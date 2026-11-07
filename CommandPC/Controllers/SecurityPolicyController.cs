using System;
using System.Collections.Generic;
using Command.Models;
using Command.Services;
using Microsoft.AspNetCore.Mvc;

namespace Command.Controllers
{
    [ApiController]
    [Route("api/security")]
    [Route("api/v1/security")]
    public class SecurityPolicyController : ControllerBase
    {
        private readonly ISecurityPolicyService _securityPolicy;

        public SecurityPolicyController(ISecurityPolicyService securityPolicy)
        {
            _securityPolicy = securityPolicy ?? throw new ArgumentNullException(nameof(securityPolicy));
        }

        [HttpGet("devices")]
        public ActionResult<IReadOnlyList<DevicePermissionDto>> GetDevices()
        {
            return Ok(_securityPolicy.GetDevicePermissions());
        }

        [HttpPost("devices/role")]
        public ActionResult<DevicePermissionDto> SetDeviceRole([FromBody] UpdateDeviceRoleRequest request)
        {
            if (request == null)
            {
                return BadRequest("Payload cannot be null.");
            }

            try
            {
                var result = _securityPolicy.SetDeviceRole(request.DeviceId, request.Role);
                return Ok(result);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpGet("audit")]
        public ActionResult<IReadOnlyList<SecurityAuditEntryDto>> GetAudit([FromQuery] int limit = 100)
        {
            return Ok(_securityPolicy.GetAuditLog(limit));
        }
    }
}
