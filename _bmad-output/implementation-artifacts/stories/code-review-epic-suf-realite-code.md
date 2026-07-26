# Code-review epic SUF — lentille « Réalité du code »

> **Date** : 2026-07-26 · **Périmètre** : SUF-1..SUF-4 (diff consolidé) · **Mode** : LECTURE SEULE
> (aucun fichier de `lib/` ni de `test/` modifié par cette revue).
> **Hors périmètre, non revu** : `packages/zcrud_markdown/`.
> **Discipline** : chaque affirmation ci-dessous est accompagnée de la commande rejouée et de son RC.
> Une « absence » n'est jamais affirmée de mémoire.

**Verdict global : RÉSERVES.** Le doc d'audit `docs/parity-session-widgets-2026-07-26.md` est d'une
fidélité **inhabituellement élevée** : les 8 greps négatifs et les 3 greps positifs sont **tous
rejouables à l'identique** (RC conformes), et **la totalité** des n° de ligne cités côté
`/home/zakarius/DEV/lex_douane` **et** côté `zcrud` tombe juste. La voie (b) du T0 n'a **dégradé aucune
contrainte** : `example/pubspec.yaml` et `example/test/boundary_deps_test.dart` sont inchangés au
`git diff`. La conclusion « preuve négative » de la paire 3 **tient** : l'écart n'est pas enterré.

Les réserves portent sur **trois chiffres/affirmations** qui ne résistent pas au rejeu :

1. le nombre de tests neufs annoncé par SUF-2 (**14+1** annoncés, **17** réels) ;
2. l'affirmation « **aucun `pubspec.yaml` n'a bougé** … le graphe reste **69 arêtes** » (§5.2 du doc) —
   le diff de l'epic fait passer le graphe de **68 → 69** via `packages/zcrud_study/pubspec.yaml` ;
