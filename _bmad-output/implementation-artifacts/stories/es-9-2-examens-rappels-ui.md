---
baseline_commit: 5271ac1ff3e7124324b0367e4570437ceed41d28
---

# Story ES-9.2 : Examens & rappels (UI) — `ZExamEditor` + section rappels approchants alimentant la vue quotidienne

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **utilisateur**,
I want **créer/consulter des examens (`ZExam` daté + rappels typés `ZReminderTime`) et voir les rappels approchants**,
so that **préparer mes examens, les rappels approchants alimentant ma vue quotidienne (`aggregateDailyStudyTasks`, FR-S10) — la planification de notification OS restant un seam app, le domaine ne calculant que `isApproaching(now)` déterministe.**

## Contexte & décisions verrouillées (à NE PAS ré-arbitrer)

Cette story est la **2ᵉ de la chaîne sérielle ES-9.1 (done) → 9.2 → 9.3 → 9.4** qui écrivent TOUTES `zcrud_study` : **une seule en vol**, jamais en parallèle (epics § ES-9 ; sprint-status `es-9-2-… [SÉQ — zcrud_exam/zcrud_study]`). Aucune parallélisation. ES-9.1 est `done` ; ES-9.2 la suit directement.

### Périmètre validé SUR DISQUE (ne rien inventer)

- **`ZExam` EXISTE** — `packages/zcrud_exam/lib/src/domain/z_exam.dart` (livré ES-2.6, FR-S9). Entité `ZEntity` + `ZExtensible`, `@ZcrudModel(kind:'exam')`. Champs : `id?` (opaque, `null` = éphémère, AD-14), `folderId` (clé NEUTRE `String`), `title`, `date` (`DateTime?` ISO-8601, clé MÉTIER), `reminderEnabled` (`bool`), `reminderDaysBefore` (`List<int>`, **ordre préservé**), `reminderTime` (**`ZReminderTime?` TYPÉ, CANAL HORS-CODEGEN** `'HH:mm'`, PAS d'annotation `@ZcrudField` ⇒ **aucun `ZFieldSpec` généré** — la dartdoc `z_exam.dart:196-199` dit explicitement « L'éditeur d'examen (ES-9.2) ajoutera son champ heure **explicitement** »). Méthodes de proximité `daysUntil(now)` / `isPast(now)` / `isApproaching(now)` **PURES, TOTALES, DÉTERMINISTES, horloge `now` en PARAMÈTRE** (jamais `DateTime.now()`, prouvé machine `no_datetime_now_test.dart`).
- **`ZReminderTime` EXISTE** — `packages/zcrud_exam/lib/src/domain/z_reminder_time.dart`. Value-object PUR `{hour, minute}`, `parse(String?)` défensif TOTAL (`null`/hors-bornes ⇒ `null`, jamais throw, AD-10), `toHhmm()` → `'HH:mm'`. **Le TYPE dit le format** ⇒ aucune `String` `'HH:mm'` ambiguë ne flotte dans l'UI (AD-28). Exporté par le barrel `zcrud_exam`.
- **`aggregateDailyStudyTasks` EXISTE** — `packages/zcrud_study_kernel/lib/src/domain/aggregate_daily_study_tasks.dart` (livré ES-2.7, FR-S10). Signature : `List<ZDailyStudyTask> aggregateDailyStudyTasks({required int dueCount, required Iterable<ZApproachingExam> exams, required DateTime now})`. Consomme les examens via le **port NEUTRE** `ZApproachingExam` (`z_daily_study_task.dart`) — le kernel **ne dépend PAS de `zcrud_exam`** (AD-1). Filtre les approchants (`isApproaching(now)`), trie par (date croissante, index d'entrée), émet `[ZDueCardsTask?] + ZExamTask[]`. PURE/TOTALE.
- **`ZExam` ne fait PAS ENCORE `implements ZApproachingExam`** (grep : 0 occurrence). Le doc `z_daily_study_task.dart:30` dit : « le câblage `ZExam implements ZApproachingExam` (**ou un adaptateur**) est **additif, trivial et DÉFÉRÉ au consommateur** (**ES-9.2** / ES-5, D10) ». **ES-9.2 EST ce consommateur** : elle livre le câblage.
- **`zcrud_study` est le package de PRÉSENTATION Flutter** (`sdk: flutter` + `flutter_test`, runner **`flutter test`** R14). Il porte déjà `lib/src/presentation/` (ES-5/7/8) **et** `lib/src/domain/` (ES-9.1). Précédents DIRECTS de « widget de présentation composant un package DOMAINE » : **`ZStudyMindmapSection` (ES-7.1)** compose `zcrud_mindmap`, **`ZTagEditor` (ES-8.1)** compose `zcrud_study_kernel` — les deux vivent dans `zcrud_study/presentation`, **jamais** dans le package domaine composé.

### 🔴 ARBITRAGE STRUCTURANT — l'UI vit dans `zcrud_study/presentation`, PAS dans `zcrud_exam` (déviation JUSTIFIÉE du chemin littéral de l'epic)

Les métadonnées de l'epic nomment littéralement `packages/zcrud_exam/lib/src/presentation/z_exam_editor.dart`. **CE CHEMIN EST REJETÉ**, après vérif disque, au profit de **`packages/zcrud_study/lib/src/presentation/`**. Raisons NON-NÉGOCIABLES :

1. **`zcrud_exam` est PUR-DART aujourd'hui** (pubspec vérifié : deps = `zcrud_core` + `zcrud_annotations` UNIQUEMENT ; `dev_dependencies` = `test`/`build_runner` ; **AUCUN `flutter`/`flutter_test`** ; tests `dart test` ; **`gate:web` default-ON** `dart test -p node`). Y loger un widget Flutter **imposerait de le basculer Flutter** (ajout `sdk: flutter`), ce qui : (a) **casse `gate:web`** (`dart:ui`/Material introuvables en JS) ; (b) viole **NFR-S3** (« importer `zcrud_exam` seul n'ajoute pas de dép lourde ») ; (c) impose une **fenêtre R25 sérialisée** (bascule pubspec + `dart pub get` en solo) — coût et risque évitables.
2. **Précédent unanime** : TOUS les widgets de présentation qui composent un package domaine (`ZStudyMindmapSection` ES-7.1, `ZTagEditor` ES-8.1, `ZAnnotationToolbar` ES-8.2) vivent dans le package de PRÉSENTATION, jamais dans le domaine composé. L'architecture valorise la **pureté des packages domaine** (CORE OUT=0, « import X seul n'ajoute ni Flutter ni Firebase »).
3. **Coût graphe MINIMAL** : Option B = **1 seule arête acyclique** `zcrud_study → zcrud_exam` (44 arêtes). Option A (bascule) = arête `zcrud_exam → flutter` + perte `gate:web` + R25. Option B est strictement dominante.

