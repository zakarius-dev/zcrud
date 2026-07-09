import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// Implémentations minimales de test pour exercer les contrats abstraits.
class _Card extends ZEntity {
  const _Card(this._id);
  final String? _id;
  @override
  String? get id => _id;
}

class _TreeNode extends ZNode {
  const _TreeNode(this._id);
  final String _id;
  @override
  String get id => _id;
}

class _Doc implements ZSyncable {
  const _Doc(this._at);
  final DateTime? _at;
  @override
  DateTime? get updatedAt => _at;
}

void main() {
  group('ZEntity — identité opaque + éphémère (AC2)', () {
    test('id null ⇒ isEphemeral true', () {
      const c = _Card(null);
      expect(c.id, isNull);
      expect(c.isEphemeral, isTrue);
    });

    test('id présent ⇒ isEphemeral false', () {
      const c = _Card('abc');
      expect(c.id, 'abc');
      expect(c.isEphemeral, isFalse);
    });
  });

  group('ZNode — id non-null (AC3)', () {
    test('expose un id non-null', () {
      const n = _TreeNode('n1');
      expect(n.id, 'n1');
    });
  });

  group('ZSyncable — clé LWW (AC4)', () {
    test('expose updatedAt nullable', () {
      final at = DateTime.utc(2026);
      expect(_Doc(at).updatedAt, at);
      expect(const _Doc(null).updatedAt, isNull);
    });
  });
}
