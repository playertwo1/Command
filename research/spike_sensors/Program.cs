using System;
using LibreHardwareMonitor.Hardware;

class Program
{
    static void Main()
    {
        Console.WriteLine("=== SPIKE SENSORS & POWER TEST ===");
        
        // 1. Testar Bateria e Energia
        TestPowerStatus();

        // 2. Testar LibreHardwareMonitor
        TestHardwareSensors();
    }

    static void TestPowerStatus()
    {
        Console.WriteLine("\n[1] TESTANDO WIN32 POWER STATUS:");
        try
        {
            // P/Invoke GetSystemPowerStatus para teste portável em console
            if (GetSystemPowerStatus(out SYSTEM_POWER_STATUS status))
            {
                int batteryPercent = status.BatteryLifePercent;
                bool isCharging = (status.BatteryFlag & 8) != 0;
                bool hasBattery = (status.BatteryFlag & 128) == 0 && batteryPercent != 255;
                bool acOnline = status.ACLineStatus == 1;

                Console.WriteLine($"  ACLineStatus: {status.ACLineStatus} (Online = {acOnline})");
                Console.WriteLine($"  BatteryFlag: {status.BatteryFlag}");
                Console.WriteLine($"  BatteryPercent: {(batteryPercent == 255 ? "N/A" : batteryPercent + "%")}");
                Console.WriteLine($"  IsCharging: {isCharging}");
                Console.WriteLine($"  HasBattery: {hasBattery}");
            }
            else
            {
                Console.WriteLine("  GetSystemPowerStatus retornou false.");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"  Falha ao ler PowerStatus: {ex.Message}");
        }
    }

    static void TestHardwareSensors()
    {
        Console.WriteLine("\n[2] TESTANDO LIBREHARDWAREMONITOR:");
        var computer = new Computer
        {
            IsCpuEnabled = true,
            IsGpuEnabled = true,
            IsMemoryEnabled = true,
            IsMotherboardEnabled = true,
            IsStorageEnabled = true
        };

        try
        {
            computer.Open();
            Console.WriteLine("  Computer.Open() executado com sucesso.");

            float? cpuTemp = null;
            float? gpuTemp = null;

            foreach (var hardware in computer.Hardware)
            {
                hardware.Update();
                Console.WriteLine($"\n  -> Hardware: [{hardware.HardwareType}] {hardware.Name}");

                foreach (var sensor in hardware.Sensors)
                {
                    if (sensor.SensorType == SensorType.Temperature)
                    {
                        Console.WriteLine($"     * TEMP: {sensor.Name} = {sensor.Value}°C");
                        if (hardware.HardwareType == HardwareType.Cpu && cpuTemp == null && sensor.Value.HasValue)
                        {
                            cpuTemp = sensor.Value.Value;
                        }
                        if ((hardware.HardwareType == HardwareType.GpuNvidia || 
                             hardware.HardwareType == HardwareType.GpuAmd || 
                             hardware.HardwareType == HardwareType.GpuIntel) && 
                            gpuTemp == null && sensor.Value.HasValue)
                        {
                            gpuTemp = sensor.Value.Value;
                        }
                    }
                }

                foreach (var sub in hardware.SubHardware)
                {
                    sub.Update();
                    Console.WriteLine($"     + SubHardware: [{sub.HardwareType}] {sub.Name}");
                    foreach (var sensor in sub.Sensors)
                    {
                        if (sensor.SensorType == SensorType.Temperature)
                        {
                            Console.WriteLine($"        * TEMP: {sensor.Name} = {sensor.Value}°C");
                        }
                    }
                }
            }

            Console.WriteLine("\n=== RESUMO DOS SENSORES CAPTURADOS ===");
            Console.WriteLine($"  CPU Temp detectada: {(cpuTemp.HasValue ? $"{cpuTemp.Value:F1}°C" : "NÃO DISPONÍVEL (Exige Admin ou driver indisponível)")}");
            Console.WriteLine($"  GPU Temp detectada: {(gpuTemp.HasValue ? $"{gpuTemp.Value:F1}°C" : "NÃO DISPONÍVEL (Exige Admin ou GPU integrada sem sensor)")}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"  Exceção no LibreHardwareMonitor: {ex.Message}\n{ex.StackTrace}");
        }
        finally
        {
            try { computer.Close(); } catch { }
        }
    }

    [System.Runtime.InteropServices.DllImport("kernel32.dll")]
    private static extern bool GetSystemPowerStatus(out SYSTEM_POWER_STATUS lpSystemPowerStatus);

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
