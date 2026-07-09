---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 2.7 : Réactivité Flutter-native (`ZFormController`) + seams d'injection

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur du cœur `zcrud_core`**,
je veux **poser la brique de réactivité Flutter-native — un `ZFormController` (`ChangeNotifier`) qui expose une `ValueListenable` par champ (rebuild ciblé), le pattern de *seams* d'injection qui `throw` par défaut, et `ZcrudScope` (un `InheritedWidget`, défaut zéro-dépendance) qui résout ces seams — le tout SANS importer aucun gestionnaire d'état (ni Riverpod, ni GetX, ni provider) et sans jamais référencer `WidgetRef`/`Get.find`/`Get.put`/`Provider.of`**,
afin que **le moteur `DynamicEdition` (E3) corrige par conception le bug historique de reconstruction globale du formulaire à chaque frappe (jank, perte de focus, saut de curseur — OBJECTIF PRODUIT N°1, SM-1), que la granularité soit identique quel que soit le gestionnaire d'état de l'app hôte (AD-15), et que l'injection/cycle de vie soit branchable par binding (E2-9) sans jamais modifier le cœur (AD-6).**

## Contexte & valeur — OBJECTIF PRODUIT N°1 + INFLEXION ARCHITECTURALE

**Objectif produit n°1 de zcrud** (CLAUDE.md, PRD SM-1, AD-2) : corriger par conception le bug de rafraîchissement global du formulaire à chaque frappe. Cette story pose la **fondation réactive** sur laquelle E3 construira le moteur `DynamicEdition` : un `ZFormController` dont chaque champ est une **tranche `ValueListenable` indépendante**, si bien qu'un widget de champ ne reconstruit **que** sa propre tranche (via `ValueListenableBuilder`) — jamais tout le formulaire.

**⚠️ INFLEXION ARCHITECTURALE — `zcrud_core` acquiert le SDK Flutter (à cadrer explicitement).**
Jusqu'ici (E2-1 `done`, E2-2 `review`) `zcrud_core` est **pur-Dart** (`environment.sdk: ^3.12.2`, seule dépendance runtime `dartz`, tests `package:test` via `dart test`). **E2-7 y introduit pour la première fois le SDK Flutter** :
- `ChangeNotifier` / `ValueListenable` / `Listenable` / `ValueNotifier` (`package:flutter/foundation.dart`) pour la réactivité (AD-2/AD-15) ;
- `InheritedWidget` / `BuildContext` / `ValueListenableBuilder` (`package:flutter/widgets.dart`) pour `ZcrudScope` et le pattern de binding par slice.

