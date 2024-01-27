using AnyDeck.Lib;

namespace AnyDeck.Mixer
{
    internal class MixerEntity
    {
        public MixerEntity(MixerMaster master)
        {
            this.Device = master;
            this.Config = (MixerConfig)DBHelper.Retrieve(this.Device.Id);
            if (this.Config == null)
            {
                this.Config = new MixerConfig(true, master.Title);
            }
        }

        public MixerConfig Config { get; set; }
        public MixerMaster Device { get; set; }
    }
}
