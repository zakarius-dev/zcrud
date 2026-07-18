/// Barrel d'API publique de `zcrud_media` — satellite MÉDIA (fp-4-2, AD-51).
///
/// Câble le contrat cœur EXISTANT `ZFilePicker`/`ZFileSource` derrière une **API
/// neutre** (`AppFile`/chemins/`Uint8List` — aucun type plateforme en signature,
/// AD-40) et fournit des affordances riches via `ZWidgetRegistry`.
///
/// ## Séquence de câblage attendue (côté binding/app — AC6/AR-4, ET-3)
///
/// L'enrôlement est **EXPLICITE au bootstrap**, jamais un side-effect d'import :
///
/// ```dart
/// final picker = ZMediaFilePicker();          // (optionnel : seams/crop injectés)
/// final registry = ZWidgetRegistry();
/// registerZMediaFieldWidgets(registry, picker: picker);
/// // puis, dans l'arbre :
/// ZcrudScope(filePicker: picker, widgetRegistry: registry, child: ...)
/// ```
///
/// - [ZMediaFilePicker] : à injecter dans `ZcrudScope.filePicker` — sert la
///   parité d'acquisition (galerie/caméra/sélecteur/recadrage) des types
///   **natifs** `image`/`file`/`document` que le cœur route déjà vers
///   `ZAppFileField`.
/// - [registerZMediaFieldWidgets] : enrôle les widgets riches (drop-zone /
///   ouverture / vignette vidéo) sous les `kind` **custom**
///   [mediaImageFieldKind]/[mediaFileFieldKind]/[mediaVideoFieldKind] (ET-2 : le
///   cœur route les types natifs avant le registre ; ces kinds custom sont
///   l'unique voie sans écriture cœur).
///
/// 🔴 **Isolation (AD-1/AD-40)** : ce barrel n'exporte **aucun** symbole de
/// plugin (`image_picker`/`file_picker`/`image_cropper`/`video_thumbnail`/
/// `open_file`/`dotted_border`/`camera`) — uniquement des types neutres. Les
/// deps média sont confinées à `lib/src/` (garde
/// `test/z_media_confinement_test.dart`).
library;

export 'src/data/z_media_file_picker.dart' show ZMediaFilePicker;
export 'src/domain/z_media_crop_options.dart' show ZMediaCropOptions;
export 'src/domain/z_media_seams.dart'
    show
        ZDocumentScanSeam,
        ZFileOpenSeam,
        ZFilePickSeam,
        ZImageCropSeam,
        ZImagePickSeam,
        ZVideoThumbnailSeam;
export 'src/presentation/z_media_field_widget.dart'
    show
        ZMediaFieldMode,
        ZMediaFieldWidget,
        mediaFileFieldKind,
        mediaImageFieldKind,
        mediaVideoFieldKind,
        registerZMediaFieldWidgets;
