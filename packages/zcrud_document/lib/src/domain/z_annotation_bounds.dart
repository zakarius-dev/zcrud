/// Rectangle d'ancrage borné `[0,1]` `ZAnnotationBounds` (ES-2.5, FR-S8,
/// AC1–AC4) — **value object pur Dart**.
///
/// origine: lex_core (module « Étude ») —
/// `entities/education/annotation_bounds.dart` (`AnnotationBounds {x, y, width,
/// height}`, fractions `[0,1]` de la page).
///
/// ## 🔴 D3 — `dart:ui` REJETÉ ; `fromPageRect`/`toPageRect` NON portés
///
/// La source lex **importe `dart:ui`** (`Rect`/`Size`) pour les helpers de
/// conversion espace-page ↔ fractions. `zcrud_document` est **pur Dart** (tests
/// sous `dart test`, NFR-S3/SM-S5) : `dart:ui` = Flutter, **interdit**. La
/// conversion géométrique a besoin de la **taille de page mesurée** par le viewer
/// ⇒ c'est un **seam de présentation** (ES-8.2, côté app). Le domaine ne porte
/// que les **4 fractions bornées** — précédent `ZDocumentViewerPrefs` (enums
/// Syncfusion refusés, mapping en presentation).
///
/// ## 🔴 D4 — Invariant `[0,1]` AJOUTÉ (assumé vs lex — R-H/R1)
///
/// lex **ne borne pas** x/y/w/h (la dartdoc « fractions [0,1] » est de la prose,
/// qu'aucune machine ne tient). L'AC FR-S8 exige « bornée [0,1] » ⇒ l'invariant
/// naît **avec sa garde** [sanitizeCoord], appliquée aux **DEUX frontières
/// réelles** : [fromMap] (désérialisation) **ET** [copyWith] (mutation
/// applicative) — **la même fonction nommée aux deux** (leçon H2 : jamais deux
/// jumelles divergentes). Le constructeur `const` **ne sanitise pas** (AD-10 y
/// interdit `assert`/appel de fonction). Précédent EXACT :
/// `ZDocumentViewerPrefs.sanitizeZoomLevel`.
///
/// ## Sous-modèle `@ZcrudModel` NON-`ZExtensible`, codegen-able (D2)
///
/// Les `double` **SONT** codegen-ables (précédent `ZDocumentViewerPrefs.zoomLevel:
/// double @ZcrudField`). En tant que `@ZcrudModel`, il est décodé **défensivement
/// par élément** comme sous-modèle (`bounds` en `subModel`, `rects` en
/// `listModel` — patron `ZChoice`) : une valeur corrompue retombe sur les défauts,
/// **jamais de throw du parent** (AD-10). Aucun slot `extra`/`extension`.
///
/// 🔴 **L'extension générée `ZAnnotationBoundsZcrud` est `hide` du barrel** (M2,
/// leçon EXACTE de `ZDocumentViewerPrefs`) : son `copyWith`/`toMap` généré,
/// appelable **explicitement** depuis l'API publique, **CONTOURNERAIT**
/// [sanitizeCoord] (un VO à invariant de valeur a « quelque chose à perdre »).
/// [toMap] est donc **promu en méthode d'INSTANCE** (surface (dé)sérialisation
/// préservée, porte du `copyWith` fermée).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

part 'z_annotation_bounds.g.dart';

/// Rectangle d'ancrage d'une annotation, en **fractions `[0,1]`** de la page.
///
/// Pour un surlignage, c'est le rectangle **enveloppe** ; pour une sticky note,
/// c'est un **point** (coin haut-gauche). Indépendant du zoom/scroll/layout.
@ZcrudModel(kind: 'annotation_bounds')
class ZAnnotationBounds {
  /// Primitif de reconstruction `const` (source du `copyWith` généré).
  ///
  /// ⚠️ **Ne sanitise pas** les coordonnées (un constructeur `const` ne le peut
  /// pas — AD-10 y interdit `assert`/appel de fonction). La garde [sanitizeCoord]
  /// vit aux **deux frontières réelles** : [fromMap] (désérialisation — la seule
  /// voie par laquelle une valeur corrompue peut entrer) et [copyWith] (**méthode
  /// d'INSTANCE**, qui *masque* le `copyWith` de l'extension générée — mutation
  /// applicative).
  const ZAnnotationBounds({
    this.x = 0.0,
    this.y = 0.0,
    this.width = 0.0,
    this.height = 0.0,
  });

