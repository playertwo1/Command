using System;
using System.Collections.Generic;
using DroidDeck.Controllers;
using DroidDeck.Models;
using DroidDeck.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Xunit;

namespace DroidDeck.Tests
{
    public class PowerControlTests
    {
        [Fact]
        public void FormatMacAddress_ConvertsByteArrayToColonSeparatedUpperHex()
        {
            var service = new PowerControlService();
            var bytes = new byte[] { 0x00, 0x1A, 0x2B, 0x3C, 0x4D, 0x5E };

            string mac = service.FormatMacAddress(bytes);

            Assert.Equal("00:1A:2B:3C:4D:5E", mac);
        }

        [Fact]
        public void FormatMacAddress_NullOrEmpty_ReturnsEmptyString()
        {
            var service = new PowerControlService();

            Assert.Equal(string.Empty, service.FormatMacAddress(null));
            Assert.Equal(string.Empty, service.FormatMacAddress(Array.Empty<byte>()));
        }

        [Fact]
        public void GetWakeInfo_ReturnsValidHostAndNetworkInfo()
        {
            var service = new PowerControlService();
            var wakeInfo = service.GetWakeInfo();

            Assert.NotNull(wakeInfo);
            Assert.False(string.IsNullOrWhiteSpace(wakeInfo.HostName));
            Assert.Equal(Environment.MachineName, wakeInfo.HostName);
            Assert.Equal(9, wakeInfo.WolPort);
            // MAC address se encontrado deve ter formato AA:BB:CC:DD:EE:FF
            if (wakeInfo.SupportsWakeOnLan)
            {
                Assert.Matches(@"^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$", wakeInfo.MacAddress);
            }
        }

        [Fact]
        public void ExecutePowerAction_RequiresExplicitConfirmation()
        {
            var service = new PowerControlService();

            // Lock sem confirmação
            var lockResult = service.ExecutePowerAction(new PowerActionRequest
            {
                Action = "lock",
                Confirmed = false
            });

            Assert.False(lockResult.Success);
            Assert.Equal("aborted", lockResult.Status);
            Assert.Equal("CONFIRMATION_REQUIRED", lockResult.ErrorCode);
            Assert.Contains("obrigatória", lockResult.ErrorMessage);

            // Sleep sem confirmação
            var sleepResult = service.ExecutePowerAction(new PowerActionRequest
            {
                Action = "sleep",
                Confirmed = false
            });

            Assert.False(sleepResult.Success);
            Assert.Equal("aborted", sleepResult.Status);
            Assert.Equal("CONFIRMATION_REQUIRED", sleepResult.ErrorCode);

            foreach (var action in new[] { "shutdown", "restart" })
            {
                var result = service.ExecutePowerAction(new PowerActionRequest
                {
                    Action = action,
                    Confirmed = false
                });
                Assert.False(result.Success);
                Assert.Equal("aborted", result.Status);
                Assert.Equal("CONFIRMATION_REQUIRED", result.ErrorCode);
            }
        }

        [Fact]
        public void ExecutePowerAction_RejectsActionsOutsideAllowlist()
        {
            var service = new PowerControlService();

            foreach (var action in new[] { "cmd", "hibernate", "shutdown.exe", " ", "" })
            {
                var result = service.ExecutePowerAction(new PowerActionRequest
                {
                    Action = action,
                    Confirmed = true
                });

                Assert.False(result.Success);
                Assert.Equal("failed", result.Status);
                Assert.Equal("ACTION_NOT_ALLOWED", result.ErrorCode);
            }
        }

        [Fact]
        public void ExecutePowerAction_ShutdownAndRestart_UseInvokerAndAudit()
        {
            var calls = new List<bool>();
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var service = new PowerControlService(
                jobHistory: jobHistory,
                exitWindowsInvoker: restart =>
                {
                    calls.Add(restart);
                    return true;
                });

            var shutdown = service.ExecutePowerAction(new PowerActionRequest
            {
                Action = "shutdown",
                Confirmed = true,
                RequestId = "req_shutdown_1"
            }, deviceId: "device_a");

            Assert.True(shutdown.Success);
            Assert.Equal("shutdown", shutdown.Action);
            Assert.Equal("succeeded", shutdown.Status);
            Assert.Equal(new[] { false }, calls);
            var shutdownJob = jobHistory.GetJob(shutdown.JobId!);
            Assert.NotNull(shutdownJob);
            Assert.Equal("system.shutdown", shutdownJob.ActionType);
            Assert.Equal("succeeded", shutdownJob.Status);
            Assert.DoesNotContain("shutdown.exe", shutdownJob.ActionType, StringComparison.OrdinalIgnoreCase);

            var restart = service.ExecutePowerAction(new PowerActionRequest
            {
                Action = " RESTART ",
                Confirmed = true,
                RequestId = "req_restart_1"
            }, deviceId: "device_b");

            Assert.True(restart.Success);
            Assert.Equal("restart", restart.Action);
            Assert.Equal(new[] { false, true }, calls);
            var restartJob = jobHistory.GetJob(restart.JobId!);
            Assert.NotNull(restartJob);
            Assert.Equal("system.restart", restartJob.ActionType);
        }

        [Fact]
        public void ExecutePowerAction_ShutdownFailure_RecordsFailedJob()
        {
            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);
            var service = new PowerControlService(
                jobHistory: jobHistory,
                exitWindowsInvoker: _ => false);

            var result = service.ExecutePowerAction(new PowerActionRequest
            {
                Action = "shutdown",
                Confirmed = true,
                RequestId = "req_shutdown_fail"
            });

