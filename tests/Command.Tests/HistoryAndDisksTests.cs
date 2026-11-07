using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using Command.Hubs;
using Command.Models;
using Command.Services;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Command.Tests
{
    public class HistoryAndDisksTests
    {
        [Fact]
        public void MetricSampleDto_DefaultAndAssignment()
        {
            var now = DateTime.UtcNow;
            var sample = new MetricSampleDto
            {
                TimestampUtc = now,
                Cpu = 42.5f,
                Ram = 68.2f,
                Gpu = 15.0f,
                CpuTempC = 55.0f,
                GpuTempC = 50.0f
            };

            Assert.Equal(now, sample.TimestampUtc);
            Assert.Equal(42.5f, sample.Cpu);
            Assert.Equal(68.2f, sample.Ram);
            Assert.Equal(15.0f, sample.Gpu);
            Assert.Equal(55.0f, sample.CpuTempC);
            Assert.Equal(50.0f, sample.GpuTempC);
        }

        [Fact]
        public void DiskVolumeDto_DefaultAndAssignment()
        {
            var disk = new DiskVolumeDto
            {
                Name = "C:",
                Label = "Windows SSD",
                TotalGB = 512.0f,
                AvailableGB = 256.0f,
                UsagePercent = 50.0f
            };

            Assert.Equal("C:", disk.Name);
            Assert.Equal("Windows SSD", disk.Label);
            Assert.Equal(512.0f, disk.TotalGB);
            Assert.Equal(256.0f, disk.AvailableGB);
            Assert.Equal(50.0f, disk.UsagePercent);
        }

        [Fact]
        public void SystemStats_Serialization_IncludesHistoryAndDisksCamelCase()
        {
            var stats = new SystemStats
            {
                CpuUsage = 15.0f,
                RamUsage = 50.0f,
                History =
                {
                    new MetricSampleDto
                    {
                        TimestampUtc = new DateTime(2026, 10, 17, 19, 0, 0, DateTimeKind.Utc),
                        Cpu = 15.0f,
                        Ram = 50.0f,
                        Gpu = 5.0f,
                        CpuTempC = 45.0f,
                        GpuTempC = null
                    }
                },
                Disks =
                {
                    new DiskVolumeDto
                    {
                        Name = "C:",
                        Label = "System",
                        TotalGB = 476.0f,
                        AvailableGB = 120.0f,
                        UsagePercent = 74.8f
                    }
                }
            };

            var options = new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
            string json = JsonSerializer.Serialize(stats, options);

            Assert.Contains("\"history\":[", json);
            Assert.Contains("\"timestampUtc\":", json);
            Assert.Contains("\"cpu\":15", json);
            Assert.Contains("\"cpuTempC\":45", json);
            Assert.Contains("\"disks\":[", json);
            Assert.Contains("\"name\":\"C:\"", json);
            Assert.Contains("\"label\":\"System\"", json);
            Assert.Contains("\"usagePercent\":74.8", json);
        }

        [Fact]
        public void SystemMonitorService_HistoryBuffer_CapsAt60AndMaintainsFifoOrder()
        {
            var monitor = new SystemMonitorService(
                NullLogger<SystemMonitorService>.Instance,
                new FakeHubContext(),
                new MediaControlService(NullLogger<MediaControlService>.Instance)
            );

            // Adiciona 75 amostras sequenciais (1 a 75)
            for (int i = 1; i <= 75; i++)
            {
                monitor.RecordSample(new MetricSampleDto
                {
                    TimestampUtc = DateTime.UtcNow,
                    Cpu = i,
                    Ram = 50.0f,
                    Gpu = 10.0f
                });
            }

            var snapshot = monitor.GetHistorySnapshot();

            // Capacidade máxima é exatamente 60
            Assert.Equal(60, snapshot.Count);

            // FIFO: As primeiras 15 foram descartadas. O buffer deve conter de 16 a 75.
            Assert.Equal(16f, snapshot.First().Cpu);
            Assert.Equal(75f, snapshot.Last().Cpu);
        }

        [Fact]
        public void SystemMonitorService_SampleDisks_OnWindows_ReturnsValidFixedVolumes()
        {
            if (!OperatingSystem.IsWindows()) return;

            var disks = SystemMonitorService.SampleDisks();

            Assert.NotEmpty(disks);
            foreach (var disk in disks)
            {
                Assert.False(string.IsNullOrWhiteSpace(disk.Name));
                Assert.True(disk.TotalGB > 0, $"Drive {disk.Name} TotalGB should be > 0");
                Assert.True(disk.AvailableGB >= 0, $"Drive {disk.Name} AvailableGB should be >= 0");
                Assert.InRange(disk.UsagePercent, 0f, 100f);
            }

            // O volume de sistema (ex.: C:) deve estar presente na lista
            var sysDrive = (System.IO.Path.GetPathRoot(Environment.SystemDirectory) ?? "C:").TrimEnd('\\');
            Assert.Contains(disks, d => string.Equals(d.Name, sysDrive, StringComparison.OrdinalIgnoreCase));
        }

        private class FakeHubContext : IHubContext<DeckHub>
        {
            public IHubClients Clients => new FakeHubClients();
            public IGroupManager Groups => throw new NotImplementedException();
        }

        private class FakeHubClients : IHubClients
        {
            public IClientProxy All => new FakeClientProxy();
            public IClientProxy AllExcept(IReadOnlyList<string> excludedConnectionIds) => new FakeClientProxy();
            public IClientProxy Client(string connectionId) => new FakeClientProxy();
            public IClientProxy Clients(IReadOnlyList<string> connectionIds) => new FakeClientProxy();
            public IClientProxy Group(string groupName) => new FakeClientProxy();
            public IClientProxy GroupExcept(string groupName, IReadOnlyList<string> excludedConnectionIds) => new FakeClientProxy();
            public IClientProxy Groups(IReadOnlyList<string> groupNames) => new FakeClientProxy();
            public IClientProxy User(string userId) => new FakeClientProxy();
            public IClientProxy Users(IReadOnlyList<string> userIds) => new FakeClientProxy();
        }

        private class FakeClientProxy : IClientProxy
        {
            public System.Threading.Tasks.Task SendCoreAsync(string method, object?[] args, System.Threading.CancellationToken cancellationToken = default)
            {
                return System.Threading.Tasks.Task.CompletedTask;
            }
        }
    }
}
