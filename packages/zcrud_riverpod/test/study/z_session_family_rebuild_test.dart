// ES-10.1 AC3 (SM-1, objectif produit n°1) — aucun rebuild de provider si la
// valeur profonde de la config est inchangée.
//
// Discriminant R3-I3 : keyer la family par `ZStudySessionConfig` comparée par
// IDENTITÉ (ou une clé shallow) fait passer le compteur de builds de 1 → 2 sur
// « égales mais distinctes » ⇒ ce test rougit. C'est la matérialisation
// exécutable de l'objectif n°1 au niveau du binding.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_riverpod/zcrud_riverpod.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Observer comptant les CRÉATIONS de providers de la family de sélection
/// (`didAddProvider`) — chaque clé DISTINCTE crée un provider ; deux clés ÉGALES
/// (par `==`/`hashCode` de `ZSessionConfigKey`) sont dédupliquées ⇒ une seule
/// création.
class _AddCounter extends ProviderObserver {
  int adds = 0;
  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    if (provider.argument is ZSessionConfigKey) adds++;
  }
}

ZStudySessionConfig makeConfig() => ZStudySessionConfig(
      mode: ZReviewMode.spaced,
      folderId: 'folder-1',
      tagIds: <String>['t1', 't2'],
      types: <String>['multipleChoice'],
      count: 10,
      extra: <String, dynamic>{'note': 'x'},
    );

void main() {
  test('family clée par ZSessionConfigKey : configs ÉGALES mais distinctes ⇒ '
      '1 seul build (SM-1) ; config différant d\'un champ ⇒ +1 build (AC3)', () {
    final observer = _AddCounter();
    final container = ProviderContainer(observers: <ProviderObserver>[observer]);
    addTearDown(container.dispose);

    final configA = makeConfig();
    final configB = configA.copyWith(); // ÉGALE mais instance DISTINCTE.
    expect(identical(configA, configB), isFalse);

    // Souscriptions maintenues vivantes ⇒ le dedup dépend de la clé, pas du
    // timing d'auto-dispose.
    container.listen(
      zStudySessionSelectorProvider(ZSessionConfigKey(configA)),
      (_, __) {},
    );
    expect(observer.adds, 1, reason: 'première clé ⇒ un build');

    container.listen(
      zStudySessionSelectorProvider(ZSessionConfigKey(configB)),
      (_, __) {},
    );
    expect(
      observer.adds,
      1,
      reason: 'config égale-mais-distincte ⇒ MÊME clé ⇒ AUCUN rebuild (SM-1). '
          'Keyer par identité/shallow ferait passer à 2 (R3-I3).',
    );

    final configDiff = configA.copyWith(count: 11); // diffère d'UN champ.
    container.listen(
      zStudySessionSelectorProvider(ZSessionConfigKey(configDiff)),
      (_, __) {},
    );
    expect(observer.adds, 2,
        reason: 'nouvelle clé (un champ change) ⇒ nouveau build');
  });

  test('la family délègue à la primitive PURE ZStudySessionSelector du kernel',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final config = makeConfig();
    final selector = container
        .read(zStudySessionSelectorProvider(ZSessionConfigKey(config)));
    expect(selector, isA<ZStudySessionSelector>());
    expect(selector.config, same(config));
  });
}
