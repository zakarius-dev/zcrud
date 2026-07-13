# Story ES-1.3 : Réconciliation des métadonnées de sync — `ZSyncMeta` hors-entité (OQ #3)

Status: review

<!-- Note: Validation optionnelle. Lancer validate-create-story avant dev-story si souhaité. -->

## Story

As a **développeur intégrateur**,
I want **une convention UNIQUE de métadonnées de sync (`ZSyncMeta` hors-entité) pour toutes les entités study, l'alignement outillé de `ZStudyFolder`, et la divergence résiduelle documentée**,
so that **le moteur de merge LWW soit unique (jamais deux conventions in-entité vs hors-entité incompatibles) AVANT qu'ES-2 ne fige les entités canoniques**.

Périmètre : **verrouiller une convention déjà partiellement en place**, pas en inventer une. `ZSyncMeta` **EXISTE DÉJÀ** dans `zcrud_core` (E5-3) et le merge LWW **s'y appuie déjà**. Cette story (1) **prouve** cette propriété par des tests qui **cassent** si quelqu'un rebranche le merge sur un `T.updatedAt` interne, (2) **corrige un défaut réel** de capture des clés de sync dans `extra`, (3) **déprécie** `ZStudyFolder.updatedAt` en miroir de compat, (4) **consigne** AD-19 + la divergence résiduelle dans la doc d'architecture + memlog.

> **Métadonnées** — Taille : **M** · Statut initial : `backlog` · Parallélisation : **SÉQUENTIELLE** (écrit `zcrud_core` **et** `zcrud_study_kernel` **et** `zcrud_flashcard` → aucun autre workstream en vol). Packages : `zcrud_core` (1 fichier domaine), `zcrud_study_kernel` (1 entité + tests), `zcrud_flashcard` (1 entité + tests), doc `architecture-zcrud-study-2026-07-12/architecture.md` (AD-19) + `.memlog.md`. **Couvre :** FR-S3 · **AD :** **AD-19** (à matérialiser), AD-9, AD-16, AD-10, AD-1, AD-4, AD-5 · **NFR-S3, NFR-S4** · **SM-S6**.

---

## Contexte & décisions de conception (LIRE AVANT DE CODER — NE PAS REJOUER CES TRANCHAGES)

L'investigation sur disque a été faite. **Ne rien re-décider** : implémenter tel quel.

### État réel du dépôt (vérifié, avec chemins:lignes)

| Question | Réponse RÉELLE |
|---|---|
| `ZSyncMeta` existe-t-il déjà ? | **OUI**, dans le cœur : `packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart:20` (+ `ZSyncEntry` `z_sync_entry.dart:27`, `ZLwwResolver` `z_lww_resolver.dart:86`), exportés par `packages/zcrud_core/lib/domain.dart:84-86`. |
| Le merge LWW lit-il déjà la méta ? | **OUI**. `ZLwwResolver.resolve` compare `local.updatedAt` / `remote.updatedAt` (`z_lww_resolver.dart:102`), et `ZSyncEntry.updatedAt` est **dérivé du meta** : `DateTime? get updatedAt => meta.updatedAt;` (`z_sync_entry.dart:41`). **Aucun** chemin ne lit `T.updatedAt`. |
| Précédent hors-entité (AD-19) | `ZMindmap` : `static const Set<String> _reservedSyncKeys = {'updated_at','is_deleted'}` (`packages/zcrud_mindmap/lib/src/domain/z_mindmap.dart:68-72`) — jamais capturées dans `extra`, jamais réémises par `toJson`. **C'est le patron à généraliser.** |
| `ZStudyFolder.updatedAt` | Champ de 1ʳᵉ classe (`packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart:162`), documenté lui-même comme « divergence **assumée** vs `ZMindmap` — open question canonique **#3 non tranchée ici** » (l. 30-33). **C'est cette OQ que la story clôt.** |
| Qui lit/écrit `ZStudyFolder.updatedAt` ? | **Personne en production.** Aucun dépôt/adapter ne le lit : les seuls usages sont des **tests** (`packages/zcrud_study_kernel/test/z_study_folder_test.dart:21,57,124,221` ; `packages/zcrud_flashcard/test/z_study_folder_test.dart:57,121-126,221`). Il n'existe **aucun** `ZStudyFolderRepository`. → **La dépréciation ne casse aucun appelant de production.** |
| L'entité est-elle nourrie par la méta ? | **OUI, par collision de clé.** Les stores écrivent `updated_at`/`is_deleted` **dans le même document** que le corps (`hive_z_local_store.dart:183-186` ; `firebase_z_repository_impl.dart:232`) puis passent la map **complète** à `fromMap` (`hive_z_local_store.dart:222-231` `_decodeEntity` ; `firebase_z_repository_impl.dart:670` `_decode`). `updated_at` étant un champ déclaré de `ZStudyFolder`, l'entité **absorbe** l'estampille du store : le miroir est déjà, de fait, **maintenu par l'adapter**. |
| Le dépôt flashcard merge-t-il sur `T.updatedAt` ? | **NON.** `ZFlashcardRepository` (`packages/zcrud_flashcard/lib/src/data/z_flashcard_repository.dart:69`) ne fait **aucun** merge : il délègue à `ZSyncableRepository<ZFlashcard>.sync()` (port E5), dont l'impl `ZOfflineFirstRepository` merge via `ZLwwResolver` sur `ZSyncEntry.meta`. `ZRepetitionInfo` (canal SRS) **ne porte AUCUN `updatedAt`** — la clé LWW est **exclusivement** hors-entité (`z_repetition_store.dart:12,20-22,53-54`). **`ZRepetitionInfo` est déjà le modèle de la convention cible.** |

### D1 — `ZSyncMeta` est RÉUTILISÉ depuis `zcrud_core`. **Aucun** doublon, **aucun** réexport dans le kernel.

