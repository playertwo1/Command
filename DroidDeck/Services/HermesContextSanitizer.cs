using System;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using DroidDeck.Models;

namespace DroidDeck.Services
{
    /// <summary>
    /// Sanitizador de contexto e telemetria para o módulo Hermes IA.
    /// Remove dados pessoais, caminhos locais de usuários, IPs privados e tokens sensíveis antes de qualquer processamento por IA.
    /// </summary>
    public static class HermesContextSanitizer
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

        /// <summary>
        /// Gera resumo textual limpo e sanitizado das métricas de telemetria e processos.
        /// </summary>
        public static string BuildSanitizedTelemetryContext(SystemStats? stats, TopProcessesResponseDto? topProcesses)
        {
            var inv = CultureInfo.InvariantCulture;
            var sb = new StringBuilder();
            sb.AppendLine("=== TELEMETRIA DO SISTEMA ===");

            if (stats != null)
            {
                sb.AppendLine($"- CPU: {stats.CpuUsage.ToString("F1", inv)}%");
                if (stats.CpuTempC.HasValue)
                {
                    sb.AppendLine($"- Temp CPU: {stats.CpuTempC.Value.ToString("F1", inv)} °C");
                }

                sb.AppendLine($"- RAM: {stats.RamUsage.ToString("F1", inv)}% (Disponível: {stats.RamAvailable.ToString("F0", inv)} MB / Total: {stats.RamTotal.ToString("F0", inv)} MB)");

                if (stats.GpuUsage > 0)
                {
                    sb.AppendLine($"- GPU: {stats.GpuUsage.ToString("F1", inv)}%");
                }

                if (stats.GpuTempC.HasValue)
                {
                    sb.AppendLine($"- Temp GPU: {stats.GpuTempC.Value.ToString("F1", inv)} °C");
                }

                if (stats.HasBattery && stats.BatteryPercent.HasValue)
                {
                    string charging = stats.IsCharging == true ? " (Carregando)" : "";
                    sb.AppendLine($"- Bateria: {stats.BatteryPercent.Value}%{charging}");
                }

                if (stats.Disks != null && stats.Disks.Count > 0)
                {
                    sb.AppendLine("- Discos:");
                    foreach (var disk in stats.Disks)
                    {
                        sb.AppendLine($"  * {disk.Name} ({disk.Label}): {disk.UsagePercent.ToString("F1", inv)}% usado ({disk.AvailableGB.ToString("F1", inv)} GB livres de {disk.TotalGB.ToString("F1", inv)} GB)");
                    }
                }
            }
            else
            {
                sb.AppendLine("- Métricas de hardware não disponíveis.");
            }

            if (topProcesses != null)
            {
                if (topProcesses.ByCpu != null && topProcesses.ByCpu.Count > 0)
                {
                    sb.AppendLine("- Top Processos por CPU:");
                    foreach (var p in topProcesses.ByCpu.Take(5))
                    {
                        string cpu = p.CpuPercent.HasValue ? p.CpuPercent.Value.ToString("F1", inv) : "N/A";
                        sb.AppendLine($"  * {SanitizeText(p.Name)} (PID: {p.Pid}): {cpu}% CPU, {p.MemoryMB.ToString("F1", inv)} MB RAM");
                    }
                }

                if (topProcesses.ByMemory != null && topProcesses.ByMemory.Count > 0)
                {
                    sb.AppendLine("- Top Processos por RAM:");
                    foreach (var p in topProcesses.ByMemory.Take(5))
                    {
                        sb.AppendLine($"  * {SanitizeText(p.Name)} (PID: {p.Pid}): {p.MemoryMB.ToString("F1", inv)} MB RAM");
                    }
                }
            }

            return SanitizeText(sb.ToString().TrimEnd());
        }
    }
}
