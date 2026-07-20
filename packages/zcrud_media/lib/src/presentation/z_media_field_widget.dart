/// `ZMediaFieldWidget` — affordances **riches** média servies via
/// `ZWidgetRegistry` (fp-4-2, AC4/AC6) : zone de dépôt (`dotted_border`),
/// ouverture au tap (`open_file`), vignette vidéo (`video_thumbnail`, type
/// neutre `Uint8List`).
///
/// **Patron `zcrud_intl`** (`registerZAddressFieldWidgets`) : une fonction
/// top-level [registerZMediaFieldWidgets] enregistre le(s) builder(s) sous les
/// `kind` [mediaImageFieldKind]/[mediaFileFieldKind]/[mediaVideoFieldKind]
/// (alignés sur `EditionFieldType.mediaImage/mediaFile/mediaVideo.name`) ; les
/// collaborateurs (picker/thumbnailer/opener) sont capturés par **closure**
/// (AD-4). Chaque montage crée SON état.
///
/// 🔴 **Dispatch cœur (fp-4-2/MAJEUR-1)** : le cœur route les types
/// `mediaImage`/`mediaFile`/`mediaVideo` vers la famille `registryOrFallback`
/// (dispatcher `ZFieldWidget`) → il résout le builder par `field.type.name`
/// dans le `ZWidgetRegistry` injecté au `ZcrudScope`. Un champ
/// `ZFieldSpec(type: EditionFieldType.mediaImage)` atteint donc CE builder dès
/// que [registerZMediaFieldWidgets] a peuplé ce registre ; sinon repli
/// `ZUnsupportedFieldWidget` (AD-10). Les types NATIFS `image`/`file`/`document`
/// restent, EUX, routés vers `ZAppFileField` (famille `file`) — les types média
/// riches sont un chemin DISTINCT, jamais un override du natif.
///
/// **AD-2 / SM-1** : value-in-slice — le builder lit `ctx.value` et écrit via
/// `ctx.onChanged` **dans** la frontière de rebuild ; aucune souscription
/// élargie, aucun `TextEditingController`. **AD-13 / FR-26** : cibles ≥ 48 dp,
/// `Semantics` explicites sans double-annonce, insets **directionnels**, thème
/// injecté (`ZcrudTheme.of`, repli `Theme.of`) — aucune couleur codée en dur.
/// **AD-10** : ouverture échouée / picker absent / vignette indisponible →
/// résultat défini, jamais un throw traversant.
library;

import 'dart:typed_data';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/z_media_file_picker.dart';
import '../data/z_media_plugin_seams.dart';
import '../domain/z_media_seams.dart';

/// `kind` du champ **image riche** (drop-zone + ouverture), ALIGNÉ sur le nom
/// de l'`EditionFieldType` que le dispatcher cœur route vers le registre
/// (fp-4-2/MAJEUR-1) : `EditionFieldType.mediaImage.name == 'mediaImage'`. Un
/// champ `ZFieldSpec(type: EditionFieldType.mediaImage)` atteint donc ce builder
/// dès que [registerZMediaFieldWidgets] a peuplé le `ZWidgetRegistry` injecté au
/// `ZcrudScope` (sinon repli `ZUnsupportedFieldWidget`, AD-10).
final String mediaImageFieldKind = EditionFieldType.mediaImage.name;

/// `kind` du champ **fichier/document riche** (drop-zone + ouverture), aligné
/// sur `EditionFieldType.mediaFile.name == 'mediaFile'` (fp-4-2/MAJEUR-1).
final String mediaFileFieldKind = EditionFieldType.mediaFile.name;

/// `kind` du champ **vidéo** (drop-zone + vignette `Uint8List`), aligné sur
/// `EditionFieldType.mediaVideo.name == 'mediaVideo'` (fp-4-2/MAJEUR-1).
final String mediaVideoFieldKind = EditionFieldType.mediaVideo.name;

/// Mode de rendu d'un champ média riche (pilote l'icône, la source
/// d'acquisition et l'affichage de la vignette vidéo).
enum ZMediaFieldMode {
  /// Image : acquisition galerie, aperçu image.
  image,

  /// Fichier/document : acquisition sélecteur, ouverture au tap.
  file,

  /// Vidéo : acquisition galerie, **vignette** générée (`Uint8List`).
  video,
}

