/// `ZRichTextFullscreenDialog` — éditeur rich-text **plein-écran** (DP-3, B6/AC3).
///
/// Présente l'éditeur Quill COMPLET (toolbar complète + embeds LaTeX/tableau) en
/// **dialog dimensionné 80 %×70 %** de l'écran, avec **repli `Scaffold`
/// plein-écran** sous un seuil de largeur (petit écran). Pré-rempli avec une
/// **valeur neutre** ; **Valider** retourne la valeur neutre éditée, **Annuler**
/// retourne `null` (aucune mutation). Ouvert par le mode `inline` (bouton
/// « Agrandir ») ET le mode `block` (bouton « Rédiger »/« Modifier »).
///
/// INVARIANTS (NON-NÉGOCIABLES) :
/// - **AD-7/AD-1** : entrée/sortie = valeur **NEUTRE** (`Object?` Delta JSON) +
///   `ZCodec` optionnel ; AUCUN type Quill dans la signature publique
///   ([showZRichTextFullscreenDialog], `ZRichTextFullscreenDialog`).
/// - **AD-2** : [QuillController] isolé créé UNE FOIS / disposé ; ici PAS de sync
///   guardée (le dialog possède sa propre copie éphémère du document — la
///   remontée se fait UNIQUEMENT à la validation).
/// - **AD-10** : valeur d'entrée absente/corrompue → document VIDE éditable,
///   jamais de throw ; annulation → `null`.
/// - **AD-13/FR-26** : actions ≥ 48 dp, `Semantics` explicites, directionnel ;
///   couleurs issues du thème injecté (repli `Theme.of`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/delta_neutral_ops.dart';
import '../data/z_delta_codec.dart';
import '../domain/z_codec.dart';
import 'z_rich_text_core.dart';

/// Seuil de largeur (dp) sous lequel le dialog bascule en `Scaffold`
/// plein-écran (petit écran / mobile). Au-dessus : dialog centré 80 %×70 %.
const double _kFullscreenBreakpoint = 600;

/// Ouvre l'éditeur rich-text plein-écran et retourne la **valeur neutre** éditée
/// (Delta JSON) si l'utilisateur **valide**, ou `null` s'il **annule**/ferme.
///
/// [initialValue] pré-remplit l'éditeur (valeur neutre OU format persisté du
/// [codec]). [title] est le titre affiché (défaut « Éditer »). AUCUN type Quill
/// dans la signature (AD-7).
Future<Object?> showZRichTextFullscreenDialog(
  BuildContext context, {
  required Object? initialValue,
  String? title,
  ZCodec? codec,
}) {
  final size = MediaQuery.sizeOf(context);
  final bool fullscreen = size.width < _kFullscreenBreakpoint;
  return showDialog<Object?>(
    context: context,
    // Plein-écran (petit écran) : dialog opaque plein cadre ; sinon dialog
    // centré dimensionné (AC3).
    useSafeArea: !fullscreen,
    builder: (BuildContext dialogContext) => ZRichTextFullscreenDialog(
      initialValue: initialValue,
      title: title,
      codec: codec,
      fullscreen: fullscreen,
    ),
  );
}

/// Contenu du dialog d'édition plein-écran (exposé pour les tests widget).
class ZRichTextFullscreenDialog extends StatefulWidget {
  /// Construit le dialog. [fullscreen] `true` ⇒ présentation `Scaffold`
  /// plein-écran ; `false` ⇒ dialog centré 80 %×70 %.
  const ZRichTextFullscreenDialog({
    required this.initialValue,
    this.title,
    this.codec,
    this.fullscreen = false,
    super.key,
  });

  /// Valeur NEUTRE (ou format persisté du [codec]) pré-remplissant l'éditeur.
  final Object? initialValue;

  /// Titre du dialog (défaut « Éditer »).
  final String? title;

  /// Codec de normalisation de l'entrée / défaut `ZDeltaCodec`.
  final ZCodec? codec;

  /// Présentation plein-écran (`Scaffold`) vs dialog dimensionné.
  final bool fullscreen;

  @override
  State<ZRichTextFullscreenDialog> createState() =>
      _ZRichTextFullscreenDialogState();
}

class _ZRichTextFullscreenDialogState extends State<ZRichTextFullscreenDialog> {
  late final QuillController _quill;
  late final FocusNode _focus;
  late final ScrollController _scroll;
  late final ZCodec _codec;
  late final QuillSimpleToolbarConfig _toolbarConfig;

  @override
  void initState() {
    super.initState();
    _codec = widget.codec ?? const ZDeltaCodec();
    final ops = _codec.decode(widget.initialValue);
    final document = DeltaNeutralOps.decodeDefensiveDocument(ops);
    _quill = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _focus = FocusNode();
    _scroll = ScrollController();
    _toolbarConfig = buildZToolbarConfig(
      onInsertLatex: () =>
          insertZLatex(context, _quill, isMounted: () => mounted),
      onInsertTable: () =>
          insertZTable(context, _quill, isMounted: () => mounted),
    );
  }

  @override
  void dispose() {
    _quill.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Valide : remonte la valeur NEUTRE courante (Delta JSON) au demandeur.
  void _submit() {
    final neutral = DeltaNeutralOps.encodeNeutral(_quill.document);
    Navigator.of(context).pop(neutral);
  }

  /// Annule : retourne `null` (aucune mutation de la tranche hôte).
  void _cancel() => Navigator.of(context).pop();

  Widget _buildBody(BuildContext context) {
    final zTheme = ZcrudTheme.of(context);
    final borderColor =
        zTheme.fieldBorderColor ?? Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          container: true,
          label: 'Barre d\'outils',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kZMinTapTarget),
            child: QuillSimpleToolbar(controller: _quill, config: _toolbarConfig),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.all(zTheme.radiusM),
            ),
            child: Padding(
              padding: zTheme.fieldPadding,
              child: QuillEditor(
                controller: _quill,
                focusNode: _focus,
                scrollController: _scroll,
                config: const QuillEditorConfig(
                  padding: EdgeInsetsDirectional.zero,
                  embedBuilders: kZEmbedBuilders,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _actions(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    return <Widget>[
      Semantics(
        button: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kZMinTapTarget,
            minHeight: kZMinTapTarget,
          ),
          child: TextButton(
            key: const Key('z-richtext-dialog-cancel'),
            onPressed: _cancel,
            child: Text(l10n.cancelButtonLabel),
          ),
        ),
      ),
      Semantics(
        button: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kZMinTapTarget,
            minHeight: kZMinTapTarget,
          ),
          child: FilledButton(
            key: const Key('z-richtext-dialog-submit'),
            onPressed: _submit,
            child: Text(l10n.okButtonLabel),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.title ?? 'Éditer';
    final Widget scaffold = Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('z-richtext-dialog-close'),
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
          onPressed: _cancel,
        ),
        title: Semantics(header: true, child: Text(title)),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton(
              key: const Key('z-richtext-dialog-submit'),
              onPressed: _submit,
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context)),
    );

    final Widget content = widget.fullscreen
        // Plein-écran : Scaffold occupe tout le cadre du dialog.
        ? Dialog.fullscreen(child: scaffold)
        // Dialog dimensionné 80 %×70 % (AC3).
        : _sizedDialog(context, title);

    return Localizations.override(
      context: context,
      delegates: const <LocalizationsDelegate<dynamic>>[
        FlutterQuillLocalizations.delegate,
      ],
      child: content,
    );
  }

  Widget _sizedDialog(BuildContext context, String title) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      child: SizedBox(
        width: size.width * 0.8,
        height: size.height * 0.7,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody(context)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _actions(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
