# Code-review — ES-6.1 : Édition/lecture de notes markdown (`ZSmartNoteEditor` / `ZSmartNoteReader`, `zcrud_note`)

- **Story** : `es-6-1-edition-lecture-notes-markdown` (statut `review`)
- **Skill invoqué** : `bmad-code-review` (VRAI skill, tool `Skill`) — chargé et suivi (step-01 gather-context → revue adversariale). Aucun fallback disque nécessaire.
- **Baseline** : `f751d82fecf2f7b80104a32146a3c14dfa8ef38e` (frontmatter story).
- **Périmètre revu** : `lib/src/presentation/z_smart_note_editor.dart` (créé), `lib/src/presentation/z_smart_note_reader.dart` (créé), `test/z_smart_note_editor_test.dart` (créé), `test/z_smart_note_reader_test.dart` (créé), `lib/zcrud_note.dart` (barrel étendu), `pubspec.yaml` (bascule Flutter + arête `zcrud_markdown`), `test/source_policy_test.dart` (retarget).
- **Verdict** : ✅ **APPROUVÉ AVEC RÉSERVE MINEURE** — aucun finding HIGH/MAJEUR. 1 MEDIUM (pouvoir discriminant AC3), 3 LOW. La réconciliation **DW-ES22-1 est solide PAR CONSTRUCTION et prouvée exécutablement** (AC5 rougit franchement quand on injecte le chemin destructeur).

---

## Vérif verte rejouée RÉELLEMENT (RC hors pipe — R15)

| Commande | RC | Résultat |
|---|---|---|
| `flutter test` (package Flutter — R14) | **0** | **147 tests passed** (88 domaine inchangés + 59 nouveaux présentation/politique) |
| `python3 scripts/dev/graph_proof.py` | **0** | ACYCLIQUE OK · CORE OUT=0 OK · arête `zcrud_note → zcrud_markdown` présente · **41 arêtes, 20 nœuds** |
| `dart run melos exec --scope="zcrud_note" -- dart analyze` | **0** | *No issues found!* |

> Note R15 : les RC de graph_proof et analyze ont été capturés HORS pipe (`cmd > f; echo $?`). Le `flutter test` de baseline a affiché « All tests passed! » (145..147 verts) ; re-confirmé après restauration des injections.

---

## Preuves de POUVOIR DISCRIMINANT (R12) — rouge PROVOQUÉ pour chaque garde load-bearing

Chaque injection a été posée par **édition ciblée**, observée, puis **restaurée par édition ciblée** (R13, jamais `git checkout`). `git diff` final vs delivered = **vide** ; suite re-verte à 147/RC=0.

