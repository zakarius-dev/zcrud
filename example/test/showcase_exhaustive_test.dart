import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/demos/showcase/showcase_coverage.dart';
import 'package:zcrud_example/demos/showcase/showcase_data.dart';
import 'package:zcrud_example/demos/showcase/showcase_screen.dart';
import 'package:zcrud_field_extras/zcrud_field_extras.dart';
import 'package:zcrud_geo/zcrud_geo.dart';
import 'package:zcrud_html/zcrud_html.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';
import 'package:zcrud_media/zcrud_media.dart';

import 'support/pump_helpers.dart';

void main() {
  // AC1 — EXHAUSTIVITÉ dérivée de l'enum : CHAQUE `EditionFieldType.values` a un
  // statut CONNU (couverture prouvée PAR CONSTRUCTION, jamais un nombre figé).
  test('AC1 — les 46 EditionFieldType ont tous un statut connu (dérivé de l\'enum)',
      () {
    for (final t in EditionFieldType.values) {
      expect(ShowcaseCoverage.byType.containsKey(t), isTrue,
          reason: 'type $t sans statut de couverture (SM-2 : jamais « inconnu »)');
    }
    // La matrice couvre EXACTEMENT l'enum (aucune entrée orpheline, aucun manquant).
    expect(ShowcaseCoverage.byType.length, EditionFieldType.values.length);
    // `CoverageStatus` n'a pas de valeur « inconnu » : SM-2 satisfait par typage.
    for (final c in ShowcaseCoverage.byType.values) {
      expect(CoverageStatus.values.contains(c.status), isTrue);
    }
  });

  // AC2 — les capacités fp-4/fp-5 se rendent par leur VRAI adaptateur (présence ≠
  // association) ; AUCUN ZUnsupportedFieldWidget hors gaps assumés.
  testWidgets('AC2 — nouveaux types rendus par leur adaptateur réel',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const ShowcaseScreen()));
    await tester.pumpAndSettle();

    // Média riche (fp-4-2) : 3 champs mediaImage/File/Video.
    expect(find.byType(ZMediaFieldWidget), findsNWidgets(3));
    // Couleur multiple (fp-4-4).
    expect(find.byType(ZColorMultiFieldWidget), findsOneWidget);
    // HTML en lecture (fp-4-3) : html + inlineHtml readOnly → ZHtmlView (WebView
    // WYSIWYG non montable headless — ET-5).
    expect(find.byType(ZHtmlView), findsNWidgets(2));
    // Champs spécialisés (fp-5-2).
    expect(find.byType(ZPinFieldWidget), findsOneWidget);
    expect(find.byType(ZAutocompleteFieldWidget), findsOneWidget);
    expect(find.byType(ZEditableTableFieldWidget), findsOneWidget);
    // Markdown : bloc + inline + richText (3 ZMarkdownField).
    expect(find.byType(ZMarkdownField), findsNWidgets(3));
    // geo : location + geoArea (2 ZGeoFieldWidget).
    expect(find.byType(ZGeoFieldWidget), findsNWidgets(2));
    // dateRange natif (fp-1-1).
    expect(find.byType(ZDateRangeFieldWidget), findsOneWidget);

    // Aucun repli non-supporté : présence = association réelle partout.
    expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
  });

  // MED-1 — DÉRIVÉ DE LA MATRICE : chaque type étiqueté LIVE (liveNative /
  // liveSatellite) doit être EFFECTIVEMENT monté dans le socle showcase par son
  // VRAI adaptateur — un type ne peut PAS être compté « Livré » sans être rendu.
  // Falsifiable : retirer un type live du socle ⇒ rouge (type nommé « absent du
  // socle ») ; casser sa route (repli non-supporté) ⇒ rouge (type nommé « routé
  // en repli »). La liste des types live est DÉRIVÉE de `ShowcaseCoverage.byType`,
  // jamais figée.
  testWidgets('MED-1 — chaque type LIVE de la matrice est monté par son adaptateur réel dans le socle',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const ShowcaseScreen()));
    await tester.pumpAndSettle();

    // Types LIVE dérivés de la matrice (jamais une liste codée en dur).
    final liveTypes = ShowcaseCoverage.byType.entries
        .where((e) =>
            e.value.status == CoverageStatus.liveNative ||
            e.value.status == CoverageStatus.liveSatellite)
        .map((e) => e.key)
        .toSet();
    // Garde-fou : la matrice DOIT contenir des types live (sinon le test serait
    // vacuously vert).
    expect(liveTypes, isNotEmpty);

    // Champs du socle indexés par type (source de vérité de ce qui est monté).
    final socleByType = <EditionFieldType, List<ZFieldSpec>>{};
    for (final f in ShowcaseData.socleFields) {
      (socleByType[f.type] ??= <ZFieldSpec>[]).add(f);
    }

    for (final t in liveTypes) {
      final specs = socleByType[t];
      expect(specs, isNotNull,
          reason: 'type LIVE $t absent du socle showcase '
              '(compté « Livré » sans être monté — MED-1)');
      // AU MOINS un champ de ce type est réellement monté (clé présente dans
      // l\'arbre) — certains champs de même type peuvent être conditionnels/masqués.
      final mounted = specs!
          .where((s) =>
              find.byKey(ValueKey<String>(s.name)).evaluate().isNotEmpty)
          .toList();
      expect(mounted, isNotEmpty,
          reason: 'type LIVE $t déclaré au socle mais AUCUN champ monté à l\'écran');
      // Chaque champ monté de ce type est servi par son VRAI adaptateur : aucun
      // repli non-supporté dans son sous-arbre (route intacte).
      for (final s in mounted) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey<String>(s.name)),
            matching: find.byType(ZUnsupportedFieldWidget),
          ),
          findsNothing,
          reason: 'type LIVE $t (« ${s.name} ») routé vers un repli '
              'non-supporté (route cassée — MED-1)');
      }
    }
  });

  // AC4 — `absentCapabilities` NE CONTIENT PLUS les kinds livrés (grep négatif) ;
  // ne subsistent que les gaps assumés (icon / LaTeX SVG / itemsAreTags).
  test('AC4 — absentCapabilities réconcilié : livrés retirés, gaps assumés gardés',
      () {
    final kinds = ShowcaseData.absentCapabilities.map((c) => c.kind).toList();
    // Les capacités livrées par FP-4/FP-5 ne figurent plus comme ABSENTES.
    const delivered = <String>[
      'select/radio/relation (modal riche)',
      'mediaImage / mediaFile / mediaVideo',
      'html / inlineHtml',
      'color (multiple)',
      'pin',
      'autocomplete',
      'editableTable',
    ];
    for (final d in delivered) {
      expect(kinds, isNot(contains(d)),
          reason: '$d est LIVRÉ (démontré live) — ne doit plus être ABSENT');
    }
    // Les gaps assumés restants sont présents et justifiés.
    expect(kinds, containsAll(<String>['icon', 'latexSvgFallback', 'itemsAreTags']));
    for (final cap in ShowcaseData.absentCapabilities) {
      expect(cap.reason, isNotEmpty);
    }
  });

  // AC4 — les étiquettes ABSENT restent visibles (jamais silencieusement retirées).
  testWidgets('AC4 — étiquettes ABSENT visibles pour les gaps assumés',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrapForTest(const ShowcaseScreen()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Chip, 'ABSENT'),
        findsNWidgets(ShowcaseData.absentCapabilities.length));
    for (final cap in ShowcaseData.absentCapabilities) {
      expect(find.byKey(ValueKey<String>('absent-${cap.kind}')), findsOneWidget);
    }
  });
}
