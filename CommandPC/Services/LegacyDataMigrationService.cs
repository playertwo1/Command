using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Command.Lib;
using Command.Models;
using Microsoft.Extensions.Logging;

namespace Command.Services
{
    public class LegacyDataMigrationService : ILegacyDataMigrationService
    {
        private const string SecretHeader = "DDSECRET1\n";

        // Chave de leitura do formato legado.
        private static readonly byte[] LegacyEntropy = Encoding.UTF8.GetBytes("DroidDeck.SecretFile.v1");

        // Entropia do Command
        private static readonly byte[] CommandEntropy = Encoding.UTF8.GetBytes("Command.SecretFile.v1");

        private static readonly HashSet<string> KnownSecretFiles = new(StringComparer.OrdinalIgnoreCase)
        {
            "apikey",
            "discord.json",
            "obs.json",
            "tuya.json",
            "homeassistant.json",
            "spotify.json",
            "twitch.json"
        };

        private readonly ILogger<LegacyDataMigrationService> _logger;
        private readonly string _legacyRoaming;
        private readonly string _legacyLocal;
        private readonly string _targetRoaming;
        private readonly string _targetLocal;

        public LegacyDataMigrationService(
            ILogger<LegacyDataMigrationService> logger,
            string? customLegacyRoaming = null,
            string? customLegacyLocal = null,
            string? customTargetRoaming = null,
            string? customTargetLocal = null)
        {
            _logger = logger;

            _legacyRoaming = customLegacyRoaming ?? Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "DroidDeck");

            _legacyLocal = customLegacyLocal ?? Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DroidDeck");

            _targetRoaming = customTargetRoaming ?? AppPaths.RoamingDir;
            _targetLocal = customTargetLocal ?? AppPaths.LocalDir;
        }

        public string LegacyRoamingPath => _legacyRoaming;
        public string LegacyLocalPath => _legacyLocal;
        public string TargetRoamingPath => _targetRoaming;
        public string TargetLocalPath => _targetLocal;

        public MigrationPlan BuildPlan()
        {
            var candidates = new List<LegacyItemCandidate>();

            // 1. Escaneia Roaming legado (perfis e configs)
            if (Directory.Exists(_legacyRoaming))
            {
                ScanDirectoryRecursively(_legacyRoaming, _legacyRoaming, _targetRoaming, candidates, isLocal: false);
            }

            // 2. Escaneia Local legado (segredos, apikey, jobs)
            if (Directory.Exists(_legacyLocal))
            {
                ScanDirectoryRecursively(_legacyLocal, _legacyLocal, _targetLocal, candidates, isLocal: true);
            }

            return new MigrationPlan
            {
                HasLegacyData = candidates.Count > 0,
                LegacyRoamingPath = _legacyRoaming,
                LegacyLocalPath = _legacyLocal,
                TargetRoamingPath = _targetRoaming,
                TargetLocalPath = _targetLocal,
                Candidates = candidates
            };
        }

        private void ScanDirectoryRecursively(
            string currentDir,
            string baseSourceDir,
            string baseTargetDir,
            List<LegacyItemCandidate> candidates,
            bool isLocal)
        {
            var dirInfo = new DirectoryInfo(currentDir);
            if (!dirInfo.Exists) return;

            // Ignora pastas transitórias como transfers e screenshots da migração de perfil
            if (isLocal && (dirInfo.Name.Equals("transfers", StringComparison.OrdinalIgnoreCase) ||
                            dirInfo.Name.Equals("screenshots", StringComparison.OrdinalIgnoreCase)))
            {
                return;
            }

            foreach (var file in dirInfo.EnumerateFiles())
            {
                // Ignora arquivos de log e temporários
                if (file.Extension.Equals(".log", StringComparison.OrdinalIgnoreCase) ||
                    file.Extension.Equals(".tmp", StringComparison.OrdinalIgnoreCase) ||
                    file.Name.StartsWith("."))
                {
                    continue;
                }

                string relativePath = Path.GetRelativePath(baseSourceDir, file.FullName);
                string targetPath = Path.Combine(baseTargetDir, relativePath);

                bool isSecret = isLocal && (KnownSecretFiles.Contains(file.Name) || FileStartsWithSecretHeader(file.FullName));
                var itemType = ClassifyItem(relativePath, isSecret, isLocal);

                candidates.Add(new LegacyItemCandidate
                {
                    SourcePath = file.FullName,
                    RelativePath = relativePath.Replace('\\', '/'),
                    TargetPath = targetPath,
                    ItemType = itemType,
                    IsSecret = isSecret,
                    SizeBytes = file.Length,
                    TargetExists = File.Exists(targetPath)
                });
            }

            foreach (var subDir in dirInfo.EnumerateDirectories())
            {
                ScanDirectoryRecursively(subDir.FullName, baseSourceDir, baseTargetDir, candidates, isLocal);
            }
        }

