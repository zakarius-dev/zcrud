/// `ZRichTextFullscreenDialog` — éditeur rich-text **plein-écran** (B6).
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
/// - **AD-13** : actions ≥ 48 dp, `Semantics` explicites, directionnel ;
///   couleurs issues du thème injecté (repli `Theme.of`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/delta_neutral_ops.dart';
import '../data/z_delta_codec.dart';
import '../domain/z_codec.dart';
import 'z_rich_text_core.dart';
import 'z_rich_text_style_set.dart';
import 'z_rich_text_toolbar_config.dart';

/// Seuil de largeur (dp) sous lequel le dialog bascule en `Scaffold`
/// plein-écran (petit écran / mobile). Au-dessus : dialog centré 80 %×70 %.
const double _kFullscreenBreakpoint = 600;

/// Ouvre l'éditeur rich-text plein-écran et retourne la **valeur neutre** éditée
/// (Delta JSON) si l'utilisateur **valide**, ou `null` s'il **annule**/ferme.
///
/// [initialValue] pré-remplit l'éditeur (valeur neutre OU format persisté du
/// [codec]). [title] est le titre affiché (défaut « Éditer »), [subtitle] la
/// ligne secondaire rendue sous lui. AUCUN type Quill dans la signature (AD-7).
///
/// [fullscreen] fige la présentation : `true` ⇒ plein cadre (`Scaffold`),
/// `false` ⇒ dialogue centré 80 %×70 %. `null` (défaut) ⇒ arbitrage
/// **automatique** sur la largeur de l'écran, le comportement historique — un
/// hôte qui ne passe rien ne voit aucune différence, à aucune largeur.
///
/// Le forçage sert l'hôte dont toutes les éditions ouvrent une ROUTE plein
/// cadre : sans lui, il devait remonter le helper autour de
/// `ZRichTextFullscreenDialog`, et figeait au passage **sa** valeur du seuil de
/// bascule au lieu de suivre celle du socle.
Future<Object?> showZRichTextFullscreenDialog(
  BuildContext context, {
  required Object? initialValue,
  String? title,
  String? subtitle,
  ZCodec? codec,
  String? placeholder,
  ZRichTextStyleSet? styleSet,
  double? textScaleFactor,
  ZRichTextFormulaSpec? formulaSpec,
  ZRichTextToolbarConfig? toolbarConfig,
  bool? fullscreen,
  List<ZEmbedRenderer> extraEmbedRenderers = const <ZEmbedRenderer>[],
}) {
  final size = MediaQuery.sizeOf(context);
  // `null` ⇒ arbitrage AUTOMATIQUE sur la largeur, exactement comme avant :
  // la valeur calculée est la même expression, au même endroit. Un booléen
  // explicite le REMPLACE et fige la présentation quelle que soit la largeur.
  final bool isFullscreen = fullscreen ?? (size.width < _kFullscreenBreakpoint);
  return showDialog<Object?>(
    context: context,
    // Plein-écran (petit écran) : dialog opaque plein cadre ; sinon dialog
    // centré dimensionné.
    useSafeArea: !isFullscreen,
    builder: (BuildContext dialogContext) => ZRichTextFullscreenDialog(
      initialValue: initialValue,
      title: title,
      subtitle: subtitle,
      codec: codec,
      placeholder: placeholder,
      styleSet: styleSet,
      textScaleFactor: textScaleFactor,
      formulaSpec: formulaSpec,
      toolbarConfig: toolbarConfig,
      fullscreen: isFullscreen,
      extraEmbedRenderers: extraEmbedRenderers,
    ),
  );
}

