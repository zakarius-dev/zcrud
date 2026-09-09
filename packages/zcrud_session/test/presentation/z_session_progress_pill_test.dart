/// Style `pill` de `ZSessionProgressIndicator` — pilule compacte « X/Y ».
///
/// Quatre familles de gardes, dont aucune ne se contente de la **présence**
/// d'un widget :
///
/// 1. **ce que la pilule REND** — le texte peint et le fond/premier plan
///    réellement portés par la décoration montée, jamais le passage d'un
///    paramètre ;
/// 2. **la source unique** — le texte peint et le `Semantics(value:)` annoncé
///    dérivent du même `position` borné (corpus ASYMÉTRIQUE : `2/5`, pour
///    qu'une inversion ou un décalage ne puisse pas rester vert) ;
/// 3. **la parité sémantique STRICTE** avec les trois styles préexistants —
///    même couple (label, value) sur le nœud de progression, et progression
///    annoncée **une seule fois** dans le sous-arbre ;
/// 4. **l'inertie** — sans `style:`, l'arbre rendu est STRICTEMENT égal au
///    dump figé pris avant l'ajout du style (égalité de suite, jamais un
///    `contains`).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZcrudScope, ZcrudTheme;
import 'package:zcrud_session/zcrud_session.dart';

/// Signature de l'arbre du SEUL sous-arbre de l'indicateur (racine incluse) —
/// suite ordonnée de `(type, clé)`. Les identités d'instance (`#a1b2c`) sont
/// normalisées : elles varient d'un run à l'autre et ne décrivent aucune forme.
List<String> _treeSignature(WidgetTester tester) => tester
    .widgetList(
      find.descendant(
        of: find.byType(ZSessionProgressIndicator),
        matching: find.byWidgetPredicate((_) => true),
        matchRoot: true,
      ),
    )
    .map(
      (w) =>
          '${w.runtimeType}|${w.key}'.replaceAll(RegExp(r'#[0-9a-f]{5}'), '#…'),
    )
    .toList();

