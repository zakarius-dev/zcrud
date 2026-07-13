# Code Review — Story ES-1.4 : Gates CI d'extension + `gate:reserved-keys` (AD-19.1.c)

- **Mode** : VRAI skill `bmad-code-review` (tool `Skill`), customization résolue via `_bmad/scripts/resolve_customization.py`. Contexte non interactif (sous-agent de Workflow) → cascade Tier 1 (story fournie), diff = arbre de travail + fichiers non suivis.
- **Story** : `_bmad-output/implementation-artifacts/stories/es-1-4-gates-ci-extension.md`
- **Spec normative** : `architecture.md` § AD-19.1.c (mise à jour par la story — relue).
- **Date** : 2026-07-13
- **Verdict** : ⛔ **CHANGES REQUESTED** — **1 HIGH** (le cinquième faux vert **est trouvé**), **3 MEDIUM**, **3 LOW**.
- **Décompte** : HIGH 1 · MEDIUM 3 · LOW 3 · Total 7.

---

## 0. Synthèse exécutive

La story livre une infrastructure de gates d'une qualité nettement au-dessus de la moyenne du repo : le `exit 79` FATAL est **réel** (vérifié empiriquement), l'assertion (b) rend l'assertion (a) **non-vacueuse par construction**, la déviation de la spec figée (`registry.decode` → voie de domaine) est **correcte et documentée**, la CI en step unique **ne perd aucun gate**, et l'allowlist legacy est verrouillée dans les deux sens.

**Mais le motif « le filet existait, il n'était pas accroché » se reproduit une CINQUIÈME fois**, cette fois **dans le filet lui-même**.

Le contrôle de couverture `E_disk \ E_covered` — la règle **précise** dont la mission est d'empêcher qu'une entité d'ES-2 échappe au volet (A) — repose sur une **regex ligne-à-ligne** qui ne reconnaît qu'une seule forme de déclaration de classe. Trois formes **légales, banales et produites par `dart format` lui-même** lui échappent. Une entité ES-2 **écrite à la main** dans l'une de ces formes traverse le gate **VERTE sans jamais être sondée**.

C'est prouvé empiriquement (fixtures ci-dessous, `RC=0`). Et — coïncidence révélatrice — c'est **la seule des trois règles de couverture qui n'a pas sa propre fixture dans `prove_gates.dart`** : on ne l'a jamais vue échouer *isolément*. « Un gate qu'on n'a pas vu échouer n'est pas un gate » : la règle (3) n'a, à ce jour, jamais été vue échouer seule.

---

## 1. Réponse directe aux axes prioritaires

### Axe 1 — Le volet (A) teste-t-il VRAIMENT quelque chose ? → **OUI. Non vacueux.**

| Sous-question | Verdict | Preuve |
|---|---|---|
| (a) `kDomainDecoders` couvre-t-il tous les kinds ? | ✅ **Oui, et l'oubli mord** | Le test `chaque kind enregistré a un corps de sonde ET un décodeur` (`reserved_keys_test.dart:35`) compare `registry.kinds` à `kProbeBodies` **et** `kDomainDecoders`, **dans les deux sens** (kind sans corps ⇒ ROUGE ; corps orphelin ⇒ ROUGE). Pas de fallback `{}` silencieux. |
| (b) Les corps de sonde sont-ils assez riches pour que `extra` soit réellement peuplé ? | ✅ **Oui — et c'est garanti par construction, pas par chance** | L'assertion **(b)** (`extra['zz_cle_inconnue'] == 'gardee'`) **échoue** si `fromMap` ne peuple pas `extra`. La suite étant verte sur les 5 kinds + 2 sondes manuelles, `extra` **est** peuplé partout ⇒ l'assertion (a) porte sur un `extra` non vide. **Vérifié sur disque** : `ZStudyFolder.fromMap` → `extra: _extraFrom(map)` (`z_study_folder.dart:131`). C'est le point de design le plus solide de la story : **(b) est l'anti-vacuité de (a)**. |
| (c) L'assertion (b) empêche-t-elle de « passer le gate en vidant `extra` » ? | ✅ **Oui** | C'est exactement son rôle, et le contre-exemple `_LyingEntity` (AC5) prouve en permanence que les assertions mordent. |
| (d) `registry.encode` sur une entité décodée-domaine est-il représentatif de la production ? | ✅ **Oui** | Le registrar généré câble `toMap: (value) => value.toMap()` (`z_study_folder.g.dart:202`) — `registry.encode` **délègue au `toMap` d'instance du domaine**, c'est-à-dire exactement le chemin d'écriture de production. Les assertions (c)/(d) sont donc pleinement représentatives. (Contrairement à `decode`, `encode` **n'est pas** dégradé.) |

