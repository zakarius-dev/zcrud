/// Widget de la **famille sous-liste** (`subItems`) — E3-3b-2 : **mini-CRUD
/// imbriqué** (POINT DE VIGILANCE AD-2 N°1).
///
/// Édite une `List<Map<String, dynamic>>` d'items : **ajouter**, **supprimer**,
/// **réordonner**. Chaque item est édité par un **sous-formulaire imbriqué** —
/// un `ZFormController` PROPRE à l'item (slice imbriqué) réutilisant le
/// dispatcher `ZFieldWidget`.
///
/// **SM-1 IMBRIQUÉ (AD-2, OBJECTIF PRODUIT N°1)** — invariants NON-NÉGOCIABLES :
/// - **Le conteneur écoute un canal STRUCTUREL** (add/remove/reorder — géré par
///   `setState` local), **jamais la valeur des sous-champs**. Taper dans un champ
///   d'un item ne reconstruit QUE ce champ (via le `ZFieldListenableBuilder` du
///   `ZFieldWidget` imbriqué) — **PAS** le conteneur, **PAS** les autres items,
///   **PAS** le formulaire racine.
/// - **La tranche parente est agrégée hors de la voie de rebuild** : ce widget
///   est monté par `ZFieldWidget` **AVANT** la souscription à la tranche parente
///   (comme `hidden`/`unsupported`) → écrire la `List` agrégée via `onChanged`
///   (→ `setValue` parent) **ne reconstruit pas** ce conteneur. L'agrégation est
///   déclenchée par un listener sur chaque slice imbriqué (canal de valeur), qui
///   écrit la `List` sans jamais reconstruire le conteneur.
/// - **Place stable par item** : chaque item est enveloppé dans
///   `KeyedSubtree(ValueKey(itemId))` (identité stable) → un réordonnancement ou
///   un retrait **ne vole/ne perd pas** l'état/focus des voisins. Le
///   `ZFormController` d'un item retiré est **`dispose`** (aucune fuite).
/// - **Aucun `setState` de niveau formulaire, aucun `Form`/`FormBuilder`
///   global** : la granularité imbriquée réutilise INTÉGRALEMENT la machinerie
///   E3 (dispatcher + tranches).
///
/// **Frontière E4-5** : ce widget est le **champ d'édition imbriqué** (dans un
/// formulaire) ; l'**écran de sous-liste autonome** (mini-CRUD plein écran,
/// `ZSubListScreen`) reste **E4-5** — non dupliqué ici. Le sous-schéma `const`
/// ([ZSubListConfig.itemFields]) est la brique commune réutilisable.
///
/// a11y/RTL (AD-13) : boutons add/remove/monter/descendre = `IconButton`
/// (cibles ≥ 48 dp) + `Semantics`/tooltips ; insets **directionnels** ; aucune
/// couleur codée en dur (bordure dérivée du `ZcrudTheme` — FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_spec.dart';
import '../../../domain/edition/z_sub_list_config.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';
import '../../z_form_controller.dart';
import '../z_field_widget.dart';

/// Seam (usage de test) : construit le widget d'édition d'un **sous-champ**
/// d'item, avec le contexte de l'item (`itemId`) pour instrumenter les compteurs
/// de rebuild imbriqués (preuve SM-1 imbriqué). À défaut : dispatcher
/// `ZFieldWidget`. Le type est public ; le **paramètre** qui le porte est
/// `@visibleForTesting` (production : toujours `null`).
typedef ZSubItemFieldBuilder = Widget Function(
  BuildContext context,
  ZFormController itemController,
  ZFieldSpec field,
  String itemId,
);

/// Champ d'édition d'une **sous-liste** d'items (`List<Map>` en tranche parente).
class ZSubListFieldWidget extends StatefulWidget {
  /// Construit le champ sous-liste pour [field], valeur initiale [initialValue]
  /// (`List<Map>` ou `null`), agrégeant vers la tranche parente via [onChanged].
  const ZSubListFieldWidget({
    required this.field,
    required this.initialValue,
    required this.onChanged,
    this.itemFieldBuilder,
    super.key,
  });

  /// Spécification `const` du champ rendu (`config` = [ZSubListConfig]).
  final ZFieldSpec field;

  /// Valeur INITIALE de la tranche parente (`List<Map>` ou `null`) — lue **une
  /// fois** pour amorcer les sous-contrôleurs. La suite est gouvernée par l'état
  /// imbriqué (le conteneur ne re-souscrit PAS à la tranche parente).
  final Object? initialValue;

  /// Notifié avec la `List<Map<String, dynamic>>` agrégée à chaque mutation
  /// (structurelle OU valeur d'un sous-champ) — branché sur `setValue` parent.
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  /// Seam de test (voir [ZSubItemFieldBuilder]) ; `null` en production.
  @visibleForTesting
  final ZSubItemFieldBuilder? itemFieldBuilder;

  @override
  State<ZSubListFieldWidget> createState() => _ZSubListFieldWidgetState();
}

/// Item imbriqué : identité **stable** ([id]) + sous-contrôleur imbriqué.
class _SubItem {
  _SubItem(this.id, this.controller);

  final String id;
  final ZFormController controller;
}

class _ZSubListFieldWidgetState extends State<ZSubListFieldWidget> {
  /// Items imbriqués (source de vérité en édition ; agrégés vers le parent).
  final List<_SubItem> _items = <_SubItem>[];

