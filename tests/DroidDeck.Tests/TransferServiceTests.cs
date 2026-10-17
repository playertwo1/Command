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
    }
}
