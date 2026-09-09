/// Fidélité PARAMÉTRABLE de la progression de session — `ZSessionDotsGeometry`
/// et le style `segmentedMarker`.
///
/// Aucune garde ne se contente du **passage** d'un paramètre : chacune mesure
/// ce qui est réellement **peint** (rectangles montés, appels de canvas
/// enregistrés), parce qu'un paramètre relayé jusqu'à un champ inutilisé
/// laisserait toutes les gardes de « passage » vertes.
///
/// Cinq familles :
///
/// 1. **inertie stricte** — sans géométrie ni style, l'arbre ET les rectangles
///    ET les couleurs ET les rayons sont ceux du dump figé pris avant le lot ;
/// 2. **chaque champ de géométrie a un effet PEINT** — taille, élongation,
///    écart, alignement, débordement, plus leurs bornes (invariant AD-10) ;
/// 3. **le marqueur triangulaire** — trois sommets, sur le SEUL segment
///    courant, au-dessus de segments détachés et tous arrondis ;
/// 4. **RTL** — miroir strict des rectangles peints entre les deux directions ;
/// 5. **parité sémantique** des CINQ styles, et `shouldRepaint` honnête.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZColorPair, ZcrudScope;
import 'package:zcrud_session/zcrud_session.dart';

// ════════════════════════════════════════════════════════════════════════════
// Harnais
// ════════════════════════════════════════════════════════════════════════════