⇒ **Décision : Option B.** `ZExamEditor` et la section rappels vivent dans `zcrud_study/lib/src/presentation/` ; `zcrud_exam` reste **INTOUCHÉ, pur-Dart** (consommé, jamais modifié). Le retro ES-8 (l.105) envisageait « si `zcrud_exam` est créé/basculé Flutter, appliquer R25 » — condition NON réalisée : `zcrud_exam` existe déjà pur-Dart, on ne le bascule PAS. Déviation tracée en **§ Findings/dettes (DW-ES92-1)**.

### 🔴 ARBITRAGE — le câblage `ZExam → ZApproachingExam` est un ADAPTATEUR dans `zcrud_study`, PAS un `implements` dans `zcrud_exam`

Le doc kernel sanctionne « `implements` **OU** adaptateur ». On choisit l'**adaptateur** (`class _ZExamApproaching implements ZApproachingExam` — ou fonction `zExamAsApproaching(ZExam)`), défini dans `zcrud_study` (qui importe DÉJÀ le kernel `ZApproachingExam` **et** importera `zcrud_exam` `ZExam`). Justification :

- **Zéro arête sur `zcrud_exam`** : un `implements` dans `zcrud_exam` ajouterait `zcrud_exam → zcrud_study_kernel` (le port vit au kernel) — arête que le pubspec `zcrud_exam` **diffère explicitement** (« l'arête sera déclarée quand un import réel l'exigera, ES-3.x »). L'adaptateur côté `zcrud_study` évite cette arête : `zcrud_exam` reste sur `core`/`annotations` seuls.
- L'adaptateur est un **forwarder trivial** (`isApproaching`/`daysUntil`/`date` délégués à la vraie méthode `ZExam`) — c'est LA ligne de prod PROPRE à ES-9.2 sur laquelle AC4 s'ancre (R20 : ne PAS re-tester `aggregateDailyStudyTasks`, code kernel déjà testé).

### Arête de graphe AJOUTÉE (AD-1) — mesurée sur disque

Baseline **43 arêtes / 20 nœuds** (mesuré aujourd'hui `python3 scripts/dev/graph_proof.py`, après ES-9.1). ES-9.2 ajoute **`zcrud_study → zcrud_exam`** (le pubspec `zcrud_study` ne le déclare pas encore — grep vérifié) ⇒ **44 arêtes, delta = +1 EXACTEMENT**, 20 nœuds inchangés. **ACYCLIQUE** (`zcrud_exam → core/annotations` seulement ; `zcrud_exam` ne dépend PAS de `zcrud_study` ⇒ aucun cycle). **CORE OUT=0 préservé**. AUCUNE autre arête (pas de gestionnaire d'état, pas de SDK notification/OS).

### Runner (R14) & fenêtre workspace (R25)

- **Runner : `flutter test`** sur `packages/zcrud_study` (package Flutter). `zcrud_exam` reste `dart test` (INTOUCHÉ). Ne JAMAIS lancer `dart test` sur `zcrud_study`.
- **R25** : l'ajout de la dépendance `zcrud_exam` **mute le workspace** (`dart pub get`/bootstrap). ES-9.2 étant **seule en vol** dans la chaîne, la fenêtre pub-get est naturellement sérialisée (aucun autre workstream `zcrud_study` actif).

## Acceptance Criteria

Chaque AC est **à pouvoir discriminant** (R12) : ancré sur la **ligne de prod PROPRE à ES-9.2** (R20/R24 — jamais un artefact adjacent stable, ni un libellé présent dans toutes les branches, ni du code CONSOMMÉ déjà testé), prouvé par une injection qui la neutralise (§ Injections R3). Toute garde de filtrage/transformation asserte la **PRÉSERVATION EXACTE** (résultat attendu byte-à-byte), jamais la seule absence d'anomalie ni « la liste est non vide » (R26). Une garde load-bearing NON exercée par un test committé est un **vœu** (leçon méta ES-9.1 M-1) : chaque garde ci-dessous est VERROUILLÉE par un test qui rougit sous neutralisation.

**AC1 — `ZExamEditor` adossé à `ZExam`, émission PRÉSERVANT EXACTEMENT la saisie, `id == null` (AD-14, R26)**
**Given** `ZExam`/`ZReminderTime` (FR-S9) et une saisie utilisateur (titre, date, rappels activés, seuils, heure)
**When** l'utilisateur valide l'éditeur
**Then**
- `ZExamEditor` émet, via `onSubmit(ZExam exam)`, un `ZExam` dont **CHAQUE champ saisi survit à l'identique** : `title` saisi, `date` choisie, `reminderEnabled`, `reminderDaysBefore` (ordre EXACT), `reminderTime` — **jamais un `ZExam` défaut/vide** ni un champ perdu ;
- l'`exam` émis a **`id == null`** (l'`id` est matérialisé au repository, ES-3 — **jamais** par le widget, AD-14) ;
- l'éditeur **compose** l'entité `ZExam` (construction/`copyWith`), il ne réimplémente NI sa (dé)sérialisation NI sa validation.
**Discriminant (R26)** — assertion de **préservation exacte** de l'`exam` émis (égalité `ZExam` de valeur sur TOUS les champs saisis, non-dégénérée : au moins un seuil, une heure non-`null`, un titre non-vide). Injection R3-I1 : l'éditeur émet un `ZExam()` par défaut (ou droppe `reminderDaysBefore`) ⇒ l'égalité de préservation RC=1. Injection R3-I1b : l'éditeur assigne un `id` non-`null` ⇒ l'assertion `id == null` RC=1. **PAS** « onSubmit est appelé » (vacue).

