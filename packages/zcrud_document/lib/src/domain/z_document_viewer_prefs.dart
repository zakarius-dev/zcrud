/// Préférences de lecture d'un document — pur Dart.
///
/// Jamais un enum d'une bibliothèque de rendu ici : un modèle de domaine ne
/// persiste jamais un enum d'une lib UI concrète (ex. un enum Syncfusion) —
/// ce serait une violation directe de l'invariant « zéro dépendance lourde
/// dans le domaine d'étude » (invariant AD-1). Les enums exposés ici sont
/// pur-Dart ; le mapping vers les enums d'une bibliothèque de rendu vit
/// uniquement en presentation, côté application — hors de ce paquet.
///
/// Sous-modèle `@ZcrudModel` non-`ZExtensible` : aucun slot `extra` à
/// détruire ⇒ la délégation au `fromMap` généré est autorisée — mais le
/// corps doit rester non-nu, parce qu'il sanitise [zoomLevel] (un invariant
/// de valeur naît avec sa garde).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

part 'z_document_viewer_prefs.g.dart';

/// Sens de défilement du viewer.
///
/// **Ordre normatif** : le repli défensif d'un enum non-nullable sans
/// valeur par défaut est la première constante déclarée ⇒ [vertical] est le
/// défaut d'une valeur absente / `null` / non-`String` / inconnue.
enum ZDocumentScrollDirection {
  /// Défilement vertical — défaut défensif (première constante déclarée).
  vertical,

  /// Feuilletage latéral.
  horizontal;
}

/// Disposition des pages du viewer.
///
/// **Ordre normatif** : [continuous] est le défaut défensif.
enum ZDocumentPageLayout {
  /// Pages enchaînées en continu — défaut défensif (première constante
  /// déclarée).
  continuous,

  /// Une page à la fois.
  single;
}

/// Zoom par défaut (aucune transformation) — repli de toute valeur
/// persistée non finie, nulle ou négative.
const double kDefaultZoomLevel = 1.0;

/// Borne inférieure du zoom persistable (dézoom ×4).
///
/// Un `zoom_level: -5` ou `1e9` persisté (corruption, bug d'application,
/// écriture concurrente) casserait le viewer au chargement : un invariant
/// de valeur naît donc avec sa garde.
///
/// Justification de la borne : le domaine ne garantit qu'une valeur finie
/// et strictement positive, dans un intervalle où un rendu reste possible —
/// il n'impose pas l'ergonomie du viewer. `0.25` est le plus fort dézoom
/// au-delà duquel une page A4 devient illisible sur tout écran (environ 4
/// pages par hauteur d'écran) ; c'est aussi l'ordre de grandeur du plancher
/// des viewers PDF courants. Les bornes d'IHM réelles (souvent plus
/// strictes) restent au viewer, en presentation — hors périmètre de ce
/// paquet.
const double kMinZoomLevel = 0.25;

/// Borne supérieure du zoom persistable (agrandissement ×10).
///
/// Voir [kMinZoomLevel] pour la justification d'ensemble. `10.0` couvre
/// largement la lecture d'un scan de mauvaise qualité (le facteur au-delà
/// duquel un rendu rasterisé n'apporte plus d'information) tout en écartant
/// les valeurs manifestement corrompues (`1e9`, qui ferait exploser la
/// mémoire de rendu).
const double kMaxZoomLevel = 10.0;

