/// Gardes IFFD : slots hôte de type et de consigne de la carte de révision.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

import 'support/z_sources.dart' as zsrc;

const _badgePadding = EdgeInsetsDirectional.symmetric(
  horizontal: 9,
  vertical: 4,
);
const _badgeRadius = Radius.circular(11);
const _badgeIconSize = 18.0;
const _gradient = ZGradientSpec(
  gradient: LinearGradient(colors: <Color>[Color(1), Color(2)]),
  onGradient: Color(3),
);

Widget _host({
  ZFlashcardQuestionTypeBadgeBuilder? questionTypeBadgeBuilder,
  Widget? instructionBanner,
  TextDirection textDirection = TextDirection.ltr,
}) => MaterialApp(
  home: ZcrudScope(
    theme: const ZcrudTheme(
      countPillPadding: _badgePadding,
      countPillRadius: _badgeRadius,
      countPillIconSize: _badgeIconSize,
      gradientBegin: AlignmentDirectional.topStart,
      gradientEnd: AlignmentDirectional.bottomEnd,
    ),
    gradientResolver: (ColorScheme _, String key) => _gradient,
    child: Directionality(
      textDirection: textDirection,
      child: Scaffold(
        body: ZFlashcardReviewCard(
          card: const ZFlashcard(
            question: 'Question',
            answer: 'Réponse',
            type: ZFlashcardType.multipleChoice,
          ),
          questionTypeBadgeBuilder: questionTypeBadgeBuilder,
          instructionBanner: instructionBanner,
        ),
      ),
    ),
  ),
);

void main() {
  test(
    'aucune table de libellés de type ne vit dans les sources du package',
    () {
      // 🔴 STRIPPÉ (support/z_sources.dart) : la dartdoc peut citer « 'QCM' »
      // pour documenter que l'hôte fournit le libellé — seul un littéral dans
      // le CODE doit rougir.
      final source = zsrc.strippedSource(File(
        'lib/src/presentation/z_flashcard_review_card.dart',
      ));
      const forbiddenLabels = <String>[
        'QCM',
        'Vrai/Faux',
        'Question ouverte',
        'Cas pratique',
        'Choisissez la bonne reponse',
        'Redigez votre reponse',
      ];

      for (final label in forbiddenLabels) {
        expect(
          RegExp("['\\\"]${RegExp.escape(label)}['\\\"]").hasMatch(source),
          isFalse,
          reason:
              'un libellé traduit (« $label ») ne peut pas vivre dans '
              'zcrud_flashcard : l’hôte le fournit par slot',
        );
      }
    },
  );

  testWidgets('les deux slots null sont structurellement absents', (
    tester,
  ) async {
    await tester.pumpWidget(_host());

    expect(find.byKey(ZFlashcardReviewCard.questionTypeBadgeKey), findsNothing);
    expect(find.byKey(ZFlashcardReviewCard.instructionBannerKey), findsNothing);
  });

  testWidgets('le badge reçoit le type et rend le libellé localisé de l’hôte', (
    tester,
  ) async {
    ZFlashcardType? receivedType;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        questionTypeBadgeBuilder: (BuildContext context, ZFlashcardType type) {
          receivedType = type;
          return Semantics(label: 'Type : QCM', child: const Text('QCM'));
        },
        instructionBanner: Semantics(
          label: 'Consigne : choisissez une réponse',
          child: const Text('Choisissez la bonne réponse'),
        ),
      ),
    );

    expect(receivedType, ZFlashcardType.multipleChoice);
    expect(find.text('QCM'), findsOneWidget);
    expect(find.text('Choisissez la bonne réponse'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Type : QCM')),
      findsOneWidget,
      reason: 'le type est une information annoncée, pas une décoration',
    );
    handle.dispose();
  });

  testWidgets('le chrome du badge suit les tokens et le gradient de l’hôte', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        questionTypeBadgeBuilder: (BuildContext context, ZFlashcardType type) =>
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[Icon(Icons.help_outline), Text('Badge')],
            ),
      ),
    );

    final badge = tester.widget<Container>(
      find.byKey(ZFlashcardReviewCard.questionTypeBadgeKey),
    );
    final decoration = badge.decoration! as BoxDecoration;
    expect(badge.padding, _badgePadding);
    expect(decoration.borderRadius, const BorderRadius.all(_badgeRadius));
    expect(
      (decoration.gradient! as LinearGradient).colors,
      _gradient.gradient.colors,
    );
    final iconContext = tester.element(find.byIcon(Icons.help_outline));
    expect(IconTheme.of(iconContext).size, _badgeIconSize);
  });

  testWidgets('le badge conserve un alignement directionnel en RTL', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        textDirection: TextDirection.rtl,
        questionTypeBadgeBuilder: (BuildContext context, ZFlashcardType type) =>
            const Text('QCM'),
      ),
    );

    final align = tester.widget<Align>(
      find.ancestor(
        of: find.byKey(ZFlashcardReviewCard.questionTypeBadgeKey),
        matching: find.byType(Align),
      ),
    );
    expect(
      (align.alignment as AlignmentDirectional).resolve(TextDirection.rtl),
      Alignment.centerRight,
    );
  });
}
