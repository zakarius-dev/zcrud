/// Tri de la liste de flashcards.
///
/// Pur, stable et total (invariant AD-10) : aucune entrée ne lève, et deux
/// cartes que le critère ne départage pas gardent leur ordre d'entrée.
///
/// ## Pourquoi la stabilité n'est pas un détail
///
/// `List.sort` du SDK ne garantit pas la stabilité. Sans clé secondaire, deux
/// cartes de même `createdAt` (import en lot : dates identiques à la
/// seconde) permuteraient d'un rebuild à l'autre — la liste « sauterait »
/// sous le doigt de l'utilisateur sans qu'aucune donnée n'ait changé. La
/// stabilité est donc obtenue par construction (index d'entrée en
/// départage), jamais par confiance dans le SDK.
///
/// ## Le mode manuel ne trie pas ici
///
/// [ZFlashcardSortMode.manual] rend l'ordre d'entrée inchangé : l'ordre
/// manuel est possédé par les primitives d'ordonnancement de dossier du
/// noyau d'étude, et c'est l'appelant qui l'applique. Le recopier ici serait
/// une seconde voie d'ordre manuel.
library;

import 'z_flashcard.dart';
import 'z_flashcard_search_text.dart';

/// Mode de tri de la liste — enum, jamais des booléens.
enum ZFlashcardSortMode {
  /// Plus récentes d'abord (`createdAt` décroissant) — défaut usuel.
  dateDesc,

  /// Plus anciennes d'abord (`createdAt` croissant).
  dateAsc,

  /// Par énoncé, ordre alphabétique normalisé (accents et casse ignorés).
  title,

  /// Ordre manuel : entrée rendue telle quelle (l'ordre est appliqué par les
  /// primitives d'ordonnancement de dossier du noyau d'étude, jamais ici).
  manual,
}

/// Trie [cards] selon [mode] — pure, stable, totale.
///
/// Position déterministe des `createdAt` `null` (invariant AD-10) : une
/// carte sans date (éphémère, ou legacy dont le champ manque) est rangée en
/// fin en [ZFlashcardSortMode.dateDesc] comme en [ZFlashcardSortMode.dateAsc]
/// — « les cartes sans date sont à la fin », dans les deux sens. Les
/// inverser avec le sens du tri les ferait surgir en tête d'un tri « plus
/// anciennes d'abord », ce qu'aucun utilisateur n'attend d'une carte sans
/// date. Jamais d'exception.
///
/// L'entrée n'est jamais mutée : une nouvelle liste est rendue.
List<ZFlashcard> zSortFlashcards(
  Iterable<ZFlashcard> cards,
  ZFlashcardSortMode mode,
) {
  final entries = cards.toList(growable: false);

  // Le mode manuel ne trie rien — l'ordre manuel appartient au noyau
  // d'étude.
  if (mode == ZFlashcardSortMode.manual) {
    return List<ZFlashcard>.of(entries);
  }

  // Index d'entrée mémorisé avant le tri : clé secondaire de départage ⇒
  // stabilité par construction (indépendante du SDK).
  final indexed = <_Indexed>[
    for (var i = 0; i < entries.length; i++) _Indexed(i, entries[i]),
  ];

  indexed.sort((a, b) {
    final primary = _compare(a.card, b.card, mode);
    // Ex-aequo sur le critère ⇒ l'ordre d'entrée fait foi (stable).
    return primary != 0 ? primary : a.index.compareTo(b.index);
  });

  return indexed.map((e) => e.card).toList(growable: false);
}

/// Comparaison primaire selon [mode] (`0` ⇒ ex-aequo, départagé par l'index).
int _compare(ZFlashcard a, ZFlashcard b, ZFlashcardSortMode mode) {
  switch (mode) {
    case ZFlashcardSortMode.dateDesc:
      return _compareDates(a.createdAt, b.createdAt, descending: true);
    case ZFlashcardSortMode.dateAsc:
      return _compareDates(a.createdAt, b.createdAt, descending: false);
    case ZFlashcardSortMode.title:
      // Normalisé : « Élève » et « eleve » se rangent au même endroit — un
      // tri alphabétique brut mettrait tous les accentués après le « z »
      // (ordre des points de code), ce qui est faux pour un francophone.
      return zFlashcardSearchText(a.question)
          .compareTo(zFlashcardSearchText(b.question));
    case ZFlashcardSortMode.manual:
      // Inatteignable (court-circuité plus haut) — mais explicite : jamais
      // de `default:` qui masquerait un futur membre d'enum non traité.
      return 0;
  }
}

/// Compare deux dates nullables, `null` toujours en fin (invariant AD-10).
int _compareDates(DateTime? a, DateTime? b, {required bool descending}) {
  // `null` en fin dans les deux sens : la position d'une carte sans date ne
  // dépend pas du sens du tri (voir la dartdoc de `zSortFlashcards`).
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return descending ? b.compareTo(a) : a.compareTo(b);
}

/// Carte enveloppée de son index d'entrée (départage stable).
class _Indexed {
  const _Indexed(this.index, this.card);

  final int index;
  final ZFlashcard card;
}
