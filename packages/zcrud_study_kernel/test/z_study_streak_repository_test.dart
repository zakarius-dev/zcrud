/// Persistance du streak par le port **EXISTANT** (SU-6 — AC5, D4).
///
/// 🔴 **AUCUN port neuf n'est créé par su-6** : `ZStudyRepository<T extends
/// ZEntity>` est le **seul** port du kernel, et `ZStudyStreak` étant une
/// `ZEntity`, `ZStudyRepository<ZStudyStreak>` est **déjà** son contrat de dépôt.
/// Ces tests le **PROUVENT** au lieu de l'affirmer — et prouvent surtout les deux
/// garanties dont la story dépend (AD-10/AD-11) :
///   1. un échec de persistance rend un `Left(ZFailure)`, **jamais** une
///      exception ⇒ l'hôte peut continuer la session ;
///   2. le Template Method `save` (`@nonVirtual`) n'est **pas contournable** :
///      un `validate → Left` **empêche mécaniquement** l'appel à `persist`.
///
/// L'adaptateur CONCRET (Hive/Firestore) vit dans `zcrud_firestore` (ES-3.2) —
/// **hors périmètre su-6**. Ce qui est prouvable ici sans aucun store l'est :
/// c'est tout l'intérêt d'un port.
library;

import 'package:dartz/dartz.dart';
import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Dépôt **fixture** de streak — espionne `persist` et rend ce qu'on lui dit.
///
/// Étend le port RÉEL `ZStudyRepository<ZStudyStreak>` (jamais une copie) : si
/// le port cessait de servir `ZStudyStreak`, ce fichier ne compilerait plus.
class _FakeStreakRepository extends ZStudyRepository<ZStudyStreak> {
  _FakeStreakRepository({this.failure, this.validationFailure});

  /// Échec rendu par `persist` (`null` ⇒ succès).
  final ZFailure? failure;

  /// Échec rendu par `validate` (`null` ⇒ succès).
  final ZFailure? validationFailure;

  /// 🔴 Espion : les items RÉELLEMENT persistés (prouve que `persist` a été —
  /// ou n'a PAS été — atteint).
  final List<ZStudyStreak> persisted = <ZStudyStreak>[];

