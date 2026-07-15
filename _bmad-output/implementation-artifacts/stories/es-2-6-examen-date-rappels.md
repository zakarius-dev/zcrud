# Story ES-2.6 : Examen daté + rappels (`ZExam` / `ZReminderTime`)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur du domaine study zcrud**,
I want **créer un NOUVEAU package pur-Dart `zcrud_exam` modélisant un examen daté rattaché à un dossier avec rappels (`ZExam` : `ZEntity` + `ZExtensible`, `@ZcrudModel`) + un value-object d'heure de rappel (`ZReminderTime`, format `HH:mm`), dont TOUTE la logique de proximité (`daysUntil` / `isPast` / `isApproaching`) est une méthode PURE prenant l'horloge `now` en PARAMÈTRE**,
so that **la proximité d'examen soit déterministe et testable sans jamais appeler `DateTime.now()` en dur (interdit : non déterministe, non testable, et `Date.now()` est littéralement banni des scripts de ce repo), que l'examen se (dé)sérialise zéro-perte avec `updated_at`/`is_deleted` hors-entité (`ZSyncMeta`, AD-19), et qu'importer `zcrud_flashcard`/`zcrud_note` seul n'entraîne JAMAIS le code examens (NFR-S10).**

## Contexte & source de vérité

- **FR couverte** : **FR-S9** — « Examen daté + rappels (`ZExam`/`ZReminderTime`), méthodes pures horloge injectée. » [Source: epics-zcrud-study-2026-07-12/epics.md#FR-S9, table de traçabilité l.113 ; prd-zcrud-study-2026-07-12/prd.md#FR-S9 l.179-183]
- **Épic** : ES-2 (Modélisation du domaine éducatif). **Dépend de** : ES-1 (kernel + gate AD-19.1 + `gate:web` + `ZSyncMeta`), ES-2.2 (`zcrud_note` livré — **GABARIT** du package pur-Dart et du patron `extra`), ES-2.2b (gardes `extra` systémiques MESURÉES), ES-2.5 (leçons `DW-ES25-1`). [Source: epics.md l.169, l.338 ; sprint-status.yaml l.254-264]
- **Package cible** : **NOUVEAU** `packages/zcrud_exam/` (pur-Dart, à la manière EXACTE de `zcrud_note`). Fichiers : `pubspec.yaml`, barrel `lib/zcrud_exam.dart`, `lib/src/domain/{z_exam.dart, z_exam.g.dart, z_reminder_time.dart}`, `test/*_test.dart`. [Source: epics.md l.437 ; sprint-status.yaml l.264 « [M][∥ — zcrud_exam] ZExam/ZReminderTime (horloge injectée) »]
- **Parallélisation** : **PARALLÉLISABLE** — package `zcrud_exam` **disjoint** de `zcrud_document` (ES-2.1/2.5) et `zcrud_note` (ES-2.2/6.1). Le **seul** point de contact possible serait `zcrud_core` : cette story **n'y écrit PAS** (elle consomme uniquement la surface pur-Dart `package:zcrud_core/domain.dart`). Contact secondaire : `tool/reserved_keys_gate` (câblage du gate, R8) — écriture **ciblée additive**, sérialisée si une autre story y touche en même temps. [Source: epics.md l.169, l.338 ; CLAUDE.md « Règles générales »]
- **Sources lex/IFFD à porter (et à DIVERGER)** :
  - `lex_core` / IFFD module « Étude » — entité `Exam` : `{id, folderId, title, date, reminderEnabled, reminderDaysBefore[], reminderTime}`. Le canonique retient la forme lex ; **IFFD est un cas de MIGRATION (ES-11.x), jamais une source de forme** (précédent `ZSmartNote` : IFFD importe `cloud_firestore` → violation NFR-S3). ⚠️ `lex_douane` **n'est PAS présent** sur ce poste (`/home/zakarius/DEV/lex_douane` absent) : la forme est portée depuis le PRD/epics + `docs/canonical-schema.md` (le corpus y référence `ScheduledReminder.payload` comme « Map ouverte non typée » — un patron `extra`/`ZExtension`, PAS un champ typé). [Source: canonical-schema.md l.230, l.255]
- **Convention `HH:mm` déjà dans le cœur** : `ZTimeCodec` (`packages/zcrud_core/lib/src/domain/edition/z_time_codec.dart`) fait déjà `'HH:mm'` ↔ `{hour, minute}`, **pur-Dart, Flutter-free, défensif** (hors bornes → `null`, jamais de throw). `ZReminderTime` s'aligne sur cette convention canonique `HH:mm` (§Dates). [Source: z_time_codec.dart l.1-15]

### Cette story ne livre PAS

- **Aucun widget, aucune UI, aucun éditeur d'examen** : l'UI de création/liste d'examens et le fil de rappels (FR-S30) est **ES-9.2** (`packages/zcrud_exam/lib/src/presentation/z_exam_editor.dart`, composé dans `zcrud_study`). [Source: epics.md l.954-966]
- **Aucun repository, aucune persistance, aucune cascade, aucune notification planifiée** : la persistance des examens et la cascade `folder→exam` sont **ES-3.x** ; le déclenchement système des rappels est app-specific (ES-9). Cette story livre le **domaine pur** + le round-trip `Map`.
- **Aucune agrégation `aggregateDailyStudyTasks`** : elle est **ES-2.7** (`zcrud_study_kernel`, indirection par registre pour éviter une dépendance montante vers `zcrud_exam`). Cette story n'expose QUE les méthodes de proximité que 2.7 consommera. [Source: epics.md l.447-449]
- **Aucune horloge `ZClock` / abstraction de temps** : décision D5 ci-dessous — l'injection est un **paramètre `DateTime now`**, pas un service.

## Décisions structurantes (tranchées PAR LECTURE — R4)

- **D1 — `ZExam` = `ZEntity` + `ZExtensible`.** L'examen est un **contenu personnel top-level à identité propre** (id opaque nullable, AD-14) → patron **ES-2.2b INTÉGRAL** (jumeau `ZSmartNote` / `ZFlashcardTag`) : ctor `const` qui **ne filtre RIEN** (`: _extra = extra`), slot brut `_extra` **lu nulle part ailleurs**, accesseur `extra` **normalisant** (`zNormalizeExtra`, seul point traversé par TOUTES les voies), garde partagée `_sanitizeExtra` (`fromMap` **ET** `copyWith`), `toMap()` étalant l'**accesseur** `...extra`, `copyWith` **à sentinelle** couvrant TOUS les champs, égalité **profonde** `zJsonEquals`/`zJsonHash`. [Source: z_smart_note.dart, z_flashcard_tag.dart ; architecture AD-4]
- **D2 — `ZReminderTime` = value-object PUR, NON `@ZcrudModel`, NON `ZExtensible`.** C'est un couple `{hour, minute}` **persisté en `String` `'HH:mm'`** (convention canonique §Dates, alignée `ZTimeCodec`). Il porte `ZReminderTime.parse(String?)` **défensif** (repli `null`, jamais throw), `toHhmm()`, `==`/`hashCode` de valeur (`Object.hash`). **Il n'est PAS enregistré** (aucun `registerZ…`), donc **RIEN à câbler dans le gate pour lui** (ni `kRegistrars`, ni `kNonExtensibleKinds`).
  - **Pourquoi NON `@ZcrudModel`** : un `@ZcrudModel` utilisé comme champ (`subModel`) est sérialisé par le générateur en **map imbriquée `{hour, minute}`**, jamais en `'HH:mm'`. La FR exige explicitement « value-object + JsonConverter `HH:mm` » (forme persistée `HH:mm`, compat migration lex/IFFD). ⇒ `ZReminderTime` est un VO pur et `ZExam.reminderTime` est un **CANAL HORS-CODEGEN** (patron `ZSmartNote.content` / `ZDocumentReadingState.learning` / `ZFolderContentsOrder.sectionOrders`) décodé/réémis **à la main** en `'HH:mm'`. Cela satisfait **AD-28** (le TYPE `ZReminderTime` dit le format ; aucune `String` `'HH:mm'` ambiguë ne flotte dans l'UI). [Source: z_smart_note.dart l.194-213 ; generator `_classify` l.440-486]
- **D3 — `reminderTime` est un CANAL HORS-CODEGEN, clé réservée `reminder_time`.** ⚠️ **Contrainte de gate DURE, mesurée sur disque** : la règle **(g)** de `scripts/ci/gate_reserved_keys.dart` (`_channelsOf`, l.523-588) flague **TOUT champ d'instance** d'une classe `@ZcrudModel ZExtensible` qui n'est **ni `@ZcrudField`/`@ZcrudId`**, ni `extra`/`extension`/support `_extra`. Elle **ne se limite PAS aux types `Map`/`List`** : `final ZReminderTime? reminderTime;` **SERA** détecté comme canal de clé `reminder_time`. ⇒ **(g1)** `reminder_time` **DOIT** figurer dans `ZExam._reservedKeys` (sinon gate ROUGE) ; **(g2)** `kProbeBodies['exam']` **DOIT** porter `reminder_time` **NON VIDE** (sinon gate ROUGE). La clé persistée **DOIT** être le snake_case du nom de champ (`reminderTime` → `reminder_time`), déclarée **une seule fois** en `const String kReminderTimeKey = 'reminder_time';`. [Source: gate_reserved_keys.dart l.79-115, l.500-588]
- **D4 — `DateTime` codegen-able en ISO-8601.** Le générateur supporte `DateTime` (`_classify` → `dateTimeType`) : `fromMap` via `_$asDateTime` (`DateTime.tryParse`, défensif → `null`), `toMap` via `?.toIso8601String()`. Précédent EXACT : `ZSmartNote.createdAt` / `ZStudyDocument.createdAt`. ⇒ **`date` est un `@ZcrudField DateTime?` NORMAL** (pas un canal hors-codegen). [Source: z_smart_note.g.dart l.131-133, l.182, l.192 ; generator l.468-469, l.512-513, l.612-613]
- **D5 — Horloge injectée = PARAMÈTRE `DateTime now`, PAS de `ZClock`.** La FR dit « les méthodes prennent l'horloge injectée (`now`) ». Le repo **n'a AUCUN `ZClock`/`DateTime Function()`** (vérifié). N'en inventer aucun (YAGNI ; AD interdit d'inventer une abstraction non requise) : `int? daysUntil(DateTime now)`, `bool isPast(DateTime now)`, `bool isApproaching(DateTime now)` — signatures **totales, pures, déterministes**. [Source: prd.md#FR-S9 l.183 ; epics.md l.445-447]
- **D6 — `date` NULLABLE, méthodes TOTALES sur `null`.** Un `DateTime` n'a **aucun constructeur `const`** : un champ non-nullable exigerait `required` (friction probe/copyWith/gate). Précédent : `createdAt` est `DateTime?`. ⇒ `date` est `@ZcrudField DateTime? date` (défaut `const` `null`). Les méthodes de proximité sont **totales** : `date == null` ⇒ `daysUntil` rend `null`, `isPast`/`isApproaching` rendent `false` (rien à comparer). C'est le repli sûr AD-10 « champ absent → défaut sûr, jamais throw ». [Source: AD-10 ; z_smart_note.dart l.215-222]

## Acceptance Criteria

> **Motif dominant du projet à contrer** : « Un artefact de vérification déclaré valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé. Aucune quantité de vert ne détecte un faux vert ; seul un rouge provoqué le peut. » ⇒ Chaque garde/gate naît avec **sa fixture d'échec ISOLÉE (R2)** + son **injection de régression rejouable (R3)**. AST, jamais regex (R5). Aucune dégradation silencieuse (R6). Un golden temporel qui PASSE PAR COÏNCIDENCE est POWERLESS (leçon ES-2.3) : les vecteurs d'horloge ont un **pouvoir discriminant OBSERVÉ** (faire VARIER `now`).

### `ZReminderTime` — value-object `HH:mm` défensif

**AC1.** `ZReminderTime` est un **value-object PUR** (`class ZReminderTime {`), **NON `@ZcrudModel`**, **NON `ZExtensible`**, dans `lib/src/domain/z_reminder_time.dart`. Il porte deux `int` `final` (`hour`, `minute`), un constructeur nominal **`const ZReminderTime({required this.hour, required this.minute})`** (ou avec défauts), `==`/`hashCode` de valeur (`Object.hash(hour, minute)`). Il **n'importe QUE** du Dart pur (aucun Flutter, aucun `TimeOfDay`).

**AC2.** **`factory ZReminderTime.parse(String? hhmm)` défensif et TOTAL (AD-10)** : accepte `'HH:mm'` (et tolère `'HH:mm:ss'`, secondes tronquées, parité `ZTimeCodec.hhmmToMap`) ; rend **`null`** — jamais un throw — si `hhmm` est `null`, non parsable, ou hors bornes (`hour ∉ [0,23]` **ou** `minute ∉ [0,59]`). `ZReminderTime.toHhmm()` rend la chaîne zéro-paddée `'HH:mm'` (24 h). Round-trip : `ZReminderTime.parse(t.toHhmm()) == t` pour tout `t` valide.
  - **Fixture d'échec ISOLÉE (R2)** : `ZReminderTime.parse('25:00')`, `parse('08:99')`, `parse('huit heures')`, `parse('')`, `parse(null)` ⇒ **tous `null`** ; `parse('8:5')` et `parse('08:05')` ⇒ `hour==8, minute==5` ; `ZReminderTime(hour: 8, minute: 5).toHhmm() == '08:05'`.
  - **Injection de régression (R3)** : remplacer la borne `minute > 59` par `minute > 60` (ou retirer la garde de bornes) doit rendre un test ROUGE (`parse('08:60')` cesserait de rendre `null`).

### `ZExam` — entité `@ZcrudModel` + `ZExtensible`, round-trip zéro-perte

**AC3.** `ZExam` est une **`@ZcrudModel(kind: 'exam')` classe `extends ZEntity with ZExtensible`** portant :
  - `id` : `@override @ZcrudId() final String? id;` (opaque, nullable — éphémère AD-14, jamais attribué par l'entité) ;
  - `folderId` : `@ZcrudField() final String folderId;` (défaut `''`, clé **NEUTRE** `String` — **aucun symbole de `zcrud_study_kernel` importé**, leçon L2/D7 de `ZSmartNote.folderId`) ;
  - `title` : `@ZcrudField(label: 'Examen') final String title;` (défaut `''`) ;
  - `date` : `@ZcrudField() final DateTime? date;` (D4/D6, persisté ISO-8601 `date`, défaut `null`) ;
  - `reminderEnabled` : `@ZcrudField() final bool reminderEnabled;` (persisté `reminder_enabled`, défaut `false`) ;
  - `reminderDaysBefore` : `@ZcrudField() final List<int> reminderDaysBefore;` (persisté `reminder_days_before`, chemin `listScalar` **natif codegen**, défaut `const <int>[]`) ;
  - `reminderTime` : `final ZReminderTime? reminderTime;` — **CANAL HORS-CODEGEN** (D2/D3), persisté `reminder_time` en `'HH:mm'` `String`, défaut `null`, **PAS d'annotation `@ZcrudField`** ;
  - `extension` : `@override final ZExtension? extension;` (slot AD-4 pt.1) ;
  - `extra` : accesseur `@override Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);` + slot brut `final Map<String, dynamic> _extra;`.
  - Constructeur nominal **`const`** (patron `ZSmartNote` : `// ignore: prefer_initializing_formals` + `: _extra = extra`). **⛔ AUCUN `assert` dans le ctor `const`** (AD-10 — le décodeur généré l'appelle avec des valeurs BRUTES ; un `assert` ferait échouer la désérialisation d'une donnée corrompue).

**AC4.** **`factory ZExam.fromMap(Map<String,dynamic> map, {ZExamExtensionParser? extensionParser})` défensive, non-nue (AD-10)** : délègue à `_$ZExamFromMap` généré pour les champs de schéma (`folder_id`/`title` absents → `''` ; `date` illisible → `null` ; `reminder_enabled` absent → `false` ; `reminder_days_before` illisible → `const []`), **puis câble les canaux hors-codegen** : `reminderTime: ZReminderTime.parse(map[kReminderTimeKey] as String?)` (défensif) ; `extension` via `extensionParser` (repli `null`, `ZExtension.guard`) ; `extra: _extraFrom(map)`. **⛔ Corps NON NU obligatoire** : une délégation nue à `_$ZExamFromMap` laisserait `extra` VIDE — le build la REFUSE (`_rejectNakedCodegenDelegation`) et le garde runtime `_$zRequireExtraPreserved` lèverait à l'enregistrement. `ZExam.fromMap(const <String,dynamic>{})` **ne throw JAMAIS**.
  - **Fixture d'échec ISOLÉE (R2)** : `ZExam.fromMap({})` rend une instance sur les défauts ; `ZExam.fromMap({'date': 'pas-une-date'})` ⇒ `date == null` (pas de throw) ; `ZExam.fromMap({'reminder_time': '99:99'})` ⇒ `reminderTime == null`.

**AC5.** **Round-trip `Map` idempotent et ZÉRO-PERTE** : `toMap()` réutilise le `toMap()` **généré** (`ZExamZcrud(this).toMap()`, champs de schéma) puis superpose les canaux hors-codegen — `...extra` (l'**ACCESSEUR** qui NORMALISE, jamais `_extra` brut), `kReminderTimeKey: reminderTime?.toHhmm()` **si `reminderTime != null`** (sinon clé omise, patron nullable), et `extension.toJson()` si `extension != null`. Pour toute `map` bien formée, `ZExam.fromMap(m).toMap()` réémet **exactement** les mêmes clés/valeurs (y compris `reminder_days_before` ordonné et une clé legacy inconnue portée par `extra`).
  - **Pouvoir discriminant OBSERVÉ (anti-golden-fortuit)** : la fixture round-trip porte une clé inconnue (`'legacy_note': {...}` imbriquée), un `reminder_days_before: [7, 1]` (**ordre préservé**), un `reminder_time: '08:30'`. `fromMap(m) == fromMap(m)` (égalité PROFONDE) **ET** `fromMap(m).toMap()` re-décodée redonne une instance `==`.
  - **Injection de régression (R3)** : retirer la ligne `kReminderTimeKey: reminderTime?.toHhmm()` de `toMap()` doit rendre un test ROUGE (le round-trip perd l'heure de rappel).

**AC6.** **AD-19 — AUCUN horodatage de sync inline.** `ZExam` ne déclare **NI `updatedAt` NI `isDeleted`** : l'autorité Last-Write-Wins et le soft-delete vivent **HORS-ENTITÉ** (`ZSyncMeta`). `ZExam._reservedKeys ⊇ ZSyncMeta.reservedKeys` (`{updated_at, is_deleted}`) — ces clés, écrites **dans le corps** par le store avant `fromMap`, ne tombent JAMAIS dans `extra` (AD-4) et ne sont JAMAIS réémises par `toMap()` (AD-16). **La date d'examen (`date`) est une clé MÉTIER `date` DISTINCTE de toute clé de sync** (aucune collision).
  - **Fixture d'échec ISOLÉE (R2)** : `ZExam.fromMap({..., 'updated_at': '1999-01-01', 'is_deleted': true}).extra` ne contient NI `updated_at` NI `is_deleted` ; `ZExam.fromMap({...}).toMap()` ne contient NI `updated_at` NI `is_deleted`.
  - **Injection de régression (R3)** : `exam.copyWith(extra: {'updated_at': 'x', 'is_deleted': true}).toMap()` ne réémet toujours PAS ces clés (garde partagée `_sanitizeExtra` sur les DEUX frontières — leçon H2/MAJEUR-3 de `ZSmartNote`) ; retirer `...ZSyncMeta.reservedKeys` de `_reservedKeys` rend un test ROUGE.

**AC7.** **Patron `extra` ES-2.2b INTÉGRAL (garde INCONDITIONNELLE, DW-ES22-3/DW-ES22-4).** L'accesseur `extra` NORMALISE (`zNormalizeExtra`) — la garde tient **quelle que soit la voie d'écriture, y compris le constructeur `const`** (seule voie incapable de filtrer). `copyWith` **à sentinelle** couvre TOUS les champs (dont `reminderTime`, `extension`, `extra`) via `_$undefined` — le `copyWith` GÉNÉRÉ les remettrait à leurs DÉFAUTS (perte silencieuse, finding H3). `copyWith(extra:)` passe par la **MÊME fonction nommée** `_sanitizeExtra` qu'en `fromMap` (ne peut ROUVRIR le filtre — DW-ES22-3). Égalité **PROFONDE** sur `extra` (`zJsonEquals`/`zJsonHash`) : un `extra` legacy IMBRIQUÉ (`Map`/`List`) ne casse pas `fromMap(m) == fromMap(m)` (DW-ES22-4).
  - **Fixture d'échec ISOLÉE (R2)** : `ZExam(extra: {'updated_at': 'x'}).extra` (voie **CONSTRUCTEUR**, la polluante) est VIDE de clés réservées ; `ZExam(extra: {'k': {'nested': [1,2]}}) == ZExam(extra: {'k': {'nested': [1,2]}})` (égalité profonde).
  - **Injection de régression (R3)** : remplacer `zJsonEquals(extra, other.extra)` par `extra == other.extra` (égalité superficielle) rend le test d'`extra` imbriqué ROUGE ; retirer `_sanitizeExtra` de `copyWith` rend le test de la voie `copyWith` ROUGE.

### Méthodes de proximité — PURES, TOTALES, DÉTERMINISTES, horloge injectée

**AC8.** `ZExam` expose trois méthodes **pures** prenant `DateTime now` en **PARAMÈTRE** (D5) — **AUCUN appel à `DateTime.now()`/`DateTime()` argless dans le domaine** :
  - `int? daysUntil(DateTime now)` : nombre de jours **calendaires** (comparaison sur la date normalisée, UTC pour éviter la dérive DST/fuseau) de `now` jusqu'à `date` ; **`null` si `date == null`**. Positif = futur, négatif = passé, `0` = même jour.
  - `bool isPast(DateTime now)` : `date != null && daysUntil(now)! < 0` (l'examen est strictement passé) ; `false` si `date == null`.
  - `bool isApproaching(DateTime now)` : `reminderEnabled && date != null && !isPast(now) && reminderDaysBefore.any((d) => daysUntil(now)! <= d)` (un rappel est dû aujourd'hui ou l'échéance approche sous l'un des seuils). `false` si `date == null`, si `reminderEnabled == false`, ou si `reminderDaysBefore` est vide. *(La sémantique exacte de « approchant » est tranchée par le dev ; elle DOIT être documentée, totale, et couverte par les vecteurs discriminants ci-dessous.)*

**AC9.** **DÉTERMINISME PROUVÉ (même `now` → même sortie) ET DÉPENDANCE PROUVÉE (la sortie dépend de `now`, et QUE de `now` + l'état de l'examen)** — le cœur anti-`DateTime.now()`-caché :
  - **Déterminisme** : deux appels `exam.daysUntil(now)` avec le **même** `now` (littéral `DateTime.utc(2026, 7, 20, 9, 0)`) rendent la **même** valeur.
  - **Pouvoir discriminant OBSERVÉ (faire VARIER l'horloge)** : pour un `date == DateTime.utc(2026, 7, 20)`, balayer `now` sur `{2026-07-13 (J-7), 2026-07-19 (J-1), 2026-07-20 (J0), 2026-07-21 (J+1)}` et **asserter des sorties DISTINCTES** : `daysUntil` = `{7, 1, 0, -1}` ; `isPast` = `{false, false, false, true}`. Avec `reminderEnabled: true, reminderDaysBefore: [7, 1]` : `isApproaching` = `{true, true, true, false}` (à J-7 le seuil 7 déclenche ; à J+1 c'est passé). ⇒ **une méthode qui ignorerait `now` (ou appellerait `DateTime.now()`) ne pourrait PAS produire ces 4 sorties distinctes** : le test le PROUVE (un `DateTime.now()` caché passerait un golden à `now` fixe, mais ÉCHOUE dès que `now` varie).
  - **Injection de régression (R3)** : remplacer un `now` paramètre par `DateTime.now()` dans le corps d'une méthode rend la suite « balayage d'horloge » ROUGE (les 4 sorties ne dépendraient plus de l'argument).

**AC10.** **AUCUN `DateTime.now()` / `DateTime()` argless dans `packages/zcrud_exam/lib/` — PROUVÉ PAR MACHINE (R5 : AST/analyse, pas un simple grep).** Un test (`@TestOn('vm')`, il lit le disque — cf. AC13) parse les unités sources de `lib/` (via `package:analyzer` ou, à défaut, un scan tokenisé documenté) et **échoue s'il trouve une invocation `DateTime.now()` ou `DateTime()` sans argument** dans le domaine. *(Le `.g.dart` généré n'en contient pas ; s'il fallait l'exclure, l'exclusion est écrite.)*
  - **Fixture d'échec ISOLÉE (R2)** : le test lui-même est validé en injectant temporairement un `DateTime.now()` dans une méthode → le test ROUGIT (pouvoir discriminant démontré, jamais un test POWERLESS — leçon `DW-ES25-1`/ES-2.5 : un test qui « prouverait » par un chemin qui passerait même sans la garde est un mensonge d'artefact).

### Intégration workspace + gate (R8 — MÊME story)

**AC11.** **Nouveau package intégré au workspace** : `packages/zcrud_exam/pubspec.yaml` (`name: zcrud_exam`, `publish_to: none`, `resolution: workspace`, `environment: sdk: ^3.12.2`, `dependencies: {zcrud_core: ^0.1.0, zcrud_annotations: ^0.1.0}`, `dev_dependencies: {zcrud_generator: ^0.1.0, build_runner: ^2.5.0, test: ^1.25.0}` — GABARIT `zcrud_note`, **zéro** dép lourde / Flutter / Firebase / gestionnaire d'état). Le membre `- packages/zcrud_exam` est ajouté au bloc `workspace:` du `pubspec.yaml` **RACINE** (seul point de déclaration ; `melos list` le prend via le glob `packages/**`). Barrel `lib/zcrud_exam.dart` exportant `z_reminder_time.dart` et `z_exam.dart` **avec `hide ZExamZcrud`** (règle (h) : aucune extension générée n'est exportée — sinon `ZExamZcrud(e).copyWith(...)` DÉTRUIRAIT `reminderTime`/`extra`/`extension`, finding H3). `.g.dart` **suivi par git** (gate `codegen-distribution`). **`melos list` passe de 17 à 18 packages.**
  - **Vérif** : `dart pub get` (workspace) OK ; `melos list | wc -l` == 18 ; `melos run generate` émet `z_exam.g.dart` ; le graphe reste **ACYCLIQUE / CORE OUT=0** (`scripts/dev/graph_proof.py`).

**AC12.** **Câblage du gate reserved-keys DANS CETTE STORY (R8) — sinon `ZExam` naît NON SONDÉE (faux vert par omission)** :
  - Ajouter `zcrud_exam: ^0.1.0` aux `dependencies:` de `tool/reserved_keys_gate/pubspec.yaml` (**NOUVELLE dépendance** — `zcrud_exam` n'y est pas encore, contrairement à `zcrud_document`/`zcrud_note`) + `import 'package:zcrud_exam/zcrud_exam.dart';` dans `registrars.dart`.
  - `kRegistrars` += `registerZExam` (kind `exam` — zcrud_exam).
  - `kProbeBodies['exam']` = corps minimal valide **PORTANT LE CANAL HORS-CODEGEN `reminder_time` NON VIDE** (règle (g2)) **et** `reminder_days_before` : p.ex. `{'id': 'p', 'folder_id': 'f', 'title': 't', 'date': '2026-07-20T00:00:00.000Z', 'reminder_enabled': true, 'reminder_days_before': [7, 1], 'reminder_time': '08:30'}`. ⚠️ Une sonde SANS `reminder_time` (ou avec une valeur vide) rendrait le canal « préservé PAR PROSE » et laisserait le gate VERT si on retirait `kReminderTimeKey` de `_reservedKeys` (finding H1/H2 à NE PAS rejouer).
  - `kExtraWriters['exam']` = **DEUX** voies VERBATIM (règle AST (j)/(k)) : `ZExtraWriter(voie: 'ctor', write: _ctorExam, eagerlyNormalized: false)` (ctor `const` : ne filtre RIEN) **et** `ZExtraWriter(voie: 'copyWith', write: _copyWithExam, eagerlyNormalized: true)`. `_ctorExam` reconstruit `ZExam` en recopiant **tous** les champs (dont `reminderTime`) et en passant `extra: x` **VERBATIM** ; `_copyWithExam` = `(e as ZExam).copyWith(extra: x)`.
  - `kNonExtensibleKinds` : **AUCUN ajout** (`ZReminderTime` n'est PAS enregistré — VO pur ; `ZExam` EST `ZExtensible`).
  - ⛔ **NE PAS toucher** `kLegacyUpdatedAtMirrors` (`ZExam` n'a aucun miroir `updated_at` : la sync est hors-entité dès l'origine, comme `ZFlashcardTag`/mindmap).
  - **Vérif (R3, rejouée par l'orchestrateur)** : `dart run scripts/ci/gate_reserved_keys.dart` VERT ; puis, injection — retirer `registerZExam` de `kRegistrars` ⇒ gate ROUGE (`R_disk \ R_wired ≠ ∅`) ; retirer `reminder_time` de `_reservedKeys` ⇒ gate ROUGE (règle (g1)) ; retirer la voie `ctor` de `kExtraWriters['exam']` ⇒ gate ROUGE (règle (j)).

**AC13.** **`gate:web` DEFAULT-ON — piège d'environnement CONNU pour ce package pur-Dart.** `zcrud_exam` (pur-Dart avec `test/`) est **AUTO-DÉCOUVERT** par `scripts/ci/gate_web_determinism.dart` **à sa création, sans éditer le gate** (périmètre default-ON). Conséquence DURE : **tout test important `dart:io`** (p.ex. le test AST anti-`DateTime.now()` d'AC10, ou un `source_policy_test.dart`) **DOIT** être taggé **`@TestOn('vm')` avec une RAISON ÉCRITE** en tête de fichier (patron `zcrud_note/test/source_policy_test.dart` + `z_note_content_test.dart` l.396-398) — sinon `dart test -p node` échoue et le gate ROUGIT. Les **tests d'horloge NE DOIVENT PAS** toucher `dart:io` : l'horloge est un **littéral injecté** — construire les `DateTime` via `DateTime.utc(2026, 7, 20, 9, 0)` (arguments explicites), **JS-safe** (c'est `DateTime.now()` argless, non déterministe, qui est proscrit — pas `DateTime.utc(...)` avec arguments ni `DateTime.tryParse`). ⇒ les tests de round-trip / proximité / `ZReminderTime` tournent **sous `dart test` ET `dart test -p node`** sans tag.
  - **Vérif** : `dart run scripts/ci/gate_web_determinism.dart` VERT (Node présent) — `zcrud_exam` apparaît dans la cible ; aucun test non taggé n'importe `dart:io`.

**AC14.** **Vérif verte REPO-WIDE (R9)** : `melos run generate` OK (avec `z_exam.g.dart` **committé**) → `melos run analyze` RC=0 → `melos run test` RC=0 → `dart test` de `zcrud_exam` (VM) **et** `dart test -p node` (JS) RC=0 → `dart run scripts/ci/gate_reserved_keys.dart` VERT → `dart run scripts/ci/gate_web_determinism.dart` VERT → `melos run verify` (dont `codegen-distribution`, `graph_proof`, `secrets`) VERT. **NFR-S10** : importer `zcrud_flashcard`/`zcrud_note` seul n'ajoute PAS `zcrud_exam` au graphe (aucune arête entrante vers `zcrud_exam`).

## Tasks / Subtasks

- [x] **T1 — Créer le package `zcrud_exam` + intégration workspace (AC11)**
  - [x] `packages/zcrud_exam/pubspec.yaml` (GABARIT `zcrud_note` : `resolution: workspace`, deps `{zcrud_core, zcrud_annotations}`, dev-deps `{zcrud_generator, build_runner, test}`, dartdoc de tête expliquant les arêtes acycliques + « aucune dép lourde/Flutter/Firebase/état »).
  - [x] Ajouter `- packages/zcrud_exam` au bloc `workspace:` du `pubspec.yaml` RACINE (avec commentaire de justification, patron des membres existants).
  - [x] `lib/zcrud_exam.dart` (barrel) : `export 'src/domain/z_reminder_time.dart';` + `export 'src/domain/z_exam.dart' hide ZExamZcrud;` (règle (h)) + dartdoc de bibliothèque (FR-S9, AD-19, AD-28, patron `extra`).
  - [x] `dart pub get` ; vérifier `melos list | wc -l == 18`.
- [x] **T2 — `ZReminderTime` (VO `HH:mm`) + tests (AC1, AC2)**
  - [x] `lib/src/domain/z_reminder_time.dart` : `class ZReminderTime` (VO pur, `const` ctor, `hour`/`minute`, `parse`/`toHhmm`, `==`/`hashCode`).
  - [x] `test/z_reminder_time_test.dart` : bornes, non-parsable, round-trip, égalité + fixture d'échec R2.
- [x] **T3 — `ZExam` (`@ZcrudModel` + `ZExtensible`) + `.g.dart` (AC3, AC4, AC5, AC6, AC7)**
  - [x] `lib/src/domain/z_exam.dart` : `const String kReminderTimeKey = 'reminder_time';`, `typedef ZExamExtensionParser`, classe `ZExam`, ctor `const`, `fromMap` non-nue, `toMap`, `copyWith` à sentinelle, `_reservedKeys` (⊇ `ZSyncMeta.reservedKeys` + `kReminderTimeKey` + `'extension'` + `$ZExamFieldSpecs`), `_extraFrom`/`_sanitizeExtra`, `_decodeExtension`, `==`/`hashCode` profonds.
  - [x] `melos run generate` → `z_exam.g.dart` (COMMITTÉ) ; vérifier `date`→ISO-8601, `reminder_days_before`→`listScalar`.
  - [x] `test/z_exam_test.dart` : round-trip zéro-perte (vecteurs discriminants AC5), `fromMap({})` sûr, AD-19 (AC6), patron `extra` ES-2.2b voies ctor+copyWith (AC7), date corrompue → null.
- [x] **T4 — Méthodes de proximité pures + déterminisme (AC8, AC9, AC10)**
  - [x] `daysUntil`/`isPast`/`isApproaching(DateTime now)` (totales sur `date == null`, doc de sémantique).
  - [x] `test/z_exam_clock_test.dart` : balayage d'horloge {J-7, J-1, J0, J+1} → sorties distinctes (AC9) ; déterminisme (même `now` → même sortie) ; **DateTime.utc littéraux, aucun `dart:io`**.
  - [x] `test/no_datetime_now_test.dart` (**`@TestOn('vm')` + raison écrite**) : AST/scan anti-`DateTime.now()` dans `lib/` (AC10) + fixture d'échec R2.
- [x] **T5 — Câblage gate reserved-keys (R8, AC12)**
  - [x] `tool/reserved_keys_gate/pubspec.yaml` : += `zcrud_exam: ^0.1.0`.
  - [x] `registrars.dart` : import ; `kRegistrars += registerZExam` ; `kProbeBodies['exam']` (avec `reminder_time` NON VIDE + `reminder_days_before`) ; `kExtraWriters['exam']` (ctor VERBATIM + copyWith) ; `_ctorExam`/`_copyWithExam`.
  - [x] `dart run scripts/ci/gate_reserved_keys.dart` VERT.
- [x] **T6 — Vérif verte REPO-WIDE + injections R3 (AC13, AC14)**
  - [x] `melos run generate` (g.dart committé) → `melos run analyze` RC0 → `melos run test` RC0 → `dart test -p node` (zcrud_exam) RC0 → gate reserved-keys VERT → `gate_web_determinism` VERT → `melos run verify` VERT.
  - [x] Rejouer chaque injection de régression R3 des ACs (heure retirée du `toMap`, `now`→`DateTime.now()`, registrar/reserved-key/voie retirés) et confirmer le ROUGE, puis restaurer.

## Dev Notes

### Patrons & fichiers de référence (À LIRE avant de coder)
- **GABARIT package pur-Dart** : `packages/zcrud_note/` (pubspec, barrel `hide XxxZcrud`, tests `dart test`). [ES-2.2]
- **GABARIT entité `ZExtensible` + canal hors-codegen** : `packages/zcrud_note/lib/src/domain/z_smart_note.dart` — copier le squelette (ctor `const` `: _extra = extra`, `fromMap` non-nue, `toMap` `...extra` + canal + `extension`, `copyWith` sentinelle, `_reservedKeys`, `_sanitizeExtra`, `==`/`hashCode` profonds). Le canal `content` est le **jumeau exact** de `reminderTime` (décodé/réémis à la main, clé réservée, probe non-vide).
- **GABARIT `extra` intégral jumeau** : `packages/zcrud_study_kernel/lib/src/domain/z_flashcard_tag.dart` (`zSanitizeExtra`/`zJsonEquals`/`zJsonHash` du cœur).
- **VO `HH:mm` pur-Dart défensif** : `packages/zcrud_core/lib/src/domain/edition/z_time_codec.dart` (réutiliser la mécanique `parse`/bornes ; `ZReminderTime` peut s'appuyer sur `ZTimeCodec.hhmmToMap`/`hhmmToMinutesOfDay` ou répliquer la logique — au choix du dev, mais défensif TOTAL).
- **Helpers cœur (surface `package:zcrud_core/domain.dart`)** : `ZEntity`, `ZExtensible`, `ZExtension`, `ZSyncMeta` (`.reservedKeys`), `zNormalizeExtra`, `zSanitizeExtra`, `zJsonEquals`, `zJsonHash`, `_$undefined` (sentinelle). **Importer `domain.dart`, JAMAIS le barrel principal** (qui tire Flutter et casserait `dart test`).

### Invariants AD applicables (chaque story, NON-NÉGOCIABLES)
- **AD-3** : `@ZcrudModel`/`@ZcrudField`, `@JsonSerializable` pur, `fieldRename: snake`, enums camelCase. `date` persisté ISO-8601 (`toIso8601String`/`tryParse`). `reminder_days_before` = `List<int>` natif (`listScalar`).
- **AD-4** : slot `ZExtension?` versionné + `extra: Map` + (pas de `ZTypeRegistry` requis ici). `ZReminderTime` = VO (pas un point d'extension).
- **AD-10 défensif** : ne throw JAMAIS. Aucun `assert` dans le ctor `const`. `date`/`reminderTime` illisibles → `null`. `fromMap(const {})` sûr.
- **AD-13** : (aucune UI ici, mais) pas de style/couleur codé en dur.
- **AD-14** : `id` opaque nullable, jamais attribué par l'entité (repository, ES-3).
- **AD-16 / AD-19 / AD-19.1** : `updated_at`/`is_deleted` = STORE hors-entité, jamais inline ; `_reservedKeys ⊇ ZSyncMeta.reservedKeys` ; `$ZExamFieldSpecs ∩ ZSyncMeta.reservedKeys == {}`. Câbler le gate DANS cette story (R8).
- **AD-28** : le contenu n'est jamais une `String` ambiguë — `reminderTime` est typé `ZReminderTime?` (le TYPE dit le format `HH:mm`), pas une `String` qui flotte.
- **NFR-S3 / NFR-S10 / SM-S5** : pur-Dart, tests `dart test`, aucune dép lourde ; modularité prouvée (aucune arête entrante).

### Rétro ES-1 (R1–R9) — appliquées ici
- **R2** : chaque garde naît avec sa fixture d'échec ISOLÉE (bornes `ZReminderTime`, `date` corrompue, canal `reminder_time`, clés de sync, voie ctor).
- **R3** : chaque injection de régression est REJOUÉE par l'orchestrateur (heure retirée, `now`→`DateTime.now()`, registrar/reserved-key/voie retirés).
- **R4** : specs tranchées PAR LECTURE (D1–D6 ci-dessus), pas de mémoire.
- **R5** : AST/analyse pour reconnaître une structure Dart (test anti-`DateTime.now()` d'AC10), jamais un simple regex fragile.
- **R6** : aucun `try-catch` mort/décoratif (leçon L3 de `ZSmartNote._asStringMap`) ; aucune dégradation silencieuse.
- **R8** : entité câblée au gate dans la MÊME story (T5).
- **R9** : vérif verte rejouée REPO-WIDE (`melos analyze` **ET** `melos verify`, pas seulement par-package — un symbole public de `zcrud_exam` cassant un consommateur ne se voit qu'en repo-wide).

### `gate:web` — RAPPEL EXPLICITE (piège rejoué si oublié)
`zcrud_exam` est pur-Dart ⇒ **couvert par `gate:web` dès sa création**. Tout test `dart:io` → **`@TestOn('vm')` + raison écrite** (patron `zcrud_note`). Les `DateTime` des tests d'horloge sont des **littéraux `DateTime.utc(...)`** (JS-safe) ; l'interdit porte sur `DateTime.now()` argless (non déterministe), pas sur `DateTime.utc(args)` ni `DateTime.tryParse`. Ne PAS ajouter d'opt-out de confort au gate.

### Leçons fraîches à ne pas rejouer
- **ES-2.3** : un golden temporel/hash peut PASSER PAR COÏNCIDENCE → vecteurs à pouvoir discriminant OBSERVÉ (faire VARIER `now`, asserter des sorties DISTINCTES).
- **ES-2.4 (DW-ES24-1)** : ne pas surpromettre l'immuabilité PROFONDE des canaux `List`/`Map` au ctor `const` (`reminderDaysBefore` : la dartdoc ne promet pas une copie défensive profonde que le ctor `const` ne peut pas faire).
- **ES-2.5 (DW-ES25-1)** : un test de « non-export d'extension générée » via import INTERNE est POWERLESS (passe même sans le `hide`). Le `hide ZExamZcrud` du barrel tient l'invariant ; ne pas prétendre le PROUVER par un test qui l'utilise déjà via `src/`.

### Project Structure Notes
- **Alignement** : nouveau `packages/zcrud_exam/` strictement calqué sur `zcrud_note` (structure, pubspec, barrel, `lib/src/domain/`, `.g.dart` suivi git). Naming : types `Z*`, fichiers snake_case, tests `*_test.dart`.
- **Variance assumée** : `reminderTime` typé VO persisté en `String` `HH:mm` (canal hors-codegen) plutôt qu'un `@ZcrudModel` subModel imbriqué — justifié D2 (compat migration + AD-28). `date` nullable (D6) plutôt que required — justifié (const ctor + précédent `createdAt`).
- **Conflit potentiel** : `tool/reserved_keys_gate` (partagé) — écriture ADDITIVE ciblée (T5). Si une autre story en vol y écrit, sérialiser.

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story-ES-2.6 l.431-447 ; #FR-S9 l.113 ; parallélisation l.169, l.338]
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-study-2026-07-12/prd.md#FR-S9 l.179-183 ; entités l.96 ; hors-entité sync l.139]
- [Source: docs/canonical-schema.md l.230, l.255 (ScheduledReminder = Map ouverte)]
- [Source: packages/zcrud_note/ (GABARIT) ; packages/zcrud_note/lib/src/domain/z_smart_note.dart (canal hors-codegen) ; packages/zcrud_study_kernel/lib/src/domain/z_flashcard_tag.dart (extra ES-2.2b)]
- [Source: packages/zcrud_core/lib/src/domain/edition/z_time_codec.dart (HH:mm) ; packages/zcrud_core/lib/src/domain/extension/z_extensible.dart (zNormalizeExtra/zSanitizeExtra) ; z_json_equality.dart]
- [Source: tool/reserved_keys_gate/lib/src/registrars.dart (contrat câblage) ; pubspec.yaml (deps) ; scripts/ci/gate_reserved_keys.dart l.500-588 (règle (g)) ; scripts/ci/gate_web_determinism.dart l.17-34, l.123-138 (default-ON)]
- [Source: _bmad-output/implementation-artifacts/stories/epic-es-1-retrospective.md R1-R9 l.72-110 ; code-review-es-2-5.md (DW-ES25-1) ; CLAUDE.md (invariants AD, cycle BMAD, findings MEDIUM)]

## Definition of Done
- [x] AC1–AC14 satisfaits, chaque garde avec fixture d'échec R2 + injection R3 rejouée.
- [x] `melos run generate` OK (`z_exam.g.dart` committé) · `melos run analyze` RC=0 · `melos run test` RC=0 · `dart test -p node` (zcrud_exam) RC=0.
- [x] `dart run scripts/ci/gate_reserved_keys.dart` VERT · `dart run scripts/ci/gate_web_determinism.dart` VERT · `melos run verify` VERT.
- [x] `melos list` == 18 · graphe ACYCLIQUE / CORE OUT=0 · aucune arête entrante vers `zcrud_exam` (NFR-S10).
- [x] Aucun `DateTime.now()`/`DateTime()` argless dans `packages/zcrud_exam/lib/` (prouvé par machine).
- [x] Findings code-review HIGH/MAJEUR/MEDIUM corrigés (ou MEDIUM justifié par écrit).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

- Vérif verte REPO-WIDE rejouée réellement : `dart pub get` (workspace) OK ·
  `melos run generate` RC=0 (`z_exam.g.dart` émis) · `melos run analyze` RC=0
  (SUCCESS, `zcrud_exam` : No issues) · `melos run test` RC=0 (`zcrud_exam` 41/41) ·
  `dart test -p node` (zcrud_exam) RC=0 (39/41 ; les 2 tests `@TestOn('vm')`
  correctement exclus en JS) · `gate_reserved_keys.dart` RC=0 · `gate_web_determinism.dart`
  RC=0 (`zcrud_exam` dans la cible) · `prove_gates.dart` 41 OK / 0 FAIL ·
  `graph_proof.py` ACYCLIQUE OK / CORE OUT=0 OK (zcrud_exam → {core, annotations,
  generator} ; **0 arête entrante** — NFR-S10) · `melos run verify` RC=0 · `melos list` == 18.
- Injections de régression R3 (exécutées réellement, RC=1, restaurées par édition ciblée) :
  1. `registerZExam` retiré de `kRegistrars` ⇒ ROUGE (`R_disk \ R_wired = {exam}`).
  2. `kReminderTimeKey` retiré de `_reservedKeys` ⇒ ROUGE (règle (g1) : canal `reminder_time` non réservé).
  3. voie `ctor` retirée de `kExtraWriters['exam']` ⇒ ROUGE (règle (j) : `ZExam.ctor` non sondée).
  4. `hide ZExamZcrud` retiré du barrel ⇒ ROUGE (règle (h) : extension générée exportée).
  5. `DateTime.now()` injecté dans `daysUntil` ⇒ `no_datetime_now_test.dart` ROUGE (`Actual: ['lib/src/domain/z_exam.dart']`).
  `git diff --stat` post-restauration : aucun résidu d'injection (grep `R3-INJECTION` = NONE).

### Completion Notes List

- Package `zcrud_exam` créé (pur-Dart, gabarit `zcrud_note`), 18ᵉ package.
- `ZReminderTime` : VO pur `HH:mm` défensif (réutilise `ZTimeCodec.hhmmToMap`), NON `@ZcrudModel`, NON `ZExtensible`, aucun câblage gate.
- `ZExam` : `ZEntity` + `ZExtensible` `@ZcrudModel(kind: 'exam')`. Patron `extra` ES-2.2b intégral (accesseur normalisant, garde `_sanitizeExtra` partagée fromMap+copyWith, `...extra` dans toMap, copyWith à sentinelle sur TOUS les champs, égalité profonde `zJsonEquals`/`zJsonHash`).
- `reminderTime` = canal HORS-CODEGEN, clé réservée `reminder_time` (règle (g1)/(g2)) ; `date` = `@ZcrudField DateTime?` ISO-8601 ; `reminderDaysBefore` = `List<int>` natif `listScalar`.
- AD-19 : NI `updatedAt` NI `isDeleted` ; `_reservedKeys ⊇ ZSyncMeta.reservedKeys` ; `$ZExamFieldSpecs ∩ ZSyncMeta.reservedKeys == {}`.
- Proximité pure horloge injectée (`DateTime now` en paramètre) : `daysUntil`/`isPast`/`isApproaching` totales sur `date == null` (jours calendaires UTC). Pouvoir discriminant OBSERVÉ : balayage {J-7,J-1,J0,J+1} sur le même examen (date fixe J0) ⇒ `daysUntil={7,1,0,-1}`, `isPast={F,F,F,T}`, `isApproaching={T,T,T,F}` (seuils [7,1]) — 4 sorties distinctes prouvant la dépendance à `now`. Déterminisme prouvé (même `now` ⇒ même sortie).
- Gate câblé DANS la story (R8) : import, `registerZExam`, `kProbeBodies['exam']` (avec `reminder_time` non vide + `reminder_days_before`), `kExtraWriters['exam']` (ctor VERBATIM + copyWith), `_ctorExam`/`_copyWithExam`. `kLegacyUpdatedAtMirrors`/`manual_probes.dart` NON touchés.
- **D remises en cause** : AUCUNE. D1–D6 confirmées par le code réel (le générateur produit exactement `_$asDateTime`/`?.toIso8601String()` pour `date` et `whereType<int>().toList()` pour `reminder_days_before`, comme prescrit ; la règle (g) `_channelsOf` flague bien `reminderTime` en canal `reminder_time` comme anticipé).
- **Dettes ouvertes** : aucune nouvelle. DW-ES24-1 respectée (la dartdoc de `reminderDaysBefore` ne surpromet pas l'immuabilité profonde au ctor `const`). DW-ES25-1 respectée (le test AST anti-`DateTime.now()` a un pouvoir discriminant prouvé par la fixture R2 + l'injection R5, jamais POWERLESS).
- **Fallback disque** : NON — le skill `bmad-dev-story` a été invoqué via le tool `Skill` avec succès.
- `.g.dart` régénéré et LAISSÉ dans l'arbre (non gitignoré, éligible git — gate `codegen-distribution` vert), NON committé (consigne).

### File List

Créés :
- `packages/zcrud_exam/pubspec.yaml`
- `packages/zcrud_exam/lib/zcrud_exam.dart`
- `packages/zcrud_exam/lib/src/domain/z_reminder_time.dart`
- `packages/zcrud_exam/lib/src/domain/z_exam.dart`
- `packages/zcrud_exam/lib/src/domain/z_exam.g.dart` (généré, suivi git, NON committé par cette story)
- `packages/zcrud_exam/test/z_reminder_time_test.dart`
- `packages/zcrud_exam/test/z_exam_test.dart`
- `packages/zcrud_exam/test/z_exam_clock_test.dart`
- `packages/zcrud_exam/test/no_datetime_now_test.dart` (`@TestOn('vm')`)

Modifiés :
- `pubspec.yaml` (racine) — `- packages/zcrud_exam` ajouté au bloc `workspace:`
- `tool/reserved_keys_gate/pubspec.yaml` — `zcrud_exam: ^0.1.0` en `dependencies:`
- `tool/reserved_keys_gate/lib/src/registrars.dart` — import + `registerZExam` + `kProbeBodies['exam']` + `kExtraWriters['exam']` + `_ctorExam`/`_copyWithExam`
