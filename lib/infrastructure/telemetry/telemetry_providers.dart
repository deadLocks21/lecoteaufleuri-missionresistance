import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../application/services/logger_service.dart';
import '../../domain/ports/logger_port.dart';
import 'composite_logger.dart';
import 'console_logger.dart';
import 'log_context.dart';
import 'signoz_logger.dart';

/// Câblage de la télémétrie (sélection d'adapter + attributs de ressource).
///
/// Centralisé ici comme `di.dart` l'est pour les ports métier : tout ce qui
/// dépend du build (dart-define, mode release, OS) vit dans ce fichier, le
/// reste de l'app ne voit que `loggerProvider`.

/// Endpoint OTLP HTTP de Signoz au build, ex.
/// `https://ingest.eu.signoz.cloud:443/v1/logs`. Vide → Signoz désactivé.
///
/// Passé via :
/// `flutter run --dart-define=SIGNOZ_INGEST_URL=https://…/v1/logs`
const String _kSignozEndpoint = String.fromEnvironment('SIGNOZ_INGEST_URL');

/// Clé d'ingestion Signoz Cloud au build. Envoyée en `signoz-access-token`.
/// Laisser vide pour un self-hosted sans auth.
const String _kSignozKey = String.fromEnvironment('SIGNOZ_INGESTION_KEY');

/// Override optionnel de l'attribut `deployment.environment`.
/// Par défaut `production` en release, `development` sinon.
const String _kEnvOverride = String.fromEnvironment('SIGNOZ_ENV');

/// Version de l'app exposée en attribut de ressource `service.version`.
/// Le build CI injecte la vraie valeur via
/// `--dart-define=APP_VERSION=$VERSION+$BUILD_NUMBER`. Sinon un repère
/// `dev` pour que les builds locaux non configurés soient évidents dans Signoz.
const String _kAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

/// Unique [LoggerPort] de l'app (l'adapter concret sélectionné).
///
/// Logique de sélection :
///
/// | Mode    | SIGNOZ_INGEST_URL | Implémentation                       |
/// |---------|-------------------|--------------------------------------|
/// | release | non               | `ConsoleLogger` (fail-safe)          |
/// | release | oui               | `SignozLogger` seul                  |
/// | debug   | non               | `ConsoleLogger` seul                 |
/// | debug   | oui               | `CompositeLogger` : console + signoz |
///
/// La branche debug+signoz laisse le dev voir dans sa propre console
/// exactement ce qui est expédié.
///
/// `Provider` simple = gardé vivant tant que le container existe (l'adapter
/// Signoz tient un timer périodique + un client dio qu'il serait coûteux de
/// recréer à la demande).
final loggerPortProvider = Provider<LoggerPort>((ref) {
  final hasSignoz = _kSignozEndpoint.isNotEmpty;

  final console = ConsoleLogger(
    prefix: hasSignoz && !kReleaseMode ? '[→signoz]' : null,
  );

  if (!hasSignoz) {
    return console;
  }

  final signoz = SignozLogger(
    endpoint: _kSignozEndpoint,
    ingestionKey: _kSignozKey.isEmpty ? null : _kSignozKey,
    resourceAttributes: _resourceAttributes(),
  );
  ref.onDispose(signoz.dispose);

  if (kReleaseMode) {
    return signoz;
  }
  // Build debug avec Signoz câblé : on reflète vers la console pour calibrer.
  return CompositeLogger([console, signoz]);
});

/// Contexte de log mutable à l'échelle de l'app. Un [LogContext.sessionId] par
/// lancement. `Provider` simple → l'id de session reste stable.
final logContextProvider = Provider<LogContext>((ref) {
  return LogContext(sessionId: const Uuid().v4());
});

/// Façade ergonomique consommée par les services / l'UI / `main.dart`.
///
/// Le resolver de contexte dynamique lit [logContextProvider] via `ref.read`
/// (et non `ref.watch`) à chaque émission, pour que l'instance du logger reste
/// stable tout en portant le `session.id` courant. La reconstruire détruirait
/// le tampon de batch Signoz.
///
/// Attributs expédiés :
///
/// | Clé          | Source           | Quand              |
/// |--------------|------------------|--------------------|
/// | `session.id` | UUID par lancement | toujours          |
///
/// `service.version`, `os.type`, `deployment.environment`… sont attachés une
/// fois par batch comme attributs *de ressource* OTLP (cf. [loggerPortProvider]).
final loggerProvider = Provider<LoggerService>((ref) {
  return LoggerService(
    ref.watch(loggerPortProvider),
    resolveContext: () => ref.read(logContextProvider).toAttributes(),
  );
});

Map<String, Object?> _resourceAttributes() {
  String env;
  if (_kEnvOverride.isNotEmpty) {
    env = _kEnvOverride;
  } else {
    env = kReleaseMode ? 'production' : 'development';
  }
  return {
    'service.name': 'mission-resistance',
    'service.version': _kAppVersion,
    'deployment.environment': env,
    'os.type': _osType(),
    'container.name': 'mission-resistance-flutter',
    'host.name': 'com.lecoteaufleuri.missionresistance',
  };
}

String _osType() {
  // `Platform` est indisponible sur web ; on garde le catch par défense au cas
  // où la cible web serait activée.
  try {
    return Platform.operatingSystem;
  } catch (_) {
    return 'unknown';
  }
}
