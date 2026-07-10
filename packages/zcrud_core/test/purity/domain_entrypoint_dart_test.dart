// Preuve PAR IMPORT RÉEL (AD-14) : le point d'entrée `package:zcrud_core/domain.dart`
// surface les APIs pur-Dart du cœur ET reste Flutter-free. Ce fichier n'importe
// QUE `package:test` + `domain.dart` (jamais `flutter_test` ni le barrel principal
// `zcrud_core.dart`) : il DOIT donc compiler et tourner sous `dart test`. Si
// `domain.dart` tirait transitivement `package:flutter/*` (dart:ui), la
// compilation VM échouerait — c'est la garde la plus forte, complémentaire du
// grep de `domain_purity_test.dart`.
//
// Lancement dédié : `dart test test/purity/domain_entrypoint_dart_test.dart`
// depuis `packages/zcrud_core` (voie Flutter-free ; le reste de la suite tourne
// sous `flutter test`).
import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';

/// Entité minimale prouvant que `ZEntity` + `ZExtensible` sont accessibles ET
/// compilables sous `dart test` (donc transitivement pur-Dart).
class _Probe extends ZEntity with ZExtensible {
  _Probe(this.id);

  @override
  final String? id;

  @override
  ZExtension? get extension => null;

  @override
  Map<String, dynamic> get extra => const <String, dynamic>{};
}

void main() {
  test('domain.dart surface les 4 APIs pur-Dart (compile + run sous dart test)',
      () {
    // (1) ZEntity + (2) ZExtensible.
    final probe = _Probe('a');
    expect(probe.id, 'a');
    expect(probe.extension, isNull);
    expect(probe.extra, isEmpty);

    // (3) ZExtension.guard : parsing défensif (jamais de throw).
    expect(ZExtension.guard<int?>(() => 42), 42);
    expect(ZExtension.guard<int?>(() => throw StateError('x')), isNull);

    // (4) ZSourceRegistry : registre ouvert instanciable.
    final registry = ZSourceRegistry();
    expect(registry.isRegistered('inconnu'), isFalse);

    // Bonus : le dartz curaté + la hiérarchie ZFailure sont aussi sur la surface
    // pure (les satellites en dépendent, ex. ZFlashcardRepository).
    const Either<ZFailure, int> ok = Right<ZFailure, int>(1);
    expect(ok.isRight(), isTrue);
  });
}