/// Contenu du dialog d'édition plein-écran.
///
/// Montage DIRECT prévu : un hôte qui gère lui-même sa route (ou son
/// `showDialog`) construit ce widget et fige la présentation par [fullscreen].
/// Passer par [showZRichTextFullscreenDialog] reste la voie courte.
class ZRichTextFullscreenDialog extends StatefulWidget {
  /// Construit le dialog. [fullscreen] `true` ⇒ présentation `Scaffold`
  /// plein-écran ; `false` ⇒ dialog centré 80 %×70 %.
  const ZRichTextFullscreenDialog({
    required this.initialValue,
    this.title,
    this.subtitle,
    this.codec,
    this.placeholder,
    this.styleSet,
    this.textScaleFactor,
    this.formulaSpec,
    this.toolbarConfig,
    this.fullscreen = false,
    this.extraEmbedRenderers = const <ZEmbedRenderer>[],
    super.key,
  });

  /// Rendus d'embed DÉCLARÉS PAR L'APPELANT, en plus de ceux du socle.
  ///
  /// Vide (défaut) ⇒ rendu strictement inchangé. Un rendu déclaré ici l'emporte
  /// sur celui du socle pour le même type d'op — voir [ZEmbedRenderer] pour la
  /// règle de collision.
  final List<ZEmbedRenderer> extraEmbedRenderers;

  /// Valeur NEUTRE (ou format persisté du [codec]) pré-remplissant l'éditeur.
  final Object? initialValue;

  /// Titre du dialog (défaut « Éditer »).
  final String? title;

  /// Ligne secondaire rendue **sous** le [title], dans les deux présentations
  /// (barre plein-écran et en-tête du dialogue dimensionné).
  ///
  /// Un éditeur plein cadre REMPLACE l'écran d'où l'on vient : il porte donc
  /// les deux informations que cet écran donnait — **sur quoi** on travaille
  /// (l'item) et **quel** champ on édite. Composer les deux dans [title]
  /// préserve l'information et perd la hiérarchie.
  ///
  /// Le texte vient de l'appelant (aucun libellé n'est fabriqué ici) et est
  /// tronqué à **une ligne**. `null` (défaut) ⇒ **absent de l'arbre** : aucune
  /// `Column` interposée, rendu strictement identique à celui d'avant
  /// l'ouverture du créneau.
  ///
  /// Sa typographie dérive des **métriques** de `TextTheme.titleSmall` ; sa
  /// couleur reste HÉRITÉE de la surface qui l'accueille, pour rester lisible
  /// sur une barre teintée.
  final String? subtitle;

  /// Codec de normalisation de l'entrée / défaut `ZDeltaCodec`.
  final ZCodec? codec;

  /// Placeholder (texte indicatif) de l'éditeur VIDE. Le texte vient de
  /// l'appelant (déjà résolu l10n par `ZMarkdownField`) ; `null` ⇒ aucun
  /// placeholder. JAMAIS de libellé codé en dur ici.
  final String? placeholder;

  /// Jeu de styles NEUTRE par champ — MÊME rendu que le champ appelant.
  final ZRichTextStyleSet? styleSet;

  /// Facteur d'échelle ABSOLU du texte. `null` ⇒ échelle ambiante.
  final double? textScaleFactor;

  /// Rendu des formules par champ. `null` ⇒ rendu historique.
  final ZRichTextFormulaSpec? formulaSpec;

  /// Config de barre NEUTRE transmise par le champ appelant.
  /// `null` ⇒ défaut historique du dialog ([ZRichTextToolbarConfig.full]).
  final ZRichTextToolbarConfig? toolbarConfig;

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

  // Mémoïsation de la liste d'`EmbedBuilder`s : recalculée seulement quand la
  // liste déclarée par l'appelant CHANGE D'IDENTITÉ, jamais à chaque build
  // (AD-2 : la référence passée à Quill doit rester stable).
  List<ZEmbedRenderer>? _renderersSeen;
  List<EmbedBuilder>? _embedBuildersCache;

