using System;
using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;

namespace DroidDeck.Auth
{
    public sealed class ControlPairingTicketStore
    {
        private static readonly TimeSpan TicketLifetime = TimeSpan.FromMinutes(2);
        private readonly ConcurrentDictionary<string, DateTimeOffset> _tickets = new(StringComparer.Ordinal);
        private readonly TimeProvider _timeProvider;

        public static ControlPairingTicketStore Shared { get; } = new();

        public ControlPairingTicketStore(TimeProvider? timeProvider = null) =>
            _timeProvider = timeProvider ?? TimeProvider.System;

        public string Issue()
        {
            var ticket = ToBase64Url(RandomNumberGenerator.GetBytes(32));
            var now = _timeProvider.GetUtcNow();
            foreach (var old in _tickets)
                if (old.Value <= now) _tickets.TryRemove(old.Key, out _);
            _tickets[Hash(ticket)] = now.Add(TicketLifetime);
            return ticket;
        }

        public bool TryConsume(string? ticket)
        {
            if (string.IsNullOrEmpty(ticket) || ticket.Length > 128) return false;
            if (!_tickets.TryRemove(Hash(ticket), out var expiresAt)) return false;
            return expiresAt > _timeProvider.GetUtcNow();
        }

        private static string Hash(string value) => Convert.ToHexString(
            SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();

        private static string ToBase64Url(byte[] bytes) => Convert.ToBase64String(bytes)
            .TrimEnd('=').Replace('+', '-').Replace('/', '_');
    }
}
