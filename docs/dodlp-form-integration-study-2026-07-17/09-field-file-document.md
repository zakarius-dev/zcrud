# Étude parité DODLP → zcrud — famille FICHIER / DOCUMENT

Extension de `STUDY.md`. Dépôts en lecture seule : `/home/zakarius/DEV/dodlp-otr`. Écriture uniquement sous
`/home/zakarius/DEV/zcrud/docs/dodlp-form-integration-study-2026-07-17/`.

## Portée

Champs DODLP de type `EditionFieldTypes.file`, `EditionFieldTypes.image`, `EditionFieldTypes.document` —
dispatchés dans `edition_screen.dart:2018-2020` vers **un seul et même widget** :
`AppFileEditionField` (`lib/modules/data_crud/presentation/widgets/app_file_edition_field.dart`, 739 l. VIVANT).

⚠️ **Correction du brief de tâche** : les packages `file_manager` (pub.dev), `open_file` et `dotted_border`
listés dans le brief comme "rendus" de la famille fichier ne sont **PAS** utilisés par `AppFileEditionField`
(le widget de champ d'édition CRUD). Preuves ci-dessous (§ Greps). Ils appartiennent à un module DODLP
**distinct** (`lib/modules/file_manager/` — bibliothèque `erp_file_manager`, écran de gestion/exploration de
fichiers cloud, hors formulaire d'édition CRUD).

---

## 1. Champ `file` / `image` / `document` (un seul widget de rendu)

### 1.1 Type de champ

| DODLP (`EditionFieldTypes`) | zcrud (`EditionFieldType`) |
|---|---|
| `file` | `file` |
| `image` | `image` |
| `document` | `document` |

`packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart:91,94,97` — les 3 valeurs existent déjà
**nativement**, mappage 1:1.

### 1.2 Package DODLP qui rend le champ + API réellement utilisée

**Widget** : `AppFileEditionField` (StatefulWidget, état local `_files`/`_deletedFiles`/`_isBusy`) —
`app_file_edition_field.dart:17-738`.

**Packages tiers réellement importés et utilisés dans ce widget** (`app_file_edition_field.dart:1-15`) :

| Package (pubspec) | Usage réel dans `AppFileEditionField` | file:line |
|---|---|---|
| `file_picker: ^10.3.3` | `FilePicker.platform.pickFiles(dialogTitle:, allowMultiple:, type: FileType.custom\|any, allowedExtensions:, withData: kIsWeb)` — sélection document générique | `app_file_edition_field.dart:225-259` (`_handlePickFile`) |
| `image_picker: ^1.2.0` | `ImagePicker().pickImage(source: camera\|gallery)` / `.pickMultiImage(limit:)` — 2 flux séparés caméra/galerie | `app_file_edition_field.dart:156-223` (`_handleCamera`, `_handleGallery`) |
| `cunning_document_scanner: ^1.4.0` | `CunningDocumentScanner.getPictures(isGalleryImportAllowed: true, iosScannerOptions: IosScannerOptions(imageFormat: png))` puis assemblage PDF via `PdfCreationService.createPdfFromImagePaths` (service interne, hors scope pkg tiers) | `app_file_edition_field.dart:119-154` (`_handleScanDocument`) |
| `path` (`p.basename`) | Extraction du nom de fichier depuis `localPath` | `app_file_edition_field.dart:9,272` |

**Packages listés dans le brief mais ABSENTS de ce widget** (greps négatifs, RC prouvé § Greps) :
- `file_manager` (pub.dev ^1.0.2, déclaré en pubspec) — **jamais importé** nulle part dans `lib/` (`package:file_manager` : 0 match). Dépendance **morte** dans le pubspec DODLP.
- `open_file` — utilisé uniquement dans `lib/modules/file_manager/file_manager.dart` et `lib/modules/syncfusion/save_file_mobile.dart` (autre module, export PDF). **Jamais** dans `app_file_edition_field.dart`.
- `dotted_border` — utilisé uniquement dans `lib/modules/file_manager/presentation/views/resource_files_screen.dart:685` (état vide d'un sélecteur de ressources cloud, feature séparée). **Jamais** dans `app_file_edition_field.dart` ni comme "zone de dépôt" du champ d'édition.

**Modes / props réellement exposés par le champ** (`FileFieldConfig`, `models/file_field_config.dart:3-33`) :
`multiple: bool`, `maxFiles: int?`, `allowedExtensions: List<String>?`, `allowedDocumentTypes: List<AppDocumentType>`
(`pdf`/`word`/`excel`/`powerpoint`/`image`/`text` — `models/app_file.dart:10-40`), `stepLevelLeftPadding: double`
(indentation dans un stepper). Pas de mode dialog/inline distinct : le sélecteur s'ouvre en
`showModalBottomSheet` (`app_file_edition_field.dart:313-387`) avec jusqu'à 4 actions conditionnelles
(scan/caméra/galerie/document) selon `allowedDocumentTypes`.

**Callback** : `onChanged: Function(List<AppFile>? newValue, [List<String> deletedIds])?` (`:20`) — déclenché
par un bouton **Save explicite** dans l'en-tête (pas d'auto-commit à chaque ajout — `_hasChanges` compare
`listEquals(_files, _initialValue)` + `_deletedIds.isNotEmpty`, `:82-83,487-491`).

### 1.3 Rendu visuel (ce qui casserait la parité)

- **Carte conteneur** avec en-tête dégradé (`widget.gradient`, 2 couleurs, défaut `[blue, purple]`), coins
  arrondis 14, ombre légère, bordure teintée si contenu présent (`:409-429`).
- En-tête (masqué en `isFullscreen`) : icône du 1er fichier + `label` + bouton **Save** (opacité 0.5 si
  aucun changement) + bouton **Add** (`+`) si `_canAdd` (`:433-528`).
- Corps : soit texte "Aucun fichier sélectionné" (`:529-536`), soit **GridView** responsive
  (`crossAxisCount = (mediaWidth/350).floor().clamp(1,4)`, `itemHeight = kToolbarHeight`) de `ListTile`
  (icône/miniature 40×40, nom, sous-titre `EXT • taille formatée` + badge "Brouillon"/"En attente d'envoi",
  action supprimer/restaurer) — `:538-672`.
- **Miniature image** : `MemoryImage` (bytes) → `FileImage` (localPath) → `base64Decode(content)` →
  `NetworkImage(cloudUrl)`, dans cet ordre de priorité (`:579-593`).
- Overlay `CircularProgressIndicator` + opacité 0.5 pendant `_isBusy` (upload/scan en cours) (`:544-567`).
- Bottom-sheet d'ajout : 4 actions en `Row` (icône ronde colorée + libellé), conditionnées par
  `allowedDocumentTypes` : Scanner (orange, PDF only, non-web), Prendre des photos (bleu), Charger des
  photos (bleu), Sélectionner un document (violet) (`:332-380`).
- Fichier supprimé (non encore persisté) reste visible à opacité 0.5 avec icône "restaurer" (`:595-596,656-666`)
  — **UX de suppression réversible avant Save**, pas de suppression immédiate.
- **Aucun tap-to-open / preview plein écran** : le `ListTile` n'a pas d'`onTap` — cliquer sur un fichier ne
  fait **rien** (seule l'action delete/restore est cliquable). L'ouverture (`OpenFile.open`) n'existe que dans
  le module `file_manager` séparé (`ErpFilePreview`, `helpers.dart:871-874`), jamais câblée sur ce champ.

### 1.4 Couverture zcrud

**NATIF, déjà implémenté** (story E3-3c + parité MIN-2) :

- `packages/zcrud_core/lib/src/presentation/edition/families/z_app_file_field_widget.dart` (459 l.) —
  `ZAppFileField` : lit `value` (`AppFile?` single / `List<AppFile>` multiple), écrit via `onChanged`
  (value-in-slice, AD-2), boutons d'action par `ZFileSource` autorisée (`scan`/`camera`/`gallery`/
  `filePicker` — mêmes 4 sources que le bottom-sheet DODLP), miniatures avec `Image.network` (repli icône),
  refus accessible au-delà de `maxFiles` (`Semantics(liveRegion:)`), reflet d'état d'upload
  (`pending`/`uploading`/`uploaded`/`failed`) + retry.
- `packages/zcrud_core/lib/src/domain/edition/app_file.dart` (242 l.) — `AppFile` value-object **sans octets**
  (id/name/mimeType/sizeBytes/remoteUrl/localPath/uploadState/progress/documentType/extra),
  `ZAppFileUploadState` (pending/uploading/uploaded/failed), `fromMap`/`toMap` défensifs (AD-10).
- `FileFieldConfig` (`z_field_config.dart:245-306`) — **parité explicite documentée dans le code** avec DODLP :
  `acceptedExtensions`, `acceptedMimeTypes`, `maxFiles`, `maxSizeBytes`, `allowedSources` (`ZFileSource`),
  `allowedDocumentTypes: Map<String, List<String>>` (commentaire `:273-280` cite littéralement "parité DODLP
  `allowedDocumentTypes`"), `imageFallback: bool` (commentaire `:282-287` cite littéralement "parité DODLP
  « fallback image »").
- Seams d'injection : `ZFilePicker` (abstrait, `z_file_picker.dart:20-29`, méthode `pick(source, config)`)
  et `CloudStorageRepository` (`domain/ports/cloud_storage_repository.dart:24`) — **AUCUNE impl concrète
  dans le repo** (seuls des fakes de test : `packages/zcrud_core/test/support/fake_file_picker.dart`,
  `fake_cloud_storage_repository.dart`). Les commentaires du widget déclarent explicitement l'impl concrète
  différée à E7 (intégration DODLP).

**ABSENT** :
- **Aucune implémentation concrète de `ZFilePicker`** (adaptateur `file_picker`/`image_picker`/
  `cunning_document_scanner`) dans un satellite zcrud — greps § Greps.
- **Aucune implémentation concrète de `CloudStorageRepository`** (Firebase Storage) dans `zcrud_firestore`
  — greps § Greps.
- Pas de flux "scanner un document → assembler en PDF" équivalent à `PdfCreationService` DODLP côté zcrud
  (logique service, hors scope pur-widget — attendu en E7).

### 1.5 Écart & stratégie de package

**Le natif zcrud (`ZAppFileField` + `FileFieldConfig` + seams) couvre déjà la totalité de la surface
fonctionnelle et visuelle du champ DODLP** : mêmes 4 sources d'acquisition, mêmes contraintes de config
(extensions/mime/taille/max/catégories), même fallback image, même modèle d'état d'upload, même contrat
"référence sans octets". Le code documente lui-même la parité (commentaires "parité DODLP" explicites).

**Ce qui reste à faire n'est PAS un gap de conception mais un manque d'implémentation concrète des seams** —
attendu et déjà scopé pour E7 :
1. **Adaptateur `ZFilePicker`** dans le binding DODLP (`zcrud_get`, ou l'app elle-même) implémentant
   `pick(source, config)` avec `file_picker` (source `filePicker`), `image_picker` (sources `camera`/
   `gallery`), `cunning_document_scanner` (source `scan`) — **réutiliser directement ces 3 packages tiers
   DODLP** (aucune raison de forker : ce sont des wrappers plateforme minces, licence MIT/BSD standard,
   maintenance active). L'adaptateur vit dans le package de binding (`zcrud_get`) ou dans l'app DODLP elle-
   même — **jamais dans `zcrud_core`** (AD-1, seam déjà prévu à cet effet).
2. **Adaptateur `CloudStorageRepository`** dans `zcrud_firestore` (Firebase Storage) pour le transport
   binaire post-acquisition — cohérent avec l'architecture offline-first existante d'AD-9.
3. **Pas de `dotted_border`** requis : DODLP ne l'utilise pas dans ce champ (module distinct) ; `ZAppFileField`
   n'a pas de "zone de dépôt" par drag&drop et ne devrait pas en introduire une hors demande explicite (rendu
   DODLP = bottom-sheet d'actions, pas de dropzone).
4. **Pas de `open_file`/`file_manager`(pub) requis** pour la parité de CE champ : DODLP lui-même n'ouvre/ne
   prévisualise pas les fichiers dans le formulaire d'édition — silence fonctionnel à reproduire tel quel
   (ne PAS ajouter un tap-to-open que DODLP n'a pas, sous peine de divergence UX non demandée).
5. **Risque déclaré `file_manager` (pub.dev)** : dépendance **morte** côté DODLP (jamais importée) — ne pas
   la porter vers zcrud ; à signaler à l'équipe DODLP comme dépendance à retirer du `pubspec.yaml` (hors
   périmètre zcrud, note informative uniquement).

**Format de valeur** :
- **DODLP** : `List<AppFile>` (`models/app_file.dart:77-243`, implémente `DynamicModel`) — champs incluant
  `bytes: List<int>?` (**exclus** de `toMap()`, jamais persistés), `content: String?` (base64 optionnel),
  `cloudPath`/`cloudUrl`, `status: AppDocumentStatus` (draft/uploading/uploaded/converting/converted/
  embedding/embedded — 7 valeurs, cycle de conversion/embedding pour recherche IA, **hors scope zcrud**).
  Résolution à l'édition : `edition_screen.dart:2018-2088` sépare fichiers `draft` (déjà en mémoire) des
  fichiers persistés référencés par **id/url** (`idsOrUrls`), re-hydratés via
  `dodlp.appFileRepository.streamFromIdsOrPaths(idsOrPaths:)` (Firestore) — donc la valeur "au repos" sur
  l'entité est vraisemblablement `List<String>` (ids/chemins), gonflée en `List<AppFile>` uniquement en
  mémoire d'édition.
- **zcrud** : `AppFile?` (single) / `List<AppFile>` (multiple) directement dans la tranche — **value object
  pur-Dart sans bytes** (`domain/edition/app_file.dart:55-71`), `uploadState` **4 valeurs** seulement
  (pending/uploading/uploaded/failed — pas de pipeline conversion/embedding, jugé hors scope formulaire
  d'édition générique). Écart assumé et documenté (`ZAppFileUploadState` est un sous-ensemble volontaire
  d'`AppDocumentStatus`) — si DODLP a besoin du statut `embedding`/`embedded` pour piloter une UI de
  recherche IA, ce sera un **`extra: Map<String,dynamic>`** (slot d'extension AD-4), pas une extension de
  l'enum fermé.

---

## 2. Greps (preuves, commande + RC)

```bash
$ cd /home/zakarius/DEV/dodlp-otr
$ grep -rn "dotted_border" --include="*.dart" lib/
lib/modules/file_manager/file_manager.dart:49:import 'package:dotted_border/dotted_border.dart';
$ echo RC=$?
RC=0

$ grep -rln "package:open_file" --include="*.dart" lib/
lib/modules/file_manager/file_manager.dart
lib/modules/syncfusion/save_file_mobile.dart
$ echo RC=$?
RC=0

$ grep -rn "package:file_manager" --include="*.dart" lib/
(aucune sortie)
$ echo RC=$?
RC=1

$ grep -n "DottedBorder" lib/modules/file_manager/presentation/views/resource_files_screen.dart
685:                                      ? DottedBorder(
$ echo RC=$?
RC=0

$ grep -n "OpenFile" lib/modules/data_crud/presentation/widgets/app_file_edition_field.dart
(aucune sortie)
$ echo RC=$?
RC=1

$ grep -n "AppFileEditionField(" lib/modules/data_crud/presentation/views/edition_screen.dart
2063:              return AppFileEditionField(
$ echo RC=$?
RC=0
```

```bash
$ cd /home/zakarius/DEV/zcrud
$ grep -rln "implements ZFilePicker\|extends ZFilePicker" packages/
packages/zcrud_core/test/support/fake_file_picker.dart
$ echo RC=$?
RC=0   # (seul un fake de test — aucune impl concrète, prouvé par absence hors test/)

$ grep -rln "implements CloudStorageRepository\|extends CloudStorageRepository" packages/
packages/zcrud_core/test/presentation/edition/z_app_file_field_test.dart
packages/zcrud_core/test/support/fake_cloud_storage_repository.dart
$ echo RC=$?
RC=0   # (idem : uniquement test/)

$ grep -n "^  dotted_border" packages/zcrud_ui_kit/pubspec.yaml
(aucune sortie)
$ echo RC=$?
RC=1   # dotted_border cité en COMMENTAIRE ("AUCUN tiers ... dotted_border") comme dépendance INTERDITE,
       # pas une dépendance réelle
```

---

## 3. Synthèse tableau

| Champ DODLP | `EditionFieldType` zcrud | Package DODLP réel (champ édition) | Couverture zcrud | Verdict |
|---|---|---|---|---|
| `file` | `file` | `file_picker` (générique) | **Natif** `ZAppFileField`+`FileFieldConfig` (E3-3c/MIN-2) | Natif OK — implémenter `ZFilePicker` adapter (E7) |
| `image` | `image` | `image_picker` (caméra+galerie) | **Natif** `ZAppFileField` (`imageFallback`, `Image.network`) | Natif OK — implémenter `ZFilePicker` adapter (E7) |
| `document` (scan) | `document` | `cunning_document_scanner` (+ service PDF interne) | **Natif** (`ZFileSource.scan` prévu) mais pas d'impl assemblage PDF | Natif OK côté widget — gap = adapter `ZFilePicker.pick(scan)` + service PDF (E7) |
| Upload/transport binaire | — (seam) | Firestore custom (`appFileRepository`) | Port `CloudStorageRepository` défini, **ABSENT** en impl | Gap — adapter `zcrud_firestore` (E7) |
| Dépôt drag&drop (`dotted_border`) | — | **Non utilisé** dans le champ (module `file_manager` séparé) | N/A | Pas un écart — ne rien ajouter |
| Ouverture fichier (`open_file`) | — | **Non utilisé** dans le champ (module `file_manager` séparé) | N/A | Pas un écart — ne rien ajouter |
| Package `file_manager` (pub) | — | **Jamais importé** (dépendance morte) | N/A | Signaler à DODLP (hors zcrud) |
