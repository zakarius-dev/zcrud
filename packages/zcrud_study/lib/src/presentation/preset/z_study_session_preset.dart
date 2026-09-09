/// Assemblage de référence de l'écran de session : les FORMES, paramétrées.
///
/// ## Pourquoi un objet de configuration, et pas une fabrique de slots
///
/// L'écran de session expose déjà tout ce qu'il faut pour bâtir une session
/// complète — mais **en valeurs** : une clé de dégradé ici, un seam de pastille
/// là, une hauteur de liseré ailleurs. Ce qui manquait, ce sont les **formes**
/// qui les assemblent : la rangée d'en-tête, le chrome de carte, le style de
/// progression. Chaque hôte les recomposait, et chaque recomposition se paie —
/// un créneau de carte posé sans l'état de révélation branché, un retrait qui
/// emporte des seams sans qu'aucun test ne bouge.
///
/// Une fabrique qui **remplirait des slots** ne fermerait pas ce défaut : rien
/// n'empêcherait d'en poser la moitié. Un preset est **interprété par l'écran
/// lui-même** : il n'y a pas de câblage intermédiaire à oublier.
///
/// ## La règle de priorité, en un mot
///
/// **Un paramètre explicite gagne toujours sur le preset.** Poser un preset
/// n'enlève donc jamais rien : il remplit ce qui n'a pas été dit. Et sans
/// preset, l'écran rend exactement l'arbre qu'il rendait avant que ce type
/// n'existe.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZAnswerActionsLayout,
        ZAnswerChoiceLayout,
        ZAnswerGradingVisibility,
        ZAnswerSubmitWidth;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcardQuestionTypeBadgeBuilder;
import 'package:zcrud_session/zcrud_session.dart'
    show ZSessionDotsGeometry, ZSessionProgressStyle;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZStudyStreak;

import '../z_study_session_slices.dart';
import 'z_card_chrome_spec.dart';
import 'z_card_type_shadow.dart';
import 'z_session_header_spec.dart';

/// Formes de référence d'un écran de session, décrites une fois.
///
/// Chaque champ nul laisse l'écran **strictement inchangé** : un preset ne
/// retire jamais rien et n'ajoute que ce qu'il décrit.
///
/// ## Où chaque champ est interprété
///
/// [header], [progressStyle] et les trois réglages de forme de la progression
/// sont interprétés par le corps composable de la session ; [cardChrome] et
/// [cardBackgroundColorKey] le sont par l'écran qui
/// **monte la carte** lui-même. Un hôte qui remplace la carte entière par son
/// propre constructeur de carte devient responsable de son chrome : le preset
/// n'habille que la carte du socle.
@immutable
class ZStudySessionPreset {
  /// Décrit les formes à poser. Tout champ omis laisse l'écran inchangé.
  const ZStudySessionPreset({
    this.header,
    this.cardChrome,
    this.progressStyle,
    this.progressDotsGeometry,
    this.progressLinearThickness,
    this.progressSegmentedMarkerThickness,
    this.cardBackgroundColorKey,
    this.answerChoiceLayout,
    this.answerActionsLayout,
    this.answerSubmitWidth,
    this.answerGradingVisibility,
  });

