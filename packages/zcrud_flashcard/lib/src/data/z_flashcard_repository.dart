/// Dépôt offline-first `ZFlashcardRepository` — coordinateur qui compose,
/// par injection, les ports neutres du cœur pour la carte
/// (`ZSyncableRepository<ZFlashcard>`) et un canal SRS séparé
/// (`ZRepetitionStore`), et fait progresser l'état SRS par l'unique voie
/// `reviewCard() → ZSrsScheduler.apply` (invariant AD-9).
///
/// ## Invariant SRS top-level
///
/// L'état `ZRepetitionInfo` est persisté exclusivement via
/// [ZRepetitionStore] (chemin logique top-level
/// `study_repetitions/{cardId}`), jamais dans le corps de la carte. Le
/// partage ou la duplication d'une carte n'emporte donc jamais l'historique
/// SRS. Côté modèle l'invariant est déjà tenu (`ZFlashcard` ne porte aucun
/// champ SRS) ; côté dépôt, [reviewCard]/[initRepetition] n'écrivent jamais
/// via [cards].
///
/// ## Voie d'écriture SRS unique
///
/// [reviewCard] est la seule méthode publique produisant un état SRS avancé
/// (délègue exactement à `scheduler.apply`) ; [initRepetition] (état neuf,
/// `scheduler.initial`) est le seul autre write SRS. Aucune autre API
/// publique n'écrit un état SRS.
///
/// ## Isolation
///
/// Ce fichier n'importe aucun type backend (Firestore/Hive/Firebase) ni le
/// paquet adaptateur (invariant AD-1). La concrétude backend offline-first
/// est injectée, typée sur les ports neutres — jamais importée ici.
/// `zcrud_flashcard` ne tire jamais Firebase.
///
/// Contrat de résultat (invariant AD-11) : signatures publiques
/// `ZResult<…>`/`Stream<List<…>>` nues ; aucun `try-catch` nu (le seul
/// `try/finally` est la garde de ré-entrance de [sync], sans `catch`).
///
/// Défensif (invariant AD-10) : un état SRS absent au chargement retombe sur
/// `scheduler.initial()` ([reviewCard] réussit sur une carte jamais
/// révisée) ; un état corrompu est reconstruit par `ZRepetitionInfo.fromMap`
/// (dans le store) — jamais d'exception ; une lecture vide n'est pas une
/// erreur.
library;

// `prefer_initializing_formals` : faux positif (champ privé exposé en
// paramètre nommé public — `this._cards` est interdit par Dart). Désactivé
// au niveau fichier, même patron que le dépôt offline-first du cœur.
// ignore_for_file: prefer_initializing_formals

import 'package:zcrud_core/domain.dart';

import '../domain/z_flashcard.dart';
import '../domain/z_repetition_info.dart';
import '../domain/z_sm2_scheduler.dart';
import '../domain/z_srs_scheduler.dart';
import 'z_repetition_store.dart';

/// Journal minimal neutre du dépôt flashcard (aucune dépendance backend).
///
/// Miroir du journal du dépôt offline-first du cœur : un drop de traduction
/// requête→backend ou un échec de synchronisation best-effort est loggé ici
/// — jamais silencieux (invariant AD-11). Défaut no-op.
typedef ZFlashcardRepositoryLog = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

void _noopLog(String message, {Object? error, StackTrace? stackTrace}) {}

/// Coordinateur offline-first des flashcards et de leur état SRS (canal
/// séparé).
///
/// Injection (aucun singleton — testabilité) : un
/// [ZSyncableRepository]`<ZFlashcard>` (port carte, local autoritaire et
/// distant best-effort), un [ZRepetitionStore] (canal SRS séparé
/// top-level), un [ZSrsScheduler] (défaut `const ZSm2Scheduler()`), et un
/// [ZFlashcardRepositoryLog] optionnel (défaut no-op).
class ZFlashcardRepository {
  /// Construit le dépôt par composition des ports injectés.
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

  /// Garde de ré-entrance de [sync] : coalesce un cycle si un est déjà en
  /// vol.
  bool _syncing = false;

  // ─────────────────────────── Cartes (offline-first) ──────────────────────

  /// Flux temps réel nu des cartes non soft-deleted (délègue au port carte).
  Stream<List<ZFlashcard>> watchAll() => _cards.watchAll();

