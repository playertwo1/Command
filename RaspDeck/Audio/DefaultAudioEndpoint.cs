using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using NAudio.CoreAudioApi;

namespace DroidDeck.Audio
{
    /// <summary>
    /// Troca o dispositivo de audio padrao do Windows.
    ///
    /// Nao existe API publica para isso: o proprio painel de Som usa a interface COM nao
    /// documentada IPolicyConfig, estavel desde o Windows 7 (EarTrumpet, SoundSwitch e
    /// AudioDeviceCmdlets usam a mesma). Define o padrao nos tres papeis (console, multimidia
    /// e comunicacao), que e o que o usuario espera ao "trocar de fone".
    /// </summary>
    public static class DefaultAudioEndpoint
    {
        public static void Set(string deviceId)
        {
            var policy = (IPolicyConfig)new PolicyConfigClient();
            try
            {
                foreach (var role in new[] { ERole.Console, ERole.Multimedia, ERole.Communications })
                    Marshal.ThrowExceptionForHR(policy.SetDefaultEndpoint(deviceId, role));
            }
            finally
            {
                Marshal.ReleaseComObject(policy);
            }
        }

        /// <summary>Id do padrao atual de saida (render) ou entrada (capture).</summary>
        public static string? GetDefault(bool input)
        {
            try
            {
                using var en = new MMDeviceEnumerator();
                using var device = en.GetDefaultAudioEndpoint(input ? DataFlow.Capture : DataFlow.Render, Role.Multimedia);
                return device.ID;
            }
            catch
            {
                return null;
            }
        }

        /// <summary>Dispositivos ativos: (id, nome).</summary>
        public static List<(string Id, string Name)> List(bool input)
        {
            var result = new List<(string, string)>();
            using var en = new MMDeviceEnumerator();
            var devices = en.EnumerateAudioEndPoints(input ? DataFlow.Capture : DataFlow.Render, DeviceState.Active);
            foreach (var d in devices)
            {
                // Proxy COM: liberar sempre (ver MixerMaster).
                using (d) result.Add((d.ID, d.FriendlyName));
            }
            return result;
        }

        private enum ERole
        {
            Console = 0,
            Multimedia = 1,
            Communications = 2,
        }

        [ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")]
        private class PolicyConfigClient { }

        // So SetDefaultEndpoint e usado; os metodos anteriores precisam estar declarados para a
        // vtable ficar na ordem certa.
        [ComImport, Guid("f8679f50-850a-41cf-9c72-430f290290c8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IPolicyConfig
        {
            [PreserveSig] int GetMixFormat(string deviceId, IntPtr format);
            [PreserveSig] int GetDeviceFormat(string deviceId, bool defaultFormat, IntPtr format);
            [PreserveSig] int ResetDeviceFormat(string deviceId);
            [PreserveSig] int SetDeviceFormat(string deviceId, IntPtr endpointFormat, IntPtr mixFormat);
            [PreserveSig] int GetProcessingPeriod(string deviceId, bool defaultPeriod, IntPtr defaultPeriodOut, IntPtr minimumPeriod);
            [PreserveSig] int SetProcessingPeriod(string deviceId, IntPtr period);
            [PreserveSig] int GetShareMode(string deviceId, IntPtr mode);
            [PreserveSig] int SetShareMode(string deviceId, IntPtr mode);
            [PreserveSig] int GetPropertyValue(string deviceId, bool fxStore, IntPtr key, IntPtr value);
            [PreserveSig] int SetPropertyValue(string deviceId, bool fxStore, IntPtr key, IntPtr value);
            [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string deviceId, ERole role);
            [PreserveSig] int SetEndpointVisibility(string deviceId, bool visible);
        }
    }
}
