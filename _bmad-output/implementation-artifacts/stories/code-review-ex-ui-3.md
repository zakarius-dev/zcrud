# Code Review — EX-UI.3 : `ZAdaptiveGrid` + `computeCrossAxisCount`

- **Skill** : `bmad-code-review` (invoqué via tool `Skill`, chargé OK — pas de fallback disque).
- **Portée** : `packages/zcrud_responsive/lib/src/domain/compute_cross_axis_count.dart`, `lib/src/presentation/z_adaptive_grid.dart`, barrel `lib/zcrud_responsive.dart`, tests `compute_cross_axis_count_test.dart` + `z_adaptive_grid_test.dart`. Archi : AD-31 (+ AD-1/2/10/13/14/15).
- **Vérif rejouée sur disque** : `dart analyze packages/zcrud_responsive` → **No issues found!** · `flutter test packages/zcrud_responsive` → **82/82 verts** (RC=0).
- **Verdict** : **APPROUVÉ**. **0 HIGH, 0 MEDIUM**. 3 LOW consignés (non bloquants).

---

## Couverture des ACs (adversarial : satisfait ET testé porteur)

| AC | Satisfait | Test porteur (échouerait si la garde sautait ?) |
|----|-----------|--------------------------------------------------|
| AC1 clamp bas ≥1 | ✅ `lo = minColumns<1?1:minColumns`, `raw<lo→lo` | ✅ `w=100,minW=300→1` ; `minColumns:0/-5→1` |
| AC2 défauts sûrs sans throw/÷0 | ✅ gardes NaN/≤0 AVANT division, clamp manuel | ✅ `minW=0/NaN`, `w=0/NaN/∞`, `maxColumns<minColumns` en `returnsNormally` — retirer une garde ⇒ `floor(Infinity/NaN)` lève `UnsupportedError` ⇒ test rouge |
| AC3 frontières + clamp haut | ✅ `floor`+borne manuelle | ✅ `w=minW→1`, `2minW→2`, `2minW−1→1`, `½minW→1`, `10000+max4→4`, `null→33` |
| AC4 garde vide | ✅ `children.isEmpty→SizedBox.shrink()` AVANT LayoutBuilder | ✅ `GridView` findsNothing |
| AC5 largeur LOCALE | ✅ `constraints.maxWidth`, jamais `Get.width`/`MediaQuery` | ✅ panneau `SizedBox(250)` sous écran 1400 → 1 col |
| AC6 aspect déduit + garde | ✅ `itemHeight>0? w/h : aspectRatio??1.0` | ✅ itemHeight=200 ; repli 1.0 ; explicite 1.5 ; itemHeight=0→repli |
| AC7 Stateless/builder/RTL | ✅ `StatelessWidget`, `GridView.builder`, `EdgeInsetsGeometry?` | ✅ RTL==LTR @250/1000 ; shrinkWrap+NeverScrollable |
| AC8 barrel + gates | ✅ 2 exports ciblés, tri `directives_ordering` OK | ✅ analyze RC=0 |

Axes adversariaux vérifiés : clamp bas ≥1 **prouvé garanti** (jamais 0) ; clamp haut OK ; tous cas dégénérés (minItemWidth≤0/NaN, availableWidth≤0/NaN/∞, maxColumns<minColumns) **sans throw ni ÷0** ; largeur locale via `LayoutBuilder` (aucun `Get.width`/`MediaQuery` — les occurrences grep sont uniquement des anti-modèles cités en dartdoc) ; garde vide ; `GridView.builder` paresseux ; directionnel AD-13 (aucun `EdgeInsets.only` left/right) ; nom `ZAdaptiveGrid` (pas de collision avec `ZResponsiveGrid` de core) ; AD-2 aucun gestionnaire d'état.

---

## Findings

### LOW-1 — `itemWidth` non gardé contre ≤0 / infini avant le calcul du ratio
`z_adaptive_grid.dart:104-110`. `itemWidth = (constraints.maxWidth − spacing·(n−1)) / n` puis `ratio = itemWidth / height` (si `itemHeight>0`). Deux entrées pathologiques produisent un `childAspectRatio` non-positif ou infini, qui viole l'assertion `childAspectRatio > 0` de `SliverGridDelegateWithFixedCrossAxisCount` (throw en mode debug — contraire à l'esprit AD-10 « jamais de throw ») :
1. `spacing > minItemWidth` avec plusieurs colonnes (ex. `minItemWidth:300, spacing:700, w:600 → n=2, itemWidth=−50`) ⇒ ratio négatif.
2. `constraints.maxWidth == double.infinity` (grille placée en largeur non bornée) + `itemHeight` fourni ⇒ `itemWidth` infini ⇒ ratio infini.
**Impact** : faible — inputs contrivés (espacement > largeur-min d'item ; ou GridView vertical en contexte horizontalement non borné, que Flutter rejette de toute façon). Non couvert par un test.
**Correction suggérée** : `final double safeWidth = itemWidth.isFinite && itemWidth > 0 ? itemWidth : minItemWidth;` avant le calcul du ratio, ou clamp `ratio` à `> 0` (repli `aspectRatio ?? 1.0`). Cohérent avec la garde `itemHeight>0` déjà présente.

### LOW-2 — Commentaire du barrel mal attribué
`zcrud_responsive.dart:42-43`. Le commentaire « Aiguilleur de disposition responsive (EX-UI.2) — 3 builders… » coiffe le **bloc de deux** exports presentation, dont `export 'src/presentation/z_adaptive_grid.dart';` qui relève d'**EX-UI.3** (grille d'items), pas de l'aiguilleur EX-UI.2. **Impact** : cosmétique (documentation trompeuse). **Correction** : séparer le commentaire du `z_adaptive_grid` ou ajouter une ligne dédiée « Grille d'items adaptative (EX-UI.3) ».

### LOW-3 — Dartdoc de bibliothèque du barrel périmé
`zcrud_responsive.dart:3-27`. Le dartdoc `library` ne décrit que les primitives EX-UI.1 (`ZWindowSizeClass`, `ZBreakpointValue`) ; ni `ZResponsiveLayout` (EX-UI.2) ni `ZAdaptiveGrid`/`computeCrossAxisCount` (EX-UI.3) n'y figurent. **Impact** : cosmétique. **Correction** : mentionner les deux primitives d'EX-UI.3 dans l'en-tête.

---

## Conformité AD (rappel)
AD-31 ✅ (clamp≥1, largeur locale, garde vide, `ZAdaptiveGrid`≠`ZResponsiveGrid`, aspect déduit) · AD-1 ✅ (aucune arête `zcrud_*` nouvelle ; domaine Dart pur) · AD-2/15 ✅ (StatelessWidget, 0 manager) · AD-10 ✅ (défauts sûrs — réserve LOW-1) · AD-13 ✅ (`EdgeInsetsGeometry?`, RTL testé) · AD-14 ✅ (fonction pure déterministe) · NFR-U6 ✅ (testable sans BuildContext) · NFR-U11 ✅ (0 codegen).

**Aucun finding HIGH/MEDIUM. Story recevable en l'état ; les 3 LOW sont optionnels (LOW-1 recommandé si adoption future avec `spacing` généreux).**
