using System;
using System.ComponentModel.DataAnnotations;
using Command.Lib.Input;

namespace Command.Models
{
    public sealed record MouseMoveRequest(
        [Required] double Dx,
        [Required] double Dy);

    public sealed record MouseClickRequest(
        [Required] string Button,
        string? Action = "click",
        double? NormalizedX = null,
        double? NormalizedY = null);

    public sealed record MouseScrollRequest(
        int DeltaX = 0,
        int DeltaY = 0);

    public sealed record KeyInputRequest(
        [Required] string Key);

    public sealed record TextInputRequest(
        [Required] string Text);

    public sealed class RemoteInputBatchRequest
    {
        [Required]
        public string Type { get; set; } = string.Empty;

        public double? Dx { get; set; }
        public double? Dy { get; set; }

        public string? Button { get; set; }
        public string? Action { get; set; }
        public double? NormalizedX { get; set; }
        public double? NormalizedY { get; set; }

        public int? DeltaX { get; set; }
        public int? DeltaY { get; set; }

        public string? Key { get; set; }
        public string? Text { get; set; }
    }

    public static class MouseButtonParser
    {
        public static bool TryParse(string? buttonStr, string? actionStr, out MouseButton button, out MouseAction action)
        {
            button = MouseButton.Left;
            action = MouseAction.Click;

            if (string.IsNullOrWhiteSpace(buttonStr))
                return false;

            button = buttonStr.Trim().ToLowerInvariant() switch
            {
                "left" or "1" => MouseButton.Left,
                "right" or "2" => MouseButton.Right,
                "middle" or "3" => MouseButton.Middle,
                _ => (MouseButton)(-1)
            };

            if ((int)button == -1) return false;

            if (!string.IsNullOrWhiteSpace(actionStr))
            {
                action = actionStr.Trim().ToLowerInvariant() switch
                {
                    "click" => MouseAction.Click,
                    "double_click" or "doubleclick" or "double" => MouseAction.DoubleClick,
                    "down" => MouseAction.Down,
                    "up" => MouseAction.Up,
                    _ => (MouseAction)(-1)
                };

                if ((int)action == -1) return false;
            }

            return true;
        }
    }
}
