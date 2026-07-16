---
baseline_commit: 3adf49dbec2d04e00d45c871d38544d2696756a3
---

# Story ES-10.1 : Providers Riverpod + égalité profonde de `ZStudySessionConfig` au binding

Status: review

<!-- Créée par bmad-create-story (skill réel). Cycle BMAD strict. NE PAS éditer le sprint-status ici (orchestrateur). -->

## Story

As a **développeur lex**,
I want **des providers `zcrud_riverpod` branchant les repos/streams `zcrud_study` (le port générique `ZStudyRepository<T>`) sur Riverpod, l'égalité profonde de `ZStudySessionConfig` — requise comme clé de family — étant fournie CÔTÉ binding**,
So that **je peux consommer `zcrud_study` sous Riverpod sans que le kernel ni le cœur ne connaissent Riverpod, et sans qu'un rebuild de provider ne se déclenche quand la valeur profonde de la config n'a pas changé (objectif produit n°1, SM-1)**.

---

## Contexte & état réel validé sur disque (le 2026-07-16)

> **Ne rien réinventer.** Le binding `zcrud_riverpod` EXISTE déjà (livré en E2-9). Cette story **ajoute** un sous-arbre `lib/src/study/`, elle ne recrée pas la coquille.

- **`packages/zcrud_riverpod/` EXISTE** et est un package **Flutter** (`pubspec.yaml` : `flutter: sdk: flutter` + `flutter_riverpod: ^2.6.1` + `dev: flutter_test`, `binding_conformance: ^0.0.1`). ⇒ **R14 : les tests se lancent via `flutter test`**, JAMAIS `dart test`.
- Déjà présent (E2-9, à RÉUTILISER tel quel, ne pas dupliquer) :
  - `lib/src/presentation/zcrud_riverpod_scope.dart` — `ZcrudRiverpodScope` (monte un `UncontrolledProviderScope`, enveloppe un `ZcrudScope` porteur du resolver) + `zFormControllerProvider` (`Provider.autoDispose<ZFormController>` avec `ref.onDispose(controller.dispose)`). **Patron auto-dispose canonique à réutiliser.**
  - `lib/src/presentation/z_riverpod_resolver.dart` — `ZRiverpodResolver extends ZDependencyResolver` : `resolve<T>()` lit un `Map<Type, ProviderListenable<Object?>> seams` dans un `ProviderContainer` ; **lève `ZScopeError` (message actionnable) si le seam manque** (« seams throw », AD-6 — jamais de résolution silencieuse). **C'est le point d'injection des repos** : un repo `zcrud_study` est fourni à un provider via ce registre `seams`, pas via un import concret.
  - Barrel `lib/zcrud_riverpod.dart`, tests `test/presentation/*` + `test/purity/idiom_isolation_test.dart` (garde : aucun idiome GetX/get_it/provider dans `lib/`).
- **Dépendances `zcrud_*` actuelles du binding** : `zcrud_core` **UNIQUEMENT** (pubspec, invariant E2-9). ⇒ cette story introduit la **première arête de fan-in** vers l'étage study (cf. § Graphe).
- **`ZStudySessionConfig` VIT dans `zcrud_study_kernel`** (`lib/src/domain/z_study_session_config.dart`, `@ZcrudModel(kind: 'study_session_config')`). Champs : `mode` (`ZReviewMode`, défaut `spaced`), `folderId` (`String?`), `tagIds` (`List<String>?`), `types` (`List<String>?`), `count` (`int?`), `extension` (`ZExtension?`), `extra` (`Map<String,dynamic>` normalisée). **Elle porte DÉJÀ un `operator ==`/`hashCode` par VALEUR profonde** (mode, folderId, `_listEquals(tagIds)`, `_listEquals(types)`, count, extension, `zJsonEquals(extra)`) — **une seule forme persistable, round-trip AD-10** (`g.dart` committé). **NE PAS ajouter une seconde forme dans le kernel** (AD-24, cf. ci-dessous).
- **Port générique** : `ZStudyRepository<T extends ZEntity> extends ZSyncableRepository<T>` (`zcrud_study_kernel/lib/src/domain/z_study_repository.dart`, exporté par le barrel kernel). Flux `watchAll()`/`watch()` = `Stream<List<T>>` **NUS** (AD-5) ; `save`/`softDelete` = `Future<ZResult<T>>` = `Either<ZFailure,T>` (AD-11). Backend-agnostique (aucun type `cloud_firestore`/Hive/Flutter).
- **Primitive de sélection PURE** : `ZStudySessionSelector` (kernel, `z_study_session_selector.dart`, exportée) — la sélection effective des cartes d'une session à partir de `ZStudySessionConfig`. **La config décrit *quelles* cartes ; le selector calcule la sélection.** Réutiliser cette primitive côté binding, ne pas la ré-implémenter.
- **Barrel kernel** (`zcrud_study_kernel.dart`) exporte `z_study_repository.dart`, `z_study_session_config.dart` (`hide ZStudySessionConfigZcrud`), `z_study_session_selector.dart`, `z_session_candidate.dart`, `z_study_session_result.dart`. ⇒ **`zcrud_study_kernel` est le point d'agrégation** suffisant pour des providers GÉNÉRIQUES sur `ZStudyRepository<T>` + la clé `ZStudySessionConfig`.