/// Préférences de lecture persistées d'un document (zoom, sens,
/// disposition).
///
/// Value object non-`ZExtensible` : aucun slot `extra` / `extension`. Il
/// est décodé défensivement comme sous-modèle de [ZDocumentReadingState]
/// (chemin sous-modèle : une valeur corrompue — non-map, scalaire… —
/// retombe sur les défauts, jamais de `throw` du parent, invariant AD-10).
@ZcrudModel(kind: 'document_viewer_prefs')
class ZDocumentViewerPrefs {
  /// Constructeur bas niveau (`const`, source du `copyWith` généré).
  ///
  /// Ne sanitise pas [zoomLevel] (un constructeur `const` ne le peut pas).
  /// La garde d'invariant vit aux deux frontières réelles : [fromMap]
  /// (désérialisation — la seule voie par laquelle une valeur corrompue
  /// peut entrer) et [copyWith] (méthode d'instance, qui masque le
  /// `copyWith` de l'extension générée — mutation applicative).
  const ZDocumentViewerPrefs({
    this.zoomLevel = kDefaultZoomLevel,
    this.scrollDirection = ZDocumentScrollDirection.vertical,
    this.pageLayout = ZDocumentPageLayout.continuous,
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Délègue au décodeur généré (défauts sûrs : `zoom_level` absent/non
  /// numérique → [kDefaultZoomLevel] ; `scroll_direction`/`page_layout`
  /// inconnus → première constante de leur enum), puis sanitise le zoom —
  /// le codegen, lui, ne borne rien.
  ///
  /// Corps volontairement non nu : c'est le seul endroit où une valeur
  /// persistée corrompue (`NaN`, `-5`, `0`, `1e9`) peut entrer dans le
  /// domaine.
  factory ZDocumentViewerPrefs.fromMap(Map<String, dynamic> map) {
    final base = _$ZDocumentViewerPrefsFromMap(map);
    return ZDocumentViewerPrefs(
      zoomLevel: sanitizeZoomLevel(base.zoomLevel),
      scrollDirection: base.scrollDirection,
      pageLayout: base.pageLayout,
    );
  }

  /// Ramène [raw] dans le domaine de définition du zoom — ne lève jamais.
  ///
  /// - non finie (`NaN`, `±Infinity`) ⇒ [kDefaultZoomLevel] ;
  /// - `<= 0` (un zoom nul ou négatif n'a aucun sens) ⇒ [kDefaultZoomLevel] ;
  /// - sinon clampée dans `[kMinZoomLevel, kMaxZoomLevel]`.
  ///
  /// (Une valeur non numérique — `"x"`, `null`, une map — est déjà retombée
  /// sur [kDefaultZoomLevel] au décodage généré.)
  static double sanitizeZoomLevel(double raw) {
    if (!raw.isFinite || raw <= 0) return kDefaultZoomLevel;
    return raw.clamp(kMinZoomLevel, kMaxZoomLevel);
  }

  /// Niveau de zoom (défaut [kDefaultZoomLevel] ; fini, > 0, clampé dans
  /// `[kMinZoomLevel, kMaxZoomLevel]` à toute frontière — voir
  /// [sanitizeZoomLevel]).
  @ZcrudField(defaultValue: kDefaultZoomLevel)
  final double zoomLevel;

  /// Sens de défilement (persisté `scroll_direction` ; défaut `vertical`).
  @ZcrudField()
  final ZDocumentScrollDirection scrollDirection;

  /// Disposition des pages (persisté `page_layout` ; défaut `continuous`).
  @ZcrudField()
  final ZDocumentPageLayout pageLayout;

  /// Sérialise vers la map persistée (snake_case) — méthode d'instance.
  ///
  /// L'extension générée `ZDocumentViewerPrefsZcrud` est masquée du barrel
  /// public : son `copyWith` généré, appelable explicitement, contournerait
  /// [sanitizeZoomLevel] depuis l'API publique — le masquage par le
  /// `copyWith` d'instance ne vaut que pour l'appel implicite. Un value
  /// object non-`ZExtensible` n'a « rien à perdre » seulement tant qu'il ne
  /// porte aucun invariant de valeur : dès qu'il en porte un, son extension
  /// générée a de nouveau quelque chose à perdre.
  ///
  /// Le `toMap()` du barrel disparaissant avec le masquage, il est promu
  /// en méthode d'instance : la surface publique de (dé)sérialisation est
  /// préservée (et alignée sur les autres value objects du paquet, qui ont
  /// tous un `toMap()` d'instance), sans rouvrir la porte du `copyWith`.
  Map<String, dynamic> toMap() => ZDocumentViewerPrefsZcrud(this).toMap();

  /// Copie sanitisée — méthode d'instance, qui masque le `copyWith` de
  /// l'extension générée `ZDocumentViewerPrefsZcrud` (un membre d'instance
  /// gagne toujours sur un membre d'extension) — et l'extension elle-même
  /// est masquée du barrel, donc inatteignable depuis l'API publique.
  ///
  /// C'est volontaire : le `copyWith` généré accepterait `zoomLevel: -5`
  /// sans broncher, rouvrant l'invariant que [fromMap] ferme. Tous les
  /// champs étant non-nullables, la sémantique « argument omis ⇒ valeur
  /// conservée » suffit (aucune sentinelle de remise à `null` nécessaire).
  ZDocumentViewerPrefs copyWith({
    double? zoomLevel,
    ZDocumentScrollDirection? scrollDirection,
    ZDocumentPageLayout? pageLayout,
  }) =>
      ZDocumentViewerPrefs(
        zoomLevel: sanitizeZoomLevel(zoomLevel ?? this.zoomLevel),
        scrollDirection: scrollDirection ?? this.scrollDirection,
        pageLayout: pageLayout ?? this.pageLayout,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDocumentViewerPrefs &&
          zoomLevel == other.zoomLevel &&
          scrollDirection == other.scrollDirection &&
          pageLayout == other.pageLayout;

  @override
  int get hashCode => Object.hash(zoomLevel, scrollDirection, pageLayout);

  @override
  String toString() => 'ZDocumentViewerPrefs(zoomLevel: $zoomLevel, '
      'scrollDirection: ${scrollDirection.name}, pageLayout: ${pageLayout.name})';
}
