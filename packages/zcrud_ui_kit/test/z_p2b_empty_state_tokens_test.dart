/// `ZEmptyState` : la boucle **jeton → pixel** est fermée.
///
/// Chaque garde pose UN jeton (ou UN paramètre) et mesure la valeur
/// effectivement rendue sur le widget qui peint — jamais un intermédiaire.
/// Une garde qui vérifierait que le style est « résolu » sans regarder l'arbre
/// mesurerait `zcrud_core`, pas ce paquet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

Widget _host(Widget child, {ZcrudTheme? tokens}) => MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF3366AA),
  ),
  home: ZcrudScope(
    theme: tokens,
    child: Scaffold(body: child),
  ),
);

/// Hauteurs des `SizedBox` d'espacement posés par l'ossature, dans l'ordre de
/// l'arbre.
///
/// Le filtre `width == null` écarte le `SizedBox` interne d'`Icon` (qui porte
/// largeur ET hauteur) : sans lui la garde mesurerait la taille du glyphe au
/// milieu du rythme, donc deux propriétés à la fois.
List<double?> _gaps(WidgetTester tester, Type root) => tester
    .widgetList<SizedBox>(
      find.descendant(of: find.byType(root), matching: find.byType(SizedBox)),
    )
    .where((SizedBox b) => b.width == null)
    .map((SizedBox b) => b.height)
    .toList();

