import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Sous-classe tierce fictive : PROUVE l'extensibilité inter-package de
/// `ZFailure` (AC6 — la base est `abstract`, PAS `sealed`).
class _AppSpecificFailure extends ZFailure {
  const _AppSpecificFailure(super.message, {this.code});
  final int? code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AppSpecificFailure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => Object.hash(runtimeType, message, code);
}

void main() {
  group('ZFailure — égalité de valeur (AC7)', () {
    test('réflexivité : a == a', () {
      const a = ZDomainFailure('boom');
      expect(a == a, isTrue);
    });

    test('symétrie + hashCode cohérent pour champs égaux', () {
      const a = ZDomainFailure('boom');
      const b = ZDomainFailure('boom');
      expect(a == b, isTrue);
      expect(b == a, isTrue);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('champs différents ⇒ inégal', () {
      expect(const ZDomainFailure('a') == const ZDomainFailure('b'), isFalse);
    });

    test('discrimination par runtimeType (même message ⇒ inégal)', () {
      expect(const ZDomainFailure('x') == const ZCacheFailure('x'), isFalse);
      expect(const ZServerFailure('x') == const ZNotFoundFailure('x'), isFalse);
    });

    test('les 4 sous-classes canoniques sont égales à elles-mêmes par valeur',
        () {
      expect(const ZCacheFailure('c'), equals(const ZCacheFailure('c')));
      expect(const ZServerFailure('s'), equals(const ZServerFailure('s')));
      expect(const ZDomainFailure('d'), equals(const ZDomainFailure('d')));
    });

    test('message est exposé', () {
      expect(const ZDomainFailure('msg').message, 'msg');
    });
  });

  group('ZNotFoundFailure — champs propres dans ==/hashCode', () {
    test('id/entity égaux ⇒ égal + hashCode identique', () {
      const a = ZNotFoundFailure('nope', id: '42', entity: 'Card');
      const b = ZNotFoundFailure('nope', id: '42', entity: 'Card');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('id différent ⇒ inégal (message identique)', () {
      const a = ZNotFoundFailure('nope', id: '1');
      const b = ZNotFoundFailure('nope', id: '2');
      expect(a == b, isFalse);
    });

    test('entity différent ⇒ inégal', () {
      const a = ZNotFoundFailure('nope', entity: 'Card');
      const b = ZNotFoundFailure('nope', entity: 'Folder');
      expect(a == b, isFalse);
    });
  });

  group('ZFailure — usage dans Set/Map (cohérence hashCode)', () {
    test('déduplication dans un Set', () {
      // Construit depuis une liste pour exercer la dédup à l'exécution
      // (deux ZDomainFailure('x') égaux ⇒ une seule entrée).
      final failures = <ZFailure>[
        ZDomainFailure('x'.toString()),
        ZDomainFailure('x'.toString()),
        ZCacheFailure('x'.toString()),
      ];
      expect(failures.toSet().length, 2);
    });

    test('clé de Map stable', () {
      final map = <ZFailure, int>{const ZServerFailure('e'): 1};
      expect(map[const ZServerFailure('e')], 1);
    });
  });

  group('ZFailure — extensibilité inter-package (AC6)', () {
    test('une sous-classe tierce compile et respecte l égalité', () {
      const ZFailure a = _AppSpecificFailure('oops', code: 7);
      const ZFailure b = _AppSpecificFailure('oops', code: 7);
      expect(a, equals(b));
      expect(a == const _AppSpecificFailure('oops', code: 8), isFalse);
      // Discrimination vs une failure canonique de même message.
      expect(a == const ZDomainFailure('oops'), isFalse);
    });
  });
}