  /// Flux temps réel nu filtré/trié/paginé (délègue au port carte).
  Stream<List<ZFlashcard>> watch(ZDataRequest request) => _cards.watch(request);

  /// Lit toutes les cartes correspondant à [request] (exclut les
  /// soft-deleted).
  Future<ZResult<List<ZFlashcard>>> getAll({ZDataRequest? request}) =>
      _cards.getAll(request: request);

  /// Lit la carte d'identité [id] (`Left(ZNotFoundFailure)` si
  /// absente/supprimée).
  Future<ZResult<ZFlashcard>> getById(String id) => _cards.getById(id);

  /// Persiste [card] (offline-first : local autoritaire, distant
  /// best-effort).
  ///
  /// Matérialisation de l'éphémère (invariant AD-14) : une carte éphémère
  /// (`id == null`) valide délègue au port carte, qui matérialise l'`id`
  /// opaque et estampille `updated_at` (clé de merge, hors entité) ;
  /// `folderId`/`subFolderId` sont conservés.
  ///
  /// Garde `folderId` : une carte éphémère dont `folderId` est `null` ou
  /// vide retourne `Left(ZDomainFailure)` sans appeler [cards] (aucune
  /// écriture) et sans exception. Une carte déjà matérialisée (`id != null`)
  /// n'est pas soumise à cette garde — elle ne s'applique qu'à la
  /// matérialisation de l'éphémère.
  Future<ZResult<ZFlashcard>> save(ZFlashcard card) async {
    if (card.isEphemeral &&
        (card.folderId == null || card.folderId!.isEmpty)) {
      return Left<ZFailure, ZFlashcard>(const ZDomainFailure(
        'Matérialisation refusée : dossier cible requis (folderId) pour une '
        'carte éphémère.',
      ));
    }
    return _cards.save(card);
  }

  /// Supprime logiquement la carte [id] (`is_deleted = true`, hors entité).
  Future<ZResult<Unit>> softDelete(String id) => _cards.softDelete(id);

  /// Restaure la carte [id] supprimée logiquement (corbeille).
  Future<ZResult<Unit>> restore(String id) => _cards.restore(id);

  // ─────────────────────── SRS : voie d'écriture unique ───────────────────────

