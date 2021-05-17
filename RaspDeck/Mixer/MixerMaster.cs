using NAudio.CoreAudioApi;
using System.Collections.Generic;
using System.Linq;

namespace RaspDeck
{
  class MixerMaster
  {
    private string id;
    private string category;
    private string description;
    private int volume;
    private string icon;
    private bool mute;
    private Dictionary<int, MixerChannel> channels;

    public MixerMaster()
    {
      channels = new Dictionary<int, MixerChannel>();
    }
    public MixerMaster(MMDevice device, string category)
    {
      channels = new Dictionary<int, MixerChannel>();
      id = device.ID;
      this.category = category;
      description = device.FriendlyName;
      volume = (int)(device.AudioEndpointVolume.MasterVolumeLevelScalar * 100);
      icon = null;
      mute = device.AudioEndpointVolume.Mute;
      if ("output".Equals(category))
      {
        var sessions = device.AudioSessionManager.Sessions;
        for (int i = 0; i < sessions.Count; i++)
        {
          if (sessions[i].IsSystemSoundsSession) continue;
          var channel = new MixerChannel(sessions[i], device.AudioEndpointVolume.MasterVolumeLevelScalar);
          channels[(int)sessions[i].GetProcessID] = channel;
        }
      }
    }
    public MixerMaster(string id, string category)
    {
      channels = new Dictionary<int, MixerChannel>();
      var devices = new MMDeviceEnumerator();
      var device = devices.GetDevice(id);
      if (device.State.CompareTo(DeviceState.Unplugged) == 0 || device.State.CompareTo(DeviceState.NotPresent) == 0 || device.State.CompareTo(DeviceState.Disabled) == 0) device = null;
      if (device != null)
      {
        this.id = device.ID;
        this.category = category;
        description = device.FriendlyName;
        volume = (int)(device.AudioEndpointVolume.MasterVolumeLevelScalar * 100);
        icon = null;
        mute = device.AudioEndpointVolume.Mute;
        if ("output".Equals(category))
        {
          var sessions = device.AudioSessionManager.Sessions;
          for (int i = 0; i < sessions.Count; i++)
          {
            if (sessions[i].IsSystemSoundsSession) continue;
            var channel = new MixerChannel(sessions[i], device.AudioEndpointVolume.MasterVolumeLevelScalar);
            channels[(int)sessions[i].GetProcessID] = channel;
          }
        }
      }
    }
    public static List<MixerMaster> GetAllMixers(DataFlow dataFlow, DeviceState deviceState)
    {
      var devices = new List<MixerMaster>();
      foreach (MMDevice d in new MMDeviceEnumerator().EnumerateAudioEndPoints(dataFlow, deviceState))
      {
        var master = new MixerMaster(d, ((dataFlow.CompareTo(DataFlow.Render) == 0) ? "output" : "input"));
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
        volume = data.Volume / 100.0f;
        if (data.Session >= 0 && device.DataFlow.CompareTo(DataFlow.Render) == 0) //Alterando Session!
          GetChannel(data.Session).SetOptions(data, device.AudioEndpointVolume.MasterVolumeLevelScalar);
        else //Alterando Master!
        {
          if (data.Volume > 0)
          {
            device.AudioEndpointVolume.MasterVolumeLevelScalar = volume;
          }
          else
          {
            device.AudioEndpointVolume.Mute = true;
          }
          device.AudioEndpointVolume.Mute = data.Mute;
        }
      }
      return new MixerMaster(device, ((device.DataFlow.CompareTo(DataFlow.Render) == 0) ? "output" : "input"));
    }

    public string Id { get => id; set => id = value; }
    public string Category { get => category; set => category = value; }
    public string Description { get => description; set => description = value; }
    public int Volume { get => volume; set => volume = value; }
    public string Icon { get => icon; set => icon = value; }
    public bool Mute { get => mute; set => mute = value; }
    public List<MixerChannel> Channels { get => channels.Values.ToList(); }
  }
}
