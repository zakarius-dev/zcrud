/// `ZSessionSummaryView` face à un verdict d'examen blanc.
///
/// Quatre propriétés, chacune rejouée ROUGE PAR ASSERTION sur une injection
/// ciblée dans `lib/`, restaurée par copie :
///
/// 1. **inertie absolue** sans verdict — l'arbre est comparé à un DUMP FIGÉ,
///    capturé sur le code d'AVANT le lot (`test/support/
///    z_summary_tree_before_p1c.txt`) puis restauré ; pas un `contains`, pas un
///    `>=` : l'égalité stricte de la suite des widgets et de leurs clés ;
/// 2. un verdict **réussi** monte la célébration avec la **durée du jeton de
///    thème**, pas la durée par défaut du fichier ;
/// 3. les couleurs de la bande de verdict viennent du **profil de référence** :
///    palette signature sous `legacy`, rôles M3 sous `neutral` ;
/// 4. un verdict **manqué** n'allume **aucune** célébration, même demandée.
///
/// Plus une garde de source (FR-26) : aucun seuil ni libellé de verdict en dur
/// dans `lib/`.
@TestOn('vm')
library;

import 'dart:io';

// Importer `confetti` DANS UN TEST ne viole pas le confinement : la garde de
// confinement scanne `lib/`. C'est en lisant le controller RÉELLEMENT passé au
// widget qu'on tient la durée effectivement montée.
import 'package:confetti/confetti.dart' show ConfettiWidget;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySessionResult;

/// Corpus commun — 7 correctes sur 10.
const ZStudySessionResult _result = ZStudySessionResult(
  total: 10,
  correct: 7,
  byQuality: <String, int>{'0': 1, '2': 2, '3': 3, '4': 3, '5': 1},
);

/// Verdict RÉUSSI (dérivé du corpus à la main : 7/10 ≥ 0,7).
const ZWhiteExamVerdict _passed = ZWhiteExamVerdict(
  passed: true,
  ratio: 0.7,
  correct: 7,
  total: 10,
);

/// Verdict MANQUÉ (6/10 < 0,7).
const ZWhiteExamVerdict _failed = ZWhiteExamVerdict(
  passed: false,
  ratio: 0.6,
  correct: 6,
  total: 10,
);

/// Graine de thème du test — la garde de couleurs compare aux rôles de CE
/// `ColorScheme`, jamais à une valeur écrite en dur.
const Color _seed = Color(0xFF3355AA);

ColorScheme _scheme() => ColorScheme.fromSeed(seedColor: _seed);

/// Signature d'arbre : la suite exacte des widgets montés et de leurs clés.
///
/// Les identités d'instance (`#a1b2c`) sont neutralisées — elles changent d'un
/// run à l'autre sans que l'arbre change. Rien d'autre n'est normalisé.
List<String> _treeSignature(WidgetTester tester) => tester.allWidgets
    .map(
      (w) =>
          '${w.runtimeType}|${w.key}'.replaceAll(RegExp(r'#[0-9a-f]{5}'), '#…'),
    )
    .toList();

