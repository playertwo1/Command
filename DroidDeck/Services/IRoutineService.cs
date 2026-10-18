using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using DroidDeck.Models;

namespace DroidDeck.Services
{
    public interface IRoutineService
    {
        IReadOnlyList<RoutineDefinitionDto> GetRoutines();
        RoutineDefinitionDto? GetRoutine(string id);
        RoutineDefinitionDto SaveCustomRoutine(RoutineDefinitionDto routine);
        bool DeleteCustomRoutine(string id);
        Task<RoutineExecutionResponse> ExecuteRoutineAsync(string id, bool confirmed, string? deviceId = null, CancellationToken ct = default);
    }
}
