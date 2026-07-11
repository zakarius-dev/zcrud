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

    final Widget content = _isEmpty
        ? Padding(
            padding: zTheme.fieldPadding,
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
            padding: zTheme.fieldPadding,
            child: QuillEditor(
              controller: _quill,
              focusNode: _focus,
              scrollController: _scroll,
              config: const QuillEditorConfig(
                // Non-scrollable : hauteur intrinsèque, l'hôte défile.
                scrollable: false,
                padding: EdgeInsetsDirectional.zero,
                // Autorise la sélection/copie (lecture) mais AUCUNE saisie
                // (controller readOnly). MÊMES embed builders qu'en édition.
                showCursor: false,
                embedBuilders: kZEmbedBuilders,
              ),
            ),
          );

    final reader = Semantics(
      // Lisible au lecteur d'écran (contenu exposé) mais SANS action d'édition
      // (readOnly=true ⇒ pas de champ éditable annoncé). AD-13.
      label: widget.label,
      readOnly: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.all(zTheme.radiusM),
        ),
        child: content,
      ),
    );

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