**AC2 — `reminderTime` TYPÉ `ZReminderTime`, jamais une `String` ambiguë ; round-trip persistance `'HH:mm'` (AD-28, R26)**
**Given** que l'heure de rappel doit rester TYPÉE (canal hors-codegen `'HH:mm'`)
**When** l'utilisateur saisit une heure (ex. 8 h 05) et valide
**Then**
- l'`exam` émis porte `reminderTime == ZReminderTime(hour: 8, minute: 5)` (un **`ZReminderTime`**, PAS une `String`) ; heure vidée ⇒ `reminderTime == null` (défensif, AD-10) ;
- le round-trip persistance est EXACT : `ZExam.fromMap(exam.toMap()).reminderTime == exam.reminderTime`, et `exam.toMap()[kReminderTimeKey] == '08:05'` (zéro-paddé, clé `reminder_time`) ;
- **aucune `String` `'HH:mm'` brute** n'est stockée dans l'état de l'éditeur comme source de vérité de l'heure (le TYPE porte le format).
**Discriminant (R26/AD-28)** — assertion sur le **TYPE statique** (`exam.reminderTime` est `ZReminderTime?`) **et** l'exactitude `08:05`. Injection R3-I2 : l'éditeur stocke/émet l'heure en `String` nue (ou perd le zéro-padding `'8:5'`) ⇒ l'assertion de type/valeur RC=1. Ancre sur la ligne d'éditeur, PAS sur `ZReminderTime.parse` (testé dans `zcrud_exam`, R20).

**AC3 — `reminderDaysBefore` : PRÉSERVATION EXACTE de l'ordre et des doublons de seuils (R26)**
**Given** une saisie de seuils de rappel (ex. `[7, 1]`, ou `[3, 3, 10]` avec répétition)
**When** l'utilisateur valide
**Then** l'`exam` émis porte `reminderDaysBefore` **byte-à-byte identique à la saisie** — **ordre préservé**, **aucun tri implicite, aucune dédup silencieuse, aucune perte** (la sémantique `ZExam` est ordre-sensible : `==` et `toMap` réémettent dans l'ordre).
**Discriminant (R26 — sur-purge/normalisation)** — assertion `emitted.reminderDaysBefore == [7, 1]` (EXACT, pas `isNotEmpty` ni `contains(7)`). Injection R3-I3 : l'éditeur `..sort()` ou `.toSet().toList()` les seuils ⇒ pour `[7,1]` l'assertion attend `[7,1]` mais obtient `[1,7]` (ou `[3,10]` après dédup) ⇒ RC=1. Prouver avec un cas **non-trié + à doublon** (état dégénéré exclu).

**AC4 — Rappels approchants alimentant `aggregateDailyStudyTasks` via l'ADAPTATEUR `ZApproachingExam` (FR-S10, R20/R26)**
**Given** un ensemble de `ZExam` RÉELS (mix : approchants, passés, `reminderEnabled=false`, `date=null`) et une horloge `now` INJECTÉE
**When** on les adapte via l'adaptateur d'ES-9.2 (`_ZExamApproaching`/`zExamAsApproaching`) et on les passe à `aggregateDailyStudyTasks(dueCount:, exams:, now:)`
**Then** la liste de `ZExamTask` produite contient **EXACTEMENT les examens approchants**, **triés par date croissante**, les passés / rappels-off / `date==null`-non-approchants **écartés** — la **préservation exacte** de la sélection ET de l'ordre est assérée (R26), pas « la liste est non vide » ; chaque `ZExamTask.daysUntil` reflète `exam.daysUntil(now)` réel.
**Discriminant (R20 + R26)** — l'AC s'ancre sur l'**ADAPTATEUR** (ligne de prod ES-9.2), PAS sur `aggregateDailyStudyTasks` (kernel, déjà testé — le re-tester en boîte noire serait POWERLESS, piège R20). Le test asserte la **composition** : « des `ZExam` réels, vus à travers NOTRE adaptateur, produisent la vue quotidienne correcte ». Injection R3-I4 : l'adaptateur code en dur `isApproaching(now) => true` (au lieu de déléguer à `ZExam`) ⇒ un examen **passé** fuit dans la liste ⇒ l'attendu EXACT (approchants seuls, ordonnés) RC=1. Injection R3-I4b : l'adaptateur retourne `daysUntil => 0` constant ⇒ le tri par date et les `daysUntil` attendus RC=1.

**AC5 — La planification de notification OS est un SEAM APP ; le domaine ne calcule que `isApproaching(now)` déterministe (AD-12/AD-26, R5)**
**Given** que la planification concrète (canal OS, plugin de notification, horaire système) est **app-specific**
**When** on analyse les fichiers ES-9.2 + le pubspec `zcrud_study`
**Then**
- **aucun** `DateTime.now()` / `DateTime()` argless dans les fichiers ES-9.2 : l'horloge `now` est **INJECTÉE** en paramètre (patron `ZExam`/`aggregateDailyStudyTasks`) ; le widget/section ne calcule QUE `isApproaching(now)` déterministe ;
- **aucune** dépendance de notification/OS/scheduler ajoutée au pubspec (`flutter_local_notifications`, `awesome_notifications`, `workmanager`, `android_alarm_manager`, timezone/cron, …) — la seule arête ajoutée est `zcrud_exam` ; **aucun** appel de plateforme/plugin de notification, **aucun** `Timer`/`Future.delayed` de planification dans le code ES-9.2 ;
- la section expose les approchants (et/ou un `onRemindersComputed`/`ZApproachingExam[]`) pour que **l'app** planifie — le widget ne planifie JAMAIS.
**Discriminant (R5/AD-12)** — un test de scan LOCAL au package énumère les fichiers ES-9.2 et asserte l'**absence RÉELLE** de `DateTime.now(`/`DateTime()` et de tout symbole de notification/scheduler (patron `no_datetime_now_test.dart`). Injection R3-I5 : insérer `final now = DateTime.now();` dans le widget/section ⇒ le scan RC=1. Injection R3-I5b : importer/nommer `flutter_local_notifications` ⇒ scan + graphe RC=1. L'AC prouve l'absence, pas « le fichier compile ».

