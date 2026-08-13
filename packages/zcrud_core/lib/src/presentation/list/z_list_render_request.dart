/// Modèles de **requête de rendu de liste** neutres du cœur `zcrud_core`.
///
/// Ces value objects sont **Material-free**, purs-données-présentation : ils ne
/// portent AUCUN widget, AUCUNE dépendance lourde, AUCUN `package:syncfusion`.
/// Ils constituent le **contrat neutre** que le port [ZListRenderer] consomme,
/// de sorte qu'un backend `SfDataGrid` (dans `zcrud_list`) ou un backend
/// Material `DataTable` s'implémente sur le MÊME contrat sans que Syncfusion ne
/// contamine le cœur.
///
/// **Frontière** : le contrat porte des `ZListColumn` **dérivées**
/// (`deriveColumns`, visibilité/formatage/largeur/ordre) via la fabrique
/// [ZListRenderRequest.fromSchema] — le backend consomme le format neutre partagé
/// sans re-dériver. Les **états UI**
/// (`loading`/`empty`/`noResults`/`error`) NE sont PAS portés ici : ils vivent
/// dans le wrapper `DynamicList` (`ZListViewState`). Vues alternatives, recherche/
/// tri/pagination et actions/`ZAcl` restent hors de ce contrat.
///
/// Égalité de **valeur profonde** (`==`/`hashCode`), cohérente avec
/// `ZFieldSpec`/`ZDataRequest` (helpers pur-Dart, aucun `package:collection` —
/// AD-1 out-degree 0).
library;

import '../../domain/contracts/z_entity.dart';
import '../../domain/edition/z_field_spec.dart';
import 'z_list_column.dart';

/// Ligne neutre d'une liste : une **identité opaque** + un sac de cellules.
///
/// [cells] mappe `field.name → valeur brute` (`Object?`, **opaque** : aucune
/// contrainte de type, aucun formatage). La projection `T → ZListRow` (via
/// `toMap`/`ZFieldSpec`) est l'affaire de l'appelant ;
/// le port n'impose AUCUNE générécité `T`.
class ZListRow {
  /// Construit une ligne. [id] est l'identité opaque (clé stable) ; [cells]
  /// porte les valeurs brutes indexées par `field.name`.
  const ZListRow({required this.id, required this.cells});

  /// Construit la ligne d'une **entité**, en lui attribuant la clé standard
  /// [keyOf] : l'`id` réel, ou une clé éphémère stable si l'entité n'est pas
  /// encore persistée.
  ///
  /// C'est la fabrique à utiliser dans un projecteur `T → ZListRow` : elle
  /// évite de redéclarer la convention de clé au moment où l'on construit
  /// aussi l'index qui servira à `DynamicList.entityFor`.
  ///
  /// ```dart
  /// ZListRow rowOf(Consignee c) {
  ///   index[ZListRow.keyOf(c)] = c;          // index ← même clé
  ///   return ZListRow.ofEntity(c, cellsOf(c));
  /// }
  /// ```
  ZListRow.ofEntity(ZEntity entity, Map<String, Object?> cells)
      : this(id: keyOf(entity), cells: cells);

  /// Identité opaque de la ligne (clé stable, non affichée par défaut).
  ///
  /// Volontairement **non nullable**, alors que `ZEntity.id` est nullable :
  /// une ligne de liste a besoin d'une clé stable (sélection, actions,
  /// virtualisation), là où une entité **éphémère** (`ZEntity.id == null`,
  /// pas encore persistée) n'a pas de clé naturelle. Dans ce cas, c'est au
  /// projecteur `T → ZListRow` de **fabriquer** une clé stable — utiliser la
  /// fabrique standard [ZListRow.ephemeralKey] (clé positionnelle préfixée,
  /// dérivée de l'index d'insertion) ou une identité locale générée à la
  /// création de l'objet — et de la conserver jusqu'à ce que la persistance
  /// attribue l'identité réelle.
  final String id;

