class ControlPairingQr {
  const ControlPairingQr({
    required this.ip,
    required this.port,
    required this.ticket,
    required this.pin,
  });

  final String ip;
  final int port;
  final String ticket;
  final String pin;

  static ControlPairingQr? tryParse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        (uri.scheme != 'command' && uri.scheme != 'droiddeck') ||
        uri.host != 'control-pair') {
      return null;
    }
    final params = uri.queryParametersAll;
    if (params.values.any((values) => values.length != 1)) return null;
    final ip = params['ip']?.single;
    final portText = params['port']?.single;
    final ticket = params['ticket']?.single;
    final pin = params['pin']?.single.toLowerCase();
    final port = int.tryParse(portText ?? '');
    if (ip == null ||
        ip.isEmpty ||
        ip.length > 253 ||
        port != 4788 ||
        ticket == null ||
        !RegExp(r'^[A-Za-z0-9_-]{22,128}$').hasMatch(ticket) ||
        pin == null ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(pin)) {
      return null;
    }
    return ControlPairingQr(ip: ip, port: port!, ticket: ticket, pin: pin);
  }
}
