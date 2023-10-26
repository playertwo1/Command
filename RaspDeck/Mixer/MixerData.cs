using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AnyDeck
{
    public class MixerData
    {
        private int session;
        private bool mute;
        private int volume;

        public MixerData()
        {
            session = -1;
        }
        public int Session { get => session; set => session = value; }
        public bool Mute { get => mute; set => mute = value; }
        public int Volume { get => volume; set => volume = value; }
    }
}
