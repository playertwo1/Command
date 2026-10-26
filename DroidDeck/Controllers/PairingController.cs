using System;
using System.ComponentModel.DataAnnotations;
using DroidDeck.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DroidDeck.Controllers
{
    [ApiController]
    [Route("api/v1/pairing")]
    public sealed class PairingController : ControllerBase
    {
        private readonly ControlPairingTicketStore _tickets;
        private readonly PairedDeviceCredentialStore _credentials;

        public PairingController(ControlPairingTicketStore tickets, PairedDeviceCredentialStore credentials)
        {
            _tickets = tickets;
            _credentials = credentials;
        }

        [AllowAnonymous]
        [HttpPost("exchange")]
        public ActionResult<ExchangeControlTicketResponse> Exchange([FromBody] ExchangeControlTicketRequest request)
        {
            if (!Request.IsHttps) return StatusCode(403);
            if (request is null || !_tickets.TryConsume(request.Ticket)) return Unauthorized();

            try
            {
                var created = _credentials.Create();
                return Ok(new ExchangeControlTicketResponse(created.DeviceId, created.Credential));
            }
            catch
            {
                // The ticket has already been consumed. Fail closed; the user can display a new QR.
                return StatusCode(500);
            }
        }

        [Authorize(AuthenticationSchemes = "ApiKey")]
        [HttpPost("devices/{deviceId}/revoke")]
        public IActionResult Revoke(string deviceId) =>
            _credentials.Revoke(deviceId) ? NoContent() : NotFound();
    }

    public sealed record ExchangeControlTicketRequest([Required] string Ticket);
    public sealed record ExchangeControlTicketResponse(string DeviceId, string Credential);
}
