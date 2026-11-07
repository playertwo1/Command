using Command.Models;

namespace Command.Services
{
    public interface IEncryptedBackupService
    {
        EncryptedBackupEnvelopeDto ExportEncrypted(string passphrase);
        EncryptedBackupRestoreResponse RestoreEncrypted(EncryptedBackupEnvelopeDto envelope, string passphrase);
    }
}
