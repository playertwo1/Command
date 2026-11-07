using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Command.Controllers;
using Command.Models;
using Command.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Command.Tests
{
    public class RoutineServiceTests
    {
        private readonly AppCatalogService _appCatalog;

        public RoutineServiceTests()
        {
            _appCatalog = new AppCatalogService(NullLogger<AppCatalogService>.Instance);
        }

        [Fact]
        public void RoutineService_InitializesThreeDefaultPresets()
        {
            var service = new RoutineService(_appCatalog);
            var routines = service.GetRoutines();

            Assert.NotNull(routines);
            Assert.True(routines.Count >= 3);

            var studyVault = routines.FirstOrDefault(r => r.Id == "preset_study_vault");
            Assert.NotNull(studyVault);
            Assert.True(studyVault.IsPreset);
            Assert.True(studyVault.RequiresConfirmation);
            Assert.Equal(2, studyVault.Steps.Count);

            var devOrbit = routines.FirstOrDefault(r => r.Id == "preset_dev_orbit");
            Assert.NotNull(devOrbit);
            Assert.True(devOrbit.IsPreset);
            Assert.True(devOrbit.RequiresConfirmation);

            var focusCleanup = routines.FirstOrDefault(r => r.Id == "preset_focus_cleanup");
            Assert.NotNull(focusCleanup);
            Assert.True(focusCleanup.IsPreset);
            Assert.True(focusCleanup.RequiresConfirmation);
        }

        [Fact]
        public void RoutineService_SaveCustomRoutine_RejectsUnauthorizedAppsAndProtectedKills()
        {
            var service = new RoutineService(_appCatalog);

            // 1. Rejeita app arbitrário fora da allowlist (powershell)
            var routineWithShell = new RoutineDefinitionDto
            {
                Id = "custom_shell",
                Name = "Tentativa Shell",
                Steps = new List<RoutineStepDto>
                {
                    new() { ActionType = "app.launch", TargetId = "powershell" }
                }
            };
            Assert.Throws<InvalidOperationException>(() => service.SaveCustomRoutine(routineWithShell));

            // 2. Rejeita app arbitrário fora da allowlist (cmd)
            var routineWithCmd = new RoutineDefinitionDto
            {
                Id = "custom_cmd",
                Name = "Tentativa CMD",
                Steps = new List<RoutineStepDto>
                {
                    new() { ActionType = "app.launch", TargetId = "cmd" }
                }
            };
            Assert.Throws<InvalidOperationException>(() => service.SaveCustomRoutine(routineWithCmd));

            // 3. Rejeita app.kill em app protegido (obsidian possui CanKill=false)
            var routineKillObsidian = new RoutineDefinitionDto
            {
                Id = "custom_kill_obsidian",
                Name = "Encerrar Obsidian",
                Steps = new List<RoutineStepDto>
                {
                    new() { ActionType = "app.kill", TargetId = "obsidian" }
                }
            };
            Assert.Throws<InvalidOperationException>(() => service.SaveCustomRoutine(routineKillObsidian));

            // 4. Rejeita tipo de ação arbitrária desconhecida
            var routineInvalidAction = new RoutineDefinitionDto
            {
                Id = "custom_script",
                Name = "Script arbitrário",
                Steps = new List<RoutineStepDto>
                {
                    new() { ActionType = "bash.eval", TargetId = "script.sh" }
                }
            };
            Assert.Throws<InvalidOperationException>(() => service.SaveCustomRoutine(routineInvalidAction));
        }

        [Fact]
        public void RoutineService_SaveAndGet_AcceptsValidAllowlistSteps()
        {
            var service = new RoutineService(_appCatalog);

            var validCustom = new RoutineDefinitionDto
            {
                Id = "my_custom_routine",
                Name = "Minha Rotina Válida",
                Description = "Abre o Obsidian e aguarda",
                Icon = "star",
                Steps = new List<RoutineStepDto>
                {
                    new() { ActionType = "app.launch", TargetId = "obsidian", DelayMs = 200 },
                    new() { ActionType = "delay", DelayMs = 500 }
                }
            };

            var saved = service.SaveCustomRoutine(validCustom);
            Assert.NotNull(saved);
            Assert.False(saved.IsPreset);
            Assert.True(saved.RequiresConfirmation);

            var retrieved = service.GetRoutine("my_custom_routine");
            Assert.NotNull(retrieved);
            Assert.Equal("Minha Rotina Válida", retrieved.Name);
        }

        [Fact]
        public void RoutineService_DeleteCustomRoutine_AllowsDeletingPresetsAndCustomRoutines()
        {
            var service = new RoutineService(_appCatalog);

            // Preset agora pode ser excluído conforme solicitado pelo usuário (v1.6 Fase R4)
            bool deletedPreset = service.DeleteCustomRoutine("preset_study_vault");
            Assert.True(deletedPreset);
            Assert.Null(service.GetRoutine("preset_study_vault"));

            // Rotina customizada pode ser deletada
            var custom = new RoutineDefinitionDto
            {
                Id = "temp_routine",
                Name = "Rotina Temporária",
                Steps = new List<RoutineStepDto>
                {
                    new() { ActionType = "delay", DelayMs = 100 }
                }
            };
            service.SaveCustomRoutine(custom);
            Assert.NotNull(service.GetRoutine("temp_routine"));

            bool deletedCustom = service.DeleteCustomRoutine("temp_routine");
            Assert.True(deletedCustom);
            Assert.Null(service.GetRoutine("temp_routine"));
        }

        [Fact]
        public void RoutineService_PersistsEmptyListAfterDeletingLastRoutine()
        {
            var storagePath = Path.Combine(Path.GetTempPath(), $"command-routines-{Guid.NewGuid():N}.json");
            try
            {
                var service = new RoutineService(_appCatalog, storagePath: storagePath);
                foreach (var routine in service.GetRoutines().ToList())
                {
                    Assert.True(service.DeleteCustomRoutine(routine.Id));
                }

                Assert.Empty(service.GetRoutines());
                var restarted = new RoutineService(_appCatalog, storagePath: storagePath);
                Assert.Empty(restarted.GetRoutines());
            }
            finally
            {
                if (File.Exists(storagePath)) File.Delete(storagePath);
            }
        }

        [Fact]
        public void RoutineService_ExpandedActions_ValidatesShortcutsMediaAndPower()
        {
            var service = new RoutineService(_appCatalog);

            var validRoutine = new RoutineDefinitionDto
            {
                Id = "expanded_routine",
                Name = "Rotina Expandida",
                Steps = new List<RoutineStepDto>
                {
                    new() { ActionType = "system.shortcut", TargetId = "Win+D", DelayMs = 100 },
                    new() { ActionType = "media.control", TargetId = "play_pause", DelayMs = 100 },
                    new() { ActionType = "power.action", TargetId = "lock", DelayMs = 0 }
                }
            };

            var saved = service.SaveCustomRoutine(validRoutine);
            Assert.NotNull(saved);
            Assert.Equal(3, saved.Steps.Count);

            // Rejeita atalho inválido / shell injection
            var invalidShortcut = new RoutineDefinitionDto
            {
                Id = "invalid_shortcut",
                Name = "Atalho Inválido",
                Steps = new List<RoutineStepDto>
                {
                    new() { ActionType = "system.shortcut", TargetId = "rm -rf /" }
                }
            };
            Assert.Throws<InvalidOperationException>(() => service.SaveCustomRoutine(invalidShortcut));

            // Rejeita ação de energia fora da allowlist
            var invalidPower = new RoutineDefinitionDto
            {
                Id = "invalid_power",
                Name = "Ação de Energia Inválida",
                Steps = new List<RoutineStepDto>
                {
                    new() { ActionType = "power.action", TargetId = "explode" }
                }
            };
            Assert.Throws<InvalidOperationException>(() => service.SaveCustomRoutine(invalidPower));
        }

        [Fact]
        public async Task RoutineService_ExecuteRoutineAsync_RequiresConfirmation()
        {
            var service = new RoutineService(_appCatalog);

            // Sem confirmação explícita -> abortado
            var response = await service.ExecuteRoutineAsync("preset_study_vault", confirmed: false);

            Assert.Equal("aborted", response.OverallStatus);
            Assert.Empty(response.StepResults);
        }

        [Fact]
        public async Task RoutineService_ExecuteRoutineAsync_AbortOnFailure_SkipsSubsequentSteps()
        {
            var mockCatalog = new Mock<IAppCatalogService>();
            // Configura mock para permitir validação
            mockCatalog.Setup(c => c.TryGetApp("test_notepad", out It.Ref<AppCatalogItem>.IsAny))
                       .Returns((string id, out AppCatalogItem item) =>
                       {
                           item = new AppCatalogItem { Id = "test_notepad", Name = "Notepad", CanKill = true };
                           return true;
                       });

            // Porém a execução de KillAsync falha propositalmente
            mockCatalog.Setup(c => c.KillAsync("test_notepad", null, null))
                       .ReturnsAsync(new AppOperationResult { Success = false, ErrorMessage = "Processo travado ou inacessível." });

            var mockScreenshot = new Mock<IScreenshotService>();

            var service = new RoutineService(mockCatalog.Object, mockScreenshot.Object);

            var routine = new RoutineDefinitionDto
            {
                Id = "fail_test_routine",
                Name = "Rotina com Falha",
                Steps = new List<RoutineStepDto>
                {
                    new()
                    {
                        StepId = "step_1_kill",
                        ActionType = "app.kill",
                        TargetId = "test_notepad",
                        ContinueOnError = false // Interrompe próximos passos
                    },
                    new()
                    {
                        StepId = "step_2_screenshot",
                        ActionType = "screenshot.capture",
                        TargetId = "primary",
                        ContinueOnError = true
                    }
                }
            };
            service.SaveCustomRoutine(routine);

            var result = await service.ExecuteRoutineAsync("fail_test_routine", confirmed: true);

            Assert.Equal("failed", result.OverallStatus);
            Assert.Equal(2, result.StepResults.Count);

            // Passo 1 falhou
            Assert.Equal("failed", result.StepResults[0].Status);
            Assert.Contains("Processo travado", result.StepResults[0].ErrorMessage);

            // Passo 2 foi skipped devido a ContinueOnError == false
            Assert.Equal("skipped", result.StepResults[1].Status);
            mockScreenshot.Verify(s => s.CapturePrimaryScreen(It.IsAny<string>(), It.IsAny<string>()), Times.Never);
        }

        [Fact]
        public async Task RoutinesController_EndpointsWorkProperly()
        {
            var service = new RoutineService(_appCatalog);
            var webhook = new WebhookNotificationService();
            var controller = new RoutinesController(service, webhook);

            // GET routines
            var listResult = controller.GetRoutines();
            var okList = Assert.IsType<OkObjectResult>(listResult.Result);
            var routines = Assert.IsAssignableFrom<IReadOnlyList<RoutineDefinitionDto>>(okList.Value);
            Assert.True(routines.Count >= 3);

            // POST save custom routine
            var saveResult = controller.SaveCustomRoutine(new RoutineDefinitionDto
            {
                Id = "ctrl_custom",
                Name = "Rotina do Controller",
                Steps = new List<RoutineStepDto>
                {
                    new() { ActionType = "delay", DelayMs = 50 }
                }
            });
            var okSave = Assert.IsType<OkObjectResult>(saveResult.Result);
            var savedRoutine = Assert.IsType<RoutineDefinitionDto>(okSave.Value);
            Assert.Equal("ctrl_custom", savedRoutine.Id);

            // POST execute
            var execResult = await controller.ExecuteRoutine("ctrl_custom", confirmed: true);
            var okExec = Assert.IsType<OkObjectResult>(execResult.Result);
            var execResp = Assert.IsType<RoutineExecutionResponse>(okExec.Value);
            Assert.Equal("succeeded", execResp.OverallStatus);

            // GET & POST webhook
            var getWebhookRes = controller.GetWebhookConfig();
            var okWebhook = Assert.IsType<OkObjectResult>(getWebhookRes.Result);
            var webhookConfig = Assert.IsType<WebhookConfigDto>(okWebhook.Value);
            Assert.False(webhookConfig.Enabled);

            var updateWebhookRes = controller.UpdateWebhookConfig(new WebhookUpdateConfigRequest
            {
                Enabled = true,
                WebhookUrl = "https://discord.com/webhook/test"
            });
            var okUpdateWebhook = Assert.IsType<OkObjectResult>(updateWebhookRes.Result);
            var updatedConfig = Assert.IsType<WebhookConfigDto>(okUpdateWebhook.Value);
            Assert.True(updatedConfig.Enabled);
            Assert.True(updatedConfig.HasWebhookUrl);
        }
    }
}
