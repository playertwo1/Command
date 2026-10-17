using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Route("api/v1/[controller]")]
    public class AppsController : ControllerBase
    {
        private readonly IAppCatalogService _catalogService;
        private readonly IJobHistoryService _jobHistory;
        private readonly ILogger<AppsController> _logger;

        public AppsController(
            IAppCatalogService catalogService,
            IJobHistoryService jobHistory,
            ILogger<AppsController> logger)
        {
            _catalogService = catalogService;
            _jobHistory = jobHistory;
            _logger = logger;
        }

        /// <summary>
        /// Lista os aplicativos e projetos autorizados na allowlist (sem expor caminhos locais).
        /// </summary>
        [HttpGet]
        public ActionResult<IReadOnlyList<AppSummaryDto>> GetAllowedApps()
        {
            return Ok(_catalogService.GetAllowedApps());
        }

        /// <summary>
        /// Inicia um aplicativo ou projeto autorizado na allowlist com rastreamento de job e proteção contra repetição.
        /// </summary>
        [HttpPost("{appId}/launch")]
        public async Task<ActionResult<CommandJob>> LaunchApp(string appId, [FromBody] LaunchAppRequest request)
        {
            if (string.IsNullOrWhiteSpace(request?.RequestId))
            {
                return BadRequest(new { error = "O campo requestId é obrigatório para idempotência e auditoria." });
            }

            if (!_catalogService.TryGetApp(appId, out _))
            {
                return NotFound(new { error = $"Aplicativo com ID '{appId}' não encontrado na allowlist." });
            }

            CommandJob job;
            bool isExisting;
            try
            {
                job = _jobHistory.GetOrCreateJob(request.RequestId, "app.launch", appId, request.DeviceId, out isExisting);
            }
            catch (InvalidOperationException ex)
            {
                return Conflict(new { error = ex.Message });
            }

            // Se a requisição for duplicada (toque repetido), retorna o job existente sem reexecutar (F4-02 / F4-05)
            if (isExisting)
            {
                _logger.LogInformation("Requisição duplicada ignorada para o job '{JobId}' (RequestId: {RequestId})", job.Id, job.RequestId);
                return Ok(job);
            }

            _jobHistory.UpdateJob(job.Id, "running");
            var result = await _catalogService.LaunchAsync(appId);

            if (result.Success)
            {
                _jobHistory.UpdateJob(job.Id, "succeeded");
            }
            else
            {
                _jobHistory.UpdateJob(job.Id, "failed", result.ErrorMessage);
            }

            return Ok(_jobHistory.GetJob(job.Id));
        }

        /// <summary>
        /// Encerra um aplicativo autorizado na allowlist (apenas se CanKill == true e com confirmação explícita).
        /// </summary>
        [HttpPost("{appId}/kill")]
        public async Task<ActionResult<CommandJob>> KillApp(string appId, [FromBody] KillAppRequest request)
        {
            if (string.IsNullOrWhiteSpace(request?.RequestId))
            {
                return BadRequest(new { error = "O campo requestId é obrigatório." });
            }

            if (!request.Confirmed)
            {
                return BadRequest(new { error = "Confirmação explícita é obrigatória para encerrar um aplicativo." });
            }

            if (!_catalogService.TryGetApp(appId, out var app))
            {
                return NotFound(new { error = $"Aplicativo com ID '{appId}' não encontrado na allowlist." });
            }

            if (!app.CanKill)
            {
                return StatusCode(403, new { error = $"O aplicativo '{app.Name}' está protegido e não pode ser encerrado remotamente." });
            }

            CommandJob job;
            bool isExisting;
            try
            {
                job = _jobHistory.GetOrCreateJob(request.RequestId, "app.kill", appId, request.DeviceId, out isExisting);
            }
            catch (InvalidOperationException ex)
            {
                return Conflict(new { error = ex.Message });
            }

            if (isExisting)
            {
                return Ok(job);
            }

            _jobHistory.UpdateJob(job.Id, "running");
            var result = await _catalogService.KillAsync(appId, request.ProcessId, request.StartTimeUtc);

            if (result.Success)
            {
                _jobHistory.UpdateJob(job.Id, "succeeded");
            }
            else
            {
                _jobHistory.UpdateJob(job.Id, "failed", result.ErrorMessage);
            }

            return Ok(_jobHistory.GetJob(job.Id));
        }
    }
}
