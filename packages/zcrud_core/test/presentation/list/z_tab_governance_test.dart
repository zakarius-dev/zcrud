// Gardes des **onglets gouvernés** : cascade d'autorisations (onglet ⊂ écran
// ⊂ scope), non-élargissement, et pastille de comptage qui se rafraîchit sans
// reconstruire la page de l'onglet (AD-2).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// ACL n'autorisant que les actions de [allowed].
class OnlyAcl implements ZAcl {
  const OnlyAcl(this.allowed);

  final Set<ZCrudAction> allowed;

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      allowed.contains(action);
}

/// Sonde : rend, pour chaque action citée, le verdict de l'ACL **ambiante**
/// telle que la voit la page de l'onglet.
class AclProbe extends StatelessWidget {
  const AclProbe({required this.actions, super.key});

  final List<ZCrudAction> actions;

  @override
  Widget build(BuildContext context) {
    final acl = ZcrudScope.maybeOf(context)?.acl;
    return Column(
      children: <Widget>[
        for (final action in actions)
          Text(
            '${action.name}=${acl == null ? 'absent' : acl.can(action)}',
            key: ValueKey<String>('probe_${action.name}'),
          ),
      ],
    );
  }
}

String probeOf(WidgetTester tester, ZCrudAction action) =>
    tester.widget<Text>(find.byKey(ValueKey<String>('probe_${action.name}')))
        .data!;

/// Page d'onglet qui **compte ses constructions**.
class CountingPage extends StatelessWidget {
  const CountingPage({required this.builds, super.key});

  final List<int> builds;

  @override
  Widget build(BuildContext context) {
    builds.add(1);
    return const Text('page');
  }
}

