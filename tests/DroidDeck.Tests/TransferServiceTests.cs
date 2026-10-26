using System;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using DroidDeck.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace DroidDeck.Tests
{
    public class TransferServiceTests : IDisposable
    {
        private readonly string _testBaseDir;
        private readonly string _testInbound;
        private readonly string _testOutbound;
        private readonly JobHistoryService _jobHistoryService;
        private readonly TransferService _service;

        public TransferServiceTests()
        {
            _testBaseDir = Path.Combine(Path.GetTempPath(), "DroidDeckTests_" + Guid.NewGuid().ToString("N"));
            _testInbound = Path.Combine(_testBaseDir, "inbound");
            _testOutbound = Path.Combine(_testBaseDir, "outbound");

            Directory.CreateDirectory(_testInbound);
            Directory.CreateDirectory(_testOutbound);

            _jobHistoryService = new JobHistoryService(NullLogger<JobHistoryService>.Instance, Path.Combine(_testBaseDir, "jobs.json"));
            _service = new TransferService(_jobHistoryService, NullLogger<TransferService>.Instance, _testInbound, _testOutbound);
        }

        public void Dispose()
        {
            try
            {
                if (Directory.Exists(_testBaseDir))
                {
                    Directory.Delete(_testBaseDir, recursive: true);
                }
            }
            catch { }
        }

        private static string CalcSha256(byte[] data)
        {
            using var sha = SHA256.Create();
            return BitConverter.ToString(sha.ComputeHash(data)).Replace("-", "").ToLowerInvariant();
        }

        [Fact]
        public async Task Upload_Sucesso_GravaArquivoEValidaSha256()
        {
            byte[] content = Encoding.UTF8.GetBytes("Conteúdo confidencial e seguro de teste Command.");
            string sha256 = CalcSha256(content);

            using var ms = new MemoryStream(content);
            var result = await _service.UploadFileAsync("inbound", "relatorio.txt", ms, sha256, "pixel9", "req-01");

            Assert.True(result.Success);
            Assert.Equal("relatorio.txt", result.Item!.Name);
            Assert.Equal(content.Length, result.Item.SizeBytes);
            Assert.Equal(sha256, result.Item.Sha256);

            string targetFile = Path.Combine(_testInbound, "relatorio.txt");
            Assert.True(File.Exists(targetFile));
            Assert.Equal(content, File.ReadAllBytes(targetFile));

            // Job registrado no histórico
            var jobs = _jobHistoryService.GetJobs("pixel9");
            Assert.Contains(jobs, j => j.TargetId == "relatorio.txt" && j.Status == "succeeded");
        }

        [Fact]
        public async Task Upload_ChecksumInvalido_RejeitaEApagaTemporario()
        {
            byte[] content = Encoding.UTF8.GetBytes("Arquivo com checksum forjado.");
            string wrongSha = "0000000000000000000000000000000000000000000000000000000000000000";

            using var ms = new MemoryStream(content);
            var result = await _service.UploadFileAsync("inbound", "documento.pdf", ms, wrongSha, "pixel9");

            Assert.False(result.Success);
            Assert.Equal("CHECKSUM_MISMATCH", result.ErrorCode);

            // Verifica que arquivo final e temporários não existem
            Assert.False(File.Exists(Path.Combine(_testInbound, "documento.pdf")));
            Assert.Empty(Directory.GetFiles(_testInbound, "*.tmp"));
        }

        [Fact]
        public async Task Upload_ColisaoDeNome_RejeitaSemSobrescrever()
        {
            string targetFile = Path.Combine(_testInbound, "existente.txt");
            File.WriteAllText(targetFile, "versao original");

            byte[] newContent = Encoding.UTF8.GetBytes("tentativa de sobrescrita");
            using var ms = new MemoryStream(newContent);
            var result = await _service.UploadFileAsync("inbound", "existente.txt", ms, null, "pixel9");

            Assert.False(result.Success);
            Assert.Equal("FILE_ALREADY_EXISTS", result.ErrorCode);
            Assert.Equal("versao original", File.ReadAllText(targetFile));
        }

        [Theory]
        [InlineData("virus.exe")]
        [InlineData("script.bat")]
        [InlineData("powershell.ps1")]
        [InlineData("shell.sh")]
        [InlineData("trojan.dll")]
        public async Task Upload_ExtensaoBloqueada_Rejeita(string fileName)
        {
            byte[] content = Encoding.UTF8.GetBytes("binario perigoso");
            using var ms = new MemoryStream(content);
            var result = await _service.UploadFileAsync("inbound", fileName, ms, null, "pixel9");

            Assert.False(result.Success);
            Assert.Equal("BLOCKED_EXTENSION", result.ErrorCode);
            Assert.False(File.Exists(Path.Combine(_testInbound, fileName)));
        }

        [Theory]
        [InlineData("../perigo.txt")]
        [InlineData("pasta/perigo.txt")]
        [InlineData("..\\perigo.txt")]
        [InlineData("C:\\Windows\\system.ini")]
        [InlineData("perigo.txt:stream")]
        public async Task Upload_PathTraversal_Rejeita(string fileName)
        {
            byte[] content = Encoding.UTF8.GetBytes("traversal attempt");
            using var ms = new MemoryStream(content);
            var result = await _service.UploadFileAsync("inbound", fileName, ms, null, "pixel9");

            Assert.False(result.Success);
            Assert.True(result.ErrorCode == "PATH_TRAVERSAL" || result.ErrorCode == "INVALID_FILENAME_PATTERN");
        }

        [Theory]
        [InlineData("CON.txt")]
        [InlineData("NUL.pdf")]
        [InlineData("PRN.csv")]
        [InlineData("COM1.log")]
        public async Task Upload_DispositivoReservadoWindows_Rejeita(string fileName)
        {
            byte[] content = Encoding.UTF8.GetBytes("reserved device");
            using var ms = new MemoryStream(content);
            var result = await _service.UploadFileAsync("inbound", fileName, ms, null, "pixel9");

            Assert.False(result.Success);
            Assert.Equal("RESERVED_FILENAME", result.ErrorCode);
        }

        [Fact]
        public void ListFiles_SomenteOutbound_DevolveItens()
        {
            File.WriteAllText(Path.Combine(_testOutbound, "dados.csv"), "id,nome\n1,Alpha");
            File.WriteAllText(Path.Combine(_testOutbound, "imagem.png"), "fake png bytes");
            File.WriteAllText(Path.Combine(_testOutbound, "lixo.tmp"), "ignorar");

            var items = _service.ListFiles("outbound", "pixel9").ToList();
            Assert.Equal(2, items.Count);
            Assert.Contains(items, i => i.Name == "dados.csv");
            Assert.Contains(items, i => i.Name == "imagem.png");
            Assert.DoesNotContain(items, i => i.Name.EndsWith(".tmp"));

            Assert.Throws<InvalidOperationException>(() => _service.ListFiles("inbound", "pixel9"));
        }

        [Fact]
        public void Download_Sucesso_DevolveStreamEHeaders()
        {
            byte[] content = Encoding.UTF8.GetBytes("Arquivo pronto para exportacao ao Android.");
            string targetFile = Path.Combine(_testOutbound, "export.json");
            File.WriteAllBytes(targetFile, content);

            var result = _service.GetFileForDownload("outbound", "export.json", "pixel9");
            Assert.True(result.Success);
            Assert.Equal("export.json", result.FileName);
            Assert.Equal("application/json", result.ContentType);
            Assert.Equal(content.Length, result.SizeBytes);
            Assert.Equal(CalcSha256(content), result.Sha256);

            using var ms = new MemoryStream();
            result.Stream!.CopyTo(ms);
            Assert.Equal(content, ms.ToArray());
            result.Stream.Dispose();

            // Job registrado
            var jobs = _jobHistoryService.GetJobs("pixel9");
            Assert.Contains(jobs, j => j.TargetId == "export.json" && j.ActionType == "transfer.download");
        }

        [Fact]
        public void Download_ArquivoNaoExiste_RetornaNotFound()
        {
            var result = _service.GetFileForDownload("outbound", "inexistente.txt", "pixel9");
            Assert.False(result.Success);
            Assert.Equal("FILE_NOT_FOUND", result.ErrorCode);
        }

        [Fact]
        public void Download_PathTraversal_Rejeita()
        {
            var result = _service.GetFileForDownload("outbound", "../fora.txt", "pixel9");
            Assert.False(result.Success);
            Assert.Equal("PATH_TRAVERSAL", result.ErrorCode);
        }

        [Fact]
        public async Task UploadChunk_MultiplosBlocos_SucessoEStatus()
        {
            byte[] chunk1 = Encoding.UTF8.GetBytes("Parte 01 de dados - ");
            byte[] chunk2 = Encoding.UTF8.GetBytes("Parte 02 de dados intermediaria - ");
            byte[] chunk3 = Encoding.UTF8.GetBytes("Parte 03 final!");

            byte[] fullContent = chunk1.Concat(chunk2).Concat(chunk3).ToArray();
            string expectedSha = CalcSha256(fullContent);
            string uploadId = "upl-test-123";
            string fileName = "backup.zip";
            long totalSize = fullContent.Length;

            // Bloco 1
            using (var ms1 = new MemoryStream(chunk1))
            {
                var res1 = await _service.UploadChunkAsync(uploadId, "inbound", fileName, 0, totalSize, false, ms1, null, "pixel9");
                Assert.True(res1.Success);
                Assert.False(res1.IsComplete);
                Assert.Equal(chunk1.Length, res1.BytesReceived);
            }

            // Checagem de status intermediário
            var status = _service.GetUploadStatus(uploadId, "inbound", fileName);
            Assert.True(status.Exists);
            Assert.False(status.IsComplete);
            Assert.Equal(chunk1.Length, status.BytesReceived);

            // Bloco 2
            using (var ms2 = new MemoryStream(chunk2))
            {
                var res2 = await _service.UploadChunkAsync(uploadId, "inbound", fileName, chunk1.Length, totalSize, false, ms2, null, "pixel9");
                Assert.True(res2.Success);
                Assert.False(res2.IsComplete);
                Assert.Equal(chunk1.Length + chunk2.Length, res2.BytesReceived);
            }

            // Bloco 3 (Final)
            using (var ms3 = new MemoryStream(chunk3))
            {
                var res3 = await _service.UploadChunkAsync(uploadId, "inbound", fileName, chunk1.Length + chunk2.Length, totalSize, true, ms3, expectedSha, "pixel9");
                Assert.True(res3.Success);
                Assert.True(res3.IsComplete);
                Assert.Equal(totalSize, res3.BytesReceived);
                Assert.Equal(expectedSha, res3.Item!.Sha256);
            }

            // Arquivo final promovido em inbound e sem .part
            string targetPath = Path.Combine(_testInbound, fileName);
            Assert.True(File.Exists(targetPath));
            Assert.Equal(fullContent, File.ReadAllBytes(targetPath));
            Assert.Empty(Directory.GetFiles(_testInbound, "*.part"));

            // Status após conclusão
            var finalStatus = _service.GetUploadStatus(uploadId, "inbound", fileName);
            Assert.True(finalStatus.Exists);
            Assert.True(finalStatus.IsComplete);
        }

        [Fact]
        public async Task UploadChunk_GapDeOffset_Rejeita()
        {
            byte[] chunk = Encoding.UTF8.GetBytes("dados com pulo");
            using var ms = new MemoryStream(chunk);

            // Tenta enviar com offset 500 sem arquivo existente
            var res = await _service.UploadChunkAsync("upl-gap-1", "inbound", "dados.bin", 500, 1000, false, ms, null, "pixel9");
            Assert.False(res.Success);
            Assert.Equal("PART_NOT_FOUND", res.ErrorCode);

            // Agora cria parte inicial de 10 bytes
            byte[] init = Encoding.UTF8.GetBytes("0123456789");
            using var msInit = new MemoryStream(init);
            await _service.UploadChunkAsync("upl-gap-2", "inbound", "dados.bin", 0, 1000, false, msInit, null, "pixel9");

            // Tenta pular para offset 50 (gap)
            using var msGap = new MemoryStream(chunk);
            var resGap = await _service.UploadChunkAsync("upl-gap-2", "inbound", "dados.bin", 50, 1000, false, msGap, null, "pixel9");
            Assert.False(resGap.Success);
            Assert.Equal("CHUNK_OFFSET_GAP", resGap.ErrorCode);
            Assert.Equal("CHUNK_OFFSET_GAP", resGap.ErrorCode);
        }

        [Fact]
        public async Task UploadChunk_ChecksumInvalidoNoBlocoFinal_RejeitaELimpaPart()
        {
            byte[] data = Encoding.UTF8.GetBytes("conteudo corrompido");
            string wrongSha = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";

            using var ms = new MemoryStream(data);
            var res = await _service.UploadChunkAsync("upl-corrupt", "inbound", "corrupt.txt", 0, data.Length, true, ms, wrongSha, "pixel9");

            Assert.False(res.Success);
            Assert.Equal("CHECKSUM_MISMATCH", res.ErrorCode);
            Assert.False(File.Exists(Path.Combine(_testInbound, "corrupt.txt")));
            Assert.Empty(Directory.GetFiles(_testInbound, "*.part"));
        }

        [Fact]
        public void CleanOrphanedParts_RemoveArquivosExpirados()
        {
            string oldPart = Path.Combine(_testInbound, "velho.txt.upl-old.part");
            string oldTmp = Path.Combine(_testInbound, "velho.tmp");
            string freshPart = Path.Combine(_testInbound, "novo.txt.upl-new.part");

            File.WriteAllText(oldPart, "parte velha");
            File.WriteAllText(oldTmp, "tmp velho");
            File.WriteAllText(freshPart, "parte nova");

            // Define data antiga para os arquivos velhos (3 dias atrás)
            var oldDate = DateTime.UtcNow.AddDays(-3);
            File.SetLastWriteTimeUtc(oldPart, oldDate);
            File.SetLastWriteTimeUtc(oldTmp, oldDate);

            int cleaned = _service.CleanOrphanedParts(TimeSpan.FromHours(24));
            Assert.Equal(2, cleaned);
            Assert.False(File.Exists(oldPart));
            Assert.False(File.Exists(oldTmp));
            Assert.True(File.Exists(freshPart));
        }

        [Fact]
        public void Download_Fatiado_DevolveTrechoCorreto()
        {
            byte[] content = Encoding.UTF8.GetBytes("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ");
            string targetFile = Path.Combine(_testOutbound, "fatiado.txt");
            File.WriteAllBytes(targetFile, content);

            // Offset 10, length 15 -> "ABCDEFGHIJKLMNOP" (15 bytes)
            var res = _service.GetFileForDownload("outbound", "fatiado.txt", "pixel9", offset: 10, length: 15);
            Assert.True(res.Success);
            Assert.True(res.IsChunked);
            Assert.Equal(10, res.Offset);
            Assert.Equal(15, res.ChunkLength);
            Assert.Equal(content.Length, res.SizeBytes);

            using var ms = new MemoryStream();
            res.Stream!.CopyTo(ms);
            byte[] readBytes = ms.ToArray();
            Assert.Equal(15, readBytes.Length);

            string expectedSubstr = "ABCDEFGHIJKLMNO";
            Assert.Equal(expectedSubstr, Encoding.UTF8.GetString(readBytes));
            res.Stream.Dispose();
        }

        [Fact]
        public void Download_OffsetInvalido_RetornaErro()
        {
            byte[] content = Encoding.UTF8.GetBytes("dados");
            string targetFile = Path.Combine(_testOutbound, "range_test.txt");
            File.WriteAllBytes(targetFile, content);

            var res = _service.GetFileForDownload("outbound", "range_test.txt", "pixel9", offset: 100, length: 10);
            Assert.False(res.Success);
            Assert.Equal("INVALID_RANGE", res.ErrorCode);
        }
    }
}
