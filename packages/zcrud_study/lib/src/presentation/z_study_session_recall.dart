/// Régime de **rappel de la question** sous la surface de saisie, et sa table
/// unique de résolution.
///
/// La surface de saisie répète la question au-dessus du champ de réponse : sur
/// une fenêtre large, ce rappel évite un aller-retour du regard vers la carte.
/// Sur une fenêtre étroite, la carte et son rappel occupent la hauteur entière
/// et poussent la saisie hors de l'écran — le rappel dessert alors ce qu'il
/// sert.
///
/// D'où un régime explicite, dont le défaut se décide **sur la largeur
/// disponible** et nulle part ailleurs.
library;

import 'z_study_session_reference.dart';

/// Régime de rendu du rappel de question.
enum ZStudySessionQuestionRecall {
  /// Défaut — le régime est déduit de la largeur disponible :
  /// [full] au-dessus de [ZStudySessionReference.narrowWidth], [compact] en
  /// dessous.
  auto,

  /// Rappel rendu **en entier**, quelle que soit la largeur.
  ///
  /// C'est la valeur à poser pour retrouver le rendu d'un assemblage qui
  /// ignore ce régime.
  full,

  /// Rappel **abrégé** : hauteur bornée, fin de zone en dégradé.
  compact,

  /// Aucun rappel : la question n'est lue que sur la carte.
  hidden,
}

/// Résout le régime **effectif** du rappel de question.
///
/// [availableWidth] est la largeur de la surface qui porte l'écran de session.
/// [narrowWidth] est le seuil d'étroitesse (défaut :
/// [ZStudySessionReference.narrowWidth]).
///
/// Table unique : aucune autre décision de régime n'est prise ailleurs.
ZStudySessionQuestionRecall zResolveQuestionRecall(
  ZStudySessionQuestionRecall requested,
  double availableWidth, {
  double narrowWidth = ZStudySessionReference.narrowWidth,
}) =>
    switch (requested) {
      ZStudySessionQuestionRecall.full => ZStudySessionQuestionRecall.full,
      ZStudySessionQuestionRecall.compact =>
        ZStudySessionQuestionRecall.compact,
      ZStudySessionQuestionRecall.hidden => ZStudySessionQuestionRecall.hidden,
      ZStudySessionQuestionRecall.auto => availableWidth < narrowWidth
          ? ZStudySessionQuestionRecall.compact
          : ZStudySessionQuestionRecall.full,
    };
