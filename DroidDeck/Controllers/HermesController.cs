using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;

namespace DroidDeck.Controllers
{
    [ApiController]
    [Route("api/hermes")]
    [Route("api/v1/hermes")]
    public class HermesController : ControllerBase
    {
        private readonly IHermesService _hermesService;

        public HermesController(IHermesService hermesService)
        {
            _hermesService = hermesService;
        }

        /// <summary>
        /// Consulta o status e configurações atuais do módulo Hermes IA.
        /// Nunca expõe a API key em texto claro.
        /// </summary>
        [HttpGet("status")]
        [HttpGet]
        public ActionResult<HermesConfigDto> GetStatus()
        {
            return Ok(_hermesService.GetStatus());
        }

        /// <summary>
        /// Atualiza as configurações de ativação, endpoint, modelo ou API key do Hermes.
        /// </summary>
        [HttpPost("config")]
        public ActionResult<HermesConfigDto> UpdateConfig([FromBody] HermesUpdateConfigRequest request)
        {
            return Ok(_hermesService.UpdateConfig(request));
        }

        /// <summary>
        /// Executa a análise assistida por IA com sanitização rigorosa de contexto e filtro de allowlist.
        /// </summary>
        [HttpPost("analyze")]
        public async Task<ActionResult<HermesAnalyzeResponse>> Analyze(
            [FromBody] HermesAnalyzeRequest request,
            [FromHeader(Name = "X-Device-Id")] string? deviceId = null,
            CancellationToken ct = default)
        {
            var result = await _hermesService.AnalyzeAsync(request, deviceId, ct);
            return Ok(result);
        }
    }
}
