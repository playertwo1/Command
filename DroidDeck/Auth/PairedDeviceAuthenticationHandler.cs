using System;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace DroidDeck.Auth
{
    public sealed class PairedDeviceAuthenticationHandler : AuthenticationHandler<AuthenticationSchemeOptions>
    {
        private readonly PairedDeviceCredentialStore _credentials;

        public PairedDeviceAuthenticationHandler(
            IOptionsMonitor<AuthenticationSchemeOptions> options,
            ILoggerFactory logger,
            UrlEncoder encoder,
            PairedDeviceCredentialStore credentials) : base(options, logger, encoder) =>
            _credentials = credentials;

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (!Request.IsHttps)
                return Task.FromResult(AuthenticateResult.Fail("HTTPS required"));

            var header = Request.Headers["Authorization"].ToString();
            if (!header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                return Task.FromResult(AuthenticateResult.Fail("Missing device credential"));

            var credential = header["Bearer ".Length..].Trim();
            if (!_credentials.TryAuthenticate(credential, out var device) || device is null)
                return Task.FromResult(AuthenticateResult.Fail("Invalid device credential"));

            var claims = new[]
            {
                new Claim("device_id", device.DeviceId),
                new Claim("device_role", device.Role),
            };
            var identity = new ClaimsIdentity(claims, Scheme.Name);
            return Task.FromResult(AuthenticateResult.Success(
                new AuthenticationTicket(new ClaimsPrincipal(identity), Scheme.Name)));
        }
    }
}
