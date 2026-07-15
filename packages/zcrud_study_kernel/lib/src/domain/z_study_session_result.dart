/// `ZStudySessionResult` — value-object PUR du résultat d'UNE session d'étude
/// (ES-2.7, **FR-S10**).
///
/// origine: lex_core (module « Étude ») —
/// `entities/education/study_session.dart` (`StudySessionResult`,
/// `@JsonSerializable(fieldRename: snake)`, `{mode, total, correct,
/// byQuality: Map(String,int)}`). **AUCUN `id`, AUCUN `folderId`, AUCUNE
/// `date`** : c'est le résumé d'un run (mode + total + correct + répartition
/// des qualités SM-2).
///
/// ## 🔴 D1 — pourquoi un value-object PUR, et NON un `@ZcrudModel`
///
/// La source lex est un simple `@JsonSerializable` **sans `id`** ; l'épic ET le
/// PRD le nomment explicitement **« value-object »**. ⇒ patron VO PUR du repo
/// (précédent EXACT [ZReminderTime] d'ES-2.6 : classe pure, `fromMap`/`toMap`
/// **écrits à la main**, `==`/`hashCode` de valeur, AUCUN codegen, AUCUN
/// `@JsonSerializable`, AUCUN `registerZ…`).
///
/// Deux raisons TECHNIQUES de rester VO pur plutôt que `@ZcrudModel` :
/// 1. [ZStudySessionResult] n'est le champ (sous-modèle) d'AUCUNE entité
///    enregistrée de cette story (contraste `ZChoice`⊂`ZFlashcard`) — il n'a
///    donc **aucune raison** d'être `@ZcrudModel` ;
/// 2. son [byQuality] `Map<String,int>` **n'est PAS codegen-able** — le
///    générateur `_classify` n'a **aucune branche `isDartCoreMap`** (cf.
///    `ZFolderContentsOrder.sectionOrders`). Le rendre `@ZcrudModel` forcerait
///    un canal hors-codegen + une clé réservée + un câblage de gate, pour un
///    gain **nul**.
///
/// Conséquence : **aucun câblage du gate `reserved-keys`** (ni registrar, ni
/// kind, ni writer `extra`) — AC14.
///
/// ## Défensif et TOTAL (AD-10) — jamais de throw
///
/// [ZStudySessionResult.fromMap] ne **throw JAMAIS**, pas même
/// `ZStudySessionResult.fromMap(const {})` : `mode` inconnu/absent → [ZReviewMode.spaced] ;
/// `total`/`correct` absent, non-`num`, ou **négatif** → `0` ; [byQuality]
/// décodé **défensivement à 2 niveaux** (map absente/non-`Map` → `{}` ; valeur
/// non-`int` → paire **ignorée** ; clés **verbatim**), rendu **NON MODIFIABLE**.
///
/// **Pur-Dart, Flutter-free** : aucune dépendance Material/Firebase.
/// **NON `ZExtensible`** : ce n'est pas un point d'extension (AD-4).
library;

import 'package:zcrud_core/domain.dart';

import 'z_review_mode.dart';

