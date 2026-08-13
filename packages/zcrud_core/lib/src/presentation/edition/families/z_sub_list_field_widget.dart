/// Widget de la **famille sous-liste** (`subItems`) : **mini-CRUD
/// imbriqué** (POINT DE VIGILANCE invariant AD-2).
///
/// Édite une `List<Map<String, dynamic>>` d'items : **ajouter**, **supprimer**,
/// **réordonner**. Chaque item est édité par un **sous-formulaire imbriqué** —
/// un `ZFormController` PROPRE à l'item (slice imbriqué) réutilisant le
/// dispatcher `ZFieldWidget`.
///
/// **RÉACTIVITÉ IMBRIQUÉE (invariant AD-2)** — invariants NON-NÉGOCIABLES :
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
///   du dispatcher + tranches.
///
/// Ce widget est le **champ d'édition imbriqué** (dans un formulaire) ; un
/// **écran de sous-liste autonome** (mini-CRUD plein écran) resterait un
/// composant distinct, non dupliqué ici. Le sous-schéma `const`
/// ([ZSubListConfig.itemFields]) est la brique commune réutilisable.
///
/// a11y/RTL (invariant AD-13) : boutons add/remove/monter/descendre =
/// `IconButton` (cibles ≥ 48 dp) + `Semantics`/tooltips ; insets
/// **directionnels** ; aucune couleur codée en dur (bordure dérivée du
/// `ZcrudTheme` — invariant FR-26).
///
/// **Mode compact** additif : lorsque `config.displayMode ==
/// ZSubListDisplayMode.compact`, le widget rend une **liste résumé** (une
/// ligne/valeurs de résumé par item, jamais les sous-champs éditables inline)
/// + un **dialog d'édition PAR ITEM** (ajouter/consulter/modifier/supprimer),
/// chaque action **filtrée par `ZAcl`**. Le mode `inline` (défaut) est
/// **strictement préservé**. Dans le dialog : `ZFormController` PROPRE,
/// `ZFieldWidget` réutilisé, aucun `Form` global.
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/edition_field_type.dart';
import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../../domain/edition/z_sub_list_config.dart';
import '../../../domain/ports/z_acl.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';
import '../../z_form_controller.dart';
import '../../zcrud_scope.dart';
import '../z_field_widget.dart';
import '../z_read_only_value.dart';
import '../z_select_choices_resolver.dart';
import '../z_value_emptiness.dart';

/// Seam (usage de test) : construit le widget d'édition d'un **sous-champ**
/// d'item, avec le contexte de l'item (`itemId`) pour instrumenter les compteurs
/// de rebuild imbriqués (preuve de granularité, invariant AD-2). À défaut :
/// dispatcher `ZFieldWidget`. Le type est public ; le **paramètre** qui le
/// porte est `@visibleForTesting` (production : toujours `null`).
typedef ZSubItemFieldBuilder = Widget Function(
  BuildContext context,
  ZFormController itemController,
  ZFieldSpec field,
  String itemId,
);

/// Seam de **présentation** : dérive un **titre/résumé** lisible d'un item
/// (`Map`) — titre du dialog d'édition et repli de résumé de ligne en mode
/// compact. Vit en couche widget (JAMAIS dans la config domaine — garde
/// `domain_purity_test`).
typedef ZSubItemTitleBuilder = String Function(Map<String, dynamic> item);

