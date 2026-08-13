/// Actions de **lot** DÉCLARÉES en données + barre d'actions neutre.
///
/// Suit le même patron qu'un menu d'action **par item** (« action déclarée en
/// donnée, `onSelected == null ⇒ ABSENTE » ») étendu au **lot**, sans
/// partager de type avec un tel menu applicatif : une arête core→satellite
/// serait un cycle AD-1, la variance de type entre les deux est donc assumée.
///
/// Invariants (AD-2/AD-4/AD-13/AD-15) : AUCUN gestionnaire d'état ; labels/icônes
/// INJECTÉS (i18n, jamais codés en dur) ; nature = **enum** extensible additif
/// (jamais un booléen) ; `onSelected == null` ⇒ action ABSENTE (jamais un bouton
/// grisé par simple oubli de callback — l'inertie, elle, se DÉCLARE :
/// `ZBatchAction.enabled: false`, et l'action garde alors sa place en annonçant
/// son motif) ; cibles ≥ 48 dp ; `Semantics` explicites ; directionnel ; thème
/// injecté (`ZcrudTheme.of`, repli `Theme.of`). La barre lit la SEULE tranche
/// `selectedIds`/`selectedCount` du contrôleur **détenu par la liste**
/// (propriétaire UNIQUE, AD-2) via `ValueListenableBuilder` (rebuild ciblé) —
/// elle ne détient AUCUN état de sélection.
library;

import 'package:flutter/material.dart';

import '../theme/z_theme.dart';
import 'z_list_selection.dart';

/// Cible de taille interactive minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Emprise horizontale RÉSERVÉE par la barre pour UN bouton d'action.
///
/// `_BarButton` contraint son `IconButton` à `minWidth: _kMinTapTarget` ; un
/// `IconButton` Material par défaut (glyphe 24 dp + rembourrage 8 dp) mesure
/// 40 dp et est donc porté à EXACTEMENT 48 dp par cette contrainte. La barre
/// réserve un « créneau » de cette largeur par bouton pour décider du repli
/// (cf. [ZBatchActionBar]) — un thème hôte qui gonflerait `IconButton` au-delà
/// de 48 dp sortirait de ce contrat (le compteur `Flexible` absorbe alors le
/// dépassement résiduel, cf. `build`).
const double _kActionSlot = _kMinTapTarget;

/// Nature d'une action de **lot** — enum EXTENSIBLE additif (AD-4).
///
/// [delete]/[restore]/[move] sont les natures intégrées ; [custom] couvre toute
/// action applicative hors nomenclature (l'appelant porte le
/// [ZBatchAction.label]/[icon] et le callback). Un membre neuf est
/// **non-breaking** : aucun `switch` exhaustif sur ce type n'existe dans le cœur
/// (grep négatif — la barre filtre sur `onSelected`, elle ne branche pas par
/// nature).
enum ZBatchActionKind {
  /// Supprimer les éléments sélectionnés (voie `batchDelete` — cascade injectée).
  delete,

  /// **Restaurer** les éléments sélectionnés — le geste inverse de [delete],
  /// celui d'un listing de corbeille.
  ///
  /// Sans ce membre, une barre de corbeille devait déclarer sa restauration en
  /// [custom], c'est-à-dire annoncer « hors nomenclature » un geste qui est
  /// exactement le pendant du plus intégré de tous. La nature d'une action de
  /// lot sert à la reconnaître (journalisation, télémétrie, décoration d'un
  /// hôte) : [custom] y perdait cette information.
  restore,

  /// Déplacer les éléments sélectionnés (voie `batchMove` — destination injectée).
  move,

  /// Action de lot applicative hors nomenclature.
  custom,
}

