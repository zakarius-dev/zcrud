// Gardes : un `ZcrudScope` posé SOUS le `Navigator` est-il visible depuis une
// route poussée (dialogue, feuille modale, menu) ?
//
// 🔴 MOTIF — `ZcrudScope` était un simple `InheritedWidget`. Une route poussée
// naît dans une AUTRE branche de l'arbre (l'`Overlay` du `Navigator`) : elle
// n'hérite que de ce qui vit AU-DESSUS du `Navigator`, plus les
// `InheritedTheme` que le framework CAPTURE au point d'appel. Un scope posé
// sous `home` (le cas courant) était donc invisible d'un `showDialog` — le
// dialogue perdait les jetons (`theme`), les libellés (`labels`), les seams et
// l'ACL, et retombait sur les défauts : ACL refusante, jetons dérivés du
// `ColorScheme`, libellés du paquet. Seules les `ThemeData.extensions`
// passaient, parce que `Theme` est un `InheritedTheme`.
//
// Ces gardes n'ajoutent AUCUNE `ThemeData.extension` : elles posent le jeton
// UNIQUEMENT par `ZcrudScope(theme: …)`. Si le scope ne traverse pas, la valeur
// lue dans la route est celle du repli — l'assertion rougit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Jeton invraisemblable : aucun repli dérivé d'un `ColorScheme` ne peut le
/// produire par hasard.
const Color _kJeton = Color(0xFF00C853);

/// Seam témoin : l'identité de CETTE instance doit se retrouver dans la route.
class _SeamRenderer extends ZListRenderer {
  _SeamRenderer();
  @override
  Widget build(
    BuildContext context,
    ZListRenderRequest request, {
    ZListInteraction? interaction,
  }) =>
      const SizedBox.shrink();
}

