// E2-9 AC3/AC8 : `ZcrudGetScope` monte un locator get_it, y résout un seam via
// `ZcrudScope.of(context).resolver`, et dispose le `ZFormController` possédé au
// démontage (pas de fuite). Bridge GetX optionnel couvert aussi.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_get/zcrud_get.dart';

/// Seam applicatif fictif fourni par l'hôte (démonstration, pas de métier réel).
class _DemoSeam {
  const _DemoSeam(this.label);
  final String label;
}

class _HostResolver extends ZDependencyResolver {
  const _HostResolver();

  @override
  T resolve<T>() => throw StateError('resolver hôte non destiné à résoudre');
}

class _MarkerAcl implements ZAcl {
  const _MarkerAcl(this.allowed);

  final bool allowed;

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      allowed;
}

/// Controller espion pour prouver le `dispose()` au démontage.
class _SpyController extends ZFormController {
  bool disposed = false;
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  testWidgets(
    'complète le scope ambiant, mais le resolver et l’ACL du binding priment',
    (tester) async {
      const hostResolver = _HostResolver();
      const hostAcl = _MarkerAcl(true);
      const bindingAcl = _MarkerAcl(false);
      const hostTheme = ZcrudTheme(gapS: 17);
      final hostWidgetRegistry = ZWidgetRegistry();
      final hostSubListRegistry = ZSubListSeamRegistry();
      late ZcrudScope hostScope;
      late ZcrudScope boundScope;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudScope(
            resolver: hostResolver,
            acl: hostAcl,
            theme: hostTheme,
            widgetRegistry: hostWidgetRegistry,
            subListSeamRegistry: hostSubListRegistry,
            child: Builder(
              builder: (hostContext) {
                hostScope = ZcrudScope.of(hostContext);
                return ZcrudGetScope(
                  locator: GetIt.asNewInstance(),
                  acl: bindingAcl,
                  child: Builder(
                    builder: (boundContext) {
                      boundScope = ZcrudScope.of(boundContext);
                      return const SizedBox();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(boundScope, isNot(same(hostScope)));
      expect(boundScope.theme, same(hostTheme));
      expect(boundScope.widgetRegistry, same(hostWidgetRegistry));
      expect(boundScope.subListSeamRegistry, same(hostSubListRegistry));
      expect(boundScope.resolver, isA<ZGetResolver>());
      expect(boundScope.resolver, isNot(same(hostResolver)));
      expect(boundScope.acl, same(bindingAcl));
      expect(boundScope.acl, isNot(same(hostAcl)));
    },
  );

  testWidgets('sans scope ambiant, conserve les replis zéro-config', (
    tester,
  ) async {
    late ZcrudScope boundScope;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudGetScope(
          locator: GetIt.asNewInstance(),
          child: Builder(
            builder: (context) {
              boundScope = ZcrudScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(boundScope.theme, isNull);
    expect(boundScope.widgetRegistry, isNull);
    expect(boundScope.subListSeamRegistry, isNull);
    expect(boundScope.resolver, isA<ZGetResolver>());
    expect(boundScope.acl, isA<ZDenyAllAcl>());
    expect(boundScope.acl.can(ZCrudAction.create), isFalse);
  });

  testWidgets('résout un seam enregistré dans get_it via le resolver (AC3)', (
    tester,
  ) async {
    final locator = GetIt.asNewInstance()
      ..registerSingleton<_DemoSeam>(const _DemoSeam('ok'));
    late _DemoSeam resolved;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudGetScope(
          locator: locator,
          child: Builder(
            builder: (context) {
              resolved = ZcrudScope.of(context).resolver.resolve<_DemoSeam>();
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(resolved.label, 'ok');
  });

  testWidgets('resolver lève ZScopeError pour un type non enregistré (AC3)', (
    tester,
  ) async {
    late ZDependencyResolver resolver;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudGetScope(
          locator: GetIt.asNewInstance(),
          child: Builder(
            builder: (context) {
              resolver = ZcrudScope.of(context).resolver;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(() => resolver.resolve<_DemoSeam>(), throwsA(isA<ZScopeError>()));
  });

  testWidgets(
    'dispose le ZFormController possédé au démontage (AC3, pas de fuite)',
    (tester) async {
      final spy = _SpyController();
      final locator = GetIt.asNewInstance();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudGetScope(
            locator: locator,
            createController: () => spy,
            child: const SizedBox(),
          ),
        ),
      );
      expect(spy.disposed, isFalse);
      expect(locator.isRegistered<ZFormController>(), isTrue);

      // Démontage du scope.
      await tester.pumpWidget(const SizedBox());
      expect(spy.disposed, isTrue, reason: 'controller disposé au démontage');
      expect(
        locator.isRegistered<ZFormController>(),
        isFalse,
        reason: 'controller désenregistré du locator',
      );
    },
  );

  testWidgets('locator PARTAGÉ + deux ZcrudGetScope : dispose de l\'un ⇒ le '
      'ZFormController de l\'autre SURVIT (résoluble) (MEDIUM-2)', (
    tester,
  ) async {
    // Locator applicatif PARTAGÉ (scénario E7-1 : DODLP passe son getIt global).
    final shared = GetIt.asNewInstance();
    final ctrlA = _SpyController();
    final ctrlB = _SpyController();

    Widget scope(ZFormController controller) => ZcrudGetScope(
      key: ObjectKey(controller),
      locator: shared,
      createController: () => controller,
      child: const SizedBox(),
    );

    // Monte les DEUX scopes sur le MÊME locator.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [scope(ctrlA), scope(ctrlB)]),
      ),
    );

    // Un seul ZFormController occupe le slot de type du locator partagé : le
    // PREMIER scope (a) en est le propriétaire ; le second ne le réenregistre pas.
    expect(shared.isRegistered<ZFormController>(), isTrue);
    expect(
      identical(shared.get<ZFormController>(), ctrlA),
      isTrue,
      reason: 'le premier scope possède l\'enregistrement partagé',
    );

    // Démonte le SECOND scope (b) — NON-propriétaire de l'enregistrement.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [scope(ctrlA)]),
      ),
    );

    // MEDIUM-2 : le dispose du scope non-propriétaire NE désenregistre PAS le
    // controller d'autrui — celui du scope (a) survit et reste résoluble.
    expect(
      shared.isRegistered<ZFormController>(),
      isTrue,
      reason: 'MEDIUM-2 : le dispose de b ne touche pas l\'enregistrement de a',
    );
    expect(
      identical(shared.get<ZFormController>(), ctrlA),
      isTrue,
      reason: 'le ZFormController du scope survivant reste résoluble',
    );
    expect(
      ctrlB.disposed,
      isTrue,
      reason: 'le scope démonté dispose SON propre controller',
    );
    expect(
      ctrlA.disposed,
      isFalse,
      reason: 'le controller du scope encore monté reste vivant',
    );
  });

  testWidgets(
    'bridge GetX : Get.put à l\'entrée, Get.delete au démontage (AC3)',
    (tester) async {
      addTearDown(Get.reset);
      final spy = _SpyController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudGetScope(
            locator: GetIt.asNewInstance(),
            createController: () => spy,
            registerInGetX: true,
            child: const SizedBox(),
          ),
        ),
      );
      expect(
        Get.isRegistered<ZFormController>(),
        isTrue,
        reason: 'controller résoluble via Get.find dans une app GetX',
      );

      await tester.pumpWidget(const SizedBox());
      expect(
        Get.isRegistered<ZFormController>(),
        isFalse,
        reason: 'Get.delete au démontage',
      );
      expect(spy.disposed, isTrue);
    },
  );
}
