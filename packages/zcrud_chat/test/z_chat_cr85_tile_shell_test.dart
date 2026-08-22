/// La coquille de tuile, deuxième passe : **ce que le filet borne**, et le
/// créneau de fin de coiffe.
///
/// ## Ce que ce fichier mesure, et pourquoi dans cet ordre
///
/// Le premier groupe est le **contre-témoin**, en COMPTES ABSOLUS : sans
/// coquille et sans créneau, l'arbre rendu est celui d'avant — zéro
/// `DecoratedBox`, zéro `Row`, un nombre de `Column` figé. Une garde écrite en
/// comparaison de deux rendus passifs serait restée verte même si les deux
/// avaient changé ensemble.
///
/// Le deuxième groupe mesure l'**appartenance dans l'arbre** : la barre
/// d'actions n'est pas un descendant de la carte, les blocs le sont. C'est une
/// mesure de structure, pas d'apparence — une garde de pixels serait passée si
/// quelqu'un s'était contenté de repeindre le filet.
///
/// Le troisième mesure l'effet que l'hôte a constaté à l'écran : sur un
/// message court, le filet ne monte plus jusque sous les commandes, donc sa
/// hauteur tombe d'au moins la hauteur de la barre.
///
/// Le quatrième mesure le créneau de fin de coiffe : sa place, sa densité, son
/// plancher tactile, sa sémantique, et ce qu'il devient quand le sujet est
/// long — en LTR comme en RTL.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_render_harness.dart';

/// Clé de la barre d'actions montée par l'hôte de test.
const Key kActions = Key('cr85-actions');

/// Clé du créneau de fin de coiffe monté par l'hôte de test.
const Key kTrailing = Key('cr85-trailing');

/// Nombre de widgets de type [T] sous la tuile.
int under<T extends Widget>(WidgetTester tester) => find
    .descendant(of: find.byType(ZChatMessageTile), matching: find.byType(T))
    .evaluate()
    .length;

/// La carte : le **premier** `DecoratedBox` sous la tuile (la pilule de dépli
/// est le dernier, et elle est un descendant de celui-ci).
Finder cardOf() => find
    .descendant(
      of: find.byType(ZChatMessageTile),
      matching: find.byType(DecoratedBox),
    )
    .first;

/// Une tuile d'assistant portant [text], avec les créneaux demandés.
Widget tile({
  required String text,
  ZChatTileShell? shell,
  String? topic,
  Widget? actions,
}) => ZChatMessageTile(
  message: assistant(<ZContentBlock>[ZTextBlock(text: text)]),
  shell: shell,
  topic: topic,
  actionsBuilder: actions == null
      ? null
      : (BuildContext context, ZChatMessage message) => actions,
);

