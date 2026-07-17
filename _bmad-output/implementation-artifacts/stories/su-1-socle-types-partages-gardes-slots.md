# Story SU-1 : Socle — types partagés, gardes et slots

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **mainteneur de zcrud**,
I want **que les retouches des types PARTAGÉS existants (échelle de qualité, garde de mode, clé de section, slot de rendu) soient faites une seule fois, en amont**,
so that **les stories livrables (su-2..su-12) ne se marchent pas dessus et héritent d'invariants déjà garantis par construction.**

**Couvre :** AD-34, AD-38, AD-40, AD-46 (socle transverse — aucun FR direct).
**Source de spécification :** `epics.md` § Epic 1 → **Story 1.1** (ACs repris, jamais réinventés).

## Contexte & décisions verrouillées (à NE PAS ré-arbitrer)

**TÊTE BLOQUANTE du sprint SU** (`sprint-status` l.453) : `[M][SÉQ — bloque TOUT]`. Cette story est
la **seule** autorisée à retoucher ces types partagés — les workstreams (A) flashcard/session,
(B) export, (C) mindmap ne démarrent qu'après son `done`. **Aucune parallélisation.**

**Périmètre RÉEL, vérifié sur disque (ne rien inventer, ne rien recréer) :**

| Symbole | Existe ? | Emplacement RÉEL vérifié |
|---|---|---|
| `ZSrsConfig` | ✅ existe | `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart:17` |
| `ZQualityScale` | ✅ existe | `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart:29` |
| `ZStudySessionEngine` | ✅ existe | `packages/zcrud_session/lib/src/domain/z_study_session_engine.dart:115` |
| `ZLinearSessionState` | ✅ existe (garde `assert` **modèle à copier**) | `packages/zcrud_session/lib/src/domain/z_linear_session_state.dart:143-153` |
| `ZWhiteExamSessionEngine` | ✅ existe | `packages/zcrud_session/lib/src/domain/z_white_exam_session_engine.dart:240` |
| `ZFolderContentsOrder` | ✅ existe | `packages/zcrud_study_kernel/lib/src/domain/z_folder_contents_order.dart:129` |
| `applyOrder<T>` | ✅ existe | `packages/zcrud_study_kernel/lib/src/domain/apply_order.dart:41` |
| `ZReviewMode` (6 valeurs) | ✅ existe | `packages/zcrud_study_kernel/lib/src/domain/z_review_mode.dart:26` |
| `ZMindmapNodeContentBuilder` + défaut texte brut | ✅ existe (**patron AD-40 à copier**) | `packages/zcrud_mindmap/lib/src/presentation/z_mindmap_view_config.dart:25` |

**AUCUN moteur n'est créé** (AD-34) · **AUCUNE seconde entité d'ordre** (AD-38) · **AUCUNE écriture
dans `zcrud_core`** (interdit à toute story SU — seul E-MULTI-EDIT y écrit).

### Absences PROUVÉES par grep négatif (RC=1 = 0 occurrence)

Le dev agent **ne doit pas chercher** ces symboles : ils n'existent pas, ils sont à créer.

```bash
# PREUVE 1 — aucun constructeur canonique de sectionKey n'existe → RC=1
grep -rn "sectionKeyFor\|zSectionKey\|buildSectionKey\|canonicalSectionKey" packages/ --include="*.dart"
# PREUVE 2 — ZStudySessionEngine ne contient AUCUN assert (trou AD-34 confirmé) → RC=1
grep -n "assert" packages/zcrud_session/lib/src/domain/z_study_session_engine.dart
# PREUVE 3 — ZSrsConfig ne porte AUCUNE borne d'échelle → RC=1
grep -n "minQuality\|maxQuality\|qualityScale\|scale" packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart
# PREUVE 4 — aucun enum de type de contenu n'existe (→ contentType reste String opaque, AC3) → RC=1
grep -rln "enum ZStudyContentType\|enum ZContentType\|enum ZStudyToolKind" packages/ --include="*.dart"
# PREUVE 5 — aucun test de ZSrsConfig n'existe (le fichier de test AC1 est NEUF) → RC=2
ls packages/zcrud_flashcard/test/z_srs_config_test.dart
# PREUVE 6 — aucune classe ZFlashcardContent n'existe (ne pas la chercher — cf. AC4) → RC=1
grep -rn "class ZFlashcardContent" packages/ --include="*.dart"
```

### Arêtes de graphe : AUCUNE nouvelle (vérifié)

`zcrud_session` **dépend déjà** de `zcrud_flashcard` (`pubspec.yaml` : `zcrud_flashcard: ^0.2.1`) et
**importe déjà `ZSrsConfig`** dans 4 fichiers (`z_study_session_engine.dart:29`,
`z_white_exam_session_engine.dart:53`, `z_linear_session_state.dart:43`, `z_session_reviewer.dart:18`).
→ **La dérivation AD-46 ne coûte AUCUNE arête** ; `graph_proof` et **CORE OUT=0** restent inchangés.
Si le dev agent croit devoir ajouter une dépendance, **il se trompe** — l'arête existe.

### ⚠️ Contrainte structurelle AD-40 (arbitrage tranché — NE PAS rouvrir)

