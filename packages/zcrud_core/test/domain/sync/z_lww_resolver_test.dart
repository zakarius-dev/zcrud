// Tests E5-3 : `ZLwwResolver` — résolveur Last-Write-Wins PUR (déterministe,
// aucune horloge/I/O). Couvre AC2 : présence unilatérale, plus grand updatedAt
// gagne, null = plus ancien, égalité → local fait foi (noop si états identiques).
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

ZSyncEntry<_Note> _entry(
  String id,
  String title, {
  DateTime? at,
  bool deleted = false,
}) =>
    ZSyncEntry<_Note>(
      entity: _Note(id: id, title: title),
      meta: ZSyncMeta(updatedAt: at, isDeleted: deleted),
    );

void main() {
  const resolver = ZLwwResolver();
  final older = DateTime.utc(2026, 1, 1);
  final newer = DateTime.utc(2026, 6, 1);

  group('présence unilatérale', () {
    test('local seul → pushLocalToRemote', () {
      final d = resolver.resolve<_Note>(_entry('a', 'x', at: older), null);
      expect(d.action, ZLwwAction.pushLocalToRemote);
      expect(d.entry!.id, 'a');
    });

    test('remote seul → adoptRemoteIntoLocal', () {
      final d = resolver.resolve<_Note>(null, _entry('a', 'x', at: older));
      expect(d.action, ZLwwAction.adoptRemoteIntoLocal);
      expect(d.entry!.id, 'a');
    });

    test('aucun côté → noop (défensif)', () {
      final d = resolver.resolve<_Note>(null, null);
      expect(d.action, ZLwwAction.noop);
      expect(d.entry, isNull);
    });
  });

  group('le plus grand updatedAt gagne', () {
    test('distant plus récent → adoptRemoteIntoLocal', () {
      final d = resolver.resolve<_Note>(
        _entry('a', 'local', at: older),
        _entry('a', 'remote', at: newer),
      );
      expect(d.action, ZLwwAction.adoptRemoteIntoLocal);
      expect(d.entry!.entity.title, 'remote');
    });

    test('local plus récent → pushLocalToRemote', () {
      final d = resolver.resolve<_Note>(
        _entry('a', 'local', at: newer),
        _entry('a', 'remote', at: older),
      );
      expect(d.action, ZLwwAction.pushLocalToRemote);
      expect(d.entry!.entity.title, 'local');
    });
  });

  group('null = plus ancien', () {
    test('local null perd contre distant daté → adopt', () {
      final d = resolver.resolve<_Note>(
        _entry('a', 'local'),
        _entry('a', 'remote', at: older),
      );
      expect(d.action, ZLwwAction.adoptRemoteIntoLocal);
    });

    test('distant null perd contre local daté → push', () {
      final d = resolver.resolve<_Note>(
        _entry('a', 'local', at: older),
        _entry('a', 'remote'),
      );
      expect(d.action, ZLwwAction.pushLocalToRemote);
    });
  });

  group('égalité stricte → le LOCAL fait foi', () {
    test('états identiques (même corps + is_deleted) → noop', () {
      final d = resolver.resolve<_Note>(
        _entry('a', 'x', at: older),
        _entry('a', 'x', at: older),
      );
      expect(d.action, ZLwwAction.noop);
    });

    test('deux updatedAt null + états identiques → noop', () {
      final d = resolver.resolve<_Note>(
        _entry('a', 'x'),
        _entry('a', 'x'),
      );
      expect(d.action, ZLwwAction.noop);
    });

    test('égalité mais états DIFFÉRENTS (corps) → push local (autoritaire)', () {
      final d = resolver.resolve<_Note>(
        _entry('a', 'local', at: older),
        _entry('a', 'remote', at: older),
      );
      expect(d.action, ZLwwAction.pushLocalToRemote);
      expect(d.entry!.entity.title, 'local');
    });

    test('égalité mais is_deleted DIFFÉRENT → push local (autoritaire)', () {
      final d = resolver.resolve<_Note>(
        _entry('a', 'x', at: older),
        _entry('a', 'x', at: older, deleted: true),
      );
      expect(d.action, ZLwwAction.pushLocalToRemote);
      expect(d.entry!.isDeleted, isFalse,
          reason: 'le local (vivant) réaligne le distant');
    });
  });

  group('tombstone LWW', () {
    test('tombstone distant plus récent → adopt (soft-delete adopté localement)',
        () {
      final d = resolver.resolve<_Note>(
        _entry('a', 'x', at: older),
        _entry('a', 'x', at: newer, deleted: true),
      );
      expect(d.action, ZLwwAction.adoptRemoteIntoLocal);
      expect(d.entry!.isDeleted, isTrue);
    });

    test('tombstone local plus récent → push (propagé au distant)', () {
      final d = resolver.resolve<_Note>(
        _entry('a', 'x', at: newer, deleted: true),
        _entry('a', 'x', at: older),
      );
      expect(d.action, ZLwwAction.pushLocalToRemote);
      expect(d.entry!.isDeleted, isTrue);
    });
  });

  group('ZLwwDecision — égalité de valeur', () {
    test('== sur (action, entry)', () {
      final e = _entry('a', 'x', at: older);
      expect(ZLwwDecision<_Note>.pushLocalToRemote(e),
          equals(ZLwwDecision<_Note>.pushLocalToRemote(e)));
      expect(const ZLwwDecision<_Note>.noop(),
          equals(const ZLwwDecision<_Note>.noop()));
    });
  });
}
