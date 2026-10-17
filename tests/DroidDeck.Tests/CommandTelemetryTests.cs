using DroidDeck.Models;
using Xunit;

namespace DroidDeck.Tests
{
    public class CommandTelemetryTests
    {
        [Fact]
        public void SystemStats_Valores_IncluiDiscoEUptime()
        {
            var stats = new SystemStats
            {
                CpuUsage = 15.5f,
                RamUsage = 50.0f,
                RamTotal = 16384f,
                RamAvailable = 8192f,
                DiskUsage = 45.2f,
                DiskTotalGB = 512.0f,
                DiskAvailableGB = 280.5f,
                UptimeSeconds = 3600,
                GpuUsage = 10.0f,
                NetUpKBps = 120.5f,
                NetDownKBps = 540.2f
            };

            Assert.Equal(15.5f, stats.CpuUsage);
            Assert.Equal(45.2f, stats.DiskUsage);
            Assert.Equal(512.0f, stats.DiskTotalGB);
            Assert.Equal(280.5f, stats.DiskAvailableGB);
            Assert.Equal(3600, stats.UptimeSeconds);
        }
    }
}
