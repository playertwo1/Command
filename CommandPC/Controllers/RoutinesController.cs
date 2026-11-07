using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Command.Models;
using Command.Services;
using Microsoft.AspNetCore.Mvc;

namespace Command.Controllers
{
    [ApiController]
    [Route("api/routines")]
    [Route("api/v1/routines")]
    public class RoutinesController : ControllerBase
    {
        private readonly IRoutineService _routineService;
        private readonly IWebhookNotificationService _webhookService;

        public RoutinesController(
            IRoutineService routineService,
            IWebhookNotificationService webhookService)
        {
            _routineService = routineService;
            _webhookService = webhookService;
        }

        /// <summary>
        /// Lista todas as rotinas disponíveis (presets de fábrica e macros personalizadas).
        /// </summary>
        [HttpGet]
        public ActionResult<IReadOnlyList<RoutineDefinitionDto>> GetRoutines()
        {
            return Ok(_routineService.GetRoutines());
        }

        /// <summary>
        /// Consulta a definição detalhada de uma rotina específica.
        /// </summary>
        [HttpGet("{id}")]
        public ActionResult<RoutineDefinitionDto> GetRoutine(string id)
        {
            var routine = _routineService.GetRoutine(id);
            if (routine == null)
            {
                return NotFound(new { error = $"Rotina com ID '{id}' não encontrada." });
            }
            return Ok(routine);
        }

        /// <summary>
        /// Salva uma rotina personalizada com validação estrita da allowlist de aplicativos e ações.
        /// Retorna 400 BadRequest caso algum passo viole a política de segurança.
        /// </summary>
        [HttpPost]
        public ActionResult<RoutineDefinitionDto> SaveCustomRoutine([FromBody] RoutineDefinitionDto routine)
        {
            try
            {
                var saved = _routineService.SaveCustomRoutine(routine);
                return Ok(saved);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                return BadRequest(new { error = $"Falha ao salvar rotina: {ex.Message}" });
            }
        }

        /// <summary>
        /// Remove uma rotina personalizada ou predefinida (preset).
        /// </summary>
        [HttpDelete("{id}")]
        public IActionResult DeleteCustomRoutine(string id)
        {
            var routine = _routineService.GetRoutine(id);
            if (routine == null)
            {
                return NotFound(new { error = $"Rotina com ID '{id}' não encontrada." });
            }

            bool deleted = _routineService.DeleteCustomRoutine(id);
            if (deleted)
            {
                return Ok(new { success = true, message = $"Rotina '{id}' excluída com sucesso." });
            }

            return BadRequest(new { error = "Não foi possível remover a rotina solicitada." });
        }

        /// <summary>
        /// Executa uma rotina encadeada passo a passo sequencialmente com confirmação explícita.
        /// </summary>
        [HttpPost("{id}/execute")]
        public async Task<ActionResult<RoutineExecutionResponse>> ExecuteRoutine(
            string id,
            [FromQuery] bool confirmed = true,
            [FromHeader(Name = "X-Device-Id")] string? deviceId = null,
            CancellationToken ct = default)
        {
            var result = await _routineService.ExecuteRoutineAsync(id, confirmed, deviceId, ct);
            return Ok(result);
        }

        /// <summary>
        /// Consulta a configuração atual do serviço de webhook externo.
        /// </summary>
        [HttpGet("webhook")]
        public ActionResult<WebhookConfigDto> GetWebhookConfig()
        {
            return Ok(_webhookService.GetConfig());
        }

        /// <summary>
        /// Atualiza as configurações e URL do webhook de notificação.
        /// </summary>
        [HttpPost("webhook")]
        public ActionResult<WebhookConfigDto> UpdateWebhookConfig([FromBody] WebhookUpdateConfigRequest request)
        {
            var updated = _webhookService.UpdateConfig(
                request.Enabled,
                request.WebhookUrl,
                request.NotifyOnRoutineComplete,
                request.NotifyOnCriticalAlert);

            return Ok(updated);
        }
    }
}
