using System;
using System.Text.RegularExpressions;

namespace Command.Services
{
    /// <summary>
    /// Sanitiza texto livre antes de enviá-lo a serviços de notificação externos.
    /// Remove caminhos de usuário, IPs privados e tokens sensíveis.
    /// </summary>
    public static class SensitiveTextSanitizer
    {
        // 1. Substitui caminhos de usuário no Windows (ex: C:\Users\notefael) por C:\Users\[REDACTED]
        private static readonly Regex UserPathRegex = new(
            @"(?i)[a-zA-Z]:[\\/]Users[\\/][^\s\\/""',;]+",
            RegexOptions.Compiled);

        // 1b. Fallback para Users\nome_usuario relativo
        private static readonly Regex RelativeUserPathRegex = new(
            @"(?i)(?<![a-zA-Z]:[\\/])\bUsers[\\/][^\s\\/""',;]+",
            RegexOptions.Compiled);

        // 2. Mascara IPs IPv4 privados: 10.x.y.z, 192.168.x.y, 172.16.x.y a 172.31.x.y
        private static readonly Regex PrivateIpRegex = new(
            @"\b(?:10(?:\.\d{1,3}){3}|192\.168(?:\.\d{1,3}){2}|172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})\b",
            RegexOptions.Compiled);

        // 3. Mascara tokens de API / Bearer: sk-..., AIza..., Bearer ...
        private static readonly Regex ApiKeyOrBearerRegex = new(
            @"(?i)\b(?:Bearer(?:\s+|:\s*)[A-Za-z0-9_\-\.]+|sk-[A-Za-z0-9_\-]+|AIza[A-Za-z0-9_\-]+)\b",
            RegexOptions.Compiled);

        public const string RedactedUser = @"C:\Users\[REDACTED]";
        public const string RedactedIp = "xxx.xxx.*.***";
        public const string RedactedKey = "[REDACTED_KEY]";

        /// <summary>
        /// Sanitiza texto livre removendo caminhos de perfil de usuário, IPs privados e chaves de API/Bearer tokens.
        /// </summary>
        public static string SanitizeText(string? input)
        {
            if (string.IsNullOrEmpty(input))
            {
                return string.Empty;
            }

            // Sanitiza caminhos de usuário absolutos
            string sanitized = UserPathRegex.Replace(input, RedactedUser);

            // Sanitiza caminhos de usuário relativos
            sanitized = RelativeUserPathRegex.Replace(sanitized, @"Users\[REDACTED]");

            // Sanitiza IPs privados
            sanitized = PrivateIpRegex.Replace(sanitized, RedactedIp);

            // Sanitiza tokens e chaves de API
            sanitized = ApiKeyOrBearerRegex.Replace(sanitized, RedactedKey);

            return sanitized;
        }

    }
}
