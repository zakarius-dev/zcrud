/// CR-IFFD-38 — la révélation de `ZFlashcardReviewCard` est **PILOTABLE** par
/// l'hôte.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// CE QUE CES GARDES MESURENT, ET CE QU'ELLES REFUSENT DE MESURER
///
/// L'hôte avait gelé son blocage par une garde qui comptait les occurrences du
/// texte `flipCardController:` sur tout son `lib/`, **déclarations comprises** :
/// elle serait restée **verte avec zéro passage réel**. Aucune garde d'ici ne
/// compte d'occurrence : chacune **monte l'arbre** et vérifie que la commande
/// **change ce qui est rendu**.
///
/// Les 4 sites vifs de l'hôte sont représentés :
/// - « Voir la réponse », bouton EXTERNE à la carte (face avant) ;
/// - « Masquer la réponse », posé par le PARENT sur la face arrière ;
/// - le tap sur la carte elle-même (chemin historique) ;
/// - le passage à la carte suivante (AC7), qui doit rester cohérent avec le
///   pilote.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

const ZFlashcard _q1 = ZFlashcard(question: 'Q1', answer: 'A1');
const ZFlashcard _q2 = ZFlashcard(question: 'Q2', answer: 'A2');

/// Hôte de référence : il POSSÈDE le contrôleur dans un champ de son `State`
/// (l'usage légal) et pose ses commandes **hors** de la carte — exactement la
/// topologie du mode apprentissage de l'hôte réel.
class _Host extends StatefulWidget {
  const _Host({
    this.card = _q1,
    this.onRevealChanged,
    this.initiallyRevealed = false,
    this.withController = true,
  });

