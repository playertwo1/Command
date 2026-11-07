import 'package:command/src/connection/constants.dart';
import 'package:command/src/services/mdns_discovery_service.dart';
import 'package:command/src/services/signalr_service.dart';
import 'package:command/core/core.dart';
import 'package:command/src/config/integrations_page.dart';
import 'package:command/src/config/pc_switcher.dart';
import 'package:command/src/connection/pc_store.dart';
import 'package:command/src/connection/pc_connections.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_checker.dart';
import 'control_pairing_qr.dart';
import 'control_pairing_transport.dart';
import 'qr_scan_page.dart';
import 'appearance_settings_page.dart';
import 'health_alert_settings_page.dart';
import '../welcome/welcome_page.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  ConfigPageState createState() => ConfigPageState();
}

class ConfigPageState extends State<ConfigPage> {
  final _ipController = TextEditingController();
  bool _isLoading = false;
  bool _isCheckingAppUpdate = false;
  String? _appUpdateStatus;
  List<DiscoveredCommandDevice> _discoveredDevices = [];

  @override
  void initState() {
    super.initState();
    _loadIP();
  }

  List<SavedPc> _pcs = [];

  Future<void> _loadIP() async {
    final prefs = await SharedPreferences.getInstance();
    var pcs = await PcStore.load();
    // PC migrado da versão antiga ainda sem nome: pergunta ao PC em uso.
    final current = pcs.where((p) => p.id == PcStore.currentId).firstOrNull;
    if (current != null &&
        (current.name == 'PC' || current.name == current.ip)) {
      await fetchPcName(current);
      pcs = await PcStore.load();
    }
    if (!mounted) return;
    setState(() {
      _pcs = pcs;
      _ipController.text = prefs.getString(Constants.ipAddrKey) ?? '';
    });
  }