/// Une action de lot — data-class de présentation immuable (`const`).
///
/// [label]/[icon] sont INJECTÉS (i18n, jamais codés en dur). [onSelected] `null`
/// ⇒ action ABSENTE de la barre (AD-4). L'action s'exécute sur la sélection
/// COURANTE : l'appelant (qui détient le contrôleur) lit la sélection dans
/// son callback (ex. via `batchDelete`/`batchMove`/`applyCommonField`).
///
/// **Absente ou inerte, deux choses distinctes** — c'est le même partage que
/// pour une action de ligne (`ZResolvedRowAction`) :
///
/// | Déclaration | Rendu |
/// |---|---|
/// | `onSelected == null` | l'action **n'existe pas** dans la barre |
/// | [enabled] `== false` | l'action **garde sa place**, grisée, non actionnable, et annonce son motif |
///
/// La première forme sert au masquage ; la seconde à l'inertie — celle qu'un
/// mode d'ACL « désactiver » attend, où l'utilisateur doit voir que le geste
/// existe et apprendre pourquoi il lui est fermé.
@immutable
class ZBatchAction {
  /// Construit une action de lot.
  const ZBatchAction({
    required this.kind,
    required this.label,
    required this.icon,
    this.onSelected,
    this.enabled = true,
    this.disabledReason,
  });

  /// Nature de l'action ([ZBatchActionKind]).
  final ZBatchActionKind kind;

  /// Libellé LOCALISÉ INJECTÉ (i18n, AD-13/FR-23).
  final String label;

  /// Glyphe INJECTÉ de l'action (jamais codé en dur).
  final IconData icon;

  /// Callback d'exécution. `null` ⇒ action ABSENTE de la barre (AD-4).
  final VoidCallback? onSelected;

  /// `false` ⇒ l'action est rendue **inerte** : présente, grisée, non
  /// actionnable, et annoncée comme désactivée (`Semantics(enabled: false)`).
  /// [onSelected] n'est alors **jamais** invoqué — l'inertie porte sur
  /// l'apparence *et* sur l'effet.
  ///
  /// Défaut `true` ⇒ comportement strictement inchangé.
  final bool enabled;

  /// Motif LOCALISÉ INJECTÉ du refus, annoncé en `Semantics.hint` quand
  /// [enabled] est `false` (`null` ⇒ aucun motif annoncé). Ignoré tant que
  /// l'action est active.
  final String? disabledReason;
}

