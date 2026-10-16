using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using DroidDeck.Actions;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace DroidDeck.Tests
{
    public class ActionExecutorTests
    {
        private class FakeProvider : IActionProvider
        {
            public FakeProvider(string type, params string[] aliases)
            {
                Type = type;
                Aliases = aliases;
            }

            public string Type { get; }
            public IReadOnlyCollection<string> Aliases { get; }
            public List<(DeckAction action, string? buttonId)> Calls { get; } = new();

            public ActionSchema Describe() => new() { Title = Type };

            public async Task ExecuteAsync(ActionContext context)
            {
                Calls.Add((context.Action, context.ButtonId));
                // Uma acao que dispara outra (como a multi) leva junto o botao de origem.
                if (context.Get("chain") is { Length: > 0 } next)
                    await context.ExecuteAsync(new DeckAction { Type = next });
            }
        }

        private static ActionExecutorService Executor(params IActionProvider[] providers) =>
            new(NullLogger<ActionExecutorService>.Instance, providers);

        [Fact]
        public async Task Despacha_PeloTipo_SemDiferenciarMaiusculas_ePorAlias()
        {
            var launch = new FakeProvider("launch_app", "launchapp");
            var executor = Executor(launch);

            await executor.ExecuteActionAsync(new DeckAction { Type = "LAUNCH_APP" });
            await executor.ExecuteActionAsync(new DeckAction { Type = "launchApp" }, "b1");

            Assert.Equal(2, launch.Calls.Count);
            Assert.Equal("b1", launch.Calls[1].buttonId);
        }

        [Fact]
        public async Task TipoDesconhecido_NaoLanca()
        {
            await Executor(new FakeProvider("obs")).ExecuteActionAsync(new DeckAction { Type = "nada" });
        }

        [Fact]
        public async Task AcaoEncadeada_PreservaOBotaoDeOrigem()
        {
            var a = new FakeProvider("a");
            var b = new FakeProvider("b");
            var executor = Executor(a, b);

            await executor.ExecuteActionAsync(
                new DeckAction { Type = "a", Parameters = new() { ["chain"] = "b" } }, "botao");

            Assert.Equal("botao", Assert.Single(b.Calls).buttonId);
        }

        [Fact]
        public void Schema_MarcaTiposPrivilegiados_eUsaOTipoDoProvedor()
        {
            var schema = Executor(new FakeProvider("hotkey"), new FakeProvider("obs")).DescribeAll();

            Assert.True(schema.Single(s => s.Type == "hotkey").Privileged);
            Assert.False(schema.Single(s => s.Type == "obs").Privileged);
        }
    }
}
