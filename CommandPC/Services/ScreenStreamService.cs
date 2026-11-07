using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;

namespace Command.Services
{
    public class ScreenStreamBusyException : InvalidOperationException
    {
        public ScreenStreamBusyException(string message) : base(message) { }
    }

    public class ScreenStreamService : IScreenStreamService
    {
        private readonly IDesktopCaptureProvider _captureProvider;
        private readonly ILogger<ScreenStreamService> _logger;
        private readonly SemaphoreSlim _streamLock = new(1, 1);
        private static readonly byte[] BoundaryBytes = Encoding.ASCII.GetBytes("\r\n--frame\r\nContent-Type: image/jpeg\r\nContent-Length: ");
        private static readonly byte[] HeaderEndBytes = Encoding.ASCII.GetBytes("\r\n\r\n");

        public ScreenStreamService(IDesktopCaptureProvider captureProvider, ILogger<ScreenStreamService> logger)
        {
            _captureProvider = captureProvider;
            _logger = logger;
        }

        public bool IsStreamingActive => _streamLock.CurrentCount == 0;

        public async Task WriteStreamAsync(Stream outputStream, int fps, int quality, double scale, CancellationToken cancellationToken)
        {
            if (!_streamLock.Wait(0))
            {
                throw new ScreenStreamBusyException("STREAM_BUSY: Outro cliente já está conectado ao streaming de tela.");
            }

            fps = Math.Clamp(fps, 1, 20);
            quality = Math.Clamp(quality, 20, 95);
            scale = Math.Clamp(scale, 0.25, 1.0);

            _logger.LogInformation("Iniciando stream de desktop MJPEG: {Fps} FPS, {Quality}% qualidade, {Scale:F2}x escala", fps, quality, scale);

            ImageCodecInfo? jpegEncoder = GetEncoder(ImageFormat.Jpeg);
            var encoderParams = new EncoderParameters(1);
            encoderParams.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, (long)quality);

            try
            {
                var sw = new Stopwatch();

                while (!cancellationToken.IsCancellationRequested)
                {
                    sw.Restart();
                    byte[]? frameBytes = null;

                    var sessionState = _captureProvider.CheckSessionState();

                    if (sessionState != DesktopSessionState.Ready)
                    {
                        frameBytes = CreateInfoFrame(sessionState, (int)(1280 * scale), (int)(720 * scale));
                        await WriteFrameAsync(outputStream, frameBytes, cancellationToken);
                        await Task.Delay(1000, cancellationToken);
                        continue;
                    }

                    try
                    {
                        byte[] rawFrame = _captureProvider.CapturePrimaryScreen(out int w, out int h);
                        frameBytes = ProcessFrame(rawFrame, w, h, scale, jpegEncoder, encoderParams);
                    }
                    catch (Exception ex) when (ex is not OperationCanceledException)
                    {
                        _logger.LogWarning(ex, "Erro pontual durante captura de frame de tela: {Message}", ex.Message);
                        frameBytes = CreateInfoFrame(DesktopSessionState.NotInteractive, (int)(1280 * scale), (int)(720 * scale));
                    }

                    if (frameBytes != null && frameBytes.Length > 0)
                    {
                        await WriteFrameAsync(outputStream, frameBytes, cancellationToken);
                    }

                    sw.Stop();
                    int targetFrameDurationMs = 1000 / fps;
                    int sleepMs = Math.Max(5, targetFrameDurationMs - (int)sw.ElapsedMilliseconds);
                    await Task.Delay(sleepMs, cancellationToken);
                }
            }
            catch (OperationCanceledException)
            {
                // Desconexão esperada do cliente
            }
            finally
            {
                _streamLock.Release();
                _logger.LogInformation("Streaming de desktop encerrado.");
            }
        }

