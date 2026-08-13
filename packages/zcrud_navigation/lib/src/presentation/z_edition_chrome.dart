/// **Chrome d'édition** — le porte-valeurs du chrome interne d'un formulaire
/// présenté.
///
/// `zcrud_navigation` sait déjà choisir et ouvrir le **conteneur**
/// (`page`/`sheet`/`dialog`, dérivé du breakpoint). Il ne fournissait pas le
/// chrome interne : titre, actions submit/discard, et surtout le
/// **comportement d'en-tête propre à chaque mode** — un besoin qu'une
/// intégration ad hoc recode habituellement à la main, avec des rendus
/// divergents d'une application à l'autre.
///
/// [ZEditionChrome] est le **descripteur** de ce chrome ; [ZEditionScaffold]
/// (fichier voisin) en fait le rendu **par mode**. Les deux sont **opt-in** :
/// `presentEdition(chrome: null)` — le défaut — rend **exactement** l'arbre
/// d'aujourd'hui (garde d'identité d'arbre, `z_edition_chrome_identity_test`).
///
/// ## Invariants portés par ce fichier
///
/// * **Invariant AD-4 (extension ouverte)** : classe **non-`sealed`,
///   non-`final`**, avec [ZEditionChrome.copyWith] ; un champ `null` signifie
///   **absent de l'arbre** — jamais un `SizedBox.shrink`, jamais un `throw`.
/// * **Invariant AD-10 (repli, jamais d'exception)** : un chrome **partiel**
///   (aucun titre, aucune action) reste rendable ; un mode non prévu retombe
///   sur la forme la plus neutre.
/// * **Aucune couleur codée en dur** ici (que des dimensions et des
///   scalaires), **aucun libellé** codé en dur — les libellés se résolvent par
///   `label(context, 'save'|'cancel'|'close')` de `ZcrudLocalizations`
///   (`zcrud_core`, tables fr/en déjà en place), surchargeables par paramètre.
/// * **Priorité de résolution** (même patron que les autres jetons `ZcrudTheme`) :
///   **paramètre > jeton `ZcrudTheme.*` > défaut-référence
///   [ZEditionChromeReference]**.
/// * **Invariants AD-2/AD-15** : aucun gestionnaire d'état ; Flutter vanilla
///   uniquement — ce fichier n'ajoute **aucune arête** au graphe (`zcrud_core`
///   est déjà une dépendance de `zcrud_navigation`).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZConfirmDiscard,
        ZEditionSubmitController,
        ZFormController,
        ZcrudTheme;

/// Les **valeurs de référence** du chrome d'édition — le point d'audit unique.
///
/// **AUCUNE COULEUR ici** : uniquement des **dimensions**. Chaque couleur du
/// chrome est un **rôle** du `ColorScheme` courant, résolu au rendu.
abstract final class ZEditionChromeReference {
  /// Cible tactile minimale (dp) — invariant AD-13. **Assertée explicitement**
  /// par le chrome (`ConstrainedBox`), jamais empruntée au plancher ambiant du
  /// SDK :
  /// une garde qui mesurerait le 48 du SDK serait vacante.
  static const double minTouchTarget = 48;

  /// Gouttière interne de l'en-tête et de la barre d'actions (dp).
  static const EdgeInsetsDirectional headerPadding =
      EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8);

  /// Gouttière de la barre d'actions en pied (`dialog` / `sheet`).
  static const EdgeInsetsDirectional actionBarPadding =
      EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8);

  /// Dégagement horizontal interne d'une action textuelle (dp).
  static const EdgeInsetsDirectional actionPadding =
      EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0);

  /// Largeur de la poignée de la feuille (dp) — M3.
  static const double dragHandleWidth = 32;

  /// Épaisseur de la poignée de la feuille (dp) — M3.
  static const double dragHandleHeight = 4;

  /// Opacité du rôle `onSurfaceVariant` appliquée à la poignée.
  static const double dragHandleOpacity = 0.4;

  /// Hauteur étendue de l'en-tête repliable du mode `page` (dp).
  static const double pageHeaderExpandedHeight = 112;

  /// Opacité du rôle `onSurface` sur une action **désactivée** (M3 : 0.38).
  /// La couleur n'est jamais le SEUL canal — `Semantics(enabled:)` la double.
  static const double disabledOpacity = 0.38;
}

/// Métriques **résolues** du chrome (paramètre > jeton > référence).
///
/// Porte-valeurs **immuable** consommé par [ZEditionScaffold] ; il ne contient
/// que des dimensions.
@immutable
class ZEditionChromeMetrics {
  /// Construit un jeu de métriques déjà résolu.
  const ZEditionChromeMetrics({
    required this.minTouchTarget,
    required this.headerPadding,
    required this.actionBarPadding,
    required this.actionPadding,
    required this.gap,
    required this.pageHeaderExpandedHeight,
  });

