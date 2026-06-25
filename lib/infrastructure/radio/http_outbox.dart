import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../http/api_headers.dart';
import '../../domain/entities/radio_message.dart';
import '../../domain/ports/outbox_port.dart';
import '../../domain/value_objects/recording.dart';
import 'radio_json.dart';

/// Adapter réseau de [OutboxPort] : diffuse une émission via
/// `POST /sessions/<teamId>/radio` (multipart : fichier `audio` + champ
/// `duration_ms`). Le backend persiste l'audio sur kDrive et l'indexe dans le
/// groupe de l'équipe. Le fichier temporaire local est supprimé après l'envoi.
class HttpOutbox implements OutboxPort {
  HttpOutbox({
    required String baseUrl,
    required this.teamId,
    this.partieId,
    Dio? dio,
  })  : _base = _trimTrailingSlash(baseUrl),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _trimTrailingSlash(baseUrl),
                connectTimeout: const Duration(seconds: 8),
                sendTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                headers: apiHeaders(partieId: partieId),
              ),
            );

  final Dio _dio;
  final String _base;
  final String teamId;

  /// Partie courante (scope serveur de l'émission). `null` = aucune partie.
  final String? partieId;

  String get _audioBase => '$_base/sessions/$teamId/radio';

  @override
  Future<RadioMessage> send(Recording recording) async {
    final file = File(recording.path);
    try {
      final form = FormData.fromMap({
        'duration_ms': recording.duration.inMilliseconds.toString(),
        'audio': await MultipartFile.fromFile(
          recording.path,
          filename: 'message.m4a',
          contentType: DioMediaType.parse(recording.contentType),
        ),
      });
      final resp = await _dio.post<Map<String, dynamic>>(
        '/sessions/$teamId/radio',
        data: form,
      );
      final message = resp.data?['message'];
      if (message is! Map<String, dynamic>) {
        throw const FormatException('réponse radio invalide');
      }
      return radioMessageFromJson(message, audioBase: _audioBase);
    } finally {
      // Émission ponctuelle : on ne conserve pas le fichier local.
      unawaited(file.delete().catchError((_) => file));
    }
  }

  static String _trimTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
