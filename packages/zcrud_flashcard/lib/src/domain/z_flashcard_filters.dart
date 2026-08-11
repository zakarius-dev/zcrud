/// Filtres test/examen purs.
///
/// Vit dans `zcrud_flashcard` : les filtres exigent à la fois
/// `ZStudySessionSelector` (noyau d'étude, amont) et `ZSrsConfig`/
/// `ZRepetitionInfo` (ce paquet) — c'est le premier point du graphe qui voit
/// les deux.
///
/// Purs (invariant AD-14) : aucune E/S, aucune horloge capturée, aucun
/// générateur aléatoire capturé — la source d'aléa est un paramètre (une
/// source non déterministe capturée rend le test soit instable, soit
/// tautologique). `Random` vient de `dart:math` : pur-Dart, légal ici.
///
/// Sélection en amont, exécution en aval : ces fonctions produisent une
/// file. Aucun moteur n'est filtré ici, et ce fichier n'en câble aucun.
library;

import 'dart:math';

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySessionSelector;

// `ZChoice` vient de `z_flashcard.dart` (qui l'exporte via son propre
// import) — l'importer en plus est redondant (`unnecessary_import`).
import 'z_flashcard.dart';
import 'z_flashcard_search_text.dart';
import 'z_repetition_info.dart';
import 'z_srs_config.dart';

/// Niveau de maîtrise d'une carte — enum, jamais un `bool isMastered` (un
/// booléen ne saurait pas dire quel seau).
///
/// Non persisté (valeur de retour runtime) ⇒ pas d'annotation de valeur
/// d'enum inconnue à déclarer.
enum ZMasteryLevel {
  /// Qualité `[minQuality .. passThreshold - 1]`, y compris jamais vue.
  ///
  /// La borne basse `q0` fait partie de ce seau : aucune note n'est hors
  /// seau. Exclure `q0` en ferait disparaître des filtres l'apprenant le
  /// plus en difficulté.
  bad,

  /// Qualité au seuil de passage — réussie, pas encore maîtrisée.
  good,

  /// Qualité au-delà du seuil de maîtrise — maîtrisée.
  mastered,
}

/// Classe une carte par niveau de maîtrise — fonction pure.
///
/// - [info] : état SRS de la carte, ou `null` si aucun (⇒ jamais vue) ;
/// - [config] : propriétaire de toutes les bornes.
///
/// ## Les bornes viennent toutes de [config] — aucun littéral
///
/// `minQuality`, `passThreshold` et `masteredThreshold` sont lus sur
/// [config] : aucune borne numérique n'apparaît en dur ici.
///
/// ## `config.clampQuality` est l'unique voie de clamp
///
/// Une qualité hors échelle (corruption, port d'évaluation aberrant) est
/// clampée par [ZSrsConfig.clampQuality], jamais rejetée par une exception
/// (invariant AD-10) et jamais laissée hors seau.
///
/// ## `good` n'est pas `mastered`
///
/// `correct` (qualité au moins égale au seuil de passage) et `mastered`
/// (au-delà du seuil de maîtrise) sont deux concepts différents. Une carte
/// tout juste réussie n'est pas maîtrisée.
///
/// La forme retenue pour `good` est l'intervalle
/// `[passThreshold .. masteredThreshold - 1]` : pour une configuration non
/// canonique, elle ne laisse aucune note hors seau, ce qu'exige la
/// discipline de classification — une égalité stricte y ouvrirait un trou.
ZMasteryLevel zMasteryLevelOf(ZRepetitionInfo? info, ZSrsConfig config) {
  // Jamais vue : aucun état SRS, jamais révisée, ou aucune note enregistrée.
  // Les trois disent la même chose, et « jamais vue » est rangée dans `bad`.
  if (info == null) return ZMasteryLevel.bad;
  if (info.repetitions == 0) return ZMasteryLevel.bad;
  final raw = info.lastQuality;
  if (raw == null) return ZMasteryLevel.bad;

  // Unique voie de clamp — jamais un clamp réécrit ici.
  final quality = config.clampQuality(raw);

  if (quality >= config.masteredThreshold) return ZMasteryLevel.mastered;
  if (quality >= config.passThreshold) return ZMasteryLevel.good;
  return ZMasteryLevel.bad;
}

