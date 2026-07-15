---
baseline_commit: aaa7989612f5213509daae9ddbddb7a7513cd650
---

# Story ES-4.1 : [TÊTE — résolution différée] Convergence de l'ordonnanceur SRS sur SM-2 canonique + tests de contrat

Status: review

<!-- Epic ES-4 : SRS convergé + runtimes de session. TÊTE d'ES-4 — bloque ES-4.2/4.3/4.4 (les runtimes de session s'appuient sur la source SM-2 unique verrouillée ici). -->
<!-- Résolution DIFFÉRÉE OQ-S3 (AD-22) : la comparaison numérique aux impls externes lex/IFFD/dodlp est DOCUMENTAIRE ; le critère EXÉCUTABLE in-repo = les tests de contrat de planification. -->
<!-- ⚠️ PARALLÉLISATION — workstream A. Un workstream B (epic ES-5) écrit packages/zcrud_study/** en parallèle. ISOLATION STRICTE : cette story n'écrit QUE zcrud_flashcard (+ la note AD-22 par édition CIBLÉE) ; NE touche PAS zcrud_core, zcrud_study, NI sprint-status.yaml. Vérifs CIBLÉES par package (PAS de melos repo-wide au milieu du dev — délégué à l'orchestrateur au gate de commit). -->
<!-- Gotchas rétro ES-3 en vigueur : R12 (pouvoir discriminant EXIGÉ), R14 (runner par nature du package), R15 (RC capturé HORS pipe), R13 (restauration par édition ciblée, jamais git checkout), R3 (injections orchestrateur), R6 (jamais de dégradation silencieuse). -->

## Story

As a **utilisateur existant dont la planification SRS est active** (et, en amont, le mainteneur qui doit garantir qu'aucune régression de planification n'entre au moment où ES-4.2/4.3/4.4 vont câbler les runtimes de session sur l'ordonnanceur),
I want **que la formule SuperMemo-2 de `ZSm2Scheduler`/`ZSrsScheduler` soit CONFIRMÉE canonique (unifiant déjà lex `Sm2` — plafond EF 2.5 — et la variante IFFD — clamp des DEUX bornes de l'ease factor), figée par une batterie de TESTS DE CONTRAT à vecteurs déterministes (mêmes entrées → mêmes intervalles/EF/échéances) qui ROUGISSENT si la formule dévie, la divergence overdue de lex + le gel de l'échelle qualité 0..5 documentés par écrit (AD-22 + memlog), et la voie d'écriture SRS restant UNIQUE (`reviewCard() → ZSrsScheduler.apply`, AD-9)**,
so that **ma courbe de révision ne subisse aucune régression au moment de la convergence, qu'un futur "petit ajustement" de la formule soit IMPOSSIBLE à merger sans casser un vecteur de contrat rouge, et que les runtimes de session (ES-4.2/4.3/4.4) reposent sur un socle SM-2 verrouillé et documenté.**

---

## Contexte & état mesuré sur disque

> ⚠️ **La convergence est déjà réalisée dans le CODE.** `ZSm2Scheduler` a été livré en **E9-2** et AD-22 le déclare canonique « vérifié sur le code ». Cette story **N'ÉCRIT PAS un nouvel algorithme** : elle (1) **confirme** que l'algo courant EST canonique par comparaison numérique mesurée aux sources externes, (2) le **VERROUILLE** par un fichier de contrat à vecteurs figés, (3) **documente** les divergences tranchées. **Par défaut : AUCUN changement de comportement du scheduler.** Tout ajustement resterait l'exception à justifier (§ D5), jamais la règle.

### 1. L'algorithme courant `ZSm2Scheduler` (lu INTÉGRALEMENT — `packages/zcrud_flashcard/lib/src/domain/z_sm2_scheduler.dart`)

```dart
// EF : recalculé À CHAQUE appel, y compris sur lapse (l.53-54)
final rawEase = current.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
final easeFactor = rawEase.clamp(config.minEaseFactor, config.maxEaseFactor).toDouble(); // clamp des DEUX bornes (l.55-56)

final passed = q >= config.passThreshold;                    // seuil réussite (l.58)
if (passed) {
  repetitions = current.repetitions + 1;
  if (current.repetitions == 0)      interval = 1;           // clé sur repetitions AVANT incrément (l.64-73)
  else if (current.repetitions == 1) interval = 6;
  else interval = (current.interval * easeFactor * config.defaultIntervalModifier).round();
} else {                                                     // lapse (l.75-78)
  repetitions = 0; interval = 1;
}
final learnedAt = current.learnedAt ?? (passed ? effectiveNow : null); // 1re réussite, JAMAIS null ensuite (l.81)
final nextReviewDate = effectiveNow.add(Duration(days: interval));     // now + interval jours (l.82)
```
- Qualité **clampée `0..5`** défensivement (`quality.clamp(0, 5)`, l.49) — jamais de throw ; absorbe l'échelle IFFD 1-5.
- Horloge **injectée** (`now`, l.47), `simulate` délègue à `apply` (l.100-105).
- **AUCUNE** contribution overdue.

### 2. `ZSrsConfig` (défauts canoniques — `z_srs_config.dart` l.20-27, l.33)
`minEaseFactor 1.3` · `maxEaseFactor 2.5` · `defaultEaseFactor 2.5` (`kDefaultEaseFactor`) · `defaultIntervalModifier 1.0` · `overdueBonusFactor 0.5` (**inerte** au MVP, l.51-54) · `passThreshold 3`.

### 3. `ZRepetitionInfo` (contenant PUR, AUCUNE formule — `z_repetition_info.dart` l.63-322)
- Séparé de la carte (`flashcardId` = clé de jointure, pas d'`id`/`ZEntity`, l.126-128).
- **Voie d'écriture UNIQUE (AD-9, AC7 d'E9-2)** : aucun `copyWith`/setter SRS public ; l'extension générée `ZRepetitionInfoZcrud` (qui porte `copyWith`) est **masquée du barrel** (`hide`, `zcrud_flashcard.dart` l.132). Seul `withFolder` existe (relocalisation de routage, NON une voie d'avancement — l.194-205 : ne prend aucun paramètre d'ordonnancement, n'invoque aucun scheduler).
- `fromMap`/`toMap` (dé)sérialisent l'état **TEL QUEL** sans jamais invoquer un scheduler (AD-9/AD-10, sync « map telle quelle »), sanitisation défensive `interval`/`repetitions` négatifs → 0 (l.115-116).

### 4. Couverture de test EXISTANTE (`test/z_srs_scheduler_test.dart` — lu INTÉGRALEMENT)
Teste déjà le **comportement** : courbe q=5 `1,6,15,38` (l.38-67), croissance/plafond EF 2.5, décroissance/plancher EF 1.3, lapse `repetitions=0/interval=1/learnedAt préservé`, clamp qualité `-3≡0`/`99≡5`, config injectée, remplaçabilité (`_FixedStepScheduler`), `simulate=apply`, voie unique. **CE N'EST PAS un test de CONTRAT figé** : il vérifie des propriétés (monotonie, bornes) et quelques points, mais **ne matérialise PAS une TABLE DE VECTEURS déterministes exhaustive** liant chaque `(état initial, séquence de qualités, now) → (interval, repetitions, easeFactor, nextReviewDate, learnedAt, lastQuality)` attendus. **Anti-inertie : ne PAS dupliquer ce fichier — le NOUVEAU `z_sm2_contract_test.dart` porte la TABLE GELÉE distincte** (le golden numérique verrouillé, raison d'être de la résolution ES-4.1, epic F3).

---

## Reconnaissance externe MESURÉE (documentaire — AD-22, epic F3)

> La comparaison aux impls externes est **DOCUMENTAIRE** (note écrite, pas un test CI : le code lex/IFFD n'est pas rejouable dans la CI zcrud). Chiffres et emplacements **MESURÉS sur disque** ci-dessous. Le critère de résolution **exécutable in-repo** reste `z_sm2_contract_test.dart`.

### lex `Sm2` — la RÉFÉRENCE (`~/DEV/lex_douane/packages/lex_core/lib/domain/usecases/education/sm2.dart`, lu INTÉGRALEMENT)
- Constantes (l.107-122) : `minEaseFactor 1.3` · `maxEaseFactor 2.5` · `defaultEaseFactor 2.5` · `defaultIntervalModifier 1.0` · `overdueBonusFactor 0.5` · `passThreshold 3` — **valeurs IDENTIQUES à `ZSrsConfig`**.
- EF (l.233-243) : `ef + (0.1 - (5-q)*(0.08 + (5-q)*0.02))`, clamp `[1.3;2.5]` — **formule + clamp des deux bornes IDENTIQUES** à `ZSm2Scheduler`.
- Intervalles (l.152-160) : clé sur `newRepetitions` (APRÈS incrément) `==1→1`, `==2→6`, `≥3→round(interval*EF) + overdueContribution`.
- **Bonus overdue** (l.248-263) : régime multiplicatif SEUL, `min(round(overdueDays*0.5), base)` jours crédités si révision APRÈS `nextReviewDate` ; `0` si à l'heure/en avance, sur lapse, ou paliers 1/6.
- **`intervalModifier` appliqué à TOUS les régimes** (l.165, 265-268) : `_applyModifier(raw, mod) = max(1, round(raw*mod))` — y compris paliers 1/6 ET lapse ; param **par appel** (`apply(..., intervalModifier)`).
- Échelle qualité : `Sm2QualityLevel` **1-5** (l.11-25 : `complique(1)`…`tresFacile(5)`) ; `q=0` valide dans `apply` (traité en lapse) mais **aucun bouton UI**.
- Voie d'écriture UNIQUE confirmée : `repetition_repository_impl.dart` l.26-27/l.134 — `reviewCard` applique `Sm2.apply` en interne ; `initRepetition` = seul autre write (état neuf).

### IFFD `Sm` — la « variante IFFD » (MESURÉ : pas de classe domaine propre)
- La dartdoc de lex `Sm2` (l.65) l'énonce : **lex `Sm2` EST « la variante IFFD »** (clamp des deux bornes, échelle via `Sm2QualityLevel`). Recherche sur `~/DEV/iffd/lib` : **aucune classe algorithme domaine `Sm`/`Sm2` isolée** — la logique SRS est **diffuse dans la présentation** (`iffd/lib/src/presentation/features/flashcards/widgets/*`). Traits distinctifs vs SM-2 canonique pur : **échelle qualité 1-5** (pas de q=0) + **clamp des DEUX bornes de l'EF**. Ces deux traits sont **déjà unifiés** dans `ZSm2Scheduler` (clamp `0..5` absorbe 1-5 sans throw ; clamp `[1.3;2.5]` des deux bornes).

### dodlp — MESURÉ : **AUCUN module SRS** (`~/DEV/dodlp-otr/lib`)
- `find` sur `*flashcard*`/`*sm2*`/`*repetition*` dans `dodlp-otr/lib` : **0 fichier**. dodlp est l'app douane (CRUD `data_crud` réflexif `reflectable`), **sans module d'étude/SRS**. **Correction mesurée de la prémisse épic** (« trois implémentations SM-2 ») : il y a **deux** sources SRS réelles (lex `Sm2` référence + IFFD variante diffuse) et **dodlp n'a rien à converger**. À documenter en note AD-22 (ne pas laisser la prémisse implicite).

---

## Décisions de conception (tranchées ici)

- **D1 — La formule SM-2 canonique TRANCHÉE = `ZSm2Scheduler` COURANT, INCHANGÉ.** Formule figée : `EF' = EF + (0.1 - (5-q)*(0.08 + (5-q)*0.02))`, clamp `[minEaseFactor=1.3 ; maxEaseFactor=2.5]`, recalculé à CHAQUE révision (lapse compris) ; intervalles `rep 0→1j`, `rep 1→6j`, `rep ≥2→round(interval_préc × EF × modifier)` (clé sur le compteur AVANT incrément — **équivalent** au keying lex sur `newRepetitions` puisque `newRep = current.rep+1`) ; lapse (`q < passThreshold=3`) → `repetitions=0, interval=1` ; `learnedAt` à la 1re réussite, jamais `null` ensuite ; `nextReviewDate = now + interval jours` ; qualité **clampée 0..5**.
- **D2 — Parité numérique lex↔zcrud PROUVÉE au régime de défaut.** À `ZSrsConfig()` par défaut (`modifier=1.0`) et pour des révisions **à l'heure/en avance** (pas d'overdue), `ZSm2Scheduler.apply` est **numériquement identique** à lex `Sm2.apply` : EF (formule+clamp identiques) ; intervalles `round(prev×EF)` (lex `_applyModifier(round(prev×EF),1.0)=round(prev×EF)` = zcrud `round(prev×EF×1.0)`) ; paliers 1/6 ; lapse 1 ; `learnedAt`/`nextReviewDate`. La divergence n'apparaît QUE sous overdue (D3) ou modifier≠1.0 (D4). **C'est le socle de non-régression** (validation comportementale sur données réelles déférée à ES-10.2/ES-11.2).
- **D3 — Bonus overdue de lex : NON porté (SM-2 pur).** Décision AD-22. `overdueBonusFactor` reste dans `ZSrsConfig` comme **point d'extension inerte documenté** (l.51-54), jamais consommé par le scheduler par défaut. Une app qui l'exige fournit **une autre impl `ZSrsScheduler`** (port pluggable, jamais `sealed`). Divergence **documentée par écrit** (AD-22 + memlog).
- **D4 — Divergence SECONDAIRE MESURÉE : portée du `intervalModifier`.** lex applique le modifier à **tous** les régimes (paliers 1/6 et lapse compris, planché à 1) et l'expose **par appel** ; `ZSm2Scheduler` l'applique **uniquement** dans la branche multiplicative (`interval×EF×modifier`), via le champ `config.defaultIntervalModifier`, **pas par appel**. **À `modifier=1.0` (défaut) : identiques.** Divergence visible seulement si une app injecte `modifier≠1.0` (les paliers 1/6/lapse restent fixes en zcrud, sont mis à l'échelle en lex). **Décision : conserver le comportement zcrud tel quel** (pas de régression au défaut ; changer élargirait le périmètre et risquerait une régression) ; **documenter** cette divergence de portée dans la note AD-22/memlog (elle n'était PAS explicitée avant).
- **D5 — Ajustement de code du scheduler = EXCEPTION à justifier, pas la règle.** Le périmètre par défaut est **doc + verrou de contrat**, ZÉRO changement de comportement. Si (et seulement si) un vecteur de contrat révèle une déviation RÉELLE de la formule canonique tranchée (D1), l'ajustement est appliqué **minimalement**, justifié par écrit, et **re-verrouillé** par le vecteur. Aucun ajustement « esthétique » (renommage, réorganisation) qui toucherait la sémantique.
- **D6 — Échelle qualité GELÉE `0..5`, documentée.** Le clamp `0..5` (l.49) absorbe l'échelle IFFD 1-5 **sans throw** (AC6 d'E9-2). Gel documenté : `0` et `1/2` sont des lapses (`< passThreshold`), `3` première réussite, `4/5` réussites. Le mapping UI (boutons 1-5 / `Sm2QualityLevel`) appartient à ES-4.5, **hors périmètre** ici.
- **D7 — Voie d'écriture UNIQUE réaffirmée et VERROUILLÉE (AD-9).** `apply` (avancement) + `initial` (état neuf) sont les seules productions d'état ; `withFolder` est une relocalisation de routage (aucun paramètre d'ordonnancement). Le contrat inclut un vecteur discriminant qui **rougirait** si une seconde voie faisait progresser l'état (§ Injections R3, INJ-4).
- **D8 — Fichier de contrat = `z_sm2_contract_test.dart`, runner `flutter test`.** `zcrud_flashcard/pubspec.yaml` déclare `flutter: sdk: flutter` (l.37) + `flutter_test` en dev (l.53) ⇒ **package Flutter ⇒ `flutter test`** (R14). Le fichier importe `package:flutter_test/flutter_test.dart` (cohérent avec `z_srs_scheduler_test.dart`), horloge fixée `DateTime.utc(...)`, **AUCUN `DateTime.now()`** (déterminisme total).

---

## Acceptance Criteria

> Chaque AC est à **pouvoir discriminant (R12)** : il nomme le vecteur/test qui ROUGIT si la garde saute. « Contrat » = table de vecteurs GELÉS.

1. **AC1 — La formule canonique est CONFIRMÉE et documentée (D1).** Les 3 fichiers domaine (`z_sm2_scheduler.dart`, `z_srs_scheduler.dart`, `z_srs_config.dart`) sont vérifiés : formule EF, clamp des deux bornes, paliers 1j/6j, lapse, `learnedAt` non-null-après-réussite, `nextReviewDate`, clamp qualité `0..5`, constantes lues depuis `ZSrsConfig` injecté (aucune constante SM-2 en dur ailleurs), horloge injectée. **Par défaut AUCUN changement de comportement** ; tout ajustement suit D5 (justifié + re-verrouillé). *(Discriminant : les vecteurs AC2-AC5 figent chaque facette ; un changement de constante/keying/clamp les rougit.)*

2. **AC2 — Contrat "première révision" gelé.** `z_sm2_contract_test.dart` fige, depuis `initial()`, pour chaque `q ∈ {0,1,2,3,4,5}` à `now = kNow` : `(interval, repetitions, easeFactor, nextReviewDate, learnedAt, lastQuality)` EXACTS. Notamment `q=5 → interval 1, rep 1, EF 2.5, learnedAt kNow` ; `q=3 → interval 1, rep 1, EF < 2.5` (décroissance sur q=3 depuis 2.5) ; `q=2 → lapse : rep 0, interval 1, learnedAt null` ; `q=0 ≡ q=1 ≡ q=2` (tous lapse). *(Discriminant : INJ-1 — altérer `0.1` → `0.11` rougit le vecteur EF de q=3/q=4 ; changer le palier `1→2` rougit `interval`.)*

3. **AC3 — Contrat "révisions successives" gelé (courbe q=5).** Séquence `q=5` répétée depuis `initial()` : `interval` suit **exactement** `1, 6, 15, 38, 95, …` (`round(prev×2.5)`), `repetitions` `1,2,3,4,5`, `EF` reste `2.5` (déjà au plafond), `nextReviewDate = kNow + interval j` à chaque pas (horloge fixe). Vecteur additionnel EF **croissant** : depuis un état à EF abaissé (une passe q=3), une suite q=5 fait remonter EF de `+0.1`/pas puis **plafonner** à 2.5 (valeurs figées, ≥3 pas). *(Discriminant : INJ-2 — retirer le facteur `easeFactor` du produit d'intervalle (ou fixer modifier à une autre valeur) rougit `15/38/95` ; supprimer le clamp haut rougit le plafond EF.)*

4. **AC4 — Contrat "reset sur échec (q<3)" gelé.** Depuis un état avancé (≥2 réussites q=5 : rep=2, interval=6, learnedAt=kNow), `apply(q=2)` (et `q∈{0,1}`) fige : `repetitions=0`, `interval=1`, `learnedAt` **PRÉSERVÉ** (== la 1re réussite, jamais null — AC4 d'E9-2), `EF` recalculé (décroissant, ≥ plancher), `nextReviewDate = kNow + 1j`, `lastQuality` = la qualité clampée. *(Discriminant : INJ-3 — si le lapse remettait `learnedAt` à null, le vecteur rougit ; si `repetitions` n'était pas remis à 0, il rougit.)*

5. **AC5 — Contrat "bornes EF" gelé (plancher 1.3 ET plafond 2.5).** Vecteur plancher : suite de `q=3` (décroissante) converge et **s'ancre à `minEaseFactor=1.3`** (valeur exacte au pas où le plancher est atteint, figée). Vecteur plafond : `defaultEaseFactor=2.5=maxEaseFactor` ⇒ `q=5` ne dépasse jamais 2.5. Vecteur config custom : `ZSrsConfig(minEaseFactor: 1.5)` ⇒ le plancher figé devient 1.5 (prouve que la borne est **lue de la config**, pas codée en dur). *(Discriminant : INJ-1b — remplacer `config.minEaseFactor` par un littéral `1.3` dans le clamp rougit le vecteur config-custom (1.5).)*

6. **AC6 — Qualité clampée `0..5`, aucun throw, gelée (D6).** `apply(info, -100)` ≡ `apply(info, 0)` et `apply(info, 1000)` ≡ `apply(info, 5)` (états EXACTEMENT égaux, `lastQuality` = 0 / 5) ; aucune exception (`returnsNormally`) pour toute qualité hors bornes, y compris `simulate`. *(Discriminant : si le clamp sautait, `apply(info, 99)` throw sur `(5-99)` amplifié ou produit un EF hors bornes → vecteur rouge.)*

7. **AC7 — Voie d'écriture SRS UNIQUE réaffirmée (AD-9, D7).** Le contrat vérifie : (a) `apply` et `initial` sont les seules productions d'état avancé/neuf ; (b) `simulate == apply` (projection pure, source non mutée) ; (c) `withFolder` **préserve à l'identique** tous les champs d'ordonnancement (n'avance PAS l'état) ; (d) `ZRepetitionInfo` n'expose aucun `copyWith`/setter SRS public (l'extension générée est `hide` au barrel). *(Discriminant : INJ-4 — un test qui tenterait d'avancer l'état via une seconde voie (ex. re-exposer `ZRepetitionInfoZcrud.copyWith`) rougirait le garde de surface publique ; `withFolder` modifiant un champ d'ordonnancement rougirait (c).)*

8. **AC8 — Divergences DOCUMENTÉES par écrit (AD-22 + memlog), avant merge.** La note AD-22 de l'architecture est **augmentée (édition CIBLÉE)** avec : (i) la comparaison numérique mesurée lex `Sm2` ↔ `ZSm2Scheduler` (parité au régime de défaut, D2) ; (ii) le **bonus overdue NON porté** (D3) ; (iii) la **divergence de portée du `intervalModifier`** nouvellement mesurée (D4) ; (iv) le **gel de l'échelle qualité 0..5** (D6) ; (v) la **correction de prémisse** : dodlp n'a aucun module SRS, IFFD n'a pas de classe algorithme domaine isolée (lex `Sm2` EST la variante IFFD) — MESURÉ. Une entrée memlog/Deferred référence ES-4.1 comme résolution d'OQ-S3. *(Discriminant : AC8 est prosaïque mais BORNÉ par les mesures ci-dessus ; le code-review vérifie que chaque point (i)-(v) figure et cite un fichier:ligne mesuré.)*

9. **AC9 — `ZRepetitionInfo` (dé)sérialise défensivement, sans scheduler (AD-10) — non-régression.** Vérifier (réutiliser/étendre `z_repetition_info_test.dart` si besoin, SANS le dupliquer) qu'aucun round-trip `fromMap`/`toMap` du contrat n'invoque un scheduler et qu'un état corrompu (`ease_factor` non-numérique, compteurs négatifs) ne fait pas échouer le parent. *(Discriminant : le groupe défensif existant reste vert ; un vecteur de contrat lisant un état persisté corrompu ne throw pas.)*

10. **AC10 — Graphe & surface publique INCHANGÉS (AD-1) ; gates verts.** Aucune arête de dépendance ajoutée ; `zcrud_core` NON touché (CORE OUT=0) ; barrel public inchangé (`z_srs_scheduler.dart`/`z_sm2_scheduler.dart`/`z_srs_config.dart`/`z_repetition_info.dart` exportés comme avant, `ZRepetitionInfoZcrud` toujours `hide`). `gate:reserved-keys` VERT ; si un `.g.dart` de `packages/*/lib/` est régénéré (peu probable — aucun modèle modifié), il est committé. *(Discriminant : `melos run analyze` + `melos run verify` REPO-WIDE verts au gate de commit (orchestrateur) ; `z_public_surface_test.dart`/`z_kernel_surface_guard_test.dart` verts.)*

---

## Tasks / Subtasks

- [x] **T1 — Confirmer la canonicité des 3 fichiers domaine (AC1, D1, D5)**
  - [x] Relire `z_sm2_scheduler.dart` / `z_srs_scheduler.dart` / `z_srs_config.dart` ligne à ligne face à la formule canonique tranchée (D1). Vérifier : formule EF, clamp deux bornes lues de la config, paliers 1/6, lapse, `learnedAt`, `nextReviewDate`, clamp qualité, horloge injectée, aucune constante SM-2 en dur. → **CONFORME l.44-98 / config l.20-58 : ZÉRO déviation.**
  - [x] **Par défaut : AUCUNE modification de comportement.** Aucun vecteur n'a révélé de déviation → code de prod **INTACT** (`git diff packages/zcrud_flashcard/lib/` = VIDE après restauration des injections).
- [x] **T2 — Écrire le contrat gelé `packages/zcrud_flashcard/test/z_sm2_contract_test.dart` (AC2-AC7, AC9)**
  - [x] Horloge fixe `final kNow = DateTime.utc(2026, 1, 1);` — AUCUN `DateTime.now()`. Import `package:flutter_test/flutter_test.dart` + `package:zcrud_flashcard/zcrud_flashcard.dart`.
  - [x] Groupe **"AC2 — première révision"** : table `q ∈ {0..5}` depuis `initial()`, tuples EXACTS figés. EF figés calculés : q=3 → `2.36`, q=2 → `2.18`, q=1 → `1.96`, q=0 → `1.70`, q=4/q=5 → `2.5`. (comparaison EF via `moreOrLessEquals(v, 1e-9)` — absorbe la représ. binaire des littéraux décimaux, epsilon 100 000× < la moindre dérive réelle 0.01).
  - [x] Groupe **"AC3 — révisions successives q=5"** : `1, 6, 15, 38, 95` figés (5 pas) + EF croissant depuis état abaissé (2.36→2.46→plafond 2.5).
  - [x] Groupe **"AC4 — reset q<3"** : depuis état avancé (rep2/interval6/EF2.5/learnedAt=kNow), `learnedAt` PRÉSERVÉ, rep=0, interval=1, EF=2.18 décroissant, nextReviewDate=kNow+1j.
  - [x] Groupe **"AC5 — bornes EF"** : plancher `1.3` figé, plafond `2.5`, + variante `ZSrsConfig(minEaseFactor: 1.5)` prouvant la lecture de config.
  - [x] Groupe **"AC6 — qualité 0..5 défensive"** : équivalences `-100≡0`, `1000≡5`, `returnsNormally` (apply ET simulate).
  - [x] Groupe **"AC7 — voie d'écriture unique"** : `simulate==apply` source non mutée ; `withFolder` préserve l'ordonnancement (aucun avancement).
  - [x] (AC9) Round-trip `toMap`/`fromMap` d'un état avancé = identité (aucun recalcul scheduler) + état persisté corrompu → pas de throw. SANS dupliquer les groupes défensifs de `z_repetition_info_test.dart`.
- [~] **T3 — Documenter les divergences (AC8) — DÉLÉGUÉ À L'ORCHESTRATEUR**
  - [x] **Doc "dans le code" (per directive orchestrateur workstream A)** : la formule canonique GELÉE + les divergences mesurées (bonus overdue NON porté AD-22/D3 ; portée du `intervalModifier` zcrud vs lex D4) sont documentées dans le dartdoc d'en-tête de `z_sm2_contract_test.dart`.
  - [~] **AD-22 architecture.md (l.228-231) + entrée memlog/Deferred** : artefact de PLANIFICATION PARTAGÉ hors `packages/zcrud_flashcard/**` → **délégué à l'orchestrateur** (isolation stricte workstream A : la story n'écrit QUE `zcrud_flashcard`). Points (i)-(v) mesurés et prêts (cf. Completion Notes) pour l'édition ciblée orchestrateur.
- [x] **T4 — Vérif verte CIBLÉE + injections R3 (AC10)**
  - [x] `flutter test` sur `zcrud_flashcard` (R14) → **RC=0** (211 tests : 22 nouveaux du contrat + 189 existants). RC capturé HORS pipe (R15).
  - [x] `dart analyze packages/zcrud_flashcard` → **RC=0** (No issues found).
  - [x] `python3 scripts/dev/graph_proof.py` → **RC=0** (ACYCLIQUE OK, CORE OUT=0 OK).
  - [x] INJ-1..INJ-5 déroulées, chacune ROUGE comme prévu, restaurées par édition ciblée (R13). Prod `lib/` diff = VIDE.
  - [x] **`melos run analyze` + `melos run verify` REPO-WIDE : NON rejoués ici — délégués à l'ORCHESTRATEUR au gate de commit d'epic** (workstream B actif).

---

## Injections R3 prévues (chaque garde prouvée LOAD-BEARING, rejouée par l'ORCHESTRATEUR)

> **Mesure RC (R15) — NON-NÉGOCIABLE :** `OUT=$(cmd); RC=$?` (ou `cmd; RC=$?`), **JAMAIS** `cmd | tail`/`| grep` (renvoie le RC du pipe). Un rouge lu à travers un pipe n'a rien prouvé.
> **Restauration (R13) :** par **édition ciblée** de retour, JAMAIS `git checkout` (masquerait un effet de bord).
> **Runner (R14) :** `zcrud_flashcard` est un **paquet Flutter** (`pubspec.yaml` l.37 `flutter: sdk: flutter`) ⇒ **`flutter test`** (et NON `dart test`, qui ne compile pas les tests important `flutter_test`).

- **INJ-1 — Constante EF (AC2/AC5).** Édition ciblée dans `z_sm2_scheduler.dart` l.53 : `0.1` → `0.11`. `flutter test test/z_sm2_contract_test.dart; RC=$?` → **RC≠0** attendu (vecteurs EF de q=3/q=4 rouges). Restaurer par édition ciblée. *(Prouve que le contrat MORD sur la formule d'ease.)*
- **INJ-1b — Borne lue de config vs littéral (AC5).** Édition ciblée : remplacer `config.minEaseFactor` (l.56) par le littéral `1.3`. `flutter test test/z_sm2_contract_test.dart; RC=$?` → **RC≠0** (le vecteur `ZSrsConfig(minEaseFactor: 1.5)` attend 1.5, obtient 1.3). Restaurer. *(Prouve que le plancher est réellement paramétré, pas codé en dur.)*
- **INJ-2 — Keying/produit d'intervalle (AC3).** Édition ciblée : dans la branche multiplicative (l.71), retirer `* easeFactor`. `flutter test …; RC=$?` → **RC≠0** (`15/38/95` rouges). Restaurer. *(Prouve que le contrat MORD sur la croissance d'intervalle.)*
- **INJ-3 — Préservation de `learnedAt` sur lapse (AC4).** Édition ciblée : l.81 → `final learnedAt = passed ? effectiveNow : null;` (remise à null sur lapse). `flutter test …; RC=$?` → **RC≠0** (vecteur reset : `learnedAt` attendu préservé, obtient null). Restaurer. *(Prouve l'invariant "jamais remis à null".)*
- **INJ-4 — Voie d'écriture unique (AC7, AD-9).** Édition ciblée : dans `withFolder` (`z_repetition_info.dart` l.194-205), muter un champ d'ordonnancement (ex. `interval: interval + 1`). `flutter test test/z_sm2_contract_test.dart; RC=$?` → **RC≠0** (le vecteur "withFolder préserve l'ordonnancement" rouge). Restaurer. *(Prouve qu'aucune seconde voie ne peut faire progresser l'état sans casser le contrat.)*
- **INJ-5 — Charge du contrat lui-même (contre-preuve R12).** Après avoir écrit `z_sm2_contract_test.dart` : commenter le bloc `expect` d'un vecteur central (ex. la courbe q=5). Rejouer INJ-2 → le fichier de contrat **NE rougit PLUS** sur ce point ⇒ prouve que c'est bien CE vecteur qui portait la charge. Restaurer (dé-commenter). *(Anti-artefact décoratif : le contrat n'est pas POWERLESS.)*

---

## Vérif verte à rejouer (commandes exactes, RC capturé HORS pipe — R15)

```bash
# 1. Contrat SM-2 + suites SRS existantes de zcrud_flashcard (RUNNER = flutter, R14)
cd packages/zcrud_flashcard && flutter test; echo "flashcard test RC=$?"; cd ../..

# 2. Analyse ciblée du package
dart analyze packages/zcrud_flashcard; echo "analyze RC=$?"

# 3. (ORCHESTRATEUR, gate de commit d'epic — PAS pendant le dev, workstream B actif)
dart run melos run analyze; echo "melos analyze RC=$?"
dart run melos run verify;  echo "melos verify  RC=$?"
```

> ⚠️ Ne JAMAIS mesurer un RC via `flutter test … | tail`/`| grep` : le pipe renvoie le RC du dernier maillon (R15). Toujours `cmd; RC=$?`.
> ⚠️ **Runner (R14)** : `zcrud_flashcard` = paquet Flutter ⇒ `flutter test`. `dart test` échouerait (import `flutter_test`).

---

## Dev Notes

### Périmètre & invariants NON-NÉGOCIABLES
- **Fichiers touchés (EXCLUSIVEMENT)** : `packages/zcrud_flashcard/lib/src/domain/{z_sm2_scheduler.dart, z_srs_scheduler.dart, z_srs_config.dart}` (vérif ; **modif seulement sous D5**) ; **NOUVEAU** `packages/zcrud_flashcard/test/z_sm2_contract_test.dart` ; `architecture.md` note AD-22 + memlog (édition **ciblée**). **NE touche PAS** `zcrud_core` (CORE OUT=0, AD-1), `zcrud_study` (workstream B), NI `sprint-status.yaml` (orchestrateur).
- **AD-9 voie d'écriture UNIQUE** : `reviewCard() → ZSrsScheduler.apply` (avancement) + `initial()` (état neuf) sont les SEULES productions d'état ; `ZRepetitionInfo` reste sans `copyWith`/setter SRS public (extension générée `hide`). `withFolder` = relocalisation de routage, PAS un avancement.
- **AD-5/AD-10** : `Either`/`Unit` pour les contrats repo (hors périmètre direct ici) ; (dé)sérialisation défensive de `ZRepetitionInfo` inchangée (AC9).
- **Isolation workstream A** : vérifs CIBLÉES par package (pas de `melos` repo-wide au milieu du dev — délégué à l'orchestrateur au repos des workstreams). INJ-* restaurées par édition ciblée (R13), git status propre en fin de dev (hors fichiers livrables).

### Pourquoi cette story ne réécrit RIEN par défaut
`ZSm2Scheduler` est déjà canonique (E9-2, AD-22 « vérifié sur le code »). La **résolution différée** OQ-S3 exigeait deux choses restées ouvertes : (1) le **verrou exécutable** (table de vecteurs figés — ce que `z_srs_scheduler_test.dart` ne fait pas : il teste des propriétés, pas un golden numérique gelé) ; (2) la **note écrite** des divergences avant tout merge des runtimes de session. Un changement de formule serait une **régression** de planification pour les utilisateurs existants (le pire résultat possible de cette story). La valeur ajoutée est le **verrou** + la **doc**, pas un nouvel algorithme.

### Anti-inertie (réutilisation)
- **Réutiliser `ZRepetitionInfo`/`ZSrsConfig`/`ZSm2Scheduler`** tels quels ; ne rien dupliquer.
- **Ne PAS dupliquer `z_srs_scheduler_test.dart`** : le nouveau `z_sm2_contract_test.dart` porte la TABLE GELÉE (golden numérique), distincte des tests de propriété existants. Si un chevauchement est trivial, référencer plutôt qu'copier.
- Aucun modèle `@ZcrudModel` n'est modifié ⇒ **aucun `.g.dart` ne devrait être régénéré**. Si `melos run generate` en régénère un de `packages/*/lib/`, le committer (suivi git).

### Valeurs numériques à FIGER (à calculer précisément dans le test — ne pas approximer)
Depuis `EF=2.5`, `EF' = 2.5 + (0.1 - (5-q)*(0.08 + (5-q)*0.02))` puis clamp `[1.3;2.5]` :
- `q=5` → `2.5 + 0.1 = 2.6` → clamp **2.5** · `q=4` → `2.5 + (0.1 - 1*0.10) = 2.5` → **2.5** · `q=3` → `2.5 + (0.1 - 2*0.12) = 2.5 - 0.14 = 2.36` → **2.36** · `q=2` → `2.5 + (0.1 - 3*0.14) = 2.5 - 0.32 = 2.18` → **2.18** · `q=1` → `2.5 - 0.54 = 1.96` · `q=0` → `2.5 - 0.80 = 1.70`.
- Courbe q=5 (EF plafonné 2.5) : `1, 6, round(6×2.5)=15, round(15×2.5)=38, round(38×2.5)=95, round(95×2.5)=238, …`.
> ⚠️ Le dev DOIT recalculer/confirmer ces valeurs dans le test (elles définissent le golden). Les figer en littéraux ; toute dérive du code les rougit.

