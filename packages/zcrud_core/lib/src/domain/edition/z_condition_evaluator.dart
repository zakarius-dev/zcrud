/// Évaluateur **pur** d'une [ZCondition] déclarative contre l'état de formulaire
/// (E3-4, AD-2). C'est le pendant **runtime** de la structure `const` posée par
/// [ZCondition] (E2-4) : la donnée est évaluée ici, JAMAIS par une closure portée
/// par l'annotation (cause historique du focus perdu — cf. `z_condition.dart`).
///
/// **Pur-Dart** (couche `domain`, garde `domain_purity_test.dart`) : aucune
/// dépendance Flutter, aucun état. L'évaluation lit les valeurs de champ via une
/// fonction d'accès [ZValueOf] injectée (typiquement `ZFormController.valueOf`),
/// ce qui découple l'évaluateur du moteur réactif (AD-2 : la souscription CIBLÉE
/// aux champs de garde vit en présentation, pas ici).
///
/// **Frontière AD-2** : cet évaluateur est *sans effet* — il ne déclenche aucun
/// rebuild. Le sélecteur de visibilité (présentation) l'appelle pour recomposer
/// l'ensemble visible, puis pilote `setVisibleFields` (canal structurel unique).
library;

import 'z_condition.dart';

/// Accès pur à la valeur courante d'un champ par son `name` (`null` si absent).
///
/// Injecté par l'appelant ; typiquement `ZFormController.valueOf`. Garde
/// l'évaluateur **découplé** du moteur réactif (aucun import de présentation).
typedef ZValueOf = Object? Function(String field);

/// Évalue [condition] contre l'état lu via [valueOf] et retourne sa vérité.
///
/// Sémantique par [ZConditionOp] :
/// - [ZConditionOp.equals] / [ZConditionOp.notEquals] : comparaison `==` de la
///   valeur du champ à `condition.value` ;
/// - [ZConditionOp.isNull] / [ZConditionOp.notNull] : test de nullité ;
/// - [ZConditionOp.truthy] : « vrai » = non `null`, non `false`, non `0`/`0.0`,
///   et non **vide** (`String`/`Iterable`/`Map` vide ⇒ faux) — cf. [zIsTruthy] ;
/// - [ZConditionOp.and] : conjonction de TOUS les `operands` (vide ⇒ `true`) ;
/// - [ZConditionOp.or] : disjonction d'AU MOINS un `operand` (vide ⇒ `false`) ;
/// - [ZConditionOp.not] : négation de l'unique `operand`.
///
/// **Pur / total** : ne lève jamais ; un combinateur mal formé (opérande `null`)
/// est traité de façon défensive (`and`/`not` d'un `null` ⇒ neutre) — cohérent
/// avec la désérialisation défensive (AD-10). Une FEUILLE mal formée (`field`
/// `null`, non atteignable via les constructeurs publics) lit une valeur `null`
/// au lieu de lever (garde défensive — LOW-4). Récursif sur les combinateurs.
bool evaluateZCondition(ZCondition condition, ZValueOf valueOf) {
  // Lecture défensive de la valeur d'une feuille : `field` `null` ⇒ `null`
  // (jamais de déréférencement `!` qui lèverait sur une condition mal formée).
  Object? leafValue() {
    final field = condition.field;
    return field == null ? null : valueOf(field);
  }

  switch (condition.op) {
    case ZConditionOp.equals:
      return leafValue() == condition.value;
    case ZConditionOp.notEquals:
      return leafValue() != condition.value;
    case ZConditionOp.isNull:
      return leafValue() == null;
    case ZConditionOp.notNull:
      return leafValue() != null;
    case ZConditionOp.truthy:
      return zIsTruthy(leafValue());
    case ZConditionOp.and:
      final operands = condition.operands;
      if (operands == null || operands.isEmpty) return true;
      for (final o in operands) {
        if (!evaluateZCondition(o, valueOf)) return false;
      }
      return true;
    case ZConditionOp.or:
      final operands = condition.operands;
      if (operands == null || operands.isEmpty) return false;
      for (final o in operands) {
        if (evaluateZCondition(o, valueOf)) return true;
      }
      return false;
    case ZConditionOp.not:
      final operand = condition.operand;
      if (operand == null) return true;
      return !evaluateZCondition(operand, valueOf);
  }
}

/// Sémantique **partagée** de « valeur vraie » (utilisée par [ZConditionOp.truthy]
/// et par le filtre `showIfNull`/« champ vide » de la présentation E3-4).
///
/// `false` pour : `null`, le booléen `false`, `0`/`0.0` (numériques), et toute
/// collection/chaîne **vide** (`String`/`Iterable`/`Map`). `true` sinon — en
/// particulier une valeur non vide, un booléen `true`, un nombre non nul.
bool zIsTruthy(Object? value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  if (value is Map) return value.isNotEmpty;
  return true;
}

/// Extrait l'**ensemble des champs de garde** d'un ensemble de conditions :
/// l'union des `field` référencés (récursivement à travers `and`/`or`/`not`).
///
/// C'est le contrat qui permet au sélecteur de visibilité (présentation) de
/// s'abonner UNIQUEMENT à ces champs — une frappe sur un champ **hors** de cet
/// ensemble ne déclenche donc AUCUN recalcul de visibilité (SM-1, AD-2).
Set<String> zGuardFieldsOf(Iterable<ZCondition?> conditions) {
  final guards = <String>{};
  void walk(ZCondition? c) {
    if (c == null) return;
    final field = c.field;
    if (field != null) guards.add(field);
    final operands = c.operands;
    if (operands != null) {
      for (final o in operands) {
        walk(o);
      }
    }
    walk(c.operand);
  }

  for (final c in conditions) {
    walk(c);
  }
  return guards;
}
