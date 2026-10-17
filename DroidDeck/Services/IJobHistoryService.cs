using System.Collections.Generic;
using DroidDeck.Models;

namespace DroidDeck.Services
{
    public interface IJobHistoryService
    {
        CommandJob GetOrCreateJob(string requestId, string actionType, string targetId, string? deviceId, out bool isExisting);
        void UpdateJob(string id, string status, string? errorMessage = null);
        IReadOnlyList<CommandJob> GetJobs(string? deviceId = null, int limit = 50);
        CommandJob? GetJob(string id);
        void ClearHistory(string? deviceId = null);
    }
}
