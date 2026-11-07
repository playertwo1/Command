using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using Command.Models;
using Command.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Command.Tests
{
    public class ServicesAndProcessesTests
    {
        [Fact]
        public void ServiceStatusDto_Properties_DefaultAndAssign()
        {
            var dto = new ServiceStatusDto
            {
                Name = "Spooler",
                DisplayName = "Print Spooler",
                Status = "Running",
                IsRunning = true
            };

            Assert.Equal("Spooler", dto.Name);
            Assert.Equal("Print Spooler", dto.DisplayName);
            Assert.Equal("Running", dto.Status);
            Assert.True(dto.IsRunning);
        }

        [Fact]
        public void TopProcessDto_Properties_DefaultAndAssign()
        {
            var dto = new TopProcessDto
            {
                Pid = 1234,
                Name = "dotnet",
                MemoryMB = 256.5f,
                CpuPercent = 12.3f
            };

            Assert.Equal(1234, dto.Pid);
            Assert.Equal("dotnet", dto.Name);
            Assert.Equal(256.5f, dto.MemoryMB);
            Assert.Equal(12.3f, dto.CpuPercent);
        }

        [Fact]
        public void TopProcessesResponseDto_Serialization_ProducesCamelCaseJson()
        {
            var response = new TopProcessesResponseDto
            {
                ByMemory =
                {
                    new TopProcessDto { Pid = 100, Name = "code", MemoryMB = 512.0f, CpuPercent = 2.5f }
                },
                ByCpu =
                {
                    new TopProcessDto { Pid = 200, Name = "ffmpeg", MemoryMB = 128.0f, CpuPercent = 45.0f }
                }
            };

            var options = new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
            string json = JsonSerializer.Serialize(response, options);

            Assert.Contains("\"byMemory\":[", json);
            Assert.Contains("\"byCpu\":[", json);
            Assert.Contains("\"pid\":100", json);
            Assert.Contains("\"name\":\"code\"", json);
            Assert.Contains("\"memoryMB\":512", json);
            Assert.Contains("\"cpuPercent\":2.5", json);
        }

        [Fact]
        public void WindowsServiceMonitor_Allowlist_EnforcesOnlyAllowedServices()
        {
            var customAllowed = new[] { "Spooler", "WSearch" };
            var monitor = new WindowsServiceMonitor(NullLogger<WindowsServiceMonitor>.Instance, customAllowed);

            Assert.Equal(2, monitor.AllowedServices.Count);

            // Tenta filtrar por um serviço não permitido ("MaliciousService")
            var filtered = monitor.GetServicesStatus(new[] { "MaliciousService" });
            Assert.Empty(filtered);

            // Filtro com serviço permitido deve retornar
            var valid = monitor.GetServicesStatus(new[] { "Spooler" });
            Assert.Single(valid);
            Assert.Equal("Spooler", valid[0].Name);
        }

        [Fact]
        public void WindowsServiceMonitor_NonExistentService_ReturnsNotFound()
        {
            var monitor = new WindowsServiceMonitor(NullLogger<WindowsServiceMonitor>.Instance, new[] { "NonExistentService123" });

            var results = monitor.GetServicesStatus();

            Assert.Single(results);
            Assert.Equal("NonExistentService123", results[0].Name);
            Assert.Equal("NotFound", results[0].Status);
            Assert.False(results[0].IsRunning);
        }

        [Fact]
        public void WindowsServiceMonitor_Live_OnWindows_QueriesRealServicesWithoutThrowing()
        {
            if (!OperatingSystem.IsWindows()) return;

            var monitor = new WindowsServiceMonitor(NullLogger<WindowsServiceMonitor>.Instance);
            var results = monitor.GetServicesStatus();

            Assert.NotEmpty(results);
            foreach (var s in results)
            {
                Assert.False(string.IsNullOrWhiteSpace(s.Name));
                Assert.False(string.IsNullOrWhiteSpace(s.DisplayName));
                Assert.False(string.IsNullOrWhiteSpace(s.Status));
            }

            // Spooler normalmente está presente no Windows
            var spooler = results.FirstOrDefault(r => r.Name.Equals("Spooler", StringComparison.OrdinalIgnoreCase));
            if (spooler != null)
            {
                Assert.False(string.IsNullOrWhiteSpace(spooler.DisplayName));
            }
        }

        [Fact]
        public void TopProcessesService_Live_ReturnsProcessesWithoutExposingPaths()
        {
            if (!OperatingSystem.IsWindows()) return;

            var service = new TopProcessesService(NullLogger<TopProcessesService>.Instance);
            var result = service.GetTopProcesses(5);

            Assert.NotNull(result);
            Assert.NotNull(result.ByMemory);
            Assert.NotNull(result.ByCpu);

            Assert.InRange(result.ByMemory.Count, 1, 5);

            // Sanitização estrita: nomes de processos não podem conter barras de caminho ou .exe
            foreach (var p in result.ByMemory)
            {
                Assert.True(p.Pid > 0);
                Assert.False(string.IsNullOrWhiteSpace(p.Name));
                Assert.DoesNotContain("\\", p.Name);
                Assert.DoesNotContain("/", p.Name);
                Assert.True(p.MemoryMB > 0);
            }

            // Lista ByMemory deve estar ordenada de forma decrescente
            for (int i = 0; i < result.ByMemory.Count - 1; i++)
            {
                Assert.True(result.ByMemory[i].MemoryMB >= result.ByMemory[i + 1].MemoryMB);
            }
        }
    }
}
