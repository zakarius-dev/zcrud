/// `ZMarkdownReader` — **lecteur** rich-text NON éditable (B4).
///
/// Rend une **valeur neutre** (Delta JSON) en lecture seule via un [QuillEditor]
/// readOnly, SANS toolbar, SANS voie d'écriture. Réutilise les MÊMES embed
/// builders (LaTeX/tableau) que l'éditeur — les embeds sont donc rendus en
/// lecture. Utilisé (a) quand `field.readOnly == true` (voie `controller` ET
/// voie `ctx`), et (b) comme APERÇU du mode `block` (avant ouverture du dialog).
///
/// INVARIANTS (NON-NÉGOCIABLES) :
/// - **AD-2** : [QuillController] readOnly créé UNE FOIS en `initState`
///   disposé en `dispose`, JAMAIS recréé au rebuild. **AUCUN** abonnement
///   `document.changes`, **AUCUN** `setValue`/`onChanged` : la voie de frappe
///   n'existe pas en lecture. Une nouvelle valeur EXTERNE ré-hydrate le document
///   (swap `document`) sans recréer le controller.
/// - **AD-7/AD-1** : entrée = valeur **NEUTRE** (`Object?` Delta JSON) + `ZCodec`
///   optionnel ; AUCUN type Quill dans la signature publique.
/// - **AD-10** : valeur absente/vide/corrompue → rendu VIDE propre (placeholder
///   discret), JAMAIS de throw.
/// - **AD-13** : directionnel, `Semantics` **lisible** (le contenu est
///   exposé au lecteur d'écran) mais SANS action d'édition ; couleurs issues du
///   thème injecté (repli `Theme.of`), zéro couleur codée en dur.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/delta_neutral_ops.dart';
import '../data/z_delta_codec.dart';
import '../domain/z_codec.dart';
import '../domain/z_markdown_copy_format.dart';
import 'z_rich_text_core.dart';
import 'z_rich_text_style_set.dart';

/// Habillage du [ZMarkdownReader].
///
/// Le lecteur a été écrit pour une **place de champ de formulaire** : cadre,
/// rayon, `fieldPadding`. Ce chrome est juste là, et il reste le défaut. Il est
/// en revanche **faux dans une bulle de conversation**, qui porte déjà son fond,
/// son rayon et ses marges : le cadre y devient une boîte dans une boîte.
///
/// AD-57 : strictement **additif**. [bordered] est le défaut, donc un appelant
/// existant ne bouge pas d'un pixel.
enum ZMarkdownReaderChrome {
  /// Cadre + rayon + `fieldPadding` du thème — le rendu historique (défaut).
  bordered,

  /// **Aucun** cadre, **aucun** padding : le contenu seul. L'appelant fournit
  /// son propre habillage (bulle de chat, carte, aperçu inline).
  none,
}

/// Lecteur rich-text NON éditable d'une **valeur neutre** (Delta JSON).
class ZMarkdownReader extends StatefulWidget {
  /// Construit le lecteur pour [value] (valeur neutre de la tranche).
  ///
  /// [codec] normalise une valeur au format persisté (ex. String Markdown) en
  /// ops neutres avant rendu (précédence `param > défaut ZDeltaCodec`). [label]
  /// alimente la sémantique. [placeholder] est le texte affiché quand le contenu
  /// est vide (défaut « Aucun contenu »).
  const ZMarkdownReader({
    required this.value,
    this.codec,
    this.label,
    this.placeholder = defaultPlaceholder,
    this.chrome = ZMarkdownReaderChrome.bordered,
    this.semanticsEnabled = true,
    this.baseStyle,
    this.styleSet,
    this.textScaleFactor,
    this.formulaSpec,
    this.copyOnLongPress = false,
    this.copyFormats = const <ZMarkdownCopyFormat>[],
    this.copiedFeedbackText,
    this.copySemanticsLabel,
    this.emptyBuilder,
    this.emptyIcon,
    this.emptySubtitle,
    this.extraEmbedRenderers = const <ZEmbedRenderer>[],
    super.key,
  });

  /// Rendus d'embed DÉCLARÉS PAR L'APPELANT, en plus de ceux du socle.
  ///
  /// Vide (défaut) ⇒ rendu strictement inchangé. Un rendu déclaré ici l'emporte
  /// sur celui du socle pour le même type d'op — voir [ZEmbedRenderer] pour la
  /// règle de collision.
  final List<ZEmbedRenderer> extraEmbedRenderers;

