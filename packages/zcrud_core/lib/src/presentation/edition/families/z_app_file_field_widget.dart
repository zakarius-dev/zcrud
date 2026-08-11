/// Widget de la **famille fichier** (`file`/`image`/`document`).
///
/// Champ **value-in-slice** (invariant AD-2) : lit `value` (`AppFile?` en
/// mode single, `List<AppFile>` en mode multiple) et écrit via `onChanged`
/// (branché sur `setValue` par le dispatcher) — **aucun
/// `TextEditingController`**, rebuild borné à ce champ (frontière
/// `ZFieldListenableBuilder` du dispatcher).
///
/// ## Seams injectés (invariant AD-1 : cœur OUT=0, aucune dépendance lourde)
///
/// - **Acquisition** via `ZcrudScope.filePicker` (`ZFilePicker`) : boutons
///   scan/caméra/galerie/picker. `null` ⇒ actions désactivées proprement.
/// - **Transport** via `ZcrudScope.cloudStorage` (`CloudStorageRepository`) :
///   sur acquisition, si injecté, déclenche `upload` et **reflète**
///   `AppFile.uploadState` (`pending → uploading → uploaded`/`failed`) dans la
///   tranche. `null` ⇒ le fichier reste `pending` (orchestration déférée à
///   l'app/`onSubmit`). AUCUNE impl concrète ici.
///
/// Le cœur n'importe **jamais** `image_picker`/`file_picker`/`firebase_storage` :
/// les impls concrètes vivent dans l'app/binding (picker) et
/// `zcrud_firestore` (storage).
///
/// ## Prévisualisation (web-safe)
///
/// - Image **uploadée** (`uploaded` + `remoteUrl`) → `Image.network` (web-safe,
///   `errorBuilder` de repli). - Document / fichier **local** pré-upload → icône
///   (dérivée du mime) + nom (rendu binaire local **déféré** ; `dart:io` hors
///   whitelist de pureté).
///
/// ## a11y / RTL (invariant AD-13)
///
/// `Semantics` explicites + cibles ≥ 48 dp (`IconButton`) sur chaque action /
/// suppression / retry ; état d'upload annoncé sémantiquement ; miniatures avec
/// label alternatif (nom de fichier) ; insets/alignements **directionnels**
/// exclusifs ; couleurs **dérivées du thème** (aucun littéral — invariant
/// FR-26).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/edition/app_file.dart';
import '../../../domain/edition/edition_field_type.dart';
import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../../domain/ports/z_app_file_resolver.dart';
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

/// État de résolution d'une **référence opaque** (`String`) de fichier —
/// visible dans le rendu (un silence sur une résolution en échec serait un
/// défaut, invariant AD-10).
enum _RefState {
  /// Résolution en cours (le port a été appelé, la réponse n'est pas arrivée).
  resolving,

  /// Le port a répondu SANS `AppFile` porteur de cet id ⇒ **introuvable**.
  missing,

  /// La résolution a **échoué** (`Error`, `Exception` — l'échec NORMAL d'une
  /// E/S — ou dépassement du délai de garde) ⇒ réessayable.
  failed,
}

class _ZAppFileFieldState extends State<ZAppFileField> {
  /// Références **résolues** (référence opaque → `AppFile`). État UI local :
  /// la résolution n'écrit JAMAIS dans la tranche (invariant AD-2 — écrire la
  /// tranche élargirait la voie de rebuild ET salirait le formulaire).
  final Map<String, AppFile> _resolved = <String, AppFile>{};

  /// État visible des références NON résolues (jamais un silence).
  final Map<String, _RefState> _refState = <String, _RefState>{};

  /// Refus accessible (invariant AD-13) : `true` quand la dernière
  /// acquisition a dépassé `maxFiles` et que les fichiers en trop ont été
  /// écartés. Affiché via un message `Semantics(liveRegion: true)` (annoncé
  /// au lecteur d'écran). État UI **local** (rebuild borné à ce champ —
  /// n'affecte pas la tranche ni l'invariant AD-2).
  bool _maxFilesReached = false;

  /// Config typée du champ (défaut sûr : toutes sources, aucune borne).
  FileFieldConfig get _config => widget.field.config is FileFieldConfig
      ? widget.field.config! as FileFieldConfig
      : const FileFieldConfig();

  /// Résolveur de références injecté (`null` ⇒ voie de références **inactive**,
  /// comportement historique strictement conservé).
  ZAppFileResolver? get _resolver =>
      ZcrudScope.maybeOf(context)?.appFileResolver;

