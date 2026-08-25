/// 🔴 CR-IFFD-112 — **coupure du résumé** d'un déclencheur de sélection
/// multiple : trois étiquettes, puis une ligne « +N … ».
///
/// Le défaut mesuré côté hôte : une matrice d'autorisations porte quinze
/// valeurs, le déclencheur les rend TOUTES, s'étire sur un demi-écran et pousse
/// les champs suivants hors de vue — pendant que le compte lui-même se perd
/// (« treize étiquettes » ne se lit pas, « +10 autres » se lit).
///
/// Ce que ces gardes tiennent, et qu'une garde de présence ne tiendrait pas :
///
/// * **SUM-R1** — la structure de référence rendue **sans aucun réglage** est
///   celle qui a été MESURÉE dans la source héritée (`Wrap` 6/6, trois
///   étiquettes, rembourrage 8/3, rayon 6, texte 12/w500, débordement 11 pt à
///   4 dp) ; seules les COULEURS viennent du thème.
/// * **SUM-R2** — la coupure est mesurée par le **COMPTE annoncé** (10), jamais
///   par la présence d'un texte : une ligne « +0 » ou « +13 » passerait un
///   `findsOneWidget`.
/// * **SUM-R3** — bornes : exactement trois valeurs ⇒ AUCUN débordement ; zéro
///   valeur ⇒ aucune étiquette ; un palier ABSURDE (0, négatif) ⇒ aucune
///   coupure et **aucune exception** (invariant AD-10).
/// * **SUM-R4** — les jetons de forme gouvernent RÉELLEMENT le rendu, avec
///   anti-vacuité contre les valeurs de référence.
/// * **SUM-R5** — 🔴 la coupure est **VISUELLE SEULEMENT** : l'annonce
///   accessible porte les treize valeurs (invariant AD-13).
/// * **SUM-R6** — le mot du débordement vient de la table l10n, jamais d'un
///   littéral (FR-26).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_select/zcrud_select.dart';

/// Treize valeurs — le cas signalé (une ligne de matrice d'autorisations).
const int _n = 13;

List<ZFieldChoice> _choices(int n) => <ZFieldChoice>[
      for (int i = 0; i < n; i++)
        ZFieldChoice(value: 'v$i', label: 'Filiere $i'),
    ];

Widget _host({
  required int selectedCount,
  int catalogue = _n,
  ZcrudTheme? theme,
  ZSelectTileSpec? spec,
  ZcrudLabels? labels,
}) =>
    MaterialApp(
      home: ZcrudScope(
        selectPresenter: ZSmartSelectPresenter(spec: spec),
        theme: theme,
        labels: labels,
        child: Scaffold(
          body: ZSelectFieldWidget(
            field: ZFieldSpec(
              name: 'f',
              type: EditionFieldType.select,
              label: 'Filieres',
              choices: _choices(catalogue),
            ),
            value: <Object?>[for (int i = 0; i < selectedCount; i++) 'v$i'],
            onChanged: (_) {},
            multiple: true,
          ),
        ),
      ),
    );

final Finder _trigger = find
    .descendant(of: find.byType(Card), matching: find.byType(ListTile))
    .first;

/// Le `Wrap` du résumé — présent seulement quand au moins une valeur est
/// sélectionnée.
final Finder _wrap = find.descendant(of: _trigger, matching: find.byType(Wrap));

/// Les étiquettes du résumé : les conteneurs peints DANS le `Wrap`.
final Finder _chips =
    find.descendant(of: _wrap, matching: find.byType(Container));

/// Le texte de débordement rendu, ou `null` s'il n'y en a aucun.
///
/// 🔴 Cherché par PRÉFIXE `+`, jamais par la chaîne complète attendue : une
/// garde qui interrogerait `find.text('+10 more')` serait verte pour « il
/// existe ce texte » et ne dirait rien du compte quand il dérive.
String? _overflowText(WidgetTester tester) {
  final Iterable<Text> textes = tester
      .widgetList<Text>(find.descendant(of: _trigger, matching: find.byType(Text)))
      .where((Text t) => (t.data ?? '').startsWith('+'));
  return textes.isEmpty ? null : textes.single.data;
}