  /// Texte du placeholder par défaut de l'état vide.
  static const String defaultPlaceholder = 'Aucun contenu';

  /// Valeur NEUTRE courante à rendre (Delta JSON `List<Map<String, dynamic>>`)
  /// ou valeur au format persisté du [codec]. `null`/vide ⇒ placeholder.
  final Object? value;

  /// `ZCodec` de normalisation de la valeur d'entrée (défaut `ZDeltaCodec`).
  final ZCodec? codec;

  /// Libellé de champ pour la sémantique (lecture d'écran).
  final String? label;

  /// Texte affiché quand le contenu est vide (AD-10).
  final String placeholder;

  /// Habillage du lecteur. Défaut [ZMarkdownReaderChrome.bordered]
  /// = rendu historique inchangé.
  final ZMarkdownReaderChrome chrome;

  /// Pose le nœud [Semantics] `readOnly` du lecteur (défaut `true` = historique).
  ///
  /// **Pourquoi c'est débrayable, et mesuré.** Un appelant qui annonce
  /// DÉJÀ le contenu au-dessus — c'est le cas de `ZChatMessageTile`, qui pose
  /// un `Semantics` de message alimenté par `ZContentBlock.accessibleText` —
  /// ferait, sans ce drapeau, **deux** nœuds pour un seul contenu : le message
  /// annoncé une fois par la tuile, une seconde par le lecteur. Le
  /// coupe-circuit n'invente rien : il laisse l'annonce là où elle était déjà.
  final bool semanticsEnabled;

  /// Style **attendu par l'appelant** pour le corps de texte (DP-RT).
  ///
  /// Additif (AD-57) : `null` = défaut = rendu historique, dérivé du seul thème.
  /// Fourni, il devient la base du paragraphe, des listes et de la citation ;
  /// les rôles matérialisés (titres, code inline) en dévient délibérément.
  /// C'est le canal par lequel [ZMarkdownRichTextRenderer] honore le `baseStyle`
  /// du port `ZRichTextRenderer` — et il alimente AUSSI le placeholder, pour que
  /// le vide ne change pas de taille en cours de route.
  final TextStyle? baseStyle;

  /// Jeu de styles NEUTRE par champ — mêmes slots qu'en édition,
  /// appliqué PAR-DESSUS thème + [baseStyle]. `null` ⇒ rendu historique (AD-57).
  final ZRichTextStyleSet? styleSet;

  /// Facteur d'échelle ABSOLU du texte rendu. `null` ⇒ échelle ambiante.
  final double? textScaleFactor;

  /// Rendu des formules par champ. `null` ⇒ rendu historique.
  final ZRichTextFormulaSpec? formulaSpec;

  /// (opt-in) : un **appui long** sur le contenu copie la valeur au
  /// presse-papier (parité legacy `edition_screen:1293-1300`).
  ///
  /// Charge copiée : la valeur ENCODÉE par le codec du lecteur — un
  /// `ZMarkdownCodec` copie donc le **string Markdown** (comportement legacy) ;
  /// un codec dont l'encodage n'est pas un `String` (ex. `ZDeltaCodec`) copie
  /// le Delta JSON sérialisé. Mesuré : le long-press de SÉLECTION de
  /// l'éditeur (enfant) gagne l'arène gestuelle sur un `GestureDetector`
  /// parent — l'opt-in **désactive donc la sélection interactive** du lecteur,
  /// exactement l'articulation legacy (lecteur non sélectionnable, appui long
  /// = tout copier). Défaut `false` ⇒ rendu ET gestes historiques inchangés.
  final bool copyOnLongPress;

  /// Formats de copie DÉCLARÉS PAR L'HÔTE (ne s'applique que si
  /// [copyOnLongPress] est actif).
  ///
  /// Vide (défaut) ⇒ le geste copie DIRECTEMENT la valeur encodée par le
  /// codec du lecteur (comportement historique inchangé). Non vide ⇒ l'appui
  /// long ouvre un menu listant EXACTEMENT ces formats, dans cet ordre
  /// (libellé résolu l10n par [ZMarkdownCopyFormat.key]) ; la transformation
  /// du format choisi reçoit le Delta neutre du document courant et sa chaîne
  /// est copiée. Le retour ([copiedFeedbackText]) est le même dans les deux
  /// voies.
  final List<ZMarkdownCopyFormat> copyFormats;

