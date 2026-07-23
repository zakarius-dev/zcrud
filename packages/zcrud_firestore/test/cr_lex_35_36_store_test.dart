// CR-LEX-35 — `ZLocalStore` n'offrait aucune purge par `id` : un hôte dont la
// sémantique locale est « purger » (annuler une écriture qui n'aurait pas dû
// avoir lieu) ne pouvait que poser un tombstone, propagé au cloud et gardé
// indéfiniment. `purge(id)` supprime physiquement, sans tombstone.
//
// CR-LEX-36 — la clé LWW `updated_at` était estampillée en dur à
// `DateTime.now()` client. Deux appareils aux horloges désynchronisées
// produisaient un ordre d'arbitrage faux, et l'hôte n'avait AUCUN levier. Le
// clock injectable (`ZClock`) est ce levier — et rend le skew reproductible.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

class _Note extends ZEntity {
  const _Note({this.id, required this.title});
  @override
  final String? id;
  final String title;
  static _Note fromMap(Map<String, dynamic> m) =>
      _Note(id: m['id'] as String?, title: m['title'] as String? ?? '');
  Map<String, dynamic> toMap() =>
      <String, dynamic>{if (id != null) 'id': id, 'title': title};
  @override
  bool operator ==(Object o) => o is _Note && o.id == id && o.title == title;
  @override
  int get hashCode => Object.hash(id, title);
}

HiveZLocalStore<_Note> _store(Box<dynamic> box, {ZClock? clock}) =>
    HiveZLocalStore<_Note>(
      box: box,
      kind: 'note',
      fromMap: _Note.fromMap,
      toMap: (n) => n.toMap(),
      idFactory: () => 'gen',
      clock: clock,
    );

void main() {
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('hive_crlex3536');
    Hive.init(tmp.path);
  });
  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });
  Future<Box<dynamic>> openBox() => Hive.openBox<dynamic>('notes');

  group('🔴 CR-LEX-35 — purge par identité, SANS tombstone', () {
    test('purge supprime physiquement (aucune entrée résiduelle)', () async {
      final box = await openBox();
      final store = _store(box);
      await store.put(const _Note(id: 'x1', title: 'T'));
      expect(box.containsKey('x1'), isTrue);

      final res = await store.purge('x1');
      expect(res.isRight(), isTrue);
      expect(box.containsKey('x1'), isFalse,
          reason: 'purge = box.delete, aucune trace conservée');
    });

    test('🔴 purge ne laisse PAS de tombstone (contraste softDelete)', () async {
      final box = await openBox();
      final store = _store(box);

      // softDelete : l'entrée SUBSISTE (tombstone propagé).
      await store.put(const _Note(id: 'a', title: 'T'));
      await store.softDelete('a');
      expect(box.containsKey('a'), isTrue,
          reason: 'softDelete conserve un tombstone à propager');
      expect((jsonDecode(box.get('a') as String) as Map)['is_deleted'], true);

      // purge : rien ne subsiste, donc rien à propager.
      await store.put(const _Note(id: 'b', title: 'T'));
      await store.purge('b');
      expect(box.containsKey('b'), isFalse);
    });

    test('purge est IDEMPOTENTE (id absent → succès, pas d\'erreur)', () async {
      final box = await openBox();
      final store = _store(box);
      final res = await store.purge('jamais_ecrit');
      expect(res.isRight(), isTrue,
          reason: 'purger ce qui n\'existe pas est un succès, pas un NotFound');
    });

    test('une entrée purgée disparaît des lectures', () async {
      final box = await openBox();
      final store = _store(box);
      await store.put(const _Note(id: 'x1', title: 'T'));
      await store.purge('x1');
      final all = (await store.getAll()).getOrElse(() => throw StateError('l'));
      expect(all, isEmpty);
    });
  });

  group('🔴 CR-LEX-36 — le clock est un levier, et rend le skew reproductible',
      () {
    String updatedAt(Box<dynamic> box, String id) =>
        (jsonDecode(box.get(id) as String) as Map)['updated_at'] as String;

    test('l\'horloge injectée détermine `updated_at` (pas l\'horloge système)',
        () async {
      final box = await openBox();
      final DateTime fige = DateTime.utc(2020, 1, 1, 12);
      final store = _store(box, clock: ZSystemClock.fixed(fige));
      await store.put(const _Note(id: 'x1', title: 'T'));
      expect(updatedAt(box, 'x1'), fige.toIso8601String(),
          reason: 'la clé LWW vient du clock injecté, plus de DateTime.now() en dur');
    });

    test('🔴 le SKEW est reproductible : l\'horloge en avance « gagne »', () async {
      // Le cœur de CR-36 : l'appareil dont l'horloge AVANCE porte un updated_at
      // supérieur, donc gagne le LWW — même s'il a écrit AVANT en temps réel.
      final box = await openBox();
      final DateTime reel = DateTime.utc(2026, 6, 1, 10);
      final enAvance = _store(box,
          clock: ZSystemClock.fixed(reel.add(const Duration(hours: 2))));
      final aLHeure = _store(box, clock: ZSystemClock.fixed(reel));

      await enAvance.put(const _Note(id: 'x1', title: 'écrit EN PREMIER'));
      final tApres = updatedAt(box, 'x1');
      await aLHeure.put(const _Note(id: 'x2', title: 'écrit APRÈS'));
      final tAvant = updatedAt(box, 'x2');

      expect(tApres.compareTo(tAvant) > 0, isTrue,
          reason: 'l\'écriture réellement ANTÉRIEURE porte l\'estampille SUPÉRIEURE '
              '— c\'est exactement l\'inversion LWW que le skew provoque');
    });

    test('le levier : une horloge CORRIGÉE rétablit l\'ordre', () async {
      // Un hôte qui mesure son offset serveur peut injecter une horloge
      // corrigée — le levier app-side qui manquait totalement.
      final box = await openBox();
      final DateTime base = DateTime.utc(2026, 6, 1, 10);
      // Deux appareils, l'un avec offset +2h MESURÉ et CORRIGÉ (donc annulé).
      final corrige = _store(box, clock: ZSystemClock.fixed(base));
      final aLHeure = _store(box,
          clock: ZSystemClock.fixed(base.add(const Duration(seconds: 1))));
      await corrige.put(const _Note(id: 'x1', title: 'premier'));
      await aLHeure.put(const _Note(id: 'x2', title: 'second'));
      expect(updatedAt(box, 'x2').compareTo(updatedAt(box, 'x1')) > 0, isTrue,
          reason: 'horloges corrigées ⇒ l\'ordre réel est respecté');
    });

    test('softDelete estampille AUSSI via le clock (site n°3 de CR-36)', () async {
      final box = await openBox();
      final DateTime fige = DateTime.utc(2020, 1, 1, 12);
      final store = _store(box, clock: ZSystemClock.fixed(fige));
      await store.put(const _Note(id: 'x1', title: 'T'));
      await store.softDelete('x1');
      expect(updatedAt(box, 'x1'), fige.toIso8601String());
    });

    test('défaut inchangé : sans clock injecté, horloge système', () async {
      final box = await openBox();
      final store = _store(box); // pas de clock
      final avant = DateTime.now().toUtc();
      await store.put(const _Note(id: 'x1', title: 'T'));
      final ts = DateTime.parse(updatedAt(box, 'x1'));
      expect(ts.isAfter(avant.subtract(const Duration(seconds: 5))), isTrue,
          reason: 'le défaut reste DateTime.now().toUtc()');
    });
  });
}
