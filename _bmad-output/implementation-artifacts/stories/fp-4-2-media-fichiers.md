---
baseline_commit: be9dc4402929f463f565ea336b88cabdf9adf995
---

# Story fp-4.2: Média & fichiers complets (`zcrud_media`)

Status: review

<!-- Épic E-FORM-PARITY (Formulaire : parité DODLP totale) · Epic 4 « Média-rich ».
     Satellite DISJOINT parallélisable (≤ 3 en vol avec fp-4-1/fp-4-3, fichiers disjoints).
     fp-4-2 ÉCRIT UNIQUEMENT sous packages/zcrud_media/. NE TOUCHE PAS zcrud_core, ni aucun
     autre satellite/vendor, ni le showcase/harnais, ni le binding zcrud_get. -->

## Story

As a **utilisateur DODLP** (et développeur consommateur du moteur),
I want **file** (bottom-sheet multi-sources + zone de dépôt + ouverture), **image** (galerie/caméra + recadrage), **document** et **vignette vidéo**, servis par le satellite `zcrud_media` derrière une **API neutre**,
so that je couvre **toute la famille média-rich** du moteur — sans jamais tirer une dépendance plateforme dans le cœur, ni casser SM-1, ni faire fuiter un type de plugin.

## Contexte & périmètre (LIRE AVANT DE CODER)

**Nature : ADAPTATEURS MÉDIA dans le satellite `zcrud_media`** (squelette déjà livré par fp-1-2). On remplit la coquille par : (1) un **`ZFilePicker` concret** (`ZMediaFilePicker`) qui câble `image_picker` / `file_picker` / `image_cropper` derrière le contrat cœur EXISTANT ; (2) des **`ZFieldWidgetBuilder`** enregistrés via `ZWidgetRegistry` (patron `zcrud_intl`) pour les affordances riches (zone de dépôt `dotted_border`, ouverture `open_file`, vignette vidéo `video_thumbnail`) ; (3) une garde de confinement **mise à jour** avec la nouvelle allowlist média. **Aucune écriture cœur, aucun binding, aucun showcase.**

**⚠️ CONTRAINTE D'ARCHITECTURE VÉRIFIÉE SUR DISQUE (décisive pour la conception) :**
Le dispatcher du cœur route **nativement** `file`/`image`/`document` vers `ZAppFileField` **AVANT** toute consultation du `ZWidgetRegistry` :
`packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart:602` (`case … → ZAppFileField(...)`) ; le repli registre (`registry?.tryBuilderFor(field.type.name)`, ligne 699-700) n'est atteint que pour les `kind` **NON** nativement gérés. **Conséquence directe** : `zcrud_media` **ne peut pas** « override » `image`/`file`/`document` via `ZWidgetRegistry` — ces types ne l'atteignent jamais. Donc :
- La **parité d'acquisition** (caméra/galerie/picker/recadrage) des types natifs passe **exclusivement** par le seam `ZFilePicker` (`ZcrudScope.filePicker`), que `ZAppFileField` consomme déjà. → **AUCUNE modification cœur** (disjonction respectée par conception).
- Les **affordances riches** (zone de dépôt, ouverture au tap, vignette vidéo) sont servies via `ZWidgetRegistry` sous des **`kind` custom** (`mediaImage` / `mediaFile` / `mediaVideo`) qu'une app/binding enregistre explicitement — voir **ET-2**. Étendre les types natifs eux-mêmes exigerait une écriture cœur : **HORS périmètre → signalé, non fait**.

**Disjonction (parallélisation Epic 4, fichiers disjoints) — NON-NÉGOCIABLE :**
- fp-4-2 crée/édite **UNIQUEMENT** sous `packages/zcrud_media/` (+ éventuellement `pubspec.lock` racine, **non committé**, résultat de `pub get`).
- **NE TOUCHE PAS** `packages/zcrud_core/`, ni `zcrud_select` (fp-4-1), ni `zcrud_html` (fp-4-3), ni `awesome_select`, ni `zcrud_get`, ni le showcase/harnais.
- Le **seul** point de contact théorique serait `zcrud_core` — **exclu ici** : on consomme ses seams EXISTANTS (`ZFilePicker`, `ZFileSource`, `AppFile`, `FileFieldConfig`, `ZWidgetRegistry`, `ZFieldWidgetBuilder`, `ZFieldWidgetContext`, `ZcrudTheme`), on n'en écrit aucun.
- Si un besoin d'abstraction cœur manquante apparaît → **STOP + SIGNALER** (re-séquencer derrière une story CORE-SÉRIALISÉE), ne pas écrire dans le cœur en parallèle.

**Contrainte de dépôt :** SEUL `/home/zakarius/DEV/zcrud` est modifiable. Repos d'app (`dodlp-otr`, etc.) = **LECTURE SEULE** (référence).