---

## Décision d'architecture centrale — AD-24 (égalité profonde AU BINDING)

> **[Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-24]**
> **AD-24** — *une seule* forme `ZStudySessionConfig` (`@ZcrudModel`, persistable, round-trip) vit dans `zcrud_study_kernel`. **L'égalité profonde requise par une family Riverpod (clé de provider) vit DANS LE BINDING `zcrud_riverpod`, jamais dans le kernel/cœur** — le domaine ne connaît pas Riverpod. **Prevents** : les deux formes concurrentes de lex (config persistée simple *vs* value-object riche pour clé Riverpod) rentrant toutes deux dans le cœur.

**Traduction non ambiguë pour le dev (le piège à éviter) :**

Le kernel expose DÉJÀ un `==` par valeur sur `ZStudySessionConfig`. La tentation naïve — `StreamProvider.family<…, ZStudySessionConfig>` clé directement sur la config, « ça marche » via le `==` du kernel — **localiserait la responsabilité d'égalité DANS LE KERNEL** et viole l'intention d'AD-24 : le kernel deviendrait garant du contrat de caching Riverpod (couplage inverse). **La responsabilité d'égalité de la clé de family DOIT être matérialisée et TESTÉE dans `zcrud_riverpod`.**

⇒ **Déliverable AD-24** : un **type de clé possédé par le binding** — `ZSessionConfigKey` (sous `lib/src/study/`) — qui enveloppe une `ZStudySessionConfig` et **implémente sa propre égalité profonde par VALEUR sur TOUS les champs** (`mode`, `folderId`, `tagIds` profond, `types` profond, `count`, `extension`, `extra` via `zJsonEquals`). La/les family(ies) sont clées par `ZSessionConfigKey`, **jamais** par `ZStudySessionConfig` nu. Ainsi la garantie de dedup/no-rebuild **vit et se prouve dans le binding**, indépendamment de ce que le kernel décide de son propre `==`.

---

## Acceptance Criteria

> Chaque AC est **discriminant** (R12) et, quand il pose une garde, **co-livré avec un test à rouge provoqué** (R27, leçon centrale ES-9). Les injections R3 sont listées §*Injections R3 prévues*.

### AC1 — Providers Riverpod pour les repos/streams `zcrud_study` (le port `ZStudyRepository<T>`)

**Given** le port générique `ZStudyRepository<T extends ZEntity>` (kernel) et son flux `watchAll()` / `watch(id)` (`Stream<List<T>>` nu, AD-5)
**When** on fournit les providers `zcrud_riverpod`
**Then** `zcrud_riverpod` expose, sous `lib/src/study/`, une fabrique de providers branchant ce port sur Riverpod : le **repo est résolu via le seam** (`ZRiverpodResolver`/`ProviderListenable`, jamais un import de repo concret), le flux `watchAll()` est exposé via un **`StreamProvider.autoDispose`** (émet exactement la `Stream<List<T>>` du repo, ordre et contenu préservés), et l'écriture (`save`/`softDelete`) reste un `Future<ZResult<T>>` non enveloppé.
**Then** **AUCUN** `WidgetRef` / `ConsumerWidget` / `ProviderScope` / symbole `flutter_riverpod` n'apparaît dans `zcrud_study*` ni `zcrud_study_kernel` ni `zcrud_core` (NFR-S5, AD-15).

**Discriminant** — un `StreamProvider` qui ré-émet une liste transformée/réordonnée, ou qui n'auto-dispose pas, échoue le test d'égalité de flux / de dispose. Un provider qui `import 'package:zcrud_study.../…repository_impl'` (repo concret) au lieu de résoudre par seam brise l'inversion de dépendance (mesuré par le test de résolution via seam + `ZScopeError` si absent).

### AC2 — Égalité profonde de `ZStudySessionConfig` AU BINDING (AD-24) — clé de family `ZSessionConfigKey`

