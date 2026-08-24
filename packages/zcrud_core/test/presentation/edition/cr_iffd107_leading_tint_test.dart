// CR-IFFD-107 (volet cœur) — la TEINTE et la PASTILLE suivent l'ornement
// `leading`, et deviennent disponibles au PRÉSENTATEUR RICHE :
//  - le slot `leading` (`InputDecoration.icon`) reçoit le même traitement que
//    `prefixIcon`/`suffixIcon` (glyphe teinté via `iconColor`, pastille sous
//    les mêmes jetons), sous la même gouvernance de modes (`bare` : porté par
//    la Card, inchangé) ;
//  - `zResolveTintedAdornment` rend à un présentateur la teinte NORMALISÉE et
//    l'icône en pastille prêtes à poser sur une tuile, sans dupliquer ni la
//    résolution de clé ni la normalisation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const ZFieldSpec _field = ZFieldSpec(
  name: 'quand',
  type: EditionFieldType.text,
  leading: ZFieldAdornment.icon('date'),
);

const ZFieldSpec _fieldLarge = ZFieldSpec(
  name: 'quand',
  type: EditionFieldType.text,
  leading: ZFieldAdornment.icon('date'),
  fieldSize: ZFieldSize.large,
);

const Color _bleu = Color(0xFF1732AB);

