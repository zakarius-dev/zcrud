/// **CR-IFFD-61 ④** — le compteur d'en-tête de section devient ADJACENT au
/// titre (`Row[titre, écart, compteur]`), sur demande du thème ; le défaut
/// (compteur renvoyé à l'extrémité de la ligne) reste strictement inchangé.
///
/// 🔴 **Ce que ces gardes mesurent, et les angles morts visés** :
///
/// * l'adjacence en **ÉCART MESURÉ** titre↔compteur (`getRect`), jamais en
///   « le compteur est dans l'arbre » — et **en position relative au chevron**
///   et aux actions : « adjacent au titre » et « collé au chevron » sont deux
///   rendus qu'un simple `findsOneWidget` confondrait ;
/// * la **non-écrasabilité du compteur** par un titre long : sa largeur est
///   comparée à sa largeur en titre court, à **320 dp**, dans les DEUX
///   placements et dans les DEUX directions (AD-13). Une garde qui ne
///   mesurerait que l'écart resterait verte si le badge était compressé ;
/// * l'**absence de débordement** (`RenderFlex overflowed`) — mesurée par
///   capture d'exception, pas déduite ;
/// * l'**interaction avec les livraisons de CR-IFFD-50** (`secondaryActionLabel`
///   visible + chevron `inHeaderRow`), montées ENSEMBLE : c'est la
///   configuration où l'espace manque réellement.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZStudySectionCollapsePlacement,
        ZStudySectionCountPlacement,
        ZcrudTheme;
import 'package:zcrud_study/zcrud_study.dart';

const String _kShort = 'Notes';
const String _kLong =
    'Notes de cours du second semestre sur la valeur en douane et ses ajustements';
const String _kSecondary = 'AFFICHER_TOUT';
const int _kCount = 6;

ZStudyToolsSectionSpec _spec({
  String title = _kShort,
  bool collapsible = false,
  String? secondaryActionLabel,
  VoidCallback? secondaryAction,
  VoidCallback? addAction,
}) =>
    ZStudyToolsSectionSpec(
      id: 'notes',
      title: title,
      itemCount: _kCount,
      itemBuilder: (context, i) => SizedBox(height: 20, child: Text('It$i')),
      emptyState: const Text('EMPTY'),
      collapsible: collapsible,
      secondaryAction: secondaryAction,
      secondaryActionLabel: secondaryActionLabel,
      addAction: addAction,
    );

