using System;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;

namespace DroidDeck.Controllers
{
    [ApiController]
    [Route("api/backup/encrypted")]
    [Route("api/v1/backup/encrypted")]
    public class EncryptedBackupController : ControllerBase
    {
        private readonly IEncryptedBackupService _backupService;

        public EncryptedBackupController(IEncryptedBackupService backupService)
        {
            _backupService = backupService ?? throw new ArgumentNullException(nameof(backupService));
        }

        [HttpPost("export")]
        public ActionResult<EncryptedBackupEnvelopeDto> Export([FromBody] EncryptedBackupExportRequest request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Passphrase))
            {
                return BadRequest("Passphrase is required.");
            }

            try
            {
                var envelope = _backupService.ExportEncrypted(request.Passphrase);
                return Ok(envelope);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPost("restore")]
        public ActionResult<EncryptedBackupRestoreResponse> Restore([FromBody] EncryptedBackupRestoreRequest request)
        {
            if (request == null || request.Envelope == null)
            {
                return BadRequest("Payload and Envelope are required.");
            }

            var result = _backupService.RestoreEncrypted(request.Envelope, request.Passphrase);
            return Ok(result);
        }
    }
}
