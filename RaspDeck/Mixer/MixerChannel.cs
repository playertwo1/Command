using NAudio.CoreAudioApi;
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

namespace AnyDeck
{
    class MixerChannel
    {
        private readonly AudioSessionControl session;

        public MixerChannel() { }
        public MixerChannel(AudioSessionControl session, float masterVolume)
        {
            Id = 0;
            Description = "Windows";
            if (!session.IsSystemSoundsSession)
            {
                if (ProcessExists(session.GetProcessID))
                {
                    Process process = Process.GetProcessById((int)session.GetProcessID);
                    Description = (process.ProcessName == "Spotify" ? process.ProcessName + ": " : "") + (process.MainWindowTitle != "" ? process.MainWindowTitle : process.ProcessName);
                    String SigBase64 = null;
                    Id = (int)session.GetProcessID;
                    try
                    {
                        Bitmap bImage = System.Drawing.Icon.ExtractAssociatedIcon(process.MainModule.FileName).ToBitmap();
                        System.IO.MemoryStream ms = new MemoryStream();
                        bImage.Save(ms, ImageFormat.Png);
                        byte[] byteImage = ms.ToArray();
                        SigBase64 = "data:image/png;base64," + Convert.ToBase64String(byteImage);
                    }
                    catch
                    {

                    }
                    finally
                    {
                        Icon = SigBase64;
                    }
                }
            }
            Volume = (int)(session.SimpleAudioVolume.Volume * masterVolume * 100);
            Mute = session.SimpleAudioVolume.Mute;
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
                float volume;
                volume = (data.Volume ?? -1.0f) / 100.0f;
                var newVolume = volume / masterVolume;
                bool mute = data.Mute == true;
                if (mute && session.SimpleAudioVolume.Volume >= newVolume)
                    session.SimpleAudioVolume.Mute = mute;
                else
                    if (newVolume > 0)
                {
                    if (newVolume <= 1)
                        session.SimpleAudioVolume.Volume = newVolume;
                    else
                        session.SimpleAudioVolume.Volume = 1;
                    session.SimpleAudioVolume.Mute = false;
                }
                else
                    session.SimpleAudioVolume.Mute = mute;
            }
        }

        public int Id { get; set; }
        public string Description { get; set; }
        public int Volume { get; set; }
        public string Icon { get; set; }
        public bool Mute { get; set; }

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
