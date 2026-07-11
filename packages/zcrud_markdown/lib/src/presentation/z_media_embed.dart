/// Embeds **image / vidéo** (DP-22, M20) de `zcrud_markdown` : embeds Quill
/// STANDARD de type `image` / `video` (op Delta `{"insert":{"image":<source>}}` /
/// `{"insert":{"video":<source>}}`), leurs `EmbedBuilder`s de rendu DÉFENSIF, et
/// le **seam de résolution de source** ([ZMediaEmbedScope]/[ZMediaResolver]) qui
/// permet à l'app hôte de fournir le rendu réel (réseau/asset/cache) SANS que le
/// package ne tire AUCUNE dépendance réseau ni ne code d'URL/endpoint en dur.
///
/// PATRON : ces embeds MIROITENT `z_latex_embed.dart`/`z_table_embed.dart` — même
/// contrat `Embeddable`, même `EmbedBuilder` défensif, même placeholder thémé,
/// même label a11y. Le TYPE (`image`/`video`) est celui STANDARD de flutter_quill
/// (`BlockEmbed.imageType`/`videoType`) : la valeur portée par la tranche est donc
/// interopérable avec un Delta produit par un autre éditeur Quill (parité DODLP,
/// dont les op embed image/vidéo empruntent ces mêmes clés).
///
/// SEAM NEUTRE (AD-1, « pas d'upload réseau dans le package ») : le package ne
/// SAIT PAS charger une source (une URL http, un chemin d'asset, un blob…). Il
/// délègue le rendu à un [ZMediaResolver] fourni par l'hôte via [ZMediaEmbedScope].
/// EN L'ABSENCE de resolver — OU si le resolver throw (AD-10) — un **placeholder
/// thémé** (icône + libellé + source tronquée) est rendu : l'éditeur reste
/// fonctionnel et AUCUN accès réseau n'est tenté par le package.
///
/// DÉFENSIF (AD-10) : le rendu ne throw JAMAIS — source absente / non-`String` /
/// vide → placeholder ; resolver qui throw → placeholder (capturé). A11Y (AD-13) :
/// [Semantics] explicite, insets DIRECTIONNELS, couleurs du thème injecté
/// (`ZcrudTheme`/`Theme`), zéro couleur codée en dur, cibles ≥ 48 dp au dialogue.
library;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Clé/type Delta de l'embed image — op `{"insert": {"image": "<source>"}}`.
/// IDENTIQUE à `BlockEmbed.imageType` de flutter_quill (interop, parité DODLP).
const String kImageEmbedType = 'image';

/// Clé/type Delta de l'embed vidéo — op `{"insert": {"video": "<source>"}}`.
/// IDENTIQUE à `BlockEmbed.videoType` de flutter_quill (interop, parité DODLP).
const String kVideoEmbedType = 'video';

/// Libellés a11y (AD-13) des placeholders — lisibles par lecteur d'écran.
@visibleForTesting
const String kImagePlaceholderLabel = 'image';
@visibleForTesting
const String kVideoPlaceholderLabel = 'vidéo';

/// Nature d'un média embed (image ou vidéo) — NEUTRE (aucun type Quill).
enum ZMediaKind {
  /// Embed image (`{"insert":{"image":<source>}}`).
  image,

  /// Embed vidéo (`{"insert":{"video":<source>}}`).
  video,
}

/// Référence NEUTRE à une source de média : nature + source OPAQUE (URL / URI /
/// chemin d'asset / data-uri — le package n'en interprète RIEN).
@immutable
class ZMediaRef {
  /// Construit une référence de média [kind] portant la [source] opaque.
  const ZMediaRef({required this.kind, required this.source});

  /// Image ou vidéo.
  final ZMediaKind kind;

  /// Source opaque (jamais interprétée/chargée par le package).
  final String source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZMediaRef &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          source == other.source;

  @override
  int get hashCode => Object.hash(kind, source);
}

