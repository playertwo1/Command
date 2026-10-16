using System.Collections.Generic;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace DroidDeck.Tests
{
    public class ButtonToggleTests
    {
        private static DeckAction Media(string cmd) => new() { Type = "media", Parameters = new() { ["command"] = cmd } };

        [Fact]
        public void Toggle_AlternaEEscolheAAcaoDoEstado()
        {
            var toggles = new ButtonToggleService(NullLogger<ButtonToggleService>.Instance);
            var b = new DeckButton { Id = "t-" + System.Guid.NewGuid(), Toggle = true, Action = Media("play"), ActiveAction = Media("pause") };

            Assert.False(toggles.IsOn(b.Id));
            Assert.Same(b.Action, toggles.Press(b));        // desligado -> liga, roda a acao normal
            Assert.True(toggles.IsOn(b.Id));
            Assert.Same(b.ActiveAction, toggles.Press(b));  // ligado -> desliga, roda a acao do ligado
            Assert.False(toggles.IsOn(b.Id));
        }

        [Fact]
        public void Toggle_SemAcaoDoLigado_RodaSempreAMesma()
        {
            var toggles = new ButtonToggleService(NullLogger<ButtonToggleService>.Instance);
            var b = new DeckButton { Id = "t-" + System.Guid.NewGuid(), Toggle = true, Action = Media("next") };

            Assert.Same(b.Action, toggles.Press(b));
            Assert.Same(b.Action, toggles.Press(b));
        }

        [Fact]
        public void Toggle_SobreviveAReinicio()
        {
            var id = "t-" + System.Guid.NewGuid();
            new ButtonToggleService(NullLogger<ButtonToggleService>.Instance).Set(id, true);
            Assert.True(new ButtonToggleService(NullLogger<ButtonToggleService>.Instance).IsOn(id));
        }

        [Fact]
        public void AcaoDoLigadoPrivilegiada_CriadaDeFora_ERecusada()
        {
            var hotkey = new DeckAction { Type = "hotkey", Parameters = new() { ["keys"] = "^m" } };
            var saved = new DeckProfile { Id = "p", Buttons = { new DeckButton { Id = "b", Action = Media("play") } } };
            var incoming = new DeckProfile { Id = "p", Buttons = { new DeckButton { Id = "b", Action = Media("play"), Toggle = true, ActiveAction = hotkey } } };

            Assert.NotNull(ActionPolicy.FindRemoteViolation(incoming, saved));
        }
    }

    public class InfoButtonTests
    {
        private static DeckButton Info(string type, Dictionary<string, string> p) =>
            new() { Id = "i", DynamicType = type, DynamicParameters = p };

        [Fact]
        public void Comando_CriadoDeFora_ERecusado_MasPodeSerMantido()
        {
            var cmd = Info("command", new() { ["command"] = "echo oi" });
            Assert.NotNull(ActionPolicy.FindRemoteViolation(new DeckProfile { Buttons = { cmd } }, null));

            var saved = new DeckProfile { Id = "p", Buttons = { Info("command", new() { ["command"] = "echo oi" }) } };
            var renamed = Info("command", new() { ["command"] = "echo oi" });
            renamed.Label = "novo nome";
            Assert.Null(ActionPolicy.FindRemoteViolation(new DeckProfile { Id = "p", Buttons = { renamed } }, saved));

            var changed = Info("url", new() { ["url"] = "http://192.168.0.1/admin" });
            Assert.NotNull(ActionPolicy.FindRemoteViolation(new DeckProfile { Id = "p", Buttons = { changed } }, saved));
        }

        [Fact]
        public void ClimaERelogio_PodemSerCriadosDeFora()
        {
            var p = new DeckProfile { Buttons = { Info("weather", new() { ["city"] = "Recife" }), Info("clock", new()) } };
            Assert.Null(ActionPolicy.FindRemoteViolation(p, null));
        }

        [Theory]
        [InlineData("current.temp", "21.5")]
        [InlineData("items[1].name", "b")]
        [InlineData("items.0.name", "a")]
        [InlineData("ok", "sim")]
        [InlineData("title", "Olá")]
        public void JsonPath_LeOCampo(string path, string expected)
        {
            const string json = "{\"current\":{\"temp\":21.5},\"items\":[{\"name\":\"a\"},{\"name\":\"b\"}],\"ok\":true,\"title\":\"Olá\"}";
            Assert.Equal(expected, InfoService.JsonPath(json, path));
        }

        [Fact]
        public void JsonPath_CampoQueNaoExiste_Explica()
        {
            var ex = Assert.Throws<System.InvalidOperationException>(() => InfoService.JsonPath("{\"a\":1}", "b"));
            Assert.Contains("\"b\"", ex.Message);
        }

        [Fact]
        public void Modelo_TrocaOValor()
        {
            Assert.Equal("Dia 42", InfoService.Format(Info("command", new() { ["format"] = "Dia {value}" }), "42").Text);
            Assert.Equal("42", InfoService.Format(Info("command", new()), "42").Text);
        }

        [Fact]
        public void Intervalo_TemLimites()
        {
            Assert.Equal(5, InfoService.Interval(Info("command", new() { ["interval"] = "1" })).TotalSeconds);
            Assert.Equal(60, InfoService.Interval(Info("url", new())).TotalSeconds);
            Assert.Equal(15, InfoService.Interval(Info("weather", new())).TotalMinutes);
        }
    }
}
