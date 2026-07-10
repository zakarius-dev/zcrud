/// Widget de la **famille fichier** (`file`/`image`/`document`) — E3-3c.
///
/// Champ **value-in-slice** (AD-2) : lit `value` (`AppFile?` en mode single,
/// `List<AppFile>` en mode multiple) et écrit via `onChanged` (branché sur
/// `setValue` par le dispatcher) — **aucun `TextEditingController`**, rebuild
/// borné à ce champ (frontière `ZFieldListenableBuilder` du dispatcher).
///
/// ## Seams injectés (AD-1 : cœur OUT=0, aucune dépendance lourde)
///
/// - **Acquisition** via `ZcrudScope.filePicker` (`ZFilePicker`) : boutons
///   scan/caméra/galerie/picker. `null` ⇒ actions désactivées proprement.
/// - **Transport** via `ZcrudScope.cloudStorage` (`CloudStorageRepository`) :
///   sur acquisition, si injecté, déclenche `upload` et **reflète**
///   `AppFile.uploadState` (`pending → uploading → uploaded`/`failed`) dans la
///   tranche. `null` ⇒ le fichier reste `pending` (orchestration déférée à
///   l'app/`onSubmit`, parité DODLP draft→cloud). AUCUNE impl concrète ici.
///
/// Le cœur n'importe **jamais** `image_picker`/`file_picker`/`firebase_storage` :
/// les impls concrètes vivent dans l'app/binding (picker, E7) et
/// `zcrud_firestore` (storage, E5).
///
/// ## Prévisualisation (web-safe)
///
/// - Image **uploadée** (`uploaded` + `remoteUrl`) → `Image.network` (web-safe,
///   `errorBuilder` de repli). - Document / fichier **local** pré-upload → icône
///   (dérivée du mime) + nom (rendu binaire local **déféré** ; `dart:io` hors
///   whitelist de pureté).
///
/// ## a11y / RTL (AD-13)
///
/// `Semantics` explicites + cibles ≥ 48 dp (`IconButton`) sur chaque action /
/// suppression / retry ; état d'upload annoncé sémantiquement ; miniatures avec
/// label alternatif (nom de fichier) ; insets/alignements **directionnels**
/// exclusifs ; couleurs **dérivées du thème** (aucun littéral — FR-26).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/edition/app_file.dart';
import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';
import '../../zcrud_scope.dart';

/// Champ d'édition **fichier/image/document** (value-in-slice, seams injectés).
class ZAppFileField extends StatefulWidget {
  /// Construit le champ pour [field], valeur courante [value] (`AppFile?` ou
  /// `List<AppFile>`), notifiant [onChanged] (branché sur `setValue`).
  const ZAppFileField({
    required this.field,
    required this.value,
    required this.onChanged,
    this.liveValue,
    super.key,
  });

  /// Spécification `const` du champ rendu (`type` ∈ {file,image,document}).
  final ZFieldSpec field;

  /// Valeur COURANTE de la tranche `field.name` (`AppFile?` / `List<AppFile>`).
  final Object? value;

  /// Écrit une nouvelle valeur dans la tranche (branché sur `setValue`).
  final ValueChanged<Object?> onChanged;

  /// Lecture **synchrone** de la tranche vivante (`controller.valueOf`) —
  /// injectée par le dispatcher. Les orchestrations asynchrones (upload) lisent
  /// l'état LE PLUS RÉCENT via ce getter (le rebuild value-in-slice n'ayant pas
  /// encore propagé [value] pendant une rafale de `setValue`). `null` en usage
  /// autonome ⇒ repli sur [value].
  final Object? Function()? liveValue;

  @override
  State<ZAppFileField> createState() => _ZAppFileFieldState();
}

class _ZAppFileFieldState extends State<ZAppFileField> {
  /// Refus accessible (AC8/AD-13) : `true` quand la dernière acquisition a
  /// dépassé `maxFiles` et que les fichiers en trop ont été écartés. Affiché via
  /// un message `Semantics(liveRegion: true)` (annoncé au lecteur d'écran).
  /// État UI **local** (rebuild borné à ce champ — n'affecte pas la tranche ni
  /// SM-1/AD-2).
  bool _maxFilesReached = false;

  /// Config typée du champ (défaut sûr : toutes sources, aucune borne).
  FileFieldConfig get _config => widget.field.config is FileFieldConfig
      ? widget.field.config! as FileFieldConfig
      : const FileFieldConfig();