  /// Cible tactile minimale (dp).
  final double minTouchTarget;

  /// Gouttière de l'en-tête.
  final EdgeInsetsGeometry headerPadding;

  /// Gouttière de la barre d'actions.
  final EdgeInsetsGeometry actionBarPadding;

  /// Dégagement interne d'une action.
  final EdgeInsetsGeometry actionPadding;

  /// Écart entre deux actions voisines (dp).
  final double gap;

  /// Hauteur étendue de l'en-tête repliable (`page`).
  final double pageHeaderExpandedHeight;
}

/// Résout les métriques du chrome — **paramètre > jeton `ZcrudTheme` >
/// référence [ZEditionChromeReference]**.
///
/// ## Le maillon JETON, et ce qu'il ne couvre PAS
///
/// Quatre des six métriques ont un jeton dédié dans `ZcrudTheme`
/// (`editionChromeMinTouchTarget`, `editionChromeHeaderPadding`,
/// `editionChromeActionBarPadding`, `editionChromePageHeaderExpandedHeight`) —
/// tous **nullables et absents de `ZcrudTheme.fallback()`**, donc **aucun hôte
/// passif ne bouge**.
///
/// Les deux autres n'en ont **délibérément pas** :
///
/// * **[ZEditionChromeMetrics.gap]** lit déjà `ZcrudTheme.gapM`, jeton
///   générique **existant** et réglable à l'échelle de l'app. Un
///   `editionChromeGap` serait un **second canal pour la même propriété** —
///   exactement le motif de divergence que ce dépôt s'interdit ailleurs
///   (cf. `z_sheet_frame.dart`).
/// * **[ZEditionChromeMetrics.actionPadding]** est le dégagement interne d'un
///   seul widget d'action : un micro-détail de rendu, pas une décision de
///   design prise à l'échelle d'une app. Il reste entièrement surchargeable —
///   par ce paramètre, et par `ZEditionScaffold.metrics`.
///
/// Les dimensions de la poignée M3 et les opacités d'état désactivé de
/// [ZEditionChromeReference] ne figurent même pas dans [ZEditionChromeMetrics] :
/// ce sont des constantes M3, pas des réglages.
ZEditionChromeMetrics zEditionChromeMetricsOf(
  BuildContext context, {
  double? minTouchTarget,
  EdgeInsetsGeometry? headerPadding,
  EdgeInsetsGeometry? actionBarPadding,
  EdgeInsetsGeometry? actionPadding,
  double? gap,
  double? pageHeaderExpandedHeight,
}) {
  final ZcrudTheme theme = ZcrudTheme.of(context);
  return ZEditionChromeMetrics(
    minTouchTarget: minTouchTarget ??
        theme.editionChromeMinTouchTarget ??
        ZEditionChromeReference.minTouchTarget,
    headerPadding: headerPadding ??
        theme.editionChromeHeaderPadding ??
        ZEditionChromeReference.headerPadding,
    actionBarPadding: actionBarPadding ??
        theme.editionChromeActionBarPadding ??
        ZEditionChromeReference.actionBarPadding,
    actionPadding: actionPadding ?? ZEditionChromeReference.actionPadding,
    gap: gap ?? theme.gapM,
    pageHeaderExpandedHeight: pageHeaderExpandedHeight ??
        theme.editionChromePageHeaderExpandedHeight ??
        ZEditionChromeReference.pageHeaderExpandedHeight,
  );
}

/// Descripteur du **chrome interne** d'un formulaire d'édition présenté.
///
/// Tous les champs sont **optionnels** : un chrome vide (`ZEditionChrome()`)
/// rend un en-tête sans titre ni action — **jamais** un `throw`, **jamais** un
/// `SizedBox.shrink` de remplissage (invariants AD-4/AD-10).
///
/// ## Branchement sur le cœur (aucune arête nouvelle)
///
/// * [submitController] : `ZEditionSubmitController` de `zcrud_core` — quand il
///   est fourni, l'action d'enregistrement **écoute son état** (rebuild ciblé,
///   invariant AD-2 : elle n'écoute QUE `state`) et se désactive pendant
///   `inProgress`.
/// * [formController] + [onConfirmDiscard] : `ZDiscardGuard` de `zcrud_core` —
///   quand [formController] est fourni, [ZEditionScaffold] enveloppe **tout**
///   le chrome dans un `ZDiscardGuard`, et `presentEdition` **neutralise les
///   voies de fermeture implicites qui court-circuitent `PopScope`**
///   (mesuré : la fermeture d'une feuille **par glissement** appelle
///   `Navigator.pop` — jamais `maybePop` — et perd donc la saisie sans
///   confirmation).
class ZEditionChrome {
  /// Construit un descripteur de chrome. Tout est optionnel (invariants
  /// AD-4/AD-10).
  const ZEditionChrome({
    this.title,
    this.submitLabel,
    this.discardLabel,
    this.onSubmit,
    this.onDiscard,
    this.submitController,
    this.formController,
    this.onConfirmDiscard,
    this.extraActions = const <Widget>[],
    this.showDragHandle = true,
  });

