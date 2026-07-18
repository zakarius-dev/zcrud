# Étude de parité — famille IMAGE/MÉDIA (DODLP → zcrud)

Extension de `STUDY.md` — champ par champ, package de rendu DODLP confronté à la
couverture `zcrud`. Repo DODLP (**lecture seule**) : `/home/zakarius/DEV/dodlp-otr`.
Repo zcrud (analyse) : `/home/zakarius/DEV/zcrud`.

> ⚠️ **Constat central** : DODLP expose **un seul type de champ dynamique**
> (`EditionFieldTypes.file` / `.image` / `.document`) rendu par **un seul widget**
> (`AppFileEditionField`), qui ne fait **ni recadrage, ni caméra en direct, ni
> vignette vidéo**. Le recadrage (`image_cropper`) et la capture caméra explicite
> (`ImageSource.camera` d'`image_picker`) n'existent QUE dans le flux **photo de
> profil utilisateur** (`auth.dart`), hors du moteur CRUD déclaratif. Le paquet
> `camera` (^0.11.2, live-preview) est **mort** dans l'app : importé/initialisé
> dans `main.dart` mais sa variable globale `platformCameras` n'est référencée
> nulle part ailleurs. `video_thumbnail` sert le **file manager**, pas le champ
> d'édition dynamique. Ceci change fortement le périmètre de parité réel.

---

## 1. Champ `image` / `file` / `document` (widget générique DODLP)

**`EditionFieldType` zcrud correspondant** : `file` / `image` / `document` (natifs,
`packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart:91,94,97`).

### 1.1 Dispatch DODLP

Les **trois** types `EditionFieldTypes.file`/`.image`/`.document` retombent sur le
**même** widget, sans distinction de comportement (seule la config d'extensions
diffère pour `image`) :
`lib/modules/data_crud/presentation/views/edition_screen.dart:2018-2098`
```dart
case EditionFieldTypes.file:
case EditionFieldTypes.image:
case EditionFieldTypes.document:
  ...
  final effectiveConfig = field.fileConfig ??
      (field.type == EditionFieldTypes.image
          ? FileFieldConfig(multiple: field.multiple, maxFiles: ..., allowedExtensions: ['jpg','jpeg','png','webp'])
          : null);
  ...
  return AppFileEditionField(label: ..., initialValue: initialValue, deletedFiles: ..., config: effectiveConfig, onChanged: ...);
```
Le flux passe par un `StreamBuilder<List<AppFile>>` (`dodlp.appFileRepository.streamFromIdsOrPaths`)
pour hydrater les fichiers distants depuis des ids/urls stockés dans l'entité (edition_screen.dart:2051-2057).

### 1.2 Package DODLP + API réellement utilisée

Widget : `lib/modules/data_crud/presentation/widgets/app_file_edition_field.dart` (738 l., VIVANT).

| Action | Package | API exacte | file:line |
|---|---|---|---|
| Scanner un document (PDF only, `!kIsWeb`) | `cunning_document_scanner ^1.4.0` | `CunningDocumentScanner.getPictures(isGalleryImportAllowed: true, iosScannerOptions: IosScannerOptions(imageFormat: IosImageFormat.png))` puis assemblage PDF via `PdfCreationService.createPdfFromImagePaths` | app_file_edition_field.dart:119-154 |
| Prendre des photos (caméra) | `image_picker ^1.2.0` | `ImagePicker().pickImage(source: ImageSource.camera, preferredCameraDevice: kIsWeb?front:rear)` (mono) ou `pickMultiImage(limit:)` si `limit>1` — **AUCUN appel `ImageSource.camera` en mode multiple** (le SDK ne le permet pas ; multi-shot camera = boucle absente, DODLP ne boucle pas non plus) | app_file_edition_field.dart:156-191 |
| Charger des photos (galerie) | `image_picker ^1.2.0` | `pickImage(source: ImageSource.gallery)` (mono) / `pickMultiImage(limit:)` (multi) | app_file_edition_field.dart:193-223 |
| Sélectionner un document générique | `file_picker ^10.3.3` | `FilePicker.platform.pickFiles(dialogTitle:, allowMultiple:, type: allowedExtensions!=null?custom:any, allowedExtensions:, withData: kIsWeb)` | app_file_edition_field.dart:225-259 |
| Prévisualisation image (post-pick) | Flutter natif (**pas** de package tiers) | `MemoryImage`/`FileImage`/`base64Decode→MemoryImage`/`NetworkImage` selon la provenance (`bytes`/`localPath`/`content`/`cloudUrl`) → `DecorationImage` sur un carré 40×40 en `leading` de `ListTile` | app_file_edition_field.dart:579-611 |
| **Recadrage** | **ABSENT du champ générique** — voir §2 | — | — |
| **Caméra live-preview** | **ABSENT** — `image_picker` délègue à l'app caméra OS, jamais le paquet `camera` | — | — |
| **Vignette vidéo** | **ABSENT** — `AppDocumentType` n'a même pas de variante `video` (enum: `pdf,word,excel,powerpoint,image,text`) | app.py `models/app_file.dart:10-16` | — |

### 1.3 Rendu visuel (ce qui casserait la parité)

- Bottom-sheet modal (`showModalBottomSheet`, coins arrondis 20) avec jusqu'à 4
  boutons ronds icône+libellé (scan / photo / galerie / document) filtrés par
  `_canPickImage`/`_canPickPdf`/`_canPickDocument` dérivés de
  `config.allowedDocumentTypes` (app_file_edition_field.dart:313-387).
- Carte conteneur avec header dégradé (`widget.gradient`, 2 couleurs), icône du
  type de fichier dominant, titre, bouton **Enregistrer** (`_hasChanges` seulement)
  et bouton **+** (app_file_edition_field.dart:409-528).
- Grille adaptative (`GridView.builder`, `crossAxisCount = (largeur/350).floor().clamp(1,4)`)
  de `ListTile` 40×40 avec miniature carrée (`DecorationImage`/`BoxFit.cover`),
  badge « Brouillon » (`AppDocumentStatus.draft`) ou « En attente d'envoi »
  (`.uploading`), bouton supprimer/restaurer (icône `delete_outline`/`restart_alt`,
  opacité 0.5 sur les éléments marqués supprimés) — app_file_edition_field.dart:575-672.
- `_isBusy` : overlay `CircularProgressIndicator` centré + opacité 0.5 sur la
  grille pendant une opération asynchrone (pick/scan) — pas de granularité par
  fichier côté DODLP (contrairement à zcrud, cf. §1.4).

### 1.4 Couverture zcrud

Natif : `ZAppFileField`
(`packages/zcrud_core/lib/src/presentation/edition/families/z_app_file_field_widget.dart`),
seams `ZFilePicker` (`ZcrudScope.filePicker`) + `CloudStorageRepository`
(`ZcrudScope.cloudStorage`), config `FileFieldConfig`
(`packages/zcrud_core/lib/src/domain/edition/z_field_config.dart:245-335`).

Preuve — **AUCUNE implémentation concrète** de `ZFilePicker` dans le monorepo (seule
l'interface + un fake de test) :
```
$ grep -rln "ZFilePicker" --include="*.dart" packages/ | grep -v "\.bak"
packages/zcrud_core/lib/zcrud_core.dart
packages/zcrud_core/lib/src/presentation/zcrud_scope.dart
packages/zcrud_core/lib/src/presentation/edition/z_file_picker.dart
packages/zcrud_core/lib/src/presentation/edition/families/z_app_file_field_widget.dart
packages/zcrud_core/lib/src/domain/edition/z_field_config.dart
packages/zcrud_core/test/presentation/edition/file_field_a11y_rtl_test.dart
packages/zcrud_core/test/presentation/edition/z_app_file_field_test.dart
packages/zcrud_core/test/support/fake_file_picker.dart
```
RC=0, mais **zéro** occurrence hors `zcrud_core` (cœur + tests) → aucun satellite
ne fournit encore l'implémentation `image_picker`/`file_picker`/`cunning_document_scanner`.
`ZFileSource` (`z_field_config.dart:215-227`) énumère exactement les 4 sources DODLP
(`scan`, `camera`, `gallery`, `filePicker`) — **l'abstraction couvre déjà le
périmètre acquisition**, seule l'implémentation manque.

Comparaison de mapping des couples config :
| DODLP `FileFieldConfig` | zcrud `FileFieldConfig` | Écart |
|---|---|---|
| `multiple`/`maxFiles` | `ZFieldSpec.multiple` (source unique) + `maxFiles` | équivalent, refonte propre (single source of truth) |
| `allowedExtensions` (plate) | `acceptedExtensions` + `allowedDocumentTypes` (par catégorie) + `effectiveExtensions` (union) | zcrud **strictement plus riche** (MIN-2) |
| `allowedDocumentTypes: List<AppDocumentType>` (filtre les boutons du bottom-sheet) | `allowedSources: List<ZFileSource>` (filtre directement les sources, pas les types de doc) | reformulation : zcrud filtre par **source d'acquisition**, DODLP par **type de document accepté** → mapping non 1:1, mais couvre le même besoin UX (masquer un bouton non pertinent) |
| — (icône dérivée du mime, pas de repli déclaratif) | `imageFallback: bool` (MIN-2, parité « fallback image » DODLP) | zcrud a un point de config dédié que DODLP n'a pas formalisé (comportement implicite côté DODLP) |
| Statuts `draft`/`uploading`/`uploaded`/`converting`/`converted`/`embedding`/`embedded` (`AppDocumentStatus`, 7 valeurs, incl. IA/embeddings) | `ZAppFileUploadState` : `pending`/`uploading`/`uploaded`/`failed` (4 valeurs) | **écart de richesse** : DODLP porte des états de traitement post-upload (conversion, embedding IA) que `zcrud_core` n'a pas — hors périmètre `AD-1` (traitement métier, pas rendu) ; à porter dans l'app/domaine consommateur si nécessaire, pas dans le champ |

Aperçu réseau : `Image.network(file.remoteUrl!, errorBuilder: ...)` avec
`semanticLabel` (z_app_file_field_widget.dart:360-371) — **équivalent** à DODLP
(`NetworkImage` brut) ; ni l'un ni l'autre n'utilise `cached_network_image` dans
le champ d'édition (confirmé négatif ci-dessous) — **aucun écart de parité ici**.

Preuve — `cached_network_image` absent du champ d'édition DODLP :
```
$ grep -rn "CachedNetworkImage\|cached_network_image" \
    lib/modules/data_crud/presentation/ | grep -v "\.bak"
RC=1
```
(le package est utilisé ailleurs dans DODLP — `file_manager`, `auth_profile`,
`workflow/event_location_widget.dart`, `workflow/workspace.dart` — mais **jamais**
dans `data_crud`, donc **hors périmètre de parité du champ média**.)

### 1.5 Écart & stratégie de package

- **Multi-select caméra (`limit>1` → `pickMultiImage`)** : zcrud n'impose rien à
  ce niveau — c'est un détail d'implémentation du `ZFilePicker` concret. **Aucun
  changement de contrat requis** ; l'adaptateur (satellite) doit répliquer la même
  heuristique (`limit>1` → galerie multi ; sinon `pickImage(source: camera)`).
- **Scan de document (`cunning_document_scanner`)** : `ZFileSource.scan`
  existe déjà dans le contrat cœur mais **aucune implémentation n'existe**.
  Stratégie : nouvel adaptateur `ZFilePicker` (satellite `zcrud_get` pour DODLP,
  ou nouveau satellite dédié `zcrud_media`/`zcrud_file_picker` réutilisable
  cross-binding) implémentant les 4 sources via `image_picker` + `file_picker` +
  `cunning_document_scanner` + `PdfCreationService`-équivalent. **Jamais dans
  `zcrud_core`** (AD-1 : `cunning_document_scanner`/`image_picker`/`file_picker`
  sont des dépendances lourdes plateforme).
- **Recadrage (`image_cropper`)** : **ABSENT à la fois du champ générique DODLP
  ET de zcrud** — pas un écart de parité (DODLP ne le fait pas non plus pour les
  champs dynamiques). Ne pas l'ajouter par excès de zèle : le periment du crop
  DODLP est le seul avatar utilisateur (hors scope CRUD).
- **Caméra live-preview (`camera` package)** : mort côté DODLP (aucun appel hors
  `main.dart`/`platformCameras` jamais lu) → **ne pas porter dans zcrud**, aucune
  perte de parité (DODLP simule déjà « prendre une photo » via l'appareil photo
  natif de l'OS, piloté par `image_picker`).
- **Vignette vidéo (`video_thumbnail`)** : `AppDocumentType` DODLP **n'a pas** de
  variante `video` → le champ média dynamique DODLP **ne gère pas la vidéo**.
  zcrud n'a donc rien à combler ici pour la parité stricte. Si un futur besoin
  vidéo apparaît (hors DODLP, ex. lex_douane), il faudrait étendre `AppFile`
  (zcrud) avec un indicateur de type MIME vidéo + un adaptateur satellite
  `video_thumbnail`, mais ce n'est **pas requis par la parité DODLP actuelle**.
- **Risques d'adoption des packages DODLP identifiés** :
  - `cunning_document_scanner` : maintenance mono-mainteneur (package peu
    téléchargé), API native (ML Kit Android / VisionKit iOS) — dépendance
    plateforme non triviale à isoler proprement derrière `ZFilePicker` (AD-1
    respecté seulement si l'appel reste dans le satellite).
  - `image_picker`/`file_picker` : mainstream, faible risque.
  - `cached_network_image` : non requis pour parité du champ média (cf. preuve
    négative ci-dessus) — ne pas l'introduire sans un besoin identifié ailleurs
    (perf de cache réseau en liste, hors du périmètre `08`).
- **A11y/RTL/thème** : `ZAppFileField` est **déjà** strictement supérieur à
  DODLP sur ce plan — `Semantics(liveRegion:)` sur le message de dépassement
  `maxFiles` et sur l'état d'upload (`uploading`/`failed`), `EdgeInsetsDirectional`
  partout, icônes ≥ 48 dp (`IconButton`), aucune couleur codée en dur (thème
  `ZcrudTheme.of(context)`) — DODLP utilise des couleurs Material littérales
  (`Colors.blue`, `Colors.purple`, `Colors.orange`, `Colors.red` — cf.
  app_file_edition_field.dart:24,344,355,366,377,661-662) et `EdgeInsets.only`
  non-directionnel (ligne 627) : **DODLP viole les invariants AD-13/FR-26 que
  zcrud respecte déjà** — aucun retour en arrière à faire pour "coller" à DODLP
  sur ce point.
- **Rebuild granulaire (AD-2)** : `ZAppFileField` est `value-in-slice` pur
  (aucun `TextEditingController`, `ValueChanged<Object?> onChanged`) — DODLP
  reconstruit tout le widget via `setState` interne (`_AppFileEditionFieldState`,
  ex. lignes 288, 300, 310) mais reste **local au champ** (pas de refresh global
  du formulaire) donc pas de régression SM-1 identifiée dans DODLP lui-même à ce
  niveau — le gain de zcrud est la granularité **par fichier** lors de l'upload
  (`_replace` cible un seul `AppFile` via `_identity`), que DODLP n'a pas
  (`_isBusy` global à tout le champ pendant le pick, pas de reflet par-fichier
  de l'état d'upload car DODLP délègue l'upload à un `onChanged` externe, pas au
  widget lui-même).

---

## 2. Champ hors-périmètre CRUD : photo de profil utilisateur (`image_cropper` + caméra)

Non exposé via `EditionFieldTypes` (pas un champ `ZFieldSpec`) — **signalé pour
mémoire** car c'est la seule occurrence vivante de `image_cropper` dans DODLP.

- **Fichier** : `lib/modules/data_crud/functions.dart:1051-1176` (fonction
  `pickCropAndSetImage`), appelée depuis `lib/modules/auth/services/auth.dart:88-104`
  (`setUserProfilePircture`).
- **Package** : `image_cropper ^11.0.0` — `ImageCropper().cropImage(sourcePath:, maxHeight:100, maxWidth:100, compressFormat: ImageCompressFormat.png, uiSettings:[AndroidUiSettings(cropStyle: CropStyle.circle, initAspectRatio: CropAspectRatioPreset.square, lockAspectRatio:true, showCropGrid:true), IOSUiSettings(title:)])` — recadrage **circulaire forcé 100×100** (avatar).
- **Rendu visuel** : dialogue de recadrage natif plein écran (UI Android/iOS du
  plugin), cercle de crop verrouillé en ratio carré.
- **Couverture zcrud** : **ABSENTE** (confirmé §1.4 — zéro mention de « crop »
  dans tout le monorepo zcrud).
- **Verdict** : **hors scope de la parité du champ média CRUD**. C'est un widget
  d'app (avatar de profil), pas un `ZFieldSpec`/`EditionFieldType`. Ne pas créer
  de `EditionFieldType.avatar`/crop dédié dans `zcrud_core` sans mandat produit
  explicite — si DODLP veut porter ce flux sur zcrud, il resterait un **widget
  d'app** consommant directement `image_picker`+`image_cropper` en dehors du
  moteur déclaratif (comme aujourd'hui), pas un champ du schéma canonique.
  Confirmé mort ailleurs (usage commenté) :
```
$ grep -rn "pickCropAndSetImage" --include="*.dart" lib/ | grep -v "\.bak"
lib/src/presentation/side_menu/src/side_menu_drawer.dart:188:  // (commenté, appel mort)
lib/src/presentation/side_menu/src/side_menu_drawer.dart:199:  // (commenté, appel mort)
lib/modules/data_crud/functions.dart:1051:Future<String?> pickCropAndSetImage({
lib/modules/auth/services/auth.dart:94:    return await pickCropAndSetImage(
```

---

## Synthèse

| # | Champ/flux | Package(s) DODLP | Couverture zcrud | Verdict |
|---|---|---|---|---|
| 1 | `image`/`file`/`document` (champ CRUD unique) — pick galerie/caméra | `image_picker ^1.2.0` | **Natif** `ZAppFileField` + contrat `ZFilePicker`/`ZFileSource.{camera,gallery}` — **implémentation concrète absente** | Adopter (adaptateur satellite à écrire, contrat déjà suffisant) |
| 2 | Scan document → PDF | `cunning_document_scanner ^1.4.0` | **Natif** (contrat `ZFileSource.scan` déjà présent) — impl absente | Adopter le package DODLP via adaptateur satellite (jamais `zcrud_core`) |
| 3 | Sélecteur fichier générique | `file_picker ^10.3.3` | **Natif** (contrat `ZFileSource.filePicker`) — impl absente | Adopter (adaptateur) |
| 4 | Recadrage image (champ CRUD générique) | **N/A — DODLP ne recadre PAS dans le champ CRUD** | **ABSENT** (zcrud, cohérent) | Pas un gap — parité déjà atteinte (aucun des deux ne le fait) |
| 5 | Recadrage avatar profil (hors CRUD) | `image_cropper ^11.0.0` | **ABSENT** (hors scope `ZFieldSpec`) | Hors périmètre — rester un widget d'app si porté |
| 6 | Caméra live-preview | `camera ^0.11.2` | **ABSENT** | Pas un gap — package **mort** côté DODLP lui-même |
| 7 | Vignette vidéo | `video_thumbnail ^0.5.6` | **ABSENT**, et `AppDocumentType`/`AppFile` DODLP n'a **aucune** variante vidéo | Pas un gap de parité — hors périmètre du champ média DODLP actuel |
| 8 | Prévisualisation réseau | (aucun package tiers, `NetworkImage`/`Image.network` brut des deux côtés) | **Natif**, équivalent strict | Natif OK |

Aucune violation AD-1 à anticiper : tout adaptateur nécessaire (§1, §2, §3) vit
dans un satellite (`zcrud_get` ou nouveau `zcrud_media`), jamais `zcrud_core`,
qui n'importe déjà aucune de ces dépendances (confirmé par grep négatif §1.4).
