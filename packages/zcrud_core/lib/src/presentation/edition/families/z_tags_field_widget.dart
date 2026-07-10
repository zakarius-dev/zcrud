/// Widget de la **famille tags** (E3-3b-1) : `tags`.
///
/// Saisie multi-valeur à puces : la valeur est une `List<String>` **en tranche**
/// (lecture `value`, écriture via `onChanged`). L'ajout se fait par un champ de
/// saisie interne **éphémère** ; le retrait par une action par puce.
///
/// **Stabilité (contrat E3-2, AD-2)** : le `TextEditingController` de la saisie
/// d'ajout est un état **local éphémère** (ce n'est PAS la valeur du champ, qui
/// vit en tranche) — créé 1× en [State.initState], `dispose`, **jamais recréé**
/// pendant la frappe. Taper dans la saisie d'ajout n'écrit PAS la tranche (aucun
/// rebuild de tranche tant qu'aucune étiquette n'est validée) ; valider une
/// étiquette écrit la `List` via `onChanged` (rebuild de la seule tranche).
///
/// a11y/RTL (AD-13) : chaque puce supprimable expose une action sémantique via
/// un `IconButton` (cible ≥ 48 dp garantie) ; la saisie et le bouton d'ajout
/// sont ≥ 48 dp ; `Wrap` respecte la `Directionality`. Aucune couleur/inset non
/// directionnel en dur (FR-26 : bordure dérivée du `ZcrudTheme`).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';

/// Champ d'édition à **étiquettes** (`List<String>` en tranche, add/remove).
class ZTagsFieldWidget extends StatefulWidget {
  /// Construit le champ d'étiquettes lié à [field], valeur courante [value]
  /// (`List<String>` ou `null`), notifiant [onChanged] avec la nouvelle liste.
  const ZTagsFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (`List<String>` ou `null`).
  final Object? value;

  /// Notifié avec la nouvelle `List<String>` d'étiquettes.
  final ValueChanged<List<String>> onChanged;

  @override
  State<ZTagsFieldWidget> createState() => _ZTagsFieldWidgetState();
}

class _ZTagsFieldWidgetState extends State<ZTagsFieldWidget> {
  /// Saisie d'ajout **éphémère** (état local, PAS la valeur du champ) — stable.
  late final TextEditingController _add;
  late final FocusNode _addFocus;

  @override
  void initState() {
    super.initState();
    _add = TextEditingController();
    _addFocus = FocusNode();
  }

  @override
  void dispose() {
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  /// Lecture **défensive** de la liste courante (`null`/type inattendu → `[]`).
  List<String> get _tags {
    final v = widget.value;
    if (v is List) {
      return <String>[for (final e in v) if (e != null) '$e'];
    }
    return const <String>[];
  }

  void _addTag() {
    final raw = _add.text.trim();
    if (raw.isEmpty) return;
    final next = List<String>.of(_tags);
    if (!next.contains(raw)) {
      next.add(raw);
      widget.onChanged(next);
    }
    _add.clear();
    _addFocus.requestFocus();
  }

  void _removeAt(int index) {
    final next = List<String>.of(_tags)..removeAt(index);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, widget.field.label ?? widget.field.name,
        fallback: widget.field.label ?? widget.field.name);
    final theme = ZcrudTheme.of(context);
    final removeLabel = label(context, 'removeTag');
    final tags = _tags;

    return Semantics(
      container: true,
      label: resolvedLabel,
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
                for (var i = 0; i < tags.length; i++)
                  _TagChip(
                    text: tags[i],
                    borderColor: theme.fieldBorderColor,
                    radius: theme.radiusM,
                    removeLabel: '$removeLabel: ${tags[i]}',
                    onRemove: widget.field.readOnly ? null : () => _removeAt(i),
                  ),
              ],
            ),
          ),
          if (!widget.field.readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _add,
                      focusNode: _addFocus,
                      decoration:
                          InputDecoration(labelText: label(context, 'addTag')),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: label(context, 'addTag'),
                    onPressed: _addTag,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Puce d'étiquette avec action de retrait accessible (`IconButton` ≥ 48 dp).
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.text,
    required this.borderColor,
    required this.radius,
    required this.removeLabel,
    required this.onRemove,
  });

  final String text;
  final Color? borderColor;
  final Radius radius;
  final String removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: borderColor == null ? null : Border.all(color: borderColor!),
        borderRadius: BorderRadius.all(radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 0),
            child: Text(text),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: removeLabel,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
