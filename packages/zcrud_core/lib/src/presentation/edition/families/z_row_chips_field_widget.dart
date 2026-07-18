/// Widget de la **famille rowChips** (E3-3b-1) : `rowChips`.
///
/// Rangée de puces **mono-choix** alimentée par `ZFieldSpec.choices`
/// (`ZFieldChoice{value,label}`) : la valeur sélectionnée (unique) vit **dans la
/// tranche** (lecture `value`, écriture via `onChanged` — aucun
/// `TextEditingController`, AD-2). Toucher une puce déjà sélectionnée la
/// désélectionne (`null`).
///
/// a11y/RTL (AD-13) : `ChoiceChip` porte l'état sélectionné sémantique et une
/// cible ≥ 48 dp (`materialTapTargetSize: padded` par défaut) ; `Wrap` respecte
/// la `Directionality` ambiante. Aucune couleur/inset non directionnel en dur
/// (FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_choice.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';

/// Champ d'édition à **puces mono-choix** (rangée depuis `field.choices`).
class ZRowChipsFieldWidget extends StatelessWidget {
  /// Construit la rangée de puces liée à [field] (options = `field.choices`),
  /// valeur courante [value], notifiant [onChanged] avec la valeur choisie
  /// (ou `null` si désélection).
  const ZRowChipsFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Spécification `const` du champ rendu (source des `choices`).
  final ZFieldSpec field;

  /// Valeur courante sélectionnée (unique) ou `null`.
  final Object? value;

  /// Notifié avec la valeur choisie (ou `null` si désélection).
  final ValueChanged<Object?> onChanged;

  /// MIN-2 (parité DODLP « sous-titre rowChips ») — puce avec **sous-titre**
  /// optionnel (`ZFieldChoice.subtitle`). Sans sous-titre ⇒ `ChoiceChip` simple
  /// (rendu E3-3b inchangé) ; avec sous-titre ⇒ label sur deux lignes (titre +
  /// ligne secondaire `bodySmall`) et `Tooltip` a11y portant le sous-titre.
  Widget _chip(BuildContext context, ZFieldChoice choice) {
    final title = label(context, choice.label, fallback: choice.label);
    final sub = choice.subtitle == null
        ? null
        : label(context, choice.subtitle!, fallback: choice.subtitle!);
    final selected = value == choice.value;
    final onSelected = field.readOnly
        ? null
        : (bool s) => onChanged(s ? choice.value : null);

    if (sub == null) {
      return ChoiceChip(
        label: Text(title),
        selected: selected,
        onSelected: onSelected,
      );
    }
    return Tooltip(
      message: sub,
      child: ChoiceChip(
        label: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, textAlign: TextAlign.start),
            Text(sub,
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        selected: selected,
        onSelected: onSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);

    return Semantics(
      container: true,
      // Pas de `label:` ici : le `Text(resolvedLabel)` visible ci-dessous fournit
      // déjà le nom accessible du conteneur — le dupliquer sur le Semantics
      // provoquerait une DOUBLE annonce (cf. correctif fp-4-4/fp-5-1).
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
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final choice in field.choices)
                  _chip(context, choice),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
