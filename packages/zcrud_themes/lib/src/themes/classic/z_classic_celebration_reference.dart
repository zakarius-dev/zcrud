/// **Unique** fichier de référence COULEUR de la famille « célébration » du
/// thème Classic : confettis et médaille de fin de session.
///
/// Ces teintes sont festives par nature et ne correspondent à aucun rôle de
/// `ColorScheme` : elles entrent comme référence auditée (exception FR-26
/// encadrée, centralisée ici).
///
/// ## Contraste : ce qui est exigé, et ce qui ne l'est pas
///
/// * [badgeGradient] porte le glyphe de la médaille : son premier plan est
///   MESURÉ sur la bande médiane et tient `kZNonTextMinContrast` (3.0:1).
///   Une garde le recalcule.
/// * [confetti] est une **décoration** au sens de WCAG §1.4.11 : des particules
///   animées qui ne portent aucune information et dont la disparition ne change
///   rien à ce que l'utilisateur peut faire. Aucun plancher de contraste ne
///   leur est donc imposé, et aucune garde n'en invente un. L'information
///   « session terminée » est portée par la médaille et par le texte, jamais
///   par les confettis seuls (invariant AD-13 : le canal couleur n'est jamais
///   seul).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZGradientSpec;

/// Confettis, médaille et glyphe de célébration du thème Classic — point
/// d'audit unique.
abstract final class ZClassicCelebrationReference {
  // Relevé : `lib/src/presentation/features/flashcards/pages/
  // flashcards_learning_celebration_page.dart:126-131` — la liste des six
  // teintes de particules, déclarée en un point unique.
  //
  // ⚠️ Le brief citait `:90-131` ; les lignes 95-102 de ce fichier sont les
  // dégradés de FOND de la page, pas les confettis. Seules 126-131 le sont.

  /// Les six teintes de particules, dans leur ordre d'origine.
  ///
  /// Décoratives : aucun plancher de contraste (cf. dartdoc de tête).
  static final List<Color> confetti = List<Color>.unmodifiable(<Color>[
    const Color(0xFF667EEA),
    const Color(0xFFFF6B6B),
    const Color(0xFF4ECDC4),
    const Color(0xFFFFE66D),
    const Color(0xFF95E1D3),
    const Color(0xFFF38181),
  ]);

  // Relevé : `flashcards_learning_celebration_page.dart:249` (dégradé de la
  // médaille) et `:260` (glyphe).
  //
  // ⚠️ CORRECTION DE CONTRASTE. Le code de référence peignait le glyphe en
  // BLANC (`:262`) sur ce dégradé doré : contraste mesuré 1.66:1 sur la bande
  // médiane (#FFBE00), très en dessous du plancher 3.0:1 — la médaille était
  // quasi illisible. Premier plan porté à NOIR, qui mesure 12.62:1. Le dégradé
  // lui-même est repris à l'octet : seule la lisibilité est corrigée.

  /// Dégradé de la médaille (`#ffd700 → #ffa500`), premier plan noir MESURÉ.
  static const ZGradientSpec badgeGradient = ZGradientSpec(
    gradient: LinearGradient(
      // AD-13 : alignements DIRECTIONNELS — le sens suit celui du texte.
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFFFFD700), Color(0xFFFFA500)],
    ),
    onGradient: Color(0xFF000000),
  );

  /// Glyphe de la médaille de fin de session.
  static const IconData badgeIcon = Icons.emoji_events_rounded;

  /// Clé de dégradé sous laquelle la médaille est publiée au seam
  /// `ZcrudScope.gradientResolver`.
  static const String badgeGradientKey = 'zcrud.classic.celebration.badge';
}