/// Filtres de session test/examen — value object immuable.
///
/// ## Ce que cette classe ne porte pas — et pourquoi
///
/// Ni `questionTypes`, ni `tagIds`. Ces filtres consomment
/// `ZStudySessionSelector` pour dossier, tags et types — jamais réécrits ;
/// ils délèguent à `matches()`, et n'ajoutent que ce que le noyau ne sait pas
/// faire. Or `ZStudySessionConfig` porte déjà `folderId`/`tagIds`/`types`, et
/// `ZStudySessionSelector.matches` les applique.
///
/// Les porter aussi ici créerait deux sources du même filtre, avec une
/// question sans réponse (« lequel gagne ? »).
///
/// Un filtre, une source : dossier/tags/types → `selector` ; maîtrise,
/// sources et taille du tirage → ici (le noyau ignore `ZSrsConfig` et
/// `ZFlashcardSource`).
class ZFlashcardTestFilters {
  /// Construit des filtres de test.
  ///
  /// - [questionCount] : nombre de questions — défaut 10 ; excédent ⇒ tirage
  ///   aléatoire (voir [zDrawQuestions]) ;
  /// - [masteryLevels] : seaux retenus — vide = tous (aucun filtre) ;
  /// - [sources] : `kind` de provenance retenus (registre ouvert, invariant
  ///   AD-4) — vide = toutes.
  const ZFlashcardTestFilters({
    this.questionCount = 10,
    this.masteryLevels = const <ZMasteryLevel>{},
    this.sources = const <String>{},
  });

  /// Nombre de questions voulu (défaut 10). `<= 0` ⇒ sélection vide
  /// (cohérent avec `ZStudySessionSelector`, `count <= 0` ⇒ vide).
  final int questionCount;

  /// Seaux de maîtrise retenus — vide = tous (`null`/vide ⇒ pas de filtre).
  final Set<ZMasteryLevel> masteryLevels;

  /// `kind` de source retenus — vide = toutes. Les `kind` viennent du
  /// registre ouvert (invariant AD-4) : jamais une enum fermée ici.
  final Set<String> sources;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFlashcardTestFilters &&
          questionCount == other.questionCount &&
          _setEquals(masteryLevels, other.masteryLevels) &&
          _setEquals(sources, other.sources);

  @override
  int get hashCode => Object.hash(
        questionCount,
        Object.hashAllUnordered(masteryLevels),
        Object.hashAllUnordered(sources),
      );
}

/// Égalité d'ensembles (sans dépendance à `collection`).
bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

/// Prédicat de `kind` de source — implémentation unique.
///
/// ## Pourquoi il est extrait
///
/// Le filtre « provenance » est exigé par deux surfaces : le tirage de
/// session ([zApplyTestFilters]) et la consultation de la liste
/// ([zApplyBrowseFilters]). Le recopier serait deux sources du même filtre —
/// exactement ce que ce fichier condamne pour dossier/tags/types en
/// déléguant au noyau. Ici le noyau ne peut rien : il ignore
/// `ZFlashcardSource`. L'extraction est donc la seule façon de tenir la
/// règle « un filtre, une source ».
///
/// Sémantique (vide ⇒ pas de filtre, patron de `ZStudySessionSelector`) :
/// - [sources] vide ⇒ `true` (toutes les provenances) ;
/// - sinon : la carte doit porter une source dont le `kind` est dans
///   [sources] ; une carte sans source (`null`) est exclue dès qu'un filtre
///   est posé.
///
/// Les `kind` viennent du registre ouvert (invariant AD-4) — jamais une enum
/// fermée.
///
/// Pure et totale (invariant AD-10) : aucun cas ne lève.
bool zMatchesSourceKind(ZFlashcard card, Set<String> sources) {
  if (sources.isEmpty) return true;
  final kind = card.source?.kind;
  if (kind == null) return false;
  return sources.contains(kind);
}

