using System;
using System.Security.Claims;
using DroidDeck.Lib.Input;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DroidDeck.Controllers
{
    [Authorize(AuthenticationSchemes = "PairedDevice,ApiKey")]
    [ApiController]
    [Route("api/v1/input")]
    public class RemoteInputController : ControllerBase
    {
        private readonly IRemoteControlSessionService _sessionService;
        private readonly IRemoteInputInjector _injector;

        public RemoteInputController(
            IRemoteControlSessionService sessionService,
            IRemoteInputInjector injector)
        {
            _sessionService = sessionService ?? throw new ArgumentNullException(nameof(sessionService));
            _injector = injector ?? throw new ArgumentNullException(nameof(injector));
        }

        [HttpPost("session/start")]
        public IActionResult StartSession()
        {
            var (deviceId, role) = GetCurrentDevice();
            var result = _sessionService.TryStartSession(deviceId, role);

            return result.Status switch
            {
                SessionStartStatus.Success => Ok(new
                {
                    sessionId = result.Session!.SessionId,
                    deviceId = result.Session.DeviceId,
                    timeoutSeconds = 60
                }),
                SessionStartStatus.Locked => StatusCode(423, new { error = result.Reason ?? "SESSION_LOCKED" }),
                SessionStartStatus.Forbidden => StatusCode(403, new { error = result.Reason ?? "INSUFFICIENT_DEVICE_ROLE" }),
                SessionStartStatus.Conflict => StatusCode(409, new { error = "SESSION_ALREADY_ACTIVE", activeDeviceId = result.ActiveDeviceId }),
                _ => StatusCode(500)
            };
        }

        [HttpPost("session/end")]
        public IActionResult EndSession()
        {
            var (deviceId, _) = GetCurrentDevice();
            _sessionService.TryEndSession(deviceId, "UserRequested");
            return NoContent();
        }

        [HttpGet("session")]
        public IActionResult GetSession()
        {
            var session = _sessionService.ActiveSession;
            if (session == null)
            {
                return Ok(new { isActive = false });
            }

            return Ok(new
            {
                isActive = true,
                sessionId = session.SessionId,
                deviceId = session.DeviceId,
                lastActivityUtc = session.LastActivityUtc
            });
        }

        [HttpPost("move")]
        public IActionResult Move([FromBody] MouseMoveRequest request)
        {
            if (request == null ||
                double.IsNaN(request.Dx) || double.IsInfinity(request.Dx) ||
                double.IsNaN(request.Dy) || double.IsInfinity(request.Dy))
            {
                return BadRequest(new { error = "INVALID_COORDINATES" });
            }

            if (Math.Abs(request.Dx) > 1000 || Math.Abs(request.Dy) > 1000)
            {
                return BadRequest(new { error = "COORDINATE_DELTA_EXCEEDS_LIMIT" });
            }

            var (deviceId, role) = GetCurrentDevice();
            var val = _sessionService.ValidateCanInput(deviceId, role);
            if (val.Status != SessionValidateStatus.Allowed)
                return MapSessionValidationResult(val);

            _injector.SendMouseMove((int)Math.Round(request.Dx), (int)Math.Round(request.Dy));
            return NoContent();
        }

        [HttpPost("click")]
        public IActionResult Click([FromBody] MouseClickRequest request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Button))
            {
                return BadRequest(new { error = "MISSING_BUTTON" });
            }

            if (!MouseButtonParser.TryParse(request.Button, request.Action, out var button, out var action))
            {
                return BadRequest(new { error = "INVALID_MOUSE_BUTTON_OR_ACTION" });
            }

            if (request.NormalizedX.HasValue || request.NormalizedY.HasValue)
            {
                if (!request.NormalizedX.HasValue || !request.NormalizedY.HasValue ||
                    double.IsNaN(request.NormalizedX.Value) || double.IsInfinity(request.NormalizedX.Value) ||
                    double.IsNaN(request.NormalizedY.Value) || double.IsInfinity(request.NormalizedY.Value) ||
                    request.NormalizedX.Value < 0.0 || request.NormalizedX.Value > 1.0 ||
                    request.NormalizedY.Value < 0.0 || request.NormalizedY.Value > 1.0)
                {
                    return BadRequest(new { error = "INVALID_NORMALIZED_COORDINATES" });
                }
            }

            var (deviceId, role) = GetCurrentDevice();
            var val = _sessionService.ValidateCanInput(deviceId, role);
            if (val.Status != SessionValidateStatus.Allowed)
                return MapSessionValidationResult(val);

            if (request.NormalizedX.HasValue && request.NormalizedY.HasValue)
            {
                _injector.SendMouseClickAt(button, action, request.NormalizedX.Value, request.NormalizedY.Value);
            }
            else
            {
                _injector.SendMouseButton(button, action);
            }

            return NoContent();
        }

        [HttpPost("scroll")]
        public IActionResult Scroll([FromBody] MouseScrollRequest request)
        {
            if (request == null || Math.Abs(request.DeltaX) > 10000 || Math.Abs(request.DeltaY) > 10000)
            {
                return BadRequest(new { error = "SCROLL_DELTA_EXCEEDS_LIMIT" });
            }

            var (deviceId, role) = GetCurrentDevice();
            var val = _sessionService.ValidateCanInput(deviceId, role);
            if (val.Status != SessionValidateStatus.Allowed)
                return MapSessionValidationResult(val);

            _injector.SendMouseScroll(request.DeltaX, request.DeltaY);
            return NoContent();
        }

        [HttpPost("key")]
        public IActionResult Key([FromBody] KeyInputRequest request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Key))
            {
                return BadRequest(new { error = "MISSING_KEY" });
            }

            if (!KeyAllowlist.TryNormalizeAndValidate(request.Key, out var normalizedSequence, out var reason))
            {
                return BadRequest(new { error = reason ?? "KEY_NOT_IN_ALLOWLIST" });
            }

            var (deviceId, role) = GetCurrentDevice();
            var val = _sessionService.ValidateCanInput(deviceId, role);
            if (val.Status != SessionValidateStatus.Allowed)
                return MapSessionValidationResult(val);

            _injector.SendKey(normalizedSequence);
            return NoContent();
        }

        [HttpPost("text")]
        public IActionResult Text([FromBody] TextInputRequest request)
        {
            if (request == null || request.Text == null)
            {
                return BadRequest(new { error = "MISSING_TEXT" });
            }

            if (request.Text.Length > 500)
            {
                return StatusCode(413, new { error = "TEXT_EXCEEDS_500_CHARS_LIMIT" });
            }

            var (deviceId, role) = GetCurrentDevice();
            var val = _sessionService.ValidateCanInput(deviceId, role);
            if (val.Status != SessionValidateStatus.Allowed)
                return MapSessionValidationResult(val);

            _injector.SendText(request.Text);
            return NoContent();
        }

        [HttpPost]
        public IActionResult Input([FromBody] RemoteInputBatchRequest request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Type))
            {
                return BadRequest(new { error = "MISSING_EVENT_TYPE" });
            }

            return request.Type.ToLowerInvariant() switch
            {
                "move" => Move(new MouseMoveRequest(request.Dx ?? 0, request.Dy ?? 0)),
                "click" => Click(new MouseClickRequest(request.Button ?? "left", request.Action ?? "click", request.NormalizedX, request.NormalizedY)),
                "scroll" => Scroll(new MouseScrollRequest(request.DeltaX ?? 0, request.DeltaY ?? 0)),
                "key" => Key(new KeyInputRequest(request.Key ?? string.Empty)),
                "text" => Text(new TextInputRequest(request.Text ?? string.Empty)),
                _ => BadRequest(new { error = "UNKNOWN_EVENT_TYPE" })
            };
        }

        private (string DeviceId, string Role) GetCurrentDevice()
        {
            var deviceId = User.FindFirst("device_id")?.Value;
            var role = User.FindFirst("device_role")?.Value;

            if (!string.IsNullOrEmpty(deviceId))
            {
                return (deviceId, role ?? "ViewerOnly");
            }

            if (User.Identity?.IsAuthenticated == true)
            {
                return ("local_admin", "FullControl");
            }

            return ("anonymous", "ViewerOnly");
        }

        private IActionResult MapSessionValidationResult(SessionValidateResult result) =>
            result.Status switch
            {
                SessionValidateStatus.Allowed => Ok(),
                SessionValidateStatus.Locked => StatusCode(423, new { error = result.Reason ?? "SESSION_LOCKED" }),
                SessionValidateStatus.Forbidden => StatusCode(403, new { error = result.Reason ?? "INSUFFICIENT_DEVICE_ROLE" }),
                SessionValidateStatus.NoActiveSession => StatusCode(409, new { error = result.Reason ?? "NO_ACTIVE_SESSION" }),
                SessionValidateStatus.RateLimitExceeded => StatusCode(429, new { error = result.Reason ?? "RATE_LIMIT_EXCEEDED" }),
                _ => StatusCode(500)
            };
    }
}
