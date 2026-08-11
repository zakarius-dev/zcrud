/// `ZStudySessionResult` — value-object pur du résultat d'une session
/// d'étude.
///
/// Aucun identifiant, aucun `folderId`, aucune date : c'est le résumé d'un
/// parcours (mode + total + réponses correctes + répartition des qualités
/// SM-2).
///
/// ## Pourquoi un value-object pur, et non un modèle enregistré
///
/// [ZStudySessionResult] n'est le champ (sous-modèle) d'aucune entité
/// enregistrée du kernel — il n'a donc aucune raison d'être un modèle
/// `@ZcrudModel`. De plus, son [byQuality] (`Map<String,int>`) n'est pas
/// codegen-able : le générateur ne sait pas classifier un type `Map` en
/// champ. Le rendre `@ZcrudModel` forcerait un canal hors-codegen, une clé
/// réservée et un câblage de registre pour un gain nul.
///
/// Conséquence : aucun câblage du gate de clés réservées (ni registrar, ni
/// nature, ni écriture dans `extra`).
///
/// ## Défensif et total (invariant AD-10) — jamais de `throw`
///
/// [ZStudySessionResult.fromMap] ne lève jamais, pas même sur une map vide :
/// `mode` inconnu/absent → [ZReviewMode.spaced] ; `total`/`correct` absent,
/// non-`num`, ou négatif → `0` ; [byQuality] décodé défensivement à deux
/// niveaux (map absente/non-`Map` → `{}` ; valeur non-`int` → paire
/// ignorée ; clés verbatim), rendu non modifiable.
///
/// Pur-Dart, sans dépendance Flutter. Non `ZExtensible` : ce n'est pas un
/// point d'extension (invariant AD-4).
library;

import 'package:zcrud_core/domain.dart';

import 'z_review_mode.dart';

/// Résultat d'une session d'étude — value-object immuable.
///
/// `mode` (mode de révision), `total` (cartes vues), `correct` (bonnes
/// réponses), [byQuality] (qualité SM-2 `"0".."5"` → compte). Persisté en
/// snake_case (`by_quality`), valeurs d'enum en camelCase (`mode.name`).
class ZStudySessionResult {
  /// Construit un résultat de session (constructeur `const`).
  ///
  /// Aucun filtre ni `assert` ici (invariant AD-10) : l'immuabilité non
  /// modifiable de [byQuality] est portée par la frontière [fromMap] (la
  /// seule qui reçoit des valeurs brutes du corpus persisté). Un appelant
  /// qui passe une `Map` mutable en mémoire obtient un objet qui la
  /// référence — c'est son invariant à tenir.
  ///
  /// Le slot stocké interne reste brut (le constructeur `const` ne filtre
  /// rien, l'invariant AD-10 y interdit l'`assert`) ; c'est l'accesseur
  /// [byQuality] qui rend une vue non modifiable inconditionnellement.
  const ZStudySessionResult({
    this.mode = ZReviewMode.spaced,
    this.total = 0,
    this.correct = 0,
    Map<String, int> byQuality = const <String, int>{},
    // ignore: prefer_initializing_formals
  }) : _byQuality = byQuality;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10)
  /// — ne lève jamais, pas même sur une map vide.
  ///
  /// - `mode` : décodé par nom (camelCase) avec repli [ZReviewMode.spaced]
  ///   (absent/inconnu → `spaced`, jamais de cast dur) ;
  /// - `total`/`correct` : `int` avec repli `0` (absent, non-`num`, ou
  ///   négatif → `0`) ;
  /// - `by_quality` : décodage défensif à deux niveaux (map absente/non-
  ///   `Map` → `{}` ; valeur non-`int` → paire ignorée ; clés verbatim),
  ///   rendu non modifiable.
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

  /// Nombre de réponses correctes (défaut `0`, jamais négatif après
  /// [fromMap]).
  final int correct;

  /// Répartition `qualité SM-2 → compte` (défaut `const {}`).
  ///
  /// Rendu non modifiable inconditionnellement : l'accesseur rend une vue
  /// `unmodifiable` du slot brut — muter en place lève `UnsupportedError`,
  /// même sur une instance née du constructeur `const` invoqué non-`const`.
  /// Sans quoi le [hashCode] changerait et l'instance se perdrait dans son
  /// propre `Set`. Clés opaques (verbatim, ex. `"0".."5"`).
  Map<String, int> get byQuality => zUnmodifiableScalarMap(_byQuality);

  /// Slot brut tel que reçu par le constructeur — lu nulle part ailleurs que
  /// dans l'accesseur [byQuality] (le constructeur `const` ne peut pas le
  /// filtrer).
  final Map<String, int> _byQuality;

  /// Sérialise vers la map persistée (snake_case, `mode` en camelCase
  /// `name`).
  ///
  /// `by_quality` réémis en `Map<String,int>` plate (copie fraîche) —
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
  // Décodage défensif (invariant AD-10) — aucune de ces fonctions ne lève.
  // ---------------------------------------------------------------------------

  /// Décode `mode` par nom (camelCase), repli [ZReviewMode.spaced] — jamais
  /// de cast dur (une valeur inconnue/absente/non-`String` retombe sur
  /// `spaced`).
  static ZReviewMode _decodeMode(Object? raw) {
    for (final value in ZReviewMode.values) {
      if (value.name == raw) return value;
    }
    return ZReviewMode.spaced;
  }

  /// Décode un compteur : `num` clampé à `>= 0` ; toute autre valeur
  /// (absente, `String`, `bool`…) ou négative → `0` (repli sûr).
  static int _decodeCount(Object? raw) {
    if (raw is num) {
      final v = raw.toInt();
      return v < 0 ? 0 : v;
    }
    return 0;
  }

  /// Décode [byQuality] à deux niveaux (invariant AD-10) — jamais de
  /// `throw`, rend une map non modifiable.
  ///
  /// - Niveau 1 : `by_quality` absente / non-`Map` (`42`, `"x"`, une liste)
  ///   → `{}` ;
  /// - Niveau 2 : valeur non-`int` (`'nan'`, `2.0`, `null`) → paire ignorée
  ///   (jamais de nettoyage silencieux du reste) ;
  /// - clés verbatim (opaques, `''` toléré).
  static Map<String, int> _decodeByQuality(Object? raw) {
    if (raw is! Map) return const <String, int>{};
    final out = <String, int>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      // Niveau 2 : valeur non-`int` ⇒ paire ignorée (clé opaque verbatim).
      if (value is int) out['${entry.key}'] = value;
    }
    // Vue non modifiable (idempotente ⇒ accesseur zéro-copie).
    return zUnmodifiableScalarMap(out);
  }

  // ---------------------------------------------------------------------------
  // Égalité de valeur — [byQuality] commutatif sur les clés.
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

  /// Égalité ensembliste sur les clés (l'ordre d'insertion n'a aucun sens),
  /// valeurs comparées (`{'0':1} != {'0':2}` ; `{'0':1} != {'1':1}`).
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

  /// Hash commutatif (somme sur les paires ⇒ indépendant de l'ordre des
  /// clés) mais sensible aux clés ET aux valeurs (`Object.hash(key,
  /// value)`).
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
