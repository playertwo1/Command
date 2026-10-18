using System;

namespace DroidDeck.Models
{
    public record DevicePermissionDto(string DeviceId, string Role, DateTime UpdatedAtUtc);

    public record UpdateDeviceRoleRequest(string DeviceId, string Role);

    public record SecurityAuditEntryDto(string Id, string DeviceId, string ActionType, bool Allowed, string Reason, DateTime TimestampUtc);
}
