using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using Command.Services;
using Xunit;
using Xunit.Abstractions;

namespace Command.Tests
{
    public class ScreenStreamSpikeTests
    {
        private readonly ITestOutputHelper _output;

        public ScreenStreamSpikeTests(ITestOutputHelper output)
        {
            _output = output;
        }

        [Fact]
        public void Benchmark_LiveDesktopCapture_PerformanceAndCompression()
        {
            var provider = new WindowsDesktopCaptureProvider();
            var sessionState = provider.CheckSessionState();
            _output.WriteLine($"[SPIKE T0] Estado da Sessao: {sessionState}");

            if (sessionState != DesktopSessionState.Ready)
            {
                _output.WriteLine("[SPIKE T0] Sessao nao interativa ou bloqueada. Pulando benchmark ao vivo.");
                return;
            }

            // 1. Aquecimento
            byte[] initialFrame = provider.CapturePrimaryScreen(out int w, out int h);
            _output.WriteLine($"[SPIKE T0] Resolucao Nativa Detectada: {w}x{h} ({initialFrame.Length / 1024} KB)");
            Assert.True(w > 0 && h > 0);
            Assert.NotEmpty(initialFrame);

            // 2. Benchmark de 15 frames continuos (simulando 1 segundo a 15 FPS)
            const int iterations = 15;
            var sw = Stopwatch.StartNew();
            long totalCaptureMs = 0;
            long totalScaledMs = 0;
            long totalBytesRaw = 0;
            long totalBytesScaled = 0;

            ImageCodecInfo? jpegEncoder = GetEncoder(ImageFormat.Jpeg);
            Assert.NotNull(jpegEncoder);

            var encoderParams70 = new EncoderParameters(1);
            encoderParams70.Param[0] = new EncoderParameter(Encoder.Quality, 70L);

            for (int i = 0; i < iterations; i++)
            {
                var frameSw = Stopwatch.StartNew();
                byte[] frame = provider.CapturePrimaryScreen(out int frameW, out int frameH);
                frameSw.Stop();
                totalCaptureMs += frameSw.ElapsedMilliseconds;
                totalBytesRaw += frame.Length;

                // Teste de redimensionamento em memoria (escala 0.67x para telas mobile)
                var scaleSw = Stopwatch.StartNew();
                using (var ms = new MemoryStream(frame))
                using (var originalImg = Image.FromStream(ms))
                {
                    int targetW = (int)(frameW * 0.67);
                    int targetH = (int)(frameH * 0.67);
                    using var scaledBmp = new Bitmap(targetW, targetH);
                    using (var g = Graphics.FromImage(scaledBmp))
                    {
                        g.InterpolationMode = InterpolationMode.Bilinear;
                        g.DrawImage(originalImg, 0, 0, targetW, targetH);
                    }

                    using var scaledMs = new MemoryStream();
                    scaledBmp.Save(scaledMs, jpegEncoder, encoderParams70);
                    scaleSw.Stop();
                    totalScaledMs += scaleSw.ElapsedMilliseconds;
                    totalBytesScaled += scaledMs.Length;
                }
            }

            sw.Stop();

            double avgCaptureMs = (double)totalCaptureMs / iterations;
            double avgScaleCompressMs = (double)totalScaledMs / iterations;
            double avgFrameKb = (double)totalBytesRaw / iterations / 1024.0;
            double avgScaledFrameKb = (double)totalBytesScaled / iterations / 1024.0;
            double theoreticalMaxFps = 1000.0 / (avgCaptureMs + avgScaleCompressMs);

            _output.WriteLine($"[SPIKE T0] --- RESULTADOS DO BENCHMARK ({iterations} FRAMES) ---");
            _output.WriteLine($"[SPIKE T0] Tempo medio de Captura GDI BitBlt: {avgCaptureMs:F2} ms");
            _output.WriteLine($"[SPIKE T0] Tempo medio de Redimensionamento + JPEG 70%: {avgScaleCompressMs:F2} ms");
            _output.WriteLine($"[SPIKE T0] Tempo total por frame (Pipeline): {avgCaptureMs + avgScaleCompressMs:F2} ms");
            _output.WriteLine($"[SPIKE T0] Tamanho medio frame Nativo: {avgFrameKb:F1} KB");
            _output.WriteLine($"[SPIKE T0] Tamanho medio frame Mobile (67%): {avgScaledFrameKb:F1} KB");
            _output.WriteLine($"[SPIKE T0] Taxa teorica maxima sustentavel: {theoreticalMaxFps:F1} FPS");
            _output.WriteLine($"[SPIKE T0] Largura de banda estimada a 10 FPS (Mobile): {(avgScaledFrameKb * 10 * 8 / 1024.0):F2} Mbps");

            // Asserções de performance: captura deve ser proporcional à contagem de pixels da resolução nativa
            double pixelMegaCount = (w * h) / 1_000_000.0;
            double maxAllowedCaptureMs = Math.Max(60.0, pixelMegaCount * 50.0); // tolerância escalada para monitores de alta densidade (2.8K/4K)
            Assert.True(avgCaptureMs < maxAllowedCaptureMs, $"Tempo medio de captura muito alto: {avgCaptureMs}ms (limite: {maxAllowedCaptureMs}ms para {w}x{h})");
            double minAllowedFps = pixelMegaCount > 4.0 ? 2.0 : 3.0;
            Assert.True(theoreticalMaxFps >= minAllowedFps, $"FPS sustentavel insuficiente para streaming: {theoreticalMaxFps} FPS (minimo: {minAllowedFps} FPS para {w}x{h})");
        }

        private static ImageCodecInfo? GetEncoder(ImageFormat format)
        {
            var codecs = ImageCodecInfo.GetImageEncoders();
            foreach (var codec in codecs)
            {
                if (codec.FormatID == format.Guid)
                {
                    return codec;
                }
            }
            return null;
        }
    }
}
