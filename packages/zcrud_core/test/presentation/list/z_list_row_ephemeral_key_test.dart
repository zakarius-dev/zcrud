// CR-LIST (clé éphémère) : fabrique de clé STANDARD `ZListRow.ephemeralKey`
// pour les entités non persistées (`ZEntity.id == null`) — chaque consommateur
// n'invente plus son propre format positionnel.
//
// Gardes : format canonique préfixé, déterminisme (même index → même clé,
// lignes égales), unicité par index, reconnaissance `isEphemeralKey`.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  test('format canonique : __ephemeral_<index>', () {
    expect(ZListRow.ephemeralKey(0), '__ephemeral_0');
    expect(ZListRow.ephemeralKey(42), '__ephemeral_42');
  });

  test('déterminisme : même index → même clé, lignes de valeur ÉGALE', () {
    expect(ZListRow.ephemeralKey(7), ZListRow.ephemeralKey(7));
    final a = ZListRow(id: ZListRow.ephemeralKey(7), cells: const {'n': 1});
    final b = ZListRow(id: ZListRow.ephemeralKey(7), cells: const {'n': 1});
    // La sélection/les actions, keyées par `id`, survivent aux rebuilds.
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('unicité positionnelle : deux index distincts → deux clés distinctes',
      () {
    final keys = {for (var i = 0; i < 100; i++) ZListRow.ephemeralKey(i)};
    expect(keys, hasLength(100));
  });

  test('isEphemeralKey reconnaît les clés fabriquées, et elles seules', () {
    expect(ZListRow.isEphemeralKey(ZListRow.ephemeralKey(3)), isTrue);
    expect(ZListRow.isEphemeralKey('abc123'), isFalse);
    expect(ZListRow.isEphemeralKey(''), isFalse);
    // Une identité réelle qui ressemblerait au préfixe sans l'être.
    expect(ZListRow.isEphemeralKey('_ephemeral_1'), isFalse);
  });
}
