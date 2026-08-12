/// `ZFlashcardPreview` — aperçu en lecture seule d'une flashcard.
///
/// ## Il ne rend rien lui-même : il compose `ZFlashcardReviewCard`
///
/// Une carte doit s'ouvrir en aperçu rendu par `ZFlashcardReviewCard` —
/// jamais un rendu parallèle. Réécrire ici un affichage
/// question/réponse serait une seconde surface de rendu : elle divergerait au
/// premier changement de `ZFlashcardReviewCard` (une transition, un type de
/// carte, un correctif de contraste), et aucun test ne rougirait — les deux
/// rendus seraient simplement différents. C'est le même péché que la « 2e
/// entité », en version widget.
///
/// ⇒ Ce fichier est mince par conception : il choisit les callbacks, et
/// délègue tout le rendu.
///
/// ## La règle des actions : une seule, appliquée en un seul endroit
///
/// `ZFlashcardReviewCard` porte déjà la règle « `onEdit`/`onDelete` `null` ⇒
/// action absente » et « jamais d'action si `card.isReadOnly` » (son
/// `_actionsAllowed`). Ce widget ne la réimplémente pas : il se contente de
/// ne pas fournir de callback sur une carte en lecture seule. Les deux voies
/// convergent vers la même absence — jamais deux règles concurrentes.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Aperçu d'une flashcard — délègue le rendu à [ZFlashcardReviewCard].
///
/// - [card] : carte affichée ;
/// - [onEdit]/[onDelete] : actions injectées. `null` ⇒ absentes (invariant
///   AD-4, jamais grisées). Ignorées si `card.isReadOnly` : une carte
///   partagée ne s'édite ni ne se supprime — c'est précisément le cas où
///   dupliquer pour modifier prend le relais ;
/// - [contentBuilder] : slot opt-in (`null` ⇒ texte brut par défaut) ;
/// - [revealTransition] : transition souhaitée (Reduce Motion prime).
class ZFlashcardPreview extends StatelessWidget {
  /// Construit l'aperçu de [card].
  const ZFlashcardPreview({
    required this.card,
    this.onEdit,
    this.onDelete,
    this.contentBuilder,
    this.revealTransition = ZRevealTransition.flip3d,
    super.key,
  });

  /// Carte affichée (immuable).
  final ZFlashcard card;

  /// Édition — `null` ou carte en lecture seule ⇒ action absente.
  final VoidCallback? onEdit;

  /// Suppression — `null` ou carte en lecture seule ⇒ action absente.
  final VoidCallback? onDelete;

  /// Slot de rendu de contenu opt-in — `null` ⇒ défaut de
  /// `ZFlashcardReviewCard`.
  final ZFlashcardContentBuilder? contentBuilder;

  /// Transition de révélation souhaitée (Reduce Motion la neutralise).
  final ZRevealTransition revealTransition;

  /// `true` si la carte tolère des actions d'écriture.
  ///
  /// Exposé pour que la règle soit **falsifiable** : c'est la voie que `build`
  /// emprunte réellement, pas une affirmation de dartdoc.
  @visibleForTesting
  bool get actionsAllowed => !card.isReadOnly;

  @override
  Widget build(BuildContext context) {
    // Aucun rendu propre : `ZFlashcardReviewCard` est la seule surface
    // de rendu d'une carte. Ce widget ne décide que des callbacks.
    return ZFlashcardReviewCard(
      card: card,
      revealTransition: revealTransition,
      contentBuilder: contentBuilder,
      // Lecture seule ⇒ `null` ⇒ absente (jamais grisée). La carte
      // porte elle aussi cette garde (`_actionsAllowed`) : les deux voies
      // convergent vers la même absence, jamais vers deux règles concurrentes.
      onEdit: actionsAllowed ? onEdit : null,
      onDelete: actionsAllowed ? onDelete : null,
    );
  }
}
