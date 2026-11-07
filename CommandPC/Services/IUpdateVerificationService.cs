using Command.Models;

namespace Command.Services
{
    public interface IUpdateVerificationService
    {
        UpdateStatusDto GetStatus();
        VerifyUpdatePackageResponse VerifyPayload(string payloadBase64, string expectedSha256);
    }
}
