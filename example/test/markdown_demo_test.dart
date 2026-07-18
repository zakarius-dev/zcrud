import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_example/demos/markdown_demo_screen.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import 'support/pump_helpers.dart';

// PÉRIMÈTRE DE COUVERTURE (Finding LOW-2) — ce test de DÉMO couvre l'INTÉGRATION
// de `ZMarkdownField` dans l'app-vitrine : montage du champ (contrôleur isolé,
// AD-7), valeur persistée lisible et bascule de codec (Delta ↔ Markdown). La
// couverture PROFONDE de l'éditeur — frappe réelle avec focus, embeds LaTeX/
// tableau insérés depuis la toolbar (AC3), Quill interne — est portée par les
// ~155 tests du PACKAGE `zcrud_markdown` (E6), et n'est PAS re-jouée ici :
// l'écran de démo n'ajoute pas de logique d'édition, il ne fait qu'assembler le
// champ + la voie de persistance publique (`persistedValueOf`). L'édition est
// donc simulée via la tranche neutre (Delta JSON) — voie de persistance publique
// du `ZFormController` — plutôt que par frappe Quill (redondante avec E6).
void main() {
  // AC3 — l'écran Markdown monte un ZMarkdownField (contrôleur isolé), affiche la
  // valeur persistée et bascule le codec.
  testWidgets('AC3 — édition Markdown : édite → valeur persistée + switch codec',
      (tester) async {
    await tester.pumpWidget(wrapForTest(const MarkdownDemoScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownDemoScreen), findsOneWidget);
    expect(find.byType(ZMarkdownField), findsOneWidget);

    // Récupère le `ZFormController` isolé porté par le champ (voie de persistance
    // publique) et simule une édition en écrivant la tranche neutre (Delta JSON).
    final field = tester.widget<ZMarkdownField>(find.byType(ZMarkdownField));
    // `ZMarkdownField.controller` est nullable dans le type (voie `ctx`/registre
    // le laisse à `null`), mais `MarkdownDemoScreen` monte le champ via la voie
    // `controller` (constructeur par défaut, paramètre `required`) — non-null ici.
    final controller = field.controller!;
    controller.setValue('body', <Map<String, dynamic>>[
      <String, dynamic>{'insert': 'Bonjour zcrud\n'},
    ]);
    await tester.pump();

    // La zone read-only affiche la valeur persistée encodée (Delta par défaut).
    expect(find.textContaining('Bonjour zcrud'), findsOneWidget);

    // Bascule le codec vers Markdown → le champ se re-monte (Key) et la valeur
    // persistée est ré-encodée (String Markdown), toujours porteuse du contenu.
    await tester.tap(find.text('Markdown'));
    await tester.pumpAndSettle();
    expect(find.byType(ZMarkdownField), findsOneWidget);
    expect(find.textContaining('Bonjour zcrud'), findsOneWidget);
  });
}
