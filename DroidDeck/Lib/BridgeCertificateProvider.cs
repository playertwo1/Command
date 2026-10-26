using System;
using System.IO;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

namespace DroidDeck.Lib
{
    /// <summary>Stable, DPAPI-protected TLS identity for this Bridge installation.</summary>
    public static class BridgeCertificateProvider
    {
        private static readonly object Sync = new();
        private static X509Certificate2? _certificate;
        private static string FilePath => Path.Combine(AppPaths.LocalDir, "bridge-tls-pfx");

        public const int HttpsPort = 4788;

        public static X509Certificate2 GetCertificate()
        {
            if (_certificate is not null) return _certificate;
            lock (Sync)
            {
                if (_certificate is not null) return _certificate;
                if (File.Exists(FilePath))
                {
                    try
                    {
                        var pfx = Convert.FromBase64String(SecretFile.ReadAllText(FilePath));
                        _certificate = new X509Certificate2(pfx, (string?)null, X509KeyStorageFlags.EphemeralKeySet);
                        if (_certificate.HasPrivateKey && _certificate.NotAfter.ToUniversalTime() > DateTime.UtcNow)
                            return _certificate;
                        _certificate.Dispose();
                        _certificate = null;
                    }
                    catch
                    {
                        _certificate?.Dispose();
                        _certificate = null;
                    }
                }

                using var rsa = RSA.Create(2048);
                var request = new CertificateRequest(
                    $"CN=Command Bridge {Environment.MachineName}", rsa,
                    HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
                request.CertificateExtensions.Add(new X509BasicConstraintsExtension(false, false, 0, true));
                request.CertificateExtensions.Add(new X509KeyUsageExtension(
                    X509KeyUsageFlags.DigitalSignature | X509KeyUsageFlags.KeyEncipherment, true));
                var usages = new OidCollection { new("1.3.6.1.5.5.7.3.1") };
                request.CertificateExtensions.Add(new X509EnhancedKeyUsageExtension(usages, true));

                using var generated = request.CreateSelfSigned(
                    DateTimeOffset.UtcNow.AddMinutes(-5), DateTimeOffset.UtcNow.AddYears(5));
                var protectedPfx = Convert.ToBase64String(generated.Export(X509ContentType.Pfx));
                SecretFile.WriteAllText(FilePath, protectedPfx);
                _certificate = new X509Certificate2(
                    Convert.FromBase64String(protectedPfx), (string?)null, X509KeyStorageFlags.EphemeralKeySet);
                return _certificate;
            }
        }

        public static string GetSha256Pin() => Convert.ToHexString(GetCertificate().GetCertHash(HashAlgorithmName.SHA256)).ToLowerInvariant();
    }
}