  /// Titre affiché dans l'en-tête. `null` ⇒ **absent de l'arbre** (aucun nœud
  /// de titre n'est construit).
  final String? title;

  /// Libellé de l'action d'enregistrement. `null` ⇒ `label(context, 'save')`
  /// (`ZcrudLocalizations`, fr/en) — **jamais** une chaîne codée en dur ici.
  final String? submitLabel;

  /// Libellé de l'action d'abandon. `null` ⇒ `label(context, 'cancel')`.
  final String? discardLabel;

  /// Callback d'enregistrement. `null` **et** [submitController] `null` ⇒
  /// aucune action d'enregistrement dans l'arbre.
  final VoidCallback? onSubmit;

  /// Callback d'abandon. `null` ⇒ repli `Navigator.maybePop` (voie qui honore
  /// `PopScope`, donc [ZFormController] via `ZDiscardGuard`).
  final VoidCallback? onDiscard;

  /// Contrôleur de soumission du cœur. Covariance Dart : un
  /// `ZEditionSubmitController<MonEntité>` s'y range sans conversion.
  final ZEditionSubmitController<Object?>? submitController;

  /// Contrôleur de formulaire dont l'état *dirty* arme `ZDiscardGuard`.
  /// `null` ⇒ **aucun** garde d'abandon (et aucune neutralisation du
  /// glissement).
  final ZFormController? formController;

  /// Seam applicatif de confirmation d'abandon (dialogue fourni par l'app).
  final ZConfirmDiscard? onConfirmDiscard;

  /// Actions supplémentaires placées **avant** l'action d'enregistrement.
  ///
  /// Elles sont rendues **exactement une fois**, dans **tous** les modes, dans
  /// la rangée des actions positives — jamais en plus dans l'en-tête :
  ///
  /// | `mode`   | Emplacement à l'écran                                    |
  /// |----------|----------------------------------------------------------|
  /// | `page`   | `actions` de l'en-tête repliable, avant l'enregistrement  |
  /// | `dialog` | barre d'actions **en pied**, avant l'enregistrement       |
  /// | `sheet`  | barre d'actions **en pied** (`SafeArea`), avant l'enregistrement |
  ///
  /// Liste vide (le défaut) ⇒ **rien** dans l'arbre (invariant AD-4). Ces
  /// widgets sont rendus tels quels : c'est à l'appelant de leur donner leur
  /// cible tactile (≥ 48 dp) et leur `Semantics` (invariant AD-13).
  final List<Widget> extraActions;

  /// Affiche la poignée M3 en mode `sheet`. `false` ⇒ poignée **absente de
  /// l'arbre**.
  final bool showDragHandle;

  /// `true` ssi un `ZDiscardGuard` doit être armé — c'est **le seul** critère
  /// qui déclenche la neutralisation des fermetures implicites non gardées.
  bool get guardsDiscard => formController != null;

  /// `true` ssi une action d'enregistrement doit exister dans l'arbre.
  bool get hasSubmitAction => onSubmit != null || submitController != null;

  /// Copie modifiée (invariant AD-4 : extension par composition, jamais par
  /// héritage sérialisé).
  ZEditionChrome copyWith({
    String? title,
    String? submitLabel,
    String? discardLabel,
    VoidCallback? onSubmit,
    VoidCallback? onDiscard,
    ZEditionSubmitController<Object?>? submitController,
    ZFormController? formController,
    ZConfirmDiscard? onConfirmDiscard,
    List<Widget>? extraActions,
    bool? showDragHandle,
  }) =>
      ZEditionChrome(
        title: title ?? this.title,
        submitLabel: submitLabel ?? this.submitLabel,
        discardLabel: discardLabel ?? this.discardLabel,
        onSubmit: onSubmit ?? this.onSubmit,
        onDiscard: onDiscard ?? this.onDiscard,
        submitController: submitController ?? this.submitController,
        formController: formController ?? this.formController,
        onConfirmDiscard: onConfirmDiscard ?? this.onConfirmDiscard,
        extraActions: extraActions ?? this.extraActions,
        showDragHandle: showDragHandle ?? this.showDragHandle,
      );
}
