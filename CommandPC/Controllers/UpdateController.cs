using System;
using Command.Models;
using Command.Services;
using Microsoft.AspNetCore.Mvc;

namespace Command.Controllers
{
    [ApiController]
    [Route("api/system")]
    [Route("api/v1/system")]
    public class UpdateController : ControllerBase
    {
        private readonly IUpdateVerificationService _updateService;
        private readonly ISystemStabilityMonitor _stabilityMonitor;

        public UpdateController(
            IUpdateVerificationService updateService,
            ISystemStabilityMonitor stabilityMonitor)
        {
            _updateService = updateService ?? throw new ArgumentNullException(nameof(updateService));
            _stabilityMonitor = stabilityMonitor ?? throw new ArgumentNullException(nameof(stabilityMonitor));
        }

        [HttpGet("update/status")]
        public ActionResult<UpdateStatusDto> GetUpdateStatus()
        {
            return Ok(_updateService.GetStatus());
        }

        [HttpPost("update/verify")]
        public ActionResult<VerifyUpdatePackageResponse> VerifyUpdatePackage([FromBody] VerifyUpdatePackageRequest request)
        {
            if (request == null)
            {
                return BadRequest("Payload cannot be null.");
            }

            var result = _updateService.VerifyPayload(request.PayloadBase64, request.ExpectedSha256);
            return Ok(result);
        }

        [HttpGet("stability")]
        public ActionResult<SystemStabilityDto> GetStability()
        {
            return Ok(_stabilityMonitor.GetCurrentSnapshot());
        }
    }
}