/// Le compte réellement annoncé par la ligne de débordement.
int? _overflowCount(WidgetTester tester) {
  final String? texte = _overflowText(tester);
  if (texte == null) return null;
  final RegExpMatch? m = RegExp(r'^\+(\d+)\b').firstMatch(texte);
  expect(m, isNotNull, reason: '🔴 la ligne « $texte » ne porte AUCUN compte');
  return int.parse(m!.group(1)!);
}

void main() {
  group('🎯 SUM-R1 — structure de référence, SANS aucun réglage', () {
    testWidgets(
      '13 valeurs ⇒ Wrap 6/6, TROIS étiquettes 8/3 au rayon 6, texte 12/w500',
      (tester) async {
        await tester.pumpWidget(_host(selectedCount: _n));
        await tester.pumpAndSettle();

        final Wrap wrap = tester.widget<Wrap>(_wrap);
        // Littéraux MESURÉS dans la source héritée, pas les constantes qui les
        // produisent : une garde qui lirait `ZSelectTileReference.chipSpacing`
        // resterait verte si la constante dérivait.
        expect(wrap.spacing, 6.0);
        expect(wrap.runSpacing, 6.0);

        expect(_chips, findsNWidgets(3),
            reason: '🔴 sans coupure, treize étiquettes s\'empilent et '
                'poussent les champs suivants hors de vue');

        final Container chip = tester.widget<Container>(_chips.first);
        expect(
          chip.padding,
          const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3),
        );
        final BoxDecoration deco = chip.decoration! as BoxDecoration;
        expect(deco.borderRadius, BorderRadius.circular(6));

        final Text texte = tester.widget<Text>(
          find.descendant(of: _chips.first, matching: find.byType(Text)),
        );
        expect(texte.style?.fontSize, 12.0);
        expect(texte.style?.fontWeight, FontWeight.w500);

        // La ligne de débordement : 11 pt, à 4 dp sous la dernière rangée.
        final Text debordement = tester.widget<Text>(
          find.descendant(of: _trigger, matching: find.text(_overflowText(tester)!)),
        );
        expect(debordement.style?.fontSize, 11.0);
        final Padding pad = tester.widget<Padding>(find.ancestor(
          of: find.text(_overflowText(tester)!),
          matching: find.byType(Padding),
        ).first);
        expect(pad.padding, const EdgeInsetsDirectional.only(top: 4));
      },
    );

    testWidgets(
      '🔴 la coupure REND la hauteur : le déclencheur coupé est nettement plus '
      'court que le même déclencheur non coupé',
      (tester) async {
        // 🔴 Largeur de TÉLÉPHONE : c'est là que le défaut a été constaté.
        // Sur les 800 dp du viewport de test par défaut, treize étiquettes
        // tiennent en deux rangées et la garde serait presque muette.
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_host(selectedCount: _n));
        await tester.pumpAndSettle();
        final double coupe = tester.getSize(find.byType(Card).first).height;

        // Palier NON POSITIF ⇒ aucune coupure : le rendu d'AVANT ce lot.
        await tester.pumpWidget(_host(
          selectedCount: _n,
          theme: const ZcrudTheme(selectSummaryMaxChips: 0),
        ));
        await tester.pumpAndSettle();
        final double entier = tester.getSize(find.byType(Card).first).height;

        // MESURÉ : 136 dp coupé contre 261 dp entier, sur un écran de 844 dp
        // de haut — le seuil de 100 dp d'écart est délibérément plus bas que
        // l'écart réel, pour qu'un léger changement de typographie ne rende pas
        // la garde instable, tout en restant impossible à franchir si la
        // coupure cesse d'agir.
        expect(entier, greaterThan(coupe + 100),
            reason: '🔴 si la coupure ne change pas la hauteur, elle ne '
                'corrige PAS le défaut signalé (une tuile qui s\'étire sur un '
                'demi-écran) — coupe=$coupe, entier=$entier');
      },
    );

    testWidgets('les COULEURS restent des rôles du thème (FR-26)',
        (tester) async {
      Future<Color?> fond(Color graine) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: graine)),
          home: ZcrudScope(
            selectPresenter: const ZSmartSelectPresenter(),
            child: Scaffold(
              body: ZSelectFieldWidget(
                field: ZFieldSpec(
                  name: 'f',
                  type: EditionFieldType.select,
                  label: 'Filieres',
                  choices: _choices(_n),
                ),
                value: const <Object?>['v0'],
                onChanged: (_) {},
                multiple: true,
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        return (tester.widget<Container>(_chips.first).decoration!
                as BoxDecoration)
            .color;
      }

      final Color? bleu = await fond(const Color(0xFF0000FF));
      final Color? rouge = await fond(const Color(0xFFFF0000));
      // Anti-vacuité : un littéral ne SUIVRAIT pas le changement de schéma.
      expect(bleu, isNot(rouge));
    });
  });

  group('🎯 SUM-R2 — le COMPTE annoncé, pas la présence d\'un texte', () {
    testWidgets('13 valeurs, palier 3 ⇒ 3 étiquettes et un débordement de 10',
        (tester) async {
      await tester.pumpWidget(_host(selectedCount: _n));
      await tester.pumpAndSettle();
      expect(_chips, findsNWidgets(3));
      expect(_overflowCount(tester), 10,
          reason: '🔴 « +0 » ou « +13 » passeraient un simple `findsOneWidget`');
    });

    testWidgets('un palier EXPLICITE gouverne le compte (spec > jeton)',
        (tester) async {
      await tester.pumpWidget(_host(
        selectedCount: _n,
        theme: const ZcrudTheme(selectSummaryMaxChips: 2),
        spec: const ZSelectTileSpec(summaryMaxChips: 5),
      ));
      await tester.pumpAndSettle();
      expect(_chips, findsNWidgets(5),
          reason: '🔴 le PARAMÈTRE doit l\'emporter sur le jeton');
      expect(_overflowCount(tester), 8);

      // …et sans paramètre, c'est le jeton qui décide (anti-vacuité du test
      // précédent : sinon il serait vert même si le jeton était ignoré partout).
      await tester.pumpWidget(_host(
        selectedCount: _n,
        theme: const ZcrudTheme(selectSummaryMaxChips: 2),
      ));
      await tester.pumpAndSettle();
      expect(_chips, findsNWidgets(2));
      expect(_overflowCount(tester), 11);
    });
  });

  group('🎯 SUM-R3 — bornes et valeurs absurdes (AD-10)', () {
    testWidgets('EXACTEMENT 3 valeurs ⇒ aucun débordement', (tester) async {
      await tester.pumpWidget(_host(selectedCount: 3));
      await tester.pumpAndSettle();
      expect(_chips, findsNWidgets(3));
      expect(_overflowText(tester), isNull,
          reason: '🔴 « +0 autres » sur une liste complète est un mensonge');
    });

    testWidgets('4 valeurs ⇒ 3 étiquettes et un débordement de 1',
        (tester) async {
      await tester.pumpWidget(_host(selectedCount: 4));
      await tester.pumpAndSettle();
      expect(_chips, findsNWidgets(3));
      expect(_overflowCount(tester), 1);
    });

    testWidgets('0 valeur ⇒ AUCUNE étiquette, aucun débordement',
        (tester) async {
      await tester.pumpWidget(_host(selectedCount: 0));
      await tester.pumpAndSettle();
      expect(_wrap, findsNothing);
      expect(_chips, findsNothing);
      expect(_overflowText(tester), isNull);
    });

    for (final int absurde in <int>[0, -1, -999]) {
      testWidgets('palier $absurde ⇒ aucune coupure, aucune exception',
          (tester) async {
        await tester.pumpWidget(_host(
          selectedCount: _n,
          theme: ZcrudTheme(selectSummaryMaxChips: absurde),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '🔴 un palier absurde ne doit JAMAIS lever (AD-10)');
        expect(_chips, findsNWidgets(_n));
        expect(_overflowText(tester), isNull);
      });
    }

    testWidgets('un palier absurde en PARAMÈTRE se comporte à l\'identique',
        (tester) async {
      await tester.pumpWidget(_host(
        selectedCount: _n,
        spec: const ZSelectTileSpec(summaryMaxChips: -3),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_chips, findsNWidgets(_n));
    });

    testWidgets(
      '🔴 les MÉTRIQUES normalisent le palier absurde en `null`, pas seulement '
      'le rendu',
      (tester) async {
        // Garde du maillon lui-même : `zSelectTileMetricsOf` est PUBLIC. Une
        // garde qui ne mesurerait que l'arbre resterait verte si la
        // normalisation migrait dans le widget — et un hôte qui lit
        // `summaryMaxChips` pour dimensionner autre chose recevrait `0`.
        late ZSelectTileMetrics absurde;
        late ZSelectTileMetrics parDefaut;
        await tester.pumpWidget(MaterialApp(
          home: ZcrudScope(
            theme: const ZcrudTheme(selectSummaryMaxChips: -7),
            child: Builder(builder: (ctx) {
              absurde = zSelectTileMetricsOf(ctx);
              return const SizedBox.shrink();
            }),
          ),
        ));
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (ctx) {
            parDefaut = zSelectTileMetricsOf(ctx);
            return const SizedBox.shrink();
          }),
        ));
        expect(absurde.summaryMaxChips, isNull);
        expect(absurde.summaryMaxChips, isNot(-7));
        // Anti-vacuité : sans jeton, les métriques portent BIEN un palier.
        expect(parDefaut.summaryMaxChips, 3);
      },
    );
  });

  group('🎯 SUM-R4 — les jetons de FORME gouvernent le rendu', () {
    testWidgets('rayon, rembourrage et taille de texte suivent les jetons',
        (tester) async {
      await tester.pumpWidget(_host(
        selectedCount: 2,
        theme: const ZcrudTheme(
          selectSummaryChipRadius: 20,
          selectSummaryChipPadding:
              EdgeInsetsDirectional.symmetric(horizontal: 17, vertical: 11),
          selectSummaryChipFontSize: 19,
        ),
      ));
      await tester.pumpAndSettle();

      final Container chip = tester.widget<Container>(_chips.first);
      expect(
        chip.padding,
        const EdgeInsetsDirectional.symmetric(horizontal: 17, vertical: 11),
      );
      expect(
        (chip.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(20),
      );
      final Text texte = tester.widget<Text>(
        find.descendant(of: _chips.first, matching: find.byType(Text)),
      );
      expect(texte.style?.fontSize, 19.0);

      // Anti-vacuité : aucune des trois valeurs n'est celle de la référence.
      expect(20.0, isNot(ZSelectTileReference.summaryChipRadius));
      expect(19.0, isNot(ZSelectTileReference.chipFontSize));
      expect(17.0, isNot(ZSelectTileReference.summaryChipPaddingHorizontal));
    });
  });

  group('🎯 SUM-R5 — 🔴 la coupure est VISUELLE SEULEMENT (AD-13)', () {
    testWidgets(
      'treize valeurs coupées à trois ⇒ l\'annonce en porte TREIZE',
      (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(_host(selectedCount: _n));
        await tester.pumpAndSettle();

        // Prérequis : la coupure est bien active à l'écran.
        expect(_chips, findsNWidgets(3));

        final String annonce =
            tester.getSemantics(find.bySemanticsLabel('Filieres')).value;
        for (int i = 0; i < _n; i++) {
          expect(
            annonce,
            contains('Filiere $i'),
            reason: '🔴 « Filiere $i » a disparu de l\'annonce : un lecteur '
                'd\'écran perdrait une information que la tuile POSSÈDE — la '
                'coupure est une accommodation de mise en page, et une annonce '
                'audio ne consomme aucune hauteur.',
          );
        }
        // La ligne « +10 … » n'est PAS un substitut : elle vit sous
        // `excludeSemantics` et n'est jamais annoncée.
        expect(annonce, isNot(contains('+10')));
        handle.dispose();
      },
    );
  });

  group('🎯 SUM-R6 — le mot du débordement vient de l10n (FR-26)', () {
    testWidgets('une surcharge `ZcrudScope.labels` REMPLACE le fragment',
        (tester) async {
      await tester.pumpWidget(_host(selectedCount: _n));
      await tester.pumpAndSettle();
      final String parDefaut = _overflowText(tester)!;

      await tester.pumpWidget(_host(
        selectedCount: _n,
        labels: ZcrudLabels(<String, String>{
          'selectSummaryOverflow': 'ZZZ',
        }),
      ));
      await tester.pumpAndSettle();

      expect(_overflowText(tester), '+10 ZZZ');
      // 🔴 Anti-vacuité : le texte par défaut n'était PAS déjà « +10 ZZZ », et
      // il a réellement changé — un littéral codé en dur ne bougerait pas.
      expect(parDefaut, isNot('+10 ZZZ'));
      expect(_overflowCount(tester), 10);
    });
  });
}