  @override
  ZResult<Unit> validate(ZStudyStreak item) {
    final f = validationFailure;
    if (f != null) return Left<ZFailure, Unit>(f);
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<ZStudyStreak>> persist(
    ZStudyStreak item, {
    String? collectionId,
  }) async {
    persisted.add(item);
    final f = failure;
    if (f != null) return Left<ZFailure, ZStudyStreak>(f);
    return Right<ZFailure, ZStudyStreak>(item);
  }

  @override
  Stream<List<ZStudyStreak>> watchAll() => const Stream<List<ZStudyStreak>>.empty();

  @override
  Stream<List<ZStudyStreak>> watch(ZDataRequest request) =>
      const Stream<List<ZStudyStreak>>.empty();

  @override
  Future<ZResult<List<ZStudyStreak>>> getAll({ZDataRequest? request}) async =>
      const Right<ZFailure, List<ZStudyStreak>>(<ZStudyStreak>[]);

  @override
  Future<ZResult<ZStudyStreak>> getById(String id) async =>
      const Right<ZFailure, ZStudyStreak>(ZStudyStreak());

  @override
  Future<ZResult<Unit>> softDelete(String id) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<Unit>> restore(String id) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      const Right<ZFailure, int>(0);

  @override
  Future<ZResult<Unit>> sync() async => const Right<ZFailure, Unit>(unit);

  @override
  void dispose() {}
}

/// Dépôt qui **valide la cohérence des dates** du streak (D4 : la validation de
/// cohérence est légitime dans `validate`, le **calcul** ne l'est pas).
///
/// `validate` reste **PUR** : aucun `DateTime.now()`, aucune I/O — il n'inspecte
/// que l'item reçu (contrat `z_study_repository.dart:70-85`).
class _ValidatingStreakRepository extends _FakeStreakRepository {
  @override
  ZResult<Unit> validate(ZStudyStreak item) {
    if (!zIsCivilDay(item.lastGradedDay) && item.lastGradedDay != null) {
      return const Left<ZFailure, Unit>(
        ZDomainFailure('lastGradedDay n\'est pas un jour civil yyyy-MM-dd'),
      );
    }
    if (item.current < 0 || item.best < 0) {
      return const Left<ZFailure, Unit>(
        ZDomainFailure('un compteur d\'assiduité n\'est jamais négatif'),
      );
    }
    return const Right<ZFailure, Unit>(unit);
  }
}

void main() {
  group('AC5 — le streak passe par le port EXISTANT ZStudyRepository', () {
    test('ZStudyRepository<ZStudyStreak> est une instanciation VALIDE du port '
        '(aucun port neuf)', () {
      final repo = _FakeStreakRepository();

      // Le typage PROUVE l'affirmation : si `ZStudyStreak` n'était pas une
      // `ZEntity`, ceci ne compilerait pas.
      expect(repo, isA<ZStudyRepository<ZStudyStreak>>());
      expect(repo, isA<ZSyncableRepository<ZStudyStreak>>());
      expect(repo, isA<ZRepository<ZStudyStreak>>());
      expect(const ZStudyStreak(), isA<ZEntity>());
    });

    test('save d\'un streak valide ⇒ Right(streak), persist ATTEINT', () async {
      final repo = _FakeStreakRepository();
      const streak =
          ZStudyStreak(current: 4, best: 9, lastGradedDay: '2026-03-29');

      final result = await repo.save(streak);

      expect(result.isRight(), isTrue);
      expect(
        result.getOrElse(() => const ZStudyStreak()),
        equals(streak),
      );
      // 🔴 L'espion PROUVE que `persist` a réellement été atteint — sans quoi le
      // test suivant (« persist NON atteint ») serait vrai pour de mauvaises
      // raisons (un espion jamais branché voit toujours 0 appel).
      expect(repo.persisted, hasLength(1));
      expect(repo.persisted.single, equals(streak));
    });

    test('🔴 un échec de persistance rend Left(ZFailure) — JAMAIS une exception '
        '(AD-11/AD-10 : la session continue)', () async {
      final repo = _FakeStreakRepository(
        failure: const ZCacheFailure('disque plein'),
      );
      const streak = ZStudyStreak(current: 2, best: 2, lastGradedDay: '2026-03-29');

      // 🔴 L'ASSERTION QUI PORTE : aucun throw ne s'échappe. L'injection R3 de
      // l'AC5 (remplacer le `Left` par un `throw` dans le dépôt) fait rougir
      // CETTE ligne.
      final result = await repo.save(streak);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ZCacheFailure>()),
        (_) => fail('un échec de persistance ne doit pas rendre Right'),
      );
    });

    test('🔴 un échec de persistance n\'empêche PAS la session de continuer : '
        'le streak reste AFFICHABLE (AD-10)', () async {
      final repo = _FakeStreakRepository(
        failure: const ZServerFailure('backend indisponible'),
      );
      const before = ZStudyStreak(current: 6, best: 6, lastGradedDay: '2026-03-28');
      final at = DateTime(2026, 3, 29, 9);

      // Le calcul est PUR et se fait AVANT toute persistance : la valeur à
      // afficher existe indépendamment du sort du dépôt.
      final advance = zAdvanceStreak(
        before,
        at: at,
        mode: ZReviewMode.spaced,
        civilDayOf: (_) => '2026-03-29',
      );
      expect(advance.streak.current, equals(7));

      final result = await repo.save(advance.streak);

      // La persistance échoue…
      expect(result.isLeft(), isTrue);
      // …mais la flamme calculée reste INTACTE et affichable : l'hôte consigne
      // le repli et poursuit. C'est exactement ce qu'exige AD-10.
      expect(advance.streak.current, equals(7));
      expect(advance.outcome, equals(ZStreakOutcome.incremented));
    });

    test('les 3 familles de ZFailure remontent telles quelles (jamais de throw)',
        () async {
      for (final failure in <ZFailure>[
        const ZCacheFailure('cache'),
        const ZServerFailure('server'),
        const ZNotFoundFailure('absent'),
      ]) {
        final repo = _FakeStreakRepository(failure: failure);
        final result = await repo.save(const ZStudyStreak(current: 1, best: 1));
        expect(result.isLeft(), isTrue, reason: '$failure doit rendre Left');
      }
    });
  });

  group('AC5 — Template Method : save n\'est PAS contournable', () {
    test('🔴 validate → Left EMPÊCHE MÉCANIQUEMENT persist (espion à 0 appel)',
        () async {
      final repo = _FakeStreakRepository(
        validationFailure: const ZDomainFailure('refusé'),
      );

      final result = await repo.save(const ZStudyStreak(current: 1, best: 1));

      expect(result.isLeft(), isTrue);
      // 🔴 « 0 appel » n'est probant QUE parce que le test précédent a prouvé que
      // cet espion capte RÉELLEMENT (1 appel sur le chemin nominal). Sans cette
      // preuve préalable, un espion débranché rendrait ce test infalsifiable.
      expect(
        repo.persisted,
        isEmpty,
        reason: '🔴 un validate → Left doit court-circuiter l\'écriture',
      );
    });

    test('validate PUR de cohérence des dates (D4) : un jour illisible est '
        'REFUSÉ avant écriture', () async {
      final repo = _ValidatingStreakRepository();

      final rejected = await repo.save(
        const ZStudyStreak(current: 1, best: 1, lastGradedDay: 'pas-une-date'),
      );

      expect(rejected.isLeft(), isTrue);
      expect(repo.persisted, isEmpty, reason: 'aucune écriture sur rejet');

      // …et un streak cohérent passe (le validateur n'est pas un mur aveugle).
      final accepted = await repo.save(
        const ZStudyStreak(current: 1, best: 1, lastGradedDay: '2026-03-29'),
      );
      expect(accepted.isRight(), isTrue);
      expect(repo.persisted, hasLength(1));
    });

    test('validate refuse un compteur négatif (cohérence, pas calcul)', () async {
      final repo = _ValidatingStreakRepository();

      final result = await repo.save(const ZStudyStreak(current: -1, best: 0));

      expect(result.isLeft(), isTrue);
      expect(repo.persisted, isEmpty);
    });

    test('un streak SANS lastGradedDay (jamais noté) est VALIDE', () async {
      final repo = _ValidatingStreakRepository();

      final result = await repo.save(const ZStudyStreak());

      expect(result.isRight(), isTrue);
      expect(repo.persisted, hasLength(1));
    });
  });
}
