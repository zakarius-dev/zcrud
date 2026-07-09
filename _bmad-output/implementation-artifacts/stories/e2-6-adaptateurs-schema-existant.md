---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 2.6 : Adaptateurs de schéma existant — `ZModelAdapter` (contrat) / `JsonSerializableAdapter` (lex_douane) / `ReflectableCodec` (DODLP)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur de zcrud intégrant des apps héritées (lex_douane en `@JsonSerializable` code-gen, DODLP en `reflectable`/GetX)**,
je veux **un contrat d'adaptation `ZModelAdapter<T>` (couche `data` pur-Dart de `zcrud_core`) qui prend un modèle EXISTANT — via ses PROPRES fonctions de (dé)sérialisation (`fromJson`/`toJson` d'un `@JsonSerializable`, ou l'introspection d'un modèle `reflectable`) — et l'enregistre au `ZcrudRegistry` (E2-3) SANS le réécrire ni le repasser par le builder zcrud (E2-5), plus deux implémentations : `JsonSerializableAdapter<T>` (dans `zcrud_core/lib/src/data/`, pur-Dart, cible lex_douane) et `ReflectableCodec` (dans `zcrud_get/lib/src/data/codecs/reflectable_codec.dart` — l'UNIQUE chemin allowlisté du gate anti-`reflectable`, cible DODLP)**,
afin que **lex_douane et DODLP exposent leurs entités comme `ZcrudModel` enregistrés (décodables/encodables via `registry.decode/encode(kind, …)`, alimentant repositories E5, formulaire E3, liste E4) SANS second modèle ni double maintenance (FR-11), sans imposer `freezed` ni forcer lex à adopter `reflectable`, en préservant l'acyclicité AD-1 (cœur OUT=0) et en gardant `gate:reflectable` VERT (reflectable confiné au seul chemin allowlisté).**

## Contexte & valeur

**FR-11 — « réutiliser l'existant sans réécrire ».** Canonique §246 : zcrud *« expose des contrats abstraits (`ZEntity`/`ZSyncable`/`ZNode`) + un registre, et laisse chaque app choisir sa techno de génération »*. §21/§7 : *« lex = `json_serializable` code-gen only, reflectable totalement absent ; DODLP repose au contraire sur reflectable/GetX ; zcrud NE DOIT imposer ni freezed ni reflectable »*. E2-6 est le **pont** entre le codegen natif zcrud (E2-5) et ces deux mondes hérités : au lieu d'annoter `@ZcrudModel` puis lancer `build_runner` (ce que fait E2-5), on **enveloppe** la sérialisation que le modèle possède déjà et on l'**enregistre** au même `ZcrudRegistry`.

**Position dans l'épic E2 (cœur + codegen + bindings).** Prérequis **done** :
- **E2-3** (registre & extensibilité) : `ZcrudRegistry` **instanciable** avec `register<T>(kind, {required fromMap, required toMap, List<ZFieldSpec> fieldSpecs = const []})`, `decode/encode(kind, …)`, `codecFor`/`tryCodecFor`, `fieldSpecsFor`/`tryFieldSpecsFor`, collision → `ZDuplicateRegistrationError`, absence → `ZUnregisteredTypeError` (`zcrud_registry.dart`). **C'est la cible d'enregistrement de CETTE story.**
- **E2-5** (générateur build_runner) : a créé la classe runtime `ZFieldSpec` (`z_field_spec.dart`) et câblé le slot `fieldSpecs` du registre. E2-6 **réutilise** `ZFieldSpec` (fourni manuellement, cf. AC5) et **n'invoque pas** le builder.
- **E2-9** (bindings) : `zcrud_get` a déjà acquis le SDK Flutter + `get`/`get_it` et héberge `ZGetResolver`/`ZcrudGetScope`. C'est le package d'accueil de `ReflectableCodec`.

**Chaîne de valeur aval (consommateurs de E2-6) :**
- **E7-2** (`ReflectableCodec` + `ZcrudRegistry` au bootstrap DODLP) : consomme le contrat/impl posé ici, branché sur le **vrai** reflector DODLP + `initializeReflectable()` + init 2 apps Firebase, injecté après `registerServices()`. **E2-6 pose l'adaptateur + le prouve sur un double de réflexion ; E7-2 le câble sur les vrais modèles DODLP** (cf. « Décision livrer-vs-déférer »).
- **E8-1** (binding `zcrud_riverpod` + adaptateur lex_douane) : réutilise `JsonSerializableAdapter` pour exposer les entités `@JsonSerializable` de lex *« sans second modèle »*.
- **E5** (Firestore) : `registry.decode(kind, map)` alimente les repositories quel que soit le mode d'enregistrement (natif E2-5 ou adapté E2-6).

