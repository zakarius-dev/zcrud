/// **CR-IFFD-63** — la typographie de l'en-tête de page est ATTEIGNABLE :
/// titre, sous-titre, onglet sélectionné, onglet non sélectionné.
///
/// Ce que cette suite verrouille, dans l'ordre :
///
/// 1. **Le défaut ne bouge pas.** Sans paramètre ni jeton, l'arbre et le style
///    rendu sont **identiques** à ceux d'une app-bar Material nue. `ZPageScaffold`
///    est GÉNÉRIQUE : un défaut distinctif s'imposerait à tout hôte, y compris
///    celui qui ne l'a pas demandé.
/// 2. **La priorité stricte** paramètre > jeton `ZcrudTheme` > défaut, sur les
///    quatre créneaux.
/// 3. **La couleur est ignorée** — et ce n'est pas un choix de goût :
///    * sur le titre, elle doit rester héritée du `foregroundColor` pour rester
///      lisible sous un dégradé d'identité ;
///    * sur les onglets, `TabBar` dérive sa couleur de sélection de
///      `labelStyle?.color` : un style coloré **écrase** la distinction
///      sélectionné/non-sélectionné.
/// 4. **La retombée du SDK est neutralisée** : régler le seul style sélectionné
///    ne doit pas mettre TOUS les onglets au style sélectionné.
/// 5. Les **quatre modes** d'app-bar sont couverts (fixe ET slivers).
/// 6. Le **mode recherche** est explicitement HORS périmètre : le champ garde
///    son style.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Style RÉELLEMENT peint par le `RenderParagraph` du texte [data] — après
/// fusion de tous les `DefaultTextStyle` de la chaîne.
TextStyle _painted(WidgetTester tester, String data) =>
    tester.renderObject<RenderParagraph>(find.text(data)).text.style!;

List<ZPageTab> _tabs() => <ZPageTab>[
  ZPageTab(label: 'Alpha', contentBuilder: (_) => const Text('corpsA')),
  ZPageTab(label: 'Beta', contentBuilder: (_) => const Text('corpsB')),
];

Widget _host({
  required Widget child,
  ZcrudTheme? tokens,
  ZGradientResolver? gradient,
  TextDirection direction = TextDirection.ltr,
}) {
  final Widget app = MaterialApp(
    home: Directionality(textDirection: direction, child: child),
  );
  if (tokens == null && gradient == null) return app;
  return ZcrudScope(theme: tokens, gradientResolver: gradient, child: app);
}

ZGradientSpec _gradientSpec(ColorScheme scheme, String key) => ZGradientSpec(
  gradient: LinearGradient(
    colors: <Color>[scheme.primary, scheme.secondary],
  ),
  onGradient: scheme.onPrimary,
);