/// Champ d'édition d'une **sous-liste** d'items (`List<Map>` en tranche parente).
class ZSubListFieldWidget extends StatefulWidget {
  /// Construit le champ sous-liste pour [field], valeur initiale [initialValue]
  /// (`List<Map>` ou `null`), agrégeant vers la tranche parente via [onChanged].
  ///
  /// [acl] filtre les actions du mode compact. `null` (défaut) ⇒ l'ACL du
  /// `ZcrudScope` ambiant est consultée ; sans scope, le repli est **refusant**
  /// (`ZDenyAllAcl`) : aucune action d'item n'est offerte. [collectionId] est
  /// transmis à `ZAcl.can(..., collectionId:)` ;
  /// [itemTitleBuilder] dérive le titre du dialog / résumé de ligne. Ces
  /// paramètres sont **ignorés** en mode `inline` (comportement inchangé).
  const ZSubListFieldWidget({
    required this.field,
    required this.initialValue,
    required this.onChanged,
    this.itemFieldBuilder,
    this.acl,
    this.collectionId,
    this.itemTitleBuilder,
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

  /// Port d'autorisation consommé **uniquement** en mode compact pour
  /// filtrer add/view/edit/delete.
  ///
  /// `null` (défaut) ⇒ ACL du `ZcrudScope` ambiant, puis repli **refusant**
  /// (`ZDenyAllAcl`). En développement, l'ouverture totale se déclare :
  /// `ZcrudScope(acl: const ZAllowAllAcl())`.
  final ZAcl? acl;

  /// Discriminant de collection transmis à [ZAcl.can]. `null` par défaut.
  final String? collectionId;

  /// Seam de titre d'item, mode compact. `null` → titre dérivé des
  /// `summaryFields`/champs + libellé du champ.
  final ZSubItemTitleBuilder? itemTitleBuilder;

  @override
  State<ZSubListFieldWidget> createState() => _ZSubListFieldWidgetState();
}

/// Item imbriqué : identité **stable** ([id]) + sous-contrôleur imbriqué.
class _SubItem {
  _SubItem(this.id, this.controller, {this.unmapped = const <String, dynamic>{}});

  final String id;
  final ZFormController controller;

  /// **Clés de la GRAINE que le sous-schéma ne gère pas.**
  ///
  /// Le sous-formulaire d'un item n'alloue une tranche que pour les `itemFields`
  /// déclarés. Sans ce résidu, l'item réémis serait RECOMPOSÉ à partir de ces
  /// seuls champs et toute autre clé portée par la graine — `id` en premier —
  /// **disparaîtrait dès la première frappe** dans n'importe quel sous-champ.
  /// Ce ne serait pas un affichage faux : la donnée serait détruite (un
  /// identifiant technique ou une clé annexe non déclarée au sous-schéma).
  ///
  /// **Pourquoi ce point de conservation, et pas un autre :**
  /// - il est porté par l'**item lui-même**, donc l'appariement graine ↔ item est
  ///   fait par **IDENTITÉ**, jamais par index. Un `_move`/`_removeAt`/
  ///   soft-delete transporte le résidu avec son item : il est structurellement
  ///   impossible de recoller la graine d'un item sur un autre — ce qui serait
  ///   **pire** que la perte d'origine ;
  /// - il ne contient **JAMAIS** une clé déclarée (filtrée à la construction),
  ///   et il est fusionné **AVANT** les tranches dans `_syncToParent` : un champ
  ///   que l'utilisateur **efface** reste effacé, il ne ressuscite pas depuis la
  ///   graine ;
  /// - il n'est peuplé que depuis la graine du parent (`initState`). Un item
  ///   **ajouté** n'a pas de graine : son résidu reste vide et son comportement
  ///   est inchangé.
  final Map<String, dynamic> unmapped;

  /// Soft-delete : `true` ⇒ item **marqué supprimé** (exclu de l'agrégation
  /// parent) mais conservé pour **restauration** en session.
  bool deleted = false;
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
      // SEUL point d'entrée d'une GRAINE (données du parent) → seul point où
      // un résidu hors schéma est capturé (cf. `_SubItem.unmapped`).
      _items.add(_makeItem(data, preserveUnmapped: true));
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

  /// Mode de rendu — `inline` (défaut) si config absente/non conforme.
  ZSubListDisplayMode get _displayMode {
    final config = widget.field.config;
    return config is ZSubListConfig
        ? config.displayMode
        : ZSubListDisplayMode.inline;
  }

  /// Champs résumé du mode compact — vide si config absente/non conforme.
  List<String> get _summaryFields {
    final config = widget.field.config;
    return config is ZSubListConfig ? config.summaryFields : const <String>[];
  }

  /// En-têtes de colonnes du résumé ? (**opt-in**, défaut `false` ⇒ mise en
  /// page compacte strictement inchangée).
  bool get _showSummaryHeaders {
    final config = widget.field.config;
    return config is ZSubListConfig && config.showSummaryHeaders;
  }

  /// Soft-delete actif ? (défaut `false`, config absente/non conf.)
  bool get _softDelete {
    final config = widget.field.config;
    return config is ZSubListConfig && config.softDelete;
  }

  /// Gabarits de création (vide si config absente/non conforme).
  List<ZSubListItemTemplate> get _creationTemplates {
    final config = widget.field.config;
    return config is ZSubListConfig
        ? config.creationTemplates
        : const <ZSubListItemTemplate>[];
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

  /// Construit un item. [preserveUnmapped] n'est `true` que pour une **graine**
  /// venue du parent (`initState`) : un item **ajouté** (bouton `+` ou dialog
  /// d'ajout) n'a pas de graine, son résidu reste vide et son comportement est
  /// strictement inchangé.
  _SubItem _makeItem(Map<String, dynamic> data, {bool preserveUnmapped = false}) {
    final id = 'item_${_seq++}';
    final controller = ZFormController(
      initialValues: <String, Object?>{
        for (final f in _itemFields) f.name: data[f.name],
      },
      visibleFields: <String>[for (final f in _itemFields) f.name],
    );
    final item = _SubItem(
      id,
      controller,
      unmapped: preserveUnmapped ? _unmappedOf(data) : const <String, dynamic>{},
    );
    _attach(item);
    return item;
  }

  /// Résidu de [data] : les clés que le sous-schéma **ne déclare pas**. Une clé
  /// déclarée n'y entre JAMAIS — c'est ce qui garantit qu'un champ effacé par
  /// l'utilisateur ne ressuscite pas depuis la graine.
  Map<String, dynamic> _unmappedOf(Map<String, dynamic> data) {
    final known = <String>{for (final f in _itemFields) f.name};
    final rest = <String, dynamic>{
      for (final entry in data.entries)
        if (!known.contains(entry.key)) entry.key: entry.value,
    };
    return rest.isEmpty ? const <String, dynamic>{} : rest;
  }

  /// Attache le listener d'agrégation sur CHAQUE slice imbriqué. Un changement
  /// de valeur d'un sous-champ ne reconstruit PAS le conteneur (non souscrit à
  /// la tranche parente) — il se contente d'agréger vers le parent (invariant
  /// AD-2 préservé).
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
      // Un item soft-deleted est EXCLU de l'agrégation parent (retiré des
      // données) mais conservé localement pour restauration.
      for (final item in _items)
        if (!item.deleted)
          <String, dynamic>{
            // Le résidu hors schéma de la GRAINE DE CET ITEM (apparié par
            // identité — il voyage avec l'item à travers réordonnancement,
            // retrait et soft-delete) est réémis EN PREMIER : les tranches
            // écrites ensuite priment TOUJOURS, donc un champ déclaré effacé
            // reste effacé (`null`) et ne ressuscite pas.
            ...item.unmapped,
            for (final f in _itemFields) f.name: item.controller.valueOf(f.name),
          },
    ]);
  }

