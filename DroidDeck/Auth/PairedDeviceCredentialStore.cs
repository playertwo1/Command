using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using DroidDeck.Lib;

namespace DroidDeck.Auth
{
    public sealed class PairedDeviceCredentialStore
    {
        private readonly object _sync = new();
        private readonly string _path;
        private List<DeviceCredentialRecord>? _records;

        public PairedDeviceCredentialStore() : this(Path.Combine(AppPaths.LocalDir, "paired-devices")) { }

        internal PairedDeviceCredentialStore(string path) => _path = path;

        public (string DeviceId, string Credential) Create()
        {
            lock (_sync)
            {
                var records = Load();
                var deviceId = Guid.NewGuid().ToString("D");
                var credential = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
                    .TrimEnd('=').Replace('+', '-').Replace('/', '_');
                records.Add(new DeviceCredentialRecord(deviceId, Hash(credential), "FullControl", DateTimeOffset.UtcNow));
                Save(records);
                return (deviceId, credential);
            }
        }

        public bool TryAuthenticate(string? credential, out DeviceCredentialRecord? device)
        {
            device = null;
            if (string.IsNullOrEmpty(credential) || credential.Length > 128) return false;
            var candidate = SHA256.HashData(Encoding.UTF8.GetBytes(credential));
            lock (_sync)
            {
                foreach (var record in Load())
                {
                    byte[] stored;
                    try { stored = Convert.FromHexString(record.CredentialHash); }
                    catch (FormatException) { continue; }
                    if (stored.Length == candidate.Length && CryptographicOperations.FixedTimeEquals(stored, candidate))
                    {
                        device = record;
                        return true;
                    }
                }
            }
            return false;
        }

        public bool Revoke(string deviceId)
        {
            lock (_sync)
            {
                var records = Load();
                var removed = records.RemoveAll(d => string.Equals(d.DeviceId, deviceId, StringComparison.OrdinalIgnoreCase)) > 0;
                if (removed) Save(records);
                return removed;
            }
        }

        private List<DeviceCredentialRecord> Load()
        {
            if (_records is not null) return _records;
            if (!File.Exists(_path)) return _records = new List<DeviceCredentialRecord>();
            try
            {
                _records = JsonSerializer.Deserialize<List<DeviceCredentialRecord>>(SecretFile.ReadAllText(_path)) ?? new();
            }
            catch
            {
                // Corrupt/unreadable credential storage must not authenticate devices.
                _records = new List<DeviceCredentialRecord>();
            }
            return _records;
        }

        private void Save(List<DeviceCredentialRecord> records)
        {
            SecretFile.WriteAllText(_path, JsonSerializer.Serialize(records));
            _records = records;
        }

        private static string Hash(string credential) => Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(credential))).ToLowerInvariant();
    }

    public sealed record DeviceCredentialRecord(string DeviceId, string CredentialHash, string Role, DateTimeOffset CreatedAtUtc);
}