**AC6 — Réactivité Flutter-native : controller owned/injected, granularité SM-1, zéro `setState` de page (AD-2/AD-15, SM-1)**
**Given** l'objectif produit n°1 (rebuilds granulaires, zéro perte de focus)
**When** l'utilisateur tape dans un champ de l'éditeur
**Then**
- le `TextEditingController` POSSÉDÉ est créé en `initState` (**jamais** dans `build`) et disposé au `dispose` ; un controller **INJECTÉ** est utilisé tel quel et **JAMAIS disposé** (patron owned/injected `ZStudyMindmapSection` ES-7.1 / `ZTagEditor` ES-8.1) ;
- l'état par champ vit dans un `ValueNotifier`/`ValueListenable` LOCAL — **aucun `setState` à l'échelle de l'éditeur**, **aucun** gestionnaire d'état (`get`/`riverpod`/`provider`) importé (AD-2/AD-15) ;
- taper N caractères ne reconstruit QUE le champ courant (SM-1) — clé stable `ValueKey` par champ, identité du controller STABLE entre rebuilds.
**Discriminant (SM-1)** — capture de l'**identité du controller détenu** (stable entre deux rebuilds) + compteur de rebuild par champ (seul le champ courant se reconstruit). Injection R3-I6 : recréer le `TextEditingController` dans `build()` ⇒ l'identité change ⇒ RC=1. Injection R3-I6b : lifter l'état en `setState` de page (ou remonter le notifier) ⇒ un champ voisin se reconstruit à la frappe ⇒ le compteur RC=1. Réutilise `z_study_tools_rebuild_test.dart` (SM-1).

**AC7 — Accessibilité AD-13 : Semantics non vides, cibles ≥ 48 dp, directionnel, thème injecté (FR-26, R24)**
**Given** les exigences a11y (AD-13/NFR-S6)
**When** on rend `ZExamEditor` et la section rappels
**Then**
- chaque contrôle interactif (valider, ajouter un seuil, choisir date/heure, toggle rappels) porte un **`Semantics.label` NON vide** (INJECTÉ, repli neutre documenté — jamais un label codé en dur imposé, FR-26) ;
- toute cible interactive mesure **≥ 48 dp** (`tester.getSize`) ;
- widgets **DIRECTIONNELS** uniquement (`EdgeInsetsDirectional`, `TextAlign.start/end`, `AlignmentDirectional` — jamais `.left/.right`, AD-13) ; la liste des approchants est un **`ListView.builder`** (jamais `ListView(children:)`) ;
- couleurs/thème via `ZcrudScope`/`ZcrudTheme` (`package:zcrud_core`), **aucune `Color`/`IconData`/label métier codé en dur** (FR-26) — icônes significatives INJECTÉES avec repli neutre documenté (patron `ZStudyToolsSectionSpec`/`ZTagEditor`).
**Discriminant (R24)** — mesure `getSize ≥ 48`, `getSemantics().label` non vide et DISTINCT par contrôle. Injection R3-I7 : réduire une cible < 48 dp (ou vider un `Semantics.label`) ⇒ RC=1. Un test de source (grep) asserte l'absence de `EdgeInsets.only(left:/right:)`/`TextAlign.left`/`ListView(children:` dans les fichiers ES-9.2.

