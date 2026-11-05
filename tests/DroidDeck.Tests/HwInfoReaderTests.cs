using System;
using System.Text;
using DroidDeck.Services;
using Xunit;

namespace DroidDeck.Tests
{
    public class HwInfoReaderTests
    {
        static void Put(byte[] b, int off, string s) => Encoding.UTF8.GetBytes(s).CopyTo(b, off);

        [Fact]
        public void Parse_PicksCpuPackageAndGpuTemperature()
        {
            const int sSize = 264, rSize = 316, sOff = 44, rOff = 44 + 2 * 264;
            var b = new byte[rOff + 3 * rSize];
            BitConverter.GetBytes(0x53695748u).CopyTo(b, 0);
            BitConverter.GetBytes((uint)sOff).CopyTo(b, 20);
            BitConverter.GetBytes((uint)sSize).CopyTo(b, 24);
            BitConverter.GetBytes(2u).CopyTo(b, 28);
            BitConverter.GetBytes((uint)rOff).CopyTo(b, 32);
            BitConverter.GetBytes((uint)rSize).CopyTo(b, 36);
            BitConverter.GetBytes(3u).CopyTo(b, 40);
            Put(b, sOff + 8, "CPU [#0]: Intel");
            Put(b, sOff + sSize + 8, "GPU [#0]: NVIDIA");

            void Reading(int i, uint sensor, string label, double v)
            {
                int r = rOff + i * rSize;
                BitConverter.GetBytes(1u).CopyTo(b, r);
                BitConverter.GetBytes(sensor).CopyTo(b, r + 4);
                Put(b, r + 12, label);
                BitConverter.GetBytes(v).CopyTo(b, r + 284);
            }
            Reading(0, 0, "Core 0", 50);
            Reading(1, 0, "CPU Package", 61.5);
            Reading(2, 1, "GPU Temperature", 70);

            Assert.Equal((61.5f, 70f), HwInfoReader.Parse(b));
        }

        [Fact]
        public void Parse_ReturnsNullWhenHwInfoClosed() =>
            Assert.Equal((null, null), HwInfoReader.Parse(new byte[64]));
    }
}
