/// Filtres test/examen **PURS** (SU-6, FR-SU12 — AC10/AC11/AC12, décisions
/// D1/D5).
///
/// Vit dans `zcrud_flashcard` (D1) : les filtres exigent **à la fois**
/// `ZStudySessionSelector` (kernel, amont) **et** `ZSrsConfig`/`ZRepetitionInfo`
/// (ce package) — c'est le **premier** point du graphe qui voit les deux.
///
/// **PURS** (AD-14) : aucune I/O, **aucune horloge capturée**, **aucun `Random()`
/// capturé** — la source d'aléa est un **PARAMÈTRE** (D5 : `DateTime.now()` et
/// `Random()` sont la **même faute**, une source non déterministe capturée rend le
/// test soit flaky, soit tautologique). `Random` vient de `dart:math` : pur-Dart,
/// légal ici.
///
/// **AD-33 — sélection AMONT, runtime AVAL** : ces fonctions **produisent une
/// file**. Aucun moteur ne filtre, et su-6 n'en câble aucun (D7/AD-34).
library;

import 'dart:math';

import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySessionSelector;

// `ZChoice` vient de `z_flashcard.dart` (qui l'exporte via son propre import) —
// l'importer en plus est redondant (`unnecessary_import`).
import 'z_flashcard.dart';
import 'z_flashcard_search_text.dart';
import 'z_repetition_info.dart';
import 'z_srs_config.dart';

/// Niveau de maîtrise d'une carte — **enum**, jamais un `bool isMastered`
/// (AC15 : convention du spine « enums > booléens » ; un booléen ne saurait pas
/// dire *quel* seau).
///
/// **NON persisté** (valeur de retour **runtime**) ⇒ pas de
/// `@JsonKey(unknownEnumValue:)` à déclarer — consigné (AC15).
enum ZMasteryLevel {
  /// 🔴 **q0-2** (`[minQuality .. passThreshold - 1]`) **∪ jamais vue** (AD-46).
  ///
  /// ⚠️ **q0 EST dans ce seau.** Le PRD FR-SU12 porte un résidu « q1-2 » de
  /// l'échelle 1-5 ; AD-46 impose **q0-2** (« **aucune note n'est hors seau** »).
  /// Un `q0` (blackout total) hors seau, c'est l'apprenant le plus en difficulté
  /// qui disparaît des filtres.
  bad,

  /// **q3** (`passThreshold`) — réussie, pas encore maîtrisée.
  good,

  /// **q4-5** (`>= ZSrsConfig.masteredThreshold`) — maîtrisée.
  mastered,
}

/// Classe une carte par niveau de maîtrise — **fonction PURE** (AC10).
///
/// - [info] : état SRS de la carte, ou `null` si **aucun** (⇒ jamais vue) ;
/// - [config] : **propriétaire AD-46** de toutes les bornes.
///
/// ## Les bornes viennent TOUTES de [config] — aucun littéral
///
/// `minQuality`, `passThreshold` et `masteredThreshold` sont **lus** sur
/// [config] : **aucun `0`/`2`/`3`/`4`/`5` en dur** n'apparaît ici (AD-46 ; gardé
/// par `test/z_mastered_threshold_single_source_test.dart`, qui rougit si la
/// dérivation du seuil est recopiée hors de `z_srs_config.dart`).
///
/// ## `config.clampQuality` est l'UNIQUE voie de clamp (AD-46)
///
/// Une qualité **hors échelle** (`9`, `-2` — corruption, port d'évaluation
/// aberrant) est **clampée** par [ZSrsConfig.clampQuality], jamais rejetée par une
/// exception (AD-10) et jamais laissée « hors seau ».
///
/// ## 🔴 `good` (q3) n'est PAS `mastered` (q4-5)
///
/// C'est l'écart n°1 de su-5 : `correct` (= `q >= passThreshold`, soit **q3+**)
/// et `mastered` (**q4-5**) sont **deux concepts différents**. Une carte tout
/// juste réussie n'est pas maîtrisée.
///
/// ⚠️ **Lecture assumée du tableau AC10** : le tableau écrit `good` = «
/// `lastQuality == passThreshold` ». La forme retenue est l'**intervalle**
/// `[passThreshold .. masteredThreshold - 1]`, **strictement équivalente** pour la
/// config canonique (`passThreshold=3`, `masteredThreshold=4` ⇒ seul q3 est
/// `good`) mais qui, pour une config non canonique (ex. `minQuality: 1` ⇒
/// `passThreshold=2`, `masteredThreshold=4`), ne laisse **aucune note hors seau**
/// — ce qu'AD-46 exige explicitement. L'égalité stricte y ouvrirait un **trou**
/// sur q3.
ZMasteryLevel zMasteryLevelOf(ZRepetitionInfo? info, ZSrsConfig config) {
  // Jamais vue : aucun état SRS, jamais révisée, ou aucune note enregistrée.
  // Les trois disent la même chose — et AD-46 range « jamais vue » dans `bad`
  // (les deux prédicats coexistent : écart E3).
  if (info == null) return ZMasteryLevel.bad;
  if (info.repetitions == 0) return ZMasteryLevel.bad;
  final raw = info.lastQuality;
  if (raw == null) return ZMasteryLevel.bad;

  // 🔴 UNIQUE voie de clamp (AD-46) — jamais un `clamp(0, 5)` réécrit ici.
  final quality = config.clampQuality(raw);

  if (quality >= config.masteredThreshold) return ZMasteryLevel.mastered;
  if (quality >= config.passThreshold) return ZMasteryLevel.good;
  return ZMasteryLevel.bad;
}

