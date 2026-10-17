using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using DroidDeck.Models;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    public class AppCatalogService : IAppCatalogService
    {
        private readonly ILogger<AppCatalogService> _logger;
        private readonly Dictionary<string, AppCatalogItem> _allowedApps = new(StringComparer.OrdinalIgnoreCase);

        public AppCatalogService(ILogger<AppCatalogService> logger)
        {
            _logger = logger;
            RegisterDefaultAllowedApps();
        }

        private void RegisterDefaultAllowedApps()
        {
            // 1. Obsidian (FL-1)
            var obsidianPath = ResolveObsidianPath();
            _allowedApps["obsidian"] = new AppCatalogItem
            {
                Id = "obsidian",
                Name = "Obsidian",
                Description = "Base de conhecimento e notas (NexusVault)",
                Icon = "description",
                CanKill = false,
                Executable = obsidianPath ?? "obsidian://open",
                ProcessName = "Obsidian"
            };

            // 2. Orbit PJ (FL-2)
            var orbitProjectDir = @"C:\Users\notefael\projetos\orbit-pj";
            var editorPath = ResolveCodeEditorPath();
            _allowedApps["orbit"] = new AppCatalogItem
            {
                Id = "orbit",
                Name = "Orbit PJ",
                Description = "Projeto Orbit no VS Code",
                Icon = "terminal",
                CanKill = false,
                Executable = editorPath ?? "explorer.exe",
                Arguments = $"\"{orbitProjectDir}\"",
                ProcessName = "Code"
            };

            // 3. Bloco de Notas de Teste (FL-5) - permitido encerrar para testes de validação
            _allowedApps["test_notepad"] = new AppCatalogItem
            {
                Id = "test_notepad",
                Name = "Bloco de Notas (Teste)",
                Description = "App de teste para abertura e encerramento controlado",
                Icon = "edit_note",
                CanKill = true,
                Executable = "notepad.exe",
                ProcessName = "notepad"
            };
        }

        private static string? ResolveObsidianPath()
        {
            string[] possiblePaths =
            {
                @"C:\Program Files\Obsidian\Obsidian.exe",
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Programs\Obsidian\Obsidian.exe")
            };

            foreach (var p in possiblePaths)
            {
                if (File.Exists(p)) return p;
            }
            return null;
        }

        private static string? ResolveCodeEditorPath()
        {
            var localApp = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string[] possiblePaths =
            {
                Path.Combine(localApp, @"Programs\Microsoft VS Code\bin\code.cmd"),
                Path.Combine(localApp, @"Programs\Microsoft VS Code\Code.exe"),
                @"C:\Program Files\Microsoft VS Code\bin\code.cmd"
            };

            foreach (var p in possiblePaths)
            {
                if (File.Exists(p)) return p;
            }
            return null;
        }

        public IReadOnlyList<AppSummaryDto> GetAllowedApps()
        {
            var list = new List<AppSummaryDto>();
            foreach (var item in _allowedApps.Values)
            {
                list.Add(BuildSummary(item));
            }
            return list;
        }

        public bool TryGetApp(string id, out AppCatalogItem item) =>
            _allowedApps.TryGetValue(id, out item!);

        public AppSummaryDto? GetAppSummary(string id)
        {
            if (_allowedApps.TryGetValue(id, out var item))
            {
                return BuildSummary(item);
            }
            return null;
        }

        private static AppSummaryDto BuildSummary(AppCatalogItem item)
        {
            bool isRunning = false;
            int? pid = null;
            DateTime? startTimeUtc = null;

            try
            {
                var processes = Process.GetProcessesByName(item.ProcessName);
                if (processes.Length > 0)
                {
                    var p = processes[0];
                    isRunning = true;
                    pid = p.Id;
                    try
                    {
                        startTimeUtc = p.StartTime.ToUniversalTime();
                    }
                    catch { }
                }
            }
            catch { }

            return new AppSummaryDto
            {
                Id = item.Id,
                Name = item.Name,
                Description = item.Description,
                Icon = item.Icon,
                CanKill = item.CanKill,
                IsRunning = isRunning,
                ProcessId = pid,
                StartTimeUtc = startTimeUtc
            };
        }

        public Task<AppOperationResult> LaunchAsync(string id)
        {
            if (!_allowedApps.TryGetValue(id, out var app))
            {
                return Task.FromResult(new AppOperationResult
                {
                    Success = false,
                    ErrorMessage = $"Aplicativo com ID '{id}' não está na allowlist de programas autorizados."
                });
            }

            try
            {
                _logger.LogInformation("Iniciando app autorizado '{Id}' ({Name})", app.Id, app.Name);
                var startInfo = new ProcessStartInfo
                {
                    FileName = app.Executable,
                    Arguments = app.Arguments ?? "",
                    UseShellExecute = true
                };

                var proc = Process.Start(startInfo);
                return Task.FromResult(new AppOperationResult
                {
                    Success = true,
                    ProcessId = proc?.Id
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Falha ao iniciar app '{Id}'", id);
                return Task.FromResult(new AppOperationResult
                {
                    Success = false,
                    ErrorMessage = $"Falha ao iniciar o aplicativo: {ex.Message}"
                });
            }
        }

        public async Task<AppOperationResult> KillAsync(string id, int? expectedPid = null, DateTime? expectedStartTimeUtc = null)
        {
            if (!_allowedApps.TryGetValue(id, out var app))
            {
                return new AppOperationResult
                {
                    Success = false,
                    ErrorMessage = $"Aplicativo '{id}' não encontrado na allowlist."
                };
            }

            // Regra F4-03 / Segurança: Apenas apps explicitamente autorizados para encerramento
            if (!app.CanKill)
            {
                _logger.LogWarning("Tentativa de encerramento recusada para app protegido '{Id}'", id);
                return new AppOperationResult
                {
                    Success = false,
                    ErrorMessage = $"O aplicativo '{app.Name}' está protegido e não pode ser encerrado remotamente."
                };
            }

            try
            {
                var processes = Process.GetProcessesByName(app.ProcessName);
                if (processes.Length == 0)
                {
                    return new AppOperationResult
                    {
                        Success = false,
                        ErrorMessage = $"Nenhum processo '{app.ProcessName}' encontrado em execução."
                    };
                }

                // Localiza o processo específico se PID foi passado
                Process? targetProc = null;
                if (expectedPid.HasValue)
                {
                    targetProc = processes.FirstOrDefault(p => p.Id == expectedPid.Value);
                    if (targetProc == null)
                    {
                        return new AppOperationResult
                        {
                            Success = false,
                            ErrorMessage = $"A instância com PID {expectedPid.Value} não foi encontrada ou já foi encerrada."
                        };
                    }

                    // Validação de PID reuse com base no tempo de início (F4-03 / F4-05)
                    if (expectedStartTimeUtc.HasValue)
                    {
                        try
                        {
                            var procStartUtc = targetProc.StartTime.ToUniversalTime();
                            if (Math.Abs((procStartUtc - expectedStartTimeUtc.Value).TotalSeconds) > 5)
                            {
                                return new AppOperationResult
                                {
                                    Success = false,
                                    ErrorMessage = "O PID foi reutilizado por outra instância recente. Operação abortada por segurança."
                                };
                            }
                        }
                        catch { }
                    }
                }
                else
                {
                    targetProc = processes[0];
                }

                int killedPid = targetProc.Id;
                _logger.LogInformation("Encerrando processo autorizado '{Name}' (PID: {Pid})", app.ProcessName, killedPid);

                // Tentativa de fechamento gracioso
                targetProc.CloseMainWindow();

                // Aguarda até 1s
                for (int i = 0; i < 10; i++)
                {
                    if (targetProc.HasExited) break;
                    await Task.Delay(100);
                }

                if (!targetProc.HasExited)
                {
                    targetProc.Kill();
                }

                return new AppOperationResult
                {
                    Success = true,
                    ProcessId = killedPid
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Erro ao encerrar processo do app '{Id}'", id);
                return new AppOperationResult
                {
                    Success = false,
                    ErrorMessage = $"Falha ao encerrar processo: {ex.Message}"
                };
            }
        }
    }
}
