/// Barrel d'API publique de `zcrud_document` (ES-2.1, **FR-S4**).
///
/// Document d'étude et **état de lecture personnel**, séparés **par
/// construction** (AD-26) :
/// - `ZStudyDocument` : le **contenu PARTAGEABLE** (nom, chemin de stockage,
///   statut d'ingestion, taille) — destiné au sous-arbre partageable d'un dossier ;
/// - `ZDocumentReadingState` : l'**état PERSONNEL** (page courante, préférences de
///   viewer, pages maîtrisées) — **jamais colocalisé** dans le document, donc
///   **jamais emporté par un partage/une duplication** (patron `ZRepetitionInfo`) ;
/// - `ZDocumentViewerPrefs` : préférences de lecture (zoom **borné**, sens,
///   disposition) — enums **pur-Dart** (jamais Syncfusion : le mapping vers la lib
///   de rendu vit en **presentation**, côté app) ;
/// - `ZDocumentLearningInfo` / `ZDocPageQuality` : maîtrise **par page**
///   (`Map<int,int>` ⇒ VO **écrit à la main** — le générateur ne supporte aucun
///   type `Map`).
/// - `ZDocumentAnnotation` (ES-2.5, FR-S8) : **annotation PARTAGEABLE** (surlignage
///   / sticky note) — `ZEntity` + `ZExtensible`, top-level à identité propre
///   (AD-26). Son rectangle d'ancrage `ZAnnotationBounds` est un VO **borné
///   `[0,1]`** (`sanitizeCoord` aux deux frontières) ; `ZDocumentAnnotationKind`
///   en fixe la nature (repli défensif `highlight`).
///
/// **AD-19** : **aucune** de ces entités ne déclare `updated_at`/`is_deleted` —
/// l'autorité Last-Write-Wins et le soft-delete vivent **hors-entité**
/// (`ZSyncMeta`). Porter le schéma lex verbatim — qui les loge **inline**, et dont
/// `updatedAt` est **littéralement** la clé LWW de l'état de lecture — recréerait
/// la perte de valeur métier soldée en ES-1.3.
///
/// Dépend UNIQUEMENT de `zcrud_core` (surface **pur-Dart** `domain.dart`/
/// `edition.dart`), `zcrud_study_kernel` et `zcrud_annotations` (AD-1/AD-17) —
/// **zéro** dép lourde, **zéro** gestionnaire d'état, **zéro** `cloud_firestore`,
/// **zéro** SDK Flutter (NFR-S3/SM-S5). Tests sous `dart test`.
///
/// ## Extensions générées masquées (`hide`) — **LES TROIS**, sans exception (M2)
///
/// `ZStudyDocumentZcrud` et `ZDocumentReadingStateZcrud` portent un `copyWith`
/// **généré** qui **ignore** les canaux hors-codegen (`extra`, `extension`,
/// `learning`) et les remettrait à leurs **défauts** ⇒ **perte silencieuse**. La
/// copie et la (dé)sérialisation passent par l'**API d'instance**
/// (`fromMap`/`toMap`/`copyWith` à sentinelle).
///
/// 🔴 **`ZDocumentViewerPrefsZcrud` est DÉSORMAIS MASQUÉE ELLE AUSSI** (M2,
/// code-review ES-2.1). La justification d'AC1 — « `ZDocumentViewerPrefs` n'est
/// pas `ZExtensible` ⇒ son extension générée n'a **rien à perdre** » — est
/// devenue **FAUSSE** dès l'instant où l'entité a reçu un **invariant de valeur**
/// (zoom fini, `> 0`, clampé) : elle a désormais quelque chose à perdre. Le
/// `copyWith` d'instance ne masque le `copyWith` généré que sur l'appel
/// **implicite** ; l'appel **explicite d'extension** restait ouvert depuis l'API
/// publique et **CONTOURNAIT** la garde :
///
/// ```dart
/// ZDocumentViewerPrefsZcrud(const ZDocumentViewerPrefs()).copyWith(zoomLevel: -5)
/// // ⇒ zoomLevel == -5.0 : invariant « fini, > 0, clampé » CONTOURNÉ
/// ```
///
/// ⇒ **Politique UNIFORME du barrel : aucune extension générée n'est exportée.**
/// Le `toMap()` de `ZDocumentViewerPrefs` est **promu en méthode d'instance** —
/// la surface publique de (dé)sérialisation est **préservée**, la porte du
/// `copyWith` est **fermée**. (Le `.g.dart` reste dans la même bibliothèque que
/// l'entité : le registrar généré et le `toMap()` imbriqué de l'état de lecture
/// continuent d'y accéder normalement.)
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

// ── Présentation ACCESSIBLE (ES-8.2, FR-S28) — bascule Flutter (D2/D5) ────────
// UI d'annotation WCAG (AD-13) bâtie AU-DESSUS des modèles déjà livrés. Aucun
// type Flutter/`Color` n'apparaît en signature publique (AC13-e) : la surface
// exportée n'expose que `String colorKey`, `ZColorPalette`, `ZDocumentAnnotation`
// et des callbacks neutres.
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
