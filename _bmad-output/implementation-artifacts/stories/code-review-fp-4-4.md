# Code-review — fp-4-4 (color multiple, cœur)

Périmètre : `packages/zcrud_core/` uniquement (champ couleur multiple `ZColorMultiFieldWidget`).
Date : 2026-07-18 · Modèle : Opus 4.8 (1M).

## Findings × statut × preuve

| # | Sévérité | Finding | Statut | Correctif | Preuve (rouge-avant + vert-après) |
|---|----------|---------|--------|-----------|-----------------------------------|
| MED-1 | MEDIUM (bug UX contraste) | Glyphe coche/croix peint sur la pastille ARGB coloré via `onPrimary/onSurface` (couleurs du **thème de l'app**, axe indépendant de la pastille) ⇒ en `ThemeData.dark()`, glyphe sombre-sur-pastille-sombre, croix de suppression quasi invisible. | **CORRIGÉ** | Helper partagé `_glyphOn(int argb)` : contraste piloté par la luminosité de la **PASTILLE** (`ThemeData.estimateBrightnessForColor(Color(argb))`), blanc/noir **dérivés par HSV** (`HSVColor.fromAHSV(1,0,0,1/0).toColor()` — pur-données, respecte la garde FR-26 qui bannit `Colors.`/`Color(0x…)`). Appliqué à `_CheckSwatch` (coche) ET `_RemovableSwatch` (croix). | Tests porteurs (f) pastille SOMBRE `0xFF262626` ⇒ glyphe blanc + (g) pastille CLAIRE `0xFFE6E6E6` ⇒ glyphe noir, montés sous `ThemeData.dark()` ; assertions couleur ET brightness opposée. **Rouge-avant** : ré-appliqué l'ancien heuristique `onPrimary/onSurface` ⇒ (f)+(g) échouent (`00:00 +0 -2`). Vert-après : 15/15. |
| MED-2 | MEDIUM (trou de test) | `_addColor` (bouton « ajouter une couleur ») portait 3 comportements non testés : append+**dédup** (`!current.contains(picked)`), **défensif AD-10** (`try/catch` seam ⇒ aucune écriture si throw), repli `ZColorPickerDialog`. Aucun test ne l'actionnait. | **CORRIGÉ** (tests seulement — code déjà conforme) | Ajout de 3 tests porteurs actionnant réellement le bouton via `find.bySemanticsLabel('Add a color')` + seam `ZColorPicker` injecté par `ZcrudScope.colorPicker`. | (h) seam renvoie une nouvelle couleur ⇒ ajoutée à la tranche ; (i) seam renvoie une couleur **déjà présente** ⇒ dédup (tranche reste à 1) ; (j) seam qui **throw** ⇒ aucune écriture + `takeException` null. **Rouge-avant** : sans le garde `!current.contains(picked)` ⇒ (i) échoue ; sans le `try/catch` ⇒ (j) échoue (`00:00 +0 -1` chacun). |
| LOW | LOW (double annonce a11y) | `Semantics(container:true, label: resolvedLabel)` + `Text(resolvedLabel)` visible ⇒ le libellé est annoncé deux fois. | **CORRIGÉ** | Retrait du `label:` sur le `Semantics(container:true)` — le `Text` visible fournit déjà le nom accessible (motif fp-5-1). | Test (k) : `find.bySemanticsLabel('Colors')` ⇒ `findsOneWidget`. **Rouge-avant** : réintroduire `label: resolvedLabel` ⇒ (k) échoue (le libellé apparaît 2×). |
| LOW-dette | LOW (dette pré-existante, **non corrigée**) | Le champ **simple** `z_color_field_widget.dart` porte le même motif `Semantics(container:true, label:) + Text`. | **SIGNALÉ** (hors périmètre) | — | Non touché : hors périmètre de la revue fp-4-4 (le champ multiple) ; correction non triviale-sûre en isolation. À traiter dans une story ciblée sur le champ mono. |

## Vérif verte rejouée (réelle, disque)

- `dart analyze packages/zcrud_core` → **RC=0** (2 infos pré-existantes non liées, dans `test/presentation/list/z_batch_action_test.dart`).
- `flutter test packages/zcrud_core` → **1013 passed** (1007 initiaux + 6 nouveaux tests f/g/h/i/j/k), RC=0.
- `flutter test .../color_multiple_test.dart` isolé → **11/11 passed**.
- `flutter test .../style_purity_test.dart` (garde FR-26) → **vert** (aucun littéral `Colors.` — blanc/noir dérivés HSV).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK · CORE OUT=0 OK** (out-degree(zcrud_core)=0).

## Invariants / conformité

- **API publique inchangée** : aucun type/signature exportés modifiés (`_glyphOn` privé ; params de test seulement dans le fichier de test).
- **FR-26** (aucun style codé en dur) : contraste dérivé par HSV, pas de `Colors.`/`Color(0x…)` — garde `style_purity_test` verte.
- **AD-10** (parse/seam défensif) : conservé et désormais **prouvé par test** (seam qui throw ⇒ aucune écriture).
- **AD-13** (a11y) : contraste glyphe/pastille garanti quel que soit le thème ; libellé annoncé une seule fois.
- **CORE OUT=0** : aucune dépendance ajoutée.
- Seul `packages/zcrud_core/` modifié (zcrud_field_extras non touché — workstream fp-5-2 disjoint).
