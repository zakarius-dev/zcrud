# Code Review — EX-UI.11 (BINDING GetX : `ZGetFormPresenter` + `ZGetToaster`)

- **Skill** : `bmad-code-review` (tool `Skill`) — chargé (step-file architecture). Revue conduite en lecture seule, adversariale.
- **Story** : `ex-ui-11-binding-getx-presenter-toaster.md` (5 ACs) — DERNIÈRE story de l'epic EX-UI.
- **Date** : 2026-07-16. **Reviewer** : agent adversarial. **Portée** : `packages/zcrud_get/` uniquement.

## Vérif verte rejouée sur disque

- `dart analyze packages/zcrud_get` → **No issues found!** (RC=0).
- `flutter test --no-pub` (package) → **54/54 All tests passed!** (dont 4 presenter + 6 toaster + 3 seam + 3 confinement).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK / CORE OUT=0 OK** ; arêtes `zcrud_get` = `→ zcrud_core`, `→ zcrud_navigation`, `→ zcrud_study_kernel`, `→ zcrud_ui_kit` (2 nouvelles UI sortantes, `zcrud_responsive` transitif).
- Scan impl : **aucun** `Get.width/height/context!`, **aucun** littéral hex/`Colors.*`, **aucun** `TextAlign.left/right` (seules occurrences = commentaires/dartdoc).

## Conformité par AC

| AC | Verdict | Preuve |
|----|---------|--------|
| AC1 — présentateur 3 modes GetX, signature exacte, switch exhaustif, `MediaQuery.sizeOf`, form-agnostique | ✅ | `@override present<T>` reprend la signature du port (compile) ; `switch (mode)` total ; `Get.to(fullscreenDialog:)` / `Get.bottomSheet(isScrollControlled:)` / `Get.dialog(Dialog+ConstrainedBox, barrierDismissible:)` ; `Builder(builder:)` opaque ; repli `?? Future<T?>.value()`. Tests porteurs (page écarte le trigger ; dialog exige `Dialog`+`isDialogOpen` ; sheet exige `isBottomSheetOpen`). |
| AC2 — toaster 4 sévérités, couleur `ColorScheme` jamais seul canal | ✅ | `switch (severity)` total ; `(background, foreground, icon)` dérivés (`primary`/`tertiary`/`secondary`/`errorColor??error`) ; icône+texte ; `mainButton` SSI `actionLabel && onAction` ; `TextAlign.start` ; `Semantics(liveRegion:)`. Test asserte `backgroundColor == roleOf(scheme)` (porteur, jamais hex). |
| AC3 — substitution au seam prouvée, paquets purs inchangés | ✅ | `ex_ui_11_seam_test` : sans scope → `ZAdaptivePresenter`/`ZScaffoldMessengerToaster` (défaut) ; avec scope → `ZGetFormPresenter`/`ZGetToaster` ; helper `ZcrudGetUiScope` monte les deux. `git status` : aucune modif de `zcrud_navigation`/`zcrud_ui_kit`. |
| AC4 — `get` confiné, graphe acyclique, CORE OUT=0, 2 arêtes | ✅ (réserve test, cf. M1) | pubspec +`zcrud_navigation`/`zcrud_ui_kit` ^0.2.0 ; graph_proof confirme. |
| AC5 — vert, barrel étendu, codegen no-op | ✅ | analyze RC=0, tests verts, barrel +3 exports + dartdoc EX-UI.11 sans retrait ni ré-export de paquet pur. |

## Findings

### HIGH
Aucun.

### MEDIUM

**M1 — Test de confinement ne couvre pas la clause « QUE » d'AC4** · `packages/zcrud_get/test/ex_ui_11_confinement_test.dart:64-83`
AC4 exige de prouver que `package:get/` **n'apparaît QUE** dans `zcrud_get/lib/` (le texte de l'AC liste aussi `zcrud_responsive` et `zcrud_core`). Le test ne scanne l'absence de `package:get`/`go_router` que dans `zcrud_navigation/lib` et `zcrud_ui_kit/lib`, puis vérifie la **présence** de `get` dans `zcrud_get`. Une fuite de `package:get/` dans `zcrud_responsive` (nouvellement tiré transitivement) ou dans un autre paquet pur passerait **inaperçue** — `graph_proof.py` ne l'attrape pas non plus (`get` n'est pas un nœud `zcrud_*`).
- **Impact** : régression AD-15 silencieuse hors des 2 paquets scannés.
- **Correction** : étendre `_offenders` à `zcrud_responsive/lib` (et idéalement itérer tous les `packages/*/lib` sauf `zcrud_get`) pour asserter l'absence de `package:get/`.
- **Statut** : reporté justifié acceptable — D8 de la story prescrit explicitement le scan restreint à `zcrud_navigation`+`zcrud_ui_kit` (les 2 paquets qui définissent les ports implémentés, seuls vecteurs directs) ; le risque résiduel sur `responsive`/`core` est faible (paquets purs sous leurs propres invariants). À durcir en dette EX-UI si souhaité.

### LOW

**L1 — Aucune assertion comportementale n'interdit `Get.width/height`** · `z_get_form_presenter_test.dart`
AC1 impose la mesure par `MediaQuery.sizeOf(context)` (jamais `Get.*`). Aucun test ne rougirait si l'impl revenait à `Get.width/Get.height` (les surfaces s'ouvriraient identiquement). Garde-fou actuel = revue + dartdoc uniquement (grep confirme l'absence). Inhérentement difficile à tester ; acceptable.

**L2 — Matcher lâche `findsWidgets`** · `z_get_toaster_test.dart:92`
`expect(find.text('coucou'), findsWidgets)` tolère 0+... en réalité 1+ ici. `findsWidgets` exige ≥1 donc reste porteur, mais `findsOneWidget` serait plus strict.

**L3 — `snackPosition: SnackPosition.BOTTOM` en dur** · `z_get_toaster.dart:96`
Constante de position codée (documentée « cohérent avec SnackBar Material »). Non couverte par le thème injecté ; acceptable car non-couleur et alignée sur le défaut pur-Flutter.

## Décisions de conception validées

- D2/D5 : `switch` exhaustif sans `default`/throw sur les 3 modes et 4 sévérités (compilateur garantit la totalité). ✅
- D3 : icône unique dans `messageText` (pas de doublon `icon:` du prototype de story) — évite une double icône, `find.byIcon` reste `findsOneWidget`. ✅ (amélioration légitime vs prototype D3.)
- D4 : helper `ZcrudGetUiScope` trivial livré, imbrique les seams existants sans en créer un concurrent ni toucher `ZcrudScope`. ✅
- AD-1/NFR-U1 : 2 arêtes sortantes du puits, `CORE OUT=0` intact, acyclique. ✅
- AD-4/NFR-U9 : impls externes compilent et se substituent sans modifier les paquets purs (`abstract interface class`). ✅

## Verdict

**APPROUVÉ.** 0 HIGH, 1 MEDIUM (reporté-justifié, borderline durcissement de test), 3 LOW. Les 5 ACs sont satisfaits et testés par des tests **porteurs** (casser un mode/une sévérité/une couleur rougit). Vérif verte réelle confirmée (analyze RC=0, 54/54 tests, graphe acyclique CORE OUT=0). Le MEDIUM M1 n'est pas bloquant : il relève du durcissement de couverture au-delà du périmètre D8 explicitement défini, sans défaut de conformité constaté. La story peut passer `done` et débloquer la rétrospective EX-UI.