L'epic évoquait un fichier `packages/zcrud_study_kernel/lib/src/domain/z_sync_meta.dart` (« réexport/alignement depuis `zcrud_core` **si déjà présent** »). **Il est déjà présent** ⇒ **ce fichier NE SERA PAS CRÉÉ**, et le kernel **ne réexporte pas** `ZSyncMeta`.

Justification (à recopier en Completion Notes) :
1. **AD-1 / source unique.** Le kernel dépend de `zcrud_core` (`packages/zcrud_study_kernel/pubspec.yaml`, `dependencies: zcrud_core`) : tout satellite study accède déjà à `ZSyncMeta` via `import 'package:zcrud_core/domain.dart';`. Un réexport créerait **deux chemins d'import** pour un même symbole — dette de surface pure.
2. **Effet de bord toxique du réexport.** `zcrud_flashcard` réexporte **en bloc** le barrel kernel (`packages/zcrud_flashcard/lib/zcrud_flashcard.dart`, `export 'package:zcrud_study_kernel/zcrud_study_kernel.dart' hide …`). Réexporter `ZSyncMeta` depuis le kernel le **ferait fuiter** dans la surface publique de `zcrud_flashcard` — exactement ce que D3/L4 d'ES-1.2 interdit.

### D2 — **TRANCHAGE : `ZSyncMeta` NE RENTRE PAS dans la surface publique de `zcrud_flashcard`** (ni `hide`, ni allowlist)

**Décision : `ZSyncMeta` reste accessible via `package:zcrud_core/domain.dart` uniquement.**

- **Le dépôt flashcard n'en a pas besoin dans SA surface.** `ZFlashcardRepository` compose des **ports** (`ZSyncableRepository<ZFlashcard>`, `ZRepetitionStore`) : la méta est portée **par les ports**, elle ne traverse **jamais** l'API publique du dépôt (aucune signature publique de `z_flashcard_repository.dart` ne mentionne `ZSyncMeta`/`ZSyncEntry`).
- Les rares consommateurs internes (fakes de test : `packages/zcrud_flashcard/test/support/fakes.dart:45,153`) importent **déjà** `package:zcrud_core/domain.dart` directement. Rien à changer.
- **Conséquence sur le garde ES-1.2/L4** (`packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart`) : ce garde ne scanne **que** les symboles déclarés dans les fichiers `export 'src/…'` du barrel kernel (`_publicKernelSymbols`, l. 91-140). `ZSyncMeta` vivant dans `zcrud_core`, **il est structurellement invisible pour le garde**.

> **OBJECTIF DE CONCEPTION DE CETTE STORY : ajouter ZÉRO nouveau symbole public top-level au barrel `zcrud_study_kernel`.** Le garde reste donc vert **sans aucune modification** ni du `hide` de `zcrud_flashcard`, ni de `_flashcardAllowlist`. C'est **vérifié par AC6** (et non supposé).

### D3 — Les clés de sync deviennent des **statiques de `ZSyncMeta`** (zcrud_core) — donc **zéro nouveau symbole public**

Le patron `ZMindmap._reservedSyncKeys` est **dupliqué à la main** partout (`z_mindmap.dart:68`, `z_mindmap_node.dart:83`, `hive_z_local_store.dart:122-126`, `firebase_z_repository_impl.dart:159-163`). La 5ᵉ copie (dans `ZStudyFolder`) serait la duplication de trop, et la convention AD-19 doit avoir **une** définition machine.

**Tranchage** : les clés + la garde vivent **sur `ZSyncMeta` lui-même**, en **membres statiques** — pas en nouveaux types top-level :

```dart
// packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart  (AJOUTS à la classe existante)
class ZSyncMeta {
  /// Clé snake_case de l'horodatage LWW (AD-9) — **hors-entité**.
  static const String kUpdatedAt = 'updated_at';

  /// Clé snake_case du drapeau de soft-delete (AD-9/AD-16) — **hors-entité**.
  static const String kIsDeleted = 'is_deleted';

  /// Clés **RÉSERVÉES** à la couche de sync (AD-19). Une entité ne les capture
  /// JAMAIS dans `extra` et ne les réémet JAMAIS depuis son `toMap`/`toJson` :
  /// elles appartiennent au store, pas au domaine métier.
  static const Set<String> reservedKeys = <String>{kUpdatedAt, kIsDeleted};

  /// Retire les [reservedKeys] de [map] (helper de garde AD-19, pur, défensif).
  static Map<String, dynamic> stripReserved(Map<String, dynamic> map) => ...;
  // … reste de la classe INCHANGÉ (fromJson/toJson/copyWith/==/hashCode)
}
```

