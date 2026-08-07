/// **Lot K2 (chantier composer-lex, arbitrage owner 2026-08-07)** — les valeurs
/// de RENDU DE RÉFÉRENCE du composer, mesurées chez **lex_douane** (l'app la
/// plus avancée, désignée référence du mode Chat par la décision du 2026-08-05)
/// et centralisées en UN SEUL endroit — patron `ZChatNotebookReference`
/// (lui-même hérité de `ZStudyCardReference`, CR-IFFD-56/57).
///
/// Toutes les lignes citées sont celles de
/// `lex/packages/lex_ui/lib/presentation/widgets/chat/chat_input.dart`, sauf
/// mention (`effort_chips.dart`, `chat_enums.dart` — même dossier lex).
///
/// ## ⚠️ Exception FR-26 ENCADRÉE (même gouvernance que le notebook)
///
/// Ce fichier est le **second et dernier** de `zcrud_chat` autorisé à porter des
/// couleurs littérales, aux trois conditions de l'arbitrage du 2026-08-04 :
///
/// 1. **Centralisation** — les trois teintes d'identité des paliers de
///    verbosité (`chat_enums.dart:42-46` chez lex) vivent ici et nulle part
///    ailleurs ;
/// 2. **Remplaçabilité** — remplaçables par **paramètre**
///    (`ZChatComposerChrome.responseLengthAccents`) et par **jeton** — le jeton
///    `ZcrudTheme.chatResponseLengthAccents` est **demandé** à `zcrud_core`
///    (hors périmètre de ce lot) et s'insérera entre les deux, comme
///    `chatSelectedEmphasisWeight` l'a été pour CR-74 ; priorité
///    **paramètre > jeton > référence** ;
/// 3. **Exemption nominative** — `test/z_chat_purity_test.dart` exempte CE
///    fichier **par nom exact**, de ses deux règles de COULEUR seulement : les
///    règles AD-13 (directionnalité) et `TextStyle(` y restent opposables.
///
/// Ces trois teintes sont **non dérivables** d'un `ColorScheme` : ce sont des
/// teintes d'IDENTITÉ de palier (vert/bleu/violet), pas des rôles. Elles sont
/// indexées par **`ZChatResponseLength`** — l'axe du kernel auquel les paliers
/// lex correspondent déjà (alias de lecture, `z_chat_enums.dart:100-113`) —
/// jamais par une chaîne métier.
///
/// ## 🔴 Les défauts lex qui ne sont PAS reproduits (relevé §A.2 de l'étude)
///
/// | Défaut mesuré chez lex | Ce que ce fichier fait |
/// |---|---|
/// | bouton « fermer l'édition » **28 dp** (`:516-519`) | non déclaré — [sendTargetSize] est le SEUL côté de cible ici, et il vaut 48 |
/// | bouton « retirer la PJ » **20 dp** (`:1032`), badge OCR ~22 dp (`:1054`), micro compact < 48 dp (`:896`) | non déclarés — la valeur qu'on ne peut pas lire ici ne peut pas être reproduite par inadvertance |
/// | `Positioned(top: 0, right: 0)` non directionnel (`:1025-1026`) | aucune constante de décalage `Right` : tout est `EdgeInsetsDirectional` (AD-13) |
/// | placeholder animé **sans garde Reduce-Motion** (`:1162-1198`) | les durées sont publiées, mais `ZChatComposerAnimatedHint` (le widget du socle) est NEUTRALISÉ par `MediaQuery.disableAnimations` — mesuré |
/// | `theme.dividerColor` / `fillColor` Material | non portés : rôles de thème, à câbler par l'hôte en jetons `ZcrudTheme` |
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

/// Les valeurs de RÉFÉRENCE du composer — le point d'audit **unique** de la
/// famille « composer » (la famille « notebook » a le sien :
/// `ZChatNotebookReference`).
abstract final class ZChatComposerReference {
  // ── Conteneur de la barre (`:474-482`) ────────────────────────────────────

  /// Marge externe du conteneur (`:474`, `EdgeInsets.all(8)` — symétrique,
  /// publiée directionnelle par principe AD-13).
  static const EdgeInsetsDirectional outerPadding = EdgeInsetsDirectional.all(
    8,
  );

