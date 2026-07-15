# Code-review adversariale — Story ES-2.7

**Résultat de session (`ZStudySessionResult`) + agrégation quotidienne (`ZDailyStudyTask` / `aggregateDailyStudyTasks`) + port neutre `ZApproachingExam`**

- **Skill invoqué** : `bmad-code-review` (tool `Skill`, VRAI skill — pas de fallback disque).
- **Cible** : diff kernel-only ES-2.7 (fichiers NEUFS + barrel kernel + `hide` flashcard).
- **Baseline** : `6d8694227a8134f0f0ddac4f8dc6a98338da7701`.
- **Date** : 2026-07-15.
- **Méthode** : lecture intégrale des 3 fichiers de prod + 4 tests + barrel + `hide` + surface-guard ; **injections de régression R3 REJOUÉES RÉELLEMENT sur disque** (restauration par édition ciblée, JAMAIS `git checkout`) ; probe empirique du seuil `List.sort`.

---

## VERDICT : ✅ APPROUVÉ (0 HIGH / 0 MAJEUR / 0 MEDIUM ; 2 LOW informationnels)

Story **verte**, **pouvoir discriminant OBSERVÉ** sur chaque garde critique (tri stable, anti-`DateTime.now()`, filtre horloge, surface-guard) — chacune **rougit réellement** quand on la neutralise. Le motif dominant du projet (« vert déclaré valide sur son EXISTENCE, jamais sur son POUVOIR ») est **contré** : aucun golden fortuit détecté, le n=40 du test de tri est **load-bearing et prouvé**. Les décisions D1–D11 sont conformes à l'architecture (VO pur non-`@ZcrudModel`, `abstract interface class` jamais `sealed`, port neutre au kernel, `registrars.dart` INTOUCHÉ). Aucun finding bloquant `done`.

---

## Axes adversariaux — OBSERVÉ (rejeu réel), pas seulement LU

### R3 — Injections de régression rejouées (restaurées par édition ciblée)

| # | Injection | Fichier | Résultat OBSERVÉ | RC |
|---|-----------|---------|------------------|-----|
| **R3a** | Tie-breaker retiré (`return cmp;` — tri par date seule) | `aggregate_daily_study_tasks.dart` | Test « 40 examens de MÊME date » **ROUGE** : `Which: at location [0] is '13' instead of '00'` (quicksort permute) | ROUGE (1 fail) |
| **R3b** | `DateTime.now()` injecté dans le corps | `aggregate_daily_study_tasks.dart` | `no_datetime_now_test` **ROUGE** : `Fichiers fautifs : [.../aggregate_daily_study_tasks.dart]` | ROUGE (1 fail) |
| **R3c** | Filtre neutralisé (`if (true)`) | `aggregate_daily_study_tasks.dart` | **ROUGE** : « EXCLUS », « BALAYAGE D'HORLOGE » (`J+1 attendu null`), « FRONTIÈRE DE JOUR » | ROUGE (4 fails) |
| **R3d** | Symbole retiré du `hide` flashcard | `zcrud_flashcard.dart` | `z_kernel_surface_guard_test` **ROUGE** : `FUITE POTENTIELLE … {aggregateDailyStudyTasks}` (via `flutter test`) | ROUGE (1 fail) |

**Toutes les 4 injections mordent réellement.** Chaque garde a un pouvoir discriminant observé. Restauration vérifiée : kernel **231 tests OK**, guard **5 OK**, gate:reserved-keys **RC=0**.

### 🔴 AXE 1 — TRI STABLE (AC10) : le piège le plus subtil — VÉRIFIÉ MOI-MÊME

Le dev affirme : `List.sort` de Dart stable ≤33, instable ≥40, et le test choisit n=40 EXPRÈS. **J'ai vérifié cette affirmation par probe empirique** (comparateur retournant 0 = clés égales) :

```
n=2  stable=true    n=32 stable=true    n=33 stable=true
n=40 stable=false (first5=[13,1,2,3,4])   n=50 stable=false
```