  /// Compteur monotone d'identités d'items (clés stables, jamais réutilisées).
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    for (final data in _readList(widget.initialValue)) {
      _items.add(_makeItem(data));
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      _detach(item);
      item.controller.dispose();
    }
    super.dispose();
  }

  /// Sous-schéma `const` de l'item (vide si config absente/non conforme).
  List<ZFieldSpec> get _itemFields {
    final config = widget.field.config;
    return config is ZSubListConfig ? config.itemFields : const <ZFieldSpec>[];
  }

  bool get _reorderable {
    final config = widget.field.config;
    return config is ZSubListConfig ? config.reorderable : true;
  }

  /// Lecture **défensive** de la liste courante (`null`/type inattendu → `[]`).
  List<Map<String, dynamic>> _readList(Object? value) {
    if (value is List) {
      return <Map<String, dynamic>>[
        for (final e in value)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    }
    return const <Map<String, dynamic>>[];
  }

  _SubItem _makeItem(Map<String, dynamic> data) {
    final id = 'item_${_seq++}';
    final controller = ZFormController(
      initialValues: <String, Object?>{
        for (final f in _itemFields) f.name: data[f.name],
      },
      visibleFields: <String>[for (final f in _itemFields) f.name],
    );
    final item = _SubItem(id, controller);
    _attach(item);
    return item;
  }

  /// Attache le listener d'agrégation sur CHAQUE slice imbriqué. Un changement
  /// de valeur d'un sous-champ ne reconstruit PAS le conteneur (non souscrit à
  /// la tranche parente) — il se contente d'agréger vers le parent (SM-1
  /// imbriqué préservé).
  void _attach(_SubItem item) {
    for (final f in _itemFields) {
      item.controller.fieldListenable(f.name).addListener(_syncToParent);
    }
  }

  void _detach(_SubItem item) {
    for (final f in _itemFields) {
      item.controller.fieldListenable(f.name).removeListener(_syncToParent);
    }
  }

  /// Agrège l'état imbriqué en `List<Map>` et écrit la tranche parente. Appelé
  /// depuis un handler d'évènement (listener/bouton), JAMAIS pendant un `build`.
  void _syncToParent() {
    widget.onChanged(<Map<String, dynamic>>[
      for (final item in _items)
        <String, dynamic>{
          for (final f in _itemFields) f.name: item.controller.valueOf(f.name),
        },
    ]);
  }

  void _addItem() {
    setState(() {
      _items.add(_makeItem(const <String, dynamic>{}));
    });
    _syncToParent();
  }

  void _removeAt(int index) {
    final removed = _items[index];
    setState(() {
      _items.removeAt(index);
    });
    _detach(removed);
    removed.controller.dispose();
    _syncToParent();
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
    });
    _syncToParent();
  }

  Widget _buildItemField(_SubItem item, ZFieldSpec field) {
    final custom = widget.itemFieldBuilder;
    if (custom != null) return custom(context, item.controller, field, item.id);
    return ZFieldWidget(controller: item.controller, field: field);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final removeLabel = label(context, 'removeItem');
    final upLabel = label(context, 'moveItemUp');
    final downLabel = label(context, 'moveItemDown');
    final readOnly = widget.field.readOnly;

    return Semantics(
      container: true,
      label: resolvedLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Text(
              resolvedLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (var i = 0; i < _items.length; i++)
            KeyedSubtree(
              key: ValueKey<String>(_items[i].id),
              child: _SubItemCard(
                borderColor: theme.fieldBorderColor,
                radius: theme.radiusM,
                index: i,
                count: _items.length,
                reorderable: _reorderable && !readOnly,
                removable: !readOnly,
                removeLabel: removeLabel,
                upLabel: upLabel,
                downLabel: downLabel,
                onRemove: () => _removeAt(i),
                onMoveUp: () => _move(i, -1),
                onMoveDown: () => _move(i, 1),
                fields: <Widget>[
                  for (final f in _itemFields)
                    KeyedSubtree(
                      key: ValueKey<String>('${_items[i].id}/${f.name}'),
                      child: _buildItemField(_items[i], f),
                    ),
                ],
              ),
            ),
          if (!readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: Text(label(context, 'addItem')),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Carte d'un item imbriqué : sous-formulaire + contrôles (retrait/réordo)
/// accessibles (`IconButton` ≥ 48 dp), bordure dérivée du thème (FR-26).
class _SubItemCard extends StatelessWidget {
  const _SubItemCard({
    required this.borderColor,
    required this.radius,
    required this.index,
    required this.count,
    required this.reorderable,
    required this.removable,
    required this.removeLabel,
    required this.upLabel,
    required this.downLabel,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.fields,
  });

  final Color? borderColor;
  final Radius radius;
  final int index;
  final int count;
  final bool reorderable;
  final bool removable;
  final String removeLabel;
  final String upLabel;
  final String downLabel;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: borderColor == null ? null : Border.all(color: borderColor!),
          borderRadius: BorderRadius.all(radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Column(children: fields)),
                if (reorderable)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    tooltip: upLabel,
                    onPressed: index > 0 ? onMoveUp : null,
                  ),
                if (reorderable)
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    tooltip: downLabel,
                    onPressed: index < count - 1 ? onMoveDown : null,
                  ),
                if (removable)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: removeLabel,
                    onPressed: onRemove,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
