using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace DroidDeck.Controllers
{
    [ApiController]
    [Route("api/transfers")]
    [Route("api/v1/transfers")]
    public class TransfersController : ControllerBase
    {
        private readonly ITransferService _transferService;
        private readonly IDestinationFolderStore _destinations;

        public TransfersController(ITransferService transferService, IDestinationFolderStore destinations)
        {
            _transferService = transferService;
            _destinations = destinations;
        }

        /// <summary>Pastas de destino nomeadas para upload. Expõe só id, nome e ícone — nunca o caminho.</summary>
        [HttpGet("destinations")]
        public IActionResult ListDestinations() =>
            Ok(_destinations.List().Select(d => new { d.Id, d.Name, d.Icon }));

        private string GetRequestingDeviceId()
        {
            if (Request.Headers.TryGetValue("X-Device-Id", out var devId) && !string.IsNullOrWhiteSpace(devId))
            {
                return devId.ToString();
            }

            return "authorized_paired_device";
        }

        /// <summary>
        /// Lista os arquivos autorizados na raiz de saída ('outbound').
        /// </summary>
        [HttpGet("{rootId}")]
        public IActionResult ListFiles([FromRoute] string rootId)
        {
            try
            {
                var files = _transferService.ListFiles(rootId, GetRequestingDeviceId());
                return Ok(files);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { code = "INVALID_ROOT", message = ex.Message });
            }
        }

        /// <summary>
        /// Navega pelos subdiretórios e arquivos dentro das pastas autorizadas ('outbound' ou 'inbound').
        /// Protegido rigorosamente contra path traversal e symlinks.
        /// </summary>
        [HttpGet("{rootId}/browse")]
        public IActionResult BrowseDirectory([FromRoute] string rootId, [FromQuery] string? subPath)
        {
            var result = _transferService.BrowseDirectory(rootId, subPath, GetRequestingDeviceId());
            if (!result.Success)
            {
                return result.ErrorCode switch
                {
                    "DIRECTORY_NOT_FOUND" => NotFound(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "PATH_TRAVERSAL" or "INVALID_PATH_PATTERN" or "RESERVED_FILENAME" or "INVALID_ROOT"
                        => BadRequest(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "ACCESS_DENIED" => StatusCode(403, new { code = result.ErrorCode, message = result.ErrorMessage }),
                    _ => BadRequest(new { code = result.ErrorCode, message = result.ErrorMessage })
                };
            }

            return Ok(new
            {
                rootId = result.RootId,
                currentPath = result.CurrentPath,
                items = result.Items
            });
        }

        /// <summary>
        /// Baixa um arquivo localizado em qualquer subpasta autorizada de 'outbound'.
        /// </summary>
        [HttpGet("{rootId}/download")]
        public IActionResult DownloadFileByPath(
            [FromRoute] string rootId,
            [FromQuery] string path,
            [FromQuery] long? offset = null,
            [FromQuery] long? length = null)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                return BadRequest(new { code = "EMPTY_PATH", message = "O parâmetro path é obrigatório." });
            }

            return DownloadFile(rootId, path, offset, length);
        }

        /// <summary>
        /// Baixa um arquivo da raiz de saída com validação de caminho e hash SHA-256 no cabeçalho.
        /// Suporta fatiamento por bloco com offset e length.
        /// </summary>
        [HttpGet("{rootId}/{fileName}")]
        public IActionResult DownloadFile(
            [FromRoute] string rootId,
            [FromRoute] string fileName,
            [FromQuery] long? offset = null,
            [FromQuery] long? length = null)
        {
            var result = _transferService.GetFileForDownload(rootId, fileName, GetRequestingDeviceId(), offset, length);
            if (!result.Success)
            {
                return result.ErrorCode switch
                {
                    "FILE_NOT_FOUND" => NotFound(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "INVALID_RANGE" => StatusCode(416, new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "PATH_TRAVERSAL" or "INVALID_FILENAME" or "INVALID_FILENAME_PATTERN" or "BLOCKED_EXTENSION"
                        => BadRequest(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "ACCESS_DENIED" => StatusCode(403, new { code = result.ErrorCode, message = result.ErrorMessage }),
                    _ => BadRequest(new { code = result.ErrorCode, message = result.ErrorMessage })
                };
            }

            Response.Headers.Append("Accept-Ranges", "bytes");
            Response.Headers.Append("X-File-Size", result.SizeBytes.ToString());

            if (!string.IsNullOrEmpty(result.Sha256))
            {
                Response.Headers.Append("X-Checksum-Sha256", result.Sha256);
            }

            if (result.IsChunked)
            {
                long end = result.Offset + result.ChunkLength - 1;
                Response.Headers.Append("Content-Range", $"bytes {result.Offset}-{end}/{result.SizeBytes}");
                Response.StatusCode = StatusCodes.Status206PartialContent;
                return File(result.Stream!, result.ContentType, result.FileName);
            }

            return File(result.Stream!, result.ContentType, result.FileName, enableRangeProcessing: true);
        }

        /// <summary>
        /// Envia um bloco de arquivo para upload resumível na raiz 'inbound'.
        /// </summary>
        [HttpPost("upload/chunk")]
        [RequestSizeLimit(10 * 1024 * 1024)] // 10 MB limit per chunk (chunks are 4 MB)
        public async Task<IActionResult> UploadChunk(
            [FromForm] string uploadId,
            [FromForm] string fileName,
            [FromForm] long offset,
            [FromForm] long totalSize,
            [FromForm] bool isLastChunk,
            [FromForm] IFormFile? chunk,
            [FromForm] string? rootId,
            [FromForm] string? expectedSha256,
            [FromForm] string? requestId,
            [FromForm] string? conflictPolicy)
        {
            if (chunk == null || chunk.Length == 0)
            {
                return BadRequest(new { code = "EMPTY_CHUNK", message = "Nenhum dado recebido no bloco." });
            }

            string actualRoot = string.IsNullOrWhiteSpace(rootId) ? "inbound" : rootId;
            using var stream = chunk.OpenReadStream();

            var result = await _transferService.UploadChunkAsync(
                uploadId,
                actualRoot,
                fileName,
                offset,
                totalSize,
                isLastChunk,
                stream,
                expectedSha256,
                GetRequestingDeviceId(),
                requestId,
                conflictPolicy);

            if (!result.Success)
            {
                return result.ErrorCode switch
                {
                    "FILE_ALREADY_EXISTS" => Conflict(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "FILE_TOO_LARGE" => StatusCode(413, new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "CHECKSUM_MISMATCH" => BadRequest(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "CHUNK_OFFSET_GAP" => Conflict(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "PART_NOT_FOUND" => NotFound(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    _ => BadRequest(new { code = result.ErrorCode, message = result.ErrorMessage })
                };
            }

            return Ok(result);
        }

        /// <summary>
        /// Consulta o status e progresso de um upload resumível em andamento.
        /// </summary>
        [HttpGet("upload/status")]
        public IActionResult GetUploadStatus(
            [FromQuery] string uploadId,
            [FromQuery] string fileName,
            [FromQuery] string? rootId = null)
        {
            if (string.IsNullOrWhiteSpace(uploadId) || string.IsNullOrWhiteSpace(fileName))
            {
                return BadRequest(new { code = "INVALID_PARAMETERS", message = "uploadId e fileName são obrigatórios." });
            }

            string actualRoot = string.IsNullOrWhiteSpace(rootId) ? "inbound" : rootId;
            var status = _transferService.GetUploadStatus(uploadId, actualRoot, fileName);
            return Ok(status);
        }

        /// <summary>
        /// Envia um arquivo com validação SHA-256 e gravação temporária atômica para a raiz 'inbound'.
        /// </summary>
        [HttpPost("upload")]
        [RequestSizeLimit(105 * 1024 * 1024)] // 105 MB request limit
        public async Task<IActionResult> UploadFile(
            [FromForm] IFormFile? file,
            [FromForm] string? rootId,
            [FromForm] string? expectedSha256,
            [FromForm] string? requestId,
            [FromForm] string? conflictPolicy)
        {
            if (file == null || file.Length == 0)
            {
                return BadRequest(new { code = "EMPTY_FILE", message = "Nenhum arquivo enviado no formulário." });
            }

            string actualRoot = string.IsNullOrWhiteSpace(rootId) ? "inbound" : rootId;
            string fileName = Path.GetFileName(file.FileName);

            using var stream = file.OpenReadStream();
            var result = await _transferService.UploadFileAsync(
                actualRoot,
                fileName,
                stream,
                expectedSha256,
                GetRequestingDeviceId(),
                requestId,
                conflictPolicy);

            if (!result.Success)
            {
                return result.ErrorCode switch
                {
                    "FILE_ALREADY_EXISTS" => Conflict(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "FILE_TOO_LARGE" => StatusCode(413, new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "CHECKSUM_MISMATCH" => BadRequest(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "PATH_TRAVERSAL" or "BLOCKED_EXTENSION" or "INVALID_FILENAME" or "INVALID_FILENAME_PATTERN" or "RESERVED_FILENAME"
                        => BadRequest(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    _ => StatusCode(500, new { code = result.ErrorCode, message = result.ErrorMessage })
                };
            }

            return Ok(result.Item);
        }
    }
}