  void _addItem() {
    setState(() {
      // Amorce le nouvel item avec `defaultNewItem` (défensif).
      _items.add(_makeItem(Map<String, dynamic>.from(_defaultNewItem)));
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

  /// **La lecture seule DESCEND dans les sous-champs.**
  ///
  /// `DynamicEdition._effective` ne force `readOnly: true` que sur les specs de
  /// PREMIER NIVEAU : les `itemFields` ne sont pas parcourus par ce mécanisme.
  /// En mode `inline`, sans ce relais, seuls les boutons du conteneur
  /// seraient gatés — les champs internes resteraient **éditables et
  /// focalisables**. La règle est la MÊME pour les trois modes (le mode
  /// `compact` la couvre dans son dialogue,
  /// `_ZSubItemEditDialog._buildField`).
  Widget _buildItemField(_SubItem item, ZFieldSpec field) {
    final spec = widget.field.readOnly && !field.readOnly
        ? field.copyWith(readOnly: true)
        : field;
    final custom = widget.itemFieldBuilder;
    if (custom != null) return custom(context, item.controller, spec, item.id);
    return ZFieldWidget(controller: item.controller, field: spec);
  }

  @override
  Widget build(BuildContext context) {
    // Dispatch EXPLICITE par mode de rendu, décidé UNE FOIS au build du
    // conteneur (l'édition vit dans le dialog → pas de rebuild par frappe).
    // `switch` exhaustif SANS `default:` : un futur mode casse la
    // compilation → JAMAIS un repli silencieux vers `inline`.
    switch (_displayMode) {
      case ZSubListDisplayMode.compact:
        return _buildCompact(context);
      case ZSubListDisplayMode.tags:
        return _buildTags(context);
      case ZSubListDisplayMode.inline:
        return _buildInline(context);
    }
  }

  /// Rendu **inline** — STRICTEMENT préservé.
  Widget _buildInline(BuildContext context) {
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

    // a11y : le conteneur ne porte PAS `label:` — le `Text` visible
    // ci-dessous fournit déjà le nom accessible de la section. Un `label:`
    // sur le `Semantics(container:)` DOUBLERAIT l'annonce du lecteur d'écran
    // (deux nœuds « Items »). Le `container: true` conserve la frontière
    // sémantique (groupement) sans redoublement.
    return Semantics(
      container: true,
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
                  label: Text(_addLabel(context)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Mode compact (liste résumé + dialog par item) ──────────────────────────

  /// Représentation textuelle stable d'une valeur (`null`/vide → `''`,
  /// invariant AD-10).
  static String _stringOf(Object? value) => value == null ? '' : '$value';

  /// Sous-spec de [name] dans le sous-schéma `const`, ou `null` si le `name`
  /// déclaré en `summaryFields` ne correspond à aucun `itemField` (invariant
  /// AD-10 : une config incohérente ne fait pas échouer le rendu).
  ZFieldSpec? _specOf(String name) {
    for (final f in _itemFields) {
      if (f.name == name) return f;
    }
    return null;
  }

  /// **Projection d'AFFICHAGE** d'une valeur de résumé.
  ///
  /// Ce n'est **pas** une copie du motif `'$value'` : elle **réutilise**
  /// `zReadOnlyValueOf`, la projection d'affichage déjà en place pour le mode
  /// lecture — donc les MÊMES règles, dans le même canal :
  /// - un `select`/`radio`/`checkbox`/`relation`/`rowChips` rend le **libellé**
  ///   du choix, jamais sa clé technique ;
  /// - une valeur **orpheline** (sélectionnée puis retirée des choix) rend le
  ///   libellé l10n `choiceUnresolved` de `z_orphan_choice.dart` — le même
  ///   libellé et le même canal que les autres voies de rendu, ni
  ///   disparition ni clé brute ;
  /// - une date rend le port `ZDateDisplayFormatter` (chaîne brute sans port).
  ///
  /// Les **choix effectifs** sont résolus par `zResolveSelectChoices` sur le
  /// contrôleur DE L'ITEM : une source `ZChoicesSource` (synchrone), un
  /// `choicesFromKey` ou des options dérivées de l'item sont donc honorés — une
  /// valeur légitime issue d'une source dynamique n'est PAS vue comme orpheline.
  /// La famille `relation` (source = `Stream`) reste hors de portée synchrone :
  /// elle retombe sur `choices` statiques, donc sur le libellé d'orphelin.
  ///
  /// **Valeur vide ⇒ `''` STRICTEMENT** (jamais le placeholder « — » de la fiche
  /// de lecture) : le mettre déplacerait tout hôte passif.
  ///
  /// **Périmètre volontairement BORNÉ** : choix et dates. Les autres familles
  /// gardent `_stringOf` **inchangé** — router tout le résumé dans
  /// `zReadOnlyValueOf` transformerait aussi, sans qu'un hôte l'ait demandé,
  /// `true` en « Oui », `42` en « 42 % », une valeur `password` en « •••• ».
  /// Un hôte passif ne bouge donc QUE là où c'est exigé (libellés de choix)
  /// ou là où il a injecté un port (dates).
  ///
  /// Invariant AD-2 : lecture de la seule tranche du sous-champ, aucun objet
  /// coûteux alloué, aucune souscription — la cellule ne reconstruit rien
  /// au-delà d'elle.
  String _displayText(BuildContext context, _SubItem item, String name) {
    final raw = item.controller.valueOf(name);
    if (zIsEmptyValue(raw)) return '';
    final spec = _specOf(name);
    if (spec == null || !_projectedTypes.contains(spec.type)) {
      return _stringOf(raw);
    }
    final cfg = spec.config;
    final rov = zReadOnlyValueOf(
      context,
      spec,
      raw,
      choices: zResolveSelectChoices(
        context,
        item.controller,
        spec,
        cfg is ZSelectConfig ? cfg : null,
      ),
    );
    // `rov.widget` n'a pas de texte : repli brut (aucune famille projetée ici
    // n'en produit — garde-fou AD-10).
    return rov.text ?? _stringOf(raw);
  }

  /// Familles dont le résumé est **projeté** : les familles à choix (libellé
  /// au lieu de la clé) et les familles de date (port d'affichage). Toute
  /// autre famille conserve son rendu brut d'origine.
  static const Set<EditionFieldType> _projectedTypes = <EditionFieldType>{
    EditionFieldType.select,
    EditionFieldType.radio,
    EditionFieldType.checkbox,
    EditionFieldType.relation,
    EditionFieldType.rowChips,
    EditionFieldType.dateTime,
    EditionFieldType.time,
  };

  /// Snapshot `Map` des valeurs courantes d'un item (lecture des tranches).
  Map<String, dynamic> _itemData(_SubItem item) => <String, dynamic>{
        for (final f in _itemFields) f.name: item.controller.valueOf(f.name),
      };

  /// Applique **défensivement** le seam de titre (invariant AD-10 : un
  /// builder hôte qui throw ne fait jamais échouer le parent → repli `null`).
  String? _safeTitle(ZSubItemTitleBuilder builder, Map<String, dynamic> data) {
    try {
      return builder(data);
    } catch (_) {
      return null;
    }
  }

  /// Titre de résumé d'une ligne quand aucun `summaryFields` :
  /// `itemTitleBuilder` s'il est fourni, sinon **concaténation lisible** des
  /// valeurs non nulles des `itemFields` (jamais un déballage éditable).
  String _defaultTitle(BuildContext context, _SubItem item) {
    final data = _itemData(item);
    final builder = widget.itemTitleBuilder;
    if (builder != null) {
      final t = _safeTitle(builder, data);
      if (t != null && t.isNotEmpty) return t;
    }
    // Le `itemTitleBuilder` reçoit toujours la donnée BRUTE (contrat inchangé) ;
    // seul le repli dérivé est projeté (mêmes règles que `_displayText`).
    return <String>[
      for (final f in _itemFields)
        if (data[f.name] != null && _displayText(context, item, f.name).isNotEmpty)
          _displayText(context, item, f.name),
    ].join(' — ');
  }

  /// Titre du dialog d'édition : `itemTitleBuilder(data)` s'il est fourni
  /// et non vide, sinon le libellé du champ.
  String _dialogTitle(BuildContext context, Map<String, dynamic> data) {
    final builder = widget.itemTitleBuilder;
    if (builder != null) {
      final t = _safeTitle(builder, data);
      if (t != null && t.isNotEmpty) return t;
    }
    return label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
  }

  /// Contenu résumé d'une ligne (mode compact) : les `summaryFields` en lecture
  /// (défilement horizontal encapsulé) ou le titre dérivé.
  Widget _summaryCells(BuildContext context, _SubItem item) {
    final summaryFields = _summaryFields;
    if (summaryFields.isNotEmpty) {
      // Mode EN-TÊTES (opt-in) : colonnes de largeur égale, ellipse, aucun
      // défilement horizontal — sans quoi des cellules de largeur intrinsèque
      // défilant chacune pour son compte ne s'aligneraient jamais sous
      // l'en-tête. Le texte tronqué reste atteignable par consulter/modifier.
      if (_showSummaryHeaders) {
        return Row(
          children: <Widget>[
            for (final name in summaryFields)
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 16, 0),
                  child: Text(
                    _displayText(context, item, name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
          ],
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final name in summaryFields)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 16, 0),
                child: Text(
                  _displayText(context, item, name),
                  textAlign: TextAlign.start,
                ),
              ),
          ],
        ),
      );
    }
    return Text(
      _defaultTitle(context, item),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
    );
  }

  /// Ligne d'**en-têtes de colonnes** (opt-in). Reprend le
  /// `label` l10n de chaque `ZFieldSpec` de `summaryFields` (repli : le `name`)
  /// — aucun libellé codé en dur (invariant FR-26). Même géométrie de colonnes
  /// que les cellules (`Expanded` + même padding de fin) : l'alignement est réel.
  ///
  /// a11y (invariant AD-13) : `header: true` sur chaque cellule — l'en-tête
  /// est annoncé comme tel, et la distinction ne repose pas sur le seul
  /// style visuel.
  ///
  /// [actionCount] = nombre d'`IconButton` de fin de ligne (gated ACL) : la
  /// réserve de fin reproduit leur emprise pour que les colonnes tombent
  /// réellement en face. Une ligne **soft-deleted** n'expose qu'une action
  /// (restaurer) + un badge : ses colonnes sont donc décalées de la différence.
  Widget _summaryHeaderRow(BuildContext context, int actionCount) {
    final summaryFields = _summaryFields;
    return Padding(
      // Reproduit la géométrie de `_CompactRow` : marge externe 16, marge
      // interne de début 12, réserve de fin = actions + marge interne 4.
      padding: const EdgeInsetsDirectional.fromSTEB(28, 8, 16, 0),
      child: Row(
        children: <Widget>[
          for (final name in summaryFields)
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 16, 0),
                child: Semantics(
                  // `container: true` est NÉCESSAIRE, pas décoratif : le mode
                  // compact est enveloppé d'un `Semantics(container: true)` qui
                  // FUSIONNE ses descendants — sans nœud propre, le drapeau
                  // `header` remonterait sur le bloc entier, qui serait alors
                  // annoncé comme un titre (mesuré).
                  container: true,
                  header: true,
                  child: Text(
                    label(
                      context,
                      _specOf(name)?.label ?? name,
                      fallback: _specOf(name)?.label ?? name,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ),
          SizedBox(width: actionCount * _actionExtent + 4),
        ],
      ),
    );
  }

  /// Emprise horizontale d'une action de fin de ligne (`IconButton` Material,
  /// cible tactile ≥ 48 dp — invariant AD-13). Sert à réserver, sous
  /// l'en-tête, la même largeur que la zone d'actions.
  static const double _actionExtent = 48;

  /// Ouvre le dialog d'édition d'un item. `initial` amorce le `ZFormController`
  /// propre du dialog ; retourne le `Map` agrégé à la validation, `null` à
  /// l'annulation/consultation.
  Future<Map<String, dynamic>?> _showItemDialog(
    Map<String, dynamic> initial, {
    required bool readOnly,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _ZSubItemEditDialog(
        title: _dialogTitle(dialogContext, initial),
        itemFields: _itemFields,
        initial: initial,
        readOnly: readOnly,
        itemFieldBuilder: widget.itemFieldBuilder,
      ),
    );
  }

  /// Ajout via dialog. L'item est amorcé de `defaultNewItem`
  /// **fusionné** avec les [templateDefaults] d'un gabarit de création —
  /// les valeurs du gabarit priment. Item vide par défaut.
  Future<void> _openAddDialog({
    Map<String, Object?> templateDefaults = const <String, Object?>{},
  }) async {
    final seed = <String, dynamic>{
      ..._defaultNewItem,
      ...templateDefaults,
    };
    final result = await _showItemDialog(seed, readOnly: false);
    if (!mounted || result == null) return;
    setState(() => _items.add(_makeItem(result)));
    _syncToParent();
  }

  /// Édition via dialog (remplace **à sa place** — identité stable
  /// conservée en réécrivant les tranches du contrôleur de l'item).
  Future<void> _openEditDialog(_SubItem item) async {
    final result = await _showItemDialog(_itemData(item), readOnly: false);
    if (!mounted || result == null) return;
    for (final f in _itemFields) {
      item.controller.setValue(f.name, result[f.name]);
    }
    setState(() {});
    _syncToParent();
  }

  /// Consultation (dialog `readOnly`, sans Enregistrer).
  Future<void> _openViewDialog(_SubItem item) async {
    await _showItemDialog(_itemData(item), readOnly: true);
  }

  /// Suppression avec **dialog de confirmation** puis retrait. En mode
  /// `softDelete`, l'item est **marqué supprimé** (restaurable) au lieu
  /// d'être retiré définitivement.
  Future<void> _confirmDelete(_SubItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(label(dialogContext, 'confirmDeleteItem')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(label(dialogContext, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(label(dialogContext, 'delete')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (_softDelete) {
      setState(() => item.deleted = true);
      _syncToParent();
      return;
    }
    final index = _items.indexOf(item);
    if (index >= 0) _removeAt(index);
  }

  /// Restaure un item soft-deleted (réintègre l'agrégation parent).
  void _restore(_SubItem item) {
    setState(() => item.deleted = false);
    _syncToParent();
  }

  /// Contrôle d'ajout — **menu** de gabarits de création si
  /// `creationTemplates` non vide, sinon simple bouton `+`. Chaque gabarit
  /// pré-remplit le dialog.
  Widget _buildAddControl(BuildContext context) {
    final templates = _creationTemplates;
    if (templates.isEmpty) {
      return IconButton(
        icon: const Icon(Icons.add),
        tooltip: _addLabel(context),
        onPressed: () => _openAddDialog(),
      );
    }
    // Résolution par IDENTITÉ, JAMAIS par position : la valeur portée est le
    // GABARIT lui-même, jamais son index. Avec `value: i` + `templates[i]`,
    // un rebuild survenu entre l'ouverture du menu et la sélection (la
    // sous-liste rebâtit à chaque `setState` d'item) et qui RÉORDONNE les
    // gabarits ouvrirait un dialog pré-rempli avec les valeurs d'un AUTRE
    // gabarit ; un rebuild qui les RACCOURCIT lèverait un `RangeError` dans
    // un gestionnaire de tap. Même sémantique que `ZDefaultMenuRenderer`
    // (`zcrud_menu`) — non importable ici (invariant AD-1, out-degree zcrud
    // de 0).
    return PopupMenuButton<ZSubListItemTemplate>(
      icon: const Icon(Icons.add),
      tooltip: _addLabel(context),
      onSelected: (template) =>
          _openAddDialog(templateDefaults: template.defaults),
      itemBuilder: (context) => <PopupMenuEntry<ZSubListItemTemplate>>[
        for (final template in templates)
          PopupMenuItem<ZSubListItemTemplate>(
            value: template,
            child: Text(label(context, template.labelKey,
                fallback: template.labelKey)),
          ),
      ],
    );
  }

  /// Rendu **compact** : en-tête + liste résumé keyée + actions gated ACL.
  Widget _buildCompact(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final readOnly = widget.field.readOnly;
    final cid = widget.collectionId;
    // Priorité : paramètre du champ > ACL du scope ambiant > refus.
    final ZAcl acl = widget.acl ??
        ZcrudScope.maybeOf(context)?.acl ??
        const ZDenyAllAcl();
    final canCreate =
        !readOnly && acl.can(ZCrudAction.create, collectionId: cid);
    final canView = acl.can(ZCrudAction.view, collectionId: cid);
    final canUpdate =
        !readOnly && acl.can(ZCrudAction.update, collectionId: cid);
    final canDelete =
        !readOnly && acl.can(ZCrudAction.delete, collectionId: cid);

    // a11y : pas de `label:` sur le conteneur — le `Text` visible
    // (en-tête) porte déjà le nom de section ; un `label:` doublerait l'annonce.
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    resolvedLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.start,
                  ),
                ),
                if (canCreate) _buildAddControl(context),
              ],
            ),
          ),
          // En-têtes de colonnes, **opt-in** et rendus seulement s'il y a
          // des colonnes ET des lignes à coiffer.
          if (_showSummaryHeaders &&
              _summaryFields.isNotEmpty &&
              _items.isNotEmpty)
            _summaryHeaderRow(
              context,
              (canView ? 1 : 0) + (canUpdate ? 1 : 0) + (canDelete ? 1 : 0),
            ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
              child: Text(
                label(context, 'noItems'),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.start,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                return KeyedSubtree(
                  key: ValueKey<String>(item.id),
                  child: _CompactRow(
                    borderColor: theme.fieldBorderColor,
                    radius: theme.radiusM,
                    summary: _summaryCells(context, item),
                    deleted: item.deleted,
                    canView: canView,
                    canUpdate: canUpdate,
                    canDelete: canDelete,
                    viewLabel: label(context, 'viewItem'),
                    editLabel: label(context, 'editItem'),
                    deleteLabel: label(context, 'deleteItem'),
                    restoreLabel: label(context, 'restoreItem'),
                    deletedBadge: label(context, 'deletedItemBadge'),
                    onView: () => _openViewDialog(item),
                    onEdit: () => _openEditDialog(item),
                    onDelete: () => _confirmDelete(item),
                    onRestore: () => _restore(item),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Mode tags (rangée de puces `InputChip`, minimal) ────────────────────────

  /// Rendu **tags** : rendu natif **MINIMAL** zéro-dépendance — une
  /// rangée `Wrap` de `InputChip` présentant le **résumé** de chaque item
  /// (`summaryFields`/repli titre), plus un bouton d'ajout (≥ 48 dp) réutilisant
  /// la machinerie de dialog existante (`_buildAddControl` → `_openAddDialog`).
  /// Tapoter une puce ouvre le dialog d'édition (consultation si `readOnly`) ;
  /// la puce est supprimable (`onDeleted` → `_confirmDelete`, gère softDelete).
  /// Directionnel (`Wrap` suit `Directionality`, `EdgeInsetsDirectional`),
  /// `Semantics` explicites, aucune couleur codée en dur (thème hérité,
  /// invariant FR-26). Les tags **riches** (toggle/icône par tag,
  /// réordonnancement drag) relèvent d'un rendu séparé, hors de ce mode
  /// minimal.
  Widget _buildTags(BuildContext context) {
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final readOnly = widget.field.readOnly;
    final removeLabel = label(context, 'removeItem');
    // Items visibles : les items soft-deleted sont EXCLUS (cohérent avec
    // l'agrégation parent) ; le rendu minimal ne porte pas la restauration
    // (offerte par le mode compact / un rendu tags riche futur).
    final visible = <_SubItem>[
      for (final item in _items)
        if (!item.deleted) item,
    ];

    // a11y : pas de `label:` sur le conteneur — le `Text` visible
    // (en-tête) porte déjà le nom de section ; un `label:` doublerait l'annonce.
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    resolvedLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.start,
                  ),
                ),
                if (!readOnly) _buildAddControl(context),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final item in visible)
                  InputChip(
                    key: ValueKey<String>('tag_${item.id}'),
                    label: Text(_chipLabel(item)),
                    // Invariant AD-13 : épingle la cible tactile à `padded`
                    // (≥ 48 dp) INDÉPENDAMMENT du thème ambiant — sinon un thème
                    // `materialTapTargetSize: shrinkWrap` ferait tomber la puce
                    // (et son `onDeleted`) sous 48 dp.
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onPressed: readOnly
                        ? () => _openViewDialog(item)
                        : () => _openEditDialog(item),
                    onDeleted: readOnly ? null : () => _confirmDelete(item),
                    deleteButtonTooltipMessage: readOnly ? null : removeLabel,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Libellé lisible d'une puce : résumé dérivé (`summaryFields`/titre)
  /// ou, à défaut, le libellé du champ (jamais une puce vide/illisible).
  String _chipLabel(_SubItem item) {
    final summaryFields = _summaryFields;
    if (summaryFields.isNotEmpty) {
      final parts = <String>[
        for (final name in summaryFields)
          if (_displayText(context, item, name).isNotEmpty)
            _displayText(context, item, name),
      ];
      if (parts.isNotEmpty) return parts.join(' — ');
    }
    final title = _defaultTitle(context, item);
    if (title.isNotEmpty) return title;
    return label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
  }
}

/// Ligne résumé d'un item en mode **compact** : résumé + actions de fin
/// de ligne accessibles (`IconButton` ≥ 48 dp, tooltips l10n), gated ACL en
/// amont (rendues conditionnellement). Bordure dérivée du thème (invariant
/// FR-26).
class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.borderColor,
    required this.radius,
    required this.summary,
    required this.deleted,
    required this.canView,
    required this.canUpdate,
    required this.canDelete,
    required this.viewLabel,
    required this.editLabel,
    required this.deleteLabel,
    required this.restoreLabel,
    required this.deletedBadge,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final Color? borderColor;
  final Radius radius;
  final Widget summary;

  /// Item soft-deleted → résumé barré + badge + action restaurer.
  final bool deleted;
  final bool canView;
  final bool canUpdate;
  final bool canDelete;
  final String viewLabel;
  final String editLabel;
  final String deleteLabel;
  final String restoreLabel;
  final String deletedBadge;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    // Résumé barré en état soft-deleted (a11y : badge textuel explicite).
    final summaryContent = deleted
        ? Row(
            children: <Widget>[
              Flexible(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                      decoration: TextDecoration.lineThrough),
                  child: summary,
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                child: Text(deletedBadge,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.start),
              ),
            ],
          )
        : summary;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: borderColor == null ? null : Border.all(color: borderColor!),
          borderRadius: BorderRadius.all(radius),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 0),
          child: Row(
            children: <Widget>[
              Expanded(child: summaryContent),
              // Item soft-deleted : seule l'action **restaurer** est offerte.
              if (deleted)
                IconButton(
                  icon: const Icon(Icons.restore_from_trash),
                  tooltip: restoreLabel,
                  onPressed: onRestore,
                )
              else ...<Widget>[
                if (canView)
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    tooltip: viewLabel,
                    onPressed: onView,
                  ),
                if (canUpdate)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: editLabel,
                    onPressed: onEdit,
                  ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: deleteLabel,
                    onPressed: onDelete,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog d'édition PAR ITEM — héberge un `ZFormController`
/// **PROPRE** amorcé du `Map` de l'item et rend les sous-champs via le
/// dispatcher `ZFieldWidget` (réutilisation intégrale de la machinerie
/// d'édition). **Aucun `Form` global** (invariant AD-2). Le contrôleur est
/// `dispose` à la fermeture (aucune fuite). Invariant AD-2 : taper dans un
/// sous-champ ne reconstruit QUE ce champ (`ZFieldWidget`/
/// `ZFieldListenableBuilder`), jamais le dialog ni la liste résumé. En lecture
/// (`readOnly`) : chaque spec `copyWith(readOnly: true)`, pas de bouton
/// Enregistrer (seul **Fermer**).
class _ZSubItemEditDialog extends StatefulWidget {
  const _ZSubItemEditDialog({
    required this.title,
    required this.itemFields,
    required this.initial,
    required this.readOnly,
    this.itemFieldBuilder,
  });

  final String title;
  final List<ZFieldSpec> itemFields;
  final Map<String, dynamic> initial;
  final bool readOnly;
  final ZSubItemFieldBuilder? itemFieldBuilder;

  @override
  State<_ZSubItemEditDialog> createState() => _ZSubItemEditDialogState();
}

class _ZSubItemEditDialogState extends State<_ZSubItemEditDialog> {
  /// Contrôleur PROPRE au dialog (create/dispose) — jamais partagé avec le
  /// conteneur : taper ici n'affecte le parent qu'à **Enregistrer**.
  late final ZFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ZFormController(
      initialValues: <String, Object?>{
        for (final f in widget.itemFields) f.name: widget.initial[f.name],
      },
      visibleFields: <String>[for (final f in widget.itemFields) f.name],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildField(ZFieldSpec field) {
    final spec = widget.readOnly ? field.copyWith(readOnly: true) : field;
    final custom = widget.itemFieldBuilder;
    if (custom != null) {
      return custom(context, _controller, spec, 'dialog');
    }
    return ZFieldWidget(controller: _controller, field: spec);
  }

  void _save() {
    Navigator.of(context).pop(<String, dynamic>{
      for (final f in widget.itemFields) f.name: _controller.valueOf(f.name),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final f in widget.itemFields)
              KeyedSubtree(
                key: ValueKey<String>('dialog/${f.name}'),
                child: _buildField(f),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(label(context, widget.readOnly ? 'close' : 'cancel')),
        ),
        if (!widget.readOnly)
          TextButton(
            onPressed: _save,
            child: Text(label(context, 'save')),
          ),
      ],
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
