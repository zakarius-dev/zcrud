---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 2.3 : Registre & extensibilité (ZcrudRegistry / ZTypeRegistry / ZSourceRegistry / ZExtension / extra)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur du cœur `zcrud_core`**,
je veux **poser le socle d'extensibilité AD-4 — les registres ouverts `ZcrudRegistry` (modèles), `ZTypeRegistry` (types de champ/valeur ouverts) et `ZSourceRegistry` (provenance), le slot type additif **versionné** `ZExtension` (parsing défensif `fromJsonSafe → null`) et le contrat d'échappatoire non typée `extra: Map<String,dynamic>` — en Dart pur, avec un échec **explicite** (`throw`) sur type non enregistré**,
afin que **le codegen (E2-5) enregistre chaque `@ZcrudModel` sans lister les modèles à la main, que les apps hôtes (DODLP article, lex_douane) branchent leurs variants de type/provenance **sans forker** le cœur (E3-3b, E7-2, E9-1), et que tout document historique/corrompu se déserialise sur un défaut sûr sans jamais faire échouer le parent — tout en restant backend-agnostique, sans réintroduire Flutter/Firebase ni un gestionnaire d'état dans le domaine.**

## Contexte & valeur

E2-1 (contrats `ZEntity`/`ZNode`/`ZSyncable`/`ZSyncMeta`/`ZFailure` + `ZResult<T>` + câblage dartz) et E2-2 (ports `ZRepository<T>`/`ZDataRequest`/`ZCursor`/`ZDataState`/`ZAcl`) sont **done** ; E2-7 (`ZFormController`/`ZcrudScope`) et E2-9 (bindings) sont **done**. Le package `zcrud_core` **autorise désormais le SDK Flutter** (AD-14, acquis en E2-7) mais la **couche `lib/src/domain/` reste STRICTEMENT pur-Dart** — gardée par `test/purity/domain_purity_test.dart` (grep : aucun import Flutter/Firebase/Hive/gestionnaire d'état hormis `package:dartz`).

**E2-3 est le socle d'extensibilité AD-4**, consommé en aval par :
- **E2-5 (générateur build_runner)** : chaque `@ZcrudModel` génère son **enregistrement au `ZcrudRegistry`** (`fromMap`/`toMap` + `kind`) et « échec explicite si type non enregistré » — E2-3 fournit le registre et l'erreur `ZUnregisteredTypeError` que le codegen câble.
- **E3-3b (familles avancées)** : « types dont le widget vit ailleurs (markdown→E6, géo/tél→E11a) servis via `ZTypeRegistry` ».
- **E7-2 (`ReflectableCodec` + `ZcrudRegistry` au bootstrap)** : DODLP conserve sa réflexion sans lister ses modèles ; registre injecté après `registerServices()`.
- **E9-1 (`ZFlashcard`)** : « variant "article" via `ZSourceRegistry` » ; « porte les slots d'extension `extra` + `ZExtension?` (AD-4) ».

**Ce que cette story matérialise (schéma canonique §4, porté de lex_douane) — le mécanisme d'extension principal :**
1. **Slot type additif versionné `ZExtension?`** — pattern `HierarchyNode.ragContext → NodeContext{formatVersion, fromJsonSafe}` (canonique §4 pt.1, `node_context.dart:68`) : extension **riche, rétro-compatible**, versionnée indépendamment, parsée défensivement (repli `null`, **jamais throw**).
2. **Échappatoire non typée `extra: Map<String,dynamic>`** (défaut `const {}`) — pattern `TariffDetails.metadata` (canonique §4 pt.2).
3. **Registres ouverts `register(kind, fromJson, toJson)`** — `ZTypeRegistry`/`ZSourceRegistry` (canonique §4 pt.3) : chaque app enregistre les `fromJson/toJson` de ses variants, **levant la frontière inter-package qu'une `sealed` interdit** ; plus le `ZcrudRegistry` de **modèles** (kind→(fromMap,toMap)) consommé par le codegen (AD-3).

**Point subtil central de la story (à ne pas confondre) — deux régimes d'erreur cohabitent :**
- **AD-3 / frontière de décodage de MODÈLE** : `ZcrudRegistry.codecFor(kind)` sur un **kind inconnu → `throw` explicite** (`ZUnregisteredTypeError`), **jamais** un cast `null` silencieux. C'est un **bug de bootstrap** (l'app a oublié d'enregistrer le modèle), pas une donnée corrompue.
- **AD-10 / frontière de parsing de CHAMP** : un `ZExtension.fromJsonSafe` sur données absentes/corrompues/de version inconnue → **`null`, jamais throw** ; le parent se déserialise quand même. C'est de la donnée, tolérée défensivement.
Cette dualité est **le cœur de la story** et doit être encodée sans ambiguïté (voir Dev Notes « Deux régimes d'erreur »).

**Ce qui rendra la story vérifiable :** register/lookup fonctionnent sous les 3 registres ; kind inconnu → `throw ZUnregisteredTypeError` (frontière modèle) ; kind dupliqué → `throw ZDuplicateRegistrationError` (bug de bootstrap détecté, pas last-wins silencieux) ; `ZExtension.fromJsonSafe` sur payload corrompu/tronqué/version inconnue → `null` **sans throw** ; round-trip d'une extension versionnée (`toJson`↔`fromJsonSafe`) ; `extra` préservé (round-trip) et défaut `const {}` ; le domaine reste **pur-Dart** (garde de pureté verte) ; `analyze` RC=0 ; `flutter test`/`melos run test` RC=0.

## Périmètre strict de CETTE story (anti-empiètement)

- ✅ **`ZcrudRegistry`** : registre de **modèles** — `register<T>(kind, {fromMap, toMap})`, `isRegistered(kind)`, `codecFor(kind)` (**throw** si absent), `tryCodecFor(kind)` (null si absent), `decode(kind, map)`/`encode(kind, value)`, `kinds`. **Instance** injectable (PAS de singleton statique mutable).
- ✅ **`ZTypeRegistry`** : registre de **types de champ/valeur ouverts** — `register(kind, fromJson, toJson)`, lookup strict/défensif, `throw` sur kind inconnu (au point de décodage strict).
- ✅ **`ZSourceRegistry`** : registre de **provenance ouverte** — même mécanique `register(kind, fromJson, toJson)` (variant `article` douane branché par l'app hôte, cf. E9-1).
- ✅ **Base interne partagée `ZCodecRegistry<T>`** (container générique, **non exporté** ou exporté comme abstraction fine) factorisant register/lookup/erreurs — pour ne pas tripler le code (anti-réinvention).
- ✅ **`ZUnregisteredTypeError`** + **`ZDuplicateRegistrationError`** : erreurs de configuration/bootstrap, sous-types de `Error` Dart (**PAS** de `ZFailure` — voir Dev Notes), messages actionnables (kind + registre concerné).
- ✅ **`ZExtension`** : base **abstraite additive versionnée** (`int get formatVersion` ; `Map<String,dynamic> toJson()`) + helper défensif réutilisable `ZExtension.guard`/`tryParse` (renvoie `null` sur toute exception) — testable dans le cœur via une fausse extension.
- ✅ **`ZExtensible`** : mixin/contrat fin exposant `ZExtension? get extension;` et `Map<String,dynamic> get extra;` (défaut `const {}`) — que les entités canoniques concrètes (E9/E10) mixeront, **sans** polluer `ZEntity`.
- ✅ Helper(s) `extra` défensifs (lecture typée sûre, jamais throw) si trivial — sinon consignés.
- ✅ Exports du barrel + docstrings d'origine `fichier:ligne` lex (traçabilité re-portage, canonique §6.6).
- ✅ Tests pur-Dart (`package:test`) : registres (faux types), extension corrompue, collision de kind, round-trips, `extra`, pureté.
- ❌ **Pas** de `ZFieldSpec` réel dans la registration (le type **n'existe pas** avant E2-4/E2-5) : le `ZcrudRegistry` v1 porte `fromMap`/`toMap` ; l'association `ZFieldSpec[]` est ajoutée **additivement** en E2-4/E2-5 (voir Dev Notes « Slot ZFieldSpec différé »).
- ❌ **Pas** d'annotations `@ZcrudModel`/`@ZcrudField`/`@ZcrudId` (→ **E2-4**) ni de générateur build_runner (→ **E2-5**).
- ❌ **Pas** de modèles canoniques concrets (`ZFlashcard`, `ZMindmapNode`, `ZFlashcardSource`…) ni d'enums ouverts métier (→ E9/E10).
- ❌ **Pas** de `ReflectableCodec`/`JsonSerializableAdapter` (→ **E2-6**) ni de câblage bootstrap DODLP (→ **E7-2**).
- ❌ **Pas** de dépendance à Flutter/Firebase/Hive/gestionnaire d'état dans les fichiers de cette story (couche `domain/` pur-Dart).
- ❌ **Ne PAS** toucher `sprint-status.yaml` (géré par l'orchestrateur).
- ❌ **Ne PAS** supprimer/renommer les types E2-1/E2-2/E2-7 exportés (non-régression) ni `ZCoreApi`.

## Acceptance Criteria

1. **Pureté Dart du domaine (AD-14, AD-1) préservée.** Aucun fichier introduit par cette story sous `packages/zcrud_core/lib/src/domain/` n'importe `package:flutter/*`, `dart:ui`, `package:cloud_firestore/*`, une `package:firebase*`, `package:hive*`, ni un gestionnaire d'état (`flutter_riverpod`/`riverpod`/`get`/`provider`). Seuls imports externes autorisés : `dart:core` (implicite) et `package:dartz/dartz.dart` (si utile). `test/purity/domain_purity_test.dart` (existant, qui scanne récursivement `lib/src/domain/`) reste **vert** en couvrant les nouveaux répertoires `registry/` et `extension/`. `pubspec.yaml` de `zcrud_core` n'ajoute **aucune** dépendance `zcrud_*` (AD-1, out-degree 0 préservé) ni backend/manager.

2. **`ZcrudRegistry` — enregistrement de modèles + lookup (AD-3, AD-4 pt.3).** Un registre **instanciable** `ZcrudRegistry` expose :
   - `void register<T>(String kind, {required T Function(Map<String,dynamic>) fromMap, required Map<String,dynamic> Function(T) toMap})` — enregistre un couple (dé)sérialisation pour `kind` ;
   - `bool isRegistered(String kind)` ; `Iterable<String> get kinds` ;
   - `ZModelCodec codecFor(String kind)` — **retourne** le codec, ou **`throw ZUnregisteredTypeError`** si `kind` absent ;
   - `ZModelCodec? tryCodecFor(String kind)` — variante **défensive** renvoyant `null` si absent (pour un appelant qui veut brancher, cf. AD-10) ;
   - `Object decode(String kind, Map<String,dynamic> map)` et `Map<String,dynamic> encode(String kind, Object value)` — commodités s'appuyant sur `codecFor` (donc **throw** si `kind` non enregistré).
   Le registre est une **instance** (pas un singleton statique global mutable — voir Dev Notes « Mutabilité & injection »).

3. **Type non enregistré → `throw` explicite (AD-3).** `ZcrudRegistry.codecFor('inconnu')` (et `decode`/`encode` sur kind absent) **lève `ZUnregisteredTypeError`** — **jamais** de retour `null` silencieux ni de cast implicite. `ZUnregisteredTypeError` est un sous-type de `Error` Dart (**pas** un `ZFailure`), porte le `kind` fautif et le nom du registre dans un `message` actionnable, et n'est **pas** destiné à être `fold`é dans un `Either` (c'est un bug de configuration, cf. Dev Notes « Deux régimes d'erreur »).

4. **Collision de `kind` → `throw` (bootstrap défensif).** Enregistrer deux fois le **même** `kind` sur un registre lève **`ZDuplicateRegistrationError`** (sous-type de `Error`, message actionnable), plutôt qu'un remplacement silencieux « last-wins » — pour détecter un ordre de bootstrap ou une double-génération fautifs. **Décision consignée** (Dev Notes) ; l'alternative last-wins est explicitement rejetée.

5. **`ZTypeRegistry` & `ZSourceRegistry` — `register(kind, fromJson, toJson)` (AD-4 pt.3).** Deux registres ouverts partageant la mécanique register/lookup/erreurs :
   - `ZTypeRegistry` sert les **types de champ/valeur** dont le widget/codec vit hors du cœur (markdown/géo/tél — consommé par E3-3b) ;
   - `ZSourceRegistry` sert la **provenance ouverte** (variant `article` douane branché par l'app — consommé par E9-1) ;
   - chacun expose `register(String kind, {required fromJson, required toJson})`, `isRegistered`, un lookup **strict** (`throw ZUnregisteredTypeError` sur kind absent) **et** un lookup **défensif** (`null` sur kind absent), et la même règle de collision (AC4). La factorisation passe par un **container générique interne** `ZCodecRegistry<T>` (générique de **conteneur**, comme `ZRepository<T>` — **pas** un generic de sérialisation, cf. AD-4 rejet des generics de sérialisation ; documenté).

6. **`ZExtension` — slot type additif VERSIONNÉ (AD-4 pt.1, AD-10).** Une base **abstraite** `ZExtension` (jamais `sealed` — extension inter-package) expose au minimum `int get formatVersion` (version de sous-schéma **indépendante** du parent) et `Map<String,dynamic> toJson()`. `ZExtension` fournit un helper défensif **réutilisable et testable** — `static T? guard<T>(T Function() parse)` (ou `tryParse`) — qui exécute un parseur et **renvoie `null` sur TOUTE exception** (jamais de propagation). Convention documentée : chaque sous-classe concrète (en satellite, E9/E10) expose un `static X? fromJsonSafe(Map<String,dynamic>? json)` bâti sur `guard`, qui renvoie `null` si `json` est `null`, corrompu, ou de `formatVersion` non gérée. `ZExtension` n'impose **ni** `freezed` **ni** `@JsonSerializable` au niveau contrat (pur-Dart).

7. **`ZExtension.fromJsonSafe` ne throw JAMAIS et renvoie `null` sur corrompu (AD-10).** Prouvé via une **fausse extension** déclarée dans le test : `guard`/`fromJsonSafe` sur `null`, sur une map aux clés manquantes, sur un type inattendu (ex. `formatVersion` = `"x"` au lieu d'`int`), et sur un `formatVersion` inconnu → **`null` à chaque fois, aucune exception**. Un `formatVersion` connu et bien formé → instance reconstruite (round-trip).

8. **Round-trip d'une extension versionnée + `extra` préservé.** Pour la fausse extension du test : `ext.toJson()` puis `FakeExt.fromJsonSafe(json)` reconstruit une valeur **égale** (round-trip), avec `formatVersion` conservé. Le contrat `extra` : une entité fictive `ZExtensible` porte `Map<String,dynamic> extra` de défaut `const {}` ; un round-trip conceptuel (`extra` écrit → relu) **préserve** les paires arbitraires, y compris des clés inconnues du cœur (échappatoire non typée, canonique §4 pt.2).

9. **`ZExtensible` — contrat de slot d'extension (AD-4).** Un mixin/contrat fin `ZExtensible` déclare `ZExtension? get extension;` et `Map<String,dynamic> get extra;` (défaut `const {}` côté implémentation). Il n'est **pas** mixé dans `ZEntity` (qui reste un contrat pur d'identité — E2-1) : les entités canoniques concrètes (E9/E10) le mixent **en plus**. Documenté comme le point d'ancrage des « slots `extra` + `ZExtension?` » requis par E9-1.

10. **Emplacements, barrel & exports.** Les nouveaux types vivent sous `packages/zcrud_core/lib/src/domain/registry/` et `.../extension/` (voir Dev Notes). L'API publique passe **uniquement** par le barrel `lib/zcrud_core.dart` (ordre alphabétique `directives_ordering`), qui exporte `ZcrudRegistry`+`ZModelCodec`, `ZTypeRegistry`, `ZSourceRegistry`, `ZUnregisteredTypeError`, `ZDuplicateRegistrationError`, `ZExtension`, `ZExtensible` (et `ZCodecRegistry` si jugé public), **sans** rien retirer des exports E2-1/E2-2/E2-7 ni `ZCoreApi`.

11. **Consommabilité par E2-5 démontrée (contrat de codegen).** Un test **simule le pattern d'enregistrement généré** : une fonction `registerFakeModel(ZcrudRegistry r)` appelle `r.register<FakeModel>('fakeModel', fromMap: …, toMap: …)`, puis `r.decode('fakeModel', map)` reconstruit un `FakeModel` et `r.encode('fakeModel', model)` reproduit la map (round-trip complet **via le registre**, sans réflexion). Prouve que le codegen (E2-5) pourra émettre des fonctions d'enregistrement prenant une **instance** de `ZcrudRegistry` en paramètre (injection au bootstrap, cf. E7-2).

12. **Vérif verte (AD-3/AD-4/AD-10 respectés).** `dart run melos run generate` OK (aucun codegen requis ici, pipeline reste vert) ; `dart analyze`/`melos run analyze` RC=0 (zéro warning bloquant, `public_member_api_docs` satisfait si activé) ; `flutter test`/`melos run test` RC=0 avec les tests ajoutés ; `melos run verify` OK (graphe AD-1 acyclique, cœur out-degree 0 inchangé ; aucun type backend AD-5). Aucun `.g.dart` produit/suivi.

## Tasks / Subtasks

- [x] **Tâche 1 — Base interne partagée + erreurs (AC: 3, 4, 5)**
  - [x] Créer `lib/src/domain/registry/z_registry_error.dart` : `class ZUnregisteredTypeError extends Error` (champs `kind` + `registryName`, `toString()` actionnable) ; `class ZDuplicateRegistrationError extends Error` (idem). **Sous-types de `Error`** (pas de `ZFailure`) — voir Dev Notes « Deux régimes d'erreur ».
  - [x] Créer `lib/src/domain/registry/z_codec_registry.dart` : container générique interne `ZCodecRegistry<T>` (map `String kind → T`), `register(kind, T value)` (collision → `throw ZDuplicateRegistrationError`), `bool isRegistered(kind)`, `T entryFor(kind)` (absent → `throw ZUnregisteredTypeError`), `T? tryEntryFor(kind)`, `Iterable<String> get kinds`. Docstring : « générique de CONTENEUR (cf. `ZRepository<T>`), PAS un generic de sérialisation (AD-4) ».
- [x] **Tâche 2 — `ZcrudRegistry` (modèles) (AC: 2, 3, 4, 11)**
  - [x] Créer `lib/src/domain/registry/zcrud_registry.dart` : `class ZModelCodec { final String kind; final Object Function(Map<String,dynamic>) fromMap; final Map<String,dynamic> Function(Object) toMap; }` (typedefs `ZFromMap`/`ZToMap`).
  - [x] `class ZcrudRegistry` bâti sur `ZCodecRegistry<ZModelCodec>` : `register<T>(kind, {fromMap, toMap})` (adapte les callbacks typés `T` vers `Object` en interne — cast sûr côté encode), `isRegistered`, `kinds`, `codecFor` (throw), `tryCodecFor` (null), `decode(kind, map)`, `encode(kind, value)`.
  - [x] Docstring « Slot `ZFieldSpec` différé » : l'association `kind → List<ZFieldSpec>` sera ajoutée **additivement** en E2-4/E2-5 (nouveau paramètre optionnel / seconde map), sans casser la signature actuelle.
- [x] **Tâche 3 — `ZTypeRegistry` + `ZSourceRegistry` (AC: 5)**
  - [x] Créer `lib/src/domain/registry/z_type_registry.dart` et `.../z_source_registry.dart` : chacun un `register(String kind, {required Object Function(Map<String,dynamic>) fromJson, required Map<String,dynamic> Function(Object) toJson})` + lookup strict/défensif + collision, réutilisant `ZCodecRegistry`. Docstrings d'usage (E3-3b pour type, E9-1 pour source) + origine lex (`flashcard_source.dart:13`, canonique §4).
- [x] **Tâche 4 — `ZExtension` + `ZExtensible` + helper `extra` (AC: 6, 7, 8, 9)**
  - [x] Créer `lib/src/domain/extension/z_extension.dart` : `abstract class ZExtension { const ZExtension(); int get formatVersion; Map<String,dynamic> toJson(); static T? guard<T>(T Function() parse) { try { return parse(); } catch (_) { return null; } } }`. Docstring origine `node_context.dart:68` (`NodeContext{formatVersion, fromJsonSafe}`).
  - [x] Créer `lib/src/domain/extension/z_extensible.dart` : `mixin ZExtensible { ZExtension? get extension; Map<String,dynamic> get extra; }` (+ doc : défaut `const {}` porté par l'implémentation, jamais mixé dans `ZEntity`). Optionnel : helper `zExtraRead<T>(Map, key)` défensif si trivial.
- [x] **Tâche 5 — Barrel & exports (AC: 10)**
  - [x] Étendre `lib/zcrud_core.dart` : ajouter les `export 'src/domain/registry/…';` et `export 'src/domain/extension/…';` en **ordre alphabétique** ; **ne rien retirer** (E2-1/E2-2/E2-7 + `ZCoreApi` conservés).
- [x] **Tâche 6 — Tests pur-Dart (AC: 1, 3, 4, 7, 8, 11)**
  - [x] `test/domain/registry/zcrud_registry_test.dart` : register/`isRegistered`/`kinds` ; `codecFor`/`decode`/`encode` round-trip via `FakeModel` (AC11 : `registerFakeModel(r)`) ; kind inconnu → `throwsA(isA<ZUnregisteredTypeError>())` ; collision → `throwsA(isA<ZDuplicateRegistrationError>())` ; `tryCodecFor(inconnu) == null`.
  - [x] `test/domain/registry/z_type_source_registry_test.dart` : mêmes garanties pour `ZTypeRegistry` & `ZSourceRegistry` (register/lookup strict+défensif, kind inconnu → throw, collision → throw, isolation : deux instances distinctes ne partagent pas leurs enregistrements).
  - [x] `test/domain/extension/z_extension_test.dart` : `FakeExt implements ZExtension` (`formatVersion`, `toJson`, `static FakeExt? fromJsonSafe(json)` via `guard`) ; `fromJsonSafe(null)`/clés manquantes/type inattendu/`formatVersion` inconnu → `null` **sans throw** ; round-trip `toJson`↔`fromJsonSafe` égal ; `guard(() => throw …) == null`.
  - [x] `test/domain/extension/z_extensible_test.dart` : entité fictive `ZExtensible` — `extra` défaut `const {}`, round-trip conceptuel préservant des clés inconnues ; `extension` nullable.
  - [x] Vérifier que `test/purity/domain_purity_test.dart` couvre bien `registry/` et `extension/` (récursif — aucun ajout requis, mais l'exécuter et confirmer vert).
- [x] **Tâche 7 — Vérif verte & traçabilité (AC: 12)**
  - [x] `dart run melos run generate` OK ; `dart analyze`/`melos run analyze` RC=0 ; `flutter test`/`melos run test` RC=0 ; `melos run verify` OK (graphe AD-1 inchangé, cœur out-degree 0).
  - [x] Confirmer que `ZCoreApi` + tous les exports E2-1/E2-2/E2-7 restent exportés (non-régression) ; 0 `.g.dart` suivi par git.

## Dev Notes

### Emplacements décidés (sous `packages/zcrud_core/lib/src/domain/`)

| Type | Fichier | Nature |
|---|---|---|
| `ZUnregisteredTypeError`, `ZDuplicateRegistrationError` | `registry/z_registry_error.dart` | sous-types de `Error` Dart (bug de config, jamais `ZFailure`) |
| `ZCodecRegistry<T>` | `registry/z_codec_registry.dart` | container générique interne (register/lookup/erreurs) partagé |
| `ZModelCodec`, `ZcrudRegistry` | `registry/zcrud_registry.dart` | registre de **modèles** (kind→fromMap/toMap), consommé par E2-5 |
| `ZTypeRegistry` | `registry/z_type_registry.dart` | registre de **types de champ ouverts** (E3-3b) |
| `ZSourceRegistry` | `registry/z_source_registry.dart` | registre de **provenance ouverte** (E9-1) |
| `ZExtension` (+ `guard`) | `extension/z_extension.dart` | slot type additif **versionné**, parsing défensif |
| `ZExtensible` | `extension/z_extensible.dart` | mixin exposant `extension`/`extra`, mixé par les entités E9/E10 |

### Ambiguïté tranchée #1 — Deux régimes d'erreur (AD-3 throw vs AD-10 null)

C'est **le** point délicat de la story. Les deux règles ne se contredisent pas — elles s'appliquent à des **frontières différentes** :

- **Frontière de DÉCODAGE DE MODÈLE (AD-3)** : quand un appelant demande « reconstruis-moi l'objet dont le `kind` discriminant vaut X », un `kind` **non enregistré** est un **bug de bootstrap** (l'app a oublié d'appeler `register`, ou l'ordre d'init est faux). Le contrat exige un **échec explicite** : `throw ZUnregisteredTypeError` — « jamais par cast null silencieux » (AD-3 textuel). On modélise ça avec un **`Error`** Dart (comme `StateError`/`ArgumentError`), **pas** un `ZFailure` : un `Error` signale un défaut programmatique non récupérable en production ; un `ZFailure` (dartz `Left`) modélise un échec métier attendu et récupérable. Ne **jamais** envelopper `ZUnregisteredTypeError` dans un `Either`.
- **Frontière de PARSING DE CHAMP/EXTENSION (AD-10)** : quand on lit une **donnée** (un `ZExtension` d'un document historique, un enum inconnu, un champ absent), la corruption/inconnu est **attendue** et doit être **tolérée** : `fromJsonSafe → null`, `unknownEnumValue`, `defaultValue`, **jamais** de throw, le parent survit. C'est de la donnée, pas de la configuration.

**Corollaire pour le lookup** : `ZcrudRegistry.codecFor(kind)` **throw** (frontière modèle, strict) ; `tryCodecFor(kind)` **renvoie null** (échappatoire pour un appelant qui veut, lui, se comporter défensivement — ex. un import tolérant). Les deux coexistent volontairement.

### Ambiguïté tranchée #2 — Mutabilité & injection : instance, PAS de singleton statique mutable

Les registres sont **mutables** (peuplés par des `register(...)` au bootstrap) mais **PAS** exposés comme un **singleton statique global mutable**. Décision : ce sont des **instances** que l'app crée et **injecte** via `ZcrudScope`/le binding (cohérent avec E2-8 « pas de singleton statique mutable » et AD-6/AD-15 : injection par seams). Justification :
- **Isolation inter-app (OQ-6)** : lex_douane et DODLP peuvent porter des registres **distincts** sans collision globale ; un test peut instancier un registre neuf et jetable (pas d'état résiduel entre tests).
- **E2-5/E7-2** : le codegen émettra des fonctions `registerXxx(ZcrudRegistry r)` prenant l'**instance** en paramètre ; DODLP injecte son registre « après `registerServices()` » (E7-2) — un global mutable rendrait l'ordre d'init fragile et non testable.

**Thread-safety** : non requise. Dart est **mono-thread par isolate** (pas de mémoire partagée concurrente) ; l'enregistrement se fait en phase de bootstrap séquentielle. Aucun verrou nécessaire ; documenter ce choix (pas de `synchronized`).

### Ambiguïté tranchée #3 — OQ-6 : registres par axe (pas un registre global unique)

La question ouverte OQ-6 (canonique §8.6) demande : un `ZTypeRegistry` global unique, ou des registres **par axe** ? **Décision : par axe** — `ZcrudRegistry` (modèles), `ZTypeRegistry` (types de champ), `ZSourceRegistry` (provenance) sont **trois registres distincts** (l'épic E2-3 les nomme séparément ; E3-3b cible `ZTypeRegistry`, E9-1 cible `ZSourceRegistry`). Ils **partagent l'implémentation** via `ZCodecRegistry<T>` mais restent des **espaces de noms séparés** (un `kind` « article » côté source n'entre pas en collision avec un `kind` de type de champ). Meilleure isolation + testabilité. On garde la porte ouverte à d'autres axes futurs (`ZNodeTypeRegistry`, `ZSrsSchedulerRegistry`) sur la même base, sans refactor.

### Ambiguïté tranchée #4 — Collision de kind : throw (pas last-wins)

Ré-enregistrer un `kind` déjà présent **throw `ZDuplicateRegistrationError`** au lieu d'écraser silencieusement. Un « last-wins » masquerait une **double génération** (deux `part` codegen enregistrant le même modèle) ou un **ordre de bootstrap** fautif — exactement le genre de bug que « échoue explicitement, jamais silencieux » (AD-3) veut prévenir. Si un besoin d'override légitime émerge plus tard (hot-reload, tests), on ajoutera **additivement** un paramètre explicite `override: true` — pas de changement de défaut. Décision consignée pour le code-review.

### Slot `ZFieldSpec` différé (dépendance E2-4/E2-5)

L'AC de l'épic mentionne « kind→(fromMap,toMap) **+ éventuel `ZFieldSpec`** ». Or **`ZFieldSpec` n'existe pas** avant E2-4/E2-5. Cette story livre donc `ZcrudRegistry` avec `fromMap`/`toMap` **seulement** ; l'association `kind → List<ZFieldSpec>` sera ajoutée **additivement** en E2-4/E2-5 (paramètre optionnel `fieldSpecs` sur `register`, ou seconde map `_specs`), **sans casser** la signature actuelle (AD-10 additif). À documenter en docstring pour que E2-5 sache où brancher. **Ne pas** introduire un slot `Object?` non typé « en attendant » (fuite d'API) — le point d'extension est décrit, pas pré-câblé.

### Invariants d'architecture applicables (rappel dev)

- **AD-1** : `zcrud_core` = puits du graphe (out-degree 0). Aucun `zcrud_*` ajouté ; `dartz` n'est pas un `zcrud_*`.
- **AD-3** : codegen enregistre au `ZcrudRegistry` ; **type non enregistré → throw explicite**, jamais cast null. Base posée ici (l'erreur + le registre).
- **AD-4** : extension = **composition** (`ZExtension` versionné) + `extra` Map + **registre** `register(kind, fromJson, toJson)` + enums ouverts. **Rejetés** : héritage de classes sérialisées (on ne dérive PAS `ZExtension` d'une classe sérialisée ; base abstraite FINE OK), `sealed` inter-package (`ZExtension`/registres restent ouverts), **generics comme mécanisme de sérialisation** (le `ZCodecRegistry<T>` est un générique de **conteneur**, pas de sérialisation — documenté).
- **AD-5** : backend-agnostique — aucun `Timestamp`/`Filter`/`FirebaseException`. Rien de tel ici (registres/extension purs).
- **AD-10** : désérialisation défensive — `ZExtension.fromJsonSafe → null` jamais throw ; évolution additive (slot `ZFieldSpec` additif). La **frontière modèle** (AD-3) reste, elle, stricte (throw).
- **AD-14** : couche `domain/` pur-Dart ; invariants au repository, pas ici.
- **AD-6/AD-15** : registres **injectés** via `ZcrudScope`/binding (instances), pas de singleton statique mutable ; le câblage d'injection concret relève d'E2-7/E7-2 (hors périmètre — on livre les types injectables).

### Conventions de code (canonique §5)

- **`@JsonSerializable` non requis** : `ZExtension`/`ZExtensible` sont des **contrats abstraits** pur-Dart ; les `toJson`/`fromJsonSafe` concrets vivent dans les sous-classes satellites (E9/E10) ou sont écrits à la main dans les tests (faux types). Pas de `part '*.g.dart'`.
- **`Equatable` jamais** — si `ZModelCodec`/faux types ont besoin d'égalité de valeur (round-trip), `==`/`hashCode` manuels via `Object.hash`.
- **`freezed` non imposé** ; classes `final` + constructeur `const` où pertinent.
- **`sealed` proscrit** pour `ZExtension` et les registres (extension inter-package, AD-4). (Rappel : `ZFlashcardSource` restera `sealed` **en interne** au package flashcard, avec variant `custom` + `ZSourceRegistry` pour l'ouverture — deux usages distincts, E9.)
- **Erreurs de config = `Error`** (`ZUnregisteredTypeError`/`ZDuplicateRegistrationError`), **erreurs métier = `ZFailure`** (`Either.Left`). Ne pas confondre.
- Traçabilité : docstring d'origine `lex_core/…:ligne` (`node_context.dart:68` pour `ZExtension` ; `flashcard_source.dart:13` pour `ZSourceRegistry`), canonique §6.6.

### Source tree à toucher

```
packages/zcrud_core/
  lib/zcrud_core.dart                         # + exports registry/ & extension/ (alpha), rien retiré
  lib/src/domain/
    registry/z_registry_error.dart            # NEW (ZUnregisteredTypeError, ZDuplicateRegistrationError : Error)
    registry/z_codec_registry.dart            # NEW (ZCodecRegistry<T> container générique)
    registry/zcrud_registry.dart              # NEW (ZModelCodec + ZcrudRegistry)
    registry/z_type_registry.dart             # NEW (ZTypeRegistry)
    registry/z_source_registry.dart           # NEW (ZSourceRegistry)
    extension/z_extension.dart                # NEW (ZExtension + guard)
    extension/z_extensible.dart               # NEW (ZExtensible mixin)
  test/
    domain/registry/zcrud_registry_test.dart      # NEW
    domain/registry/z_type_source_registry_test.dart  # NEW
    domain/extension/z_extension_test.dart        # NEW
    domain/extension/z_extensible_test.dart       # NEW
    purity/domain_purity_test.dart                # EXISTANT — reste vert (couvre registry/ & extension/)
```

### Project Structure Notes

- La couche `domain/` reste **pur-Dart** : ces types n'importent que `dart:core` (et éventuellement `package:dartz` s'il sert — a priori inutile ici). **Ne pas** ajouter `flutter` pour cette story ; l'injection Flutter (`ZcrudScope`) est déjà posée (E2-7) et consomme ces instances **sans** que le domaine dépende de Flutter.
- Tests en **`package:test`** (pur-Dart), exécutés via `flutter test`/`melos run test` (comme E2-1/E2-2). Ne pas tirer `flutter_test` dans ces tests de domaine.
- Ne pas régénérer/committer de `*.g.dart` (aucun modèle annoté ici ; E2-4/E2-5 introduiront le codegen).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E2] — Story E2-3 (register/throw/`ZExtension`/`extra`) ; consommateurs E2-5, E3-3b, E7-2, E9-1.
- [Source: architecture.md#AD-4] — extension : composition + `ZExtension` versionné (`formatVersion`, `fromJsonSafe → null`, `@JsonKey(defaultValue)`) + `extra` Map + `ZTypeRegistry`/`ZSourceRegistry.register(kind, fromJson, toJson)` + enums ouverts ; **rejetés** : héritage de classes sérialisées, `sealed` inter-package, generics de sérialisation.
- [Source: architecture.md#AD-3] — codegen → enregistrement au `ZcrudRegistry` ; type non enregistré **échoue explicitement (throw)**, jamais cast null silencieux ; `reflectable` banni.
- [Source: architecture.md#AD-10] — désérialisation défensive (`fromJsonSafe → null`, `unknownEnumValue`, `defaultValue`) ; chaque `ZExtension` porte son `formatVersion` ; évolution additive.
- [Source: architecture.md#AD-6] / [AD-15] — injection/cycle de vie par seams (`ZcrudScope`/bindings) ; pas de conteneur imposé.
- [Source: docs/canonical-schema.md#4] — mécanisme d'extension principal (composition + `ZExtension{formatVersion,fromJsonSafe}` + `extra` + registre) ; tableau des mécanismes ; rejets (`sealed` inter-package, generics de sérialisation, héritage sérialisé).
- [Source: docs/canonical-schema.md#5] — conventions (`Equatable` jamais, `freezed` non imposé, `==`/`hashCode` manuels, `@JsonSerializable` pur, enums camelCase).
- [Source: docs/canonical-schema.md#8.6] — OQ-6 portée du registre (tranchée ici : par axe) ; §8 pattern registre.
- [Source: docs/canonical-schema.md#node_context.dart:68] — `NodeContext{formatVersion, fromJsonSafe}` (origine de `ZExtension`).
- [Source: docs/canonical-schema.md#flashcard_source.dart:13] — `FlashcardSource` (union `sealed` interne + variant `custom` + registre → origine de `ZSourceRegistry`).
- [Source: packages/zcrud_core/lib/src/domain/failures/z_failure.dart] — `ZFailure` (métier, `Either.Left`) : à NE PAS confondre avec les `Error` de config de cette story.
- [Source: packages/zcrud_core/lib/zcrud_core.dart] — barrel actuel (à étendre, ordre alphabétique) ; [Source: packages/zcrud_core/test/purity/domain_purity_test.dart] — garde de pureté récursive.
- [Source: _bmad-output/implementation-artifacts/stories/e2-1-contrats-de-base.md] — décision `abstract` vs `sealed` (précédent `ZFailure`), conventions de test pur-Dart.

## Stratégie de tests

Tous les tests sont **pur-Dart** (`import 'package:test/test.dart';`), exécutés via `flutter test`/`melos run test`. Ils utilisent de **faux types** locaux (aucun modèle canonique réel n'existe encore).

- **`ZcrudRegistry` (`zcrud_registry_test.dart`)** :
  - `FakeModel` local (`final`, `==`/`hashCode`) + `registerFakeModel(ZcrudRegistry r)` simulant le pattern **généré** (AC11) ;
  - register → `isRegistered('fakeModel')` vrai, `kinds` contient `fakeModel` ;
  - `decode('fakeModel', map)` reconstruit le `FakeModel` attendu ; `encode('fakeModel', model)` reproduit la map ; **round-trip** égal ;
  - `codecFor('inconnu')` / `decode('inconnu', {})` / `encode('inconnu', x)` → `expect(() => …, throwsA(isA<ZUnregisteredTypeError>()))` ; message contient le `kind` ;
  - `tryCodecFor('inconnu') == null` (défensif) ;
  - double `register('fakeModel', …)` → `throwsA(isA<ZDuplicateRegistrationError>())`.
- **`ZTypeRegistry`/`ZSourceRegistry` (`z_type_source_registry_test.dart`)** : mêmes garanties (register/lookup strict `throw` + défensif `null`, collision `throw`) ; **isolation** : deux instances distinctes n'ont pas d'état partagé ; un `kind` enregistré côté source n'est pas visible côté type (espaces de noms séparés).
- **`ZExtension` (`z_extension_test.dart`)** :
  - `FakeExt implements ZExtension` (`int formatVersion`, `toJson()`, `static FakeExt? fromJsonSafe(Map<String,dynamic>? j) => ZExtension.guard(() => …)`) ;
  - `fromJsonSafe(null)` → `null` ; clés manquantes → `null` ; `formatVersion:'x'` (type faux) → `null` ; `formatVersion:99` (inconnu) → `null` ; **aucune** exception (`returnsNormally`) ;
  - `formatVersion` connu + bien formé → instance ; **round-trip** `ext.toJson()` → `fromJsonSafe` égal ;
  - `ZExtension.guard(() => throw StateError('x'))` → `null`.
- **`ZExtensible` (`z_extensible_test.dart`)** : entité fictive mixant `ZExtensible` → `extra` défaut `const {}` ; assigner `extra = {'k': 1, 'inconnu': [1,2]}` puis relire **préserve** les paires (échappatoire non typée) ; `extension` nullable OK.
- **Pureté (`domain_purity_test.dart`, existant)** : l'exécuter — il scanne récursivement `lib/src/domain/` donc couvre `registry/` et `extension/` sans modification ; confirmer **vert** (aucun import interdit introduit).
- **Vérif verte finale** : `melos run generate` OK → `dart analyze`/`melos run analyze` RC=0 → `flutter test`/`melos run test` RC=0 → `melos run verify` OK (graphe AD-1 inchangé).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, effort high)

### Debug Log References

- `dart analyze` (zcrud_core) → 0 issue (1 info `unintended_html_in_doc_comment` corrigée avant final).
- `melos run analyze` → SUCCESS (14 packages, 0 issue).
- `melos run test` → SUCCESS (zcrud_core : 140 tests, dont +36 nouveaux E2-3).
- `melos run verify` → RC=0 ; `graph_proof` : total arêtes = 17, `out-degree(zcrud_core) = 0`, `CORE OUT=0 OK`.
- `melos run generate` → SUCCESS ; 0 `.g.dart` produit/suivi.
- Pureté domaine : grep imports interdits sous `lib/src/domain/` = 0 ; `domain_purity_test.dart` (3 tests) vert, couvre `registry/` + `extension/`.
- `melos list` = 14 packages.

### Completion Notes List

- **Deux régimes d'erreur (Dev Notes #1)** encodés sans ambiguïté : frontière MODÈLE (AD-3) → `codecFor`/`decode`/`encode` lèvent `ZUnregisteredTypeError` (sous-type de `Error`, jamais `ZFailure`) ; frontière DONNÉE (AD-10) → `ZExtension.guard`/`fromJsonSafe` renvoient `null` sur toute exception ; `tryCodecFor` fournit l'échappatoire défensive `null`.
- **Injection (Dev Notes #2)** : registres = **instances** (`ZcrudRegistry()`, `ZTypeRegistry()`, `ZSourceRegistry()`), aucun singleton statique mutable ; isolation inter-instance testée (OQ-6).
- **Par axe (Dev Notes #3)** : trois registres distincts partageant `ZCodecRegistry<T>` (générique de CONTENEUR, pas de sérialisation — AD-4) ; espaces de noms séparés testés (un `kind` côté source invisible côté type).
- **Collision → throw (Dev Notes #4)** : `ZDuplicateRegistrationError`, pas de last-wins silencieux.
- **Factorisation** : `ZTypeRegistry`/`ZSourceRegistry` partagent la base fine `ZOpenRegistry` (+ `ZValueCodec`) composant `ZCodecRegistry<ZValueCodec>` — évite la duplication des thin-wrappers tout en gardant des types nommés distincts. Base non sérialisée → conforme au rejet AD-4 de l'héritage de **classes sérialisées** (documenté).
- **Slot `ZFieldSpec` différé** : `ZcrudRegistry` v1 porte `fromMap`/`toMap` seulement ; point d'extension E2-4/E2-5 documenté en docstring, pas de slot `Object?` non typé pré-câblé.
- **`ZExtensible` non mixé dans `ZEntity`** (AC9) ; helper défensif `zExtraRead<T>` ajouté (trivial).
- **Non-régression** : exports E2-1/E2-2/E2-7 + `ZCoreApi` conservés ; parité ×4 verte ; SM-1 intacte ; 0 dépendance `zcrud_*`/backend/manager ajoutée à `zcrud_core` (out-degree 0 préservé).

### File List

**Créés (source, `packages/zcrud_core/lib/src/domain/`)**
- `registry/z_registry_error.dart` — `ZUnregisteredTypeError`, `ZDuplicateRegistrationError` (sous-types de `Error`).
- `registry/z_codec_registry.dart` — container générique interne `ZCodecRegistry<T>`.
- `registry/zcrud_registry.dart` — `ZModelCodec` (+ typedefs `ZFromMap`/`ZToMap`) + `ZcrudRegistry`.
- `registry/z_open_registry.dart` — `ZValueCodec` (+ typedefs `ZFromJson`/`ZToJson`) + base `ZOpenRegistry`.
- `registry/z_type_registry.dart` — `ZTypeRegistry`.
- `registry/z_source_registry.dart` — `ZSourceRegistry`.
- `extension/z_extension.dart` — `ZExtension` (+ `guard`).
- `extension/z_extensible.dart` — mixin `ZExtensible` (+ helper `zExtraRead`).

**Créés (tests, `packages/zcrud_core/test/`)**
- `domain/registry/zcrud_registry_test.dart`
- `domain/registry/z_type_source_registry_test.dart`
- `domain/extension/z_extension_test.dart`
- `domain/extension/z_extensible_test.dart`

**Modifiés**
- `packages/zcrud_core/lib/zcrud_core.dart` — barrel : +8 exports registry/extension en ordre alphabétique (rien retiré).
