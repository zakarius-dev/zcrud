# Story ES-2.0 : [TÊTE BLOQUANTE ES-2] `registry.decode` préserve `extra` (DW-ES14-1) — la voie registre cesse de détruire les clés métier inconnues

Status: review

- **Clé sprint-status** : `es-2-0-registry-decode-preserve-extra`
- **Epic** : ES-2 (tête bloquante — s'exécute AVANT/EN PARALLÈLE des stories kernel d'ES-2)
- **Taille** : **M/L** (2 packages + 1 harnais + 2 scripts CI ; aucune nouvelle entité)
- **Parallélisation** : ✅ **Parallélisable avec ES-2.1 / ES-2.2 / ES-2.6**.
  **Packages écrits (disjoints du kernel)** : `packages/zcrud_generator/`, `packages/zcrud_firestore/`, `tool/reserved_keys_gate/`, `scripts/ci/`.
  ⛔ **N'ÉCRIT NI `zcrud_core` NI `zcrud_study_kernel`** — c'est la condition de la parallélisation (garde-fou n°2 de CLAUDE.md : `zcrud_core` est le seul point de contact possible ; cette story n'y touche pas, donc une story kernel peut tourner simultanément).
- **Origine** : dette **DW-ES14-1**, déclarée 🔴 **BLOQUANTE** par la rétrospective ES-1 (§5) — *« Câbler le store en ES-3 sur un `registry.decode` destructeur transformerait une dette latente en perte de données irréversible. »*
- **Absorbe aussi** : finding **L3 d'ES-1.3** (`*.g.dart` et membre déprécié) — **même package**.

---

## Story

**As a** mainteneur de `zcrud` préparant le câblage du store d'étude (ES-3.2/ES-3.5),
**I want** que `ZcrudRegistry.decode(kind, map)` reconstruise une entité dont le slot `extra` (AD-4) est **peuplé** — au lieu de le laisser vide —,
**so that** la fabrique publique `FirebaseZRepositoryImpl.fromRegistry` cesse de **détruire silencieusement et irréversiblement** toute clé métier inconnue du schéma à chaque cycle lecture → écriture, et que le gate `reserved-keys` puisse enfin décoder par le registre (supprimant la déviation `kDomainDecoders`).

---

## Contexte — le défaut, **vérifié sur disque** (pas sur la foi de la rétro)

### Ce que le générateur émet RÉELLEMENT aujourd'hui

`packages/zcrud_generator/lib/src/zcrud_model_generator.dart`, `_emitRegister` (**l. 437-447**) :

```dart
'void register$className(ZcrudRegistry registry) =>\n'
'    registry.register<$className>(\n'
"      '$kind',\n"
'      fromMap: _\$${className}FromMap,\n'   // ⛔ factory CODEGEN — ignore `extra`
'      toMap: (value) => value.toMap(),\n'   // ✅ toMap d'INSTANCE — spread `...extra`
'      fieldSpecs: \$${className}FieldSpecs,\n'
'    );'
```

Sortie constatée — `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.g.dart:200` :
`fromMap: _$ZStudyFolderFromMap,`

### Pourquoi c'est destructeur

`_$ZXxxFromMap` ne connaît **que** les champs annotés `@ZcrudField` : il ne peuple **ni `extra`, ni `extension`, ni `source`** (canaux **hors-codegen**, câblés à la main par la factory de **domaine** `ZXxx.fromMap`). Donc :

| Voie | `extra` après décodage |
|---|---|
| `ZXxx.fromMap(map)` (**domaine**) | ✅ peuplé (`_extraFrom(map)`) |
| `registry.decode(kind, map)` (**registre**) | ⛔ **`{}` — clés inconnues PERDUES** |

`toMap()` (voie d'écriture) fait `{...extra, ...ZXxxZcrud(this).toMap()}` ⇒ ce qui a été perdu au décodage n'est **jamais réémis**. Un cycle `read → write` via le registre **efface** définitivement toute clé hors-schéma.

`FirebaseZRepositoryImpl.fromRegistry` (`packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:193`) fait exactement ça :
```dart
fromMap: (map) => registry.decode(kind, map) as T,
```
**Latent** (zéro appelant ; avertissement dartdoc `DW-ES14-1` posé en ES-1.3, l. 130-179), **destructif dès la première adoption**.

### Le contournement à supprimer

`tool/reserved_keys_gate/lib/src/registrars.dart` maintient **à la main** `kDomainDecoders` (`kind → ZXxx.fromMap`) — une **déviation documentée** de la lettre d'AD-19.1.c, qui n'existe **que** parce que `registry.decode` est cassé (sans elle, l'assertion (a) du gate serait **vacuellement verte** et (b) **structurellement rouge**).

---

## ⚠️ Décisions de conception — CHAQUE prescription a été CONFRONTÉE AU CODE (R4 / R-G)

> **Leçon R-G de la rétro** : *« en ES-1.2 et ES-1.4, le défaut était DANS LA SPEC »*. Les décisions ci-dessous sont **fermées** : le dev ne les rejoue pas, mais il **doit** les remettre en cause si le code réel les contredit (et le dire).

### D1 — Le registrar émet `fromMap: ZXxx.fromMap` (factory de DOMAINE) — ✅ **PROUVÉ ASSIGNABLE**

**Le doute** : `ZcrudRegistry.register<T>` exige `required T Function(Map<String, dynamic> map) fromMap` (`zcrud_registry.dart:77`), or les factories de domaine ont des **paramètres nommés optionnels** :

| Entité | Signature RÉELLE de `fromMap` |
|---|---|
| `ZChoice` | `(Map<String, dynamic> map)` |
| `ZRepetitionInfo` | `(Map<String, dynamic> map, {ZRepetitionInfoExtensionParser? extensionParser})` |
| `ZStudyFolder` | `(Map<String, dynamic> map, {ZFolderExtensionParser? extensionParser})` |
| `ZStudySessionConfig` | `(Map<String, dynamic> map, {ZSessionConfigExtensionParser? extensionParser})` |
| `ZFlashcard` | `(Map<String, dynamic> map, {ZSourceRegistry? sourceRegistry, ZFlashcardExtensionParser? extensionParser})` |

**Verdict : le tear-off EST assignable** (Dart : un type de fonction avec des paramètres **optionnels supplémentaires** est un sous-type de celui qui ne les a pas).

**Double preuve** :
1. Spike exécuté (`dart analyze` clean + `dart run` : `extra` peuplé).
2. **Preuve de disque, plus forte** : `kDomainDecoders` (`registrars.dart:92-98`) câble **déjà** `'flashcard': ZFlashcard.fromMap` sur le typedef `Object Function(Map<String, dynamic> map)` — **et ça compile aujourd'hui**.

⇒ La prescription évidente **tient**. Le générateur émet `fromMap: $className.fromMap`.

### D2 — Factory absente ou incompatible ⇒ **ÉCHEC DE BUILD EXPLICITE**, jamais de repli silencieux (**R6**)

Un repli silencieux sur `_$XxxFromMap` recréerait **exactement** le défaut qu'on corrige, sur les ~8 entités d'ES-2. **Interdit.**

**Ce n'est pas un durcissement gratuit** : le générateur **présuppose déjà** l'existence de `T.fromMap(Map<String, dynamic>)` pour tout `@ZcrudModel` utilisé comme **sous-modèle** —
`zcrud_model_generator.dart:265` (`_$decodeModel($m, $t.fromMap)`) et `:306` (`${f.elementTypeName}.fromMap(const <String, dynamic>{})`).
D2 ne fait que transformer une **hypothèse implicite** en **contrat vérifié par machine** (R1/R6). Les 5 entités réelles + les 2 modèles de test (`Article`, `Author`) la définissent **toutes**.

**Détection — API analyzer 8 PROUVÉE par spike** (le générateur est sur `analyzer: ^8.0.0`) :
```dart
element.constructors.where((c) => c.name == 'fromMap')   // .name == 'fromMap' ; 'new' pour l'anonyme
```
Sortie réelle du spike : `ZChoice` → `ctor.name=fromMap isFactory=true` ; idem `ZFlashcard`, `Article`, `Author`.

**Validation de signature — API PROUVÉE** (`ctor.formalParameters`) :
- exactement **1** paramètre **positionnel requis** de type `Map<String, dynamic>` (`p.isPositional && p.isRequired`) ;
- **tous les autres paramètres sont optionnels** (`p.isOptional`).
Sortie réelle du spike sur `ZFlashcard.fromMap` : `map` (positional=true required=true), `sourceRegistry` (optional=true), `extensionParser` (optional=true).

**Message d'échec** (`InvalidGenerationSourceError`, patron des l. 63-75 / 122-127 / 220-225) : nommer la classe, dire **pourquoi** (« sans factory de domaine, le registre décoderait par `_$XxxFromMap`, qui **détruit** `extra` — AD-4/DW-ES14-1 »), et donner le geste (« déclarez `factory Xxx.fromMap(Map<String, dynamic> map) => _$XxxFromMap(map);` »).

> **Repli borné, SI et SEULEMENT SI** le dev prouve que D2 casse un cas légitime : restreindre l'échec dur aux classes **`ZExtensible`** (détection par `TypeChecker` sur `ZExtensible`, `packages/zcrud_core/lib/src/domain/extension/z_extensible.dart:18` — le générateur importe déjà `zcrud_core`). Un repli sur `_$XxxFromMap` reste alors autorisé **uniquement** pour une classe non-`ZExtensible`, et doit être **BRUYANT** dans le log de build (`log.warning`) — **jamais** silencieux (R6). Toute déviation est **justifiée par écrit** en Completion Notes.

### D3 — 🔴 L'assertion (e) doit être **CONDITIONNÉE à `expectExtensible`** — la lettre de la spec porte (encore) le défaut

**AD-19.1.c / la rétro disent : « round-trip préservant une clé inconnue POUR CHAQUE KIND ».** **Pris au pied de la lettre, c'est FAUX.**

`ZChoice` (kind **`flashcard_choice`**) est **enregistrée** mais **n'est PAS `ZExtensible`** (`class ZChoice {` — aucun `extra`, cf. `kNonExtensibleKinds`). Elle **ne peut structurellement pas** préserver une clé inconnue. Une assertion (e) « pour chaque kind » la rendrait **ROUGE À JAMAIS**.

C'est **la même erreur** que le cast `as ZExtensible` de la spec figée (piège n°1 corrigé en ES-1.4) : la lettre de la spec se casse sur `ZChoice` **une deuxième fois**.

⇒ **(e) s'applique EXACTEMENT là où (a)/(b) s'appliquent** — et le saut est **DÉCLARÉ, jamais silencieux** (patron **L1** déjà en place : `expectExtensible`, `assertExtraClean` mord dans les **deux** sens).

### D4 — 🔴 **FINDING NOUVEAU — la voie registre détruit AUSSI `extension`** (⇒ dette **DW-ES14-2**)

Constat de disque : **les 4 entités `ZExtensible` mettent `'extension'` dans `_reservedKeys`** (`z_flashcard.dart:335`, `z_repetition_info.dart:242`, `z_study_folder.dart:327`, `z_study_session_config.dart`) — et `ZFlashcard` y met **aussi** `'source'`.

Conséquence, **même après le swap D1**, sur la voie registre (`extensionParser: null`, faute de slot d'injection dans `ZcrudRegistry`) :

| Canal hors-codegen | Sort via `registry.decode` **après** D1 | Pourquoi |
|---|---|---|
| **`extra`** | ✅ **PRÉSERVÉ** (objet de cette story) | `_extraFrom(map)` |
| **`source`** | ✅ **PRÉSERVÉ** | `ZFlashcardSource.fromJson(raw, registry: null)` → kind inconnu ⇒ `ZCustomSource(kind, body)` (**payload brut conservé**, `z_flashcard_source.dart:77-86`) |
| **`extension`** | ⛔ **DÉTRUIT** | `_decodeExtension(raw, null)` → **`if (parser == null) return null;`** (`z_flashcard.dart:316`) ; `'extension'` étant **réservée**, elle n'atterrit pas non plus dans `extra` ; `toMap()` n'émet `extension` que si non-`null` ⇒ **la clé disparaît du round-trip**. |

**Conséquence NON NÉGOCIABLE sur le périmètre** : ⛔ **NE PAS supprimer purement et simplement l'avertissement dartdoc de `fromRegistry`.** Déclarer la voie « sûre » après n'avoir corrigé que `extra` serait **exactement le motif de l'epic ES-1** (*« un artefact déclaré valide sur la base de son existence, jamais de son pouvoir discriminant observé »*). L'avertissement est **REFORMULÉ** (AC7) et la perte résiduelle est **ÉPINGLÉE PAR UN TEST** (AC8).

**Pourquoi ne PAS corriger `extension` dans cette story** : il faudrait un slot d'injection de parser dans `ZcrudRegistry` (**`zcrud_core`**) ou changer la sémantique des entités (**`zcrud_study_kernel`**) — les **deux** packages que cette story s'interdit d'écrire (condition de la parallélisation avec ES-2.1/2.2/2.6). ⇒ **DW-ES14-2 ouverte, documentée, épinglée ; à traiter AVANT ES-3.2/ES-3.5**, comme DW-ES14-1.

### D5 — 🔴 **La piste L3 de la rétro est FALSIFIÉE par la mesure** — le lint prescrit ne s'applique pas

La rétro (et le finding L3 d'ES-1.3) prescrivent : *« faire émettre `// ignore_for_file: deprecated_member_use` par `zcrud_generator` »*, au motif que *« si l'exclusion `**/*.g.dart` saute, l'analyse rougit sur du code non éditable »*.

**Mesure réelle** (exclusion levée sur `packages/zcrud_study_kernel`, puis restauration à l'octet près — `git diff` **vide**) :

```
dart analyze packages/zcrud_study_kernel/lib
→ 29 issues found.
→ ZÉRO `deprecated_member_use`.
```

**Cause** : un `.g.dart` est un **`part of`** — donc la **MÊME BIBLIOTHÈQUE** que l'entité qui déclare le membre déprécié. Dart n'émet **aucun** diagnostic de dépréciation **intra-bibliothèque** (confirmé aussi par spike isolé : témoin sans `ignore` = « No issues found »).

⇒ Émettre `// ignore_for_file: deprecated_member_use` **ne supprimerait RIEN**. Ce serait un **artefact décoratif jamais observé en train de supprimer quoi que ce soit** — précisément la faute que la rétro condamne.

**Diagnostics RÉELLEMENT mesurés** si l'exclusion saute : `unused_element` (les helpers partagés `_$asInt`/`_$asDouble`/… ne sont pas référencés dans toutes les bibliothèques) + `unnecessary_nullable_for_final_variable_declarations`.

⇒ **Décision : L3 est tranchée PAR LA MESURE (AC9), pas par un ignore décoratif.**

---

## Acceptance Criteria

### AC1 — Le registrar généré décode par la factory de DOMAINE
**Given** une classe annotée `@ZcrudModel` déclarant `factory Xxx.fromMap(Map<String, dynamic> map)` (éventuellement avec des paramètres nommés **optionnels**),
**When** `melos run generate` régénère les `*.g.dart`,
**Then** le `registerXxx` émis contient **`fromMap: Xxx.fromMap,`** (et **plus** `_$XxxFromMap`),
**And** les 5 registrars réels (`registerZStudyFolder`, `registerZStudySessionConfig`, `registerZFlashcard`, `registerZRepetitionInfo`, `registerZChoice`) le reflètent sur disque,
**And** `toMap: (value) => value.toMap(),` et `fieldSpecs:` sont **inchangés** (non-régression).

### AC2 — Absence/incompatibilité de la factory ⇒ échec de build EXPLICITE (R6)
**Given** une classe `@ZcrudModel` **sans** `fromMap`, **ou** dont le `fromMap` a un paramètre **requis** en plus de la map,
**When** le builder tourne,
**Then** il lève une **`InvalidGenerationSourceError`** nommant la classe, la raison (`extra` serait détruit — AD-4/DW-ES14-1) et le geste correctif,
**And** **aucun** repli silencieux sur `_$XxxFromMap` n'a lieu,
**And** le cas est couvert par un test dans `packages/zcrud_generator/test/build_failure_test.dart` (patron des échecs existants).

### AC3 — `registry.decode` PRÉSERVE `extra` (le cœur de DW-ES14-1)
**Given** un `ZcrudRegistry` peuplé par tous les `kRegistrars`, et une map de sonde portant une clé **inconnue du schéma** (`zz_cle_inconnue: 'gardee'`),
**When** on appelle `registry.decode(kind, sonde)` pour **chaque kind `ZExtensible`**,
**Then** l'entité décodée a `extra['zz_cle_inconnue'] == 'gardee'` (⇒ **plus jamais `extra == {}`**),
**And** `registry.encode(kind, entité)['zz_cle_inconnue'] == 'gardee'` — le **round-trip complet** est préservé,
**And** `extra` ne contient **aucune** clé de `ZSyncMeta.reservedKeys` (l'assertion (a) reste vraie, et **cesse d'être vacuelle**).

### AC4 — Assertion **(e)** câblée dans le volet (A), **conditionnée** (D3)
**Given** le harnais `tool/reserved_keys_gate/`,
**When** le test par kind s'exécute,
**Then** une **5ᵉ assertion (e)** — *le round-trip `registry.decode → registry.encode` préserve `kProbeUnknownKey`* — est appliquée à **chaque kind `ZExtensible`**,
**And** elle est **SAUTÉE DE MANIÈRE DÉCLARÉE** pour les kinds de `kNonExtensibleKinds` (**`flashcard_choice`**) — jamais silencieusement (patron **L1**),
**And** un **contre-exemple mensonger PERMANENT** (ex. `_ExtraDroppingEntity` : décode `extra` correctement mais **omet `...extra`** dans son `toMap`) prouve que **(e) MORD** — cette entité est **verte sur (a)/(b)/(c)/(d)** pour que **seule (e)** puisse la faire rougir (**R2 : fixture isolée par règle**).

### AC5 — La déviation `kDomainDecoders` est SUPPRIMÉE
**Given** que `registry.decode` == décodage de domaine (AC1),
**When** on relit `tool/reserved_keys_gate/lib/src/registrars.dart`,
**Then** `kDomainDecoders` (l. 92-98), son `typedef ZDomainDecoder` et son dartdoc de déviation **n'existent plus**,
**And** le test par kind de `reserved_keys_test.dart` décode via **`registry.decode`** (les deux tests par kind — voie domaine / voie registre — **fusionnent en un seul**),
**And** les assertions de cohérence de câblage portant sur `kDomainDecoders` (`reserved_keys_test.dart:51-56, 64-69`) sont retirées,
**And** le **contrat d'extension ES-2** du dartdoc de `registrars.dart` passe de **3 lignes à 2** par entité (`kRegistrars` + `kProbeBodies`),
**And** **aucune référence morte** à `kDomainDecoders` ne subsiste — **y compris dans le message d'échec de `scripts/ci/gate_reserved_keys.dart` (l. ~541)** et dans le dartdoc de `fromRegistry`.

### AC6 — 🔴 Injection de régression **REJOUÉE** (R3) — critère de clôture
**Given** l'arbre vert,
**When** on **casse volontairement** le générateur (remettre `fromMap: _\$${className}FromMap`) puis `melos run generate` + `dart run melos run gate:reserved-keys`,
**Then** le gate est **ROUGE** sur l'assertion **(e)** (et/ou (b)) — **sortie brute collée dans les Completion Notes**,
**And** après restauration **à l'octet près** (`git diff` **vide**) + `melos run generate`, le gate est **VERT**,
**And** l'orchestrateur **rejoue lui-même** 1→4 (le rapport de l'agent ne vaut pas preuve).
> ⚠️ **Piège structurel à connaître** : (e) vit dans le **volet (A)**, qui est **explicitement SKIPPÉ en mode fixture `--root`** (`gate_reserved_keys.dart:676-680`). Une fixture `prove_gates --root` ne peut donc **PAS** prouver (e). La preuve de (e) = **contre-exemple permanent dans le harnais (AC4) + cette injection réelle (AC6)**. Ne pas fabriquer une fixture `--root` vacuellement verte.

### AC7 — L'avertissement `DW-ES14-1` de `fromRegistry` est **REFORMULÉ** (pas supprimé) — D4
**Given** le finding D4 (`extension` reste détruit),
**When** on relit le dartdoc de `FirebaseZRepositoryImpl.fromRegistry` (l. ~130-195),
**Then** le tableau « VOIE REGISTRE → `extra` = {} ⛔ PERDU » est **corrigé** (`extra` ✅ **PRÉSERVÉ**, `source` ✅ **PRÉSERVÉ** via `ZCustomSource`),
**And** un avertissement **subsistant et explicite `DW-ES14-2`** signale que **`extension` est DÉTRUIT** sur cette voie (parser non injectable dans `ZcrudRegistry`) et **quand** l'utiliser malgré tout,
**And** **DW-ES14-2** est inscrite dans la section **Deferred › DETTES OUVERTES** de `architecture-zcrud-study-2026-07-12/architecture.md`, avec sévérité, cause, **critère de clôture** et **« à traiter AVANT ES-3.2/ES-3.5 »**,
**And** **DW-ES14-1** y est marquée **SOLDÉE** (avec la correction ratifiée du pt. 2 d'AD-19.1.c : la voie registre peuple désormais `extra` ⇒ la déviation `kDomainDecoders` est supprimée).

### AC8 — La perte résiduelle d'`extension` est **ÉPINGLÉE PAR UN TEST** (jamais implicite)
**Given** une sonde portant une clé `extension` valide,
**When** elle est décodée via `registry.decode` puis ré-encodée,
**Then** un test **nommé et commenté** (`DW-ES14-2`) **fige le comportement réel** : `extension` **n'est pas** dans la map ré-encodée,
**And** son dartdoc/`reason` dit explicitement que c'est une **PERTE CONNUE ET DÉLIBÉRÉMENT NON CORRIGÉE ICI** (périmètre : `zcrud_core`/kernel interdits à cette story), et **ce que le test devra devenir** quand DW-ES14-2 sera soldée,
**And** le test **rougirait** si la perte devenait **silencieusement** pire (ex. `extra` régressé du même coup).
> Ce test est un **verrou d'honnêteté** : il rend la dette **visible en machine**, pas seulement en prose (motif n°2 de la rétro : *« règle écrite, aucune machine »*).

### AC9 — L3 est tranchée **PAR LA MESURE** (D5)
**Given** la piste de la rétro (`// ignore_for_file: deprecated_member_use` émis par le générateur),
**When** le dev **re-mesure lui-même** (lever l'exclusion `**/*.g.dart`, `dart analyze` sur un package générant, restaurer à l'octet près),
**Then** il **colle la sortie brute** dans les Completion Notes,
**And** **si** (attendu, déjà mesuré) il y a **ZÉRO `deprecated_member_use`** ⇒ **L3 est CLOSE — prémisse falsifiée** : **aucun `ignore` n'est émis** (un `ignore` qui ne supprime rien est un faux filet), et la falsification est consignée (rétro/architecture § dettes) avec la **raison** (`part of` ⇒ même bibliothèque ⇒ pas de diagnostic de dépréciation),
**And** **si** la mesure **contredit** ce constat ⇒ le générateur émet l'`ignore_for_file` avec les **noms de lints RÉELLEMENT mesurés**, et la suppression est **prouvée par injection** (avant : rouge / après : vert).
> ⛔ **Interdit** : émettre un `ignore` « au cas où », sans l'avoir vu supprimer un diagnostic réel.

### AC10 — Non-régression **repo-wide** (R9)
**Given** tous les workstreams au repos,
**When** l'orchestrateur rejoue la vérif,
**Then** `melos run generate` **OK**, `melos run analyze` **repo-wide RC=0**, `melos run verify` **repo-wide RC=0**,
**And** `dart run scripts/ci/prove_gates.dart` : **≥ la baseline mesurée au démarrage de la story (35 OK / 0 FAIL), jamais moins** — et **strictement supérieure** si des fixtures sont ajoutées,
**And** `melos list` = **15 packages** (`tool/reserved_keys_gate` reste dans `melos.ignore`),
**And** les suites restent vertes : `zcrud_flashcard` **189**, `zcrud_study_kernel` **108** (VM), `zcrud_core` **911**, `zcrud_firestore` **90**, `zcrud_mindmap` **110** (≥ baseline),
**And** `graph_proof` **ACYCLIQUE / CORE OUT=0**,
**And** **AD-5 intact** : **aucun** type `cloud_firestore` dans `zcrud_core` ; **AD-1 intact** : `analyzer` reste confiné à `zcrud_generator` + `dev_dependencies` racine.

---

## Tasks / Subtasks

- [x] **T1 — Générateur : émettre la factory de domaine** (AC1, AC2) — `packages/zcrud_generator/`
  - [x] T1.1 Ajouter la **détection** de la factory : `element.constructors.where((c) => c.name == 'fromMap')` (API **prouvée**, analyzer 8).
  - [x] T1.2 Ajouter la **validation de signature** via `ctor.formalParameters` : 1 positionnel requis `Map<String, dynamic>` + tous les autres `isOptional`.
  - [x] T1.3 Modifier `_emitRegister` (l. 437-447) : `fromMap: $className.fromMap,`. **Ne toucher ni `toMap:` ni `fieldSpecs:`.**
  - [x] T1.4 Échec explicite `InvalidGenerationSourceError` si absente/incompatible (message actionnable, patron l. 220-225).
  - [x] T1.5 **Ne PAS supprimer** l'émission de `_$XxxFromMap` : les factories de domaine l'appellent (`final base = _$ZXxxFromMap(map);`) et les sous-modèles en dépendent.
  - [x] T1.6 Tests : `zcrud_model_generator_test.dart` (le registrar émis contient `fromMap: Article.fromMap`) + `build_failure_test.dart` (2 cas : pas de `fromMap` ; `fromMap` à paramètre requis surnuméraire) + fixture(s) sous `test/models/`.
  - [x] T1.7 `melos run generate` → vérifier sur disque les **5** registrars réels.

- [x] **T2 — Harnais : assertion (e) + suppression de `kDomainDecoders`** (AC3, AC4, AC5) — `tool/reserved_keys_gate/`
  - [x] T2.1 `assertions.dart` : ajouter **(e)** (round-trip clé inconnue sur la map **ré-encodée**), **conditionnée à `expectExtensible`** (D3), skip **DÉCLARÉ** ; l'intégrer à `assertReservedKeysClean` (qui prend désormais `encoded` **issu du registre**).
  - [x] T2.2 `registrars.dart` : **supprimer** `kDomainDecoders` + `typedef ZDomainDecoder` + le dartdoc de déviation ; réécrire le **contrat d'extension ES-2** (2 lignes/entité).
  - [x] T2.3 `reserved_keys_test.dart` : **fusionner** les 2 tests par kind en **1** (décodage via `registry.decode`) ; retirer les assertions de cohérence `kDomainDecoders` ; **ajouter `_ExtraDroppingEntity`** (contre-exemple permanent **isolé** de (e) — vert sur (a)(b)(c)(d)).
  - [x] T2.4 Ajouter le **test de verrou DW-ES14-2** (AC8).

- [x] **T3 — Scripts CI** (AC5, AC10) — `scripts/ci/`
  - [x] T3.1 `gate_reserved_keys.dart` : corriger le message d'échec (l. ~541) qui cite `kDomainDecoders` (**référence morte** après T2.2) et l'en-tête si elle y fait allusion.
  - [x] T3.2 `prove_gates.dart` : **relancer** et vérifier la **non-régression** du nombre de fixtures. ⚠️ **Ne PAS** tenter d'y prouver (e) via `--root` (volet (A) skippé — cf. note d'AC6).
  - [x] T3.3 **Si** un script melos est ajouté/modifié : l'éditer dans **`pubspec.yaml` (source de vérité) ET `melos.yaml` (miroir)**, sinon **`gate:melos` rougit**. *(A priori aucun ajout : `gate:reserved-keys` existe déjà.)*

- [x] **T4 — `zcrud_firestore` : reformuler l'avertissement** (AC7) — `packages/zcrud_firestore/`
  - [x] T4.1 `firebase_z_repository_impl.dart` (l. ~130-195) : corriger le tableau (`extra` ✅, `source` ✅) et **conserver un avertissement `DW-ES14-2`** sur `extension`.
  - [x] T4.2 Vérifier qu'aucune autre dartdoc du repo n'affirme encore « `registry.decode` détruit `extra` » (grep `DW-ES14-1`).

- [x] **T5 — Architecture & dettes** (AC7, AC9)
  - [x] T5.1 `architecture-zcrud-study-2026-07-12/architecture.md` : **DW-ES14-1 → SOLDÉE** ; **DW-ES14-2 → OUVERTE** (§ Deferred) ; note sous AD-19.1.c (la correction ratifiée pt.2 est **levée** : le volet (A) décode désormais **par le registre**, comme le prescrivait la lettre).
  - [x] T5.2 Consigner la **falsification de L3** (D5) avec la mesure.

- [x] **T6 — Injection de régression + vérif verte** (AC6, AC10)
  - [x] T6.1 Injection R3 (casser → **ROUGE** → restaurer à l'octet près → **VERT**), **sortie brute** en Completion Notes.
  - [x] T6.2 `melos run generate` + `melos run analyze` + `melos run verify` **repo-wide** + `prove_gates` + `melos list` (15).

---

## Dev Notes

### Fichiers à toucher (chemins **vérifiés sur disque**)

| Fichier | Nature |
|---|---|
| `packages/zcrud_generator/lib/src/zcrud_model_generator.dart` | **UPDATE** — `_emitRegister` (l. 437-447) + détection/validation |
| `packages/zcrud_generator/test/zcrud_model_generator_test.dart` | UPDATE |
| `packages/zcrud_generator/test/build_failure_test.dart` | UPDATE (2 nouveaux cas) |
| `packages/zcrud_generator/test/models/` | NEW (fixtures d'échec) |
| `tool/reserved_keys_gate/lib/src/registrars.dart` | **UPDATE** — supprimer `kDomainDecoders` (l. 92-98) |
| `tool/reserved_keys_gate/lib/src/assertions.dart` | **UPDATE** — assertion (e) |
| `tool/reserved_keys_gate/test/reserved_keys_test.dart` | **UPDATE** — fusion + `_ExtraDroppingEntity` + verrou DW-ES14-2 |
| `scripts/ci/gate_reserved_keys.dart` | UPDATE — message l. ~541 |
| `scripts/ci/prove_gates.dart` | UPDATE (si fixtures) |
| `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart` | **UPDATE** — dartdoc `fromRegistry` (l. ~130-195) |
| `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md` | UPDATE — dettes + AD-19.1.c |

⛔ **NE PAS TOUCHER** : `packages/zcrud_core/**`, `packages/zcrud_study_kernel/**` (hors `*.g.dart` **régénérés**, gitignorés) — condition de la parallélisation.

### État actuel de ce qu'on modifie (lu, pas supposé)

- **`ZcrudRegistry.register<T>`** (`zcrud_registry.dart:75-90`) : `required T Function(Map<String, dynamic> map) fromMap` — **signature inchangée** par cette story (elle vit dans `zcrud_core`, interdit d'écriture ici ; **et elle n'a pas besoin de changer** : D1 est prouvé assignable).
- **`registry.decode`** (`:125-126`) : `codecFor(kind).fromMap(map)` — **inchangé**.
- **`toMap` d'instance** : `ZFlashcard.toMap({ZSourceRegistry? sourceRegistry})` a un **paramètre optionnel** ; `toMap: (value) => value.toMap()` s'y résout déjà (l'extension générée est **masquée** par la méthode d'instance). **Ne rien changer.**
- **Les 5 kinds** : `study_folder`, `study_session_config`, `flashcard`, `repetition_info`, `flashcard_choice` (`kProbeBodies`, `registrars.dart:51-62`).
- **`kNonExtensibleKinds`** = `{'flashcard_choice'}` — **la clé de D3**.
- **`kLegacyUpdatedAtMirrors`** = `{'study_folder', 'flashcard'}` — **test de verrou** figé (`reserved_keys_test.dart:130-141`) : **ne pas y toucher**, toute variation est ROUGE par conception.

### Ce qui doit rester vrai après la story (non-régression fonctionnelle)

- Le décodage reste **DÉFENSIF (AD-10)** : `ZXxx.fromMap` **ne throw jamais** (map vide, `extension` corrompue, enum inconnu…). Le swap **améliore** la défensivité (la factory de domaine sanitise en plus : `ZRepetitionInfo` clampe `interval`/`repetitions` négatifs — `z_repetition_info.dart:110-112`). **Ajouter un test** : `registry.decode(kind, {})` ne throw pour **aucun** kind.
- **AD-5** : aucun type `cloud_firestore` ne fuit dans `zcrud_core`.
- **AD-3** : `reflectable` reste banni (`gate:reflectable`).
- **AD-1** : `analyzer` reste confiné à `zcrud_generator`.

### Pièges connus (issus de la rétro ES-1 — à ne pas rejouer)

1. **R5 — jamais de regex sur du Dart.** Le générateur lit le **modèle d'éléments** ; `gate_reserved_keys.dart` lit l'**AST**. ⛔ Aucun `grep`/regex pour reconnaître une structure Dart.
2. **R6 — jamais de dégradation silencieuse.** Un repli sur `_$XxxFromMap` non signalé = le défaut recréé.
3. **R2 — une fixture par règle.** `_ExtraDroppingEntity` doit être **verte sur (a)(b)(c)(d)** ; sinon elle ne prouve **rien** sur (e) (c'est l'erreur exacte qui a masqué H1 d'ES-1.4).
4. **Faux vert par vacuité.** Après la story, l'assertion **(a) cesse d'être vacuelle** — c'est le gain principal, à **constater** (avant : `extra == {}` toujours ⇒ (a) triviale).
5. **`melos list` = 15.** Le harnais est dans `melos.ignore` ⇒ `melos run test` **ne l'exécute pas** : seul `gate:reserved-keys` le lance.

### References

- [Source: `_bmad-output/implementation-artifacts/stories/epic-es-1-retrospective.md` §5 (DW-ES14-1), §6 (R-D, R-G), R1–R9]
- [Source: `architecture-zcrud-study-2026-07-12/architecture.md` § AD-19.1.c (corrections ratifiées pt. 1 et 2), § Deferred › DW-ES14-1]
- [Source: `architecture-zcrud-2026-07-09/architecture.md` § AD-3 (codegen), AD-4 (`extra`), AD-5, AD-10, AD-16]
- [Source: `packages/zcrud_generator/lib/src/zcrud_model_generator.dart:437-447` (`_emitRegister`), `:265`/`:306` (dépendance implicite à `T.fromMap`)]
- [Source: `packages/zcrud_core/lib/src/domain/registry/zcrud_registry.dart:75-90, 125-131`]
- [Source: `tool/reserved_keys_gate/lib/src/registrars.dart:92-98` (`kDomainDecoders`), `:116` (`kNonExtensibleKinds`)]
- [Source: `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:130-195` (dartdoc DW-ES14-1), `:193` (`registry.decode`)]
- [Source: `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart:316, 332-337` ; `z_flashcard_source.dart:77-86` (D4)]
- [Source: `CLAUDE.md` — Key Don'ts, parallélisation, gates CI]

---

## Strategie de test

| Niveau | Test | Prouve |
|---|---|---|
| **Générateur** (unitaire) | `registerArticle` émis contient `fromMap: Article.fromMap` | AC1 |
| **Générateur** (échec de build) | classe sans `fromMap` / `fromMap` à param requis ⇒ `InvalidGenerationSourceError` | AC2 (R6) |
| **Harnais — volet (A)** | par kind : sonde polluée → `registry.decode` → **(a)(b)(c)(d)(e)** | AC3, AC4 |
| **Harnais — contre-exemple** | `_ExtraDroppingEntity` (verte sur (a)-(d)) fait **ROUGIR (e)** | AC4 (**R2**) |
| **Harnais — verrou de dette** | `extension` **absent** du ré-encodage registre (DW-ES14-2) | AC8 |
| **Défensivité** | `registry.decode(kind, {})` ne throw pour aucun kind | AD-10 |
| **Injection R3** | générateur remis à `_$XxxFromMap` ⇒ gate **ROUGE** ; restauré ⇒ **VERT** | **AC6 (clôture)** |
| **Repo-wide** | `analyze` + `verify` + `prove_gates` + `melos list` (15) | AC10 (**R9**) |

**Definition of Done** : AC1→AC10 verts · **injection de régression rejouée par l'orchestrateur** · findings HIGH/MAJEUR/MEDIUM du code-review corrigés (ou MEDIUM justifiés par écrit) · `melos run analyze` **ET** `melos run verify` **repo-wide** RC=0.

---

## Dev Agent Record

### Agent Model Used

`claude-opus-4-8` — skill BMAD **`bmad-dev-story` réellement invoqué** via le tool `Skill` (aucun fallback disque).

### Debug Log References

- Injection R3 n° 1 (générateur → `_$XxxFromMap`) : `gate:reserved-keys` **RC=1**, 8 tests rouges.
- Injection R3 n° 2 (contrat `_requireDomainFromMap` désactivé) : `build_failure_test` **2 rouges**.
- Injection R3 n° 3 (assertion (e) neutralisée) : **1 seul** test rouge — la fixture `_ExtraDroppingEntity` (isolation R2 prouvée).
- Re-mesure L3 (AC9) : exclusion `**/*.g.dart` levée → `dart analyze packages/zcrud_study_kernel/lib` → **29 issues, ZÉRO `deprecated_member_use`**.

### Completion Notes List

#### 1. AC6 — INJECTION DE RÉGRESSION (R3), sorties BRUTES

**(a) ROUGE** — générateur remis à `fromMap: _$${className}FromMap` + `melos run generate` (le `.g.dart` réel repasse à `fromMap: _$ZFlashcardFromMap`) :

```
$ dart run melos run gate:reserved-keys
[gate:reserved-keys] couverture : 5 registrar(s) sur disque (5 kind(s)), 5 câblé(s) (5 sonde(s)), 2 sonde(s) manuelle(s).
[gate:reserved-keys] volet (A) — flutter test --tags reserved-keys (tool/reserved_keys_gate)…
00:00 +1 -1: … study_folder : sonde polluée → decode/encode REGISTRE propres (a→e) [E]
  Expected: 'gardee'
    Actual: <null>
  [study_folder] (b) AD-4 RÉGRESSÉ : la clé inconnue `zz_cle_inconnue` n'a pas survécu au décodage.
… (idem study_session_config, flashcard, repetition_info)
00:00 +24 -8: DW-ES14-2 — VERROU … repetition_info : `extension` N'EST PAS réémise [E]
00:00 +24 -8: Some tests failed.
[gate:reserved-keys] ÉCHEC : volet (A) ROUGE : … (e) clé inconnue PERDUE au round-trip
  `registry.decode → encode` (DW-ES14-1 : le registrar généré doit câbler `fromMap: ZXxx.fromMap`…)
[gate:reserved-keys] 1 violation(s) — AD-19.1.
RC INJECTION = 1
```

⚠️ **Honnêteté sur ce que ce rouge prouve** : dans le test par kind, **(b) tombe AVANT (e)** — ce rouge ne prouve donc pas, à lui seul, que **(e) mord**. **Preuve complémentaire exigée par R3, réellement exécutée** (sonde jetable dans le harnais, appelant **(e) SEULE** sur la voie registre réelle, injection toujours active) :

```
00:00 +0 -1: (e) SEULE sur study_folder (voie registre réelle) [E]
  Expected: 'gardee'
    Actual: <null>
  [study_folder] (e) DW-ES14-1 / AD-4 VIOLÉ : la clé inconnue `zz_cle_inconnue` n'a PAS survécu au
  round-trip `registry.decode → registry.encode` — elle est DÉTRUITE. …
  (idem study_session_config, flashcard, repetition_info — 4/4 ROUGES)
```
*(sonde supprimée après mesure ; `git status` du harnais propre.)*

**(b) RESTAURATION à l'octet près** :
```
$ diff -q <sauvegarde> packages/zcrud_generator/lib/src/zcrud_model_generator.dart
RESTAURATION À L'OCTET PRÈS ✅   (fichiers identiques)
```

**(c) VERT** :
```
$ dart run melos run generate   → SUCCESS ; z_flashcard.g.dart:211 → fromMap: ZFlashcard.fromMap,
$ dart run melos run gate:reserved-keys
[gate:reserved-keys] OK — clés de sync réservées : volet (A) + volet (B) + couverture (AD-19.1.c).
RC = 0
```

**Injection n° 2 (AC2/R6 — le contrat du générateur)** : appel à `_requireDomainFromMap` commenté ⇒
```
00:14 +2 -2: … `fromMap` avec un paramètre REQUIS surnuméraire → échec explicite [E]
  Expected: throws <InvalidGenerationSource> with `message`: (contains 'BadFromMap.fromMap' and
            contains 'INCOMPATIBLE' and contains 'DW-ES14-1')
    Actual: <Instance of 'Future<void>'>          ⛔ AUCUN throw : le repli silencieux est revenu
  → 2 tests ROUGES (classe sans `fromMap` + signature incompatible)
```
Restauré à l'octet ⇒ `dart test` → **+91 All tests passed**.

**Injection n° 3 (AC4/R2 — l'isolation de la fixture (e))** : assertion (e) neutralisée (`kProbeUnknownValue` → `anything`) ⇒ **UN SEUL** test rouge :
```
00:00 +31 -1: Some tests failed.
  reserved_keys_test.dart: AC4 — assertion (e) … (e) MORD : `toMap` sans `...extra` ⇒ clé inconnue DÉTRUITE
```
⇒ `_ExtraDroppingEntity` **ne dépend QUE de (e)** (verte sur (a)(b)(c)(d)) : la fixture est bien **isolée par règle** (R2). Restauré à l'octet ⇒ **+32 All tests passed**.

#### 2. AC9 — L3 tranchée PAR LA MESURE (D5 CONFIRMÉ, prémisse FALSIFIÉE)

Re-mesure **rejouée moi-même** (exclusion `- "**/*.g.dart"` retirée de `analysis_options.yaml` racine) :

```
$ dart analyze packages/zcrud_study_kernel/lib
   info - src/domain/z_study_session_config.g.dart:97:18 - Unnecessary 'this.' qualifier … - unnecessary_this
   …
29 issues found.

$ dart analyze … | grep -c deprecated_member_use
0                                    ⛔ ZÉRO

Diagnostics RÉELS (par type) :  18 unnecessary_this · 9 unused_element
                                 2 unnecessary_nullable_for_final_variable_declarations
```
Restauration : `git diff --stat analysis_options.yaml` → **VIDE** ; `dart analyze` → `No issues found!`.

**Cause** (confirmée) : un `.g.dart` est un `part of` ⇒ **même bibliothèque** que l'entité déclarant le membre déprécié ⇒ **aucun diagnostic de dépréciation intra-bibliothèque**. ⇒ **AUCUN `// ignore_for_file` n'est émis** : ce serait un artefact décoratif jamais vu supprimer quoi que ce soit — la faute exacte que la rétro condamne. **L3 CLOSE** (consignée en architecture § Deferred).

#### 3. Points où j'ai dû REMETTRE LA STORY EN CAUSE (R-G)

1. **D2 — la story sous-estime le périmètre du contrat.** Elle affirme : *« Les 5 entités réelles + les 2 modèles de test (`Article`, `Author`) la définissent toutes »*. **FAUX** : `packages/zcrud_generator/test/dp12_dp13_projection_test.dart` déclare **3 modèles in-memory** (`Decorated`, `Flags`, `Plain`) **sans `fromMap`** — D2 les casse. **Traité SANS affaiblir D2** (le repli borné autorisé par la story n'a **pas** été utilisé) : les 3 fixtures reçoivent leur factory de domaine. Le contrat reste un **échec dur**, sans exception.
2. **AC6 — le rouge du gate ne prouve pas (e) à lui seul** (voir § 1) : (b) tombe avant. Preuve isolée de (e) **exécutée en plus**.
3. **AC5 — « aucune référence morte »** : le message d'échec du gate a été réécrit **sans nommer** `kDomainDecoders` (pointer un symbole supprimé enverrait le mainteneur le chercher). Les 2 mentions restantes (dartdoc `registrars.dart`, commentaire du test) sont des **notes historiques explicites** (« n'existe plus / a été supprimée »), pas des pointeurs.
4. **Constat hors périmètre (à arbitrer par l'orchestrateur)** : les `*.g.dart` de `packages/**` sont **SUIVIS PAR GIT** (`git check-ignore` négatif ; commit `a64e3b3`) — ce qui **contredit CLAUDE.md** (« gitignorés, jamais committés »). Les **5 `.g.dart` régénérés** apparaissent donc dans `git status` et **doivent être committés** avec la story, sous peine de laisser dans git des registrars qui câblent encore `_$ZXxxFromMap`. **Je n'ai rien committé.**

#### 4. Conformité D1..D5

- **D1** ✅ tenu : `fromMap: $className.fromMap` — les 5 registrars réels le reflètent sur disque ; le tear-off à paramètres nommés optionnels est bien assignable (`ZFlashcard`/`ZStudyFolder`/… compilent et décodent).
- **D2** ✅ tenu **sans repli** : `InvalidGenerationSourceError` (absence **et** signature incompatible), détection par le **modèle d'éléments analyzer** (R5 — zéro regex).
- **D3** ✅ tenu : (e) **conditionnée à `expectExtensible`**, skip **DÉCLARÉ** et vérifié **dans les deux sens** contre le type réel ; `flashcard_choice` sauté sans silence.
- **D4** ✅ tenu : avertissement de `fromRegistry` **REFORMULÉ, pas supprimé** (`extra` ✅ / `source` ✅ / `extension` ⛔) ; **DW-ES14-2** ouverte en architecture + **épinglée par 4 tests de verrou** (un par kind `ZExtensible`), qui rougiraient aussi si la perte s'étendait à `extra`.
- **D5** ✅ tenu : L3 falsifiée par la mesure, **aucun `ignore` décoratif**.

#### 5. Vérif verte (rejouée, RC réels)

| Commande | Résultat |
|---|---|
| `dart run melos run generate` | **SUCCESS** |
| `dart run melos run analyze` (repo-wide) | **RC=0** |
| `dart run melos run verify` (repo-wide, avant-plan) | **RC=0** (9 gates, dont `gate:web` + `gate:reserved-keys`) |
| `dart run melos run test` | **RC=0** |
| `dart run scripts/ci/prove_gates.dart` | **35 OK / 0 FAIL** (= baseline ; aucune fixture ajoutée — AC6 **interdit** de prouver (e) via `--root`, le volet (A) y étant skippé) |
| `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK · CORE OUT=0 OK** (15 nœuds) |
| `dart run melos list` | **15** packages |

**Compteurs de tests (avant → après)** : `zcrud_generator` **87 → 91** · harnais `reserved_keys_gate` **24 → 32** · `zcrud_flashcard` **189 = 189** · `zcrud_study_kernel` **108 = 108** · `zcrud_core` **911 = 911** · `zcrud_firestore` **90 = 90** · `zcrud_mindmap` **110 = 110** — **zéro régression**.

**AD-1/AD-5 intacts** : `analyzer` reste confiné à `zcrud_generator` ; aucun type `cloud_firestore` dans `zcrud_core` ; **aucune écriture** dans `zcrud_core` ni `zcrud_study_kernel` (hors `*.g.dart` **régénérés**) — la parallélisation avec ES-2.1/2.2/2.6 est préservée.

### File List

**Modifiés**
- `packages/zcrud_generator/lib/src/zcrud_model_generator.dart` — `_requireDomainFromMap` (détection + validation de signature, échec dur) ; `_emitRegister` → `fromMap: Xxx.fromMap`
- `packages/zcrud_generator/test/build_failure_test.dart` — 3 tests (sans `fromMap` ; param requis surnuméraire ; nommés optionnels acceptés + registrar émis)
- `packages/zcrud_generator/test/zcrud_model_generator_test.dart` — AC1 sur le `.g.dart` réel (domaine câblé, `_$XxxFromMap` non câblé, `toMap`/`fieldSpecs` inchangés)
- `packages/zcrud_generator/test/dp12_dp13_projection_test.dart` — factories `fromMap` des 3 modèles in-memory (contrat D2)
- `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart` — dartdoc `fromRegistry` **reformulé** (DW-ES14-1 soldée / **DW-ES14-2** ouverte)
- `tool/reserved_keys_gate/lib/src/assertions.dart` — **assertion (e)** `assertUnknownKeyRoundTrip` + intégration à `assertReservedKeysClean`
- `tool/reserved_keys_gate/lib/src/registrars.dart` — **suppression** de `kDomainDecoders` + `typedef ZDomainDecoder` ; contrat d'extension **2 lignes**
- `tool/reserved_keys_gate/test/reserved_keys_test.dart` — fusion des 2 tests/kind en 1 (**voie registre**) ; `_ExtraDroppingEntity` (contre-exemple isolé de (e)) ; **verrou DW-ES14-2** ; défensivité `decode({})`
- `scripts/ci/gate_reserved_keys.dart` — en-tête (volet A = voie registre + (e)) ; messages d'échec (référence morte purgée)
- `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md` — DW-ES14-1 **SOLDÉE** ; **DW-ES14-2 OUVERTE** ; L3 **CLOSE (falsifiée)** ; correction ratifiée n° 2 d'AD-19.1.c **levée**

**Régénérés** (suivis par git, cf. § 3 pt. 4) : `z_study_folder.g.dart`, `z_study_session_config.g.dart`, `z_flashcard.g.dart`, `z_repetition_info.g.dart`, `z_choice.g.dart`, `packages/zcrud_generator/test/models/article.g.dart`
</content>
</invoke>
