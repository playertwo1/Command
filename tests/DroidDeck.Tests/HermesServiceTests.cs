using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using DroidDeck.Controllers;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace DroidDeck.Tests
{
    public class HermesServiceTests
    {
        private readonly AppCatalogService _appCatalog;

        public HermesServiceTests()
        {
            _appCatalog = new AppCatalogService(NullLogger<AppCatalogService>.Instance);
        }

        [Fact]
        public async Task HermesService_BlocksCalls_WhenDisabled()
        {
            var service = new HermesService(_appCatalog);

            var status = service.GetStatus();
            Assert.False(status.Enabled);

            var response = await service.AnalyzeAsync(new HermesAnalyzeRequest
            {
                Prompt = "Como está o uso de memória?"
            });

            Assert.False(response.Success);
            Assert.Equal("HERMES_DISABLED", response.ErrorCode);
            Assert.Contains("desativado", response.ErrorMessage);
        }

        [Fact]
        public void HermesService_FilterAllowedActions_EnforcesAllowlistAndCanKillRules()
        {
            var service = new HermesService(_appCatalog);

            var candidates = new List<HermesSuggestedActionDto>
            {
                // Permitidos
                new() { ActionType = "app.launch", TargetId = "obsidian", Title = "Abrir Obsidian" },
                new() { ActionType = "app.kill", TargetId = "test_notepad", Title = "Encerrar Notepad" },
                new() { ActionType = "screenshot.capture", TargetId = "primary", Title = "Print da tela" },

                // Proibidos / Violam Allowlist ou CanKill
                new() { ActionType = "app.kill", TargetId = "obsidian", Title = "Matar Obsidian (Proibido CanKill=false)" },
                new() { ActionType = "app.launch", TargetId = "powershell", Title = "PowerShell Arbitrário" },
                new() { ActionType = "app.kill", TargetId = "cmd", Title = "CMD Arbitrário" },
                new() { ActionType = "app.launch", TargetId = "unknown_app", Title = "App Desconhecido" }
            };

            var filtered = service.FilterAllowedActions(candidates);

            Assert.Equal(3, filtered.Count);

            // Verifica que obsidian (launch) e test_notepad (kill) foram mantidos
            Assert.Contains(filtered, a => a.ActionType == "app.launch" && a.TargetId == "obsidian");
            Assert.Contains(filtered, a => a.ActionType == "app.kill" && a.TargetId == "test_notepad");
            Assert.Contains(filtered, a => a.ActionType == "screenshot.capture" && a.TargetId == "primary");

            // Verifica que todos exigem confirmação explícita
            Assert.All(filtered, a => Assert.True(a.RequiresConfirmation));

            // Garante que apps fora da allowlist ou protegidos foram excluídos
            Assert.DoesNotContain(filtered, a => a.TargetId == "powershell");
            Assert.DoesNotContain(filtered, a => a.TargetId == "cmd");
            Assert.DoesNotContain(filtered, a => a.TargetId == "unknown_app");
            Assert.DoesNotContain(filtered, a => a.ActionType == "app.kill" && a.TargetId == "obsidian");
        }

        [Fact]
        public async Task HermesService_AnalyzeAsync_WhenEnabled_ReturnsSuccessAndSanitizedSummary()
        {
            var mockTopProcesses = new Mock<ITopProcessesService>();
            mockTopProcesses.Setup(m => m.GetTopProcesses(It.IsAny<int>())).Returns(new TopProcessesResponseDto
            {
                ByCpu = new List<TopProcessDto>
                {
                    new() { Pid = 42, Name = "Obsidian", CpuPercent = 5.2f, MemoryMB = 350f }
                }
            });

            var service = new HermesService(_appCatalog, mockTopProcesses.Object);
            service.UpdateConfig(new HermesUpdateConfigRequest { Enabled = true });

            var request = new HermesAnalyzeRequest
            {
                Prompt = @"Gostaria de abrir o obsidian para editar minhas notas em C:\Users\notefael\Desktop",
                IncludeTelemetry = true,
                IncludeTopProcesses = true
            };

            var response = await service.AnalyzeAsync(request);

            Assert.True(response.Success);
            Assert.NotNull(response.Reply);
            Assert.Contains("Obsidian", response.Reply);

            // Contexto sanitizado sem vazar caminho do usuário
            Assert.NotNull(response.SanitizedContextSummary);
            Assert.DoesNotContain("notefael", response.SanitizedContextSummary);

            // Sugestão válida presente na allowlist
            Assert.Single(response.SuggestedActions);
            var action = response.SuggestedActions[0];
            Assert.Equal("app.launch", action.ActionType);
            Assert.Equal("obsidian", action.TargetId);
            Assert.True(action.RequiresConfirmation);
        }

        [Fact]
        public async Task HermesService_AnalyzeAsync_RejectsInvalidOrExpiredScreenshot()
        {
            var mockScreenshot = new Mock<IScreenshotService>();
            mockScreenshot.Setup(s => s.GetMetadata("invalid-shot")).Returns((ScreenshotInfoDto?)null);

            var service = new HermesService(_appCatalog, screenshotService: mockScreenshot.Object);
            service.UpdateConfig(new HermesUpdateConfigRequest { Enabled = true });

            var response = await service.AnalyzeAsync(new HermesAnalyzeRequest
            {
                Prompt = "Analise esta captura",
                ScreenshotId = "invalid-shot"
            });

            Assert.False(response.Success);
            Assert.Equal("SCREENSHOT_UNAVAILABLE", response.ErrorCode);
        }

        [Fact]
        public void HermesService_Config_NeverExposesApiKeyInGet()
        {
            var service = new HermesService(_appCatalog);

            var updated = service.UpdateConfig(new HermesUpdateConfigRequest
            {
                Enabled = true,
                EndpointUrl = "https://generativelanguage.googleapis.com",
                ModelName = "gemini-3.8-flash",
                ApiKey = "secret-super-key-12345"
            });

            Assert.True(updated.Enabled);
            Assert.True(updated.HasApiKey);

            var status = service.GetStatus();
            Assert.True(status.Enabled);
            Assert.True(status.HasApiKey);
            Assert.Equal("https://generativelanguage.googleapis.com", status.EndpointUrl);
            Assert.Equal("gemini-3.8-flash", status.ModelName);
        }

        [Fact]
        public async Task HermesController_EndpointsWorkProperly()
        {
            var service = new HermesService(_appCatalog);
            var controller = new HermesController(service);

            // GET status
            var statusResult = controller.GetStatus();
            var okStatus = Assert.IsType<OkObjectResult>(statusResult.Result);
            var config = Assert.IsType<HermesConfigDto>(okStatus.Value);
            Assert.False(config.Enabled);

            // POST config
            var updateResult = controller.UpdateConfig(new HermesUpdateConfigRequest
            {
                Enabled = true,
                ApiKey = "AIzaSyTest123"
            });
            var okUpdate = Assert.IsType<OkObjectResult>(updateResult.Result);
            var updatedConfig = Assert.IsType<HermesConfigDto>(okUpdate.Value);
            Assert.True(updatedConfig.Enabled);
            Assert.True(updatedConfig.HasApiKey);

            // POST analyze
            var analyzeResult = await controller.Analyze(new HermesAnalyzeRequest
            {
                Prompt = "Preciso encerrar o bloco de notas de teste"
            }, deviceId: "device-test-01");

            var okAnalyze = Assert.IsType<OkObjectResult>(analyzeResult.Result);
            var analyzeResp = Assert.IsType<HermesAnalyzeResponse>(okAnalyze.Value);
            Assert.True(analyzeResp.Success);
            Assert.Contains(analyzeResp.SuggestedActions, a => a.ActionType == "app.kill" && a.TargetId == "test_notepad");
        }
    }
}
