using System;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace Command.Tests
{
    public class PingAndLatencyTests : IClassFixture<WebApplicationFactory<Command.Program>>
    {
        private readonly WebApplicationFactory<Command.Program> _factory;

        public PingAndLatencyTests(WebApplicationFactory<Command.Program> factory) => _factory = factory;

        [Fact]
        public async Task GetPing_SemAutenticacao_Retorna200EPropriedadesEsperadas()
        {
            var client = _factory.CreateClient();

            var response = await client.GetAsync("/api/ping");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            var json = await response.Content.ReadFromJsonAsync<JsonNode>();
            Assert.NotNull(json);
            Assert.True(json["ok"]?.GetValue<bool>());
            Assert.Equal(Environment.MachineName, json["hostName"]?.GetValue<string>());
            Assert.Equal("ok", json["status"]?.GetValue<string>());

            var timeStr = json["serverTimeUtc"]?.GetValue<string>();
            Assert.NotNull(timeStr);
            var serverTime = DateTime.Parse(timeStr);
            Assert.True((DateTime.UtcNow - serverTime.ToUniversalTime()).TotalSeconds < 10);
        }

        [Fact]
        public async Task GetPingV1_Alias_Retorna200EPropriedadesEsperadas()
        {
            var client = _factory.CreateClient();

            var response = await client.GetAsync("/api/v1/ping");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);

            var json = await response.Content.ReadFromJsonAsync<JsonNode>();
            Assert.NotNull(json);
            Assert.True(json["ok"]?.GetValue<bool>());
            Assert.Equal(Environment.MachineName, json["hostName"]?.GetValue<string>());
        }
    }
}
