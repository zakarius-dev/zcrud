/// **Lot 1 « étude »** — le RENDU DE RÉFÉRENCE de l'écran de session de
/// révision assemblé, centralisé en UN SEUL endroit (patron
/// `ZStudyCardReference`, directive owner : « les valeurs de référence entrent
/// comme DÉFAUTS de jetons/rôles documentés, jamais comme constantes
/// éparpillées dans les widgets »).
///
/// ## Origine legacy — `fichier:ligne`
///
/// L'assemblage de référence est l'écran de démonstration
/// `example/lib/demos/study_session_demo_screen.dart` (575 l.), seul hôte
/// correct existant avant ce lot. Chaque constante ci-dessous cite la ligne
/// exacte dont elle est extraite : la référence n'est pas inventée, elle est
/// **relevée**.
///
/// ## Priorité de résolution, partout
///
/// **paramètre > jeton `ZcrudTheme.studySession*` > défaut-référence**
///
/// **Les jetons `studySession*` n'existent PAS ENCORE** dans `ZcrudTheme`
/// (mesuré : `grep -n "studySession"` sur `z_theme.dart` → vide ; `zcrud_core`
/// appartient à un autre lot). La chaîne effective d'aujourd'hui est donc
/// **paramètre > référence**, et [zStudySessionChromeOf] est écrit de sorte que
/// l'insertion du maillon jeton soit **une ligne par champ** — jamais une
/// réécriture. La liste des jetons à poser (nom, type, valeur de référence) est
/// remontée dans le rapport de lot.
///
/// ## FR-26 — matière en rôles, TOUJOURS
///
/// **AUCUNE couleur ici.** Les seules valeurs figées sont des DIMENSIONS,
/// des proportions et des scalaires. Chaque couleur du rendu de référence est
/// un rôle du `ColorScheme` courant, résolu au rendu par
/// [zStudySessionChromeOf] : séparateur `outlineVariant`, texte secondaire
/// `onSurfaceVariant`, accent de progression `primary`.
///
/// Ce fichier n'est donc **PAS** dans l'exemption nominative
/// `_colorGuardExemptFiles` de `z_widgets_hardcode_scan_test.dart` — et la
/// garde couleur doit rester verte dessus **sans exception**.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

/// Les valeurs de RÉFÉRENCE de l'écran de session — le point d'audit unique.
///
/// Modifier une valeur ici change le défaut de **tout** l'assemblage
/// (`ZStudySessionView` et son enveloppe). `abstract final class` +
/// `static const` seuls : rien à instancier, rien à muter.
abstract final class ZStudySessionReference {
  /// Part verticale de la **pile de cartes** (`Expanded(flex: 3)` —
  /// `study_session_demo_screen.dart:487`).
  static const int stackFlex = 3;

  /// Part verticale de la **zone de saisie/notation** (`Expanded(flex: 2)` —
  /// `study_session_demo_screen.dart:506`).
  ///
  /// La saisie et la notation sont des **FRÈRES** de la pile, jamais des
  /// descendants : un `TextField` sous le `PanGestureRecognizer` du swiper fait
  /// se battre le placement du curseur contre la navigation (cf. dartdoc de
  /// `ZSessionCardSwiper`, § « L'ARÈNE DES GESTES »). Ces deux flex sont donc
  /// la matérialisation d'un invariant, pas un simple réglage esthétique.
  static const int inputFlex = 2;

  /// Padding interne des zones défilantes (12, directionnel — AD-13 ;
  /// `study_session_demo_screen.dart:439` et `:508`).
  static const EdgeInsetsGeometry contentPadding =
      EdgeInsetsDirectional.all(12);

  /// Épaisseur (et hauteur totale) du séparateur pile ↔ saisie
  /// (`Divider(height: 1)` — `study_session_demo_screen.dart:504`).
  static const double dividerThickness = 1;

  /// Écart vertical entre deux blocs du repli « session vide »
  /// (`SizedBox(height: 12)` — `study_session_demo_screen.dart:474`).
  static const double sectionGap = 12;

  /// Cible tap minimale Material/AD-13 (dp).
  ///
  /// Même valeur que `ZSessionCardSwiper.minTarget` — délibérément **relevée
  /// ici aussi** : les cibles de CET assemblage (compteurs tapables, issue de
  /// sortie du repli vide) ne descendent pas du swiper et n'hériteraient donc
  /// d'aucune contrainte. La garde mesure la **géométrie rendue**, jamais les
  /// contraintes déclarées.
  static const double minTarget = 48;

