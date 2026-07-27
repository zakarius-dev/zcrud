/// Préréglage décoratif de démonstration inspiré de cinq dégradés de dossiers.
///
/// Ces couleurs restent exclusivement app-side : elles ne constituent pas une
/// charte de marque et ne sont jamais importées par un package zcrud.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_session/zcrud_session.dart';

/// Tokens VIS stables de la démonstration. Leur identité est conservée entre
/// les builds afin que [ZcrudScope.updateShouldNotify] ne notifie pas tout
/// l'arbre inutilement.
const ZcrudTheme iffdVisualTheme = ZcrudTheme(
  gapM: 10,
  gapL: 20,
  // 🔴 Les trois tokens d'accent sont INDISPENSABLES (CR epic VIS, MAJEUR-2).
  // Les consommateurs (`ZFolderCardGradientAccent`, `ZFlashcardReviewCard`)
  // n'assemblent leur barre que si les QUATRE entrées sont non nulles : la spec
  // de dégradé ET ces trois tokens. Le premier jet du préréglage ne déclarait
  // aucun d'eux : les dix dégradés ci-dessous étaient donc déclarés mais
  // **inobservables dans tout parcours de démonstration**.
  accentBarHeight: 4,
  // AD-13 : alignements DIRECTIONNELS. IFFD utilise `centerLeft → centerRight`
  // (`folders_page.dart:960`) ; recopiés tels quels, ils figeraient le sens du
  // dégradé en RTL.
  gradientBegin: AlignmentDirectional.centerStart,
  gradientEnd: AlignmentDirectional.centerEnd,
  celebrationDuration: Duration(seconds: 5),
  celebrationCurve: Curves.easeOutCubic,
);

/// Recette stable de célébration pour le parcours de session de démonstration.
const ZCelebrationSpec iffdCelebrationSpec = ZCelebrationSpec(
  burstDuration: Duration(seconds: 5),
  numberOfParticles: 50,
  gravity: 0.15,
  emissionFrequency: 0.03,
  trophyIcon: Icons.emoji_events,
  ringsDiameter: 112,
  ringsStrokeWidth: 12,
  ringsTrackColorKey: 'neutral',
  ringsProgressColorKey: 'primary',
);

const List<ZGradientSpec> _iffdFolderGradientsLight = <ZGradientSpec>[
  ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF667EEA), Color(0xFF764BA2)],
    ),
    onGradient: Color(0xFFFFFFFF),
  ),
  ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
    onGradient: Color(0xFFFFFFFF),
  ),
  ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFFF093FB), Color(0xFFF5576C)],
    ),
    onGradient: Color(0xFFFFFFFF),
  ),
  ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF4FACFE), Color(0xFF00F2FE)],
    ),
    onGradient: Color(0xFFFFFFFF),
  ),
  ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFFFA709A), Color(0xFFFEE140)],
    ),
    onGradient: Color(0xFF1A1A1A),
  ),
];

const List<ZGradientSpec> _iffdFolderGradientsDark = <ZGradientSpec>[
  ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    ),
    onGradient: Color(0xFFFFFFFF),
  ),
  ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF00B4DB), Color(0xFF0083B0)],
    ),
    onGradient: Color(0xFFFFFFFF),
  ),
  ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFFFC466B), Color(0xFF3F5EFB)],
    ),
    onGradient: Color(0xFFFFFFFF),
  ),
  ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFF56AB2F), Color(0xFF134E5E)],
    ),
    onGradient: Color(0xFFFFFFFF),
  ),
  ZGradientSpec(
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      colors: <Color>[Color(0xFFF12711), Color(0xFFF5AF19)],
    ),
    onGradient: Color(0xFF1A1A1A),
  ),
];

/// Résout les dégradés de démonstration selon la luminosité réellement active.
///
/// Deux familles de clés, car **deux consommateurs distincts** interrogent ce
/// même résolveur (CR epic VIS, MAJEUR-2 — le premier jet n'en reconnaissait
/// qu'une, si bien que la carte de flashcard n'obtenait jamais de dégradé) :
/// * `iffd-folder-0..4` — identité **persistée** d'un dossier, jamais son index
///   d'affichage (règle D3 : un tri ou un filtre ne doit pas changer sa couleur) ;
/// * `multipleChoice` / `trueOrFalse` / `openQuestion` / `exercise` — le
///   `card.type.name` que `ZFlashcardReviewCard` transmet tel quel.
///
/// ⚠️ Le mapping type → dégradé est déclaré **UNE SEULE FOIS**, ici. C'est
/// exactement ce qu'IFFD ne fait pas : il en porte quatre exemplaires, dont un
/// qui **inverse `openQuestion` et `exercise`** (`flashcard_widgets.dart:145`
/// contre `flashcard_repetition_widgets.dart:50`).
ZGradientSpec? iffdVisualGradientResolver(
  ColorScheme scheme,
  String gradientKey,
) {
  final index = switch (gradientKey) {
    'iffd-folder-0' => 0,
    'iffd-folder-1' => 1,
    'iffd-folder-2' => 2,
    'iffd-folder-3' => 3,
    'iffd-folder-4' => 4,
    // Types de question — table canonique unique.
    'multipleChoice' => 0,
    'trueOrFalse' => 1,
    'openQuestion' => 2,
    'exercise' => 3,
    _ => null,
  };
  if (index == null) return null;
  final gradients = scheme.brightness == Brightness.dark
      ? _iffdFolderGradientsDark
      : _iffdFolderGradientsLight;
  return gradients[index];
}