/// Filtres de session test/examen — value object **immuable** (FR-SU12).
///
/// ## 🔴 Ce que cette classe NE porte PAS — et pourquoi (AC10)
///
/// **Ni `questionTypes`, ni `tagIds`.** Le tableau de spécifications de la story
/// les listait, mais AC10 tranche plus fort : « elle **CONSOMME**
/// `ZStudySessionSelector` pour dossier ∧ tags ∧ types — **jamais réécrits** ;
/// elle **délègue** à `matches()`, et n'ajoute que ce que le kernel ne sait pas
/// faire ». Or `ZStudySessionConfig` porte **déjà** `folderId`/`tagIds`/`types`, et
/// `ZStudySessionSelector.matches` les applique (dossier ∧ tags ∧ types).
///
/// Les porter **aussi** ici créerait **deux sources** du même filtre, avec une
/// question sans réponse (« lequel gagne ? ») : exactement la lecture *conforme
/// mais incompatible* que la revue adversariale traque. Et les laisser en
/// **champs morts** serait pire encore (une fonctionnalité morte sur son chemin
/// documenté — un défaut déjà démasqué dans cet epic).
///
/// ⇒ **Un filtre, une source** : dossier/tags/types → `selector` ; maîtrise,
/// sources et taille du tirage → ici (le kernel ignore `ZSrsConfig` et
/// `ZFlashcardSource`).
class ZFlashcardTestFilters {
  /// Construit des filtres de test.
  ///
  /// - [questionCount] : nombre de questions — **défaut 10** (FR-SU12) ;
  ///   excédent ⇒ **tirage aléatoire** (cf. [zDrawQuestions]) ;
  /// - [masteryLevels] : seaux retenus — **vide = tous** (aucun filtre) ;
  /// - [sources] : `kind` de provenance retenus (registre **ouvert** AD-4) —
  ///   **vide = toutes**.
  const ZFlashcardTestFilters({
    this.questionCount = 10,
    this.masteryLevels = const <ZMasteryLevel>{},
    this.sources = const <String>{},
  });

  /// Nombre de questions voulu (défaut **10**). `<= 0` ⇒ sélection **vide**
  /// (cohérent avec `ZStudySessionSelector`, `count <= 0` ⇒ vide).
  final int questionCount;

  /// Seaux de maîtrise retenus — **vide = tous** (patron `ZStudySessionSelector` :
  /// `null`/vide ⇒ pas de filtre).
  final Set<ZMasteryLevel> masteryLevels;