**Pourquoi c'est structurant et non décoratif.** Sans cette story, la seule voie d'entrée au registre est `@ZcrudModel` + `build_runner` (E2-5) — inacceptable pour DODLP (reflectable, pas de listing de modèles) et coûteux/redondant pour lex (modèles `@JsonSerializable` déjà générés). E2-6 rend le `ZcrudRegistry` **agnostique de la provenance de la sérialisation** : natif zcrud, `json_serializable`, ou réflexion — même contrat de sortie (`ZModelCodec` + `fieldSpecs`).

## Périmètre strict de CETTE story (anti-empiètement)

**DANS le périmètre :**
- **`zcrud_core/lib/src/data/`** (NOUVELLE couche `data`, **pur-Dart** — déjà anticipée par `test/purity/domain_purity_test.dart` qui garde `lib/src/data`) :
  - `ZModelAdapter<T>` : le **contrat** d'adaptation (interface abstraite) `existing model → ZcrudRegistry`.
  - `JsonSerializableAdapter<T>` : implémentation concrète prenant les `T Function(Map) fromJson` / `Map Function(T) toJson` d'un modèle `@JsonSerializable` existant + option de tolérance défensive (AD-10) + `fieldSpecs` fournis manuellement.
  - Export via le barrel `zcrud_core.dart` (et, si pertinent pour E3/E5, un sous-barrel `data.dart` — à décider, cf. Ambiguïtés).
- **`zcrud_get/lib/src/data/codecs/reflectable_codec.dart`** (**exactement** ce chemin — allowlist du gate) :
  - `ReflectableCodec` : adapte un modèle `reflectable` DODLP en `ZModelAdapter`/enregistrement, via une **capacité de réflexion injectée** (cf. AC4). SEUL fichier du dépôt autorisé à `import 'package:reflectable/reflectable.dart'`.
  - Export via le barrel `zcrud_get.dart`.
- **Modèles de test** (test-only, ne créent AUCUN 15e package produit) :
  - un `@JsonSerializable` de test (dans `zcrud_core/test/`, avec son `.g.dart` json_serializable généré ou un `fromJson`/`toJson` écrits à la main pour rester hermétique — cf. Dev Notes) ;
  - un double/fake de capacité de réflexion (dans `zcrud_get/test/`) prouvant `ReflectableCodec` **sans** générer de `*.reflectable.dart` (cf. Décision & AC6).

