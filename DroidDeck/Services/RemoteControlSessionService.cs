using System;
using System.Threading;

namespace DroidDeck.Services
{
    public class RemoteControlSessionService : IRemoteControlSessionService
    {
        private static RemoteControlSessionService? _shared;
        public static RemoteControlSessionService Shared => _shared ??= new RemoteControlSessionService(
            new WindowsDesktopCaptureProvider(),
            new SecurityPolicyService());

        private readonly IDesktopCaptureProvider _desktopCapture;
        private readonly ISecurityPolicyService _securityPolicy;
        private readonly TimeProvider _timeProvider;
        private readonly TimeSpan _inactivityTimeout;
        private readonly object _lock = new();

        private RemoteControlSession? _activeSession;
        public event Action<RemoteControlSession?>? SessionChanged;

        // Rate limiter simples por segundo
        private long _currentSecondWindow;
        private int _eventsInCurrentSecond;
        private const int MaxEventsPerSecond = 120;

        public RemoteControlSessionService(
            IDesktopCaptureProvider desktopCapture,
            ISecurityPolicyService securityPolicy,
            TimeProvider? timeProvider = null,
            TimeSpan? inactivityTimeout = null)
        {
            _desktopCapture = desktopCapture ?? throw new ArgumentNullException(nameof(desktopCapture));
            _securityPolicy = securityPolicy ?? throw new ArgumentNullException(nameof(securityPolicy));
            _timeProvider = timeProvider ?? TimeProvider.System;
            _inactivityTimeout = inactivityTimeout ?? TimeSpan.FromSeconds(60);

            _shared ??= this;
        }

        public RemoteControlSession? ActiveSession
        {
            get
            {
                lock (_lock)
                {
                    CleanExpiredSessionIfAny();
                    return _activeSession;
                }
            }
        }

        public bool IsSessionActive => ActiveSession != null;

        public SessionStartResult TryStartSession(string deviceId, string deviceRole)
        {
            if (string.IsNullOrWhiteSpace(deviceId))
            {
                return SessionStartResult.Forbidden("DEVICE_ID_REQUIRED");
            }

            // 1. Verificar bloqueio do Windows / UAC
            var sessionState = _desktopCapture.CheckSessionState();
            if (sessionState == DesktopSessionState.SessionLocked ||
                sessionState == DesktopSessionState.SecureDesktop ||
                sessionState == DesktopSessionState.NotInteractive)
            {
                return SessionStartResult.Locked("SESSION_LOCKED");
            }

            // 2. Verificar papel ViewerOnly
            if (string.Equals(deviceRole, "ViewerOnly", StringComparison.OrdinalIgnoreCase))
            {
                return SessionStartResult.Forbidden("INSUFFICIENT_DEVICE_ROLE");
            }

            if (!_securityPolicy.CanExecuteMutation(deviceId, "remote_input.session_start", out var denialReason))
            {
                return SessionStartResult.Forbidden(denialReason ?? "INSUFFICIENT_DEVICE_ROLE");
            }

            lock (_lock)
            {
                CleanExpiredSessionIfAny();

                if (_activeSession != null)
                {
                    if (string.Equals(_activeSession.DeviceId, deviceId, StringComparison.OrdinalIgnoreCase))
                    {
                        // Mesmo dispositivo: renova a atividade
                        _activeSession.Touch(_timeProvider.GetUtcNow());
                        return SessionStartResult.Succeeded(_activeSession);
                    }

                    return SessionStartResult.Conflict(_activeSession.DeviceId);
                }

                var now = _timeProvider.GetUtcNow();
                var session = new RemoteControlSession(
                    Guid.NewGuid().ToString("N"),
                    deviceId,
                    now,
                    now);

                _activeSession = session;
                NotifySessionChanged(session);
                return SessionStartResult.Succeeded(session);
            }
        }

        public bool TryEndSession(string deviceId, string reason)
        {
            lock (_lock)
            {
                CleanExpiredSessionIfAny();
                if (_activeSession == null) return false;

                if (!string.Equals(_activeSession.DeviceId, deviceId, StringComparison.OrdinalIgnoreCase) &&
                    !string.Equals(deviceId, "local_admin", StringComparison.OrdinalIgnoreCase))
                {
                    return false;
                }

                EndSessionInternal(_activeSession, reason);
                return true;
            }
        }

        public bool ForceEndSession(string reason)
        {
            lock (_lock)
            {
                if (_activeSession == null) return false;
                EndSessionInternal(_activeSession, reason);
                return true;
            }
        }

        public SessionValidateResult ValidateCanInput(string deviceId, string deviceRole)
        {
            // 1. Bloqueio do Windows / UAC
            var sessionState = _desktopCapture.CheckSessionState();
            if (sessionState == DesktopSessionState.SessionLocked ||
                sessionState == DesktopSessionState.SecureDesktop ||
                sessionState == DesktopSessionState.NotInteractive)
            {
                return SessionValidateResult.Locked("SESSION_LOCKED");
            }

            // 2. ViewerOnly
            if (string.Equals(deviceRole, "ViewerOnly", StringComparison.OrdinalIgnoreCase))
            {
                return SessionValidateResult.Forbidden("INSUFFICIENT_DEVICE_ROLE");
            }

            lock (_lock)
            {
                CleanExpiredSessionIfAny();

                if (_activeSession == null)
                {
                    return SessionValidateResult.NoActiveSession("NO_ACTIVE_SESSION");
                }

                if (!string.Equals(_activeSession.DeviceId, deviceId, StringComparison.OrdinalIgnoreCase) &&
                    !string.Equals(deviceId, "local_admin", StringComparison.OrdinalIgnoreCase))
                {
                    return SessionValidateResult.Forbidden("SESSION_OWNED_BY_ANOTHER_DEVICE");
                }

                // 3. Rate limiting
                var now = _timeProvider.GetUtcNow();
                long currentSecond = now.ToUnixTimeSeconds();
                if (currentSecond != _currentSecondWindow)
                {
                    _currentSecondWindow = currentSecond;
                    _eventsInCurrentSecond = 1;
                }
                else
                {
                    _eventsInCurrentSecond++;
                    if (_eventsInCurrentSecond > MaxEventsPerSecond)
                    {
                        return SessionValidateResult.RateLimitExceeded("RATE_LIMIT_EXCEEDED");
                    }
                }

                _activeSession.Touch(now);
                return SessionValidateResult.Allowed;
            }
        }

        private void CleanExpiredSessionIfAny()
        {
            if (_activeSession == null) return;

            var elapsed = _timeProvider.GetUtcNow() - _activeSession.LastActivityUtc;
            if (elapsed > _inactivityTimeout)
            {
                EndSessionInternal(_activeSession, "IdleTimeout");
            }
        }

        private void EndSessionInternal(RemoteControlSession session, string reason)
        {
            _activeSession = null;
            _securityPolicy.CanExecuteMutation(session.DeviceId, $"remote_input.session_end:{reason}", out _);
            NotifySessionChanged(null);
        }

        private void NotifySessionChanged(RemoteControlSession? session)
        {
            try
            {
                SessionChanged?.Invoke(session);
            }
            catch { }
        }
    }
}
