import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/mission_resistance_app.dart';
import 'application/services/logger_service.dart';
import 'infrastructure/telemetry/telemetry_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Port de communication isolate d'arrière-plan (suivi GPS) → isolate UI,
  // pour remonter les points capturés tant que l'app est ouverte.
  FlutterForegroundTask.initCommunicationPort();

  // Orientation portrait verrouillée + rendu edge-to-edge (BRIEF §13).
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Container Riverpod construit à la main pour lire le logger AVANT `runApp`
  // et câbler les handlers d'erreurs framework ci-dessous.
  final container = ProviderContainer();
  final logger = container.read(loggerProvider);

  _installErrorHandlers(logger);
  logger.info('app.started');

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MissionResistanceApp(),
    ),
  );
}

/// Route les erreurs Flutter/Dart non capturées vers le logger.
///
/// Deux hooks couvrent l'essentiel des défaillances côté Dart :
///
/// - [FlutterError.onError] — erreurs synchrones levées par le framework
///   (build de widget, layout, render, assertions).
/// - [PlatformDispatcher.onError] — erreurs Dart asynchrones qui échappent à
///   tout `Future`/`Stream`/zone au-dessus d'elles (le filet de dernier
///   recours introduit en Flutter 3.3).
///
/// Les crashs natifs (Swift/Obj-C sur iOS, JVM sur Android, libs FFI) passent
/// à côté des deux — ils tuent l'isolate Dart avant que l'un ou l'autre ne
/// s'exécute. Ajouter Crashlytics ou Sentry si ça devient un enjeu.
void _installErrorHandlers(LoggerService logger) {
  final defaultOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    logger.error(
      'flutter.error',
      error: details.exception,
      stack: details.stack,
      attrs: {
        if (details.library != null) 'flutter.library': details.library!,
        if (details.context != null)
          'flutter.context': details.context!.toString(),
      },
    );
    // On garde le comportement par défaut (écran rouge en debug, dump console
    // ailleurs) pour ne pas masquer silencieusement les erreurs en dev.
    defaultOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error('dart.uncaught', error: error, stack: stack);
    // `true` marque l'erreur comme gérée : l'app continue de tourner plutôt
    // que de laisser l'erreur remonter à la plateforme.
    return true;
  };

  if (kDebugMode) {
    // Ceinture + bretelles : rend visible l'init du logger dans la console, si
    // bien que la première ligne de chaque run de dev est visible.
    debugPrint('logger: error handlers installed');
  }
}