  /// `true` quand la voie de résolution des références est active. Sans port
  /// injecté, le champ se comporte EXACTEMENT comme avant (les valeurs
  /// non-`AppFile` sont ignorées, aucun état supplémentaire, aucune référence
  /// conservée à la réécriture) — hôte passif immobile.
  bool get _refsEnabled => _resolver != null;

  /// Entrées **brutes** de la tranche vivante, dans l'ordre : `AppFile` (objets
  /// fichier) et `String` non vides (**références opaques**, seulement si le
  /// port est injecté). Toute autre valeur est ignorée (invariant AD-10).
  List<Object> get _entries {
    final v = widget.liveValue != null ? widget.liveValue!() : widget.value;
    final refs = _refsEnabled;
    if (v is AppFile) return <Object>[v];
    if (v is String) return (refs && v.isNotEmpty) ? <Object>[v] : const <Object>[];
    if (v is List) {
      return <Object>[
        for (final e in v)
          if (e is AppFile)
            e
          else if (refs && e is String && e.isNotEmpty)
            e,
      ];
    }
    return const <Object>[];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncResolution();
  }

  @override
  void didUpdateWidget(ZAppFileField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncResolution();
  }

  /// Demande la résolution des références **pas encore demandées**.
  ///
  /// Appelé hors `build` (`didChangeDependencies`/`didUpdateWidget`/retry) : la
  /// mutation d'état est directe (un `build` suit immédiatement) — c'est la
  /// COMPLÉTION asynchrone qui passe par `setState`, sous la frontière de
  /// rebuild du champ (invariant AD-2 : aucun autre champ, aucun rebuild du
  /// formulaire, aucune écriture de tranche).
  void _syncResolution() {
    final resolver = _resolver;
    if (resolver == null) return;
    final pending = <String>[
      for (final e in _entries)
        if (e is String && !_resolved.containsKey(e) && !_refState.containsKey(e))
          e,
    ];
    if (pending.isEmpty) return;
    for (final ref in pending) {
      _refState[ref] = _RefState.resolving;
    }
    // ignore: discarded_futures
    _runResolve(resolver, pending);
  }

  /// Exécute la résolution et projette TOUS les issues possibles en état
  /// VISIBLE (invariant AD-10) : succès, référence introuvable, échec
  /// (`Error` **comme** `Exception` — l'échec normal d'une E/S), `Future` qui
  /// ne se termine jamais (délai de garde [ZAppFileResolver.timeout]). Ne
  /// lève JAMAIS.
  Future<void> _runResolve(ZAppFileResolver resolver, List<String> refs) async {
    List<AppFile>? files;
    var failed = false;
    try {
      files = await resolver
          .resolve(List<String>.unmodifiable(refs))
          .timeout(resolver.timeout);
    } on Object {
      // `on Object` DÉLIBÉRÉ : un `on Error` laisserait remonter les
      // `Exception`, c'est-à-dire l'échec NORMAL d'une E/S.
      failed = true;
    }
    if (!mounted) return;
    final resolvedFiles = files;
    setState(() {
      if (failed || resolvedFiles == null) {
        for (final ref in refs) {
          _refState[ref] = _RefState.failed;
        }
        return;
      }
      final byId = <String, AppFile>{
        for (final f in resolvedFiles)
          if (f.id != null) f.id!: f,
      };
      for (final ref in refs) {
        final file = byId[ref];
        if (file != null) {
          _resolved[ref] = file;
          _refState.remove(ref);
        } else {
          _refState[ref] = _RefState.missing;
        }
      }
    });
  }

  /// Relance la résolution d'une référence en échec (action de **lecture** —
  /// disponible même en lecture seule).
  void _retryResolve(String ref) {
    setState(() => _refState.remove(ref));
    _syncResolution();
  }

  /// Clé d'identité stable d'un fichier à travers les transitions d'état
  /// (pending → uploading → uploaded/failed) : `localPath` (stable) puis `id`
  /// puis `name`.
  String _identity(AppFile f) => f.localPath ?? f.id ?? f.name;

