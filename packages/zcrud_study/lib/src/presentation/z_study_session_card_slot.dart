/// Créneau de carte de l'écran de session **assemblé** : ce que l'assemblage
/// sait de la carte qu'il fait rendre, offert à l'hôte qui compose la sienne.
///
/// Un hôte qui compose sa propre carte (badge de type, bandeau de consigne)
/// n'abandonne pas pour autant l'assemblage : il lui manque seulement deux
/// informations que la pile et l'écran détiennent, et qu'il devrait sinon
/// refabriquer — **quelle carte est devant**, et **si la réponse est
/// dévoilée**. Les refabriquer demanderait de posséder un contrôleur d'index et
/// un contrôleur de révélation, donc de tenir une seconde source de vérité à
/// côté de celle de l'assemblage.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcard;
import 'package:zcrud_session/zcrud_session.dart'
    show ZSessionCardSlot, ZSessionItem;

/// Créneau de construction d'une carte, côté écran assemblé.
///
/// Compose le créneau de la pile ([slot] — item, rang, `isFront`) plutôt que
/// d'en redéclarer les champs : le rang et la position restent définis à un
/// seul endroit. S'y ajoute ce que la pile ne connaît pas — la [card] résolue
/// par identité, et l'état de révélation de l'écran.
@immutable
class ZStudySessionCardSlot {
  /// Construit le créneau.
  const ZStudySessionCardSlot({
    required this.slot,
    required this.card,
    required this.revealed,
    this.toggleReveal,
  });

  /// Créneau de la pile : item, rang dans la file, et `isFront`.
  final ZSessionCardSlot slot;

  /// Carte résolue par **identité** (jamais par index).
  final ZFlashcard card;

  /// Vrai quand la réponse est dévoilée.
  ///
  /// Toujours `false` pour une carte qui n'est pas devant : la réponse de la
  /// carte suivante ne se lit jamais avant sa question.
  final bool revealed;

  /// Bascule l'état de révélation, ou `null` quand la révélation n'est pas
  /// offerte (carte empilée derrière le front, ou politique de révélation qui
  /// ne l'offre pas dans ce mode).
  ///
  /// `null` signifie « pas de commande », jamais « commande inerte » : un
  /// contrôle composé sous cette condition n'existe pas plutôt que d'exister
  /// mort.
  final VoidCallback? toggleReveal;

  /// Item de la file rendu par ce créneau.
  ZSessionItem get item => slot.item;

  /// Rang de [item] dans la file.
  int get index => slot.index;

  /// Vrai pour la seule carte de devant — celle que le geste emporte.
  bool get isFront => slot.isFront;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudySessionCardSlot &&
          other.slot == slot &&
          other.card == card &&
          other.revealed == revealed &&
          other.toggleReveal == toggleReveal;

  @override
  int get hashCode => Object.hash(slot, card, revealed, toggleReveal);

  @override
  String toString() => 'ZStudySessionCardSlot(index: $index, '
      'isFront: $isFront, revealed: $revealed)';
}

/// Construit la carte d'affichage d'un [ZStudySessionCardSlot].
///
/// Fournie à `ZStudySessionHost.cardSlotBuilder`, elle **remplace** le
/// `cardBuilder` de l'écran pour toutes les cartes de la pile.
typedef ZStudySessionCardSlotBuilder = Widget Function(
  BuildContext context,
  ZStudySessionCardSlot slot,
);
