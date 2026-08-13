// Numérotation CONTINUE d'une page à l'autre.
//
// `pageOffset` suppose que l'hôte sache dans quelle page il est — faux dès que
// c'est le RENDU qui pagine (l'index de page lui est privé). Le décalage est
// donc déclaré ici et la position vient du rendu.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  test('CONTRE-TÉMOIN — par défaut chaque page repart de 1', () {
    const ordinal = ZListOrdinal(enabled: true);
    expect(ordinal.textAt(0, pageIndex: 2, pageSize: 20), '1');
    expect(ordinal.textsFor(2, pageIndex: 1, pageSize: 20), <String>['1', '2']);
  });

  test('continuousAcrossPages : la 2e page d\'un pager de 20 commence à 21',
      () {
    const ordinal = ZListOrdinal(enabled: true, continuousAcrossPages: true);
    expect(ordinal.textAt(0, pageIndex: 1, pageSize: 20), '21');
    expect(
      ordinal.textsFor(3, pageIndex: 2, pageSize: 20),
      <String>['41', '42', '43'],
    );
  });

  test('un rendu qui ne transmet pas sa page numérote comme avant', () {
    const ordinal = ZListOrdinal(enabled: true, continuousAcrossPages: true);
    expect(ordinal.textAt(0), '1');
    expect(ordinal.textAt(4), '5');
  });

  test('pageOffset et continuité SE COMPOSENT (départ à un rang connu)', () {
    const ordinal = ZListOrdinal(
      enabled: true,
      pageOffset: 100,
      continuousAcrossPages: true,
    );
    expect(ordinal.textAt(0, pageIndex: 1, pageSize: 10), '111');
  });

  test('la continuité entre dans l\'égalité de valeur', () {
    expect(
      const ZListOrdinal(enabled: true),
      isNot(const ZListOrdinal(enabled: true, continuousAcrossPages: true)),
    );
    expect(
      const ZListOrdinal(enabled: true, continuousAcrossPages: true),
      const ZListOrdinal(enabled: true, continuousAcrossPages: true),
    );
  });
}
