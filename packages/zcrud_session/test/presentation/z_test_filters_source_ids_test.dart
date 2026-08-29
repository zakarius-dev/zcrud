/// 🎯 `ZTestFiltersDialog` — la section « provenance par identifiant ».
///
/// Trois propriétés :
///  1. **INERTIE ABSOLUE** — sans candidats (`availableSourceIds` omis),
///     l'arbre rendu est **strictement identique** (widget par widget, dans
///     l'ordre) à celui d'un dialog construit sans le paramètre. Aucune
///     section, aucun `SizedBox` d'espacement en plus ;
///  2. **PRÉSENCE** — avec candidats, une bascule par identifiant, cochable,
///     et l'ensemble coché ressort dans `ZFlashcardTestFilters.sourceIds` ;
///  3. **AUCUNE PERTE** — un `initial.sourceIds` non vide est **restitué**
///     par « Valider », y compris quand aucune section n'est rendue. C'était
///     le défaut : le dialog reconstruisait les filtres sans ce critère, donc
///     un simple aller-retour l'effaçait en silence.
///
/// A11y (invariant AD-13) : chaque bascule passe par le patron `_FilterToggle`
/// commun (déjà gardé pour `checked:`/`onTap:`/48 dp) — la garde vérifie ici
/// que la nouvelle section emprunte bien ce patron, jamais une copie.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcardTestFilters, ZMasteryLevel;
import 'package:zcrud_session/zcrud_session.dart';

/// Structure EXACTE du contenu du dialog : le type de chaque enfant direct
/// de la `Column`, dans l'ordre.
///
/// 🔴 C'est ce que la garde d'inertie doit mesurer, et **pas** une comparaison
/// entre « paramètre omis » et « paramètre passé vide » : ces deux appels
/// traversent le MÊME code, donc leur égalité est une TAUTOLOGIE — mesuré,
/// une section rendue sans garde de non-vacuité les laissait tous deux verts.
/// La référence est donc une liste GELÉE, écrite ici en toutes lettres.
List<String> _contentStructure(WidgetTester tester) {
  final column = tester.widget<Column>(
    find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Column),
    ),
  );
  return column.children
      .map((Widget w) => w.runtimeType.toString())
      .toList(growable: false);
}

