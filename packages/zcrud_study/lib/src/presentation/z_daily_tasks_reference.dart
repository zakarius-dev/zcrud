/// **Lot 4 « étude »** — le RENDU DE RÉFÉRENCE de la vue des tâches du jour,
/// centralisé en UN SEUL endroit (patron `ZStudyCardReference` CR-IFFD-56,
/// `ZContentHubReference` CR-IFFD-65, `ZStudySessionReference` lot 1).
///
/// ## Origine legacy, relevée ligne à ligne
///
/// IFFD `lib/src/presentation/features/tasks/pages/daily_tasks_page.dart`
/// (1101 l.) et `…/widgets/weekdays_widget.dart` (93 l.). Chaque constante
/// ci-dessous porte le `fichier:ligne` d'où elle est relevée.
///
/// ## 🔴 FR-26 — AUCUNE couleur ici, et ce n'est PAS un oubli
///
/// Contrairement à `ZFlashcardCardReference` et `ZContentHubReference`, ce
/// fichier **ne demande AUCUNE exemption** de la garde anti-couleurs : les seules
/// valeurs figées sont des **dimensions** et des **scalaires**. Toute couleur du
/// rendu est un **rôle du `ColorScheme`** courant, résolu au rendu par
/// [zDailyTasksChromeOf]. C'est possible parce que le legacy peint déjà cette
/// vue en rôles (`primaryContainer`, `primary`, `cardColor`) — à **deux**
/// exceptions près, qui sont des `Colors.grey` et que le socle **ne reproduit
/// pas** (cf. [ZDailyTasksReference.borderRoleNote]).
///
/// ## 🔴 UNE divergence délibérée avec le legacy — et UNE SUSPICION RÉFUTÉE
///
/// ① **Divergence RETENUE — le liseré et le numéro non sélectionnés.** Le legacy
/// pose `Colors.grey` (`daily_tasks_page.dart:175` et `:218`) — un gris
/// **constant dans les deux luminosités** (grep négatif exécuté sur le fichier
/// legacy : `grep -n 'Brightness' daily_tasks_page.dart` ⇒ **sortie vide**). En
/// thème sombre il s'écrase contre le fond, et FR-26 interdit de toute façon un
/// littéral. Le socle rend ces deux plans en `outlineVariant` /
/// `onSurfaceVariant`, qui **suivent** la luminosité.
///
/// ② **Suspicion RÉFUTÉE PAR LA MESURE — le premier plan de la cellule
/// SÉLECTIONNÉE.** Le legacy peint `colorScheme.primary` **sur**
/// `colorScheme.primaryContainer` (`daily_tasks_page.dart:170` + `:201`/`:217`).
/// Ce n'est pas l'appariement nominal de Material 3 (le rôle prévu pour ce fond
/// est `onPrimaryContainer`), et une première rédaction de ce fichier en avait
/// conclu qu'il fallait diverger « pour le contraste ».
///
/// 🔴 **La mesure a INFIRMÉ cette conclusion, et la divergence a été retirée.**
/// `zContrastRatio` sur **12 graines × 2 luminosités** de `ColorScheme.fromSeed`
/// (dont noir, blanc, gris moyen et jaune — les cas extrêmes) :
///
/// | Appariement | Pire cas mesuré | Plancher AA (4.5:1) |
/// |---|---|---|
/// | legacy `primary` / `primaryContainer` | **4.97** | tenu |
/// | M3 `onPrimaryContainer` / `primaryContainer` | 7.17 | tenu |
///
/// L'appariement du legacy **tient le plancher partout** : il n'y avait aucun
/// défaut à corriger, seulement un `onPrimaryContainer` plus confortable. La
/// règle du socle est explicite (« le défaut EST la référence », CR-IFFD-56) —
/// une préférence de contraste ne justifie pas de faire diverger un rendu de
/// référence. Le socle peint donc `primary`, **comme le legacy**.
///
/// Ce qui reste de l'épisode est une **garde**, pas une divergence : elle mesure
/// le contraste **réellement rendu** contre le plancher AA sur ce même échantillon
/// de graines. Si un jour la construction tonale du SDK change, ou si le rendu
/// dérive, elle rougit — au lieu de nous laisser croire un raisonnement que
/// personne n'aurait vérifié.
///
/// ## Priorité de résolution, partout
///
/// **paramètre de la vue > jeton `ZcrudTheme.dailyTasks*` > défaut-référence**.
///
/// 🔒 **Les trois maillons existent désormais.** Les sept jetons
/// `ZcrudTheme.dailyTasks*` ont été posés dans `zcrud_core` (déclaration,
/// constructeur, `copyWith` signature ET corps, `lerp` — les quatre sites),
/// et [zDailyTasksChromeOf] les intercale **entre le paramètre et la
/// référence**, sans déplacer une autre ligne, exactement comme annoncé.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

