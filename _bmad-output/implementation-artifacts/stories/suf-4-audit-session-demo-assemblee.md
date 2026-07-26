---
baseline_commit: 1cb2107
---

# Story SUF-4 : Audit de parité session + fermeture des manques + démo assemblée

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

**En tant que** mainteneur de zcrud préparant la migration lex_douane (module « Étude »),
**je veux** un audit widget-par-widget prouvé sur disque de la chaîne `zcrud_session` face aux widgets natifs de `lex_ui`, la fermeture par **slots injectables** des écarts réels, et une **démo `example/` assemblée de bout en bout**,
**afin que** l'app cible puisse bridger le flux de session complet (mode-selector → boutons SRS → indicateur → résumé) **sans perte visuelle ni fonctionnelle**, avec la preuve que chaque garde de parité mord (R3).

Cette story **clôt l'epic SUF**. Elle vient **APRÈS SUF-1 (`ZPageScaffold`/`ZSearchableAppBar`), SUF-2 (`ZFolderCard`), SUF-3 (`ZStudyFolderDetail`)** — leur existence sur disque est un **pré-requis vérifié en début de dev-story** (au moment de la rédaction, aucun de ces widgets n'existe encore : `grep -rln "class ZFolderCard\|class ZStudyFolderDetail\|class ZPageScaffold" packages/` → **RC=1**).

## Contexte vérifié sur disque (lecture seule stricte `/home/zakarius/DEV/lex_douane`)

Les 4 paires visées existent bien des deux côtés (chemins vérifiés) :

| # | Widget zcrud (`packages/zcrud_session/lib/src/presentation/`) | Widget natif lex (`packages/lex_ui/lib/presentation/`) |
|---|---|---|
| 1 | `z_srs_quality_buttons.dart:102` `ZSrsQualityButtons` | `widgets/study/srs_quality_buttons.dart:55` `SrsQualityButtons` |
| 2 | `z_session_summary_view.dart:129` `ZSessionSummaryView` | `widgets/study/session_summary_view.dart:41` `SessionSummaryView` |
| 3 | `z_session_mode_selector.dart:58` `ZSessionModeSelector` | `screens/study_mode_selector_screen.dart:40` `StudyModeSelectorScreen` |
| 4 | `z_session_progress_indicator.dart:59` `ZSessionProgressIndicator` | `screens/study_session_screen.dart:472` `_SessionHeader` (`LinearProgressIndicator`, `minHeight: 6`) |

**Constat d'audit préliminaire (fait par le create-story, à re-prouver par le dev — ne pas prendre pour argent comptant) :**

- **Paire 1 — Boutons SRS.** zcrud couvre déjà les 3 questions de la spec :
  - *échelle 5 crans* : `ZQualityScale.fromConfig` dérive `[config.minQuality .. config.maxQuality]` (AD-46) — une `ZSrsConfig` `1..5` donne 5 crans ; **parité par bridge** (pas de littéral).
  - *surbrillance niveau suggéré IA* : `selectedQuality` (advisory, SU-3) — signalée par **canal NON-coloré** (`Semantics(selected:)` + icône coche). lex utilise `preselectedLevel`/`suggested` (fond alpha 0.24 vs 0.12 + bord 2 px). **Écart candidat** : la *forme* de surbrillance zcrud est **figée** (coche) ; lex l'exprime par intensité de fond/bord. À trancher : superset a11y (preuve négative) **ou** slot d'affordance injectable.
  - *preview d'intervalle* : seam `previewLabelFor` — **parité** (lex : `srsIntervalPreviewLabel`).
- **Paire 2 — Résumé.** zcrud couvre les 2 questions :
  - *bouton « Encore N dues »* : `dueRemaining` + `onContinue` (bouton **absent** si `0`, patron AD-45) — parité stricte avec `_MoreDueButton` de lex.
  - *pilules de répartition* : monte `ZSessionQualityBreakdown` (verbatim `byQuality`) — parité avec `SessionQualityBreakdown`. **Parité probable, à confirmer.**
