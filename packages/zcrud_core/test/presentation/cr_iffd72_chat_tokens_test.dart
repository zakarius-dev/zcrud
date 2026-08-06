/// Jetons de RENDU DU CHAT (**CR-IFFD-72**, lot γ) — les 4 sites, et le
/// null-préservant.
///
/// 🔴 Ces jetons sont le **niveau 2** de la chaîne `paramètre > jeton >
/// référence` de `ZChatNotebookSkin` (`zcrud_chat`). Le piège qu'ils partagent
/// avec toute la famille : un jeton oublié dans `copyWith` ou dans `lerp`
/// **compile**, et le défaut ne se voit qu'à l'usage — la valeur est perdue, ou
/// remise à zéro à la première transition de thème.
///
/// 🔴 Le second piège, spécifique ici : si `lerp` matérialisait une valeur là
/// où les deux côtés sont `null`, la valeur de RÉFÉRENCE IFFD s'imposerait à
/// **tout hôte** au premier changement de thème — exactement ce que « skin
/// opt-in » exclut.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('🔴 CR-IFFD-72 — les 9 jetons de chat traversent `copyWith`', () {
    test('chaque jeton posé par `copyWith` est relu tel quel', () {
      const ZcrudTheme base = ZcrudTheme();
      final ZcrudTheme t = base.copyWith(
        chatBubbleWidthFactor: 0.95,
        chatRequestBubbleRadius: const Radius.circular(12),
        chatResponseBubbleRadius: const Radius.circular(4),
        chatBubbleShowAuthorAvatar: true,
        chatBubbleShowAuthorName: true,
        chatBubbleShowTimestamp: false,
        chatToolAccentColor: const Color(0xFFFF9800),
        chatCapabilityAccents: const <String, Color>{
          'mindmap': Color(0xFF010203),
        },
        chatBusyPalette: const <Color>[Color(0xFF040506)],
      );
      expect(t.chatBubbleWidthFactor, 0.95);
      expect(t.chatRequestBubbleRadius, const Radius.circular(12));
      expect(t.chatResponseBubbleRadius, const Radius.circular(4));
      expect(t.chatBubbleShowAuthorAvatar, isTrue);
      expect(t.chatBubbleShowAuthorName, isTrue);
      expect(t.chatBubbleShowTimestamp, isFalse);
      expect(t.chatToolAccentColor, const Color(0xFFFF9800));
      expect(t.chatCapabilityAccents, <String, Color>{
        'mindmap': const Color(0xFF010203),
      });
      expect(t.chatBusyPalette, <Color>[const Color(0xFF040506)]);
      // …et le thème de départ n'en portait AUCUN (sans quoi le test serait
      // vert sur un `copyWith` qui ignore ses arguments).
      expect(base.chatBubbleWidthFactor, isNull);
      expect(base.chatToolAccentColor, isNull);
    });

    test('un `copyWith` VIDE ne perd aucun jeton de chat', () {
      // Le défaut classique : un jeton absent du CORPS de `copyWith` disparaît
      // au premier appel, y compris sans argument.
      final ZcrudTheme t = const ZcrudTheme(
        chatBubbleWidthFactor: 0.95,
        chatRequestBubbleRadius: Radius.circular(12),
        chatResponseBubbleRadius: Radius.circular(4),
        chatBubbleShowAuthorAvatar: true,
        chatBubbleShowAuthorName: true,
        chatBubbleShowTimestamp: false,
        chatToolAccentColor: Color(0xFFFF9800),
        chatCapabilityAccents: <String, Color>{'mindmap': Color(0xFF010203)},
        chatBusyPalette: <Color>[Color(0xFF040506)],
      ).copyWith();
      expect(t.chatBubbleWidthFactor, 0.95);
      expect(t.chatRequestBubbleRadius, const Radius.circular(12));
      expect(t.chatResponseBubbleRadius, const Radius.circular(4));
      expect(t.chatBubbleShowAuthorAvatar, isTrue);
      expect(t.chatBubbleShowAuthorName, isTrue);
      expect(t.chatBubbleShowTimestamp, isFalse);
      expect(t.chatToolAccentColor, const Color(0xFFFF9800));
      expect(t.chatCapabilityAccents, isNotNull);
      expect(t.chatBusyPalette, isNotNull);
    });
  });

  group('🔴 CR-IFFD-72 — `lerp` : null-PRÉSERVANT, et discret là où il faut',
      () {
    test('`null` ↔ `null` reste `null` — la référence IFFD n\'est JAMAIS '
        'matérialisée par une transition', () {
      const ZcrudTheme a = ZcrudTheme();
      const ZcrudTheme b = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        final ZcrudTheme l = a.lerp(b, t);
        expect(l.chatBubbleWidthFactor, isNull, reason: 't=$t');
        expect(l.chatRequestBubbleRadius, isNull, reason: 't=$t');
        expect(l.chatResponseBubbleRadius, isNull, reason: 't=$t');
        expect(l.chatBubbleShowAuthorAvatar, isNull, reason: 't=$t');
        expect(l.chatBubbleShowAuthorName, isNull, reason: 't=$t');
        expect(l.chatBubbleShowTimestamp, isNull, reason: 't=$t');
        expect(l.chatToolAccentColor, isNull, reason: 't=$t');
        expect(l.chatCapabilityAccents, isNull, reason: 't=$t');
        expect(l.chatBusyPalette, isNull, reason: 't=$t');
      }
    });

    test('les valeurs CONTINUES s\'interpolent, les DISCRÈTES basculent', () {
      const ZcrudTheme a = ZcrudTheme(
        chatBubbleWidthFactor: 0,
        chatRequestBubbleRadius: Radius.circular(0),
        chatBubbleShowAuthorAvatar: false,
        chatBusyPalette: <Color>[Color(0xFF000000)],
      );
      const ZcrudTheme b = ZcrudTheme(
        chatBubbleWidthFactor: 1,
        chatRequestBubbleRadius: Radius.circular(10),
        chatBubbleShowAuthorAvatar: true,
        chatBusyPalette: <Color>[Color(0xFFFFFFFF)],
      );
      final ZcrudTheme mid = a.lerp(b, 0.5);
      expect(mid.chatBubbleWidthFactor, closeTo(0.5, 1e-9));
      expect(mid.chatRequestBubbleRadius, const Radius.circular(5));
      // Un booléen et une SÉQUENCE ne s'interpolent pas : ni demi-avatar, ni
      // demi-palette.
      expect(mid.chatBubbleShowAuthorAvatar, isTrue);
      expect(mid.chatBusyPalette, <Color>[const Color(0xFFFFFFFF)]);
      expect(a.lerp(b, 0.25).chatBubbleShowAuthorAvatar,
          isFalse);
      expect(a.lerp(b, 0.25).chatBusyPalette,
          <Color>[const Color(0xFF000000)]);
    });

    test('un jeton posé d\'UN SEUL côté n\'est pas effacé au bout de la '
        'transition', () {
      const ZcrudTheme a = ZcrudTheme(chatToolAccentColor: Color(0xFFFF9800));
      const ZcrudTheme b = ZcrudTheme();
      expect(a.lerp(b, 0).chatToolAccentColor,
          const Color(0xFFFF9800));
      expect(a.lerp(b, 1).chatToolAccentColor?.a, 0);
    });
  });

  group('🔴 CR-IFFD-72 — le jeton est bien LU par `ZcrudTheme.of`', () {
    testWidgets('un jeton posé par `ZcrudScope` survit à la résolution',
        (WidgetTester tester) async {
      late ZcrudTheme seen;
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            theme: const ZcrudTheme(chatBubbleWidthFactor: 0.42),
            child: Builder(
              builder: (BuildContext context) {
                seen = ZcrudTheme.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(seen.chatBubbleWidthFactor, 0.42);
    });

    testWidgets('…et sans jeton, `of` ne fabrique AUCUNE valeur de chat',
        (WidgetTester tester) async {
      late ZcrudTheme seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              seen = ZcrudTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // 🔴 Le repli `ZcrudTheme.fallback` ne doit dériver aucun jeton de chat :
      // sinon le skin ne pourrait jamais atteindre son niveau 3.
      expect(seen.chatBubbleWidthFactor, isNull);
      expect(seen.chatToolAccentColor, isNull);
      expect(seen.chatCapabilityAccents, isNull);
      expect(seen.chatBusyPalette, isNull);
    });
  });
}
