import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:command/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T0 - Resumable Transfers Models', () {
    test('ChunkUploadResponse deserializes correctly', () {
      final json = {
        'success': true,
        'errorCode': '',
        'errorMessage': '',
        'uploadId': 'upl-123',
        'fileName': 'arquivo.zip',
        'bytesReceived': 4194304,
        'isComplete': true,
        'item': {
          'name': 'arquivo.zip',
          'sizeBytes': 4194304,
          'sha256': 'hash123',
          'modifiedAtUtc': '2026-10-26T10:00:00Z',
        },
      };

      final resp = ChunkUploadResponse.fromJson(json);
      expect(resp.success, isTrue);
      expect(resp.uploadId, 'upl-123');
      expect(resp.fileName, 'arquivo.zip');
      expect(resp.bytesReceived, 4194304);
      expect(resp.isComplete, isTrue);
      expect(resp.item?.sha256, 'hash123');
    });

    test('ResumableUploadStatus deserializes correctly', () {
      final json = {
        'exists': true,
        'uploadId': 'upl-resume',
        'fileName': 'dados.bin',
        'bytesReceived': 2097152,
        'totalSize': 8388608,
        'isComplete': false,
      };

      final status = ResumableUploadStatus.fromJson(json);
      expect(status.exists, isTrue);
      expect(status.uploadId, 'upl-resume');
      expect(status.fileName, 'dados.bin');
      expect(status.bytesReceived, 2097152);
      expect(status.totalSize, 8388608);
      expect(status.isComplete, isFalse);
    });
  });

  group('T0 - Client Resumable Upload Flow', () {
    late Dio dio;
    late CommandClient client;
    late List<Map<String, dynamic>> recordedRequests;
    ResumableUploadStatus currentStatus = const ResumableUploadStatus(
      exists: false,
      uploadId: '',
      fileName: '',
      bytesReceived: 0,
      totalSize: 0,
      isComplete: false,
    );
    bool failNextChunk = false;
    String failErrorCode = 'WRITE_FAILED';

    setUp(() {
      dio = Dio();
      recordedRequests = [];
      failNextChunk = false;
      currentStatus = const ResumableUploadStatus(
        exists: false,
        uploadId: '',
        fileName: '',
        bytesReceived: 0,
        totalSize: 0,
        isComplete: false,
      );

      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'GET' && options.path.contains('/api/transfers/upload/status')) {
            recordedRequests.add({
              'method': 'GET',
              'path': options.path,
              'query': options.queryParameters,
            });
            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'exists': currentStatus.exists,
                'uploadId': currentStatus.uploadId,
                'fileName': currentStatus.fileName,
                'bytesReceived': currentStatus.bytesReceived,
                'totalSize': currentStatus.totalSize,
                'isComplete': currentStatus.isComplete,
              },
            ));
          }

          if (options.method == 'GET' && options.path.contains('/api/transfers/outbound/')) {
            recordedRequests.add({
              'method': 'GET',
              'path': options.path,
              'query': options.queryParameters,
              'headers': options.headers,
            });
            final offset = options.queryParameters['offset'] as int? ?? 0;
            final length = options.queryParameters['length'] as int? ?? 10;
            final fullData = utf8.encode('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ');
            final chunk = fullData.sublist(offset, offset + length);
            final sha = sha256.convert(chunk).toString();

            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 206,
              data: chunk,
              headers: Headers.fromMap({
                'X-Checksum-Sha256': [sha],
                'Content-Range': ['bytes $offset-${offset + length - 1}/${fullData.length}'],
              }),
            ));
          }

          if (options.method == 'POST' && options.path.contains('/api/transfers/upload/chunk')) {
            final formData = options.data as FormData;
            final map = <String, dynamic>{};
            for (final field in formData.fields) {
              map[field.key] = field.value;
            }
            recordedRequests.add({
              'method': 'POST',
              'path': options.path,
              'fields': map,
              'filesCount': formData.files.length,
            });

            if (failNextChunk) {
              return handler.resolve(Response(
                requestOptions: options,
                statusCode: 400,
                data: {
                  'success': false,
                  'errorCode': failErrorCode,
                  'errorMessage': 'Falha simulada no envio do bloco',
                  'uploadId': map['uploadId'],
                  'fileName': map['fileName'],
                  'bytesReceived': 0,
                  'isComplete': false,
                },
              ));
            }

            final isLast = map['isLastChunk'] == 'true';
            final offset = int.parse(map['offset'] as String);
            final totalSize = int.parse(map['totalSize'] as String);
            final currentEnd = isLast ? totalSize : (offset + 300);

            return handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'errorCode': '',
                'errorMessage': '',
                'uploadId': map['uploadId'],
                'fileName': map['fileName'],
                'bytesReceived': currentEnd,
                'isComplete': isLast,
                if (isLast)
                  'item': {
                    'name': map['fileName'],
                    'sizeBytes': totalSize,
                    'sha256': map['expectedSha256'] ?? 'simulated_sha',
                    'modifiedAtUtc': DateTime.now().toUtc().toIso8601String(),
                  },
              },
            ));
          }

          handler.next(options);
        },
      ));

      client = CommandClient(baseUrl: 'http://localhost:4787', dio: dio);
    });

    test('uploadFileResumable divides into chunks and completes successfully', () async {
      final testData = Uint8List(1000);
      for (int i = 0; i < testData.length; i++) {
        testData[i] = i % 256;
      }
      final expectedHash = sha256.convert(testData).toString().toLowerCase();
      final progressEvents = <int>[];

      final result = await client.uploadFileResumable(
        fileName: 'teste.bin',
        bytes: testData,
        uploadId: 'upl-test-01',
        chunkSize: 300,
        onProgress: (sent, total) {
          progressEvents.add(sent);
        },
      );

      expect(result.success, isTrue);
      expect(result.isComplete, isTrue);
      expect(result.bytesReceived, 1000);

      final posts = recordedRequests.where((r) => r['method'] == 'POST').toList();
      expect(posts.length, 4);

      expect(posts[0]['fields']['offset'], '0');
      expect(posts[0]['fields']['isLastChunk'], 'false');

      expect(posts[1]['fields']['offset'], '300');
      expect(posts[1]['fields']['isLastChunk'], 'false');

      expect(posts[2]['fields']['offset'], '600');
      expect(posts[2]['fields']['isLastChunk'], 'false');

      expect(posts[3]['fields']['offset'], '900');
      expect(posts[3]['fields']['isLastChunk'], 'true');
      expect(posts[3]['fields']['expectedSha256'], expectedHash);

      expect(progressEvents, containsAllInOrder([300, 600, 900, 1000]));
    });

    test('uploadFileResumable resumes from existing byte offset', () async {
      final testData = Uint8List(1000);
      currentStatus = const ResumableUploadStatus(
        exists: true,
        uploadId: 'upl-resumed',
        fileName: 'teste.bin',
        bytesReceived: 600,
        totalSize: 0,
        isComplete: false,
      );

      final progressEvents = <int>[];

      final result = await client.uploadFileResumable(
        fileName: 'teste.bin',
        bytes: testData,
        uploadId: 'upl-resumed',
        chunkSize: 300,
        onProgress: (sent, total) {
          progressEvents.add(sent);
        },
      );

      expect(result.success, isTrue);
      expect(result.isComplete, isTrue);

      final posts = recordedRequests.where((r) => r['method'] == 'POST').toList();
      expect(posts.length, 2);
      expect(posts[0]['fields']['offset'], '600');
      expect(posts[1]['fields']['offset'], '900');
      expect(posts[1]['fields']['isLastChunk'], 'true');

      expect(progressEvents.first, 600);
    });

    test('uploadFileResumable returns immediately if already complete', () async {
      final testData = Uint8List(1000);
      currentStatus = const ResumableUploadStatus(
        exists: true,
        uploadId: 'upl-done',
        fileName: 'concluido.zip',
        bytesReceived: 1000,
        totalSize: 1000,
        isComplete: true,
      );

      final result = await client.uploadFileResumable(
        fileName: 'concluido.zip',
        bytes: testData,
        uploadId: 'upl-done',
        chunkSize: 300,
      );

      expect(result.success, isTrue);
      expect(result.isComplete, isTrue);

      final posts = recordedRequests.where((r) => r['method'] == 'POST').toList();
      expect(posts, isEmpty);
    });

    test('uploadFileResumable halts and reports error when a chunk fails', () async {
      final testData = Uint8List(1000);
      failNextChunk = true;
      failErrorCode = 'CHUNK_OFFSET_GAP';

      final result = await client.uploadFileResumable(
        fileName: 'erro.bin',
        bytes: testData,
        uploadId: 'upl-fail',
        chunkSize: 300,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'CHUNK_OFFSET_GAP');
    });

    test('downloadOutboundFile supports offset and length range query', () async {
      final res = await client.downloadOutboundFile(
        'relatorio.txt',
        offset: 10,
        length: 5,
      );

      expect(res.bytes.length, 5);
      final getReq = recordedRequests.firstWhere((r) => r['method'] == 'GET' && r['path'].contains('/outbound/'));
      expect(getReq['query']['offset'], 10);
      expect(getReq['query']['length'], 5);
      expect(getReq['headers']['Range'], 'bytes=10-14');
    });
  });
}
