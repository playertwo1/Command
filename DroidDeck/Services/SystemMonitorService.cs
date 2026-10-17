using DroidDeck.Hubs;
using DroidDeck.Models;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace DroidDeck.Services
{
    public class SystemMonitorService : BackgroundService
    {
        private readonly ILogger<SystemMonitorService> _logger;
        private readonly IHubContext<DeckHub> _hubContext;
        private readonly MediaControlService _media;
        private readonly IHardwareSensorProvider? _sensorProvider;
        private PerformanceCounter? _cpuCounter;

        // Estado para throughput de rede (deltas por segundo).
        private long _lastSent;
        private long _lastRecv;
        private DateTime _lastNetTime = DateTime.UtcNow;

        // Counters de GPU (uso) por instância de engine 3D; cacheados entre ticks.
        private readonly Dictionary<string, PerformanceCounter> _gpuCounters = new();
        // A enumeração de instâncias ("GetInstanceNames") é cara e aloca uma string por
        // engine de GPU a cada chamada. Só rescaneia a cada N ticks; entre eles, só lê os
        // counters já cacheados (evita pressão de GC constante no loop de 1s).
        private int _gpuTick = 0;
        private const int GpuRescanEveryTicks = 30;

        // Buffer circular para os últimos 60 segundos de telemetria
        private readonly object _historyLock = new();
        private readonly Queue<MetricSampleDto> _history = new(60);

        /// <summary>Última amostra de telemetria coletada pelo monitor de sistema.</summary>
        public SystemStats LastStats { get; private set; } = new();

        public void RecordSample(MetricSampleDto sample)
        {
            lock (_historyLock)
            {
                while (_history.Count >= 60)
                {
                    _history.Dequeue();
                }
                _history.Enqueue(sample);
            }
        }

        public List<MetricSampleDto> GetHistorySnapshot()
        {
            lock (_historyLock)
            {
                return _history.ToList();
            }
        }

        public SystemMonitorService(
            ILogger<SystemMonitorService> logger,
            IHubContext<DeckHub> hubContext,
            MediaControlService media,
            IHardwareSensorProvider? sensorProvider = null)
        {
            _logger = logger;
            _hubContext = hubContext;
            _media = media;
            _sensorProvider = sensorProvider;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            if (!OperatingSystem.IsWindows())
            {
                _logger.LogWarning("SystemMonitorService is only supported on Windows.");
                return;
            }

            try
            {
                try
                {
                    _cpuCounter = new PerformanceCounter("Processor", "% Processor Time", "_Total");
                }
                catch
                {
                    // Fallback for PT-BR
                    try { _cpuCounter = new PerformanceCounter("Processador", "% tempo de processador", "_Total"); }
                    catch (Exception ex) { _logger.LogError(ex, "Failed to init CPU Counter"); }
                }

                if (_cpuCounter != null) _cpuCounter.NextValue();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Fatal Error initializing Monitors");
                return;
            }

            // Amostragem inicial para que endpoints REST tenham dados imediatos
            try
            {
                SampleStats();
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Erro na amostragem inicial de telemetria");
            }

            int tick = 0;
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    // Sem clientes ouvindo, não computa nem transmite nada — evita o poll
                    // de mídia WinRT (caro) e as alocações de rede/GPU 24/7 com o app ocioso.
                    if (DeckHub.ConnectedCount <= 0)
                    {
                        await Task.Delay(1000, stoppingToken);
                        continue;
                    }

                    var stats = SampleStats();

                    // Broadcast to clients listening on "ReceiveSystemStats"
                    await _hubContext.Clients.All.SendAsync("ReceiveSystemStats", stats, cancellationToken: stoppingToken);

                    // Estado de reprodução de mídia (pra botões play/pause refletirem).
                    // A cada 3s: o acesso WinRT (RequestAsync) é caro; 1s era exagero.
                    if (tick % 3 == 0)
                    {
                        try
                        {
                            var playing = await _media.IsAnythingPlayingAsync();
                            await _hubContext.Clients.All.SendAsync("ReceiveMediaStatus",
                                new { playing }, cancellationToken: stoppingToken);
                        }
                        catch { }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error broadcasting system stats");
                }

                tick++;
                await Task.Delay(1000, stoppingToken);
            }

            // Libera os PerformanceCounter ao encerrar o serviço.
            try { _cpuCounter?.Dispose(); } catch { }
            foreach (var c in _gpuCounters.Values) { try { c.Dispose(); } catch { } }
            _gpuCounters.Clear();
        }

        public SystemStats SampleStats()
        {
            var cpu = _cpuCounter?.NextValue() ?? 0;

            // RAM via GlobalMemoryStatusEx: total, disponível e % de uso de uma vez.
            var mem = new MEMORYSTATUSEX();
            float ramTotal = 0, ramAvailable = 0, ramLoad = 0;
            if (GlobalMemoryStatusEx(mem))
            {
                ramTotal = mem.ullTotalPhys / (1024f * 1024f); // MB
                ramAvailable = mem.ullAvailPhys / (1024f * 1024f); // MB
                ramLoad = mem.dwMemoryLoad; // % usada (0-100)
            }

            var (netUp, netDown) = SampleNetwork();
            var disks = SampleDisks();
            var (diskUsage, diskTotal, diskFree) = SampleDisk(disks);
            long uptime = Environment.TickCount64 / 1000;

            // Telemetria estendida de sensores e energia (v0.2)
            _sensorProvider?.UpdateSensors();
            var (cpuTemp, gpuTemp) = _sensorProvider?.GetTemperatures() ?? (null, null);
            var (batteryPercent, isCharging, hasBattery) = _sensorProvider?.GetPowerStatus() ?? (null, null, false);

            float roundedCpu = (float)Math.Round(cpu, 1);
            float roundedRam = (float)Math.Round(ramLoad, 1);
            float gpuUsage = SampleGpu();

            var sample = new MetricSampleDto
            {
                TimestampUtc = DateTime.UtcNow,
                Cpu = roundedCpu,
                Ram = roundedRam,
                Gpu = gpuUsage,
                CpuTempC = cpuTemp,
                GpuTempC = gpuTemp
            };
            RecordSample(sample);

            var stats = new SystemStats
            {
                CpuUsage = roundedCpu,
                RamTotal = ramTotal,
                RamAvailable = ramAvailable,
                RamUsage = roundedRam,
                NetUpKBps = netUp,
                NetDownKBps = netDown,
                GpuUsage = gpuUsage,
                DiskUsage = diskUsage,
                DiskTotalGB = diskTotal,
                DiskAvailableGB = diskFree,
                UptimeSeconds = uptime,
                CpuTempC = cpuTemp,
                GpuTempC = gpuTemp,
                BatteryPercent = batteryPercent,
                IsCharging = isCharging,
                HasBattery = hasBattery,
                History = GetHistorySnapshot(),
                Disks = disks
            };
            LastStats = stats;
            return stats;
        }

        private (float up, float down) SampleNetwork()
        {
            long sent = 0, recv = 0;
            try
            {
                foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
                {
                    if (ni.OperationalStatus != OperationalStatus.Up) continue;
                    if (ni.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
                    var s = ni.GetIPv4Statistics();
                    sent += s.BytesSent;
                    recv += s.BytesReceived;
                }
            }
            catch { }

            var now = DateTime.UtcNow;
            var elapsed = (now - _lastNetTime).TotalSeconds;
            float up = 0, down = 0;
            if (_lastSent > 0 && elapsed > 0.1)
            {
                up = (float)Math.Max(0, (sent - _lastSent) / elapsed / 1024.0);   // KB/s
                down = (float)Math.Max(0, (recv - _lastRecv) / elapsed / 1024.0); // KB/s
            }
            _lastSent = sent;
            _lastRecv = recv;
            _lastNetTime = now;
            return (up, down);
        }

        public static List<DiskVolumeDto> SampleDisks()
        {
            var disks = new List<DiskVolumeDto>();
            try
            {
                foreach (var drive in DriveInfo.GetDrives())
                {
                    if (drive.DriveType == DriveType.Fixed && drive.IsReady)
                    {
                        float total = drive.TotalSize / (1024f * 1024f * 1024f);
                        float free = drive.AvailableFreeSpace / (1024f * 1024f * 1024f);
                        float used = total - free;
                        float usage = total > 0 ? (used / total) * 100f : 0f;
                        string label = string.Empty;
                        try { label = drive.VolumeLabel; } catch { }
                        if (string.IsNullOrWhiteSpace(label))
                        {
                            label = drive.Name.TrimEnd('\\');
                        }

                        disks.Add(new DiskVolumeDto
                        {
                            Name = drive.Name.TrimEnd('\\'),
                            Label = label,
                            TotalGB = (float)Math.Round(total, 1),
                            AvailableGB = (float)Math.Round(free, 1),
                            UsagePercent = (float)Math.Round(usage, 1)
                        });
                    }
                }
            }
            catch { }
            return disks;
        }

        private static (float usage, float totalGb, float freeGb) SampleDisk(List<DiskVolumeDto> disks)
        {
            try
            {
                string sysDrive = (Path.GetPathRoot(Environment.SystemDirectory) ?? "C:").TrimEnd('\\');
                var primary = disks.FirstOrDefault(d => string.Equals(d.Name, sysDrive, StringComparison.OrdinalIgnoreCase))
                              ?? disks.FirstOrDefault();
                if (primary != null)
                {
                    return (primary.UsagePercent, primary.TotalGB, primary.AvailableGB);
                }
            }
            catch { }
            return (0, 0, 0);
        }

        private float SampleGpu()
        {
            try
            {
                // Rescan das instâncias só de tempos em tempos (caro). No 1º tick e a cada N.
                if (_gpuTick++ % GpuRescanEveryTicks == 0)
                {
                    var cat = new PerformanceCounterCategory("GPU Engine");
                    var names = cat.GetInstanceNames()
                        .Where(n => n.EndsWith("engtype_3D"))
                        .ToHashSet();

                    foreach (var n in names)
                    {
                        if (!_gpuCounters.ContainsKey(n))
                        {
                            var c = new PerformanceCounter("GPU Engine", "Utilization Percentage", n, true);
                            try { c.NextValue(); } catch { } // prime: 1ª leitura é 0
                            _gpuCounters[n] = c;
                        }
                    }
                    foreach (var key in _gpuCounters.Keys.Where(k => !names.Contains(k)).ToList())
                    {
                        try { _gpuCounters[key].Dispose(); } catch { }
                        _gpuCounters.Remove(key);
                    }
                }

                float sum = 0;
                foreach (var c in _gpuCounters.Values)
                {
                    try { sum += c.NextValue(); } catch { }
                }
                return Math.Min(sum, 100f);
            }
            catch
            {
                return 0; // GPU Engine indisponível neste sistema
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        private class MEMORYSTATUSEX
        {
            public uint dwLength;
            public uint dwMemoryLoad;
            public ulong ullTotalPhys;
            public ulong ullAvailPhys;
            public ulong ullTotalPageFile;
            public ulong ullAvailPageFile;
            public ulong ullTotalVirtual;
            public ulong ullAvailVirtual;
            public ulong ullAvailExtendedVirtual;

            public MEMORYSTATUSEX()
            {
                dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
            }
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GlobalMemoryStatusEx([In, Out] MEMORYSTATUSEX lpBuffer);
    }
}
