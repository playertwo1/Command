using System;
using System.IO.MemoryMappedFiles;
using System.Text;

namespace Command.Services
{
    /// <summary>
    /// Fallback opcional: lê CPU/GPU do Shared Memory do HWiNFO (Configurações > Shared Memory Support),
    /// só quando o usuário já roda o HWiNFO. Nada é instalado nem iniciado pelo Command.
    /// </summary>
    public static class HwInfoReader
    {
        const string MapName = @"Global\HWiNFO_SENS_SM2";
        const uint LiveSignature = 0x53695748; // 'HWiS'; 'DEAD' quando o HWiNFO fecha
        const int HeaderSize = 44, SensorNameOffset = 8, ReadingLabelOffset = 12, ReadingValueOffset = 284;
        const uint TempType = 1;

        public static (float? Cpu, float? Gpu) Read()
        {
            try
            {
                using var mmf = MemoryMappedFile.OpenExisting(MapName, MemoryMappedFileRights.Read);
                using var view = mmf.CreateViewAccessor(0, 0, System.IO.MemoryMappedFiles.MemoryMappedFileAccess.Read);
                var buf = new byte[view.Capacity];
                view.ReadArray(0, buf, 0, buf.Length);
                return Parse(buf);
            }
            catch
            {
                return (null, null); // HWiNFO fechado ou sem Shared Memory ligado
            }
        }

        public static (float? Cpu, float? Gpu) Parse(byte[] b)
        {
            if (b.Length < HeaderSize || BitConverter.ToUInt32(b, 0) != LiveSignature) return (null, null);
            uint sOff = BitConverter.ToUInt32(b, 20), sSize = BitConverter.ToUInt32(b, 24), sCount = BitConverter.ToUInt32(b, 28);
            uint rOff = BitConverter.ToUInt32(b, 32), rSize = BitConverter.ToUInt32(b, 36), rCount = BitConverter.ToUInt32(b, 40);
            float? cpu = null, gpu = null;
            for (uint i = 0; i < rCount; i++)
            {
                long r = rOff + (long)i * rSize;
                if (r + ReadingValueOffset + 8 > b.Length || BitConverter.ToUInt32(b, (int)r) != TempType) continue;
                uint si = BitConverter.ToUInt32(b, (int)r + 4);
                if (si >= sCount) continue;
                var label = Text(b, (int)r + ReadingLabelOffset);
                var sensor = Text(b, (int)(sOff + si * sSize) + SensorNameOffset);
                var value = BitConverter.ToDouble(b, (int)r + ReadingValueOffset);
                if (double.IsNaN(value) || value < 1 || value > 125) continue;

                bool isGpu = label.Contains("GPU", StringComparison.OrdinalIgnoreCase)
                    || sensor.Contains("GPU", StringComparison.OrdinalIgnoreCase);
                if (isGpu)
                {
                    if (gpu == null || label.StartsWith("GPU Temperature", StringComparison.OrdinalIgnoreCase)) gpu = (float)Math.Round(value, 1);
                }
                else if (label.Contains("CPU", StringComparison.OrdinalIgnoreCase) || label.Contains("Tctl", StringComparison.OrdinalIgnoreCase))
                {
                    if (cpu == null || label.Contains("Package", StringComparison.OrdinalIgnoreCase) || label.Contains("Tctl", StringComparison.OrdinalIgnoreCase)) cpu = (float)Math.Round(value, 1);
                }
            }
            return (cpu, gpu);
        }

        static string Text(byte[] b, int offset)
        {
            int end = Array.IndexOf(b, (byte)0, offset, Math.Min(128, b.Length - offset));
            return Encoding.UTF8.GetString(b, offset, (end < 0 ? Math.Min(128, b.Length - offset) : end - offset));
        }
    }
}
