import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'reference_form.dart';

/// Variante STEPPER de la démo d'édition (EX-1, AC5-d). [ZStepperEdition]
/// partitionne le MÊME formulaire de référence en étapes séquencées sur un
/// unique `ZFormController` stable (état préservé en va-et-vient, validation
/// par étape).
class EditionStepperDemo extends StatefulWidget {
  /// Construit l'écran stepper.
  const EditionStepperDemo({super.key});

  @override
  State<EditionStepperDemo> createState() => _EditionStepperDemoState();
}

class _EditionStepperDemoState extends State<EditionStepperDemo> {
  late final ZFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ZFormController(initialValues: ReferenceForm.initialValues());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Démo Édition — Stepper')),
      body: ZStepperEdition(
        controller: _controller,
        fields: ReferenceForm.fields,
        steps: ReferenceForm.steps,
        layout: ReferenceForm.layout,
        padding: const EdgeInsetsDirectional.all(12),
        previousLabel: 'Précédent',
        nextLabel: 'Suivant',
        finishLabel: 'Terminer',
        onComplete: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assistant terminé.')),
          );
        },
      ),
    );
  }
}
