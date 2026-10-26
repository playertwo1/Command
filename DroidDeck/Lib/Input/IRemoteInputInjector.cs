namespace DroidDeck.Lib.Input
{
    public enum MouseButton
    {
        Left,
        Right,
        Middle
    }

    public enum MouseAction
    {
        Click,
        DoubleClick,
        Down,
        Up
    }

    public interface IRemoteInputInjector
    {
        void SendMouseMove(int dx, int dy);
        void SendMouseButton(MouseButton button, MouseAction action);
        void SendMouseScroll(int deltaX, int deltaY);
        void SendKey(string normalizedSequence);
        void SendText(string text);
    }
}
