import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Poste les notifications locales « nouveau message radio ».
///
/// Conçu pour tourner dans l'**isolate d'arrière-plan** du suivi (le seul poller
/// pendant la partie) : il s'initialise à la demande (`DartPluginRegistrant`
/// déjà appelé par `startTrackingCallback`). Le canal Android est **distinct**
/// de celui du service de premier plan (`mission_resistance_tracking`) pour ne
/// pas écraser la notification permanente du suivi.
class LocalNotifier {
  LocalNotifier({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const String _channelId = 'mission_resistance_radio';
  static const String _channelName = 'Messages radio';
  static const String _channelDescription =
      'Alerte quand un nouveau message arrive dans le groupe.';

  Future<void> _ensureReady() async {
    if (_ready) return;
    // La permission POST_NOTIFICATIONS (Android 13+) / l'autorisation iOS sont
    // déjà demandées côté UI au démarrage du suivi
    // (`TrackingService._ensureNotificationPermission`). On ne re-demande pas ici
    // (l'isolate de fond n'a pas d'UI pour répondre au dialogue).
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
    _ready = true;
  }

  /// Affiche une notification pour un message reçu d'un autre poste du groupe.
  /// L'`id` stable (dérivé de l'id du message) évite d'empiler des doublons si
  /// le même message était notifié deux fois.
  Future<void> showNewMessage({
    required String messageId,
    required String sender,
  }) async {
    await _ensureReady();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: messageId.hashCode & 0x7fffffff,
      title: 'Nouveau message radio',
      body: sender,
      notificationDetails: details,
    );
  }
}
