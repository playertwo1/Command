using System;
using System.Collections.Generic;
using DroidDeck.Controllers;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace DroidDeck.Tests
{
    public class EncryptedBackupTests
    {
        private readonly AppCatalogService _appCatalog;

        public EncryptedBackupTests()
        {
            _appCatalog = new AppCatalogService(NullLogger<AppCatalogService>.Instance);
        }

        [Fact]
        public void ExportEncrypted_ValidPassphrase_ProducesCompleteEnvelope()
        {
            var routineService = new RoutineService(_appCatalog);
            var securityService = new SecurityPolicyService();

            routineService.SaveCustomRoutine(new RoutineDefinitionDto
            {
                Id = "custom_test_routine",
                Name = "Rotina de Teste",
                Description = "Descrição",
                Steps = new List<RoutineStepDto>
                {
                    new() { StepId = "s1", ActionType = "delay", DelayMs = 100 }
                }
            });

            securityService.SetDeviceRole("dev-tablet", "FullControl");

            var backupService = new EncryptedBackupService(routineService, securityService);
            var envelope = backupService.ExportEncrypted("SecureMasterPassword123!");

            Assert.NotNull(envelope);
            Assert.Equal(1, envelope.FormatVersion);
            Assert.Equal("Command", envelope.App);
            Assert.Equal("1.0.0", envelope.Version);
            Assert.False(string.IsNullOrWhiteSpace(envelope.SaltBase64));
            Assert.False(string.IsNullOrWhiteSpace(envelope.NonceBase64));
            Assert.False(string.IsNullOrWhiteSpace(envelope.TagBase64));
            Assert.False(string.IsNullOrWhiteSpace(envelope.CiphertextBase64));
            Assert.False(string.IsNullOrWhiteSpace(envelope.PlaintextSha256));
        }

        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("12345")]
        public void ExportEncrypted_ShortOrNullPassphrase_ThrowsArgumentException(string? invalidPassphrase)
        {
            var routineService = new RoutineService(_appCatalog);
            var securityService = new SecurityPolicyService();
            var backupService = new EncryptedBackupService(routineService, securityService);

            Assert.Throws<ArgumentException>(() => backupService.ExportEncrypted(invalidPassphrase!));
        }

        [Fact]
        public void RestoreEncrypted_ValidPassphrase_RestoresDataFaithfully()
        {
            var srcRoutineService = new RoutineService(_appCatalog);
            var srcSecurityService = new SecurityPolicyService();

            srcRoutineService.SaveCustomRoutine(new RoutineDefinitionDto
            {
                Id = "custom_backup_routine",
                Name = "Rotina Backup",
                Steps = new List<RoutineStepDto>
                {
                    new() { StepId = "s1", ActionType = "delay", DelayMs = 50 }
                }
            });

            srcSecurityService.SetDeviceRole("device-backup", "ViewerOnly");

            var backupServiceSource = new EncryptedBackupService(srcRoutineService, srcSecurityService);
            var envelope = backupServiceSource.ExportEncrypted("MasterKey#2026");

            // Novo ambiente de destino vazio
            var dstRoutineService = new RoutineService(_appCatalog);
            var dstSecurityService = new SecurityPolicyService();
            var backupServiceDest = new EncryptedBackupService(dstRoutineService, dstSecurityService);

            var restoreResult = backupServiceDest.RestoreEncrypted(envelope, "MasterKey#2026");

            Assert.True(restoreResult.Success);
            Assert.Equal(1, restoreResult.RestoredRoutinesCount);
            Assert.Equal(1, restoreResult.RestoredPermissionsCount);
            Assert.Null(restoreResult.ErrorCode);

            var restoredRoutine = dstRoutineService.GetRoutine("custom_backup_routine");
            Assert.NotNull(restoredRoutine);
            Assert.Equal("Rotina Backup", restoredRoutine.Name);

            var perms = dstSecurityService.GetDevicePermissions();
            Assert.Contains(perms, p => p.DeviceId == "device-backup" && p.Role == "ViewerOnly");
        }

        [Fact]
        public void RestoreEncrypted_WrongPassphrase_ReturnsDecryptionFailed()
        {
            var routineService = new RoutineService(_appCatalog);
            var securityService = new SecurityPolicyService();
            var backupService = new EncryptedBackupService(routineService, securityService);

            var envelope = backupService.ExportEncrypted("CorrectPassword123");

            var result = backupService.RestoreEncrypted(envelope, "WrongPassword456");

            Assert.False(result.Success);
            Assert.Equal("DECRYPTION_FAILED", result.ErrorCode);
        }

        [Fact]
        public void RestoreEncrypted_CorruptedCiphertext_ReturnsDecryptionFailed()
        {
            var routineService = new RoutineService(_appCatalog);
            var securityService = new SecurityPolicyService();
            var backupService = new EncryptedBackupService(routineService, securityService);

            var envelope = backupService.ExportEncrypted("CorrectPassword123");
            byte[] cipherBytes = Convert.FromBase64String(envelope.CiphertextBase64);
            cipherBytes[0] ^= 0xFF; // Inverte bits
            var corruptedEnvelope = envelope with { CiphertextBase64 = Convert.ToBase64String(cipherBytes) };

            var result = backupService.RestoreEncrypted(corruptedEnvelope, "CorrectPassword123");

            Assert.False(result.Success);
            Assert.Equal("DECRYPTION_FAILED", result.ErrorCode);
        }

        [Fact]
        public void RestoreEncrypted_TamperedSha256_ReturnsIntegrityCheckFailed()
        {
            var routineService = new RoutineService(_appCatalog);
            var securityService = new SecurityPolicyService();
            var backupService = new EncryptedBackupService(routineService, securityService);

            var envelope = backupService.ExportEncrypted("CorrectPassword123");
            var tamperedEnvelope = envelope with { PlaintextSha256 = "0000000000000000000000000000000000000000000000000000000000000000" };

            var result = backupService.RestoreEncrypted(tamperedEnvelope, "CorrectPassword123");

            Assert.False(result.Success);
            Assert.Equal("INTEGRITY_CHECK_FAILED", result.ErrorCode);
        }

        [Fact]
        public void EncryptedBackupController_ExportAndRestoreEndpoints_WorkCorrectly()
        {
            var routineService = new RoutineService(_appCatalog);
            var securityService = new SecurityPolicyService();
            var backupService = new EncryptedBackupService(routineService, securityService);
            var controller = new EncryptedBackupController(backupService);

            // Export
            var exportRes = controller.Export(new EncryptedBackupExportRequest("StrongPassphrase!"));
            var okExport = Assert.IsType<OkObjectResult>(exportRes.Result);
            var envelope = Assert.IsType<EncryptedBackupEnvelopeDto>(okExport.Value);

            // Restore
            var restoreRes = controller.Restore(new EncryptedBackupRestoreRequest("StrongPassphrase!", envelope));
            var okRestore = Assert.IsType<OkObjectResult>(restoreRes.Result);
            var resp = Assert.IsType<EncryptedBackupRestoreResponse>(okRestore.Value);
            Assert.True(resp.Success);

            // Bad request handling
            var badExport = controller.Export(new EncryptedBackupExportRequest("123"));
            Assert.IsType<BadRequestObjectResult>(badExport.Result);
        }
    }
}
