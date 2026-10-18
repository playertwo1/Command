using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text.Json;
using DroidDeck.Models;

namespace DroidDeck.Services
{
    public class EncryptedBackupService : IEncryptedBackupService
    {
        private readonly IRoutineService _routineService;
        private readonly ISecurityPolicyService _securityPolicyService;

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNameCaseInsensitive = true
        };

        public EncryptedBackupService(IRoutineService routineService, ISecurityPolicyService securityPolicyService)
        {
            _routineService = routineService ?? throw new ArgumentNullException(nameof(routineService));
            _securityPolicyService = securityPolicyService ?? throw new ArgumentNullException(nameof(securityPolicyService));
        }

        public EncryptedBackupEnvelopeDto ExportEncrypted(string passphrase)
        {
            if (string.IsNullOrEmpty(passphrase) || passphrase.Length < 6)
            {
                throw new ArgumentException("Passphrase must have at least 6 characters.", nameof(passphrase));
            }

            var routines = _routineService.GetCustomRoutines();
            var permissions = _securityPolicyService.GetDevicePermissions();

            var payload = new BackupPayload
            {
                Routines = new List<RoutineDefinitionDto>(routines),
                Permissions = new List<DevicePermissionDto>(permissions),
                ExportedAt = DateTime.UtcNow
            };

            byte[] plaintextBytes = JsonSerializer.SerializeToUtf8Bytes(payload, JsonOptions);
            string plaintextSha256 = Convert.ToHexString(SHA256.HashData(plaintextBytes)).ToLowerInvariant();

            byte[] salt = RandomNumberGenerator.GetBytes(16);
            byte[] nonce = RandomNumberGenerator.GetBytes(12);
            byte[] key = Rfc2898DeriveBytes.Pbkdf2(passphrase, salt, 100_000, HashAlgorithmName.SHA256, 32);

            byte[] ciphertext = new byte[plaintextBytes.Length];
            byte[] tag = new byte[16];

            using (var aesGcm = new AesGcm(key, 16))
            {
                aesGcm.Encrypt(nonce, plaintextBytes, ciphertext, tag);
            }

            return new EncryptedBackupEnvelopeDto(
                FormatVersion: 1,
                App: "Command",
                Version: "1.0.0",
                CreatedAtUtc: DateTime.UtcNow,
                SaltBase64: Convert.ToBase64String(salt),
                NonceBase64: Convert.ToBase64String(nonce),
                TagBase64: Convert.ToBase64String(tag),
                CiphertextBase64: Convert.ToBase64String(ciphertext),
                PlaintextSha256: plaintextSha256
            );
        }

        public EncryptedBackupRestoreResponse RestoreEncrypted(EncryptedBackupEnvelopeDto envelope, string passphrase)
        {
            if (envelope == null ||
                string.IsNullOrEmpty(passphrase) ||
                passphrase.Length < 6 ||
                string.IsNullOrWhiteSpace(envelope.SaltBase64) ||
                string.IsNullOrWhiteSpace(envelope.NonceBase64) ||
                string.IsNullOrWhiteSpace(envelope.TagBase64) ||
                string.IsNullOrWhiteSpace(envelope.CiphertextBase64) ||
                string.IsNullOrWhiteSpace(envelope.PlaintextSha256))
            {
                return new EncryptedBackupRestoreResponse(false, 0, 0, "INVALID_PAYLOAD", "Invalid or missing backup envelope or passphrase.");
            }

            byte[] salt;
            byte[] nonce;
            byte[] tag;
            byte[] ciphertext;

            try
            {
                salt = Convert.FromBase64String(envelope.SaltBase64);
                nonce = Convert.FromBase64String(envelope.NonceBase64);
                tag = Convert.FromBase64String(envelope.TagBase64);
                ciphertext = Convert.FromBase64String(envelope.CiphertextBase64);
            }
            catch (FormatException)
            {
                return new EncryptedBackupRestoreResponse(false, 0, 0, "INVALID_PAYLOAD", "Envelope contains malformed base64 fields.");
            }

            byte[] key = Rfc2898DeriveBytes.Pbkdf2(passphrase, salt, 100_000, HashAlgorithmName.SHA256, 32);
            byte[] plaintext = new byte[ciphertext.Length];

            try
            {
                using var aesGcm = new AesGcm(key, tag.Length);
                aesGcm.Decrypt(nonce, ciphertext, tag, plaintext);
            }
            catch (CryptographicException)
            {
                return new EncryptedBackupRestoreResponse(false, 0, 0, "DECRYPTION_FAILED", "Invalid passphrase or corrupted payload.");
            }
            catch (Exception ex)
            {
                return new EncryptedBackupRestoreResponse(false, 0, 0, "DECRYPTION_FAILED", ex.Message);
            }

            string computedSha256 = Convert.ToHexString(SHA256.HashData(plaintext)).ToLowerInvariant();
            if (!string.Equals(computedSha256, envelope.PlaintextSha256, StringComparison.OrdinalIgnoreCase))
            {
                return new EncryptedBackupRestoreResponse(false, 0, 0, "INTEGRITY_CHECK_FAILED", "Checksum mismatch.");
            }

            BackupPayload? payload;
            try
            {
                payload = JsonSerializer.Deserialize<BackupPayload>(plaintext, JsonOptions);
            }
            catch (Exception ex)
            {
                return new EncryptedBackupRestoreResponse(false, 0, 0, "DESERIALIZATION_FAILED", ex.Message);
            }

            int restoredRoutines = 0;
            if (payload?.Routines != null)
            {
                foreach (var routine in payload.Routines)
                {
                    if (routine != null)
                    {
                        try
                        {
                            _routineService.SaveCustomRoutine(routine);
                            restoredRoutines++;
                        }
                        catch
                        {
                            // Presets ou validação inválida ignorados
                        }
                    }
                }
            }

            int restoredPermissions = 0;
            if (payload?.Permissions != null)
            {
                foreach (var perm in payload.Permissions)
                {
                    if (perm != null && !string.IsNullOrWhiteSpace(perm.DeviceId) && !string.IsNullOrWhiteSpace(perm.Role))
                    {
                        try
                        {
                            _securityPolicyService.SetDeviceRole(perm.DeviceId, perm.Role);
                            restoredPermissions++;
                        }
                        catch
                        {
                            // Ignora papel inválido
                        }
                    }
                }
            }

            return new EncryptedBackupRestoreResponse(true, restoredRoutines, restoredPermissions, null, null);
        }

        private class BackupPayload
        {
            public List<RoutineDefinitionDto>? Routines { get; set; }
            public List<DevicePermissionDto>? Permissions { get; set; }
            public DateTime ExportedAt { get; set; }
        }
    }
}
