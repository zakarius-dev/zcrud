# Étude parité DODLP → zcrud — Famille COULEUR

Extension de `STUDY.md` (2026-07-16) — cartographie exhaustive des usages de
sélection de couleur **vivants** dans DODLP (`/home/zakarius/DEV/dodlp-otr`,
lecture seule) et confrontation à la couverture `zcrud` (natif `zcrud_core` /
satellite / ABSENT).

**Verdict résumé** : l'essentiel est déjà couvert par la story **DP.17**
(statut `review`, `_bmad-output/implementation-artifacts/stories/dp-17-number-devise-pourcentage-color-picker.md`)
— `ZColorFieldWidget` (`packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart`)
reproduit la palette de swatches DODLP + fournit un picker enrichi
(teinte/saturation/luminosité/opacité/hex/récents) **100 % Flutter neutre**,
avec un **seam `ZcrudScope.colorPicker`** pour injecter `flex_color_picker`
côté binding si un consommateur veut la roue HSV exacte. Deux écarts
persistent : (1) le **variant multi-couleurs** (`field.multiple`, package
legacy `color_picker_field`) n'a **aucun équivalent** natif ; (2) le
**picker fill/stroke du geofence** (`showColorPickerDialog` dans
`geofence_field.dart`) n'a pas d'UI portée côté `zcrud_geo` (seulement le
modèle de données `ZGeoShapeStyle`, pas encore de widget « toolbar
styling »).

---

## 1. Champ couleur simple (`EditionFieldTypes.color`, non-multiple)

**`EditionFieldType` zcrud correspondant** : `EditionFieldType.color`
(`packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart:124`).

### Package DODLP + usage vivant

- **Package** : `flex_color_picker: ^3.7.1` (`pubspec.yaml:76`).
- **Fichier** : `lib/modules/data_crud/presentation/views/edition_screen.dart`
  — dispatch `case EditionFieldTypes.color:` lignes **1669-1850** (branche
  non-multiple : lignes **1743-1850**).
- **API/variantes réellement utilisées** (lignes 1773-1828) :
  - `showColorPickerDialog(context, initialColor, …)` — **dialog** modal (pas
    inline).
  - `pickersEnabled: {wheel: true, primary: true, accent: true, custom: true}`
    — 4 onglets : roue HSV, couleurs primaires Material, accents Material,
    personnalisé.
  - `enableOpacity: true` — canal alpha réglable.
  - `showColorCode: true`, `colorCodeHasColor: true`, `showColorName: true`
    (via `ColorTools.nameThatColor`) — saisie/affichage hex + nom de couleur
    dérivé.
  - `showRecentColors: true`, `maxRecentColors: 10`,
    `recentColors: field.recentColors` (`models.dart:663,781` —
    `List<Color> recentColors = const []` au niveau du field spec).
  - `wheelDiameter: 165`, dimensions custom (`width/height: 40`,
    `borderRadius: 40`, `spacing/runSpacing: 2`), sous-titres personnalisés
    (« Variantes », « Opacité »).
  - `copyPasteBehavior` (long-press menu actif, boutons copier/coller
    désactivés), `actionButtons` (OK + fermer, pas de boutons de dialog
    natifs), `constraints` (min 480×320, max width 320).
  - Affichage hors-dialog : `ListTile` avec `subtitle: Text(ColorTools
    .nameThatColor(_initialColor))` coloré, `trailing: ColorIndicator`
    (rond 40×40, `elevation: 1`).
- **Format stocké** : le `Color` Dart brut est passé à `invokeItemSetter`
  (`functions.dart:262-283`, réflexion `reflector.invokeSetter` ou repli
  `toMap()/toJson()`) — la sérialisation finale (int ARGB vs `Color`) dépend
  du modèle cible ; la lecture (lignes 1743-1752) est **défensive** et
  accepte `Color` / `String` (`int.parse`) / `int`.

### Rendu visuel (ce qui casserait la parité)

`Card` + `ListTile` avec nom de couleur en italique coloré + `ColorIndicator`
rond ; dialog modal 320×480 avec 4 onglets (roue/primaires/accents/hex),
sliders opacité, champ hex éditable, 10 couleurs récentes, sous-titres
français « Variantes »/« Opacité ».

### Couverture zcrud

**Natif** — `ZColorFieldWidget`
(`packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart`) :

```
grep -n "class ZColorFieldWidget\|class ZColorPickerDialog\|ZColorConfig" \
  packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart \
  packages/zcrud_core/lib/src/domain/edition/z_field_config.dart
```
→ RC=0, trouvé : `ZColorFieldWidget` (l.49), `ZColorPickerDialog`
built-in (l.281), `ZColorConfig` (`z_field_config.dart:111`).

