/// Rectangle d'ancrage borné `[0,1]` `ZAnnotationBounds` — value object pur
/// Dart.
///
/// ## Aucune dépendance à `dart:ui`
///
/// `zcrud_document` est pur Dart (tests sous `dart test`) : `dart:ui`
/// (`Rect`/`Size`) équivaut à Flutter, interdit ici. La conversion
/// géométrique entre un rectangle en pixels et ces fractions a besoin de la
/// taille de page mesurée par le viewer ⇒ c'est un seam de présentation,
/// côté application. Le domaine ne porte que les quatre fractions bornées.
///
/// ## Invariant `[0,1]` porté par une garde machine
///
/// L'invariant naît avec sa garde [sanitizeCoord], appliquée aux deux
/// frontières réelles : [fromMap] (désérialisation) et [copyWith] (mutation
/// applicative) — la même fonction nommée aux deux, jamais deux jumelles
/// divergentes. Le constructeur `const` ne sanitise pas (l'invariant AD-10
/// y interdit `assert`/appel de fonction).
///
/// ## Sous-modèle `@ZcrudModel` non-`ZExtensible`, codegen-able
///
/// Les `double` sont codegen-ables. En tant que `@ZcrudModel`, il est
/// décodé défensivement par élément comme sous-modèle : une valeur
/// corrompue retombe sur les défauts, jamais de `throw` du parent
/// (invariant AD-10). Aucun slot `extra`/`extension`.
///
/// L'extension générée `ZAnnotationBoundsZcrud` est masquée du barrel : son
/// `copyWith`/`toMap` généré, appelable explicitement depuis l'API
/// publique, contournerait [sanitizeCoord] (un value object à invariant de
/// valeur a quelque chose à perdre). [toMap] est donc promu en méthode
/// d'instance (surface de (dé)sérialisation préservée, porte du `copyWith`
/// fermée).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

part 'z_annotation_bounds.g.dart';

/// Rectangle d'ancrage d'une annotation, en fractions `[0,1]` de la page.
///
/// Pour un surlignage, c'est le rectangle enveloppe ; pour une note ancrée,
/// c'est un point (coin haut-gauche). Indépendant du zoom/scroll/layout.
@ZcrudModel(kind: 'annotation_bounds')
class ZAnnotationBounds {
  /// Constructeur bas niveau (`const`, source du `copyWith` généré).
  ///
  /// Ne sanitise pas les coordonnées (un constructeur `const` ne le peut
  /// pas — l'invariant AD-10 y interdit `assert`/appel de fonction). La
  /// garde [sanitizeCoord] vit aux deux frontières réelles : [fromMap]
  /// (désérialisation — la seule voie par laquelle une valeur corrompue
  /// peut entrer) et [copyWith] (méthode d'instance, qui masque le
  /// `copyWith` de l'extension générée — mutation applicative).
  const ZAnnotationBounds({
    this.x = 0.0,
    this.y = 0.0,
    this.width = 0.0,
    this.height = 0.0,
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Délègue au décodeur généré (défauts sûrs : coordonnée absente / non
  /// numérique — `'x': 'abc'`, `null`, `[]` — → `0.0` au décodage), puis
  /// sanitise les quatre coordonnées via [sanitizeCoord] — le codegen, lui,
  /// ne borne rien.
  ///
  /// Corps volontairement non nu : c'est le point d'entrée où une valeur
  /// persistée corrompue (`NaN`, `-3`, `5.0`, `1e9`) peut entrer dans le
  /// domaine. `ZAnnotationBounds.fromMap(const {})` rend `(0,0,0,0)` —
  /// jamais de `throw`.
  factory ZAnnotationBounds.fromMap(Map<String, dynamic> map) {
    final base = _$ZAnnotationBoundsFromMap(map);
    return ZAnnotationBounds(
      x: sanitizeCoord(base.x),
      y: sanitizeCoord(base.y),
      width: sanitizeCoord(base.width),
      height: sanitizeCoord(base.height),
    );
  }

  /// Ramène une coordonnée dans son domaine `[0,1]` — ne lève jamais.
  ///
  /// - non finie (`NaN`, `±Infinity`) ⇒ `0.0` ;
  /// - sinon clampée dans `[0.0, 1.0]` (`raw.clamp(0.0, 1.0)`).
  ///
  /// Déclarée publique et nommée : la garde est ainsi la même fonction aux
  /// deux frontières ([fromMap] et [copyWith]) — impossible qu'une des deux
  /// dérive.
  static double sanitizeCoord(double raw) {
    if (!raw.isFinite) return 0.0;
    return raw.clamp(0.0, 1.0);
  }

  /// Abscisse du coin haut-gauche, fraction `[0,1]` de la largeur de page
  /// (défaut `0.0` ; clampée à toute frontière — voir [sanitizeCoord]).
  @ZcrudField()
  final double x;

  /// Ordonnée du coin haut-gauche, fraction `[0,1]` de la hauteur de page
  /// (défaut `0.0` ; clampée à toute frontière).
  @ZcrudField()
  final double y;

  /// Largeur, fraction `[0,1]` de la largeur de page (défaut `0.0` ;
  /// clampée).
  @ZcrudField()
  final double width;

  /// Hauteur, fraction `[0,1]` de la hauteur de page (défaut `0.0` ;
  /// clampée).
  @ZcrudField()
  final double height;

  /// Sérialise vers la map persistée (snake_case) — méthode d'instance.
  ///
  /// L'extension générée `ZAnnotationBoundsZcrud` est masquée du barrel :
  /// son `copyWith` généré, appelable explicitement, contournerait
  /// [sanitizeCoord] depuis l'API publique (le masquage par le `copyWith`
  /// d'instance ne vaut que pour l'appel implicite). Le `toMap()` du
  /// barrel disparaissant avec le masquage, il est promu en méthode
  /// d'instance : la surface publique de (dé)sérialisation est préservée,
  /// sans rouvrir la porte du `copyWith`.
  Map<String, dynamic> toMap() => ZAnnotationBoundsZcrud(this).toMap();

  /// Copie re-clampée — méthode d'instance, qui masque le `copyWith` de
  /// l'extension générée `ZAnnotationBoundsZcrud` (un membre d'instance
  /// gagne toujours sur un membre d'extension) — et l'extension elle-même
  /// est masquée du barrel, donc inatteignable depuis l'API publique.
  ///
  /// C'est volontaire : le `copyWith` généré accepterait `x: 5` sans
  /// broncher, rouvrant l'invariant que [fromMap] ferme. Tous les champs
  /// étant non-nullables, la sémantique « argument omis ⇒ valeur
  /// conservée » suffit (aucune sentinelle de remise à `null` nécessaire).
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