Future<List<String>> _pump(
  WidgetTester tester,
  ZStudyToolsSectionSpec spec, {
  ZcrudTheme? theme,
  double width = 400,
  TextDirection dir = TextDirection.ltr,
}) async {
  final List<String> errors = <String>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails d) => errors.add(d.toString());
  try {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme == null
            ? null
            : ThemeData(extensions: <ThemeExtension<dynamic>>[theme]),
        home: Directionality(
          textDirection: dir,
          child: Scaffold(
            body: SizedBox(
              width: width,
              child: ZSectionedStudyLayout(
                sections: <ZStudyToolsSectionSpec>[spec],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previous;
  }
  for (var i = 0; i < 20; i++) {
    final Object? e = tester.takeException();
    if (e == null) break;
    errors.add(e.toString());
  }
  return errors;
}

/// Le `Container` du badge — l'ancêtre direct du texte du compteur.
Rect _badgeRect(WidgetTester tester) => tester.getRect(
      find
          .ancestor(
            of: find.text('$_kCount'),
            matching: find.byType(Container),
          )
          .first,
    );

Rect _titleRect(WidgetTester tester, String title) =>
    tester.getRect(find.text(title));

/// LARGEUR de la BOÎTE du titre.
///
/// 🔴 C'est le discriminant réel des deux placements : en `lineEnd` le titre
/// est `Expanded`, sa boîte occupe TOUTE la place restante (l'écart mesuré
/// jusqu'au badge vaut alors le seul `gapS`, ce qui rendrait une garde d'écart
/// AVEUGLE au placement) ; en `adjacentToTitle` il est `Flexible` et sa boîte
/// se réduit à la largeur du texte.
double _titleBoxWidth(WidgetTester tester, String title) =>
    _titleRect(tester, title).width;

/// Abscisse DROITE réellement PEINTE du dernier glyphe de [title].
double _glyphRight(WidgetTester tester, String title) {
  final RenderParagraph p =
      tester.renderObject<RenderParagraph>(find.text(title).first);
  final List<TextBox> boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: title.length),
  );
  expect(boxes, isNotEmpty, reason: 'aucune boîte de glyphe — mesure vacuelle');
  final Rect box = _titleRect(tester, title);
  return box.left + boxes.map((TextBox b) => b.right).reduce((a, b) => a > b ? a : b);
}

const ZcrudTheme _kAdjacent = ZcrudTheme(
  studySectionCountPlacement: ZStudySectionCountPlacement.adjacentToTitle,
);

void main() {
  group('CR-IFFD-61 ④ — placement du compteur', () {
    testWidgets('DÉFAUT (jeton nul) ⇒ le compteur est renvoyé à l\'EXTRÉMITÉ : '
        'le titre le POUSSE (rendu historique)', (tester) async {
      await _pump(tester, _spec());
      // 🔴 Mesure du PLACEMENT, pas de l'écart : le titre `Expanded` occupe
      // toute la place restante, donc l'espace vide se trouve DANS sa boîte,
      // entre le dernier glyphe et le badge.
      expect(
        _badgeRect(tester).left - _glyphRight(tester, _kShort),
        greaterThan(200),
        reason: 'le rendu historique doit rester : titre `Expanded`',
      );
      expect(
        _titleBoxWidth(tester, _kShort),
        greaterThan(200),
        reason: 'en `lineEnd` la boîte du titre prend toute la place',
      );
    });

    testWidgets('🔴 `adjacentToTitle` ⇒ le compteur SUIT le titre, à l\'écart '
        'exact du jeton (défaut `gapS`)', (tester) async {
      await _pump(tester, _spec(), theme: _kAdjacent);
      final BuildContext ctx = tester.element(find.text(_kShort));
      final double gapS = ZcrudTheme.of(ctx).gapS;
      expect(
        _badgeRect(tester).left - _glyphRight(tester, _kShort),
        closeTo(gapS, 0.5),
        reason: '🔴 le compteur n\'est pas ADJACENT au titre : mesuré depuis '
            'le dernier GLYPHE, pas depuis la boîte',
      );
      // …et la boîte du titre s\'est bien RÉDUITE au texte (le discriminant).
      expect(_titleBoxWidth(tester, _kShort), lessThan(100));
    });

    testWidgets('🔴 `studySectionCountGap` PRIME — l\'écart cesse de rider '
        '`gapS` (référence IFFD : 12)', (tester) async {
      await _pump(
        tester,
        _spec(),
        theme: const ZcrudTheme(
          gapS: 4,
          studySectionCountGap: 12,
          studySectionCountPlacement:
              ZStudySectionCountPlacement.adjacentToTitle,
        ),
      );
      final BuildContext ctx = tester.element(find.text(_kShort));
      // Non-vacuité : la valeur attendue DIFFÈRE de `gapS`.
      expect(ZcrudTheme.of(ctx).gapS, isNot(12));
      expect(
        _badgeRect(tester).left - _glyphRight(tester, _kShort),
        closeTo(12, 0.5),
      );
    });

    testWidgets('🔴 le jeton d\'écart s\'applique AUSSI au placement '
        'HISTORIQUE (un seul rôle, deux placements)', (tester) async {
      await _pump(tester, _spec(), theme: const ZcrudTheme(gapS: 4));
      final double avant =
          _badgeRect(tester).left - _titleRect(tester, _kShort).right;
      expect(avant, 4, reason: 'repli = `gapS`');
      await _pump(
        tester,
        _spec(),
        theme: const ZcrudTheme(gapS: 4, studySectionCountGap: 20),
      );
      expect(
        _badgeRect(tester).left - _titleRect(tester, _kShort).right,
        20,
        reason: '🔴 le jeton n\'est lu que sur le chemin adjacent',
      );
    });

    // ─────────────────────────────────────────── titre long, 320 dp, LTR/RTL ─
    for (final TextDirection dir in TextDirection.values) {
      final String nom = dir == TextDirection.ltr ? 'LTR' : 'RTL';

      testWidgets(
          '🔴 $nom / 320 dp / titre LONG — `adjacentToTitle` : le compteur '
          'garde sa TAILLE, le titre s\'ELLIPSE, aucun débordement',
          (tester) async {
        // Référence de taille : le même badge avec un titre COURT.
        await _pump(tester, _spec(), theme: _kAdjacent, width: 320, dir: dir);
        final Size reference = _badgeRect(tester).size;

        final List<String> errors = await _pump(
          tester,
          _spec(title: _kLong),
          theme: _kAdjacent,
          width: 320,
          dir: dir,
        );
        expect(
          errors.where((String e) => e.contains('overflowed')),
          isEmpty,
          reason: '🔴 débordement à 320 dp avec un titre long : $errors',
        );
        expect(
          _badgeRect(tester).size,
          reference,
          reason: '🔴 le compteur est ÉCRASÉ par le titre long — c\'est la '
              'réserve explicite de la CR',
        );
        // Le titre s'ellipse : il ne dépasse pas la ligne.
        final Text title = tester.widget<Text>(find.text(_kLong));
        final TextOverflow overflow = title.overflow ??
            DefaultTextStyle.of(tester.element(find.text(_kLong))).overflow;
        expect(overflow, TextOverflow.ellipsis);
        // Le compteur SUIT toujours le titre dans le sens de lecture.
        final Rect t = _titleRect(tester, _kLong);
        final Rect b = _badgeRect(tester);
        if (dir == TextDirection.ltr) {
          expect(b.left, greaterThanOrEqualTo(t.right));
        } else {
          expect(b.right, lessThanOrEqualTo(t.left));
        }
      });

      testWidgets(
          '🔴 $nom / 320 dp / titre LONG — placement HISTORIQUE : le compteur '
          'garde sa taille aussi (aucune régression)', (tester) async {
        await _pump(tester, _spec(), width: 320, dir: dir);
        final Size reference = _badgeRect(tester).size;
        final List<String> errors =
            await _pump(tester, _spec(title: _kLong), width: 320, dir: dir);
        expect(errors.where((String e) => e.contains('overflowed')), isEmpty);
        expect(_badgeRect(tester).size, reference);
      });
    }


    // ────────────────────────── interaction avec les livraisons CR-IFFD-50 ─
    //
    // 🔴 **PIÈGE DE GARDE mesuré ici, et évité** : `RenderFlex` ne signale un
    // débordement qu'UNE SEULE FOIS par objet de rendu (`_overflowReportNeeded`
    // n'est jamais réarmé). Comparer « adjacent » et « historique » par DEUX
    // `pumpWidget` dans le MÊME test rendait donc le second toujours à 0 — et
    // la garde concluait que l'adjacence AJOUTAIT un débordement. Mesuré en
    // tests SÉPARÉS : les deux placements débordent identiquement (1) à 320 dp
    // dans la configuration la plus dense, et aucun (0) à 500 dp. Chaque test
    // ci-dessous ne pompe donc QU'UNE fois la configuration dense.
    for (final TextDirection dir in TextDirection.values) {
      final String nom = dir == TextDirection.ltr ? 'LTR' : 'RTL';

      ZStudyToolsSectionSpec dense() => _spec(
            title: _kLong,
            collapsible: true,
            secondaryAction: () {},
            secondaryActionLabel: _kSecondary,
            addAction: () {},
          );

      const ZcrudTheme denseAdjacent = ZcrudTheme(
        studySectionCountPlacement: ZStudySectionCountPlacement.adjacentToTitle,
        studySectionCollapsePlacement:
            ZStudySectionCollapsePlacement.inHeaderRow,
      );
      const ZcrudTheme denseHistoric = ZcrudTheme(
        studySectionCollapsePlacement:
            ZStudySectionCollapsePlacement.inHeaderRow,
      );

      testWidgets(
          '🔴 $nom / 320 dp — RÉFÉRENCE : la configuration dense déborde DÉJÀ '
          'au placement HISTORIQUE (le débordement PRÉEXISTE)', (tester) async {
        final List<String> errors = await _pump(
          tester,
          dense(),
          theme: denseHistoric,
          width: 320,
          dir: dir,
        );
        expect(
          errors.where((String e) => e.contains('overflowed')).length,
          1,
          reason: 'contrôle de NON-VACUITÉ : si le placement historique cessait '
              'de déborder ici, la garde jumelle (adjacent) devrait exiger ZÉRO '
              'débordement au lieu de « pas plus qu\'avant »',
        );
      });

      testWidgets(
          '🔴 $nom / 320 dp — compteur ADJACENT + libellé secondaire VISIBLE + '
          'chevron `inHeaderRow` + ajout : PAS PLUS de débordement qu\'avant',
          (tester) async {
        final List<String> errors = await _pump(
          tester,
          dense(),
          theme: denseAdjacent,
          width: 320,
          dir: dir,
        );
        expect(
          errors.where((String e) => e.contains('overflowed')).length,
          lessThanOrEqualTo(1),
          reason: '🔴 l\'adjacence AJOUTE un débordement que le placement '
              'historique n\'avait pas : $errors',
        );
        // Le compteur reste ADJACENT au titre et RESTE en amont du libellé
        // secondaire dans le sens de lecture : il qualifie le TITRE, pas la
        // ligne d'actions (c'est la demande de la CR).
        final Rect badge = _badgeRect(tester);
        final Rect secondary = tester.getRect(find.text(_kSecondary));
        if (dir == TextDirection.ltr) {
          expect(badge.right, lessThanOrEqualTo(secondary.left));
        } else {
          expect(badge.left, greaterThanOrEqualTo(secondary.right));
        }
        // Les cibles tactiles gardent ≥ 48 dp (invariant CR-IFFD-50) — c'est
        // le titre qui rétrécit, jamais une cible.
        for (final Element e in <Element>[
          ...find.byType(IconButton).evaluate(),
          ...find.byType(TextButton).evaluate(),
        ]) {
          expect((e.renderObject! as RenderBox).size.height,
              greaterThanOrEqualTo(48));
        }
      });

      testWidgets(
          '🔴 $nom / 500 dp — la MÊME configuration dense : AUCUN débordement, '
          'compteur ADJACENT, compteur NON écrasé', (tester) async {
        final List<String> errors = await _pump(
          tester,
          dense(),
          theme: denseAdjacent,
          width: 500,
          dir: dir,
        );
        expect(
          errors.where((String e) => e.contains('overflowed')),
          isEmpty,
          reason: '🔴 débordement à 500 dp : $errors',
        );
        final double gapS =
            ZcrudTheme.of(tester.element(find.text(_kLong))).gapS;
        final Rect badge = _badgeRect(tester);
        final Rect titleBox = _titleRect(tester, _kLong);
        // 🔴 Le titre est ELLIPSÉ ici : sa BOÎTE se termine où le texte se
        // termine visuellement (l'ellipse `…` n'est PAS dans les boîtes de
        // glyphes de `getBoxesForSelection` — mesurer le dernier glyphe
        // donnerait un écart faussement plus grand de la largeur de l'ellipse).
        expect(
          dir == TextDirection.ltr
              ? badge.left - titleBox.right
              : titleBox.left - badge.right,
          closeTo(gapS, 0.5),
          reason: '🔴 le compteur n\'est plus adjacent au titre',
        );
        // Le compteur garde sa taille naturelle (référence : titre COURT).
        final Size crushed = badge.size;
        await _pump(tester, _spec(), theme: denseAdjacent, width: 500, dir: dir);
        expect(
          _badgeRect(tester).size,
          crushed,
          reason: '🔴 le compteur est ÉCRASÉ par le titre long',
        );
      });
    }
  });
}