- Valeur en tranche : `int` ARGB 32 bits (0xAARRGGBB) — format stable, pas de
  `Color` Dart en signature.
- **Palette de swatches** (15 dans DODLP legacy vs 12+3 neutres dérivés HSV
  ici — parité *fonctionnelle*, pas pixel-exacte des teintes).
- **Bouton « couleur personnalisée »** → ouvre soit `ZcrudScope.colorPicker`
  (seam injectable, `zcrud_scope.dart:66,143`) soit le picker built-in
  neutre (`_ZColorPickerDialog`) : sliders teinte/saturation/luminosité +
  opacité optionnelle (`ZColorConfig.enableAlpha`) + champ hex éditable +
  couleurs récentes (`ZColorConfig.recentColors`/`showRecent`).
- **Seam DP-17 (M14)** documenté explicitement en tête de fichier (lignes
  9-20) comme *parité `flex_color_picker` DODLP* : le cœur reste neutre
  (AD-1, aucune dép `flex_color_picker` dans `pubspec.yaml` d'aucun package
  zcrud) —

```
grep -rln "flex_color_picker" packages/*/pubspec.yaml
```
→ RC=1 (aucun match) — **confirmé : zéro dépendance `flex_color_picker` dans
le monorepo zcrud**, seulement en commentaire/doc.

### Écart & stratégie

- **Roue HSV exacte + onglets primaires/accents Material** : le picker
  built-in ne reproduit **pas** l'UI à onglets de `flex_color_picker` (roue
  colorimétrique circulaire, palettes Material prédéfinies) — remplacée par
  des sliders HSV linéaires. Perte de fidélité visuelle si comparé pixel à
  pixel, mais **fonctionnellement équivalent** (même espace de couleur
  atteignable via hex/sliders).
