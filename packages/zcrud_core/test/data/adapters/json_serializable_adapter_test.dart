// E2-6 AC2/AC3/AC5/AC6/AC7 (FR-11, AD-3/AD-10) : `JsonSerializableAdapter` —
// expose un modèle `@JsonSerializable` EXISTANT comme `ZcrudModel` enregistré,
// SANS le repasser par le builder zcrud. Round-trip via le REGISTRE, collision,
// type absent, mode défensif. Tests PUR-DART.
//
// Ambiguïté #3 (tranchée orchestrateur) : le modèle de test est HERMÉTIQUE —
// `fromJson`/`toJson` ÉCRITS À LA MAIN, mimant la sortie `json_serializable`.
// AUCUNE dépendance `json_serializable`/`build_runner`/`freezed` n'est ajoutée à
// `zcrud_core` : ce qui compte pour l'AC est que l'adaptateur consomme des
// `fromJson`/`toJson` FOURNIS, indépendants du builder zcrud.
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Modèle de test mimant un `@JsonSerializable` lex_douane : `final` + `const` +
/// factory `.fromJson` / méthode `.toJson` écrites à la main (hermétique — zéro
/// dépendance de génération). `==`/`hashCode` via `Object.hash` (canonique §5 —
/// jamais `Equatable`).
class DummyEtude {
  const DummyEtude({required this.id, required this.titre, required this.annee});

  /// Sortie typique d'un `_$DummyEtudeFromJson` : cast strict, LÈVE si la clé
  /// manque ou a le mauvais type (map corrompue) — exactement ce qu'AD-10 doit
  /// pouvoir absorber côté frontière via `fromMapSafe`.
  factory DummyEtude.fromJson(Map<String, dynamic> json) => DummyEtude(
        id: json['id'] as String,
        titre: json['titre'] as String,
        annee: json['annee'] as int,
      );

  final String id;
  final String titre;
  final int annee;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'id': id, 'titre': titre, 'annee': annee};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DummyEtude &&
          id == other.id &&
          titre == other.titre &&
          annee == other.annee;

  @override
  int get hashCode => Object.hash(id, titre, annee);
}

/// Construit l'adaptateur depuis les fonctions que le modèle possède DÉJÀ.
JsonSerializableAdapter<DummyEtude> buildAdapter({
  List<ZFieldSpec> fieldSpecs = const <ZFieldSpec>[],
}) =>
    JsonSerializableAdapter<DummyEtude>(
      kind: 'etude',
      fromJson: DummyEtude.fromJson,
      toJson: (DummyEtude e) => e.toJson(),
      fieldSpecs: fieldSpecs,
    );

void main() {
  const sample = DummyEtude(id: 'e1', titre: 'Régime douanier', annee: 2018);

  group('JsonSerializableAdapter — enregistrement sans builder zcrud (AC2)', () {
    test('registerInto rend le kind décodable/encodable via le registre', () {
      final registry = ZcrudRegistry();
      buildAdapter().registerInto(registry);

      expect(registry.isRegistered('etude'), isTrue);
      expect(registry.kinds, contains('etude'));
      expect(registry.codecFor('etude').kind, 'etude');
    });

    test('round-trip decode(encode(x)) == x via le REGISTRE', () {
      final registry = ZcrudRegistry();
      buildAdapter().registerInto(registry);

      final encoded = registry.encode('etude', sample);
      expect(encoded, <String, dynamic>{
        'id': 'e1',
        'titre': 'Régime douanier',
        'annee': 2018,
      });

      final decoded = registry.decode('etude', encoded);
      expect(decoded, isA<DummyEtude>());
      expect(decoded, equals(sample));
    });

    test('l\'adaptateur expose fromMap/toMap cohérents (round-trip direct)', () {
      final adapter = buildAdapter();
      expect(adapter.kind, 'etude');
      expect(adapter.fromMap(adapter.toMap(sample)), equals(sample));
    });
  });

  group('JsonSerializableAdapter — contrat E2-3 préservé (AC3, AC6)', () {
    test('codecFor(kind absent) → ZUnregisteredTypeError', () {
      final registry = ZcrudRegistry();
      buildAdapter().registerInto(registry);
      expect(
        () => registry.codecFor('kind-absent'),
        throwsA(isA<ZUnregisteredTypeError>()),
      );
    });

    test('double registerInto du même kind → ZDuplicateRegistrationError', () {
      final registry = ZcrudRegistry();
      buildAdapter().registerInto(registry);
      expect(
        () => buildAdapter().registerInto(registry),
        throwsA(isA<ZDuplicateRegistrationError>()),
      );
    });
  });

  group('JsonSerializableAdapter — fieldSpecs fournis, pas inférés (AC5)', () {
    const specs = <ZFieldSpec>[
      ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
      ZFieldSpec(name: 'titre', type: EditionFieldType.text),
    ];

    test('sans fieldSpecs → fieldSpecsFor renvoie const [] (licite)', () {
      final registry = ZcrudRegistry();
      buildAdapter().registerInto(registry);
      expect(registry.fieldSpecsFor('etude'), isEmpty);
    });

    test('avec fieldSpecs → transmis tel quel à register', () {
      final registry = ZcrudRegistry();
      buildAdapter(fieldSpecs: specs).registerInto(registry);
      expect(registry.fieldSpecsFor('etude'), same(specs));
    });
  });

  group('JsonSerializableAdapter — désérialisation défensive (AC7, AD-10)', () {
    test('mode strict : fromMap sur map corrompue LÈVE (délègue au fromJson)',
        () {
      final adapter = buildAdapter();
      expect(
        () => adapter.fromMap(<String, dynamic>{'id': 'x'}), // titre/annee absents
        throwsA(anything),
      );
    });

    test('mode défensif : fromMapSafe sur map VALIDE → même résultat que fromMap',
        () {
      final adapter = buildAdapter();
      final map = adapter.toMap(sample);
      expect(adapter.fromMapSafe(map), equals(sample));
    });

    test('mode défensif : fromMapSafe sur map CORROMPUE → null (pas de crash)',
        () {
      final adapter = buildAdapter();
      expect(adapter.fromMapSafe(<String, dynamic>{'id': 'x'}), isNull);
      expect(adapter.fromMapSafe(<String, dynamic>{}), isNull);
      // Mauvais type (annee non-int) : ne corrompt pas, renvoie null.
      expect(
        adapter.fromMapSafe(
            <String, dynamic>{'id': 'e1', 'titre': 't', 'annee': 'NaN'}),
        isNull,
      );
    });
  });
}
