// CR-LEX-34 — `save()` écrasait le document EN TOTALITÉ : un hôte dont l'entité
// ne mappe pas tous les champs `Z` détruisait silencieusement ceux qu'il
// ignorait, dont ceux écrits par un AUTRE hôte. Aucune barrière : le code
// compile, `analyze` est vert, aucun test de round-trip ne rougit — le harnais
// part d'une entité hôte, il ne peut donc jamais construire l'état « un `Z`
// déjà porteur est écrasé ».
//
// `putMerged` déplace le « relire-fusionner » DANS le store, une fois, au lieu
// de le laisser à l'oubli de chaque appelant.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

/// Entité d'hôte A : elle ne connaît que `title`. Elle ignore volontairement
/// `autre_hote` — la clé qu'un hôte B a écrite dans le même document.
class _HoteA extends ZEntity {
  const _HoteA({this.id, required this.title});

  @override
  final String? id;
  final String title;

  static _HoteA fromMap(Map<String, dynamic> m) =>
      _HoteA(id: m['id'] as String?, title: m['title'] as String? ?? '');

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'title': title,
      };

  @override
  bool operator ==(Object other) =>
      other is _HoteA && other.id == id && other.title == title;
  @override
  int get hashCode => Object.hash(id, title);
}

HiveZLocalStore<_HoteA> _store(Box<dynamic> box) => HiveZLocalStore<_HoteA>(
      box: box,
      kind: 'note',
      fromMap: _HoteA.fromMap,
      toMap: (n) => n.toMap(),
      idFactory: () => 'generated',
    );

/// Sème un document BRUT porteur d'une clé d'un autre hôte.
Future<void> _seedAutreHote(Box<dynamic> box, String id) => box.put(
      id,
      jsonEncode(<String, dynamic>{
        'id': id,
        'title': 'ancien titre',
        'autre_hote': <String, dynamic>{'format_version': 2, 'flag': true},
        'is_deleted': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );

Map<String, dynamic> _raw(Box<dynamic> box, String id) =>
    jsonDecode(box.get(id) as String) as Map<String, dynamic>;

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('hive_crlex34');
    Hive.init(tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<Box<dynamic>> openBox() => Hive.openBox<dynamic>('notes');

  group('🔴 CR-LEX-34 — la clé d\'un autre hôte SURVIT à putMerged', () {
    test('putMerged PRÉSERVE `autre_hote` ; put la DÉTRUIT', () async {
      final box = await openBox();
      final store = _store(box);

      // Contrôle NÉGATIF : `put` (l'ancien chemin) écrase → destruction.
      await _seedAutreHote(box, 'x1');
      await store.put(const _HoteA(id: 'x1', title: 'nouveau titre'));
      expect(_raw(box, 'x1').containsKey('autre_hote'), isFalse,
          reason: 'put écrase tout : la clé de l\'autre hôte est perdue (le défaut)');

      // Le correctif : `putMerged` fusionne → survie.
      await _seedAutreHote(box, 'x2');
      final res = await store.putMerged(const _HoteA(id: 'x2', title: 'nouveau titre'));
      expect(res.isRight(), isTrue);
      final merged = _raw(box, 'x2');
      expect(merged['autre_hote'], <String, dynamic>{'format_version': 2, 'flag': true},
          reason: 'la clé de l\'autre hôte doit survivre VERBATIM');
      expect(merged['title'], 'nouveau titre',
          reason: 'le champ mappé par l\'hôte A doit bien être mis à jour');
    });

    test('l\'entité rendue reflète le champ mis à jour', () async {
      final box = await openBox();
      final store = _store(box);
      await _seedAutreHote(box, 'x1');
      final res = await store.putMerged(const _HoteA(id: 'x1', title: 'maj'));
      expect(res.getOrElse(() => throw StateError('left')).title, 'maj');
    });

    test('stable sur trois cycles — aucune érosion de la clé étrangère', () async {
      final box = await openBox();
      final store = _store(box);
      await _seedAutreHote(box, 'x1');
      for (var cycle = 0; cycle < 3; cycle++) {
        await store.putMerged(_HoteA(id: 'x1', title: 'cycle $cycle'));
        expect(_raw(box, 'x1').containsKey('autre_hote'), isTrue,
            reason: 'cycle $cycle');
      }
    });
  });

  group('Bornes et invariants', () {
    test('putMerged sur un id ABSENT crée le document (= put)', () async {
      final box = await openBox();
      final store = _store(box);
      final res = await store.putMerged(const _HoteA(id: 'neuf', title: 'T'));
      expect(res.isRight(), isTrue);
      expect(_raw(box, 'neuf')['title'], 'T');
      expect(_raw(box, 'neuf').containsKey('autre_hote'), isFalse);
    });

    test('putMerged matérialise l\'éphémère (id null → id attribué)', () async {
      final box = await openBox();
      final store = _store(box);
      final saved = (await store.putMerged(const _HoteA(title: 'T')))
          .getOrElse(() => throw StateError('left'));
      expect(saved.id, 'generated');
    });

    test('putMerged RESSUSCITE un soft-deleté (is_deleted → false)', () async {
      final box = await openBox();
      final store = _store(box);
      await store.put(const _HoteA(id: 'x1', title: 'T'));
      await store.softDelete('x1');
      await store.putMerged(const _HoteA(id: 'x1', title: 'T2'));
      expect(_raw(box, 'x1')['is_deleted'], false,
          reason: 'un putMerged EST une mutation utilisateur : save ⇒ vivant');
    });

    test('AD-16 — putMerged réestampille updated_at (mutation, pas merge)',
        () async {
      final box = await openBox();
      final store = _store(box);
      await _seedAutreHote(box, 'x1');
      final avant = _raw(box, 'x1')['updated_at'] as String;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await store.putMerged(const _HoteA(id: 'x1', title: 'T'));
      expect(_raw(box, 'x1')['updated_at'], isNot(avant),
          reason: 'contrairement à applyMerged, putMerged est une vraie écriture');
    });

    test('⚠️ LIMITE ASSUMÉE — le merge est ADDITIF, il n\'efface pas', () async {
      // Un champ que l'hôte OMET (ici `autre_hote`, jamais mappé par _HoteA) ne
      // peut pas être supprimé par putMerged. C'est le prix de la préservation :
      // depuis la seule map de l'entité, « non mappé » et « volontairement vidé »
      // sont indiscernables. Pour effacer, l'appelant utilise `put`.
      final box = await openBox();
      final store = _store(box);
      await _seedAutreHote(box, 'x1');
      await store.putMerged(const _HoteA(id: 'x1', title: 'T'));
      expect(_raw(box, 'x1').containsKey('autre_hote'), isTrue,
          reason: 'putMerged ne peut pas effacer — c\'est documenté, pas un bug');
    });
  });
}
