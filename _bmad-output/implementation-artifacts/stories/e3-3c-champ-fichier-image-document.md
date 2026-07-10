---
baseline_commit: acc6a2138a437fd3d1c53886246fa3340c0b540f
---
# Story 3.3c : Champ fichier / image / document (`ZAppFileField`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a développeur intégrant zcrud,
I want déclarer un champ **fichier / image / document** dérivé du schéma, avec un modèle `AppFile` sérialisable, une `FileFieldConfig` (types acceptés, sources scan/caméra/galerie/picker, tailles), un widget `ZAppFileField` (boutons d'action, prévisualisation, suppression, états d'upload) — le **picker** et le **stockage cloud** étant des **seams injectés** (jamais des dépendances lourdes de `zcrud_core`),
so that les types `file`/`image`/`document` du catalogue quittent le repli « non pris en charge » et atteignent la **parité DODLP (SM-2)**, tout en gardant `zcrud_core` **sans aucune dépendance lourde** (image_picker/file_picker/firebase_storage) — invariant AD-1, cœur OUT=0.

## Contexte

Cette story **comble le trou de couverture FR-2** relevé au contrôle de complétude : `file`/`image`/`document` étaient les derniers types du catalogue de parité DODLP sans famille de rendu. Elle avait été **sautée par erreur** dans la séquence E3 ; **E3-1..E3-6 sont `done` sauf E3-3c**. Elle **complète E3** (parité DODLP, SM-2).

**État réel du dispatcher (source de vérité `familyOf`).** E3-3a (`e3-3a-dispatcher-familles-base.md`, done) a livré `EditionFamily` + `familyOf(EditionFieldType)` — un `switch` **exhaustif SANS `default:`** sur les **39** valeurs de `EditionFieldType` (AC2 : un type non classé **casse la compilation**). E3-3b (sous-stories -1/-2/-3, done) a ajouté les familles avancées (`tags`/`rowChips`/`rating`/`slider`/`color`/`subItems`/`dynamicItem`/`signature`/`widget`) et le **`ZWidgetRegistry`** injecté (`registryOrFallback` pour markdown/géo/tél/`icon`/`custom`). **Aujourd'hui `file`/`image`/`document` (ET `stepper`) tombent encore dans `EditionFamily.unsupported`** → `ZUnsupportedFieldWidget` (repli accessible, jamais un crash). E3-3c **fait sortir `file`/`image`/`document` de `unsupported`** vers une **famille dédiée** ; `stepper` reste seul en `unsupported` (traité par E3-5, regroupement multi-étapes, pas un champ-feuille).

**Machinerie réutilisée (JAMAIS réécrite).** Le champ fichier est un champ **value-in-slice** comme les familles E3-3a/E3-3b non-clavier (booléen/select/relation/color) : il **lit** `value` depuis la tranche `field.name` via `ZFieldListenableBuilder` (frontière de rebuild, E2-7) et **écrit** via `controller.setValue(field.name, appFile)` sur interaction (pick/remove) — **aucun `TextEditingController`**, aucun `setState` global, rebuild **borné à ce seul champ** (AD-2, objectif produit n°1). Le dispatcher `ZFieldWidget` (`z_field_widget.dart`) route la nouvelle famille dans le `switch` de rendu, **dans** la souscription au slice existante.

**Parité DODLP (technical-inventory §2.8 / §3).** DODLP porte le trio mature `AppFile` (+ enums `AppDocumentType`/`Status`), `FileFieldConfig` (multiple/maxFiles/extensions), `AppFileEditionField` (scan/caméra/galerie/picker, 738 l.), derrière l'unique point de couplage Firebase `CloudStorageRepository` (`firebase_cloud_storage_repository_impl.dart`). IFFD n'a **pas** de champ fichier générique. La reconnaissance (§ *décisions*) tranche : **`zcrud_core` absorbe le champ fichier, le couplage limité à l'interface `CloudStorageRepository`** ; l'orchestration upload draft→cloud (copiée-collée dans les écrans DODLP) et l'impl Firebase Storage sont **déportées** (E5/E7).

### Frontière E3-3c / E5 / E7 (DÉCIDÉE — NON-NÉGOCIABLE AD-1)

| Livrable | Story | Couche / package |
|---|---|---|
| `AppFile` (modèle réf. de fichier, **sérialisable, sans bytes lourds**) + `ZAppFileUploadState` | **E3-3c** | `zcrud_core` domaine pur-Dart |
| `FileFieldConfig` (types/sources/tailles) + `ZFileSource` | **E3-3c** | `zcrud_core` domaine pur-Dart (`extends ZFieldConfig`) |
| `CloudStorageRepository` — **port neutre** (interface `Either<ZFailure,_>`) | **E3-3c** | `zcrud_core` domaine (`ports/`) — **interface seule** |
| `ZFilePicker` — **seam d'acquisition** (interface pure) | **E3-3c** | `zcrud_core` présentation (interface seule, injectée) |
| `ZAppFileField` (widget : actions/prévisualisation/suppression/états) | **E3-3c** | `zcrud_core` présentation |
| `EditionFamily.file` + routage `familyOf`/dispatch | **E3-3c** | `zcrud_core` présentation |
| **Impl concrète du picker** (image_picker/file_picker, scan/caméra) | **E7 / app / binding** | app DODLP ou binding — **jamais `zcrud_core`** |
| **Impl concrète upload/download** (Firebase Storage) | **E5** | `zcrud_firestore` (`FirebaseCloudStorageRepositoryImpl`) |
| Orchestration draft→cloud dans les écrans métier | **E7** | app DODLP |

> **INVARIANT AD-1 (cœur OUT=0).** `zcrud_core` **NE DOIT tirer AUCUNE** dépendance lourde : ni `image_picker`, ni `file_picker`, ni `firebase_storage`/`firebase_*`. Le picker **et** le stockage sont des **interfaces** définies dans le cœur et **injectées** ; leurs impls concrètes vivent dans l'app/le binding (picker) et `zcrud_firestore` (storage). En test, un **fake picker** et un **fake `CloudStorageRepository`** prouvent le comportement sans dépendance lourde. Le graphe reste acyclique, `zcrud_core` out-degree **0**.