Future<void> _pump(
  WidgetTester tester, {
  ZSessionProgressStyle? style,
  int total = 5,
  int currentIndex = 1,
  ZSessionDotsGeometry? geometry,
  double? markerThickness,
  TextDirection? textDirection,
  ZColorPair? Function(ColorScheme, String)? colorKeyResolver,
  double width = 800,
}) async {
  Widget indicator = ZSessionProgressIndicator(
    total: total,
    currentIndex: currentIndex,
    passThreshold: 3,
    style: style ?? ZSessionProgressStyle.dots,
    dotsGeometry: geometry,
    segmentedMarkerThickness: markerThickness,
  );
  if (textDirection != null) {
    indicator = Directionality(
      textDirection: textDirection,
      child: indicator,
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: width,
            child: ZcrudScope(
              colorKeyResolver: colorKeyResolver,
              child: indicator,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Le point d'index [i], visé par SA clé — jamais un `Container` trouvé au
/// hasard de l'arbre.
Finder _dot(int i) => find.byKey(ValueKey<String>('zProgressDot_$i'));

Rect _dotRect(WidgetTester tester, int i) => tester.getRect(_dot(i));

/// Décoration réellement montée par le point d'index [i].
BoxDecoration _dotDecoration(WidgetTester tester, int i) {
  final container = tester.widget<Container>(
    find.descendant(of: _dot(i), matching: find.byType(Container)),
  );
  final decoration = container.decoration;
  if (decoration is BoxDecoration) return decoration;
  fail('le point $i ne porte pas de BoxDecoration (décoration=$decoration)');
}

/// Rejoue le PEINTRE monté sur un canvas enregistreur et rend ses appels.
///
/// C'est la seule mesure honnête pour un `CustomPainter` : le style n'a aucun
/// widget par segment, il n'y a donc rien à viser avec `getRect`. `toImage()`
/// n'est pas une option (il pend sous le harnais de test).
List<RecordedInvocation> _record(WidgetTester tester) {
  final canvas = TestRecordingCanvas();
  final context = TestRecordingPaintingContext(canvas);
  final box = tester.renderObject<RenderBox>(
    find.byKey(ZSessionProgressIndicator.segmentedMarkerKey),
  );
  box.paint(context, Offset.zero);
  return canvas.invocations;
}

List<RRect> _rrects(List<RecordedInvocation> calls) => calls
    .where((c) => c.invocation.memberName == #drawRRect)
    .map((c) => c.invocation.positionalArguments[0] as RRect)
    .toList();

/// Couleurs des segments, en entiers ARGB.
///
/// ⚠️ **Jamais l'objet `Color`** : `Paint.color` restitue ses composantes
/// depuis des flottants 32 bits, donc une couleur allée-retour par un `Paint`
/// n'est **plus égale** à celle qu'on y a posée — alors que les deux
/// s'impriment à l'identique (`toString` arrondit à quatre décimales). Une
/// comparaison d'objets échouerait ici sans que le message dise pourquoi.
List<int> _rrectColors(List<RecordedInvocation> calls) => calls
    .where((c) => c.invocation.memberName == #drawRRect)
    .map((c) => (c.invocation.positionalArguments[1] as Paint).color.toARGB32())
    .toList();

List<Path> _paths(List<RecordedInvocation> calls) => calls
    .where((c) => c.invocation.memberName == #drawPath)
    .map((c) => c.invocation.positionalArguments[0] as Path)
    .toList();

/// Le peintre réellement monté (comparé, jamais reconstruit à la main).
CustomPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(ZSessionProgressIndicator.segmentedMarkerKey),
  );
  final painter = paint.painter;
  if (painter == null) fail('le style à marqueur ne monte AUCUN peintre');
  return painter;
}

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // 1 — inertie stricte
  // ══════════════════════════════════════════════════════════════════════════
  group('🧊 Inertie — un hôte qui ne pose RIEN voit le rendu d\'avant', () {
    testWidgets(
      'sans géométrie, arbre + rectangles + couleurs + rayons sont STRICTEMENT '
      'égaux au dump figé pris avant le lot',
      (tester) async {
        final frozen = File(
          'test/support/z_progress_tree_before_lotp2b.txt',
        ).readAsLinesSync().where((l) => l.isNotEmpty).toList();
        expect(frozen, isNotEmpty, reason: 'dump figé absent');

        final observed = <String>[];
        for (final total in <int>[4, 12]) {
          await _pump(tester, total: total, currentIndex: 1);
          observed.add('## total=$total');
          final widgets = tester.widgetList(
            find.descendant(
              of: find.byType(ZSessionProgressIndicator),
              matching: find.byWidgetPredicate((_) => true),
              matchRoot: true,
            ),
          );
          for (final w in widgets) {
            observed.add(
              'TREE ${w.runtimeType}|${w.key}'.replaceAll(
                RegExp(r'#[0-9a-f]{5}'),
                '#…',
              ),
            );
          }
          for (var i = 0; i < total; i++) {
            final r = _dotRect(tester, i);
            final d = _dotDecoration(tester, i);
            observed.add(
              'RECT $i|${r.left}|${r.top}|${r.width}|${r.height}'
              '|${d.color}|${d.borderRadius}',
            );
          }
        }

        // 🔴 MORDANT : la moindre dérive de taille, d'écart, d'alignement, de
        // couleur ou de rayon change une ligne. Égalité STRICTE de la suite —
        // ni `contains`, ni `length >=`.
        expect(observed, frozen);
      },
    );

    testWidgets(
      'une géométrie VIDE est indiscernable d\'aucune géométrie — même arbre, '
      'mêmes rectangles',
      (tester) async {
        await _pump(tester, total: 5);
        final without = <Rect>[for (var i = 0; i < 5; i++) _dotRect(tester, i)];

        await _pump(tester, total: 5, geometry: const ZSessionDotsGeometry());
        final withEmpty = <Rect>[
          for (var i = 0; i < 5; i++) _dotRect(tester, i),
        ];

        // 🔴 MORDANT : un défaut de géométrie qui ne serait PAS la valeur
        // d'aujourd'hui (une pilule 14×10 promue défaut, par exemple) écarterait
        // ces deux suites.
        expect(withEmpty, without);
      },
    );

    testWidgets('le défaut de l\'enum reste `dots`', (tester) async {
      // 🔴 MORDANT : `segmentedMarker` promu défaut changerait le rendu de TOUT
      // hôte passif.
      expect(
        const ZSessionProgressIndicator(
          total: 1,
          currentIndex: 0,
          passThreshold: 3,
        ).style,
        ZSessionProgressStyle.dots,
      );
      expect(
        const ZSessionProgressIndicator(
          total: 1,
          currentIndex: 0,
          passThreshold: 3,
        ).dotsGeometry,
        isNull,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2 — chaque champ de géométrie a un effet PEINT
  // ══════════════════════════════════════════════════════════════════════════
  group('Géométrie — chaque champ change ce qui est PEINT', () {
    testWidgets('`inactiveSize` fixe la taille RENDUE des points non courants', (
      tester,
    ) async {
      await _pump(
        tester,
        total: 5,
        currentIndex: 1,
        geometry: const ZSessionDotsGeometry(inactiveSize: Size(14, 10)),
      );

      // 🔴 MORDANT : un champ relayé mais jamais lu laisserait 8×8.
      expect(_dotRect(tester, 0).size, const Size(14, 10));
      expect(_dotRect(tester, 2).size, const Size(14, 10));
      // Contre-preuve : la valeur observée n'est pas le défaut.
      expect(_dotRect(tester, 0).size, isNot(const Size(8, 8)));
    });

    testWidgets(
      '`activeScale` élonge le SEUL point courant, en multipliant sa HAUTEUR',
      (tester) async {
        await _pump(
          tester,
          total: 5,
          currentIndex: 1,
          geometry: const ZSessionDotsGeometry(
            inactiveSize: Size(14, 10),
            activeScale: 2.4,
          ),
        );

        // 24 = 10 × 2,4 — la hauteur, jamais la largeur (14 × 2,4 = 33,6).
        expect(_dotRect(tester, 1).size, const Size(24, 10));
        // 🔴 MORDANT : une échelle appliquée à TOUS les points, ou à la
        // largeur, riposterait sur l'une de ces deux lignes.
        expect(_dotRect(tester, 0).size, const Size(14, 10));
        expect(_dotRect(tester, 1).width, isNot(closeTo(33.6, 0.01)));
      },
    );

    testWidgets('`gap` fixe l\'écart PEINT entre deux points voisins', (
      tester,
    ) async {
      await _pump(
        tester,
        total: 5,
        geometry: const ZSessionDotsGeometry(gap: 12),
      );

      // Mesuré entre le bord droit d'un point et le bord gauche du suivant :
      // c'est l'écart, pas la somme d'un pas et d'une largeur.
      expect(_dotRect(tester, 3).left - _dotRect(tester, 2).right, 12.0);
      // 🔴 MORDANT : le défaut est 4 — un `gap` ignoré laisserait 4.
      expect(_dotRect(tester, 3).left - _dotRect(tester, 2).right, isNot(4.0));
    });

    testWidgets('`gap: 0` est ACCEPTÉ — des points jointifs sont un design', (
      tester,
    ) async {
      await _pump(tester, total: 5, geometry: const ZSessionDotsGeometry(gap: 0));

      // 🔴 MORDANT : une borne `<= 0` retomberait sur le défaut 4.
      expect(_dotRect(tester, 3).left - _dotRect(tester, 2).right, 0.0);
    });

    testWidgets('`alignment` déplace RÉELLEMENT la file dans sa largeur', (
      tester,
    ) async {
      await _pump(tester, total: 5, width: 600);
      final startLeft = _dotRect(tester, 0).left;

      await _pump(
        tester,
        total: 5,
        width: 600,
        geometry: const ZSessionDotsGeometry(alignment: WrapAlignment.center),
      );
      final centerLeft = _dotRect(tester, 0).left;
      // Mesuré DANS la passe centrée : lire ce bord après avoir repompé en
      // alignement `end` mesurerait une autre mise en page.
      final centerRight = _dotRect(tester, 4).right;

      await _pump(
        tester,
        total: 5,
        width: 600,
        geometry: const ZSessionDotsGeometry(alignment: WrapAlignment.end),
      );
      final endLeft = _dotRect(tester, 0).left;

      // 🔴 MORDANT : un alignement relayé mais jamais posé sur le `Wrap`
      // rendrait ces trois valeurs égales.
      expect(startLeft, 0.0);
      expect(centerLeft, greaterThan(startLeft));
      expect(endLeft, greaterThan(centerLeft));
      // La file centrée l'est vraiment : autant d'espace de chaque côté.
      expect(centerLeft, closeTo(600 - centerRight, 0.01));
    });

    testWidgets(
      '`scrollable` garde UNE SEULE rangée là où le défaut passe à la ligne',
      (tester) async {
        // 100 points de 8 dp espacés de 4 : 1 196 dp de file pour 400 dp de
        // large — le débordement est certain, la mesure ne dépend d'aucune
        // marge.
        await _pump(tester, total: 100, width: 400);
        final wrappedTops = <double>{
          for (var i = 0; i < 100; i++) _dotRect(tester, i).top,
        };

        await _pump(
          tester,
          total: 100,
          width: 400,
          geometry: const ZSessionDotsGeometry(scrollable: true),
        );
        final scrolledTops = <double>{
          for (var i = 0; i < 100; i++) _dotRect(tester, i).top,
        };

        // 🔴 MORDANT : sans la branche défilante, la file passerait à la ligne
        // ici AUSSI et les deux ensembles auraient la même cardinalité.
        expect(
          wrappedTops.length,
          greaterThan(1),
          reason: 'le défaut doit passer à la ligne',
        );
        expect(scrolledTops, hasLength(1));
        expect(
          find.descendant(
            of: find.byType(ZSessionProgressIndicator),
            matching: find.byType(Scrollable),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'file défilante : l\'alignement reste opérant tant que la file TIENT',
      (tester) async {
        await _pump(
          tester,
          total: 5,
          width: 600,
          geometry: const ZSessionDotsGeometry(
            scrollable: true,
            alignment: WrapAlignment.center,
          ),
        );
        final centered = _dotRect(tester, 0).left;

        await _pump(
          tester,
          total: 5,
          width: 600,
          geometry: const ZSessionDotsGeometry(scrollable: true),
        );
        final started = _dotRect(tester, 0).left;

        // 🔴 MORDANT : un `Row` laissé s'ajuster à son contenu n'aurait aucun
        // espace libre à distribuer — `center` serait inerte et ces deux
        // valeurs seraient égales.
        expect(started, 0.0);
        expect(centered, greaterThan(0));
      },
    );

    testWidgets(
      'bornes (AD-10) : dimensions absurdes IGNORÉES, jamais une exception ni '
      'un point invisible',
      (tester) async {
        for (final geometry in <ZSessionDotsGeometry>[
          const ZSessionDotsGeometry(inactiveSize: Size(-4, 10)),
          const ZSessionDotsGeometry(inactiveSize: Size(14, 0)),
          ZSessionDotsGeometry(inactiveSize: Size(double.nan, 10)),
          ZSessionDotsGeometry(inactiveSize: Size(14, double.infinity)),
          const ZSessionDotsGeometry(activeScale: -1),
          const ZSessionDotsGeometry(activeScale: 0),
          ZSessionDotsGeometry(activeScale: double.nan),
          const ZSessionDotsGeometry(gap: -5),
          ZSessionDotsGeometry(gap: double.infinity),
        ]) {
          await _pump(tester, total: 5, currentIndex: 1, geometry: geometry);

          expect(tester.takeException(), isNull, reason: '$geometry a levé');
          // Repli COMPLET sur le rendu d'aujourd'hui : 8×8, actif 12×8,
          // écart 4. Une moitié reçue et une moitié dérivée donnerait une
          // forme que personne n'a demandée.
          expect(
            _dotRect(tester, 0).size,
            const Size(8, 8),
            reason: '$geometry n\'est pas retombée sur le défaut',
          );
          expect(_dotRect(tester, 1).size, const Size(12, 8), reason: '$geometry');
          expect(
            _dotRect(tester, 3).left - _dotRect(tester, 2).right,
            4.0,
            reason: '$geometry',
          );
        }
      },
    );

    test('`ZSessionDotsGeometry` est un value-object (égalité par valeur)', () {
      // ⚠️ **Instances DISTINCTES, jamais deux `const` identiques** — mesuré :
      // ma première version comparait deux littéraux `const` de mêmes
      // arguments. Dart les CANONICALISE en un seul objet, si bien qu'une
      // égalité réduite à `identical` restait VERTE : la garde ne mesurait
      // plus l'égalité par valeur, seulement la canonicalisation du
      // compilateur. Les constructions ci-dessous prennent leurs arguments à
      // l'exécution, elles ne peuvent donc pas être fusionnées.
      final size = Size(10 + 4.0, 10);
      final a = ZSessionDotsGeometry(inactiveSize: size, gap: 6 * 2.0);
      final b = ZSessionDotsGeometry(
        inactiveSize: Size(size.width, size.height),
        gap: 12.0,
      );
      final c = ZSessionDotsGeometry(inactiveSize: size, gap: 11.0);

      expect(identical(a, b), isFalse, reason: 'instances confondues');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a, isNot(const ZSessionDotsGeometry()));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3 — le marqueur triangulaire
  // ══════════════════════════════════════════════════════════════════════════
  group('`segmentedMarker` — segments détachés et repère triangulaire', () {
    testWidgets(
      '🔴 `segmentedMarker` monte SON nœud et aucun élément des autres styles',
      (tester) async {
        await _pump(tester, style: ZSessionProgressStyle.segmentedMarker);

        expect(
          find.byKey(ZSessionProgressIndicator.segmentedMarkerKey),
          findsOneWidget,
        );
        // 🔴 MORDANT : une branche oubliée du `switch` retomberait sur `dots`.
        expect(_dot(0), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('zProgressSegment_0')),
          findsNothing,
        );
        expect(find.byKey(ZSessionProgressIndicator.linearKey), findsNothing);
        expect(find.byKey(ZSessionProgressIndicator.pillKey), findsNothing);
      },
    );

    testWidgets(
      'les segments sont DÉTACHÉS et TOUS pleinement arrondis — jamais des '
      'bandes jointives arrondies aux seules extrémités',
      (tester) async {
        await _pump(
          tester,
          style: ZSessionProgressStyle.segmentedMarker,
          total: 5,
          markerThickness: 8,
        );
        final rrects = _rrects(_record(tester));

        expect(rrects, hasLength(5));
        const expected = Radius.circular(4); // épaisseur / 2 ⇒ un stade
        for (var i = 0; i < rrects.length; i++) {
          // 🔴 MORDANT : le patron « arrondi aux seules extrémités » pose
          // `Radius.zero` sur les coins intérieurs — chacune de ces quatre
          // égalités riposterait.
          expect(rrects[i].tlRadius, expected, reason: 'segment $i');
          expect(rrects[i].trRadius, expected, reason: 'segment $i');
          expect(rrects[i].blRadius, expected, reason: 'segment $i');
          expect(rrects[i].brRadius, expected, reason: 'segment $i');
          expect(rrects[i].outerRect.height, 8.0, reason: 'segment $i');
        }
        for (var i = 1; i < rrects.length; i++) {
          // 🔴 MORDANT : des bandes jointives donneraient un écart de 0.
          expect(
            rrects[i].outerRect.left - rrects[i - 1].outerRect.right,
            closeTo(4, 0.01),
            reason: 'segments $i-1/$i non détachés',
          );
        }
      },
    );

    testWidgets(
      '🔴 le marqueur est un TRIANGLE — trois sommets, pas un rectangle',
      (tester) async {
        await _pump(
          tester,
          style: ZSessionProgressStyle.segmentedMarker,
          total: 5,
          currentIndex: 1,
          markerThickness: 8,
        );
        final path = _paths(_record(tester)).single;
        final bounds = path.getBounds();

        // Une seule sous-forme fermée : le chemin n'est pas un assemblage.
        final metrics = path.computeMetrics().toList();
        expect(metrics, hasLength(1));
        expect(metrics.single.isClosed, isTrue);

        // Base = 2 × hauteur (sommet droit), hauteur = épaisseur.
        expect(bounds.width, closeTo(16, 0.01));
        expect(bounds.height, closeTo(8, 0.01));

        // 🔴 MORDANT — c'est ce bloc qui distingue un triangle d'un rectangle
        // de mêmes bornes : un rectangle contiendrait ses deux coins hauts.
        expect(
          path.contains(Offset(bounds.center.dx, bounds.bottom - 0.5)),
          isTrue,
          reason: 'la base du marqueur est vide',
        );
        expect(
          path.contains(Offset(bounds.left + 0.5, bounds.top + 0.5)),
          isFalse,
          reason: '🔴 le marqueur remplit son coin haut-gauche : c\'est un '
              'rectangle, pas un triangle',
        );
        expect(
          path.contains(Offset(bounds.right - 0.5, bounds.top + 0.5)),
          isFalse,
          reason: '🔴 le marqueur remplit son coin haut-droit',
        );
      },
    );

    testWidgets(
      '🔴 le marqueur est sur le SEUL segment courant — absent des autres',
      (tester) async {
        await _pump(
          tester,
          style: ZSessionProgressStyle.segmentedMarker,
          total: 5,
          currentIndex: 3,
          markerThickness: 8,
        );
        final calls = _record(tester);
        final rrects = _rrects(calls);
        final paths = _paths(calls);

        // 🔴 MORDANT : un marqueur peint sur chaque segment en donnerait 5.
        expect(paths, hasLength(1));
        final bounds = paths.single.getBounds();
        expect(
          bounds.center.dx,
          closeTo(rrects[3].outerRect.center.dx, 0.01),
          reason: 'le marqueur ne surmonte pas le segment courant',
        );
        // Et il ne couvre AUCUN autre segment.
        for (var i = 0; i < rrects.length; i++) {
          if (i == 3) continue;
          expect(
            paths.single.contains(
              Offset(rrects[i].outerRect.center.dx, bounds.center.dy),
            ),
            isFalse,
            reason: '🔴 le marqueur déborde sur le segment $i',
          );
        }
        // Il vit AU-DESSUS de la barre, il ne la recouvre pas.
        expect(bounds.bottom, closeTo(rrects[3].outerRect.top, 0.01));
      },
    );

    testWidgets(
      'un `currentIndex` hors file laisse le marqueur sur la DERNIÈRE carte, '
      'là où le nœud annonce « 5/5 » (AD-10 — même source bornée)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          style: ZSessionProgressStyle.segmentedMarker,
          total: 5,
          currentIndex: 99,
          markerThickness: 8,
        );

        expect(tester.takeException(), isNull);
        final calls = _record(tester);
        final paths = _paths(calls);
        // 🔴 MORDANT : un `currentIndex` brut ne trouverait AUCUN segment à
        // marquer — le repère disparaîtrait sous une annonce « 5/5 ».
        expect(paths, hasLength(1));
        expect(
          paths.single.getBounds().center.dx,
          closeTo(_rrects(calls).last.outerRect.center.dx, 0.01),
        );
        expect(
          tester
              .getSemantics(find.byKey(ZSessionProgressIndicator.progressKey))
              .value,
          '5/5',
        );
        handle.dispose();
      },
    );

    testWidgets('une file VIDE ne peint rien et n\'explose pas (AD-10)', (
      tester,
    ) async {
      await _pump(
        tester,
        style: ZSessionProgressStyle.segmentedMarker,
        total: 0,
        currentIndex: 0,
      );

      expect(tester.takeException(), isNull);
      final calls = _record(tester);
      expect(_rrects(calls), isEmpty);
      expect(_paths(calls), isEmpty);
    });

    testWidgets(
      'une file si dense que les intervalles mangent la place ne peint rien — '
      'jamais un segment de largeur négative (AD-10)',
      (tester) async {
        // 400 dp de large, 200 cartes, intervalle 4 : 796 dp d'intervalles à
        // eux seuls.
        await _pump(
          tester,
          style: ZSessionProgressStyle.segmentedMarker,
          total: 200,
          width: 400,
          markerThickness: 8,
        );

        expect(tester.takeException(), isNull);
        expect(_rrects(_record(tester)), isEmpty);
      },
    );

    testWidgets(
      '`segmentedMarkerThickness` change l\'épaisseur PEINTE, et toute la '
      'géométrie en dérive',
      (tester) async {
        await _pump(
          tester,
          style: ZSessionProgressStyle.segmentedMarker,
          total: 5,
        );
        final byDefault = _rrects(_record(tester));
        // Défaut = `ZcrudTheme.gapS`.
        expect(byDefault.first.outerRect.height, 4.0);

        await _pump(
          tester,
          style: ZSessionProgressStyle.segmentedMarker,
          total: 5,
          markerThickness: 12,
        );
        final posed = _rrects(_record(tester));

        // 🔴 MORDANT : une épaisseur relayée mais jamais lue laisserait 4.
        expect(posed.first.outerRect.height, 12.0);
        expect(posed.first.tlRadius, const Radius.circular(6));
        expect(
          posed[1].outerRect.left - posed[0].outerRect.right,
          closeTo(6, 0.01),
        );
        expect(_paths(_record(tester)).single.getBounds().height, closeTo(12, 0.01));
      },
    );

    testWidgets(
      'bornes de l\'épaisseur (AD-10) : valeur absurde IGNORÉE, jamais une '
      'barre invisible',
      (tester) async {
        for (final thickness in <double>[-1, 0, double.nan, double.infinity]) {
          await _pump(
            tester,
            style: ZSessionProgressStyle.segmentedMarker,
            total: 5,
            markerThickness: thickness,
          );
          expect(tester.takeException(), isNull, reason: '$thickness a levé');
          expect(
            _rrects(_record(tester)).first.outerRect.height,
            4.0,
            reason: '$thickness n\'est pas retombée sur le token de thème',
          );
        }
      },
    );

    testWidgets(
      '🔴 les couleurs viennent du SEAM — segments ET marqueur, jamais un rôle '
      'en dur',
      (tester) async {
        const injected = ZColorPair(
          color: Color(0xFF123456),
          onColor: Color(0xFF654321),
        );
        await _pump(
          tester,
          style: ZSessionProgressStyle.segmentedMarker,
          total: 5,
          currentIndex: 1,
          markerThickness: 8,
          colorKeyResolver: (scheme, key) =>
              key == ZSessionProgressIndicator.pendingColorKey
                  ? injected
                  : null,
        );
        final calls = _record(tester);

        // 🔴 MORDANT : un `scheme.primary` en dur ne consulterait pas le
        // résolveur — aucune de ces couleurs ne serait la teinte injectée.
        expect(_rrectColors(calls), hasLength(5));
        expect(_rrectColors(calls), everyElement(injected.color.toARGB32()));
        final markerPaint = calls
            .where((c) => c.invocation.memberName == #drawPath)
            .map((c) => c.invocation.positionalArguments[1] as Paint)
            .single;
        expect(markerPaint.color.toARGB32(), injected.color.toARGB32());
        // Contre-preuve : la teinte observée n'est aucun rôle du thème.
        expect(
          injected.color.toARGB32(),
          isNot(
            Theme.of(
              tester.element(
                find.byKey(ZSessionProgressIndicator.segmentedMarkerKey),
              ),
            ).colorScheme.primary.toARGB32(),
          ),
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 4 — RTL
  // ══════════════════════════════════════════════════════════════════════════
  group('RTL — le sens de lecture vient du `Directionality` (AD-13)', () {
    testWidgets(
      '🔴 sous `Directionality(rtl)`, le PREMIER segment est à DROITE, et les '
      'rectangles peints sont le MIROIR STRICT de ceux de LTR',
      (tester) async {
        await _pump(
          tester,
          style: ZSessionProgressStyle.segmentedMarker,
          total: 5,
          currentIndex: 1,
          markerThickness: 8,
          textDirection: TextDirection.ltr,
        );
        final ltr = _rrects(_record(tester))
            .map((r) => r.outerRect)
            .toList(growable: false);
        final ltrMarker = _paths(_record(tester)).single.getBounds();
        final width = tester
            .getSize(find.byKey(ZSessionProgressIndicator.segmentedMarkerKey))
            .width;

        await _pump(
          tester,
          style: ZSessionProgressStyle.segmentedMarker,
          total: 5,
          currentIndex: 1,
          markerThickness: 8,
          textDirection: TextDirection.rtl,
        );
        final rtl = _rrects(_record(tester))
            .map((r) => r.outerRect)
            .toList(growable: false);
        final rtlMarker = _paths(_record(tester)).single.getBounds();

        expect(width, 800.0);
        expect(rtl, hasLength(ltr.length));
        // 🔴 MORDANT — un `TextDirection.ltr` codé en dur (le défaut du patron
        // qu'on remplace) rendrait `rtl` IDENTIQUE à `ltr` : chacune de ces
        // égalités miroir riposterait.
        for (var i = 0; i < ltr.length; i++) {
          expect(rtl[i].left, closeTo(width - ltr[i].right, 0.01), reason: '$i');
          expect(rtl[i].right, closeTo(width - ltr[i].left, 0.01), reason: '$i');
          expect(rtl[i].top, ltr[i].top, reason: '$i');
          expect(rtl[i].bottom, ltr[i].bottom, reason: '$i');
        }
        // Le marqueur suit la même carte, du bon côté.
        expect(rtlMarker.center.dx, closeTo(width - ltrMarker.center.dx, 0.01));
        // Contre-preuve : les deux directions ne sont pas confondues.
        expect(ltr.first.left, lessThan(ltr.last.left));
        expect(rtl.first.left, greaterThan(rtl.last.left));
      },
    );

    testWidgets(
      'les points suivent aussi le sens de lecture — `alignment: start` est '
      'directionnel',
      (tester) async {
        await _pump(
          tester,
          total: 5,
          width: 600,
          textDirection: TextDirection.rtl,
        );
        // 🔴 MORDANT : un `Wrap` aligné sur la gauche en dur mettrait le
        // premier point à gauche en RTL aussi.
        expect(_dotRect(tester, 0).right, 600.0);
        expect(_dotRect(tester, 0).left, greaterThan(_dotRect(tester, 4).left));
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 5 — parité sémantique et `shouldRepaint`
  // ══════════════════════════════════════════════════════════════════════════
  group('Parité sémantique des CINQ styles, et repeinte honnête', () {
    testWidgets(
      '🔴 le couple (label, value) du nœud de progression est IDENTIQUE pour '
      'les CINQ styles',
      (tester) async {
        final handle = tester.ensureSemantics();
        final announced = <ZSessionProgressStyle, List<String>>{};

        for (final style in ZSessionProgressStyle.values) {
          await _pump(tester, style: style, total: 5, currentIndex: 1);
          final node = tester.getSemantics(
            find.byKey(ZSessionProgressIndicator.progressKey),
          );
          announced[style] = <String>[node.label, node.value];
        }

        // La comparaison porte sur les QUATRE styles préexistants, pas sur une
        // chaîne écrite à la main : un style neuf muet, ou trop bavard, s'écarte
        // de tous les autres à la fois.
        expect(announced, hasLength(ZSessionProgressStyle.values.length));
        for (final style in ZSessionProgressStyle.values) {
          expect(
            announced[style],
            announced[ZSessionProgressStyle.dots],
            reason: '🔴 $style rompt la parité sémantique',
          );
        }
        // Contre-preuve : la valeur comparée n'est pas vide.
        expect(announced[ZSessionProgressStyle.segmentedMarker], <String>[
          '2/5',
          '2/5',
        ]);
        handle.dispose();
      },
    );

    testWidgets(
      '🔴 la progression n\'est annoncée QU\'UNE FOIS sous `segmentedMarker`',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          style: ZSessionProgressStyle.segmentedMarker,
          total: 5,
          currentIndex: 1,
        );

        // On mesure le TEXTE ANNONCÉ, pas le nombre de nœuds : un doublon
        // fusionné n'ajoute aucun nœud, il ALLONGE le libellé du nœud parent.
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

        expect(announced, <String>['2/5|2/5']);
        handle.dispose();
      },
    );

    testWidgets(
      '🔴 `shouldRepaint` est FAUX sur un peintre identique, VRAI dès qu\'un '
      'champ change',
      (tester) async {
        Future<CustomPainter> painterFor({
          int currentIndex = 1,
          double? thickness = 8,
          TextDirection direction = TextDirection.ltr,
          ZColorPair? Function(ColorScheme, String)? resolver,
        }) async {
          await _pump(
            tester,
            style: ZSessionProgressStyle.segmentedMarker,
            total: 5,
            currentIndex: currentIndex,
            markerThickness: thickness,
            textDirection: direction,
            colorKeyResolver: resolver,
          );
          return _painter(tester);
        }

        final reference = await painterFor();
        final identical = await painterFor();

        // 🔴 MORDANT : un `=> true` inconditionnel (le patron qu'on remplace)
        // riposterait ici, et seulement ici.
        expect(
          identical.shouldRepaint(reference),
          isFalse,
          reason: '🔴 le peintre se redéclare sale sans avoir changé',
        );

        // 🔴 MORDANT : un `=> false` laisserait la barre figée — chacune de ces
        // quatre lignes riposterait.
        expect((await painterFor(currentIndex: 2)).shouldRepaint(reference), isTrue);
        expect((await painterFor(thickness: 12)).shouldRepaint(reference), isTrue);
        expect(
          (await painterFor(direction: TextDirection.rtl))
              .shouldRepaint(reference),
          isTrue,
        );
        expect(
          (await painterFor(
            resolver: (scheme, key) => const ZColorPair(
              color: Color(0xFF123456),
              onColor: Color(0xFF654321),
            ),
          )).shouldRepaint(reference),
          isTrue,
          reason: '🔴 un changement de COULEUR ne déclenche pas la repeinte',
        );
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 6 — relais par la pile
  // ══════════════════════════════════════════════════════════════════════════
  group('La pile RELAIE les réglages jusqu\'à l\'indicateur', () {
    Future<void> pumpSwiper(
      WidgetTester tester, {
      ZSessionDotsGeometry? geometry,
      ZSessionProgressStyle style = ZSessionProgressStyle.dots,
      double? markerThickness,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZSessionCardSwiper(
              queue: const <ZSessionItem>[
                ZSessionItem(flashcardId: 'a', folderId: 'f'),
                ZSessionItem(flashcardId: 'b', folderId: 'f'),
                ZSessionItem(flashcardId: 'c', folderId: 'f'),
              ],
              passThreshold: 3,
              progressStyle: style,
              progressDotsGeometry: geometry,
              progressSegmentedMarkerThickness: markerThickness,
              cardBuilder: (context, item) => const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      '🔴 `progressDotsGeometry` atteint la GÉOMÉTRIE PEINTE des points',
      (tester) async {
        // La pile démarre sur la carte 0 : les points NON courants sont donc
        // les suivants — mesurer le point 0 mesurerait l'élongation, pas la
        // taille inactive.
        await pumpSwiper(tester);
        expect(_dotRect(tester, 1).size, const Size(8, 8));

        await pumpSwiper(
          tester,
          geometry: const ZSessionDotsGeometry(
            inactiveSize: Size(14, 10),
            gap: 12,
          ),
        );

        // 🔴 MORDANT : un paramètre ajouté à la pile mais jamais transmis à
        // l'indicateur laisserait 8×8 et un écart de 4.
        expect(_dotRect(tester, 1).size, const Size(14, 10));
        expect(_dotRect(tester, 2).left - _dotRect(tester, 1).right, 12.0);
        // Le point COURANT suit la même géométrie : 10 × 1,5 = 15.
        expect(_dotRect(tester, 0).size, const Size(15, 10));
      },
    );

    testWidgets(
      '🔴 `progressSegmentedMarkerThickness` atteint l\'épaisseur PEINTE',
      (tester) async {
        await pumpSwiper(
          tester,
          style: ZSessionProgressStyle.segmentedMarker,
          markerThickness: 12,
        );

        expect(_rrects(_record(tester)).first.outerRect.height, 12.0);
      },
    );

    testWidgets('sans réglage, la pile rend EXACTEMENT ce qu\'elle rendait', (
      tester,
    ) async {
      await pumpSwiper(tester);

      // 🔴 MORDANT : un défaut posé par la pile (au lieu de `null` relayé)
      // changerait le rendu de tout hôte passif.
      expect(_dotRect(tester, 1).size, const Size(8, 8));
      expect(_dotRect(tester, 0).size, const Size(12, 8));
      expect(_dotRect(tester, 2).left - _dotRect(tester, 1).right, 4.0);
      expect(_dotRect(tester, 1).width, isNot(14.0));
    });
  });
}
