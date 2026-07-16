# Code Review — EX-UI.6 : `ZFormPresenter` + `ZAdaptivePresenter` + seam + `presentEdition`

- **Skill** : `bmad-code-review` invoqué via le tool `Skill` (chargé). Revue conduite adversariale, **lecture seule** (aucune modif code ni sprint-status).
- **Date** : 2026-07-16 · **Reviewer** : agent adversarial · **Langue** : FR
- **Cible** : `packages/zcrud_navigation/lib/src/presentation/{z_form_presenter,z_adaptive_presenter,z_form_presenter_scope,present_edition}.dart` + barrel + `test/{z_adaptive_presenter,z_form_presenter_scope,present_edition}_test.dart`

## Vérifs rejouées sur disque

| Gate | Résultat |
|---|---|
| `dart analyze packages/zcrud_navigation` | **No issues found** (RC=0) |
| `flutter test packages/zcrud_navigation` | **All tests passed** — 33 tests (dont EX-UI.5) verts |
| `python3 scripts/dev/graph_proof.py` | **ACYCLIQUE OK / CORE OUT=0 OK** (49 arêtes, 22 nœuds) |
| grep `package:(get\|go_router\|flutter_riverpod\|provider)/` sur lib+test | **0 import réel** — uniquement mentions dartdoc |
| grep `Get.(to\|dialog\|bottomSheet\|width\|height\|context)` | **0 usage réel** — uniquement dartdoc de migration |
| pubspec deps | `zcrud_core`, `zcrud_responsive`, `flutter` — **aucune arête nouvelle** |

## Confrontation ACs

| AC | Verdict | Preuve |
|---|---|---|
| AC1 — port abstract non-`sealed`, form-agnostique, `presentation/` | ✅ | `abstract interface class ZFormPresenter`; `_RecordingPresenter implements ZFormPresenter` (impl **externe** au fichier) compile et se substitue → prouve non-`sealed`; `domain/` intact (aucun `import flutter`) |
| AC2 — 3 surfaces Flutter vanilla, switch exhaustif sans throw | ✅ | `page`→`Navigator.push(MaterialPageRoute(fullscreenDialog:true))`; `sheet`→`showModalBottomSheet(isScrollControlled:true)`; `dialog`→`showDialog(Dialog+ConstrainedBox)`; switch sur 3 valeurs **sans `default` ni throw** (AD-10); tests des 3 surfaces verts |
| AC3 — tailles max + retour `Navigator.pop<T>` | ⚠️ (voir M1) | Dialog `maxWidth:400`→`ConstrainedBox` porteur; retour valeur prouvé pour les **3 modes** (`result-$mode`); défaut sheet/dialog dérivé de `MediaQuery.sizeOf` |
| AC4 — seam local, défaut `ZAdaptivePresenter`, `ZcrudScope` intact | ✅ | `of()` sans scope→`ZAdaptivePresenter`; `maybeOf`→null; injection résolue; `updateShouldNotify = presenter != old`; `zcrud_core` sans arête sortante (graph_proof) |
| AC5 — `presentEdition` câble largeur→policy→seam→present | ✅ | 4 cas largeur (`<600`→sheet, `600..839`→dialog, `≥840`+light→dialog, `≥840`+heavy→page) captés via recorder + surface réelle (BottomSheet) via défaut |
| AC6 — RTL / a11y / grep manager négatif | ✅ | dialog+sheet sous `Directionality.rtl` sans exception; `useSafeArea`/`barrierDismissible` exposés; aucun helper non-directionnel introduit |
| AC7 — barrel +4 exports, graphe, codegen no-op | ✅ | barrel exporte les 4 fichiers + 3 domaine intacts; graph_proof OK; aucun `@ZcrudModel`; pas de nouveau package |

## Findings

### HIGH
Aucun.

### MEDIUM

**M1 — Test de contrainte `maxHeight` sur la bottom-sheet NON PORTEUR** · `test/z_adaptive_presenter_test.dart:134-145`
- **Constat** : le test « sheet maxHeight=300 » asserte `tester.getSize(BottomSheet).height <= 300`. Le `builder` ne rend qu'un `Text` (~quelques dizaines de px) et `showModalBottomSheet(isScrollControlled:true)` dimensionne la sheet **au contenu** ; la borne 300 n'est **jamais** atteinte. L'assertion est donc trivialement vraie même si l'on **supprimait** `constraints.maxHeight` du code de production → une mutation du dispatch ne rougirait pas ce test.
- **Impact** : l'application effective de `maxHeight` pour le mode `sheet` (branche AC3) n'est pas réellement couverte, contrairement au pendant `dialog`/`maxWidth` qui, lui, est porteur (`ConstrainedBox.maxWidth==400`). Le **code de production est correct** (`BoxConstraints(maxHeight: effectiveMaxHeight,…)` bien passé) — c'est une faiblesse de **qualité de test**, pas un bug fonctionnel.
- **Correction suggérée** : soit asserter directement la contrainte passée (localiser la sheet et vérifier `constraints.maxHeight == 300`), soit rendre un `builder` de hauteur intrinsèque > 300 (ex. `SizedBox(height: 600)`) et vérifier que la sheet est bornée à ≤ 300, de sorte que retirer la contrainte du code fasse échouer le test.

### LOW

- **L1** — `test/z_adaptive_presenter_test.dart` : pas de test pour `maxWidth` en mode `sheet`, ni pour l'**ignorance** documentée des tailles en mode `page`. Couverture optionnelle.
- **L2** — `lib/src/presentation/z_form_presenter.dart:54` : la dartdoc de `useSafeArea` ne précise pas qu'il est **sans effet** en mode `page` (`MaterialPageRoute` n'a pas ce paramètre), alors que le comportement `barrierDismissible` (dialog-only) est, lui, documenté.
- **L3** — `lib/zcrud_navigation.dart:4-5` : l'intro du barrel qualifie encore le package de « tête P2 (**EX-UI.5**) » ; la section Présentation EX-UI.6 a bien été ajoutée plus bas mais le chapeau n'a pas été rafraîchi (cosmétique).
- **L4** — `updateShouldNotify` du seam n'est pas couvert par un test dédié (trivial ; comportement standard `InheritedWidget`).

## Verdict

**APPROUVÉ.** Les 7 ACs sont satisfaits et testés ; port `abstract interface class` **jamais `sealed`** prouvé substituable par une impl externe ; `ZAdaptivePresenter` **100 % Flutter vanilla** (aucun `get`/`go_router`/`riverpod`/`provider` réel, grep confirmé), switch **exhaustif sans throw**, retour `<T>` via `Navigator.pop` prouvé sur les 3 modes ; seam `InheritedWidget` **local** avec défaut sûr, `ZcrudScope`/`CORE OUT=0` intacts ; `presentEdition` matérialise le câblage largeur→breakpoint→policy→mode→surface (4 cas). Gates verts (analyze RC=0, 33 tests, graph_proof ACYCLIQUE/CORE OUT=0).

Aucun HIGH. **1 MEDIUM (M1, qualité de test — code correct)** : correction recommandée dans le périmètre avant `done` (rendre le test `maxHeight` porteur) ou justification écrite si reportée. LOW optionnels.
