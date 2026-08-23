/// Valeurs de rendu de référence du composer, centralisées en un seul
/// endroit — même patron que `ZChatNotebookReference`.
///
/// ## Exception encadrée sur les couleurs codées en dur
///
/// Ce fichier est l'un des deux seuls de `zcrud_chat` autorisés à porter des
/// couleurs littérales, à trois conditions strictes :
///
/// 1. Centralisation — les trois teintes d'identité des paliers de verbosité
///    vivent ici et nulle part ailleurs ;
/// 2. Remplaçabilité — remplaçables par paramètre
///    (`ZChatComposerChrome.responseLengthAccents`) et, à terme, par un jeton
///    de thème qui s'insérera entre les deux ; priorité paramètre > jeton >
///    référence ;
/// 3. Exemption nominative — la garde de source qui interdit les couleurs
///    codées en dur exempte ce fichier par son nom exact, et seulement de sa
///    règle de couleur : l'invariant AD-13 (directionnalité) et l'interdiction
///    de `TextStyle(` y restent opposables.
///
/// Ces trois teintes ne sont pas dérivables d'un `ColorScheme` : ce sont des
/// teintes d'identité de palier (vert/bleu/violet), pas des rôles. Elles sont
/// indexées par [ZChatResponseLength] — l'axe du kernel — jamais par une
/// chaîne métier.
///
/// ## Ce que ce fichier ne déclare délibérément pas
///
/// Une valeur qui ne peut pas être lue ici ne peut pas être reproduite par
/// inadvertance. Toute cible tactile déclarée ici vaut donc au moins 48 dp et
/// tout décalage déclaré ici est directionnel — y compris ceux des deux
/// affordances les plus souvent rétrécies, la sortie du bandeau d'édition
/// ([editingCancelTargetSize]) et le retrait d'une pièce jointe
/// ([attachmentRemoveTargetSize]). Les durées d'une animation de placeholder
/// sont publiées sans jamais dispenser le widget du socle de sa garde
/// Reduce Motion. Les rôles de thème (couleur de filet, couleur de fond) ne
/// sont pas portés ici : ils se câblent par paramètre ou par jeton, seule
/// leur épaisseur ou leur forme relève de la référence.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'z_chat_message_tile.dart' show kZChatMinTapTarget;

/// Les valeurs de référence du composer — le point d'audit unique de la
/// famille « composer » (la famille « notebook » a le sien :
/// `ZChatNotebookReference`).
abstract final class ZChatComposerReference {
  // ── Conteneur de la barre ──────────────────────────────────────────────

  /// Marge externe du conteneur — symétrique, publiée directionnelle par
  /// principe (invariant AD-13).
  static const EdgeInsetsDirectional outerPadding = EdgeInsetsDirectional.all(
    8,
  );

  /// Rayon du conteneur de la barre.
  static const Radius containerRadius = Radius.circular(12);

  /// Épaisseur du filet du conteneur — largeur par défaut d'un `BorderSide`,
  /// soit 1.
  ///
  /// Seule l'épaisseur est une valeur de référence. La couleur reste un rôle
  /// de thème, non portée ici : le socle n'invente aucune teinte. Elle se
  /// câble par `ZChatComposerSurface.borderColor` puis par un jeton de
  /// thème. Sans couleur résolue, aucun filet n'est rendu, jamais une
  /// bordure inerte (invariant AD-4).
  static const double borderWidth = 1;

  // ── Champ de texte ─────────────────────────────────────────────────────

  /// Nombre minimal de lignes du champ.
  static const int fieldMinLines = 1;

  /// Nombre maximal de lignes du champ.
  static const int fieldMaxLines = 5;

  /// Marge interne du champ.
  static const EdgeInsetsDirectional fieldContentPadding =
      EdgeInsetsDirectional.fromSTEB(16, 12, 4, 4);

  /// Décalage haut du bloc champ — vertical, sans axe horizontal.
  static const double fieldTopGap = 4;

  // ── Bouton d'envoi ─────────────────────────────────────────────────────

  /// Côté de la cible d'envoi, alignée sur `kZChatMinTapTarget`. Le
  /// résolveur écrête toute demande plus basse à ce plancher.
  static const double sendTargetSize = 48;

  /// Marge autour du bouton d'envoi.
  static const EdgeInsetsDirectional sendPadding = EdgeInsetsDirectional.all(4);

  /// Échelle du bouton quand la saisie est vide.
  static const double sendScaleIdle = 0.7;

  /// Échelle du bouton quand la saisie est non vide.
  static const double sendScaleActive = 1;

  /// Durée de la transition d'échelle.
  static const Duration sendScaleDuration = Duration(milliseconds: 150);

  /// Côté du spinner de téléversement.
  static const double uploadSpinnerSize = 24;

  /// Épaisseur du trait du spinner.
  static const double uploadSpinnerStrokeWidth = 2;

  // ── Rangée d'outils : puces et badges ──────────────────────────────────

