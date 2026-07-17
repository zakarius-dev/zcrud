/// AC7 — SM-1 / rebuilds granulaires (SU-2, NFR-SU2 — AD-2, **objectif produit
/// n°1**).
///
/// ⚠️ **Ce fichier SOLDE la dette L1 du code-review de su-1** : la « vraie garde
/// SM-1 » (*aucune closure réallouée à chaque build*) y avait été **explicitement
/// déférée à su-2**, faute de call-site de production. `ZFlashcardReviewCard` est
/// ce call-site.
///
/// Les assertions portent sur du **code de production réellement exercé** :
/// - l'identité du builder résolu **que `build` emprunte** (`resolvedContentBuilder`) ;
/// - l'identité d'une **instance de widget stable** au travers d'une révélation ;
/// - l'**absence de `setState`** dans la source de production (garde de source).
///
/// Accès `dart:io` (garde de source) ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

const ZFlashcard _card = ZFlashcard(question: 'Q', answer: 'A');
const ZFlashcard _other = ZFlashcard(question: 'Q2', answer: 'A2');

Future<void> _pump(
  WidgetTester tester, {
  ZFlashcard card = _card,
  ZFlashcardContentBuilder? contentBuilder,
  VoidCallback? onEdit,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: ZFlashcardReviewCard(
                card: card,
                contentBuilder: contentBuilder,
                onEdit: onEdit,
              ),
            ),
          ),
        ),
      ),
    );

ZFlashcardReviewCard _cardWidget(WidgetTester tester) =>
    tester.widget<ZFlashcardReviewCard>(find.byType(ZFlashcardReviewCard));

