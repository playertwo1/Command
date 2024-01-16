using AnyDeck.Lib;

namespace AnyDeck.Mixer
{
    internal class MixerEntity
    {
        private MixerConfig config;
        private MixerMaster device;

        public MixerEntity(MixerMaster master)
        {
            this.device = master;
            this.config = (MixerConfig)DBHelper.Retrieve(this.device.Id);
            if (this.config == null)
            {
                this.config = new MixerConfig(true, master.Title);
            }
        }

        public MixerConfig Config { get => this.config; set => this.config = value; }
        public MixerMaster Device { get => this.device; set => this.device = value; }
    }
}
