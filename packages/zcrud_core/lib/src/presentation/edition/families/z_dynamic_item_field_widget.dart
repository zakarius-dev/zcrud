/// Widget de la **famille item dynamique** (`dynamicItem`) — E3-3b-2.
///
/// Édite un **item unique** dynamique (`Map<String, dynamic>?` en tranche
/// parente) : **ajouter** (créer l'item), **éditer** (sous-formulaire imbriqué),
/// **effacer** (`clear` → `null`). Variante de cardinalité ≤ 1 de la sous-liste
/// (`ZSubListFieldWidget`) — même invariant **SM-1 IMBRIQUÉ** (AD-2) :
/// - monté par `ZFieldWidget` **AVANT** la souscription à la tranche parente →
///   éditer un sous-champ ne reconstruit PAS ce conteneur ni le formulaire
///   racine (le conteneur écoute un canal **structurel** : présence/absence de
///   l'item, géré par `setState`) ;
/// - la valeur `Map` est **agrégée hors de la voie de rebuild** via un listener
///   sur chaque slice imbriqué → `onChanged` (→ `setValue` parent) ;
/// - le `ZFormController` de l'item effacé est **`dispose`** (aucune fuite).
///
/// a11y/RTL (AD-13) : boutons add/clear = `IconButton`/`TextButton` (≥ 48 dp) +
/// `Semantics`/tooltips ; insets **directionnels** ; bordure dérivée du
/// `ZcrudTheme` (FR-26).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_spec.dart';
import '../../../domain/edition/z_sub_list_config.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';
import '../../z_form_controller.dart';
import '../z_field_widget.dart';
import 'z_sub_list_field_widget.dart' show ZSubItemFieldBuilder;

/// DP-19 (M19) — **Seam de champs dynamiques** (parité `subItemsFormFieldsBuilder
/// (state)` DODLP) : calcule la **liste des sous-champs à RENDRE** à partir de
/// l'état COURANT de l'item (`Map`). Vit en couche présentation (jamais une
/// closure dans le domaine — AD-3/AD-14, garde `domain_purity_test`). Défensif
/// (AD-10) : le résultat est **intersecté** avec `itemFields` de la config (par
/// `name`) — un champ hors config est ignoré (aucune tranche orpheline, SM-1).
typedef ZDynamicItemFieldsResolver = List<ZFieldSpec> Function(
  Map<String, dynamic> state,
);

/// Champ d'édition d'un **item unique dynamique** (`Map?` en tranche parente).
class ZDynamicItemFieldWidget extends StatefulWidget {
  /// Construit le champ item dynamique pour [field], valeur initiale
  /// [initialValue] (`Map` ou `null`), agrégeant vers le parent via [onChanged].
  const ZDynamicItemFieldWidget({
    required this.field,
    required this.initialValue,
    required this.onChanged,
    this.itemFieldBuilder,
    this.fieldsResolver,
    super.key,
  });

  /// Spécification `const` du champ rendu (`config` = [ZSubListConfig]).
  final ZFieldSpec field;

  /// Valeur INITIALE de la tranche parente (`Map` ou `null`) — lue **une fois**
  /// pour amorcer le sous-contrôleur.
  final Object? initialValue;

  /// Notifié avec le `Map<String, dynamic>?` agrégé (`null` si effacé) — branché
  /// sur `setValue` parent.
  final ValueChanged<Map<String, dynamic>?> onChanged;

  /// Seam de test (voir [ZSubItemFieldBuilder]) ; `null` en production.
  @visibleForTesting
  final ZSubItemFieldBuilder? itemFieldBuilder;

  /// DP-19 (M19) — seam de champs dynamiques (voir [ZDynamicItemFieldsResolver]).
  /// `null` (défaut) ⇒ rendu de tous les `itemFields` de la config (rétro-compat).
  final ZDynamicItemFieldsResolver? fieldsResolver;

  @override
  State<ZDynamicItemFieldWidget> createState() =>
      _ZDynamicItemFieldWidgetState();
}

