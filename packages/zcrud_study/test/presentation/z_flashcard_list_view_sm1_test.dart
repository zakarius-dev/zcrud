// SM-1 (objectif produit n°1) — taper ne reconstruit QUE le champ (SU-8/AC18).
//
// 🔴 « Preuve par COMPTEUR, jamais par opinion » : les sondes comptent les
// rebuilds RÉELS de la liste et du champ. Un test qui n'assérerait que « ça ne
// crashe pas » laisserait passer le bug historique n°1 de zcrud — le formulaire
// entier reconstruit à chaque frappe (jank, perte de focus).
//
// La liste peut porter des MILLIERS de cartes : chaque rebuild superflu
// re-filtre, re-trie et re-construit des tuiles. C'est la raison d'être du
// débounce + de la `ValueListenable` ciblée.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

const _labels = ZFlashcardListLabels(
  searchHint: 'Rechercher',
  searchFieldLabel: 'Champ de recherche',
  emptyState: 'Aucune carte',
  noResults: 'Aucun résultat',
  actionsMenuTooltip: 'Actions',
  openAction: 'Ouvrir',
  editAction: 'Modifier',
  deleteAction: 'Supprimer',
  duplicateAction: 'Dupliquer',
  moveUpAction: 'Monter',
  moveDownAction: 'Descendre',
  generateWithAiAction: 'Générer avec IA',  readOnlyBadge: 'Lecture seule',
);

/// Débounce COURT et déterministe (le test contrôle l'horloge via `pump`).
const _debounce = Duration(milliseconds: 100);

/// Les **100 caractères** tapés par le test phare (AC18 verbatim).
///
/// 🔴 Ils sont contenus dans la question de **chaque** carte du harnais : tout
/// préfixe tapé MATCHE donc, et la liste reste **peuplée** pendant toute la
/// frappe. Sans cela, le filtre viderait la liste, aucune tuile ne serait
/// construite, et le compteur resterait à 0 **même sans débounce** — la sonde
/// serait infalsifiable.
/// (Longueur **mesurée**, jamais estimée — la sonde `text.length == 100` du test
/// a rejeté deux écritures « à peu près 100 ».)
const String _typed = 'lorem ipsum dolor sit amet consectetur adipiscing elit sed do'
    ' eiusmod tempor incididunt ut labore et';

ZFlashcard _card(String id) => ZFlashcard(id: id, question: 'Question $id');

/// Sonde de comptage : compte les `build` de son sous-arbre.
///
/// 🔴 **RÉELLEMENT BRANCHÉE** : elle enveloppe le `contentBuilder` de la vue, qui
/// est appelé pour CHAQUE tuile construite. Un espion jamais branché serait
/// infalsifiable (défaut démasqué sur su-4).
class _Counter {
  int tileBuilds = 0;
  void reset() => tileBuilds = 0;
}

Widget _harness({
  required List<ZFlashcard> cards,
  required _Counter counter,
  Duration debounce = _debounce,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1200,
          height: 800,
          child: ZFlashcardListView(
            cards: cards,
            labels: _labels,
            searchDebounce: debounce,
            contentBuilder: (context, text) {
              counter.tileBuilds++;
              return Text(text);
            },
          ),
        ),
      ),
    );