  /// `kind` de source retenus — **vide = toutes**. Les `kind` viennent du
  /// **registre** ouvert (AD-4) : jamais une enum fermée ici.
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

/// Prédicat de `kind` de source — **IMPLÉMENTATION UNIQUE** (SU-8, AC6).
///
/// ## Pourquoi il est extrait
///
/// Le filtre « provenance » est exigé **par deux surfaces** : le **tirage** de
/// session ([zApplyTestFilters], su-6) et la **consultation** de la liste
/// ([zApplyBrowseFilters], su-8). Le recopier serait **deux sources du même
/// filtre** — la faute que ce fichier condamne lui-même en tête (« un filtre, une
/// source ») et qu'il a déjà évitée pour dossier/tags/types en déléguant au
/// kernel. Ici le kernel ne peut rien : il ignore `ZFlashcardSource` (AD-17).
/// L'extraction est donc la **seule** façon de tenir la règle.
///
/// Sémantique (patron `ZStudySessionSelector` : vide ⇒ pas de filtre) :
/// - [sources] **vide** ⇒ `true` (toutes les provenances) ;
/// - sinon : la carte doit porter une source dont le `kind` est dans [sources] ;
///   une carte **sans source** (`null`) est **exclue** dès qu'un filtre est posé
///   (elle n'a pas la provenance demandée).
///
/// Les `kind` viennent du **registre ouvert** (AD-4) — jamais une enum fermée.
///
/// **PURE** et **totale** (AD-10) : aucun cas ne lève.
bool zMatchesSourceKind(ZFlashcard card, Set<String> sources) {
  if (sources.isEmpty) return true;
  final kind = card.source?.kind;
  if (kind == null) return false;
  return sources.contains(kind);
}

/// Applique les filtres test/examen — **fonction PURE** (AC10/AC11).
///
/// - [srsById] : état SRS **indexé** par `flashcardId` ⇒ **lookup O(1)** par
///   carte (AC8), jamais un `firstWhere` ;
/// - [filters] : maîtrise / sources / taille du tirage ;
/// - [config] : **propriétaire AD-46** des bornes ;
/// - [selector] : **CONSOMMÉ** pour dossier ∧ tags ∧ types — jamais réécrits ;
/// - [random] : source d'aléa **INJECTÉE** (D5) — jamais `Random()` capturé.
///
/// ## Ordre des opérations
///
/// 1. `selector.matches(card)` — dossier ∧ tags ∧ types (**délégué** au kernel) ;
/// 2. seau de maîtrise (`zMasteryLevelOf`) — ce que le kernel ne sait pas faire ;
/// 3. `kind` de source ;
/// 4. **tirage** à `filters.questionCount` (aléatoire si excédent).
///
/// ⚠️ On appelle `selector.matches` (le **prédicat**) et **non** `selectFrom` :
/// `selectFrom` appliquerait **en plus** son propre plafond `config.count`, qui
/// **doublonnerait** `filters.questionCount` — deux troncatures concurrentes, et
/// la première (par ordre d'entrée, non aléatoire) viderait le tirage de son sens.
/// `matches` est **exactement** la surface que le kernel expose « filtres seuls,
/// hors plafond » (dartdoc `z_study_session_selector.dart:41-49`).
///
/// **Robustesse (AD-10)** : aucun filtre ne retenant rien ⇒ **liste vide**, jamais
/// de throw. Une carte sans état SRS ⇒ traitée « jamais vue » (`bad`).
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
    // 1. Dossier ∧ tags ∧ types — DÉLÉGUÉ au kernel (jamais réécrit).
    if (!selector.matches(card)) continue;

    // 2. Seau de maîtrise — lookup O(1) (AC8).
    if (filters.masteryLevels.isNotEmpty) {
      final id = card.id;
      final info = id == null ? null : srsById[id];
      if (!filters.masteryLevels.contains(zMasteryLevelOf(info, config))) {
        continue;
      }
    }

    // 3. `kind` de source (registre ouvert — AD-4). DÉLÉGUÉ à l'implémentation
    //    UNIQUE `zMatchesSourceKind`, partagée avec `zApplyBrowseFilters`
    //    (su-8/AC6) : le prédicat n'est écrit qu'une fois.
    if (!zMatchesSourceKind(card, filters.sources)) continue;

    eligible.add(card);
  }

  // 4. Tirage — aléa INJECTÉ (AC11).
  return zDrawQuestions(eligible, count: filters.questionCount, random: random);
}

