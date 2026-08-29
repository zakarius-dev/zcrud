/// Dialog de confirmation générique + helper (invariants AD-2, AD-13).
///
/// `ZConfirmDialog` factorise le dialogue de confirmation dark-mode-aware
/// (couleurs dérivées du `ColorScheme` courant, jamais `kSuccessColor*`/
/// `kErrorColor*`), labels par défaut via `MaterialLocalizations` (aucune
/// chaîne codée en dur), tonalité portée par [ZConfirmTone] (jamais un
/// `bool`), RTL-safe, cibles ≥ 48 dp, **sans aucun gestionnaire d'état**
/// (`showDialog` + `Navigator.pop`).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_confirm_tone.dart';

/// Cible tactile minimale (Material / AD-13) pour les actions du dialog.
const double _kMinTouchTarget = 48;

const Key _kNoTitleSemanticsKey = ValueKey<String>(
  'z_confirm_dialog_no_title_semantics',
);

/// Dialog de confirmation (`AlertDialog`) à thème injecté, dark-mode-aware.
///
/// Expose un titre optionnel, un message et deux actions (confirmer / annuler). La couleur
/// du bouton de confirmation est **dérivée** du `ColorScheme` courant selon
/// [tone] (`destructive` → `ColorScheme.error`; `neutral` → `ColorScheme.primary`)
/// — jamais un littéral hex. Les labels par défaut proviennent de
/// `MaterialLocalizations.of(context)` (jamais de chaîne « Confirmer »/« Annuler »
/// codée en dur). Confirmer → `Navigator.pop(context, true)`; annuler →
/// `Navigator.pop(context, false)`. Avec `title: null`, le titre est retiré
/// entièrement de l'arbre du `AlertDialog` : ce widget n'invente délibérément
/// aucun titre par défaut ou localisé.
///
/// ## Ce qui décide du pixel
///
/// Forme, styles du titre et du message, retrait des actions et couleur de
/// l'action destructive viennent de `ZConfirmDialogStyle.resolve(context)`,
/// donc des jetons `confirmDialog*` de `ZcrudTheme`. Ces jetons sont
/// **transportés `null`** jusqu'à `AlertDialog` : un `null` n'est pas une
/// absence de style, c'est l'instruction « suis le `DialogTheme` ambiant, puis
/// le défaut Material ». Sans aucun jeton posé, le dialogue est donc au pixel
/// près celui d'un `AlertDialog` nu.
///
/// [ZConfirmTone.destructive] fait exception : la couleur destructive est
/// **toujours résolue**, parce qu'aucun composant Material n'en porte. À
/// défaut de jeton, elle vaut `ColorScheme.error`.
///
/// ## Le style se résout chez l'appelant
///
/// Une route de dialogue est poussée sur le `Navigator`, **hors** du sous-arbre
/// de l'écran : elle hérite du `Theme` (capturé par `showDialog`) mais **pas**
/// d'un `InheritedWidget` ordinaire comme `ZcrudScope`. Des jetons posés par
/// `ZcrudScope(theme:)` seraient donc invisibles depuis le dialogue. C'est
/// pourquoi [style] existe : [showZConfirmDialog] résout le style **au point
/// d'appel**, dans le contexte de l'écran, et le transporte. Utilisé
/// directement dans un arbre (`showDialog` fait maison, ou dialogue embarqué),
/// ce widget résout lui-même depuis son propre contexte.
///
/// ## Créneaux
///
/// [icon] alimente l'`icon:` de l'`AlertDialog` (au-dessus du titre).
/// [content] **remplace** le rendu visuel du [message] — qui reste requis et
/// reste le libellé sémantique du dialogue sans titre : une confirmation dont
/// la question ne vit que dans un widget graphique serait muette au lecteur
/// d'écran.
///
/// Généralement affiché via [showZConfirmDialog], mais utilisable directement
/// avec `showDialog<bool>`.
class ZConfirmDialog extends StatelessWidget {
  /// Construit le dialog. [message] est requis; les labels et la [tone] ont des
  /// défauts sûrs (l10n Flutter + `neutral`). `title: null` retire entièrement
  /// le titre de l'arbre du `AlertDialog`, sans titre par défaut ou localisé
  /// inventé par ce widget.
  const ZConfirmDialog({
    this.title,
    required this.message,
    this.content,
    this.icon,
    this.confirmLabel,
    this.cancelLabel,
    this.tone = ZConfirmTone.neutral,
    this.style,
    super.key,
  });

  /// Titre optionnel du dialog.
  final String? title;

  /// Message / question de confirmation. Toujours requis : même remplacé
  /// visuellement par [content], il reste le canal sémantique du dialogue.
  final String message;

  /// Corps **remplaçant** le rendu du [message], ou `null` pour le rendu
  /// texte par défaut.
  final Widget? content;

  /// Icône optionnelle affichée au-dessus du titre par `AlertDialog`.
  final Widget? icon;

