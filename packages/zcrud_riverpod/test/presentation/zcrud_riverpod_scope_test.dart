// E2-9 AC4/AC8 : `ZcrudRiverpodScope` monte un ProviderScope, résout un seam via
// `ZcrudScope.of(context).resolver`, et expose un ZFormController auto-dispose.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_riverpod/zcrud_riverpod.dart';

/// Seam applicatif fictif fourni par l'hôte (démonstration).
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

/// Controller espion pour prouver l'auto-dispose.
class _SpyController extends ZFormController {
  bool disposed = false;
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

final _demoSeamProvider = Provider<_DemoSeam>((ref) => const _DemoSeam('ok'));

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
                return ZcrudRiverpodScope(
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
      expect(boundScope.resolver, isA<ZRiverpodResolver>());
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
        child: ZcrudRiverpodScope(
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
    expect(boundScope.resolver, isA<ZRiverpodResolver>());
    expect(boundScope.acl, isA<ZDenyAllAcl>());
    expect(boundScope.acl.can(ZCrudAction.create), isFalse);
  });

  testWidgets('résout un seam via un provider enregistré (AC4)', (
    tester,
  ) async {
    late _DemoSeam resolved;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudRiverpodScope(
          seams: {_DemoSeam: _demoSeamProvider},
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

  testWidgets('resolver lève ZScopeError pour un type sans provider (AC4)', (
    tester,
  ) async {
    late ZDependencyResolver resolver;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudRiverpodScope(
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

  test(
    'zFormControllerProvider : auto-dispose branché sur ref.onDispose (AC4)',
    () {
      final spy = _SpyController();
      final container = ProviderContainer(
        overrides: [
          zFormControllerProvider.overrideWith((ref) {
            ref.onDispose(spy.dispose);
            return spy;
          }),
        ],
      );
      // Maintient le provider vivant tant que le conteneur l'est.
      final sub = container.listen(zFormControllerProvider, (_, __) {});
      expect(sub.read(), same(spy));
      expect(spy.disposed, isFalse);

      container.dispose();
      expect(
        spy.disposed,
        isTrue,
        reason: 'auto-dispose exécuté au dispose du conteneur (pas de fuite)',
      );
    },
  );

  testWidgets('démontage du scope dispose le controller auto-dispose (AC4)', (
    tester,
  ) async {
    final spy = _SpyController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudRiverpodScope(
          overrides: [
            zFormControllerProvider.overrideWith((ref) {
              ref.onDispose(spy.dispose);
              return spy;
            }),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              // Écoute le provider pour l'instancier réellement.
              ref.watch(zFormControllerProvider);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(spy.disposed, isFalse);

    await tester.pumpWidget(const SizedBox());
    expect(
      spy.disposed,
      isTrue,
      reason: 'container disposé au démontage → onDispose du controller',
    );
  });
}