## Acceptance Criteria

1. **`file`/`image`/`document` → famille dédiée (0 `unsupported`).** `familyOf` route `EditionFieldType.file`, `.image`, `.document` vers une **nouvelle** `EditionFamily.file` (et **plus** vers `unsupported`). Le `switch` reste **exhaustif SANS `default:`** (les 39 valeurs énumérées ; un type non classé casse la compilation — invariant AC2 d'E3-3a préservé). Test d'exhaustivité (itère `EditionFieldType.values`, 39) : `file`/`image`/`document` → `EditionFamily.file` ; **`stepper` est désormais le SEUL type en `EditionFamily.unsupported`**. *(Régression attendue : les assertions existantes de `z_field_dispatch_test.dart` classant `file`/`image`/`document` en `unsupported` DOIVENT être mises à jour ; ne pas casser les autres familles.)*

2. **`AppFile` — modèle domaine pur-Dart, sérialisable, sans bytes lourds.** `AppFile` (couche `domain`, **pur-Dart**, aucun import Flutter/Firebase) porte une **référence** de fichier : `id` (`String?` opaque), `name`, `mimeType`/`contentType`, `sizeBytes` (`int?`), `remoteUrl` (`String?`, renseigné après upload), `localPath`/`sourceUri` (`String?`, chemin local pré-upload), `uploadState` (`ZAppFileUploadState`), `progress` (`double?` 0..1 optionnel), et un `extra`/`documentType` optionnel pour la parité (`AppDocumentType` DODLP → valeur ouverte). **Interdit : aucun champ de bytes/`Uint8List`** dans le modèle (la tranche reste légère — AD-2 ; le transport binaire est la responsabilité de l'impl picker/storage). `toMap`/`fromMap` (ou `toJson`/`fromJson`) round-trip testés ; **désérialisation défensive AD-10** : un champ absent/corrompu ne fait **jamais** échouer le parse (défaut sûr, `uploadState` inconnu → repli, jamais un `throw`). `copyWith` fourni (sentinelle non requise ici, documenter la convention). `==`/`hashCode`.

3. **`ZAppFileUploadState` — enum d'état d'upload.** Valeurs **camelCase** (canonique §5) couvrant au minimum : `pending` (local, pas encore uploadé), `uploading`, `uploaded` (URL distante disponible), `failed`. Discipline `@JsonKey(unknownEnumValue:)`/repli défensif documentée (AD-10). L'état vit **dans** `AppFile` (une seule voie de vérité de l'état du fichier).

4. **`FileFieldConfig extends ZFieldConfig` — pur-données `const`.** Sous-classe `const` de `ZFieldConfig` (pattern `ZTextConfig`/`ZNumberConfig`) portant : `acceptedExtensions`/`acceptedMimeTypes` (`List<String>`), `maxFiles` (`int?`), `maxSizeBytes` (`int?`), `allowedSources` (ensemble de `ZFileSource`). `==`/`hashCode`. `ZFileSource` = enum **camelCase** : `scan`, `camera`, `gallery`, `filePicker`. Défauts sûrs si `config == null` (toutes sources autorisées ou un défaut documenté, aucun crash). *(Le multiple s'appuie sur `ZFieldSpec.multiple` existant + `maxFiles` ; cf. Ambiguïté 2.)*

5. **`CloudStorageRepository` — port NEUTRE (interface seule, `Either<ZFailure,_>`).** Interface **abstraite** en `domain/ports/`, **backend-agnostique** (AD-5) : aucune signature n'expose de type Firebase/`cloud_firestore` ; passe `domain_purity_test` (0 import Flutter/Firebase, 0 type backend textuel). Contrat AD-11 : opérations retournant `ZResult<T>` (`Either<ZFailure,T>`) — p. ex. `Future<ZResult<AppFile>> upload(AppFile file)` (renvoie l'`AppFile` avec `remoteUrl`/`uploaded`), `Future<ZResult<Unit>> delete(AppFile file)` (ou par `remoteUrl`), lecture d'URL de download ; progression optionnelle exposée en `Stream<double>` **nu** (jamais enveloppé — AD-11) si fourni. **Aucune impl concrète dans `zcrud_core`** (impl Firebase Storage = E5). Un **fake** en test prouve `upload → Right(uploaded)`, échec → `Left(ServerFailure)`, `delete → Right(unit)`.

6. **`ZFilePicker` — seam d'acquisition injecté (interface pure).** Interface (couche `presentation`, **aucune dépendance lourde** — juste `AppFile` + `FileFieldConfig`) exposant l'acquisition par source, p. ex. `Future<List<AppFile>> pick({required ZFileSource source, required FileFieldConfig config})` (ou méthodes `pickImageFromGallery`/`captureFromCamera`/`scanDocument`/`pickFile`). Renvoie des `AppFile` en `uploadState: pending` avec métadonnées + `localPath` (**pas de bytes**). **Injecté via `ZcrudScope`** (nouveau champ nullable `filePicker`, même pattern qu'`widgetRegistry`), défaut `null`. L'impl concrète (image_picker/file_picker/scan) vit dans l'app/le binding (E7). En test, un **fake `ZFilePicker`** renvoie un `AppFile` déterministe.

7. **Acquisition → `AppFile` en tranche (value-in-slice, AD-2).** `ZAppFileField` rend **un bouton d'action par source autorisée** (`allowedSources` ∩ défaut) : appuyer déclenche `ZFilePicker.pick(source)` puis **écrit** le/les `AppFile` dans la tranche via `controller.setValue(field.name, …)`. Aucune souscription élargie : le rebuild reste **borné à ce champ** (frontière `ZFieldListenableBuilder` réutilisée). Test (fake picker) : tap « galerie » → `AppFile` présent dans la tranche `field.name` ; le compteur de build des **voisins** est inchangé. Si `filePicker == null` : les actions sont désactivées/absentes proprement (aucun crash).

8. **Multiplicité `single`/`multiple`.** `ZFieldSpec.multiple == false` → la tranche porte un `AppFile?` (le pick **remplace**) ; `multiple == true` → `List<AppFile>` (le pick **ajoute**, borné par `FileFieldConfig.maxFiles` s'il est défini — au-delà, refus accessible sans crash). Test des deux modes.

9. **Prévisualisation + suppression.** (a) **Image uploadée** (`uploadState == uploaded`, `remoteUrl != null`) → miniature via `Image.network(remoteUrl)` (web-safe, aucune dépendance lourde). (b) **Document** ou **fichier local pré-upload** → **icône** (dérivée du mime/`documentType`) + **nom de fichier** (pas de rendu binaire local — cf. Ambiguïté 4 ; extension différée). (c) Chaque fichier a un **bouton de suppression** (≥ 48 dp, `Semantics`) qui réécrit la tranche (retire l'`AppFile`). Test : preview image vs document distincts ; suppression met à jour la tranche.

10. **États d'upload via le port (fake), sans dépendance lourde.** Sur acquisition, si un `CloudStorageRepository` est injecté, `ZAppFileField` déclenche `upload(appFile)` et **reflète** `AppFile.uploadState` (`pending → uploading → uploaded`/`failed`) dans la tranche ; l'état `failed` est **accessible** (message/`Semantics`, indication l10n) et **réessayable** (bouton retry accessible) — jamais un crash. Si **aucun** `CloudStorageRepository` n'est injecté, l'`AppFile` reste `pending` (orchestration déférée à l'app/`onSubmit` — parité DODLP draft→cloud) sans crash. Test avec **fake storage** (succès → `uploaded`+`remoteUrl` ; `Left(ServerFailure)` → `failed`) **et** sans storage (reste `pending`). **Le port n'a AUCUNE impl concrète dans `zcrud_core`** (E5).

11. **a11y (AD-13/FR-23).** Chaque bouton d'action (scan/caméra/galerie/picker), chaque bouton de suppression et de retry porte des **`Semantics` explicites** (libellé l10n) et une **cible ≥ 48 dp** ; l'état d'upload (`uploading`/`failed`) est **annoncé** sémantiquement ; les miniatures portent un label alternatif (nom de fichier). Test a11y : `meetsGuideline(androidTapTargetGuideline)` sur un formulaire contenant le champ fichier + présence des labels sémantiques.

12. **RTL + pureté de style (AD-13).** (a) Rendu sous `Directionality(textDirection: TextDirection.rtl)` correct (pas d'overflow, alignements cohérents ; rangée de boutons/miniatures en `Wrap`/`Row` directionnel). (b) `style_purity_test.dart` reste **vert** sur **tous** les nouveaux fichiers `lib/src/presentation/**` : usage **exclusif** d'`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start-end`/`PositionedDirectional` ; **aucun** style/couleur codé en dur (thème via `Theme.of`/`ZcrudTheme` — FR-26).

13. **AD-1 prouvé : `zcrud_core` SANS dépendance lourde.** (a) `packages/zcrud_core/pubspec.yaml` ne gagne **aucune** dépendance `image_picker`/`file_picker`/`firebase_storage`/`firebase_*`/Syncfusion/Quill. (b) `presentation_purity_test` + `domain_purity_test` restent **verts** sur les nouveaux fichiers (aucun import interdit ; `services.dart` seulement via l'allowlist par symbole si strictement nécessaire — préférer l'éviter). (c) Le **graphe de dépendances reste acyclique**, `zcrud_core` out-degree **0** (`graph_proof`/`melos run verify`), `melos list` = 14, **0** `.g.dart` committé. (d) Un test/grep dédié asserte l'**absence textuelle** d'`image_picker`/`file_picker`/`firebase` dans `lib/`.

14. **SM-1 préservé (objectif produit n°1, AD-2).** Sur un formulaire de référence **incluant un champ fichier**, taper 100 caractères dans un champ **texte** ne reconstruit **que** ce champ (le compteur de build du champ fichier et des autres voisins est **inchangé**, compteur structurel du formulaire = 1) ; focus/curseur préservés. L'ajout de la famille fichier au dispatcher **n'introduit aucun rebuild global**.

15. **l10n (AD-13/FR-23).** Tous les libellés (actions scan/caméra/galerie/fichier, suppression, retry, états `uploading`/`upload échoué`, préviz alternative) passent par `ZcrudLabels`/le registre l10n injecté (clés en/fr ajoutées à `z_localizations.dart`) — **aucun** littéral métier codé en dur.

## Tasks / Subtasks

- [x] **Task 1 — Modèle domaine `AppFile` + `ZAppFileUploadState`** (AC: 2, 3)
  - [x] Créer `AppFile` en `packages/zcrud_core/lib/src/domain/edition/app_file.dart` — pur-Dart, **sans bytes**, champs de la table AC2, `copyWith`, `==`/`hashCode`.
  - [x] `toMap`/`fromMap` **défensifs** (AD-10) : champ absent/corrompu → défaut sûr, jamais un `throw` ; `uploadState` inconnu → repli `pending` documenté.
  - [x] `ZAppFileUploadState` (`pending`/`uploading`/`uploaded`/`failed`), valeurs camelCase, repli défensif (`fromName`).
- [x] **Task 2 — `FileFieldConfig` + `ZFileSource`** (AC: 4)
  - [x] `FileFieldConfig extends ZFieldConfig` (`const`, `==`/`hashCode`) dans `z_field_config.dart` : `acceptedExtensions`/`acceptedMimeTypes`, `maxFiles`, `maxSizeBytes`, `allowedSources`.
  - [x] `ZFileSource` (`scan`/`camera`/`gallery`/`filePicker`, camelCase) ; défaut sûr = toutes sources si `config == null`.
- [x] **Task 3 — Port neutre `CloudStorageRepository`** (AC: 5)
  - [x] Interface **abstraite** en `packages/zcrud_core/lib/src/domain/ports/cloud_storage_repository.dart` — `upload`/`delete`/`downloadUrl` en `ZResult`, progression `Stream<double>` **nu** ; **backend-agnostique** (AD-5), aucun type Firebase.
  - [x] Aucune impl concrète ici (E5). Frontière E5 documentée dans le doc-comment.
- [x] **Task 4 — Seam `ZFilePicker` + injection `ZcrudScope`** (AC: 6)
  - [x] Interface `ZFilePicker` (présentation, pure) : `pick({source, config}) → Future<List<AppFile>>`, renvoie `pending` + `localPath`, **pas de bytes**.
  - [x] Ajouté `final ZFilePicker? filePicker;` **et** `final CloudStorageRepository? cloudStorage;` à `ZcrudScope` (défaut `null`, `updateShouldNotify` mis à jour) — **Décision : injection via `ZcrudScope`** (Ambiguïté 5, option a — symétrie `filePicker`/`widgetRegistry`, dégradation `null` explicite).
- [x] **Task 5 — `EditionFamily.file` + routage `familyOf`/dispatch** (AC: 1)
  - [x] Ajouté `EditionFamily.file` ; `file`/`image`/`document` → `EditionFamily.file` dans `familyOf` (retirés de `unsupported` ; **`stepper` seul en `unsupported`**). `switch` toujours exhaustif SANS `default:`.
  - [x] Ajouté le `case EditionFamily.file` dans le `switch` de rendu de `z_field_widget.dart`, **dans** la souscription au slice (value-in-slice) → `ZAppFileField`.
- [x] **Task 6 — Widget `ZAppFileField`** (AC: 7, 8, 9, 10)
  - [x] Créé `families/z_app_file_field_widget.dart` : lit `value` (`AppFile?`/`List<AppFile>`), boutons d'action par `allowedSource` → `ZFilePicker` → `setValue` ; suppression → `setValue` ; multiplicité single/multiple (+`maxFiles`).
  - [x] Prévisualisation : `Image.network` (image uploadée, `errorBuilder` web-safe) vs icône+nom (document/local) ; suppression + retry accessibles.
  - [x] Orchestration upload via `CloudStorageRepository` injecté (reflet de `uploadState` dans la tranche via `liveValue` synchrone) ; sans port → reste `pending`. **Aucune** dépendance lourde.
- [x] **Task 7 — a11y / RTL / thème / l10n** (AC: 11, 12, 15)
  - [x] `Semantics` + cibles ≥ 48 dp (`IconButton`) sur chaque contrôle ; insets/alignements directionnels exclusivement ; thème injecté ; clés l10n en/fr ajoutées à `z_localizations.dart`.
- [x] **Task 8 — Barrel exports** (AC: 2, 4, 5, 6, 7)
  - [x] Exporté `app_file.dart` (`AppFile`/`ZAppFileUploadState`), `cloud_storage_repository.dart`, `z_file_picker.dart`, `z_app_file_field_widget.dart` dans `lib/zcrud_core.dart` (`FileFieldConfig`/`ZFileSource` via `z_field_config.dart` déjà exporté ; `EditionFamily.file` via `edition_field_family.dart`).
- [x] **Task 9 — Mise à jour des tests régressés** (AC: 1)
  - [x] `z_field_dispatch_test.dart` mis à jour : `file`/`image`/`document` → `EditionFamily.file` + `ZAppFileField` (**0 fallback**) ; **`stepper` = seul `unsupported`** ; partition recalculée `base(13)+hidden(1)+feuilles(8)+freeWidget(1)+registre(12)+file(3)+unsupported(1)=39`.
- [x] **Task 10 — Tests** (AC: 1–15) — voir « Testing ».
- [x] **Task 11 — Vérif verte** : `analyze` RC=0 (14 pkgs) → `flutter test` RC=0 (427 zcrud_core) → `melos run verify` RC=0 (CORE OUT=0, ACYCLIQUE, gates reflectable/secrets/codegen/compat, `melos list`=14, 0 `.g.dart` committé). `melos run generate` = no-op (aucun modèle annoté dans zcrud_core).

## Dev Notes

### Architecture — invariants applicables (NON-NÉGOCIABLES)

- **AD-1 (cœur OUT=0, direction acyclique)** : `zcrud_core` **ne dépend d'aucun** package zcrud satellite ni d'aucune dépendance lourde (Firebase/Syncfusion/Quill/Maps) **ni d'`image_picker`/`file_picker`/`firebase_storage`**. Picker + stockage = **interfaces** dans le cœur, **injectées** ; impls concrètes hors cœur (app/binding pour le picker, `zcrud_firestore`/E5 pour le storage). [Source: architecture.md#AD-1]
- **AD-5 (domaine backend-agnostique, ports & adapters)** : `CloudStorageRepository` est un **port neutre** ; aucun type Firebase/`cloud_firestore` ne fuit dans le domaine. La traduction concrète vit dans l'adaptateur E5. [Source: architecture.md#AD-5]
- **AD-6 (injection & cycle de vie pluggables)** : les seams (`ZFilePicker`, `CloudStorageRepository`) sont résolus via `ZcrudScope`/binding — jamais un singleton statique mutable. [Source: architecture.md#AD-6]
- **AD-11 (Either/flux nus/`ZFailure`)** : le port retourne `ZResult<T>` = `Either<ZFailure,T>` (dartz), `ZResult<Unit>` pour void ; la progression éventuelle est un `Stream<double>` **nu**. [Source: architecture.md#AD-11, `z_failure.dart:93` `typedef ZResult<T> = Either<ZFailure,T>`]
- **AD-10 (désérialisation défensive)** : `AppFile.fromMap` ne casse jamais sur champ absent/corrompu (défaut sûr, `uploadState` inconnu → repli). [Source: architecture.md#AD-10]
- **AD-2 (rebuilds granulaires, objectif produit n°1)** : le champ fichier = **value-in-slice** ; il réutilise `ZFieldListenableBuilder` (E2-7) comme frontière de rebuild ; aucun `setState` global ; aucun `TextEditingController`. [Source: architecture.md#AD-2]
- **AD-13 (RTL/a11y/l10n)** : directionnel exclusif, `Semantics`, cibles ≥ 48 dp, l10n injecté. [Source: architecture.md#AD-13, binds FR-23]
- **FR-26** : aucun style/couleur codé en dur ; thème injecté (`ZcrudTheme`/`ThemeExtension`), repli `Theme.of`. [Source: architecture.md#AD-13/CLAUDE.md]
- **AD-4 (extensibilité)** : `documentType` (parité `AppDocumentType` DODLP) est traité comme **valeur ouverte** (repli défensif), pas un `sealed` inter-package. [Source: architecture.md#AD-4]

### CLAUDE.md — Key Don'ts directement pertinents

- **Jamais** faire dépendre `zcrud_core` de Firebase / d'une dépendance lourde → picker/storage **injectés**.
- **Jamais** laisser fuiter un type `cloud_firestore` dans le domaine → port neutre.
- **Jamais** `try-catch` nu dans un repository → envelopper en `Either<ZFailure,T>` (impl E5).
- **Jamais** `EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`, `TextAlign.left/right`, `Positioned(left/right)` → variantes **directionnelles**.
- **Jamais** `ListView(children: [...])` → `ListView.builder` (si liste de fichiers scrollable).
- **Jamais** importer un gestionnaire d'état dans `zcrud_core` ; **jamais** style/couleur en dur.
- **Toujours** `Semantics` explicites + cibles ≥ 48 dp ; `const` pour les widgets immuables.

### Fichiers existants à réutiliser / modifier (LIRE avant d'implémenter — ne pas réécrire)

- `packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart` — **`EditionFamily` + `familyOf`** (switch exhaustif 39 valeurs SANS `default:`). **MODIFIER** : ajouter `EditionFamily.file` ; router `file`/`image`/`document` vers elle (retirer de `unsupported` ; `stepper` y reste seul). *(État actuel : `case EditionFieldType.stepper: case .file: case .image: case .document: return EditionFamily.unsupported;` — scinder.)*
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` — **dispatcher-hôte** : `switch (family)` de rendu **dans** `ZFieldListenableBuilder`. **MODIFIER** : ajouter `case EditionFamily.file: return ZAppFileField(...)`. S'inspirer du câblage `signature`/`freeWidget`/`_dispatchRegistry` (value-in-slice, `onChanged → setValue`). Ne PAS allouer de `TextEditingController` (fichier = non-clavier ; `familyUsesTextController` inchangé).
- `packages/zcrud_core/lib/src/domain/edition/z_field_config.dart` — **AJOUTER** `FileFieldConfig` (+`ZFileSource`) aligné sur `ZTextConfig`/`ZNumberConfig`/`ZSliderConfig` (`const`, `==`/`hashCode`). Le doc-comment existant **prévoit déjà** `FileFieldConfig` (« → E-fichier »).
- `packages/zcrud_core/lib/src/domain/ports/z_repository.dart` (+ `z_acl.dart`) — **patron du port** : `abstract class`, `ZResult`/`Stream` nu, doc-comment AD-5/AD-11. **AJOUTER** un pair `cloud_storage_repository.dart` dans `ports/`.
- `packages/zcrud_core/lib/src/domain/failures/z_failure.dart` — `typedef ZResult<T> = Either<ZFailure,T>` + `DomainFailure`/`ServerFailure`/`NotFoundFailure` (réutiliser pour le fake storage).
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` — **AJOUTER** `final ZFilePicker? filePicker;` (+ `cloudStorage?` si retenu), mettre à jour le constructeur `const` et `updateShouldNotify` (pattern exact d'`widgetRegistry`).
- `packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart` + `families/z_free_widget_field_widget.dart` — **patron du seam injecté** (`ZcrudScope.maybeOf(context)?.xxx`, repli si `null`). Répliquer pour `filePicker`/`cloudStorage`.
- `packages/zcrud_core/lib/src/presentation/edition/families/z_unsupported_field_widget.dart`, `z_boolean_field_widget.dart`, `z_select_field_widget.dart` — patrons a11y/RTL/thème/l10n des familles value-in-slice (Semantics, ≥ 48 dp, directionnel, `ZcrudTheme.of`).
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` — **AJOUTER** les clés (en/fr) : actions (`fileActionScan`/`Camera`/`Gallery`/`Pick`), `fileRemove`, `fileRetry`, `fileUploading`, `fileUploadFailed`, `filePreviewAlt`. *(Pattern : `unsupportedField`/`selectTime` déjà présents en/fr.)*
- `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart` — **39 valeurs** (`file`/`image`/`document` présents), source du test d'exhaustivité. **NE PAS** modifier (les types existent déjà).
- Gardes : `test/purity/domain_purity_test.dart` (domaine pur-Dart, 0 Flutter/Firebase), `presentation_purity_test.dart` (whitelist `flutter/material` + `form_builder_validators` ; `services.dart` allowlisté par symbole), `style_purity_test.dart` (directionnel + couleur) — **doivent rester verts**.

### Modèle de référence DODLP (parité SM-2, ne PAS copier le couplage)

- `AppFile` DODLP (`models/app_file.dart:77`, + enums `AppDocumentType`/`Status`) : **matures mais couplés** au singleton `dodlp` + Firestore + `cloudPath` codé dans les écrans (technical-inventory §*Risques* : « `AppFile` couplé au singleton + Firestore + convention cloudPath »). E3-3c **découple** : `AppFile` **pur**, sans bytes, sans cloudPath métier ; le chemin cloud est la responsabilité de l'impl storage (E5/app).
- `FileFieldConfig` DODLP (`models/file_field_config.dart:3`) : multiple/maxFiles/extensions → repris en `const` pur-données.
- `AppFileEditionField` DODLP (738 l., scan/caméra/galerie/picker) : **réécrit** en `ZAppFileField` **rebuild-granulaire** (value-in-slice) + seams injectés — pas de portage 1:1 du couplage Firebase/singleton.
- `CloudStorageRepository` DODLP/IFFD (`firebase_cloud_storage_repository_impl.dart:9`) : **unique point de couplage Firebase Storage** → devient un **port neutre** ici ; l'impl `FirebaseCloudStorageRepositoryImpl` est **E5** (`zcrud_firestore`).

### Décision d'intégration (à respecter — AD-1/AD-2)

- **Seams injectés, jamais des deps.** `ZFilePicker` (acquisition) et `CloudStorageRepository` (transport) sont **des interfaces** définies dans le cœur. `zcrud_core` **n'ajoute aucune** dépendance lourde à son `pubspec.yaml`. Les impls concrètes : app/binding (picker, via image_picker/file_picker) et `zcrud_firestore`/E5 (storage, via firebase_storage). Prouvé par AC13 (pubspec + purity + graph + grep).
- **value-in-slice.** La tranche porte l'`AppFile`/`List<AppFile>` **typé** (cohérent avec la décision E3-3a « valeur typée en tranche » pour num/date/select). La (dé)sérialisation `toMap`/`fromMap` s'applique à la frontière de persistance (générateur/adapter), pas dans le slice runtime.
- **Prévisualisation web-safe.** `Image.network(remoteUrl)` (image uploadée) est sans dépendance et web-safe. **Éviter** `Image.file`/`dart:io` (non web-safe, et `dart:io` n'est pas dans la whitelist de pureté). Le rendu binaire **local** (avant upload) est **déféré** (icône + nom en attendant) ; un `ZFilePreviewBuilder` optionnel injecté pourra l'enrichir plus tard (extension AD-4) — **hors périmètre E3-3c**.

### Ambiguïtés détectées (trancher en dev, sans bloquer)

1. **Emplacement d'`AppFile`.** `domain/edition/app_file.dart` (proche de `z_field_config.dart`/`z_field_spec.dart`) **ou** un nouveau `domain/file/`. Recommandé : `domain/edition/` (cohérent, aucune nouvelle sous-couche). `AppFile` est un **value object**, **PAS un `ZEntity`** (pas de soft-delete/`ZSyncMeta`/matérialisation d'`id`).
2. **Multiplicité.** Réutiliser `ZFieldSpec.multiple` (existant) pour single/multiple + `FileFieldConfig.maxFiles` pour la borne. Ne PAS ajouter un `multiple` à la config (éviter la double source). `single` → `AppFile?` ; `multiple` → `List<AppFile>`.
3. **Orchestration d'upload : auto vs à la soumission.** Recommandé : upload **déclenché à l'acquisition** si un `CloudStorageRepository` est injecté (reflet immédiat de `uploadState`), **sinon** l'`AppFile` reste `pending` et l'app orchestre à `onSubmit` (parité DODLP draft→cloud). Tester les deux chemins ; ne pas coder en dur un backend.
4. **Prévisualisation locale (bytes).** Déférée (web-safety + `dart:io` hors whitelist). Défaut : icône (par mime/`documentType`) + nom pour local/document ; `Image.network` pour image uploadée. Extension future = seam `ZFilePreviewBuilder` (hors périmètre).
5. **Injection du storage : `ZcrudScope` vs `ZDependencyResolver`.** Deux voies conformes AD-6 : (a) champ nullable `ZcrudScope.cloudStorage` (symétrique de `filePicker`/`widgetRegistry` — simple, testable, défaut `null` = pas d'upload) ; (b) `ZDependencyResolver.tryResolve<CloudStorageRepository>()` (aligné sur la résolution des ports/repositories). Recommandé : **(a) `ZcrudScope`** pour la symétrie avec `filePicker` et la dégradation `null` explicite ; documenter le choix.
6. **`AppDocumentType`.** Parité DODLP : traiter comme **valeur ouverte** (String/`extra` + repli défensif), pas un enum fermé inter-package (AD-4/AD-10).

### Project Structure Notes

- Nouveaux fichiers : `domain/edition/app_file.dart` (+ `ZAppFileUploadState`), `domain/ports/cloud_storage_repository.dart`, `presentation/edition/z_file_picker.dart` (seam), `presentation/edition/families/z_app_file_field_widget.dart`. Modifs : `z_field_config.dart` (`FileFieldConfig`/`ZFileSource`), `edition_field_family.dart` (`EditionFamily.file`), `z_field_widget.dart` (case), `zcrud_scope.dart` (`filePicker`/`cloudStorage`), `z_localizations.dart` (clés), `zcrud_core.dart` (exports).
- **Pureté** : `domain/` (AppFile/FileFieldConfig/port) reste **pur-Dart** (`domain_purity_test` : 0 Flutter/Firebase, seul `package:dartz` autorisé). `presentation/` (widget/seam) : `flutter/material` + interne uniquement (`presentation_purity_test`). **Aucune** entrée `image_picker`/`file_picker`/`firebase*` dans `pubspec.yaml`.
- Graphe **acyclique**, `zcrud_core` out-degree **0** (aucune nouvelle dépendance de package).

### Testing

Framework : `flutter_test` (widgets) + `package:test` (gardes fichiers). Répertoire : `packages/zcrud_core/test/presentation/edition/` (widget), `test/domain/edition/` (modèle/config), `test/domain/ports/` (port + fake), `test/purity/` (gardes). Réutiliser/étendre `_reference_form.dart`/`_family_form.dart`.

Tests exigés :

- **Exhaustivité dispatch (AC1)** : mettre à jour `z_field_dispatch_test.dart` — `file`/`image`/`document` → `EditionFamily.file` + widget `ZAppFileField` (0 fallback) ; **`stepper` seul en `unsupported`** ; itération `EditionFieldType.values` (39) : aucun type non classé, aucune régression des autres familles.
- **`AppFile` (AC2/AC3)** : `app_file_test.dart` — round-trip `toMap`/`fromMap`, `copyWith`, `==`/`hashCode` ; **défensif AD-10** : map vide / champ corrompu / `uploadState` inconnu → défaut sûr, **aucun throw** ; **aucun champ bytes** (test structurel/documentaire).
- **`FileFieldConfig`/`ZFileSource` (AC4)** : `const`, `==`/`hashCode`, défauts si `null`.
- **Port `CloudStorageRepository` + fake (AC5/AC10)** : `fake_cloud_storage_repository.dart` — `upload → Right(uploaded+remoteUrl)`, échec → `Left(ServerFailure)`, `delete → Right(unit)` ; le fake ne tire **aucune** dépendance lourde.
- **Seam `ZFilePicker` + acquisition (AC6/AC7)** : `fake_file_picker.dart` renvoie un `AppFile` déterministe ; tap action → `AppFile` en tranche (`controller.value(field.name)`), voisins inchangés ; `filePicker == null` → actions désactivées, aucun crash.
- **Multiplicité (AC8)** : single (remplace, `AppFile?`) vs multiple (ajoute, `List<AppFile>`, borne `maxFiles`).
- **Prévisualisation + suppression (AC9)** : image uploadée → `Image` (network) ; document/local → icône+nom ; suppression → tranche mise à jour.
- **États d'upload (AC10)** : avec fake storage succès → `uploaded` ; `Left` → `failed` (accessible, retry) ; sans storage → reste `pending`. Aucun crash.
- **a11y (AC11)** : `field_a11y` étendu — formulaire avec champ fichier ; `meetsGuideline(androidTapTargetGuideline)` (≥ 48 dp), labels sémantiques des actions/suppression/état ; `SemanticsHandle` disposé.
- **RTL (AC12a)** : pump sous `Directionality(rtl)` — pas d'overflow, rangée directionnelle. **(AC12b)** `style_purity_test` vert sur les nouveaux fichiers.
- **AD-1 no-heavy-dep (AC13)** : garde/grep — `pubspec.yaml` sans `image_picker`/`file_picker`/`firebase*` ; `lib/` sans occurrence textuelle de ces imports ; `domain_purity`/`presentation_purity` verts ; `graph_proof` CORE OUT=0.
- **SM-1 (AC14)** : réutiliser/étendre `sm1_full_form` avec un champ fichier présent — 100 frappes texte → seul le champ texte reconstruit ; champ fichier + voisins inchangés ; structurel = 1.
- **l10n (AC15)** : clés en/fr présentes ; libellés résolus via le registre (pas de littéral en dur).

Non-régression : suite `zcrud_core` complète verte (E2-7/E2-9, E3-1..E3-6, E3-3a/E3-3b), gates melos/reflectable/secrets/codegen/compat/serialization, `graph_proof` CORE OUT=0, `melos list`=14, 0 `.g.dart` committé.

### References

- [Source: epics.md#E3 — Story E3-3c] (`AppFile`+`FileFieldConfig`+`ZAppFileField`, scan/caméra/galerie/picker, prévisualisation ; port `CloudStorageRepository` ; upload/download concret app/E5 ; types `file`/`image`/`document`, parité DODLP SM-2 ; a11y/RTL comme E3-3a ; comble le trou FR-2).
- [Source: architecture.md#AD-1] (cœur OUT=0, pas de dep lourde) ; [#AD-5] (domaine backend-agnostique, ports) ; [#AD-6] (injection par bindings) ; [#AD-11] (`Either`/`ZResult`/flux nus/`ZFailure`) ; [#AD-10] (désérialisation défensive) ; [#AD-2] (rebuilds granulaires) ; [#AD-13] (RTL/a11y/l10n, bind FR-23) ; [#AD-4] (extensibilité, valeur ouverte).
- [Source: docs/technical-inventory.md §2.8 / §3] (`AppFile`/`FileFieldConfig`/`AppFileEditionField`/`CloudStorageRepository` DODLP ; `file`/`image`/`document` → parité DODLP ; découplage du singleton/Firestore/cloudPath ; `zcrud_core` absorbe le champ fichier, couplage limité à l'interface `CloudStorageRepository`).
- [Source: story e3-3a-dispatcher-familles-base.md] (`EditionFamily`/`familyOf` 0 `default`, value-in-slice non-clavier, a11y/RTL par widget, `KeyedSubtree`) ; [story e3-3b-familles-avancees-sous-listes.md] (`ZWidgetRegistry` injecté, seam `ZcrudScope`).
- Fichiers : `edition_field_family.dart`, `z_field_widget.dart`, `z_field_config.dart`, `z_field_spec.dart`, `edition_field_type.dart`, `ports/z_repository.dart`, `failures/z_failure.dart`, `zcrud_scope.dart`, `z_widget_registry.dart`, `families/z_free_widget_field_widget.dart`, `l10n/z_localizations.dart`, `test/purity/{domain,presentation,style}_purity_test.dart`, `test/presentation/edition/z_field_dispatch_test.dart`.
- [Source: CLAUDE.md] Key Don'ts (jamais Firebase/dep lourde dans `zcrud_core` ; port neutre ; directionnel ; Semantics ≥ 48 dp ; no hardcoded style/couleur ; no state-manager in core).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (dev-story BMAD, effort high)

### Debug Log References

- `dart analyze` (zcrud_core lib+test) : `No issues found!`
- `flutter test` (zcrud_core) : **+427 All tests passed!** (initial) → **+429** après remédiation M1/L3 (2 tests ajoutés).
- `dart run melos run analyze` : SUCCESS (14 packages, RC=0)
- `dart run melos run verify` : RC=0 (graph_proof + gates)
- `python3 scripts/dev/graph_proof.py` : `out-degree(zcrud_core) = 0 (runtime)` → `ACYCLIQUE OK` / `CORE OUT=0 OK`
- `dart run melos run test` : SUCCESS (RC=0), `melos list` = 14

#### Remédiation code-review (passe post-review — statut reste `review`)

- **M1 (MEDIUM — corrigé)** : `maxFiles` ne tronque plus **silencieusement**. `z_app_file_field_widget.dart` — `_pick` positionne un état local `_maxFilesReached` quand `combined.length > max` ; les fichiers valides du début sont conservés (`sublist(0, max)`), l'excédent est écarté ET **non uploadé** (`next.contains(f)`), et un message `Semantics(liveRegion: true)` + clé l10n `fileMaxReached` (en/fr) est **annoncé** au lecteur d'écran (AD-13). Rebuild borné à ce champ (état UI local → SM-1/AD-2 intacts). Test ajouté : `AC8/M1 : dépassement maxFiles → borné + REFUS ACCESSIBLE (liveRegion)…` (borne=2, ordre `[a,b]` conservé, message présent, liveRegion active, pas de crash).
- **L3 (couverture — solidifié)** : test `L3 : 2 uploads concurrents + add pendant upload (complétion entrelacée)…` avec un fake `GatedCloudStorageRepository` (uploads maintenus EN VOL, `resolve(name)` complète dans un ordre arbitraire B→A→C). Prouve la chaîne read-modify-write : add-during-upload n'écrase aucun fichier en vol, complétion entrelacée → 3 fichiers, chacun atteint `uploaded`+`remoteUrl`, aucun perdu.
- **L1 (LOW — corrigé)** : commentaire trompeur sur `_ActionButton` réaligné sur la réalité (IconButton porte nativement le rôle `button` + tooltip = label sémantique ; aucun wrapper `Semantics` additionnel).
- **L2 (LOW — consigné, déféré)** : identité de repli `localPath ?? id ?? name` — collision seulement si un picker non conforme renvoie deux fichiers homonymes sans `localPath` NI `id` (contrat `ZFilePicker` garantit `localPath`). Risque résiduel négligeable ; renforcement (uuid/index) déféré, invariant « picker fournit toujours localPath » documenté.
- **L4 (LOW — consigné, intentionnel)** : `CloudStorageRepository.watchProgress` / `AppFile.progress` = **hook forward E5/E7** (progression fine). API volontairement exposée mais non câblée en E3-3c (spinner indéterminé pendant `uploading`, conforme AC10 où la progression est optionnelle). **Non retiré** — surface stable pour l'impl storage (E5).
- Re-vérif verte rejouée : `dart analyze lib test` = `No issues found!` ; `flutter test` (zcrud_core) = **+429 All tests passed!** ; `melos run analyze` RC=0 ; `melos run verify` RC=0 (CORE OUT=0 OK, gates melos/reflectable/secrets/codegen/compat OK) ; `melos list` = 14 ; `git ls-files '*.g.dart'` = 0 ; 0 dep lourde / 0 import `dart:io` dans `lib/`.

### Completion Notes List

- **AD-1 (cœur OUT=0) prouvé** : `zcrud_core/pubspec.yaml` inchangé (aucun `image_picker`/`file_picker`/`firebase*`) ; nouveau garde `test/purity/no_heavy_file_dep_test.dart` (grep pubspec + imports `lib/`) ; `graph_proof` CORE OUT=0. Picker + storage sont des **seams injectés** (`ZFilePicker` / `CloudStorageRepository`), impls hors cœur (E7 / E5).
- **Famille fichier** : `file`/`image`/`document` sortent d'`unsupported` → `EditionFamily.file` (widget `ZAppFileField`) ; `switch` de `familyOf` reste **exhaustif sans `default:`** ; `stepper` est désormais le **seul** type `unsupported` (asserté par test). Partition 39 recalculée.
- **AppFile** : value object pur-Dart **sans octets** ; `toMap`/`fromMap` défensifs (AD-10 : map vide / champs corrompus / `upload_state` inconnu → défauts sûrs, 0 throw) ; clés persistées snake_case, `upload_state` = nom d'enum camelCase.
- **value-in-slice (AD-2)** : `ZAppFileField` lit la tranche et écrit via `onChanged → setValue`, aucun `TextEditingController`. Un getter `liveValue` (fourni par le dispatcher = `controller.valueOf`) donne l'état **synchrone** le plus récent aux orchestrations d'upload asynchrones (évite l'écrasement de la tranche par une lecture périmée pendant une rafale de `setValue`). SM-1 préservé (test dédié : 100 frappes texte, champ fichier + voisins inchangés, structurel = 1, `find.byType(Form) findsNothing`).
- **États d'upload via port fake** : succès → `uploaded` + `remoteUrl` ; `Left(ServerFailure)` → `failed` (message accessible + retry) ; sans storage → reste `pending`. Preview `Image.network` (uploadée, `errorBuilder` web-safe → pas d'exception réseau en test) vs icône+nom (document/local).
- **a11y/RTL/l10n** : `IconButton` (≥ 48 dp) + tooltips l10n sur actions/suppression/retry ; état `failed`/`uploading` annoncé (`Semantics` liveRegion) ; insets `EdgeInsetsDirectional` exclusifs ; couleurs dérivées du thème (style_purity vert) ; clés en/fr ajoutées.
- **Ambiguïtés tranchées** : (1) `AppFile` en `domain/edition/` ; (2) multiplicité via `ZFieldSpec.multiple` + `maxFiles` ; (3) upload déclenché à l'acquisition si storage injecté, sinon `pending` ; (4) préviz locale déférée (icône+nom) ; (5) injection storage via `ZcrudScope.cloudStorage` ; (6) `documentType` = valeur ouverte.
- Hors périmètre (frontière respectée) : impl concrète picker (E7), impl Firebase Storage (E5), orchestration draft→cloud (E7).

### File List

**Créés — lib :**
- `packages/zcrud_core/lib/src/domain/edition/app_file.dart` (`AppFile` + `ZAppFileUploadState`)
- `packages/zcrud_core/lib/src/domain/ports/cloud_storage_repository.dart` (port neutre)
- `packages/zcrud_core/lib/src/presentation/edition/z_file_picker.dart` (seam `ZFilePicker`)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_app_file_field_widget.dart` (`ZAppFileField`)

**Modifiés — lib :**
- `packages/zcrud_core/lib/src/domain/edition/z_field_config.dart` (`FileFieldConfig` + `ZFileSource`)
- `packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart` (`EditionFamily.file` + routage)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (`case EditionFamily.file`)
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` (`filePicker` + `cloudStorage`)
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` (clés en/fr fichier)
- `packages/zcrud_core/lib/zcrud_core.dart` (barrel exports)

**Créés — test :**
- `packages/zcrud_core/test/domain/edition/app_file_test.dart`
- `packages/zcrud_core/test/domain/edition/file_field_config_test.dart`
- `packages/zcrud_core/test/domain/ports/cloud_storage_repository_test.dart`
- `packages/zcrud_core/test/presentation/edition/z_app_file_field_test.dart`
- `packages/zcrud_core/test/presentation/edition/file_field_a11y_rtl_test.dart`
- `packages/zcrud_core/test/presentation/edition/sm1_file_field_test.dart`
- `packages/zcrud_core/test/purity/no_heavy_file_dep_test.dart`
- `packages/zcrud_core/test/support/fake_cloud_storage_repository.dart`
- `packages/zcrud_core/test/support/fake_file_picker.dart`

**Modifiés — test :**
- `packages/zcrud_core/test/presentation/edition/z_field_dispatch_test.dart` (T9)
