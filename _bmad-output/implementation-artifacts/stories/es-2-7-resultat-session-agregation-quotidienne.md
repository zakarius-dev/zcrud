---
baseline_commit: 6d8694227a8134f0f0ddac4f8dc6a98338da7701
---

# Story ES-2.7 : Résultat de session + agrégation quotidienne (`ZStudySessionResult` / `ZDailyStudyTask` / `aggregateDailyStudyTasks`)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur du domaine study zcrud**,
I want **modéliser dans le noyau `zcrud_study_kernel` (1) un value-object PUR de résultat de session `ZStudySessionResult` (mode/total/correct/byQuality), (2) une famille de tâches quotidiennes `ZDailyStudyTask` OUVERTE (interface + variantes `ZDueCardsTask`/`ZExamTask`, JAMAIS `sealed` — AD-4), (3) une fonction pure `aggregateDailyStudyTasks` qui combine les cartes dues et les examens approchants du jour au regard d'une horloge `now` INJECTÉE, en consommant les examens par un PORT NEUTRE `ZApproachingExam` (jamais `zcrud_exam` — AD-1/AD-17)**,
so that **la vue « Aujourd'hui » (cartes dues + examens approchants) soit produite de façon PURE, TOTALE et DÉTERMINISTE — sans `DateTime.now()` caché (interdit, non déterministe, banni des scripts du repo), sans dépendance montante du kernel vers un satellite, et sans switch exhaustif figé (variantes extensibles par consommateur, AD-4).**

## Contexte & source de vérité

- **FR couverte** : **FR-S10** — « Résultat de session (`ZStudySessionResult`) + agrégation quotidienne (`ZDailyStudyTask` + `aggregateDailyStudyTasks`). » [Source: epics-zcrud-study-2026-07-12/epics.md#FR-S10 l.451-467, table de traçabilité l.482 ; prd-zcrud-study-2026-07-12/prd.md#FR-S10 l.185-190]
- **Épic** : ES-2 (Modélisation du domaine éducatif). **Dépend de** : ES-1 (kernel + `ZSyncMeta` + `gate:web` + AST purity harness + `applyOrder`), ES-2.2b (gardes `extra` systémiques MESURÉES — patron VO/`ZExtensible`), ES-2.6 (`ZExam` **LIVRÉE** : `daysUntil`/`isPast`/`isApproaching(now)` PURES, horloge injectée, comparaison UTC — que cette story CONSOMME par un port). [Source: epics.md l.451, séquencement l.135-155 ; sprint-status.yaml (ligne ES-2.7)]
- **Package cible** : **kernel existant** `packages/zcrud_study_kernel/` (pur-Dart, comme ES-2.3/ES-2.4). Fichiers NEUFS : `lib/src/domain/{z_study_session_result.dart, z_daily_study_task.dart, aggregate_daily_study_tasks.dart}` + tests + mise à jour du barrel + `hide` `zcrud_flashcard` + surface-guard. [Source: epics.md l.457 « `packages/zcrud_study_kernel/lib/src/domain/{z_study_session_result.dart, z_daily_study_task.dart, aggregate_daily_study_tasks.dart}` (indirection par registre pour éviter toute dépendance montante vers `zcrud_exam`/`zcrud_flashcard`) »]
- **Parallélisation** : **SÉQUENTIELLE** — la story **ÉCRIT le kernel** (`zcrud_study_kernel`). Elle N'écrit PAS `zcrud_core` (elle consomme uniquement la surface pur-Dart `package:zcrud_core/domain.dart`) et **NE MODIFIE PAS `zcrud_exam`** (voir D10). Aucune fenêtre de parallélisation avec une autre story touchant le kernel. **NE TOUCHE PAS au sprint-status** (édition ciblée réservée à l'orchestrateur). [Source: sprint-status.yaml « [M][SÉQ — écrit kernel] ZStudySessionResult/ZDailyStudyTask/aggregate » ; CLAUDE.md « Règles générales »]

### 🔴 Source lex/IFFD PORTÉE (et à DIVERGER) — lecture RÉELLE du disque (R4/R-G)

`lex_douane` est **présent** sur ce poste. La forme canonique est portée de `lex_core` (module « Étude »), LU réellement :

1. **`StudySessionResult`** (`packages/lex_core/lib/domain/entities/education/study_session.dart` l.47-74) : `@JsonSerializable(fieldRename: snake)` **value-object** — `{mode: ReviewMode, total: int, correct: int, byQuality: Map<String,int>}`. **AUCUN `id`, AUCUN `folderId`, AUCUNE `date`.** `byQuality` : clé = qualité SM-2 `"0".."5"`, valeur = compte.
2. **`DailyStudyTask`** (`packages/lex_core/lib/domain/entities/education/daily_study_task.dart`) : **`sealed class`** ÉPHÉMÈRE (jamais persistée, aucun `fromJson`/`toJson`) à **DEUX variantes** — `DueCardsTask(int count)` et `ExamTask(Exam exam, int daysUntil)`. `==`/`hashCode` cohérents (clé de rebuild widget stable).
3. **`aggregateDailyStudyTasks`** (même fichier, l.82-93) : **fonction PURE** — `{required int dueCount, required List<Exam> exams, required DateTime now}` → `List<DailyStudyTask>`. Contrat : `DueCardsTask` présent **ssi `dueCount > 0`, TOUJOURS en tête** ; un `ExamTask` **pour chaque examen dont `isApproaching(now)`** (les passés / hors-fenêtre / rappels désactivés sont **exclus**) ; `ExamTask` triés par **date d'échéance croissante** (le plus proche d'abord), **après** la ligne dues. « Aucune I/O, aucune horloge interne : purement dérivée de ses arguments. »

**⚠️ CORRECTION MAJEURE DU BRIEF D'ORCHESTRATION (à intégrer — R4).** Le brief supposait une **agrégation par JOUR calendaire** de `ZStudySessionResult` (« regroupement par jour DATE-DÉPENDANT, deux résultats à cheval sur minuit dans le bon bucket »). **La lecture RÉELLE de la source falsifie cette hypothèse** : `aggregateDailyStudyTasks` **NE bucketise PAS** des résultats de session par jour. C'est une **vue « rythme du jour »** qui combine (a) le compte de cartes dues et (b) les examens approchants, au regard d'un `now` injecté. **`ZStudySessionResult` n'est PAS consommé par l'agrégation** — c'est un VO séparé (résultat d'UNE session). Le point de vigilance « frontière de jour / minuit » demeure RÉEL, mais il vit **dans `ZExam.daysUntil/isApproaching`** (comparaison **UTC-normalisée**, déjà LIVRÉE en ES-2.6) **et** dans l'injection de `now` — **pas** dans une bucketisation que cette story n'introduit pas. (Cf. ES-2.6, `z_exam.dart` l.300-345 : `DateTime.utc(d.year, d.month, d.day)` — aucune dérive DST/fuseau.)

### Ce que cette story ne livre PAS

- **Aucun widget, aucune UI, aucun provider Riverpod/GetX** : la surface « Aujourd'hui » (`study_today_section` / `daily_task_row`) et son câblage à un gestionnaire d'état sont **ES-5 / ES-9 / ES-10** (bindings). Cette story livre le **domaine pur** + la fonction pure. [Source: epics.md ES-5/ES-9/ES-10 ; AD-2/AD-15]
- **Aucune modification de `ZExam` / `zcrud_exam`** (D10) : l'entité examen est **LIVRÉE et FIGÉE** (ES-2.6, `done`). Le câblage `ZExam → ZApproachingExam` (via `implements` ou adaptateur) appartient au **consommateur** (ES-9.2 « fil de rappels » / ES-5) — pas au kernel. Cette story livre le **port neutre** et teste l'agrégation avec un **double de test** local au kernel.
- **Aucun `dueCount` calculé** : le compte de cartes dues est fourni par l'APPELANT (source unique amont — `ZRepetitionInfo`/repository, ES-3/ES-9). L'agrégation ne recalcule **JAMAIS** ce compte (parité stricte lex : « source unique, jamais recalculé ici »).
- **Aucune persistance / repository / cascade** : la persistance éventuelle de `ZStudySessionResult` est **ES-3.x**. Cette story livre le **round-trip `Map` in-memory** (`toMap`/`fromMap`) pour le « si persisté » de l'AC épic, rien de plus.
- **Aucune horloge `ZClock` / service de temps** : l'injection est un **paramètre `DateTime now`** (parité D5 d'ES-2.6). N'inventer AUCUNE abstraction non requise (YAGNI ; le repo n'a AUCUN `ZClock`).
- **Aucun registre de (dé)sérialisation `ZTypeRegistry` pour `ZDailyStudyTask`** (D2/D3 ci-dessous) : le type est **éphémère et non sérialisé** — l'extensibilité AD-4 « sans switch exhaustif figé » est portée par une **interface OUVERTE + discriminant `String kind`**, PAS par la machinerie `register(kind, fromJson, toJson)` (réservée aux types SÉRIALISÉS).