**Given** une family Riverpod destinée à être clée par `ZStudySessionConfig`
**When** on la définit
**Then** l'**égalité profonde** requise vit dans un type **possédé par le binding** (`ZSessionConfigKey`, `lib/src/study/z_session_config_key.dart`) — `operator ==`/`hashCode` **par VALEUR profonde sur TOUS les champs** de la config ; **jamais** une seconde forme ajoutée au kernel/cœur (le kernel garde **une seule** `ZStudySessionConfig` persistable, inchangée). La family est clée par `ZSessionConfigKey`.
**Then** deux `ZStudySessionConfig` **structurellement égales mais d'identités distinctes** ⇒ `ZSessionConfigKey` **égales** + `hashCode` **identiques** ; deux configs différant d'**exactement un champ** ⇒ clés **inégales**.

**Discriminant (R27 — leçon ES-9.3 MEDIUM-1, à NE PAS répéter)** — le test d'égalité **varie CHAQUE champ un à un** (7 cas mono-champ : `mode`, `folderId`, `tagIds`, `types`, `count`, `extension`, `extra`), **jamais « tous à la fois »** (qui teste la présence de `==`, pas la contribution de chaque champ). Neutraliser la comparaison d'un seul champ dans `ZSessionConfigKey.==` (ou le retirer de `hashCode`) DOIT faire **rougir** le cas correspondant (injections `R3-I2a..g`). Un test qui reste vert sous cette neutralisation est **powerless** et rejeté.

### AC3 — SM-1 : aucun rebuild de provider si la valeur profonde de la config est inchangée (objectif produit n°1)

**Given** une family clée par `ZSessionConfigKey`, et un compteur de builds du provider
**When** on lit/écoute la family avec deux instances de `ZStudySessionConfig` **structurellement égales mais distinctes en mémoire**
**Then** le provider **build UNE seule fois** (Riverpod dédup la clé par `==`/`hashCode` de `ZSessionConfigKey`) — **zéro rebuild** superflu.
**When** on lit ensuite avec une config différant d'**un** champ
**Then** le provider **rebuild** (nouvelle clé ⇒ nouvel état) — le compteur incrémente.

**Discriminant (SM-1)** — remplacer `ZSessionConfigKey` par la config nue comparée par **identité** (ou par une clé « shallow » ignorant `extra`/`tagIds`/`types`) fait passer le compteur de builds de **1 → 2** sur le cas « égales mais distinctes » : le test **rougit** (injection `R3-I3`). C'est la matérialisation exécutable de l'objectif n°1 (pas de rebuild inutile) au niveau du binding.

### AC4 — Résolution par seam robuste (AD-6/AD-10) : throw actionnable, jamais silence

**Given** un provider qui résout son `ZStudyRepository<T>` via le registre `seams` du `ZcrudRiverpodScope`
**When** aucun provider n'est enregistré pour ce type
**Then** la résolution lève un **`ZScopeError` au message actionnable** (réutilise le contrat existant de `ZRiverpodResolver`) — **jamais** de `null` silencieux ni de crash non typé.

**Discriminant** — un provider qui capture l'absence de seam et retombe sur un repo par défaut / `null` masque l'erreur d'injection : le test asserte `throwsA(isA<ZScopeError>())` avec message contenant le `Type` manquant (injection `R3-I4` : retirer le throw ⇒ le test rougit).

### AC5 — Cycle de vie : auto-dispose des providers study (aucune fuite)

**Given** les providers study exposés par le binding
**When** plus personne n'écoute (ou le `ProviderContainer` est disposé)
**Then** les `StreamProvider.autoDispose` **annulent leur souscription** et libèrent les ressources (`ref.onDispose`) — aucune souscription pendante, aucune fuite (même patron que `zFormControllerProvider`).

**Discriminant** — un `StreamProvider` NON auto-dispose garde la souscription vivante : le test (fake repo comptant les souscriptions actives / une `StreamController` observant `onCancel`) montre `onCancel` non appelé ⇒ rouge (injection `R3-I5` : retirer `.autoDispose`).

### AC6 — Graphe acyclique, fan-in SORTANT, CORE OUT=0 (AD-1)

