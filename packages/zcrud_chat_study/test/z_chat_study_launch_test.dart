/// Gardes de la sélection de modes du parcours « Commencer à apprendre ».
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat_study/zcrud_chat_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  test('exactement 3 modes sont offerts, dans l\'ordre des tuiles IFFD', () {
    expect(kZChatStudyLaunchModes, <ZReviewMode>[
      ZReviewMode.learn,
      ZReviewMode.spaced,
      ZReviewMode.whiteExam,
    ]);
  });

  test('le mode MORT d\'IFFD (`cramming`) n\'est PAS porté', () {
    // Chez IFFD, `cramming` n'a AUCUN site de construction : la seule tuile qui
    // le produisait est entièrement en commentaire. Le porter reviendrait à
    // ressusciter du code mort dans le socle.
    expect(zIsChatStudyLaunchMode(ZReviewMode.cramming), isFalse);
  });

  test('`list` n\'est pas un mode de session et n\'est pas porté au CTA', () {
    // `listOnly` est la valeur PAR DÉFAUT d'un paramètre de page chez IFFD,
    // utilisée par les écrans de liste/édition — pas une session d'étude.
    expect(zIsChatStudyLaunchMode(ZReviewMode.list), isFalse);
  });

  test('`test` n\'est pas porté au CTA (décalage libellé/enum d\'IFFD)', () {
    // 🔴 Chez IFFD la tuile « Test » construit `whiteExam`, et c'est la tuile
    // « à réviser » qui construit `.test`. Porter par le LIBELLÉ échangerait
    // deux modes. Ce test fige la lecture du CODE, pas celle de l'UI.
    expect(zIsChatStudyLaunchMode(ZReviewMode.test), isFalse);
    expect(zIsChatStudyLaunchMode(ZReviewMode.whiteExam), isTrue);
    expect(zIsChatStudyLaunchMode(ZReviewMode.spaced), isTrue);
  });

  test(
      'PARTITION EXHAUSTIVE — toute valeur de ZReviewMode est classée '
      '(offerte XOR non-offerte)', () {
    // Sans cette garde, l'ajout d'une 7e valeur à `ZReviewMode` la laisserait
    // silencieusement hors du parcours ET hors de la liste d'exclusion — donc
    // hors de toute décision. Ici, elle fait ROUGIR.
    final Set<ZReviewMode> offered = kZChatStudyLaunchModes.toSet();

    expect(offered.intersection(kZChatStudyModesNotLaunched), isEmpty);
    expect(
      offered.union(kZChatStudyModesNotLaunched),
      ZReviewMode.values.toSet(),
      reason: 'une valeur de ZReviewMode n\'est classée nulle part',
    );
  });

  test('aucun doublon dans la liste offerte', () {
    expect(kZChatStudyLaunchModes.toSet(), hasLength(kZChatStudyLaunchModes.length));
  });
}