// ═══════════════════════════════════════════════════════════════════════════
// SU-8 — Filtres de CONSULTATION (FR-SU14, AC5/AC6/AC7).
//
// 🔴 Pourquoi une fonction DISTINCTE de `zApplyTestFilters` — et non un
// paramètre de plus
//
// `zApplyTestFilters` est un **TIRAGE de session** : `questionCount` (défaut
// **10**) + `Random` requis + `srsById` requis. L'appliquer à une liste de
// gestion afficherait **10 cartes** d'un dossier qui en compte 2 000, dans un
// ordre **non déterministe**, et imposerait le SRS à une surface de simple
// consultation. Ce serait un défaut fonctionnel majeur, et **muet**.
//
// Les deux fonctions partagent donc ce qui DOIT l'être — `selector.matches`
// (dossier ∧ tags ∧ types) et `zMatchesSourceKind` (provenance) — et rien
// d'autre. « Un filtre, une source » est tenu **sans** confondre deux intentions.
// ═══════════════════════════════════════════════════════════════════════════

/// Champ de flashcard sur lequel porte la **recherche texte** (SU-8, AC5).
///
/// **Enum, jamais des booléens** (`searchQuestion`/`searchAnswer`/… ne sauraient
/// pas dire *quel* champ, et rendraient toute extension breaking). Un
/// `Set<ZFlashcardSearchField>` compose librement.
///
/// **NON persisté** (réglage d'UI runtime) ⇒ pas de `@JsonKey(unknownEnumValue:)`.
enum ZFlashcardSearchField {
  /// L'énoncé ([ZFlashcard.question]) — seul champ texte requis.
  question,

  /// La réponse : [ZFlashcard.answer] **ou** le contenu des [ZFlashcard.choices]
  /// (QCM) — les deux portent « la réponse » selon le type de carte.
  answer,

  /// Les étiquettes ([ZFlashcard.tagIds]).
  ///
  /// ⚠️ Recherche sur les **ids** de tags : le libellé d'un tag vit dans
  /// `ZFlashcardTag`, entité **séparée** que ce package ne joint pas. L'appelant
  /// qui veut chercher par libellé résout ses tags en amont (`tagLabels`).
  tags,
}

/// L'ensemble **par défaut** des champs cherchés : les trois (AC5).
const Set<ZFlashcardSearchField> _kDefaultSearchFields = <ZFlashcardSearchField>{
  ZFlashcardSearchField.question,
  ZFlashcardSearchField.answer,
  ZFlashcardSearchField.tags,
};

/// Filtres de **consultation** de la liste — value object **immuable** (AC5/AC6).
///
/// Ne porte **NI** `questionCount`, **NI** `Random`, **NI** `masteryLevels` :
/// une liste de gestion ne tire pas, ne mélange pas et ne juge pas la maîtrise
/// (AC7). Ne porte pas non plus dossier/tags/types — **délégués** au
/// [ZStudySessionSelector] (AC6, « un filtre, une source »).
class ZFlashcardBrowseFilters {
  /// Construit des filtres de consultation.
  ///
  /// - [query] : recherche texte **brute** (normalisée à l'application) —
  ///   vide/espaces seuls ⇒ **aucun** filtre texte ;
  /// - [searchFields] : champs cherchés — défaut **les trois** ;
  /// - [sources] : `kind` de provenance retenus (registre **ouvert** AD-4) —
  ///   **vide = toutes**.
  const ZFlashcardBrowseFilters({
    this.query = '',
    this.searchFields = _kDefaultSearchFields,
    this.sources = const <String>{},
  });

  /// Recherche texte brute. Normalisée par [zFlashcardSearchText] au moment de
  /// l'application — jamais stockée normalisée (le VO reflète la saisie).
  final String query;

  /// Champs sur lesquels porte [query] — défaut : les trois (AC5).
  ///
  /// **Vide ⇒ aucun champ cherché** ⇒ une [query] non vide ne retient **rien**
  /// (cohérent : on a explicitement demandé à ne chercher nulle part). Ce n'est
  /// **pas** le patron « vide = tout » des ensembles de filtres, car ce set
  /// désigne une **surface de recherche**, pas un filtre de sélection.
  final Set<ZFlashcardSearchField> searchFields;

