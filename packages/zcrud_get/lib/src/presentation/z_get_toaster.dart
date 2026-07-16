/// Toaster **GetX** (EX-UI.11, AD-32/AD-13) — implémentation manager du port
/// [ZToaster] de `zcrud_ui_kit`.
///
/// [ZGetToaster] **transpose** le toaster par défaut pur-Flutter
/// `ZScaffoldMessengerToaster` à l'idiome GetX (`Get.snackbar`). C'est la
/// réécriture **neutralisée** du `ToastService` GetX historique (dodlp) :
/// * les 3 méthodes ad hoc `showErrorToast`/`showSuccessToast`/`showInfoToast`
///   + tout `bool isError` → l'`enum` [ZToastSeverity] (une seule méthode
///   [show], sévérité en paramètre — NFR-U7) ;
/// * toute couleur **hex** en dur → couleur **dérivée du `ColorScheme`** injecté
///   (jamais de littéral — AD-13/NFR-U5, dark-mode-aware).
///
/// **Sévérité perceptible SANS la couleur** : icône + texte (couleur **jamais**
/// seul canal — WCAG/AD-13/NFR-U4), table identique à `ZScaffoldMessengerToaster` :
///
/// | Sévérité | Fond (rôle `ColorScheme`) | Texte/icône | Icône |
/// |---|---|---|---|
/// | `info` | `scheme.primary` | `scheme.onPrimary` | `info_outline` |
/// | `success` | `scheme.tertiary` | `scheme.onTertiary` | `check_circle_outline` |
/// | `warning` | `scheme.secondary` | `scheme.onSecondary` | `warning_amber_outlined` |
/// | `error` | `ZcrudTheme.errorColor` → `scheme.error` | `scheme.onError` | `error_outline` |
///
/// **`get` confiné ici (AD-15)** : ce fichier importe `package:get/get.dart` —
/// légitime UNIQUEMENT dans le binding. `zcrud_ui_kit` (qui définit le port)
/// n'importe aucun tiers. Substitution au défaut via le seam **déjà fourni**
/// `ZToasterScope` (aucun nouveau seam).
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Toaster GetX : mappe une [ZToastSeverity] sur `Get.snackbar`. `const` — aucun
/// état (le [BuildContext] est reçu à l'appel). Substituable via [ZToasterScope].
class ZGetToaster implements ZToaster {
  /// Construit le toaster GetX (immuable — AD-13).
  const ZGetToaster();

  @override
  void show(
    BuildContext context, {
    required String message,
    ZToastSeverity severity = ZToastSeverity.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground, IconData icon) =
        _resolve(context, severity, scheme);

    final showAction = actionLabel != null && onAction != null;

    Get.snackbar(
      // Pas de titre métier en dur — le message est porté par `messageText`.
      '',
      message,
      // Sévérité perceptible SANS la couleur : icône + texte (jamais seul canal,
      // AD-13/NFR-U4). `Semantics(liveRegion:)` annonce le message (a11y).
      messageText: Semantics(
        container: true,
        liveRegion: true,
        label: message,
        child: ExcludeSemantics(
          child: Row(
            children: <Widget>[
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  // Directionnel (RTL-safe) — ⛔ jamais TextAlign.left/right.
                  textAlign: TextAlign.start,
                  style: TextStyle(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: background, // ⛔ jamais hex — dérivé du ColorScheme injecté
      colorText: foreground,
      duration: duration ?? const Duration(seconds: 4),
      // Action facultative : affichée SSI actionLabel != null && onAction != null.
      mainButton: showAction
          ? TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: TextStyle(color: foreground),
              ),
            )
          : null,
      // Cohérent avec la SnackBar Material par défaut (bas de l'écran).
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Résout `(fond, avant-plan lisible, icône)` pour une sévérité — couleur
  /// dérivée du `ColorScheme` (jamais hex). `switch` EXHAUSTIF sur les 4 valeurs
  /// (jamais de throw — AD-10). `error` réutilise l'idiome EX-UI.7
  /// `ZcrudTheme.of(context).errorColor ?? scheme.error`.
  (Color, Color, IconData) _resolve(
    BuildContext context,
    ZToastSeverity severity,
    ColorScheme scheme,
  ) {
    switch (severity) {
      case ZToastSeverity.info:
        return (scheme.primary, scheme.onPrimary, Icons.info_outline);
      case ZToastSeverity.success:
        return (
          scheme.tertiary,
          scheme.onTertiary,
          Icons.check_circle_outline,
        );
      case ZToastSeverity.warning:
        return (
          scheme.secondary,
          scheme.onSecondary,
          Icons.warning_amber_outlined,
        );
      case ZToastSeverity.error:
        final errorColor = ZcrudTheme.of(context).errorColor ?? scheme.error;
        return (errorColor, scheme.onError, Icons.error_outline);
    }
  }
}
