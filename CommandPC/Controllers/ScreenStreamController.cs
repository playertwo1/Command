using System;
using System.Threading.Tasks;
using Command.Services;
using Microsoft.AspNetCore.Mvc;

namespace Command.Controllers
{
    [ApiController]
    [Route("api/stream")]
    [Route("api/v1/stream")]
    public class ScreenStreamController : ControllerBase
    {
        private readonly IScreenStreamService _screenStreamService;

        public ScreenStreamController(IScreenStreamService screenStreamService)
        {
            _screenStreamService = screenStreamService;
        }

        /// <summary>
        /// Transmissão contínua em tempo real da tela do PC via HTTP Multipart MJPEG.
        /// Suporta controle cooperativo por CancellationToken e limite de 1 cliente ativo por vez.
        /// </summary>
        [HttpGet("desktop")]
        public async Task<IActionResult> StreamDesktop(
            [FromQuery] int fps = 10,
            [FromQuery] int quality = 70,
            [FromQuery] double scale = 0.67)
        {
            Response.ContentType = "multipart/x-mixed-replace; boundary=frame";
            Response.Headers["Cache-Control"] = "no-cache, no-store, must-revalidate";
            Response.Headers["Pragma"] = "no-cache";

            try
            {
                await _screenStreamService.WriteStreamAsync(
                    Response.Body,
                    fps,
                    quality,
                    scale,
                    HttpContext.RequestAborted);

                return new EmptyResult();
            }
            catch (ScreenStreamBusyException ex)
            {
                return Conflict(new { code = "STREAM_BUSY", message = ex.Message });
            }
            catch (OperationCanceledException)
            {
                return new EmptyResult();
            }
        }
    }
}