- **Zéro nouveau symbole top-level** ⇒ zéro impact sur le garde de surface, zéro impact sur les barrels.
- `fromJson`/`toJson` existants **doivent** être réécrits pour consommer `kUpdatedAt`/`kIsDeleted` (aujourd'hui littéraux `'updated_at'`/`'is_deleted'` l. 38-39, 51-52) — **strictement iso-comportement**.
- **HORS PÉRIMÈTRE** : le refactor des constantes privées `_kUpdatedAt`/`_kIsDeleted` des adapters `zcrud_firestore` (`hive_z_local_store.dart`, `firebase_z_repository_impl.dart`) et des copies de `zcrud_mindmap`. Toucher `zcrud_firestore` élargirait le rayon d'explosion sans servir un AC. → **Dette consignée** (cf. § Dette).

### D4 — Le **défaut réel** à corriger : `is_deleted` fuit dans `extra` (bug latent, non testé)

`ZStudyFolder._reservedKeys` (`z_study_folder.dart:287-290`) = `{noms des ZFieldSpec générés} ∪ {'extension'}`. Les specs générés sont (`z_study_folder.g.dart:173-193`) : `id, title, color_key, parent_id, owner_id, archived_at, created_at, updated_at, is_public, shared_with, can_be_joined_with_link, co_workers_can_invite_others, share_id`.

⇒ **`is_deleted` n'y est PAS.** Or les stores écrivent **toujours** `is_deleted` dans le corps et passent la map **complète** à `fromMap`. Donc, aujourd'hui :

```
store.getById(id)  →  fromMap({..., updated_at: X, is_deleted: false})
                   →  extra == {'is_deleted': false}      ← POLLUTION
                   →  toMap() réémet 'is_deleted'          ← FUITE d'une préoccupation de store dans le domaine
                   →  f1 == f2 devient FAUX entre une entité construite en mémoire et la même relue du store
```

Le test existant `z_study_folder_test.dart:28-29` (`expect(map.containsKey('is_deleted'), isFalse)`) **ne détecte rien** : il ne teste que le `toMap()` d'un dossier **construit en mémoire**, jamais un round-trip depuis une map de store.

**Le même défaut existe sur `ZFlashcard`** (`packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart:311-315` : `_reservedKeys` = specs ∪ `{'source','extension'}` — pas de `is_deleted`).

**Correction (les deux entités)** : ajouter `...ZSyncMeta.reservedKeys` à `_reservedKeys`.
**Ce n'est PAS une perte de données** : `is_deleted` appartient au store, qui le **réécrit à chaque `put`** (`hive_z_local_store.dart:186`) et le **préserve verbatim** sur la voie de sync (`ZSyncEntry`/`applyMerged`). Le retirer d'`extra` **restaure** l'invariant AD-16 (« soft-delete hors-entité ») au lieu de le contourner.

### D5 — `ZStudyFolder.updatedAt` : **miroir de compat DÉPRÉCIÉ**, jamais l'autorité de merge

```dart
/// **MIROIR DE COMPATIBILITÉ — DÉPRÉCIÉ (AD-19).**
///
/// L'autorité de merge Last-Write-Wins est **exclusivement** `ZSyncMeta.updatedAt`
/// (hors-entité). Ce champ est **maintenu par l'adapter** (collision de clé
/// `updated_at` : le store réécrit la clé à chaque `put` et la relit dans
/// `fromMap`), UNIQUEMENT pour que les lectures **legacy** — documents écrits
/// avant AD-19 et consommateurs existants (DODLP/IFFD) — restent valides
/// (AD-10, évolution additive). **NE JAMAIS** l'utiliser pour décider d'un merge,
/// d'un tri de sync ou d'une résolution de conflit.
@Deprecated(
  'Miroir de compat (AD-19). Autorité de merge = ZSyncMeta.updatedAt (hors-entité). '
  'Ne jamais lire ce champ pour un merge/tri de sync.',
)
@ZcrudField()
final DateTime? updatedAt;
```

**Sûreté du gate `analyze` — VÉRIFIÉE EMPIRIQUEMENT (sonde `dart analyze` réelle, pas raisonnée)** :
- usage **dans la même librairie** que la déclaration → **aucun diagnostic** ;
- usage **cross-package** (tests `zcrud_flashcard` → `ZStudyFolder` du kernel) → `deprecated_member_use` de sévérité **`info`** ;
- `melos run analyze` exécute `dart analyze .` **sans `--fatal-infos`** (`melos.yaml:30-32`) et la CI l'appelle tel quel (`.github/workflows/ci.yml:42-43`) → les infos **ne sont PAS fatales** → **RC=0 préservé**.
- ⚠️ Les `*.g.dart` sont **exclus de l'analyse** (`analysis_options.yaml`, `exclude: **/*.g.dart`) : le code généré qui construit `ZStudyFolder(updatedAt: …)` ne produit **aucun** diagnostic.
- **Hygiène** : sur les sites de test qui exercent **volontairement** le miroir legacy, ajouter `// ignore: deprecated_member_use` (précédent : `packages/zcrud_mindmap/test/z_mindmap_view_test.dart:391`). Objectif : sortie CI propre + intention explicite.

**`ZFlashcard.updatedAt`** : **même statut de miroir**, mais **PAS de `@Deprecated` en ES-1.3**. AD-19 ne le prescrit pas et sa surface E9 est consommée par la migration DODLP en cours. → **dartdoc de miroir** ajouté + **divergence résiduelle DOCUMENTÉE** dans AD-19 (jamais laissée implicite). La correction `_reservedKeys` (D4), elle, **s'applique bien** à `ZFlashcard`.

---

## Acceptance Criteria

### AC1 — Convention consignée : AD-19 matérialisé dans la doc d'architecture + memlog

- `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md` § **AD-19** est **enrichi** d'une sous-section normative reprenant **textuellement** la règle :
  > « Toute **nouvelle** entité study porte `updated_at` + `is_deleted` **hors-entité** via `ZSyncMeta`. Le merge LWW se fait **TOUJOURS** sur `ZSyncMeta.updated_at`, **JAMAIS** sur un `T.updatedAt` interne. »
- La sous-section **liste nommément** les entités ES-2 concernées (`ZStudyDocument`, `ZSmartNote`, `ZExam`, `ZFlashcardTag`, `ZDocumentAnnotation`, `ZStudyPodcast`, entités de partage) et **désigne `ZRepetitionInfo` comme exemplaire de référence** (zéro `updatedAt` interne).
- Elle **documente explicitement la divergence résiduelle** (cf. AC5).
- `architecture-zcrud-study-2026-07-12/.memlog.md` porte une entrée datée ES-1.3 tranchant **OQ #3 / OQ-S2**.

### AC2 — Le merge LWW ne lit JAMAIS `T.updatedAt` — **prouvé par un test qui casse si on l'y rebranche**

- Un test **adversarial** construit deux `ZSyncEntry<ZStudyFolder>` dont le **miroir d'entité CONTREDIT la méta** :
  - `local` : `entity.updatedAt = 2030-01-01` (miroir très récent, **mensonger**), `meta.updatedAt = 2020-01-01` ;
  - `remote` : `entity.updatedAt = 1990-01-01` (miroir très ancien), `meta.updatedAt = 2026-01-01`.
- `const ZLwwResolver().resolve(local, remote)` retourne **`ZLwwAction.adoptRemoteIntoLocal`** (la **méta** gagne), **jamais** `pushLocalToRemote`.
- Le cas **symétrique** (méta locale plus récente, miroir local plus ancien) retourne **`pushLocalToRemote`**.
- Le test porte un dartdoc explicite : *« si ce test tombe, quelqu'un a rebranché le merge sur `T.updatedAt` — AD-19 est violé »*.

### AC3 — Clés de sync **réservées** : `ZSyncMeta.kUpdatedAt` / `kIsDeleted` / `reservedKeys` / `stripReserved`

- `ZSyncMeta` expose les **statiques** de D3. `fromJson`/`toJson` les consomment (plus aucun littéral `'updated_at'`/`'is_deleted'` dans le fichier).
- **Iso-comportement strict** : les 905+ tests de `zcrud_core` (dont `test/domain/z_sync_meta_test.dart`) passent **sans modification** de leurs attentes.
- `stripReserved` est **pure et défensive** : map vide → map vide ; map sans clé réservée → copie égale ; ne mute **jamais** l'entrée.
- **Aucun nouveau symbole top-level public** n'est ajouté à `zcrud_core` (uniquement des membres statiques sur une classe existante).

### AC4 — `is_deleted` ne pollue plus `extra` (`ZStudyFolder` **et** `ZFlashcard`)

- `ZStudyFolder.fromMap({... 'updated_at': X, 'is_deleted': true, 'related_topics': [...]})` :
  - `extra` **ne contient NI `is_deleted` NI `updated_at`** ;
  - `extra` **contient toujours** `related_topics` (round-trip AD-4 **non régressé**) ;
  - `toMap()` **n'émet aucune clé `is_deleted`** (AC5 d'E9-3 préservée, désormais **réellement** testée) ;
  - `fromMap(toMap(f)).extra == f.extra` (convergence).