        private static bool FileStartsWithSecretHeader(string filePath)
        {
            try
            {
                using var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                using var reader = new StreamReader(fs, Encoding.UTF8);
                string? firstLine = reader.ReadLine();
                return firstLine != null && firstLine.Equals("DDSECRET1", StringComparison.Ordinal);
            }
            catch
            {
                return false;
            }
        }

        private static LegacyItemType ClassifyItem(string relativePath, bool isSecret, bool isLocal)
        {
            if (isSecret) return LegacyItemType.Secret;
            string lower = relativePath.ToLowerInvariant();
            if (lower.Contains("profile")) return LegacyItemType.Profile;
            if (lower.EndsWith(".json") || lower.EndsWith(".xml") || lower.EndsWith(".yaml") || lower.EndsWith(".yml"))
                return LegacyItemType.Configuration;
            return LegacyItemType.GeneralData;
        }

        public async Task<MigrationExecutionResult> ExecuteMigrationAsync(
            bool explicitConsent,
            MigrationCollisionPolicy collisionPolicy = MigrationCollisionPolicy.BackupAndOverwrite)
        {
            if (!explicitConsent)
            {
                _logger.LogWarning("Tentativa de migração de dados legados rejeitada por falta de consentimento explícito.");
                return new MigrationExecutionResult
                {
                    Success = false,
                    ConsentProvided = false,
                    ErrorCode = "CONSENT_REQUIRED",
                    ErrorMessage = "A migração de dados legados requer consentimento explícito do usuário antes da execução."
                };
            }

            var plan = BuildPlan();
            if (!plan.HasLegacyData)
            {
                _logger.LogInformation("Nenhum dado legado encontrado para migrar.");
                return new MigrationExecutionResult
                {
                    Success = true,
                    ConsentProvided = true,
                    MigratedCount = 0,
                    SkippedCount = 0,
                    FailedCount = 0
                };
            }

            int migrated = 0;
            int skipped = 0;
            int failed = 0;
            var details = new List<MigratedItemResult>();

            foreach (var item in plan.Candidates)
            {
                var detail = new MigratedItemResult { RelativePath = item.RelativePath };

                try
                {
                    // Tratamento de colisão
                    if (File.Exists(item.TargetPath))
                    {
                        if (collisionPolicy == MigrationCollisionPolicy.Skip)
                        {
                            detail.Success = true;
                            detail.Skipped = true;
                            skipped++;
                            details.Add(detail);
                            continue;
                        }

                        if (collisionPolicy == MigrationCollisionPolicy.BackupAndOverwrite)
                        {
                            string backupPath = $"{item.TargetPath}.bak.{DateTime.UtcNow:yyyyMMddHHmmss}";
                            File.Move(item.TargetPath, backupPath);
                            detail.BackupPath = backupPath;
                            _logger.LogInformation("Backup de colisão criado para {RelativePath}: {BackupPath}", item.RelativePath, backupPath);
                        }
                    }

                    string? targetDir = Path.GetDirectoryName(item.TargetPath);
                    if (!string.IsNullOrEmpty(targetDir) && !Directory.Exists(targetDir))
                    {
                        Directory.CreateDirectory(targetDir);
                    }

                    if (item.IsSecret)
                    {
                        MigrateSecretFile(item.SourcePath, item.TargetPath);
                    }
                    else
                    {
                        await MigrateRegularFileAsync(item.SourcePath, item.TargetPath);
                    }

                    detail.Success = true;
                    migrated++;
                    _logger.LogInformation("Arquivo legado migrado com sucesso: {RelativePath} (Tipo: {ItemType})", item.RelativePath, item.ItemType);
                }
                catch (CryptographicException ex)
                {
                    failed++;
                    detail.Success = false;
                    detail.ErrorCode = "DPAPI_DECRYPT_FAILED";
                    detail.ErrorMessage = "Falha ao decifrar segredo com a chave DPAPI do usuário Windows atual.";
                    _logger.LogError(ex, "Falha de decifração DPAPI ao migrar segredo {RelativePath}", item.RelativePath);
                }
                catch (Exception ex)
                {
                    failed++;
                    detail.Success = false;
                    detail.ErrorCode = "MIGRATION_FAILED";
                    detail.ErrorMessage = $"Falha ao migrar arquivo: {ex.Message}";
                    _logger.LogError(ex, "Erro ao migrar arquivo {RelativePath}", item.RelativePath);
                }

                details.Add(detail);
            }

            bool allSucceeded = failed == 0;
            return new MigrationExecutionResult
            {
                Success = allSucceeded,
                ConsentProvided = true,
                MigratedCount = migrated,
                SkippedCount = skipped,
                FailedCount = failed,
                Details = details,
                ErrorCode = allSucceeded ? string.Empty : "PARTIAL_MIGRATION_FAILURE",
                ErrorMessage = allSucceeded ? string.Empty : $"{failed} arquivo(s) falharam durante a migração de dados legados."
            };
        }

