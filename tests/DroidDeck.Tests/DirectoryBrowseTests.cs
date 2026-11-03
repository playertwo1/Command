using System;
using System.IO;
using System.Text;
using DroidDeck.Controllers;
using DroidDeck.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace DroidDeck.Tests
{
    public class DirectoryBrowseTests : IDisposable
    {
        private readonly string _testBaseDir;
        private readonly string _inboundDir;
        private readonly string _outboundDir;
        private readonly Mock<IJobHistoryService> _mockJobHistory;
        private readonly TransferService _service;

        public DirectoryBrowseTests()
        {
            _testBaseDir = Path.Combine(Path.GetTempPath(), "DroidDeckTests_Browse_" + Guid.NewGuid().ToString("N"));
            _inboundDir = Path.Combine(_testBaseDir, "inbound");
            _outboundDir = Path.Combine(_testBaseDir, "outbound");

            Directory.CreateDirectory(_inboundDir);
            Directory.CreateDirectory(_outboundDir);

            _mockJobHistory = new Mock<IJobHistoryService>();
            bool isNew = true;
            _mockJobHistory
                .Setup(j => j.GetOrCreateJob(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), out isNew))
                .Returns(new Models.CommandJob { Id = "test-job", Status = "running" });

            _service = new TransferService(
                _mockJobHistory.Object,
                NullLogger<TransferService>.Instance,
                customInboundRoot: _inboundDir,
                customOutboundRoot: _outboundDir);
        }

        public void Dispose()
        {
            try
            {
                if (Directory.Exists(_testBaseDir))
                {
                    Directory.Delete(_testBaseDir, true);
                }
            }
            catch { }
        }

        [Fact]
        public void BrowseDirectory_ListsFoldersAndFiles_InSubPath()
        {
            // Cria estrutura: outbound/docs/2026/nota.pdf
            string subDir = Path.Combine(_outboundDir, "docs", "2026");
            Directory.CreateDirectory(subDir);
            string filePath = Path.Combine(subDir, "nota.pdf");
            File.WriteAllText(filePath, "conteudo de teste do pdf");

            // Navega na raiz de outbound
            var rootResult = _service.BrowseDirectory("outbound", null, "test-device");
            Assert.True(rootResult.Success);
            Assert.Equal("outbound", rootResult.RootId);
            Assert.Empty(rootResult.CurrentPath);
            Assert.Single(rootResult.Items);
            Assert.True(rootResult.Items[0].IsDirectory);
            Assert.Equal("docs", rootResult.Items[0].Name);

            // Navega em docs
            var docsResult = _service.BrowseDirectory("outbound", "docs", "test-device");
            Assert.True(docsResult.Success);
            Assert.Equal("docs", docsResult.CurrentPath);
            Assert.Single(docsResult.Items);
            Assert.True(docsResult.Items[0].IsDirectory);
            Assert.Equal("2026", docsResult.Items[0].Name);

            // Navega em docs/2026
            var deepResult = _service.BrowseDirectory("outbound", "docs/2026", "test-device");
            Assert.True(deepResult.Success);
            Assert.Equal("docs/2026", deepResult.CurrentPath);
            Assert.Single(deepResult.Items);
            Assert.False(deepResult.Items[0].IsDirectory);
            Assert.Equal("nota.pdf", deepResult.Items[0].Name);
            Assert.Equal("docs/2026/nota.pdf", deepResult.Items[0].RelativePath);
            Assert.Equal(".pdf", deepResult.Items[0].Extension);
            Assert.True(deepResult.Items[0].SizeBytes > 0);
        }

        [Theory]
        [InlineData("../")]
        [InlineData("../../windows")]
        [InlineData("docs/../../etc")]
        [InlineData("..\\windows")]
        [InlineData("/root")]
        public void BrowseDirectory_BlocksPathTraversal(string badPath)
        {
            var result = _service.BrowseDirectory("outbound", badPath, "test-device");
            Assert.False(result.Success);
            Assert.Equal("PATH_TRAVERSAL", result.ErrorCode);
        }

        [Theory]
        [InlineData("CON")]
        [InlineData("NUL")]
        [InlineData("sub/COM1")]
        public void BrowseDirectory_BlocksReservedWindowsNames(string reservedPath)
        {
            var result = _service.BrowseDirectory("outbound", reservedPath, "test-device");
            Assert.False(result.Success);
            Assert.Equal("RESERVED_FILENAME", result.ErrorCode);
        }

        [Fact]
        public void BrowseDirectory_ReturnsNotFound_WhenDirectoryMissing()
        {
            var result = _service.BrowseDirectory("outbound", "pasta_inexistente", "test-device");
            Assert.False(result.Success);
            Assert.Equal("DIRECTORY_NOT_FOUND", result.ErrorCode);
        }

        [Fact]
        public void GetFileForDownload_DownloadsNestedFile_Successfully()
        {
            string nestedFolder = Path.Combine(_outboundDir, "relatorios");
            Directory.CreateDirectory(nestedFolder);
            string nestedFile = Path.Combine(nestedFolder, "relatorio.csv");
            File.WriteAllText(nestedFile, "id,nome\n1,command");

            var result = _service.GetFileForDownload("outbound", "relatorios/relatorio.csv", "test-device");
            Assert.True(result.Success);
            Assert.Equal("relatorio.csv", result.FileName);
            Assert.NotNull(result.Stream);
            Assert.NotEmpty(result.Sha256);

            using var reader = new StreamReader(result.Stream!);
            string content = reader.ReadToEnd();
            Assert.Contains("id,nome", content);
        }

        [Fact]
        public void TransfersController_BrowseDirectory_ReturnsOkWithItems()
        {
            string subDir = Path.Combine(_outboundDir, "financas");
            Directory.CreateDirectory(subDir);
            File.WriteAllText(Path.Combine(subDir, "balanco.txt"), "balanco ok");

            var controller = new TransfersController(_service, new DestinationFolderStore(":memory:"));
            controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() };

            var actionResult = controller.BrowseDirectory("outbound", "financas");
            var okResult = Assert.IsType<OkObjectResult>(actionResult);
            Assert.NotNull(okResult.Value);
        }
    }
}
