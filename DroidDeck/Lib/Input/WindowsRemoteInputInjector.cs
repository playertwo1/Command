using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Threading;

namespace DroidDeck.Lib.Input
{
    public class WindowsRemoteInputInjector : IRemoteInputInjector
    {
        private const uint INPUT_MOUSE = 0;
        private const uint MOUSEEVENTF_MOVE = 0x0001;
        private const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
        private const uint MOUSEEVENTF_LEFTUP = 0x0004;
        private const uint MOUSEEVENTF_RIGHTDOWN = 0x0008;
        private const uint MOUSEEVENTF_RIGHTUP = 0x0010;
        private const uint MOUSEEVENTF_MIDDLEDOWN = 0x0020;
        private const uint MOUSEEVENTF_MIDDLEUP = 0x0040;
        private const uint MOUSEEVENTF_WHEEL = 0x0800;
        private const uint MOUSEEVENTF_HWHEEL = 0x1000;
        private const uint MOUSEEVENTF_ABSOLUTE = 0x8000;

        [StructLayout(LayoutKind.Sequential)]
        private struct MOUSEINPUT
        {
            public int dx;
            public int dy;
            public uint mouseData;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct KEYBDINPUT
        {
            public ushort wVk;
            public ushort wScan;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Explicit)]
        private struct InputUnion
        {
            [FieldOffset(0)] public MOUSEINPUT mi;
            [FieldOffset(0)] public KEYBDINPUT ki;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct INPUT
        {
            public uint type;
            public InputUnion u;
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

        public void SendMouseMove(int dx, int dy)
        {
            if (!OperatingSystem.IsWindows()) return;

            var input = new INPUT
            {
                type = INPUT_MOUSE,
                u = new InputUnion
                {
                    mi = new MOUSEINPUT
                    {
                        dx = dx,
                        dy = dy,
                        dwFlags = MOUSEEVENTF_MOVE
                    }
                }
            };
            Dispatch(new[] { input });
        }

        public void SendMouseButton(MouseButton button, MouseAction action)
        {
            if (!OperatingSystem.IsWindows()) return;

            uint downFlag = button switch
            {
                MouseButton.Right => MOUSEEVENTF_RIGHTDOWN,
                MouseButton.Middle => MOUSEEVENTF_MIDDLEDOWN,
                _ => MOUSEEVENTF_LEFTDOWN
            };

            uint upFlag = button switch
            {
                MouseButton.Right => MOUSEEVENTF_RIGHTUP,
                MouseButton.Middle => MOUSEEVENTF_MIDDLEUP,
                _ => MOUSEEVENTF_LEFTUP
            };

            switch (action)
            {
                case MouseAction.Down:
                    Dispatch(new[] { MakeMouseInput(downFlag) });
                    break;
                case MouseAction.Up:
                    Dispatch(new[] { MakeMouseInput(upFlag) });
                    break;
                case MouseAction.DoubleClick:
                    Dispatch(new[] { MakeMouseInput(downFlag), MakeMouseInput(upFlag) });
                    Thread.Sleep(20);
                    Dispatch(new[] { MakeMouseInput(downFlag), MakeMouseInput(upFlag) });
                    break;
                case MouseAction.Click:
                default:
                    Dispatch(new[] { MakeMouseInput(downFlag), MakeMouseInput(upFlag) });
                    break;
            }
        }

        public void SendMouseClickAt(MouseButton button, MouseAction action, double normalizedX, double normalizedY)
        {
            if (!OperatingSystem.IsWindows()) return;

            normalizedX = Math.Clamp(normalizedX, 0.0, 1.0);
            normalizedY = Math.Clamp(normalizedY, 0.0, 1.0);

            int absX = (int)Math.Round(normalizedX * 65535.0);
            int absY = (int)Math.Round(normalizedY * 65535.0);

            var moveInput = new INPUT
            {
                type = INPUT_MOUSE,
                u = new InputUnion
                {
                    mi = new MOUSEINPUT
                    {
                        dx = absX,
                        dy = absY,
                        dwFlags = MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE
                    }
                }
            };

            uint downFlag = button switch
            {
                MouseButton.Right => MOUSEEVENTF_RIGHTDOWN,
                MouseButton.Middle => MOUSEEVENTF_MIDDLEDOWN,
                _ => MOUSEEVENTF_LEFTDOWN
            };

            uint upFlag = button switch
            {
                MouseButton.Right => MOUSEEVENTF_RIGHTUP,
                MouseButton.Middle => MOUSEEVENTF_MIDDLEUP,
                _ => MOUSEEVENTF_LEFTUP
            };

            var inputs = new List<INPUT>(5) { moveInput };
            switch (action)
            {
                case MouseAction.Down:
                    inputs.Add(MakeMouseInput(downFlag));
                    break;
                case MouseAction.Up:
                    inputs.Add(MakeMouseInput(upFlag));
                    break;
                case MouseAction.DoubleClick:
                    inputs.Add(MakeMouseInput(downFlag));
                    inputs.Add(MakeMouseInput(upFlag));
                    inputs.Add(MakeMouseInput(downFlag));
                    inputs.Add(MakeMouseInput(upFlag));
                    break;
                case MouseAction.Click:
                default:
                    inputs.Add(MakeMouseInput(downFlag));
                    inputs.Add(MakeMouseInput(upFlag));
                    break;
            }

            Dispatch(inputs.ToArray());
        }

        public void SendMouseScroll(int deltaX, int deltaY)
        {
            if (!OperatingSystem.IsWindows()) return;

            var inputs = new List<INPUT>(2);
            if (deltaY != 0)
            {
                inputs.Add(new INPUT
                {
                    type = INPUT_MOUSE,
                    u = new InputUnion
                    {
                        mi = new MOUSEINPUT
                        {
                            mouseData = (uint)deltaY,
                            dwFlags = MOUSEEVENTF_WHEEL
                        }
                    }
                });
            }

            if (deltaX != 0)
            {
                inputs.Add(new INPUT
                {
                    type = INPUT_MOUSE,
                    u = new InputUnion
                    {
                        mi = new MOUSEINPUT
                        {
                            mouseData = (uint)deltaX,
                            dwFlags = MOUSEEVENTF_HWHEEL
                        }
                    }
                });
            }

            if (inputs.Count > 0)
            {
                Dispatch(inputs.ToArray());
            }
        }

        public void SendKey(string normalizedSequence)
        {
            if (!OperatingSystem.IsWindows() || string.IsNullOrEmpty(normalizedSequence)) return;

            var strokes = KeySequence.Parse(normalizedSequence);
            KeyboardInput.Send(strokes);
        }

        public void SendText(string text)
        {
            if (!OperatingSystem.IsWindows() || string.IsNullOrEmpty(text)) return;

            var strokes = new List<KeyStroke>(text.Length);
            foreach (char c in text)
            {
                strokes.Add(KeyStroke.ForChar(KeyModifiers.None, c));
            }
            KeyboardInput.Send(strokes);
        }

        private static INPUT MakeMouseInput(uint flags) => new()
        {
            type = INPUT_MOUSE,
            u = new InputUnion
            {
                mi = new MOUSEINPUT { dwFlags = flags }
            }
        };

        private static void Dispatch(INPUT[] inputs)
        {
            if (inputs.Length == 0) return;
            uint sent = SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>());
            if (sent != inputs.Length)
            {
                // Janelas elevadas ou desktop bloqueado podem descartar
                int err = Marshal.GetLastWin32Error();
                if (err != 0)
                {
                    throw new Win32Exception(err, "SendInput falhou.");
                }
            }
        }
    }
}
