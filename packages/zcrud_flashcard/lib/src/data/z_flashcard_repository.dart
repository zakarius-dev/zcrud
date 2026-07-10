/// Dépôt **offline-first** `ZFlashcardRepository` (Story E9-4) — coordinateur qui
/// compose, **par injection**, les **ports neutres** d'E5 pour la carte
/// (`ZSyncableRepository<ZFlashcard>`) et un canal SRS **séparé**
/// (`ZRepetitionStore`), et fait progresser l'état SRS par l'**unique** voie
/// `reviewCard() → ZSrsScheduler.apply` (AD-9).
///
/// **Invariant SRS top-level (AD-9, AC2/AC3)** : l'état `ZRepetitionInfo` est
/// persisté **exclusivement** via [ZRepetitionStore] (chemin logique top-level
/// `study_repetitions/{cardId}`), **jamais** dans le corps/`toMap` de la carte.
/// Le partage/duplication d'une carte n'emporte donc **jamais** l'historique SRS
/// d'autrui. Côté modèle l'invariant est déjà tenu (`ZFlashcard` ne porte aucun
/// champ SRS, E9-1) ; côté dépôt, [reviewCard]/[initRepetition] n'écrivent
/// **jamais** via [cards].
///
/// **Voie d'écriture SRS UNIQUE (AD-9, AC4)** : [reviewCard] est la **seule**
/// méthode publique produisant un état SRS **avancé** (délègue exactement à
/// `scheduler.apply`) ; [initRepetition] (état neuf, `scheduler.initial`) est le
/// **seul** autre write SRS. Aucune autre API publique n'écrit un état SRS.
///
/// **Isolation AD-1** : ce fichier n'importe **aucun** type backend
/// (Firestore/Hive/Firebase) ni le paquet adaptateur. La concrétude backend
/// offline-first (`ZOfflineFirstRepository<ZFlashcard>` d'E5, adaptateur
/// Hive/Firestore de [ZRepetitionStore]) est **injectée** typée sur les ports
/// neutres — jamais importée ici. `zcrud_flashcard` **ne tire jamais Firebase**.
///
/// **Contrat de résultat (AD-11)** : signatures publiques `ZResult<…>` /
/// `Stream<List<…>>` **nues** ; **aucun** `try-catch` nu (le seul `try/finally`
/// est la garde de ré-entrance de [sync], sans `catch`).
///
/// **Défensif (AD-10)** : un état SRS **absent** au chargement retombe sur
/// `scheduler.initial()` ([reviewCard] réussit sur une carte jamais révisée) ;
/// un état **corrompu** est reconstruit par `ZRepetitionInfo.fromMap` (dans le
/// store) — jamais de throw ; lectures `vide ≠ erreur`.
library;

// `prefer_initializing_formals` : FAUX POSITIF (champ privé exposé en paramètre
// nommé public — `this._cards` interdit par Dart). Désactivé au niveau fichier
// comme le dépôt offline-first d'E5 (`z_offline_first_repository.dart`).
// ignore_for_file: prefer_initializing_formals

import 'package:zcrud_core/domain.dart';

import '../domain/z_flashcard.dart';
import '../domain/z_repetition_info.dart';
import '../domain/z_sm2_scheduler.dart';
import '../domain/z_srs_scheduler.dart';
import 'z_repetition_store.dart';

/// Journal minimal **neutre** du dépôt flashcard (aucune dépendance backend).
///
/// Miroir de `ZOfflineFirstLog` (E5-3) : un drop de traduction requête→backend
/// (dette A2) ou un échec de sync best-effort (dette A1) est **loggé** ici —
/// jamais silencieux (AD-11). Défaut no-op.
typedef ZFlashcardRepositoryLog = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

void _noopLog(String message, {Object? error, StackTrace? stackTrace}) {}

/// Coordinateur offline-first des flashcards + de leur état SRS (canal séparé).
///
/// **Injection** (aucun singleton — testabilité, AC1) : un
/// [ZSyncableRepository]`<ZFlashcard>` (port carte E5, **local autoritaire +
/// distant best-effort**), un [ZRepetitionStore] (canal SRS séparé top-level),
/// un [ZSrsScheduler] (défaut `const ZSm2Scheduler()`), et un
/// [ZFlashcardRepositoryLog] optionnel (défaut no-op).
class ZFlashcardRepository {
  /// Construit le dépôt par **composition** des ports injectés.
  ZFlashcardRepository({
    required ZSyncableRepository<ZFlashcard> cards,
    required ZRepetitionStore repetitions,
    ZSrsScheduler scheduler = const ZSm2Scheduler(),
    ZFlashcardRepositoryLog? logger,
  })  : _cards = cards,
        _reps = repetitions,
        _scheduler = scheduler,
        _log = logger ?? _noopLog;

