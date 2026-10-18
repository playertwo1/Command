using DroidDeck.Models;

namespace DroidDeck.Services
{
    public interface IUpdateVerificationService
    {
        UpdateStatusDto GetStatus();
        VerifyUpdatePackageResponse VerifyPayload(string payloadBase64, string expectedSha256);
    }
}
