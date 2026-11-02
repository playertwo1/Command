using System;
using System.Runtime.InteropServices;
using System.Management;
using LibreHardwareMonitor.Hardware;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    public interface IHardwareSensorProvider : IDisposable
    {
        /// <summary>
        /// Retorna as temperaturas mais recentes de CPU e GPU (em graus Celsius), ou null se indisponíveis.
        /// </summary>
        (float? CpuTempC, float? GpuTempC) GetTemperatures();

        /// <summary>
        /// Retorna o status de energia e bateria do sistema (porcentagem 0-100, se está carregando e se possui bateria).
        /// </summary>
        (int? BatteryPercent, bool? IsCharging, bool HasBattery) GetPowerStatus();

        /// <summary>
        /// Atualiza as leituras dos sensores de hardware respeitando intervalo mínimo de atualização.
        /// </summary>
        void UpdateSensors();
    }

    public class HardwareSensorProvider : IHardwareSensorProvider
    {
        private readonly ILogger<HardwareSensorProvider>? _logger;
        private readonly Computer? _computer;
        private readonly object _lock = new();
        private bool _disposed;

        private float? _cachedCpuTemp;
        private float? _cachedGpuTemp;
        private DateTime _lastUpdateUtc = DateTime.MinValue;
        private readonly TimeSpan _minUpdateInterval = TimeSpan.FromSeconds(3);
        private bool _loggedAcpi;
        private bool _loggedGpu;

        public HardwareSensorProvider(ILogger<HardwareSensorProvider>? logger = null)
        {
            _logger = logger;

            if (OperatingSystem.IsWindows())
            {
                try
                {
                    _computer = new Computer
                    {
                        IsCpuEnabled = true,
                        IsGpuEnabled = true,
                        IsMotherboardEnabled = false,
                        IsMemoryEnabled = false,
                        IsControllerEnabled = false,
                        IsStorageEnabled = false,
                        IsNetworkEnabled = false
                    };
                    _computer.Open();
                    _logger?.LogInformation("[HardwareSensors] LibreHardwareMonitor inicializado com sucesso.");
                }
                catch (Exception ex)
                {
                    _logger?.LogWarning(ex, "[HardwareSensors] Falha ao inicializar LibreHardwareMonitor. Operando em modo fallback.");
                    _computer = null;
                }
            }
        }

        public (float? CpuTempC, float? GpuTempC) GetTemperatures()
        {
            lock (_lock)
            {
                return (_cachedCpuTemp, _cachedGpuTemp);
            }
        }

        public (int? BatteryPercent, bool? IsCharging, bool HasBattery) GetPowerStatus()
        {
            if (!OperatingSystem.IsWindows())
            {
                return (null, null, false);
            }

            try
            {
                if (GetSystemPowerStatus(out SYSTEM_POWER_STATUS status))
                {
                    // BatteryFlag & 128 = NoSystemBattery
                    bool hasBattery = (status.BatteryFlag & 128) == 0 && status.BatteryLifePercent != 255;
                    int? batteryPercent = hasBattery ? (int?)status.BatteryLifePercent : null;
                    
                    bool? isCharging = null;
                    if (hasBattery)
                    {
                        // BatteryFlag & 8 = Charging, ou ACLineStatus == 1 (Online / Na tomada)
                        isCharging = (status.BatteryFlag & 8) != 0 || status.ACLineStatus == 1;
                    }

                    return (batteryPercent, isCharging, hasBattery);
                }
            }
            catch (Exception ex)
            {
                _logger?.LogDebug(ex, "[HardwareSensors] Erro ao obter PowerStatus via Win32.");
            }

            return (null, null, false);
        }

        public void UpdateSensors()
        {
            if (!OperatingSystem.IsWindows())
                return;

            lock (_lock)
            {
                if (DateTime.UtcNow - _lastUpdateUtc < _minUpdateInterval)
                    return;

                _lastUpdateUtc = DateTime.UtcNow;

                float? libreCpu = null;
                float? libreGpu = null;
                try
                {
                    ReadLibreHardwareMonitor(ref libreCpu, ref libreGpu);
                }
                catch (Exception ex)
                {
                    _logger?.LogDebug(ex, "[HardwareSensors] Erro ao atualizar o LibreHardwareMonitor.");
                }

                float? acpi = null;
                float? nvidia = null;
                float? amd = null;
                if (libreCpu == null)
                {
                    acpi = ReadAcpiThermalZone();
                    if (acpi != null && !_loggedAcpi)
                    {
                        _loggedAcpi = true;
                        _logger?.LogInformation("[HardwareSensors] CPU lida pela zona térmica ACPI.");
                    }
                }
                if (libreGpu == null)
                {
                    nvidia = GpuThermalReader.ReadNvidia();
                    amd = nvidia == null ? GpuThermalReader.ReadAmd() : null;
                    if ((nvidia != null || amd != null) && !_loggedGpu)
                    {
                        _loggedGpu = true;
                        _logger?.LogInformation("[HardwareSensors] GPU lida pelo driver, sem elevação.");
                    }
                }

                var chosen = ThermalScale.Choose(libreCpu, libreGpu, acpi, nvidia, amd);
                _cachedCpuTemp = chosen.Cpu;
                _cachedGpuTemp = chosen.Gpu;
            }
        }

        private void ReadLibreHardwareMonitor(ref float? cpuTemp, ref float? gpuTemp)
        {
            if (_computer == null) return;
            foreach (var hardware in _computer.Hardware)
            {
                try
                {
                    hardware.Update();
                    ExtractTemperatures(hardware, ref cpuTemp, ref gpuTemp);
                    foreach (var sub in hardware.SubHardware)
                    {
                        sub.Update();
                        ExtractTemperatures(sub, ref cpuTemp, ref gpuTemp);
                    }
                }
                catch
                {
                    // Um componente quebrado não impede os outros.
                }
            }
        }

        private float? ReadAcpiThermalZone()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher(
                    @"root\wmi",
                    "SELECT CurrentTemperature FROM MSAcpi_ThermalZoneTemperature");
                float? hottest = null;
                foreach (var entry in searcher.Get())
                {
                    using var zone = (ManagementObject)entry;
                    if (zone["CurrentTemperature"] == null) continue;
                    var raw = Convert.ToUInt32(zone["CurrentTemperature"]);
                    var celsius = ThermalScale.FromTenthsOfKelvin(raw);
                    if (celsius == null) continue;
                    if (hottest == null || celsius > hottest) hottest = celsius;
                }
                return hottest;
            }
            catch (Exception ex)
            {
                _logger?.LogDebug(ex, "[HardwareSensors] Zona ACPI indisponível.");
                return null;
            }
        }

        private static void ExtractTemperatures(IHardware hardware, ref float? cpuTemp, ref float? gpuTemp)
        {
            foreach (var sensor in hardware.Sensors)
            {
                if (sensor.SensorType == SensorType.Temperature && sensor.Value.HasValue)
                {
                    float val = (float)Math.Round(sensor.Value.Value, 1);
                    if (hardware.HardwareType == HardwareType.Cpu && cpuTemp == null)
                    {
                        cpuTemp = val;
                    }
                    else if ((hardware.HardwareType == HardwareType.GpuNvidia ||
                              hardware.HardwareType == HardwareType.GpuAmd ||
                              hardware.HardwareType == HardwareType.GpuIntel) && gpuTemp == null)
                    {
                        gpuTemp = val;
                    }
                }
            }
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;

            try
            {
                _computer?.Close();
            }
            catch { }
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetSystemPowerStatus(out SYSTEM_POWER_STATUS lpSystemPowerStatus);

        [StructLayout(LayoutKind.Sequential)]
        private struct SYSTEM_POWER_STATUS
        {
            public byte ACLineStatus;
            public byte BatteryFlag;
            public byte BatteryLifePercent;
            public byte SystemStatusFlag;
            public int BatteryLifeTime;
            public int BatteryFullLifeTime;
        }
    }
}
