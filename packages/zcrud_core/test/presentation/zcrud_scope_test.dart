// AC4/AC5 : `ZcrudScope` (InheritedWidget, défaut zéro-config) + seams throw.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Resolver fake fournissant une valeur `String` (AC4 : seam fourni).
class _FakeResolver extends ZDependencyResolver {
  const _FakeResolver(this.value);
  final String value;
  @override
  T resolve<T>() => value as T;
}

/// Faux `ZListRenderer` const (E4-1, AC3) — zéro Syncfusion.
class _FakeListRenderer extends ZListRenderer {
  const _FakeListRenderer();
  @override
  Widget build(
    BuildContext context,
    ZListRenderRequest request, {
    ZListInteraction? interaction,
  }) =>
      const SizedBox();
}

void main() {
  testWidgets('of() sans scope dans l\'arbre lève ZScopeError (AC5)',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }),
    );
    expect(() => ZcrudScope.of(ctx), throwsA(isA<ZScopeError>()));
    expect(ZcrudScope.maybeOf(ctx), isNull);
  });

  testWidgets('scope par défaut expose ZAllowAllAcl permissive (AC5)',
      (tester) async {
    late ZcrudScope scope;
    await tester.pumpWidget(
      ZcrudScope(
        child: Builder(builder: (context) {
          scope = ZcrudScope.of(context);
          return const SizedBox();
        }),
      ),
    );
    expect(scope.acl, isA<ZAllowAllAcl>());
    expect(scope.acl.can(ZCrudAction.view), isTrue);
    expect(scope.acl.can(ZCrudAction.delete), isTrue);
  });

  testWidgets('resolver non fourni (défaut throwing) lève ZScopeError (AC4)',
      (tester) async {
    late ZcrudScope scope;
    await tester.pumpWidget(
      ZcrudScope(
        child: Builder(builder: (context) {
          scope = ZcrudScope.of(context);
          return const SizedBox();
        }),
      ),
    );
    expect(() => scope.resolver.resolve<String>(),
        throwsA(isA<ZScopeError>()));
  });

  testWidgets('resolver fourni retourne la valeur injectée (AC4)',
      (tester) async {
    late ZcrudScope scope;
    await tester.pumpWidget(
      ZcrudScope(
        resolver: const _FakeResolver('injecté'),
        child: Builder(builder: (context) {
          scope = ZcrudScope.of(context);
          return const SizedBox();
        }),
      ),
    );
    expect(scope.resolver.resolve<String>(), 'injecté');
  });

  test('updateShouldNotify : true ssi le bundle change (AC5)', () {
    const child = SizedBox();
    const acl = ZAllowAllAcl();
    const r1 = ZDependencyResolver.throwing;
    const scopeA = ZcrudScope(resolver: r1, acl: acl, child: child);
    const scopeSame = ZcrudScope(resolver: r1, acl: acl, child: child);
    const scopeDiffResolver =
        ZcrudScope(resolver: _FakeResolver('x'), acl: acl, child: child);

    expect(scopeA.updateShouldNotify(scopeSame), isFalse);
    expect(scopeA.updateShouldNotify(scopeDiffResolver), isTrue);
  });

  test('E2-8 : labels/theme null par défaut (zéro-config préservé, AC9)', () {
    const scope = ZcrudScope(child: SizedBox());
    expect(scope.labels, isNull);
    expect(scope.theme, isNull);
  });

  testWidgets('E2-8 : labels/theme injectés exposés par of() (AC5/AC9)',
      (tester) async {
    final labels = ZcrudLabels({'save': 'Valider'});
    const theme = ZcrudTheme();
    late ZcrudScope scope;
    await tester.pumpWidget(
      ZcrudScope(
        labels: labels,
        theme: theme,
        child: Builder(builder: (context) {
          scope = ZcrudScope.of(context);
          return const SizedBox();
        }),
      ),
    );
    expect(identical(scope.labels, labels), isTrue);
    expect(identical(scope.theme, theme), isTrue);
  });

  test('E4-1 : listRenderer null par défaut (zéro-config préservé, AC3)', () {
    const scope = ZcrudScope(child: SizedBox());
    expect(scope.listRenderer, isNull);
  });

  test('E4-1 : updateShouldNotify sensible à listRenderer (AC3)', () {
    const child = SizedBox();
    const renderer = _FakeListRenderer();
    const base = ZcrudScope(listRenderer: renderer, child: child);
    expect(
      base.updateShouldNotify(
        const ZcrudScope(listRenderer: renderer, child: child),
      ),
      isFalse,
    );
    expect(
      base.updateShouldNotify(const ZcrudScope(child: child)),
      isTrue,
    );
  });

  test('E2-8 : updateShouldNotify sensible à labels/theme (AC9)', () {
    const child = SizedBox();
    final labelsA = ZcrudLabels({'save': 'A'});
    final labelsB = ZcrudLabels({'save': 'B'});
    const themeA = ZcrudTheme();
    const themeB = ZcrudTheme(gapM: 99);
    final base = ZcrudScope(labels: labelsA, theme: themeA, child: child);

    expect(
      base.updateShouldNotify(
        ZcrudScope(labels: labelsA, theme: themeA, child: child),
      ),
      isFalse,
    );
    expect(
      base.updateShouldNotify(
        ZcrudScope(labels: labelsB, theme: themeA, child: child),
      ),
      isTrue,
    );
    expect(
      base.updateShouldNotify(
        ZcrudScope(labels: labelsA, theme: themeB, child: child),
      ),
      isTrue,
    );
  });
}
