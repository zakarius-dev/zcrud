/// Inertie ABSOLUE de `ZEmptyState` et du dialogue de confirmation.
///
/// Les empreintes ci-dessous ont été FIGÉES avant que le lot ne touche à
/// `lib/` : elles décrivent le rendu tel qu'il était, au widget près, au pixel
/// près et à la couleur près. Brancher les jetons `emptyState*` /
/// `confirmDialog*` ne doit rien changer tant qu'aucun jeton n'est posé — un
/// hôte qui met à jour sans rien déclarer doit obtenir exactement le même
/// écran.
///
/// L'égalité est STRICTE (jamais `contains`) : une garde d'inertie qui
/// tolérerait un widget de plus resterait verte au moment précis où l'inertie
/// se perd.
///
/// Cause de rouge légitime autre qu'une régression : une montée de version du
/// SDK Flutter qui renomme un widget interne d'`AlertDialog`. Le remède est
/// alors de re-figer l'empreinte, jamais de relâcher la comparaison.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

import 'support/z_tree_signature.dart';

/// Thème déterministe : une graine fixe rend le `ColorScheme` reproductible.
ThemeData _theme() =>
    ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF3366AA));

const String _kEmptySignature = '''
ZEmptyState
  _ZStateScaffold
    Center
      Padding [pad=EdgeInsetsDirectional(24.0, 24.0, 24.0, 24.0)]
        Column [main=MainAxisSize.min cross=CrossAxisAlignment.center]
          Semantics [label=Titre. Message container=true]
            ExcludeSemantics
              Column [main=MainAxisSize.min cross=CrossAxisAlignment.center]
                Icon [icon=61734 size=48.0 color=Color(alpha: 1.0000, red: 0.2627, green: 0.2784, blue: 0.3059, colorSpace: ColorSpace.sRGB)]
                SizedBox [w=null h=16.0]
                Text [data=Titre align=TextAlign.center style=TextStyle(debugLabel: ((englishLike titleMedium 2021).merge((blackMountainView titleMedium).apply)).copyWith, inherit: false, color: Color(alpha: 1.0000, red: 0.0980, green: 0.1098, blue: 0.1255, colorSpace: ColorSpace.sRGB), family: Roboto, size: 16.0, weight: 500, letterSpacing: 0.1, baseline: alphabetic, height: 1.5x, leadingDistribution: even, decoration: Color(alpha: 1.0000, red: 0.0980, green: 0.1098, blue: 0.1255, colorSpace: ColorSpace.sRGB) TextDecoration.none)]
                SizedBox [w=null h=8.0]
                Text [data=Message align=TextAlign.center style=TextStyle(debugLabel: (englishLike bodyMedium 2021).merge((blackMountainView bodyMedium).apply), inherit: false, color: Color(alpha: 1.0000, red: 0.0980, green: 0.1098, blue: 0.1255, colorSpace: ColorSpace.sRGB), family: Roboto, size: 14.0, weight: 400, letterSpacing: 0.3, baseline: alphabetic, height: 1.4x, leadingDistribution: even, decoration: Color(alpha: 1.0000, red: 0.0980, green: 0.1098, blue: 0.1255, colorSpace: ColorSpace.sRGB) TextDecoration.none)]
          SizedBox [w=null h=16.0]
          TextButton
''';

const String _kDialogSignature = '''
ZConfirmDialog
  AlertDialog [shape=null titleTextStyle=null contentTextStyle=null actionsPadding=null icon=null]
    Dialog
      Semantics [label=null container=false]
        AnimatedPadding
          Padding [pad=EdgeInsets(40.0, 24.0, 40.0, 24.0)]
            MediaQuery
              Align
                ConstrainedBox
                  Material
                    _MaterialInterior
                      PhysicalShape
                        _ShapeBorderPaint
                          CustomPaint
                            NotificationListener<LayoutChangedNotification>
                              _InkFeatures
                                AnimatedDefaultTextStyle
                                  DefaultTextStyle
                                    Semantics [label=Alert container=false]
                                      IntrinsicWidth
                                        Column [main=MainAxisSize.min cross=CrossAxisAlignment.stretch]
                                          Padding [pad=EdgeInsets(24.0, 24.0, 24.0, 0.0)]
                                            DefaultTextStyle
                                              Semantics [label=null container=true]
                                                Text [data=Titre align=null style=null]
                                          Flexible
                                            Padding [pad=EdgeInsets(24.0, 16.0, 24.0, 24.0)]
                                              DefaultTextStyle
                                                Semantics [label=null container=true]
                                                  Text [data=Message align=null style=null]
                                          Padding [pad=EdgeInsets(24.0, 0.0, 24.0, 24.0)]
                                            OverflowBar
                                              TextButton
                                              FilledButton
''';

void main() {
  group('P2-B — inertie absolue (aucun jeton posé)', () {
    testWidgets('ZEmptyState : arbre, rects et couleur d\'icône INCHANGÉS', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(),
          home: Scaffold(
            body: ZEmptyState(
              icon: Icons.inbox_outlined,
              title: 'Titre',
              message: 'Message',
              actionLabel: 'Action',
              onAction: () {},
            ),
          ),
        ),
      );

      expect(
        zTreeSignature(tester, find.byType(ZEmptyState)),
        _kEmptySignature,
      );
      expect(
        tester.getRect(find.byType(Icon)),
        rectMoreOrLessEquals(
          const Rect.fromLTRB(376, 210, 424, 258),
          epsilon: 0.5,
        ),
      );
      expect(
        tester.getRect(find.text('Message')),
        rectMoreOrLessEquals(
          const Rect.fromLTRB(350.1, 306, 449.9, 326),
          epsilon: 0.5,
        ),
      );
      expect(
        tester.getRect(find.byType(TextButton)),
        rectMoreOrLessEquals(
          const Rect.fromLTRB(345.7, 342, 454.3, 390),
          epsilon: 0.5,
        ),
      );
      expect(
        tester.widget<Icon>(find.byType(Icon)).color,
        const Color(0xFF43474E),
      );
    });

    testWidgets('showZConfirmDialog : arbre, rects et teintes INCHANGÉS', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(),
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: TextButton(
                onPressed: () => showZConfirmDialog(
                  context,
                  title: 'Titre',
                  message: 'Message',
                  tone: ZConfirmTone.destructive,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        zTreeSignature(tester, find.byType(ZConfirmDialog)),
        _kDialogSignature,
      );
      expect(
        tester.getRect(find.text('Titre')),
        rectMoreOrLessEquals(
          const Rect.fromLTRB(284.0, 230.0, 516.0, 262.0),
          epsilon: 0.5,
        ),
      );
      expect(
        tester.getRect(find.text('Message')),
        rectMoreOrLessEquals(
          const Rect.fromLTRB(284.0, 278.0, 516.0, 298.0),
          epsilon: 0.5,
        ),
      );
      final FilledButton confirm = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      final ColorScheme scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF3366AA),
      );
      expect(
        confirm.style?.backgroundColor?.resolve(<WidgetState>{}),
        scheme.error,
      );
      expect(
        confirm.style?.foregroundColor?.resolve(<WidgetState>{}),
        scheme.onError,
      );
    });
  });
}
