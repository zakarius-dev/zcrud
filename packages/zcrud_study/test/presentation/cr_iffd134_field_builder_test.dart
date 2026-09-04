// CR-IFFD-134 — créneau de rendu des champs texte du formulaire de carte de
// `ZMultiFlashcardEditor` (`fieldBuilders`).
//
// Trois propriétés sont gardées ici, et elles sont indépendantes :
//
//  1. INERTIE ABSOLUE — sans aucun slot, l'arbre du formulaire est identique
//     (liste FIGÉE des types d'enfants de la colonne, jamais `contains`), les
//     quatre champs gardent leurs propriétés, et AUCUNE écoute n'est posée sur
//     les controllers (une écriture programmatique dans un controller ne
//     publie RIEN sur le chemin par défaut, où `TextField.onChanged` est le
//     seul publieur — poser une écoute en plus doublerait la notification).
//
//  2. LE CRÉNEAU EST UN CRÉNEAU — un slot fourni pour un champ remplace ce
//     champ et lui seul ; le discriminant reçu est celui du champ, et il est
//     STABLE (indépendant du libellé localisé).
//
//  3. LA SAISIE DE L'HÔTE ATTEINT LA CARTE — c'est le piège que la demande ne
//     voit pas : `_notify()` n'était appelé que par `onChanged` /
//     `onEditingComplete` du `TextField`. Un widget injecté ne notifiait donc
//     rien, et la saisie de l'hôte était perdue silencieusement au commit.
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show Unit, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

class _CommitSpy {
  final List<List<ZFlashcard>> payloads = <List<ZFlashcard>>[];
  Future<ZResult<Unit>> call(List<ZFlashcard> cards) async {
    payloads.add(List<ZFlashcard>.of(cards));
    return right(unit);
  }
}

final _labels = ZMultiFlashcardEditorLabels(
  addCardLabel: 'Ajouter',
  deleteSelectedLabel: 'Supprimer',
  commitLabel: 'Enregistrer',
  applyCommonLabel: 'Appliquer',
  selectAllLabel: 'Tout sélectionner',
  emptyState: 'Aucune carte',
  detailPlaceholder: 'Sélectionner une carte',
  backToListLabel: 'Retour',
  questionLabel: 'Question',
  answerLabel: 'Réponse',
  explanationLabel: 'Explication',
  hintLabel: 'Indice',
  typeLabel: 'Type',
  commonFieldPickerLabel: 'Champ',
  commonValueLabel: 'Valeur',
  previewTitle: 'Aperçu',
  commitSucceeded: 'Enregistré',
  commitFailed: 'Échec',
  selectCardSemanticLabel: (i) => 'Sélectionner la carte $i',
  countLabelBuilder: (n) => '$n sélectionnée(s)',
  applyReportBuilder: (r) => 'Appliqué ${r.succeededCount}',
);

const _initial = ZFlashcard(id: 'a', question: 'Q0', answer: 'R0');

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 1000, height: 900, child: child),
      ),
    );

Widget _editor(
  _CommitSpy spy, {
  Map<ZFlashcardEditorField, ZFlashcardFieldBuilder>? fieldBuilders,
}) =>
    ZMultiFlashcardEditor(
      initialCards: const <ZFlashcard>[_initial],
      onCommit: spy.call,
      labels: _labels,
      fieldBuilders: fieldBuilders,
    );

/// Ouvre le volet détail sur la carte unique (tap sur son résumé de ligne).
Future<void> _focusCard(WidgetTester tester) async {
  await tester.tap(find.text('Q0'));
  await tester.pump();
}

/// Types des enfants DIRECTS de la colonne du formulaire de carte.
List<String> _formChildTypes(WidgetTester tester, Finder anchor) {
  final column = tester.widget<Column>(
    find.ancestor(of: anchor, matching: find.byType(Column)).first,
  );
  return column.children.map((w) => w.runtimeType.toString()).toList();
}

Future<List<ZFlashcard>> _commit(WidgetTester tester, _CommitSpy spy) async {
  await tester.tap(find.byKey(ZMultiFlashcardEditor.commitButtonKey));
  await tester.pumpAndSettle();
  return spy.payloads.last;
}

