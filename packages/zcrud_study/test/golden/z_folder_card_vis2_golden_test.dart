import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/src/presentation/z_folder_card.dart';
import 'package:zcrud_study/src/presentation/z_folder_card_chrome.dart';

const _start = Color(0xFF3366AA);
const _end = Color(0xFFAA6633);

ZGradientSpec? _goldenGradient(ColorScheme _, String key) =>
    key == 'folder-reference'
    ? const ZGradientSpec(
        gradient: LinearGradient(colors: <Color>[_start, _end]),
        onGradient: Color(0xFFFFFFFF),
      )
    : null;

void main() {
  testWidgets('VIS-2 G2 — golden du preset d’accent complet', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(240, 180);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.light(
            primary: _start,
            secondaryContainer: Color(0xFFD0E0F0),
            onSecondaryContainer: Color(0xFF10233A),
          ),
        ),
        home: ZcrudScope(
          theme: const ZcrudTheme(
            accentBarHeight: 4,
            gradientBegin: AlignmentDirectional.centerStart,
            gradientEnd: AlignmentDirectional.centerEnd,
          ),
          gradientResolver: _goldenGradient,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 220,
                  height: 160,
                  child: ZFolderCard(
                    title: 'Dossier de reference',
                    colorKey: 'secondary',
                    headerDecoration: ZFolderCardGradientAccent(
                      gradientKey: 'folder-reference',
                    ),
                    counts: Text('12 cartes'),
                    menu: Icon(Icons.more_vert),
                    isArchived: true,
                    archivedLabel: 'Archive',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ZFolderCard),
      matchesGoldenFile('goldens/z_folder_card_vis2_preset.png'),
    );
  });
}
