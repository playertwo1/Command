using System;
using System.IO;
using System.Text.Json;
using Command.Auth;
using Command.Lib;
using Xunit;

namespace Command.Tests
{
    public sealed class ControlPairingSecurityTests
    {
        [Fact]
        public void Ticket_ExpiraEmDoisMinutos()
        {
            var clock = new TestClock(DateTimeOffset.UtcNow);
            var tickets = new ControlPairingTicketStore(clock);
            var ticket = tickets.Issue();

            clock.Advance(TimeSpan.FromMinutes(2));

            Assert.False(tickets.TryConsume(ticket));
            Assert.False(tickets.TryConsume(ticket));
        }

        [Fact]
        public void Ticket_SoPodeSerConsumidoUmaVez()
        {
            var tickets = new ControlPairingTicketStore();
            var ticket = tickets.Issue();

            Assert.True(tickets.TryConsume(ticket));
            Assert.False(tickets.TryConsume(ticket));
            Assert.False(tickets.TryConsume("ticket-desconhecido"));
            Assert.False(tickets.TryConsume(new string('x', 129)));
        }

        [Fact]
        public void Credencial_AutenticaPorHash_eRevogacaoFalhaFechado()
        {
            var path = Path.Combine(Path.GetTempPath(), $"command-devices-{Guid.NewGuid():N}");
            try
            {
                var store = new PairedDeviceCredentialStore(path);
                var issued = store.Create();

                Assert.True(store.TryAuthenticate(issued.Credential, out var device));
                Assert.Equal(issued.DeviceId, device!.DeviceId);
                Assert.Equal("FullControl", device.Role);
                Assert.False(store.TryAuthenticate("unknown", out _));
                Assert.False(store.TryAuthenticate(new string('x', 129), out _));
                Assert.False(File.ReadAllText(path).Contains(issued.Credential, StringComparison.Ordinal));

                Assert.True(store.Revoke(issued.DeviceId));
                Assert.False(store.TryAuthenticate(issued.Credential, out _));
            }
            finally
            {
                if (File.Exists(path)) File.Delete(path);
            }
        }

        [Fact]
        public void PersistenciaProtegidaContemHashEmVezDaCredencial()
        {
            var path = Path.Combine(Path.GetTempPath(), $"command-devices-{Guid.NewGuid():N}");
            try
            {
                var issued = new PairedDeviceCredentialStore(path).Create();
                var wrapped = File.ReadAllText(path);
                Assert.True(SecretFile.TryUnwrap(wrapped, out var plain));
                Assert.DoesNotContain(issued.Credential, plain, StringComparison.Ordinal);
                Assert.Contains(Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
                    System.Text.Encoding.UTF8.GetBytes(issued.Credential))).ToLowerInvariant(), plain);
                Assert.NotNull(JsonSerializer.Deserialize<DeviceCredentialRecord[]>(plain));
            }
            finally
            {
                if (File.Exists(path)) File.Delete(path);
            }
        }

        private sealed class TestClock : TimeProvider
        {
            private DateTimeOffset _now;
            public TestClock(DateTimeOffset now) => _now = now;
            public override DateTimeOffset GetUtcNow() => _now;
            public void Advance(TimeSpan amount) => _now += amount;
        }
    }
}