  /// Préfixe réservé des clés éphémères fabriquées par [ephemeralKey].
  static const String _ephemeralKeyPrefix = '__ephemeral_';

  /// Fabrique la **clé standard** d'une ligne dont l'entité est **éphémère**
  /// (`ZEntity.id == null`, pas encore persistée) : une clé positionnelle
  /// stable dérivée de l'[index] d'insertion — `'__ephemeral_<index>'`.
  ///
  /// **Déterministe** : même [index] → même clé (la sélection et les actions,
  /// keyées par `id`, survivent aux rebuilds tant que la position ne change
  /// pas). À n'utiliser que le temps de la persistance : dès que l'entité
  /// reçoit son identité réelle, c'est elle qui devient la clé.
  ///
  /// La graine [index] est libre : index d'insertion, ou identité mémoire de
  /// l'instance (`identityHashCode`) — c'est le choix de [keyOf].
  ///
  /// Centralisé ici pour que chaque projecteur `T → ZListRow` n'invente pas
  /// son propre format ; [isEphemeralKey] reconnaît les clés ainsi fabriquées
  /// (par exemple pour désactiver la corbeille sur une ligne non persistée).
  static String ephemeralKey(int index) => '$_ephemeralKeyPrefix$index';

  /// Clé de ligne **standard** d'une [entity] : son `id` s'il est attribué,
  /// sinon une clé éphémère dérivée de l'identité mémoire de l'instance.
  ///
  /// C'est la convention **publique** de tout l'assemblage zcrud
  /// (`ZCrudScreen` la suit) : un hôte qui doit reconstruire l'index
  /// `ZListRow.id → entité` consommé par `DynamicList.entityFor` appelle cette
  /// fonction au lieu de deviner la formule. La clé d'une entité éphémère est
  /// stable **tant que l'instance vit** (mêmes lignes sélectionnées d'un
  /// rebuild à l'autre) ; dès que la persistance attribue un `id`, c'est lui
  /// qui devient la clé.
  static String keyOf(ZEntity entity) =>
      entity.id ?? ephemeralKey(identityHashCode(entity));

  /// `true` si [id] est une clé **éphémère** fabriquée par [ephemeralKey]
  /// (préfixe réservé `'__ephemeral_'`).
  static bool isEphemeralKey(String id) => id.startsWith(_ephemeralKeyPrefix);

  /// Valeurs brutes de la ligne indexées par `field.name` (opaques).
  final Map<String, Object?> cells;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListRow &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          _mapEquals(cells, other.cells);

  @override
  int get hashCode => Object.hash(runtimeType, id, _mapHash(cells));

  @override
  String toString() => 'ZListRow(id: $id, cells: $cells)';
}

/// Requête de rendu **neutre et immuable** consommée par [ZListRenderer].
///
/// Porte les [columns] **dérivées** (`ZListColumn` : en-tête non résolu,
/// largeur, format pur — cf. [ZListRenderRequest.fromSchema]) et les [rows]. Le
/// backend consomme le format neutre partagé (`col.format(row.cells[col.name])`)
/// sans re-dériver ni dupliquer de logique de format. Aucun état
/// `loading`/`empty`/`noResults`/`error` (dans `DynamicList`/`ZListViewState`),
/// aucun tri/filtre.
///
/// Immuable (`const` + champs `final`) ; égalité de **valeur profonde** (listes
/// et cellules comparées élément par élément).
class ZListRenderRequest {
  /// Construit une requête de rendu à partir des [columns] **dérivées** et
  /// [rows]. Pour dériver les colonnes depuis un `ZFieldSpec[]`, préférer la
  /// fabrique [ZListRenderRequest.fromSchema].
  const ZListRenderRequest({
    required this.columns,
    required this.rows,
    this.ordinal = const ZListOrdinal(),
  });

