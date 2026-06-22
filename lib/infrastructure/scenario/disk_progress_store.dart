import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/ports/progress_store.dart';
import '../../domain/value_objects/mission_progress.dart';
import 'progress_json.dart';

/// Adapter de [ProgressStore] qui persiste la progression **localement**
/// (`shared_preferences` — vérité front + repli hors-ligne) **et** la pousse au
/// backend (`PUT /sessions/<teamId>/progress`).
///
/// - [read] est **local-first** : on rend la copie locale si elle existe (l'app
///   est l'autorité pendant la partie, y compris hors-ligne) ; on n'interroge le
///   backend que pour **amorcer** un appareil vierge (réinstallation, autre
///   téléphone). Cela évite d'écraser une progression locale plus récente par
///   une copie serveur en retard.
/// - [write] écrit toujours en local, puis pousse au backend. Le push reprend
///   l'idée du buffer hors-ligne de `HttpPositionReporter`, **simplifié** : la
///   progression est last-write-wins, donc un **seul état en attente**
///   ([_pending], écrasé par le plus récent) + un retry périodique qui rattrape
///   au retour du réseau.
class DiskProgressStore implements ProgressStore {
  DiskProgressStore({
    required this.teamId,
    required this.partieId,
    required String baseUrl,
    Dio? dio,
    this.retryInterval = const Duration(seconds: 20),
  })  : _path = '/sessions/$teamId/progress',
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _trimTrailingSlash(baseUrl),
                connectTimeout: const Duration(seconds: 8),
                sendTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                contentType: 'application/json',
                headers: {'X-Partie-Id': partieId},
              ),
            );

  final String teamId;

  /// Partie courante : scope la progression (en-tête `X-Partie-Id` + clé de
  /// cache local) → ardoise vierge à chaque nouvelle partie.
  final String partieId;
  final String _path;
  final Dio _dio;
  final Duration retryInterval;

  MissionProgress? _pending;
  Future<void>? _inflight;
  Timer? _retryTimer;

  /// Préfixe des clés `shared_preferences` (une entrée par (équipe, partie)).
  static const String keyPrefix = 'progress_cache:';

  String get _key => '$keyPrefix$teamId:$partieId';

  static String _trimTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// Efface la progression mise en cache de **toutes** les équipes
  /// (réinitialisation du poste). N'affecte pas le backend.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(keyPrefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  @override
  Future<MissionProgress?> read() async {
    final local = await _readLocal();
    if (local != null) return local;

    // Pas de cache local (appareil vierge) → on tente d'amorcer depuis le back.
    try {
      final resp = await _dio.get<Map<String, dynamic>>(_path);
      final progress = resp.data?['progress'];
      if (progress is Map<String, dynamic>) {
        final remote = progressFromJson(progress);
        await _writeLocal(remote);
        return remote;
      }
    } catch (_) {
      // hors-ligne / serveur indisponible → rien à amorcer
    }
    return null;
  }

  @override
  Future<void> write(MissionProgress progress) async {
    await _writeLocal(progress); // vérité front, toujours
    _pending = progress; // dernier état à pousser
    unawaited(_push());
  }

  /// Pousse l'état en attente, en coalesçant les envois concurrents.
  Future<void> _push() async {
    if (_inflight != null) return _inflight;
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    final future = _ship(pending);
    _inflight = future;
    try {
      await future;
    } finally {
      _inflight = null;
    }
    if (_pending != null) unawaited(_push()); // un état plus récent est arrivé
  }

  Future<void> _ship(MissionProgress progress) async {
    try {
      await _dio.put<dynamic>(_path, data: progressToJson(progress));
      _retryTimer?.cancel();
      _retryTimer = null;
    } on DioException catch (e) {
      // Partie terminée (410) : inutile de réessayer — la progression de cette
      // partie est close. On abandonne l'état en attente (le contrôleur de
      // partie bascule l'UI en « terminée » via son poll).
      if (e.response?.statusCode == 410) {
        _pending = null;
        _retryTimer?.cancel();
        _retryTimer = null;
        return;
      }
      // Échec réseau : on remet l'état en attente (sauf s'il a déjà été remplacé
      // par un plus récent) et on arme un retry périodique.
      _pending ??= progress;
      _armRetry();
      developer.log(
        'scenario: progression non synchronisée — réessai différé',
        name: 'mission_resistance.scenario',
        level: 900,
        error: e,
      );
    } catch (e) {
      // Erreur inattendue (non réseau) : on retente plus tard, best-effort.
      _pending ??= progress;
      _armRetry();
      developer.log(
        'scenario: progression non synchronisée — réessai différé',
        name: 'mission_resistance.scenario',
        level: 900,
        error: e,
      );
    }
  }

  void _armRetry() {
    _retryTimer ??= Timer.periodic(retryInterval, (_) {
      if (_pending == null) {
        _retryTimer?.cancel();
        _retryTimer = null;
        return;
      }
      unawaited(_push());
    });
  }

  Future<MissionProgress?> _readLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return progressFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLocal(MissionProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(progressToJson(progress)));
  }
}
