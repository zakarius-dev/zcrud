// Story ES-9.4 — AC6 : verrou AD-19.1 (M-1) sur CHAQUE porteur d'`extra` de la
// surface de partage. Les clés de sync RÉSERVÉES (updated_at/is_deleted) sont
// écartées À LA LECTURE via l'accesseur (slot `_extra` + `zSanitizeExtra`).
//
// 🔴 LOAD-BEARING : neutraliser un accesseur en prod (`get extra => _extra;`) fait
// ROUGIR ce test. `reserved_keys_gate` n'importe PAS `zcrud_study` ⇒ SEUL ce test
// package-local couvre ces porteurs. Runner R14.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

void main() {
  const raw = <String, dynamic>{
    'updated_at': '2026-01-01T00:00:00Z',
    'is_deleted': true,
    'legit': 42,
  };

  void expectSanitized(Map<String, dynamic> extra) {
    expect(extra.containsKey('updated_at'), isFalse,
        reason: 'updated_at (clé de sync réservée) doit être écartée');
    expect(extra.containsKey('is_deleted'), isFalse,
        reason: 'is_deleted (clé de sync réservée) doit être écartée');
    expect(extra['legit'], 42);
    expect(extra.length, 1);
  }

  test('ZStudyMembership.extra écarte les clés de sync (AD-19.1)', () {
    expectSanitized(const ZStudyMembership(extra: raw).extra);
  });

  test('ZShareLink.extra écarte les clés de sync (AD-19.1)', () {
    expectSanitized(const ZShareLink(extra: raw).extra);
  });

  test('ZPublicStudyFolder.extra écarte les clés de sync (AD-19.1)', () {
    expectSanitized(const ZPublicStudyFolder(extra: raw).extra);
  });

  test('ZStudyFolderReport.extra écarte les clés de sync (AD-19.1)', () {
    expectSanitized(const ZStudyFolderReport(extra: raw).extra);
  });

  test('deux instances ne différant que par une clé réservée sont ÉGALES', () {
    const a = ZShareLink(id: 'l', extra: <String, dynamic>{'legit': 1});
    const b = ZShareLink(
      id: 'l',
      extra: <String, dynamic>{'legit': 1, 'updated_at': 'x', 'is_deleted': true},
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('toJson ne réémet JAMAIS une clé réservée (AD-19.1)', () {
    final json = const ZStudyMembership(extra: raw).toJson();
    expect(json.containsKey('updated_at'), isFalse);
    expect(json.containsKey('is_deleted'), isFalse);
    expect(json['legit'], 42);
  });
}