  /// Fichiers courants dérivés de la tranche vivante (lecture value-in-slice ;
  /// [ZAppFileField.liveValue] pour l'état synchrone le plus récent).
  List<AppFile> get _files {
    final v = widget.liveValue != null ? widget.liveValue!() : widget.value;
    if (v is AppFile) return <AppFile>[v];
    if (v is List) return v.whereType<AppFile>().toList(growable: false);
    return const <AppFile>[];
  }

  /// Clé d'identité stable d'un fichier à travers les transitions d'état
  /// (pending → uploading → uploaded/failed) : `localPath` (stable) puis `id`
  /// puis `name`.
  String _identity(AppFile f) => f.localPath ?? f.id ?? f.name;

  /// Écrit la tranche selon la multiplicité (single ⇒ `AppFile?`/remplace ;
  /// multiple ⇒ `List<AppFile>`).
  void _commit(List<AppFile> files) {
    if (widget.field.multiple) {
      widget.onChanged(List<AppFile>.unmodifiable(files));
    } else {
      widget.onChanged(files.isEmpty ? null : files.first);
    }
  }

  /// Remplace le fichier d'identité [oldFile] par [updated] (read-modify-write
  /// sur la tranche COURANTE — `widget.value` reflète le dernier état).
  void _replace(AppFile oldFile, AppFile updated) {
    final id = _identity(oldFile);
    final next = <AppFile>[
      for (final f in _files) _identity(f) == id ? updated : f,
    ];
    _commit(next);
  }

  Future<void> _pick(ZFileSource source) async {
    final picker = ZcrudScope.maybeOf(context)?.filePicker;
    if (picker == null) return;
    final picked = await picker.pick(source: source, config: _config);
    if (!mounted || picked.isEmpty) return;
    final List<AppFile> next;
    // Refus accessible AC8/AD-13 : au-delà de `maxFiles`, on écarte SEULEMENT
    // les fichiers en trop (les valides déjà présents et le début de la
    // sélection sont conservés) et on ANNONCE le refus (message liveRegion).
    var maxReached = false;
    if (widget.field.multiple) {
      final combined = <AppFile>[..._files, ...picked];
      final max = _config.maxFiles;
      if (max != null && combined.length > max) {
        maxReached = true;
        next = combined.sublist(0, max);
      } else {
        next = combined;
      }
    } else {
      next = <AppFile>[picked.first];
    }
    if (_maxFilesReached != maxReached) {
      setState(() => _maxFilesReached = maxReached);
    }
    _commit(next);
    // Déclenche l'upload des fichiers réellement retenus (si un storage est
    // injecté) — sinon ils restent `pending` (orchestration déférée).
    for (final f in picked) {
      if (next.contains(f)) unawaited(_startUpload(f));
    }
  }

  Future<void> _startUpload(AppFile file) async {
    final storage = ZcrudScope.maybeOf(context)?.cloudStorage;
    if (storage == null) return; // reste `pending` (parité draft→cloud)
    _replace(file, file.copyWith(uploadState: ZAppFileUploadState.uploading));
    final result = await storage.upload(file);
    if (!mounted) return;
    result.fold(
      (_) => _replace(
        file,
        file.copyWith(uploadState: ZAppFileUploadState.failed),
      ),
      (uploaded) => _replace(file, uploaded),
    );
  }

  void _remove(AppFile file) {
    final id = _identity(file);
    _commit(<AppFile>[
      for (final f in _files)
        if (_identity(f) != id) f,
    ]);
  }

  IconData _iconFor(AppFile file) =>
      file.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined;

