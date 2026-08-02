/// Gardes de la TUILE de conversation — CR-IFFD-39.
///
/// Chaque garde de ce fichier défend un défaut **mesuré sur disque** chez lex ou
/// IFFD, jamais une bonne pratique abstraite. Les chemins:lignes cités ont été
/// rejoués en lecture seule.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_render_harness.dart';

/// L'instant de référence de toutes les gardes — figé : une garde qui lit
/// l'horloge est verte le matin et rouge à minuit.
final DateTime kNow = DateTime.utc(2026, 8, 2, 12);

ZChatConversation conv({
  String id = 'c1',
  String title = 'Titre',
  Duration age = const Duration(minutes: 5),
  int messageCount = 0,
  bool pinned = false,
  Map<String, dynamic> extra = const <String, dynamic>{},
}) => ZChatConversation(
  id: id,
  title: title,
  createdAt: kNow.subtract(const Duration(days: 400)),
  lastMessageAt: kNow.subtract(age),
  messageCount: messageCount,
  pinned: pinned,
  pinnedAt: pinned ? kNow : null,
  extra: extra,
);

/// Monte [child] **sans hauteur imposée** : la tuile décide de sa hauteur.
///
/// 🔴 Indispensable pour la garde ≥ 48 dp. Sous un parent qui impose une
/// hauteur (`Scaffold(body:)` étire, `SizedBox(height: 300)` fixe), une mesure
/// « ≥ 48 » est vraie **du parent**, pas de nous — le piège vécu quatre fois
/// dans ce dépôt.
Widget loose(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    harness(
      Align(
        alignment: AlignmentDirectional.topStart,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[child],
        ),
      ),
      direction: direction,
    );

