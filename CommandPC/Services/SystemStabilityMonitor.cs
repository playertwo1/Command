using System;
using System.Diagnostics;
using Command.Models;

namespace Command.Services
{
    public class SystemStabilityMonitor : ISystemStabilityMonitor
    {
        private readonly DateTime _startTimeUtc;

        public SystemStabilityMonitor()
        {
            try
            {
                using var proc = Process.GetCurrentProcess();
                _startTimeUtc = proc.StartTime.ToUniversalTime();
            }
            catch
            {
                _startTimeUtc = DateTime.UtcNow;
            }
        }

        public SystemStabilityDto GetCurrentSnapshot()
        {
            using var proc = Process.GetCurrentProcess();
            proc.Refresh();

            double workingSetMb = Math.Round(proc.WorkingSet64 / 1024.0 / 1024.0, 2);
            int handleCount = proc.HandleCount;
            int threadCount = proc.Threads.Count;
            long uptimeSeconds = Math.Max(0, (long)(DateTime.UtcNow - _startTimeUtc).TotalSeconds);

            string healthStatus = (workingSetMb < 350.0 && handleCount < 2500)
                ? "Healthy"
                : "Warning";

            return new SystemStabilityDto(
                WorkingSetMb: workingSetMb,
                HandleCount: handleCount,
                ThreadCount: threadCount,
                BridgeUptimeSeconds: uptimeSeconds,
                HealthStatus: healthStatus,
                TimestampUtc: DateTime.UtcNow
            );
        }
    }
}
