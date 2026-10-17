using System;
using System.Text.Json;
using DroidDeck.Models;
using DroidDeck.Services;
using Xunit;

namespace DroidDeck.Tests
{
    public class HardwareSensorsTests
    {
        [Fact]
        public void SystemStats_ThermalAndBatteryProperties_DefaultToNull()
        {
            var stats = new SystemStats();

            Assert.Null(stats.CpuTempC);
            Assert.Null(stats.GpuTempC);
            Assert.Null(stats.BatteryPercent);
            Assert.Null(stats.IsCharging);
            Assert.False(stats.HasBattery);
        }

        [Fact]
        public void SystemStats_ThermalAndBatteryProperties_PreserveValues()
        {
            var stats = new SystemStats
            {
                CpuUsage = 25.0f,
                CpuTempC = 58.5f,
                GpuTempC = 62.0f,
                BatteryPercent = 88,
                IsCharging = true,
                HasBattery = true
            };

            Assert.Equal(58.5f, stats.CpuTempC);
            Assert.Equal(62.0f, stats.GpuTempC);
            Assert.Equal(88, stats.BatteryPercent);
            Assert.True(stats.IsCharging);
            Assert.True(stats.HasBattery);
        }

        [Fact]
        public void SystemStats_Serialization_ProducesCamelCaseJson()
        {
            var stats = new SystemStats
            {
                CpuUsage = 20.0f,
                CpuTempC = 65.4f,
                GpuTempC = null,
                BatteryPercent = 95,
                IsCharging = false,
                HasBattery = true
            };

            var options = new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };
            string json = JsonSerializer.Serialize(stats, options);

            Assert.Contains("\"cpuTempC\":65.4", json);
            Assert.Contains("\"gpuTempC\":null", json);
            Assert.Contains("\"batteryPercent\":95", json);
            Assert.Contains("\"isCharging\":false", json);
            Assert.Contains("\"hasBattery\":true", json);
        }

        [Fact]
        public void MockHardwareSensorProvider_ReturnsConfiguredValues()
        {
            var mock = new FakeHardwareSensorProvider(
                cpuTemp: 52.3f,
                gpuTemp: 48.0f,
                batteryPercent: 80,
                isCharging: true,
                hasBattery: true
            );

            mock.UpdateSensors();
            var (cpuTemp, gpuTemp) = mock.GetTemperatures();
            var (batteryPercent, isCharging, hasBattery) = mock.GetPowerStatus();

            Assert.Equal(52.3f, cpuTemp);
            Assert.Equal(48.0f, gpuTemp);
            Assert.Equal(80, batteryPercent);
            Assert.True(isCharging);
            Assert.True(hasBattery);
            Assert.True(mock.UpdateCalled);

            mock.Dispose();
            Assert.True(mock.Disposed);
        }

        [Fact]
        public void HardwareSensorProvider_LiveInstance_DoesNotThrowOnPowerOrTemperatureRead()
        {
            if (!OperatingSystem.IsWindows()) return;

            using var provider = new HardwareSensorProvider();

            provider.UpdateSensors();
            var (cpuTemp, gpuTemp) = provider.GetTemperatures();
            var (batteryPercent, isCharging, hasBattery) = provider.GetPowerStatus();

            // Em modo não-elevado, cpuTemp pode ser null (fallback seguro), mas não deve estourar exceção.
            if (cpuTemp.HasValue)
            {
                Assert.InRange(cpuTemp.Value, 0f, 130f);
            }

            if (gpuTemp.HasValue)
            {
                Assert.InRange(gpuTemp.Value, 0f, 130f);
            }

            if (hasBattery)
            {
                Assert.NotNull(batteryPercent);
                Assert.InRange(batteryPercent.Value, 0, 100);
            }
            else
            {
                Assert.Null(batteryPercent);
            }
        }

        private class FakeHardwareSensorProvider : IHardwareSensorProvider
        {
            private readonly float? _cpuTemp;
            private readonly float? _gpuTemp;
            private readonly int? _batteryPercent;
            private readonly bool? _isCharging;
            private readonly bool _hasBattery;

            public bool UpdateCalled { get; private set; }
            public bool Disposed { get; private set; }

            public FakeHardwareSensorProvider(float? cpuTemp, float? gpuTemp, int? batteryPercent, bool? isCharging, bool hasBattery)
            {
                _cpuTemp = cpuTemp;
                _gpuTemp = gpuTemp;
                _batteryPercent = batteryPercent;
                _isCharging = isCharging;
                _hasBattery = hasBattery;
            }

            public (float? CpuTempC, float? GpuTempC) GetTemperatures() => (_cpuTemp, _gpuTemp);
            public (int? BatteryPercent, bool? IsCharging, bool HasBattery) GetPowerStatus() => (_batteryPercent, _isCharging, _hasBattery);
            public void UpdateSensors() => UpdateCalled = true;
            public void Dispose() => Disposed = true;
        }
    }
}
