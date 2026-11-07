using Command.Lib.Input;
using Xunit;

namespace Command.Tests
{
    public sealed class KeyAllowlistTests
    {
        [Theory]
        [InlineData("Enter", "{ENTER}")]
        [InlineData("Return", "{ENTER}")]
        [InlineData("Esc", "{ESC}")]
        [InlineData("Escape", "{ESC}")]
        [InlineData("Tab", "{TAB}")]
        [InlineData("Backspace", "{BS}")]
        [InlineData("BS", "{BS}")]
        [InlineData("Space", "{SPACE}")]
        [InlineData("Delete", "{DELETE}")]
        [InlineData("Del", "{DELETE}")]
        [InlineData("Insert", "{INSERT}")]
        [InlineData("Home", "{HOME}")]
        [InlineData("End", "{END}")]
        [InlineData("PgUp", "{PGUP}")]
        [InlineData("PgDn", "{PGDN}")]
        [InlineData("Up", "{UP}")]
        [InlineData("Down", "{DOWN}")]
        [InlineData("Left", "{LEFT}")]
        [InlineData("Right", "{RIGHT}")]
        [InlineData("F1", "{F1}")]
        [InlineData("F5", "{F5}")]
        [InlineData("F12", "{F12}")]
        [InlineData("Win", "{WIN}")]
        public void TeclaNomeada_ValidaENormaliza(string input, string expected)
        {
            Assert.True(KeyAllowlist.TryNormalizeAndValidate(input, out var normalized, out var reason));
            Assert.Null(reason);
            Assert.Equal(expected, normalized);

            // Verifica que a sequência normalizada é aceita pelo parser nativo
            var strokes = KeySequence.Parse(normalized);
            Assert.NotEmpty(strokes);
        }

        [Theory]
        [InlineData("Ctrl+C", "^c")]
        [InlineData("ctrl+v", "^v")]
        [InlineData("Ctrl+Shift+Z", "^+z")]
        [InlineData("Alt+Tab", "%{TAB}")]
        [InlineData("Win+D", "#d")]
        [InlineData("Win+E", "#e")]
        [InlineData("Ctrl+Alt+Del", "^%{DELETE}")]
        [InlineData("Ctrl+Shift+Esc", "^+{ESC}")]
        [InlineData("Alt+F4", "%{F4}")]
        public void ModificadoresComTecla_ValidaENormaliza(string input, string expected)
        {
            Assert.True(KeyAllowlist.TryNormalizeAndValidate(input, out var normalized, out var reason));
            Assert.Null(reason);
            Assert.Equal(expected, normalized);

            var strokes = KeySequence.Parse(normalized);
            Assert.NotEmpty(strokes);
        }

        [Theory]
        [InlineData("")]
        [InlineData("   ")]
        [InlineData(null)]
        [InlineData("cmd.exe")]
        [InlineData("powershell -enc aaaa")]
        [InlineData("curl http://evil.com")]
        [InlineData("rmdir /s /q")]
        [InlineData("Enter; calc.exe")]
        [InlineData("Ctrl+C & echo hacked")]
        [InlineData("`rm -rf /`")]
        [InlineData("$env:PATH")]
        [InlineData("Alt+UnknownKey")]
        public void EntradaInvalidaOuMaliciosa_RejeitaSemExcecao(string? input)
        {
            Assert.False(KeyAllowlist.TryNormalizeAndValidate(input, out var normalized, out var reason));
            Assert.True(string.IsNullOrEmpty(normalized));
            Assert.NotNull(reason);
        }
    }
}
