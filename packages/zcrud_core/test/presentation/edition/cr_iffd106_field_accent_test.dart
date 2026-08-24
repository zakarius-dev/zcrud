// CR-IFFD-106 — barre d'ACCENT SUPÉRIEURE de champ : une bande fine coiffant
// le champ, dimensionnée par `ZcrudTheme.accentBarHeight` (le jeton cesse de
// mentir : il devient LE consommé), colorée par `zResolveFieldAccent` (clé par
// champ `zFieldAccentKey(name)`, à défaut la teinte par type — chemin CR-96,
// normalisée pour le contraste).
//
// Cadrage :
//  - étalon hôte passif : sans jeton, ou sans couleur résolue, AUCUN wrapper
//    ajouté à l'arbre — rendu strictement inchangé ;
//  - jeton + teinte de type ⇒ barre à la hauteur du jeton, couleur = la MÊME
//    teinte normalisée que la bordure de focus (une seule chaîne de teinte) ;
//  - clé par champ prioritaire sur la teinte de type ;
//  - adversarial : couleur illisible ⇒ normalisée (plancher §1.4.11), jamais
//    appliquée brute ;
//  - décorative : pleine largeur (stretch, symétrique — AD-13), aucune cible
//    tactile ajoutée.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const double _kHauteur = 3.7;

const ZFieldSpec _field = ZFieldSpec(name: 'nom', type: EditionFieldType.text);

const ZcrudTheme _accentTokens = ZcrudTheme(accentBarHeight: _kHauteur);

// Bleu foncé : lisible sur surface claire ⇒ la normalisation est l'identité.
const Color _bleu = Color(0xFF1732AB);
// Vert foncé lisible, distinct du bleu.
const Color _vert = Color(0xFF00600F);

ZGradientSpec _spec(Color c) => ZGradientSpec(
      gradient: LinearGradient(colors: [c, c]),
      onGradient: const Color(0xFFFFFFFF),
    );

ZGradientSpec? _typeResolver(ColorScheme scheme, String key) =>
    key == zFieldTypeTintKey(EditionFieldType.text) ? _spec(_bleu) : null;

Future<void> _pump(
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
}

Finder _bar() => find.byWidgetPredicate(
    (w) => w is SizedBox && w.height == _kHauteur && w.child is ColoredBox);

Color _barColor(WidgetTester tester) =>
    ((tester.widget<SizedBox>(_bar()).child!) as ColoredBox).color;

void main() {
  testWidgets(
      '🔴 ÉTALON hôte passif : sans jeton ET sans couleur résolue, aucune '
      'barre — dans les DEUX directions du opt-in', (tester) async {
    // Ni jeton ni résolveur.
    await _pump(tester);
    expect(_bar(), findsNothing, reason: 'aucune déclaration ⇒ aucun wrapper');
    // Jeton posé SANS couleur résolue : le jeton seul ne peint RIEN (le fond
    // n'a pas d'autre source de couleur — rien d'inventé, FR-26).
    await _pump(tester, theme: _accentTokens);
    expect(_bar(), findsNothing,
        reason: 'hauteur sans couleur ⇒ rien — une barre « neutre » serait '
            'une couleur inventée');
    // Teinte résolue SANS jeton : c'est `accentBarHeight` qui dimensionne la
    // barre — absent, elle n\'existe pas.
    await _pump(tester, resolver: _typeResolver);
    expect(_bar(), findsNothing,
        reason: 'la teinte seule (CR-96) ne fabrique aucune barre');
  });

  testWidgets(
      '🔴 jeton + teinte de type : la barre est rendue à la hauteur EXACTE du '
      'jeton, de la MÊME teinte normalisée que la bordure de focus',
      (tester) async {
    await _pump(tester, resolver: _typeResolver, theme: _accentTokens);
    expect(_bar(), findsOneWidget);
    final deco =
        tester.widget<TextField>(find.byType(TextField)).decoration!;
    final focus = (deco.focusedBorder! as OutlineInputBorder).borderSide.color;
    expect(_barColor(tester), focus,
        reason: 'une seule chaîne de teinte : la barre porte la couleur que '
            'la décoration applique au focus (chemin CR-96, déjà normalisé)');
    // Décorative et symétrique : la bande s\'étire pleine largeur (stretch —
    // identique en RTL, AD-13) et n\'ajoute aucune cible tactile.
    final column = tester.widget<Column>(
        find.ancestor(of: _bar(), matching: find.byType(Column)).first);
    expect(column.crossAxisAlignment, CrossAxisAlignment.stretch);
    expect(
        find.ancestor(of: _bar(), matching: find.byType(GestureDetector)),
        findsNothing,
        reason: 'purement décorative : aucune affordance ajoutée');
  });

  testWidgets(
      '🔴 la clé PAR CHAMP (`zFieldAccentKey`) prime sur la teinte de type',
      (tester) async {
    ZGradientSpec? resolver(ColorScheme scheme, String key) {
      if (key == zFieldAccentKey('nom')) return _spec(_vert);
      if (key == zFieldTypeTintKey(EditionFieldType.text)) return _spec(_bleu);
      return null;
    }

    await _pump(tester, resolver: resolver, theme: _accentTokens);
    expect(_barColor(tester), _vert,
        reason: 'la couleur déclarée champ par champ l\'emporte sur le type');
    final deco =
        tester.widget<TextField>(find.byType(TextField)).decoration!;
    expect((deco.focusedBorder! as OutlineInputBorder).borderSide.color, _bleu,
        reason: 'la clé d\'accent ne détourne PAS la teinte de la décoration');
  });

  testWidgets(
      '🔴 ADVERSARIAL : une couleur illisible est NORMALISÉE (plancher '
      'non-texte 3.0:1 contre la surface du champ), jamais appliquée brute',
      (tester) async {
    const Color jaune = Color(0xFFFFFF00);
    ZGradientSpec? resolver(ColorScheme scheme, String key) =>
        key == zFieldAccentKey('nom') ? _spec(jaune) : null;
    await _pump(tester, resolver: resolver, theme: _accentTokens);
    final rendue = _barColor(tester);
    expect(rendue, isNot(jaune),
        reason: 'une couleur illisible ne doit JAMAIS être peinte telle quelle');
    final surface = ThemeData().colorScheme.surfaceContainerHighest;
    expect(zContrastRatio(rendue, surface),
        greaterThanOrEqualTo(kZNonTextMinContrast),
        reason: 'plancher WCAG §1.4.11 mesuré contre la surface du champ');
  });
}