        private static async Task WriteFrameAsync(Stream outputStream, byte[] frameBytes, CancellationToken cancellationToken)
        {
            await outputStream.WriteAsync(BoundaryBytes, 0, BoundaryBytes.Length, cancellationToken);
            byte[] lengthHeader = Encoding.ASCII.GetBytes(frameBytes.Length.ToString());
            await outputStream.WriteAsync(lengthHeader, 0, lengthHeader.Length, cancellationToken);
            await outputStream.WriteAsync(HeaderEndBytes, 0, HeaderEndBytes.Length, cancellationToken);
            await outputStream.WriteAsync(frameBytes, 0, frameBytes.Length, cancellationToken);
            await outputStream.FlushAsync(cancellationToken);
        }

        private static byte[] ProcessFrame(
            byte[] rawFrame,
            int originalWidth,
            int originalHeight,
            double scale,
            ImageCodecInfo? encoder,
            EncoderParameters encoderParams)
        {
            if (scale >= 0.98 && encoder == null)
            {
                return rawFrame;
            }

            using var msIn = new MemoryStream(rawFrame);
            using var origImg = Image.FromStream(msIn);

            int targetW = Math.Max(64, (int)(originalWidth * scale));
            int targetH = Math.Max(64, (int)(originalHeight * scale));

            using var scaledBmp = new Bitmap(targetW, targetH);
            using (var g = Graphics.FromImage(scaledBmp))
            {
                g.InterpolationMode = InterpolationMode.Bilinear;
                g.CompositingQuality = CompositingQuality.HighSpeed;
                g.SmoothingMode = SmoothingMode.None;
                g.PixelOffsetMode = PixelOffsetMode.HighSpeed;
                g.DrawImage(origImg, 0, 0, targetW, targetH);
            }

            using var msOut = new MemoryStream();
            if (encoder != null)
            {
                scaledBmp.Save(msOut, encoder, encoderParams);
            }
            else
            {
                scaledBmp.Save(msOut, ImageFormat.Jpeg);
            }

            return msOut.ToArray();
        }

        private static byte[] CreateInfoFrame(DesktopSessionState state, int width, int height)
        {
            width = Math.Max(320, width);
            height = Math.Max(180, height);

            using var bmp = new Bitmap(width, height);
            using var g = Graphics.FromImage(bmp);
            g.Clear(Color.FromArgb(18, 17, 26)); // Fundo dark

            string title = state switch
            {
                DesktopSessionState.SessionLocked => "ÁREA DE TRABALHO BLOQUEADA",
                DesktopSessionState.SecureDesktop => "TELA SEGURA DO WINDOWS (UAC)",
                _ => "SESSÃO NÃO INTERATIVA"
            };

            string subtitle = state switch
            {
                DesktopSessionState.SessionLocked => "Aguardando desbloqueio no PC...",
                DesktopSessionState.SecureDesktop => "Confirme ou feche o prompt UAC no computador...",
                _ => "Aguardando inicialização da área de trabalho..."
            };

            using var pen = new Pen(Color.FromArgb(124, 58, 237), 3);
            g.DrawRectangle(pen, 10, 10, width - 20, height - 20);

            using var titleFont = new Font("Segoe UI", Math.Max(12, height / 25), FontStyle.Bold);
            using var subFont = new Font("Segoe UI", Math.Max(10, height / 35), FontStyle.Regular);
            using var purpleBrush = new SolidBrush(Color.FromArgb(167, 139, 250));
            using var textBrush = new SolidBrush(Color.FromArgb(220, 220, 230));

            var format = new StringFormat
            {
                Alignment = StringAlignment.Center,
                LineAlignment = StringAlignment.Center
            };

            var titleRect = new RectangleF(0, (height / 2f) - 30, width, 30);
            var subRect = new RectangleF(0, (height / 2f) + 5, width, 30);

            g.DrawString(title, titleFont, purpleBrush, titleRect, format);
            g.DrawString(subtitle, subFont, textBrush, subRect, format);

            using var ms = new MemoryStream();
            bmp.Save(ms, ImageFormat.Jpeg);
            return ms.ToArray();
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
