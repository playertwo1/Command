using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using DroidDeck.Models;

namespace DroidDeck.Lib.Input
{
    /// <summary>
    /// Grava o que se digita no PC (hook de teclado de baixo nivel) e transforma em passos de
    /// multi-acao: teclas digitadas em sequencia viram um passo de atalho; uma pausa maior
    /// que <see cref="PauseMs"/> vira a espera do passo seguinte.
    ///
    /// Le o teclado inteiro enquanto grava, entao so pode ser ligado pelo configurador no
    /// proprio PC, e desliga sozinho depois de <see cref="MaxDuration"/>.
    /// </summary>
    public sealed class MacroRecorder : IDisposable
    {
        public static readonly TimeSpan MaxDuration = TimeSpan.FromSeconds(60);
        public const int PauseMs = 600;

        public readonly record struct KeyEvent(ushort Vk, KeyModifiers Modifiers, long AtMs);

        private readonly object _lock = new();
        private readonly List<KeyEvent> _events = new();
        private Thread? _thread;
        private uint _threadId;
        private Stopwatch _clock = new();
        private KeyModifiers _held;
        private LowLevelKeyboardProc? _proc; // referencia viva: o GC nao pode coletar o callback

        public bool Recording => _thread != null;

        public DateTime? StartedAt { get; private set; }

        public int Count
        {
            get { lock (_lock) return _events.Count; }
        }

        public void Start()
        {
            Stop();
            lock (_lock) _events.Clear();
            _held = KeyModifiers.None;
            _clock = Stopwatch.StartNew();
            StartedAt = DateTime.UtcNow;
            var ready = new ManualResetEventSlim();
            _thread = new Thread(() => HookLoop(ready)) { IsBackground = true, Name = "MacroRecorder" };
            _thread.Start();
            ready.Wait(TimeSpan.FromSeconds(2));
        }

        /// <summary>Para e devolve as teclas gravadas.</summary>
        public List<KeyEvent> Stop()
        {
            var thread = _thread;
            if (thread != null)
            {
                PostThreadMessage(_threadId, WM_QUIT, IntPtr.Zero, IntPtr.Zero);
                thread.Join(TimeSpan.FromSeconds(2));
                _thread = null;
            }
            StartedAt = null;
            lock (_lock) return _events.ToList();
        }

        private void HookLoop(ManualResetEventSlim ready)
        {
            _threadId = GetCurrentThreadId();
            _proc = HookCallback;
            var hook = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(null), 0);
            ready.Set();
            if (hook == IntPtr.Zero) return;
            using var timeout = new System.Threading.Timer(_ => PostThreadMessage(_threadId, WM_QUIT, IntPtr.Zero, IntPtr.Zero),
                null, MaxDuration, Timeout.InfiniteTimeSpan);
            try
            {
                while (GetMessage(out var msg, IntPtr.Zero, 0, 0) > 0)
                {
                    TranslateMessage(ref msg);
                    DispatchMessage(ref msg);
                }
            }
            finally
            {
                UnhookWindowsHookEx(hook);
                _thread = null;
            }
        }

        private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
        {
            if (nCode >= 0)
            {
                var data = Marshal.PtrToStructure<KBDLLHOOKSTRUCT>(lParam);
                var down = wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN;
                var up = wParam == (IntPtr)WM_KEYUP || wParam == (IntPtr)WM_SYSKEYUP;
                // Teclas que o proprio DroidDeck injeta (LLKHF_INJECTED) nao entram.
                if ((data.flags & 0x10) == 0 && (down || up))
                {
                    var vk = (ushort)data.vkCode;
                    var mod = ModifierOf(vk);
                    if (mod != KeyModifiers.None)
                    {
                        if (down) _held |= mod;
                        else _held &= ~mod;
                    }
                    else if (down)
                    {
                        lock (_lock) _events.Add(new KeyEvent(vk, _held, _clock.ElapsedMilliseconds));
                    }
                }
            }
            return CallNextHookEx(IntPtr.Zero, nCode, wParam, lParam);
        }

        private static KeyModifiers ModifierOf(ushort vk) => vk switch
        {
            0x10 or 0xA0 or 0xA1 => KeyModifiers.Shift,
            0x11 or 0xA2 or 0xA3 => KeyModifiers.Ctrl,
            0x12 or 0xA4 or 0xA5 => KeyModifiers.Alt,
            0x5B or 0x5C => KeyModifiers.Win,
            _ => KeyModifiers.None,
        };

        // ---- Conversao para passos ----

        private static readonly Dictionary<ushort, string> Named = new()
        {
            [0x08] = "BACKSPACE", [0x09] = "TAB", [0x0D] = "ENTER", [0x13] = "BREAK", [0x14] = "CAPSLOCK",
            [0x1B] = "ESC", [0x20] = "SPACE", [0x21] = "PGUP", [0x22] = "PGDN", [0x23] = "END", [0x24] = "HOME",
            [0x25] = "LEFT", [0x26] = "UP", [0x27] = "RIGHT", [0x28] = "DOWN", [0x2C] = "PRTSC", [0x2D] = "INSERT",
            [0x2E] = "DELETE", [0x5D] = "APPS", [0x6A] = "MULTIPLY", [0x6B] = "ADD", [0x6D] = "SUBTRACT",
            [0x6E] = "DECIMAL", [0x6F] = "DIVIDE", [0x90] = "NUMLOCK", [0x91] = "SCROLLLOCK",
            [0xAD] = "VOLUME_MUTE", [0xAE] = "VOLUME_DOWN", [0xAF] = "VOLUME_UP",
            [0xB0] = "MEDIA_NEXT", [0xB1] = "MEDIA_PREV", [0xB2] = "MEDIA_STOP", [0xB3] = "MEDIA_PLAY_PAUSE",
        };

