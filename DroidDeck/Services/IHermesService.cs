using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Models;

namespace DroidDeck.Services
{
    public interface IHermesService
    {
        HermesConfigDto GetStatus();
        HermesConfigDto UpdateConfig(HermesUpdateConfigRequest request);
        Task<HermesAnalyzeResponse> AnalyzeAsync(HermesAnalyzeRequest request, string? deviceId = null, CancellationToken ct = default);
        List<HermesSuggestedActionDto> FilterAllowedActions(IEnumerable<HermesSuggestedActionDto> candidates);
    }
}
