using System;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace DroidDeck.Services
{
    public class WindowsDesktopCaptureProvider : IDesktopCaptureProvider
    {
        private const uint DESKTOP_SWITCHDESKTOP = 0x0100;
        private const int ERROR_ACCESS_DENIED = 5;
        private const uint SRCCOPY = 0x00CC0020;

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr OpenInputDesktop(uint dwFlags, bool fInherit, uint dwDesiredAccess);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool SetThreadDesktop(IntPtr hDesktop);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool CloseDesktop(IntPtr hDesktop);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr GetDC(IntPtr hWnd);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

        [DllImport("gdi32.dll", SetLastError = true)]
        private static extern IntPtr CreateCompatibleDC(IntPtr hdc);

        [DllImport("gdi32.dll", SetLastError = true)]
        private static extern IntPtr CreateCompatibleBitmap(IntPtr hdc, int nWidth, int nHeight);

        [DllImport("gdi32.dll", SetLastError = true)]
        private static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);

        [DllImport("gdi32.dll", SetLastError = true)]
        private static extern bool DeleteDC(IntPtr hdc);

        [DllImport("gdi32.dll", SetLastError = true)]
        private static extern bool DeleteObject(IntPtr hObject);

        [DllImport("gdi32.dll", SetLastError = true)]
        private static extern bool BitBlt(IntPtr hdcDest, int nXDest, int nYDest, int nWidth, int nHeight, IntPtr hdcSrc, int nXSrc, int nYSrc, uint dwRop);

        public DesktopSessionState CheckSessionState()
        {
            if (!System.OperatingSystem.IsWindows())
            {
                return DesktopSessionState.NotInteractive;
            }

            var primary = Screen.PrimaryScreen;
            if (primary == null || primary.Bounds.Width <= 0 || primary.Bounds.Height <= 0)
            {
                return DesktopSessionState.NotInteractive;
            }

            // Verifica se o desktop de entrada está acessível na sessão interativa
            IntPtr hDesktop = OpenInputDesktop(0, false, DESKTOP_SWITCHDESKTOP);
            if (hDesktop == IntPtr.Zero)
            {
                int error = Marshal.GetLastWin32Error();
                if (error == ERROR_ACCESS_DENIED)
                {
                    // Workstation locked ou Secure Desktop (UAC / Winlogon)
                    return DesktopSessionState.SessionLocked;
                }

                return DesktopSessionState.NotInteractive;
            }

            CloseDesktop(hDesktop);
            return DesktopSessionState.Ready;
        }

        public byte[] CapturePrimaryScreen(out int width, out int height)
        {
            var primary = Screen.PrimaryScreen;
            if (primary == null || primary.Bounds.Width <= 0 || primary.Bounds.Height <= 0)
            {
                throw new InvalidOperationException("Monitor principal não encontrado ou sessão não interativa.");
            }

            var bounds = primary.Bounds;
            width = bounds.Width;
            height = bounds.Height;

            // Abre o desktop de entrada com permissão de leitura
            IntPtr hDesktop = OpenInputDesktop(0, false, 0x01FF);
            if (hDesktop == IntPtr.Zero)
            {
                int err = Marshal.GetLastWin32Error();
                if (err == ERROR_ACCESS_DENIED)
                {
                    throw new InvalidOperationException("SESSION_LOCKED: Área de trabalho bloqueada ou UAC ativo.");
                }
                throw new Win32Exception(err, $"Falha ao abrir desktop de entrada: código {err}");
            }

            byte[]? result = null;
            Exception? threadEx = null;

            // Executa em thread dedicada para permitir SetThreadDesktop sem colisão com janelas ou hooks pré-existentes
            var thread = new Thread(() =>
            {
                try
                {
                    if (!SetThreadDesktop(hDesktop))
                    {
                        throw new Win32Exception(Marshal.GetLastWin32Error(), "Falha ao vincular thread ao desktop de entrada.");
                    }

                    IntPtr sDC = GetDC(IntPtr.Zero);
                    if (sDC == IntPtr.Zero)
                    {
                        throw new Win32Exception(Marshal.GetLastWin32Error(), "Falha ao obter DC do monitor.");
                    }

                    try
                    {
                        IntPtr mDC = CreateCompatibleDC(sDC);
                        if (mDC == IntPtr.Zero)
                        {
                            throw new Win32Exception(Marshal.GetLastWin32Error(), "Falha ao criar DC compatível em memória.");
                        }

                        try
                        {
                            IntPtr hBmp = CreateCompatibleBitmap(sDC, bounds.Width, bounds.Height);
                            if (hBmp == IntPtr.Zero)
                            {
                                throw new Win32Exception(Marshal.GetLastWin32Error(), "Falha ao alocar bitmap GDI compatível.");
                            }

                            try
                            {
                                IntPtr old = SelectObject(mDC, hBmp);
                                bool ok = BitBlt(mDC, 0, 0, bounds.Width, bounds.Height, sDC, bounds.Left, bounds.Top, SRCCOPY);
                                int bitBltErr = Marshal.GetLastWin32Error();
                                SelectObject(mDC, old);

                                if (!ok)
                                {
                                    throw new Win32Exception(bitBltErr, $"BitBlt falhou com código de erro {bitBltErr}.");
                                }

                                using var bmp = Image.FromHbitmap(hBmp);
                                using var ms = new MemoryStream();
                                bmp.Save(ms, ImageFormat.Jpeg);
                                result = ms.ToArray();
                            }
                            finally
                            {
                                DeleteObject(hBmp);
                            }
                        }
                        finally
                        {
                            DeleteDC(mDC);
                        }
                    }
                    finally
                    {
                        ReleaseDC(IntPtr.Zero, sDC);
                    }
                }
                catch (Exception ex)
                {
                    threadEx = ex;
                }
            })
            {
                IsBackground = true
            };

            thread.Start();
            thread.Join();
            CloseDesktop(hDesktop);

            if (threadEx != null)
            {
                throw new InvalidOperationException($"Falha de captura da API do Windows: {threadEx.Message}", threadEx);
            }

            if (result == null || result.Length == 0)
            {
                throw new InvalidOperationException("Falha ao codificar buffer de imagem capturado.");
            }

            return result;
        }
    }
}
