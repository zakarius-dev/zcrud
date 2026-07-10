import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_example/app.dart';
import 'package:zcrud_example/demos/export_demo_screen.dart';
import 'package:zcrud_example/demos/geo_demo_screen.dart';
import 'package:zcrud_example/demos/intl_demo_screen.dart';
import 'package:zcrud_example/demos/markdown_demo_screen.dart';
import 'package:zcrud_example/demos/offline_demo_screen.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    // L'entrée Offline ouvre un HiveZLocalStore réel → Hive init hermétique.
    tempDir = Directory.systemTemp.createTempSync('zcrud_home_nav');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(HiveZLocalStore.boxNameFor('demoRecord'));
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // AC9 — chaque entrée MVP activée navigue vers son écran dédié, sans exception.
  testWidgets('AC9 — accueil : navigation vers les 5 nouvelles démos',
      (tester) async {
    tester.view.physicalSize =
        Size(1200 * tester.view.devicePixelRatio, 2400 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    Future<void> openAndBack(String entry, Type screen,
        {bool settle = true}) async {
      await tester.tap(find.text(entry));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        // Écrans à carte (FlutterMap) : les tuiles réseau ne se résolvent jamais
        // en test → pas de `settle`.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(screen), findsOneWidget);
      // Retour à l'accueil (BackButton Material, indépendant de la locale).
      await tester.tap(find.byType(BackButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    await openAndBack('Markdown', MarkdownDemoScreen);
    await openAndBack('Geo', GeoDemoScreen, settle: false);
    await openAndBack('Intl', IntlDemoScreen);
    await openAndBack('Export', ExportDemoScreen);
    // Offline ouvre un HiveZLocalStore réel : sous FakeAsync l'IO fichier ne se
    // résout pas (l'écran affiche brièvement un indicateur) → pas de `settle`.
    await openAndBack('Offline / Firestore', OfflineDemoScreen, settle: false);
  });
}
