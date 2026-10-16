using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;
using DroidDeck.Models;
using DroidDeck.Services;
using Xunit;

namespace DroidDeck.Tests
{
    public class GestureTests
    {
        private static DeckAction Hotkey => new() { Type = "hotkey", Parameters = new() { ["keys"] = "^c" } };
        private static DeckAction Media => new() { Type = "media", Parameters = new() { ["command"] = "next" } };

        [Fact]
        public void ActionFor_EscolheAAcaoDoGesto()
        {
            var b = new DeckButton { Action = Media, LongPressAction = Hotkey };
            Assert.Same(b.Action, b.ActionFor(null));
            Assert.Same(b.Action, b.ActionFor("tap"));
            Assert.Same(b.LongPressAction, b.ActionFor("longPress"));
            Assert.Null(b.ActionFor("doubleTap"));
        }

        [Fact]
        public void ToqueLongoPrivilegiado_CriadoDeFora_ERecusado()
        {
            var saved = new DeckProfile { Id = "p", Buttons = { new DeckButton { Id = "b", Action = Media } } };
            var incoming = new DeckProfile { Id = "p", Buttons = { new DeckButton { Id = "b", Action = Media, LongPressAction = Hotkey } } };

            Assert.NotNull(ActionPolicy.FindRemoteViolation(incoming, saved));
        }

        [Fact]
        public void ToqueDuploPrivilegiadoJaSalvo_PodeSerMantido()
        {
            var saved = new DeckProfile { Id = "p", Buttons = { new DeckButton { Id = "b", DoubleTapAction = Hotkey } } };
            var incoming = new DeckProfile { Id = "p", Buttons = { new DeckButton { Id = "b", Label = "novo nome", DoubleTapAction = Hotkey } } };

            Assert.Null(ActionPolicy.FindRemoteViolation(incoming, saved));
        }
    }

    public class ForegroundWatcherTests
    {
        private static readonly List<DeckProfile> Profiles = new()
        {
            new DeckProfile { Id = "geral" },
            new DeckProfile { Id = "obs", AutoSwitchApps = new() { "obs64.exe" } },
            new DeckProfile { Id = "code", AutoSwitchApps = new() { "Code", "devenv" } },
        };

        [Theory]
        [InlineData("obs64", "obs")]
        [InlineData("OBS64", "obs")]
        [InlineData("code", "code")]
        [InlineData("devenv.exe", "code")]
        [InlineData("chrome", null)]
        [InlineData(null, null)]
        public void Match_PeloNomeDoProcesso(string? process, string? expected) =>
            Assert.Equal(expected, ForegroundWatcher.Match(Profiles, process));
    }

    public class BackupTests
    {
        [Fact]
        public void LeOQueFoiExportado()
        {
            var profile = new DeckProfile
            {
                Id = "a1",
                Name = "Live",
                AutoSwitchApps = new() { "obs64" },
                Buttons = { new DeckButton { Id = "b1", Label = "Cena", IconBase64 = "AAAA", LongPressAction = new DeckAction { Type = "obs" } } },
            };

            using var ms = new MemoryStream();
            using (var zip = new ZipArchive(ms, ZipArchiveMode.Create, leaveOpen: true))
            {
                Entry(zip, "manifest.json", "{\"format\":1,\"app\":\"DroidDeck\"}");
                Entry(zip, "profiles/a1.json", System.Text.Json.JsonSerializer.Serialize(profile,
                    new System.Text.Json.JsonSerializerOptions { PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase }));
            }
            ms.Position = 0;

            var read = Assert.Single(BackupService.Read(ms));
            Assert.Equal("Live", read.Name);
            Assert.Equal("obs64", Assert.Single(read.AutoSwitchApps!));
            Assert.Equal("AAAA", read.Buttons[0].IconBase64);
            Assert.Equal("obs", read.Buttons[0].LongPressAction!.Type);
        }

        [Fact]
        public void ArquivoQueNaoEBackup_ERecusado()
        {
            using var ms = new MemoryStream(Encoding.UTF8.GetBytes("nao e zip"));
            var ex = Assert.Throws<InvalidDataException>(() => BackupService.Read(ms));
            Assert.Contains("DroidDeck", ex.Message);
        }

        [Fact]
        public void BackupDeVersaoMaisNova_ERecusado()
        {
            using var ms = new MemoryStream();
            using (var zip = new ZipArchive(ms, ZipArchiveMode.Create, leaveOpen: true))
                Entry(zip, "manifest.json", "{\"format\":99,\"app\":\"DroidDeck\"}");
            ms.Position = 0;
            Assert.Throws<InvalidDataException>(() => BackupService.Read(ms));
        }

        [Fact]
        public void PerfilComIdPerigoso_EIgnorado()
        {
            using var ms = new MemoryStream();
            using (var zip = new ZipArchive(ms, ZipArchiveMode.Create, leaveOpen: true))
            {
                Entry(zip, "manifest.json", "{\"format\":1,\"app\":\"DroidDeck\"}");
                Entry(zip, "profiles/x.json", "{\"id\":\"..\\\\..\\\\evil\",\"name\":\"x\"}");
            }
            ms.Position = 0;
            Assert.Empty(BackupService.Read(ms));
        }

        private static void Entry(ZipArchive zip, string name, string content)
        {
            using var w = new StreamWriter(zip.CreateEntry(name).Open());
            w.Write(content);
        }
    }
}