  /// Libellé du bouton de confirmation (défaut: `okButtonLabel`).
  final String? confirmLabel;

  /// Libellé du bouton d'annulation (défaut: `cancelButtonLabel`).
  final String? cancelLabel;

  /// Tonalité de la confirmation (défaut: [ZConfirmTone.neutral]).
  ///
  /// `destructive` colore l'action de confirmation avec le jeton
  /// `confirmDialogDestructiveColor`, à défaut `ColorScheme.error`.
  final ZConfirmTone tone;

  /// Style résolu **à la place** de ce widget, ou `null` pour le résoudre
  /// depuis son propre contexte. Sert à transporter les jetons de l'écran
  /// jusqu'à une route de dialogue, qui n'en hérite pas.
  final ZConfirmDialogStyle? style;

  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ZConfirmDialogStyle resolved =
        style ?? ZConfirmDialogStyle.resolve(context);
    // Couleur du bouton de confirmation dérivée du ColorScheme selon la tonalité.
    final confirmColor = switch (tone) {
      ZConfirmTone.neutral => scheme.primary,
      ZConfirmTone.destructive => resolved.destructiveColor,
    };
    // Premier plan de l'action destructive. Tant que la teinte destructive EST
    // `ColorScheme.error`, `onError` reste rendu tel quel : c'est le rôle que
    // Material lui a apparié, et le recalculer ferait bouger un rendu que
    // personne n'a demandé de changer. Dès qu'un jeton impose une AUTRE teinte,
    // `onError` n'a plus aucune raison de contraster avec elle — il est alors
    // remonté au plancher de lisibilité des objets non textuels.
    final Color onConfirmColor = switch (tone) {
      ZConfirmTone.neutral => scheme.onPrimary,
      ZConfirmTone.destructive =>
        resolved.destructiveColor == scheme.error
            ? scheme.onError
            : zReadableTintOn(
                scheme.onError,
                surface: resolved.destructiveColor,
              ),
    };
    final resolvedConfirm = confirmLabel ?? materialL10n.okButtonLabel;
    final resolvedCancel = cancelLabel ?? materialL10n.cancelButtonLabel;

    final dialog = AlertDialog(
      icon: icon,
      shape: resolved.shape,
      titleTextStyle: resolved.titleStyle,
      contentTextStyle: resolved.contentStyle,
      actionsPadding: resolved.actionsPadding,
      title: title == null ? null : Text(title!),
      content: content ?? Text(message),
      // `actions` disposées par le framework de façon directionnelle (RTL-safe).
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(_kMinTouchTarget, _kMinTouchTarget),
          ),
          onPressed: () => Navigator.pop(context, false),
          child: Text(resolvedCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(_kMinTouchTarget, _kMinTouchTarget),
            backgroundColor: confirmColor,
            foregroundColor: onConfirmColor,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(resolvedConfirm),
        ),
      ],
    );

    if (title != null) {
      return dialog;
    }

    return Semantics(
      key: _kNoTitleSemanticsKey,
      label: message,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      child: dialog,
    );
  }
}

/// Affiche un [ZConfirmDialog] et retourne la décision de l'utilisateur.
///
/// Retourne `true` si l'utilisateur confirme, `false` s'il annule **ou** ferme le
/// dialog par le barrier / un pop sans valeur (`showDialog<bool>(...) ?? false` —
/// défaut sûr AD-10, jamais de throw). N'utilise **aucun** gestionnaire d'état:
/// uniquement `showDialog` + `Navigator.pop` (invariant AD-2).
///
/// Avec `title: null`, le titre est retiré entièrement de l'arbre du
/// `AlertDialog`; cette fonction n'invente délibérément aucun titre par défaut
/// ou localisé.
///
/// [icon] et [content] sont les créneaux de [ZConfirmDialog] : une icône
/// au-dessus du titre, et un corps qui remplace le rendu du [message]. Le
/// style vient des jetons `confirmDialog*` de `ZcrudTheme` — aucun jeton posé,
/// aucun changement de rendu.
///
/// [barrierDismissible] à `false` interdit la fermeture par le voile ; le
/// résultat reste `false` pour toute sortie qui n'est pas une confirmation
/// explicite (repli sûr AD-10).
Future<bool> showZConfirmDialog(
  BuildContext context, {
  String? title,
  required String message,
  Widget? content,
  Widget? icon,
  String? confirmLabel,
  String? cancelLabel,
  ZConfirmTone tone = ZConfirmTone.neutral,
  bool barrierDismissible = true,
}) async {
  // Résolu ICI, dans le contexte de l'écran : la route du dialogue n'hérite
  // pas des `InheritedWidget` ordinaires de l'appelant (`ZcrudScope`), et des
  // jetons posés par scope y seraient invisibles.
  final ZConfirmDialogStyle style = ZConfirmDialogStyle.resolve(context);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => ZConfirmDialog(
      style: style,
      title: title,
      message: message,
      content: content,
      icon: icon,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      tone: tone,
    ),
  );
  return result ?? false;
}
