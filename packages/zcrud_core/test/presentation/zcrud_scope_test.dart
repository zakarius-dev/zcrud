// AC4/AC5 : `ZcrudScope` (InheritedWidget, défaut zéro-config) + seams throw.
import 'package:flutter/material.dart';
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
  }) => const SizedBox();
}

void main() {
  testWidgets('of() sans scope dans l\'arbre lève ZScopeError (AC5)', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox();
        },
      ),
    );
    expect(() => ZcrudScope.of(ctx), throwsA(isA<ZScopeError>()));
    expect(ZcrudScope.maybeOf(ctx), isNull);
  });

  testWidgets('scope par défaut expose ZAllowAllAcl permissive (AC5)', (
    tester,
  ) async {
    late ZcrudScope scope;
    await tester.pumpWidget(
      ZcrudScope(
        child: Builder(
          builder: (context) {
            scope = ZcrudScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(scope.acl, isA<ZAllowAllAcl>());
    expect(scope.acl.can(ZCrudAction.view), isTrue);
    expect(scope.acl.can(ZCrudAction.delete), isTrue);
  });

  testWidgets('resolver non fourni (défaut throwing) lève ZScopeError (AC4)', (
    tester,
  ) async {
    late ZcrudScope scope;
    await tester.pumpWidget(
      ZcrudScope(
        child: Builder(
          builder: (context) {
            scope = ZcrudScope.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(() => scope.resolver.resolve<String>(), throwsA(isA<ZScopeError>()));
  });

  testWidgets('resolver fourni retourne la valeur injectée (AC4)', (
    tester,
  ) async {
    late ZcrudScope scope;
    await tester.pumpWidget(
      ZcrudScope(
        resolver: const _FakeResolver('injecté'),
        child: Builder(
          builder: (context) {
            scope = ZcrudScope.of(context);
            return const SizedBox();
          },
        ),
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
    const scopeDiffResolver = ZcrudScope(
      resolver: _FakeResolver('x'),
      acl: acl,
      child: child,
    );

    expect(scopeA.updateShouldNotify(scopeSame), isFalse);
    expect(scopeA.updateShouldNotify(scopeDiffResolver), isTrue);
  });

  test('E2-8 : labels/theme null par défaut (zéro-config préservé, AC9)', () {
    const scope = ZcrudScope(child: SizedBox());
    expect(scope.labels, isNull);
    expect(scope.theme, isNull);
  });

  testWidgets('E2-8 : labels/theme injectés exposés par of() (AC5/AC9)', (
    tester,
  ) async {
    final labels = ZcrudLabels({'save': 'Valider'});
    const theme = ZcrudTheme();
    late ZcrudScope scope;
    await tester.pumpWidget(
      ZcrudScope(
        labels: labels,
        theme: theme,
        child: Builder(
          builder: (context) {
            scope = ZcrudScope.of(context);
            return const SizedBox();
          },
        ),
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
    expect(base.updateShouldNotify(const ZcrudScope(child: child)), isTrue);
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

  test('copyWith : un seam omis hérite, un seam nommé remplace', () {
    const child = SizedBox();
    final labels = ZcrudLabels({'save': 'Valider'});
    const theme = ZcrudTheme();
    const aclParent = ZAllowAllAcl();
    final parent = ZcrudScope(
      resolver: const _FakeResolver('parent'),
      acl: aclParent,
      labels: labels,
      theme: theme,
      listRenderer: const _FakeListRenderer(),
      child: child,
    );

    const aclEcran = _DenyAllAcl();
    final derived = parent.copyWith(acl: aclEcran, child: const SizedBox());

    // Le seam nommé est remplacé.
    expect(identical(derived.acl, aclEcran), isTrue);
    // Tout seam omis hérite — nullable (labels/theme/listRenderer) comme
    // non nullable (resolver).
    expect(identical(derived.resolver, parent.resolver), isTrue);
    expect(identical(derived.labels, labels), isTrue);
    expect(identical(derived.theme, theme), isTrue);
    expect(identical(derived.listRenderer, parent.listRenderer), isTrue);
  });

  test('copyWith : `null` explicite remet un seam nullable à son repli', () {
    final parent = ZcrudScope(
      labels: ZcrudLabels({'save': 'Valider'}),
      theme: const ZcrudTheme(),
      child: const SizedBox(),
    );

    final reset = parent.copyWith(labels: null, child: const SizedBox());

    expect(reset.labels, isNull, reason: '`null` explicite doit REMETTRE');
    expect(reset.theme, isNotNull, reason: 'un seam omis doit HÉRITER');
  });

  testWidgets('derive : dérive le scope ambiant en ne remplaçant que les '
      'seams nommés', (tester) async {
    final labels = ZcrudLabels({'save': 'Valider'});
    const aclEcran = _DenyAllAcl();
    late ZcrudScope inner;
    await tester.pumpWidget(
      ZcrudScope(
        resolver: const _FakeResolver('ambiant'),
        labels: labels,
        child: Builder(
          builder: (context) => ZcrudScope.derive(
            context,
            acl: aclEcran,
            child: Builder(
              builder: (context) {
                inner = ZcrudScope.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(identical(inner.acl, aclEcran), isTrue);
    expect(identical(inner.labels, labels), isTrue);
    expect(inner.resolver.resolve<String>(), 'ambiant');
  });

  testWidgets('derive sans scope ambiant : part du scope zéro-config', (
    tester,
  ) async {
    late ZcrudScope inner;
    await tester.pumpWidget(
      Builder(
        builder: (context) => ZcrudScope.derive(
          context,
          acl: const _DenyAllAcl(),
          child: Builder(
            builder: (context) {
              inner = ZcrudScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(inner.acl, isA<_DenyAllAcl>());
    expect(inner.labels, isNull);
    expect(() => inner.resolver.resolve<String>(), throwsA(isA<ZScopeError>()));
  });

  test(
    'G9 : les 18 seams, dont reorder/drop/gradient, notifient isolément',
    () {
      const child = SizedBox();
      ZGradientSpec? gradientA(ColorScheme scheme, String key) => null;
      ZGradientSpec? gradientB(ColorScheme scheme, String key) => null;
      final base = ZcrudScope(child: child);
      expect(base.updateShouldNotify(const ZcrudScope(child: child)), isFalse);
      expect(
        base.updateShouldNotify(
          const ZcrudScope(
            reorderRenderer: _FakeReorderRenderer(),
            child: child,
          ),
        ),
        isTrue,
      );
      expect(
        base.updateShouldNotify(
          const ZcrudScope(
            dropRegionRenderer: _FakeDropRegionRenderer(),
            child: child,
          ),
        ),
        isTrue,
      );
      expect(
        base.updateShouldNotify(
          ZcrudScope(gradientResolver: gradientA, child: child),
        ),
        isTrue,
      );
      expect(
        ZcrudScope(
          gradientResolver: gradientA,
          child: child,
        ).updateShouldNotify(
          ZcrudScope(gradientResolver: gradientB, child: child),
        ),
        isTrue,
      );
    },
  );
}

/// ACL qui refuse tout — pour distinguer une surcharge du défaut permissif.
class _DenyAllAcl implements ZAcl {
  const _DenyAllAcl();
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      false;
}

class _FakeReorderRenderer extends ZReorderRenderer {
  const _FakeReorderRenderer();

  @override
  Widget build(BuildContext context, ZReorderRenderRequest request) =>
      const SizedBox();
}

class _FakeDropRegionRenderer extends ZDropRegionRenderer {
  const _FakeDropRegionRenderer();

  @override
  Widget build(BuildContext context, ZDropRegionRequest request) =>
      const SizedBox();
}
