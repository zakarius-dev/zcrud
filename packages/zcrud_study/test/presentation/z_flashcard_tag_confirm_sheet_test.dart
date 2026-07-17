// SU-9/AC9 — feuille de confirmation de tags : réutilise ZTagEditor, pré-cochage
// éditable (ajout/retrait/décochage), aucune persistance, id null.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZFlashcardTag, ZSuggestedTag;

Widget _harness(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 800, height: 800, child: child)),
    );

ZFlashcardTagConfirmSheet _sheet({
  required void Function(List<ZFlashcardTag>) onConfirmed,
  List<ZSuggestedTag> suggested = const <ZSuggestedTag>[],
}) =>
    ZFlashcardTagConfirmSheet(
      title: 'Tags',
      confirmLabel: 'Confirmer',
      cancelLabel: 'Annuler',
      inputLabel: 'Nom du tag',
      inputHint: 'Ajouter un tag',
      addSemanticLabel: 'Ajouter le tag',
      suggestedTags: suggested,
      onConfirmed: onConfirmed,
    );

void main() {
  testWidgets('réutilise ZTagEditor (jamais un second éditeur)', (tester) async {
    await tester.pumpWidget(_harness(_sheet(onConfirmed: (_) {})));
    expect(find.byType(ZTagEditor), findsOneWidget);
  });

  testWidgets('tags suggérés PRÉ-COCHÉS et confirmés avec id null (AC9)',
      (tester) async {
    List<ZFlashcardTag>? confirmed;
    await tester.pumpWidget(_harness(_sheet(
      onConfirmed: (t) => confirmed = t,
      suggested: const <ZSuggestedTag>[
        ZSuggestedTag(title: 'algèbre'),
        ZSuggestedTag(title: 'géométrie'),
      ],
    )));
    await tester.tap(find.byKey(const ValueKey<String>('z-tag-confirm-apply')));
    await tester.pump();
    expect(confirmed, isNotNull);
    expect(confirmed!.map((t) => t.title), containsAll(<String>['algèbre', 'géométrie']));
    expect(confirmed!.every((t) => t.id == null), isTrue,
        reason: 'matérialisés par le repository app-side (AD-14), jamais ici');
  });

  testWidgets('DÉCOCHER un tag pré-coché le retire de l\'ensemble retenu',
      (tester) async {
    List<ZFlashcardTag>? confirmed;
    await tester.pumpWidget(_harness(_sheet(
      onConfirmed: (t) => confirmed = t,
      suggested: const <ZSuggestedTag>[ZSuggestedTag(title: 'algèbre')],
    )));
    // La puce pré-cochée porte un bouton de retrait (ZTagChips) — le décochage.
    await tester.tap(find.bySemanticsLabel('Supprimer le tag algèbre'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('z-tag-confirm-apply')));
    await tester.pump();
    expect(confirmed, isEmpty,
        reason: 'un tag décoché n\'est plus dans l\'ensemble retenu');
  });
}
