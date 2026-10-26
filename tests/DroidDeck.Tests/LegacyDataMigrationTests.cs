using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using DroidDeck.Lib;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace DroidDeck.Tests
{
    public class LegacyDataMigrationTests : IDisposable
    {
        private static readonly byte[] LegacyEntropy = Encoding.UTF8.GetBytes("DroidDeck.SecretFile.v1");
        private static readonly byte[] CommandEntropy = Encoding.UTF8.GetBytes("Command.SecretFile.v1");

        private readonly string _testRoot;
        private readonly string _legacyRoaming;
        private readonly string _legacyLocal;
        private readonly string _targetRoaming;
        private readonly string _targetLocal;

        public LegacyDataMigrationTests()
        {
            _testRoot = Path.Combine(Path.GetTempPath(), "cmd-migration-test-" + Guid.NewGuid().ToString("N"));
            _legacyRoaming = Path.Combine(_testRoot, "LegacyRoaming");
            _legacyLocal = Path.Combine(_testRoot, "LegacyLocal");
            _targetRoaming = Path.Combine(_testRoot, "TargetRoaming");
            _targetLocal = Path.Combine(_testRoot, "TargetLocal");

            Directory.CreateDirectory(_testRoot);
        }

        public void Dispose()
        {
            try
            {
                if (Directory.Exists(_testRoot))
                    Directory.Delete(_testRoot, true);
            }
            catch { }
        }

        private LegacyDataMigrationService CreateService()
        {
            return new LegacyDataMigrationService(
                NullLogger<LegacyDataMigrationService>.Instance,
                customLegacyRoaming: _legacyRoaming,
                customLegacyLocal: _legacyLocal,
                customTargetRoaming: _targetRoaming,
                customTargetLocal: _targetLocal);
        }

        [Fact]
        public async Task SemDiretoriosLegados_PlanoRetornaSemDadosEMigracaoVazia()
        {
            var service = CreateService();
            var plan = service.BuildPlan();

            Assert.False(plan.HasLegacyData);
            Assert.Empty(plan.Candidates);

            var result = await service.ExecuteMigrationAsync(explicitConsent: true);
            Assert.True(result.Success);
            Assert.Equal(0, result.MigratedCount);
            Assert.Equal(0, result.SkippedCount);
            Assert.Equal(0, result.FailedCount);
        }

        [Fact]
        public async Task SemConsentimentoExplicito_RejeitaMigracaoComConsentRequired()
        {
            Directory.CreateDirectory(_legacyRoaming);
            File.WriteAllText(Path.Combine(_legacyRoaming, "config.json"), "{}");

            var service = CreateService();
            var result = await service.ExecuteMigrationAsync(explicitConsent: false);

            Assert.False(result.Success);
            Assert.False(result.ConsentProvided);
            Assert.Equal("CONSENT_REQUIRED", result.ErrorCode);
            Assert.Contains("consentimento explícito", result.ErrorMessage);
        }

        [Fact]
        public async Task SegredoLegadoCifradoComEntropiaDroidDeck_MigraParaEntropiaCommandELeComSucesso()
        {
            Directory.CreateDirectory(_legacyLocal);
            string secretKey = "api-secret-key-12345";
            string legacyFile = Path.Combine(_legacyLocal, "apikey");

            // Cria segredo legado no formato upstream (DDSECRET1 + blob com entropia DroidDeck.SecretFile.v1)
            byte[] legacyBlob = ProtectedData.Protect(Encoding.UTF8.GetBytes(secretKey), LegacyEntropy, DataProtectionScope.CurrentUser);
            File.WriteAllText(legacyFile, "DDSECRET1\n" + Convert.ToBase64String(legacyBlob));

            var service = CreateService();
            var plan = service.BuildPlan();

            Assert.True(plan.HasLegacyData);
            Assert.Single(plan.Candidates);
            Assert.True(plan.Candidates[0].IsSecret);

            var result = await service.ExecuteMigrationAsync(explicitConsent: true);
            Assert.True(result.Success);
            Assert.Equal(1, result.MigratedCount);

            string targetFile = Path.Combine(_targetLocal, "apikey");
            Assert.True(File.Exists(targetFile));

            // Verifica que o arquivo no disco está cifrado e não contém a string pura
            string onDisk = File.ReadAllText(targetFile);
            Assert.StartsWith("DDSECRET1\n", onDisk);
            Assert.DoesNotContain(secretKey, onDisk);

            // Verifica que o Command consegue ler com seu leitor padrão SecretFile
            string readByCommand = SecretFile.ReadAllText(targetFile);
            Assert.Equal(secretKey, readByCommand);

            // Verifica preservação estrita do arquivo de origem
            Assert.True(File.Exists(legacyFile));
            Assert.Equal("DDSECRET1\n" + Convert.ToBase64String(legacyBlob), File.ReadAllText(legacyFile));
        }

        [Fact]
        public async Task SegredoLegadoTextoPuro_MigraParaEntropiaCommandELeComSucesso()
        {
            Directory.CreateDirectory(_legacyLocal);
            string secretContent = "{\"ClientSecret\":\"plain-text-discord-secret\"}";
            string legacyFile = Path.Combine(_legacyLocal, "discord.json");
            File.WriteAllText(legacyFile, secretContent);

            var service = CreateService();
            var result = await service.ExecuteMigrationAsync(explicitConsent: true);

            Assert.True(result.Success);
            Assert.Equal(1, result.MigratedCount);

            string targetFile = Path.Combine(_targetLocal, "discord.json");
            Assert.True(File.Exists(targetFile));

            // Deve ter sido cifrado com a entropia do Command
            string readByCommand = SecretFile.ReadAllText(targetFile);
            Assert.Equal(secretContent, readByCommand);

            // Origem em texto puro preservada
            Assert.Equal(secretContent, File.ReadAllText(legacyFile));
        }

        [Fact]
        public async Task ArquivoPerfilComum_CopiaAtomicamenteMantendoConteudoEIntegridade()
        {
            string profileDir = Path.Combine(_legacyRoaming, "Profiles");
            Directory.CreateDirectory(profileDir);
            string profileContent = "{\"Deck\":{\"Name\":\"StreamDeck\",\"Buttons\":[{\"Id\":\"btn1\",\"Row\":0,\"Col\":0}]}}";
            string legacyProfile = Path.Combine(profileDir, "default.json");
            File.WriteAllText(legacyProfile, profileContent);

            var service = CreateService();
            var result = await service.ExecuteMigrationAsync(explicitConsent: true);

            Assert.True(result.Success);
            Assert.Equal(1, result.MigratedCount);

            string targetProfile = Path.Combine(_targetRoaming, "Profiles", "default.json");
            Assert.True(File.Exists(targetProfile));
            Assert.Equal(profileContent, File.ReadAllText(targetProfile));

            // Origem preservada
            Assert.True(File.Exists(legacyProfile));
        }

        [Fact]
        public async Task PoliticaColisao_Skip_NaoSobrescreveDestinoExistente()
        {
            Directory.CreateDirectory(_legacyRoaming);
            Directory.CreateDirectory(_targetRoaming);

            File.WriteAllText(Path.Combine(_legacyRoaming, "settings.json"), "{\"version\":1}");
            File.WriteAllText(Path.Combine(_targetRoaming, "settings.json"), "{\"version\":2}");

            var service = CreateService();
            var result = await service.ExecuteMigrationAsync(
                explicitConsent: true,
                collisionPolicy: MigrationCollisionPolicy.Skip);

            Assert.True(result.Success);
            Assert.Equal(0, result.MigratedCount);
            Assert.Equal(1, result.SkippedCount);

            // Conteúdo alvo mantido sem alteração
            Assert.Equal("{\"version\":2}", File.ReadAllText(Path.Combine(_targetRoaming, "settings.json")));
        }

        [Fact]
        public async Task PoliticaColisao_BackupAndOverwrite_GeraArquivoBakESubstituiDestino()
        {
            Directory.CreateDirectory(_legacyRoaming);
            Directory.CreateDirectory(_targetRoaming);

            string targetFile = Path.Combine(_targetRoaming, "settings.json");
            File.WriteAllText(Path.Combine(_legacyRoaming, "settings.json"), "{\"version\":1}");
            File.WriteAllText(targetFile, "{\"version\":2}");

            var service = CreateService();
            var result = await service.ExecuteMigrationAsync(
                explicitConsent: true,
                collisionPolicy: MigrationCollisionPolicy.BackupAndOverwrite);

            Assert.True(result.Success);
            Assert.Equal(1, result.MigratedCount);
            Assert.Equal(0, result.SkippedCount);

            // Alvo atualizado
            Assert.Equal("{\"version\":1}", File.ReadAllText(targetFile));

            // Backup criado
            var bakFiles = Directory.GetFiles(_targetRoaming, "settings.json.bak.*");
            Assert.Single(bakFiles);
            Assert.Equal("{\"version\":2}", File.ReadAllText(bakFiles[0]));
        }

        [Fact]
        public async Task PoliticaColisao_Overwrite_SobrescreveSemGerarBak()
        {
            Directory.CreateDirectory(_legacyRoaming);
            Directory.CreateDirectory(_targetRoaming);

            string targetFile = Path.Combine(_targetRoaming, "settings.json");
            File.WriteAllText(Path.Combine(_legacyRoaming, "settings.json"), "{\"version\":1}");
            File.WriteAllText(targetFile, "{\"version\":2}");

            var service = CreateService();
            var result = await service.ExecuteMigrationAsync(
                explicitConsent: true,
                collisionPolicy: MigrationCollisionPolicy.Overwrite);

            Assert.True(result.Success);
            Assert.Equal(1, result.MigratedCount);

            Assert.Equal("{\"version\":1}", File.ReadAllText(targetFile));
            var bakFiles = Directory.GetFiles(_targetRoaming, "settings.json.bak.*");
            Assert.Empty(bakFiles);
        }

        [Fact]
        public async Task Idempotencia_ExecutarDuasVezesComSkip_ResultaEmSkippedNaSegunda()
        {
            Directory.CreateDirectory(_legacyRoaming);
            File.WriteAllText(Path.Combine(_legacyRoaming, "deck.json"), "{\"buttons\":[]}");

            var service = CreateService();

            var run1 = await service.ExecuteMigrationAsync(explicitConsent: true, collisionPolicy: MigrationCollisionPolicy.Skip);
            Assert.True(run1.Success);
            Assert.Equal(1, run1.MigratedCount);
            Assert.Equal(0, run1.SkippedCount);

            var run2 = await service.ExecuteMigrationAsync(explicitConsent: true, collisionPolicy: MigrationCollisionPolicy.Skip);
            Assert.True(run2.Success);
            Assert.Equal(0, run2.MigratedCount);
            Assert.Equal(1, run2.SkippedCount);
        }

        [Fact]
        public async Task SegredoCorrompido_FalhaNoSegredoMasNaoImpedeDemaisArquivosENaoVazaSegredo()
        {
            Directory.CreateDirectory(_legacyLocal);
            Directory.CreateDirectory(_legacyRoaming);

            // 1. Arquivo de perfil válido
            File.WriteAllText(Path.Combine(_legacyRoaming, "profile.json"), "{\"valid\":true}");

            // 2. Segredo corrompido (header DDSECRET1 mas payload base64 corrompido)
            File.WriteAllText(Path.Combine(_legacyLocal, "apikey"), "DDSECRET1\nnot-a-valid-base64-or-dpapi-blob!!");

            var service = CreateService();
            var result = await service.ExecuteMigrationAsync(explicitConsent: true);

            // Falha parcial esperada
            Assert.False(result.Success);
            Assert.Equal(1, result.MigratedCount); // perfil válido migrou
            Assert.Equal(1, result.FailedCount);   // segredo corrompido falhou
            Assert.Equal("PARTIAL_MIGRATION_FAILURE", result.ErrorCode);

            // Perfil migrou com sucesso
            Assert.True(File.Exists(Path.Combine(_targetRoaming, "profile.json")));

            // Detalhes da falha não vazam conteúdo sensível
            var failedDetail = Assert.Single(result.Details, d => !d.Success);
            Assert.Equal("apikey", failedDetail.RelativePath);
            Assert.DoesNotContain("not-a-valid-base64", failedDetail.ErrorMessage);
        }

        [Fact]
        public void PastasTransitoriasETemporarias_SaoIgnoradasNoScan()
        {
            Directory.CreateDirectory(Path.Combine(_legacyLocal, "transfers"));
            Directory.CreateDirectory(Path.Combine(_legacyLocal, "screenshots"));
            Directory.CreateDirectory(Path.Combine(_legacyRoaming, "Logs"));

            File.WriteAllText(Path.Combine(_legacyLocal, "transfers", "sample.bin"), "data");
            File.WriteAllText(Path.Combine(_legacyLocal, "screenshots", "shot.png"), "data");
            File.WriteAllText(Path.Combine(_legacyRoaming, "debug.log"), "log-content");
            File.WriteAllText(Path.Combine(_legacyRoaming, "cache.tmp"), "tmp-content");
            File.WriteAllText(Path.Combine(_legacyRoaming, ".hidden"), "hidden");
            File.WriteAllText(Path.Combine(_legacyRoaming, "real-config.json"), "{\"ok\":true}");

            var service = CreateService();
            var plan = service.BuildPlan();

            Assert.True(plan.HasLegacyData);
            Assert.Single(plan.Candidates);
            Assert.Equal("real-config.json", plan.Candidates[0].RelativePath);
        }
    }
}
