// E2-6 AC4/AC6 (FR-11, AD-3/AD-6) : `ReflectableCodec` — adapte un modèle DODLP
// via une capacité de réflexion INJECTÉE (seam AD-6), prouvé avec un DOUBLE/FAKE
// (pas de `initializeReflectable()`, AUCUN `*.reflectable.dart` généré sous
// `packages/` → gate VERT). Round-trip via le REGISTRE + garde « aucun fichier
// généré reflectable sous packages/ ».
//
// NB : ce fichier de test N'IMPORTE PAS `reflectable` et NE contient PAS le
// littéral d'import interdit — il n'implémente que le port
// `ZReflectionCapability` (défini au chemin allowlisté). Le confinement de
// l'import est prouvé par `gate_reflectable.dart` (AC6), PAS ré-implémenté ici
// (ce qui réintroduirait le littéral interdit dans un fichier non allowlisté).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_get/zcrud_get.dart';

/// Modèle DODLP de test (`final`, `==`/`hashCode` maison).
class DummyDossier {
  const DummyDossier({required this.ref, required this.montant});

  final String ref;
  final double montant;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DummyDossier && ref == other.ref && montant == other.montant;

  @override
  int get hashCode => Object.hash(ref, montant);
}

/// DOUBLE de capacité de réflexion : implémente le port SANS `reflectable`
/// (simule l'introspection d'un reflector DODLP). Prouve la logique
/// d'adaptation de `ReflectableCodec` sans exécuter `initializeReflectable()`.
class FakeDossierReflection implements ZReflectionCapability<DummyDossier> {
  @override
  String get kind => 'dossier';

  @override
  Map<String, dynamic> toMap(DummyDossier value) =>
      <String, dynamic>{'ref': value.ref, 'montant': value.montant};

  @override
  DummyDossier fromMap(Map<String, dynamic> map) => DummyDossier(
        ref: map['ref'] as String,
        montant: map['montant'] as double,
      );
}

void main() {
  const sample = DummyDossier(ref: 'D-42', montant: 1250.5);

  group('ReflectableCodec — réflexion injectée + round-trip registre (AC4)', () {
    test('registerInto rend le kind décodable/encodable via le registre', () {
      final registry = ZcrudRegistry();
      ReflectableCodec<DummyDossier>(capability: FakeDossierReflection())
          .registerInto(registry);

      expect(registry.isRegistered('dossier'), isTrue);
      expect(registry.codecFor('dossier').kind, 'dossier');
    });

    test('round-trip decode(encode(x)) == x via le REGISTRE', () {
      final registry = ZcrudRegistry();
      ReflectableCodec<DummyDossier>(capability: FakeDossierReflection())
          .registerInto(registry);

      final decoded =
          registry.decode('dossier', registry.encode('dossier', sample));
      expect(decoded, isA<DummyDossier>());
      expect(decoded, equals(sample));
    });

    test('kind délégué à la capacité ; double register → throw (contrat E2-3)',
        () {
      final registry = ZcrudRegistry();
      final codec =
          ReflectableCodec<DummyDossier>(capability: FakeDossierReflection());
      expect(codec.kind, 'dossier');
      codec.registerInto(registry);
      expect(
        () => ReflectableCodec<DummyDossier>(
                capability: FakeDossierReflection())
            .registerInto(registry),
        throwsA(isA<ZDuplicateRegistrationError>()),
      );
    });

    test('mode défensif hérité : fromMapSafe(corrompue) → null (AD-10)', () {
      final codec =
          ReflectableCodec<DummyDossier>(capability: FakeDossierReflection());
      expect(codec.fromMapSafe(sample.toMapForTest()), equals(sample));
      expect(codec.fromMapSafe(<String, dynamic>{'ref': 'x'}), isNull);
    });
  });

  group('ReflectableCodec — confinement (AC6, gate AD-3)', () {
    // Le confinement de l'import `reflectable` (seul chemin allowlisté) est
    // prouvé de bout en bout par `dart run scripts/ci/gate_reflectable.dart`
    // (exécuté en vérif verte, AC6) — NON ré-implémenté ici pour ne pas
    // introduire le littéral d'import interdit dans un fichier non allowlisté.
    // Cette garde couvre l'autre moitié du piège : aucun `*.reflectable.dart`
    // généré ne doit exister sous `packages/` (sinon scanné et rejeté).
    test('aucun *.reflectable.dart généré sous packages/', () {
      final offenders = _packagesRoot()
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.reflectable.dart'))
          .map((f) => f.path)
          .toList();
      expect(offenders, isEmpty,
          reason: 'fichiers reflectable générés (gate ROUGE):\n'
              '${offenders.join('\n')}');
    });
  });
}

/// Localise la racine `packages/` quel que soit le CWD (racine repo ou package).
Directory _packagesRoot() {
  for (final base in <String>['', '../../']) {
    final dir = Directory('${base}packages');
    if (dir.existsSync()) return dir;
  }
  fail('packages/ introuvable depuis ${Directory.current.path}');
}

extension _ToMapForTest on DummyDossier {
  Map<String, dynamic> toMapForTest() =>
      <String, dynamic>{'ref': ref, 'montant': montant};
}