void main() {
  group('🔴 AC18/SM-1 — taper 100 caractères ne reconstruit QUE le champ', () {
    testWidgets(
      '🔴 100 caractères ⇒ rebuilds de liste BORNÉS (débounce), focus CONSERVÉ',
      (tester) async {
        final counter = _Counter();

        // 🔴 Les cartes DOIVENT matcher chaque préfixe tapé, sinon la liste
        // tombe en « aucun résultat » et le compteur reste à 0 **quel que soit**
        // le débounce — la sonde ne mesurerait RIEN et le test serait vert même
        // débounce supprimé. (Défaut réel de la 1re écriture, démasqué par
        // l'injection R3.)
        final cards = List<ZFlashcard>.generate(
          30,
          (i) => ZFlashcard(id: 'c$i', question: '$_typed — carte $i'),
        );
        await tester.pumpWidget(_harness(cards: cards, counter: counter));
        await tester.pump();

        // Focus réel sur le champ (comme un utilisateur qui clique dedans).
        await tester.tap(find.byKey(ZFlashcardListView.searchFieldKey));
        await tester.pump();

        final field = tester.widget<TextField>(
            find.byKey(ZFlashcardListView.searchFieldKey));
        expect(field.focusNode?.hasFocus ?? primaryFocus != null, isTrue,
            reason: 'sonde : le champ doit avoir le focus AVANT la frappe');

        counter.reset();

        // 🔴 100 caractères, frappe soutenue (chaque frappe < débounce).
        const text = _typed;
        expect(text.length, 100, reason: 'sonde : exactement 100 caractères');

        for (var i = 1; i <= text.length; i++) {
          await tester.enterText(
            find.byKey(ZFlashcardListView.searchFieldKey),
            text.substring(0, i),
          );
          // Frappe RAPIDE : sous le seuil de débounce ⇒ aucun recalcul.
          await tester.pump(const Duration(milliseconds: 10));
        }

        final duringTyping = counter.tileBuilds;
        expect(
          duringTyping,
          0,
          reason: '🔴 SM-1 : $duringTyping rebuilds de tuile PENDANT la frappe. '
              'Le débounce doit absorber une rafale : la liste ne se recalcule '
              'qu\'au REPOS. Sans lui, 100 frappes × 30 tuiles = 3 000 '
              'constructions — le jank historique que zcrud corrige par '
              'conception.',
        );

        // 🔴 Au repos : le recalcul a lieu, UNE fois — et il construit des
        // tuiles RÉELLES. C'est ce qui rend le « 0 » ci-dessus significatif :
        // sans cette assertion, « 0 rebuild » serait aussi vrai d'une liste
        // MORTE (le défaut « fonctionnalité morte sur son chemin documenté »).
        await tester.pump(_debounce);
        await tester.pump();
        expect(counter.tileBuilds, greaterThan(0),
            reason: '🔴 le recalcul débouncé n\'a JAMAIS eu lieu ⇒ la recherche '
                'est morte, et le « 0 pendant la frappe » ne prouvait rien');
        expect(find.textContaining('carte 0'), findsOneWidget,
            reason: 'les cartes matchent bien la saisie (sonde du harnais)');

        // 🔴 Le focus n'a JAMAIS été perdu (le bug historique n°1).
        expect(
          tester
                  .widget<TextField>(
                      find.byKey(ZFlashcardListView.searchFieldKey))
                  .controller
                  ?.text ??
              '',
          text,
          reason: '🔴 la saisie complète est intacte — un controller recréé au '
              'rebuild aurait tronqué le texte et fait sauter le curseur',
        );
        expect(primaryFocus?.hasFocus, isTrue,
            reason: '🔴 ZÉRO perte de focus après 100 caractères');
      },
    );

    testWidgets(
      '🔴 le CHAMP n\'est PAS reconstruit par la frappe (controller STABLE)',
      (tester) async {
        final counter = _Counter();
        await tester.pumpWidget(
            _harness(cards: <ZFlashcard>[_card('c1')], counter: counter));
        await tester.pump();

        final controllerBefore = tester
            .widget<TextField>(find.byKey(ZFlashcardListView.searchFieldKey))
            .controller;

        for (final s in <String>['a', 'ab', 'abc']) {
          await tester.enterText(
              find.byKey(ZFlashcardListView.searchFieldKey), s);
          await tester.pump(const Duration(milliseconds: 10));
        }
        await tester.pump(_debounce);
        await tester.pump();

        final controllerAfter = tester
            .widget<TextField>(find.byKey(ZFlashcardListView.searchFieldKey))
            .controller;

        expect(identical(controllerBefore, controllerAfter), isTrue,
            reason: '🔴 AD-2 : le `TextEditingController` doit être STABLE '
                '(créé une fois, disposé). Le recréer au rebuild PERDRAIT le '
                'focus et la sélection à chaque frappe — le bug n°1');
      },
    );

    testWidgets(
      '🔴 une rafale ⇒ UN SEUL recalcul (pas un par caractère)',
      (tester) async {
        final counter = _Counter();
        // 3 cartes, toutes retenues par « Question » ⇒ chaque recalcul est
        // visible dans le compteur (3 tuiles par passe).
        final cards = <ZFlashcard>[_card('c1'), _card('c2'), _card('c3')];
        await tester.pumpWidget(_harness(cards: cards, counter: counter));
        await tester.pump();
        counter.reset();

        // 10 frappes rapides.
        for (var i = 1; i <= 10; i++) {
          await tester.enterText(
              find.byKey(ZFlashcardListView.searchFieldKey),
              'Question'.substring(0, (i % 8) + 1));
          await tester.pump(const Duration(milliseconds: 5));
        }
        expect(counter.tileBuilds, 0, reason: 'rien pendant la rafale');

        await tester.pump(_debounce);
        await tester.pump();

        expect(counter.tileBuilds, 3,
            reason: '🔴 UN SEUL recalcul (3 tuiles), pas 10 × 3 = 30. '
                '${counter.tileBuilds} ⇒ le débounce ne tient pas');
      },
    );

    testWidgets('la recherche débouncée FILTRE réellement (jamais décorative)',
        (tester) async {
      final counter = _Counter();
      final cards = <ZFlashcard>[
        ZFlashcard(id: 'a', question: 'Physique nucléaire'),
        ZFlashcard(id: 'b', question: 'Histoire romaine'),
      ];
      await tester.pumpWidget(_harness(cards: cards, counter: counter));
      await tester.pump();

      expect(find.text('Physique nucléaire'), findsOneWidget);
      expect(find.text('Histoire romaine'), findsOneWidget);

      await tester.enterText(
          find.byKey(ZFlashcardListView.searchFieldKey), 'physique');
      await tester.pump(_debounce);
      await tester.pump();

      expect(find.text('Physique nucléaire'), findsOneWidget,
          reason: '🔴 un débounce qui ne notifierait JAMAIS donnerait « 0 '
              'rebuild » (test SM-1 vert) sur une recherche MORTE');
      expect(find.text('Histoire romaine'), findsNothing);
    });

    testWidgets('🔴 recherche normalisée sur le chemin RÉEL de la vue (NFD)',
        (tester) async {
      final counter = _Counter();
      // 🔴 NFD EXPLICITE (\u) : É = E+U+0301, è = e+U+0300. La sonde garantit
      // que le corpus est RÉELLEMENT décomposé (un littéral collé est souvent
      // re-précomposé NFC en silence ⇒ ce test resterait vert le strip supprimé).
      const nfdEleve = 'E\u0301le\u0300ve studieux';
      expect(nfdEleve.runes.any((r) => r >= 0x300 && r <= 0x36F), isTrue,
          reason: 'sonde : le corpus doit porter une marque combinante (NFD réel)');
      final cards = <ZFlashcard>[
        ZFlashcard(id: 'a', question: nfdEleve), // NFD réel (cf. sonde)
        ZFlashcard(id: 'b', question: 'Professeur'),
      ];
      await tester.pumpWidget(_harness(cards: cards, counter: counter));
      await tester.pump();

      await tester.enterText(
          find.byKey(ZFlashcardListView.searchFieldKey), 'eleve');
      await tester.pump(_debounce);
      await tester.pump();

      expect(find.text(nfdEleve), findsOneWidget,
          reason: '🔴 la normalisation NFD doit s\'appliquer sur le chemin RÉEL '
              'de la vue, pas seulement en test unitaire de la fonction pure');
      expect(find.text('Professeur'), findsNothing);
    });
  });

  group('🔴 AC18 — cycle de vie du Timer (fuite réelle, pas théorique)', () {
    testWidgets('démonter PENDANT un débounce en vol ⇒ aucun throw', (tester) async {
      final counter = _Counter();
      await tester.pumpWidget(
          _harness(cards: <ZFlashcard>[_card('c1')], counter: counter));
      await tester.pump();

      // Frappe, puis démontage AVANT l'échéance du débounce.
      await tester.enterText(
          find.byKey(ZFlashcardListView.searchFieldKey), 'abc');
      await tester.pump(const Duration(milliseconds: 10));

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      // Laisse largement passer l'échéance : un Timer non annulé taperait ici,
      // sur un arbre MORT.
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull,
          reason: '🔴 `Timer` non annulé au dispose ⇒ `_query.value` sur un '
              'ValueNotifier DISPOSÉ ⇒ « A ValueNotifier was used after being '
              'disposed ». Fuite RÉELLE, pas théorique');
    });

    testWidgets('aucun Timer pendant après le dispose (pas de test en attente)',
        (tester) async {
      final counter = _Counter();
      await tester.pumpWidget(
          _harness(cards: <ZFlashcard>[_card('c1')], counter: counter));
      await tester.pump();
      await tester.enterText(
          find.byKey(ZFlashcardListView.searchFieldKey), 'x');
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(milliseconds: 500));
      // Si un Timer survivait, `flutter_test` ferait échouer le test à la fin
      // (« A Timer is still pending »). Le pump ci-dessus le déclencherait.
      expect(tester.takeException(), isNull);
    });
  });
}