### Runner par nature du package (R14) — MESURÉ
`packages/zcrud_flashcard/pubspec.yaml` : `dependencies.flutter: sdk: flutter` (l.37) + `dev_dependencies.flutter_test: sdk: flutter` (l.53) ⇒ **paquet Flutter ⇒ `flutter test`**. Le commentaire du pubspec (l.31-36) le confirme explicitement (« aiguille sur `flutter test` et non `dart test` »). L'algo SM-2 est pur-Dart, mais le **runner du package** est `flutter test`.

### Project Structure Notes
- `z_sm2_contract_test.dart` vit à côté de `z_srs_scheduler_test.dart` (`packages/zcrud_flashcard/test/`). Convention `*_test.dart`.
- La note AD-22 est un artefact de **planification** partagé ; édition **ciblée** de la seule sous-section AD-22 (l.228-231) + entrée memlog — jamais de réécriture globale (contention cross-workstream évitée).

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story-ES-4.1 — ACs, F3 portée documentaire vs contrat exécutable]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-22 — L228-231 : ZSm2Scheduler canonique, overdue non porté, clamp 0..5]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-9 — état SRS séparé, voie d'écriture unique]
- [Source: packages/zcrud_flashcard/lib/src/domain/z_sm2_scheduler.dart#L44-L106 — apply/simulate/initial, formule EF, paliers, lapse]
- [Source: packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart#L20-L58 — constantes injectables]
- [Source: packages/zcrud_flashcard/lib/src/domain/z_repetition_info.dart#L63-L205 — contenant pur, voie unique, withFolder]
- [Source: packages/zcrud_flashcard/test/z_srs_scheduler_test.dart — couverture propriété existante (à NE PAS dupliquer)]
- [Source: ~/DEV/lex_douane/packages/lex_core/lib/domain/usecases/education/sm2.dart#L103-L268 — référence lex : constantes, EF, intervalles, overdue, _applyModifier]
- [Source: ~/DEV/lex_douane/packages/lex_data/lib/data/repositories/repetition_repository_impl.dart#L26-L134 — reviewCard→Sm2.apply voie unique]
- [Source: docs/canonical-schema.md#L62-L75 — ZRepetitionInfo + Sm2/Sm2QualityLevel canonique]
- [Source: CLAUDE.md — AD-1 (CORE OUT=0), AD-9/AD-16 (voie unique), AD-10 (désérialisation défensive), R12/R14/R15 gotchas]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high) — workstream A parallèle, isolation stricte `zcrud_flashcard`.

### Debug Log References

- Vérif verte CIBLÉE (RC HORS pipe, R15) :
  - `dart analyze packages/zcrud_flashcard` → **No issues found — RC=0**
  - `flutter test` (zcrud_flashcard, R14) → **All tests passed (211 tests) — RC=0**
  - `flutter test test/z_sm2_contract_test.dart` → **22 vecteurs, All tests passed — RC=0**
  - `python3 scripts/dev/graph_proof.py` → **total arêtes=37, out-degree(zcrud_core)=0, ACYCLIQUE OK, CORE OUT=0 OK — RC=0**

### Completion Notes List

**ZÉRO changement de comportement de `ZSm2Scheduler` (D1/D5).** Aucun vecteur n'a révélé de déviation de la formule canonique. Le code de production est **INTACT** : `git diff packages/zcrud_flashcard/lib/` = **VIDE** après restauration de toutes les injections. AUCUN `.g.dart` régénéré (aucun modèle `@ZcrudModel` modifié — D1).

**Livrable = (1) verrou de contrat + (2) doc dans le code.** Nouveau fichier `z_sm2_contract_test.dart` : 22 vecteurs GELÉS (golden numérique déterministe), DISTINCT de `z_srs_scheduler_test.dart` (qui teste des propriétés). Valeurs EF figées calculées et confirmées par exécution : depuis EF=2.5 → q=3:`2.36`, q=2:`2.18`, q=1:`1.96`, q=0:`1.70`, q=4/5:`2.5` ; courbe q=5 `1,6,15,38,95` ; plancher `1.3` / plafond `2.5` ; config custom `minEaseFactor:1.5` prouvant la lecture de config. Comparaison EF via `moreOrLessEquals(v, 1e-9)` : robuste à la représentation binaire des littéraux décimaux SANS éroder le pouvoir discriminant (toute dérive réelle décale l'EF d'au moins 0.01 ≫ 1e-9).

**Doc "dans le code" (directive orchestrateur)** : le dartdoc d'en-tête de `z_sm2_contract_test.dart` documente la formule canonique GELÉE + les 2 divergences MESURÉES vs lex `Sm2` (bonus overdue NON porté / D3-AD-22 ; portée `intervalModifier` limitée à la branche multiplicative en zcrud vs tous régimes en lex / D4).

**AC8 (AD-22 architecture.md + memlog) — DÉLÉGUÉ à l'orchestrateur** (artefact de planification PARTAGÉ hors `zcrud_flashcard/`, isolation stricte workstream A). Points prêts pour l'édition ciblée, chacun mesuré sur disque :
  - (i) parité numérique lex `Sm2` (`~/DEV/lex_douane/packages/lex_core/lib/domain/usecases/education/sm2.dart` l.233-243 EF, l.152-160 intervalles) ↔ `ZSm2Scheduler` (l.53-56 EF, l.62-78 intervalles) au régime de défaut (modifier=1.0, pas d'overdue) ;
  - (ii) bonus overdue NON porté (lex sm2.dart l.248-263 vs `ZSrsConfig.overdueBonusFactor` INERTE, z_srs_config.dart l.51-54) ;
  - (iii) divergence de portée `intervalModifier` (lex `_applyModifier` l.165/265-268 tous régimes + par appel vs zcrud z_sm2_scheduler.dart l.71 branche multiplicative seule + champ config) ;
  - (iv) gel de l'échelle qualité `0..5` (z_sm2_scheduler.dart l.49 `quality.clamp(0,5)`) ;
  - (v) correction de prémisse MESURÉE : dodlp n'a AUCUN module SRS (`~/DEV/dodlp-otr/lib` : 0 fichier `*sm2*`/`*repetition*`) ; IFFD n'a pas de classe algorithme domaine isolée (lex `Sm2` EST la variante IFFD, sm2.dart l.65).

**Injections R3 — chaque garde prouvée LOAD-BEARING (messages EXACTS capturés, RC=1 HORS pipe, restaurées par édition ciblée R13) :**
  - **INJ-1** (EF `0.1`→`0.11`, `z_sm2_scheduler.dart` l.54) : ROUGE. `AC2 … q=3 … EF 2.36 [E]  Expected: 2.36 (±1e-9)  Actual: <2.37>` (idem q=2 `2.18`→`2.19`, q=1 `1.96`→`1.97`, q=0 `1.70`→`1.71`). RC=1.
  - **INJ-1b** (`config.minEaseFactor`→littéral `1.3`, l.56) : ROUGE. `AC5 … config custom minEaseFactor=1.5 … [E]  Actual: <1.3800000000000001>` (attendu 1.5). RC=1.
  - **INJ-2** (retrait de `* easeFactor`, l.70-72) : ROUGE. `AC3 … interval suit EXACTEMENT 1, 6, 15, 38, 95 … [E]  Expected: <15>  Actual: <6>  (pas 3 : interval attendu 15)`. RC=1.
  - **INJ-3** (`learnedAt` remis à null sur lapse, l.81) : ROUGE. `AC4 … apply(q=2) … learnedAt PRÉSERVÉ [E]  Expected: DateTime:<2026-01-01 00:00:00.000Z>  Actual: <null>`. RC=1.
  - **INJ-4** (`withFolder` mute `interval: interval + 1`, `z_repetition_info.dart` l.198) : ROUGE. `AC7 … withFolder PRÉSERVE l'ordonnancement … [E]  Expected: <15>  Actual: <16>`. RC=1.
  - **INJ-5** (contre-preuve R12) : les DEUX `expect` interval-dépendants de la courbe AC3 (`interval` + `nextReviewDate`) neutralisés + INJ-2 réactivé → `AC3 … interval suit EXACTEMENT … : +1: All tests passed! RC=0`. Prouve que ce sont bien CES asserts qui portent la charge (contrat NON décoratif) ; la neutralisation du seul `expect(interval)` NE suffisait PAS (le `expect(nextReviewDate)` mordait aussi = défense en profondeur). Restauré (dé-commenté).

**Confirmation finale** : après toutes les restaurations, `git diff packages/zcrud_flashcard/lib/` VIDE ⇒ comportement par défaut de `ZSm2Scheduler`/`ZRepetitionInfo` EXACTEMENT inchangé.

### File List

- **NEW** `packages/zcrud_flashcard/test/z_sm2_contract_test.dart` (contrat gelé 22 vecteurs + doc formule/divergences)
- (aucun autre fichier de code modifié — `lib/` INTACT ; AD-22 architecture.md + memlog délégués à l'orchestrateur)