- **Idem pour `ZFlashcard.fromMap`** (même correction, même test).
- **Aucun throw** sur une map corrompue (`is_deleted: 'oui'`, `updated_at: 42`) — AD-10.

### AC5 — Miroir de compat déprécié + divergence résiduelle **documentée, jamais implicite**

- `ZStudyFolder.updatedAt` porte `@Deprecated(...)` + le dartdoc de D5.
- **Round-trip legacy prouvé** : une map **legacy** (`updated_at` présent dans le corps, **`is_deleted` absent**, clés inconnues présentes) reste **entièrement lisible** — miroir peuplé, `extra` préservé, aucun crash (AD-10, évolution **additive seulement**). **Aucune donnée existante ne devient illisible.**
- La divergence résiduelle est écrite **noir sur blanc** dans AD-19 :
  1. le miroir n'est pas un champ distinct — c'est **la même clé persistée `updated_at`** : il est maintenu **par collision de clé**, l'adapter l'écrasant à chaque `put` (donc toujours convergent avec la méta) ;
  2. `ZStudyFolder.toMap()` **émet** `updated_at` (valeur potentiellement périmée) — **sans effet** : `_encode` du store l'**écrase inconditionnellement** par l'estampille `ZSyncMeta` (prouvé par test, cf. AC5-bis) ;
  3. `ZFlashcard.updatedAt` est un **miroir de même nature, NON déprécié en ES-1.3** (surface E9 consommée par DODLP) — dépréciation à re-statuer en ES-2/ES-11 ;
  4. `ZRepetitionInfo` **ne porte aucun** `updatedAt` : c'est **l'exemplaire cible** pour toutes les entités ES-2.
