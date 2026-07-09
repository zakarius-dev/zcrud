// AC6/AC7/AC8 (AD-4 pt.1, AD-10) : `ZExtension` — slot type additif VERSIONNÉ ;
// `guard`/`fromJsonSafe` renvoient `null` sur TOUT payload corrompu/inconnu
// SANS throw ; round-trip d'une extension versionnée. Tests PUR-DART.
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Fausse extension concrète — simule le pattern satellite (E9/E10) :
/// `formatVersion` propre, `toJson`, et `static fromJsonSafe` bâti sur
/// `ZExtension.guard` (repli `null`, jamais throw).
class FakeExt extends ZExtension {
  const FakeExt(this.note);

  /// Reconstruit une [FakeExt] ; `null` si `json` absent, corrompu, ou de
  /// `formatVersion` non gérée — via `ZExtension.guard` (AD-10).
  static FakeExt? fromJsonSafe(Map<String, dynamic>? json) =>
      ZExtension.guard<FakeExt>(() {
        if (json == null) throw const FormatException('null json');
        final version = json['formatVersion'] as int; // throw si type faux
        if (version != _version) {
          throw FormatException('version non gérée: $version');
        }
        return FakeExt(json['note'] as String);
      });

  static const int _version = 1;

  final String note;

  @override
  int get formatVersion => _version;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'formatVersion': _version, 'note': note};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FakeExt && note == other.note;

  @override
  int get hashCode => note.hashCode;
}

void main() {
  group('ZExtension.guard (AC6/AC7, AD-10)', () {
    test('renvoie le résultat quand le parseur réussit', () {
      expect(ZExtension.guard<int>(() => 42), 42);
    });

    test('renvoie null sur exception, sans propagation', () {
      expect(
        () => ZExtension.guard<int>(() => throw StateError('x')),
        returnsNormally,
      );
      expect(ZExtension.guard<int>(() => throw StateError('x')), isNull);
    });

    test('capture aussi les Error (pas seulement les Exception)', () {
      expect(
        ZExtension.guard<int>(() => throw ArgumentError('boom')),
        isNull,
      );
    });
  });

  group('FakeExt.fromJsonSafe — défensif (AC7, AD-10)', () {
    test('null → null', () {
      expect(FakeExt.fromJsonSafe(null), isNull);
    });

    test('clés manquantes → null', () {
      expect(FakeExt.fromJsonSafe(<String, dynamic>{}), isNull);
    });

    test('type inattendu (formatVersion="x") → null', () {
      expect(
        FakeExt.fromJsonSafe(<String, dynamic>{'formatVersion': 'x', 'note': 'n'}),
        isNull,
      );
    });

    test('formatVersion inconnu (99) → null', () {
      expect(
        FakeExt.fromJsonSafe(<String, dynamic>{'formatVersion': 99, 'note': 'n'}),
        isNull,
      );
    });

    test('aucun cas ne throw (returnsNormally)', () {
      for (final bad in <Map<String, dynamic>?>[
        null,
        <String, dynamic>{},
        <String, dynamic>{'formatVersion': 'x'},
        <String, dynamic>{'formatVersion': 99, 'note': 'n'},
        <String, dynamic>{'note': 123},
      ]) {
        expect(() => FakeExt.fromJsonSafe(bad), returnsNormally);
      }
    });
  });

  group('Round-trip versionné (AC8)', () {
    test('toJson ↔ fromJsonSafe reconstruit une valeur égale', () {
      const ext = FakeExt('bonjour');
      final json = ext.toJson();
      final restored = FakeExt.fromJsonSafe(json);
      expect(restored, equals(ext));
      expect(restored!.formatVersion, ext.formatVersion);
    });

    test('formatVersion préservé et indépendant du parent', () {
      const ext = FakeExt('x');
      expect(ext.toJson()['formatVersion'], 1);
    });
  });
}
