/// Implémentation par défaut du port [ZToaster] — pur-Flutter (AD-32, AD-2, AD-13).
///
/// `ZScaffoldMessengerToaster` affiche une `SnackBar` via
/// `ScaffoldMessenger.of(context).showSnackBar` — **Flutter vanilla, AUCUN
/// gestionnaire d'état** (pas de `Get.showSnackbar`). C'est l'impl retenue par
/// défaut quand aucun toaster custom n'est fourni via [ZToasterScope].
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_toast_severity.dart';
import '../domain/z_toaster.dart';

/// Toaster par défaut : mappe une [ZToastSeverity] sur une `SnackBar` colorée.
///
/// **Couleur toujours dérivée du `ColorScheme` courant, JAMAIS de hex**
/// (dark-mode-aware — s'adapte au `Brightness`) :
///
/// | Sévérité | Fond (rôle `ColorScheme`) | Texte/icône | Icône |
/// |---|---|---|---|
/// | `error` | `ZcrudTheme.errorColor` → `scheme.error` | `scheme.onError` | `error_outline` |
/// | `info` | `scheme.primary` | `scheme.onPrimary` | `info_outline` |
/// | `success` | `scheme.tertiary` | `scheme.onTertiary` | `check_circle_outline` |
/// | `warning` | `scheme.secondary` | `scheme.onSecondary` | `warning_amber_outlined` |
///
/// `ZcrudTheme`/M3 n'exposent pas de slot `success`/`warning`/`info` : le mapping
/// **dérive** ces sévérités de rôles `ColorScheme` **existants** (déterministe,
/// documenté) — aucun littéral introduit. La sévérité est portée par **une icône
/// + le texte** (couleur **jamais** seul canal — WCAG/AD-13/NFR-U4).
class ZScaffoldMessengerToaster implements ZToaster {
  /// Construit le toaster par défaut (immuable — AD-13).
  const ZScaffoldMessengerToaster();

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

    final snackBar = SnackBar(
      backgroundColor: background,
      duration: duration ?? const Duration(seconds: 4),
      // Sévérité perceptible SANS la couleur : icône + texte (jamais seul canal).
      // `Semantics` container (liveRegion) annonce le message une seule fois ;
      // les nœuds visuels sont exclus pour éviter la double annonce (a11y AD-13).
      content: Semantics(
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
                  textAlign: TextAlign.start,
                  style: TextStyle(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
      action: showAction
          ? SnackBarAction(
              label: actionLabel,
              textColor: foreground,
              onPressed: onAction,
            )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Résout `(fond, avant-plan lisible, icône)` pour une sévérité — couleur
  /// dérivée du `ColorScheme` (jamais hex). `error` réutilise l'idiome EX-UI.7
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
        final errorColor =
            ZcrudTheme.of(context).errorColor ?? scheme.error;
        return (errorColor, scheme.onError, Icons.error_outline);
    }
  }
}
