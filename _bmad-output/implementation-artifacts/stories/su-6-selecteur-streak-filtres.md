---
baseline_commit: 9ed81259f2d386e2596a8b8552231768f95bf110
---

# Story 1.6 : Sélecteur de session, streak et filtres test/examen

Status: in-progress

**Clé sprint-status** : `su-6-selecteur-streak-filtres`
**Taille** : XL — `[A — après su-5]`
**Couvre** : FR-SU10, FR-SU11, FR-SU12
**Ligne du sprint-status (contrat, mot pour mot)** :
> `[XL][A — après su-5] FR-SU10/11/12 ZSessionModeSelector O(1) ; streak CANONIQUE zcrud_study_kernel (jour civil LOCAL, reset à 1 PAS 0, horloge PARAMÉTRÉE, exclu en consultation, toast via ZToaster) ; filtres purs (mauvais=q0-2 AD-46)`

---

## Story

As an **apprenant**,
I want **choisir quoi réviser et voir ma flamme**,
so that **je démarre la bonne session en un geste et je tiens mon rythme**.

---

## Contexte & décisions verrouillées (à NE PAS ré-arbitrer)

| Verrou | Source | Conséquence pour su-6 |
|---|---|---|
| Seau « mauvais » = **q0-2**, bon = **q3**, maîtrisé = **q4-5** | AD-46 + glossaire PRD | Le PRD FR-SU12 dit « q0-2 » : **aucun écart ici** (contrairement à FR-SU9). Jamais « 1-2 ». |
| `ZSrsConfig` **possède** l'échelle (`minQuality`/`maxQuality`) | AD-46, su-1 | `ZQualityScale.fromConfig` **dérive**. Jamais de littéral de borne. |
| `config.clampQuality` = **UNIQUE** voie de clamp | AD-46, su-1 | Toute qualité entrante hors échelle passe par lui. |
| Horloge **injectée**, jamais capturée | AD-14, spine « calcul pur testable » | `DateTime.now()` **interdit** dans le calcul du streak. |
| Streak : **reset à 1**, PAS à 0 | Spine § « Écarts assumés » | Le PRD (« remise à zéro ») est **déjà amendé** par le spine. Ne pas ré-ouvrir. |
| **Aucun nouveau moteur** ; les 3 runtimes existent | AD-34 | su-6 ne touche **aucun** runtime. |
| Sélection **amont**, runtime **aval** | AD-33 | Les filtres produisent une file ; aucun moteur ne filtre. |
| Jamais d'exception | AD-10 | Tous les replis ci-dessous. |
| enums > booléens | Spine § Conventions | `ZMasteryLevel`, `ZStreakOutcome`, `ZSessionModeKind`. |

---

## Périmètre RÉEL vérifié sur disque (consommer — ne JAMAIS recréer)

### Ce que les acquis offrent RÉELLEMENT (lu, pas supposé)

| Acquis | Emplacement RÉEL (lu) | Contrat RÉEL |
|---|---|---|
| `ZSrsConfig` | `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart:17` | `minQuality = 0`, `maxQuality = 5`, `passThreshold = 3`, `clampQuality`. `assert(maxQuality == 5)`. **NON-codegen** (grep `@ZcrudModel` → **RC=1**) ⇒ un getter ajouté n'a **aucun** impact sérialisation/round-trip. |
| `ZQualityScale` | `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart:40` | `ZQualityScale.fromConfig(config)` → `min`/`max`/`qualities`/`contains`. **Seule** voie publique. |
| `zMasteredCount` (su-5) | `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart:109` | `int zMasteredCount(Map<String,int> byQuality, ZQualityScale scale, int masteredThreshold)`. Clampe les crans négatifs, ignore le hors-échelle, jamais de throw. |
| Seuil de maîtrise (su-5) | `z_session_summary_view.dart:363` | `widget.masteredThreshold ?? scale.max - 1` — **dérivé**, jamais le littéral `4`. ⚠️ vit en **présentation `zcrud_session`** → voir **D2**. |
| `ZStudySessionSelector` | `packages/zcrud_study_kernel/lib/src/domain/z_study_session_selector.dart:34` | `matches(candidate)` (dossier ∧ tags ∧ types, **hors** `count`) + `selectFrom<T>(candidates)` (filtres ∧ troncature `count`). **Pur, sans horloge, sans mélange.** Ordre d'entrée **préservé**. `count <= 0` ⇒ vide. |
| `ZSessionCandidate` | `.../z_session_candidate.dart:26` | `folderId`, `subFolderId`, `tagIds`, `typeKey`. 🔴 **AUCUN état SRS** (ni qualité, ni `nextReviewDate`) — cf. **D1**. |
| `ZRepetitionInfo` | `packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart:66` | `flashcardId`, `folderId`, `interval`, `repetitions`, `easeFactor`, `nextReviewDate`, `learnedAt`, `lastQuality`. `fromMap` défensif. |
| `ZChoice` | `packages/zcrud_flashcard/lib/src/domain/z_choice.dart:25` | `{String content, bool isCorrect}` — 🔴 `isCorrect` est porté **PAR l'objet choix** (cf. **AC12**). |
| `ZFlashcard` | `.../z_flashcard.dart:148,167,236` | `type`, `choices` (`List<ZChoice>?`), `typeKey => type.name`, `implements ZSessionCandidate`. |
| `ZStudyRepository<T>` | `packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart:68` | `abstract class ZStudyRepository<T extends ZEntity> extends ZSyncableRepository<T>` ; `validate(T)` (hook **pur**, `ZResult<Unit>`, défaut `Right(unit)`), `persist` `@protected`, `save` **`@nonVirtual`** (Template Method). |
| `ZToaster` | `packages/zcrud_ui_kit/lib/src/domain/z_toaster.dart:23` | `abstract interface class ZToaster { void show(BuildContext, {required String message, ZToastSeverity severity = info, Duration? duration, String? actionLabel, VoidCallback? onAction}); }` |
| `ZToasterScope` | `packages/zcrud_ui_kit/lib/src/presentation/z_toaster_scope.dart:23` | `maybeOf(context) → ZToaster?` ; `of(context) → ZToaster` avec **repli sûr** `const ZScaffoldMessengerToaster()` — **jamais de throw** (AD-10). |
| `ZReviewMode` | `packages/zcrud_study_kernel/lib/src/domain/z_review_mode.dart:28-43` | 🔴 Valeurs RÉELLES : `spaced`, `learn`, `list`, `test`, `whiteExam`, `cramming`. **Il n'existe AUCUN `listOnly`** — cf. **Écart E1**. |
| Garde d'échelle | `packages/zcrud_session/test/z_quality_scale_single_source_test.dart:105` | `const List<String> _scannedSources` (3 entrées) + `scanForScaleLiterals(lines, path)` **partagé** garde/contre-preuve. « Tout fichier qui CITE cette garde DOIT figurer ici — sinon la citation est un fantôme. » |
| Garde de pureté | `packages/zcrud_session/test/z_purity_test.dart:41-48` | **AUTO-ÉNUMÉRANTE** : `Directory('lib').listSync(recursive: true)` ⇒ tout nouveau fichier est **né gardé**. |
| Garde de confinement tierce | `packages/zcrud_session/test/z_third_party_confinement_test.dart:83-113` | Table de paquets **tiers** (`flutter_card_swiper`, `confetti`) + `bannedTypes`/`probeLeak`/`probeOwn`. |

### Absences PROUVÉES par grep négatif (rejouables, RC cité)

