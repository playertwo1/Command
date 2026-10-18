using DroidDeck.Models;

namespace DroidDeck.Services
{
    public interface ISystemStabilityMonitor
    {
        SystemStabilityDto GetCurrentSnapshot();
    }
}