**La déviation du dev par rapport à la lettre d'AD-19.1.c est JUSTIFIÉE et correctement documentée** (`registrars.dart:64-91`, `architecture.md` AD-19.1.c « Piège n°2 »). Sans elle, le gate aurait effectivement été vacuellement vert. Bon appel.

### Axe 2 — Contrôle de couverture anti-faux-vert → **PARTIELLEMENT AVEUGLE. C'est le HIGH.**

| Règle | État | |
|---|---|---|
| `R_disk \ R_wired` (registrar sur disque non câblé) | ✅ **Réelle** | Scan des `*.g.dart` sous `packages/*/lib` — **aucun chemin en dur**, un package ES-2 est découvert automatiquement (`_packageLibs` itère `packages/*`). Regex `void\s+(registerZ\w+)\s*\(\s*ZcrudRegistry` : **vérifiée conforme** aux 5 registrars réellement générés. Fixture `prove_gates` dédiée. |
| `R_wired \ R_disk` (câblage mort) | ✅ Réelle | |
| **`E_disk \ E_covered`** (classe `ZExtensible` ni enregistrée ni sondée) | ⛔ **AVEUGLE sur 3 formes de déclaration légales** | **Voir H1.** Preuve empirique `RC=0`. |

Le scan est **structurellement bon** (pas de chemin/glob en dur ; `packages/*` découvert par `listSync`). Le défaut n'est pas dans l'**énumération des packages**, il est dans la **reconnaissance des classes**.

### Axe 3 — `exit 79` FATAL (risque R1) → **RÉELLEMENT FATAL. Vérifié.**

Preuve empirique (code de sortie mesuré **sans pipe** — le premier essai mesurait `tail` et rendait un faux `EXIT=0`, ironie notée) :

```
$ cd tool/reserved_keys_gate && flutter test --tags reserved-keys-TYPO
No tests ran.
No tests match the requested tag selectors: include: "reserved-keys-TYPO"
EXIT_REEL_FLUTTER=79
```

`gate_reserved_keys.dart:280` traite `r.exitCode == 79` comme `_fail(...)` ⇒ `exit(1)`. **Un `@Tags` mal orthographié, supprimé, ou un `dart_test.yaml` cassé ⇒ gate ROUGE.** Une erreur de compilation du harnais ⇒ `exitCode != 0` ⇒ ROUGE (ligne 288). Un `flutter` absent du PATH ⇒ `ProcessException` non capturée ⇒ RC=255 ⇒ ROUGE. Un harnais absent ⇒ `_fail` explicite (ligne 257). **Aucun trou sur cet axe.**

### Axe 4 — DW-ES14-1 → **RÉEL, PROUVÉ, mais LATENT (zéro appelant). MEDIUM.** Voir M2.

---

## 2. Findings

### 🔴 HIGH

#### H1 — `_classWithExtensible` : le détecteur de classes `ZExtensible` est aveugle à trois formes de déclaration légales ⇒ **une entité ES-2 peut traverser le gate sans jamais être sondée**

