# Code Review — E9-2 : SRS pluggable (`ZRepetitionInfo` + `ZSrsScheduler`, SuperMemo-2)

- **Story** : `_bmad-output/implementation-artifacts/stories/e9-2-srs-pluggable-zsrsscheduler.md`
- **Package** : `zcrud_flashcard`
- **Baseline** : `04aaaf0`
- **Mode skill** : `bmad-code-review` invoqué via le tool `Skill` (step-file architecture), exécution adversariale inline (3 axes : Blind Hunter / Edge Case Hunter / Acceptance Auditor) par le sous-agent — pas de fallback disque nécessaire.
- **Périmètre** : fichiers E9-2 UNIQUEMENT (`z_srs_config.dart`, `z_repetition_info.dart`, `z_srs_scheduler.dart`, `z_sm2_scheduler.dart`, barrel, `z_flashcard_api.dart`, 2 tests). E9-1 / E5 / E10 exclus.

## Vérif verte rejouée (réelle, sur disque)

| Gate | Commande | Résultat |
|------|----------|----------|
| Codegen | `dart run build_runner build --delete-conflicting-outputs` | OK — asset graph à jour, `z_repetition_info.g.dart` présent (gitignoré), 0 output à réécrire |
| Analyze | `dart analyze .` | **RC=0** — « No issues found! » |
| Test | `flutter test` | **RC=0** — **59 tests passés** (32 E9-2 : 20 scheduler + 12 repetition_info ; 27 E9-1 hérités) |
| Anti-`reflectable` | grep sur les 4 fichiers algo | vide (OK) |
| Pureté AD-14 | grep imports `flutter`/`firebase`/`cloud_firestore`/`hive` sur fichiers algo | vide (OK, pur-Dart) |
| Isolation AD-1 | `git status packages/zcrud_core/**` (attribuable à E9-2) | aucun fichier core touché par la story (OK) |

## Findings

### HIGH / MAJEUR
Aucun.

### MEDIUM

**M-1 — AC7 : le constructeur `const` public expose tous les champs SRS → voie de construction arbitraire hors `apply()`**
`z_repetition_info.dart:73-84` — le constructeur `ZRepetitionInfo({required flashcardId, required folderId, interval, repetitions, easeFactor, nextReviewDate, learnedAt, lastQuality, …})` est **public et exporté** par le barrel. N'importe quel consommateur peut fabriquer un état SRS arbitraire (`ZRepetitionInfo(flashcardId:'c', folderId:'f', interval: 9999, repetitions: 50, easeFactor: 99.0, …)`) **sans passer par `apply()`**. L'AC7 demandait pourtant que « la reconstruction interne nécessaire à `apply`/`fromMap` reste **privée/de bas niveau** … jamais une API d'avancement publique concurrente ». Le `hide ZRepetitionInfoZcrud` du barrel ferme bien la porte du `copyWith` généré (vérifié : barrel l.22 ; l'appel interne `ZRepetitionInfoZcrud(this).toMap()` reste résolu dans le fichier source), mais il **ne ferme pas** la porte du constructeur public.
- **Impact** : la « voie d'écriture UNIQUE » (AD-9) n'est garantie qu'**par convention/dartdoc**, pas par le type. Un appelant peut injecter un état SRS incohérent en contournant l'algorithme.
- **Nuance déterminante** : cette ouverture est **architecturalement inévitable** compte tenu d'AC3/FR-17 — un scheduler alternatif (FSRS/Leitner) vivant dans **un autre package** doit pouvoir construire un `ZRepetitionInfo` ; le test `_FixedStepScheduler` le prouve d'ailleurs en appelant ce même constructeur. `@internal` (meta) casserait ce contrat inter-package. Il n'existe donc pas de correctif « privatisant » sans sacrifier la remplaçabilité, qui est la priorité produit.
- **Recommandation** : **justifier par écrit** (politique MEDIUM : corriger OU justifier). Acter dans la story que la garantie « voie unique » est **de niveau convention** (dartdoc + `hide` du `copyWith`), volontairement subordonnée à AC3 (seam de construction public requis pour les schedulers tiers). Optionnel : renommer le constructeur en un nommé plus explicite (`ZRepetitionInfo.raw`/`.reconstruct`) pour signaler l'intention « bas niveau, ne pas utiliser pour avancer l'état ». **Pas de blocage `done`.**

