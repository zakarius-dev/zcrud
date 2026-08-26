/// 🎯 Gardes PORTEUSES de la **réaction de la bordure à l'état** du
/// déclencheur de sélection.
///
/// **Ce qui est défendu** : un déclencheur qui porte une valeur se teinte et
/// s'épaissit — en consommant la teinte par type de champ déjà servie par le
/// résolveur de dégradé du scope, jamais une couleur inventée. Un déclencheur
/// vide garde le rendu de repos.
///
/// 🔴 **La garantie centrale, mesurée ici** : une application **sans résolveur
/// de teinte** obtient EXACTEMENT le rendu antérieur, dans les deux états —
/// couleur *et* épaisseur. En particulier l'épaisseur ne bouge jamais seule :
/// sans couleur pour l'accompagner, ce serait un changement de rendu que
/// personne n'a demandé et que rien ne rend lisible.
///
/// 🔴 **Anti-vacuité** : chaque garde mesure le `BorderSide` RÉELLEMENT monté
/// sur le `Card` (couleur et épaisseur), jamais la présence d'un widget ; et
/// l'étalon affirme d'abord que le rendu de repos n'est PAS celui de l'état
/// renseigné, sans quoi les deux passeraient l'une pour l'autre.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_select/zcrud_select.dart';

const List<ZFieldChoice> _abc = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'Alpha'),
  ZFieldChoice(value: 'b', label: 'Bravo'),
];

/// Teinte servie par le résolveur : **déjà lisible** sur la surface de champ
/// du thème clair, pour que la normalisation de contraste du cœur soit
/// l'identité et que l'attendu de la garde reste un LITTÉRAL (cf. `_bleuEstDejaLisible`).
const Color _bleu = Color(0xFF1A237E);

/// Opacité attendue de la bordure teintée — littéral du test, JAMAIS
/// `ZSelectTileReference.selectedBorderTintAlpha` (le code sous test).
const double _alphaAttendu = 80 / 255;

/// Épaisseur attendue de la bordure teintée — littéral du test.
const double _epaisseurAttendue = 1.5;

/// Épaisseur attendue au repos — littéral du test.
const double _epaisseurRepos = 1.0;

ZGradientSpec? _bleuResolver(ColorScheme scheme, String key) =>
    key == zFieldTypeTintKey(EditionFieldType.select)
        ? const ZGradientSpec(
            gradient: LinearGradient(colors: <Color>[_bleu, _bleu]),
            onGradient: Color(0xFFFFFFFF),
          )
        : null;

ZFieldSpec _spec({bool readOnly = false, bool leading = false}) => ZFieldSpec(
      name: 'f',
      type: EditionFieldType.select,
      label: 'Mon champ',
      choices: _abc,
      leading: leading ? const ZFieldAdornment.icon('date') : null,
      readOnly: readOnly,
    );

Widget _host({
  required Widget child,
  ZGradientResolver? resolver,
  ZcrudTheme? theme,
  ZSelectTileSpec? spec,
}) =>
    MaterialApp(
      theme: ThemeData.light(),
      home: ZcrudScope(
        selectPresenter: ZSmartSelectPresenter(spec: spec),
        gradientResolver: resolver,
        theme: theme,
        child: Scaffold(body: child),
      ),
    );

Widget _field({
  Object? value,
  bool multiple = false,
  bool readOnly = false,
  bool leading = false,
}) =>
    ZSelectFieldWidget(
      field: _spec(readOnly: readOnly, leading: leading),
      value: value,
      multiple: multiple,
      onChanged: (_) {},
    );

/// Le `BorderSide` RÉELLEMENT peint par le déclencheur.
BorderSide _side(WidgetTester tester) {
  final Card card = tester.widget<Card>(find.byType(Card).first);
  final ShapeBorder shape = card.shape!;
  expect(shape, isA<RoundedRectangleBorder>());
  return (shape as RoundedRectangleBorder).side;
}

/// La décoration de la **pastille** d'ornement de tête, ou `null` s'il n'y en
/// a pas (l'ornement est alors l'icône nue).
BoxDecoration? _pastille(WidgetTester tester) {
  final ListTile tile = tester.widget<ListTile>(
    find.descendant(of: find.byType(Card), matching: find.byType(ListTile)).first,
  );
  final Widget? head = (tile.leading! as UnconstrainedBox).child;
  if (head is! Center) return null;
  return (head.child! as DecoratedBox).decoration as BoxDecoration;
}

/// Rôle de bordure de repos du thème employé par `_host`.
Color get _outlineVariant => ThemeData.light().colorScheme.outlineVariant;

