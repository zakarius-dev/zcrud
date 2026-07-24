/// Port de **dépôt d'étude générique** (Story ES-3.1, FR-S12, AD-5/AD-11/AD-9/
/// AD-14/AD-1) — le contrat CRUD offline-first factorisé des ~15 repositories
/// quasi identiques de lex_core.
///
/// ## Le doublon factorisé (origine lex)
///
/// lex_core porte ~15 repositories redéclarant la MÊME forme :
/// `FlashcardsRepository`, `StudyFoldersRepository`, `RepetitionRepository`,
/// `SmartNotesRepository`, `MindmapsRepository`, `StudyDocumentsRepository`,
/// `ExamsRepository`, … Chacun expose un flux nu (`dataChanges` /
/// `foldersStream` / `repetitionsStream` / `cardsStream`), un `save`/`delete`/
/// `sync` en `Either<Failure,·>`, et **ré-inline** ses invariants métier dans
/// chaque `save*` (jamais factorisés). Exemples MESURÉS :
/// - `study_folders_repository_impl.dart:141-165` — « 2 niveaux max » : la
///   validation est écrite AVANT toute écriture Hive/Firestore, un `Left`
///   court-circuite l'écriture ;
/// - `flashcards_repository.dart:14-20` — matérialisation de l'éphémère : une
///   carte éphémère sans dossier cible → `Left(ZDomainFailure)`.
///
/// ## Ce que ce port AJOUTE (et ce qu'il n'ajoute PAS)
///
/// [ZStudyRepository] **COMPOSE** avec [ZSyncableRepository] (AD-4 : composer,
/// pas dupliquer) : il n'ajoute **qu'une** chose au-dessus du sur-port de
/// `zcrud_core` — le **hook de validation métier par override** ([validate]),
/// **garanti d'être exécuté avant toute persistance** par un patron
/// **Template Method** ([save]). Tout le reste est **hérité, non redéclaré** :
/// - les flux `watchAll()` / `watch()` restent des `Stream<List<T>>` **NUS**
///   (AD-11). `watchAll()` **EST** le `dataChanges`/`foldersStream`/… canonique
///   des ~15 repos lex — unifiés (dartdoc `z_repository.dart`) : **aucun getter
///   `dataChanges` redondant n'est ajouté** (le dupliquer violerait AD-4) ;
/// - `getAll`/`getById`/`softDelete`/`restore`/`count`/`sync`/`dispose`
///   retournent leurs `ZResult<·>` hérités inchangés ;
/// - `sync()` reste best-effort (AD-9 : `Right(unit)` si déconnecté).
///
/// ## Template Method — le hook n'est PAS décoratif (R12, contre-mesure D1/D2)
///
/// Le port n'expose **pas un hook nu** que rien n'obligerait [save] à appeler
/// (ce serait un hook décoratif ignorable — le jumeau du test AC13 *powerless*
/// d'ES-2.5). À la place : [save] est **concret** et appelle [validate] PUIS,
/// **seulement si `Right`**, l'écriture protégée [persist]. Un override de
/// [validate] qui renvoie `Left` **empêche mécaniquement** l'appel à [persist]
/// — prouvable dans le kernel SANS aucun store (fake `persist`-espion).
///
/// ## Backend-agnostique (AD-5/AD-11 · NFR-S3/SM-S5)
///
/// Ce port ne référence **aucun** type `cloud_firestore`/Hive/Flutter
/// (`Timestamp`/`Filter`/`Box`/`WriteBatch`/`Color`…). La traduction
/// `ZDataRequest → Filter`, le curseur concret, le `Box`, le `WriteBatch` et le
/// décodage contextualisé (`ZcrudRegistry`/`ZDecodeContext`, ES-3.0) vivent dans
/// l'**adaptateur offline-first** (ES-3.2, `zcrud_firestore`) — jamais ici. Le
/// port **admet** le contrat offline-first (store local source de vérité, merge
/// LWW sur `updatedAt` hors-entité, soft-delete `is_deleted`) via les membres
/// hérités, sans **décider** aucune topologie.
library;

import 'package:meta/meta.dart';
import 'package:zcrud_core/domain.dart';