```bash
cd /home/zakarius/DEV/zcrud
grep -rni "streak" packages/ --include="*.dart" -q            # RC=1 → ABSENT (aucun streak nulle part)
grep -rn "ZSessionModeSelector" packages/ -q                  # RC=1 → ABSENT
grep -rn "ZStudyStreak\|z_study_streak" packages/ -q          # RC=1 → ABSENT
grep -rn "masteredThreshold" packages/zcrud_flashcard/lib/ -q # RC=1 → ABSENT (le seuil n'est PAS dans le domaine)
grep -rn "zMasteredCount" packages/zcrud_session/lib/ -q      # RC=0 → PRÉSENT (su-5, à CONSOMMER)
grep -rn "zcrud_ui_kit" packages/zcrud_session/pubspec.yaml -q# RC=1 → ARÊTE ABSENTE (cf. D3)
grep -rn "Random" packages/zcrud_flashcard/lib/ packages/zcrud_session/lib/ -q # RC=1 → ABSENT
grep -rn "@ZcrudModel" packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart -q # RC=1 → ZSrsConfig NON-codegen
```

> ⚠️ **Piège méthodologique mesuré pendant ce create-story** : `grep … | head ; echo $?` rend le RC de
> **`head`** (toujours `0`) — une « preuve d'absence » ainsi obtenue est **FAUSSE**. Tous les RC
> ci-dessus sont obtenus **sans pipe**, avec `-q`. Le dev **rejoue ces commandes telles quelles**.

### État de l'arbre (source unique : `python3 scripts/dev/graph_proof.py`, rejoué → RC=0)

```
total arêtes = 52 · noeuds = 23 · ACYCLIQUE OK · CORE OUT=0 OK
zcrud_session -> zcrud_core, zcrud_flashcard, zcrud_study_kernel      (PAS zcrud_ui_kit)
zcrud_ui_kit  -> zcrud_core                                            (UNIQUE arête sortante)
```
`graph_proof.py` **n'a AUCUNE allowlist d'arêtes** (grep `ALLOW|allowlist|EXPECTED_EDGES` → aucun résultat) :
il prouve **acyclicité + CORE OUT=0**, rien d'autre.

---

## 🎯 Les décisions de conception (mode non interactif — option la plus conservatrice, consignée)

### D1 — 🔴 Où vit CHAQUE morceau : dicté par la direction des arêtes, pas par le confort

