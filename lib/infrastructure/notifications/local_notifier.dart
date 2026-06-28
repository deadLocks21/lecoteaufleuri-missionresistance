import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../ui/strings.dart';

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

  // v2 : canal recréé pour inclure le son custom (radio_static.wav).
  // Les canaux Android sont immuables — changer l'id force la recréation.
  static const String _channelId = 'mission_resistance_radio_v2';
  static const String _channelName = 'Messages radio';
  static const String _channelDescription =
      'Alerte quand un nouveau message arrive dans le groupe.';

  static const String _partieChannelId = 'mission_resistance_partie';
  static const String _partieChannelName = 'Fin de partie';
  static const String _partieChannelDescription =
      'Alerte quand le QG met fin à la partie.';
  // Id fixe : une seule notification « fin de partie » à la fois (les rappels
  // successifs remplacent la précédente plutôt que de s'empiler).
  static const int _partieEndedNotifId = 1;

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
        sound: RawResourceAndroidNotificationSound('radio_static'),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
        sound: 'radio_static.wav',
      ),
    );
    await _plugin.show(
      id: messageId.hashCode & 0x7fffffff,
      title: 'Nouveau message radio',
      body: sender,
      notificationDetails: details,
    );
  }

  /// Affiche une notification « partie terminée » pour ramener le joueur vers le
  /// poste (où l'écran de fin l'attend). Postée par l'isolate de suivi dès qu'il
  /// détecte la fin de partie (`410`), donc même app fermée.
  Future<void> showPartieEnded() async {
    await _ensureReady();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _partieChannelId,
        _partieChannelName,
        channelDescription: _partieChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.status,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
      ),
    );
    await _plugin.show(
      id: _partieEndedNotifId,
      title: Strings.partieEndedNotifTitle,
      body: Strings.partieEndedNotifBody,
      notificationDetails: details,
    );
  }
}
