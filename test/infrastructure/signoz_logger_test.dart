import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mission_resistance/domain/value_objects/log_level.dart';
import 'package:mission_resistance/infrastructure/telemetry/signoz_logger.dart';

/// Adapter dio qui capture la requête au lieu de toucher le réseau, et renvoie
/// un 200 vide. Permet d'assert le payload OTLP exact expédié à Signoz.
class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  String? lastBody;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    lastOptions = options;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      lastBody = utf8.decode(chunks.expand((c) => c).toList());
    }
    return ResponseBody.fromString(
      '',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Extrait la valeur d'un attribut depuis la liste `KeyValue[]` OTLP.
Object? _attr(List<dynamic> attributes, String key) {
  for (final a in attributes.cast<Map<String, dynamic>>()) {
    if (a['key'] == key) {
      final value = a['value'] as Map<String, dynamic>;
      return value.values.first;
    }
  }
  return null;
}

void main() {
  late _CapturingAdapter adapter;
  late SignozLogger logger;

  SignozLogger build({String? ingestionKey}) {
    final dio = Dio()..httpClientAdapter = adapter;
    return SignozLogger(
      endpoint: 'https://ingest.test/v1/logs',
      ingestionKey: ingestionKey,
      resourceAttributes: const {
        'service.name': 'mission-resistance',
        'service.version': '1.2.3+45',
        'deployment.environment': 'production',
        'os.type': 'ios',
      },
      // Très long pour que le timer périodique ne déclenche pas d'envoi
      // pendant le test — on pilote le flush manuellement.
      flushInterval: const Duration(hours: 1),
      dio: dio,
    );
  }

  setUp(() => adapter = _CapturingAdapter());
  tearDown(() => logger.dispose());

  test('expédie un payload OTLP avec les attributs de ressource (version, env)',
      () async {
    logger = build(ingestionKey: 'secret-key');

    await logger.log(
      LogLevel.info,
      'app.started',
      attributes: {'session.id': 'sess-1'},
    );
    await logger.flush();

    expect(adapter.callCount, 1);
    expect(adapter.lastOptions!.path, 'https://ingest.test/v1/logs');
    // La clé d'ingestion part en header signoz-access-token.
    expect(adapter.lastOptions!.headers['signoz-access-token'], 'secret-key');

    final body = jsonDecode(adapter.lastBody!) as Map<String, dynamic>;
    final resourceLog = (body['resourceLogs'] as List).single as Map;

    // Attributs de ressource : c'est là que vivent version + env.
    final resAttrs =
        ((resourceLog['resource'] as Map)['attributes'] as List);
    expect(_attr(resAttrs, 'service.name'), 'mission-resistance');
    expect(_attr(resAttrs, 'service.version'), '1.2.3+45');
    expect(_attr(resAttrs, 'deployment.environment'), 'production');
    expect(_attr(resAttrs, 'os.type'), 'ios');

    // L'enregistrement lui-même : sévérité OTel + corps + attributs.
    final scopeLog = ((resourceLog['scopeLogs'] as List).single as Map);
    final record = (scopeLog['logRecords'] as List).single as Map;
    expect(record['severityText'], 'INFO');
    expect(record['severityNumber'], 9);
    expect((record['body'] as Map)['stringValue'], 'app.started');
    expect(_attr(record['attributes'] as List, 'session.id'), 'sess-1');
  });

  test('sans clé d\'ingestion, aucun header d\'auth', () async {
    logger = build(ingestionKey: null);

    await logger.log(LogLevel.warn, 'something');
    await logger.flush();

    expect(adapter.callCount, 1);
    expect(
      adapter.lastOptions!.headers.containsKey('signoz-access-token'),
      isFalse,
    );
  });

  test('une erreur sérialise type + message d\'exception', () async {
    logger = build();

    await logger.log(
      LogLevel.error,
      'boom',
      error: StateError('bad state'),
    );
    await logger.flush();

    final body = jsonDecode(adapter.lastBody!) as Map<String, dynamic>;
    final record = ((((body['resourceLogs'] as List).single
            as Map)['scopeLogs'] as List)
        .single as Map)['logRecords'] as List;
    final attrs = (record.single as Map)['attributes'] as List;
    expect(_attr(attrs, 'exception.type'), 'StateError');
    expect(_attr(attrs, 'exception.message'), contains('bad state'));
  });

  test('flush sans rien en tampon n\'émet aucune requête', () async {
    logger = build();
    await logger.flush();
    expect(adapter.callCount, 0);
  });
}
