using Command.Auth;
using QRCoder;

namespace Command.Lib
{
    /// <summary>
    /// Monta os dados de pareamento (URI + QR) compartilhados pela janela de bandeja
    /// e pelo modo de diagnóstico --print-pairing.
    /// </summary>
    public static class PairingInfo
    {
        public const int Port = 4787;
        public const int ControlPort = BridgeCertificateProvider.HttpsPort;

        /// <summary>URI atual de pareamento; o app também aceita droiddeck:// de instalações antigas.</summary>
        public static string BuildUri()
        {
            var ip = NetworkInfo.GetLanIp();
            var key = ApiKeyProvider.GetKey();
            return $"command://pair?ip={ip}&port={Port}&key={key}";
        }

        /// <summary>Credencial temporária de controle, emitida apenas pela janela local de pareamento.</summary>
        public static string BuildControlUri()
        {
            var ip = NetworkInfo.GetLanIp();
            var ticket = Auth.ControlPairingTicketStore.Shared.Issue();
            var pin = BridgeCertificateProvider.GetSha256Pin();
            return $"command://control-pair?ip={Uri.EscapeDataString(ip)}&port={ControlPort}&ticket={ticket}&pin={pin}";
        }

        public static byte[] BuildQrPng(string uri, int pixelsPerModule = 10)
        {
            var generator = new QRCodeGenerator();
            var data = generator.CreateQrCode(uri, QRCodeGenerator.ECCLevel.Q);
            return new PngByteQRCode(data).GetGraphic(pixelsPerModule);
        }
    }
}
