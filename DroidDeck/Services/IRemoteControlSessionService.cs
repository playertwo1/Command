using System;

namespace DroidDeck.Services
{
    public sealed class RemoteControlSession
    {
        public string SessionId { get; }
        public string DeviceId { get; }
        public DateTimeOffset StartTimeUtc { get; }
        public DateTimeOffset LastActivityUtc { get; private set; }

        public RemoteControlSession(string sessionId, string deviceId, DateTimeOffset startTimeUtc, DateTimeOffset lastActivityUtc)
        {
            SessionId = sessionId;
            DeviceId = deviceId;
            StartTimeUtc = startTimeUtc;
            LastActivityUtc = lastActivityUtc;
        }

        public void Touch(DateTimeOffset now) => LastActivityUtc = now;
    }

    public enum SessionStartStatus
    {
        Success,
        Locked,
        Forbidden,
        Conflict
    }

    public enum SessionValidateStatus
    {
        Allowed,
        Locked,
        Forbidden,
        NoActiveSession,
        RateLimitExceeded
    }

    public sealed record SessionStartResult(
        SessionStartStatus Status,
        RemoteControlSession? Session = null,
        string? ActiveDeviceId = null,
        string? Reason = null)
    {
        public static SessionStartResult Succeeded(RemoteControlSession session) =>
            new(SessionStartStatus.Success, Session: session);

        public static SessionStartResult Locked(string reason) =>
            new(SessionStartStatus.Locked, Reason: reason);

        public static SessionStartResult Forbidden(string reason) =>
            new(SessionStartStatus.Forbidden, Reason: reason);

        public static SessionStartResult Conflict(string activeDeviceId) =>
            new(SessionStartStatus.Conflict, ActiveDeviceId: activeDeviceId, Reason: "SESSION_ALREADY_ACTIVE");
    }

    public sealed record SessionValidateResult(
        SessionValidateStatus Status,
        string? Reason = null)
    {
        public static readonly SessionValidateResult Allowed = new(SessionValidateStatus.Allowed);

        public static SessionValidateResult Locked(string reason) =>
            new(SessionValidateStatus.Locked, Reason: reason);

        public static SessionValidateResult Forbidden(string reason) =>
            new(SessionValidateStatus.Forbidden, Reason: reason);

        public static SessionValidateResult NoActiveSession(string reason) =>
            new(SessionValidateStatus.NoActiveSession, Reason: reason);

        public static SessionValidateResult RateLimitExceeded(string reason) =>
            new(SessionValidateStatus.RateLimitExceeded, Reason: reason);
    }

    public interface IRemoteControlSessionService
    {
        RemoteControlSession? ActiveSession { get; }
        bool IsSessionActive { get; }

        SessionStartResult TryStartSession(string deviceId, string deviceRole);
        bool TryEndSession(string deviceId, string reason);
        bool ForceEndSession(string reason);

        SessionValidateResult ValidateCanInput(string deviceId, string deviceRole);

        event Action<RemoteControlSession?>? SessionChanged;
    }
}
