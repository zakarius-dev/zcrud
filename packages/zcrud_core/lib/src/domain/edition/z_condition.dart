/// Condition de visibilité **déclarative** (`displayCondition`) d'un champ,
/// portée par `@ZcrudField.condition` (authoring) et projetée dans
/// `ZFieldSpec.condition` (runtime, E2-5).
///
/// origine: `displayCondition` DODLP/IFFD — mais **jamais une closure**. Une
/// closure `(item, state, crud) → bool` (patron lex/DODLP, cause historique du
/// focus perdu, inventaire §4.1(a)) **ne peut ni être `const` ni être lue par
/// `ConstantReader`** → proscrite dans l'annotation. Exprimée ici **en données**.
///
/// **Frontière statique/runtime (AD-2)** : E2-4 livre la **structure** ;
/// l'**évaluation** contre l'état de formulaire est **E3** (sélecteur de
/// visibilité dédié — « seul un changement de visibilité reconstruit la LISTE,
/// place stable pour les champs conditionnels »). Les cas irréductiblement
/// dynamiques passent par une surcouche runtime (E3), jamais par l'annotation.
library;

/// **Source de valeur** d'une feuille de [ZCondition] (parité DODLP — DP-2, B3).
///
/// Sépare, en **données** (jamais une closure — AD-2/AD-3), les trois origines
/// de valeur qu'un `displayCondition` DODLP lit à l'exécution :
///
/// - [state] — valeur **courante** du champ dans le formulaire (défaut,
///   comportement historique) ; miroir de `editionState[...]` DODLP. Seules ces
///   feuilles alimentent la souscription ciblée par frappe (`zGuardFieldsOf`,
///   SM-1).
/// - [persisted] — valeur de l'**item d'origine** (baseline immuable capturée à
///   la construction du contrôleur) ; miroir de `item[...]` DODLP, distinct de
///   l'état mutable. Lue via l'accesseur `persistedValueOf` injecté. **Immuable**
///   dans une session ⇒ ne contribue PAS à la garde par frappe.
/// - [context] — valeur d'une **clé de contexte d'édition** (hors formulaire) :
///   `crud`/`mode`/drapeaux applicatifs. Lue via l'accesseur `contextValueOf`
///   injecté. Convention de sérialisation : `crud` en `String` camelCase miroir
///   de l'enum `Crud` DODLP (`'read'`/`'create'`/`'update'`/`'delete'`), `mode`
///   en `String`, drapeaux en `bool`. Les drapeaux/services **capturés** DODLP
///   (`includeGender`, `userPermissions.can<AppelConvocation>(crud)`) sont
///   **pré-calculés par l'app** et injectés comme pseudo-champs de contexte
///   (`ZCondition.truthy('includeGender', source: ZValueSource.context)`) —
///   workaround propre « donnée, pas closure ». Recalcul sur bascule de contexte
///   via `zContextGuardKeysOf` (jamais par frappe).
enum ZValueSource {
  /// Valeur **courante** du champ (défaut ; `editionState[...]` DODLP).
  state,

  /// Valeur de l'**item persisté** d'origine (baseline ; `item[...]` DODLP).
  persisted,

  /// Valeur d'une **clé de contexte** d'édition (`crud`/`mode`/drapeaux).
  context,
}

/// Opérateur d'une [ZCondition] déclarative.
enum ZConditionOp {
  /// `field == value`.
  equals,

  /// `field != value`.
  notEquals,

  /// `field == null`.
  isNull,

  /// `field != null`.
  notNull,

  /// `field` est « vrai » (non nul, non vide, non `false`, non `0`).
  truthy,

  /// Conjonction de tous les [ZCondition.operands].
  and,

  /// Disjonction d'au moins un des [ZCondition.operands].
  or,

  /// Négation de l'unique opérande.
  not,

  /// La valeur est **vide** (`zLengthOf(v) == 0` : `null`/`''`/`[]`/`{}`).
  isEmpty,

  /// La valeur est **non vide** (`zLengthOf(v) > 0`). Reproduit
  /// `(entries as List).isNotEmpty` / `(str ?? '').isNotEmpty` (DODLP, Forme B).
  isNotEmpty,

  /// La **longueur** de la valeur égale [ZCondition.length] (`zLengthOf(v) == n`).
  lengthEquals,

  /// La longueur de la valeur est **strictement supérieure** à [ZCondition.length].
  lengthGt,

  /// La longueur de la valeur est **supérieure ou égale** à [ZCondition.length].
  lengthGte,

  /// La longueur de la valeur est **strictement inférieure** à [ZCondition.length].
  lengthLt,

  /// La longueur de la valeur est **inférieure ou égale** à [ZCondition.length].
  lengthLte,
}

/// Expression `const` de visibilité conditionnelle (pur-données).
///
/// Feuilles (dépendent d'un champ) : [ZCondition.equals], [ZCondition.notEquals],
/// [ZCondition.isNull], [ZCondition.notNull], [ZCondition.truthy].
/// Combinateurs : [ZCondition.and], [ZCondition.or], [ZCondition.not].
class ZCondition {
  const ZCondition._(
    this.op, {
    this.field,
    this.value,
    this.operands,
    this.operand,
    this.source = ZValueSource.state,
    this.length,
  });

