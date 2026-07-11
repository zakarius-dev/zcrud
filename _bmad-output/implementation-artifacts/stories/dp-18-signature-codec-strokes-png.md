# Story DP.18: ZSignatureCodec strokes ↔ PNG (parité DODLP — M15)

Status: review

## Story

As développeur consommateur de zcrud (migration DODLP → zcrud),
I want un **codec pluggable NEUTRE** convertissant les strokes vectoriels normalisés de zcrud en **PNG** (`Uint8List`, format DODLP) et inspectant un PNG (magic-number/dimensions),
so that les signatures DODLP existantes (bitmap PNG) et les consommateurs PDF/tiers restent compatibles, **sans** tirer `dart:ui`/rasterisation lourde dans le cœur (AD-1, graphe `zcrud_core` OUT=0).

Périmètre : **`zcrud_core` uniquement** (+ tests). Gap : **M15** (`signature` format PNG vs strokes). Réf : `docs/dodlp-edition-parity-gap.md` §2.5 (M15), §3 MAJOR.

## Acceptance Criteria

1. **AC1** — `ZSignatureCodec` (`const`, pluggable) expose la (dé)sérialisation **pur-Dart** strokes ↔ valeur-de-tranche (`Map` versionnée) — **source unique de vérité** partagée avec `ZSignatureFieldWidget` (qui délègue `decode`/`encode`). *(IMPLÉMENTÉ : `z_signature_codec.dart` ; widget refactoré.)*
2. **AC2** — Round-trip exact : `valueFromStrokes` → `strokesFromValue` restitue les strokes normalisés `[0,1]` ; strokes vides ⇒ `null`.
3. **AC3** — **strokes → PNG** (`toPng`) : la rasterisation `dart:ui` (bannie du cœur par `presentation_purity`, AD-1) est **DÉFÉRÉE** à un seam host-fourni `ZSignatureRasterizer`. Aucun rasterizer ⇒ `toPng` retourne `null` (dégradation propre). *(IMPLÉMENTÉ.)*
4. **AC4** — Spec de rasterisation **pur-données** `ZSignatureRasterSpec` (dimensions + style neutre ; couleur = donnée ARGB, jamais un littéral — masque exprimé `0xFF << 24`, FR-26).
5. **AC5** — Inspection PNG pur-Dart : `isPng` (magic-number) + `pngSize` (IHDR big-endian) — défensifs (non-PNG/trop court ⇒ `false`/`null`).
6. **AC6** — Défensif (AD-10) : valeur corrompue ⇒ `[]`/`null` (jamais de throw) ; rasterizer défaillant (throw/`null`) ⇒ `toPng` retourne `null` sans crash.
7. **AC7** — Neutralité (AD-1) : aucune dépendance lourde ; seuls `Offset`/`Size` (`flutter/widgets`) + `Uint8List` (`dart:typed_data`) ; graphe OUT=0 inchangé.

## Tests (implémentés, verts)

- `dp18_signature_codec_test.dart` (11 tests) : round-trip strokes↔Map, vides→null, corrompu→[], `isPng`/`pngSize`, `toPng` sans rasterizer/défaillant/vide, **PREUVE de seam** (rasterizer `dart:ui` RÉEL côté test → PNG valide ré-inspecté via `isPng`/`pngSize`).

## Vérif verte (rejouée sur disque)

`dart analyze packages/zcrud_core` RC=0 · `flutter test` RC=0 (857) · `graph_proof` CORE OUT=0 · `style_purity` vert · domain entrypoint purity RC=0.

## Seams / impls déférés

- **Rasterisation réelle** (`PictureRecorder`/`Canvas`/`toByteData(png)`) : **DÉFÉRÉE** à un binding/`zcrud_export`/app via `ZSignatureRasterizer` (AD-1 — `dart:ui` interdit dans le cœur). Le test fournit un rasterizer `dart:ui` réel prouvant que le seam est implémentable.
- **PNG → strokes** (vectorisation) : hors périmètre (non fiable) ; le codec expose l'inspection PNG + la voie strokes→PNG. La migration DODLP PNG conserve le bitmap opaque côté consommateur.