  /// libellé du retour (SnackBar via `ScaffoldMessenger.maybeOf`)
  /// après copie — INJECTÉ par l'hôte (l10n chez lui, aucun libellé en dur
  /// ici). `null` OU messenger absent ⇒ copie **silencieuse** (aucun crash).
  final String? copiedFeedbackText;

  /// libellé `Semantics` du geste de copie (hint annoncé au lecteur
  /// d'écran). `null` ⇒ l'action long-press reste exposée, annoncée par le
  /// système (localisé), sans hint supplémentaire.
  final String? copySemanticsLabel;

  /// (opt-in) : constructeur d'état vide ENTIÈREMENT custom — prioritaire
  /// sur [emptyIcon]/[emptySubtitle]. `null` (et icône/sous-titre `null`) ⇒
  /// état vide historique STRICTEMENT inchangé ([placeholder] seul).
  final WidgetBuilder? emptyBuilder;

  /// (opt-in) : icône de l'état vide enrichi (parité legacy
  /// `notes_rounded` — l'ICÔNE est choisie par l'hôte, rien d'imposé).
  final IconData? emptyIcon;

  /// (opt-in) : seconde ligne de l'état vide enrichi (sous le
  /// [placeholder]) — libellé INJECTÉ par l'hôte (aucun texte en dur ici).
  final String? emptySubtitle;

  @override
  State<ZMarkdownReader> createState() => _ZMarkdownReaderState();
}

class _ZMarkdownReaderState extends State<ZMarkdownReader> {
  /// Controller Quill **readOnly** isolé — créé UNE FOIS, jamais recréé (AD-2).
  /// N'écoute PAS `document.changes` (aucun abonnement, aucune émission).
  late final QuillController _quill;

  /// `ScrollController` stable du lecteur.
  late final ScrollController _scroll;

  /// `FocusNode` NON focusable (lecture seule) — requis par [QuillEditor] mais
  /// ne prend jamais le focus clavier ni la traversée. Créé UNE FOIS.
  late final FocusNode _focus;

  /// Codec de normalisation de l'entrée (résolu UNE FOIS).
  late final ZCodec _codec;

