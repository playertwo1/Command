using System;
using System.IO;
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

        public TransfersController(ITransferService transferService)
        {
            _transferService = transferService;
        }

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
        public IActionResult DownloadFileByPath([FromRoute] string rootId, [FromQuery] string path)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                return BadRequest(new { code = "EMPTY_PATH", message = "O parâmetro path é obrigatório." });
            }

            return DownloadFile(rootId, path);
        }

        /// <summary>
        /// Baixa um arquivo da raiz de saída com validação de caminho e hash SHA-256 no cabeçalho.
        /// </summary>
        [HttpGet("{rootId}/{fileName}")]
        public IActionResult DownloadFile([FromRoute] string rootId, [FromRoute] string fileName)
        {
            var result = _transferService.GetFileForDownload(rootId, fileName, GetRequestingDeviceId());
            if (!result.Success)
            {
                return result.ErrorCode switch
                {
                    "FILE_NOT_FOUND" => NotFound(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "PATH_TRAVERSAL" or "INVALID_FILENAME" or "INVALID_FILENAME_PATTERN" or "BLOCKED_EXTENSION"
                        => BadRequest(new { code = result.ErrorCode, message = result.ErrorMessage }),
                    "ACCESS_DENIED" => StatusCode(403, new { code = result.ErrorCode, message = result.ErrorMessage }),
                    _ => BadRequest(new { code = result.ErrorCode, message = result.ErrorMessage })
                };
            }

            Response.Headers.Append("X-Checksum-Sha256", result.Sha256);
            Response.Headers.Append("X-File-Size", result.SizeBytes.ToString());

            return File(result.Stream!, result.ContentType, result.FileName);
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
            [FromForm] string? requestId)
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
                requestId);

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
