using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Controllers;
using DroidDeck.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace DroidDeck.Tests
{
    public class ScreenStreamTests
    {
        private static byte[] CreateTestJpeg(int width = 100, int height = 100)
        {
            using var bmp = new Bitmap(width, height);
            using var g = Graphics.FromImage(bmp);
            g.Clear(Color.Purple);
            using var ms = new MemoryStream();
            bmp.Save(ms, ImageFormat.Jpeg);
            return ms.ToArray();
        }

        [Fact]
        public async Task WriteStreamAsync_OutputsValidMjpegFrames_WhenSessionReady()
        {
            var mockCapture = new Mock<IDesktopCaptureProvider>();
            mockCapture.Setup(c => c.CheckSessionState()).Returns(DesktopSessionState.Ready);
            int w = 100, h = 100;
            mockCapture.Setup(c => c.CapturePrimaryScreen(out w, out h)).Returns(CreateTestJpeg(100, 100));

            var service = new ScreenStreamService(mockCapture.Object, NullLogger<ScreenStreamService>.Instance);

            using var ms = new MemoryStream();
            using var cts = new CancellationTokenSource();

            // Cancel after 100ms so it writes at least one frame
            cts.CancelAfter(150);

            await service.WriteStreamAsync(ms, fps: 20, quality: 50, scale: 0.5, cts.Token);

            string output = Encoding.ASCII.GetString(ms.ToArray());
            Assert.Contains("--frame", output);
            Assert.Contains("Content-Type: image/jpeg", output);
            Assert.Contains("Content-Length: ", output);
            Assert.False(service.IsStreamingActive);
        }

        [Fact]
        public async Task WriteStreamAsync_OutputsInfoFrame_WhenSessionLocked()
        {
            var mockCapture = new Mock<IDesktopCaptureProvider>();
            mockCapture.Setup(c => c.CheckSessionState()).Returns(DesktopSessionState.SessionLocked);

            var service = new ScreenStreamService(mockCapture.Object, NullLogger<ScreenStreamService>.Instance);

            using var ms = new MemoryStream();
            using var cts = new CancellationTokenSource();

            // Cancel after 120ms
            cts.CancelAfter(120);

            await service.WriteStreamAsync(ms, fps: 10, quality: 70, scale: 0.5, cts.Token);

            string output = Encoding.ASCII.GetString(ms.ToArray());
            Assert.Contains("--frame", output);
            Assert.Contains("Content-Type: image/jpeg", output);
            Assert.False(service.IsStreamingActive);
        }

        [Fact]
        public async Task WriteStreamAsync_RejectsConcurrentClientWithConflictException()
        {
            var mockCapture = new Mock<IDesktopCaptureProvider>();
            mockCapture.Setup(c => c.CheckSessionState()).Returns(DesktopSessionState.Ready);
            int w = 80, h = 60;
            mockCapture.Setup(c => c.CapturePrimaryScreen(out w, out h)).Returns(CreateTestJpeg(80, 60));

            var service = new ScreenStreamService(mockCapture.Object, NullLogger<ScreenStreamService>.Instance);

            using var ms1 = new MemoryStream();
            using var ms2 = new MemoryStream();
            using var cts1 = new CancellationTokenSource();

            // First stream runs in background
            var task1 = Task.Run(() => service.WriteStreamAsync(ms1, fps: 10, quality: 50, scale: 0.5, cts1.Token));

            // Small wait to ensure stream 1 acquires lock
            await Task.Delay(40);
            Assert.True(service.IsStreamingActive);

            // Second concurrent stream should throw ScreenStreamBusyException
            await Assert.ThrowsAsync<ScreenStreamBusyException>(() =>
                service.WriteStreamAsync(ms2, fps: 10, quality: 50, scale: 0.5, CancellationToken.None));

            // Terminate first stream
            cts1.Cancel();
            await task1;

            Assert.False(service.IsStreamingActive);

            // After first stream finishes, another stream should acquire lock without issue
            using var cts3 = new CancellationTokenSource();
            cts3.CancelAfter(80);
            using var ms3 = new MemoryStream();
            await service.WriteStreamAsync(ms3, fps: 10, quality: 50, scale: 0.5, cts3.Token);

            Assert.False(service.IsStreamingActive);
        }

        [Fact]
        public async Task ScreenStreamController_ReturnsConflict_WhenBusyExceptionOccurs()
        {
            var mockService = new Mock<IScreenStreamService>();
            mockService.Setup(s => s.WriteStreamAsync(
                It.IsAny<Stream>(), It.IsAny<int>(), It.IsAny<int>(), It.IsAny<double>(), It.IsAny<CancellationToken>()))
                .ThrowsAsync(new ScreenStreamBusyException("STREAM_BUSY: Outro cliente ativo."));

            var controller = new ScreenStreamController(mockService.Object);
            var httpContext = new DefaultHttpContext();
            controller.ControllerContext = new ControllerContext { HttpContext = httpContext };

            var result = await controller.StreamDesktop(10, 70, 0.67);

            var conflictResult = Assert.IsType<ConflictObjectResult>(result);
            Assert.Equal(409, conflictResult.StatusCode);
            Assert.Equal("multipart/x-mixed-replace; boundary=frame", httpContext.Response.ContentType);
            Assert.Equal("no-cache, no-store, must-revalidate", httpContext.Response.Headers["Cache-Control"]);
        }
    }
}
