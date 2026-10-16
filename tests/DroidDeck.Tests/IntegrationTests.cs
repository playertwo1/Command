using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using DroidDeck.Integrations;
using Xunit;

namespace DroidDeck.Tests
{
    public class HomeAssistantParseTests
    {
        [Fact]
        public void Luz_LeEstadoBrilhoECor()
        {
            var node = JsonNode.Parse("""
                {"entity_id":"light.sala","state":"on",
                 "attributes":{"friendly_name":"Sala","brightness":128,"rgb_color":[255,128,0]}}
                """);
            var e = HomeAssistantIntegration.Parse(node)!;
            Assert.Equal("light", e.Domain);
            Assert.Equal("Sala", e.Name);
            Assert.Equal(50, e.Brightness);
            Assert.Equal("#FF8000", e.Color);
        }

        [Fact]
        public void Sensor_LeUnidade()
        {
            var e = HomeAssistantIntegration.Parse(JsonNode.Parse(
                """{"entity_id":"sensor.temp","state":"23.5","attributes":{"unit_of_measurement":"°C"}}"""))!;
            Assert.Equal("23.5", e.State);
            Assert.Equal("°C", e.Unit);
            Assert.Null(e.Brightness);
        }

        [Fact]
        public void SemEntidade_Null() => Assert.Null(HomeAssistantIntegration.Parse(JsonNode.Parse("{}")));

        [Theory]
        [InlineData("scene", "scene")]
        [InlineData("brightness", "light")]
        [InlineData("toggle", "switch")]
        [InlineData("display", "sensor")]
        public void Operacao_FiltraDominios(string op, string domain) =>
            Assert.Contains(domain, HomeAssistantIntegration.DomainsFor(op));
    }

    public class OAuthTests
    {
        [Fact]
        public void Pkce_DesafioEOSha256DoVerificador()
        {
            var (verifier, challenge) = OAuthTokens.NewPkce();
            Assert.InRange(verifier.Length, 43, 128);
            var expected = System.Convert.ToBase64String(SHA256.HashData(Encoding.ASCII.GetBytes(verifier)))
                .TrimEnd('=').Replace('+', '-').Replace('/', '_');
            Assert.Equal(expected, challenge);
            Assert.DoesNotContain("=", challenge);
        }

        [Theory]
        [InlineData("{\"error\":{\"status\":403,\"message\":\"Player command failed: Premium required\"}}", "Player command failed: Premium required")]
        [InlineData("{\"error\":\"Unauthorized\",\"status\":401,\"message\":\"Invalid OAuth token\"}", "Invalid OAuth token")]
        [InlineData("{\"error\":{\"code\":403,\"message\":\"quotaExceeded\"}}", "quotaExceeded")]
        [InlineData("<html>", "HTTP 500")]
        public void ErroDasApis_ViraMensagem(string body, string expected) =>
            Assert.Equal(expected, ApiCall.ErrorText(body, 500));
    }
}
