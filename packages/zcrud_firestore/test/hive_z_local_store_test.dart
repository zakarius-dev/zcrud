// Tests E5-2 : `HiveZLocalStore<T>` (store LOCAL source de vérité offline-first,
// JSON, décodage DÉFENSIF, soft-delete hors-entité, invariant clé↔corps,
// isolation Hive).
//
// Backend : Hive sur tmpdir (`Hive.init` + nettoyage `tearDown`) — aucun binding
// Flutter requis, box injectée directement au constructeur (couture DI).
//
// Learning E5-1 ABSORBÉ : les cas limites sont RÉELS (entrée Hive corrompue,
// type inattendu, doc sans is_deleted, clé absente) — jamais un seed « propre »
// qui masque la sémantique prod.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

// ───────────────────────── Modèle de test ─────────────────────────────────

/// Entité de test minimale. `fromMap` **strict** : lève sur `title`/`count`
/// corrompus (permet de prouver le décodage défensif de l'adaptateur).
class _Note extends ZEntity {
  const _Note({
    this.id,
    required this.title,
    required this.count,
    this.tags = const <String>[],
  });

  @override
  final String? id;
  final String title;
  final int count;
  final List<String> tags;

  static _Note fromMap(Map<String, dynamic> map) {
    final title = map['title'];
    final count = map['count'];
    if (title is! String) {
      throw const FormatException('title manquant/invalide');
    }
    if (count is! int) {
      throw const FormatException('count manquant/invalide');
    }
    return _Note(
      id: map['id'] as String?,
      title: title,
      count: count,
      tags: (map['tags'] as List<dynamic>?)?.cast<String>() ?? const <String>[],
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'title': title,
        'count': count,
        'tags': tags,
      };

  @override
  bool operator ==(Object other) =>
      other is _Note &&
      other.id == id &&
      other.title == title &&
      other.count == count &&
      _listEq(other.tags, tags);

  @override
  int get hashCode => Object.hash(id, title, count, Object.hashAll(tags));

  @override
  String toString() => '_Note(id: $id, title: $title, count: $count)';
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Fabrique d'`id` DÉTERMINISTE pour les tests (séquence stable).
String Function() _seqId() {
  var n = 0;
  return () => 'id${(++n).toString().padLeft(3, '0')}';
}

HiveZLocalStore<_Note> _store(
  Box<dynamic> box, {
  bool withFromMapSafe = false,
  String Function()? idFactory,
  ZLocalStoreLog? logger,
}) =>
    HiveZLocalStore<_Note>(
      box: box,
      kind: 'note',
      fromMap: _Note.fromMap,
      toMap: (n) => n.toMap(),
      fromMapSafe: withFromMapSafe
          ? (m) {
              try {
                return _Note.fromMap(m);
              } on Object {
                return null;
              }
            }
          : null,
      idFactory: idFactory ?? _seqId(),
      logger: logger,
    );

/// Écrit une entrée BRUTE (contourne l'encodeur) — nécessaire pour exercer les
/// cas de corruption/soft-delete RÉELS.
Future<void> _seedRaw(
  Box<dynamic> box,
  String id,
  Map<String, dynamic> body, {
  bool? isDeleted = false,
}) {
  final map = <String, dynamic>{
    ...body,
    'id': id,
    if (isDeleted != null) 'is_deleted': isDeleted,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
  return box.put(id, jsonEncode(map));
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('hive_zls_test');
    Hive.init(tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<Box<dynamic>> openBox([String name = 'notes']) =>
      Hive.openBox<dynamic>(name);

  group('AC4 — round-trip local put/getById (JSON, une box par kind)', () {
    test('put (éphémère) matérialise un id puis getById restitue l\'égal',
        () async {
      final box = await openBox();
      final store = _store(box);

      final saved = await store.put(
        const _Note(title: 'Alpha', count: 3, tags: <String>['a', 'b']),
      );
      final note = saved.getOrElse(() => fail('put a échoué: $saved'));
      expect(note.id, isNotNull);
      expect(note.isEphemeral, isFalse);

      final fetched = await store.getById(note.id!);
      expect(
        fetched.getOrElse(() => fail('getById a échoué: $fetched')),
        equals(note),
      );
    });

    test('boxNameFor dérive le nom du kind', () {
      expect(HiveZLocalStore.boxNameFor('flashcard'), 'zcrud_flashcard');
    });
  });

  group('AC7 — invariant clé↔corps + matérialisation éphémère', () {
    test('put écrit TOUJOURS le corps `id` == clé de box (éphémère)', () async {
      final box = await openBox();
      final store = _store(box, idFactory: () => 'fixedEph');

      final n = (await store.put(const _Note(title: 'x', count: 1)))
          .toIterable()
          .first;
      expect(n.id, 'fixedEph');

      final stored = box.get('fixedEph') as String;
      final map = jsonDecode(stored) as Map<String, dynamic>;
      expect(map['id'], 'fixedEph',
          reason: 'Le corps porte son id logique (invariant clé↔corps).');
      expect(map['is_deleted'], isFalse);
      expect(map['updated_at'], isA<String>()); // ISO-8601
    });

    test('put (id fourni) : clé de box == corps `id` == id fourni', () async {
      final box = await openBox();
      final store = _store(box);
      final n =
          (await store.put(const _Note(id: 'fixed1', title: 'y', count: 2)))
              .toIterable()
              .first;
      expect(n.id, 'fixed1');
      final map = jsonDecode(box.get('fixed1') as String) as Map<String, dynamic>;
      expect(map['id'], 'fixed1');
    });
  });

  group('AC5 — décodage DÉFENSIF (AD-10) : 1 corrompu parmi N → N-1', () {
    test('JSON illisible / non-String / champ manquant → écartés + loggés',
        () async {
      final box = await openBox();
      final logs = <String>[];
      final store = _store(box, logger: (m, {error, stackTrace}) => logs.add(m));

      // 2 entrées valides
      await store.put(const _Note(id: 'ok1', title: 'ok1', count: 1));
      await store.put(const _Note(id: 'ok2', title: 'ok2', count: 2));
      // corrompu #1 : JSON tronqué (illisible)
      await box.put('badJson', '{"id":"badJson","title":');
      // corrompu #2 : type inattendu (valeur non-String stockée)
      await box.put('badType', 12345);
      // corrompu #3 : JSON valide mais `count` de mauvais type → fromMap lève
      await _seedRaw(
          box, 'badField', <String, dynamic>{'title': 'x', 'count': 'NaN'});

      final r = (await store.getAll()).getOrElse(() => fail('getAll'));
      expect(r.map((n) => n.title).toSet(), <String>{'ok1', 'ok2'},
          reason: '3 corrompus écartés, 2 valides conservés (N-1 généralisé).');
      expect(logs, isNotEmpty,
          reason: 'écarté + loggé, jamais avalé silencieusement');
    });

    test('fromMapSafe injecté est utilisé (voie ZModelAdapter)', () async {
      final box = await openBox();
      final store = _store(box, withFromMapSafe: true);
      await store.put(const _Note(id: 'ok', title: 'ok', count: 1));
      await _seedRaw(box, 'bad', <String, dynamic>{'title': 42, 'count': 1});
      final r = (await store.getAll()).getOrElse(() => fail('getAll'));
      expect(r.map((n) => n.title), <String>['ok']);
    });
  });

  group('AC6 — soft-delete hors-entité + cohérence get/getAll/watch', () {
    test('softDelete masque partout, restore ré-affiche, champs métier intacts',
        () async {
      final box = await openBox();
      final store = _store(box);
      final a =
          (await store.put(const _Note(id: 'a', title: 'métier', count: 42)))
              .toIterable()
              .first;
      await store.put(const _Note(id: 'b', title: 'b', count: 2));

      final del = await store.softDelete(a.id!);
      expect(del.isRight(), isTrue);

      // hors-entité : champs métier intacts, seul is_deleted a basculé.
      final raw = jsonDecode(box.get('a') as String) as Map<String, dynamic>;
      expect(raw['is_deleted'], isTrue);
      expect(raw['title'], 'métier');
      expect(raw['count'], 42);

      // COHÉRENCE : exclu de getById ET getAll ET watchAll.
      expect((await store.getById('a')).isLeft(), isTrue);
      final all = (await store.getAll()).getOrElse(() => fail('getAll'));
      expect(all.map((n) => n.id), <String>['b']);
      final watched = await store.watchAll().first;
      expect(watched.map((n) => n.id), <String>['b']);
      store.dispose();

      // restore → de nouveau visible partout.
      expect((await store.restore('a')).isRight(), isTrue);
      expect((await store.getById('a')).isRight(), isTrue);
      final all2 = (await store.getAll()).getOrElse(() => fail('getAll'));
      expect(all2.map((n) => n.id).toSet(), <String>{'a', 'b'});
    });

    test('entrée SANS is_deleted : exclusion COHÉRENTE get/getAll/watch',
        () async {
      final box = await openBox();
      final store = _store(box);
      // seed RÉEL sans champ is_deleted (entrée non-zcrud-native)
      await _seedRaw(box, 'legacy1', <String, dynamic>{'title': 'legacy', 'count': 1},
          isDeleted: null);
      await store.put(const _Note(id: 'ok1', title: 'ok', count: 9));

      final byId = await store.getById('legacy1');
      expect(byId.isLeft(), isTrue);
      byId.leftMap((f) => expect(f, isA<NotFoundFailure>()));

      final all = (await store.getAll()).getOrElse(() => fail('getAll'));
      expect(all.map((n) => n.id).toSet(), <String>{'ok1'});
      final watched = await store.watchAll().first;
      expect(watched.map((n) => n.id).toSet(), <String>{'ok1'});
      store.dispose();
    });
  });

  group('AC8 — watchAll local émet les changements', () {
    test('seed immédiat puis ré-émission sur put puis softDelete', () async {
      final box = await openBox();
      final store = _store(box);

      final emissions = <List<String>>[];
      final sub = store
          .watchAll()
          .listen((list) => emissions.add(list.map((n) => n.id!).toList()));

      // laisse passer le seed
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await store.put(const _Note(id: 'w1', title: 'w', count: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await store.softDelete('w1');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await sub.cancel();
      store.dispose();

      expect(emissions.first, isEmpty, reason: 'seed = box vide');
      expect(emissions.any((e) => e.contains('w1')), isTrue,
          reason: 'après put, w1 apparaît');
      expect(emissions.last, isEmpty,
          reason: 'après softDelete, w1 retiré des visibles');
    });
  });

  group('AC9 — Either/CacheFailure, NotFound, vide (jamais de catch nu)', () {
    test('getById clé absente → Left(NotFoundFailure) (null ≠ erreur)',
        () async {
      final box = await openBox();
      final store = _store(box);
      final r = await store.getById('nope');
      expect(r.isLeft(), isTrue);
      r.leftMap((f) {
        expect(f, isA<NotFoundFailure>());
        expect((f as NotFoundFailure).id, 'nope');
      });
    });

    test('box vide → Right([]) (vide ≠ erreur)', () async {
      final box = await openBox();
      final store = _store(box);
      final r = (await store.getAll()).getOrElse(() => fail('getAll'));
      expect(r, isEmpty);
    });

    test('erreur d\'accès (box fermée) → Left(CacheFailure), jamais d\'exception',
        () async {
      final box = await openBox();
      final store = _store(box);
      await box.close(); // provoque une HiveError sur tout accès ultérieur

      final getAll = await store.getAll();
      expect(getAll.isLeft(), isTrue);
      getAll.leftMap((f) => expect(f, isA<CacheFailure>()));

      final put = await store.put(const _Note(title: 't', count: 1));
      expect(put.isLeft(), isTrue);
      put.leftMap((f) => expect(f, isA<CacheFailure>()));

      final del = await store.softDelete('x');
      expect(del.isLeft(), isTrue);
      del.leftMap((f) => expect(f, isA<CacheFailure>()));
    });

    test('softDelete d\'un id inconnu → Left(NotFoundFailure)', () async {
      final box = await openBox();
      final store = _store(box);
      final r = await store.softDelete('inconnu');
      expect(r.isLeft(), isTrue);
      r.leftMap((f) => expect(f, isA<NotFoundFailure>()));
    });
  });

  group('openBox factory (prod path, sans exposer Hive)', () {
    test('ouvre la box du kind et round-trip', () async {
      final store = await HiveZLocalStore.openBox<_Note>(
        kind: 'note',
        fromMap: _Note.fromMap,
        toMap: (n) => n.toMap(),
        idFactory: () => 'p1',
      );
      final saved = (await store.put(const _Note(title: 'prod', count: 7)))
          .getOrElse(() => fail('put'));
      expect(saved.id, 'p1');
      final back = (await store.getById('p1')).getOrElse(() => fail('getById'));
      expect(back.title, 'prod');
      // dispose ferme la box POSSÉDÉE (fire-and-forget, contrat void). LOW-2 :
      // au lieu d'un délai fixe fragile, on synchronise DÉTERMINISTIQUEMENT sur
      // la fin RÉELLE de la fermeture (Future capturé en test) avant que
      // tearDown n'appelle Hive.close() (évite une double-fermeture concurrente).
      store.dispose();
      expect(store.closedForTest, isNotNull,
          reason: 'dispose() capture le Future de fermeture de la box possédée');
      await store.closedForTest;
    });
  });

  group('MEDIUM-2 — persistance DISQUE réelle (close → reopen)', () {
    test('put → close box → reopen (même nom) → getById/getAll restitue',
        () async {
      const boxName = 'zcrud_note_persist';
      // Session 1 : écrit puis FERME la box (flush sur disque).
      final box1 = await Hive.openBox<dynamic>(boxName);
      final store1 = _store(box1, idFactory: () => 'persist1');
      final saved = (await store1.put(
        const _Note(title: 'durable', count: 5, tags: <String>['x']),
      ))
          .getOrElse(() => fail('put'));
      expect(saved.id, 'persist1');
      await box1.close();

      // Session 2 : ROUVRE une NOUVELLE box sur le MÊME nom (relit le fichier
      // .hive du disque) et vérifie que l'entité a survécu au cycle disque —
      // round-trip JSON PERSISTANT réel, pas seulement le cache en-session.
      final box2 = await Hive.openBox<dynamic>(boxName);
      final store2 = _store(box2);
      final back = (await store2.getById('persist1'))
          .getOrElse(() => fail('getById après reopen'));
      expect(back, equals(saved),
          reason: 'entité identique après close→reopen disque');
      final all = (await store2.getAll())
          .getOrElse(() => fail('getAll après reopen'));
      expect(all.map((n) => n.id), <String>['persist1']);
      await box2.close();
    });
  });

  group('MEDIUM-1 — anti-fuite : onCancel libère la souscription source', () {
    test('annuler l\'abonnement watchAll libère sub + controller (pas de fuite)',
        () async {
      final box = await openBox();
      final store = _store(box);
      expect(store.activeSourceSubscriptions, 0);
      expect(store.activeStreamControllers, 0);

      final sub = store.watchAll().listen((_) {});
      // laisse onListen s'exécuter (seed + abonnement box.watch()).
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.activeSourceSubscriptions, 1,
          reason: 'onListen a créé l\'abonnement source `box.watch()`');
      expect(store.activeStreamControllers, 1);

      await sub.cancel(); // déclenche onCancel (attendu par cancel()).
      expect(store.activeSourceSubscriptions, 0,
          reason: 'onCancel annule + retire la souscription source (anti-fuite)');
      expect(store.activeStreamControllers, 0,
          reason: 'onCancel retire le StreamController');
      store.dispose();
    });

    test('N cycles subscribe/cancel ne laissent AUCUNE ressource vivante',
        () async {
      final box = await openBox();
      final store = _store(box);
      for (var i = 0; i < 5; i++) {
        final sub = store.watchAll().listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await sub.cancel();
      }
      expect(store.activeSourceSubscriptions, 0,
          reason: 'croissance bornée : rien ne s\'accumule (MEDIUM-1)');
      expect(store.activeStreamControllers, 0);
      store.dispose();
    });
  });

  group('ZResult = Either<ZFailure,T> (contrat AD-11)', () {
    test('getAll renvoie un Right côté succès', () async {
      final box = await openBox();
      final store = _store(box);
      final r = await store.getAll();
      expect(r, isA<Right<ZFailure, List<_Note>>>());
    });
  });

  // ─────────────── AC10 / AC3 — Gates d'ISOLATION (AD-5 / AD-1) ───────────────

  group('AC10 — isolation : aucun type Hive dans une signature publique', () {
    test('aucun symbole hive dans une déclaration de membre public exporté', () {
      final pkg = _pkgDir();
      // Le barrel ne ré-exporte AUCUN paquet hive/firebase.
      final barrel =
          File('${pkg.path}/lib/zcrud_firestore.dart').readAsStringSync();
      for (final bad in <String>['hive', 'hive_flutter', 'cloud_firestore']) {
        expect(RegExp("export\\s+'package:$bad").hasMatch(barrel), isFalse,
            reason: 'Le barrel ne doit PAS ré-exporter package:$bad (AD-5).');
      }

      const forbidden = <String>[
        r'\bBox\b',
        r'\bLazyBox\b',
        r'\bHiveObject\b',
        r'\bHiveInterface\b',
        r'\bHiveList\b',
        r'\bBoxEvent\b',
        r'\bHiveError\b',
        r'\bBoxCollection\b',
      ];
      final forbiddenRe = RegExp(forbidden.join('|'));
      // Ligne de déclaration de membre public : indentée d'EXACTEMENT 2 espaces,
      // nom NON préfixé `_`, suivie de `(`/`=>`/`{`/`get ` (miroir gate E5-1).
      // Les params de constructeur (indent 4 = couture DI `Box`) et les membres
      // privés (`_box`) sont exclus par construction.
      final publicMember = RegExp(
        r'^  (?:@override\s+)?(?:factory\s+|static\s+)?[A-Za-z_][\w<>,.\?\s\[\]]*?\b([A-Za-z][\w]*)\s*(?:\(|=>|\{|get\s)',
      );
      final exported = <String>[
        'lib/src/data/hive_z_local_store.dart',
        'lib/src/data/firestore_z_remote_store.dart',
      ];
      var publicSignatureLinesScanned = 0;
      final offenders = <String>[];
      for (final rel in exported) {
        final lines = File('${pkg.path}/$rel').readAsLinesSync();
        var inBlockComment = false;
        for (final raw in lines) {
          final trimmed = raw.trimLeft();
          if (inBlockComment) {
            if (trimmed.contains('*/')) inBlockComment = false;
            continue;
          }
          if (trimmed.startsWith('/*')) {
            if (!trimmed.contains('*/')) inBlockComment = true;
            continue;
          }
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          final m = publicMember.firstMatch(raw);
          if (m == null) continue;
          if (m.group(1)!.startsWith('_')) continue;
          publicSignatureLinesScanned++;
          if (forbiddenRe.hasMatch(raw)) offenders.add(raw.trim());
        }
      }
      expect(publicSignatureLinesScanned, greaterThan(3),
          reason: 'Le scanner doit avoir vu des signatures publiques (put/'
              'getAll/getById/...) — sinon FAUX VERT.');
      expect(offenders, isEmpty,
          reason: 'Type Hive interdit dans une signature publique (AD-5):\n'
              '${offenders.join('\n')}');
    });

    test('firestore_z_remote_store n\'importe PAS cloud_firestore ni hive', () {
      final pkg = _pkgDir();
      final src = File(
              '${pkg.path}/lib/src/data/firestore_z_remote_store.dart')
          .readAsStringSync();
      expect(src.contains("package:cloud_firestore"), isFalse);
      expect(src.contains("package:hive"), isFalse);
    });
  });

  group('AC3 — zcrud_core ne dépend NI de Hive NI de Firebase', () {
    test('pubspec de zcrud_core sans hive/firebase/cloud_firestore', () {
      final core = _coreDir();
      final lines = File('${core.path}/pubspec.yaml').readAsLinesSync();
      const depBlocks = <String>[
        'dependencies:',
        'dev_dependencies:',
        'dependency_overrides:',
      ];
      var inDeps = false;
      final offenders = <String>[];
      for (final raw in lines) {
        final line = raw.replaceFirst(RegExp(r'#.*$'), '').trimRight();
        if (line.isEmpty) continue;
        if (depBlocks.contains(line.trim())) {
          inDeps = true;
          continue;
        }
        if (RegExp(r'^[A-Za-z_]').hasMatch(line) &&
            !depBlocks.contains(line.trim())) {
          inDeps = false;
          continue;
        }
        if (!inDeps) continue;
        final m = RegExp(r'^\s{2,}([A-Za-z0-9_]+)\s*:').firstMatch(line);
        if (m == null) continue;
        final dep = m.group(1)!;
        if (dep.contains('hive') ||
            dep.contains('firebase') ||
            dep.contains('cloud_firestore')) {
          offenders.add(dep);
        }
      }
      expect(offenders, isEmpty,
          reason: 'zcrud_core ne doit dépendre NI de Hive NI de Firebase '
              '(AD-1/AD-5). Trouvé : $offenders');
    });
  });
}

/// Localise le répertoire du package `zcrud_firestore` quel que soit le CWD.
Directory _pkgDir() {
  for (final base in <String>['', 'packages/zcrud_firestore/']) {
    final dir = Directory(base.isEmpty ? '.' : base);
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/lib/src/data').existsSync()) {
      return dir;
    }
  }
  fail('Répertoire zcrud_firestore introuvable depuis ${Directory.current.path}');
}

/// Localise le répertoire du package `zcrud_core` (lecture SEULE de son pubspec).
Directory _coreDir() {
  for (final base in <String>[
    '../zcrud_core',
    'packages/zcrud_core',
    '../../packages/zcrud_core',
  ]) {
    final dir = Directory(base);
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
  }
  fail('Répertoire zcrud_core introuvable depuis ${Directory.current.path}');
}
