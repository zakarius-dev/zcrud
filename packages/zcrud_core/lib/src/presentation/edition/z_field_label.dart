/// `ZFieldLabel` — libellé de champ **enrichi partagé** : `Text.rich` du
/// libellé thémé + un astérisque « requis » coloré **erreur** rendu
/// uniquement si le champ est requis et éditable.
///
/// La couleur d'erreur est **thémée** (aucune couleur en dur — invariant
/// FR-26) et l'astérisque est **décoratif** (`ExcludeSemantics`) : le
/// rôle « requis » reste porté par le validateur natif (invariant AD-13),
/// l'astérisque n'introduit pas de faux label a11y.
///
/// Invariant AD-2 : widget **statique** (aucune tranche écoutée) — construit
/// dans la décoration statique, hors de la voie de frappe. Directionnel
/// (invariant AD-13).
library;

import 'package:flutter/material.dart';

import '../../domain/edition/z_field_spec.dart';
import '../l10n/z_localizations.dart';
import '../theme/z_theme.dart';

/// Libellé enrichi (style thémé + astérisque requis) partagé par les familles
/// décor-portantes en mode normal (`InputDecoration.label`) et par
/// `ZLargeFieldCard` en mode large.
class ZFieldLabel extends StatelessWidget {
  /// Construit le libellé enrichi de [field]. [large] sélectionne le style
  /// (`largeLabelTextStyle`/`bodyLarge` vs `labelTextStyle`/`bodyMedium`).
  const ZFieldLabel({
    required this.field,
    this.large = false,
    super.key,
  });

  /// Spécification `const` du champ (source du libellé + de `isRequired`).
  final ZFieldSpec field;

  /// Mode large (Card) : style `largeLabelTextStyle`/`bodyLarge` `w500`.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ZcrudTheme.of(context);
    final resolved = label(
      context,
      field.label ?? field.name,
      fallback: field.label ?? field.name,
    );
    final baseStyle = large
        ? (tokens.largeLabelTextStyle ?? theme.textTheme.bodyLarge)
        : (tokens.labelTextStyle ?? theme.textTheme.bodyMedium);
    // Couleur d'erreur thémée (invariant FR-26) — jamais un littéral. Repli
    // sur `ColorScheme.error`.
    final errorColor = tokens.errorColor ?? theme.colorScheme.error;
    // Astérisque uniquement si requis ET éditable (le `readOnly` global
    // force `field.readOnly`).
    final showStar = field.isRequired && !field.readOnly;

    return Text.rich(
      TextSpan(
        text: resolved,
        style: baseStyle,
        children: showStar
            ? <InlineSpan>[
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  // Décoratif (invariant AD-13) : le rôle « requis » est
                  // porté par le validateur natif — l'astérisque n'est pas
                  // un label a11y.
                  child: ExcludeSemantics(
                    child: Text(
                      ' *',
                      style: (baseStyle ?? const TextStyle())
                          .copyWith(color: errorColor),
                    ),
                  ),
                ),
              ]
            : const <InlineSpan>[],
      ),
      textAlign: TextAlign.start,
    );
  }
}
