/// Widget de la **famille slider** (E3-3b-1) : `slider`.
///
/// `Slider` borné : la valeur (`num`) vit **en tranche** (lecture `value`,
/// écriture via `onChanged` — aucun `TextEditingController`, AD-2). Bornes/pas
/// depuis `ZSliderConfig` (`min`/`max`/`divisions` ; défauts sûrs `0..1`
/// continu).
///
/// a11y/RTL (AD-13) : le `Slider` porte nativement une sémantique de curseur
/// (valeur annoncée via `label`) et est directionnel par construction. Aucune
/// couleur en dur (thème injecté — FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';

/// Champ d'édition **curseur** (`num` borné en tranche).
class ZSliderFieldWidget extends StatelessWidget {
  /// Construit le curseur lié à [field], valeur courante [value] (`num` ou
  /// `null`), notifiant [onChanged] avec la nouvelle valeur (`double`).
  const ZSliderFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (`num` ou `null`).
  final Object? value;

  /// Notifié avec la nouvelle valeur du curseur (`double`).
  final ValueChanged<num> onChanged;

  ZSliderConfig get _config {
    final config = field.config;
    return config is ZSliderConfig ? config : const ZSliderConfig();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);
    final config = _config;
    // Bornes sûres : min < max garanti pour éviter une assertion Slider.
    final min = config.min;
    final max = config.max > config.min ? config.max : config.min + 1;
    final raw = value is num ? (value! as num).toDouble() : min;
    final current = raw.clamp(min, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
          child: Text(resolvedLabel, style: Theme.of(context).textTheme.bodySmall),
        ),
        Slider(
          value: current,
          min: min,
          max: max,
          divisions: config.divisions,
          label: current.toStringAsFixed(config.divisions == null ? 2 : 0),
          onChanged: field.readOnly ? null : onChanged,
        ),
      ],
    );
  }
}