  final ZSyncableRepository<ZFlashcard> _cards;
  final ZRepetitionStore _reps;
  final ZSrsScheduler _scheduler;
  final ZFlashcardRepositoryLog _log;

  /// Garde de **ré-entrance** de [sync] (dette A3) : coalesce un cycle si un est
  /// déjà en vol.
  bool _syncing = false;

  // ─────────────────────────── Cartes (offline-first E5) ──────────────────────

  /// Flux temps réel **nu** des cartes non soft-deleted (délègue au port carte).
  Stream<List<ZFlashcard>> watchAll() => _cards.watchAll();

  /// Flux temps réel **nu** filtré/trié/paginé (délègue au port carte).
  Stream<List<ZFlashcard>> watch(ZDataRequest request) => _cards.watch(request);

  /// Lit toutes les cartes correspondant à [request] (exclut les soft-deleted).
  Future<ZResult<List<ZFlashcard>>> getAll({ZDataRequest? request}) =>
      _cards.getAll(request: request);

  /// Lit la carte d'identité [id] (`Left(NotFoundFailure)` si absente/supprimée).
  Future<ZResult<ZFlashcard>> getById(String id) => _cards.getById(id);

  /// Persiste [card] (offline-first : local autoritaire + distant best-effort).
  ///
  /// **Matérialisation de l'éphémère (AD-14, AC5)** : une carte éphémère
  /// (`id == null`) valide délègue au port carte, qui matérialise l'`id` opaque
  /// (UUID) et estampille `updated_at` (`ZSyncMeta`, clé LWW) ; `folderId`/
  /// `subFolderId` sont conservés.
  ///
  /// **Garde `folderId` (AC6)** : une carte **éphémère** dont `folderId` est
  /// `null` **ou** vide (`''`) retourne `Left(DomainFailure)` **sans** appeler
  /// [cards] (aucune écriture) et **sans** throw. Une carte **déjà
  /// matérialisée** (`id != null`) n'est **pas** soumise à cette garde (choix
  /// retenu, cf. AC6 : la garde ne s'applique qu'à la matérialisation de
  /// l'éphémère — libellé de l'epic « carte éphémère sauvegardée sans dossier »).
  Future<ZResult<ZFlashcard>> save(ZFlashcard card) async {
    if (card.isEphemeral &&
        (card.folderId == null || card.folderId!.isEmpty)) {
      return Left<ZFailure, ZFlashcard>(const DomainFailure(
        'Matérialisation refusée : dossier cible requis (folderId) pour une '
        'carte éphémère.',
      ));
    }
    return _cards.save(card);
  }

  /// Soft-delete la carte [id] (`is_deleted = true`, hors-entité `ZSyncMeta`).
  Future<ZResult<Unit>> softDelete(String id) => _cards.softDelete(id);

  /// Restaure la carte [id] soft-deletée (corbeille).
  Future<ZResult<Unit>> restore(String id) => _cards.restore(id);

  // ─────────────────────── SRS : voie d'écriture UNIQUE ───────────────────────

  /// **Inscrit** la carte [flashcardId] du dossier [folderId] à l'étude —
  /// **idempotent** (dette L2 d'E9-4, tranchée E9-5).
  ///
  /// **Garde d'idempotence (AC8)** : si un état SRS **existe déjà** pour la
  /// carte, il est **préservé** et **renvoyé tel quel** (no-op — **aucun**
  /// écrasement de `repetitions`/`interval`/`learnedAt`) ; un état neuf
  /// (`scheduler.initial`) n'est écrit **que si absent** (première inscription).
  /// Un double-appel accidentel (UI d'inscription) ne détruit donc **jamais** un
  /// historique. Le **reset délibéré** passe par [resetRepetition] (voie
  /// explicite documentée).
  ///
  /// **Défensif (AD-10)** : un état **corrompu** relu est reconstruit par le
  /// store (`fromMap`) et considéré présent (préservé) — jamais un throw. Un
  /// `Left` réel du store (`CacheFailure`) est propagé.
  ///
  /// **Seul** write SRS autorisé **hors** [reviewCard]/[resetRepetition] ; ne
  /// touche **jamais** [cards] ; n'appelle **jamais** `scheduler.apply` (pas une
  /// voie d'avancement, AD-9).
  Future<ZResult<ZRepetitionInfo>> initRepetition({
    required String flashcardId,
    required String folderId,
  }) async {
    final loaded = await _reps.getByCard(flashcardId);
    return loaded.fold(
      (failure) => Left<ZFailure, ZRepetitionInfo>(failure),
      (existing) {
        if (existing != null) {
          // Idempotence : historique préservé, renvoyé tel quel (no-op).
          return Right<ZFailure, ZRepetitionInfo>(existing);
        }
        final fresh = _scheduler.initial(
          flashcardId: flashcardId,
          folderId: folderId,
        );
        return _reps.put(fresh);
      },
    );
  }

