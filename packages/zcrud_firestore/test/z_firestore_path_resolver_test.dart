// Tests ES-3.2 : résolveur de chemins Firestore bi-topologie (AC10, AC11).
//
// Pouvoir discriminant (R12) : chaque fixture asserte le chemin EXACT — échanger
// une branche (flat↔nested) ou inverser une garde (parentId requis) change le
// chemin résolu et fait ROUGIR. `flutter_test` (VM) — `zcrud_firestore` est un
// package Flutter (D9, HORS gate:web-determinism).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

void main() {
  // Table de topologie de référence : les 3 formes + une variante flat user-scopée.
  ZFirestorePathResolver resolver() => ZFirestorePathResolver(
        <String, ZFirestorePathRule>{
          // flat top-level PUR (IFFD `db.collection('flashcards')`).
          'flashcards_flat':
              const ZFirestorePathRule.flatTopLevel(collection: 'flashcards'),
          // flat top-level USER-SCOPÉE (`users/{uid}/flashcards`).
          'flashcards_user': const ZFirestorePathRule.flatTopLevel(
              collection: 'flashcards', userScoped: true),
          // nested lex (`users/{uid}/study_folders/{folderId}/flashcards`).
          'flashcards': const ZFirestorePathRule.nestedUnderParent(
              collection: 'flashcards', parentCollection: 'study_folders'),
          // globale top-level (`study_share_links`, HORS users/{uid}).
          'study_share_links': const ZFirestorePathRule.globalTopLevel(
              collection: 'study_share_links'),
        },
      );

  group('AC10 — bi-topologie flat / nested / global', () {
    test('(a) flatTopLevel PUR → collection nue (IFFD)', () {
      final r = resolver();
      expect(
        r.resolveCollection(kind: 'flashcards_flat', userId: 'u1')
            .getOrElse(() => 'ERR'),
        'flashcards',
        reason: 'flat pur : jamais de préfixe users/{uid}',
      );
    });

    test('(a\') flatTopLevel USER-SCOPÉE → users/{uid}/flashcards', () {
      final r = resolver();
      expect(
        r.resolveCollection(kind: 'flashcards_user', userId: 'u1')
            .getOrElse(() => 'ERR'),
        'users/u1/flashcards',
      );
    });

    test('(b) nestedUnderParent → users/{uid}/study_folders/{fid}/flashcards',
        () {
      final r = resolver();
      // ★ R3-h : si la règle "flashcards" pointait sur une topologie flat, ce
      // chemin deviendrait "flashcards" (mauvaise collection) → ROUGE.
      expect(
        r
            .resolveCollection(kind: 'flashcards', userId: 'u1', parentId: 'f1')
            .getOrElse(() => 'ERR'),
        'users/u1/study_folders/f1/flashcards',
      );
    });

    test('(c) globalTopLevel → study_share_links (HORS users/{uid})', () {
      final r = resolver();
      final path = r
          .resolveCollection(kind: 'study_share_links', userId: 'u1')
          .getOrElse(() => 'ERR');
      expect(path, 'study_share_links');
      expect(path.contains('users/'), isFalse,
          reason: 'la collection globale ne vit JAMAIS sous users/{uid}');
    });

    test('(d) nested SANS parentId → Left explicite (jamais un chemin muet)', () {
      final r = resolver();
      final res = r.resolveCollection(kind: 'flashcards', userId: 'u1');
      expect(res.isLeft(), isTrue);
      res.leftMap((f) {
        expect(f, isA<ZDomainFailure>());
        expect(f.message, contains('parentId'));
      });
    });

    test('user-scopée SANS userId → Left explicite', () {
      final r = resolver();
      final res = r.resolveCollection(kind: 'flashcards_user');
      expect(res.isLeft(), isTrue);
      res.leftMap((f) => expect(f.message, contains('userId')));
    });

    test('kind inconnu → Left explicite (frontière stricte)', () {
      final r = resolver();
      final res = r.resolveCollection(kind: 'inexistant');
      expect(res.isLeft(), isTrue);
      res.leftMap((f) => expect(f, isA<ZDomainFailure>()));
    });

    test('resolveDoc = <collection>/<id> (nested)', () {
      final r = resolver();
      expect(
        r
            .resolveDoc(
                kind: 'flashcards', id: 'c9', userId: 'u1', parentId: 'f1')
            .getOrElse(() => 'ERR'),
        'users/u1/study_folders/f1/flashcards/c9',
      );
    });

    test('resolveDoc propage le Left de resolveCollection (nested sans parent)',
        () {
      final r = resolver();
      expect(r.resolveDoc(kind: 'flashcards', id: 'c9', userId: 'u1').isLeft(),
          isTrue);
    });
  });

  // ───────────────────────── AC11 — anti-réflexion / backend-agnostique ───────

  group('AC11 — anti-réflexion : segment LITTÉRAL, jamais T.toString()', () {
    test('la dérivation de chemin n\'utilise NI runtimeType NI .toString()', () {
      final src = File(_resolverPath()).readAsStringSync();
      // Le CRUD quasi-réflexif IFFD (`collection = T.toString()`) est BANNI.
      // Scan hors commentaires/dartdoc (qui MENTIONNENT ces termes comme bannis).
      final offenders = <String>[];
      var inBlock = false;
      for (final raw in src.split('\n')) {
        final t = raw.trimLeft();
        if (inBlock) {
          if (t.contains('*/')) inBlock = false;
          continue;
        }
        if (t.startsWith('/*')) {
          if (!t.contains('*/')) inBlock = true;
          continue;
        }
        if (t.startsWith('///') || t.startsWith('//')) continue;
        if (raw.contains('runtimeType') || raw.contains('.toString()')) {
          offenders.add(raw.trim());
        }
      }
      expect(offenders, isEmpty,
          reason: 'aucune réflexion pour dériver un segment (AC11) :\n'
              '${offenders.join('\n')}');
    });

    test('aucun type cloud_firestore importé ni en signature (AD-5)', () {
      final src = File(_resolverPath()).readAsStringSync();
      expect(src.contains('package:cloud_firestore'), isFalse);
      expect(src.contains('package:hive'), isFalse);
      // Aucun générique Type ni paramètre `Type` : le résolveur ne connaît que
      // des `String kind` — un `T.toString()` est structurellement impossible.
      expect(RegExp(r'resolveCollection<').hasMatch(src), isFalse);
    });
  });
}

String _resolverPath() {
  for (final base in <String>['', 'packages/zcrud_firestore/']) {
    final f = File('${base}lib/src/data/z_firestore_path_resolver.dart');
    if (f.existsSync()) return f.path;
  }
  fail('z_firestore_path_resolver.dart introuvable depuis ${Directory.current.path}');
}