  /// `kind` de source retenus — **vide = toutes** (patron des autres filtres).
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

/// Applique les filtres de **consultation** — **fonction PURE et DÉTERMINISTE**
/// (AC6/AC7).
///
/// - [selector] : **CONSOMMÉ** pour dossier ∧ tags ∧ types — jamais réécrits.
///   On appelle `matches` (le **prédicat**) et **JAMAIS** `selectFrom` : ce
///   dernier applique le plafond `config.count`, qui **tronquerait la liste de
///   gestion en silence** (un dossier de 2 000 cartes n'en montrerait que
///   `count`). C'est le piège exact de `selectFrom` sur une surface de
///   consultation ;
/// - [filters] : recherche texte + `kind` de source — **tout** ce que le kernel
///   ignore, et **rien** de plus ;
/// - [tagLabels] : résolution **optionnelle** `tagId → libellé` pour la recherche
///   sur les tags. Absente ⇒ la recherche porte sur les **ids** (le libellé vit
///   dans `ZFlashcardTag`, entité séparée — ce package ne la joint pas).
///
/// ## Aucun tirage, aucun aléa, aucune troncature (AC7)
///
/// La signature ne porte **ni `Random`, ni `questionCount`** : deux appels sur la
/// même entrée rendent **exactement** la même liste, dans **l'ordre d'entrée**
/// (le tri est la responsabilité de l'appelant — `ZFlashcardSortMode`, AC8).
/// Gardé par `test/z_flashcard_browse_filters_test.dart` (garde de **signature**).
///
/// **Robustesse (AD-10)** : aucun filtre ne retenant rien ⇒ **liste vide**,
/// jamais de throw. `query` vide/espaces ⇒ aucun filtre texte. `searchFields`
/// vide + `query` non vide ⇒ **rien** (cf. [ZFlashcardBrowseFilters.searchFields]).
/// L'entrée n'est jamais mutée.
List<ZFlashcard> zApplyBrowseFilters(
  Iterable<ZFlashcard> cards, {
  required ZStudySessionSelector selector,
  required ZFlashcardBrowseFilters filters,
  Map<String, String>? tagLabels,
}) {
  // Normalisation faite UNE FOIS pour toute la liste (jamais par carte) : sur
  // des milliers de cartes, replier la requête à chaque itération serait un coût
  // pur. Vide après normalisation (espaces seuls) ⇒ aucun filtre texte.
  final needle = zFlashcardSearchText(filters.query);
  final hasQuery = needle.isNotEmpty;

  final result = <ZFlashcard>[];
  for (final card in cards) {
    // 1. Dossier ∧ tags ∧ types — DÉLÉGUÉ au kernel (jamais réécrit, jamais
    //    `selectFrom` : son plafond `count` tronquerait la liste).
    if (!selector.matches(card)) continue;

    // 2. `kind` de source — implémentation UNIQUE partagée avec le tirage.
    if (!zMatchesSourceKind(card, filters.sources)) continue;

    // 3. Recherche texte normalisée (le seul ajout de su-8 avec la source).
    if (hasQuery &&
        !_matchesQuery(card, needle, filters.searchFields, tagLabels)) {
      continue;
    }

    result.add(card);
  }
  return result;
}

/// `true` si [needle] (**déjà normalisé**) apparaît dans l'un des [fields] de
/// [card].
///
/// Chaque champ est normalisé par [zFlashcardSearchText] **avant** comparaison :
/// « eleve » trouve « Élève » (NFC **et** NFD), et « a b » trouve « a b »
/// (insécable) — des deux côtés de la comparaison.
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
        // « la réponse » selon le type : texte libre ET/OU contenu des choix.
        // Les deux sont consultés — une carte QCM n'a pas d'`answer`, et une
        // carte ouverte n'a pas de `choices` : n'en lire qu'un rendrait la
        // recherche muette sur la moitié des types.
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

/// Tire [count] éléments de [eligible] — **aléa INJECTÉ** (AC11).
///
/// - `count <= 0` ⇒ **vide** (cohérent avec `ZStudySessionSelector`) ;
/// - `count >= eligible.length` ⇒ **tout** est rendu, **sans tirage** et sans
///   throw (l'ordre d'entrée est préservé : rien à départager) ;
/// - sinon : **exactement** [count] éléments, **tous** ⊆ [eligible], **sans
///   doublon**.
///
/// ## 🔴 L'aléa est RÉELLEMENT consulté
///
/// Le tirage est un **Fisher-Yates partiel** sur une copie : `random.nextInt` est
/// appelé pour **chaque** élément tiré. Une implémentation « prendre les [count]
/// premières » (`eligible.take(count)`) passerait *tous* les autres tests —
/// longueur, inclusion, absence de doublon, déterminisme à graine égale — et
/// **échouerait uniquement** sur « deux graines ⇒ deux sous-ensembles ». C'est
/// **LE** test qui prouve que l'aléa n'est pas décoratif.
///
/// À graine égale, le résultat est **strictement déterministe** (aucune source
/// d'aléa capturée).
///
/// L'entrée n'est **jamais mutée** (copie défensive).
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
    // Fisher-Yates partiel : chaque tirage consulte RÉELLEMENT `random`.
    final pick = random.nextInt(pool.length);
    drawn.add(pool[pick]);
    // Échange avec la fin puis retrait : O(1), et aucun doublon possible.
    pool[pick] = pool[pool.length - 1];
    pool.removeLast();
  }
  return drawn;
}

