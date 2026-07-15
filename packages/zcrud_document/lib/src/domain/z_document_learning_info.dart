/// État d'apprentissage **par page** d'un document (ES-2.1, FR-S4).
///
/// origine: lex_core (module « Étude ») — `entities/education/document_learning_info.dart`.
///
/// ## 🔴 Pourquoi cette classe est ÉCRITE À LA MAIN (D3 — contrainte MACHINE)
///
/// Le générateur `zcrud` **ne supporte AUCUN type `Map`** : `_classify`
/// (`zcrud_model_generator.dart`) accepte **exactement** `String`, `int`,
/// `double`, `num`, `bool`, `DateTime`, un **enum**, un sous-modèle `@ZcrudModel`
/// et les `List<` de ces types — il n'existe **aucune branche `isDartCoreMap`**.
/// Un champ `qualityByPage: Map<int, int>` annoté `@ZcrudField` fait donc
/// **ÉCHOUER LE BUILD** (« Type de champ non (dé)sérialisable »).
///
/// **Confirmation indépendante** : dans lex, `document_learning_info.dart` est la
/// **seule** des trois entités « document » **sans `@JsonSerializable`** — elle y
/// est écrite à la main, `fromJson`/`toJson` compris. lex a rencontré la **même**
/// contrainte.
///
/// ⇒ **VO PUR** : aucune annotation, aucun `.g.dart`, aucun `kind`, **pas de
/// registrar**. N'étant **ni `ZExtensible` ni enregistrée**, elle sort de `E_disk`
/// **et** de `R_disk` du gate `reserved-keys` ⇒ **aucun câblage `manual_probes.dart`
/// n'est requis** (ce fichier est réservé aux entités hand-written **ET**
/// `ZExtensible` — cas `ZMindmap`/`ZMindmapNode`).
///
/// Pur Dart — aucune dépendance Flutter/Firebase/Hive (NFR-S3/SM-S5).
library;

import 'package:zcrud_core/domain.dart';

import 'z_doc_page_quality.dart';

/// Clé persistée de la map d'apprentissage (snake_case, imbriquée sous `learning`).
const String kQualityByPageKey = 'quality_by_page';

/// Qualité d'apprentissage **par page** d'un document, colocalisée dans
/// l'**état PERSONNEL** [ZDocumentReadingState] (AD-26 — jamais dans le
/// sous-arbre partageable du document).
///
/// [qualityByPage] associe chaque **page 1-based** à sa qualité entière
/// ([ZDocPageQuality.value]). Une page **absente** compte comme « à revoir » : le
/// décompte de maîtrise part de zéro.
///
/// **Persistance** : `{"quality_by_page": {"1": 2, "3": 0}}` — clés = numéro de
/// page en **`String`** (seule forme valide en JSON/Firestore), valeurs = `int`.
class ZDocumentLearningInfo {
  /// Primitif de reconstruction `const` (bas niveau).
  ///
  /// ⚠️ **Ne filtre pas** [qualityByPage] : un constructeur `const` ne le peut
  /// pas, et **un `assert` serait un CONTRESENS ici** — le décodage généré
  /// construit l'entité avec les valeurs **brutes** avant sanitisation, donc un
  /// `assert` ferait **THROW la désérialisation d'une donnée corrompue**, en
  /// violation directe d'**AD-10** (« un champ absent/corrompu ne fait JAMAIS
  /// échouer le parent »).
  ///
  /// La garde de l'invariant « pages **1-based**, valeurs entières » vit donc aux
  /// **frontières réelles**, et **à TOUTES** : [fromJson]/[fromJsonSafe]
  /// (désérialisation — la seule voie par laquelle une donnée corrompue peut
  /// entrer), [mark] **et** [copyWith] (mutation applicative). Cf. `_guard`.
  ///
  /// 🔴 **DW-ES24-1 (ES-3.0)** : le slot STOCKÉ [_qualityByPage] reste **BRUT**
  /// (le ctor `const` ne peut RIEN filtrer, AD-10 y interdit l'`assert`) ; c'est
  /// l'**ACCESSEUR** [qualityByPage] qui rend une vue **NON MODIFIABLE**
  /// (`zUnmodifiableScalarMap`) — **INCONDITIONNELLEMENT**, y compris quand ce ctor
  /// `const` est invoqué non-`const` avec une réf mutable retenue.
  const ZDocumentLearningInfo({
    Map<int, int> qualityByPage = const <int, int>{},
    // ignore: prefer_initializing_formals
  }) : _qualityByPage = qualityByPage;

