/// Dialog de confirmation générique + helper (AD-32, AD-13, AD-2).
///
/// `ZConfirmDialog` neutralise les `buildConfirmDialog` dupliqués (dodlp
/// `forms_utils.dart:271`, iffd `forms_utils.dart:455`) : dark-mode-aware
/// (couleurs dérivées du `ColorScheme` courant, jamais `kSuccessColor*`/
/// `kErrorColor*`), labels par défaut via `MaterialLocalizations` (aucune chaîne
/// codée en dur), tonalité portée par [ZConfirmTone] (jamais un `bool`), RTL-safe,
/// cibles ≥ 48 dp, **sans aucun gestionnaire d'état** (`showDialog` + `Navigator.pop`).
library;

import 'package:flutter/material.dart';

import '../domain/z_confirm_tone.dart';

/// Cible tactile minimale (Material / AD-13) pour les actions du dialog.
const double _kMinTouchTarget = 48;

/// Dialog de confirmation (`AlertDialog`) à thème injecté, dark-mode-aware.
///
/// Expose un titre, un message et deux actions (confirmer / annuler). La couleur
/// du bouton de confirmation est **dérivée** du `ColorScheme` courant selon
/// [tone] (`destructive` → `ColorScheme.error` ; `neutral` → `ColorScheme.primary`)
/// — jamais un littéral hex. Les labels par défaut proviennent de
/// `MaterialLocalizations.of(context)` (jamais de chaîne « Confirmer »/« Annuler »
/// codée en dur). Confirmer → `Navigator.pop(context, true)` ; annuler →
/// `Navigator.pop(context, false)`.
///
/// Généralement affiché via [showZConfirmDialog], mais utilisable directement
/// avec `showDialog<bool>`.
class ZConfirmDialog extends StatelessWidget {
  /// Construit le dialog. [title] et [message] sont requis ; les labels et la
  /// [tone] ont des défauts sûrs (l10n Flutter + `neutral`).
  const ZConfirmDialog({
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.tone = ZConfirmTone.neutral,
    super.key,
  });

  /// Titre du dialog.
  final String title;

  /// Message / question de confirmation.
  final String message;

  /// Libellé du bouton de confirmation (défaut : `okButtonLabel`).
  final String? confirmLabel;

  /// Libellé du bouton d'annulation (défaut : `cancelButtonLabel`).
  final String? cancelLabel;

  /// Tonalité de la confirmation (défaut : [ZConfirmTone.neutral]).
  final ZConfirmTone tone;

  @override
  Widget build(BuildContext context) {
    final materialL10n = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // Couleur du bouton de confirmation dérivée du ColorScheme selon la tonalité.
    final confirmColor = switch (tone) {
      ZConfirmTone.neutral => scheme.primary,
      ZConfirmTone.destructive => scheme.error,
    };
    final resolvedConfirm = confirmLabel ?? materialL10n.okButtonLabel;
    final resolvedCancel = cancelLabel ?? materialL10n.cancelButtonLabel;

    return AlertDialog(
      title: Text(title),
      content: Text(message),
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
            foregroundColor: switch (tone) {
              ZConfirmTone.neutral => scheme.onPrimary,
              ZConfirmTone.destructive => scheme.onError,
            },
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(resolvedConfirm),
        ),
      ],
    );
  }
}

/// Affiche un [ZConfirmDialog] et retourne la décision de l'utilisateur.
///
/// Retourne `true` si l'utilisateur confirme, `false` s'il annule **ou** ferme le
/// dialog par le barrier / un pop sans valeur (`showDialog<bool>(...) ?? false` —
/// défaut sûr AD-10, jamais de throw). N'utilise **aucun** gestionnaire d'état :
/// uniquement `showDialog` + `Navigator.pop` (AD-2/NFR-U2).
Future<bool> showZConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  ZConfirmTone tone = ZConfirmTone.neutral,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ZConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      tone: tone,
    ),
  );
  return result ?? false;
}
