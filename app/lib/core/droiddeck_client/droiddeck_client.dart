import 'dart:typed_data';

import 'package:droiddeck/core/i18n/i18n.dart';
import 'package:dio/dio.dart';
import 'models/mixer_data.dart';
import 'models/audio_target.dart';
import 'models/mixer_entity.dart';
import 'models/mixer_master.dart';
import 'models/media_session.dart';
import 'models/deck_profile.dart';
import 'models/deck_action.dart';
import 'models/sound_result.dart';
import 'models/app_catalog_models.dart';
export 'models/app_catalog_models.dart';
import 'models/screenshot_models.dart';
export 'models/screenshot_models.dart';
import 'models/transfer_models.dart';
export 'models/transfer_models.dart';
import 'models/diagnostics_models.dart';
export 'models/diagnostics_models.dart';

class DroidDeckClient {
  final Dio _dio;
  final String baseUrl;

  DroidDeckClient({
    required String baseUrl,
    Dio? dio,
  })  : _dio = dio ?? Dio(),
        baseUrl = baseUrl {
    _dio.options.baseUrl = baseUrl;
    // O PC traduz o que manda (tipos de ação, erros) pelo idioma do app.
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      options.headers['Accept-Language'] = AppLanguage.header;
      handler.next(options);
    }));
  }

  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  /// Define (ou remove) a chave de API enviada em todas as requisições (header X-API-KEY).
  void setApiKey(String? key) {
    if (key == null || key.isEmpty) {
      _dio.options.headers.remove('X-API-KEY');
    } else {
      _dio.options.headers['X-API-KEY'] = key;
    }
  }

  /// Retorna a chave de API configurada no cliente, se houver.
  String? get apiKey => _dio.options.headers['X-API-KEY'] as String?;

  Future<List<MixerEntity>> getOutputs() async {
    final response = await _dio.get('/api/v1/Mixer/out');
    return (response.data as List)
        .map((e) => MixerEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MixerEntity> getOutput(String id) async {
    final response = await _dio.get('/api/v1/Mixer/out/$id');
    return MixerEntity.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MixerMaster> setOutput(String id, MixerData data) async {
    final response = await _dio.put(
      '/api/v1/Mixer/out/$id',
      data: data.toJson(),
    );
    return MixerMaster.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<MixerEntity>> getInputs() async {
    final response = await _dio.get('/api/v1/Mixer/in');
    return (response.data as List)
        .map((e) => MixerEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MixerEntity> getInput(String id) async {
    final response = await _dio.get('/api/v1/Mixer/in/$id');
    return MixerEntity.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MixerMaster> setInput(String id, MixerData data) async {
    final response = await _dio.put(
      '/api/v1/Mixer/in/$id',
      data: data.toJson(),
    );
    return MixerMaster.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> mute(AudioTarget target) async {
    final response = await _dio.post(
      '/api/Software/mute',
      data: target.toJson(),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleMute(AudioTarget target) async {
    final response = await _dio.post(
      '/api/Software/toggle-mute',
      data: target.toJson(),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Estado de mute atual de um processo (null se não houver sessão de áudio).
  Future<bool?> getMuteState(String process) async {
    final response = await _dio.get('/api/Software/mute-state/$process');
    final data = response.data;
    if (data is Map && data['muted'] is bool) return data['muted'] as bool;
    return null;
  }

  /// Estado atual do Discord (connected/mute/deaf/channelId/channelName/
  /// inputVolume/outputVolume/voiceMode/participants) ou null se indisponível.
  Future<Map<String, dynamic>?> getDiscordState() async {
    try {
      final response = await _dio.get('/api/discord/state');
      return (response.data as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// Servidores do Discord do usuário ([{id, name}]).
  Future<List<Map<String, String>>> getDiscordGuilds() async {
    try {
      final r = await _dio.get('/api/discord/guilds');
      return (r.data as List)
          .map<Map<String, String>>(
              (e) => {'id': '${e['id']}', 'name': '${e['name'] ?? ''}'})
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Canais de voz de um servidor ([{id, name}]).
  Future<List<Map<String, String>>> getDiscordChannels(String guildId) async {
    try {
      final r = await _dio.get('/api/discord/channels/$guildId');
      return (r.data as List)
          .map<Map<String, String>>(
              (e) => {'id': '${e['id']}', 'name': '${e['name'] ?? ''}'})
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Salva as credenciais do app Discord (Client ID + Secret) no PC.
  Future<void> setDiscordConfig(String clientId, String clientSecret) async {
    await _dio.post('/api/discord/config',
        data: {'clientId': clientId, 'clientSecret': clientSecret});
  }

  /// Conecta ao Discord (abre o popup de autorização no PC na 1ª vez).
  /// Lança [Exception] com mensagem legível em caso de erro.
  Future<Map<String, dynamic>> connectDiscord() async {
    try {
      final r = await _dio.post('/api/discord/connect');
      return (r.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? '${data['error']}'
          : tr('Falha ao conectar — o Discord está aberto no PC?');
      throw Exception(msg);
    }
  }

  /// Sons da soundboard NATIVA do Discord ([{soundId, name, guildId, emojiName}]).
  Future<List<Map<String, String>>> getDiscordSoundboardSounds() async {
    try {
      final r = await _dio.get('/api/discord/soundboard-sounds');
      return (r.data as List)
          .map<Map<String, String>>((e) => {
                'soundId': '${e['soundId'] ?? ''}',
                'name': '${e['name'] ?? ''}',
                'guildId': '${e['guildId'] ?? ''}',
                'emojiName': '${e['emojiName'] ?? ''}',
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Toca um som da soundboard nativa do Discord no canal de voz atual.
  Future<void> playDiscordSoundboard(String soundId, String? guildId) async {
    await _dio.post('/api/discord/play-soundboard',
        data: {'soundId': soundId, 'guildId': guildId});
  }

  // ---- OBS ----
  /// Estado do OBS (connected/currentScene/recording/streaming/virtualCam/
  /// replayBuffer/scenes/audioInputs) ou null se indisponível.
  Future<Map<String, dynamic>?> getObsState() async {
    try {
      final r = await _dio.get('/api/obs/state');
      return (r.data as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// Salva a config do OBS (host/porta/senha do obs-websocket).
  Future<void> setObsConfig(String host, int port, String? password) async {
    await _dio.post('/api/obs/config',
        data: {'host': host, 'port': port, 'password': password});
  }

  /// Conecta no OBS (obs-websocket). Lança [Exception] legível em caso de erro.
  Future<Map<String, dynamic>> connectObs() async {
    try {
      final r = await _dio.post('/api/obs/connect');
      return (r.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['error'] != null)
          ? '${data['error']}'
          : tr('Falha ao conectar no OBS (obs-websocket ativo?)');
      throw Exception(msg);
    }
  }

  // ---- Tuya / Smart Life ----
  /// Estado do plugin: paired/connected/push + os dispositivos com status e funções.
  Future<Map<String, dynamic>?> getTuyaState() async {
    try {
      final r = await _dio.get('/api/tuya/state');
      return (r.data as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// Passo 1 do pareamento: devolve `qrPayload` para renderizar o QR na tela.
  Future<Map<String, dynamic>> startTuyaPairing(String userCode) async {
    try {
      final r = await _dio
          .post('/api/tuya/pair/start', data: {'userCode': userCode});
      return (r.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw Exception(_tuyaError(e, tr('Falha ao gerar o QR de pareamento')));
    }
  }

  /// Passo 2: chamar em laço. `false` = ainda não escaneado (não é erro).
  /// Lança [Exception] quando o QR expirou (HTTP 410) e outro precisa ser gerado.
  Future<bool> pollTuyaPairing() async {
    try {
      final r = await _dio.post('/api/tuya/pair/poll');
      return (r.data as Map)['scanned'] == true;
    } on DioException catch (e) {
      throw Exception(_tuyaError(e, tr('Falha ao verificar o pareamento')));
    }
  }

  /// Reenumera os dispositivos na nuvem. Caro em cota — só a pedido do usuário.
  Future<Map<String, dynamic>> refreshTuyaDevices() async {
    try {
      final r = await _dio.post('/api/tuya/devices/refresh');
      return (r.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw Exception(_tuyaError(e, tr('Falha ao atualizar os dispositivos')));
    }
  }

  /// Dispara um comando avulso (usado pelo botão "testar" do editor).
  Future<void> sendTuyaCommand(
      String deviceId, String code, Object? value) async {
    try {
      await _dio.post('/api/tuya/command',
          data: {'deviceId': deviceId, 'code': code, 'value': value});
    } on DioException catch (e) {
      throw Exception(_tuyaError(e, tr('Falha ao enviar o comando')));
    }
  }

  static String _tuyaError(DioException e, String fallback) {
    final data = e.response?.data;
    return (data is Map && data['error'] != null) ? '${data['error']}' : fallback;
  }

  // Media Control methods
  Future<List<MediaSession>> getMediaSessions() async {
    final response = await _dio.get('/api/v1/Media/sessions');
    return (response.data as List)
        .map((e) => MediaSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MediaSession> getMediaSession(String id) async {
    final response = await _dio.get('/api/v1/Media/sessions/$id');
    return MediaSession.fromJson(response.data as Map<String, dynamic>);
  }

  /// Envia um comando de transporte e devolve o que o backend aplicou:
  /// `sessionId` (pode diferir do pedido, quando o id salvo nao existe mais) e
  /// `playing` (estado logo apos o comando). Mapa vazio se a resposta vier sem corpo.
  Future<Map<String, dynamic>> sendMediaCommand(String id, String command) async {
    final response = await _dio.post(
      '/api/v1/Media/sessions/$id/command',
      data: {'command': command},
    );
    final data = response.data;
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // StreamDeck methods
  Future<List<DeckProfile>> getProfiles() async {
    final response = await _dio.get('/api/StreamDeck/profiles');
    return (response.data as List)
        .map((e) => DeckProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DeckProfile> getProfile(String id) async {
    final response = await _dio.get('/api/StreamDeck/profiles/$id');
    return DeckProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> saveProfile(DeckProfile profile) async {
    await _dio.post(
      '/api/StreamDeck/profiles',
      data: profile.toJson(),
    );
  }

  Future<void> deleteProfile(String id) async {
    await _dio.delete('/api/StreamDeck/profiles/$id');
  }

  /// Aperta um botão salvo: o PC lê a ação do perfil. É o caminho do deck — o
  /// /execute com ação avulsa recusa (403), de fora do PC, ações que rodam código.
  Future<void> pressButton(String profileId, String buttonId,
      {String gesture = 'tap'}) async {
    await _dio.post(
      '/api/StreamDeck/press',
      data: {'profileId': profileId, 'buttonId': buttonId, 'gesture': gesture},
    );
  }

  /// Backup dos perfis (.droiddeck, um zip).
  Future<List<int>> exportBackup() async {
    final response = await _dio.get<List<int>>('/api/backup',
        options: Options(responseType: ResponseType.bytes));
    return response.data ?? const [];
  }

  /// Restaura um .droiddeck. Devolve quantos perfis entraram.
  Future<int> importBackup(List<int> bytes) async {
    // Bytes direto (não Stream): no navegador o Dio só envia corpo binário assim.
    final response = await _dio.post('/api/backup',
        data: Uint8List.fromList(bytes),
        options: Options(contentType: 'application/octet-stream'));
    return ((response.data as Map?)?['imported'] as num?)?.toInt() ?? 0;
  }

  /// Catálogo dos tipos de ação (GET /api/actions/schema). Servidores anteriores
  /// à 1.8 não têm o endpoint: aí lança, e o editor usa o catálogo embutido.
  Future<List<Map<String, dynamic>>> getActionSchema() async {
    final response = await _dio.get('/api/actions/schema');
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Estado atual de um provedor de ação (o mesmo que vai pelo SignalR).
  Future<Map<String, dynamic>?> getActionState(String type) async {
    final response = await _dio.get('/api/actions/state/$type');
    final data = response.data;
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// GET genérico para as listas de opções que o schema aponta (cenas, filtros...).
  Future<dynamic> getJson(String path) async {
    final response = await _dio.get(path);
    return response.data;
  }

  Future<dynamic> postJson(String path, [Object? body]) async {
    final response = await _dio.post(path, data: body);
    return response.data;
  }

  Future<dynamic> deleteJson(String path) async {
    final response = await _dio.delete(path);
    return response.data;
  }

  Future<void> executeAction(DeckAction action) async {
    await _dio.post(
      '/api/StreamDeck/execute',
      data: action.toJson(),
    );
  }

  /// Grade física do deck persistida no PC ({rows, columns}).
  Future<Map<String, int>?> getLayout() async {
    try {
      final r = await _dio.get('/api/StreamDeck/layout');
      final m = (r.data as Map);
      return {
        'rows': (m['rows'] as num).toInt(),
        'columns': (m['columns'] as num).toInt(),
      };
    } catch (_) {
      return null;
    }
  }

  /// O celular reporta quantos botões cabem inteiros na tela.
  Future<void> saveLayout(int rows, int columns) async {
    await _dio.post(
      '/api/StreamDeck/layout',
      data: {'rows': rows, 'columns': columns},
    );
  }

  // ---- Soundboard (MyInstants) ----
  /// Busca sons no MyInstants (proxiado pelo backend).
  Future<List<SoundResult>> searchSounds(String query) async {
    try {
      final r = await _dio.get('/api/Soundboard/search',
          queryParameters: {'q': query});
      return (r.data as List)
          .map((e) => SoundResult.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Sons em alta no MyInstants.
  Future<List<SoundResult>> getTrendingSounds() async {
    try {
      final r = await _dio.get('/api/Soundboard/trending');
      return (r.data as List)
          .map((e) => SoundResult.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Toca um som no PC (sai pelo dispositivo configurado — cabo/monitor).
  Future<void> playSound(String id, String url, String title) async {
    await _dio.post('/api/Soundboard/play',
        data: {'id': id, 'url': url, 'title': title});
  }

  /// Para tudo que estiver tocando na soundboard.
  Future<void> stopSounds() async {
    await _dio.post('/api/Soundboard/stop');
  }

  /// Dispositivos de saída de áudio disponíveis ([{id, name}]).
  Future<List<Map<String, String>>> getSoundDevices() async {
    try {
      final r = await _dio.get('/api/Soundboard/devices');
      return (r.data as List)
          .map<Map<String, String>>(
              (e) => {'id': '${e['id']}', 'name': '${e['name'] ?? ''}'})
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Config da soundboard ({cableDeviceId, monitorDeviceId, monitorEnabled, volume}).
  Future<Map<String, dynamic>?> getSoundboardConfig() async {
    try {
      final r = await _dio.get('/api/Soundboard/config');
      return (r.data as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  /// Salva a config da soundboard (seleção de dispositivos + volume).
  Future<void> saveSoundboardConfig({
    String? cableDeviceId,
    String? monitorDeviceId,
    bool? monitorEnabled,
    int? volume,
  }) async {
    await _dio.post('/api/Soundboard/config', data: {
      'cableDeviceId': cableDeviceId,
      'monitorDeviceId': monitorDeviceId,
      'monitorEnabled': monitorEnabled,
      'volume': volume,
    });
  }

  /// Lista os aplicativos autorizados na allowlist do PC.
  Future<List<AllowedApp>> getApps() async {
    final response = await _dio.get('/api/apps');
    return (response.data as List)
        .map((e) => AllowedApp.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Inicia um aplicativo autorizado no PC com proteção contra repetição.
  Future<CommandJob> launchApp(
    String appId, {
    required String requestId,
    String? deviceId,
  }) async {
    final response = await _dio.post(
      '/api/apps/$appId/launch',
      data: {
        'requestId': requestId,
        'deviceId': deviceId,
      },
    );
    return CommandJob.fromJson(response.data as Map<String, dynamic>);
  }

  /// Encerra um aplicativo autorizado com confirmação obrigatória.
  Future<CommandJob> killApp(
    String appId, {
    required String requestId,
    required bool confirmed,
    int? processId,
    DateTime? startTimeUtc,
    String? deviceId,
  }) async {
    final response = await _dio.post(
      '/api/apps/$appId/kill',
      data: {
        'requestId': requestId,
        'confirmed': confirmed,
        'processId': processId,
        'startTimeUtc': startTimeUtc?.toIso8601String(),
        'deviceId': deviceId,
      },
    );
    return CommandJob.fromJson(response.data as Map<String, dynamic>);
  }

  /// Obtém histórico recente de execuções no PC.
  Future<List<CommandJob>> getJobs({String? deviceId, int limit = 50}) async {
    final response = await _dio.get(
      '/api/jobs',
      queryParameters: {
        if (deviceId != null) 'deviceId': deviceId,
        'limit': limit,
      },
    );
    return (response.data as List)
        .map((e) => CommandJob.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Limpa o histórico de execuções.
  Future<void> clearJobs({String? deviceId}) async {
    await _dio.delete(
      '/api/jobs',
      queryParameters: {
        if (deviceId != null) 'deviceId': deviceId,
      },
    );
  }

  /// Solicita uma captura manual do monitor principal no PC.
  Future<ScreenshotInfo> captureScreenshot({
    required String requestId,
    String? deviceId,
  }) async {
    final response = await _dio.post(
      '/api/screenshots/capture',
      data: {
        'requestId': requestId,
        if (deviceId != null) 'deviceId': deviceId,
      },
    );
    return ScreenshotInfo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Obtém os bytes da imagem de uma captura de tela ativa.
  Future<Uint8List> getScreenshotBytes(
    String screenshotId, {
    String? deviceId,
  }) async {
    final response = await _dio.get<List<int>>(
      '/api/screenshots/$screenshotId',
      queryParameters: {
        if (deviceId != null) 'deviceId': deviceId,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  /// Monta a URL completa para visualização da captura de tela.
  String getScreenshotUrl(String screenshotId, {String? deviceId}) {
    final base = _dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/api/screenshots/$screenshotId');
    if (deviceId != null) {
      return uri.replace(queryParameters: {'deviceId': deviceId}).toString();
    }
    return uri.toString();
  }

  /// Lista os arquivos autorizados na pasta de saída do PC ('outbound').
  Future<List<TransferItem>> listOutboundTransfers({String? deviceId}) async {
    final response = await _dio.get(
      '/api/transfers/outbound',
      options: deviceId != null ? Options(headers: {'X-Device-Id': deviceId}) : null,
    );
    final list = response.data as List<dynamic>;
    return list.map((e) => TransferItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Navega de forma segura pelos subdiretórios de 'outbound' ou 'inbound'.
  Future<DirectoryBrowseResult> browseDirectory(String rootId, {String? subPath, String? deviceId}) async {
    final response = await _dio.get(
      '/api/transfers/$rootId/browse',
      queryParameters: {
        if (subPath != null && subPath.isNotEmpty) 'subPath': subPath,
      },
      options: deviceId != null ? Options(headers: {'X-Device-Id': deviceId}) : null,
    );
    return DirectoryBrowseResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Baixa um arquivo localizado em subpastas de 'outbound'.
  Future<FileDownloadData> downloadNestedFile(String relativePath, {String? deviceId}) async {
    final response = await _dio.get<List<int>>(
      '/api/transfers/outbound/download',
      queryParameters: {'path': relativePath},
      options: Options(
        responseType: ResponseType.bytes,
        headers: deviceId != null ? {'X-Device-Id': deviceId} : null,
      ),
    );
    final sha256 = response.headers.value('X-Checksum-Sha256') ?? '';
    final name = relativePath.split('/').last;
    return FileDownloadData(
      fileName: name,
      bytes: Uint8List.fromList(response.data!),
      checksumSha256: sha256,
    );
  }

  /// Baixa um arquivo da pasta de saída do PC e retorna os bytes e hash SHA-256.
  Future<FileDownloadData> downloadOutboundFile(String fileName, {String? deviceId}) async {
    final response = await _dio.get<List<int>>(
      '/api/transfers/outbound/$fileName',
      options: Options(
        responseType: ResponseType.bytes,
        headers: deviceId != null ? {'X-Device-Id': deviceId} : null,
      ),
    );
    final sha256 = response.headers.value('X-Checksum-Sha256') ?? '';
    return FileDownloadData(
      fileName: fileName,
      bytes: Uint8List.fromList(response.data!),
      checksumSha256: sha256,
    );
  }

  /// Faz upload de um arquivo para a pasta 'inbound' do PC com SHA-256 esperado e RequestId.
  Future<UploadTransferResult> uploadInboundFile({
    required String fileName,
    required Uint8List bytes,
    String? expectedSha256,
    String? requestId,
    String? deviceId,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'rootId': 'inbound',
      if (expectedSha256 != null) 'expectedSha256': expectedSha256,
      if (requestId != null) 'requestId': requestId,
    });

    final response = await _dio.post(
      '/api/transfers/upload',
      data: formData,
      options: deviceId != null ? Options(headers: {'X-Device-Id': deviceId}) : null,
    );
    final item = TransferItem.fromJson(response.data as Map<String, dynamic>);
    return UploadTransferResult(success: true, item: item);
  }

  /// Consulta os serviços do Windows permitidos na allowlist de monitoramento (S3/S5).
  Future<List<WindowsServiceItem>> getServices({List<String>? names}) async {
    final Map<String, dynamic> query = {};
    if (names != null && names.isNotEmpty) {
      query['names'] = names.join(',');
    }
    final response = await _dio.get(
      '/api/services',
      queryParameters: query.isNotEmpty ? query : null,
    );
    final list = response.data as List<dynamic>;
    return list.map((e) => WindowsServiceItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Consulta os processos que mais consomem memória e CPU no PC (S3/S5).
  Future<TopProcessesData> getTopProcesses({int count = 5}) async {
    final response = await _dio.get(
      '/api/processes/top',
      queryParameters: {'count': count},
    );
    return TopProcessesData.fromJson(response.data as Map<String, dynamic>);
  }

  /// Realiza um ping de diagnóstico no servidor medindo o RTT (Round-Trip Time) em milissegundos (S8).
  Future<PingResult> ping() async {
    final sw = Stopwatch()..start();
    final response = await _dio.get('/api/ping');
    sw.stop();
    final latencyMs = sw.elapsedMilliseconds;
    final map = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    return PingResult.fromJson(map, latencyMs);
  }
}

