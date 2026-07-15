@Tags(<String>['serialization-compat'])
library;

/// CORPUS de rétro-compatibilité de sérialisation du NOYAU d'étude (ES-3.5,
/// AD-10) — **test-only, additif, ZÉRO changement de lib kernel**.
///
/// Exécuté par le slot de gate de merge `verify:serialization`
/// (`scripts/ci/verify_serialization.dart` → `dart test --tags
/// serialization-compat` ; `zcrud_study_kernel` = pur-Dart). Satisfait le HOOK
/// déclaré de `packages/zcrud_study_kernel/dart_test.yaml` (« ES-3.5 sèmera le
/// corpus »).
///
/// Le kernel ne connaît PAS la casse legacy (AD-27) : ce corpus exerce des
/// documents historiques **snake_case canoniques** — `ZSyncMeta` absent, enum
/// inconnu → défaut sûr (1ʳᵉ constante), champs manquants → décodage défensif
/// qui SURVIT (`returnsNormally`), jamais de throw.
///
/// JS-safe (aucun `dart:io`, littéraux ISO) — parité `gate:web` des tests kernel.
import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  // ══════════════════════════════════════════════════════════════════════
  // ZStudyFolder — document historique snake_case, ZSyncMeta absent
  // ══════════════════════════════════════════════════════════════════════
  group('ZStudyFolder — décodage défensif (AD-10)', () {
    test('doc historique complet (snake_case, SANS is_deleted/updated_at) '
        'décode les vraies valeurs', () {
      final folder = ZStudyFolder.fromMap(<String, dynamic>{
        'id': 'folder_001',
        'title': 'Algèbre',
        'color_key': 'blue',
        'parent_id': null,
        'owner_id': 'user_amadou',
        'created_at': '2024-03-15T10:30:00.000Z',
      });
      expect(folder.id, 'folder_001');
      expect(folder.title, 'Algèbre');
      expect(folder.colorKey, 'blue');
      expect(folder.ownerId, 'user_amadou');
      expect(folder.createdAt, isNotNull);
    });

    test('champs récents absents → défauts sûrs (title requis → repli)', () {
      late ZStudyFolder folder;
      expect(
        () => folder = ZStudyFolder.fromMap(<String, dynamic>{'id': 'f2'}),
        returnsNormally,
      );
      expect(folder.title, ''); // requis absent → repli
      expect(folder.colorKey, '');
      expect(folder.ownerId, '');
      expect(folder.isPublic, isFalse);
      expect(folder.sharedWith, isEmpty);
    });

    test('map vide → parent survit, jamais throw', () {
      expect(() => ZStudyFolder.fromMap(const <String, dynamic>{}),
          returnsNormally);
    });

    test('clés de sync réservées (is_deleted/updated_at) ne polluent PAS extra '
        '(concern de store, AD-19)', () {
      final folder = ZStudyFolder.fromMap(<String, dynamic>{
        'id': 'f3',
        'title': 'T',
        'is_deleted': true,
        'updated_at': '2024-04-01T08:00:00.000Z',
        'relatedTopics': <String>['x'], // clé libre → extra (round-trip)
      });
      expect(folder.extra.containsKey('is_deleted'), isFalse);
      expect(folder.extra.containsKey('updated_at'), isFalse);
      expect(folder.extra['relatedTopics'], <String>['x']);
    });

    test('types corrompus (title non-String, shared_with non-liste) → replis, '
        'jamais throw', () {
      late ZStudyFolder folder;
      expect(
        () => folder = ZStudyFolder.fromMap(<String, dynamic>{
          'id': 42, // non-String
          'title': 99, // non-String → repli ''
          'shared_with': 'pas-une-liste',
          'is_public': 'oui', // non-bool
        }),
        returnsNormally,
      );
      expect(folder.title, '');
      expect(folder.sharedWith, isEmpty);
      expect(folder.isPublic, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // ZStudyPodcast — enum inconnu → défaut sûr (1ʳᵉ constante = ready)
  // ══════════════════════════════════════════════════════════════════════
  group('ZStudyPodcast — enum défensif (AD-10)', () {
    test('status connu décodé normalement', () {
      final podcast = ZStudyPodcast.fromMap(<String, dynamic>{
        'id': 'pod_1',
        'source_id': 'src_1',
        'mode': 'simple',
        'status': 'processing',
      });
      expect(podcast.status, ZPodcastStatus.processing);
    });

    test('status inconnu / null / non-String → ready (défaut = 1ʳᵉ constante)',
        () {
      expect(
        ZStudyPodcast.fromMap(<String, dynamic>{'status': 'quantum'}).status,
        ZPodcastStatus.ready,
      );
      expect(
        ZStudyPodcast.fromMap(<String, dynamic>{'status': null}).status,
        ZPodcastStatus.ready,
      );
      expect(
        ZStudyPodcast.fromMap(<String, dynamic>{'status': 42}).status,
        ZPodcastStatus.ready,
      );
      expect(
        ZStudyPodcast.fromMap(const <String, dynamic>{}).status,
        ZPodcastStatus.ready,
      );
    });

    test('map vide → parent survit, jamais throw', () {
      expect(() => ZStudyPodcast.fromMap(const <String, dynamic>{}),
          returnsNormally);
    });
  });
}
