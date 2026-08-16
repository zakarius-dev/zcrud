/// Widget de la **famille item dynamique** (`dynamicItem`).
///
/// Édite un **item unique** dynamique (`Map<String, dynamic>?` en tranche
/// parente) : **ajouter** (créer l'item), **éditer** (sous-formulaire imbriqué),
/// **effacer** (`clear` → `null`). Variante de cardinalité ≤ 1 de la sous-liste
/// (`ZSubListFieldWidget`) — même invariant AD-2 (réactivité imbriquée) :
/// - monté par `ZFieldWidget` **AVANT** la souscription à la tranche parente →
///   éditer un sous-champ ne reconstruit PAS ce conteneur ni le formulaire
///   racine (le conteneur écoute un canal **structurel** : présence/absence de
///   l'item, géré par `setState`) ;
/// - la valeur `Map` est **agrégée hors de la voie de rebuild** via un listener
///   sur chaque slice imbriqué → `onChanged` (→ `setValue` parent) ;
/// - le `ZFormController` de l'item effacé est **`dispose`** (aucune fuite).
///
/// a11y/RTL (invariant AD-13) : boutons add/clear = `IconButton`/`TextButton`
/// (≥ 48 dp) + `Semantics`/tooltips ; insets **directionnels** ; bordure
/// dérivée du `ZcrudTheme` (invariant FR-26).
///
/// ## Seams de présentation — résolus par le CHEMIN NOMINAL
///
/// Comme la sous-liste, cette famille lit ses seams dans le **canal**
/// `ZSubListSeamRegistry` (`ZcrudScope.subListSeamRegistry`), résolu **ici**
/// plutôt que relayé par `ZFieldWidget`. Le motif est le même : [fieldsResolver]
/// existait en paramètre mais le dispatcher ne le transmettait pas — le seam
/// n'était donc atteignable qu'en remplaçant le champ entier par un
/// `fieldBuilder`.
///
/// Deux seams seulement ont un sens ici (cardinalité ≤ 1, item toujours
/// déballé, ni liste ni résumé ni en-tête à habiller) :
/// - `itemFieldsResolver` → sous-champs rendus (équivalent de [fieldsResolver]) ;
/// - `itemActionsBuilder` → actions **supplémentaires**, après « effacer ».
///
/// Les autres seams du bundle sont **ignorés** silencieusement (invariant
/// AD-10). Priorité : paramètre du constructeur > seam du registre > défaut.
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/z_field_spec.dart';
import '../../../domain/edition/z_sub_list_config.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';
import '../../z_form_controller.dart';
import '../../zcrud_scope.dart';
import '../z_field_widget.dart';
import '../z_sub_list_seams.dart';
import 'z_sub_list_field_widget.dart' show ZSubItemFieldBuilder;