/// Barre d'actions de **lot** neutre.
///
/// **Propriétaire UNIQUE** : reçoit le [controller] détenu par la surface de
/// liste — elle ne le crée jamais, ne le `dispose` jamais. Lit la SEULE tranche
/// `selectedIds` via `ValueListenableBuilder` (rebuild ciblé) et rend : un
/// **badge compteur** ([selectedCount]), un bouton « tout sélectionner »
/// (présent SEULEMENT si [onSelectAll] non `null`), puis les [actions] déclarées
/// dont `onSelected != null`.
///
/// **Résilience à la contrainte de largeur** : la rangée ne coupe jamais
/// son contenu sur une largeur réduite (une rangée non résiliente lève un
/// `RenderFlex overflowed` dès que trop d'actions sont déclarées pour la
/// largeur disponible). Deux mécanismes, tous deux INACTIFS tant
/// que la largeur suffit (rendu identique) :
///
/// 1. le **badge compteur est `Flexible`** — un libellé localisé long se rétrécit
///    (ellipse) au lieu de pousser les boutons hors du cadre ;
/// 2. **repli en menu de dépassement** — sous `LayoutBuilder`, si les boutons ne
///    tiennent pas dans la largeur disponible, les DERNIERS basculent dans un
///    `PopupMenuButton` (un créneau de [_kActionSlot] lui est réservé).
///
/// La convention de dépassement suit celle de `ZAppBarAction.isOverflow`
/// (`zcrud_ui_kit`) — même présentation (`Icons.more_vert` + entrées
/// `icône + libellé`) — mais elle est **INSPIRÉE, jamais importée** : une arête
/// `zcrud_core → zcrud_ui_kit` violerait AD-1 (CORE OUT = 0). Différence
/// assumée : `isOverflow` est un choix DÉCLARÉ par l'appelant, ici le repli est
/// PILOTÉ PAR LA LARGEUR (l'appelant ne peut pas connaître la largeur de rendu).
/// Les actions repliées restent atteignables ET annoncées (chaque entrée porte
/// son libellé visible ; le bouton de dépassement porte [overflowLabel], à
/// défaut le libellé localisé que `PopupMenuButton` applique lui-même —
/// `MaterialLocalizations.showMenuTooltip`).
class ZBatchActionBar extends StatelessWidget {
  /// Construit la barre.
  ///
  /// [controller] : contrôleur de sélection DÉTENU par la liste (jamais recréé
  /// ici). [actions] : actions candidates (ordre préservé ; celles à
  /// `onSelected == null` sont FILTRÉES). [countLabelBuilder] : construit le
  /// libellé LOCALISÉ du badge à partir du compteur (INJECTÉ ; repli neutre au
  /// nombre brut si `null`). [selectAllLabel]/[onSelectAll] : label INJECTÉ +
  /// callback « tout sélectionner » (bouton ABSENT si `onSelectAll == null`).
  const ZBatchActionBar({
    required this.controller,
    required this.actions,
    this.countLabelBuilder,
    this.selectAllLabel,
    this.onSelectAll,
    this.overflowLabel,
    super.key,
  }) : assert(
          onSelectAll == null || selectAllLabel != null,
          'ZBatchActionBar: selectAllLabel (nom accessible a11y, AD-13) DOIT '
          'être fourni dès que onSelectAll l\'est — jamais un bouton « tout '
          'sélectionner » actionnable mais MUET pour un lecteur d\'écran '
          '(récidive su-9). Fournir selectAllLabel avec onSelectAll.',
        );

  /// Contrôleur de sélection détenu par la liste (source de vérité UNIQUE).
  final ZListSelectionController controller;

  /// Actions candidates (celles à [ZBatchAction.onSelected] `null` sont ABSENTES).
  final List<ZBatchAction> actions;

  /// Construit le libellé LOCALISÉ du badge compteur (INJECTÉ). `null` ⇒ nombre
  /// brut (repli neutre).
  final String Function(int selectedCount)? countLabelBuilder;

  /// Label LOCALISÉ INJECTÉ de « tout sélectionner » (a11y + tooltip).
  ///
  /// **OBLIGATOIRE dès que [onSelectAll] est fourni** (assert en constructeur) :
  /// un bouton « tout sélectionner » actionnable SANS nom accessible est
  /// proscrit — muet pour un lecteur d'écran. Ignoré si [onSelectAll] est
  /// `null` (bouton absent).
  final String? selectAllLabel;

  /// Callback « tout sélectionner ». `null` ⇒ bouton ABSENT (AD-4). Non-`null`
  /// ⇒ [selectAllLabel] DOIT l'être aussi (nom accessible a11y, AD-13).
  final VoidCallback? onSelectAll;

