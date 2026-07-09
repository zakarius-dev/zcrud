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
  testWidgets('résout un seam via context.read (AC5)', (tester) async {
    late _DemoSeam resolved;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudProviderScope(
          providers: [
            Provider<_DemoSeam>.value(value: const _DemoSeam('ok')),
          ],
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

  testWidgets('resolver lève ZScopeError pour un type sans provider (AC5)',
      (tester) async {
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

  testWidgets('provider dispose le ZFormController au démontage (AC5, pas de fuite)',
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
    expect(spy.disposed, isTrue,
        reason: 'ChangeNotifierProvider dispose le controller au démontage');
  });

  testWidgets('le ZFormController exposé est résoluble (context.read) (AC5)',
      (tester) async {
    late ZFormController resolved;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudProviderScope(
          child: Builder(
            builder: (context) {
              resolved =
                  ZcrudScope.of(context).resolver.resolve<ZFormController>();
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(resolved, isA<ZFormController>());
  });
}