  /// Écrit la tranche selon la multiplicité (single ⇒ élément/`null` ;
  /// multiple ⇒ `List<Object>`).
  ///
  /// Les **références opaques non résolues sont PRÉSERVÉES telles quelles**
  /// (`String`) : une acquisition ou une suppression ne doit jamais effacer
  /// silencieusement les identifiants que l'hôte a persistés. Sans port injecté,
  /// [_entries] ne contient que des `AppFile` ⇒ écriture strictement identique à
  /// l'historique.
  void _commitEntries(List<Object> entries) {
    if (!widget.field.multiple) {
      widget.onChanged(entries.isEmpty ? null : entries.first);
      return;
    }
    // TYPE DE TRANCHE PRÉSERVÉ : tant qu'aucune référence non résolue ne
    // subsiste, la tranche reste une `List<AppFile>` (contrat historique — un
    // hôte qui fait `value as List<AppFile>` n'est pas déplacé). Elle ne
    // s'élargit en `List<Object>` que s'il RESTE une référence à préserver.
    if (entries.every((e) => e is AppFile)) {
      widget.onChanged(
        List<AppFile>.unmodifiable(entries.whereType<AppFile>()),
      );
    } else {
      widget.onChanged(List<Object>.unmodifiable(entries));
    }
  }

  /// Remplace le fichier d'identité [oldFile] par [updated] (read-modify-write
  /// sur la tranche COURANTE — `widget.value` reflète le dernier état).
  void _replace(AppFile oldFile, AppFile updated) {
    final id = _identity(oldFile);
    _commitEntries(<Object>[
      for (final e in _entries)
        if (e is AppFile && _identity(e) == id) updated else e,
    ]);
  }

  Future<void> _pick(ZFileSource source) async {
    final picker = ZcrudScope.maybeOf(context)?.filePicker;
    if (picker == null) return;
    final picked = await picker.pick(source: source, config: _config);
    if (!mounted || picked.isEmpty) return;
    final List<Object> next;
    // Refus accessible (invariant AD-13) : au-delà de `maxFiles`, on écarte SEULEMENT
    // les fichiers en trop (les valides déjà présents et le début de la
    // sélection sont conservés) et on ANNONCE le refus (message liveRegion).
    // Les références opaques comptent comme des entrées occupées (elles
    // DÉSIGNENT un fichier déjà attaché).
    var maxReached = false;
    if (widget.field.multiple) {
      final combined = <Object>[..._entries, ...picked];
      final max = _config.maxFiles;
      if (max != null && combined.length > max) {
        maxReached = true;
        next = combined.sublist(0, max);
      } else {
        next = combined;
      }
    } else {
      next = <Object>[picked.first];
    }
    if (_maxFilesReached != maxReached) {
      setState(() => _maxFilesReached = maxReached);
    }
    _commitEntries(next);
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
    _commitEntries(<Object>[
      for (final e in _entries)
        if (!(e is AppFile && _identity(e) == id)) e,
    ]);
  }

  /// Retire une **référence opaque** de la tranche (action d'écriture).
  void _removeRef(String ref) {
    _commitEntries(<Object>[
      for (final e in _entries)
        if (e != ref) e,
    ]);
  }

  IconData _iconFor(AppFile file) {
    // Sur un champ `image` avec `imageFallback`, un fichier non-image
    // affiche malgré tout l'icône image.
    final imageFallback = _config.imageFallback &&
        widget.field.type == EditionFieldType.image;
    return (file.isImage || imageFallback)
        ? Icons.image_outlined
        : Icons.insert_drive_file_outlined;
  }

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
    // LECTURE SEULE (invariant AD-16) : les actions d'ACQUISITION sont des actions
    // d'ÉCRITURE — elles ne sont PLUS émises du tout (elles n'auraient jamais dû
    // être montées, seulement grisées). Les actions de LECTURE (aperçu, retry de
    // RÉSOLUTION) restent disponibles.
    // Sans picker injecté, la rangée reste ÉMISE mais désactivée (contrat
    // historique documenté : « `null` ⇒ actions désactivées proprement »).
    final showSourceActions = !widget.field.readOnly;
    final actionsEnabled = picker != null;
    final entries = _entries;