  /// Label LOCALISÉ INJECTÉ du bouton de **dépassement** (a11y + tooltip).
  ///
  /// N'a d'effet que sur une largeur trop étroite pour toutes les actions.
  /// `null` ⇒ le libellé localisé STANDARD
  /// `MaterialLocalizations.showMenuTooltip` appliqué par `PopupMenuButton`
  /// lui-même (jamais une chaîne codée en dur ; jamais un bouton MUET pour un
  /// lecteur d'écran).
  final String? overflowLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // AD-4 — action sans callback ⇒ ABSENTE (jamais rendue grisée/no-op).
    final visible =
        actions.where((a) => a.onSelected != null).toList(growable: false);
    return ValueListenableBuilder<Set<String>>(
      valueListenable: controller.selectedIds,
      builder: (context, selected, _) {
        final count = selected.length;
        final countLabel = countLabelBuilder?.call(count) ?? '$count';
        // a11y (AD-13) : le badge compteur est annoncé UNE
        // seule fois — par le `Text(countLabel)` visible ci-dessous. On ne
        // porte PAS `label: countLabel` sur ce `Semantics` conteneur : il
        // FUSIONNERAIT avec le libellé du `Text` enfant et le compteur serait
        // annoncé DEUX FOIS (« 3 sélectionné(s) 3 sélectionné(s) »). Le
        // conteneur ne fait que grouper la barre (frontière sémantique), sans
        // libellé propre.
        // Entrées de barre, ordre PRÉSERVÉ : « tout sélectionner » (si fourni)
        // puis les actions visibles. Le repli de dépassement mord par la FIN.
        final entries = <_BarEntry>[
          if (onSelectAll != null)
            _BarEntry(
              icon: Icons.select_all,
              label: selectAllLabel!,
              onPressed: onSelectAll!,
            ),
          for (final action in visible)
            _BarEntry(
              icon: action.icon,
              label: action.label,
              onPressed: action.onSelected!,
              enabled: action.enabled,
              disabledReason: action.enabled ? null : action.disabledReason,
            ),
        ];
        return Semantics(
          container: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Combien de boutons tiennent réellement ? Sur une
              // largeur INFINIE (Row/ListView horizontal hôte) aucune contrainte
              // ne s'applique : tout reste en ligne (rendu inchangé).
              var inlineCount = entries.length;
              if (constraints.maxWidth.isFinite) {
                final slots = (constraints.maxWidth / _kActionSlot).floor();
                if (slots < entries.length) {
                  // Un créneau est RÉSERVÉ au bouton de dépassement lui-même.
                  inlineCount = slots > 0 ? slots - 1 : 0;
                }
              }
              final overflow = entries.sublist(inlineCount);
              return Row(
                children: [
                  // Badge compteur (tranche réactive `selectedCount`).
                  // `Flexible` : un libellé localisé long se
                  // rétrécit au lieu de pousser les boutons hors du cadre. Sur
                  // une largeur suffisante il reçoit sa largeur intrinsèque —
                  // rendu INCHANGÉ.
                  Flexible(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(end: theme.gapM),
                      child: Text(
                        countLabel,
                        textAlign: TextAlign.start,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  for (final entry in entries.take(inlineCount))
                    _BarButton(
                      icon: entry.icon,
                      label: entry.label,
                      onPressed: entry.enabled ? entry.onPressed : null,
                      disabledReason: entry.disabledReason,
                    ),
                  if (overflow.isNotEmpty)
                    _OverflowMenu(entries: overflow, label: overflowLabel),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Entrée de barre RÉSOLUE (callback non-`null` : les actions ABSENTES ont déjà
/// été filtrées). Purement interne — sert au repli de dépassement.
@immutable
class _BarEntry {
  const _BarEntry({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.disabledReason,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// `false` ⇒ entrée rendue INERTE (grisée, non actionnable) — jamais absente.
  final bool enabled;

  /// Motif du refus annoncé en `Semantics.hint` (entrée inerte seulement).
  final String? disabledReason;
}

/// Menu de **dépassement** de la barre — présentation calquée sur un patron
/// de menu de dépassement satellite (`zcrud_ui_kit`) SANS l'importer (AD-1).
///
/// a11y (AD-13) : le bouton porte un `tooltip` (nom accessible + `button:
/// true` fournis par `PopupMenuButton`), jamais un `Semantics(label:)`
/// supplémentaire qui DOUBLERAIT l'annonce. Chaque entrée du menu
/// porte son libellé VISIBLE — une action repliée reste annoncée, jamais
/// invisible au lecteur d'écran. Cible ≥ 48 dp. Aucune couleur littérale
/// codée en dur : le menu hérite du thème.
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.entries, this.label});

  final List<_BarEntry> entries;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // `tooltip: null` n'est PAS un bouton muet : `PopupMenuButton` applique
    // lui-même `?? MaterialLocalizations.of(context).showMenuTooltip`
    // (popup_menu.dart) — le nom accessible de repli est donc LOCALISÉ par le
    // framework, jamais une chaîne codée en dur ici. On se garde
    // bien de dupliquer ce repli : un `?? showMenuTooltip` local serait du code
    // MORT, indistinguable de son absence.
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _kMinTapTarget,
        minHeight: _kMinTapTarget,
      ),
      // Résolution par IDENTITÉ, JAMAIS par position. La valeur
      // portée par chaque entrée est l'ENTRÉE ELLE-MÊME, pas son index : le
      // callback invoqué est donc TOUJOURS celui de l'action que l'utilisateur
      // a vue et touchée. Un `PopupMenuButton<int>` + `entries[i].onPressed()`
      // relisait la liste APRÈS coup — un rebuild qui RÉORDONNE entre
      // l'ouverture et la sélection exécutait une AUTRE action (silencieusement),
      // et un rebuild qui RACCOURCIT la liste levait un `RangeError` DANS un
      // gestionnaire de tap. C'est la même lecture que `ZDefaultMenuRenderer`
      // (`zcrud_menu`, `PopupMenuButton<ZMenuEntry>`) — que l'on ne peut PAS
      // importer ici (AD-1 : `zcrud_core` a un out-degree zcrud de 0), d'où
      // l'adoption de la SÉMANTIQUE, pas de la couture.
      child: PopupMenuButton<_BarEntry>(
        icon: const Icon(Icons.more_vert),
        tooltip: label,
        itemBuilder: (context) => <PopupMenuEntry<_BarEntry>>[
          for (final entry in entries)
            PopupMenuItem<_BarEntry>(
              value: entry,
              // Une entrée inerte reste LISTÉE et annoncée : elle ne se
              // sélectionne pas, elle ne disparaît pas.
              enabled: entry.enabled,
              child: Row(
                children: [
                  Icon(entry.icon),
                  SizedBox(width: theme.gapM),
                  Flexible(
                    child: Text(
                      entry.label,
                      textAlign: TextAlign.start,
                    ),
                  ),
                ],
              ),
            ),
        ],
        onSelected: (entry) => entry.onPressed(),
      ),
    );
  }
}

/// Bouton d'action de barre — cible ≥ 48 dp, label a11y via le `tooltip` de
/// `IconButton` (qui porte DÉJÀ `button: true` + le label sémantique). On
/// n'ajoute PAS un `Semantics(label:)` supplémentaire : il FUSIONNERAIT avec
/// celui du tooltip et l'action serait annoncée DEUX FOIS. Directionnel
/// (IconButton neutre).
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    this.label,
    this.onPressed,
    this.disabledReason,
  });

  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;

  /// Motif du refus, annoncé en `hint` quand le bouton est inerte.
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final Widget button = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _kMinTapTarget,
        minHeight: _kMinTapTarget,
      ),
      child: IconButton(
        icon: Icon(icon),
        tooltip: label,
        onPressed: onPressed,
      ),
    );
    // Un `IconButton` sans callback est DÉJÀ annoncé désactivé par Material :
    // on n'ajoute donc aucun `Semantics(enabled:)` qui doublerait l'annonce.
    // Seul le MOTIF manque au socle — et seulement s'il a été déclaré.
    final reason = disabledReason;
    if (onPressed != null || reason == null) return button;
    // `MergeSemantics` : le motif et le bouton forment UN SEUL nœud. Sans lui,
    // le motif resterait sur un nœud parent — un lecteur d'écran posé sur le
    // bouton annoncerait « désactivé » sans jamais dire pourquoi.
    return MergeSemantics(
      child: Semantics(enabled: false, hint: reason, child: button),
    );
  }
}
