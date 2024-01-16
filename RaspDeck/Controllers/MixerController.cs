using AnyDeck.Services;
using Microsoft.AspNetCore.Mvc;
using NAudio.CoreAudioApi;

namespace AnyDeck.Controllers
{
    [Route("api/v1/[controller]")]
    [ApiController]
    public class MixerController : ControllerBase
    {
        private readonly MixerService mixerService = new MixerService();

        [HttpGet("out")]
        public IActionResult GetAllOutputs()
        {
            return Ok(mixerService.FindAll());
        }

        [HttpGet("out/{id}")]
        public IActionResult GetOutput(string id)
        {
            var mixer = mixerService.FindOne(id);
            if (mixer != null)
                return Ok(mixer);
            return BadRequest();
        }

        [HttpPut("out/{id}")]
        public IActionResult SetOutput(string id, [FromBody] MixerData data)
        {
            var device = new MixerMaster(id);
            if (device == null) return BadRequest();
            else return Ok(device.SetOptions(id, data));
        }

        [HttpGet("in")]
        public IActionResult GetAllInputs()
        {
            return Ok(MixerMaster.GetAllMixers(DataFlow.Capture, DeviceState.Active));
        }

        [HttpGet("in/{id}")]
        public IActionResult GetInput(string id)
        {
            var device = new MixerMaster(id);
            if (device == null)
                return BadRequest();
            return Ok(device);
        }

        [HttpPut("in/{id}")]
        public IActionResult SetInput(string id, [FromBody] MixerData data)
        {
            var device = new MixerMaster(id);
            if (device == null) return BadRequest();
            else return Ok(device.SetOptions(id, data));
        }
    }
}
