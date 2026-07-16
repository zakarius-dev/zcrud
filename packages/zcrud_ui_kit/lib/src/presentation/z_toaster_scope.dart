/// Seam de substitution du toaster + helper `zToast` (AD-6, AD-15).
///
/// `ZToasterScope` est un `InheritedWidget` **local** (zéro dépendance manager)
/// permettant à une app de **substituer** son propre [ZToaster] (GetX,
/// `toastification`, …) **sans** que `zcrud_ui_kit` n'importe aucun tiers. Le
/// helper [zToast] est le point d'entrée « une ligne » pour les écrans : il
/// résout le toaster effectif et délègue.
library;

import 'package:flutter/widgets.dart';

import '../domain/z_toast_severity.dart';
import '../domain/z_toaster.dart';
import 'z_scaffold_messenger_toaster.dart';

/// Fournit un [ZToaster] aux descendants (seam de substitution, AD-6).
///
/// Monter `ZToasterScope(toaster: MonToaster(), child: ...)` fait résoudre
/// [zToast] / [of] sur ce toaster custom. **Sans** scope monté, [of] retombe
/// sur `const ZScaffoldMessengerToaster()` (défaut sûr — **jamais de throw**,
/// AD-10). Ce seam est **spécifique au toaster** ; il ne remplace pas
/// `ZcrudScope` (thème/labels).
class ZToasterScope extends InheritedWidget {
  /// Construit le scope avec le [toaster] à exposer aux descendants.
  const ZToasterScope({
    required this.toaster,
    required super.child,
    super.key,
  });

  /// Toaster exposé aux descendants.
  final ZToaster toaster;

  /// Lit le [ZToaster] du scope le plus proche, ou `null` si aucun n'est monté.
  static ZToaster? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ZToasterScope>()
        ?.toaster;
  }

  /// Résout le toaster effectif : celui du scope, sinon le **défaut sûr**
  /// `const ZScaffoldMessengerToaster()` (jamais de throw — AD-10).
  static ZToaster of(BuildContext context) {
    return maybeOf(context) ?? const ZScaffoldMessengerToaster();
  }

  @override
  bool updateShouldNotify(ZToasterScope oldWidget) {
    return oldWidget.toaster != toaster;
  }
}

/// Affiche un toast via le [ZToaster] résolu par [ZToasterScope.of].
///
/// Point d'entrée de convenance : résout le toaster effectif (custom via un
/// [ZToasterScope] monté, sinon [ZScaffoldMessengerToaster] par défaut) puis
/// délègue à `toaster.show(...)`. [severity] défaut [ZToastSeverity.info]
/// (défaut sûr, AD-10). N'importe **aucun** gestionnaire d'état (AD-2/AD-15).
void zToast(
  BuildContext context,
  String message, {
  ZToastSeverity severity = ZToastSeverity.info,
  Duration? duration,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  ZToasterScope.of(context).show(
    context,
    message: message,
    severity: severity,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}
