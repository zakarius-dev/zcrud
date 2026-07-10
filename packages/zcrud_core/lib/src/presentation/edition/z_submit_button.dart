/// Chrome de **soumission accessible** (E3-6, AC5/AC6/AC14) : un bouton scellé
/// sur l'état de soumission + une surface d'erreur accessible.
///
/// origine: la voie de soumission (E3-6) expose un `ValueListenable<ZSubmissionState>`
/// (AD-11, cœur agnostique manager — AD-15). Le bouton n'écoute QUE cet état
/// (SM-1 — AD-2) : une frappe ne le reconstruit jamais.
///
/// - `inProgress` ⇒ bouton **désactivé** (`onPressed: null`) + indicateur de
///   progression + `Semantics(enabled: false)` ; ré-entrance gardée par le
///   contrôleur (AC5).
/// - `failure` ⇒ `failure.message` rendu dans une surface d'erreur **accessible**
///   (`Semantics(liveRegion: true)`) ; bouton **réactivé** (nouvel essai — AC6).
///
/// a11y (AD-13) : cible ≥ 48 dp, insets **directionnels**, style dérivé du thème
/// (aucun littéral de couleur — FR-26).
library;

import 'package:flutter/material.dart';

import 'z_submission.dart';

/// Bouton de soumission + surface d'erreur, scellés sur [controller].state.
class ZSubmitButton<T> extends StatelessWidget {
  /// Construit le bouton pour [controller], avec le libellé [label]. [onDone]
  /// est notifié après une soumission (succès/échec) pour l'orchestration hôte.
  const ZSubmitButton({
    required this.controller,
    required this.label,
    this.onDone,
    super.key,
  });

  /// Contrôleur de soumission (source de l'état + action `submit`).
  final ZEditionSubmitController<T> controller;

  /// Libellé du bouton (clé l10n ou littéral — résolu côté hôte).
  final String label;

  /// Notifié avec l'issue après une soumission (optionnel).
  final ValueChanged<ZSubmissionOutcome<T>>? onDone;

  Future<void> _submit() async {
    final outcome = await controller.submit();
    onDone?.call(outcome);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZSubmissionState>(
      valueListenable: controller.state,
      builder: (context, state, _) {
        final inProgress = state.status == ZSubmissionStatus.inProgress;
        final failure = state.status == ZSubmissionStatus.failure
            ? state.failure
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (failure != null)
              Semantics(
                liveRegion: true,
                container: true,
                child: Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                  child: Text(
                    failure.message,
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
              child: Semantics(
                // État d'accessibilité explicite : désactivé pendant l'attente.
                enabled: !inProgress,
                button: true,
                label: label,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: FilledButton(
                    onPressed: inProgress ? null : _submit,
                    child: inProgress
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(label, textAlign: TextAlign.start),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