  /// JSON canonique de la dernière valeur rendue — dédup de la ré-hydratation.
  late String _lastValueJson;

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
    final ops = _codec.decode(widget.value);
    final document = DeltaNeutralOps.decodeDefensiveDocument(ops);
    // readOnly: true ⇒ le controller REJETTE toute mutation ; aucun
    // abonnement `document.changes` n'est posé (voie de frappe absente).
    _quill = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    _scroll = ScrollController();
    _focus = FocusNode(canRequestFocus: false, skipTraversal: true);
    _lastValueJson = jsonEncode(DeltaNeutralOps.encodeNeutral(document));
  }

  @override
  void didUpdateWidget(covariant ZMarkdownReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ré-hydrate le document si la valeur EXTERNE a changé (aperçu block après
    // édition dialog, ou mode lecture rafraîchi). Swap du document SANS recréer
    // le controller (AD-2). Aucune voie d'écriture n'est réactivée (readOnly).
    final ops = _codec.decode(widget.value);
    final incoming = DeltaNeutralOps.decodeDefensiveDocument(ops);
    final incomingJson = jsonEncode(DeltaNeutralOps.encodeNeutral(incoming));
    if (incomingJson == _lastValueJson) return;
    _quill.document = incoming;
    _lastValueJson = incomingJson;
  }

  @override
  void dispose() {
    _quill.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _isEmpty {
    // Document « vide » = uniquement le `\n` terminal Delta (longueur 1).
    final plain = _quill.document.toPlainText().trim();
    return plain.isEmpty;
  }

  /// copie la valeur ENCODÉE (codec du lecteur) au presse-papier,
  /// puis retour opt-in — SnackBar seulement si un libellé est INJECTÉ **et**
  /// qu'un `ScaffoldMessenger` est monté ; sinon copie silencieuse (AD-10 :
  /// jamais de crash faute de canal de notification).
  Future<void> _copyAll() async {
    final Object? encoded =
        _codec.encode(DeltaNeutralOps.encodeNeutral(_quill.document));
    final String payload = encoded is String ? encoded : jsonEncode(encoded);
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    final String? feedback = widget.copiedFeedbackText;
    if (feedback == null) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(feedback)));
  }

  /// dispatch du geste de copie : SANS format déclaré, copie directe
  /// (comportement de référence inchangé) ; AVEC, menu des formats de l'hôte
  /// ancré au point d'appui ([globalPosition], repli = centre du lecteur).
  Future<void> _onCopyGesture([Offset? globalPosition]) async {
    if (widget.copyFormats.isEmpty) return _copyAll();
    // Sans Overlay monté (hôte minimal), aucun menu n'est possible : repli
    // sur la copie directe plutôt qu'un throw (jamais de crash).
    if (Overlay.maybeOf(context) == null) return _copyAll();
    final ZMarkdownCopyFormat? chosen = await _showCopyMenu(globalPosition);
    if (chosen == null || !mounted) return;
    await _copyWithFormat(chosen);
  }

  /// menu des formats déclarés — EXACTEMENT la liste de l'hôte, dans son
  /// ordre ; libellés résolus l10n par clé (`label(context, key,
  /// fallback: key)`), aucun libellé du paquet. Items ≥ 48 dp
  /// (hauteur [kMinInteractiveDimension] des [PopupMenuItem]) + `Semantics`
  /// bouton.
  Future<ZMarkdownCopyFormat?> _showCopyMenu(Offset? globalPosition) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final RenderBox self = context.findRenderObject()! as RenderBox;
    final Offset anchor = globalPosition ??
        self.localToGlobal(self.size.center(Offset.zero), ancestor: overlay);
    // Ancrage au POINT physique de l'appui (position pointeur, indépendante de
    // la direction de lecture) ; le menu se replace seul près des bords.
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromCenter(center: anchor, width: 0, height: 0),
      Offset.zero & overlay.size,
    );
    return showMenu<ZMarkdownCopyFormat>(
      context: context,
      position: position,
      items: <PopupMenuEntry<ZMarkdownCopyFormat>>[
        for (final ZMarkdownCopyFormat format in widget.copyFormats)
          PopupMenuItem<ZMarkdownCopyFormat>(
            key: Key('z-markdown-copy-format-${format.key}'),
            value: format,
            // hauteur par défaut d'un PopupMenuItem = kMinInteractiveDimension
            // (48 dp) — cible tactile suffisante sans contrainte ajoutée.
            child: Semantics(
              button: true,
              child: Text(label(context, format.key, fallback: format.key)),
            ),
          ),
      ],
    );
  }

  /// copie la chaîne produite par la transformation de [format] à partir du
  /// Delta NEUTRE du document courant, puis même retour que [_copyAll].
  /// Défensif : une transformation d'hôte qui lève n'écrit rien et ne casse
  /// jamais le lecteur.
  Future<void> _copyWithFormat(ZMarkdownCopyFormat format) async {
    final List<Map<String, dynamic>> delta =
        DeltaNeutralOps.encodeNeutral(_quill.document);
    final String payload;
    try {
      payload = format.transform(delta);
    } on Object catch (_) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    final String? feedback = widget.copiedFeedbackText;
    if (feedback == null) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(feedback)));
  }

  /// état vide — historique STRICT quand aucun paramètre d'état vide
  /// n'est fourni ; enrichi (icône + deux lignes) ou builder custom sinon.
  Widget _buildEmptyState(BuildContext context, EdgeInsetsGeometry pad) {
    final WidgetBuilder? builder = widget.emptyBuilder;
    if (builder != null) {
      return Padding(padding: pad, child: builder(context));
    }
    final TextStyle? placeholderStyle =
        widget.baseStyle ?? Theme.of(context).textTheme.bodySmall;
    if (widget.emptyIcon == null && widget.emptySubtitle == null) {
      // Défaut HISTORIQUE inchangé (gardé) : le placeholder seul, aligné début.
      return Padding(
        padding: pad,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            widget.placeholder,
            textAlign: TextAlign.start,
            style: placeholderStyle,
          ),
        ),
      );
    }
    // Enrichi (opt-in) : icône + [placeholder] + sous-titre, centrés —
    // couleurs issues des RÔLES du thème (zéro couleur en dur).
    final Color muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: pad,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (widget.emptyIcon != null) ...<Widget>[
              Icon(widget.emptyIcon, color: muted, size: 32),
              const SizedBox(height: 8),
            ],
            Text(
              widget.placeholder,
              textAlign: TextAlign.center,
              style: placeholderStyle,
            ),
            if (widget.emptySubtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                widget.emptySubtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zTheme = ZcrudTheme.of(context);
    final borderColor =
        zTheme.fieldBorderColor ?? Theme.of(context).colorScheme.outline;

    // `none` retire cadre ET padding — l'appelant habille.
    final bool chromeless = widget.chrome == ZMarkdownReaderChrome.none;
    final EdgeInsetsGeometry pad = chromeless
        ? EdgeInsetsDirectional.zero
        : zTheme.fieldPadding;

    final Widget content = _isEmpty
        // historique STRICT sans paramètre ; enrichi/builder opt-in.
        ? _buildEmptyState(context, pad)
        : Padding(
            padding: pad,
            child: zWrapRichTextContent(
              context,
              // échelle/formules par champ — `null` ⇒ aucun wrapper.
              textScaleFactor: widget.textScaleFactor,
              formulaSpec: widget.formulaSpec,
              QuillEditor(
              controller: _quill,
              focusNode: _focus,
              scrollController: _scroll,
              config: QuillEditorConfig(
                // Non-scrollable : hauteur intrinsèque, l'hôte défile.
                scrollable: false,
                padding: EdgeInsetsDirectional.zero,
                // Autorise la sélection/copie (lecture) mais AUCUNE saisie
                // (controller readOnly). MÊMES embed builders qu'en édition.
                // l'opt-in `copyOnLongPress` DÉSACTIVE la sélection
                // interactive — mesuré, le recognizer long-press de sélection
                // (enfant) gagnerait sinon l'arène sur le geste de copie.
                enableInteractiveSelection: !widget.copyOnLongPress,
                showCursor: false,
                embedBuilders: _embedBuilders,
                // (AD-10) : repli TOTAL. Sans lui, un type
                // d'embed inconnu — d'un hôte, d'une version future, ou né
                // d'une op corrompue — lève un `UnimplementedError` EN PLEIN
                // BUILD, donc irrattrapable : écran rouge, puis cascade de
                // `RenderErrorBox`. Mesuré sur `divider`.
                unknownEmbedBuilder: kZUnknownEmbedBuilder,
                  // styles de titres dérivés du thème.
                  // jeu de styles par champ fusionné par-dessus.
                  customStyles: zQuillThemedStyles(
                    context,
                    baseStyle: widget.baseStyle,
                    styleSet: widget.styleSet,
                  ),
                ),
              ),
            ),
          );

    // (opt-in) : appui long = copie du contenu + retour. Jamais sur
    // l'état vide (parité legacy : le geste n'existe que s'il y a un contenu).
    Widget gestured = content;
    if (widget.copyOnLongPress && !_isEmpty) {
      gestured = Semantics(
        // Action exposée au lecteur d'écran (AD-13) ; hint INJECTÉ optionnel.
        // Voie sémantique sans position pointeur ⇒ le menu (si formats)
        // s'ancre au centre du lecteur.
        onLongPress: _onCopyGesture,
        hint: widget.copySemanticsLabel,
        child: GestureDetector(
          key: const Key('z-markdown-reader-copy-gesture'),
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (LongPressStartDetails details) =>
              _onCopyGesture(details.globalPosition),
          child: content,
        ),
      );
    }

    final Widget framed = chromeless
        ? gestured
        : DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.all(zTheme.radiusM),
            ),
            child: gestured,
          );

    final Widget reader = widget.semanticsEnabled
        // Lisible au lecteur d'écran (contenu exposé) mais SANS action
        // d'édition (readOnly=true ⇒ pas de champ éditable annoncé). AD-13.
        ? Semantics(label: widget.label, readOnly: true, child: framed)
        : framed;

    // Localisations Quill requises par QuillEditor (même en lecture).
    return Localizations.override(
      context: context,
      delegates: const <LocalizationsDelegate<dynamic>>[
        FlutterQuillLocalizations.delegate,
      ],
      child: reader,
    );
  }
}
