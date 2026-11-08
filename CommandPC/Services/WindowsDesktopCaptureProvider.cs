using System;
using System.ComponentModel;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace Command.Services
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
        private static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
        private const int DESKTOPHORZRES = 118;
        private const int DESKTOPVERTRES = 117;

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

        // BitBlt não copia o cursor do mouse; sem ele o app não mostra onde o ponteiro está.
        private const int CURSOR_SHOWING = 0x00000001;
        private const uint DI_NORMAL = 0x0003;

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT { public int X; public int Y; }

        [StructLayout(LayoutKind.Sequential)]
        private struct CURSORINFO
        {
            public int cbSize;
            public int flags;
            public IntPtr hCursor;
            public POINT ptScreenPos;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct ICONINFO
        {
            public bool fIcon;
            public int xHotspot;
            public int yHotspot;
            public IntPtr hbmMask;
            public IntPtr hbmColor;
        }

        [DllImport("user32.dll")]
        private static extern bool GetCursorInfo(ref CURSORINFO pci);

        [DllImport("user32.dll")]
        private static extern bool GetIconInfo(IntPtr hIcon, out ICONINFO piconinfo);

        [DllImport("user32.dll")]
        private static extern bool DrawIconEx(IntPtr hdc, int xLeft, int yTop, IntPtr hIcon, int cxWidth, int cyWidth, uint istepIfAniCur, IntPtr hbrFlickerFreeDraw, uint diFlags);

        // Anel de contraste (branco + roxo do app) para achar o ponteiro numa tela reduzida no celular.
        private static void DrawMarker(IntPtr hdc, int cx, int cy, int radius)
        {
            using var g = Graphics.FromHdc(hdc);
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            using var outer = new Pen(Color.White, Math.Max(4, radius / 5f));
            using var inner = new Pen(Color.FromArgb(167, 139, 250), Math.Max(2, radius / 10f));
            g.DrawEllipse(outer, cx - radius, cy - radius, radius * 2, radius * 2);
            g.DrawEllipse(inner, cx - radius, cy - radius, radius * 2, radius * 2);
        }

        private static void DrawCursor(IntPtr hdc, double scaleX, double scaleY, int radius)
        {
            var ci = new CURSORINFO { cbSize = Marshal.SizeOf<CURSORINFO>() };
            if (!GetCursorInfo(ref ci) || (ci.flags & CURSOR_SHOWING) == 0 || ci.hCursor == IntPtr.Zero) return;
            if (!GetIconInfo(ci.hCursor, out var info)) return;
            try
            {
                int x = (int)Math.Round(ci.ptScreenPos.X * scaleX) - info.xHotspot;
                int y = (int)Math.Round(ci.ptScreenPos.Y * scaleY) - info.yHotspot;
                DrawMarker(hdc, x + info.xHotspot, y + info.yHotspot, radius);
                DrawIconEx(hdc, x, y, ci.hCursor, 0, 0, 0, IntPtr.Zero, DI_NORMAL);
            }
            finally
            {
                if (info.hbmMask != IntPtr.Zero) DeleteObject(info.hbmMask);
                if (info.hbmColor != IntPtr.Zero) DeleteObject(info.hbmColor);
            }
        }

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
            int capturedWidth = bounds.Width;
            int capturedHeight = bounds.Height;

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
                        // DPI-aware: Obter resolução física nativa do monitor para evitar corte de tela em escalas > 100%
                        int physWidth = GetDeviceCaps(sDC, DESKTOPHORZRES);
                        int physHeight = GetDeviceCaps(sDC, DESKTOPVERTRES);
                        if (physWidth > 0 && physHeight > 0)
                        {
                            capturedWidth = physWidth;
                            capturedHeight = physHeight;
                        }

                        IntPtr mDC = CreateCompatibleDC(sDC);
                        if (mDC == IntPtr.Zero)
                        {
                            throw new Win32Exception(Marshal.GetLastWin32Error(), "Falha ao criar DC compatível em memória.");
                        }

                        try
                        {
                            IntPtr hBmp = CreateCompatibleBitmap(sDC, capturedWidth, capturedHeight);
                            if (hBmp == IntPtr.Zero)
                            {
                                throw new Win32Exception(Marshal.GetLastWin32Error(), "Falha ao alocar bitmap GDI compatível.");
                            }

                            try
                            {
                                IntPtr old = SelectObject(mDC, hBmp);
                                bool ok = BitBlt(mDC, 0, 0, capturedWidth, capturedHeight, sDC, 0, 0, SRCCOPY);
                                int bitBltErr = Marshal.GetLastWin32Error();
                                // Processo sem DPI-awareness lê o cursor em coordenadas lógicas.
                                if (ok) DrawCursor(mDC, (double)capturedWidth / bounds.Width, (double)capturedHeight / bounds.Height, Math.Max(24, capturedHeight / 45));
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

            width = capturedWidth;
            height = capturedHeight;
            return result;
        }
    }
}
