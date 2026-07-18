/// Actions de **lot** DÉCLARÉES en données + barre d'actions neutre (me-1, AD-44).
///
/// origine: pendant GÉNÉRIQUE de `ZItemActionsMenu` (`zcrud_study`, actions PAR
/// item) porté dans le cœur pour le **lot**. Duplication VOULUE : une arête
/// core→study serait un cycle AD-1 — la variance est assumée (les deux modèles
/// partagent le patron « action déclarée en donnée, `onSelected == null ⇒
/// ABSENTE » sans partager de type).
///
/// Invariants (AD-2/AD-4/AD-13/AD-15) : AUCUN gestionnaire d'état ; labels/icônes
/// INJECTÉS (i18n, jamais codés en dur) ; nature = **enum** extensible additif
/// (jamais un booléen) ; `onSelected == null` ⇒ action ABSENTE (jamais un bouton
/// grisé/no-op) ; cibles ≥ 48 dp ; `Semantics` explicites ; directionnel ; thème
/// injecté (`ZcrudTheme.of`, repli `Theme.of`). La barre lit la SEULE tranche
/// `selectedIds`/`selectedCount` du contrôleur **détenu par la liste** (propriétaire
/// UNIQUE AD-44) via `ValueListenableBuilder` (rebuild ciblé) — elle ne détient
/// AUCUN état de sélection.
library;

import 'package:flutter/material.dart';

import '../theme/z_theme.dart';
import 'z_list_selection.dart';

/// Cible de taille interactive minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Nature d'une action de **lot** — enum EXTENSIBLE additif (AD-4).
///
/// [delete]/[move] sont les natures intégrées ; [custom] couvre toute action
/// applicative hors nomenclature (l'appelant porte le [ZBatchAction.label]/[icon]
/// et le callback). Un membre neuf est **non-breaking** : aucun `switch`
/// exhaustif sur ce type n'existe dans le cœur (grep négatif — la barre filtre
/// sur `onSelected`, elle ne branche pas par nature).
enum ZBatchActionKind {
  /// Supprimer les éléments sélectionnés (voie `batchDelete` — cascade injectée).
  delete,

  /// Déplacer les éléments sélectionnés (voie `batchMove` — destination injectée).
  move,

  /// Action de lot applicative hors nomenclature.
  custom,
}

/// Une action de lot — data-class de présentation immuable (`const`).
///
/// [label]/[icon] sont INJECTÉS (i18n, jamais codés en dur). [onSelected] `null`
/// ⇒ action ABSENTE de la barre (AD-4/AD-44). L'action s'exécute sur la sélection
/// COURANTE : l'appelant (qui détient le contrôleur, AD-44) lit la sélection dans
/// son callback (ex. via `batchDelete`/`batchMove`/`applyCommonField`).
@immutable
class ZBatchAction {
  /// Construit une action de lot.
  const ZBatchAction({
    required this.kind,
    required this.label,
    required this.icon,
    this.onSelected,
  });

  /// Nature de l'action ([ZBatchActionKind]).
  final ZBatchActionKind kind;

  /// Libellé LOCALISÉ INJECTÉ (i18n, AD-13/FR-23).
  final String label;

  /// Glyphe INJECTÉ de l'action (jamais codé en dur).
  final IconData icon;

  /// Callback d'exécution. `null` ⇒ action ABSENTE de la barre (AD-4/AD-44).
  final VoidCallback? onSelected;
}

/// Barre d'actions de **lot** neutre (me-1, AD-44).
///
/// **Propriétaire UNIQUE** : reçoit le [controller] détenu par la surface de
/// liste — elle ne le crée jamais, ne le `dispose` jamais. Lit la SEULE tranche
/// `selectedIds` via `ValueListenableBuilder` (rebuild ciblé) et rend : un
/// **badge compteur** ([selectedCount]), un bouton « tout sélectionner »
/// (présent SEULEMENT si [onSelectAll] non `null`), puis les [actions] déclarées
/// dont `onSelected != null`.
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
  /// un bouton « tout sélectionner » actionnable SANS nom accessible est proscrit
  /// (récidive su-9). Ignoré si [onSelectAll] est `null` (bouton absent).
  final String? selectAllLabel;

  /// Callback « tout sélectionner ». `null` ⇒ bouton ABSENT (AD-4). Non-`null`
  /// ⇒ [selectAllLabel] DOIT l'être aussi (nom accessible a11y, AD-13).
  final VoidCallback? onSelectAll;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // AD-4/AD-44 — action sans callback ⇒ ABSENTE (jamais rendue grisée/no-op).
    final visible =
        actions.where((a) => a.onSelected != null).toList(growable: false);
    return ValueListenableBuilder<Set<String>>(
      valueListenable: controller.selectedIds,
      builder: (context, selected, _) {
        final count = selected.length;
        final countLabel = countLabelBuilder?.call(count) ?? '$count';
        // a11y (AD-13, leçon su-8/AC20) : le badge compteur est annoncé UNE
        // seule fois — par le `Text(countLabel)` visible ci-dessous. On ne
        // porte PAS `label: countLabel` sur ce `Semantics` conteneur : il
        // FUSIONNERAIT avec le libellé du `Text` enfant et le compteur serait
        // annoncé DEUX FOIS (« 3 sélectionné(s) 3 sélectionné(s) »). Le
        // conteneur ne fait que grouper la barre (frontière sémantique), sans
        // libellé propre.
        return Semantics(
          container: true,
          child: Row(
            children: [
              // Badge compteur (tranche réactive `selectedCount`).
              Padding(
                padding: EdgeInsetsDirectional.only(end: theme.gapM),
                child: Text(countLabel, textAlign: TextAlign.start),
              ),
              if (onSelectAll != null)
                _BarButton(
                  icon: Icons.select_all,
                  label: selectAllLabel,
                  onPressed: onSelectAll,
                ),
              for (final action in visible)
                _BarButton(
                  icon: action.icon,
                  label: action.label,
                  onPressed: action.onSelected,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Bouton d'action de barre — cible ≥ 48 dp, label a11y via le `tooltip` de
/// `IconButton` (qui porte DÉJÀ `button: true` + le label sémantique). On
/// n'ajoute PAS un `Semantics(label:)` supplémentaire : il FUSIONNERAIT avec
/// celui du tooltip et l'action serait annoncée DEUX FOIS (même défaut que
/// `ZItemActionsMenu`, SU-8/AC20). Directionnel (IconButton neutre).
class _BarButton extends StatelessWidget {
  const _BarButton({required this.icon, this.label, this.onPressed});

  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
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
  }
}