**HORS périmètre (empiètement interdit) :**
- ❌ **Bootstrap DODLP réel** : vrai reflector DODLP, `initializeReflectable()`, init 2 apps Firebase, injection après `registerServices()`, enregistrement des vraies entités DODLP → **E7-2**. E2-6 livre l'adaptateur + un test sur double de réflexion ; **pas** le câblage app.
- ❌ **Adaptateur d'entités lex_douane réelles** (`ProviderScope`/`zcrud_riverpod`, entités `Étude` concrètes) → **E8-1**. E2-6 livre `JsonSerializableAdapter` générique + un modèle `@JsonSerializable` de **test**.
- ❌ **`ZCodec` rich-text (Delta/Markdown/HTML)** de l'AD-7 → **E6-2**. Homonyme trompeur : l'AD-7 `ZCodec` (dé)sérialise du **contenu rich-text**, PAS des modèles. CETTE story adapte des **modèles** ; d'où le nom `ZModelAdapter` (cf. Ambiguïté #1). Ne pas créer de type `ZCodec` ici.
- ❌ **Modification du builder E2-5** ou du gate E1-3 (`scripts/ci/gate_reflectable.dart`). Le gate reste tel quel ; la story **s'y conforme** (chemin allowlisté + zéro `*.reflectable.dart` sous `packages/`). Toucher au gate = régression de périmètre.
- ❌ **Génération de `ZFieldSpec` par introspection** : E2-6 accepte des `fieldSpecs` **fournis** (défaut `const []`) ; il ne les infère pas depuis le modèle hérité (FR-11 vise la réutilisation de la *sérialisation*, pas la reconstruction du schéma de formulaire).
- ❌ Toute écriture de `sprint-status.yaml` par le dev (l'orchestrateur gère les transitions).

## Acceptance Criteria

1. **Contrat `ZModelAdapter<T>` (pur-Dart, `zcrud_core/lib/src/data/`).** Une interface abstraite exposant au minimum : `String get kind`, `T fromMap(Map<String, dynamic> map)`, `Map<String, dynamic> toMap(T value)`, `List<ZFieldSpec> get fieldSpecs`, et `void registerInto(ZcrudRegistry registry)` qui appelle `registry.register<T>(kind, fromMap: fromMap, toMap: toMap, fieldSpecs: fieldSpecs)`. La couche `lib/src/data/` **n'importe ni Flutter, ni Firebase, ni un gestionnaire d'état** (`domain_purity_test.dart` reste vert : le test garde déjà `lib/src/data`). Aucun `import 'package:reflectable/'` dans `zcrud_core` (`gate:reflectable` inchangé). AD-1 préservé : `zcrud_core` OUT=0.

2. **`JsonSerializableAdapter<T>` expose un modèle `@JsonSerializable` existant SANS le repasser par le builder zcrud.** L'adaptateur se construit à partir des fonctions que le modèle possède DÉJÀ : `required T Function(Map<String, dynamic>) fromJson`, `required Map<String, dynamic> Function(T) toJson`, `required String kind`, et `List<ZFieldSpec> fieldSpecs = const []` (fournis, pas inférés). `registerInto(registry)` rend le modèle décodable/encodable via `registry.decode/encode(kind, …)`. **Aucune annotation `@ZcrudModel`, aucun `build_runner` zcrud, aucun `.g.dart` zcrud** n'est requis pour ce modèle (seul son propre `.g.dart` json_serializable, s'il existe, est utilisé — via les fonctions injectées).

3. **`freezed` non requis ; `reflectable` non imposé à lex.** `JsonSerializableAdapter` fonctionne sur un modèle `final` + `const` + `fromJson`/`toJson` **sans** dépendance `freezed` ni `reflectable`. Aucune dépendance `freezed`/`reflectable` ajoutée à `zcrud_core`. (AD-3 : freezed non imposé ; canonique §21/§252.)

4. **`ReflectableCodec` (DODLP) vit EXACTEMENT au chemin allowlisté et réflexion INJECTÉE.** Le fichier est `packages/zcrud_get/lib/src/data/codecs/reflectable_codec.dart` (suffixe exact de l'allowlist `gate_reflectable.dart`). Il `import 'package:reflectable/reflectable.dart'` (toléré à ce seul chemin) et adapte un modèle `reflectable` en `ZModelAdapter`/enregistrement `ZcrudRegistry`. La **capacité de réflexion** (reflector + type/kind) est **injectée** (paramètre de construction / port fin `ZReflectionCapability` ou équivalent typedef) — de sorte que la logique d'adaptation soit **testable sans exécuter `initializeReflectable()`**. `ReflectableCodec` implémente ou produit un `ZModelAdapter` et le `registerInto(registry)`.

5. **`fieldSpecs` fournis, pas inférés (FR-11 borné à la sérialisation).** Les deux adaptateurs acceptent `List<ZFieldSpec>` (défaut `const []`) et le transmettent tel quel à `registry.register`. Enregistrer sans schéma est licite : `registry.fieldSpecsFor(kind)` renvoie alors `const []` (et non un throw), `registry.decode/encode` fonctionnent. Aucun adaptateur ne tente de reconstruire un `ZFieldSpec` depuis le modèle hérité.

6. **Preuves de round-trip via le registre, SANS builder zcrud, gate VERT.** Tests exécutables réels :
   - **lex path** : un modèle `@JsonSerializable` de test (`final`, `fromJson`/`toJson`) est adapté via `JsonSerializableAdapter`, `registerInto(registry)`, puis `registry.decode(kind, registry.encode(kind, x)) == x` (round-trip) ; `registry.codecFor("kind-absent")` → `ZUnregisteredTypeError` ; double `registerInto` du même `kind` → `ZDuplicateRegistrationError` (contrat E2-3 préservé). **Aucun `@ZcrudModel`/build_runner zcrud dans ce test.**
   - **DODLP path** : `ReflectableCodec` construit avec un **double/fake** de capacité de réflexion (pas de `*.reflectable.dart` généré), `registerInto(registry)`, round-trip `decode(encode(x)) == x`. Prouve la logique d'adaptation reflectable **sans** violer le gate.
   - **gate** : `dart run scripts/ci/gate_reflectable.dart` → **exit 0** (`gate:reflectable OK`) sur l'arbre après la story : le SEUL fichier référençant `package:reflectable/` est `zcrud_get/lib/src/data/codecs/reflectable_codec.dart` ; **aucun** `*.reflectable.dart` généré n'existe sous `packages/` (sinon il serait scanné et rejeté — cf. Dev Notes « Piège du fichier généré reflectable »).

7. **Désérialisation défensive préservée où pertinent (AD-10).** `JsonSerializableAdapter` offre un mode/option de **tolérance** : une map corrompue/tronquée ne fait pas remonter une exception de parsing brute au-delà de la frontière d'adaptation quand ce mode est activé (option `defensive`/wrapper `fromMapSafe` retournant un défaut documenté ou propageant une `ZFailure`/`null` selon le contrat retenu) — **sans jamais corrompre silencieusement** des données valides. Le comportement par défaut (strict, délègue au `fromJson` du modèle) et le mode défensif sont **documentés** et **testés** (map valide → round-trip ; map corrompue en mode défensif → pas de crash du parent).

8. **Barrels & API publique.** `ZModelAdapter` + `JsonSerializableAdapter` exportés par `zcrud_core.dart` (barrel `lib/<pkg>.dart`, convention AD/Consistency) ; `ReflectableCodec` exporté par `zcrud_get.dart`. Docstrings en français précisant : ce que fait l'adaptateur, l'origine (FR-11), le fait qu'il ne repasse PAS par le builder, et pour `ReflectableCodec` la note « seule exception `reflectable` autorisée (AD-3), allowlist gate ».

9. **Vérif verte de bout en bout.** `melos run generate` OK, `dart analyze`/`flutter analyze` RC=0 sur `zcrud_core` et `zcrud_get`, `flutter test`/`dart test` RC=0 (nouveaux tests inclus), `dart run scripts/ci/gate_reflectable.dart` exit 0, `graph_proof` (AD-1, cœur OUT=0) inchangé, `gate:codegen`/`gate:compat` inchangés. Aucune régression des tests E2-3/E2-5/E2-9.

## Tasks / Subtasks

- [x] **Task 1 — Contrat `ZModelAdapter<T>` dans `zcrud_core/lib/src/data/` (AC: 1, 5)**
  - [x] Créer `packages/zcrud_core/lib/src/data/adapters/z_model_adapter.dart` : interface abstraite (`kind`, `fromMap`, `toMap`, `fieldSpecs`, `registerInto(ZcrudRegistry)`), pur-Dart, docstrings FR (origine FR-11).
  - [x] `registerInto` délègue à `registry.register<T>(kind, fromMap:, toMap:, fieldSpecs:)` (signature E2-3 intacte).
  - [x] Export via `zcrud_core.dart` (**Ambiguïté #2 tranchée** : PAS de sous-barrel `data.dart` — exports directs par fichier depuis `zcrud_core.dart`, cohérent avec la convention du barrel existant ; `data.dart` aurait dupliqué la surface sans bénéfice).
- [x] **Task 2 — `JsonSerializableAdapter<T>` (lex_douane) (AC: 2, 3, 5, 7)**
  - [x] `packages/zcrud_core/lib/src/data/adapters/json_serializable_adapter.dart` : construit depuis `fromJson`/`toJson`/`kind`/`fieldSpecs` injectés ; implémente `ZModelAdapter<T>`.
  - [x] Mode défensif (AD-10) : `fromMapSafe → T?` (null sur map corrompue), **hérité du contrat** `ZModelAdapter` (réutilisé aussi par `ReflectableCodec`) ; défaut strict via `fromMap`. **Ambiguïté #4 tranchée** : aligné sur E2-5 `fromJsonSafe → null` ; le registre enregistre la voie stricte (décodage non-null par contrat E2-3), `fromMapSafe` est l'entrée tolérante côté frontière (E5).
  - [x] Docstrings FR ; zéro dépendance `freezed`/`reflectable` ajoutée à `zcrud_core`.
- [x] **Task 3 — `ReflectableCodec` (DODLP) au chemin allowlisté (AC: 4, 8)**
  - [x] `packages/zcrud_get/lib/src/data/codecs/reflectable_codec.dart` (chemin EXACT) : `import 'package:reflectable/reflectable.dart'` ; réflexion **injectée** via le port fin `ZReflectionCapability<T>` ; `ReflectableCodec` étend `ZModelAdapter` + `registerInto`. Helper prod `ReflectableMirrorCapability` (référence `Reflectable`/`InstanceMirror`, câblage réel déféré E7-2).
  - [x] `reflectable: ^5.2.3` ajouté aux `dependencies` de `zcrud_get` uniquement (5.x requis pour compat `build ^3.0.0` du `zcrud_generator` ; 4.x épinglait `build ^2.x` → conflit). `graph_proof` : CORE OUT=0, 14 nœuds, 17 arêtes (inchangé — reflectable non `zcrud_*`).
  - [x] Export via `zcrud_get.dart` ; docstring FR « seule exception AD-3, allowlist gate ».
- [x] **Task 4 — Tests lex path (AC: 2, 3, 5, 6, 7)**
  - [x] Modèle `@JsonSerializable` de test `DummyEtude` dans `zcrud_core/test/data/adapters/` (**Ambiguïté #3 tranchée** : `fromJson`/`toJson` **écrits à la main**, HERMÉTIQUE — zéro dep `json_serializable`/`build_runner` ajoutée au cœur).
  - [x] `JsonSerializableAdapter` → `registerInto` → round-trip `decode(encode(x))==x` ; `codecFor(absent)`→throw ; double register→`ZDuplicateRegistrationError` ; `fieldSpecsFor` → `const []` + variante avec specs.
  - [x] Mode défensif : map valide → même résultat ; map corrompue/mauvais type → `null` (pas de crash parent) ; strict `fromMap` lève.
- [x] **Task 5 — Tests DODLP path + preuve gate (AC: 4, 6)**
  - [x] Fake `FakeDossierReflection` (double du port, **sans** import `reflectable`) dans `zcrud_get/test/data/codecs/` — **aucun** `*.reflectable.dart` sous `packages/` (garde in-suite).
  - [x] `ReflectableCodec` + fake → `registerInto` → round-trip `decode(encode(x))==x` ; double register → throw ; `fromMapSafe` défensif.
  - [x] `dart run scripts/ci/gate_reflectable.dart` → **exit 0**. Le scan « seul chemin reflectable = allowlisté » est **délégué au gate réel** (le ré-implémenter in-suite réintroduisait le littéral `package:reflectable/` dans un fichier de test non allowlisté → gate ROUGE ; piège évité).
- [x] **Task 6 — Vérif verte + barrels + non-régression (AC: 8, 9)**
  - [x] Exports barrels ; `melos run generate` OK, `analyze` RC=0 (14 pkgs, 0 issue), `test` RC=0 (241 tests), `gate:reflectable` exit 0, `verify`/`graph_proof`/`prove_gates`(22 OK)/`gate:compat`/`gate:codegen` inchangés, tests E2-3/E2-5/E2-9 verts.

## Dev Notes

### Cible d'enregistrement (E2-3) — API exacte à appeler
`ZcrudRegistry` (`packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart`) est **instanciable** (pas un singleton statique). Signature à utiliser telle quelle (NE PAS la modifier — c'est un contrat E2-3/E2-5 gelé) :
```dart
void register<T extends Object>(
  String kind, {
  required T Function(Map<String, dynamic> map) fromMap,
  required Map<String, dynamic> Function(T value) toMap,
  List<ZFieldSpec> fieldSpecs = const <ZFieldSpec>[],
});
// + decode(kind, map) / encode(kind, value) / codecFor / tryCodecFor
//   / fieldSpecsFor / tryFieldSpecsFor / isRegistered / kinds
```
Collision de `kind` → `ZDuplicateRegistrationError` ; `kind` absent → `ZUnregisteredTypeError` (`z_registry_error.dart`). `T extends Object` : `fromMap` doit produire un non-null (les adaptateurs enveloppent des modèles non-null).

### Nommage — pourquoi `ZModelAdapter` et pas `ZCodec` (Ambiguïté #1, TRANCHÉE)
Le libellé de la story E2-6 (epics.md:68) écrit « `ZCodec`/`ReflectableCodec`/`JsonSerializableAdapter` », mais **`ZCodec` est déjà réservé** par **AD-7** au codec **rich-text pluggable** (Delta/Markdown/HTML, E6-2) et le domaine porte déjà `ZModelCodec` (le couple `(fromMap,toMap)` stocké par le registre) et `ZValueCodec` (registres ouverts). Introduire un 3e `ZCodec` de modèles créerait une collision/confusion. **Décision : nommer le contrat `ZModelAdapter<T>`** (adaptation d'un **modèle** hérité vers le registre), distinct du `ZCodec` rich-text. `ReflectableCodec`/`JsonSerializableAdapter` conservent les noms du backlog (ce sont des *adapters* concrets). À confirmer implicitement par le dev ; si un nom `ZCodec` de modèle est exigé plus tard, il devra être désambiguïsé du `ZCodec` AD-7.

### Placement — pourquoi `data`, pas `domain` ni `zcrud_generator`
- `ZModelAdapter` + `JsonSerializableAdapter` sont de la **plomberie de (dé)sérialisation** (couche `data`), pas des contrats de domaine ni de la génération de code. Ils vont dans `zcrud_core/lib/src/data/` — couche **pur-Dart** déjà anticipée par `domain_purity_test.dart` (`_pureDirs()` inclut `lib/src/data`). **PAS** dans `zcrud_generator` : celui-ci est un `dev_dependency` build-time (analyzer/source_gen) ; les adaptateurs sont du **runtime** consommé par les apps. Les mettre dans le générateur violerait AD-1 (le runtime ne dépend pas de build_runner).
- `ReflectableCodec` : DODLP-spécifique + `reflectable` → **obligatoirement** `zcrud_get` (binding DODLP), au chemin allowlisté. Jamais dans `zcrud_core` (`_neverExemptPackages = ['zcrud_core']` dans le gate : le cœur n'est JAMAIS exempté, même un fichier nommé `reflectable_codec.dart`).

### Piège du fichier généré `*.reflectable.dart` (CRITIQUE pour AC6/le gate)
`gate_reflectable.dart` scanne `packages/*/{lib,bin,tool,test,example}/**.dart` et rejette tout `import 'package:reflectable/'` **hors** le suffixe exact `zcrud_get/lib/src/data/codecs/reflectable_codec.dart`. Or un **vrai** modèle `reflectable` annoté exige `initializeReflectable()` issu d'un fichier généré `*.reflectable.dart` (par le builder reflectable) — ce fichier **importe** `package:reflectable/` et, placé sous `packages/zcrud_get/test/…`, serait **scanné et REJETÉ** → gate ROUGE. **Conséquence de conception** : on n'introduit **PAS** de modèle reflectable réel + génération sous `packages/` dans E2-6. On **injecte** la capacité de réflexion (port fin) et on teste `ReflectableCodec` avec un **double/fake** — zéro `*.reflectable.dart` sous `packages/`, gate VERT. Le vrai modèle reflectable + `initializeReflectable()` vit dans l'app **DODLP** (E7-2), **hors** de la racine `packages/` scannée par le gate — c'est le placement naturel et non conflictuel.

### Décision livrer-vs-déférer le `ReflectableCodec` concret (E2-6 vs E7-2) — TRANCHÉE
- **E2-6 (ici)** : livre le contrat `ZModelAdapter`, `JsonSerializableAdapter` **complet + testé** (lex path), et `ReflectableCodec` **complet en tant qu'adaptateur** au chemin allowlisté, **prouvé sur un double de réflexion injecté** (round-trip via registre, gate vert). La réflexion est un **seam injecté** (AD-6).
- **E7-2 (déféré)** : câble `ReflectableCodec` sur le **vrai** reflector DODLP + `initializeReflectable()`, injecte le `ZcrudRegistry` peuplé après `registerServices()`, préserve l'init des 2 apps Firebase, enregistre les vraies entités DODLP « sans les lister ». Ce câblage app-side vit dans DODLP (hors `packages/`), ce qui **est la raison** pour laquelle le vrai reflectable ne peut pas être exercé dans E2-6 sans casser le gate. Le contrat/adaptateur est donc **prêt et prouvé** ici ; seul le branchement sur les vrais modèles est déféré.

### Désérialisation défensive (AD-10) — portée dans E2-6
Le `fromJson` d'un `@JsonSerializable` peut lever sur une map corrompue. FR-11 ne veut pas réécrire le modèle, mais AD-10 exige qu'un document corrompu ne fasse pas échouer le parent « où pertinent ». `JsonSerializableAdapter` expose donc un **mode défensif optionnel** (ex. `JsonSerializableAdapter.defensive(...)` ou `bool defensive`) qui capture l'échec de parsing et retourne un défaut documenté / `null` / propage une `ZFailure` (choisir un contrat cohérent avec E2-5 `fromJsonSafe → null` et le documenter). Le mode strict par défaut délègue tel quel. **Ne jamais** corrompre silencieusement une map valide.

### Où vit le modèle `@JsonSerializable` de test
Test-only, dans `zcrud_core/test/` (PAS de 15e package). Deux options acceptables : (a) un vrai `@JsonSerializable` avec `part '*.g.dart'` généré par `melos run generate` (prouve le cas réel lex, mais ajoute `json_serializable`/`json_annotation` en `dev_dependencies` de `zcrud_core` — vérifier `gate:compat`) ; (b) une classe `final` avec `fromJson`/`toJson` **écrits à la main** mimant la sortie `json_serializable` (hermétique, zéro dépendance de génération). **Recommandation : (b)** pour l'hermétisme et éviter d'alourdir `zcrud_core` — ce qui compte pour l'AC est que l'adaptateur consomme des `fromJson`/`toJson` **fournis**, indépendants du builder zcrud. Documenter le choix retenu.

### Invariants AD applicables (rappel non-négociable)
- **AD-1** : `zcrud_core` OUT=0 (aucune arête vers un autre `zcrud_*` ni backend) ; `zcrud_get` OUT runtime = 1 (→ cœur). `reflectable`/`json_serializable` ne sont pas des `zcrud_*` → non comptés par `graph_proof.py`. Vérifier le graphe vert.
- **AD-3** : reflectable BANNI partout SAUF `ReflectableCodec` au chemin allowlisté ; freezed non imposé ; type non enregistré → throw (déjà garanti par E2-3).
- **AD-4** : extensibilité par registre (`register(kind, …)`) — E2-6 est un producteur d'entrées de registre, pas un nouveau mécanisme.
- **AD-6** : la capacité de réflexion de `ReflectableCodec` est un **seam injecté**, pas un `Get.find` en dur.
- **AD-10** : désérialisation défensive préservée (mode défensif de `JsonSerializableAdapter`).

### Project Structure Notes
- Nouveaux fichiers :
  - `packages/zcrud_core/lib/src/data/adapters/z_model_adapter.dart` (NEW)
  - `packages/zcrud_core/lib/src/data/adapters/json_serializable_adapter.dart` (NEW)
  - `packages/zcrud_get/lib/src/data/codecs/reflectable_codec.dart` (NEW, chemin allowlisté)
  - tests sous `zcrud_core/test/` et `zcrud_get/test/`
- Fichiers modifiés : `packages/zcrud_core/lib/zcrud_core.dart` (exports), `packages/zcrud_get/lib/zcrud_get.dart` (export), `packages/zcrud_get/pubspec.yaml` (+`reflectable`).
- Conflits/variances : première couche `data` de `zcrud_core` (jusqu'ici seuls `domain`/`presentation` existaient) — conforme à l'archi hexagonale et déjà anticipée par la garde de pureté. RAS.

### References
- [Source: epics.md#E2 (Story E2-6)] — AC : expose une entité `@JsonSerializable` (lex) ou reflectable (DODLP) comme `ZcrudModel` sans réécrire ; freezed non requis (FR-11).
- [Source: epics.md#E7 (Story E7-2)] — `ReflectableCodec` + `ZcrudRegistry` au bootstrap DODLP (déféré : vrai reflector + Firebase + registerServices).
- [Source: epics.md#E8 (Story E8-1)] — binding `zcrud_riverpod` + adaptateur d'entités lex via `ZCodec`, sans second modèle.
- [Source: architecture.md#AD-3] — codegen source de vérité ; reflectable banni SAUF `ReflectableCodec` DODLP ; freezed non imposé ; type non enregistré → throw.
- [Source: architecture.md#AD-4] — extensibilité par registre `register(kind, fromJson, toJson)`.
- [Source: architecture.md#AD-6] — injection/lifecycle par seams (réflexion injectée, pas `Get.find` en dur).
- [Source: architecture.md#AD-1] — direction de dépendance acyclique, cœur OUT=0.
- [Source: architecture.md#AD-10] — désérialisation défensive (`fromJsonSafe → null`, jamais d'échec du parent).
- [Source: docs/canonical-schema.md §21, §246, §252, §260] — lex = json_serializable code-gen only, reflectable absent ; DODLP = reflectable/GetX ; ni freezed ni reflectable imposés ; contrats abstraits + registre ; `ZCodec` nommés (rich-text/double-wire, distinct des adaptateurs de modèle).
- [Source: packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart] — API `register`/`decode`/`encode`/`fieldSpecsFor` cible.
- [Source: scripts/ci/gate_reflectable.dart] — allowlist EXACTE `zcrud_get/lib/src/data/codecs/reflectable_codec.dart` ; `_neverExemptPackages=['zcrud_core']` ; scan `{lib,bin,tool,test,example}`.
- [Source: packages/zcrud_core/test/purity/domain_purity_test.dart] — `lib/src/data` gardé pur-Dart.
- [Source: e2-3-registre-extensibilite.md] — contrat registre instanciable + erreurs.
- [Source: e2-5-generateur-build-runner.md] — `ZFieldSpec` runtime + slot `fieldSpecs` (E2-6 réutilise, n'invoque pas le builder).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD `bmad-dev-story`, effort high).

### Debug Log References

- Résolution `reflectable ^4.0.5` → conflit `build`: `zcrud_generator` exige `build ^3.0.0`, reflectable 3.x–4.0.x épingle `build ^2.x`. Corrigé en `reflectable ^5.2.3` (série 5.x compatible `build ^3`).
- `flutter test zcrud_get` (1er run) : échec unique du test de confinement in-suite — le test **contenait** le littéral `package:reflectable/` (scan re-implémenté), ce qui (a) le faisait s'auto-détecter comme offender et (b) aurait fait ROUGIR le vrai `gate_reflectable.dart` (scan des `test/`). Corrigé en supprimant le scan in-suite et en s'appuyant sur le gate réel (AC6) ; littéral désormais présent **uniquement** dans le fichier allowlisté.
- Lints `prefer_initializing_formals` / `directives_ordering` : le monorepo applique **zéro issue** (12 autres pkgs « No issues found »). Corrigés : formelles initialisantes privées (`this._fromJson`, `this._toJson`, `this._capability`, `this._reflector`…), et exports `src/data/` remontés **avant** `src/domain/` dans le barrel (ordre alphabétique).

### Completion Notes List

- **Contrat `ZModelAdapter<T extends Object>`** (couche `data` PUR-DART du cœur) : `kind`/`fromMap`/`toMap`/`fieldSpecs` + `registerInto(registry)` (délègue à `register<T>`, signature E2-3 gelée) + `fromMapSafe → T?` défensif (AD-10, try/catch → null), hérité par les deux impls.
- **`JsonSerializableAdapter<T>`** : enveloppe les `fromJson`/`toJson` d'un modèle `@JsonSerializable` existant sans builder zcrud ni `.g.dart` zcrud ; zéro dep `freezed`/`reflectable` au cœur.
- **`ReflectableCodec<T>`** (chemin allowlisté `zcrud_get/lib/src/data/codecs/reflectable_codec.dart`) : adapte un modèle DODLP via le port injecté `ZReflectionCapability` (seam AD-6), testable sans `initializeReflectable()`. `ReflectableMirrorCapability` référence `Reflectable`/`InstanceMirror` (câblage réel déféré E7-2). `reflectable` ajouté à `zcrud_get` uniquement.
- **Décisions d'ambiguïté** : #2 → pas de sous-barrel `data.dart` (exports directs) ; #3 → modèle `@JsonSerializable` de test hermétique (fromJson/toJson manuels, cœur sans json_serializable) + double de réflexion (pas de `.reflectable.dart` sous `packages/`) ; #4 → mode défensif `fromMapSafe → null` (aligné E2-5), voie stricte enregistrée.
- **Preuves** : round-trip lex + DODLP `decode(encode(x))==x` via le REGISTRE ; `codecFor(absent)`→`ZUnregisteredTypeError` ; double register→`ZDuplicateRegistrationError` ; `fieldSpecsFor`→`const []`. `gate:reflectable` exit 0 (seul chemin reflectable = allowlisté ; 0 `.reflectable.dart` sous `packages/`). Cœur : 0 flutter/reflectable/json_serializable ; `domain_purity_test` vert (couvre `lib/src/data`). AD-1 : CORE OUT=0, 14 nœuds, 17 arêtes (inchangé). `melos list`=14.
- **Vérif verte rejouée** : `generate` OK ; `analyze` RC=0 (0 issue/14 pkgs) ; `test` RC=0, **241 tests** (dart 38 : annotations 8 + generator 30 ; flutter 203 : core 170 + get 17 + provider 8 + riverpod 8) ; `verify` RC=0 ; `prove_gates` 22 OK/0 FAIL ; `graph_proof` RC=0.

### File List

**Créés :**
- `packages/zcrud_core/lib/src/data/adapters/z_model_adapter.dart`
- `packages/zcrud_core/lib/src/data/adapters/json_serializable_adapter.dart`
- `packages/zcrud_get/lib/src/data/codecs/reflectable_codec.dart`
- `packages/zcrud_core/test/data/adapters/json_serializable_adapter_test.dart`
- `packages/zcrud_get/test/data/codecs/reflectable_codec_test.dart`

**Modifiés :**
- `packages/zcrud_core/lib/zcrud_core.dart` (exports `ZModelAdapter` + `JsonSerializableAdapter`)
- `packages/zcrud_get/lib/zcrud_get.dart` (export `ReflectableCodec` + port de réflexion)
- `packages/zcrud_get/pubspec.yaml` (+`reflectable: ^5.2.3`, dep de `zcrud_get` uniquement)

## Change Log

- 2026-07-09 — E2-6 implémentée (dev-story) : contrat `ZModelAdapter` + `JsonSerializableAdapter` (cœur, data pur-Dart) + `ReflectableCodec` (zcrud_get, chemin allowlisté, réflexion injectée). Round-trips lex/DODLP via registre, mode défensif AD-10, gate:reflectable vert, AD-1 CORE OUT=0. Status → review.
