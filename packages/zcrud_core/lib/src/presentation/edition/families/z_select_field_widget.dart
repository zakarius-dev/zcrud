/// Widget de la **famille select** (E3-3a) : `select` / `radio` / `checkbox`.
///
/// Alimenté par `ZFieldSpec.choices` (`ZFieldChoice{value,label}`) :
/// - `select` → `DropdownButtonFormField` (choix unique) ;
/// - `radio` → `RadioGroup` + `RadioListTile` (choix unique, cibles ≥ 48 dp) ;
/// - `checkbox` → `CheckboxListTile` **multi-sélection** (valeur = `List`),
///   convention story #3 (`checkbox`+`choices` ⇒ multi ; le booléen unique est
///   la famille `boolean`).
///
/// Aucun `TextEditingController` (AD-2) : lecture de `value`, écriture via
/// `onChanged`. a11y/RTL (AD-13) : `RadioListTile`/`CheckboxListTile` portent
/// rôle + état + cible ≥ 48 dp ; le dropdown porte son libellé via `labelText`.
/// Aucune couleur/inset non directionnel en dur (FR-26). `Column` (jamais
/// `ListView(children:)`) pour les listes bornées de cases/radios.
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/edition_field_type.dart';
import '../../../domain/edition/z_field_choice.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';

/// Champ d'édition à **choix** (liste déroulante / radios / cases).
class ZSelectFieldWidget extends StatelessWidget {
  /// Construit le contrôle de choix lié à [field] (options = `field.choices`),
  /// valeur courante [value], notifiant [onChanged] avec la (les) valeur(s).
  const ZSelectFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    this.bare = false,
    super.key,
  });

  /// Spécification `const` du champ rendu (source des `choices`).
  final ZFieldSpec field;

  /// Valeur courante (valeur unique, ou `List` pour `checkbox` multi).
  final Object? value;

  /// Notifié avec la valeur sélectionnée (unique) ou la `List` (multi).
  final ValueChanged<Object?> onChanged;

  /// Rendu **bare** (borderless, sans label) du dropdown pour le mode `large`
  /// (AC4) : le décor est porté par la Card. Défaut `false`.
  final bool bare;

  String _label(BuildContext context, String key) =>
      label(context, key, fallback: key);

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);

    if (field.type == EditionFieldType.checkbox) {
      return _buildCheckboxes(context, resolvedLabel);
    }
    if (field.type == EditionFieldType.radio) {
      return _buildRadios(context, resolvedLabel);
    }
    return _buildDropdown(context, resolvedLabel);
  }

  Widget _buildDropdown(BuildContext context, String resolvedLabel) {
    final values = field.choices.map((c) => c.value).toList(growable: false);
    final current = values.contains(value) ? value : null;
    return DropdownButtonFormField<Object?>(
      // L-3 : un `FormField` ne relit `initialValue` qu'à l'`initState`. Clé sur
      // la valeur COURANTE de la tranche pour que le contrôle recrée son état et
      // reflète un changement EXTERNE/programmatique (analogue à la sync guardée
      // du texte). La sélection d'un dropdown est atomique (aucune saisie en
      // cours à écraser). Reste DANS la tranche du champ (AD-2 : le rebuild est
      // borné par `ZFieldListenableBuilder`).
      key: ValueKey<Object?>(current),
      initialValue: current,
      decoration: ZcrudTheme.of(context).inputDecoration(
        context,
        label: bare ? null : resolvedLabel,
        bare: bare,
      ),
      items: <DropdownMenuItem<Object?>>[
        for (final choice in field.choices)
          DropdownMenuItem<Object?>(
            value: choice.value,
            child: Text(_label(context, choice.label)),
          ),
      ],
      onChanged: field.readOnly ? null : onChanged,
    );
  }

  Widget _buildRadios(BuildContext context, String resolvedLabel) {
    return Semantics(
      container: true,
      label: resolvedLabel,
      child: RadioGroup<Object?>(
        groupValue: value,
        onChanged: onChanged,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(resolvedLabel,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            for (final choice in field.choices)
              RadioListTile<Object?>(
                value: choice.value,
                // L-4 : en `readOnly`, `enabled: false` DÉSACTIVE réellement
                // chaque radio (état `disabled` correct pour l'a11y et l'UX),
                // au lieu de l'ancien `onChanged: (_) {}` no-op qui laissait le
                // groupe visuellement/sémantiquement ACTIF mais inerte.
                enabled: !field.readOnly,
                title: Text(_label(context, choice.label)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxes(BuildContext context, String resolvedLabel) {
    final selected = value is Iterable
        ? List<Object?>.from(value! as Iterable)
        : <Object?>[];
    return Semantics(
      container: true,
      label: resolvedLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Text(resolvedLabel,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          for (final choice in field.choices)
            CheckboxListTile(
              value: selected.contains(choice.value),
              onChanged: field.readOnly
                  ? null
                  : (checked) => _toggle(selected, choice, checked),
              title: Text(_label(context, choice.label)),
            ),
        ],
      ),
    );
  }

  void _toggle(List<Object?> selected, ZFieldChoice choice, bool? checked) {
    final next = List<Object?>.from(selected);
    if (checked == true) {
      if (!next.contains(choice.value)) next.add(choice.value);
    } else {
      next.remove(choice.value);
    }
    onChanged(next);
  }
}