  /// Reconstruit **défensivement** depuis une map persistée (AD-10, AC2/AC3).
  ///
  /// Délègue au `_$ZAnnotationBoundsFromMap` **généré** (défauts sûrs : coord
  /// absente / non numérique — `'x': 'abc'`, `null`, `[]` — → `0.0` au décodage,
  /// `_$asDouble` rendant `null`), **puis SANITISE** les 4 coordonnées via
  /// [sanitizeCoord] — le codegen, lui, ne borne rien.
  ///
  /// ⚠️ Corps volontairement **NON NU** : c'est le point d'entrée où une valeur
  /// persistée corrompue (`NaN`, `-3`, `5.0`, `1e9`) peut entrer dans le domaine.
  /// `ZAnnotationBounds.fromMap(const {})` rend `(0,0,0,0)` — **jamais de throw**.
  factory ZAnnotationBounds.fromMap(Map<String, dynamic> map) {
    final base = _$ZAnnotationBoundsFromMap(map);
    return ZAnnotationBounds(
      x: sanitizeCoord(base.x),
      y: sanitizeCoord(base.y),
      width: sanitizeCoord(base.width),
      height: sanitizeCoord(base.height),
    );
  }

  /// Ramène une coordonnée dans son domaine `[0,1]` — **ne throw jamais**.
  ///
  /// - **non finie** (`NaN`, `±Infinity`) ⇒ `0.0` ;
  /// - sinon **clampée** dans `[0.0, 1.0]` (`raw.clamp(0.0, 1.0)`).
  ///
  /// Déclarée **publique et NOMMÉE** : la garde est ainsi **la même fonction** aux
  /// deux frontières ([fromMap] et [copyWith]) — impossible qu'une des deux
  /// dérive (leçon H2). Précédent : `ZDocumentViewerPrefs.sanitizeZoomLevel`.
  static double sanitizeCoord(double raw) {
    if (!raw.isFinite) return 0.0;
    return raw.clamp(0.0, 1.0);
  }

  /// Abscisse du coin haut-gauche, fraction `[0,1]` de la largeur de page
  /// (défaut `0.0` ; **clampée** à toute frontière — cf. [sanitizeCoord]).
  @ZcrudField()
  final double x;

  /// Ordonnée du coin haut-gauche, fraction `[0,1]` de la hauteur de page
  /// (défaut `0.0` ; **clampée** à toute frontière).
  @ZcrudField()
  final double y;

  /// Largeur, fraction `[0,1]` de la largeur de page (défaut `0.0` ; **clampée**).
  @ZcrudField()
  final double width;

  /// Hauteur, fraction `[0,1]` de la hauteur de page (défaut `0.0` ; **clampée**).
  @ZcrudField()
  final double height;

  /// Sérialise vers la map persistée (snake_case) — **méthode d'INSTANCE**.
  ///
  /// 🔴 **M2** : l'extension générée `ZAnnotationBoundsZcrud` est **`hide` du
  /// barrel** — son `copyWith` généré, appelable **explicitement**
  /// (`ZAnnotationBoundsZcrud(b).copyWith(x: 5)`), **CONTOURNAIT** [sanitizeCoord]
  /// depuis l'API PUBLIQUE (le masquage par le `copyWith` d'instance ne vaut que
  /// pour l'appel **implicite**). Le `toMap()` du barrel disparaissant avec le
  /// `hide`, il est **promu en méthode d'instance** : la surface publique de
  /// (dé)sérialisation est **préservée**, **sans** rouvrir la porte du `copyWith`.
  Map<String, dynamic> toMap() => ZAnnotationBoundsZcrud(this).toMap();

  /// Copie **re-clampée** — **méthode d'INSTANCE**, qui *masque* le `copyWith` de
  /// l'extension générée `ZAnnotationBoundsZcrud` (un membre d'instance gagne
  /// toujours sur un membre d'extension) — et l'extension elle-même est **`hide`
  /// du barrel** (M2), donc **inatteignable** depuis l'API publique.
  ///
  /// C'est **volontaire** : le `copyWith` généré accepterait `x: 5` **sans
  /// broncher**, rouvrant l'invariant que [fromMap] ferme. Tous les champs étant
  /// non-nullables, la sémantique « argument omis ⇒ valeur conservée » suffit
  /// (aucune sentinelle de reset-`null` nécessaire).
  ZAnnotationBounds copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) =>
      ZAnnotationBounds(
        x: sanitizeCoord(x ?? this.x),
        y: sanitizeCoord(y ?? this.y),
        width: sanitizeCoord(width ?? this.width),
        height: sanitizeCoord(height ?? this.height),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZAnnotationBounds &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() =>
      'ZAnnotationBounds(x: $x, y: $y, width: $width, height: $height)';
}