- **Fichier** : `scripts/ci/gate_reserved_keys.dart:114-115` (regex `_classWithExtensible`), consommée en **:133-134** (volet B) **et :227-231** (contrôle de couverture, règle (3)).
- **AD impactés** : **AD-19.1.c pt.1** (anti-faux-vert par omission), **AD-4** (round-trip `extra`), **AC2 de la story** (« un registrar/**une entité** non câblé(e) fait ROUGIR le gate » — non tenu pour « une entité »).

**Le défaut.** La détection est faite **ligne par ligne**, avec :

```dart
RegExp(r'^\s*(?:abstract\s+)?class\s+(\w+)\b[^{]*\bwith\b[^{]*\bZExtensible\b')
```

Elle exige que la déclaration tienne **sur une seule ligne** et n'accepte **aucun modificateur de classe Dart 3** hors `abstract`. Échappent donc au détecteur :

1. **En-tête enroulée par `dart format`** (nom long, `implements` multiples → > 80 colonnes) — le formateur du projet **produit lui-même** cette forme ;
2. **`final class`** (modificateur Dart 3) ;
3. **`base class`** / `sealed class` / `interface class`.

**Preuve empirique** (fixtures éphémères, gate exécuté en mode `--root`) :

| Fixture | Forme | `ZSyncMeta.reservedKeys` présent ? | Volet (B) | Couverture (3) | **RC** |
|---|---|---|---|---|---|
| A | `class ZStudyDocument with ZExtensible implements ZSyncable {` (1 ligne) | non | 🔴 mord | 🔴 mord | ≠0 ✅ |
| B | en-tête **enroulée** sur 3 lignes | non | 🔴 mord *(via `_extraField` seulement)* | ⚪️ **AVEUGLE** | ≠0 |
| C | `final class ZExam with ZExtensible {` | non | 🔴 mord *(via `_extraField`)* | ⚪️ **AVEUGLE** | ≠0 |
| D | `base class ZSmartNote with ZExtensible {` | non | 🔴 mord *(via `_extraField`)* | ⚪️ **AVEUGLE** | ≠0 |
| **E** | en-tête **enroulée** + `extra` exposé par **getter** + `...ZSyncMeta.reservedKeys` présent | **oui** | ⚪️ aveugle | ⚪️ **AVEUGLE** | **`0` — VERT** ⛔ |
| **F** | **`final class`** + `...ZSyncMeta.reservedKeys` présent | **oui** | ⚪️ aveugle | ⚪️ **AVEUGLE** | **`0` — VERT** ⛔ |

**Scénario de production ES-2 (parfaitement plausible)** :
1. ES-2 crée `ZSmartNoteRevisionSnapshot`, **écrite à la main** (pas de `@ZcrudModel` — exactement le cas de `ZMindmap`/`ZMindmapNode`, qui sont **déjà** dans cette catégorie) ;
2. le nom est long → `dart format` **enroule** l'en-tête ;
3. le dev, diligent, copie le motif et met bien `...ZSyncMeta.reservedKeys` → **volet (B) satisfait** ;
4. **pas de registrar** sur disque ⇒ `R_disk \ R_wired` **ne mord pas** ;
5. le dev **oublie** `manual_probes.dart` ⇒ règle (3) devrait mordre… **elle est aveugle** ;
6. **gate VERT. L'entité n'est JAMAIS sondée par le volet (A).**

C'est **exactement** la classe de défaut que la story existe pour prévenir, reproduite **à l'intérieur du gate**. Le filet est là ; il n'est pas accroché aux entités écrites à la main dont l'en-tête dépasse 80 colonnes.

> ⚠️ Nuance honnête, à porter au crédit du dev : pour les entités **annotées `@ZcrudModel`** (la majorité d'ES-2), le chemin `R_disk \ R_wired` mord **quelle que soit la forme de la déclaration** (il lit les `*.g.dart`, pas les en-têtes). Le trou ne concerne que les entités **hand-written**. Mais c'est précisément la catégorie que la règle (3) et `manual_probes.dart` ont été inventés pour couvrir — donc le trou est *pile* là où la protection était censée être.

**Recommandation** (correction obligatoire avant `done`) :
1. Détecter la classe sur le **fichier entier**, pas ligne à ligne, et accepter les modificateurs Dart 3 :
   ```dart
   final RegExp _classWithExtensible = RegExp(
     r'(?:abstract|base|final|sealed|interface|mixin)?\s*(?:base|final|sealed|interface)?\s*'
     r'class\s+(\w+)\b[^{;]*?\bwith\b[^{;]*?\bZExtensible\b[^{;]*?\{',
     multiLine: true, dotAll: true,
   );
   ```
   (ou, plus robuste et sans regex fragile : **normaliser le source** en repliant les sauts de ligne jusqu'au premier `{` de chaque déclaration `class`.)
2. Élargir `_extraField` à la forme **getter** (`Map<String, dynamic> get extra`), aujourd'hui invisible au volet (B).
3. **Ajouter à `prove_gates.dart` une fixture dédiée à la règle (3)** (cf. M1) — et l'écrire **avec une en-tête enroulée**, pour que la non-régression du présent finding soit gardée par machine.

---

### 🟠 MEDIUM

#### M1 — `prove_gates.dart` : la règle (3) `E_disk \ E_covered` n'a **aucune fixture propre** — la seule règle fragile est la seule jamais vue échouer isolément

- **Fichier** : `scripts/ci/prove_gates.dart:247-284`.
- **AD** : AD-19.1.c pt.1 ; principe « un gate qu'on n'a pas vu échouer n'est pas un gate » (story, condition de clôture).

Le harnais de preuve couvre : `reserved-keys/clean` (arbre réel, RC=0), `reserved-keys/fixture-syntaxique` (volet B), `reserved-keys/fixture-registrar-non-cable` (règle (1) `R_disk \ R_wired`). **Il ne couvre ni la règle (2) (câblage mort) ni la règle (3) (`E_disk \ E_covered`).**

La fixture `fixture-syntaxique` **semble** couvrir (3) — sa classe `ZBad with ZExtensible` déclenche effectivement les deux règles — mais l'assertion ne teste que `exitCode != 0` : **elle serait verte même si la règle (3) n'existait pas**. La preuve est donc **confondue**, et c'est précisément ce qui a permis à H1 de passer inaperçu : `26 OK / 0 FAIL` sans qu'aucun cas n'exerce (3) seule.

**Recommandation** : ajouter deux fixtures ciblées — (a) classe `ZExtensible` **contenant** `ZSyncMeta.reservedKeys` mais non couverte (isole (3) du volet B), **avec en-tête enroulée** ; (b) registrar câblé absent du disque (isole (2)).

#### M2 — DW-ES14-1 : `registry.decode` **détruit** `extra` — violation AD-4 **prouvée**, mais **latente** (zéro appelant)

- **Fichier** : `packages/zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:143` (`fromMap: (map) => registry.decode(kind, map) as T`).
- **Cause racine** : `zcrud_generator` émet `fromMap: _$ZXxxFromMap` (`z_study_folder.g.dart:201`) — la factory du codegen, qui **ne connaît que les champs `@ZcrudField`** et **ne touche jamais `extra`** (grep `extra` dans `z_study_folder.g.dart` : **0 occurrence**). La factory de domaine `ZStudyFolder.fromMap`, elle, fait `extra: _extraFrom(map)`.
- **AD** : **AD-4** (slot `extra` = round-trip garanti des clés inconnues), AD-16.
- **Non introduit par ES-1.4** — dette préexistante, **correctement identifiée, tracée et NON masquée** par le dev (`registrars.dart:86-91`, `architecture.md` AD-19.1.c).

**Preuve empirique** (test jetable exécuté dans le harnais, puis supprimé) :

```
VOIE DOMAINE        -> extra = {zz_cle_metier_app: valeur_critique}
VOIE REGISTRE       -> extra = {}                        ⛔ PERDU
ROUND-TRIP REGISTRE -> zz_cle_metier_app = null          ⛔ DÉTRUIT à la réécriture
```

**Est-ce une perte de données en production aujourd'hui ? NON — et c'est ce qui borne la sévérité.** `FirebaseZRepositoryImpl.fromRegistry` a **zéro appelant** dans tout le repo (`grep -rn "fromRegistry" packages example` → seulement sa propre déclaration et son dartdoc). Le constructeur nominal prend des closures `fromMap`/`toMap` explicites : une app qui passe `ZStudyFolder.fromMap` **préserve `extra`**.

**Sévérité : MEDIUM** (et non HIGH) : défaut **latent**, sur une fabrique **publique, documentée et présentée comme la « voie stricte »** — donc **destructif dès la première adoption**. Chaque lecture→écriture Firestore détruirait alors silencieusement toutes les clés métier inconnues du cœur.

**Corrigeable dans ES-1.4 ?** Le **correctif de fond, NON** : il appartient à `zcrud_generator` (émettre `fromMap: ZXxx.fromMap` lorsque la classe en définit une), ce qui touche le générateur + les 5 `.g.dart` + les tests du générateur → **hors périmètre, story dédiée requise** (DW-ES14-1 à porter au backlog **avant** ES-3.x / l'intégration store).

**Mitigation À FAIRE dans ES-1.4** (coût quasi nul, périmètre respecté) : annoter `fromRegistry` d'un avertissement dartdoc explicite — « ⚠️ **DW-ES14-1** : cette voie **perd `extra`** (AD-4 non préservé). Ne pas l'utiliser pour une entité `ZExtensible` tant que DW-ES14-1 n'est pas soldée » — voire `@Deprecated`. Sans cela, la dette est tracée dans un fichier de harnais que **personne ne lira** au moment de câbler le store.

#### M3 — `R_wired` est dérivé d'une **mention textuelle**, pas de l'appartenance réelle à `kRegistrars`

- **Fichier** : `scripts/ci/gate_reserved_keys.dart:154` (`_registrarRef = RegExp(r'\b(registerZ\w+)\b')`), consommée en :178-180.
- **AD** : AD-19.1.c pt.1.

Le gate considère un registrar « câblé » dès qu'il **apparaît textuellement** dans `registrars.dart` — n'importe où : dans une autre liste, dans un `const _obsoletes = [...]`, ou dans un **commentaire de bloc `/* */`** (le dépouillement `_stripLineComments` ne traite **que** les `//`). Le test de cohérence du harnais ne rattrape pas : il part de `registry.kinds`, donc de `kRegistrars` **réel**, et ne sait rien de ce que le gate a cru voir.

Conséquence : `R_disk ⊆ R_wired` peut être satisfait alors que le registrar **n'est pas dans `kRegistrars`** ⇒ kind **non sondé**, gate **vert**. Exploitation involontaire plausible : un dev qui commente temporairement une ligne de `kRegistrars` **en bloc** (`/* registerZExam, */`).

**Recommandation** : dériver `R_wired` du **seul littéral `kRegistrars`** — extraire la sous-chaîne entre `kRegistrars = <ZRegistrar>[` et le `];` correspondant, puis y appliquer `_registrarRef`. ~5 lignes. (Alternativement : dépouiller aussi les commentaires de bloc.)

---

### 🟡 LOW

#### L1 — `assertExtraClean` : early-return **silencieux** sur une entité non-`ZExtensible`
`tool/reserved_keys_gate/lib/src/assertions.dart:55` — `if (entity is! ZExtensible) return;`. Correct aujourd'hui (`ZChoice`), mais **aucune assertion positive** ne garantit qu'un kind *censé* être extensible l'est réellement : si `kDomainDecoders` était mal recâblé vers un type non-`ZExtensible`, (a) et (b) deviendraient **vacuelles sans le moindre signal**. Reco : dériver du disque un `expectExtensible` par kind, ou au minimum émettre un `printOnFailure`/log du skip.

#### L2 — `ZCRUD_SKIP_WEB_GATE=1` : interrupteur d'environnement qui **verdit** un gate
`scripts/ci/gate_web_determinism.dart:178` — vérifié : `ZCRUD_SKIP_WEB_GATE=1 → RC=0`. Le skip est **bruyant** (bannière), la CI ne le pose pas, et le besoin (dev hors-ligne) est légitime. Mais c'est **exactement** la mécanique du faux vert historique (`gate:web` qui skippait silencieusement faute de Node) — avec un interrupteur en plus. Reco : refuser le skip explicite quand `CI=true` (`Platform.environment['CI']`), pour que l'échappatoire soit **structurellement locale**.

#### L3 — `gate:web` exclut par construction les packages **Flutter** — conséquence non écrite
`scripts/ci/gate_web_determinism.dart:97-112` — cible = pur-Dart avec `test/` (aujourd'hui : `zcrud_annotations`, `zcrud_study_kernel` — vérifié à l'exécution). **Sans conséquence aujourd'hui** : la seule arithmétique 32-bit sensible au web du repo est `zFnv1a32` (`grep -rl "0xFFFFFFFF" packages/*/lib` → **uniquement** `zcrud_study_kernel/lib/src/domain/z_color_palette.dart`), qui est bien dans la cible. Mais `zcrud_core` est un package **Flutter** depuis E2-7 : toute future fonction de hachage / arithmétique 32-bit y serait **hors couverture web**. Le critère (« pur-Dart ») est écrit ; sa **conséquence** ne l'est pas. Reco : une ligne dans le dartdoc du gate + un renvoi dans AD-19/NFR-S8.

---

## 3. Axes vérifiés — RAS (points forts à acter)

| Axe | Verdict | Preuve rejouée |
|---|---|---|
| **5 — ci.yml en step unique : un gate a-t-il été PERDU ?** | ✅ **Aucun** | `git diff` de l'ancienne liste : `graph_proof`, `gate_melos_divergence`, `gate_reflectable`, `gate_secret_scan`, `gate_codegen`, `gate_compat_resolution`, `verify:serialization` — **les 7 sont dans `verify`** (`pubspec.yaml:117-126`). `gitleaks` **et** `prove_gates` **conservés en steps séparés** (à raison : historique git / fixtures). `gate:web` **AJOUTÉ** (il manquait). Bilan : **+2 gates, −0**. |
| **6 — opt-out `gate:web`** | ✅ Justifié par écrit | `gate_web_determinism.dart:50-59` : `zcrud_generator` = builder `build_runner` VM-only (`dart:io`/`analyzer`/`build`) — raison **écrite**, avec interdiction explicite du motif « les tests ne passent pas en JS ». Cible auto-découverte (`packages/*`), **aucun chemin en dur** : un package pur-Dart d'ES-2 est couvert **à sa création**. (Réserve : cf. L3 pour les packages Flutter.) |
| **7 — allowlist legacy `{study_folder, flashcard}`** | ✅ Verrou dans les **deux sens** | `reserved_keys_test.dart:121` : `equals({'study_folder','flashcard'})` ⇒ **toute croissance ET toute réduction = ROUGE**. Entrée **morte** : double garde — `assertEncodedClean` exige que l'entrée émette *réellement* `updated_at` (`assertions.dart:113`, anti-inertie) **et** le test `registry.isRegistered(kind)` (`:134`). Portée **strictement bornée à (d)** : `_LyingEntity` prouve que (a)/(b)/(c) mordent **même sous allowlist**. |
| **8a — blocs melos miroirs** | ✅ | `pubspec.yaml` (source de vérité) et `melos.yaml` portent des blocs `scripts:` identiques ; `gate:melos` (M-1) les compare — vert. `gate:reserved-keys` **présent des deux côtés** et **dans `verify`** (AC7). |
| **8b — hygiène git** | ✅ | `git add -An tool/reserved_keys_gate` → **7 fichiers source uniquement**. `build/` et `.flutter-plugins-dependencies` correctement **gitignorés** ; aucun `pubspec.lock` de harnais. **Aucune fixture résiduelle** (les fixtures de `prove_gates` sont éphémères ; celles de cette revue vivent dans le scratchpad, hors repo — arbre vérifié propre après revue). |
| **9 — interrupteur `verify:serialization`** | ✅ Vérifié empiriquement | Sans interrupteur → `RC=0` (SKIP bruyant, bannière nommant les packages) ; `ZCRUD_REQUIRE_SERIALIZATION_COMPAT=1` → **`RC=1`**. Le point d'accroche ES-3.5 (`packages/zcrud_study_kernel/dart_test.yaml`, tag `serialization-compat`) est en place. |
| **10 — `@TestOn('vm')` sur `no_runtime_dep_test`** | ✅ | Réponse **attendue** au gate (test structurel `dart:io`, inexécutable en JS), motivée par écrit — **pas** un opt-out de confort. |
| **11 — AD-19.1.c mis à jour** | ✅ | `architecture.md` documente les **deux** pièges de la spec figée (cast `ZChoice`, `registry.decode` vacuellement vert) et la dette DW-ES14-1. Spec et implémentation **réconciliées**. |

---

## 4. Complétude des ACs

| AC | État | Note |
|---|---|---|
| AC1 — volet (A) comportemental | ✅ | Assertions (a)(b)(c)(d), 5 kinds + 2 sondes manuelles, voie de domaine + ré-encodage registre. Non vacueux (cf. axe 1). |
| **AC2 — anti-faux-vert par omission (registrar **ou entité** non câblé(e) ⇒ ROUGE)** | ⛔ **PARTIEL** | **Registrar** : ✅. **Entité** : ⛔ **H1** — trois formes de déclaration échappent au détecteur. |
| AC3 — volet (B) syntaxique | 🟡 Partiel | Fonctionne, message actionnable ; mais aveugle à `get extra` et aux en-têtes enroulées (H1, pt. 2 de la reco). |
| AC4 — preuve par injection de régression | ✅ | Rejouée par l'orchestrateur (retrait de `...ZSyncMeta.reservedKeys` sur `z_repetition_info.dart` ⇒ ROUGE volets A **et** B ; restauration byte-identique). |
| AC5 — contre-exemple mensonger permanent | ✅ | `_LyingEntity` (`reserved_keys_test.dart:14`) — 5 tests, dont la portée minimale de l'allowlist. Excellent. |
| AC6 — gates auto-découvrants pour ES-2 | 🟡 Partiel | `gate:web` et `gate:reserved-keys` découvrent `packages/*` sans liste en dur ✅ — **mais** la découverte des **entités** est trouée (H1). |
| AC7 — `verify` des deux côtés (M-1) | ✅ | |
| AC8 — CI : Node + gates non dupliqués + ordre | ✅ | `setup-node@v4`, step unique `dart run melos run verify`, codegen **avant** les gates (requis : `gate:codegen` et `gate:reserved-keys` lisent les `*.g.dart`). |
| AC9 — slot rétro-compat sans faux vert | ✅ | SKIP bruyant + interrupteur, vérifiés. |
| AC10 — vérif verte repo-wide | ✅ | Rejouée par l'orchestrateur (melos verify RC=0, prove_gates 26/0, melos list=15, graph ACYCLIQUE/CORE OUT=0, 1408 tests). |

---

## 5. Décision

⛔ **CHANGES REQUESTED.**

**Bloquant avant `done`** :
- **H1** — corriger la détection des classes `ZExtensible` (multi-lignes + modificateurs Dart 3 + `get extra`) ; **et** ajouter la fixture `prove_gates` correspondante (M1) — sans quoi la correction elle-même ne serait pas gardée par machine.
- **M1** — fixture propre pour `E_disk \ E_covered` (isolée du volet B), écrite **avec une en-tête enroulée**.
- **M3** — dériver `R_wired` du seul littéral `kRegistrars`.
- **M2** — **mitigation obligatoire** dans le périmètre : avertissement dartdoc explicite sur `FirebaseZRepositoryImpl.fromRegistry` (« perd `extra` — DW-ES14-1 »). Le **correctif de fond** (`zcrud_generator`) est **légitimement reporté** : hors périmètre, story dédiée à ouvrir au backlog **avant** tout câblage du store.

**LOW** (L1/L2/L3) : optionnels ; L2 et L3 sont des one-liners, à prendre si le contexte le permet.

**Après correction de H1/M1/M3 + mitigation M2, la story est bonne.** Le reste du livrable est solide, et la discipline « ne jamais faire confiance à un vert » a **déjà payé quatre fois** dans cet epic — elle vient de payer une cinquième.

---

## Disposition orchestrateur (2026-07-12)

Verdict initial : **CHANGES REQUESTED** (1 HIGH · 3 MEDIUM · 3 LOW).

> ⚠️ **L'agent de remédiation a PLANTÉ** (`API Error: Connection closed mid-response`) après 84 appels d'outils, sans rendre de rapport. Conformément à CLAUDE.md, **aucune confiance n'a été accordée à son état déclaré** : l'orchestrateur a **vérifié l'intégralité du résultat sur disque** et **rejoué lui-même les preuves**. Diagnostic : l'agent est mort **en rédigeant son rapport final**, pas en pleine édition — l'arbre était cohérent et complet.

### Traitement des findings (vérifié sur disque par l'orchestrateur)

- **H1 (HIGH) — le contrôle de couverture était aveugle → CORRIGÉ STRUCTURELLEMENT.** L'ancienne regex ligne-à-ligne (`_classWithExtensible`) est **supprimée** ; `scripts/ci/gate_reserved_keys.dart` parse désormais le Dart via **`package:analyzer` (AST)** — `ClassDeclaration` + `withClause`/`implementsClause`/`extendsClause` —, robuste à **toutes** les formes légales, aux commentaires et au retour à la ligne. Le rustinage de regex a été **explicitement refusé** : un scan textuel « amélioré » reste fragile par nature.
  **PREUVE REJOUÉE PAR L'ORCHESTRATEUR** (injection des 3 formes qui échappaient) — le gate devient **ROUGE** sur chacune, et **les deux volets tirent** (syntaxique **et** couverture « faux vert par omission ») :
  - en-tête **enroulée** par `dart format` (la forme que le formateur du projet produit lui-même) → ROUGE ;
  - `final class` → ROUGE ; `base class` → ROUGE.
  Nettoyage vérifié : arbre propre, gate re-vert.
- **M1 (cause racine de H1) — la règle (3) `E_disk \ E_covered` n'avait AUCUNE fixture propre → CORRIGÉ.** C'est précisément ce qui avait masqué H1 (`26 OK / 0 FAIL` sans qu'aucun cas ne l'exerce isolément). `prove_gates` passe de **26 → 32 cas**, avec fixtures dédiées.
- **M3 — `R_wired` dérivé d'une mention textuelle → CORRIGÉ.** Il est désormais dérivé du **parse AST réel** de `kRegistrars`/`kProbeBodies`/`kManualProbes` (et non de ce que le gate « croyait lire ») ; commentaires dépouillés.
- **M2 / DW-ES14-1 — mitigation appliquée, correctif de fond HORS PÉRIMÈTRE.** `registry.decode` **détruit** `extra` (prouvé par la revue : `zz_cle_metier_app` → `null` après round-trip) car le registrar généré câble `fromMap: _$ZXxxFromMap`. **Latent** : `FirebaseZRepositoryImpl.fromRegistry` a **zéro appelant** ⇒ aucune perte de données aujourd'hui, mais destructif **dès la première adoption**. Mitigation à coût nul : **avertissement `⚠️⚠️ DW-ES14-1` en tête de `fromRegistry` lui-même** (« CETTE VOIE DÉTRUIT `extra` (AD-4). NE PAS CÂBLER UN STORE DESSUS ») — car une dette consignée dans un fichier de harnais que personne n'ouvrira **n'est pas consignée**. **Story dédiée à ouvrir avant tout câblage du store (ES-3, couche data)** ; correctif = `zcrud_generator` (émettre `fromMap: ZXxx.fromMap`).
- **L1, L2, L3 → CORRIGÉS.** Notamment **L2** : `ZCRUD_SKIP_WEB_GATE=1` (et l'absence de Node) sont désormais **REFUSÉS sous `CI=true`** — un skip est un secours de poste de dev, jamais un échappatoire de CI.

### Vérif verte finale (rejouée par l'orchestrateur, agent planté ⇒ zéro confiance accordée)

`melos run analyze` repo-wide SUCCESS · `melos run verify` repo-wide **RC=0** · **`prove_gates` 32 OK / 0 FAIL** (26 → 32) · `gate:reserved-keys` vert sur l'arbre réel · kernel **108** VM / **98** JS · flashcard **189** · core **911** · firestore **90** · mindmap **110** · `melos list` **15** · `graph_proof` ACYCLIQUE OK / CORE OUT=0 OK · arbre git **propre** (aucune fixture ni sonde résiduelle).

**Conclusion : story ES-1.4 → `done`.**

### Le motif de l'epic ES-1 — « le filet existait, il n'était pas accroché » (5 fois)

| # | Étage | Le filet existait… | …mais |
|---|---|---|---|
| 1 | **Entités** (H1/H2, ES-1.3) | `ZSyncMeta.reservedKeys` était défini | 2 entités sur 4 ne le consommaient pas — **sous 1193 tests verts** |
| 2 | **Règle** (M5, ES-1.3) | AD-19.1 était écrite | **aucune machine ne la vérifiait** |
| 3 | **CI** (ES-1.4) | `gate:web` était écrit et prouvé localement | **jamais invoqué dans `ci.yml`** (qui énumérait les gates au lieu d'appeler `verify`) — et pas de Node |
| 4 | **Spec** (ES-1.4) | AD-19.1.c était figée et « exécutoire » | `registry.decode` **ne peuple pas `extra`** ⇒ le gate aurait été **vacuellement vert** |
| 5 | **Le gate lui-même** (H1, ES-1.4) | le contrôle de couverture existait | **regex aveugle** à 3 formes légales, dont celle que `dart format` produit — *le gate qui impose « accrochez le filet » avait son propre filet décroché* |

**Enseignement opératoire, désormais non négociable** : *un filet qu'on n'a pas vu échouer n'est pas un filet.* Chaque gate de cet epic a été validé **par injection de régression rejouée par l'orchestrateur**, jamais sur la foi d'un rapport. Corollaire structurel : `ci.yml` appelle désormais un **step unique `melos run verify`**, rendant la dérive « gate dans `verify` mais absent de la CI » **impossible par construction**.
