using System.Text.Json;
using DroidDeck.Hubs;
using DroidDeck.Services;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace DroidDeck.Tests
{
    public class ObsStateTests
    {
        private static JsonElement Ev(string json) => JsonDocument.Parse(json).RootElement;

        [Fact]
        public void PausarERetomar_ContinuaGravando()
        {
            var obs = new ObsService(NullLogger<ObsService>.Instance, new Mock<IHubContext<DeckHub>>().Object);

            obs.ApplyRecordState(Ev("""{"outputActive":true,"outputState":"OBS_WEBSOCKET_OUTPUT_STARTED"}"""));
            Assert.True(obs.Recording);

            // O OBS manda outputActive=false ao pausar, mas a gravacao segue aberta.
            obs.ApplyRecordState(Ev("""{"outputActive":false,"outputState":"OBS_WEBSOCKET_OUTPUT_PAUSED"}"""));
            Assert.True(obs.Recording);
            Assert.True(obs.RecordPaused);

            obs.ApplyRecordState(Ev("""{"outputActive":false,"outputState":"OBS_WEBSOCKET_OUTPUT_RESUMED"}"""));
            Assert.True(obs.Recording);
            Assert.False(obs.RecordPaused);

            obs.ApplyRecordState(Ev("""{"outputActive":false,"outputState":"OBS_WEBSOCKET_OUTPUT_STOPPED"}"""));
            Assert.False(obs.Recording);
            Assert.False(obs.RecordPaused);
        }
    }
}
