# Story ES-4.5 : Widgets qualité & progression SRS — `ZSrsQualityButtons`, `ZSessionQualityBreakdown`, `ZStudyProgressRings` (présentation PURE, thème/labels injectés)

Status: review

<!-- Epic ES-4 : SRS convergé + runtimes de session. ES-4.5 est la DERNIÈRE story d'ES-4 (déclenche la rétrospective ES-4). Dépend d'ES-4.1 DONE (source SM-2 unique verrouillée : ZSrsConfig.passThreshold + ZSm2Scheduler.simulate — jamais recalculé en dur), d'ES-4.2/4.3/4.4 DONE (runtimes qui PRODUISENT les résultats consommés) et d'ES-2.7 DONE (value-object ZStudySessionResult {mode,total,correct,byQuality}). SÉQUENTIELLE vis-à-vis d'ES-4.1..4.4 : MÊME package zcrud_session, mais NOUVEAU sous-dossier lib/src/presentation/ (fichiers NEUFS distincts). NE modifie AUCUN domaine 4.2/4.3/4.4 (z_study_session_engine.dart, z_linear_session_state.dart, z_white_exam_session_engine.dart, z_session_state.dart, z_session_item.dart) sauf le barrel (exports ADDITIFS). -->
<!-- ⚠️ PARALLÉLISATION — workstream A. Un workstream B (epic ES-5) écrit packages/zcrud_study/** en parallèle. ISOLATION STRICTE : cette story n'écrit QUE des fichiers NEUFS sous packages/zcrud_session/lib/src/presentation/ + des exports ADDITIFS au barrel packages/zcrud_session/lib/zcrud_session.dart + des tests/goldens neufs. NE touche PAS zcrud_core/lib, zcrud_flashcard/lib, zcrud_study_kernel/lib, zcrud_study/**, les 6 fichiers domaine d'ES-4.2/4.3/4.4, NI sprint-status.yaml (orchestrateur). Vérifs CIBLÉES par package (PAS de melos repo-wide au milieu du dev — délégué à l'orchestrateur au gate de commit d'epic). -->
<!-- Gotchas rétro en vigueur : R12 (pouvoir discriminant EXIGÉ — mapping UI↔quality + breakdown fidèle CENTRAUX), R14 (runner par NATURE du package — zcrud_session = Flutter → flutter test, y compris widget tests + golden), R15 (RC capturé HORS pipe), R13 (restauration par édition ciblée, jamais git checkout), R3 (injections orchestrateur), R6 (jamais de dégradation silencieuse — un byQuality inattendu se RÉVÈLE, ne se tait pas). -->

## Story

As a **développeur intégrateur (DODLP / IFFD / lex)**,
I want **trois widgets de PRÉSENTATION PURS — `ZSrsQualityButtons` (boutons de notation qualité, échelle 0-5 ou 1-5 configurable, callback), `ZSessionQualityBreakdown` (répartition `byQuality` d'un `ZStudySessionResult`), `ZStudyProgressRings` (anneaux de progression total/correct via `CustomPaint` pur) — sans AUCUNE couleur/label/icône codée en dur, directionnels, accessibles (Semantics, ≥ 48 dp), consommant les résultats produits par les runtimes ES-4.2/4.3/4.4**,
so that **j'affiche notation, distribution des qualités et progression avec l'apparence de MON app (couleurs/labels injectés via `ZcrudScope`/`ThemeExtension` + l10n `zcrud_core`), le mapping bouton→qualité vivant DANS le widget (hors du scheduler, ES-4.1 D6), les intervalles prévisionnels venant de `ZSm2Scheduler.simulate` (jamais recalculés en dur), et zéro gestionnaire d'état ni écriture SRS.**

---

## Contexte & état mesuré sur disque

> ⚠️ **Aucun nouveau package, aucune nouvelle dépendance de pubspec, aucun `.g.dart`.** Cette story AJOUTE un sous-dossier `lib/src/presentation/` au package `zcrud_session` **déjà livré (ES-4.2..4.4)** et COMPOSE des value-objects/seams EXISTANTS (`ZStudySessionResult`, `ZSrsConfig.passThreshold`, `ZSm2Scheduler.simulate`, `ZcrudScope`/`ZcrudTheme`/`ZColorKeyResolver`). Le graphe de dépendances inter-packages est **INCHANGÉ** (voir §4), `melos list` reste **20**.
>
> **Nommage — source de vérité = l'épic ES-4.5** (`epics.md` l.690-710) : les widgets s'appellent **`ZSrsQualityButtons`**, **`ZSessionQualityBreakdown`**, **`ZStudyProgressRings`**. (Le brief d'orchestration mentionne les alias raccourcis `ZQualityBreakdown`/`ZProgressRings` — RETENIR les noms canoniques de l'épic, préfixe `Z`, convention repo.)

### 1. Les résultats CONSOMMÉS (livrés, lus INTÉGRALEMENT sur disque)

| Symbole | Fichier (ligne mesurée) | Rôle consommé par ES-4.5 |
|---|---|---|
| `ZStudySessionResult` | `packages/zcrud_study_kernel/lib/src/domain/z_study_session_result.dart` (l.53-125 : `{mode, total, correct, byQuality: Map<String,int>}`, `const`, égalité profonde D7, `byQuality` **NON MODIFIABLE**) | **DTO d'entrée** : `byQuality` → `ZSessionQualityBreakdown` ; `total`/`correct` → `ZStudyProgressRings`. **Consommé tel quel** (aucune reconstruction, aucun clone). `byQuality` a des clés qualité SM-2 opaques `"0".."5"` (verbatim, cf. l.107). |
| `ZSrsConfig.passThreshold` | `packages/zcrud_flashcard/lib/src/domain/z_srs_config.dart` (l.26/56-58, défaut `3`, échelle `0..5`) | **Frontière réussite** `quality >= passThreshold`. Réutilisé (jamais un `3` littéral) pour teinter/étiqueter réussite vs lapse dans le breakdown & les boutons — INJECTÉ, jamais recopié (D5). |
| `ZSm2Scheduler.simulate` | `packages/zcrud_flashcard/lib/src/domain/z_sm2_scheduler.dart` (l.100-105) + contrat `packages/zcrud_flashcard/lib/src/domain/z_srs_scheduler.dart` (l.40) : `ZRepetitionInfo simulate(ZRepetitionInfo current, int quality, {DateTime? now})` | **Source des intervalles prévisionnels** de `ZSrsQualityButtons` (AC1 épic). Projection PURE sans effet de bord (l.103 : « identique à `apply`, aucun état persisté »). Le widget NE recalcule JAMAIS l'intervalle : il APPELLE le seam. |
| `ZStudySessionEngine` / `ZWhiteExamSessionEngine` / `ZLinearSessionState` | `z_study_session_engine.dart`, `z_white_exam_session_engine.dart`, `z_linear_session_state.dart` | **NON modifiés, NON importés en dur par les widgets.** Les widgets consomment leur SORTIE (`ZStudySessionResult`) + reçoivent un callback `onQualitySelected`. Un moteur peut brancher ce callback sur `grade`/`answer`, mais le widget n'en dépend PAS (découplage par callback, AD-2). |

### 2. Le seam de thème/labels INJECTÉ (lu — `zcrud_core` présentation)

| Symbole | Fichier (ligne mesurée) | Rôle |
|---|---|---|
| `ZcrudScope` | `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` (l.48-189) : `InheritedWidget`, `static of(context)` (l.168), champs `resolver`/`theme`/`labels`/`colorKeyResolver` | Seam d'injection **par défaut zéro-config** (`InheritedWidget`, aucune dépendance à un gestionnaire d'état). Source des couleurs/labels/palette pour les 3 widgets. |
| `ZcrudTheme extends ThemeExtension<ZcrudTheme>` | `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart` (l.22-…) : couleurs sémantiques `nullable` + repli `ZcrudTheme.fallback` (dérivées du `ColorScheme`), tokens d'espacement/rayon, `EdgeInsetsDirectional` | **Design-tokens injectés** (FR-26/AD-6). AUCUN style codé en dur : les couleurs sont dérivées du `ColorScheme`/`TextTheme` au repli. Espacements directionnels réutilisés. |
| `ZColorKeyResolver` / `zDefaultColorKeyResolver` | `packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart` (l.139-191) : `colorKey (String) → ZColorPair` via `ColorScheme` | Résolution d'une **`colorKey` bornée** (jamais `Colors.blue`) — mécanisme d'injection couleur EXISTANT réutilisé pour les qualités/segments (AD-13 : couleur jamais SEUL canal). |
| l10n `zcrud_core` | `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart`, `z_labels.dart` | **Labels injectés** (jamais un `"Facile"` codé en dur dans le widget). Un label de qualité manquant retombe sur un fallback l10n de `zcrud_core`, jamais sur une string littérale. |

> ⚠️ **INFLEXION MESURÉE — 1re surface de PRÉSENTATION de `zcrud_session`.** Le package n'exposait jusqu'ici que du domaine (`lib/src/domain/`), important `package:zcrud_core/domain.dart` (pur-Dart). Cette story introduit `lib/src/presentation/` important `package:flutter/material.dart` **et** la surface présentation de `zcrud_core` (`package:zcrud_core/zcrud_core.dart` — `ZcrudScope`/`ZcrudTheme`/`ZColorKeyResolver`). **Ce sont des surfaces d'import NOUVELLES au sein de nœuds de graphe DÉJÀ présents** (`flutter` et `zcrud_core` sont déjà des arêtes sortantes du pubspec, cf. §4) ⇒ **`graph_proof.py` INCHANGÉ, aucune nouvelle arête inter-packages**.

### 3. Le barrel actuel (lu — `packages/zcrud_session/lib/zcrud_session.dart` l.24-29)
```dart
export 'src/domain/z_linear_session_state.dart';
export 'src/domain/z_session_item.dart';
export 'src/domain/z_session_reviewer.dart';
export 'src/domain/z_session_state.dart';
export 'src/domain/z_study_session_engine.dart';
export 'src/domain/z_white_exam_session_engine.dart';
```
⇒ **exports ADDITIFS** (édition ciblée, additive, du barrel) des 3 nouveaux fichiers présentation + du/des DTO(s) publics (`ZQualityScale`, `ZProgressRingsData`). Aucun export supprimé/modifié.

### 4. Runner, graphe & gates (MESURÉ)
- **Runner (R14) :** `zcrud_session` est un paquet **Flutter** (`flutter` en dépendance, `pubspec.yaml` l.… `flutter: sdk: flutter`). Les widgets importent `package:flutter/material.dart` ⇒ tests = **`flutter test`** (widget tests + golden). `dart test` échouerait.
- **`gate:graph` (`scripts/dev/graph_proof.py`) :** ES-4.5 n'ajoute **AUCUNE** arête inter-packages — `flutter`, `zcrud_core`, `zcrud_flashcard`, `zcrud_study_kernel` sont **déjà** déclarés en dépendances (`packages/zcrud_session/pubspec.yaml` dependencies, MESURÉ). **ACYCLIQUE + CORE OUT=0 préservés, `graph_proof.py` INCHANGÉ.** (Confirmer : la surface présentation de `zcrud_core` importée par le widget ne crée pas d'arête retour `zcrud_core → zcrud_session` — impossible par construction, AD-1.)
- **`gate:melos` :** aucun nouveau package ⇒ `melos list` = **20** (inchangé).
- **`gate:codegen-distribution` :** aucun `@ZcrudModel`/`@JsonSerializable` (widgets + DTO d'affichage NON persistés) ⇒ **aucun `*.g.dart`** attendu, gate sans objet.
- **`gate:web` (déterminisme pur-Dart) :** cible les paquets pur-Dart ; `zcrud_session` (Flutter) est HORS cible.

---

## Reconnaissance externe MESURÉE (documentaire — origine des boutons qualité / anneaux)

> Le critère de résolution **exécutable in-repo** reste : mapping UI↔quality golden (AC1), breakdown fidèle par comptage/golden (AC2), painter/DTO golden (AC3). La reco externe motive l'apparence de référence, PAS le contrat.

### IFFD / lex — boutons de qualité SM-2 et surfaces de progression (READ-ONLY, non modifiées)
- **À MESURER par le dev avant implémentation** (reco read-only, citer `fichier:ligne`) :
  - lex/IFFD : le composant de notation qualité (échelle SM-2 `0..5`, labels type « Again/Hard/Good/Easy » ou variante), la **couleur par qualité** (à ne PAS recopier — origine du `colorKey` injecté), et l'aperçu d'intervalle (« prévu dans X j »).
  - lex/IFFD : la surface de **répartition des qualités** (histogramme/segments) d'un résultat de session.
  - lex/IFFD : les **anneaux/jauges de progression** (total vs correct) — origine du `CustomPaint`.
- **GOTCHA attendu (précédent ES-4.4)** : dans lex/IFFD ces surfaces sont **diffuses dans la présentation** (couleurs `AppColors.srs*` en dur, labels littéraux). ES-4.5 en extrait la STRUCTURE (mapping, DTO, painter) en **rejetant** les couleurs/labels en dur → injection `ZcrudScope`. Citer la string/couleur en dur mesurée comme **anti-modèle** (ce qu'on NE reproduit PAS).

---

## Décisions de conception (tranchées ici)

- **D1 — 3 widgets, 3 fichiers NEUFS, présentation PURE.** `packages/zcrud_session/lib/src/presentation/{z_srs_quality_buttons.dart, z_session_quality_breakdown.dart, z_study_progress_rings.dart}`. Chacun `StatelessWidget` (ou composé de `ValueListenableBuilder`/`ListenableBuilder` SI un `Listenable` est injecté) — **AUCUN gestionnaire d'état** (Riverpod/GetX/provider), **AUCUN `setState`** à l'échelle du widget, **AUCUN `ChangeNotifier` détenu** (AD-2/AD-15). Aucune écriture SRS : les widgets NE détiennent NI `ZSrsScheduler` mutant, NI `ZRepetitionStore` ; `simulate` est une projection PURE (AC1).
- **D2 — `ZSrsQualityButtons` : le mapping UI↔quality vit ICI (ES-4.1 D6).** Le widget porte une **échelle configurable** `ZQualityScale` (value-object : `min` ∈ {0,1}, `max` = 5, ⇒ liste ordonnée de qualités). Chaque bouton rend un cran de qualité et, au tap, appelle `onQualitySelected(int quality)` avec **la qualité EXACTE du cran** (mapping déterministe, testé golden AC1). Le label de chaque cran vient de l'l10n injectée (jamais littéral) ; la couleur d'un cran vient d'un `colorKey` injecté résolu par `ZColorKeyResolver` (jamais `Colors.*`). L'intervalle prévisionnel d'un cran, si affiché, vient de `previewLabelFor(quality)` — un seam qui APPELLE `ZSm2Scheduler.simulate(current, quality)` (jamais un calcul d'intervalle en dur ; AC1 épic « intervalles de `simulate`/`previewLabel` »).
- **D3 — `ZSessionQualityBreakdown` : rend `byQuality` INJECTÉ, fidèle.** Prend `Map<String,int> byQuality` (typiquement `result.byQuality`) + l'échelle `ZQualityScale`. Rend **exactement** un segment/barre par qualité présente, valeur = compte, **aucune catégorie omise, aucune inversée** (AC2 discriminant). Ordre = ordre de l'échelle (croissant de qualité), pas l'ordre d'insertion de la map. Couleurs par `colorKey` injecté, labels l10n, **compte affiché en texte** (couleur jamais seul canal, AD-13). Une clé `byQuality` HORS échelle (ex. `"9"`, corpus corrompu) est **rendue à part / signalée**, jamais silencieusement fusionnée dans un autre cran (R6). `ListView.builder`/`Wrap` — jamais `ListView(children:[...])`.
- **D4 — `ZStudyProgressRings` : `CustomPaint` pur consommant un DTO pré-calculé (AC3 épic).** Un value-object d'affichage `ZProgressRingsData` (ex. `{total, correct, ratio ∈ [0,1] clampé}` — `ratio = total == 0 ? 0 : correct/total`) est **pré-calculé** (fonction pure exposée `ZProgressRingsData.fromResult(ZStudySessionResult)`), puis un `CustomPainter` le peint **sans logique métier** (aucun accès repo, aucun calcul SRS). `total == 0` ⇒ anneau vide (pas de division par zéro). Couleurs (piste/progression) injectées via thème/`colorKey`, jamais en dur.
- **D5 — `passThreshold` INJECTÉ, jamais `3` littéral.** Toute distinction réussite/lapse (teinte, regroupement, `Semantics` « réussi ») lit `ZSrsConfig.passThreshold` (défaut `3`) fourni par l'appelant, jamais une constante `3` en dur (D5, réutilisation ES-4.1).
- **D6 — a11y & directionnel NON-NÉGOCIABLES (AD-13/NFR-S6/NFR-S7).** Cibles tap ≥ 48 dp (boutons qualité), `Semantics` explicites (chaque bouton = label + valeur ; chaque segment breakdown = « qualité X : N » ; anneau = « correct/total »). Directionnel **uniquement** : `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start/end`, `PositionedDirectional` — JAMAIS les variantes `left/right`. Couleur jamais SEUL canal (texte/label toujours présent).
- **D7 — Barrel : exports ADDITIFS uniquement.** Ajout des 3 widgets + `ZQualityScale` + `ZProgressRingsData` au barrel (édition ciblée). Aucune modification/suppression d'export existant. Graphe & runner INCHANGÉS (§4).
- **D8 — Découplage par callback (pas de couplage runtime).** Les widgets NE `import` PAS les moteurs (`ZStudySessionEngine` etc.) : ils reçoivent `onQualitySelected` (callback) et les DTO (`ZStudySessionResult`/`byQuality`) en paramètres. Un moteur ES-4.2/4.3/4.4 branche ces seams côté appelant. (Évite un cycle de couplage présentation↔runtime et respecte AD-2.)

---

## Acceptance Criteria

> Chaque AC est à **pouvoir discriminant (R12)** : il nomme le vecteur/test qui ROUGIT si la garde saute. Les DEUX CENTRAUX : **AC1 (mapping UI↔quality)** et **AC2 (breakdown fidèle)**.

1. **AC1 — `ZSrsQualityButtons` : mapping bouton→qualité EXACT + intervalle de `simulate` — CŒUR (D2, R12).** Un widget test rend `ZSrsQualityButtons(scale: ZQualityScale(min: 0, max: 5), onQualitySelected: capture, previewLabelFor: …)`. (a) Taper le cran de qualité `q` (pour chaque `q ∈ 0..5`) appelle `onQualitySelected(q)` **avec exactement `q`** — figé par capture et assertion cran-par-cran. (b) Le libellé d'intervalle d'un cran provient de `previewLabelFor(q)` qui délègue à `ZSm2Scheduler.simulate(current, q)` ; un test vérifie que l'intervalle affiché = `simulate(...).interval` (jamais une valeur recalculée en dur). *(Discriminant : INJ-1 — inverser le mapping d'un cran (« Facile » → mauvaise qualité) OU coder un intervalle en dur fait rougir l'assertion cran-par-cran / la comparaison à `simulate`.)*
2. **AC2 — `ZSessionQualityBreakdown` : rend `byQuality` INJECTÉ, aucune catégorie omise/inversée — CŒUR (D3, R6, R12).** Un widget/golden test rend `ZSessionQualityBreakdown(byQuality: {"0":1,"2":3,"5":2}, scale: …)` et vérifie **par comptage** (via `Semantics`/finder) qu'il existe **un et un seul** segment par clé présente, chacun avec sa valeur exacte, ordonnés par qualité croissante. Une clé hors échelle (`{"9":1}`) est rendue/signalée à part (jamais fusionnée). *(Discriminant : INJ-2 — omettre une catégorie, inverser deux comptes, ou fusionner une clé inconnue fait rougir le comptage/golden.)*
3. **AC3 — `ZStudyProgressRings` : `CustomPaint` PUR sur DTO pré-calculé — (D4, R12).** `ZProgressRingsData.fromResult(ZStudySessionResult(total: 8, correct: 6))` produit `ratio == 0.75` (fonction pure, test unitaire) ; `fromResult(total: 0, correct: 0)` ⇒ `ratio == 0` (pas de division par zéro). Le widget est un `CustomPaint` consommant ce DTO ; un golden fige le rendu de référence. *(Discriminant : INJ-3 — un `ratio` faux (off-by-one, `correct/(total-1)`) ou un crash sur `total==0` fait rougir le test de DTO / golden.)*
4. **AC4 — Thème/labels/couleurs INJECTÉS, ZÉRO valeur en dur — (D2/D3/D4, FR-26/AD-6, R12).** Un test/scan prouve qu'AUCUN des 3 fichiers ne contient `Colors.` littéral, `Color(0x…)`, `AppColors.`, ni label utilisateur en string littérale : couleurs via `ZColorKeyResolver`/`ZcrudTheme` (repli `Theme.of`), labels via l10n `zcrud_core`. *(Discriminant : INJ-4 — introduire `Colors.blue`/`"Facile"` en dur fait rougir le scan / le test de thème override.)*
5. **AC5 — a11y & directionnel — (D6, AD-13/NFR-S6/NFR-S7, R12).** Widget test : chaque bouton qualité a une cible ≥ 48 dp (`tester.getSize` / `SemanticsNode`), chaque surface expose un `Semantics` (label+valeur) ; scan : aucune API non-directionnelle (`EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`, `TextAlign.left/right`, `Positioned(left:/right:)`), aucun `ListView(children:[...])`. *(Discriminant : INJ-5 — retirer un `Semantics` ou passer une cible < 48 dp / une API `left/right` fait rougir.)*
6. **AC6 — `passThreshold` INJECTÉ, jamais `3` en dur — (D5, R12).** Un test passant `passThreshold: 4` change la frontière réussite/lapse dans le breakdown/les boutons (ex. cran `3` bascule de « réussi » à « lapse ») ; aucun `3` littéral dans les 3 fichiers. *(Discriminant : INJ-6 — figer `>= 3` en dur fait rougir le test à `passThreshold: 4`.)*
7. **AC7 — Consommation `ZStudySessionResult` sans reconstruction — (D3/D4, anti-inertie).** Le breakdown consomme `result.byQuality` et les rings consomment `result.total`/`result.correct` **directement** ; aucun re-parse, aucun `Map` dupliqué, aucun recomptage à partir d'une liste brute. Un test round-trip vérifie `ZSessionQualityBreakdown(byQuality: r.byQuality)` == rendu de `r`.
8. **AC8 — Barrel additif + graphe/runner INCHANGÉS — (D7, §4).** Le barrel exporte les 3 widgets + DTO ; `melos list == 20` ; `graph_proof.py` inchangé (aucune arête ajoutée) ; runner = `flutter test`. `flutter analyze` du package RC=0 ; `flutter test` du package RC=0.
9. **AC9 — Pureté runtime : aucun import de moteur, aucune écriture SRS — (D1/D8, AD-2/AD-23).** Scan : les 3 widgets n'importent NI `z_study_session_engine.dart`/`z_white_exam_session_engine.dart`/`z_linear_session_state.dart`, NI `ZRepetitionStore`, NI un gestionnaire d'état ; `simulate` est appelé mais AUCUN `apply`/`put`/`reviewCard` (projection pure seule).

---

## Tasks / Subtasks

- [x] **T1 — `ZSrsQualityButtons` + `ZQualityScale` (D2/D5/D6)** — `lib/src/presentation/z_srs_quality_buttons.dart`
  - [x] `ZQualityScale` value-object (`min ∈{0,1}`, `max=5` ⇒ liste ordonnée), `==`/`hashCode`.
  - [x] `StatelessWidget` : un bouton par cran, `onQualitySelected(int quality)` avec la qualité EXACTE, cible ≥ 48 dp, `Semantics` label+valeur.
  - [x] Labels via l10n `zcrud_core` (fallback l10n, jamais littéral) ; couleur via `colorKey` + `ZColorKeyResolver` ; intervalle via `previewLabelFor(quality)` → `ZSm2Scheduler.simulate` (jamais recalculé). Directionnel.
- [x] **T2 — `ZSessionQualityBreakdown` (D3/D5/D6)** — `lib/src/presentation/z_session_quality_breakdown.dart`
  - [x] Rend `byQuality` injecté, un segment par clé, valeur exacte, ordre par qualité, compte affiché en texte (couleur non-seule). Clé hors échelle signalée à part (R6). `Wrap`. `Semantics` par segment.
- [x] **T3 — `ZStudyProgressRings` + `ZProgressRingsData` (D4/D6)** — `lib/src/presentation/z_study_progress_rings.dart`
  - [x] `ZProgressRingsData.fromResult(ZStudySessionResult)` (fonction PURE, `ratio` clampé, `total==0`→0).
  - [x] `CustomPaint`/`CustomPainter` PUR consommant le DTO ; couleurs injectées ; `Semantics` « correct/total ».
- [x] **T4 — Barrel additif (D7)** — `lib/zcrud_session.dart` : exports ADDITIFS des 3 widgets + `ZQualityScale` + `ZProgressRingsData` (aucune suppression).
- [x] **T5 — Tests (runner `flutter test`, R14) + pouvoir discriminant (R12)** — `test/presentation/`
  - [x] `z_srs_quality_buttons_test.dart` (AC1 : mapping cran-par-cran + intervalle=`simulate`), `z_session_quality_breakdown_test.dart` (AC2 : comptage fidèle + clé hors échelle), `z_study_progress_rings_test.dart` (AC3 : DTO pur + widget), `z_widgets_hardcode_scan_test.dart` (AC4/AC5 scan couleur+directionnel), `z_widgets_purity_test.dart` (AC9 pureté imports). a11y/thème override/passThreshold intégrés au test des boutons.
  - [x] Golden : NON introduit — rendu figé par assertions sémantiques/comptage déterministes (évite la fragilité golden inter-environnements, fonts) ; AC3 gardé par le test PUR de `ZProgressRingsData` + rendu `CustomPaint`/Semantics.
- [x] **T6 — Vérif verte CIBLÉE + injections R3** — `flutter analyze` + `flutter test` du package RC=0 (RC hors pipe, R15). INJ-1..INJ-6 déroulées (chacune ROUGE puis restaurée par édition ciblée, R13).

---

## Injections R3 prévues (chaque garde prouvée LOAD-BEARING, rejouée par l'ORCHESTRATEUR)

> **Mesure RC (R15) — NON-NÉGOCIABLE :** `OUT=$(cmd); RC=$?` (ou `cmd; RC=$?`), **JAMAIS** `cmd | tail`/`| grep`. **Restauration (R13) :** édition ciblée de retour, JAMAIS `git checkout`. **Runner (R14) :** `zcrud_session` = paquet Flutter ⇒ `flutter test`.

| # | Injection (édition ciblée temporaire) | AC gardé | Rouge attendu |
|---|---|---|---|
| INJ-1 | Inverser le mapping d'un cran de `ZSrsQualityButtons` (cran `5` → `onQualitySelected(0)`), OU remplacer l'intervalle par une constante en dur | AC1 | assertion cran-par-cran / comparaison à `simulate` ROUGE |
| INJ-2 | Omettre une catégorie de `byQuality` (skip d'une clé) OU fusionner une clé hors échelle dans un cran connu | AC2 | comptage/golden breakdown ROUGE |
| INJ-3 | Fausser `ZProgressRingsData.ratio` (`correct/(total-1)`) OU retirer le garde `total==0` | AC3 | test DTO / division par zéro ROUGE |
| INJ-4 | Introduire `Colors.blue` / label `"Facile"` en dur dans un widget | AC4 | scan anti-hardcode / test thème override ROUGE |
| INJ-5 | Retirer un `Semantics` OU réduire une cible tap < 48 dp OU utiliser `EdgeInsets.only(left:)` | AC5 | test a11y / scan directionnel ROUGE |
| INJ-6 | Figer `quality >= 3` en dur au lieu de lire `passThreshold` | AC6 | test à `passThreshold: 4` ROUGE |

---

## Vérif verte à rejouer (commandes exactes, RC capturé HORS pipe — R15)

```bash
# Runner = flutter (R14 : widgets Material ⇒ flutter test ; dart test échouerait)
cd /home/zakarius/DEV/zcrud/packages/zcrud_session

# 1. Analyse ciblée
flutter analyze; RC_ANALYZE=$?

# 2. Tests du package (widget tests + golden)
flutter test; RC_TEST=$?

echo "analyze=$RC_ANALYZE test=$RC_TEST"   # attendu : 0 0

# 3. Gate graphe (INCHANGÉ — aucune arête ajoutée) — délégué à l'orchestrateur au gate d'epic
#    python3 /home/zakarius/DEV/zcrud/scripts/dev/graph_proof.py ; RC=$?
# 4. melos list == 20 (inchangé)
```
> ⚠️ Ne JAMAIS mesurer un RC via `flutter test … | tail`/`| grep` (R15). Toujours `cmd; RC=$?`.
> ⚠️ **Runner (R14)** : `zcrud_session` = paquet Flutter ⇒ `flutter test` (`dart test` échouerait — import flutter/material non résolu).
> ⚠️ **Golden (R14/R15)** : si un golden est introduit, le régénérer une fois (`flutter test --update-goldens`) PUIS committer les captures ; ne jamais laisser un golden non figé.

---

## Dev Notes

### Périmètre & invariants NON-NÉGOCIABLES
- **AD-2 / AD-15** : widgets PURS de présentation (`StatelessWidget`/`ValueListenableBuilder`), AUCUN gestionnaire d'état, callbacks injectés. Aucun `setState`, aucun `ChangeNotifier` détenu.
- **AD-23** : aucune écriture SRS. `simulate` = projection PURE (aucun `apply`/`put`/`reviewCard`).
- **FR-26 / AD-6 / AD-13** : couleurs/labels/icônes INJECTÉS (`ZcrudScope`/`ZcrudTheme`/`ZColorKeyResolver` + l10n `zcrud_core`, repli `Theme.of`), jamais en dur ; directionnel (`*Directional`, `TextAlign.start/end`), `Semantics`, cibles ≥ 48 dp, couleur jamais seul canal, `ListView.builder`.
- **AD-1** : CORE OUT=0 — `zcrud_core` ne dépend JAMAIS de `zcrud_session` (l'import présentation est UNIDIRECTIONNEL, session→core).

### Anti-inertie (réutilisation)
- CONSOMMER `ZStudySessionResult` (ES-2.7) — `byQuality`/`total`/`correct` directement, aucune reconstruction (AC7).
- RÉUTILISER l'échelle/frontière ES-4.1 : `ZSrsConfig.passThreshold` injecté (jamais `3` en dur), `ZSm2Scheduler.simulate` pour les intervalles (jamais recalculés).
- RÉUTILISER le seam thème EXISTANT (`ZColorKeyResolver`, `ZcrudTheme`) — ne PAS créer un nouveau mécanisme de couleur.

### Graphe & runner (MESURÉ)
- `graph_proof.py` INCHANGÉ : `flutter`, `zcrud_core`, `zcrud_flashcard`, `zcrud_study_kernel` déjà arêtes du pubspec. L'ajout de `package:flutter/material.dart` et de la surface présentation de `zcrud_core` sont des surfaces d'import NOUVELLES dans des nœuds DÉJÀ présents ⇒ **zéro nouvelle arête inter-packages**. `melos list = 20`.
- Runner = `flutter test` (R14) : widgets Material.

### Références
- [Source: epics.md — Story ES-4.5 (l.690-710), FR-S21 ; AD-25/AD-2/AD-13 (l.51, l.249-252)]
- [Source: architecture.md — AD-2/AD-15 (Flutter-native), AD-13 (RTL/a11y/thème injecté, l.51), AD-1 (CORE OUT=0)]
- [Source: z_study_session_result.dart l.53-125 — DTO consommé] [z_srs_config.dart l.26/56-58 — passThreshold] [z_sm2_scheduler.dart l.100-105 — simulate]
- [Source: zcrud_scope.dart l.48-189, z_theme.dart l.22-…, z_color_key_resolver.dart l.139-191 — seams d'injection]
- [Source: CLAUDE.md — R3/R6/R12/R13/R14/R15 gotchas ; Key Don'ts (directionnel, ListView.builder, style injecté)]

## Dev Agent Record

### Agent Model Used
claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References
Vérifs vertes CIBLÉES (paquet Flutter → `flutter`, R14 ; RC capturé HORS pipe, R15 ; cwd = `packages/zcrud_session`) :

| Vérif | Commande | RC | Détail |
|---|---|---|---|
| analyze | `flutter analyze` | **0** | `No issues found!` |
| test | `flutter test` | **0** | **73** tests passés (18 existants domaine + 55 nouveaux/existants ; les 5 fichiers `test/presentation/` ajoutés) |
| graph | `python3 scripts/dev/graph_proof.py` | **0** | ACYCLIQUE, `out-degree(zcrud_core) = 0`, INCHANGÉ (aucune arête ajoutée) |
| melos | `dart run melos list` | — | **20** (inchangé) |

**Pouvoir discriminant R12 — 6 injections rejouées RÉELLEMENT (édition ciblée temporaire → ROUGE → restauration ciblée R13, jamais `git checkout`). Messages EXACTS capturés :**

- **INJ-1** (mapping cran 5 → `onQualitySelected(0)`) → AC1 ROUGE :
  `Expected: <5>  Actual: <0>` — « cran visuel 5 doit noter la qualité 5 (mapping D6) ».
- **INJ-2** (breakdown omet la catégorie `quality==2`) → AC2 ROUGE :
  `Expected: exactly one matching candidate  Actual: Found 0 widgets with key [<'zBreakdownSegment_2'>]`.
- **INJ-3** (ratio faussé `correct/(total-1)`) → AC3 ROUGE :
  `Expected: <0.75>  Actual: <0.8571428571428571>`.
- **INJ-4** (`Colors.blue` en dur dans `ZSrsQualityButtons`) → AC4 ROUGE :
  `z_srs_quality_buttons.dart:200 → Colors. :: color: Colors.blue,`.
- **INJ-5** (cible tap `minTarget = 24 < 48`) → AC5 ROUGE :
  `Expected: a value greater than or equal to <48>  Actual: <38.25>` — « cran 0 : largeur < 48 dp ».
- **INJ-6** (`quality >= 3` en dur au lieu de `passThreshold`) → AC6 ROUGE :
  `Expected: contains 'lapse'  Actual: 'ok'  Which: does not contain 'lapse'`.

Après restauration : `flutter analyze` RC=0 + `flutter test` RC=0 (73) reconfirmés, aucun résidu d'injection en code (résidus grep = doc-comments seuls).

### Completion Notes
Ultimate context engine analysis completed - comprehensive developer guide created. DERNIÈRE story d'ES-4 → déclenche la rétrospective ES-4 après `done`.

**Livré (3 widgets de présentation PURS, noms canoniques épic ES-4.5) :**
- `ZSrsQualityButtons` (+ `ZQualityScale`, seams `ZQualityLabelKeyResolver`/`ZQualityColorKeyResolver`, `zDefaultQualityLabelKey`) : mapping cran→qualité DANS le widget (D6), `onQualitySelected(int)` avec la qualité EXACTE, intervalle prévisionnel via seam `previewLabelFor` (= `ZSm2Scheduler.simulate` côté appelant — le widget N'IMPORTE PAS le scheduler ⇒ AD-23 par construction). Réussite/lapse via `passThreshold` INJECTÉ (jamais `3` en dur).
- `ZSessionQualityBreakdown` : rend `byQuality` INJECTÉ, un segment par clé présente, ordre par qualité croissante (ordre de l'échelle, pas d'insertion), compte en texte (couleur non-seule). Clé HORS échelle rendue À PART (`unknownKeyPrefix`), signalée dans `Semantics.label` (« hors échelle »), jamais fusionnée (R6).
- `ZStudyProgressRings` (+ `ZProgressRingsData.fromResult`, fonction PURE) : `CustomPaint`/`CustomPainter` PUR sur DTO pré-calculé ; `ratio = total==0 ? 0 : (correct/total).clamp(0,1)` (pas de division par zéro, clamp défensif) ; couleurs piste/progression injectées via `zResolveColorKeyOrSlot` ; `Semantics` « correct/total ».

**Injection thème/labels/couleurs (FR-26/AD-6/AD-13) :** couleurs via `zResolveColorKeyOrSlot`/`ZcrudTheme` (repli `Theme.of`), labels via `label(context, key)` l10n `zcrud_core` (clés `zcrud.srs.quality.*`, fallback numérique — jamais de libellé littéral), espacements/rayons `ZcrudTheme`, directionnel (`EdgeInsetsDirectional`, `TextAlign.center/end`), cibles ≥ 48 dp, `Wrap`/`Column` (jamais `ListView(children:)`).

**Découplage (AD-2/AD-15/D8) :** 3 `StatelessWidget` PURS, aucun gestionnaire d'état, aucun `setState`, aucun `ChangeNotifier` détenu, aucun import de moteur (`z_*_session_engine`/`z_linear_session_state`), aucune écriture SRS. Callbacks/DTO/seams injectés.

**Signalements de parallélisation (workstream A, isolation stricte) :**
- Écrit UNIQUEMENT sous `packages/zcrud_session/**` (3 fichiers NEUFS `lib/src/presentation/`, barrel additif, 5 tests NEUFS `test/presentation/`, + 1 test existant SCOPÉ). AUCUN touche à `zcrud_study`, `zcrud_core`, aux 6 fichiers domaine ES-4.2/4.3/4.4, `scripts/ci`, `pubspec.yaml` racine, `melos.yaml`, `sprint-status.yaml`.
- **`pubspec.yaml` de `zcrud_session` NON modifié** : `flutter` (donc `material`), `zcrud_core`, `zcrud_flashcard`, `zcrud_study_kernel` étaient DÉJÀ des dépendances. La surface présentation de `zcrud_core` + `flutter/material` sont des imports NOUVEAUX dans des nœuds de graphe DÉJÀ présents ⇒ **AUCUNE nouvelle arête inter-package, `graph_proof.py` INCHANGÉ, `melos list` = 20**.
- **Ajustement CIBLÉ d'un test existant** (`test/z_purity_test.dart`) : le scan « runtime widget-free » excluait TOUT `lib/**` ; il est SCOPÉ pour exclure `lib/src/presentation/` (widgets Material PURS, légitimes AD-2). La garde de pureté runtime reste intacte sur `lib/src/domain/` ; une garde de pureté dédiée aux widgets (aucun moteur importé, aucune écriture SRS) est ajoutée en `test/presentation/z_widgets_purity_test.dart` (AC9).

### File List
**Nouveaux (code) :**
- `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart`
- `packages/zcrud_session/lib/src/presentation/z_session_quality_breakdown.dart`
- `packages/zcrud_session/lib/src/presentation/z_study_progress_rings.dart`

**Nouveaux (tests) :**
- `packages/zcrud_session/test/presentation/z_srs_quality_buttons_test.dart`
- `packages/zcrud_session/test/presentation/z_session_quality_breakdown_test.dart`
- `packages/zcrud_session/test/presentation/z_study_progress_rings_test.dart`
- `packages/zcrud_session/test/presentation/z_widgets_hardcode_scan_test.dart`
- `packages/zcrud_session/test/presentation/z_widgets_purity_test.dart`

**Modifiés :**
- `packages/zcrud_session/lib/zcrud_session.dart` (barrel — exports ADDITIFS des 3 widgets + `ZQualityScale` + `ZProgressRingsData`)
- `packages/zcrud_session/test/z_purity_test.dart` (scan runtime SCOPÉ hors `lib/src/presentation/`)
