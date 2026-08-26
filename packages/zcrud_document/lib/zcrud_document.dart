/// Barrel d'API publique de `zcrud_document`.
///
/// Document d'étude et état de lecture personnel, séparés par construction :
/// - `ZStudyDocument` : le contenu partageable (nom, chemin de stockage,
///   statut d'ingestion, taille) — destiné au sous-arbre partageable d'un
///   dossier ;
/// - `ZDocumentReadingState` : l'état personnel (page courante, préférences
///   de viewer, pages maîtrisées) — jamais colocalisé dans le document, donc
///   jamais emporté par un partage/une duplication ;
/// - `ZDocumentViewerPrefs` : préférences de lecture (zoom borné, sens,
///   disposition) — enums pur-Dart (jamais un enum d'une bibliothèque de
///   rendu concrète : le mapping vers celle-ci vit en presentation, côté
///   application) ;
/// - `ZDocumentLearningInfo` / `ZDocPageQuality` : maîtrise par page
///   (`Map<int,int>` ⇒ value object écrit à la main — le générateur ne
///   supporte aucun type `Map`) ;
/// - `ZDocumentAnnotation` : annotation partageable (surlignage / note
///   ancrée) — `ZEntity` + `ZExtensible`, top-level à identité propre. Son
///   rectangle d'ancrage `ZAnnotationBounds` est un value object borné
///   `[0,1]` (`sanitizeCoord` aux deux frontières) ; `ZDocumentAnnotationKind`
///   en fixe la nature — surlignage, note ancrée, soulignage, barrage,
///   soulignage ondulé — avec repli défensif `highlight` pour toute valeur
///   inconnue. `ZAnnotationMark` en donne le rendu canonique (une apparence
///   observable par nature).
///
/// Aucune de ces entités ne déclare `updated_at`/`is_deleted` — l'autorité
/// Last-Write-Wins et le soft-delete vivent hors-entité (`ZSyncMeta`,
/// invariant AD-9). Porter un schéma legacy verbatim — qui les logerait
/// inline, et dont `updatedAt` serait littéralement la clé Last-Write-Wins
/// de l'état de lecture — recréerait une perte de valeur métier.
///
/// Dépend uniquement de `zcrud_core` (surface pur-Dart `domain.dart`/
/// `edition.dart`), `zcrud_study_kernel` et `zcrud_annotations` (invariant
/// AD-1) — zéro dépendance lourde, zéro gestionnaire d'état, zéro
/// `cloud_firestore`, zéro SDK Flutter dans le domaine. Tests de domaine
/// sous `dart test`.
///
/// ## Extensions générées masquées (`hide`) — les trois, sans exception
///
/// `ZStudyDocumentZcrud` et `ZDocumentReadingStateZcrud` portent un
/// `copyWith` généré qui ignore les canaux hors-codegen (`extra`,
/// `extension`, `learning`) et les remettrait à leurs défauts ⇒ perte
/// silencieuse. La copie et la (dé)sérialisation passent par l'API
/// d'instance (`fromMap`/`toMap`/`copyWith` à sentinelle).
///
/// `ZDocumentViewerPrefsZcrud` est masquée elle aussi. La justification «
/// cette entité n'est pas `ZExtensible` ⇒ son extension générée n'a rien à
/// perdre » cesse d'être vraie dès l'instant où l'entité reçoit un
/// invariant de valeur (zoom fini, `> 0`, clampé) : elle a désormais
/// quelque chose à perdre. Le `copyWith` d'instance ne masque le `copyWith`
/// généré que sur l'appel implicite ; l'appel explicite d'extension restait
/// ouvert depuis l'API publique et contournait la garde :
///
/// ```dart
/// ZDocumentViewerPrefsZcrud(const ZDocumentViewerPrefs()).copyWith(zoomLevel: -5)
/// // ⇒ zoomLevel == -5.0 : invariant « fini, > 0, clampé » contourné
/// ```
///
/// D'où une politique uniforme du barrel : aucune extension générée n'est
/// exportée. Le `toMap()` de `ZDocumentViewerPrefs` est promu en méthode
/// d'instance — la surface publique de (dé)sérialisation est préservée, la
/// porte du `copyWith` est fermée. (Le fichier compagnon généré reste dans
/// la même bibliothèque que l'entité : le registrar généré et le `toMap()`
/// imbriqué de l'état de lecture continuent d'y accéder normalement.)
///
/// API publique = ce barrel ; implémentation sous `lib/src/domain/`.
library;

export 'src/domain/z_annotation_bounds.dart' hide ZAnnotationBoundsZcrud;
export 'src/domain/z_doc_page_quality.dart';
export 'src/domain/z_document_annotation.dart' hide ZDocumentAnnotationZcrud;
export 'src/domain/z_document_annotation_kind.dart';
export 'src/domain/z_document_learning_info.dart';
export 'src/domain/z_document_reading_state.dart'
    hide ZDocumentReadingStateZcrud;
export 'src/domain/z_document_status.dart';
export 'src/domain/z_document_viewer_prefs.dart' hide ZDocumentViewerPrefsZcrud;
export 'src/domain/z_study_document.dart' hide ZStudyDocumentZcrud;

// ── Présentation accessible — bascule Flutter ─────────────────────────────
// UI d'annotation WCAG (invariant AD-13) bâtie au-dessus des modèles déjà
// livrés. Aucun type Flutter/`Color` n'apparaît en signature publique : la
// surface exportée n'expose que `String colorKey`, `ZColorPalette`,
// `ZDocumentAnnotation` et des callbacks neutres.
export 'src/presentation/z_annotation_mark.dart'
    show ZAnnotationMark, kAnnotationMarkKeyPrefix;
export 'src/presentation/z_annotation_panel.dart' show ZAnnotationPanel;
export 'src/presentation/z_annotation_tool_controller.dart'
    show
        ZAnnotationToolController,
        kAnnotationKindKeyPrefix,
        kAnnotationSwatchKeyPrefix,
        kAnnotationSwatchFillKeyPrefix,
        kAnnotationSelectedMarkerKey,
        kAnnotationPanelEntryKeyPrefix;
export 'src/presentation/z_annotation_toolbar.dart' show ZAnnotationToolbar;
export 'src/presentation/z_document_viewer_chrome.dart'
    show
        ZDocumentPageNavigation,
        ZDocumentViewerChrome,
        ZDocumentViewerLoadState;
