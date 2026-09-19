import 'package:flutter/widgets.dart';
import 'package:zcrud_session/zcrud_session.dart';

/// Active le cycle réponse, correction, choix du palier, confirmation.
/// La politique de file est optionnelle : sans elle, le SRS reste historique.
/// Ces options s'appliquent uniquement aux modes SRS `learn` et `spaced`.
/// Les autres modes les ignorent et conservent leur flux habituel.
class ZLearningSessionOptions {
  /// Configure le mode apprentissage et son chrome optionnel.
  const ZLearningSessionOptions({
    this.queuePolicy,
    this.feedbackBuilder,
    this.squareQualityButtons = true,
    this.showProgressBadge = false,
  });

  /// Politique de consommation et de réinsertion de la file SRS.
  final ZQueuePolicy? queuePolicy;

  /// Présentation injectée de la correction typée.
  final Widget Function(BuildContext, ZLearningFeedback)? feedbackBuilder;

  /// Paliers carrés avec aperçu d'intervalle.
  final bool squareQualityButtons;

  /// Affiche le compteur intégré, sauf si un compteur personnalisé est fourni.
  final bool showProgressBadge;
}
