/// Barrel d'API publique de `zcrud_study_kernel`.
///
/// Noyau d'étude bas-niveau (ES-1.1), **source UNIQUE** — remontée depuis
/// `zcrud_flashcard` (AD-18) — de :
/// - `ZStudyFolder` : dossier d'organisation multi-type (rattachement inverse) ;
/// - `validatePlacement` : primitive PURE de hiérarchie 2 niveaux ;
/// - `ZReviewMode` : enum de mode de session ;
/// - `ZStudySessionConfig` : config de session persistable (filtres `types`
///   **neutralisés** en `List<String>` pour l'acyclicité — AC6) ;
/// - `ZSessionCandidate` : **port neutre** filtrable (implémenté par les entités
///   des satellites, ex. `ZFlashcard`) ;
/// - `ZStudySessionSelector` : sélection PURE opérant sur `ZSessionCandidate`.
///
/// Dépend UNIQUEMENT de `zcrud_core` (surface pur-Dart) + `zcrud_annotations`
/// (AD-1/AD-17) — aucune arête vers `zcrud_flashcard`, aucune dép lourde.
///
/// **Extensions générées masquées (`hide`)** : `ZStudyFolderZcrud` /
/// `ZStudySessionConfigZcrud` portent un `copyWith`/`toMap` internes ; la
/// (dé)sérialisation et la copie passent par l'API d'instance
/// (`fromMap`/`toMap`/`copyWith` à sentinelle), pas par l'extension générée (qui
/// remettrait `extra`/`extension` à leurs défauts → perte silencieuse). Politique
/// reproduite à l'identique de l'ancien barrel `zcrud_flashcard` (surface
/// publique inchangée).
///
/// **ES-1.2 — utilitaires domaine purs partagés** (FR-S2) : trois utilitaires
/// **sans dépendance métier**, réutilisables par tout satellite study — remplacent
/// les 3+ palettes/tris/normalisations dupliqués lex/IFFD :
/// - `ZColorPalette`/`ZKeyHash`/`zFnv1a32` : registre borné + fallback + remap
///   déterministe de `colorKey` (**zéro `Color`** — SM-S5 ; résolution
///   `colorKey → Color` injectée côté `zcrud_core`, `ZcrudScope.colorKeyResolver`) ;
/// - `ZUnorderedPlacement`/`applyOrder<T>` : tri stable à ordre personnel partiel ;
/// - `normalizeTagTitle`/`dedupeByNormalizedTitle<T>` : normalisation + dédoublonnage
///   de titre de tag.
///
/// **Règle de maintenance (D3, solde LOW-1 d'ES-1.1)** : `zcrud_flashcard`
/// réexporte ce barrel via une liste **`hide`** (jamais `show`) pour préserver
/// intégralement la surface historique E9 — **symboles générés inclus**
/// (`registerZStudyFolder`, `registerZStudySessionConfig`, field-specs) — tout
/// en excluant les utilitaires hors périmètre flashcard. **Tout nouveau symbole
/// public ajouté à CE barrel qui n'a rien à voir avec les flashcards DOIT être
/// ajouté à la liste `hide` de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart`**
/// (ex. futur `ZSyncMeta` d'ES-1.3, entités ES-2, …).
///
/// Règle **outillée** (finding L4 du code-review ES-1.2) :
/// `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` croise les
/// symboles publics RÉELS de ce barrel avec le `hide` de `zcrud_flashcard` et une
/// allowlist explicite — un symbole non classé **fait échouer les tests** (plus
/// de fuite silencieuse possible).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/domain/apply_order.dart';
export 'src/domain/normalize_tag_title.dart';
export 'src/domain/z_color_palette.dart';
export 'src/domain/z_review_mode.dart';
export 'src/domain/z_session_candidate.dart';
export 'src/domain/z_study_folder.dart' hide ZStudyFolderZcrud;
export 'src/domain/z_study_folder_hierarchy.dart';
export 'src/domain/z_study_session_config.dart' hide ZStudySessionConfigZcrud;
export 'src/domain/z_study_session_selector.dart';