        private static void MigrateSecretFile(string sourcePath, string targetPath)
        {
            string content = File.ReadAllText(sourcePath);
            string plainText;

            if (content.StartsWith("DDSECRET1\n", StringComparison.Ordinal) || content.StartsWith("DDSECRET1\r\n", StringComparison.Ordinal))
            {
                // Decifra usando a entropia legada
                string base64 = content.Substring(content.IndexOf('\n') + 1).Trim();
                byte[] blob = Convert.FromBase64String(base64);
                byte[] decrypted = ProtectedData.Unprotect(blob, LegacyEntropy, DataProtectionScope.CurrentUser);
                plainText = Encoding.UTF8.GetString(decrypted);
            }
            else
            {
                // Texto puro legado
                plainText = content;
            }

            // Cifra com a nova entropia Command
            byte[] newBlob = ProtectedData.Protect(Encoding.UTF8.GetBytes(plainText), CommandEntropy, DataProtectionScope.CurrentUser);
            string wrapped = "DDSECRET1\n" + Convert.ToBase64String(newBlob);

            // Validação em memória antes de persistir
            byte[] testDecrypted = ProtectedData.Unprotect(newBlob, CommandEntropy, DataProtectionScope.CurrentUser);
            string testString = Encoding.UTF8.GetString(testDecrypted);
            if (!string.Equals(plainText, testString, StringComparison.Ordinal))
            {
                throw new InvalidOperationException("Falha na verificação de integridade da nova cifra DPAPI em memória.");
            }

            // Gravação atômica
            string tmp = targetPath + ".tmp";
            try
            {
                File.WriteAllText(tmp, wrapped, Encoding.UTF8);
                File.Move(tmp, targetPath, overwrite: true);
            }
            finally
            {
                if (File.Exists(tmp))
                {
                    try { File.Delete(tmp); } catch { }
                }
            }
        }

        private static async Task MigrateRegularFileAsync(string sourcePath, string targetPath)
        {
            string tmp = targetPath + ".tmp";
            try
            {
                using (var src = new FileStream(sourcePath, FileMode.Open, FileAccess.Read, FileShare.Read))
                using (var dst = new FileStream(tmp, FileMode.Create, FileAccess.Write, FileShare.None))
                {
                    await src.CopyToAsync(dst);
                    await dst.FlushAsync();
                }

                File.Move(tmp, targetPath, overwrite: true);
            }
            finally
            {
                if (File.Exists(tmp))
                {
                    try { File.Delete(tmp); } catch { }
                }
            }
        }
    }
}