void main() {
  group('🔴 CR-IFFD-134 §1 — inertie ABSOLUE sans aucun slot', () {
    testWidgets(
        'arbre du formulaire FIGÉ : la liste des enfants est EXACTEMENT '
        'celle d\'avant le créneau', (tester) async {
      final spy = _CommitSpy();
      await tester.pumpWidget(_harness(_editor(spy)));
      await _focusCard(tester);

      // Liste FIGÉE — égalité stricte, jamais `contains` : un widget
      // d'enveloppe ajouté sur le chemin par défaut (ex. un `KeyedSubtree`
      // posé sans discernement) la fait rougir.
      expect(
        _formChildTypes(tester, find.byKey(const ValueKey<String>('z-card-question'))),
        equals(<String>[
          'TextField',
          'SizedBox',
          'TextField',
          'SizedBox',
          'TextField',
          'SizedBox',
          'TextField',
          'SizedBox',
          'ValueListenableBuilder<ZFlashcardType>',
        ]),
      );

      // Les quatre champs par défaut, et leurs propriétés.
      for (final entry in <String, String>{
        'z-card-question': 'Question',
        'z-card-answer': 'Réponse',
        'z-card-explanation': 'Explication',
        'z-card-hint': 'Indice',
      }.entries) {
        final field = tester.widget<TextField>(
          find.byKey(ValueKey<String>(entry.key)),
        );
        expect(field.textAlign, TextAlign.start,
            reason: 'AD-13 : alignement directionnel (${entry.key})');
        expect(field.decoration?.labelText, entry.value);
        expect(field.onChanged, isNotNull,
            reason: '🔴 le chemin par défaut publie par `onChanged`');
        expect(field.onEditingComplete, isNotNull);
      }
    });

    testWidgets(
        '🔴 AUCUNE écoute posée sur les controllers : une écriture '
        'programmatique ne publie RIEN sur le chemin par défaut',
        (tester) async {
      final spy = _CommitSpy();
      await tester.pumpWidget(_harness(_editor(spy)));
      await _focusCard(tester);

      final controller = tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('z-card-question')),
          )
          .controller!;
      // Sur le chemin par défaut, `TextField.onChanged` est le SEUL publieur.
      // Une écoute posée en plus doublerait la notification à chaque frappe :
      // cette écriture, qui ne passe pas par le champ, doit rester sans effet.
      controller.text = 'ÉCRITURE HORS CHAMP';
      await tester.pump();

      expect((await _commit(tester, spy)).single, equals(_initial),
          reason: '🔴 sans slot, rien n\'écoute le controller');
    });

    testWidgets('une frappe publie EXACTEMENT la carte attendue',
        (tester) async {
      final spy = _CommitSpy();
      await tester.pumpWidget(_harness(_editor(spy)));
      await _focusCard(tester);

      await tester.enterText(
          find.byKey(const ValueKey<String>('z-card-question')), 'Q1');
      await tester.pump();

      expect((await _commit(tester, spy)).single,
          equals(_initial.copyWith(question: 'Q1')));
    });
  });

  group('🔴 CR-IFFD-134 §2 — le créneau remplace le champ visé, et lui seul',
      () {
    testWidgets('slot sur `question` ⇒ widget hôte rendu, 3 champs par défaut',
        (tester) async {
      final spy = _CommitSpy();
      final seen = <ZFlashcardEditorField>[];
      final labelsSeen = <String>[];
      await tester.pumpWidget(_harness(_editor(
        spy,
        fieldBuilders: <ZFlashcardEditorField, ZFlashcardFieldBuilder>{
          ZFlashcardEditorField.question: (context, slot) {
            seen.add(slot.field);
            labelsSeen.add(slot.label);
            return const Text('ÉDITEUR RICHE HÔTE');
          },
        },
      )));
      await _focusCard(tester);

      expect(find.text('ÉDITEUR RICHE HÔTE'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('z-card-question')),
          findsOneWidget,
          reason: 'la clé du champ reste portée par le slot (identité stable)');
      expect(
        tester.widget(find.byKey(const ValueKey<String>('z-card-question'))),
        isA<KeyedSubtree>(),
        reason: '🔴 le `TextField` par défaut a bien CÉDÉ la place',
      );
      // Les trois autres champs restent des `TextField` par défaut.
      for (final key in <String>[
        'z-card-answer',
        'z-card-explanation',
        'z-card-hint',
      ]) {
        expect(tester.widget(find.byKey(ValueKey<String>(key))),
            isA<TextField>(), reason: '$key non visé ⇒ inchangé');
      }
      expect(seen, equals(<ZFlashcardEditorField>[
        ZFlashcardEditorField.question,
      ]));
      expect(labelsSeen, equals(<String>['Question']),
          reason: 'le libellé LOCALISÉ injecté est transmis tel quel');
    });

    testWidgets(
        '🔴 discriminant STABLE : une fabrique PARTAGÉE distingue les 4 champs '
        'sans lire le libellé', (tester) async {
      final spy = _CommitSpy();
      final byField = <ZFlashcardEditorField, TextEditingController>{};
      ZFlashcardFieldBuilder shared() => (context, slot) {
            byField[slot.field] = slot.controller;
            return Text('slot:${slot.field.name}');
          };
      await tester.pumpWidget(_harness(_editor(
        spy,
        fieldBuilders: <ZFlashcardEditorField, ZFlashcardFieldBuilder>{
          for (final f in ZFlashcardEditorField.values) f: shared(),
        },
      )));
      await _focusCard(tester);

      expect(byField.keys.toSet(), equals(ZFlashcardEditorField.values.toSet()));
      // Chaque champ reçoit SON controller — jamais deux fois le même.
      expect(byField.values.toSet().length, 4);
      // Le controller reçu porte bien la valeur de SON champ.
      expect(byField[ZFlashcardEditorField.question]!.text, 'Q0');
      expect(byField[ZFlashcardEditorField.answer]!.text, 'R0');
      expect(byField[ZFlashcardEditorField.explanation]!.text, '');
      expect(byField[ZFlashcardEditorField.hint]!.text, '');
      expect(find.text('slot:question'), findsOneWidget);
      expect(find.text('slot:hint'), findsOneWidget);
    });

    testWidgets('AD-2 : le controller remis au slot est STABLE au rebuild',
        (tester) async {
      final spy = _CommitSpy();
      final received = <TextEditingController>[];
      // Fabrique NEUVE à chaque construction de l'arbre : l'égalité de
      // controller ne peut donc pas venir d'une closure mémoïsée.
      Widget build() => _harness(_editor(
            spy,
            fieldBuilders: <ZFlashcardEditorField, ZFlashcardFieldBuilder>{
              ZFlashcardEditorField.question: (context, slot) {
                received.add(slot.controller);
                return const SizedBox.shrink();
              },
            },
          ));

      await tester.pumpWidget(build());
      await _focusCard(tester);
      final first = received.first;
      // Une frappe est SEEDÉE dans le controller de l'hôte avant le rebuild :
      // un controller recréé la perdrait.
      first.text = 'SAISIE EN COURS';
      await tester.pump();

      // Reconstruction de l'arbre (nouvelle instance de widget, même clé).
      await tester.pumpWidget(build());
      await tester.pump();

      expect(received.length, greaterThan(1),
          reason: 'le slot a bien été reconstruit');
      expect(identical(received.last, first), isTrue,
          reason: '🔴 AD-2 : jamais recréé au rebuild');
      expect(received.last.text, 'SAISIE EN COURS');
      expect((await _commit(tester, spy)).single.question, 'SAISIE EN COURS',
          reason: '🔴 le rebuild ne doit pas perdre la saisie de l\'hôte');
    });
  });

  group('🔴 CR-IFFD-134 §3 — la saisie de l\'hôte atteint la carte', () {
    testWidgets(
        '🔴 écrire dans le controller REÇU par le slot publie la valeur '
        'jusqu\'à la carte commitée', (tester) async {
      final spy = _CommitSpy();
      late TextEditingController hostController;
      await tester.pumpWidget(_harness(_editor(
        spy,
        fieldBuilders: <ZFlashcardEditorField, ZFlashcardFieldBuilder>{
          ZFlashcardEditorField.question: (context, slot) {
            hostController = slot.controller;
            return const SizedBox.shrink();
          },
        },
      )));
      await _focusCard(tester);

      // L'hôte écrit dans SON éditeur riche ⇒ le controller reçu.
      hostController.text = 'FORMULE \$\$x^2\$\$';
      await tester.pump();

      expect((await _commit(tester, spy)).single.question, 'FORMULE \$\$x^2\$\$',
          reason: '🔴 sans écoute, la saisie de l\'hôte serait PERDUE');
    });

    // NON GARDÉ, et dit honnêtement : `_ZCardFormState._lastText` évite de
    // publier quand un `TextEditingController` notifie sans que le TEXTE
    // change (déplacement du curseur). Cette économie n'est PAS observable
    // depuis la surface publique — une publication à vide repose la MÊME
    // carte, laisse `isDirty` inchangé et ne reconstruit rien. Une garde
    // écrite ici serait tautologique : mesuré, le retrait du garde-fou dans
    // `lib/` laisse la suite VERTE (injection R3 « publication à vide »).
    // Elle n'est donc pas écrite plutôt que d'être écrite fausse.

    testWidgets(
        '🔴 `slot.onEditingComplete` publie ET rafraîchit l\'aperçu',
        (tester) async {
      final spy = _CommitSpy();
      late ZFlashcardFieldSlot captured;
      await tester.pumpWidget(_harness(_editor(
        spy,
        fieldBuilders: <ZFlashcardEditorField, ZFlashcardFieldBuilder>{
          ZFlashcardEditorField.question: (context, slot) {
            captured = slot;
            return const SizedBox.shrink();
          },
        },
      )));
      await _focusCard(tester);

      // L'aperçu montre encore la valeur initiale.
      expect(
        tester
            .widget<ZFlashcardReviewCard>(
              find.byKey(const ValueKey<String>('z-multi-editor-preview')),
            )
            .card
            .question,
        'Q0',
      );

      captured.controller.value =
          const TextEditingValue(text: 'Q FIN DE SAISIE');
      captured.onEditingComplete();
      await tester.pump();

      expect(
        tester
            .widget<ZFlashcardReviewCard>(
              find.byKey(const ValueKey<String>('z-multi-editor-preview')),
            )
            .card
            .question,
        'Q FIN DE SAISIE',
        reason: '🔴 la voie de fin de saisie du champ par défaut est exposée',
      );
      expect((await _commit(tester, spy)).single.question, 'Q FIN DE SAISIE');
    });

    testWidgets(
        '🔴 slot RETIRÉ : le champ par défaut revient et AUCUNE écoute '
        'résiduelle ne double la publication', (tester) async {
      final spy = _CommitSpy();
      late TextEditingController hostController;
      Widget build(bool withSlot) => _harness(_editor(
            spy,
            fieldBuilders: withSlot
                ? <ZFlashcardEditorField, ZFlashcardFieldBuilder>{
                    ZFlashcardEditorField.question: (context, slot) {
                      hostController = slot.controller;
                      return const SizedBox.shrink();
                    },
                  }
                : null,
          ));

      await tester.pumpWidget(build(true));
      await _focusCard(tester);
      final captured = hostController;

      // L'hôte retire son éditeur riche : le champ par défaut reprend la main.
      await tester.pumpWidget(build(false));
      await tester.pump();
      expect(tester.widget(find.byKey(const ValueKey<String>('z-card-question'))),
          isA<TextField>());

      // Écoute résiduelle ? Le controller est le MÊME objet (AD-2) : une
      // écriture programmatique doit redevenir sans effet.
      expect(
        identical(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey<String>('z-card-question')),
              )
              .controller,
          captured,
        ),
        isTrue,
      );
      captured.text = 'ÉCRITURE HORS CHAMP';
      await tester.pump();

      expect((await _commit(tester, spy)).single, equals(_initial),
          reason: '🔴 l\'écoute doit avoir été RETIRÉE avec le slot');
    });
  });
}
