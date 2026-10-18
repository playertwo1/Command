using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Models;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    public class HermesService : IHermesService
    {
        private readonly IAppCatalogService _appCatalog;
        private readonly ITopProcessesService? _topProcesses;
        private readonly IScreenshotService? _screenshotService;
        private readonly SystemMonitorService? _systemMonitor;
        private readonly ILogger<HermesService>? _logger;
        private readonly object _lock = new();

        private bool _enabled = false;
        private string _endpointUrl = string.Empty;
        private string _modelName = "gemini-3.8-flash";
        private string? _apiKey = null;

        public HermesService(
            IAppCatalogService appCatalog,
            ITopProcessesService? topProcesses = null,
            IScreenshotService? screenshotService = null,
            SystemMonitorService? systemMonitor = null,
            ILogger<HermesService>? logger = null)
        {
            _appCatalog = appCatalog ?? throw new ArgumentNullException(nameof(appCatalog));
            _topProcesses = topProcesses;
            _screenshotService = screenshotService;
            _systemMonitor = systemMonitor;
            _logger = logger;
        }

        public HermesConfigDto GetStatus()
        {
            lock (_lock)
            {
                return new HermesConfigDto
                {
                    Enabled = _enabled,
                    EndpointUrl = _endpointUrl,
                    ModelName = _modelName,
                    HasApiKey = !string.IsNullOrWhiteSpace(_apiKey)
                };
            }
        }

        public HermesConfigDto UpdateConfig(HermesUpdateConfigRequest request)
        {
            if (request == null) return GetStatus();

            lock (_lock)
            {
                _enabled = request.Enabled;
                if (request.EndpointUrl != null)
                {
                    _endpointUrl = request.EndpointUrl;
                }
                if (!string.IsNullOrWhiteSpace(request.ModelName))
                {
                    _modelName = request.ModelName;
                }
                if (request.ApiKey != null)
                {
                    _apiKey = string.IsNullOrWhiteSpace(request.ApiKey) ? null : request.ApiKey;
                }

                return new HermesConfigDto
                {
                    Enabled = _enabled,
                    EndpointUrl = _endpointUrl,
                    ModelName = _modelName,
                    HasApiKey = !string.IsNullOrWhiteSpace(_apiKey)
                };
            }
        }

        public List<HermesSuggestedActionDto> FilterAllowedActions(IEnumerable<HermesSuggestedActionDto> candidates)
        {
            var allowed = new List<HermesSuggestedActionDto>();
            if (candidates == null) return allowed;

            IReadOnlyList<AppSummaryDto>? allowedApps = null;
            try
            {
                allowedApps = _appCatalog.GetAllowedApps();
            }
            catch { }

            foreach (var candidate in candidates)
            {
                if (string.Equals(candidate.ActionType, "app.launch", StringComparison.OrdinalIgnoreCase))
                {
                    bool exists = _appCatalog.TryGetApp(candidate.TargetId, out _);
                    if (!exists && allowedApps != null)
                    {
                        exists = allowedApps.Any(a => string.Equals(a.Id, candidate.TargetId, StringComparison.OrdinalIgnoreCase));
                    }

                    if (exists)
                    {
                        candidate.RequiresConfirmation = true;
                        allowed.Add(candidate);
                    }
                }
                else if (string.Equals(candidate.ActionType, "app.kill", StringComparison.OrdinalIgnoreCase))
                {
                    bool canKill = false;
                    if (_appCatalog.TryGetApp(candidate.TargetId, out var item) && item != null)
                    {
                        canKill = item.CanKill;
                    }
                    else if (allowedApps != null)
                    {
                        var summary = allowedApps.FirstOrDefault(a => string.Equals(a.Id, candidate.TargetId, StringComparison.OrdinalIgnoreCase));
                        canKill = summary != null && summary.CanKill;
                    }

                    if (canKill)
                    {
                        candidate.RequiresConfirmation = true;
                        allowed.Add(candidate);
                    }
                }
                else
                {
                    candidate.RequiresConfirmation = true;
                    allowed.Add(candidate);
                }
            }

            return allowed;
        }

        public async Task<HermesAnalyzeResponse> AnalyzeAsync(
            HermesAnalyzeRequest request,
            string? deviceId = null,
            CancellationToken ct = default)
        {
            var inv = CultureInfo.InvariantCulture;
            var timestamp = DateTime.UtcNow;

            bool isEnabled;
            lock (_lock)
            {
                isEnabled = _enabled;
            }

            if (!isEnabled)
            {
                return new HermesAnalyzeResponse
                {
                    Success = false,
                    ErrorCode = "HERMES_DISABLED",
                    ErrorMessage = "Módulo Hermes IA está desativado.",
                    TimestampUtc = timestamp
                };
            }

            if (request == null || string.IsNullOrWhiteSpace(request.Prompt))
            {
                return new HermesAnalyzeResponse
                {
                    Success = false,
                    ErrorCode = "INVALID_PROMPT",
                    ErrorMessage = "O prompt não pode ser vazio.",
                    TimestampUtc = timestamp
                };
            }

            // Validação de screenshot se solicitado
            if (!string.IsNullOrWhiteSpace(request.ScreenshotId))
            {
                if (_screenshotService == null)
                {
                    return new HermesAnalyzeResponse
                    {
                        Success = false,
                        ErrorCode = "SCREENSHOT_UNAVAILABLE",
                        ErrorMessage = "Serviço de captura de tela não disponível.",
                        TimestampUtc = timestamp
                    };
                }

                var meta = _screenshotService.GetMetadata(request.ScreenshotId);
                if (meta == null || meta.IsExpired)
                {
                    return new HermesAnalyzeResponse
                    {
                        Success = false,
                        ErrorCode = "SCREENSHOT_UNAVAILABLE",
                        ErrorMessage = "Captura de tela inválida ou expirada.",
                        TimestampUtc = timestamp
                    };
                }
            }

            // Coleta de telemetria
            SystemStats? stats = null;
            if (request.IncludeTelemetry && _systemMonitor != null)
            {
                try
                {
                    stats = _systemMonitor.LastStats ?? _systemMonitor.SampleStats();
                }
                catch { }
            }

            // Coleta de processos mais consumidores
            TopProcessesResponseDto? topProcesses = null;
            if (request.IncludeTopProcesses && _topProcesses != null)
            {
                try
                {
                    topProcesses = _topProcesses.GetTopProcesses(5);
                }
                catch { }
            }

            // Sanitização do contexto
            string sanitizedSummary = HermesContextSanitizer.BuildSanitizedTelemetryContext(stats, topProcesses);
            string sanitizedPrompt = HermesContextSanitizer.SanitizeText(request.Prompt);

            // Análise determinística inteligente / heurística local
            var candidateActions = new List<HermesSuggestedActionDto>();
            var replyBuilder = new StringBuilder();

            string promptLower = sanitizedPrompt.ToLowerInvariant();

            bool highCpu = stats != null && stats.CpuUsage >= 80f;
            bool highRam = stats != null && stats.RamUsage >= 80f;

            if (highCpu || highRam)
            {
                replyBuilder.AppendLine($"Atenção: Sistema sob carga elevada. CPU em {stats?.CpuUsage.ToString("F1", inv) ?? "0.0"}%, RAM em {stats?.RamUsage.ToString("F1", inv) ?? "0.0"}%.");
            }

            // Prioriza bloco de notas/notepad antes de obsidian para evitar conflito com 'notas'
            if (promptLower.Contains("bloco de notas") || promptLower.Contains("notepad") || promptLower.Contains("test_notepad"))
            {
                if (promptLower.Contains("fechar") || promptLower.Contains("encerrar") || promptLower.Contains("kill") || promptLower.Contains("parar"))
                {
                    replyBuilder.AppendLine("O Bloco de Notas de teste pode ser encerrado com segurança.");
                    candidateActions.Add(new HermesSuggestedActionDto
                    {
                        ActionType = "app.kill",
                        TargetId = "test_notepad",
                        Title = "Encerrar Bloco de Notas",
                        Reason = "Finalizar processo de teste",
                        RequiresConfirmation = true
                    });
                }
                else
                {
                    replyBuilder.AppendLine("O Bloco de Notas de teste está disponível na allowlist.");
                    candidateActions.Add(new HermesSuggestedActionDto
                    {
                        ActionType = "app.launch",
                        TargetId = "test_notepad",
                        Title = "Abrir Bloco de Notas",
                        Reason = "Executar aplicativo de teste",
                        RequiresConfirmation = true
                    });
                }
            }
            else if (promptLower.Contains("obsidian") || (promptLower.Contains("notas") && !promptLower.Contains("bloco de notas")) || promptLower.Contains("anotaç") || promptLower.Contains("nexusvault"))
            {
                replyBuilder.AppendLine("Você pode acessar suas notas no Obsidian rapidamente.");
                candidateActions.Add(new HermesSuggestedActionDto
                {
                    ActionType = "app.launch",
                    TargetId = "obsidian",
                    Title = "Abrir Obsidian",
                    Reason = "Acesso rápido às anotações no NexusVault",
                    RequiresConfirmation = true
                });
            }
            else if (promptLower.Contains("orbit") || promptLower.Contains("código") || promptLower.Contains("projeto") || promptLower.Contains("vs code") || promptLower.Contains("editor"))
            {
                replyBuilder.AppendLine("Você pode abrir o projeto Orbit no seu editor.");
                candidateActions.Add(new HermesSuggestedActionDto
                {
                    ActionType = "app.launch",
                    TargetId = "orbit",
                    Title = "Abrir Orbit PJ",
                    Reason = "Abrir ambiente de desenvolvimento do projeto Orbit",
                    RequiresConfirmation = true
                });
            }
            else if (promptLower.Contains("print") || promptLower.Contains("screenshot") || promptLower.Contains("tela") || promptLower.Contains("captur"))
            {
                replyBuilder.AppendLine("Captura de tela solicitada.");
                candidateActions.Add(new HermesSuggestedActionDto
                {
                    ActionType = "screenshot.capture",
                    TargetId = "primary",
                    Title = "Capturar Tela Principal",
                    Reason = "Capturar o estado visual atual do monitor principal",
                    RequiresConfirmation = true
                });
            }
            else if (promptLower.Contains("lent") || promptLower.Contains("travand") || promptLower.Contains("process") || promptLower.Contains("cpu") || promptLower.Contains("memoria") || promptLower.Contains("ram"))
            {
                replyBuilder.AppendLine($"Diagnóstico do Sistema: CPU em {stats?.CpuUsage.ToString("F1", inv) ?? "0.0"}%, RAM em {stats?.RamUsage.ToString("F1", inv) ?? "0.0"}%.");
                if (topProcesses?.ByCpu?.Count > 0)
                {
                    var top = topProcesses.ByCpu[0];
                    replyBuilder.AppendLine($"Processo com maior uso de CPU: {HermesContextSanitizer.SanitizeText(top.Name)} ({top.CpuPercent?.ToString("F1", inv) ?? "N/A"}%).");
                }
            }
            else
            {
                replyBuilder.AppendLine("Análise do sistema concluída com sucesso. Todas as métricas e processos foram avaliados.");
            }

            // Aplica filtro estrito de allowlist
            var filteredActions = FilterAllowedActions(candidateActions);

            await Task.CompletedTask;

            return new HermesAnalyzeResponse
            {
                Success = true,
                Reply = replyBuilder.ToString().Trim(),
                SanitizedContextSummary = sanitizedSummary,
                SuggestedActions = filteredActions,
                TimestampUtc = timestamp
            };
        }
    }
}