  /// État vide (aucune page évaluée) — **défaut sûr** de toute dégénérescence.
  static const ZDocumentLearningInfo empty = ZDocumentLearningInfo();

  /// Reconstruit **défensivement** depuis la map persistée — **ne throw JAMAIS**
  /// (AD-10, AC5/AC11).
  ///
  /// Chaque entrée est **validée puis IGNORÉE si invalide** (jamais d'échec du
  /// parent) :
  /// - `quality_by_page` **absente** ou **non-map** ⇒ [empty] ;
  /// - clé **non parsable** en `int` (`"abc"`) ⇒ entrée ignorée ;
  /// - page **`< 1`** (`"0"`, `"-3"`) ⇒ entrée ignorée — l'indexation est
  ///   **1-based** (alignée sur les viewers PDF) ; une page `0`/négative est une
  ///   corruption, pas une donnée ;
  /// - valeur **ni `num` ni `String` numérique** (`"x"`, une map, `null`) ⇒
  ///   entrée ignorée.
  ///
  /// 🟡 **L1 (code-review ES-2.1) — la COERCION `String` est DÉSORMAIS EXPLICITE.**
  /// La v1 rejetait `{'1': '2'}` (`if (value is! num) continue;`) : une qualité
  /// persistée en **chaîne** — coercion Firestore/Hive, ou **repliage legacy
  /// IFFD** (ES-11.2 : le `quality` d'IFFD vient d'un **autre schéma**, 1 ligne
  /// par page) — faisait **DISPARAÎTRE l'entrée EN SILENCE**, au moment précis du
  /// chantier de migration. C'était une **incohérence de tolérance** : **tout le
  /// reste du package coerce** les scalaires (`_$asInt` accepte `String`).
  /// ⇒ On **coerce** (comme le codegen), on ne rejette plus. Rejeter aurait été
  /// une **perte muette** (R6 : aucune dégradation silencieuse).
  factory ZDocumentLearningInfo.fromJson(Map<String, dynamic> json) {
    final raw = json[kQualityByPageKey];
    if (raw is! Map) return empty;
    final map = <int, int>{};
    for (final entry in raw.entries) {
      final page = int.tryParse('${entry.key}');
      // Pages **1-based** : `0`, négatif ou non parsable ⇒ entrée REJETÉE.
      if (page == null || page < 1) continue;
      final value = _asQuality(entry.value);
      if (value == null) continue;
      map[page] = value;
    }
    // M3 : la map exposée est NON MODIFIABLE (comme `extra` sur les deux
    // `ZExtensible` du package) — une mutation en place contournerait
    // l'invariant 1-based, changerait le `hashCode` (une SOMME) et perdrait
    // l'instance dans son propre `Set`.
    return map.isEmpty
        ? empty
        : ZDocumentLearningInfo(qualityByPage: _guard(map));
  }

  /// Coerce défensivement une **valeur de qualité** persistée (L1) — `null` si
  /// elle n'est pas interprétable (l'entrée est alors ignorée, jamais de throw).
  ///
  /// Accepte `num` **et** `String` numérique (`'2'`, `'2.0'`) — même tolérance
  /// que le décodage généré (`_$asInt`/`_$asNum`). Rejette tout le reste (`'x'`,
  /// une map, une liste, `null`, `bool`).
  static int? _asQuality(Object? raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return num.tryParse(raw)?.toInt();
    return null;
  }