  /// Session complète — en-tête, chrome de carte et progression compacte.
  ///
  /// `classic` nomme une **direction de design**, pas l'apparence d'une
  /// application : l'écran y gagne un en-tête à trois places (titre, compteur,
  /// série), une carte à liseré, et une progression écrite en toutes lettres.
  /// Toutes les **valeurs** restent celles de l'hôte — les textes sont déjà
  /// localisés par lui, les couleurs passent par des clés.
  ///
  /// [counter] compose le libellé du compteur depuis la progression réelle.
  /// C'est délibérément à l'appelant : en régime SRS,
  /// `remaining + reviewed != total`, et aucune formule ne convient à tous.
  ///
  /// [accentHeight] est le seul interrupteur du liseré ; laissé nul, le jeton
  /// de thème `accentBarHeight` décide, et les deux nuls ⇒ aucun liseré.
  ///
  /// Deux formes de progression y sont décrites — celle des **points** et
  /// l'épaisseur de la **barre segmentée à marqueur** — chacune sans effet hors
  /// du style choisi par [progressStyle] : décrire une forme ne la montre pas,
  /// elle attend le style qui la peint.
  ///
  /// Quatre **formes de la surface de saisie** y sont posées : ligne de choix
  /// en tuile, contrôles d'aide côte à côte, soumission pleine largeur, et
  /// rangée de paliers montée d'emblée. Chacune se remplace par son paramètre.
  ///
  /// 🔴 [answerGradingVisibility] par défaut ([ZAnswerGradingVisibility.always])
  /// change l'**ordre des gestes** : la rangée de paliers est montée et active
  /// avant toute réponse, et un palier tapé alors est une notation manuelle qui
  /// verrouille la surface — une notation, jamais deux. Poser
  /// [ZAnswerGradingVisibility.afterSubmit] garde l'ordre habituel (répondre,
  /// puis noter).
  ///
  /// L'**ombre de la carte suit son TYPE** : sa teinte est la première couleur
  /// du dégradé qui identifie ce type, résolue carte par carte. C'est une forme
  /// qu'un thème ne peut pas décrire — il n'a qu'une teinte d'ombre, quand un
  /// écran montre plusieurs types côte à côte. Un type dont aucun dégradé n'est
  /// résoluble ne reçoit pas de teinte : le jeton de thème garde alors la main.
  /// [cardShadowColor] impose au contraire une teinte unique à toutes les
  /// cartes.
  ///
  /// Rien n'est fabriqué pour rien : sans aucune valeur d'en-tête, aucun
  /// en-tête n'est décrit ; et aucune épaisseur de barre continue n'est posée —
  /// la référence n'en décrit pas. Le chrome de carte, lui, est toujours décrit
  /// **parce que la direction d'ombre en fait partie** : ce n'est pas un
  /// descripteur vide.
  factory ZStudySessionPreset.classic({
    String? title,
    String Function(ZStudySessionProgress progress)? counter,
    ZStudyStreak? streak,
    Widget? headerTrailing,
    String? cardTypeGradientKey,
    Widget? instructionBanner,
    ZFlashcardQuestionTypeBadgeBuilder? questionTypeBadgeBuilder,
    double? accentHeight,
    Color? cardShadowColor,
    ZSessionProgressStyle progressStyle = ZSessionProgressStyle.pill,
    ZSessionDotsGeometry? progressDotsGeometry,
    double? progressLinearThickness,
    double? progressSegmentedMarkerThickness,
    String? cardBackgroundColorKey,
    ZAnswerChoiceLayout answerChoiceLayout = ZAnswerChoiceLayout.tile,
    ZAnswerActionsLayout answerActionsLayout = ZAnswerActionsLayout.sideBySide,
    ZAnswerSubmitWidth answerSubmitWidth = ZAnswerSubmitWidth.full,
    ZAnswerGradingVisibility answerGradingVisibility =
        ZAnswerGradingVisibility.always,
  }) {
    // AD-4 — un descripteur n'est décrit que si quelque chose le remplit :
    // une closure qui rendrait une spécification vide monterait un slot que
    // l'écran croirait porteur.
    final bool describesHeader = title != null ||
        counter != null ||
        streak != null ||
        headerTrailing != null;
    // Le chrome, lui, n'est PAS conditionnel : la direction d'ombre par type
    // est une forme de `classic` à part entière, au même titre que la pilule
    // de progression ou la tuile de choix. Le descripteur n'est donc jamais
    // vide (AD-4 tient : quelque chose le remplit toujours), et il reste
    // strictement inerte là où la chaîne par type ne résout rien.
    return ZStudySessionPreset(
      header: describesHeader
          ? (ZStudySessionProgress progress) => ZSessionHeaderSpec(
                title: title,
                counter: counter?.call(progress),
                streak: streak,
                trailing: headerTrailing,
              )
          : null,
      cardChrome: (_) => ZCardChromeSpec(
            typeGradientKey: cardTypeGradientKey,
            instructionBanner: instructionBanner,
            questionTypeBadgeBuilder: questionTypeBadgeBuilder,
            accentHeight: accentHeight,
            shadowColor: cardShadowColor,
            shadowColorResolver: zFlashcardTypeShadowColor,
          ),
      progressStyle: progressStyle,
      progressDotsGeometry: progressDotsGeometry ?? classicDotsGeometry,
      progressLinearThickness: progressLinearThickness,
      progressSegmentedMarkerThickness:
          progressSegmentedMarkerThickness ?? classicSegmentedMarkerThickness,
      cardBackgroundColorKey: cardBackgroundColorKey,
      answerChoiceLayout: answerChoiceLayout,
      answerActionsLayout: answerActionsLayout,
      answerSubmitWidth: answerSubmitWidth,
      answerGradingVisibility: answerGradingVisibility,
    );
  }

  /// Forme des points de progression de la direction `classic`.
  ///
  /// Des pastilles larges et basses, le point courant nettement allongé, une
  /// file centrée qui reste sur une seule rangée quelle que soit sa longueur.
  /// C'est une **direction de design** mesurée sur une référence visuelle, pas
  /// une valeur imposée : elle se remplace par paramètre, et n'a d'effet que
  /// sous le style « points ».
  static const ZSessionDotsGeometry classicDotsGeometry = ZSessionDotsGeometry(
    inactiveSize: Size(14, 10),
    activeScale: 2.4,
    gap: 12,
    alignment: WrapAlignment.center,
    scrollable: true,
  );

  /// Épaisseur de la barre segmentée à marqueur de la direction `classic`.
  static const double classicSegmentedMarkerThickness = 8;

  /// Décrit l'en-tête depuis la progression courante.
  ///
  /// Battu par le constructeur d'en-tête explicite de l'écran. Rappelé à
  /// chaque changement de progression, et **lui seul** : la pile de cartes
  /// n'est pas reconstruite.
  final ZSessionHeaderSpecBuilder? header;