## Décisions structurantes (tranchées PAR LECTURE — R4/R-G)

- **D1 — `ZStudySessionResult` = value-object PUR, NON `@ZcrudModel`, NON `ZEntity`, NON `ZExtensible`.** La source lex est un simple `@JsonSerializable` **sans `id`** ; l'épic ET le PRD le nomment explicitement **« value-object »**. ⇒ patron VO PUR du repo (précédent EXACT `ZReminderTime` d'ES-2.6 : classe pure, `fromMap`/`toMap` **écrits à la main**, `==`/`hashCode` de valeur, AUCUN codegen, AUCUN `@JsonSerializable`). Champs : `mode: ZReviewMode` (enum kernel existant, repli défensif `spaced`), `total: int` (défaut `0`), `correct: int` (défaut `0`), `byQuality: Map<String,int>` (défaut `const {}`). **Conséquence FORTE : aucun `registerZ…` n'est généré ⇒ AUCUN câblage du gate `reserved-keys` pour ce VO** (contraste ES-2.3/2.4/2.6). [Source: study_session.dart l.47-74 ; z_reminder_time.dart ; epics.md l.463 « c'est un **value-object** » ; prd.md l.188]
  - **Pourquoi PAS `@ZcrudModel` NON-`ZExtensible` (comme `ZChoice`/`ZAnnotationBounds`)** : ces VO-là sont `@ZcrudModel` **parce qu'ils sont des sous-modèles imbriqués** d'une entité enregistrée (`ZChoice`⊂`ZFlashcard`, `ZAnnotationBounds`⊂`ZDocumentAnnotation`) — le générateur EXIGE `@ZcrudModel` sur un champ sous-modèle. `ZStudySessionResult` **n'est le champ d'AUCUNE entité de cette story** (autonome) ⇒ il n'a **aucune raison** d'être `@ZcrudModel`, et son `byQuality: Map<String,int>` **n'est PAS codegen-able** (le générateur `_classify` n'a **aucune branche `isDartCoreMap`** — cf. `ZFolderContentsOrder.sectionOrders`). Le rendre `@ZcrudModel` forcerait `byQuality` en canal hors-codegen + clé réservée + câblage gate, pour un gain nul. ⇒ **VO PUR, round-trip à la main.**
