using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using Command.Models;
using Microsoft.Extensions.Logging;

namespace Command.Services
{
    public interface ITopProcessesService
    {
        TopProcessesResponseDto GetTopProcesses(int limit = 5);
    }

    /// <summary>
    /// Consulta somente leitura dos processos mais consumidores de CPU e RAM no host Windows.
    /// Não expõe caminhos de arquivo, variáveis, parâmetros ou privilégio de encerramento.
    /// </summary>
    public class TopProcessesService : ITopProcessesService
    {
        private readonly ILogger<TopProcessesService> _logger;
        private readonly object _lock = new();
        private readonly Dictionary<int, (TimeSpan CpuTime, DateTime Timestamp)> _cpuSnapshots = new();
        private TopProcessesResponseDto? _cachedResponse;
        private DateTime _lastScanTime = DateTime.MinValue;
        private static readonly TimeSpan CacheTtl = TimeSpan.FromSeconds(2);

        public TopProcessesService(ILogger<TopProcessesService> logger)
        {
            _logger = logger;
        }

        public TopProcessesResponseDto GetTopProcesses(int limit = 5)
        {
            int safeLimit = Math.Clamp(limit, 1, 10);
            var now = DateTime.UtcNow;

            lock (_lock)
            {
                if (now - _lastScanTime < CacheTtl && _cachedResponse != null)
                {
                    return new TopProcessesResponseDto
                    {
                        ByMemory = _cachedResponse.ByMemory.Take(safeLimit).ToList(),
                        ByCpu = _cachedResponse.ByCpu.Take(safeLimit).ToList()
                    };
                }

                _cachedResponse = ScanProcesses(now);
                _lastScanTime = now;

                return new TopProcessesResponseDto
                {
                    ByMemory = _cachedResponse.ByMemory.Take(safeLimit).ToList(),
                    ByCpu = _cachedResponse.ByCpu.Take(safeLimit).ToList()
                };
            }
        }

        private TopProcessesResponseDto ScanProcesses(DateTime now)
        {
            var rawList = new List<TopProcessDto>();
            var seenPids = new HashSet<int>();
            int processorCount = Environment.ProcessorCount;

            Process[] processes;
            try
            {
                processes = Process.GetProcesses();
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Falha ao obter lista de processos do sistema");
                return new TopProcessesResponseDto();
            }

            foreach (var p in processes)
            {
                int pid = p.Id;
                seenPids.Add(pid);

                string name = string.Empty;
                float memoryMB = 0f;
                float? cpuPercent = null;

                try
                {
                    name = p.ProcessName;
                    memoryMB = (float)Math.Round(p.WorkingSet64 / (1024f * 1024f), 1);
                }
                catch
                {
                    // Processo finalizado ou inacessível
                    p.Dispose();
                    continue;
                }

                // Cálculo do uso de CPU via delta de tempo do processador
                try
                {
                    var currentCpu = p.TotalProcessorTime;
                    if (_cpuSnapshots.TryGetValue(pid, out var prev))
                    {
                        var timeDeltaMs = (now - prev.Timestamp).TotalMilliseconds;
                        if (timeDeltaMs > 200)
                        {
                            var cpuDeltaMs = (currentCpu - prev.CpuTime).TotalMilliseconds;
                            var pct = (float)Math.Round((cpuDeltaMs / (timeDeltaMs * processorCount)) * 100.0, 1);
                            cpuPercent = Math.Clamp(pct, 0f, 100f);
                        }
                    }
                    _cpuSnapshots[pid] = (currentCpu, now);
                }
                catch
                {
                    // Sem permissão para ler TotalProcessorTime (ex.: Processos do Kernel ou UAC)
                    cpuPercent = null;
                }
                finally
                {
                    p.Dispose();
                }

                rawList.Add(new TopProcessDto
                {
                    Pid = pid,
                    Name = name,
                    MemoryMB = memoryMB,
                    CpuPercent = cpuPercent
                });
            }

            // Limpa entradas de PIDs que não existem mais
            foreach (var pid in _cpuSnapshots.Keys.Where(k => !seenPids.Contains(k)).ToList())
            {
                _cpuSnapshots.Remove(pid);
            }

            var byMemory = rawList
                .OrderByDescending(p => p.MemoryMB)
                .Take(10)
                .ToList();

            var byCpu = rawList
                .Where(p => p.CpuPercent.HasValue)
                .OrderByDescending(p => p.CpuPercent!.Value)
                .Take(10)
                .ToList();

            return new TopProcessesResponseDto
            {
                ByMemory = byMemory,
                ByCpu = byCpu
            };
        }
    }
}
