/// `ZFlashcardTypeFieldWidget` — sélecteur du type de flashcard, servi via
/// `ZWidgetRegistry`.
///
/// Champ additif paramétré par l'entité de l'application : les six valeurs
/// de [ZFlashcardType] sont proposées en tuiles mono-choix accessibles ; la
/// sélection émet la valeur typée via `ctx.onChanged`. Défensif (invariant
/// AD-10) : une valeur de tranche illisible retombe sur `openQuestion`.
///
/// `StatefulWidget` sans contrôleur de texte (invariant AD-2, aucune
/// frappe) ; lit `ctx.value`, écrit via `ctx.onChanged` — aucune
/// souscription élargie, aucun rebuild global. Les libellés sont
/// paramétrables par closure (invariant AD-4).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_flashcard_type.dart';
import 'z_flashcard_editor_values.dart';
import 'z_flashcard_option_tile.dart';

/// Résout le libellé affiché d'un [ZFlashcardType] (paramétrable par
/// l'application).
typedef ZFlashcardTypeLabel = String Function(ZFlashcardType type);

/// Sélecteur de type de flashcard (widget d'édition additif).
class ZFlashcardTypeFieldWidget extends StatefulWidget {
  /// Construit le sélecteur pour [ctx]. [labelResolver] surcharge les
  /// libellés des six types (défaut : libellés FR intégrés).
  const ZFlashcardTypeFieldWidget({
    required this.ctx,
    this.labelResolver,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contexte du champ (`ctx.value` = type courant ; `ctx.onChanged` = écriture).
  final ZFieldWidgetContext ctx;

  /// Résolveur de libellé (capturé par closure, invariant AD-4 ; défaut FR).
  final ZFlashcardTypeLabel? labelResolver;

  /// Hook de test : appelé une fois en `initState`.
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test : appelé à chaque (re)build.
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Libellé FR par défaut d'un [type] (repli si aucun [labelResolver]).
  static String defaultLabel(ZFlashcardType type) {
    switch (type) {
      case ZFlashcardType.multipleChoice:
        return 'Choix multiples (QCM)';
      case ZFlashcardType.trueOrFalse:
        return 'Vrai / Faux';
      case ZFlashcardType.openQuestion:
        return 'Question ouverte';
      case ZFlashcardType.exercise:
        return 'Exercice';
      case ZFlashcardType.fillBlank:
        return 'Texte à trous';
      case ZFlashcardType.shortAnswer:
        return 'Réponse courte';
    }
  }

  @override
  State<ZFlashcardTypeFieldWidget> createState() =>
      _ZFlashcardTypeFieldWidgetState();
}

class _ZFlashcardTypeFieldWidgetState extends State<ZFlashcardTypeFieldWidget> {
  @override
  void initState() {
    super.initState();
    widget.onInit?.call();
  }

  ZFlashcardType get _current => coerceFlashcardType(widget.ctx.value);

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final field = widget.ctx.field;
    final resolvedLabel = field.label ?? field.name;
    final resolveLabel = widget.labelResolver ??
        ZFlashcardTypeFieldWidget.defaultLabel;
    final current = _current;
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
            // Liste construite paresseusement (invariant AD-13 :
            // `ListView.builder`), bornée (6 items) → `shrinkWrap` sans
            // scroll interne concurrent.
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ZFlashcardType.values.length,
              itemBuilder: (context, index) {
                final type = ZFlashcardType.values[index];
                return ZFlashcardOptionTile(
                  key: ValueKey<String>('z-flashcard-type-${type.name}'),
                  label: resolveLabel(type),
                  selected: type == current,
                  enabled: !field.readOnly,
                  onTap: () => widget.ctx.onChanged(type),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
