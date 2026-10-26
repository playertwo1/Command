using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace DroidDeck.Lib.Mdns
{
    public class MdnsDiscoveryServer : BackgroundService
    {
        public const string ServiceType = "_command._tcp.local";
        public const int MdnsPort = 5353;
        private static readonly IPAddress MulticastAddress = IPAddress.Parse("224.0.0.251");

        private readonly ILogger<MdnsDiscoveryServer> _logger;
        private Socket? _socket;
        private readonly string _machineName;
        private readonly string _instanceName;
        private readonly string _hostName;

        public MdnsDiscoveryServer(ILogger<MdnsDiscoveryServer> logger)
        {
            _logger = logger;
            _machineName = Environment.MachineName;
            _instanceName = $"{_machineName}._command._tcp.local";
            _hostName = $"{_machineName}.local";
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            try
            {
                _socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, ProtocolType.Udp);
                _socket.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
                _socket.Bind(new IPEndPoint(IPAddress.Any, MdnsPort));

                try
                {
                    _socket.SetSocketOption(SocketOptionLevel.IP, SocketOptionName.AddMembership,
                        new MulticastOption(MulticastAddress, IPAddress.Any));
                    _socket.SetSocketOption(SocketOptionLevel.IP, SocketOptionName.MulticastTimeToLive, 255);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "[mDNS] Não foi possível ingressar no grupo multicast 224.0.0.251");
                }

                _logger.LogInformation("[mDNS] Servidor iniciado na porta {Port} para serviço {Service}", MdnsPort, ServiceType);

                // Envia anúncio espontâneo inicial na rede
                await SendAnnouncementAsync(ttl: 120, target: new IPEndPoint(MulticastAddress, MdnsPort));

                byte[] buffer = new byte[4096];
                EndPoint remoteEp = new IPEndPoint(IPAddress.Any, 0);

                while (!stoppingToken.IsCancellationRequested)
                {
                    try
                    {
                        var result = await _socket.ReceiveFromAsync(buffer, SocketFlags.None, remoteEp, stoppingToken);
                        if (result.ReceivedBytes <= 0) continue;

                        var packet = MdnsPacket.Parse(buffer, result.ReceivedBytes);
                        if (packet.IsQuery)
                        {
                            await HandleQueryAsync(packet, result.RemoteEndPoint);
                        }
                    }
                    catch (ObjectDisposedException)
                    {
                        break;
                    }
                    catch (OperationCanceledException)
                    {
                        break;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "[mDNS] Erro transitório recebendo pacote; continuando");
                        try { await Task.Delay(500, stoppingToken); } catch { break; }
                    }
                }
            }
            catch (SocketException ex)
            {
                _logger.LogWarning(ex, "[mDNS] Falha ao vincular socket mDNS na porta 5353 (pode estar em uso por outro serviço). mDNS desativado localmente.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[mDNS] Erro inesperado no serviço mDNS");
            }
            finally
            {
                // Envia pacote de adeus (TTL=0) informando que o serviço saiu da rede
                try
                {
                    if (_socket != null && _socket.IsBound)
                    {
                        await SendAnnouncementAsync(ttl: 0, target: new IPEndPoint(MulticastAddress, MdnsPort));
                    }
                }
                catch { }

                try
                {
                    _socket?.Close();
                    _socket?.Dispose();
                }
                catch { }
            }
        }

        private async Task HandleQueryAsync(MdnsPacket query, EndPoint remoteEndPoint)
        {
            bool matches = false;
            bool unicast = false;

            foreach (var q in query.Questions)
            {
                if (string.Equals(q.Name, ServiceType, StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(q.Name, "_services._dns-sd._udp.local", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(q.Name, _instanceName, StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(q.Name, _hostName, StringComparison.OrdinalIgnoreCase))
                {
                    matches = true;
                    if (q.UnicastResponse) unicast = true;
                    break;
                }
            }

            if (!matches) return;

            // Se o solicitante pediu unicast explícito, responde para ele; senão envia multicast
            var target = unicast ? remoteEndPoint : new IPEndPoint(MulticastAddress, MdnsPort);
            await SendAnnouncementAsync(ttl: 120, target: target, queryId: query.TransactionId);
        }

        public async Task SendAnnouncementAsync(uint ttl, EndPoint target, ushort queryId = 0)
        {
            if (_socket == null || !_socket.IsBound) return;

            try
            {
                var response = BuildResponsePacket(ttl, queryId);
                byte[] bytes = response.ToBytes();
                await _socket.SendToAsync(bytes, SocketFlags.None, target);
                _logger.LogDebug("[mDNS] Anúncio enviado para {Target} (TTL={Ttl})", target, ttl);
            }
            catch (Exception ex)
            {
                _logger.LogDebug(ex, "[mDNS] Falha enviando anúncio para {Target}", target);
            }
        }

        public MdnsPacket BuildResponsePacket(uint ttl, ushort queryId = 0)
        {
            var response = new MdnsPacket
            {
                TransactionId = queryId,
                Flags = 0x8400 // Response + Authoritative
            };

            // 1. Resposta PTR: _command._tcp.local -> {MachineName}._command._tcp.local
            response.Answers.Add(new DnsResourceRecord
            {
                Name = ServiceType,
                Type = DnsRecordType.PTR,
                Class = 0x0001, // IN
                Ttl = ttl,
                Data = MdnsPacket.EncodeName(_instanceName)
            });

            // 2. Resposta SRV: {Instance} -> host, port 4787
            response.Answers.Add(new DnsResourceRecord
            {
                Name = _instanceName,
                Type = DnsRecordType.SRV,
                Class = 0x8001, // Cache-flush IN
                Ttl = ttl,
                Data = MdnsPacket.EncodeSrv(0, 0, (ushort)PairingInfo.Port, _hostName)
            });

            // 3. Resposta TXT com metadados higienizados (sem credenciais ou segredos)
            string certPin = string.Empty;
            try { certPin = BridgeCertificateProvider.GetSha256Pin(); } catch { }

            var txtDict = new Dictionary<string, string>
            {
                ["txtvers"] = "1",
                ["name"] = _machineName,
                ["id"] = _machineName,
                ["port"] = PairingInfo.Port.ToString(),
                ["controlPort"] = PairingInfo.ControlPort.ToString(),
                ["certPin"] = certPin,
                ["model"] = "CommandBridge"
            };

            response.Answers.Add(new DnsResourceRecord
            {
                Name = _instanceName,
                Type = DnsRecordType.TXT,
                Class = 0x8001,
                Ttl = ttl,
                Data = MdnsPacket.EncodeTxt(txtDict)
            });

            // 4. Resposta A: endereço IPv4 local
            IPAddress? localIp = null;
            try
            {
                if (IPAddress.TryParse(NetworkInfo.GetLanIp(), out var ip))
                {
                    localIp = ip;
                }
            }
            catch { }

            if (localIp != null && localIp.AddressFamily == AddressFamily.InterNetwork)
            {
                response.Additionals.Add(new DnsResourceRecord
                {
                    Name = _hostName,
                    Type = DnsRecordType.A,
                    Class = 0x8001,
                    Ttl = ttl,
                    Data = localIp.GetAddressBytes()
                });
            }

            return response;
        }
    }
}