`ZSessionCandidate` **ne porte aucun état SRS** (lu : 4 getters, aucun quality/date). Le kernel est
**ignorant** de `ZSrsConfig` et `ZRepetitionInfo` (`zcrud_flashcard → zcrud_study_kernel`, jamais
l'inverse). Donc :

| Livrable | Package | Pourquoi **ce** package et pas un autre |
|---|---|---|
| `ZStudyStreak` + `zAdvanceStreak` | **`zcrud_study_kernel`** (`lib/src/domain/`) | Imposé par le sprint-status/PRD (« entité domaine kernel »). Le streak n'a besoin **que de dates** — aucun besoin de `ZSrsConfig` ⇒ l'arête manquante ne gêne pas. **Pur-Dart** (le kernel n'importe que `package:zcrud_core/domain.dart`, tests sous `dart test`) ⇒ **aucun import Flutter**. |
| Filtres FR-SU12 + catégorisation FR-SU10 | **`zcrud_flashcard`** (`lib/src/domain/`) | Ils exigent **à la fois** `ZStudySessionSelector` (kernel, amont) **et** `ZSrsConfig`/`ZRepetitionInfo` (flashcard). `zcrud_flashcard` est le **premier** point du graphe qui voit les deux. Les mettre dans le kernel est **impossible** (il ne voit pas `ZSrsConfig`) ; les mettre dans `zcrud_session` couperait `zcrud_flashcard` d'un filtre qui est du **domaine**. |
| `ZSessionModeSelector` + dialog de filtres + badge flamme | **`zcrud_session`** (`lib/src/presentation/`) | Widgets ⇒ présentation ; `zcrud_session` voit déjà `zcrud_flashcard` + kernel. |

### D2 — 🔴 Le seuil de maîtrise : le handoff su-5 **exige** de le PROMOUVOIR, pas de le recopier

**Le fait mesuré** : su-5 a créé le seuil **une fois**, mais dans
`zcrud_session/lib/src/presentation/z_session_summary_view.dart:363` (`?? scale.max - 1`) — soit en
**présentation**, et en **AVAL** de `zcrud_flashcard`. Or **D1** place les filtres dans
`zcrud_flashcard`, en **AMONT**. **Un package amont ne peut pas importer un package aval** (AD-1).

**Les trois issues, et pourquoi une seule tient :**

| Option | Verdict |
|---|---|
| Les filtres re-dérivent `max - 1` chez eux | 🚫 **REFUSÉ** — c'est **exactement** la seconde source que su-5 interdit par écrit (« su-6 DOIT le consommer, **jamais le redéclarer** ») et **le HIGH de su-1**. Pire : `maxQuality` étant épinglé à 5 par `assert`, la divergence serait **ISO-COMPORTEMENTALE** ⇒ **toute la suite resterait VERTE**. |
| Déplacer les filtres dans `zcrud_session` | 🚫 **REFUSÉ** — FR-SU12 exige une **fonction pure de domaine** ; `zcrud_flashcard` (le propriétaire de `ZSrsConfig`/`ZRepetitionInfo`) serait privé de son propre filtre. |
| **PROMOUVOIR le seuil dans son propriétaire AD-46 (`ZSrsConfig`)**, su-5 le **consomme** | ✅ **RETENU** |

**Le contrat exact** — dans `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart` :

```dart
/// Seuil de MAÎTRISE — **dérivé** de la borne haute possédée par ce config (AD-46).
/// `maxQuality - 1` ⇒ q4-5 en échelle canonique. JAMAIS le littéral `4`.
/// 🔴 SOURCE UNIQUE : promue ici par su-6 parce que les filtres FR-SU12 vivent
/// dans `zcrud_flashcard`, en AMONT de `zcrud_session` où su-5 l'avait dérivé —
/// un amont ne peut pas importer un aval (AD-1). su-5 CONSOMME désormais ce getter.
int get masteredThreshold => maxQuality - 1;
```

- ✅ **C'est une PROMOTION vers le propriétaire AD-46, pas une redéclaration** : la dérivation
  **se déplace** dans le seul type qui possède l'échelle. Le nombre de sources **reste 1**.
- ✅ **Zéro risque de sérialisation** : `ZSrsConfig` est **NON-codegen** (grep `@ZcrudModel` → **RC=1**)
  et c'est un **getter dérivé** (aucun champ, aucun paramètre de constructeur, aucun `toMap`).
- ✅ **Retouche de su-5 STRICTEMENT bornée à une ligne** — `z_session_summary_view.dart:363` :
  `widget.masteredThreshold ?? scale.max - 1` → `widget.masteredThreshold ?? widget.srsConfig.masteredThreshold`
  (le point d'injection `masteredThreshold` de su-5 est **conservé tel quel**). **Rien d'autre de su-5
  n'est touché** — ce n'est pas une réouverture de su-5, c'est l'exécution de son handoff.
- ✅ La garde d'échelle **voit** ce déplacement : `z_session_summary_view.dart` est **déjà** dans
  `_scannedSources` ⇒ si quelqu'un y ré-inline `scale.max - 1` ou `?? 4`, elle rougit. **Ne pas créer
  de garde parallèle** (leçon E10) — cf. **AC9**.

### D3 — 🔴 `ZToaster` : le sprint-status l'impose, mais l'arête **n'existe pas**

**Le fait mesuré** : `ZToaster`/`ZToasterScope` vivent dans **`zcrud_ui_kit`**. `zcrud_session` **ne
dépend PAS** de `zcrud_ui_kit` (grep pubspec → **RC=1**). Seuls `zcrud_get` et `example` en dépendent.

**Retenu (le plus conservatif)** : **AJOUTER l'arête `zcrud_session → zcrud_ui_kit`** et consommer
`ZToasterScope.of(context).show(...)`.

| Contrôle | Verdict |
|---|---|
| Acyclicité | ✅ `zcrud_ui_kit → zcrud_core` est sa **seule** arête sortante ⇒ `session → ui_kit → core` reste **acyclique**. |
| CORE OUT=0 | ✅ inchangé (aucune arête **sortante** de `zcrud_core`). |
| Allowlist d'arêtes | ✅ **inexistante** dans `graph_proof.py` ⇒ aucune règle enfreinte. |
| Nouvelle dépendance **tierce** | ✅ **AUCUNE** — `zcrud_ui_kit` ne dépend que de `zcrud_core` + SDK Flutter. La table de `z_third_party_confinement_test.dart` est **TIERCE** ⇒ **ne pas y toucher**. |
| Spine | ✅ « Seams réutilisés, **jamais redéclarés** : … `ZToaster`/`ZToasterScope` … ». Redéclarer un port de toast dans `zcrud_session` serait la violation. |

**Rejeté** : un `ZToaster` local à `zcrud_session`, ou un `onStreakUpdated` callback qui ferait
afficher le toast par l'app (le sprint-status impose « **toast via `ZToaster`** », pas « via un
callback »). Le repli sûr de `ZToasterScope.of` (`ZScaffoldMessengerToaster`) satisfait AD-10 **sans
aucun code défensif à écrire**.

### D4 — Persistance du streak : `ZStudyRepository<ZStudyStreak>`, jamais un port neuf

Le port **existe** : `ZStudyRepository<T extends ZEntity>`. `ZStudyStreak` est donc une `ZEntity`
`@ZcrudModel` ⇒ **codegen** ⇒ `z_study_streak.g.dart` **committé** (`packages/*/lib/` est suivi par
git — NFR-SU10, gate `codegen-distribution`). **Aucun nouveau port** n'est créé (grep `Port` dans le
kernel → seul `ZStudyRepository` existe). `validate()` reste **PUR** (aucun `DateTime.now()`, contrat
lu ligne 68-80) : la validation de cohérence des dates y est légitime, le **calcul** n'y est pas.

### D5 — 🔴 Horloge ET aléa : **même discipline**, tous deux INJECTÉS

`DateTime.now()` et `Random()` sont **la même faute** : une source non déterministe **capturée** rend
le test soit flaky, soit tautologique.

```dart
// Streak — l'instant est un PARAMÈTRE (AD-14). Jamais DateTime.now() dans le corps.
ZStreakAdvance zAdvanceStreak(ZStudyStreak current, {required DateTime at, required ZReviewMode mode});

// Tirage/mélange — la source d'aléa est un PARAMÈTRE. Jamais Random() dans le corps.
List<T> zDrawQuestions<T>(List<T> eligible, {required int count, required Random random});
List<ZChoice> zShuffleChoices(List<ZChoice> choices, {required Random random});
```
`Random` vient de `dart:math` — **pur-Dart**, légal dans le kernel comme dans `zcrud_flashcard`.

### D6 — « Exclu en consultation » : la règle RÉELLE est « **répétition notée** »

FR-SU11 : « incrément à la première **répétition notée** du jour ». AD-34 (table lue) : **seuls
`spaced`/`learn` écrivent le SRS**. Donc le streak n'avance que sur `spaced`/`learn` ; `list`
(**la consultation**), `cramming`, `test`, `whiteExam` rendent `ZStreakOutcome.skippedNotGraded`.
C'est un **sur-ensemble** de l'exigence littérale des epics (« mode consultation »), cohérent avec
« notée », et **testable par énumération de l'enum** (AC4). Consigné : les epics n'exigent
littéralement que `list` ; les 3 autres non-SRS sont exclus **par la même règle**, pas par un cas
particulier.

### D7 — su-6 **ne câble AUCUN moteur**

`zAdvanceStreak` est une **fonction pure** appelée par l'hôte après une répétition notée.
**Aucune** modification de `ZStudySessionEngine`/`ZSessionReviewer`/`ZSessionCardSwiper` (su-4) :
ce serait rouvrir une story livrée, et AD-34 ferme déjà le sujet. Le sélecteur **produit** une file
(AD-33 : sélection amont) ; il ne démarre aucun runtime lui-même.

---

## ⚠️ Écarts tranchés (à consigner, pas à ré-ouvrir)

| # | Écart | Réalité disque / doc | **Tranché** |
|---|---|---|---|
| **E1** | Le sprint-status écrit « exclu en consultation (**`listOnly`**) » | `ZReviewMode` n'a **aucun** `listOnly` — la consultation est **`ZReviewMode.list`** (`z_review_mode.dart:34`) | Utiliser **`ZReviewMode.list`**. `listOnly` est une **coquille** du sprint-status : ne **pas** créer d'enum ni d'alias pour l'honorer. |
| **E2** | PRD FR-SU11 : « remise à **zéro** » | Spine § Écarts assumés : « **reset à 1** (la répétition du jour compte) » | **reset à 1** — déjà amendé par le spine. |
| **E3** | PRD FR-SU12 : « mauvais = q0-2/jamais vu » | AD-46 : « mauvais = q0-2 » | **q0-2** ∪ **jamais vue** (une carte jamais vue est « mauvaise » **et** hors seau de qualité — les deux prédicats coexistent, cf. AC10). |
| **E4** | Le seuil de maîtrise est en présentation `zcrud_session` (su-5) | Les filtres sont en amont (`zcrud_flashcard`) | **Promotion dans `ZSrsConfig`** (D2) — su-5 consomme. |
| **E5** | Le sprint-status impose « toast via `ZToaster` » | Arête `session → ui_kit` **absente** (RC=1) | **Créer l'arête** (D3) — acyclique, zéro dépendance tierce. |

---

## ⚠️ Frontières de périmètre (dures)

| Sujet | Story propriétaire | su-6 |
|---|---|---|
| UI d'examen blanc (`ZListSessionView`) | **su-7** | 🚫 |
| Liste de flashcards, recherche, tris, ordre manuel | **su-8** | 🚫 |
| Flux UI de génération IA | **su-9** | 🚫 |
| Parcours assemblé `example/` | **su-10** | 🚫 |
| Nouveau moteur / écriture SRS / retouche d'un runtime | *aucune* (AD-33/AD-34) | 🚫 **su-6 n'écrit AUCUN SRS** |
| `zcrud_core` | **E-MULTI-EDIT** uniquement | 🚫 **interdit** |
| `zcrud_session` : su-5 | — | ✅ **UNE seule ligne** (`:363`, D2) — rien d'autre |

---

## Acceptance Criteria

### AC1 — `ZStudyStreak` : entité **domaine** du kernel, pur-Dart, persistable

**Given** aucun streak n'existe (grep `streak` → **RC=1**)
**When** su-6 est livrée
**Then** `packages/zcrud_study_kernel/lib/src/domain/z_study_streak.dart` porte `ZStudyStreak`
`@ZcrudModel`, `implements ZEntity`, champs : `id`, `current` (série en cours), `best` (record),
`lastGradedDay` (**jour civil**, ISO-8601 `yyyy-MM-dd`)
**And** `z_study_streak.g.dart` est **généré ET committé** (gate `codegen-distribution`)
**And** **aucun import Flutter** (garde : le kernel tourne sous `dart test`)
**And** `fromMap` est **défensif** (AD-10) : `current`/`best` absents/non-int/**négatifs** → `0` ;
`lastGradedDay` illisible → `null` — **jamais** de throw
**And** le fichier est exporté par le barrel `lib/zcrud_study_kernel.dart`.
> **Test porteur** : round-trip `toMap`/`fromMap` + map vide + map corrompue (`{'current': 'x', 'best': -4}`).
> **Injection R3** : remplacer le défaut `-4 → 0` par `-4` ⇒ le test **rougit** (comportement, pas compilation).

### AC2 — `zAdvanceStreak` : calcul **PUR**, horloge **PARAMÉTRÉE**, **reset à 1**

**Given** la signature `ZStreakAdvance zAdvanceStreak(ZStudyStreak current, {required DateTime at, required ZReviewMode mode})`
**When** elle s'exécute
**Then** elle est **PURE** : aucun I/O, **aucun `DateTime.now()`** dans le corps
**And** le comportement est **exactement** :

| Cas | `lastGradedDay` vs jour civil local de `at` | Résultat |
|---|---|---|
| Toute première répétition notée | `null` | `current = 1`, `ZStreakOutcome.started` |
| Même jour civil | `== jour(at)` | **inchangé** (idempotent), `ZStreakOutcome.alreadyCountedToday` |
| Jour civil **suivant** | `== jour(at) - 1` | `current + 1`, `ZStreakOutcome.incremented` |
| **Trou** ≥ 1 jour civil complet | `< jour(at) - 1` | 🔴 **`current = 1`**, `ZStreakOutcome.resetToOne` — **JAMAIS 0** |

**And** `best = max(best, current)` après application
**And** `ZStreakOutcome` est un **enum** (jamais un `bool`).
> **Test porteur** : un cas par ligne du tableau, **valeur exacte** (`equals(1)`, jamais `isNotNull`/`greaterThan(0)`).
> **Injection R3** : passer `resetToOne` de `1` à `0` ⇒ le test **rougit** (c'est **le** défaut que
> le spine nomme). `greaterThan(0)` ne rougirait PAS sur `0`… mais `equals(1)` si — assertions **exactes** exigées.

### AC3 — 🔴 Le **jour civil LOCAL** aux bornes : le nid à bugs, prescrit cas par cas

**Given** que « jour civil local » est calculé
**When** on éprouve les bornes
**Then** la dérivation du jour est **`DateTime(at.year, at.month, at.day)`** (constructeur **local**),
**jamais** `at.toUtc()`, **jamais** `millisecondsSinceEpoch ~/ 86400000` (qui casse en DST et hors UTC)
**And** l'écart de jours est calculé sur les **dates civiles** (`différence de jours civils`), **jamais**
`at.difference(other).inDays` (qui rend **0** pour un écart de 23 h en DST, et **1** pour 25 h)
**And** les cas suivants sont **tous** couverts par un test porteur :

| Cas aux bornes | Attendu |
|---|---|
| `23:59:59` puis `00:00:01` le lendemain | **jours civils différents** ⇒ `incremented` (≈ 2 s d'écart réel) |
| `00:00:00` puis `23:59:59` **le même jour** | **même jour** ⇒ `alreadyCountedToday` (≈ 24 h d'écart réel) |
| DST **printemps** (jour de **23 h**), veille → lendemain | `incremented` (**pas** `resetToOne`) |
| DST **automne** (jour de **25 h**), veille → lendemain | `incremented` (**pas** `alreadyCountedToday`) |
| Même instant en `local` vs `at.toUtc()` près de minuit | Le jour retenu est le **LOCAL** (assertion explicite) |
| `at` **antérieur** à `lastGradedDay` (horloge reculée, date **future** persistée) | **jamais** de throw, **jamais** de `current` négatif ; repli **`alreadyCountedToday`** (`current` inchangé) — AD-10 |
| `lastGradedDay` **dupliqué**/désordonné dans une séquence | `zAdvanceStreak` est **idempotent** : rejouer N fois le même `at` ⇒ **strictement** le même résultat |

> ⚠️ **Le test ne doit PAS dépendre du fuseau de la machine de CI.** Le dev **choisit et consigne** l'une
> des deux voies **testables** : (a) `zAdvanceStreak` prend un paramètre de **conversion de jour civil**
> injectable (`ZCivilDay Function(DateTime)`, défaut = `DateTime(y,m,d)` local) que le test substitue par
> un calendrier simulé DST ; (b) le test construit des `DateTime` **locaux** et n'assert que sur des
> propriétés **indépendantes du fuseau**. **(a) est RETENU par défaut** (le plus conservateur : il rend
> le DST **réellement** testable sans dépendre du `TZ` de la CI — (b) ne peut PAS simuler un jour de 23 h).
> **Injection R3** : remplacer la dérivation civile par `at.difference(other).inDays` ⇒ les deux cas DST **rougissent**.

### AC4 — Streak **exclu** hors répétition notée (dont la **consultation**)

**Given** `ZReviewMode` (valeurs RÉELLES : `spaced`, `learn`, `list`, `test`, `whiteExam`, `cramming`)
**When** `zAdvanceStreak(..., mode: m)` est appelé
**Then** `spaced`/`learn` → le streak **avance** (AC2)
**And** `list` (**la consultation**), `cramming`, `test`, `whiteExam` → streak **strictement inchangé**,
`ZStreakOutcome.skippedNotGraded`
**And** le test **énumère `ZReviewMode.values`** (jamais une liste recopiée) ⇒ un **7ᵉ mode** ajouté
demain **casse** le test tant qu'il n'est pas classé.
> **Injection R3** : faire avancer le streak en `list` ⇒ rougit. **Assertion sur l'objet entier**
> (`equals(before)`), pas seulement sur `current`.

### AC5 — Persistance par le port **EXISTANT**, jamais un port neuf

**Given** `ZStudyRepository<T extends ZEntity>` (le **seul** port du kernel — vérifié)
**When** le streak est persisté
**Then** il passe par `ZStudyRepository<ZStudyStreak>` — **aucun** nouveau port, **aucun** store en champ
**And** l'écriture rend un `Either<ZFailure, T>` (AD-11), **jamais** une exception
**And** un échec de persistance **n'empêche pas** l'affichage de la session (AD-10) : le repli est
consigné et la session continue
**And** `save` **`@nonVirtual`** n'est **pas** contourné (aucun appel direct à `persist`).
> **Test porteur** : un dépôt fixture rendant `Left(ZFailure)` ⇒ aucun throw, session continue.
> **Injection R3** : remplacer le `Left` par un `throw` dans l'appelant ⇒ rougit.

### AC6 — Toast via `ZToaster` — **jamais** un `SnackBar` en dur

**Given** un streak mis à jour (`started`/`incremented`/`resetToOne`)
**When** la confirmation s'affiche
**Then** elle passe par **`ZToasterScope.of(context).show(context, message: …, severity: …)`**
**And** `packages/zcrud_session/pubspec.yaml` gagne `zcrud_ui_kit: ^0.2.1` (D3)
**And** `ZToastSeverity` est utilisé (**jamais** un `bool isError`)
**And** `alreadyCountedToday`/`skippedNotGraded` ⇒ **AUCUN** toast (pas de spam à chaque carte)
**And** un grep `SnackBar(` dans `packages/zcrud_session/lib/` rend **RC=1**
**And** `python3 scripts/dev/graph_proof.py` reste **RC=0** (ACYCLIQUE + CORE OUT=0) avec **53** arêtes.
> **Test porteur** : un **espion `ZToaster`** (implémente le port, enregistre les appels) monté via
> `ZToasterScope` ⇒ on assert **message + severity + nombre d'appels**.
> 🔴 **L'espion doit être RÉELLEMENT branché** (leçon : « espion jamais branché = infalsifiable ») :
> le test **prouve d'abord** que l'espion capte (un cas `incremented` → **1** appel) **avant**
> d'asserter les cas à **0** appel — sinon « 0 appel » serait vrai même avec un espion débranché.
> **Injection R3** : remplacer le toast par un `ScaffoldMessenger…showSnackBar` ⇒ l'espion voit **0** appel ⇒ rougit.

### AC7 — `ZSessionModeSelector` : les 3 options + badge **flamme** (FR-SU10)

**Given** un ensemble de cartes et leur état SRS
**When** `ZSessionModeSelector` s'affiche
**Then** il propose exactement :

| Option | Règle **exacte** | Visibilité |
|---|---|---|
| **« Apprendre +N »** | cartes **jamais apprises** (`repetitions == 0`), lot **configurable, défaut 30** ; **anneau de progression** | visible si > 0 |
| **« À réviser »** | cartes **dues** (`nextReviewDate <= at`), **triées par urgence** (la plus en retard **d'abord**) | **visible seulement si > 0** |
| **« Test »** | ouvre le **dialog de filtres** (AC10) | toujours |

**And** un **badge flamme** affiche `streak.current`
**And** l'instant `at` est **injecté** (jamais `DateTime.now()` dans le widget — AD-14)
**And** le tri par urgence est **exact et stable** : `{J-5, J-1, J-3}` → `{J-5, J-3, J-1}` (assertion
sur la **séquence entière**, jamais `isNotEmpty`)
**And** un lot de **60** jamais-apprises rend **exactement 30** cartes (défaut), **35** si `batchSize: 35`.
> 🔴 **Un contrôle doit être ACTIONNÉ dans son test** (leçons su-2/su-4 : marqueur sur le **mauvais**
> choix ; bouton « précédent » qui **avançait**, vert car jamais **tapé**) : chaque option est
> **`tap`ée** et l'on assert **quelle** file/valeur le callback reçoit — jamais la seule présence du widget.

### AC8 — 🔴 La catégorisation **O(1) par carte** : PROUVÉE par une **MESURE**, pas par une opinion

**Given** que FR-SU10 exige « catégorisation en **O(1)** par carte (lookup **sets**) »
**When** la catégorisation s'exécute
**Then** l'état SRS est indexé **une fois** en `Map<String, ZRepetitionInfo>` (clé `flashcardId`) et
chaque carte est classée par **lookup** — **interdits** : `infos.firstWhere((i) => i.flashcardId == c.id)`,
`list.indexOf`, `list.contains` sur une `List`, ou tout `where` **imbriqué** dans la boucle par carte
**And** le coût est **MESURÉ** par un test qui **rougit** si l'implémentation devient O(n²) :

```
Sonde : une entité de test qui COMPTE les lectures de ses accesseurs (flashcardId / lastQuality /
        nextReviewDate / repetitions).
Mesure : catégoriser N=200 puis N=1600 cartes.
Assert : lectures_totales <= k * N (k = petite constante, ex. 4) — pour LES DEUX N.
         ⇒ O(n²) : ~N² lectures ⇒ 200 → 40 000 > 800 ⇒ ROUGE.
```
**And** la **contre-preuve R3 est DANS le fichier de test** : une implémentation de référence
**délibérément O(n²)** (`firstWhere` par carte) est soumise à **la MÊME assertion** et doit **ÉCHOUER**
— sinon le compteur ne prouve **rien** (il prouverait le pouvoir du motif, jamais celui de la sonde).
> 🚫 **Aucune mesure de TEMPS** (`Stopwatch`) : flaky en CI, et un `sleep` la ferait passer. On compte
> des **opérations**, grandeur **déterministe**.
> 🚫 L'assertion ne se compare **pas** à une constante lue dans le code de prod (leçon su-4 « 48 dp ») :
> `k` et `N` sont **littéraux dans le test**.

### AC9 — 🔴 Le seuil de maîtrise : **UNE** source — promue, consommée, gardée

**Given** le handoff écrit de su-5 (« su-6 DOIT le consommer, **jamais le redéclarer** »)
**When** su-6 est livrée
**Then** `ZSrsConfig.masteredThreshold` (`=> maxQuality - 1`) existe dans `zcrud_flashcard` (D2)
**And** `z_session_summary_view.dart:363` **consomme** `widget.srsConfig.masteredThreshold`
(le paramètre injectable `masteredThreshold` de su-5 est **conservé**)
**And** 🔴 **`z_srs_config.dart` est AJOUTÉ à `_scannedSources`**… **SI et seulement si** la garde
sait le lire : `_scannedSources` est relatif au package `zcrud_session` (`lib/src/...`) alors que
`z_srs_config.dart` vit dans `zcrud_flashcard`. **Décision retenue (conservatrice)** : **NE PAS**
étendre `_scannedSources` hors de `zcrud_session` (un chemin `../zcrud_flashcard/...` est fragile et
casserait selon le cwd), **NE PAS** créer de garde parallèle (leçon E10) — mais **ajouter dans
`packages/zcrud_flashcard/test/` une garde du même patron**, réutilisant le **même critère**, qui
échoue si un **littéral `4`** (ou `max - 1` recopié) réapparaît **hors** de `z_srs_config.dart`
**And** le dartdoc de `masteredThreshold` **cite** la garde qui le protège **réellement** — la leçon
su-5 est explicite : *une garde citée mais aveugle est un **FANTÔME***.
**And** un grep `scale.max - 1` dans `packages/zcrud_session/lib/` rend **RC=1** après la story.
> **Injection R3** : ré-inliner `?? 4` dans `z_session_summary_view.dart` ⇒
> `z_quality_scale_single_source_test.dart` **rougit** (le fichier y est **déjà** listé — vérifié : `:107`).
> ⚠️ Rappel : `maxQuality` étant épinglé à `5` par `assert`, `?? 4` est **ISO-COMPORTEMENTAL** ⇒
> **seule** la garde structurelle peut l'attraper. C'est **toute** sa raison d'être.

### AC10 — Filtres FR-SU12 : **fonction PURE**, seaux **AD-46**, `ZStudySessionSelector` **consommé**

**Given** les filtres test/examen
**When** ils s'appliquent
**Then** la fonction est **PURE** (aucun I/O, aucune horloge capturée, aucun `Random()` capturé)
**And** elle **CONSOMME `ZStudySessionSelector`** pour dossier ∧ tags ∧ types — **jamais** réécrits
(elle **délègue** à `matches()`, et n'ajoute que ce que le kernel ne sait pas faire)
**And** les niveaux de maîtrise sont un **enum** `ZMasteryLevel { bad, good, mastered }` :

| Niveau | Règle **exacte** (AD-46) |
|---|---|
| `bad` | `lastQuality` ∈ **[minQuality .. passThreshold-1]** (= **q0-2**) **∪ jamais vue** (`repetitions == 0` / `lastQuality == null`) |
| `good` | `lastQuality == passThreshold` (= **q3**) |
| `mastered` | `lastQuality >= config.masteredThreshold` (= **q4-5**) — **AC9**, jamais un littéral |

**And** les bornes viennent **toutes** de `ZSrsConfig` (`minQuality`, `passThreshold`, `masteredThreshold`) —
**aucun littéral `0`/`2`/`3`/`4`/`5`**
**And** `questionCount` **défaut 10**, **tirage aléatoire** si excédent (AC11)
**And** `tags` et `sources` filtrent ; les types de source viennent du **registre** (AD-4)
**And** 🔴 **`correct` (q3+) ≠ `mastered` (q4-5)** — l'écart n°1 de su-5 : un test asserte
**explicitement** que `q3` est `good` et **PAS** `mastered`.
> **Test porteur** : **table exhaustive q0,q1,q2,q3,q4,q5 + jamais-vue → niveau attendu** (7 cas, **aucun trou**).
> **Injection R3** : passer `bad` à « q1-2 » (le résidu PRD) ⇒ le cas **q0** **rougit** — AD-46 :
> « **aucune note n'est hors seau** ».

### AC11 — Tirage aléatoire : source **INJECTÉE**, et **PROUVÉE consultée**

**Given** `zDrawQuestions(eligible, count: n, random: r)` et 100 cartes éligibles pour `count: 10`
**When** le tirage s'exécute
**Then** il rend **exactement 10** cartes, **toutes** ⊆ `eligible`, **sans doublon**
**And** `Random(seed)` ⇒ résultat **strictement déterministe** (même graine ⇒ même tirage, assert sur
la **séquence d'ids entière**)
**And** 🔴 **deux graines différentes ⇒ deux sous-ensembles différents** — c'est **LE** test qui prouve
que l'aléa est **réellement consulté** : une implémentation « prendre les 10 premières » passerait
tous les autres tests et **rougit uniquement sur celui-ci**
**And** `count >= eligible.length` ⇒ **tout** est rendu (aucun tirage, aucun throw)
**And** `count <= 0` ⇒ **vide** (cohérent avec `ZStudySessionSelector`, `count <= 0` ⇒ vide — lu `:52`).
> **Injection R3** : remplacer le corps par `eligible.take(count)` ⇒ le test « graines différentes » rougit.
> 🚫 Interdit : `Random()` sans graine dans un test (flaky), ou un test qui n'assert que `length` (tautologique).

### AC12 — Mélange des choix QCM : l'**ASSOCIATION** survit (leçon su-2)

**Given** `zShuffleChoices(choices, random: r)` et `ZChoice{content, isCorrect}` (lu : `isCorrect` est
porté **PAR l'objet**)
**When** les choix sont mélangés avant la session
**Then** le mélange **permute les objets `ZChoice`** — **jamais** les `content` séparément d'un index
de bonne réponse
**And** 🔴 le **multiset des PAIRES `(content, isCorrect)`** est **strictement préservé** — pas
seulement l'ensemble des `content` : c'est **exactement** le défaut su-2 (« marqueur attribué au
**mauvais** choix ») ; un test qui n'assert que les `content` **ne peut pas** le voir
**And** aucun choix n'est **perdu** ni **dupliqué** (longueur + multiset)
**And** graines différentes ⇒ ordres différents (même preuve qu'AC11)
**And** `choices == null` / **vide** / **un seul** choix ⇒ **jamais** de throw (AD-10)
**And** l'**original n'est jamais muté** (le mélange rend une **nouvelle** liste).
> **Injection R3** : mélanger les `content` en laissant `isCorrect` à sa position ⇒ l'assertion de
> **paires** rougit (l'assertion de `content` seule, elle, resterait **verte** — c'est la démonstration).

### AC13 — Robustesse (AD-10) — **jamais** de throw

**Given** les entrées dégénérées
**When** su-6 s'exécute
**Then** **aucune** exception, **aucun** écran vide non expliqué :

| Entrée | Attendu |
|---|---|
| Dossier **vide** (0 carte) | Sélecteur affiché, **aucune** option de session, **jamais** de throw |
| **Aucune** carte due | « À réviser » **absente** (jamais grisée) |
| **Aucune** jamais apprise | « Apprendre +N » **absente** |
| Lot demandé **> 30** dispo (60 cartes) | **exactement** `batchSize` (défaut 30) |
| `byQuality` **corrompu** (`{'9': 3, '': 1, '03': 2, '5': -3}`) | clés hors échelle **ignorées**, crans négatifs **plancher 0**, jamais de throw (patron `zMasteredCount` lu `:109-122`) |
| Qualité **hors échelle** (`lastQuality = 9` ou `-2`) | **`config.clampQuality`** — **UNIQUE** voie de clamp (AD-46) ; classée dans un seau, jamais « hors seau » |
| Streak : date **future**, **dupliquée**, **désordonnée** | AC3 (repli `alreadyCountedToday`, jamais négatif, idempotent) |
| Filtres ne retenant **rien** | **liste vide** rendue, **jamais** un throw, message d'état vide |
| `ZRepetitionInfo` **absent** pour une carte | carte = **jamais vue** (repli), jamais un throw |

### AC14 — A11y / l10n / thème / RTL — la garde est **auto-énumérante** : ne pas la doubler

**Given** que `z_purity_test.dart` **auto-énumère** `lib/` (`Directory('lib').listSync(recursive: true)`, lu `:41-48`)
**When** les nouveaux widgets sont ajoutés
**Then** ils sont **nés gardés** — **aucune garde parallèle** n'est créée ; on **étend** l'existante si besoin
**And** aucun **libellé** ni **couleur** codés en dur (NFR-SU4/NFR-SU5) — passage par `ZcrudLabels` +
`Theme.of(context)`/`ThemeExtension`
**And** cibles tactiles **≥ 48 dp** + `Semantics` explicites (AD-13/NFR-SU3)
**And** variantes **directionnelles** uniquement (`EdgeInsetsDirectional`, `AlignmentDirectional`,
`TextAlign.start/end`) — RTL
**And** 🔴 **angle mort CONNU** : la garde de libellés **ne couvre PAS `Semantics(label:)`** ⇒ le badge
flamme, l'anneau de progression et les 3 options portent un `Semantics(label:)` **issu de `ZcrudLabels`**,
**vérifié par un test dédié** (la garde ne le fera pas)
**And** 🔴 **un défaut est un MOTIF** (leçon su-5 : `Semantics`+`Text` corrigé à un endroit, **3 autres
tuiles** laissées cassées) : le correctif est appliqué à **TOUTES** les tuiles/badges du diff, et le
test **énumère** les tuiles — jamais une seule.
> ⚠️ **Reduce Motion** : l'anneau de progression et la flamme sont **statiques** si Reduce Motion (NFR-SU3).
> 🚫 Leçon su-3 : **aucune animation factice** « pour la conformité » — si une animation n'est pas
> requise, on ne la simule pas (un test ne peut pas rougir sur du décor).

### AC15 — **enums > booléens** (convention du spine)

**Given** les variantes de su-6
**When** elles sont typées
**Then** `ZMasteryLevel { bad, good, mastered }`, `ZStreakOutcome { started, incremented,
alreadyCountedToday, resetToOne, skippedNotGraded }`, `ZSessionModeKind { learnNew, review, test }`
**And** **aucun** `bool isMastered` / `bool didIncrement` / `bool isTest` dans une signature publique
**And** aucun enum public sans `@JsonKey(unknownEnumValue:)` **s'il est persisté** (`ZStreakOutcome`
et `ZMasteryLevel` **ne le sont pas** : valeurs de retour **runtime** — consigné).

### AC16 — Vérif verte & gates (rejoués **réellement** sur disque)

**Given** la story déclarée verte
**When** l'orchestrateur rejoue
**Then** `melos run generate` **OK** (`z_study_streak.g.dart` généré **ET committé**)
**And** `flutter analyze` **RC=0** · tests **RC=0** **par package**
**And** `python3 scripts/dev/graph_proof.py` **RC=0** (**ACYCLIQUE** + **CORE OUT=0**, **53** arêtes après D3)
**And** `melos run analyze` **ET** `melos run verify` **REPO-WIDE** verts au gate de commit d'epic
(⚠️ une vérif **par package** ne détecte **PAS** une régression cross-package — précédent réel :
`ZExportApi` supprimé en E11a-3 cassant `zcrud_flashcard`, `melos analyze` resté **ROUGE** plusieurs commits).

---

## Spécifications techniques — contrat à livrer

### `packages/zcrud_study_kernel/` (pur-Dart — **aucun** import Flutter)

```dart
// lib/src/domain/z_study_streak.dart  (+ z_study_streak.g.dart généré ET committé)
@ZcrudModel()
class ZStudyStreak implements ZEntity {
  const ZStudyStreak({this.id, this.current = 0, this.best = 0, this.lastGradedDay});
  factory ZStudyStreak.fromMap(Map<String, dynamic> map);   // défensif (AD-10)
  final String? id;
  final int current;        // série en cours ; jamais négatif
  final int best;           // record ; jamais < current
  final String? lastGradedDay; // jour civil ISO-8601 'yyyy-MM-dd' ; null = jamais
  Map<String, dynamic> toMap();
  ZStudyStreak copyWith({...});
}

/// Jour civil LOCAL — le SEUL point de dérivation (AC3).
typedef ZCivilDayOf = String Function(DateTime at); // défaut: (at) => 'yyyy-MM-dd' de DateTime(at.year, at.month, at.day)

enum ZStreakOutcome { started, incremented, alreadyCountedToday, resetToOne, skippedNotGraded }

class ZStreakAdvance { final ZStudyStreak streak; final ZStreakOutcome outcome; }

/// PUR. Horloge PARAMÉTRÉE (AD-14). Reset à 1 (JAMAIS 0). Idempotent par jour civil LOCAL.
ZStreakAdvance zAdvanceStreak(
  ZStudyStreak current, {
  required DateTime at,
  required ZReviewMode mode,
  ZCivilDayOf civilDayOf,   // injectable → DST réellement testable (AC3)
});
```

### `packages/zcrud_flashcard/` (domaine — voit `ZSrsConfig` **et** le kernel)

```dart
// lib/src/domain/z_srs_config.dart  — AJOUT (D2/AC9)
int get masteredThreshold => maxQuality - 1;   // SOURCE UNIQUE. Jamais le littéral 4.

// lib/src/domain/z_flashcard_filters.dart — NOUVEAU (FR-SU12, PUR)
enum ZMasteryLevel { bad, good, mastered }
ZMasteryLevel zMasteryLevelOf(ZRepetitionInfo? info, ZSrsConfig config); // clampQuality = unique voie

class ZFlashcardTestFilters {           // valeurs, immuable
  final int questionCount;              // défaut 10
  final Set<String> questionTypes;      // vide = tous
  final Set<ZMasteryLevel> masteryLevels;
  final Set<String> tagIds;
  final Set<String> sources;
}

/// PURE. CONSOMME ZStudySessionSelector (dossier ∧ tags ∧ types) — jamais réécrit.
List<ZFlashcard> zApplyTestFilters(
  Iterable<ZFlashcard> cards, {
  required Map<String, ZRepetitionInfo> srsById,  // index O(1) — AC8
  required ZFlashcardTestFilters filters,
  required ZSrsConfig config,
  required ZStudySessionSelector selector,
  required Random random,                          // INJECTÉ — AC11
});

List<T> zDrawQuestions<T>(List<T> eligible, {required int count, required Random random});
List<ZChoice> zShuffleChoices(List<ZChoice> choices, {required Random random}); // paires préservées — AC12

// lib/src/domain/z_session_categorization.dart — NOUVEAU (FR-SU10, O(1) — AC8)
class ZSessionCategories { final List<ZFlashcard> neverLearned, due; }
ZSessionCategories zCategorize(
  Iterable<ZFlashcard> cards, {
  required Map<String, ZRepetitionInfo> srsById,   // lookup set/map — jamais firstWhere
  required DateTime at,                             // horloge INJECTÉE
});
```

### `packages/zcrud_session/` (présentation)

```dart
// pubspec.yaml — AJOUT (D3) : zcrud_ui_kit: ^0.2.1
// lib/src/presentation/z_session_mode_selector.dart — NOUVEAU
enum ZSessionModeKind { learnNew, review, test }
class ZSessionModeSelector extends StatelessWidget {
  const ZSessionModeSelector({
    required this.cards, required this.srsById, required this.at,   // horloge injectée
    required this.streak, required this.srsConfig,
    this.batchSize = 30,                 // FR-SU10 : configurable, défaut 30
    required this.onStart,               // (ZSessionModeKind, List<ZFlashcard>)
    this.onOpenFilters, super.key,
  });
}
// lib/src/presentation/z_streak_badge.dart          — badge flamme (Semantics via ZcrudLabels)
// lib/src/presentation/z_test_filters_dialog.dart   — dialog FR-SU12 (pilote la fonction PURE)
// lib/src/presentation/z_session_summary_view.dart  — :363 UNE ligne : ?? widget.srsConfig.masteredThreshold
```

---

## Tasks / Subtasks

- [ ] **T1 — Streak, domaine kernel** (AC1, AC2, AC3, AC4)
  - [ ] `z_study_streak.dart` (`@ZcrudModel`, `ZEntity`, `fromMap` défensif) + barrel
  - [ ] `melos run generate` → **committer** `z_study_streak.g.dart`
  - [ ] `ZStreakOutcome`, `ZStreakAdvance`, `ZCivilDayOf`, `zAdvanceStreak` (pur, horloge paramétrée)
  - [ ] Tests : tableau AC2 (valeurs **exactes**) + **7 cas aux bornes AC3** (DST 23 h/25 h, minuit, UTC vs local, date future, idempotence) + énumération `ZReviewMode.values` (AC4)
- [ ] **T2 — Persistance du streak** (AC5)
  - [ ] `ZStudyRepository<ZStudyStreak>` consommé ; **aucun** port neuf ; `Either` ; repli sur `Left`
- [ ] **T3 — Seuil de maîtrise : promotion + consommation** (AC9, D2)
  - [ ] `ZSrsConfig.masteredThreshold` (getter dérivé) + dartdoc citant la garde **réelle**
  - [ ] `z_session_summary_view.dart:363` → `?? widget.srsConfig.masteredThreshold` (**une ligne**)
  - [ ] Garde du même patron dans `packages/zcrud_flashcard/test/` (littéral `4`/`max - 1` hors propriétaire)
  - [ ] Vérifier `grep "scale.max - 1" packages/zcrud_session/lib/ -q` → **RC=1**
- [ ] **T4 — Catégorisation O(1)** (AC7, AC8)
  - [ ] `zCategorize` par **index `Map`** ; tri par urgence exact
  - [ ] 🔴 Test-**sonde comptant les lectures** (N=200 / N=1600, `<= 4N`) + **contre-preuve O(n²) dans le même fichier** qui doit **ÉCHOUER**
- [ ] **T5 — Filtres purs FR-SU12** (AC10, AC11, AC12)
  - [ ] `ZMasteryLevel` + `zMasteryLevelOf` (bornes **toutes** de `ZSrsConfig`, `clampQuality` unique voie)
  - [ ] `zApplyTestFilters` **déléguant** à `ZStudySessionSelector.matches` (jamais réécrit)
  - [ ] `zDrawQuestions` / `zShuffleChoices` — `Random` **injecté**
  - [ ] Tests : table **7 cas** q0..q5 + jamais-vue ; `q3 = good ≠ mastered` ; **graines différentes** ; **paires `(content,isCorrect)`**
- [ ] **T6 — `ZSessionModeSelector` + badge + dialog** (AC6, AC7, AC13, AC14, AC15)
  - [ ] 3 options (règles de visibilité), anneau, badge flamme, dialog de filtres
  - [ ] Toast via `ZToasterScope.of` + arête `zcrud_ui_kit` au pubspec ; **espion prouvé branché**
  - [ ] `Semantics(label:)` via `ZcrudLabels` sur **TOUTES** les tuiles (motif, pas un point)
  - [ ] Options **`tap`ées** dans les tests (jamais la seule présence)
- [ ] **T7 — Robustesse** (AC13) : dossier vide · 0 due · 0 jamais-vue · lot > 30 · `byQuality` corrompu · qualité hors échelle · dates futures/dupliquées/désordonnées · filtres vides
- [ ] **T8 — Vérif verte** (AC16) : `generate` + `analyze` + `flutter test` **par package** + `graph_proof.py` (**53** arêtes)

---

## Stratégie de test

### ⚠️ `melos run test` est INUTILISABLE (parallélise, se bloque) — `flutter test` PAR PACKAGE

```bash
cd /home/zakarius/DEV/zcrud
dart run melos run generate
cd packages/zcrud_study_kernel && dart test          # pur-Dart (baseline 313)
cd ../zcrud_flashcard        && flutter test         # baseline 399
cd ../zcrud_session          && flutter test         # baseline 418
cd ../.. && python3 scripts/dev/graph_proof.py       # RC=0 ; 53 arêtes après D3
# Gate de commit d'epic (workstreams au repos) — REPO-WIDE, NON négociable :
dart run melos run analyze && dart run melos run verify
```
**Baseline héritée** : **23/23 packages, 4097 tests** (`zcrud_session` **418**, `zcrud_flashcard` **399**,
`zcrud_study_kernel` **313**) — à **rejouer réellement**, jamais à recopier de ce document.

🚫 **Jamais `git checkout`** (su-1..su-6 **non committés** — un checkout les **détruit**).
🚫 **Jamais `dart format`**.

### Discipline R3 — un test qui ne rougit pas ne prouve rien

Pour **chaque** AC : fichier réel + test porteur + **injection qui doit le faire rougir**.
🔴 **Chaque rouge doit être causé par le COMPORTEMENT** — une injection qui casse la **compilation**
rougit tout et ne prouve **RIEN**.

### 🔴 Défauts déjà démasqués dans cet epic — **interdits de récidive**

| Défaut | Story | Ce que su-6 fait |
|---|---|---|
| **Présence ≠ association** (marqueur sur le **mauvais** choix) | su-2 | **AC12** : multiset des **paires**, pas des `content` |
| **Contrôle jamais ACTIONNÉ** (« précédent » qui avançait) | su-4 | **AC7** : chaque option **`tap`ée**, on assert la file **reçue** |
| **Un défaut est un MOTIF** (3 tuiles laissées cassées) | su-5 | **AC14** : test **énumérant** toutes les tuiles |
| **Assertion vs constante du code** (« 48 dp ») | su-4 | **AC8** : `k`/`N` **littéraux dans le test** |
| **Espion jamais branché** (infalsifiable) | — | **AC6** : prouver **1 appel** avant d'asserter **0** |
| **Garde aveugle / dé-commentateur inadapté** (Dart sur du YAML) | su-5 | **AC9** : la garde citée **voit** ce qu'elle garde, ou on ne la cite pas |
| **Animation factice** | su-3 | **AC14** : rien de simulé « pour la conformité » |
| **Assertions faibles** (`isNotNull`, `isNotEmpty`, `lessThanOrEqualTo`) | — | valeurs/séquences **exactes** partout |
| **Modifier un test pour taire un défaut réel** | su-2 | 🚫 **JAMAIS** |

---

## Dev Notes

- **Le piège n°1 de cette story est D2** : `maxQuality` est **épinglé à 5** par `assert` ⇒ écrire `4`
  au lieu de `maxQuality - 1` est **ISO-COMPORTEMENTAL**, **toute la suite reste VERTE**, et le
  reviewer suivant lit un dartdoc rassurant. **Seule** la garde structurelle attrape ça. C'est
  **littéralement** le HIGH de su-1, et su-5 a documenté le mécanisme en détail — le relire
  (`z_quality_scale_single_source_test.dart:11-37`) **avant** d'écrire une ligne.
- **Le piège n°2 est le jour civil** : `at.difference(other).inDays` **paraît** juste et casse en DST
  (23 h → `0` ; 25 h → `1`). D'où la dérivation civile **explicite** + `civilDayOf` injectable :
  sans lui, le DST **n'est pas testable** sans dépendre du `TZ` de la CI.
- **Le piège n°3 est la preuve d'absence** : `grep … | head ; echo $?` rend le RC de `head`. Utiliser
  `grep -q` **sans pipe**.
- `zcrud_study_kernel` est **pur-Dart** (`dart test`, pas `flutter test`) : **aucun** import Flutter
  dans le streak. `Random`/`DateTime` viennent de `dart:math`/`dart:core` — légaux.
- L'arête `zcrud_session → zcrud_ui_kit` (D3) est la **seule** modification de graphe de la story :
  `graph_proof.py` doit passer de **52** à **53** arêtes, en restant **ACYCLIQUE / CORE OUT=0**.

### Project Structure Notes

- `zcrud_study_kernel` (domaine pur, codegen) · `zcrud_flashcard` (domaine, filtres+catégorisation) ·
  `zcrud_session` (présentation) — conforme à AD-1 et au placement du spine (« `zcrud_study_kernel`
  (streak) » y est **nommément** prévu).
- **Aucune** écriture dans `zcrud_core` (réservé à E-MULTI-EDIT).
- Variance assumée : su-6 modifie **une ligne** de su-5 (`:363`) et **ajoute un getter** à
  `ZSrsConfig` (su-1) — justifié par D2/AC9 (exécution du handoff écrit de su-5), borné, gardé.

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-ui-2026-07-16/epics.md#Story 1.6`]
- [Source: `.../architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md#AD-46, AD-33, AD-34, §Conventions, §Écarts assumés, §Placement des paquets`]
- [Source: `.../prds/prd-zcrud-study-ui-2026-07-16/prd.md#FR-SU10, FR-SU11, FR-SU12, §4 Glossaire`]
- [Source: `docs/parity-study-ui-2026-07-16/annexes/iffd_flashcards.md` — best-of-breed : « Apprendre +N » lot 30, « À réviser » par urgence, « Test » + dialog, badge flamme, lookup sets O(1)]
- [Source: `_bmad-output/implementation-artifacts/stories/su-5-ecran-fin-feedback-pedagogique.md#D9 — Handoff su-6`, `#D3`, `#File List`]
- [Source: `_bmad-output/implementation-artifacts/stories/code-review-su-5.md`]
- [Source: `CLAUDE.md` — cycle BMAD strict, gates, Key Don'ts]
- Code lu : `z_srs_config.dart:17-47` · `z_srs_quality_buttons.dart:40-68` · `z_session_summary_view.dart:80-122,361-365` ·
  `z_study_session_selector.dart:34-88` · `z_session_candidate.dart:26-39` · `z_repetition_info.dart:66-90` ·
  `z_study_repository.dart:68-115` · `z_toaster.dart:23-39` · `z_toaster_scope.dart:23-51` ·
  `z_review_mode.dart:28-43` · `z_choice.dart:25-40` · `z_flashcard.dart:148,167,236` ·
  `z_quality_scale_single_source_test.dart:100-122` · `z_purity_test.dart:41-48` ·
  `z_third_party_confinement_test.dart:83-124` · `scripts/dev/graph_proof.py`

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