/// Enregistre les builders média riches sous les trois `kind` custom
/// [mediaImageFieldKind]/[mediaFileFieldKind]/[mediaVideoFieldKind] dans
/// [registry].
///
/// **Point d'enrôlement EXPLICITE (AC6/AR-4)** : à appeler au **bootstrap** du
/// binding/app — **jamais** un side-effect d'import. Le cœur reste agnostique
/// (aucune modif de `zcrud_core`). [picker] (à injecter aussi dans
/// `ZcrudScope.filePicker`) alimente les zones de dépôt ; `null` ⇒ drop-zone
/// désactivée proprement (AD-10). [thumbnailer]/[opener] par défaut = plugins
/// réels. [onInit]/[onBuild] sont des hooks de test (SM-1).
void registerZMediaFieldWidgets(
  ZWidgetRegistry registry, {
  ZMediaFilePicker? picker,
  ZVideoThumbnailSeam? thumbnailer,
  ZFileOpenSeam? opener,
  VoidCallback? onInit,
  VoidCallback? onBuild,
}) {
  final resolvedThumb = thumbnailer ?? ZPluginVideoThumbnailSeam();
  final resolvedOpener = opener ?? ZPluginFileOpenSeam();
  registry.register(
    mediaImageFieldKind,
    ZMediaFieldWidget.builder(
      mode: ZMediaFieldMode.image,
      picker: picker,
      thumbnailer: resolvedThumb,
      opener: resolvedOpener,
      onInit: onInit,
      onBuild: onBuild,
    ),
  );
  registry.register(
    mediaFileFieldKind,
    ZMediaFieldWidget.builder(
      mode: ZMediaFieldMode.file,
      picker: picker,
      thumbnailer: resolvedThumb,
      opener: resolvedOpener,
      onInit: onInit,
      onBuild: onBuild,
    ),
  );
  registry.register(
    mediaVideoFieldKind,
    ZMediaFieldWidget.builder(
      mode: ZMediaFieldMode.video,
      picker: picker,
      thumbnailer: resolvedThumb,
      opener: resolvedOpener,
      onInit: onInit,
      onBuild: onBuild,
    ),
  );
}

