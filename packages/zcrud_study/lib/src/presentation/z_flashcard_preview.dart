/// `ZFlashcardPreview` — aperçu **en lecture seule** d'une flashcard (SU-8,
/// AC14 — AD-45).
///
/// ## 🔴 Il ne rend RIEN lui-même : il COMPOSE `ZFlashcardReviewCard`
///
/// AD-45 exige qu'une carte s'ouvre en aperçu « rendu par `ZFlashcardReviewCard`
/// (su-2) — **jamais un rendu parallèle** ». Réécrire ici un affichage
/// question/réponse serait une **seconde surface de rendu** : elle divergerait au
/// premier changement de su-2 (une transition, un type de carte, un correctif de
/// contraste), et **aucun test ne rougirait** — les deux rendus seraient
/// simplement différents. C'est le même péché que la « 2e entité », en version
/// widget.
///
/// ⇒ Ce fichier est **mince par conception** : il choisit les callbacks, et
/// délègue **tout** le rendu.
///
/// ## La règle des actions : UNE seule, appliquée en UN seul endroit
///
/// `ZFlashcardReviewCard` porte **déjà** la règle « `onEdit`/`onDelete` `null` ⇒
/// action **ABSENTE** » **et** « jamais d'action si `card.isReadOnly` » (son
/// `_actionsAllowed`). Ce widget ne la **réimplémente pas** : il se contente de
/// ne pas fournir de callback sur une carte en lecture seule. Les deux voies
/// **convergent** vers la même absence — jamais deux règles concurrentes.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Aperçu d'une flashcard — **délègue le rendu** à [ZFlashcardReviewCard].
///
/// - [card] : carte affichée ;
/// - [onEdit]/[onDelete] : actions **injectées**. `null` ⇒ **ABSENTES** (AD-45,
///   jamais grisées). **Ignorées** si `card.isReadOnly` : une carte partagée ne
///   s'édite ni ne se supprime — c'est précisément le cas où « dupliquer pour
///   modifier » (FR-SU21) prend le relais ;
/// - [contentBuilder] : slot AD-40 **opt-in** (`null` ⇒ texte brut de su-1) ;
/// - [revealTransition] : transition **souhaitée** (Reduce Motion **prime**, su-2).
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

  /// Édition — `null` **ou** carte en lecture seule ⇒ action **ABSENTE**.
  final VoidCallback? onEdit;

  /// Suppression — `null` **ou** carte en lecture seule ⇒ action **ABSENTE**.
  final VoidCallback? onDelete;

  /// Slot de rendu de contenu **opt-in** (AD-40) — `null` ⇒ défaut de su-2.
  final ZFlashcardContentBuilder? contentBuilder;

  /// Transition de révélation souhaitée (Reduce Motion la neutralise — su-2).
  final ZRevealTransition revealTransition;

  /// `true` si la carte tolère des actions d'écriture (AD-45).
  ///
  /// Exposé pour que la règle soit **falsifiable** : c'est la voie que `build`
  /// emprunte réellement, pas une affirmation de dartdoc.
  @visibleForTesting
  bool get actionsAllowed => !card.isReadOnly;

  @override
  Widget build(BuildContext context) {
    // 🔴 AUCUN rendu propre : `ZFlashcardReviewCard` (su-2) est la SEULE surface
    // de rendu d'une carte. Ce widget ne décide QUE des callbacks.
    return ZFlashcardReviewCard(
      card: card,
      revealTransition: revealTransition,
      contentBuilder: contentBuilder,
      // AD-45 : lecture seule ⇒ `null` ⇒ ABSENTE (jamais grisée). La carte
      // porte elle aussi cette garde (`_actionsAllowed`) : les deux voies
      // convergent vers la MÊME absence, jamais vers deux règles concurrentes.
      onEdit: actionsAllowed ? onEdit : null,
      onDelete: actionsAllowed ? onDelete : null,
    );
  }
}