  /// Vrai si le champ [field] (lu sur [source]) égale [value].
  const ZCondition.equals(String field, Object? value,
      {ZValueSource source = ZValueSource.state})
      : this._(ZConditionOp.equals, field: field, value: value, source: source);

  /// Vrai si le champ [field] (lu sur [source]) diffère de [value].
  const ZCondition.notEquals(String field, Object? value,
      {ZValueSource source = ZValueSource.state})
      : this._(ZConditionOp.notEquals,
            field: field, value: value, source: source);

  /// Vrai si le champ [field] (lu sur [source]) est `null`.
  const ZCondition.isNull(String field,
      {ZValueSource source = ZValueSource.state})
      : this._(ZConditionOp.isNull, field: field, source: source);

  /// Vrai si le champ [field] (lu sur [source]) n'est pas `null`.
  const ZCondition.notNull(String field,
      {ZValueSource source = ZValueSource.state})
      : this._(ZConditionOp.notNull, field: field, source: source);

  /// Vrai si le champ [field] (lu sur [source]) est « vrai » (non nul/vide/`false`/`0`).
  const ZCondition.truthy(String field,
      {ZValueSource source = ZValueSource.state})
      : this._(ZConditionOp.truthy, field: field, source: source);

  /// Vrai si le champ [field] (lu sur [source]) est **vide** (`null`/`''`/`[]`/`{}`).
  const ZCondition.isEmpty(String field,
      {ZValueSource source = ZValueSource.state})
      : this._(ZConditionOp.isEmpty, field: field, source: source);

  /// Vrai si le champ [field] (lu sur [source]) est **non vide**.
  /// Reproduit `(entries as List).isNotEmpty` DODLP (Forme B).
  const ZCondition.isNotEmpty(String field,
      {ZValueSource source = ZValueSource.state})
      : this._(ZConditionOp.isNotEmpty, field: field, source: source);

  /// Vrai si la **longueur** de [field] (lu sur [source]) égale [length].
  const ZCondition.lengthEquals(String field, int length,
      {ZValueSource source = ZValueSource.state})
      : this._(ZConditionOp.lengthEquals,
            field: field, length: length, source: source);

  /// Vrai si la longueur de [field] (lu sur [source]) est `> [length]`.
  const ZCondition.lengthGt(String field, int length,
      {ZValueSource source = ZValueSource.state})
      : this._(ZConditionOp.lengthGt,
            field: field, length: length, source: source);

  /// Vrai si la longueur de [field] (lu sur [source]) est `>= [length]`.
  const ZCondition.lengthGte(String field, int length,
      {ZValueSource source = ZValueSource.state})
      : this._(ZConditionOp.lengthGte,
            field: field, length: length, source: source);

  /// Vrai si la longueur de [field] (lu sur [source]) est `< [length]`.
  const ZCondition.lengthLt(String field, int length,
      {ZValueSource source = ZValueSource.state})
      : this._(ZConditionOp.lengthLt,
            field: field, length: length, source: source);

  /// Vrai si la longueur de [field] (lu sur [source]) est `<= [length]`.
  const ZCondition.lengthLte(String field, int length,
      {ZValueSource source = ZValueSource.state})
      : this._(ZConditionOp.lengthLte,
            field: field, length: length, source: source);

  /// Conjonction (`ET`) de [operands].
  const ZCondition.and(List<ZCondition> operands)
      : this._(ZConditionOp.and, operands: operands);

  /// Disjonction (`OU`) de [operands].
  const ZCondition.or(List<ZCondition> operands)
      : this._(ZConditionOp.or, operands: operands);

  /// Négation de [operand].
  const ZCondition.not(ZCondition operand)
      : this._(ZConditionOp.not, operand: operand);

  /// Opérateur de la condition.
  final ZConditionOp op;

  /// Champ observé (feuilles) ; `null` pour les combinateurs.
  final String? field;

  /// Valeur de comparaison ([ZConditionOp.equals]/[ZConditionOp.notEquals]).
  final Object? value;

  /// **Source** de lecture de la feuille (défaut [ZValueSource.state] —
  /// rétro-compatible). Ignorée par les combinateurs (`and`/`or`/`not`).
  final ZValueSource source;

  /// **Seuil de longueur** des opérateurs de forme
  /// ([ZConditionOp.lengthEquals]/`lengthGt`/`lengthGte`/`lengthLt`/`lengthLte`) ;
  /// `null` pour les autres opérateurs.
  final int? length;

  /// Sous-conditions des combinateurs `and`/`or` ; `null` sinon.
  final List<ZCondition>? operands;

  /// Sous-condition unique du combinateur `not` ; `null` sinon.
  final ZCondition? operand;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZCondition &&
          runtimeType == other.runtimeType &&
          op == other.op &&
          field == other.field &&
          value == other.value &&
          source == other.source &&
          length == other.length &&
          operand == other.operand &&
          _listEquals(operands, other.operands);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        op,
        field,
        value,
        source,
        length,
        operand,
        operands == null ? null : Object.hashAll(operands!),
      );

  @override
  String toString() =>
      'ZCondition(${op.name}, field: $field, source: ${source.name})';
}

/// Égalité **profonde** de deux listes de conditions (pur-Dart, évite
/// `package:collection` — AD-1, out-degree 0).
bool _listEquals(List<ZCondition>? a, List<ZCondition>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