/// Mélange les choix d'un QCM — **aléa INJECTÉ** (AC12).
///
/// ## 🔴 Ce sont les OBJETS qui permutent, jamais les libellés seuls
///
/// `ZChoice` porte `isCorrect` **SUR l'objet** (`{content, isCorrect}` — lu :
/// `z_choice.dart:25-40`). Le mélange permute donc les **`ZChoice` entiers** : le
/// multiset des **PAIRES `(content, isCorrect)`** est **strictement préservé**.
///
/// C'est **exactement** le défaut de su-2 (« marqueur attribué au **mauvais**
/// choix ») : mélanger les `content` en laissant `isCorrect` à sa position
/// produirait le **même ensemble de libellés** — un test qui n'assert que les
/// `content` resterait **VERT** en désignant la mauvaise bonne réponse.
///
/// **Robustesse (AD-10)** : `null`, liste **vide** ou **un seul** choix ⇒ jamais
/// de throw (rendus tels quels, en liste neuve).
///
/// L'original n'est **jamais muté** : une **nouvelle** liste est rendue.
///
/// ## 🔴 Le CONTRAT de couture que l'hôte doit respecter (su-6, LOW-4bis)
///
/// Cette fonction n'a **aucun appelant de production**, et c'est **conforme au
/// périmètre** : D7 interdit à su-6 de câbler un moteur, AD-33 place la sélection
/// **en amont** et le parcours assemblé est **su-10**. Mais le contrat, lui,
/// n'était écrit **nulle part** (`grep -rq "copyWith(choices" packages/` → RC=1).
/// Il l'est ici :
///
/// ```dart
/// // ✅ La carte ENTIÈRE est reconstruite avec les choix mélangés…
/// final shuffled = card.copyWith(choices: zShuffleChoices(card.choices, random: r));
/// // …et c'est CETTE carte qui part à l'affichage ET à la correction.
/// ```
///
/// 🚫 Mélanger **pour l'affichage** tout en notant la carte **d'origine**
/// désynchroniserait les deux côtés — le défaut su-2, par la couture au lieu de
/// la fonction. Le typage **ferme** aujourd'hui cette voie (le widget n'accepte
/// qu'un `ZFlashcard`, jamais une `List<ZChoice>` séparée : affichage et
/// correction lisent donc **la même liste**) ; ce paragraphe est là pour que la
/// fermeture reste **délibérée** le jour où quelqu'un ajoutera ce paramètre.
///
/// ⚠️ **À porter au ledger de su-10** : si le mélange n'est **jamais** câblé,
/// **aucun test existant ne rougira** — le QCM présentera éternellement la bonne
/// réponse à la **même position**. Le défaut su-2 réapparaîtrait alors *par
/// omission* au lieu de *par erreur*.
List<ZChoice> zShuffleChoices(
  List<ZChoice>? choices, {
  required Random random,
}) {
  if (choices == null || choices.length <= 1) {
    return List<ZChoice>.of(choices ?? const <ZChoice>[]);
  }
  final shuffled = List<ZChoice>.of(choices);
  // Fisher-Yates complet — permute les OBJETS (la paire reste soudée).
  for (var i = shuffled.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final tmp = shuffled[i];
    shuffled[i] = shuffled[j];
    shuffled[j] = tmp;
  }
  return shuffled;
}