/// **Seam de champs dynamiques** : calcule la **liste des sous-champs à
/// RENDRE** à partir de l'état COURANT de l'item (`Map`). Vit en couche
/// présentation (jamais une closure dans le domaine — invariants AD-3/AD-14,
/// garde `domain_purity_test`). Défensif (invariant AD-10) : le résultat est
/// **intersecté** avec `itemFields` de la config (par `name`) — un champ hors
/// config est ignoré (aucune tranche orpheline, invariant AD-2).
///
/// Alias historique de [ZSubItemFieldsResolver], porté par le canal
/// `ZSubListSeams.itemFieldsResolver` : même signature, même contrat.
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

  /// Seam de champs dynamiques (voir [ZDynamicItemFieldsResolver]).
  /// `null` (défaut) ⇒ le seam `itemFieldsResolver` du registre
  /// (`ZcrudScope.subListSeamRegistry`) est consulté ; à défaut, rendu de tous
  /// les `itemFields` de la config (rétro-compat).
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

  /// **Clés de la GRAINE que le sous-schéma ne gère pas** (même mécanisme
  /// que `ZSubListFieldWidget` : sans ce résidu, l'item serait RECOMPOSÉ à
  /// partir des seuls `itemFields`, donc `id` et toute clé non déclarée
  /// seraient **détruits dès la première frappe**).
  ///
  /// Cardinalité ≤ 1 : il n'y a qu'un item vivant à la fois et ce champ est
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

  /// Valeurs par défaut d'un nouvel item (vide si config absente).
  Map<String, Object?> get _defaultNewItem {
    final config = widget.field.config;
    return config is ZSubListConfig
        ? config.defaultNewItem
        : const <String, Object?>{};
  }

  /// Libellé du bouton de création (repli `addItem`).
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

  /// Sous-champs à **RENDRE** : le seam [ZDynamicItemFieldsResolver]
  /// s'il est fourni (intersecté défensivement avec `itemFields` par `name` —
  /// aucune tranche orpheline, invariants AD-10/AD-2), sinon tous les
  /// `itemFields`.
  /// **Seams de présentation** résolus dans le `ZcrudScope` ambiant pour CE
  /// champ (cascade `widgetKind` → `name` → `type.name`). `null` ⇒ rendu natif,
  /// inchangé (invariant AD-10).
  ZSubListSeams? get _seams =>
      ZcrudScope.maybeOf(context)?.subListSeamRegistry?.resolve(widget.field);

  /// Invoque un seam hôte **défensivement** (invariant AD-10) : un seam qui
  /// lève est traité comme un seam **absent**.
  static T? _safe<T>(T Function() run) {
    try {
      return run();
    } catch (_) {
      return null;
    }
  }

  /// Snapshot **complet** de l'item (résidu hors schéma d'abord, tranches
  /// ensuite — même ordre que `_syncToParent`). C'est la donnée servie aux
  /// seams : un identifiant technique non déclaré au sous-schéma y figure.
  Map<String, dynamic> _rawItemData(ZFormController controller) =>
      <String, dynamic>{
        ..._unmapped,
        for (final f in _itemFields) f.name: controller.valueOf(f.name),
      };

  /// **Actions supplémentaires** de l'item ([ZSubListSeams.itemActionsBuilder])
  /// — rendues **après** « effacer », jamais à sa place. Chaque action est
  /// contrainte à ≥ 48 dp (invariant AD-13) : le socle ne peut pas garantir la
  /// cible tactile d'un widget qu'il ne construit pas, il garantit la place
  /// qu'il lui réserve. Seam absent ou qui lève ⇒ liste vide (invariant AD-10),
  /// donc le rendu d'avant.
  List<Widget> _extraActions(
    BuildContext context,
    ZFormController controller,
  ) {
    final builder = _seams?.itemActionsBuilder;
    if (builder == null) return const <Widget>[];
    final built = _safe(() => builder(
          context,
          ZSubListItemView(
            field: widget.field,
            data: _rawItemData(controller),
            index: 0,
            itemId: _itemId ?? '',
            readOnly: widget.field.readOnly,
          ),
        ));
    if (built == null || built.isEmpty) return const <Widget>[];
    return <Widget>[
      for (final action in built)
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: action,
        ),
    ];
  }

  List<ZFieldSpec> _renderFields(ZFormController controller) {
    // Priorité : paramètre du constructeur > seam du registre > config.
    final resolver = widget.fieldsResolver ?? _seams?.itemFieldsResolver;
    if (resolver == null) return _itemFields;
    final known = <String>{for (final f in _itemFields) f.name};
    List<ZFieldSpec> resolved;
    try {
      resolved = resolver(_currentData(controller));
    } catch (_) {
      return _itemFields; // Invariant AD-10 : resolver défaillant ⇒ repli config.
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
    // L'item disparaît → son résidu de graine aussi. Sans cela, un
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
            // Résidu hors schéma de la graine EN PREMIER — les tranches
            // écrites ensuite priment toujours (un champ effacé reste effacé).
            ..._unmapped,
            for (final f in _itemFields) f.name: controller.valueOf(f.name),
          });
  }

  void _addItem() {
    setState(() {
      // Amorce le nouvel item avec `defaultNewItem` (défensif).
      _controller = _makeController(Map<String, dynamic>.from(_defaultNewItem));
      // Un item AJOUTÉ n'a pas de graine → aucun résidu (comportement
      // strictement inchangé). Explicite, pour ne dépendre d'aucun état résiduel.
      _unmapped = const <String, dynamic>{};
    });
    _syncToParent();
  }

  void _clearItem() {
    setState(_disposeController);
    _syncToParent();
  }

  /// **La lecture seule DESCEND dans les sous-champs.**
  ///
  /// `DynamicEdition._effective` ne force `readOnly: true` que sur les specs de
  /// PREMIER NIVEAU : les `itemFields` portés par la config ne sont pas
  /// parcourus. Sans ce report, un item ouvert en mode lecture globale
  /// resterait **entièrement éditable et focalisable**. Même mécanisme que
  /// celui appliqué au dialogue de la sous-liste compacte.
  ///
  /// Le **mode de présentation** n'a pas à être relayé : il descend par le
  /// contexte (`ZReadModeScope`). En consultation, les champs de l'item sont
  /// donc rendus en **fiches**.
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
                            // Sous-champs dynamiques (seam) évalués au build
                            // STRUCTUREL du conteneur (invariant AD-2 préservé).
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
                      // Actions supplémentaires de l'hôte — **après** effacer,
                      // jamais à sa place. Aucun seam ⇒ liste vide, donc aucun
                      // widget ajouté : structure inchangée.
                      ..._extraActions(context, controller),
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