/// Les valeurs de RÉFÉRENCE de la vue des tâches du jour (mesurées chez IFFD),
/// le point d'audit unique.
abstract final class ZDailyTasksReference {
  // ── Bandeau de semaine ────────────────────────────────────────────────────

  /// Nombre de jours du bandeau (**7** — `daily_tasks_page.dart:141-144`).
  static const int daysPerBand = DateTime.daysPerWeek;

  /// Premier jour de la semaine (**lundi** — `weekdays_widget.dart:6-7`,
  /// `subtract(Duration(days: date.weekday - DateTime.monday))`).
  static const int weekStart = DateTime.monday;

  /// Padding du bandeau (**8 / 4**, directionnel — `daily_tasks_page.dart:147`).
  ///
  /// Jeton dédié, POSÉ et lu par [zDailyTasksChromeOf] :
  /// `ZcrudTheme.dailyTasksBandPadding` (`EdgeInsetsGeometry?`).
  static const EdgeInsetsGeometry bandPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4);

  /// Marge externe d'une cellule de jour (**horizontal 2**, directionnelle —
  /// `daily_tasks_page.dart:164`).
  ///
  /// Jeton dédié, POSÉ et lu par [zDailyTasksChromeOf] :
  /// `ZcrudTheme.dailyTasksDayCellMargin`.
  static const EdgeInsetsGeometry dayCellMargin =
      EdgeInsetsDirectional.symmetric(horizontal: 2);

  /// Padding interne d'une cellule de jour (**vertical 8**, directionnel —
  /// `daily_tasks_page.dart:166`).
  ///
  /// Jeton dédié, POSÉ et lu par [zDailyTasksChromeOf] :
  /// `ZcrudTheme.dailyTasksDayCellPadding`.
  static const EdgeInsetsGeometry dayCellPadding =
      EdgeInsetsDirectional.symmetric(vertical: 8);

  /// Rayon d'une cellule de jour (**12** — `daily_tasks_page.dart:178`).
  ///
  /// Jeton dédié, POSÉ et lu par [zDailyTasksChromeOf] :
  /// `ZcrudTheme.dailyTasksDayCellRadius` (`Radius?`).
  static const Radius dayCellRadius = Radius.circular(12);

  /// Épaisseur du liseré d'une cellule NON sélectionnée (**1** —
  /// `daily_tasks_page.dart:176`).
  static const double borderWidth = 1;

  /// Épaisseur du liseré d'une cellule SÉLECTIONNÉE (**2** — même ligne).
  ///
  /// 🔴 **Ce n'est pas une redondance avec la couleur** : AD-13 interdit que la
  /// couleur soit le SEUL canal d'une information. L'épaisseur double est le
  /// second canal visuel de la sélection, et `Semantics(selected:)` en est le
  /// canal non visuel (garde dédiée).
  static const double selectedBorderWidth = 2;

  /// Cible tactile minimale d'une cellule de jour (**48** — AD-13/NFR-S6).
  ///
  /// 🔴 **Ce n'est PAS une valeur du legacy** : le legacy pose un
  /// `GestureDetector` sur un `Container` dont la hauteur n'est **contrainte par
  /// rien** (`daily_tasks_page.dart:159-231`) — à fort rétrécissement de texte,
  /// sa cible passe sous le plancher. Le socle la contraint, et la garde le
  /// mesure sur la **géométrie rendue**, pas sur la présence d'un widget.
  ///
  /// Jeton dédié, POSÉ et lu par [zDailyTasksChromeOf] :
  /// `ZcrudTheme.dailyTasksMinTapTarget` (`double?`) — interpolé en
  /// **plancher** (`_lerpNullableFloor`), jamais matérialisé à `0`.
  static const double minTapTarget = 48;

  /// Écart intitulé de jour → numéro (**4** — `daily_tasks_page.dart:208`).
  static const double weekdayGap = 4;

  /// Écart numéro → mois (**2** — `daily_tasks_page.dart:222`).
  static const double monthGap = 2;

  /// Largeur en deçà de laquelle le mois n'est **pas** rendu (**600** —
  /// `daily_tasks_page.dart:145`, `constraints.maxWidth < 600`).
  ///
  /// Le legacy y change AUSSI le format d'intitulé (`'E'` vs `'EEEE'`) : ce
  /// choix-là appartient à l'hôte, qui reçoit la largeur ambiante et formate
  /// lui-même (aucun `DateFormat` dans le socle — cf. FR-26).
  ///
  /// Jeton dédié, POSÉ et lu par [zDailyTasksChromeOf] :
  /// `ZcrudTheme.dailyTasksMonthBreakpoint` (`double?`).
  static const double monthBreakpoint = 600;

  /// Graisse de l'intitulé de jour (`bold` — `daily_tasks_page.dart:199`).
  static const FontWeight weekdayFontWeight = FontWeight.bold;

  /// Graisse du numéro de jour SÉLECTIONNÉ (`bold` —
  /// `daily_tasks_page.dart:213-215`).
  static const FontWeight selectedDayFontWeight = FontWeight.bold;

  /// Graisse du numéro de jour non sélectionné (`normal` — même site).
  static const FontWeight dayFontWeight = FontWeight.normal;

  // ── Liste des tâches ──────────────────────────────────────────────────────

  /// Padding d'une ligne de tâche (**12 / 6**, directionnel —
  /// `daily_tasks_page.dart:674`).
  ///
  /// Jeton dédié, POSÉ et lu par [zDailyTasksChromeOf] :
  /// `ZcrudTheme.dailyTasksItemPadding`.
  static const EdgeInsetsGeometry itemPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6);

  /// Plancher de contraste des premiers plans TEXTE (**4.5:1**, WCAG 2.2
  /// §1.4.3 AA) — utilisé par la garde de divergence ②, jamais par le rendu.
  static const double textMinContrast = 4.5;

  // ⚠️ Pas de constante « note d'audit » ici, et c'est MESURÉ : une première
  // rédaction en portait une, dont la VALEUR citait le `Colors.grey` du legacy.
  // La garde anti-couleurs (`z_widgets_hardcode_scan_test.dart`) l'a attrapée —
  // à raison : son scanner ignore les commentaires mais lit les chaînes, et il
  // ne peut pas distinguer une citation d'un usage. La note vit donc dans la
  // dartdoc de tête (§ divergence ①), là où elle est prose et non donnée.

  // ── Ce que ce fichier ne contient PAS, et pourquoi ─────────────────────────
  //
  // * Les « actions rapides » (`_QuickActionsWidget`,
  //   `daily_tasks_page.dart:900-1050`) : le legacy en pose QUATRE dont TROIS
  //   sont `enabled: false` (l.917 / l.925 / l.933). Porter une commande morte
  //   serait porter un défaut — AD-4 : une capacité absente est ABSENTE.
  // * Le `DottedBorder` de l'état vide (`daily_tasks_page.dart:581`) : il vient
  //   d'un paquet tiers que `zcrud_study` ne tire pas, et l'état vide est
  //   INJECTÉ par l'hôte (FR-26) — le socle n'en dessine aucun.
  // * Tout `DateFormat` : le formatage de date est de l'i18n, donc de l'hôte.
}

