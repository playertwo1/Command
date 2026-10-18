import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum StreamQualityPreset {
  low(fps: 5, quality: 50, scale: 0.5, label: 'Econômica (5 FPS)'),
  medium(fps: 10, quality: 70, scale: 0.67, label: 'Balanceada (10 FPS)'),
  high(fps: 15, quality: 85, scale: 1.0, label: 'Alta (15 FPS)');

  final int fps;
  final int quality;
  final double scale;
  final String label;

  const StreamQualityPreset({
    required this.fps,
    required this.quality,
    required this.scale,
    required this.label,
  });
}

class DesktopStreamController extends ChangeNotifier {
  http.Client? _httpClient;
  StreamSubscription<List<int>>? _subscription;
  bool _isPlaying = false;
  Uint8List? _latestFrame;
  String? _errorMessage;
  int _fps = 0;
  final List<DateTime> _frameTimestamps = [];
  StreamQualityPreset _preset = StreamQualityPreset.medium;

  bool get isPlaying => _isPlaying;
  Uint8List? get latestFrame => _latestFrame;
  String? get errorMessage => _errorMessage;
  int get fps => _fps;
  StreamQualityPreset get preset => _preset;

  void setPreset(StreamQualityPreset newPreset) {
    if (_preset == newPreset) return;
    _preset = newPreset;
    notifyListeners();
  }

  @visibleForTesting
  void setStreamStateForTesting({bool? isPlaying, Uint8List? frame, int? fps, String? error}) {
    if (isPlaying != null) _isPlaying = isPlaying;
    if (frame != null) _latestFrame = frame;
    if (fps != null) _fps = fps;
    if (error != null) _errorMessage = error;
    notifyListeners();
  }

  Future<void> start({
    required String baseUrl,
    String? apiKey,
    http.Client? clientOverride,
  }) async {
    await stop();

    _isPlaying = true;
    _errorMessage = null;
    _frameTimestamps.clear();
    _fps = 0;
    notifyListeners();

    _httpClient = clientOverride ?? http.Client();

    final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse(
      '$cleanBase/api/stream/desktop?fps=${_preset.fps}&quality=${_preset.quality}&scale=${_preset.scale}',
    );

    try {
      final request = http.Request('GET', uri);
      if (apiKey != null && apiKey.isNotEmpty) {
        request.headers['X-API-KEY'] = apiKey;
      }
      request.headers['Accept'] = 'multipart/x-mixed-replace';

      final response = await _httpClient!.send(request);

      if (response.statusCode == 409) {
        _errorMessage = 'Ocupado: outro cliente já está conectado ao streaming.';
        _isPlaying = false;
        notifyListeners();
        return;
      }

      if (response.statusCode != 200) {
        _errorMessage = 'Falha ao iniciar streaming (HTTP ${response.statusCode}).';
        _isPlaying = false;
        notifyListeners();
        return;
      }

      final buffer = <int>[];

      _subscription = response.stream.listen(
        (chunk) {
          buffer.addAll(chunk);
          _extractFrames(buffer);
        },
        onError: (e) {
          if (_isPlaying) {
            _errorMessage = 'Conexão interrompida: $e';
            _isPlaying = false;
            notifyListeners();
          }
        },
        onDone: () {
          if (_isPlaying) {
            _isPlaying = false;
            notifyListeners();
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      _errorMessage = 'Erro de conexão: $e';
      _isPlaying = false;
      notifyListeners();
    }
  }

  void _extractFrames(List<int> buffer) {
    // Procura por delimitações de frame JPEG: SOI (0xFF, 0xD8) e EOI (0xFF, 0xD9)
    while (buffer.length >= 4) {
      int startIndex = -1;
      for (int i = 0; i < buffer.length - 1; i++) {
        if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
          startIndex = i;
          break;
        }
      }

      if (startIndex == -1) {
        // Nenhum início de JPEG encontrado, descarta bytes órfãos
        buffer.clear();
        break;
      }

      int endIndex = -1;
      for (int i = startIndex + 2; i < buffer.length - 1; i++) {
        if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
          endIndex = i + 1;
          break;
        }
      }

      if (endIndex == -1) {
        // Frame incompleto, aguarda mais chunks
        if (startIndex > 0) {
          buffer.removeRange(0, startIndex);
        }
        break;
      }

      // Frame JPEG completo localizado
      final frameBytes = Uint8List.fromList(buffer.sublist(startIndex, endIndex + 1));
      buffer.removeRange(0, endIndex + 1);

      _latestFrame = frameBytes;
      _recordFrameForFps();
      notifyListeners();
    }
  }

  void _recordFrameForFps() {
    final now = DateTime.now();
    _frameTimestamps.add(now);
    final cutoff = now.subtract(const Duration(seconds: 1));
    _frameTimestamps.removeWhere((t) => t.isBefore(cutoff));
    _fps = _frameTimestamps.length;
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Future<void> stop() async {
    _isPlaying = false;
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
    _httpClient?.close();
    _httpClient = null;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isPlaying = false;
    _subscription?.cancel();
    _subscription = null;
    _httpClient?.close();
    _httpClient = null;
    super.dispose();
  }
}