void main() {
  test(
    'PRÉMISSE — la teinte servie est déjà lisible sur la surface de champ : '
    'la normalisation du cœur est l\'identité, l\'attendu reste un littéral',
    () {
      final Color surface =
          ThemeData.light().colorScheme.surfaceContainerHighest;
      expect(
        zReadableTintOn(_bleu, surface: surface),
        _bleu,
        reason: '🔴 la teinte choisie est corrigée par la normalisation : les '
            'attendus littéraux des gardes ci-dessous ne décrivent plus le '
            'rendu — choisir une autre teinte.',
      );
      expect(
        zContrastRatio(_bleu, surface),
        greaterThanOrEqualTo(kZNonTextMinContrast),
      );
    },
  );

  group('🎯 INERTIE — aucun résolveur de teinte : rendu antérieur, aux 2 états',
      () {
    testWidgets(
      'mono : renseigné et vide peignent LE MÊME `BorderSide` — rôle '
      '`outlineVariant`, épaisseur 1',
      (tester) async {
        await tester.pumpWidget(_host(child: _field(value: 'a')));
        await tester.pumpAndSettle();
        final BorderSide rempli = _side(tester);

        await tester.pumpWidget(_host(child: _field()));
        await tester.pumpAndSettle();
        final BorderSide vide = _side(tester);

        expect(rempli.color, _outlineVariant,
            reason: '🔴 une teinte est peinte SANS résolveur — couleur '
                'inventée par le socle (FR-26).');
        expect(rempli.width, _epaisseurRepos,
            reason: '🔴 l\'épaisseur a bougé SEULE : une application sans '
                'résolveur voit son rendu changer sans raison lisible.');
        expect(vide.color, _outlineVariant);
        expect(vide.width, _epaisseurRepos);
        expect(rempli.color, vide.color);
        expect(rempli.width, vide.width);
      },
    );

    testWidgets(
      'multiple : idem — l\'état se calcule sur une LISTE, et l\'inertie vaut '
      'aussi là',
      (tester) async {
        await tester.pumpWidget(
          _host(child: _field(value: const <Object?>['a'], multiple: true)),
        );
        await tester.pumpAndSettle();
        final BorderSide rempli = _side(tester);

        await tester.pumpWidget(
          _host(child: _field(value: const <Object?>[], multiple: true)),
        );
        await tester.pumpAndSettle();
        final BorderSide vide = _side(tester);

        expect(rempli.color, _outlineVariant);
        expect(rempli.width, _epaisseurRepos);
        expect(vide.color, _outlineVariant);
        expect(vide.width, _epaisseurRepos);
      },
    );

    testWidgets(
      'lecture seule AVEC valeur : la tuile survit et reste au rendu de repos',
      (tester) async {
        await tester
            .pumpWidget(_host(child: _field(value: 'a', readOnly: true)));
        await tester.pumpAndSettle();
        expect(find.byType(ListTile), findsOneWidget,
            reason: 'parité : lecture seule AVEC valeur ⇒ tuile rendue');
        expect(_side(tester).color, _outlineVariant);
        expect(_side(tester).width, _epaisseurRepos);
      },
    );
  });

  group('🎯 EFFET — résolveur de teinte servi : la bordure réagit à l\'état',
      () {
    testWidgets(
      'mono renseigné : bordure à la TEINTE DU CHAMP atténuée, épaisseur 1,5 ; '
      'mono vide : rendu de repos intact',
      (tester) async {
        await tester.pumpWidget(
          _host(child: _field(value: 'a'), resolver: _bleuResolver),
        );
        await tester.pumpAndSettle();
        final BorderSide rempli = _side(tester);
        expect(rempli.color, _bleu.withValues(alpha: _alphaAttendu),
            reason: '🔴 la bordure ne consomme pas la teinte du champ.');
        expect(rempli.color.a, closeTo(_alphaAttendu, 1e-6),
            reason: '🔴 teinte à PLEINE saturation : un trait dur autour de '
                'chaque champ rempli.');
        expect(rempli.width, _epaisseurAttendue);

        await tester.pumpWidget(
          _host(child: _field(), resolver: _bleuResolver),
        );
        await tester.pumpAndSettle();
        final BorderSide vide = _side(tester);
        expect(vide.color, _outlineVariant,
            reason: '🔴 un champ VIDE se teinte : l\'état n\'est plus lisible.');
        expect(vide.width, _epaisseurRepos);

        // 🔴 Anti-vacuité : les deux états DIFFÈRENT bien, sur les DEUX canaux
        // (jamais la couleur seule — AD-13).
        expect(rempli.color, isNot(vide.color));
        expect(rempli.width, isNot(vide.width));
      },
    );

    testWidgets(
      'multiple : liste NON VIDE ⇒ teinté ; liste VIDE ⇒ repos',
      (tester) async {
        await tester.pumpWidget(_host(
          child: _field(value: const <Object?>['a', 'b'], multiple: true),
          resolver: _bleuResolver,
        ));
        await tester.pumpAndSettle();
        expect(_side(tester).color, _bleu.withValues(alpha: _alphaAttendu));
        expect(_side(tester).width, _epaisseurAttendue);

        await tester.pumpWidget(_host(
          child: _field(value: const <Object?>[], multiple: true),
          resolver: _bleuResolver,
        ));
        await tester.pumpAndSettle();
        expect(_side(tester).color, _outlineVariant);
        expect(_side(tester).width, _epaisseurRepos);
      },
    );

    testWidgets(
      'lecture seule AVEC valeur : la tuile porte une valeur, donc elle se '
      'teinte — l\'état prime sur l\'éditabilité',
      (tester) async {
        await tester.pumpWidget(_host(
          child: _field(value: 'a', readOnly: true),
          resolver: _bleuResolver,
        ));
        await tester.pumpAndSettle();
        expect(_side(tester).color, _bleu.withValues(alpha: _alphaAttendu));
        expect(_side(tester).width, _epaisseurAttendue);
      },
    );

    testWidgets(
      'clé NON SERVIE par le résolveur : inertie complète — la teinte d\'un '
      'AUTRE type de champ ne déteint pas sur la sélection',
      (tester) async {
        await tester.pumpWidget(_host(
          child: _field(value: 'a'),
          resolver: (ColorScheme scheme, String key) =>
              key == zFieldTypeTintKey(EditionFieldType.text)
                  ? const ZGradientSpec(
                      gradient: LinearGradient(colors: <Color>[_bleu, _bleu]),
                      onGradient: Color(0xFFFFFFFF),
                    )
                  : null,
        ));
        await tester.pumpAndSettle();
        expect(_side(tester).color, _outlineVariant);
        expect(_side(tester).width, _epaisseurRepos);
      },
    );
  });

  group('🎯 ÉCHAPPATOIRE — retrouver le rendu STATIQUE, résolveur présent', () {
    testWidgets(
      'jetons d\'état posés aux valeurs de repos ⇒ la bordure cesse de réagir',
      (tester) async {
        const Color pose = Color(0xFF445566);
        const ZcrudTheme statique = ZcrudTheme(
          selectTileBorderColor: pose,
          selectTileBorderWidth: _epaisseurRepos,
          selectTileSelectedBorderColor: pose,
          selectTileSelectedBorderWidth: _epaisseurRepos,
        );
        await tester.pumpWidget(_host(
          child: _field(value: 'a'),
          resolver: _bleuResolver,
          theme: statique,
        ));
        await tester.pumpAndSettle();
        final BorderSide rempli = _side(tester);

        await tester.pumpWidget(_host(
          child: _field(),
          resolver: _bleuResolver,
          theme: statique,
        ));
        await tester.pumpAndSettle();
        final BorderSide vide = _side(tester);

        expect(rempli.color, pose,
            reason: '🔴 le jeton d\'état est ignoré : la teinte passe outre, '
                'et l\'échappatoire n\'existe pas.');
        expect(rempli.width, _epaisseurRepos);
        expect(vide.color, pose);
        expect(vide.width, _epaisseurRepos);
        // Anti-vacuité : sans les jetons, CE MÊME arbre réagirait.
        expect(pose, isNot(_bleu.withValues(alpha: _alphaAttendu)));
      },
    );

    testWidgets(
      'le PARAMÈTRE prime sur le jeton ET sur la teinte (chaîne complète)',
      (tester) async {
        const Color parametre = Color(0xFFCC00CC);
        await tester.pumpWidget(_host(
          child: _field(value: 'a'),
          resolver: _bleuResolver,
          theme: const ZcrudTheme(
            selectTileSelectedBorderColor: Color(0xFF00CC00),
            selectTileSelectedBorderWidth: 4,
          ),
          spec: const ZSelectTileSpec(
            selectedBorderColor: parametre,
            selectedBorderWidth: 3,
          ),
        ));
        await tester.pumpAndSettle();
        expect(_side(tester).color, parametre);
        expect(_side(tester).width, 3);
      },
    );

    testWidgets(
      'le JETON prime sur la teinte servie (2e maillon de la chaîne)',
      (tester) async {
        const Color jeton = Color(0xFF00CC00);
        await tester.pumpWidget(_host(
          child: _field(value: 'a'),
          resolver: _bleuResolver,
          theme: const ZcrudTheme(
            selectTileSelectedBorderColor: jeton,
            selectTileSelectedBorderWidth: 4,
          ),
        ));
        await tester.pumpAndSettle();
        expect(_side(tester).color, jeton);
        expect(_side(tester).width, 4);
      },
    );
  });

  group('🎯 PASTILLE — l\'ornement de tête suit le même état que la bordure',
      () {
    // Jetons de pastille de l'application : la pastille n'existe QUE parce
    // qu'ils sont posés (opt-in du cœur, inchangé par ce lot).
    const ZcrudTheme pastille = ZcrudTheme(
      adornmentIconBackgroundAlpha: 0.12,
      adornmentIconBackgroundRadius: Radius.circular(8),
      adornmentIconSize: 18,
    );

    testWidgets(
      'INERTIE : jetons de pastille posés mais AUCUN résolveur ⇒ pas de '
      'pastille du tout, dans les deux états',
      (tester) async {
        for (final Object? valeur in <Object?>['a', null]) {
          await tester.pumpWidget(_host(
            child: _field(value: valeur, leading: true),
            theme: pastille,
          ));
          await tester.pumpAndSettle();
          expect(_pastille(tester), isNull,
              reason: '🔴 une pastille est peinte SANS teinte servie : sa '
                  'couleur serait inventée (FR-26). valeur=$valeur');
        }
      },
    );

    testWidgets(
      'EFFET : renseigné ⇒ pastille à l\'opacité du jeton ; vide ⇒ pastille '
      'ESTOMPÉE (même teinte, même géométrie)',
      (tester) async {
        await tester.pumpWidget(_host(
          child: _field(value: 'a', leading: true),
          resolver: _bleuResolver,
          theme: pastille,
        ));
        await tester.pumpAndSettle();
        final BoxDecoration rempli = _pastille(tester)!;

        await tester.pumpWidget(_host(
          child: _field(leading: true),
          resolver: _bleuResolver,
          theme: pastille,
        ));
        await tester.pumpAndSettle();
        final BoxDecoration vide = _pastille(tester)!;

        expect(rempli.color!.a, closeTo(0.12, 1e-6),
            reason: '🔴 l\'état renseigné n\'est plus à l\'opacité que '
                'l\'application a posée.');
        // 0,12 × 0,375 — littéraux du test, PAS la constante de référence.
        expect(vide.color!.a, closeTo(0.12 * 0.375, 1e-6),
            reason: '🔴 la pastille de l\'état vide n\'est pas estompée : elle '
                'ne dit plus rien de l\'état.');
        // 🔴 Anti-vacuité : les deux états DIFFÈRENT réellement.
        expect(rempli.color!.a, isNot(closeTo(vide.color!.a, 1e-6)));
        // Seule l\'opacité change : la teinte et la géométrie sont les mêmes.
        expect(vide.color!.r, closeTo(rempli.color!.r, 1e-6));
        expect(vide.color!.g, closeTo(rempli.color!.g, 1e-6));
        expect(vide.color!.b, closeTo(rempli.color!.b, 1e-6));
        expect(vide.borderRadius, rempli.borderRadius);
      },
    );

    testWidgets(
      'ÉCHAPPATOIRE : jeton d\'état posé à l\'opacité de la pastille ⇒ '
      'pastille insensible à l\'état',
      (tester) async {
        const ZcrudTheme statique = ZcrudTheme(
          adornmentIconBackgroundAlpha: 0.12,
          adornmentIconBackgroundRadius: Radius.circular(8),
          adornmentIconSize: 18,
          selectTileEmptyAdornmentAlpha: 0.12,
        );
        await tester.pumpWidget(_host(
          child: _field(value: 'a', leading: true),
          resolver: _bleuResolver,
          theme: statique,
        ));
        await tester.pumpAndSettle();
        final BoxDecoration rempli = _pastille(tester)!;
        await tester.pumpWidget(_host(
          child: _field(leading: true),
          resolver: _bleuResolver,
          theme: statique,
        ));
        await tester.pumpAndSettle();
        expect(_pastille(tester)!.color, rempli.color);
      },
    );

    testWidgets(
      'le PARAMÈTRE prime sur le jeton pour l\'opacité de l\'état vide',
      (tester) async {
        await tester.pumpWidget(_host(
          child: _field(leading: true),
          resolver: _bleuResolver,
          theme: const ZcrudTheme(
            adornmentIconBackgroundAlpha: 0.12,
            adornmentIconBackgroundRadius: Radius.circular(8),
            adornmentIconSize: 18,
            selectTileEmptyAdornmentAlpha: 0.02,
          ),
          spec: const ZSelectTileSpec(emptyAdornmentAlpha: 0.3),
        ));
        await tester.pumpAndSettle();
        expect(_pastille(tester)!.color!.a, closeTo(0.3, 1e-6));
      },
    );
  });
}
