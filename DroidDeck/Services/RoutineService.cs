using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Models;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    public class RoutineService : IRoutineService
    {
        private readonly IAppCatalogService _appCatalog;
        private readonly IScreenshotService? _screenshotService;
        private readonly IWebhookNotificationService? _webhookService;
        private readonly ILogger<RoutineService>? _logger;

        private readonly ConcurrentDictionary<string, RoutineDefinitionDto> _routines = new(StringComparer.OrdinalIgnoreCase);

        private static readonly HashSet<string> AllowedActionTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            "app.launch",
            "app.kill",
            "screenshot.capture",
            "delay"
        };

        public RoutineService(
            IAppCatalogService appCatalog,
            IScreenshotService? screenshotService = null,
            IWebhookNotificationService? webhookService = null,
            ILogger<RoutineService>? logger = null)
        {
            _appCatalog = appCatalog ?? throw new ArgumentNullException(nameof(appCatalog));
            _screenshotService = screenshotService;
            _webhookService = webhookService;
            _logger = logger;

            InitializeDefaultPresets();
        }

        private void InitializeDefaultPresets()
        {
            // 1. Preset Estudo & Vault (Obsidian + Screenshot de verificação)
            var studyVault = new RoutineDefinitionDto
            {
                Id = "preset_study_vault",
                Name = "Modo Estudo & Vault",
                Description = "Abre o Obsidian e registra o estado visual da tela principal",
                Icon = "menu_book",
                IsPreset = true,
                RequiresConfirmation = true,
                Steps = new List<RoutineStepDto>
                {
                    new()
                    {
                        StepId = "step_obsidian_launch",
                        ActionType = "app.launch",
                        TargetId = "obsidian",
                        DelayMs = 300,
                        ContinueOnError = false
                    },
                    new()
                    {
                        StepId = "step_vault_shot",
                        ActionType = "screenshot.capture",
                        TargetId = "primary",
                        DelayMs = 0,
                        ContinueOnError = true
                    }
                }
            };

            // 2. Preset Dev Orbit (Orbit PJ + Obsidian)
            var devOrbit = new RoutineDefinitionDto
            {
                Id = "preset_dev_orbit",
                Name = "Modo Dev Orbit",
                Description = "Inicia o projeto Orbit PJ e abre o Obsidian para anotações técnicas",
                Icon = "terminal",
                IsPreset = true,
                RequiresConfirmation = true,
                Steps = new List<RoutineStepDto>
                {
                    new()
                    {
                        StepId = "step_orbit_launch",
                        ActionType = "app.launch",
                        TargetId = "orbit",
                        DelayMs = 300,
                        ContinueOnError = false
                    },
                    new()
                    {
                        StepId = "step_notes_launch",
                        ActionType = "app.launch",
                        TargetId = "obsidian",
                        DelayMs = 0,
                        ContinueOnError = false
                    }
                }
            };

            // 3. Preset Limpeza de Foco (Encerra app de teste + captura de confirmação)
            var focusCleanup = new RoutineDefinitionDto
            {
                Id = "preset_focus_cleanup",
                Name = "Limpeza de Foco",
                Description = "Encerra aplicativos de teste e captura o monitor principal para validação",
                Icon = "cleaning_services",
                IsPreset = true,
                RequiresConfirmation = true,
                Steps = new List<RoutineStepDto>
                {
                    new()
                    {
                        StepId = "step_notepad_kill",
                        ActionType = "app.kill",
                        TargetId = "test_notepad",
                        DelayMs = 200,
                        ContinueOnError = false
                    },
                    new()
                    {
                        StepId = "step_cleanup_shot",
                        ActionType = "screenshot.capture",
                        TargetId = "primary",
                        DelayMs = 0,
                        ContinueOnError = true
                    }
                }
            };

            _routines[studyVault.Id] = studyVault;
            _routines[devOrbit.Id] = devOrbit;
            _routines[focusCleanup.Id] = focusCleanup;
        }

        public IReadOnlyList<RoutineDefinitionDto> GetRoutines()
        {
            return _routines.Values.OrderByDescending(r => r.IsPreset).ThenBy(r => r.Name).ToList();
        }

        public RoutineDefinitionDto? GetRoutine(string id)
        {
            if (string.IsNullOrWhiteSpace(id)) return null;
            return _routines.TryGetValue(id, out var routine) ? routine : null;
        }

        public RoutineDefinitionDto SaveCustomRoutine(RoutineDefinitionDto routine)
        {
            if (routine == null) throw new ArgumentNullException(nameof(routine));

            if (string.IsNullOrWhiteSpace(routine.Id))
            {
                routine.Id = "routine_" + Guid.NewGuid().ToString("N")[..8];
            }

            if (_routines.TryGetValue(routine.Id, out var existing) && existing.IsPreset)
            {
                throw new InvalidOperationException("Não é permitido sobrescrever rotinas predefinidas (presets).");
            }

            // Validação estrita de cada passo (Regra 3 - Allowlist e Ações Tipadas)
            ValidateRoutineSteps(routine.Steps);

            routine.IsPreset = false;
            routine.RequiresConfirmation = true; // Confirmação obrigatória
            foreach (var step in routine.Steps)
            {
                step.DelayMs = Math.Clamp(step.DelayMs, 0, 10000);
            }

            _routines[routine.Id] = routine;
            _logger?.LogInformation("Rotina customizada '{Id}' ('{Name}') salva com {Count} passos", routine.Id, routine.Name, routine.Steps.Count);
            return routine;
        }

        public bool DeleteCustomRoutine(string id)
        {
            if (string.IsNullOrWhiteSpace(id)) return false;

            if (_routines.TryGetValue(id, out var routine))
            {
                if (routine.IsPreset)
                {
                    _logger?.LogWarning("Tentativa de excluir preset bloqueada para '{Id}'", id);
                    return false;
                }

                return _routines.TryRemove(id, out _);
            }

            return false;
        }

        public async Task<RoutineExecutionResponse> ExecuteRoutineAsync(
            string id,
            bool confirmed,
            string? deviceId = null,
            CancellationToken ct = default)
        {
            var startedAt = DateTime.UtcNow;

            var routine = GetRoutine(id);
            if (routine == null)
            {
                return new RoutineExecutionResponse
                {
                    RoutineId = id,
                    RoutineName = "Desconhecida",
                    OverallStatus = "failed",
                    StepResults = new List<RoutineStepResultDto>
                    {
                        new()
                        {
                            StepId = "init",
                            ActionType = "none",
                            TargetId = id,
                            Status = "failed",
                            ErrorMessage = $"Rotina '{id}' não encontrada."
                        }
                    },
                    StartedAtUtc = startedAt,
                    CompletedAtUtc = DateTime.UtcNow
                };
            }

            // Exige confirmação explícita para evitar disparo acidental
            if (!confirmed)
            {
                _logger?.LogWarning("Execução da rotina '{Id}' abortada: falta confirmação explícita", id);
                return new RoutineExecutionResponse
                {
                    RoutineId = routine.Id,
                    RoutineName = routine.Name,
                    OverallStatus = "aborted",
                    StepResults = new List<RoutineStepResultDto>(),
                    StartedAtUtc = startedAt,
                    CompletedAtUtc = DateTime.UtcNow
                };
            }

            // Validação estrita de allowlist antes de iniciar qualquer execução
            try
            {
                ValidateRoutineSteps(routine.Steps);
            }
            catch (Exception ex)
            {
                _logger?.LogError(ex, "Execução da rotina '{Id}' bloqueada por violação da allowlist", id);
                return new RoutineExecutionResponse
                {
                    RoutineId = routine.Id,
                    RoutineName = routine.Name,
                    OverallStatus = "failed",
                    StepResults = new List<RoutineStepResultDto>
                    {
                        new()
                        {
                            StepId = "validation",
                            ActionType = "security_check",
                            TargetId = id,
                            Status = "failed",
                            ErrorMessage = ex.Message
                        }
                    },
                    StartedAtUtc = startedAt,
                    CompletedAtUtc = DateTime.UtcNow
                };
            }

            var results = new List<RoutineStepResultDto>();
            bool hadFailure = false;

            for (int i = 0; i < routine.Steps.Count; i++)
            {
                var step = routine.Steps[i];

                if (hadFailure)
                {
                    // Passos seguintes a uma falha com ContinueOnError == false são marcados como skipped
                    results.Add(new RoutineStepResultDto
                    {
                        StepId = step.StepId,
                        ActionType = step.ActionType,
                        TargetId = step.TargetId,
                        Status = "skipped",
                        ErrorMessage = "Interrompido por falha no passo anterior.",
                        DurationMs = 0
                    });
                    continue;
                }

                ct.ThrowIfCancellationRequested();

                var sw = Stopwatch.StartNew();
                var stepResult = new RoutineStepResultDto
                {
                    StepId = step.StepId,
                    ActionType = step.ActionType,
                    TargetId = step.TargetId
                };

                try
                {
                    await ExecuteSingleStepAsync(step, stepResult, deviceId, ct);
                }
                catch (Exception ex)
                {
                    stepResult.Status = "failed";
                    stepResult.ErrorMessage = ex.Message;
                }
                finally
                {
                    sw.Stop();
                    stepResult.DurationMs = sw.ElapsedMilliseconds;
                }

                results.Add(stepResult);

                if (stepResult.Status == "failed")
                {
                    if (!step.ContinueOnError)
                    {
                        hadFailure = true;
                    }
                }
            }

            // Determina OverallStatus
            string overallStatus;
            int succeededCount = results.Count(r => r.Status == "succeeded");
            int failedCount = results.Count(r => r.Status == "failed");

            if (failedCount == 0 && succeededCount == results.Count)
            {
                overallStatus = "succeeded";
            }
            else if (succeededCount > 0 && failedCount > 0)
            {
                overallStatus = "partial_failure";
            }
            else
            {
                overallStatus = "failed";
            }

            var completedAt = DateTime.UtcNow;
            var response = new RoutineExecutionResponse
            {
                RoutineId = routine.Id,
                RoutineName = routine.Name,
                OverallStatus = overallStatus,
                StepResults = results,
                StartedAtUtc = startedAt,
                CompletedAtUtc = completedAt
            };

            // Notificação assíncrona sanitizada via Webhook (se configurado)
            if (_webhookService != null && _webhookService.GetConfig().NotifyOnRoutineComplete)
            {
                _ = Task.Run(async () =>
                {
                    try
                    {
                        string title = $"Rotina {routine.Name}: {overallStatus.ToUpperInvariant()}";
                        string body = $"Execução concluída com status '{overallStatus}'. Passos com sucesso: {succeededCount}/{results.Count}.";
                        await _webhookService.SendNotificationAsync(title, body, ct);
                    }
                    catch { }
                }, ct);
            }

            return response;
        }

        private async Task ExecuteSingleStepAsync(
            RoutineStepDto step,
            RoutineStepResultDto result,
            string? deviceId,
            CancellationToken ct)
        {
            if (string.Equals(step.ActionType, "delay", StringComparison.OrdinalIgnoreCase))
            {
                int delay = Math.Clamp(step.DelayMs, 0, 10000);
                if (delay > 0)
                {
                    await Task.Delay(delay, ct);
                }
                result.Status = "succeeded";
                return;
            }

            if (string.Equals(step.ActionType, "app.launch", StringComparison.OrdinalIgnoreCase))
            {
                var launchRes = await _appCatalog.LaunchAsync(step.TargetId);
                if (launchRes.Success)
                {
                    result.Status = "succeeded";
                    result.JobId = launchRes.ProcessId?.ToString();
                }
                else
                {
                    result.Status = "failed";
                    result.ErrorMessage = launchRes.ErrorMessage ?? "Falha ao iniciar app";
                }
            }
            else if (string.Equals(step.ActionType, "app.kill", StringComparison.OrdinalIgnoreCase))
            {
                var killRes = await _appCatalog.KillAsync(step.TargetId);
                if (killRes.Success)
                {
                    result.Status = "succeeded";
                    result.JobId = killRes.ProcessId?.ToString();
                }
                else
                {
                    result.Status = "failed";
                    result.ErrorMessage = killRes.ErrorMessage ?? "Falha ao encerrar app";
                }
            }
            else if (string.Equals(step.ActionType, "screenshot.capture", StringComparison.OrdinalIgnoreCase))
            {
                if (_screenshotService != null)
                {
                    var reqId = Guid.NewGuid().ToString("N");
                    var shot = _screenshotService.CapturePrimaryScreen(reqId, deviceId);
                    if (shot.Success)
                    {
                        result.Status = "succeeded";
                        result.JobId = shot.Metadata?.Id;
                    }
                    else
                    {
                        result.Status = "failed";
                        result.ErrorMessage = shot.ErrorMessage ?? "Falha na captura de tela";
                    }
                }
                else
                {
                    result.Status = "succeeded";
                }
            }
            else
            {
                result.Status = "failed";
                result.ErrorMessage = $"Tipo de ação não suportado: '{step.ActionType}'";
            }

            // Delay pós-passo se configurado
            if (step.DelayMs > 0 && result.Status == "succeeded")
            {
                await Task.Delay(Math.Clamp(step.DelayMs, 0, 10000), ct);
            }
        }

        private void ValidateRoutineSteps(IEnumerable<RoutineStepDto> steps)
        {
            if (steps == null) return;

            foreach (var step in steps)
            {
                if (string.IsNullOrWhiteSpace(step.ActionType) || !AllowedActionTypes.Contains(step.ActionType))
                {
                    throw new InvalidOperationException($"Ação '{step.ActionType}' não é permitida pelo motor de rotinas.");
                }

                if (string.Equals(step.ActionType, "app.launch", StringComparison.OrdinalIgnoreCase))
                {
                    bool exists = _appCatalog.TryGetApp(step.TargetId, out _);
                    if (!exists)
                    {
                        var allowed = _appCatalog.GetAllowedApps();
                        exists = allowed != null && allowed.Any(a => string.Equals(a.Id, step.TargetId, StringComparison.OrdinalIgnoreCase));
                    }

                    if (!exists)
                    {
                        throw new InvalidOperationException($"Aplicativo '{step.TargetId}' não está autorizado na allowlist.");
                    }
                }
                else if (string.Equals(step.ActionType, "app.kill", StringComparison.OrdinalIgnoreCase))
                {
                    bool canKill = false;
                    if (_appCatalog.TryGetApp(step.TargetId, out var item) && item != null)
                    {
                        canKill = item.CanKill;
                    }
                    else
                    {
                        var allowed = _appCatalog.GetAllowedApps();
                        var summary = allowed?.FirstOrDefault(a => string.Equals(a.Id, step.TargetId, StringComparison.OrdinalIgnoreCase));
                        canKill = summary != null && summary.CanKill;
                    }

                    if (!canKill)
                    {
                        throw new InvalidOperationException($"O aplicativo '{step.TargetId}' não está autorizado para encerramento (CanKill=false ou fora da allowlist).");
                    }
                }
            }
        }
    }
}