  /// Rayon du conteneur de la barre (`:482`).
  static const Radius containerRadius = Radius.circular(12);

  // ── Champ de texte (`:585-609`) ───────────────────────────────────────────

  /// Nombre minimal de lignes du champ (`:588`).
  static const int fieldMinLines = 1;

  /// Nombre maximal de lignes du champ (`:589`).
  static const int fieldMaxLines = 5;

  /// Marge interne du champ (`:609`,
  /// `EdgeInsetsDirectional.fromSTEB(16, 12, 4, 4)` — déjà directionnel chez
  /// lex ✓).
  static const EdgeInsetsDirectional fieldContentPadding =
      EdgeInsetsDirectional.fromSTEB(16, 12, 4, 4);

  /// Décalage HAUT du bloc champ (`:585`, `EdgeInsets.only(top: 4)` —
  /// vertical, sans axe horizontal).
  static const double fieldTopGap = 4;

  // ── Bouton d'envoi (`:646-697`) ───────────────────────────────────────────

  /// Côté de la cible d'envoi : **48** (`:651-657`, `SizedBox` 48×48 autour du
  /// FAB + `Semantics(button:, label:)`) — lex est ici CONFORME AD-13, et
  /// cette valeur est alignée sur `kZChatMinTapTarget`. Le résolveur écrête
  /// toute demande plus basse à ce plancher.
  static const double sendTargetSize = 48;

  /// Marge autour du bouton d'envoi (`:646`, `:677`).
  static const EdgeInsetsDirectional sendPadding = EdgeInsetsDirectional.all(4);

  /// Échelle du bouton quand la saisie est **vide** (`:674-676`).
  static const double sendScaleIdle = 0.7;

  /// Échelle du bouton quand la saisie est **non vide** (`:674-676`).
  static const double sendScaleActive = 1;

  /// Durée de la transition d'échelle (`:674-676`, 150 ms, courbe par défaut).
  static const Duration sendScaleDuration = Duration(milliseconds: 150);

  /// Côté du spinner de téléversement (`:632-641`, boîte 48 avec spinner 24).
  static const double uploadSpinnerSize = 24;

  /// Épaisseur du trait du spinner (`:632-641`).
  static const double uploadSpinnerStrokeWidth = 2;

  // ── Rangée d'outils : puces et badges (`:720-874`) ────────────────────────

  /// Largeur d'écran sous laquelle la rangée passe en mode « icône seule »
  /// (`:720`, `< 400`).
  static const double mobileBreakpoint = 400;

  /// Côté de l'avatar d'une puce (`:768-780`, `:816-833` — 24 dp).
  ///
  /// ⚠️ Taille du **glyphe**, jamais de la cible : la cible reste
  /// [sendTargetSize]/`kZChatMinTapTarget`.
  static const double chipAvatarSize = 24;

  /// Rayon d'une puce de réglage (`:768-780`, radius 12).
  static const Radius chipRadius = Radius.circular(12);

  /// Rayon d'un badge compteur/effort (`:790-807`, `:856-874` — radius 8).
  static const Radius badgeRadius = Radius.circular(8);

