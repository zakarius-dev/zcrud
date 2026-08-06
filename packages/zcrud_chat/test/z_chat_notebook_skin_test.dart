/// La chaîne **paramètre > jeton > référence** du rendu Notebook — lot γ,
/// CR-IFFD-72.
///
/// 🔴 Les trois niveaux sont atteints **séparément**. Une garde qui ne
/// prouverait que « le paramètre gagne » resterait verte sur une implémentation
/// qui ignore complètement le jeton — c'est le défaut « priorité insensible au
/// paramètre » déjà démasqué dans ce dépôt, pris par l'autre bout.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Monte un arbre minimal et rend le style résolu par [skin].
Future<ZChatNotebookStyle> _resolve(
  WidgetTester tester, {
  ZChatNotebookSkin skin = const ZChatNotebookSkin(),
  ZcrudTheme? theme,
}) async {
  late ZChatNotebookStyle out;
  Widget tree = Builder(
    builder: (BuildContext context) {
      out = skin.resolve(context);
      return const SizedBox.shrink();
    },
  );
  if (theme != null) {
    tree = ZcrudScope(theme: theme, child: tree);
  }
  await tester.pumpWidget(
    Directionality(textDirection: TextDirection.ltr, child: tree),
  );
  return out;
}

void main() {
  group('🔴 SKIN-G1 — NIVEAU 3 seul : la référence, quand rien n\'est réglé',
      () {
    testWidgets('un skin vide, sans thème, rend EXACTEMENT la référence IFFD',
        (WidgetTester tester) async {
      final ZChatNotebookStyle s = await _resolve(tester);
      expect(s.bubbleWidthFactor, ZChatNotebookReference.bubbleWidthFactor);
      expect(s.bubbleWidthFactor, 0.95,
          reason: '🔴 la valeur mesurée chez IFFD '
              '(`chatbot_conversation_screen.dart:3570`) a bougé');
      expect(s.requestBubbleRadius, const Radius.circular(12));
      expect(s.responseBubbleRadius, isNull,
          reason: '🔴 le legacy ne pose AUCUN `shape` sur la réponse : en '
              'inventer un serait une valeur que personne n\'a mesurée');
      expect(s.showAuthorAvatar, isFalse);
      expect(s.showAuthorName, isFalse);
      expect(s.showTimestamp, isTrue);
      expect(s.toolAccentColor, ZChatNotebookReference.toolAccentColor);
      expect(s.busyPalette, ZChatNotebookReference.busyPalette);
    });
  });

  group('🔴 SKIN-G2 — NIVEAU 2 seul : le JETON bat la référence', () {
    testWidgets('sans aucun paramètre, chaque jeton est réellement lu',
        (WidgetTester tester) async {
      const ZcrudTheme token = ZcrudTheme(
        chatBubbleWidthFactor: 0.5,
        chatRequestBubbleRadius: Radius.circular(3),
        chatResponseBubbleRadius: Radius.circular(4),
        chatBubbleShowAuthorAvatar: true,
        chatBubbleShowAuthorName: true,
        chatBubbleShowTimestamp: false,
        chatToolAccentColor: Color(0xFF010203),
        chatBusyPalette: <Color>[Color(0xFF040506)],
      );
      final ZChatNotebookStyle s = await _resolve(tester, theme: token);
      // 🔴 CHAQUE jeton séparément : un seul `??` oublié dans `resolve` laisse
      // la référence gagner, sans erreur de compilation.
      expect(s.bubbleWidthFactor, 0.5);
      expect(s.requestBubbleRadius, const Radius.circular(3));
      expect(s.responseBubbleRadius, const Radius.circular(4));
      expect(s.showAuthorAvatar, isTrue);
      expect(s.showAuthorName, isTrue);
      expect(s.showTimestamp, isFalse);
      expect(s.toolAccentColor, const Color(0xFF010203));
      expect(s.busyPalette, <Color>[const Color(0xFF040506)]);
      // …et aucune de ces valeurs n'est celle de la référence (sans quoi le
      // test serait vert sur un `resolve` qui ignore le jeton).
      expect(s.bubbleWidthFactor,
          isNot(ZChatNotebookReference.bubbleWidthFactor));
      expect(s.showAuthorAvatar,
          isNot(ZChatNotebookReference.showAuthorAvatar));
      expect(s.toolAccentColor, isNot(ZChatNotebookReference.toolAccentColor));
    });

    testWidgets('un jeton FAUX (`false`) est respecté, jamais confondu avec '
        '« non réglé »', (WidgetTester tester) async {
      // Le piège du `??` sur un booléen : `false ?? référence` n'existe pas en
      // Dart, mais `theme.x == false` traité comme absence, si. La référence
      // vaut `true` pour l'horodatage : un jeton `false` doit gagner.
      final ZChatNotebookStyle s = await _resolve(
        tester,
        theme: const ZcrudTheme(chatBubbleShowTimestamp: false),
      );
      expect(ZChatNotebookReference.showTimestamp, isTrue);
      expect(s.showTimestamp, isFalse);
    });
  });

  group('🔴 SKIN-G3 — NIVEAU 1 : le PARAMÈTRE bat le jeton', () {
    testWidgets('paramètre et jeton en désaccord : le paramètre gagne, valeur '
        'par valeur', (WidgetTester tester) async {
      const ZcrudTheme token = ZcrudTheme(
        chatBubbleWidthFactor: 0.5,
        chatRequestBubbleRadius: Radius.circular(3),
        chatBubbleShowAuthorName: true,
        chatToolAccentColor: Color(0xFF010203),
      );
      final ZChatNotebookStyle s = await _resolve(
        tester,
        theme: token,
        skin: const ZChatNotebookSkin(
          bubbleWidthFactor: 0.25,
          requestBubbleRadius: Radius.circular(7),
          showAuthorName: false,
          toolAccentColor: Color(0xFF070809),
        ),
      );
      expect(s.bubbleWidthFactor, 0.25);
      expect(s.requestBubbleRadius, const Radius.circular(7));
      expect(s.showAuthorName, isFalse);
      expect(s.toolAccentColor, const Color(0xFF070809));
    });

    testWidgets('un paramètre ABSENT ne masque pas le jeton des autres champs',
        (WidgetTester tester) async {
      // La chaîne est par CHAMP, pas par objet : régler la largeur ne doit pas
      // faire retomber le rayon sur la référence.
      final ZChatNotebookStyle s = await _resolve(
        tester,
        theme: const ZcrudTheme(chatRequestBubbleRadius: Radius.circular(3)),
        skin: const ZChatNotebookSkin(bubbleWidthFactor: 0.25),
      );
      expect(s.bubbleWidthFactor, 0.25, reason: 'niveau 1');
      expect(s.requestBubbleRadius, const Radius.circular(3),
          reason: '🔴 niveau 2 PERDU : la chaîne est résolue par objet et non '
              'par champ');
    });
  });

  group('🔴 SKIN-G4 — les accents de capacité : trois niveaux, et le canal non '
      'chromatique INTACT', () {
    testWidgets('référence seule', (WidgetTester tester) async {
      final ZChatNotebookStyle s = await _resolve(tester);
      final ZChatNotebookCapabilityStyle cap =
          s.capability(kZChatCapabilityMindmap)!;
      expect(cap, ZChatNotebookReference.capabilities[kZChatCapabilityMindmap]);
    });

    testWidgets('le jeton remplace l\'accent, PAS les canaux non chromatiques',
        (WidgetTester tester) async {
      final ZChatNotebookStyle s = await _resolve(
        tester,
        theme: const ZcrudTheme(
          chatCapabilityAccents: <String, Color>{
            kZChatCapabilityMindmap: Color(0xFF0A0B0C),
          },
        ),
      );
      final ZChatNotebookCapabilityStyle cap =
          s.capability(kZChatCapabilityMindmap)!;
      expect(cap.accent, const Color(0xFF0A0B0C));
      // 🔴 LA propriété du lot : un thème ne peut pas ramener le défaut
      // « information portée par la seule couleur ».
      expect(cap.generatedLabelKey, kZChatLabelGenerated);
      expect(cap.generatedMarkSize,
          ZChatNotebookReference.generatedMarkSize);
    });

    testWidgets('le paramètre bat le jeton, accent par accent',
        (WidgetTester tester) async {
      final ZChatNotebookStyle s = await _resolve(
        tester,
        theme: const ZcrudTheme(
          chatCapabilityAccents: <String, Color>{
            kZChatCapabilityMindmap: Color(0xFF0A0B0C),
            kZChatCapabilityHumour: Color(0xFF0D0E0F),
          },
        ),
        skin: const ZChatNotebookSkin(
          capabilityAccents: <String, Color>{
            kZChatCapabilityMindmap: Color(0xFF101112),
          },
        ),
      );
      expect(s.capability(kZChatCapabilityMindmap)!.accent,
          const Color(0xFF101112), reason: 'niveau 1');
      expect(s.capability(kZChatCapabilityHumour)!.accent,
          const Color(0xFF0D0E0F),
          reason: '🔴 niveau 2 PERDU : une table de paramètres partielle a '
              'écrasé la table de jetons ENTIÈRE');
      expect(s.capability(kZChatCapabilityStory)!.accent,
          ZChatNotebookReference
              .capabilities[kZChatCapabilityStory]!.accent,
          reason: '🔴 niveau 3 PERDU : une capacité non citée doit garder son '
              'accent de référence');
    });

    testWidgets('une capacité INCONNUE rend `null`, jamais un style inventé '
        '(AD-10)', (WidgetTester tester) async {
      final ZChatNotebookStyle s = await _resolve(
        tester,
        skin: const ZChatNotebookSkin(
          capabilityAccents: <String, Color>{'futur': Color(0xFF131415)},
        ),
      );
      expect(s.capability('futur'), isNull,
          reason: '🔴 un accent fourni pour une clé inconnue a été promu en '
              'style INCOMPLET — donc sans canal non chromatique.');
      expect(s.capability(''), isNull);
    });
  });

  group('🔴 SKIN-G5 — AD-10 : `resolve` ne lève JAMAIS', () {
    testWidgets('sans `ZcrudScope` NI `Theme`, la résolution aboutit',
        (WidgetTester tester) async {
      // `ZcrudTheme.of` retombe sur `Theme.of(context)` puis sur son repli :
      // aucun de ces chemins ne doit faire tomber une conversation.
      final ZChatNotebookStyle s = await _resolve(tester);
      expect(s.bubbleWidthFactor, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });
}
