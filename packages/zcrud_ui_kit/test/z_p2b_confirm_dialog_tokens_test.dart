/// `showZConfirmDialog` : jetons `confirmDialog*` lus, créneaux à leur place.
///
/// Le régime de nullité du dialogue diffère de celui de l'état vide : les
/// jetons sont **transportés `null`** jusqu'à `AlertDialog`, qui suit alors le
/// `DialogTheme`. Les gardes mesurent donc ce qui arrive sur l'`AlertDialog`,
/// pas une valeur que le socle aurait inventée en chemin.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

const Color _seed = Color(0xFF3366AA);

ColorScheme get _scheme => ColorScheme.fromSeed(seedColor: _seed);

/// Monte un hôte et ouvre le dialogue, en rendant le contexte disponible.
Future<void> _open(
  WidgetTester tester, {
  ZcrudTheme? tokens,
  String? title = 'Titre',
  String message = 'Question ?',
  Widget? content,
  Widget? icon,
  ZConfirmTone tone = ZConfirmTone.neutral,
  bool barrierDismissible = true,
  void Function(bool)? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: _seed),
      home: ZcrudScope(
        theme: tokens,
        child: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                final bool r = await showZConfirmDialog(
                  context,
                  title: title,
                  message: message,
                  content: content,
                  icon: icon,
                  tone: tone,
                  barrierDismissible: barrierDismissible,
                );
                onResult?.call(r);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

AlertDialog _dialog(WidgetTester tester) =>
    tester.widget<AlertDialog>(find.byType(AlertDialog));

Color? _confirmBackground(WidgetTester tester) => tester
    .widget<FilledButton>(find.byType(FilledButton))
    .style
    ?.backgroundColor
    ?.resolve(<WidgetState>{});

Color? _confirmForeground(WidgetTester tester) => tester
    .widget<FilledButton>(find.byType(FilledButton))
    .style
    ?.foregroundColor
    ?.resolve(<WidgetState>{});

void main() {
  group('P2-B — jeton posé ⇒ valeur lue (dialogue)', () {
    testWidgets('shape / styles / actionsPadding sont transmis TELS QUELS', (
      WidgetTester tester,
    ) async {
      const ShapeBorder shape = StadiumBorder();
      const TextStyle titleStyle = TextStyle(fontSize: 29);
      const TextStyle contentStyle = TextStyle(fontSize: 13);
      const EdgeInsetsGeometry actions = EdgeInsetsDirectional.all(7);
      await _open(
        tester,
        tokens: const ZcrudTheme(
          confirmDialogShape: shape,
          confirmDialogTitleStyle: titleStyle,
          confirmDialogContentStyle: contentStyle,
          confirmDialogActionsPadding: actions,
        ),
      );
      final AlertDialog d = _dialog(tester);
      expect(d.shape, shape);
      expect(d.titleTextStyle, titleStyle);
      expect(d.contentTextStyle, contentStyle);
      expect(d.actionsPadding, actions);
    });

    testWidgets('aucun jeton ⇒ les quatre membres restent null (le '
        'DialogTheme reste maître)', (WidgetTester tester) async {
      await _open(tester);
      final AlertDialog d = _dialog(tester);
      expect(d.shape, isNull);
      expect(d.titleTextStyle, isNull);
      expect(d.contentTextStyle, isNull);
      expect(d.actionsPadding, isNull);
    });
  });

  group('P2-B — action destructive', () {
    testWidgets('confirmDialogDestructiveColor ⇒ fond de la confirmation', (
      WidgetTester tester,
    ) async {
      const Color destructive = Color(0xFF8B0000);
      await _open(
        tester,
        tone: ZConfirmTone.destructive,
        tokens: const ZcrudTheme(confirmDialogDestructiveColor: destructive),
      );
      expect(_confirmBackground(tester), destructive);
    });

    testWidgets('sans jeton ⇒ ColorScheme.error', (WidgetTester tester) async {
      await _open(tester, tone: ZConfirmTone.destructive);
      expect(_confirmBackground(tester), _scheme.error);
      // Inertie du premier plan : `onError` intact, jamais recalculé.
      expect(_confirmForeground(tester), _scheme.onError);
    });

    testWidgets('le jeton destructif NE fuit PAS sur la tonalité neutre', (
      WidgetTester tester,
    ) async {
      await _open(
        tester,
        tokens: const ZcrudTheme(
          confirmDialogDestructiveColor: Color(0xFF8B0000),
        ),
      );
      expect(_confirmBackground(tester), _scheme.primary);
    });

    testWidgets('jeton clair ⇒ le premier plan est REMONTÉ au plancher de '
        'lisibilité (pas laissé à onError)', (WidgetTester tester) async {
      // Un jaune très clair : `onError` (blanc) y serait illisible.
      const Color pale = Color(0xFFFFF3B0);
      await _open(
        tester,
        tone: ZConfirmTone.destructive,
        tokens: const ZcrudTheme(confirmDialogDestructiveColor: pale),
      );
      final Color fg = _confirmForeground(tester)!;
      expect(fg, isNot(_scheme.onError));
      expect(zContrastRatio(fg, pale), greaterThanOrEqualTo(3.0));
    });
  });

  group('P2-B — créneaux', () {
    testWidgets('icon atterrit sur AlertDialog.icon, pas ailleurs', (
      WidgetTester tester,
    ) async {
      const Widget glyph = Icon(
        Icons.warning_amber_outlined,
        key: ValueKey<String>('glyph'),
      );
      await _open(tester, icon: glyph);
      expect(_dialog(tester).icon, same(glyph));
      expect(find.byKey(const ValueKey<String>('glyph')), findsOneWidget);
    });

    testWidgets('content REMPLACE le rendu du message', (
      WidgetTester tester,
    ) async {
      const Widget body = SizedBox(key: ValueKey<String>('body'), height: 40);
      await _open(tester, content: body);
      expect(_dialog(tester).content, same(body));
      expect(find.text('Question ?'), findsNothing);
    });

    testWidgets('content posé et titre absent ⇒ le message reste le libellé '
        'sémantique du dialogue', (WidgetTester tester) async {
      await _open(tester, title: null, content: const SizedBox(height: 40));
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is Semantics && w.properties.label == 'Question ?',
        ),
        findsWidgets,
      );
    });

    testWidgets('sans créneau ⇒ le message est rendu en texte', (
      WidgetTester tester,
    ) async {
      await _open(tester);
      expect(find.text('Question ?'), findsOneWidget);
      expect(_dialog(tester).icon, isNull);
    });
  });

  group('P2-B — barrierDismissible', () {
    testWidgets('false ⇒ le voile ne ferme pas le dialogue', (
      WidgetTester tester,
    ) async {
      await _open(tester, barrierDismissible: false);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('true (défaut) ⇒ le voile ferme et la décision vaut false', (
      WidgetTester tester,
    ) async {
      bool? result;
      await _open(tester, onResult: (bool r) => result = r);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(result, isFalse);
    });
  });
}
