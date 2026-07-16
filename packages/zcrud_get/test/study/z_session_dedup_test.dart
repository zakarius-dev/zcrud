// ES-11.1 AC3 (SM-1, objectif produit n°1) — aucune RECRÉATION d'instance de
// sélecteur si la valeur profonde de la config est inchangée (dedup GetX par
// `Type` + `tag`).
//
// Discriminant R3-I3 : dériver le `tag` d'une composante d'IDENTITÉ
// (`identityHashCode`) ou d'une clé shallow (ignorant `extra`/`tagIds`/`types`)
// fait passer le compteur de constructions de 1 → 2 sur « égales mais
// distinctes » et rend `identical` faux ⇒ ce test rougit. C'est la
// matérialisation exécutable de l'objectif n°1 au niveau du binding.
//
// R27.4 : le test exerce la FACTORY PUBLIQUE exportée (`zPutStudySessionSelector`),
// pas seulement `ZSessionConfigKey.tag` en isolation.
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

ZStudySessionConfig makeConfig() => ZStudySessionConfig(
      mode: ZReviewMode.spaced,
      folderId: 'folder-1',
      tagIds: <String>['t1', 't2'],
      types: <String>['multipleChoice'],
      count: 10,
      extra: <String, dynamic>{'note': 'x'},
    );

void main() {
  test('dedup GetX par tag : configs ÉGALES mais distinctes ⇒ 1 seule '
      'construction + MÊME instance (SM-1) ; config différant d\'un champ ⇒ '
      '+1 construction (AC3)', () {
    addTearDown(Get.reset);

    var builds = 0;
    ZStudySessionSelector counted(ZStudySessionConfig c) {
      builds++;
      return ZStudySessionSelector(c);
    }

    final configA = makeConfig();
    final configB = configA.copyWith(); // ÉGALE mais instance DISTINCTE.
    expect(identical(configA, configB), isFalse);

    final selA = zPutStudySessionSelector(
      ZSessionConfigKey(configA),
      create: counted,
    );
    expect(builds, 1, reason: 'première clé ⇒ une construction');

    final selB = zPutStudySessionSelector(
      ZSessionConfigKey(configB),
      create: counted,
    );
    expect(
      builds,
      1,
      reason: 'config égale-mais-distincte ⇒ MÊME tag ⇒ AUCUNE recréation '
          '(SM-1). Dériver le tag par identité/shallow ferait passer à 2 (R3-I3).',
    );
    expect(
      identical(selA, selB),
      isTrue,
      reason: 'la MÊME instance GetX est réutilisée (Get.find par Type + tag)',
    );

    final configDiff = configA.copyWith(count: 11); // diffère d'UN champ.
    final selDiff = zPutStudySessionSelector(
      ZSessionConfigKey(configDiff),
      create: counted,
    );
    expect(builds, 2,
        reason: 'nouvelle clé (un champ change) ⇒ nouveau tag ⇒ construction');
    expect(identical(selA, selDiff), isFalse,
        reason: 'tag différent ⇒ instance distincte');
  });

  test('la factory délègue à la primitive PURE ZStudySessionSelector du kernel '
      '(config threadée telle quelle)', () {
    addTearDown(Get.reset);
    final config = makeConfig();
    final selector = zPutStudySessionSelector(ZSessionConfigKey(config));
    expect(selector, isA<ZStudySessionSelector>());
    // Le sélecteur enveloppe EXACTEMENT la config de la clé (jamais réimplémenté).
    expect(selector.config, same(config));
  });
}
