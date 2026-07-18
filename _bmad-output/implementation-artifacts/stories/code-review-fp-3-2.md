# Code-review fp-3-2 — findings & statut de correction

Périmètre corrigé : **`example/` UNIQUEMENT**. `packages/*` INTOUCHÉ
(`git status --porcelain packages/` VIDE).

## Tableau finding × statut × preuve

| Finding | Sévérité | Statut | Correctif | Preuve |
|---|---|---|---|---|
| **MED-1** — statut `liveNative` découplé du rendu : `file`/`image`/`document` étiquetés « Livré natif » dans `ShowcaseCoverage.byType` mais ABSENTS de `socleFields` ⇒ comptés sans jamais être montés | MEDIUM | **CORRIGÉ** | (1) Groupe `_nativeFiles` (3 champs file/image/document) ajouté à `socleFields` + section « Fichiers natifs (ZAppFileField) » — rendus par leur VRAI adaptateur natif `ZAppFileField` via le dispatcher (`z_field_widget.dart:615`), seams picker/storage `ZcrudScope`, données fictives. (2) Test DÉRIVÉ de la matrice `MED-1` dans `showcase_exhaustive_test.dart` : pour CHAQUE type `liveNative`/`liveSatellite` de `ShowcaseCoverage.byType`, exige ≥1 champ EFFECTIVEMENT monté (clé présente) ET rendu sans `ZUnsupportedFieldWidget`. Liste des types dérivée de l'enum/matrice, jamais figée. | **Falsifiabilité prouvée** : `_nativeFiles` retiré du socle ⇒ test ROUGE `RC=1` nommant `type LIVE EditionFieldType.file absent du socle showcase (compté « Livré » sans être monté — MED-1)` ; restauré ⇒ VERT `RC=0`. Suite exhaustive isolée : `+5 All tests passed`. |
| **LOW-2** — prose « WYSIWYG exercée au RUNTIME » fausse : `ZHtmlEditorField` jamais instancié (grep 0 call-site) ; tous les champs html/inlineHtml sont `readOnly:true` | LOW | **CORRIGÉ (prose)** | Prose bornée honnêtement dans `showcase_data.dart` (doc `_richNew` + commentaire inline) et notes de `showcase_coverage.dart` (html/inlineHtml) : « registrar `registerZHtmlFields` câblé + rendu LECTURE (`ZHtmlView`) démontré ; aucun champ html ÉDITABLE monté (tous `readOnly`) ; éditeur WYSIWYG WebView (`ZHtmlEditorField`) non montable en `flutter test` (ET-5), édition au runtime hors démo test ». Comportement INCHANGÉ. Option « champ html éditable » NON retenue (WebView `ZHtmlEditorField` non montable headless — ET-5 documenté). | `grep -rn "ZHtmlEditorField(" example/` = 0 call-site (confirmé). Prose ne prétend plus aucune édition runtime exercée par les tests. |

## Vérif verte rejouée (RC réels sur disque)

- `dart analyze example` → **RC=0** (seule subsiste l'`info` deprecation
  PRÉ-EXISTANTE `softDeleteSelected` de `list_demo_screen.dart`, fichier non touché).
- `flutter test example` (suite ENTIÈRE) → **RC=0, 97 passed** (« All tests passed! »,
  > 96).
- `flutter test example/test/boundary_deps_test.dart` (garde de frontière) → **RC=0, VERTE**.
- `flutter test example/test/showcase_exhaustive_test.dart` (isolé) → **RC=0**, dont le
  nouveau test `MED-1`.

## Frontière packages/*

`git status --porcelain packages/` = **VIDE** — aucun `packages/*` modifié. Correctifs
confinés à `example/lib/demos/showcase/` et `example/test/`.
