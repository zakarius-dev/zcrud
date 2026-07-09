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
      const a = DomainFailure('boom');
      expect(a == a, isTrue);
    });

    test('symétrie + hashCode cohérent pour champs égaux', () {
      const a = DomainFailure('boom');
      const b = DomainFailure('boom');
      expect(a == b, isTrue);
      expect(b == a, isTrue);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('champs différents ⇒ inégal', () {
      expect(const DomainFailure('a') == const DomainFailure('b'), isFalse);
    });

    test('discrimination par runtimeType (même message ⇒ inégal)', () {
      expect(const DomainFailure('x') == const CacheFailure('x'), isFalse);
      expect(const ServerFailure('x') == const NotFoundFailure('x'), isFalse);
    });

    test('les 4 sous-classes canoniques sont égales à elles-mêmes par valeur',
        () {
      expect(const CacheFailure('c'), equals(const CacheFailure('c')));
      expect(const ServerFailure('s'), equals(const ServerFailure('s')));
      expect(const DomainFailure('d'), equals(const DomainFailure('d')));
    });

    test('message est exposé', () {
      expect(const DomainFailure('msg').message, 'msg');
    });
  });

  group('NotFoundFailure — champs propres dans ==/hashCode', () {
    test('id/entity égaux ⇒ égal + hashCode identique', () {
      const a = NotFoundFailure('nope', id: '42', entity: 'Card');
      const b = NotFoundFailure('nope', id: '42', entity: 'Card');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('id différent ⇒ inégal (message identique)', () {
      const a = NotFoundFailure('nope', id: '1');
      const b = NotFoundFailure('nope', id: '2');
      expect(a == b, isFalse);
    });

    test('entity différent ⇒ inégal', () {
      const a = NotFoundFailure('nope', entity: 'Card');
      const b = NotFoundFailure('nope', entity: 'Folder');
      expect(a == b, isFalse);
    });
  });

  group('ZFailure — usage dans Set/Map (cohérence hashCode)', () {
    test('déduplication dans un Set', () {
      // Construit depuis une liste pour exercer la dédup à l'exécution
      // (deux DomainFailure('x') égaux ⇒ une seule entrée).
      final failures = <ZFailure>[
        DomainFailure('x'.toString()),
        DomainFailure('x'.toString()),
        CacheFailure('x'.toString()),
      ];
      expect(failures.toSet().length, 2);
    });

    test('clé de Map stable', () {
      final map = <ZFailure, int>{const ServerFailure('e'): 1};
      expect(map[const ServerFailure('e')], 1);
    });
  });

  group('ZFailure — extensibilité inter-package (AC6)', () {
    test('une sous-classe tierce compile et respecte l égalité', () {
      const ZFailure a = _AppSpecificFailure('oops', code: 7);
      const ZFailure b = _AppSpecificFailure('oops', code: 7);
      expect(a, equals(b));
      expect(a == const _AppSpecificFailure('oops', code: 8), isFalse);
      // Discrimination vs une failure canonique de même message.
      expect(a == const DomainFailure('oops'), isFalse);
    });
  });
}
