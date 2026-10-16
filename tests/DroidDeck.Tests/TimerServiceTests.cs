using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Actions.Providers;
using DroidDeck.Hubs;
using DroidDeck.Services;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace DroidDeck.Tests
{
    public class TimerServiceTests
    {
        private DateTime _now = new(2026, 10, 15, 12, 0, 0, DateTimeKind.Utc);
        private readonly List<string> _finished = new();

        private TimerService Service()
        {
            var clients = new Mock<IHubClients>();
            clients.Setup(c => c.All).Returns(Mock.Of<IClientProxy>());
            var hub = new Mock<IHubContext<DeckHub>>();
            hub.Setup(h => h.Clients).Returns(clients.Object);

            return new TimerService(NullLogger<TimerService>.Instance, hub.Object)
            {
                Now = () => _now,
                OnFinished = t => _finished.Add(t.Id),
            };
        }

        private static Dictionary<string, string> P(params (string k, string v)[] ps) =>
            ps.ToDictionary(p => p.k, p => p.v);

        private static long Field(TimerService s, string id, string name)
        {
            var entry = s.GetStatePayload()[id];
            return Convert.ToInt64(entry.GetType().GetProperty(name)!.GetValue(entry));
        }

        private static bool Flag(TimerService s, string id, string name) =>
            (bool)s.GetStatePayload()[id].GetType().GetProperty(name)!.GetValue(s.GetStatePayload()[id])!;

        [Fact]
        public void Countdown_TerminaNaHora_eAvisa()
        {
            var s = Service();
            var p = P(("mode", "countdown"), ("durationSec", "60"));

            s.Apply("t", "toggle", p);
            _now += TimeSpan.FromSeconds(59);
            Assert.False(s.Tick());

            _now += TimeSpan.FromSeconds(2);
            Assert.True(s.Tick());
            Assert.True(Flag(s, "t", "finished"));
            Assert.False(Flag(s, "t", "running"));
            Assert.Equal(new[] { "t" }, _finished);
        }

        [Fact]
        public void Pausar_CongelaOTempo()
        {
            var s = Service();
            var p = P(("mode", "stopwatch"));

            s.Apply("c", "toggle", p);
            _now += TimeSpan.FromSeconds(10);
            s.Apply("c", "toggle", p); // pausa
            _now += TimeSpan.FromMinutes(5);

            Assert.Equal(10_000, Field(s, "c", "elapsedMs"));
        }

        [Fact]
        public void ToqueDepoisDeTerminar_Zera()
        {
            var s = Service();
            var p = P(("mode", "countdown"), ("durationSec", "1"));
            s.Apply("t", "toggle", p);
            _now += TimeSpan.FromSeconds(2);
            s.Tick();

            s.Apply("t", "toggle", p);

            Assert.False(Flag(s, "t", "finished"));
            Assert.Equal(0, Field(s, "t", "elapsedMs"));
        }

        [Fact]
        public void Pomodoro_PassaParaAPausa_SemAcumularAtraso()
        {
            var s = Service();
            var p = P(("mode", "pomodoro"), ("workSec", "1500"), ("breakSec", "300"));
            s.Apply("p", "toggle", p);

            // O laco percebe o fim 1s atrasado: a pausa conta a partir do fim real.
            _now += TimeSpan.FromSeconds(1501);
            Assert.True(s.Tick());

            Assert.True(Flag(s, "p", "running"));
            Assert.Equal(1, Field(s, "p", "cycles"));
            Assert.Equal(300_000, Field(s, "p", "durationMs"));
            Assert.Equal(1_000, Field(s, "p", "elapsedMs"));
        }

        [Fact]
        public void Contador_SomaSubtraiEZera()
        {
            var s = Service();
            var p = P(("mode", "counter"));

            s.Apply("n", "toggle", p);
            s.Apply("n", "increment", P(("mode", "counter"), ("step", "5")));
            s.Apply("n", "decrement", p);
            Assert.Equal(5, Field(s, "n", "count"));

            s.Apply("n", "reset", p);
            Assert.Equal(0, Field(s, "n", "count"));
        }

        [Fact]
        public void TrocarOModoDoBotao_ComecaDoZero()
        {
            var s = Service();
            s.Apply("x", "toggle", P(("mode", "stopwatch")));
            _now += TimeSpan.FromSeconds(30);

            s.Apply("x", "toggle", P(("mode", "countdown"), ("durationSec", "60")));

            Assert.Equal(0, Field(s, "x", "elapsedMs"));
            Assert.True(Flag(s, "x", "running"));
        }
    }

    public class HttpProviderTests
    {
        [Fact]
        public void Requisicao_LevaCorpoECabecalhos()
        {
            using var req = HttpProvider.BuildRequest(HttpMethod.Post, new Uri("https://exemplo.com/hook"),
                "Authorization: Bearer abc\nX-Origem: deck\nlinha invalida\nContent-Type: application/vnd.teste",
                "{\"a\":1}", "application/json");

            Assert.Equal("Bearer abc", req.Headers.Authorization!.ToString());
            Assert.Equal("deck", req.Headers.GetValues("X-Origem").Single());
            Assert.Equal("application/vnd.teste", req.Content!.Headers.ContentType!.MediaType);
            Assert.Equal("{\"a\":1}", req.Content.ReadAsStringAsync().Result);
        }

        [Fact]
        public void Get_NaoTemCorpo()
        {
            using var req = HttpProvider.BuildRequest(HttpMethod.Get, new Uri("https://exemplo.com"), "", "ignorado", "text/plain");
            Assert.Null(req.Content);
        }
    }
}
