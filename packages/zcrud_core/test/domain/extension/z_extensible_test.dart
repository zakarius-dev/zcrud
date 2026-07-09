// AC8/AC9 (AD-4) : `ZExtensible` — mixin `extension`/`extra` (défaut `const {}`),
// échappatoire non typée préservée (round-trip conceptuel), lecture défensive
// `zExtraRead`. Tests PUR-DART.
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Extension minimale pour peupler le slot `extension`.
class _Ext extends ZExtension {
  const _Ext();
  @override
  int get formatVersion => 1;
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'formatVersion': 1};
}

/// Entité fictive mixant `ZExtensible` — les entités canoniques (E9/E10) feront
/// de même, SANS que `ZEntity` porte ce mixin (AC9).
class FakeEntity with ZExtensible {
  FakeEntity({this.extension, Map<String, dynamic>? extra})
      : extra = extra ?? const <String, dynamic>{};

  @override
  final ZExtension? extension;

  @override
  final Map<String, dynamic> extra;
}

void main() {
  group('ZExtensible — contrat de slot (AC9)', () {
    test('extra défaut const {} ; extension nullable', () {
      final e = FakeEntity();
      expect(e.extra, isEmpty);
      expect(e.extension, isNull);
    });

    test('extension peut être renseignée', () {
      final e = FakeEntity(extension: const _Ext());
      expect(e.extension, isA<ZExtension>());
      expect(e.extension!.formatVersion, 1);
    });
  });

  group('extra — échappatoire non typée (AC8, canonique §4 pt.2)', () {
    test('préserve des paires arbitraires, y compris des clés inconnues', () {
      final source = <String, dynamic>{
        'k': 1,
        'inconnu': <int>[1, 2],
        'nested': <String, dynamic>{'a': true},
      };
      final e = FakeEntity(extra: source);
      // Round-trip conceptuel : ce qui est écrit est relu à l'identique.
      expect(e.extra, equals(source));
      expect(e.extra['inconnu'], <int>[1, 2]);
    });
  });

  group('zExtraRead — lecture typée défensive (AD-10)', () {
    final extra = <String, dynamic>{'n': 42, 's': 'hello'};

    test('retourne la valeur si présente et du bon type', () {
      expect(zExtraRead<int>(extra, 'n'), 42);
      expect(zExtraRead<String>(extra, 's'), 'hello');
    });

    test('retourne null si clé absente', () {
      expect(zExtraRead<int>(extra, 'absent'), isNull);
    });

    test('retourne null si type incompatible (jamais throw)', () {
      expect(() => zExtraRead<int>(extra, 's'), returnsNormally);
      expect(zExtraRead<int>(extra, 's'), isNull);
    });
  });
}
