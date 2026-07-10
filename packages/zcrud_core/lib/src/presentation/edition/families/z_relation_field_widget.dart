/// Widget de la **famille relation** (E3-3a) : `relation`.
///
/// **Abstraction** du sélecteur d'entité liée (DODLP `crudDataSelect`) : un
/// contrôle de sélection lisant/écrivant la tranche, avec une **source
/// injectable** ([options], défaut vide). E3-3a ne câble PAS la source
/// dynamique (repository/stream) : ce port est résolu au runtime en **E4** (ports
/// E2-2), jamais dans l'annotation `const` (cf. doc de `EditionFieldType.
/// relation`). Sans options, le contrôle reste **désactivé mais accessible**
/// (libellé + indice l10n), jamais un crash.
///
/// POINT DE CÂBLAGE E4 : remplacer [options] par une résolution de source (via
/// un port injecté au scope) fournissant `List<ZFieldChoice>` (ou un flux) — la
/// signature `value`/`onChanged` du widget reste inchangée.
///
/// a11y/RTL (AD-13) : rendu via `DropdownButtonFormField` (libellé sémantique +
/// cible ≥ 48 dp). Aucune couleur/inset non directionnel en dur (FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_choice.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';

/// Champ d'édition **relation** (sélecteur d'entité liée, source injectable).
class ZRelationFieldWidget extends StatelessWidget {
  /// Construit le sélecteur lié à [field] ; [value] est la valeur courante,
  /// [onChanged] écrit la sélection, [options] est la source **injectable**
  /// (défaut vide — la vraie source est câblée en E4).
  const ZRelationFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    this.options = const <ZFieldChoice>[],
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (id d'entité liée, opaque).
  final Object? value;

  /// Notifié avec la valeur sélectionnée.
  final ValueChanged<Object?> onChanged;

  /// Source **injectable** des options (défaut vide ; câblage runtime E4).
  final List<ZFieldChoice> options;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);
    final values = options.map((c) => c.value).toList(growable: false);
    final current = values.contains(value) ? value : null;
    final enabled = options.isNotEmpty && !field.readOnly;

    return DropdownButtonFormField<Object?>(
      // L-3 : clé sur la valeur COURANTE de la tranche → le `FormField` recrée
      // son état et reflète un changement EXTERNE/programmatique (un `FormField`
      // ne relit `initialValue` qu'à l'`initState`). Sélection atomique, aucune
      // saisie en cours à écraser. Reste borné par `ZFieldListenableBuilder`
      // (AD-2, aucun rebuild global).
      key: ValueKey<Object?>(current),
      initialValue: current,
      decoration: InputDecoration(
        labelText: resolvedLabel,
        hintText: label(context, 'select'),
      ),
      items: <DropdownMenuItem<Object?>>[
        for (final option in options)
          DropdownMenuItem<Object?>(
            value: option.value,
            child: Text(label(context, option.label, fallback: option.label)),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
