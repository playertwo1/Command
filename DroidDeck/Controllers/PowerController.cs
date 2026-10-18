using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;

namespace DroidDeck.Controllers
{
    [ApiController]
    [Route("api/power")]
    [Route("api/v1/power")]
    [Route("api/system")]
    public class PowerController : ControllerBase
    {
        private readonly IPowerControlService _powerService;

        public PowerController(IPowerControlService powerService)
        {
            _powerService = powerService;
        }

        /// <summary>
        /// Obtém informações de rede do host para disparo de pacotes mágicos Wake-on-LAN (MAC address, IP e porta).
        /// </summary>
        [HttpGet("wake-info")]
        public ActionResult<NetworkWakeInfoDto> GetWakeInfo()
        {
            return Ok(_powerService.GetWakeInfo());
        }

        /// <summary>
        /// Executa uma ação de energia ou bloqueio de sessão com confirmação explícita obrigatória.
        /// </summary>
        [HttpPost("action")]
        public ActionResult<PowerActionResultDto> ExecuteAction(
            [FromBody] PowerActionRequest request,
            [FromHeader(Name = "X-Device-Id")] string? deviceId = null)
        {
            var result = _powerService.ExecutePowerAction(request, deviceId);
            if (!result.Success)
            {
                return BadRequest(result);
            }
            return Ok(result);
        }

        /// <summary>
        /// Atalho para bloqueio imediato da estação de trabalho (LockWorkStation).
        /// </summary>
        [HttpPost("lock")]
        public ActionResult<PowerActionResultDto> Lock(
            [FromBody(EmptyBodyBehavior = Microsoft.AspNetCore.Mvc.ModelBinding.EmptyBodyBehavior.Allow)] PowerActionRequest? body = null,
            [FromQuery] bool? confirmed = null,
            [FromQuery] string? requestId = null,
            [FromHeader(Name = "X-Device-Id")] string? deviceId = null)
        {
            var request = new PowerActionRequest
            {
                Action = "lock",
                Confirmed = body?.Confirmed ?? confirmed ?? false,
                RequestId = body?.RequestId ?? requestId
            };
            return ExecuteAction(request, deviceId);
        }

        /// <summary>
        /// Atalho para suspensão de energia do computador (Sleep / SetSuspendState).
        /// </summary>
        [HttpPost("sleep")]
        public ActionResult<PowerActionResultDto> Sleep(
            [FromBody(EmptyBodyBehavior = Microsoft.AspNetCore.Mvc.ModelBinding.EmptyBodyBehavior.Allow)] PowerActionRequest? body = null,
            [FromQuery] bool? confirmed = null,
            [FromQuery] string? requestId = null,
            [FromHeader(Name = "X-Device-Id")] string? deviceId = null)
        {
            var request = new PowerActionRequest
            {
                Action = "sleep",
                Confirmed = body?.Confirmed ?? confirmed ?? false,
                RequestId = body?.RequestId ?? requestId
            };
            return ExecuteAction(request, deviceId);
        }
    }
}
