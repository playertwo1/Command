using NAudio.CoreAudioApi;
using System.Collections.Generic;

namespace Command.Audio
{
    public interface IAudioDeviceEnumerator
    {
        IEnumerable<IAudioDevice> EnumerateAudioEndPoints(DataFlow dataFlow, DeviceState deviceState);
        IAudioDevice? GetDevice(string id);
    }
}
