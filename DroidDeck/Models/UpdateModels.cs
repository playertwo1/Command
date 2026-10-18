using System;

namespace DroidDeck.Models
{
    public record UpdateStatusDto(
        string CurrentVersion,
        string Channel,
        bool UpdateAvailable,
        string LatestVersion,
        bool IsVelopackReady,
        string BinarySha256,
        DateTime CheckedAtUtc
    );

    public record VerifyUpdatePackageRequest(string PayloadBase64, string ExpectedSha256);

    public record VerifyUpdatePackageResponse(bool IsValid, string ActualSha256, string? ErrorMessage);

    public record SystemStabilityDto(
        double WorkingSetMb,
        int HandleCount,
        int ThreadCount,
        long BridgeUptimeSeconds,
        string HealthStatus,
        DateTime TimestampUtc
    );
}
