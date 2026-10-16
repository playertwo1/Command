using System;
using System.Diagnostics;

namespace DroidDeck.Lib
{
    /// <summary>
    /// Regras de entrada no Firewall do Windows para a API (TCP) e o discovery (UDP).
    ///
    /// Sem elas o aviso do Windows aparece no primeiro uso e, se o usuario fechar ou a rede
    /// estiver marcada como Publica, o celular recebe timeout -- a causa mais comum de "nao
    /// conecta". As regras valem so para a sub-rede local (remoteip=localsubnet), em qualquer
    /// perfil de rede: redes de casa marcadas como Publica continuam funcionando, sem abrir
    /// as portas para fora da LAN.
    /// </summary>
    public static class FirewallSetup
    {
        public const int DiscoveryPort = 7573;

        private static string TcpRule => $"DroidDeck (TCP {PairingInfo.Port})";
        private static string UdpRule => $"DroidDeck discovery (UDP {DiscoveryPort})";

        /// <summary>As duas regras ja existem? Consultar nao exige administrador.</summary>
        public static bool RulesExist() => RuleExists(TcpRule) && RuleExists(UdpRule);

        private static bool RuleExists(string name)
        {
            try
            {
                using var p = Process.Start(new ProcessStartInfo("netsh",
                    $"advfirewall firewall show rule name=\"{name}\"")
                {
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                });
                if (p == null) return false;
                p.StandardOutput.ReadToEnd();
                p.WaitForExit(5000);
                return p.ExitCode == 0;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// Cria (ou recria) as regras. Pede elevacao (UAC); devolve false se o usuario
        /// recusar ou algo falhar.
        /// </summary>
        public static bool AddRules()
        {
            var commands = string.Join(" & ",
                Delete(TcpRule), Delete(UdpRule),
                Add(TcpRule, "TCP", PairingInfo.Port),
                Add(UdpRule, "UDP", DiscoveryPort));
            return RunElevated(commands);
        }

        /// <summary>Remove as regras (desinstalacao). Tambem pede elevacao.</summary>
        public static bool RemoveRules() => RunElevated(string.Join(" & ", Delete(TcpRule), Delete(UdpRule)));

        private static string Delete(string name) =>
            $"netsh advfirewall firewall delete rule name=\"{name}\" >nul 2>&1";

        private static string Add(string name, string protocol, int port) =>
            $"netsh advfirewall firewall add rule name=\"{name}\" dir=in action=allow " +
            $"protocol={protocol} localport={port} remoteip=localsubnet profile=any";

        private static bool RunElevated(string commands)
        {
            try
            {
                using var p = Process.Start(new ProcessStartInfo("cmd.exe", $"/c {commands}")
                {
                    UseShellExecute = true,
                    Verb = "runas",
                    WindowStyle = ProcessWindowStyle.Hidden,
                });
                if (p == null) return false;
                p.WaitForExit(30000);
                return RulesExistAfter(commands);
            }
            catch (Exception ex)
            {
                // ERROR_CANCELLED (1223): o usuario recusou o UAC.
                Log.Info($"Firewall: elevacao recusada ou falhou ({ex.Message})");
                return false;
            }
        }

        private static bool RulesExistAfter(string commands) =>
            commands.Contains(" add rule") ? RulesExist() : !RuleExists(TcpRule);
    }
}
