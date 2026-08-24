// CR-IFFD-101 — l'œil de la famille MOT DE PASSE et les adornments
// interactifs (`ZFieldAdornment.onTap`).
//
// Contrat gardé : masqué PAR DÉFAUT ; la bascule affiche/masque ; l'état ne
// survit pas au démontage du champ ; cible ≥ 48 dp et sémantique à état
// (AD-13). Adversarial : un adornment SANS `onTap` reste purement décoratif.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const ZFieldSpec _password =
    ZFieldSpec(name: 'secret', type: EditionFieldType.password);

Widget _host(ZFormController c, ZFieldSpec field, {Key? key}) => MaterialApp(
      home: Scaffold(
        body: ZFieldWidget(key: key, controller: c, field: field),
      ),
    );

TextField _tf(WidgetTester t) => t.widget<TextField>(find.byType(TextField));

void main() {
  testWidgets('🔴 masqué par défaut ; l\'œil bascule afficher/masquer', (
    tester,
  ) async {
    final c = ZFormController();
    await tester.pumpWidget(_host(c, _password));
    expect(_tf(tester).obscureText, isTrue,
        reason: 'un mot de passe est TOUJOURS masqué au montage');
    expect(find.byTooltip('Show password'), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(_tf(tester).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(_tf(tester).obscureText, isTrue);
    c.dispose();
  });

  testWidgets('🔴 la bascule NE SURVIT PAS au démontage : un champ remonté '
      'repart masqué', (tester) async {
    final c = ZFormController();
    await tester.pumpWidget(_host(c, _password, key: const ValueKey('a')));
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(_tf(tester).obscureText, isFalse);
    // Nouvelle clé ⇒ State recréé (démontage/remontage).
    await tester.pumpWidget(_host(c, _password, key: const ValueKey('b')));
    expect(_tf(tester).obscureText, isTrue);
    c.dispose();
  });

  testWidgets('a11y : cible ≥ 48 dp et sémantique À ÉTAT sur l\'œil', (
    tester,
  ) async {
    final c = ZFormController();
    await tester.pumpWidget(_host(c, _password));
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(find.byType(IconButton)),
      containsSemantics(hasToggledState: true, isToggled: false),
      reason: 'le bouton annonce son état (masqué ⇒ non enclenché)',
    );
    c.dispose();
  });

  testWidgets('un mot de passe en LECTURE SEULE n\'offre pas la bascule', (
    tester,
  ) async {
    final c = ZFormController();
    await tester.pumpWidget(
      _host(c, _password.copyWith(readOnly: true)),
    );
    expect(find.byType(IconButton), findsNothing);
    expect(_tf(tester).obscureText, isTrue);
    c.dispose();
  });

  testWidgets('🔴 ADVERSARIAL : un adornment SANS onTap reste décoratif ; '
      'avec onTap, il devient une cible qui appelle la closure', (
    tester,
  ) async {
    final c = ZFormController();
    // Sans onTap : aucun IconButton (arbre strictement antérieur).
    await tester.pumpWidget(_host(
      c,
      const ZFieldSpec(
        name: 'a',
        type: EditionFieldType.text,
        suffix: ZFieldAdornment.icon('info'),
      ),
    ));
    expect(find.byType(IconButton), findsNothing);

    // Avec onTap : cible ≥ 48 dp qui appelle la closure au tap.
    var taps = 0;
    await tester.pumpWidget(_host(
      c,
      ZFieldSpec(
        name: 'a',
        type: EditionFieldType.text,
        suffix: ZFieldAdornment.icon('info', onTap: () => taps++),
      ),
    ));
    final button = find.byType(IconButton);
    expect(button, findsOneWidget);
    final size = tester.getSize(button);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    expect(taps, 1);
    c.dispose();
  });

  testWidgets('adornment TEXTE avec onTap : cible bornée à 48 dp minimum, '
      'sémantique de bouton', (tester) async {
    final c = ZFormController();
    var taps = 0;
    await tester.pumpWidget(_host(
      c,
      ZFieldSpec(
        name: 'a',
        type: EditionFieldType.text,
        suffix: ZFieldAdornment.text('kg', onTap: () => taps++),
      ),
    ));
    // Un `InputDecoration.suffix` n'est INTERACTIF qu'une fois le champ
    // focalisé (comportement Material) : focaliser d'abord.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final target = find.byType(InkWell);
    expect(target, findsOneWidget);
    final size = tester.getSize(target);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(target);
    expect(taps, 1);
    c.dispose();
  });
}
