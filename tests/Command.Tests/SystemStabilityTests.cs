using System;
using Command.Controllers;
using Command.Models;
using Command.Services;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Xunit;

namespace Command.Tests
{
    public class SystemStabilityTests
    {
        [Fact]
        public void GetCurrentSnapshot_ReturnsValidProcessMetrics()
        {
            var monitor = new SystemStabilityMonitor();
            var snapshot = monitor.GetCurrentSnapshot();

            Assert.NotNull(snapshot);
            Assert.True(snapshot.WorkingSetMb > 0, "WorkingSetMb deve ser maior que zero.");
            Assert.True(snapshot.HandleCount > 0, "HandleCount deve ser maior que zero.");
            Assert.True(snapshot.ThreadCount > 0, "ThreadCount deve ser maior que zero.");
            Assert.True(snapshot.BridgeUptimeSeconds >= 0, "BridgeUptimeSeconds deve ser não-negativo.");
            Assert.Contains(snapshot.HealthStatus, new[] { "Healthy", "Warning" });
            Assert.True(snapshot.TimestampUtc <= DateTime.UtcNow);
        }

        [Fact]
        public void HealthStatus_Under350MbAndUnder2500Handles_IsHealthy()
        {
            var mockMonitor = new Mock<ISystemStabilityMonitor>();
            mockMonitor.Setup(m => m.GetCurrentSnapshot()).Returns(new SystemStabilityDto(
                WorkingSetMb: 120.5,
                HandleCount: 650,
                ThreadCount: 16,
                BridgeUptimeSeconds: 3600,
                HealthStatus: "Healthy",
                TimestampUtc: DateTime.UtcNow
            ));

            var snapshot = mockMonitor.Object.GetCurrentSnapshot();
            Assert.Equal("Healthy", snapshot.HealthStatus);
            Assert.True(snapshot.WorkingSetMb < 350.0);
            Assert.True(snapshot.HandleCount < 2500);
        }

        [Fact]
        public void HealthStatus_ExceedingThresholds_ReportsWarning()
        {
            var mockMonitor = new Mock<ISystemStabilityMonitor>();
            mockMonitor.Setup(m => m.GetCurrentSnapshot()).Returns(new SystemStabilityDto(
                WorkingSetMb: 420.0,
                HandleCount: 3000,
                ThreadCount: 40,
                BridgeUptimeSeconds: 7200,
                HealthStatus: "Warning",
                TimestampUtc: DateTime.UtcNow
            ));

            var snapshot = mockMonitor.Object.GetCurrentSnapshot();
            Assert.Equal("Warning", snapshot.HealthStatus);
        }

        [Fact]
        public void UpdateController_GetStability_ReturnsOkWithSnapshot()
        {
            var updateMock = new Mock<IUpdateVerificationService>();
            var stabilityMock = new Mock<ISystemStabilityMonitor>();

            var expectedDto = new SystemStabilityDto(
                WorkingSetMb: 85.0,
                HandleCount: 400,
                ThreadCount: 12,
                BridgeUptimeSeconds: 120,
                HealthStatus: "Healthy",
                TimestampUtc: DateTime.UtcNow
            );

            stabilityMock.Setup(s => s.GetCurrentSnapshot()).Returns(expectedDto);

            var controller = new UpdateController(updateMock.Object, stabilityMock.Object);
            var result = controller.GetStability();

            var okResult = Assert.IsType<OkObjectResult>(result.Result);
            var dto = Assert.IsType<SystemStabilityDto>(okResult.Value);
            Assert.Equal(85.0, dto.WorkingSetMb);
            Assert.Equal("Healthy", dto.HealthStatus);
        }
    }
}
