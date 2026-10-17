using System;
using System.Collections.Generic;
using System.Linq;
using System.ServiceProcess;
using DroidDeck.Models;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Services
{
    public interface IWindowsServiceMonitor
    {
        IReadOnlyList<string> AllowedServices { get; }
        List<ServiceStatusDto> GetServicesStatus(IEnumerable<string>? filterNames = null);
    }

    /// <summary>
    /// Monitoramento somente leitura de serviços do Windows sob allowlist estrita.
    /// Não expõe nenhuma ação de inicialização, parada ou modificação de serviços.
    /// </summary>
    public class WindowsServiceMonitor : IWindowsServiceMonitor
    {
        public static readonly IReadOnlyList<string> DefaultAllowedServices = new[]
        {
            "Tailscale",
            "Spooler",
            "WSearch",
            "WinDefend",
            "docker"
        };

        private readonly ILogger<WindowsServiceMonitor> _logger;
        private readonly HashSet<string> _allowedSet;
        private readonly object _cacheLock = new();
        private Dictionary<string, ServiceStatusDto> _statusCache = new(StringComparer.OrdinalIgnoreCase);
        private DateTime _lastScanTime = DateTime.MinValue;
        private static readonly TimeSpan CacheTtl = TimeSpan.FromSeconds(2);

        public IReadOnlyList<string> AllowedServices { get; }

        public WindowsServiceMonitor(
            ILogger<WindowsServiceMonitor> logger,
            IEnumerable<string>? allowedServices = null)
        {
            _logger = logger;
            var inputList = allowedServices?.ToList();
            var list = (inputList != null && inputList.Count > 0)
                ? inputList
                : DefaultAllowedServices.ToList();
            AllowedServices = list.AsReadOnly();
            _allowedSet = new HashSet<string>(list, StringComparer.OrdinalIgnoreCase);
        }

        public List<ServiceStatusDto> GetServicesStatus(IEnumerable<string>? filterNames = null)
        {
            var requested = filterNames != null
                ? filterNames.Where(f => _allowedSet.Contains(f)).ToList()
                : AllowedServices.ToList();

            if (requested.Count == 0)
            {
                return new List<ServiceStatusDto>();
            }

            var now = DateTime.UtcNow;
            lock (_cacheLock)
            {
                if (now - _lastScanTime < CacheTtl && _statusCache.Count > 0)
                {
                    return requested
                        .Select(name => _statusCache.TryGetValue(name, out var dto) ? dto : CreateNotFound(name))
                        .ToList();
                }

                _statusCache = RefreshAllServices();
                _lastScanTime = now;

                return requested
                    .Select(name => _statusCache.TryGetValue(name, out var dto) ? dto : CreateNotFound(name))
                    .ToList();
            }
        }

        private Dictionary<string, ServiceStatusDto> RefreshAllServices()
        {
            var dict = new Dictionary<string, ServiceStatusDto>(StringComparer.OrdinalIgnoreCase);

            if (!OperatingSystem.IsWindows())
            {
                foreach (var name in AllowedServices)
                {
                    dict[name] = new ServiceStatusDto
                    {
                        Name = name,
                        DisplayName = name,
                        Status = "UnsupportedOS",
                        IsRunning = false
                    };
                }
                return dict;
            }

            foreach (var name in AllowedServices)
            {
                dict[name] = QuerySingleService(name);
            }

            return dict;
        }

        private ServiceStatusDto QuerySingleService(string serviceName)
        {
            try
            {
                using var sc = new ServiceController(serviceName);
                var status = sc.Status;
                return new ServiceStatusDto
                {
                    Name = serviceName,
                    DisplayName = !string.IsNullOrWhiteSpace(sc.DisplayName) ? sc.DisplayName : serviceName,
                    Status = status.ToString(),
                    IsRunning = status == ServiceControllerStatus.Running
                };
            }
            catch (InvalidOperationException)
            {
                // Serviço não existe ou não está instalado no host
                return CreateNotFound(serviceName);
            }
            catch (Exception ex)
            {
                _logger.LogDebug(ex, "Erro ao consultar status do serviço {ServiceName}", serviceName);
                return new ServiceStatusDto
                {
                    Name = serviceName,
                    DisplayName = serviceName,
                    Status = "Unknown",
                    IsRunning = false
                };
            }
        }

        private static ServiceStatusDto CreateNotFound(string name) => new()
        {
            Name = name,
            DisplayName = name,
            Status = "NotFound",
            IsRunning = false
        };
    }
}
