import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/demos/showcase/showcase_data.dart';
import 'package:zcrud_example/demos/showcase/showcase_screen.dart';
import 'package:zcrud_geo/zcrud_geo.dart';
import 'package:zcrud_intl/zcrud_intl.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import 'support/pump_helpers.dart';

void main() {
  // AC1 — le socle est monté par le VRAI dispatcher : chaque famille est rendue
  // par SON adaptateur concret (présence ≠ association) ; AUCUN
  // ZUnsupportedFieldWidget (les satellites markdown/intl/geo sont servis par le
  // registre peuplé via le composeur fp-2-2).
  testWidgets('AC1 — socle rendu par les adaptateurs réels, zéro non-supporté',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const ShowcaseScreen()));
    await tester.pumpAndSettle();

    // Familles natives (cœur) — adaptateurs concrets.
    expect(find.byType(ZTextFieldWidget), findsWidgets);
    expect(find.byType(ZNumberFieldWidget), findsWidgets);
    expect(find.byType(ZDateFieldWidget), findsWidgets);
    expect(find.byType(ZDateRangeFieldWidget), findsOneWidget);
    expect(find.byType(ZBooleanFieldWidget), findsWidgets);
    expect(find.byType(ZSelectFieldWidget), findsWidgets); // select+radio+checkbox
    expect(find.byType(ZRelationFieldWidget), findsOneWidget);
    expect(find.byType(ZRowChipsFieldWidget), findsOneWidget);
    expect(find.byType(ZTagsFieldWidget), findsOneWidget);
    expect(find.byType(ZRatingFieldWidget), findsOneWidget);
    expect(find.byType(ZSliderFieldWidget), findsOneWidget);
    // sColor (socle) + les 2 voies natif-vs-package (sliders / roue) = 3.
    expect(find.byType(ZColorFieldWidget), findsNWidgets(3));
    expect(find.byType(ZSignatureFieldWidget), findsOneWidget);
    expect(find.byType(ZSubListFieldWidget), findsOneWidget);
    expect(find.byType(ZDynamicItemFieldWidget), findsOneWidget);

    // Satellites (composeur fp-2-2) — widgets RÉELS des satellites, pas un mock.
    // fp-3-2 : le socle exerce désormais markdown/inlineMarkdown/richText
    // (3 ZMarkdownField) et location + geoArea (2 ZGeoFieldWidget).
    expect(find.byType(ZMarkdownField), findsNWidgets(3));
    expect(find.byType(ZPhoneFieldWidget), findsOneWidget);
    expect(find.byType(ZCountryFieldWidget), findsOneWidget);
    expect(find.byType(ZAddressFieldWidget), findsOneWidget);
    expect(find.byType(ZGeoFieldWidget), findsNWidgets(2));

    // Preuve centrale : présence ≠ association — AUCUN repli non-supporté.
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
  });

  // AC2 — les capacités non livrées sont étiquetées « ABSENT » (visibles, jamais
  // masquées, jamais faux-rendues).
  testWidgets('AC2 — capacités ABSENTES étiquetées et visibles', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const ShowcaseScreen()));
    await tester.pumpAndSettle();

    // Toutes les entrées ABSENTES portent un chip « ABSENT » distinct.
    expect(find.widgetWithText(Chip, 'ABSENT'),
        findsNWidgets(ShowcaseData.absentCapabilities.length));
    // Un gap ASSUMÉ représentatif est textuellement présent (fp-3-2 : les
    // capacités jadis absentes — dont HTML WYSIWYG — sont désormais LIVRÉES ;
    // ne subsistent que les vrais gaps, ex. le fallback LaTeX SVG banni).
    expect(find.textContaining('LaTeX'), findsWidgets);
    // Chaque entrée est identifiée (jamais silencieusement retirée).
    for (final cap in ShowcaseData.absentCapabilities) {
      expect(find.byKey(ValueKey<String>('absent-${cap.kind}')), findsOneWidget,
          reason: 'gap ${cap.kind} doit rester visible');
    }
  });

  // AC3 — valeur initiale : `sText` est pré-rempli via `initialValues`.
  testWidgets('AC3 — valeur initiale pré-remplie', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const ShowcaseScreen()));
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('sText')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.controller.text, 'Valeur initiale');
  });

  // AC3 — champ désactivé : `sDisabled` est en lecture seule (readOnly par champ).
  testWidgets('AC3 — champ désactivé (readOnly par champ)', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const ShowcaseScreen()));
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('sDisabled')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.readOnly, isTrue);
  });

  // AC3 — erreur de validation : « Valider » révèle le message du champ requis.
  testWidgets('AC3 — erreur de validation révélée par « Valider »',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const ShowcaseScreen()));
    await tester.pumpAndSettle();

    // Avant révélation : aucun message d'erreur.
    expect(find.text(showcaseRequiredError), findsNothing);

    await tester.ensureVisible(
        find.byKey(const ValueKey<String>('showcase-validate')));
    await tester.tap(find.byKey(const ValueKey<String>('showcase-validate')));
    await tester.pumpAndSettle();

    expect(find.text(showcaseRequiredError), findsOneWidget);
  });

  // AC3 — conditionnel : `sPremium` masqué tant que `sBoolean` est faux, révélé
  // quand on l'active (le champ de garde pilote la visibilité).
  testWidgets('AC3 — champ conditionnel masqué/révélé par sa garde',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const ShowcaseScreen()));
    await tester.pumpAndSettle();

    // Masqué au départ (sBoolean = false).
    expect(find.byKey(const ValueKey<String>('sPremium')), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey<String>('sBoolean')));
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey<String>('sBoolean')),
      matching: find.byType(Switch),
    ));
    await tester.pumpAndSettle();

    // Révélé une fois la garde active.
    expect(find.byKey(const ValueKey<String>('sPremium')), findsOneWidget);
  });

  // AC3 — mode lecture GLOBAL : la bascule force les champs saisissables en
  // lecture seule (falsifiable — l'état `readOnly` du champ bascule false→true).
  testWidgets('AC3 — bascule mode lecture global', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const ShowcaseScreen()));
    await tester.pumpAndSettle();

    EditableText sText() => tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('sText')),
            matching: find.byType(EditableText),
          ),
        );
    // Éditable au départ.
    expect(sText().readOnly, isFalse);

    await tester.tap(find.byTooltip('Mode édition'));
    await tester.pumpAndSettle();

    // En lecture seule après bascule globale.
    expect(sText().readOnly, isTrue);
  });

  // AC3 — RTL : la bascule applique une direction RTL au sous-arbre du socle
  // (variantes directionnelles — AD-13).
  testWidgets('AC3 — bascule RTL applique TextDirection.rtl', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const ShowcaseScreen()));
    await tester.pumpAndSettle();

    Element bodyEl() =>
        tester.element(find.byKey(const ValueKey<String>('showcase-validate')));
    expect(Directionality.of(bodyEl()), TextDirection.ltr);

    await tester.tap(find.byTooltip('Sens : LTR'));
    await tester.pumpAndSettle();
    expect(Directionality.of(bodyEl()), TextDirection.rtl);
  });

  // AC3 — thème clair/sombre : la bascule dérive un ColorScheme sombre (aucune
  // couleur codée en dur — FR-26).
  testWidgets('AC3 — bascule thème clair/sombre', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const ShowcaseScreen()));
    await tester.pumpAndSettle();

    Element bodyEl() =>
        tester.element(find.byKey(const ValueKey<String>('showcase-validate')));
    expect(Theme.of(bodyEl()).brightness, Brightness.light);

    await tester.tap(find.byTooltip('Thème clair'));
    await tester.pumpAndSettle();
    expect(Theme.of(bodyEl()).brightness, Brightness.dark);
  });
}