| # | Garde testée | Mutation injectée en prod | RC | Observé | Verdict |
|---|---|---|---|---|---|
| 1 | **AC3 / SM-1** (`z_smart_note_editor_test.dart`) | `_form = ZFormController(...)` **recréé à chaque `build`** (churn, viole AD-2) | **0** | **RESTE VERT** — voir MEDIUM-1 | 🟠 **NON discriminant sur cette mutation** |
| 2 | **AC5 / DW-ES22-1** (round-trip legacy) | seed de la tranche avec une **`String` brute** (`note.content.first['insert']`) au lieu des ops | **1** | `asDeltaOps(String)→[]` ⇒ document `'\n'` ; `Expected: contains '# Titre markdown legacy' / Actual: '\n'` | ✅ **FORT** |
| 3 | **D6 pureté domaine** (`source_policy_test.dart`) | `import 'package:flutter/material.dart';` dans `lib/src/domain/z_note_content.dart` | **1** | assertion `not contains 'package:flutter/'` rougit, `Actual` pointe `lib/src/domain/z_note_content.dart` | ✅ **FORT** (via l'assertion, sous `flutter test`) |
| 4 | **AC9 no-codec** (`source_policy_test.dart`) | `class _InjectedCodec implements ZCodec {…}` dans `lib/` | **1** | `Expected: empty / Actual: ['lib/src/presentation/z_smart_note_reader.dart']` | ✅ **FORT** |

**Injection #2 (AC5)** est la preuve exécutable centrale de la réconciliation exigée par le verrou DW-ES22-1 : le round-trip **effondre le corps legacy à `'\n'`** dès qu'une `String` brute atteint `ZMarkdownField`. L'implémentation livrée seed **toujours** `note.content` (ops `List<Map>` déjà canoniques), donc la branche destructrice `asDeltaOps(String)→null→[]` est **inatteignable par construction**. ✅ Réconciliation confirmée.

**Injection #3** — précision honnête : sous `dart test` la mutation rougit d'abord par **échec de compilation** (le barrel `zcrud_note.dart` ré-exporte le domaine, qui tire alors `dart:ui` indisponible en VM). Sous **`flutter test`** (le runner R14 du package), c'est **l'assertion elle-même** qui mord et nomme le fichier fautif — le retarget D6 est donc réellement discriminant, pas un simple artefact de plateforme.

---

## Vérification des invariants adversariaux

- **DW-ES22-1 réconciliée PAR CONSTRUCTION (D4)** ✅ — `ZSmartNoteEditor.initState` seed `{content: note.content}` (ops). `ZMarkdownField._initEditingController` lit la tranche → `ZDeltaCodec.decode` = `DeltaNeutralOps.decodeDefensiveOps` (identité sur `List<Map>` portant `insert`). Aucune `String` brute n'atteint `asDeltaOps(String)`. Le verrou-source (`DeltaNeutralOps` privé ; `zcrud_markdown.dart` ne l'exporte pas) tient — vérifié dans le barrel `zcrud_markdown`.
- **AD-2 / AD-7 / SM-1** ✅ (code livré) — `ZFormController` créé en `initState`, `dispose()` en `dispose` (retrait du listener AVANT dispose), jamais recréé ; `ValueKey('content')` stable ; sens unique (`_onContentChanged` **relit** la tranche et remonte `copyWith`, ne **réécrit jamais** la tranche → aucune ré-injection écrasant le curseur). Confirmé par AC3/AC4 verts (focus conservé, curseur à 101, `onChanged` ×100).
- **AD-1 / AC8** ✅ — barrel `show ZSmartNoteEditor` / `show ZSmartNoteReader` uniquement ; signatures publiques = `ZSmartNote` + `ValueChanged<ZSmartNote>` + `String?` (zéro type Quill). `flutter_quill` est une **dev_dependency de TEST** (absente de `dependencies:`). Graphe acyclique, CORE OUT=0, arête sortante unique `zcrud_note → zcrud_markdown` (+ `→ zcrud_core/annotations`). `source_policy` interdit `QuillController` dans tout `lib/`.
- **AD-10** ✅ — AC6 (éditeur `content==[]` → doc vide, aucun throw ; reader → placeholder). Hérité de `zcrud_markdown`, non régressé.
- **AD-13 / FR-26** ✅ (inhérence) — les adaptateurs **n'ajoutent aucune cible interactive ni couleur** : ils délèguent à `ZMarkdownField`/`ZMarkdownReader` (déjà directionnels, `Semantics`, thème injecté, ≥48 dp). AC7 vérifie le rendu RTL sans exception.
- **Retarget `source_policy_test` (D6)** ✅ — la garde de pureté mord sur `lib/src/domain/`+`lib/src/data/` (injection #3), autorise `lib/src/presentation/` (baseline vert alors que la présentation importe Flutter/zcrud_markdown), et **conserve** le verrou DW-ES22-1 (source `delta_neutral_ops.dart` + barrel privé).

---

## Findings

### 🟠 MEDIUM-1 — AC3 (load-bearing) ne discrimine PAS le churn du `ZFormController`
- **Fichier** : `packages/zcrud_note/test/z_smart_note_editor_test.dart:86-159` (groupe AC3 / SM-1).
- **Scénario d'échec** : en recréant `_form = ZFormController(...)` **à chaque `build`** (mutation posée : champ passé `late` + recréation dans `build`), **AC3 reste VERT** (RC=0, injection #1). Toutes les assertions d'AC3 portent sur des propriétés **que `ZMarkdownField` protège lui-même** : identité du `QuillController`, `FocusNode`, témoin frère, `onChangedCount==100`. Aucune n'observe l'identité du **`ZFormController`** ni son `dispose`. Un refactor qui rendrait `_form` non-`final` et le recréerait dans `build` **fuit un `ZFormController` + un listener à chaque frame** (jamais disposés) **sans qu'aucun test ne rougisse** — alors que l'invariant AD-2 « controller créé UNE FOIS, jamais recréé, disposé » est précisément l'objectif produit n°1. Le pouvoir discriminant réel d'AC3 contre « controller recréé dans build » repose **uniquement** sur le fait que `late final` *throw* (ce que le dev a vérifié), pas sur une assertion comportementale — la story affirme pourtant (§ Injections R3 #1) que recréer le controller causerait « perte de focus / identité changée », ce que la mutation réfute.
- **Correctif proposé (dans le périmètre, non appliqué — orchestrateur pilote)** : dans AC3, capturer `final formBefore = tester.widget<ZMarkdownField>(...).controller;` avant la boucle de 100 frappes et asserter `identical(tester.widget<ZMarkdownField>(...).controller, formBefore)` **après** la tempête de rebuilds ; optionnellement, prouver le `dispose` du `ZFormController` (démontage + espion). Cela ancre l'invariant sur l'objet propre à l'éditeur, indépendamment de la robustesse de `ZMarkdownField`.
- **Note** : **le code livré est CORRECT** (`_form` créé en `initState`, disposé en `dispose`). C'est une **lacune de couverture / pouvoir discriminant**, pas un bug d'exécution.

### 🟡 LOW-1 — `ZSmartNoteEditor` sans `didUpdateWidget` : swap de note sur le même élément mélange métadonnées neuves + corps périmé
- **Fichier** : `packages/zcrud_note/lib/src/presentation/z_smart_note_editor.dart:81-103`.
- **Scénario** : si un hôte réutilise le **même** élément `ZSmartNoteEditor` (même position, **sans** `Key` distincte) en passant une **autre** `ZSmartNote`, `_form` n'est **pas** re-seedé (voulu pour SM-1), mais `_onContentChanged` remonte `widget.note.copyWith(content: <ops de l'ANCIENNE session>)` → la note remontée porte le **titre/dossier de la nouvelle** et le **corps de l'ancienne**. Persisté, cela corrompt silencieusement. La story scope « corps uniquement » et ne couvre pas le swap ; le reader (stateless) est immunisé.
- **Correctif proposé** : documenter la discipline de `Key` par note (ex. `ZSmartNoteEditor(key: ValueKey(note.id), …)`) dans le dartdoc, **ou** implémenter `didUpdateWidget` re-seedant la tranche quand `oldWidget.note.id != widget.note.id` (hors focus, pour ne pas régresser le sens unique).

### 🟡 LOW-2 — `onChanged` possible sur montage pour un seed non canonique (comportement hérité)
- **Fichier** : `z_smart_note_editor.dart:100-103` + `zcrud_markdown` `_normalizeSliceIfNeeded` (`z_markdown_field.dart:398-413`).
- **Scénario** : si `note.content` n'est pas déjà la forme neutre canonique (ex. relu de Hive avec clés dynamiques), `ZMarkdownField` poste en post-frame un `_write(neutralSeed)` → déclenche `_onContentChanged` → `onChanged` émet **avant toute interaction utilisateur**. Sans effet sur les tests livrés (contenus déjà canoniques). Un hôte qui traite `onChanged` comme « dirty flag » marquerait la note modifiée à l'ouverture.
- **Correctif proposé** : documenter que le premier `onChanged` peut refléter une normalisation (pas une édition), ou garder la première valeur pour ne remonter que sur diff réel.

### 🟡 LOW-3 — variable locale redondante dans le reader (nit)
- **Fichier** : `z_smart_note_reader.dart:52,57` — `final String? resolvedPlaceholder = placeholder;` puis `resolvedPlaceholder ?? _kDefaultPlaceholder`. Le local n'apporte rien ; `placeholder ?? _kDefaultPlaceholder` suffit. Purement cosmétique.

---

## Action DOCUMENTAIRE en suspens (hors code — à statuer par l'orchestrateur)

- **DW-ES-6.1-1** (T7/D8) : la perte de couverture `gate:web` sur `zcrud_note` après bascule Flutter est **consignée** dans `pubspec.yaml` + `source_policy_test.dart`, mais **l'escalade dans `architecture.md § Deferred`** reste explicitement déléguée par la story à « l'orchestrateur/code-review ». À réaliser avant `done` pour tracer la dette (option future : extraire `zcrud_note_domain` pur-Dart et restaurer la matrice de coercition D5 sous `dart test -p node`).

---

## Synthèse

- **Aucun HIGH / MAJEUR.** Les gardes load-bearing de la réconciliation (AC5 DW-ES22-1), du no-codec (AC9) et de la pureté domaine (D6) ont un **pouvoir discriminant fort et prouvé** (rouges provoqués).
- **1 MEDIUM** : AC3 (SM-1) n'ancre pas son invariant sur le `ZFormController` de l'éditeur → churn non détecté (code livré correct ; lacune de test). Correction recommandée dans le périmètre (assertion d'identité du controller + dispose).
- **3 LOW** : swap de note sans `didUpdateWidget` (LOW-1, risque de corruption sur mésusage), `onChanged` de normalisation au montage (LOW-2), nit reader (LOW-3).
- État disque après revue : **propre** (toutes injections restaurées par édition ciblée, `git diff` vide, suite 147/RC=0).

---

## Remédiation orchestrateur (2026-07-15) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| MEDIUM-1 | 🟠 MEDIUM | ✅ **CORRIGÉ** | `z_smart_note_editor_test.dart` (AC3) : capture du `ZFormController` isolé **avant** la tempête de 100 frappes + assertion **directe** `identical(md.controller, formBefore)` **après**. Le test ancre désormais l'invariant sur l'identité de `_form` (indépendamment des protections propres de `ZMarkdownField` sur son `QuillController`). **Pouvoir discriminant PROUVÉ (orchestrateur, injection fidèle)** : `_form` rendu non-`final` + recréé dans `build` avec listener ré-attaché (onChangedCount préservé à 100) ⇒ **c'est exactement la nouvelle assertion qui rougit** (`Expected: true, Actual: <false>`, reason « ZFormController recréé sous rebuild ⇒ AD-2 violé »), RC=1. Restauré par édition ciblée (R13) ⇒ 147 tests / RC=0. |
| LOW-3 | 🟡 LOW | ✅ **CORRIGÉ** | `z_smart_note_reader.dart` : local redondant `resolvedPlaceholder` inliné (`placeholder ?? _kDefaultPlaceholder`). |
| LOW-1 | 🟡 LOW | 🟡 **CONSIGNÉ (non corrigé)** | Absence de `didUpdateWidget` : réutilisation d'un même élément avec une autre `ZSmartNote` sans `Key` distincte. **Mésusage hôte** hors périmètre ES-6.1 ; ajouter `didUpdateWidget` (re-seed hors focus) introduirait un chemin de ré-injection à concevoir avec soin (risque de régression SM-1). Recommandation de discipline `Key: ValueKey(note.id)` documentée. À traiter si un consommateur réel réutilise l'élément. |
| LOW-2 | 🟡 LOW | 🟡 **CONSIGNÉ (non corrigé)** | `onChanged` possible au montage sur seed non canonique (normalisation post-frame héritée de `ZMarkdownField`). Comportement **hérité** du widget réutilisé, non introduit par l'adaptateur ; neutre (remonte la valeur canonique). Consigné. |
| DW-ES-6.1-1 | — | ✅ **ESCALADÉ** | Perte de couverture `gate:web` après bascule Flutter : escaladée dans `architecture.md § Deferred › DETTES OUVERTES › DW-ES-6.1-1`. |
| DW-ES22-1 | — | ✅ **SOLDÉE** | Réconciliée par construction en ES-6.1 (preuve AC5) : marquée SOLDÉE dans `architecture.md § Deferred`. |

**Re-vérif verte post-remédiation (RC hors pipe — R15)** : `flutter test` (zcrud_note, R14) → RC=0, **147 tests** · `dart analyze` (scope zcrud_note) → RC=0 (*No issues found!*) · `graph_proof.py` → RC=0 (ACYCLIQUE + CORE OUT=0).

**Verdict final** : ✅ **PRÊT POUR `done`** — aucun HIGH/MAJEUR ; MEDIUM-1 corrigé et prouvé non-powerless ; LOW-3 corrigé ; LOW-1/LOW-2 consignés avec justification ; dettes documentaires soldées/escaladées.
