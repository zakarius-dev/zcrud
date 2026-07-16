import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: child),
  );
}

void main() {
  for (final entry in <String, ThemeData>{
    'light': ThemeData.light(),
    'dark': ThemeData.dark(),
  }.entries) {
    final label = entry.key;
    final theme = entry.value;

    group('ZEmptyState ($label)', () {
      testWidgets('rend icône + titre + message + CTA', (tester) async {
        var tapped = false;
        await tester.pumpWidget(_wrap(
          ZEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Rien ici',
            message: 'Aucun élément',
            actionLabel: 'Ajouter',
            onAction: () => tapped = true,
          ),
          theme: theme,
        ));

        expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
        expect(find.text('Rien ici'), findsOneWidget);
        expect(find.text('Aucun élément'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Ajouter'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Ajouter'));
        expect(tapped, isTrue);
      });

      testWidgets('texte présent même sans icône (jamais seul canal)',
          (tester) async {
        await tester.pumpWidget(_wrap(
          const ZEmptyState(message: 'Vide'),
          theme: theme,
        ));
        expect(find.text('Vide'), findsOneWidget);
        // Pas de CTA quand onAction est absent.
        expect(find.byType(TextButton), findsNothing);
      });
    });

    group('ZLoadingState ($label)', () {
      testWidgets('rend un indicateur + message optionnel + Semantics',
          (tester) async {
        await tester.pumpWidget(_wrap(
          const ZLoadingState(message: 'Chargement…'),
          theme: theme,
        ));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Chargement…'), findsOneWidget);
      });

      testWidgets('sans message → Semantics annonce le chargement (a11y M1)',
          (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_wrap(const ZLoadingState(), theme: theme));
        // Repli par défaut de `ZContentStateView` : aucun message visible, mais
        // le lecteur d'écran DOIT entendre le chargement — `Semantics.label`
        // jamais nul (dérivé de la l10n injectée, repli « Loading… »). Test
        // PORTEUR : avec l'ancien `label: message` (null), aucun label ne
        // correspondrait.
        expect(
          find.bySemanticsLabel(RegExp('Loading|Chargement')),
          findsOneWidget,
        );
        handle.dispose();
      });
    });

    group('ZErrorState ($label)', () {
      testWidgets('rend icône + message + CTA réessayer', (tester) async {
        var retried = false;
        await tester.pumpWidget(_wrap(
          ZErrorState(
            message: 'Échec',
            title: 'Erreur',
            retryLabel: 'Réessayer',
            onRetry: () => retried = true,
          ),
          theme: theme,
        ));

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Erreur'), findsOneWidget);
        expect(find.text('Échec'), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, 'Réessayer'));
        expect(retried, isTrue);
      });

      testWidgets('teinte icône dérivée de ColorScheme.error', (tester) async {
        await tester.pumpWidget(_wrap(
          const ZErrorState(message: 'Échec'),
          theme: theme,
        ));
        final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
        expect(icon.color, theme.colorScheme.error);
      });
    });
  }
}