/// L'écran monté **exactement** comme au moment de la capture du dump figé.
Future<void> _pumpFrozenHarness(
  WidgetTester tester, {
  ZWhiteExamVerdict? verdict,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZSessionSummaryView(
          result: _result,
          duration: const Duration(minutes: 3, seconds: 25),
          config: const ZSrsConfig(),
          onFinish: () {},
          dueRemaining: 3,
          onContinue: () {},
          celebration: ZSummaryCelebration.subtle,
          feedbackKey: 'zcrud.session.feedback.great',
          verdict: verdict,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _pumpScoped(
  WidgetTester tester, {
  ZWhiteExamVerdict? verdict,
  ZSummaryCelebration celebration = ZSummaryCelebration.none,
  ZcrudTheme? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorScheme: _scheme()),
      home: Scaffold(
        body: ZcrudScope(
          theme: theme,
          child: ZSessionSummaryView(
            result: _result,
            duration: const Duration(minutes: 3, seconds: 25),
            config: const ZSrsConfig(),
            onFinish: () {},
            celebration: celebration,
            verdict: verdict,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Sources de `lib/**` débarrassées de leurs commentaires (une dartdoc a le
/// droit de CITER un seuil d'exemple ; le code n'a pas le droit d'en porter un).
Map<String, String> _libCode() {
  final dir = Directory('lib');
  expect(
    dir.existsSync(),
    isTrue,
    reason: 'répertoire lib introuvable (cwd=${Directory.current.path})',
  );
  final out = <String, String>{};
  for (final file in dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final buffer = StringBuffer();
    var inBlockComment = false;
    for (var line in file.readAsLinesSync()) {
      var trimmed = line.trim();
      if (inBlockComment) {
        if (!trimmed.contains('*/')) continue;
        inBlockComment = false;
        trimmed = trimmed.substring(trimmed.indexOf('*/') + 2).trim();
      }
      if (trimmed.startsWith('/*')) {
        if (!trimmed.contains('*/')) {
          inBlockComment = true;
          continue;
        }
        trimmed = trimmed.substring(trimmed.indexOf('*/') + 2).trim();
      }
      if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
      final slash = trimmed.indexOf('//');
      if (slash >= 0) trimmed = trimmed.substring(0, slash).trim();
      if (trimmed.isEmpty) continue;
      buffer.writeln(trimmed);
    }
    out[file.path] = buffer.toString();
  }
  expect(out, isNotEmpty, reason: 'aucune source scannée');
  return out;
}

void main() {
  group('🧊 Inertie absolue — sans verdict, RIEN ne bouge', () {
    testWidgets(
      'I1 — l\'arbre monté sans verdict est IDENTIQUE au dump figé d\'AVANT le lot',
      (tester) async {
        await _pumpFrozenHarness(tester);

        final expected = File(
          'test/support/z_summary_tree_before_p1c.txt',
        ).readAsLinesSync().where((l) => l.isNotEmpty).toList();
        expect(
          expected,
          isNotEmpty,
          reason: 'le dump figé doit exister — sans lui la garde ne mesure rien',
        );

        expect(
          _treeSignature(tester),
          expected,
          reason:
              'ATTRAPE : le moindre nœud ajouté, retiré ou déplacé par ce lot '
              'sur le chemin SANS verdict. Égalité STRICTE de la suite '
              '(widget, clé) — jamais un `contains`, jamais un `length >=`',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('🎉 Un verdict réussi célèbre — avec le jeton de thème', () {
    testWidgets(
      'C1 — verdict réussi : célébration montée, durée = celle du JETON (≠ défaut)',
      (tester) async {
        // Posée à la main, et volontairement DIFFÉRENTE de la durée par défaut
        // du fichier (800 ms) : une garde calée sur le défaut ne prouverait
        // pas que le jeton est lu.
        const token = Duration(milliseconds: 1234);
        await _pumpScoped(
          tester,
          verdict: _passed,
          theme: const ZcrudTheme(celebrationDuration: token),
        );

        expect(
          find.byKey(ZSessionSummaryView.trophyIconKey),
          findsOneWidget,
          reason:
              'ATTRAPE : un verdict réussi qui ne déclenche RIEN — l\'hôte '
              'devrait alors demander lui-même la célébration',
        );
        final confetti = tester.widget<ConfettiWidget>(
          find.byType(ConfettiWidget),
        );
        expect(
          confetti.confettiController.duration,
          token,
          reason:
              'ATTRAPE : une durée en dur, ou la lecture du défaut du fichier '
              'au lieu du jeton `ZcrudTheme.celebrationDuration`',
        );

        // Preuve par POMPAGE : la célébration vit encore APRÈS la durée par
        // défaut (800 ms) — c'est bien la durée POSÉE qui court.
        await tester.pump(const Duration(milliseconds: 900));
        expect(find.byType(ConfettiWidget), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'C2 — verdict réussi : la variante EXPLICITE de l\'hôte est respectée',
      (tester) async {
        await _pumpScoped(
          tester,
          verdict: _passed,
          celebration: ZSummaryCelebration.subtle,
        );

        expect(find.byKey(ZSessionSummaryView.trophyIconKey), findsOneWidget);
        expect(
          find.byType(ConfettiWidget),
          findsNothing,
          reason:
              'ATTRAPE : un verdict qui ÉCRASE le choix explicite de l\'hôte '
              '— `subtle` demandé, confetti imposé',
        );
      },
    );
  });

  group('🎨 Couleurs du verdict — profil de référence, jamais un hex', () {
    testWidgets('K1 — profil `neutral` : rôles M3 EXACTS', (tester) async {
      await _pumpScoped(
        tester,
        verdict: _passed,
        theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.neutral),
      );

      final container = tester.widget<Container>(
        find.byKey(ZSessionSummaryView.verdictKey),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(
        decoration.gradient,
        isNull,
        reason:
            'ATTRAPE : la référence auditée peinte sous un profil NEUTRE — '
            'le profil neutre existe précisément pour ne rien peindre d\'elle',
      );
      expect(
        decoration.color,
        _scheme().primaryContainer,
        reason:
            'ATTRAPE : un autre rôle (ou une couleur en dur) — l\'attendu est '
            'le rôle EXACT du `ColorScheme` du thème monté',
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ZSessionSummaryView.verdictKey),
          matching: find.byType(Text),
        ),
      );
      expect(text.style!.color, _scheme().onPrimaryContainer);
    });

    testWidgets('🔴 K1b — DÉFAUT du socle : indiscernable du profil `neutral`',
        (tester) async {
      // Aucun profil déclaré : le socle rend son défaut, qui est `neutral`.
      await _pumpScoped(tester, verdict: _passed);
      final decoration = tester
          .widget<Container>(find.byKey(ZSessionSummaryView.verdictKey))
          .decoration! as BoxDecoration;
      expect(
        decoration.gradient,
        isNull,
        reason: '🔴 la référence auditée est peinte sans profil déclaré : le '
            'défaut du socle a dérivé vers `legacy`',
      );
      expect(decoration.color, _scheme().primaryContainer);
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ZSessionSummaryView.verdictKey),
          matching: find.byType(Text),
        ),
      );
      expect(text.style!.color, _scheme().onPrimaryContainer);
    });

    testWidgets('K2 — profil `legacy` EXPLICITE : palette signature EXACTE', (
      tester,
    ) async {
      await _pumpScoped(
        tester,
        verdict: _passed,
        theme: const ZcrudTheme(referenceProfile: ZReferenceProfile.legacy),
      );

      // Identité écrite À LA MAIN : jamais lue de la constante du widget.
      final signature = zSignatureGradientFor('zcrud.session.summary.verdict');
      expect(signature, isNotNull);

      final container = tester.widget<Container>(
        find.byKey(ZSessionSummaryView.verdictKey),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(
        decoration.gradient,
        signature!.gradient,
        reason:
            'ATTRAPE : un dégradé qui n\'est PAS celui de la palette signature '
            'auditée — ou un profil neutre appliqué par défaut',
      );
      expect(decoration.color, isNull);
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ZSessionSummaryView.verdictKey),
          matching: find.byType(Text),
        ),
      );
      expect(text.style!.color, signature.onGradient);
    });
  });

  group('🚫 Un verdict manqué ne fête rien', () {
    testWidgets(
      'E1 — verdict manqué : AUCUNE célébration, même explicitement demandée',
      (tester) async {
        await _pumpScoped(
          tester,
          verdict: _failed,
          celebration: ZSummaryCelebration.confetti,
        );
        await tester.pump(const Duration(milliseconds: 700));

        expect(
          find.byType(ConfettiWidget),
          findsNothing,
          reason:
              'ATTRAPE : des confettis sur un échec — la pire régression '
              'possible de cet écran',
        );
        expect(
          find.byKey(ZSessionSummaryView.trophyIconKey),
          findsNothing,
          reason: 'ATTRAPE : le trophée monté malgré un verdict manqué',
        );
      },
    );

    testWidgets('E2 — verdict manqué : le libellé d\'échec est rendu, SANS '
        'couleur sémantique inventée', (tester) async {
      await _pumpScoped(tester, verdict: _failed);

      final node = find.byKey(ZSessionSummaryView.verdictKey);
      expect(node, findsOneWidget);
      expect(
        tester.widget(node),
        isA<Text>(),
        reason:
            'ATTRAPE : une bande colorée sur un échec — l\'échec est dit par '
            'le TEXTE, pas par une couleur d\'alerte inventée ici',
      );
      final text = tester.widget<Text>(node);
      expect(text.data, isNotEmpty);
      // Le style est celui du thème AMBIANT, tel quel : aucun `copyWith` de
      // couleur. C'est la formulation exacte de « aucune couleur sémantique
      // inventée » — asserter `color == null` serait faux (le thème en pose
      // une, et c'est la sienne).
      final ambient = Theme.of(tester.element(node));
      expect(
        text.style,
        ambient.textTheme.titleMedium,
        reason:
            'ATTRAPE : une couleur sémantique (erreur/rouge) posée sur '
            'l\'échec — ce paquet n\'en décide aucune, il rend le style du '
            'thème sans y toucher',
      );
      expect(
        text.style!.color,
        isNot(_scheme().error),
        reason: 'ATTRAPE : le rôle d\'erreur détourné en verdict',
      );
      expect(text.style!.color, isNot(_scheme().onErrorContainer));
    });
  });

  group('🔒 FR-26 — aucun seuil ni libellé de verdict en dur dans lib/', () {
    test('S1 — aucun littéral `0.7` ni `70` dans le CODE de lib/', () {
      // Le seuil de réussite est une donnée de l'application : sa valeur ne
      // doit exister nulle part dans le socle, pas même en repli.
      final banned = <RegExp>[
        RegExp(r'(?<![\d.])0\.7(?![\d])'),
        RegExp(r'(?<![\d.])70(?![\d])'),
      ];
      final violations = <String>[];
      _libCode().forEach((path, code) {
        for (final line in code.split('\n')) {
          for (final pattern in banned) {
            if (pattern.hasMatch(line)) {
              violations.add('$path :: ${line.trim()}');
            }
          }
        }
      });
      expect(
        violations,
        isEmpty,
        reason:
            'ATTRAPE : un seuil de réussite écrit dans le socle (`0.7`, `70`) '
            '— il appartient à l\'application, qui le déclare',
      );
    });

    test('S2 — les libellés du verdict passent par le mécanisme l10n', () {
      final code = _libCode()['lib/src/presentation/z_session_summary_view.dart'];
      expect(code, isNotNull);
      // Chaque clé n'est consommée que dans un appel `label(`.
      for (final key in <String>[
        'verdictPassedLabelKey',
        'verdictFailedLabelKey',
      ]) {
        final uses = code!
            .split('\n')
            .where((l) => l.contains('ZSessionSummaryView.$key'))
            .toList();
        expect(
          uses,
          isNotEmpty,
          reason: 'la clé $key doit être consommée quelque part',
        );
      }
      expect(
        code!.contains('label('),
        isTrue,
        reason:
            'ATTRAPE : un libellé de verdict rendu en dur au lieu de passer '
            'par `label(context, clé, fallback:)`',
      );
    });
  });
}