/// Applique les filtres test/examen — fonction pure.
///
/// - [srsById] : état SRS indexé par `flashcardId` ⇒ lookup O(1) par carte,
///   jamais un `firstWhere` ;
/// - [filters] : maîtrise / sources / taille du tirage ;
/// - [config] : propriétaire des bornes ;
/// - [selector] : consommé pour dossier, tags et types — jamais réécrits ;
/// - [random] : source d'aléa injectée — jamais un générateur capturé.
///
/// ## Ordre des opérations
///
/// 1. `selector.matches(card)` — dossier, tags et types (délégué au noyau) ;
/// 2. seau de maîtrise (`zMasteryLevelOf`) — ce que le noyau ne sait pas
///    faire ;
/// 3. `kind` de source ;
/// 4. tirage à `filters.questionCount` (aléatoire si excédent).
///
/// On appelle `selector.matches` (le prédicat) et non `selectFrom` :
/// `selectFrom` appliquerait en plus son propre plafond, qui doublonnerait
/// `filters.questionCount` — deux troncatures concurrentes, et la première
/// (par ordre d'entrée, non aléatoire) viderait le tirage de son sens.
///
/// Robustesse (invariant AD-10) : aucun filtre ne retenant rien ⇒ liste
/// vide, jamais d'exception. Une carte sans état SRS ⇒ traitée « jamais
/// vue » (`bad`).
List<ZFlashcard> zApplyTestFilters(
  Iterable<ZFlashcard> cards, {
  required Map<String, ZRepetitionInfo> srsById,
  required ZFlashcardTestFilters filters,
  required ZSrsConfig config,
  required ZStudySessionSelector selector,
  required Random random,
}) {
  final eligible = <ZFlashcard>[];

  for (final card in cards) {
    // 1. Dossier, tags et types — délégué au noyau (jamais réécrit).
    if (!selector.matches(card)) continue;

    // 2. Seau de maîtrise — lookup O(1).
    if (filters.masteryLevels.isNotEmpty) {
      final id = card.id;
      final info = id == null ? null : srsById[id];
      if (!filters.masteryLevels.contains(zMasteryLevelOf(info, config))) {
        continue;
      }
    }

    // 3. `kind` de source (registre ouvert). Délégué à l'implémentation
    //    unique `zMatchesSourceKind`, partagée avec `zApplyBrowseFilters`.
    if (!zMatchesSourceKind(card, filters.sources)) continue;

    eligible.add(card);
  }

  // 4. Tirage — aléa injecté.
  return zDrawQuestions(eligible, count: filters.questionCount, random: random);
}

// ═══════════════════════════════════════════════════════════════════════════
// Filtres de consultation.
//
// Pourquoi une fonction distincte de `zApplyTestFilters` — et non un
// paramètre de plus
//
// `zApplyTestFilters` est un tirage de session : `questionCount` (défaut 10)
// et un `Random` requis. L'appliquer à une liste de gestion afficherait 10
// cartes d'un dossier qui en compte 2 000, dans un ordre non déterministe, et
// imposerait le SRS à une surface de simple consultation.
//
// Les deux fonctions partagent donc ce qui doit l'être — `selector.matches`
// (dossier, tags et types) et `zMatchesSourceKind` (provenance) — et rien
// d'autre. « Un filtre, une source » est tenu sans confondre deux intentions.
// ═══════════════════════════════════════════════════════════════════════════

/// Champ de flashcard sur lequel porte la recherche texte.
///
/// Enum, jamais des booléens (des champs booléens séparés ne sauraient pas
/// dire quel champ, et rendraient toute extension incompatible). Un
/// `Set<ZFlashcardSearchField>` compose librement.
///
/// Non persisté (réglage d'interface runtime) ⇒ pas d'annotation de valeur
/// d'enum inconnue.
enum ZFlashcardSearchField {
  /// L'énoncé ([ZFlashcard.question]) — seul champ texte requis.
  question,

  /// La réponse : [ZFlashcard.answer] ou le contenu des [ZFlashcard.choices]
  /// (QCM) — les deux portent « la réponse » selon le type de carte.
  answer,

  /// Les étiquettes ([ZFlashcard.tagIds]).
  ///
  /// Recherche sur les identifiants de tags : le libellé d'un tag vit dans
  /// une entité séparée que ce paquet ne joint pas. L'appelant qui veut
  /// chercher par libellé résout ses tags en amont.
  tags,
}

/// L'ensemble par défaut des champs cherchés : les trois.
const Set<ZFlashcardSearchField> _kDefaultSearchFields = <ZFlashcardSearchField>{
  ZFlashcardSearchField.question,
  ZFlashcardSearchField.answer,
  ZFlashcardSearchField.tags,
};

/// Filtres de consultation de la liste — value object immuable.
///
/// Ne porte ni `questionCount`, ni `Random`, ni `masteryLevels` : une liste
/// de gestion ne tire pas, ne mélange pas et ne juge pas la maîtrise. Ne
/// porte pas non plus dossier/tags/types — délégués au
/// [ZStudySessionSelector] (« un filtre, une source »).
class ZFlashcardBrowseFilters {
  /// Construit des filtres de consultation.
  ///
  /// - [query] : recherche texte brute (normalisée à l'application) —
  ///   vide/espaces seuls ⇒ aucun filtre texte ;
  /// - [searchFields] : champs cherchés — défaut les trois ;
  /// - [sources] : `kind` de provenance retenus (registre ouvert, invariant
  ///   AD-4) — vide = toutes.
  const ZFlashcardBrowseFilters({
    this.query = '',
    this.searchFields = _kDefaultSearchFields,
    this.sources = const <String>{},
  });