void main() {
  group('CR-IFFD-63 ① — le DÉFAUT ne bouge pas', () {
    testWidgets('titre : style peint IDENTIQUE à une AppBar Material nue', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(appBar: AppBar(title: const Text('TITRE'))),
        ),
      );
      await tester.pumpAndSettle();
      final TextStyle reference = _painted(tester, 'TITRE');

      await tester.pumpWidget(
        _host(child: const ZPageScaffold(title: 'TITRE')),
      );
      await tester.pumpAndSettle();
      final TextStyle actual = _painted(tester, 'TITRE');

      expect(
        <Object?>[
          actual.fontSize,
          actual.fontWeight,
          actual.letterSpacing,
          actual.height,
          actual.color,
        ],
        <Object?>[
          reference.fontSize,
          reference.fontWeight,
          reference.letterSpacing,
          reference.height,
          reference.color,
        ],
        reason:
            '🔴 le titre de `ZPageScaffold` a cessé d\'être celui d\'une '
            'AppBar Material nue : un défaut distinctif s\'imposerait à TOUT '
            'hôte du socle, y compris celui qui ne l\'a pas demandé.',
      );
      // La garde n'est pas VACUELLE : la référence est bien le défaut M3
      // (`titleLarge` en poids NORMAL) — donc un passage en gras la ferait
      // rougir, elle ne mesure pas « n'importe quoi égale n'importe quoi ».
      expect(reference.fontSize, 22.0);
      expect(reference.fontWeight, FontWeight.w400);
    });

    testWidgets('titre : AUCUNE enveloppe de style n\'entre dans l\'arbre', (
      tester,
    ) async {
      Future<int> defaultTextStyles({TextStyle? param}) async {
        await tester.pumpWidget(
          _host(child: ZPageScaffold(title: 'TITRE', titleTextStyle: param)),
        );
        await tester.pumpAndSettle();
        return find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(DefaultTextStyle),
            )
            .evaluate()
            .length;
      }

      final int sansReglage = await defaultTextStyles();
      final int avecReglage = await defaultTextStyles(
        param: const TextStyle(fontWeight: FontWeight.w700),
      );
      expect(
        avecReglage,
        sansReglage + 1,
        reason:
            '🔴 AD-4 : sans réglage, aucune enveloppe ne doit être posée '
            '(pas de widget inerte) ; avec réglage, exactement UNE.',
      );
    });

    testWidgets('onglets : labelStyle ET unselectedLabelStyle restent nuls', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(child: ZPageScaffold(title: 'T', tabs: _tabs())),
      );
      await tester.pumpAndSettle();
      final TabBar bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.labelStyle, isNull);
      expect(bar.unselectedLabelStyle, isNull);
      // Non-vacuité : le rendu M3 par défaut ne distingue PAS par le poids
      // (les deux onglets sont en w500) — c'est le constat de la CR.
      expect(_painted(tester, 'Alpha').fontWeight, FontWeight.w500);
      expect(_painted(tester, 'Beta').fontWeight, FontWeight.w500);
      expect(
        _painted(tester, 'Alpha').color,
        isNot(_painted(tester, 'Beta').color),
        reason: 'la distinction par la COULEUR existe déjà et doit survivre',
      );
    });

    testWidgets('sous-titre : métriques de titleSmall, comme avant', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          child: const ZPageScaffold(
            title: 'T',
            subtitle: Text('SOUS'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final TextStyle small = Theme.of(
        tester.element(find.text('SOUS')),
      ).textTheme.titleSmall!;
      final TextStyle painted = _painted(tester, 'SOUS');
      expect(painted.fontSize, small.fontSize);
      expect(painted.fontWeight, small.fontWeight);
    });
  });

  group('CR-IFFD-63 ② — priorité paramètre > jeton > défaut', () {
    testWidgets('TITRE : les trois niveaux', (tester) async {
      // (a) jeton seul.
      await tester.pumpWidget(
        _host(
          tokens: const ZcrudTheme(
            pageHeaderTitleStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 26,
            ),
          ),
          child: const ZPageScaffold(title: 'TITRE'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester, 'TITRE').fontWeight, FontWeight.w600);
      expect(_painted(tester, 'TITRE').fontSize, 26.0);

      // (b) paramètre + jeton ⇒ le PARAMÈTRE prime, entièrement.
      await tester.pumpWidget(
        _host(
          tokens: const ZcrudTheme(
            pageHeaderTitleStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 26,
            ),
          ),
          child: const ZPageScaffold(
            title: 'TITRE',
            titleTextStyle: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 30,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester, 'TITRE').fontWeight, FontWeight.w900);
      expect(_painted(tester, 'TITRE').fontSize, 30.0);

      // (c) ni l'un ni l'autre ⇒ défaut M3.
      await tester.pumpWidget(
        _host(child: const ZPageScaffold(title: 'TITRE')),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester, 'TITRE').fontWeight, FontWeight.w400);
      expect(_painted(tester, 'TITRE').fontSize, 22.0);
    });

    testWidgets('SOUS-TITRE : les trois niveaux', (tester) async {
      await tester.pumpWidget(
        _host(
          tokens: const ZcrudTheme(
            pageHeaderSubtitleStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          child: const ZPageScaffold(title: 'T', subtitle: Text('SOUS')),
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester, 'SOUS').fontSize, 11.0);
      expect(_painted(tester, 'SOUS').fontWeight, FontWeight.w600);

      await tester.pumpWidget(
        _host(
          tokens: const ZcrudTheme(
            pageHeaderSubtitleStyle: TextStyle(fontSize: 11),
          ),
          child: const ZPageScaffold(
            title: 'T',
            subtitle: Text('SOUS'),
            subtitleTextStyle: TextStyle(fontSize: 9),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester, 'SOUS').fontSize, 9.0);
    });

    testWidgets('ONGLETS : les trois niveaux, sélectionné ET non sélectionné', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          tokens: const ZcrudTheme(
            pageHeaderTabSelectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w700,
            ),
            pageHeaderTabUnselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w300,
            ),
          ),
          child: ZPageScaffold(title: 'T', tabs: _tabs()),
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester, 'Alpha').fontWeight, FontWeight.w700);
      expect(_painted(tester, 'Beta').fontWeight, FontWeight.w300);

      await tester.pumpWidget(
        _host(
          tokens: const ZcrudTheme(
            pageHeaderTabSelectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w700,
            ),
            pageHeaderTabUnselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w300,
            ),
          ),
          child: ZPageScaffold(
            title: 'T',
            tabs: _tabs(),
            tabLabelStyle: const TextStyle(fontWeight: FontWeight.w900),
            tabUnselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w100,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester, 'Alpha').fontWeight, FontWeight.w900);
      expect(_painted(tester, 'Beta').fontWeight, FontWeight.w100);
    });
  });

  group('CR-IFFD-63 ③ — la COULEUR est ignorée (et pourquoi)', () {
    testWidgets(
      'titre : le poids passe, la couleur reste celle du dégradé d\'identité',
      (tester) async {
        await tester.pumpWidget(
          _host(
            gradient: _gradientSpec,
            child: const ZPageScaffold(
              title: 'TITRE',
              gradientKey: 'dossier-1',
              // Un hôte distrait joint une couleur à sa demande de graisse.
              titleTextStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF00FF00),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final ColorScheme scheme = Theme.of(
          tester.element(find.text('TITRE')),
        ).colorScheme;
        final TextStyle painted = _painted(tester, 'TITRE');
        expect(painted.fontWeight, FontWeight.w700);
        expect(
          painted.color,
          scheme.onPrimary,
          reason:
              '🔴 la couleur du titre DOIT rester celle imposée par le '
              'dégradé d\'identité (`ZGradientSpec.onGradient`). Laisser '
              'passer la couleur du style rendrait le titre illisible sur '
              'une app-bar teintée — le défaut que `_zSubtitleSlice` évite '
              'depuis CR-IFFD-34.',
        );
        expect(painted.color, isNot(const Color(0xFF00FF00)));
      },
    );

    testWidgets(
      'onglets : un style coloré ne DÉTRUIT pas la distinction de sélection',
      (tester) async {
        // Référence : couleurs de sélection sans aucun réglage.
        await tester.pumpWidget(
          _host(child: ZPageScaffold(title: 'T', tabs: _tabs())),
        );
        await tester.pumpAndSettle();
        final Color refSelected = _painted(tester, 'Alpha').color!;
        final Color refUnselected = _painted(tester, 'Beta').color!;
        expect(refSelected, isNot(refUnselected));

        await tester.pumpWidget(
          _host(
            child: ZPageScaffold(
              title: 'T',
              tabs: _tabs(),
              tabLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF123456),
              ),
              tabUnselectedLabelStyle: const TextStyle(
                color: Color(0xFF123456),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_painted(tester, 'Alpha').fontWeight, FontWeight.w700);
        expect(
          _painted(tester, 'Alpha').color,
          refSelected,
          reason:
              '🔴 `TabBar` dérive sa couleur de sélection de '
              '`labelStyle?.color` : laisser passer la couleur alignerait '
              'les deux onglets sur la MÊME teinte et supprimerait un canal '
              'de distinction (mesuré).',
        );
        expect(_painted(tester, 'Beta').color, refUnselected);
      },
    );
  });

  group('CR-IFFD-63 ④ — la retombée du SDK est neutralisée', () {
    testWidgets(
      'régler le SEUL style sélectionné ne met pas TOUS les onglets en gras',
      (tester) async {
        await tester.pumpWidget(
          _host(
            child: ZPageScaffold(
              title: 'T',
              tabs: _tabs(),
              tabLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_painted(tester, 'Alpha').fontWeight, FontWeight.w700);
        expect(
          _painted(tester, 'Beta').fontWeight,
          FontWeight.w500,
          reason:
              '🔴 `TabBar` résout son style non sélectionné par '
              '`unselectedLabelStyle ?? tabBarTheme.unselectedLabelStyle ?? '
              'labelStyle` : sans neutralisation explicite, demander « le '
              'gras sur l\'onglet courant » met TOUS les onglets en gras et '
              'annule la distinction demandée (mesuré).',
        );
      },
    );

    testWidgets('le `TabBarTheme` de l\'hôte reste atteignable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            tabBarTheme: const TabBarThemeData(
              unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w200),
            ),
          ),
          home: ZPageScaffold(
            title: 'T',
            tabs: _tabs(),
            tabLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester, 'Alpha').fontWeight, FontWeight.w700);
      expect(
        _painted(tester, 'Beta').fontWeight,
        FontWeight.w200,
        reason:
            '🔴 la neutralisation ne doit pas ÉCRASER le style non '
            'sélectionné déclaré par l\'hôte dans son `TabBarTheme` (leçon '
            'CR-LEX-73 : ne jamais rendre inatteignable un slot du thème).',
      );
    });
  });

  group('CR-IFFD-63 ⑤ — les QUATRE modes d\'app-bar', () {
    for (final ZPageAppBarMode mode in ZPageAppBarMode.values) {
      testWidgets('mode $mode : titre ET onglets atteignables', (tester) async {
        await tester.pumpWidget(
          _host(
            tokens: const ZcrudTheme(
              pageHeaderTitleStyle: TextStyle(fontWeight: FontWeight.w800),
              pageHeaderTabSelectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            child: ZPageScaffold(title: 'TITRE', mode: mode, tabs: _tabs()),
          ),
        );
        await tester.pumpAndSettle();
        expect(_painted(tester, 'TITRE').fontWeight, FontWeight.w800);
        expect(_painted(tester, 'Alpha').fontWeight, FontWeight.w800);
        expect(_painted(tester, 'Beta').fontWeight, FontWeight.w500);
      });

      // 🔴 Volet PARAMÈTRE, distinct du volet jeton ci-dessus. Le jeton est lu
      // par le site de rendu lui-même (`ZcrudTheme.of(context)`) : il continue
      // donc de fonctionner même si la PROPAGATION du paramètre vers la
      // branche sliver est cassée. Mesuré en campagne R3 : couper
      // `titleTextStyle` dans `_buildSliver` laissait la variante « jeton »
      // VERTE. Sans ce volet, la propagation n'était pas gardée.
      testWidgets('mode $mode : les PARAMÈTRES atteignent le site de rendu', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            child: ZPageScaffold(
              title: 'TITRE',
              subtitle: const Text('SOUS'),
              mode: mode,
              tabs: _tabs(),
              titleTextStyle: const TextStyle(fontWeight: FontWeight.w800),
              subtitleTextStyle: const TextStyle(fontSize: 9),
              tabLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabUnselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w200,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_painted(tester, 'TITRE').fontWeight, FontWeight.w800);
        expect(_painted(tester, 'SOUS').fontSize, 9.0);
        expect(_painted(tester, 'Alpha').fontWeight, FontWeight.w800);
        expect(_painted(tester, 'Beta').fontWeight, FontWeight.w200);
      });
    }

    testWidgets('ZPageShellBody (sans Scaffold) porte les mêmes créneaux', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          child: Scaffold(
            body: ZPageShellBody(
              title: 'TITRE',
              subtitle: const Text('SOUS'),
              tabs: _tabs(),
              titleTextStyle: const TextStyle(fontWeight: FontWeight.w800),
              subtitleTextStyle: const TextStyle(fontSize: 9),
              tabLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester, 'TITRE').fontWeight, FontWeight.w800);
      expect(_painted(tester, 'SOUS').fontSize, 9.0);
      expect(_painted(tester, 'Alpha').fontWeight, FontWeight.w800);
      expect(_painted(tester, 'Beta').fontWeight, FontWeight.w500);
    });

    testWidgets('ZSearchableAppBar seule porte titre et sous-titre', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          child: const Scaffold(
            appBar: ZSearchableAppBar(
              title: 'TITRE',
              subtitle: Text('SOUS'),
              titleTextStyle: TextStyle(fontWeight: FontWeight.w800),
              subtitleTextStyle: TextStyle(fontSize: 9),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester, 'TITRE').fontWeight, FontWeight.w800);
      expect(_painted(tester, 'SOUS').fontSize, 9.0);
    });
  });

  group('CR-IFFD-63 ⑥ — mode RECHERCHE : hors périmètre, et prouvé', () {
    testWidgets('le champ de recherche garde son style, titre absent', (
      tester,
    ) async {
      // Clé DISTINCTE par passage : sans elle, le second `pumpWidget` réutilise
      // l'`State` du premier — la recherche est déjà ouverte et le tap sur la
      // loupe échoue (mesuré). Ce n'est pas un détail de test : c'est la preuve
      // que l'état de recherche est bien DÉTENU par le widget (AD-2).
      Future<TextStyle?> fieldStyle(String key, {TextStyle? param}) async {
        await tester.pumpWidget(
          _host(
            child: ZPageScaffold(
              key: ValueKey<String>(key),
              title: 'TITRE',
              titleTextStyle: param,
              search: ZAppBarSearchConfig(onQueryChanged: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        return tester.widget<TextField>(find.byType(TextField)).style;
      }

      final TextStyle? sansReglage = await fieldStyle('nu');
      final TextStyle? avecReglage = await fieldStyle(
        'stylé',
        param: const TextStyle(fontWeight: FontWeight.w900),
      );
      expect(find.text('TITRE'), findsNothing);
      expect(
        avecReglage,
        sansReglage,
        reason:
            '🔴 le champ de recherche n\'est PAS le titre : lui imposer la '
            'graisse d\'un titre ferait saisir l\'utilisateur en gras.',
      );
      // Non-vacuité : le style du champ EST bien défini (donc l'égalité
      // ci-dessus ne compare pas `null` à `null`).
      expect(sansReglage, isNotNull);
      expect(sansReglage!.fontSize, 22.0);
    });

    testWidgets('AUCUNE enveloppe de style n\'est posée sur le champ', (
      tester,
    ) async {
      // Volet STRUCTUREL du test précédent. `TextField.style` porte
      // `inherit: false` : une enveloppe `DefaultTextStyle` posée par erreur
      // autour du champ ne changerait PAS ce `style` et resterait donc
      // invisible à la comparaison ci-dessus (leçon CR-IFFD-42). On compte
      // donc les enveloppes.
      Future<int> wrappers({TextStyle? param, required String key}) async {
        await tester.pumpWidget(
          _host(
            child: ZPageScaffold(
              key: ValueKey<String>(key),
              title: 'TITRE',
              titleTextStyle: param,
              search: ZAppBarSearchConfig(onQueryChanged: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        return find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(DefaultTextStyle),
            )
            .evaluate()
            .length;
      }

      final int nu = await wrappers(key: 'nu2');
      final int style = await wrappers(
        key: 'stylé2',
        param: const TextStyle(fontWeight: FontWeight.w900),
      );
      expect(
        style,
        nu,
        reason:
            '🔴 en mode recherche, le style de titre ne doit poser AUCUNE '
            'enveloppe : le champ n\'est pas un titre.',
      );
      // Non-vacuité : l'app-bar en porte bien (le décompte n'est pas 0 = 0).
      expect(nu, greaterThan(0));
    });
  });

  group('CR-IFFD-63 ⑦ — A11y / RTL', () {
    testWidgets('RTL : titre et onglets stylés, cibles ≥ 48 dp', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          direction: TextDirection.rtl,
          child: ZPageScaffold(
            title: 'TITRE',
            tabs: _tabs(),
            titleTextStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
            actions: <ZAppBarAction>[
              ZAppBarAction(
                icon: Icons.add,
                semanticLabel: 'ajouter',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_painted(tester, 'TITRE').fontWeight, FontWeight.w800);
      expect(_painted(tester, 'Alpha').fontWeight, FontWeight.w800);
      // La bande d'onglets reste une cible ≥ 48 dp malgré le restylage.
      expect(
        tester.getSize(find.byType(TabBar)).height,
        greaterThanOrEqualTo(48.0),
      );
      // La sémantique des actions n'est pas altérée par le restylage.
      expect(find.bySemanticsLabel('ajouter'), findsOneWidget);
    });

    testWidgets('un style d\'onglet plus GRAND ne rétrécit pas la cible', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          child: ZPageScaffold(
            title: 'T',
            tabs: _tabs(),
            tabLabelStyle: const TextStyle(fontSize: 24),
            tabUnselectedLabelStyle: const TextStyle(fontSize: 24),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(TabBar)).height,
        greaterThanOrEqualTo(48.0),
      );
    });
  });
}
