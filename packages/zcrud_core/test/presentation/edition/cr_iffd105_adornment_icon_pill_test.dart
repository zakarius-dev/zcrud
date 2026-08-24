// CR-IFFD-105 — « pastille » de fond des ornements ICÔNE : un aplat de la
// teinte par type de champ (déjà normalisée — chemin CR-IFFD-96), atténué par
// `adornmentIconBackgroundAlpha`, arrondi par `adornmentIconBackgroundRadius`,
// le glyphe dimensionné par `adornmentIconSize`.
//
// Cadrage :
//  - étalon hôte passif : aucun jeton ⇒ aucun conteneur ajouté à l'arbre
//    (précédent : les jetons `subListAddControl*`) ;
//  - jetons + teinte ⇒ pastille peinte SOUS l'icône, insets directionnels ;
//  - adversarial : jetons SANS teinte résolue ⇒ rien d'inventé — le fond n'a
//    pas d'autre source de couleur (une pastille « neutre » serait une couleur
//    inventée, FR-26) ; seul `adornmentIconSize` (canal de dimension)
//    s'applique ;
//  - gouvernance des modes : en `bare` (Card large), la teinte n'existe pas ⇒
//    pastille omise avec elle ; un ornement interactif garde son `IconButton`
//    nu (cible ≥ 48 dp, AD-13).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const ZFieldSpec _field = ZFieldSpec(
  name: 'nom',
  type: EditionFieldType.text,
  prefix: ZFieldAdornment.icon('person'),
);

ZGradientSpec? _tintResolver(ColorScheme scheme, String key) =>
    key == zFieldTypeTintKey(EditionFieldType.text)
        ? const ZGradientSpec(
            gradient:
                LinearGradient(colors: [Color(0xFF1732AB), Color(0xFF1732AB)]),
            onGradient: Color(0xFFFFFFFF),
          )
        : null;

const ZcrudTheme _pillTokens = ZcrudTheme(
  adornmentIconBackgroundAlpha: 0.12,
  adornmentIconBackgroundRadius: Radius.circular(8),
  adornmentIconSize: 18,
);

Future<InputDecoration> _pumpDecoration(
  WidgetTester tester, {
  ZFieldSpec field = _field,
  ZGradientResolver? resolver,
  ZcrudTheme? theme,
}) async {
  final c = ZFormController();
  addTearDown(c.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ZcrudScope(
        gradientResolver: resolver,
        theme: theme,
        child: ZFieldWidget(controller: c, field: field),
      ),
    ),
  ));
  return tester.widget<TextField>(find.byType(TextField)).decoration!;
}

void main() {
  testWidgets(
      '🔴 ÉTALON hôte passif : aucun jeton ⇒ l\'icône NUE, aucun conteneur '
      'ajouté — même avec une teinte résolue', (tester) async {
    final sans = await _pumpDecoration(tester);
    expect(sans.prefixIcon, isA<Icon>(),
        reason: 'sans jeton, le slot porte l\'Icon telle quelle');
    expect((sans.prefixIcon! as Icon).size, isNull,
        reason: 'sans `adornmentIconSize`, la taille reste au IconTheme');
    final avecTeinte = await _pumpDecoration(tester, resolver: _tintResolver);
    expect(avecTeinte.prefixIcon, isA<Icon>(),
        reason: 'la teinte seule (CR-96) ne fabrique AUCUNE pastille : seul '
            'le canal couleur d\'icône change');
  });

  testWidgets(
      '🔴 jetons + teinte : la pastille est peinte SOUS l\'icône — fond = '
      'teinte normalisée atténuée, rayon, insets directionnels, glyphe 18',
      (tester) async {
    final deco = await _pumpDecoration(
      tester,
      resolver: _tintResolver,
      theme: _pillTokens,
    );
    final tint = deco.prefixIconColor;
    expect(tint, isNotNull, reason: 'pré-requis : la teinte est résolue');
    final center = deco.prefixIcon;
    expect(center, isA<Center>(), reason: 'la pastille épouse le glyphe au '
        'centre du slot (elle ne s\'étire pas — la cible du slot est intacte)');
    final box = (center! as Center).child! as DecoratedBox;
    final d = box.decoration as BoxDecoration;
    expect(d.color, tint!.withValues(alpha: 0.12),
        reason: 'le fond est la MÊME teinte (déjà normalisée), atténuée par '
            'le jeton d\'opacité — jamais une autre couleur');
    expect(d.borderRadius, const BorderRadius.all(Radius.circular(8)));
    final padding = box.child! as Padding;
    expect(padding.padding, const EdgeInsetsDirectional.all(7),
        reason: 'insets DIRECTIONNELS (AD-13)');
    expect((padding.child! as Icon).size, 18,
        reason: 'le glyphe prend `adornmentIconSize`');
  });

  testWidgets(
      '🔴 ADVERSARIAL : jetons posés SANS teinte résolue ⇒ aucune pastille — '
      'rien d\'inventé ; seule la taille (canal de dimension) s\'applique',
      (tester) async {
    final deco = await _pumpDecoration(tester, theme: _pillTokens);
    expect(deco.prefixIconColor, isNull);
    expect(deco.prefixIcon, isA<Icon>(),
        reason: 'le fond n\'a pas d\'autre source de couleur que la teinte : '
            'sans elle, aucun conteneur — une pastille « neutre » serait une '
            'couleur inventée (FR-26)');
    expect((deco.prefixIcon! as Icon).size, 18,
        reason: '`adornmentIconSize` est indépendant de la teinte');
  });

  testWidgets(
      'gouvernance des modes : en `bare` (Card large), pas de teinte ⇒ pas '
      'de pastille, même jetons posés', (tester) async {
    late InputDecoration deco;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZcrudScope(
          gradientResolver: _tintResolver,
          theme: _pillTokens,
          child: Builder(builder: (context) {
            deco = zFieldDecoration(context, _field, bare: true);
            return const SizedBox.shrink();
          }),
        ),
      ),
    ));
    expect(deco.prefixIcon, isA<Icon>(),
        reason: 'la teinte n\'existe pas en `bare` : la pastille est omise '
            'avec elle (gouvernance des modes)');
  });

  testWidgets(
      'un ornement icône INTERACTIF garde son IconButton nu : l\'affordance '
      'native (≥ 48 dp) n\'est ni doublée ni enveloppée', (tester) async {
    final field = ZFieldSpec(
      name: 'nom',
      type: EditionFieldType.text,
      prefix: ZFieldAdornment.icon('person', onTap: () {}),
    );
    final deco = await _pumpDecoration(
      tester,
      field: field,
      resolver: _tintResolver,
      theme: _pillTokens,
    );
    expect(deco.prefixIcon, isA<IconButton>(),
        reason: 'la pastille est décorative : un geste déclaré prime');
  });
}
