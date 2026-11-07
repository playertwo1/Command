using Command.Models;

namespace Command.Services
{
    public interface IScreenshotService
    {
        ScreenshotCaptureResult CapturePrimaryScreen(string requestId, string? deviceId);
        ScreenshotFileResult GetScreenshot(string id, string? deviceId);
        ScreenshotInfoDto? GetMetadata(string id);
        void CleanExpiredScreenshots();
    }
}
