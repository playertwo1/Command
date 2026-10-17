using System;
using System.Collections.Generic;
using System.IO;
using DroidDeck.Lib;
using DroidDeck.Models;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    public class ScreenshotService : IScreenshotService
    {
        private readonly IDesktopCaptureProvider _captureProvider;
        private readonly IJobHistoryService _jobHistory;
        private readonly ILogger<ScreenshotService> _logger;
        private readonly object _lock = new();

        private readonly Dictionary<string, ScreenshotMetadata> _byScreenshotId = new(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, ScreenshotMetadata> _byRequestId = new(StringComparer.OrdinalIgnoreCase);
        private readonly HashSet<string> _expiredIds = new(StringComparer.OrdinalIgnoreCase);
        private readonly string _storageDir;

        public const int ExpirationMinutes = 10;

        public ScreenshotService(
            IDesktopCaptureProvider captureProvider,
            IJobHistoryService jobHistory,
            ILogger<ScreenshotService> logger)
        {
            _captureProvider = captureProvider;
            _jobHistory = jobHistory;
            _logger = logger;
            _storageDir = Path.Combine(AppPaths.LocalDir, "screenshots");

            try
            {
                if (!Directory.Exists(_storageDir))
                {
                    Directory.CreateDirectory(_storageDir);
                }

                // Limpeza no startup de temporários acumulados anteriormente (F5-04)
                PurgeAllTempFiles();
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Erro inicializando diretório de capturas temporárias: {StorageDir}", _storageDir);
            }
        }

        public ScreenshotCaptureResult CapturePrimaryScreen(string requestId, string? deviceId)
        {
            if (string.IsNullOrWhiteSpace(requestId))
            {
                throw new ArgumentException("O campo requestId é obrigatório para idempotência e auditoria.", nameof(requestId));
            }

            lock (_lock)
            {
                CleanExpiredInternal();

                // Idempotência: se já existe requisição com mesmo requestId e ainda válida
                if (_byRequestId.TryGetValue(requestId, out var existing))
                {
                    if (DateTime.UtcNow <= existing.ExpiresAtUtc && File.Exists(existing.FilePath))
                    {
                        return ScreenshotCaptureResult.Ok(existing);
                    }

                    // Se expirou, remove para permitir nova tentativa
                    _byRequestId.Remove(requestId);
                    _byScreenshotId.Remove(existing.Id);
                }

                // Verifica sessão interativa e bloqueio de tela / UAC
                var sessionState = _captureProvider.CheckSessionState();
                if (sessionState == DesktopSessionState.SessionLocked)
                {
                    RecordFailedJob(requestId, deviceId, "SESSION_LOCKED: A área de trabalho está bloqueada ou em tela segura do Windows (UAC).");
                    return ScreenshotCaptureResult.Fail("SESSION_LOCKED", "A área de trabalho está bloqueada ou em tela segura do Windows (UAC). Desbloqueie o PC para capturar a tela.");
                }

                if (sessionState == DesktopSessionState.SecureDesktop)
                {
                    RecordFailedJob(requestId, deviceId, "SECURE_DESKTOP: Tela segura ativa (UAC/Login). Acesso negado.");
                    return ScreenshotCaptureResult.Fail("SECURE_DESKTOP", "Área de trabalho segura ativa (UAC/Login). Acesso negado.");
                }

                if (sessionState == DesktopSessionState.NotInteractive)
                {
                    RecordFailedJob(requestId, deviceId, "NOT_INTERACTIVE: Sessão do Windows não interativa ou monitor indisponível.");
                    return ScreenshotCaptureResult.Fail("NOT_INTERACTIVE", "Sessão do Windows não interativa ou monitor indisponível.");
                }

                try
                {
                    byte[] imageBytes = _captureProvider.CapturePrimaryScreen(out int width, out int height);
                    string screenshotId = Guid.NewGuid().ToString("N");
                    string filePath = Path.Combine(_storageDir, $"{screenshotId}.jpg");

                    File.WriteAllBytes(filePath, imageBytes);

                    var now = DateTime.UtcNow;
                    var metadata = new ScreenshotMetadata
                    {
                        Id = screenshotId,
                        RequestId = requestId,
                        DeviceId = deviceId,
                        CreatedAtUtc = now,
                        ExpiresAtUtc = now.AddMinutes(ExpirationMinutes),
                        Width = width,
                        Height = height,
                        FileSizeBytes = imageBytes.Length,
                        FilePath = filePath
                    };

                    _byScreenshotId[screenshotId] = metadata;
                    _byRequestId[requestId] = metadata;

                    // Registra sucesso no histórico de jobs auditável
                    var job = _jobHistory.GetOrCreateJob(requestId, "screenshot.capture", "primary_screen", deviceId, out _);
                    _jobHistory.UpdateJob(job.Id, "succeeded");

                    // Log apenas de metadados sem imagem ou dados privados (F5-02)
                    _logger.LogInformation("Screenshot capturada: Id={Id}, RequestId={RequestId}, Dimensões={Width}x{Height}, Tamanho={Size}B, Expira={Expires}",
                        metadata.Id, metadata.RequestId, metadata.Width, metadata.Height, metadata.FileSizeBytes, metadata.ExpiresAtUtc);

                    return ScreenshotCaptureResult.Ok(metadata);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Erro ao capturar tela para RequestId={RequestId}", requestId);
                    RecordFailedJob(requestId, deviceId, $"CAPTURE_FAILED: {ex.Message}");
                    return ScreenshotCaptureResult.Fail("CAPTURE_FAILED", $"Falha ao capturar tela: {ex.Message}");
                }
            }
        }

        public ScreenshotFileResult GetScreenshot(string id, string? deviceId)
        {
            lock (_lock)
            {
                CleanExpiredInternal();

                if (!_byScreenshotId.TryGetValue(id, out var meta))
                {
                    if (_expiredIds.Contains(id))
                    {
                        return ScreenshotFileResult.Expired();
                    }
                    return ScreenshotFileResult.NotFound();
                }

                if (DateTime.UtcNow > meta.ExpiresAtUtc)
                {
                    PurgeItem(meta);
                    return ScreenshotFileResult.Expired();
                }

                // Proteção contra acesso por outro aparelho (F5-02)
                if (!string.IsNullOrEmpty(meta.DeviceId) &&
                    !string.IsNullOrEmpty(deviceId) &&
                    !string.Equals(meta.DeviceId, deviceId, StringComparison.OrdinalIgnoreCase))
                {
                    return ScreenshotFileResult.Forbidden();
                }

                if (!File.Exists(meta.FilePath))
                {
                    return ScreenshotFileResult.NotFound("Arquivo temporário da captura não encontrado no disco.");
                }

                return ScreenshotFileResult.FoundFile(meta.FilePath, "image/jpeg", meta);
            }
        }

        public ScreenshotInfoDto? GetMetadata(string id)
        {
            lock (_lock)
            {
                CleanExpiredInternal();

                if (!_byScreenshotId.TryGetValue(id, out var meta))
                {
                    return null;
                }

                if (DateTime.UtcNow > meta.ExpiresAtUtc)
                {
                    PurgeItem(meta);
                    return null;
                }

                return ToDto(meta);
            }
        }

        public void CleanExpiredScreenshots()
        {
            lock (_lock)
            {
                CleanExpiredInternal();
            }
        }

        private void CleanExpiredInternal()
        {
            var now = DateTime.UtcNow;
            var expiredKeys = new List<string>();

            foreach (var kvp in _byScreenshotId)
            {
                if (now > kvp.Value.ExpiresAtUtc)
                {
                    expiredKeys.Add(kvp.Key);
                }
            }

            foreach (var key in expiredKeys)
            {
                if (_byScreenshotId.TryGetValue(key, out var meta))
                {
                    PurgeItem(meta);
                }
            }

            // Limpa arquivos órfãos no disco se houver
            try
            {
                if (Directory.Exists(_storageDir))
                {
                    foreach (var file in Directory.GetFiles(_storageDir, "*.jpg"))
                    {
                        var info = new FileInfo(file);
                        if (now - info.CreationTimeUtc > TimeSpan.FromMinutes(ExpirationMinutes))
                        {
                            try { File.Delete(file); } catch { }
                        }
                    }
                }
            }
            catch { }
        }

        private void PurgeItem(ScreenshotMetadata meta)
        {
            _byScreenshotId.Remove(meta.Id);
            _byRequestId.Remove(meta.RequestId);
            _expiredIds.Add(meta.Id);

            try
            {
                if (File.Exists(meta.FilePath))
                {
                    File.Delete(meta.FilePath);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Erro ao remover arquivo temporário expirado: {FilePath}", meta.FilePath);
            }
        }

        private void PurgeAllTempFiles()
        {
            if (!Directory.Exists(_storageDir)) return;

            foreach (var file in Directory.GetFiles(_storageDir))
            {
                try { File.Delete(file); } catch { }
            }
        }

        private void RecordFailedJob(string requestId, string? deviceId, string errorMessage)
        {
            try
            {
                var job = _jobHistory.GetOrCreateJob(requestId, "screenshot.capture", "primary_screen", deviceId, out _);
                _jobHistory.UpdateJob(job.Id, "failed", errorMessage);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Erro ao registrar falha do job para RequestId={RequestId}", requestId);
            }
        }

        public static ScreenshotInfoDto ToDto(ScreenshotMetadata meta) => new()
        {
            Id = meta.Id,
            RequestId = meta.RequestId,
            Width = meta.Width,
            Height = meta.Height,
            SizeBytes = meta.FileSizeBytes,
            CreatedAtUtc = meta.CreatedAtUtc,
            ExpiresAtUtc = meta.ExpiresAtUtc
        };
    }
}