void main() {
  group('🔴 85-A — CONTRE-TÉMOIN : rien de déclaré, arbre INCHANGÉ (comptes '
      'ABSOLUS)', () {
    testWidgets('sans coquille ni créneau : zéro carte, zéro rangée, UNE '
        'colonne', (WidgetTester tester) async {
      await tester.pumpWidget(harness(tile(text: 'corps')));
      expect(under<DecoratedBox>(tester), 0, reason: '🔴 une carte est '
          'apparue sans qu\'aucune coquille ne soit déclarée');
      expect(under<Row>(tester), 0, reason: '🔴 une rangée est apparue sans '
          'créneau de coiffe déclaré');
      expect(under<Column>(tester), 1, reason: '🔴 le nombre de colonnes de '
          'la tuile nue a changé');
    });

    testWidgets('actions seules, sans coquille : la colonne unique d\'avant, '
        'zéro carte', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          tile(
            text: 'corps',
            actions: const SizedBox(key: kActions, height: 24, width: 24),
          ),
        ),
      );
      expect(under<DecoratedBox>(tester), 0);
      expect(under<Row>(tester), 0);
      // Une seule colonne s'ajoute — celle qui empile blocs et actions. Sans
      // coquille, le lot ne scinde RIEN : c'est le rendu d'avant, à
      // l'identique.
      expect(under<Column>(tester), 2, reason: '🔴 sans coquille, la tuile '
          's\'est mise à scinder son empilement');
    });

    testWidgets('coquille sans créneau de coiffe : zéro rangée', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          tile(text: 'corps', shell: const ZChatTileShell(), topic: 'sujet'),
        ),
      );
      expect(under<Row>(tester), 0, reason: '🔴 la coiffe est devenue une '
          'rangée alors qu\'aucun créneau n\'est déclaré');
    });
  });

  group('🔴 85-B — le filet borne le CONTENU : appartenance dans l\'ARBRE',
      () {
    testWidgets('la barre d\'actions n\'est PAS un descendant de la carte ; '
        'les blocs le sont', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          tile(
            text: 'corps',
            shell: const ZChatTileShell(),
            topic: 'sujet',
            actions: const SizedBox(key: kActions, height: 24, width: 24),
          ),
        ),
      );
      // La barre existe bien — sans quoi la garde serait verte pour la plus
      // mauvaise des raisons.
      expect(find.byKey(kActions), findsOneWidget);
      expect(
        find.descendant(of: cardOf(), matching: find.byKey(kActions)),
        findsNothing,
        reason: '🔴 la barre d\'actions est DANS le filet : le cadre délimite '
            'la réponse ET ses commandes',
      );
      expect(
        find.descendant(of: cardOf(), matching: find.text('corps')),
        findsOneWidget,
        reason: '🔴 le contenu est SORTI du filet',
      );
      expect(
        find.descendant(of: cardOf(), matching: find.text('sujet')),
        findsOneWidget,
        reason: '🔴 la coiffe est sortie du filet',
      );
    });

    testWidgets('l\'identité reste DANS le filet — elle dit de qui est le '
        'message, pas ce qu\'on peut en faire', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[
              const ZTextBlock(text: 'corps'),
            ]),
            shell: const ZChatTileShell(),
            identityBuilder: (BuildContext c, ZChatMessage m) =>
                const Text('qui'),
            actionsBuilder: (BuildContext c, ZChatMessage m) =>
                const SizedBox(key: kActions, height: 24, width: 24),
          ),
        ),
      );
      expect(
        find.descendant(of: cardOf(), matching: find.text('qui')),
        findsOneWidget,
        reason: '🔴 l\'identité est sortie du filet',
      );
      expect(
        find.descendant(of: cardOf(), matching: find.byKey(kActions)),
        findsNothing,
      );
    });

    testWidgets('le bouton de dépli reste DANS le filet — il gouverne le '
        'contenu que le filet borne', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          SingleChildScrollView(
            child: ZChatMessageTile(
              message: assistant(<ZContentBlock>[longText(40)]),
              collapsedMaxHeight: 96,
              shell: const ZChatTileShell(),
            ),
          ),
        ),
      );
      // Le bouton n'apparaît qu'après la MESURE du dépassement, relayée par
      // un rappel de mise en page : une seule frame ne suffit pas.
      await tester.pump();
      expect(
        find.descendant(
          of: cardOf(),
          matching: find.byType(GestureDetector),
        ),
        findsOneWidget,
        reason: '🔴 le bouton de dépli est sorti du filet',
      );
    });
  });

  group('🔴 85-C — la MESURE de l\'hôte : sur un message court, le filet '
      'rétrécit', () {
    testWidgets('la carte ne monte plus jusque sous les commandes', (
      WidgetTester tester,
    ) async {
      const double barHeight = 96;
      await tester.pumpWidget(
        harness(
          tile(
            text: 'corps',
            shell: const ZChatTileShell(),
            actions: const SizedBox(
              key: kActions,
              height: barHeight,
              width: 240,
            ),
          ),
        ),
      );
      final Rect whole = tester.getRect(find.byType(ZChatMessageTile));
      final Rect card = tester.getRect(cardOf());
      final Rect bar = tester.getRect(find.byKey(kActions));
      expect(bar.height, barHeight);
      // Ce que l'hôte a mesuré : la carte a perdu la hauteur de la barre.
      expect(
        card.height,
        lessThanOrEqualTo(whole.height - bar.height),
        reason: '🔴 le filet englobe encore la barre d\'actions',
      );
      // Et la barre est SOUS la carte, pas dedans.
      expect(
        card.bottom,
        lessThanOrEqualTo(bar.top),
        reason: '🔴 la barre d\'actions chevauche la carte',
      );
    });
  });

  group('🔴 85-D — le créneau de FIN DE COIFFE', () {
    testWidgets('déclaré, il est rendu en FIN de coiffe, sur la ligne du '
        'sujet', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          tile(
            text: 'corps',
            topic: 'sujet',
            shell: ZChatTileShell(
              showTimestamp: false,
              topicTrailing: (BuildContext c, ZChatMessage m) =>
                  const SizedBox(key: kTrailing, height: 8, width: 40),
            ),
          ),
        ),
      );
      expect(under<Row>(tester), 1, reason: '🔴 la coiffe n\'est pas devenue '
          'une rangée');
      final Rect subject = tester.getRect(find.text('sujet'));
      final Rect slot = tester.getRect(find.byKey(kTrailing));
      expect(slot.left, greaterThanOrEqualTo(subject.right), reason: '🔴 en '
          'LTR, le créneau n\'est pas APRÈS le sujet');
      // Même ligne : les deux centres verticaux coïncident.
      expect(slot.center.dy, closeTo(subject.center.dy, 1.0));
    });

    testWidgets('🔬 le plancher tactile est le NÔTRE, pas celui du SDK : un '
        'créneau de 8 dp est rendu à 48 dp', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          tile(
            text: 'corps',
            topic: 'sujet',
            shell: ZChatTileShell(
              showTimestamp: false,
              topicTrailing: (BuildContext c, ZChatMessage m) =>
                  const SizedBox(key: kTrailing, height: 8, width: 40),
            ),
          ),
        ),
      );
      // Le SDK ne contraint rien ici : sans notre `ConstrainedBox`, ce
      // `SizedBox` mesurerait 8 dp de haut. C'est la contrainte DÉCLARÉE qui
      // est mesurée, pas un plancher hérité.
      expect(
        tester.getSize(find.byKey(kTrailing)).height,
        kZChatMinTapTarget,
        reason: '🔴 le créneau descend sous le plancher tactile (AD-13)',
      );
    });

    testWidgets('🔬 la DENSITÉ réduite est déclarée : un glyphe du créneau '
        'mesure la taille de référence, pas les 24 dp du SDK', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          tile(
            text: 'corps',
            topic: 'sujet',
            shell: ZChatTileShell(
              showTimestamp: false,
              topicTrailing: (BuildContext c, ZChatMessage m) =>
                  const Icon(Icons.delete_outline, key: kTrailing),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(kTrailing)).width,
        ZChatNotebookReference.tileTopicTrailingIconSize,
        reason: '🔴 le créneau ne porte plus la densité réduite de la coiffe',
      );
      expect(
        ZChatNotebookReference.tileTopicTrailingIconSize,
        lessThan(ZChatNotebookReference.perMessageActionIconSize),
        reason: '🔴 la densité de la coiffe n\'est plus RÉDUITE par rapport à '
            'celle d\'une action de message',
      );
    });

    testWidgets('sujet LONG : il TRONQUE, le créneau reste entier et ne '
        'déborde pas', (WidgetTester tester) async {
      // Le sujet est rendu APRÈS `trim()` : le comparer avec son espace final
      // ne trouverait aucun `Text`.
      final String long = ('sujet ' * 200).trim();
      final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = caught.add;
      try {
        await tester.pumpWidget(
          harness(
            tile(
              text: 'corps',
              topic: long,
              shell: ZChatTileShell(
                showTimestamp: false,
                topicTrailing: (BuildContext c, ZChatMessage m) =>
                    const SizedBox(key: kTrailing, height: 48, width: 144),
              ),
            ),
          ),
        );
      } finally {
        FlutterError.onError = previous;
      }
      expect(caught, isEmpty, reason: '🔴 la coiffe déborde quand le sujet '
          'est long et le créneau chargé');
      expect(
        tester.getSize(find.byKey(kTrailing)).width,
        144,
        reason: '🔴 le créneau est ÉCRASÉ par un sujet long',
      );
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        find.text(long),
      );
      expect(paragraph.didExceedMaxLines, isTrue, reason: '🔴 le sujet ne '
          'tronque pas');
      final Rect tileRect = tester.getRect(find.byType(ZChatMessageTile));
      final Rect slot = tester.getRect(find.byKey(kTrailing));
      expect(slot.right, lessThanOrEqualTo(tileRect.right + 0.5));
    });

    testWidgets('RTL : « fin de coiffe » se rend à GAUCHE, le sujet à droite',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          tile(
            text: 'corps',
            topic: 'sujet',
            shell: ZChatTileShell(
              showTimestamp: false,
              topicTrailing: (BuildContext c, ZChatMessage m) =>
                  const SizedBox(key: kTrailing, height: 8, width: 40),
            ),
          ),
          direction: TextDirection.rtl,
        ),
      );
      final Rect subject = tester.getRect(find.text('sujet'));
      final Rect slot = tester.getRect(find.byKey(kTrailing));
      expect(slot.right, lessThanOrEqualTo(subject.left), reason: '🔴 en RTL, '
          'le créneau n\'a pas migré du côté FIN (la gauche)');
    });

    testWidgets('un créneau SANS sujet ni horodatage se pose seul, du côté '
        'fin', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          tile(
            text: 'corps',
            shell: ZChatTileShell(
              showTimestamp: false,
              topicTrailing: (BuildContext c, ZChatMessage m) =>
                  const SizedBox(key: kTrailing, height: 8, width: 40),
            ),
          ),
        ),
      );
      expect(find.byKey(kTrailing), findsOneWidget);
      expect(under<Row>(tester), 0, reason: '🔴 une rangée a été insérée pour '
          'borner un seul enfant');
      final Rect card = tester.getRect(cardOf());
      final Rect slot = tester.getRect(find.byKey(kTrailing));
      expect(slot.right, closeTo(card.right - 8, 1.5), reason: '🔴 le créneau '
          'seul n\'est pas posé du côté FIN');
    });

    testWidgets('A11y — le créneau garde sa sémantique PROPRE : le libellé '
        'd\'en-tête du sujet ne l\'avale pas', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          tile(
            text: 'corps',
            topic: 'sujet',
            shell: ZChatTileShell(
              showTimestamp: false,
              topicTrailing: (BuildContext c, ZChatMessage m) => Semantics(
                key: kTrailing,
                button: true,
                label: 'supprimer',
                child: const SizedBox(height: 48, width: 48),
              ),
            ),
          ),
        ),
      );
      // La contrainte DÉCLARÉE : le créneau est un FRÈRE du sujet. Le
      // `Semantics(header:, excludeSemantics: true)` de la coiffe n'exclut
      // que ses propres enfants — s'il enveloppait le créneau, « supprimer »
      // aurait disparu de l'arbre sémantique.
      expect(find.bySemanticsLabel('supprimer'), findsOneWidget,
          reason: '🔴 la sémantique du créneau a été avalée par la coiffe');
      expect(find.bySemanticsLabel('sujet'), findsOneWidget);
    });

    testWidgets('AD-10 — un créneau qui LÈVE perd le créneau, jamais la '
        'coiffe', (WidgetTester tester) async {
      final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = caught.add;
      try {
        await tester.pumpWidget(
          harness(
            tile(
              text: 'corps',
              topic: 'sujet',
              shell: ZChatTileShell(
                showTimestamp: false,
                topicTrailing: (BuildContext c, ZChatMessage m) =>
                    throw StateError('créneau fautif'),
              ),
            ),
          ),
        );
      } finally {
        FlutterError.onError = previous;
      }
      expect(find.text('sujet'), findsOneWidget);
      expect(find.text('corps'), findsOneWidget);
      expect(under<Row>(tester), 0);
      expect(
        caught.map((FlutterErrorDetails d) => d.context.toString()).join(),
        contains(kZChatSeamTopicTrailing),
        reason: '🔴 l\'échec du créneau n\'est pas relayé sous son nom de seam',
      );
    });
  });
}