  /// Recherche texte brute. Normalisée par [zFlashcardSearchText] au moment
  /// de l'application — jamais stockée normalisée (ce value-object reflète
  /// la saisie).
  final String query;

  /// Champs sur lesquels porte [query] — défaut : les trois.
  ///
  /// Vide ⇒ aucun champ cherché ⇒ une [query] non vide ne retient rien
  /// (cohérent : on a explicitement demandé à ne chercher nulle part). Ce
  /// n'est pas le patron « vide = tout » des ensembles de filtres, car ce
  /// jeu désigne une surface de recherche, pas un filtre de sélection.
  final Set<ZFlashcardSearchField> searchFields;

  /// `kind` de source retenus — vide = toutes (patron des autres filtres).
  final Set<String> sources;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFlashcardBrowseFilters &&
          query == other.query &&
          _setEquals(searchFields, other.searchFields) &&
          _setEquals(sources, other.sources);

  @override
  int get hashCode => Object.hash(
        query,
        Object.hashAllUnordered(searchFields),
        Object.hashAllUnordered(sources),
      );
}

/// Applique les filtres de consultation — fonction pure et déterministe.
///
/// - [selector] : consommé pour dossier, tags et types — jamais réécrits. On
///   appelle `matches` (le prédicat) et jamais `selectFrom` : ce dernier
///   applique un plafond qui tronquerait la liste de gestion en silence (un
///   dossier de 2 000 cartes n'en montrerait qu'une fraction) ;
/// - [filters] : recherche texte et `kind` de source — tout ce que le noyau
///   ignore, et rien de plus ;
/// - [tagLabels] : résolution optionnelle identifiant → libellé pour la
///   recherche sur les tags. Absente ⇒ la recherche porte sur les
///   identifiants (le libellé vit dans une entité séparée que ce paquet ne
///   joint pas).
///
/// ## Aucun tirage, aucun aléa, aucune troncature
///
/// La signature ne porte ni `Random`, ni `questionCount` : deux appels sur
/// la même entrée rendent exactement la même liste, dans l'ordre d'entrée
/// (le tri est la responsabilité de l'appelant — `ZFlashcardSortMode`).
///
/// Robustesse (invariant AD-10) : aucun filtre ne retenant rien ⇒ liste
/// vide, jamais d'exception. `query` vide/espaces ⇒ aucun filtre texte.
/// `searchFields` vide avec `query` non vide ⇒ rien (voir
/// [ZFlashcardBrowseFilters.searchFields]). L'entrée n'est jamais mutée.
List<ZFlashcard> zApplyBrowseFilters(
  Iterable<ZFlashcard> cards, {
  required ZStudySessionSelector selector,
  required ZFlashcardBrowseFilters filters,
  Map<String, String>? tagLabels,
}) {
  // Normalisation faite une fois pour toute la liste (jamais par carte) :
  // sur des milliers de cartes, replier la requête à chaque itération
  // serait un coût pur. Vide après normalisation (espaces seuls) ⇒ aucun
  // filtre texte.
  final needle = zFlashcardSearchText(filters.query);
  final hasQuery = needle.isNotEmpty;

  final result = <ZFlashcard>[];
  for (final card in cards) {
    // 1. Dossier, tags et types — délégué au noyau (jamais réécrit, jamais
    //    `selectFrom` : son plafond tronquerait la liste).
    if (!selector.matches(card)) continue;

    // 2. `kind` de source — implémentation unique partagée avec le tirage.
    if (!zMatchesSourceKind(card, filters.sources)) continue;

    // 3. Recherche texte normalisée.
    if (hasQuery &&
        !_matchesQuery(card, needle, filters.searchFields, tagLabels)) {
      continue;
    }

    result.add(card);
  }
  return result;
}

/// `true` si [needle] (déjà normalisé) apparaît dans l'un des [fields] de
/// [card].
///
/// Chaque champ est normalisé par [zFlashcardSearchText] avant comparaison :
/// « eleve » trouve « Élève » (formes composées et décomposées), et « a b »
/// trouve « a b » (insécable) — des deux côtés de la comparaison.
bool _matchesQuery(
  ZFlashcard card,
  String needle,
  Set<ZFlashcardSearchField> fields,
  Map<String, String>? tagLabels,
) {
  for (final field in fields) {
    switch (field) {
      case ZFlashcardSearchField.question:
        if (zFlashcardSearchText(card.question).contains(needle)) return true;
      case ZFlashcardSearchField.answer:
        // « la réponse » selon le type : texte libre et/ou contenu des
        // choix. Les deux sont consultés — une carte QCM n'a pas
        // d'`answer`, et une carte ouverte n'a pas de `choices` : n'en lire
        // qu'un rendrait la recherche muette sur la moitié des types.
        final answer = card.answer;
        if (answer != null &&
            zFlashcardSearchText(answer).contains(needle)) {
          return true;
        }
        final choices = card.choices;
        if (choices != null) {
          for (final choice in choices) {
            if (zFlashcardSearchText(choice.content).contains(needle)) {
              return true;
            }
          }
        }
      case ZFlashcardSearchField.tags:
        for (final tagId in card.tagIds) {
          // Libellé résolu si l'appelant l'a fourni, sinon l'id lui-même.
          final label = tagLabels?[tagId] ?? tagId;
          if (zFlashcardSearchText(label).contains(needle)) return true;
        }
    }
  }
  return false;
}

