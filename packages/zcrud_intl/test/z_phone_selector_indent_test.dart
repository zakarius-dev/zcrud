// CR-DODLP-PHONE-INDENT (2026-08-10) — le contenu « drapeau + indicatif » du
// champ `phoneNumber` doit démarrer au MÊME retrait de tête que le contenu des
// champs voisins, dans le MÊME thème.
//
// 🔴 CAUSE VÉRIFIÉE SUR LE RENDU, pas recopiée de la CR. Le bouton sélecteur du
// paquet tiers occupe le slot `prefixIcon` (`copyWith(prefixIcon: SelectorButton
// (…))`), et `InputDecorator` **substitue** la largeur du `prefixIcon` au retrait
// de tête du contenu (`input_decorator.dart` : `prefixIcon == null ?
// contentPadding.start + inputGap : prefixIconSize.width + …`). Le retrait du
// thème est donc perdu côté tête.
//
// 🔴 MAIS LA MESURE CORRIGE LE CHIFFRE DE LA CR. Sonde (supprimée) sur un
// formulaire de deux champs (`inputContentPadding.start` = 16, bordure
// `OutlineInputBorder`), page 800 dp, carte à x = 12 :
//
//   | rendu                     | AVANT | APRÈS |
//   |---------------------------|-------|-------|
//   | contenu du champ `text`   | 32.0  | 32.0  |
//   | drapeau du `phoneNumber`  | 12.0  | 32.0  |
//
// Le drapeau était donc au **ras exact** du bord de la carte (12.0 = bord), et
// l'écart valait **20 dp**, pas 16 : le retrait réel des voisins vaut
// `contentPadding.start` (16) **+** l'`inputGap` du SDK (le `gapPadding` de la
// bordure, 4). Corriger de 16 aurait laissé 4 dp d'écart — c'est pourquoi les
// gardes ci-dessous confrontent DEUX RENDUS RÉELS et ne comparent jamais à une
// constante de style.
//
// 🔴 RÉSIDU RTL MESURÉ, ASSUMÉ, NON CORRIGÉ : en RTL le tiers ajoute lui-même
// 8 dp de tête via un `Padding(EdgeInsets.only(right: 8.0))` **non directionnel**
// posé dans `SelectorButton` (chemin DIALOG). Mesuré : résidu (drapeau − voisin)
// = 8.0 dp sous `start` = 16 **et** sous `start` = 28. Il est donc **constant et
// indépendant de notre jeton** — hors de portée de `zcrud_intl` (le tiers écrase
// tout `prefixIcon` injecté, on ne peut pas l'envelopper). La garde RTL affirme
// exactement cela : notre retrait suit le jeton du côté TÊTE (AD-13), le résidu
// du tiers ne bouge pas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

/// Drapeau du Togo rendu par le sélecteur (emoji, `useEmoji: true`).
const String _flagTg = '\u{1F1F9}\u{1F1EC}';

/// Thème dont le retrait interne DIFFÈRE du défaut — sert à prouver que le
/// retrait du drapeau **suit le jeton** et n'est pas une constante.
const ZcrudTheme _widePadding = ZcrudTheme(
  inputContentPadding: EdgeInsetsDirectional.fromSTEB(28, 16, 8, 16),
);