/// Chrome de référence RÉSOLU de la vue des tâches du jour : chaque champ
/// applique la priorité **paramètre > jeton > référence**, et toute couleur est
/// un RÔLE du `ColorScheme` courant (FR-26). Produit par [zDailyTasksChromeOf].
@immutable
class ZDailyTasksChrome {
  /// Construit un chrome résolu (usage interne à la vue).
  const ZDailyTasksChrome({
    required this.bandPadding,
    required this.dayCellMargin,
    required this.dayCellPadding,
    required this.dayCellRadius,
    required this.borderWidth,
    required this.selectedBorderWidth,
    required this.minTapTarget,
    required this.monthBreakpoint,
    required this.weekdayGap,
    required this.monthGap,
    required this.itemPadding,
    required this.cellColor,
    required this.selectedCellColor,
    required this.borderColor,
    required this.selectedBorderColor,
    required this.weekdayStyle,
    required this.selectedWeekdayStyle,
    required this.dayStyle,
    required this.selectedDayStyle,
    required this.monthStyle,
  });

  /// Padding effectif du bandeau.
  final EdgeInsetsGeometry bandPadding;

  /// Marge externe effective d'une cellule de jour.
  final EdgeInsetsGeometry dayCellMargin;

  /// Padding interne effectif d'une cellule de jour.
  final EdgeInsetsGeometry dayCellPadding;