  /// Fabrique dérivant les [columns] d'un `ZFieldSpec[]` via `deriveColumns`
  /// (visibilité/format/ordre/largeur), en appliquant la [policy] optionnelle.
  ///
  /// Centralise la dérivation dans le cœur (format neutre partagé) : le backend
  /// n'a plus qu'à rendre les `ZListColumn` produites.
  /// [formatting] porte les **seams d'affichage capturés** (libellé d'orphelin
  /// localisé, port de dates, locale) — cf. `ZListFormat`. Omis ⇒ rendu
  /// locale-neutre d'origine (appel headless : `zcrud_export`).
  ZListRenderRequest.fromSchema(
    List<ZFieldSpec> fields,
    this.rows, {
    ZColumnPolicy? policy,
    ZListFormat formatting = const ZListFormat(),
  })  : columns = deriveColumns(fields, policy: policy, formatting: formatting),
        ordinal = policy?.ordinal ?? const ZListOrdinal();

  /// Colonnes **dérivées** du schéma (`ZListColumn` : en-tête non résolu, clé de
  /// mapping `name`, largeur indicative, format pur par type).
  final List<ZListColumn> columns;

  /// Lignes à afficher (identité opaque + cellules brutes).
  final List<ZListRow> rows;

  /// Déclaration de la colonne de **numéro d'ordre** (cf. [ZListOrdinal]).
  ///
  /// Désactivée par défaut. Le numéro n'est volontairement PAS rangé dans
  /// `ZListRow.cells` : il se dérive de la position d'affichage
  /// ([ZListOrdinal.textAt]) au moment du rendu, de sorte qu'un tri renumérote
  /// l'écran au lieu de promener d'anciens numéros.
  final ZListOrdinal ordinal;

  /// Numéro affiché pour la ligne rendue en position [displayIndex]
  /// (**0-based**, après tri et filtrage), ou `null` si la colonne d'ordre
  /// n'est pas demandée.
  ///
  /// Raccourci vers [ZListOrdinal.textAt] : c'est ce que le backend appelle au
  /// moment de peindre la ligne, pour ne pas réinventer sa propre
  /// numérotation.
  String? ordinalTextAt(int displayIndex) =>
      ordinal.enabled ? ordinal.textAt(displayIndex) : null;

  /// Numéros des lignes **telles qu'elles sont affichées**, dans cet ordre.
  ///
  /// [displayedRows] est la séquence effectivement peinte — après tri,
  /// filtrage et pagination. Le résultat est toujours `['1', '2', '3', …]` :
  /// la numérotation décrit l'écran, elle ne suit **pas** l'ordre d'origine des
  /// lignes. Un backend qui trie n'a donc rien à recalculer ni à invalider.
  ///
  /// Liste vide si la colonne d'ordre n'est pas demandée.
  List<String> ordinalTextsForDisplay(List<ZListRow> displayedRows) =>
      ordinal.enabled
          ? ordinal.textsFor(displayedRows.length)
          : const <String>[];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListRenderRequest &&
          runtimeType == other.runtimeType &&
          _listEquals(columns, other.columns) &&
          _listEquals(rows, other.rows) &&
          ordinal == other.ordinal;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        Object.hashAll(columns),
        Object.hashAll(rows),
        ordinal,
      );

  @override
  String toString() => 'ZListRenderRequest(columns: ${columns.length}, '
      'rows: ${rows.length}, ordinal: $ordinal)';
}

/// Égalité **profonde** de deux listes (élément par élément), pur-Dart
/// (évite `package:collection` — AD-1 out-degree 0).
bool _listEquals(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Égalité **profonde** de deux maps (clé + valeur), pur-Dart.
bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Hash **indépendant de l'ordre** d'insertion, cohérent avec [_mapEquals].
int _mapHash(Map<String, Object?> map) {
  var hash = 0;
  for (final entry in map.entries) {
    // XOR : commutatif → l'ordre des clés n'altère pas le hash.
    hash ^= Object.hash(entry.key, entry.value);
  }
  return hash;
}