void main() {
  group('AC7 — aucune closure réallouée : le défaut est un TEAR-OFF statique', () {
    testWidgets(
      'resolvedContentBuilder est IDENTIQUE entre deux builds successifs '
      '(solde de la dette L1)',
      (tester) async {
        // 🔴 LE discriminant déféré par su-1. Une résolution écrite
        // `?? (c, s) => ZFlashcardDefaultContent(content: s)` allouerait une
        // closure NEUVE à chaque build : son identité changerait, la stabilité
        // des rebuilds serait cassée — et CE test rougirait.
        await _pump(tester);
        final first = _cardWidget(tester).resolvedContentBuilder;

        await _pump(tester); // rebuild complet
        final second = _cardWidget(tester).resolvedContentBuilder;

        expect(identical(first, second), isTrue,
            reason: 'le builder par défaut est RÉALLOUÉ à chaque build : ce '
                'n\'est pas un tear-off statique (AD-2/SM-1)');
      },
    );

    testWidgets('le tear-off résolu EST celui de su-1 (aucun défaut concurrent)',
        (tester) async {
      // Prouve que la carte CONSOMME le défaut de su-1 plutôt que d'en
      // réinventer un — une seconde source de défaut divergerait en silence.
      await _pump(tester);

      expect(
        identical(
          _cardWidget(tester).resolvedContentBuilder,
          ZFlashcardDefaultContent.builder,
        ),
        isTrue,
        reason: 'la carte n\'utilise pas ZFlashcardDefaultContent.builder',
      );
    });

    testWidgets('un builder INJECTÉ est rendu tel quel (jamais ré-enveloppé)',
        (tester) async {
      // Une ré-enveloppe (`(c, s) => injected(c, s)`) casserait l'identité tout
      // autant qu'une closure de défaut.
      await _pump(tester, contentBuilder: _sentinel);

      expect(identical(_cardWidget(tester).resolvedContentBuilder, _sentinel),
          isTrue,
          reason: 'le builder injecté est ré-enveloppé dans une closure : son '
              'identité change à chaque build');
    });
  });

  group('AC7 — la révélation ne reconstruit QUE la tranche de face', () {
    testWidgets(
      'le sous-arbre STABLE de la carte survit à la révélation, à l\'IDENTIQUE',
      (tester) async {
        // La rangée d'actions est un SIBLING du ValueListenableBuilder : si la
        // révélation passait par un `setState` de carte, `build` re-rentrerait
        // et en construirait une INSTANCE NEUVE. Son identité est donc une
        // mesure directe de « la carte entière s'est-elle reconstruite ? ».
        await _pump(tester, onEdit: () {});
        final before =
            tester.widget(find.byKey(ZFlashcardReviewCard.actionsKey));

        await tester.tap(find.byType(ZFlashcardReviewCard));
        await tester.pumpAndSettle();
        expect(find.text('A'), findsOneWidget); // la révélation a bien eu lieu

        final after =
            tester.widget(find.byKey(ZFlashcardReviewCard.actionsKey));

        expect(identical(before, after), isTrue,
            reason: 'le sous-arbre stable a été RECONSTRUIT par la révélation : '
                'la carte utilise un setState global au lieu du '
                'ValueListenableBuilder (AD-2, objectif produit n°1)');
      },
    );

    testWidgets(
      'CONTRE-PREUVE — la sonde d\'identité a du POUVOIR : un vrai rebuild de '
      'la carte, lui, PRODUIT une instance neuve',
      (tester) async {
        // Sans ce cas, l'assertion `identical` ci-dessus resterait verte même si
        // la sonde comparait deux fois la même référence gelée.
        await _pump(tester, onEdit: () {});
        final before =
            tester.widget(find.byKey(ZFlashcardReviewCard.actionsKey));

        await _pump(tester, onEdit: () {}); // rebuild RÉEL du parent
        final after =
            tester.widget(find.byKey(ZFlashcardReviewCard.actionsKey));

        expect(identical(before, after), isFalse,
            reason: 'la sonde ne distingue PAS un rebuild réel : elle ne prouve '
                'rien sur la granularité');
      },
    );
  });

  group('AC7 — discriminant (1) : le contentBuilder n\'est PAS ré-invoqué à '
      'chaque FRAME', () {
    // 🔴 LA sonde prescrite par AC7 (« une sonde de comptage dans le
    // `contentBuilder` injecté prouve que la révélation ne reconstruit pas le
    // sous-arbre stable ») — elle était ABSENTE. La sonde livrée mesurait
    // l'identité de la RANGÉE D'ACTIONS, un sibling situé HORS de
    // l'`AnimatedBuilder` : structurellement incapable de voir ce chemin.
    //
    // Le défaut réel : `AnimatedBuilder` jetait son `child:` ⇒ le contenu était
    // reconstruit à chaque tick (~17 fois par révélation sur une carte simple,
    // 153 sur un QCM 8 choix + explication). Sur le chemin markdown d'AC6, cela
    // fait autant de `md.Document` + `MarkdownToDelta.convert` + `jsonEncode`
    // par flip — tous jetés par une déduplication qui n'arrive qu'APRÈS le coût.

    testWidgets(
      'une révélation complète ne construit le contenu qu\'un nombre BORNÉ de '
      'fois (et non une fois par frame)',
      (tester) async {
        var builds = 0;
        Widget probe(BuildContext context, String content) {
          builds++;
          return Text(content);
        }

        await _pump(tester, contentBuilder: probe);
        final apresMontage = builds;

        await tester.tap(find.byType(ZFlashcardReviewCard));
        await tester.pumpAndSettle(); // TOUTES les frames du flip (250 ms)

        final pendantRevelation = builds - apresMontage;

        // Une révélation change la face UNE fois (au franchissement de la
        // mi-course) : le contenu se reconstruit donc un nombre CONSTANT de
        // fois, indépendant du nombre de frames. Le seuil est volontairement
        // large (tolérance aux détails de rebuild) tout en restant très en
        // dessous du régime « une construction par tick » (~17).
        expect(pendantRevelation, lessThanOrEqualTo(6),
            reason: 'le contenu est reconstruit $pendantRevelation fois par '
                'révélation : l\'`AnimatedBuilder` jette son `child:` et '
                'rebuild le contenu à CHAQUE FRAME (AD-2/SM-1, objectif '
                'produit n°1). Sur le chemin markdown, c\'est un re-parse '
                'complet par frame.');
        expect(find.text('A'), findsOneWidget,
            reason: 'la révélation n\'a pas eu lieu : la sonde ne mesure rien');
      },
    );

    testWidgets(
      'le coût NE CROÎT PAS avec le nombre de frames : une transition 4× plus '
      'longue ne construit PAS 4× plus de contenu',
      (tester) async {
        // ⚠️ LE discriminant structurel. Un seuil absolu peut toujours être
        // « ajusté » ; ce cas-ci compare deux régimes du MÊME widget et ne peut
        // être satisfait QUE si le contenu est hors de la boucle de frames :
        // avec un rebuild par tick, allonger la durée multiplie mécaniquement
        // le compteur.
        Future<int> compte(Duration duree) async {
          var builds = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 400,
                    child: ZFlashcardReviewCard(
                      card: _card,
                      transitionDuration: duree,
                      contentBuilder: (BuildContext context, String content) {
                        builds++;
                        return Text(content);
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          final apresMontage = builds;
          await tester.tap(find.byType(ZFlashcardReviewCard));
          await tester.pumpAndSettle();
          return builds - apresMontage;
        }

        final court = await compte(const Duration(milliseconds: 200));
        final long = await compte(const Duration(milliseconds: 800));

        expect(long, court,
            reason: 'une transition 4× plus longue construit le contenu $long '
                'fois contre $court : le nombre de constructions suit le nombre '
                'de FRAMES — le contenu vit dans le `builder:` de '
                'l\'`AnimatedBuilder` au lieu de son `child:` (SM-1)');
      },
    );

    testWidgets(
      'CONTRE-PREUVE — la sonde a du POUVOIR : elle COMPTE bien les '
      'constructions réelles du contenu',
      (tester) async {
        // Sans ce cas, les bornes ci-dessus resteraient vertes si la sonde
        // n'était jamais appelée (compteur gelé à 0 ⇒ tout seuil satisfait).
        var builds = 0;
        Widget probe(BuildContext context, String content) {
          builds++;
          return Text(content);
        }

        await _pump(tester, contentBuilder: probe);

        expect(builds, greaterThan(0),
            reason: 'la sonde n\'est JAMAIS invoquée : elle ne mesure rien et '
                'les seuils ci-dessus ne prouvent RIEN');
      },
    );
  });

  group('AC7 — changer de carte réinitialise la révélation', () {
    testWidgets('une carte suivante ne s\'ouvre JAMAIS réponse déjà révélée',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);

      // Nouvelle carte, MÊME State (didUpdateWidget) — bug fonctionnel réel si
      // la révélation persistait.
      await _pump(tester, card: _other);
      await tester.pumpAndSettle();

      expect(find.text('Q2'), findsOneWidget,
          reason: 'la carte suivante s\'ouvre RÉPONSE RÉVÉLÉE : la révélation '
              'n\'est pas réinitialisée dans didUpdateWidget');
      expect(find.text('A2'), findsNothing);
    });

    testWidgets('la carte réinitialisée reste révélable', (tester) async {
      await _pump(tester);
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();

      await _pump(tester, card: _other);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();

      expect(find.text('A2'), findsOneWidget,
          reason: 'le reset a laissé le controller dans un état incohérent');
    });

    testWidgets('un rebuild avec la MÊME carte ne réinitialise PAS', (tester) async {
      // Discriminant inverse : réinitialiser à chaque rebuild ferait « retomber »
      // la carte sur sa question au moindre rebuild du parent.
      await _pump(tester);
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();

      await _pump(tester); // même carte
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget,
          reason: 'la révélation est perdue au rebuild : le reset se déclenche '
              'trop largement');
    });
  });

  group('AC7 — l\'état de révélation est NOTIFIÉ sans être cédé', () {
    Future<void> pumpAvecEcoute(
      WidgetTester tester,
      List<bool> events, {
      ZFlashcard card = _card,
    }) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: ZFlashcardReviewCard(
                    card: card,
                    onRevealChanged: events.add,
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('onRevealChanged reçoit chaque bascule', (tester) async {
      final events = <bool>[];
      await pumpAvecEcoute(tester, events);

      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();

      expect(events, <bool>[true, false]);
    });

    testWidgets(
      '🔴 D6 — le RESET de carte notifie aussi (les DEUX voies notifient)',
      (tester) async {
        // Le dartdoc promet une notification « à chaque bascule » ; seul le tap
        // l'honorait. Scénario réel (su-4) : l'apprenant révèle la carte A ⇒
        // l'hôte reçoit `true` et affiche `ZSrsQualityButtons`. Le swipe amène
        // la carte B : la face repart sur QUESTION mais l'hôte n'est pas
        // prévenu ⇒ il croit toujours `revealed == true` ⇒ les boutons de
        // notation s'affichent sur une carte NON révélée, et l'apprenant note
        // une carte dont il n'a pas vu la réponse — écriture SRS faussée.
        final events = <bool>[];
        await pumpAvecEcoute(tester, events);

        await tester.tap(find.byType(ZFlashcardReviewCard));
        await tester.pumpAndSettle();
        expect(events, <bool>[true]);

        // Carte suivante ⇒ la révélation retombe : l'hôte DOIT l'apprendre.
        await pumpAvecEcoute(tester, events, card: _other);
        await tester.pumpAndSettle();

        expect(events, <bool>[true, false],
            reason: 'le reset de carte remet la face sur QUESTION SANS notifier '
                'l\'hôte : son état diverge silencieusement du nôtre');
      },
    );

    testWidgets(
      'le reset ne notifie PAS quand rien ne bascule (aucun faux événement)',
      (tester) async {
        // Discriminant inverse : notifier inconditionnellement au changement de
        // carte noierait l'hôte de `false` redondants sur chaque carte non
        // révélée — et lui ferait croire à une bascule qui n'a pas eu lieu.
        final events = <bool>[];
        await pumpAvecEcoute(tester, events);

        await pumpAvecEcoute(tester, events, card: _other);
        await tester.pumpAndSettle();

        expect(events, isEmpty,
            reason: 'un `false` est émis alors que la carte n\'était pas '
                'révélée : la notification ne suit pas un CHANGEMENT réel');
      },
    );

    testWidgets(
      'la notification du reset ne casse PAS un hôte qui réagit par setState',
      (tester) async {
        // `didUpdateWidget` s'exécute PENDANT le build du parent : notifier
        // synchroniquement y ferait planter tout hôte qui appelle `setState`
        // dans `onRevealChanged` (« setState() called during build ») — un
        // hôte parfaitement légitime.
        var revealed = false;
        var card = _card;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) =>
                        Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ZFlashcardReviewCard(
                          card: card,
                          onRevealChanged: (bool v) =>
                              setState(() => revealed = v),
                        ),
                        TextButton(
                          onPressed: () => setState(() => card = _other),
                          child: const Text('suivante'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ZFlashcardReviewCard));
        await tester.pumpAndSettle();
        expect(revealed, isTrue);

        await tester.tap(find.text('suivante'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'la notification du reset est émise PENDANT le build : un '
                'hôte qui réagit par setState plante');
        expect(revealed, isFalse,
            reason: 'l\'hôte n\'a pas appris que la révélation est retombée');
      },
    );
  });

  group('AC7 — garde de source : AUCUN setState à l\'échelle de la carte', () {
    test(
      'la source de ZFlashcardReviewCard ne contient AUCUN setState (AD-2)',
      () {
        // Garde de SOURCE assumée : elle ne remplace pas les sondes d'identité
        // ci-dessus, elle ferme la porte à la RÉINTRODUCTION d'un setState que
        // ces sondes pourraient ne pas couvrir sur un futur chemin.
        final source = File('lib/src/presentation/z_flashcard_review_card.dart');
        expect(source.existsSync(), isTrue,
            reason: 'source introuvable (cwd = ${Directory.current.path})');

        final lines = source.readAsLinesSync();
        expect(lines, isNotEmpty, reason: 'fichier vide — rien scanné (R12)');

        final offenders = <String>[];
        for (var i = 0; i < lines.length; i++) {
          final trimmed = lines[i].trimLeft();
          if (trimmed.startsWith('///') || trimmed.startsWith('//')) {
            continue; // la prose DOIT pouvoir nommer setState pour l'interdire
          }
          if (trimmed.contains('setState')) {
            offenders.add('${source.path}:${i + 1} → « $trimmed »');
          }
        }

        expect(offenders, isEmpty,
            reason: 'setState à l\'échelle de la carte (AD-2, objectif produit '
                'n°1) : la révélation doit passer par le ValueNotifier '
                'stable :\n${offenders.join('\n')}');

        // Contre-preuve R12 : le scan voit bel et bien le code de production —
        // sinon le vert ci-dessus ne prouverait rien.
        expect(
          lines.any((l) => l.contains('ValueListenableBuilder')),
          isTrue,
          reason: 'le scan ne voit pas le code de production attendu : il est '
              'aveugle, donc l\'absence de setState ne prouve RIEN',
        );
      },
    );
  });
}

/// Sentinelle **tear-off statique** — jamais une closure allouée par le test :
/// cela masquerait précisément la garde que ce fichier installe.
Widget _sentinel(BuildContext context, String content) => Text('INJ:$content');