ZGradientSpec? _tintResolver(ColorScheme scheme, String key) =>
    key == zFieldTypeTintKey(EditionFieldType.text)
        ? const ZGradientSpec(
            gradient: LinearGradient(colors: [_bleu, _bleu]),
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
      '🔴 ÉTALON hôte passif : sans jeton, le slot `leading` porte l\'Icon '
      'telle quelle — même avec une teinte résolue, aucun conteneur',
      (tester) async {
    final sans = await _pumpDecoration(tester);
    expect(sans.icon, isA<Icon>(),
        reason: 'sans jeton, le slot `icon` reste l\'Icon nue');
    expect((sans.icon! as Icon).size, isNull);
    expect(sans.iconColor, isNull);
    final avecTeinte = await _pumpDecoration(tester, resolver: _tintResolver);
    expect(avecTeinte.icon, isA<Icon>(),
        reason: 'la teinte seule ne fabrique AUCUNE pastille sur `leading`');
    expect(avecTeinte.iconColor, isNotNull,
        reason: 'le glyphe de tête est teinté par `iconColor` (chemin CR-96)');
  });

  testWidgets(
      '🔴 jetons + teinte : `leading` reçoit le MÊME traitement que '
      '`prefixIcon` — pastille (teinte atténuée, rayon, insets directionnels) '
      'et glyphe dimensionné', (tester) async {
    final deco = await _pumpDecoration(
      tester,
      resolver: _tintResolver,
      theme: _pillTokens,
    );
    final tint = deco.iconColor;
    expect(tint, isNotNull, reason: 'pré-requis : la teinte est résolue');
    expect(deco.icon, isA<Center>(),
        reason: 'la pastille épouse le glyphe, comme sur `prefixIcon`');
    final box = (deco.icon! as Center).child! as DecoratedBox;
    final d = box.decoration as BoxDecoration;
    expect(d.color, tint!.withValues(alpha: 0.12),
        reason: 'le fond est la MÊME teinte normalisée, atténuée par l\'alpha');
    expect(d.borderRadius, const BorderRadius.all(Radius.circular(8)));
    final padding = box.child! as Padding;
    expect(padding.padding, const EdgeInsetsDirectional.all(7),
        reason: 'insets DIRECTIONNELS (AD-13)');
    expect((padding.child! as Icon).size, 18);
  });

  testWidgets(
      '🔴 gouvernance des modes : en `large` (bare), `leading` est porté par '
      'la Card — nu, jamais pastillé, même jetons + teinte posés',
      (tester) async {
    final c = ZFormController();
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZcrudScope(
          gradientResolver: _tintResolver,
          theme: _pillTokens,
          child: SingleChildScrollView(
            child: ZFieldWidget(controller: c, field: _fieldLarge),
          ),
        ),
      ),
    ));
    final deco = tester.widget<TextField>(find.byType(TextField)).decoration!;
    expect(deco.icon, isNull,
        reason: 'en bare, la décoration ne porte pas `leading` (Card)');
    // L'icône de la Card reste NUE : aucune pastille hors de la décoration.
    expect(
        find.byWidgetPredicate((w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color != null &&
            ((w.decoration as BoxDecoration).color!.a - 0.12).abs() < 0.001),
        findsNothing,
        reason: 'la gouvernance `bare`/`large` est inchangée');
  });

  group('zResolveTintedAdornment — point d\'entrée des présentateurs riches',
      () {
    Future<ZTintedAdornment> resolve(
      WidgetTester tester, {
      ZFieldAdornment? adornment = const ZFieldAdornment.icon('date'),
      ZGradientResolver? resolver,
      ZcrudTheme? theme,
    }) async {
      late ZTintedAdornment out;
      await tester.pumpWidget(MaterialApp(
        home: ZcrudScope(
          gradientResolver: resolver,
          theme: theme,
          child: Builder(builder: (context) {
            out = zResolveTintedAdornment(context, adornment, field: _field);
            return const SizedBox.shrink();
          }),
        ),
      ));
      return out;
    }

    testWidgets(
        '🔴 la teinte rendue est NORMALISÉE (plancher 3.0:1) — une couleur '
        'illisible n\'est jamais rendue brute', (tester) async {
      const Color jaune = Color(0xFFFFFF00);
      final out = await resolve(
        tester,
        resolver: (scheme, key) =>
            key == zFieldTypeTintKey(EditionFieldType.text)
                ? const ZGradientSpec(
                    gradient: LinearGradient(colors: [jaune, jaune]),
                    onGradient: Color(0xFF000000),
                  )
                : null,
      );
      expect(out.tint, isNotNull);
      expect(out.tint, isNot(jaune),
          reason: 'le présentateur reçoit une teinte DÉJÀ normalisée — il ne '
              're-normalise pas');
      final surface = ThemeData().colorScheme.surfaceContainerHighest;
      expect(zContrastRatio(out.tint!, surface),
          greaterThanOrEqualTo(kZNonTextMinContrast));
    });

    testWidgets(
        '🔴 jetons + teinte : le child est l\'icône EN PASTILLE, glyphe teinté '
        'et dimensionné — prêt à poser sur une tuile', (tester) async {
      final out = await resolve(
        tester,
        resolver: _tintResolver,
        theme: _pillTokens,
      );
      final center = out.child;
      expect(center, isA<Center>());
      final box = (center! as Center).child! as DecoratedBox;
      expect((box.decoration as BoxDecoration).color,
          out.tint!.withValues(alpha: 0.12));
      final icon =
          ((box.child! as Padding).child!) as Icon;
      expect(icon.color, out.tint,
          reason: 'hors décoration, le glyphe porte la teinte lui-même');
      expect(icon.size, 18);
    });

    testWidgets(
        'sans jetons : le child est l\'Icon teintée, sans conteneur ; sans '
        'résolveur : rien d\'inventé (tint null, Icon nue)', (tester) async {
      final teintee = await resolve(tester, resolver: _tintResolver);
      expect(teintee.child, isA<Icon>());
      expect((teintee.child! as Icon).color, teintee.tint);
      final nue = await resolve(tester);
      expect(nue.tint, isNull);
      expect(nue.child, isA<Icon>());
      expect((nue.child! as Icon).color, isNull);
    });

    testWidgets(
        'ornement absent ⇒ child null mais la teinte reste servie ; ornement '
        'INTERACTIF ⇒ IconButton nu (cible ≥ 48 dp), jamais pastillé',
        (tester) async {
      final absent = await resolve(tester,
          adornment: null, resolver: _tintResolver, theme: _pillTokens);
      expect(absent.child, isNull);
      expect(absent.tint, isNotNull,
          reason: 'la tuile peut teinter ses propres canaux sans ornement');
      final interactif = await resolve(tester,
          adornment: ZFieldAdornment.icon('clear', onTap: () {}),
          resolver: _tintResolver,
          theme: _pillTokens);
      expect(interactif.child, isA<IconButton>(),
          reason: 'l\'affordance native prime — pas de pastille décorative');
    });
  });
}
