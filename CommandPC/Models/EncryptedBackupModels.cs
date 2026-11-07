using System;

namespace Command.Models
{
    public record EncryptedBackupExportRequest(string Passphrase);

    public record EncryptedBackupEnvelopeDto(
        int FormatVersion,
        string App,
        string Version,
        DateTime CreatedAtUtc,
        string SaltBase64,
        string NonceBase64,
        string TagBase64,
        string CiphertextBase64,
        string PlaintextSha256
    );

    public record EncryptedBackupRestoreRequest(string Passphrase, EncryptedBackupEnvelopeDto Envelope);

    public record EncryptedBackupRestoreResponse(
        bool Success,
        int RestoredRoutinesCount,
        int RestoredPermissionsCount,
        string? ErrorCode,
        string? ErrorMessage
    );
}
