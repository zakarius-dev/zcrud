/// `ZSubfolderCompactSelector` — sélecteur de sous-dossiers pour PETIT écran
/// (SUF-3, T3).
///
/// Rangée de puces (chips) défilant horizontalement : item racine « Tous les
/// sous-dossiers » en tête, puis les [ZSubfolderRef], puis un bouton « Ajouter »
/// optionnel. **Aucune sidebar** — la bascule sidebar ↔ sélecteur compact est
/// arbitrée par `ZResponsiveLayout` au seuil `ZWindowSizeThresholds.mediumMinWidth`
/// (600 dp) côté `ZStudyFolderDetail` (AC7).
///
/// **PARITÉ avec la sidebar (R-SUF2)** : le contenu d'une puce vient du MÊME
/// [ZSubfolderNavSpec.itemBuilder] injecté que celui de la sidebar (à défaut :
/// pastille d'accent + libellé + compteur, MÊMES informations). Une même
/// `ZSubfolderNavSpec` a donc les mêmes capacités des deux côtés du seuil — le
/// seam d'extension n'est jamais « sidebar-only ».
///
/// **AD-2/AD-15** : ne détient aucun état — la sélection est une tranche
/// réactive injectée (`ValueListenable<String?>`), scopée **par puce**
/// (surbrillance ciblée). **AD-13** : `Semantics(selected:)`, cibles ≥ 48 dp,
/// libellés INJECTÉS, directionnel (`ListView` horizontal, insets `Directional`).
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

import 'z_subfolder_item_chrome.dart';
import 'z_subfolder_nav_spec.dart';
import 'z_subfolder_ref.dart';

/// Cible interactive minimale (AD-13).
const double _kMinTapTarget = 48.0;

/// Glyphe conventionnel « ajouter » de REPLI (jamais un libellé).
const IconData _kAddFallbackIcon = Icons.add;

/// Sélecteur compact de sous-dossiers (petit écran).
class ZSubfolderCompactSelector extends StatelessWidget {
  /// Construit le sélecteur compact.
  const ZSubfolderCompactSelector({
    required this.spec,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  /// Clé stable du sélecteur compact (exposée pour les tests).
  static const Key compactKey = ValueKey<String>('suf3:compact');

  /// Descripteur de navigation (données + labels, tout injecté).
  final ZSubfolderNavSpec spec;

  /// Tranche réactive de sélection (`null` = item racine).
  final ValueListenable<String?> selected;

  /// Émis quand une puce est choisie (`null` pour la racine).
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // Racine (id `null`) + sous-dossiers + (optionnel) bouton « Ajouter ».
    // Rangée EAGER défilant horizontalement (peu d'items) : hauteur bornée par le
    // contenu (jamais un `ListView` horizontal à hauteur non bornée dans une
    // `Column`). `ListView(children:)` interdit (AD-13) — d'où `Row`.
    // Scope de mode posé AU-DESSUS du `ChoiceChip` (donc au-dessus du dry layout
    // qu'il calcule) : l'`itemBuilder` injecté lit
    // `ZSubfolderLayoutMode.of(context) == compact` et sait que sa largeur n'est
    // PAS bornée (CR-IFFD-31) — sans 4ᵉ paramètre, sans `LayoutBuilder`.
    return ZSubfolderLayoutScope(
      mode: ZSubfolderLayoutMode.compact,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinTapTarget),
        child: SingleChildScrollView(
          key: compactKey,
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _chip(
                context,
                theme,
                refOrNull: null,
                label: spec.allSubfoldersLabel,
              ),
              for (final ref in spec.subfolders)
                _chip(context, theme, refOrNull: ref, label: ref.label),
              if (spec.addAction != null) _addButton(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  /// Une puce sélectionnable. [refOrNull] `null` ⇒ item racine.
  ///
  /// **PARITÉ avec la sidebar (R-SUF2)** : le contenu vient du MÊME
  /// [ZSubfolderNavSpec.itemBuilder] injecté — et, à défaut, du même chrome
  /// neutre (pastille d'accent + compteur). Une `ZSubfolderNavSpec` a donc les
  /// MÊMES capacités des deux côtés du seuil de bascule (600 dp) : le seam
  /// d'extension n'est pas « sidebar-only ». La mise en évidence de la sélection
  /// reste posée par SUF-3 (`ChoiceChip.selected`), jamais déléguée à l'hôte.
  Widget _chip(
    BuildContext context,
    ZcrudTheme theme, {
    required ZSubfolderRef? refOrNull,
    required String label,
  }) {
    final id = refOrNull?.id;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: theme.gapS),
      child: ValueListenableBuilder<String?>(
        valueListenable: selected,
        builder: (context, current, _) {
          final isSelected = current == id;
          final content = spec.itemBuilder?.call(
                context,
                // MÊME convention que la sidebar pour l'item racine : aucune
                // divergence de contrat entre les deux chemins.
                refOrNull ?? ZSubfolderRef(id: '', label: label),
                isSelected,
              ) ??
              _defaultContent(theme, refOrNull, label);
          return ChoiceChip(
            label: content,
            selected: isSelected,
            onSelected: (_) => onSelect(id),
          );
        },
      ),
    );
  }

  /// Contenu neutre par défaut d'une puce : pastille d'accent (si `colorKey`) +
  /// libellé + badge de compteur (si `count`) — MÊMES informations que la rangée
  /// par défaut de la sidebar.
  Widget _defaultContent(ZcrudTheme theme, ZSubfolderRef? ref, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (ref?.colorKey != null) ...<Widget>[
          ZSubfolderAccentPastille(colorKey: ref!.colorKey!),
          SizedBox(width: theme.gapS),
        ],
        Text(label, textAlign: TextAlign.start),
        if (ref?.count != null) ...<Widget>[
          SizedBox(width: theme.gapS),
          ZSubfolderCountPill(count: ref!.count!),
        ],
      ],
    );
  }

  Widget _addButton(BuildContext context, ZcrudTheme theme) {
    final label = spec.addLabel ?? spec.allSubfoldersLabel;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: theme.gapS),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _kMinTapTarget,
          minHeight: _kMinTapTarget,
        ),
        child: IconButton(
          key: const ValueKey<String>('suf3:compact:add'),
          onPressed: spec.addAction,
          tooltip: label,
          icon: Icon(spec.addIcon ?? _kAddFallbackIcon, semanticLabel: label),
        ),
      ),
    );
  }
}