Il **n'existe aucun foyer commun** pour un typedef de slot partagé entre `zcrud_flashcard` et
`zcrud_mindmap` : `zcrud_mindmap` dépend de `zcrud_core` + `zcrud_markdown` + `graphite`
**mais PAS de `zcrud_study_kernel`** (pubspec vérifié) ; le seul ancêtre commun est `zcrud_core`,
**interdit d'écriture** à toute story SU. **Conséquence tranchée** : le slot AD-40 est défini
**par package consommateur** (patron `ZMindmapNodeContentBuilder` déjà en place côté mindmap). SU-1
livre **le pendant côté `zcrud_flashcard`** ; `zcrud_mindmap` est **déjà conforme** et n'est PAS
retouché ici (son slot d'édition relève de su-12). **Ne PAS créer de package de socle, ne PAS
écrire dans `zcrud_core`, ne PAS ajouter `zcrud_study_kernel` aux deps de `zcrud_mindmap`.**

### ⚠️ Risque de RÉGRESSION DE DONNÉES PERSISTÉES (AC3) — lire avant de coder

`sectionOrders` est un **canal persisté** (`ZFolderContentsOrder`, clé réservée `section_orders`).
Des clés sont **déjà en base** chez les consommateurs, de forme **nue** (`'flashcards'`, `'docs'` —
cf. `z_folder_contents_order_test.dart:104`, `z_study_tools_reorder_test.dart:85`). Le constructeur
canonique **DOIT** produire **exactement** `'flashcards'` pour `(contentType: 'flashcards',
subfolderId: null)` — tout préfixe/suffixe ajouté (`'flashcards/'`, `'section:flashcards'`)
**orphelinerait silencieusement** tout ordre existant : `applyOrder` étant **total**, une clé
fautive est **ignorée sans erreur ni test rouge** (c'est exactement le `Prevents` d'AD-38). AC3
verrouille cette rétro-compatibilité par un test porteur.

## Acceptance Criteria

Chaque AC est **à pouvoir discriminant** : ancré sur une ligne de prod réelle et accompagné d'une
**injection** qui doit la faire ROUGIR. Un test qui reste vert quand on casse la logique est un
test tautologique et **invalide l'AC** (discipline R3).

---

**AC1 — `ZSrsConfig` devient l'unique propriétaire des bornes d'échelle 0..5 (AD-46)**

**Given** `ZSrsConfig` ne porte aujourd'hui que `passThreshold` (borne d'échelle absente — PREUVE 3)
**When** la story est livrée
**Then**
- `ZSrsConfig` porte **`minQuality = 0`** et **`maxQuality = 5`** aux côtés de `passThreshold`
  (échelle canonique **0..5**, SM-2 complet — AD-46, défaut actuel et usage lex) ;
- un **`assert` de cohérence** interdit une config incohérente :
  `minQuality < maxQuality` **et** `minQuality < passThreshold <= maxQuality` ;
