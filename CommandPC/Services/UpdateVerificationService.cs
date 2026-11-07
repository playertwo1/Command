using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using Command.Models;

namespace Command.Services
{
    public class UpdateVerificationService : IUpdateVerificationService
    {
        private static readonly string CachedBinarySha256 = ComputeSelfHash();

        public UpdateStatusDto GetStatus()
        {
            return new UpdateStatusDto(
                CurrentVersion: "1.1.0",
                Channel: "stable",
                UpdateAvailable: false,
                LatestVersion: "1.1.0",
                IsVelopackReady: true,
                BinarySha256: CachedBinarySha256,
                CheckedAtUtc: DateTime.UtcNow
            );
        }

        public VerifyUpdatePackageResponse VerifyPayload(string payloadBase64, string expectedSha256)
        {
            if (string.IsNullOrWhiteSpace(payloadBase64))
            {
                return new VerifyUpdatePackageResponse(false, string.Empty, "Payload cannot be null or empty.");
            }

            if (string.IsNullOrWhiteSpace(expectedSha256))
            {
                return new VerifyUpdatePackageResponse(false, string.Empty, "ExpectedSha256 cannot be null or empty.");
            }

            byte[] bytes;
            try
            {
                bytes = Convert.FromBase64String(payloadBase64);
            }
            catch (FormatException ex)
            {
                return new VerifyUpdatePackageResponse(false, string.Empty, $"Malformed base64 payload: {ex.Message}");
            }

            string actualSha256 = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
            bool isValid = string.Equals(actualSha256, expectedSha256.Trim(), StringComparison.OrdinalIgnoreCase);

            return new VerifyUpdatePackageResponse(
                IsValid: isValid,
                ActualSha256: actualSha256,
                ErrorMessage: isValid ? null : "Checksum mismatch between payload and expectedSha256."
            );
        }

        private static string ComputeSelfHash()
        {
            try
            {
                var location = typeof(UpdateVerificationService).Assembly.Location;
                if (!string.IsNullOrEmpty(location) && File.Exists(location))
                {
                    using var stream = File.OpenRead(location);
                    return Convert.ToHexString(SHA256.HashData(stream)).ToLowerInvariant();
                }
            }
            catch
            {
                // Fallback gracioso
            }

            return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes("Command-DroidDeck-v1.1.0"))).ToLowerInvariant();
        }
    }
}
