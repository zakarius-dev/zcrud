// Tests E5-3 : `ZSyncEntry<T>` — value object appariant une entité et son
// `ZSyncMeta` (accès dérivés id/updatedAt/isDeleted, égalité de valeur, transport
// des tombstones).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _Note extends ZEntity {
  const _Note({this.id, required this.title});

  @override
  final String? id;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is _Note && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);

  @override
  String toString() => '_Note($id, $title)';
}

void main() {
  final t = DateTime.utc(2026, 1, 1, 12);

  group('accès dérivés', () {
    test('id/updatedAt/isDeleted dérivés de entity + meta', () {
      final e = ZSyncEntry<_Note>(
        entity: const _Note(id: 'a', title: 'x'),
        meta: ZSyncMeta(updatedAt: t, isDeleted: false),
      );
      expect(e.id, 'a');
      expect(e.updatedAt, t);
      expect(e.isDeleted, isFalse);
    });

    test('éphémère → id null', () {
      final e = ZSyncEntry<_Note>(
        entity: const _Note(title: 'x'),
        meta: const ZSyncMeta(),
      );
      expect(e.id, isNull);
      expect(e.updatedAt, isNull);
      expect(e.isDeleted, isFalse);
    });
  });

  group('transport des tombstones', () {
    test('une entrée soft-deletée reste valide (isDeleted=true, entity décodée)',
        () {
      final e = ZSyncEntry<_Note>(
        entity: const _Note(id: 'a', title: 'métier'),
        meta: ZSyncMeta(updatedAt: t, isDeleted: true),
      );
      expect(e.isDeleted, isTrue);
      expect(e.entity.title, 'métier', reason: 'le corps métier survit');
    });
  });

  group('égalité de valeur', () {
    test('== / hashCode sur (entity, meta)', () {
      final a = ZSyncEntry<_Note>(
        entity: const _Note(id: 'a', title: 'x'),
        meta: ZSyncMeta(updatedAt: t),
      );
      final b = ZSyncEntry<_Note>(
        entity: const _Note(id: 'a', title: 'x'),
        meta: ZSyncMeta(updatedAt: t),
      );
      final c = ZSyncEntry<_Note>(
        entity: const _Note(id: 'a', title: 'y'),
        meta: ZSyncMeta(updatedAt: t),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });
}