    return Semantics(
      container: true,
      // Pas de `label:` ici : le `Text(resolvedLabel)` visible ci-dessous fournit
      // déjà le nom accessible du conteneur — le dupliquer sur le Semantics
      // provoquerait une DOUBLE annonce. Le 2ᵉ
      // Semantics (état upload, `altLabel`+`value`+`liveRegion`) reste intact.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Text(resolvedLabel,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          // Rangée d'actions par source autorisée (directionnelle, ≥ 48 dp).
          // NON ÉMISE en lecture seule (actions d'écriture) — cf.
          // `showSourceActions`.
          if (showSourceActions)
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
          // Refus accessible du dépassement de `maxFiles` (invariant AD-13) : message
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
          if (entries.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
              child: Wrap(
                spacing: theme.gapM,
                runSpacing: theme.gapS,
                children: <Widget>[
                  for (final entry in entries)
                    if (entry is AppFile)
                      _FilePreviewTile(
                        file: entry,
                        icon: _iconFor(entry),
                        readOnly: widget.field.readOnly,
                        border: theme.fieldBorderColor ?? colors.outline,
                        radius: theme.radiusM,
                        onRemove:
                            widget.field.readOnly ? null : () => _remove(entry),
                        onRetry: widget.field.readOnly
                            ? null
                            : () {
                                // ignore: discarded_futures
                                _startUpload(entry);
                              },
                      )
                    // Référence opaque : rendue avec un état VISIBLE quel que
                    // soit son sort (résolue / en cours / introuvable / échec) —
                    // jamais un vide silencieux (invariant AD-10).
                    else if (entry is String)
                      if (_resolved[entry] case final resolvedFile?)
                        _FilePreviewTile(
                          file: resolvedFile,
                          icon: _iconFor(resolvedFile),
                          readOnly: widget.field.readOnly,
                          border: theme.fieldBorderColor ?? colors.outline,
                          radius: theme.radiusM,
                          onRemove: widget.field.readOnly
                              ? null
                              : () => _removeRef(entry),
                          // Le retry d'UPLOAD est une action d'écriture : sans
                          // objet local à renvoyer, il n'a pas de sens sur une
                          // référence distante déjà persistée.
                          onRetry: null,
                        )
                      else
                        _RefStateTile(
                          state: _refState[entry] ?? _RefState.resolving,
                          border: theme.fieldBorderColor ?? colors.outline,
                          radius: theme.radiusM,
                          // Action de LECTURE : disponible même en lecture seule.
                          onRetry: () => _retryResolve(entry),
                          onRemove: widget.field.readOnly
                              ? null
                              : () => _removeRef(entry),
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
      // `Semantics` additionnel requis. Cible ≥ 48 dp par défaut (invariant AD-13).
      tooltip: text,
      onPressed: enabled ? onPressed : null,
    );
  }
}

/// Tuile d'une **référence opaque non résolue** : rend VISIBLE ce qui, avant ce
/// correctif, disparaissait sans trace (champ migré affiché vide, sans erreur).
///
/// - `resolving` : indicateur de progression + libellé l10n ;
/// - `missing` : « fichier indisponible » (le port a répondu sans cet id) ;
/// - `failed` : « échec du chargement » + **réessai** (action de LECTURE, donc
///   disponible même en lecture seule).
///
/// Chaque état terminal est annoncé (`Semantics(liveRegion: true)`), aucun
/// littéral de couleur ni de texte (invariant FR-26), insets directionnels
/// (invariant AD-13),
/// cibles ≥ 48 dp (`IconButton`).
class _RefStateTile extends StatelessWidget {
  const _RefStateTile({
    required this.state,
    required this.border,
    required this.radius,
    required this.onRetry,
    required this.onRemove,
  });

  final _RefState state;
  final Color border;
  final Radius radius;
  final VoidCallback onRetry;
  final VoidCallback? onRemove;

  static const double _thumb = 56;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final resolving = state == _RefState.resolving;
    final failed = state == _RefState.failed;
    final String key;
    final IconData icon;
    switch (state) {
      case _RefState.resolving:
        key = 'fileResolving';
        icon = Icons.hourglass_empty;
      case _RefState.missing:
        key = 'fileRefUnresolved';
        icon = Icons.help_outline;
      case _RefState.failed:
        key = 'fileResolveFailed';
        icon = Icons.error_outline;
    }
    final text = label(context, key);

    return Semantics(
      container: true,
      liveRegion: !resolving,
      label: text,
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
              SizedBox(
                width: _thumb,
                height: _thumb,
                child: Center(
                  child: resolving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(icon, size: 32, semanticLabel: text),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
                child: Text(
                  text,
                  textAlign: TextAlign.start,
                  style: failed
                      ? Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.error)
                      : Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (failed)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: label(context, 'fileResolveRetry'),
                  onPressed: onRetry,
                ),
              if (onRemove != null)
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

/// Miniature d'un fichier : préviz (image réseau / icône+nom) + suppression +
/// retry + reflet de l'état d'upload — tout accessible (invariant AD-13).
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
