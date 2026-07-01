import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/value_objects/message_target.dart';
import '../session/session_controller.dart';

/// Destinataire courant d'un poste central / nazi : piloté par le sélecteur de la
/// vue radio, lu par [EmissionService] à l'envoi. Défaut : **tout le monde**.
/// Réinitialisé à chaque changement d'équipe (re-login), pour ne pas garder la
/// cible d'un poste précédent.
class SelectedRecipient extends Notifier<MessageTarget> {
  @override
  MessageTarget build() {
    // Dépendance = reset à `all` dès que l'équipe courante change.
    ref.watch(currentTeamProvider);
    return MessageTarget.all;
  }

  /// Choisit le destinataire de la prochaine émission.
  void select(MessageTarget target) => state = target;
}

final selectedRecipientProvider =
    NotifierProvider<SelectedRecipient, MessageTarget>(SelectedRecipient.new);