            Assert.False(result.Success);
            Assert.Equal("EXECUTION_FAILED", result.ErrorCode);
            var job = jobHistory.GetJob(result.JobId!);
            Assert.NotNull(job);
            Assert.Equal("failed", job.Status);
        }

        [Fact]
        public void ExecutePowerAction_InvokesInjectedDelegates_AndRecordsJobHistory()
        {
            bool lockCalled = false;
            bool sleepCalled = false;

            var jobHistory = new JobHistoryService(NullLogger<JobHistoryService>.Instance);

            var service = new PowerControlService(
                jobHistory: jobHistory,
                lockWorkstationInvoker: () => { lockCalled = true; return true; },
                suspendStateInvoker: () => { sleepCalled = true; return true; }
            );

            // 1. Testa Lock com confirmação
            var lockResult = service.ExecutePowerAction(new PowerActionRequest
            {
                Action = "lock",
                Confirmed = true,
                RequestId = "req_lock_1"
            }, deviceId: "device_a");

            Assert.True(lockResult.Success);
            Assert.Equal("succeeded", lockResult.Status);
            Assert.Equal("lock", lockResult.Action);
            Assert.True(lockCalled);
            Assert.NotNull(lockResult.JobId);

            var lockJob = jobHistory.GetJob(lockResult.JobId!);
            Assert.NotNull(lockJob);
            Assert.Equal("succeeded", lockJob.Status);
            Assert.Equal("system.lock_workstation", lockJob.ActionType);

            // 2. Testa Sleep com confirmação
            var sleepResult = service.ExecutePowerAction(new PowerActionRequest
            {
                Action = "sleep",
                Confirmed = true,
                RequestId = "req_sleep_1"
            }, deviceId: "device_b");

            Assert.True(sleepResult.Success);
            Assert.Equal("succeeded", sleepResult.Status);
            Assert.Equal("sleep", sleepResult.Action);
            Assert.True(sleepCalled);
            Assert.NotNull(sleepResult.JobId);

            var sleepJob = jobHistory.GetJob(sleepResult.JobId!);
            Assert.NotNull(sleepJob);
            Assert.Equal("succeeded", sleepJob.Status);
            Assert.Equal("system.sleep", sleepJob.ActionType);
        }

        [Fact]
        public void PowerController_EndpointsWorkProperly()
        {
            var service = new PowerControlService(
                lockWorkstationInvoker: () => true,
                suspendStateInvoker: () => true
            );

            var controller = new PowerController(service);

            // GET wake-info
            var wakeRes = controller.GetWakeInfo();
            var okWake = Assert.IsType<OkObjectResult>(wakeRes.Result);
            var wakeDto = Assert.IsType<NetworkWakeInfoDto>(okWake.Value);
            Assert.Equal(Environment.MachineName, wakeDto.HostName);

            // POST lock sem confirmação -> 400 BadRequest
            var unconfirmedRes = controller.Lock(confirmed: false);
            var badReq = Assert.IsType<BadRequestObjectResult>(unconfirmedRes.Result);
            var badDto = Assert.IsType<PowerActionResultDto>(badReq.Value);
            Assert.False(badDto.Success);
            Assert.Equal("CONFIRMATION_REQUIRED", badDto.ErrorCode);

            // POST lock com confirmação -> 200 OK
            var confirmedLock = controller.Lock(confirmed: true);
            var okLock = Assert.IsType<OkObjectResult>(confirmedLock.Result);
            var lockDto = Assert.IsType<PowerActionResultDto>(okLock.Value);
            Assert.True(lockDto.Success);
            Assert.Equal("lock", lockDto.Action);

            // POST sleep com confirmação -> 200 OK
            var confirmedSleep = controller.Sleep(confirmed: true);
            var okSleep = Assert.IsType<OkObjectResult>(confirmedSleep.Result);
            var sleepDto = Assert.IsType<PowerActionResultDto>(okSleep.Value);
            Assert.True(sleepDto.Success);
            Assert.Equal("sleep", sleepDto.Action);

            var nativeCalls = new List<bool>();
            var nativeService = new PowerControlService(exitWindowsInvoker: restart =>
            {
                nativeCalls.Add(restart);
                return true;
            });
            var nativeController = new PowerController(nativeService);

            var deniedShutdown = nativeController.Shutdown(confirmed: false);
            var badShutdown = Assert.IsType<BadRequestObjectResult>(deniedShutdown.Result);
            var deniedDto = Assert.IsType<PowerActionResultDto>(badShutdown.Value);
            Assert.Equal("CONFIRMATION_REQUIRED", deniedDto.ErrorCode);
            Assert.Empty(nativeCalls);

            var okShutdown = nativeController.Shutdown(confirmed: true);
            var shutdownResult = Assert.IsType<OkObjectResult>(okShutdown.Result);
            var shutdownDto = Assert.IsType<PowerActionResultDto>(shutdownResult.Value);
            Assert.True(shutdownDto.Success);
            Assert.Equal("shutdown", shutdownDto.Action);

            var okRestart = nativeController.Restart(confirmed: true);
            var restartResult = Assert.IsType<OkObjectResult>(okRestart.Result);
            var restartDto = Assert.IsType<PowerActionResultDto>(restartResult.Value);
            Assert.True(restartDto.Success);
            Assert.Equal("restart", restartDto.Action);
            Assert.Equal(new[] { false, true }, nativeCalls);
        }
    }
}
