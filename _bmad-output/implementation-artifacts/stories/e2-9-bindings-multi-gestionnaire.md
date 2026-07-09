---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 2.9 : Bindings multi-gestionnaire (`zcrud_riverpod`, `zcrud_get`, `zcrud_provider`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant qu'**intégrateur d'une app hôte (DODLP/GetX, lex_douane/Riverpod, ou provider)**,
je veux **brancher l'injection, le scoping et le cycle de vie du `ZFormController` (et la résolution des seams) sur MON gestionnaire d'état, via un package de binding dédié (`zcrud_riverpod` / `zcrud_get` / `zcrud_provider`) qui adapte l'idiome de mon manager SANS réimplémenter la réactivité**,
afin que **le même `ZFormController` produise une granularité de rebuild IDENTIQUE (objectif produit n°1, SM-1) quel que soit le manager — prouvé par un test de parité rejoué à l'identique sous les 3 bindings ET sous `ZcrudScope` seul (AD-15) — et que le cœur `zcrud_core` reste STRICTEMENT inchangé (0 manager importé) pour supporter un manager de plus (AD-6/AD-15).**

## Contexte & valeur — MATÉRIALISATION D'AD-15 (multi-gestionnaire par bindings)

**AD-15 (NON-NÉGOCIABLE)** : « `zcrud_core` n'importe **aucun** gestionnaire d'état ; sa réactivité repose sur `Listenable`/`ValueListenable` (Flutter pur). Des **bindings optionnels** adaptent injection / cycle de vie / scoping du `ZFormController` et des seams à chaque idiome — `zcrud_riverpod`, `zcrud_get` (cible **DODLP**), `zcrud_provider` — **sans réimplémenter la réactivité**. `ZcrudScope` (InheritedWidget) est le défaut zéro-dépendance. Un même controller fonctionne à l'identique sous les quatre. **Ajouter un manager = un nouveau package de binding, jamais une modification du cœur. »**

Cette story **remplit les 3 coquilles** de binding créées en E1-2 (aujourd'hui de simples placeholders `ZRiverpodApi`/`ZGetApi`/`ZProviderApi`) avec leur **substance réelle** : chacun apporte (a) une implémentation de `ZDependencyResolver` (seam de résolution) selon son idiome, (b) un **widget de scope** équivalent à `ZcrudScope` qui monte le conteneur du manager ET injecte le resolver manager-backed dans un `ZcrudScope` (les widgets du cœur continuent d'appeler `ZcrudScope.of(context)`), (c) une politique de **création / scoping / dispose** du `ZFormController` conforme au lifecycle du manager.

**L'invariant de valeur (SM-1) est prouvé par un GATE DE PARITÉ** : un seul harnais de test — mêmes champs, même `ZFormController`, mêmes compteurs de build — est exécuté 4 fois (bare `ZcrudScope`, riverpod, get, provider). Sous chacun : `setValue('a')` ×N ne reconstruit que le champ `a`, jamais `b`, jamais le canal structurel, sans perte de focus. C'est la preuve exécutable que « la granularité repose sur les primitives Flutter, identique quel que soit le manager » (AD-2 renvoyant à AD-15).

**Ce qui débloque :** cette story déverrouille **E7-1** (binding `zcrud_get` + `ZcrudScope` pour DODLP — GetX/`get_it`, prioritaire pour le MVP) et **E8-1** (binding `zcrud_riverpod` + adaptateur d'entités lex_douane — `ProviderScope`). L'**ordre de livraison** intra-story reflète cette priorité : **`zcrud_get` d'abord** (E7), **`zcrud_riverpod` ensuite** (E8), **`zcrud_provider` en dernier** (aucun consommateur MVP direct, mais complète la matrice AD-15).

**Ce qui rend la story vérifiable :** (1) le gate de parité passe 4×4 (granularité + zéro rebuild global + focus préservé + voisin jamais reconstruit) ; (2) `graph_proof.py` prouve que le cœur reste `CORE OUT=0` et que le graphe reste **acyclique** (arêtes ajoutées : `binding → zcrud_core` uniquement — jamais l'inverse) ; (3) une garde de non-régression du cœur prouve **0** manager et **0** token `WidgetRef`/`Get.find`/`Get.put`/`Provider.of` **dans `zcrud_core`** (le code manager-spécifique vit UNIQUEMENT dans son binding) ; (4) la CI reste verte (les bindings deviennent des packages Flutter → routés vers `flutter test` par le filtre melos `--flutter` existant, sans toucher aux scripts → `gate:melos` M-1 inchangé).

## ⚠️ Verdict de taille : XL → voir la section « Découpage recommandé »

**Cette story couvrant les 3 bindings + le gate de parité est jugée XL** (3 packages × [inflexion pubspec Flutter+SDK manager + resolver + scope widget + lifecycle + tests] + 1 harnais de parité partagé réutilisable + son exécution 4×). Le **Readiness Report §recommandation #9** recommande explicitement de « scinder E2-9 en une story par binding + une story-gate de parité (prioriser `zcrud_get` pour E7, `zcrud_riverpod` pour E8) », et §finding majeur : « E2-9 empaquette 3 bindings avec un AC combiné non complétable incrémentalement (anti-pattern *setup all*) ». **Une section « Découpage recommandé » (ci-dessous) propose le split ; l'orchestrateur tranche.** Si l'orchestrateur choisit de garder la story unique, elle est livrable en respectant l'ordre `get → riverpod → provider` et le gate de parité final. Si elle est scindée, ce fichier sert de story-parent : chaque sous-story hérite du périmètre de son binding + le gate est porté par la story-gate.

## Périmètre strict de CETTE story (anti-empiètement)

Pour **chacun** des 3 bindings (`zcrud_get`, `zcrud_riverpod`, `zcrud_provider`), dans cet ordre :

- ✅ **Inflexion pubspec** : le package (aujourd'hui pur-Dart `sdk: ^3.12.2`, seule dep `zcrud_core`) devient un **package Flutter** — ajout de `flutter: {sdk: flutter}` + `flutter_test: {sdk: flutter}` (dev) + **le SDK du manager** (voir table plus bas) — **dans SON pubspec uniquement, jamais dans `zcrud_core`**. Toujours **0** autre `zcrud_*` que `zcrud_core`, **0** backend lourd (Firebase/Syncfusion/Quill/Maps).
- ✅ **Implémentation de `ZDependencyResolver`** (seam de résolution AD-6) selon l'idiome du manager : résout `T resolve<T>()` en délégant au conteneur du manager (`ProviderContainer`/`ref` ; `get_it`/`Get.find` ; `context.read<T>()`/locator injecté). Nom préfixé `Z` + suffixe binding (ex. `ZRiverpodResolver`, `ZGetResolver`, `ZProviderResolver`).
- ✅ **Widget de scope** équivalent à `ZcrudScope`, propre au binding (ex. `ZcrudRiverpodScope`, `ZcrudGetScope`, `ZcrudProviderScope`) : monte le conteneur du manager (`ProviderScope` / `Bindings`+`get_it` / `ChangeNotifierProvider`) **ET** enveloppe l'enfant dans un `ZcrudScope(resolver: <resolver manager-backed>, acl: ...)` — de sorte que **les widgets du cœur continuent d'appeler `ZcrudScope.of(context)`** (l'API du cœur ne change pas). Le binding ne réimplémente PAS la réactivité : il **réutilise** `ZFormController`/`ZFieldListenableBuilder` de `zcrud_core`.
- ✅ **Création / scoping / dispose du `ZFormController`** selon le lifecycle du manager :
  - `zcrud_get` : le controller créé/possédé via `get_it` (factory/singleton scopé) ou via un `GetxController` hôte ; `dispose()` branché sur `onClose`/`Get.delete`/désenregistrement `get_it`.
  - `zcrud_riverpod` : exposé par un provider **auto-dispose** (ex. `Provider.autoDispose` / `NotifierProvider`) qui `create` le `ZFormController` et appelle `ref.onDispose(controller.dispose)`.
  - `zcrud_provider` : exposé par un `ChangeNotifierProvider<ZFormController>(create: ...)` dont `provider` gère le `dispose()` automatiquement.
- ✅ **Tests widget par binding** (flutter_test) : le scope résout un seam fourni ; le `ZFormController` est créé et disposé au bon moment (pas de fuite) ; `ZcrudScope.of(context)` retourne bien le resolver manager-backed.
- ✅ **GATE DE PARITÉ partagé et réutilisable** : un harnais unique (fonction de suite paramétrée par un `wrap: Widget Function(Widget child)`) exécutant des assertions IDENTIQUES de rebuild granulaire, invoqué 4× (bare `ZcrudScope`, get, riverpod, provider). Emplacement du harnais = **décision de conception** (voir Dev Notes « Emplacement du harnais de parité » ; option recommandée : package dev-only `zcrud_binding_conformance`).
- ✅ **Barrel** de chaque binding : exporter le resolver + le scope widget (+ éventuels helpers). Conserver / retirer proprement le placeholder `Z*Api` (décision consignée : le remplacer par la substance réelle, ou le conserver comme marqueur de version).
- ✅ **Non-régression cœur & graphe** : `zcrud_core` **inchangé** (0 ligne modifiée idéalement ; si un point d'extension manque, le documenter comme finding — NE PAS ajouter de manager au cœur) ; `graph_proof.py` → `CORE OUT=0 OK` + `ACYCLIQUE OK` (nouvelles arêtes `binding → zcrud_core` seulement) ; garde de pureté cœur intacte (0 manager, 0 token interdit dans `zcrud_core`).
- ✅ **CI/melos** : vérifier que le filtre melos `--flutter` route bien les nouveaux packages Flutter vers `flutter test` (les bindings rejoignent `zcrud_core` côté `test:flutter`). **Ne PAS** modifier les scripts `test:dart`/`test:flutter`/`test` (ils routent déjà par `--flutter`/`--no-flutter`) → `gate:melos` M-1 reste vert sans édition. Si un ajout de package dev-only (harnais) est retenu, l'intégrer au workspace (`melos.yaml` packages glob) et ajuster le décompte `melos list`.

- ❌ **PAS** de logique métier applicative (adaptateur d'entités lex_douane → **E8-1** ; délégation à `getIt<DodlpController>()` réel + permissions/toast/config/l10n concrets DODLP → **E7-1**). E2-9 pose la **mécanique** de binding générique + un fake de démonstration dans les tests, pas l'intégration app réelle.
- ❌ **PAS** de seam l10n/thème concret (→ **E2-8**). E2-9 branche le seam de **résolution de dépendances** (`ZDependencyResolver`) et le lifecycle du controller ; les seams l10n/thème seront résolus par le même mécanisme une fois E2-8 livré.
- ❌ **PAS** de `ZListController` (fantôme signalé au readiness — non produit ; hors périmètre ; ne rien inventer).
- ❌ **PAS** de moteur `DynamicEdition` ni de widgets d'édition concrets (→ **E3**). E2-9 réutilise le harnais de champ minimal (`ZFieldListenableBuilder`) pour le gate de parité.
- ❌ **NE PAS** importer un manager, ni `WidgetRef`/`Get.find`/`Get.put`/`Provider.of`, ni le SDK d'un manager **dans `zcrud_core`** (AD-6/AD-15). Le code manager-spécifique vit **exclusivement** dans son package de binding.
- ❌ **NE PAS** créer d'arête `zcrud_core → binding` (acyclicité AD-1). **NE PAS** faire dépendre un binding d'un autre binding.
- ❌ **NE PAS** toucher `sprint-status.yaml` (orchestrateur). **NE PAS** committer de `*.g.dart`.

## Acceptance Criteria

1. **Cœur `zcrud_core` STRICTEMENT inchangé pour ajouter un manager (AD-15 — NON-NÉGOCIABLE).**
   - Aucune modification fonctionnelle de `packages/zcrud_core/lib/**` n'est requise pour brancher les 3 bindings (`git diff` sur `zcrud_core/lib` = vide, ou limité à de la doc explicitement justifiée ; **jamais** d'ajout de dépendance/import manager).
   - `packages/zcrud_core/pubspec.yaml` n'acquiert **aucun** `flutter_riverpod`/`riverpod`/`get`/`get_it`/`provider` ni aucun `zcrud_*`.
   - La garde de pureté du cœur reste verte : **0** occurrence (hors commentaires) de `WidgetRef`, `Get.find`, `Get.put`, `Provider.of` dans `zcrud_core/lib` ; **0** import manager sous `zcrud_core`.

2. **Graphe acyclique + cœur `CORE OUT=0` préservé (AD-1).** Après ajout des SDK manager et des arêtes de binding, `python3 scripts/dev/graph_proof.py` affiche `CORE OUT=0 OK` et `ACYCLIQUE OK`. Les seules nouvelles arêtes `zcrud_*` sont `zcrud_riverpod → zcrud_core`, `zcrud_get → zcrud_core`, `zcrud_provider → zcrud_core` (déjà présentes depuis E1-2) — **aucune** arête `zcrud_core → binding`, **aucune** arête `binding → binding`. Les SDK manager (`flutter_riverpod`/`get`/`provider`) n'étant pas des `zcrud_*`, ils n'ajoutent aucune arête comptée.

3. **`zcrud_get` — binding GetX/`get_it` (prioritaire E7).**
   - `pubspec.yaml` de `zcrud_get` : `flutter: {sdk: flutter}` + `flutter_test` (dev) + `get: ^4.x` + `get_it: ^8.x` (versions stables épinglées, confirmées à l'implémentation) ; `zcrud_core` conservé ; **rien** d'autre.
   - `ZGetResolver implements ZDependencyResolver` : `resolve<T>()` délègue à `get_it`/`Get.find<T>()` ; lève `ZScopeError` (ou l'erreur du locator, documentée) si `T` non enregistré.
   - `ZcrudGetScope` (widget) : enregistre/résout le `ZFormController` via `get_it`/`Bindings` (création/scoping/dispose branchés sur `onClose`/`Get.delete`/désenregistrement) **et** enveloppe l'enfant dans `ZcrudScope(resolver: ZGetResolver(...), acl: ...)`. Les widgets du cœur restent inchangés (`ZcrudScope.of(context)`).
   - Barrel `zcrud_get.dart` exporte `ZGetResolver` + `ZcrudGetScope`.
   - Tests widget verts : un seam fourni via `get_it` est résolu par `ZcrudScope.of(context).resolver.resolve<Seam>()` ; le `ZFormController` est disposé quand le scope est démonté (pas de fuite).

4. **`zcrud_riverpod` — binding Riverpod (prioritaire E8).**
   - `pubspec.yaml` : `flutter` + `flutter_test` + `flutter_riverpod: ^2.x` ; `zcrud_core` conservé ; rien d'autre.
   - `ZRiverpodResolver implements ZDependencyResolver` : `resolve<T>()` délègue à un `ProviderContainer`/`WidgetRef` (lecture d'un provider par type) ; `ZScopeError` si absent.
   - `ZcrudRiverpodScope` (widget) : monte `ProviderScope` **et** enveloppe l'enfant dans `ZcrudScope(resolver: ZRiverpodResolver(...))`. Le `ZFormController` est exposé par un provider **auto-dispose** (`create` + `ref.onDispose(controller.dispose)`).
   - Barrel `zcrud_riverpod.dart` exporte `ZRiverpodResolver` + `ZcrudRiverpodScope` (+ le provider du controller si public).
   - Tests widget verts : résolution d'un seam via provider ; auto-dispose du controller vérifié (pas de fuite après démontage/invalidation).

5. **`zcrud_provider` — binding `provider` (matrice complète).**
   - `pubspec.yaml` : `flutter` + `flutter_test` + `provider: ^6.x` ; `zcrud_core` conservé ; rien d'autre.
   - `ZProviderResolver implements ZDependencyResolver` : `resolve<T>()` délègue à `context.read<T>()` (ou à un locator injecté au scope) ; `ZScopeError` si absent.
   - `ZcrudProviderScope` (widget) : monte un `ChangeNotifierProvider<ZFormController>(create: ...)` (dispose géré par `provider`) **et** enveloppe l'enfant dans `ZcrudScope(resolver: ZProviderResolver(...))`.
   - Barrel `zcrud_provider.dart` exporte `ZProviderResolver` + `ZcrudProviderScope`.
   - Tests widget verts : résolution d'un seam via `provider` ; `dispose()` du controller déclenché par `provider` au démontage.

6. **GATE DE PARITÉ — un test de rebuild granulaire IDENTIQUE sous 4 configurations (AD-15, SM-1 — CŒUR DE LA STORY).**
   - Un **harnais unique et réutilisable** expose une suite paramétrée : `runZFormGranularRebuildParitySuite({required String label, required Widget Function(Widget child) wrap})`. Le corps monte TOUJOURS le même arbre : un `ZFormController` à ≥ 2 champs (`'a'`, `'b'`), chacun rendu par un `ZFieldListenableBuilder` (ou `ValueListenableBuilder` sur `controller.fieldListenable(name)`) muni d'un **compteur de build par champ**, plus un `ListenableBuilder` structurel branché sur le `ZFormController` (compteur global). Cet arbre est enveloppé par `wrap(...)`.
   - La suite est invoquée **4 fois** : (a) bare `ZcrudScope` (référence, aucun manager) ; (b) `ZcrudGetScope` ; (c) `ZcrudRiverpodScope` ; (d) `ZcrudProviderScope`. **Le corps du test et les assertions sont strictement identiques** ; seul `wrap` change (le code manager-spécifique est confiné au `wrap`).
   - **Assertions identiques sous chaque `wrap`** : après montage (chaque champ construit une fois), `controller.setValue('a', ...)` **×N (N ≥ 20)** puis `pump()` ⇒ (i) compteur `'a'` a augmenté ; (ii) compteur `'b'` **inchangé** (zéro rebuild croisé) ; (iii) compteur **global inchangé** (aucun `notifyListeners()` global — invariant SM-1) ; (iv) variante avec `TextField`/`EditableText` réel (`onChanged → setValue`, sans ré-injection) : après saisie caractère par caractère, `focusNode.hasFocus == true` et la sélection/curseur n'est pas réinitialisée ; le champ voisin ne reconstruit jamais.
   - **Preuve d'AD-15** : les 4 exécutions produisent les **mêmes** compteurs (à la config près de `wrap`) → la granularité est identique quel que soit le manager.

7. **Nommage & structure (Consistency Conventions §5).** Types publics préfixés `Z` (`ZGetResolver`/`ZRiverpodResolver`/`ZProviderResolver`, `ZcrudGetScope`/`ZcrudRiverpodScope`/`ZcrudProviderScope`) ; fichiers snake_case sous `lib/src/presentation/` ; API publique via barrel `lib/<pkg>.dart` uniquement (`directives_ordering`, ordre alpha des exports) ; aucun type public non préfixé `Z`. Le placeholder `Z*Api` est soit remplacé par la substance réelle, soit conservé (décision consignée).

8. **Le code manager-spécifique vit UNIQUEMENT dans son binding (AD-6/AD-15).** Chaque token/idiome manager (`Get.find`/`Get.put`/`getIt`, `ProviderScope`/`ref`/`WidgetRef`, `context.read`/`Provider.of`/`ChangeNotifierProvider`) apparaît **exclusivement** dans le package de binding correspondant — jamais dans `zcrud_core`, jamais dans un autre binding. Une garde (test/grep) le vérifie : `zcrud_get` ne contient pas `ProviderScope`/`context.read` ; `zcrud_riverpod` ne contient pas `Get.find`/`context.read` ; etc. (garde par binding, best-effort documentée).

9. **CI/melos verts sans divergence (M-1).** Les 3 bindings devenant des packages Flutter, ils sont routés vers `flutter test` par le filtre `melos exec --flutter` **existant** (aucune édition des scripts `test:dart`/`test:flutter`/`test` → `gate_melos_divergence.dart` reste vert, blocs `pubspec.yaml`/`melos.yaml` identiques inchangés). `dart pub get` racine RC=0 (résolution workspace des SDK manager) ; lockfile racine unique, aucun lock parasite de package.

10. **Non-régression + décompte packages.** Barrels des 3 bindings valides ; les exports/tests E2-1/E2-2/E2-7 de `zcrud_core` restent verts (aucune régression) ; `git ls-files '*.g.dart'` = **0**. `melos list` = **14** (ou **15** si le package dev-only `zcrud_binding_conformance` est retenu — décision consignée, et tout gate/attente de décompte ajusté en conséquence).

11. **Vérif verte finale (rejouée réellement sur disque).** `dart run melos run generate` OK (no-op, 0 modèle annoté) → `dart run melos run analyze` RC=0 (0 warning) → `dart run melos run test` RC=0 (les 4 packages Flutter — `zcrud_core` + 3 bindings + éventuel conformance — via `flutter test` ; les autres via `dart test`) avec le **gate de parité vert sous les 4 configurations** → `dart run melos run verify` RC=0 (`graph_proof` `CORE OUT=0 OK`/`ACYCLIQUE OK`, gates reflectable/secrets/codegen/melos/compat OK). Greps de pureté cœur = **0** violation (AC1/AC8).

## Tasks / Subtasks

- [x] **Tâche 1 — Harnais de parité partagé & réutilisable (AC: 6, 10)** *(fait en premier : c'est l'oracle commun ; permet le TDD des bindings)*
  - [x] Décider l'emplacement du harnais (Dev Notes « Emplacement du harnais de parité ») : **recommandé** = package dev-only `packages/zcrud_binding_conformance/` (dépend de `zcrud_core` + `flutter_test`) ; alternatives (entrypoint `package:zcrud_core/conformance.dart` ; duplication) évaluées et rejetées avec rationale.
  - [x] Implémenter `runZFormGranularRebuildParitySuite({required String label, required Widget Function(Widget child) wrap})` : arbre à 2 champs + compteurs par champ + compteur structurel global ; assertions granularité + zéro-rebuild-global + focus/curseur préservés ; N ≥ 20.
  - [x] Auto-test du harnais sous **bare `ZcrudScope`** (config de référence, sans manager) → vert.
  - [x] Si package dev-only retenu : l'ajouter au glob `packages/*` du workspace (`melos.yaml`), `dart pub get` racine RC=0, `melos list` reflète le nouveau décompte, `graph_proof` toujours `ACYCLIQUE`.
- [x] **Tâche 2 — `zcrud_get` (prioritaire E7) (AC: 2, 3, 7, 8)**
  - [x] `pubspec.yaml` : + `flutter`/`flutter_test` (SDK) + `get`/`get_it` (versions stables épinglées) ; 0 autre `zcrud_*`, 0 backend lourd. `dart pub get` RC=0 ; `graph_proof` `CORE OUT=0 OK`.
  - [x] `lib/src/presentation/z_get_resolver.dart` : `ZGetResolver implements ZDependencyResolver` (délègue `get_it`/`Get.find`).
  - [x] `lib/src/presentation/zcrud_get_scope.dart` : `ZcrudGetScope` (création/scoping/dispose du `ZFormController` via `get_it`/`Bindings` + enveloppe `ZcrudScope`).
  - [x] Barrel `zcrud_get.dart` : exporte resolver + scope (placeholder `ZGetApi` remplacé/conservé — décision).
  - [x] Tests widget `test/presentation/*` : résolution de seam, lifecycle/dispose, garde « pas d'idiome riverpod/provider ici ».
- [x] **Tâche 3 — `zcrud_riverpod` (prioritaire E8) (AC: 2, 4, 7, 8)**
  - [x] `pubspec.yaml` : + `flutter`/`flutter_test` + `flutter_riverpod: ^2.x`. `dart pub get` RC=0 ; `graph_proof` OK.
  - [x] `z_riverpod_resolver.dart` : `ZRiverpodResolver` (délègue `ProviderContainer`/`ref`).
  - [x] `zcrud_riverpod_scope.dart` : `ZcrudRiverpodScope` (`ProviderScope` + `ZcrudScope`) ; provider auto-dispose du `ZFormController` (`ref.onDispose`).
  - [x] Barrel + tests widget (résolution, auto-dispose, garde d'isolement d'idiome).
- [x] **Tâche 4 — `zcrud_provider` (matrice complète) (AC: 2, 5, 7, 8)**
  - [x] `pubspec.yaml` : + `flutter`/`flutter_test` + `provider: ^6.x`. `dart pub get` RC=0 ; `graph_proof` OK.
  - [x] `z_provider_resolver.dart` : `ZProviderResolver` (délègue `context.read`).
  - [x] `zcrud_provider_scope.dart` : `ZcrudProviderScope` (`ChangeNotifierProvider<ZFormController>` + `ZcrudScope`).
  - [x] Barrel + tests widget (résolution, dispose via provider, garde d'idiome).
- [x] **Tâche 5 — Exécution du GATE DE PARITÉ sous les 4 configs (AC: 6)**
  - [x] Un fichier de test par binding (ou un fichier agrégé) invoque `runZFormGranularRebuildParitySuite(wrap: ...)` avec le scope du binding ; + l'invocation bare `ZcrudScope`. 4 exécutions, assertions identiques, toutes vertes.
  - [x] Vérifier que les compteurs sont cohérents entre les 4 (mêmes ordres de grandeur : `buildsA` ↑, `buildsB` == 1, `buildsGlobal` == 1).
- [x] **Tâche 6 — Non-régression cœur, graphe, pureté (AC: 1, 2, 8)**
  - [x] `git diff packages/zcrud_core/lib` vide (ou doc justifiée) ; grep 0 manager / 0 token interdit dans `zcrud_core`.
  - [x] `graph_proof.py` `CORE OUT=0 OK` + `ACYCLIQUE OK` ; nouvelles arêtes = `binding → zcrud_core` seulement.
  - [x] Gardes d'isolement d'idiome par binding vertes.
- [x] **Tâche 7 — CI/melos & vérif verte finale (AC: 9, 10, 11)**
  - [x] Confirmer que `melos exec --flutter` sélectionne désormais `zcrud_core` + les 3 bindings (+ conformance) ; scripts `test:*` **inchangés** ; `gate_melos_divergence.dart` RC=0.
  - [x] `generate` OK → `analyze` RC=0 → `melos run test` RC=0 (gate de parité vert ×4) → `melos run verify` RC=0 → `prove_gates.dart` OK/0 FAIL.
  - [x] `git ls-files '*.g.dart'` = 0 ; barrels valides ; décompte `melos list` cohérent avec la décision Tâche 1.

## Dev Notes

### État réel des dépendances au démarrage (E2-7 `done`)

`zcrud_core` expose déjà, sous `lib/src/presentation/`, tout ce dont les bindings ont besoin — **aucun de ces types n'est à modifier** :

| Type cœur | Rôle pour le binding |
|---|---|
| `ZFormController extends ChangeNotifier` (`z_form_controller.dart`) | Le controller **réutilisé** tel quel : `fieldListenable(name)` (tranche stable), `setValue`/`valueOf`, `visibleFields`/`setVisibleFields` (seul canal `notifyListeners()`), `dispose()`. Le binding gère seulement **création/scoping/dispose**, pas la réactivité. |
| `ZcrudScope extends InheritedWidget` (`zcrud_scope.dart`) | Constructeur `ZcrudScope({required child, resolver = ZDependencyResolver.throwing, acl = const ZAllowAllAcl(), key})` ; `of(context)`/`maybeOf(context)` ; `updateShouldNotify` sur identité `resolver`/`acl`. Chaque scope de binding **enveloppe** un `ZcrudScope` en lui passant son resolver manager-backed. |
| `ZDependencyResolver` (abstract, `z_dependency_resolver.dart`) | `T resolve<T>()` ; `static const throwing` (défaut `_ThrowingResolver` → `ZScopeError`). Chaque binding en **fournit une implémentation** déléguant à son conteneur. |
| `ZScopeError extends Error` (`z_scope_error.dart`) | Erreur actionnable levée quand un seam n'est pas fourni. Les resolvers de binding la relancent (ou documentent l'erreur native du locator). |
| `ZFieldListenableBuilder` (`z_field_listenable_builder.dart`) | Widget de slice réutilisé **tel quel** dans le harnais de parité (`ValueListenableBuilder` sur `controller.fieldListenable(name)`). |
| `ZAcl`/`ZAllowAllAcl` (`domain/ports/z_acl.dart`) | Port ACL surfacé par `ZcrudScope` ; défaut permissif ; un binding peut en injecter une concrète (hors périmètre — E7/E8). |

**État des 3 coquilles (E1-2)** : chaque binding est aujourd'hui `sdk: ^3.12.2` (pur-Dart), unique dep `zcrud_core: ^0.0.1`, et n'expose qu'un placeholder (`ZRiverpodApi`/`ZGetApi`/`ZProviderApi` référençant `ZCoreApi.version` pour matérialiser l'arête AD-1). Cette story y **injecte la substance** + le SDK manager.

### Pattern de binding (identique pour les 3) — « adapter, ne pas réimplémenter »

Le contrat AD-6/AD-15 se matérialise par un **wrapper** : le scope du binding monte le conteneur natif du manager PUIS enveloppe un `ZcrudScope` porteur d'un `ZDependencyResolver` manager-backed. Les widgets du cœur ne connaissent QUE `ZcrudScope.of(context)` — ils ne savent pas quel manager est derrière. Schéma :

```
ZcrudGetScope( / ZcrudRiverpodScope( / ZcrudProviderScope(
  child: <arbre applicatif>,
)
  └─ monte le conteneur manager (get_it/Bindings | ProviderScope | ChangeNotifierProvider)
  └─ ZcrudScope(
        resolver: ZGetResolver(...) | ZRiverpodResolver(...) | ZProviderResolver(...),
        acl: ...,
        child: <arbre applicatif>,
     )
```

Le `ZFormController` est **créé/possédé par le conteneur du manager** (factory `get_it` scopée | provider auto-dispose Riverpod | `ChangeNotifierProvider` provider) → son `dispose()` est branché sur le lifecycle idiomatique du manager, jamais dupliqué dans le cœur. **Aucun** binding ne recrée de `ValueNotifier` ni de mécanique de tranche : c'est `ZFormController` qui la porte (AD-2), donc la granularité est mécaniquement identique (preuve = gate de parité).

### SDK manager par binding (versions indicatives — épingler la stable au moment de l'implémentation)

| Binding | SDK manager | Contrainte indicative | Idiome injection / lifecycle |
|---|---|---|---|
| `zcrud_get` (E7/DODLP) | `get` + `get_it` | `get: ^4.7.x`, `get_it: ^8.x` | `getIt<T>()` / `Get.find<T>()` ; `Bindings`/`GetxController` ; dispose `onClose`/`Get.delete`/désenregistrement |
| `zcrud_riverpod` (E8/lex_douane) | `flutter_riverpod` | `flutter_riverpod: ^2.6.x` | `ProviderScope` + `ref`/`ProviderContainer` ; provider auto-dispose + `ref.onDispose` |
| `zcrud_provider` | `provider` | `provider: ^6.1.x` | `ChangeNotifierProvider<ZFormController>` + `context.read<T>()` ; dispose auto par `provider` |

> Étape « latest tech » : confirmer la dernière stable de chaque SDK au moment du `dev-story` (compat Flutter 3.44.x utilisé en CI). `flutter_riverpod` (et pas `riverpod` seul) car c'est le binding **Flutter** de Riverpod ; ne PAS mélanger avec `riverpod_annotation`/codegen (hors périmètre).

### Emplacement du harnais de parité (décision de conception à consigner)

Le gate de parité exige un test **IDENTIQUE et réutilisable** sous 4 configs, réparties sur ≥ 3 packages. Options :

- **Option A (RECOMMANDÉE) — package dev-only `packages/zcrud_binding_conformance/`** : dépend de `zcrud_core` + `flutter_test` ; exporte `runZFormGranularRebuildParitySuite(...)`. Chaque binding l'ajoute en `dev_dependencies` et l'invoque avec son `wrap`. **Avantages** : cœur strictement inchangé (AD-15), zéro duplication, oracle unique. **Coût** : +1 package workspace (`melos list` = 15 ; ajuster tout décompte attendu ; arête `conformance → zcrud_core`, acyclique). Bien noter que ce package est **dev/test-only** (aucun poids runtime pour les apps).
- **Option B — entrypoint `package:zcrud_core/conformance.dart`** dans `zcrud_core` : évite un package, mais **modifie le cœur** et tire `flutter_test` dans sa surface publique → tension avec « cœur inchangé ». **Rejetée** sauf décision contraire de l'orchestrateur.
- **Option C — duplication du fichier** dans chaque binding : viole « IDENTIQUE / réutilisable », dérive garantie. **Rejetée.**

Le readiness §reco #5 suggère par ailleurs une **example-app** comme surface de validation multi-binding : elle n'existe pas encore (aucune story) — ne PAS la créer ici ; le harnais dev-only couvre le besoin de gate exécutable sans attendre l'example-app.

### Impact CI/melos — les bindings deviennent des packages Flutter (point à ne pas rater)

Comme en E2-7 pour `zcrud_core` : dès qu'un package déclare `flutter: {sdk: flutter}`, `dart test` y refuse de tourner. **Bonne nouvelle** : les scripts melos routent **déjà** par filtre (`test:flutter = melos exec --flutter --dir-exists test -- flutter test` ; `test:dart = --no-flutter … dart test` ; `test = test:dart && test:flutter`). Les 3 bindings (+ conformance) rejoignent automatiquement le lot `--flutter`. **Donc AUCUNE édition des scripts** → `gate_melos_divergence.dart` (M-1) reste vert sans réplique. Vérifier seulement que `melos exec --flutter` sélectionne bien les nouveaux packages et `--no-flutter` les purs-Dart restants. `ci.yml` étape « Test » = `dart run melos run test` (inchangé ; Flutter déjà installé via subosito).

### Graphe & pureté (AD-1/AD-6/AD-15)

- `graph_proof.py` ne compte que les arêtes `zcrud_*` (`EDGE = ^\s+(zcrud_[a-z_]+):`). Les SDK manager n'en sont pas → `CORE OUT=0` **inchangé**. Les arêtes `binding → zcrud_core` existent depuis E1-2. **Interdiction absolue** : arête `zcrud_core → binding` (cœur ne dépend jamais d'un satellite) et `binding → binding`.
- Garde d'isolement d'idiome (AC8) : par binding, un test/grep vérifie qu'aucun idiome d'un AUTRE manager n'apparaît (`zcrud_get` ⇒ pas de `ProviderScope`/`ref`/`context.read` ; `zcrud_riverpod` ⇒ pas de `Get.find`/`context.read` ; `zcrud_provider` ⇒ pas de `Get.find`/`ProviderScope`). Et surtout : **rien** de tout cela dans `zcrud_core` (garde cœur E2-7 déjà en place — la maintenir verte).

### Conventions de code (canonique §5, cohérence E2-1/E2-2/E2-7)

- Types publics **préfixés `Z`** ; fichiers `snake_case` sous `lib/src/presentation/` ; API via barrel ; `directives_ordering` (ordre alpha des exports).
- `analysis_options` hérité (`include: ../../analysis_options.yaml`) ; `public_member_api_docs` satisfait (docstrings sur tout public).
- Tests des bindings : **`flutter_test`** (`testWidgets`/`WidgetTester`). Pas de `Equatable` ; `freezed`/`@JsonSerializable` non requis (aucun modèle sérialisé ici ; 0 `.g.dart`).
- Pas de secret, pas de style codé en dur, pas de `badCertificateCallback` (AD-12) — sans objet ici mais gardé à l'esprit.

### Emplacements décidés (par binding, sous `packages/<binding>/lib/src/presentation/`)

| Binding | Resolver | Scope widget |
|---|---|---|
| `zcrud_get` | `z_get_resolver.dart` (`ZGetResolver`) | `zcrud_get_scope.dart` (`ZcrudGetScope`) |
| `zcrud_riverpod` | `z_riverpod_resolver.dart` (`ZRiverpodResolver`) | `zcrud_riverpod_scope.dart` (`ZcrudRiverpodScope`) |
| `zcrud_provider` | `z_provider_resolver.dart` (`ZProviderResolver`) | `zcrud_provider_scope.dart` (`ZcrudProviderScope`) |
| (dev-only, si Option A) `zcrud_binding_conformance` | — | `lib/src/z_form_parity_suite.dart` (`runZFormGranularRebuildParitySuite`) |

### Source tree à toucher

```
packages/zcrud_get/
  pubspec.yaml                                  # UPDATE : + flutter/flutter_test + get/get_it ; 0 autre zcrud_*/backend
  lib/zcrud_get.dart                            # UPDATE : exporte ZGetResolver + ZcrudGetScope
  lib/src/presentation/z_get_resolver.dart      # NEW
  lib/src/presentation/zcrud_get_scope.dart     # NEW
  test/presentation/*                           # NEW (flutter_test) + invocation gate parité
packages/zcrud_riverpod/  … (symétrique : ZRiverpodResolver / ZcrudRiverpodScope)
packages/zcrud_provider/  … (symétrique : ZProviderResolver / ZcrudProviderScope)
packages/zcrud_binding_conformance/             # NEW (Option A, dev-only) — harnais de parité partagé
  pubspec.yaml                                  # zcrud_core + flutter_test
  lib/zcrud_binding_conformance.dart            # barrel
  lib/src/z_form_parity_suite.dart              # runZFormGranularRebuildParitySuite(...)
melos.yaml / pubspec.yaml                        # scripts test:* INCHANGÉS (filtre --flutter existant) ; glob packages/* couvre le nouveau pkg
# packages/zcrud_core/**                         # NON MODIFIÉ (AD-15) — garde de pureté conservée verte
```

### Project Structure Notes

- Chaque binding **gagne** `flutter`/`flutter_test` + son SDK manager, mais **aucun** autre `zcrud_*` ni backend → `CORE OUT=0` préservé ; nouvelles arêtes `binding → zcrud_core` uniquement.
- **Ne rien renommer/déplacer** dans `zcrud_core` ; réutiliser `ZFormController`/`ZcrudScope`/`ZDependencyResolver`/`ZFieldListenableBuilder`/`ZAcl` tels quels.
- Aucun `*.g.dart` (aucun modèle annoté). Ne pas committer de généré.
- Décompte `melos list` : 14 si harnais placé hors nouveau package (Options B/C, non recommandées) ; 15 si `zcrud_binding_conformance` (Option A). Consigner la décision et ajuster toute attente de décompte.

### References

- [Source: epics.md#E2 (Story E2-9)] — « chaque binding fournit création/scoping/dispose du `ZFormController` et résolution des seams selon son idiome ; un même controller + un test de rebuild granulaire identique passe sous les 3 bindings ET sous `ZcrudScope` seul (AD-15). Le cœur reste inchangé pour ajouter un manager. » Ordre intra-épic : E2-1→E2-2→E2-7→E2-9.
- [Source: epics.md#E7 (E7-1)] — binding `zcrud_get` + `ZcrudScope` pour DODLP (GetX/`get_it`, resolver → `getIt<DodlpController>()`, `flutter_riverpod` non ajouté). **Consommateur** de `zcrud_get` → priorité de livraison #1.
- [Source: epics.md#E8 (E8-1)] — binding `zcrud_riverpod` + adaptateur d'entités lex_douane (`ProviderScope`). **Consommateur** de `zcrud_riverpod` → priorité #2.
- [Source: architecture.md#AD-15] — multi-gestionnaire par bindings ; `zcrud_core` n'importe aucun manager ; bindings adaptent injection/lifecycle/scoping SANS réimplémenter la réactivité ; `ZcrudScope` défaut ; « ajouter un manager = un nouveau binding, jamais modifier le cœur » ; « un même controller fonctionne à l'identique sous les quatre ».
- [Source: architecture.md#AD-6] — seams (resolver, permissions, toast, config, l10n, codecs) + cycle de vie des controllers résolus par binding ; interdits `WidgetRef`/`Get.find`/`Get.put`/`Provider.of` dans le cœur ; accès via `ZcrudScope.of(context)` / API du binding.
- [Source: architecture.md#AD-2] — réactivité Flutter-native, rebuilds granulaires ; granularité identique quel que soit le manager (renvoie à AD-15) ; interdits (setState global, closures de build, recréation de `TextEditingController`, ré-injection) ; SM-1.
- [Source: architecture.md#AD-1] — graphe acyclique ; `zcrud_core` ne dépend d'aucun satellite ; tout satellite dépend de `zcrud_core`, jamais l'inverse.
- [Source: implementation-readiness-report-2026-07-09.md §reco #9] — « Scinder E2-9 en une story par binding + une story-gate de parité (prioriser `zcrud_get` pour E7, `zcrud_riverpod` pour E8). » §finding majeur : « E2-9 empaquette 3 bindings … anti-pattern *setup all* ». §reco #5 : example-app comme surface de validation multi-binding (non créée ici).
- [Source: packages/zcrud_core/lib/src/presentation/z_form_controller.dart] — API `ZFormController` réutilisée (tranches, `setValue`, `visibleFields`, `dispose`).
- [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart] — `ZcrudScope(child, resolver, acl)` + `of`/`maybeOf` + `updateShouldNotify` ; chaque scope de binding l'enveloppe avec son resolver.
- [Source: packages/zcrud_core/lib/src/presentation/z_dependency_resolver.dart] — `ZDependencyResolver.resolve<T>()` + `throwing` ; implémenté par chaque binding.
- [Source: packages/zcrud_core/lib/src/presentation/z_field_listenable_builder.dart] — `ZFieldListenableBuilder` réutilisé dans le harnais de parité.
- [Source: packages/zcrud_{get,riverpod,provider}/] — coquilles E1-2 (pur-Dart, dep `zcrud_core`, placeholder `Z*Api`) à remplir.
- [Source: pubspec.yaml#melos + melos.yaml] — scripts `test:dart`/`test:flutter`/`test` routant par filtre `--flutter`/`--no-flutter` (INCHANGÉS) ; gate M-1 `gate_melos_divergence.dart`.
- [Source: scripts/dev/graph_proof.py] — out-degree(zcrud_core) ne compte que les arêtes `zcrud_*` ; SDK manager n'ajoute pas d'arête (`CORE OUT=0` préservé).
- [Source: CLAUDE.md#Réactivité Flutter-native / Key Don'ts] — jamais de manager dans `zcrud_core` ; code manager-spécifique vit dans son package de binding ; multi-gestionnaire par bindings via `ZcrudScope`.

## Stratégie de tests

- **Harnais de parité (`runZFormGranularRebuildParitySuite`, flutter_test)** : oracle unique paramétré par `wrap`. Corps : `ZFormController` à 2 champs (`'a'`/`'b'`), chacun via `ZFieldListenableBuilder` avec compteur ; `ListenableBuilder` structurel (compteur global). Assertions (identiques ×4) : `setValue('a')`×N (N≥20) ⇒ `buildsA`↑, `buildsB` inchangé, `buildsGlobal` inchangé ; variante `EditableText`/`TextField` réel ⇒ focus conservé, curseur non réinitialisé, voisin jamais reconstruit.
- **Par binding (`test/presentation/*`, flutter_test)** :
  - `zcrud_get` : `ZcrudGetScope` monte le conteneur `get_it`/`Bindings` ; un seam enregistré est résolu via `ZcrudScope.of(context).resolver.resolve<Seam>()` ; `ZFormController` disposé au démontage (pas de fuite) ; garde d'isolement d'idiome.
  - `zcrud_riverpod` : `ZcrudRiverpodScope` monte `ProviderScope` ; seam résolu via provider ; controller auto-dispose (`ref.onDispose`) vérifié ; garde d'isolement.
  - `zcrud_provider` : `ZcrudProviderScope` monte `ChangeNotifierProvider` ; seam résolu via `context.read` ; dispose auto par `provider` vérifié ; garde d'isolement.
- **Gate de parité exécuté ×4** : invocations `runZFormGranularRebuildParitySuite(wrap: bare ZcrudScope / ZcrudGetScope / ZcrudRiverpodScope / ZcrudProviderScope)` — toutes vertes, compteurs cohérents (`buildsB==1`, `buildsGlobal==1`).
- **Non-régression cœur & graphe** : `git diff packages/zcrud_core/lib` vide (ou doc justifiée) ; garde de pureté cœur (0 manager, 0 token interdit) verte ; `graph_proof` `CORE OUT=0 OK`/`ACYCLIQUE OK` ; tests E2-1/E2-2/E2-7 verts.
- **Vérif verte finale** : `melos run generate` OK → `melos run analyze` RC=0 → `melos run test` RC=0 (4 packages Flutter via `flutter test`, autres via `dart test`, gate parité vert ×4) → `melos run verify` RC=0 (`CORE OUT=0`, ACYCLIQUE, `gate:melos` inchangé OK) ; `git ls-files '*.g.dart'`=0.

## Découpage recommandé (Readiness §reco #9 — l'orchestrateur décide)

Verdict de taille : **XL**. Si l'orchestrateur retient le split (recommandé), voici la décomposition proposée — dépendances : chaque sous-story dépend d'E2-7 (`done`) ; la story-gate dépend des 3 (ou d'au moins celles qu'on veut certifier) :

| Sous-story | Périmètre | Priorité | Débloque | ACs hérités |
|---|---|---|---|---|
| **E2-9a — `zcrud_get`** | pubspec (flutter+get+get_it) + `ZGetResolver` + `ZcrudGetScope` + lifecycle + tests binding | **#1** | E7-1 (DODLP) | AC 2,3,7,8,9,10,11 |
| **E2-9b — `zcrud_riverpod`** | pubspec (flutter+flutter_riverpod) + `ZRiverpodResolver` + `ZcrudRiverpodScope` + auto-dispose + tests | **#2** | E8-1 (lex_douane) | AC 2,4,7,8,9,10,11 |
| **E2-9c — `zcrud_provider`** | pubspec (flutter+provider) + `ZProviderResolver` + `ZcrudProviderScope` + tests | **#3** | matrice AD-15 | AC 2,5,7,8,9,10,11 |
| **E2-9d — Gate de parité (story-gate)** | package/harnais `zcrud_binding_conformance` + `runZFormGranularRebuildParitySuite` + exécution ×4 (bare + 3 bindings) | **#4 (après 9a-c)** | Preuve SM-1/AD-15 | AC 1,6,10,11 |

Rationale du split : rend chaque binding **complétable incrémentalement** (E7 n'attend que 9a, E8 que 9b), supprime l'anti-pattern « setup all », isole le gate de parité comme certification transverse. **Alternative (story unique)** : livrable dans l'ordre `get → riverpod → provider → gate`, le gate de parité restant le critère de sortie global. Ce fichier reste valable comme parent dans les deux cas.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story). Story unique (non scindée — décision orchestrateur) ; livraison ordonnée `get → riverpod → provider → gate`.

### Debug Log References

Vérif verte rejouée sur disque :
- `melos run generate` RC=0 (no-op : 0 modèle annoté).
- `melos run analyze` RC=0 (SUCCESS, 0 warning — les 3 bindings devenus Flutter analysés proprement).
- `melos run test` RC=0 : `zcrud_core` +96, `zcrud_get` +9, `zcrud_riverpod` +7, `zcrud_provider` +7 ; les 4 packages Flutter routés par `melos exec --flutter` (`zcrud_core`, `zcrud_get`, `zcrud_riverpod`, `zcrud_provider`).
- **Gate de parité vert ×4** (`runZFormGranularRebuildParitySuite`) : `bare ZcrudScope`, `ZcrudGetScope`, `ZcrudRiverpodScope`, `ZcrudProviderScope`. Compteurs identiques sous chaque config : `buildsA = 1 + 25`, `buildsB = 1`, `buildsGlobal = 1` (0 rebuild global), focus/curseur préservés, voisin jamais reconstruit → SM-1 sous chaque manager.
- `melos run verify` RC=0 : `graph_proof` `CORE OUT=0 OK` + `ACYCLIQUE OK` (17 arêtes, 14 nœuds — **inchangé** vs E1-2 : aucune nouvelle arête `zcrud_*`), `gate:melos` OK (13 scripts, M-1), reflectable/secrets/codegen/compat OK.
- `prove_gates.dart` : 22 OK, 0 FAIL.
- `melos list` = **14** (harnais `binding_conformance` exclu via `melos.ignore`). Lockfile racine unique (aucun lock parasite de package).
- Pureté cœur : `packages/zcrud_core/lib` **non modifié** (0 fichier édité) ; grep manager (`WidgetRef`/`Get.find`/`Get.put`/`Provider.of`/imports manager) = **0** violation. `git ls-files '*.g.dart'` = 0.

### Remédiation code-review (post-review, statut reste `review`)

Corrections des 2 findings MEDIUM du `code-review-e2-9.md` + renforcement du gate de parité (fermeture du trou de couverture n°1). `zcrud_core` **toujours strictement inchangé** (AD-15).

- **MEDIUM-1 — resolver provider recréé à chaque build (asymétrie AD-15).**
  - `packages/zcrud_provider/lib/src/presentation/zcrud_provider_scope.dart` : `ZcrudProviderScope` converti `StatelessWidget → StatefulWidget` ; le `ZProviderResolver` est **mémoïsé** (`late final _resolver`, créé une fois) et son `BuildContext` sous les providers lui est (ré)attaché par `attach(inner)` à chaque build du `Builder` — **sans changer son identité**. `ZcrudScope.updateShouldNotify` (comparaison `identical`) renvoie donc `false` → plus aucun sur-rebuild des consommateurs de `ZcrudScope.of`, à parité avec get/riverpod.
  - `packages/zcrud_provider/lib/src/presentation/z_provider_resolver.dart` : `_context` rendu mutable + méthode `attach()` (identité stable) ; garde `ZScopeError` si résolution avant attache. Lifecycle du `ZFormController` inchangé (toujours disposé par `provider`).
  - **Preuve** : `test/presentation/z_provider_parity_test.dart` (config `ZcrudProviderScope`) — la nouvelle assertion `buildsScopeConsumer` échouait AVANT le fix (`Actual: 26` = 1+25, resolver recréé 25×), **passe** après.
- **RENFORCEMENT DU GATE (oracle unique partagé).** `tool/binding_conformance/lib/src/z_form_parity_suite.dart` : ajout d'un 3e `testWidgets` dans `runZFormGranularRebuildParitySuite` + sonde publique `ZScopeConsumerProbe` (consommateur de `ZcrudScope.of(context).resolver`, mémoïsée → ne reconstruit que via la dépendance InheritedWidget). Un `ValueNotifier` force N=25 rebuilds DU SCOPE ; assertion uniforme sous les 4 wraps : `buildsScopeConsumer` reste **1**. Un binding recréant son resolver fait exploser ce compteur (1+25) → **échec** (vérifié sur la version buggée de provider). Aucune duplication : corps figé, seul `wrap` varie.
- **MEDIUM-2 — `ZcrudGetScope.dispose` désenregistrant le controller d'autrui (locator partagé).**
  - `packages/zcrud_get/lib/src/presentation/zcrud_get_scope.dart` : gardes d'**appartenance** `_ownsLocatorRegistration` / `_ownsGetXRegistration` (posées à `true` uniquement quand CE scope a effectivement enregistré). Au `dispose`, `unregister`/`Get.delete` **uniquement** si le scope est propriétaire ET que l'instance courante est `identical` à `_controller` — jamais l'enregistrement d'un autre scope. Doc `locator` mise à jour (règle « slot de type occupé par le 1er scope » + LOW-1 GetX global).
  - **Preuve** : `test/presentation/zcrud_get_scope_test.dart` — nouveau test « locator PARTAGÉ + deux `ZcrudGetScope`, dispose de l'un ⇒ le `ZFormController` de l'autre SURVIT (résoluble) ». Échouerait avec l'ancien code (le dispose du non-propriétaire faisait `unregister` du controller partagé) ; **passe** avec la garde.
- **LOW-1** (bridge `registerInGetX` sur singleton global `Get`) : traité — même garde d'appartenance `_ownsGetXRegistration` + identité avant `Get.delete` ; documenté (« un seul scope actif possède l'enregistrement GetX »).
- **LOW-2** (`binding_conformance` déclare `flutter_test` en dep runtime) : **consigné, aucune action** — le `lib/` du harnais importe `package:flutter_test` (l'API publique EST une suite `testWidgets`/`expect`) ; un dev_dependency ne peut pas être importé depuis `lib/`. Reste dev/test-only (référencé uniquement en `dev_dependencies` des bindings, non transitif pour les apps).

**Vérif verte rejouée (remédiation) :**
- `melos run test` **RC=0** — nb de tests **augmenté** : `zcrud_get` 9→**12** (+2 sonde bare+get, +1 MEDIUM-2), `zcrud_riverpod` 7→**8** (+1 sonde), `zcrud_provider` 7→**8** (+1 sonde), `zcrud_core` **96** (inchangé). **Parité ×4 verte** avec la nouvelle assertion `buildsScopeConsumer` (bare + get + riverpod + provider).
- `melos run analyze` **RC=0** (0 warning) ; `melos run verify` **RC=0** (`CORE OUT=0 OK`, `ACYCLIQUE OK`, 17 arêtes / 14 nœuds, `gate:melos` OK 13 scripts, reflectable/secrets/codegen/compat OK) ; `prove_gates.dart` **22 OK / 0 FAIL** ; `melos list` = **14**.
- Pureté cœur : `packages/zcrud_core/lib` **non touché** ; grep manager = **0** ; `git ls-files '*.g.dart'` = **0**.

### Completion Notes List

**Décisions de conception consignées :**

1. **Emplacement du harnais de parité (Option A adaptée — invariant 14 packages préservé).** Le harnais partagé vit dans **`tool/binding_conformance/`** (dev/test-only, modèle `tool/compat_check`), **HORS du glob melos `packages/**`**, mais **membre du bloc `workspace:`** du root `pubspec.yaml` pour une résolution partagée propre (lockfile racine unique, siblings résolus par version — path dev-dep impossible car les membres sont `resolution: workspace`). Découverte clé : sous pub workspaces, **melos 7 dérive sa liste de packages du bloc `workspace:`, pas du glob `packages:`** → l'appartenance au workspace poussait `melos list` à 15. Corrigé via **`melos.ignore: [binding_conformance]`** (dans `pubspec.yaml` **et** `melos.yaml` ; n'affecte pas M-1 qui ne compare que `scripts:`) → `melos list` = **14**. Nom **sans préfixe `zcrud_`** → la regex `zcrud_*` de `graph_proof.py` n'ajoute **aucune** arête : graphe strictement identique à E1-2 (seules arêtes `binding → zcrud_core`), CORE OUT=0 / ACYCLIQUE préservés. **Aucune duplication**, oracle unique, `zcrud_core` **strictement inchangé** (AD-15). Options B (`package:zcrud_core/conformance.dart`) et C (duplication) rejetées comme prévu.
2. **Placeholders `Z*Api` (ambiguïté #4).** **Conservés** comme marqueurs de version (`ZGetApi`/`ZRiverpodApi`/`ZProviderApi`, référençant `ZCoreApi.version`) ET complétés par la substance réelle. Churn minimal, l'arête AD-1 documentée reste tangible ; les barrels exportent désormais placeholder + resolver + scope.
3. **Écart de borne `resolve<T>()` (non borné) vs SDK manager (`T extends Object`).** `zcrud_get` : `ZGetResolver` délègue à `get_it` via l'escape hatch `type:` (lookup par `Type`), sans passer un `T` non borné à l'API générique. `zcrud_provider` : `Provider.of<T>(context, listen: false)` est non borné → délégation directe (équivalent `context.read<T>()`), `ProviderNotFoundException` convertie en `ZScopeError`. `zcrud_riverpod` : registre `Type → provider` + `container.read` (retourne `Object?`, cast — pas de conflit de borne).
4. **Usage réel du SDK `get`.** `ZGetResolver` = get_it (idiome DODLP `getIt<T>()`). Le SDK réactif `get` est réellement utilisé par `ZcrudGetScope` via le bridge optionnel `registerInGetX` (`Get.put`/`Get.delete`, défaut **faux** pour éviter tout état global partagé dans le gate de parité), couvrant la voie « GetxController host / `Get.delete` » du lifecycle. Testé (avec `Get.reset` en tearDown).
5. **`zcrud_provider` — `lazy: false`** sur le `ChangeNotifierProvider<ZFormController>` : un scope de formulaire possède son controller dès le montage (création/dispose garantis même si le controller n'est jamais lu).

**Versions SDK manager épinglées (Flutter 3.44.4 / Dart 3.12.2, résolues réellement) :** `get: ^4.7.2` + `get_it: ^8.0.3` ; `flutter_riverpod: ^2.6.1` ; `provider: ^6.1.2`.

**Gardes AC8 (isolement d'idiome par binding) :** grep à **bornes de mots** (évite le faux positif `ProviderScope` ⊂ `ZcrudProviderScope`) ; chaque binding prouve l'absence des idiomes des 2 autres managers. Garde de pureté cœur E2-7 maintenue verte.

**Points laissés hors périmètre (conformes à la story) :** intégration app réelle DODLP (E7-1) / adaptateur d'entités lex_douane (E8-1) ; seams l10n/thème concrets (E2-8) ; example-app multi-binding (non créée).

### File List

**NOUVEAUX — harnais de parité dev/test-only (hors `packages/**`) :**
- `tool/binding_conformance/pubspec.yaml`
- `tool/binding_conformance/lib/binding_conformance.dart` (barrel)
- `tool/binding_conformance/lib/src/z_form_parity_suite.dart` (`runZFormGranularRebuildParitySuite`, `ZDisposeSpyFormController`)

**MODIFIÉS — config workspace/melos :**
- `pubspec.yaml` (bloc `workspace:` + `tool/binding_conformance` ; `melos.ignore: [binding_conformance]`)
- `melos.yaml` (miroir `ignore: [binding_conformance]`)

**`zcrud_get` (binding #1) :**
- `packages/zcrud_get/pubspec.yaml` (MODIFIÉ : + flutter/flutter_test + get ^4.7.2 + get_it ^8.0.3 + dev-dep binding_conformance)
- `packages/zcrud_get/lib/zcrud_get.dart` (MODIFIÉ : barrel exporte resolver + scope + placeholder)
- `packages/zcrud_get/lib/src/presentation/z_get_resolver.dart` (NEW)
- `packages/zcrud_get/lib/src/presentation/zcrud_get_scope.dart` (NEW)
- `packages/zcrud_get/test/presentation/zcrud_get_scope_test.dart` (NEW)
- `packages/zcrud_get/test/presentation/z_get_parity_test.dart` (NEW — bare + get)
- `packages/zcrud_get/test/purity/idiom_isolation_test.dart` (NEW)

**`zcrud_riverpod` (binding #2) :**
- `packages/zcrud_riverpod/pubspec.yaml` (MODIFIÉ : + flutter/flutter_test + flutter_riverpod ^2.6.1 + dev-dep binding_conformance)
- `packages/zcrud_riverpod/lib/zcrud_riverpod.dart` (MODIFIÉ : barrel)
- `packages/zcrud_riverpod/lib/src/presentation/z_riverpod_resolver.dart` (NEW)
- `packages/zcrud_riverpod/lib/src/presentation/zcrud_riverpod_scope.dart` (NEW — + `zFormControllerProvider` auto-dispose)
- `packages/zcrud_riverpod/test/presentation/zcrud_riverpod_scope_test.dart` (NEW)
- `packages/zcrud_riverpod/test/presentation/z_riverpod_parity_test.dart` (NEW)
- `packages/zcrud_riverpod/test/purity/idiom_isolation_test.dart` (NEW)

**`zcrud_provider` (binding #3) :**
- `packages/zcrud_provider/pubspec.yaml` (MODIFIÉ : + flutter/flutter_test + provider ^6.1.2 + dev-dep binding_conformance)
- `packages/zcrud_provider/lib/zcrud_provider.dart` (MODIFIÉ : barrel)
- `packages/zcrud_provider/lib/src/presentation/z_provider_resolver.dart` (NEW)
- `packages/zcrud_provider/lib/src/presentation/zcrud_provider_scope.dart` (NEW)
- `packages/zcrud_provider/test/presentation/zcrud_provider_scope_test.dart` (NEW)
- `packages/zcrud_provider/test/presentation/z_provider_parity_test.dart` (NEW)
- `packages/zcrud_provider/test/purity/idiom_isolation_test.dart` (NEW)

**NON MODIFIÉ (AD-15) :** `packages/zcrud_core/**` (0 fichier édité).

## Change Log

| Date | Version | Description | Auteur |
|---|---|---|---|
| 2026-07-09 | 0.1 | Implémentation E2-9 : 3 bindings (`zcrud_get`/`zcrud_riverpod`/`zcrud_provider`) remplis (resolver + scope + lifecycle + tests) ; harnais de parité partagé `tool/binding_conformance` ; gate de parité vert ×4 (SM-1/AD-15) ; cœur inchangé ; `melos list`=14 ; graphe/gates verts. Status → review. | claude-opus-4-8 (dev-story) |
