using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;

namespace DroidDeck.Controllers
{
    /// <summary>Valores atuais dos botoes de informacao e dos botoes de dois estados.</summary>
    [Route("api/info")]
    [ApiController]
    public class InfoController : ControllerBase
    {
        private readonly InfoService _info;
        private readonly ButtonToggleService _toggles;

        public InfoController(InfoService info, ButtonToggleService toggles)
        {
            _info = info;
            _toggles = toggles;
        }

        [HttpGet]
        public ActionResult Get() => Ok(new
        {
            buttons = _info.GetState(),
            nowPlaying = _info.NowPlaying,
            toggles = _toggles.GetState(),
        });
    }
}