  /// **Reset délibéré** de l'état SRS de la carte [flashcardId] (dossier
  /// [folderId]) — voie **explicite** documentée (dette L2, AC8).
  ///
  /// Réinitialise **inconditionnellement** l'état via `scheduler.initial`
  /// (compteurs à zéro, `easeFactor` défaut, dates `null`) puis le persiste. À
  /// utiliser **uniquement** pour une remise à zéro volontaire (jamais sur le
  /// chemin d'inscription — cf. [initRepetition]). N'appelle **jamais**
  /// `scheduler.apply` (pas une voie d'avancement, AD-9) ; ne touche **jamais**
  /// [cards].
  Future<ZResult<ZRepetitionInfo>> resetRepetition({
    required String flashcardId,
    required String folderId,
  }) {
    final fresh = _scheduler.initial(
      flashcardId: flashcardId,
      folderId: folderId,
    );
    return _reps.put(fresh);
  }

  /// **Déplace** la carte [flashcardId] vers le dossier [folderId] (sous-dossier
  /// [subFolderId] optionnel) et **re-synchronise** le `folderId` dénormalisé de
  /// sa ligne SRS (dette M1 d'E9-4, intégrée E9-5).
  ///
  /// **Atomicité de routage (AC7)** : met à jour (1) la carte via le port carte
  /// (`folderId`/`subFolderId`, estampille `updated_at`) **puis** (2) la ligne
  /// SRS via une **relocalisation folder-only** (`ZRepetitionInfo.withFolder`) —
  /// **sans** toucher **aucun** champ d'ordonnancement (`interval`/`repetitions`/
  /// `easeFactor`/`nextReviewDate`/`learnedAt`/`lastQuality` **inchangés**), donc
  /// **pas** une voie d'avancement (AD-9, garantie **par construction** :
  /// `withFolder` n'expose aucun paramètre d'ordonnancement).
  ///
  /// **`vide ≠ erreur` (AD-10)** : si la carte n'a **aucune** ligne SRS
  /// (jamais inscrite), seule la carte est déplacée — **aucun** `put` SRS. Si la
  /// carte est introuvable, `Left(NotFoundFailure)` (aucune écriture). Un `Left`
  /// du port carte est propagé **avant** toute écriture SRS (la carte prime).
  Future<ZResult<ZFlashcard>> moveCard({
    required String flashcardId,
    required String folderId,
    String? subFolderId,
  }) async {
    final loadedCard = await _cards.getById(flashcardId);
    return loadedCard.fold(
      (failure) => Left<ZFailure, ZFlashcard>(failure),
      (card) async {
        final moved = await _cards.save(
          card.copyWith(folderId: folderId, subFolderId: subFolderId),
        );
        return moved.fold(
          (failure) => Left<ZFailure, ZFlashcard>(failure),
          (savedCard) async {
            // Re-sync folder-only de la ligne SRS dénormalisée (M1).
            final srs = await _reps.getByCard(flashcardId);
            await srs.fold(
              (failure) async {
                _log(
                  'moveCard: relecture SRS échouée — carte déplacée, re-sync '
                  'folderId SRS différée (best-effort).',
                  error: failure,
                );
              },
              (existing) async {
                // `vide ≠ erreur` : aucune ligne SRS → aucun put (AC7).
                if (existing != null) {
                  // MEDIUM-2 : le `Left` du put de re-sync ne doit JAMAIS être
                  // avalé (AD-11) — sinon la carte bouge mais la ligne SRS garde
                  // un `folderId` périmé (getDue incohérent) sans aucune trace.
                  final resynced = await _reps.put(existing.withFolder(folderId));
                  resynced.leftMap(
                    (failure) => _log(
                      'moveCard: re-sync du folderId SRS échouée — carte déplacée '
                      'mais ligne SRS au folderId périmé (getDue potentiellement '
                      'incohérent, best-effort).',
                      error: failure,
                    ),
                  );
                }
              },
            );
            return Right<ZFailure, ZFlashcard>(savedCard);
          },
        );
      },
    );
  }

