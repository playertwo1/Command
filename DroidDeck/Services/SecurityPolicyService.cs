using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using DroidDeck.Models;

namespace DroidDeck.Services
{
    public class SecurityPolicyService : ISecurityPolicyService
    {
        private readonly ConcurrentDictionary<string, DevicePermissionDto> _deviceRoles =
            new(StringComparer.OrdinalIgnoreCase);

        private readonly LinkedList<SecurityAuditEntryDto> _auditLog = new();
        private readonly object _auditLock = new();
        private const int MaxAuditLogEntries = 500;

        public IReadOnlyList<DevicePermissionDto> GetDevicePermissions()
        {
            return _deviceRoles.Values.OrderBy(d => d.DeviceId).ToList();
        }

        public DevicePermissionDto SetDeviceRole(string deviceId, string role)
        {
            if (string.IsNullOrWhiteSpace(deviceId))
            {
                throw new ArgumentException("DeviceId cannot be null or empty.", nameof(deviceId));
            }

            if (!string.Equals(role, "FullControl", StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(role, "ViewerOnly", StringComparison.OrdinalIgnoreCase))
            {
                throw new ArgumentException($"Invalid role '{role}'. Allowed roles are 'FullControl' or 'ViewerOnly'.", nameof(role));
            }

            string normalizedRole = string.Equals(role, "FullControl", StringComparison.OrdinalIgnoreCase)
                ? "FullControl"
                : "ViewerOnly";

            var entry = new DevicePermissionDto(deviceId, normalizedRole, DateTime.UtcNow);
            _deviceRoles[deviceId] = entry;
            return entry;
        }

        public bool CanExecuteMutation(string? deviceId, string actionType, out string? denialReason)
        {
            bool allowed = true;
            denialReason = null;

            if (!string.IsNullOrWhiteSpace(deviceId) &&
                _deviceRoles.TryGetValue(deviceId, out var permission))
            {
                if (string.Equals(permission.Role, "ViewerOnly", StringComparison.OrdinalIgnoreCase))
                {
                    allowed = false;
                    denialReason = "INSUFFICIENT_DEVICE_ROLE";
                }
            }

            var auditEntry = new SecurityAuditEntryDto(
                Guid.NewGuid().ToString("N"),
                deviceId ?? "unknown",
                actionType,
                allowed,
                denialReason ?? "OK",
                DateTime.UtcNow
            );

            lock (_auditLock)
            {
                _auditLog.AddFirst(auditEntry);
                while (_auditLog.Count > MaxAuditLogEntries)
                {
                    _auditLog.RemoveLast();
                }
            }

            return allowed;
        }

        public IReadOnlyList<SecurityAuditEntryDto> GetAuditLog(int limit = 100)
        {
            if (limit <= 0) limit = 100;

            lock (_auditLock)
            {
                return _auditLog.Take(limit).ToList();
            }
        }
    }
}
