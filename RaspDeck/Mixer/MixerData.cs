using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AnyDeck
{
    public class MixerData
    {
        public MixerData()
        {
            Session = -1;
        }
        public int Session { get; set; }
        public bool? Mute { get; set; }
        public int? Volume { get; set; }
    }
}
