/// Préférences de lecture d'un document (ES-2.1, FR-S4) — **pur Dart**.
///
/// origine: lex_core (module « Étude ») — `entities/education/document_reading_state.dart`
/// (`DocumentViewerPrefs`) + `enums/education/document_viewer_prefs.dart`.
///
/// 🔴 **JAMAIS d'enum de lib de rendu ici** (D6, NFR-S3/SM-S5). IFFD persiste
/// `PdfPageLayoutMode`/`PdfScrollDirection` — des enums **Syncfusion** — **dans
/// son modèle de domaine** (`folder_document_reading.dart`). C'est une violation
/// directe de l'invariant « zéro dép lourde dans le domaine study ». On porte les
/// enums **pur-Dart** de lex ; le mapping vers les enums Syncfusion vit
/// **uniquement en presentation**, côté app — **hors de ce package**.
///
/// **Sous-modèle `@ZcrudModel` NON-`ZExtensible`** (patron `ZChoice`,
/// `packages/zcrud_flashcard/lib/src/domain/z_choice.dart`) : aucun slot `extra`
/// à détruire ⇒ la délégation au `fromMap` généré est **autorisée** — mais le
/// corps **doit** rester non-nu, parce qu'il **sanitise** [zoomLevel] (R-H/R1 :
/// un invariant de valeur naît avec sa garde).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

part 'z_document_viewer_prefs.g.dart';

/// Sens de défilement du viewer.
///
/// 🔴 **ORDRE NORMATIF** (D5) : le repli défensif d'un enum non-nullable sans
/// `defaultValue` est `T.values.first` ⇒ **[vertical] est le défaut** d'une
/// valeur absente / `null` / non-`String` / inconnue.
enum ZDocumentScrollDirection {
  /// Défilement vertical (**défaut défensif** — 1ʳᵉ constante).
  vertical,

  /// Feuilletage latéral.
  horizontal;
}

/// Disposition des pages du viewer.
///
/// 🔴 **ORDRE NORMATIF** (D5) : **[continuous] est le défaut** défensif.
enum ZDocumentPageLayout {
  /// Pages enchaînées en continu (**défaut défensif** — 1ʳᵉ constante).
  continuous,

  /// Une page à la fois.
  single;
}

/// Zoom **par défaut** (aucune transformation) — repli de toute valeur persistée
/// non finie, nulle ou négative.
const double kDefaultZoomLevel = 1.0;

/// Borne **INFÉRIEURE** du zoom persistable (**dézoom ×4**).
///
/// 🔵 **Décision de story assumée, ABSENTE de lex** (AC4) : lex **ne borne pas**
/// `zoomLevel` — un `zoom_level: -5` ou `1e9` persisté (corruption, bug d'app,
/// écriture concurrente) casse le viewer au chargement. **R-H/R1** exige qu'un
/// invariant de valeur naisse **avec sa garde**.
///
/// **Justification de la borne** : le domaine ne garantit qu'une valeur **finie
/// et strictement positive**, dans un intervalle où un rendu reste *possible* —
/// il n'impose **pas** l'ergonomie du viewer. `0.25` est le plus fort dézoom
/// au-delà duquel une page A4 devient illisible sur tout écran (~4 pages par
/// hauteur d'écran) ; c'est aussi l'ordre de grandeur du plancher des viewers PDF
/// courants. Les bornes d'**IHM réelles** (souvent plus strictes) restent au
/// viewer, en **presentation** — hors périmètre de ce package.
const double kMinZoomLevel = 0.25;

/// Borne **SUPÉRIEURE** du zoom persistable (**agrandissement ×10**).
///
/// Cf. [kMinZoomLevel] pour la justification d'ensemble. `10.0` couvre largement
/// la lecture d'un scan de mauvaise qualité (le facteur au-delà duquel un rendu
/// rasterisé n'apporte plus d'information) tout en écartant les valeurs
/// manifestement corrompues (`1e9`, qui ferait exploser la mémoire de rendu).
const double kMaxZoomLevel = 10.0;

/// Préférences de lecture persistées d'un document (zoom, sens, disposition).
///
/// **Value object NON-`ZExtensible`** (patron `ZChoice`) : aucun slot `extra` /
/// `extension`. Il est décodé **défensivement** comme sous-modèle de
/// [ZDocumentReadingState] (chemin `subModel` : une `prefs` corrompue — non-map,
/// scalaire… — retombe sur les défauts, **jamais de throw du parent**, AD-10).
@ZcrudModel(kind: 'document_viewer_prefs')
class ZDocumentViewerPrefs {
  /// Primitif de reconstruction `const` (source du `copyWith` généré).
  ///
  /// ⚠️ **Ne sanitise pas** [zoomLevel] (un constructeur `const` ne le peut pas).
  /// La garde d'invariant vit aux **deux frontières réelles** : [fromMap]
  /// (désérialisation — la seule voie par laquelle une valeur corrompue peut
  /// entrer) et [copyWith] (**méthode d'INSTANCE**, qui *masque* le `copyWith`
  /// de l'extension générée — mutation applicative).
  const ZDocumentViewerPrefs({
    this.zoomLevel = kDefaultZoomLevel,
    this.scrollDirection = ZDocumentScrollDirection.vertical,
    this.pageLayout = ZDocumentPageLayout.continuous,
  });

