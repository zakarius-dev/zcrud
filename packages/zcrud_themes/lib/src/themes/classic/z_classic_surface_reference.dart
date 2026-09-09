/// **Unique** fichier de référence de la famille « surfaces » du thème
/// Classic : fonds de page, fonds de carte, rayons, cible tactile.
///
/// Les deux fonds et le fond de carte sombre sont des littéraux : un fond de
/// page presque-noir bleuté n'est pas dérivable d'un `ColorScheme` (ce n'est
/// pas `surface`, qui porte déjà une teinte issue de la graine). Ils entrent
/// donc comme référence auditée — exception FR-26 encadrée, centralisée ici.
///
/// Les rayons et la cible tactile ne sont pas des couleurs : ce sont des
/// scalaires, remplaçables jeton par jeton dans tous les cas.
///
/// [minTapTarget] est un **plancher** et jamais un maximum : un thème ne
/// réduit pas une cible tactile sous 48 dp (invariant AD-13). Aucune valeur
/// d'ici ne peut passer sous ce seuil, et une garde le vérifie.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZGradientSpec;

/// Fonds, cartes, rayons et bandeaux du thème Classic — point d'audit unique.
abstract final class ZClassicSurfaceReference {
  // Relevé : `lib/src/presentation/features/flashcards/pages/
  // folder_flashcards_repetitions_page.dart:239` — l'unique point où le
  // Scaffold choisit son fond selon la luminosité.

  /// Fond de page en luminosité sombre.
  static const Color darkBackground = Color(0xFF0D1117);

  /// Fond de page en luminosité claire.
  static const Color lightBackground = Color(0xFFF8FAFC);

  // Relevé : `…/widgets/interactive_flashcard_repetition_card.dart:424` —
  // le corps de carte, `Color(0xFF1A1F2E)` en sombre, blanc en clair.
  // ⚠️ Le brief situait cette valeur dans `folder_…_page.dart:317` : elle n'y
  // est pas. Mesure retenue, brief corrigé.

  /// Fond de carte en luminosité sombre.
  static const Color darkCard = Color(0xFF1A1F2E);

  /// Fond de carte en luminosité claire.
  static const Color lightCard = Color(0xFFFFFFFF);

  // Relevé : `folder_flashcards_repetitions_page.dart:282` (bandeau de tête),
  // `:1097` (carte), `:1056` (tuile).

  /// Rayon du bandeau de tête (20).
  static const Radius heroRadius = Radius.circular(20);

  /// Rayon d'une carte (14).
  static const Radius cardRadius = Radius.circular(14);

  /// Rayon d'une tuile ou d'une pastille (12).
  static const Radius tileRadius = Radius.circular(12);

  /// Cible tactile minimale, en dp (invariant AD-13). Plancher : le thème ne
  /// descend jamais en dessous.
  static const double minTapTarget = 48;

  // Relevé : `…/widgets/interactive_flashcard_repetition_card.dart:430-433` —
  // `Container(height: 4, …)` coiffant le corps de la carte, peint du dégradé
  // du type.

  /// Épaisseur, en dp, du liseré de tête d'une carte de révision.
  ///
  /// À passer en **paramètre** de la surface qui en veut un — le paramètre
  /// `cardAccentHeight` de l'écran de session, ou `accentHeight` de la carte
  /// elle-même :
  ///
  /// ```dart
  /// ZStudySessionScaffold(
  ///   cardAccentHeight: ZClassicSurfaceReference.cardAccentHeight,
  ///   // …
  /// )
  /// ```
  ///
  /// Cette valeur n'est **pas** posée sur le jeton `ZcrudTheme.accentBarHeight`
  /// par `ZClassicTheme` : ce jeton-là gouverne aussi le liseré des cartes de
  /// dossier et celui des champs de formulaire, deux surfaces qui n'offrent
  /// aucun paramètre pour s'y soustraire. Le poser pour atteindre la carte de
  /// révision repeindrait les deux autres — et de façon variable selon ce que
  /// l'hôte branche par ailleurs. Un thème pose ce qu'il a mesuré, là où il
  /// l'a mesuré.
  static const double cardAccentHeight = 4;

  // Relevé : `folder_flashcards_repetitions_page.dart:274-275` (sombre) et
  // `:278-279` (clair) — le dégradé du bandeau de tête, choisi selon la
  // luminosité. Premiers plans RETENUS PAR MESURE sur la bande médiane
  // (candidats blanc/noir, contraste WCAG) : blanc dans les deux cas.

  /// Dégradé du bandeau de tête en luminosité sombre.
  static const ZGradientSpec heroGradientDark = ZGradientSpec(
    gradient: LinearGradient(
      // AD-13 : alignements DIRECTIONNELS — le sens suit celui du texte.
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF1E3A5F), Color(0xFF2D5A87)],
    ),
    onGradient: Color(0xFFFFFFFF),
  );

  /// Dégradé du bandeau de tête en luminosité claire.
  static const ZGradientSpec heroGradientLight = ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF667EEA), Color(0xFF764BA2)],
    ),
    onGradient: Color(0xFFFFFFFF),
  );

  /// Fond de page pour [brightness].
  static Color backgroundFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;

  /// Fond de carte pour [brightness].
  static Color cardFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkCard : lightCard;

  /// Dégradé du bandeau de tête pour [brightness].
  static ZGradientSpec heroGradientFor(Brightness brightness) =>
      brightness == Brightness.dark ? heroGradientDark : heroGradientLight;
}
