using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AnyDeck.Mixer
{
    internal class MixerConfig
    {
        private bool enabled;
        private string customName;

        public MixerConfig(bool enabled, string customName)
        {
            this.enabled = enabled;
            this.customName = customName;
        }

        public bool Enabled { get => enabled; set => enabled = value; }
        public string CustomName { get => customName; set => customName = value; }
    }
}
