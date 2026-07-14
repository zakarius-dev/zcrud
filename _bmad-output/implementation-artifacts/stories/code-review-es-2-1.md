# Code Review — ES-2.1 : Document d'étude + état de lecture personnel (`zcrud_document`)

- **Skill** : `bmad-code-review` (**réellement invoqué** via le tool `Skill` — aucun fallback disque).
- **Story** : `_bmad-output/implementation-artifacts/stories/es-2-1-document-etat-lecture.md` (statut `review`, 14 ACs, D1..D10).
- **Diff** : working tree non committé — **NOUVEAU** package `packages/zcrud_document/` (pubspec, barrel, 5 fichiers domaine, 3 `.g.dart`, 6 fichiers de test) + **3 seuls** fichiers hors package (`pubspec.yaml` racine, `tool/reserved_keys_gate/pubspec.yaml`, `tool/reserved_keys_gate/lib/src/registrars.dart`). **AC14 tenu** (vérifié : aucune ligne de `zcrud_core`/`zcrud_study_kernel`/`zcrud_flashcard`/`zcrud_mindmap`/`zcrud_firestore` ; les `M` visibles sur ces packages sont ceux d'**ES-2.0**, en vol).
- **Vérifs vertes** : exploitées telles que rejouées par l'orchestrateur (`melos list`=16 · `analyze` RC=0 · `verify` RC=0 · `prove_gates` 37/0 · `graph_proof` ACYCLIQUE + CORE OUT=0 · 8 registrars disque = 8 câblés · `zcrud_document` **112** tests · harnais 35→**43** · zéro régression). **Non refaites.**
- **Verdict** : **CHANGES REQUESTED** — 2 findings bloquants (1 HIGH systémique, 1 MAJEUR de perte silencieuse), 3 MEDIUM, 3 LOW.

---

## Résumé exécutif

La story est, sur le fond, **la meilleure de l'epic** : elle a mesuré au lieu d'affirmer. Le dev a **refusé la lettre de l'AC10** après avoir **prouvé par injection** que la sonde `learning` de `kProbeBodies` est **inerte** (le gate reste VERT sans `kLearningKey` dans `_reservedKeys`) — c'est exactement le geste que la rétro réclame, et il a posé le filet manquant là où AC14 l'autorisait.

**Mais le motif dominant du projet se rejoue quand même — une 8ᵉ fois — à deux endroits :**

1. **H1 (systémique)** : le filet anti-H2 est un **test artisanal, par canal, dans le package**. Rien, dans aucune machine, n'obligera le **prochain** canal hors-codegen (`ZSmartNote.content`/`ZCodec` en ES-2.2, `ZDocumentAnnotation` en ES-2.5…) à naître avec son observateur. Le constat le plus important de la story — « **le gate ne couvre PAS les canaux hors-codegen** » — reste **consigné en prose**. **R1 violé** (« toute règle naît avec son gate »). Le repo compte déjà **DEUX** canaux (`source`, `learning`) et **DEUX** tests artisanaux **dans deux fichiers différents**.
2. **H2/MAJEUR (local)** : le trou de `copyWith` que le dev **dit avoir fermé** (Completion Notes §3, « l'invariant tient aux **deux** frontières ») est fermé sur **`ZDocumentViewerPrefs`** et sur **`ZDocumentReadingState`**… et **laissé OUVERT sur `ZStudyDocument`** — la 3ᵉ entité de la même story, dont la dartdoc affirme pourtant « `sizeBytes` … **jamais négative** — R-H ». Une prose de garde qu'aucune machine ne tient : le motif exact, à l'intérieur même de la story qui le combat.

---

## Findings

### 🔴 H1 — HIGH (systémique, R1) — Le filet anti-H2 est un artisanat par canal ; rien ne fera naître le prochain avec son observateur

**Fichiers** :
- `tool/reserved_keys_gate/lib/src/assertions.dart:61-281` (assertions (a)…(e))
- `tool/reserved_keys_gate/lib/src/registrars.dart:57-105` (`kProbeBodies`, sondes `source` + `learning`)
- `packages/zcrud_document/test/ad_26_registry_test.dart:168-210` (groupe *anti-H2*, seul filet qui mord)

**Le fait, mesuré (injection n°2 du dev, rejouée par l'orchestrateur)** : en retirant `kLearningKey` de `ZDocumentReadingState._reservedKeys`, **`gate:reserved-keys` RESTE VERT (RC=0)**. Seuls rougissent les tests **du package**.

**Pourquoi** : les 5 assertions du volet (A) n'observent **que** `ZSyncMeta.reservedKeys` (a/c/d) et **l'unique** `kProbeUnknownKey` (b/e). **Aucune ne regarde une clé du CORPS de sonde.** La sonde **TRANSPORTE** `learning` et `source` ; **rien ne les OBSERVE**. Le finding **H2 d'ES-2.0 n'est donc PAS soldé au niveau du harnais** : le correctif d'ES-2.0 (ajouter `source` à `kProbeBodies`) est, lui aussi, **inerte** — le seul observateur de `source` est un groupe écrit **à la main** (`reserved_keys_test.dart:507+`), et le seul observateur de `learning` est un groupe écrit **à la main** dans un **autre package**.

**Scénario d'échec REPRODUCTIBLE (le 8ᵉ rejeu, déjà armé)** :
> ES-2.2 crée `ZSmartNote.content` (canal hors-codegen via `ZCodec` — le générateur ne sait pas le traiter, exactement comme `Map`). Le dev d'ES-2.2 suit **le patron affiché** : clé dans `_reservedKeys`, décodage/réémission à la main, **corps de sonde dans `kProbeBodies`** (AC10 le prescrit, et c'est ce que la lettre du patron demande). Il n'écrit **pas** de groupe anti-H2 (rien ne le lui impose ; le gate est vert ; `prove_gates` est vert ; 1000+ tests sont verts). Un refactor ultérieur retire `'content'` de `_reservedKeys` ⇒ `content` atterrit **dans `extra`**, est **réémis en double**, l'`==` entre l'instance mémoire et la même relue du store **casse**, et le round-trip du store **n'est plus idempotent**. **Le gate reste VERT. Aucun test ne rougit.** Perte silencieuse — le motif, mot pour mot.

**Ce qui prouve qu'un filet GÉNÉRIQUE est possible — et qu'il est déjà pratiqué DANS CE HARNAIS** : le verrou DW-ES14-2 (`reserved_keys_test.dart:397-408`) boucle sur `kProbeBodies.keys.where((k) => !kNonExtensibleKinds.contains(k))` et couvre donc **automatiquement** les 2 nouveaux kinds d'ES-2.1, **sans que le dev ait eu quoi que ce soit à écrire**. La même mécanique aurait couvert `source` **et** `learning` **d'un seul coup**.

**Filet manquant — proposition concrète (2 endroits, ~15 lignes, aucun code par entité)** :

- **(f) — assertion comportementale, dans `assertExtraClean`** (passer le corps de sonde à l'assertion) :
  ```dart
  // (f) — AUCUNE clé du CORPS DE SONDE ne doit atterrir dans `extra`.
  // `extra` = clés INCONNUES du domaine. Le corps de sonde ne contient, par
  // construction, QUE des clés que le domaine CONNAÎT (champs de schéma +
  // canaux hors-codegen). Une clé du corps trouvée dans `extra` PROUVE qu'un
  // canal a été oublié dans `_reservedKeys`.
  expect(entity.extra.keys.toSet().intersection(probeBody.keys.toSet()), isEmpty);
  ```
  ⇒ **Mord sur l'injection n°2** (`learning` non réservé ⇒ intersection = `{learning}`) **et** sur toute régression de `source`. **Zéro faux positif aujourd'hui** (vérifié : `extra` après décodage de la sonde ne contient que `zz_cle_inconnue`).

- **(g) — règle de couverture, dans le volet (B)/AST du gate** : extraire de chaque `_reservedKeys` les clés qui ne proviennent **ni** de `$XxxFieldSpecs`, **ni** de `'extension'`, **ni** de `ZSyncMeta.reservedKeys` (littéraux **et** `const` comme `kLearningKey`) — c'est **la déclaration MACHINE d'un canal hors-codegen** — puis **exiger** que chacune figure dans `kProbeBodies[kind]`. **ROUGE** sinon (« canal déclaré, jamais sondé »).
  ⇒ **(g) donne des dents à (f)** : un canal ne peut plus naître sans sa sonde, et sa sonde ne peut plus rester inerte. **La discipline du dev cesse d'être le garde-fou.**

- **(h) — optionnel, générique, très fort** : idempotence d'entité sur la sonde — `registry.decode(kind, registry.encode(kind, e)) == e`. (Vérifié analytiquement : **mord** sur l'injection n°2, car `extra['learning']` porterait la map **brute** au 1ᵉʳ tour et la map **réémise** au 2ᵉ — deux instances `Map` distinctes ⇒ `_mapEquals` faux.)

**Sans (f)+(g), ES-2.1 lègue à ES-2.2/2.5/2.6 un faux vert en germe.** C'est le seul finding qui, à lui seul, justifie de ne pas passer `done` en l'état.

---

### 🔴 H2 — MAJEUR — `ZStudyDocument.copyWith` ROUVRE les invariants R-H que `fromMap` ferme (perte silencieuse à l'ÉCRITURE)

**Fichier** : `packages/zcrud_document/lib/src/domain/z_study_document.dart:201-242` (`copyWith`) — cf. dartdoc `:154` (« `sizeBytes` … **jamais négative** — R-H ») et `:143-152` (`pageCount` « `<= 0` ⇒ `null` »).

**Le fait** : `fromMap` (`:97-115`) sanitise `pageCount <= 0 ⇒ null` et `sizeBytes < 0 ⇒ 0`. **`copyWith` ne sanitise RIEN.** Ses **deux sœurs de la même story** le font pourtant :
- `ZDocumentViewerPrefs.copyWith` **sanitise** le zoom (`z_document_viewer_prefs.dart:150-159`, testé `z_document_viewer_prefs_test.dart:147`) ;
- `ZDocumentReadingState.copyWith` **sanitise** `currentPage`/`pageCount` (`z_document_reading_state.dart:190-199`, testé `z_document_reading_state_test.dart:241,263`).

**Scénario d'échec REPRODUCTIBLE** :
```dart
final d = ZStudyDocument.fromMap(<String, dynamic>{'id': 'd1'});
final m = d.copyWith(sizeBytes: -1, pageCount: 0).toMap();
// m == {'id':'d1', …, 'page_count': 0, 'size_bytes': -1}   ⇒ PERSISTÉ TEL QUEL
final relu = ZStudyDocument.fromMap(m);
// relu.sizeBytes == 0   ET   relu.pageCount == null        ⇒ VALEURS CHANGÉES
// d.copyWith(...) != relu                                   ⇒ round-trip NON idempotent
```
⇒ Le store écrit une valeur **hors du domaine de définition**, et la relecture la **modifie silencieusement**. C'est précisément le critère « **convergence : une instance mémoire == la même relue du store** » que `z_study_document_test.dart:75` prétend établir — mais ce test n'exerce **que** la voie `fromMap`, jamais la voie `copyWith`. Le groupe `copyWith` (`:262-282`) ne teste **que** la sémantique de sentinelle, **aucun invariant de valeur**.

**Aggravant** : la Completion Note §3 affirme « **Trou refermé au-delà de la lettre de l'AC** … l'invariant tient aux **deux** frontières (désérialisation **et** mutation applicative) ». C'est vrai pour 2 entités sur 3. **La dartdoc de `sizeBytes` affirme un invariant qu'aucune machine ne tient** — le motif dominant du projet, dans la story qui le combat.

**Correctif attendu** : sanitiser `pageCount`/`sizeBytes` dans `ZStudyDocument.copyWith` (patron déjà écrit 2 fois dans le même package), + 1 test par invariant (« la garde ne se rouvre pas via `copyWith` »). AC11 l'exige (« **chacun** porte un test de garde »).

---

### 🟠 M1 — MEDIUM — AC9 (R-C) n'est PAS tenu pour la 3ᵉ entité enregistrée

**Fichier** : `packages/zcrud_document/test/z_document_viewer_prefs_test.dart` — **zéro** occurrence de `ZSyncMeta` / `reservedKeys` (vérifié par grep).

AC9 : « `$XxxFieldSpecs ∩ ZSyncMeta.reservedKeys` est **VIDE** pour **chacune des 3 entités** — assertion écrite **explicitement**, entité par entité » ; la rétro (R-C) précise « **le gate ne le couvre pas directement** ». Le contrôle existe pour `ZStudyDocument` (`z_study_document_test.dart:123`) et `ZDocumentReadingState` (`z_document_reading_state_test.dart:154`) — **pas** pour `ZDocumentViewerPrefs`, pourtant **enregistrée** (kind `document_viewer_prefs`) et donc persistable top-level.

**Scénario** : ES-2.5 ajoute un champ à `ZDocumentViewerPrefs` sous une clé réservée (`updated_at` « dernière préférence modifiée » — le geste **naturel** que R-C décrit). Aucun test du package ne mord.
**Atténuation** (⇒ MEDIUM, pas MAJEUR) : l'assertion **(d)** du gate mordrait *indirectement* (le `toMap()` généré réémettrait `updated_at`, hors `kLegacyUpdatedAtMirrors` ⇒ ROUGE). Mais c'est un rattrapage **fortuit**, pas le contrôle prescrit.
**Correctif** : 6 lignes, copiées des deux sœurs.

---

### 🟠 M2 — MEDIUM — L'extension générée `ZDocumentViewerPrefsZcrud` est exportée publiquement et son `copyWith` CONTOURNE `sanitizeZoomLevel`

**Fichiers** : `packages/zcrud_document/lib/zcrud_document.dart` (`export 'src/domain/z_document_viewer_prefs.dart';` — **sans `hide`**) ; `z_document_viewer_prefs.g.dart` (extension `ZDocumentViewerPrefsZcrud`, `copyWith` généré) ; `z_document_viewer_prefs.dart:142-159`.

Le `copyWith` d'instance ne masque l'extension que sur l'appel **implicite** (`prefs.copyWith(...)`). L'appel **explicite d'extension** reste ouvert **depuis le barrel public** :
```dart
import 'package:zcrud_document/zcrud_document.dart';
final p = ZDocumentViewerPrefsZcrud(const ZDocumentViewerPrefs()).copyWith(zoomLevel: -5);
// p.zoomLevel == -5.0   ⇒ invariant « fini, > 0, clampé » CONTOURNÉ
```
La justification d'AC1 (« `ZDocumentViewerPrefs` n'est pas `ZExtensible` ⇒ son extension générée **n'a rien à perdre** ⇒ ne rien masquer ») est devenue **fausse** dès l'instant où le dev a (à raison) doté l'entité d'un **invariant de valeur** : elle a désormais quelque chose à perdre. Précédent du repo : les extensions générées des `ZExtensible` sont `hide` **précisément** parce qu'un membre généré contourne une garde d'instance.
**Correctif** : `hide ZDocumentViewerPrefsZcrud` dans le barrel (le `toMap()` généré reste appelable en interne — même bibliothèque que le `.g.dart` du reading-state et que le registrar), ou promouvoir `toMap()` en méthode d'instance si la surface publique en a besoin.
**Note R-G** : le défaut vient de **la story** (AC1), pas du dev.

---

### 🟠 M3 — MEDIUM — `ZDocumentLearningInfo.qualityByPage` expose une `Map` MUTABLE (3ᵉ porte, non gardée)

**Fichier** : `packages/zcrud_document/lib/src/domain/z_document_learning_info.dart:66-79` (`fromJson` construit une map **mutable** et la passe telle quelle), `:101` (champ public), `:123-128` (`mark` ⇒ `Map<int,int>.from`, mutable).

Incohérence directe avec le reste du package : `_extraFrom` rend `Map.unmodifiable` sur **les deux** `ZExtensible`.

**Scénario d'échec REPRODUCTIBLE** :
```dart
final i = ZDocumentLearningInfo.fromJson({'quality_by_page': {'1': 2}});
final s = <ZDocumentLearningInfo>{i};
i.qualityByPage[0] = 2;      // page 0 : invariant « 1-based » CONTOURNÉ
                             // (gardé à fromJson ET à mark… mais pas ici)
s.contains(i);               // ⇒ FALSE : le hashCode (somme) a changé,
                             //   l'instance s'est PERDUE dans son propre Set
i.toJson();                  // ⇒ {'quality_by_page': {'1':2, '0':2}} PERSISTÉ
                             //   puis SILENCIEUSEMENT REJETÉ à la relecture
```
**Correctif** : `Map.unmodifiable` dans `fromJson`, `mark` et `copyWith` (ou getter `UnmodifiableMapView`).

---

### 🟡 L1 — LOW — Valeur de qualité persistée en `String` ⇒ page **silencieusement perdue** (incohérence de tolérance)

`z_document_learning_info.dart:75` : `if (value is! num) continue;` — un `quality_by_page: {'1': '2'}` (coercion Firestore/Hive, ou **repliage legacy IFFD** où `quality` vient d'un autre schéma — ES-11.2) fait **disparaître l'entrée**, alors que **tout le reste du package coerce** les scalaires (`_$asInt` accepte `String`). Décision défendable (rejeter), mais elle doit être **explicite** — sinon c'est une perte muette au moment précis du chantier de migration.

### 🟡 L2 — LOW — `zcrud_study_kernel` : dépendance **DÉCLARÉE, aucun import**

`packages/zcrud_document/pubspec.yaml` (`dependencies:`) — assumé par **D9** (arête consommée par ES-2.5/ES-3.3). Sans objet fonctionnellement (aucun cycle ; `graph_proof` reste ACYCLIQUE / CORE OUT=0). À noter tout de même : `graph_proof` « prouve » ici une arête **déclarative** qui n'existe pas dans le code — et un consommateur tire le kernel pour rien. À re-justifier si ES-2.5/ES-3.3 glissent.

### 🟡 L3 — LOW — **DW-ES21-1** ne vit que dans les Completion Notes et un commentaire de code

`DW-ES14-1` avait été porté jusque dans `sprint-status.yaml:257` — c'est **ce qui l'a réellement fait remonter** en tête d'ES-2. `DW-ES21-1` n'apparaît (grep) **que** dans la story, `z_document_status.dart` et `z_document_status_test.dart` : **rien ne le ramènera devant ES-3.5/ES-11.2**.
> Sur le fond, **D7/AC3 est tenu, et bien tenu** : 8 tests épinglent la dégradation, `ZDocumentStatus.values.length == 4` est verrouillé, et le verrou est **SAIN** — il épingle la sémantique du **DOMAINE** (`'embedded'` ⇒ `uploading`), qui restera **correcte** quand l'adapter fera le mapping **en amont**. Il **ne cimente donc rien** (réponse explicite à l'axe 8).

---

## Ce qui a été vérifié et est CONFORME (pas de finding)

| Axe | Constat |
|---|---|
| **AD-10 (défensif)** | Les 6 cas demandés testés analytiquement sur le code **réel** : `page_count:"abc"` ⇒ `null` (`_$asInt`→`tryParse`) · `zoom_level:null` ⇒ `1.0` (`_$asDouble`→`null`→`defaultValue`, puis `sanitizeZoomLevel`) · `quality_by_page:[]` ⇒ `empty` (`raw is! Map`) · `status:"inconnu"` ⇒ `uploading` (`_$enumFromName ?? values.first`) · `learning:42` ⇒ `empty` (`fromJsonSafe`) · `prefs:"x"` ⇒ défauts (`_$decodeModel ?? fromMap(const {})`). **Aucun chemin de throw** ; 3 tests « aucune entrée ne fait THROW » + `fromMap(const {})` × 3. ✅ |
| **R-A (comportemental)** | Sonde de STORE décodée ⇒ `extra ∩ ZSyncMeta.reservedKeys == {}` **et** `toMap()` muet, **par entité** `ZExtensible` (`z_study_document_test.dart:153,170` · `z_document_reading_state_test.dart:176,192`) + volet (A) du gate. ✅ |
| **R-C** | `$ZStudyDocumentFieldSpecs` = `{id, folder_id, file_name, status, storage_path, page_count, size_bytes, created_at}` · `$ZDocumentReadingStateFieldSpecs` = `{doc_id, current_page, page_count, prefs}` ⇒ **∩ `{updated_at, is_deleted}` = ∅**. `createdAt` bien sous `created_at` (clé **distincte**, jamais réservée). ✅ *(la 3ᵉ entité manque — cf. M1)* |
| **AC8 / patron ES-2.0** | Les 3 registrars câblent `fromMap: ZXxx.fromMap` (**domaine**) ; le garde runtime `_$zRequireExtraPreserved` est émis pour **les 2 `ZExtensible` seulement** ; `toMap()` d'instance = `{...extra, ...généré, learning}` ⇒ **une clé de schéma ne peut pas être écrasée par `extra`** (ordre correct). Injection n°3 (retrait de `...extra`) ⇒ `StateError` à l'enregistrement : le garde **mord** sur les entités neuves. ✅ |
| **Anti-H2 (local)** | Le test du package observe le **POUVOIR**, pas l'existence : `encoded['learning'] == payload` **ET** `extra.containsKey('learning') == false`. Il **rougit** réellement (injection n°2). Non vacu. ✅ *(mais il est artisanal — cf. H1)* |
| **D3 / `manual_probes.dart`** | `ZDocumentLearningInfo` n'est **ni `ZExtensible` ni enregistrée** ⇒ hors `E_disk`/`R_disk` ⇒ **aucun câblage requis** ; `manual_probes.dart` **non touché** (vérifié : `git status` vide dessus). Le dev a raison. ✅ |
| **AD-26** | Prouvé **par machine** : `$ZStudyDocumentFieldSpecs ∩ clés de lecture == ∅`, **aucun** champ `subItems` dans le document, et la map réellement persistée d'une instance **pleine** ne porte aucune clé personnelle. ✅ |
| **AD-1 / AD-5 / NFR-S3** | pubspec : `zcrud_core` + `zcrud_study_kernel` + `zcrud_annotations` **seulement** — zéro Flutter, zéro `cloud_firestore`, zéro Syncfusion, zéro gestionnaire d'état. Tests sous `dart test`. ✅ |
| **AD-19 / D2** | **Zéro** `updatedAt`/`isDeleted` dans les 3 entités ; `kLegacyUpdatedAtMirrors` **inchangé** (`{study_folder, flashcard}`, verrou vert). ✅ |
| **D9 (parallélisation)** | **Aucun** symbole public du kernel/core modifié ; barrel kernel intact ; `hide` de `zcrud_flashcard` intact ⇒ **ES-2.2/ES-2.6 restent parallélisables**. ✅ |
| **DW-ES14-2 (`extension`)** | La destruction connue de `extension` sur la voie registre est **automatiquement verrouillée** pour les 2 nouveaux kinds (boucle générique `kProbeBodies.keys` du harnais, `reserved_keys_test.dart:397-408`) — **rien à faire**. *(Et c'est la preuve vivante qu'un invariant générique piloté par les sondes fonctionne — cf. le correctif proposé en H1.)* ✅ |

---

## Triage — actions attendues avant `done`

| # | Sévérité | Action | Portée |
|---|---|---|---|
| **H1** | **HIGH** | Ajouter **(f)** (`extra ∩ corps-de-sonde == ∅`, dans `assertExtraClean`) **et (g)** (volet AST : tout canal déclaré dans `_reservedKeys` hors schéma/`extension`/`ZSyncMeta` **doit** figurer dans `kProbeBodies[kind]`). **Injection de régression obligatoire** (retirer `kLearningKey` ⇒ le **gate** doit passer **ROUGE**, pas seulement les tests du package). | `tool/reserved_keys_gate/` + `scripts/ci/gate_reserved_keys.dart` — **hors** des packages en vol (ES-2.2/ES-2.6 non impactés) |
| **H2** | **MAJEUR** | Sanitiser `pageCount`/`sizeBytes` dans `ZStudyDocument.copyWith` + 1 test de garde par invariant. | `packages/zcrud_document/` |
| **M1** | MEDIUM | Ajouter le contrôle R-C sur `$ZDocumentViewerPrefsFieldSpecs` (AC9 : « **chacune** des 3 »). | `packages/zcrud_document/test/` |
| **M2** | MEDIUM | `hide ZDocumentViewerPrefsZcrud` dans le barrel (AC1 à corriger — défaut **de la story**, R-G). | `packages/zcrud_document/` |
| **M3** | MEDIUM | `Map.unmodifiable` sur `qualityByPage` (`fromJson`/`mark`/`copyWith`). | `packages/zcrud_document/` |
| **L1** | LOW | Trancher explicitement la coercion `String` des qualités (rejet **ou** `_$asInt`-like) — impacte ES-11.2. | doc/code |
| **L2** | LOW | Rien à faire ; re-justifier si ES-2.5/ES-3.3 glissent. | — |
| **L3** | LOW | Porter **DW-ES21-1** dans `sprint-status.yaml` (comme DW-ES14-1) — **écriture réservée à l'orchestrateur**. | sprint-status |

> **H1 est le finding de l'epic.** Les 3 MEDIUM sont locaux et corrigeables sans régression. **H2 est bloquant** au sens des règles projet (perte silencieuse, correction obligatoire avant `done`).

---
---

# 🔧 STATUT DE REMÉDIATION (2026-07-13) — agent `bmad-dev-story` (remédiation)

**0 finding reporté.** **H1, H2, M1, M2, M3 CORRIGÉS** · **L1 TRANCHÉ ET CORRIGÉ** · **L2 justifié (sans objet)** · **L3 signalé à l'orchestrateur (non écrit — `sprint-status.yaml` lui est réservé)**.
**+ 1 finding NOUVEAU, découvert PAR LA MACHINE ajoutée en H1 : `H3` (HIGH, hors périmètre de la story) — corrigé.**

Chaque filet ajouté ou modifié est prouvé par **injection de régression réellement exécutée** (**R3** : casser → **ROUGE observé** → restaurer à l'octet près → **VERT observé**), et chaque règle naît avec sa **fixture d'échec isolée** (**R2**).

| # | Sévérité | Statut | Preuve |
|---|---|---|---|
| **H1** | HIGH | ✅ **CORRIGÉ** — 3 règles génériques **(f)** + **(g1)/(g2)** + **(h)** | Le gate **ROUGIT MAINTENANT** sur l'injection `kLearningKey` (il restait **VERT**) |
| **H2** | MAJEUR | ✅ **CORRIGÉ** — `ZStudyDocument.copyWith` sanitise, gardes **nommées et partagées** | 4 tests qui **mordent** (injection rejouée) |
| **H3** | **HIGH (NOUVEAU)** | ✅ **CORRIGÉ** — `hide ZFlashcardZcrud` | **Trouvé par la règle (h)**, sur l'arbre réel, sous 1000+ tests verts |
| **M1** | MEDIUM | ✅ **CORRIGÉ** — R-C sur la 3ᵉ entité | 3 tests |
| **M2** | MEDIUM | ✅ **CORRIGÉ** — `hide` + `toMap()` promu en instance | 3 tests + règle **(h)** qui la tient |
| **M3** | MEDIUM | ✅ **CORRIGÉ** — `qualityByPage` **non modifiable** + filtrée à **toutes** les frontières | 4 tests |
| **L1** | LOW | ✅ **TRANCHÉ : on COERCE** (on ne rejette plus) | 3 tests |
| **L2** | LOW | 🔵 **JUSTIFIÉ — rien à faire** | cf. § L2 |
| **L3** | LOW | ⚠️ **SIGNALÉ À L'ORCHESTRATEUR** (je n'écris pas `sprint-status.yaml`) | cf. § L3 |

---

## 🔴 H1 — ✅ CORRIGÉ · le corps de sonde est ENFIN OBSERVÉ (et la discipline du dev cesse d'être le garde-fou)

**Le diagnostic de la revue est intégralement confirmé sur le code réel.** Les 5 assertions du volet (A) ne regardaient **que** `ZSyncMeta.reservedKeys` ((a)/(c)/(d)) et **l'unique** `zz_cle_inconnue` ((b)/(e)). La sonde **TRANSPORTAIT** `source` et `learning` ; **rien ne les OBSERVAIT**. Le correctif H2 d'ES-2.0 était donc bien **INERTE**.

### Le filet proposé par la revue — **implémenté tel quel, et il tient**

- **(f) — `assertExtraClean`, comportementale** (`tool/reserved_keys_gate/lib/src/assertions.dart`) :
  `entity.extra.keys ∩ kProbeBodies[kind].keys == ∅`. **Générique — zéro code par entité.**
  Le paramètre `probeBody` est **REQUIS** (jamais optionnel) : un optionnel se serait oublié en silence et (f) serait redevenue vacuelle — la faute exacte que ce gate combat.
  **Zéro faux positif** sur les 8 kinds réels + les 2 sondes manuelles (vérifié : 46/46 verts).

- **(g) — volet AST du gate** (`scripts/ci/gate_reserved_keys.dart`), **définition MACHINE d'un canal** :
  un champ d'instance d'une classe `@ZcrudModel` **`ZExtensible`** qui n'est **NI** `@ZcrudField`/`@ZcrudId`, **NI** `extra`/`extension` **EST**, par construction, un **canal hors-codegen**. Le gate en dérive la clé persistée (**snake_case du nom de champ**) et exige :
  - **(g1)** elle figure dans les clés **réservées** déclarées par la classe (littéral de `Set` statique : chaînes **et** `const` top-level résolus — donc `kLearningKey`) ;
  - **(g2)** elle figure dans **`kProbeBodies[kind]`**.
  Le gate détecte **exactement 2 canaux** sur l'arbre réel : `ZFlashcard.source` et `ZDocumentReadingState.learning`. **Zéro faux positif.**

- **(g2) donne bien ses DENTS à (f)** — c'est vérifié, pas supposé : **vider la sonde** (la seule façon de neutraliser (f)) est **ROUGE**.

- **(h)** — cf. **H3** ci-dessous : la revue demandait de « vérifier qu'aucune extension générée ne reste exportée ». **Je l'ai fait par machine**, et la machine a trouvé un HIGH.

### Injections R3 — **SORTIES RÉELLES**

**🔴 L'INJECTION DÉCISIVE — `kLearningKey` retiré de `ZDocumentReadingState._reservedKeys`.**
*Avant cette remédiation : `[gate:reserved-keys] OK … GATE RC=0` — **LE GATE RESTAIT VERT**.*

```
### INJECTION (f)/(g1) : kLearningKey RETIRÉ de _reservedKeys ###
[gate:reserved-keys] ÉCHEC : (g1) CANAL HORS-CODEGEN NON RÉSERVÉ :
  `ZDocumentReadingState.learning` (packages/zcrud_document/lib/src/domain/z_document_reading_state.dart)
  n'est ni `@ZcrudField`/`@ZcrudId`, ni `extra`/`extension` — c'est donc un canal décodé/réémis À LA MAIN.
  Sa clé persistée `learning` DOIT figurer dans les clés RÉSERVÉES de la classe (`_reservedKeys`), sinon
  elle atterrit dans `extra`, est RÉÉMISE EN DOUBLE par `toMap()`, et l'`==` entre une instance mémoire et
  la même relue du store CASSE.

00:00 +13 -1: document_reading_state : sonde polluée → decode/encode REGISTRE propres (a→e) [E]
  Expected: empty
    Actual: Set:['learning']
  [document_reading_state] (f) CANAL HORS-CODEGEN OUBLIÉ : la/les clé(s) {learning} du CORPS DE SONDE
  ont été capturées dans `extra`.

RC GATE (injection kLearningKey) = 1        ✅ ROUGE — par (g1) [AST] ET par (f) [comportemental]
```
```
RESTAURATION À L'OCTET PRÈS ✅   (git status --short → vide sur le fichier)
[gate:reserved-keys] OK — clés de sync réservées : volet (A) + volet (B) + couverture (AD-19.1.c).
```
> **C'est le critère de succès de H1, atteint.** Le gate rougit désormais **deux fois** là où il restait vert.

**Injection (g2)-A — VIDER la sonde `learning` (= tenter de désactiver (f)) :**
```
[gate:reserved-keys] ÉCHEC : (g2) CANAL DÉCLARÉ, JAMAIS SONDÉ : `ZDocumentReadingState.learning` …
  mais `kProbeBodies['document_reading_state']` NE LA PORTE PAS.
RC = 1                                      ✅ (f) N'EST PAS DÉSACTIVABLE
```

**Injection (g2)-B — retirer la sonde `source` (le correctif H2 d'ES-2.0, désormais OBSERVÉ) :**
```
[gate:reserved-keys] ÉCHEC : (g2) CANAL DÉCLARÉ, JAMAIS SONDÉ : `ZFlashcard.source`
  (packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart) … `kProbeBodies['flashcard']` NE LA PORTE PAS.
RC = 1                                      ✅ le correctif d'ES-2.0 N'EST PLUS INERTE
```

### R2 — fixtures d'échec **ISOLÉES**, prouvées par injection croisée

`prove_gates.dart` : **37 → 41 OK / 0 FAIL** (`canal-hors-codegen-1-non-reserve`, `canal-hors-codegen-2-non-sonde`, `hide-extension-generee-exportee`, + **contre-épreuve** `hide-extension-generee-masquee`).

| Règle neutralisée dans le gate | Fixtures qui rougissent |
|---|---|
| **(g1)** | `canal-hors-codegen-1-non-reserve` **SEULE** → `38 OK, 1 FAIL` |
| **(g2)** | `canal-hors-codegen-2-non-sonde` **SEULE** → `38 OK, 1 FAIL` |
| **(h)** | `hide-extension-generee-exportee` **SEULE** → `40 OK, 1 FAIL` |

> **Isolation par règle réellement observée** (R2), pas affirmée.

Contre-exemple **permanent et isolé** de **(f)** dans le harnais : **`_ChannelLeakingEntity`** — **VERTE sur (a)(b)(c)(d)(e)** (elle dépouille les clés de sync, préserve la clé inconnue, étale `...extra`), **SEULE (f)** peut la faire rougir : elle déclare un canal hors-codegen porté par sa sonde et **oublie de le réserver**. Harnais : **43 → 46** tests.

### Re-statut des tests anti-H2 **artisanaux** (`zcrud_document`) — **CONSERVÉS, et je le dis**

Ils ne sont **pas** redondants avec (f) : ils observent **strictement plus** — (1) la **reconstruction typée** du canal (`qualityByPage` en `Map<int,int>`, `masteredCount`), (2) la **réémission à l'identique** du payload, (3) le **chemin corrompu** (`learning: 'pas une map'` ⇒ `empty`, jamais de throw). Et ils tournent **là où le gate ne tourne pas** : le harnais est dans `melos.ignore` ⇒ **`melos run test` ne l'exécute pas** (seul `melos run verify` le fait). **Défense en profondeur assumée — mais ils ne sont plus le SEUL filet**, et leur préambule (qui justifiait leur existence par « aucune assertion du gate ne regarde `learning` ») est **re-statué** en conséquence.

---

## 🔴 H3 — **NOUVEAU (HIGH)** — ✅ CORRIGÉ · `ZFlashcardZcrud` était **EXPORTÉE PUBLIQUEMENT** — la 9ᵉ occurrence, trouvée **par la machine ajoutée en H1**

> ⚠️ **HORS DU PÉRIMÈTRE assigné** (`packages/zcrud_flashcard/lib/zcrud_flashcard.dart`, **1 ligne**). Je le déclare explicitement. **Justification** : c'est une **perte de données silencieuse prouvée**, sur l'entité **phare**, via l'**API publique** ; CLAUDE.md rend la correction d'un HIGH **obligatoire** ; et **le gate que H1 m'imposait d'écrire passait ROUGE tant qu'elle n'était pas faite** — je ne pouvais ni livrer un gate rouge, ni l'allowlister (ce serait exactement « passer le gate en s'y ajoutant », que la rétro condamne). Le fichier est **disjoint** d'ES-2.2/ES-2.6 (nouveaux packages) : la parallélisation n'est pas menacée. **`zcrud_flashcard` : 189 = 189 tests, aucune régression.**

**Le fait, mesuré.** `ZFlashcard` est `ZExtensible` **et** porte le canal `source`. Son extension générée était exportée **sans `hide`** (`zcrud_flashcard.dart:70`), alors que ses **3 sœurs** `ZExtensible` du repo étaient, elles, bien masquées. Le `copyWith` **généré** mentionne `source`/`extra`/`extension` **zéro fois** (vérifié sur le `.g.dart`) ⇒ il les **remet aux défauts** :

```dart
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
ZFlashcardZcrud(card).copyWith(question: 'x');
// ⇒ extra, extension ET source : DÉTRUITS, en silence.
```
Le `copyWith` d'**instance** ne masque que l'appel **implicite** ; l'appel **explicite d'extension** restait **ouvert depuis l'API publique** — **exactement M2, mais sur une entité `ZExtensible`**, donc **pire**.

**Pourquoi personne ne l'a vu** : la politique `hide` vivait **en commentaire de barrel**. **Aucune machine ne la tenait.** *Une règle sans son gate* — **la faute même de H1**, à un autre étage. C'est la **9ᵉ occurrence du motif dominant**.

**Correctif** : `export 'src/domain/z_flashcard.dart' hide ZFlashcardZcrud;` **+ la règle (h)** qui la tient désormais **par machine**, avec sa fixture d'échec isolée **et sa contre-épreuve**.

```
### Sur l'ARBRE RÉEL, avant correctif ###
[gate:reserved-keys] ÉCHEC : (h) EXTENSION GÉNÉRÉE EXPORTÉE : `ZFlashcardZcrud` est exposée par le point
  d'entrée public `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (`export 'src/domain/z_flashcard.dart';`
  sans `hide`), alors que `ZFlashcard` est `ZExtensible`.
RC = 1
```

---

## 🔴 H2 — ✅ CORRIGÉ · l'invariant tient enfin aux **DEUX** frontières

`ZStudyDocument.copyWith` passait `sizeBytes` et `pageCount` **BRUTS**. Le scénario de la revue est **reproduit tel quel**, puis **fermé**.

**Correctif** : les gardes sont **extraites, NOMMÉES et PUBLIQUES** — `ZStudyDocument.sanitizePageCount` / `sanitizeSizeBytes` — et **consommées par `fromMap` ET `copyWith`**. Deux implémentations jumelles auraient fini par **diverger** : il n'y en a plus qu'une (anti-dérive, testé).

**4 tests qui MORDENT** (`z_study_document_test.dart` › groupe *H2*), dont la **convergence par la voie `copyWith`** — que le test d'origine (l. 75) n'exerçait **que** par `fromMap` :
```
### INJECTION H2 : copyWith RE-DÉSANITISÉ (état d'origine) ###
00:00 +20 -1: H2 … MORD : `sizeBytes: -1` ⇒ 0 (jamais négative — la dartdoc le PROMET) [E]
00:00 +20 -2: H2 … MORD : `pageCount: 0` / négatif ⇒ null (« inconnu », pas « zéro page ») [E]
00:00 +20 -3: H2 … CONVERGENCE par la voie `copyWith` : ce qui est PERSISTÉ est RELISIBLE [E]
RESTAURATION À L'OCTET PRÈS ✅   →   +129: All tests passed!
```

### « Cherche le MÊME trou partout » — balayage des **3 voies d'écriture**, sur les 3 entités

| Voie | `ZStudyDocument` | `ZDocumentReadingState` | `ZDocumentViewerPrefs` | `ZDocumentLearningInfo` |
|---|---|---|---|---|
| `fromMap`/`fromJson` | ✅ | ✅ | ✅ | ✅ |
| `copyWith` d'**instance** | ⛔ **H2 — corrigé** | ✅ (déjà) | ✅ (déjà) | ⛔ **corrigé** (filtrait pas les pages `< 1`) |
| `copyWith` **GÉNÉRÉ** (extension) | ✅ `hide` (barrel) | ✅ `hide` (barrel) | ⛔ **M2 — corrigé** (`hide`) | — (pas de codegen) |
| Constructeur `const` | 🔵 **voir ci-dessous** | 🔵 | 🔵 | 🔵 |

> 🔵 **REFUTATION DE LA DIRECTION DONNÉE — le constructeur `const` NE DOIT PAS être gardé, et un `assert` y serait un CONTRESENS.**
> La consigne demandait de fermer « toute garde contournable par une voie d'écriture (…**constructeur**) ». **Je refuse cette partie, et voici pourquoi (vérifié sur le code généré)** : le décodeur **généré** (`_$ZStudyDocumentFromMap`) **appelle le constructeur avec les valeurs BRUTES**, *avant* la sanitisation de `fromMap`. Un `assert` (ou un throw) dans le constructeur ferait donc **ÉCHOUER LA DÉSÉRIALISATION D'UNE DONNÉE CORROMPUE** — **violation frontale d'AD-10** (« un champ absent/corrompu ne fait **jamais** échouer le parent »), et une **régression** par rapport à l'existant. Le constructeur `const` est un **primitif de bas niveau** ; les **frontières réelles** sont la **désérialisation** (seule voie par laquelle une donnée corrompue entre) et la **mutation applicative** (`copyWith`/`mark`). **Les deux sont désormais fermées, aux 4 entités.** C'est explicitement documenté en dartdoc (plutôt que laissé implicite).

---

## 🟠 M1 — ✅ CORRIGÉ · AC9/R-C sur la **3ᵉ** entité

`z_document_viewer_prefs_test.dart` gagne le groupe **« AD-19 / R-C : clés de sync hors-entité (AC9) »** (3 tests, calqués sur ses deux sœurs) : `$ZDocumentViewerPrefsFieldSpecs` est **épinglé** (`{zoom_level, scroll_direction, page_layout}`), son intersection avec `ZSyncMeta.reservedKeys` est **VIDE**, `$ZDocumentViewerPrefsTimestampFields ∩ reservedKeys == ∅` (AD-19.1.b), et `toMap()` ne réémet **ni** `updated_at` **ni** `is_deleted`. **AC9 est désormais tenu pour les 3 entités, pas 2.**

---

## 🟠 M2 — ✅ CORRIGÉ · et le trou était **RÉEL** (le test lui-même le prouve)

`hide ZDocumentViewerPrefsZcrud` dans le barrel + **`toMap()` promu en méthode d'instance** (la surface publique de (dé)sérialisation est **préservée**, alignée sur ses deux sœurs ; seule la porte du `copyWith` est fermée).

> **Preuve que le trou était public** : `z_document_viewer_prefs_test.dart` — qui n'importe **que le barrel** — **a cessé de compiler** dès le `hide` posé (il appelait `ZDocumentViewerPrefsZcrud(p).toMap()`). Le test **atteignait** l'extension **par l'API publique** : c'était bien un trou, pas une hypothèse.

Le groupe **M2** conserve un test de **non-régression de la MOTIVATION** : par import direct (interne), `ZDocumentViewerPrefsZcrud(p).copyWith(zoomLevel: -5.0).zoomLevel == -5.0` — **le `copyWith` généré ne sanitise toujours rien**, ce qui est précisément pourquoi son extension **doit** rester `hide`.
**Politique du barrel désormais UNIFORME : aucune extension générée n'est exportée** — et c'est **tenu par la règle (h)** (⇒ **H3**).

*(Note R-G confirmée : le défaut venait de la **story** (AC1), pas du dev.)*

---

## 🟠 M3 — ✅ CORRIGÉ · `qualityByPage` **non modifiable**, à **toutes** les frontières

`_guard(...)` (filtre **pages `< 1`** + `Map.unmodifiable`) est appliqué dans **`fromJson`, `mark` ET `copyWith`**.
⚠️ **Au-delà de la lettre du finding** : la revue ne demandait que l'immutabilité. Mais `copyWith(qualityByPage: {0: 2})` **rouvrait aussi l'invariant 1-based** que `fromJson`/`mark` ferment (page `0` **persistée**, puis **silencieusement rejetée** à la relecture ⇒ round-trip **non idempotent**) — c'est le **même trou que H2**, sur la 4ᵉ entité. Fermé.

**4 tests** (dont le scénario exact de la revue : l'instance **ne se perd plus dans son propre `Set`**).
```
### INJECTION M3 : _guard retiré de fromJson (map REDEVENUE MUTABLE) ###
00:00 +25 -1: M3 … MORD : muter la map de `fromJson` ⇒ UnsupportedError [E]
00:00 +26 -2: M3 … l'instance ne se PERD PLUS dans son propre `Set` (hashCode stable) [E]
RESTAURATION À L'OCTET PRÈS ✅
```

---

## 🟡 L1 — ✅ TRANCHÉ **ET CORRIGÉ** : on **COERCE** (on ne rejette plus)

**Décision** : `_asQuality` accepte `num` **et** `String` numérique — **même tolérance que le codegen** (`_$asInt`). Rejeter était une **perte muette** (**R6 : aucune dégradation silencieuse**), et une **incohérence de tolérance** avec tout le reste du package — **au moment précis du chantier de migration IFFD** (ES-11.2 : le `quality` d'IFFD vient d'un **autre schéma**). La coercion reste **BORNÉE** : `'x'`, une map, `null`, `bool` sont **toujours rejetés** (testé).
```
### INJECTION L1 : coercion String retirée (rejet silencieux d'origine) ###
00:00 +29 -1: L1 … MORD : `{"1": "2"}` ⇒ page 1 CONSERVÉE (et non plus PERDUE) [E]
RESTAURATION À L'OCTET PRÈS ✅
```

## 🟡 L2 — 🔵 JUSTIFIÉ, rien à faire

L'arête `zcrud_document → zcrud_study_kernel` est **déclarative** (AD-17), assumée par **D9** de la story, consommée par **ES-2.5** (`colorKey`/`ZColorPalette`) et **ES-3.3** (registre de cascade, AD-21). Aucun cycle (`graph_proof` : **ACYCLIQUE / CORE OUT=0**, 16 nœuds). **À re-justifier si ES-2.5/ES-3.3 glissent** — inchangé.

## 🟡 L3 — ⚠️ **SIGNALÉ À L'ORCHESTRATEUR (non corrigé — délibérément)**

**`DW-ES21-1` n'est PAS dans `sprint-status.yaml`.** Je **n'ai pas** écrit ce fichier (**écriture réservée à l'orchestrateur**, consigne explicite). **Action attendue de l'orchestrateur** : porter `DW-ES21-1` dans `sprint-status.yaml`, comme `DW-ES14-1` l'avait été (`sprint-status.yaml:257` — c'est **ce qui l'a réellement fait remonter** en tête d'ES-2). Sans cela, **rien ne ramènera la dette devant ES-3.5/ES-11.2** :
> **DW-ES21-1** — *mapping legacy IFFD **6 états → 4 canoniques**, dû dans l'adapter `zcrud_firestore` (ES-3.5/ES-11.2, AD-27). Jusque-là, un document IFFD `uploaded`/`converting`/`converted`/`embedding`/`embedded` **se lit `uploading`** — affiché « Traitement… » **pour toujours**, y compris quand il est réellement PRÊT. Mapping cible : `uploading→uploading` · `converting|embedding→validating` · `uploaded|converted|embedded→ready`.*

**Nouvelle dette à porter également** — issue de (g) : **la clé persistée d'un canal hors-codegen DOIT être le snake_case de son nom de champ** (contrainte **normative** nouvelle, sans quoi le gate ne peut pas la dériver par machine). Consignée dans `architecture.md` (§ AD-19.1.c) ; aucun canal existant ne la viole.

---

## Vérif verte finale — **rejouée intégralement** (RC réels, `verify` en AVANT-PLAN)

| Commande | Résultat |
|---|---|
| `dart run melos run generate` | **SUCCESS** |
| `dart run melos run analyze` (repo-wide) | **RC=0** |
| `dart run melos run verify` (repo-wide, avant-plan) | **RC=0** |
| `dart run melos run test` (repo-wide) | **RC=0** |
| `dart run scripts/ci/prove_gates.dart` | **41 OK / 0 FAIL** (baseline **37** → **+4** : (g1), (g2), (h), contre-épreuve (h)) |
| `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK · CORE OUT=0 OK** (**16** nœuds) |
| `dart run melos list` | **16** |
| `gate:reserved-keys` | **OK** — volet (A) + volet (B) + couverture ; **8 registrars / 8 câblés**, **2 canaux hors-codegen** (règle (g)) |

**Compteurs de tests (avant remédiation → après)**

| Suite | Avant | Après |
|---|---|---|
| `zcrud_document` | 112 | **129** (+17) |
| `reserved_keys_gate` (harnais) | 43 | **46** (+3) |
| `zcrud_generator` | 102 | **102** |
| `zcrud_flashcard` | 189 | **189** *(aucune régression malgré le `hide` — H3)* |
| `zcrud_study_kernel` | 108 | **108** |
| `zcrud_core` | 911 | **911** |
| `zcrud_firestore` | 90 | **90** |
| `zcrud_mindmap` | 110 | **110** |

**Périmètre** : `packages/zcrud_document/`, `tool/reserved_keys_gate/`, `scripts/ci/`, `architecture.md` — **+ `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (1 ligne, H3, DÉCLARÉ ci-dessus)**. **AUCUNE** écriture dans `zcrud_core`, `zcrud_study_kernel` ni `zcrud_generator`. **AUCUNE** écriture du `sprint-status.yaml`. **AUCUN** commit. `lex_douane`/`iffd` : **lecture seule** (non touchés). Aucune trace d'injection résiduelle (`grep` → néant).

## Points où j'ai REFUTÉ la direction donnée

1. **Le constructeur `const` ne doit PAS être gardé** (cf. § H2) : la consigne demandait de fermer *toutes* les voies d'écriture, **constructeur compris**. **C'est faux ici** — le décodeur **généré** appelle le constructeur avec les valeurs **brutes** ⇒ un `assert`/throw y ferait **échouer la désérialisation d'une donnée corrompue**, en **violation d'AD-10**. Documenté au lieu d'être « corrigé ».
2. **La consigne « re-statue les tests anti-H2 artisanaux » supposait un choix binaire garder/retirer.** Ils sont **gardés**, mais pour une raison que la consigne n'anticipait pas : le harnais est dans **`melos.ignore`** ⇒ **`melos run test` ne l'exécute pas**. (f)/(g) sont le signal du **gate** ; ces tests sont le signal de la **suite de tests**. Ce n'est pas de la redondance, c'est une **couverture d'exécution différente**.
3. **Ma première fixture (h) n'était pas isolée — et c'est le protocole R2 qui l'a attrapée.** Mon marqueur d'isolation (« est \`ZExtensible\` ») était une **sous-chaîne du message de (h) lui-même** : la fixture se déclarait non isolée à tort. Corrigé (marqueur propre à la règle (3)). *Consigné plutôt que masqué — même leçon que l'injection trop faible de M4 en ES-2.0.*
4. **La revue voyait M2 comme un MEDIUM local.** En le tenant **par machine** (règle (h)), il a révélé un **HIGH** (**H3**) sur l'entité **phare**, dans un **autre package**. Le finding « local » était en réalité le **symptôme visible** d'une règle sans gate.
