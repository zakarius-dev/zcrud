# zcrud_media

Satellite **média** de zcrud (AD-51) — câble le contrat cœur existant
`ZFilePicker`/`ZFileSource` derrière une API **neutre** (`AppFile`/chemins/
`Uint8List` — aucun type plateforme en signature publique, AD-40) et fournit des
**affordances riches** (drop-zone / ouverture au tap / vignette vidéo) servies
via `ZWidgetRegistry`.

> **État : LIVRÉ (fp-4-2).** Le picker média concret et les widgets riches sont
> écrits ; les dépendances tierces sont confinées à `lib/src/` (gardées par
> `test/z_media_confinement_test.dart`).

## Ce que fournit le package

- **`ZMediaFilePicker`** — implémentation neutre de `ZFilePicker` (contrat cœur)
  à injecter dans `ZcrudScope.filePicker`. Sert l'acquisition des types
  **natifs** `image`/`file`/`document` que le cœur route vers `ZAppFileField`.
  L'acquisition (galerie / caméra / sélecteur de documents / recadrage) est
  déléguée à des **seams** injectables (`ZImagePickSeam`, `ZFilePickSeam`,
  `ZImageCropSeam`, `ZDocumentScanSeam`) — défaut = plugins réels, fakes en test.
- **Widgets média riches** (`registerZMediaFieldWidgets`) — enregistre trois
  builders dans un `ZWidgetRegistry`, sous les `kind`
  `mediaImageFieldKind`/`mediaFileFieldKind`/`mediaVideoFieldKind`, **alignés sur
  `EditionFieldType.mediaImage/mediaFile/mediaVideo.name`**. Le dispatcher cœur
  (`ZFieldWidget`, famille `registryOrFallback`) résout ces types par
  `field.type.name` ⇒ un `ZFieldSpec(type: EditionFieldType.mediaImage)` rend le
  widget riche (drop-zone + ouverture + aperçu) dès que le registre est peuplé ;
  sinon repli propre `ZUnsupportedFieldWidget` (AD-10). Ces types sont un chemin
  **distinct** des types natifs `image`/`file`/`document` (jamais un override).

## Câblage (côté binding/app — enrôlement EXPLICITE au bootstrap)

```dart
final picker = ZMediaFilePicker();          // seams/crop optionnellement injectés
final registry = ZWidgetRegistry();
registerZMediaFieldWidgets(registry, picker: picker);
// puis, dans l'arbre :
ZcrudScope(filePicker: picker, widgetRegistry: registry, child: ...)
```

## Dépendances

- **`zcrud_core`** — unique arête `zcrud_*` sortante (AD-1, CORE OUT=0).
- Deps média tierces **confinées à `lib/src/`** (invisibles au barrel neutre) :
  `image_picker`, `file_picker`, `image_cropper`, `video_thumbnail`, `open_file`,
  `dotted_border`. La caméra passe par `image_picker`/`ImageSource.camera` (ET-5)
  — le plugin `camera` n'est **pas** requis (retiré en MED-3).

L'allowlist (dépendances + imports) est gardée par
`test/z_media_confinement_test.dart` (`graph_proof` ne voit que les arêtes
`zcrud_*`). Publié sous licence MIT.

## Limite connue

- **Acquisition vidéo directe** : la drop-zone du mode vidéo acquiert via la
  galerie d'images (pas de chemin `pickVideo` dans `ZFileSource` côté cœur). Le
  champ vidéo gère la **vignette** d'un `AppFile` vidéo préexistant ;
  l'acquisition vidéo directe est un suivi (cf. `code-review-fp-4-2.md`, LOW).