- **AC5-bis** : un test prouve que **le miroir n'a AUCUN pouvoir d'écriture** — un `ZStudyFolder` dont le miroir vaut `2030-01-01`, encodé par la voie de store, produit un `updated_at` **≠ 2030** (l'estampille du store gagne).

### AC6 — **Surface publique inchangée** : le garde ES-1.2/L4 reste vert **sans être modifié**

- `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart` passe **tel quel** — **ni** sa `_flashcardAllowlist`, **ni** la liste `hide` de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` ne sont modifiées.
- **Aucun** `export` ajouté au barrel `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart`.
- Le test de surface positive `packages/zcrud_flashcard/test/z_public_surface_test.dart` passe **sans modification**.
- ⚠️ Si le dev se retrouve à devoir toucher le `hide` ou l'allowlist, **c'est le signe qu'il a violé D1/D2/D3** (il a ajouté un symbole au kernel) → **revenir au design**, ne pas « réparer » le garde.

### AC7 — Vérif verte repo-wide + non-régression chiffrée (gate de commit, leçon `ZExportApi`)

- `melos run generate` OK (le `@Deprecated` **cohabite** avec `@ZcrudField` : `z_study_folder.g.dart` doit **toujours** émettre le spec `updated_at` — à vérifier **après** codegen).
- `melos run analyze` **REPO-WIDE** RC=0 (infos `deprecated_member_use` tolérées, **non fatales** — cf. D5).
- `melos run test` RC=0 avec les **planchers** : `zcrud_core` **≥ 905**, `zcrud_flashcard` **≥ 171**, `zcrud_study_kernel` **≥ 90** (VM).
- `melos run test:js` RC=0, `zcrud_study_kernel` **≥ 80** (node) — les nouveaux tests kernel doivent être **pur-Dart et JS-safe** (aucun `dart:io`, aucune dépendance Flutter).
- `melos run verify` **REPO-WIDE** RC=0 (`gate:graph` acyclique, `gate:secrets`, `verify:serialization`).

---

## Tasks / Subtasks

- [x] **T1 — `zcrud_core` : statiques de clés réservées sur `ZSyncMeta`** (AC3)
  - [x] `packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart` : ajouter `kUpdatedAt`, `kIsDeleted`, `reservedKeys`, `stripReserved` (**membres statiques** — aucun type top-level nouveau).
  - [x] Réécrire `fromJson` (l. 36-41) et `toJson` (l. 50-53) pour consommer les constantes (iso-comportement).
  - [x] Dartdoc : ces clés sont **la définition machine d'AD-19**.
  - [x] `packages/zcrud_core/test/domain/z_sync_meta_test.dart` : ajouter les cas `reservedKeys` / `stripReserved` (pureté, non-mutation, map vide, clés absentes). **Ne modifier aucune attente existante.**

- [x] **T2 — `zcrud_study_kernel` : `ZStudyFolder` aligné** (AC4, AC5)
  - [x] `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart` :
    - [x] `_reservedKeys` (l. 287-290) : ajouter `...ZSyncMeta.reservedKeys`.
    - [x] `updatedAt` (l. 160-162) : `@Deprecated(...)` + dartdoc « miroir de compat » (D5). **Conserver `@ZcrudField()`.**
    - [x] Dartdoc de tête (l. 30-33) : remplacer « divergence **assumée** … OQ #3 **non tranchée** » par la **résolution AD-19** (miroir déprécié, autorité = `ZSyncMeta`).
    - [x] `toMap()` (l. 197-211) : dartdoc — n'émet **jamais** `is_deleted` (désormais **garanti par `_reservedKeys`**, plus par chance).
  - [x] `melos run generate` : **vérifier** que `z_study_folder.g.dart` émet toujours `ZFieldSpec(name: 'updated_at', …)`.

- [x] **T3 — `zcrud_flashcard` : `ZFlashcard` aligné (même défaut `extra`)** (AC4, AC5-3)
  - [x] `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart` : `_reservedKeys` (l. 311-315) → ajouter `...ZSyncMeta.reservedKeys`.
  - [x] `updatedAt` (l. 189) : dartdoc **« miroir de compat, autorité = `ZSyncMeta` »** — **SANS** `@Deprecated` (D5).

- [x] **T4 — Test STAR : le merge LWW ignore le miroir** (AC2)
  - [x] Créer `packages/zcrud_study_kernel/test/z_sync_meta_authority_test.dart` (pur-Dart, JS-safe).
  - [x] Cas « miroir mensonger » local & remote (D5/AC2), cas symétrique, cas `meta.updatedAt == null` des deux côtés (le miroir **ne départage rien**).
  - [x] Dartdoc d'alerte : *« ce test tombe ⇒ AD-19 violé »*.

- [x] **T5 — Tests de garde des clés réservées + round-trip legacy** (AC4, AC5)
  - [x] `packages/zcrud_study_kernel/test/z_study_folder_test.dart` : groupe **« AD-19 — clés de sync hors-entité »** — `extra` sans `is_deleted`/`updated_at` ; `related_topics` préservé ; `toMap()` sans `is_deleted` ; **round-trip legacy** (map sans `is_deleted`) lisible ; map corrompue → aucun throw.
  - [x] Idem dans `packages/zcrud_flashcard/test/z_study_folder_test.dart` (le miroir de tests du kernel — **le garder synchrone**) et `packages/zcrud_flashcard/test/z_flashcard_test.dart` (pour `ZFlashcard`).
  - [x] **AC5-bis** : test prouvant que l'estampille du store **écrase** le miroir (simuler l'`_encode` : `{...folder.toMap(), 'updated_at': storeStamp}` → la valeur du store gagne ; le miroir `2030` n'a aucun pouvoir).
  - [x] Ajouter `// ignore: deprecated_member_use` sur les sites de test **cross-package** lisant volontairement le miroir.

- [x] **T6 — Garde de surface : vérifier, ne PAS modifier** (AC6)
  - [x] Exécuter `z_kernel_surface_guard_test.dart` + `z_public_surface_test.dart` : **verts sans modification**.
  - [x] Vérifier par `git diff` : **aucun** changement dans `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart` ni dans le bloc `export … hide …` de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart`.

- [x] **T7 — Documentation : AD-19 + memlog** (AC1, AC5)
  - [x] `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md` § AD-19 (l. 99-102) : ajouter la sous-section normative + **les 4 divergences résiduelles** d'AC5 + le pointeur code (`ZSyncMeta.reservedKeys` = définition machine).
  - [x] `.memlog.md` du même dossier : entrée ES-1.3 (tranche **OQ #3 / OQ-S2**).
  - [x] Consigner la **dette DW-ES13-1** (cf. § Dette).

- [x] **T8 — Vérif verte repo-wide** (AC7)
  - [x] `melos run generate` → `melos run analyze` → `melos run test` → `melos run test:js` → `melos run verify`, **tous RC=0**, planchers de tests tenus.

---

## Dev Notes

### Invariants applicables (rappel — non négociables)

- **AD-1** : le kernel ne dépend **que** de `zcrud_core` + `zcrud_annotations`. `packages/zcrud_study_kernel/test/z_kernel_resolution_test.dart` et `z_kernel_purity_test.dart` figent cette fermeture — **ne pas la casser** (aucun nouvel import).
- **AD-5 / NFR-S3** : aucun type backend dans le domaine. `ZSyncMeta` reste ISO-8601 + snake_case, jamais `Timestamp`.
- **AD-10 / SM-S6** : **évolution additive seulement**. Aucun champ supprimé, aucun renommage, aucune migration. Une donnée écrite avant ES-1.3 **doit** rester lisible (testé, AC5).
- **AD-4** : `extra` reste l'échappatoire des clés **inconnues du domaine** — les clés de sync ne sont **pas** inconnues : elles appartiennent au **store**. Les en retirer n'est pas une perte, c'est une **correction de couche**.
- **AD-11** : aucun `try-catch` nu ; rien de nouveau côté repository ici.

### Pièges identifiés (anti-régression)

1. **Ne PAS créer `z_sync_meta.dart` dans le kernel** (D1). L'epic le suggérait « si absent » — il est présent.
2. **Ne PAS réexporter `ZSyncMeta` depuis le barrel kernel** (D2) : fuite garantie dans `zcrud_flashcard`.
3. **`@Deprecated` + `@ZcrudField` doivent coexister** : après `melos run generate`, **vérifier** que le spec `updated_at` est toujours émis dans `z_study_folder.g.dart`. Si le générateur skippait un membre déprécié, `_reservedKeys` perdrait `updated_at` → régression silencieuse (l'entité capturerait `updated_at` dans `extra`). **Vérification obligatoire, pas une hypothèse.**
4. **`melos analyze` reste vert** : `deprecated_member_use` est **info**, non fatal (sonde réelle, D5). Ne **jamais** « corriger » cela en supprimant la dépréciation.
5. **Deux copies du test `z_study_folder_test.dart`** existent (kernel + flashcard, héritage ES-1.1) : les faire évoluer **ensemble**, sinon la suite flashcard casse.
6. **Les tests kernel tournent aussi sous `dart test -p node`** (`melos run test:js`) : le test STAR doit être **pur-Dart** — aucun `dart:io`, aucun `flutter_test`.
7. **`ZSyncEntry.updatedAt` est un getter dérivé de `meta`** — le test STAR doit bien passer par `ZSyncEntry(entity: …, meta: …)`, en s'assurant que `entity.updatedAt` ≠ `meta.updatedAt` (c'est **tout** le pouvoir discriminant du test).
8. **`_reservedKeys` de `ZStudyFolder` est `static final`** (dérivé de `$ZStudyFolderFieldSpecs`) : le spread `...ZSyncMeta.reservedKeys` y est légal. Ne pas le passer en `const`.
9. **🚫 NE PAS TOUCHER `packages/zcrud_flashcard/test/support/fakes.dart`.** Le fake store y maintient le miroir **par `copyWith(updatedAt: now)`** (l. 41-42) **en plus** de la méta (l. 45). C'est **volontaire** : il simule la collision de clé de l'adapter réel. Un dev qui « alignerait » le fake en retirant le `copyWith` **casserait** `z_flashcard_repository_test.dart:170` (`expect(card.updatedAt, isNotNull)`) — régression pure, **hors sujet**. Le fake reste **inchangé**.
10. **Ordre d'écriture dans `_encode` = la garantie d'AC5-bis.** `hive_z_local_store.dart:180-187` fait `map = Map.of(_toMap(value))` **PUIS** `map[_kUpdatedAt] = meta[...]` : l'estampille du store est écrite **APRÈS** le corps, donc elle **écrase** systématiquement le miroir. Le test AC5-bis doit reproduire **cet ordre** (`{...folder.toMap(), ZSyncMeta.kUpdatedAt: storeStamp}`) — le kernel ne pouvant pas dépendre de `zcrud_firestore` (AD-1), c'est une **simulation du contrat**, à annoter d'un commentaire pointant la ligne réelle.
11. **Ne JAMAIS éditer un `*.g.dart`** (gitignoré, régénéré). La seule action codegen autorisée est `melos run generate`.

### Dette consignée (à sortir de la story)

- **DW-ES13-1 (LOW)** — Les adapters `zcrud_firestore` (`hive_z_local_store.dart:122-126`, `firebase_z_repository_impl.dart:159-163`) et `zcrud_mindmap` (`z_mindmap.dart:68-72`, `z_mindmap_node.dart:83`) redéclarent **en dur** les clés `'updated_at'`/`'is_deleted'`. Après ES-1.3 elles ont une **définition machine unique** (`ZSyncMeta.kUpdatedAt`/`kIsDeleted`/`reservedKeys`) : ces 4 sites devraient l'adopter. **Hors périmètre ES-1.3** (élargirait le rayon d'explosion à `zcrud_firestore`/`zcrud_mindmap` sans servir un AC). À traiter en ES-1.4 (gates) ou en nettoyage d'ES-2.
- **DW-ES13-2 (LOW)** — Dépréciation formelle de `ZFlashcard.updatedAt` : reportée (surface E9 consommée par DODLP). À re-statuer en ES-2/ES-11.

### Intelligence de la story précédente (ES-1.2, `done`)

- Le code-review ES-1.2 a produit **0 HIGH, 4 MEDIUM (corrigés), 4 LOW** ; **L4** (« la règle de maintenance du `hide` n'est pas outillée — insuffisante pour **ES-1.3** ») a été soldé par la création du garde `z_kernel_surface_guard_test.dart`. **Cette story est le premier client de ce garde** : le design D1/D2/D3 (zéro nouveau symbole kernel) est précisément ce qui le fait rester vert **sans dérogation**.
- Leçon ES-1.2 : *« vérifier empiriquement, pas seulement raisonner »* (le déterminisme web a été prouvé par compilation dart2js réelle). Appliquée ici : la **sévérité de `deprecated_member_use`** a été prouvée par `dart analyze` réel, pas supposée.
- Leçon **`ZExportApi`** (CLAUDE.md) : la vérif **par package** ne détecte **pas** une régression cross-package. Cette story touche 3 packages → **`melos run analyze` + `melos run verify` REPO-WIDE obligatoires** avant `done`.

### Project Structure Notes

- **Aucun nouveau fichier de production.** 3 fichiers modifiés (`z_sync_meta.dart`, `z_study_folder.dart`, `z_flashcard.dart`) + 1 nouveau test kernel + tests étendus + 2 docs.
- Aucun barrel modifié. Aucune dépendance `pubspec` ajoutée. Graphe AD-1 inchangé (`gate:graph` doit rester vert **sans changement**).

### References

- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md#AD-19`] (l. 99-102) — règle à matérialiser ; § *Consistency Conventions* (l. 156) — « `ZSyncMeta` hors-entité **universel** ; merge LWW sur `ZSyncMeta.updated_at` ».
- [Source: `_bmad-output/planning-artifacts/epics/epics-zcrud-study-2026-07-12/epics.md#Story ES-1.3`] — ACs d'origine, taille M, séquentielle.
- [Source: `_bmad-output/planning-artifacts/prds/prd-zcrud-study-2026-07-12/prd.md#FR-S3`] (l. 136) — réconciliation OQ canonique #3.
- [Source: `packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart:20-79`] — `ZSyncMeta` **existant** (à étendre, jamais à dupliquer).
- [Source: `packages/zcrud_core/lib/src/domain/sync/z_lww_resolver.dart:86-125`] + [`z_sync_entry.dart:41`] — le merge lit **`meta.updatedAt`**, jamais `T.updatedAt`.
- [Source: `packages/zcrud_mindmap/lib/src/domain/z_mindmap.dart:68-72`] — précédent hors-entité `_reservedSyncKeys` (patron à généraliser).
- [Source: `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart:30-33, 160-162, 287-290`] — OQ #3 ouverte, champ miroir, `_reservedKeys` **incomplet**.
- [Source: `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart:189, 311-315`] — même défaut `_reservedKeys`.
- [Source: `packages/zcrud_firestore/lib/src/data/hive_z_local_store.dart:170-231`] + [`firebase_z_repository_impl.dart:226-240, 658-675`] — le store fusionne la méta dans le corps et passe la map **complète** à `fromMap`.
- [Source: `packages/zcrud_flashcard/lib/src/data/z_repetition_store.dart:12-22, 53-54`] — `ZRepetitionInfo` : **exemplaire** de la convention cible (zéro `updatedAt` interne).
- [Source: `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart:1-24, 34-43`] — garde L4 (nomme explicitement ES-1.3/`ZSyncMeta`).
- [Source: `melos.yaml:30-32, 42-44, 78-88`] + [`.github/workflows/ci.yml:42-43`] — `dart analyze` **sans `--fatal-infos`** ; gates `test:js` / `verify`.

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (skill `bmad-dev-story`).

