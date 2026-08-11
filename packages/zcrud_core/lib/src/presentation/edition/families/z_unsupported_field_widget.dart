/// **Repli contrôlé** : rendu accessible pour tout `EditionFieldType`
/// servi **ailleurs** (registre de widgets, ou type hors-parité).
///
/// Tout type non-base doit **dégrader proprement**, JAMAIS lever
/// d'exception ni casser le formulaire. Ce widget rend un placeholder
/// **accessible** (libellé du champ + indication l10n « type non pris en charge
/// ici ») ; ce n'est PAS un `ErrorWidget` et il ne `throw` jamais.
///
/// POINT D'EXTENSION : un **registre de widgets** (aligné sur
/// `ZTypeRegistry`, invariant AD-4) remplace ce repli par le vrai widget hôte
/// quand le type est enregistré. Ce widget ne fait que **nommer** ce point
/// d'extension et fournir le repli par défaut.
///
/// a11y/RTL (invariant AD-13) : `Semantics` explicite (libellé + indication),
/// insets **directionnels**, aucune couleur codée en dur (thème hérité —
/// invariant FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';

/// Placeholder **accessible** pour un type de champ non pris en charge ici.
class ZUnsupportedFieldWidget extends StatelessWidget {
  /// Construit le repli pour [field] (type hors familles de base).
  const ZUnsupportedFieldWidget({required this.field, super.key});

  /// Spécification `const` du champ non rendu par une famille de base.
  final ZFieldSpec field;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);
    final hint = label(context, 'unsupportedField');
    final theme = ZcrudTheme.of(context);

    return Semantics(
      label: '$resolvedLabel: $hint',
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: theme.gapL,
          vertical: theme.gapM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(resolvedLabel, style: Theme.of(context).textTheme.bodyMedium),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