### LOW / nits

**L-1 (point a) — `last_quality` hors bornes conservé par `fromMap` alors qu'`apply` clampe à `0..5`**
`z_repetition_info_test.dart:109-112` + `z_sm2_scheduler.dart:49,94`. Choix documenté (AC9). **Cohérent, pas incohérent** : le clamp appartient à la **voie d'écriture** (`apply`), la (dé)sérialisation est une couche de **transport zéro-perte** (AC8) qui ne doit rien normaliser. Seule séquelle : un lecteur de persistance peut recevoir `lastQuality ∉ [0;5]`.
- **Reco** : documenter côté API que `lastQuality` lu depuis la persistance n'est pas garanti dans `[0;5]` (le clamp n'intervient qu'au prochain `apply`). Aucun changement de code.

**L-2 (point b) — `overdueBonusFactor` : champ de config totalement inerte**
`z_srs_config.dart:51-54`. Aucune lecture dans `ZSm2Scheduler`. **Correct pour E9-2** : explicitement autorisé par AC4 (« peut rester non appliqué au MVP … le noter explicitement ») et documenté dans le dartdoc. Ce n'est pas de la dette masquée mais une surface de config latente jusqu'à E9-4.
- **Reco** : s'assurer qu'E9-4 (ou un ticket de suivi) référence ce paramètre pour qu'il ne devienne pas une constante morte oubliée. Aucun changement en E9-2.

**L-3 — Variante IFFD : `easeFactor` recalculé aussi sur lapse (q<3)**
`z_sm2_scheduler.dart:53-56` applique la formule easeFactor **quelle que soit l'issue**, y compris sur lapse — alors que le SM-2 **classique** laisse EF inchangé quand `q<3`. **Spec-sanctionné** : AC4 liste la formule easeFactor comme un bullet indépendant de réussite/lapse et nomme la « variante IFFD canonique ». Purement informationnel.
- **Reco** : aucune. Comportement conforme à l'AC et déterministe.

**L-4 — Défaut de désérialisation `ease_factor` figé à `2.5` (non config-aware)**
`z_repetition_info.g.dart:87` (`?? 2.5`, projeté depuis `@ZcrudField(defaultValue: ZSrsConfig.kDefaultEaseFactor)`). Un `ZSrsConfig(defaultEaseFactor: 2.1)` n'affecte **pas** le repli de désérialisation. **Conforme à l'AC** (AC1/AC9 spécifient le défaut = `2.5` constant) et incontournable (le codegen `const` ne peut injecter une config runtime). Informationnel.

## Vérification des axes adversariaux exigés

- **Exactitude SM-2** ✔ intervalles `1 / 6 / round(i·ef·mod)` (test : 1,6,15,38) ; lapse `rep=0, interval=1` ; formule easeFactor + **clamp effectif aux DEUX bornes** (`.clamp(min,max)`, plafond 2.5 sur q=5 et plancher 1.3 sur q=3 testés) ; `learnedAt` fixé à la 1re réussite et **jamais reset** sur lapse (`current.learnedAt ?? …`, testé) ; `nextReviewDate = now + interval j`. `.round()` Dart (37.5→38) conforme au test.
- **État SRS séparé** ✔ `ZRepetitionInfo` distinct de `ZFlashcard`, `with ZExtensible`, **sans `id`/`ZEntity`**, clé = `flashcardId` ; test `isNot(isA<ZFlashcard>())`.
- **Voie d'écriture unique** ⚠ `copyWith` généré **masqué** (`hide`, OK) ; **mais** constructeur public = seam de construction arbitraire (cf. M-1). `apply()` reste la seule voie de **progression algorithmique**.
- **Sync « map telle quelle »** ✔ `fromMap`/`toMap` sans scheduler ; valeurs impossibles (`easeFactor=9.9`, `interval=999`) conservées (testé) → merge LWW E9-4 non-dérivant garanti.
- **Interface remplaçable** ✔ `abstract interface class` (pas `sealed`) ; `_FixedStepScheduler` substitué produit un planning différent (1,2,3,4 vs 1,6,15,38), modèle inchangé.
- **Désérialisation défensive AD-10** ✔ générateur défensif (`_$asInt`/`_$asDouble`/`_$asDateTime` → repli) + sanitisation manuelle des négatifs ; map vide, `ease_factor` non-num, `interval` non-int/négatif, dates illisibles, `extension` corrompue, types mixtes → aucun throw parent (testé).
- **Enums camelCase / `@JsonKey(unknownEnumValue)`** — N/A ici : `ZRepetitionInfo` ne porte aucun enum (qualité = `int 0..5` générique, conforme au cadrage).
- **`ZSrsConfig` injectable** ✔ toutes les bornes/seuils lus depuis `config` ; injection prouvée (`defaultIntervalModifier`/`maxEaseFactor`/`passThreshold` custom changent le planning). Les coefficients intrinsèques de la formule SM-2 (`0.1/0.08/0.02`, intervalles `1/6`) sont hardcodés — c'est la définition même de « SM-2 » (hors liste `ZSrsConfig`), conforme.
- **Isolation AD-1 / pureté AD-14** ✔ zéro edit `zcrud_core`, zéro import lourd dans les fichiers algo.

