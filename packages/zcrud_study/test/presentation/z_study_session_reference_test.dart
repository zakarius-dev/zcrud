/// **Lot 1 « étude »** — `ZStudySessionReference` / `zStudySessionChromeOf` :
/// la chaîne de priorité, champ par champ, et FR-26.
///
/// 🔒 **Égalités EXACTES, jamais un `contains`.** Une garde qui vérifierait
/// « le chrome contient bien une valeur » serait verte sur n'importe quelle
/// valeur — y compris celle du mauvais maillon.
///
/// ⚠️ **Chaîne d'aujourd'hui : `paramètre > référence`.** Les jetons
/// `ZcrudTheme.studySession*` n'existent pas encore (`zcrud_core` appartient à
/// un autre lot) ; le test le CONSTATE (cf. le dernier groupe) au lieu de faire
/// semblant de tester un maillon absent.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

void main() {
  /// Résout le chrome dans un contexte RÉEL (le résolveur lit `Theme.of`).
  Future<ZStudySessionChrome> resolve(
    WidgetTester tester, {
    int? stackFlex,
    int? inputFlex,
    EdgeInsetsGeometry? contentPadding,
    double? dividerThickness,
    double? sectionGap,
    double? minTarget,
    TextStyle? counterStyle,
    ThemeData? theme,
  }) async {
    late ZStudySessionChrome chrome;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (BuildContext context) {
            chrome = zStudySessionChromeOf(
              context,
              stackFlex: stackFlex,
              inputFlex: inputFlex,
              contentPadding: contentPadding,
              dividerThickness: dividerThickness,
              sectionGap: sectionGap,
              minTarget: minTarget,
              counterStyle: counterStyle,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return chrome;
  }

  group('sans paramètre ⇒ les valeurs de RÉFÉRENCE, champ par champ', () {
    testWidgets('chaque champ dimensionnel vaut EXACTEMENT sa référence',
        (tester) async {
      final ZStudySessionChrome c = await resolve(tester);
      expect(c.stackFlex, ZStudySessionReference.stackFlex);
      expect(c.inputFlex, ZStudySessionReference.inputFlex);
      expect(c.contentPadding, ZStudySessionReference.contentPadding);
      expect(c.dividerThickness, ZStudySessionReference.dividerThickness);
      expect(c.sectionGap, ZStudySessionReference.sectionGap);
      expect(c.minTarget, ZStudySessionReference.minTarget);
    });

    testWidgets(
        '🔴 les valeurs de référence sont celles RELEVÉES sur l\'assemblage '
        'd\'origine (elles ne dérivent pas en silence)', (tester) async {
      // Ancrage littéral : si quelqu'un « ajuste » une référence, ce test le
      // dit. Une référence sans ancrage n'est plus une référence, c'est un
      // défaut arbitraire.
      expect(ZStudySessionReference.stackFlex, 3,
          reason: 'study_session_demo_screen.dart:487');
      expect(ZStudySessionReference.inputFlex, 2,
          reason: 'study_session_demo_screen.dart:506');
      expect(ZStudySessionReference.dividerThickness, 1,
          reason: 'study_session_demo_screen.dart:504');
      expect(ZStudySessionReference.sectionGap, 12,
          reason: 'study_session_demo_screen.dart:474');
      expect(ZStudySessionReference.contentPadding,
          const EdgeInsetsDirectional.all(12),
          reason: 'study_session_demo_screen.dart:439/:508');
      expect(ZStudySessionReference.minTarget, 48, reason: 'AD-13');
    });
  });

  group('🔴 le PARAMÈTRE l\'emporte — champ par champ, aucun oublié', () {
    testWidgets('chaque paramètre surcharge RÉELLEMENT sa référence',
        (tester) async {
      const EdgeInsetsGeometry pad = EdgeInsetsDirectional.all(31);
      const TextStyle style = TextStyle(letterSpacing: 3.5);
      final ZStudySessionChrome c = await resolve(
        tester,
        stackFlex: 7,
        inputFlex: 9,
        contentPadding: pad,
        dividerThickness: 4,
        sectionGap: 33,
        minTarget: 64,
        counterStyle: style,
      );
      expect(c.stackFlex, 7);
      expect(c.inputFlex, 9);
      expect(c.contentPadding, pad);
      expect(c.dividerThickness, 4);
      expect(c.sectionGap, 33);
      expect(c.minTarget, 64);
      expect(c.counterStyle, style);

      // 🔬 …et aucune de ces valeurs n'est la référence : sans ce contrôle, un
      // paramètre dont la valeur coïnciderait avec la référence rendrait le
      // test vert sur un résolveur qui IGNORE le paramètre.
      expect(c.stackFlex, isNot(ZStudySessionReference.stackFlex));
      expect(c.inputFlex, isNot(ZStudySessionReference.inputFlex));
      expect(c.contentPadding, isNot(ZStudySessionReference.contentPadding));
      expect(
          c.dividerThickness, isNot(ZStudySessionReference.dividerThickness));
      expect(c.sectionGap, isNot(ZStudySessionReference.sectionGap));
      expect(c.minTarget, isNot(ZStudySessionReference.minTarget));
    });
  });

  group('🔴 FR-26 — toute couleur est un RÔLE du `ColorScheme`', () {
    testWidgets('les couleurs suivent le schéma, elles ne sont pas figées',
        (tester) async {
      final ThemeData clair = ThemeData(
        colorScheme: const ColorScheme.light(
          outlineVariant: Color(0xFF112233),
          onSurfaceVariant: Color(0xFF445566),
          primary: Color(0xFF778899),
        ),
      );
      final ZStudySessionChrome c = await resolve(tester, theme: clair);
      expect(c.dividerColor, const Color(0xFF112233));
      expect(c.secondaryTextColor, const Color(0xFF445566));
      expect(c.accentColor, const Color(0xFF778899));
    });

    testWidgets(
        '🔬 un AUTRE schéma rend d\'AUTRES couleurs (la garde ne lit pas une '
        'constante)', (tester) async {
      final ThemeData sombre = ThemeData(
        colorScheme: const ColorScheme.dark(
          outlineVariant: Color(0xFFAABBCC),
          onSurfaceVariant: Color(0xFFDDEEFF),
          primary: Color(0xFF010203),
        ),
      );
      final ZStudySessionChrome c = await resolve(tester, theme: sombre);
      expect(c.dividerColor, const Color(0xFFAABBCC));
      expect(c.secondaryTextColor, const Color(0xFFDDEEFF));
      expect(c.accentColor, const Color(0xFF010203));
    });

    test(
        '🔴 le fichier de référence ne porte AUCUNE couleur littérale — et il '
        'n\'est PAS exempté de la garde couleur', () {
      const String path = 'lib/src/presentation/z_study_session_reference.dart';
      final File file = File(path);
      expect(file.existsSync(), isTrue,
          reason: 'introuvable: $path (cwd=${Directory.current.path}) — '
              'lancer `flutter test` DEPUIS le package');
      final List<String> offenders = <String>[];
      final List<String> lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final String trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
        for (final String motif in <String>['Colors.', 'Color(0x']) {
          if (lines[i].contains(motif)) {
            offenders.add('$path:${i + 1} → $motif');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 ce fichier tient sur les seuls RÔLES du `ColorScheme` : '
              'aucune exemption FR-26 n\'a été demandée pour lui, et la garde '
              '`z_widgets_hardcode_scan_test.dart` doit rester verte dessus '
              'SANS exception.\n${offenders.join('\n')}');
    });
  });

  group('🔗 le maillon JETON — branché, et gardé branché', () {
    // 🔬 Ce groupe était un TRIPWIRE : il assertait l'ABSENCE des jetons
    // `studySession*` et portait, dans son propre message d'échec, l'action à
    // mener le jour où ils apparaîtraient. Ils ont été posés dans `zcrud_core`
    // (7 jetons, 4 sites chacun) ; le tripwire a rougi, il a désigné le
    // maillon manquant, et il est ici CONVERTI en garde de la propriété qu'il
    // annonçait — plutôt que retiré. Un tripwire qu'on supprime laisse la
    // propriété sans surveillance.
    test('les 7 jetons existent dans `ZcrudTheme`', () {
      final File theme = File(
        '../zcrud_core/lib/src/presentation/theme/z_theme.dart',
      );
      expect(theme.existsSync(), isTrue,
          reason: 'sonde cassée : le fichier de thème est introuvable depuis '
              '${Directory.current.path}');
      final String src = theme.readAsStringSync();
      for (final String token in _kStudySessionTokens) {
        expect(src, contains('studySession$token'),
            reason: '🔴 le jeton `studySession$token` a disparu de '
                '`ZcrudTheme` : le maillon du milieu de '
                '`zStudySessionChromeOf` ne résout plus rien.');
      }
    });

    test(
        '`zStudySessionChromeOf` intercale CHAQUE jeton entre le paramètre et '
        'la référence', () {
      final File src = File(
        'lib/src/presentation/z_study_session_reference.dart',
      );
      expect(src.existsSync(), isTrue, reason: 'sonde cassée');
      final String body = src.readAsStringSync();
      for (final String token in _kStudySessionTokens) {
        expect(body, contains('theme.studySession$token'),
            reason: '🔴 le maillon JETON de `studySession$token` a sauté : la '
                'chaîne retomberait à `paramètre > référence`, et un hôte qui '
                'thématise son écran de session ne serait plus entendu.');
      }
    });
  });
}

/// Les sept jetons de l'écran de session, suffixe seul (le préfixe
/// `studySession` est ajouté par les gardes). Source unique : toute évolution
/// de la famille se déclare ICI, et les deux gardes suivent.
const List<String> _kStudySessionTokens = <String>[
  'StackFlex',
  'InputFlex',
  'ContentPadding',
  'DividerThickness',
  'SectionGap',
  'MinTarget',
  'CounterStyle',
];
