---
baseline_commit: 448616b4a9f982fa017737f5dd4898fb9cc938d8
---

# Story ES-11.1 : Binding GetX — injection/lifecycle du cœur `zcrud_study` vers GetX/get_it (`zcrud_get`)

Status: review

<!-- Créée par bmad-create-story (skill réel `bmad-create-story`, tool Skill). Cycle BMAD strict. NE PAS éditer le sprint-status ici (ressort de l'orchestrateur). -->

## Story

As a **développeur DODLP (hôte GetX/get_it)**,
I want **un sous-arbre `zcrud_get/lib/src/study/` branchant le port générique `ZStudyRepository<T>` et la primitive PURE `ZStudySessionSelector` du kernel sur l'idiome GetX/get_it — l'égalité profonde de `ZStudySessionConfig` (contrat de caching du manager) étant fournie CÔTÉ binding, comme le MIROIR exact d'ES-10.1 (Riverpod)**,
So that **je peux consommer `zcrud_study` sous GetX sans que le kernel ni le cœur ne connaissent GetX, le controller/observable de session étant réutilisé (jamais recréé) quand la valeur profonde de la config n'a pas changé (objectif produit n°1, SM-1), et sans que le binding ne dépende d'aucun package d'ENTITÉ concrète (R28)**.

---

## Contexte & état réel validé sur disque (le 2026-07-16)

> **Ne rien réinventer.** Le binding `zcrud_get` EXISTE déjà (livré en E2-9). Cette story **ajoute** un sous-arbre `lib/src/study/`, elle ne recrée NI la coquille NI le scope/resolver de présentation. C'est le **MIROIR GetX d'ES-10.1** (dont le patron est repris champ pour champ).

### `zcrud_get` — état réel (vérifié)

- **`packages/zcrud_get/` EXISTE** et est un package **Flutter** — `pubspec.yaml` : `flutter: sdk: flutter` + `get: ^4.7.2` + `get_it: ^8.0.3` + `reflectable: ^5.2.3` (exception `ReflectableCodec` DODLP, chemin allowlisté) ; `dev_dependencies` : `flutter_test`, `binding_conformance: ^0.0.1`. ⇒ **R14 : les tests se lancent via `flutter test`, JAMAIS `dart test`.**
- **Dépendances `zcrud_*` actuelles** : `zcrud_core` **UNIQUEMENT** (out-degree runtime `zcrud_*` = 1). ⇒ cette story introduit la **première arête de fan-in** `zcrud_get → zcrud_study_kernel` (cf. § Graphe). `get`/`get_it`/`reflectable`/`flutter` **ne sont PAS des `zcrud_*`** ⇒ non comptés par `graph_proof.py` (CORE OUT=0 inchangé).
- Déjà présent (E2-9, à **RÉUTILISER tel quel**, ne pas dupliquer) :
  - `lib/src/presentation/zcrud_get_scope.dart` — `ZcrudGetScope` (monte/réutilise un `GetIt`, y crée/scope/**dispose** le `ZFormController` selon le lifecycle du manager avec **gardes d'appartenance** MEDIUM-2/LOW-1, bridge GetX optionnel `Get.put`/`Get.delete`, puis enveloppe un `ZcrudScope` porteur du resolver). **Patron lifecycle/dispose canonique à réutiliser — ne pas y toucher.**
  - `lib/src/presentation/z_get_resolver.dart` — `ZGetResolver extends ZDependencyResolver` : `resolve<T>()` interroge le `GetIt` du scope **par `Type`** (escape hatch `type:` pour franchir le `T` non borné du cœur) et **lève `ZScopeError` (message actionnable) si `T` n'est pas enregistré** (« seams throw », AD-6 — jamais de résolution silencieuse). **C'est le point d'injection des repos** : un `ZStudyRepository<T>` concret est fourni par l'app via le locator, jamais par un import concret dans le binding.
  - `lib/src/data/codecs/reflectable_codec.dart` — `ReflectableCodec` (E2-6, hors périmètre de cette story ; **ne pas toucher**).
  - Barrel `lib/zcrud_get.dart` ; tests `test/presentation/*` (`z_get_parity_test.dart` parité rebuild du formulaire via `binding_conformance`, `zcrud_get_scope_test.dart`) + `test/purity/idiom_isolation_test.dart` (garde : **aucun idiome Riverpod/provider** dans `lib/` — scan **récursif**) + `test/data/codecs/*`.

### Le kernel `zcrud_study_kernel` — surface consommée (vérifiée, inchangée)

- **`ZStudySessionConfig` VIT dans `zcrud_study_kernel`** (`lib/src/domain/z_study_session_config.dart`, `@ZcrudModel(kind: 'study_session_config')`, `g.dart` committé). Champs : `mode` (`ZReviewMode`, défaut `spaced`), `folderId` (`String?`), `tagIds` (`List<String>?`), `types` (`List<String>?`), `count` (`int?`), `extension` (`ZExtension?`), `extra` (`Map<String,dynamic>` normalisée via `zNormalizeExtra`). **Elle porte DÉJÀ un `operator ==`/`hashCode` par VALEUR profonde** (7 champs, `zJsonEquals(extra)`), **une seule forme persistable, round-trip AD-10**. **NE PAS ajouter de seconde forme dans le kernel** (AD-24). `copyWith` disponible (utile aux tests mono-champ).
- **Port générique** : `ZStudyRepository<T extends ZEntity>` (`z_study_repository.dart`, exporté par le barrel kernel). `watchAll()`/`watch()` = `Stream<List<T>>` **NUS** (AD-5) ; `save`/`softDelete`/`count`/`sync` = `Future<ZResult<T>>` = `Either<ZFailure,T>` (AD-11). Backend-agnostique.
- **Primitive de sélection PURE** : `ZStudySessionSelector` (`z_study_session_selector.dart`, exportée) — `const ZStudySessionSelector(this.config)`, getter `config`, méthodes pures `matches`/`selectFrom<T>` (filtres dossier ∧ tags ∧ types + plafond `count`, ordre préservé, sans état/I/O). **Réutiliser telle quelle, ne JAMAIS réimplémenter la sélection.**
- **Barrel kernel** (`zcrud_study_kernel.dart`) exporte `z_study_repository.dart`, `z_study_session_config.dart` (`hide ZStudySessionConfigZcrud`), `z_study_session_selector.dart`, `z_session_candidate.dart`, `z_study_session_result.dart`. ⇒ **`zcrud_study_kernel` est le point d'agrégation** suffisant pour un branchement GÉNÉRIQUE sur `ZStudyRepository<T>` + la clé `ZStudySessionConfig`. `zJsonEquals`/`zJsonHash` viennent de `zcrud_core` (le barrel kernel ne les réexporte pas → importer explicitement `zcrud_core`).

### Le MODÈLE à miroiter — ES-10.1 (Riverpod), livré et DONE

`zcrud_riverpod/lib/src/study/` contient exactement le patron à transposer en GetX :
- `z_session_config_key.dart` — `ZSessionConfigKey` : enveloppe `ZStudySessionConfig`, `operator ==`/`hashCode` **par VALEUR profonde sur les 7 champs** (AD-24, égalité de clé **au binding**).
- `z_study_providers.dart` — `zStudyRepositoryProvider<T>()` (**seam** qui *throw* `ZScopeError`), `zStudyWatchAllProvider<T>({repo})` (`StreamProvider.autoDispose` du flux nu `watchAll()`), `zStudySessionSelectorProvider` (`family` clée par `ZSessionConfigKey` déléguant à la primitive PURE — **dedup SM-1**).
- Tests : `z_session_config_key_equality_test.dart` (**7 cas mono-champ**, R27), `z_session_family_rebuild_test.dart` (**SM-1**, compteur de builds `1→2` sous keying identité), `z_study_providers_test.dart` (ré-émission exacte + seam throw + auto-dispose `onCancel`), `z_binding_backend_isolation_test.dart` (aucun backend en code/pubspec).

> **La transposition n'est PAS littérale : Riverpod a `family` + dedup par `==`/`hashCode` de clé ; GetX N'A PAS de family.** Le mécanisme GetX natif de réutilisation d'instance est l'indexation **`Type` + `tag` (String)** du gestionnaire d'instances (`Get.put`/`Get.find`/`Get.isRegistered(tag:)`). Le miroir de la clé de family est donc **un `tag` déterministe dérivé de l'égalité profonde** : deux configs structurellement égales ⇒ **même `tag`** ⇒ GetX réutilise la **même** instance (dedup). C'est ce `tag` qui matérialise SM-1 côté GetX (cf. AC2/AC3).

---

## Décision d'architecture centrale — AD-24 + R28 (le double garde-fou de conception)

> **[Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-24 ; stories/epic-es-10-retrospective.md#R28/R27.4]**

### AD-24 — égalité profonde AU BINDING (miroir GetX)

*Une seule* forme `ZStudySessionConfig` (persistable, round-trip) vit dans `zcrud_study_kernel`. **Le contrat de caching du gestionnaire d'état** (la clé qui décide si l'instance est réutilisée ou recréée) vit **DANS LE BINDING**, jamais dans le kernel/cœur — le domaine ne connaît pas GetX. Le kernel a DÉJÀ un `==` par valeur **légitime** (forme persistable) ; clef le cache directement dessus « marcherait » mais **localiserait la responsabilité de caching dans le kernel** (couplage inverse interdit, AD-15).

⇒ **Déliverable AD-24** : un type de clé possédé par `zcrud_get` — `ZSessionConfigKey` (sous `lib/src/study/`) — qui enveloppe une `ZStudySessionConfig`, **réimplémente son égalité profonde par VALEUR sur les 7 champs** (`mode`, `folderId`, `tagIds` profond, `types` profond, `count`, `extension`, `extra` via `zJsonEquals`), **ET expose un `String get tag` DÉTERMINISTE** tel que **`a == b ⟺ a.tag == b.tag`** (le `tag` est la matérialisation GetX du contrat de caching). La garantie de dedup/no-rebuild **vit et se prouve dans `zcrud_get`**, indépendamment du `==` kernel.

### R28 — le binding NAÎT GÉNÉRIQUE (leçon centrale d'ES-10, à appliquer DÈS create-story)

> **[Source: stories/epic-es-10-retrospective.md#R28 ; §4/§9]** — ES-10.2 a d'abord fait dépendre le binding de 4 entités concrètes (fan-in typé) ⇒ conflit de frontière v1.x (EX-3 : `example/` forcé de tirer `zcrud_flashcard` déféré), invisible pour `graph_proof`, révélé **seulement** par `melos verify` REPO-WIDE. Décision verrouillée : **binding GÉNÉRIQUE**, spécialisation typée **app-side**.

**ES-11.1 est un SECOND fan-in binding — il doit naître générique, PAS répéter l'erreur d'ES-10.2 :**
- **Deps `zcrud_*` du binding = `zcrud_core` + `zcrud_study_kernel` UNIQUEMENT.** **AUCUNE** entité concrète (`zcrud_document`/`zcrud_note`/`zcrud_exam`/`zcrud_session`/`zcrud_flashcard`/`zcrud_mindmap`/`zcrud_study`). Le générique se paramètre par `T extends ZEntity` (port `ZStudyRepository<T>`) — il ne **nomme aucune** entité.
- **Spécialisation typée par entité = one-liner APP-SIDE** (composition-root DODLP), où l'entité est déjà légitimement tirée — **jamais** dans le binding réutilisable. Tracée en dette **DW-ES111-1** (miroir de DW-ES102-1).
- **Toute arête de fan-in ajoutée est validée contre la frontière v1.x (EX-3) par `melos run verify` REPO-WIDE avant tout `done`** — `graph_proof`/`melos list` verts NE suffisent PAS (R9/R28/leçon `ZExportApi`).

### R27.4 — le verrou vise le SYMBOLE PUBLIC consommé

> **[Source: stories/epic-es-10-retrospective.md#R27.4]** — un helper interne prouvé POWERFUL n'implique PAS que son câblage dans le point d'entrée public l'est. **Muter le SITE D'APPEL du symbole EXPORTÉ (barrel) doit rougir un test.** Ici : le test de dedup SM-1 doit exercer la **fonction/factory publique** que DODLP appellera (`zPutStudySessionSelector` / `buildStudyWatchController`), pas seulement `ZSessionConfigKey.tag` en isolation.

---

## Acceptance Criteria

> Chaque AC est **discriminant** (R12) et, quand il pose une garde, **co-livré avec un test à rouge provoqué** (R27, leçon centrale ES-9/ES-10). Les injections R3 sont listées §*Injections R3 prévues*. **Runner = `flutter test` (R14) ; RC capturé HORS pipe (R15).**

### AC1 — Controller GetX de flux study générique (le port `ZStudyRepository<T>`, flux nu re-émis exactement)

**Given** le port générique `ZStudyRepository<T extends ZEntity>` (kernel) et son flux `watchAll()` (`Stream<List<T>>` **nu**, AD-5)
**When** on fournit le sous-arbre `zcrud_get/lib/src/study/`
**Then** `zcrud_get` expose un **`GetxController` générique** `ZStudyWatchController<T extends ZEntity>` (idiome GetX, `package:get`) qui : (a) est construit à partir d'un `ZStudyRepository<T>` **résolu via le seam** (cf. AC4), (b) sur `onInit()` s'abonne au flux `watchAll()` et publie chaque émission **telle quelle** (ordre et contenu **préservés, sans transformation ni réordonnancement**) dans un observable exposé (`RxList<T>`/`Rx<List<T>>`), (c) l'écriture (`save`/`softDelete`) reste un `Future<ZResult<T>>` **non enveloppé** (le controller n'altère pas le contrat du port).
**Then** **AUCUN** symbole GetX/get_it n'apparaît dans `zcrud_study_kernel`/`zcrud_core` (garanti **structurellement** par le graphe — ils ne dépendent pas de `zcrud_get`, cf. AC6).

**Discriminant** — un controller qui ré-émet une liste **transformée/réordonnée/filtrée** échoue le test de séquence (la suite d'émissions observée ≠ la suite source). *(Le test drive `onInit()` puis observe la séquence d'un fake repo à `StreamController`.)*

### AC2 — Égalité profonde AU BINDING + `tag` déterministe (AD-24, miroir GetX de `ZSessionConfigKey`)

**Given** un cache d'instance destiné à être clé par `ZStudySessionConfig`
**When** on définit la clé côté binding
**Then** l'égalité profonde vit dans un type **possédé par `zcrud_get`** — `ZSessionConfigKey` (`lib/src/study/z_session_config_key.dart`) — avec `operator ==`/`hashCode` **par VALEUR profonde sur les 7 champs** (`mode`, `folderId`, `tagIds`/`types` via `zJsonEquals`, `count`, `extension`, `extra` via `zJsonEquals`) réutilisant `zJsonEquals`/`zJsonHash` de `zcrud_core` ; **jamais** une seconde forme ajoutée au kernel/cœur (le kernel garde **une seule** `ZStudySessionConfig`, inchangée — prouvé par `git status`).
**Then** `ZSessionConfigKey` expose **`String get tag` DÉTERMINISTE** vérifiant **`a == b ⟺ a.tag == b.tag`** : deux configs **structurellement égales mais d'identités distinctes** ⇒ `==` égales, `hashCode` identiques **et `tag` identiques** ; deux configs différant d'**exactement un champ** ⇒ `==` inégales **et `tag` différents**.

**Discriminant (R27 — leçon ES-9.3 MEDIUM-1 / ES-10.1, à NE PAS répéter)** — le test **varie CHAQUE champ un à un** (7 cas mono-champ : `mode`, `folderId`, `tagIds`, `types`, `count`, `extension`, `extra`) et asserte **à la fois** l'inégalité `==` **et** la divergence de `tag`, **jamais « tous à la fois »**. Neutraliser la comparaison d'un seul champ dans `==` **ou** l'exclure de la dérivation de `tag` DOIT faire **rougir** le cas correspondant (injections `R3-I2a..g`). Un cas `extra` **imbriqué** compare par `zJsonEquals` (valeur profonde), jamais par référence.

### AC3 — SM-1 : réutilisation d'instance sans recréation si la valeur profonde est inchangée (objectif produit n°1, via le `tag` GetX)

**Given** une factory publique de session déléguant à la primitive PURE `ZStudySessionSelector`, dédupliquant par le `tag` de `ZSessionConfigKey` dans le gestionnaire d'instances GetX
**When** on l'appelle deux fois avec deux `ZStudySessionConfig` **structurellement égales mais distinctes en mémoire**
**Then** le sélecteur est **construit UNE seule fois** et la **MÊME instance** est réutilisée (`identical` vrai) — GetX indexe par `Type`+`tag`, même `tag` ⇒ pas de recréation (**zéro rebuild** superflu, SM-1).
**When** on rappelle ensuite avec une config différant d'**un** champ
**Then** un **nouveau** sélecteur est construit (nouveau `tag` ⇒ instance distincte) — le compteur de constructions incrémente.
**Then** le corps de la factory **délègue** à `ZStudySessionSelector(key.config)` (primitive PURE kernel) — **jamais** la sélection réimplémentée.

**Discriminant (SM-1, R27.4)** — dériver le `tag` d'une composante d'**IDENTITÉ** (ex. `identityHashCode(config)`) ou d'une clé **shallow** (ignorant `extra`/`tagIds`/`types`) fait passer le compteur de constructions de **1 → 2** sur le cas « égales mais distinctes » ⇒ le test **rougit** (injection `R3-I3`). Le test exerce la **factory publique exportée** (R27.4), pas seulement `ZSessionConfigKey.tag` isolé.

### AC4 — Résolution par seam robuste (AD-6/AD-10) : throw actionnable, jamais silence

**Given** la construction d'un `ZStudyWatchController<T>` qui résout son `ZStudyRepository<T>` via un `ZDependencyResolver` (le `ZGetResolver`/get_it du `ZcrudGetScope`)
**When** aucun `ZStudyRepository<T>` n'est enregistré pour ce type
**Then** la résolution lève un **`ZScopeError` au message actionnable** contenant le `Type` manquant (réutilise le contrat existant de `ZGetResolver`) — **jamais** `null` silencieux ni crash non typé.

**Discriminant** — une factory qui capture l'absence de seam et retombe sur un repo par défaut/`null` masque l'erreur d'injection : le test asserte `throwsA(isA<ZScopeError>())` avec message contenant le `Type` (injection `R3-I4` : avaler le throw ⇒ le test rougit).

### AC5 — Cycle de vie GetX : `onClose` annule la souscription (aucune fuite — miroir de l'auto-dispose Riverpod)

**Given** un `ZStudyWatchController<T>` abonné au flux `watchAll()`
**When** le controller est démonté (`onClose()` — lifecycle GetX, ou via `Get.delete`/le `ZcrudGetScope`)
**Then** la souscription au flux du repo est **annulée** (`StreamSubscription.cancel()` dans `onClose()`) — le `onCancel` de la `StreamController` source est appelé, **aucune souscription pendante, aucune fuite**.

**Discriminant** — un controller qui **n'annule pas** la souscription dans `onClose()` garde le flux vivant : le test (fake repo à `StreamController(onCancel: …)`) montre `onCancel` **non appelé** après `onClose()` ⇒ rouge (injection `R3-I5` : retirer le `cancel()` de `onClose`). *(Le test drive `onInit()` → une émission → `onClose()`, puis asserte `onCancel` appelé.)*

### AC6 — Graphe acyclique, fan-in SORTANT, CORE OUT=0, R28 (AUCUNE entité) (AD-1)

**Given** le graphe de dépendances du monorepo (baseline mesurée **45 arêtes / 20 nœuds**, CORE OUT=0)
**When** on rejoue `python3 scripts/dev/graph_proof.py`
**Then** **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 46`** (**delta = +1** : nouvelle arête SORTANTE `zcrud_get → zcrud_study_kernel`, **seul** dep `zcrud_*` ajouté), 20 nœuds inchangés. L'arête va du **binding vers l'étage study**, **jamais l'inverse** (aucun package study ne dépend de `zcrud_get` ; le binding est un **PUITS**). Le commentaire d'invariant du `pubspec.yaml` de `zcrud_get` (qui affirme aujourd'hui « AUCUN autre `zcrud_*` que `zcrud_core` ») est **mis à jour**.

**Discriminant (R28)** — `graph_proof` refuse tout cycle (fatal) ; un delta ≠ +1 — en particulier une arête vers un package d'**ENTITÉ** (`zcrud_document`/`note`/`exam`/`session`/`flashcard`/`mindmap`) — fait diverger le compte et **DOIT** être retiré (injection `R3-I6`). `get`/`get_it`/`reflectable`/`flutter` ne sont pas des `zcrud_*` ⇒ n'entrent pas dans le compte ni ne changent CORE OUT.

### AC7 — Frontière v1.x (EX-3) préservée repo-wide — le binding ne tire aucune entité déférée

**Given** la frontière EX-3 (`example/` ne doit pas tirer transitivement `zcrud_flashcard`/`zcrud_mindmap`, entités E9/E10 déférées v1.x)
**When** on rejoue **`dart run melos run verify` REPO-WIDE**
**Then** **RC=0** : `example/` résout, aucune entité déférée tirée par `zcrud_get`, tous les gates verts (`gate:reserved-keys`, `gate:secrets`, `gate:web`, `codegen-distribution`, `verify:serialization`, isolement d'idiome).

**Discriminant (R28/R9)** — c'est **exactement** le cas d'ES-10.2 : une arête de fan-in vers une entité déférée est **VERTE** pour `graph_proof`/analyze ciblé mais **ROUGE** repo-wide. Un scan de code (AC8) + le pubspec générique (kernel seul) verrouillent l'absence d'entité **avant** `verify`.

### AC8 — Isolement backend & générique (R28/AD-5/AD-15) : ni backend, ni entité dans `lib/src/study/`

**Given** le sous-arbre `lib/src/study/` et le `pubspec.yaml`
**When** on rejoue les gardes de surface
**Then** (a) aucun symbole **backend** (`cloud_firestore`, `FirebaseFirestore`, `package:zcrud_firestore`, `package:hive`, type `Box`) n'apparaît dans le **code** de `lib/` (commentaires strippés — un dartdoc peut NOMMER la frontière, jamais la RÉFÉRENCER en code) ; (b) le `pubspec.yaml` (hors commentaires `#`) ne déclare **aucun** backend **ni aucun package d'ENTITÉ** `zcrud_*` (deps `zcrud_*` = `zcrud_core` + `zcrud_study_kernel` **exactement**) ; (c) la garde d'isolement d'idiome existante (`test/purity/idiom_isolation_test.dart`, scan **récursif** de `lib/`) reste verte — le nouveau dossier `lib/src/study/` est **couvert automatiquement** (aucun idiome Riverpod/provider ne s'y glisse ; GetX/get_it y sont autorisés).

**Discriminant** — ajouter `import 'package:cloud_firestore/…'` ou une dep entité au pubspec ⇒ la garde backend/entité **rougit** (et `graph_proof` diverge / `verify` casse) — injection `R3-I7`.

---

## Tasks / Subtasks

- [x] **T1 — `pubspec.yaml` : ajouter l'arête de fan-in `zcrud_study_kernel` + MAJ invariant** (AC6/AC8)
  - [x] Ajouter `zcrud_study_kernel: ^0.1.0` dans `dependencies:` (à côté de `zcrud_core`).
  - [x] **NE PAS** ajouter de package d'entité : **aucun** (R28 — fan-in = kernel seul).
  - [x] **Commentaire d'invariant mis à jour** (deps `zcrud_*` = core + study_kernel, AUCUNE entité, CORE OUT=0).
  - [x] `dart pub get` (workspace) RC=0, résolution `workspace`, sans conflit.

- [x] **T2 — `ZSessionConfigKey` : égalité profonde AU BINDING + `tag` déterministe (AD-24)** — `lib/src/study/z_session_config_key.dart` (**NOUVEAU**) (AC2)
  - [x] Classe immuable enveloppant `final ZStudySessionConfig config;`.
  - [x] `operator ==` par VALEUR sur les 7 champs (réutilise `zJsonEquals`/`zJsonHash` de `zcrud_core`).
  - [x] `hashCode` couvrant les **mêmes** champs (`Object.hashAll` + `zJsonHash`), cohérent avec `==`.
  - [x] **`String get tag` DÉTERMINISTE** dérivé des 7 champs (JSON canonique à clés récursivement triées, `jsonEncode`), garantissant `a == b ⟺ a.tag == b.tag`. Pas de `hashCode`/identité.
  - [x] Dartdoc : pourquoi ici et pas au kernel (AD-24) + pourquoi un `tag` (GetX vs family) + note R27.

- [x] **T3 — Branchement study GetX générique** — `lib/src/study/z_study_get.dart` (**NOUVEAU**) (AC1/AC3/AC4/AC5)
  - [x] `ZStudyWatchController<T extends ZEntity> extends GetxController` : `RxList<T> items` ; `onInit()` → `_sub = _repo.watchAll().listen(items.assignAll)` (ré-émission exacte) ; `onClose()` → `_sub?.cancel()` puis `super.onClose()` (AC5) ; getter `repository` (écritures brutes non enveloppées, AC1).
  - [x] **Factory de résolution par seam** : `buildStudyWatchController<T>(ZDependencyResolver resolver)` → throw `ZScopeError` actionnable si absent (AC4, non avalé).
  - [x] **Factory de sélection dédupliquée (SM-1)** : `zPutStudySessionSelector(key, {create})` — dedup GetX par `Type`+`key.tag`, délègue à `ZStudySessionSelector.new` (jamais réimplémentée) ; `create` injectable pour compter les constructions.
  - [x] Dartdoc : `tag` = miroir GetX de la family ; spécialisation typée = app-side (DW-ES111-1).

- [x] **T4 — Barrel** — `lib/zcrud_get.dart` (AC1/AC2/AC3)
  - [x] `export 'src/study/z_session_config_key.dart';` et `export 'src/study/z_study_get.dart';`. Exports E2-9 inchangés.

- [x] **T5 — Tests `flutter test` (R14)** — `packages/zcrud_get/test/study/` (**NOUVEAU dossier**)
  - [x] `z_session_config_key_equality_test.dart` (**AC2**) : égales-mais-distinctes ⇒ `==`/`hashCode`/`tag` identiques ; 7 cas mono-champ (`==` inégal ET `tag` différent) ; extra imbriqué (`zJsonEquals`) ; extra à ordre de clés différent ⇒ `tag` identique (canonique) ; extra profond divergent.
  - [x] `z_session_dedup_test.dart` (**AC3, SM-1**) : `addTearDown(Get.reset)` ; compteur `create` ; égales-mais-distinctes ⇒ 1 construction + `identical` vrai ; un champ change ⇒ 2 constructions. Exerce la factory publique (R27.4).
  - [x] `z_study_watch_controller_test.dart` (**AC1/AC4/AC5**) : fake repo `StreamController(onCancel:)` ; séquence exacte ; seam absent ⇒ `throwsA(isA<ZScopeError>())` (message contient le Type) ; seam présent ⇒ repo résolu ; écritures non enveloppées ; `onClose()` ⇒ `onCancel` appelé.
  - [x] `z_binding_study_isolation_test.dart` (**AC8**) : scan `lib/` (aucun symbole backend en code) ; scan `pubspec.yaml` (aucun backend ni entité `zcrud_*` — liste noire des 6 entités + backends).

- [x] **T6 — Garde d'isolement d'idiome (AC8c)** — `test/purity/idiom_isolation_test.dart` (scan récursif) couvre `lib/src/study/` automatiquement ; reste VERT (aucun idiome Riverpod/provider ; GetX autorisé). Aucune modification.

- [x] **T7 — Vérif verte rejouée** + MAJ File List / Dev Agent Record / Change Log. Suites E2-9 (`z_get_parity_test.dart`, `zcrud_get_scope_test.dart`, `idiom_isolation_test.dart`, codecs) restent VERTES (présentation E2-9 non touchée).

---

## Injections R3 prévues (mutation → AC rouge → restauration) — verrous LOAD-BEARING

> **R27** : chaque garde est **co-livrée** avec le test qui rougit sous sa neutralisation. Aucune garde « vœu ». **R27.4** : les injections SM-1 visent le **symbole public** (factory exportée), pas seulement le helper interne.

- **R3-I2a..g (AC2 — égalité + `tag` par CHAMP)** — dans `ZSessionConfigKey.==` **ou** la dérivation de `tag`, neutraliser **un seul** champ (ex. retirer `&& config.count == o.config.count`, ou exclure `count` du `tag`, ou remplacer `zJsonEquals(extra)` par `true`) ⇒ le cas mono-champ correspondant rougit (7 injections indépendantes). *(Leçon ES-9.3 MEDIUM-1 / ES-10.1 : « tous à la fois » ne suffit pas.)*
- **R3-I2h (AC2 — hashCode/tag cohérents)** — retirer un champ de `hashCode` (rompre `a==b ⇒ hash==hash`) ⇒ le cas « égales mais distinctes » rougit.
- **R3-I3 (AC3 — SM-1)** — dériver `tag` d'`identityHashCode(config)` (ou d'une clé shallow ignorant `extra`/`tagIds`/`types`) ⇒ le compteur de constructions passe **1 → 2** sur « égales mais distinctes » et `identical` devient faux ⇒ `z_session_dedup_test.dart` rougit. **Exercé via la factory publique** (R27.4).
- **R3-I4 (AC4 — seam throw)** — avaler le `ZScopeError` (retour `null`/repo par défaut) dans `buildStudyWatchController` ⇒ `throwsA(isA<ZScopeError>())` rougit.
- **R3-I5 (AC5 — lifecycle onClose)** — retirer le `_sub?.cancel()` de `onClose()` ⇒ le test `onCancel` (anti-fuite) rougit.
- **R3-I6 (AC6 — graphe/R28)** — ajouter une arête parasite (`zcrud_document`/`zcrud_note`/`zcrud_flashcard`/`crypto`/`http`) au pubspec ⇒ `graph_proof` compte ≠ 46 (justification impossible dans le périmètre 11.1) ; une arête vers une entité déférée ⇒ `melos verify` REPO-WIDE rouge (EX-3, AC7) ; tout cycle est fatal.
- **R3-I7 (AC8 — backend/entité en code)** — ajouter `import 'package:cloud_firestore/…'` (ou une dep entité) dans `lib/src/study/` ⇒ `z_binding_study_isolation_test.dart` rougit.

---

## Dev Notes

### Forme d'API retenue (guardrail, éviter la sur-ingénierie ET la traduction littérale)

**GetX n'a pas de family.** Ne PAS tenter de recopier `Provider.family` : le miroir GetX de la dedup par clé est l'indexation **`Type`+`tag`** du gestionnaire d'instances (`Get.put`/`Get.find`/`Get.isRegistered(tag:)`). Le `tag` déterministe de `ZSessionConfigKey` EST le contrat de caching (AD-24). Deux formes acceptables pour le controller de flux, au choix du dev, **documentées** :

1. **`GetxController` + souscription explicite** (recommandé, testable) : `_sub = repo.watchAll().listen(...)` dans `onInit`, `_sub?.cancel()` dans `onClose`. Discriminant `onCancel` net (R3-I5).
2. **`RxList.bindStream(repo.watchAll())`** (idiome GetX pur) : GetX annule la souscription à la fermeture du controller. Acceptable **si** le test prouve l'annulation (`onCancel`) au démontage — sinon préférer (1).

La spécialisation **typée par entité** (`ZStudyWatchController<ZStudyDocument>`, seam `ZStudyRepository<ZStudyDocument>`) est un **one-liner APP-SIDE** (DODLP composition-root) — **jamais** tirée ici (R28, dette DW-ES111-1). Le binding reste générique sur `T`.

### Pourquoi l'égalité (et le `tag`) vivent au binding alors que le kernel a déjà un `==` (le point subtil)

Le kernel a un `==` par valeur **légitime** (forme persistable, round-trip). Rien à changer côté kernel. AD-24 exige que **le contrat de caching du manager** (ici le `tag` GetX qui décide de la réutilisation d'instance) soit porté par un type **du binding** (`ZSessionConfigKey`), pour que : (a) le kernel ne devienne jamais garant d'un contrat GetX (couplage inverse interdit, AD-15) ; (b) la garantie no-recreation (SM-1) soit **prouvée localement** dans `zcrud_get` en variant chaque champ, indépendamment du `==` kernel. `ZSessionConfigKey` réutilise les primitives (`zJsonEquals`/`zJsonHash`) — il ne duplique pas la *normalisation* de `extra`, seulement la *responsabilité de clé*.

### Invariants AD applicables (rappel, NON-NÉGOCIABLES)

- **AD-1** — graphe acyclique, CORE OUT=0 ; fan-in **SORTANT** binding → study, jamais l'inverse ; baseline 45 → **46** (delta +1, kernel) ; binding = **PUITS**. **R28 : aucune entité.**
- **AD-2 / AD-15** — réactivité Flutter-native ; le cœur/kernel n'importe **PAS** GetX ; le code GetX/get_it-spécifique vit **exclusivement** dans `zcrud_get` ; SM-1 : pas de recréation d'instance quand la valeur profonde est inchangée (dedup par `tag`).
- **AD-4** — `String` opaque (`id`, `folderId`, `tagIds`) ; slot `extra`/`extension` versionné déjà porté par la config ; generics autorisés pour un **PORT** (`ZStudyRepository<T>`), jamais pour la sérialisation.
- **AD-5 / AD-11** — flux = `Stream<List<T>>` **nus** re-émis sans transformation ; écritures = `Either<ZFailure,T>` (`ZResult`). Le controller **enveloppe** un flux nu du port, il ne change pas le contrat.
- **AD-6** — seams **throw** (jamais de résolution silencieuse) — réutiliser `ZScopeError` de `ZGetResolver`.
- **AD-10** — défensif : un seam manquant lève une erreur **actionnable typée**, jamais un crash brut.
- **AD-24** — égalité profonde de `ZStudySessionConfig` (et le `tag`) **au binding**.
- **FR-26** — thème injecté (non concerné : ES-11.1 n'expose aucun widget ; les controllers/factories ne codent aucun style).

### Runner & fenêtre pub-get (R14/R15/R25)

- **R14** : `zcrud_get` est un package **Flutter** → **`flutter test`** (jamais `dart test`).
- **R15** : capturer le **RC HORS pipe** — `flutter test …; echo "RC=$?"` (jamais `| tail` qui masque le code retour).
- **R25** : cette story **ajoute une dépendance** (`zcrud_study_kernel`) ⇒ fenêtre `pub get`/bootstrap sensible : rejouer `dart pub get` (workspace) et confirmer résolution `workspace` sans conflit avant analyze/test.

### Ne rien réinventer / ne rien casser (régression)

- Réutiliser `ZcrudGetScope`, `ZGetResolver` (E2-9) **tels quels** — le nouveau code s'ajoute sous `lib/src/study/`, il ne modifie pas la présentation E2-9 ni `ReflectableCodec`.
- `z_get_parity_test.dart` (parité rebuild via `binding_conformance`) et `zcrud_get_scope_test.dart` (lifecycle/gardes d'appartenance) doivent **rester verts** : ne pas toucher au scope ni au resolver.
- Le controller de flux résout le repo **via seam** (locator/resolver), **jamais** par import d'un `…repository_impl` concret (briserait l'inversion de dépendance ET R28).

### R28 & frontière v1.x — le gate REPO-WIDE est NON-NÉGOCIABLE (leçon ES-10.2)

ES-11.1 est un **second fan-in binding**. Une arête vers une entité déférée v1.x (`zcrud_flashcard`/`mindmap`) serait **VERTE** pour `graph_proof`/analyze ciblé mais **ROUGE** repo-wide (EX-3 : `example/` ne résout plus). ⇒ **rejouer `dart run melos run analyze` ET `dart run melos run verify` REPO-WIDE** avant tout `review`/`done`. Un `graph_proof`/`secrets`/`melos list` verts NE remplacent PAS `melos verify` (précédent `ZExportApi`).

### Project Structure Notes

- **NOUVEAUX (lib)** : `lib/src/study/z_session_config_key.dart`, `lib/src/study/z_study_get.dart`.
- **NOUVEAUX (test)** : `test/study/z_session_config_key_equality_test.dart`, `test/study/z_session_dedup_test.dart`, `test/study/z_study_watch_controller_test.dart`, `test/study/z_binding_study_isolation_test.dart`.
- **MODIFIÉS** : `lib/zcrud_get.dart` (2 exports), `pubspec.yaml` (dep kernel + invariant).
- **INCHANGÉS** (ne pas toucher) : tout `lib/src/presentation/*`, `lib/src/data/*`, `test/presentation/*`, `test/purity/*`, `test/data/*`, `zcrud_study_kernel/*`, `zcrud_core/*`, `zcrud_riverpod/*`.
- API publique = barrel ; impl sous `lib/src/study/` (convention AD).
- Aucune `@ZcrudModel`/`@JsonSerializable` nouvelle ⇒ **aucun `*.g.dart` nouveau** attendu dans `zcrud_get` (rejouer `melos run generate` par prudence, cf. Vérif verte).

### Dette anticipée

- **DW-ES111-1 (miroir de DW-ES102-1)** — câblage DODLP app-side : (1) enregistrement des seams `ZStudyRepository<Entity>` au locator get_it/GetX de DODLP avec l'adapter firestore folder-scopé (`buildFolderScopedStudyRepository<Entity>`, livré ES-10.2 côté `zcrud_firestore`, générique-par-topologie) ; (2) controllers/selectors **typés par entité** = one-liners app-side ; (3) cutover repo-par-repo des repos IFFD (flat top-level) — voir ES-11.2/ES-11.3. **Aucun fichier lex/iffd/dodlp touché côté zcrud** (re-scope utilisateur respecté). Marqueur dartdoc `DW-ES111-1` sur chaque déliverable générique.

### References

- [Source: epics-zcrud-study-2026-07-12/epics.md#Epic-ES-11 / Story-ES-11.1] — FR-S34 (binding GetX + migration IFFD), dépend d'ES-10, package `zcrud_get`, `lib/src/study/*`, code manager-spécifique confiné au binding (AD-15).
- [Source: stories/epic-es-10-retrospective.md#R28] — binding/agrégateur GÉNÉRIQUE, aucune dep d'entité ; spécialisation typée app-side ; arête de fan-in validée par `melos verify` REPO-WIDE avant merge. **ES-11.1 = miroir GetX, R28 dès create-story.**
- [Source: stories/epic-es-10-retrospective.md#R27.4] — le verrou à rouge provoqué vise le SYMBOLE PUBLIC consommé (factory exportée), pas seulement le helper interne.
- [Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-24] — une forme kernel unique ; égalité profonde AU binding ; prevents les deux formes.
- [Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-15] — bindings multi-gestionnaire ; code manager-spécifique confiné au binding (`zcrud_get` pour GetX) ; cœur sans gestionnaire d'état.
- [Source: architecture-zcrud-2026-07-09/architecture.md#AD-1/AD-2/AD-5/AD-6/AD-10] — graphe acyclique CORE OUT=0 ; réactivité Flutter-native ; flux nus + `Either` ; seams throw ; désérialisation défensive.
- [Source: packages/zcrud_riverpod/lib/src/study/{z_session_config_key.dart, z_study_providers.dart}] — patron ES-10.1 à miroiter (égalité profonde au binding + seam throw + dedup SM-1).
- [Source: packages/zcrud_riverpod/test/study/*] — patron de tests (7 cas mono-champ, compteur de builds SM-1, seam/dispose, isolation backend).
- [Source: packages/zcrud_get/lib/src/presentation/{zcrud_get_scope.dart, z_get_resolver.dart}] — `ZcrudGetScope` (lifecycle/dispose, gardes d'appartenance), `ZGetResolver` (seam get_it + `ZScopeError`) à réutiliser.
- [Source: packages/zcrud_study_kernel/lib/src/domain/{z_study_session_config.dart, z_study_repository.dart, z_study_session_selector.dart}] — `==`/`hashCode` par valeur (7 champs), port `ZStudyRepository<T>` (flux nus + `ZResult`), primitive PURE `ZStudySessionSelector` (réutiliser, ne pas réimplémenter).

---

## Vérif verte à rejouer (avant tout `review`/`done`) — RC HORS pipe (R15)

> Rejouée **réellement sur disque** par l'orchestrateur, jamais sur la foi du rapport dev.

1. **Codegen** — `dart run melos run generate` (aucun nouveau `*.g.dart` attendu dans `zcrud_get` ; confirme que rien n'est cassé côté kernel).
2. **Bootstrap** (R25, dep ajoutée) — `dart pub get` (workspace) sans conflit ni warning nouveau.
3. **Analyze ciblé** — `dart analyze packages/zcrud_get` → **RC=0** (0 issue).
4. **Tests (R14)** — `flutter test packages/zcrud_get; echo "RC=$?"` → **RC=0**. Attendu : suites E2-9 existantes (parité, scope, idiom, codecs) **inchangées vertes** + 4 nouvelles suites study (égalité+tag mono-champ ×7, dedup SM-1, watch/seam/onClose, isolation backend/entité).
5. **Graphe (AC6)** — `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 46`** (45 → 46, delta +1 = `zcrud_get → zcrud_study_kernel`, SORTANTE), 20 nœuds ; **aucune** arête `zcrud_get → entité`.
6. **`dart run melos list`** — sanity (20 packages, `zcrud_get` présent).
7. **Gates repo-wide (AC7, NON-NÉGOCIABLE R28/R9)** — `dart run melos run analyze` **ET** `dart run melos run verify` REPO-WIDE → **VERT** (`gate:reserved-keys`, `gate:secrets`, `gate:web`, `codegen-distribution`, `verify:serialization`, isolement d'idiome ; **frontière EX-3 : `example/` résout, aucune entité déférée tirée**). La vérif ciblée d'un package NE détecte PAS une régression cross-package.

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, skill réel via tool Skill).

### Debug Log References

- Fenêtre R25 : ajout dep `zcrud_study_kernel` → `dart pub get` (workspace) RC=0.
- Hang initial (2 tests `z_study_watch_controller_test.dart`) : `StreamController` single-subscription **jamais écouté** + `addTearDown(controller.close)` bloquait (le `done` d'un contrôleur single-sub non écouté ne se livre jamais → future de `close()` pendante, timeout 30 s). Corrigé en `StreamController.broadcast()` pour les 2 tests qui n'établissent aucune souscription (les tests AC1-séquence/AC5 gardent le single-sub + onCancel).

### Completion Notes List

- **Binding study GetX GÉNÉRIQUE** livré sous `lib/src/study/` (miroir GetX d'ES-10.1) — réutilise `ZcrudGetScope`/`ZGetResolver` (E2-9, non touchés) et la primitive PURE `ZStudySessionSelector` (kernel, non réimplémentée).
- **AD-24** : `ZSessionConfigKey` porte l'égalité profonde (7 champs) **au binding** + un `String get tag` DÉTERMINISTE (JSON canonique à clés triées) tel que `a == b ⟺ a.tag == b.tag` — matérialisation GetX du contrat de caching (indexation `Type`+`tag`).
- **SM-1** : `zPutStudySessionSelector` dédup par `key.tag` — 1 construction sur configs égales-mais-distinctes, `identical` vrai ; +1 sur un champ modifié. R27.4 respecté (le verrou vise la factory publique exportée).
- **R28** : fan-in = `zcrud_study_kernel` UNIQUEMENT, **aucune** entité concrète (prouvé par graph_proof = 46 arêtes + garde pubspec liste-noire + `melos verify` repo-wide vert, EX-3 préservée).
- **Preuves R3 (mutation → RED → restauration)** : R3-I2 (`count` neutralisé dans `==` → cas mono-champ `count` RED), R3-I3 (`tag` par `identityHashCode` → dedup SM-1 + `tag`-equality RED), R3-I4 (throw avalé/repo null → seam RED), R3-I5 (`cancel()` retiré de `onClose` → anti-fuite RED), R3-I7 (import `cloud_firestore` → isolation code RED), R3-I6 (arête `zcrud_get→zcrud_flashcard` → graph 47 + résolution repo-wide échoue). Toutes restaurées, VERTES.
- **Dette DW-ES111-1** à escalader à l'orchestrateur : câblage DODLP app-side (enregistrement des seams `ZStudyRepository<Entity>` au locator, controllers/selectors typés par entité = one-liners app-side, cutover repos IFFD) — aucun fichier lex/iffd/dodlp touché ici.

### File List

- `packages/zcrud_get/lib/src/study/z_session_config_key.dart` (NOUVEAU)
- `packages/zcrud_get/lib/src/study/z_study_get.dart` (NOUVEAU)
- `packages/zcrud_get/lib/zcrud_get.dart` (MODIFIÉ — 2 exports study)
- `packages/zcrud_get/pubspec.yaml` (MODIFIÉ — dep `zcrud_study_kernel` + invariant R28)
- `packages/zcrud_get/test/study/z_session_config_key_equality_test.dart` (NOUVEAU)
- `packages/zcrud_get/test/study/z_session_dedup_test.dart` (NOUVEAU)
- `packages/zcrud_get/test/study/z_study_watch_controller_test.dart` (NOUVEAU)
- `packages/zcrud_get/test/study/z_binding_study_isolation_test.dart` (NOUVEAU)

### Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-16 | 0.1 | Story créée (bmad-create-story, skill réel) — miroir GetX d'ES-10.1, R28/R27.4 appliqués dès create-story — statut ready-for-dev | create-story |
| 2026-07-16 | 0.2 | Implémentation (bmad-dev-story, skill réel) — binding study GetX générique (`ZSessionConfigKey`+`tag`, `ZStudyWatchController`, `buildStudyWatchController`, `zPutStudySessionSelector`) ; 38 tests verts ; graph 46 arêtes acyclique CORE OUT=0 ; `melos analyze` + `melos verify` repo-wide RC=0 ; 6 injections R3 prouvées RED+restaurées — statut review | dev-story |
