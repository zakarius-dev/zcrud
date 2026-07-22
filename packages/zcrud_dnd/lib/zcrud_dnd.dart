/// **zcrud_dnd** — implémentation OPT-IN du port `ZDropRegionRenderer`
/// (`zcrud_core`) adossée au paquet `super_drag_and_drop` de l'écosystème
/// pub.dev (AD-57).
///
/// ## Drag-and-drop NATIF — et rien d'autre
///
/// « Natif » = recevoir des données venues du **système** ou d'une **autre
/// application** : un fichier glissé depuis l'explorateur, une image déposée
/// depuis un navigateur. Ce paquet n'a **rien** à voir avec le
/// réordonnancement interne d'une collection : cela relève de
/// `ZReorderRenderer` / `zcrud_reorder`. Les deux ont été délibérément séparés
/// — les confondre imposerait une chaîne de compilation native à des hôtes qui
/// veulent seulement réordonner.
///
/// ## Coût de build, à connaître AVANT d'ajouter la dépendance
///
/// `super_drag_and_drop` embarque du code natif (Rust) et télécharge des
/// binaires précompilés à la construction. zcrud étant distribué en dépendance
/// git — sans étape de publication qui absorberait ce coût — la contrainte
/// s'impose au build de toute application consommatrice. C'est la raison d'être
/// du paquet séparé.
///
/// ## Ce que ce barrel expose — et ce qu'il n'expose PAS
///
/// **Aucun** type de `super_drag_and_drop` ni de `super_clipboard` n'apparaît
/// ici ni dans une signature publique (AD-57, condition 2) : l'adaptateur qui
/// les manipule est privé. L'hôte ne connaît que `ZDropRegionRenderer`,
/// `ZDropRegionRequest`, `ZDroppedItem` et `ZDropKind`, tous portés par
/// `zcrud_core`.
///
/// ## Installer ce paquet est un CHOIX, jamais une obligation
///
/// Le port a un **défaut zéro-dépendance** (`ZNoDropRegionRenderer`, dans
/// `zcrud_core`) : sans ce satellite, la zone rend son contenu inchangé et
/// n'accepte aucun dépôt. L'hôte garde ses autres voies d'import (sélecteur de
/// fichiers, presse-papier) — capacité **dégradée, jamais absente**.
///
/// ## Usage
///
/// ```dart
/// ZcrudScope(
///   dropRegionRenderer: const ZNativeDropRegionRenderer(),
///   child: MyApp(),
/// )
/// ```
library;

export 'src/domain/z_drop_kind_mapping.dart'
    show
        ZDropItemSource,
        kZDropKindPriority,
        zBuildDroppedItems,
        zCandidateDropKinds,
        zMimeTypeForFormats,
        zSelectDropKind;
export 'src/domain/z_drop_read_failure.dart' show ZDropReadFailure;
export 'src/presentation/z_native_drop_region_renderer.dart'
    show ZNativeDropRegionRenderer;
