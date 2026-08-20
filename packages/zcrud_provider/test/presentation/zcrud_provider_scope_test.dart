// E2-9 AC5/AC8 : `ZcrudProviderScope` monte un ChangeNotifierProvider, résout un
// seam via `ZcrudScope.of(context).resolver` (context.read), et laisse `provider`
// disposer le ZFormController au démontage.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_provider/zcrud_provider.dart';

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

/// Controller espion pour prouver le dispose géré par `provider`.
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
    'le Builder complète l’ambiant sans se dériver du scope qu’il crée',
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
                return ZcrudProviderScope(
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

      expect(find.byType(ZcrudScope), findsNWidgets(2));
      expect(boundScope, isNot(same(hostScope)));
      expect(boundScope.theme, same(hostTheme));
      expect(boundScope.widgetRegistry, same(hostWidgetRegistry));
      expect(boundScope.subListSeamRegistry, same(hostSubListRegistry));
      expect(boundScope.resolver, isA<ZProviderResolver>());
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
        child: ZcrudProviderScope(
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
    expect(boundScope.resolver, isA<ZProviderResolver>());
    expect(boundScope.acl, isA<ZDenyAllAcl>());
    expect(boundScope.acl.can(ZCrudAction.create), isFalse);
  });

  testWidgets('résout un seam via context.read (AC5)', (tester) async {
    late _DemoSeam resolved;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudProviderScope(
          providers: [Provider<_DemoSeam>.value(value: const _DemoSeam('ok'))],
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

  testWidgets('resolver lève ZScopeError pour un type sans provider (AC5)', (
    tester,
  ) async {
    late ZDependencyResolver resolver;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudProviderScope(
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
    'provider dispose le ZFormController au démontage (AC5, pas de fuite)',
    (tester) async {
      final spy = _SpyController();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudProviderScope(
            createController: () => spy,
            child: const SizedBox(),
          ),
        ),
      );
      expect(spy.disposed, isFalse);

      await tester.pumpWidget(const SizedBox());
      expect(
        spy.disposed,
        isTrue,
        reason: 'ChangeNotifierProvider dispose le controller au démontage',
      );
    },
  );

  testWidgets('le ZFormController exposé est résoluble (context.read) (AC5)', (
    tester,
  ) async {
    late ZFormController resolved;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudProviderScope(
          child: Builder(
            builder: (context) {
              resolved = ZcrudScope.of(
                context,
              ).resolver.resolve<ZFormController>();
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(resolved, isA<ZFormController>());
  });
}