- **D2 — `ZDailyStudyTask` = famille ÉPHÉMÈRE OUVERTE (interface + variantes), JAMAIS `sealed`.** La source lex est `sealed` ; **AD-4 REJETTE explicitement `sealed` pour l'extension inter-package**, et l'épic exige « sans switch exhaustif figé (registre extensible, AD-4) ». ⇒ `abstract interface class ZDailyStudyTask { String get kind; }` (discriminant **opaque `String`**, précédent `ZSessionCandidate.typeKey` / `ZFlashcardSource.kind`), avec deux variantes concrètes **immuables** `ZDueCardsTask` (`{String kind => 'dueCards'; int count}`) et `ZExamTask` (`{String kind => 'exam'; ZApproachingExam exam; int daysUntil}`). Un consommateur dispatche sur `.kind` avec un **`default`** (aucune exhaustivité imposée) et un satellite futur (ES-2.8 podcast, ES-9) peut AJOUTER une variante **sans modifier le kernel**. `==`/`hashCode` de valeur sur chaque variante (clé de rebuild stable — parité lex). **Non persisté ⇒ AUCUN codegen, AUCUN câblage gate.** [Source: daily_study_task.dart ; architecture AD-4 « Rejetés : … `sealed` pour l'extension inter-package » ; z_session_candidate.dart]
- **D3 — `aggregateDailyStudyTasks` consomme les examens par un PORT NEUTRE `ZApproachingExam` (indirection, AD-1/AD-17).** Le kernel **ne dépend d'AUCUN satellite** : il ne peut PAS importer `zcrud_exam` (ni `ZExam`). ⇒ définir dans le kernel un **port pur-Dart** `abstract interface class ZApproachingExam { bool isApproaching(DateTime now); int? daysUntil(DateTime now); DateTime? get date; }` (précédent EXACT `ZSessionCandidate` : port au kernel, implémenté côté satellite). Signature : `List<ZDailyStudyTask> aggregateDailyStudyTasks({required int dueCount, required Iterable<ZApproachingExam> exams, required DateTime now})`. Le kernel reste **ignorant de `ZExam`** ; l'agrégation est testée avec un **double** local implémentant le port (aucun besoin de `zcrud_exam` dans les tests kernel). [Source: epics.md l.457 « indirection … pour éviter toute dépendance montante » ; z_session_candidate.dart ; architecture AD-1/AD-17]
  - **Le port vit dans `z_daily_study_task.dart`** (couplage fort : `ZExamTask` porte un `ZApproachingExam`) — l'épic nomme 3 fichiers ; on n'en ajoute pas un 4ᵉ.
- **D4 — Frontière de jour = UTC-normalisée, HÉRITÉE du port (ZExam, ES-2.6), + `now` INJECTÉ.** L'agrégation **ne fait aucune arithmétique de date elle-même** : elle DÉLÈGUE à `exam.isApproaching(now)` (filtre) et `exam.daysUntil(now)` (décompte), tous deux **UTC-normalisés et déterministes** dans `ZExam`. Le tri utilise `exam.date` (clé métier). ⇒ aucune décision « UTC vs local » NEUVE ici : elle est déjà tranchée (UTC) et prouvée en amont. **AUCUN `DateTime.now()`/`.toLocal()` caché** dans l'agrégation (leçon ES-2.6). [Source: z_exam.dart l.300-345]
- **D5 — Tri STABLE et DÉTERMINISTE sur date égale (finding anti-`List.sort`-instable).** `List.sort` de Dart **n'est PAS garanti stable**. lex trie `..sort((a,b) => a.date.compareTo(b.date))` : **deux examens de MÊME date ont un ordre NON déterministe** (dépend de l'implémentation du tri). ⇒ l'agrégation DOIT produire un ordre **totalement déterministe** — soit par **tri stable explicite** préservant l'ordre d'entrée sur égalité de date, soit par un **tie-breaker déterministe documenté** (p.ex. ordre d'entrée / index). C'est un **pouvoir discriminant OBSERVÉ** (R2) : un test à deux examens de même date DOIT prouver l'ordre exact. **`date` du port étant `DateTime?`** : `isApproaching(now)==true` implique `date != null` (ZExam le garantit) — mais l'agrégation reste **TOTALE** si un `date == null` fuit (fallback déterministe, jamais de throw / `null!`).
- **D6 — Défensif TOTAL (AD-10), jamais de throw.** `aggregateDailyStudyTasks(dueCount: 0, exams: [], now: …)` → `const []`. `dueCount < 0` → traité comme « pas de dues » (`> 0` faux). Un `ZApproachingExam` dont `isApproaching(now)` throw (implémentation hostile) → l'agrégation ne doit pas laisser fuiter (garde défensive raisonnable ; a minima, le port du repo — `ZExam` — est déjà total). `ZStudySessionResult.fromMap(const {})` → défauts sûrs (`spaced`/`0`/`0`/`{}`), jamais de throw. `byQuality` : `Map` absente/non-`Map` → `{}` ; valeur non-`int` (ou non coercible) → paire **ignorée** ; clés **verbatim** (opaques). Compteur `total`/`correct` absent/non-numérique/négatif → **`0`** (fallback sûr). [Source: AD-10 ; z_folder_contents_order.dart l.300-320 (décodage Map défensif) ; z_exam.dart AC4]
- **D7 — Égalité `byQuality` : COMMUTATIVE sur les clés (l'ordre d'insertion n'a aucun sens), valeurs comparées.** Deux `ZStudySessionResult` aux mêmes paires `byQuality` insérées dans un ordre de clés différent sont **ÉGAUX** (lookup ensembliste, hash **commutatif** — somme, patron `ZFolderContentsOrder._sectionOrdersHash` mais sans niveau ordre-sensible interne car les valeurs sont des `int` scalaires). `byQuality` exposé **NON MODIFIABLE** (`Map.unmodifiable`) aux frontières qui le construisent (immuabilité — une mutation changerait `hashCode` et perdrait l'instance dans son `Set`). [Source: z_folder_contents_order.dart l.397-423]
- **D8 — `gate:web` DEFAULT-ON + littéraux `DateTime` JS-safe.** Les tests kernel tournent sous `dart test` **ET** `dart test -p node`. Construire tous les `now`/`date` via `DateTime.utc(2026, 7, 20, 9, 0)` (arguments explicites, JS-safe) — **jamais** `DateTime.now()` argless. Le seul test touchant `dart:io` (AST anti-`DateTime.now()`, D9) porte **`@TestOn('vm')` + RAISON écrite**. [Source: z_kernel_purity_test.dart l.31 `@TestOn('vm')` ; es-2-6 AC13]
- **D9 — AST anti-`DateTime.now()` NEUF pour le kernel (première fonction horloge du kernel).** Le harnais de pureté kernel existant (`z_kernel_purity_test.dart`) ne scanne QUE `dart:ui`/`package:flutter`/`Color`/`IconData` — **PAS `DateTime.now()`**. `aggregateDailyStudyTasks` est la **PREMIÈRE fonction horloge-dépendante du kernel** ⇒ ajouter un test AST `no_datetime_now_test.dart` (`@TestOn('vm')`) scannant `packages/zcrud_study_kernel/lib/**` et échouant sur toute invocation `DateTime.now()` ou `DateTime()` argless (patron `zcrud_exam/test/no_datetime_now_test.dart`). **R5 : AST/tokenisé documenté, jamais un grep naïf.** [Source: zcrud_exam/test/no_datetime_now_test.dart ; z_kernel_purity_test.dart l.94-108]
- **D10 — `zcrud_exam` NON MODIFIÉ ; câblage `ZExam→port` DÉFÉRÉ au consommateur.** Garder le blast-radius **kernel-only** (story SÉQUENTIELLE « écrit kernel »). `ZExam` a déjà la forme structurelle du port (`isApproaching`/`daysUntil`/`date`) mais ne l'`implements` pas (le port n'existait pas à ES-2.6). L'ajout de `implements ZApproachingExam` (ou d'un adaptateur) est **additif et trivial**, fait par ES-9.2/ES-5 quand ils câbleront la vue. Cette story **prouve** que le contrat colle en le documentant + testant le port avec un double dont la forme est **identique à `ZExam`**.
- **D11 — Surface publique : `hide` côté `zcrud_flashcard` + surface-guard.** `zcrud_flashcard` réexporte le barrel kernel via une liste **`hide`** (jamais `show`). Les nouveaux symboles publics (`ZStudySessionResult`, `ZDailyStudyTask`, `ZDueCardsTask`, `ZExamTask`, `ZApproachingExam`, `aggregateDailyStudyTasks`) sont **study-niveau, NON pertinents flashcard** ⇒ **ajoutés à la liste `hide`** de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (précédent EXACT `ZFolderContentsOrder` d'ES-2.4) et **classés** dans `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` (sinon les tests de surface ÉCHOUENT — plus de fuite silencieuse). [Source: zcrud_flashcard.dart l.66-70 ; zcrud_study_kernel.dart l.35-48]

## Acceptance Criteria

> **Motif dominant du projet à contrer** : « Un artefact de vérification déclaré valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé. Aucune quantité de vert ne détecte un faux vert ; seul un rouge provoqué le peut. » ⇒ Chaque garde/gate naît avec **sa fixture d'échec ISOLÉE (R2)** + son **injection de régression rejouable (R3)**. AST, jamais regex naïf (R5). Aucune dégradation silencieuse (R6). **Un golden d'agrégation qui PASSE PAR COÏNCIDENCE est POWERLESS (leçon ES-2.3)** : les vecteurs d'horloge/tri ont un **pouvoir discriminant OBSERVÉ** — faire VARIER `now` et l'entrée pour PROUVER que la sortie en dépend. **Égalité ordre-sensible vs commutative bien distinguée (leçon ES-2.4).** **Aucun test powerless par chemin qui passerait sans la garde (leçon ES-2.5/DW-ES25-1).** **Aucun `DateTime.now()`/`.toLocal()` caché (leçon ES-2.6).**

### `ZStudySessionResult` — value-object PUR, round-trip défensif

**AC1.** `ZStudySessionResult` est un **value-object PUR** (`class ZStudySessionResult {`) dans `lib/src/domain/z_study_session_result.dart`, **NON `@ZcrudModel`**, **NON `ZEntity`**, **NON `ZExtensible`** (D1). Il porte : `final ZReviewMode mode;` (défaut `ZReviewMode.spaced`), `final int total;` (défaut `0`), `final int correct;` (défaut `0`), `final Map<String,int> byQuality;` (défaut `const <String,int>{}`, exposé **NON MODIFIABLE** — D7). Constructeur nominal **`const`**. Il **n'importe QUE** `package:zcrud_core/domain.dart` (pour `ZReviewMode`… en réalité `ZReviewMode` vient du kernel : import relatif `z_review_mode.dart`) et du Dart pur — **aucun Flutter, aucun codegen, aucun `@JsonSerializable`, aucun `registerZ…`**.

**AC2.** **`factory ZStudySessionResult.fromMap(Map<String,dynamic> map)` défensive et TOTALE (AD-10, D6)** : `mode` = `ZReviewMode` décodé avec repli `spaced` (valeur absente/inconnue → `spaced`, jamais de throw) ; `total`/`correct` = `int` avec fallback **`0`** (absent, non-numérique, ou négatif → `0`) ; `byQuality` = décodage **défensif à 2 niveaux** (map absente/non-`Map` → `{}` ; valeur non-`int`/non-coercible → paire **ignorée** ; clés **verbatim**), rendu **NON MODIFIABLE**. `ZStudySessionResult.fromMap(const <String,dynamic>{})` **ne throw JAMAIS** et rend les défauts. `toMap()` réémet `{mode: mode.name, total, correct, by_quality: {…}}` (snake_case, valeurs d'enum en **camelCase** `name`).
  - **Fixture d'échec ISOLÉE (R2)** : `ZStudySessionResult.fromMap({})` → `mode==spaced, total==0, correct==0, byQuality=={}` ; `fromMap({'total': -3, 'correct': 'x', 'mode': 'inconnu', 'by_quality': 42})` → `total==0, correct==0, mode==spaced, byQuality=={}` ; `fromMap({'by_quality': {'0': 2, '5': 'nan', '3': 4}})` → `byQuality == {'0':2, '3':4}` (paire `'5'` ignorée).
  - **Injection de régression (R3)** : retirer le clamp `total < 0 → 0` (rendre `total` brut) ⇒ `fromMap({'total': -3}).total == -3`, un test ROUGIT ; remplacer le repli `mode` par un cast dur ⇒ `fromMap({'mode': 'inconnu'})` throw, un test ROUGIT.

**AC3.** **Round-trip `Map` idempotent (« round-trip si persisté » de l'AC épic)** : pour toute instance `r` bien formée, `ZStudySessionResult.fromMap(r.toMap()) == r` (égalité de valeur). `by_quality` réémis en `Map<String,int>` plate.
  - **Pouvoir discriminant OBSERVÉ (anti-golden-fortuit, R2)** : la fixture porte `mode: ZReviewMode.whiteExam`, `total: 20`, `correct: 13`, `byQuality: {'0':1,'2':3,'5':9}` — round-trip `==`. **Faire VARIER un champ** (p.ex. `correct: 12`) rend les deux instances **INÉGALES** (prouve que `==` dépend RÉELLEMENT de `correct`, pas un `true` fortuit).
  - **Injection de régression (R3)** : omettre `by_quality` de `toMap()` ⇒ le round-trip perd la répartition, un test ROUGIT.

**AC4.** **Égalité `byQuality` COMMUTATIVE sur les clés (D7)** : `ZStudySessionResult(mode: m, total: t, correct: c, byQuality: {'0':1,'5':2})` **==** la même avec `byQuality: {'5':2,'0':1}` (ordre d'insertion des clés SANS effet), `hashCode` identique. Mais `byQuality: {'0':1}` **!=** `byQuality: {'0':2}` (les valeurs comptent) et `{'0':1}` **!=** `{'1':1}` (les clés comptent).
  - **Fixture d'échec ISOLÉE (R2)** : les 4 assertions ci-dessus (2 égales, 2 inégales).
  - **Injection de régression (R3)** : remplacer l'égalité `byQuality` commutative par `identical`/référence ⇒ le cas « même paires, ordre de clés différent » devient INÉGAL, un test ROUGIT.

### `ZDailyStudyTask` — famille OUVERTE (AD-4, jamais `sealed`)

**AC5.** `ZDailyStudyTask` est **`abstract interface class ZDailyStudyTask { String get kind; }`** dans `lib/src/domain/z_daily_study_task.dart` — **JAMAIS `sealed`** (AD-4 : `sealed` interdit pour l'extension inter-package). Deux variantes concrètes **immuables** :
  - `class ZDueCardsTask implements ZDailyStudyTask { String get kind => 'dueCards'; final int count; }` — `count` strictement `> 0` par construction de l'agrégation (mais l'entité elle-même ne throw pas si `0` : c'est l'agrégation qui n'en émet pas) ; `==`/`hashCode` de valeur.
  - `class ZExamTask implements ZDailyStudyTask { String get kind => 'exam'; final ZApproachingExam exam; final int daysUntil; }` — `==`/`hashCode` de valeur (sur `exam` + `daysUntil`).
  - Le discriminant `kind` est un **`String` opaque** (précédent `ZSessionCandidate.typeKey`) : un consommateur dispatche via `switch (task.kind) { case 'dueCards': … case 'exam': … default: … }` avec **`default` obligatoire** (aucune exhaustivité figée). **Documenter** qu'un satellite peut AJOUTER une variante sans modifier le kernel (AD-4).

**AC6.** **`ZApproachingExam` = port NEUTRE pur-Dart (D3)** dans `z_daily_study_task.dart` : `abstract interface class ZApproachingExam { bool isApproaching(DateTime now); int? daysUntil(DateTime now); DateTime? get date; }`. **AUCUN import de `zcrud_exam`/`ZExam`** — le port est structurellement satisfait par `ZExam` (câblage déféré, D10). Dartdoc citant le précédent `ZSessionCandidate` (port au kernel, implémenté côté satellite) et la garantie d'acyclicité AD-1/AD-17.

### `aggregateDailyStudyTasks` — PURE, TOTALE, DÉTERMINISTE, horloge injectée

**AC7.** `aggregateDailyStudyTasks({required int dueCount, required Iterable<ZApproachingExam> exams, required DateTime now})` → `List<ZDailyStudyTask>` dans `lib/src/domain/aggregate_daily_study_tasks.dart`, **PURE** (aucune I/O, aucune horloge interne, dérivée QUE de ses arguments — D3) :
  - un `ZDueCardsTask(dueCount)` est présent **ssi `dueCount > 0`**, **TOUJOURS en tête** ;
  - un `ZExamTask(e, e.daysUntil(now)!)` pour **chaque** `e` tel que `e.isApproaching(now) == true` (les passés / hors-fenêtre / rappels désactivés sont **exclus** par le port) ;
  - les `ZExamTask` sont triés par **date d'échéance croissante** (`e.date`), placés **après** la ligne dues ;
  - **AUCUN appel à `DateTime.now()`/`DateTime()` argless / `.toLocal()`** — `now` est le SEUL référentiel temporel.

**AC8.** **DÉTERMINISME PROUVÉ (même entrée+`now` → même sortie) ET DÉPENDANCE À `now` PROUVÉE (pouvoir discriminant OBSERVÉ — anti-golden-fortuit, cœur anti-`DateTime.now()`-caché)** :
  - **Déterminisme** : deux appels avec le **même** `now` (littéral `DateTime.utc(2026,7,19,9,0)`) et la même entrée rendent des listes **égales** (élément par élément).
  - **Balayage d'horloge (faire VARIER `now`)** : pour un examen `date == DateTime.utc(2026,7,20)`, `reminderEnabled: true`, `reminderDaysBefore: [7,1]`, balayer `now ∈ {J-7 (07-13), J-1 (07-19), J0 (07-20), J+1 (07-21)}` et **asserter des sorties DISTINCTES** : l'`ExamTask` est **présent** à J-7/J-1/J0 avec `daysUntil ∈ {7,1,0}`, **ABSENT** à J+1 (passé). ⇒ une agrégation qui ignorerait `now` (ou appellerait `DateTime.now()`) **ne pourrait PAS** produire ces 4 sorties : le test le PROUVE.
  - **Frontière de jour (minuit/fuseau) — corrigée par lecture (D4)** : pour un `date == DateTime.utc(2026,7,20)`, un `now` **avant** minuit UTC du 20 (`DateTime.utc(2026,7,19,23,59)`) donne `daysUntil == 1` (examen à venir, `ExamTask` présent) ; un `now` **après** (`DateTime.utc(2026,7,20,0,1)`) donne `daysUntil == 0` (jour J, présent) ; `DateTime.utc(2026,7,21,0,1)` → passé, **absent**. La frontière est **UTC, déterministe, injectée** — prouvé en faisant varier `now` **de part et d'autre** de minuit UTC (jamais un golden à `now` fixe).
  - **Injection de régression (R3)** : remplacer le paramètre `now` par `DateTime.now()` dans le corps ⇒ la suite « balayage d'horloge » ROUGIT (les 4 sorties ne dépendraient plus de l'argument).

**AC9.** **`dueCount` — source unique, jamais recalculé, borné à `> 0`** : `dueCount == 0` (et `< 0`) ⇒ **aucun** `ZDueCardsTask` ; `dueCount == 5` ⇒ `ZDueCardsTask(5)` **en tête**, `count == 5` **verbatim** (l'agrégation ne recalcule ni ne re-borne le compte, parité lex).
  - **Fixture d'échec ISOLÉE (R2)** : `aggregate(dueCount: 0, exams: [], now: …) == const []` ; `aggregate(dueCount: 3, exams: [], now: …)` → `[ZDueCardsTask(3)]` ; `aggregate(dueCount: -1, …)` → pas de `ZDueCardsTask`.

**AC10.** **Tri STABLE et DÉTERMINISTE sur date ÉGALE (D5, finding anti-`List.sort`-instable)** : deux (ou plus) `ZApproachingExam` de **MÊME `date`** produisent des `ZExamTask` dans un ordre **totalement déterministe et documenté** (tri stable préservant l'ordre d'entrée, OU tie-breaker déterministe explicite). L'ordre exact est **asserté** (pas « un ordre quelconque »).
  - **Pouvoir discriminant OBSERVÉ (R2)** : entrée = `[examA(date=D, id=a), examB(date=D, id=b)]` (même `D`, approchants) → sortie `[ZExamTask(examA,…), ZExamTask(examB,…)]` dans l'ordre **PROUVÉ** ; puis entrée inversée `[examB, examA]` → sortie cohérente avec la règle de stabilité documentée (si ordre-d'entrée : `[examB, examA]`). Deux examens de dates **DIFFÉRENTES** (D1 < D2) sortent **TOUJOURS** `[plus-proche, plus-loin]` quel que soit l'ordre d'entrée.
  - **Injection de régression (R3)** : remplacer le tri stable par un `..sort(compareDate)` nu **et** faire dépendre l'assertion de l'ordre exact sur date égale ⇒ le test devient sensible à l'instabilité (documenter que c'est bien la stabilité qui est éprouvée, pas un hasard).

**AC11.** **TOTALITÉ / défensif (AD-10, D6)** : `aggregate(dueCount: 0, exams: const [], now: …)` → `const []` (jamais de throw) ; une liste `exams` où **aucun** n'est approchant → `[]` (ou `[ZDueCardsTask]` si `dueCount>0`) ; l'agrégation ne fait **jamais** `daysUntil(now)!` sur un examen non filtré (l'ordre garde-`isApproaching`-puis-`daysUntil` garantit `date != null` sur les approchants). Un `now` quelconque ne fait jamais throw.

**AC12.** **AUCUN `DateTime.now()`/`DateTime()` argless dans `packages/zcrud_study_kernel/lib/` — PROUVÉ PAR MACHINE (R5, AST/tokenisé, D9)** : un test **NEUF** `no_datetime_now_test.dart` (`@TestOn('vm')` + RAISON écrite — il lit le disque) parse/tokenise les unités de `lib/**` du kernel et **échoue** sur toute invocation `DateTime.now()` ou `DateTime()` sans argument. (Le harnais de pureté existant `z_kernel_purity_test.dart` ne couvre QUE Flutter/`Color` — il ne remplace PAS celui-ci.)
  - **Fixture d'échec ISOLÉE (R2)** : valider le test en injectant **temporairement** un `DateTime.now()` dans `aggregate_daily_study_tasks.dart` → le test ROUGIT (pouvoir discriminant démontré ; jamais un test POWERLESS — leçon DW-ES25-1/ES-2.5). `DateTime.utc(...)` avec arguments et `DateTime.tryParse` restent **autorisés** (ce sont les argless non déterministes qui sont proscrits).

### Intégration surface + gates (R8/R9 — MÊME story)

**AC13.** **Barrel kernel + surface publique (D11)** : les 3 fichiers sont exportés depuis `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (`export 'src/domain/z_study_session_result.dart';`, `export 'src/domain/z_daily_study_task.dart';`, `export 'src/domain/aggregate_daily_study_tasks.dart';`) avec dartdoc de tête (FR-S10, VO/interface ouverte AD-4, port neutre AD-1). Les nouveaux symboles publics (`ZStudySessionResult`, `ZDailyStudyTask`, `ZDueCardsTask`, `ZExamTask`, `ZApproachingExam`, `aggregateDailyStudyTasks`) sont **ajoutés à la liste `hide`** de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (non pertinents flashcard, précédent `ZFolderContentsOrder`) **et classés** dans `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` (hide-list vs allowlist). **AUCUN `hide XxxZcrud`** n'est requis (aucune extension générée : pas de `@ZcrudModel`).
  - **Vérif** : `dart test packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` VERT ; retirer un symbole du `hide` **sans** l'allowlister ⇒ ce test ROUGIT (anti-fuite silencieuse, finding L4 d'ES-1.2).

**AC14.** **AUCUN câblage du gate `reserved-keys` (D1/D2/D4) — et c'est PROUVÉ, pas supposé** : aucun des 3 livrables n'est un `@ZcrudModel` enregistré ⇒ **aucun** `registerZ…` généré, **aucune** entrée à ajouter dans `tool/reserved_keys_gate/lib/src/registrars.dart` (ni `kRegistrars`, ni `kProbeBodies`, ni `kNonExtensibleKinds`, ni `kExtraWriters`, ni `kLegacyUpdatedAtMirrors`). **⛔ NE PAS toucher `registrars.dart`.**
  - **Vérif (anti-inertie, R3)** : `dart run scripts/ci/gate_reserved_keys.dart` reste **VERT sans aucune modification du gate** (le gate dérive `R_disk` d'un `grep 'void registerZ…'` sur les `*.g.dart` — la story n'en génère aucun de neuf) ; `git status` ne montre **aucun** nouveau `.g.dart` sous `packages/zcrud_study_kernel/lib/`. Si un `@ZcrudModel` s'était glissé par erreur, un `registerZ…` apparaîtrait sur disque et le gate ROUGIRAIT (`R_disk \ R_wired ≠ ∅`) — filet automatique.

**AC15.** **`gate:web` DEFAULT-ON (D8)** : tous les tests de VO/tâche/agrégation utilisent des `DateTime.utc(…)` littéraux (JS-safe) et **n'importent PAS `dart:io`** ⇒ ils tournent sous `dart test` **ET** `dart test -p node`. Le SEUL test à `dart:io` (`no_datetime_now_test.dart`, AC12) porte `@TestOn('vm')` + raison. `dart run scripts/ci/gate_web_determinism.dart` VERT.

**AC16.** **Vérif verte REPO-WIDE (R9)** : `melos run generate` OK (**aucun nouveau `.g.dart`** attendu) → `melos run analyze` RC=0 → `melos run test` RC=0 → `dart test` de `zcrud_study_kernel` (VM) **et** `dart test -p node` (JS) RC=0 → `dart run scripts/ci/gate_reserved_keys.dart` VERT (**inchangé**) → `dart run scripts/ci/gate_web_determinism.dart` VERT → `melos run verify` (dont `codegen-distribution`, `graph_proof`/acyclicité **CORE OUT=0**, `secrets`) VERT. **NFR-S10** : le graphe reste ACYCLIQUE ; `zcrud_study_kernel` ne gagne **aucune** arête sortante vers un satellite (`zcrud_exam`/`zcrud_flashcard`) — l'agrégation passe par le port neutre.

## Tasks / Subtasks

- [x] **T1 — `ZStudySessionResult` (VO pur) + tests (AC1–AC4, D1/D6/D7)**
  - [x] `lib/src/domain/z_study_session_result.dart` : classe pure `const` (`mode: ZReviewMode` défaut `spaced`, `total`/`correct: int` défaut `0`, `byQuality: Map<String,int>` défaut `const {}` NON MODIFIABLE), `fromMap` défensif (repli `mode→spaced`, `total`/`correct` clamp `≥0`, `byQuality` décodage 2 niveaux + `unmodifiable`), `toMap` (`by_quality` plate, enum `name`), `==`/`hashCode` (byQuality **commutatif**). Dartdoc citant l'origine lex + D1/D6/D7 + « VO pur, aucun codegen ».
  - [x] `test/z_study_session_result_test.dart` : AC2 (fixtures défensives R2 + injections R3), AC3 (round-trip idempotent + pouvoir discriminant en faisant varier un champ), AC4 (commutativité byQuality + injection R3). Littéraux JS-safe, pas de `dart:io`.
- [x] **T2 — `ZDailyStudyTask` (interface ouverte) + variantes + port `ZApproachingExam` (AC5/AC6, D2/D3)**
  - [x] `lib/src/domain/z_daily_study_task.dart` : `abstract interface class ZDailyStudyTask { String get kind; }` (JAMAIS `sealed`) ; `ZDueCardsTask`/`ZExamTask` immuables (`==`/`hashCode` de valeur) ; port `ZApproachingExam` (aucun import satellite). Dartdoc : AD-4 (pas de sealed, dispatch `kind` + `default`, extension par satellite), précédent `ZSessionCandidate`, D10 (câblage `ZExam` déféré).
  - [x] `test/z_daily_study_task_test.dart` : `kind` de chaque variante ; `==`/`hashCode` (deux `ZExamTask` égaux ssi `exam` + `daysUntil` égaux ; deux `ZDueCardsTask` égaux ssi `count` égal) ; **un double `_FakeApproachingExam`** local (forme identique à `ZExam` : `isApproaching`/`daysUntil`/`date`).
- [x] **T3 — `aggregateDailyStudyTasks` (fonction pure) + tests discriminants (AC7–AC11, D3/D4/D5/D6)**
  - [x] `lib/src/domain/aggregate_daily_study_tasks.dart` : filtre `isApproaching(now)` → tri **STABLE** par `date` (tie-breaker déterministe documenté) → `[if(dueCount>0) ZDueCardsTask(dueCount), …ZExamTask]`. Pure, totale, aucun `DateTime.now()`. Dartdoc : contrat lex porté + D4 (frontière UTC héritée) + D5 (stabilité).
  - [x] `test/aggregate_daily_study_tasks_test.dart` : AC7 (contrat ordre/filtre), **AC8** (déterminisme + **balayage d'horloge J-7…J+1** + **frontière minuit UTC de part et d'autre** + injection R3), AC9 (dueCount 0/>0/<0), **AC10** (tri stable sur date égale — ordre PROUVÉ + dates distinctes), AC11 (vides/défensif). `DateTime.utc(...)` littéraux, double `ZApproachingExam` local.
- [x] **T4 — AST anti-`DateTime.now()` NEUF pour le kernel (AC12, D9)**
  - [x] `test/no_datetime_now_test.dart` (`@TestOn('vm')` + RAISON écrite en tête, patron `zcrud_exam/test/no_datetime_now_test.dart`) : scan AST/tokenisé de `packages/zcrud_study_kernel/lib/**`, échec sur `DateTime.now()`/`DateTime()` argless. **Valider par injection temporaire R2** (documenté dans le Dev Agent Record, remis en état).
- [x] **T5 — Surface publique + guard (AC13, D11)**
  - [x] Barrel `zcrud_study_kernel.dart` : 3 `export` + dartdoc de tête (FR-S10, AD-4, port).
  - [x] `zcrud_flashcard.dart` : ajouter les 6 symboles à la liste `hide` (bloc commenté « ES-2.7 — non pertinents flashcard », précédent `ZFolderContentsOrder`).
  - [x] `z_kernel_surface_guard_test.dart` : les 6 symboles sont **classés dans le `hide`** ⇒ le guard (qui dérive `hidden` du barrel) passe VERT **sans édition** ; aucune allowlist requise (non pertinents flashcard). Prouvé par injection R3(d).
- [x] **T6 — Vérif verte REPO-WIDE + gates (AC14/AC15/AC16, R8/R9)**
  - [x] `melos run generate` (confirmer **aucun** nouveau `.g.dart` ; côté généré propre) → `melos run analyze` RC=0 → `melos run test` RC=0.
  - [x] `dart test` (VM) **et** `dart test -p node` (JS) de `zcrud_study_kernel` RC=0.
  - [x] `dart run scripts/ci/gate_reserved_keys.dart` VERT (**registrars.dart INCHANGÉ**) ; `dart run scripts/ci/gate_web_determinism.dart` VERT ; `melos run verify` (codegen-distribution/graph_proof/secrets) VERT ; acyclicité **CORE OUT=0**, `zcrud_study_kernel` **sans arête** vers un satellite.

## Dev Notes

### Fichiers touchés (blast-radius, kernel-only)

| Fichier | Nature | Note |
|---|---|---|
| `packages/zcrud_study_kernel/lib/src/domain/z_study_session_result.dart` | **NEUF** | VO pur (D1) — aucun `@ZcrudModel` |
| `packages/zcrud_study_kernel/lib/src/domain/z_daily_study_task.dart` | **NEUF** | interface ouverte + variantes + port `ZApproachingExam` (D2/D3) |
| `packages/zcrud_study_kernel/lib/src/domain/aggregate_daily_study_tasks.dart` | **NEUF** | fonction pure (D3/D4/D5) |
| `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` | UPDATE | 3 `export` (AC13) |
| `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` | UPDATE | +6 symboles au `hide` (D11) |
| `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` | UPDATE | classer 6 symboles (D11) |
| `packages/zcrud_study_kernel/test/{z_study_session_result,z_daily_study_task,aggregate_daily_study_tasks,no_datetime_now}_test.dart` | **NEUF** | tests discriminants |

**⛔ NE PAS toucher** : `zcrud_exam`/`ZExam` (D10), `tool/reserved_keys_gate/**` (AC14 — aucun câblage), `zcrud_core`, `kLegacyUpdatedAtMirrors`, tout `*.g.dart`.

### Invariants AD applicables (architecture.md — NON-NÉGOCIABLES)

- **AD-1 / AD-17 (acyclicité)** : le kernel ne dépend d'**aucun satellite**. Le port `ZApproachingExam` est la clé de voûte (précédent `ZSessionCandidate`) : il permet à `aggregateDailyStudyTasks` de consommer `ZExam` **sans l'importer**. `graph_proof` doit rester **CORE OUT=0** et sans nouvelle arête sortante du kernel (AC16).
- **AD-4 (extensibilité)** : `ZDailyStudyTask` est **OUVERTE** (interface + `String kind`), **JAMAIS `sealed`** (`sealed` explicitement rejeté pour l'extension inter-package). Pas de switch exhaustif figé — dispatch `kind` + `default`. Pas de `ZTypeRegistry` (type éphémère non sérialisé — YAGNI, comme ES-2.6 a décliné `ZClock`).
- **AD-3 (codegen / sérialisation)** : `ZStudySessionResult` est un **VO pur SANS codegen** (précédent `ZReminderTime`). `mode` = enum en **camelCase** (`name`) ; persistance en **snake_case** (`by_quality`). `byQuality: Map<String,int>` **n'est pas codegen-able** (le générateur n'a aucune branche `Map`) — raison n°1 de ne PAS le rendre `@ZcrudModel`.
- **AD-10 (défensif)** : ne throw **JAMAIS**. Aucun `assert` (aucun ctor `const` codegen ici, mais principe conservé). Décodage `byQuality`/`total`/`correct`/`mode` à repli sûr. `aggregate([])` → `[]`. Aucun `daysUntil(now)!` sur un examen non filtré.
- **AD-13 (RTL/accessibilité)** : hors périmètre (aucune UI). Zéro `Color`/`IconData`/Flutter dans le kernel (garanti par `z_kernel_purity_test`).
- **AD-16 / AD-19 (sync hors-entité)** : **sans objet ici** — aucun des 3 livrables n'est une entité persistée top-level `@ZcrudModel` ⇒ aucune clé `updated_at`/`is_deleted`, aucun `_reservedKeys`, aucun `ZSyncMeta`. (Si ES-3 décidait un jour de persister `ZStudySessionResult` top-level, ce serait une **décision d'architecture** ré-ouvrant D1 — hors périmètre.)

### Leçons rétro ES-1 (R1–R9) & code-reviews ES-2.x — à APPLIQUER

- **R2 (fixture d'échec ISOLÉE)** : chaque garde naît avec son rouge provoqué — AC2/AC4/AC8/AC10/AC12 portent une injection R3 rejouable.
- **R3 (injection de régression rejouée par l'orchestrateur)** : les manips (retirer clamp, remplacer `now` par `DateTime.now()`, casser le `hide`) sont **listées** pour que l'orchestrateur les REJOUE réellement sur disque (jamais sur la foi du rapport).
- **R4/R-G (trancher par lecture)** : D1–D11 sont ancrées sur la lecture RÉELLE de `lex_core` + des entités kernel livrées — **y compris la CORRECTION du brief** (pas de bucketisation par jour).
- **R5 (AST, pas regex naïf)** : AC12 exige un scan tokenisé/AST (patron `zcrud_exam/test/no_datetime_now_test.dart`).
- **R6 (aucune dégradation silencieuse)** : `byQuality`/`total` corrompus → repli **documenté**, jamais un throw muet ni un « nettoyage » qui perdrait de la donnée.
- **Leçon ES-2.3 (golden fortuit)** : AC8/AC10 **font VARIER** l'entrée/`now` pour PROUVER la dépendance — jamais un golden à `now` fixe.
- **Leçon ES-2.4 (ordre-sensible vs commutatif)** : `byQuality` = **commutatif** (AC4) ; le tri des `ZExamTask` = **ordonné/stable** (AC10). Les deux natures sont **distinguées et testées séparément**.
- **Leçon ES-2.5 (DW-ES25-1, test powerless)** : AC12 est validé par injection (le test ROUGIT réellement) — pas « prouvé » par un chemin qui passerait sans la garde.
- **Leçon ES-2.6 (horloge injectée)** : `now` **PARAMÈTRE**, jamais `DateTime.now()`/`.toLocal()` caché ; frontière de jour **UTC** héritée de `ZExam` (déjà prouvée).

### Pièges connus (mesurés sur ce repo)

1. **`List.sort` NON stable** (D5/AC10) : deux dates égales → ordre non déterministe si tri nu. Utiliser un tri stable / tie-breaker explicite — SINON un golden passera « par chance » puis cassera au premier changement d'implémentation Dart.
2. **`gate:web` default-ON** : un `import 'dart:io'` non taggé dans un test kernel fait ROUGIR `dart test -p node`. Seul `no_datetime_now_test.dart` touche le disque (⇒ `@TestOn('vm')`).
3. **Surface-guard silencieux** : oublier d'ajouter un symbole au `hide` de `zcrud_flashcard` **et** à l'allowlist du guard = fuite. Le test `z_kernel_surface_guard_test.dart` l'attrape — le mettre à jour EN CONSCIENCE (finding L4 d'ES-1.2).
4. **Tentation `@ZcrudModel`** : rendre `ZStudySessionResult` `@ZcrudModel` déclencherait un canal hors-codegen pour `byQuality` + câblage gate complet (R8) pour AUCUN gain. Rester VO pur (D1).
5. **Tentation `sealed`** (parité lex) : interdit par AD-4. Interface ouverte (D2).
6. **Tentation d'importer `zcrud_exam`** dans l'agrégation : casse l'acyclicité (AD-1). Passer par le port `ZApproachingExam` (D3) — le test utilise un double, PAS `ZExam`.

### Commandes de vérif (à rejouer réellement — R9)

```bash
dart run melos run generate            # aucun nouveau *.g.dart attendu
git status --porcelain packages/zcrud_study_kernel/lib   # côté généré : propre
dart run melos run analyze             # RC=0
dart test packages/zcrud_study_kernel  # VM, RC=0
dart test -p node packages/zcrud_study_kernel   # JS, RC=0
dart test packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart
dart run scripts/ci/gate_reserved_keys.dart      # VERT, registrars.dart INCHANGÉ
dart run scripts/ci/gate_web_determinism.dart    # VERT
dart run melos run verify              # graph_proof (CORE OUT=0) / secrets / codegen-distribution
```

## Dev Agent Record

### Context Reference

- Story ES-2.7 (ce fichier). Sources précédents LUS sur disque : `ZReminderTime` (VO pur, ES-2.6), `ZExam.daysUntil/isApproaching` (UTC, horloge injectée, ES-2.6), `ZSessionCandidate` (port neutre kernel), `ZFolderContentsOrder` (décodage Map défensif + hash commutatif, ES-2.4), `zcrud_exam/test/no_datetime_now_test.dart` (scan tokenisé), `z_kernel_purity_test.dart` (garde VM-only), `z_kernel_surface_guard_test.dart` (guard hide/allowlist).

### Agent Model Used

claude-opus-4-8 (subagent bmad-dev-story, effort high).

### Debug Log References

**Injections de régression R3 — rejouées RÉELLEMENT sur disque (RC=1 à chaque fois), restaurées par ÉDITION CIBLÉE :**

- **(a) tri stable neutralisé** (tie-breaker d'index retiré, comparateur `return cmp;`) → `aggregate…_test.dart` « 40 examens de MÊME date » ROUGE : `Which: at location [0] is '13' instead of '00'` (le quicksort de Dart — instable ≥ 40 éléments, mesuré — permute). Restauré.
- **(b) `DateTime.now()` injecté** dans `aggregate_daily_study_tasks.dart` → `no_datetime_now_test.dart` ROUGE : `Fichiers fautifs : [.../aggregate_daily_study_tasks.dart]`. Restauré.
- **(c) filtre `isApproaching` neutralisé** (`if (true)`) → `aggregate…_test.dart` « BALAYAGE D'HORLOGE » ROUGE : `J+1 Expected: null, Actual: ZExamTask(daysUntil: -1)`. Restauré.
- **(d) symbole retiré du `hide` flashcard** (`aggregateDailyStudyTasks`) → `z_kernel_surface_guard_test.dart` ROUGE : `FUITE POTENTIELLE … {aggregateDailyStudyTasks}`. Restauré.

**Portée HONNÊTE de l'AST anti-`DateTime.now()`** : scan tokenisé (commentaires dépouillés) — attrape `DateTime.now(` et `DateTime()` argless littéraux ; **n'attrape PAS** un tearoff `DateTime.now` sans parenthèses (limite documentée en tête du test, leçon LOW-1 ES-2.6). Fixture R2 in-test prouve le pouvoir sans toucher au disque.

**Preuve du pouvoir discriminant du tri stable** : Dart `List.sort` mesuré stable pour n ≤ 33 (insertion-sort), **instable pour n ≥ 40** (dual-pivot quicksort). Le test « 40 examens de même date » choisit n=40 EXPRÈS pour que l'absence de tie-breaker soit OBSERVABLE (sinon un test à 2 éléments passerait « par chance » — leçon ES-2.3).

### Completion Notes List

- ✅ `ZStudySessionResult` = VO **pur** (aucun `@ZcrudModel`/codegen/`registerZ…`) — `fromMap`/`toMap` à la main, `byQuality` décodé défensivement 2 niveaux + `unmodifiable`, `==`/`hashCode` **commutatif** sur `byQuality` (somme de `Object.hash(key,value)`).
- ✅ `ZDailyStudyTask` = `abstract interface class` OUVERTE (JAMAIS `sealed`, AD-4), discriminant `String kind` ; variantes `ZDueCardsTask`/`ZExamTask` immuables ; port neutre `ZApproachingExam` défini DANS le kernel (aucun import `zcrud_exam`).
- ✅ `aggregateDailyStudyTasks` PURE/TOTALE/DÉTERMINISTE : filtre `isApproaching(now)` → tri **stable** `(date, index d'entrée)` → `[dues?, …ZExamTask]`. `now` injecté, `daysUntil(now) ?? 0` (jamais de `!`), `const []` sur vide.
- ✅ **AC14 anti-inertie PROUVÉ** : aucun `.g.dart` généré pour les 3 fichiers (aucun `@ZcrudModel`) ; `gate_reserved_keys.dart` VERT **sans modifier `registrars.dart`**.
- ✅ **NFR-S10 / AD-1** : `graph_proof` → ACYCLIQUE, CORE OUT=0, `zcrud_study_kernel` **sans arête** vers `zcrud_exam`/`zcrud_flashcard` (uniquement → core/annotations/generator).
- ✅ **gate:web** : tests VO/tâche/agrégation JS-safe (`DateTime.utc` littéraux, zéro `dart:io`) ⇒ verts sous `dart test -p node` ; seul `no_datetime_now_test.dart` est `@TestOn('vm')` (+ raison).
- **Décisions D remises en cause (R-G)** : **aucune D falsifiée**. La correction du brief (pas de bucketisation par jour) était déjà actée dans la story (D3/D4) et confirmée par lecture. **D11 nuancé** : le guard passe **sans édition** du test (les 6 symboles sont classés via le `hide`, que le guard dérive automatiquement du barrel) — écrire du code dans le test aurait été inutile ; conforme à « ne pas surpromettre » (DW-ES25-1).
- **Dettes ouvertes** : câblage `ZExam implements ZApproachingExam` DÉFÉRÉ à ES-9.2/ES-5 (D10, hors périmètre) ; persistance éventuelle de `ZStudySessionResult` = ES-3.x (rouvrirait D1 si top-level).

### File List

**NEUFS (kernel) :**
- `packages/zcrud_study_kernel/lib/src/domain/z_study_session_result.dart`
- `packages/zcrud_study_kernel/lib/src/domain/z_daily_study_task.dart`
- `packages/zcrud_study_kernel/lib/src/domain/aggregate_daily_study_tasks.dart`
- `packages/zcrud_study_kernel/test/z_study_session_result_test.dart`
- `packages/zcrud_study_kernel/test/z_daily_study_task_test.dart`
- `packages/zcrud_study_kernel/test/aggregate_daily_study_tasks_test.dart`
- `packages/zcrud_study_kernel/test/no_datetime_now_test.dart`

**MODIFIÉS :**
- `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (+3 `export` ES-2.7, ordre alphabétique)
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (+6 symboles au `hide`)

**NON TOUCHÉS (conformité)** : `tool/reserved_keys_gate/lib/src/registrars.dart` (AC14), `zcrud_exam`/`ZExam` (D10), `zcrud_core`, tout `*.g.dart`, `sprint-status.yaml`.

## Definition of Done

- [x] AC1–AC16 satisfaits ; ACs testables couverts par des tests à **pouvoir discriminant OBSERVÉ** (jamais un golden fortuit).
- [x] `ZStudySessionResult` = VO pur (AUCUN `@ZcrudModel`/codegen/`registerZ…`) ; `ZDailyStudyTask` = interface OUVERTE (JAMAIS `sealed`) ; `aggregateDailyStudyTasks` PURE/TOTALE/DÉTERMINISTE via port `ZApproachingExam` (kernel sans arête satellite).
- [x] `now` INJECTÉ partout ; **zéro** `DateTime.now()`/`DateTime()` argless/`.toLocal()` dans `lib/` — **prouvé par AST** validé par injection (R2).
- [x] Tri **stable/déterministe** sur date égale (AC10) ; `byQuality` **commutatif** (AC4) — natures distinguées.
- [x] Barrel + `hide` `zcrud_flashcard` + surface-guard à jour et VERTS (AC13).
- [x] **AUCUN** câblage du gate `reserved-keys` (registrars.dart INCHANGÉ) — gate VERT sans modification (AC14) ; **aucun** nouveau `.g.dart`.
- [x] Vérif verte REPO-WIDE rejouée : `generate`/`analyze`/`test` (VM+node) RC=0, gates `reserved-keys`/`web-determinism`/`verify` VERTS, acyclicité CORE OUT=0, NFR-S10 (kernel sans dépendance montante).
- [ ] code-review adversariale passée ; findings HIGH/MAJEUR + MEDIUM corrigés (ou MEDIUM justifiés par écrit). _(étape suivante — hors dev-story)_

## Notes pour l'orchestrateur

- **Statut cible de cette étape** : `ready-for-dev`. **Le sprint-status N'EST PAS modifié par cette story** (édition ciblée réservée à l'orchestrateur).
- **Décisions structurantes à valider en code-review** : D1 (`ZStudySessionResult` = VO pur non enregistré), D2 (`ZDailyStudyTask` interface ouverte, pas `sealed`), D3 (port `ZApproachingExam` — kernel sans dépendance à `zcrud_exam`), D5 (tri stable), D10 (`zcrud_exam` non modifié), D11 (surface-guard).
- **Correction du brief à acter** : il n'y a **PAS** de bucketisation par jour calendaire de `ZStudySessionResult` (le brief le supposait) — la vérité source (lex + épic) est une **vue « rythme du jour »** cartes-dues + examens-approchants. Le point de vigilance minuit/fuseau demeure et est couvert par AC8 (frontière UTC injectée, de part et d'autre de minuit).
