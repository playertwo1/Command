using NAudio.CoreAudioApi;
using System;
using System.Diagnostics;

namespace RaspDeck
{
  class MixerChannel
  {
    private int id;
    private string description;
    private int volume;
    private string icon;
    private bool mute;
    private readonly AudioSessionControl session;

    public MixerChannel() { }
    public MixerChannel(AudioSessionControl session, float masterVolume)
    {
      id = 0;
      description = "Windows";
      if (!session.IsSystemSoundsSession)
      {
        if (ProcessExists(session.GetProcessID))
        {
          Process process = Process.GetProcessById((int)session.GetProcessID);
          description = (process.ProcessName == "Spotify" ? process.ProcessName + ": " : "") + (process.MainWindowTitle != "" ? process.MainWindowTitle : process.ProcessName);
          id = (int)session.GetProcessID;
        }
      }
      volume = (int)(session.SimpleAudioVolume.Volume * masterVolume * 100);
      mute = session.SimpleAudioVolume.Mute;
      this.session = session;
    }

    public AudioSessionControl GetSession()
    {
      return session;
    }

    public void SetOptions(MixerData data, float masterVolume)
    {
      if (session != null)
      {
        session.SimpleAudioVolume.Mute = data.Mute;
        float volume;
        volume = data.Volume / 100.0f;
        if (data.Volume > 0)
        {
          var newVolume = volume / masterVolume;
          if (newVolume <= 1)
            session.SimpleAudioVolume.Volume = newVolume;
          else
            session.SimpleAudioVolume.Volume = 1;
        }
        else
        {
          session.SimpleAudioVolume.Mute = true;
        }
      }
    }

    public int Id { get => id; set => id = value; }
    public string Description { get => description; set => description = value; }
    public int Volume { get => volume; set => volume = value; }
    public string Icon { get => icon; set => icon = value; }
    public bool Mute { get => mute; set => mute = value; }

    private bool ProcessExists(uint processId)
    {
      try
      {
        var process = Process.GetProcessById((int)processId);
        return true;
      }
      catch (ArgumentException)
      {
        return false;
      }
    }
  }
}