  final ZFlashcard card;
  final ValueChanged<bool>? onRevealChanged;
  final bool initiallyRevealed;
  final bool withController;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with ZDisplayStateOwnerMixin {
  late final ZToggleController reveal = ZToggleController(
    owner: this,
    initialValue: widget.initiallyRevealed,
    debugLabel: 'reveal',
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              // Site 1 — « Voir la réponse », EXTERNE à la carte.
              TextButton(onPressed: reveal.set, child: const Text('VOIR')),
              // Site 4 — « Masquer la réponse », posé par le PARENT.
              TextButton(onPressed: reveal.clear, child: const Text('MASQUER')),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 400,
                    child: ZFlashcardReviewCard(
                      card: widget.card,
                      revealController: widget.withController ? reveal : null,
                      onRevealChanged: widget.onRevealChanged,
                      // Rend la rangée d'actions PRÉSENTE : c'est la sonde de
                      // stabilité d'instance de la garde SM-1 ci-dessous.
                      onEdit: () {},
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

_HostState _host(WidgetTester t) => t.state<_HostState>(find.byType(_Host));

void main() {
  group('SANS contrôleur — le comportement est STRICTEMENT inchangé', () {
    testWidgets('le tap révèle, et la notification est émise', (tester) async {
      final List<bool> seen = <bool>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: ZFlashcardReviewCard(
                card: _q1,
                onRevealChanged: seen.add,
              ),
            ),
          ),
        ),
      ));

      expect(find.text('Q1'), findsOneWidget);
      expect(find.text('A1'), findsNothing);

      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();

      expect(find.text('A1'), findsOneWidget,
          reason: 'le défaut interne DOIT rester le comportement actuel : '
              'c\'est le bon défaut pour la majorité des hôtes (AD-4)');
      expect(seen, <bool>[true]);
    });

    testWidgets('un contrôleur RETIRÉ ne fige pas la carte', (tester) async {
      // L'hôte a le droit de retirer son pilote : la carte doit alors
      // redevenir autonome, pas rester bloquée sur la dernière commande.
      await tester.pumpWidget(const _Host());
      await tester.tap(find.text('VOIR'));
      await tester.pumpAndSettle();
      expect(find.text('A1'), findsOneWidget);

      await tester.pumpWidget(const _Host(withController: false));
      await tester.pumpAndSettle();
      expect(find.text('A1'), findsOneWidget,
          reason: 'le repli interne doit REPRENDRE la valeur affichée');

      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();
      expect(find.text('Q1'), findsOneWidget,
          reason: 'la carte doit redevenir autonome après retrait du pilote');
    });
  });

  group('AVEC contrôleur — l\'hôte COMMANDE réellement la révélation', () {
    testWidgets('🔴 « Voir la réponse » (bouton EXTERNE) révèle la réponse',
        (tester) async {
      await tester.pumpWidget(const _Host());
      expect(find.text('Q1'), findsOneWidget);
      expect(find.text('A1'), findsNothing);

      await tester.tap(find.text('VOIR'));
      await tester.pumpAndSettle();

      // 🔴 LE défaut que la CR décrit : sans ce paramètre, ce bouton serait
      // « affiché, cliquable et sans effet ». La mesure porte donc sur l'ARBRE.
      expect(find.text('A1'), findsOneWidget,
          reason: 'commande MORTE : le bouton de l\'hôte ne fait rien');
      expect(find.text('Q1'), findsNothing);
    });

    testWidgets('🔴 « Masquer la réponse » (4e site, posé par le PARENT) '
        'referme la carte', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.tap(find.text('VOIR'));
      await tester.pumpAndSettle();
      expect(find.text('A1'), findsOneWidget);

      await tester.tap(find.text('MASQUER'));
      await tester.pumpAndSettle();

      expect(find.text('Q1'), findsOneWidget,
          reason: 'le 4e site de commande — omis par la CR — doit être servi');
      expect(find.text('A1'), findsNothing);
    });

    testWidgets('un contrôleur DÉJÀ révélé monte la carte face RÉPONSE',
        (tester) async {
      await tester.pumpWidget(const _Host(initiallyRevealed: true));
      await tester.pumpAndSettle();

      // Sans synchronisation de l'état visuel au montage, la carte afficherait
      // la question alors que sa source de vérité dit « réponse ».
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('Q1'), findsNothing);

      // 🔴 CE QUE LA MESURE PRÉCÉDENTE NE VOIT PAS. Le CONTENU affiché est
      // gouverné par la mi-course de la transition, l'ORIENTATION par la valeur
      // du controller d'animation. Une carte montée « contenu = réponse » mais
      // « animation = 0 » paraît juste (le texte est bon) et est pourtant dans
      // un état incohérent : la face arrière y est contre-rotée sans rotation
      // porteuse — elle s'affiche EN MIROIR — et le premier tap est INERTE,
      // parce qu'il déclenche un `reverse()` depuis une valeur déjà nulle.
      // C'est ce tap-là qui rend la propriété falsifiable.
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();
      expect(find.text('Q1'), findsOneWidget,
          reason: 'le premier tap sur une carte montée RÉVÉLÉE doit la '
              'refermer : s\'il est inerte, l\'état visuel initial n\'a pas '
              'été synchronisé sur la source de vérité');
      expect(find.text('A1'), findsNothing);
    });
  });

  group('Le contrôleur est LA SOURCE DE VÉRITÉ (aucun miroir)', () {
    testWidgets('🔴 le TAP sur la carte remonte dans le contrôleur de l\'hôte',
        (tester) async {
      await tester.pumpWidget(const _Host());
      final _HostState host = _host(tester);
      expect(host.reveal.value, isFalse);

      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();

      expect(find.text('A1'), findsOneWidget);
      expect(host.reveal.value, isTrue,
          reason: 'la carte a gardé un MIROIR : son état a divergé de la source '
              'de vérité, et le bouton « Masquer » de l\'hôte deviendrait faux');
    });

    testWidgets('🔴 après un tap, la commande de l\'hôte reste COHÉRENTE',
        (tester) async {
      // C'est le symptôme réel d'une divergence : un miroir laisserait
      // `reveal.value == false` après le tap, si bien que « VOIR » (qui écrit
      // `true`) serait un NO-OP et ne refermerait ni n'ouvrirait rien.
      await tester.pumpWidget(const _Host());
      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();

      await tester.tap(find.text('MASQUER'));
      await tester.pumpAndSettle();
      expect(find.text('Q1'), findsOneWidget,
          reason: 'l\'hôte doit pouvoir reprendre la main après un geste '
              'utilisateur — sinon les deux chemins divergent');
    });

    testWidgets('AC7 — la carte SUIVANTE remet le PILOTE en face question',
        (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.tap(find.text('VOIR'));
      await tester.pumpAndSettle();
      expect(_host(tester).reveal.value, isTrue);

      await tester.pumpWidget(const _Host(card: _q2));
      await tester.pumpAndSettle();

      expect(find.text('Q2'), findsOneWidget,
          reason: 'AC7 : la carte suivante s\'ouvre en face QUESTION');
      expect(_host(tester).reveal.value, isFalse,
          reason: 'le reset AC7 doit être ÉCRIT dans la source de vérité : '
              'sinon l\'hôte croit la réponse affichée et le bouton « Masquer » '
              'devient inerte sur la carte suivante');
    });
  });

  group('La notification sortante est CONSERVÉE', () {
    testWidgets('🔴 une commande EXTERNE notifie aussi `onRevealChanged`',
        (tester) async {
      final List<bool> seen = <bool>[];
      await tester.pumpWidget(_Host(onRevealChanged: seen.add));

      await tester.tap(find.text('VOIR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MASQUER'));
      await tester.pumpAndSettle();

      expect(seen, <bool>[true, false],
          reason: 'su-4 conditionne `ZSrsQualityButtons` à la révélation : une '
              'commande d\'hôte muette lui ferait noter une carte non révélée');
    });

    testWidgets('le tap notifie toujours, contrôleur présent', (tester) async {
      final List<bool> seen = <bool>[];
      await tester.pumpWidget(_Host(onRevealChanged: seen.add));

      await tester.tap(find.byType(ZFlashcardReviewCard));
      await tester.pumpAndSettle();

      expect(seen, <bool>[true]);
    });
  });

  group('Possession — la carte n\'est PAS propriétaire du pilote', () {
    testWidgets('🔴 le contrôleur de l\'hôte SURVIT au démontage de la carte',
        (tester) async {
      final _ExternalOwner owner = _ExternalOwner();
      final ZToggleController controller =
          ZToggleController(owner: owner, debugLabel: 'externe');
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: ZFlashcardReviewCard(
                card: _q1,
                revealController: controller,
              ),
            ),
          ),
        ),
      ));
      expect(controller.consumerCount, 1,
          reason: 'un contrôleur consommé doit se DÉCLARER consommé — c\'est ce '
              'qui rend détectable un contrôleur accepté mais jamais branché');

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(controller.isDisposed, isFalse,
          reason: 'la carte disposerait un objet qui ne lui appartient pas');
      expect(controller.consumerCount, 0, reason: 'la carte doit se débrancher');
      controller.value = true; // lèverait si le contrôleur avait été disposé
      expect(controller.value, isTrue);
    });

    testWidgets('un contrôleur JAMAIS passé à la carte est signalé',
        (tester) async {
      // Le cas mort n°2 mesuré chez l'hôte : un widget DÉCLARE le contrôleur et
      // ne l'utilise jamais dans son corps.
      await tester.pumpWidget(const _Host(withController: false));
      expect(_host(tester).reveal.wasEverConsumed, isFalse);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(tester.takeException(), isAssertionError,
          reason: 'sans ce signal on ne distingue plus « bouton inerte » de '
              '« bouton non branché »');
    });
  });

  group('AD-2 / SM-1 — la commande externe ne rebuild QUE la tranche', () {
    testWidgets('🔴 l\'instance de la rangée d\'actions SURVIT à la commande',
        (tester) async {
      await tester.pumpWidget(const _Host());
      // La rangée d'actions est construite en SIBLING du ValueListenableBuilder
      // de la face : si la commande provoquait un `setState` d'échelle carte,
      // cette instance serait remplacée.
      final Element before = tester.element(
        find.byKey(ZFlashcardReviewCard.actionsKey),
      );

      await tester.tap(find.text('VOIR'));
      await tester.pumpAndSettle();

      expect(find.text('A1'), findsOneWidget);
      expect(
        identical(
          before,
          tester.element(find.byKey(ZFlashcardReviewCard.actionsKey)),
        ),
        isTrue,
        reason: 'une commande de l\'hôte ne doit pas reconstruire la carte '
            'entière (AD-2, objectif produit n°1)',
      );
    });
  });
}

/// Propriétaire hors arbre pour les cas où le contrôleur survit à la carte.
class _ExternalOwner implements ZDisplayStateOwner {
  @override
  void zRegisterDisplayState(ZDisplayStateController<Object?> controller) {}
}
