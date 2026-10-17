using System.Collections.Generic;
using DroidDeck.Lib.Input;
using Xunit;
using E = DroidDeck.Lib.Input.MacroRecorder.KeyEvent;

namespace DroidDeck.Tests
{
    public class MacroRecorderTests
    {
        // Layout fixo para o teste nao depender do teclado da maquina.
        private static char Layout(ushort vk) => vk switch { 0xBE => '.', 0xBB => '=', 0xDB => '(', _ => '\0' };

        [Theory]
        [InlineData(0x43, KeyModifiers.Ctrl, "^c")]
        [InlineData(0x41, KeyModifiers.Shift, "+a")]
        [InlineData(0x0D, KeyModifiers.None, "{ENTER}")]
        [InlineData(0x73, KeyModifiers.Alt, "%{F4}")]
        [InlineData(0x09, KeyModifiers.Ctrl | KeyModifiers.Shift, "^+{TAB}")]
        [InlineData(0x44, KeyModifiers.Win, "#d")]
        [InlineData(0x35, KeyModifiers.None, "5")]
        [InlineData(0xBE, KeyModifiers.None, ".")]
        [InlineData(0xDB, KeyModifiers.None, "{(}")]
        public void Token_NaSintaxeDoSendKeys(int vk, KeyModifiers mods, string expected) =>
            Assert.Equal(expected, MacroRecorder.Token(new E((ushort)vk, mods, 0), Layout));

        [Fact]
        public void TeclaSemTraducao_EIgnorada() =>
            Assert.Null(MacroRecorder.Token(new E(0xFF, KeyModifiers.None, 0), Layout));

        [Fact]
        public void Pausas_ViramEsperaEntrePassos()
        {
            var events = new List<E>
            {
                new(0x4F, KeyModifiers.None, 0),     // o
                new(0x49, KeyModifiers.None, 120),   // i
                new(0x0D, KeyModifiers.None, 300),   // enter
                new(0x53, KeyModifiers.Ctrl, 1540),  // ^s, 1.24 s depois
            };
            var steps = MacroRecorder.ToSteps(events, Layout);

            Assert.Equal(2, steps.Count);
            Assert.Equal("oi{ENTER}", steps[0].Parameters!["keys"]);
            Assert.Equal(0, steps[0].DelayMs);
            Assert.Equal("^s", steps[1].Parameters!["keys"]);
            Assert.Equal(1200, steps[1].DelayMs);
            Assert.All(steps, s => Assert.Equal("hotkey", s.Type));
        }

        [Fact]
        public void TokensGerados_SaoLidosPeloParser()
        {
            var keys = MacroRecorder.ToSteps(new List<E>
            {
                new(0x43, KeyModifiers.Ctrl, 0), new(0xDB, KeyModifiers.None, 10), new(0x73, KeyModifiers.Alt, 20),
            }, Layout)[0].Parameters!["keys"];
            Assert.Equal(3, KeySequence.Parse(keys).Count);
        }
    }
}