/// **Seam de résolution de source** : transforme une [ZMediaRef] neutre en widget
/// rendu. FOURNI PAR L'HÔTE (via [ZMediaEmbedScope]). C'est le SEUL endroit où un
/// accès réseau/asset peut être décidé — le package n'en câble AUCUN.
///
/// Retourner `null` (ou laisser throw, capturé — AD-10) ⇒ le builder retombe sur
/// son placeholder thémé.
typedef ZMediaResolver = Widget? Function(BuildContext context, ZMediaRef ref);

/// `InheritedWidget` fournissant le [ZMediaResolver] aux embeds image/vidéo.
///
/// ABSENT ⇒ rendu placeholder (défaut sûr, zéro réseau). L'hôte l'insère au-dessus
/// de l'éditeur pour brancher son propre rendu média (ex. `Image.network`, cache,
/// lecteur vidéo) — code réseau confiné à l'app, jamais au package (AD-1).
class ZMediaEmbedScope extends InheritedWidget {
  /// Fournit [resolver] au sous-arbre [child].
  const ZMediaEmbedScope({
    required this.resolver,
    required super.child,
    super.key,
  });

  /// Résolveur de source injecté par l'hôte.
  final ZMediaResolver resolver;

  /// Récupère le résolveur le plus proche, ou `null` (⇒ placeholder).
  static ZMediaResolver? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ZMediaEmbedScope>();
    return scope?.resolver;
  }

  @override
  bool updateShouldNotify(ZMediaEmbedScope oldWidget) =>
      resolver != oldWidget.resolver;
}

/// Embed Quill STANDARD **bloc** de type `image` (`data` = source `String`).
class ZImageEmbed extends Embeddable {
  /// Construit l'embed image portant la [source] opaque.
  const ZImageEmbed(String source) : super(kImageEmbedType, source);
}

/// Embed Quill STANDARD **bloc** de type `video` (`data` = source `String`).
class ZVideoEmbed extends Embeddable {
  /// Construit l'embed vidéo portant la [source] opaque.
  const ZVideoEmbed(String source) : super(kVideoEmbedType, source);
}

/// `EmbedBuilder` de rendu DÉFENSIF (AD-10) d'un média (image OU vidéo) via le
/// seam [ZMediaResolver], sinon placeholder thémé. Sans état ⇒ instance `const`
/// STABLE (SM-1/AD-2 : aucune allocation par (re)build ; hors chemin chaud).
class ZMediaEmbedBuilder extends EmbedBuilder {
  /// Builder `const` pour la nature [kind] (clé Delta `image` ou `video`).
  const ZMediaEmbedBuilder(this.kind);

  /// Nature du média rendu (fixe la clé Delta captée).
  final ZMediaKind kind;

  @override
  String get key =>
      kind == ZMediaKind.image ? kImageEmbedType : kVideoEmbedType;

