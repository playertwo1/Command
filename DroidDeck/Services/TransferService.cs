using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using DroidDeck.Models;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    public class TransferService : ITransferService
    {
        public const long MaxFileSizeBytes = 100 * 1024 * 1024; // 100 MiB

        private static readonly HashSet<string> BlockedExtensions = new(StringComparer.OrdinalIgnoreCase)
        {
            ".exe", ".bat", ".cmd", ".ps1", ".vbs", ".sh", ".msi", ".dll", ".com",
            ".scr", ".pif", ".reg", ".jar", ".appx", ".sys", ".drv"
        };

        private static readonly HashSet<string> ReservedWindowsNames = new(StringComparer.OrdinalIgnoreCase)
        {
            "CON", "PRN", "AUX", "NUL",
            "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
            "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
        };

        private readonly string _inboundRoot;
        private readonly string _outboundRoot;
        private readonly IJobHistoryService _jobHistoryService;
        private readonly ILogger<TransferService> _logger;

        public TransferService(
            IJobHistoryService jobHistoryService,
            ILogger<TransferService> logger,
            string? customInboundRoot = null,
            string? customOutboundRoot = null)
        {
            _jobHistoryService = jobHistoryService;
            _logger = logger;

            string baseDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "DroidDeck",
                "transfers");

            _inboundRoot = Path.GetFullPath(customInboundRoot ?? Path.Combine(baseDir, "inbound"));
            _outboundRoot = Path.GetFullPath(customOutboundRoot ?? Path.Combine(baseDir, "outbound"));

            EnsureDirectoryExists(_inboundRoot);
            EnsureDirectoryExists(_outboundRoot);
        }

        public string InboundRootPath => _inboundRoot;
        public string OutboundRootPath => _outboundRoot;

        public IEnumerable<TransferItemDto> ListFiles(string rootId, string requestingDeviceId)
        {
            if (!string.Equals(rootId, "outbound", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("Apenas a raiz de saída ('outbound') pode ser listada.");
            }

            var dir = new DirectoryInfo(_outboundRoot);
            if (!dir.Exists) return Enumerable.Empty<TransferItemDto>();

            var items = new List<TransferItemDto>();
            foreach (var fi in dir.EnumerateFiles())
            {
                if ((fi.Attributes & FileAttributes.ReparsePoint) != 0) continue; // Ignora symlinks
                if (fi.Name.EndsWith(".tmp", StringComparison.OrdinalIgnoreCase)) continue;

                string sha = ComputeFileSha256(fi.FullName);
                items.Add(new TransferItemDto
                {
                    Name = fi.Name,
                    SizeBytes = fi.Length,
                    Sha256 = sha,
                    ModifiedAtUtc = fi.LastWriteTimeUtc
                });
            }

            return items.OrderBy(i => i.Name);
        }

        public async Task<UploadTransferResult> UploadFileAsync(
            string rootId,
            string fileName,
            Stream contentStream,
            string? expectedSha256,
            string requestingDeviceId,
            string? requestId = null)
        {
            if (!string.Equals(rootId, "inbound", StringComparison.OrdinalIgnoreCase))
            {
                return new UploadTransferResult
                {
                    Success = false,
                    ErrorCode = "INVALID_ROOT",
                    ErrorMessage = "Upload permitido exclusivamente para a raiz 'inbound'."
                };
            }

            var validation = ValidateFileName(fileName);
            if (!validation.IsValid)
            {
                return new UploadTransferResult
                {
                    Success = false,
                    ErrorCode = validation.ErrorCode,
                    ErrorMessage = validation.ErrorMessage
                };
            }

            string cleanName = validation.CleanFileName;
            string targetPath = Path.Combine(_inboundRoot, cleanName);

            // Revalida confinamento do caminho canônico
            if (!IsPathWithinDirectory(targetPath, _inboundRoot))
            {
                return new UploadTransferResult
                {
                    Success = false,
                    ErrorCode = "PATH_TRAVERSAL",
                    ErrorMessage = "Caminho fora dos limites autorizados da raiz de entrada."
                };
            }

            // Colisão de nome: rejeita e não sobrescreve
            if (File.Exists(targetPath))
            {
                return new UploadTransferResult
                {
                    Success = false,
                    ErrorCode = "FILE_ALREADY_EXISTS",
                    ErrorMessage = $"O arquivo '{cleanName}' já existe na pasta de entrada. Sobrescrita não autorizada."
                };
            }

            string tmpPath = Path.Combine(_inboundRoot, $"{cleanName}.{Guid.NewGuid():N}.tmp");
            long totalBytes = 0;
            string computedSha256 = string.Empty;

            try
            {
                using (var fileStream = new FileStream(tmpPath, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                using (var sha = SHA256.Create())
                {
                    byte[] buffer = new byte[81920];
                    int bytesRead;

                    while ((bytesRead = await contentStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                    {
                        totalBytes += bytesRead;
                        if (totalBytes > MaxFileSizeBytes)
                        {
                            fileStream.Close();
                            TryDeleteFile(tmpPath);
                            return new UploadTransferResult
                            {
                                Success = false,
                                ErrorCode = "FILE_TOO_LARGE",
                                ErrorMessage = $"O arquivo excede o limite máximo permitido de {MaxFileSizeBytes / (1024 * 1024)} MiB."
                            };
                        }

                        await fileStream.WriteAsync(buffer, 0, bytesRead);
                        sha.TransformBlock(buffer, 0, bytesRead, null, 0);
                    }

                    sha.TransformFinalBlock(Array.Empty<byte>(), 0, 0);
                    computedSha256 = BitConverter.ToString(sha.Hash!).Replace("-", "").ToLowerInvariant();
                }

                // Verifica integridade com hash esperado
                if (!string.IsNullOrWhiteSpace(expectedSha256))
                {
                    string normalizedExpected = expectedSha256.Trim().ToLowerInvariant();
                    if (!string.Equals(computedSha256, normalizedExpected, StringComparison.OrdinalIgnoreCase))
                    {
                        TryDeleteFile(tmpPath);
                        return new UploadTransferResult
                        {
                            Success = false,
                            ErrorCode = "CHECKSUM_MISMATCH",
                            ErrorMessage = $"Falha de integridade: SHA-256 computado ({computedSha256}) difere do esperado ({normalizedExpected})."
                        };
                    }
                }

                // Promoção atômica
                File.Move(tmpPath, targetPath);

                var dto = new TransferItemDto
                {
                    Name = cleanName,
                    SizeBytes = totalBytes,
                    Sha256 = computedSha256,
                    ModifiedAtUtc = DateTime.UtcNow
                };

                // Auditoria sanitizada no histórico de jobs
                var job = _jobHistoryService.GetOrCreateJob(requestId ?? Guid.NewGuid().ToString("N"), "transfer.upload", cleanName, requestingDeviceId, out _);
                _jobHistoryService.UpdateJob(job.Id, "succeeded");

                _logger.LogInformation("Upload concluído com sucesso: {FileName} ({SizeBytes} bytes, SHA256 {Sha256}) por {Device}",
                    cleanName, totalBytes, computedSha256, requestingDeviceId);

                return new UploadTransferResult
                {
                    Success = true,
                    Item = dto
                };
            }
            catch (Exception ex)
            {
                TryDeleteFile(tmpPath);
                _logger.LogError(ex, "Falha durante gravação de upload do arquivo {FileName}", cleanName);
                return new UploadTransferResult
                {
                    Success = false,
                    ErrorCode = "WRITE_FAILED",
                    ErrorMessage = $"Falha ao gravar arquivo: {ex.Message}"
                };
            }
        }

        public FileDownloadResult GetFileForDownload(string rootId, string fileName, string requestingDeviceId)
        {
            if (!string.Equals(rootId, "outbound", StringComparison.OrdinalIgnoreCase))
            {
                return new FileDownloadResult
                {
                    Success = false,
                    ErrorCode = "INVALID_ROOT",
                    ErrorMessage = "Download permitido exclusivamente a partir da raiz 'outbound'."
                };
            }

            var validation = ValidateFileName(fileName);
            if (!validation.IsValid)
            {
                return new FileDownloadResult
                {
                    Success = false,
                    ErrorCode = validation.ErrorCode,
                    ErrorMessage = validation.ErrorMessage
                };
            }

            string cleanName = validation.CleanFileName;
            string targetPath = Path.Combine(_outboundRoot, cleanName);

            if (!IsPathWithinDirectory(targetPath, _outboundRoot))
            {
                return new FileDownloadResult
                {
                    Success = false,
                    ErrorCode = "PATH_TRAVERSAL",
                    ErrorMessage = "Tentativa de acesso fora da raiz autorizada."
                };
            }

            var fi = new FileInfo(targetPath);
            if (!fi.Exists)
            {
                return new FileDownloadResult
                {
                    Success = false,
                    ErrorCode = "FILE_NOT_FOUND",
                    ErrorMessage = $"O arquivo '{cleanName}' não foi encontrado na pasta de saída."
                };
            }

            // Proteção contra symlinks e reparse points
            if ((fi.Attributes & FileAttributes.ReparsePoint) != 0)
            {
                return new FileDownloadResult
                {
                    Success = false,
                    ErrorCode = "ACCESS_DENIED",
                    ErrorMessage = "Links simbólicos e reparse points não são autorizados para leitura."
                };
            }

            string sha256 = ComputeFileSha256(targetPath);
            var fs = new FileStream(targetPath, FileMode.Open, FileAccess.Read, FileShare.Read);

            var job = _jobHistoryService.GetOrCreateJob(Guid.NewGuid().ToString("N"), "transfer.download", cleanName, requestingDeviceId, out _);
            _jobHistoryService.UpdateJob(job.Id, "succeeded");

            return new FileDownloadResult
            {
                Success = true,
                Stream = fs,
                FileName = cleanName,
                SizeBytes = fi.Length,
                Sha256 = sha256,
                ContentType = GetMimeType(cleanName)
            };
        }

        private static (bool IsValid, string CleanFileName, string ErrorCode, string ErrorMessage) ValidateFileName(string? rawName)
        {
            if (string.IsNullOrWhiteSpace(rawName))
            {
                return (false, string.Empty, "INVALID_FILENAME", "Nome de arquivo ausente ou vazio.");
            }

            string name = rawName.Trim();

            // Rejeita caracteres de controle e barras
            if (name.Contains('/') || name.Contains('\\') || name.Contains("..") || name.Contains(':'))
            {
                return (false, string.Empty, "PATH_TRAVERSAL", "Nome de arquivo contém caracteres ou sequências de traversal proibidos.");
            }

            // Verifica padrão simples: letras, números, hífen, sublinhado, ponto e espaço
            if (!Regex.IsMatch(name, @"^[a-zA-Z0-9_\-\. ]+\.[a-zA-Z0-9]+$"))
            {
                return (false, string.Empty, "INVALID_FILENAME_PATTERN", "Nome de arquivo deve conter apenas caracteres alfanuméricos simples e extensão.");
            }

            string ext = Path.GetExtension(name);
            if (string.IsNullOrWhiteSpace(ext) || BlockedExtensions.Contains(ext))
            {
                return (false, string.Empty, "BLOCKED_EXTENSION", $"A extensão '{ext}' não é permitida por motivos de segurança.");
            }

            string nameWithoutExt = Path.GetFileNameWithoutExtension(name).Trim();
            if (ReservedWindowsNames.Contains(nameWithoutExt))
            {
                return (false, string.Empty, "RESERVED_FILENAME", $"O nome '{nameWithoutExt}' é um dispositivo reservado do Windows.");
            }

            return (true, name, string.Empty, string.Empty);
        }

        private static bool IsPathWithinDirectory(string candidatePath, string rootDirectory)
        {
            string fullCandidate = Path.GetFullPath(candidatePath);
            string fullRoot = Path.GetFullPath(rootDirectory);

            if (!fullRoot.EndsWith(Path.DirectorySeparatorChar.ToString()))
            {
                fullRoot += Path.DirectorySeparatorChar;
            }

            return fullCandidate.StartsWith(fullRoot, StringComparison.OrdinalIgnoreCase);
        }

        private static string ComputeFileSha256(string filePath)
        {
            using var sha = SHA256.Create();
            using var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            byte[] hash = sha.ComputeHash(fs);
            return BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
        }

        private static string GetMimeType(string fileName)
        {
            string ext = Path.GetExtension(fileName).ToLowerInvariant();
            return ext switch
            {
                ".txt" or ".log" => "text/plain",
                ".pdf" => "application/pdf",
                ".png" => "image/png",
                ".jpg" or ".jpeg" => "image/jpeg",
                ".gif" => "image/gif",
                ".webp" => "image/webp",
                ".zip" => "application/zip",
                ".json" => "application/json",
                ".csv" => "text/csv",
                ".md" => "text/markdown",
                ".mp3" => "audio/mpeg",
                ".wav" => "audio/wav",
                ".mp4" => "video/mp4",
                _ => "application/octet-stream"
            };
        }

        private static void EnsureDirectoryExists(string dir)
        {
            if (!Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }
        }

        private static void TryDeleteFile(string path)
        {
            try
            {
                if (File.Exists(path)) File.Delete(path);
            }
            catch { }
        }
    }
}
