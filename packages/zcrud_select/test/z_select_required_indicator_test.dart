/// 🎯 CR-REQUIRED-INDICATOR — gardes PORTEUSES de l'astérisque « requis » du
/// présentateur (`ZSmartSelectPresenter`), tile **et** titre de modal.
///
/// **La régression défendue** : le rendu natif décoré porte l'astérisque via
/// `zFieldDecoration → ZFieldLabel`. Enrôler `zcrud_select` remplace ce rendu par
/// le tile du présentateur, qui ne le portait pas — donc **câbler le paquet
/// faisait DISPARAÎTRE l'indicateur**.
///
/// 🔴 **Anti-vacuité (piège propre à ce lot)** : une garde de l'astérisque qui
/// passerait aussi avec `isRequired: false` ne mesure rien. **Chaque** propriété
/// est donc affirmée dans les DEUX sens (requis ⇒ présent, non requis ⇒ absent),
/// et sur les DEUX branches (`.single` et `.multiple`, deux sites d'appel
/// distincts dans `present()`).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_select/zcrud_select.dart';

const List<ZFieldChoice> _abc = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'Alpha'),
  ZFieldChoice(value: 'b', label: 'Bravo'),
];

/// Spec de champ, requise ou non (le `required` passe par un VALIDATEUR — c'est
/// la seule source de `ZFieldSpec.isRequired`).
ZFieldSpec _spec({
  required bool required,
  bool readOnly = false,
}) =>
    ZFieldSpec(
      name: 'f',
      type: EditionFieldType.select,
      label: 'Mon champ',
      choices: _abc,
      readOnly: readOnly,
      validators: required
          ? const <ZValidatorSpec>[ZValidatorSpec.required()]
          : const <ZValidatorSpec>[],
    );

Widget _host({
  required Widget child,
  ThemeData? theme,
  ZcrudTheme? tokens,
}) =>
    MaterialApp(
      theme: theme,
      home: ZcrudScope(
        selectPresenter: const ZSmartSelectPresenter(),
        theme: tokens,
        child: Scaffold(body: child),
      ),
    );

Widget _field({
  required bool required,
  bool multiple = false,
  bool searchable = false,
  bool readOnly = false,
  Object? value,
}) =>
    ZSelectFieldWidget(
      field: _spec(required: required, readOnly: readOnly),
      value: value,
      onChanged: (_) {},
      multiple: multiple,
      searchable: searchable,
    );

/// Le `ListTile` du déclencheur riche (spécifique au présentateur : le rendu
/// natif n'enveloppe aucun `ListTile` dans un `Card`).
final Finder _trigger =
    find.descendant(of: find.byType(Card), matching: find.byType(ListTile)).first;

/// L'astérisque **peint** — le `Text(' *')` porté par le `WidgetSpan`.
final Finder _star = find.text(' *');

/// Style **effectif** du texte `Mon champ` tel qu'il sera peint : on descend
/// l'arbre de spans en fusionnant les styles, exactement comme le fait
/// `TextPainter`.
///
/// 🔴 Pourquoi pas le style du `RichText` racine : il vaut le `DefaultTextStyle`
/// ambiant **quoi qu'il arrive** ; l'affirmer serait tautologique. C'est le
/// style fusionné AU NIVEAU DU TEXTE qui révèle une surcharge imposée par un
/// libellé enrichi (c'est précisément ce que ferait `ZFieldLabel`, mesuré à
/// `w500` en `large` et `bodyMedium` sinon).
TextStyle? _paintedLabelStyle(WidgetTester tester, Finder scope) {
  final RichText rt = tester.widget<RichText>(
    find.descendant(of: scope, matching: find.byType(RichText)).first,
  );
  TextStyle? found;
  void walk(InlineSpan span, TextStyle? inherited) {
    if (span is! TextSpan) return;
    final TextStyle? merged = span.style == null
        ? inherited
        : (inherited == null ? span.style : inherited.merge(span.style));
    if (span.text == 'Mon champ') found = merged;
    for (final InlineSpan c in span.children ?? const <InlineSpan>[]) {
      walk(c, merged);
    }
  }

  walk(rt.text, null);
  return found;
}

