---
baseline_commit: 5271ac1ff3e7124324b0367e4570437ceed41d28
---

# Story ES-9.4 : Communauté / partage optionnelle + modération (+ dette sécu lex)

Status: review

<!-- Story enrichie par bmad-create-story (skill réel). Effort demandé : high (story L,
     nouvelle surface domaine multi-entités + garde de sécurité load-bearing). -->

## Story

As a **enseignant**,
I want **activer le partage d'un dossier d'étude (lien révocable, galerie publique, adhésion, signalement/modération) SANS que le partage devienne un invariant du domaine**,
so that **je partage un dossier modéré tandis que l'état personnel (SRS, ordre, lecture) n'est JAMAIS emporté par le partage, et la dette de sécurité héritée de lex (contributeur modifiant des champs de contrôle) est CORRIGÉE par conception ou DOCUMENTÉE explicitement — jamais héritée en silence**.

**FR couverte :** FR-S32 · **NFR :** NFR-S11 (sécurité), SM-SC2 (pas d'app-specific dans le package partagé) · **AD :** AD-26 (partage = extension optionnelle activable, état personnel jamais partagé), AD-4 (ZExtension + registres, `abstract interface` jamais `sealed`), AD-5 (`Either<ZFailure,T>` / `Unit` / `Stream<List<T>>` nu), AD-9 (offline-first, état personnel séparé, soft-delete/LWW hors-entité), AD-10 (désérialisation défensive), AD-11/AD-12 (backend-agnostique, zéro SDK/secret), AD-19.1 (extra protégé + verrouillé par test), AD-20 (`study_share_links` collection globale, `ZShareLink` révocable), AD-1/AD-17 (graphe acyclique, CORE OUT=0).

**Position dans la chaîne (STRICTEMENT SÉQUENTIEL) :** ES-9.1 (done) → ES-9.2 (done) → ES-9.3 (done) → **ES-9.4 (cette story, DERNIÈRE de l'epic ES-9)**. Une seule en vol, **aucune parallélisation** (écrit `zcrud_study`, non ∥ avec ES-7.1/ES-8.1/ES-9.1/ES-9.3). Après elle : `bmad-retrospective` de l'epic ES-9.

---

## Acceptance Criteria

> **Convention de pouvoir discriminant (R12/R26, leçons ES-9.1 M-1 / ES-9.3 MEDIUM-1)** : chaque AC ci-dessous nomme la **garde load-bearing** et l'**injection à rouge provoqué** qui la verrouille. Une garde non exercée par un test qui ROUGIT est un **vœu** (`powerless guard`) — interdit. Chaque garde de cette story (ACL champs de contrôle, révocation, séparation état personnel, `extra` AD-19.1, anti-secret, optionalité) DOIT rougir sous neutralisation.

### AC1 — Partage = extension OPTIONNELLE ACTIVABLE (AD-26)

**Given** une app qui veut le partage
**When** elle l'active
**Then** le partage est fourni par des artefacts **`zcrud_study/lib/src/domain/`** self-contained : entités `ZStudyMembership` / `ZShareLink` / `ZPublicStudyFolder` / `ZStudyFolderReport`, une extension concrète `ZStudySharingExtension implements ZExtension` (le slot **opt-in** porté par `ZStudyFolder.extension` — slot **DÉJÀ EXISTANT** dans le kernel, **RÉUTILISÉ** R21, jamais re-déclaré), et les ports `ZStudySharingPort` / `ZStudyModerationPort`.
**Discriminant** : l'extension `implements ZExtension` (pas `extends`, pas `sealed`) et expose un `static ZStudySharingExtension? fromJsonSafe(Object?)` bâti sur `ZExtension.guard` (précédent `ZNoteAudio`). Test : `fromJsonSafe(null)`/map corrompue ⇒ `null`, `formatVersion` non gérée ⇒ `null`, **jamais** de throw (AD-10). Si `fromJsonSafe` propage une exception → le test ROUGIT.

### AC2 — App qui N'ACTIVE PAS le partage : ni entités, ni backend (SM-SC2)

**Given** une app qui n'active pas le partage
**When** on résout son graphe et qu'elle round-trip un `ZStudyFolder`
**Then** elle n'en tire **ni entités ni backend** : (a) **aucune** nouvelle arête de graphe (delta = 0, pas de SDK/backend de partage tiré — pubspec `zcrud_study` inchangé) ; (b) `ZStudyFolder.fromMap(map)` **SANS** `extensionParser` de partage décode le dossier **normalement** (`extension == null`), le dossier survit (AD-10), aucune activation implicite.
**Discriminant** : test qui construit une map de dossier portant un bloc `extension` de partage, la décode **sans** parser, asserte `folder.extension == null` **et** que le round-trip du reste du dossier est intact. Le graphe est prouvé par `graph_proof.py` (44 arêtes, delta 0, CORE OUT=0). Si une arête backend apparaît (ex. un import `cloud_firestore`/SDK dans un fichier domaine) → `graph_proof`/gate ROUGIT.

### AC3 — État PERSONNEL jamais emporté par le partage (AD-9/AD-26)

**Given** l'état personnel (`ZRepetitionInfo`, `ZFolderContentsOrder`, `ZDocumentReadingState`/`ZDocumentLearningInfo`)
**When** un dossier est partagé / publié / une adhésion est créée
**Then** **aucune** entité de partage (ni `ZStudySharingExtension`) ne porte, ni ne sérialise, une clé d'état personnel — le sous-arbre partageable est **structurellement disjoint** du sous-arbre personnel.
**Discriminant (LOAD-BEARING)** : test qui énumère les clés sérialisées (`toJson()`/`toMap()`) de **toutes** les entités de partage + de l'extension et asserte l'**intersection VIDE** avec un ensemble de clés d'état personnel connues (`{repetition, repetition_info, folder_contents_order, reading_state, learning_info, ease_factor, interval, repetitions, due_date, next_review}` — noms de champs SRS/ordre/lecture des packages `zcrud_flashcard`/`zcrud_study_kernel`/`zcrud_document`). **Injection R3 (à rouge provoqué)** : ajouter en prod un champ `repetitionInfo`/`easeFactor` (ou étaler un état personnel) dans une entité de partage → le test ROUGIT. Sans ce test, la séparation serait un vœu.

### AC4 — `ZShareLink` révocable ; `study_share_links` collection globale ; champs de contrôle protégés (AD-20)

**Given** un `ZShareLink`
**When** on le révoque
**Then** il porte un état de révocation **monotone** (`revoked: bool` + `revokedAt: DateTime?`) ; le port `ZStudySharingPort.revokeShareLink(linkId)` retourne `ZResult<Unit>` (`Either<ZFailure, Unit>`) ; `study_share_links` est **documenté** comme collection **globale** résolue côté adapter (AD-20, résolution de chemin **hors domaine**) ; l'`ownerUid` et les champs de contrôle sont **protégés** (cf. AC5).
**Discriminant** : (a) `revokeShareLink` retourne `Unit`, **jamais** un `ZShareLink` nu ni un `Stream` enveloppé (AD-5) ; (b) un lien révoqué reste révoqué à travers un round-trip `toJson`/`fromJson` (la révocation **survit au décodage**, parité leçon M3 kernel) ; (c) l'ACL rejette la **dé-révocation** par un non-owner (AC5). **Injection R3** : rendre `revokeShareLink` non-`Unit` (ex. `ZResult<ZShareLink>`) → la liaison de type statique du test de surface ROUGIT à la compilation.

### AC5 — 🔴 DETTE DE SÉCURITÉ LEX : contributeur NE PEUT PAS modifier un champ de contrôle (NFR-S11 — CŒUR DE LA STORY)

**Given** la dette de sécurité héritée de lex (dans lex, un contributeur d'un dossier partagé peut modifier des **champs de contrôle** — `isPublic`/`sharedWith`/`canBeJoinedWithLink`/`coWorkersCanInviteOthers`/`shareId`/`ownerId`, le bloc V2c **inerte** aujourd'hui porté dans `ZStudyFolder` — car le partage était **baked dans l'entité** dossier et le merge **LWW** faisait « le dernier écrivain gagne » sans autorité ; la révocation ne prenait effet **qu'à la prochaine sync**)
**When** on porte le partage
**Then** la dette est **CORRIGÉE PAR CONCEPTION dans le domaine** (pas héritée en silence) :

1. **Séparation structurelle** — les champs de contrôle (propriété, rôle d'adhésion, état de révocation du lien, listing public) vivent dans les **entités de partage owner-contrôlées** (`ZShareLink.ownerUid`/`revoked`, `ZStudyMembership.role`, `ZPublicStudyFolder.ownerUid`), **jamais** routés par le sous-arbre partageable du dossier. Le bloc V2c de `ZStudyFolder` reste **inerte** (aucune logique de partage ne le lit) — la story n'y adosse **aucune** décision d'autorisation.
2. **Garde ACL PURE (load-bearing)** — une primitive de domaine `ZStudySharingAcl` expose `bool isControlField(String key)` et `bool canMutateControl({required String actorUid, required String ownerUid, required ZMembershipRole role})` : **seul l'owner** (ou un rôle explicitement habilité) peut muter un champ de contrôle ; un **contributeur/viewer** ne le peut **PAS**. Les ports (`activateSharing`/`revokeShareLink`/`grantMembership`/`publish`) **consomment** cette garde : une mutation de contrôle par un non-owner remonte `Left(ZFailure)` (échec d'autorisation domaine), **jamais** un `Right` silencieux.
3. **Révocation autoritaire in-domaine** — `revoked` étant un champ de contrôle, un contributeur ne peut **pas** le remettre à `false` (la garde rejette) : la révocation est **monotone côté domaine** (la « dé-révocation LWW » de lex est **fermée** au niveau de l'autorisation domaine).

**Discriminant (LOAD-BEARING, CŒUR)** : test `z_study_sharing_acl_test.dart` qui asserte : un `actorUid` **contributeur** ⇒ `canMutateControl(...) == false` pour **chaque** champ de contrôle (owner change, révocation, listing, invitation) ; un **owner** ⇒ `true`. **Injection R3 (obligatoire, prouvée à rouge)** : neutraliser la garde en prod (`canMutateControl(...) => true;` ou `isControlField(...) => false;`) → le test ROUGIT (un contributeur passerait la garde). Si la neutralisation laisse le test **VERT**, la garde est un vœu et la story est **NON conforme**.

**Dette résiduelle DOCUMENTÉE (jamais silencieuse)** : l'**enforcement SERVEUR** (règles backend rejetant une écriture non autorisée à la source, et l'atténuation du résiduel LWW « la garde locale ne bloque pas une écriture forgée côté store distant ») est **hors domaine** (backend-agnostique, AD-11/AD-12 ; le backend de partage est **fourni par l'app**, AD-26). Le domaine fait **sa part** : séparation structurelle + prédicat d'autorisation **pur, testable, consommé par les ports**, que les règles serveur de l'app **doivent** répliquer. Ce résiduel est **inscrit** en dartdoc impossible à rater **et** au registre de dettes (**DW-ES94-1**, cf. Dev Notes) — corrigé/documenté explicitement, **jamais** hérité en silence (NFR-S11).

### AC6 — `extra` protégé AD-19.1 sur chaque porteur (verrouillé par test)

**Given** toute entité de partage (et `ZStudySharingExtension`) portant un `extra: Map<String,dynamic>`
**When** on lit `extra`
**Then** les clés de sync **réservées** (`updated_at`/`is_deleted`, `ZSyncMeta.reservedKeys`) sont **écartées à la LECTURE** (slot privé `_extra` brut + accesseur `zSanitizeExtra(_extra, {...ZSyncMeta.reservedKeys})`), et aucune entité de partage ne déclare de champ `updatedAt`/`isDeleted` interne (AD-19.1 : LWW **hors-entité** exclusivement).
**Discriminant (M-1)** : `z_study_sharing_reserved_keys_test.dart` construit chaque porteur avec `extra = {updated_at, is_deleted, legit:42}` et asserte les clés réservées **absentes**, `legit` **préservée**, deux instances ne différant que par une clé réservée **égales**. **Injection R3** : neutraliser un accesseur (`get extra => _extra;`) → ROUGIT. `reserved_keys_gate` **n'importe PAS `zcrud_study`** (établi ES-9.1 M-1) ⇒ **SEUL** ce test package-local couvre ces porteurs.

### AC7 — Ports NEUTRES : zéro SDK/secret/endpoint (AD-11/AD-12) + surface AD-5

**Given** les ports `ZStudySharingPort` / `ZStudyModerationPort`
**When** on inspecte le domaine
**Then** (a) `abstract interface class`, **jamais** `sealed` (AD-4) ; (b) toute opération retourne `Future<ZResult<T>>` (= `Either<ZFailure,T>`) ou `ZResult<Unit>` pour un void ; tout flux est un `Stream<List<T>>` **NU** (AD-5) — **jamais** un `T` nu, **jamais** un `Stream` enveloppé dans `ZResult` ; (c) **aucun** littéral d'endpoint/URL, clé, token, en-tête d'auth, nom de collection en dur, `package:crypto`, ni SDK backend dans les fichiers `lib/src/domain/`.
**Discriminant** : `z_study_sharing_no_secret_test.dart` (ou extension du scan ES-9.1) scanne `lib/src/domain/*.dart` — **injection R3** : insérer `const _ep = 'https://…'` ou une clé `AIzaSy…` → ROUGIT (local **et** `gate:secrets`). Surface AD-5 pincée par liaison de type statique (un retour nu rougirait à la compilation du test de surface).

---

## Tasks / Subtasks

- [x] **T1 — Entités de partage (domaine, hand-written défensif AD-10 ; PAS `@ZcrudModel`)** (AC1, AC3, AC4, AC6)
  - [x] `packages/zcrud_study/lib/src/domain/z_study_membership.dart` — `ZStudyMembership` (`id` String? opaque, `folderId`, `actorUid`, `role: ZMembershipRole`, `extra`) + enum **ouvert** `ZMembershipRole { owner, contributor, viewer, unknown }` avec repli `unknown` sur valeur inconnue (`fromName` défensif, AD-10). Immuable, `const` ctor, `copyWith`, `toJson`/`fromJson` défensif (jamais throw), `==`/`hashCode` par valeur (égalité **profonde** `extra` via `zJsonEquals`/`zJsonHash`).
  - [x] `z_share_link.dart` — `ZShareLink` (`id`/`token` opaque, `folderId`, `ownerUid`, `revoked: bool = false`, `revokedAt: DateTime?`, `extra`). `revoke()` helper renvoyant une copie révoquée ; round-trip qui **préserve** l'état de révocation (survit au décodage).
  - [x] `z_public_study_folder.dart` — `ZPublicStudyFolder` (`id`/`folderId`, `ownerUid`, `title`, `listedAt: DateTime?`, `extra`) — métadonnées de galerie **partageables uniquement** (aucun état personnel).
  - [x] `z_study_folder_report.dart` — `ZStudyFolderReport` (`id`, `folderId`, `reporterUid`, `reason: String`, `status: ZReportStatus`, `createdAt: DateTime?`, `extra`) + enum ouvert `ZReportStatus { open, reviewing, resolved, dismissed, unknown }`.
  - [x] **AD-19.1 sur CHAQUE entité** : slot privé `_extra`, accesseur `extra => zSanitizeExtra(_extra, _reservedKeys)`, `_reservedKeys = {...ZSyncMeta.reservedKeys}` ; **aucun** champ `updatedAt`/`isDeleted` interne.
- [x] **T2 — Extension de partage concrète (slot opt-in de `ZStudyFolder`, RÉUTILISE le slot kernel)** (AC1, AC3, AC5-pt1)
  - [x] `z_study_sharing_extension.dart` — `ZStudySharingExtension implements ZExtension` : `formatVersion`, champs de **contrôle partageables** (`isPublic`, `joinableWithLink`, `coOwnersCanInvite`, `shareLinkId?`) — **jamais** d'état personnel. `toJson()` incluant `format_version` ; `static ZStudySharingExtension? fromJsonSafe(Object?)` sur `ZExtension.guard` (précédent `ZNoteAudio`, version non gérée ⇒ `null`). **NE PAS** re-déclarer le slot dans le kernel : `ZStudyFolder.extension` (`ZExtension?`) + `ZFolderExtensionParser` existent déjà — l'app injecte `extensionParser: ZStudySharingExtension.fromJsonSafe`.
- [x] **T3 — 🔴 Garde ACL de sécurité (CŒUR, dette lex corrigée)** (AC5)
  - [x] `z_study_sharing_acl.dart` — `ZStudySharingAcl` : `bool isControlField(String key)` (ensemble figé des clés de contrôle), `bool canMutateControl({required String actorUid, required String ownerUid, required ZMembershipRole role})` (owner ⇒ true ; contributor/viewer/unknown ⇒ false). Pur, total, déterministe, jamais de throw/IO/`DateTime.now()`.
  - [x] Dartdoc **impossible à rater** documentant la dette lex (contributeur mutant un champ de contrôle ; limite LWW/révocation à la prochaine sync) et **DW-ES94-1** (enforcement serveur = hors domaine, à répliquer côté règles app).
- [x] **T4 — Ports neutres** (AC1, AC4, AC7)
  - [x] `z_study_sharing_port.dart` — `abstract interface class ZStudySharingPort` : `activateSharing`/`createShareLink` → `Future<ZResult<ZShareLink>>`, `revokeShareLink(String linkId)` → `Future<ZResult<Unit>>`, `grantMembership(ZStudyMembership)` → `Future<ZResult<ZStudyMembership>>`, `watchMemberships(String folderId)` → `Stream<List<ZStudyMembership>>` **nu**, `publishToGallery`/`unpublish` → `Future<ZResult<ZPublicStudyFolder>>` / `Future<ZResult<Unit>>`. Dartdoc : chaque mutation de contrôle **consomme** `ZStudySharingAcl` (impl app), `study_share_links` = collection **globale** résolue côté adapter (AD-20).
  - [x] `z_study_moderation_port.dart` — `abstract interface class ZStudyModerationPort` : `report(ZStudyFolderReport)` → `Future<ZResult<Unit>>`, `watchReports(String folderId)` → `Stream<List<ZStudyFolderReport>>` **nu**, `resolveReport`/`takedown` → `Future<ZResult<Unit>>`.
- [x] **T5 — Barrel** (AC1)
  - [x] `packages/zcrud_study/lib/zcrud_study.dart` : `export` des 7 nouveaux fichiers domaine sous une rubrique « ES-9.4 — communauté / partage optionnel ». **NE PAS** ré-exporter `ZStudyFolder`/`ZExtension` (viennent du kernel/core).
- [x] **T6 — Tests discriminants (chaque garde verrouillée par un rouge provoqué)** (tous ACs)
  - [x] `test/z_study_sharing_entities_test.dart` — construction, `fromJson` défensif (map vide/corrompue/enum inconnu ⇒ défaut, jamais throw), round-trip `toJson`/`fromJson` **exact** (cas non-dégénérés, R26), `==`/`hashCode` **par champ** (varier UN seul champ à la fois, y compris `extra`, y compris `revoked`/`role` — leçon ES-9.3 MEDIUM-1).
  - [x] `test/z_study_sharing_reserved_keys_test.dart` — AC6, verrou M-1 (rouge sous `get extra => _extra;`).
  - [x] `test/z_study_sharing_acl_test.dart` — **AC5 CŒUR** : contributeur ⇒ pas de mutation de contrôle, owner ⇒ oui ; rouge sous `canMutateControl => true` / `isControlField => false`. Inclut un cas « contributeur ne peut PAS dé-révoquer un lien ».
  - [x] `test/z_study_sharing_personal_state_test.dart` — AC3 : intersection vide des clés sérialisées vs clés d'état personnel ; rouge si un champ personnel est ajouté à une entité de partage.
  - [x] `test/z_study_sharing_ports_surface_test.dart` — AC4/AC7 : surface AD-5 (retours `ZResult`/`Unit`/`Stream` nu, liaison de type statique), `abstract interface`/non-`sealed`, contrat de révocation.
  - [x] `test/z_study_sharing_optional_test.dart` — AC2 : `ZStudyFolder.fromMap` sans parser ⇒ `extension == null`, dossier survit ; assertion « pas de nouvelle dépendance backend » (documentaire, complétée par le graph_proof orchestrateur).
  - [x] `test/z_study_sharing_no_secret_test.dart` — AC7 : scan anti-secret/anti-endpoint/anti-crypto des nouveaux fichiers domaine (rouge sous injection d'un endpoint/clé). *(Alternative acceptée : étendre `z_ai_ports_no_secret_test.dart` — le scan couvre déjà tout `lib/src/domain/*.dart` ; vérifier que le seuil `greaterThanOrEqualTo` reste cohérent avec le nouveau compte de fichiers.)*
- [x] **T7 — Vérif verte + graphe** (tous ACs) — cf. section « Vérif verte à rejouer ».

---

## Dev Notes

### Périmètre & optionalité — ce qui existe DÉJÀ vs ce qui est à CRÉER (validé sur disque)

- **RIEN de la surface de partage n'existe encore** dans le domaine : `grep -rl "ZStudyMembership\|ZShareLink\|ZPublicStudyFolder\|ZStudyFolderReport\|ZStudySharingPort\|ZStudyModerationPort"` sur `packages/*/lib` rend **zéro**. **Tout est à créer** dans `packages/zcrud_study/lib/src/domain/`.
- **Le slot d'extension EXISTE DÉJÀ (RÉUTILISER, R21 — ne PAS re-déclarer)** : `ZStudyFolder` (kernel) porte déjà `final ZExtension? extension` (mixin `ZExtensible`) **et** le typedef `ZFolderExtensionParser` + `ZStudyFolder.fromMap(map, {extensionParser})`. La story **n'a donc PAS à toucher le kernel** : elle fournit la sous-classe concrète `ZStudySharingExtension` (dans `zcrud_study`) et l'app l'injecte comme parser. ⇒ **delta graphe = 0**, aucune contention d'écriture kernel, `zcrud_study_kernel` NON modifié.
- **Origine de la dette de sécurité lex** : le bloc V2c **inerte** de `ZStudyFolder` (`isPublic`/`sharedWith`/`canBeJoinedWithLink`/`coWorkersCanInviteOthers`/`shareId` — `z_study_folder.dart:44-51,190-208`). En lex, ces champs de contrôle vivaient **dans l'entité dossier** partagée et le merge **LWW** (AD-9) laissait « le dernier écrivain gagne » : un contributeur pouvait les réécrire, et la révocation n'agissait qu'à la sync suivante. **La correction ES-9.4** ne réactive **pas** ce bloc : elle route le contrôle par des **entités owner-contrôlées séparées** + une **garde ACL pure**. Le bloc V2c reste inerte (aucune régression, discipline « figer tôt »).
- **Package(s) touché(s)** : **`zcrud_study` UNIQUEMENT** (domaine + barrel + tests). Kernel/core **consommés**, non modifiés.
- **Runner (R14)** : `zcrud_study` dépend de `flutter` ⇒ **`flutter test`** (pas `dart test`). RC capturés **hors pipe (R15)**.

### Patrons OBLIGATOIRES (réutilisation — ne rien réinventer)

- **Entités hand-written défensives, PAS `@ZcrudModel`** : `zcrud_study` n'a **aucun** codegen (aucun `.g.dart`, aucun `build_runner`), et `reserved_keys_gate` **n'importe pas `zcrud_study`** (ES-9.1 M-1). Introduire `@ZcrudModel` ici serait une expansion d'infra hors périmètre. Suivre le patron **hand-written défensif** déjà en place dans ce package : `ZEducationQuotaInfo` (`fromJson` défensif, coercions `_asIntOrNull`, jamais throw) et les request-VO (`z_podcast_generation_port.dart` : slot `_extra` + accesseur `zSanitizeExtra`, `==`/`hashCode` par valeur avec `zJsonEquals`/`zJsonHash`).
- **`ZExtension` concret** : calquer `ZNoteAudio` (`packages/zcrud_note/lib/src/domain/z_note_audio.dart`) — `implements ZExtension`, `formatVersion`, `toJson` avec `format_version`, `fromJsonSafe` sur `ZExtension.guard` (version non gérée / corrompu ⇒ `null`, jamais throw). **Ne pas** `extends`, **jamais** `sealed`.
- **Ports** : calquer `ZPodcastGenerationPort` (`abstract interface class`, `Future<ZResult<…>>`) et le contrat `ZStudyRepository` du kernel pour les flux nus. Import `package:zcrud_core/domain.dart` (`ZResult`, `Either`, `ZFailure`, `Unit`, `ZExtension`, `ZSyncMeta`, `zSanitizeExtra`, `zJsonEquals`, `zJsonHash`).
- **Clés persistées** : snake_case ; enums en camelCase avec repli `unknown` (AD-3/AD-10). **Aucun** nom de collection en dur dans le domaine (`study_share_links` = concern d'adapter, AD-20).

### 🔴 Dette de sécurité lex — traitement EXPLICITE (NFR-S11) — ne PAS hériter en silence

- **Corrigée par conception (in-domaine)** : (1) séparation structurelle des champs de contrôle ; (2) `ZStudySharingAcl.canMutateControl` — prédicat **pur** rejetant un contributeur ; (3) révocation monotone (dé-révocation par non-owner rejetée). Verrou : `z_study_sharing_acl_test.dart` **rougit** sous neutralisation de la garde (AC5 — obligatoire).
- **Résiduel DOCUMENTÉ = DW-ES94-1** : l'enforcement **serveur** (règles backend rejetant l'écriture forgée à la source ; atténuation du résiduel LWW distant) est **hors domaine backend-agnostique** (AD-11/AD-12 ; backend de partage fourni par l'app, AD-26). Le domaine expose le prédicat que les règles serveur de l'app **doivent** répliquer. **Inscrire** DW-ES94-1 en dartdoc de `ZStudySharingAcl` **et** le mentionner dans le Dev Agent Record + le rapport de story. Ceci **satisfait** NFR-S11 (« corrigée OU documentée explicitement, jamais héritée en silence ») en faisant **les deux**.
- **Anticipé (DW-ES14-2 relatif, NON introduit ici, à ne pas confondre)** : pour une app qui n'active PAS le partage mais round-trip un dossier écrit AVEC partage, `ZStudyFolder.toMap` **omet** un `extension == null` (comportement pré-existant de `z_study_folder.dart:269`) ⇒ le slot non typé n'est pas réémis. C'est le **DW-ES14-2** déjà tracé (correctif de fond = `zcrud_core`/registre), **hors périmètre ES-9.4**. Ne pas tenter de le corriger ici ; le **signaler** si observé (ne pas masquer).

### Séparation état personnel (AC3) — pourquoi c'est structurel

`ZRepetitionInfo` (`zcrud_flashcard`), `ZFolderContentsOrder` (kernel), `ZDocumentReadingState`/`ZDocumentLearningInfo` (`zcrud_document`) sont l'**état personnel** de l'utilisateur. AD-9/AD-26 : ils vivent dans un sous-arbre **distinct** et ne sont **jamais** colocalisés dans le contenu partageable. Concrètement, **aucun** champ des entités de partage ni de `ZStudySharingExtension` ne référence ces clés. Le test AC3 rend cette absence **exécutoire** (intersection vide), sinon c'est un vœu.

### Anti-pattern à éviter (leçons ES-9.1 / ES-9.3 — CRUCIALES)

- **`powerless guard` (M-1)** : toute garde (ACL, révocation, séparation personnelle, `extra`, anti-secret, optionalité) **DOIT** rougir sous neutralisation prod. Un test qui reste VERT quand on casse la garde ne **prouve rien**.
- **Égalité sous-testée (ES-9.3 MEDIUM-1)** : les cas négatifs de `==` doivent varier **UN seul champ à la fois** (helper `copyOf`/`copyWith`), sinon un champ retiré de `==` passe inaperçu. Couvrir **chaque** champ, `extra` (deep) inclus, `revoked`/`role` inclus.
- **`R20` (garde alimentée par du code consommé)** : ne pas survaloriser un test qui exerce surtout un fake ou du code kernel déjà testé ; nommer explicitement la seule ligne de prod ES-9.4 réellement pincée.

### Injections R3 prévues (avec verrouillage ACL/sécu explicite)

| Injection | Cible prod | Test verrou | Rouge attendu |
|---|---|---|---|
| **R3-ACL (CŒUR, AC5)** — `canMutateControl(...) => true;` (ou `isControlField => false`) | `z_study_sharing_acl.dart` | `z_study_sharing_acl_test.dart` | contributeur passe la garde ⇒ **RED** |
| **R3-REVOKE (AC4)** — un lien révoqué autorise la dé-révocation par non-owner | `z_study_sharing_acl.dart` / `z_share_link.dart` | `z_study_sharing_acl_test.dart` | dé-révocation acceptée ⇒ **RED** |
| **R3-PERSONAL (AC3)** — ajouter `repetitionInfo`/`easeFactor` à une entité de partage | entités de partage | `z_study_sharing_personal_state_test.dart` | intersection non vide ⇒ **RED** |
| **R3-EXTRA (AC6, M-1)** — `get extra => _extra;` | chaque entité + extension | `z_study_sharing_reserved_keys_test.dart` | `updated_at` survit ⇒ **RED** |
| **R3-SECRET (AC7)** — insérer `AIzaSy…` / `https://…` dans un fichier domaine | fichier domaine partage | `z_study_sharing_no_secret_test.dart` **+** `gate:secrets` | fuite détectée ⇒ **RED** (local + gate) |
| **R3-SURFACE (AC4/AC7)** — `revokeShareLink` → `ZResult<ZShareLink>` (non-`Unit`) | `z_study_sharing_port.dart` | `z_study_sharing_ports_surface_test.dart` | erreur de compilation ⇒ **RED** |
| **R3-EQ (AC1, ES-9.3 leçon)** — retirer `zJsonEquals(extra,…)` (ou `revoked ==`) de `==` | entité | `z_study_sharing_entities_test.dart` | cas mono-champ ⇒ **RED** |
| **R3-OPT (AC2)** — parser injecté implicitement / import backend | domaine | `graph_proof.py` + `z_study_sharing_optional_test.dart` | delta arête ≠ 0 ⇒ **RED** |

> Toute injection est **restaurée par édition ciblée (R13)** après vérification ; l'orchestrateur rejoue lui-même au moins l'injection **R3-ACL** (cœur) pour confirmer le pouvoir discriminant réel avant `done`.

### Project Structure Notes

- Fichiers **NEW** uniquement, tous sous `packages/zcrud_study/lib/src/domain/` (7) + `test/` (7) + 1 édition **UPDATE** ciblée du barrel `lib/zcrud_study.dart`. **Aucun** `.g.dart` (pas de codegen). **Aucune** modification hors `packages/zcrud_study/`.
- **Aucune** nouvelle dépendance pubspec (AC2/AD-1). Réutilise `zcrud_core` (types domaine) et `zcrud_study_kernel` (`ZStudyFolder`, `ZExtension` via core) déjà déclarés.
- `sprint-status.yaml` et `architecture.md` **NON touchés** par la story (transition de statut = responsabilité orchestrateur).

### Vérif verte à rejouer (RÉELLEMENT, RC hors pipe — R15 ; runner R14)

```bash
# 1. Tests du package (runner R14 = flutter test, RC hors pipe R15)
cd packages/zcrud_study && flutter test          # attendu RC=0 (baseline ES-9.3 = 148 tests + nouveaux)

# 2. Graphe (AC2/AD-1) — delta 0, acyclique, CORE OUT=0
python3 scripts/dev/graph_proof.py               # attendu : total arêtes = 44, ACYCLIQUE OK, CORE OUT=0 OK

# 3. Workspace intact
dart run melos list                              # attendu : 20 packages

# 4. Gates repo-wide (NON-NÉGOCIABLE au gate de commit d'epic)
dart run melos run analyze                       # RC=0 repo-wide
dart run melos run verify                        # RC=0 : gate:secrets OK, [gate:reserved-keys] OK, reflectable/codegen/codegen-distribution/compat/web + verify:serialization OK
```

**Verrous à confirmer RÉELS avant `done`** : injection R3-ACL (cœur sécu) rougit puis restaurée VERT ; `gate:secrets` rougit sous clé injectée puis VERT ; `extra` reserved-keys rougit sous accesseur neutralisé puis VERT. Ne jamais enchaîner sur la foi du rapport dev — rejouer sur disque.

### References

- Epic ES-9.4 : `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story ES-9.4` (l. 986-1014), métadonnées l. 992.
- AD-26 (partage extension optionnelle, état personnel jamais partagé) : `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md:254-257`.
- AD-20 (`study_share_links` collection globale, `ZShareLink` révocable, résolution de chemin hors domaine) : `architecture.md:218-226`.
- AD-19.1 (`extra` protégé + verrouillé, `ZSyncMeta.reservedKeys`, entités de partage nommées) : `architecture.md:99-157`, pt. entités de partage l. 108.
- AD-4 / AD-5 / AD-9 / AD-10 / AD-11 / AD-12 : `architecture.md` (tableau AD l. 46-52) ; DETTES OUVERTES DW-ES14-2 l. 384-388.
- NFR-S11 / SM-SC2 : `_bmad-output/planning-artifacts/prds/prd-zcrud-study-2026-07-12/prd.md:368,406,444-445` ; epics l. 81, 928.
- Précédents de code (RÉUTILISER) : `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart` (slot `extension` + `ZFolderExtensionParser`, bloc V2c inerte, patron `extra`) ; `packages/zcrud_note/lib/src/domain/z_note_audio.dart` (`ZExtension` concret) ; `packages/zcrud_study/lib/src/domain/z_podcast_generation_port.dart` (port + request-VO `extra`) ; `packages/zcrud_study/lib/src/domain/z_education_quota_info.dart` (VO défensif) ; `packages/zcrud_study_kernel/lib/src/domain/z_study_repository.dart` (contrat AD-5, flux nus).
- Leçons verrouillées : code-review ES-9.1 (M-1 `powerless guard`) `code-review-es-9-1.md` ; code-review ES-9.3 (MEDIUM-1 égalité par champ) `code-review-es-9-3.md` ; verrou reserved-keys `packages/zcrud_study/test/z_ai_ports_reserved_keys_test.dart` ; scan anti-secret `packages/zcrud_study/test/z_ai_ports_no_secret_test.dart`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill réel `bmad-dev-story`, effort high).

### Debug Log References

- `flutter test` zcrud_study (R14, RC hors pipe R15) → **RC=0, 201 tests** (baseline ES-9.3 = 148 → +53 nouveaux).
- `python3 scripts/dev/graph_proof.py` → RC=0 : **44 arêtes, delta 0**, ACYCLIQUE OK, CORE OUT=0 OK.
- `dart run melos list` → RC=0, **20 packages**.
- `dart run melos exec --scope=zcrud_study -- dart analyze` → RC=0. `dart run melos run analyze` (repo-wide) → RC=0.
- `dart run melos run verify` (repo-wide) → **RC=0** : gate:secrets OK, gate:reserved-keys OK (volets A+B+couverture AD-19.1.c), reflectable/codegen/codegen-distribution/compat/web + verify:serialization OK.

**Verrous discriminants R3 (rouge PROVOQUÉ puis restauré, RC hors pipe) :**
- **R3-ACL (CŒUR, AC5)** — `canMutateControl(...) => true;` → `z_study_sharing_acl_test.dart` **RED** (contributeur/viewer/unknown/dé-révocation passent) → restauré VERT.
- **R3-EXTRA (AC6, M-1)** — `get extra => _extra;` (ZShareLink) → `z_study_sharing_reserved_keys_test.dart` **RED** → restauré VERT.
- **R3-PERSONAL (AC3)** — `'ease_factor': 2.5` ajouté au `toJson` de `ZStudyMembership` → `z_study_sharing_personal_state_test.dart` **RED** (intersection non vide) → restauré VERT.
- **R3-SECRET (AC7)** — `const _ep = 'https://…'` injecté dans `z_study_sharing_port.dart` → `z_study_sharing_no_secret_test.dart` **RED** → restauré VERT.

### Completion Notes List

- **Périmètre respecté** : écriture **UNIQUEMENT** dans `packages/zcrud_study/` (8 fichiers domaine NEW + barrel UPDATE + 7 tests NEW). `zcrud_study_kernel`/`zcrud_core` **consommés, non modifiés**. Bloc V2c inerte de `ZStudyFolder` **non réactivé**. Slot kernel `ZStudyFolder.extension` + `ZFolderExtensionParser` **RÉUTILISÉS** (R21) via l'injection `extensionParser: ZStudySharingExtension.fromJsonSafe`.
- **Dette sécu lex — DEUX voies (AC5/NFR-S11)** : (1) **corrigée par conception** — champs de contrôle isolés dans entités owner-contrôlées (`ZShareLink.ownerUid`/`revoked`, `ZStudyMembership.role`, `ZPublicStudyFolder.ownerUid`/`listedAt`) + garde ACL pure `ZStudySharingAcl.canMutateControl` (contributeur ⇒ `false`) + révocation **monotone** (non-owner ne peut dé-révoquer) ; (2) **état personnel séparé** — intersection VIDE prouvée (`z_study_sharing_personal_state_test.dart`).
- **🔴 DW-ES94-1 (À ESCALADER par l'orchestrateur)** : l'**enforcement SERVEUR** (règles backend rejetant à la source une écriture de contrôle forgée + atténuation du résiduel LWW distant) est **HORS DOMAINE** (AD-11/AD-12/AD-26, backend fourni par l'app). Le domaine fournit le prédicat pur `canMutateControl` que les règles serveur de l'app **DOIVENT répliquer**. Documenté en dartdoc **impossible à rater** dans `z_study_sharing_acl.dart` + `z_study_sharing_port.dart`/`z_study_moderation_port.dart`. **Non inscrit dans architecture.md** (non touché) — escalade orchestrateur.
- **DW-ES14-2 (pré-existant, HORS périmètre)** : `ZStudyFolder.toMap` omet un `extension == null` — non corrigé ici (correctif de fond = `zcrud_core`). Non introduit ni aggravé par cette story.
- **AD-19.1** : chaque porteur d'`extra` (4 entités + les 3 request-VO existants) protégé par slot `_extra` + `zSanitizeExtra(...ZSyncMeta.reservedKeys)`, verrouillé par `z_study_sharing_reserved_keys_test.dart`.
- **sprint-status.yaml** et **architecture.md** : **NON touchés** (responsabilité orchestrateur).

### File List

**NEW — domaine (`packages/zcrud_study/lib/src/domain/`) :**
- `z_study_membership.dart` (`ZStudyMembership` + enum ouvert `ZMembershipRole`)
- `z_share_link.dart` (`ZShareLink` révocable + `revoke()`)
- `z_public_study_folder.dart` (`ZPublicStudyFolder`)
- `z_study_folder_report.dart` (`ZStudyFolderReport` + enum ouvert `ZReportStatus`)
- `z_study_sharing_extension.dart` (`ZStudySharingExtension implements ZExtension`)
- `z_study_sharing_acl.dart` (`ZStudySharingAcl` — garde pure CŒUR + DW-ES94-1)
- `z_study_sharing_port.dart` (`abstract interface class ZStudySharingPort`)
- `z_study_moderation_port.dart` (`abstract interface class ZStudyModerationPort`)

**UPDATE :**
- `packages/zcrud_study/lib/zcrud_study.dart` (barrel — export des 8 fichiers domaine, rubrique ES-9.4)

**NEW — tests (`packages/zcrud_study/test/`) :**
- `z_study_sharing_entities_test.dart` (construction, fromJson défensif, round-trip R26, `==` par champ)
- `z_study_sharing_reserved_keys_test.dart` (AC6, verrou M-1)
- `z_study_sharing_acl_test.dart` (AC5 CŒUR, R3-ACL, R3-REVOKE)
- `z_study_sharing_personal_state_test.dart` (AC3, R3-PERSONAL, intersection vide)
- `z_study_sharing_ports_surface_test.dart` (AC4/AC7, surface AD-5 par liaison de type statique)
- `z_study_sharing_optional_test.dart` (AC2, optionalité, `extension == null` sans parser)
- `z_study_sharing_no_secret_test.dart` (AC7, scan anti-secret/endpoint/crypto)
