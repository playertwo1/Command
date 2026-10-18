using DroidDeck.Models;

namespace DroidDeck.Services
{
    public interface IEncryptedBackupService
    {
        EncryptedBackupEnvelopeDto ExportEncrypted(string passphrase);
        EncryptedBackupRestoreResponse RestoreEncrypted(EncryptedBackupEnvelopeDto envelope, string passphrase);
    }
}
