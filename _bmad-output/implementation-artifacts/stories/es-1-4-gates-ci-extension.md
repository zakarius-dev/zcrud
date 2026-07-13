# Story ES-1.4 : Gates CI d'extension — anti-`reflectable`, secrets, codegen, compat de sérialisation + **`gate:reserved-keys`** (AD-19.1.c)

Status: review

<!-- Note: Validation optionnelle. Lancer validate-create-story avant dev-story si souhaité. -->

## Story

As a **mainteneur**,
I want **étendre l'infrastructure de gates CI existante aux packages study (présents et FUTURS) et rendre AD-19.1 EXÉCUTOIRE par un gate `reserved-keys`**,
so that **l'hygiène (pas de `reflectable`, pas de secret, codegen à jour, désérialisation défensive, clés de sync réservées) soit vérifiée repo-wide à chaque push — AVANT qu'ES-2 ne crée ~8 nouvelles entités qui reproduiraient l'oubli qui a produit les 2 findings HIGH d'ES-1.3 sous 1193 tests verts**.

> **Métadonnées** — Taille : **M** (bornée haute : le gate M5 est un livrable à part entière) · Statut initial : `backlog` · Parallélisation : **SÉQUENTIELLE légère** (fichiers CI/scripts/tool disjoints du code des packages ; **n'écrit AUCUN fichier `packages/*/lib`** hors ajout de `dart_test.yaml`) · **Dernière story de l'epic ES-1** → suivie de `bmad-retrospective` + commit d'epic.
> **Fichiers** : `scripts/ci/*`, `scripts/dev/*`, `.github/workflows/ci.yml`, `pubspec.yaml` (bloc `melos.scripts` + `workspace`), `melos.yaml` (miroir M-1), **nouveau harnais `tool/reserved_keys_gate/`**, `packages/zcrud_study_kernel/dart_test.yaml`.
> **Couvre** : NFR-S2, NFR-S4, NFR-S8 · **AD** : **AD-19.1.c (M5 — NON NÉGOCIABLE)**, AD-19.1.a/b, AD-1, AD-3, AD-4, AD-10, AD-12, AD-16 · **Hérité** : finding **M5** du code-review ES-1.3.

---

## ⛔ Condition de clôture NON NÉGOCIABLE

**ES-1.4 NE PEUT PAS ÊTRE CLÔTURÉE SANS `gate:reserved-keys` (volets A ET B), prouvé PAR INJECTION DE RÉGRESSION.**
Un gate qu'on n'a **pas vu échouer** n'est pas un gate (méthode qui a validé `gate:web` et le garde de surface en ES-1.2). La vérif verte prouve l'autorité du **résolveur** ; **rien** ne prouve aujourd'hui la propreté des **entités**.

---

## Contexte & décisions de conception (LIRE AVANT DE CODER — NE PAS REJOUER CES TRANCHAGES)

L'inspection sur disque **a été faite**. Les 5 tranchages ci-dessous sont **fermés** : implémenter tel quel.

### État RÉEL de l'infrastructure de gates (vérifié, avec chemins)

| Gate / script | Fichier | Découverte des packages | Couvre `zcrud_study_kernel` ? | Couvrira ES-2 sans édition ? |
|---|---|---|---|---|
| `gate:graph` (AD-1) | `scripts/dev/graph_proof.py` | `glob(packages/*/pubspec.yaml)` | ✅ oui | ✅ **oui** |
| `gate:melos` (M-1) | `scripts/ci/gate_melos_divergence.dart` | s.o. (compare 2 blocs YAML) | s.o. | s.o. |
| `gate:reflectable` (AD-3) | `scripts/ci/gate_reflectable.dart` | scan récursif de `packages` (`lib/ bin/ tool/ test/ example/`) | ✅ oui | ✅ **oui** (allowlist = **1 chemin scopé** `zcrud_get/lib/src/data/codecs/reflectable_codec.dart` ; tout autre fichier, n'importe où, est en violation) |
| `gate:secrets` (AD-12) | `scripts/ci/gate_secret_scan.dart` | `--root` défaut `.` → **dépôt entier** (couvre `tool/`, `scripts/`, `.github/`) | ✅ oui | ✅ **oui** |
| `gate:codegen` (AD-3) | `scripts/ci/gate_codegen.dart` | scan récursif de `packages` | ✅ oui | ✅ **oui** |
| `gate:compat` (FR-25) | `scripts/ci/gate_compat_resolution.dart` | `tool/compat_check` isolé | s.o. | s.o. |
| `gate:web` (ES-1.2) | `scripts/ci/gate_web_determinism.dart` | ❌ **`const _kernelPath = 'packages/zcrud_study_kernel'` EN DUR** | ✅ oui | ❌ **NON** |
| `verify:serialization` (E2-10/AD-10) | `scripts/ci/verify_serialization.dart` | `Directory('packages').listSync()` + aiguillage `dart`/`flutter` par package | ✅ oui | ✅ **oui** |
| `verify` (agrégat) | `pubspec.yaml` (**source de vérité**) + `melos.yaml` (**miroir**) | enchaîne les 8 scripts ci-dessus | — | — |
| CI | `.github/workflows/ci.yml` | steps **listés à la main**, pas `melos run verify` | — | ❌ dérive possible |

**Verdict** : l'infra est saine et **majoritairement auto-découvrante**. **Deux** trous réels + **un** manquant :
1. `gate:web` a la **seule liste en dur** du repo → un futur `zcrud_session`/`zcrud_note` pur-Dart ne serait **pas** couvert.
2. **`ci.yml` n'installe PAS Node** → `gate:web` **SKIPpe silencieusement en CI depuis ES-1.2** : le déterminisme web n'est en fait **jamais vérifié en CI**, alors que le dartdoc du gate affirme « La CI de référence installe Node (`actions/setup-node`) ». **Faux vert avéré.**
3. **`gate:reserved-keys` n'existe pas** (M5). Rien ne casse si une entité oublie `...ZSyncMeta.reservedKeys`.

### Inventaire RÉEL des entités (base du gate M5)

**5 `kind` enregistrés** (`void registerZXxx(ZcrudRegistry)` générés, dans `packages/*/lib/**/*.g.dart`) :

| Registrar | `kind` | Package | `ZExtensible` ? |
|---|---|---|---|
| `registerZStudyFolder` | `study_folder` | `zcrud_study_kernel` | ✅ |
| `registerZStudySessionConfig` | `study_session_config` | `zcrud_study_kernel` | ✅ |
| `registerZFlashcard` | `flashcard` | `zcrud_flashcard` | ✅ |
| `registerZRepetitionInfo` | `repetition_info` | `zcrud_flashcard` | ✅ |
| `registerZChoice` | `flashcard_choice` | `zcrud_flashcard` | ❌ **NON** (pas d'`extra`) |

> ⚠️ **Piège n°1 — `ZChoice`** : enregistré mais **pas** `ZExtensible`. Le cast `(e as ZExtensible)` de la spec AD-19.1.c **throw** dessus. Le gate DOIT : appliquer **(a)/(b) uniquement aux `ZExtensible`**, et **(c)/(d) à TOUS les kinds** (un `toMap` qui émettrait `is_deleted` est fautif même sans `extra`).

**6 classes `with ZExtensible`** (dont 2 **non enregistrées**, `fromJson`/`toJson` manuels → **liste explicite de sondes** exigée par la spec) :

| Classe | Fichier | Enregistrée ? |
|---|---|---|
| `ZStudyFolder` | `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart:80` | ✅ `study_folder` |
| `ZStudySessionConfig` | `packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart:54` | ✅ `study_session_config` |
| `ZFlashcard` | `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart:66` | ✅ `flashcard` |
| `ZRepetitionInfo` | `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart:66` | ✅ `repetition_info` |
| `ZMindmap` | `packages/zcrud_mindmap/lib/src/domain/z_mindmap.dart:21` | ❌ **sonde manuelle** |
| `ZMindmapNode` | `packages/zcrud_mindmap/lib/src/domain/z_mindmap_node.dart:34` | ❌ **sonde manuelle** |

**Fixtures à EXCLURE du scan** : `packages/zcrud_generator/test/models/*.g.dart` (`registerArticle`/`registerAuthor` — modèles de test du générateur, pas des entités du domaine).

---

### D1 — TRANCHAGE « découverte automatique » : **un seul gate à dé-durcir** (`gate:web`)

Tous les autres gates parcourent déjà `packages/*` dynamiquement ⇒ **aucune liste en dur à supprimer ailleurs**. Un package ES-2 créé demain est couvert par `graph`/`reflectable`/`secrets`/`codegen`/`verify:serialization`/`analyze`/`test` **sans toucher un gate**.

**`gate:web` est généralisé** : plutôt qu'une liste d'opt-in (à maintenir), on adopte **default-ON + opt-OUT justifié** :

- **Cible** = **tout package pur-Dart** (pubspec sans `flutter: sdk: flutter` en `dependencies`) possédant un dossier `test/` — détection **par le même helper que `verify_serialization.dart`** (`_isFlutterPackage`, à factoriser/recopier).
- **Opt-out allowlisté et JUSTIFIÉ PAR ÉCRIT** (dans le script) :
  - `zcrud_generator` — **builder `build_runner` VM-only** : dépend de `dart:io`/`analyzer`/`build`, `dart test -p node` est structurellement inapplicable (ce n'est pas du code embarquable dans une app web).
  - `zcrud_annotations` — pas de `test/` aujourd'hui ; **aucun opt-out** (couvert automatiquement s'il en gagne un).
- Conséquence : `zcrud_note`, `zcrud_session`, `zcrud_exam` (pur-Dart attendus) seront couverts **à leur création**, sans édition du gate.
- La **dégradation propre** (SKIP bruyant RC=0 si Node absent) est **conservée à l'identique** — c'est la convention maison.

> ⚠️ **Piège n°2** : un package pur-Dart dont les tests importent `dart:io` sans `@TestOn('vm')` fera **rougir** `gate:web` à sa création. C'est **voulu** (le message d'échec du gate le dit déjà : « Piste n°2 »). Ne PAS ajouter d'opt-out de confort : soit le test est taggé `@TestOn('vm')`, soit le package sort de la cible pour une raison **écrite**.

---

### D2 — TRANCHAGE « où vit le volet (A) du gate M5 » : **nouveau harnais `tool/reserved_keys_gate/`**

**Le problème** : le volet (A) doit **décoder** via un `ZcrudRegistry` peuplé de **TOUS** les `registerXxx` du repo. Les entités vivent dans `zcrud_study_kernel`, `zcrud_flashcard` **et** `zcrud_mindmap`. **Aucun package existant ne voit les trois** (`zcrud_flashcard` ne dépend pas de `zcrud_mindmap`), et **créer** une telle arête violerait AD-1 (dépendance runtime artificielle entre satellites). Un script Dart hors-package ne peut pas non plus décoder (pas d'imports).

**Décision : un harnais dev/test-only sous `tool/`** — patron **déjà établi deux fois** dans ce repo (`tool/compat_check` en E1-4, `tool/binding_conformance` en E2-9). **Ne pas réinventer : copier la structure de `tool/binding_conformance`.**

```
tool/reserved_keys_gate/
  pubspec.yaml                 # name: reserved_keys_gate (SANS préfixe zcrud_), publish_to: none, resolution: workspace
  lib/reserved_keys_gate.dart  # barrel : registrars câblés + sondes manuelles + allowlist + assertions
  lib/src/registrars.dart      # kRegistrars : List<void Function(ZcrudRegistry)> + kProbeBodies : Map<kind, corps minimal>
  lib/src/manual_probes.dart   # sondes des entités NON enregistrées (ZMindmap, ZMindmapNode)
  lib/src/assertions.dart      # assertReservedKeysClean(...) — assertions (a)(b)(c)(d) réutilisables
  test/reserved_keys_test.dart # @Tags(['reserved-keys']) — volet (A) + contre-exemple mensonger
  dart_test.yaml               # déclare le tag reserved-keys
```

**Pourquoi c'est acyclique (à recopier en Completion Notes)** :
1. `scripts/dev/graph_proof.py` n'itère que `glob('packages/*/pubspec.yaml')` ⇒ **`tool/` est structurellement invisible** pour le graphe. **ACYCLIQUE / CORE OUT=0 inchangés.**
2. Le harnais est un **puits (sink)** : **aucun** package `zcrud_*` ne dépend de lui (contrairement à `binding_conformance`, référencé en `dev_dependency` des bindings). **Zéro** arête entrante ⇒ **aucun cycle possible par construction**.
3. Nom **SANS préfixe `zcrud_`** (convention E2-9) : même si le scan de graphe était un jour élargi, la regex `EDGE = ^\s+(zcrud_[a-z_]+)\s*:` ne l'attraperait pas.
4. Membre du bloc `workspace:` du root `pubspec.yaml` (résolution partagée, lockfile racine unique) mais **HORS du glob melos `packages/**`** ⇒ `melos list` **reste 15** (invariant produit) ⇒ il faut l'ajouter au bloc `ignore:` de **`pubspec.yaml` ET `melos.yaml`** (M-1).

**Package Flutter** : `zcrud_core` est un package Flutter depuis E2-7 ⇒ le harnais tire `flutter`/`flutter_test` et se lance avec **`flutter test`** (comme `binding_conformance`). Dépendances : `zcrud_core`, `zcrud_study_kernel`, `zcrud_flashcard`, `zcrud_mindmap` (contraintes `^0.1.0`, cf. REL-1/D2).

> ⚠️ **Piège n°3 — le harnais est dans `melos.ignore`** ⇒ **`melos run test` NE L'EXÉCUTERA PAS**. Le volet (A) DOIT donc être lancé **explicitement** par `scripts/ci/gate_reserved_keys.dart` (`flutter test --tags reserved-keys` dans `tool/reserved_keys_gate`), sinon le gate est un **faux vert total**. C'est le piège n°1 de cette story.

**Extension ES-2 (documenter dans le README/dartdoc du harnais)** : créer une entité study ⇒ ajouter son `registerZXxx` à `kRegistrars` **et** son corps de sonde à `kProbeBodies`. **L'oublier ne passe PAS inaperçu** : le contrôle de couverture (D2-bis) rend le gate **ROUGE**.

### D2-bis — TRANCHAGE « anti-faux-vert par omission » (exigé mot pour mot par AD-19.1.c pt.1)

`scripts/ci/gate_reserved_keys.dart` **dérive l'inventaire du DISQUE** et le confronte au **câblage du harnais** :

| Ensemble | Dérivation |
|---|---|
| `R_disk` | `grep` des `void registerZ<Xxx>(ZcrudRegistry` dans `packages/*/lib/**/*.g.dart` (**exclut** `packages/zcrud_generator/test/**`) |
| `R_wired` | registrars **réellement référencés** dans `tool/reserved_keys_gate/lib/src/registrars.dart` |
| `E_disk` | classes `class X ... with ZExtensible` dans `packages/*/lib/**/*.dart` (hors `*.g.dart`) |
| `E_covered` | classes couvertes par un `kind` de `R_wired` **∪** sondes manuelles de `manual_probes.dart` **∪** allowlist syntaxique justifiée |

- `R_disk \ R_wired ≠ ∅` → **ROUGE** : « `registerZSmartNote` existe mais n'est pas câblé dans `tool/reserved_keys_gate/lib/src/registrars.dart` — le gate serait un faux vert par omission (AD-19.1.c pt.1). »
- `E_disk \ E_covered ≠ ∅` → **ROUGE** : « `ZFoo` porte un `extra` mais n'est ni enregistrée ni sondée. »
- Un `kind` de `kProbeBodies` **sans** registrar correspondant, ou un registrar **sans** corps de sonde → **ROUGE** (anti-pourrissement).

---

### D3 — TRANCHAGE « allowlist legacy » : explicite, justifiée, **VERROUILLÉE**, et **anti-inertie**

```dart
/// Miroirs de compat AD-19.2 (pts 1-3) — SEULS kinds tolérés à ÉMETTRE `updated_at`
/// depuis leur `toMap()` (assertion (d) UNIQUEMENT).
///
/// - 'study_folder' : ZStudyFolder.updatedAt, miroir DÉPRÉCIÉ maintenu par collision
///   de clé (le store écrit la méta APRÈS le corps ⇒ le miroir n'a AUCUN pouvoir
///   d'écriture — AD-19.2 pt.1/2, prouvé ES-1.3 AC5-bis).
/// - 'flashcard'    : ZFlashcard.updatedAt, miroir de même nature NON déprécié
///   (surface E9 consommée par la migration DODLP — AD-19.2 pt.3, dette DW-ES13-2).
///
/// ⛔ TOUTE nouvelle entrée = DÉCISION D'ARCHITECTURE (mise à jour d'AD-19.2 + note
/// écrite en code-review). CE N'EST PAS UN ÉCHAPPATOIRE DE CONFORT. Le test de
/// VERROU ci-dessous devient ROUGE si l'ensemble change : on ne « passe pas le gate »
/// en y ajoutant son kind sans que quelqu'un l'ait vu.
const Set<String> kLegacyUpdatedAtMirrors = <String>{'study_folder', 'flashcard'};
```

**Trois protections cumulées :**
1. **Portée minimale** : l'allowlist **ne s'applique QU'À l'assertion (d)** (`encode` émet `updated_at`). Les assertions **(a)** (`extra` propre), **(b)** (round-trip AD-4 préservé) et **(c)** (`encode` n'émet **jamais** `is_deleted`) sont **SANS EXCEPTION**, pour **tous** les kinds, **legacy compris**.
2. **Test de verrou** (dans `test/reserved_keys_test.dart`) : `expect(kLegacyUpdatedAtMirrors, equals({'study_folder', 'flashcard'}))` — **toute** croissance/réduction rend la suite **ROUGE**. Élargir l'allowlist exige donc d'éditer **sciemment** un attendu figé (geste visible en revue), jamais un ajout discret.
3. **Anti-inertie** : chaque entrée doit correspondre à un `kind` **réellement enregistré** ; une entrée morte (kind disparu) → **ROUGE**.

> **Réponse explicite à la question « le gate doit-il échouer si l'allowlist grossit sans justification ? » → OUI**, par le test de verrou (2). Le gate ne peut pas lire une justification en prose ; il rend l'élargissement **impossible en silence**, ce qui est l'équivalent exécutoire.

---

### D4 — TRANCHAGE « AC gate de compat de sérialisation » (renvoi ES-3.5) : **pas de faux vert**

**État réel** : le slot `verify:serialization` **existe** (E1-3), est **rattaché au gate de merge** (`melos run verify` + `ci.yml`), et **auto-découvre `packages/*`** ⇒ `zcrud_study_kernel` est **déjà** dans son périmètre **sans aucune édition**. La suite de tests, elle, est un livrable **ES-3.5** (corpus de rétro-compat).

**Le vrai risque** : `exit 79` (« aucun test taggé ») est **toléré silencieusement** ⇒ **faux vert structurel** — exactement la maladie que cette story combat.

**Décision (3 gestes, zéro invention de corpus)** :
1. **NE PAS** écrire de corpus de rétro-compat ici (périmètre ES-3.5) — et **ne pas** simuler un test vert.
2. **Rendre le SKIP BRUYANT** (patron `gate:web`) : bannière explicite listant **nommément** les packages sans test `serialization-compat`, disant noir sur blanc que **la rétro-compat n'a PAS été vérifiée** et renvoyant à **ES-3.5** (+ E2-10). RC reste **0** (le corpus n'est pas encore dû).
3. **Câbler le point d'accroche** : créer `packages/zcrud_study_kernel/dart_test.yaml` déclarant le tag `serialization-compat` (calqué sur `packages/zcrud_generator/dart_test.yaml`), + **interrupteur de bascule** `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` (env) qui fait passer le SKIP en **ÉCHEC** : ES-3.5 n'aura qu'à l'activer en CI, **sans toucher au workflow ni au script**.

---

### D5 — TRANCHAGE « CI GitHub » : elle existe, mais elle **ment sur `gate:web`** et **duplique la liste des gates**

`.github/workflows/ci.yml` **existe** et respecte l'ordre imposé (**codegen → analyze → test → gates**). Deux défauts :

1. ❌ **Aucun `actions/setup-node`** ⇒ `gate:web` **SKIPpe à chaque build depuis ES-1.2** (son propre dartdoc prétend le contraire). → **AJOUTER `actions/setup-node@v4`** avant les gates. *(Après cet ajout, `dart test -p node` s'exécutera réellement en CI : si un test du kernel importe `dart:io` sans `@TestOn('vm')`, la CI rougira — c'est le comportement attendu, à traiter, pas à contourner.)*
2. ❌ La CI **re-liste** les gates à la main ⇒ **classe de dérive** identique à celle que `gate:melos` (M-1) combat : un gate ajouté à `verify` et oublié dans `ci.yml` (ou l'inverse) passe inaperçu.
   → **La CI exécute `dart run melos run verify` comme step UNIQUE des gates** (c'est déjà ce que la description de `verify` promet : « miroir de la CI »). On **conserve en steps distincts** ce qui n'est **pas** dans `verify` : `gitleaks` (autorité historique git, CI-only) et `prove_gates.dart` (preuve par fixtures). **Dérive supprimée par construction** — plus aucune liste dupliquée.

---

## Acceptance Criteria

### AC1 — `gate:reserved-keys` **volet (A) COMPORTEMENTAL** (AD-19.1.c) — l'autorité rouge/vert
**Given** un `ZcrudRegistry` peuplé par **tous** les registrars du repo (`kRegistrars`)
**When** on décode, pour **chaque `kind` enregistré**, la sonde `{...corpsMinimalValide(kind), 'updated_at': '2026-01-01T00:00:00.000Z', 'is_deleted': true, 'zz_cle_inconnue': 'gardee'}`
**Then** pour chaque kind :
- **(a)** si l'entité est `ZExtensible` : `extra.keys.toSet().intersection(ZSyncMeta.reservedKeys)` est **vide** ;
- **(b)** si l'entité est `ZExtensible` : `extra['zz_cle_inconnue'] == 'gardee'` (round-trip AD-4 **non régressé** — interdit de « passer le gate » en vidant `extra`) ;
- **(c)** `registry.encode(kind, e)` **ne contient PAS** `is_deleted` — **aucune exception, aucun kind** ;
- **(d)** `registry.encode(kind, e)` **ne contient PAS** `updated_at`, **sauf** `kind ∈ kLegacyUpdatedAtMirrors` (`study_folder`, `flashcard`) ;
- les kinds **non `ZExtensible`** (`flashcard_choice`) subissent **(c)/(d)** sans crash (pas de cast `as ZExtensible` aveugle).
**And** les entités **non enregistrées** portant un `extra` (`ZMindmap`, `ZMindmapNode`) subissent les **mêmes** assertions (a)(b)(c)(d) via **sondes manuelles explicites**, **sans allowlist**.
**And** le test porte `@Tags(['reserved-keys'])` et le tag est déclaré dans `tool/reserved_keys_gate/dart_test.yaml`.

### AC2 — **Anti-faux-vert par omission** : un registrar/une entité non câblé(e) fait ROUGIR le gate
**Given** `scripts/ci/gate_reserved_keys.dart`
**When** un `void registerZXxx(ZcrudRegistry` existe dans `packages/*/lib/**/*.g.dart` (hors fixtures `zcrud_generator/test/**`) mais **n'est pas** câblé dans `registrars.dart` — **ou** une classe `with ZExtensible` n'est ni enregistrée, ni sondée, ni allowlistée
**Then** le gate sort **RC ≠ 0** avec un message **actionnable** nommant le symbole et le fichier à éditer.
**And** un `kind` de `kProbeBodies` sans registrar (ou l'inverse), ou une entrée morte de `kLegacyUpdatedAtMirrors`, fait aussi **RC ≠ 0**.

### AC3 — `gate:reserved-keys` **volet (B) SYNTAXIQUE** (filet anti-oubli pédagogique)
**Given** un scan repo-wide de `packages/*/lib/**/*.dart` (hors `*.g.dart`)
**When** un fichier déclare une classe **`with ZExtensible`** (ou un champ `extra`) **sans** contenir le texte `ZSyncMeta.reservedKeys` et **sans** figurer dans une allowlist **justifiée par écrit dans le script**
**Then** le gate sort **RC ≠ 0** avec le message : `« ajoutez ...ZSyncMeta.reservedKeys à _reservedKeys (AD-19.1) — fichier: <path> »`.
**And** sur l'arbre RÉEL, les **6** classes de l'inventaire passent (`ZMindmap`/`ZMindmapNode` consomment `ZSyncMeta.reservedKeys` via `_reservedSyncKeys`, ES-1.3 pt.5).
**And** le volet (B) **ne remplace pas** (A) : les deux tournent, les deux peuvent rougir indépendamment.

### AC4 — **PREUVE PAR INJECTION DE RÉGRESSION** (obligatoire, journalisée)
**Given** le gate implémenté et vert
**When** on retire `...ZSyncMeta.reservedKeys` de `_reservedKeys` dans `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart` (≈ l. 243)
**Then** `dart run melos run gate:reserved-keys` sort **RC ≠ 0** — **volet (A)** échoue sur **(a)** (les 2 clés de sync polluent `extra` de `repetition_info`) **ET (d)** (`encode` réémet `updated_at` hors allowlist) — **et volet (B)** échoue aussi (le fichier ne contient plus le texte).
**When** on **restaure** le fichier
**Then** le gate **redevient RC = 0**.
**And** la **sortie ROUGE brute** (extrait) + la re-vérif verte sont **collées dans les Completion Notes** de la story. *(Injection à rejouer aussi sur `packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart` — les 2 entités des findings HIGH d'ES-1.3.)*
**And** le repo est laissé **PROPRE** (`git status` sans modification résiduelle des entités).

### AC5 — Contre-exemple mensonger **permanent** (le gate mord, prouvé à chaque run)
**Given** une entité **volontairement fautive** définie **DANS le harnais** (`_LyingEntity` : capture tout dans `extra`, réémet `is_deleted`/`updated_at`), enregistrée dans un registre **local au test**
**When** on lui applique les **mêmes** assertions `assertReservedKeysClean(...)`
**Then** elles **ÉCHOUENT** (`expect(() => …, throwsA(isA<TestFailure>()))`) — le gate ne peut pas devenir tautologiquement vert.
*(Patron `z_sync_meta_authority_test.dart` d'ES-1.3 : le miroir mensonger.)*

### AC6 — Gates existants **repo-wide** et **auto-découvrants** pour ES-2 (NFR-S2/NFR-S8)
**Given** les 15 packages (dont `zcrud_study_kernel`) et les futurs `zcrud_note`/`zcrud_document`/`zcrud_session`/`zcrud_exam`/`zcrud_study`
**Then** `gate:reflectable`, `gate:secrets`, `gate:codegen`, `gate:graph`, `verify:serialization` les couvrent **sans liste en dur** *(vérifié : aucune liste à supprimer — cf. D1)*
**And** `gate:web` est **généralisé** : cible = **tout package pur-Dart avec `test/`**, opt-out **allowlisté et justifié par écrit** (`zcrud_generator` : builder VM-only) — plus de `_kernelPath` en dur
**And** `prove_gates.dart` gagne une fixture **anti-`reflectable` dans un package study** (`packages/zcrud_study_kernel/bin/…` éphémère) prouvant l'AC de l'epic.

### AC7 — `melos` : `gate:reserved-keys` câblé dans `verify` — **des DEUX côtés** (M-1)
**Given** la source de vérité `pubspec.yaml` (bloc `melos.scripts`) et son **miroir** `melos.yaml`
**Then** un script `gate:reserved-keys` existe **à l'identique dans les deux**, et l'agrégat `verify` l'enchaîne
**And** `dart run melos run gate:melos` reste **RC = 0** (aucune divergence)
**And** `tool/reserved_keys_gate` est ajouté au bloc `workspace:` du root `pubspec.yaml` **et** au bloc `ignore:` de `pubspec.yaml` **et** de `melos.yaml` ⇒ **`melos list` reste 15**.

### AC8 — CI GitHub : Node installé + gates **non dupliqués** + ordre respecté (NFR-S2)
**Given** `.github/workflows/ci.yml`
**Then** un step `actions/setup-node@v4` précède les gates ⇒ **`gate:web` s'exécute RÉELLEMENT** (fin du SKIP permanent)
**And** les gates sont exécutés par le step **unique** `dart run melos run verify` (plus de liste dupliquée), `gitleaks` et `prove_gates.dart` restant des steps CI-only
**And** l'ordre **codegen → analyze → test → gates** est **préservé**
**And** les commentaires d'en-tête du workflow sont mis à jour (ils décrivent la liste supprimée).

### AC9 — Slot de rétro-compat de sérialisation : **renvoi ES-3.5 sans faux vert** (NFR-S4)
**Given** `scripts/ci/verify_serialization.dart`
**Then** son périmètre couvre **déjà** `packages/*` dynamiquement (**aucune édition de périmètre**)
**And** le SKIP devient **BRUYANT** : bannière nommant les packages **sans** test `serialization-compat` et renvoyant explicitement à **ES-3.5**
**And** `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` transforme ce SKIP en **ÉCHEC** (interrupteur qu'ES-3.5 activera sans toucher au script ni au workflow)
**And** `packages/zcrud_study_kernel/dart_test.yaml` déclare le tag `serialization-compat` (point d'accroche prêt)
**And** **aucun** test de rétro-compat n'est inventé ici.

### AC10 — Vérif verte repo-wide + non-régression chiffrée (gate de commit d'epic — leçon `ZExportApi`)
**Then** rejouer **réellement** :
- `dart run melos run generate` → **RC 0**
- `dart run melos run analyze` **REPO-WIDE** → **RC 0**
- `dart run melos run verify` **REPO-WIDE** → **RC 0** (inclut le nouveau gate)
- `dart run melos run test` → **RC 0**, avec **oracles de non-régression** : `zcrud_study_kernel` **≥ 108** (VM) / **≥ 98** (node) · `zcrud_flashcard` **≥ 189** · `zcrud_core` **≥ 911** · `zcrud_firestore` **≥ 90** · `zcrud_mindmap` **≥ 110**
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK** + **CORE OUT=0 OK**
- `dart run scripts/ci/prove_gates.dart` → **RC 0**
- `dart run melos list` → **15** packages

---

## Tasks / Subtasks

- [x] **T1 — Harnais `tool/reserved_keys_gate/`** (AC1, AC5) — *copier la structure de `tool/binding_conformance`*
  - [x] `tool/reserved_keys_gate/pubspec.yaml` : `name: reserved_keys_gate` (**sans** préfixe `zcrud_`), `publish_to: none`, `version: 0.0.1`, `resolution: workspace`, `environment.sdk: ^3.12.2` ; `dependencies` : `zcrud_core: ^0.1.0`, `zcrud_study_kernel: ^0.1.0`, `zcrud_flashcard: ^0.1.0`, `zcrud_mindmap: ^0.1.0`, `flutter: {sdk: flutter}`, `flutter_test: {sdk: flutter}` — **en-tête dartdoc reprenant D2 (acyclicité)**.
  - [x] `lib/src/registrars.dart` : `kRegistrars` (les **5** registrars) + `kProbeBodies` (`kind → corps minimal valide`) + **`kDomainDecoders`** (déviation ratifiée, cf. Completion Notes). **Fallback interdit** : un kind sans corps/décodeur → ROUGE (AC2).
  - [x] `lib/src/manual_probes.dart` : sondes `ZMindmap`/`ZMindmapNode` (`fromJson`/`toJson` manuels, **hors registre**).
  - [x] `lib/src/assertions.dart` : `assertReservedKeysClean(...)` → assertions **(a)(b)(c)(d)**, `(a)/(b)` **conditionnées à `entity is ZExtensible`** *(piège n°1 : `ZChoice`)*. `ZSyncMeta.stripReserved` consommé par (a) ⇒ **L4 soldée**.
  - [x] `lib/reserved_keys_gate.dart` (barrel) + `dart_test.yaml` (tag `reserved-keys`).
  - [x] `test/reserved_keys_test.dart` : `@Tags(['reserved-keys'])` — **20 tests** : boucle sur tous les kinds (voie domaine + voie registre) + sondes manuelles + **verrou de l'allowlist** + **anti-inertie** + **contre-exemple mensonger** `_LyingEntity` (AC5).
- [x] **T2 — `scripts/ci/gate_reserved_keys.dart`** (AC1, AC2, AC3)
  - [x] Volet **(B)** : scan `packages/*/lib/**/*.dart` (hors `*.g.dart`), commentaires **strippés** avant le test de présence du texte ; allowlist `kSyntacticAllowlist` **vide et justifiée** ; message pédagogique exact d'AC3.
  - [x] **Contrôle de couverture** (D2-bis) : `R_disk`/`R_wired`/`E_disk`/`E_covered` + **câblage mort** → ROUGE actionnable.
  - [x] Volet **(A)** : `flutter test --tags reserved-keys` dans `tool/reserved_keys_gate`, stdout/stderr relayés, RC propagé, **`exit 79` ⇒ FATAL** *(piège n°3)*.
  - [x] `--root` pour les fixtures ; en-tête dartdoc citant **AD-19.1.c** + H1/H2 d'ES-1.3.
- [x] **T3 — Généraliser `gate:web`** (AC6) — `_kernelPath` **supprimé** ; cible = tout package pur-Dart avec `test/` (`zcrud_annotations`, `zcrud_study_kernel`), opt-out `{'zcrud_generator'}` justifié ; SKIP bruyant + `ZCRUD_SKIP_WEB_GATE` conservés. **Piège n°2 matérialisé et traité** : `zcrud_annotations/test/no_runtime_dep_test.dart` (lecture disque `dart:io`) taggé `@TestOn('vm')` — pas d'opt-out de confort.
- [x] **T4 — `verify:serialization` : SKIP bruyant + interrupteur** (AC9) — bannière nommant les 14 packages sans corpus + renvoi **ES-3.5** ; `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` ⇒ **RC=1** (vérifié) ; `packages/zcrud_study_kernel/dart_test.yaml` créé. **Aucun corpus inventé.**
- [x] **T5 — Câblage melos** (AC7) — `pubspec.yaml` (source de vérité) + `melos.yaml` (miroir) : `workspace:`, `ignore:`, `gate:reserved-keys`, `verify`. Compteurs « 14 » → **15**. `gate:melos` **RC=0 (15 scripts)**. `melos list` = **15**.
- [x] **T6 — CI GitHub** (AC8) — `actions/setup-node@v4` ajouté ; gates → **step unique `dart run melos run verify`** ; `gitleaks` + `prove_gates` conservés en steps CI-only ; en-tête refondu (la dérive est désormais impossible par construction).
- [x] **T7 — `prove_gates.dart`** (AC6) — 3 fixtures ajoutées (**26 OK / 0 FAIL**) : anti-`reflectable` dans `zcrud_study_kernel/bin` (nettoyée en `finally`), volet (B) syntaxique, registrar non câblé.
- [x] **T8 — PREUVE PAR INJECTION DE RÉGRESSION** (AC4) — 2 entités, ROUGE → restauration → VERT, sorties collées en Completion Notes ; arbre restauré à l'octet près.
- [x] **T9 — Vérif verte repo-wide + oracles** (AC10) — `generate`/`analyze`/`verify`/`test`/`graph_proof`/`prove_gates`/`melos list` : **tous verts**.

---

## Dev Notes

### Invariants non négociables
- **AD-1** : rien ne doit créer d'arête entre satellites. Le harnais vit sous `tool/` **précisément** pour ça (D2). **Ne JAMAIS** ajouter `zcrud_mindmap` aux `dependencies` de `zcrud_flashcard` « pour voir les deux ».
- **M-1** : `pubspec.yaml` = **source de vérité** des scripts melos ; `melos.yaml` = **miroir**. Éditer un seul des deux ⇒ `gate:melos` ROUGE (et le script serait **silencieusement sans effet**).
- **AD-3** : ne jamais éditer un `*.g.dart` à la main ; ils sont **gitignorés** (régénérés). Le scan `R_disk` les lit **après** `melos run generate` — le gate **présuppose donc le codegen** (comme `gate:codegen`) : le documenter dans l'en-tête et **le placer après `generate`** dans la CI.
- **Convention maison des gates** (à imiter, pas à réinventer) : script **Dart** (jamais `grep` shell — historique de greps buggés), `--root` pour fixtures, dégradation **propre et BRUYANTE**, messages français, RC explicite, dartdoc citant l'AD.

### Pièges (anti-régression)
1. **`ZChoice` n'est pas `ZExtensible`** → `(e as ZExtensible)` **throw**. Conditionner (a)/(b).
2. **Le harnais est dans `melos.ignore`** → `melos run test` **ne le lance pas** ⇒ **faux vert total** si le gate ne l'invoque pas explicitement.
3. **`exit 79`** : toléré dans `verify:serialization` (corpus dû en ES-3.5), **FATAL** dans `gate:reserved-keys` (aucun test = le gate n'a rien prouvé).
4. **`flutter test`** (pas `dart test`) pour le harnais : `zcrud_core` est Flutter depuis E2-7.
5. **Fixtures dans l'arbre réel** : nettoyage **inconditionnel en `finally`** (patron M-3 de `prove_gates.dart`) — aucune fixture ne doit rester committée en état de violation.
6. **`melos list` = 15** (pas 14) : les commentaires du repo sont **périmés** depuis ES-1.1.
7. **`pubspec.lock`** : le lock **racine** peut bouger (nouveau membre) ; **ne pas committer** les `pubspec.lock` de package.

### Extension ES-2 (contrat à documenter dans le harnais)
Créer une entité study ⇒ **2 lignes** : ajouter `registerZXxx` à `kRegistrars` **et** son corps à `kProbeBodies`. **L'oublier = ROUGE** (AC2). Aucune édition de gate n'est requise pour un **nouveau package**.

### Dette / renvois
- **ES-3.5** : corpus de rétro-compat de sérialisation (activer `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1`).
- **DW-ES13-2** : dépréciation formelle de `ZFlashcard.updatedAt` → sortie de `kLegacyUpdatedAtMirrors` (ES-2/ES-11).
- **L4 (ES-1.3)** : `ZSyncMeta.stripReserved` sans appelant de production → **soldé** par ce gate.

### Intelligence de la story précédente (ES-1.3, `done`)
Les 2 findings **HIGH** (`ZRepetitionInfo`, `ZStudySessionConfig` fuyant `is_deleted`/`updated_at` dans `extra`) sont passés **sous 1193 tests verts**. Le correctif a ajouté des tests **par entité** — ce qui **ne protège pas** les entités **futures**. C'est la raison d'être de ce gate : le protéger **par machine**, pas par vigilance.

### Project Structure Notes
- **Aucun** fichier de `packages/*/lib` n'est modifié (hors `dart_test.yaml`) — sauf **temporairement** en T8, **restauré**.
- Nouveau membre workspace `tool/reserved_keys_gate` : **hors** `packages/**` (invariant `melos list` = 15), **hors** graphe AD-1.

### References
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-19.1.c`] — **spécification FIGÉE** du gate (volets A et B), allowlist legacy, inventaire de départ.
- [Source: idem #AD-19.1.a / #AD-19.1.b / #AD-19.2] — clés réservées, hint `timestamp` interdit, divergences résiduelles.
- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story ES-1.4`] — ACs d'origine (reflectable/secrets/codegen/compat, repo-wide, codegen avant analyze/test).
- [Source: `_bmad-output/implementation-artifacts/stories/code-review-es-1-3.md`] — finding **M5** (report explicite vers ES-1.4).
- [Source: `packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart`] — `kUpdatedAt`/`kIsDeleted`/`reservedKeys`/`stripReserved`.
- [Source: `scripts/ci/gate_web_determinism.dart`, `scripts/ci/verify_serialization.dart`, `scripts/ci/prove_gates.dart`, `scripts/dev/graph_proof.py`, `melos.yaml`, `pubspec.yaml`, `.github/workflows/ci.yml`] — conventions à imiter.
- [Source: `tool/binding_conformance/pubspec.yaml`] — **patron** du harnais hors-`packages/**` (E2-9).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`).

### Debug Log References

`melos run generate` / `analyze` / `test` / `verify` / `graph_proof` / `prove_gates` rejoués réellement (cf. AC10 ci-dessous).

### Completion Notes List

#### 1. Trois faux verts corrigés (constatés sur disque)

1. **`gate:web` n'était PAS invoqué en CI** (`ci.yml` énumérait les gates à la main et n'appelait jamais `verify`) ⇒ le gate d'ES-1.2 **n'a jamais tourné en CI**.
2. **Node n'était pas installé en CI** ⇒ même invoqué, `gate:web` aurait SKIPpé silencieusement.
3. **`gate_web_determinism.dart` avait `_kernelPath` en dur** ⇒ aucun package ES-2 n'aurait été couvert.

**Correction STRUCTURELLE** : `ci.yml` exécute désormais **`dart run melos run verify` en step unique** (+ `actions/setup-node@v4`). Tout gate ajouté à `verify` est en CI **par construction** ; la classe de dérive « gate dans `verify`, absent de `ci.yml` » est **impossible**. Restent en steps CI-only : `gitleaks` (historique git) et `prove_gates.dart` (fixtures).

#### 2. Deux failles de la spec figée AD-19.1.c (corrigées, architecture.md mis à jour)

- **`(e as ZExtensible)` throw sur `ZChoice`** (enregistrée, mais **pas** `ZExtensible`) ⇒ (a)/(b) **conditionnées à `is ZExtensible`** ; (c)/(d) restent applicables à **tous** les kinds. *(Correction ratifiée par l'orchestrateur.)*
- **`registry.decode(kind, …)` ne peuple PAS `extra`** — découverte de cette story. Les registrars générés câblent `fromMap: _$ZXxxFromMap` (factory du **codegen**), qui ignore le canal hors-codegen `extra`. Décoder *uniquement* par le registre aurait rendu **(a) vacuellement verte** (le gate n'aurait protégé **rien**) et **(b) structurellement rouge**. Le volet (A) décode donc par la **voie de domaine** (`ZXxx.fromMap`, câblée dans `kDomainDecoders`) puis **ré-encode via le registre** pour (c)/(d).
  **Preuve empirique** : sous injection, le test `repetition_info : encodage via le registre` reste **VERT** alors que `repetition_info : sonde polluée` devient **ROUGE**. La lettre de la spec produisait un faux vert.
  **Dette DW-ES14-1 ouverte** (hors périmètre) : `FirebaseZRepositoryImpl` décode via `registry.decode` (`firebase_z_repository_impl.dart:143`) ⇒ **`extra` est perdu sur ce chemin de production** (round-trip AD-4 non préservé côté store). Correctif = `zcrud_generator`. **Signalé, non masqué.**

#### 3. AC4 — PREUVE PAR INJECTION DE RÉGRESSION (sorties brutes)

**Injection 1** — `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart` (retrait de `...ZSyncMeta.reservedKeys`) :

```
[gate:reserved-keys] ÉCHEC : ajoutez `...ZSyncMeta.reservedKeys` à `_reservedKeys` (AD-19.1) — fichier: packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart
[gate:reserved-keys] couverture : 5 registrar(s) sur disque, 5 câblé(s), 2 sonde(s) manuelle(s).
[gate:reserved-keys] volet (A) — flutter test --tags reserved-keys (tool/reserved_keys_gate)…
  [repetition_info] (a) AD-19.1 VIOLÉ : les clés réservées {updated_at, is_deleted} ont été capturées dans `extra`. Ajoutez `...ZSyncMeta.reservedKeys` à `_reservedKeys` de l'entité (la clé ne doit pas pouvoir ENTRER dans `extra`, donc plus en ressortir).
[gate:reserved-keys] ÉCHEC : volet (A) ROUGE : une entité capture/réémet des clés de sync réservées (AD-19.1).
[gate:reserved-keys] 2 violation(s) — AD-19.1.
RC=1
```
**Après restauration** : `[gate:reserved-keys] OK — clés de sync réservées : volet (A) + volet (B) + couverture (AD-19.1.c).` — **RC=0**.

**Injection 2** — `packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart` :

```
[gate:reserved-keys] ÉCHEC : ajoutez `...ZSyncMeta.reservedKeys` à `_reservedKeys` (AD-19.1) — fichier: packages/zcrud_study_kernel/lib/src/domain/z_study_session_config.dart
[gate:reserved-keys] volet (A) — flutter test --tags reserved-keys (tool/reserved_keys_gate)…
  [study_session_config] (a) AD-19.1 VIOLÉ : les clés réservées {updated_at, is_deleted} ont été capturées dans `extra`. …
[gate:reserved-keys] 2 violation(s) — AD-19.1.
RC=1
```
**Après restauration** : **RC=0**.

> Les **deux** volets rougissent : (B) syntaxique (le fichier ne contient plus le texte, commentaires strippés) **et** (A) comportemental. Fail-fast sur (a) : (c)/(d) ne sont pas évaluées pour ce kind une fois (a) rouge — l'entité est capturée quoi qu'il en soit.

**Volet (B) seul + contrôle de couverture** — prouvés par fixtures permanentes (`prove_gates.dart`, RC=0, 26 OK / 0 FAIL) :
```
[OK] reserved-keys/clean                      — exit=0 (arbre réel, volets A+B+couverture)
[OK] reserved-keys/fixture-syntaxique         — exit=1 (ZExtensible sans ZSyncMeta.reservedKeys)
[OK] reserved-keys/fixture-registrar-non-cable— exit=1 (registrar non câblé = faux vert par omission)
[OK] reflectable/study-package-scanned        — exit=1 (package study couvert, AC6)
```

**Arbre PROPRE** : aucune fixture résiduelle (`find packages -name "__gate_proof*"` → vide) ; les 2 entités injectées sont **identiques à l'octet** à leur sauvegarde (`diff` vide, `...ZSyncMeta.reservedKeys` bien présent dans les deux).

#### 4. AC10 — Vérif verte repo-wide (rejouée réellement)

| Commande | Résultat |
|---|---|
| `dart run melos run generate` | **RC=0** (SUCCESS) |
| `dart run melos run analyze` (repo-wide) | **RC=0** — `No issues found!` sur les 15 packages |
| `dart analyze` (harnais `tool/reserved_keys_gate`) | **RC=0** — `No issues found!` |
| `dart run melos run verify` (repo-wide) | **RC=0** — graph · melos · reflectable · secrets · codegen · compat · **web (réellement exécuté)** · **reserved-keys** · verify:serialization |
| `dart run melos run test` | **RC=0** — kernel **108** · flashcard **189** · core **911** · firestore **90** · mindmap **110** · annotations 9 · generator 87 · markdown 269 · intl 169 · geo 162 · export 42 · list 20 · get 17 · provider 8 · riverpod 8 |
| `gate:web` (node) | kernel **98** tests JS · annotations 7 tests JS |
| `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK** · **CORE OUT=0 OK** · 15 nœuds |
| `dart run scripts/ci/prove_gates.dart` | **RC=0** — **26 OK / 0 FAIL** |
| `dart run melos list` | **15** |
| `gate:melos` (M-1) | **RC=0** — « blocs scripts identiques (**15 scripts**) » |

Oracles de non-régression **tous atteints ou dépassés**.

### File List

**Créés**
- `tool/reserved_keys_gate/pubspec.yaml`
- `tool/reserved_keys_gate/dart_test.yaml`
- `tool/reserved_keys_gate/lib/reserved_keys_gate.dart`
- `tool/reserved_keys_gate/lib/src/registrars.dart`
- `tool/reserved_keys_gate/lib/src/manual_probes.dart`
- `tool/reserved_keys_gate/lib/src/assertions.dart`
- `tool/reserved_keys_gate/test/reserved_keys_test.dart`
- `scripts/ci/gate_reserved_keys.dart`
- `packages/zcrud_study_kernel/dart_test.yaml`

**Modifiés**
- `scripts/ci/gate_web_determinism.dart` (généralisé — `_kernelPath` supprimé)
- `scripts/ci/verify_serialization.dart` (SKIP bruyant + `ZCRUD_REQUIRE_SERIALIZATION_COMPAT`)
- `scripts/ci/prove_gates.dart` (3 fixtures)
- `.github/workflows/ci.yml` (setup-node + step unique `melos run verify`)
- `pubspec.yaml` (workspace, `melos.ignore`, `gate:reserved-keys`, `verify`, compteurs 14→15)
- `melos.yaml` (miroir M-1)
- `packages/zcrud_annotations/test/no_runtime_dep_test.dart` (`@TestOn('vm')`)
- `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md` (AD-19.1.c corrigé, AD-19.2 pt.8 soldé)

### Change Log

- 2026-07-13 — ES-1.4 implémentée : `gate:reserved-keys` (volets A+B+couverture), `gate:web` généralisé, `verify:serialization` bruyant + interrupteur, CI refondue en step unique `melos run verify` + Node. Prouvé par injection de régression. Statut → `review`.
