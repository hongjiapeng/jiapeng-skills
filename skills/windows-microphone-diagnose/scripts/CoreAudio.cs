using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Threading;

namespace PersonalMicrophone {
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] internal class EnumeratorClass { }
    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IEnumerator {
        [PreserveSig] int EnumAudioEndpoints(int flow, uint states, out ICollection devices);
        [PreserveSig] int GetDefaultAudioEndpoint(int flow, int role, out IDevice device);
        [PreserveSig] int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string id, out IDevice device);
    }
    [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface ICollection {
        [PreserveSig] int GetCount(out uint count);
        [PreserveSig] int Item(uint index, out IDevice device);
    }
    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IDevice {
        [PreserveSig] int Activate(ref Guid iid, uint context, IntPtr parameters, [MarshalAs(UnmanagedType.IUnknown)] out object value);
        [PreserveSig] int OpenPropertyStore(int access, out IntPtr store);
        [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
        [PreserveSig] int GetState(out uint state);
    }
    [ComImport, Guid("1BE09788-6894-4089-8586-9A2A6C265AC5"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IEndpoint { [PreserveSig] int GetDataFlow(out int flow); }
    [ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IVolume {
        [PreserveSig] int RegisterControlChangeNotify(IntPtr callback);
        [PreserveSig] int UnregisterControlChangeNotify(IntPtr callback);
        [PreserveSig] int GetChannelCount(out uint count);
        [PreserveSig] int SetMasterVolumeLevel(float db, ref Guid context);
        [PreserveSig] int SetMasterVolumeLevelScalar(float scalar, ref Guid context);
        [PreserveSig] int GetMasterVolumeLevel(out float db);
        [PreserveSig] int GetMasterVolumeLevelScalar(out float scalar);
        [PreserveSig] int SetChannelVolumeLevel(uint channel, float db, ref Guid context);
        [PreserveSig] int SetChannelVolumeLevelScalar(uint channel, float scalar, ref Guid context);
        [PreserveSig] int GetChannelVolumeLevel(uint channel, out float db);
        [PreserveSig] int GetChannelVolumeLevelScalar(uint channel, out float scalar);
        [PreserveSig] int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, ref Guid context);
        [PreserveSig] int GetMute([MarshalAs(UnmanagedType.Bool)] out bool mute);
    }
    [ComImport, Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMeter {
        [PreserveSig] int GetPeakValue(out float peak);
        [PreserveSig] int GetMeteringChannelCount(out uint count);
        [PreserveSig] int GetChannelsPeakValues(uint count, IntPtr peaks);
        [PreserveSig] int QueryHardwareSupport(out uint support);
    }
    [ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")] internal class PolicyClass { }
    // Undocumented ABI. Preserve all slots; only call the last two methods.
    [ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IPolicy {
        [PreserveSig] int GetMixFormat([MarshalAs(UnmanagedType.LPWStr)] string id, IntPtr format);
        [PreserveSig] int GetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string id, int defaultFormat, IntPtr format);
        [PreserveSig] int ResetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string id);
        [PreserveSig] int SetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string id, IntPtr endpointFormat, IntPtr mixFormat);
        [PreserveSig] int GetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string id, int defaultPeriod, IntPtr period, IntPtr minimum);
        [PreserveSig] int SetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string id, IntPtr period);
        [PreserveSig] int GetShareMode([MarshalAs(UnmanagedType.LPWStr)] string id, IntPtr mode);
        [PreserveSig] int SetShareMode([MarshalAs(UnmanagedType.LPWStr)] string id, IntPtr mode);
        [PreserveSig] int GetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string id, int fxStore, IntPtr key, IntPtr value);
        [PreserveSig] int SetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string id, int fxStore, IntPtr key, IntPtr value);
        [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role);
        [PreserveSig] int SetEndpointVisibility([MarshalAs(UnmanagedType.LPWStr)] string id, [MarshalAs(UnmanagedType.Bool)] bool visible);
    }
    public class EndpointInfo {
        public string id; public uint state; public string stateLabel;
        public float? volumePercent; public bool? muted; public string controlError;
    }
    public class DefaultInfo { public string role; public string id; public string hresult; }
    public class Snapshot { public EndpointInfo[] endpoints; public DefaultInfo[] defaults; }
    public class ProbeInfo {
        public string id; public int seconds; public int samples; public float peak; public bool signalObserved;
        public string interpretation = "Meter activity only; no capture stream is opened and no speech is recorded.";
    }
    public static class Audio {
        private static readonly string[] Roles = { "console", "multimedia", "communications" };
        private static void Release(object value) {
            if (value != null && Marshal.IsComObject(value)) Marshal.ReleaseComObject(value);
        }
        private static int Check(int hr, string operation) {
            if (hr < 0) throw new COMException(operation + " failed (0x" + hr.ToString("X8") + ").", hr);
            return hr;
        }
        private static string Label(uint state) {
            switch (state) { case 1: return "active"; case 2: return "disabled"; case 4: return "not-present"; case 8: return "unplugged"; default: return "unknown"; }
        }
        private static IDevice Capture(IEnumerator enumerator, string id) {
            IDevice device; Check(enumerator.GetDevice(id, out device), "GetDevice");
            try {
                int flow; Check(((IEndpoint)device).GetDataFlow(out flow), "GetDataFlow");
                if (flow != 1) throw new ArgumentException("Target must be a recording/capture endpoint.");
                return device;
            } catch { Release(device); throw; }
        }
        private static object Activate(IDevice device, Type type) {
            Guid iid = type.GUID; object value;
            Check(device.Activate(ref iid, 23, IntPtr.Zero, out value), "Activate " + type.Name); return value;
        }
        private static EndpointInfo Describe(IDevice device) {
            EndpointInfo info = new EndpointInfo();
            Check(device.GetId(out info.id), "GetId"); Check(device.GetState(out info.state), "GetState");
            info.stateLabel = Label(info.state);
            if (info.state == 1) {
                object control = null;
                try {
                    control = Activate(device, typeof(IVolume)); float volume; bool muted;
                    Check(((IVolume)control).GetMasterVolumeLevelScalar(out volume), "GetVolume");
                    Check(((IVolume)control).GetMute(out muted), "GetMute");
                    info.volumePercent = volume * 100; info.muted = muted;
                } catch (Exception ex) { info.controlError = ex.Message; } finally { Release(control); }
            }
            return info;
        }
        public static Snapshot Read() {
            IEnumerator enumerator = null; ICollection collection = null;
            try {
                enumerator = (IEnumerator)new EnumeratorClass(); Check(enumerator.EnumAudioEndpoints(1, 15, out collection), "EnumAudioEndpoints");
                uint count; Check(collection.GetCount(out count), "GetCount"); List<EndpointInfo> endpoints = new List<EndpointInfo>();
                for (uint i = 0; i < count; i++) {
                    IDevice device = null;
                    try { Check(collection.Item(i, out device), "Item"); endpoints.Add(Describe(device)); } finally { Release(device); }
                }
                List<DefaultInfo> defaults = new List<DefaultInfo>();
                for (int role = 0; role < 3; role++) {
                    IDevice device = null;
                    try {
                        DefaultInfo info = new DefaultInfo(); info.role = Roles[role];
                        int hr = enumerator.GetDefaultAudioEndpoint(1, role, out device); info.hresult = "0x" + hr.ToString("X8");
                        if (hr >= 0) Check(device.GetId(out info.id), "Default GetId"); defaults.Add(info);
                    } finally { Release(device); }
                }
                return new Snapshot { endpoints = endpoints.ToArray(), defaults = defaults.ToArray() };
            } finally { Release(collection); Release(enumerator); }
        }
        public static int Enable(string id) {
            IEnumerator enumerator = null; IDevice device = null; object policy = null;
            try {
                enumerator = (IEnumerator)new EnumeratorClass(); device = Capture(enumerator, id);
                uint state; Check(device.GetState(out state), "GetState");
                if (state != 1 && state != 2) throw new InvalidOperationException("Check connection/driver first; target must be active or disabled.");
                policy = new PolicyClass(); return Check(((IPolicy)policy).SetEndpointVisibility(id, true), "SetEndpointVisibility");
            } finally { Release(policy); Release(device); Release(enumerator); }
        }
        public static int SetDefault(string id, int role) {
            if (role < 0 || role > 2) throw new ArgumentOutOfRangeException("role");
            IEnumerator enumerator = null; IDevice device = null; object policy = null;
            try {
                enumerator = (IEnumerator)new EnumeratorClass(); device = Capture(enumerator, id);
                uint state; Check(device.GetState(out state), "GetState"); if (state != 1) throw new InvalidOperationException("Target must be active.");
                policy = new PolicyClass(); return Check(((IPolicy)policy).SetDefaultEndpoint(id, role), "SetDefaultEndpoint " + Roles[role]);
            } finally { Release(policy); Release(device); Release(enumerator); }
        }
        public static int SetInput(string id, bool unmute, float volumePercent) {
            IEnumerator enumerator = null; IDevice device = null; object control = null;
            try {
                if (!unmute && (float.IsNaN(volumePercent) || volumePercent < 0 || volumePercent > 100)) throw new ArgumentOutOfRangeException("volumePercent");
                enumerator = (IEnumerator)new EnumeratorClass(); device = Capture(enumerator, id);
                uint state; Check(device.GetState(out state), "GetState"); if (state != 1) throw new InvalidOperationException("Target must be active.");
                control = Activate(device, typeof(IVolume)); Guid context = Guid.Empty;
                if (unmute) return Check(((IVolume)control).SetMute(false, ref context), "SetMute");
                return Check(((IVolume)control).SetMasterVolumeLevelScalar(volumePercent / 100, ref context), "SetVolume");
            } finally { Release(control); Release(device); Release(enumerator); }
        }
        public static ProbeInfo Probe(string id, int seconds) {
            if (seconds < 1 || seconds > 30) throw new ArgumentOutOfRangeException("seconds");
            IEnumerator enumerator = null; IDevice device = null; object meter = null;
            try {
                enumerator = (IEnumerator)new EnumeratorClass(); device = Capture(enumerator, id);
                uint state; Check(device.GetState(out state), "GetState"); if (state != 1) throw new InvalidOperationException("Target must be active.");
                meter = Activate(device, typeof(IMeter)); ProbeInfo result = new ProbeInfo { id = id, seconds = seconds };
                for (int i = 0; i < seconds * 10; i++) {
                    float peak; Check(((IMeter)meter).GetPeakValue(out peak), "GetPeakValue");
                    result.peak = Math.Max(result.peak, peak); result.samples++; Thread.Sleep(100);
                }
                result.signalObserved = result.peak > 0; return result;
            } finally { Release(meter); Release(device); Release(enumerator); }
        }
    }
}
