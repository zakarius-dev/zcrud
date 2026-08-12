// AC2/AC3/AC4/AC11 (AD-3/AD-4) : `ZcrudRegistry` — enregistrement de modèles,
// lookup strict (throw) vs défensif (null), collision (throw), round-trip via
// le registre (contrat de codegen E2-5). Tests PUR-DART.
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Faux modèle local (aucun modèle canonique n'existe avant E9/E10). `final` +
/// `==`/`hashCode` manuels via `Object.hash` (canonique §5 — `Equatable` jamais).
class FakeModel {
  const FakeModel({required this.id, required this.label});

  factory FakeModel.fromMap(Map<String, dynamic> map) => FakeModel(
        id: map['id'] as String,
        label: map['label'] as String,
      );

  final String id;
  final String label;

  Map<String, dynamic> toMap() => <String, dynamic>{'id': id, 'label': label};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FakeModel && id == other.id && label == other.label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// Second faux modèle, distinct de [FakeModel] — pour les scénarios
/// multi-types de la table `Type → kind`.
class OtherModel {
  const OtherModel({required this.code});

  factory OtherModel.fromMap(Map<String, dynamic> map) =>
      OtherModel(code: map['code'] as int);

  final int code;

  Map<String, dynamic> toMap() => <String, dynamic>{'code': code};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OtherModel && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Simule le pattern d'enregistrement **généré** par E2-5 : une fonction prenant
/// une **instance** de `ZcrudRegistry` (injection au bootstrap, cf. E7-2).
void registerFakeModel(ZcrudRegistry r) {
  r.register<FakeModel>(
    'fakeModel',
    fromMap: FakeModel.fromMap,
    toMap: (FakeModel m) => m.toMap(),
  );
}

void main() {
  group('ZcrudRegistry — enregistrement & lookup (AC2)', () {
    test('register → isRegistered / kinds', () {
      final r = ZcrudRegistry();
      expect(r.isRegistered('fakeModel'), isFalse);
      registerFakeModel(r);
      expect(r.isRegistered('fakeModel'), isTrue);
      expect(r.kinds, contains('fakeModel'));
    });

    test('codecFor retourne le codec du kind enregistré', () {
      final r = ZcrudRegistry()..let(registerFakeModel);
      final codec = r.codecFor('fakeModel');
      expect(codec.kind, 'fakeModel');
    });
  });

  group('ZcrudRegistry — round-trip via le registre (AC11, contrat E2-5)', () {
    test('decode reconstruit le modèle ; encode reproduit la map', () {
      final r = ZcrudRegistry()..let(registerFakeModel);
      const model = FakeModel(id: 'a1', label: 'Alpha');
      final map = model.toMap();

      final decoded = r.decode('fakeModel', map);
      expect(decoded, isA<FakeModel>());
      expect(decoded, equals(model));

      final encoded = r.encode('fakeModel', model);
      expect(encoded, equals(map));
    });

    test('round-trip complet decode(encode()) == identité', () {
      final r = ZcrudRegistry()..let(registerFakeModel);
      const model = FakeModel(id: 'b2', label: 'Beta');
      final roundTripped = r.decode('fakeModel', r.encode('fakeModel', model));
      expect(roundTripped, equals(model));
    });
  });

  group('ZcrudRegistry — type non enregistré → throw (AC3, AD-3)', () {
    test('codecFor(inconnu) lève ZUnregisteredTypeError', () {
      final r = ZcrudRegistry();
      expect(
        () => r.codecFor('inconnu'),
        throwsA(isA<ZUnregisteredTypeError>()),
      );
    });

    test('decode/encode(inconnu) lèvent ZUnregisteredTypeError', () {
      final r = ZcrudRegistry();
      expect(
        () => r.decode('inconnu', <String, dynamic>{}),
        throwsA(isA<ZUnregisteredTypeError>()),
      );
      expect(
        () => r.encode('inconnu', const FakeModel(id: 'x', label: 'y')),
        throwsA(isA<ZUnregisteredTypeError>()),
      );
    });

    test('le message porte le kind fautif et le nom du registre', () {
      final r = ZcrudRegistry();
      try {
        r.codecFor('inconnu');
        fail('devait throw');
      } on ZUnregisteredTypeError catch (e) {
        expect(e.kind, 'inconnu');
        expect(e.registryName, 'ZcrudRegistry');
        expect(e.toString(), contains('inconnu'));
        expect(e.toString(), contains('ZcrudRegistry'));
      }
    });

    test('ZUnregisteredTypeError est un Error (pas un ZFailure) — AD-3', () {
      final err = ZUnregisteredTypeError(kind: 'k', registryName: 'R');
      expect(err, isA<Error>());
      expect(err, isNot(isA<ZFailure>()));
    });
  });

  group('ZcrudRegistry — lookup défensif (AC2/AD-10)', () {
    test('tryCodecFor(inconnu) == null (jamais throw)', () {
      final r = ZcrudRegistry();
      expect(r.tryCodecFor('inconnu'), isNull);
    });

    test('tryCodecFor(enregistré) retourne le codec', () {
      final r = ZcrudRegistry()..let(registerFakeModel);
      expect(r.tryCodecFor('fakeModel'), isNotNull);
    });
  });

  group('ZcrudRegistry — collision → throw (AC4, Dev Notes #4)', () {
    test('double register du même kind lève ZDuplicateRegistrationError', () {
      final r = ZcrudRegistry()..let(registerFakeModel);
      expect(
        () => registerFakeModel(r),
        throwsA(isA<ZDuplicateRegistrationError>()),
      );
    });

    test('ZDuplicateRegistrationError est un Error, message actionnable', () {
      final err = ZDuplicateRegistrationError(kind: 'k', registryName: 'R');
      expect(err, isA<Error>());
      expect(err.toString(), contains('k'));
      expect(err.toString(), contains('R'));
    });
  });

  group('ZcrudRegistry — isolation instance (Dev Notes #2, OQ-6)', () {
    test('deux instances ne partagent pas leurs enregistrements', () {
      final a = ZcrudRegistry()..let(registerFakeModel);
      final b = ZcrudRegistry();
      expect(a.isRegistered('fakeModel'), isTrue);
      expect(b.isRegistered('fakeModel'), isFalse);
    });
  });

  group('ZcrudRegistry — slot fieldSpecs additif (E2-5, AC7/AD-10)', () {
    const specs = <ZFieldSpec>[
      ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
      ZFieldSpec(name: 'label', type: EditionFieldType.text),
    ];

    test('register avec fieldSpecs → fieldSpecsFor renvoie la même liste', () {
      final r = ZcrudRegistry();
      r.register<FakeModel>(
        'fm',
        fromMap: FakeModel.fromMap,
        toMap: (FakeModel m) => m.toMap(),
        fieldSpecs: specs,
      );
      expect(r.fieldSpecsFor('fm'), same(specs));
      expect(r.tryFieldSpecsFor('fm'), same(specs));
    });

    test('register SANS fieldSpecs → liste vide (signature rétro-compatible)',
        () {
      final r = ZcrudRegistry()..let(registerFakeModel);
      expect(r.fieldSpecsFor('fakeModel'), isEmpty);
      expect(r.tryFieldSpecsFor('fakeModel'), isEmpty);
    });

    test('fieldSpecsFor(inconnu) → throw ; tryFieldSpecsFor(inconnu) → null',
        () {
      final r = ZcrudRegistry();
      expect(() => r.fieldSpecsFor('inconnu'),
          throwsA(isA<ZUnregisteredTypeError>()));
      expect(r.tryFieldSpecsFor('inconnu'), isNull);
    });
  });

  group('ZcrudRegistry — kindOf<T>() (table Type → kind, CR registry)', () {
    test('association univoque → retourne le kind', () {
      final r = ZcrudRegistry()..let(registerFakeModel);
      expect(r.kindOf<FakeModel>(), 'fakeModel');
    });

    test('type jamais enregistré → null (jamais throw)', () {
      final r = ZcrudRegistry();
      expect(r.kindOf<FakeModel>(), isNull);
    });

    test('type inconnu sur un registre non vide → null aussi', () {
      final r = ZcrudRegistry()..let(registerFakeModel);
      expect(r.kindOf<OtherModel>(), isNull);
    });

    test(
        'même type sous DEUX kinds : register passe, kindOf lève un '
        'StateError nommant le type et les kinds', () {
      final r = ZcrudRegistry()..let(registerFakeModel);
      // L'enregistrement du même type sous un second kind reste PERMIS
      // (modèle partagé par deux collections) — aucune rupture rétroactive.
      r.register<FakeModel>(
        'fakeModelBis',
        fromMap: FakeModel.fromMap,
        toMap: (FakeModel m) => m.toMap(),
      );
      try {
        r.kindOf<FakeModel>();
        fail('devait throw StateError (association non univoque)');
      } on StateError catch (e) {
        final msg = e.message;
        expect(msg, contains('FakeModel'));
        expect(msg, contains('"fakeModel"'));
        expect(msg, contains('"fakeModelBis"'));
        // Le message oriente vers la voie par-kind (actionnable).
        expect(msg, contains('par-kind'));
      }
    });

    test('isolation instance : la table Type → kind ne fuit pas entre '
        'deux registres', () {
      final a = ZcrudRegistry()..let(registerFakeModel);
      final b = ZcrudRegistry();
      expect(a.kindOf<FakeModel>(), 'fakeModel');
      expect(b.kindOf<FakeModel>(), isNull);
    });

    test('collision de kind (duplicate) → la table Type → kind reste '
        'inchangée (cohérent avec _fieldSpecs)', () {
      final r = ZcrudRegistry()..let(registerFakeModel);
      // Ré-enregistrer le MÊME kind avec un AUTRE type doit throw AVANT
      // toute écriture de table : OtherModel ne doit pas apparaître.
      expect(
        () => r.register<OtherModel>(
          'fakeModel',
          fromMap: OtherModel.fromMap,
          toMap: (OtherModel m) => m.toMap(),
        ),
        throwsA(isA<ZDuplicateRegistrationError>()),
      );
      expect(r.kindOf<OtherModel>(), isNull);
      expect(r.kindOf<FakeModel>(), 'fakeModel');
    });
  });

  group('ZcrudRegistry — encodeOf/decodeOf typés (CR registry)', () {
    test('nominal : encodeOf<T> == encode(kind) ; decodeOf<T> rend un T', () {
      final r = ZcrudRegistry()..let(registerFakeModel);
      const model = FakeModel(id: 'a1', label: 'Alpha');

      final encoded = r.encodeOf<FakeModel>(model);
      expect(encoded, equals(r.encode('fakeModel', model)));

      final FakeModel decoded = r.decodeOf<FakeModel>(encoded);
      expect(decoded, equals(model));
    });

    test('round-trip typé decodeOf(encodeOf()) == identité', () {
      final r = ZcrudRegistry()..let(registerFakeModel);
      const model = FakeModel(id: 'b2', label: 'Beta');
      expect(r.decodeOf<FakeModel>(r.encodeOf<FakeModel>(model)),
          equals(model));
    });

    test('type non enregistré → StateError actionnable (jamais un silence)',
        () {
      final r = ZcrudRegistry();
      expect(
        () => r.encodeOf<FakeModel>(const FakeModel(id: 'x', label: 'y')),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('encodeOf'), contains('FakeModel'),
              contains('bootstrap')),
        )),
      );
      expect(
        () => r.decodeOf<FakeModel>(<String, dynamic>{}),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('decodeOf'), contains('FakeModel')),
        )),
      );
    });

    test('type ambigu (deux kinds) → StateError du contrat kindOf', () {
      final r = ZcrudRegistry()
        ..let(registerFakeModel)
        ..register<FakeModel>(
          'fakeModelBis',
          fromMap: FakeModel.fromMap,
          toMap: (FakeModel m) => m.toMap(),
        );
      expect(
        () => r.encodeOf<FakeModel>(const FakeModel(id: 'x', label: 'y')),
        throwsA(isA<StateError>().having(
            (e) => e.message, 'message', contains('fakeModelBis'))),
      );
      expect(
        () => r.decodeOf<FakeModel>(<String, dynamic>{}),
        throwsA(isA<StateError>()),
      );
    });

    test('deux types distincts sous deux kinds : chacun résout le sien', () {
      final r = ZcrudRegistry()
        ..let(registerFakeModel)
        ..register<OtherModel>(
          'otherModel',
          fromMap: OtherModel.fromMap,
          toMap: (OtherModel m) => m.toMap(),
        );
      expect(r.kindOf<FakeModel>(), 'fakeModel');
      expect(r.kindOf<OtherModel>(), 'otherModel');
      const other = OtherModel(code: 42);
      expect(r.decodeOf<OtherModel>(r.encodeOf<OtherModel>(other)),
          equals(other));
    });
  });
}

/// Petit helper de test : applique [fn] à `this` et le retourne (cascade lisible).
extension _Let<T> on T {
  T let(void Function(T) fn) {
    fn(this);
    return this;
  }
}