/// Monte le dialog et capture **ce que `Navigator.pop` rend à l'hôte**
/// (même patron que `z_session_mode_selector_test.dart` : c'est le PAYLOAD
/// REÇU qui est asserté, jamais la seule présence d'un widget).
Future<List<ZFlashcardTestFilters?>> _open(
  WidgetTester tester, {
  ZFlashcardTestFilters initial = const ZFlashcardTestFilters(),
  List<String> availableSources = const <String>[],
  List<String> availableSourceIds = const <String>[],
}) async {
  final popped = <ZFlashcardTestFilters?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () async {
              popped.add(
                await showDialog<ZFlashcardTestFilters>(
                  context: context,
                  builder: (_) => ZTestFiltersDialog(
                    initial: initial,
                    availableSources: availableSources,
                    availableSourceIds: availableSourceIds,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  return popped;
}

void main() {
  group('🔒 INERTIE — sans candidats, l\'arbre est INCHANGÉ', () {
    /// Structure HISTORIQUE gelée, avec un `kind` de source proposé et aucun
    /// identifiant : stepper, espacement, trois seaux de maîtrise, puis la
    /// section des `kind` (espacement + une bascule). **Rien d'autre.**
    const historic = <String>[
      '_QuestionCountStepper',
      'SizedBox',
      '_FilterToggle', // ZMasteryLevel.bad
      '_FilterToggle', // ZMasteryLevel.good
      '_FilterToggle', // ZMasteryLevel.mastered
      'SizedBox', // espacement de la section « kind »
      '_FilterToggle', // kind « note »
    ];

    testWidgets(
        '🔴 `availableSourceIds` omis ⇒ contenu STRICTEMENT égal à la '
        'structure historique GELÉE (aucun nœud en plus)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZTestFiltersDialog(availableSources: <String>['note']),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_contentStructure(tester), orderedEquals(historic),
          reason: '🔴 le contenu du dialog a changé alors qu\'aucun '
              'identifiant n\'est proposé : la section (ou son espacement) '
              'est rendue sans candidat');
      expect(find.byKey(ZTestFiltersDialog.sourceIdKey('n1')), findsNothing);
    });

    testWidgets(
        '🔬 contre-preuve — la MÊME mesure voit bien la section quand des '
        'candidats existent (sinon l\'égalité ci-dessus ne prouverait rien)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZTestFiltersDialog(
              availableSources: <String>['note'],
              availableSourceIds: <String>['n1'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        _contentStructure(tester),
        orderedEquals(<String>[...historic, 'SizedBox', '_FilterToggle']),
        reason: '🔴 la mesure de structure est aveugle à la section : la '
            'garde d\'inertie ci-dessus serait verte pour de mauvaises '
            'raisons',
      );
    });
  });

  group('🎯 PRÉSENCE — avec candidats, la section existe et est cochable', () {
    testWidgets('une bascule par identifiant, absente pour un identifiant '
        'non proposé', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZTestFiltersDialog(
              availableSourceIds: <String>['n1', 'doc7'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ZTestFiltersDialog.sourceIdKey('n1')), findsOneWidget);
      expect(find.byKey(ZTestFiltersDialog.sourceIdKey('doc7')), findsOneWidget);
      // 🔴 Discriminant : la section n'affiche QUE les candidats fournis.
      expect(find.byKey(ZTestFiltersDialog.sourceIdKey('n2')), findsNothing);
      // Le repli est l'identifiant lui-même (opaque, non traduisible).
      expect(find.text('n1'), findsOneWidget);
    });

    testWidgets('🔴 cocher deux identifiants les fait ressortir dans '
        '`sourceIds` — et les non cochés N\'Y SONT PAS', (tester) async {
      final popped = await _open(
        tester,
        availableSourceIds: const <String>['n1', 'n2', 'doc7'],
      );

      await tester.tap(find.byKey(ZTestFiltersDialog.sourceIdKey('n1')));
      await tester.pump();
      await tester.tap(find.byKey(ZTestFiltersDialog.sourceIdKey('doc7')));
      await tester.pump();
      await tester.tap(find.byKey(ZTestFiltersDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(popped.single!.sourceIds, <String>{'n1', 'doc7'});
      expect(popped.single!.sourceIds.contains('n2'), isFalse,
          reason: '🔴 un identifiant NON coché est ressorti : la section coche '
              'tout ce qu\'elle propose au lieu de la sélection réelle');
    });

    testWidgets('décocher un identifiant PRÉ-COCHÉ le retire réellement',
        (tester) async {
      final popped = await _open(
        tester,
        initial: const ZFlashcardTestFilters(sourceIds: <String>{'n1', 'n2'}),
        availableSourceIds: const <String>['n1', 'n2'],
      );

      await tester.tap(find.byKey(ZTestFiltersDialog.sourceIdKey('n1')));
      await tester.pump();
      await tester.tap(find.byKey(ZTestFiltersDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(popped.single!.sourceIds, <String>{'n2'});
    });
  });

  group('🎯 AUCUNE PERTE — `initial.sourceIds` est restitué', () {
    testWidgets(
        '🔴 aller-retour SANS toucher à rien, AUCUNE section d\'identifiants '
        'rendue ⇒ `sourceIds` ressort INTACT (c\'était le défaut)',
        (tester) async {
      final popped = await _open(
        tester,
        initial: const ZFlashcardTestFilters(
          questionCount: 25,
          masteryLevels: <ZMasteryLevel>{ZMasteryLevel.bad},
          sources: <String>{'note'},
          sourceIds: <String>{'n1', 'doc7'},
        ),
        // 🔒 `availableSourceIds` délibérément VIDE : c'est le scénario du
        // défaut — aucune section d'identifiants n'est rendue, et le critère
        // devait pourtant survivre.
      );
      expect(find.byKey(ZTestFiltersDialog.sourceIdKey('n1')), findsNothing);

      await tester.tap(find.byKey(ZTestFiltersDialog.confirmKey));
      await tester.pumpAndSettle();

      final out = popped.single;
      expect(out, isNotNull);
      expect(out!.sourceIds, <String>{'n1', 'doc7'},
          reason: '🔴 un aller-retour dans le dialog a EFFACÉ `sourceIds` : le '
              'dialog reconstruit les filtres sans un critère qu\'il ne fait '
              'pas régler');
      // Les autres critères restent eux aussi intacts (témoin : le défaut ne
      // touchait QUE `sourceIds`).
      expect(out.questionCount, 25);
      expect(out.masteryLevels, <ZMasteryLevel>{ZMasteryLevel.bad});
      expect(out.sources, <String>{'note'});
      // Égalité du value-object entier : rien n'a bougé nulle part.
      expect(
        out,
        const ZFlashcardTestFilters(
          questionCount: 25,
          masteryLevels: <ZMasteryLevel>{ZMasteryLevel.bad},
          sources: <String>{'note'},
          sourceIds: <String>{'n1', 'doc7'},
        ),
      );
    });
  });
}
