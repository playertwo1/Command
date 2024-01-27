using AnyDeck.Mixer;
using NAudio.CoreAudioApi;
using System.Collections.Generic;

namespace AnyDeck.Services
{
    internal class MixerService
    {
        public List<MixerEntity> FindAllOutputs()
        {
            List<MixerEntity> list = new List<MixerEntity>();
            foreach (MixerMaster item in MixerMaster.GetAllMixers(DataFlow.Render, DeviceState.Active))
            {
                list.Add(new MixerEntity(item));
            }
            return list;
        }

        public List<MixerEntity> FindAllInputs()
        {
            List<MixerEntity> list = new List<MixerEntity>();
            foreach(MixerMaster item in MixerMaster.GetAllMixers(DataFlow.Capture, DeviceState.Active))
            {
                list.Add(new MixerEntity(item));
            }
            return list;
        }

        public MixerEntity FindOne(string id)
        {
            MixerMaster result = new MixerMaster(id);
            if (result != null)
                return new MixerEntity(result);
            return null;
        }
    }
}
