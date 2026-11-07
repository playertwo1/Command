using Command.Models;
using Command.Services;
using Microsoft.AspNetCore.Mvc;

namespace Command.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Route("api/v1/[controller]")]
    public class ScreenshotsController : ControllerBase
    {
        private readonly IScreenshotService _screenshotService;

        public ScreenshotsController(IScreenshotService screenshotService)
        {
            _screenshotService = screenshotService;
        }

        /// <summary>
        /// Solicita uma captura de tela sob demanda do monitor principal na sessão interativa.
        /// Rejeita sessões bloqueadas ou em tela segura (UAC) com erro descritivo.
        /// </summary>
        [HttpPost("capture")]
        public ActionResult<ScreenshotInfoDto> Capture([FromBody] CaptureScreenshotRequest request)
        {
            if (string.IsNullOrWhiteSpace(request?.RequestId))
            {
                return BadRequest(new { code = "INVALID_REQUEST", error = "O campo requestId é obrigatório para rastreabilidade e idempotência." });
            }

            var result = _screenshotService.CapturePrimaryScreen(request.RequestId, request.DeviceId);

            if (!result.Success)
            {
                if (result.ErrorCode == "SESSION_LOCKED" || result.ErrorCode == "SECURE_DESKTOP")
                {
                    return StatusCode(423, new { code = result.ErrorCode, error = result.ErrorMessage });
                }

                if (result.ErrorCode == "NOT_INTERACTIVE")
                {
                    return StatusCode(503, new { code = result.ErrorCode, error = result.ErrorMessage });
                }

                return BadRequest(new { code = result.ErrorCode ?? "CAPTURE_FAILED", error = result.ErrorMessage });
            }

            return Ok(ScreenshotService.ToDto(result.Metadata!));
        }

        /// <summary>
        /// Obtém a imagem da captura de tela solicitada, com validação de expiração (10 min) e isolamento por dispositivo.
        /// </summary>
        [HttpGet("{id}")]
        public IActionResult GetScreenshot(string id, [FromQuery] string? deviceId)
        {
            var result = _screenshotService.GetScreenshot(id, deviceId);

            return result.Status switch
            {
                ScreenshotFileStatus.Found => PhysicalFile(result.FilePath!, result.ContentType!),
                ScreenshotFileStatus.Expired => StatusCode(410, new { code = "EXPIRED", error = result.ErrorMessage }),
                ScreenshotFileStatus.Forbidden => StatusCode(403, new { code = "FORBIDDEN", error = result.ErrorMessage }),
                _ => NotFound(new { code = "NOT_FOUND", error = result.ErrorMessage ?? "Captura não encontrada." })
            };
        }

        /// <summary>
        /// Consulta os metadados da captura de tela (resolução, tamanho, validade) sem baixar a imagem.
        /// </summary>
        [HttpGet("{id}/info")]
        public ActionResult<ScreenshotInfoDto> GetInfo(string id)
        {
            var meta = _screenshotService.GetMetadata(id);
            if (meta == null)
            {
                return NotFound(new { code = "NOT_FOUND", error = "Metadados da captura não encontrados ou expirados." });
            }

            return Ok(meta);
        }
    }
}