  /// Décrit l'habillage de la carte que l'écran monte lui-même.
  ///
  /// Chaque champ du chrome est battu individuellement par son paramètre
  /// homonyme de l'écran.
  final ZCardChromeSpecBuilder? cardChrome;

  /// Style de l'indicateur de progression.
  ///
  /// `null` ⇒ le style demandé à l'écran, sinon le style par défaut.
  final ZSessionProgressStyle? progressStyle;

  /// Forme des points de progression.
  ///
  /// `null` ⇒ la géométrie demandée à l'écran, sinon le rendu par défaut de
  /// l'indicateur. Sans effet hors du style « points ». Battue par la
  /// géométrie explicite de l'écran.
  final ZSessionDotsGeometry? progressDotsGeometry;

  /// Épaisseur de la barre de progression continue.
  ///
  /// `null` ⇒ l'épaisseur demandée à l'écran, sinon celle que l'indicateur
  /// dérive du thème. Sans effet hors du style « barre continue ».
  final double? progressLinearThickness;

  /// Épaisseur de la barre de progression segmentée à marqueur.
  ///
  /// `null` ⇒ l'épaisseur demandée à l'écran, sinon celle que l'indicateur
  /// dérive du thème. Sans effet hors du style « barre segmentée à marqueur ».
  final double? progressSegmentedMarkerThickness;

  /// **Clé** de couleur du fond de carte, jamais une couleur.
  ///
  /// Résolue par le résolveur de clés de l'hôte, avec repli sur un rôle
  /// contrasté du thème : une clé inconnue ne lève pas et ne laisse pas la
  /// carte sans fond. Battue par la couleur de fond explicite de l'écran.
  final String? cardBackgroundColorKey;

  /// Disposition d'une ligne de choix de la surface de saisie.
  ///
  /// `null` ⇒ la disposition demandée à l'écran, sinon le jeton de thème,
  /// sinon la ligne nue de référence. Battue par la disposition explicite de
  /// l'écran.
  final ZAnswerChoiceLayout? answerChoiceLayout;

  /// Disposition des deux contrôles d'aide de la surface de saisie.
  ///
  /// `null` ⇒ la disposition demandée à l'écran, sinon le jeton de thème,
  /// sinon la colonne de référence. Battue par la disposition explicite de
  /// l'écran.
  final ZAnswerActionsLayout? answerActionsLayout;

  /// Largeur du contrôle de soumission de la surface de saisie.
  ///
  /// `null` ⇒ la largeur demandée à l'écran, sinon le jeton de thème, sinon la
  /// largeur du contenu. Battue par la largeur explicite de l'écran.
  final ZAnswerSubmitWidth? answerSubmitWidth;

  /// Moment d'apparition de la rangée de paliers de notation.
  ///
  /// `null` ⇒ le moment demandé à l'écran, sinon le jeton de thème, sinon
  /// l'apparition après soumission. Battu par le moment explicite de l'écran.
  ///
  /// 🔴 [ZAnswerGradingVisibility.always] change l'**ordre des gestes** : la
  /// rangée est montée et active avant toute réponse, et un palier tapé alors
  /// est une notation manuelle qui verrouille la surface. Une carte notée à la
  /// main produit exactement une notation, jamais deux.
  final ZAnswerGradingVisibility? answerGradingVisibility;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudySessionPreset &&
          runtimeType == other.runtimeType &&
          header == other.header &&
          cardChrome == other.cardChrome &&
          progressStyle == other.progressStyle &&
          progressDotsGeometry == other.progressDotsGeometry &&
          progressLinearThickness == other.progressLinearThickness &&
          progressSegmentedMarkerThickness ==
              other.progressSegmentedMarkerThickness &&
          cardBackgroundColorKey == other.cardBackgroundColorKey &&
          answerChoiceLayout == other.answerChoiceLayout &&
          answerActionsLayout == other.answerActionsLayout &&
          answerSubmitWidth == other.answerSubmitWidth &&
          answerGradingVisibility == other.answerGradingVisibility;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        header,
        cardChrome,
        progressStyle,
        progressDotsGeometry,
        progressLinearThickness,
        progressSegmentedMarkerThickness,
        cardBackgroundColorKey,
        answerChoiceLayout,
        answerActionsLayout,
        answerSubmitWidth,
        answerGradingVisibility,
      );

  @override
  String toString() => 'ZStudySessionPreset(progressStyle: $progressStyle, '
      'progressDotsGeometry: $progressDotsGeometry, '
      'progressLinearThickness: $progressLinearThickness, '
      'progressSegmentedMarkerThickness: $progressSegmentedMarkerThickness, '
      'cardBackgroundColorKey: $cardBackgroundColorKey, '
      'answerChoiceLayout: $answerChoiceLayout, '
      'answerActionsLayout: $answerActionsLayout, '
      'answerSubmitWidth: $answerSubmitWidth, '
      'answerGradingVisibility: $answerGradingVisibility)';
}