- **CONFIRMÉ** : la bascule insertion-sort → dual-pivot quicksort est **entre 33 et 40**. À n≤33 un tri nu (sans tie-breaker) préserve l'ordre d'entrée ⇒ un test à petit n **PASSERAIT À TORT** (golden fortuit, powerless). Le dev a **correctement** choisi n=40 : c'est la plus petite taille « ronde » au-dessus du seuil où l'instabilité est OBSERVABLE.
- **PROUVÉ par un rouge provoqué** (R3a) : sans le tie-breaker, le test n=40 rougit réellement (`[0]='13'`). Le n choisi rend donc l'instabilité **véritablement observable** — ce n'est PAS un golden fortuit.
- **Tie-breaker déterministe** : `(date, index d'entrée)` via `_IndexedExam.index` — ordre total strict. Testé **dans les DEUX sens** : `[a,b]→[a,b]` ET `[b,a]→[b,a]` (test « date ÉGALE ⇒ ordre d'ENTRÉE préservé »). Dates différentes → toujours `[proche, loin]` quel que soit l'ordre d'entrée. **Conforme AC10.**

### 🔴 AXE 2 — Agrégation dépend de `now` (pas d'un golden fixe)
Balayage `{J-7, J-1, J0, J+1}` asserte `daysUntil ∈ {7,1,0}` puis `null` (absent) à J+1. Frontière minuit UTC prouvée **des deux côtés** : `07-19 23:59 → daysUntil 1` (à venir) vs `07-20 00:01 → daysUntil 0` (jour J) vs `07-21 00:01 → null` (passé, absent). Aucun off-by-one : `daysUntil` délègue à la normalisation UTC héritée de `ZExam` (ES-2.6). R3c neutralisant le filtre fait rougir ces 3 tests ⇒ dépendance à `now` OBSERVÉE.

### 🔴 AXE 3 — Anti-`DateTime.now()`
Scan tokenisé (commentaires dépouillés), `@TestOn('vm')` + raison écrite, méta-garde couvrant les 3 fichiers, fixture R2 in-test prouvant le pouvoir des regex. R3b confirme le mordant. **Portée honnêtement documentée** : n'attrape PAS un tearoff `DateTime.now` sans parenthèses (limite écrite en tête, leçon LOW-1 ES-2.6) — **aucune surpromesse**. Restauré : **0** `DateTime.now()`/argless en prod.

### 🔴 AXE 4 — AC14 anti-inertie
`gate_reserved_keys.dart` **RC=0 SANS modification de `registrars.dart`**. `git diff` de `registrars.dart` : **aucune** entrée ES-2.7 (`session_result`/`dailyStudy`/`approaching`/`aggregate` absents — les 202 lignes ajoutées relèvent d'ES-2.3/2.4/2.5/2.6, non committées). Aucun `.g.dart` généré pour les 3 fichiers. Aucun `@ZcrudModel` accidentel (lecture intégrale des 3 fichiers). **Conforme.**

### 🔴 AXE 5 — Value-object / port neutre
- `ZStudySessionResult.byQuality` : égalité **commutative** (ensembliste sur clés, hash = Σ `Object.hash(k,v)`), décodage **défensif 2 niveaux** (non-`Map`→`{}`, valeur non-`int` ignorée, jamais throw), `Map.unmodifiable` sur la frontière `fromMap`, `fromMap(const {})` sûr. Tests AC4 : 2 égaux / 2 inégaux + hashCode. **Conforme.**
- `ZDailyStudyTask` = `abstract interface class` (⛔ **VÉRIFIÉ mot-clé réel** : `abstract interface class`, PAS `sealed`). Extension prouvée par `_PodcastTask` (satellite hypothétique) + dispatch `switch … default`.
- `ZApproachingExam` = port pur-Dart **défini DANS le kernel**, **aucun import `zcrud_exam`** (double `_Fake` local de forme identique à `ZExam`). **Conforme D3/D10.**

### 🔴 AXE 6 — AD-1/AD-17 / graphe
Lecture des 3 fichiers : imports = uniquement `z_review_mode.dart` (relatif) et `z_daily_study_task.dart` (relatif). **Aucune** arête vers `zcrud_exam`/`zcrud_flashcard`, **zéro** Flutter/`dart:ui`. `graph_proof` ACYCLIQUE / CORE OUT=0 confirmé par l'orchestrateur ; le code le corrobore structurellement.

### 🔴 AXE 7 — Surface (D11)
Les 6 symboles sont dans la liste `hide` de `zcrud_flashcard.dart`. `z_kernel_surface_guard_test` **VERT** (5 tests). R3d prouve son pouvoir (retirer un symbole → `FUITE POTENTIELLE`). Le guard passe **sans allowlist** (symboles study-niveau masqués) — pas de test powerless exigé (leçon DW-ES25-1 respectée). Le `+7` du diff sur le guard test = ES-2.3 (tags), **PAS ES-2.7** (confirmé par `git diff`).

### 🔴 AXE 8 — AD-10 défensif
`_decodeCount` : `num` clampé `≥0`, sinon `0` (négatif/`String`/`bool`→0). `aggregate([], now)` → `const []`. `daysUntil(now) ?? 0` (jamais de `!`). `_compareDates` : nulls déterministes en dernier, jamais throw. Aucun `assert` en ctor `const`. Test « exam date null toléré » → `returnsNormally`. **Conforme.**

### 🔴 AXE 9 — Périmètre
`git diff --stat` (kernel/flashcard/gate) : `zcrud_flashcard.dart` (+17), `z_kernel_surface_guard_test.dart` (+7, ES-2.3), `zcrud_study_kernel.dart` (+31), `registrars.dart` (+202, ES-2.3/2.4/2.5/2.6). **ES-2.7 n'a touché NI `registrars.dart` NI `zcrud_exam`.** Fichiers NEUFS ES-2.7 = 3 lib + 4 tests. **Blast-radius kernel-only respecté.**

---

## Findings

### LOW-1 (informationnel, ACCEPTÉ) — Constructeur `const` n'impose pas l'immuabilité de `byQuality`
`z_study_session_result.dart:59-64` — le ctor `const` stocke `byQuality` tel quel ; seule `fromMap` applique `Map.unmodifiable`. Un appelant faisant `ZStudySessionResult(byQuality: mapMutable)` puis mutant `mapMutable` casserait l'invariant `hashCode`/`Set`.
**Scénario** : `final m = {'0':1}; final r = ZStudySessionResult(byQuality: m); m['1']=2;` ⇒ `r.hashCode` change après insertion dans un `Set`.
**Verdict : ACCEPTÉ.** (1) Explicitement documenté dans le dartdoc du ctor (« c'est **son** invariant à tenir ») ; (2) conforme au précédent EXACT `ZReminderTime` (aucune logique en ctor `const`, AD-10) ; (3) la seule frontière recevant des données externes/persistées (`fromMap`) EST protégée ; (4) le défaut `const {}` est déjà immuable. Aucun AC violé (AC1 « exposé NON MODIFIABLE » satisfait sur les frontières `fromMap`+défaut, cf. D7 « aux frontières qui le construisent »). Pas de correction requise.

### LOW-2 (informationnel) — Tri sur `DateTime` complet, pas sur le jour UTC normalisé
`aggregate_daily_study_tasks.dart:73-78` — le tri utilise `exam.date` brut ; deux examens du même jour calendaire mais à heures différentes trient par timestamp (avant que le tie-breaker d'index n'intervienne). `daysUntil` normalise pourtant au jour UTC. En pratique `ZExam.date` est jour-granulaire, l'ordre reste **déterministe** dans tous les cas.
**Verdict : ACCEPTÉ.** Aucune non-détermination introduite (l'ordre reste total et stable) ; le tie-breaker ne s'active que sur `DateTime` STRICTEMENT égal. Cohérent avec la parité lex (`sort((a,b)=>a.date.compareTo(b.date))`). Pas de correction requise.

---

## Vérif verte rejouée (réelle, sur disque)

| Vérif | Résultat |
|-------|----------|
| `dart test` kernel (VM, complet) | **231 OK** |
| `dart test -p node` (agg + session + task) | **32 OK** (web/gate:web) |
| `flutter test z_kernel_surface_guard_test` | **5 OK** |
| `dart run scripts/ci/gate_reserved_keys.dart` | **RC=0** (registrars INCHANGÉ) |
| `git diff registrars.dart` — additions ES-2.7 | **AUCUNE** |

*(Note environnement : la surface-guard doit être lancée via `flutter test` — `dart test` crashe le compilateur FFI sur un package Flutter ; sans rapport avec le diff ES-2.7.)*

## Conclusion
**APPROUVÉ pour `done`.** Aucun finding HIGH/MAJEUR/MEDIUM. 2 LOW informationnels documentés et acceptés (aucune correction requise). Toutes les gardes critiques ont un pouvoir discriminant PROUVÉ par rouge provoqué. Le tri stable est le point le plus subtil et il est **correct + testé au bon n (40)**. Anti-`DateTime.now()` et AC14 confirmés.