/// Champ d'édition média riche (value-in-slice, patron AD-2).
class ZMediaFieldWidget extends StatefulWidget {
  /// Construit le champ pour [ctx] en mode [mode].
  const ZMediaFieldWidget({
    required this.ctx,
    required this.mode,
    required this.thumbnailer,
    required this.opener,
    this.picker,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contexte du champ (`ctx.value` = `AppFile?`/`List<AppFile>` courant,
  /// `ctx.onChanged` = écriture de la tranche).
  final ZFieldWidgetContext ctx;

  /// Mode de rendu (image/file/video).
  final ZMediaFieldMode mode;

  /// Seam de vignette vidéo (mode video). Neutre (`Uint8List`).
  final ZVideoThumbnailSeam thumbnailer;

  /// Seam d'ouverture au tap. Résultat défini (AD-10).
  final ZFileOpenSeam opener;

  /// Façade d'acquisition (`null` ⇒ drop-zone désactivée proprement).
  final ZMediaFilePicker? picker;

  /// Hook de test : appelé UNE FOIS en `initState` (preuve SM-1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test : appelé à chaque (re)build (compteur ciblé SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable sous un `kind` média. Les
  /// collaborateurs sont capturés par closure (partageables) ; chaque montage
  /// crée SON état.
  static ZFieldWidgetBuilder builder({
    required ZMediaFieldMode mode,
    required ZVideoThumbnailSeam thumbnailer,
    required ZFileOpenSeam opener,
    ZMediaFilePicker? picker,
    VoidCallback? onInit,
    VoidCallback? onBuild,
  }) {
    return (BuildContext context, ZFieldWidgetContext ctx) => ZMediaFieldWidget(
          ctx: ctx,
          mode: mode,
          thumbnailer: thumbnailer,
          opener: opener,
          picker: picker,
          onInit: onInit,
          onBuild: onBuild,
        );
  }

  @override
  State<ZMediaFieldWidget> createState() => _ZMediaFieldWidgetState();
}

class _ZMediaFieldWidgetState extends State<ZMediaFieldWidget> {
  /// Cache des vignettes vidéo MÉMOÏSÉES par `localPath` (MED-2/SM-1/AD-2) : le
  /// `Future` de génération native est calculé **une seule fois par chemin** et
  /// réutilisé à chaque rebuild de la tranche — sinon `FutureBuilder(future:
  /// generate(...))` en `build()` régénérerait la vignette à CHAQUE frappe. Une
  /// entrée n'est jamais ré-générée tant que son chemin ne change pas.
  final Map<String, Future<Uint8List?>> _thumbCache =
      <String, Future<Uint8List?>>{};

  @override
  void initState() {
    super.initState();
    widget.onInit?.call();
  }

  /// `Future` de vignette MÉMOÏSÉ pour [localPath] : première demande ⇒ appel du
  /// seam (`generate`) mis en cache ; demandes suivantes ⇒ même `Future`
  /// (aucun nouvel appel natif — MED-2). Le thumbnailer est stable (closure),
  /// donc un changement de `widget.thumbnailer` reste hors du chemin de frappe.
  Future<Uint8List?> _thumbFor(String localPath) =>
      _thumbCache.putIfAbsent(localPath, () => widget.thumbnailer.generate(localPath));

  /// Config fichier du champ (défaut sûr : toutes sources, aucune borne).
  FileFieldConfig get _config => widget.ctx.field.config is FileFieldConfig
      ? widget.ctx.field.config! as FileFieldConfig
      : const FileFieldConfig();

  /// Fichiers courants dérivés de la tranche (value-in-slice, AD-2).
  List<AppFile> get _files {
    final v = widget.ctx.value;
    if (v is AppFile) return <AppFile>[v];
    if (v is List) return v.whereType<AppFile>().toList(growable: false);
    return const <AppFile>[];
  }

  /// Source d'acquisition selon le mode (image/vidéo → galerie ; fichier →
  /// sélecteur de documents).
  ///
  /// ⚠️ **LIMITE CONNUE (fp-4-2/LOW)** : en mode [ZMediaFieldMode.video], la
  /// drop-zone acquiert via `ZFileSource.gallery` (image_picker → `pickImages`)
  /// — il n'existe PAS encore de chemin `pickVideo` dans le contrat cœur
  /// `ZFileSource`. Le champ vidéo gère aujourd'hui pleinement la **vignette**
  /// d'un `AppFile` vidéo **préexistant** (valeur de tranche) ; l'ACQUISITION
  /// vidéo directe depuis la drop-zone est un SUIVI (ajout d'une source vidéo au
  /// seam/`ZFileSource` côté cœur). Consigné dans `code-review-fp-4-2.md`.
  ZFileSource get _source =>
      widget.mode == ZMediaFieldMode.file
          ? ZFileSource.filePicker
          : ZFileSource.gallery;

  /// Écrit la tranche selon la multiplicité (single ⇒ `AppFile?` ; multiple ⇒
  /// `List<AppFile>` borné par `maxFiles`) — voie d'émission UNIQUE (AD-2).
  void _commit(List<AppFile> files) {
    if (widget.ctx.field.multiple) {
      widget.ctx.onChanged(List<AppFile>.unmodifiable(files));
    } else {
      widget.ctx.onChanged(files.isEmpty ? null : files.first);
    }
  }

  /// Acquisition via la zone de dépôt / bouton d'ajout. Picker `null` ⇒ no-op
  /// (désactivé proprement, AD-10).
  Future<void> _acquire() async {
    final picker = widget.picker;
    if (picker == null) return;
    final picked = await picker.pick(source: _source, config: _config);
    if (!mounted || picked.isEmpty) return;
    if (widget.ctx.field.multiple) {
      final combined = <AppFile>[..._files, ...picked];
      final max = _config.maxFiles;
      _commit(
          max != null && combined.length > max ? combined.sublist(0, max) : combined);
    } else {
      _commit(<AppFile>[picked.first]);
    }
  }

  /// Retire [file] de la tranche (voie unique AD-2).
  void _remove(AppFile file) {
    final id = _identity(file);
    _commit(<AppFile>[
      for (final f in _files)
        if (_identity(f) != id) f,
    ]);
  }

  static String _identity(AppFile f) => f.localPath ?? f.id ?? f.name;

  /// Ouvre [file] au tap via le seam (résultat défini, AD-10).
  Future<void> _open(AppFile file) async {
    final path = file.localPath;
    if (path == null || path.isEmpty) return;
    await widget.opener.open(path);
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final field = widget.ctx.field;
    final resolvedLabel = field.label ?? field.name;
    final readOnly = field.readOnly;
    final files = _files;
    return Semantics(
      container: true,
      label: resolvedLabel,
      child: Padding(
        padding: theme.fieldPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(resolvedLabel, style: TextStyle(color: theme.labelColor)),
            SizedBox(height: theme.gapS),
            for (final f in files) ...<Widget>[
              _fileTile(f, theme, readOnly),
              SizedBox(height: theme.gapS),
            ],
            if (readOnly)
              const SizedBox.shrink()
            else if (files.isEmpty || field.multiple)
              _dropZone(theme),
          ],
        ),
      ),
    );
  }

  /// Zone de dépôt `dotted_border` : affordance d'acquisition ≥ 48 dp,
  /// `Semantics(button:)`, couleur **dérivée du thème** (FR-26).
  Widget _dropZone(ZcrudTheme theme) {
    final borderColor =
        theme.labelColor ?? Theme.of(context).colorScheme.outline;
    final dropLabel = label(
      context,
      'media.dropZone',
      fallback: 'Ajouter un fichier',
    );
    final enabled = widget.picker != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: dropLabel,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        // dotted_border 3 : les réglages de tracé passent par un `options`
        // typé (`sealed DottedBorderOptions`) au lieu de paramètres nommés à
        // plat. `borderType: BorderType.RRect` + `radius:` deviennent
        // `RoundedRectDottedBorderOptions`, qui fixe `BorderType.RRect` par
        // construction. Le `padding` par défaut reste `EdgeInsets.all(2)`
        // comme en v2 : aucun décalage visuel.
        child: DottedBorder(
          options: RoundedRectDottedBorderOptions(
            radius: const Radius.circular(8),
            color: borderColor,
            strokeWidth: 1.5,
            dashPattern: const <double>[6, 3],
          ),
          child: InkWell(
            key: const Key('z-media-dropzone'),
            onTap: enabled ? _acquire : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              alignment: AlignmentDirectional.center,
              padding: const EdgeInsetsDirectional.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(_modeIcon, color: borderColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      dropLabel,
                      textAlign: TextAlign.start,
                      style: TextStyle(color: theme.labelColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tuile d'un fichier acquis : vignette/icône + nom + ouverture + suppression.
  Widget _fileTile(AppFile file, ZcrudTheme theme, bool readOnly) {
    final openLabel = label(context, 'media.open', fallback: 'Ouvrir le fichier');
    final removeLabel =
        label(context, 'media.remove', fallback: 'Retirer le fichier');
    final displayName = file.name.isEmpty
        ? label(context, 'media.unnamed', fallback: 'Fichier')
        : file.name;
    return Row(
      children: <Widget>[
        _leading(file),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            displayName,
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Semantics(
          button: true,
          label: openLabel,
          child: IconButton(
            key: Key('z-media-open-${_identity(file)}'),
            icon: const Icon(Icons.open_in_new),
            tooltip: openLabel,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => _open(file),
          ),
        ),
        if (!readOnly)
          Semantics(
            button: true,
            label: removeLabel,
            child: IconButton(
              key: Key('z-media-remove-${_identity(file)}'),
              icon: const Icon(Icons.close),
              tooltip: removeLabel,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => _remove(file),
            ),
          ),
      ],
    );
  }

  /// Vignette (mode vidéo) ou icône dérivée du mode. La vignette vidéo est un
  /// type **neutre** (`Uint8List`) résolu par le seam (AD-40) ; échec ⇒ icône
  /// (AD-10).
  Widget _leading(AppFile file) {
    if (widget.mode != ZMediaFieldMode.video || file.localPath == null) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Icon(_modeIcon),
      );
    }
    return SizedBox(
      width: 48,
      height: 48,
      child: FutureBuilder<Uint8List?>(
        key: Key('z-media-thumb-${_identity(file)}'),
        future: _thumbFor(file.localPath!),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return Icon(_modeIcon);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            semanticLabel: file.name,
            errorBuilder: (_, __, ___) => Icon(_modeIcon),
          );
        },
      ),
    );
  }

  IconData get _modeIcon {
    switch (widget.mode) {
      case ZMediaFieldMode.image:
        return Icons.image_outlined;
      case ZMediaFieldMode.video:
        return Icons.videocam_outlined;
      case ZMediaFieldMode.file:
        return Icons.insert_drive_file_outlined;
    }
  }
}
