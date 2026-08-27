/// **Le rappel d'historique** — la flèche haut sur un champ vide.
///
/// ## Ce que le geste doit préserver
///
/// La flèche haut est d'abord une touche de **navigation** : dans un champ
/// multiligne, elle remonte d'une ligne. Un rappel d'historique qui la
/// capterait sans condition rendrait la saisie longue inutilisable, et le
/// défaut serait invisible sur un champ d'une seule ligne.
///
/// La règle retenue est donc la plus étroite qui rende le geste utile : le
/// rappel n'a lieu **que si le champ est vide**. Un champ vide n'a ni ligne
/// précédente, ni curseur ailleurs qu'à l'origine — il n'y a donc rien à
/// perdre. Dès qu'un caractère est saisi, la flèche haut reprend intégralement
/// son sens natif, et le socle ne la voit plus passer.
///
/// ## Un port, pas un journal
///
/// Le socle ne tient aucun historique de saisie : il demande à l'hôte quelle
/// entrée rappeler. [ZChatThreadHistory] est le branchement fourni — le
/// dernier message d'utilisateur du fil — et il reste remplaçable : un hôte
/// qui veut un anneau à plusieurs crans, un historique inter-conversations ou
/// une entrée persistée implémente son propre [ZChatComposerHistoryPort].
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import '../z_chat_controller.dart';
import 'z_chat_composer_edit.dart';

/// Intention « rappeler l'entrée précédente ».
class ZChatComposerHistoryIntent extends Intent {
  /// Construit l'intention.
  const ZChatComposerHistoryIntent();
}

/// Le port par lequel l'hôte dit **quoi** rappeler.
abstract interface class ZChatComposerHistoryPort {
  /// L'entrée à rappeler, ou `null` quand il n'y en a aucune.
  ///
  /// Appelée deux fois par geste — une fois pour savoir si le rappel a lieu,
  /// une fois pour l'exécuter : une implémentation doit être **pure et
  /// bon marché**, et ne rien consommer au passage.
  String? previous();
}

/// Port **inerte** : il n'y a jamais rien à rappeler.
class ZChatComposerNoHistory implements ZChatComposerHistoryPort {
  /// Construit le port inerte.
  const ZChatComposerNoHistory();

  @override
  String? previous() => null;
}

/// Rappelle le **dernier message d'utilisateur** du fil.
///
/// Un seul cran : c'est le geste que la plupart des saisies attendent, et le
/// port reste ouvert pour davantage. Les messages d'assistant, de système et
/// de rôle non reconnu sont ignorés — on ne rappelle jamais une réponse à la
/// place d'une question.
class ZChatThreadHistory implements ZChatComposerHistoryPort {
  /// Construit le rappel adossé à [controller].
  const ZChatThreadHistory(this.controller);

  /// Le contrôleur dont le fil est lu.
  final ZChatController controller;

  @override
  String? previous() {
    final List<ZChatMessage> fil = controller.messages.value;
    for (int i = fil.length - 1; i >= 0; i--) {
      final ZChatMessage m = fil[i];
      if (m.role != ZChatRole.user) continue;
      final String texte = m.content;
      // Un message vide — ou fait de blancs — n'est pas une entrée : le
      // rappeler remplacerait un champ vide par un champ vide, en avalant la
      // frappe pour rien.
      return texte.trim().isEmpty ? null : texte;
    }
    return null;
  }
}

/// L'action du rappel.
///
/// Elle est **désactivée** dès que le champ contient quelque chose, ou qu'il
/// n'y a rien à rappeler. Une action désactivée rend `KeyEventResult.ignored`
/// : la frappe poursuit sa route vers `DefaultTextEditingShortcuts`, et la
/// flèche haut y retrouve son sens de navigation, intact.
class ZChatComposerHistoryAction extends Action<ZChatComposerHistoryIntent> {
  /// Construit l'action.
  ZChatComposerHistoryAction({required this.composer, required this.history});

  /// La tranche de saisie — lue vivante, jamais capturée au montage.
  final TextEditingController composer;

  /// Le port consulté.
  final ZChatComposerHistoryPort history;

  @override
  bool isEnabled(ZChatComposerHistoryIntent intent) =>
      composer.text.isEmpty && history.previous() != null;

  @override
  Object? invoke(ZChatComposerHistoryIntent intent) {
    final String? entree = history.previous();
    if (entree == null) return null;
    // Le champ est vide (c'est la condition d'activation) : l'intervalle
    // remplacé est donc vide lui aussi, et le rappel n'écrase rien. Il passe
    // par le site d'écriture UNIQUE, qui pose le curseur en fin — c'est là
    // qu'on continue à écrire quand on reprend une question.
    zChatReplaceComposerRange(composer, start: 0, end: 0, text: entree);
    return null;
  }
}
