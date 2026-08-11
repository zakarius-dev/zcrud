/// Port de notification (toast), abstrait et **pluggable** (invariants AD-4, AD-6).
///
/// `ZToaster` abstrait l'affichage d'un toast pour qu'un paquet **pur** ne se
/// couple à aucun gestionnaire d'état ni tiers UI (GetX, `toastification`, …).
/// L'implémentation **par défaut** [ZScaffoldMessengerToaster] est fournie ici
/// (Flutter vanilla); les implémentations concrètes spécifiques à un manager
/// vivent dans les **bindings** (`zcrud_get`) ou sont fournies par
/// l'app via le seam [ZToasterScope].
library;

import 'package:flutter/widgets.dart';

import 'z_toast_severity.dart';

/// Contrat d'affichage d'un toast.
///
/// **`abstract interface class`** (jamais `sealed`, invariant AD-4) : une
/// app ou un binding peut l'implémenter **sans modifier** `zcrud_ui_kit`. La
/// sévérité est **toujours** un [ZToastSeverity] (jamais un `bool isError`
/// ni un `String` libre). Le port reçoit le [BuildContext] à l'appel (les
/// impls `ScaffoldMessenger` / GetX en ont besoin) : c'est un **port de
/// présentation**, il ne conserve **aucune** référence manager en champ.
abstract interface class ZToaster {
  /// Affiche un toast portant [message], qualifié par [severity].
  ///
  /// - [severity] : défaut [ZToastSeverity.info] (défaut sûr, invariant
  ///   AD-10).
  /// - [duration] : durée d'affichage optionnelle ; si `null`, l'impl
  ///   choisit un défaut sûr (ex. la durée par défaut de `SnackBar`).
  /// - [actionLabel] + [onAction] : action facultative (les deux requis
  ///   pour afficher une action).
  void show(
    BuildContext context, {
    required String message,
    ZToastSeverity severity = ZToastSeverity.info,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  });
}
