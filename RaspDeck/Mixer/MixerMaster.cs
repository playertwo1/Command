using NAudio.CoreAudioApi;
using System.Collections.Generic;
using System.Linq;

namespace AnyDeck
{
    class MixerMaster
    {
        private Dictionary<int, MixerChannel> channels;

        public MixerMaster()
        {
            channels = new Dictionary<int, MixerChannel>();
        }
        public MixerMaster(MMDevice device)
        {
            newMaster(device);
        }
        public MixerMaster(string idString)
        {
            var devices = new MMDeviceEnumerator();
            var device = devices.GetDevice(idString);
            if (device.State.CompareTo(DeviceState.Unplugged) == 0 ||
                device.State.CompareTo(DeviceState.NotPresent) == 0 ||
                device.State.CompareTo(DeviceState.Disabled) == 0) device = null;
            if (device != null) newMaster(device);
        }

        private void newMaster(MMDevice device)
        {
            Id = device.ID;
            Title = device.FriendlyName.Substring(0, device.FriendlyName.IndexOf("(")).Trim();
            Description = device.DeviceFriendlyName;
            Volume = (int)(device.AudioEndpointVolume.MasterVolumeLevelScalar * 100);
            Mute = device.AudioEndpointVolume.Mute;
            Icon = null;
            if (device.DataFlow == DataFlow.Render)
            {
                var sessions = device.AudioSessionManager.Sessions;
                channels = new Dictionary<int, MixerChannel>();
                for (int i = 0; i < sessions.Count; i++)
                {
                    if (sessions[i].IsSystemSoundsSession) continue;
                    var channel = new MixerChannel(sessions[i], device.AudioEndpointVolume.MasterVolumeLevelScalar);
                    channels[(int)sessions[i].GetProcessID] = channel;
                }
            }
        }
        public static List<MixerMaster> GetAllMixers(DataFlow dataFlow, DeviceState deviceState)
        {
            var devices = new List<MixerMaster>();
            foreach (MMDevice d in new MMDeviceEnumerator().EnumerateAudioEndPoints(dataFlow, deviceState))
            {
                var master = new MixerMaster(d);
                devices.Add(master);
            }
            return devices;
        }
        public MixerChannel GetChannel(int id)
        {
            return channels[id];
        }

        public MixerMaster SetOptions(string id, MixerData data)
        {
            var devices = new MMDeviceEnumerator();
            var device = devices.GetDevice(id);
            if (device == null) return null;
            else
            {
                float volume;
                volume = (data.Volume ?? -1.0f) / 100.0f;
                bool mute = data.Mute == true;
                if (data.Session >= 0 && device.DataFlow.CompareTo(DataFlow.Render) == 0)
                    GetChannel(data.Session).SetOptions(data, device.AudioEndpointVolume.MasterVolumeLevelScalar);
                else
                    if (mute && device.AudioEndpointVolume.MasterVolumeLevelScalar >= volume)
                    device.AudioEndpointVolume.Mute = mute;
                else
                        if (volume > 0)
                {
                    device.AudioEndpointVolume.MasterVolumeLevelScalar = volume;
                    device.AudioEndpointVolume.Mute = false;
                }
                else
                    device.AudioEndpointVolume.Mute = mute;
            }
            return new MixerMaster(device);
        }

        public string Id { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public int Volume { get; set; }
        public string Icon { get; set; }
        public bool Mute { get; set; }
        public List<MixerChannel> Channels { get => channels != null ? channels.Values.ToList() : null; }
    }
}
