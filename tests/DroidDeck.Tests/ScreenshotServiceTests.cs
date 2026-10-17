using System;
using System.IO;
using System.Text;
using DroidDeck.Lib;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace DroidDeck.Tests
{
    public class FakeDesktopCaptureProvider : IDesktopCaptureProvider
    {
        public DesktopSessionState StateToReturn { get; set; } = DesktopSessionState.Ready;
        public int CaptureCallCount { get; private set; }
        public byte[] DummyBytes { get; set; } = Encoding.UTF8.GetBytes("fake_jpeg_image_data");
        public int Width { get; set; } = 1920;
        public int Height { get; set; } = 1080;

        public DesktopSessionState CheckSessionState() => StateToReturn;

        public byte[] CapturePrimaryScreen(out int width, out int height)
        {
            CaptureCallCount++;
            width = Width;
            height = Height;
            return DummyBytes;
        }
    }

    public class ScreenshotServiceTests : IDisposable
    {
        private readonly string _testDir;

        public ScreenshotServiceTests()
        {
            _testDir = Path.Combine(Path.GetTempPath(), "DroidDeck_ScreenshotTests_" + Guid.NewGuid().ToString("N"));
            Environment.SetEnvironmentVariable(AppPaths.DataDirEnvVar, _testDir);
        }

        public void Dispose()
        {
            Environment.SetEnvironmentVariable(AppPaths.DataDirEnvVar, null);
            try
            {
                if (Directory.Exists(_testDir))
                {
                    Directory.Delete(_testDir, true);
                }
            }
            catch { }
        }

        [Fact]
        public void Capture_WhenDesktopReady_GeneratesScreenshotAndRegistersJob()
        {
            var fakeCapture = new FakeDesktopCaptureProvider();
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var service = new ScreenshotService(fakeCapture, jobHistory, NullLogger<ScreenshotService>.Instance);

            var result = service.CapturePrimaryScreen("req_101", "device_s25");

            Assert.True(result.Success);
            Assert.NotNull(result.Metadata);
            Assert.Equal("req_101", result.Metadata.RequestId);
            Assert.Equal("device_s25", result.Metadata.DeviceId);
            Assert.Equal(1920, result.Metadata.Width);
            Assert.Equal(1080, result.Metadata.Height);
            Assert.True(File.Exists(result.Metadata.FilePath));

            // Valida registro e auditoria de jobs
            var job = jobHistory.GetJob("req_101");
            Assert.NotNull(job);
            Assert.Equal("screenshot.capture", job.ActionType);
            Assert.Equal("primary_screen", job.TargetId);
            Assert.Equal("succeeded", job.Status);
        }

        [Fact]
        public void Capture_WhenSessionLocked_ReturnsSessionLockedAndLogsFailureJob()
        {
            var fakeCapture = new FakeDesktopCaptureProvider { StateToReturn = DesktopSessionState.SessionLocked };
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var service = new ScreenshotService(fakeCapture, jobHistory, NullLogger<ScreenshotService>.Instance);

            var result = service.CapturePrimaryScreen("req_locked_1", "device_s25");

            Assert.False(result.Success);
            Assert.Equal("SESSION_LOCKED", result.ErrorCode);
            Assert.Contains("bloqueada", result.ErrorMessage);

            var job = jobHistory.GetJob("req_locked_1");
            Assert.NotNull(job);
            Assert.Equal("failed", job.Status);
            Assert.Contains("SESSION_LOCKED", job.ErrorMessage);
        }

        [Fact]
        public void Capture_WhenSecureDesktop_ReturnsSecureDesktop()
        {
            var fakeCapture = new FakeDesktopCaptureProvider { StateToReturn = DesktopSessionState.SecureDesktop };
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var service = new ScreenshotService(fakeCapture, jobHistory, NullLogger<ScreenshotService>.Instance);

            var result = service.CapturePrimaryScreen("req_uac_1", "device_s25");

            Assert.False(result.Success);
            Assert.Equal("SECURE_DESKTOP", result.ErrorCode);
        }

        [Fact]
        public void Capture_WhenNotInteractive_ReturnsNotInteractive()
        {
            var fakeCapture = new FakeDesktopCaptureProvider { StateToReturn = DesktopSessionState.NotInteractive };
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var service = new ScreenshotService(fakeCapture, jobHistory, NullLogger<ScreenshotService>.Instance);

            var result = service.CapturePrimaryScreen("req_noninter_1", "device_s25");

            Assert.False(result.Success);
            Assert.Equal("NOT_INTERACTIVE", result.ErrorCode);
        }

        [Fact]
        public void Capture_Idempotency_SameRequestId_ReturnsExistingWithoutRecapture()
        {
            var fakeCapture = new FakeDesktopCaptureProvider();
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var service = new ScreenshotService(fakeCapture, jobHistory, NullLogger<ScreenshotService>.Instance);

            var first = service.CapturePrimaryScreen("req_double_tap", "device_s25");
            var second = service.CapturePrimaryScreen("req_double_tap", "device_s25");

            Assert.True(first.Success);
            Assert.True(second.Success);
            Assert.Equal(first.Metadata!.Id, second.Metadata!.Id);
            Assert.Equal(1, fakeCapture.CaptureCallCount);
        }

        [Fact]
        public void GetScreenshot_DeviceIsolation_EnforcesOwnership()
        {
            var fakeCapture = new FakeDesktopCaptureProvider();
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var service = new ScreenshotService(fakeCapture, jobHistory, NullLogger<ScreenshotService>.Instance);

            var capture = service.CapturePrimaryScreen("req_owner_test", "device_A");
            Assert.True(capture.Success);

            // Acesso pelo mesmo dispositivo -> Sucesso
            var found = service.GetScreenshot(capture.Metadata!.Id, "device_A");
            Assert.Equal(ScreenshotFileStatus.Found, found.Status);

            // Acesso por dispositivo diferente -> 403 Forbidden
            var forbidden = service.GetScreenshot(capture.Metadata.Id, "device_B");
            Assert.Equal(ScreenshotFileStatus.Forbidden, forbidden.Status);
        }

        [Fact]
        public void GetScreenshot_ExpiredScreenshot_ReturnsExpiredAndDeletesFile()
        {
            var fakeCapture = new FakeDesktopCaptureProvider();
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var service = new ScreenshotService(fakeCapture, jobHistory, NullLogger<ScreenshotService>.Instance);

            var capture = service.CapturePrimaryScreen("req_expire_test", "device_A");
            Assert.True(capture.Success);
            var path = capture.Metadata!.FilePath;
            Assert.True(File.Exists(path));

            // Simula expiração adiantando o horário de expiração para o passado
            capture.Metadata.ExpiresAtUtc = DateTime.UtcNow.AddMinutes(-1);

            var result = service.GetScreenshot(capture.Metadata.Id, "device_A");
            Assert.Equal(ScreenshotFileStatus.Expired, result.Status);
            Assert.False(File.Exists(path), "O arquivo temporário no disco deve ser excluído após a expiração de 10 min.");
        }
    }
}
