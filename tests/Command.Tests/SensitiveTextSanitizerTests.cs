using Command.Services;
using Xunit;

namespace Command.Tests
{
    public class SensitiveTextSanitizerTests
    {
        [Fact]
        public void SanitizeText_RedactsWindowsUserPaths()
        {
            string input = @"Arquivo confidencial em C:\Users\notefael\secret.txt e c:\users\admin\config.yaml";
            string result = SensitiveTextSanitizer.SanitizeText(input);

            Assert.Contains(@"C:\Users\[REDACTED]\secret.txt", result);
            Assert.Contains(@"C:\Users\[REDACTED]\config.yaml", result);
            Assert.DoesNotContain("notefael", result);
            Assert.DoesNotContain("admin", result);
        }

        [Fact]
        public void SanitizeText_RedactsPrivateIpv4Addresses()
        {
            string input = "Acessando host em 192.168.1.50, gateway 10.0.0.1 e subnet 172.20.10.5, com DNS 8.8.8.8";
            string result = SensitiveTextSanitizer.SanitizeText(input);

            Assert.Contains("xxx.xxx.*.***", result);
            Assert.DoesNotContain("192.168.1.50", result);
            Assert.DoesNotContain("10.0.0.1", result);
            Assert.DoesNotContain("172.20.10.5", result);
            Assert.Contains("8.8.8.8", result); // IP público deve ser preservado
        }

        [Fact]
        public void SanitizeText_RedactsBearerTokensAndApiKeys()
        {
            string input = "Header: Bearer abcdef123456 | OpenAI: sk-proj1234567890 | Gemini: AIzaSyA1234567890";
            string result = SensitiveTextSanitizer.SanitizeText(input);

            Assert.Contains("[REDACTED_KEY]", result);
            Assert.DoesNotContain("abcdef123456", result);
            Assert.DoesNotContain("sk-proj1234567890", result);
            Assert.DoesNotContain("AIzaSyA1234567890", result);
        }

    }
}