  /// Reconstruit **défensivement** depuis une map persistée (AD-10, AC4/AC11).
  ///
  /// Délègue au `_$ZDocumentViewerPrefsFromMap` **généré** (défauts sûrs :
  /// `zoom_level` absent/non numérique → [kDefaultZoomLevel] ;
  /// `scroll_direction`/`page_layout` inconnus → **1ʳᵉ constante** de leur enum,
  /// D5), **puis SANITISE le zoom** — le codegen, lui, ne borne rien.
  ///
  /// ⚠️ Corps volontairement **NON NU** : c'est le seul endroit où une valeur
  /// persistée corrompue (`NaN`, `-5`, `0`, `1e9`) peut entrer dans le domaine.
  factory ZDocumentViewerPrefs.fromMap(Map<String, dynamic> map) {
    final base = _$ZDocumentViewerPrefsFromMap(map);
    return ZDocumentViewerPrefs(
      zoomLevel: sanitizeZoomLevel(base.zoomLevel),
      scrollDirection: base.scrollDirection,
      pageLayout: base.pageLayout,
    );
  }

  /// Ramène [raw] dans le domaine de définition du zoom — **ne throw jamais**.
  ///
  /// - **non finie** (`NaN`, `±Infinity`) ⇒ [kDefaultZoomLevel] ;
  /// - **`<= 0`** (un zoom nul ou négatif n'a aucun sens) ⇒ [kDefaultZoomLevel] ;
  /// - sinon **clampée** dans `[kMinZoomLevel, kMaxZoomLevel]`.
  ///
  /// (Une valeur **non numérique** — `"x"`, `null`, une map — est déjà retombée
  /// sur [kDefaultZoomLevel] au décodage généré, `_$asDouble` rendant `null`.)
  static double sanitizeZoomLevel(double raw) {
    if (!raw.isFinite || raw <= 0) return kDefaultZoomLevel;
    return raw.clamp(kMinZoomLevel, kMaxZoomLevel);
  }

  /// Niveau de zoom (défaut [kDefaultZoomLevel] ; **fini, > 0, clampé** dans
  /// `[kMinZoomLevel, kMaxZoomLevel]` à toute frontière — cf. [sanitizeZoomLevel]).
  @ZcrudField(defaultValue: kDefaultZoomLevel)
  final double zoomLevel;

  /// Sens de défilement (persisté `scroll_direction` ; défaut `vertical` — D5).
  @ZcrudField()
  final ZDocumentScrollDirection scrollDirection;

  /// Disposition des pages (persisté `page_layout` ; défaut `continuous` — D5).
  @ZcrudField()
  final ZDocumentPageLayout pageLayout;

  /// Sérialise vers la map persistée (snake_case) — **méthode d'INSTANCE**.
  ///
  /// 🔴 **M2 (code-review ES-2.1)** : l'extension générée `ZDocumentViewerPrefsZcrud`
  /// est désormais **`hide` du barrel public** — son `copyWith` généré, appelable
  /// **explicitement** (`ZDocumentViewerPrefsZcrud(p).copyWith(zoomLevel: -5)`),
  /// **CONTOURNAIT** [sanitizeZoomLevel] depuis l'API PUBLIQUE : le masquage par
  /// le `copyWith` d'instance ne vaut que pour l'appel **implicite**. La
  /// justification d'AC1 (« cette entité n'est pas `ZExtensible` ⇒ son extension
  /// générée n'a **rien à perdre** ») est devenue **fausse** dès l'instant où
  /// l'entité a reçu un **invariant de valeur** : elle a désormais quelque chose
  /// à perdre.
  ///
  /// Le `toMap()` du barrel disparaissant avec le `hide`, il est **promu en
  /// méthode d'instance** : la surface publique de (dé)sérialisation est
  /// **préservée** (et alignée sur ses deux sœurs, qui ont toutes deux un
  /// `toMap()` d'instance), **sans** rouvrir la porte du `copyWith`.
  Map<String, dynamic> toMap() => ZDocumentViewerPrefsZcrud(this).toMap();

  /// Copie **sanitisée** — **méthode d'INSTANCE**, qui *masque* le `copyWith` de
  /// l'extension générée `ZDocumentViewerPrefsZcrud` (un membre d'instance gagne
  /// toujours sur un membre d'extension) — et l'extension elle-même est **`hide`
  /// du barrel** (M2), donc **inatteignable** depuis l'API publique.
  ///
  /// C'est **volontaire** : le `copyWith` généré accepterait `zoomLevel: -5`
  /// **sans broncher**, rouvrant l'invariant que [fromMap] ferme. Tous les champs
  /// étant non-nullables, la sémantique « argument omis ⇒ valeur conservée »
  /// suffit (aucune sentinelle de reset-`null` nécessaire).
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