  ({IconData icon, String labelKey}) _actionOf(ZFileSource source) {
    switch (source) {
      case ZFileSource.scan:
        return (icon: Icons.document_scanner_outlined, labelKey: 'fileActionScan');
      case ZFileSource.camera:
        return (icon: Icons.photo_camera_outlined, labelKey: 'fileActionCamera');
      case ZFileSource.gallery:
        return (icon: Icons.photo_library_outlined, labelKey: 'fileActionGallery');
      case ZFileSource.filePicker:
        return (icon: Icons.attach_file_outlined, labelKey: 'fileActionPick');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final colors = Theme.of(context).colorScheme;
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final picker = ZcrudScope.maybeOf(context)?.filePicker;
    final actionsEnabled = picker != null && !widget.field.readOnly;
    final files = _files;

    return Semantics(
      container: true,
      label: resolvedLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Text(resolvedLabel,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          // Rangée d'actions par source autorisée (directionnelle, ≥ 48 dp).
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
            child: Wrap(
              spacing: theme.gapS,
              children: <Widget>[
                for (final source in _config.allowedSources)
                  _ActionButton(
                    action: _actionOf(source),
                    enabled: actionsEnabled,
                    onPressed: () {
                      // ignore: discarded_futures
                      _pick(source);
                    },
                  ),
              ],
            ),
          ),
          // Refus accessible du dépassement de `maxFiles` (AC8/AD-13) : message
          // annoncé au lecteur d'écran (`liveRegion`) + visible, couleur du thème.
          if (_maxFilesReached)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  label(context, 'fileMaxReached'),
                  textAlign: TextAlign.start,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.error),
                ),
              ),
            ),
          if (files.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
              child: Wrap(
                spacing: theme.gapM,
                runSpacing: theme.gapS,
                children: <Widget>[
                  for (final file in files)
                    _FilePreviewTile(
                      file: file,
                      icon: _iconFor(file),
                      readOnly: widget.field.readOnly,
                      border: theme.fieldBorderColor ?? colors.outline,
                      radius: theme.radiusM,
                      onRemove: widget.field.readOnly ? null : () => _remove(file),
                      onRetry: widget.field.readOnly
                          ? null
                          : () {
                              // ignore: discarded_futures
                              _startUpload(file);
                            },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bouton d'action d'acquisition (cible ≥ 48 dp, `Semantics` via `tooltip`).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.enabled,
    required this.onPressed,
  });

  final ({IconData icon, String labelKey}) action;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = label(context, action.labelKey);
    return IconButton(
      icon: Icon(action.icon),
      // `IconButton` porte nativement le rôle sémantique `button` et le
      // `tooltip` alimente le label sémantique (l10n) — pas de wrapper
      // `Semantics` additionnel requis. Cible ≥ 48 dp par défaut (AD-13).
      tooltip: text,
      onPressed: enabled ? onPressed : null,
    );
  }
}

/// Miniature d'un fichier : préviz (image réseau / icône+nom) + suppression +
/// retry + reflet de l'état d'upload — tout accessible (AD-13).
class _FilePreviewTile extends StatelessWidget {
  const _FilePreviewTile({
    required this.file,
    required this.icon,
    required this.readOnly,
    required this.border,
    required this.radius,
    required this.onRemove,
    required this.onRetry,
  });

  final AppFile file;
  final IconData icon;
  final bool readOnly;
  final Color border;
  final Radius radius;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  static const double _thumb = 56;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final altLabel = file.name.isNotEmpty
        ? file.name
        : label(context, 'filePreviewAlt');
    final uploading = file.uploadState == ZAppFileUploadState.uploading;
    final failed = file.uploadState == ZAppFileUploadState.failed;

    // Aperçu : image uploadée → réseau (repli icône) ; sinon icône + nom.
    final Widget preview;
    if (file.isImage &&
        file.uploadState == ZAppFileUploadState.uploaded &&
        file.remoteUrl != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.all(radius),
        child: Image.network(
          file.remoteUrl!,
          width: _thumb,
          height: _thumb,
          fit: BoxFit.cover,
          semanticLabel: altLabel,
          errorBuilder: (context, error, stack) =>
              Icon(icon, semanticLabel: altLabel),
        ),
      );
    } else {
      preview = Icon(icon, size: 32, semanticLabel: altLabel);
    }

    final String stateLabel;
    if (uploading) {
      stateLabel = label(context, 'fileUploading');
    } else if (failed) {
      stateLabel = label(context, 'fileUploadFailed');
    } else {
      stateLabel = altLabel;
    }

    return Semantics(
      container: true,
      liveRegion: uploading || failed,
      label: altLabel,
      value: stateLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.all(radius),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(width: _thumb, height: _thumb, child: Center(child: preview)),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(altLabel, textAlign: TextAlign.start),
                    if (uploading)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                              child: Text(label(context, 'fileUploading'),
                                  style: Theme.of(context).textTheme.bodySmall),
                            ),
                          ],
                        ),
                      ),
                    if (failed)
                      Text(
                        label(context, 'fileUploadFailed'),
                        textAlign: TextAlign.start,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.error),
                      ),
                  ],
                ),
              ),
              if (failed && onRetry != null)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: label(context, 'fileRetry'),
                  onPressed: onRetry,
                ),
              if (!readOnly && onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: label(context, 'fileRemove'),
                  onPressed: onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
