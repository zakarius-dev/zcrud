# Code-review — fp-5-3 (geoArea style picker) — correction du finding LOW

Périmètre : `packages/zcrud_geo/` UNIQUEMENT. Aucun autre package touché (fp-2-1 sur `zcrud_core` tournant en parallèle). API publique du picker inchangée.

## Findings × statut × preuve

| # | Sévérité | Finding | Statut | Correctif retenu | Preuve |
|---|----------|---------|--------|------------------|--------|
| 1 | LOW | `_StylePreview.borderColor` = **paramètre mort** : déclaré (l.213), passé par le parent (l.155), mais jamais lu par `build` — la bordure de la vignette utilisait `stroke` (la DONNÉE). AC5 exige un **cadre NEUTRE du thème** délimitant la vignette du fond. Défaut de contraste : si `stroke ≈ couleur de fond`, la vignette perd sa délimitation. | **CORRIGÉ (fix cadre neutre, préféré)** | `borderColor` câblé comme **cadre EXTÉRIEUR neutre** (`ZcrudTheme.fieldBorderColor ?? colorScheme.outline`) toujours visible, DISTINCT du **liseré INTÉRIEUR** rendant le trait `stroke` (donnée). Structure : `Container(key: outerFrameKey, border=borderColor) > padding > DecoratedBox(key: innerSwatchKey, fill + border=stroke)`. | Test porteur AC5 : monte le picker avec `fillColorArgb == strokeColorArgb == 0xFF123456` (trait == fond) ⇒ le cadre extérieur (`ValueKey('z_geo_style_preview_frame')`) porte TOUJOURS la couleur neutre du thème (`fieldBorderColor ?? outline`), DISTINCTE du stroke ; le liseré intérieur rend bien `stroke`. Falsifiable : ancien code sans cadre (border=stroke, pas de clé) ⇒ `findsOneWidget` sur la clé + assertion couleur neutre échouent. `flutter test .../z_geo_shape_style_picker_test.dart --plain-name "AC5 — cadre neutre"` → +1 All tests passed. |

## Vérif verte rejouée (réellement sur disque)

- `dart analyze packages/zcrud_geo` → **RC=0** ("No issues found!").
- `flutter test packages/zcrud_geo` → **RC=0, 174/174 verts** (était 173, +1 test porteur AC5).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIQUE OK**, **CORE OUT=0 OK**, RC=0.
- `flutter test .../isolation_gates_test.dart` → vert (barrel sans symbole SDK carte + gate RTL statique `EdgeInsets.only` OK ; le nouveau `EdgeInsets.all(3)` n'est pas banni).
- `git status packages/zcrud_geo/pubspec.yaml` → vide : **pubspec geo INTOUCHÉ** (aucune dep couleur lourde, CORE OUT=0 préservé).

## Fichiers modifiés (zcrud_geo uniquement)

- `packages/zcrud_geo/lib/src/presentation/z_geo_shape_style_picker.dart` — `_StylePreview` : cadre neutre extérieur (thème) + vignette intérieure (stroke), clés `outerFrameKey`/`innerSwatchKey`.
- `packages/zcrud_geo/test/z_geo_shape_style_picker_test.dart` — groupe « AC5 — cadre neutre du thème délimitant la vignette d'aperçu » (test porteur).
