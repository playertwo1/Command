using System;
using System.Collections.Generic;
using System.Text;

namespace DroidDeck.Lib.Input
{
    /// <summary>
    /// Allowlist estrita para entrada remota de teclado.
    /// Impede execução arbitrária, comandos de terminal ou sequências desconhecidas.
    /// Normaliza para a sintaxe aceita por KeySequence.Parse.
    /// </summary>
    public static class KeyAllowlist
    {
        private static readonly Dictionary<string, string> NamedKeys = new(StringComparer.OrdinalIgnoreCase)
        {
            ["ESC"] = "{ESC}",
            ["ESCAPE"] = "{ESC}",
            ["TAB"] = "{TAB}",
            ["ENTER"] = "{ENTER}",
            ["RETURN"] = "{ENTER}",
            ["BACKSPACE"] = "{BS}",
            ["BS"] = "{BS}",
            ["BKSP"] = "{BS}",
            ["SPACE"] = "{SPACE}",
            ["DELETE"] = "{DELETE}",
            ["DEL"] = "{DELETE}",
            ["INSERT"] = "{INSERT}",
            ["INS"] = "{INSERT}",
            ["HOME"] = "{HOME}",
            ["END"] = "{END}",
            ["PGUP"] = "{PGUP}",
            ["PAGEUP"] = "{PGUP}",
            ["PGDN"] = "{PGDN}",
            ["PAGEDOWN"] = "{PGDN}",
            ["UP"] = "{UP}",
            ["DOWN"] = "{DOWN}",
            ["LEFT"] = "{LEFT}",
            ["RIGHT"] = "{RIGHT}",
            ["WIN"] = "{WIN}",
            ["LWIN"] = "{WIN}",
            ["RWIN"] = "{WIN}",
            ["APPS"] = "{APPS}",
            ["PRTSC"] = "{PRTSC}",
            ["PRINTSCREEN"] = "{PRTSC}",
        };

        static KeyAllowlist()
        {
            for (int i = 1; i <= 12; i++)
            {
                NamedKeys["F" + i] = "{F" + i + "}";
            }
        }

        public static bool TryNormalizeAndValidate(string? input, out string normalizedSequence, out string? failureReason)
        {
            normalizedSequence = string.Empty;
            failureReason = null;

            if (string.IsNullOrWhiteSpace(input))
            {
                failureReason = "KEY_EMPTY";
                return false;
            }

            string raw = input.Trim();

            // Bloquear caracteres de controle, comandos, redirecionamento ou shell injection
            if (raw.IndexOfAny(new[] { ';', '&', '|', '`', '$', '<', '>', '"', '\'', '\n', '\r', '\0' }) >= 0)
            {
                failureReason = "INVALID_CHARACTERS";
                return false;
            }

            // Se for tecla nomeada direta (ex: "Enter", "Esc", "F5")
            if (NamedKeys.TryGetValue(raw, out var mappedDirect))
            {
                normalizedSequence = mappedDirect;
                return true;
            }

            // Se contiver modificadores separados por '+' (ex: "Ctrl+C", "Alt+Tab", "Win+D", "Ctrl+Shift+Esc")
            var parts = raw.Split('+', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 0)
            {
                failureReason = "KEY_EMPTY";
                return false;
            }

            if (parts.Length == 1)
            {
                // Caractere único alfanumérico ou pontuação segura
                if (parts[0].Length == 1 && IsSafeSingleChar(parts[0][0]))
                {
                    normalizedSequence = parts[0];
                    return true;
                }

                failureReason = "KEY_NOT_IN_ALLOWLIST";
                return false;
            }

            // Última parte é a tecla base; anteriores são modificadores
            string baseKey = parts[^1];
            var modifiers = new StringBuilder();

            for (int i = 0; i < parts.Length - 1; i++)
            {
                string mod = parts[i].ToLowerInvariant();
                switch (mod)
                {
                    case "ctrl":
                    case "control":
                        modifiers.Append('^');
                        break;
                    case "alt":
                        modifiers.Append('%');
                        break;
                    case "shift":
                        modifiers.Append('+');
                        break;
                    case "win":
                    case "windows":
                    case "meta":
                        modifiers.Append('#');
                        break;
                    default:
                        failureReason = $"UNKNOWN_MODIFIER_{parts[i]}";
                        return false;
                }
            }

            string normalizedBase;
            if (NamedKeys.TryGetValue(baseKey, out var mappedBase))
            {
                normalizedBase = mappedBase;
            }
            else if (baseKey.Length == 1 && IsSafeSingleChar(baseKey[0]))
            {
                normalizedBase = baseKey.ToLowerInvariant();
            }
            else
            {
                failureReason = "KEY_NOT_IN_ALLOWLIST";
                return false;
            }

            normalizedSequence = modifiers.ToString() + normalizedBase;
            return true;
        }

        private static bool IsSafeSingleChar(char c) =>
            char.IsAsciiLetterOrDigit(c) || c is '-' or '=' or '[' or ']' or '\\' or '/' or ',' or '.' or '`';
    }
}
