# Étude 13 — Famille SIGNATURE / RATING / SLIDER / DIVERS (DODLP → zcrud)

Date : 2026-07-17. Périmètre : champs `signature`, `rating`, `slider` de
`EditionFieldTypes` (DODLP `lib/modules/data_crud/`) + tout usage voisin
(`percent_indicator`, `syncfusion_flutter_signaturepad`, `package:signature`)
détecté par grep exhaustif, confronté à `zcrud_core` (familles natives
`z_signature_field_widget.dart`, `z_rating_field_widget.dart`,
`z_slider_field_widget.dart`).

**Repo DODLP** : `/home/zakarius/DEV/dodlp-otr` (lecture seule, aucune écriture).
**Repo zcrud** : `/home/zakarius/DEV/zcrud`.

---

## 1. Champ `signature` (`EditionFieldTypes.signature`)

### 1.1 Package DODLP réellement utilisé — ⚠️ PAS syncfusion

Le champ dynamique du formulaire CRUD (`edition_screen.dart`) utilise le
package **`package:signature: ^6.3.0`** (pubspec.yaml:214), **PAS**
`syncfusion_flutter_signaturepad` (celui-ci existe dans le pubspec — ligne 129
— mais sert à un usage **différent et sans rapport** : capture de la
signature d'accusé-réception PDF dans `dodlp_pdf_export_mixin.dart` et deux
écrans SSE d'export T1/BEP, hors du moteur `data_crud` générique).

Preuve — usages VIVANTS de `SfSignaturePad` (syncfusion) :
```
lib/src/presentation/widgets/dodlp_pdf_export_mixin.dart:7,133   (mixin export PDF, hors data_crud)
lib/modules/sse/presentation/views/screens/export_t1_emis_screen.dart:11,936
lib/modules/sse/presentation/views/screens/export_bep_non_appure_screen.dart:11,358
```
→ RC=0, mais **zéro occurrence** dans `lib/modules/data_crud/**`.

Preuve — usage VIVANT de `package:signature` dans le moteur CRUD :
```
lib/modules/data_crud/presentation/views/edition_screen.dart:61   import 'package:signature/signature.dart';
lib/modules/data_crud/presentation/views/edition_screen.dart:2189 case EditionFieldTypes.signature:
lib/modules/data_crud/presentation/views/edition_screen.dart:2247 final SignatureController _signatureController = SignatureController(...)
lib/modules/data_crud/presentation/views/edition_screen.dart:2264 child: Signature(controller: _signatureController, backgroundColor: Colors.white)
```
(`package:signature` réapparaît aussi dans 4 écrans BMD hors data_crud —
`round_execution_screen.dart:729`, `differential_statement_wizard_screen.dart:600`,
`patrol_execution_screen.dart:818`, `operation_supervision_screen.dart:570` —
même famille de package, contexte métier différent, hors périmètre CRUD
générique.)

### 1.2 API/comportement réellement exercé (`edition_screen.dart:2189-2312`)

- **Lecture seule** (`widget.readOnly`) : rend un `Card` avec soit
  `Image.memory(signatureData, fit: BoxFit.contain)` (la valeur stockée est un
  **PNG en `Uint8List`** — `fieldValue as Uint8List?`), soit un texte "Non
  signé" si vide.
- **Édition** : `SignatureController(penStrokeWidth: 3, penColor: Colors.black,
  exportBackgroundColor: Colors.transparent)` **recréé à chaque `build`**
  (`final ... _signatureController = SignatureController(...)` dans le corps du
  `switch`, pas dans un `State` stable — bug potentiel de perte de tracé au
  rebuild, mais c'est le comportement RÉEL à égaler visuellement, pas à
  reproduire fonctionnellement).
- `Signature(controller: _signatureController, backgroundColor: Colors.white)`
  dans un `Container` bordé (`height: 200, Border.all(color: Colors.grey)`).
- Deux boutons texte **Effacer** / **Valider** : Valider appelle
  `_signatureController.toPngBytes()` (encodage PNG asynchrone du package
  `signature`) et stocke les bytes bruts comme valeur du champ (`item =
  invokeItemSetter(..., value: data)`), + toast de confirmation.
- Pas de undo, pas de redimensionnement responsive du canevas (hauteur fixe
  200), pas de Semantics explicite (à l'inverse de zcrud — cf. 1.4).

### 1.3 Rendu visuel à égaler pour la parité

- Canevas **blanc** (`backgroundColor: Colors.white`) bordé gris uni, hauteur
  fixe 200 px, largeur pleine.
- Aperçu lecture-seule = **image PNG rendue**, pas un re-tracé vectoriel.
- Bouton **Effacer** + bouton **Valider** explicite (pas de commit implicite
  au `panEnd` — DODLP exige une action "Valider" pour committer la tranche).
- Valeur persistée = **bitmap PNG**, pas des points/strokes vectoriels.

### 1.4 Couverture zcrud

**Natif** — `packages/zcrud_core/lib/src/presentation/edition/families/z_signature_field_widget.dart`
(163 l. + `_SignaturePainter`).

Preuve d'isolation (AUCUN package tiers, Flutter pur) :
```bash
grep -n "^import" packages/zcrud_core/lib/src/presentation/edition/families/z_signature_field_widget.dart
# → 'package:flutter/material.dart' + imports zcrud_core internes uniquement. RC=0.
grep -rn "package:signature\|syncfusion_flutter_signaturepad" packages/zcrud_core/pubspec.yaml
# → aucune correspondance, RC=1 (grep -c donne 0)
```
Design **délibérément différent** de DODLP, documenté dans le header du
fichier (l.1-27) :
- `GestureDetector` + `CustomPaint` **Flutter natif**, zéro dépendance lourde
  (`CORE OUT=0` préservé, AD-1/AD-15) — contre `package:signature` externe.
- Valeur encodée = **strokes vectoriels normalisés `[0,1]`** en `Map`
  versionnée (`ZSignatureCodec`, AD-3/AD-10 défensif), **pas un PNG bitmap**.
- Commit **implicite** à la fin de chaque trait (`_panEnd → _emit()`) — pas de
  bouton "Valider" séparé ; boutons `undo`/`clear` seulement (`IconButton`
  ≥48dp, tooltip l10n).
- `Semantics(container, label, value: signé/vide)` — absent côté DODLP.

### 1.5 Écart & stratégie de package

| Axe | DODLP | zcrud natif | Écart |
|---|---|---|---|
| Format de valeur | PNG `Uint8List` | strokes vectoriels normalisés `Map` | **RUPTURE de modèle de données** — migration nécessaire si les données existantes DODLP (bytes PNG stockés en base) doivent être relues par zcrud |
| Commit | bouton "Valider" explicite | auto-commit par trait | Comportement UX différent (pas bloquant visuellement) |
| Rendu lecture-seule | `Image.memory` (bitmap figé) | re-tracé vectoriel via `CustomPaint` | Résultat visuel **quasi identique** à l'écran (les strokes sont dessinés avec la même géométrie) mais **pas pixel-identique** si le trait DODLP a des artefacts propres au moteur `signature` (anti-aliasing, épaisseur variable liée à la vélocité) |
| Dépendance | `package:signature` (tiers, maintenu, licence MIT) | 0 dépendance | zcrud **gagne** en isolation (AD-1) |

**Verdict : le natif zcrud SUFFIT pour la parité visuelle du champ lui-même**
(zone de capture, effacer/annuler, aperçu) — inutile d'adopter
`package:signature` dans un satellite. Le seul vrai risque n'est **pas** la
UI mais la **donnée** : si des enregistrements DODLP existants stockent des
signatures en **PNG brut**, un adaptateur de migration (hors zcrud, côté
app DODLP/ETL) devra convertir bitmap → soit un stockage `bytes` legacy
préservé en featureflag, soit accepter la perte de rétro-édition (le PNG
importé peut être **affiché** en lecture seule via un widget de compat mais
ne peut pas être **redécodé en strokes éditables** — l'information vectorielle
n'existe pas dans un PNG). **Recommandation** : traiter ceci comme un item de
migration de données documenté dans le plan DODLP→zcrud, pas comme un gap de
package.

---

## 2. Champ `rating` (`EditionFieldTypes.rating`)

### 2.1 Package DODLP

**Aucun package tiers** — implémentation ad-hoc avec `Icons.star` /
`Icons.star_border` Material natifs. Aucune dépendance `flutter_rating_bar`,
`flutter_rating_stars` ou équivalent dans `pubspec.yaml` :
```bash
grep -in "rating" pubspec.yaml
# → 0 occurrence (RC=1)
```

### 2.2 Usage vivant — `edition_screen.dart:1918-1965`

- `Card` bordé (`elevation:0, RoundedRectangleBorder(radius:12, side: grey.shade300)`)
  contenant un `Row` avec le label à gauche (`_buildLabelWidget()`) et
  `Row(children: List.generate(5, ...))` à droite — **5 étoiles fixes en dur**
  (pas de `field.max`/config configurable côté DODLP, contrairement à zcrud).
- Chaque étoile = `IconButton(icon: Icon(index < rating ? Icons.star :
  Icons.star_border, color: kGoldColor))` — couleur **codée en dur**
  (`kGoldColor`, constante app, pas un token de thème `ThemeExtension`).
- `onPressed` fixe la note à `index + 1.0` (pas de toggle "re-cliquer pour
  effacer" — contrairement à zcrud qui remet à 0 si on retouche l'étoile
  active, `z_rating_field_widget.dart:86`).
- Pas de `Semantics` explicite, pas de tooltip par étoile.

### 2.3 Rendu visuel à égaler

- `Card` + bordure grise arrondie (12px) avec le label en `spaceBetween` avec
  les étoiles (label à gauche, étoiles à droite) — zcrud rend le label
  **au-dessus** des étoiles (`Column`), pas côte-à-côte : **écart de layout**.
  Trivial à ajuster si la parité pixel est requise (ce n'est pas un écart de
  couverture fonctionnelle, juste un agencement).
- Couleur dorée fixe (`kGoldColor`) vs icône teintée par le thème côté zcrud
  (`Theme.of(context)` — pas de couleur en dur, conforme FR-26 mais visuellement
  différent d'un DODLP qui a une étoile toujours dorée quel que soit le thème
  clair/sombre).
- Max fixe à **5** côté DODLP (jamais paramétré ailleurs — grep négatif
  ci-dessous), vs `ZRatingConfig.max` configurable côté zcrud (défaut 5).

```bash
grep -n "List.generate(" -A1 lib/modules/data_crud/presentation/views/edition_screen.dart | grep -c "List.generate(5"
# → 1 (le seul site rating) ; aucun autre nombre d'étoiles ailleurs dans le fichier
grep -c "field.ratingMax\|maxRating\|starCount" lib/modules/data_crud/presentation/views/edition_screen.dart lib/modules/data_crud/models.dart
# → 0 (RC=1) : pas de config de borne côté DODLP
```

### 2.4 Couverture zcrud

**Natif** — `z_rating_field_widget.dart` (95 l.), 0 dépendance tierce (import
uniquement `flutter/material.dart` + domaine interne). Design supérieur
fonctionnellement (borne configurable `ZRatingConfig`, toggle-to-clear,
`Semantics(value: "$current / $max")`, tooltip l10n par étoile, cible ≥48dp
garantie par `IconButton`).

### 2.5 Écart & stratégie

**Verdict : natif zcrud OK, aucun package à adopter.** Le natif est
fonctionnellement **strictement supérieur** (config du max, a11y, toggle).
Seuls des écarts de **détail visuel** (agencement label/étoiles en `Row` vs
`Column`, couleur dorée fixe vs teinte thème) casseraient une parité
**pixel-perfect** — à trancher en design review, pas un problème de package.
Aucun risque de fork/licence (zéro dépendance des deux côtés en pratique,
DODLP n'a même pas de package ici).

---

## 3. Champ `slider` (`EditionFieldTypes.slider`)

### 3.1 Package DODLP

**`Slider` Material natif Flutter** — aucun package tiers (pas de
`flutter_xlider`, `syncfusion_flutter_sliders`, etc.) :
```bash
grep -in "xlider\|syncfusion_flutter_sliders\|flutter_slider" pubspec.yaml
# → 0 occurrence (RC=1)
```

### 3.2 Usage vivant — `edition_screen.dart:1967-2016`

- `min`/`max`/`divisions` lus depuis `field.min`/`field.max`/`field.divisions`
  (défauts `0.0`/`100.0`/`null`) — **modèle identique** au `ZSliderConfig`
  zcrud (`min`/`max`/`divisions`).
- Label composite au-dessus : `"$fieldLabel (${currentSliderValue.toStringAsFixed(1)})"`
  — la valeur courante est **affichée dans le libellé** avec 1 décimale,
  contrairement à zcrud qui affiche le libellé seul au-dessus et laisse le
  `Slider.label` natif (bulle au drag) porter la valeur.
- `Slider(activeColor: kNavyColor, inactiveColor: Colors.grey.shade300,
  label: currentSliderValue.round().toString(), ...)` — couleurs **codées en
  dur** (`kNavyColor`), pas de thème injecté.
- Emballé dans un `Card` bordé (même style que `rating`) — zcrud rend le
  `Slider` nu dans une `Column` sans `Card`.

### 3.3 Couverture zcrud

**Natif** — `z_slider_field_widget.dart` (73 l.), `Slider` Material pur,
bornes sûres (`max > min` garanti pour éviter l'assertion Flutter), aucune
dépendance tierce. `Semantics` nativement portée par `Slider` (pas de wrapper
`Semantics` explicite additionnel côté zcrud, contrairement à `rating`/
`signature` — cohérent car le widget `Slider` Flutter expose déjà une
sémantique curseur).

```bash
grep -n "^import" packages/zcrud_core/lib/src/presentation/edition/families/z_slider_field_widget.dart
# → flutter/material.dart + domaine interne uniquement, RC=0 dépendance tierce
```

### 3.4 Écart & stratégie

**Verdict : natif zcrud OK, aucun package à adopter.** Écarts purement
cosmétiques : (a) absence de `Card` wrapper, (b) valeur affichée dans le
libellé composite (DODLP) vs bulle native au drag seule (zcrud), (c) couleurs
en dur DODLP vs thème zcrud. Aucun de ces écarts ne nécessite un package tiers
— ce sont des ajustements de layout/thème locaux si la parité pixel est
exigée. Aucun risque fork/licence (Slider natif des deux côtés).

---

## 4. Champs voisins hors périmètre strict — DIVERS attribués/orphelins

### 4.1 `percent_indicator` (`^4.2.3`) — pas un type de champ `data_crud`

Preuve d'absence dans le moteur CRUD :
```bash
grep -c "percentIndicator\|PercentIndicator\|percent" lib/modules/data_crud/models.dart lib/modules/data_crud/enumerations.dart lib/modules/data_crud/presentation/views/edition_screen.dart
# → 0 sur les 3 fichiers (RC=1 chacun) : aucun type EditionFieldTypes n'utilise percent_indicator
```
Usage réel confiné au module **`file_manager`** (jauges de progression
upload/download, hors moteur de formulaire dynamique) :
```
lib/modules/file_manager/file_manager.dart:34             import 'package:percent_indicator/percent_indicator.dart';
lib/modules/file_manager/presentation/views/file_manager_dashboard.dart:96  CircularPercentIndicator(...)
lib/modules/file_manager/utils/functions/helpers.dart:830  CircularPercentIndicator(...)
```
**Champ orphelin pour cette étude** : ce n'est pas un `EditionFieldTypes` du
moteur CRUD, donc **hors scope de parité de champ**. Le champ `number` zcrud
porte déjà un mode `isPercentage` (suffixe `%`, validateur `percentage`) mais
c'est un **champ texte numérique**, pas une jauge circulaire/linéaire — si
DODLP migre un jour une jauge de progression de fichier vers zcrud, ce serait
un widget d'infrastructure `zcrud_core`/app (barre de progression d'upload),
**pas** un `EditionFieldType` du schéma. Aucune action requise côté
`z_signature`/`z_rating`/`z_slider`.

### 4.2 `syncfusion_flutter_signaturepad` — orphelin CONFIRMÉ hors data_crud

Cf. §1.1 : présent dans 3 fichiers, **aucun dans `lib/modules/data_crud/`**.
C'est un doublon fonctionnel du champ `signature` mais utilisé dans un
contexte métier différent (accusé PDF BMD/SSE) qui **ne passe pas** par le
moteur de formulaire dynamique `data_crud`. Pas de recommandation
d'adoption : le natif zcrud couvre déjà le besoin de champ `signature`
générique (§1.5).

### 4.3 `expandable` (`ExpandablePanel`/`ExpandableController`) — non orphelin, déjà attribué

Trouvé dans `lib/modules/data_crud/forms_utils.dart:11,38,94-99`
(`MyStickyHeader`/`MySctickyHeaderState`) : widget de **section repliable**
(groupement/aération de champs), pas un type de champ individuel. Déjà dans
le périmètre de l'étude STUDY.md initiale ("aération") — confirmé non lié à
signature/rating/slider par grep négatif :
```bash
grep -n "star\|Star\|Slider\|percent\|Percent\|gauge\|Gauge" lib/modules/data_crud/forms_utils.dart
# → seule ligne 788 "crossAxisAlignment: CrossAxisAlignment.start" (faux positif "Star" dans "start"), RC=0 match réel
```

### 4.4 `table_calendar`, `drag_and_drop_lists`, `flutter_slidable` — orphelins HORS `data_crud`

```bash
grep -rln "table_calendar\|drag_and_drop_lists\|flutter_slidable" lib/modules/data_crud --include="*.dart"
# → aucun résultat (RC=1)
```
Usages réels : `table_calendar` → `lib/modules/workflow/presentation/views/screens/agenda_screen.dart`
(agenda métier, hors CRUD) ; `drag_and_drop_lists`/`flutter_slidable` →
non trouvés dans `lib/modules/data_crud` (recherche globale montre
`side_menu.dart`, `mindmap_edition_screen.dart`, `module_menu.dart`,
`workspace.dart` — navigation/mindmap, hors périmètre champ de formulaire).
**Non pertinents pour cette étude de parité de champ** — à signaler pour
mémoire si une autre lentille (navigation/mindmap) ne les a pas déjà couverts.

---

## 5. Synthèse

| Champ DODLP | `EditionFieldType` zcrud | Package DODLP | `file:line` | Couverture zcrud | Verdict |
|---|---|---|---|---|---|
| `signature` | `signature` | `package:signature ^6.3.0` (PAS syncfusion) | `edition_screen.dart:2189-2312` | **Natif** `z_signature_field_widget.dart` (0 dép, strokes vectoriels) | Natif OK visuellement ; **migration de données** requise (PNG bitmap DODLP → strokes vectoriels zcrud, non réversible) |
| `rating` | `rating` | Aucun (Material `Icons.star` ad-hoc) | `edition_screen.dart:1918-1965` | **Natif** `z_rating_field_widget.dart` | Natif OK, fonctionnellement supérieur ; écarts cosmétiques mineurs (layout, couleur) |
| `slider` | `slider` | Aucun (`Slider` Material natif) | `edition_screen.dart:1967-2016` | **Natif** `z_slider_field_widget.dart` | Natif OK ; écarts cosmétiques mineurs (Card wrapper, couleurs) |
| jauge upload (`percent_indicator`) | — (pas un `EditionFieldType`) | `percent_indicator ^4.2.3` | `file_manager_dashboard.dart:96` | **ABSENT** (hors scope champ CRUD) | Hors périmètre — pas un champ de formulaire |
| signature PDF export (`syncfusion_flutter_signaturepad`) | — (hors data_crud) | `syncfusion_flutter_signaturepad ^32.1.19` | `dodlp_pdf_export_mixin.dart:133`, `export_t1_emis_screen.dart:936`, `export_bep_non_appure_screen.dart:358` | Orphelin confirmé, non lié au champ `signature` du CRUD | Pas d'action zcrud |

**Aucune adoption de package tiers requise pour cette famille.** Les trois
familles natives zcrud (`z_signature`, `z_rating`, `z_slider`) couvrent la
parité fonctionnelle et visuelle à des écarts cosmétiques près (layout,
couleurs en dur DODLP vs thème zcrud). Le seul risque structurant est la
**migration de données du champ `signature`** (bitmap PNG DODLP → format
vectoriel strokes zcrud), qui est un sujet de migration applicative, pas un
gap de package.
