# Code-review ADVERSARIALE — Story ES-9.2 (Examens & rappels UI)

- **Skill invoqué** : `bmad-code-review` (tool `Skill`, réel). Étapes step-01/02 pilotées en mode subagent non-interactif ; baseline diff = `baseline_commit` de la story (`5271ac1`).
- **Périmètre** : `packages/zcrud_study/` uniquement. `zcrud_exam`/`zcrud_core`/`zcrud_study_kernel` CONSOMMÉS (lecture seule). Toute injection R3 restaurée par édition ciblée (R13) — état disque final = origine.
- **Verdict** : **APPROVED — story reste VERTE**. Aucun finding HIGH/MAJEUR/MEDIUM. 3 LOW/nits (aucun bloquant, aucune correction obligatoire).

---

## Preuves rejouées RÉELLEMENT sur disque (R3, RC hors pipe R15, runner `flutter test` R14)

### Baseline vert
- `flutter test` (5 fichiers ES-9.2) → **25/25 PASS**.
- `python3 scripts/dev/graph_proof.py` → **total arêtes = 44**, **noeuds = 20**, **ACYCLIQUE OK**, **CORE OUT=0 OK**, arête `zcrud_study → zcrud_exam` présente (delta +1 exact vs baseline 43).
- `dart run melos list` → **20** packages.
- `dart run melos run verify` → **RC=0**. Gates : `gate:secrets OK`, `gate:reserved-keys OK` (volets A+B), `gate:web OK` (`zcrud_exam` dans la cible pur-Dart `dart test -p node` ⇒ confirmé Flutter-free), `gate:reflectable OK`, `gate:codegen-distribution OK` (`zcrud_exam` a un `part`, 0 gitignoré), `verify:serialization OK`.
- `git diff packages/zcrud_exam/pubspec.yaml` **VIDE** → `zcrud_exam` reste PUR-DART (AC8/DW-ES92-1 confirmé).
- `flutter analyze` (4 fichiers ES-9.2) → **No issues found**.

### Pouvoir discriminant VÉRIFIÉ par injection (mutation → RED → restauration) — R12/R3
Le défaut dominant (« artefact validé sur EXISTENCE, jamais sur POUVOIR ») a été traqué en NEUTRALISANT chaque ligne porteuse. **Toutes ont rougi**, prouvant des tests non-powerless :

| Injection (dans `zcrud_study` seul) | AC/garde | Résultat | Restauré |
|---|---|---|---|
| `_kMinTapTarget: 48→20` | AC7 ≥48dp (garde `ConstrainedBox` count) | **RED** (`ownBoxes.length>=5` échoue) | ✅ |
| `..sort()` sur `_thresholds.value` | AC3 ordre + AC1 préservation | **RED** (3 tests) | ✅ |
| adaptateur `isApproaching(now) => true` | AC4 sélection via ADAPTATEUR (R20) | **RED** (6 tests) | ✅ |
| `DateTime.now()` injecté dans `_recompute` | AC5 scan no-scheduler | **RED** (scan tokenisé) | ✅ |
| `controller: TextEditingController(...)` recréé dans `build` | AC6 identité owned/injected (SM-1) | **RED** (2 tests) | ✅ |

**Conclusion axe 1/2/3/4** : les tests load-bearing ont un pouvoir discriminant RÉEL. En particulier :
- **Axe 2 (R26)** : AC3 asserte l'égalité EXACTE `[7,1]`/`[3,3,10]` (un `sort`/`toSet` rougit) ; AC4 asserte la SÉLECTION+ORDRE exacts `['soon','later']` + décomptes `[2,4]` (pas « liste non vide »).
- **Axe 3 (R20)** : l'injection dans `_ZExamApproaching.isApproaching` (et non dans le kernel) fait rougir AC4 ⇒ le test ancre bien sur l'ADAPTATEUR ES-9.2, PAS en boîte noire sur `aggregateDailyStudyTasks`. **Pas de powerless-par-délégation.**
- **Axe 4 (M-1)** : chaque garde (id==null, ZReminderTime typé, anti-scheduler, ≥48dp, controller stable) est verrouillée par un test à rouge provoqué. La garde anti-scheduler N'est PAS un scan de commentaire : `_stripComments` dépouille les dartdoc (qui citent `DateTime.now()` verbatim) et le méta-test R2 prouve que les regex mordent sur l'interdit et épargnent l'autorisé (`addPostFrameCallback` non capturé).

### Correction I7 signalée par le dev — VÉRIFIÉE HONNÊTE
Le dev a signalé que `getSize` seul était powerless (Material `tapTargetSize.padded` impose 48dp indépendamment du code) et a ré-ancré sur le **compte de `ConstrainedBox(min 48/48)`**. Rejoué : `_kMinTapTarget→20` fait bien rougir la garde `ownBoxes.length>=5` (les 5 boîtes propres tombent sous seuil). **La correction est réelle et discriminante.** Le diagnostic n'a pas été masqué (M-2 respecté).

---

## Findings

### LOW-1 — Garde AC5 « aucune dépendance notification au pubspec » partiellement couverte
`test/z_exam_ui_no_scheduler_test.dart` scanne les 3 fichiers source (symboles), et `graph_proof` ne compte que les arêtes internes `zcrud_*` (20 noeuds). Ni l'un ni l'autre n'attraperait un `flutter_local_notifications` ajouté au `pubspec.yaml` mais importé dans un 4ᵉ fichier hors liste. **État réel = propre** (le pubspec n'ajoute QUE `zcrud_exam`, vérifié), donc aucun défaut présent — c'est une lacune de complétude du filet, pas un bug. L'injection R3-I5b (nommer le symbole dans un des 3 fichiers) EST bien capturée.
*Correctif possible (non obligatoire)* : ajouter au test un assert lisant `pubspec.yaml` et vérifiant l'absence de la liste `_schedulerSymbols` dans les `dependencies`.

