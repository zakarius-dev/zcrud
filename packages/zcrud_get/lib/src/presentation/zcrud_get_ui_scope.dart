/// Helper de câblage « une ligne » des surfaces UI GetX (EX-UI.11, AD-6/AD-15).
///
/// [ZcrudGetUiScope] monte d'un coup les **deux seams déjà fournis** par les
/// paquets UI purs — `ZFormPresenterScope` (de `zcrud_navigation`) et
/// `ZToasterScope` (de `zcrud_ui_kit`) — pour substituer aux défauts pur-Flutter
/// (`ZAdaptivePresenter`/`ZScaffoldMessengerToaster`) les implémentations GetX
/// ([ZGetFormPresenter]/[ZGetToaster]). Une app GetX câble ainsi son présentateur
/// + toaster natifs derrière les ports zcrud en enveloppant son arbre :
///
/// ```dart
/// GetMaterialApp(
///   home: const ZcrudGetUiScope(child: MonEcran()),
/// );
/// ```
///
/// ⛔ **Ne crée aucun seam concurrent** et **ne modifie pas** `ZcrudScope` du
/// cœur (D8/`CORE OUT=0`) : il ne fait qu'**imbriquer** les `InheritedWidget`
/// existants. Les défauts des paramètres sont `const` (aucun état).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

import 'z_get_form_presenter.dart';
import 'z_get_toaster.dart';

/// Monte `ZFormPresenterScope` + `ZToasterScope` (imbriqués) au-dessus de
/// [child], substituant les défauts pur-Flutter par les surfaces GetX.
class ZcrudGetUiScope extends StatelessWidget {
  /// Construit le scope de câblage UI GetX.
  ///
  /// [presenter] : présentateur effectif (défaut [ZGetFormPresenter]).
  /// [toaster] : toaster effectif (défaut [ZGetToaster]).
  const ZcrudGetUiScope({
    required this.child,
    this.presenter = const ZGetFormPresenter(),
    this.toaster = const ZGetToaster(),
    super.key,
  });

  /// Sous-arbre applicatif placé sous les 2 seams.
  final Widget child;

  /// Présentateur injecté dans `ZFormPresenterScope` (défaut GetX).
  final ZFormPresenter presenter;

  /// Toaster injecté dans `ZToasterScope` (défaut GetX).
  final ZToaster toaster;

  @override
  Widget build(BuildContext context) {
    return ZFormPresenterScope(
      presenter: presenter,
      child: ZToasterScope(
        toaster: toaster,
        child: child,
      ),
    );
  }
}