**AC8 — Graphe acyclique, arête justifiée, `zcrud_exam` pur-Dart préservé (AD-1/AD-17, CORE OUT=0)**
**Given** l'arête `zcrud_study → zcrud_exam` ajoutée
**When** on rejoue `python3 scripts/dev/graph_proof.py`
**Then** **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 44`** (43 → 44, **exactement +1**), 20 nœuds inchangés ; le pubspec `zcrud_study` documente l'arête (« `zcrud_exam` : consommé par ES-9.2 pour `ZExam`/`ZReminderTime`/`kReminderTimeKey` — UI examens + adaptateur `ZApproachingExam`. Acyclique : exam → core/annotations, jamais l'inverse »). **`zcrud_exam` reste PUR-DART** (aucun `flutter` ajouté à SON pubspec, `gate:web` intact — DW-ES92-1). **Aucune** autre arête (pas de gestionnaire d'état, pas de SDK notification).
**Discriminant** — un delta ≠ +1 (ex. arête notification/`flutter` sur `zcrud_exam`) fait diverger le compte ⇒ échec ; `graph_proof` refuse tout cycle ; un test/inspection confirme que `packages/zcrud_exam/pubspec.yaml` n'a **pas** gagné `sdk: flutter`.

## Tasks / Subtasks

- [x] **T1 — Arête de graphe + pubspec (AC8)** — `packages/zcrud_study/pubspec.yaml`
  - [x] Ajouter `zcrud_exam: ^0.1.0` sous `dependencies` ; documenter l'arête dans le bloc « Arêtes inter-packages » (consommé par ES-9.2 : `ZExam`/`ZReminderTime`/`kReminderTimeKey` + adaptateur `ZApproachingExam` ; acyclique exam → core/annotations).
  - [x] **NE PAS** basculer `zcrud_exam` en Flutter (son pubspec reste INTOUCHÉ, pur-Dart, `gate:web`) ; **NE PAS** ajouter de SDK notification/OS/scheduler ni gestionnaire d'état (AC5).
  - [x] `dart pub get` (fenêtre R25 : ES-9.2 seule en vol) puis `python3 scripts/dev/graph_proof.py` → **44 arêtes**, ACYCLIQUE OK, CORE OUT=0 OK, 20 nœuds.

- [x] **T2 — Adaptateur `ZExam → ZApproachingExam` (AC4)** — **NOUVEAU** `packages/zcrud_study/lib/src/presentation/z_exam_reminders.dart`
  - [x] `class _ZExamApproaching implements ZApproachingExam` **et** fonction `ZApproachingExam zExamAsApproaching(ZExam)` : forwarder TRIVIAL délégant `isApproaching(now)`/`daysUntil(now)`/`date` à la vraie méthode `ZExam` — **aucune ré-implémentation** de la logique de proximité (elle vit dans `ZExam`, R20).
  - [x] Helper `List<ZDailyStudyTask> examDailyTasks({...})` + `List<ZApproachingReminder> approachingReminders({...})` minces, adaptant + déléguant à `aggregateDailyStudyTasks` (le `now` reste **injecté**, jamais `DateTime.now()`, AC5).
  - [x] Dartdoc : câblage DÉFÉRÉ au consommateur (ES-9.2), adaptateur côté `zcrud_study` (0 arête sur `zcrud_exam`).

- [x] **T3 — `ZExamEditor` (AC1, AC2, AC3, AC6, AC7)** — **NOUVEAU** `packages/zcrud_study/lib/src/presentation/z_exam_editor.dart`
  - [x] `StatefulWidget` (UNIQUEMENT cycle de vie des controllers possédés + `ValueNotifier` locaux). Paramètres : `initialExam`, `onSubmit(ZExam)`, `onPickDate`/`onPickTime` INJECTÉS (aucun `DateTime.now()`/`showDatePicker` en dur), controllers injectables, labels/icônes INJECTÉS (replis documentés), `ZcrudTheme` via `ZcrudScope`.
  - [x] Champs (chacun `ValueKey` stable, frontière rebuild) : titre (controller owned/injecté), date, toggle `reminderEnabled`, éditeur de seuils (**ordre + doublons PRÉSERVÉS**, pas de `sort`/`toSet`), heure `reminderTime` (**`ZReminderTime` TYPÉ**).
  - [x] Émission : `base.copyWith(...)` — **`id == null`** en création (AD-14, `id` de `initialExam` préservé en édition). PRÉSERVATION EXACTE de la saisie (AC1).
  - [x] a11y AD-13 : `Semantics` non vides injectés, cibles ≥ 48 dp (`_kMinTapTarget = 48.0`), `EdgeInsetsDirectional`/`TextAlign.start`, thème injecté. Aucun `setState` de page (AC6).

- [x] **T4 — Section rappels approchants (AC4, AC5, AC7)** — **NOUVEAU** `packages/zcrud_study/lib/src/presentation/z_exam_reminders_section.dart`
  - [x] Widget listant les examens approchants (dérivés via T2, `now` INJECTÉ) en **`ListView.builder`** accessible, chaque ligne keyée (`ValueKey('z-exam-reminder:${exam.id ?? index}')`), a11y AD-13.
  - [x] Expose les approchants (`onRemindersComputed` post-frame) — **la planification OS reste app-side** (AC5) : aucun plugin/`Timer`/`Future.delayed` de notification ; ne calcule que `isApproaching(now)`.
  - [x] (Non retenu — YAGNI) fabrique `sectionSpec(...)` : la section rend directement ; un `ZStudyToolsSectionSpec` n'apporterait rien ici (pas de rail/grille réordonnable).

- [x] **T5 — Barrel (AC1)** — `packages/zcrud_study/lib/zcrud_study.dart`
  - [x] Exporte `z_exam_editor.dart`, `z_exam_reminders_section.dart`, et la surface publique de `z_exam_reminders.dart` (`ZApproachingReminder`/`approachingReminders`/`examDailyTasks`/`zExamAsApproaching`). `ZExam`/`ZReminderTime` NON ré-exportés (import `package:zcrud_exam/…`).

- [x] **T6 — Tests `flutter test` (R14) — `packages/zcrud_study/test/`**
  - [x] `z_exam_editor_test.dart` : AC1 (préservation EXACTE + `id == null` ; édition préserve l'`id`) ; AC2 (`ZReminderTime` TYPÉ, `08:05`, round-trip) ; AC3 (`[7,1]`/`[3,3,10]` préservés).
  - [x] `z_exam_reminders_section_test.dart` : AC4 (mix réel vu par l'adaptateur ⇒ approchants EXACTS ordonnés ; ancré sur l'adaptateur, R20/R26 ; section rend + expose).
  - [x] `z_exam_ui_no_scheduler_test.dart` : AC5 (scan LOCAL — absence `DateTime.now(`/argless + symboles notification/scheduler ; commentaires dépouillés ; filet à pouvoir R2).
  - [x] `z_exam_editor_reactivity_test.dart` : AC6 (identité controller stable ; owned disposé / injecté non disposé ; granularité SM-1 via sonde `dateLabeler`).
  - [x] `z_exam_editor_a11y_test.dart` : AC7 (cibles ≥ 48 dp `getSize` + compte de `ConstrainedBox` ≥ 48 comme garde PROPRE ; `Semantics.label` distincts ; scan source directionnel comm. dépouillés ; RTL).
  - [x] Chaque test **rougit sur son injection R3 dédiée** — prouvé AU DEV (12 injections RC=1, cf. Debug Log).

- [x] **T7 — Vérif verte rejouée** + File List + Dev Agent Record honnête.

## Injections R3 prévues (mutation → AC rouge → restauration)

Chaque injection doit **RC=1** sur l'AC ciblé, puis restauration → vert (preuve du pouvoir discriminant, R3/R12). VERROUILLAGE explicite de chaque garde load-bearing.

- **R3-I1 (AC1)** — l'éditeur émet un `ZExam()` par défaut (ou droppe un champ saisi) ⇒ l'assertion de préservation exacte RC=1. **R3-I1b** — l'éditeur assigne un `id` non-`null` ⇒ `id == null` RC=1.
- **R3-I2 (AC2, AD-28)** — l'heure stockée/émise en `String` nue (ou zéro-padding perdu `'8:5'`) ⇒ assertion de type `ZReminderTime`/valeur `08:05` RC=1.
- **R3-I3 (AC3, R26 sur-purge/normalisation)** — `..sort()` ou `.toSet().toList()` sur `reminderDaysBefore` ⇒ pour `[7,1]` l'attendu EXACT RC=1 (ordre) ; pour `[3,3,10]` RC=1 (doublon perdu).
- **R3-I4 (AC4, R20/R26)** — l'adaptateur code en dur `isApproaching(now) => true` ⇒ un examen passé fuit ⇒ la liste attendue EXACTE (approchants seuls) RC=1. **R3-I4b** — `daysUntil => 0` constant ⇒ tri par date / `daysUntil` attendus RC=1.
- **R3-I5 (AC5, R5)** — insérer `DateTime.now()` dans le widget/section ⇒ le scan `no-scheduler` RC=1. **R3-I5b** — nommer/importer `flutter_local_notifications` (ou un `Timer` de planification) ⇒ scan + graphe RC=1.
- **R3-I6 (AC6, SM-1)** — recréer le `TextEditingController` dans `build()` ⇒ l'identité change RC=1. **R3-I6b** — lifter l'état en `setState` de page ⇒ un champ voisin se reconstruit à la frappe RC=1.
- **R3-I7 (AC7, AD-13)** — cible < 48 dp (ou `Semantics.label` vidé) ⇒ RC=1 ; un `EdgeInsets.only(left:)`/`ListView(children:` inséré ⇒ scan source RC=1.
- **R3-I8 (AC8, graphe)** — arête parasite (`flutter` sur `zcrud_exam`, ou SDK notification) ⇒ `graph_proof` compte ≠ 44 / cycle / bascule Flutter détectée.

## Dev Notes

- **RÉUTILISER, ne pas recréer (R21/SM-S4).** `ZExam`, `ZReminderTime`, `aggregateDailyStudyTasks`, `ZApproachingExam` EXISTENT et sont testés. ES-9.2 est un **adaptateur mince de PRÉSENTATION** (précédents `ZStudyMindmapSection` ES-7.1, `ZTagEditor` ES-8.1) : elle **compose** l'entité (construit/`copyWith` `ZExam`), **adapte** au port (`ZApproachingExam` forwarder trivial), **rend** l'UI. Elle ne réimplémente NI la proximité, NI la (dé)sérialisation, NI le tri quotidien.
- **Ancrage R20/R24 — le piège central de cette story.** NE PAS re-tester `aggregateDailyStudyTasks`/`ZExam.isApproaching`/`ZReminderTime.parse` en boîte noire (ce sont des mécanismes `zcrud_study_kernel`/`zcrud_exam` **déjà** testés — les asserter serait POWERLESS sur ES-9.2, piège R20 exact). Ancrer AC4 sur l'**ADAPTATEUR** d'ES-9.2 (« un `ZExam` réel vu par NOTRE adaptateur produit la vue quotidienne correcte »), AC1/AC2/AC3 sur l'**`exam` ÉMIS par l'éditeur** (préservation exacte de la saisie), AC6 sur l'**identité du controller détenu par le widget** — jamais sur un artefact adjacent stable ni un libellé présent dans toutes les branches (R24).
- **R26 (leçon centrale ES-8, récurrente ES-9.1).** AC3 (seuils) et AC4 (sélection des approchants) sont des gardes de **filtrage/transformation** : asserter la **PRÉSERVATION EXACTE** du résultat attendu (`[7,1]` reste `[7,1]` ; la liste des approchants ordonnés est exacte), **jamais** « la liste est non vide » ni « pas de throw ». Prouver par injection de **sur-purge/normalisation** (`sort`/`toSet`/`=>true`) ⇒ RC=1. Un test vrai de façon VACUE (liste vide, aucun approchant) ne compte pas — inclure des cas non-dégénérés (seuils non-triés à doublon ; mix approchants/passés/off).
- **AD-28 — l'heure est TYPÉE.** `reminderTime` est un `ZReminderTime`, jamais une `String` `'HH:mm'` flottante. Le champ heure de l'éditeur est **explicite** (le doc `z_exam.dart:196-199` le rappelle : hors-codegen ⇒ aucun `ZFieldSpec` généré). Le round-trip `toMap` réémet `reminder_time: '08:05'` sous `kReminderTimeKey`.
- **AC5 — la notification est un SEAM APP (AD-12/AD-26).** Le widget/section ne planifie JAMAIS ; il calcule `isApproaching(now)` déterministe (horloge `now` **INJECTÉE**, jamais `DateTime.now()`, R5) et expose les approchants à l'app. Aucun plugin de notification / `Timer` / `Future.delayed` de planification dans le code ES-9.2. C'est l'inverse du réflexe « le widget programme le rappel » — la programmation OS est app-side.
- **AD-14 — `id` matérialisé au repository (ES-3).** L'`exam` émis en création a `id == null` ; le widget n'attribue JAMAIS d'`id` (précédent `ZTagEditor.onCreateTag`).
- **Réactivité Flutter-native (AD-2/AD-15, SM-1).** Patron owned/injected du controller (créé `initState` ssi possédé, disposé `dispose` ssi possédé ; injecté utilisé tel quel, jamais disposé). État par champ dans `ValueNotifier` local ; aucun `setState` de page ; aucun gestionnaire d'état importé dans `zcrud_study` (AD-2/AD-15). `ValueKey` par champ = frontière de rebuild (SM-1, objectif produit n°1).
- **Directionnalité RTL / const / a11y (AD-13, FR-26).** `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start-end` ; `Semantics` explicites + cibles ≥ 48 dp ; `ListView.builder` ; couleurs/labels/icônes INJECTÉS via `ZcrudScope`/`ZcrudTheme` (repli neutre documenté), aucun style codé en dur.
- **Arbitrage placement (§ Contexte) — NE PAS ré-arbitrer.** L'UI vit dans `zcrud_study/presentation` (pas `zcrud_exam`) : `zcrud_exam` reste pur-Dart (NFR-S3/`gate:web`), 1 arête acyclique, précédent unanime. L'adaptateur `ZApproachingExam` vit côté `zcrud_study` (0 arête sur `zcrud_exam`, l'arête kernel étant explicitement différée par le pubspec `zcrud_exam`).

### Project Structure Notes

- Nouveaux fichiers UI sous `packages/zcrud_study/lib/src/presentation/` (cohérent ES-5/7/8). L'adaptateur `ZApproachingExam` peut vivre en `presentation/` (co-logé avec la section) ou `domain/` — préférer **`presentation/`** (co-localité avec le seul consommateur, la section), sauf si une réutilisation domaine émerge.
- `zcrud_exam` **INTOUCHÉ** (consommé). `zcrud_study_kernel` INTOUCHÉ (port `ZApproachingExam` consommé). `zcrud_core` INTOUCHÉ (`ZcrudScope`/`ZcrudTheme` consommés).
- Barrel unique `lib/zcrud_study.dart` (surface publique unique).
- **Variance attendue** : le pubspec `zcrud_study` gagne l'arête `zcrud_exam` ; c'est la déviation justifiée (T1), pas une entorse. Le chemin `zcrud_exam/presentation/z_exam_editor.dart` de l'epic est REMPLACÉ par `zcrud_study/presentation/` (DW-ES92-1).

### References

- Story & ACs source : `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story ES-9.2` (l. 954-970) ; FR-S30 (l. 63, 134), FR-S9 (l. 42, 113), FR-S10.
- Entités CONSOMMÉES : `packages/zcrud_exam/lib/src/domain/z_exam.dart` (`ZExam`, `daysUntil`/`isPast`/`isApproaching`, `kReminderTimeKey`, canal hors-codegen `reminderTime` l.186-200), `z_reminder_time.dart` (`ZReminderTime.parse`/`toHhmm`), barrel `packages/zcrud_exam/lib/zcrud_exam.dart`.
- Agrégation quotidienne + port : `packages/zcrud_study_kernel/lib/src/domain/aggregate_daily_study_tasks.dart` (signature l.54), `z_daily_study_task.dart` (`ZApproachingExam` l.113+, `ZExamTask`, câblage DÉFÉRÉ à ES-9.2 l.30).
- Précédents adaptateur/éditeur de présentation : `packages/zcrud_study/lib/src/presentation/z_study_mindmap_section.dart` (ES-7.1, owned/injected), `z_tag_editor.dart` (ES-8.1, controller owned/injected + émission `id==null`), `z_study_tools_section_spec.dart` (fabrique/injection FR-26).
- Invariants : `…/architecture-zcrud-study-2026-07-12/architecture.md` — AD-1/AD-17 (graphe acyclique CORE OUT=0), AD-2/AD-15 (réactivité Flutter-native, SM-1), AD-4 (String opaque, registre/port), AD-10 (défensif), AD-12/AD-26 (seam app, zéro secret/SDK), AD-13 (directionnel/Semantics/≥48dp), AD-14 (`id` au repository), AD-28 (heure TYPÉE), FR-26 (thème injecté).
- Tooling gate : `scripts/dev/graph_proof.py` (44 arêtes attendues), `melos.yaml` (`flutter test` R14 ; `gate:web` pur-Dart préservé pour `zcrud_exam`).
- Leçons rétro : R20/R24 (`epic-es-6/7-retrospective.md` — ancrage sur la ligne de prod propre, jamais artefact adjacent/code consommé), R25 (`epic-es-8-retrospective.md:91` — fenêtre pub-get sérialisée), R26 (`…:92` — préservation exacte, pas absence d'anomalie), leçon méta M-1/M-2 ES-9.1 (`code-review-es-9-1.md:157` — garde solide seulement une fois verrouillée par un test à rouge provoqué ; jamais masquer un défaut derrière un faux diagnostic).

### Vérif verte à rejouer (avant tout `review`/`done`)

**RC hors pipe (R15)** : lancer chaque commande **séparément** et capturer `echo "RC=$?"` **non pipé** (jamais `cmd | tee` qui masque le RC). **Runner R14** : `flutter test` (package Flutter) — **jamais** `dart test` sur `zcrud_study`.

- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK**, **`total arêtes = 44`** (delta +1 = `zcrud_study → zcrud_exam`), 20 nœuds.
- `dart run melos list` → **20** packages, workspace stable.
- `dart pub get` (racine) → résolution verte (fenêtre R25, ES-9.2 seule en vol).
- `melos run generate` → no-op pour `zcrud_study` (aucun `@ZcrudModel`), repo-wide vert.
- `flutter analyze` sur `packages/zcrud_study` → RC=0 (cible dev actif) ; **au gate de commit d'epic** : `dart run melos run analyze` **REPO-WIDE** (détecte les régressions cross-package — NON-NÉGOCIABLE).
- `flutter test` sur `packages/zcrud_study` (**R14**) → RC=0, tous les AC couverts, chaque injection R3 prouvée RED puis restaurée.
- **Vérif que `zcrud_exam` reste pur-Dart** : `git diff packages/zcrud_exam/pubspec.yaml` **VIDE** (aucun `sdk: flutter` ajouté) ; `melos run test` (suite pur-Dart) + `gate:web` `zcrud_exam` **verts inchangés**.
- **Au gate de commit d'epic uniquement** (workstreams au repos) : `dart run melos run verify` **REPO-WIDE** (miroir CI : graph_proof + gates + analyze + test) + `dart run scripts/ci/gate_secret_scan.dart` **vert**.

## Findings / dettes anticipés

- **DW-ES92-1 (placement UI — déviation JUSTIFIÉE du chemin de l'epic).** L'epic nomme `zcrud_exam/lib/src/presentation/z_exam_editor.dart` ; ES-9.2 place l'UI dans `zcrud_study/lib/src/presentation/` pour **préserver `zcrud_exam` pur-Dart** (NFR-S3, `gate:web`, éviter la bascule Flutter + fenêtre R25). Précédent unanime (ES-7.1/8.1/8.2). **Pas une dette** : décision d'architecture tracée. Si un jour une app veut l'édition d'examen SANS la page study-tools, on créera un package Flutter dédié (hors périmètre) — à ne pas anticiper.
- **DW-ES92-2 (persistance `ZExam` = repository, ES-3).** ES-9.2 garantit UNIQUEMENT que l'éditeur **émet** un `ZExam` valide (`id==null`, saisie préservée) et que la section **calcule** les approchants ; l'écriture/lecture effective (store, `Either`, id matérialisé) est le travail de `ZStudyRepository`/adapter — **ES-3**. Les AC sont honnêtes vis-à-vis de ce périmètre (composition/émission, jamais un effet de store). Frontière R24 honnête.
- **DW-ES92-3 (planification notification OS = app, AD-26).** La programmation concrète (canal OS, plugin) est app-side ; ES-9.2 ne livre que le calcul déterministe `isApproaching(now)` + l'exposition des approchants. Aucune dette : c'est le design (AC5).
- **DW-ES92-4 (chaîne sérielle).** ES-9.3/9.4 écrivent aussi `zcrud_study` — **jamais** en vol avec ES-9.2 (sprint-status `[SÉQ]`). Rappel orchestrateur.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill BMAD **`bmad-dev-story`** réellement invoqué via le tool `Skill`).

### Debug Log References

**Vérif verte rejouée (RC hors pipe, R15 ; runner `flutter test` R14) :**
- `dart pub get` (fenêtre R25, ES-9.2 seule en vol) → **RC=0**.
- `flutter test` sur `packages/zcrud_study` → **RC=0**, **140 tests** (dont ES-9.2), 0 régression.
- `python3 scripts/dev/graph_proof.py` → **RC=0** — `total arêtes = 44` (43→44, +1 = `zcrud_study → zcrud_exam`), 20 nœuds, **ACYCLIQUE OK**, **CORE OUT=0 OK**.
- `dart run melos list` → **20** packages.
- `dart run melos exec --scope=zcrud_study -- dart analyze` → **RC=0** (les 3 `info prefer_initializing_formals` pré-existent dans `lib/src/domain/z_ai_*`/`z_note_summary_port` — NON touchés par ES-9.2).
- `dart run melos run verify` (repo-wide, miroir CI) → **RC=0** : graph_proof + **gate:secrets OK** + **gate:reserved-keys OK** (volets A+B) + **gate:web OK** + gate:codegen-distribution OK (5 packages `part`, dont `zcrud_exam`, 0 gitignoré) + verify:serialization OK.
- `git diff packages/zcrud_exam/pubspec.yaml` **VIDE** — `zcrud_exam` reste **PUR-DART** (aucun `sdk: flutter`, `gate:web` intact, DW-ES92-1). Aucun fichier hors `packages/zcrud_study/` touché (core/kernel/exam CONSOMMÉS).

**Injections R3 prouvées (mutation → AC RED RC=1 → restauration ciblée → vert) — leçon M-1 (une garde non exercée est un vœu) :**
- **R3-I1** (AC1, drop `reminderDaysBefore`) → RC=1 ✅ ; **R3-I1b** (id non-null forcé) → RC=1 ✅ ; **R3-I2** (drop `reminderTime`) → RC=1 ✅.
- **R3-I3a** (AC3, `..sort()` sur seuils) → RC=1 ✅ ; **R3-I3b** (`toSet` dédup) → RC=1 ✅.
- **R3-I4** (AC4, adaptateur `isApproaching => true`, un passé fuit) → RC=1 ✅ ; **R3-I4b** (`daysUntil => 0` constant) → RC=1 ✅.
- **R3-I5** (AC5, `DateTime.now()` injecté dans `build`) → RC=1 ✅ ; **R3-I5b** (`import flutter_local_notifications`) → RC=1 ✅.
- **R3-I6** (AC6, controller recréé dans `build`) → RC=1 ✅.
- **R3-I7** (AC7, `_kMinTapTarget → 20`) → **d'abord RC=0** : le `getSize` seul était POWERLESS (Material `tapTargetSize.padded` impose déjà 48 dp indépendamment de notre code — piège M-1 démasqué AU DEV, pas en revue). **Correction** : ajout d'une assertion sur le **compte de `ConstrainedBox(min 48/48)`** — LA garde PROPRE à ES-9.2 — puis re-injection → **RC=1** ✅, vert restauré. (Honnêteté M-2 : le défaut est consigné, pas masqué.)

### Completion Notes List

- **Arbitrage placement respecté (DW-ES92-1)** : UI dans `zcrud_study/lib/src/presentation/`, `zcrud_exam` INTOUCHÉ pur-Dart. Adaptateur `ZApproachingExam` côté `zcrud_study` (0 arête sur `zcrud_exam`).
- **AC1** : `_submit` compose via `base.copyWith(...)` (préserve `id`/`extension`/`extra` en édition ; `id == null` en création, AD-14) ; ne réimplémente ni la (dé)sérialisation ni la validation de `ZExam`.
- **AC2/AD-28** : heure dans `ValueNotifier<ZReminderTime?>` (jamais une `String`) ; round-trip `toMap` `'08:05'` délégué à `ZExam`.
- **AC3/R26** : seuils édités par APPEND, ordre + doublons préservés (aucun `sort`/`toSet`) ; clé de puce indexée pour distinguer deux doublons.
- **AC4/R20/R26** : `approachingReminders`/`examDailyTasks` délèguent filtre+tri au kernel via l'adaptateur — la ligne load-bearing est la délégation `_ZExamApproaching`, testée sur un mix réel (approchants/passés/off/date=null), sélection + ordre EXACTS.
- **AC5/AD-26** : `now` INJECTÉ partout, aucun `DateTime.now()`, aucun plugin notification/`Timer`/`Future.delayed` ; la section EXPOSE (`onRemindersComputed` post-frame) mais ne planifie JAMAIS.
- **AC6/SM-1** : controller titre owned/injected, identité stable ; état par champ dans notifiers locaux isolés ; aucun `setState` de page.
- **AC7/AD-13/FR-26** : `Semantics` injectés distincts, cibles ≥ 48 dp (garde `ConstrainedBox` + `getSize`), directionnel, `ListView.builder`, thème via `ZcrudScope`/`ZcrudTheme`, aucune `Color`/hex codé en dur.
- **AC8/AD-1** : arête `zcrud_study → zcrud_exam` (+1 = 44), acyclique, CORE OUT=0, `zcrud_exam` pur-Dart préservé.
- **Dettes** : DW-ES92-1..4 confirmées telles quelles (aucune dette nouvelle). `sprint-status.yaml` **NON touché** (géré par l'orchestrateur).

### File List

**Créés (tous sous `packages/zcrud_study/`) :**
- `lib/src/presentation/z_exam_reminders.dart` (adaptateur `_ZExamApproaching`/`zExamAsApproaching` + `examDailyTasks` + `ZApproachingReminder`/`approachingReminders`)
- `lib/src/presentation/z_exam_editor.dart` (`ZExamEditor`)
- `lib/src/presentation/z_exam_reminders_section.dart` (`ZExamRemindersSection`)
- `test/z_exam_editor_test.dart` (AC1/AC2/AC3)
- `test/z_exam_reminders_section_test.dart` (AC4/AC5)
- `test/z_exam_ui_no_scheduler_test.dart` (AC5)
- `test/z_exam_editor_reactivity_test.dart` (AC6)
- `test/z_exam_editor_a11y_test.dart` (AC7)

**Modifiés :**
- `packages/zcrud_study/pubspec.yaml` (arête `zcrud_exam: ^0.1.0` + doc bloc « Arêtes inter-packages »)
- `packages/zcrud_study/lib/zcrud_study.dart` (barrel — exports ES-9.2)
