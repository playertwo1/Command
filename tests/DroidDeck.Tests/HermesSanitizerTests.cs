using System.Collections.Generic;
using DroidDeck.Models;
using DroidDeck.Services;
using Xunit;

namespace DroidDeck.Tests
{
    public class HermesSanitizerTests
    {
        [Fact]
        public void SanitizeText_RedactsWindowsUserPaths()
        {
            string input = @"Arquivo confidencial em C:\Users\notefael\secret.txt e c:\users\admin\config.yaml";
            string result = HermesContextSanitizer.SanitizeText(input);

            Assert.Contains(@"C:\Users\[REDACTED]\secret.txt", result);
            Assert.Contains(@"C:\Users\[REDACTED]\config.yaml", result);
            Assert.DoesNotContain("notefael", result);
            Assert.DoesNotContain("admin", result);
        }

        [Fact]
        public void SanitizeText_RedactsPrivateIpv4Addresses()
        {
            string input = "Acessando host em 192.168.1.50, gateway 10.0.0.1 e subnet 172.20.10.5, com DNS 8.8.8.8";
            string result = HermesContextSanitizer.SanitizeText(input);

            Assert.Contains("xxx.xxx.*.***", result);
            Assert.DoesNotContain("192.168.1.50", result);
            Assert.DoesNotContain("10.0.0.1", result);
            Assert.DoesNotContain("172.20.10.5", result);
            Assert.Contains("8.8.8.8", result); // IP público deve ser preservado
        }

        [Fact]
        public void SanitizeText_RedactsBearerTokensAndApiKeys()
        {
            string input = "Header: Bearer abcdef123456 | OpenAI: sk-proj1234567890 | Gemini: AIzaSyA1234567890";
            string result = HermesContextSanitizer.SanitizeText(input);

            Assert.Contains("[REDACTED_KEY]", result);
            Assert.DoesNotContain("abcdef123456", result);
            Assert.DoesNotContain("sk-proj1234567890", result);
            Assert.DoesNotContain("AIzaSyA1234567890", result);
        }

        [Fact]
        public void BuildSanitizedTelemetryContext_GeneratesCleanSummaryWithoutLeaks()
        {
            var stats = new SystemStats
            {
                CpuUsage = 75.5f,
                RamUsage = 60.2f,
                RamTotal = 16384f,
                RamAvailable = 6500f,
                CpuTempC = 55f,
                BatteryPercent = 90,
                IsCharging = true,
                HasBattery = true
            };

            var topProcesses = new TopProcessesResponseDto
            {
                ByCpu = new List<TopProcessDto>
                {
                    new() { Pid = 1001, Name = @"code", CpuPercent = 25.4f, MemoryMB = 450f },
                    new() { Pid = 1002, Name = @"Users\notefael\app.exe", CpuPercent = 12.1f, MemoryMB = 200f }
                },
                ByMemory = new List<TopProcessDto>
                {
                    new() { Pid = 1001, Name = @"code", CpuPercent = 25.4f, MemoryMB = 450f }
                }
            };

            string summary = HermesContextSanitizer.BuildSanitizedTelemetryContext(stats, topProcesses);

            Assert.Contains("75.5%", summary);
            Assert.Contains("60.2%", summary);
            Assert.Contains("55.0 °C", summary);
            Assert.Contains("Bateria: 90% (Carregando)", summary);
            Assert.Contains("Top Processos por CPU:", summary);
            Assert.DoesNotContain("notefael", summary);
            Assert.Contains("[REDACTED]", summary);
        }
    }
}