        /// <summary>Caracteres com significado na sintaxe e que precisam de chaves: {+}.</summary>
        private const string Special = "+^%~(){}#[]";

        /// <summary>Uma tecla na sintaxe do SendKeys ("^c", "{ENTER}", "+{TAB}"). Null = tecla sem traducao.</summary>
        public static string? Token(KeyEvent e, Func<ushort, char>? charOf = null)
        {
            string? key;
            if (e.Vk is >= 0x41 and <= 0x5A) key = ((char)(e.Vk + 32)).ToString();          // A-Z -> a-z
            else if (e.Vk is >= 0x30 and <= 0x39) key = ((char)e.Vk).ToString();            // 0-9
            else if (e.Vk is >= 0x70 and <= 0x87) key = "{F" + (e.Vk - 0x6F) + "}";         // F1-F24
            else if (e.Vk is >= 0x60 and <= 0x69) key = "{NUMPAD" + (e.Vk - 0x60) + "}";
            else if (Named.TryGetValue(e.Vk, out var name)) key = "{" + name + "}";
            else
            {
                var c = (charOf ?? LayoutChar)(e.Vk);
                if (c == '\0') return null;
                key = Special.Contains(c) ? "{" + c + "}" : c.ToString();
            }
            var mods = new StringBuilder();
            if (e.Modifiers.HasFlag(KeyModifiers.Ctrl)) mods.Append('^');
            if (e.Modifiers.HasFlag(KeyModifiers.Alt)) mods.Append('%');
            if (e.Modifiers.HasFlag(KeyModifiers.Shift)) mods.Append('+');
            if (e.Modifiers.HasFlag(KeyModifiers.Win)) mods.Append('#');
            return mods + key;
        }

        /// <summary>Junta as teclas em passos de atalho, separando nas pausas.</summary>
        public static List<MultiStep> ToSteps(IReadOnlyList<KeyEvent> events, Func<ushort, char>? charOf = null)
        {
            var steps = new List<MultiStep>();
            var keys = new StringBuilder();
            long last = -1;
            var delay = 0;
            void Flush()
            {
                if (keys.Length == 0) return;
                steps.Add(new MultiStep
                {
                    Type = "hotkey",
                    Parameters = new Dictionary<string, string> { ["keys"] = keys.ToString() },
                    DelayMs = delay,
                });
                keys.Clear();
            }
            foreach (var e in events)
            {
                var token = Token(e, charOf);
                if (token == null) continue;
                if (last >= 0 && e.AtMs - last > PauseMs)
                {
                    Flush();
                    // Arredonda para 100 ms: ninguem quer "espera de 1.237 ms".
                    delay = (int)(Math.Round((e.AtMs - last) / 100.0) * 100);
                }
                keys.Append(token);
                last = e.AtMs;
            }
            Flush();
            return steps;
        }

        /// <summary>Caractere que a tecla produz sem modificadores, no layout atual (sinais, acentos).</summary>
        private static char LayoutChar(ushort vk)
        {
            var c = MapVirtualKey(vk, MAPVK_VK_TO_CHAR);
            // Bit alto = tecla morta (acento): grava o proprio acento.
            return (char)(c & 0x7FFF);
        }

        public void Dispose() => Stop();

        // ---- Win32 ----

        private const int WH_KEYBOARD_LL = 13;
        private const int WM_KEYDOWN = 0x0100, WM_KEYUP = 0x0101, WM_SYSKEYDOWN = 0x0104, WM_SYSKEYUP = 0x0105;
        private const uint WM_QUIT = 0x0012;
        private const uint MAPVK_VK_TO_CHAR = 2;

        private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

        [StructLayout(LayoutKind.Sequential)]
        private struct KBDLLHOOKSTRUCT
        {
            public uint vkCode, scanCode, flags, time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct MSG
        {
            public IntPtr hwnd;
            public uint message;
            public IntPtr wParam, lParam;
            public uint time;
            public int x, y;
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

        [DllImport("user32.dll")]
        private static extern bool UnhookWindowsHookEx(IntPtr hhk);

        [DllImport("user32.dll")]
        private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr GetModuleHandle(string? lpModuleName);

        [DllImport("user32.dll")]
        private static extern int GetMessage(out MSG lpMsg, IntPtr hWnd, uint min, uint max);

        [DllImport("user32.dll")]
        private static extern bool TranslateMessage(ref MSG lpMsg);

        [DllImport("user32.dll")]
        private static extern IntPtr DispatchMessage(ref MSG lpMsg);

        [DllImport("user32.dll")]
        private static extern bool PostThreadMessage(uint idThread, uint msg, IntPtr wParam, IntPtr lParam);

        [DllImport("kernel32.dll")]
        private static extern uint GetCurrentThreadId();

        [DllImport("user32.dll")]
        private static extern uint MapVirtualKey(uint uCode, uint uMapType);
    }
}
