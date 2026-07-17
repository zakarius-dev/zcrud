/// Catégorisation PURE des cartes pour le sélecteur de session (SU-6, FR-SU10 —
/// AC7/AC8, décision D1).
///
/// Vit dans `zcrud_flashcard` (D1) : la catégorisation exige **à la fois**
/// `ZFlashcard` **et** `ZRepetitionInfo` — `zcrud_flashcard` est le **premier**
/// point du graphe qui voit les deux. Le kernel ne peut pas l'héberger (il ignore
/// `ZRepetitionInfo`), et `zcrud_session` ne le doit pas (FR-SU10 est du
/// **domaine**, pas de la présentation).
///
/// **PURE** (AD-14) : aucune I/O, **aucun `DateTime.now()`** — l'instant est un
/// **PARAMÈTRE**. Aucun moteur n'est touché (AD-34), aucune écriture SRS
/// (AD-33) : cette fonction **lit** l'état SRS, elle ne l'avance jamais.
///
/// ## 🔴 O(1) PAR CARTE — l'exigence de perf de FR-SU10 (AC8)
///
/// L'état SRS est consulté par **lookup dans une `Map`** clé par `flashcardId`
/// (indexée **une seule fois** par l'appelant). Sont **INTERDITS** :
/// `infos.firstWhere((i) => i.flashcardId == card.id)`, `list.indexOf`,
/// `list.contains` sur une `List`, ou tout `where` **imbriqué** dans la boucle par
/// carte — tous rendent la catégorisation **O(n²)**, ce qui est invisible sur les
/// 3 cartes d'un test et douloureux sur un dossier réel.
///
/// Ce n'est pas une promesse de dartdoc : `z_session_categorization_test.dart`
/// **MESURE** le coût avec une sonde comptant les **lectures d'accesseurs**
/// (N=200 **et** N=1600, `<= 4N`), et soumet une implémentation de référence
/// **délibérément O(n²)** à la **même** assertion — laquelle **DOIT échouer**.
/// Aucun `Stopwatch` (flaky, et un `sleep` le ferait passer) : on compte des
/// **opérations**, grandeur déterministe.
library;

import 'z_flashcard.dart';
import 'z_repetition_info.dart';

/// Les deux familles de cartes proposées par le sélecteur (FR-SU10).
///
/// Value object PUR : il **transporte** deux listes déjà calculées, il ne
/// recalcule rien.
class ZSessionCategories {
  /// Construit les catégories (listes déjà ordonnées).
  const ZSessionCategories({required this.neverLearned, required this.due});

  /// Catégories **vides** (dossier vide / aucune carte — AC13).
  static const ZSessionCategories empty = ZSessionCategories(
    neverLearned: <ZFlashcard>[],
    due: <ZFlashcard>[],
  );

  /// Cartes **jamais apprises** (`repetitions == 0`, ou aucun état SRS) —
  /// alimentent « Apprendre +N ». **Ordre d'entrée préservé** (déterministe).
  final List<ZFlashcard> neverLearned;

  /// Cartes **dues** (`nextReviewDate <= at`) — alimentent « À réviser », triées
  /// par **urgence** : la plus en retard **d'abord** (AC7).
  final List<ZFlashcard> due;
}

/// Indexe une collection d'états SRS par `flashcardId` — l'indexation **UNIQUE**
/// qui rend [zCategorize] O(1) par carte (AC8).
///
/// Le dernier état gagne en cas de doublon de `flashcardId` (défensif : une
/// collection incohérente ne fait jamais throw — AD-10).
Map<String, ZRepetitionInfo> zIndexSrsById(Iterable<ZRepetitionInfo> infos) =>
    <String, ZRepetitionInfo>{
      for (final info in infos) info.flashcardId: info,
    };

/// Catégorise [cards] en « jamais apprises » et « dues » — **fonction PURE**,
/// **O(1) par carte** (AC7/AC8).
///
/// - [srsById] : état SRS **déjà indexé** par `flashcardId` (cf. [zIndexSrsById])
///   — **lookup**, jamais un `firstWhere` ;
/// - [at] : instant de référence — **PARAMÈTRE** (AD-14 : `DateTime.now()` est
///   interdit ici).
///
/// ## Règles EXACTES (AC7)
///
/// - **jamais apprise** : aucun état SRS **ou** `repetitions == 0` (une carte
///   sans `ZRepetitionInfo` est « jamais vue » — repli AD-10, jamais un throw) ;
/// - **due** : `repetitions > 0` **et** `nextReviewDate != null` **et**
///   `nextReviewDate <= at` (l'échéance **pile à `at`** est due — `!isAfter`) ;
/// - une carte apprise dont l'échéance est **future** n'est ni l'un ni l'autre ;
/// - une carte apprise **sans** `nextReviewDate` n'est **pas** due (aucune
///   échéance ⇒ rien à réclamer), et n'est pas « jamais apprise » non plus (elle
///   l'a été) — elle est simplement absente des deux listes.
///
/// ## Tri par urgence : exact **ET stable**
///
/// `due` est trié par `nextReviewDate` **croissant** (la plus en retard d'abord :
/// `{J-5, J-1, J-3}` → `{J-5, J-3, J-1}`). ⚠️ `List.sort` n'est **PAS stable** en
/// Dart : à échéance **égale**, l'ordre d'entrée est préservé explicitement (tri
/// décoré par l'index) — sans quoi deux cartes de même échéance pourraient
/// permuter d'un run à l'autre, rendant l'UI non déterministe.
///
/// Une carte sans `id` (éphémère — AD-14) ne peut porter aucun état SRS : elle
/// est « jamais apprise » (repli sûr).
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
    // 🔴 LOOKUP O(1) — jamais `infos.firstWhere(...)` (qui serait O(n) PAR carte,
    // soit O(n²) au total : le défaut que la sonde d'AC8 mesure).
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

  // Tri STABLE par urgence : échéance croissante, puis ordre d'entrée à égalité.
  dueDecorated.sort((a, b) {
    final byDate = a.next.compareTo(b.next);
    return byDate != 0 ? byDate : a.index.compareTo(b.index);
  });

  return ZSessionCategories(
    neverLearned: neverLearned,
    due: <ZFlashcard>[for (final d in dueDecorated) d.card],
  );
}

/// Carte due **décorée** de son échéance et de son rang d'entrée (tri stable).
///
/// L'échéance est lue **UNE SEULE FOIS** par carte et mémorisée ici : le
/// comparateur ne relit **jamais** l'accesseur (ce qui multiplierait les lectures
/// par `log n` et brouillerait la mesure d'AC8).
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