void main() {
  group('🎯 CR-REQUIRED-INDICATOR — tile MONO (`SmartSelect.single`)', () {
    testWidgets('champ REQUIS → astérisque peint dans le titre du tile',
        (tester) async {
      await tester.pumpWidget(_host(child: _field(required: true)));
      expect(
        find.descendant(of: _trigger, matching: _star),
        findsOneWidget,
        reason: 'le tile du présentateur doit porter l\'astérisque requis',
      );
    });

    testWidgets('champ NON requis → AUCUN astérisque (anti-vacuité)',
        (tester) async {
      await tester.pumpWidget(_host(child: _field(required: false)));
      expect(_star, findsNothing);
    });

    testWidgets('requis MAIS `readOnly` → aucun astérisque (règle `!readOnly`)',
        (tester) async {
      // Une valeur est nécessaire : `readOnly` + rien de sélectionné fait
      // DISPARAÎTRE le tile (parité DODLP) — la garde n'aurait alors rien à
      // mesurer et passerait pour la mauvaise raison.
      await tester.pumpWidget(
        _host(child: _field(required: true, readOnly: true, value: 'a')),
      );
      await tester.pumpAndSettle();
      expect(_trigger, findsOneWidget,
          reason: 'le tile doit être monté (sinon la garde ne mesure rien)');
      expect(_star, findsNothing);
    });
  });

  group('🎯 CR-REQUIRED-INDICATOR — tile MULTI (`SmartSelect.multiple`)', () {
    testWidgets('champ REQUIS → astérisque peint dans le titre du tile',
        (tester) async {
      await tester.pumpWidget(
        _host(child: _field(required: true, multiple: true)),
      );
      expect(find.descendant(of: _trigger, matching: _star), findsOneWidget);
    });

    testWidgets('champ NON requis → AUCUN astérisque (anti-vacuité)',
        (tester) async {
      await tester.pumpWidget(
        _host(child: _field(required: false, multiple: true)),
      );
      expect(_star, findsNothing);
    });
  });

  group('🎯 CR-REQUIRED-INDICATOR — l\'astérisque est DÉCORATIF (AD-13)', () {
    testWidgets('astérisque sous `ExcludeSemantics` (jamais lu à voix haute)',
        (tester) async {
      await tester.pumpWidget(_host(child: _field(required: true)));
      expect(
        find.ancestor(of: _star, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
    });

    testWidgets(
        '« requis » passe par `Semantics.isRequired`, PAS par le seul astérisque',
        (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(child: _field(required: true)));
      expect(
        tester.getSemantics(_trigger),
        isSemantics(isRequired: true, hasRequiredState: true),
      );
      handle.dispose();
    });

    testWidgets('champ NON requis → `isRequired` FAUX (anti-vacuité)',
        (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(child: _field(required: false)));
      expect(
        tester.getSemantics(_trigger),
        isSemantics(isRequired: false),
      );
      handle.dispose();
    });
  });

  group('🎯 CR-REQUIRED-INDICATOR — couleur par RÔLE (FR-26)', () {
    testWidgets('sans jeton → `ColorScheme.error` du thème AMBIANT',
        (tester) async {
      // 🔴 Anti-tautologie : le thème porte une couleur d'erreur ARBITRAIRE,
      // absente du code source du paquet. Une constante en dur ne peut pas la
      // produire par accident.
      const Color rouge = Color(0xFF123456);
      final ThemeData theme = ThemeData(
        colorScheme: const ColorScheme.light().copyWith(error: rouge),
      );
      await tester.pumpWidget(
        _host(theme: theme, child: _field(required: true)),
      );
      // Rouge d'ASSERTION garanti : on affirme d'abord la PRÉSENCE (sinon
      // `tester.widget` lèverait un `StateError`, rouge moins lisible).
      expect(_star, findsOneWidget);
      expect(tester.widget<Text>(_star).style?.color, rouge);
    });

    testWidgets('jeton `ZcrudTheme.errorColor` PRIORITAIRE sur le ColorScheme',
        (tester) async {
      const Color roleScheme = Color(0xFF123456);
      const Color jeton = Color(0xFF00FF7F);
      final ThemeData theme = ThemeData(
        colorScheme: const ColorScheme.light().copyWith(error: roleScheme),
      );
      await tester.pumpWidget(_host(
        theme: theme,
        tokens: const ZcrudTheme(errorColor: jeton),
        child: _field(required: true),
      ));
      expect(_star, findsOneWidget);
      expect(tester.widget<Text>(_star).style?.color, jeton);
    });
  });

  group('🎯 CR-REQUIRED-INDICATOR — titre du MODAL', () {
    testWidgets('MONO : le titre du modal porte l\'astérisque', (tester) async {
      await tester.pumpWidget(_host(child: _field(required: true)));
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      // Le titre du modal vit dans l'`AppBar` de l'en-tête S2.
      expect(
        find.descendant(of: find.byType(AppBar), matching: _star),
        findsOneWidget,
      );
      // …et le titre lui-même est toujours là (l'en-tête n'a pas été perdu en
      // route en remplaçant `defaultModalHeader`).
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.textContaining('Mon champ', findRichText: true),
        ),
        findsOneWidget,
      );
    });

    testWidgets('MONO non requis : modal SANS astérisque (anti-vacuité)',
        (tester) async {
      await tester.pumpWidget(_host(child: _field(required: false)));
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(_star, findsNothing);
    });

    testWidgets(
        'MONO requis + searchable : la BASCULE de recherche fonctionne toujours',
        (tester) async {
      // 🔴 Le remplacement de `defaultModalHeader` doit reproduire son état
      // « filtrage » (loupe en `leading`, champ de saisie en titre) — sans cette
      // garde, la seule branche testée de l'en-tête serait la branche au repos.
      await tester.pumpWidget(
        _host(child: _field(required: true, searchable: true)),
      );
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.search),
        ),
      );
      await tester.pumpAndSettle();
      // En filtrage, le champ de saisie du fork est monté DANS l'en-tête…
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
      );
      // …et le titre (donc l'astérisque) laisse la place, comme chez le fork.
      // 🔴 Porté sur l'`AppBar` SEULE : le tile du champ reste monté DERRIÈRE le
      // modal et porte, lui, toujours son astérisque — un `findsNothing` global
      // mesurerait le mauvais nœud.
      expect(
        find.descendant(of: find.byType(AppBar), matching: _star),
        findsNothing,
      );
    });

    testWidgets('MULTI searchable : le titre du modal porte l\'astérisque',
        (tester) async {
      await tester.pumpWidget(
        _host(child: _field(required: true, multiple: true, searchable: true)),
      );
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: _star),
        findsOneWidget,
      );
    });

    testWidgets('MULTI searchable non requis : SANS astérisque (anti-vacuité)',
        (tester) async {
      await tester.pumpWidget(
        _host(child: _field(required: false, multiple: true, searchable: true)),
      );
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(_star, findsNothing);
    });

    testWidgets('MULTI non searchable : le titre du modal porte l\'astérisque',
        (tester) async {
      await tester.pumpWidget(
        _host(child: _field(required: true, multiple: true)),
      );
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: _star),
        findsOneWidget,
      );
    });
  });

  group('🎯 CR-REQUIRED-INDICATOR — hôte PASSIF immobile (typographie)', () {
    testWidgets(
        'le titre du tile garde EXACTEMENT sa typographie, requis ou non',
        (tester) async {
      await tester.pumpWidget(_host(child: _field(required: false)));
      final TextStyle? sansEtoile = _paintedLabelStyle(tester, _trigger);

      await tester.pumpWidget(_host(child: _field(required: true)));
      final TextStyle? avecEtoile = _paintedLabelStyle(tester, _trigger);

      expect(sansEtoile, isNotNull);
      expect(avecEtoile, isNotNull);
      // 🔴 C'est CE que casserait un `ZFieldLabel` posé en `ListTile.title` :
      // mesuré, il impose `w500`/16 (`large`) ou `bodyMedium`/14 — le libellé
      // d'un champ requis ne rendrait plus comme celui d'un champ facultatif.
      expect(avecEtoile!.fontSize, sansEtoile!.fontSize);
      expect(avecEtoile.fontWeight, sansEtoile.fontWeight);
      expect(avecEtoile.color, sansEtoile.color);
      expect(avecEtoile.fontFamily, sansEtoile.fontFamily);
    });

    testWidgets(
        'champ NON requis : le titre reste un `Text` NU (aucun `WidgetSpan`)',
        (tester) async {
      await tester.pumpWidget(_host(child: _field(required: false)));
      // `find.text` (sans `findRichText`) ne mord que sur un `Text` dont le
      // texte brut vaut exactement le libellé : un `WidgetSpan` y injecterait
      // U+FFFC et ferait échouer les `find.text` des hôtes.
      expect(
        find.descendant(of: _trigger, matching: find.text('Mon champ')),
        findsOneWidget,
      );
    });
  });

  group('🎯 CR-REQUIRED-INDICATOR — non-divergence avec `ZFieldLabel` (cœur)',
      () {
    testWidgets(
        'même glyphe et même couleur résolue que l\'astérisque du cœur',
        (tester) async {
      const Color rouge = Color(0xFF123456);
      final ThemeData theme = ThemeData(
        colorScheme: const ColorScheme.light().copyWith(error: rouge),
      );
      // Référence : l'astérisque tel que le cœur le rend.
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(body: ZFieldLabel(field: _spec(required: true))),
      ));
      expect(_star, findsOneWidget, reason: 'référence du cœur montée');
      final Text reference = tester.widget<Text>(_star);

      // Le nôtre, dans le même thème.
      await tester.pumpWidget(
        _host(theme: theme, child: _field(required: true)),
      );
      expect(_star, findsOneWidget, reason: 'astérisque du présentateur monté');
      final Text notre = tester.widget<Text>(_star);

      expect(notre.data, reference.data,
          reason: 'même glyphe que `ZFieldLabel`');
      expect(notre.style?.color, reference.style?.color,
          reason: 'même couleur RÉSOLUE que `ZFieldLabel`');
      // Et le cœur, lui aussi, l'exclut de la sémantique.
      expect(
        find.ancestor(of: _star, matching: find.byType(ExcludeSemantics)),
        findsWidgets,
      );
    });
  });
}