  /// **UNIQUE voie d'avancement SRS (AD-9, AC4/AC9)** : applique une révision de
  /// [quality] à l'état courant de la carte [flashcardId] et persiste le nouvel
  /// état via le canal SRS séparé.
  ///
  /// Charge l'état courant (via [ZRepetitionStore]) ou `scheduler.initial(...)`
  /// s'il est **absent** (AD-10 — une carte jamais révisée réussit), applique
  /// **exactement** `scheduler.apply(current, quality, now: now)`, persiste, et
  /// renvoie le nouvel état. **Ne touche jamais** [cards] (aucun `put` carte,
  /// AC9). L'état est persisté **tel quel** (aucun recalcul à la
  /// (dé)sérialisation ; le merge LWW se fait via `ZSyncMeta` côté store).
  Future<ZResult<ZRepetitionInfo>> reviewCard({
    required String flashcardId,
    required String folderId,
    required int quality,
    DateTime? now,
  }) async {
    final loaded = await _reps.getByCard(flashcardId);
    return loaded.fold(
      (failure) => Left<ZFailure, ZRepetitionInfo>(failure),
      (existing) {
        // AD-10 : état absent → repli sur `initial()` (jamais un échec).
        final current = existing ??
            _scheduler.initial(flashcardId: flashcardId, folderId: folderId);
        final next = _scheduler.apply(current, quality, now: now);
        return _reps.put(next);
      },
    );
  }

  // ───────────────────────── Sélection de session (getDue) ────────────────────

  /// États SRS **dus** à [now], filtrés **en mémoire** sur le snapshot du canal
  /// SRS (dette A2 assumée & loggée — les ports E5 droppent la traduction
  /// requête→backend).
  ///
  /// **Dû** = `nextReviewDate == null` (jamais révisé ⇒ dû) **ou**
  /// `nextReviewDate <= now`. Filtre optionnel [folderId] sur
  /// `ZRepetitionInfo.folderId`. `vide ≠ erreur` (`Right(<[]>)`).
  Future<ZResult<List<ZRepetitionInfo>>> getDue({
    required DateTime now,
    String? folderId,
  }) async {
    _log('getDue: filtrage EN MÉMOIRE du snapshot SRS '
        '(dette A2 — traduction requête→backend non disponible).');
    final res = await _reps.getAll();
    return res.map((all) => <ZRepetitionInfo>[
          for (final info in all)
            if (_isDue(info, now) &&
                (folderId == null || info.folderId == folderId))
              info,
        ]);
  }

  /// Un état est **dû** si jamais révisé (`nextReviewDate == null`) ou si son
  /// échéance est atteinte (`nextReviewDate <= now`).
  static bool _isDue(ZRepetitionInfo info, DateTime now) {
    final due = info.nextReviewDate;
    return due == null || !due.isAfter(now);
  }

  // ───────────────────────────── Sync best-effort ─────────────────────────────

  /// Synchronise **une fois** le dépôt : délègue au `sync()` du port carte **et**
  /// au `sync()` du canal SRS (best-effort, AD-9). `Right(unit)` si hors-ligne ;
  /// un **échec partiel** d'un port est **toléré et loggé** (jamais d'arrêt
  /// global — E5-4). Une **garde de ré-entrance** (dette A3) coalesce un cycle si
  /// un est déjà en vol.
  Future<ZResult<Unit>> sync() async {
    if (_syncing) {
      _log('sync: un cycle est déjà en vol — coalescé (Right(unit)).');
      return Right<ZFailure, Unit>(unit);
    }
    _syncing = true;
    try {
      final cardsRes = await _cards.sync();
      cardsRes.leftMap((f) => _log(
            'sync: cartes échec best-effort toléré — ${f.message}',
            error: f,
          ));
      final repsRes = await _reps.sync();
      repsRes.leftMap((f) => _log(
            'sync: SRS échec best-effort toléré — ${f.message}',
            error: f,
          ));
      // Best-effort global (AC11) : un échec partiel n'arrête jamais le cycle.
      return Right<ZFailure, Unit>(unit);
    } finally {
      _syncing = false;
    }
  }

  /// Libère les ressources des ports composés.
  void dispose() {
    _cards.dispose();
    _reps.dispose();
  }
}
