namespace Command.Services
{
    public enum DesktopSessionState
    {
        Ready,
        SessionLocked,
        SecureDesktop,
        NotInteractive
    }

    public interface IDesktopCaptureProvider
    {
        DesktopSessionState CheckSessionState();
        byte[] CapturePrimaryScreen(out int width, out int height);
    }
}
