/// Le **motif** du curseur à repères textuels, partagé par tous les réglages
/// d'échelle de ce paquet.
///
/// Un curseur seul ne dit pas ce qu'il règle : les deux applications de
/// référence posent toutes deux des repères **textuels** sous le rail. Ce
/// widget porte ce motif une seule fois — le budget de calcul et les échelles
/// déclarées par un catalogue d'outils le partagent, au lieu d'en tenir deux
/// copies qui divergeraient.
///
/// La cible du pouce est tenue au plancher tactile (`kZChatMinTapTarget`,
/// invariant AD-13) et l'échelle sous le rail est **exclue de la sémantique** :
/// le `Slider` annonce déjà sa valeur par
/// `Slider.semanticFormatterCallback`, et la répéter la ferait lire deux fois.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

/// Curseur à repères textuels.
class ZChatMaterialLabelledSlider extends StatelessWidget {
  /// Construit le curseur.
  const ZChatMaterialLabelledSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.title,
    this.divisions,
    this.valueLabelOf,
    this.marks = const <String>[],
    this.enabled = true,
    super.key,
  });

  /// Valeur courante, déjà bornée par l'appelant.
  final double value;

  /// Borne basse.
  final double min;

  /// Borne haute.
  final double max;

  /// Nouvelle valeur. Ignoré quand [enabled] est `false`.
  final ValueChanged<double> onChanged;

  /// Titre au-dessus du rail. `null` ⇒ aucun titre.
  final String? title;

  /// Nombre de crans. `null` ⇒ rail continu.
  final int? divisions;

  /// Texte annoncé pour une valeur. `null` ⇒ aucune étiquette.
  final String Function(double value)? valueLabelOf;

  /// Repères textuels sous le rail, du début vers la fin. Vide ⇒ aucun.
  final List<String> marks;

  /// `false` rend le rail **présent mais non réglable** — un réglage refusé
  /// reste visible, avec son motif à côté.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final String Function(double)? labelOf = valueLabelOf;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (title != null)
          // Invariant AD-13 : jamais `TextAlign.left`.
          Text(title!, textAlign: TextAlign.start),
        // Invariant AD-13 : la cible du pouce est tenue ≥ 48 dp en géométrie
        // RENDUE par la contrainte plancher.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kZChatMinTapTarget),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: labelOf == null ? null : labelOf(value),
            semanticFormatterCallback: labelOf == null
                ? null
                : (double v) => labelOf(v),
            onChanged: enabled ? onChanged : null,
          ),
        ),
        if (marks.isNotEmpty)
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[for (final String m in marks) Text(m)],
            ),
          ),
      ],
    );
  }
}
