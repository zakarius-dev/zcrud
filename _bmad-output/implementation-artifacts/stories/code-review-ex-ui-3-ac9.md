# Code-review CIBLÉ — delta AC9 de EX-UI.3 (`ZAdaptiveGrid` / `computeCrossAxisCount`)

- **Story** : `ex-ui-3-adaptive-grid` (déjà revue/approuvée AC1..AC8 ; change-request 2026-07-16 ajoute AC9)
- **Périmètre** : UNIQUEMENT le delta AC9 (spacing + horizontalPadding dans le calcul des colonnes) + non-régression AC1..AC8
- **Skill** : `bmad-code-review` invoqué via le tool `Skill` (chargé avec succès — pas de fallback disque)
- **Mode** : adversarial, lecture seule (aucune modification de code ni de sprint-status)
- **Vérif rejouée** : `flutter test compute_cross_axis_count_test.dart z_adaptive_grid_test.dart` → **50/50 verts**

---

## Fichiers revus

- `packages/zcrud_responsive/lib/src/domain/compute_cross_axis_count.dart` (signature étendue : `spacing`, `horizontalPadding`)
- `packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart` (résolution directionnelle du padding, passage spacing/padding, itemWidth sur effectiveWidth)
- `packages/zcrud_responsive/test/compute_cross_axis_count_test.dart`
- `packages/zcrud_responsive/test/z_adaptive_grid_test.dart`

---

## Axes adversariaux — verdict

### (1) Formule `n = ⌊(effectiveWidth + spacingEff) / (minItemWidth + spacingEff)⌋` — CORRECTE
Dérivation : `n·minItemWidth + (n−1)·spacing ≤ effectiveWidth ⇔ n ≤ (effectiveWidth + spacing)/(minItemWidth + spacing)`. Bornes vérifiées :
- effectiveWidth=920, minW=300, spacing=20 → floor(940/320)=2 ; 2 items = 620≤920 ✓, 3 items = 940>920 correctement rejeté.
- Ajustement exact (effectiveWidth=940) → 3.0→3 (tient pile) ; effectiveWidth=939 → 2 (pas d'off-by-one).
Chaque item fait bien **≥ minItemWidth** gouttières+padding déduits. **Conforme AC9.**

### (2) Rétro-compatibilité stricte — TENUE
`spacing=0 ∧ horizontalPadding=0` ⇒ `spacingEff=0`, `paddingEff=0`, `effectiveWidth=availableWidth`, `denominator=minItemWidth` ⇒ `floor(availableWidth/minItemWidth)`. **Identique** à l'ancienne signature. Le cas `availableWidth.isInfinite` est traité AVANT le calcul d'`effectiveWidth` (l.72 avant l.78) → aucun `inf−inf`/NaN introduit. Test dédié porteur (l.362 : boucle 10 largeurs + égalité stricte appel-sans-params vs appel-avec-0). Comportements AC1..AC8 inchangés hors cas spacing/padding>0.

### (3) Défauts sûrs AD-10 étendus — COMPLETS, aucun throw / aucun ÷0
- `spacingEff = (spacing.isFinite && spacing>0) ? spacing : 0` → négatif/NaN/infini → 0 ✓ (testé l.284/296/329).
- `paddingEff` idem → négatif/NaN/infini → 0 ✓ (testé l.307/318/329).
- `effectiveWidth ≤ 0` (padding ≥ largeur) → `lo` (l.79) ✓ (testé l.264).
- `minItemWidth ≤ 0 / NaN`, `availableWidth ≤ 0 / NaN / ∞` : gardes préservées avant toute division.
- `clamp` toujours valide (`hi = max(lo, maxColumns)`), jamais de `RangeError`.

### (4) `ZAdaptiveGrid` — résolution directionnelle & cohérence
- Padding résolu via `padding?.resolve(Directionality.of(context)).horizontal ?? 0` (l.100-101) — directionnel AD-13, PAS `.horizontal` d'un `EdgeInsetsGeometry` non résolu. Invariance LTR/RTL prouvée (test l.305, `EdgeInsetsDirectional.only(start:90,end:30)`).
- Pas de double-comptage : padding retranché pour le calcul de `n` ET d'`itemWidth`, mais toujours appliqué visuellement au `GridView` (`padding: padding`, l.136). GridView pose ses items sur `maxWidth − padding.horizontal = effectiveWidth`, donc l'`itemWidth`/`childAspectRatio` calculés correspondent exactement au layout réel.
- `itemWidth` déduit sur `effectiveWidth` (l.115-117) — cohérent avec le calcul des colonnes.
- Gardes `childAspectRatio` préservées (rawItemWidth fini&>0 sinon minItemWidth ; ratio fini&>0 sinon 1.0).

### (5) clamp ≥ 1 anti-iffd + childAspectRatio défensif — TOUJOURS VERTS
Tests l.336 (padding ≥ largeur → 1 col, `takeException()==null`, ratio>0 fini) et l.354 (`spacing>minItemWidth` → largeur d'item ≤0 → aucun throw). Verts.

### (6) Tests AC9 — majoritairement PORTEURS
Porteurs (échoueraient si spacing/padding ignoré) : unit l.216 (3→2 via spacing), l.233 (3→2 via padding), l.264 (padding≥largeur) ; widget l.229 (3→2 padding), l.256 (3→2 spacing), l.281 (itemWidth déduit). Retro-compat l.362 fortement porteur.

---

## Findings

### HIGH — néant
### MEDIUM — néant

### LOW / nits (non bloquants)
- **LOW-1** — `compute_cross_axis_count.dart:85` : garde `if (denominator <= 0) return lo;` est **inatteignable** (`minItemWidth > 0` déjà validé l.66, `spacingEff ≥ 0`) ⇒ `denominator > 0` toujours. Code défensif inoffensif mais impossible à couvrir par un test porteur. Conserver (belt-and-suspenders) ou documenter comme volontairement mort. Aucun impact runtime.
- **LOW-2** — `compute_cross_axis_count_test.dart:250` (test « spacing + padding cumulés » attend 3) : faiblement porteur — le résultat (3) coïncide avec l'appel sans paramètres (1000/300→3), donc ce cas précis ne détecterait pas un oubli combiné des deux params. La porteur-ité globale est assurée par les autres tests AC9. Nit.

---

## Non-régression AC1..AC8

Le passage systématique de `spacing` (défaut 8.0) par le widget modifie la base de calcul, mais les scénarios AC1..AC8 restent stables : conteneur 1000→3 (`(1008/308)=3.27→3`), 250→1, 650+maxColumns:2→2. Le test AC6 (`itemHeight`, largeur 900) a été **délibérément** mis à jour de 3→2 colonnes (commentaire l.126-127) : c'est l'effet voulu d'AC9 (3 colonnes écraseraient les items sous `minItemWidth`), non une régression. Aucun AC1..AC8 cassé. Aucune nouvelle arête `zcrud_*`, aucun secret, aucun gestionnaire d'état, `GridView.builder` conservé, RTL invariant.

## Verdict

**APPROUVÉ.** Delta AC9 correct, sûr, rétro-compatible ; AC1..AC8 intacts ; 50/50 tests verts. 0 HIGH, 0 MEDIUM, 2 LOW optionnels. Prêt pour `done` (sous réserve du gate repo-wide `melos analyze`/`verify` de l'orchestrateur).
