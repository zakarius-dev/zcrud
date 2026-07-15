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
///   carte éphémère sans dossier cible → `Left(DomainFailure)`.
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
  /// **AVANT** [persist]. Un `Left(DomainFailure)` **BLOQUE** l'écriture (le
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
}