  /// Largeur d'écran sous laquelle la rangée passe en mode « icône seule ».
  static const double mobileBreakpoint = 400;

  /// Côté de l'avatar d'une puce.
  ///
  /// Taille du glyphe, jamais de la cible : la cible reste
  /// [sendTargetSize]/`kZChatMinTapTarget`.
  static const double chipAvatarSize = 24;

  /// Rayon d'une puce de réglage.
  static const Radius chipRadius = Radius.circular(12);

  /// Rayon d'un badge compteur/effort.
  static const Radius badgeRadius = Radius.circular(8);

  /// Marge interne d'un badge — rendue directionnelle.
  static const EdgeInsetsDirectional badgePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 4);

  /// Écart de début entre une puce et son badge.
  static const double badgeStartGap = 4;

  /// Côté du glyphe du bouton « outils » et du déclencheur de palier.
  static const double toolsIconSize = 18;

  /// Marge interne du déclencheur actif.
  static const EdgeInsetsDirectional toolsActivePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 4);

  /// Durée d'un aller de l'animation de couleur du déclencheur de palier.
  ///
  /// Boucle infinie : tout widget qui l'applique doit l'arrêter sous
  /// `MediaQuery.disableAnimations`.
  static const Duration accentCycleDuration = Duration(seconds: 2);

  // ── Bandeau du mode édition ────────────────────────────────────────────

  /// Marge du bandeau « modification en cours ».
  static const EdgeInsetsDirectional editingBannerPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8);

  /// Côté du glyphe d'édition du bandeau.
  ///
  /// C'est la taille du GLYPHE, jamais celle de la cible : la sortie du
  /// bandeau a la sienne, [editingCancelTargetSize].
  static const double editingIconSize = 16;

  /// Côté de la cible de sortie du bandeau — au plancher tactile.
  ///
  /// Un glyphe compact n'autorise pas une cible compacte : la zone touchable
  /// reste ≥ 48 dp quelle que soit la taille rendue du glyphe (invariant
  /// AD-13).
  static const double editingCancelTargetSize = kZChatMinTapTarget;

  // ── Placeholder animé ──────────────────────────────────────────────────

  /// Période de rotation des suggestions du placeholder.
  static const Duration hintRotationPeriod = Duration(seconds: 4);

  /// Période du pouls de l'icône du placeholder.
  static const Duration hintPulsePeriod = Duration(milliseconds: 900);

  /// Durée du fondu du pouls.
  static const Duration hintPulseFadeDuration = Duration(milliseconds: 700);

  /// Durée du fondu de changement de texte.
  static const Duration hintSwitchDuration = Duration(milliseconds: 350);

  /// Côté de l'icône du placeholder.
  static const double hintIconSize = 18;

  // ── Bande de pièces jointes ────────────────────────────────────────────

  /// Hauteur de la bande d'aperçu.
  static const double attachmentStripHeight = 80;

  /// Côté d'une vignette.
  static const double attachmentThumbSize = 72;

  /// Rayon d'une vignette.
  static const Radius attachmentThumbRadius = Radius.circular(8);

  /// Écart de fin entre deux vignettes.
  static const double attachmentEndGap = 8;

  /// Côté de la cible de retrait d'une pièce jointe — au plancher tactile.
  ///
  /// Le retrait n'est pas une pastille posée en coin de vignette : c'est une
  /// cible ≥ 48 dp, rendue dans le flux directionnel de la vignette, jamais
  /// à un décalage `left`/`right` (invariant AD-13).
  static const double attachmentRemoveTargetSize = kZChatMinTapTarget;

  /// Écart de début entre le nom du fichier et sa cible de retrait —
  /// directionnel par construction, comme tous les écarts de ce fichier.
  static const double attachmentRemoveStartGap = 4;

  // ── Couleurs — exception encadrée (cf. dartdoc de bibliothèque) ────────

  /// Teintes d'identité des paliers de verbosité : vert (concise), bleu
  /// (standard), violet (détaillée).
  ///
  /// Indexées par l'axe du kernel ([ZChatResponseLength]), jamais par un
  /// libellé. Non dérivables d'un `ColorScheme` : aucune séquence de rôles ne
  /// porte une identité de palier. Décoratives, jamais porteuses seules
  /// d'information : le palier choisi reste annoncé par la sémantique et par
  /// l'emphase de la feuille de réglages.
  ///
  /// Remplaçables par paramètre (`ZChatComposerChrome.responseLengthAccents`,
  /// consultées clé par clé) et, dès que `zcrud_core` le portera, par un
  /// jeton de thème.
  static const Map<ZChatResponseLength, Color> responseLengthAccents =
      <ZChatResponseLength, Color>{
        ZChatResponseLength.concise: Color(0xFF4CAF50),
        ZChatResponseLength.standard: Color(0xFF2196F3),
        ZChatResponseLength.detailed: Color(0xFF9C27B0),
      };
}
