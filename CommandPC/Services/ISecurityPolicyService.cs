using System.Collections.Generic;
using Command.Models;

namespace Command.Services
{
    public interface ISecurityPolicyService
    {
        IReadOnlyList<DevicePermissionDto> GetDevicePermissions();
        DevicePermissionDto SetDeviceRole(string deviceId, string role);
        bool CanExecuteMutation(string? deviceId, string actionType, out string? denialReason);
        IReadOnlyList<SecurityAuditEntryDto> GetAuditLog(int limit = 100);
    }
}