class _ZDynamicItemFieldWidgetState extends State<ZDynamicItemFieldWidget> {
  /// Sous-contrôleur imbriqué de l'item (source de vérité en édition) ; `null`
  /// tant qu'aucun item n'est présent.
  ZFormController? _controller;

  /// Identité **stable** de l'item courant (clé de place ; jamais réutilisée).
  int _seq = 0;
  String? _itemId;

  /// LOT B — **clés de la GRAINE que le sous-schéma ne gère pas** (même défaut
  /// et même correctif que `ZSubListFieldWidget` : l'item était RECOMPOSÉ à
  /// partir des seuls `itemFields`, donc `id` et toute clé non déclarée étaient
  /// **détruits dès la première frappe**).
  ///
  /// 🔴 Cardinalité ≤ 1 : il n'y a qu'un item vivant à la fois et ce champ est
  /// écrit/effacé **exactement aux mêmes points** que `_controller` — l'appariement
  /// graine ↔ item est donc trivialement par identité, jamais par index. Le
  /// résidu est réémis AVANT les tranches (un champ effacé reste effacé) et
  /// n'est peuplé **que** depuis la graine du parent : un item **ajouté** n'a
  /// pas de graine, son comportement est inchangé.
  Map<String, dynamic> _unmapped = const <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    final data = _readMap(widget.initialValue);
    if (data != null) {
      _controller = _makeController(data);
      // SEUL point d'entrée d'une graine venue du parent.
      _unmapped = _unmappedOf(data);
    }
  }

  /// Résidu de [data] : clés que le sous-schéma **ne déclare pas**. Une clé
  /// déclarée n'y entre JAMAIS (garantit qu'un champ effacé ne ressuscite pas).
  Map<String, dynamic> _unmappedOf(Map<String, dynamic> data) {
    final known = <String>{for (final f in _itemFields) f.name};
    final rest = <String, dynamic>{
      for (final entry in data.entries)
        if (!known.contains(entry.key)) entry.key: entry.value,
    };
    return rest.isEmpty ? const <String, dynamic>{} : rest;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  List<ZFieldSpec> get _itemFields {
    final config = widget.field.config;
    return config is ZSubListConfig ? config.itemFields : const <ZFieldSpec>[];
  }

  /// DP-19 (M19) — valeurs par défaut d'un nouvel item (vide si config absente).
  Map<String, Object?> get _defaultNewItem {
    final config = widget.field.config;
    return config is ZSubListConfig
        ? config.defaultNewItem
        : const <String, Object?>{};
  }

  /// DP-19 (M19) — libellé du bouton de création (repli `addItem`).
  String _addLabel(BuildContext context) {
    final config = widget.field.config;
    final key = config is ZSubListConfig ? config.createNewTextKey : null;
    return label(context, key ?? 'addItem', fallback: label(context, 'addItem'));
  }

  /// Snapshot `Map` des valeurs courantes de l'item (lecture des tranches).
  Map<String, dynamic> _currentData(ZFormController controller) =>
      <String, dynamic>{
        for (final f in _itemFields) f.name: controller.valueOf(f.name),
      };

  /// DP-19 (M19) — sous-champs à **RENDRE** : le seam [ZDynamicItemFieldsResolver]
  /// s'il est fourni (intersecté défensivement avec `itemFields` par `name` —
  /// aucune tranche orpheline, AD-10/SM-1), sinon tous les `itemFields`.
  List<ZFieldSpec> _renderFields(ZFormController controller) {
    final resolver = widget.fieldsResolver;
    if (resolver == null) return _itemFields;
    final known = <String>{for (final f in _itemFields) f.name};
    List<ZFieldSpec> resolved;
    try {
      resolved = resolver(_currentData(controller));
    } catch (_) {
      return _itemFields; // AD-10 : resolver défaillant ⇒ repli config.
    }
    final rendered = <ZFieldSpec>[
      for (final f in resolved)
        if (known.contains(f.name)) f,
    ];
    return rendered.isEmpty ? _itemFields : rendered;
  }

  /// Lecture **défensive** (`null`/type inattendu → `null`).
  Map<String, dynamic>? _readMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  ZFormController _makeController(Map<String, dynamic> data) {
    _itemId = 'item_${_seq++}';
    final controller = ZFormController(
      initialValues: <String, Object?>{
        for (final f in _itemFields) f.name: data[f.name],
      },
      visibleFields: <String>[for (final f in _itemFields) f.name],
    );
    for (final f in _itemFields) {
      controller.fieldListenable(f.name).addListener(_syncToParent);
    }
    return controller;
  }

  void _disposeController() {
    final controller = _controller;
    if (controller == null) return;
    for (final f in _itemFields) {
      controller.fieldListenable(f.name).removeListener(_syncToParent);
    }
    controller.dispose();
    _controller = null;
    _itemId = null;
    // LOT B : l'item disparaît → son résidu de graine aussi. Sans cela, un
    // `clear` suivi d'un `add` réémettrait le résidu de l'item EFFACÉ sur un
    // item neuf (résurrection d'une donnée volontairement supprimée).
    _unmapped = const <String, dynamic>{};
  }

  /// Agrège l'item en `Map?` et écrit la tranche parente. Handler d'évènement,
  /// JAMAIS pendant un `build`.
  void _syncToParent() {
    final controller = _controller;
    widget.onChanged(controller == null
        ? null
        : <String, dynamic>{
            // LOT B : résidu hors schéma de la graine EN PREMIER — les tranches
            // écrites ensuite priment toujours (un champ effacé reste effacé).
            ..._unmapped,
            for (final f in _itemFields) f.name: controller.valueOf(f.name),
          });
  }

  void _addItem() {
    setState(() {
      // DP-19 (M19) : amorce le nouvel item avec `defaultNewItem` (défensif).
      _controller = _makeController(Map<String, dynamic>.from(_defaultNewItem));
      // LOT B : un item AJOUTÉ n'a pas de graine → aucun résidu (comportement
      // strictement inchangé). Explicite, pour ne dépendre d'aucun état résiduel.
      _unmapped = const <String, dynamic>{};
    });
    _syncToParent();
  }

  void _clearItem() {
    setState(_disposeController);
    _syncToParent();
  }

  /// LOT 3 — **la lecture seule DESCEND dans les sous-champs.**
  ///
  /// `DynamicEdition._effective` ne force `readOnly: true` que sur les specs de
  /// PREMIER NIVEAU : les `itemFields` portés par la config ne sont pas
  /// parcourus. Sans ce report, un item ouvert en mode lecture globale restait
  /// **entièrement éditable et focalisable** (fuite mesurée). Même correctif que
  /// celui déjà appliqué au dialogue de la sous-liste compacte.
  Widget _buildItemField(ZFormController controller, ZFieldSpec field) {
    final spec = widget.field.readOnly && !field.readOnly
        ? field.copyWith(readOnly: true)
        : field;
    final custom = widget.itemFieldBuilder;
    if (custom != null) {
      return custom(context, controller, spec, _itemId ?? '');
    }
    return ZFieldWidget(controller: controller, field: spec);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final readOnly = widget.field.readOnly;
    final controller = _controller;

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
          if (controller != null)
            KeyedSubtree(
              key: ValueKey<String>(_itemId!),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: theme.fieldBorderColor == null
                        ? null
                        : Border.all(color: theme.fieldBorderColor!),
                    borderRadius: BorderRadius.all(theme.radiusM),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // DP-19 (M19) : sous-champs dynamiques (seam) évalués
                            // au build STRUCTUREL du conteneur (SM-1 préservé).
                            for (final f in _renderFields(controller))
                              KeyedSubtree(
                                key: ValueKey<String>('$_itemId/${f.name}'),
                                child: _buildItemField(controller, f),
                              ),
                          ],
                        ),
                      ),
                      if (!readOnly)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: label(context, 'clearItem'),
                          onPressed: _clearItem,
                        ),
                    ],
                  ),
                ),
              ),
            )
          else if (!readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: Text(_addLabel(context)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