  /// Marge interne d'un badge (`:790-807`, h4/v0 — rendue directionnelle).
  static const EdgeInsetsDirectional badgePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 4);

  /// Écart de DÉBUT entre une puce et son badge (`:790-807`, `marge start 4` —
  /// lex écrit déjà `EdgeInsetsDirectional.only(end:)` sur la puce ✓).
  static const double badgeStartGap = 4;

  /// Côté du glyphe du bouton « outils » et du déclencheur de palier
  /// (`:836-847` et `effort_chips.dart:94-95` — 18 dp).
  static const double toolsIconSize = 18;

  /// Marge interne du déclencheur actif (`:836-847`, h6/v4).
  static const EdgeInsetsDirectional toolsActivePadding =
      EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 4);

  /// Durée d'un aller de l'animation de couleur du déclencheur de palier
  /// (`effort_chips.dart:143-155`, 2 s easeInOut, `repeat(reverse: true)`).
  ///
  /// ⚠️ Boucle infinie ⇒ tout widget qui l'applique DOIT l'arrêter sous
  /// `MediaQuery.disableAnimations` — lex le fait ici même
  /// (`effort_chips.dart:170-180`), c'est le patron à suivre.
  static const Duration accentCycleDuration = Duration(seconds: 2);

  // ── Bandeau du mode édition (`:488-526`) ──────────────────────────────────

  /// Marge du bandeau « modification en cours » (`:488-526`, h16/v8).
  static const EdgeInsetsDirectional editingBannerPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8);

  /// Côté du glyphe d'édition du bandeau (`:488-526`, 16 dp).
  ///
  /// ⚠️ Le bouton « fermer » de 28 dp du même bandeau n'est PAS déclaré :
  /// cible < 48 dp (cf. dartdoc de bibliothèque).
  static const double editingIconSize = 16;

  // ── Placeholder animé (`:1162-1198`) ──────────────────────────────────────

  /// Période de rotation des suggestions du placeholder (`:1162`, 4 s).
  static const Duration hintRotationPeriod = Duration(seconds: 4);

  /// Période du pouls de l'icône du placeholder (`:1171`, 900 ms).
  static const Duration hintPulsePeriod = Duration(milliseconds: 900);

  /// Durée du fondu du pouls (`:1188-1190`, 700 ms easeInOut).
  static const Duration hintPulseFadeDuration = Duration(milliseconds: 700);

  /// Durée du fondu de changement de texte (`:1195-1198`, 350 ms).
  static const Duration hintSwitchDuration = Duration(milliseconds: 350);

  /// Côté de l'icône du placeholder (`:597-600`, `:1191` — 18 dp).
  static const double hintIconSize = 18;

  // ── Bande de pièces jointes (`:946-1110`) ─────────────────────────────────

  /// Hauteur de la bande d'aperçu (`:946-1110`, 80 dp).
  static const double attachmentStripHeight = 80;

  /// Côté d'une vignette (`:946-1110`, 72×72).
  static const double attachmentThumbSize = 72;

  /// Rayon d'une vignette (`:946-1110`, radius 8).
  static const Radius attachmentThumbRadius = Radius.circular(8);

  /// Écart de FIN entre deux vignettes (`EdgeInsetsDirectional.only(end: 8)`,
  /// déjà directionnel chez lex ✓).
  ///
  /// ⚠️ Le bouton « retirer » de 20 dp et son `Positioned(top: 0, right: 0)`
  /// ne sont PAS déclarés (cible < 48 dp + non directionnel) : la bande du
  /// socle (`ZChatAttachmentStrip`) fait déjà mieux.
  static const double attachmentEndGap = 8;

  // ── COULEURS — exception FR-26 encadrée (cf. dartdoc de bibliothèque) ─────

  /// Teintes d'IDENTITÉ des paliers de verbosité — `chat_enums.dart:42-46`
  /// chez lex : vert `#4CAF50` (concise/« Mini »), bleu `#2196F3`
  /// (standard/« Plus »), violet `#9C27B0` (détaillée/« Pro »).
  ///
  /// Indexées par l'axe du **kernel** (`ZChatResponseLength`), jamais par un
  /// libellé. Non dérivables d'un `ColorScheme` : aucune séquence de rôles ne
  /// porte une identité de palier. Décoratives, **jamais porteuses seules**
  /// d'information : le palier choisi reste annoncé par la sémantique et par
  /// l'emphase CR-74 de la feuille de réglages.
  ///
  /// Remplaçables par paramètre (`ZChatComposerChrome.responseLengthAccents`,
  /// consultées **clé par clé**) et — dès que `zcrud_core` le portera — par le
  /// jeton demandé `ZcrudTheme.chatResponseLengthAccents`.
  static const Map<ZChatResponseLength, Color> responseLengthAccents =
      <ZChatResponseLength, Color>{
        ZChatResponseLength.concise: Color(0xFF4CAF50),
        ZChatResponseLength.standard: Color(0xFF2196F3),
        ZChatResponseLength.detailed: Color(0xFF9C27B0),
      };
}