- **Stratégie recommandée** : **ne pas** adopter `flex_color_picker` dans
  `zcrud_core` (violerait AD-1, package UI lourd avec licence MIT mais
  large surface). Le **seam `ZcrudScope.colorPicker`** est le point
  d'intégration correct : DODLP (via `zcrud_get`) enregistre un
  adaptateur `flex_color_picker` réel dans son binding pour retrouver la
  roue HSV pixel-exacte + le nom de couleur `ColorTools.nameThatColor` (qui
  est spécifique à `flex_color_picker`, absent du picker built-in — **écart
  mineur** : pas de nom de couleur affiché, seulement le hex). **Aucun
  adaptateur satellite `zcrud_flex_color_picker` n'existe encore** — à créer
  côté `zcrud_get` (ou l'app DODLP elle-même) si la roue HSV exacte est
  jugée bloquante ; sinon le built-in neutre suffit (AC déjà `review`).
- **Risque** : aucun (le natif fonctionne sans dépendance tierce) ; risque
  de fork **nul** puisque `flex_color_picker` resterait côté binding/app,
  jamais forké dans zcrud.

---

## 2. Champ couleur **multiple** (`EditionFieldTypes.color` + `field.multiple == true`)

**`EditionFieldType` zcrud correspondant** : `EditionFieldType.color`
**sans** équivalent de la variante `multiple` — **ABSENT**.

### Package DODLP + usage vivant

- **Package** : `color_picker_field: ^2.1.0` (`pubspec.yaml:77`) — **PAS**
  `flex_color_picker` pour cette variante (vérifié par grep des classes
  source ci-dessous).
- **Fichier** : `edition_screen.dart`, branche `if (field.multiple)` lignes
  **1671-1741**.
- **API réellement utilisée** :
  - `DialogRoute<ColorPickerDialogModel>` poussé via `Navigator.of(context)
    .push(dialog)` — **dialog plein écran** (pas inline), classes
    `ColorPickerDialog`/`ColorPickerDialogModel` du package
    `color_picker_field` :

```
grep -rln "class ColorPickerDialog\b" \
  /home/zakarius/.pub-cache/hosted/pub.dev/color_picker_field-2.1.0/lib \
  /home/zakarius/.pub-cache/hosted/pub.dev/flex_color_picker-3.7.1/lib
```
→ RC=0, seul match : `color_picker_field-2.1.0/lib/src/screens/color_dialog.dart`
(confirme l'attribution — **pas** `flex_color_picker`).

  - `ColorPickerDialog(initialColor: Colors.teal, colorList: _initialValue,
    enableLightness: true, enableSaturation: true, helpText: fieldLabel)` —
    sélection **multi** via une liste de `ColorPickerDialogModel.colorStates`
    (chaque couleur a un flag `selected`), plus une couleur "en cours"
    (`value.color`) ajoutée si absente de la liste.
  - Résultat sérialisé : `colors.map((e) => e.toARGB32()).toList()` — donc
    **`List<int>`** ARGB (contrairement au mono-color qui passe le `Color`
    brut).
- **Affichage hors-dialog** : `Card` + `ListTile` avec `subtitle: Wrap` de
  `CircleAvatar` 18×18 par couleur sélectionnée (ou texte « Select one or
  more » si vide).

### Rendu visuel

Liste de pastilles rondes 18 dp en `Wrap` ; dialog plein écran listant des
couleurs sélectionnables (cases à cocher implicites via `colorStates`),
sliders teinte/saturation.

### Couverture zcrud

**ABSENT** — aucune variante multi-couleurs dans `ZColorFieldWidget` ni
`ZColorConfig` :

```
grep -n "multiple" packages/zcrud_core/lib/src/domain/edition/z_field_config.dart \
  packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart
```
→ RC=1 (aucun match) — **confirmé ABSENT**, le champ couleur zcrud est
strictement mono-valeur (`Object? value` interprété comme `int?` unique,
`ZColorPicker` retourne `Future<int?>` — pas `Future<List<int>>`).

### Écart & stratégie

- **Gap fonctionnel réel** (pas juste visuel) : DODLP a un mode multi-select
  de couleurs (ex. légendes de carte, tags colorés) que zcrud ne peut pas
  représenter aujourd'hui avec `EditionFieldType.color`.
- **Stratégie** : ne **pas** forker `color_picker_field` (package peu
  maintenu — dernière release à vérifier côté pub.dev, surface petite,
  dépendance transitive supplémentaire). Deux options pour combler l'écart,
  toutes deux **hors `zcrud_core`** (AD-1) :
  1. **Composition côté story future** : une variante `ZColorConfig` additive
     (`multiple: bool`, valeur en tranche `List<int>` au lieu de `int`) dans
     `zcrud_core`, réutilisant le picker built-in en boucle (case à cocher
     par couleur choisie) — reste 100 % neutre, pas de nouvelle dépendance.
  2. **Adaptateur satellite** (`zcrud_get` ou binding DODLP) enregistrant un
     `ZFieldWidgetBuilder` dédié via `ZWidgetRegistry.register(kind, …)`
     pour un `kind` custom (ex. `"colorMulti"`), qui elle peut légitimement
     dépendre de `color_picker_field` si la parité pixel-exacte est requise.
  - Recommandation : **option 1** (extension native minimale) est
    préférable à moyen terme — la dépendance `color_picker_field` est un
    package peu significatif à répliquer en Flutter pur (liste de couleurs
    + case à cocher), et évite d'introduire une dépendance tierce
    supplémentaire dans la chaîne de binding. **Non traité par DP-17** —
    à planifier comme story dédiée si DODLP a des données réelles utilisant
    ce mode (à vérifier côté modèles DODLP avant de prioriser).
- **Risque migration de données** : le format stocké diffère déjà entre
  mono (`Color`/format modèle-dépendant) et multi (`List<int>` ARGB
  explicite) côté DODLP lui-même — aucune régression supplémentaire
  introduite par zcrud tant que le futur champ multi zcrud choisit aussi
  `List<int>` ARGB (cohérent avec le choix mono `int` ARGB déjà fait).

---

## 3. Picker fill/stroke du geofence (`geofence_field.dart`)

**Type de champ** : ce n'est **pas** un `EditionFieldTypes.color` du
dispatch générique — c'est un sous-widget de **stylisation de forme
géographique**, dans le champ géo composite. Rattaché ici car il utilise
aussi un color-picker vivant, sur `flex_color_picker` cette fois (contraste
avec §2).

### Package DODLP + usage vivant

- **Package** : `flex_color_picker: ^3.7.1`.
- **Fichier** : `lib/modules/data_crud/presentation/widgets/geofence_field/geofence_field.dart`,
  méthode `_pickColor(bool isFill)` lignes **323-360** (import ligne 12).
- **API utilisée** (lignes 328-352) : `showColorPickerDialog(context,
  currentColor, title: Text('Couleur de remplissage/bordure'), width: 40,
  height: 40, spacing: 0, runSpacing: 0, borderRadius: 0, wheelDiameter:
  165, enableOpacity: true, showColorCode: true, colorCodeHasColor: true,
  pickersEnabled: {wheel: true}, actionButtons: …, constraints: minHeight
  460, minWidth 300, maxWidth 320)` — **un seul onglet** (roue uniquement,
  pas de primaires/accents), appelé pour la couleur de **remplissage** et de
  **bordure** séparément (`_currentShapeStyle.copyWith(fillColor:…)` /
  `strokeColor:…`), déclenché en sortie de `_toggleStylingMode()`.
- **Rendu visuel** : bouton dans la barre d'outils du geofence qui ouvre le
  dialog roue-seule, applique la couleur choisie au style de la forme en
  cours d'édition sur la carte (remplissage translucide + contour opaque).

### Couverture zcrud

- **Modèle de données neutre** : `ZGeoShapeStyle`
  (`packages/zcrud_geo/lib/src/domain/z_geo_shape_style.dart:24`) porte déjà
  `fillColorArgb`/`strokeColorArgb` en `int?` ARGB, défensif
  (`fromMapSafe`), consommé par les adaptateurs carte
  (`z_osm_map_adapter.dart`, `z_google_map_adapter.dart`) — **couverture
  modèle : OK**.
- **Widget UI de sélection (toolbar « styliser cette forme »)** — **ABSENT** :

```
grep -rln "showColorPickerDialog\|_pickColor\|GeofenceField" \
  packages/zcrud_geo/lib/
```
→ RC=1 (aucun match) — **confirmé ABSENT** : aucun widget d'édition de
style de forme (fill/stroke color picker) n'est encore porté dans
`zcrud_geo`, seulement le modèle de données et le rendu carte.

```
find packages/zcrud_geo/lib -iname "*geofence*"
```
→ aucun résultat (pas de fichier).

### Écart & stratégie

- Le **modèle** est prêt (`ZGeoShapeStyle`) ; c'est l'**UI d'édition de
  style** (toolbar avec 2 boutons color-picker fill/stroke) qui manque
  entièrement côté `zcrud_geo`. Ce n'est pas un écart de la famille couleur
  au sens strict mais une **dépendance directe** : quand `zcrud_geo`
  implémentera l'éditeur de geofence interactif, il devra réutiliser le
  **même seam `ZColorPicker`/`ZColorPickerDialog`** que `zcrud_core` (ou
  son propre appel à `ZcrudScope.colorPicker`) pour éviter de dupliquer un
  second picker couleur avec une UX différente.
- **Stratégie** : réutiliser `ZColorFieldWidget`/`ZColorPickerDialog`
  exposés `@visibleForTesting`/publics depuis `zcrud_core` (déjà public
  dans le barrel `zcrud_core.dart`) plutôt que réinventer un picker
  dans `zcrud_geo` — cohérence UX, zéro dépendance nouvelle. Si la roue
  HSV mono-onglet de `flex_color_picker` est jugée indispensable pour cet
  usage carte, le **même** adaptateur de binding (§1) suffit — pas besoin
  d'un second seam.
- **Risque** : faible — reporté à la story d'implémentation de l'éditeur
  geofence interactif (hors périmètre DP-17, hors périmètre de cette
  étude couleur).

---

## Tableau de synthèse

| # | Champ / usage | Package DODLP | `file:line` | Couverture zcrud | Verdict |
|---|---|---|---|---|---|
| 1 | Couleur simple (`EditionFieldTypes.color`) | `flex_color_picker ^3.7.1` (`showColorPickerDialog`, roue+primaires+accents+hex, opacité, récents) | `edition_screen.dart:1669-1850` | **Natif** — `ZColorFieldWidget`/`ZColorPickerDialog`/`ZColorConfig` (DP-17, statut `review`) + seam `ZcrudScope.colorPicker` | **Natif OK** (fonctionnellement) ; roue HSV pixel-exacte disponible via adaptateur binding optionnel (non encore écrit) |
| 2 | Couleur multiple (`field.multiple`) | `color_picker_field ^2.1.0` (`ColorPickerDialog`/`ColorPickerDialogModel`, sélection multi, `List<int>` ARGB) | `edition_screen.dart:1671-1741` | **ABSENT** (aucune trace `multiple` dans `z_field_config.dart`/`z_color_field_widget.dart`) | **Gap** — étendre `ZColorConfig`/`ZColorFieldWidget` en natif (recommandé) ou adopter via registry satellite si urgent |
| 3 | Style geofence fill/stroke | `flex_color_picker ^3.7.1` (`showColorPickerDialog`, roue seule) | `geofence_field.dart:323-360` | **Modèle natif OK** (`ZGeoShapeStyle`) ; **UI picker ABSENTE** dans `zcrud_geo` | **Gap UI** (hors scope story couleur — dépendance de l'éditeur geofence à venir) ; réutiliser le seam §1, pas de second picker |

## Risques fork/licence signalés

- `flex_color_picker` : MIT, activement maintenu (versions 3.7.1 **et**
  3.8.0 présentes en cache local — confirme maintenance active). Aucun
  risque si cantonné au binding via le seam `ZcrudScope.colorPicker` — **ne
  jamais** l'ajouter en dépendance directe de `zcrud_core`/`zcrud_geo`
  (violerait AD-1).
- `color_picker_field` : package plus confidentiel/peu maintenu (à
  re-vérifier sur pub.dev avant toute décision d'adoption) — recommandation
  de porter la logique multi-sélection en Flutter pur plutôt que d'y
  introduire une dépendance supplémentaire dans un satellite.