  /// PCs pareados: tocar troca de PC; o menu renomeia ou esquece.
  Widget _buildPcList() {
    final connections = Injector.get<PcConnections>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('PCs pareados'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final pc in _pcs)
          Watch((context) {
            final isCurrent = pc.id == PcStore.currentId;
            final service = connections.forPc(pc.id);
            final status = service?.connectionStatus.watch(context);
            final lastSeen = service?.lastSeen.watch(context);
            final stats = service?.systemStats.watch(context);
            final revoked = service?.isRevoked.watch(context) == true;
            final online = status == 'Connected';
            final parallel = !isCurrent && service != null;
            final seenText = lastSeen == null
                ? tr('Nunca nesta sessão')
                : '${tr('Visto')} ${TimeOfDay.fromDateTime(lastSeen).format(context)}';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isCurrent
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(pc.name),
              subtitle: Text(
                '${pc.ip}:${pc.port} · ${online
                    ? tr('Online')
                    : revoked
                    ? tr('Revogado')
                    : parallel
                    ? tr('Offline')
                    : tr('Desconectado')}'
                '${online && stats != null ? ' · CPU ${stats.cpuUsage.toStringAsFixed(0)}% · RAM ${stats.ramUsage.toStringAsFixed(0)}%' : ''}'
                ' · $seenText',
              ),
              onTap: isCurrent ? null : () => switchToPc(context, pc),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'rename') await _renamePc(pc);
                  if (v == 'remove') await _removePc(pc);
                  if (v == 'connect') await connections.connectSecondary(pc);
                  if (v == 'disconnect') await connections.onPcRemoved(pc.id);
                  if (mounted) setState(() {});
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'rename', child: Text(tr('Renomear'))),
                  if (!isCurrent)
                    PopupMenuItem(
                      value: parallel ? 'disconnect' : 'connect',
                      child: Text(
                        parallel
                            ? tr('Desconectar paralelo')
                            : tr('Conectar em paralelo'),
                      ),
                    ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(tr('Esquecer este PC')),
                  ),
                ],
              ),
            );
          }),
        Text(
          tr(
            'Para acrescentar outro PC, pareie com o QR dele (ou digite o IP abaixo).',
          ),
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _renamePc(SavedPc pc) async {
    final ctrl = TextEditingController(text: pc.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Nome do PC')),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(tr('Salvar')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await PcStore.rename(pc.id, name);
    _loadIP();
  }

  Future<void> _removePc(SavedPc pc) async {
    final wasCurrent = pc.id == PcStore.currentId;
    await PcStore.remove(pc.id);
    await Injector.get<PcConnections>().onPcRemoved(pc.id);
    final next = await PcStore.current();
    if (!mounted) return;
    if (wasCurrent && next != null) {
      await switchToPc(context, next);
    } else {
      _loadIP();
    }
  }

  Future<void> _findServer() async {
    setState(() => _isLoading = true);
    try {
      final discovery = MdnsDiscoveryService();
      final devices = await discovery.discoverDevices(timeout: const Duration(seconds: 3));
      if (!mounted) return;
      setState(() {
        _discoveredDevices = devices;
      });

      if (devices.isNotEmpty) {
        final first = devices.first;
        _ipController.text = first.ip;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('Encontrado: {server} ({ip})', {'server': first.name, 'ip': first.ip}),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('Nenhum PC Command encontrado na rede'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Erro: {error}', {'error': e}))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkAppUpdate() async {
    if (_isCheckingAppUpdate) return;
    setState(() => _isCheckingAppUpdate = true);
    try {
      final update = await checkForAppUpdate();
      if (!mounted) return;
      if (!update.isAvailable) {
        final message = tr('Você já está na versão mais recente ({version}).', {
          'version': update.currentVersion,
        });
        setState(() => _appUpdateStatus = message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      setState(() {
        _appUpdateStatus = tr('Atualização disponível: {version}', {
          'version': update.latestVersion,
        });
      });
      final shouldDownload = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('Atualização disponível')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Versão atual: {version}', {
                  'version': update.currentVersion,
                }),
              ),
              Text(
                tr('Nova versão: {version}', {'version': update.latestVersion}),
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  'O APK será baixado no navegador. Ao terminar, abra o arquivo baixado e confirme a instalação.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('Cancelar')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.download),
              label: Text(tr('Baixar APK')),
            ),
          ],
        ),
      );
      if (shouldDownload != true || !mounted) return;
      try {
        final opened = await launchUrl(
          update.apkUrl,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('Não foi possível abrir o download do APK.')),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('Não foi possível abrir o download do APK.')),
            ),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      final message = tr('Não foi possível verificar atualizações agora.');
      setState(() => _appUpdateStatus = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isCheckingAppUpdate = false);
    }
  }

  Future<void> _saveAndGoBack() async {
    var ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Por favor insira um IP válido'))),
      );
      return;
    }

    // Basic Sanitization
    ip = ip.replaceAll('http://', '').replaceAll('https://', '');
    if (ip.endsWith('/')) ip = ip.substring(0, ip.length - 1);

    // Check for port
    String baseUrl;
    String port;
    if (ip.contains(':')) {
      // User provided port
      baseUrl = 'http://$ip';
      port = ip.substring(ip.indexOf(':') + 1);
    } else {
      // Default port
      port = Constants.defaultPort;
      baseUrl = 'http://$ip:$port';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.ipAddrKey, ip); // Save raw IP for UI
    await prefs.setString(
      Constants.portKey,
      port,
    ); // persiste a porta p/ o splash
    final apiKey = prefs.getString(
      Constants.apiKeyKey,
    ); // mantém a chave do pareamento
    final host = ip.contains(':') ? ip.substring(0, ip.indexOf(':')) : ip;
    final pc = await PcStore.upsert(ip: host, port: port, apiKey: apiKey);
    fetchPcName(pc);

    // Update Singletons immediately
    final client = Injector.get<CommandClient>();
    client.setBaseUrl(baseUrl);
    client.setApiKey(apiKey);

    final signalR = Injector.get<SignalRService>();
    await signalR.updateUrl(
      baseUrl,
      apiKey: apiKey,
    ); // Use local baseUrl, not client.baseUrl

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _pairWithQr() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScanPage()));
    if (result == null || !mounted) return;

    final controlQr = ControlPairingQr.tryParse(result);
    if (controlQr != null) {
      await _pairRemoteControl(controlQr);
      return;
    }

    final uri = Uri.tryParse(result);
    final ip = uri?.queryParameters['ip'];
    final port = uri?.queryParameters['port'] ?? Constants.defaultPort;
    final key = uri?.queryParameters['key'];

    if (uri == null ||
        (uri.scheme != 'command' && uri.scheme != 'droiddeck') ||
        ip == null ||
        ip.isEmpty ||
        key == null ||
        key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Esse QR não é de pareamento do Command. Use o da janela "Parear dispositivo (QR)" do PC.',
            ),
          ),
        ),
      );
      return;
    }

    final baseUrl = 'http://$ip:$port';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Constants.ipAddrKey, ip);
    await prefs.setString(
      Constants.portKey,
      port,
    ); // persiste a porta p/ o splash
    await prefs.setString(Constants.apiKeyKey, key);
    // Parear com outro PC acrescenta à lista; o mesmo IP atualiza a chave.
    final pc = await PcStore.upsert(ip: ip, port: port, apiKey: key);
    await fetchPcName(pc);

    final client = Injector.get<CommandClient>();
    client.setBaseUrl(baseUrl);
    client.setApiKey(key);
    final signalR = Injector.get<SignalRService>();
    await signalR.updateUrl(baseUrl, apiKey: key);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('Pareado com sucesso!'))));
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _pairRemoteControl(ControlPairingQr qr) async {
    final matches = (await PcStore.load())
        .where((pc) => pc.ip == qr.ip)
        .toList();
    if (matches.length != 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'Pareie primeiro este PC pelo QR normal e tente o QR de controle novamente.',
              ),
            ),
          ),
        );
      }
      return;
    }

    try {
      final credential = await exchangeControlPairingTicket(qr);
      final stored = await PcStore.setControlCredential(
        pcId: matches.single.id,
        deviceId: credential.deviceId,
        certificatePin: qr.pin,
        credential: credential.credential,
      );
      if (!stored) throw StateError('Saved PC disappeared during pairing.');
      if (!mounted) return;
      await _loadIP();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Controle remoto autorizado para este PC.'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Não foi possível autorizar o controle remoto. O QR pode ter expirado ou o certificado não corresponde.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Configuração'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pcs.isNotEmpty) ...[
                _buildPcList(),
                const Divider(height: 24),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WelcomePage()),
                  ),
                  icon: const Icon(Icons.help_outline),
                  label: Text(tr('Ainda não instalou no PC? Veja como')),
                ),
              ),
              TextField(
                controller: _ipController,
                decoration: InputDecoration(
                  labelText: tr('IP do Servidor'),
                  hintText: '192.168.x.x',
                ),
              ),
              if (_discoveredDevices.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('PCs Encontrados na Rede (mDNS)'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                for (final dev in _discoveredDevices)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.computer, color: Color(0xFFA78BFA)),
                      title: Text(dev.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${dev.ip}:${dev.port}'),
                      trailing: TextButton(
                        onPressed: () {
                          _ipController.text = dev.ip;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr('IP preenchido: {ip}', {'ip': dev.ip}))),
                          );
                        },
                        child: Text(tr('Usar')),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _findServer,
                      icon: const Icon(Icons.search),
                      label: Text(tr('Pesquisar Servidor')),
                    ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pairWithQr,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(tr('Parear (QR)')),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveAndGoBack,
                child: Text(tr('Salvar')),
              ),
              const Divider(height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.palette_outlined),
                title: Text(tr('Aparência')),
                subtitle: Text(
                  tr('Tema, cores, estilo dos botões, vibração e idioma'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AppearanceSettingsPage(),
                  ),
                ),
              ),
              // F7-01: Controles de backup/macros não entregues removidos da interface de configurações
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.extension_outlined),
                title: Text(tr('Integrações')),
                subtitle: Text(
                  tr(
                    'Discord, OBS, Twitch, YouTube, Spotify, Soundboard, Home Assistant e Tuya',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const IntegrationsPage()),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(tr('Limiares de Alerta de Recursos')),
                subtitle: Text(
                  tr('Limites de CPU, RAM, temperatura, disco e bateria'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HealthAlertSettingsPage(),
                  ),
                ),
              ),
              if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.system_update_alt),
                  title: Text(tr('Atualizações do aplicativo')),
                  subtitle: Text(
                    _appUpdateStatus ??
                        tr(
                          'Verifique e baixe a versão mais recente do Command.',
                        ),
                  ),
                  trailing: _isCheckingAppUpdate
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _checkAppUpdate,
                          child: Text(tr('Verificar agora')),
                        ),
                  onTap: _isCheckingAppUpdate ? null : _checkAppUpdate,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }
}
