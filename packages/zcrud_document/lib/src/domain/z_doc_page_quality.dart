/// Qualité d'apprentissage d'une page de document.
///
/// Jamais un `@ZcrudField` : cet enum est persisté en entier (ordinal
/// extensible, aligné sur l'échelle SM-2), or le générateur zcrud sérialise
/// les enums par nom : il ne sait pas persister un enum en `int`. L'annoter
/// comme champ produirait une (dé)sérialisation silencieusement fausse. Il
/// ne vit que dans la map écrite à la main `qualityByPage` de
/// [ZDocumentLearningInfo] (valeurs `int`), via les [fromJson]/[toJson]
/// manuels ci-dessous.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/Hive.
library;

/// Qualité d'une page : à revoir (défaut) ou maîtrisée.
///
/// Sérialisé en entier : `toReview = 0`, `mastered = 2`. L'échelle laisse
/// délibérément la place à une valeur intermédiaire future (« vu » = 1) sans
/// casser le stockage `quality_by_page` existant (invariant AD-10 :
/// évolution additive).
///
/// L'ordre de déclaration suit la convention du défaut sûr en premier, même
/// si cet enum n'est jamais décodé par le générateur.
enum ZDocPageQuality {
  /// Page à revoir — défaut d'une page non évaluée (ou de toute valeur < 2).
  toReview(0),

  /// Page maîtrisée (« j'ai compris cette page »).
  mastered(2);

  const ZDocPageQuality(this.value);

  /// Valeur entière persistée dans `quality_by_page`.
  final int value;

  /// Désérialise depuis l'entier stocké — défensif, ne lève jamais
  /// (invariant AD-10).
  ///
  /// Toute valeur `>= mastered.value` (2) est « maîtrisée » ; toute valeur
  /// `< 2`, ainsi que `null` ou une valeur non numérique, retombe sur
  /// [toReview] (défaut sûr). Une valeur intermédiaire future (`1`) se lit
  /// donc « à revoir » tant qu'elle n'est pas déclarée — jamais une erreur.
  static ZDocPageQuality fromJson(Object? raw) {
    final v = raw is num ? raw.toInt() : 0;
    return v >= mastered.value ? ZDocPageQuality.mastered : ZDocPageQuality.toReview;
  }

  /// Sérialise vers l'entier stocké.
  int toJson() => value;

  /// `true` si la page est considérée maîtrisée.
  bool get isMastered => this == ZDocPageQuality.mastered;
}