/// Contrat **abstrait** (port) d'un dépôt d'agrégat d'étude [T], **offline-first
/// et synchronisable**, doté d'un **hook de validation métier par override**
/// garanti d'être exécuté avant toute persistance.
///
/// Générique sur [ZEntity] (AD-4 : generics autorisés pour un **PORT** — pas
/// pour la sérialisation) ; `abstract class` (jamais `sealed` : extension
/// inter-package, AD-4). Vit dans `zcrud_study_kernel` (spécialisation *étude*
/// du générique `ZSyncableRepository` du cœur) : le kernel ne gagne **aucune**
/// arête sortante (AD-1/AD-17 — CORE OUT=0, acyclicité préservée).
abstract class ZStudyRepository<T extends ZEntity>
    extends ZSyncableRepository<T> {
  /// Hook métier **OVERRIDABLE** — le point d'accroche factorisé des invariants
  /// que lex ré-inline dans chaque `save*` (2 niveaux max, matérialisation de
  /// l'éphémère, cible requise, AD-14).
  ///
  /// **Contrat** : PUR, TOTAL, déterministe — **aucune** I/O, aucun
  /// `DateTime.now()`, **jamais** d'exception (AD-10). Appelé par [save]
  /// **AVANT** [persist]. Un `Left(ZDomainFailure)` **BLOQUE** l'écriture (le
  /// rejet remonte tel quel) ; un `Right(unit)` la laisse passer.
  ///
  /// **Défaut** = no-op succès (`Right(unit)`) : un dépôt sans invariant métier
  /// persiste toujours. Une sous-classe (adapter ES-3.2, ou fixture de test)
  /// **override** cette méthode pour brancher SA règle.
  ///
  /// Retourne `ZResult<Unit>` (`Either<ZFailure, Unit>`) par cohérence avec
  /// [save]/[softDelete] (AD-11), jamais un `Stream` enveloppé.
  ZResult<Unit> validate(T item) => const Right<ZFailure, Unit>(unit);

  /// Écriture protégée **réelle** (store local / merge LWW / propagation
  /// distante) — **point d'extension abstrait** implémenté par l'adaptateur
  /// offline-first (ES-3.2, `zcrud_firestore`), **jamais** ici.
  ///
  /// C'est [persist] (et non [save]) qui **matérialise l'éphémère**
  /// (`item.isEphemeral` → attribution d'un `id` opaque) et **thread** le
  /// [collectionId]. **JAMAIS appelé si [validate] renvoie `Left`** (garanti
  /// par le Template Method [save]).
  ///
  /// `@protected` : hors de la surface publique consommateur (on persiste via
  /// [save], jamais en appelant [persist] directement).
  @protected
  Future<ZResult<T>> persist(T item, {String? collectionId});

  /// Écriture protégée **PRÉSERVANTE** (CR-LEX-34) — point d'extension du
  /// Template Method [saveMerging]. Fusionne [item] par-dessus l'existant au
  /// lieu de l'écraser : voir [saveMerging] pour la sémantique et sa limite.
  ///
  /// **Défaut** : `Left(ZDomainFailure)` — un dépôt dont le backend ne sait pas
  /// fusionner au niveau du document le dit **explicitement**, exactement comme
  /// [listParentIds]. Jamais un repli silencieux sur [persist], qui rouvrirait
  /// la destruction invisible que ce membre élimine. L'adaptateur offline-first
  /// (ES-3.2) l'**override**.
  @protected
  Future<ZResult<T>> persistMerging(T item, {String? collectionId}) async =>
      Left<ZFailure, T>(
        const ZDomainFailure(
          'saveMerging() n\'est pas supporté par ce dépôt : son backend ne sait '
          'pas fusionner au niveau du document. Un Left explicite, jamais une '
          'écriture écrasante silencieuse.',
        ),
      );

  /// Énumère les identifiants des **parents** existants côté distant, pour une
  /// topologie *folder-scopée* (CR-LEX-10, remonté au PORT par CR-LEX-15).
  ///
  /// ## Pourquoi ce membre appartient au CONTRAT, pas à l'implémentation
  ///
  /// Livré d'abord sur l'adaptateur Firestore, il était **statiquement
  /// inatteignable** : les fabriques rendent le port neutre `ZStudyRepository<T>`,
  /// jamais le type concret. La seule voie était un `as ZOfflineFirstBoxRepository`
  /// — c'est-à-dire renoncer à l'abstraction que AD-5/AD-11 protègent, pour une
  /// opération qui relève précisément du repository.
  ///
  /// ## Contrat
  ///
  /// Un dépôt figé sur un unique parent ne couvre que celui-ci : sans cette
  /// énumération, un hôte multi-dossiers doit **deviner** la liste avant de
  /// construire ses dépôts, et sa seule source est le store **local** — donc
  /// **rien** sur un appareil neuf. `sync()` rendait alors `Right(unit)` sur une
  /// liste vide : un **succès silencieux** indiscernable de « l'utilisateur n'a
  /// rien ».
  ///
  /// **Défaut** : `Left(ZDomainFailure)` — un dépôt dont la topologie n'a pas de
  /// parent (flat, global) ou qui n'implémente pas la découverte le dit
  /// **explicitement**. Jamais une liste vide, qui serait exactement le mode
  /// dégradé silencieux que ce membre existe pour éliminer.
  Future<ZResult<List<String>>> listParentIds() async =>
      Left<ZFailure, List<String>>(
        const ZDomainFailure(
          'listParentIds() n\'est pas supporté par ce dépôt : la topologie n\'a '
          'pas de parent à énumérer, ou la découverte n\'est pas implémentée. '
          'Un Left explicite, jamais une liste vide silencieuse.',
        ),
      );

  /// **Template Method** (concret, non destiné à être ré-overridé) : valide
  /// [item] via [validate] PUIS, **seulement si `Right`**, persiste via
  /// [persist]. Un `validate → Left` court-circuite l'écriture et remonte le
  /// rejet **inchangé** ; un `validate → Right` délègue à [persist] en threadant
  /// [collectionId] tel quel, et remonte son `ZResult<T>` inchangé.
  ///
  /// Override de la méthode abstraite héritée de `ZRepository.save` : la
  /// signature (`{String? collectionId}`) matche exactement.
  ///
  /// `@nonVirtual` (code-review ES-3.1, M1) : le contrat « non ré-overridable »
  /// n'est PAS qu'un vœu dartdoc — l'analyzer REJETTE
  /// (`invalid_override_of_non_virtual_member`) toute sous-classe qui
  /// re-définirait [save] pour court-circuiter [validate] (réintroduisant le
  /// hook décoratif que ce port éradique). Les seuls points d'extension sont
  /// [validate] (métier) et [persist] (écriture).
  @override
  @nonVirtual
  Future<ZResult<T>> save(T item, {String? collectionId}) =>
      validate(item).fold(
        (failure) => Future<ZResult<T>>.value(Left<ZFailure, T>(failure)),
        (_) => persist(item, collectionId: collectionId),
      );

  /// Lit toutes les entités **appariées à leur [ZSyncMeta]** — `updatedAt` /
  /// `isDeleted` — **depuis le PORT** (CR-LEX-26).
  ///
  /// ## Le manque exact
  ///
  /// La méta de synchronisation est **hors-entité** (AD-19) : elle n'est pas
  /// dans le corps métier, et n'était lisible que via `ZLocalStore.syncEntries`
  /// — c'est-à-dire le **store**, pas le port. Un hôte dont l'entité expose
  /// `updatedAt`/`isDeleted` devait donc **court-circuiter** `ZStudyRepository`
  /// et atteindre le store directement, ou réécrire un accès parallèle. Le même
  /// contournement a été réécrit **cinq fois** chez un consommateur — le signal
  /// qu'il manquait au contrat, pas à l'hôte.
  ///
  /// ## Contrat
  ///
  /// **Inclut les tombstones** (`isDeleted: true`), contrairement à [getAll] qui
  /// les exclut : c'est tout l'intérêt — savoir qu'une entité est supprimée, et
  /// depuis quand, EST l'information demandée. Un dépôt vide rend `Right([])`.
  ///
  /// **Défaut** : `Left(ZDomainFailure)` — un dépôt sans couche de sync le dit
  /// explicitement, comme [listParentIds]. Jamais une liste vide, qui serait
  /// indiscernable de « l'utilisateur n'a rien ».
  Future<ZResult<List<ZSyncEntry<T>>>> getAllWithMeta() async =>
      Left<ZFailure, List<ZSyncEntry<T>>>(
        const ZDomainFailure(
          'getAllWithMeta() n\'est pas supporté par ce dépôt : il n\'a pas de '
          'couche de synchronisation exposant ZSyncMeta. Un Left explicite, '
          'jamais une liste vide silencieuse.',
        ),
      );

  /// **Suppression qui PROPAGE puis PURGE** (CR-LEX-35, demande révisée) :
  /// retire physiquement l'entrée **locale** (le cache ne croît pas) **ET**
  /// propage un **tombstone** au distant (la suppression se synchronise).
  ///
  /// ## Le manque exact que ce membre comble
  ///
  /// Aucune des deux primitives existantes ne couvrait le besoin — il est
  /// **entre les deux** :
  ///
  /// | Primitive | cache ne croît pas | propage le tombstone |
  /// |---|---|---|
  /// | [softDelete] | ❌ (tombstone local conservé) | ✅ |
  /// | `ZLocalStore.purge` | ✅ | ❌ — **résurrection au `sync()`** |
  /// | **ce membre** | ✅ | ✅ |
  ///
  /// ⚠️ **`ZLocalStore.purge` seul est un piège** pour une suppression qui doit
  /// se synchroniser : il retire l'entrée locale sans laisser de tombstone, donc
  /// un autre appareil **ressuscite** le document au prochain `sync()`. Un
  /// `softDelete`-puis-`purge` **ne sauve pas** la propagation : le push du
  /// `softDelete` est fire-and-forget et **relit** l'entrée locale — une purge
  /// awaitée la retire avant cette relecture, et le tombstone n'est jamais émis.
  /// L'ordre correct (propager, **attendre**, puis purger) est précisément ce que
  /// cette opération encapsule.
  ///
  /// **Défaut** : `Left(ZDomainFailure)` — un dépôt sans couche distante le dit
  /// explicitement, comme [listParentIds] et [persistMerging]. Jamais un repli
  /// silencieux sur une purge non propagée, qui serait le piège lui-même.
  Future<ZResult<Unit>> purgeLocalPropagatingTombstone(String id) async =>
      Left<ZFailure, Unit>(
        const ZDomainFailure(
          'purgeLocalPropagatingTombstone() n\'est pas supporté par ce dépôt : '
          'il n\'a pas de couche distante où propager un tombstone. Un Left '
          'explicite, jamais une purge locale non propagée (résurrection).',
        ),
      );

  /// **Template Method PRÉSERVANT** (CR-LEX-34) : comme [save] — valide via
  /// [validate] PUIS, seulement si `Right`, écrit — mais l'écriture **fusionne**
  /// [item] par-dessus l'existant ([persistMerging]) au lieu de l'**écraser**
  /// ([persist]).
  ///
  /// ## Le défaut que ce membre ferme
  ///
  /// [save] écrase le document en totalité. Un hôte dont l'entité ne mappe pas
  /// 100 % des champs `Z` **détruit silencieusement** ceux qu'il ignore — dont
  /// ceux écrits par un **autre hôte**, et les champs **hors-codegen**. Rien ne
  /// l'en avertit : le code compile, `analyze` est vert, aucun test de round-trip
  /// ne rougit (le harnais part d'une entité hôte, il ne peut donc jamais
  /// construire l'état « un `Z` déjà porteur est écrasé »). C'est le défaut payé
  /// **trois fois** (ZMindmap, ZExam, ZStudyDocument/Folder — CR-LEX-29/33).
  ///
  /// [saveMerging] déplace le « relire-fusionner » **dans le store**, une fois,
  /// au lieu de le laisser à la charge — donc à l'oubli — de chaque appelant.
  ///
  /// ## Sémantique et LIMITE assumée
  ///
  /// Les clés de [item] écrasent l'existant ; les clés présentes **uniquement**
  /// en base survivent. ⚠️ Le merge est **ADDITIF** : il ne peut pas EFFACER une
  /// clé — un champ que [item] omet (y compris un nullable remis à `null`, que
  /// `toMap` omet) est **préservé stale**. Pour un remplacement (donc un
  /// effacement possible), utiliser [save]. Le choix de la voie appartient à
  /// l'appelant, par appel.
  ///
  /// `@nonVirtual` (même raison que [save], code-review ES-3.1/M1) : la garantie
  /// « validate AVANT écriture » ne doit pas pouvoir être court-circuitée par un
  /// override. Les points d'extension restent [validate] et [persistMerging].
  @nonVirtual
  Future<ZResult<T>> saveMerging(T item, {String? collectionId}) =>
      validate(item).fold(
        (failure) => Future<ZResult<T>>.value(Left<ZFailure, T>(failure)),
        (_) => persistMerging(item, collectionId: collectionId),
      );
}
