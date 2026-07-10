/// `ZFlashcardOptionTile` — tuile d'option **mono-choix** accessible, partagée
/// par le sélecteur de type et le sélecteur vrai/faux (Story E9-5, AD-13/FR-26).
///
/// **a11y opérable (AD-13)** : expose une **action sémantique `tap`
/// déclenchable** (via `Semantics(onTap:)`, opérable par un lecteur d'écran) ET
/// mesure **≥ 48 dp** de haut (`BoxConstraints(minHeight: 48)`). Le
/// `GestureDetector` est `excludeFromSemantics` pour ne pas dupliquer le nœud
/// d'action. **Directionnel** (`EdgeInsetsDirectional`/`TextAlign.start`) ;
/// **thème injecté** (aucune couleur en dur — FR-26).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Tuile d'option sélectionnable (radio-like) accessible et thémée.
class ZFlashcardOptionTile extends StatelessWidget {
  /// Construit une tuile pour [label], marquée [selected], déclenchant [onTap].
  const ZFlashcardOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
    this.enabled = true,
    super.key,
  });

  /// Libellé visible de l'option.
  final String label;

  /// `true` si l'option est la sélection courante.
  final bool selected;

  /// Callback de sélection (déclenché au tap pointeur **et** à l'action
  /// sémantique `tap`). Ignoré si [enabled] est `false`.
  final VoidCallback onTap;

  /// Libellé sémantique (défaut : [label]).
  final String? semanticLabel;

  /// Option interactive (défaut `true`). `false` → grisée, non opérable.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final handler = enabled ? onTap : null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: semanticLabel ?? label,
      onTap: handler,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: handler,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: theme.gapM,
              vertical: theme.gapS,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: theme.labelColor,
                ),
                SizedBox(width: theme.gapM),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.start,
                    style: TextStyle(color: theme.labelColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