Future<void> _pump(
  WidgetTester tester, {
  ZSessionProgressStyle? style,
  int total = 5,
  int currentIndex = 1,
  ZcrudTheme? theme,
  ZColorPair? Function(ColorScheme, String)? colorKeyResolver,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZcrudScope(
          theme: theme,
          colorKeyResolver: colorKeyResolver,
          child: style == null
              ? ZSessionProgressIndicator(
                  total: total,
                  currentIndex: currentIndex,
                  passThreshold: 3,
                )
              : ZSessionProgressIndicator(
                  total: total,
                  currentIndex: currentIndex,
                  passThreshold: 3,
                  style: style,
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Le `Container` de la pilule — visé par SA clé, jamais un `Container`
/// trouvé au hasard de l'arbre.
Container _pillOf(WidgetTester tester) =>
    tester.widget<Container>(find.byKey(ZSessionProgressIndicator.pillKey));

/// Le `Text` réellement peint DANS la pilule.
Text _pillTextOf(WidgetTester tester) => tester.widget<Text>(
  find.descendant(
    of: find.byKey(ZSessionProgressIndicator.pillKey),
    matching: find.byType(Text),
  ),
);

/// La décoration réellement montée par la pilule.
ShapeDecoration _pillDecorationOf(WidgetTester tester) {
  final decoration = _pillOf(tester).decoration;
  if (decoration is ShapeDecoration) return decoration;
  fail(
    'la pilule ne porte pas de ShapeDecoration : sa forme arrondie n\'est '
    'donc pas celle qu\'on croit mesurer (décoration=$decoration)',
  );
}

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // 1 — un style à part entière
  // ══════════════════════════════════════════════════════════════════════════
  group('`pill` — un style à part entière', () {
    testWidgets(
      '🔴 `pill` monte la pilule et AUCUN élément des trois autres styles',
      (tester) async {
        await _pump(tester, style: ZSessionProgressStyle.pill);

        expect(find.byKey(ZSessionProgressIndicator.pillKey), findsOneWidget);
        // 🔴 MORDANT : si `pill` retombait sur un style existant (branche
        // oubliée du `switch`, ou valeur d'enum câblée sur `dots`), ces trois
        // attentes riposteraient.
        expect(
          find.byKey(const ValueKey<String>('zProgressDot_0')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('zProgressSegment_0')),
          findsNothing,
        );
        expect(find.byKey(ZSessionProgressIndicator.linearKey), findsNothing);
      },
    );

    testWidgets(
      '🔴 la pilule est COMPACTE — elle ne s\'étire pas sur la largeur '
      'disponible',
      (tester) async {
        // Contraintes SERRÉES en largeur, comme celles que l'indicateur reçoit
        // d'un `Expanded` : c'est le seul contexte où la compacité se mesure.
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: <Widget>[
                  Expanded(
                    child: ZSessionProgressIndicator(
                      total: 5,
                      currentIndex: 1,
                      passThreshold: 3,
                      style: ZSessionProgressStyle.pill,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final available = tester
            .getSize(find.byType(ZSessionProgressIndicator))
            .width;
        final painted = tester
            .getSize(find.byKey(ZSessionProgressIndicator.pillKey))
            .width;

        // 🔴 MORDANT : sans l'`Align`, la pilule prend TOUTE la largeur
        // (`painted == available`) — ce n'est plus un indicateur compact mais
        // une bande, indistinguable d'une barre.
        expect(available, greaterThan(400), reason: 'contraintes non serrées');
        expect(
          painted,
          lessThan(100),
          reason: '🔴 la pilule s\'étire au lieu de rester compacte',
        );
      },
    );

    testWidgets(
      'la pilule est ARRONDIE — une forme de stade, pas un rectangle',
      (tester) async {
        await _pump(tester, style: ZSessionProgressStyle.pill);

        // 🔴 MORDANT : un `RoundedRectangleBorder` à rayon nul, ou une
        // `BoxDecoration` sans rayon, ne serait plus une pilule.
        expect(
          _pillDecorationOf(tester).shape,
          isA<StadiumBorder>(),
          reason: '🔴 la pilule n\'est pas de forme arrondie',
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2 — source unique : le texte peint EST ce que le lecteur d'écran annonce
  // ══════════════════════════════════════════════════════════════════════════
  group('`pill` — le texte peint et l\'annonce ont la MÊME source', () {
    testWidgets(
      '🔴 la pilule PEINT « 2/5 » et le nœud ANNONCE « 2/5 »',
      (tester) async {
        // Corpus ASYMÉTRIQUE — délibéré : `2/5` distingue l'inversion
        // (« 5/2 »), le décalage 0-based (« 1/5 ») et la position seule
        // (« 2 »). Un corpus symétrique rendrait la garde incapable de rougir.
        await _pump(tester, style: ZSessionProgressStyle.pill);

        expect(_pillTextOf(tester).data, '2/5');
        expect(
          tester
              .getSemantics(
                find.byKey(ZSessionProgressIndicator.progressKey),
              )
              .value,
          '2/5',
        );
      },
    );

    testWidgets(
      '🔴 un `currentIndex` HORS BORNES est borné dans le texte peint AUSSI '
      '(AD-10) — jamais « 100/5 » sous une annonce « 5/5 »',
      (tester) async {
        await _pump(
          tester,
          style: ZSessionProgressStyle.pill,
          total: 5,
          currentIndex: 99,
        );

        expect(tester.takeException(), isNull);
        // 🔴 MORDANT : une pilule qui recalculerait « currentIndex + 1 » pour
        // son propre compte peindrait « 100/5 » pendant que le nœud
        // annoncerait « 5/5 » — exactement la divergence que la source unique
        // interdit.
        expect(_pillTextOf(tester).data, '5/5');
        expect(
          tester
              .getSemantics(
                find.byKey(ZSessionProgressIndicator.progressKey),
              )
              .value,
          '5/5',
        );
      },
    );

    testWidgets('une file VIDE n\'explose pas et peint « 0/0 » (AD-10)', (
      tester,
    ) async {
      await _pump(
        tester,
        style: ZSessionProgressStyle.pill,
        total: 0,
        currentIndex: 0,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(ZSessionProgressIndicator.pillKey), findsOneWidget);
      expect(_pillTextOf(tester).data, '0/0');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3 — couleurs par le SEAM, jamais un rôle en dur
  // ══════════════════════════════════════════════════════════════════════════
  group('`pill` — fond et premier plan viennent du SEAM de couleur', () {
    // Deux teintes qu'aucun `ColorScheme` généré ne produit : si elles
    // apparaissent, c'est que le résolveur hôte a bien été consulté.
    const injected = ZColorPair(
      color: Color(0xFF123456),
      onColor: Color(0xFF654321),
    );

    testWidgets(
      '🔴 un résolveur hôte qui connaît la clé de la pilule CHANGE le fond ET '
      'le premier plan',
      (tester) async {
        await _pump(
          tester,
          style: ZSessionProgressStyle.pill,
          colorKeyResolver: (scheme, key) =>
              key == ZSessionProgressIndicator.pillColorKey ? injected : null,
        );

        // 🔴 MORDANT : un `scheme.primary`/`scheme.error` codé en dur ne
        // consulterait pas le résolveur — aucune de ces deux égalités ne
        // tiendrait.
        expect(_pillDecorationOf(tester).color, injected.color);
        expect(_pillTextOf(tester).style?.color, injected.onColor);
      },
    );

    testWidgets(
      '🔴 le fond de la pilule n\'est JAMAIS le rôle d\'ERREUR du thème',
      (tester) async {
        await _pump(tester, style: ZSessionProgressStyle.pill);

        final scheme = Theme.of(
          tester.element(find.byKey(ZSessionProgressIndicator.pillKey)),
        ).colorScheme;
        final painted = _pillDecorationOf(tester).color;

        // Une progression n'est pas une alerte : la peindre en rouge dirait à
        // l'apprenant qu'il a échoué là où elle ne dit que « où en suis-je ».
        expect(painted, isNot(scheme.error));
        expect(painted, isNot(scheme.errorContainer));
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 4 — parité sémantique STRICTE avec les trois styles préexistants
  // ══════════════════════════════════════════════════════════════════════════
  group('`pill` — parité sémantique STRICTE avec les trois autres styles', () {
    testWidgets(
      '🔴 le couple (label, value) du nœud de progression est IDENTIQUE pour '
      'les QUATRE styles',
      (tester) async {
        final handle = tester.ensureSemantics();
        final announced = <ZSessionProgressStyle, List<String>>{};

        for (final style in ZSessionProgressStyle.values) {
          await _pump(tester, style: style);
          final node = tester.getSemantics(
            find.byKey(ZSessionProgressIndicator.progressKey),
          );
          announced[style] = <String>[node.label, node.value];
        }

        // 🔴 MORDANT : une pilule qui n'annoncerait pas sa position (nœud sans
        // `value`, ou `ExcludeSemantics` posé TROP HAUT) rendrait sa ligne
        // différente des trois autres — c'est la régression d'accessibilité
        // que cette garde interdit. On compare aux trois styles préexistants,
        // pas à une chaîne écrite à la main.
        expect(
          announced[ZSessionProgressStyle.pill],
          announced[ZSessionProgressStyle.dots],
        );
        expect(
          announced[ZSessionProgressStyle.pill],
          announced[ZSessionProgressStyle.segmentedBar],
        );
        expect(
          announced[ZSessionProgressStyle.pill],
          announced[ZSessionProgressStyle.linear],
        );
        // Contre-preuve : la valeur comparée n'est pas vide (sinon les trois
        // égalités ci-dessus seraient vraies par vacuité).
        expect(announced[ZSessionProgressStyle.pill], <String>['2/5', '2/5']);
        handle.dispose();
      },
    );

    testWidgets(
      '🔴 la progression n\'est annoncée QU\'UNE FOIS — le texte de la pilule '
      'ne crée pas un second nœud',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, style: ZSessionProgressStyle.pill);

        // Énumération de TOUS les nœuds du sous-arbre, `label` ET `value`.
        //
        // 🔴 **Compter les nœuds ne suffit PAS** — mesuré : ma première
        // version comptait les nœuds portant « 2/5 » et exigeait `hasLength(1)`.
        // Elle est restée **VERTE** sous l'injection « `ExcludeSemantics`
        // inerte » : le nœud du `Text` n'est pas `container`, donc le framework
        // le **FUSIONNE** dans le nœud parent. Le doublon ne crée aucun nœud
        // supplémentaire — il **allonge le libellé** du nœud existant
        // (« 2/5\n2/5 »), et un lecteur d'écran lit bien deux fois la
        // position. On mesure donc le TEXTE ANNONCÉ, pas le nombre de nœuds.
        final announced = <String>[];
        void visit(SemanticsNode node) {
          announced.add('${node.label}|${node.value}');
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(
          tester.getSemantics(
            find.byKey(ZSessionProgressIndicator.progressKey),
          ),
        );

        // 🔴 MORDANT : sans l'`ExcludeSemantics` autour de la pilule, le
        // libellé annoncé devient « 2/5\n2/5 » — la position est lue deux
        // fois. Égalité STRICTE de la suite : ni `contains`, ni `hasLength`.
        expect(announced, <String>['2/5|2/5']);
        handle.dispose();
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 5 — inertie
  // ══════════════════════════════════════════════════════════════════════════
  group('🧊 Inertie — un hôte qui ne demande RIEN voit le même arbre', () {
    testWidgets(
      'sans `style:`, l\'arbre est STRICTEMENT égal au dump figé d\'avant '
      'l\'ajout du style',
      (tester) async {
        await _pump(tester, total: 4, currentIndex: 1);

        final expected = File('test/support/z_progress_tree_before_pill.txt')
            .readAsLinesSync()
            .where((l) => l.isNotEmpty)
            .toList();
        expect(expected, isNotEmpty, reason: 'dump figé absent');
        expect(
          _treeSignature(tester),
          expected,
          reason:
              'égalité STRICTE de la suite (widget, clé) — jamais un '
              '`contains`, jamais un `length >=`',
        );
      },
    );

    testWidgets('le défaut de l\'enum reste `dots`', (tester) async {
      // 🔴 MORDANT : `pill` promu défaut changerait l'arbre de TOUT hôte
      // passif — la garde d'inertie ci-dessus rougirait, celle-ci nomme la
      // cause.
      expect(
        const ZSessionProgressIndicator(
          total: 1,
          currentIndex: 0,
          passThreshold: 3,
        ).style,
        ZSessionProgressStyle.dots,
      );
    });
  });
}