  /// Rend une map de qualités **NON MODIFIABLE** et **filtrée** sur l'invariant
  /// « pages **1-based** » (M3 + R-H, code-review ES-2.1).
  ///
  /// 🔴 **Pourquoi (M3)** : [qualityByPage] était une `Map` **MUTABLE exposée**
  /// (alors qu'`extra` est `unmodifiable` sur les deux `ZExtensible` du package —
  /// incohérence directe). Conséquence **mesurable** :
  ///
  /// ```dart
  /// final i = ZDocumentLearningInfo.fromJson({'quality_by_page': {'1': 2}});
  /// final s = <ZDocumentLearningInfo>{i};
  /// i.qualityByPage[0] = 2;   // page 0 : invariant 1-based CONTOURNÉ
  /// s.contains(i);            // ⇒ FALSE : le hashCode (somme) a CHANGÉ,
  ///                           //   l'instance s'est PERDUE dans son propre Set
  /// i.toJson();               // ⇒ {'0': 2} PERSISTÉ, puis SILENCIEUSEMENT
  ///                           //   REJETÉ à la relecture ⇒ round-trip cassé
  /// ```
  ///
  /// La garde vit donc à **TOUTES** les frontières qui construisent une map :
  /// [fromJson], [mark] et [copyWith] — plus seulement à la désérialisation.
  static Map<int, int> _guard(Map<int, int> raw) =>
      // DW-ES24-1 : vue NON MODIFIABLE (idempotente ⇒ l'accesseur la rend TELLE
      // QUELLE, zéro-copie sur le chemin chaud fromJson/mark/copyWith — AC14).
      zUnmodifiableScalarMap(<int, int>{
        for (final e in raw.entries)
          if (e.key >= 1) e.key: e.value,
      });

  /// Décodage **tolérant à tout** d'une valeur brute de store (canal
  /// **hors-codegen** de [ZDocumentReadingState], patron `ZFlashcard.source`).
  ///
  /// [raw] non-map (`42`, `"x"`, `null`, une liste) ⇒ [empty]. Une `Map` à clés
  /// non-`String` (Hive / map forgée) est **coercée** sans throw.
  static ZDocumentLearningInfo fromJsonSafe(Object? raw) {
    if (raw is Map<String, dynamic>) return ZDocumentLearningInfo.fromJson(raw);
    if (raw is Map) {
      try {
        return ZDocumentLearningInfo.fromJson(<String, dynamic>{
          for (final e in raw.entries) '${e.key}': e.value,
        });
      } catch (_) {
        return empty;
      }
    }
    return empty;
  }

  /// Qualité par page **1-based** (page absente ⇒ [ZDocPageQuality.toReview]).
  ///
  /// 🔴 **NON MODIFIABLE INCONDITIONNELLEMENT** (DW-ES24-1) : l'accesseur rend une
  /// vue `unmodifiable` du slot brut — une mutation en place lève `UnsupportedError`,
  /// **même** sur une instance née du ctor `const` invoqué non-`const`. Sans quoi
  /// elle changerait le [hashCode] (une **somme**) et **perdrait l'instance dans
  /// son propre `Set`**.
  Map<int, int> get qualityByPage => zUnmodifiableScalarMap(_qualityByPage);

  /// Slot **BRUT tel que reçu par le constructeur** — lu **NULLE PART** ailleurs
  /// que dans l'accesseur [qualityByPage] (le ctor `const` ne peut pas le filtrer).
  final Map<int, int> _qualityByPage;

  /// Nombre de pages maîtrisées (qualité `>= mastered`).
  int get masteredCount => qualityByPage.values
      .where((v) => v >= ZDocPageQuality.mastered.value)
      .length;

  /// Qualité de la page [page] (1-based) — [ZDocPageQuality.toReview] si absente
  /// ou corrompue (décodage défensif de la valeur, cf. `ZDocPageQuality.fromJson`).
  ZDocPageQuality qualityOf(int page) =>
      ZDocPageQuality.fromJson(qualityByPage[page]);

