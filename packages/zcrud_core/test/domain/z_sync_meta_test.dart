import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  final ts = DateTime.utc(2026, 7, 9, 12, 30, 45);

  group('ZSyncMeta — round-trip JSON (AC5)', () {
    test('toJson émet les clés snake_case + ISO-8601', () {
      final json = ZSyncMeta(updatedAt: ts, isDeleted: true).toJson();
      expect(json.keys.toSet(), {'updated_at', 'is_deleted'});
      expect(json['updated_at'], ts.toIso8601String());
      expect(json['is_deleted'], true);
    });

    test('round-trip toJson → fromJson préserve la valeur', () {
      final original = ZSyncMeta(updatedAt: ts, isDeleted: true);
      final restored = ZSyncMeta.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('updatedAt null sérialisé en null', () {
      final json = const ZSyncMeta().toJson();
      expect(json['updated_at'], isNull);
      expect(json['is_deleted'], false);
    });
  });

  group('ZSyncMeta — désérialisation défensive (AC5, AD-10)', () {
    test('map vide ⇒ défauts sûrs, sans throw', () {
      final meta = ZSyncMeta.fromJson(<String, dynamic>{});
      expect(meta.updatedAt, isNull);
      expect(meta.isDeleted, isFalse);
    });

    test('updated_at corrompu ⇒ null, sans throw', () {
      final meta = ZSyncMeta.fromJson({'updated_at': 'garbage-not-a-date'});
      expect(meta.updatedAt, isNull);
    });

    test('updated_at de type inattendu ⇒ null, sans throw', () {
      expect(ZSyncMeta.fromJson({'updated_at': 12345}).updatedAt, isNull);
      expect(ZSyncMeta.fromJson({'updated_at': null}).updatedAt, isNull);
    });

    test('is_deleted de type inattendu (String) ⇒ false, sans throw', () {
      expect(ZSyncMeta.fromJson({'is_deleted': 'true'}).isDeleted, isFalse);
      expect(ZSyncMeta.fromJson({'is_deleted': 1}).isDeleted, isFalse);
    });

    test('valeurs valides parsées correctement', () {
      final meta = ZSyncMeta.fromJson({
        'updated_at': ts.toIso8601String(),
        'is_deleted': true,
      });
      expect(meta.updatedAt, ts);
      expect(meta.isDeleted, isTrue);
    });
  });

  group('ZSyncMeta — égalité de valeur', () {
    test('mêmes champs ⇒ égal + hashCode identique', () {
      final a = ZSyncMeta(updatedAt: ts, isDeleted: true);
      final b = ZSyncMeta(updatedAt: ts, isDeleted: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('champs différents ⇒ inégal', () {
      expect(ZSyncMeta(updatedAt: ts) == const ZSyncMeta(), isFalse);
      expect(
        ZSyncMeta(updatedAt: ts, isDeleted: true) ==
            ZSyncMeta(updatedAt: ts, isDeleted: false),
        isFalse,
      );
    });
  });

  group('ZSyncMeta — clés réservées AD-19 (ES-1.3, AC3)', () {
    test('kUpdatedAt/kIsDeleted sont les clés snake_case canoniques', () {
      expect(ZSyncMeta.kUpdatedAt, 'updated_at');
      expect(ZSyncMeta.kIsDeleted, 'is_deleted');
    });

    test('reservedKeys = {updated_at, is_deleted} — définition machine AD-19',
        () {
      expect(ZSyncMeta.reservedKeys, {'updated_at', 'is_deleted'});
    });

    test('toJson n\'émet QUE les clés réservées', () {
      final json = ZSyncMeta(updatedAt: ts, isDeleted: true).toJson();
      expect(json.keys.toSet(), ZSyncMeta.reservedKeys);
    });

    test('stripReserved retire updated_at et is_deleted, garde le reste', () {
      final stripped = ZSyncMeta.stripReserved(<String, dynamic>{
        'title': 't',
        'updated_at': ts.toIso8601String(),
        'is_deleted': true,
        'related_topics': <String>['x'],
      });
      expect(stripped.containsKey('updated_at'), isFalse);
      expect(stripped.containsKey('is_deleted'), isFalse);
      expect(stripped['title'], 't');
      expect(stripped['related_topics'], <String>['x']);
    });

    test('stripReserved est pure : ne mute JAMAIS son entrée', () {
      final source = <String, dynamic>{
        'title': 't',
        'updated_at': ts.toIso8601String(),
        'is_deleted': false,
      };
      final stripped = ZSyncMeta.stripReserved(source);
      // L'entrée reste intacte…
      expect(source.keys.toSet(), {'title', 'updated_at', 'is_deleted'});
      // …et la sortie est une NOUVELLE map (mutable, indépendante).
      expect(identical(source, stripped), isFalse);
      stripped['x'] = 1;
      expect(source.containsKey('x'), isFalse);
    });

    test('stripReserved : map vide → map vide ; sans clé réservée → copie égale',
        () {
      expect(ZSyncMeta.stripReserved(<String, dynamic>{}), isEmpty);
      final plain = <String, dynamic>{'a': 1, 'b': 'deux'};
      expect(ZSyncMeta.stripReserved(plain), equals(plain));
    });
  });

  group('ZSyncMeta — copyWith (sentinelle reset-null)', () {
    test('omettre updatedAt conserve la valeur', () {
      final meta = ZSyncMeta(updatedAt: ts, isDeleted: true);
      final copy = meta.copyWith(isDeleted: false);
      expect(copy.updatedAt, ts);
      expect(copy.isDeleted, isFalse);
    });

    test('passer updatedAt: null remet explicitement à null', () {
      final meta = ZSyncMeta(updatedAt: ts);
      final copy = meta.copyWith(updatedAt: null);
      expect(copy.updatedAt, isNull);
    });

    test('remplacer updatedAt par une nouvelle valeur', () {
      final other = DateTime.utc(2027);
      final copy = ZSyncMeta(updatedAt: ts).copyWith(updatedAt: other);
      expect(copy.updatedAt, other);
    });
  });
}
