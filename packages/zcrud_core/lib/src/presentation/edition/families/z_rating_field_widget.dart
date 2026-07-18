/// Widget de la **famille rating** (E3-3b-1) : `rating`.
///
/// Contrôle de notation (étoiles) : la note (`num`) vit **en tranche** (lecture
/// `value`, écriture via `onChanged` — aucun `TextEditingController`, AD-2). La
/// borne max vient de `ZRatingConfig.max` (défaut 5). Toucher l'étoile déjà
/// active la désactive (retour à 0).
///
/// a11y/RTL (AD-13) : chaque étoile est un `IconButton` (cible ≥ 48 dp garantie)
/// avec libellé ; un nœud `Semantics` conteneur annonce la note courante
/// (`value`). Le `Row` suit la `Directionality` (progression début→fin). Aucune
/// couleur en dur (icône teintée par le thème — FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';

/// Champ d'édition **note** (`num` en tranche, étoiles ≥ 48 dp).
class ZRatingFieldWidget extends StatelessWidget {
  /// Construit le contrôle de note lié à [field], valeur courante [value]
  /// (`num` ou `null`), notifiant [onChanged] avec la nouvelle note (`int`).
  const ZRatingFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (`num` ou `null`).
  final Object? value;

  /// Notifié avec la nouvelle note (`int`, `0` = aucune).
  final ValueChanged<num> onChanged;

  /// Borne max depuis `ZRatingConfig` (défaut sûr 5).
  int get _max {
    final config = field.config;
    return config is ZRatingConfig ? config.max : 5;
  }

  /// Note courante bornée (`0..max`), défensive sur type inattendu.
  int get _current {
    final v = value;
    final n = v is num ? v.round() : 0;
    if (n < 0) return 0;
    if (n > _max) return _max;
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);
    final current = _current;
    final max = _max;

    return Semantics(
      container: true,
      // Pas de `label:` ici : le `Text(resolvedLabel)` visible ci-dessous fournit
      // déjà le nom accessible du conteneur — le dupliquer sur le Semantics
      // provoquerait une DOUBLE annonce (cf. correctif fp-4-4/fp-5-1). Le
      // `value:` (note courante) n'est PAS dupliqué par le Text → conservé.
      value: '$current / $max',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child:
                Text(resolvedLabel, style: Theme.of(context).textTheme.bodySmall),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 1; i <= max; i++)
                  IconButton(
                    icon: Icon(i <= current ? Icons.star : Icons.star_border),
                    tooltip: '${label(context, 'rate')} $i',
                    onPressed: field.readOnly
                        ? null
                        // Re-toucher l'étoile active → 0 (efface la note).
                        : () => onChanged(i == current ? 0 : i),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
