using Command.Models;

namespace Command.Services
{
    public interface ISystemStabilityMonitor
    {
        SystemStabilityDto GetCurrentSnapshot();
    }
}
