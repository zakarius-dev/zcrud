/// Garde anti-perte de saisie (`PopScope`) liée au *dirty* d'un
/// `ZFormController` (EX-UI.9, AD-32/AD-2/AD-25/AD-13).
///
/// [ZDiscardChangesGuard] neutralise le `DiscardChangesGuard` de lex
/// (`ConsumerWidget` + `WidgetRef` **morts**, `AlertDialog` inline dupliqué,
/// `bool Function()` non réactif, labels codés en dur) :
/// * **`StatelessWidget` pur** — AUCUN gestionnaire d'état importé
///   (ni `flutter_riverpod`, ni `get`, ni `provider`), le type `ValueListenable`
///   provenant de `package:flutter/foundation.dart` (via `material.dart`) ;
/// * l'état *dirty* est **consommé en lecture seule** via un
///   `ValueListenable<bool>` — canoniquement `ZFormController.isDirty`
///   (`zcrud_core`) — le garde n'a **aucune** poignée de mutation du contrôleur ;
/// * la confirmation réutilise `showZConfirmDialog` (EX-UI.7, `ZConfirmTone`),
///   jamais un `AlertDialog` réinventé ;
/// * rebuild **ciblé** (SM-1) : seul le `PopScope` est reconstruit au flip
///   *dirty*, le sous-arbre protégé (`child`) est passé au `child` du
///   `ValueListenableBuilder` et n'est **jamais** reconstruit.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../domain/z_confirm_tone.dart';
import 'z_confirm_dialog.dart';

/// Intercepte toute tentative de sortie tant que [isDirty] est `true` et propose
/// une confirmation (via [showZConfirmDialog]) avant de perdre la saisie.
///
/// Source *dirty* **canonique** : `ZFormController.isDirty` de `zcrud_core`
/// (`ValueListenable<bool>` — canal dédié qui ne notifie ni les tranches de
/// champ ni le `notifyListeners()` global, garantissant un rebuild granulaire).
/// L'appelant passe `controller.isDirty` : le contact avec le cœur est
/// **strictement en lecture** (aucune mutation, aucun import `zcrud_core`
/// requis ici).
///
/// [isDirty] est le **seul `bool`** de cette API (prédicat strictement binaire —
/// exception NFR-U7 documentée par l'epic EX-UI.9). Le résultat de la
/// confirmation (discard / annuler) reste également binaire ; la tonalité passe
/// par l'enum [ZConfirmTone].
///
/// Comportement ([PopScope]) :
/// * **propre** (`isDirty.value == false`) → `canPop == true` : le framework
///   pop directement, **aucun** dialog, [onDiscard] **non** appelé ;
/// * **sale** (`isDirty.value == true`) → `canPop == false` : la sortie est
///   bloquée puis [showZConfirmDialog] (`tone: destructive`) est affiché ;
///   confirmer → [onDiscard] puis `Navigator.pop` ; annuler / barrier → on
///   **reste** (défaut sûr, `?? false` interne, jamais de throw — AD-10).
class ZDiscardChangesGuard extends StatelessWidget {
  /// Construit le garde. [isDirty] et [child] sont requis ; les labels et
  /// [onDiscard] sont optionnels (replis sûrs / no-op).
  const ZDiscardChangesGuard({
    required this.isDirty,
    required this.child,
    this.title,
    this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.onDiscard,
    super.key,
  });

  /// Titre de repli **neutre** (générique, surchargeable via [title]) — jamais
  /// une chaîne métier spécifique à une application (AD-13/NFR-U5).
  static const String defaultTitle = 'Discard changes?';

  /// Message de repli **neutre** (générique, surchargeable via [message]).
  static const String defaultMessage =
      'You have unsaved changes. Discard them?';

  /// État *dirty* consommé en **lecture seule** — canoniquement
  /// `ZFormController.isDirty` (`zcrud_core`).
  final ValueListenable<bool> isDirty;

  /// Sous-arbre protégé. **Non reconstruit** au flip *dirty* (SM-1) : il est
  /// passé au `child` du [ValueListenableBuilder].
  final Widget child;

  /// Titre du dialog (défaut : [defaultTitle]).
  final String? title;

  /// Message du dialog (défaut : [defaultMessage]).
  final String? message;

  /// Libellé du bouton de confirmation (défaut : `MaterialLocalizations`).
  final String? confirmLabel;

  /// Libellé du bouton d'annulation (défaut : `MaterialLocalizations`).
  final String? cancelLabel;

  /// Callback optionnel invoqué **juste avant** le pop effectif (discard
  /// confirmé) — ex. `controller.reset()`. Jamais appelé sur une sortie propre.
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDirty,
      // `child` passé par le paramètre → NON reconstruit au flip dirty (SM-1).
      child: child,
      builder: (context, dirty, child) {
        return PopScope<Object?>(
          canPop: !dirty,
          onPopInvokedWithResult: (didPop, result) =>
              _onPopInvoked(context, didPop, result),
          child: child!,
        );
      },
    );
  }

  /// Gère l'interception : si déjà sorti (cas propre) → no-op ; sinon confirme
  /// puis pop si l'utilisateur accepte de perdre la saisie.
  Future<void> _onPopInvoked(
    BuildContext context,
    bool didPop,
    Object? result,
  ) async {
    if (didPop) return;
    // Capturer le Navigator AVANT l'await (use_build_context_synchronously).
    final navigator = Navigator.of(context);
    final shouldDiscard = await showZConfirmDialog(
      context,
      title: title ?? defaultTitle,
      message: message ?? defaultMessage,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      tone: ZConfirmTone.destructive,
    );
    if (!shouldDiscard) return;
    onDiscard?.call();
    if (navigator.mounted) navigator.pop(result);
  }
}
