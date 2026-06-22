import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../domain/entities/radio_message.dart';
import '../../domain/ports/inbox_port.dart';
import '../../domain/value_objects/message_id.dart';
import 'http_inbox.dart';
import 'radio_json.dart';

/// Adapter [InboxPort] **côté UI** quand le suivi de premier plan est le seul
/// poller (cf. discussion archi notifications) :
///
/// - [fetch] : chargement initial / rafraîchissement du backlog via HTTP
///   (délégué à [HttpInbox]) — c'est le « refresh » au montage de l'écran et au
///   retour au premier plan ;
/// - [incoming] : **pas** de sondage HTTP ici ; les nouveaux messages sont
///   poussés par l'isolate d'arrière-plan du suivi via `sendDataToMain`, reçus
///   sur le canal `TaskData`. L'app au premier plan se met ainsi à jour en live
///   sans dupliquer le poll de fond.
class PushInbox implements InboxPort {
  PushInbox({required String baseUrl, required String teamId})
      : _http = HttpInbox(baseUrl: baseUrl, teamId: teamId);

  final HttpInbox _http;

  @override
  Future<List<RadioMessage>> fetch() => _http.fetch();

  @override
  Future<void> markHeard(MessageId id) => _http.markHeard(id);

  @override
  Stream<RadioMessage> incoming() {
    final controller = StreamController<RadioMessage>();
    void onData(Object data) {
      if (data is Map && data['event'] == kRadioMessageEvent) {
        controller.add(radioMessageFromData(data));
      }
    }

    FlutterForegroundTask.addTaskDataCallback(onData);
    controller.onCancel = () {
      FlutterForegroundTask.removeTaskDataCallback(onData);
    };
    return controller.stream;
  }
}