  /// Rayon effectif d'une cellule de jour.
  final Radius dayCellRadius;

  /// Épaisseur effective du liseré non sélectionné.
  final double borderWidth;

  /// Épaisseur effective du liseré sélectionné.
  final double selectedBorderWidth;

  /// Cible tactile minimale effective (AD-13).
  final double minTapTarget;

  /// Largeur de bascule d'affichage du mois.
  final double monthBreakpoint;

  /// Écart effectif intitulé → numéro.
  final double weekdayGap;

  /// Écart effectif numéro → mois.
  final double monthGap;

  /// Padding effectif d'une ligne de tâche.
  final EdgeInsetsGeometry itemPadding;

  /// Fond d'une cellule NON sélectionnée (`CardTheme`, repli rôle `surface`).
  final Color cellColor;

  /// Fond d'une cellule SÉLECTIONNÉE (rôle `primaryContainer`).
  final Color selectedCellColor;

  /// Liseré d'une cellule NON sélectionnée (rôle `outlineVariant` —
  /// divergence ① : le legacy y pose un gris constant).
  final Color borderColor;

  /// Liseré d'une cellule SÉLECTIONNÉE (rôle `primary`).
  final Color selectedBorderColor;

  /// Style de l'intitulé de jour non sélectionné.
  final TextStyle? weekdayStyle;

  /// Style de l'intitulé de jour sélectionné.
  final TextStyle? selectedWeekdayStyle;

  /// Style du numéro de jour non sélectionné.
  final TextStyle? dayStyle;

  /// Style du numéro de jour sélectionné.
  final TextStyle? selectedDayStyle;

  /// Style du libellé de mois (rendu au-delà de [monthBreakpoint] seulement).
  final TextStyle? monthStyle;
}

