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
  testWidgets('résout un seam via un provider enregistré (AC4)', (tester) async {
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

  testWidgets('resolver lève ZScopeError pour un type sans provider (AC4)',
      (tester) async {
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

  test('zFormControllerProvider : auto-dispose branché sur ref.onDispose (AC4)',
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
    expect(spy.disposed, isTrue,
        reason: 'auto-dispose exécuté au dispose du conteneur (pas de fuite)');
  });

  testWidgets('démontage du scope dispose le controller auto-dispose (AC4)',
      (tester) async {
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
    expect(spy.disposed, isTrue,
        reason: 'container disposé au démontage → onDispose du controller');
  });
}
