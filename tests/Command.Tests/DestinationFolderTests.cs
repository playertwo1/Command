using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;
using Command.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace Command.Tests
{
    public class DestinationFolderTests : IDisposable
    {
        private readonly string _base = Path.Combine(Path.GetTempPath(), "CommandTests_Dest_" + Guid.NewGuid().ToString("N"));
        private readonly string _series;
        private readonly DestinationFolderStore _store = new(":memory:");
        private readonly TransferService _service;
        private readonly DestinationFolder _dest;

        public DestinationFolderTests()
        {
            _series = Path.Combine(_base, "Series");
            Directory.CreateDirectory(_series);
            Directory.CreateDirectory(Path.Combine(_base, "inbound"));
            Directory.CreateDirectory(Path.Combine(_base, "outbound"));
            var jobs = new Mock<IJobHistoryService>();
            bool isNew = true;
            jobs.Setup(j => j.GetOrCreateJob(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), out isNew))
                .Returns(new Models.CommandJob { Id = "j", Status = "running" });
            _service = new TransferService(jobs.Object, NullLogger<TransferService>.Instance,
                Path.Combine(_base, "inbound"), Path.Combine(_base, "outbound"), _store);
            _dest = _store.Add("Séries", "tv", _series);
        }

        public void Dispose() { try { Directory.Delete(_base, true); } catch { } }

        private static MemoryStream Bytes(string s) => new(Encoding.UTF8.GetBytes(s));

        [Fact]
        public async Task Upload_GoesToTheChosenFolder()
        {
            var r = await _service.UploadFileAsync(_dest.Id, "ep1.mkv", Bytes("a"), null, "dev");
            Assert.True(r.Success);
            Assert.True(File.Exists(Path.Combine(_series, "ep1.mkv")));
            Assert.False(File.Exists(Path.Combine(_base, "inbound", "ep1.mkv")));
        }

        [Fact]
        public async Task Upload_UnknownDestination_IsRejected()
        {
            var r = await _service.UploadFileAsync("nao-existe", "x.txt", Bytes("a"), null, "dev");
            Assert.False(r.Success);
            Assert.Equal("INVALID_ROOT", r.ErrorCode);
        }

        [Fact]
        public async Task Upload_FolderRemovedFromStore_IsRejected()
        {
            _store.Remove(_dest.Id);
            var r = await _service.UploadFileAsync(_dest.Id, "x.txt", Bytes("a"), null, "dev");
            Assert.Equal("INVALID_ROOT", r.ErrorCode);
        }

        [Fact]
        public async Task Upload_PathTraversalInFileName_IsRejected()
        {
            var r = await _service.UploadFileAsync(_dest.Id, "../../evil.txt", Bytes("a"), null, "dev");
            Assert.False(r.Success);
            Assert.False(File.Exists(Path.Combine(_base, "evil.txt")));
        }

        [Fact]
        public async Task Upload_Conflict_RejectsKeepsBothOrReplaces()
        {
            File.WriteAllText(Path.Combine(_series, "a.pdf"), "old");

            var none = await _service.UploadFileAsync(_dest.Id, "a.pdf", Bytes("new"), null, "dev");
            Assert.Equal("FILE_ALREADY_EXISTS", none.ErrorCode);

            var both = await _service.UploadFileAsync(_dest.Id, "a.pdf", Bytes("new"), null, "dev", null, "keepBoth");
            Assert.True(both.Success);
            Assert.Equal("a (1).pdf", both.Item!.Name);
            Assert.Equal("old", File.ReadAllText(Path.Combine(_series, "a.pdf")));

            var rep = await _service.UploadFileAsync(_dest.Id, "a.pdf", Bytes("new"), null, "dev", null, "replace");
            Assert.True(rep.Success);
            Assert.Equal("new", File.ReadAllText(Path.Combine(_series, "a.pdf")));
        }

        [Fact]
        public async Task ChunkUpload_GoesToTheChosenFolder()
        {
            var r = await _service.UploadChunkAsync("up1", _dest.Id, "f.pdf", 0, 3, true, Bytes("abc"), null, "dev");
            Assert.True(r.Success && r.IsComplete);
            Assert.True(File.Exists(Path.Combine(_series, "f.pdf")));
        }

        [Fact]
        public void CleanOrphanedParts_OnlyRemovesPartFilesInUserFolders()
        {
            var part = Path.Combine(_series, "x.mkv.up1.part");
            var tmp = Path.Combine(_series, "meu.tmp");
            File.WriteAllText(part, "p"); File.WriteAllText(tmp, "t");
            _service.CleanOrphanedParts(TimeSpan.FromSeconds(-1));
            Assert.False(File.Exists(part));
            Assert.True(File.Exists(tmp));
        }

        [Fact]
        public void Store_RejectsSystemFolders()
        {
            Assert.Throws<ArgumentException>(() => _store.Add("x", "i", Path.GetPathRoot(_base)!));
            Assert.Throws<ArgumentException>(() => _store.Add("x", "i", Environment.GetFolderPath(Environment.SpecialFolder.Windows)));
            Assert.Throws<ArgumentException>(() => _store.Add("x", "i", Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles)));
        }

        [Fact]
        public void Store_Persists_AndNeverNeedsToExposePath()
        {
            var file = Path.Combine(_base, "dest.json");
            var a = new DestinationFolderStore(file);
            var item = a.Add("PDFs", "doc", _series);
            Assert.Equal(item.Id, new DestinationFolderStore(file).List()[0].Id);
        }
    }
}