### LOW-2 — Assertions `expectTap(getSize>=48)` résiduelles (powerless, déjà divulguées)
`z_exam_editor_a11y_test.dart:49-52` conserve 4 `expectTap` sur `getSize` que le dev a lui-même documentés comme powerless (Material impose 48dp). Elles sont inoffensives (la garde réelle est le compte de `ConstrainedBox`), mais ajoutent une fausse impression de couverture. *Nit* : les retirer ou les commenter « belt-and-suspenders » pour éviter qu'un mainteneur futur croie qu'elles portent la garde. Non bloquant.

### LOW-3 — `didUpdateWidget` : recompute sur `identical(exams)` ⇒ staleness si liste mutée en place
`z_exam_reminders_section.dart:109` déclenche le recalcul si `!identical(oldWidget.exams, widget.exams)`. Un parent qui mute la MÊME instance de liste (même référence) et re-passe le widget ne recalculera pas les approchants (rappels périmés). Patron acceptable (le contrat attend une nouvelle liste), aligné sur les précédents ; robustesse mineure. Non bloquant.

### Nit — Assertion de TYPE statique AC2 quasi-vacue
`z_exam_editor_test.dart:142` (`final ZReminderTime? t = exam.reminderTime;`) est toujours vraie par construction (`ZExam.reminderTime` est typé). Le pouvoir réel d'AC2 vient des assertions de VALEUR (`ZReminderTime(8,5)`, `'08:05'`, round-trip) qui, elles, sont discriminantes. Ligne redondante, inoffensive.

---

## Observations hors périmètre ES-9.2 (pour l'orchestrateur — PAS des findings)
- L'arbre de travail porte des fichiers untracked hors File List d'ES-9.2 (`lib/src/domain/`, `test/z_ai_ports_*`, `test/z_education_quota_info_test.dart`, `test/z_flashcard_provenance_registry_test.dart`) : ils relèvent d'**ES-9.1 (done)**, pas de cette story. Aucune modification de `zcrud_exam`/`zcrud_core`/`zcrud_study_kernel` par ES-9.2 (CONSOMMÉS).
- Dettes anticipées DW-ES92-1..4 confirmées telles quelles (placement UI dans `zcrud_study`, persistance déférée ES-3, notif OS app-side, chaîne sérielle). Aucune dette nouvelle.

## Bilan
- **HIGH/MAJEUR** : 0
- **MEDIUM** : 0
- **LOW/nit** : 3 (+1 nit) — tous optionnels, aucun ne dégrade la vérité verte ni le pouvoir discriminant.
- **Décisions AD** vérifiées : AD-1 (arête +1 acyclique, CORE OUT=0), AD-2/15 (Flutter-native, controller owned/injected, SM-1), AD-13 (≥48dp/Semantics/directionnel/ListView.builder), AD-14 (id==null), AD-26 (seam OS, now injecté), AD-28 (ZReminderTime typé).

**Recommandation : passage à `done` autorisé** (findings LOW consignés, aucune correction obligatoire ; story verte).

---

## Remédiation orchestrateur (2026-07-16) — statuts

| Finding | Sévérité | Statut | Détail |
|---|---|---|---|
| LOW-1 (scan notif pubspec partiel) | 🟡 LOW | 🟡 **CONSIGNÉ** | La garde AC5 (« pas de dépendance notif ») n'attraperait pas un plugin ajouté au pubspec mais importé dans un 4ᵉ fichier. **État réel propre** (seul `zcrud_exam` ajouté, graph_proof=44). Élargissement optionnel (asserter l'absence de symboles notif dans pubspec.yaml). Consigné. |
| LOW-2 (asserts getSize résiduels powerless) | 🟡 LOW | 🟡 **CONSIGNÉ** | Des `expect(getSize>=48)` résiduels restent (powerless car Material impose 48dp) — **déjà divulgués par le dev**, inoffensifs : la garde RÉELLE et discriminante est le compte de `ConstrainedBox(min 48/48)` (prouvé RED sous `_kMinTapTarget→20`). Nit de clarté ; consigné (la garde load-bearing existe et mord). |
| LOW-3 (didUpdateWidget staleness) | 🟡 LOW | 🟡 **CONSIGNÉ** | Recompute sur `identical(exams)` → staleness si la liste est mutée EN PLACE. Patron acceptable (les listes sont immuables par convention) ; robustesse mineure. Consigné. |
| Nit (AC2 type statique quasi-vacu) | 🟡 nit | 🟡 **CONSIGNÉ** | L'assertion de type statique d'AC2 est quasi-vacuelle ; le pouvoir discriminant vient des VALEURS (`08:05`/round-trip AD-28), bien testées. Consigné. |

**Vérif verte (RC hors pipe — R15)** : `flutter test` zcrud_study (R14) → RC=0, **140 tests** · `melos run verify` → RC=0 (gate:secrets/reserved-keys/web OK) · graph_proof RC=0 (44 arêtes, ACYCLIQUE, CORE OUT=0) · analyze RC=0. Arbre propre après les injections du reviewer (R13).

**Verdict final** : ✅ **PRÊT POUR `done`** — 0 finding bloquant ; 4 LOW/nit consignés (garde load-bearing verrouillée et prouvée pour chaque AC).
