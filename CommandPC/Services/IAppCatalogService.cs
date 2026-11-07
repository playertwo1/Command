using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Command.Models;

namespace Command.Services
{
    public interface IAppCatalogService
    {
        IReadOnlyList<AppSummaryDto> GetAllowedApps();
        bool TryGetApp(string id, out AppCatalogItem item);
        AppSummaryDto? GetAppSummary(string id);
        Task<AppOperationResult> LaunchAsync(string id);
        Task<AppOperationResult> KillAsync(string id, int? expectedPid = null, DateTime? expectedStartTimeUtc = null);
    }
}