/// Tire [count] éléments de [eligible] — aléa injecté.
///
/// - `count <= 0` ⇒ vide (cohérent avec `ZStudySessionSelector`) ;
/// - `count >= eligible.length` ⇒ tout est rendu, sans tirage et sans
///   exception (l'ordre d'entrée est préservé : rien à départager) ;
/// - sinon : exactement [count] éléments, tous inclus dans [eligible], sans
///   doublon.
///
/// ## L'aléa est réellement consulté
///
/// Le tirage est un Fisher-Yates partiel sur une copie : `random.nextInt`
/// est appelé pour chaque élément tiré. Une implémentation « prendre les
/// [count] premières » passerait tous les autres tests — longueur,
/// inclusion, absence de doublon, déterminisme à graine égale — et
/// échouerait uniquement sur « deux graines ⇒ deux sous-ensembles » : c'est
/// le test qui prouve que l'aléa n'est pas décoratif.
///
/// À graine égale, le résultat est strictement déterministe (aucune source
/// d'aléa capturée).
///
/// L'entrée n'est jamais mutée (copie défensive).
List<T> zDrawQuestions<T>(
  List<T> eligible, {
  required int count,
  required Random random,
}) {
  if (count <= 0) return <T>[];
  if (count >= eligible.length) return List<T>.of(eligible);

  final pool = List<T>.of(eligible);
  final drawn = <T>[];
  for (var i = 0; i < count; i++) {
    // Fisher-Yates partiel : chaque tirage consulte réellement `random`.
    final pick = random.nextInt(pool.length);
    drawn.add(pool[pick]);
    // Échange avec la fin puis retrait : O(1), et aucun doublon possible.
    pool[pick] = pool[pool.length - 1];
    pool.removeLast();
  }
  return drawn;
}

/// Mélange les choix d'un QCM — aléa injecté.
///
/// ## Ce sont les objets qui permutent, jamais les libellés seuls
///
/// `ZChoice` porte `isCorrect` sur l'objet lui-même (`{content, isCorrect}`).
/// Le mélange permute donc les `ZChoice` entiers : le multiset des paires
/// `(content, isCorrect)` est strictement préservé. Mélanger les `content`
/// en laissant `isCorrect` à sa position produirait le même ensemble de
/// libellés — un test qui n'assert que les `content` resterait vert en
/// désignant la mauvaise bonne réponse.
///
/// Robustesse (invariant AD-10) : `null`, liste vide ou un seul choix ⇒
/// jamais d'exception (rendus tels quels, en liste neuve).
///
/// L'original n'est jamais muté : une nouvelle liste est rendue.
///
/// ## Le contrat de couture que l'hôte doit respecter
///
/// ```dart
/// // La carte ENTIÈRE est reconstruite avec les choix mélangés…
/// final shuffled = card.copyWith(choices: zShuffleChoices(card.choices, random: r));
/// // …et c'est CETTE carte qui part à l'affichage ET à la correction.
/// ```
///
/// Mélanger pour l'affichage tout en notant la carte d'origine
/// désynchroniserait les deux côtés : c'est le défaut que ce contrat
/// prévient. Le typage ferme aujourd'hui cette voie (le widget n'accepte
/// qu'un `ZFlashcard`, jamais une `List<ZChoice>` séparée : affichage et
/// correction lisent donc la même liste).
List<ZChoice> zShuffleChoices(
  List<ZChoice>? choices, {
  required Random random,
}) {
  if (choices == null || choices.length <= 1) {
    return List<ZChoice>.of(choices ?? const <ZChoice>[]);
  }
  final shuffled = List<ZChoice>.of(choices);
  // Fisher-Yates complet — permute les objets (la paire reste soudée).
  for (var i = shuffled.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final tmp = shuffled[i];
    shuffled[i] = shuffled[j];
    shuffled[j] = tmp;
  }
  return shuffled;
}