### Debug Log References

| Commande (rejouée réellement) | RC | Résultat |
|---|---|---|
| `dart run melos bootstrap` | 0 | 15 packages bootstrapped |
| `dart run melos run generate` | 0 | SUCCESS (build_runner sur chaque package annoté) |
| **Inspection `z_study_folder.g.dart`** | — | `ZFieldSpec(name: 'updated_at', type: EditionFieldType.dateTime)` **toujours émis** (l. 185) ; **13 specs** (inchangé) ⇒ `@Deprecated` + `@ZcrudField` **coexistent**, aucune régression silencieuse de `_reservedKeys` |
| `dart run melos run analyze` (REPO-WIDE) | 0 | **« No issues found! » sur les 15 packages** (aucun `deprecated_member_use` résiduel : `// ignore` posés sur les sites de test cross-package) |
| `dart test packages/zcrud_study_kernel` (VM) | 0 | **102 tests** (plancher ≥ 90) |
| `dart test -p node packages/zcrud_study_kernel` (JS) | 0 | **92 tests** (plancher ≥ 80) — test STAR pur-Dart/JS-safe |
| `flutter test packages/zcrud_flashcard` | 0 | **180 tests** (plancher ≥ 171) |
| `flutter test packages/zcrud_core` | 0 | **911 tests** (plancher ≥ 905) |
| `python3 scripts/dev/graph_proof.py` | 0 | ACYCLIQUE OK ; `out-degree(zcrud_core) = 0` ; 23 arêtes, 15 nœuds (**inchangé**) |
| `dart run melos run verify` (REPO-WIDE) | 0 | `gate:graph`, `gate:melos`, `gate:reflectable`, `gate:secrets`, `gate:codegen`, `gate:compat`, `gate:web` (92 tests node), `verify:serialization` — **tous verts** |