  /// `true` si la page [page] (1-based) est maîtrisée.
  bool isMastered(int page) => qualityOf(page).isMastered;

  /// Copie où la page [page] (**1-based**) prend la qualité [quality].
  ///
  /// **Garde d'invariant (R-H)** : une page `< 1` est **hors du domaine de
  /// définition** ⇒ l'appel est un **no-op** (retourne `this`), jamais un throw
  /// (cette API est appelée depuis un viewer, à partir d'indices de page : la
  /// faire crasher l'écran de lecture serait pire que d'ignorer une page
  /// impossible). Symétrique du rejet opéré par [fromJson].
  ZDocumentLearningInfo mark(int page, ZDocPageQuality quality) {
    if (page < 1) return this;
    final next = Map<int, int>.from(qualityByPage);
    next[page] = quality.value;
    // M3 : la map rendue est NON MODIFIABLE (elle ne l'était pas — un
    // `i.qualityByPage[0] = 2` a posteriori contournait l'invariant 1-based,
    // changeait le `hashCode` et perdait l'instance dans son propre `Set`).
    return ZDocumentLearningInfo(qualityByPage: _guard(next));
  }

  /// Bascule idempotente d'une page entre « maîtrisée » et « à revoir ».
  ZDocumentLearningInfo toggle(int page) => mark(
        page,
        isMastered(page) ? ZDocPageQuality.toReview : ZDocPageQuality.mastered,
      );

  /// Copie **gardée** : la map fournie est **filtrée** (pages `< 1` rejetées) et
  /// rendue **NON MODIFIABLE** (M3 + H2 « cherche le même trou partout »).
  ///
  /// Un invariant de valeur a **DEUX** frontières — la **désérialisation**
  /// ([fromJson]) **et** la **mutation applicative** ([mark], `copyWith`). Ne
  /// fermer que la première laisse la garde **ROUVRABLE** :
  /// `i.copyWith(qualityByPage: {0: 2})` persistait une page `0` que la relecture
  /// **rejette silencieusement** ⇒ round-trip **non idempotent**.
  ZDocumentLearningInfo copyWith({Map<int, int>? qualityByPage}) =>
      ZDocumentLearningInfo(
        qualityByPage: _guard(qualityByPage ?? this.qualityByPage),
      );

  /// Sérialise vers la map persistée : clés de page en **`String`**, valeurs `int`.
  ///
  /// Round-trip **stable** : `fromJson(toJson(i)) == i` (les entrées invalides ne
  /// peuvent pas exister dans une instance issue de [fromJson]).
  Map<String, dynamic> toJson() => <String, dynamic>{
        kQualityByPageKey: <String, dynamic>{
          for (final entry in qualityByPage.entries)
            entry.key.toString(): entry.value,
        },
      };

  /// Égalité **ordre-indépendante** (portée verbatim de lex).
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ZDocumentLearningInfo) return false;
    if (other.qualityByPage.length != qualityByPage.length) return false;
    for (final entry in qualityByPage.entries) {
      if (other.qualityByPage[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Hash **COMMUTATIF** (somme), donc **indépendant de l'ordre d'itération** de
  /// la map — en cohérence avec [operator ==], lui aussi ordre-indépendant.
  ///
  /// ⚠️ **Ne pas « corriger » en `Object.hashAll`** : deux instances **égales**
  /// construites dans des ordres d'insertion différents (JSON relu vs suite de
  /// [mark]) produiraient des hash **différents** — le contrat `==`/`hashCode`
  /// serait rompu (elles se perdraient dans un `Set`/`Map`). La somme est le choix
  /// **correct** ici, pas une négligence (AC5).
  @override
  int get hashCode {
    var acc = 0;
    for (final entry in qualityByPage.entries) {
      acc = acc + Object.hash(entry.key, entry.value);
    }
    return acc;
  }

  @override
  String toString() => 'ZDocumentLearningInfo(qualityByPage: $qualityByPage)';
}