Ceci est **explicitement autorisé** par AD-14 : « `zcrud_core` **autorise Flutter** (widgets du moteur d'édition) ; c'est la *couche modèles canoniques* (`domain/`) qui est pur-Dart, pas tout le package ». **La frontière de pureté est donc REDÉFINIE PAR COUCHE** (voir AC1 et Dev Notes « Frontière de pureté par couche »).

**Ce que cette story matérialise** (cycle réactif AD-2, diagramme architecture.md#AD-2) :
```
Frappe → ZFormController (ChangeNotifier, Flutter-natif)
        → fieldListenable(name) (ValueListenable de la tranche)
          → ZFieldWidget (ValueListenableBuilder) → rebuild CIBLÉ (ce champ seul)
        → visibleFields (ValueListenable structurel) → liste des champs (rebuild seulement sur changement de visibilité)
```

**Ce qui débloque :** E2-7 est verrouillé **avant** E2-8 (l10n/thème injectables, qui branche ses seams sur `ZcrudScope`) et **avant** E2-9 (bindings `zcrud_riverpod`/`zcrud_get`/`zcrud_provider`, qui adaptent création/scoping/dispose du `ZFormController` et résolvent les seams selon leur idiome). E2-7 → E3 (moteur `DynamicEdition` : E3-1 porte le test SM-1 *plein formulaire* à 100 caractères ; E3-2 gère les `TextEditingController` stables). Ordre intra-épic (epics.md) : **E2-1 → E2-2 → E2-7 → E2-9** avant E2-4/E2-5.

**Ce qui rendra la story vérifiable :** un test widget prouve la **granularité** (mettre à jour un champ N fois ne reconstruit QUE ce champ, zéro rebuild du champ voisin, zéro perte de focus/saut de curseur — proto SM-1 au niveau controller) ; un grep/purity-test prouve **0** gestionnaire d'état importé et **0** occurrence de `WidgetRef`/`Get.find`/`Get.put`/`Provider.of` dans tout `zcrud_core` ; le nouveau **test de pureté par couche** prouve que `domain/` (+`data/`) reste **pur-Dart** tandis que `presentation/` n'importe que `flutter/foundation`+`flutter/widgets` (jamais `dart:ui` direct ni un manager) ; enfin **la CI reste verte** malgré l'ajout de Flutter (le pipeline de test bascule `zcrud_core` de `dart test` vers `flutter test` — voir AC9/AC10).

## Périmètre strict de CETTE story (anti-empiètement)

- ✅ **`ZFormController extends ChangeNotifier`** (couche `presentation`) : registre stable de champs `name → tranche` ; `ValueListenable<Object?> fieldListenable(String name)` (une tranche = un `ValueNotifier` **créé une fois**, jamais recréé) ; `Object? valueOf(String name)` ; `setValue(String name, Object? value)` qui notifie **UNIQUEMENT** la tranche du champ (jamais `notifyListeners()` global sur un changement de valeur) ; `ValueListenable<List<String>> visibleFields` (tranche **structurelle** : c'est le SEUL canal qui déclenche `notifyListeners()` du controller — ajout/retrait/visibilité de champ) ; `void dispose()` qui dispose **toutes** les tranches. Immuabilité de l'identité des tranches (map figée à la construction ou création paresseuse mémoïsée).
- ✅ **Pattern de *seams* d'injection** : une abstraction de dépendance dont l'implémentation **par défaut `throw`** (`ZScopeError`/`ZMissingBindingError` explicite) tant qu'aucun binding ne l'a fournie — c.-à-d. « seams résolus par `ZcrudScope` ou un binding ». Introduits ICI : (a) un **résolveur de dépendances** `ZDependencyResolver` (`T resolve<T>()`, défaut `_ThrowingResolver` qui `throw`) ; (b) le **seam de cycle de vie** du `ZFormController` (création/scoping/dispose — défaut : cycle local possédé par l'hôte). Le port `ZAcl` (E2-2) est **surfacé** par le scope avec le défaut zéro-config `ZAllowAllAcl`.
- ✅ **`ZcrudScope extends InheritedWidget`** (couche `presentation`, défaut zéro-dépendance) : porte un bundle **immuable** de seams résolus ; `static ZcrudScope of(BuildContext)` (lève `ZScopeError` si absent) + `static ZcrudScope? maybeOf(BuildContext)` ; `updateShouldNotify` correct ; accesseurs typés qui `throw ZScopeError` si le seam requis n'a pas été fourni ET n'a pas de défaut sûr.
- ✅ **Contrat du widget de champ qui n'écoute QUE sa tranche** : soit un helper réutilisable minimal (`ZFieldSlice`/`ZFieldListenableBuilder` = fin wrapper de `ValueListenableBuilder` sur `controller.fieldListenable(name)`), soit — a minima — le **harnais de référence** du test SM-1 documentant le pattern `ValueListenableBuilder` que E3 industrialisera. (Choix laissé au dev ; le helper est recommandé pour figer le pattern.)
- ✅ **pubspec `zcrud_core`** : ajout de `flutter: { sdk: flutter }` (dependencies) + `flutter_test: { sdk: flutter }` (dev_dependencies) ; `environment.flutter` optionnel documenté. `test: ^1.25.0` **conservé** (les tests pur-Dart existants tournent sous `flutter test`).
- ✅ **Bascule du pipeline de test** pour `zcrud_core` : `dart test` → `flutter test` (voir AC9). Ajustement **sérialisé et identique** des scripts melos dans `pubspec.yaml` **ET** `melos.yaml` (gate M-1 anti-divergence) + `ci.yml`.
- ✅ **Refactor du test de pureté en pureté PAR COUCHE** (AC1) : `domain/` (+`data/`) strict pur-Dart ; `presentation/` autorise `flutter/foundation`+`flutter/widgets` ; interdits transverses (managers, `dart:ui` direct, deps lourdes, tokens `WidgetRef`/`Get.find`/`Get.put`/`Provider.of`).
- ✅ Barrel : exporter `ZFormController`, `ZcrudScope`, `ZDependencyResolver`, `ZScopeError` et le helper de slice.
- ❌ **PAS** le moteur `DynamicEdition` ni le dispatcher de champs ni les `ZFieldWidget` concrets par type ni la gestion des `TextEditingController` (→ **E3** : E3-1/E3-2). E2-7 fournit la MÉCANIQUE réactive + le harnais de preuve, pas les widgets d'édition.
- ❌ **PAS** de seam l10n/libellés ni de seam thème `ZcrudTheme`/`ThemeExtension` concret (→ **E2-8**). E2-7 pose le **pattern** de seam ; E2-8 branche l10n/thème dessus.
- ❌ **PAS** de binding concret `zcrud_riverpod`/`zcrud_get`/`zcrud_provider` (→ **E2-9**). E2-7 garantit seulement que le cœur reste inchangeable pour ajouter un manager (le seam de cycle de vie est le point d'extension).
- ❌ **PAS** de `ZcrudRegistry`/`ZTypeRegistry`/`ZExtension` (→ **E2-3**) ; **PAS** de `ZFieldSpec`/modèles annotés (→ E2-4/E2-5) ; **PAS** de codegen (`.g.dart`).
- ❌ **PAS** de `package:flutter/material.dart` (E2-7 n'en a pas besoin : `InheritedWidget`/`ValueListenableBuilder` vivent dans `widgets.dart` ; le choix Material/Cupertino des widgets d'édition est tranché en E3). **PAS** de `dart:ui` en import direct.
- ❌ **NE PAS** ajouter de gestionnaire d'état (`flutter_riverpod`/`riverpod`/`get`/`provider`) ni de dépendance lourde (Firebase/Syncfusion/Quill/Maps) — AD-1/AD-15. `flutter` (SDK) n'est **pas** un `zcrud_*` → n'ajoute **aucune** arête au graphe (`CORE OUT=0` préservé, prouvé par `graph_proof.py`).
- ❌ **NE PAS** déplacer/renommer/affaiblir les types E2-1/E2-2 ni leur garde de pureté `domain/`. **NE PAS** toucher `sprint-status.yaml` (orchestrateur). **NE PAS** committer de `*.g.dart`.

## Acceptance Criteria

1. **Frontière de pureté REDÉFINIE PAR COUCHE (AD-14, AD-2, AD-15, AD-1).**
   - **`lib/src/domain/**` (et tout futur `lib/src/data/**`) reste STRICTEMENT pur-Dart** : **0** import `package:flutter/*`, `dart:ui`, backend (`cloud_firestore`/`firebase`/`hive`) ou gestionnaire d'état ; seul import externe autorisé `package:dartz`. La garde `domain/` existante (E2-1/E2-2) **n'est pas affaiblie** : ajouter Flutter au package ne doit PAS faire fuiter Flutter dans `domain/` (test qui échoue si un `import 'package:flutter/...'` apparaît sous `domain/`).
   - **`lib/src/presentation/**` autorise UNIQUEMENT** `package:flutter/foundation.dart` et `package:flutter/widgets.dart` (+ imports internes `package:zcrud_core/...` ou relatifs, + `package:dartz`). **INTERDITS même dans `presentation/`** : `dart:ui` en import direct, `package:flutter/material.dart` (E2-7), tout gestionnaire d'état (`flutter_riverpod`/`riverpod`/`package:get/`/`package:provider/`), toute dep lourde (`cloud_firestore`/`firebase`/`hive`/`syncfusion*`/`flutter_quill`/`google_maps*`).
   - **Transverse à TOUT `zcrud_core`** : **0** occurrence textuelle (hors commentaires) des tokens `WidgetRef`, `Get.find`, `Get.put`, `Provider.of` (AD-6).
   - `packages/zcrud_core/pubspec.yaml` n'ajoute **aucun** `zcrud_*` ni manager ni backend ; `graph_proof.py` affiche `CORE OUT=0 OK` et `ACYCLIQUE OK` (l'ajout de `flutter: {sdk: flutter}` n'ajoute pas d'arête `zcrud_*`).

2. **Nommage 100 % préfixé `Z` + emplacement `presentation`.** Tous les types publics introduits sont préfixés `Z` : `ZFormController`, `ZcrudScope`, `ZDependencyResolver`, `ZScopeError` (et `ZMissingBindingError` si distinct), le helper de slice (`ZFieldListenableBuilder`/`ZFieldSlice`). Ils vivent sous `packages/zcrud_core/lib/src/presentation/` ; l'API publique passe **uniquement** par le barrel `lib/zcrud_core.dart` (ordre alphabétique des `export`, `directives_ordering`). Aucun type public non préfixé `Z`.

3. **`ZFormController` — réactivité granulaire par tranche (AD-2, cœur de SM-1).**
   - `ZFormController extends ChangeNotifier`.
   - `ValueListenable<Object?> fieldListenable(String name)` retourne, pour un `name` donné, **toujours la même instance** de `ValueListenable` (tranche stable — créée une fois, mémoïsée ; jamais recréée entre deux appels/rebuilds). Un `name` inconnu → comportement défini et documenté (throw `ArgumentError` **ou** création paresseuse ; décision consignée en Dev Notes).
   - `setValue(String name, Object? value)` met à jour **exclusivement** la tranche du champ `name` : les listeners de `fieldListenable(name)` sont notifiés ; les listeners des **autres** tranches et le `ChangeNotifier` global du controller **ne sont PAS** notifiés (aucun `notifyListeners()` global sur un changement de valeur). Poser la même valeur (`==`) est un no-op (pas de notification superflue — `ValueNotifier` gère nativement l'égalité).
   - `Object? valueOf(String name)` lit la valeur courante d'une tranche.
   - `ValueListenable<List<String>> visibleFields` (ou équivalent structurel) : **seul** canal qui déclenche `notifyListeners()` du controller (changement d'ensemble/visibilité de champs — servira E3-4 champs conditionnels). Un `setValue` ne le modifie pas.
   - `void dispose()` : dispose **toutes** les tranches et le controller ; après `dispose`, tout accès lève l'erreur Flutter standard (`ChangeNotifier` disposé). Aucune fuite (pas de listener résiduel).

4. **Pattern de *seams* : throw par défaut (AD-6).** Il existe une abstraction dont l'implémentation par défaut **`throw`** un `ZScopeError` explicite (message actionnable : quel seam, comment le fournir) tant qu'aucun binding/scope ne l'a résolue. Concrètement : `ZDependencyResolver` est un `abstract` avec `T resolve<T>()` ; l'implémentation par défaut `_ThrowingResolver` (privée, exposée via un `ZcrudScope` non configuré ou un constructeur nommé) lève `ZScopeError` sur tout `resolve`. Un test prouve : accès à un seam **non fourni** ⇒ `throwsA(isA<ZScopeError>())` ; accès à un seam **fourni** (via `ZcrudScope`/binding fake) ⇒ la valeur injectée est retournée.

5. **`ZcrudScope` — InheritedWidget, défaut zéro-dépendance (AD-6, AD-15).**
   - `ZcrudScope extends InheritedWidget` porte un bundle **immuable** de seams résolus (`ZDependencyResolver`, seam de cycle de vie, `ZAcl` avec défaut `ZAllowAllAcl`).
   - `static ZcrudScope of(BuildContext context)` retourne le scope le plus proche ou **lève `ZScopeError`** (message : « aucun `ZcrudScope` dans l'arbre ; enveloppez votre app dans `ZcrudScope(...)` ou un binding ») ; `static ZcrudScope? maybeOf(BuildContext context)` retourne `null` si absent.
   - `updateShouldNotify(old)` renvoie `true` **ssi** le bundle de seams change (identité/valeur), pas à chaque rebuild.
   - Un `ZcrudScope` **par défaut** (zéro-config) est constructible sans fournir de manager : il expose `ZAllowAllAcl` (E2-2) comme ACL par défaut et un `ZDependencyResolver` **throwing** (les dépendances applicatives doivent être fournies explicitement — « seams throw par défaut »). Ceci prouve le chemin « zéro-dépendance » d'AD-15.

6. **Aucun gestionnaire d'état, aucun accès non-réactif interdit (AD-6, AD-15 — NON-NÉGOCIABLE).** Ni `zcrud_core/lib` ni `zcrud_core/pubspec.yaml` n'importent/déclarent `flutter_riverpod`, `riverpod`, `get`, `provider`. **Aucune** référence à `WidgetRef`, `Get.find`, `Get.put`, `Provider.of` (grep = 0, AC1). L'accès aux dépendances passe **exclusivement** par `ZcrudScope.of(context)` / l'API des seams. (Vérifié par le test de pureté par couche + grep.)

7. **Le widget de champ n'écoute QUE sa tranche (AD-2).** Le helper `ZFieldListenableBuilder`/`ZFieldSlice` (ou, à défaut, le harnais de test) construit un `ValueListenableBuilder<Object?>` branché sur `controller.fieldListenable(name)`, de sorte que **seul** ce sous-arbre reconstruit lorsque la tranche `name` change. Interdits respectés : pas de construction des champs dans une closure locale de `build()` du parent ; `ValueKey(name)` disponible/documenté pour l'usage E3 ; aucune ré-injection de valeur écrasant une sélection (le controller détient la valeur ; il ne pousse jamais `.text=` — la gestion `TextEditingController` est déléguée à E3).

8. **Test widget SM-1 (proto au niveau controller) — OBJECTIF PRODUIT N°1.** Un test **`flutter_test`** (`WidgetTester`) monte un harnais minimal : un `ZFormController` avec ≥ 2 champs (`"a"`, `"b"`), chacun rendu par un `ValueListenableBuilder` sur sa tranche, muni d'un **compteur de build par champ** :
   - **Granularité** : après montage (chaque champ construit une fois), appeler `controller.setValue('a', ...)` **N fois** (N ≥ 20, « frappe » simulée) puis `pump()` ⇒ le compteur du champ `"a"` a augmenté et le compteur du champ `"b"` **est resté à sa valeur initiale** (zéro rebuild croisé).
   - **Zéro rebuild global** : un `ListenableBuilder`/`AnimatedBuilder` branché sur le `ZFormController` lui-même (structurel) **n'a pas** reconstruit suite aux `setValue` (le `notifyListeners()` global n'est PAS déclenché par un changement de valeur).
   - **Focus/curseur préservés** : une variante avec un `TextField` réel dont `onChanged → controller.setValue`, sans ré-injection dans le `TextEditingController` ⇒ après saisie caractère par caractère, `focusNode.hasFocus == true` et la sélection/curseur n'est pas réinitialisée ; le champ voisin ne reconstruit jamais. *(La version PLEIN FORMULAIRE « taper 100 caractères ne reconstruit que le champ courant » sera portée en E3-1 sur `DynamicEdition` ; ici on prouve la garantie au niveau du controller.)*

9. **Impact test/CI cadré — la CI reste VERTE malgré Flutter (NON-NÉGOCIABLE, CLAUDE.md).** Une fois `flutter` déclaré, `dart test` **échoue** dans `zcrud_core` (« Flutter users should run `flutter test` ») — pour **tous** ses tests, y compris les ~80 tests pur-Dart E2-1/E2-2. L'implémentation ajuste le pipeline pour que **tous** les tests de `zcrud_core` tournent via **`flutter test`**, sans casser les 13 autres packages pur-Dart :
   - Scripts melos scindés par filtre : `test:dart` = `melos exec --no-flutter --dir-exists test -- dart test` ; `test:flutter` = `melos exec --flutter --dir-exists test -- flutter test` ; `test` = enchaîne les deux (ou un `test` unique qui route par `--flutter`/`--no-flutter`). **Décision d'implémentation** consignée en Dev Notes.
   - **Anti-divergence M-1 (gate:melos)** : toute modification des scripts est répliquée **à l'identique** dans `pubspec.yaml` (`melos.scripts`, source de vérité) **ET** `melos.yaml` — sinon `gate_melos_divergence.dart` échoue. Vérifié.
   - `ci.yml` : l'étape « Test » exécute désormais le(s) script(s) couvrant les packages Flutter ; la toolchain Flutter est déjà installée (subosito `flutter-action`) → `flutter test` exécutable en CI sans étape supplémentaire.

10. **Barrel & non-régression E2-1/E2-2.** Le barrel `lib/zcrud_core.dart` exporte les nouveaux types (`ZFormController`, `ZcrudScope`, `ZDependencyResolver`, `ZScopeError`, helper de slice), **conserve** tous les exports E2-1 (`ZEntity`/`ZNode`/`ZSyncable`/`ZSyncMeta`/`ZFailure`+sous-classes/`ZResult`/`ZCoreApi`) et E2-2 (`ZRepository`/`ZDataRequest`/`ZFilter`/`ZSort`/`ZCursor`/`ZDataState`/`ZAcl`/`ZAllowAllAcl`/`ZCrudAction`) et le re-export **curaté** dartz. Les tests E2-1/E2-2 (~80) restent **verts** (sous `flutter test` désormais). `melos list` = **14** packages ; `git ls-files '*.g.dart'` = **0**.

11. **Vérif verte finale (rejouée réellement sur disque).** `dart run melos run generate` OK (no-op, 0 modèle annoté) → `dart run melos run analyze` RC=0 (0 warning) → **`flutter test` sur `zcrud_core` RC=0** + `dart test` sur les 13 autres RC=0, via le(s) script(s) melos ajustés (`melos run test` RC=0 global) → `melos run verify` RC=0 (`graph_proof` `CORE OUT=0 OK`/`ACYCLIQUE OK`, gates reflectable/secrets/codegen/melos/compat OK, `verify:serialization` no-op toléré). Greps de pureté par couche = **0** violation (AC1/AC6).

## Tasks / Subtasks

- [x] **Tâche 1 — Inflexion pubspec : ajout du SDK Flutter (AC: 1, 6, 9)**
  - [x] `packages/zcrud_core/pubspec.yaml` : ajout `flutter: {sdk: flutter}` (deps) + `flutter_test: {sdk: flutter}` (dev), `test: ^1.25.0` conservé. `environment.flutter` OMIS (commentaire justificatif). En-tête pubspec mis à jour (AD-14 ; toujours 0 `zcrud_*`/manager/backend).
  - [x] `dart pub get` racine RC=0 ; `graph_proof.py` → `CORE OUT=0 OK` (17 arêtes, ACYCLIQUE) ; lockfile racine unique, aucun lock parasite.
- [x] **Tâche 2 — `ZFormController` (couche presentation) (AC: 2, 3)**
  - [x] `lib/src/presentation/z_form_controller.dart` créé : `ChangeNotifier` ; map `name → ValueNotifier<Object?>` (tranches mémoïsées) ; `fieldListenable`/`valueOf`/`setValue` (notifie SEULEMENT la tranche) ; `visibleFields` + `setVisibleFields` (seul déclencheur `notifyListeners()`) ; `dispose`. Import `foundation.dart` uniquement.
  - [x] Décision `fieldListenable(nameInconnu)` = **création paresseuse mémoïsée** (documentée dans le code + Completion Notes, décision (a)).
- [x] **Tâche 3 — Seams + `ZScopeError` + `ZDependencyResolver` (AC: 4, 6)**
  - [x] `lib/src/presentation/z_scope_error.dart` : `class ZScopeError extends Error` + message actionnable. `ZMissingBindingError` **fusionné** (décision (e)).
  - [x] `lib/src/presentation/z_dependency_resolver.dart` : `abstract class ZDependencyResolver { T resolve<T>(); }` + `_ThrowingResolver` (défaut `throw ZScopeError`, exposé via `ZDependencyResolver.throwing`). Pur-Dart.
- [x] **Tâche 4 — `ZcrudScope` (InheritedWidget) (AC: 5, 6)**
  - [x] `lib/src/presentation/zcrud_scope.dart` : `InheritedWidget` (bundle `resolver`+`acl`) ; `of`/`maybeOf` ; `updateShouldNotify` (identité) ; défaut zéro-config (resolver throwing + `const ZAllowAllAcl()`). Réutilise `ZAcl`/`ZAllowAllAcl` (E2-2). Seam de cycle de vie via `resolver` (défaut host-owned) — décision (f).
- [x] **Tâche 5 — Helper de slice `ZFieldListenableBuilder` (AC: 7)**
  - [x] `lib/src/presentation/z_field_listenable_builder.dart` : wrapper `ValueListenableBuilder<Object?>` sur `controller.fieldListenable(name)`. Docstring (usage E3, `ValueKey(name)`, pas de closure/ré-injection). Import `widgets.dart`.
- [x] **Tâche 6 — Barrel (AC: 2, 10)**
  - [x] `lib/zcrud_core.dart` : +5 exports presentation (ordre alpha) ; E2-1/E2-2 + `ZCoreApi` + re-export curaté dartz conservés.
- [x] **Tâche 7 — Refactor du test de pureté PAR COUCHE (AC: 1, 6)**
  - [x] `test/purity/domain_purity_test.dart` : garde `domain/` renforcée + étendue à `data/` (échoue si `package:flutter/*` sous ces couches).
  - [x] `test/purity/presentation_purity_test.dart` : garde `presentation/` (whitelist foundation/widgets/internes/dartz ; interdit dart:ui direct, material/cupertino/services, managers, deps lourdes).
  - [x] Garde transverse tout `lib/` : 0 token `WidgetRef`/`Get.find`/`Get.put`/`Provider.of` (dans `presentation_purity_test.dart`). Tests sous `flutter test`.
- [x] **Tâche 8 — Tests widget & unitaires (AC: 3, 4, 5, 7, 8)**
  - [x] `test/presentation/z_form_controller_test.dart` (7 tests) : tranche stable, notification ciblée, no-op `==`, canal structurel, création paresseuse, dispose.
  - [x] `test/presentation/zcrud_scope_test.dart` (5 tests) : `of` sans scope → `ZScopeError` ; `maybeOf` → null ; défaut `ZAllowAllAcl` ; resolver non fourni/fourni ; `updateShouldNotify`.
  - [x] `test/presentation/sm1_granular_rebuild_test.dart` (2 tests) : SM-1 — `setValue('a')`×25 ⇒ buildsA=26, buildsB=1, buildsGlobal=1 ; variante `EditableText` : focus conservé, curseur en fin (non réinitialisé), voisin jamais reconstruit.
- [x] **Tâche 9 — Bascule pipeline test `dart test`→`flutter test` pour zcrud_core (AC: 9, 11)**
  - [x] `pubspec.yaml` (`melos.scripts`) scindé : `test:dart` (`--no-flutter`) + `test:flutter` (`--flutter`) + `test` (`melos run test:dart && melos run test:flutter`). Répliqué à l'identique dans `melos.yaml`. `verify_serialization.dart` rendu Flutter-aware (aiguillage runner dart/flutter, 79 toléré).
  - [x] `.github/workflows/ci.yml` : commentaire de l'étape « Test » documentant le routage flutter (Flutter déjà installé ; ordre codegen→analyze→test→gates inchangé).
  - [x] `gate_melos_divergence.dart` RC=0 (13 scripts, blocs identiques).
- [x] **Tâche 10 — Vérif verte & non-régression (AC: 9, 10, 11)**
  - [x] `generate` OK ; `analyze` RC=0 (14 pkgs) ; `melos run test` RC=0 (zcrud_core via `flutter test` = 96 tests) ; `melos run verify` RC=0 (`CORE OUT=0 OK`, `ACYCLIQUE OK`, gates OK) ; `prove_gates.dart` 22 OK/0 FAIL.
  - [x] ~80 tests E2-1/E2-2 verts sous `flutter test` (96 total) ; `melos list`=14 ; `git ls-files '*.g.dart'`=0 ; greps pureté 0 violation ; 0 token manager.

## Dev Notes

### INFLEXION ARCHITECTURALE — cadrage de l'ajout de Flutter à `zcrud_core`

E2-7 est la **première** story où `zcrud_core` cesse d'être un package pur-Dart. C'est **prévu et autorisé** :
- **AD-14** : « `zcrud_core` **autorise Flutter** (widgets du moteur d'édition) ; c'est la *couche modèles canoniques* (`domain/`) qui est pur-Dart, pas tout le package. »
- **AD-2/AD-15** : la réactivité repose sur les **primitives Flutter** (`Listenable`/`ValueListenable`/`ChangeNotifier`) — donc Flutter (SDK) est requis, mais **aucun gestionnaire d'état** (Riverpod/GetX/provider) n'entre dans le cœur.
- **AD-1 préservé** : `flutter: {sdk: flutter}` est une dépendance **SDK**, pas un `zcrud_*`. `graph_proof.py` ne compte que les arêtes `zcrud_*` (`EDGE = ^\s+(zcrud_[a-z_]+):`) → `CORE OUT=0` **inchangé**. Vérifié avant de coder.

### Frontière de pureté PAR COUCHE (à faire respecter par les tests)

| Couche | Flutter ? | Autorisé | Interdit |
|---|---|---|---|
| `lib/src/domain/**` (contrats E2-1, ports/data E2-2) | **NON** | `dartz`, Dart pur | **tout** `package:flutter/*`, `dart:ui`, backend, managers |
| `lib/src/data/**` (si créé plus tard) | **NON** | `dartz`, Dart pur | idem domain |
| `lib/src/presentation/**` (E2-7 : controller, scope, seams) | **OUI (restreint)** | `package:flutter/foundation.dart`, `package:flutter/widgets.dart`, internes, `dartz` | `dart:ui` **direct**, `flutter/material.dart` (E2-7), managers, deps lourdes |
| **Transverse tout `zcrud_core/lib`** | — | — | tokens `WidgetRef`, `Get.find`, `Get.put`, `Provider.of` |

⚠️ **Ne PAS déplacer** les types E2-2 : ils vivent sous `lib/src/domain/data/` et `lib/src/domain/ports/` (couverts par la garde `domain/`). Le task-description parle de « couche data (ports E2-2) » — dans CE repo, ces ports sont physiquement sous `domain/data|ports` ; la garde `domain/` les protège déjà. Ne rien renommer.

### Impact test/CI — `dart test` → `flutter test` (le point à ne pas rater)

**Fait technique** : dès qu'un package déclare `flutter: {sdk: flutter}`, `dart test` y refuse de tourner (« Flutter users should run `flutter test` »). Cela vaut pour **tous** les tests de `zcrud_core`, y compris les ~80 pur-Dart existants (qui importent `package:test/test.dart` — lesquels **tournent** parfaitement sous `flutter test`, qui est bâti au-dessus de `package:test`).

**État actuel** : `melos run test` = `melos exec --dir-exists test -- dart test` (pubspec.yaml `melos.scripts` = source de vérité ; `melos.yaml` = copie surveillée par `gate:melos`). CI (`ci.yml`) : étape « Test » = `dart run melos run test`, Flutter déjà installé (subosito `flutter-action@v2`, `flutter-version: 3.44.4`).

**Approche recommandée (dev tranche la forme exacte)** : scinder par filtre melos `--flutter`/`--no-flutter` :
```yaml
test:dart:
  run: melos exec --no-flutter --dir-exists test -- dart test
test:flutter:
  run: melos exec --flutter --dir-exists test -- flutter test
test:
  run: melos run test:dart && melos run test:flutter
```
- **Réplique OBLIGATOIRE** dans `pubspec.yaml` **et** `melos.yaml` (identiques au caractère près) — sinon `gate_melos_divergence.dart` (gate M-1) échoue. Sérialiser l'édition, vérifier le gate.
- `melos run test` (aggregate) reste le point d'entrée de CI et de la vérif verte — inchangé en surface, mais route désormais `zcrud_core` vers `flutter test`.
- Vérifier que `melos exec --flutter` sélectionne bien `zcrud_core` (et seulement lui, tant qu'il est le seul package Flutter) et `--no-flutter` les 13 autres.

*Ne PAS* forcer `flutter test` sur tous les packages (les pur-Dart n'ont pas Flutter → échec/lenteur). Le split par filtre est la solution propre.

### Conception `ZFormController` (invariants AD-2)

- **Tranche = `ValueNotifier<Object?>` mémoïsé** : une map `Map<String, ValueNotifier<Object?>>` remplie soit à la construction (liste de champs connue), soit paresseusement à la première demande — mais **jamais recréée** ensuite (identité stable exigée par AC3 ; c'est ce qui évite la recréation de state au rebuild, cause racine du bug).
- **`setValue` ≠ rebuild global** : écrire `_slices[name].value = v` notifie **uniquement** les listeners de cette tranche (comportement natif `ValueNotifier`). Le `ChangeNotifier` global (`notifyListeners()`) est **réservé** aux changements *structurels* (ensemble/visibilité de champs) — canal `visibleFields`. C'est l'invariant qui garantit SM-1.
- **Pas de ré-injection** : le controller **détient la valeur** ; il n'écrit jamais dans un `TextEditingController` (`.text=`). La synchronisation valeur↔TextField (et la stabilité du `TextEditingController`) est la responsabilité d'E3-2. Ici, le TextField du test SM-1 fait `onChanged → setValue` à sens unique.
- **`dispose`** : itérer les tranches, `notifier.dispose()`, puis `super.dispose()`. Aucun listener résiduel.

### Conception des *seams* (AD-6) — « throw par défaut »

Le principe AD-6 « seams résolus par binding, défaut throw » se matérialise ainsi :
- `ZDependencyResolver.resolve<T>()` par défaut (`_ThrowingResolver`) **lève `ZScopeError`** : forcer l'app à fournir explicitement ses dépendances (pas de résolution magique silencieuse).
- `ZcrudScope` par défaut (zéro-config) reste **utilisable** pour le chemin Flutter-natif pur : il fournit un `ZAllowAllAcl` (zéro-config sûr, E2-2) et un resolver throwing (les dépendances applicatives, si le code en demande, doivent être injectées via un scope configuré ou un binding E2-9).
- **Frontière avec E2-8/E2-9** : E2-7 pose le **pattern** (abstraction + throw + `ZcrudScope.of`). E2-8 branche les seams **l10n/thème** concrets ; E2-9 fournit les **bindings manager** (création/scoping/dispose du controller, résolution des seams selon Riverpod/GetX/provider). Ne PAS anticiper ces seams concrets ici.

### Conception du test SM-1 (proto au niveau controller)

Le test SM-1 *plein formulaire* (« taper 100 caractères ne reconstruit que le champ courant ») appartient à **E3-1** (sur `DynamicEdition`). E2-7 en prouve la **garantie sous-jacente** au niveau du controller, avec un harnais minimal :
```
ZcrudScope(
  child: Column(children: [
    ValueListenableBuilder(valueListenable: c.fieldListenable('a'), builder: (…) { buildsA++; return TextField(onChanged: (v)=>c.setValue('a', v), focusNode: fnA); }),
    ValueListenableBuilder(valueListenable: c.fieldListenable('b'), builder: (…) { buildsB++; return Text('b'); }),
    ListenableBuilder(listenable: c, builder: (…) { buildsGlobal++; return const SizedBox(); }), // structurel
  ]),
)
```
Assertions : après `enterText`/`setValue('a')` ×N → `buildsB` inchangé, `buildsGlobal` inchangé, `buildsA` augmenté ; `fnA.hasFocus == true` ; sélection du `TextEditingController` non réinitialisée. Utiliser `tester.pump()` (pas `pumpAndSettle` inutile). `flutter_test` requis (`testWidgets`).

### Conventions de code (canonique §5, cohérence E2-1/E2-2)

- Types publics **préfixés `Z`** ; fichiers `snake_case` ; API via barrel ; `directives_ordering` (ordre alpha des exports).
- **`Equatable` jamais** ; `==`/`hashCode` manuels si nécessaires (le bundle de seams peut s'appuyer sur l'identité).
- **`freezed`/`@JsonSerializable` non requis** (aucun modèle sérialisé ici ; 0 `.g.dart`).
- `analysis_options` hérité (`include: ../../analysis_options.yaml`) ; `public_member_api_docs` satisfait (docstrings sur tout public).
- Tests `presentation/` : **`flutter_test`** (`testWidgets`/`WidgetTester`) ; tests `domain/` : `package:test` (tournent sous `flutter test`).

### Emplacements décidés (sous `packages/zcrud_core/lib/src/presentation/`)

| Type | Fichier |
|---|---|
| `ZFormController` | `presentation/z_form_controller.dart` |
| `ZDependencyResolver` (+ `_ThrowingResolver`) | `presentation/z_dependency_resolver.dart` |
| `ZScopeError` | `presentation/z_scope_error.dart` |
| `ZcrudScope` | `presentation/zcrud_scope.dart` |
| `ZFieldListenableBuilder` | `presentation/z_field_listenable_builder.dart` |

### Source tree à toucher

```
packages/zcrud_core/
  pubspec.yaml                                   # UPDATE : + flutter (dep) + flutter_test (dev) ; toujours 0 zcrud_*/manager/backend
  lib/zcrud_core.dart                            # UPDATE : +5 exports presentation (ordre alpha) ; E2-1/E2-2 + ZCoreApi conservés
  lib/src/presentation/
    z_form_controller.dart                       # NEW (ChangeNotifier + tranches ValueListenable)
    z_dependency_resolver.dart                   # NEW (seam + throwing default)
    z_scope_error.dart                           # NEW (ZScopeError)
    zcrud_scope.dart                             # NEW (InheritedWidget + of/maybeOf + seams)
    z_field_listenable_builder.dart              # NEW (helper slice)
  test/presentation/
    z_form_controller_test.dart                  # NEW (flutter_test)
    zcrud_scope_test.dart                        # NEW (flutter_test)
    sm1_granular_rebuild_test.dart               # NEW (flutter_test — SM-1 proto)
  test/purity/
    domain_purity_test.dart                      # UPDATE : garde domain/ maintenue/renforcée (échoue si flutter sous domain/)
    presentation_purity_test.dart                # NEW : garde presentation/ (flutter/foundation+widgets OK ; dart:ui/material/managers KO) + tokens transverses
melos.yaml                                        # UPDATE : scripts test:dart/test:flutter/test (identiques à pubspec)
pubspec.yaml                                      # UPDATE : melos.scripts test:dart/test:flutter/test (SOURCE DE VÉRITÉ)
.github/workflows/ci.yml                          # UPDATE : étape Test couvre les packages Flutter (flutter déjà installé)
```

### Project Structure Notes

- `pubspec.yaml` **gagne** `flutter`/`flutter_test` mais **aucun** `zcrud_*`/manager/backend → `CORE OUT=0` préservé (prouvé `graph_proof.py`).
- Nouveau dossier `lib/src/presentation/` = première couche non pur-Dart du cœur (AD-14). La garde `domain/` reste stricte ; la garde `presentation/` est plus permissive mais bornée.
- Réutiliser `ZAcl`/`ZAllowAllAcl` (E2-2) dans `ZcrudScope` — **ne pas** redéclarer.
- Aucun `*.g.dart` (aucun modèle annoté). Ne pas committer de généré.

### References

- [Source: epics.md#E2] — Story E2-7 : `ZFormController` (`ChangeNotifier`) expose une `ValueListenable` par champ ; **aucun gestionnaire d'état importé** ; seams `throw` par défaut, résolus via `ZcrudScope` (InheritedWidget, défaut) ; cœur ne référence jamais `WidgetRef`/`Get.find`/`Provider.of` (AD-2, AD-6, AD-15). Ordre intra-épic E2-1→E2-2→E2-7→E2-9.
- [Source: epics.md#E3] — E3-1 : test SM-1 plein formulaire (taper 100 caractères ne reconstruit que le champ courant ; edge UJ-2 : perte de connexion pendant saisie ⇒ état du controller non perdu) ; E3-2 : `TextEditingController` stables, jamais recréés/ré-injectés. **Consommateurs** de la fondation E2-7.
- [Source: epics.md#E2 (E2-8/E2-9)] — E2-8 branche l10n/thème sur `ZcrudScope` ; E2-9 fournit les bindings manager (création/scoping/dispose du `ZFormController` + résolution des seams). Frontière de portée d'E2-7.
- [Source: architecture.md#AD-2] — réactivité Flutter-native, rebuilds granulaires ; interdits (`setState` global, champs dans closure de `build`, recréation `TextEditingController`, ré-injection de valeur) ; obligatoires (controller stable, `ValueKey`, validateurs mémoïsés, `AutovalidateMode.onUserInteraction`, place stable des champs conditionnels) ; diagramme du cycle réactif.
- [Source: architecture.md#AD-6] — seams (resolver, permissions, toast, config, l10n, codecs) + cycle de vie des controllers résolus par binding ; `ZcrudScope` (InheritedWidget, défaut zéro-dép) ; interdits `WidgetRef`/`Get.find`/`Get.put`/`Provider.of` — accès via `ZcrudScope.of(context)`.
- [Source: architecture.md#AD-14] — pureté par couche : `domain/` pur-Dart, mais `zcrud_core` **autorise Flutter** (widgets du moteur). Invariants métier au repository.
- [Source: architecture.md#AD-15] — `zcrud_core` n'importe aucun manager ; réactivité `Listenable`/`ValueListenable` ; bindings optionnels ; `ZcrudScope` défaut ; ajouter un manager = nouveau binding, jamais modifier le cœur.
- [Source: CLAUDE.md#Réactivité Flutter-native] — controller `ChangeNotifier`/`Listenable` pur-Flutter, une `ValueListenable` par champ, `ValueListenableBuilder`/`ListenableBuilder` ; interdits & obligatoires AD-2 ; multi-gestionnaire par bindings via `ZcrudScope`. SM-1 : taper 100 caractères ne reconstruit que le champ courant, zéro perte de focus.
- [Source: packages/zcrud_core/pubspec.yaml] — état pur-Dart actuel (sdk ^3.12.2, dartz, test) — à faire évoluer.
- [Source: packages/zcrud_core/test/purity/domain_purity_test.dart] — garde de pureté E2-1/E2-2 (imports interdits, tokens, `_stripComment`/`_containsWord`) — à refactorer en pureté par couche.
- [Source: pubspec.yaml#melos + melos.yaml] — scripts melos (`test` = `melos exec --dir-exists test -- dart test`) ; gate M-1 anti-divergence (`gate_melos_divergence.dart`) : blocs pubspec/melos.yaml identiques.
- [Source: .github/workflows/ci.yml] — pipeline codegen→analyze→test→gates ; Flutter installé via subosito ; étape Test à adapter.
- [Source: scripts/dev/graph_proof.py] — out-degree(zcrud_core) ne compte que les arêtes `zcrud_*` runtime → `flutter` SDK n'ajoute pas d'arête (`CORE OUT=0` préservé).
- [Source: packages/zcrud_core/lib/src/domain/ports/z_acl.dart] — `ZAcl`/`ZAllowAllAcl` (E2-2), réutilisés comme seam par défaut dans `ZcrudScope`.

## Stratégie de tests

- **`ZFormController` (`test/presentation/z_form_controller_test.dart`, flutter_test)** : `fieldListenable('a')` renvoie **la même instance** à deux appels (tranche stable) ; ajouter un listener sur `'a'` et un sur `'b'`, `setValue('a', x)` ⇒ listener `'a'` appelé, listener `'b'` **jamais** ; `setValue('a', mêmeValeur)` ⇒ pas de notification (no-op `ValueNotifier`) ; un listener sur le `ChangeNotifier` global n'est **pas** appelé par `setValue` (seul un changement `visibleFields` le déclenche) ; après `dispose()`, les tranches sont disposées (accès ⇒ erreur Flutter standard).
- **`ZcrudScope` (`test/presentation/zcrud_scope_test.dart`, flutter_test)** : `ZcrudScope.of(context)` sans scope dans l'arbre ⇒ `throwsA(isA<ZScopeError>())` ; `maybeOf` ⇒ `null` ; scope par défaut ⇒ `acl is ZAllowAllAcl` et `acl.can(...) == true` ; `resolver.resolve<X>()` non fourni ⇒ `ZScopeError`, fourni via un `ZcrudScope` configuré (fake resolver) ⇒ valeur injectée ; `updateShouldNotify` : `true` si bundle change, `false` sinon.
- **SM-1 proto (`test/presentation/sm1_granular_rebuild_test.dart`, flutter_test)** : harnais 2 champs + builder structurel avec compteurs ; `setValue('a')`/`enterText` ×N (N≥20) ⇒ `buildsA` augmente, `buildsB` **inchangé**, `buildsGlobal` **inchangé** (zéro rebuild global) ; variante `TextField` réel : après saisie caractère par caractère, `focusNode.hasFocus == true` et sélection non réinitialisée ; le champ voisin ne reconstruit jamais. *(Full-form 100 chars ⇒ E3-1.)*
- **Pureté par couche (`test/purity/*`, flutter_test)** : `domain_purity_test.dart` — 0 `package:flutter/*`/`dart:ui`/backend/manager sous `domain/` (échoue si Flutter fuit dans le domaine) ; `presentation_purity_test.dart` — sous `presentation/`, seuls `flutter/foundation`+`flutter/widgets`(+internes+dartz) autorisés, `dart:ui` direct/`flutter/material`/managers/deps lourdes interdits ; transverse `zcrud_core/lib` — 0 token `WidgetRef`/`Get.find`/`Get.put`/`Provider.of` (hors commentaires).
- **Non-régression** : les ~80 tests E2-1/E2-2 (`test/domain/*`) restent **verts** sous `flutter test` ; barrel exporte toujours E2-1/E2-2 + `ZCoreApi`.
- **Vérif verte finale** : `melos run generate` OK → `melos run analyze` RC=0 → `melos run test` RC=0 (zcrud_core `flutter test`, autres `dart test`) → `melos run verify` RC=0 (`CORE OUT=0`, ACYCLIQUE, `gate:melos` OK) ; `gate_melos_divergence.dart` RC=0 (blocs identiques).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`, effort high).

### Debug Log References

- Inflexion pubspec → `dart pub get` RC=0 ; `graph_proof.py` : 17 arêtes, `out-degree(zcrud_core)=0 (runtime)`, `ACYCLIQUE OK`, `CORE OUT=0 OK` (le SDK Flutter n'est pas une arête `zcrud_*`).
- **Blocage rencontré & résolu** : après ajout de Flutter, `melos run verify` a d'abord ÉCHOUÉ sur le slot `verify:serialization` (crash compilateur « Dart library 'dart:ui' is not available on this platform ») car `verify_serialization.dart` lançait `dart test` sur `zcrud_core` désormais Flutter. Correctif : script rendu **Flutter-aware** (aiguillage `flutter test` vs `dart test` selon la dépendance SDK Flutter du package ; exit 79 « no tests ran » toléré pour les deux runners). Vérifié : `flutter test --tags serialization-compat` (aucun match) → exit 79.
- Note : `dart test` seul ne « refuse » pas encore tant qu'aucun fichier n'importe Flutter, mais les tests `presentation/` (widget) l'exigent ; l'aiguillage par filtre melos `--flutter`/`--no-flutter` est la solution robuste retenue (AC9).

### Completion Notes List

- **Objectif produit n°1 (SM-1) matérialisé au niveau controller** : `setValue('a')` ×25 ⇒ `buildsA=26`, `buildsB=1`, `buildsGlobal=1` (zéro rebuild croisé, zéro rebuild global) ; variante `EditableText` : focus jamais perdu, curseur en fin de texte (non réinitialisé), voisin jamais reconstruit.
- **Décisions sur les ambiguïtés** :
  - **(a) `fieldListenable(nameInconnu)`** → **création paresseuse mémoïsée** (valeur initiale `null`), PAS de throw. Rationale : E3 (`DynamicEdition`) ne connaît pas toujours ses champs à l'avance ; évite un couplage d'ordre fragile. La composition structurelle reste gouvernée par `visibleFields`, pas par la simple existence d'une tranche. AC3 autorise explicitement ce choix.
  - **(b) helper de slice** → **fourni** (`ZFieldListenableBuilder`, recommandé), fige le pattern `ValueListenableBuilder` pour E3.
  - **(c) forme des scripts test** → **3 scripts** `test:dart` (`--no-flutter`) / `test:flutter` (`--flutter`) / `test` (`melos run test:dart && melos run test:flutter`). Récursion `melos run` validée. Actuellement `test:dart` = no-op (les 13 pur-Dart n'ont pas de `test/`), `test:flutter` route `zcrud_core`.
  - **(d) `ZScopeError`** → **`extends Error`** (erreur de programmation/config, pas condition récupérable) + `message` actionnable.
  - **(e) `ZMissingBindingError`** → **fusionné** dans `ZScopeError` (un seul type d'erreur actionnable suffit ; le message précise le seam manquant).
  - **(f) seam de cycle de vie du controller** (au-delà de (a)-(e)) → résolu via le seam `ZDependencyResolver` (canal unique), défaut zéro-config = « cycle local possédé par l'hôte » ; le binding concret (création/scoping/dispose) est **E2-9** — non anticipé ici (documenté dans `ZcrudScope`/`ZDependencyResolver`). À valider en code-review.
- **Vérif verte rejouée réellement** : `generate` RC=0 (no-op) → `analyze` RC=0 (14 pkgs, 0 issue) → `melos run test` RC=0 (`test:flutter` → 96 tests, dont ~80 E2-1/E2-2 non-régressés) → `melos run verify` RC=0 (`CORE OUT=0 OK`, `ACYCLIQUE OK`, gate:melos 13 scripts, reflectable/secrets/codegen/compat/serialization OK) → `prove_gates.dart` 22 OK/0 FAIL.
- **Pureté par couche (greps)** : 0 `package:flutter/*` sous `domain/` ; 0 `import 'dart:ui'` dans `lib/` ; `presentation/` n'importe que `foundation.dart`+`widgets.dart` (+ relatifs internes) ; 0 `flutter/material` ; 0 manager (`riverpod`/`get`/`provider`) ; 0 token `WidgetRef`/`Get.find`/`Get.put`/`Provider.of`.
- **Non-régression** : `melos list`=14 ; `git ls-files '*.g.dart'`=0 ; barrel conserve tous les exports E2-1/E2-2 + `ZCoreApi` + dartz curaté.

### File List

**Créés :**
- `packages/zcrud_core/lib/src/presentation/z_form_controller.dart`
- `packages/zcrud_core/lib/src/presentation/z_scope_error.dart`
- `packages/zcrud_core/lib/src/presentation/z_dependency_resolver.dart`
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart`
- `packages/zcrud_core/lib/src/presentation/z_field_listenable_builder.dart`
- `packages/zcrud_core/test/presentation/z_form_controller_test.dart`
- `packages/zcrud_core/test/presentation/zcrud_scope_test.dart`
- `packages/zcrud_core/test/presentation/sm1_granular_rebuild_test.dart`
- `packages/zcrud_core/test/purity/presentation_purity_test.dart`

**Modifiés :**
- `packages/zcrud_core/pubspec.yaml` (+`flutter`/`flutter_test` SDK ; en-tête AD-14)
- `packages/zcrud_core/lib/zcrud_core.dart` (+5 exports presentation, ordre alpha)
- `packages/zcrud_core/test/purity/domain_purity_test.dart` (garde `domain/`+`data/` renforcée)
- `pubspec.yaml` (`melos.scripts` : split `test:dart`/`test:flutter`/`test`)
- `melos.yaml` (réplique identique du split — gate M-1)
- `scripts/ci/verify_serialization.dart` (Flutter-aware : aiguillage runner dart/flutter)
- `.github/workflows/ci.yml` (commentaire routage flutter de l'étape Test)
