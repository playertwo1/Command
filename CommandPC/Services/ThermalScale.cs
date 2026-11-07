using System;

namespace Command.Services
{
    /// <summary>
    /// Converte leituras brutas e escolhe a primeira fonte que devolveu um valor.
    /// LibreHardwareMonitor vem primeiro. ACPI cobre a CPU. NVAPI e ADL cobrem a GPU.
    /// </summary>
    public static class ThermalScale
    {
        public static float? FromTenthsOfKelvin(uint raw)
        {
            if (raw == 0) return null;
            return Accept(raw / 10.0 - 273.15);
        }

        public static float? FromMilliCelsius(int milli) => Accept(milli / 1000.0);

        public static (float? Cpu, float? Gpu) Choose(
            float? libreCpu,
            float? libreGpu,
            float? acpiCpu,
            float? nvidiaGpu,
            float? amdGpu)
        {
            return (libreCpu ?? acpiCpu, libreGpu ?? nvidiaGpu ?? amdGpu);
        }

        private static float? Accept(double celsius)
        {
            if (double.IsNaN(celsius) || celsius < 1 || celsius > 125) return null;
            return (float)Math.Round(celsius, 1, MidpointRounding.AwayFromZero);
        }
    }
}
