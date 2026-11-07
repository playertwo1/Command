using System;
using System.Linq;
using Command.Controllers;
using Command.Models;
using Command.Services;
using Microsoft.AspNetCore.Mvc;
using Xunit;

namespace Command.Tests
{
    public class SecurityPolicyTests
    {
        [Fact]
        public void SetDeviceRole_ValidRoles_StoresAndReturnsPermission()
        {
            var service = new SecurityPolicyService();

            var perm1 = service.SetDeviceRole("pixel-tablet", "FullControl");
            Assert.Equal("pixel-tablet", perm1.DeviceId);
            Assert.Equal("FullControl", perm1.Role);

            var perm2 = service.SetDeviceRole("guest-phone", "ViewerOnly");
            Assert.Equal("guest-phone", perm2.DeviceId);
            Assert.Equal("ViewerOnly", perm2.Role);

            var permissions = service.GetDevicePermissions();
            Assert.Equal(2, permissions.Count);
            Assert.Contains(permissions, p => p.DeviceId == "pixel-tablet" && p.Role == "FullControl");
            Assert.Contains(permissions, p => p.DeviceId == "guest-phone" && p.Role == "ViewerOnly");
        }

        [Theory]
        [InlineData("Admin")]
        [InlineData("Root")]
        [InlineData("ReadOnly")]
        [InlineData("")]
        [InlineData(" ")]
        public void SetDeviceRole_InvalidRole_ThrowsArgumentException(string invalidRole)
        {
            var service = new SecurityPolicyService();
            Assert.Throws<ArgumentException>(() => service.SetDeviceRole("dev-1", invalidRole));
        }

        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("   ")]
        public void SetDeviceRole_InvalidDeviceId_ThrowsArgumentException(string? invalidDeviceId)
        {
            var service = new SecurityPolicyService();
            Assert.Throws<ArgumentException>(() => service.SetDeviceRole(invalidDeviceId!, "FullControl"));
        }

        [Fact]
        public void CanExecuteMutation_UnregisteredOrFullControl_ReturnsTrue()
        {
            var service = new SecurityPolicyService();
            service.SetDeviceRole("dev-admin", "FullControl");

            // Dispositivo não registrado
            Assert.True(service.CanExecuteMutation("unknown-device", "app.launch", out var reason1));
            Assert.Null(reason1);

            // Dispositivo nulo
            Assert.True(service.CanExecuteMutation(null, "app.launch", out var reason2));
            Assert.Null(reason2);

            // Dispositivo FullControl
            Assert.True(service.CanExecuteMutation("dev-admin", "app.kill", out var reason3));
            Assert.Null(reason3);
        }

        [Fact]
        public void CanExecuteMutation_ViewerOnly_ReturnsFalseWithReason()
        {
            var service = new SecurityPolicyService();
            service.SetDeviceRole("viewer-tablet", "ViewerOnly");

            bool allowed = service.CanExecuteMutation("viewer-tablet", "routine.execute", out var denialReason);
            Assert.False(allowed);
            Assert.Equal("INSUFFICIENT_DEVICE_ROLE", denialReason);
        }

        [Fact]
        public void CanExecuteMutation_RecordsAuditEntriesCorrectly()
        {
            var service = new SecurityPolicyService();
            service.SetDeviceRole("viewer-1", "ViewerOnly");

            service.CanExecuteMutation("viewer-1", "routine.execute", out _);
            service.CanExecuteMutation("admin-1", "app.launch", out _);

            var auditLog = service.GetAuditLog(10);
            Assert.Equal(2, auditLog.Count);

            // Mais recente primeiro
            var latest = auditLog[0];
            Assert.Equal("admin-1", latest.DeviceId);
            Assert.Equal("app.launch", latest.ActionType);
            Assert.True(latest.Allowed);
            Assert.Equal("OK", latest.Reason);

            var previous = auditLog[1];
            Assert.Equal("viewer-1", previous.DeviceId);
            Assert.Equal("routine.execute", previous.ActionType);
            Assert.False(previous.Allowed);
            Assert.Equal("INSUFFICIENT_DEVICE_ROLE", previous.Reason);
        }

        [Fact]
        public void AuditLog_CapsAtMax500Entries()
        {
            var service = new SecurityPolicyService();

            for (int i = 0; i < 550; i++)
            {
                service.CanExecuteMutation($"dev-{i}", "test.action", out _);
            }

            var fullLog = service.GetAuditLog(1000);
            Assert.Equal(500, fullLog.Count);
        }

        [Fact]
        public void SecurityPolicyController_HandlesGetAndSetCorrectly()
        {
            var service = new SecurityPolicyService();
            var controller = new SecurityPolicyController(service);

            // Set role via controller
            var postResult = controller.SetDeviceRole(new UpdateDeviceRoleRequest("tab-1", "ViewerOnly"));
            var okResult = Assert.IsType<OkObjectResult>(postResult.Result);
            var perm = Assert.IsType<DevicePermissionDto>(okResult.Value);
            Assert.Equal("ViewerOnly", perm.Role);

            // Get devices
            var getResult = controller.GetDevices();
            var okGetResult = Assert.IsType<OkObjectResult>(getResult.Result);
            var list = Assert.IsAssignableFrom<System.Collections.Generic.IReadOnlyList<DevicePermissionDto>>(okGetResult.Value);
            Assert.Single(list);

            // Invalid role
            var badResult = controller.SetDeviceRole(new UpdateDeviceRoleRequest("tab-1", "Superadmin"));
            Assert.IsType<BadRequestObjectResult>(badResult.Result);

            // Audit log query
            service.CanExecuteMutation("tab-1", "action.test", out _);
            var auditResult = controller.GetAudit(10);
            var okAuditResult = Assert.IsType<OkObjectResult>(auditResult.Result);
            var auditList = Assert.IsAssignableFrom<System.Collections.Generic.IReadOnlyList<SecurityAuditEntryDto>>(okAuditResult.Value);
            Assert.Single(auditList);
        }
    }
}
