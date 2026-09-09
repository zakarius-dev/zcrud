/// 🧊 INERTIE ABSOLUE des quatre réglages de forme de la surface de saisie.
///
/// Sans AUCUN réglage ni AUCUN jeton, la surface doit rendre exactement ce
/// qu'elle rendait avant leur existence — arbre **et** matière peinte.
///
/// ⚠️ Les montages de cette suite n'ÉNONCENT AUCUN des quatre paramètres.
/// Les énoncer « à leur valeur neutre » court-circuiterait le défaut du
/// constructeur : on mesurerait la valeur écrite par le test, pas celle que
/// résout la surface.
///
/// Les dumps sont figés AVANT le lot (`test/support/*_before_lots1_*.txt`) et
/// comparés à l'ÉGALITÉ STRICTE de la suite `(widget, clé)` — jamais un
/// `contains`, jamais un `length >=`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import 'z_answer_input_harness.dart';

List<String> _signature(WidgetTester tester) => tester.allWidgets
    .map(
      (w) =>
          '${w.runtimeType}|${w.key}'.replaceAll(RegExp(r'#[0-9a-f]{5}'), '#…'),
    )
    .toList();

List<String> _frozen(String name) => File(
  'test/support/$name',
).readAsLinesSync().where((l) => l.isNotEmpty).toList();

/// Toutes les `Material` du sous-arbre, dans l'ordre de l'arbre.
List<Material> _materials(WidgetTester tester) =>
    tester.widgetList<Material>(find.byType(Material)).toList();

void main() {
  group('🧊 arbre IDENTIQUE au dump figé d\'avant le lot', () {
    testWidgets('QCM — choix, soumission, indice, « je ne sais pas »', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmSingle(),
            mode: ZReviewMode.learn,
            onQualitySelected: (_) {},
            hintPort: SlowHintPort(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final List<String> expected = _frozen(
        'z_answer_input_tree_before_lots1_qcm.txt',
      );
      expect(expected, isNotEmpty, reason: 'dump figé absent');
      expect(
        _signature(tester),
        expected,
        reason:
            '🔴 égalité STRICTE de la suite (widget, clé) — un seul nœud '
            'ajouté sans réglage suffit à rompre l\'inertie',
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('rédigée — champ, soumission', (tester) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(hint: 'un indice'),
            mode: ZReviewMode.learn,
            onQualitySelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final List<String> expected = _frozen(
        'z_answer_input_tree_before_lots1_written.txt',
      );
      expect(expected, isNotEmpty, reason: 'dump figé absent');
      expect(_signature(tester), expected);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('🧊 MATIÈRE peinte identique — aucune tuile, aucun pourtour', () {
    testWidgets(
      'aucune `Material` de la surface ne porte de `shape` : ni cadre de '
      'tuile, ni pourtour tracé',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: qcmSingle(),
              mode: ZReviewMode.learn,
              onQualitySelected: (_) {},
              hintPort: SlowHintPort(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final List<Material> materials = _materials(tester);
        // Le compteur doit être PLAUSIBLE : une garde qui n'inspecte rien
        // serait verte sur tout.
        expect(
          materials.length,
          greaterThanOrEqualTo(3),
          reason: '🔴 aucune `Material` trouvée — garde INERTE',
        );
        expect(
          materials.where((Material m) => m.shape != null),
          isEmpty,
          reason:
              '🔴 une `shape` apparaît sans qu\'aucun réglage ne l\'ait '
              'demandée : c\'est un cadre de tuile ou un pourtour tracé, donc '
              'une rupture d\'inertie de la MATIÈRE que l\'égalité d\'arbre '
              'ne voit pas (le type de widget est le même)',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'la rangée de paliers est ABSENTE avant la soumission (ordre des '
      'gestes strictement inchangé)',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: qcmSingle(),
              mode: ZReviewMode.learn,
              onQualitySelected: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ZSrsQualityButtons), findsNothing);
        expect(find.byKey(K.submit), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('la soumission garde la largeur de son contenu', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmSingle(),
            mode: ZReviewMode.learn,
            onQualitySelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ZFlashcardAnswerInput.submitFullWidthKey),
        findsNothing,
      );
      final double surface = tester
          .getSize(find.byType(ZFlashcardAnswerInput))
          .width;
      expect(
        tester.getSize(find.byKey(K.submit)).width,
        lessThan(surface),
        reason: '🔴 la soumission occupe déjà toute la largeur SANS réglage',
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'les deux contrôles d\'aide restent EMPILÉS (aucune ligne partagée)',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: qcmSingle(),
              mode: ZReviewMode.learn,
              onQualitySelected: (_) {},
              hintPort: SlowHintPort(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(ZFlashcardAnswerInput.actionsRowKey), findsNothing);
        final Rect hint = tester.getRect(find.byKey(K.hintButton));
        final Rect dontKnow = tester.getRect(find.byKey(K.dontKnow));
        expect(
          dontKnow.top,
          greaterThanOrEqualTo(hint.bottom),
          reason: '🔴 les deux contrôles partagent une ligne SANS réglage',
        );

        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
