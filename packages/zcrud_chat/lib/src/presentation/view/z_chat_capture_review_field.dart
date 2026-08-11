/// Surface de relecture d'une capture — dictée ou reconnaissance de texte.
///
/// Un champ éditable pré-rempli, un geste d'annulation, un geste
/// d'insertion : les deux origines de capture (dictée, reconnaissance de
/// texte) partagent une seule surface plutôt que deux copies presque
/// identiques qui ne diffèrent que par l'icône et le titre — deux surfaces
/// jumelles finissent toujours par diverger.
///
/// ## Pourquoi ce widget existe, structurellement
///
/// Ce n'est pas un confort d'affichage : c'est la seule chose du socle qui
/// observe le tampon de relecture. `ZChatCaptureController.acceptInto`
/// refuse d'insérer quand rien n'observe le tampon — donc sans surface de
/// relecture montée, une capture ne peut pas atteindre le composer, et a
/// fortiori pas l'envoi.
///
/// ## Le `TextEditingController` est stable
///
/// Il est créé une fois et disposé une fois. Le recréer au rebuild est
/// l'interdit le plus visible de l'invariant AD-2 — perte de focus, curseur
/// qui saute — et c'est précisément ce qu'on ne peut pas se permettre sur une
/// surface dont la raison d'être est la correction.
///
/// ## Pourquoi [ZChatCaptureReviewField.cursorColor] est requise
///
/// `EditableText` exige une couleur de curseur non nulle, et ce paquet n'a le
/// droit d'en inventer aucune : le socle ne tranche jamais un choix de
/// couleur à la place de l'hôte. Entre inventer une couleur et la demander en
/// paramètre, ce paquet demande — c'est un paramètre de plus à l'appel, pas
/// une décision de design prise à la place du consommateur.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../capture/z_chat_capture_controller.dart';
import '../z_chat_controller.dart';
import 'z_chat_capture_bar.dart' show ZChatCaptureAction;
import 'z_chat_labels.dart';

/// Rend le brouillon de capture, **éditable**, avec ses deux issues.
class ZChatCaptureReviewField extends StatefulWidget {
  /// Construit la surface de relecture.
  const ZChatCaptureReviewField({
    required this.capture,
    required this.chat,
    required this.cursorColor,
    this.maxLines = 5,
    this.minLines = 2,
    super.key,
  });

  /// Le contrôleur de capture observé — ni créé ni disposé ici.
  final ZChatCaptureController capture;

  /// Le contrôleur de conversation dont le composer recevra le texte relu.
  final ZChatController chat;

  /// Couleur du curseur — fournie par l'hôte (cf. l'en-tête).
  final Color cursorColor;

  /// Hauteur maximale du champ, en lignes.
  final int maxLines;

  /// Hauteur minimale du champ, en lignes.
  final int minLines;

  @override
  State<ZChatCaptureReviewField> createState() =>
      _ZChatCaptureReviewFieldState();
}

class _ZChatCaptureReviewFieldState extends State<ZChatCaptureReviewField> {
  /// Créés une fois — jamais au rebuild (invariant AD-2).
  final TextEditingController _field = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // C'est cet abonnement qui rend le tampon « observé » : sans surface de
    // relecture montée, `acceptInto` refuse.
    widget.capture.review.addListener(_pullFromBuffer);
    _field.addListener(_pushToBuffer);
    _pullFromBuffer();
  }

  @override
  void dispose() {
    widget.capture.review.removeListener(_pullFromBuffer);
    _field.removeListener(_pushToBuffer);
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Le tampon a changé (une capture s'y est déposée) ⇒ refléter dans le champ.
  void _pullFromBuffer() {
    final String next = widget.capture.review.value;
    // Égalité d'abord : sans elle, les deux abonnements se relanceraient l'un
    // l'autre indéfiniment — et une ré-injection de valeur écraserait la
    // sélection de l'utilisateur en pleine correction (invariant AD-2).
    if (_field.text == next) return;
    _field.text = next;
    _field.selection = _field.selection.copyWith(
      baseOffset: next.length,
      extentOffset: next.length,
    );
  }

  /// L'utilisateur corrige ⇒ le tampon suit.
  void _pushToBuffer() {
    if (widget.capture.review.value == _field.text) return;
    widget.capture.review.edit(_field.text);
  }

  /// Le geste d'insertion ne rend rien à l'appelant : il passe par
  /// `acceptInto`, dont le résultat est `ZResult<Unit>`. Aucune `String` ne
  /// transite par cette couche.
  void _accept() => widget.capture.acceptInto(widget.chat);

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: widget.capture.hasPendingReview,
      builder: (BuildContext context, bool pending, Widget? child) {
        // Rien à relire ⇒ la surface disparaît (elle ne réserve pas de place
        // pour rien dans un composer déjà à l'étroit). L'abonnement au tampon,
        // lui, SURVIT : il vit dans le `State`, pas dans le sous-arbre.
        if (!pending) return const SizedBox.shrink();
        return Semantics(
          container: true,
          label: zChatLabel(context, kZChatLabelReviewCapture),
          child: Padding(
            padding: theme.formPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                EditableText(
                  controller: _field,
                  focusNode: _focus,
                  // Invariant AD-13 : jamais `TextAlign.left`.
                  textAlign: TextAlign.start,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  style: DefaultTextStyle.of(context).style,
                  cursorColor: widget.cursorColor,
                  backgroundCursorColor: widget.cursorColor,
                ),
                SizedBox(height: theme.gapS),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ZChatCaptureAction(
                      label: zChatLabel(context, kZChatLabelCancelCapture),
                      onTap: widget.capture.cancelReview,
                    ),
                    SizedBox(width: theme.gapS),
                    ZChatCaptureAction(
                      label: zChatLabel(context, kZChatLabelAcceptCapture),
                      onTap: _accept,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
