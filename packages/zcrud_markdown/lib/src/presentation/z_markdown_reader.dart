/// `ZMarkdownReader` — **lecteur** rich-text NON éditable (DP-3, B4/AC1).
///
/// Rend une **valeur neutre** (Delta JSON) en lecture seule via un [QuillEditor]
/// readOnly, SANS toolbar, SANS voie d'écriture. Réutilise les MÊMES embed
/// builders (LaTeX/tableau) que l'éditeur — les embeds sont donc rendus en
/// lecture. Utilisé (a) quand `field.readOnly == true` (voie `controller` ET
/// voie `ctx`), et (b) comme APERÇU du mode `block` (avant ouverture du dialog).
///
/// INVARIANTS (NON-NÉGOCIABLES) :
/// - **AD-2/SM-1** : [QuillController] readOnly créé UNE FOIS en `initState`,
///   disposé en `dispose`, JAMAIS recréé au rebuild. **AUCUN** abonnement
///   `document.changes`, **AUCUN** `setValue`/`onChanged` : la voie de frappe
///   n'existe pas en lecture. Une nouvelle valeur EXTERNE ré-hydrate le document
///   (swap `document`) sans recréer le controller.
/// - **AD-7/AD-1** : entrée = valeur **NEUTRE** (`Object?` Delta JSON) + `ZCodec`
///   optionnel ; AUCUN type Quill dans la signature publique.
/// - **AD-10** : valeur absente/vide/corrompue → rendu VIDE propre (placeholder
///   discret), JAMAIS de throw.
/// - **AD-13/FR-26** : directionnel, `Semantics` **lisible** (le contenu est
///   exposé au lecteur d'écran) mais SANS action d'édition ; couleurs issues du
///   thème injecté (repli `Theme.of`), zéro couleur codée en dur.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/delta_neutral_ops.dart';
import '../data/z_delta_codec.dart';
import '../domain/z_codec.dart';
import 'z_rich_text_core.dart';

/// Habillage du [ZMarkdownReader] — CR-IFFD-73.
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
    this.placeholder = 'Aucun contenu',
    this.chrome = ZMarkdownReaderChrome.bordered,
    this.semanticsEnabled = true,
    super.key,
  });

  /// Valeur NEUTRE courante à rendre (Delta JSON `List<Map<String, dynamic>>`)
  /// ou valeur au format persisté du [codec]. `null`/vide ⇒ placeholder.
  final Object? value;

  /// `ZCodec` de normalisation de la valeur d'entrée (défaut `ZDeltaCodec`).
  final ZCodec? codec;

  /// Libellé de champ pour la sémantique (lecture d'écran).
  final String? label;

  /// Texte affiché quand le contenu est vide (AD-10).
  final String placeholder;

  /// Habillage du lecteur (CR-IFFD-73). Défaut [ZMarkdownReaderChrome.bordered]
  /// = rendu historique inchangé.
  final ZMarkdownReaderChrome chrome;

  /// Pose le nœud [Semantics] `readOnly` du lecteur (défaut `true` = historique).
  ///
  /// 🔴 **Pourquoi c'est débrayable, et mesuré.** Un appelant qui annonce
  /// DÉJÀ le contenu au-dessus — c'est le cas de `ZChatMessageTile`, qui pose
  /// un `Semantics` de message alimenté par `ZContentBlock.accessibleText` —
  /// ferait, sans ce drapeau, **deux** nœuds pour un seul contenu : le message
  /// annoncé une fois par la tuile, une seconde par le lecteur. Le
  /// coupe-circuit n'invente rien : il laisse l'annonce là où elle était déjà.
  final bool semanticsEnabled;

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
  /// ne prend jamais le focus clavier ni la traversée (AC1). Créé UNE FOIS.
  late final FocusNode _focus;

  /// Codec de normalisation de l'entrée (résolu UNE FOIS).
  late final ZCodec _codec;

  /// JSON canonique de la dernière valeur rendue — dédup de la ré-hydratation.
  late String _lastValueJson;

  @override
  void initState() {
    super.initState();
    _codec = widget.codec ?? const ZDeltaCodec();
    final ops = _codec.decode(widget.value);
    final document = DeltaNeutralOps.decodeDefensiveDocument(ops);
    // readOnly: true ⇒ le controller REJETTE toute mutation (AC1) ; aucun
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

  @override
  Widget build(BuildContext context) {
    final zTheme = ZcrudTheme.of(context);
    final borderColor =
        zTheme.fieldBorderColor ?? Theme.of(context).colorScheme.outline;

    // CR-IFFD-73 : `none` retire cadre ET padding — l'appelant habille.
    final bool chromeless = widget.chrome == ZMarkdownReaderChrome.none;
    final EdgeInsetsGeometry pad = chromeless
        ? EdgeInsetsDirectional.zero
        : zTheme.fieldPadding;

    final Widget content = _isEmpty
        ? Padding(
            padding: pad,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                widget.placeholder,
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
        : Padding(
            padding: pad,
            child: QuillEditor(
              controller: _quill,
              focusNode: _focus,
              scrollController: _scroll,
              config: QuillEditorConfig(
                // Non-scrollable : hauteur intrinsèque, l'hôte défile.
                scrollable: false,
                padding: EdgeInsetsDirectional.zero,
                // Autorise la sélection/copie (lecture) mais AUCUNE saisie
                // (controller readOnly). MÊMES embed builders qu'en édition.
                showCursor: false,
                embedBuilders: kZEmbedBuilders,
                // 🔴 CR-IFFD-73 (AD-10) : repli TOTAL. Sans lui, un type
                // d'embed inconnu — d'un hôte, d'une version future, ou né
                // d'une op corrompue — lève un `UnimplementedError` EN PLEIN
                // BUILD, donc irrattrapable : écran rouge, puis cascade de
                // `RenderErrorBox`. Mesuré sur `divider`.
                unknownEmbedBuilder: kZUnknownEmbedBuilder,
                // MIN-1 : styles de titres dérivés du thème (FR-26).
                customStyles: zQuillThemedStyles(context),
              ),
            ),
          );

    final Widget framed = chromeless
        ? content
        : DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.all(zTheme.radiusM),
            ),
            child: content,
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