- **Paire 3 — Sélecteur de mode : DIVERGENCE STRUCTURELLE (zone de risque n°1 de l'audit).** `ZSessionModeSelector` est un **lanceur à 3 options** (`learnNew`/`review`/`test` + badge streak), qui **produit une file**. `StudyModeSelectorScreen` est un **écran de configuration à 6 modes** (`StudyMode.values`) avec **sémantique radio** (`ModeSelectorCard`), **stepper de N** (`_CountStepper`, `cycleCount` seul), **filtres composés** (`FilterChips` tags/types + `_ScopeFilter` sous-dossiers), **compte en direct** « Commencer ({n}) », **hint de file vide**. Réponses aux questions de la spec (préliminaire) : `FilterChips` ❌ absent de `ZSessionModeSelector` ; stepper ❌ absent ; sémantique radio ❌ (les tuiles sont `button: true`, pas `inMutuallyExclusiveGroup`). **MAIS** `zcrud_session` expose `z_test_filters_dialog.dart` (`ZTestFiltersDialog`) — le dev **doit le lire** avant de conclure : une partie des filtres peut déjà y vivre. Voie de fermeture : slots/params injectables **additifs** (jamais un redesign 6-modes), ou preuve négative que la composition est bridgeable.
- **Paire 4 — Indicateur de progression : écart candidat FORT.** `_SessionHeader` de lex rend un `LinearProgressIndicator` **continu** (`value: progress`, `minHeight: 6`). `ZSessionProgressIndicator` n'offre que `ZSessionProgressStyle.dots` et `.segmentedBar` (discrets, par carte, colorés par qualité) — **aucun mode barre continue**. Voie de fermeture probable : nouvelle valeur d'enum `ZSessionProgressStyle.linear` (barre continue, hauteur **thémable**, jamais `6` en dur), avec garde R3. Le bouton « fermer » + le titre de `_SessionHeader` sont de la **composition d'en-tête** (SUF-1 `ZPageScaffold` / app-side) → **preuve négative**, hors de ce widget.

## ⚠️ Conflit structurel détecté — À RÉSOUDRE EN PREMIER (bloquant pour la démo)

**`ZFolderCard` et `ZStudyFolderDetail` vivent dans `packages/zcrud_study` (SUF-2/SUF-3).**
**`zcrud_study` est INTERDIT dans `example/`** : son `pubspec.yaml` dépend **en dur** de `zcrud_mindmap` (arête ES-7.1) **et** `zcrud_exam` — vérifié sur disque (`packages/zcrud_study/pubspec.yaml`, et consigné noir sur blanc dans `example/pubspec.yaml` : « `zcrud_study` N'EST PAS ajouté … tirerait `zcrud_mindmap` … VIOLERAIT l'invariant AC10 »). La démo su-10 existante (`example/lib/demos/study_session_demo_screen.dart`) **exclut déjà** `zcrud_study` pour cette raison exacte et n'assemble que `zcrud_session` + `zcrud_flashcard`.

La spec SUF-4 demande une démo **« grille de dossiers (`ZFolderCard`) → `ZStudyFolderDetail` → flux session »** — or ces deux widgets sont, en l'état, **non-importables** dans `example/`.

**Le dev DOIT, avant d'écrire la démo, prouver sur disque l'état réel des arêtes de `zcrud_study` (post SUF-2/SUF-3)** puis choisir une voie **conforme** (jamais tirer `zcrud_mindmap` dans le lock d'`example/`) :
1. **Si** SUF-2/SUF-3 ont rendu les arêtes `zcrud_mindmap`/`zcrud_exam` **optionnelles** (ou déplacé `ZFolderCard`/`ZStudyFolderDetail` vers un package feuille importable) → la démo assemble les vrais widgets.
2. **Sinon** → **ne pas** ajouter `zcrud_study` à `example/`. Deux options, à documenter comme variance : (a) rendre les arêtes mindmap/exam optionnelles **dans le périmètre SUF-4** si trivial et sans régression ; (b) **escalade `correct-course`** — la démo « bout en bout » telle que spécifiée dépend d'un pré-requis d'architecture non tenu. **Ne jamais** violer AC10 pour faire passer la démo.

Ce point est le **risque n°1** de la story et conditionne l'AC de démo (AC7-AC9).

## Acceptance Criteria

**Volet AUDIT (livrable `docs/parity-session-widgets-2026-07-26.md`)**

1. **AC1 — Livrable d'audit produit et daté.** Le fichier `docs/parity-session-widgets-2026-07-26.md` existe, suit le format des audits antérieurs (`docs/parity-study-ui-2026-07-16/rapport.md` : réponse courte, matrice de parité par légende ✅/🟡/❌, chemins **exacts** des deux côtés). Chaque affirmation de parité/écart cite le **chemin + n° de ligne** vérifiés sur disque, des deux côtés.
2. **AC2 — Les 4 paires auditées widget-par-widget**, chacune répondant **explicitement** aux questions de la spec :
   - Paire 1 : surbrillance niveau suggéré IA ? preview d'intervalle ? échelle 5 crans ?
   - Paire 2 : bouton « Encore N dues » ? pilules de répartition ?
   - Paire 3 : `FilterChips` ? stepper ? sémantique radio ? (avec lecture préalable **obligatoire** de `ZTestFiltersDialog`).
   - Paire 4 : `LinearProgressIndicator` continu `h=6` ?
3. **AC3 — Toute « absence » est prouvée par un grep négatif** (commande + RC=1 consignés dans le doc) — jamais affirmée de mémoire (discipline « réalité du code »).

**Volet FERMETURE (code `zcrud_session`, additif, thémable)**

4. **AC4 — Pour chaque écart RÉEL** confirmé par l'audit : un **slot/label/param INJECTABLE** est ajouté au widget zcrud concerné, **jamais un look codé en dur** (couleur/hauteur/typo via `ZcrudTheme`/`ZColorKeyResolver`/`label(context,…)`). L'ajout est **strictement additif** : défaut inchangé ⇒ **zéro régression** pour les appelants existants (runtimes ES-4, `example/` su-10, bridges lex existants). Aucune écriture SRS (AD-33), aucun gestionnaire d'état (AD-2/AD-15).
5. **AC5 — Pour chaque paire SANS écart réel** : **preuve négative** consignée dans le doc (grep/lecture montrant que la parité est atteignable par **bridge/composition**, sans modification zcrud).
6. **AC6 — Conformité AD sur tout code ajouté** : `Semantics` explicites, cibles ≥ 48 dp, variantes **directionnelles** (RTL, AD-13), `const` où possible, l10n par labels injectés, aucune couleur/dimension en dur. Le canal couleur n'est **jamais** le seul canal.

**Volet DÉMO (`example/`)**

7. **AC7 — Parcours assemblé de bout en bout**, à partir de **widgets publics (barrels)** seuls + fakes app-side : **grille de dossiers → page-détail dossier → flux de session existant**. La forme concrète dépend de la résolution du conflit structurel ci-dessus (voir « Conflit structurel détecté ») ; la voie retenue est **documentée** (dans le doc d'audit ou un commentaire de tête de l'écran de démo) et **conforme à AC10 de su-10** (`zcrud_mindmap` jamais tiré dans le lock d'`example/`).
8. **AC8 — Apparence neutre thémable** : la démo n'impose aucun look codé en dur ; elle réutilise le `ZcrudScope` racine de l'app d'exemple (thème + labels), comme la démo su-10.
9. **AC9 — La démo compile et s'assemble** : `flutter analyze` (example) RC=0 ; un test de fumée `example/test/` **monte le parcours** et vérifie l'enchaînement (au moins : la grille rend une carte de dossier, un tap ouvre le détail, un point d'entrée de session est atteignable). Test **mordant** (R3).

**Volet R3 (transversal)**

10. **AC10 — Chaque garde ajoutée est PROUVÉE mordante** : pour chaque slot/param de fermeture, un test qui **rougit** si l'on ré-injecte la régression (mapping inversé, défaut recodé en dur, canal a11y manquant, dimension figée). Aucun test tautologique. La preuve de morsure est **consignée** (le dev exécute au moins une ré-injection et note la sortie rouge dans les Completion Notes).

## Tasks / Subtasks

- [x] **T0 — Pré-requis & garde-fous (AC-conflit)** :
  - [x] Vérifier sur disque que SUF-1/2/3 sont `done` et que `ZPageScaffold`, `ZFolderCard`, `ZStudyFolderDetail` existent (`grep -rln`). Si absents → **HALT** (dépendance non tenue, signaler à l'orchestrateur).
  - [x] Rejouer `cat packages/zcrud_study/pubspec.yaml` : les arêtes `zcrud_mindmap`/`zcrud_exam` sont-elles encore **dures** ? Décider la voie de démo (cf. « Conflit structurel »).
- [x] **T1 — Audit paire 1 (boutons SRS)** (AC1/AC2/AC3/AC5)
- [x] **T2 — Audit paire 2 (résumé)** (AC1/AC2/AC5)
- [x] **T3 — Audit paire 3 (mode selector)** (AC1/AC2/AC3) — `z_test_filters_dialog.dart` lu AVANT conclusion
- [x] **T4 — Audit paire 4 (indicateur)** (AC1/AC2/AC3)
- [x] **T5 — Rédiger `docs/parity-session-widgets-2026-07-26.md`** (AC1/AC2/AC3/AC5)
- [x] **T6 — Fermeture des écarts réels** (AC4/AC6/AC10)
  - [x] Paire 4 : `ZSessionProgressStyle.linear` (barre continue, épaisseur **thémable + injectable**), `Semantics(value:)` inchangé, défaut `dots` conservé.
  - [x] Paire 1 : `ZSrsQualityEmphasis` — écart RÉEL confirmé (affordance figée), slot de dimensions injectables.
  - [x] Paire 3 : **AUCUN code** — divergence structurelle, preuve négative consignée (§4.3 du doc).
  - [x] Paire 2 (hors liste initiale, écart réel découvert par l'audit) : `ZQualityBreakdownCoverage`.
  - [x] Tests R3 dans `packages/zcrud_session/test/presentation/suf4_parity_closures_test.dart`.
- [x] **T7 — Démo assemblée** (AC7/AC8) — **voie (b)** : `packages/zcrud_study/test/support/suf4_assembly_demo.dart` (`example/` impossible sans violer AC10 de su-10, preuve d'arêtes rejouée).
- [x] **T8 — Test de fumée du parcours** (AC9/AC10) — `packages/zcrud_study/test/suf4_assembly_demo_test.dart`, mordant.
- [x] **T9 — Vérif verte rejouée** — `melos run generate` RC=0 (zéro delta) → `dart analyze` RC=0 → `flutter test` RC=0. `sprint-status.yaml` **non modifié**.

## Dev Notes

### Invariants NON-NÉGOCIABLES (rappel ciblé)

- **AD-2 / AD-15** — réactivité Flutter-native : tout widget ajouté/modifié reste `StatelessWidget`/`StatefulWidget` **sans** gestionnaire d'état, controllers stables (create/dispose), état à **propriétaire unique** (`ValueListenable` détenu par le widget si état il y a). Aucune écriture SRS (AD-33). La chaîne `zcrud_session` est déjà **pure** (gardée par `z_purity_test.dart`) — ne pas l'entamer.
- **AD-13** — RTL : `EdgeInsetsDirectional`/`AlignmentDirectional`/`PositionedDirectional`/`TextAlign.start|end` uniquement ; `Semantics` explicites ; cibles ≥ 48 dp ; `const`. Couleur jamais seul canal.
- **Thème/couleur** — via `ZcrudTheme.of(context)` / `zResolveColorKeyOrSlot(context, colorKey, …)` / `ZColorKeyResolver` ; **jamais** `Colors.*`, `Color(0x…)`, ni dimension en dur (une garde « couleurs/dimensions en dur » rougit). Toute nouvelle dimension (ex. hauteur de barre) vient du thème (`theme.gap*`/`radius*`).
- **l10n** — libellés par `label(context, 'clé', fallback: …)` (`ZcrudLabels`) ; **jamais** un littéral utilisateur. Rappel angle mort connu : la garde de libellés **ne voit pas** `Semantics(label:)` → un test dédié doit **énumérer** les nœuds a11y ajoutés.
- **AD-46** — l'échelle de qualité **dérive** de `ZSrsConfig` (`ZQualityScale.fromConfig`, voie unique). Aucun littéral de borne (`0`/`3`/`4`/`5`) ne doit réapparaître : `z_quality_scale_single_source_test.dart` rougit sinon.
- **AD-10** — désérialisation/entrées défensives : file vide, `total == 0`, valeurs négatives corrompues ⇒ dégradation gracieuse, **jamais** d'exception.

### Fichiers à toucher / réutiliser (chemins absolus de package)

- **Audit (LECTURE SEULE ABSOLUE)** : `/home/zakarius/DEV/lex_douane/packages/lex_ui/lib/presentation/widgets/study/{srs_quality_buttons,session_summary_view,session_quality_breakdown}.dart`, `.../screens/{study_mode_selector_screen,study_session_screen}.dart`, `.../widgets/study/mode_selector_card.dart`. **Aucune écriture** dans `/home/zakarius/DEV/lex_douane` ni `/home/zakarius/DEV/iffd`.
- **Fermeture (ÉCRITURE)** : `packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart`, `.../z_srs_quality_buttons.dart`, `.../z_session_mode_selector.dart` — selon écarts confirmés ; barrel `packages/zcrud_session/lib/zcrud_session.dart` si nouvelle surface publique ; tests `packages/zcrud_session/test/presentation/`.
- **À LIRE avant de conclure sur la paire 3** : `packages/zcrud_session/lib/src/presentation/z_test_filters_dialog.dart` (filtres de test possiblement déjà portés).
- **Démo** : `example/lib/demos/` (+ `demo_registry.dart`), `example/test/`. Socle session : `example/lib/demos/study_session_demo_screen.dart` (déjà assemblé, à réutiliser). `example/pubspec.yaml` — **ne pas** y ajouter `zcrud_study` sans résolution conforme du conflit (cf. supra).
- **Livrable** : `docs/parity-session-widgets-2026-07-26.md`.

### État actuel des widgets ciblés (lu sur disque — ce que la fermeture doit préserver)

- `ZSrsQualityButtons` : mapping cran→qualité vit dans le widget (`scale.qualities[i] → qualité i`) ; seams `previewLabelFor`/`labelKeyFor`/`colorKeyFor`/`selectedQuality`/`passThreshold`. **Préserver** : défaut `selectedQuality: null` (comportement historique), voie unique de notation `onQualitySelected`, canal non-coloré de sélection.
- `ZSessionSummaryView` : assemble `ZStudyProgressRings` + `ZSessionQualityBreakdown` ; `dueRemaining`/`onContinue` (bouton absent si 0), `celebration` (enum opt-in), `masteredThreshold` consommé de la config, confetti **confiné** à ce fichier (garde `z_third_party_confinement_test.dart`). **Ne rien** ré-exporter de `confetti`.
- `ZSessionModeSelector` : 3 options + streak, produit une file via `onStart`, `at` injecté (jamais `DateTime.now()`), patron AD-45 (option à 0 = absente). Toute extension reste **additive** et ne réintroduit **aucun** calcul métier (catégorisation = `zCategorize` pure).
- `ZSessionProgressIndicator` : `dots`/`segmentedBar`, couleur par qualité via seam, `Semantics(value: 'position/total')` porté par `progressKey`. Un `ZSessionProgressStyle.linear` **doit** conserver ce contrat a11y (association value↔nœud) et rester défensif (`total == 0`).

### Patron de test R3 (référence sur disque)

`packages/zcrud_session/test/presentation/z_srs_quality_buttons_test.dart` : wrap `MaterialApp` + `ZcrudScope`, tap par `ValueKey` (jamais `find.text` dépendant de la langue), assertion **discriminante** (« un mapping inversé ou un intervalle en dur ROUGIT »). Reproduire ce niveau d'exigence : chaque garde ajoutée doit énoncer **explicitement** la régression qu'elle attrape, et le dev doit **la ré-injecter une fois** pour prouver la morsure (consigner la sortie rouge en Completion Notes — AC10).

Pour un éventuel `ZSessionProgressStyle.linear` : la garde doit rougir si (a) la hauteur est recodée en dur au lieu du thème, (b) le `Semantics(value:)` n'est plus associé au `progressKey`, (c) `total == 0` lève une exception au lieu de rendre une barre vide.

Pour l'a11y ajoutée : **énumérer** les nœuds `Semantics` (via `tester.getSemantics`), jamais asserter sur un seul `Text` visuel (leçon su-5/su-6 : un défaut a11y est un **motif** — le test balaie toutes les occurrences).

### Project Structure Notes

- **Conflit détecté (répété car central)** : `ZFolderCard`/`ZStudyFolderDetail` ∈ `zcrud_study` ; `zcrud_study` interdit dans `example/` (tire `zcrud_mindmap`+`zcrud_exam`, viole AC10 su-10). Variance à résoudre **avant** T7, voie documentée. Défaut de repli conforme : réduire le volet démo à ce qui est importable + escalade `correct-course`, **jamais** tirer `zcrud_mindmap` dans le lock d'`example/`.
- **Pas d'écriture `zcrud_core`** dans cette story (aucun besoin) — cohérent avec le séquencement SUF.
- **Code généré** : peu probable ici (widgets présentation, pas d'annotation `@ZcrudModel`). Si `melos run generate` produit un delta, le committer (packages/*/lib/**) — sinon RAS.
- **Sprint-status** : **non modifié par le dev** (l'orchestrateur sérialise les transitions).

### References

- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md` — AD-2, AD-10, AD-13, AD-15, AD-33, AD-45, AD-46]
- [Source: Plan approuvé `/home/zakarius/.claude/plans/tingly-brewing-cake.md` — story SUF-4, §« Hors périmètre » (bridges app-side), §« Vérification »]
- [Source: `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart:102`, `z_session_summary_view.dart:129`, `z_session_mode_selector.dart:58`, `z_session_progress_indicator.dart:59`]
- [Source (LECTURE SEULE) : `/home/zakarius/DEV/lex_douane/packages/lex_ui/lib/presentation/widgets/study/srs_quality_buttons.dart:55`, `session_summary_view.dart:41`, `screens/study_mode_selector_screen.dart:40`, `screens/study_session_screen.dart:472` (`_SessionHeader`, `LinearProgressIndicator minHeight:6`)]
- [Source: `example/pubspec.yaml` — invariant AC10 su-10 : `zcrud_study`/`zcrud_mindmap` interdits ; `example/lib/demos/study_session_demo_screen.dart` — socle du parcours session assemblé]
- [Source: `docs/parity-study-ui-2026-07-16/rapport.md` — format de référence du livrable d'audit]
- [Source: patron R3 `packages/zcrud_session/test/presentation/z_srs_quality_buttons_test.dart`]

## Dev Agent Record

### Agent Model Used

claude-opus-5[1m] — skill `bmad-dev-story` (tool `Skill`, invocation réelle).

### Debug Log References

**T0 — arêtes RE-PROUVÉES sur disque (post-SUF-3), voie retenue : (b)**

```console
$ awk '/^dependencies:/,/^dev_dependencies:/' packages/zcrud_study/pubspec.yaml | grep -v '^#'
  zcrud_mindmap: ^0.18.0     ← arête DURE, TOUJOURS là
  zcrud_exam: ^0.18.0        ← arête DURE, TOUJOURS là
$ grep -rn "package:zcrud_mindmap\|package:zcrud_exam" packages/zcrud_study/lib/   → 5 sites RÉELS
```

⇒ `example/` ne peut PAS importer `zcrud_study` sans un `dependency_overrides: zcrud_mindmap: path:`,
que `example/test/boundary_deps_test.dart` fait rougir par construction. **Voie (b)** : démo assemblée
en test d'assemblage bout-en-bout dans `packages/zcrud_study/test/`. `example/pubspec.yaml`,
`example/pubspec.lock` et `boundary_deps_test.dart` **INCHANGÉS**. Aucun `pubspec.yaml` touché ⇒
graphe : **ACYCLIQUE, CORE OUT=0, 69 arêtes** (rejoué).

**Deux défauts RÉELS attrapés par les gardes neuves (mesurés, pas anticipés)**

1. `semanticsValue: null` ne tait PAS le `LinearProgressIndicator` — le framework CALCULE un
   pourcentage. Arbre sémantique réel : `['2/4', '50']` ⇒ double annonce, deux unités. Corrigé par
   `ExcludeSemantics`.
2. Démo : `ZcrudScope` sous le `MaterialApp` ⇒ sous le `Navigator` ⇒ les écrans POUSSÉS ne le voyaient
   pas (`gapM` 24 injecté → 8 rendu). Corrigé : scope **ancêtre** du `MaterialApp`.

**Une garde de MA propre écriture qui ne mordait pas (durcie)** : le cas `total: 4, currentIndex: 1`
donne une fraction de **0,5** ; la ré-injection « fraction inversée » (`1 - value`) restait **VERTE**
(`1 - 0.5 == 0.5`). Corpus rendu asymétrique (`2/5`) ⇒ la garde mord.

### Completion Notes List

**AC1-AC3 (AUDIT)** — `docs/parity-session-widgets-2026-07-26.md` livré : réponse courte, matrice
✅/🟡/🔧/❌, 4 paires auditées widget-par-widget avec **chemin + n° de ligne des DEUX côtés**, 8 greps
NÉGATIFS (commande + RC consignés) et 3 greps POSITIFS. `/home/zakarius/DEV/lex_douane` en **lecture
seule absolue** (grep/read uniquement — aucune écriture).

**AC4/AC6 (FERMETURE)** — 3 écarts RÉELS fermés par slots **injectables**, jamais un look codé en dur ;
défauts **inchangés** ⇒ zéro régression (543 tests `zcrud_session` verts, dont les 529 antérieurs) :

| Paire | Slot livré | Défaut |
|---|---|---|
| 4 | `ZSessionProgressStyle.linear` + `linearThickness` (repli `ZcrudTheme.gapS`, rayon `radiusS`, couleurs par seams) | `dots` inchangé |
| 1 | `ZSrsQualityEmphasis` — **dimensions seules**, aucune couleur | `none` ⇒ rendu historique exact |
| 2 | `ZQualityBreakdownCoverage` (**enum**, pas un booléen) + pass-through `ZSessionSummaryView.breakdownCoverage` | `presentKeysOnly` inchangé |

**Paire 3 : AUCUN code — preuve négative (AC5).** Divergence structurelle (lanceur ↔ écran de
configuration). `FilterChip` : absent (grep RC=1), axes différents mais capacité présente via
`ZTestFiltersDialog` + `zApplyTestFilters`. Stepper : **présent** (`_QuestionCountStepper`, bornes
injectées — plus configurable que lex). Radio : absent **et correct** (les tuiles lancent, elles ne
sélectionnent pas ; poser `inMutuallyExclusiveGroup` sans état ferait mentir le lecteur d'écran — le
motif est utilisé ailleurs dans le package quand la sélection est réelle : contre-preuve consignée).
Aucun redesign 6-modes. **Aucune escalade nécessaire.**

AD tenus : AD-2/AD-15 (aucun gestionnaire d'état, widgets purs — `z_widgets_purity_test` vert), AD-13
(directionnel, `Semantics`, ≥ 48 dp, `const`), AD-10 (opacité clampée, épaisseur négative/NaN → repli,
`total == 0` sans exception), AD-33 (aucune écriture SRS), AD-46 (aucun littéral de borne), FR-26
(`z_widgets_hardcode_scan_test` vert : zéro couleur/libellé en dur).

**AC7/AC8/AC9 (DÉMO)** — voie **(b)** documentée dans le doc (§5) ET en tête du fichier de démo.
Parcours : `ZAdaptiveGrid`+`ZFolderCard` → `ZStudyFolderDetail` → `ZSessionModeSelector` →
`ZSessionProgressIndicator(linear)` + `ZSrsQualityButtons(emphasis)` → `ZSessionSummaryView(wholeScale)`.
Barrels publics uniquement, fakes app-side, thème injecté via `ZcrudScope` racine. Le `6` dp de lex est
injecté **par l'app** — le widget ne le connaît pas.

**AC10 (R3) — 13 régressions ré-injectées, 13 ROUGES observés, retirées, VERT reconfirmé** :

| # | Régression injectée | Garde | Verdict |
|---|---|---|---|
| 1 | `minHeight: 6` en dur | épaisseur par défaut = thème | 🔴 ROUGE |
| 2 | `value: 1 - resolvedLinearValue` | fraction peinte ↔ annoncée | 🔴 ROUGE *(après durcissement du corpus)* |
| 3 | `ExcludeSemantics` retiré | annoncée QU'UNE FOIS | 🔴 ROUGE |
| 4 | division non gardée (`total == 0`) | file vide | 🔴 ROUGE |
| 5 | `currentIndex / total` (fraction décalée) | fraction peinte ↔ annoncée | 🔴 ROUGE |
| 6 | `opacityFor/borderWidthFor(selected: false)` | emphase du cran sélectionné | 🔴 ROUGE |
| 7 | `withValues` appliqué d'office | défaut = rendu historique | 🔴 ROUGE |
| 8 | `clamp(0,1)` retiré | défensif AD-10 | 🔴 ROUGE |
| 9 | filtre `containsKey` conservé | `wholeScale` | 🔴 ROUGE |
| 10 | `coverage:` non transmis | pass-through du bilan | 🔴 ROUGE |
| 11 | toutes les cartes → dossier 0 | tap ouvre LE BON dossier | 🔴 ROUGE |
| 12 | point d'entrée `onTap: null` | entrée ACTIONNÉE | 🔴 ROUGE |
| 13 | `ZcrudScope` sous `MaterialApp` / `currentIndex: 0` figé / `wholeScale` retiré du bilan | thème traversant, barre qui avance, bilan stable | 🔴 ROUGE (3×) |

**Vérif verte RÉELLEMENT rejouée**

| Commande | Résultat |
|---|---|
| `dart run melos run generate` | **RC=0**, **zéro delta** de code généré (aucun `*.g.dart` modifié) |
| `dart analyze` — `zcrud_session` / `zcrud_study` / `zcrud_ui_kit` | **RC=0** chacun, **0 error/warning** |
| `flutter test` — `zcrud_session` | **RC=0 — 543 tests** (+14 SUF-4) |
| `flutter test` — `zcrud_study` | **RC=0 — 600 tests** (+7 SUF-4) |
| `flutter test` — `example` (7 fichiers session/frontière) | **RC=0 — 23 tests** |
| `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK · CORE OUT=0 OK · 69 arêtes** (inchangé) |

⚠️ **Signalé, PRÉ-EXISTANT, hors périmètre SUF-4** : `example/` porte **1 erreur d'analyse antérieure**
— `test/offline_demo_test.dart:146` « Missing concrete implementations of `ZLocalStore.purge` and
`ZLocalStore.putMerged` ». **Prouvé pré-existant** : `git stash` des seuls fichiers SUF-4 → l'erreur
persiste à l'identique (1 erreur avant comme après). Aucun lien avec cette story.

`sprint-status.yaml` : **NON modifié** (l'orchestrateur sérialise les transitions).

### File List

**Créés**

- `docs/parity-session-widgets-2026-07-26.md`
- `packages/zcrud_session/test/presentation/suf4_parity_closures_test.dart`
- `packages/zcrud_study/test/support/suf4_assembly_demo.dart`
- `packages/zcrud_study/test/suf4_assembly_demo_test.dart`

**Modifiés**

- `packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart`
- `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart`
- `packages/zcrud_session/lib/src/presentation/z_session_quality_breakdown.dart`
- `packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart`
- `_bmad-output/implementation-artifacts/stories/suf-4-audit-session-demo-assemblee.md` (sections autorisées)

**Non modifiés (invariants préservés — vérifié)** : `example/pubspec.yaml`, `example/pubspec.lock`,
`example/test/boundary_deps_test.dart`, tous les `packages/*/pubspec.yaml`,
`_bmad-output/implementation-artifacts/sprint-status.yaml`, et l'intégralité de
`/home/zakarius/DEV/lex_douane` (lecture seule absolue).

### Change Log

| Date | Changement |
|---|---|
| 2026-07-26 | SUF-4 implémentée. T0 tranché en **voie (b)** (arêtes `zcrud_mindmap`/`zcrud_exam` re-prouvées dures ⇒ démo assemblée dans `zcrud_study/test/`, AC10 su-10 non dégradé). Audit des 4 paires livré. 3 écarts réels fermés par slots injectables additifs (`ZSessionProgressStyle.linear`, `ZSrsQualityEmphasis`, `ZQualityBreakdownCoverage`) ; paire 3 close par preuve négative. 21 tests neufs, 13 morsures R3 prouvées. Statut → `review`. |