**Frontières (HORS fp-4-2) :** PAS le câblage binding `zcrud_get` (compose/injecte — étape binding/showcase ultérieure) · PAS le showcase/harnais axe 3 (consomme les points d'entrée exposés ici) · PAS `ZColorConfig.multiple` (fp-4-4, cœur) · PAS le scan `cunning_document_scanner` en dur (hors allowlist — voir **ET-1**) · PAS l'avatar profil `pickCropAndSetImage` (widget d'app DODLP, hors moteur — cf. [08-field-media-image.md §2]).

## Acceptance Criteria

Chaque AC = **fichier réel sur disque** + **test porteur** + **injection R3 qui rougit par comportement** (un fake qui change de conduite fait échouer le test ; une garde qui « voit » un intrus). Toute « absence » = **grep négatif** (commande + RC=1) ou assertion de test — jamais une affirmation nue. Aucune vérif non rejouée réellement ne peut être affirmée.

**AC1 — `ZMediaFilePicker` : `ZFilePicker` concret, API neutre, CORE OUT=0.** *(FR-15 · AD-51/AD-1/AD-40/AD-6)*
**Given** `zcrud_media` fournissant `ZMediaFilePicker implements ZFilePicker` (contrat cœur EXISTANT, non modifié)
**When** `pick({required ZFileSource source, required FileFieldConfig config})` est appelé pour `gallery` / `camera` / `filePicker`
**Then** l'acquisition est déléguée aux plugins via des **seams injectables** (`gallery`/`camera` → `image_picker` ; `filePicker` → `file_picker` contraint par `config.effectiveExtensions`) ; le résultat est une `List<AppFile>` en `ZAppFileUploadState.pending` **avec `localPath`/`name`/`mimeType` — jamais d'octets** (respect du contrat cœur : le transport binaire n'est pas la responsabilité du picker) ; **aucun** type plateforme (`XFile`/`PlatformFile`/`File`/`CroppedFile`) n'apparaît en **signature publique** ni dans une valeur de tranche (AD-40) ; le barrel `lib/zcrud_media.dart` n'exporte **aucun** symbole de plugin ; **CORE OUT=0** inchangé (`zcrud_media → zcrud_core` seule arête `zcrud_*`). *Test porteur : fake `image_picker`/`file_picker` déterministe → assertion sur les `AppFile` neutres retournés (mode single vs multiple via `config`/`multiple`).* 

**AC2 — Recadrage `image_cropper` post-pick, optionnel, résultat neutre.** *(FR-16 · AD-51/AD-40/AD-10)*
**Given** `ZMediaFilePicker` configuré avec une option de recadrage (`ZMediaCropOptions`, seam interne — jamais un type `image_cropper` public)
**When** une image est sélectionnée via `gallery`/`camera` avec recadrage activé
**Then** `image_cropper` recadre l'image **après** le pick, le résultat est ré-emballé en `AppFile` neutre (`localPath` du fichier recadré) ; si le recadrage est **annulé** l'image d'origine est **conservée** (résultat défini, AD-10) et **jamais** de throw traversant ; si le recadrage est **désactivé** (défaut) le flux d'AC1 est **strictement inchangé** (rétro-compat, aucune régression) ; aucun `CroppedFile` ne fuit. *Test porteur : fake cropper « recadre » → `localPath` change ; fake cropper « annule » (retourne null) → `localPath` d'origine conservé, aucune exception.*

**AC3 — Caméra & multi-sélection : parité + permission/annulation gérées (AD-10).** *(FR-16/FR-17 · AD-51/AD-10/AD-13)*
**Given** `ZMediaFilePicker` et une `config` (`multiple`/`maxFiles`)
**When** l'utilisateur capture (`camera`) ou charge en lot (`gallery`, `limit>1`)
**Then** `camera` → `image_picker.pickImage(source: camera)` (parité DODLP : délégation à l'appareil photo OS, jamais le paquet `camera` en chemin par défaut — cf. **ET-5**) ; `gallery` multi → `pickMultiImage(limit:)` borné par `maxFiles` ; une **permission refusée** ou une **annulation** produit une **liste vide définie** (AD-10), **jamais** un throw traversant ni un crash ; **aucune permission plateforme n'est codée en dur** dans le package (déclarations OS = responsabilité de l'app hôte, documenté). *Test porteur : fake qui lève `PlatformException(code: denied)` → la façade retourne `<AppFile>[]` et le test vérifie l'absence de propagation.*

**AC4 — Affordances riches via `ZWidgetRegistry` : zone de dépôt + ouverture + vignette vidéo.** *(FR-15/FR-18 · AD-51/AD-2/AD-13/FR-26/AD-40)*
**Given** `registerZMediaFieldWidgets(ZWidgetRegistry registry, {ZMediaFilePicker? picker, …})` (patron `registerZAddressFieldWidgets` de `zcrud_intl`)
**When** il enregistre les builders sous des `kind` **custom** (`mediaImage`/`mediaFile`/`mediaVideo` — voir **ET-2**) et qu'un champ est monté via `ZFieldWidget`
**Then** (a) une **zone de dépôt** `dotted_border` est rendue et déclenche l'acquisition ; (b) un fichier acquis s'**ouvre** au tap via `open_file` (résultat défini si l'ouverture échoue, AD-10) ; (c) une **vignette vidéo** est générée via `video_thumbnail` en **type neutre** (`Uint8List`/chemin — aucun type plateforme en signature) ; le builder ne lit que `ctx.value` et n'écrit que via `ctx.onChanged` **dans** la frontière de rebuild (AD-2, value-in-slice, zéro souscription élargie — SM-1) ; cibles ≥ 48 dp + `Semantics` explicites **sans double-annonce** ; **aucune** couleur/style codé en dur (thème via `ZcrudTheme.of(context)`/`ThemeExtension`, repli `Theme.of` — FR-26) ; variantes **directionnelles** (RTL, AD-13). *Test porteur : widget test montant le builder via `ZWidgetRegistry` réel → présence de la drop-zone, `onChanged` appelé au drop, compteur de build ciblé (voisin qui se reconstruit n'entraîne pas de rebuild élargi).*

**AC5 — Confinement FALSIFIABLE mis à jour (isolation média) & zéro secret.** *(AD-1/AD-40/AD-12)*
**Given** la garde `test/z_media_confinement_test.dart` livrée en squelette (fp-1-2) avec allowlist `{flutter, zcrud_core}`
**When** on l'étend pour la surface média
**Then** l'**allowlist de dépendances** devient **EXACTEMENT** `{flutter, zcrud_core, image_picker, image_cropper, camera, video_thumbnail, file_picker, open_file, dotted_border}` (dérivée, pas énumérée en dur dans plusieurs endroits divergents) et le bloc `dependencies:` de `packages/zcrud_media/pubspec.yaml` en est un **sous-ensemble exact** ; l'**allowlist d'imports** `lib/**` = allowlist deps ∪ `{zcrud_media, dart-core}` ; la **contre-preuve R12** reste vraie : un intrus témoin **hors** allowlist (ex. `cunning_document_scanner` / `path_provider`) **DOIT** faire rougir la règle, et un import légitime (`zcrud_core`, `image_picker`) **NE DOIT PAS** ; le **barrel** n'exporte aucun type de plugin (grep négatif) ; `graph_proof` → **ACYCLIC OK** + **CORE OUT=0 OK** ; `gate:secrets` OK (aucune clé/endpoint, aucune permission plateforme en dur). *Anti-vacuité : le scan `lib/**` voit ≥ 1 fichier `.dart` (un refactor hors glob rendrait la garde inopérante).*

**AC6 — Points d'entrée prêts-à-câbler + preuve EN PAQUET (pas de binding ici).** *(AR-4 · ET-3)*
**Given** que le câblage `zcrud_get` + le showcase axe 3 sont **hors** disjonction (touchent d'autres packages)
**When** fp-4-2 expose les points d'entrée d'intégration
**Then** `zcrud_media` publie via son barrel : `ZMediaFilePicker` (à injecter dans `ZcrudScope.filePicker`) et `registerZMediaFieldWidgets(...)` (à appeler au **bootstrap** du binding, **jamais** un side-effect d'import) ; la **preuve** que file/image/document/vidéo fonctionnent est apportée **DANS le paquet** par des tests widget/unit avec **données fictives** (fakes injectés), sans importer `zcrud_get` ni le showcase ; un commentaire de barrel documente la séquence de câblage attendue côté binding (« enrôlement explicite au bootstrap »). *Écart consigné ET-3 : l'AC epic « Given le binding zcrud_get » est satisfaite ici par des **points d'entrée testés en isolation** ; le câblage réel `zcrud_get` + la bascule showcase « ABSENT → livré » relèvent de l'étape binding/showcase (single-writer `zcrud_get`).* 

## Tasks / Subtasks

- [x] **T1 — `pubspec.yaml` : ajouter les deps média confinées** (AC1/AC5)
  - [x] Ajouter au bloc `dependencies:` (EN PLUS de `zcrud_core`/`flutter`) : `image_picker`, `image_cropper`, `camera`, `video_thumbnail`, `file_picker`, `open_file`, `dotted_border` (contraintes `^` — versions à **confirmer au `dart pub get`** offline/online et à aligner sur la toolchain ; repères DODLP : `image_picker ^1.2.0`, `file_picker ^10.3.3`, `image_cropper ^11.x`, `camera ^0.11.x` — cf. [FIELD-PACKAGE-MATRIX.md]).
  - [x] **Aucune** arête `zcrud_*` sortante autre que `zcrud_core`. **Aucun** secret. Mettre à jour l'en-tête de commentaire du pubspec (les deps média arrivent MAINTENANT, confinées à l'impl).
- [x] **T2 — `ZMediaFilePicker implements ZFilePicker`** (AC1/AC2/AC3)
  - [x] `lib/src/data/z_media_file_picker.dart` : implémente `pick({source, config})` via **seams injectables** (typedefs/instances de plugin passés au constructeur, défauts = vrais plugins) pour rendre les 3 chemins (`gallery`/`camera`/`filePicker`) **testables sans plateforme**.
  - [x] Convertit tout résultat plugin → `AppFile` neutre (`localPath`/`name`/`mimeType`, `pending`) ; **aucun** type plugin en signature publique (AD-40) ; `scan` → voir **ET-1** (seam optionnel, défaut non-supporté = liste vide définie).
  - [x] Recadrage `image_cropper` **post-pick** derrière `ZMediaCropOptions` (seam interne) : activé → recadre ; annulé → original conservé ; désactivé (défaut) → flux inchangé (AC2).
  - [x] **AD-10 partout** : annulation / permission refusée / plugin qui throw → `<AppFile>[]` (ou original pour le crop), **jamais** de throw traversant.
- [x] **T3 — Adaptateurs widget `ZFieldWidgetBuilder` + `registerZMediaFieldWidgets`** (AC4/AC6)
  - [x] `lib/src/presentation/z_media_field_widget.dart` : builders riches (drop-zone `dotted_border`, ouverture `open_file`, vignette `video_thumbnail` en type neutre) ; `static ZFieldWidgetBuilder builder({...})` + fonction top-level `registerZMediaFieldWidgets(registry, {...})` (patron `zcrud_intl`) enregistrant les `kind` custom `mediaImage`/`mediaFile`/`mediaVideo` (constantes `const String …Kind`).
  - [x] Rebuild **value-in-slice** (AD-2) : lit `ctx.value`, écrit `ctx.onChanged` ; hooks `@visibleForTesting onInit`/`onBuild` pour le compteur SM-1.
  - [x] A11y (≥48 dp, `Semantics` sans double-annonce), thème injecté (FR-26), directionnel (AD-13).
- [x] **T4 — Barrel + surface publique** (AC1/AC6) — `lib/zcrud_media.dart` : exporter `ZMediaFilePicker`, `ZMediaCropOptions`, `registerZMediaFieldWidgets` + constantes `kind`, la vignette (API neutre). **Retirer** le `kZcrudMediaPlaceholder` (remplacé) ou le laisser en marqueur interne non exporté. Documenter la séquence de câblage binding en dartdoc.
- [x] **T5 — Garde de confinement étendue** (AC5) — mettre à jour `test/z_media_confinement_test.dart` : `_allowedDeps` = 9 entrées ci-dessus ; `_allowedImportPkgs` = deps ∪ `{zcrud_media}` ; changer `_probeIntruder` pour un intrus **désormais réellement hors périmètre** (`cunning_document_scanner` ou `path_provider`) ; conserver les 2 volets + R12 mutantes + anti-vacuité.
- [x] **T6 — Tests porteurs** (AC1-AC4)
  - [x] `test/z_media_file_picker_test.dart` : les 3 sources (fakes) → `AppFile` neutres ; crop activé/annulé/désactivé ; permission refusée → `[]` (AD-10).
  - [x] `test/z_media_field_widget_test.dart` : montage via `ZWidgetRegistry` réel ; drop-zone présente ; `onChanged` au drop ; vignette neutre ; **compteur de rebuild ciblé** (SM-1) ; a11y (finder `Semantics`, cibles ≥48 dp).
- [x] **T7 — Vérif verte + disjonction** (tous AC)
  - [x] `dart pub get` (offline puis online si besoin) résout `zcrud_media` sans conflit.
  - [x] `python3 scripts/dev/graph_proof.py` → **ACYCLIC OK** + **CORE OUT=0 OK**.
  - [x] `dart analyze packages/zcrud_media` (ou repo-wide) RC=0.
  - [x] `flutter test` **ciblé `packages/zcrud_media`** RC=0 (jamais `melos run test` global au milieu d'un dev parallèle).
  - [x] `gate:secrets` OK ; barrel n'exporte aucun type plugin (grep négatif RC=1).
  - [x] `git diff --stat -- packages/zcrud_core packages/zcrud_select packages/zcrud_html packages/awesome_select packages/zcrud_get` → **VIDE** (preuve disjonction).

## Dev Notes

### Patron de référence (à IMITER sur disque, ne pas réinventer)
- **Auto-enregistrement via `ZWidgetRegistry` : `packages/zcrud_intl/lib/src/presentation/z_address_field_widget.dart`** — fonction top-level `registerZAddressFieldWidgets(registry, {...})` qui appelle `registry.register(kind, builder)` ; `static ZFieldWidgetBuilder builder({...})` capturant les collaborateurs par **closure** (AD-4) ; chaque montage crée SES contrôleurs (par-montage). C'est **exactement** le patron de T3.
- **Champ value-in-slice a11y/RTL/thème** : `packages/zcrud_core/lib/src/presentation/edition/families/z_app_file_field_widget.dart` (`ZAppFileField`) — modèle de granularité (`_replace` cible un seul `AppFile` via `_identity`), `Semantics(liveRegion:)`, `EdgeInsetsDirectional`, thème `ZcrudTheme.of`. À égaler côté widgets riches (ne PAS régresser sous DODLP qui, lui, viole AD-13/FR-26 — cf. [08-field-media-image.md §1.4]).
- **Garde de confinement falsifiable** : `packages/zcrud_media/test/z_media_confinement_test.dart` (déjà en place, fp-1-2) — dé-commentateur **YAML** ancré, allowlist dérivée, R12 mutantes. Base de T5.
- **Contrat cœur consommé (NE PAS réécrire)** : `z_file_picker.dart` (`ZFilePicker.pick`), `z_field_config.dart` (`ZFileSource` {scan,camera,gallery,filePicker}, `FileFieldConfig.effectiveExtensions`/`allowedSources`/`maxFiles`/`imageFallback`), `app_file.dart` (`AppFile` : `localPath`/`name`/`mimeType`/`uploadState`/`extra`/`copyWith`), `z_widget_registry.dart` (`ZWidgetRegistry`, `ZFieldWidgetBuilder`, `ZFieldWidgetContext{field,value,onChanged}`).

### Réalité du dispatch cœur (preuve — décisive)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart:602` : `case EditionFieldType.file/image/document → ZAppFileField(...)` **avant** le registre. Ligne 699-700 : `registry?.tryBuilderFor(field.type.name)` = **repli** pour les `kind` non natifs. → **prouvé** : `image`/`file`/`document` n'atteignent PAS le registre. Les widgets riches DOIVENT donc s'enregistrer sous des `kind` **custom** (ET-2), ou exiger une écriture cœur (hors scope). **NE PAS** tenter d'enregistrer un builder sous `'image'`/`'file'`/`'document'` en croyant override le natif : le test le prouverait mort (le builder ne serait jamais appelé). 

### Écarts tranchés (mode non-interactif → option CONSERVATRICE, consignée)
- **ET-1 — `scan`→PDF NON câblé en dur (`cunning_document_scanner` HORS allowlist).** Le brief de tâche fixe l'allowlist à 7 deps média **sans** `cunning_document_scanner` (paquet mono-mainteneur, natif plateforme, risque élevé — cf. [08-field-media-image.md §1.5]). Décision : `ZFileSource.scan` reste un **seam optionnel injectable** (`ZDocumentScanner?`, défaut `null` ⇒ `pick(source: scan)` retourne `<AppFile>[]` **défini**, AD-10, jamais throw). L'impl `cunning_document_scanner` + service PDF est **différée** à une story binding/média ultérieure qui l'ajouterait à SON allowlist. Signalé : l'AC epic « `ZFileSource.scan` produit un PDF » n'est **pas** couverte en dur ici — le contrat/seam l'est, l'impl concrète non.
- **ET-2 — Widgets riches sous `kind` CUSTOM (`mediaImage`/`mediaFile`/`mediaVideo`), pas d'override des types natifs.** Le cœur route `image`/`file`/`document` vers `ZAppFileField` avant le registre (preuve ci-dessus). Sans toucher le cœur (disjonction), les affordances riches (drop-zone/open/vignette) sont servies sous des `kind` custom qu'une app enregistre volontairement. Signalé : la **parité riche SUR les types natifs eux-mêmes** exigerait une écriture cœur (routage `image`/`file`/`document` vers le registre, ou un hook d'enrichissement de `ZAppFileField`) → **à re-séquencer en CORE-SÉRIALISÉE** si le owner l'exige. Non fait ici.
- **ET-3 — Câblage `zcrud_get` + showcase axe 3 différés (disjonction).** Toucher `zcrud_get`/showcase violerait « fp-4-2 écrit UNIQUEMENT `zcrud_media` ». La story expose les **points d'entrée** (`ZMediaFilePicker`, `registerZMediaFieldWidgets`) et les prouve **en paquet** (fakes) ; l'injection réelle dans `ZcrudScope.filePicker` + la bascule showcase « ABSENT → livré » sont l'étape binding/showcase (single-writer).
- **ET-4 — Capacité au-delà de l'usage DODLP minimal, par mandat de l'epic.** Les études prouvent que `image_cropper`/`camera`/`video_thumbnail`/`open_file`/`dotted_border` **ne sont PAS** utilisés par le champ CRUD DODLP (`AppFileEditionField`) : crop = avatar profil hors moteur ([08 §2]), `camera` = mort ([08 §1.5]), `open_file`/`dotted_border` = module `file_manager` séparé ([09 §1.2]). L'Epic 4 « parité **totale** média-rich » mande néanmoins la **capacité** de toute la famille. Décision : livrer les capacités **sanctionnées par le brief/epic** (allowlist 7 deps), sans régresser les invariants — ce n'est pas un clone 1:1 du widget minimal DODLP mais une parité de **capacité**. Documenté pour éviter qu'un reviewer lise « DODLP ne le fait pas » comme un défaut.
- **ET-5 — Caméra : chemin par défaut = `image_picker.pickImage(source: camera)` (parité, délégation OS).** Le paquet `camera` (live-preview) est **mort** dans DODLP. Il reste dans l'allowlist (sanctionné par le brief) pour une capture in-app **optionnelle** derrière un seam ; le chemin de parité par défaut n'en dépend pas. Scoper `camera` au minimum ; ne pas sur-investir une capture live sans mandat.

### Invariants applicables (rappel, NON-NÉGOCIABLES)
- **AD-1** : graphe acyclique ; **CORE OUT=0** ; `zcrud_media` ne dépend que de `zcrud_core` + ses deps média tierces (ajoutées à SON pubspec, **jamais** au cœur). `zcrud_core` **inchangé**.
- **AD-40** : aucun type de plugin (`XFile`/`PlatformFile`/`CroppedFile`/`File`/`camera`) en signature publique ni en valeur de tranche. Valeurs neutres : `AppFile`/chemins/`Uint8List`.
- **AD-2 / SM-1** : builders value-in-slice, aucun `TextEditingController` recréé, aucune souscription élargie ; taper/agir ne reconstruit que le champ courant.
- **AD-10** : annulation picker / permission refusée / fichier corrompu / ouverture échouée → **résultat défini**, jamais un throw traversant.
- **AD-13 / FR-26** : cibles ≥ 48 dp, `Semantics` (sans double-annonce), variantes directionnelles, thème injecté (aucune couleur/style en dur, aucune permission plateforme en dur).
- **AD-12** : zéro secret/clé/endpoint dans le package.

### Pièges de vérification (discipline de réalité)
- `grep | head` **masque le RC** → `grep -q` (RC explicite) pour toute preuve d'absence (barrel n'exporte pas de type plugin, `cunning_document_scanner` absent, etc.).
- `melos run test` **peut se bloquer** (Flutter) et casser un dev parallèle → `flutter test` **ciblé `packages/zcrud_media`**.
- Plugins plateforme (`image_picker`/`file_picker`/`image_cropper`/`camera`/`video_thumbnail`/`open_file`) **non testables sans device** → **seams injectables obligatoires** (constructeur reçoit des fakes) ; un test qui appelle le vrai plugin est un test tautologique (ne rougit jamais) — **interdit** (discipline R3).
- **Présence ≠ association** : prouver qu'un builder est *enregistré* ne prouve pas qu'il est *appelé* ; le widget test doit **monter** le champ via le dispatcher/registre et vérifier le rendu réel.
- `git checkout`/`git restore` **interdits** (destructif).

### Project Structure Notes
- Arbre cible : `lib/src/data/z_media_file_picker.dart` (adaptateur `ZFilePicker`), `lib/src/domain/` (options neutres : `ZMediaCropOptions`, seams `ZDocumentScanner?`), `lib/src/presentation/z_media_field_widget.dart` (builders + `registerZMediaFieldWidgets`), barrel `lib/zcrud_media.dart`. Placeholder fp-1-2 (`z_media_field_placeholder.dart`) → remplacé/retiré de l'export.
- Conflit potentiel : `resolution: workspace` + toolchain récente vs versions plugin — si `pub get`/`analyze` rougit sur un plugin, **assouplir uniquement** via l'`analysis_options.yaml` du satellite (documenté), jamais globalement ; ne pas figer une version incompatible.

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Story-4.2] (ACs, Binds FR-15/16/17/18, AD-51, NFR-2/9, contribue FR-39 axe 3/FR-40, AR-4 ; parallélisation Epic 4)
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md#AD-51] (adaptateurs média satellite `zcrud_media`, contrat cœur `ZFilePicker`, confinement) · [#AD-1] (acyclique, CORE OUT=0) · [#AD-40] (pas de type tiers en signature) · [#AD-2] (rebuild granulaire) · [#AD-10] (repli défini) · [#AD-13]/[#FR-26] (a11y/RTL/thème) · [#AD-12] (secrets)
- [Source: docs/dodlp-form-integration-study-2026-07-17/08-field-media-image.md] (§1 dispatch `file`/`image`/`document`, §1.2 API `image_picker`/`file_picker`, §1.5 stratégie/risques, §2 avatar hors-scope)
- [Source: docs/dodlp-form-integration-study-2026-07-17/09-field-file-document.md] (§1.2 preuve que `open_file`/`dotted_border`/`file_manager` ne sont PAS dans le champ CRUD ; correction du brief)
- [Source: docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md] (rows 17 `file`, 18 `image`, 19 `document` ; versions plugins ; L113-114 adaptateur `ZFilePicker` dans `zcrud_get`/`zcrud_media`)
- [Pattern: packages/zcrud_intl/lib/src/presentation/z_address_field_widget.dart] (`registerZAddressFieldWidgets` + `.builder` closure — patron T3)
- [Contrat cœur consommé: packages/zcrud_core/lib/src/presentation/edition/z_file_picker.dart · .../z_field_config.dart (ZFileSource/FileFieldConfig) · .../edition/app_file.dart (AppFile) · .../edition/z_widget_registry.dart (ZWidgetRegistry/ZFieldWidgetBuilder/ZFieldWidgetContext)]
- [Preuve dispatch: packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart:602,699-700 (natif avant registre)]
- [Squelette de départ: packages/zcrud_media/{pubspec.yaml, lib/zcrud_media.dart, lib/src/presentation/z_media_field_placeholder.dart, test/z_media_confinement_test.dart}]
- [Référence DODLP (LECTURE SEULE): /home/zakarius/DEV/dodlp-otr/lib/modules/data_crud/presentation/widgets/app_file_edition_field.dart]

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — `bmad-dev-story` (skill réel invoqué).

### Debug Log References

Vérif verte rejouée réellement sur disque (RC réels) :
- `dart pub get` → RC=0 (résolution : image_picker 1.2.3, file_picker 10.3.10, image_cropper 11.0.0, video_thumbnail 0.5.6, open_file 3.5.11, dotted_border 2.1.0, camera 0.11.4).
- `dart analyze packages/zcrud_media` → **No issues found! RC=0**.
- `flutter test packages/zcrud_media` → **All tests passed, RC=0** (24 tests : confinement 4 + file_picker 13 + field_widget 7).
- `python3 scripts/dev/graph_proof.py` → **ACYCLIC OK** + **CORE OUT=0 OK**, RC=0 (`zcrud_media -> zcrud_core` seule arête).
- `dart run scripts/ci/gate_secret_scan.dart` → **RC=0** (aucun secret, AD-12).
- Grep négatifs (RC=1) : barrel n'exporte aucun symbole/type plugin ; plugins importés **uniquement** sous `lib/src/data/z_media_plugin_seams.dart` ; aucune permission plateforme codée en dur ; aucun package interdit ne référence `zcrud_media`.
- Disjonction : tous les fichiers authored sont sous `packages/zcrud_media/` ; `zcrud_core` (18 fichiers) était déjà dirty au baseline (workstreams parallèles), **non** touché par fp-4-2 (grep négatif confirmé).

### Completion Notes List

- **AC1** ✅ `ZMediaFilePicker implements ZFilePicker` (`lib/src/data/z_media_file_picker.dart`) : routage `gallery`/`camera`/`filePicker`/`scan` via seams injectables ; retourne des `List<AppFile>` neutres (`localPath`/`name`/`mimeType`, `pending`, jamais d'octets) ; aucun type plateforme en signature (AD-40) ; CORE OUT=0.
- **AC2** ✅ Recadrage `image_cropper` post-pick derrière `ZMediaCropOptions` (neutre) : activé → `localPath` recadré ; annulé (`crop → null`) → original conservé ; désactivé (défaut) → seam jamais appelé (rétro-compat). AD-10, aucun `CroppedFile` public.
- **AC3** ✅ Caméra = `image_picker.pickImage(source: camera)` (ET-5, mono) ; galerie multi = `pickMultiImage(limit: maxFiles)` ; permission refusée (`PlatformException(denied)` du fake) / annulation → `<AppFile>[]` défini, aucune propagation ; zéro permission plateforme codée en dur.
- **AC4** ✅ `registerZMediaFieldWidgets` (patron `zcrud_intl`) enrôle 3 `kind` custom (`mediaImage`/`mediaFile`/`mediaVideo`) ; drop-zone `dotted_border`, ouverture `open_file`, vignette vidéo `video_thumbnail` en `Uint8List` neutre ; value-in-slice (SM-1 : voisin qui change ne reconstruit pas le champ) ; ≥48 dp + `Semantics` ; thème `ZcrudTheme.of` (FR-26), directionnel (AD-13) ; AD-10 (ouverture/vignette/picker absent → défini).
- **AC5** ✅ Garde `test/z_media_confinement_test.dart` : allowlist EXACTE 9 deps (dérivée de `_mediaDeps`), imports `lib/**` ⊆ deps ∪ `{zcrud_media}`, contre-preuves R12 mutantes + anti-vacuité ; intrus témoin = `cunning_document_scanner` (réellement hors périmètre, ET-1) ; barrel sans type plugin ; graph_proof + gate:secrets verts.
- **AC6** ✅ Barrel publie `ZMediaFilePicker` + `registerZMediaFieldWidgets` + `kind` + seams neutres + `ZMediaCropOptions` ; dartdoc documente la séquence de câblage binding (enrôlement EXPLICITE au bootstrap, jamais un side-effect d'import) ; preuve EN PAQUET par fakes, sans importer `zcrud_get`/showcase.

**Écarts consignés (mode non-interactif, option conservatrice)** :
- **ET-1** — `ZFileSource.scan` reste un seam optionnel (`ZDocumentScanSeam?`, défaut `null` ⇒ `[]` défini). `cunning_document_scanner`/service PDF **différés** (hors allowlist). L'AC epic « scan produit un PDF » n'est PAS couverte en dur (contrat/seam l'est).
- **ET-2** — Widgets riches sous `kind` custom uniquement (le cœur route `image`/`file`/`document` vers `ZAppFileField` **avant** le registre — preuve `z_field_widget.dart:602`). La **parité riche sur les types natifs eux-mêmes** exigerait une écriture cœur → **à re-séquencer CORE-SÉRIALISÉE**, non fait ici (disjonction).
- **ET-3** — Câblage réel `zcrud_get` + bascule showcase axe 3 « ABSENT → livré » différés (single-writer `zcrud_get`).
- **ET-5** — `camera` (paquet live-preview) sanctionné dans l'allowlist mais **non câblé** au chemin par défaut (réservé à une capture in-app optionnelle) ; caméra par défaut = délégation OS via `image_picker`.

### File List

Tous sous `packages/zcrud_media/` :
- `pubspec.yaml` — MODIFIÉ (ajout des 7 deps média confinées + en-tête).
- `lib/zcrud_media.dart` — MODIFIÉ (barrel : exports réels neutres, dartdoc câblage ; placeholder retiré).
- `lib/src/domain/z_media_crop_options.dart` — CRÉÉ (`ZMediaCropOptions` neutre).
- `lib/src/domain/z_media_seams.dart` — CRÉÉ (6 seams neutres injectables).
- `lib/src/data/z_media_plugin_seams.dart` — CRÉÉ (impls par défaut adossées aux plugins, confinées, AD-10).
- `lib/src/data/z_media_file_picker.dart` — CRÉÉ (`ZMediaFilePicker implements ZFilePicker`).
- `lib/src/presentation/z_media_field_widget.dart` — CRÉÉ (builders riches + `registerZMediaFieldWidgets` + `kind`).
- `lib/src/presentation/z_media_field_placeholder.dart` — SUPPRIMÉ (remplacé).
- `test/z_media_confinement_test.dart` — MODIFIÉ (allowlist 9 deps + intrus témoin hors-scope).
- `test/z_media_file_picker_test.dart` — CRÉÉ (13 tests AC1/AC2/AC3, fakes R3).
- `test/z_media_field_widget_test.dart` — CRÉÉ (7 tests AC4/AC6, registre réel + SM-1).

### Code-review correctif (fp-4-2) — transversal cœur + satellite

Rapport complet : `code-review-fp-4-2.md`. Findings traités : **MAJEUR-1** (kinds média
inatteignables par le dispatcher cœur — résolus par l'ajout des types
`mediaImage`/`mediaFile`/`mediaVideo` à `EditionFieldType`, routés vers
`registryOrFallback`, `kind` alignés sur `.name` ; **lève l'écart ET-2** :
la voie riche est désormais atteignable via le VRAI dispatcher, sans override du
natif), **MED-2** (vignette vidéo mémoïsée par `localPath`, SM-1/AD-2), **MED-3**
(`camera` retiré — jamais importé, ET-5 ; **lève l'écart ET-5**), **MED-4** (README
réécrit). **LOW** consigné (acquisition vidéo directe = suivi).

Vérif verte rejouée : `dart analyze` cœur+média RC=0 ; `flutter test packages/zcrud_core`
= +996 OK ; `flutter test packages/zcrud_media` = +31 OK (24 → 31, +7 tests porteurs) ;
`graph_proof.py` ACYCLIQUE + CORE OUT=0 ; codegen non touché (enum non persisté).

Fichiers modifiés (correctif) :
- Cœur : `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`,
  `packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart`,
  `packages/zcrud_core/test/domain/edition/edition_field_type_test.dart`,
  `packages/zcrud_core/test/presentation/edition/z_field_dispatch_test.dart`.
- Satellite : `packages/zcrud_media/lib/src/presentation/z_media_field_widget.dart`,
  `packages/zcrud_media/pubspec.yaml`,
  `packages/zcrud_media/test/z_media_confinement_test.dart`,
  `packages/zcrud_media/test/z_media_field_widget_test.dart`,
  `packages/zcrud_media/README.md`.

> Note : l'allowlist de confinement passe de **9 à 8 entrées** (6 deps média,
> `camera` retiré) — le libellé « 9 deps » du Debug Log ci-dessus reflète l'état
> AVANT ce correctif.