Future<void> _pump(
  WidgetTester tester, {
  TextDirection direction = TextDirection.ltr,
  ZcrudTheme? theme,
  ZFieldSize size = ZFieldSize.normal,
  ZFieldConfig? config,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final controller = ZFormController(
    initialValues: const <String, Object?>{'p': '+22890123456', 't': 'abc'},
    visibleFields: const <String>['p', 't'],
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: ZcrudScope(
        theme: theme,
        widgetRegistry: ZWidgetRegistry()
          ..register(
            'phoneNumber',
            ZPhoneFieldWidget.builder(defaultIsoCode: 'TG'),
          ),
        child: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: <ZFieldSpec>[
              ZFieldSpec(
                name: 'p',
                type: EditionFieldType.phoneNumber,
                label: 'Téléphone',
                fieldSize: size,
                config: config,
              ),
              // VOISIN de référence : le champ `text` du CŒUR, dans le MÊME
              // formulaire et le MÊME thème. C'est lui l'oracle — jamais un
              // nombre écrit dans ce fichier.
              ZFieldSpec(
                name: 't',
                type: EditionFieldType.text,
                label: 'Nom',
                fieldSize: size,
              ),
            ],
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Retrait de **TÊTE** de [inner] dans [outer], selon [direction] (AD-13 : on ne
/// lit jamais « la gauche », on lit le bord de tête).
double _head(Rect outer, Rect inner, TextDirection direction) =>
    direction == TextDirection.ltr
        ? inner.left - outer.left
        : outer.right - inner.right;

/// Cadre décoré du champ téléphone (l'enveloppe qui porte bordure et fond).
Rect _phoneBox(WidgetTester tester) => tester.getRect(
      find
          .descendant(
            of: find.byKey(const Key('z-phone-tap-target')),
            matching: find.byType(InputDecorator),
          )
          .first,
    );

/// Cadre décoré du champ `text` voisin (repéré par SA valeur, pas par un index).
Finder _neighbourEditable() => find.byWidgetPredicate(
      (w) => w is EditableText && w.controller.text == 'abc',
    );

Rect _neighbourBox(WidgetTester tester) => tester.getRect(
      find
          .ancestor(
            of: _neighbourEditable(),
            matching: find.byType(InputDecorator),
          )
          .first,
    );

/// Retrait de tête du DRAPEAU dans le cadre du champ téléphone.
double _flagHead(WidgetTester tester, TextDirection direction) {
  final flag = find.text(_flagTg);
  // Précondition : le sélecteur rend bien UN drapeau (sinon la garde mesurerait
  // le vide et resterait verte par accident).
  expect(flag, findsOneWidget);
  return _head(_phoneBox(tester), tester.getRect(flag), direction);
}

/// Retrait de tête du CONTENU du champ voisin, dans son propre cadre.
double _neighbourHead(WidgetTester tester, TextDirection direction) => _head(
      _neighbourBox(tester),
      tester.getRect(_neighbourEditable()),
      direction,
    );

void main() {
  group('CR-DODLP-PHONE-INDENT — parité de retrait avec le champ voisin', () {
    testWidgets('LTR : le drapeau démarre au retrait du contenu voisin',
        (tester) async {
      await _pump(tester);
      final flag = _flagHead(tester, TextDirection.ltr);
      final neighbour = _neighbourHead(tester, TextDirection.ltr);
      // Deux rendus RÉELS confrontés. Aucune constante de style ici : si le
      // thème change, les DEUX bougent ensemble.
      expect(flag, neighbour,
          reason: 'drapeau à $flag dp, contenu du champ voisin à $neighbour dp');
      // Et le retrait n'est pas nul : sans cela, l'égalité serait satisfaite par
      // deux champs tous deux collés au bord.
      expect(neighbour, greaterThan(0));
    });

    testWidgets('LTR : la parité SUIT le jeton (thème à retrait élargi)',
        (tester) async {
      await _pump(tester, theme: _widePadding);
      final flag = _flagHead(tester, TextDirection.ltr);
      final neighbour = _neighbourHead(tester, TextDirection.ltr);
      expect(flag, neighbour,
          reason: 'drapeau à $flag dp, contenu du champ voisin à $neighbour dp');
    });

    testWidgets(
        'LTR : changer le jeton déplace le drapeau AUTANT que le voisin',
        (tester) async {
      await _pump(tester);
      final flagNarrow = _flagHead(tester, TextDirection.ltr);
      final neighbourNarrow = _neighbourHead(tester, TextDirection.ltr);
      await _pump(tester, theme: _widePadding);
      final flagWide = _flagHead(tester, TextDirection.ltr);
      final neighbourWide = _neighbourHead(tester, TextDirection.ltr);
      // Le déplacement est celui du jeton, mesuré sur le voisin — pas un nombre
      // écrit ici.
      expect(flagWide - flagNarrow, neighbourWide - neighbourNarrow);
      expect(neighbourWide - neighbourNarrow, greaterThan(0));
    });

    testWidgets('RTL : le retrait est bien un retrait de TÊTE (AD-13)',
        (tester) async {
      // Le tiers ajoute en RTL 8 dp de tête qui lui sont propres (`Padding(
      // EdgeInsets.only(right: 8))` NON directionnel de `SelectorButton`), hors
      // de notre portée. Ce que NOUS devons garantir : notre part du retrait
      // suit le jeton, du côté tête. Le résidu du tiers est donc CONSTANT.
      await _pump(tester, direction: TextDirection.rtl);
      final residualNarrow = _flagHead(tester, TextDirection.rtl) -
          _neighbourHead(tester, TextDirection.rtl);
      await _pump(tester, direction: TextDirection.rtl, theme: _widePadding);
      final residualWide = _flagHead(tester, TextDirection.rtl) -
          _neighbourHead(tester, TextDirection.rtl);
      expect(residualWide, residualNarrow,
          reason: 'résidu RTL : $residualNarrow dp puis $residualWide dp — '
              's\'ils diffèrent, notre retrait ne suit pas le jeton côté tête');
      // Le retrait de tête RTL doit avoir AUGMENTÉ avec le jeton (sinon la
      // constance du résidu serait celle de deux valeurs figées).
      await _pump(tester, direction: TextDirection.rtl);
      final headNarrow = _flagHead(tester, TextDirection.rtl);
      await _pump(tester, direction: TextDirection.rtl, theme: _widePadding);
      expect(_flagHead(tester, TextDirection.rtl), greaterThan(headNarrow));
    });

    testWidgets('bare (fieldSize large) : aucun retrait ajouté, parité gardée',
        (tester) async {
      // En `bare` le décor est porté par la Card : `contentPadding` nul et
      // bordure `none` ⇒ le retrait dérivé vaut 0, comme pour le voisin. Garde
      // de NON-RÉGRESSION : la correction ne doit rien décaler ici.
      await _pump(tester, size: ZFieldSize.large);
      final flag = _flagHead(tester, TextDirection.ltr);
      expect(flag, _neighbourHead(tester, TextDirection.ltr));
      expect(flag, 0.0);
    });

    testWidgets('paramètre > jeton : la config par champ l\'emporte',
        (tester) async {
      await _pump(tester);
      final tokenHead = _flagHead(tester, TextDirection.ltr);
      await _pump(
        tester,
        config: ZIntlFieldConfig(selectorLeadingPadding: tokenHead + 24),
      );
      expect(_flagHead(tester, TextDirection.ltr), tokenHead + 24);
      // …et il ne suit alors plus le voisin : c'est bien l'hôte qui décide.
      expect(
        _flagHead(tester, TextDirection.ltr),
        isNot(_neighbourHead(tester, TextDirection.ltr)),
      );
    });
  });
}
