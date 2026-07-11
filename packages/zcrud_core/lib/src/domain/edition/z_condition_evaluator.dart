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
/// **Accesseurs par source (DP-2, B3)** : chaque feuille désigne sa source de
/// valeur ([ZCondition.source]). L'accesseur est résolu AVANT la lecture :
/// - [ZValueSource.state] → [valueOf] (défaut ; comportement historique) ;
/// - [ZValueSource.persisted] → [persistedValueOf] (item d'origine / baseline) ;
/// - [ZValueSource.context] → [contextValueOf] (crud/mode/drapeaux).
///
/// Les paramètres [persistedValueOf]/[contextValueOf] sont **nommés optionnels** :
/// un appel historique à 2 arguments `evaluateZCondition(c, valueOf)` compile et
/// se comporte à l'identique. Un accesseur **absent** (non fourni) résout `null`
/// (défensif — AD-10), jamais une exception.
///
/// Sémantique par [ZConditionOp] :
/// - [ZConditionOp.equals] / [ZConditionOp.notEquals] : comparaison `==` de la
///   valeur du champ à `condition.value` ;
/// - [ZConditionOp.isNull] / [ZConditionOp.notNull] : test de nullité ;
/// - [ZConditionOp.truthy] : « vrai » = non `null`, non `false`, non `0`/`0.0`,
///   et non **vide** (`String`/`Iterable`/`Map` vide ⇒ faux) — cf. [zIsTruthy] ;
/// - [ZConditionOp.isEmpty] / [ZConditionOp.isNotEmpty] : test de **forme** via
///   [zLengthOf] (`== 0` / `> 0`) — reproduit `(list).isNotEmpty` /
///   `(str ?? '').isEmpty` DODLP (Forme B) ;
/// - [ZConditionOp.lengthEquals]/`lengthGt`/`lengthGte`/`lengthLt`/`lengthLte` :
///   comparaison de [zLengthOf] au seuil `condition.length` (`null` ⇒ `0`) ;
/// - [ZConditionOp.and] : conjonction de TOUS les `operands` (vide ⇒ `true`) ;
/// - [ZConditionOp.or] : disjonction d'AU MOINS un `operand` (vide ⇒ `false`) ;
/// - [ZConditionOp.not] : négation de l'unique `operand`.
///
/// **Pur / total** : ne lève jamais ; un combinateur mal formé (opérande `null`)
/// est traité de façon défensive (`and`/`not` d'un `null` ⇒ neutre) — cohérent
/// avec la désérialisation défensive (AD-10). Une FEUILLE mal formée (`field`
/// `null`, non atteignable via les constructeurs publics) lit une valeur `null`
/// au lieu de lever (garde défensive — LOW-4). Le `switch` est **total** sur
/// l'enum [ZConditionOp] ; toute donnée corrompue est neutralisée en amont par
/// la lecture défensive de feuille et par `unknownEnumValue` (AD-10). Récursif
/// sur les combinateurs (les accesseurs sont propagés inchangés).
bool evaluateZCondition(
  ZCondition condition,
  ZValueOf valueOf, {
  ZValueOf? persistedValueOf,
  ZValueOf? contextValueOf,
}) {
  // Lecture défensive de la valeur d'une feuille : `field` `null` ⇒ `null` ;
  // accesseur de source absent ⇒ `null` (jamais de `!`/throw — AD-10).
  Object? leafValue() {
    final field = condition.field;
    if (field == null) return null;
    switch (condition.source) {
      case ZValueSource.state:
        return valueOf(field);
      case ZValueSource.persisted:
        return persistedValueOf == null ? null : persistedValueOf(field);
      case ZValueSource.context:
        return contextValueOf == null ? null : contextValueOf(field);
    }
  }

  bool recurse(ZCondition c) => evaluateZCondition(
        c,
        valueOf,
        persistedValueOf: persistedValueOf,
        contextValueOf: contextValueOf,
      );

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
    case ZConditionOp.isEmpty:
      return zLengthOf(leafValue()) == 0;
    case ZConditionOp.isNotEmpty:
      return zLengthOf(leafValue()) > 0;
    case ZConditionOp.lengthEquals:
      return zLengthOf(leafValue()) == (condition.length ?? 0);
    case ZConditionOp.lengthGt:
      return zLengthOf(leafValue()) > (condition.length ?? 0);
    case ZConditionOp.lengthGte:
      return zLengthOf(leafValue()) >= (condition.length ?? 0);
    case ZConditionOp.lengthLt:
      return zLengthOf(leafValue()) < (condition.length ?? 0);
    case ZConditionOp.lengthLte:
      return zLengthOf(leafValue()) <= (condition.length ?? 0);
    case ZConditionOp.and:
      final operands = condition.operands;
      if (operands == null || operands.isEmpty) return true;
      for (final o in operands) {
        if (!recurse(o)) return false;
      }
      return true;
    case ZConditionOp.or:
      final operands = condition.operands;
      if (operands == null || operands.isEmpty) return false;
      for (final o in operands) {
        if (recurse(o)) return true;
      }
      return false;
    case ZConditionOp.not:
      final operand = condition.operand;
      if (operand == null) return true;
      return !recurse(operand);
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

/// **Longueur** pure et **totale** d'une valeur pour les opérateurs de forme
/// ([ZConditionOp.isEmpty]/`isNotEmpty`/`length*`), alignée sur [zIsTruthy] : une
/// collection/chaîne vide a une longueur `0` (donc « vide » et non-« non-vide »).
///
/// - `String`/`Iterable`/`Map` ⇒ `.length` ;
/// - `null` ⇒ `0` ;
/// - scalaire non-collection (`num`/`bool`/autre) ⇒ `0` (« pas de longueur »).
///
/// **Ne lève jamais** (AD-10). Reproduit `(entries as List).length`,
/// `(str ?? '').isEmpty` (via `== 0`) des `displayCondition` DODLP (Forme B).
int zLengthOf(Object? value) {
  if (value == null) return 0;
  if (value is String) return value.length;
  if (value is Iterable) return value.length;
  if (value is Map) return value.length;
  return 0;
}

/// Extrait l'**ensemble des champs de garde** d'un ensemble de conditions :
/// l'union des `field` référencés (récursivement à travers `and`/`or`/`not`).
///
/// C'est le contrat qui permet au sélecteur de visibilité (présentation) de
/// s'abonner UNIQUEMENT à ces champs — une frappe sur un champ **hors** de cet
/// ensemble ne déclenche donc AUCUN recalcul de visibilité (SM-1, AD-2).
///
/// **DP-2 (B3)** : seules les feuilles de source [ZValueSource.state] contribuent
/// — y compris les nouvelles feuilles de forme (`isNotEmpty`, `length*`). Les
/// feuilles [ZValueSource.persisted] (baseline **immuable** dans une session) et
/// [ZValueSource.context] (crud/mode **stables** dans une session) sont **exclues**
/// : une frappe sur un champ homonyme ne doit provoquer aucun recalcul inutile.
/// Le recalcul sur bascule de contexte passe par [zContextGuardKeysOf].
Set<String> zGuardFieldsOf(Iterable<ZCondition?> conditions) {
  final guards = <String>{};
  void walk(ZCondition? c) {
    if (c == null) return;
    final field = c.field;
    if (field != null && c.source == ZValueSource.state) guards.add(field);
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

/// Extrait l'**ensemble des clés de contexte** d'un ensemble de conditions :
/// l'union des `field` de source [ZValueSource.context] (récursif à travers
/// `and`/`or`/`not`).
///
/// **Companion de [zGuardFieldsOf] (DP-2, B3)** : permet à la présentation de
/// recalculer la visibilité **quand le contexte d'édition change** (bascule
/// `crud`, changement de `mode`, drapeau applicatif) SANS polluer la souscription
/// par frappe (les clés de contexte ne sont jamais des tranches de champ). Les
/// feuilles [ZValueSource.persisted] n'ont pas de companion de **clés** (la
/// baseline se lit via `persistedValueOf`, jamais par tranche de champ) : leur
/// ré-évaluation est signalée en bloc par [zHasPersistedGuard] (un `reset`
/// restaure la baseline d'origine, mais `reseed`/`markPristine` la **mutent** —
/// il faut donc recalculer sur `reseedRevision`, cf. DP-2 MEDIUM-1).
Set<String> zContextGuardKeysOf(Iterable<ZCondition?> conditions) {
  final keys = <String>{};
  void walk(ZCondition? c) {
    if (c == null) return;
    final field = c.field;
    if (field != null && c.source == ZValueSource.context) keys.add(field);
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
  return keys;
}

/// `true` si au moins une feuille de l'ensemble de conditions lit la source
/// [ZValueSource.persisted] (récursif à travers `and`/`or`/`not`).
///
/// **Companion « en bloc » de [zGuardFieldsOf]/[zContextGuardKeysOf] (DP-2,
/// MEDIUM-1)** : la baseline n'est PAS immuable dans une session — `reseed`
/// (chargement async d'un item) et `markPristine` la **mutent** (le `reset`, lui,
/// la restaure). La présentation ne peut donc pas se contenter de l'amorçage : si
/// une feuille `persisted` existe, elle doit **recalculer la visibilité sur chaque
/// `reseedRevision`**. Un seul booléen suffit (la valeur se relit via
/// `persistedValueOf`, jamais par clé de tranche — canal STRUCTUREL, hors SM-1).
bool zHasPersistedGuard(Iterable<ZCondition?> conditions) {
  bool walk(ZCondition? c) {
    if (c == null) return false;
    if (c.field != null && c.source == ZValueSource.persisted) return true;
    final operands = c.operands;
    if (operands != null) {
      for (final o in operands) {
        if (walk(o)) return true;
      }
    }
    return walk(c.operand);
  }

  for (final c in conditions) {
    if (walk(c)) return true;
  }
  return false;
}
