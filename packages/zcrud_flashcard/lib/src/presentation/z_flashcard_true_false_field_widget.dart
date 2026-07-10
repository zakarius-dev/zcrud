/// `ZTrueFalseFieldWidget` — sélecteur **vrai/faux** (`isTrue`), servi via
/// `ZWidgetRegistry` (Story E9-5, AC1/AD-2/AD-4/AD-13/AD-10/FR-26).
///
/// Émet un `bool` via `ctx.onChanged` ; défensif (AD-10) : une valeur illisible
/// retombe sur « aucune sélection » (`null`). `StatefulWidget` sans contrôleur
/// de texte (AD-2) : lit `ctx.value`, écrit via `ctx.onChanged`.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_flashcard_editor_values.dart';
import 'z_flashcard_option_tile.dart';

/// Sélecteur vrai/faux (widget d'édition additif).
class ZTrueFalseFieldWidget extends StatefulWidget {
  /// Construit le sélecteur pour [ctx]. [trueLabel]/[falseLabel] surchargent les
  /// libellés (défaut FR).
  const ZTrueFalseFieldWidget({
    required this.ctx,
    this.trueLabel = 'Vrai',
    this.falseLabel = 'Faux',
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contexte du champ (`ctx.value` = `bool?` courant ; `ctx.onChanged`).
  final ZFieldWidgetContext ctx;

  /// Libellé de l'option « vrai » (paramétrable — AD-4).
  final String trueLabel;

  /// Libellé de l'option « faux » (paramétrable — AD-4).
  final String falseLabel;

  /// Hook de test : appelé UNE FOIS en `initState` (preuve SM-1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test : appelé à chaque (re)build (compteur ciblé SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  @override
  State<ZTrueFalseFieldWidget> createState() => _ZTrueFalseFieldWidgetState();
}

class _ZTrueFalseFieldWidgetState extends State<ZTrueFalseFieldWidget> {
  @override
  void initState() {
    super.initState();
    widget.onInit?.call();
  }

  bool? get _current => coerceTrueFalse(widget.ctx.value);

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final field = widget.ctx.field;
    final resolvedLabel = field.label ?? field.name;
    final current = _current;
    final readOnly = field.readOnly;
    return Semantics(
      container: true,
      label: resolvedLabel,
      child: Padding(
        padding: theme.fieldPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(resolvedLabel, style: TextStyle(color: theme.labelColor)),
            SizedBox(height: theme.gapS),
            ZFlashcardOptionTile(
              key: const Key('z-flashcard-true'),
              label: widget.trueLabel,
              selected: current == true,
              enabled: !readOnly,
              onTap: () => widget.ctx.onChanged(true),
            ),
            ZFlashcardOptionTile(
              key: const Key('z-flashcard-false'),
              label: widget.falseLabel,
              selected: current == false,
              enabled: !readOnly,
              onTap: () => widget.ctx.onChanged(false),
            ),
          ],
        ),
      ),
    );
  }
}
