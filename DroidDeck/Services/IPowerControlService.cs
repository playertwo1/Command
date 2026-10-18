using DroidDeck.Models;

namespace DroidDeck.Services
{
    public interface IPowerControlService
    {
        NetworkWakeInfoDto GetWakeInfo();
        PowerActionResultDto ExecutePowerAction(PowerActionRequest request, string? deviceId = null);
        string FormatMacAddress(byte[]? physicalBytes);
    }
}
