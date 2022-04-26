using NAudio.CoreAudioApi;
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;

namespace RaspDeck
{
  class MixerMaster
  {
    private string id;
    private string title;
    private string description;
    private int volume;
    private string icon;
    private bool mute;
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
      if (device.State.CompareTo(DeviceState.Unplugged) == 0 || device.State.CompareTo(DeviceState.NotPresent) == 0 || device.State.CompareTo(DeviceState.Disabled) == 0) device = null;
      if (device != null)
      {
        newMaster(device);
      }
    }

    private void newMaster(MMDevice device)
    {
      id = device.ID;
      title = device.FriendlyName.Substring(0, device.FriendlyName.IndexOf("(")).Trim();
      description = device.DeviceFriendlyName;
      volume = (int)(device.AudioEndpointVolume.MasterVolumeLevelScalar * 100);
      mute = device.AudioEndpointVolume.Mute;
      icon = null;
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
        volume = data.Volume / 100.0f;
        if (data.Session >= 0 && device.DataFlow.CompareTo(DataFlow.Render) == 0) //Alterando Session!
          GetChannel(data.Session).SetOptions(data, device.AudioEndpointVolume.MasterVolumeLevelScalar);
        else //Alterando Master!
        {
          if (data.Mute)
            device.AudioEndpointVolume.Mute = data.Mute;
          else if (data.Volume > 0)
          {
            device.AudioEndpointVolume.MasterVolumeLevelScalar = volume;
          }
          else
          {
            device.AudioEndpointVolume.Mute = true;
          }
        }
      }
      return new MixerMaster(device);
    }

    public string Id { get => id; set => id = value; }
    public string Title { get => title; set => title = value; }
    public string Description { get => description; set => description = value; }
    public int Volume { get => volume; set => volume = value; }
    public string Icon { get => icon; set => icon = value; }
    public bool Mute { get => mute; set => mute = value; }
    public List<MixerChannel> Channels { get => channels.Values.ToList(); }
  }
}
