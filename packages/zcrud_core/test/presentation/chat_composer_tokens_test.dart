/// Lot K4 (chantier composer-lex) — les 10 jetons du chrome du composer et de
/// l'emphase de sélection (CR-IFFD-74), et leurs règles de `lerp`.
///
/// Le câblage aux 4 sites est tenu par `z_theme_four_sites_guard_test.dart`
/// (structurel) ; ici on mesure les PROPRIÉTÉS de transition :
/// * **K4-L1** — un PLANCHER/une ÉCHELLE ne matérialise jamais `0` en
///   transition (le générique `_lerpNullableDouble` rend 0 — précédent
///   `studySessionMinTarget`) ;
/// * **K4-L2** — un SEUIL est DISCRET à `t = 0.5` (précédent
///   `dailyTasksMonthBreakpoint`, correctif v0.54.1 né d'un lerp continu
///   tagué rouge) ;
/// * **K4-L3** — une DURÉE ne matérialise jamais `Duration.zero` ;
/// * **K4-L4** — la graisse d'emphase ne matérialise jamais `w400` (le
///   substitut de `FontWeight.lerp` sur un côté `null`) : la sélection
///   visible survivrait sinon mal à une transition de thème ;
/// * **K4-L5** — table d'accents et décoration sont discrètes ;
/// * **K4-N** — `null` des deux côtés reste `null` (la référence du
///   consommateur n'est jamais matérialisée) ;
/// * **K4-C** — `copyWith` transporte chaque jeton (valeur ET omission).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  const ZcrudTheme empty = ZcrudTheme();

  group('K4-L1 — planchers et échelles : jamais 0 en transition', () {
    test('sendTargetSize : null↔48 rend 48, jamais un 24 intermédiaire', () {
      const ZcrudTheme b = ZcrudTheme(chatComposerSendTargetSize: 48);
      for (final double t in <double>[0, .25, .5, .75, 1]) {
        expect(
          empty.lerp(b, t).chatComposerSendTargetSize,
          48,
          reason: '🔴 t=$t : un côté null doit rendre l\'AUTRE côté — un lerp '
              'depuis 0 ferait passer la cible sous le plancher AD-13',
        );
        expect(b.lerp(empty, t).chatComposerSendTargetSize, 48);
      }
    });

    test('les deux échelles d\'envoi : null↔valeur ne traverse jamais 0', () {
      const ZcrudTheme b = ZcrudTheme(
        chatComposerSendScaleIdle: 0.7,
        chatComposerSendScaleActive: 1,
      );
      final ZcrudTheme mid = empty.lerp(b, .5);
      expect(mid.chatComposerSendScaleIdle, 0.7,
          reason: '🔴 une échelle interpolée depuis 0 rend le glyphe '
              'invisible en transition');
      expect(mid.chatComposerSendScaleActive, 1);
    });

    test('deux valeurs CONNUES s\'interpolent réellement', () {
      const ZcrudTheme a = ZcrudTheme(chatComposerSendTargetSize: 48);
      const ZcrudTheme b = ZcrudTheme(chatComposerSendTargetSize: 56);
      expect(a.lerp(b, .5).chatComposerSendTargetSize, 52,
          reason: '🔴 le repli « rendre l\'autre côté » ne doit pas avoir '
              'remplacé l\'interpolation des cas pleins');
    });
  });

  group('K4-L2 — le breakpoint est un SEUIL : DISCRET', () {
    const ZcrudTheme a = ZcrudTheme(chatComposerMobileBreakpoint: 400);
    const ZcrudTheme b = ZcrudTheme(chatComposerMobileBreakpoint: 600);

    test('aucune valeur intermédiaire n\'existe', () {
      expect(a.lerp(b, .49).chatComposerMobileBreakpoint, 400);
      expect(a.lerp(b, .5).chatComposerMobileBreakpoint, 600,
          reason: '🔴 un breakpoint interpolé continûment fait basculer la '
              'mise en page plusieurs fois pendant la transition (précédent '
              'v0.54.1)');
      expect(a.lerp(b, .75).chatComposerMobileBreakpoint, isNot(450));
    });
  });

  group('K4-L3 — les 3 durées : jamais Duration.zero matérialisé', () {
    test('null↔valeur rend la valeur, à tout t', () {
      const ZcrudTheme b = ZcrudTheme(
        chatComposerSendScaleDuration: Duration(milliseconds: 150),
        chatComposerHintRotationPeriod: Duration(seconds: 4),
        chatComposerHintSwitchDuration: Duration(milliseconds: 350),
      );
      for (final double t in <double>[0, .5, 1]) {
        final ZcrudTheme m = empty.lerp(b, t);
        expect(m.chatComposerSendScaleDuration,
            const Duration(milliseconds: 150),
            reason: '🔴 t=$t : Duration.zero matérialisé');
        expect(m.chatComposerHintRotationPeriod, const Duration(seconds: 4));
        expect(
            m.chatComposerHintSwitchDuration,
            const Duration(milliseconds: 350));
      }
    });
  });

  group('K4-L4 — la graisse d\'emphase : jamais w400 substitué', () {
    test('null↔w700 rend w700 — la sélection reste visible en transition', () {
      const ZcrudTheme b = ZcrudTheme(
        chatSelectedEmphasisWeight: FontWeight.w700,
      );
      for (final double t in <double>[0, .25, .5, .75, 1]) {
        expect(
          empty.lerp(b, t).chatSelectedEmphasisWeight,
          FontWeight.w700,
          reason: '🔴 t=$t : `FontWeight.lerp` a substitué w400 au côté null '
              '— l\'option choisie repasserait par une graisse NORMALE '
              '(le défaut CR-IFFD-74)',
        );
      }
    });

    test('deux graisses CONNUES s\'interpolent réellement', () {
      const ZcrudTheme a = ZcrudTheme(
        chatSelectedEmphasisWeight: FontWeight.w400,
      );
      const ZcrudTheme b = ZcrudTheme(
        chatSelectedEmphasisWeight: FontWeight.w800,
      );
      expect(a.lerp(b, .5).chatSelectedEmphasisWeight, FontWeight.w600);
    });
  });

  group('K4-L5 — table et décoration : discrètes', () {
    test('chatResponseLengthAccents bascule en bloc à t=.5', () {
      const Map<String, Color> tableA = <String, Color>{
        'concise': Color(0xFF000001),
      };
      const Map<String, Color> tableB = <String, Color>{
        'concise': Color(0xFF000002),
        'standard': Color(0xFF000003),
      };
      const ZcrudTheme a = ZcrudTheme(chatResponseLengthAccents: tableA);
      const ZcrudTheme b = ZcrudTheme(chatResponseLengthAccents: tableB);
      expect(a.lerp(b, .49).chatResponseLengthAccents, same(tableA));
      expect(a.lerp(b, .5).chatResponseLengthAccents, same(tableB),
          reason: '🔴 pas de demi-palette — même règle que '
              '`chatCapabilityAccents`');
    });

    test('chatSelectedEmphasisDecoration bascule à t=.5', () {
      const ZcrudTheme a = ZcrudTheme(
        chatSelectedEmphasisDecoration: TextDecoration.underline,
      );
      const ZcrudTheme b = ZcrudTheme(
        chatSelectedEmphasisDecoration: TextDecoration.overline,
      );
      expect(
          a.lerp(b, .49).chatSelectedEmphasisDecoration,
          TextDecoration.underline);
      expect(
          a.lerp(b, .5).chatSelectedEmphasisDecoration,
          TextDecoration.overline);
    });
  });

  group('K4-N — null des deux côtés RESTE null', () {
    test('la référence du consommateur n\'est jamais matérialisée', () {
      final ZcrudTheme mid = empty.lerp(const ZcrudTheme(), .5);
      expect(mid.chatComposerSendTargetSize, isNull);
      expect(mid.chatComposerSendScaleIdle, isNull);
      expect(mid.chatComposerSendScaleActive, isNull);
      expect(mid.chatComposerSendScaleDuration, isNull);
      expect(mid.chatComposerMobileBreakpoint, isNull);
      expect(mid.chatComposerHintRotationPeriod, isNull);
      expect(mid.chatComposerHintSwitchDuration, isNull);
      expect(mid.chatResponseLengthAccents, isNull);
      expect(mid.chatSelectedEmphasisWeight, isNull);
      expect(mid.chatSelectedEmphasisDecoration, isNull);
    });
  });

  group('K4-C — copyWith transporte les 10 jetons', () {
    const Map<String, Color> accents = <String, Color>{
      'detailed': Color(0xFF000004),
    };
    const ZcrudTheme full = ZcrudTheme(
      chatComposerSendTargetSize: 52,
      chatComposerSendScaleIdle: 0.6,
      chatComposerSendScaleActive: 1.1,
      chatComposerSendScaleDuration: Duration(milliseconds: 200),
      chatComposerMobileBreakpoint: 500,
      chatComposerHintRotationPeriod: Duration(seconds: 5),
      chatComposerHintSwitchDuration: Duration(milliseconds: 400),
      chatResponseLengthAccents: accents,
      chatSelectedEmphasisWeight: FontWeight.w600,
      chatSelectedEmphasisDecoration: TextDecoration.overline,
    );

    test('une copie SANS argument conserve chaque valeur', () {
      final ZcrudTheme copy = full.copyWith();
      expect(copy.chatComposerSendTargetSize, 52);
      expect(copy.chatComposerSendScaleIdle, 0.6);
      expect(copy.chatComposerSendScaleActive, 1.1);
      expect(
          copy.chatComposerSendScaleDuration,
          const Duration(milliseconds: 200));
      expect(copy.chatComposerMobileBreakpoint, 500);
      expect(copy.chatComposerHintRotationPeriod, const Duration(seconds: 5));
      expect(
          copy.chatComposerHintSwitchDuration,
          const Duration(milliseconds: 400));
      expect(copy.chatResponseLengthAccents, same(accents));
      expect(copy.chatSelectedEmphasisWeight, FontWeight.w600);
      expect(copy.chatSelectedEmphasisDecoration, TextDecoration.overline);
    });

    test('une copie CIBLÉE ne touche que son jeton', () {
      final ZcrudTheme copy = empty.copyWith(
        chatComposerMobileBreakpoint: 640,
      );
      expect(copy.chatComposerMobileBreakpoint, 640);
      expect(copy.chatComposerSendTargetSize, isNull);
      expect(copy.chatSelectedEmphasisWeight, isNull);
    });

    test('une copie par ARGUMENTS pose chaque jeton (l\'argument n\'est pas '
        'ignoré)', () {
      // 🔴 Sans ce volet, un `copyWith` qui écrirait `this.x` en ignorant
      // l'argument `x` resterait VERT : la copie sans argument conserve, la
      // garde des 4 sites voit `x:` présent — seul un argument réellement
      // PASSÉ le démasque (le piège exact que la garde documente).
      final ZcrudTheme copy = empty.copyWith(
        chatComposerSendTargetSize: 52,
        chatComposerSendScaleIdle: 0.6,
        chatComposerSendScaleActive: 1.1,
        chatComposerSendScaleDuration: const Duration(milliseconds: 200),
        chatComposerMobileBreakpoint: 500,
        chatComposerHintRotationPeriod: const Duration(seconds: 5),
        chatComposerHintSwitchDuration: const Duration(milliseconds: 400),
        chatResponseLengthAccents: accents,
        chatSelectedEmphasisWeight: FontWeight.w600,
        chatSelectedEmphasisDecoration: TextDecoration.overline,
      );
      expect(copy.chatComposerSendTargetSize, 52);
      expect(copy.chatComposerSendScaleIdle, 0.6);
      expect(copy.chatComposerSendScaleActive, 1.1);
      expect(copy.chatComposerSendScaleDuration,
          const Duration(milliseconds: 200));
      expect(copy.chatComposerMobileBreakpoint, 500);
      expect(copy.chatComposerHintRotationPeriod, const Duration(seconds: 5));
      expect(copy.chatComposerHintSwitchDuration,
          const Duration(milliseconds: 400));
      expect(copy.chatResponseLengthAccents, same(accents));
      expect(copy.chatSelectedEmphasisWeight, FontWeight.w600);
      expect(copy.chatSelectedEmphasisDecoration, TextDecoration.overline);
    });
  });
}
