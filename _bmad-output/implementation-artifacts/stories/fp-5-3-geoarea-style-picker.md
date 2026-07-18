# Story 5.3: `geoArea` — UI style-picker fill/stroke (`zcrud_geo`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a développeur consommateur,
I want styliser une zone géographique (polygone/cercle) via une toolbar fill/stroke qui **réutilise le seam couleur du cœur**,
so that je couvre le style geofence de DODLP (`flex_color_picker`) sans tirer de picker couleur lourd dans `zcrud_geo` ni le cœur.

## Contexte & cadrage (LIRE EN PREMIER)

**Ce qui EXISTE DÉJÀ (ne pas recréer) :**
- Le **modèle** `ZGeoShapeStyle` est prêt : couleurs `fillColorArgb`/`strokeColorArgb` (ARGB 32 bits `int?`, jamais `Color`), `strokeWidth` (`int`, défaut 3), `opacity` (`double` borné `[0,1]`), parse défensif `fromMapSafe` (AD-10), `copyWith`, `==`/`hashCode`. `[Source: packages/zcrud_geo/lib/src/domain/z_geo_shape_style.dart]`
- L'**adaptateur OSM** consomme déjà ce style (couleurs ARGB → `Color` confiné à l'adaptateur, repli thème FR-26) : `z_osm_map_adapter.dart:100-108` lit `shapeStyle?.strokeColorArgb`/`fillColorArgb`/`strokeWidth`. `[Source: packages/zcrud_geo/lib/src/presentation/adapters/z_osm_map_adapter.dart#shapeStyle]`
- Le **seam couleur du cœur** : le typedef `ZColorPicker` (seam injecté via `ZcrudScope.colorPicker`) **et** le picker built-in neutre `ZColorPickerDialog` (`@visibleForTesting`, type **public**) sont **exportés par le barrel** `package:zcrud_core/zcrud_core.dart` (`export '…/z_color_field_widget.dart'`). `zcrud_geo` importe déjà tout le barrel core. `[Source: packages/zcrud_core/lib/zcrud_core.dart:38 ; packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart:41-46,280-306]`
- Le seam est atteint dans le champ `color` par `ZcrudScope.maybeOf(context)?.colorPicker`, sinon repli `showDialog<int>(builder: _ZColorPickerDialog(...))`. `[Source: z_color_field_widget.dart:97-129]`

