/// `ZLargeFieldCard` — décorateur **Card** de la variante `ZFieldSize.large`.
///
/// `Card` `elevation 0` + bordure arrondie (rayon = token),
/// `ConstrainedBox(minHeight)`, `Padding` directionnel, `Row` avec
/// slots **leading/suffix optionnels** et une `Column` portant le **label
/// AU-DESSUS** du champ. Toutes les mesures proviennent des tokens `ZcrudTheme`
/// (`large*`/`input*`) — AUCUNE valeur de layout ni couleur codée en dur
/// (invariant FR-26, invariant AD-13 : insets directionnels).
///
/// Invariant AD-2 : ce widget est **statique** (il ne s'abonne à aucune
/// tranche) — l'hôte l'enveloppe autour du sous-arbre réactif, sans élargir
/// la frontière de rebuild.
library;

import 'package:flutter/material.dart';

import '../theme/z_theme.dart';

/// Enveloppe Card de la variante `large` (label au-dessus, champ interne bare).
class ZLargeFieldCard extends StatelessWidget {
  /// Construit la Card `large` portant [label] au-dessus de [child], avec des
  /// slots [leading]/[suffix] optionnels (rendus seulement s'ils sont fournis).
  const ZLargeFieldCard({
    required this.label,
    required this.child,
    this.labelWidget,
    this.leading,
    this.suffix,
    super.key,
  });

  /// Libellé sémantique affiché AU-DESSUS du champ (déjà résolu l10n par l'hôte).
  /// Porte la sémantique conteneur (a11y) ET, à défaut de [labelWidget], le
  /// rendu visible.
  final String label;

  /// Libellé **enrichi** optionnel (`ZFieldLabel` : style thémé + astérisque
  /// requis). S'il est fourni, il **remplace** le `Text(label)`
  /// visible (l'a11y reste portée par [label] via le `Semantics` conteneur).
  final Widget? labelWidget;

  /// Champ interne (rendu « bare » : sans bordure ni label propre).
  final Widget child;

  /// Slot leading optionnel (icône/action de tête) — `null` par défaut.
  final Widget? leading;

  /// Slot suffix optionnel (icône/action de queue) — `null` par défaut.
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final tokens = ZcrudTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final labelStyle =
        tokens.largeLabelTextStyle ?? Theme.of(context).textTheme.bodyLarge;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Le label a11y est porté par le `Semantics` conteneur ci-dessous —
        // le Text/label visible est exclu de la sémantique pour éviter une
        // DOUBLE annonce au lecteur d'écran (invariant AD-13). Si un label
        // enrichi est fourni, il remplace le `Text(label)` simple.
        ExcludeSemantics(
          child: labelWidget ??
              Text(label, style: labelStyle, textAlign: TextAlign.start),
        ),
        SizedBox(height: tokens.largeLabelGap),
        child,
      ],
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (leading != null) ...<Widget>[
          IconTheme.merge(
            data: IconThemeData(size: tokens.largeLeadingIconSize),
            child: leading!,
          ),
          SizedBox(width: tokens.largeLeadingGap),
        ],
        Expanded(child: column),
        if (suffix != null) ...<Widget>[
          SizedBox(width: tokens.largeLeadingGap),
          suffix!,
        ],
      ],
    );

    return Semantics(
      container: true,
      label: label,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(tokens.inputRadius),
          side: BorderSide(
            color: scheme.outline,
            width: tokens.inputBorderWidth,
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.largeMinHeight),
          child: Padding(
            padding: tokens.largePadding,
            child: row,
          ),
        ),
      ),
    );
  }
}
