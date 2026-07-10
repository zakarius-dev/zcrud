/// Widget de la **famille booléen** (E3-3a) : `boolean`.
///
/// `SwitchListTile` : lit `value` (coché si `== true`) et écrit via `onChanged`
/// (aucun `TextEditingController` — AD-2). Le `SwitchListTile` porte nativement
/// l'**état sémantique** (coché/décoché, rôle `switch`) et une cible ≥ 48 dp
/// (hauteur de `ListTile`), satisfaisant AC5/AC6 sans style codé en dur (FR-26).
///
/// Convention (story #3) : `boolean` = **toggle unique** ; la multi-sélection
/// par cases relève de `checkb` (famille select).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';

/// Champ d'édition **booléen** (interrupteur avec libellé et état sémantique).
class ZBooleanFieldWidget extends StatelessWidget {
  /// Construit l'interrupteur lié à [field] ; [value] est la valeur courante
  /// (coché si `== true`), [onChanged] écrit le nouvel état.
  const ZBooleanFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (coché si `== true`).
  final Object? value;

  /// Notifié avec le nouvel état booléen.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel =
        label(context, field.label ?? field.name, fallback: field.label ?? field.name);
    final checked = value == true;

    return SwitchListTile(
      value: checked,
      onChanged: field.readOnly ? null : onChanged,
      title: Text(resolvedLabel),
      // `ListTile` fournit une cible ≥ 48 dp et fusionne le libellé du titre
      // avec l'état `switch` du contrôle (Semantics natif).
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
    );
  }
}