/// Résout le chrome de la vue des tâches du jour depuis le contexte (rôles du
/// `ColorScheme`), avec surcharge ponctuelle par les paramètres de la vue.
///
/// 🔒 **Chaîne complète, champ par champ : `paramètre ?? jeton ?? référence`.**
/// Le maillon du milieu (`ZcrudTheme.dailyTasks*`) est branché ICI et nulle part
/// ailleurs : un hôte règle donc la vue depuis son thème, sans repasser un
/// paramètre à chaque montage.
///
/// 🚫 **Aucun jeton GÉNÉRIQUE n'est monté en maillon** — pas de `gapM` pour un
/// écart, pas de `radiusM` pour le rayon de cellule. C'est le défaut que
/// CR-IFFD-61 a corrigé sur les cartes d'étude : un jeton générique ridé par
/// deux propriétés distinctes ne peut satisfaire ni l'une ni l'autre. Chaque
/// jeton lu ici est **dédié** à sa propriété ; les champs sans jeton dédié
/// ([ZDailyTasksReference.borderWidth], les écarts, les graisses) gardent
/// franchement DEUX maillons plutôt que d'en simuler trois.
ZDailyTasksChrome zDailyTasksChromeOf(
  BuildContext context, {
  EdgeInsetsGeometry? bandPadding,
  EdgeInsetsGeometry? dayCellMargin,
  EdgeInsetsGeometry? dayCellPadding,
  Radius? dayCellRadius,
  double? minTapTarget,
  double? monthBreakpoint,
  EdgeInsetsGeometry? itemPadding,
}) {
  final ThemeData material = Theme.of(context);
  final ColorScheme scheme = material.colorScheme;
  final TextTheme text = material.textTheme;
  final ZcrudTheme theme = ZcrudTheme.of(context);
  // ② — PARITÉ avec le legacy (`daily_tasks_page.dart:201`/`:217`) : `primary`
  // sur `primaryContainer`. Ce n'est PAS l'appariement nominal M3, et c'est
  // assumé : la mesure a établi qu'il tient le plancher AA partout (pire cas
  // 4.97 sur 12 graines × 2 luminosités). Une garde le vérifie ; aucune
  // divergence n'est introduite pour une simple préférence.
  final Color onSelected = scheme.primary;
  final Color neutral = scheme.onSurfaceVariant;
  return ZDailyTasksChrome(
    bandPadding:
        bandPadding ??
        theme.dailyTasksBandPadding ??
        ZDailyTasksReference.bandPadding,
    dayCellMargin:
        dayCellMargin ??
        theme.dailyTasksDayCellMargin ??
        ZDailyTasksReference.dayCellMargin,
    dayCellPadding:
        dayCellPadding ??
        theme.dailyTasksDayCellPadding ??
        ZDailyTasksReference.dayCellPadding,
    dayCellRadius:
        dayCellRadius ??
        theme.dailyTasksDayCellRadius ??
        ZDailyTasksReference.dayCellRadius,
    borderWidth: ZDailyTasksReference.borderWidth,
    selectedBorderWidth: ZDailyTasksReference.selectedBorderWidth,
    minTapTarget:
        minTapTarget ??
        theme.dailyTasksMinTapTarget ??
        ZDailyTasksReference.minTapTarget,
    monthBreakpoint:
        monthBreakpoint ??
        theme.dailyTasksMonthBreakpoint ??
        ZDailyTasksReference.monthBreakpoint,
    weekdayGap: ZDailyTasksReference.weekdayGap,
    monthGap: ZDailyTasksReference.monthGap,
    itemPadding:
        itemPadding ??
        theme.dailyTasksItemPadding ??
        ZDailyTasksReference.itemPadding,
    // Le legacy lit `theme.cardColor` : le pendant M3 est la couleur du
    // `CardTheme` ambiant, avec le rôle `surface` en repli (jamais un littéral).
    cellColor: CardTheme.of(context).color ?? scheme.surface,
    selectedCellColor: scheme.primaryContainer,
    borderColor: scheme.outlineVariant,
    selectedBorderColor: scheme.primary,
    weekdayStyle: text.bodySmall?.copyWith(
      fontWeight: ZDailyTasksReference.weekdayFontWeight,
      color: neutral,
    ),
    selectedWeekdayStyle: text.bodySmall?.copyWith(
      fontWeight: ZDailyTasksReference.weekdayFontWeight,
      color: onSelected,
    ),
    dayStyle: text.titleMedium?.copyWith(
      fontWeight: ZDailyTasksReference.dayFontWeight,
      color: neutral,
    ),
    selectedDayStyle: text.titleMedium?.copyWith(
      fontWeight: ZDailyTasksReference.selectedDayFontWeight,
      color: onSelected,
    ),
    monthStyle: text.labelSmall,
  );
}