- `ZSrsConfig` expose **`int clampQuality(int quality)`** — **unique propriétaire du clamp**
  (AD-10/AD-46 : « toute valeur reçue hors bornes est clampée ») ; consommé par su-3
  (`suggestedQuality` du port d'évaluation) ;
- `==`/`hashCode` intègrent les deux nouveaux champs (sinon deux configs d'échelles différentes
  seraient égales — bug d'invalidation) ;
- la classe reste **`const`, pur-Dart, sans codegen** (AD-14 — ce n'est pas une entité persistée).

**Discriminant** : `clampQuality(-3) == 0`, `clampQuality(9) == 5`, `clampQuality(3) == 3` ; sur
`ZSrsConfig(minQuality: 1, maxQuality: 4, passThreshold: 2)` → `clampQuality(0) == 1` et
`clampQuality(5) == 4` (**prouve que le clamp lit la config et non `0..5` en dur**).
**Injection R3-I1** : remplacer le corps par `quality.clamp(0, 5)` ⇒ le cas `(1..4)` ROUGIT.

---

**AC2 — `ZQualityScale` DÉRIVE de `ZSrsConfig` au lieu de redéclarer l'échelle (AD-46)**

**Given** `ZQualityScale` redéclare aujourd'hui l'échelle en dur — `const ZQualityScale({this.min = 0,
this.max = 5})` avec `assert(min == 0 || min == 1)` et `assert(max == 5)`
(`z_srs_quality_buttons.dart:29-33`) : **seconde source de vérité**, inatteignable depuis le domaine
**When** la story est livrée
**Then**
- `ZQualityScale` expose **`ZQualityScale.fromConfig(ZSrsConfig config)`** comme **unique voie de
  construction publique**, lisant `config.minQuality`/`config.maxQuality` ;
- les **littéraux d'échelle disparaissent** de `ZQualityScale` : plus de défauts `= 0`/`= 5`, plus
  d'`assert(max == 5)` (c'était la redéclaration) — les bornes ne sont plus **jamais** écrites
  ailleurs que dans `ZSrsConfig` ;
- `qualities` et `contains` conservent leur sémantique exacte (liste croissante `[min..max]`) ;
- **aucune arête ajoutée** (`zcrud_session → zcrud_flashcard` préexiste — cf. supra) ;
- les **call-sites existants sont migrés** (aucune régression) :
  `z_session_quality_breakdown.dart:46` (champ `final ZQualityScale scale`) et les tests
  `z_srs_quality_buttons_test.dart` (7 sites), `z_session_quality_breakdown_test.dart` (4 sites).

**Discriminant** : `ZQualityScale.fromConfig(const ZSrsConfig()).qualities == [0,1,2,3,4,5]` **ET**
`ZQualityScale.fromConfig(const ZSrsConfig(minQuality: 1, maxQuality: 4, passThreshold: 2)).qualities
== [1,2,3,4]` — le second cas **est** la preuve de dérivation (impossible à satisfaire avec `0..5`
en dur). **Injection R3-I2** : re-coder `min = 0, max = 5` en dur ⇒ le second cas ROUGIT.

**Test « seconde source d'échelle »** (exigé mot pour mot par l'epic : « *un test échoue si une
seconde source d'échelle réapparaît* ») : **garde de source** sur `z_srs_quality_buttons.dart`,
calquée sur `z_linear_no_srs_test.dart` (scan **hors dartdoc/commentaires** — la prose doit pouvoir
nommer les concepts), qui ROUGIT si un littéral de borne (`= 5`, `= 0`, `max == 5`, `min == 0`)
réapparaît dans le **code** de la déclaration d'échelle.

---

**AC3 — Constructeur canonique UNIQUE de `sectionKey` (AD-38)**

**Given** `sectionKey` n'a **aucun** constructeur canonique (PREUVE 1) et `applyOrder` est **total**
⇒ une clé composée à la main diverge **silencieusement** (aucune erreur, aucun test rouge)
**When** une section est composée, **en lecture comme en écriture**
**Then**
- le kernel expose l'**unique** point de composition :
  **`String zSectionKey({required String contentType, String? subfolderId})`**
  dans `packages/zcrud_study_kernel/lib/src/domain/z_section_key.dart`, exporté par le barrel
  `zcrud_study_kernel.dart` ;
- **`contentType` est un `String` opaque** — **PAS un enum** : aucun enum de type de contenu
  n'existe (PREUVE 4) et les consommateurs (IFFD/lex) apportent leurs propres types
  (`'flashcards'`, `'docs'`, …) ; un enum fermé casserait l'ouverture AD-4 et les apps ;
- **forme canonique, RÉTRO-COMPATIBLE avec le persisté** (cf. § Risque) :
  `subfolderId == null || subfolderId.isEmpty` ⇒ **`contentType` VERBATIM** (`'flashcards'`) ;
  sinon ⇒ **`'$contentType/$subfolderId'`** ;
- fonction **pure, déterministe, sans horloge, sans I/O** (le kernel est pur — `z_kernel_purity_test`
  et `no_datetime_now_test` s'appliquent).

**Discriminant** : `zSectionKey(contentType: 'flashcards') == 'flashcards'` (**rétro-compat du
persisté** — verrou anti-orphelins) ; `zSectionKey(contentType: 'flashcards', subfolderId: 'sub1')
== 'flashcards/sub1'` ; `zSectionKey(contentType: 'flashcards', subfolderId: '')` ⇒ `'flashcards'`
(dégénérescence explicite, jamais `'flashcards/'`) ; **stabilité** : deux appels identiques
produisent la même clé. **Injection R3-I3** : préfixer la clé (`'section:$contentType'`) ⇒ le cas
rétro-compat ROUGIT — c'est précisément le bug d'orphelinage silencieux que l'AC prévient.

**Test « clé composée à la main ailleurs »** (exigé par l'epic) : **garde de source** scannant le
**code de production** de `zcrud_study_kernel` + `zcrud_study` et rougissant sur toute
**interpolation/concaténation** de clé de section hors `z_section_key.dart` (motifs
`'$contentType/'`, `sectionOrders['` littéral composé, `+ '/' +`). **Portée honnête et bornée** :
la garde couvre le **code zcrud**, jamais les tests (qui manipulent légitimement des clés opaques
littérales — 15 sites recensés) ni les apps consommatrices (`sectionKey` y est un paramètre reçu).

---

**AC4 — Slot de rendu ouvert côté `zcrud_flashcard`, défaut texte brut (AD-40)**

**Given** les widgets de carte (su-2) et de nœud (su-12) doivent accepter un rendu **injectable**
**When** aucun rendu n'est injecté
**Then**
- `zcrud_flashcard` expose le typedef de slot **`ZFlashcardContentBuilder = Widget Function(
  BuildContext context, String content)`** — **calqué sur `ZMindmapNodeContentBuilder`**
  (`z_mindmap_view_config.dart:25`), au **juste besoin** : le slot reçoit le **texte de contenu**
  (question/réponse) et rend un `Widget`. ⚠️ **`ZFlashcardContent` N'EXISTE PAS** (PREUVE 6) —
  **ne pas le chercher, ne pas l'inventer** ; seul `ZFlashcard` existe (`z_flashcard.dart:66`). Si
  su-2 démontre le besoin de la carte entière, l'enrichissement lui appartient (extension additive) ;
- le **défaut est un texte brut THÉMATISÉ** (`ZcrudTheme.of(context)`, repli `Theme.of`) — **jamais**
  de couleur ni de libellé en dur (NFR-SU4/NFR-SU5), exposé en **tear-off statique stable** (pas de
  closure réallouée à chaque build — patron `_defaultContent` de `z_mindmap_view.dart:137`) ;
- le défaut **ne dépend d'aucun rendu riche** : le chemin par défaut n'atteint **jamais**
  `zcrud_markdown` (le rendu riche est une **injection**, AD-4/AD-40) ;
- **aucun type `Quill`/`flutter_math_fork` dans une signature publique** (AD-7/AD-40) ;
- **l'adaptateur markdown/LaTeX prêt à injecter n'est PAS livré ici** — il relève de **su-2**
  (dans `zcrud_flashcard`, jamais dans `zcrud_markdown` = cycle AD-1). SU-1 livre **le contrat + le
  défaut**, rien de plus (bornage de périmètre).

**Discriminant** : test widget — sans injection, un contenu riche s'affiche en **texte brut** et le
`Widget` rendu **ne contient aucun** widget Quill ; avec un builder injecté, c'est **lui** qui rend
(preuve que le slot est réellement branché, pas décoratif). **Garde de source** : aucune signature
publique de `zcrud_flashcard` ne mentionne `Quill`/`flutter_math_fork` (calquée sur les gardes
d'isolation existantes `flutter_quill_isolation_graph_test.dart` / `math_lib_isolation_graph_test.dart`).
**Injection R3-I4** : rendre le riche en dur dans le défaut ⇒ la garde ROUGIT.

---

**AC5 — `ZStudySessionEngine` reçoit la garde de mode SYMÉTRIQUE (AD-34)**

**Given** `ZStudySessionEngine` accepte aujourd'hui **n'importe quel** `ZReviewMode` avec un vrai
reviewer (`mode = ZReviewMode.spaced` en paramètre, **aucun `assert`** — PREUVE 2) : donc
`(mode: cramming, reviewer: réel)` est **constructible et écrirait le SRS** — c'est **le seul trou
résiduel** identifié par le spine
**When** on tente de construire avec `mode ∈ {cramming, list, test, whiteExam}`
**Then**
- la construction est **refusée** par un **`assert`** — **strictement symétrique** à celui de
  `ZLinearSessionState` (`z_linear_session_state.dart:147-153`), **même patron, même style de
  message explicite** : n'accepter que **`spaced`** et **`learn`** ;
- **AUCUN `ZSessionReviewer` no-op** n'est fourni (ce serait la **porte dérobée** que le spine
  interdit explicitement — AD-34) ;
- le régime d'écriture reste une propriété **du type**, jamais du `mode` passé en paramètre ;
- **aucun moteur créé**, aucune signature publique cassée pour les modes légitimes
  (`spaced`/`learn` inchangés — non-régression des tests existants `z_session_engine_test.dart`).

**Discriminant** : **un cas par mode non-SRS refusé** (4 cas : `cramming`, `list`, `test`,
`whiteExam`) → `expect(() => ZStudySessionEngine(queue: …, reviewer: réel, mode: m),
throwsA(isA<AssertionError>()))` ; **plus** deux cas verts `spaced`/`learn` (la garde ne doit pas
sur-bloquer). **Injection R3-I5** : retirer l'`assert` ⇒ les 4 cas ROUGISSENT.
**Note de portée assumée** (cohérente avec le précédent ratifié `ZLinearSessionState`) : un `assert`
n'agit qu'en **debug/test** — c'est le patron **déjà en place** dans le repo et la **symétrie**
exigée par AD-34 ; ne pas dévier vers un `throw` (ce serait asymétrique et casserait le patron).

---

**AC6 — Gates repo-wide verts**

**Given** les gates du monorepo
**When** la story est déclarée verte
**Then** `melos run generate` OK · `melos run analyze` **RC=0 repo-wide** · `melos run test` **RC=0**
· `melos run verify` **RC=0** (graphe **acyclique**, **CORE OUT=0**, secrets, `codegen-distribution`).
**Non négociable** : `analyze` **repo-wide**, jamais par-package seul — une retouche de type
**partagé** casse par nature les packages **consommateurs** (précédent `ZExportApi` en E11a-3 :
symbole public supprimé, `melos analyze` RED plusieurs commits sans être vu).

## Tasks / Subtasks

- [x] **T1 — `ZSrsConfig` : bornes + clamp (AC1)** · `zcrud_flashcard`
  - [x] Ajouter `minQuality = 0` / `maxQuality = 5` au constructeur `const` + champs `final` documentés.
  - [x] Ajouter l'`assert` de cohérence (`minQuality < maxQuality`, `minQuality < passThreshold <= maxQuality`).
  - [x] Ajouter `int clampQuality(int quality)` (unique propriétaire du clamp, AD-46/AD-10).
  - [x] Étendre `==`/`hashCode` aux deux nouveaux champs.
  - [x] Vérifier que le barrel exporte déjà `z_srs_config.dart` (`zcrud_flashcard.dart:134` — **oui**, rien à faire).
- [x] **T2 — `ZQualityScale` dérivée (AC2)** · `zcrud_session`
  - [x] Remplacer la construction littérale par `ZQualityScale.fromConfig(ZSrsConfig config)` ; supprimer défauts `0`/`5` et `assert(max == 5)`.
  - [x] Migrer les call-sites : `z_session_quality_breakdown.dart:46` + tests (`z_srs_quality_buttons_test.dart`, `z_session_quality_breakdown_test.dart`).
  - [x] Vérifier qu'`aucune` arête n'est ajoutée au pubspec (elle préexiste).
- [x] **T3 — Constructeur canonique `zSectionKey` (AC3)** · `zcrud_study_kernel`
  - [x] Créer `lib/src/domain/z_section_key.dart` (fonction pure) + dartdoc citant AD-38 et le **risque d'orphelinage**.
  - [x] Exporter depuis `lib/zcrud_study_kernel.dart` (ordre alphabétique des `export` — convention du barrel).
- [x] **T4 — Slot de rendu `zcrud_flashcard` (AC4)** · `zcrud_flashcard`
  - [x] Définir le typedef + le défaut texte brut thématisé (tear-off statique).
  - [x] Vérifier que le chemin par défaut n'importe **aucun** rendu riche.
- [x] **T5 — Garde de mode symétrique (AC5)** · `zcrud_session`
  - [x] Ajouter l'`assert` de mode au constructeur de `ZStudySessionEngine`, calqué sur `ZLinearSessionState`.
  - [x] Mettre à jour le dartdoc du constructeur (le trou AD-34 est fermé).
- [x] **T6 — Tests porteurs (AC1..AC5)** — cf. § Stratégie de test.
- [x] **T7 — Vérif verte repo-wide (AC6)** : `melos run generate` → `melos run analyze` → `melos run test` → `melos run verify`.

## Stratégie de test

**Runner (R14)** : `zcrud_flashcard`, `zcrud_session`, `zcrud_study_kernel` sont des packages
**Flutter** (pubspecs vérifiés) ⇒ **`flutter test`**, jamais `dart test`.
**Gardes de source** : `@TestOn('vm')` + `dart:io` (patron `z_linear_no_srs_test.dart`), scan
**hors dartdoc/commentaires**, avec **contre-preuve R12** (`expect(lines, isNotEmpty)` — un scan qui
ne lit rien passerait sinon à vide).

| Fichier de test | Ce qu'il PROUVE (rougit si…) |
|---|---|
| `packages/zcrud_flashcard/test/z_srs_config_test.dart` **(NEUF — PREUVE 5 : n'existe pas)** | AC1 — clamp sur config **non-défaut** (1..4) ⇒ rougit si `clamp(0,5)` en dur ; `assert` de cohérence ; `==` discriminant sur les nouvelles bornes |
| `packages/zcrud_session/test/presentation/z_srs_quality_buttons_test.dart` *(étendre — existe)* | AC2 — `fromConfig(ZSrsConfig(minQuality:1,maxQuality:4))` ⇒ `[1,2,3,4]` : rougit si l'échelle est re-codée en dur |
| `packages/zcrud_session/test/z_quality_scale_single_source_test.dart` **(NEUF, garde de source)** | AC2 — rougit si un littéral de borne réapparaît dans le code de `z_srs_quality_buttons.dart` (« seconde source d'échelle ») |
| `packages/zcrud_study_kernel/test/z_section_key_test.dart` **(NEUF)** | AC3 — **rétro-compat du persisté** (`'flashcards'` verbatim), forme `'type/sous-dossier'`, `subfolderId: ''` dégénéré, déterminisme |
| `packages/zcrud_study_kernel/test/z_section_key_single_composition_test.dart` **(NEUF, garde de source)** | AC3 — rougit si une clé est composée à la main dans le **code de prod** hors `z_section_key.dart` |
| `packages/zcrud_flashcard/test/z_flashcard_content_slot_test.dart` **(NEUF, widget)** | AC4 — défaut = texte brut (aucun widget riche) ; builder injecté ⇒ c'est **lui** qui rend (slot réellement branché) |
| `packages/zcrud_flashcard/test/z_flashcard_rich_type_leak_test.dart` **(NEUF, garde de source)** | AC4 — rougit si `Quill`/`flutter_math_fork` apparaît dans une signature publique |
| `packages/zcrud_session/test/z_session_engine_test.dart` *(étendre — existe)* | AC5 — **4 cas** `cramming`/`list`/`test`/`whiteExam` ⇒ `AssertionError` ; **2 cas verts** `spaced`/`learn` (la garde ne sur-bloque pas) |

**Non-régression obligatoire** : `z_linear_no_srs_test.dart`, `z_white_exam_no_srs_test.dart`,
`z_purity_test.dart`, `z_kernel_purity_test.dart`, `no_datetime_now_test.dart`,
`z_folder_contents_order_test.dart`, `apply_order_test.dart`, `serialization_corpus_test.dart`
**restent verts** (aucun n'est à assouplir — si l'un rougit, c'est la retouche qui est fautive).

**Compatibilité de l'`assert` d'AC1 avec les `ZSrsConfig` déjà construits — VÉRIFIÉE sur disque.**
Toutes les constructions existantes ont été recensées (`grep -rn "ZSrsConfig(" packages/ --include="*_test.dart"`)
et n'emploient que `passThreshold: 4` (`z_session_engine_test.dart:191`, `z_linear_session_test.dart:129`,
`z_white_exam_session_test.dart:162`, `z_srs_scheduler_test.dart:178`), le défaut `3`, ou des
surcharges de **facteurs de facilité** sans rapport avec l'échelle (`z_sm2_contract_test.dart:241`,
`z_srs_scheduler_test.dart:32,152,167`). **Toutes satisfont `0 < {3,4} <= 5`** ⇒ l'`assert`
`minQuality < passThreshold <= maxQuality` **ne casse aucun test existant**. Si l'un rougit malgré
tout, c'est que l'invariant a été écrit **trop strict** : corriger l'`assert`, **jamais** le test.

## Dev Notes

### Contraintes AD applicables (invariants — chaque story SU y est soumise)

- **AD-46** — échelle **possédée par le domaine** (`ZSrsConfig`) ; `ZQualityScale` **dérive** ;
  seau « mauvais » = **q0-2** (conséquence consommée par su-6, hors périmètre ici) ; hors bornes ⇒ **clampé**.
- **AD-34** — un runtime par régime d'écriture ; les 3 runtimes **existent** ; garde **symétrique** ;
  **aucun reviewer no-op**.
- **AD-38** — entité d'ordre **ratifiée** (`ZFolderContentsOrder` + `applyOrder<T>`) ; `sectionKey` à
  **constructeur unique** ; **aucune nouvelle entité**, **aucun nouveau `kind` persisté**.
- **AD-40** — slot injectable, **défaut texte brut** ; adaptateur **chez le consommateur** ; **jamais**
  d'arête retour vers `zcrud_markdown` (cycle, AD-1).
- **Hérités** : AD-1 (acyclique, CORE OUT=0) · AD-2/AD-15 (pur-Flutter, **aucun** gestionnaire d'état) ·
  AD-4 (extension par registre/composition) · AD-10 (défensif, **jamais** d'exception, replis) ·
  AD-13 (RTL, `Semantics`, ≥ 48 dp, thème/l10n injectés) · AD-14 (VO `const` pur-Dart).

### Key Don'ts (spécifiques à cette story)

- 🚫 **Jamais** écrire dans `zcrud_core` (aucune story SU n'y touche).
- 🚫 **Jamais** créer un 4ᵉ moteur, ni un `ZSessionReviewer` no-op (porte dérobée AD-34).
- 🚫 **Jamais** une 2ᵉ entité d'ordre, ni un `kind` persisté, ni un `position` inline.
- 🚫 **Jamais** un enum fermé pour `contentType` (casserait IFFD/lex — PREUVE 4).
- 🚫 **Jamais** préfixer/suffixer une `sectionKey` nue (orphelinage **silencieux** du persisté).
- 🚫 **Jamais** de couleur/libellé en dur ; **jamais** `EdgeInsets.only(left:/right:)` &c. (variantes
  **directionnelles** obligatoires, AD-13).
- 🚫 **Jamais** livrer l'adaptateur markdown ici (c'est su-2) ni assouplir un test existant pour
  faire passer une retouche.

### Project Structure Notes

Fichiers **UPDATE** (lus intégralement lors de la préparation de cette story) :
`z_srs_config.dart` (VO `const`, 6 champs, `==`/`hashCode` exhaustifs — étendre sans casser le patron) ·
`z_srs_quality_buttons.dart` (`ZQualityScale` **+** widget de boutons cohabitent dans le fichier :
ne toucher **que** le VO ; le widget lit déjà `passThreshold` **injecté**, jamais `3` en dur — préserver) ·
`z_study_session_engine.dart` (reducer pur `reduceGrade` + moteur ; **ne pas** toucher au reducer,
seul le **constructeur** gagne l'`assert`) · `z_linear_session_state.dart` (**lecture seule** —
c'est le **modèle** de la garde) · barrels `zcrud_study_kernel.dart` / `zcrud_flashcard.dart` /
`zcrud_session.dart` (exports).
Fichiers **NEW** : `z_section_key.dart` + les 5 tests neufs du tableau ci-dessus.
**Convention** : API publique par barrel `lib/<pkg>.dart`, impl sous `lib/src/{domain,data,presentation}`,
types publics préfixés **`Z`**, fichiers `snake_case`, tests `*_test.dart`.

### Ambiguïtés relevées & arbitrages (tranchés faute d'interlocuteur — mode non interactif)

1. **Foyer du slot AD-40** : aucun ancêtre commun hors `zcrud_core` (interdit) ⇒ **slot par package
   consommateur** ; `zcrud_mindmap` déjà conforme, non retouché. *(Le plus conservateur : zéro arête,
   zéro écriture dans le cœur.)*
2. **Signature exacte du slot flashcard** : dépend du modèle de contenu de carte, dont la forme
   définitive est arrêtée par **su-2** ⇒ SU-1 fige **le patron** (typedef + défaut texte brut
   thématisé + tear-off stable), su-2 le consomme. Éviter la sur-généricité (« au juste besoin »).
3. **`contentType` `String` vs enum** : `String` **opaque** (PREUVE 4 + ouverture AD-4).
4. **`assert` vs `throw`** (AC5) : **`assert`**, par **symétrie** avec le précédent ratifié
   `ZLinearSessionState` — l'epic dit « garde **symétrique** ».
5. **API `ZQualityScale`** : `fromConfig` devient l'unique voie publique ⇒ **changement d'API
   pré-1.0** (`0.2.x`), assumé et borné aux call-sites internes recensés (aucun consommateur
   externe : la distribution se fait en dépendance git, migration accompagnée par su-2..su-6).

### References

- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-ui-2026-07-16/epics.md#Story 1.1: Socle — types partagés, gardes et slots] — **spécification source des ACs**
- [Source: `.../architecture/architecture-zcrud-study-ui-2026-07-16/ARCHITECTURE-SPINE.md#AD-34] · [#AD-38] · [#AD-40] · [#AD-46] · [#Invariants hérités] · [#Placement des paquets]
- [Source: `.../prds/prd-zcrud-study-ui-2026-07-16/prd.md#FR-SU2/FR-SU12] — ⚠️ le PRD dit « 1-5 » ; **le spine tranche 0..5** (écart **assumé**, § *Écarts assumés vis-à-vis du PRD*) — **suivre le spine**
- [Source: `CLAUDE.md#Critical Patterns] · [#Key Don'ts (zcrud)] · [#Processus BMAD strict] — vérif verte, `analyze`/`verify` **repo-wide** avant `done`
- [Source: `_bmad-output/implementation-artifacts/sprint-status.yaml:447-453] — séquencement : su-1 tête bloquante, puis workstreams A/B/C à packages disjoints

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] — `bmad-dev-story` (mode non interactif).

### Debug Log References

Baseline commit : `9ed81259f2d386e2596a8b8552231768f95bf110`.

**Les 6 preuves par grep négatif de la story ont été REJOUÉES sur disque** avant
toute écriture : RC=1/1/1/1/2/1 conformes. Aucun symbole prétendu absent n'existait.

**Vérif verte repo-wide (rejouée réellement, RC capturés) :**

| Commande | RC | Détail |
|---|---|---|
| `melos run generate` | OK | **aucun `*.g.dart` modifié** — la story ne touche ni annotation ni générateur (N-A de fait) |
| `melos run analyze` | **0** | repo-wide, **0 issue sur les fichiers de la story** |
| `melos run test` | **0** | 23 packages verts (`zcrud_core` 931, `zcrud_markdown` 277, `zcrud_flashcard` 235, `zcrud_study` 201, `zcrud_session` 87…) |
| `melos run verify` | **0** | graphe acyclique · **CORE OUT=0 OK** · secrets OK · codegen-distribution OK |

**Injections de faute R3 — JOUÉES RÉELLEMENT (cassée → rouge constaté → restaurée → verte) :**

| Inj. | Faute injectée | Verdict |
|---|---|---|
| R3-I1 | `clampQuality` → `quality.clamp(0, 5)` en dur | 🔴 attendu = obtenu (`Expected: <1>, Actual: <0>` sur l'échelle 1..4) |
| R3-I2 | `ZQualityScale` re-déclare `min = 0, max = 5` | 🔴 **double** : test de dérivation (`Expected: [1,2,3,4], Actual: [0,1,2,3,4,5]`) **et** garde de source unique (4 littéraux détectés) |
| R3-I3 | `zSectionKey` préfixe la clé (`'section:$contentType'`) | 🔴 3 tests, dont la **preuve de bout en bout** (`ZFolderContentsOrder` + `applyOrder`) qui démontre l'orphelinage réel |
| R3-I4 | `QuillController` en signature + import `zcrud_markdown` dans le défaut | 🔴 **double** : fuite de type en signature publique **et** import riche sur le chemin par défaut |
| R3-I5 | condition de l'`assert` de mode neutralisée (`true`) | 🔴 **exactement** les 4 modes non-SRS rougissent, les 23 autres tests restent verts (aucun faux positif) |

Aucun test tautologique : chaque test porteur a été vu rougir sur la faute qu'il prétend attraper.

### Completion Notes List

**AC1..AC6 : tous satisfaits.** Décisions et écarts, tous vérifiés sur disque :

1. **ÉCART vs la story (Stratégie de test) — `zcrud_study_kernel` n'est PAS un package
   Flutter.** La story affirme « `zcrud_flashcard`, `zcrud_session`, `zcrud_study_kernel` sont
   des packages Flutter (pubspecs vérifiés) ⇒ `flutter test` ». **Faux pour le kernel** :
   sa dev-dep est `test: ^1.25.0` (aucun `flutter_test`) et **tous** ses tests existants
   importent `package:test/test.dart` (`apply_order_test.dart`…). Détecté par le lint
   `depend_on_referenced_packages` sur mes 2 tests neufs. **Corrigé** : les tests kernel
   utilisent `package:test`, conformément à la convention réelle du package.

2. **RÉPARATION HORS PÉRIMÈTRE (régression cross-package, précédent `ZExportApi`) :**
   l'export de `zSectionKey` par le barrel kernel a fait **rougir**
   `zcrud_flashcard/test/z_kernel_surface_guard_test.dart` (garde préexistante :
   tout symbole public du kernel doit être classé `hide` ∪ allowlist). **Invisible d'une
   vérif par-package** — attrapée par le `melos run test` repo-wide exigé par AC6.
   **Arbitrage** : `zSectionKey` ajouté au **`hide`** de `zcrud_flashcard`, par **précédent
   exact** — `applyOrder`, `ZFolderContentsOrder` et `kSectionOrdersKey` (la famille à
   laquelle il appartient) y sont **déjà masqués** comme « study-niveau, NON pertinent
   flashcard ». L'allowlister aurait été incohérent avec sa propre famille et aurait élargi
   la surface publique flashcard. Réversible si su-2..su-6 le requièrent.

3. **`ZQualityScale.fromConfig` est NON-`const` — par nécessité du langage, pas par choix.**
   Un constructeur `const` ne peut pas lire un champ d'instance de son paramètre
   (`config.minQuality` n'est pas une expression constante). La seule alternative — recopier
   `0`/`5` en défauts littéraux — **serait précisément la seconde source qu'AD-46 interdit**.
   La dérivation prime sur la constance ; le VO reste `@immutable`. Conséquence bornée et
   assumée : `const` retiré de 3 `ZSessionQualityBreakdown` **de test** (aucun call-site de
   prod n'était `const` — vérifié par grep).

4. **AD-40 — le slot est défini côté `zcrud_flashcard`** (`ZFlashcardContentBuilder` +
   `ZFlashcardDefaultContent.builder`, tear-off statique stable), calqué sur
   `ZMindmapNodeContentBuilder`. `zcrud_mindmap` **non retouché** (déjà conforme).
   **L'adaptateur markdown/LaTeX n'est PAS livré** (périmètre su-2, cf. AC4).

5. **La garde AC4 est une garde de SOURCE, pas de GRAPHE — portée déclarée honnêtement** :
   `zcrud_flashcard` **dépend légitimement** de `zcrud_markdown` (arête préexistante,
   `z_flashcard_api.dart`) ; une preuve de graphe « flashcard ne voit pas Quill » serait
   **fausse par construction** et sans pouvoir. AD-40 exige plus fin : pas de fuite de type
   riche **en signature publique** — c'est ce qui est testé, et rien de plus.

6. **Aucune arête de dépendance ajoutée** (`zcrud_session → zcrud_flashcard` préexiste) ;
   **CORE OUT=0** intact ; **aucune écriture dans `zcrud_core`** ; **aucun moteur créé** ;
   **aucun `ZSessionReviewer` no-op** ; **aucune 2ᵉ entité d'ordre**.

7. **`sprint-status.yaml` NON modifié** — l'étape 4 du skill le prévoit, mais la consigne de
   l'orchestrateur l'interdit explicitement (elle prime). Le fichier porte déjà son édition
   `backlog → ready-for-dev`. **Aucun commit effectué** (commit en fin d'epic).

8. **Robustesse des gardes de source (anti-faux-vert)** : chaque garde embarque une
   **contre-preuve R12** (`isNotEmpty` sur ce qui est scanné) **et** un test de
   **contre-preuve du scanner lui-même** (sur source artificielle : il DOIT détecter la
   faute, et NE DOIT PAS faux-positiver sur du dartdoc). Une garde morte est ainsi impossible.

### File List

**NEW (6)**
- `packages/zcrud_study_kernel/lib/src/domain/z_section_key.dart`
- `packages/zcrud_study_kernel/test/z_section_key_test.dart`
- `packages/zcrud_study_kernel/test/z_section_key_single_composition_test.dart`
- `packages/zcrud_flashcard/lib/src/presentation/z_flashcard_content_slot.dart`
- `packages/zcrud_flashcard/test/z_srs_config_test.dart`
- `packages/zcrud_flashcard/test/z_flashcard_content_slot_test.dart`
- `packages/zcrud_flashcard/test/z_flashcard_rich_type_leak_test.dart`
- `packages/zcrud_session/test/z_quality_scale_single_source_test.dart`

**UPDATE**
- `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart` (T1 : bornes + `assert` + `clampQuality` + `==`/`hashCode`)
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` (export du slot ; `hide zSectionKey` — cf. note 2)
- `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart` (T2 : `fromConfig`, littéraux supprimés)
- `packages/zcrud_session/lib/src/domain/z_study_session_engine.dart` (T5 : `assert` de mode + dartdoc)
- `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` (export `z_section_key.dart`)
- `packages/zcrud_session/test/z_session_engine_test.dart` (AC5 : 4 refus + 2 verts + exhaustivité)
- `packages/zcrud_session/test/presentation/z_srs_quality_buttons_test.dart` (migration + discriminant AC2)
- `packages/zcrud_session/test/presentation/z_session_quality_breakdown_test.dart` (migration des call-sites)

### Change Log

| Date | Changement |
|---|---|
| 2026-07-16 | SU-1 implémentée (AC1..AC6). AD-46 : bornes 0..5 possédées par `ZSrsConfig`, `ZQualityScale` dérive. AD-38 : `zSectionKey` canonique (rétro-compat verbatim verrouillée). AD-40 : slot flashcard + défaut texte brut. AD-34 : garde de mode symétrique sur `ZStudySessionEngine`. Vérif verte repo-wide RC=0 (analyze/test/verify) ; 5 injections R3 jouées et constatées rouges. |
