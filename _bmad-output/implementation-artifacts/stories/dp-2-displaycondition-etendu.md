# Story DP.2: `displayCondition` étendu (parité DODLP — B3)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As développeur consommateur de zcrud (migration DODLP → zcrud),
I want que la condition de visibilité déclarative `ZCondition` reproduise fidèlement les `displayCondition` réels de DODLP — c.-à-d. tester le **contexte externe** de l'édition (`crud`, `mode`, drapeaux applicatifs), des **prédicats de forme/liste** (`isEmpty`/`isNotEmpty`/longueur), et lire l'**item persisté d'origine** distinct de l'**état courant** du formulaire,
so that les formulaires authored pour DODLP (masquage `crud != Crud.read`, étape `(entries as List).isNotEmpty`, champ `item["reajusting"] != true`, etc.) migrent **à l'identique** sous zcrud — **sans réintroduire de closure runtime dans le domaine** (cause historique du focus perdu, AD-2) et **sans régresser la souscription ciblée SM-1**.

Périmètre : **`zcrud_core` uniquement** (+ ses tests). Gap couvert : **B3** (`displayCondition` → `ZCondition` trop faible). Réf : `docs/dodlp-edition-parity-gap.md` §1 (gap bloquant #3), §2.6 (ligne d'action B3) ; épic `E-DP` story DP-2 ; DODLP lecture seule `/home/zakarius/DEV/dodlp-otr`.

> ⚠️ **Additif & sérialisé derrière d'autres stories `zcrud_core`.** Tout ajout DOIT être rétro-compatible : les `ZCondition` existantes, l'API `evaluateZCondition(condition, valueOf)` à 2 arguments, et `zGuardFieldsOf` gardent un comportement **identique**. Aucun renommage, aucune signature cassante.

## Contexte — les 3 formes de prédicat DODLP réelles (lecture seule)

DODLP porte `displayCondition` comme une **closure** `bool Function(Map item, Map editionState, Crud crud)` (`dodlp-otr/lib/modules/data_crud/models.dart:631`), appelée à chaque rebuild du formulaire (`edition_screen.dart:430-431, 559-560, 3993-3994, 4105-4106`). Les usages prod réels se répartissent en **trois formes**, toutes **inexprimables** dans le `ZCondition` actuel (feuilles `equals/notEquals/isNull/notNull/truthy` lues via `valueOf` = seul état courant) :

**Forme A — Contexte externe (`crud` / `mode` / drapeaux applicatifs capturés).**
Le prédicat teste un contexte **hors formulaire**, pas une valeur de champ :
- `crud != Crud.read` (`pia/cargaison_form.dart:57`), `crud == Crud.read` (`vido/demande_depotage_form.dart:152`), `crud == Crud.create` (`capri/alert_capri_form.dart:143`, `vido:531`), `crud != Crud.create` (`vido:544`).
- `mode == CargaisonFormMode.correction` — variable de mode **capturée** au niveau du formulaire (`pia/cargaison_stepper_form.dart:461`).
- Drapeaux/services capturés : `includeGender == true` (`operateurs_economiques_screen.dart:224`), `userPermissions.can<AppelConvocation>(crud)` (`convocations_screen.dart:678`).

**Forme B — Prédicat de forme/liste (`isEmpty`/`isNotEmpty`/longueur).**
Le prédicat teste la **forme** d'une valeur collection/chaîne, pas une égalité :
- `editionState['entries'] is List && (editionState['entries'] as List).isNotEmpty` (`antaser/besc_detail_form.dart:375-377`).
- `(item["marchandisesDeclarees"] as String? ?? '').isNotEmpty` et `.isEmpty` (`vido/mes_dossiers_form.dart:127-128, 135-137`).
- `(item["articles"] as List?)?.isNotEmpty == true` combiné (`vido/mes_dossiers_form.dart:137`).
- Combinaison forme + contexte : `item["marchandisesDeclarees"] == null && crud != Crud.create` (`vido/demande_depotage_form.dart:544`).

**Forme C — Item persisté d'origine distinct de l'état courant.**
La closure reçoit **deux maps** : `item` (l'entité **persistée** telle que chargée) ET `editionState` (l'état **mutable** en cours d'édition). Certaines conditions lisent l'un, d'autres l'autre :
- `item["reajusting"] == true` / `!= true` (`vido/demande_depotage_form.dart:197, 484, 613`) → lit l'**item persisté**.
- `editionState['is_grouped'] == true`, `editionState['entries']…` (`antaser/besc_detail_form.dart:374-377`) → lit l'**état courant**.

Le `ZCondition` actuel n'a qu'un accès (`valueOf` = état courant), aucun contexte, aucune notion de forme. D'où le gap.

## Approche retenue — **déclaratif + seams de données injectés** (PAS de closure runtime dans le domaine)

**Décision : 100 % déclaratif, aucun `Function` dans `ZCondition` ni dans l'annotation.** Justification (NON-NÉGOCIABLE) :
- **AD-2 / objectif produit n°1** : une closure `(item, state, crud) → bool` est précisément le patron qui a causé le rebuild global + focus perdu ; `z_condition.dart` la proscrit explicitement, et l'évaluateur pur (`z_condition_evaluator.dart`) est le pendant runtime « sans effet ».
- **AD-3 / codegen** : le générateur émet `ZCondition` en **`const`** via `ConstantReader` (`zcrud_generator/lib/src/zcrud_model_generator.dart:397-398` → `_emitConst`). Une closure ne peut être ni `const` ni lue par `ConstantReader`. Tout nouvel opérateur DOIT rester `const` et émissible (enum + clés `String` + valeurs primitives).

Les trois besoins sont couverts **en données**, l'irréductiblement dynamique passant par un **seam de données** (une Map de contexte + un accesseur de valeur persistée) injecté à l'évaluateur — pas une closure portée par l'annotation :

| Forme DODLP | Mécanisme zcrud déclaratif | Seam runtime (données, injecté par la présentation) |
|---|---|---|
| **A** — `crud`/`mode`/drapeaux | Feuille sur **source `context`** : `ZCondition.equals('crud', 'read', source: ZValueSource.context)`, etc. Les drapeaux capturés (`includeGender`, `userPermissions.can(...)`) sont pré-calculés par l'app et injectés comme **clés de contexte** (workaround documenté = pseudo-champ). | `contextValueOf` : `Map<String,Object?>` de contexte (crud/mode/drapeaux) fournie à `DynamicEdition`. |
| **B** — forme/liste | Nouveaux opérateurs de **forme** : `isEmpty`, `isNotEmpty`, `lengthEquals(n)`, `lengthGt(n)`, `lengthGte(n)`, `lengthLt(n)`, `lengthLte(n)` sur n'importe quelle source. | Réutilise `valueOf` / `persistedValueOf` / `contextValueOf` selon `source`. |
| **C** — item persisté ≠ état | Sélecteur de **source** sur chaque feuille : `ZValueSource { state, persisted, context }` (défaut `state`). `item[...]` → `source: persisted` ; `editionState[...]` → `source: state`. | `persistedValueOf` : lit la **baseline** immuable du `ZFormController` (`_baseline`, déjà capturée à la construction). |

Aucun code manager-spécifique, aucun Flutter dans le domaine : `contextValueOf`/`persistedValueOf` sont de simples `Object? Function(String)` (comme `ZValueOf` existant) que **la présentation** (`DynamicEdition`) fournit. Le domaine reste pur, total, sans effet (AD-2).

## Acceptance Criteria

### Bloc A — Sélecteur de source + contexte externe (Forme A & C)

1. **Enum de domaine `ZValueSource`.** Un enum public `ZValueSource { state, persisted, context }` existe dans la couche `domain` de `zcrud_core` (pur-Dart `const`, aucune dépendance Flutter — AD-1), documenté, valeurs camelCase, exporté par le barrel du domaine (`domain.dart`, là où `ZCondition` est exporté). Sémantique : `state` = valeur courante du champ (défaut, comportement actuel), `persisted` = valeur de l'item **d'origine** (baseline), `context` = valeur d'une clé de **contexte d'édition** (crud/mode/drapeaux).

2. **`ZCondition` : chaque feuille porte une `source` additive & rétro-compatible.** Les constructeurs de **feuille** (`equals`, `notEquals`, `isNull`, `notNull`, `truthy`) gagnent un paramètre nommé `{ZValueSource source = ZValueSource.state}`, intégré au champ `final ZValueSource source`, à `==`, `hashCode`, `toString`. **Défaut `state`** : une `ZCondition.equals('a', 1)` construite sans `source` conserve exactement l'égalité de valeur et le comportement actuels (aucune régression des tests d'égalité / d'évaluation existants). Les **combinateurs** (`and`/`or`/`not`) n'ont pas de source (ils n'ont pas de feuille propre). Tout reste `const`.

3. **Feuille de contexte évaluée via `contextValueOf`.** Une feuille `source: ZValueSource.context` lit sa valeur via l'accesseur de contexte injecté (et non `valueOf`). Ex. `ZCondition.notEquals('crud', 'read', source: ZValueSource.context)` reproduit `crud != Crud.read`. Convention documentée : `crud` sérialisé en `String` camelCase (`'read'`/`'create'`/`'update'`/`'delete'` — miroir de l'enum `Crud` DODLP), `mode` en `String`, drapeaux en `bool`. Une clé de contexte **absente** → `null` (défensif, jamais de throw — AD-10).

4. **Feuille persistée évaluée via `persistedValueOf`.** Une feuille `source: ZValueSource.persisted` lit la valeur de l'**item d'origine** (baseline) via l'accesseur persisté injecté. Ex. `ZCondition.notEquals('reajusting', true, source: ZValueSource.persisted)` reproduit `item["reajusting"] != true`, indépendamment d'une saisie en cours sur ce champ. Accesseur persisté absent (non fourni) → `null` (défensif — AD-10).

### Bloc B — Prédicats de forme/liste (Forme B)

5. **Opérateurs de forme sur `ZConditionOp`.** `ZConditionOp` gagne (additif, à la fin — la désérialisation défensive tolère l'ordre) : `isEmpty`, `isNotEmpty`, `lengthEquals`, `lengthGt`, `lengthGte`, `lengthLt`, `lengthLte`. Constructeurs de feuille correspondants sur `ZCondition`, tous `const`, tous portant `field` + `source` (défaut `state`) ; les opérateurs de longueur portent en plus un `final int? length` (seuil de comparaison). Ex. `ZCondition.isNotEmpty('entries')`, `ZCondition.lengthGt('items', 0, source: ZValueSource.persisted)`.

6. **Sémantique de forme totale & alignée `zIsTruthy`.** Une fonction pure partagée (ex. `zLengthOf(Object?) → int`) calcule la longueur : `String`→`.length`, `Iterable`→`.length`, `Map`→`.length`, `null`→`0`, scalaire non-collection (`num`/`bool`)→`0` (traité comme « pas de longueur »). Sémantique : `isEmpty` = `zLengthOf(v) == 0` (donc `null`, `''`, `[]`, `{}` ⇒ vide) ; `isNotEmpty` = `zLengthOf(v) > 0` ; `lengthGt(n)` = `zLengthOf(v) > n` ; idem `Gte/Lt/Lte/Equals`. Cohérent avec `zIsTruthy` existant (une collection vide n'est ni truthy ni « non-vide »). **Pur / total : ne lève jamais** (AD-10). Reproduit `(entries as List).isNotEmpty` et `(str ?? '').isEmpty`.

7. **Composition avec combinateurs & sources mélangées.** Les nouvelles feuilles se composent librement dans `and`/`or`/`not` avec des sources hétérogènes. Ex. `item["marchandisesDeclarees"] == null && crud != Crud.create` ≡ `ZCondition.and([ZCondition.isNull('marchandisesDeclarees', source: persisted), ZCondition.notEquals('crud', 'create', source: context)])`. Le cas `besc_detail` ≡ `ZCondition.and([ZCondition.equals('is_grouped', true), ZCondition.isNotEmpty('entries')])` (source `state` par défaut). L'évaluation reste récursive et défensive (opérande `null` ⇒ neutre, inchangé).

### Bloc C — Évaluateur : accesseurs injectés (rétro-compatible)

8. **Signature étendue non cassante.** `evaluateZCondition` gagne des paramètres **nommés optionnels** : `evaluateZCondition(ZCondition condition, ZValueOf valueOf, {ZValueOf? persistedValueOf, ZValueOf? contextValueOf})`. Les appels existants à 2 arguments **compilent et se comportent à l'identique**. Résolution de l'accesseur par `condition.source` : `state`→`valueOf`, `persisted`→`persistedValueOf ?? (_) => null`, `context`→`contextValueOf ?? (_) => null`. **Total** : ne lève jamais (accesseur absent ⇒ valeur `null` défensive — AD-10).

9. **Table de vérité complète.** L'évaluateur gère les nouveaux `ZConditionOp` (forme/longueur) exactement selon AC6, en lisant la valeur via l'accesseur résolu par la source (AC8). Un `ZConditionOp` inconnu (forward-compat / donnée corrompue) est traité **défensivement** (retour neutre `true` ou `false` documenté, jamais de throw) — cohérent AD-10. Les feuilles mal formées (`field` `null`, non atteignables via les constructeurs publics) lisent `null` sans lever (garde existante préservée).

### Bloc D — Souscription ciblée SM-1 (`zGuardFieldsOf`)

10. **`zGuardFieldsOf` ne remonte que les champs de source `state`.** `zGuardFieldsOf` (contrat de souscription ciblée SM-1, consommé par `dynamic_edition.dart:232`) continue de retourner l'**union des `field` de source `state`** — y compris pour les nouvelles feuilles de forme/longueur : `ZCondition.isNotEmpty('entries')` (source `state`) DOIT contribuer `'entries'` au set de garde. Les feuilles de source **`persisted`** (item d'origine, **immuable** pendant la session) et **`context`** (crud/mode, **stables** pendant la session) **NE contribuent PAS** au set de garde par frappe — une frappe sur un tel « champ » homonyme ne doit déclencher aucun recalcul de visibilité inutile. La récursion `and`/`or`/`not` est préservée.

11. **Companion `zContextGuardKeysOf` (recalcul sur changement de contexte).** Une nouvelle fonction pure `Set<String> zContextGuardKeysOf(Iterable<ZCondition?>)` retourne l'union des `field` de source **`context`** (récursive). Elle permet à la présentation de recalculer la visibilité **quand le contexte change** (bascule `crud`, changement de `mode`) sans polluer la souscription par frappe. (Les feuilles `persisted` n'ont pas de companion : la baseline est immuable dans une session d'édition ; un `reseed`/`reset` recalcule déjà structurellement.)

### Bloc E — Câblage présentation `DynamicEdition` (seam minimal, additif)

12. **`ZFormController` expose la valeur persistée (baseline).** `ZFormController` gagne un accesseur public pur `Object? baselineValueOf(String name)` (lecture seule de `_baseline`, le snapshot d'origine déjà capturé à la construction / `markPristine`/`reseed`). Aucune mutation, aucun nouveau canal réactif, aucun `notifyListeners`. C'est la source de `persistedValueOf` (Forme C).

13. **`DynamicEdition` accepte un contexte d'édition optionnel.** `DynamicEdition` gagne un paramètre additif `Map<String, Object?> conditionContext = const <String, Object?>{}` (défaut vide → rétro-compat totale). `_recomputeVisibility` (`dynamic_edition.dart:254`) appelle désormais `evaluateZCondition(f.condition!, controller.valueOf, persistedValueOf: controller.baselineValueOf, contextValueOf: (k) => conditionContext[k])`. Le set de garde par frappe reste `zGuardFieldsOf(...)` (AC10, inchangé côté abonnement). Si `conditionContext` change (nouveau widget/rebuild parent) OU si une clé de `zContextGuardKeysOf` est concernée, `didUpdateWidget` déclenche **un** `_recomputeVisibility` structurel (jamais par frappe).

14. **SM-1 / AD-2 non régressés.** La borne de rebuild est inchangée : taper 100 caractères dans un champ **hors set de garde `state`** (ex. un champ dont dépendent seulement des conditions `context`/`persisted`) ne déclenche **aucun** recalcul de visibilité et **aucune** perte de focus. Une frappe sur un champ garde `state` (y compris via un prédicat de forme `isNotEmpty`) recalcule la visibilité **une** fois, en ordre canonique, via le canal structurel unique `setVisibleFields` (no-op si inchangé). Les tests `conditional_visibility_test.dart` et `grid_conditional_focus_test.dart` restent verts.

### Transverse — invariants & non-régression

15. **Désérialisation défensive / totalité (AD-10).** Aucun chemin de l'évaluateur ni des helpers de forme ne lève : accesseur injecté absent ⇒ `null` ; clé de contexte/persistée absente ⇒ `null` ; valeur non-collection sur un op de forme ⇒ longueur `0` ; `ZConditionOp` inconnu ⇒ retour neutre documenté ; feuille mal formée ⇒ `null`. Le générateur émettant `const` (`_emitConst`) reste compatible (enum `ZValueSource` + `int?` length + `String` field/value primitifs uniquement).

16. **Rétro-compatibilité stricte.** Conditions existantes inchangées (défaut `source: state`), `evaluateZCondition(c, valueOf)` à 2 args inchangé, `zGuardFieldsOf` inchangé pour les feuilles `state`, `DynamicEdition` sans `conditionContext` inchangé. Aucun renommage d'API publique, aucun retrait. Barrel `domain.dart` : seul ajout = export de `ZValueSource` (co-localisé dans `z_condition.dart` OU nouveau fichier exporté). Le graphe de dépendances (`zcrud_core` out-degree 0) reste inchangé — aucune nouvelle dépendance.

17. **Pureté domaine (AD-1/AD-2).** `z_condition.dart` et `z_condition_evaluator.dart` restent pur-Dart, sans import Flutter, sans état, sans closure portée par l'annotation. Garde `domain_purity_test.dart` verte. Aucun `Function` ajouté à `ZCondition`/`ZFieldSpec`/l'annotation `@ZcrudField`.

18. **Parité des 3 formes couverte par tests.** Chaque forme DODLP (A/B/C ci-dessus) est reproduite par au moins un test d'évaluation traçant le fichier/ligne DODLP source (voir Tests).

## Tasks / Subtasks

- [x] **T1 — Domaine `ZValueSource` + `ZCondition` étendu (AC1, AC2, AC5)**
  - [x] Ajouter `enum ZValueSource { state, persisted, context }` (co-localisé dans `z_condition.dart`, exporté par `domain.dart`), documenté, `const`, camelCase.
  - [x] `z_condition.dart` : ajouter `final ZValueSource source` (défaut `state`) aux feuilles `equals/notEquals/isNull/notNull/truthy` ; l'intégrer à `==`, `hashCode`, `toString`. Combinateurs inchangés (source par défaut `state`, non observée).
  - [x] Étendre `ZConditionOp` : `isEmpty, isNotEmpty, lengthEquals, lengthGt, lengthGte, lengthLt, lengthLte` (additif, en fin d'enum).
  - [x] Ajouter les constructeurs `const` de feuille de forme (`ZCondition.isEmpty(field, {source})`, `ZCondition.isNotEmpty(...)`, `ZCondition.lengthGt(field, n, {source})`, etc.) + champ `final int? length`.
  - [x] Vérifié : tout reste `const` (test `const-emissible` vert) — aucun `Function`.
- [x] **T2 — Helpers de forme purs (AC6)**
  - [x] Ajouter `int zLengthOf(Object?)` dans `z_condition_evaluator.dart` (String/Iterable/Map→length, null/scalaire→0), documenté et exporté.
  - [x] Aligner la sémantique avec `zIsTruthy` (collection vide = non-truthy = vide).
- [x] **T3 — Évaluateur : accesseurs injectés + nouveaux ops (AC3, AC4, AC8, AC9)**
  - [x] Étendre `evaluateZCondition` avec `{ZValueOf? persistedValueOf, ZValueOf? contextValueOf}` (optionnels, défaut `null` → accesseur neutre).
  - [x] Résoudre l'accesseur par `condition.source` avant la lecture de feuille (`leafValue`).
  - [x] Traiter les nouveaux `ZConditionOp` (forme/longueur) via `zLengthOf`.
  - [x] Évaluateur total : `switch` exhaustif sur l'enum ; accesseur/clé absent ⇒ `null` ; jamais de throw.
- [x] **T4 — Garde SM-1 (AC10, AC11)**
  - [x] `zGuardFieldsOf` : n'ajoute au set QUE les `field` de source `state` (récursif) — les nouvelles feuilles de forme `state` incluses ; `persisted`/`context` exclues.
  - [x] Ajouter `Set<String> zContextGuardKeysOf(Iterable<ZCondition?>)` (union des `field` de source `context`, récursif).
- [x] **T5 — Présentation `ZFormController` + `DynamicEdition` (AC12, AC13, AC14)**
  - [x] `z_form_controller.dart` : ajouter `Object? baselineValueOf(String name) => _baseline[name];` (lecture seule, pur).
  - [x] `dynamic_edition.dart` : ajouter le champ `final Map<String, Object?> conditionContext` (défaut `const {}`) au constructeur `const`.
  - [x] `_recomputeVisibility` : passe `persistedValueOf: widget.controller.baselineValueOf` et `contextValueOf: (k) => conditionContext[k]` à `evaluateZCondition`.
  - [x] `didUpdateWidget` : déclenche **un** `_recomputeVisibility` si une clé de `zContextGuardKeysOf` a changé de valeur (comparaison de contenu) — jamais d'abonnement par frappe sur `context`/`persisted`. Gate d'amorçage passé de `_guardFields.isNotEmpty` à `_hasConditions` (support des conditions purement `context`/`persisted`).
- [x] **T6 — Tests (AC15..AC18)**
  - [x] `test/domain/edition/z_condition_evaluator_test.dart` : étendu — sources `state/persisted/context`, ops de forme/longueur, totalité (accesseur absent, clé absente, non-collection), `zGuardFieldsOf` exclut `persisted`/`context`, `zContextGuardKeysOf` correct, rétro-compat (2-args, égalité par défaut, const-emissible).
  - [x] Tests de parité des 3 formes traçant DODLP (Formes A/B/C + combinée A+C) dans le même fichier.
  - [x] Nouveau `test/presentation/edition/dp2_condition_context_test.dart` : recalcul UNIQUE sur changement de `conditionContext` (crud), condition `persisted` insensible à la frappe sur le champ homonyme (SM-1), condition de forme `isNotEmpty` réactive, non-régression sans `conditionContext`.
  - [x] Rejoué `analyze` (RC=0) + `flutter test` (RC=0, 649 tests) + `graph_proof` (CORE OUT=0) + purité `dart test` sur `zcrud_core`. (`melos run generate` : aucune annotation modifiée dans `zcrud_core`, pas de codegen requis.)

## Dev Notes

### Fichiers touchés (tous `zcrud_core`)

- **UPDATE** `packages/zcrud_core/lib/src/domain/edition/z_condition.dart` — enum `ZValueSource` (ou fichier voisin), `source` sur les feuilles, nouveaux `ZConditionOp` + constructeurs de forme + `length`. **État actuel** : `ZConditionOp {equals, notEquals, isNull, notNull, truthy, and, or, not}` ; classe `ZCondition` `const` avec `op/field/value/operands/operand`, `==`/`hashCode`/`toString`, `_listEquals` pur. **À préserver** : tout reste `const`, `_listEquals` intact, égalité déterministe.
- **UPDATE** `packages/zcrud_core/lib/src/domain/edition/z_condition_evaluator.dart` — accesseurs injectés, résolution par source, ops de forme, `zLengthOf`, `zContextGuardKeysOf`, `zGuardFieldsOf` filtré sur `state`. **État actuel** : `evaluateZCondition(condition, valueOf)` total + `zIsTruthy` + `zGuardFieldsOf` (union de tous les `field`). **À préserver** : totalité (ne lève jamais), sémantique `zIsTruthy`, récursion des combinateurs.
- **UPDATE** `packages/zcrud_core/lib/src/presentation/z_form_controller.dart` — `baselineValueOf(name)` lecture seule de `_baseline` (déjà présent, l.69). **À préserver** : `_baseline` n'est jamais muté hors des chemins existants (`markPristine`/`reseed`/`reset`) ; aucun canal réactif ajouté (SM-1).
- **UPDATE** `packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart` — `conditionContext` + câblage `_recomputeVisibility` (l.254-261) + `didUpdateWidget` (l.203+). **État actuel** : `_guardFields = zGuardFieldsOf(fields.condition)` (l.232) pilote l'abonnement (l.241-244) ; `_recomputeVisibility` filtre par `evaluateZCondition(f.condition!, controller.valueOf)` → `setVisibleFields`. **À préserver** : abonnement uniquement aux `_guardFields` (state), canal structurel unique `setVisibleFields`, place stable des conditionnels (AC déjà couverts E3).
- **UPDATE** `packages/zcrud_core/lib/domain.dart` — export de `ZValueSource` (si nouveau fichier) ; sinon aucun changement (co-localisé dans `z_condition.dart`, déjà exporté).

### Frontière déclaratif / seam (rappel AD-2)

Le domaine ne connaît **jamais** `crud`, `mode`, ni l'item persisté par un `Function` embarqué. Il ne connaît que : un **nom de clé** + une **source** (`state`/`persisted`/`context`). C'est la **présentation** (`DynamicEdition`, couche `presentation`) qui fournit, en **données**, la Map de contexte et l'accesseur de baseline. Le générateur n'émet donc que du `const` structurel. C'est le « seam évalué » évoqué dans la consigne : structure déclarative + données injectées au runtime, **zéro closure runtime dans le domaine**.

### Workaround documenté (drapeaux applicatifs capturés)

`includeGender == true` ou `userPermissions.can<AppelConvocation>(crud)` ne sont pas des valeurs de champ ni un `crud`/`mode` standard : l'app les **pré-calcule** et les injecte comme **clés de contexte** (`conditionContext['includeGender'] = includeGender`, `conditionContext['canAppel'] = userPermissions.can(...)`), puis la condition devient `ZCondition.truthy('includeGender', source: context)`. C'est le pattern « pseudo-champ caché » mentionné en §2.6 du rapport, rendu **propre** (donnée, pas closure). À documenter dans le doc-comment de `ZValueSource.context`.

### Convention de sérialisation du `crud` en contexte

`crud` est injecté comme `String` camelCase miroir de l'enum `Crud` DODLP : `'read'`, `'create'`, `'update'`, `'delete'` (canonique §5 : enums en camelCase). `ZCondition.equals('crud', 'read', source: context)` ≡ `crud == Crud.read`. Documenter cette convention (le binding DODLP/E7 mappera `Crud` → `String`).

### Pièges à éviter

- ❌ Ne PAS ajouter les feuilles `persisted`/`context` au set de `zGuardFieldsOf` (régression SM-1 : recalcul de visibilité inutile à chaque frappe sur un champ homonyme).
- ❌ Ne PAS muter `_baseline` depuis `baselineValueOf` (lecture seule stricte).
- ❌ Ne PAS rendre `persistedValueOf`/`contextValueOf` requis (casserait les appels 2-args existants).
- ❌ Ne PAS introduire de `Function` dans `ZCondition` (non-`const`, non `ConstantReader`, viole AD-2/AD-3).
- ❌ Ne PAS lever sur op inconnu / accesseur absent / valeur non-collection (AD-10).

## Testing Requirements

Framework : `package:test` (domaine, pur-Dart) + `flutter_test` (présentation). Rejouer `melos run generate` → `analyze` (RC=0) → `flutter test` (RC=0) sur `zcrud_core` avant `review`.

**Tests domaine (`z_condition_evaluator_test.dart`, pur) :**
- Feuilles par source : `state` (défaut, comportement inchangé), `persisted` (lit `persistedValueOf`, insensible à `valueOf`), `context` (lit `contextValueOf`).
- Ops de forme/longueur : `isEmpty`/`isNotEmpty` sur `null`/`''`/`'x'`/`[]`/`[1]`/`{}`/`{k:v}` ; `lengthGt/Gte/Lt/Lte/Equals` avec seuils ; non-collection (`num`/`bool`) ⇒ longueur `0`.
- Totalité (AD-10) : `persistedValueOf`/`contextValueOf` absents ⇒ `null` ; clé absente ⇒ `null` ; jamais de throw.
- `zGuardFieldsOf` : inclut les `field` `state` (dont ceux des ops de forme) ; **exclut** `persisted` et `context`. `zContextGuardKeysOf` : renvoie exactement les `field` `context` (récursif `and/or/not`).

**Tests de parité des 3 formes DODLP (traçabilité fichier:ligne) :**
- **Forme A** — `ZCondition.notEquals('crud','read', source: context)` avec context `{crud:'read'}`⇒`false`, `{crud:'update'}`⇒`true` (≡ `cargaison_form.dart:57`). `ZCondition.equals('crud','create', source: context)` (≡ `alert_capri_form.dart:143`). `ZCondition.truthy('includeGender', source: context)` (≡ `operateurs_economiques_screen.dart:224`, workaround pseudo-champ).
- **Forme B** — `ZCondition.and([ZCondition.equals('is_grouped', true), ZCondition.isNotEmpty('entries')])` : `{is_grouped:true, entries:[1]}`⇒`true`, `entries:[]`⇒`false`, absent⇒`false` (≡ `besc_detail_form.dart:375-377`). `ZCondition.isNotEmpty('marchandisesDeclarees')` / `isEmpty` sur `''`/`'x'` (≡ `mes_dossiers_form.dart:127,135`).
- **Forme C** — `ZCondition.notEquals('reajusting', true, source: persisted)` : baseline `{reajusting:true}`⇒`false` même si `state.reajusting=false` (saisie en cours) ; baseline `{reajusting:false}`/absent⇒`true` (≡ `demande_depotage_form.dart:197,484`). Combiné A+C : `and([isNull('marchandisesDeclarees', source: persisted), notEquals('crud','create', source: context)])` (≡ `demande_depotage_form.dart:544`).

**Tests présentation (`conditional_visibility_test.dart`, `flutter_test`) :**
- Changement de `conditionContext` (ex. `crud: 'read'` → `'update'`) recalcule la visibilité **une** fois (via `didUpdateWidget`), sans frappe.
- Condition `persisted` : une frappe sur le champ homonyme (état courant) ne change PAS la visibilité (la baseline est fixe).
- Condition de forme `isNotEmpty` (source `state`) : la visibilité bascule quand le champ passe de vide à non-vide, **une** fois, sans perte de focus (SM-1).
- Non-régression : formulaire sans `conditionContext` (défaut) et conditions `equals`/`truthy` existantes se comportent à l'identique.

## Architecture Compliance

- **AD-1** : `zcrud_core` out-degree 0 — aucune dépendance ajoutée ; enum/helpers pur-Dart.
- **AD-2 / SM-1** : aucune closure runtime dans le domaine ; abonnement par frappe limité aux feuilles `state` (`zGuardFieldsOf`) ; recalcul `context` sur changement structurel seulement ; `persisted` immuable ; canal structurel unique `setVisibleFields`.
- **AD-3** : `ZCondition` reste `const` émissible par le générateur (`_emitConst`/`ConstantReader`) ; aucun `Function` ; `freezed` non imposé.
- **AD-10** : évaluateur/helpers **totaux** (ne lèvent jamais) ; source/op/clé inconnus ⇒ défensif ; évolution **additive** (enum étendu, params optionnels, défauts rétro-compat).
- **AD-13** : sans objet (pas d'UI directionnelle ajoutée ; câblage visibilité seulement).

## Definition of Done

- [x] AC1..AC18 satisfaits.
- [x] Les 3 formes DODLP (A/B/C) reproduites et testées avec traçabilité fichier:ligne.
- [x] Rétro-compat vérifiée : conditions existantes, `evaluateZCondition` 2-args, `DynamicEdition` sans `conditionContext` → comportement identique (tests existants verts, 649 total).
- [x] SM-1 / AD-2 non régressés (`conditional_visibility_test`/`grid_conditional_focus_test` verts ; frappe hors garde `state` = 0 recalcul, prouvé par le test `persisted` insensible à la frappe).
- [x] `analyze` RC=0, `flutter test` RC=0 (649) (zcrud_core) ; `melos run generate` sans objet (aucune annotation `zcrud_core` modifiée).
- [x] Aucune modification hors `zcrud_core` (+ tests) ; aucun fichier DODLP touché.

## Dev Agent Record

### Implementation Plan

Approche 100 % déclarative + **seams de données** injectés (aucune closure runtime dans le domaine — AD-2/AD-3). Trois leviers, tous en données :

1. **`ZValueSource { state, persisted, context }`** co-localisé dans `z_condition.dart` : chaque feuille porte une `source` (défaut `state`). L'évaluateur résout l'accesseur (`valueOf`/`persistedValueOf`/`contextValueOf`) AVANT chaque lecture de feuille.
2. **Ops de forme** (`isEmpty`/`isNotEmpty`/`length*`) via un helper pur total `zLengthOf` (aligné `zIsTruthy`).
3. **Câblage présentation** : `ZFormController.baselineValueOf` (lecture seule de `_baseline`) alimente `persistedValueOf` ; `DynamicEdition.conditionContext` (Map défaut vide) alimente `contextValueOf`. `didUpdateWidget` déclenche UN recalcul si une clé de `zContextGuardKeysOf` change ; le set de garde par frappe (`zGuardFieldsOf`) reste filtré `state` (SM-1).

### Completion Notes

- **Additif / rétro-compatible strict** : aucun symbole retiré/renommé. `evaluateZCondition(c, valueOf)` 2-args, `zGuardFieldsOf`, `DynamicEdition` sans `conditionContext`, et toutes les `ZCondition` existantes (défaut `source: state`) conservent un comportement identique. `source` ajouté à `==`/`hashCode` : les conditions historiques (toutes `state`) restent mutuellement égales.
- **Pureté domaine préservée** : `z_condition.dart`/`z_condition_evaluator.dart` restent pur-Dart ; `domain.dart` Flutter-free (garde `dart test` verte). Aucun `Function` ajouté à `ZCondition`/annotation — tout reste `const` émissible par `ConstantReader`/`_emitConst` (AD-3).
- **SM-1** : `zGuardFieldsOf` ne remonte que les feuilles `state` (feuilles de forme `state` incluses) ; `persisted`/`context` exclues du recalcul par frappe. Recalcul de contexte via `zContextGuardKeysOf` sur bascule structurelle uniquement.
- **Totalité (AD-10)** : accesseur/clé absent ⇒ `null` ; op de forme sur non-collection ⇒ longueur `0` ; jamais de throw. `switch` exhaustif sur `ZConditionOp`.
- **Décision de conception** : gate d'amorçage de la visibilité passé de `_guardFields.isNotEmpty` à `_hasConditions` — sans cela un formulaire n'ayant QUE des conditions `context`/`persisted` (garde `state` vide) n'aurait pas calculé sa visibilité initiale. Reste rétro-compatible (aucune condition ⇒ pas de recalcul, on respecte `visibleFields` de l'hôte).
- **Vérif verte rejouée sur disque** : `dart analyze` RC=0 (No issues) ; `flutter test` RC=0 (649 tests, baseline ~625 + 24 nouveaux) ; `python3 scripts/dev/graph_proof.py` → `CORE OUT=0 OK` / `ACYCLIQUE OK` ; `dart test test/purity/domain_entrypoint_dart_test.dart` RC=0 (domaine Flutter-free).
- **Périmètre** : `packages/zcrud_core` uniquement (+ tests). Aucun autre package touché, aucun fichier DODLP touché, sprint-status NON modifié (transition gérée par l'orchestrateur).

### File List

- `packages/zcrud_core/lib/src/domain/edition/z_condition.dart` (M) — `enum ZValueSource` ; `source`/`length` + nouveaux `ZConditionOp` + constructeurs de forme ; `==`/`hashCode`/`toString`.
- `packages/zcrud_core/lib/src/domain/edition/z_condition_evaluator.dart` (M) — signature étendue (accesseurs optionnels) + résolution par source + ops de forme ; `zLengthOf` ; `zGuardFieldsOf` filtré `state` ; `zContextGuardKeysOf`.
- `packages/zcrud_core/lib/src/presentation/z_form_controller.dart` (M) — `baselineValueOf(name)` (lecture seule pure).
- `packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart` (M) — `conditionContext` ; câblage `_recomputeVisibility` (persisted/context) ; `_contextGuardKeys`/`_hasConditions` ; recalcul `didUpdateWidget` sur bascule de contexte.
- `packages/zcrud_core/test/domain/edition/z_condition_evaluator_test.dart` (M) — groupes DP-2 (sources, forme/longueur, gardes, parité A/B/C, rétro-compat).
- `packages/zcrud_core/test/presentation/edition/dp2_condition_context_test.dart` (A) — câblage contexte/persisted/forme + non-régression SM-1.
- `packages/zcrud_core/lib/domain.dart` : inchangé (`ZValueSource` co-localisé dans `z_condition.dart`, déjà ré-exporté).

## Project Context Reference

- Gap source : `docs/dodlp-edition-parity-gap.md` §1 (bloquant #3), §2.6 (action B3).
- Épics : `_bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md` (E-DP · DP-2).
- Architecture (AD-1/2/3/10/13) : `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md`.
- DODLP (lecture seule) : `/home/zakarius/DEV/dodlp-otr/lib/modules/data_crud/models.dart:631`, `.../presentation/views/edition_screen.dart:430-431,559-560`, + closures citées (§ Contexte).
- Story précédente de l'épic : `dp-1-layout-fieldsize-decoration.md` (patterns `ZcrudTheme`/tokens, non liés mais même épic).

## Change Log

| Date | Version | Description | Auteur |
|---|---|---|---|
| 2026-07-11 | 0.1 | Création story (context engine) — DP-2 displayCondition étendu (B3) | bmad-create-story |
| 2026-07-11 | 0.2 | Implémentation DP-2 : `ZValueSource` + ops de forme + accesseurs injectés + câblage `DynamicEdition` (contexte/baseline) ; 24 tests ajoutés ; analyze/test/graph/purité verts | bmad-dev-story |