## Positions argumentées sur les points à trancher

- **(a) `last_quality` hors bornes conservé tel quel** → **ACCEPTABLE**, non incohérent avec le clamp d'`apply`. Le clamp est une règle de la voie d'écriture, pas de la couche de transport ; AC8 impose explicitement le zéro-perte à la (dé)sérialisation. La seule dette est documentaire (L-1).
- **(b) `overdueBonusFactor` inerte** → **CORRECT pour E9-2**, pas une dette bloquante : autorisé mot pour mot par AC4 et documenté. À reprendre en E9-4 (L-2).
- **(c) `ZRepetitionInfo` sans `id`/`ZEntity`** → **COHÉRENT** avec « état top-level séparé ». `flashcardId` est la clé naturelle 1↔1 (`study_repetitions/{cardId}`, canonique §7) ; ajouter un `id` `ZEntity` créerait un second axe d'identité susceptible de diverger de la clé de jointure. Conforme à AC1.

## Verdict

**PRÊT POUR `done`.** Aucun finding HIGH/MAJEUR. Le seul MEDIUM (M-1) est un écart au **libellé littéral** d'AC7 rendu **architecturalement inévitable** par AC3/FR-17 (seam de construction public requis pour schedulers tiers) et déjà couvert par le dartdoc + le `hide` du `copyWith` → **à justifier par écrit** (politique MEDIUM), sans correctif de code. Les LOW sont optionnels/documentaires. Vérif verte réelle : codegen OK, analyze RC=0, `flutter test` RC=0 (59 tests).

---

## Résolution (orchestrateur)

Vérif verte : `dart analyze packages/zcrud_flashcard` RC=0, `flutter test packages/zcrud_flashcard` **59 tests** RC=0.

- **0 HIGH / 0 MAJEUR.**
- **M-1 (MEDIUM) — REPORTÉ AVEC JUSTIFICATION ÉCRITE** (politique MEDIUM). Le constructeur `const` public de `ZRepetitionInfo` expose les champs SRS hors `apply()`, ce qui s'écarte du libellé littéral d'AC7 (« reconstruction privée »). **Correction non faisable sans sacrifier une exigence supérieure** : AC3/FR-17 impose un seam PUBLIC pour les schedulers tiers remplaçables (prouvé par `_FixedStepScheduler` de test, inter-package) ; `@internal`/constructeur privé casserait la remplaçabilité. La voie d'écriture SRS canonique reste protégée par `hide ZRepetitionInfoZcrud` (copyWith généré masqué) + dartdoc « seule voie d'avancement = apply() ». Écart cosmétique acceptable, aucune régression. Option future non bloquante : renommer en constructeur `.raw`/`.reconstruct` (signalétique).
- **LOW-1/2/3/4 — CONSIGNÉS** (documentaires/informationnels) : `last_quality` hors bornes conservé au transport (cohérent AC8) ; `overdueBonusFactor` inerte (autorisé AC4, activé E9-4) ; easeFactor recalculé au lapse (variante spec-sanctionnée) ; défaut `ease_factor=2.5` figé (incontournable codegen const).

**Verdict final : `done`.**