  /// Nombre de lignes du compteur de session (référence : UNE ligne).
  static const int counterMaxLines = 1;
}

/// Chrome de référence **RÉSOLU** pour l'écran de session : chaque champ a
/// appliqué la priorité **paramètre > jeton `studySession*` > référence** et
/// les rôles du `ColorScheme` courant. Produit par [zStudySessionChromeOf].
@immutable
class ZStudySessionChrome {
  /// Construit un chrome résolu (usage interne à l'assemblage de session).
  const ZStudySessionChrome({
    required this.stackFlex,
    required this.inputFlex,
    required this.contentPadding,
    required this.dividerThickness,
    required this.sectionGap,
    required this.minTarget,
    required this.dividerColor,
    required this.counterStyle,
    required this.secondaryTextColor,
    required this.accentColor,
  });

  /// Part verticale effective de la pile.
  final int stackFlex;

  /// Part verticale effective de la zone de saisie/notation.
  final int inputFlex;

  /// Padding interne effectif des zones défilantes.
  final EdgeInsetsGeometry contentPadding;

  /// Épaisseur effective du séparateur.
  final double dividerThickness;

  /// Écart vertical effectif entre blocs.
  final double sectionGap;

  /// Cible tap minimale effective (dp).
  final double minTarget;

  /// Couleur du séparateur — rôle `outlineVariant` (FR-26).
  final Color dividerColor;

  /// Style effectif du compteur de session.
  final TextStyle? counterStyle;

  /// Premier plan du texte secondaire — rôle `onSurfaceVariant` (FR-26).
  final Color secondaryTextColor;

  /// Accent de progression — rôle `primary` (FR-26).
  final Color accentColor;
}

/// Résout le chrome de l'écran de session depuis le contexte (rôles du
/// `ColorScheme`, styles du `TextTheme`) avec surcharge ponctuelle par
/// paramètre. Toute couleur est un RÔLE dérivé (FR-26) — aucune n'est figée.
///
/// 🔒 **Chaîne complète : `paramètre ?? jeton ?? référence`.** Le maillon
/// jeton (`ZcrudTheme.studySession*`) est branché depuis que les jetons
/// existent dans `zcrud_core` — il s'est intercalé **entre les deux**, sans
/// déplacer une seule autre ligne, exactement comme annoncé.
///
/// 🚫 **Aucun jeton GÉNÉRIQUE n'est monté en maillon intermédiaire** — pas de
/// `gapM` pour l'écart de section, pas de `radiusM` pour un rayon. C'est
/// exactement le défaut que CR-IFFD-61 a corrigé sur les cartes d'étude :
/// l'écart tuile→titre et le padding de carte ridaient le **même** `gapM`,
/// donc aucune valeur ne pouvait satisfaire les deux. Faire rider `gapM` par
/// l'écart de session rouvrirait la même impasse — et donnerait au lecteur
/// l'illusion d'une chaîne à trois maillons là où le maillon du milieu ne
/// désigne pas la bonne propriété. Le jeton dédié viendra, ou rien.
ZStudySessionChrome zStudySessionChromeOf(
  BuildContext context, {
  int? stackFlex,
  int? inputFlex,
  EdgeInsetsGeometry? contentPadding,
  double? dividerThickness,
  double? sectionGap,
  double? minTarget,
  TextStyle? counterStyle,
}) {
  final ThemeData material = Theme.of(context);
  final ColorScheme scheme = material.colorScheme;
  final TextTheme text = material.textTheme;
  final ZcrudTheme theme = ZcrudTheme.of(context);
  return ZStudySessionChrome(
    stackFlex: stackFlex ??
        theme.studySessionStackFlex ??
        ZStudySessionReference.stackFlex,
    inputFlex: inputFlex ??
        theme.studySessionInputFlex ??
        ZStudySessionReference.inputFlex,
    contentPadding: contentPadding ??
        theme.studySessionContentPadding ??
        ZStudySessionReference.contentPadding,
    dividerThickness: dividerThickness ??
        theme.studySessionDividerThickness ??
        ZStudySessionReference.dividerThickness,
    sectionGap: sectionGap ??
        theme.studySessionSectionGap ??
        ZStudySessionReference.sectionGap,
    minTarget: minTarget ??
        theme.studySessionMinTarget ??
        ZStudySessionReference.minTarget,
    dividerColor: scheme.outlineVariant,
    counterStyle:
        counterStyle ?? theme.studySessionCounterStyle ?? text.labelLarge,
    secondaryTextColor: scheme.onSurfaceVariant,
    accentColor: scheme.primary,
  );
}
