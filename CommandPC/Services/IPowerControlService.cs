using Command.Models;

namespace Command.Services
{
    public interface IPowerControlService
    {
        NetworkWakeInfoDto GetWakeInfo();
        PowerActionResultDto ExecutePowerAction(PowerActionRequest request, string? deviceId = null);
        string FormatMacAddress(byte[]? physicalBytes);
    }
}