3. `flutter analyze` sur `example/` est **RC=1** (et non RC=0 comme l'exige AC9 de SUF-4), dont **une
   info nouvellement introduite** par la correction de l'orchestrateur.

Aucune de ces réserves n'invalide un invariant AD : le graphe est bien **ACYCLIQUE / CORE OUT=0**, et
toutes les suites de test rejouées sont **vertes**.

---

## 1. Rejeu intégral des 8 preuves NÉGATIVES du doc d'audit (§3)

Toutes lancées depuis `/home/zakarius/DEV/zcrud`. **8/8 conformes** (RC=1 annoncé, RC=1 obtenu).

| Preuve | Commande rejouée | RC annoncé | RC obtenu | Verdict |
|---|---|---|---|---|
| P4-1 | `git show HEAD:packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart \| grep -n "LinearProgressIndicator"` | 1 | **1** | ✅ |
| P4-2 | `git show HEAD:…/z_session_progress_indicator.dart \| grep -nE "^\s+(linear\|continuous),"` | 1 | **1** | ✅ |
| P4-3 | `grep -rn "Icons.close\|closeButtonTooltip" packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart` | 1 | **1** | ✅ |
| P3-1 | `grep -rn "FilterChip" packages/zcrud_session/lib/` | 1 | **1** | ✅ |
| P3-2 | `grep -n "inMutuallyExclusiveGroup\|selected:" …/z_session_mode_selector.dart` | 1 | **1** | ✅ |
| P3-3 | `grep -n "Stepper\|Increment\|increment" …/z_session_mode_selector.dart` | 1 | **1** | ✅ |
| P1-1 | `git show HEAD:…/z_srs_quality_buttons.dart \| grep -nE "BorderSide\|withValues\|Border\.all"` | 1 | **1** | ✅ |
| P1-3 | `grep -nE "minQuality = [0-9]\|maxQuality = [0-9]\|qualities = <int>\[0" …/z_srs_quality_buttons.dart` | 1 | **1** | ✅ |

**Durcissement de P3-2 fait par cette revue** (le doc ne l'avait pas fait) : le grep du doc cherche
`selected:` avec les deux-points. J'ai rejoué la forme **large** pour écarter un contournement
orthographique :

```console
$ grep -n "selected" packages/zcrud_session/lib/src/presentation/z_session_mode_selector.dart
RC=1
```

⇒ **aucune** occurrence de la racine « selected » sous quelque forme que ce soit. L'absence est donc
plus forte que ce que le doc prétend, pas plus faible.

**Contre-preuve P3-2 vérifiée** : `packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart:1081`
porte bien `inMutuallyExclusiveGroup: single` (lu sur disque). Le motif est donc connu et employé
ailleurs dans le même package — l'absence dans le mode-selector est bien un **choix**, pas un oubli.

**Ancrage de `button: true`** : `z_session_mode_selector.dart:254` = `button: true` (le doc cite `:254`).
✅ exact.

## 2. Rejeu des 3 preuves POSITIVES (§3) — RC conformes, **mais sorties tronquées**

| Preuve | RC annoncé | RC obtenu | Lignes montrées par le doc | Lignes réellement retournées |
|---|---|---|---|---|
| P3-4 (`_QuestionCountStepper`) | 0 | **0** | 97, 177, 274 (3) | 97, 177, 274, **275, 325** (5) |
| P2-1 (`dueRemaining\|showContinue`) | 0 | **0** | 180, 536 (2) | **136, 154,** 180, **533,** 536, **542, 556** (7) |
| P2-2 (`containsKey` sur HEAD) | 0 | **0** | 77 (1) | 77, **136** (2) |

Les **RC** et les **conclusions** sont justes ; c'est la **restitution** qui est éditée sans marqueur
d'élision (`…`). Dans un document dont la thèse est « commande + RC consignés, verbatim », c'est un
écart de forme qui affaiblit la valeur probante de blocs `console` par ailleurs corrects. → **F3 (LOW)**.

## 3. Vérification des n° de ligne — côté `lex_douane` (source canonique)

Toutes vérifiées par `sed -n` sur `/home/zakarius/DEV/lex_douane`. **Aucune erreur.**

- `packages/lex_ui/lib/presentation/widgets/study/srs_quality_buttons.dart` — `:26` `String srsIntervalPreviewLabel({` ✅ · `:55` `class SrsQualityButtons extends ConsumerWidget` ✅ · `:83` `static Color _colorFor(Sm2QualityLevel level)` ✅ · `:98` `static String _labelFor(…)` ✅ · `:116` `String _intervalLabel(` ✅ · `:134` `for (final level in Sm2QualityLevel.values)` ✅ · `:146` `suggested: preselectedLevel == level,` ✅ · `:151` `return LayoutBuilder(` ✅ · `:211` `selected: suggested,` ✅ · `:214` `color: color.withValues(alpha: suggested ? 0.24 : 0.12),` ✅ · `:220` `constraints: const BoxConstraints(minHeight: 48),` ✅ · `:227` `border: Border.all(color: color, width: suggested ? 2 : 1),` ✅
- `…/session_summary_view.dart` — `:41` `class SessionSummaryView extends ConsumerStatefulWidget` ✅ · `:81` `final controller = ConfettiController(` ✅ · `:153` `SessionQualityBreakdown(` ✅ · `:209` `class _MoreDueButton extends ConsumerWidget` ✅ · `:218` `if (n <= 0) return const SizedBox.shrink();` ✅
- `…/session_quality_breakdown.dart` — `:24` dartdoc « un niveau à 0 reste affiché pour une répartition… » ✅ · `:26` `class SessionQualityBreakdown extends ConsumerWidget` ✅ · `:71` `for (final level in Sm2QualityLevel.values)` ✅ · `:78` `count: histogram[level] ?? 0,` ✅
- `…/mode_selector_card.dart:49` `inMutuallyExclusiveGroup: true,` ✅
- `…/screens/study_session_screen.dart` — `:472` `class _SessionHeader extends ConsumerWidget` ✅ · `:495` `icon: const Icon(Icons.close_rounded),` ✅ · `:501` `l10n.sessionProgress(completed, total),` ✅ · `:511` `child: LinearProgressIndicator(` ✅ · `:513` `minHeight: 6,` ✅
- `…/screens/study_mode_selector_screen.dart` — `:40` `class StudyModeSelectorScreen extends ConsumerWidget` ✅ · `:51` `sessionMatchingCountProvider` ✅ · `:69` `for (final mode in StudyMode.values)` ✅ · `:84` `_CountStepper(` ✅ · `:97` `_ScopeFilter(` ✅ · `:106` `FlashcardTagChips(` ✅ · `:116` `_TypeFilterChips(` ✅ · `:137` `bottomNavigationBar: _StartBar(` ✅ · `:146` `int _effectiveCount(int? count, int maxMatching)` ✅ · `:162` `context.pushNamed('study_session', extra: launchConfig);` ✅ · `:269` `FilterChip(` ✅ · `:281` `class _CountStepper extends ConsumerWidget` ✅
- **Cardinalité « 6 modes »** vérifiée à la source :
  `packages/lex_core/lib/domain/enums/study_mode.dart` → `cycleCount, cycleAll, list, test, whiteExam, cramming` = **6**. ✅

**Lecture seule du dépôt lex_douane — vérifiée.** `git status --porcelain` sur `/home/zakarius/DEV/lex_douane`
ne montre qu'une entrée, `M scripts/generate_registry.py`, avec `git diff --stat` = **0 insertion, 0
suppression** (changement de mode seul) et `mtime = 2026-07-05 13:42` — soit **21 jours avant** l'epic
SUF. La revendication « aucune écriture » du doc est donc **exacte**.

## 4. Vérification des n° de ligne — côté `zcrud` (après fermetures)

- `z_session_progress_indicator.dart` — `:72` `linear,` ✅ · `:170` `double get resolvedLinearValue` ✅ ·
  `:177` `double resolvedLinearThickness(ZcrudTheme theme)` ✅ · `:248` `return ExcludeSemantics(` ✅
- `z_srs_quality_buttons.dart` — `:53` `ZQualityScale.fromConfig(ZSrsConfig config)` ✅ · `:195`
  `class ZSrsQualityButtons extends StatelessWidget` ✅ · `:229` `previewLabelFor` ✅ · `:254`
  `selectedQuality` ✅ · `:386` `color: fillOpacity == null` ✅ · `:394` `side: borderWidth <= 0 ? BorderSide.none` ✅.
  **Nit** : le doc situe `ZSrsQualityEmphasis` en `:120` ; la déclaration est en **`:121`** (`:120` = `@immutable`). Décalage d'une ligne, sans conséquence.
- `z_session_quality_breakdown.dart` — `:25` `enum ZQualityBreakdownCoverage {` ✅ · `:46` `wholeScale,` ✅
- `z_session_summary_view.dart` — `:160` `this.breakdownCoverage = …presentKeysOnly,` ✅ · `:204`
  `final ZQualityBreakdownCoverage breakdownCoverage;` ✅ · `:425` `coverage: widget.breakdownCoverage,` ✅
- `z_test_filters_dialog.dart` — `:177` `_QuestionCountStepper(` ✅ · `:188` `for (final level in ZMasteryLevel.values)` ✅ ·
  `:209` `for (final source in widget.availableSources)` ✅ · `:274` `class _QuestionCountStepper` ✅ ·
  `:76-78` bornes injectées (`availableSources`, `minQuestionCount = 1`, `maxQuestionCount = 100`) ✅

**Surfaces publiques réellement exportées** (le doc affirme « exposée par le barrel ») :
`packages/zcrud_session/lib/zcrud_session.dart:100,101,112,113` exportent les quatre fichiers touchés
⇒ `ZSessionProgressStyle.linear`, `ZSrsQualityEmphasis`, `ZQualityBreakdownCoverage` et
`ZSessionSummaryView.breakdownCoverage` sont **atteignables par un consommateur**. ✅

**Le « 6 » de lex n'est pas dans le package** — vérifié :

```console
$ grep -rnE "minHeight: *6|thickness: *6\b" packages/zcrud_session/lib/
packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart:58:  /// minHeight: 6)` **continu**. Ni [dots] ni [segmentedBar] ne le produisent —
RC=0
```

L'unique occurrence est **dans une dartdoc décrivant lex**, jamais du code. Et la démo l'injecte bien
**côté app** : `packages/zcrud_study/test/support/suf4_assembly_demo.dart:355` `linearThickness: 6,`. ✅

## 5. Paire 3 — la « preuve négative » tient-elle, ou l'écart est-il enterré ?

**Elle tient.** Les trois questions posées par la spec (AC2) reçoivent chacune une réponse
**reproductible**, et aucune ne masque un manque :

- *`FilterChips` ?* → absence prouvée (**P3-1, RC=1**, rejoué), et la **capacité de filtrage** invoquée
  en compensation existe vraiment : `zApplyTestFilters` est déclarée en
  `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart:220` et **exportée** par le barrel
  (`packages/zcrud_flashcard/lib/zcrud_flashcard.dart:179`). L'argument « composable par l'hôte » n'est
  donc pas une pétition de principe.
- *Stepper ?* → présence prouvée (**P3-4, RC=0**), bornes **réellement injectées** (`:76-78`, vérifiées),
  là où le `_CountStepper` de lex est borné `[1, maxMatching]` (`:146` vérifiée).
- *Sémantique radio ?* → absence prouvée (**P3-2**, et durcie par mon grep large `RC=1`), assortie d'une
  **contre-preuve vérifiée** (`z_flashcard_answer_input.dart:1081`). L'argument (« poser
  `inMutuallyExclusiveGroup` sur un contrôle sans état sélectionné ferait mentir le lecteur d'écran »)
  est cohérent avec le comportement réel du widget : le tap **appelle `onStart`** immédiatement
  (`z_session_mode_selector.dart:194` : `onOpenFilters?.call(); onStart(ZSessionModeKind.test, …)`),
  il n'existe aucun état de sélection persistant à annoncer.

**Un point non enterré mais non répondu** (pas un finding, la spec ne l'interroge pas) : la ligne 3a de
la matrice mentionne `_ScopeFilter` (portée sous-dossier, `study_mode_selector_screen.dart:97`, ligne
vérifiée) parmi les filtres de lex, puis l'absorbe dans « axes différents » sans traitement dédié. La
capacité existe côté zcrud depuis SUF-3 (`ZSubfolderNavSpec`/`ZSubfolderSidebar`), mais la connexion
n'est pas faite explicitement dans le doc. À consigner pour la rétro, pas à corriger ici.

## 6. Voie (b) du T0 — aucune contrainte dégradée ? **Confirmé**

```console
$ git diff HEAD --stat -- example/
 example/test/offline_demo_test.dart | 25 +++++++++++++++++++++++++
 1 file changed, 25 insertions(+)                                     RC=0
```

⇒ `example/pubspec.yaml` et `example/test/boundary_deps_test.dart` sont **strictement inchangés**. ✅
Le seul fichier d'`example/` touché est celui de la correction pré-existante par l'orchestrateur.

**`example/pubspec.lock`** : non suivi par git (`git check-ignore -v example/pubspec.lock` → **RC=1**,
donc **non ignoré** non plus), mais `stat` donne `mtime = 2026-07-24 17:42` — **antérieur** à l'epic
(2026-07-26). Il n'a donc **pas** été produit par SUF-4 ; la revendication « non modifié » du File List
est exacte. ⚠️ À noter pour le gate de commit d'epic : ce fichier non suivi et non ignoré serait
capturé par un `git add -A` (CLAUDE.md exige de l'exclure).

**Le conflit structurel invoqué est réel** — arêtes dures re-prouvées :

```console
$ grep -rn "package:zcrud_mindmap\|package:zcrud_exam" packages/zcrud_study/lib/
lib/src/domain/z_mindmap_generation_port.dart:30   … show ZMindmapNode;
lib/src/presentation/z_exam_editor.dart:37
lib/src/presentation/z_exam_reminders_section.dart:19
lib/src/presentation/z_study_mindmap_section.dart:35
lib/src/presentation/z_exam_reminders.dart:38                                RC=0
```

(le doc annonçait 5 sites d'import : ce sont bien **5** imports réels — les 2 lignes supplémentaires du
rejeu sont des **commentaires du barrel**, `lib/zcrud_study.dart:30,65`.)

**La régression `example/` invoquée comme pré-existante l'est bel et bien.** `purge` / `putMerged` sont
au port `ZLocalStore` **depuis `07d1cc0` / `6dc6535` (v0.12/v0.13)** — `git log -3 -- packages/zcrud_core/lib/src/domain/ports/z_local_store.dart`
et `git show HEAD:…/z_local_store.dart | grep -n "purge\|putMerged"` (RC=0, `:105` `Future<ZResult<T>> putMerged(T item);`).
Le fake d'`example/` n'avait jamais suivi. Aucun lien avec SUF-4. ✅

## 7. Le graphe : 68 → 69, pas « 69 inchangé »

```console
$ git archive HEAD | tar -x -C <tmp> && (cd <tmp> && python3 scripts/dev/graph_proof.py | tail -5)
total arêtes = 68 · out-degree(zcrud_core) = 0 · ACYCLIQUE OK · CORE OUT=0 OK

$ python3 scripts/dev/graph_proof.py | tail -5      # arbre de travail
total arêtes = 69 · out-degree(zcrud_core) = 0 · ACYCLIQUE OK · CORE OUT=0 OK   RC=0

$ git diff HEAD -- packages/zcrud_study/pubspec.yaml
+  zcrud_session: ^0.18.0                # + un bloc de justification SUF-3
```

Les **invariants tiennent** (ACYCLIQUE, CORE OUT=0), et le commentaire de SUF-3 dans le pubspec dit
justement « Graphe : 68 → 69 arêtes » — **correct**. Mais le doc d'audit §5.2 écrit :

> « Aucune contrainte existante n'a été dégradée : `example/pubspec.yaml` et
> `example/test/boundary_deps_test.dart` sont **inchangés** ; **aucun `pubspec.yaml` n'a bougé** ; le
> graphe reste **ACYCLIQUE, CORE OUT = 0, 69 arêtes**. »

… et SUF-4 tabule « **69 arêtes** (inchangé) ». Lu au niveau de l'**epic** (ce qui est la maille du
commit unique), c'est faux : un `pubspec.yaml` a bougé et le graphe a **gagné une arête**. Lu au niveau
de **SUF-4 seule**, c'est vrai — et §5.1 du même doc dit explicitement que le pubspec a changé en SUF-3.
La phrase se contredit donc **à l'intérieur de la même section**. → **F2**.

## 8. Chiffres de tests annoncés par les stories — rejeu réel

Toutes les suites lancées **depuis le répertoire du package** (convention du dépôt : les gardes de
source utilisent des chemins `File('lib/…')` relatifs au package).

| Story | Chiffre annoncé | Rejeu réel | Verdict |
|---|---|---|---|
| SUF-1 | « 22 tests ajoutés » | 4+3+2+1+3+9 = **22** déclarations | ✅ |
| SUF-1 | `flutter test` zcrud_ui_kit **109/109**, RC=0 | `cd packages/zcrud_ui_kit && flutter test` → **`+109: All tests passed!`** | ✅ |
| SUF-1 | `dart analyze packages/zcrud_ui_kit` RC=0, « No issues found! » | `cd packages/zcrud_ui_kit && dart analyze .` → **No issues found!** | ✅ |
| SUF-2 | « **14 nouveaux** + 1 golden » | `flutter test test/presentation/z_folder_card_test.dart test/golden/…` → **`+17`** | ❌ **F1** |
| SUF-2 | zcrud_study **557 tests** | 600 − 7(SUF-4) − 36(SUF-3) = **557** | ✅ |
| SUF-2 | « 51 info pré-existants » | `dart analyze .` → **52 issues**, 0 error / 0 warning | ✅ (+1, apporté par SUF-3) |
| SUF-3 | « **36 nouveaux** » | rejeu des 8 fichiers SUF-3 → **`+36: All tests passed!`** | ✅ |
| SUF-3 | zcrud_study **593 tests** | 600 − 7 = **593** | ✅ |
| SUF-4 | zcrud_session **543 tests** (+14) | `cd packages/zcrud_session && flutter test` → **`+543: All tests passed!`** ; `suf4_parity_closures_test.dart` = **14** | ✅ |
| SUF-4 | zcrud_study **600 tests** (+7) | `cd packages/zcrud_study && flutter test` → **`+600: All tests passed!`** ; `suf4_assembly_demo_test.dart` = **7** | ✅ |
| SUF-4 | graph_proof ACYCLIQUE / CORE OUT=0 | rejoué → **OK / OK** | ✅ (mais cf. §7 pour « 69 inchangé ») |
| SUF-4 | example « 7 fichiers session/frontière — 23 tests » | **non reproductible tel quel** (l'ensemble des 7 fichiers n'est pas nommé) ; la suite `example/` **complète** est verte : **`+97: All tests passed!`** | 🟡 non falsifié, non vérifiable |

**Détail de F1** : `packages/zcrud_study/test/presentation/z_folder_card_test.dart` porte **15**
déclarations `testWidgets(`/`test(`, dont `G13` est **dans une boucle** `for` sur deux `itemHeight`
⇒ **16 tests** à l'exécution, + **1** golden = **17**. Le total de 557 annoncé par la story est, lui,
correct (donc la base pré-SUF-2 était 540, pas 542) : c'est bien le **compte des tests neufs** qui est
faux, dans deux endroits de la story (`:196` et `:234`).

## 9. AC9 de SUF-4 : littéralement non tenu, et `example` analyse **RC=1**

AC9 (`suf-4-…md:77`) exige, mot pour mot : « `flutter analyze` (example) RC=0 ; **un test de fumée
`example/test/`** monte le parcours ».

- Le test de fumée vit en `packages/zcrud_study/test/suf4_assembly_demo_test.dart` (voie (b)). C'est
  **assumé et documenté** (T7/T8 de la story, §5.2 du doc, Completion Notes « AC7/AC8/AC9 — voie (b) »),
  et la justification est **solide** (cf. §6 ci-dessus). Mais AC9 est coché sans note de **variance
  d'AC** explicite alors que la story elle-même exigeait de « documenter comme variance ».
- Surtout, la clause analyse est **factuellement rouge** :

```console
$ cd example && flutter analyze
   info • … lib/demos/list_demo_screen.dart:390:44 • deprecated_member_use
   info • … lib/demos/markdown_demo_screen.dart:150:29 • unnecessary_underscores
   info • … lib/support/rebuild_indicator.dart:50:31 • unnecessary_underscores
   info • Use 'const' with the constructor … test/offline_demo_test.dart:228:7 • prefer_const_constructors
4 issues found.
RC=1
```

La **4ᵉ** info est **nouvelle** : elle porte sur `Left<ZFailure, DemoRecord>(const ZCacheFailure(…))`
(lignes 227-233), c'est-à-dire **dans le bloc ajouté par la correction de l'orchestrateur** — la
construction peut être `const`. Aucun gate ne l'attrapera : `example` **n'est pas** un package melos
(`dart run melos list` → 31 paquets, **aucun `example`**), donc `melos run analyze` ne le voit pas.
→ **F4**.

## 10. Ce que la revue a vérifié et trouvé CONFORME (pour mémoire)

- 8/8 greps négatifs et 3/3 greps positifs du doc : **RC conformes**.
- ~45 n° de ligne cités (lex + zcrud) : **tous exacts** (1 nit d'une ligne sur `ZSrsQualityEmphasis`).
- `/home/zakarius/DEV/lex_douane` : **aucune écriture** imputable à l'epic (unique entrée `git status`
  datée du 2026-07-05, diff 0/0).
- `example/pubspec.yaml`, `example/test/boundary_deps_test.dart`, `example/pubspec.lock` : **inchangés**.
- Erreur d'analyse `example` invoquée comme pré-existante : **réellement pré-existante** (port modifié
  en v0.12/v0.13).
- Arêtes `zcrud_mindmap`/`zcrud_exam` de `zcrud_study` : **réellement dures**, 5 imports réels.
- Surfaces publiques des 3 fermetures : **réellement exportées** par le barrel.
- Le `6` de lex : **absent du code** du package, injecté par la démo côté app.
- Suites de test : `zcrud_ui_kit` **109** ✅, `zcrud_study` **600** ✅, `zcrud_session` **543** ✅,
  `example` **97** ✅ — toutes vertes, RC=0.
- `dart analyze` : `zcrud_ui_kit` **No issues found!**, `zcrud_study` 52 infos / **0 error, 0 warning**,
  `zcrud_session` 40 infos / 0 error.

**Nit non-finding** : `packages/zcrud_ui_kit/test/z_page_shell_source_guard_test.dart` n'a ni
`@TestOn('vm')` ni assertion `existsSync()` (à la différence de son homologue SUF-3,
`packages/zcrud_study/test/suf3_source_guard_test.dart:5,24-27`). Lancé depuis la racine du dépôt il
casse sur `FileSystemException` au lieu d'un message actionnable. Ce n'est **pas** une divergence de
convention (tout le dépôt utilise des chemins relatifs au package : `zcrud_flashcard`, `zcrud_markdown`,
`zcrud_html`, `zcrud_core/test/purity/…`), et l'échec reste **bruyant** — donc pas de perte de morsure.

---

## Findings

### F1 — MEDIUM — nombre de tests neufs de SUF-2 faux (14+1 annoncés, 17 réels)

`_bmad-output/implementation-artifacts/stories/suf-2-carte-dossier.md:196` (et `:234`).

> « **557 tests verts** (dont **14 nouveaux** du fichier `z_folder_card_test.dart` + 1 golden) »

Preuve :

```console
$ cd packages/zcrud_study && flutter test test/presentation/z_folder_card_test.dart \
    test/golden/z_folder_card_golden_test.dart
00:00 +17: All tests passed!                                            RC=0

$ grep -cE "^\s*(test|testWidgets)\(" packages/zcrud_study/test/presentation/z_folder_card_test.dart
15      # dont G13 dans une boucle `for` sur 2 itemHeight ⇒ 16 à l'exécution
```

Recoupement arithmétique : `600 (aujourd'hui) − 7 (SUF-4) − 36 (SUF-3) = 557` ⇒ la base pré-SUF-2 était
**540**, et SUF-2 a bien ajouté **17** tests. Le total 557 est juste ; le compte de tests neufs ne l'est
pas. Sur une lentille « réalité du code », un chiffre de couverture publié et non rejouable est
exactement le type d'affirmation à corriger. **Correction : éditer la story (2 occurrences).**

### F2 — MEDIUM — « aucun pubspec.yaml n'a bougé … 69 arêtes » : le diff d'epic fait 68 → 69

`docs/parity-session-widgets-2026-07-26.md` §5.2 (fin de section) et
`_bmad-output/implementation-artifacts/stories/suf-4-audit-session-demo-assemblee.md:251` (« 69 arêtes
(inchangé) »).

Preuve :

```console
$ git archive HEAD | tar -x -C /tmp/head_tree && cd /tmp/head_tree && python3 scripts/dev/graph_proof.py | tail -5
total arêtes = 68 … ACYCLIQUE OK … CORE OUT=0 OK

$ cd /home/zakarius/DEV/zcrud && python3 scripts/dev/graph_proof.py | tail -5
total arêtes = 69 … ACYCLIQUE OK … CORE OUT=0 OK                        RC=0

$ git diff HEAD -- packages/zcrud_study/pubspec.yaml
+  zcrud_session: ^0.18.0
```

Les invariants AD-1 **tiennent** (acyclique, CORE OUT=0) — ce n'est pas une violation d'architecture,
c'est une **affirmation fausse à la maille du commit d'epic**, dans le passage même qui certifie
qu'aucune contrainte n'a été dégradée, et en contradiction avec le §5.1 du même document (qui dit que
le pubspec a changé en SUF-3). **Correction : reformuler en « aucun `pubspec.yaml` n'a bougé *dans le
périmètre SUF-4* ; le graphe est passé de 68 à 69 arêtes en SUF-3, ACYCLIQUE et CORE OUT=0 préservés ».**

### F3 — LOW — les blocs `console` du doc restituent des sorties de grep tronquées, sans élision

`docs/parity-session-widgets-2026-07-26.md` §3, blocs P3-4, P2-1, P2-2.

Preuve (RC tous conformes, volumes non) :

```console
$ grep -n "_QuestionCountStepper\|questionCountIncrementKey" \
    packages/zcrud_session/lib/src/presentation/z_test_filters_dialog.dart | wc -l
5        # le doc en montre 3 (97, 177, 274)

$ grep -n "dueRemaining\|showContinue" \
    packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart | wc -l
7        # le doc en montre 2 (180, 536)

$ git show HEAD:packages/zcrud_session/lib/src/presentation/z_session_quality_breakdown.dart \
    | grep -n "containsKey" | wc -l
2        # le doc en montre 1 (77)
```

Aucune conclusion n'en dépend. Mais dans un livrable dont l'argument est « commande + RC consignés »,
une sortie éditée sans `…` est une entorse à la discipline qu'il proclame. **Correction : ajouter un
marqueur d'élision ou coller la sortie complète.**

### F4 — LOW — AC9 de SUF-4 coché alors que `flutter analyze` (example) est RC=1, dont **1 info introduite** par le correctif

`example/test/offline_demo_test.dart:228` ; AC9 en
`_bmad-output/implementation-artifacts/stories/suf-4-audit-session-demo-assemblee.md:77`.

Preuve :

```console
$ cd example && flutter analyze ; echo "RC=$?"
   info • Use 'const' with the constructor … test/offline_demo_test.dart:228:7 • prefer_const_constructors
   (+ 3 infos pré-existantes)
4 issues found.
RC=1

$ dart run melos list | tr '\n' ' ' | grep -c example
0        # `example` n'est PAS un package melos ⇒ `melos run analyze` ne le couvre pas
```

Le code fautif est dans le bloc ajouté (lignes 227-233 : `Left<ZFailure, DemoRecord>(const ZCacheFailure(…))`
peut être `const`). Deux points distincts : (a) la clause « `flutter analyze` (example) RC=0 » d'AC9
n'est **pas** tenue et aucun gate ne le verra ; (b) la clause « test de fumée **`example/test/`** »
d'AC9 est délibérément non tenue (voie (b)) — c'est justifié et documenté dans T7/T8 et §5.2, mais
sans **note de variance au niveau de l'AC**, alors que la story exigeait de « documenter comme
variance ». **Correction : `const Left<ZFailure, DemoRecord>(…)` + note de variance explicite sur AC9.**