  List<EmbedBuilder> get _embedBuilders {
    if (!identical(_renderersSeen, widget.extraEmbedRenderers)) {
      _renderersSeen = widget.extraEmbedRenderers;
      _embedBuildersCache = zEmbedBuildersWith(widget.extraEmbedRenderers);
    }
    return _embedBuildersCache!;
  }

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
      // config transmise par le champ appelant ; `null` ⇒ full
      // (défaut historique du dialog, inchangé).
      config: widget.toolbarConfig ?? ZRichTextToolbarConfig.full,
      // CR 2026-08-11 : SURFACE plein-écran ⇒ AUTO = multi-rangées (c'est là
      // que la place existe, la découvrabilité des boutons y prime). Un
      // `multiRow: true/false` posé par l'hôte reste un forçage respecté.
      autoMultiRow: true,
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
          // fond thémé OPT-IN — `false`/`null` ⇒ aucun wrapper.
          child: zDecorateToolbar(
            context,
            widget.toolbarConfig ?? ZRichTextToolbarConfig.full,
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kZMinTapTarget),
              child:
                  QuillSimpleToolbar(controller: _quill, config: _toolbarConfig),
            ),
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
              // mêmes échelle/formules que le champ appelant.
              child: zWrapRichTextContent(
                context,
                textScaleFactor: widget.textScaleFactor,
                formulaSpec: widget.formulaSpec,
                QuillEditor(
                  controller: _quill,
                  focusNode: _focus,
                  scrollController: _scroll,
                  config: QuillEditorConfig(
                    padding: EdgeInsetsDirectional.zero,
                    embedBuilders: _embedBuilders,
                    // (AD-10) : repli TOTAL. Sans lui, un type
                    // d'embed inconnu — d'un hôte, d'une version future, ou né
                    // d'une op corrompue — lève un `UnimplementedError` EN PLEIN
                    // BUILD, donc irrattrapable : écran rouge, puis cascade de
                    // `RenderErrorBox`. Mesuré sur `divider`.
                    unknownEmbedBuilder: kZUnknownEmbedBuilder,
                    // styles de titres dérivés du thème.
                    // jeu de styles par champ fusionné par-dessus.
                    customStyles:
                        zQuillThemedStyles(context, styleSet: widget.styleSet),
                    // même placeholder que le champ appelant.
                    placeholder: widget.placeholder,
                  ),
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
        title: _titleBlock(context, title),
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
        // Dialog dimensionné 80 %×70 %.
        : _sizedDialog(context, title);

    return Localizations.override(
      context: context,
      delegates: const <LocalizationsDelegate<dynamic>>[
        FlutterQuillLocalizations.delegate,
      ],
      child: content,
    );
  }

  /// Bloc titre (+ sous-titre) partagé par les DEUX présentations.
  ///
  /// Sans sous-titre, il rend exactement le nœud d'avant — un `Semantics`
  /// d'en-tête portant le seul `Text` du titre. Avec, la `Column` groupe les
  /// deux lignes SOUS le même `Semantics` : l'annonce du lecteur d'écran reste
  /// un en-tête unique (« titre sous-titre ») au lieu de deux nœuds
  /// concurrents.
  Widget _titleBlock(
    BuildContext context,
    String title, {
    TextStyle? titleStyle,
  }) {
    final Widget titleText = Text(
      title,
      textAlign: TextAlign.start,
      style: titleStyle,
    );
    final String? subtitle = widget.subtitle;
    if (subtitle == null) {
      return Semantics(header: true, child: titleText);
    }
    // Métriques SEULEMENT (taille, graisse, interlettrage, hauteur) : la
    // couleur reste celle héritée de la surface. Forcer ici une couleur du
    // `textTheme` rendrait le sous-titre illisible sur une barre teintée par
    // l'hôte — le pendant exact de l'arbitrage déjà tenu sur l'en-tête de page.
    final TextStyle? small = Theme.of(context).textTheme.titleSmall;
    return Semantics(
      header: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // DIRECTIONNEL (AD-13) : jamais `left`.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          titleText,
          Text(
            subtitle,
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: small?.fontSize,
              fontWeight: small?.fontWeight,
              letterSpacing: small?.letterSpacing,
              height: small?.height,
            ),
          ),
        ],
      ),
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
              _titleBlock(
                context,
                title,
                titleStyle: Theme.of(context).textTheme.titleLarge,
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