/// Monte une `MaterialApp` dont le `home` porte un `ZcrudScope` (donc SOUS le
/// `Navigator`) et un bouton qui pousse une route.
Future<void> _pumpSousNavigator(
  WidgetTester tester, {
  required ZcrudScope Function(Widget bouton) scope,
  required Future<void> Function(BuildContext context) ouvrir,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (_) => scope(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => ouvrir(context),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  // ── (a) showDialog ───────────────────────────────────────────────────────
  testWidgets(
      '🔴 showDialog : le jeton du ZcrudScope posé sous le Navigator traverse '
      'la route poussée', (tester) async {
    Color? vuDansLaRoute;

    await tester.pumpWidget(
      MaterialApp(
        // Le scope est posé SOUS le `Navigator` de `MaterialApp` : c'est le
        // placement courant, et celui qui échouait.
        home: ZcrudScope(
          theme: const ZcrudTheme(fieldBorderColor: _kJeton),
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) {
                  vuDansLaRoute = ZcrudTheme.of(dialogContext).fieldBorderColor;
                  return const SizedBox.shrink();
                },
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(vuDansLaRoute, _kJeton,
        reason: 'le dialogue doit lire le jeton du scope, pas le repli');
  });

  testWidgets('🔴 showDialog : les `labels` du scope traversent la route',
      (tester) async {
    String? vu;
    final ZcrudLabels labels = ZcrudLabels(<String, String>{'zP1s': 'du-scope'});

    await _pumpSousNavigator(
      tester,
      scope: (bouton) => ZcrudScope(labels: labels, child: bouton),
      ouvrir: (context) => showDialog<void>(
        context: context,
        builder: (dialogContext) {
          vu = ZcrudScope.maybeOf(dialogContext)
              ?.labels
              ?.resolve('zP1s', fallback: 'REPLI');
          return const SizedBox.shrink();
        },
      ),
    );

    expect(vu, 'du-scope',
        reason: 'le registre de libellés du scope doit suivre la route');
  });

  testWidgets('🔴 showDialog : un seam du scope traverse la route À IDENTITÉ '
      'ÉGALE', (tester) async {
    final ZListRenderer seam = _SeamRenderer();
    Object? vu;

    await _pumpSousNavigator(
      tester,
      scope: (bouton) => ZcrudScope(listRenderer: seam, child: bouton),
      ouvrir: (context) => showDialog<void>(
        context: context,
        builder: (dialogContext) {
          vu = ZcrudScope.maybeOf(dialogContext)?.listRenderer;
          return const SizedBox.shrink();
        },
      ),
    );

    // Identité, pas égalité : re-poser un seam RECONSTRUIT invaliderait les
    // caches des dépendants et ne serait pas la même couture.
    expect(identical(vu, seam), isTrue,
        reason: 'le seam doit être la MÊME instance dans la route');
  });

  testWidgets('🔴 showDialog : l\'ACL accordée dans le scope reste accordée '
      'dans la route', (tester) async {
    bool? peutCreer;
    Object? aclVue;
    const ZAcl acl = ZAllowAllAcl();

    await _pumpSousNavigator(
      tester,
      scope: (bouton) => ZcrudScope(acl: acl, child: bouton),
      ouvrir: (context) => showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final ZcrudScope? s = ZcrudScope.maybeOf(dialogContext);
          aclVue = s?.acl;
          peutCreer = s?.acl.can(ZCrudAction.create);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(identical(aclVue, acl), isTrue,
        reason: 'la MÊME ACL doit être vue dans la route');
    expect(peutCreer, isTrue);
  });

  testWidgets(
      '🔴 SÉCURITÉ : hors de tout scope, la route reste FAIL-CLOSED (la '
      'capture ne fabrique aucun scope)', (tester) async {
    ZcrudScope? scopeVu;
    ZAcl? aclDerivee;
    Color? jetonVu;

    await tester.pumpWidget(
      MaterialApp(
        // AUCUN ZcrudScope dans l'arbre.
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) {
                scopeVu = ZcrudScope.maybeOf(dialogContext);
                aclDerivee = ZcrudScope.derive(
                  dialogContext,
                  child: const SizedBox.shrink(),
                ).acl;
                jetonVu = ZcrudTheme.of(dialogContext).fieldBorderColor;
                return const SizedBox.shrink();
              },
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(scopeVu, isNull, reason: 'aucun scope ne doit être inventé');
    expect(aclDerivee, isA<ZDenyAllAcl>(),
        reason: 'refus par défaut : la règle de sécurité est inchangée');
    expect(aclDerivee!.can(ZCrudAction.create), isFalse);
    expect(jetonVu, isNot(_kJeton));
  });

  // ── (b) feuille modale et menu ───────────────────────────────────────────
  testWidgets('🔴 showModalBottomSheet : le jeton du scope traverse',
      (tester) async {
    Color? vu;

    await _pumpSousNavigator(
      tester,
      scope: (bouton) => ZcrudScope(
        theme: const ZcrudTheme(fieldBorderColor: _kJeton),
        child: bouton,
      ),
      ouvrir: (context) => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) {
          vu = ZcrudTheme.of(sheetContext).fieldBorderColor;
          return const SizedBox.shrink();
        },
      ),
    );

    expect(vu, _kJeton);
  });

  testWidgets('🔴 showMenu : le jeton du scope traverse', (tester) async {
    Color? vu;

    await _pumpSousNavigator(
      tester,
      scope: (bouton) => ZcrudScope(
        theme: const ZcrudTheme(fieldBorderColor: _kJeton),
        child: bouton,
      ),
      ouvrir: (context) => showMenu<void>(
        context: context,
        position: const RelativeRect.fromLTRB(0, 0, 0, 0),
        items: <PopupMenuEntry<void>>[
          PopupMenuItem<void>(
            child: Builder(
              builder: (menuContext) {
                vu = ZcrudTheme.of(menuContext).fieldBorderColor;
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );

    expect(vu, _kJeton);
  });

  // ── (c) inertie : sans route poussée, RIEN ne bouge ──────────────────────
  testWidgets('🔴 INERTIE : sans route poussée, `of` rend la MÊME instance et '
      'aucun dépendant ne se reconstruit', (tester) async {
    int builds = 0;
    late ZcrudScope vu;

    final ZcrudScope scope = ZcrudScope(
      theme: const ZcrudTheme(fieldBorderColor: _kJeton),
      child: Builder(
        builder: (context) {
          builds++;
          vu = ZcrudScope.of(context);
          return const SizedBox.shrink();
        },
      ),
    );

    await tester.pumpWidget(MaterialApp(home: scope));
    expect(builds, 1);
    expect(identical(vu, scope), isTrue,
        reason: '`of` doit rendre le widget posé, pas une copie');

    // Re-pump du MÊME widget : aucun rebuild du dépendant.
    await tester.pumpWidget(MaterialApp(home: scope));
    expect(builds, 1, reason: 'aucune notification ne doit être émise');
    expect(identical(vu, scope), isTrue);
  });

  testWidgets('🔴 INERTIE : un `wrap` ne notifie AUCUN dépendant (seams '
      'identiques)', (tester) async {
    final ZListRenderer seam = _SeamRenderer();
    final ZcrudLabels labels = ZcrudLabels(<String, String>{'zP1s': 'x'});
    const ZAcl acl = ZAllowAllAcl();
    const ZcrudTheme theme = ZcrudTheme(fieldBorderColor: _kJeton);

    late BuildContext ctx;
    final ZcrudScope scope = ZcrudScope(
      acl: acl,
      labels: labels,
      theme: theme,
      listRenderer: seam,
      child: Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox.shrink();
        },
      ),
    );
    await tester.pumpWidget(MaterialApp(home: scope));

    final Widget enveloppe = scope.wrap(ctx, const SizedBox.shrink());
    expect(enveloppe, isA<ZcrudScope>());
    final ZcrudScope copie = enveloppe as ZcrudScope;

    // Un `wrap` re-pose le MÊME bundle : aucun dépendant ne doit se
    // reconstruire de ce seul fait.
    expect(copie.updateShouldNotify(scope), isFalse,
        reason: 'une re-pose identique ne doit JAMAIS notifier');
    expect(identical(copie.acl, acl), isTrue);
    expect(identical(copie.labels, labels), isTrue);
    expect(identical(copie.theme, theme), isTrue);
    expect(identical(copie.listRenderer, seam), isTrue);
    expect(copie.key, isNull,
        reason: 'la clé du scope encore monté ne doit jamais être reprise');
  });

  // ── (d) adversariale : c'est le scope DÉRIVÉ le plus proche qui est capturé
  testWidgets('🔴 ADVERSARIALE : la route capture le scope DÉRIVÉ le plus '
      'proche, pas la racine', (tester) async {
    String? vu;
    final ZcrudLabels racine = ZcrudLabels(<String, String>{'zP1s': 'RACINE'});
    final ZcrudLabels proche = ZcrudLabels(<String, String>{'zP1s': 'PROCHE'});

    await tester.pumpWidget(
      // Scope RACINE posé AU-DESSUS du `Navigator` : il est donc déjà visible
      // d'une route poussée par simple héritage. Si la capture ne remontait pas
      // le scope dérivé, la route lirait « RACINE » — c'est exactement le
      // faux-vert que cette garde interdit.
      ZcrudScope(
        labels: racine,
        child: MaterialApp(
          home: Builder(
            builder: (context) => ZcrudScope.derive(
              context,
              labels: proche,
              child: Builder(
                builder: (inner) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: inner,
                    builder: (dialogContext) {
                      vu = ZcrudScope.maybeOf(dialogContext)
                          ?.labels
                          ?.resolve('zP1s', fallback: 'REPLI');
                      return const SizedBox.shrink();
                    },
                  ),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(vu, 'PROCHE',
        reason: 'le scope capturé est le plus proche du point d\'appel');
  });
}
