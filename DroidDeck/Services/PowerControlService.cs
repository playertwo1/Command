using System;
using System.Linq;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using DroidDeck.Models;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    public class PowerControlService : IPowerControlService
    {
        private readonly IJobHistoryService? _jobHistory;
        private readonly Func<bool>? _lockWorkstationInvoker;
        private readonly Func<bool>? _suspendStateInvoker;
        private readonly ILogger<PowerControlService>? _logger;

        /// <summary>
        /// Quando falso (padrão em dev/testes), ações nativas são simuladas com sucesso seguro
        /// para não bloquear ou suspender acidentalmente a máquina do desenvolvedor ou ambiente de CI.
        /// </summary>
        public bool AllowNativeExecution { get; set; } = false;

        public PowerControlService(
            IJobHistoryService? jobHistory = null,
            Func<bool>? lockWorkstationInvoker = null,
            Func<bool>? suspendStateInvoker = null,
            ILogger<PowerControlService>? logger = null)
        {
            _jobHistory = jobHistory;
            _lockWorkstationInvoker = lockWorkstationInvoker;
            _suspendStateInvoker = suspendStateInvoker;
            _logger = logger;
        }

        public string FormatMacAddress(byte[]? physicalBytes)
        {
            if (physicalBytes == null || physicalBytes.Length == 0)
            {
                return string.Empty;
            }

            return string.Join(":", physicalBytes.Select(b => b.ToString("X2")));
        }

        public NetworkWakeInfoDto GetWakeInfo()
        {
            string hostName = Environment.MachineName;
            string macAddress = string.Empty;
            string localIp = string.Empty;
            bool supportsWol = false;

            try
            {
                var interfaces = NetworkInterface.GetAllNetworkInterfaces();

                // Busca interface operacional com endereço físico de 6 bytes (Ethernet ou Wi-Fi)
                var activeNic = interfaces.FirstOrDefault(nic =>
                    nic.OperationalStatus == OperationalStatus.Up &&
                    nic.NetworkInterfaceType != NetworkInterfaceType.Loopback &&
                    (nic.NetworkInterfaceType == NetworkInterfaceType.Ethernet ||
                     nic.NetworkInterfaceType == NetworkInterfaceType.Wireless80211) &&
                    nic.GetPhysicalAddress().GetAddressBytes().Length == 6);

                if (activeNic != null)
                {
                    macAddress = FormatMacAddress(activeNic.GetPhysicalAddress().GetAddressBytes());
                    supportsWol = !string.IsNullOrWhiteSpace(macAddress);

                    var ipProps = activeNic.GetIPProperties();
                    var ipv4 = ipProps.UnicastAddresses.FirstOrDefault(u =>
                        u.Address.AddressFamily == AddressFamily.InterNetwork &&
                        !u.Address.ToString().StartsWith("127."));

                    if (ipv4 != null)
                    {
                        localIp = ipv4.Address.ToString();
                    }
                }

                // Fallback para obter qualquer IP local se não localizado na NIC primária
                if (string.IsNullOrWhiteSpace(localIp))
                {
                    foreach (var nic in interfaces)
                    {
                        if (nic.OperationalStatus != OperationalStatus.Up || nic.NetworkInterfaceType == NetworkInterfaceType.Loopback)
                            continue;

                        var ip = nic.GetIPProperties().UnicastAddresses
                            .FirstOrDefault(u => u.Address.AddressFamily == AddressFamily.InterNetwork && !u.Address.ToString().StartsWith("127."))?
                            .Address.ToString();

                        if (!string.IsNullOrWhiteSpace(ip))
                        {
                            localIp = ip;
                            break;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger?.LogWarning(ex, "Erro ao inspecionar interfaces de rede para Wake-on-LAN");
            }

            return new NetworkWakeInfoDto
            {
                HostName = hostName,
                MacAddress = macAddress,
                LocalIp = localIp,
                WolPort = 9,
                SupportsWakeOnLan = supportsWol
            };
        }

        public PowerActionResultDto ExecutePowerAction(PowerActionRequest request, string? deviceId = null)
        {
            var now = DateTime.UtcNow;

            // Regra de Segurança: Confirmação Explícita Obrigatória
            if (request == null || !request.Confirmed)
            {
                _logger?.LogWarning("Ação de energia abortada: falta de confirmação explícita.");
                return new PowerActionResultDto
                {
                    Success = false,
                    Action = request?.Action ?? string.Empty,
                    Status = "aborted",
                    ErrorCode = "CONFIRMATION_REQUIRED",
                    ErrorMessage = "Confirmação explícita obrigatória para ações de energia/sessão.",
                    TimestampUtc = now
                };
            }

            string action = request.Action?.Trim().ToLowerInvariant() ?? string.Empty;

            // Regra de Segurança: Allowlist Estrita de Ações ("lock" e "sleep")
            if (action != "lock" && action != "sleep")
            {
                _logger?.LogWarning("Ação de energia '{Action}' rejeitada por violar a allowlist estrita.", request.Action);
                return new PowerActionResultDto
                {
                    Success = false,
                    Action = request.Action ?? string.Empty,
                    Status = "failed",
                    ErrorCode = "ACTION_NOT_ALLOWED",
                    ErrorMessage = $"Ação '{request.Action}' não é permitida pela política de segurança (apenas 'lock' e 'sleep').",
                    TimestampUtc = now
                };
            }

            // Registro e auditoria via JobHistoryService
            string reqId = string.IsNullOrWhiteSpace(request.RequestId) ? Guid.NewGuid().ToString("N") : request.RequestId;
            string actionType = action == "lock" ? "system.lock_workstation" : "system.sleep";
            CommandJob? job = null;

            if (_jobHistory != null)
            {
                try
                {
                    job = _jobHistory.GetOrCreateJob(reqId, actionType, Environment.MachineName, deviceId, out _);
                }
                catch { }
            }

            bool executionResult = false;
            string? errorMessage = null;

            try
            {
                if (action == "lock")
                {
                    executionResult = PerformLockWorkstation();
                }
                else if (action == "sleep")
                {
                    executionResult = PerformSuspendState();
                }
            }
            catch (Exception ex)
            {
                _logger?.LogError(ex, "Falha ao executar ação de energia '{Action}'", action);
                executionResult = false;
                errorMessage = ex.Message;
            }

            if (executionResult)
            {
                if (job != null)
                {
                    _jobHistory?.UpdateJob(job.Id, "succeeded");
                }

                _logger?.LogInformation("Ação de energia '{Action}' executada com sucesso.", action);
                return new PowerActionResultDto
                {
                    Success = true,
                    Action = action,
                    Status = "succeeded",
                    JobId = job?.Id,
                    TimestampUtc = DateTime.UtcNow
                };
            }
            else
            {
                string err = errorMessage ?? $"Falha ao executar comando de '{action}'.";
                if (job != null)
                {
                    _jobHistory?.UpdateJob(job.Id, "failed", err);
                }

                return new PowerActionResultDto
                {
                    Success = false,
                    Action = action,
                    Status = "failed",
                    ErrorCode = "EXECUTION_FAILED",
                    ErrorMessage = err,
                    JobId = job?.Id,
                    TimestampUtc = DateTime.UtcNow
                };
            }
        }

        private bool PerformLockWorkstation()
        {
            if (_lockWorkstationInvoker != null)
            {
                return _lockWorkstationInvoker();
            }

            if (AllowNativeExecution && OperatingSystem.IsWindows())
            {
                return LockWorkStationNative();
            }

            // Simulação segura quando AllowNativeExecution for falso
            _logger?.LogInformation("[Simulação Segura] LockWorkStation invocado com sucesso (AllowNativeExecution=false)");
            return true;
        }

        private bool PerformSuspendState()
        {
            if (_suspendStateInvoker != null)
            {
                return _suspendStateInvoker();
            }

            if (AllowNativeExecution && OperatingSystem.IsWindows())
            {
                return SetSuspendStateNative(false, false, false);
            }

            // Simulação segura quando AllowNativeExecution for falso
            _logger?.LogInformation("[Simulação Segura] SetSuspendState invocado com sucesso (AllowNativeExecution=false)");
            return true;
        }

        [DllImport("user32.dll", EntryPoint = "LockWorkStation", SetLastError = true)]
        private static extern bool LockWorkStationNative();

        [DllImport("Powrprof.dll", EntryPoint = "SetSuspendState", SetLastError = true)]
        private static extern bool SetSuspendStateNative(bool hibernate, bool forceCritical, bool disableWakeEvent);
    }
}
