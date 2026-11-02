using System;
using System.Runtime.InteropServices;

namespace DroidDeck.Services
{
    /// <summary>
    /// Temperatura da GPU pelo driver já instalado. Não pede elevação.
    /// Se a DLL não existir, a leitura volta null.
    /// </summary>
    internal static class GpuThermalReader
    {
        public static float? ReadNvidia()
        {
            try
            {
                return NvidiaThermal.Read();
            }
            catch
            {
                return null;
            }
        }

        public static float? ReadAmd()
        {
            try
            {
                return AmdThermal.Read();
            }
            catch
            {
                return null;
            }
        }

        private static class NvidiaThermal
        {
            private const uint InitializeId = 0x0150E828;
            private const uint EnumPhysicalGpusId = 0xE5AC921F;
            private const uint GetThermalSettingsId = 0xE3640A56;
            private const int ThermalTargetAll = 15;

            private static readonly object Gate = new();
            private static bool _ready;
            private static InitializeDelegate? _initialize;
            private static EnumPhysicalGpusDelegate? _enumGpus;
            private static GetThermalDelegate? _getThermal;

            public static float? Read()
            {
                lock (Gate)
                {
                    if (!Ensure()) return null;
                    if (_initialize!() != 0) return null;

                    var handles = new IntPtr[64];
                    if (_enumGpus!(handles, out var count) != 0 || count == 0) return null;

                    float? best = null;
                    var limit = Math.Min(count, handles.Length);
                    for (var i = 0; i < limit; i++)
                    {
                        if (handles[i] == IntPtr.Zero) continue;
                        var settings = new NvThermalSettings
                        {
                            Version = (uint)Marshal.SizeOf<NvThermalSettings>() | (2u << 16),
                        };
                        if (_getThermal!(handles[i], ThermalTargetAll, ref settings) != 0) continue;
                        best = Hotter(best, SensorCelsius(settings.Sensor0));
                        best = Hotter(best, SensorCelsius(settings.Sensor1));
                        best = Hotter(best, SensorCelsius(settings.Sensor2));
                    }
                    return best;
                }
            }

            private static bool Ensure()
            {
                if (_ready) return _getThermal != null;
                _ready = true;
                var module = LoadLibrary("nvapi64.dll");
                if (module == IntPtr.Zero) module = LoadLibrary("nvapi.dll");
                if (module == IntPtr.Zero) return false;

                var queryPtr = GetProcAddress(module, "nvAPI_QueryInterface");
                if (queryPtr == IntPtr.Zero) queryPtr = GetProcAddress(module, "NvAPI_QueryInterface");
                if (queryPtr == IntPtr.Zero) return false;
                var query = Marshal.GetDelegateForFunctionPointer<QueryInterfaceDelegate>(queryPtr);
                _initialize = Bind<InitializeDelegate>(query, InitializeId);
                _enumGpus = Bind<EnumPhysicalGpusDelegate>(query, EnumPhysicalGpusId);
                _getThermal = Bind<GetThermalDelegate>(query, GetThermalSettingsId);
                return _initialize != null && _enumGpus != null && _getThermal != null;
            }

            private static T? Bind<T>(QueryInterfaceDelegate query, uint id) where T : Delegate
            {
                var ptr = query(id);
                return ptr == IntPtr.Zero ? null : Marshal.GetDelegateForFunctionPointer<T>(ptr);
            }

            private static float? SensorCelsius(NvSensor sensor)
            {
                if (sensor.CurrentTemp == 0 || sensor.CurrentTemp > 150) return null;
                return sensor.CurrentTemp;
            }

            private static float? Hotter(float? current, float? next)
            {
                if (next == null) return current;
                if (current == null || next > current) return next;
                return current;
            }

            [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
            private delegate IntPtr QueryInterfaceDelegate(uint id);

            [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
            private delegate int InitializeDelegate();

            [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
            private delegate int EnumPhysicalGpusDelegate(
                [Out][MarshalAs(UnmanagedType.LPArray, SizeConst = 64)] IntPtr[] gpus,
                out int count);

            [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
            private delegate int GetThermalDelegate(IntPtr gpu, int sensorIndex, ref NvThermalSettings settings);

            [StructLayout(LayoutKind.Sequential)]
            private struct NvSensor
            {
                public int Controller;
                public uint DefaultMinTemp;
                public uint DefaultMaxTemp;
                public uint CurrentTemp;
                public int Target;
            }

            [StructLayout(LayoutKind.Sequential)]
            private struct NvThermalSettings
            {
                public uint Version;
                public uint Count;
                public NvSensor Sensor0;
                public NvSensor Sensor1;
                public NvSensor Sensor2;
            }
        }

        private static class AmdThermal
        {
            private static readonly object Gate = new();
            private static readonly AllocDelegate Alloc = size => Marshal.AllocHGlobal(size);
            private static bool _ready;
            private static ControlCreateDelegate? _create;
            private static AdapterCountDelegate? _count;
            private static TemperatureDelegate? _temperature;

            public static float? Read()
            {
                lock (Gate)
                {
                    if (!Ensure()) return null;
                    if (_create!(Alloc, 1) != 0) return null;
                    if (_count!(out var adapters) != 0 || adapters <= 0) return null;

                    float? best = null;
                    var limit = Math.Min(adapters, 8);
                    for (var i = 0; i < limit; i++)
                    {
                        var reading = new AdlTemperature { Size = Marshal.SizeOf<AdlTemperature>() };
                        if (_temperature!(i, 0, ref reading) != 0) continue;
                        var celsius = ThermalScale.FromMilliCelsius(reading.Temperature);
                        if (celsius == null) continue;
                        if (best == null || celsius > best) best = celsius;
                    }
                    return best;
                }
            }

            private static bool Ensure()
            {
                if (_ready) return _temperature != null;
                _ready = true;
                var module = LoadLibrary("atiadlxx.dll");
                if (module == IntPtr.Zero) module = LoadLibrary("atiadlxy.dll");
                if (module == IntPtr.Zero) return false;

                _create = Bind<ControlCreateDelegate>(module, "ADL_Main_Control_Create");
                _count = Bind<AdapterCountDelegate>(module, "ADL_Adapter_NumberOfAdapters_Get");
                _temperature = Bind<TemperatureDelegate>(module, "ADL_Overdrive5_Temperature_Get");
                return _create != null && _count != null && _temperature != null;
            }

            private static T? Bind<T>(IntPtr module, string name) where T : Delegate
            {
                var ptr = GetProcAddress(module, name);
                return ptr == IntPtr.Zero ? null : Marshal.GetDelegateForFunctionPointer<T>(ptr);
            }

            [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
            private delegate IntPtr AllocDelegate(int size);

            [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
            private delegate int ControlCreateDelegate(AllocDelegate alloc, int connectedOnly);

            [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
            private delegate int AdapterCountDelegate(out int count);

            [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
            private delegate int TemperatureDelegate(int adapterIndex, int thermalController, ref AdlTemperature temperature);

            [StructLayout(LayoutKind.Sequential)]
            private struct AdlTemperature
            {
                public int Size;
                public int Temperature;
            }
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr LoadLibrary(string fileName);

        [DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
        private static extern IntPtr GetProcAddress(IntPtr module, string name);
    }
}
