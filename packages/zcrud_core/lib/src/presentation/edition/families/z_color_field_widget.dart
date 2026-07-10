/// Widget de la **famille color** (E3-3b-1) : `color`.
///
/// Sélecteur de couleur par palette : la couleur vit **en tranche** encodée en
/// **`int` ARGB 32 bits** (canal alpha en poids fort — `0xAARRGGBB`) — format
/// **stable, sérialisable, additif** (décision story #7 / ambiguïté #5). Lecture
/// `value` (attendu `int` ; défensif sur tout autre type → aucune sélection),
/// écriture via `onChanged` (aucun `TextEditingController`, AD-2).
///
/// **FR-26 (aucun style codé en dur)** : les swatches de la palette sont des
/// **données** DÉRIVÉES (teintes `HSV` échelonnées, aucun littéral de couleur) —
/// ce ne sont pas des couleurs de la charte. La bordure de sélection provient du
/// `ZcrudTheme`. a11y/RTL (AD-13) : chaque swatch est une cible ≥ 48 dp avec
/// `Semantics(label + selected)` ; l'aperçu porte un `Semantics(value)` (code
/// ARGB) ; `Wrap` respecte la `Directionality`.
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';

/// Champ d'édition **couleur** (palette ; `int` ARGB en tranche).
class ZColorFieldWidget extends StatelessWidget {
  /// Construit le sélecteur lié à [field], valeur courante [value] (`int` ARGB
  /// ou `null`), notifiant [onChanged] avec l'ARGB choisi (`int`).
  const ZColorFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (`int` ARGB 32 bits ou `null`).
  final Object? value;

  /// Notifié avec l'ARGB (`int`) sélectionné.
  final ValueChanged<int> onChanged;

  /// Palette **dérivée** (12 teintes HSV échelonnées + neutres) — pur-données,
  /// aucun littéral de couleur (FR-26). Alpha plein.
  static List<int> _palette() {
    final argbs = <int>[];
    for (var i = 0; i < 12; i++) {
      final hue = (i * 30) % 360;
      argbs.add(HSVColor.fromAHSV(1, hue.toDouble(), 0.65, 0.9).toColor().toARGB32());
    }
    // Neutres dérivés (saturation nulle) : sombre / moyen / clair.
    for (final v in <double>[0.15, 0.5, 0.9]) {
      argbs.add(HSVColor.fromAHSV(1, 0, 0, v).toColor().toARGB32());
    }
    return argbs;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);
    final theme = ZcrudTheme.of(context);
    final selectLabel = label(context, 'selectColor');
    final current = value is int ? value! as int : null;
    final palette = _palette();

    return Semantics(
      container: true,
      label: resolvedLabel,
      value: current == null
          ? null
          : '#${current.toRadixString(16).padLeft(8, '0')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child:
                Text(resolvedLabel, style: Theme.of(context).textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: <Widget>[
                for (final argb in palette)
                  _Swatch(
                    argb: argb,
                    selected: argb == current,
                    borderColor: theme.fieldBorderColor,
                    label: '$selectLabel #${argb.toRadixString(16).padLeft(8, '0')}',
                    onTap: field.readOnly ? null : () => onChanged(argb),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Swatch de couleur ≥ 48 dp, accessible (label + état sélectionné).
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.argb,
    required this.selected,
    required this.borderColor,
    required this.label,
    required this.onTap,
  });

  final int argb;
  final bool selected;
  final Color? borderColor;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(argb),
                shape: BoxShape.circle,
                border: selected && borderColor != null
                    ? Border.all(color: borderColor!, width: 3)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