  /// Inscrit la carte [flashcardId] du dossier [folderId] à l'étude —
  /// idempotent.
  ///
  /// Garde d'idempotence : si un état SRS existe déjà pour la carte, il est
  /// préservé et renvoyé tel quel (aucun écrasement de
  /// `repetitions`/`interval`/`learnedAt`) ; un état neuf
  /// (`scheduler.initial`) n'est écrit que si absent (première inscription).
  /// Un double appel accidentel (interface d'inscription) ne détruit donc
  /// jamais un historique. Le reset délibéré passe par [resetRepetition]
  /// (voie explicite documentée).
  ///
  /// Défensif (invariant AD-10) : un état corrompu relu est reconstruit par
  /// le store (`fromMap`) et considéré présent (préservé) — jamais une
  /// exception. Un `Left` réel du store est propagé.
  ///
  /// Seul write SRS autorisé hors [reviewCard]/[resetRepetition] ; ne touche
  /// jamais [cards] ; n'appelle jamais `scheduler.apply` (pas une voie
  /// d'avancement, invariant AD-9).
  Future<ZResult<ZRepetitionInfo>> initRepetition({
    required String flashcardId,
    required String folderId,
  }) async {
    final loaded = await _reps.getByCard(flashcardId);
    return loaded.fold(
      (failure) => Left<ZFailure, ZRepetitionInfo>(failure),
      (existing) {
        if (existing != null) {
          // Idempotence : historique préservé, renvoyé tel quel.
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

  /// Reset délibéré de l'état SRS de la carte [flashcardId] (dossier
  /// [folderId]) — voie explicite documentée.
  ///
  /// Réinitialise inconditionnellement l'état via `scheduler.initial`
  /// (compteurs à zéro, facteur de facilité par défaut, dates `null`) puis
  /// le persiste. À utiliser uniquement pour une remise à zéro volontaire
  /// (jamais sur le chemin d'inscription — voir [initRepetition]). N'appelle
  /// jamais `scheduler.apply` (pas une voie d'avancement, invariant AD-9) ;
  /// ne touche jamais [cards].
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

  /// Déplace la carte [flashcardId] vers le dossier [folderId] (sous-dossier
  /// [subFolderId] optionnel) et re-synchronise le `folderId` dénormalisé de
  /// sa ligne SRS.
  ///
  /// Atomicité de routage : met à jour (1) la carte via le port carte
  /// (`folderId`/`subFolderId`, estampille `updated_at`) puis (2) la ligne
  /// SRS via une relocalisation folder-only (`ZRepetitionInfo.withFolder`) —
  /// sans toucher aucun champ d'ordonnancement (intervalle, répétitions,
  /// facteur de facilité, prochaine échéance, date d'apprentissage, dernière
  /// qualité inchangés), donc pas une voie d'avancement (invariant AD-9,
  /// garantie par construction : `withFolder` n'expose aucun paramètre
  /// d'ordonnancement).
  ///
  /// Vide n'est pas une erreur : si la carte n'a aucune ligne SRS (jamais
  /// inscrite), seule la carte est déplacée — aucun `put` SRS. Si la carte
  /// est introuvable, `Left(ZNotFoundFailure)` (aucune écriture). Un `Left`
  /// du port carte est propagé avant toute écriture SRS (la carte prime).
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
            // Re-synchronisation folder-only de la ligne SRS dénormalisée.
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
                // Vide n'est pas une erreur : aucune ligne SRS ⇒ aucun put.
                if (existing != null) {
                  // Le `Left` du put de re-sync ne doit jamais être avalé
                  // (invariant AD-11) — sinon la carte bouge mais la ligne
                  // SRS garde un `folderId` périmé (sélection des cartes
                  // dues potentiellement incohérente) sans aucune trace.
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

  /// Voie d'avancement SRS unique (invariant AD-9) : applique une révision
  /// de [quality] à l'état courant de la carte [flashcardId] et persiste le
  /// nouvel état via le canal SRS séparé.
  ///
  /// Charge l'état courant (via [ZRepetitionStore]) ou `scheduler.initial(...)`
  /// s'il est absent (invariant AD-10 — une carte jamais révisée réussit),
  /// applique exactement `scheduler.apply(current, quality, now: now)`,
  /// persiste, et renvoie le nouvel état. Ne touche jamais [cards] (aucun
  /// `put` carte). L'état est persisté tel quel (aucun recalcul à la
  /// (dé)sérialisation ; le merge Last-Write-Wins se fait via la méta de
  /// synchronisation côté store).
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
        // Invariant AD-10 : état absent → repli sur `initial()` (jamais un
        // échec).
        final current = existing ??
            _scheduler.initial(flashcardId: flashcardId, folderId: folderId);
        final next = _scheduler.apply(current, quality, now: now);
        return _reps.put(next);
      },
    );
  }

  // ───────────────────────── Sélection de session (getDue) ────────────────────

  /// États SRS dus à [now], filtrés en mémoire sur l'instantané du canal SRS
  /// (dette assumée et loggée — les ports du cœur ne traduisent pas encore
  /// la requête vers le backend pour ce canal).
  ///
  /// Dû = `nextReviewDate == null` (jamais révisé ⇒ dû) ou
  /// `nextReviewDate <= now`. Filtre optionnel [folderId] sur
  /// `ZRepetitionInfo.folderId`. Vide n'est pas une erreur (`Right(<[]>)`).
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

  /// Un état est dû si jamais révisé (`nextReviewDate == null`) ou si son
  /// échéance est atteinte (`nextReviewDate <= now`).
  static bool _isDue(ZRepetitionInfo info, DateTime now) {
    final due = info.nextReviewDate;
    return due == null || !due.isAfter(now);
  }

  // ───────────────────────────── Synchronisation best-effort ─────────────────

  /// Synchronise une fois le dépôt : délègue au `sync()` du port carte et au
  /// `sync()` du canal SRS (best-effort, invariant AD-9). `Right(unit)` si
  /// hors ligne ; un échec partiel d'un port est toléré et loggé (jamais
  /// d'arrêt global). Une garde de ré-entrance coalesce un cycle si un est
  /// déjà en vol.
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
      // Best-effort global : un échec partiel n'arrête jamais le cycle.
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