  /// Rendu BLOC : le média occupe sa propre ligne (cohérent image/vidéo).
  @override
  bool get expanded => true;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final Object? data = embedContext.node.value.data;
    // DÉFENSIF (AD-10) : source absente / non-`String` / vide → placeholder ;
    // on ne tente JAMAIS de résoudre une source invalide.
    if (data is! String || data.trim().isEmpty) {
      return _placeholder(context, source: null);
    }
    final ref = ZMediaRef(kind: kind, source: data);
    final ZMediaResolver? resolver = ZMediaEmbedScope.maybeOf(context);
    if (resolver != null) {
      try {
        final Widget? resolved = resolver(context, ref);
        if (resolved != null) {
          return Semantics(label: _label, child: resolved);
        }
      } on Object catch (error, stack) {
        // AD-10 : un resolver hôte qui throw ne casse JAMAIS l'éditeur.
        assert(() {
          debugPrint('ZMediaEmbedBuilder: resolver a throw ($error)\n$stack');
          return true;
        }());
      }
    }
    // Pas de resolver (ou échec) : placeholder thémé portant la source (aucun
    // accès réseau tenté par le package — seam neutre, AD-1).
    return _placeholder(context, source: data);
  }

  String get _label =>
      kind == ZMediaKind.image ? kImagePlaceholderLabel : kVideoPlaceholderLabel;

  IconData get _icon =>
      kind == ZMediaKind.image ? Icons.image_outlined : Icons.videocam_outlined;

  /// Placeholder BLOC thémé (AD-13/FR-26) : icône + libellé + source tronquée,
  /// enveloppé d'un [Semantics] lisible. Insets DIRECTIONNELS. Zéro couleur en
  /// dur (bordure/texte issus de `ZcrudTheme`/`Theme`).
  Widget _placeholder(BuildContext context, {required String? source}) {
    final ZcrudTheme zTheme = ZcrudTheme.of(context);
    final ThemeData theme = Theme.of(context);
    final Color borderColor =
        zTheme.fieldBorderColor ?? theme.colorScheme.outline;
    final Color fgColor = theme.colorScheme.onSurfaceVariant;
    final String caption =
        source == null ? _label : '$_label · ${_short(source)}';
    return Semantics(
      label: source == null ? _label : '$_label $source',
      image: kind == ZMediaKind.image,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.all(zTheme.radiusM),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(_icon, size: 20, color: fgColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    caption,
                    textAlign: TextAlign.start,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: fgColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tronque une source longue pour l'affichage du placeholder.
  static String _short(String source) {
    const int max = 48;
    return source.length <= max ? source : '${source.substring(0, max)}…';
  }
}

/// Ouvre le dialogue de saisie/édition d'une **source média** (URL / chemin /
/// data-uri — OPAQUE). Retourne la source saisie (non-blanche) ou `null` si
/// annulée. [initial] pré-remplit (édition). [kind] adapte le libellé.
///
/// SEAM NEUTRE : aucun upload/parcours de fichier n'est câblé ici (pas de
/// dépendance picker/réseau) — l'hôte peut pré-remplir la source (ex. après un
/// upload applicatif) via son propre flux ; le package ne fait que porter la
/// source opaque. Cibles ≥ 48 dp, [Semantics] explicites, insets DIRECTIONNELS.
Future<String?> showZMediaSourceDialog(
  BuildContext context, {
  required ZMediaKind kind,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _ZMediaSourceDialog(kind: kind, initial: initial),
  );
}

class _ZMediaSourceDialog extends StatefulWidget {
  const _ZMediaSourceDialog({required this.kind, required this.initial});

  final ZMediaKind kind;
  final String initial;

  @override
  State<_ZMediaSourceDialog> createState() => _ZMediaSourceDialogState();
}

class _ZMediaSourceDialogState extends State<_ZMediaSourceDialog> {
  late final TextEditingController _text;

  /// Cible de tap minimale (AD-13).
  static const double _kMinTapTarget = 48;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _isImage => widget.kind == ZMediaKind.image;

  String get _title => _isImage ? 'Image' : 'Vidéo';

  String get _fieldLabel => _isImage ? 'Source de l\'image' : 'Source de la vidéo';

  /// Une source VIDE/BLANCHE est traitée comme une ANNULATION (`pop(null)`) : on
  /// n'insère JAMAIS un embed média sans source (qui ne rendrait qu'un
  /// placeholder d'erreur persistant).
  void _submit() {
    final String source = _text.text;
    if (source.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pop(source.trim());
  }

  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Semantics(header: true, child: Text(_title)),
      content: TextField(
        controller: _text,
        autofocus: true,
        textAlign: TextAlign.start,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: _fieldLabel,
          hintText: _isImage ? 'https://… / assets/…' : 'https://…',
          hintTextDirection: TextDirection.ltr,
        ),
      ),
      actionsPadding: const EdgeInsetsDirectional.only(
        end: 12,
        bottom: 8,
        start: 12,
      ),
      actions: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _kMinTapTarget,
            minHeight: _kMinTapTarget,
          ),
          child: TextButton(
            onPressed: _cancel,
            child: Text(l10n.cancelButtonLabel),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _kMinTapTarget,
            minHeight: _kMinTapTarget,
          ),
          child: FilledButton(
            onPressed: _submit,
            child: Text(l10n.okButtonLabel),
          ),
        ),
      ],
    );
  }
}