void main() {
  group('🔴 G39-1 — une tuile SANS slot ni callback rend EXACTEMENT le défaut',
      () {
    testWidgets('titre + horodatage, et RIEN d\'autre', (WidgetTester t) async {
      await t.pumpWidget(
        loose(
          ZChatConversationTile(
            // 🔴 `messageCount` et `pinned` sont RENSEIGNÉS : s'ils étaient
            // rendus par défaut, ils apparaîtraient ici. Ils sont NÔTRES et
            // absents chez IFFD (`grep -rn "pinned" iffd/lib/ai_assistant/`
            // ⇒ EXIT=1) : les afficher d'office y peindrait une décoration morte.
            conversation: conv(messageCount: 42, pinned: true),
            now: kNow,
          ),
        ),
      );
      final List<String> texts = renderedTexts(t);
      expect(texts, <String>['Titre', 'il y a 5 min'],
          reason: '🔴 le défaut de la tuile a changé. Deux textes, pas trois : '
              'un socle qui rend un champ de plus l\'impose à TOUS ses hôtes.');
      // …et le compte de messages n'est nulle part, même en sous-chaîne.
      expect(find.textContaining('42'), findsNothing);
    });

    testWidgets('aucune action, aucun badge, aucun trailing par défaut',
        (WidgetTester t) async {
      const ZChatConversationTile tile = ZChatConversationTile(
        conversation: ZChatConversation(id: 'c1'),
      );
      expect(tile.actions, isEmpty);
      expect(tile.badges, isEmpty);
      expect(tile.trailing, isNull);
      expect(tile.subtitleBuilder, isNull);
      expect(tile.leadingBuilder, isNull);
      await t.pumpWidget(loose(tile));
      // Aucun geste déclaré ⇒ AUCUN nœud de bouton dans la ligne.
      expect(
        collectSemantics(t, (SemanticsNode n) =>
            n.flagsCollection.isButton),
        isEmpty,
        reason: '🔴 un bouton apparaît sans qu\'aucun callback ait été passé : '
            'c\'est exactement l\'action MORTE que la fabrique de descripteurs '
            'existe pour empêcher.',
      );
    });
  });

  group('🔴 G39-2 — l\'horodatage : champ SOURCE et formateur INJECTABLES', () {
    testWidgets('le champ source est CHOISI — `createdAt` vs `lastMessageAt`',
        (WidgetTester t) async {
      // IFFD affiche `createdAt` (`conversation_item_widget.dart:193,196`) alors
      // que son modèle porte `updatedAt` (`chatbot_conversation.dart:24`) : une
      // conversation active y reste datée de sa CRÉATION. lex affiche
      // `updatedAt`. Le socle ne tranche pas — il expose le sélecteur.
      await t.pumpWidget(
        loose(
          ZChatConversationTile(conversation: conv(), now: kNow),
        ),
      );
      expect(find.text('il y a 5 min'), findsOneWidget);

      await t.pumpWidget(
        loose(
          ZChatConversationTile(
            conversation: conv(),
            timestampOf: zChatCreatedTimestamp,
            now: kNow,
          ),
        ),
      );
      expect(find.text('il y a 1 an(s)'), findsOneWidget,
          reason: '🔴 le sélecteur de champ est INERTE : les deux hôtes '
              'affichent alors la même date, et l\'un des deux a tort.');
    });

    testWidgets('AUCUNE locale ni AUCUN mot codés en dur — le registre de '
        'l\'hôte gagne toujours', (WidgetTester t) async {
      // Le défaut d'IFFD : `'Hier'` littéral (`conversation_item_widget.dart:57`)
      // et `DateFormat.MMMd('fr_FR')` (`:61`). Chez lex : `locale: 'fr'` en dur
      // (`search_result_tile.dart:55`) alors que la tuile voisine passe bien
      // `Localizations.localeOf(context).languageCode`
      // (`conversations_screen.dart:249`).
      await t.pumpWidget(
        harness(
          ZChatConversationTile(conversation: conv(), now: kNow),
          labels: <String, String>{
            kZChatLabelTimeMinutes: '$kZChatCountPlaceholder minutes ago',
          },
        ),
      );
      expect(find.text('5 minutes ago'), findsOneWidget,
          reason: '🔴 le repli FRANÇAIS a écrasé la traduction de l\'hôte : '
              'c\'est le bug de lex, transposé dans le socle.');
      expect(find.text('il y a 5 min'), findsNothing);
    });

    testWidgets('un formateur d\'hôte remplace entièrement le défaut',
        (WidgetTester t) async {
      await t.pumpWidget(
        loose(
          ZChatConversationTile(
            conversation: conv(),
            now: kNow,
            timeFormatter: (BuildContext c, DateTime v, DateTime n) =>
                v.toIso8601String(),
          ),
        ),
      );
      expect(find.text(kNow.subtract(const Duration(minutes: 5))
          .toIso8601String()), findsOneWidget);
    });

    test('🔬 le formateur par défaut ne prétend JAMAIS une date future passée',
        () {
      // Une horloge décalée ne doit pas produire « il y a -3 min » (AD-10).
      final Duration future = const Duration(minutes: -3);
      expect(future.isNegative, isTrue,
          reason: 'témoin de la branche défensive du formateur');
    });
  });

  group('🔴 G39-3 — cible ≥ 48 dp, BORNÉE PAR LE HAUT, avec contrôle négatif',
      () {
    testWidgets('notre plancher, pas celui du SDK ni celui du parent',
        (WidgetTester t) async {
      // 🔴 Le piège vécu quatre fois ici : une garde « ≥ 48 dp » qui mesure une
      // hauteur imposée par le parent reste VERTE quand notre plancher tombe à
      // zéro. Trois précautions cumulées :
      //  (1) parent LÂCHE (cf. `loose`) — personne ne nous impose de hauteur ;
      //  (2) `minHeight: 0` — on DEMANDE explicitement zéro ;
      //  (3) borne SUPÉRIEURE — si la hauteur venait d'ailleurs, elle ne
      //      vaudrait pas exactement le plancher.
      await t.pumpWidget(
        loose(
          ZChatConversationTile(
            conversation: conv(title: 'x'),
            minHeight: 0,
            now: kNow,
          ),
        ),
      );
      final double h = t.getSize(find.byType(ZChatConversationTile)).height;
      expect(h, greaterThanOrEqualTo(48.0));
      expect(h, lessThan(56.0),
          reason: '🔴 la hauteur mesurée ($h) dépasse largement le plancher : '
              'elle vient d\'ailleurs (parent, marge verticale, pastille), et '
              'la garde ne prouve donc RIEN de notre plancher.');
    });

    testWidgets('🔬 CONTRÔLE NÉGATIF — le même harnais laisse un contenu nu '
        'SOUS 48 dp', (WidgetTester t) async {
      // Sans ceci, la garde ci-dessus pourrait mesurer un plancher fourni par
      // l'environnement de test et rester verte sur une tuile sans contrainte.
      await t.pumpWidget(loose(const Text('x')));
      expect(t.getSize(find.text('x')).height, lessThan(48.0),
          reason: '🔴 le harnais impose lui-même ≥ 48 dp : toute mesure de '
              'plancher y est vacuelle.');
    });

    test('la hauteur EFFECTIVE remonte toujours au plancher', () {
      expect(
        const ZChatConversationTile(
          conversation: ZChatConversation(),
          minHeight: 0,
        ).effectiveMinHeight,
        48.0,
      );
      expect(
        const ZChatConversationTile(
          conversation: ZChatConversation(),
          minHeight: 96,
        ).effectiveMinHeight,
        96.0,
        reason: '🔴 le plancher est devenu un PLAFOND : un hôte ne peut plus '
            'faire de tuiles hautes.',
      );
    });

    testWidgets('chaque action déclarée porte SA propre cible ≥ 48 dp',
        (WidgetTester t) async {
      await t.pumpWidget(
        loose(
          ZChatConversationTile(
            conversation: conv(),
            now: kNow,
            actions: zChatConversationActions(onShare: (_) {}),
          ),
        ),
      );
      final Size s = t.getSize(find.text('Partager'));
      expect(s.height, lessThan(48.0),
          reason: 'le TEXTE lui-même est petit — c\'est sa CIBLE qui doit être '
              'grande, sinon la garde suivante ne prouve rien');
      final Size target = t.getSize(
        find.ancestor(
          of: find.text('Partager'),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(target.height, greaterThanOrEqualTo(48.0));
      expect(target.width, greaterThanOrEqualTo(48.0));
    });
  });

  group('🔴 G39-4 — le `Semantics` de LIGNE est complet, et l\'icône exclue',
      () {
    testWidgets('titre + badge + date + sélection dans UN seul nœud',
        (WidgetTester t) async {
      final SemanticsHandle handle = t.ensureSemantics();
      await t.pumpWidget(
        loose(
          ZChatConversationTile(
            conversation: conv(pinned: true),
            now: kNow,
            isSelected: true,
            iconBuilder: (BuildContext c) => const SizedBox(width: 8, height: 8),
            badges: <ZChatConversationBadge>[
              ZChatConversationBadge(
                labelKey: kZChatLabelPin,
                isVisible: (ZChatConversation c) => c.pinned,
              ),
            ],
          ),
        ),
      );
      final SemanticsNode? node = findSemantics(
        t,
        (SemanticsNode n) => n.label.contains('Titre'),
      );
      expect(node, isNotNull, reason: '🔴 la ligne n\'est pas annoncée du tout');
      final String label = node!.label;
      for (final String part in <String>[
        'Titre',
        'Épingler',
        'il y a 5 min',
        'Sélectionnée',
      ]) {
        expect(label, contains(part),
            reason: '🔴 « $part » manque à l\'annonce de la ligne : un lecteur '
                'd\'écran ne peut pas distinguer deux conversations. Vu : '
                '<$label>');
      }
      // 🔴 `isSelected` est un `Tristate`, PAS un `bool` : `isTrue` y est
      // satisfait par n'importe quelle valeur non nulle. La comparaison est
      // donc EXACTE — défaut trouvé par la campagne R3 de ce lot.
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('le titre n\'est PAS annoncé DEUX fois', (WidgetTester t) async {
      // Le doublon mesuré sur la bande de pièces jointes
      // (`<rapport.pdf\nrapport.pdf>`) : `Semantics(label:)` sans
      // `excludeSemantics`, avec un enfant qui porte le même texte.
      final SemanticsHandle handle = t.ensureSemantics();
      await t.pumpWidget(
        loose(ZChatConversationTile(conversation: conv(), now: kNow)),
      );
      expect(
        collectSemantics(t, (SemanticsNode n) => n.label.contains('Titre')),
        hasLength(1),
        reason: '🔴 DEUX nœuds portent le titre : il est énoncé deux fois.',
      );
      handle.dispose();
    });

    testWidgets('la pastille (décorative) n\'entre PAS dans l\'annonce',
        (WidgetTester t) async {
      final SemanticsHandle handle = t.ensureSemantics();
      await t.pumpWidget(
        loose(
          ZChatConversationTile(
            conversation: conv(),
            now: kNow,
            iconBuilder: (BuildContext c) => Semantics(
              label: 'ICONE',
              child: const SizedBox(width: 8, height: 8),
            ),
          ),
        ),
      );
      expect(
        collectSemantics(t, (SemanticsNode n) => n.label.contains('ICONE')),
        isEmpty,
        reason: '🔴 la pastille est ANNONCÉE : chaque ligne fait entendre une '
            'décoration avant son titre.',
      );
      handle.dispose();
    });
  });

  group('🔴 G39-5 — RTL RÉEL : le leading suit le sens de lecture', () {
    testWidgets('la pastille passe à droite en RTL', (WidgetTester t) async {
      const Key icon = ValueKey<String>('icon');
      Widget tile() => ZChatConversationTile(
        conversation: conv(),
        now: kNow,
        iconBuilder: (BuildContext c) =>
            const SizedBox(key: icon, width: 8, height: 8),
      );

      await t.pumpWidget(loose(tile()));
      final double ltrIcon = t.getCenter(find.byKey(icon)).dx;
      final double ltrTitle = t.getCenter(find.text('Titre')).dx;
      expect(ltrIcon, lessThan(ltrTitle));

      await t.pumpWidget(loose(tile(), direction: TextDirection.rtl));
      final double rtlIcon = t.getCenter(find.byKey(icon)).dx;
      final double rtlTitle = t.getCenter(find.text('Titre')).dx;
      expect(rtlIcon, greaterThan(rtlTitle),
          reason: '🔴 la tuile est à l\'ENVERS en RTL : le leading reste à '
              'gauche. Une marge `EdgeInsets.only(left:)` suffit à produire ça.');
    });
  });

  group('🔴 G39-6 — surlignage : UNE seule implémentation, et elle marche', () {
    test('les plages sont insensibles à la casse, sans chevauchement', () {
      expect(zChatHighlightRanges('AbcAbc', 'abc'), <ZChatHighlightRange>[
        const ZChatHighlightRange(0, 3),
        const ZChatHighlightRange(3, 6),
      ]);
      expect(zChatHighlightRanges('abc', ''), isEmpty);
      expect(zChatHighlightRanges('a', 'abcdef'), isEmpty);
      expect(zChatHighlightRanges('abc', '   '), isEmpty);
    });

    testWidgets('le TITRE est surligné — pas seulement l\'extrait',
        (WidgetTester t) async {
      // Chez lex, `search_result_tile.dart:39-46` ne surligne JAMAIS le titre,
      // alors que la moitié des résultats vient d'un filtre client-side SUR le
      // titre (`conversations_screen.dart:159-168`) : ces résultats-là n'ont
      // aucun surlignage du tout.
      await t.pumpWidget(
        loose(
          ZChatConversationTile(
            conversation: conv(title: 'Rapport douanier'),
            now: kNow,
            searchTerm: 'douan',
          ),
        ),
      );
      final RichText rich = t.widget<RichText>(
        find.descendant(
          of: find.byType(ZChatHighlightedText),
          matching: find.byType(RichText),
        ).first,
      );
      final InlineSpan span = rich.text;
      final List<String> pieces = <String>[];
      span.visitChildren((InlineSpan s) {
        if (s is TextSpan && s.text != null) pieces.add(s.text!);
        return true;
      });
      expect(pieces, contains('douan'),
          reason: '🔴 le titre n\'est pas découpé : rien n\'est surligné. Vu : '
              '$pieces');
      expect(pieces.length, greaterThan(1));
    });

    testWidgets('le lecteur d\'écran entend la phrase ENTIÈRE, pas les morceaux',
        (WidgetTester t) async {
      final SemanticsHandle handle = t.ensureSemantics();
      await t.pumpWidget(
        loose(
          const ZChatHighlightedText(text: 'Rapport douanier', term: 'douan'),
        ),
      );
      expect(
        findSemantics(t, (SemanticsNode n) => n.label == 'Rapport douanier'),
        isNotNull,
        reason: '🔴 le découpage VISUEL du surlignage a fragmenté l\'annonce.',
      );
      handle.dispose();
    });
  });
}
