/// Catégorisation pure des cartes pour le sélecteur de session.
///
/// Vit dans `zcrud_flashcard` : la catégorisation exige à la fois
/// `ZFlashcard` et `ZRepetitionInfo` — ce paquet est le premier point du
/// graphe qui voit les deux. Le noyau d'étude ne peut pas l'héberger (il
/// ignore `ZRepetitionInfo`), et le paquet de session ne le doit pas (cette
/// logique appartient au domaine, pas à la présentation).
///
/// Pure (invariant AD-14) : aucune E/S, aucun `DateTime.now()` — l'instant
/// est un paramètre. Aucun moteur n'est touché, aucune écriture SRS : cette
/// fonction lit l'état SRS, elle ne l'avance jamais.
///
/// ## Lookup O(1) par carte
///
/// L'état SRS est consulté par lookup dans une `Map` clé par `flashcardId`
/// (indexée une seule fois par l'appelant). Sont à éviter :
/// `infos.firstWhere((i) => i.flashcardId == card.id)`, `list.indexOf`,
/// `list.contains` sur une `List`, ou tout `where` imbriqué dans la boucle
/// par carte — tous rendent la catégorisation quadratique, ce qui est
/// invisible sur quelques cartes de test et douloureux sur un dossier réel.
library;

import 'z_flashcard.dart';
import 'z_repetition_info.dart';

/// Les deux familles de cartes proposées par le sélecteur.
///
/// Value object pur : il transporte deux listes déjà calculées, il ne
/// recalcule rien.
class ZSessionCategories {
  /// Construit les catégories (listes déjà ordonnées).
  const ZSessionCategories({required this.neverLearned, required this.due});

  /// Catégories vides (dossier vide ou aucune carte).
  static const ZSessionCategories empty = ZSessionCategories(
    neverLearned: <ZFlashcard>[],
    due: <ZFlashcard>[],
  );

  /// Cartes jamais apprises (`repetitions == 0`, ou aucun état SRS) —
  /// alimentent le compteur « à apprendre ». Ordre d'entrée préservé
  /// (déterministe).
  final List<ZFlashcard> neverLearned;

  /// Cartes dues (`nextReviewDate <= at`) — alimentent « à réviser », triées
  /// par urgence : la plus en retard d'abord.
  final List<ZFlashcard> due;
}

/// Indexe une collection d'états SRS par `flashcardId` — l'indexation unique
/// qui rend [zCategorize] en O(1) par carte.
///
/// Le dernier état gagne en cas de doublon de `flashcardId` (défensif : une
/// collection incohérente ne fait jamais lever d'exception, invariant
/// AD-10).
Map<String, ZRepetitionInfo> zIndexSrsById(Iterable<ZRepetitionInfo> infos) =>
    <String, ZRepetitionInfo>{
      for (final info in infos) info.flashcardId: info,
    };

/// Catégorise [cards] en « jamais apprises » et « dues » — fonction pure,
/// O(1) par carte.
///
/// - [srsById] : état SRS déjà indexé par `flashcardId` (voir
///   [zIndexSrsById]) — lookup, jamais un `firstWhere` ;
/// - [at] : instant de référence — paramètre (`DateTime.now()` est interdit
///   ici).
///
/// ## Règles exactes
///
/// - jamais apprise : aucun état SRS ou `repetitions == 0` (une carte sans
///   `ZRepetitionInfo` est « jamais vue » — repli défensif, invariant
///   AD-10) ;
/// - due : `repetitions > 0` et `nextReviewDate != null` et
///   `nextReviewDate <= at` (l'échéance pile à `at` est due) ;
/// - une carte apprise dont l'échéance est future n'est ni l'un ni l'autre ;
/// - une carte apprise sans `nextReviewDate` n'est pas due (aucune échéance
///   ⇒ rien à réclamer), et n'est pas « jamais apprise » non plus (elle l'a
///   été) — elle est simplement absente des deux listes.
///
/// ## Tri par urgence : exact et stable
///
/// `due` est trié par `nextReviewDate` croissant (la plus en retard
/// d'abord). `List.sort` n'est pas stable en Dart : à échéance égale,
/// l'ordre d'entrée est préservé explicitement (tri décoré par l'index) —
/// sans quoi deux cartes de même échéance pourraient permuter d'un
/// rafraîchissement à l'autre, rendant l'interface non déterministe.
///
/// Une carte sans `id` (éphémère) ne peut porter aucun état SRS : elle est
/// « jamais apprise » (repli sûr).
ZSessionCategories zCategorize(
  Iterable<ZFlashcard> cards, {
  required Map<String, ZRepetitionInfo> srsById,
  required DateTime at,
}) {
  final neverLearned = <ZFlashcard>[];
  final dueDecorated = <_DecoratedDue>[];
  var index = 0;

  for (final card in cards) {
    final id = card.id;
    // Lookup O(1) — jamais `infos.firstWhere(...)`, qui serait O(n) par
    // carte, donc quadratique au total.
    final info = id == null ? null : srsById[id];

    if (info == null || info.repetitions == 0) {
      neverLearned.add(card);
      index++;
      continue;
    }

    final next = info.nextReviewDate;
    if (next != null && !next.isAfter(at)) {
      dueDecorated.add(_DecoratedDue(card: card, next: next, index: index));
    }
    index++;
  }

  // Tri stable par urgence : échéance croissante, puis ordre d'entrée à
  // égalité.
  dueDecorated.sort((a, b) {
    final byDate = a.next.compareTo(b.next);
    return byDate != 0 ? byDate : a.index.compareTo(b.index);
  });

  return ZSessionCategories(
    neverLearned: neverLearned,
    due: <ZFlashcard>[for (final d in dueDecorated) d.card],
  );
}

/// Carte due décorée de son échéance et de son rang d'entrée (tri stable).
///
/// L'échéance est lue une seule fois par carte et mémorisée ici : le
/// comparateur ne relit jamais l'accesseur.
class _DecoratedDue {
  const _DecoratedDue({
    required this.card,
    required this.next,
    required this.index,
  });

  final ZFlashcard card;
  final DateTime next;
  final int index;
}
