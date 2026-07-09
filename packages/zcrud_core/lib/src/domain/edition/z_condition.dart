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
}

/// Expression `const` de visibilité conditionnelle (pur-données).
///
/// Feuilles (dépendent d'un champ) : [ZCondition.equals], [ZCondition.notEquals],
/// [ZCondition.isNull], [ZCondition.notNull], [ZCondition.truthy].
/// Combinateurs : [ZCondition.and], [ZCondition.or], [ZCondition.not].
class ZCondition {
  const ZCondition._(this.op, {this.field, this.value, this.operands, this.operand});

  /// Vrai si le champ [field] égale [value].
  const ZCondition.equals(String field, Object? value)
      : this._(ZConditionOp.equals, field: field, value: value);

  /// Vrai si le champ [field] diffère de [value].
  const ZCondition.notEquals(String field, Object? value)
      : this._(ZConditionOp.notEquals, field: field, value: value);

  /// Vrai si le champ [field] est `null`.
  const ZCondition.isNull(String field)
      : this._(ZConditionOp.isNull, field: field);

  /// Vrai si le champ [field] n'est pas `null`.
  const ZCondition.notNull(String field)
      : this._(ZConditionOp.notNull, field: field);

  /// Vrai si le champ [field] est « vrai » (non nul/vide/`false`/`0`).
  const ZCondition.truthy(String field)
      : this._(ZConditionOp.truthy, field: field);

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
          operand == other.operand &&
          _listEquals(operands, other.operands);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        op,
        field,
        value,
        operand,
        operands == null ? null : Object.hashAll(operands!),
      );

  @override
  String toString() => 'ZCondition(${op.name}, field: $field)';
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