Future<void> pumpTabs(
  WidgetTester tester,
  List<ZListTab> tabs, {
  ZAcl? scopeAcl,
}) async {
  final Widget tabbed = ZTabbedList(tabs: tabs);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: scopeAcl == null
            ? tabbed
            : ZcrudScope(acl: scopeAcl, child: tabbed),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ZRestrictedAcl — la composition est une INTERSECTION', () {
    test('un droit accordé des deux côtés passe ; refusé d\'un seul, tombe',
        () {
      const base = OnlyAcl(<ZCrudAction>{ZCrudAction.view, ZCrudAction.update});
      const restriction =
          OnlyAcl(<ZCrudAction>{ZCrudAction.view, ZCrudAction.delete});
      const composed = ZRestrictedAcl(base, restriction);
      expect(composed.can(ZCrudAction.view), isTrue);
      // Accordé par la base seule ⇒ refusé.
      expect(composed.can(ZCrudAction.update), isFalse);
      // Accordé par la restriction seule ⇒ refusé : PAS d'élargissement.
      expect(composed.can(ZCrudAction.delete), isFalse);
      expect(composed.can(ZCrudAction.create), isFalse);
    });

    test(
        'ADVERSARIAL : la restriction la PLUS permissive possible n\'ouvre '
        'rien — un refus de base reste un refus', () {
      const base = ZDenyAllAcl();
      const composed = ZRestrictedAcl(base, ZAllowAllAcl());
      for (final action in ZCrudAction.values) {
        expect(
          composed.can(action),
          isFalse,
          reason: '${action.name} : une ACL permissive au niveau bas a rouvert '
              'un geste refusé au niveau haut',
        );
      }
    });

    test('zRestrictAcl sans restriction rend la base TELLE QUELLE', () {
      const base = ZAllowAllAcl();
      expect(identical(zRestrictAcl(base, null), base), isTrue);
      expect(zRestrictAcl(base, const ZDenyAllAcl()).can(ZCrudAction.view),
          isFalse);
    });
  });

  group('ZListTab.acl — cascade onglet > écran > scope', () {
    testWidgets(
        'niveau ONGLET : l\'onglet retire un geste que le niveau supérieur '
        'accordait', (tester) async {
      await pumpTabs(
        tester,
        <ZListTab>[
          ZListTab(
            labelKey: 'closed',
            acl: const OnlyAcl(<ZCrudAction>{ZCrudAction.view}),
            builder: (_) => const AclProbe(
              actions: <ZCrudAction>[ZCrudAction.view, ZCrudAction.update],
            ),
          ),
        ],
        scopeAcl: const ZAllowAllAcl(),
      );
      expect(probeOf(tester, ZCrudAction.view), 'view=true');
      expect(probeOf(tester, ZCrudAction.update), 'update=false');
    });

    testWidgets(
        'niveau SCOPE : ADVERSARIAL — un onglet TOUT PERMISSIF ne rouvre pas '
        'un geste refusé par le scope', (tester) async {
      await pumpTabs(
        tester,
        <ZListTab>[
          ZListTab(
            labelKey: 'all',
            acl: const ZAllowAllAcl(),
            builder: (_) => const AclProbe(
              actions: <ZCrudAction>[ZCrudAction.view, ZCrudAction.delete],
            ),
          ),
        ],
        scopeAcl: const OnlyAcl(<ZCrudAction>{ZCrudAction.view}),
      );
      expect(probeOf(tester, ZCrudAction.view), 'view=true');
      expect(
        probeOf(tester, ZCrudAction.delete),
        'delete=false',
        reason: 'la déclaration de l\'onglet a ÉLARGI un droit refusé au scope',
      );
    });

    testWidgets(
        'AUCUN niveau supérieur : un onglet permissif n\'accorde rien '
        '(fail-closed)', (tester) async {
      await pumpTabs(
        tester,
        <ZListTab>[
          ZListTab(
            labelKey: 'all',
            acl: const ZAllowAllAcl(),
            builder: (_) => const AclProbe(
              actions: <ZCrudAction>[ZCrudAction.view],
            ),
          ),
        ],
      );
      expect(probeOf(tester, ZCrudAction.view), 'view=false');
    });

    testWidgets(
        'CONTRE-TÉMOIN : sans acl d\'onglet, la page voit l\'ACL ambiante '
        'INCHANGÉE', (tester) async {
      await pumpTabs(
        tester,
        <ZListTab>[
          ZListTab(
            labelKey: 'plain',
            builder: (_) => const AclProbe(
              actions: <ZCrudAction>[ZCrudAction.view, ZCrudAction.delete],
            ),
          ),
        ],
        scopeAcl: const OnlyAcl(<ZCrudAction>{
          ZCrudAction.view,
          ZCrudAction.delete,
        }),
      );
      expect(probeOf(tester, ZCrudAction.view), 'view=true');
      expect(probeOf(tester, ZCrudAction.delete), 'delete=true');
    });
  });

  group('ZListTab.countOf — pastille de comptage', () {
    testWidgets('le compte est affiché à côté du libellé', (tester) async {
      final counter = ValueNotifier<int>(3);
      addTearDown(counter.dispose);
      await pumpTabs(
        tester,
        <ZListTab>[
          ZListTab(
            labelKey: 'pieces',
            countOf: counter,
            builder: (_) => const Text('page'),
          ),
        ],
      );
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets(
        'AD-2 : changer le compte redessine la PASTILLE, pas la page de '
        'l\'onglet', (tester) async {
      final counter = ValueNotifier<int>(1);
      addTearDown(counter.dispose);
      final builds = <int>[];
      await pumpTabs(
        tester,
        <ZListTab>[
          ZListTab(
            labelKey: 'pieces',
            countOf: counter,
            builder: (_) => CountingPage(builds: builds),
          ),
        ],
      );
      expect(find.text('1'), findsOneWidget);
      final before = builds.length;
      expect(before, greaterThan(0));

      counter.value = 7;
      await tester.pump();

      expect(find.text('7'), findsOneWidget);
      expect(
        builds.length,
        before,
        reason: 'la page de l\'onglet a été reconstruite alors que SEUL le '
            'compte a changé',
      );
    });

    testWidgets('compte nul : aucune pastille (le zéro n\'apprend rien)',
        (tester) async {
      final counter = ValueNotifier<int>(0);
      addTearDown(counter.dispose);
      await pumpTabs(
        tester,
        <ZListTab>[
          ZListTab(
            labelKey: 'pieces',
            countOf: counter,
            builder: (_) => const Text('page'),
          ),
        ],
      );
      expect(find.text('0'), findsNothing);
    });

    testWidgets(
        'CONTRE-TÉMOIN : sans countOf, le libellé est rendu seul (aucune '
        'pastille)', (tester) async {
      await pumpTabs(
        tester,
        <ZListTab>[
          ZListTab(labelKey: 'pieces', builder: (_) => const Text('page')),
        ],
      );
      expect(find.text('pieces'), findsOneWidget);
      expect(find.byType(Row), findsNothing);
    });
  });

  group('ZListTab.titles — intitulés par onglet', () {
    test('transporté tel quel, sans interprétation par le cœur', () {
      const titles = ZCrudTitles(create: 'Nouvelle pièce');
      final tab = ZListTab(
        labelKey: 'pieces',
        titles: titles,
        builder: (_) => const SizedBox.shrink(),
      );
      expect(tab.titles, same(titles));
      expect(
        ZListTab(labelKey: 'x', builder: (_) => const SizedBox.shrink()).titles,
        isNull,
      );
    });
  });
}
