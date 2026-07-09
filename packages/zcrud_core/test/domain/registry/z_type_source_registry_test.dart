// AC5 (AD-4 pt.3) : `ZTypeRegistry` & `ZSourceRegistry` — register/lookup
// strict (throw) + défensif (null), collision (throw), isolation & espaces de
// noms séparés (Dev Notes #3, OQ-6 « par axe »). Tests PUR-DART.
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Fausse valeur ouverte (variant de type/provenance) locale.
class FakeVariant {
  const FakeVariant(this.kind, this.payload);

  factory FakeVariant.fromJson(Map<String, dynamic> json) =>
      FakeVariant(json['kind'] as String, json['payload'] as String);

  final String kind;
  final String payload;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'kind': kind, 'payload': payload};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FakeVariant && kind == other.kind && payload == other.payload;

  @override
  int get hashCode => Object.hash(kind, payload);
}

void _registerVariant(ZOpenRegistry r, String kind) {
  r.register(
    kind,
    fromJson: FakeVariant.fromJson,
    toJson: (Object v) => (v as FakeVariant).toJson(),
  );
}

void main() {
  // Les deux registres partagent la mécanique `ZOpenRegistry` : on paramètre
  // les tests par une fabrique pour couvrir type ET source identiquement.
  for (final entry in <String, ZOpenRegistry Function()>{
    'ZTypeRegistry': ZTypeRegistry.new,
    'ZSourceRegistry': ZSourceRegistry.new,
  }.entries) {
    final name = entry.key;
    final make = entry.value;

    group('$name — register & lookup (AC5)', () {
      test('register → isRegistered / kinds', () {
        final r = make();
        expect(r.isRegistered('markdown'), isFalse);
        _registerVariant(r, 'markdown');
        expect(r.isRegistered('markdown'), isTrue);
        expect(r.kinds, contains('markdown'));
      });

      test('round-trip fromJson/toJson via le codec', () {
        final r = make();
        _registerVariant(r, 'markdown');
        const variant = FakeVariant('markdown', 'delta');
        final codec = r.codecFor('markdown');
        final json = codec.toJson(variant);
        expect(codec.fromJson(json), equals(variant));
      });

      test('codecFor(inconnu) → throw ZUnregisteredTypeError (strict)', () {
        final r = make();
        expect(
          () => r.codecFor('inconnu'),
          throwsA(isA<ZUnregisteredTypeError>()),
        );
      });

      test('tryCodecFor(inconnu) == null (défensif)', () {
        final r = make();
        expect(r.tryCodecFor('inconnu'), isNull);
      });

      test('collision → throw ZDuplicateRegistrationError', () {
        final r = make();
        _registerVariant(r, 'markdown');
        expect(
          () => _registerVariant(r, 'markdown'),
          throwsA(isA<ZDuplicateRegistrationError>()),
        );
      });

      test('le message d\'erreur porte le nom du registre', () {
        final r = make();
        try {
          r.codecFor('inconnu');
          fail('devait throw');
        } on ZUnregisteredTypeError catch (e) {
          expect(e.registryName, name);
        }
      });

      test('isolation : deux instances ne partagent pas leur état', () {
        final a = make();
        final b = make();
        _registerVariant(a, 'markdown');
        expect(a.isRegistered('markdown'), isTrue);
        expect(b.isRegistered('markdown'), isFalse);
      });
    });
  }

  group('Espaces de noms séparés (Dev Notes #3, OQ-6)', () {
    test('un kind côté source n\'est pas visible côté type', () {
      final type = ZTypeRegistry();
      final source = ZSourceRegistry();
      _registerVariant(source, 'article');
      expect(source.isRegistered('article'), isTrue);
      expect(type.isRegistered('article'), isFalse);
      // Même kind enregistrable des deux côtés sans collision.
      expect(() => _registerVariant(type, 'article'), returnsNormally);
    });
  });
}
