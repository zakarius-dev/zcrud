/// Helper de **slice réactif** : un widget de champ qui n'écoute QUE sa tranche
/// (AD-2). Fige le pattern que E3 (`DynamicEdition`) industrialisera.
library;

import 'package:flutter/widgets.dart';

import 'z_form_controller.dart';

/// Fin wrapper de [ValueListenableBuilder] branché sur la tranche
/// `controller.fieldListenable(name)`.
///
/// Garantit que **seul** ce sous-arbre reconstruit lorsque la tranche [name]
/// change (rebuild ciblé, cœur de SM-1). Usage E3 :
/// - poser un `key: ValueKey(name)` sur le widget de champ pour une place stable
///   (les champs conditionnels d'E3-4 ne doivent pas voler l'état d'un voisin) ;
/// - NE PAS construire les champs dans une closure locale du `build()` parent —
///   ce widget est la frontière de rebuild ;
/// - le [ZFormController] DÉTIENT la valeur ; ne jamais ré-injecter dans un
///   `TextEditingController` (`.text=`) — la stabilité du controller de texte
///   relève d'E3-2.
class ZFieldListenableBuilder extends StatelessWidget {
  /// Construit le slice réactif pour le champ [name] du [controller].
  const ZFieldListenableBuilder({
    required this.controller,
    required this.name,
    required this.builder,
    this.child,
    super.key,
  });

  /// Contrôleur de formulaire détenant la tranche.
  final ZFormController controller;

  /// Nom du champ dont la tranche est écoutée.
  final String name;

  /// Constructeur du sous-arbre, invoqué à chaque changement de la tranche.
  final ValueWidgetBuilder<Object?> builder;

  /// Sous-arbre optionnel stable, passé tel quel au [builder] (perf).
  final Widget? child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Object?>(
        valueListenable: controller.fieldListenable(name),
        builder: builder,
        child: child,
      );
}
