using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Command.Models;

namespace Command.Services
{
    public interface IRoutineService
    {
        IReadOnlyList<RoutineDefinitionDto> GetRoutines();
        IReadOnlyList<RoutineDefinitionDto> GetCustomRoutines();
        RoutineDefinitionDto? GetRoutine(string id);
        RoutineDefinitionDto SaveCustomRoutine(RoutineDefinitionDto routine);
        bool DeleteCustomRoutine(string id);
        Task<RoutineExecutionResponse> ExecuteRoutineAsync(string id, bool confirmed, string? deviceId = null, CancellationToken ct = default);
    }
}