**Given** le graphe de dépendances du monorepo (baseline mesurée **44 arêtes / 20 nœuds**, CORE OUT=0)
**When** on rejoue `python3 scripts/dev/graph_proof.py`
**Then** **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 45`** (**delta = +1** : nouvelle arête SORTANTE `zcrud_riverpod → zcrud_study_kernel`, seul dep `zcrud_*` ajouté), 20 nœuds inchangés. L'arête va du **binding vers l'étage study**, **jamais l'inverse** (aucun package study ne dépend de `zcrud_riverpod`). Le commentaire d'invariant du `pubspec.yaml` de `zcrud_riverpod` est **mis à jour** (il affirme aujourd'hui « AUCUN autre `zcrud_*` que `zcrud_core` » — devenu faux après cette story).

**Discriminant** — `graph_proof` refuse tout cycle (fatal) ; un delta ≠ +1 (ex. un dev ajoute par erreur une dépendance vers un package d'entité `zcrud_document`/`zcrud_note`/`zcrud_exam` — hors périmètre ES-10.1, réservé à ES-10.2) fait diverger le compte et doit être justifié ou retiré (injection `R3-I6`). `flutter_riverpod` n'étant PAS un `zcrud_*`, il n'entre pas dans le compte d'arêtes zcrud et ne change pas CORE OUT.

### AC7 — Isolement d'idiome préservé (AD-15) : Riverpod confiné à `zcrud_riverpod`

**Given** la garde d'isolement existante (`test/purity/idiom_isolation_test.dart`)
**When** on ajoute le sous-arbre `lib/src/study/`
**Then** aucun idiome GetX/get_it/provider n'y apparaît (la garde existante couvre déjà tout `lib/` récursivement — le nouveau dossier est **couvert automatiquement**), et symétriquement **aucun** symbole `flutter_riverpod`/`WidgetRef`/`ConsumerWidget` ne fuit vers `zcrud_study_kernel`/`zcrud_study`/`zcrud_core` (garanti **structurellement** par le graphe : ces packages ne dépendent pas de `zcrud_riverpod`, donc ne peuvent pas référencer ses symboles — AC6).

**Discriminant** — la garde `idiom_isolation` rougit si un `Get.put`/`Provider.of`/`get_it` se glisse dans `lib/src/study/`.

---

## Tasks / Subtasks

- [x] **T1 — `pubspec.yaml` : ajouter l'arête de fan-in `zcrud_study_kernel` + MAJ invariant** (AC6)
  - [x] Ajouter `zcrud_study_kernel: ^0.1.0` dans `dependencies:` (à côté de `zcrud_core`).
  - [x] **NE PAS** ajouter les packages d'entités (`zcrud_document`/`zcrud_note`/`zcrud_exam`/`zcrud_session`/`zcrud_flashcard`) : aucun ajouté (fan-in = kernel seul).
  - [x] **Commentaire d'invariant mis à jour** : « `zcrud_core` + `zcrud_study_kernel` (fan-in ES-10.1, arête SORTANTE) ; toujours AUCUN backend lourd ; `flutter_riverpod` reste le seul manager ; CORE OUT=0 préservé ».
  - [x] `dart pub get` (workspace) RC=0, résolution `workspace`, sans conflit ni warning nouveau.

- [x] **T2 — `ZSessionConfigKey` : égalité profonde au binding (AD-24)** — `lib/src/study/z_session_config_key.dart` (**NOUVEAU**) (AC2)
  - [x] Classe immuable enveloppant `final ZStudySessionConfig config;`.
  - [x] `operator ==` par VALEUR sur **tous** les champs : `mode`, `folderId`, `tagIds`/`types` (via `zJsonEquals` — listes profondes), `count`, `extension`, `extra` (`zJsonEquals`). Réutilise `zJsonEquals`/`zJsonHash` de `zcrud_core` (aucune duplication de normalisation).
  - [x] `hashCode` couvrant les **mêmes** champs (`Object.hashAll` + `zJsonHash` pour listes/extra), cohérent avec `==`.
  - [x] Dartdoc : **pourquoi ici et pas au kernel** (AD-24) + note R27 « varier chaque champ un à un ».

- [x] **T3 — Providers study génériques** — `lib/src/study/z_study_providers.dart` (**NOUVEAU**) (AC1/AC3/AC4/AC5)
  - [x] **Fonction fabrique** (forme 1) : `zStudyWatchAllProvider<T>({required ProviderListenable<ZStudyRepository<T>> repo})` → `AutoDisposeStreamProvider<List<T>>` + seam `zStudyRepositoryProvider<T>()` (Provider throw `ZScopeError` tant que non surchargé).
  - [x] `watchAll()` → `StreamProvider.autoDispose` émettant la `Stream<List<T>>` NUE du repo (aucune transformation).
  - [x] Provider de **sélection de session** : `zStudySessionSelectorProvider` = `Provider.autoDispose.family` clée par **`ZSessionConfigKey`**, déléguant à `ZStudySessionSelector(key.config)` (primitive PURE kernel) — jamais réimplémentée.
  - [x] Résolution du repo **via seam** (`ref.watch(repo)`) → `ZScopeError` actionnable (message contient le `Type`) si absent.
  - [x] `autoDispose` sur le StreamProvider (souscription au flux annulée à la fin d'écoute).

- [x] **T4 — Barrel** — `lib/zcrud_riverpod.dart` (AC1/AC2)
  - [x] `export 'src/study/z_session_config_key.dart';` et `export 'src/study/z_study_providers.dart';`.

- [x] **T5 — Tests `flutter test` (R14)** — `packages/zcrud_riverpod/test/study/` (**NOUVEAU dossier**)
  - [x] `z_session_config_key_equality_test.dart` (**AC2**) : égales/distinctes ⇒ `==` + `hashCode` ; **7 cas mono-champ** via `copyWith` + cas `extra` imbriqué (`zJsonEquals`) + cas extra profond divergent. R3-I2 (count, extra) prouvés rouges.
  - [x] `z_session_family_rebuild_test.dart` (**AC3, SM-1**) : `ProviderContainer` + `ProviderObserver` comptant `didAddProvider` ; égales-mais-distinctes ⇒ **1 build** ; un champ différent ⇒ **2 builds**. R3-I3 (keying identité) prouvé rouge.
  - [x] `z_study_providers_test.dart` (**AC1/AC4/AC5**) : fake `ZStudyRepository<_FakeEntity>` + `StreamController` ; ré-émission exacte (ordre/contenu) ; seam absent ⇒ `throwsA(isA<ZScopeError>())` (message contient le Type) ; `onCancel` appelé à la fin d'écoute (auto-dispose). R3-I4/R3-I5 prouvés rouges.

- [x] **T6 — Garde d'isolement (AC7)** — `test/purity/idiom_isolation_test.dart` scanne `lib/` **récursivement** (`listSync(recursive: true)`) ⇒ `lib/src/study/` couvert automatiquement. Aucune modification requise ; garde verte.

- [x] **T7 — Vérif verte rejouée** (§ dédiée) + MAJ File List / Dev Agent Record + Change Log.

---

## Injections R3 prévues (mutation → AC rouge → restauration) — verrous LOAD-BEARING

> **R27** : chaque garde ci-dessous est **co-livrée** avec le test qui rougit sous sa neutralisation. Aucune garde « vœu ».

- **R3-I2a..g (AC2 — égalité profonde par CHAMP)** — dans `ZSessionConfigKey.==`, neutraliser **un seul** champ à la fois (ex. supprimer `&& config.count == o.config.count`, ou remplacer `zJsonEquals(extra)` par `true`) ⇒ le cas mono-champ correspondant de `z_session_config_key_equality_test.dart` **rougit**. 7 injections indépendantes (une par champ). *(Leçon ES-9.3 MEDIUM-1 : « tous à la fois » ne suffit pas.)*
- **R3-I2h (AC2 — hashCode)** — retirer un champ de `hashCode` (rompre `a==b ⇒ hash==hash`) ⇒ le cas « égales mais distinctes » de la family (dedup par hash) ou un test `hashCode` dédié **rougit**.
- **R3-I3 (AC3 — SM-1)** — clé la family par `ZStudySessionConfig` comparée par **identité** (ou une clé shallow ignorant `extra`/`tagIds`/`types`) ⇒ le compteur de builds passe **1 → 2** sur « égales mais distinctes » ⇒ `z_session_family_rebuild_test.dart` **rougit**.
- **R3-I4 (AC4 — seam throw)** — retirer/avaler le `ZScopeError` (retour `null` ou repo par défaut) ⇒ `throwsA(isA<ZScopeError>())` **rougit**.
- **R3-I5 (AC5 — auto-dispose)** — retirer `.autoDispose` (ou `ref.onDispose`) d'un `StreamProvider` ⇒ le test `onCancel`/anti-fuite **rougit**.
- **R3-I6 (AC6 — graphe)** — ajouter une arête parasite (`zcrud_document`/`zcrud_note`/`crypto`/`http`) au pubspec ⇒ `graph_proof` compte ≠ 45 (justification impossible dans le périmètre 10.1) ; tout cycle est fatal.

---

## Dev Notes

### Forme d'API retenue (guardrail, éviter la sur-ingénierie)

Riverpod **n'a pas de providers génériques** (`Provider.family<T, …>` ne peut pas être générique sur `T`). Deux formes acceptables, au choix du dev, **documentées** :

1. **Fonction fabrique** `StreamProvider<List<T>> zStudyWatchAllProvider<T extends ZEntity>({required ProviderListenable<ZStudyRepository<T>> repo})` retournant un `StreamProvider.autoDispose` — l'app instancie un provider typé par entité en ES-10.2 en passant le seam du repo concret.
2. **Provider de repo résolu par seam** + un `StreamProvider.autoDispose` construit dessus.

La forme (1) garde ES-10.1 **générique et sans dépendance aux packages d'entités** (fan-in minimal = kernel seul, AC6). Les providers **typés concrets** (adossés à `ZStudyDocument`/`ZSmartNote`/`ZExam`…) et leurs adapters `zcrud_firestore` nested sont **ES-10.2** — ne PAS les tirer ici.

### Pourquoi l'égalité vit au binding alors que le kernel a déjà un `==` (le point subtil)

Le kernel a un `==` par valeur **légitime** (forme persistable, round-trip). Rien à changer côté kernel. AD-24 exige que **le contrat de caching de la family** (clé de provider) soit porté par un type **du binding** (`ZSessionConfigKey`), pour que : (a) le kernel ne devienne jamais garant d'un contrat Riverpod (couplage inverse interdit) ; (b) la garantie no-rebuild (SM-1) soit **prouvée localement** dans `zcrud_riverpod` en variant chaque champ, indépendamment du `==` kernel. `ZSessionConfigKey` **peut** réutiliser les primitives de comparaison (`zJsonEquals`/hash de liste) — il ne duplique pas la *normalisation*, seulement la *responsabilité de clé*.

### Invariants AD applicables (rappel, NON-NÉGOCIABLES)

- **AD-1** — graphe acyclique, CORE OUT=0 ; fan-in **SORTANT** binding → study, jamais l'inverse ; baseline 44 → **45** (delta +1, kernel).
- **AD-2 / AD-15** — réactivité Flutter-native ; le cœur/kernel n'importe **PAS** Riverpod ; le code Riverpod-spécifique vit **exclusivement** dans `zcrud_riverpod` ; SM-1 : rebuild granulaire, égalité profonde pour éviter les rebuilds inutiles.
- **AD-4** — `String` opaque (`id`, `folderId`, `tagIds`) ; slot `extra`/`extension` versionné déjà porté par la config ; pas de `sealed` pour l'extension ; generics autorisés pour un **PORT** (`ZStudyRepository<T>`), jamais pour la sérialisation.
- **AD-5 / AD-11** — flux = `Stream<List<T>>` **nus** ; écritures = `Either<ZFailure,T>` (`ZResult`). Un `StreamProvider` **enveloppe** un flux nu du port, il ne change pas le contrat du port.
- **AD-6** — seams **throw** (jamais de résolution silencieuse) — réutiliser `ZScopeError` de `ZRiverpodResolver`.
- **AD-10** — défensif : un seam manquant lève une erreur **actionnable typée**, jamais un crash brut.
- **AD-24** — égalité profonde de `ZStudySessionConfig` **au binding** (cf. supra).
- **FR-26** — thème injecté (non concerné directement ici : ES-10.1 n'expose pas de widget ; les providers ne codent aucun style).

### Runner & fenêtre pub-get (R14/R15/R25)

- **R14** : `zcrud_riverpod` est un package **Flutter** → **`flutter test`** (jamais `dart test`).
- **R15** : capturer le **RC HORS pipe** — `flutter test …; echo "RC=$?"` (jamais `| tail` qui masque le code retour).
- **R25** : cette story **ajoute une dépendance** (`zcrud_study_kernel`) ⇒ fenêtre `pub get`/bootstrap sensible : rejouer `dart pub get` au niveau workspace et confirmer résolution `workspace` sans conflit avant analyze/test.

### Ne rien réinventer / ne rien casser (régression)

- Réutiliser `ZcrudRiverpodScope`, `zFormControllerProvider`, `ZRiverpodResolver` (E2-9) **tels quels**. Le nouveau code s'ajoute sous `lib/src/study/`, il ne modifie pas la présentation E2-9.
- `z_riverpod_parity_test.dart` (parité rebuild du formulaire via `binding_conformance`) doit **rester vert** : ne pas toucher au scope ni au provider de controller.

### Project Structure Notes

- **NOUVEAUX** : `lib/src/study/z_session_config_key.dart`, `lib/src/study/z_study_providers.dart`, `test/study/z_session_config_key_equality_test.dart`, `test/study/z_session_family_rebuild_test.dart`, `test/study/z_study_providers_test.dart`.
- **MODIFIÉS** : `lib/zcrud_riverpod.dart` (2 exports), `pubspec.yaml` (dep kernel + invariant).
- **INCHANGÉS** (ne pas toucher) : tout `lib/src/presentation/*`, `test/presentation/*`, `test/purity/*`, `zcrud_study_kernel/*`, `zcrud_core/*`.
- API publique = barrel ; impl sous `lib/src/study/` (convention AD).
- Aucune `@ZcrudModel`/`@JsonSerializable` nouvelle ⇒ **aucun `*.g.dart` nouveau** attendu dans `zcrud_riverpod` (mais rejouer `melos run generate` par prudence, cf. Vérif verte).

### References

- [Source: epics-zcrud-study-2026-07-12/epics.md#Epic-ES-10 / Story-ES-10.1] — user story, ACs, FR-S33, dépend d'ES-4..ES-9, package `zcrud_riverpod`, `lib/src/study/*`, égalité profonde au binding.
- [Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-24] — une forme kernel unique ; égalité profonde AU binding ; prevents les deux formes lex.
- [Source: architecture-zcrud-study-2026-07-12/architecture.md#AD-15] — bindings multi-gestionnaire ; code manager-spécifique confiné au binding ; cœur sans gestionnaire d'état.
- [Source: architecture-zcrud-2026-07-09/architecture.md#AD-1/AD-2/AD-5/AD-6/AD-10] — graphe acyclique CORE OUT=0 ; réactivité Flutter-native ; flux nus + `Either` ; seams throw ; désérialisation défensive.
- [Source: packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart] — `==`/`hashCode` par valeur existants (7 champs) ; forme persistable unique.
- [Source: packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart] — port `ZStudyRepository<T>` (`watchAll`/`watch` `Stream<List<T>>`, `save`/`softDelete` `ZResult<T>`).
- [Source: packages/zcrud_study_kernel/lib/src/domain/z_study_session_selector.dart] — primitive PURE de sélection (à réutiliser, ne pas ré-implémenter).
- [Source: packages/zcrud_riverpod/lib/src/presentation/{zcrud_riverpod_scope.dart, z_riverpod_resolver.dart}] — `ZcrudRiverpodScope`, `zFormControllerProvider` (patron auto-dispose), `ZRiverpodResolver` (seam + `ZScopeError`).
- [Source: stories/epic-es-9-retrospective.md#R27 / §5] — garde co-livrée avec test à rouge provoqué ; égalité par valeur variant **chaque champ un à un** (leçon ES-9.3 MEDIUM-1) ; rapport déclare le gate RÉEL ; runner R14/R15.

---

## Vérif verte à rejouer (avant tout `review`/`done`) — RC HORS pipe (R15)

> Rejouée **réellement sur disque** par l'orchestrateur, jamais sur la foi du rapport dev.

1. **Codegen** — `dart run melos run generate` (aucun nouveau `*.g.dart` attendu dans `zcrud_riverpod` ; confirme que rien n'est cassé côté kernel).
2. **Bootstrap** (R25, dep ajoutée) — `dart pub get` (workspace) sans conflit ni warning nouveau.
3. **Analyze** — `dart analyze packages/zcrud_riverpod` → **RC=0** (0 issue).
4. **Tests (R14)** — `flutter test packages/zcrud_riverpod; echo "RC=$?"` → **RC=0**. Attendu : suites E2-9 existantes (parité, scope, idiom) **inchangées vertes** + 3 nouvelles suites study (égalité mono-champ ×7, rebuild SM-1, providers/seam/dispose).
5. **Graphe (AC6)** — `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 45`** (44 → 45, delta +1 = `zcrud_riverpod → zcrud_study_kernel`), 20 nœuds.
6. **`dart run melos list`** — sanity (20 packages, `zcrud_riverpod` présent).
7. **Gates repo-wide** — `dart run melos run verify` → **VERT** (`gate:reserved-keys`, `gate:secrets`, `codegen-distribution`, isolement d'idiome). **NON-NÉGOCIABLE** (règle orchestrateur : la vérif ciblée d'un package NE détecte PAS une régression cross-package).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, skill réel invoqué).

### Debug Log References

- **AC5 (onCancel)** — l'auto-dispose Riverpod n'annule la souscription au flux qu'une fois la souscription pleinement établie : le test émet une liste (`controller.add`) avant `sub.close()`, puis attend un tour de boucle réel (`Duration(milliseconds: 20)`) — sonde jetable confirmant le comportement, retirée. `container.dispose()` seul ne discrimine PAS l'auto-dispose (un provider non-autoDispose serait aussi disposé au dispose du conteneur) ⇒ la voie « fin d'écoute » (fermeture de la souscription conteneur alive) est celle qui rougit sous R3-I5.
- **Compilation** — `StreamProvider.autoDispose` renvoie `AutoDisposeStreamProvider` (PAS sous-type de `StreamProvider`) ⇒ type de retour corrigé. `zJsonEquals`/`zJsonHash` importés explicitement de `zcrud_core` (le barrel kernel ne les réexporte pas).
- **Lint dartdoc** — `unintended_html_in_doc_comment` : le snippet `zStudyRepositoryProvider<ZStudyDocument>()` scindé sur deux lignes dans un backtick faisait lire `<ZStudyDocument>` comme du HTML ⇒ snippet ramené sur une seule ligne. `dart analyze` : **No issues found!**.

### Completion Notes List

- **AD-24 matérialisé au binding** : `ZSessionConfigKey` (possédé par `zcrud_riverpod`) porte l'égalité PROFONDE de clé de family ; le kernel garde son unique `ZStudySessionConfig` persistable inchangée (aucune 2ᵉ forme ajoutée au kernel/cœur).
- **SM-1 (objectif produit n°1) prouvé exécutablement** : family clée par `ZSessionConfigKey` ⇒ deux configs égales-mais-distinctes ⇒ 1 seul build (dedup par `==`/`hashCode`) ; keying par identité rougit (R3-I3).
- **Injections R3 prouvées rouges puis restaurées** : R3-I2 (count + extra/`zJsonEquals`), R3-I3 (SM-1 identité), R3-I4 (seam throw avalé), R3-I5 (`.autoDispose` retiré). Chaque garde est LOAD-BEARING.
- **AC6 graphe** : `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK, CORE OUT=0 OK, **total arêtes = 45** (+1 = `zcrud_riverpod → zcrud_study_kernel`, arête SORTANTE), 20 nœuds. Aucun package study ne dépend du binding.
- **AC7 isolement** : garde `idiom_isolation` (scan récursif `lib/`) couvre `lib/src/study/` automatiquement — verte.
- Aucun `*.g.dart` nouveau dans `zcrud_riverpod` (aucune `@ZcrudModel`) ; `melos run generate` vert (0 output pertinent).

### Vérif verte rejouée (RC HORS pipe, R15)

| Gate | Commande | RC / résultat |
|------|----------|---------------|
| Bootstrap (R25) | `dart pub get` | **RC=0**, résolution `workspace`, sans conflit |
| Codegen | `dart run melos run generate` | **SUCCESS** (aucun `.g.dart` manquant) |
| Analyze | `dart analyze packages/zcrud_riverpod` | **No issues found!** (RC=0) |
| Tests (R14, Flutter) | `flutter test packages/zcrud_riverpod` | **All tests passed! (+23)** |
| Graphe (AC6) | `python3 scripts/dev/graph_proof.py` | ACYCLIQUE OK, CORE OUT=0 OK, **45 arêtes**, 20 nœuds |
| Sanity | `dart run melos list` | **20** packages, `zcrud_riverpod` présent |
| Gates repo-wide | `dart run melos run verify` | **RC=0** — melos, reflectable, secrets, codegen, codegen-distribution, compat, web, reserved-keys, serialization : tous OK |

### File List

**MODIFIÉS**
- `packages/zcrud_riverpod/pubspec.yaml` — dépendance `zcrud_study_kernel` (fan-in) + commentaire d'invariant mis à jour.
- `packages/zcrud_riverpod/lib/zcrud_riverpod.dart` — 2 exports (`z_session_config_key.dart`, `z_study_providers.dart`).

**NOUVEAUX (lib)**
- `packages/zcrud_riverpod/lib/src/study/z_session_config_key.dart` — `ZSessionConfigKey` (égalité profonde au binding, AD-24).
- `packages/zcrud_riverpod/lib/src/study/z_study_providers.dart` — `zStudyRepositoryProvider<T>` (seam throw), `zStudyWatchAllProvider<T>` (StreamProvider.autoDispose), `zStudySessionSelectorProvider` (family clée par `ZSessionConfigKey`).

**NOUVEAUX (test)**
- `packages/zcrud_riverpod/test/study/z_session_config_key_equality_test.dart` (AC2).
- `packages/zcrud_riverpod/test/study/z_session_family_rebuild_test.dart` (AC3/SM-1).
- `packages/zcrud_riverpod/test/study/z_study_providers_test.dart` (AC1/AC4/AC5).

### Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-16 | 0.1 | Story créée (bmad-create-story, skill réel) — statut ready-for-dev | create-story |
| 2026-07-16 | 0.2 | Implémentation (bmad-dev-story, skill réel) : `ZSessionConfigKey` (AD-24) + providers study génériques + 3 suites `flutter test` (+23 verts) ; R3-I2/I3/I4/I5 prouvées rouges ; graphe 45 arêtes acyclique ; `melos run verify` repo-wide RC=0 — statut review | dev-story |
