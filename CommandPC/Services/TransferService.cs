using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Command.Models;
using Microsoft.Extensions.Logging;

namespace Command.Services
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
        private readonly IDestinationFolderStore? _destinations;
        private readonly IJobHistoryService _jobHistoryService;
        private readonly ILogger<TransferService> _logger;

        public TransferService(
            IJobHistoryService jobHistoryService,
            ILogger<TransferService> logger,
            string? customInboundRoot = null,
            string? customOutboundRoot = null,
            IDestinationFolderStore? destinations = null)
        {
            _destinations = destinations;
            _jobHistoryService = jobHistoryService;
            _logger = logger;

            string baseDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Command",
                "transfers");

            _inboundRoot = Path.GetFullPath(customInboundRoot ?? Path.Combine(baseDir, "inbound"));
            _outboundRoot = Path.GetFullPath(customOutboundRoot ?? Path.Combine(baseDir, "outbound"));

            EnsureDirectoryExists(_inboundRoot);
            EnsureDirectoryExists(_outboundRoot);
            CleanOrphanedParts();
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
            string? requestId = null,
            string? conflictPolicy = null)
        {
            var root = ResolveUploadRoot(rootId);
            if (root == null)
            {
                return new UploadTransferResult
                {
                    Success = false,
                    ErrorCode = "INVALID_ROOT",
                    ErrorMessage = "Destino de upload inválido ou inexistente."
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
            string targetPath = Path.Combine(root, cleanName);

            // Revalida confinamento do caminho canônico
            if (!IsPathWithinDirectory(targetPath, root))
            {
                return new UploadTransferResult
                {
                    Success = false,
                    ErrorCode = "PATH_TRAVERSAL",
                    ErrorMessage = "Caminho fora dos limites autorizados da raiz de entrada."
                };
            }

            // Colisão de nome: rejeita e não sobrescreve
            if (File.Exists(targetPath) && !IsConflictPolicy(conflictPolicy))
            {
                return new UploadTransferResult
                {
                    Success = false,
                    ErrorCode = "FILE_ALREADY_EXISTS",
                    ErrorMessage = $"O arquivo '{cleanName}' já existe na pasta de entrada. Sobrescrita não autorizada."
                };
            }

            string tmpPath = Path.Combine(root, $"{cleanName}.{Guid.NewGuid():N}.tmp");
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
                targetPath = ResolveConflict(targetPath, conflictPolicy);
                File.Move(tmpPath, targetPath, conflictPolicy == "replace");
                cleanName = Path.GetFileName(targetPath);

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

        public FileDownloadResult GetFileForDownload(
            string rootId,
            string fileName,
            string requestingDeviceId,
            long? offset = null,
            long? length = null)
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

            string cleanName;
            string targetPath;

            if (fileName.Contains('/') || fileName.Contains('\\'))
            {
                var subValidation = ValidateSubPath(fileName);
                if (!subValidation.IsValid)
                {
                    return new FileDownloadResult
                    {
                        Success = false,
                        ErrorCode = subValidation.ErrorCode,
                        ErrorMessage = subValidation.ErrorMessage
                    };
                }

                string ext = Path.GetExtension(subValidation.NormalizedSubPath);
                if (string.IsNullOrWhiteSpace(ext) || BlockedExtensions.Contains(ext))
                {
                    return new FileDownloadResult
                    {
                        Success = false,
                        ErrorCode = "BLOCKED_EXTENSION",
                        ErrorMessage = $"A extensão '{ext}' não é permitida por motivos de segurança."
                    };
                }

                cleanName = Path.GetFileName(subValidation.NormalizedSubPath);
                targetPath = Path.Combine(_outboundRoot, subValidation.NormalizedSubPath.Replace('/', Path.DirectorySeparatorChar));
            }
            else
            {
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

                cleanName = validation.CleanFileName;
                targetPath = Path.Combine(_outboundRoot, cleanName);
            }

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

            long fileLength = fi.Length;
            long actualOffset = offset ?? 0;
            if (actualOffset < 0 || (actualOffset >= fileLength && fileLength > 0))
            {
                return new FileDownloadResult
                {
                    Success = false,
                    ErrorCode = "INVALID_RANGE",
                    ErrorMessage = "Offset de download fora dos limites do arquivo."
                };
            }

            long remaining = fileLength - actualOffset;
            long actualChunkLength = length.HasValue ? Math.Min(length.Value, remaining) : remaining;

            var fs = new FileStream(targetPath, FileMode.Open, FileAccess.Read, FileShare.Read);
            if (actualOffset > 0)
            {
                fs.Seek(actualOffset, SeekOrigin.Begin);
            }

            Stream resultStream = (offset.HasValue || length.HasValue)
                ? new BoundedReadStream(fs, actualChunkLength)
                : fs;

            string sha256 = ComputeFileSha256(targetPath);

            var job = _jobHistoryService.GetOrCreateJob(Guid.NewGuid().ToString("N"), "transfer.download", cleanName, requestingDeviceId, out _);
            _jobHistoryService.UpdateJob(job.Id, "succeeded");

            return new FileDownloadResult
            {
                Success = true,
                Stream = resultStream,
                FileName = cleanName,
                SizeBytes = fi.Length,
                Sha256 = sha256,
                ContentType = GetMimeType(cleanName),
                Offset = actualOffset,
                ChunkLength = actualChunkLength,
                IsChunked = offset.HasValue || length.HasValue
            };
        }

        public DirectoryBrowseResult BrowseDirectory(string rootId, string? subPath, string requestingDeviceId)
        {
            string baseRoot;
            if (string.Equals(rootId, "outbound", StringComparison.OrdinalIgnoreCase))
            {
                baseRoot = _outboundRoot;
            }
            else if (string.Equals(rootId, "inbound", StringComparison.OrdinalIgnoreCase))
            {
                baseRoot = _inboundRoot;
            }
            else
            {
                return new DirectoryBrowseResult
                {
                    Success = false,
                    ErrorCode = "INVALID_ROOT",
                    ErrorMessage = "Apenas as raízes 'outbound' e 'inbound' são autorizadas para navegação."
                };
            }

            var pathValidation = ValidateSubPath(subPath);
            if (!pathValidation.IsValid)
            {
                return new DirectoryBrowseResult
                {
                    Success = false,
                    ErrorCode = pathValidation.ErrorCode,
                    ErrorMessage = pathValidation.ErrorMessage
                };
            }

            string relativeSubPath = pathValidation.NormalizedSubPath;
            string targetDir = string.IsNullOrEmpty(relativeSubPath)
                ? baseRoot
                : Path.GetFullPath(Path.Combine(baseRoot, relativeSubPath.Replace('/', Path.DirectorySeparatorChar)));

            if (!IsPathWithinDirectory(targetDir, baseRoot) && !string.Equals(targetDir, baseRoot, StringComparison.OrdinalIgnoreCase))
            {
                return new DirectoryBrowseResult
                {
                    Success = false,
                    ErrorCode = "PATH_TRAVERSAL",
                    ErrorMessage = "Tentativa de navegação fora dos limites da raiz autorizada."
                };
            }

            var dirInfo = new DirectoryInfo(targetDir);
            if (!dirInfo.Exists)
            {
                return new DirectoryBrowseResult
                {
                    Success = false,
                    ErrorCode = "DIRECTORY_NOT_FOUND",
                    ErrorMessage = $"Diretório não encontrado: '{relativeSubPath}'."
                };
            }

            if ((dirInfo.Attributes & FileAttributes.ReparsePoint) != 0)
            {
                return new DirectoryBrowseResult
                {
                    Success = false,
                    ErrorCode = "ACCESS_DENIED",
                    ErrorMessage = "Navegação em links simbólicos ou junções não é autorizada."
                };
            }

            var items = new List<DirectoryItemDto>();

            // Pastas
            foreach (var di in dirInfo.EnumerateDirectories())
            {
                if ((di.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                if (di.Name.StartsWith(".")) continue;

                string rel = string.IsNullOrEmpty(relativeSubPath) ? di.Name : $"{relativeSubPath}/{di.Name}";
                items.Add(new DirectoryItemDto
                {
                    Name = di.Name,
                    RelativePath = rel,
                    SizeBytes = 0,
                    ModifiedAtUtc = di.LastWriteTimeUtc,
                    Extension = string.Empty,
                    IsDirectory = true
                });
            }

            // Arquivos
            foreach (var fi in dirInfo.EnumerateFiles())
            {
                if ((fi.Attributes & FileAttributes.ReparsePoint) != 0) continue;
                if (fi.Name.EndsWith(".tmp", StringComparison.OrdinalIgnoreCase)) continue;

                string rel = string.IsNullOrEmpty(relativeSubPath) ? fi.Name : $"{relativeSubPath}/{fi.Name}";
                items.Add(new DirectoryItemDto
                {
                    Name = fi.Name,
                    RelativePath = rel,
                    SizeBytes = fi.Length,
                    ModifiedAtUtc = fi.LastWriteTimeUtc,
                    Extension = fi.Extension.ToLowerInvariant(),
                    IsDirectory = false
                });
            }

            return new DirectoryBrowseResult
            {
                Success = true,
                RootId = rootId.ToLowerInvariant(),
                CurrentPath = relativeSubPath,
                Items = items.OrderByDescending(i => i.IsDirectory).ThenBy(i => i.Name).ToList()
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

        private static (bool IsValid, string NormalizedSubPath, string ErrorCode, string ErrorMessage) ValidateSubPath(string? rawSubPath)
        {
            if (string.IsNullOrWhiteSpace(rawSubPath))
            {
                return (true, string.Empty, string.Empty, string.Empty);
            }

            string clean = rawSubPath.Trim().Replace('\\', '/');

            // Rejeita traversal explícito e drives
            if (clean.Contains("..") || clean.Contains(':') || clean.StartsWith("/"))
            {
                return (false, string.Empty, "PATH_TRAVERSAL", "Subcaminho contém sequências ou formato de traversal proibidos.");
            }

            // Cada segmento deve ser seguro
            var segments = clean.Split('/', StringSplitOptions.RemoveEmptyEntries);
            foreach (var segment in segments)
            {
                if (string.IsNullOrWhiteSpace(segment) || segment == "." || segment == "..")
                {
                    return (false, string.Empty, "PATH_TRAVERSAL", "Segmento de caminho inválido.");
                }

                if (!Regex.IsMatch(segment, @"^[a-zA-Z0-9_\-\. ]+$"))
                {
                    return (false, string.Empty, "INVALID_PATH_PATTERN", $"O segmento '{segment}' contém caracteres proibidos.");
                }

                string segWithoutExt = Path.GetFileNameWithoutExtension(segment).Trim();
                if (ReservedWindowsNames.Contains(segWithoutExt) || ReservedWindowsNames.Contains(segment))
                {
                    return (false, string.Empty, "RESERVED_FILENAME", $"O segmento '{segment}' é um nome reservado do Windows.");
                }
            }

            string normalized = string.Join('/', segments);
            return (true, normalized, string.Empty, string.Empty);
        }

        private string? ResolveUploadRoot(string rootId)
        {
            if (string.Equals(rootId, "inbound", StringComparison.OrdinalIgnoreCase)) return _inboundRoot;
            var path = _destinations?.TryGetPath(rootId);
            return path != null && Directory.Exists(path) ? path : null;
        }

        private static bool IsConflictPolicy(string? policy) => policy is "replace" or "keepBoth";

        // keepBoth grava "nome (1).ext"; sem política o chamador já rejeitou a colisão antes.
        private static string ResolveConflict(string targetPath, string? policy)
        {
            if (policy != "keepBoth" || !File.Exists(targetPath)) return targetPath;
            var dir = Path.GetDirectoryName(targetPath)!;
            var name = Path.GetFileNameWithoutExtension(targetPath);
            var ext = Path.GetExtension(targetPath);
            for (int i = 1; ; i++)
            {
                var candidate = Path.Combine(dir, $"{name} ({i}){ext}");
                if (!File.Exists(candidate)) return candidate;
            }
        }

        private static void EnsureDirectoryExists(string dir)
        {
            if (!Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }
        }

        public async Task<ChunkUploadResult> UploadChunkAsync(
            string uploadId,
            string rootId,
            string fileName,
            long offset,
            long totalSize,
            bool isLastChunk,
            Stream chunkStream,
            string? expectedSha256,
            string requestingDeviceId,
            string? requestId = null,
            string? conflictPolicy = null)
        {
            var root = ResolveUploadRoot(rootId);
            if (root == null)
            {
                return new ChunkUploadResult
                {
                    Success = false,
                    ErrorCode = "INVALID_ROOT",
                    ErrorMessage = "Destino de upload inválido ou inexistente."
                };
            }

            if (string.IsNullOrWhiteSpace(uploadId) || !Regex.IsMatch(uploadId, @"^[a-zA-Z0-9_\-]{1,64}$"))
            {
                return new ChunkUploadResult
                {
                    Success = false,
                    ErrorCode = "INVALID_UPLOAD_ID",
                    ErrorMessage = "Identificador de upload inválido."
                };
            }

            var validation = ValidateFileName(fileName);
            if (!validation.IsValid)
            {
                return new ChunkUploadResult
                {
                    Success = false,
                    ErrorCode = validation.ErrorCode,
                    ErrorMessage = validation.ErrorMessage
                };
            }

            string cleanName = validation.CleanFileName;
            string targetPath = Path.Combine(root, cleanName);

            if (!IsPathWithinDirectory(targetPath, root))
            {
                return new ChunkUploadResult
                {
                    Success = false,
                    ErrorCode = "PATH_TRAVERSAL",
                    ErrorMessage = "Caminho fora dos limites autorizados da raiz de entrada."
                };
            }

            // Se o arquivo final completo já existe, rejeita sobrescrita
            if (File.Exists(targetPath) && !IsConflictPolicy(conflictPolicy))
            {
                return new ChunkUploadResult
                {
                    Success = false,
                    ErrorCode = "FILE_ALREADY_EXISTS",
                    ErrorMessage = $"O arquivo '{cleanName}' já existe na pasta de entrada."
                };
            }

            if (totalSize <= 0 || totalSize > MaxFileSizeBytes)
            {
                return new ChunkUploadResult
                {
                    Success = false,
                    ErrorCode = "FILE_TOO_LARGE",
                    ErrorMessage = $"O tamanho total excede o limite máximo permitido de {MaxFileSizeBytes / (1024 * 1024)} MiB."
                };
            }

            if (offset < 0 || offset >= totalSize)
            {
                return new ChunkUploadResult
                {
                    Success = false,
                    ErrorCode = "INVALID_CHUNK_OFFSET",
                    ErrorMessage = "Offset do bloco fora dos limites válidos."
                };
            }

            string partPath = Path.Combine(root, $"{cleanName}.{uploadId}.part");
            if (!IsPathWithinDirectory(partPath, root))
            {
                return new ChunkUploadResult
                {
                    Success = false,
                    ErrorCode = "PATH_TRAVERSAL",
                    ErrorMessage = "Caminho de bloco temporário inválido."
                };
            }

            try
            {
                FileStream fs;
                if (offset == 0)
                {
                    fs = new FileStream(partPath, FileMode.Create, FileAccess.Write, FileShare.ReadWrite);
                }
                else
                {
                    if (!File.Exists(partPath))
                    {
                        return new ChunkUploadResult
                        {
                            Success = false,
                            ErrorCode = "PART_NOT_FOUND",
                            ErrorMessage = "Arquivo de bloco temporário não encontrado para retomada."
                        };
                    }

                    fs = new FileStream(partPath, FileMode.OpenOrCreate, FileAccess.Write, FileShare.ReadWrite);
                    long existingPartLength = fs.Length;
                    if (existingPartLength < offset)
                    {
                        fs.Dispose();
                        return new ChunkUploadResult
                        {
                            Success = false,
                            ErrorCode = "CHUNK_OFFSET_GAP",
                            ErrorMessage = $"Offset recebido ({offset}) excede os bytes recebidos até o momento ({existingPartLength})."
                        };
                    }
                    fs.Seek(offset, SeekOrigin.Begin);
                }

                using (fs)
                {
                    byte[] buffer = new byte[81920];
                    int read;
                    while ((read = await chunkStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                    {
                        await fs.WriteAsync(buffer, 0, read);
                        if (fs.Position > MaxFileSizeBytes)
                        {
                            fs.Close();
                            TryDeleteFile(partPath);
                            return new ChunkUploadResult
                            {
                                Success = false,
                                ErrorCode = "FILE_TOO_LARGE",
                                ErrorMessage = "Tamanho acumulado excede o limite permitido."
                            };
                        }
                    }

                    await fs.FlushAsync();
                }

                long currentLength = new FileInfo(partPath).Length;

                if (isLastChunk)
                {
                    if (currentLength != totalSize)
                    {
                        return new ChunkUploadResult
                        {
                            Success = false,
                            ErrorCode = "INCOMPLETE_FILE",
                            ErrorMessage = $"Tamanho final ({currentLength}) não confere com o total esperado ({totalSize})."
                        };
                    }

                    string computedSha = ComputeFileSha256(partPath);
                    if (!string.IsNullOrWhiteSpace(expectedSha256))
                    {
                        string normalized = expectedSha256.Trim().ToLowerInvariant();
                        if (!string.Equals(computedSha, normalized, StringComparison.OrdinalIgnoreCase))
                        {
                            TryDeleteFile(partPath);
                            return new ChunkUploadResult
                            {
                                Success = false,
                                ErrorCode = "CHECKSUM_MISMATCH",
                                ErrorMessage = $"Falha de integridade: SHA-256 computado ({computedSha}) difere do esperado ({normalized})."
                            };
                        }
                    }

                    // Promove atômico
                    targetPath = ResolveConflict(targetPath, conflictPolicy);
                    File.Move(partPath, targetPath, conflictPolicy == "replace");
                    cleanName = Path.GetFileName(targetPath);

                    var dto = new TransferItemDto
                    {
                        Name = cleanName,
                        SizeBytes = currentLength,
                        Sha256 = computedSha,
                        ModifiedAtUtc = DateTime.UtcNow
                    };

                    var job = _jobHistoryService.GetOrCreateJob(requestId ?? Guid.NewGuid().ToString("N"), "transfer.upload", cleanName, requestingDeviceId, out _);
                    _jobHistoryService.UpdateJob(job.Id, "succeeded");

                    _logger.LogInformation("Upload em blocos concluído: {FileName} ({SizeBytes} bytes, SHA256 {Sha}) por {Device}",
                        cleanName, currentLength, computedSha, requestingDeviceId);

                    return new ChunkUploadResult
                    {
                        Success = true,
                        IsComplete = true,
                        UploadId = uploadId,
                        FileName = cleanName,
                        BytesReceived = currentLength,
                        Item = dto
                    };
                }

                return new ChunkUploadResult
                {
                    Success = true,
                    IsComplete = false,
                    UploadId = uploadId,
                    FileName = cleanName,
                    BytesReceived = currentLength
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Falha durante gravação de bloco para {FileName}", cleanName);
                return new ChunkUploadResult
                {
                    Success = false,
                    ErrorCode = "WRITE_FAILED",
                    ErrorMessage = $"Falha ao gravar bloco: {ex.Message}"
                };
            }
        }

        public ResumableUploadStatusResult GetUploadStatus(string uploadId, string rootId, string fileName)
        {
            var root = ResolveUploadRoot(rootId);
            if (root == null)
            {
                return new ResumableUploadStatusResult { Exists = false, UploadId = uploadId, FileName = fileName };
            }

            var validation = ValidateFileName(fileName);
            if (!validation.IsValid)
            {
                return new ResumableUploadStatusResult { Exists = false, UploadId = uploadId, FileName = fileName };
            }

            string cleanName = validation.CleanFileName;
            string targetPath = Path.Combine(root, cleanName);
            if (File.Exists(targetPath))
            {
                var fi = new FileInfo(targetPath);
                return new ResumableUploadStatusResult
                {
                    Exists = true,
                    IsComplete = true,
                    UploadId = uploadId,
                    FileName = cleanName,
                    BytesReceived = fi.Length,
                    TotalSize = fi.Length
                };
            }

            string partPath = Path.Combine(root, $"{cleanName}.{uploadId}.part");
            if (File.Exists(partPath))
            {
                var fi = new FileInfo(partPath);
                return new ResumableUploadStatusResult
                {
                    Exists = true,
                    IsComplete = false,
                    UploadId = uploadId,
                    FileName = cleanName,
                    BytesReceived = fi.Length,
                    TotalSize = 0
                };
            }

            return new ResumableUploadStatusResult
            {
                Exists = false,
                UploadId = uploadId,
                FileName = cleanName
            };
        }

        public int CleanOrphanedParts(TimeSpan? olderThan = null)
        {
            var threshold = olderThan ?? TimeSpan.FromHours(24);
            var cutoff = DateTime.UtcNow - threshold;
            int count = 0;

            // Nas pastas do usuário só removemos .part nossos; .tmp alheio nunca é tocado.
            var roots = new List<(string Path, bool OwnTmp)> { (_inboundRoot, true) };
            if (_destinations != null) roots.AddRange(_destinations.List().Select(d => (d.Path, false)));

            foreach (var (rootPath, ownTmp) in roots)
            {
                try
                {
                    var dir = new DirectoryInfo(rootPath);
                    if (!dir.Exists) continue;

                    foreach (var file in dir.EnumerateFiles())
                    {
                        bool isPart = file.Extension.Equals(".part", StringComparison.OrdinalIgnoreCase);
                        bool isTmp = ownTmp && file.Extension.Equals(".tmp", StringComparison.OrdinalIgnoreCase);
                        if ((isPart || isTmp) && file.LastWriteTimeUtc < cutoff)
                        {
                            TryDeleteFile(file.FullName);
                            count++;
                            _logger.LogInformation("Arquivo de parte órfão expirado removido: {File}", file.Name);
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Erro ao limpar arquivos de partes órfãos");
                }
            }

            return count;
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

    internal class BoundedReadStream : Stream
    {
        private readonly Stream _inner;
        private readonly long _limit;
        private long _readBytes;

        public BoundedReadStream(Stream inner, long limit)
        {
            _inner = inner;
            _limit = limit;
        }

        public override int Read(byte[] buffer, int offset, int count)
        {
            long remaining = _limit - _readBytes;
            if (remaining <= 0) return 0;
            int toRead = (int)Math.Min(count, remaining);
            int read = _inner.Read(buffer, offset, toRead);
            _readBytes += read;
            return read;
        }

        public override async Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken)
        {
            long remaining = _limit - _readBytes;
            if (remaining <= 0) return 0;
            int toRead = (int)Math.Min(count, remaining);
            int read = await _inner.ReadAsync(buffer, offset, toRead, cancellationToken);
            _readBytes += read;
            return read;
        }

        public override bool CanRead => true;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => _limit;
        public override long Position { get => _readBytes; set => throw new NotSupportedException(); }
        public override void Flush() => _inner.Flush();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        protected override void Dispose(bool disposing) { if (disposing) _inner.Dispose(); base.Dispose(disposing); }
    }
}