/// Résultat d'UNE session d'étude — value-object immuable (D1).
///
/// `mode` (mode de révision), `total` (cartes vues), `correct` (bonnes
/// réponses), [byQuality] (`qualité SM-2 "0".."5" → compte`). Persisté en
/// snake_case (`by_quality`), valeurs d'enum en **camelCase** (`mode.name`).
class ZStudySessionResult {
  /// Construit un résultat de session (primitif `const`).
  ///
  /// ⛔ **AUCUN filtre / `assert` ici** (AD-10, patron des VO `const` du repo,
  /// cf. [ZReminderTime]) : l'immuabilité NON MODIFIABLE de [byQuality] est
  /// portée par la frontière [fromMap] (la seule qui reçoit des valeurs BRUTES
  /// du corpus persisté). Un appelant qui passe une `Map` mutable en mémoire
  /// obtient un VO qui la référence — c'est **son** invariant à tenir.
  ///
  /// 🔴 **DW-ES24-1 (ES-3.0)** : le slot STOCKÉ [_byQuality] reste **BRUT** (ctor
  /// `const` : ne filtre RIEN, AD-10 y interdit l'`assert`) ; c'est l'**ACCESSEUR**
  /// [byQuality] qui rend une vue **NON MODIFIABLE INCONDITIONNELLEMENT**.
  const ZStudySessionResult({
    this.mode = ZReviewMode.spaced,
    this.total = 0,
    this.correct = 0,
    Map<String, int> byQuality = const <String, int>{},
    // ignore: prefer_initializing_formals
  }) : _byQuality = byQuality;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10, D6) — **ne
  /// throw JAMAIS**, pas même `ZStudySessionResult.fromMap(const {})`.
  ///
  /// - `mode` : décodé par nom (camelCase) avec repli [ZReviewMode.spaced]
  ///   (absent/inconnu → `spaced`, jamais de cast dur) ;
  /// - `total`/`correct` : `int` avec fallback **`0`** (absent, non-`num`, ou
  ///   **négatif** → `0`) ;
  /// - `by_quality` : décodage **défensif à 2 niveaux** (map absente/non-`Map`
  ///   → `{}` ; valeur non-`int` → paire **ignorée** ; clés **verbatim**),
  ///   rendu **NON MODIFIABLE**.
  factory ZStudySessionResult.fromMap(Map<String, dynamic> map) =>
      ZStudySessionResult(
        mode: _decodeMode(map['mode']),
        total: _decodeCount(map['total']),
        correct: _decodeCount(map['correct']),
        byQuality: _decodeByQuality(map['by_quality']),
      );

  /// Mode de révision (défaut [ZReviewMode.spaced], repli défensif).
  final ZReviewMode mode;

  /// Nombre total de cartes vues dans la session (défaut `0`, jamais négatif
  /// après [fromMap]).
  final int total;

  /// Nombre de réponses correctes (défaut `0`, jamais négatif après [fromMap]).
  final int correct;

  /// Répartition `qualité SM-2 → compte` (défaut `const {}`).
  ///
  /// 🔴 Rendu **NON MODIFIABLE INCONDITIONNELLEMENT** (DW-ES24-1) : l'accesseur
  /// rend une vue `unmodifiable` du slot brut — muter en place lève
  /// `UnsupportedError`, **même** sur une instance née du ctor `const` invoqué
  /// non-`const`. Sans quoi le [hashCode] changerait et l'instance se perdrait
  /// dans son propre `Set`. Clés **opaques** (verbatim, ex. `"0".."5"`).
  Map<String, int> get byQuality => zUnmodifiableScalarMap(_byQuality);

  /// Slot **BRUT tel que reçu par le constructeur** — lu **NULLE PART** ailleurs
  /// que dans l'accesseur [byQuality] (le ctor `const` ne peut pas le filtrer).
  final Map<String, int> _byQuality;

  /// Sérialise vers la map persistée (snake_case, `mode` en camelCase `name`).
  ///
  /// `by_quality` réémis en `Map<String,int>` **plate** (copie fraîche) —
  /// round-trip idempotent (`ZStudySessionResult.fromMap(r.toMap()) == r`).
  Map<String, dynamic> toMap() => <String, dynamic>{
        'mode': mode.name,
        'total': total,
        'correct': correct,
        'by_quality': <String, int>{
          for (final entry in byQuality.entries) entry.key: entry.value,
        },
      };

  // ---------------------------------------------------------------------------
  // Décodage défensif (AD-10, D6) — aucune de ces fonctions ne throw.
  // ---------------------------------------------------------------------------

  /// Décode `mode` par **nom** (camelCase), repli [ZReviewMode.spaced] — jamais
  /// de cast dur (une valeur inconnue/absente/non-`String` retombe sur `spaced`).
  static ZReviewMode _decodeMode(Object? raw) {
    for (final value in ZReviewMode.values) {
      if (value.name == raw) return value;
    }
    return ZReviewMode.spaced;
  }

  /// Décode un compteur : `num` **clampé à `>= 0`** ; toute autre valeur
  /// (absente, `String`, `bool`…) ou négative → **`0`** (fallback sûr, R6).
  static int _decodeCount(Object? raw) {
    if (raw is num) {
      final v = raw.toInt();
      return v < 0 ? 0 : v;
    }
    return 0;
  }

  /// Décode [byQuality] à **2 niveaux** (AD-10) — jamais de throw, rend une map
  /// **NON MODIFIABLE**.
  ///
  /// - Niveau 1 : `by_quality` absente / non-`Map` (`42`, `"x"`, une liste) → `{}` ;
  /// - Niveau 2 : valeur non-`int` (`'nan'`, `2.0`, `null`) → paire **IGNORÉE**
  ///   (jamais de nettoyage silencieux du reste — R6) ;
  /// - clés **verbatim** (opaques, `''` toléré).
  static Map<String, int> _decodeByQuality(Object? raw) {
    if (raw is! Map) return const <String, int>{};
    final out = <String, int>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      // Niveau 2 : valeur non-`int` ⇒ paire ignorée (clé opaque verbatim).
      if (value is int) out['${entry.key}'] = value;
    }
    // DW-ES24-1 : vue NON MODIFIABLE (idempotente ⇒ accesseur zéro-copie, AC14).
    return zUnmodifiableScalarMap(out);
  }

  // ---------------------------------------------------------------------------
  // Égalité de valeur — [byQuality] COMMUTATIF sur les clés (D7)
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudySessionResult &&
          mode == other.mode &&
          total == other.total &&
          correct == other.correct &&
          _byQualityEquals(byQuality, other.byQuality);

  @override
  int get hashCode =>
      Object.hash(mode, total, correct, _byQualityHash(byQuality));

  /// Égalité D7 : **ensembliste sur les clés** (l'ordre d'insertion n'a aucun
  /// sens), **valeurs comparées** (`{'0':1} != {'0':2}` ; `{'0':1} != {'1':1}`).
  static bool _byQualityEquals(Map<String, int> a, Map<String, int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null && !b.containsKey(entry.key)) return false;
      if (other != entry.value) return false;
    }
    return true;
  }

  /// Hash D7 : **COMMUTATIF** (somme sur les paires ⇒ indépendant de l'ordre des
  /// clés) mais sensible aux clés ET aux valeurs (`Object.hash(key, value)`).
  static int _byQualityHash(Map<String, int> m) {
    var acc = 0;
    for (final entry in m.entries) {
      acc = acc + Object.hash(entry.key, entry.value);
    }
    return acc;
  }

  @override
  String toString() =>
      'ZStudySessionResult(mode: ${mode.name}, total: $total, '
      'correct: $correct, byQuality: $byQuality)';
}
