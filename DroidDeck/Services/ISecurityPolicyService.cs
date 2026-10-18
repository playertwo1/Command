using System.Collections.Generic;
using DroidDeck.Models;

namespace DroidDeck.Services
{
    public interface ISecurityPolicyService
    {
        IReadOnlyList<DevicePermissionDto> GetDevicePermissions();
        DevicePermissionDto SetDeviceRole(string deviceId, string role);
        bool CanExecuteMutation(string? deviceId, string actionType, out string? denialReason);
        IReadOnlyList<SecurityAuditEntryDto> GetAuditLog(int limit = 100);
    }
}