### Completion Notes List

- **D1 appliqué** — `ZSyncMeta` **réutilisé** depuis `zcrud_core` : **aucun** `z_sync_meta.dart` créé dans le kernel, **aucun réexport**. Justification : (1) AD-1/source unique — le kernel dépend déjà de `zcrud_core`, un réexport créerait deux chemins d'import pour un même symbole ; (2) `zcrud_flashcard` réexporte **en bloc** le barrel kernel (`export … hide …`) — réexporter `ZSyncMeta` le ferait **fuiter** dans sa surface publique.
- **D3 appliqué — ZÉRO nouveau symbole public top-level** : les clés réservées sont des **membres statiques** de la classe existante `ZSyncMeta` (`kUpdatedAt`, `kIsDeleted`, `reservedKeys`, `stripReserved`). `fromJson`/`toJson` les consomment (plus aucun littéral `'updated_at'`/`'is_deleted'` dans le fichier), **iso-comportement** (les tests `zcrud_core` existants passent **sans modification** de leurs attentes).
- **AC6 — garde de surface VERT SANS DÉROGATION** : `z_kernel_surface_guard_test.dart` et `z_public_surface_test.dart` passent **tels quels**. **Ni** la liste `hide` de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart`, **ni** `_flashcardAllowlist`, **ni** le barrel `zcrud_study_kernel.dart` n'ont été touchés (vérifié par `git diff` : le seul diff du barrel flashcard est l'héritage **non committé d'ES-1.1/ES-1.2**, antérieur à cette story).
- **D4 — défaut latent CORRIGÉ (les deux entités)** : `_reservedKeys` de `ZStudyFolder` **et** de `ZFlashcard` omettaient `is_deleted`. Les stores écrivant `is_deleted` **dans le corps** puis passant la map **complète** à `fromMap`, la clé atterrissait dans `extra` et était **réémise** par `toMap()` (fuite d'une préoccupation de store dans le domaine, AD-16 ; `==` cassée entre une entité en mémoire et la même relue). Corrigé par `...ZSyncMeta.reservedKeys`. **Aucune perte de données** : `is_deleted` appartient au store (réécrit à chaque `put`, préservé verbatim sur la voie de sync via `ZSyncEntry`).
- **Piège n°1 LEVÉ EMPIRIQUEMENT** : après `melos run generate`, le `.g.dart` de `ZStudyFolder` émet **toujours** le spec `updated_at` (13 specs) — le générateur **ne skippe pas** un membre `@Deprecated`. Sans cela, `_reservedKeys` aurait perdu `updated_at` ⇒ capture dans `extra` (régression silencieuse).
- **Piège n°2 CONFIRMÉ** : `melos run analyze` reste **RC=0**. Mieux : « No issues found! » partout — les `// ignore: deprecated_member_use` posés sur les sites de test **cross-package** qui exercent volontairement le miroir legacy suppriment jusqu'aux `info`.
- **Piège n°3 RESPECTÉ** : `packages/zcrud_flashcard/test/support/fakes.dart` **NON touché** (le `copyWith(updatedAt: now)` y simule volontairement la collision de clé de l'adapter ; le retirer casserait `z_flashcard_repository_test.dart:170`).
- **Piège n°4 RESPECTÉ** : les **deux** copies de `z_study_folder_test.dart` (kernel + flashcard) ont évolué **ensemble** (groupe « AD-19 — clés de sync hors-entité » miroir des deux côtés).
- **Piège n°5 RESPECTÉ** : le test STAR est **pur-Dart / JS-safe** (aucun `dart:io`, aucun `flutter_test`) — rejoué vert sous `dart test -p node` (gate `test:js`).
- **AC2 — test STAR** (`z_sync_meta_authority_test.dart`) : miroirs **mensongers** contredisant frontalement la méta (local `2030`/méta `2020` vs remote `1990`/méta `2026`) ⇒ `adoptRemoteIntoLocal` (la **méta** gagne) ; cas symétrique ⇒ `pushLocalToRemote` ; métas `null` des deux côtés ⇒ le miroir **ne départage rien** ; tombstone porté par la méta. Un moteur lisant `T.updatedAt` prendrait **systématiquement la décision inverse** ⇒ le test n'a aucune zone d'ombre.
- **AC5-bis** : test prouvant que le miroir n'a **aucun pouvoir d'écriture** — l'ordre d'encodage du store (`{...folder.toMap(), ZSyncMeta.kUpdatedAt: storeStamp}`, reproduit de `hive_z_local_store.dart` `_encode`) **écrase** systématiquement le miroir `2030`.
- **AC1/AC5 — documentation** : `architecture.md` enrichi des sous-sections **AD-19.1** (règle normative textuelle + entités ES-2 nommées + `ZRepetitionInfo` exemplaire + table de la **définition machine**) et **AD-19.2** (les 5 divergences résiduelles). `.memlog.md` : entrée datée ES-1.3 tranchant **OQ #3 / OQ-S2**.
- **Dettes consignées (non traitées ici)** : **DW-ES13-1** (LOW) — 4 sites redéclarent les clés en dur (`zcrud_firestore` : `hive_z_local_store.dart`, `firebase_z_repository_impl.dart` ; `zcrud_mindmap` : `z_mindmap.dart`, `z_mindmap_node.dart`) et devraient adopter `ZSyncMeta.reservedKeys` → ES-1.4 / nettoyage ES-2. **DW-ES13-2** (LOW) — dépréciation formelle de `ZFlashcard.updatedAt` reportée (surface E9 consommée par DODLP) → à re-statuer en ES-2/ES-11.

### File List

**Modifiés (production)**
- `packages/zcrud_core/lib/src/domain/sync/z_sync_meta.dart` — statiques AD-19 (`kUpdatedAt`, `kIsDeleted`, `reservedKeys`, `stripReserved`) ; `fromJson`/`toJson` consomment les constantes.
- `packages/zcrud_study_kernel/lib/src/domain/z_study_folder.dart` — `_reservedKeys` ⊇ `ZSyncMeta.reservedKeys` ; `updatedAt` `@Deprecated` (miroir de compat) ; dartdoc de tête (OQ #3 **tranchée**) ; dartdoc `toMap()`.
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart` — `_reservedKeys` ⊇ `ZSyncMeta.reservedKeys` ; dartdoc « miroir de compat » sur `updatedAt` (**sans** `@Deprecated`, D5).

**Créés (tests)**
- `packages/zcrud_study_kernel/test/z_sync_meta_authority_test.dart` — **test STAR** AC2 (pur-Dart / JS-safe).

**Modifiés (tests)**
- `packages/zcrud_core/test/domain/z_sync_meta_test.dart` — groupe « clés réservées AD-19 » (pureté/non-mutation de `stripReserved`).
- `packages/zcrud_study_kernel/test/z_study_folder_test.dart` — groupe « AD-19 : clés de sync hors-entité » + round-trip legacy + AC5-bis.
- `packages/zcrud_flashcard/test/z_study_folder_test.dart` — miroir du groupe AD-19 (copies synchrones).
- `packages/zcrud_flashcard/test/z_flashcard_test.dart` — groupe « AD-19 : clés de sync hors-entité » (`ZFlashcard`).

**Modifiés (doc)**
- `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/architecture.md` — AD-19.1 / AD-19.2.
- `_bmad-output/planning-artifacts/architecture/architecture-zcrud-study-2026-07-12/.memlog.md` — entrée ES-1.3.

**NON touchés (invariants d'AC6, vérifié `git diff`)** : `packages/zcrud_study_kernel/lib/zcrud_study_kernel.dart`, la liste `hide` de `packages/zcrud_flashcard/lib/zcrud_flashcard.dart`, `packages/zcrud_flashcard/test/z_kernel_surface_guard_test.dart`, `packages/zcrud_flashcard/test/z_public_surface_test.dart`, `packages/zcrud_flashcard/test/support/fakes.dart`.

### Change Log

| Date | Changement |
|---|---|
| 2026-07-13 | ES-1.3 implémentée : AD-19 matérialisé (statiques `ZSyncMeta`), défaut `is_deleted`→`extra` corrigé sur `ZStudyFolder` **et** `ZFlashcard`, miroir `ZStudyFolder.updatedAt` déprécié, test STAR d'autorité de la méta, doc AD-19.1/AD-19.2 + memlog. Vérif verte repo-wide (analyze/test/test:js/verify RC=0). Statut → `review`. |
