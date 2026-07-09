---
baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f
---

# Story 2.10 : Gate de test rétro-compatibilité de sérialisation (AD-10)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **mainteneur de zcrud garantissant que le schéma canonique évolue sans jamais casser les données existantes (apps héritées lex_douane / DODLP, documents Firestore/Hive historiques)**,
je veux **un CORPUS de fixtures de (dé)sérialisation, taggé `serialization-compat` et branché sur le gate de merge (`scripts/ci/verify_serialization.dart`, aujourd'hui no-op vert), qui exerce systématiquement la désérialisation défensive du `fromMap` généré (E2-5) sur des documents historiques, tronqués, à champs inconnus, à enums inconnus, à types faux, à clés non-`String` et truffés de `null`**,
afin que **la garantie AD-10 « un champ absent/corrompu ne fait JAMAIS échouer le parent » soit PROUVÉE en continu et VÉRIFIABLE (le gate échoue rouge si un jour un cas casse le parent), transformant le slot `verify:serialization` d'un no-op documenté en corpus réel exécuté à chaque merge, sans que E2-10 ait à toucher le workflow (convention de branchement stable câblée en E1-3).**

## Contexte & Enjeu

- **AD-10 (source of truth)** — `architecture.md#AD-10 — Évolution de schéma additive & désérialisation défensive` : « entre versions mineures, **ajout seulement** (champs nullable ou `@JsonKey(defaultValue)`), jamais renommage/suppression sans montée majeure. Désérialisation défensive systématique (`unknownEnumValue`, `defaultValue`, `fromJsonSafe → null`) : **un champ absent/corrompu ne fait jamais échouer le parent**. » Cette story est le **gate qui prouve cette règle** sur un corpus réaliste.
- **Rattachement au gate de merge (E1-3/E2-10)** — `epics.md` Story E2-10 : « suite CI de désérialisation défensive sur documents **historiques/tronqués/champs inconnus** — le parent ne casse jamais ; **fait partie du gate de merge (rattaché à E1-3)**. » Le slot `verify:serialization` (`scripts/ci/verify_serialization.dart`) a été créé et câblé en **E1-3** comme **no-op vert** (Flutter-aware) et amorcé d'un premier test en **E2-5**. **E2-10 le remplit** : il passe de « amorce 2 tests » à « corpus complet des 7 familles de corruption ».
- **Ce que E2-10 n'est PAS** : cette story ne modifie **ni le générateur** (E2-5, `done`, `fromMap` déjà défensif), **ni les adaptateurs** (E2-6, `done`), **ni le contrat de registre** (E2-3, gelé). Elle **ajoute exclusivement des tests** (corpus + fixtures) et, au besoin, un fichier de fixtures partagé. C'est une story de **couverture de gate**, pas de code produit.

## Acceptance Criteria

1. **Corpus des 7 familles de corruption** — un corpus de fixtures nommées couvre EXHAUSTIVEMENT les 7 familles suivantes sur le modèle de preuve `Article`/`Author` (E2-5), chaque cas étant une `Map<String, dynamic>` (ou une `Map` à clés non-`String` pour la famille f) accompagnée de ses attentes :
   - **(a) historiques** : schéma ancien, champs récents ABSENTS → repli `defaultValue` (`views→0`, `rating→0.0`, `published→false`, `status→draft`, `tags→[]`, `author→null`, `coauthors→[]`, `createdAt→null`), champs présents conservés.
   - **(b) tronqués** : JSON partiel top-level ET sous-objet coupé (`author: {}` — `name` requis manquant → `_$decodeModel` capte → `author == null`, le parent survit ; `coauthors` avec un élément tronqué → filtré via `whereType`).
   - **(c) champs inconnus** : clés futures non reconnues (`{'title':'X','__future_key__':42,'nested_future':{...}}`) → **ignorées**, aucun throw, champs connus décodés normalement.
   - **(d) enums inconnus** : valeur d'enum future/retirée (`status:'legacyRemoved'`, `status:'futureStatus'`) → repli `defaultValue` (`ArticleStatus.draft`), jamais de throw (`_$enumFromName → null → ?? draft`).
   - **(e) types faux** : `String` au lieu d'`int` (`views:'abc'→0`, mais coercition douce `views:'42'→42`), `Map` au lieu de `List` (`tags:{}→[]`, `coauthors:{}→[]`), non-`bool` (`published:1→false`), non-`Map` pour un sous-modèle (`author:'x'→null`), `List` mixte (`tags:['a',7,null]→['a']`).
   - **(f) clés non-`String` (régression H1)** : sous-objet forgé/Hive `Map<dynamic,dynamic>` à clés `int`/mixtes (`author:{1:'a', 2:'b'}`) → `_$asStringMap` coerce en `String` ou retombe `null` SANS throw → parent survit.
   - **(g) `null` partout** : chaque champ explicitement `null` (`{'id':null,'title':null,'views':null,...}`) → tous les champs prennent leur repli, `title→''`, le parent se construit.
2. **Invariant universel « le parent survit »** — pour CHAQUE cas du corpus, `Article.fromMap(cas)` (voie codegen directe) se construit TOUJOURS et **ne lève JAMAIS d'exception** ni d'`Error` (assertion `returnsNormally` + assertions ciblées sur les valeurs de repli attendues). Idem pour le sous-modèle `Author.fromMap` sur ses cas propres.
3. **Voie registre codegen prouvée défensive** — le corpus exerce aussi la **frontière registre** pour le chemin **codegen** : `registerArticle(registry)` puis `registry.decode('article', cas)` **ne lève jamais** sur aucun cas du corpus (le `fromMap` généré étant intrinsèquement défensif, la voie stricte du registre l'est aussi POUR LES MODÈLES GÉNÉRÉS). Ceci matérialise explicitement la frontière AD-10 au niveau registre pour la voie codegen.
4. **Tag & branchement gate (no-op → corpus réel)** — le(s) fichier(s) de corpus sont taggés `@Tags(['serialization-compat'])` (tag déjà déclaré dans `dart_test.yaml`), vivent dans un package doté d'un dossier `test/`, et sont donc exécutés tels quels par `scripts/ci/verify_serialization.dart` (`<runner> test --tags serialization-compat`) **sans aucune modification du script ni du workflow**. Après E2-10, le slot exécute un corpus **réel** (≥ le nombre de familles), non plus la seule amorce E2-5.
5. **Le gate ÉCHOUE sur régression (prouvé)** — il est **démontré** (procédure documentée dans les Completion Notes, non committée) qu'un cas régressif — une attente inversée `expect(() => Article.fromMap(cas), returnsNormally)` remplacée par un décodeur STRICT qui throw — fait bien passer `dart test --tags serialization-compat` **RC ≠ 0** et `verify_serialization.dart` **exit 1**. Le gate n'est donc pas décoratif : il capte réellement une régression AD-10.
6. **Intégré au `verify`/CI de merge** — `dart run scripts/ci/verify_serialization.dart` (et l'agrégat `verify` / `prove_gates.dart`) restent **RC=0** avec le corpus en place ; la CI GitHub Actions (E1-3) l'exécute avant tout `done`. Vérif verte bout en bout rejouée : `melos run generate` OK → `melos run analyze` RC=0 → `melos run test` RC=0 → `verify:serialization` RC=0.
7. **Évolution additive documentée** — le corpus documente en tête (docstring) la discipline AD-10 « additif seulement » et sert de **fixture de non-régression de montée de version** : un cas « document v(n) lu par le code v(n+1) » (champ ajouté absent → default) et un cas « document v(n+1) lu par le code v(n) » (champ inconnu ignoré) sont présents (recouvrent familles a & c) et explicitement étiquetés comme la garantie de compat ascendante/descendante.
8. **Périmètre MEDIUM-1 E2-6 tranché & consigné** — la story TRANCHE et documente le sort du finding MEDIUM-1 d'E2-6 (voie défensive `fromMapSafe`/`decodeSafe` non atteignable via `ZcrudRegistry.decode` pour les **adaptateurs**) : **couvert ici pour la voie codegen** (AC3), **déféré à E5** pour la voie **adaptateur** (`JsonSerializableAdapter`/`ReflectableCodec`), avec note écrite dans la story ET report à consigner dans la story E5 (cf. § « Décision MEDIUM-1 »). Aucune modification du contrat gelé `ZcrudRegistry` (E2-3) dans cette story.

## Tasks / Subtasks

- [x] **T1. Concevoir le module de fixtures partagé** (AC: 1, 7)
  - [x] Créer `packages/zcrud_generator/test/models/serialization_corpus.dart` : liste `const List<CorpusCase>` (`CorpusCase = ({String name, String family, Map<Object?, Object?> map})`) de cas nommés, **groupés par famille (a)…(g)**, chaque entrée portant le libellé de famille et un commentaire du repli attendu.
  - [x] Inclure les cas de montée de version (AC7) : `historique_v_n_champ_ajoute_absent` (famille a) et `futur_v_n1_champ_inconnu_ignore` (famille c), étiquetés « compat ascendante/descendante ».
  - [x] Pour la famille (f), utiliser des littéraux `Map` à clés non-`String` **dans les sous-objets** (`author: <Object?,Object?>{1:'a'}`) — d'où le type de `map` en `Map<Object?, Object?>`. Les clés TOP-LEVEL restent `String` (contrat repository), coercé au point d'appel via `asTopLevelMap(c)`.
- [x] **T2. Écrire le corpus test codegen (voie directe)** (AC: 1, 2, 7)
  - [x] Créer `packages/zcrud_generator/test/serialization_corpus_test.dart`, `@Tags(['serialization-compat'])` + `library;`.
  - [x] Itérer le corpus : pour chaque cas, `test('[<famille>] <name> — le parent survit', () { expect(() => Article.fromMap(asTopLevelMap(c)), returnsNormally); })` **+** assertions ciblées de repli par famille (valeurs attendues d'AC1).
  - [x] Cas propres à `Author.fromMap` : **comportement OBSERVÉ documenté** — `Author.fromMap({})` NE lève PAS et renvoie `Author(name:'')` (le `fromMap` généré du sous-modèle est lui-même défensif : `name` non-`String` → `''`). Un `author` présent-mais-partiel devient donc `Author(name:'')`, PAS `null` ; seul un `author` **non-Map** s'effondre en `null`. Consigné sans modifier le codegen (cf. ambiguïtés tranchées, Dev Notes).
  - [x] **Amorce E2-5 non dupliquée** (`serialization_compat_test.dart` conservé tel quel).
- [x] **T3. Écrire le corpus test voie registre (codegen)** (AC: 3)
  - [x] Même fichier : `final registry = ZcrudRegistry(); registerArticle(registry);` puis pour chaque cas `expect(() => registry.decode('article', asTopLevelMap(c)), returnsNormally)` + un cas prouvant que `decode` renvoie bien un `Article` décodé défensivement.
  - [x] Import de la surface **pure** `package:zcrud_core/edition.dart` uniquement (test sous `dart test`).
- [x] **T4. Prouver que le gate capte une régression** (AC: 5)
  - [x] Probe ÉPHÉMÈRE (NON committée, supprimée après) : test taggé avec décodeur strict `m['views'] as int` sur `'abc'` → `dart test --tags serialization-compat` **RC=1** ; `dart run scripts/ci/verify_serialization.dart` **exit 1**. Après suppression : `dart test` **RC=0**, `verify_serialization` **RC=0**. Consigné en Completion Notes.
- [x] **T5. Vérif verte bout en bout & intégration gate** (AC: 4, 6)
  - [x] `melos run generate` OK (Article.g.dart régénéré, gitignoré) → `melos run analyze` RC=0 → `melos run test` RC=0.
  - [x] `dart run scripts/ci/verify_serialization.dart` → RC=0 (52 tests `serialization-compat` dans `zcrud_generator`, runner `dart`).
  - [x] `melos run verify` RC=0 + `dart run scripts/ci/prove_gates.dart` → RC=0 (22 OK / 0 FAIL).
- [x] **T6. Documentation AD-10 & décision MEDIUM-1** (AC: 7, 8)
  - [x] Docstring en tête du corpus : discipline « additif seulement », rôle de gate de merge, renvoi AD-10, comportement observé du codegen défensif.
  - [x] Décision MEDIUM-1 consignée (couvert codegen ici / déféré adaptateur E5) dans la § dédiée + Dev Notes (report à porter au `create-story` E5).

## Dev Notes

### État réel du terrain (vérifié sur disque)

- **Générateur E2-5 (`done`) — `fromMap` DÉFENSIF par construction.** `packages/zcrud_generator/test/models/article.g.dart` (généré, gitignoré) contient les helpers défensifs que le corpus doit exercer :
  - `_$asInt/_$asDouble/_$asNum` : coercition douce (`String`→num via `tryParse`), sinon `null` (→ repli via `?? 0`).
  - `_$asDateTime` : `String` ISO→`DateTime` via `tryParse`, sinon `null`.
  - `_$enumFromName<T>(values, name)` : `name` non-`String` ou hors domaine → `null` (→ `?? ArticleStatus.draft`). **C'est le `unknownEnumValue`/`defaultValue` d'AD-10.**
  - `_$asStringMap(v)` : coerce toute `Map` (y compris clés non-`String` Hive/forgées) en `Map<String,dynamic>` dans un `try/catch`, sinon `null`. **C'est la protection régression H1 (famille f).**
  - `_$decodeModel<T>(v, fromMap)` : `_$asStringMap` puis `fromMap` sous `try/catch` → toute anomalie (non-map, clés non-`String`, `fromMap` qui throw) retombe `null`. **Sous-objet corrompu → parent survit** (famille b) ; en liste, filtré via `whereType` (famille e).
  - `_$ArticleFromMap` (l.79-100) : garde `is String`/`is bool`/`is List` + helpers → **aucune ligne ne peut throw** sur entrée corrompue. `title` non-`String`→`''` ; `tags` non-`List`→`const []` ; `author` via `_$decodeModel` ; `coauthors` `.map(_$decodeModel).whereType<Author>()`.
- **Modèle de preuve** `packages/zcrud_generator/test/models/article.dart` : couvre `@ZcrudId` nullable, scalaires requis/nullable (`String`/`int`/`double`/`bool`), enum ouvert `ArticleStatus{draft,published,archived}` avec `defaultValue: draft`, `DateTime?` (clé persistée `created_at`), `List<String> tags` (multiple), sous-modèle `Author?` et **liste de sous-modèles** `List<Author> coauthors`. **Ce modèle est suffisant pour couvrir les 7 familles** — pas besoin d'un nouveau modèle.
- **Slot gate E1-3 + amorce E2-5.** `scripts/ci/verify_serialization.dart` : parcourt `packages/`, pour chaque package avec `test/` exécute `<runner> test --tags serialization-compat` (`runner` = `flutter` si pkg Flutter, sinon `dart` ; `zcrud_generator` est **pur-Dart** → `dart`). `exit 79` (aucun test taggé) toléré. **Aujourd'hui** : seul `zcrud_generator/test/serialization_compat_test.dart` (2 tests, semé E2-5) porte le tag → le slot n'est déjà PLUS un no-op vide mais reste une amorce. **E2-10 le remplit.** `dart_test.yaml` déclare déjà le tag `serialization-compat` (pas d'avertissement).
- **Registre E2-3 (gelé).** `packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart` : `Object decode(String kind, Map<String,dynamic> map)` (l.125) délègue au `fromMap` enregistré via `register<T>(kind, fromMap:, toMap:, …)`. **Pour un modèle CODEGEN, ce `fromMap` est le `_$…FromMap` défensif** → `decode` est défensif. `registerArticle(registry)` (généré, l.189) fait ce câblage. **Aucune signature à modifier.**

### Où vivent les fixtures & pourquoi

- **Décision : tout dans `packages/zcrud_generator/test/`**, runner **`dart`** (pur-Dart, rapide, pas de `dart:ui`). Le modèle `Article`/`Author` et son `.g.dart` défensif y sont déjà ; le registre (`ZcrudRegistry`, surface pure `edition.dart`) est importable sous `dart test` (déjà fait par les tests E2-5). Cela garde **codegen direct (AC2) ET voie registre (AC3) dans un seul package**, sans dépendre de Flutter, et évite de dupliquer le modèle dans `zcrud_core` (package Flutter, runner plus lourd).
- **Fixtures = module partagé** `models/serialization_corpus.dart` (liste de cas nommés par famille) consommé par le(s) test(s) codegen ET registre → une seule source de vérité du corpus, itérée deux fois (voie directe + voie registre). Cela **prouve le gate** : ajouter un cas cassant fait échouer les deux voies.

### Comment `verify:serialization` passe de no-op à corpus réel

1. **Convention stable (E1-3)** : le script sélectionne les tests par **tag** `serialization-compat`, pas par nom de fichier. **E2-10 n'a donc rien à câbler** : déposer des fichiers `@Tags(['serialization-compat'])` dans `zcrud_generator/test/` suffit à les faire exécuter.
2. **Avant E2-10** : 2 tests taggés (amorce E2-5) → slot vert mais quasi-vide.
3. **Après E2-10** : corpus des 7 familles × (voie directe + voie registre) → le slot exécute un **corpus réel** ; `verify_serialization.dart` reste RC=0 tant que la désérialisation défensive tient, **RC=1** dès qu'un cas casse le parent (prouvé en T4).

### Décision MEDIUM-1 (E2-6) — TRANCHÉE

- **Finding** (`code-review-e2-6.md` MEDIUM-1) : la voie défensive `fromMapSafe` des **adaptateurs** (`ZModelAdapter.fromMapSafe` / `JsonSerializableAdapter`) n'est **pas atteignable via `ZcrudRegistry.decode`** : le registre n'enregistre que la voie **stricte** (`fromMap`), qui **lève** sur une map corrompue pour un modèle **adaptateur** (dont le `fromMap` = `fromJson` lex non défensif). Le mode `fromMapSafe` ne vit que sur l'instance d'adaptateur, inatteignable par E5 qui ne détient que le `ZcrudRegistry`.
- **Tranche E2-10** :
  - ✅ **Couvert ICI (voie codegen)** : AC3 prouve que `registry.decode('article', corrompu)` **ne lève jamais** pour un modèle **généré** — car son `fromMap` EST défensif. La frontière AD-10 au niveau registre est donc **réellement câblée et testée pour la voie codegen** (la voie du schéma canonique porté de lex_douane via le builder zcrud).
  - ⏭️ **Déféré à E5 (voie adaptateur)** : le gap concerne exclusivement les modèles branchés par **adaptateur** (`JsonSerializableAdapter` lex / `ReflectableCodec` DODLP), dont le `fromMap` strict enregistré peut throw. Le corriger exige **soit** qu'E5 conserve la référence d'adaptateur pour appeler `fromMapSafe`, **soit** d'exposer **additivement** une `decodeSafe(kind, map) → Object?` sur `ZcrudRegistry` — ce qui **modifie un contrat gelé (E2-3) et touche la frontière où arrivent réellement les documents Firestore corrompus (E5)**. Hors-périmètre E2-10 (story de couverture de gate, pas de modification de contrat).
- **Rationale de la coupe** : E2-10 est mandatée pour prouver la désérialisation **défensive du codegen** + activer le gate ; le gap adaptateur est un **problème d'évolution de contrat + de frontière repository** dont le lieu naturel est **E5** (là où `registry.decode` est invoqué sur des données non fiables). Couvrir la voie codegen ici rend la garantie AD-10 **testée pour le chemin canonique** ; déférer la voie adaptateur évite un empiètement sur E2-3/E5.
- **Action de suivi (à porter en E5)** : consigner dans la story E5 l'exigence « frontière défensive AD-10 pour les modèles **adaptateur** : `decodeSafe(kind, map)` additif sur `ZcrudRegistry` OU rétention des adaptateurs pour `fromMapSafe`, + test sur documents Firestore corrompus ». L'orchestrateur reprend ce report au `create-story` d'E5.

### Contraintes AD applicables (rappel non-négociable)

- **AD-10** : le parent ne casse jamais ; **additif seulement**. Le corpus est la preuve exécutable.
- **AD-3** : zéro `reflectable` dans le moteur ; le corpus reste sur codegen pur (aucun import reflectable).
- **AD-1** : ne rien introduire qui fasse dépendre `zcrud_core` d'un autre package zcrud ; fixtures cantonnées à `zcrud_generator/test/`.
- **Key Don'ts** : ne **jamais** éditer `article.g.dart` à la main ni le committer (gitignoré, régénéré par `melos run generate`/CI). Le corpus dépend du `.g.dart` **régénéré**, pas d'un `.g.dart` figé.

### Project Structure Notes

- Fichiers touchés (NEW, tests uniquement) :
  - `packages/zcrud_generator/test/models/serialization_corpus.dart` (fixtures partagées)
  - `packages/zcrud_generator/test/serialization_corpus_test.dart` (voie codegen directe + voie registre, `@Tags(['serialization-compat'])`)
  - *(option)* `packages/zcrud_generator/test/serialization_corpus_registry_test.dart` si séparation souhaitée
- Fichiers **inchangés** : `article.dart`/`article.g.dart` (E2-5), `serialization_compat_test.dart` (amorce E2-5 conservée), `scripts/ci/verify_serialization.dart` (branchement stable), `dart_test.yaml` (tag déjà déclaré), tout `zcrud_core`/adaptateurs (E2-6).
- **Aucune** écriture du `sprint-status.yaml` par cette story (géré par l'orchestrateur).

### Testing standards

- Runner : `dart test` dans `packages/zcrud_generator` (pur-Dart). Tag obligatoire `@Tags(['serialization-compat'])` + `library;` en tête (sinon l'annotation de bibliothèque est invalide).
- Style d'assertion : `returnsNormally` pour l'invariant universel (AC2/AC3) **+** assertions de valeur de repli par famille (preuve que le repli est le bon, pas juste « ça ne throw pas »).
- Le corpus doit être **itératif** (une boucle sur la liste de fixtures) pour que l'ajout d'un cas régressif casse mécaniquement le gate (AC5).

### References

- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-10 — Évolution de schéma additive & désérialisation défensive]
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#Story E2-10] (rattachée à E1-3, gate de merge)
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#Story E1-3] (slot/gates CI)
- [Source: scripts/ci/verify_serialization.dart] (branchement stable par tag ; no-op → corpus)
- [Source: packages/zcrud_generator/test/models/article.dart] + `article.g.dart` (helpers défensifs `_$asStringMap`/`_$decodeModel`/`_$enumFromName`)
- [Source: packages/zcrud_generator/test/serialization_compat_test.dart] (amorce E2-5, à compléter sans dupliquer)
- [Source: packages/zcrud_generator/dart_test.yaml] (tag `serialization-compat` déclaré)
- [Source: packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart#decode] (voie registre, contrat gelé E2-3)
- [Source: _bmad-output/implementation-artifacts/stories/code-review-e2-6.md#MEDIUM-1] (décision couvrir codegen / déférer adaptateur E5)
- [Source: CLAUDE.md] (gates CI E2-10↔E1-3 ; désérialisation défensive ; Key Don'ts codegen)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

- `melos run generate` → SUCCESS (`article.g.dart` régénéré, gitignoré).
- `melos run analyze` → RC=0 (SUCCESS sur tous les packages).
- `dart test --tags serialization-compat` (zcrud_generator) → RC=0, **52 tests** (vs 2 amorce E2-5).
- `dart run scripts/ci/verify_serialization.dart` → RC=0 (corpus réel, runner `dart` sur zcrud_generator).
- `melos run test` → RC=0 (zcrud_generator: 80, zcrud_core: 198, zcrud_get: 17, zcrud_provider: 8, zcrud_riverpod: 8, zcrud_annotations: 8 — parité ×4 verte).
- `melos run verify` → RC=0 ; `dart run scripts/ci/prove_gates.dart` → RC=0 (**22 OK / 0 FAIL**).
- Invariants : `melos list` = 14 ; CORE OUT = 0 (aucune dep zcrud sortante de zcrud_core) ; 0 `.g.dart` suivi par git.

### Completion Notes List

**Ambiguïtés tranchées (comportement OBSERVÉ du codegen, non modifié — cf. story T2 « documenter sans modifier ») :**
- (1) `author: {}` (famille b) → le libellé d'AC1 supposait `author == null` via `_$decodeModel`. **Réalité du codegen E2-5** : `_$AuthorFromMap` est lui-même défensif (`name` non-`String` → `''`), il NE lève pas ; une map vide/partielle donne donc `Author(name:'')`, PAS `null`. Le corpus asserte le comportement réel (`author != null`, `author.name == ''`) et documente que seul un `author` **non-Map** s'effondre en `null`. L'invariant AD-10 (parent survit) est prouvé dans les deux lectures.
- (2) Famille (f) clés non-`String` : `author:{1:'a',2:'b'}` → `_$asStringMap` coerce en `{'1':'a','2':'b'}` SANS throw ; aucune clé `name` → `Author(name:'')`. Ajout d'un cas `author_cles_mixtes_avec_name` (`{'name':'Bob', 1:'x'}`) prouvant que la coercition H1 **préserve** les vrais champs malgré une clé int.
- (3) `coauthors` avec éléments tronqués (famille b) : seuls les éléments **non-Map** (`'bad'`, `7`) sont filtrés via `whereType` ; un élément Map vide devient `Author('')` conservé → `coauthors.length == 1`. Asserté tel quel.

**Preuve que le gate capte une régression (AC5, T4) — probe éphémère NON committée :**
- AVEC probe (décodeur strict `m['views'] as int` sur `'abc'`, taggé) : `dart test --tags serialization-compat` → **RC=1** (Failing tests) ; `dart run scripts/ci/verify_serialization.dart` → **exit 1**.
- APRÈS suppression de la probe : `dart test --tags serialization-compat` → **RC=0** ; `verify_serialization.dart` → **RC=0**. Le gate n'est donc pas décoratif.

**Couverture 7 familles × 2 voies :** 21 fixtures (a:2, b:2, c:1, d:3, e:9, f:2, g:1) itérées sur voie codegen directe (`Article.fromMap`) ET voie registre (`ZcrudRegistry.decode('article', …)`), + assertions ciblées de repli par famille + cas `Author.fromMap` seul.

**Décision MEDIUM-1 (E2-6) :** couverte ICI pour la **voie codegen** (AC3 : `registry.decode('article', corrompu)` ne lève jamais car le `fromMap` généré est défensif). La **voie adaptateur** (`JsonSerializableAdapter`/`ReflectableCodec`, `fromMap` strict enregistré pouvant throw) est **déférée à E5** — contrat gelé `ZcrudRegistry` (E2-3) NON modifié ici. Report à porter au `create-story` d'E5 : « frontière défensive AD-10 pour modèles adaptateur : `decodeSafe(kind, map)` additif OU rétention d'adaptateur pour `fromMapSafe`, + test sur documents Firestore corrompus ».

### File List

- `packages/zcrud_generator/test/models/serialization_corpus.dart` (NEW — corpus partagé des 7 familles, source unique de vérité)
- `packages/zcrud_generator/test/serialization_corpus_test.dart` (NEW — voie codegen directe + voie registre, `@Tags(['serialization-compat'])`)