void main() {
  group('P2-B — jeton posé ⇒ valeur lue', () {
    testWidgets('emptyStateIconSize ⇒ taille du glyphe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ZEmptyState(icon: Icons.inbox_outlined, message: 'Vide'),
          tokens: const ZcrudTheme(emptyStateIconSize: 40),
        ),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).size, 40);
    });

    testWidgets('emptyStateIconColor ⇒ couleur du glyphe', (
      WidgetTester tester,
    ) async {
      const Color tint = Color(0xFF00A0B0);
      await tester.pumpWidget(
        _host(
          const ZEmptyState(icon: Icons.inbox_outlined, message: 'Vide'),
          tokens: const ZcrudTheme(emptyStateIconColor: tint),
        ),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).color, tint);
    });

    testWidgets('emptyStateTitleStyle / emptyStateMessageStyle ⇒ styles', (
      WidgetTester tester,
    ) async {
      const TextStyle titleStyle = TextStyle(fontSize: 33);
      const TextStyle messageStyle = TextStyle(fontSize: 11);
      await tester.pumpWidget(
        _host(
          const ZEmptyState(title: 'T', message: 'M'),
          tokens: const ZcrudTheme(
            emptyStateTitleStyle: titleStyle,
            emptyStateMessageStyle: messageStyle,
          ),
        ),
      );
      expect(tester.widget<Text>(find.text('T')).style, titleStyle);
      expect(tester.widget<Text>(find.text('M')).style, messageStyle);
    });

    testWidgets('emptyStateSpacing ⇒ rythme principal (l\'écart '
        'titre→message reste interne)', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          ZEmptyState(
            icon: Icons.inbox_outlined,
            title: 'T',
            message: 'M',
            actionLabel: 'A',
            onAction: () {},
          ),
          tokens: const ZcrudTheme(emptyStateSpacing: 32),
        ),
      );
      // Ordre de l'arbre : glyphe→texte, titre→message, bloc→action.
      expect(_gaps(tester, ZEmptyState), <double>[32, 8, 32]);
    });

    testWidgets('aucun jeton ⇒ rythme de référence (16 / 8 / 16)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZEmptyState(
            icon: Icons.inbox_outlined,
            title: 'T',
            message: 'M',
            actionLabel: 'A',
            onAction: () {},
          ),
        ),
      );
      expect(_gaps(tester, ZEmptyState), <double>[16, 8, 16]);
    });
  });

  group('P2-B — priorité paramètre > jeton > défaut', () {
    testWidgets('iconSize l\'emporte sur emptyStateIconSize', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ZEmptyState(
            icon: Icons.inbox_outlined,
            message: 'Vide',
            iconSize: 64,
          ),
          tokens: const ZcrudTheme(emptyStateIconSize: 40),
        ),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).size, 64);
    });

    testWidgets('sans paramètre ni jeton ⇒ 48 dp', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const ZEmptyState(icon: Icons.inbox_outlined, message: 'Vide')),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).size, 48);
    });
  });

  group('P2-B — illustration', () {
    testWidgets('illustration fournie ⇒ AUCUNE icône, illustration présente', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ZEmptyState(
            // L'icône est fournie ET ignorée : c'est la règle qu'on mesure.
            icon: Icons.inbox_outlined,
            illustration: SizedBox(key: ValueKey<String>('illu'), height: 80),
            message: 'Vide',
          ),
        ),
      );
      expect(find.byType(Icon), findsNothing);
      expect(find.byKey(const ValueKey<String>('illu')), findsOneWidget);
    });

    testWidgets('sans illustration ⇒ le glyphe reste rendu', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const ZEmptyState(icon: Icons.inbox_outlined, message: 'Vide')),
      );
      expect(find.byType(Icon), findsOneWidget);
    });
  });

  group('P2-B — table par nature : ZEmptyState.fromSpec', () {
    testWidgets('les clés sont résolues par le registre de libellés', (
      WidgetTester tester,
    ) async {
      final ZcrudLabels labels = ZcrudLabels(<String, String>{
        'folders.empty.title': 'Aucun dossier',
        'folders.empty.message': 'Créez-en un pour commencer.',
        'folders.empty.action': 'Nouveau dossier',
      });
      await tester.pumpWidget(
        _host(
          ZEmptyState.fromSpec(
            const ZEmptyStateSpec(
              iconData: Icons.folder_outlined,
              titleKey: 'folders.empty.title',
              messageKey: 'folders.empty.message',
              actionLabelKey: 'folders.empty.action',
            ),
            labels,
            onAction: () {},
          ),
        ),
      );
      expect(find.text('Aucun dossier'), findsOneWidget);
      expect(find.text('Créez-en un pour commencer.'), findsOneWidget);
      expect(find.text('Nouveau dossier'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        Icons.folder_outlined,
      );
    });

    testWidgets('clé absente ⇒ la clé elle-même, jamais un throw', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZEmptyState.fromSpec(
            const ZEmptyStateSpec(
              titleKey: 'notes.empty.title',
              messageKey: 'notes.empty.message',
            ),
            ZcrudLabels.empty,
          ),
        ),
      );
      expect(find.text('notes.empty.title'), findsOneWidget);
      expect(find.text('notes.empty.message'), findsOneWidget);
    });

    testWidgets('action déclarée sans onAction ⇒ AUCUN bouton', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZEmptyState.fromSpec(
            const ZEmptyStateSpec(
              titleKey: 't',
              messageKey: 'm',
              actionLabelKey: 'a',
            ),
            ZcrudLabels.empty,
          ),
        ),
      );
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('illustrationBuilder de la spec ⇒ rendu à la place du glyphe', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZEmptyState.fromSpec(
            ZEmptyStateSpec(
              iconData: Icons.folder_outlined,
              titleKey: 't',
              messageKey: 'm',
              illustrationBuilder: (BuildContext context) => const SizedBox(
                key: ValueKey<String>('spec-illu'),
                height: 60,
              ),
            ),
            ZcrudLabels.empty,
          ),
        ),
      );
      expect(find.byType(Icon), findsNothing);
      expect(find.byKey(const ValueKey<String>('spec-illu')), findsOneWidget);
    });
  });

  group('P2-B — variante dense', () {
    testWidgets('compact ⇒ retrait 12 dp et rythme divisé par deux', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZEmptyState(
            icon: Icons.inbox_outlined,
            title: 'T',
            message: 'M',
            actionLabel: 'A',
            onAction: () {},
            compact: true,
          ),
        ),
      );
      final Padding pad = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(ZEmptyState),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(pad.padding, const EdgeInsetsDirectional.all(12));
      expect(_gaps(tester, ZEmptyState), <double>[8, 4, 8]);
    });
  });

  group(
    'P2-B — isolation : les jetons emptyState* NE touchent PAS l\'erreur',
    () {
      testWidgets('ZErrorState garde 48 dp et son rythme malgré les jetons', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _host(
            const ZErrorState(message: 'Boum'),
            tokens: const ZcrudTheme(
              emptyStateIconSize: 40,
              emptyStateSpacing: 32,
              emptyStateMessageStyle: TextStyle(fontSize: 11),
            ),
          ),
        );
        expect(tester.widget<Icon>(find.byType(Icon)).size, 48);
        expect(_gaps(tester, ZErrorState), <double>[16]);
        expect(
          tester.widget<Text>(find.text('Boum')).style?.fontSize,
          isNot(11),
        );
      });
    },
  );
}