**Ce qui MANQUE (le livrable de cette story) :** le **WIDGET picker de style** permettant à l'utilisateur de **CHOISIR** un `ZGeoShapeStyle` (couleur de remplissage, couleur de trait, épaisseur de trait). Grep négatif prouvant l'absence : `grep -rn "maybeOf\|colorPicker\|ZColorPickerDialog\|ZColorPicker" packages/zcrud_geo/lib packages/zcrud_geo/test` → **NONE** (aucun usage du seam couleur dans `zcrud_geo` aujourd'hui). Le row 21 de la matrice le confirme : « **UI picker fill/stroke ABSENTE** ». `[Source: docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md:57,103]`

**Frontières (HORS-story) :**
- **PAS** l'éditeur geofence interactif complet (bascule de géométrie à chaud, dessin de sommets) — seul le **picker de STYLE** est en scope. `[Source: FIELD-PACKAGE-MATRIX.md:57 « Reporté à l'éditeur geofence interactif »]`
- **PAS** d'écriture dans `zcrud_core` ni dans un autre satellite — `zcrud_geo` UNIQUEMENT. Si un besoin cœur émerge (ex. le seam n'est pas exporté), **STOP + signaler à l'orchestrateur** (jamais d'écriture cœur ici — story satellite parallélisable).
- **PAS** le showcase/harnais `example/` (porté par Epic 3.2).
- **PAS** de style sur marqueur/point (icon/infoWindow) : le picker couvre **fill + stroke** (couleur remplissage, couleur trait, épaisseur trait), champs geofence polygone/cercle. `opacity`/`visible` restent modifiables via `copyWith` mais sont hors du minimum requis (les inclure est un bonus si trivial et directionnel).

## Acceptance Criteria

1. **Nouveau widget de style-picker dans `zcrud_geo`** — Un widget public (proposé : `ZGeoShapeStylePicker`) est ajouté sous `packages/zcrud_geo/lib/src/presentation/` et exporté par le barrel `lib/zcrud_geo.dart`. Il prend en entrée un `ZGeoShapeStyle` courant (nullable → défaut sûr `const ZGeoShapeStyle()` si `null`/corrompu, AD-10) et notifie `onChanged(ZGeoShapeStyle)` à chaque modification. **Aucune** nouvelle dépendance lourde n'est ajoutée au `pubspec.yaml` de `zcrud_geo` (surtout PAS `flex_color_picker`). `[Source: epics 5.3 ; FIELD-PACKAGE-MATRIX.md:57]`

2. **Réutilisation du seam couleur du cœur (pas de 2ᵉ picker)** — La sélection de la couleur de remplissage ET de la couleur de trait passe par le **même** seam que le champ `color` : `ZcrudScope.maybeOf(context)?.colorPicker` s'il est injecté, **sinon** repli sur `ZColorPickerDialog` (built-in neutre du cœur) via `showDialog<int>`. **Aucun** nouveau dialog/picker couleur n'est écrit dans `zcrud_geo` (grep négatif : `grep -rn "class .*ColorPicker\|class .*ColorDialog" packages/zcrud_geo/lib` → NONE hormis l'usage du type importé). `[Source: z_color_field_widget.dart:41-46,97-129]`

3. **Association picker → `ZGeoShapeStyle` réellement prouvée (présence ≠ association)** — Choisir une couleur de remplissage met à jour `style.fillColorArgb` (via `copyWith`) ; choisir une couleur de trait met à jour `style.strokeColorArgb` ; ajuster l'épaisseur met à jour `style.strokeWidth`. Un **test porteur** vérifie que `onChanged` émet un `ZGeoShapeStyle` dont **le champ ciblé a changé vers la valeur exacte** choisie et que **les autres champs sont préservés** (le test rougit si le widget renvoie un style inchangé, un mauvais champ, ou écrase les champs voisins). `[Source: z_geo_shape_style.dart:184-215 copyWith]`

4. **Épaisseur de trait éditable, bornée** — L'épaisseur de trait est réglable (slider ou stepper) sur une plage sensée (≥ 0 ; borne haute raisonnable, ex. 20), valeur `int` reflétée dans `strokeWidth`. Défensif : aucune valeur négative/non finie n'atteint le modèle. `[Source: z_geo_shape_style.dart:53-54,161-166]`

5. **Aperçu de style piloté par DONNÉES + FR-26 (aucun style codé en dur)** — Un aperçu montre les couleurs courantes (remplissage/trait) et l'épaisseur. Les couleurs affichées dérivent des données ARGB du `ZGeoShapeStyle` (via `Color(argb)` local à la couche presentation, comme l'adaptateur) ; la bordure/le fond de l'aperçu et tout accent proviennent du **`ZcrudTheme`/`Theme.of(context)`** (repli), jamais d'un littéral de couleur. Un `fillColorArgb`/`strokeColorArgb` `null` retombe sur un **défaut neutre issu du thème** (pas un `Color` en dur), cohérent avec le repli de l'adaptateur OSM. `[Source: z_osm_map_adapter.dart#shapeStyle ; z_color_field_widget.dart:74-88 palette dérivée]`

6. **a11y / RTL (AD-13)** — Chaque cible interactive (bouton « remplissage », bouton « trait », contrôle d'épaisseur) est **≥ 48 dp**, porte un `Semantics` explicite (label distinct fill vs stroke — **pas de double annonce** : un seul `Semantics` porteur par cible, pas de label redondant enveloppant + enfant). La mise en page est **directionnelle** : `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`, jamais `left/right`. Le contraste de l'aperçu reste lisible (bordure thème). `[Source: z_color_field_widget.dart:142-202 ; CLAUDE.md AD-13]`

7. **Libellés via l10n injectée (aucun libellé en dur)** — Tous les libellés (fill/stroke/épaisseur/titre) passent par `label(context, 'geo.style.*', fallback: '…')` (helper du barrel core déjà utilisé dans `z_geo_field_widget.dart`), jamais de `String` figée dans l'UI. `[Source: z_geo_field_widget.dart:611,636,933]`

8. **Défensif AD-10 — style corrompu → défaut sûr, seam défaillant → pas d'écriture** — Si le style d'entrée est `null` ou incohérent, le widget part de `const ZGeoShapeStyle()` sans throw. Si le seam couleur injecté lève une exception, le comportement suit le cœur : `catch (_) → picked = null` (aucune écriture, jamais de crash du formulaire). Un **test porteur** exerce le seam qui throw et vérifie l'absence d'émission `onChanged`. `[Source: z_color_field_widget.dart:106-115,322-333 ; z_geo_shape_style.dart:117-139]`

9. **CORE OUT=0 préservé + isolation (AD-1)** — `zcrud_geo` dépend du seul `zcrud_core` (+ ses deps carte existantes `flutter_map`/`latlong2`/`google_maps_flutter`). Aucune arête nouvelle, aucune dep couleur lourde, aucun symbole SDK carte fuit dans le barrel. Le gate d'isolation existant (`test/isolation_gates_test.dart`) reste vert ; le `pubspec.yaml` de `zcrud_geo` n'acquiert **aucune** ligne de dépendance nouvelle. `[Source: packages/zcrud_geo/test/isolation_gates_test.dart ; pubspec.yaml deps]`

10. **Statut showcase** — L'entrée `geoArea` de la matrice/showcase passe conceptuellement de « ABSENT » à « livré » (le câblage `example/` effectif reste Epic 3.2 — ici on livre le widget + son export, prêt à consommer). `[Source: epics 5.3 « l'entrée showcase passe de "ABSENT" à "livré" »]`

## Tasks / Subtasks

- [x] **Task 1 — Widget `ZGeoShapeStylePicker`** (AC: 1, 3, 4, 5) — `packages/zcrud_geo/lib/src/presentation/z_geo_shape_style_picker.dart`
  - [x] `StatelessWidget` prenant `ZGeoShapeStyle? style`, `ValueChanged<ZGeoShapeStyle> onChanged`, `bool readOnly = false`, `Key?`.
  - [x] Résoudre le style effectif : `style ?? const ZGeoShapeStyle()` (AC 8).
  - [x] Aperçu piloté données (couleur remplissage/trait via `Color(argb)` local, bordure `ZcrudTheme`/`Theme.of`) ; `null` → défaut thème neutre (AC 5).
  - [x] Contrôle d'épaisseur (stepper `int` borné `[0,20]`, déterministe/testable) → `onChanged(effective.copyWith(strokeWidth: v))` (AC 4).
- [x] **Task 2 — Réutilisation du seam couleur** (AC: 2, 3, 8) — méthode privée `_pickColor(context, initialArgb) → Future<int?>`
  - [x] `ZcrudScope.maybeOf(context)?.colorPicker` prioritaire ; try/catch → `null` (AC 8, calqué sur `z_color_field_widget.dart:106-115`).
  - [x] Repli `showDialog<int>(builder: (_) => ZColorPickerDialog(initialArgb:…, enableAlpha:…, recentColors: const []))`.
  - [x] Bouton « remplissage » : `picked != null → onChanged(effective.copyWith(fillColorArgb: picked))` ; bouton « trait » : `strokeColorArgb`.
- [x] **Task 3 — a11y/RTL + l10n** (AC: 6, 7)
  - [x] Cibles ≥ 48 dp, `Semantics` porteur unique par cible (`excludeSemantics: true`, labels distincts fill/stroke, pas de double annonce).
  - [x] `EdgeInsetsDirectional`/`TextAlign.start` exclusivement (gate RTL statique vert).
  - [x] Libellés via `label(context, 'geo.style.*', fallback: …)`.
- [x] **Task 4 — Export barrel** (AC: 1, 9) — ajouté `export 'src/presentation/z_geo_shape_style_picker.dart';` à `lib/zcrud_geo.dart`. Aucun symbole SDK carte exporté ; `pubspec.yaml` INTOUCHÉ.
- [x] **Task 5 — Tests porteurs** (AC: 3, 4, 6, 8, 9) — `packages/zcrud_geo/test/z_geo_shape_style_picker_test.dart`
  - [x] **Association fill** : seam retournant ARGB connu → tap remplissage → `fillColorArgb == ARGB` ET `strokeColorArgb`/`strokeWidth` préservés (R3).
  - [x] **Association stroke** : idem pour `strokeColorArgb`.
  - [x] **Épaisseur** : stepper → `strokeWidth` ±1, couleurs préservées ; bornes `[0,20]` (désactivé aux extrêmes).
  - [x] **Seam défaillant (AD-10)** : seam qui `throw` → aucune émission `onChanged`, aucune exception remontée.
  - [x] **Défaut sûr** : `style: null` → monte sans throw, part de `ZGeoShapeStyle()`.
  - [x] **a11y** : `tester.getSize` cibles ≥ 48 dp ; un seul `Semantics` fill/stroke ; RTL sans exception.
  - [x] Le gate `isolation_gates_test.dart` reste vert (rejeu : 173 tests geo verts).
- [x] **Task 6 — Vérif verte** (AC: 9) — geo non annoté → `generate` no-op (aucun `.g.dart`) ; `dart analyze packages/zcrud_geo` RC=0 ; `flutter test packages/zcrud_geo` RC=0 ; `graph_proof` ACYCLIQUE + CORE OUT=0.

## Dev Notes

### Patterns & contraintes d'architecture

- **AD-1 / CORE OUT=0** : `zcrud_geo → zcrud_core` uniquement (+ deps carte existantes). Le seam couleur vit **dans le cœur** et est **importé** (jamais réimplémenté). **Interdit** : ajouter `flex_color_picker` ou tout package picker à `zcrud_geo/pubspec.yaml`. Si le seam n'était pas exporté (il l'est, vérifié : `zcrud_core.dart:38`), il faudrait toucher le cœur → **STOP + signaler** (hors scope satellite).
- **AD-2 / SM-1** : le widget est un `StatelessWidget` piloté par `value + onChanged` (pas d'état de formulaire interne, pas de `TextEditingController` pour les couleurs — la couleur est une **donnée ARGB**). Le parent (formulaire) porte la tranche et rebuild granulaire. Ne pas introduire de `setState` à l'échelle formulaire.
- **AD-10 (défensif)** : `style ?? const ZGeoShapeStyle()` ; seam qui throw → `catch (_)` → pas d'écriture ; épaisseur bornée avant d'atteindre le modèle. Ne JAMAIS throw depuis l'UI.
- **AD-13 (a11y/RTL)** : ≥ 48 dp, `Semantics` explicites, variantes directionnelles seules. Contraste via thème.
- **FR-26 (aucun style en dur)** : couleurs affichées = données ARGB (`Color(argb)` local presentation, comme l'adaptateur OSM `z_osm_map_adapter.dart:100-108`) ; bordures/accents/défauts = `ZcrudTheme`/`Theme.of(context)`.

### Fichiers à toucher (source tree)

| Fichier | Action | Note |
|---|---|---|
| `packages/zcrud_geo/lib/src/presentation/z_geo_shape_style_picker.dart` | **NEW** | le widget |
| `packages/zcrud_geo/lib/zcrud_geo.dart` | **UPDATE** | 1 ligne `export …style_picker.dart;` |
| `packages/zcrud_geo/test/z_geo_shape_style_picker_test.dart` | **NEW** | tests porteurs |
| `packages/zcrud_geo/pubspec.yaml` | **NE PAS TOUCHER** | CORE OUT=0 / aucune dep nouvelle |
| `zcrud_core/*` | **NE PAS TOUCHER** | seam déjà exporté ; sinon STOP+signaler |

### Réutilisation du seam — extrait de référence (à calquer, pas à recopier tel quel)

Le champ `color` du cœur ouvre le picker ainsi (`z_color_field_widget.dart:97-129`) : seam injecté `ZcrudScope.maybeOf(context)?.colorPicker` prioritaire (dans un `try/catch (_) → null`), sinon `showDialog<int>` sur `ZColorPickerDialog(initialArgb:, enableAlpha:, recentColors:)`. **Réutiliser exactement ce chemin** pour fill et pour stroke, en n'écrivant que le mapping `int? picked → copyWith(fill|stroke)`. Le typedef `ZColorPicker` et la classe `ZColorPickerDialog` sont accessibles via `import 'package:zcrud_core/zcrud_core.dart';` (déjà présent dans `z_geo_field_widget.dart:30`).

### Testing standards

- `flutter_test` + `testWidgets`. Monter le widget sous `MaterialApp` + `ZcrudScope` (pour injecter/omettre `colorPicker` et fournir la l10n/thème). Cf. patrons existants `test/z_geo_field_widget_test.dart` et `test/support/fake_map_adapter.dart`.
- **Tests porteurs (R3)** : chaque assertion doit **rougir** si la logique casse — vérifier la **valeur exacte** émise et la **préservation** des champs voisins (pas seulement « onChanged a été appelé »). Éviter le test tautologique.
- **Preuve d'absence = grep négatif** : le dev doit prouver « aucune dep couleur lourde ajoutée » (`git diff packages/zcrud_geo/pubspec.yaml` vide) et « aucun nouveau picker » (grep).

### Project Structure Notes

- Le widget suit la convention `Z`-préfixe, snake_case fichier, API publique via barrel, impl sous `lib/src/presentation/`. Cohérent avec `z_geo_field_widget.dart`.
- Pas de codegen : `zcrud_geo` n'a pas de modèle `@ZcrudModel` annoté déclenchant build_runner pour ce widget ; `melos run generate` doit rester no-op côté geo (confirmer, ne pas committer de `.g.dart` fantôme).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Story 5.3] (AC epic, FR-28, AD-8/AD-52, NFR-2)
- [Source: packages/zcrud_geo/lib/src/domain/z_geo_shape_style.dart] (modèle fill/stroke/strokeWidth, copyWith, fromMapSafe défensif)
- [Source: packages/zcrud_geo/lib/src/presentation/adapters/z_osm_map_adapter.dart#shapeStyle] (consommation du style, repli thème FR-26)
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart:41-46,97-129,280-306] (seam `ZColorPicker`, `ZColorPickerDialog`, chemin d'ouverture)
- [Source: packages/zcrud_core/lib/zcrud_core.dart:38] (export du seam couleur)
- [Source: packages/zcrud_core/lib/src/presentation/zcrud_scope.dart:155] (`ZcrudScope.colorPicker`)
- [Source: docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md:57,103,177] (row 21 geoArea, gap UI ABSENTE, réutiliser seam)
- [Source: docs/dodlp-form-integration-study-2026-07-17/07-field-color.md:245-295] (modèle prêt, UI picker absente, réutiliser le seam §1)
- [Source: packages/zcrud_geo/test/isolation_gates_test.dart] (gate CORE OUT=0 à garder vert)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m]

### Debug Log References

- `dart analyze packages/zcrud_geo` → RC=0, "No issues found!".
- `flutter test packages/zcrud_geo/test/z_geo_shape_style_picker_test.dart` → 11/11 verts.
- `flutter test packages/zcrud_geo` → 173/173 verts (inclut `isolation_gates_test.dart` + gate RTL statique).
- `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK, CORE OUT=0 OK.
- `git diff packages/zcrud_geo/pubspec.yaml` → vide (aucune dep ajoutée, PAS de `flex_color_picker`).
- Aucun `.g.dart`/`.freezed.dart` dans `zcrud_geo` (non annoté → `generate` no-op).
- **Post-review LOW (cadre neutre AC5)** : `flutter test packages/zcrud_geo` → **174/174 verts** (nouveau test porteur AC5 ajouté) ; `dart analyze packages/zcrud_geo` RC=0 ; `graph_proof.py` ACYCLIQUE + CORE OUT=0 ; `isolation_gates_test.dart` vert ; pubspec geo INTOUCHÉ.

### Completion Notes List

- Widget `ZGeoShapeStylePicker` (`StatelessWidget` public) : fill/stroke via le **seam couleur du cœur** (`ZcrudScope.colorPicker` prioritaire, `try/catch → null`, repli `ZColorPickerDialog`) — AUCUN 2e picker, AUCUNE dep couleur lourde. Épaisseur via stepper `int` borné `[0,20]` (déterministe/testable vs `Slider`).
- Association picker→modèle PROUVÉE (R3) : le champ ciblé passe à la valeur EXACTE choisie via `copyWith`, les champs voisins (stroke/width lors d'un choix fill, etc.) sont PRÉSERVÉS — les tests rougissent si un mauvais champ est écrit ou si un voisin est écrasé.
- AD-10 : `style ?? const ZGeoShapeStyle()` (défaut sûr) ; seam qui throw → aucune émission ; épaisseur clampée avant le modèle.
- AD-13 : cibles ≥ 48 dp ; un seul `Semantics` porteur par cible (`excludeSemantics: true` → pas de double annonce) ; insets/textAlign directionnels (gate RTL statique vert).
- FR-26 : couleurs = données ARGB (`Color(argb)` local presentation) ; bordures/défauts = `ZcrudTheme`/`Theme.of` (aucun littéral).
- **AC5 (post-review LOW)** : la vignette d'aperçu porte désormais un **cadre EXTÉRIEUR neutre** issu du thème (`_StylePreview.borderColor` = `ZcrudTheme.fieldBorderColor ?? colorScheme.outline`) — toujours visible, il délimite la vignette du fond — DISTINCT du **liseré INTÉRIEUR** qui rend le trait choisi (`stroke`, la donnée). Auparavant `borderColor` était un paramètre mort (déclaré/passé mais jamais lu par `build`) : si `stroke ≈ fond`, la vignette perdait sa délimitation.
- AD-1 : `pubspec.yaml` de `zcrud_geo` INTOUCHÉ, barrel n'exporte aucun symbole SDK carte, gate isolation vert, CORE OUT=0. Cœur NON touché par cette story (les modifs `zcrud_core` du working tree proviennent des workstreams parallèles fp-2-1 / fp-5-2).

### File List

- `packages/zcrud_geo/lib/src/presentation/z_geo_shape_style_picker.dart` (NEW ; UPDATE post-review — câblage cadre neutre AC5 dans `_StylePreview`)
- `packages/zcrud_geo/lib/zcrud_geo.dart` (UPDATE — 1 ligne export)
- `packages/zcrud_geo/test/z_geo_shape_style_picker_test.dart` (NEW ; UPDATE post-review — groupe test porteur AC5 cadre neutre)
