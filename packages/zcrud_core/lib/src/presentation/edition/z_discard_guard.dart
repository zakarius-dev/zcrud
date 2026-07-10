/// Confirmation d'**abandon** d'un formulaire *dirty* (E3-6, AC9).
///
/// origine: fermer un formulaire modifié sans confirmation perd des données.
/// [ZDiscardGuard] est une enveloppe **de type `PopScope`** (primitive Flutter
/// native — AUCUNE dépendance au routing de l'app / `go_router`, AD-13) : tant
/// que le formulaire est *dirty* (`controller.isDirty`), le pop est intercepté
/// et délégué à un **seam** app `onConfirmDiscard` (dialogue fourni par l'app).
///
/// - Non-dirty ⇒ `canPop = true` ⇒ pop immédiat, seam **jamais** appelé.
/// - Dirty ⇒ `canPop = false` ⇒ `onPopInvoked` appelle le seam ; `true` ⇒ pop
///   effectif (`Navigator.pop`), `false` ⇒ pas de pop.
/// - Seam absent ⇒ pop autorisé (on ne peut pas demander confirmation).
///
/// N'observe QUE `controller.isDirty` (canal dédié — SM-1) : une frappe ne le
/// reconstruit pas (le booléen ne bascule qu'au flip, AC8).
library;

import 'package:flutter/widgets.dart';

import '../z_form_controller.dart';

/// Seam de confirmation d'abandon : retourne `true` pour autoriser le pop.
/// Fourni par l'app (dialogue). `null` ⇒ pas de confirmation (pop autorisé).
typedef ZConfirmDiscard = Future<bool> Function();

/// Enveloppe `PopScope`-like conditionnant la fermeture d'un formulaire *dirty*.
class ZDiscardGuard extends StatelessWidget {
  /// Construit le garde autour de [child], lisant l'état *dirty* de [controller]
  /// et déléguant la confirmation à [onConfirmDiscard] (seam app).
  const ZDiscardGuard({
    required this.controller,
    required this.child,
    this.onConfirmDiscard,
    super.key,
  });

  /// Contrôleur détenant l'état *dirty* (`controller.isDirty`).
  final ZFormController controller;

  /// Seam de confirmation (dialogue app). `null` ⇒ pop autorisé sans question.
  final ZConfirmDiscard? onConfirmDiscard;

  /// Sous-arbre protégé (le formulaire).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // N'écoute QUE le canal dirty dédié (SM-1) : rebuild seulement au flip.
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isDirty,
      builder: (context, dirty, _) {
        return PopScope<Object?>(
          canPop: !dirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return; // pop déjà autorisé (non-dirty).
            final navigator = Navigator.of(context);
            final confirmed = await _confirm();
            if (confirmed && navigator.mounted) {
              navigator.pop(result);
            }
          },
          child: child,
        );
      },
    );
  }

  Future<bool> _confirm() async {
    final seam = onConfirmDiscard;
    if (seam == null) return true; // pas de confirmation possible ⇒ autorise.
    return seam();
  }
}
