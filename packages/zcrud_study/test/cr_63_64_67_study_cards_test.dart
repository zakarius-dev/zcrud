import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/src/presentation/z_folder_card.dart';
import 'package:zcrud_study/src/presentation/z_folder_card_chrome.dart';
import 'package:zcrud_study/src/presentation/z_study_document_card.dart';
import 'package:zcrud_study/src/presentation/z_study_note_card.dart';
import 'package:zcrud_study/src/presentation/z_study_tools_item_card.dart';

import 'support/z_sources.dart';

const _topAccentKey = ValueKey<String>('top-accent');
const _footerKey = ValueKey<String>('folder-footer');
const _itemAccentKey = ValueKey<String>('item-accent');
const _metadataKey = ValueKey<String>('metadata');
const _actionsKey = ValueKey<String>('actions');

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('CR-63 — slots de ZFolderCard', () {
    testWidgets('null n’ajoute ni accent ni pied résiduel', (tester) async {
      await tester.pumpWidget(
        _host(const ZFolderCard(title: 'Dossier', colorKey: 'folder')),
      );

      expect(find.byKey(_topAccentKey), findsNothing);
      expect(find.byKey(_footerKey), findsNothing);
    });

    testWidgets('accent pleine largeur, pied et badge archivé coexistent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 240,
            height: 160,
            child: ZFolderCard(
              title: 'Dossier',
              colorKey: 'folder',
              topAccent: SizedBox(key: _topAccentKey, height: 4),
              footer: Text('Créé par Ada', key: _footerKey),
              isArchived: true,
              archivedLabel: 'Archivé',
            ),
          ),
        ),
      );

      expect(find.byKey(_topAccentKey), findsOneWidget);
      expect(find.byKey(_footerKey), findsOneWidget);
      expect(find.text('Archivé'), findsOneWidget);
      final card = tester.getRect(find.byType(Card));
      final accent = tester.getRect(find.byKey(_topAccentKey));
      expect(accent.left, card.left);
      expect(accent.right, card.right);
      expect(accent.top, card.top);
    });

    testWidgets('semanticLabel explicite exclut les nouveaux slots', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZFolderCard(
            title: 'Dossier',
            colorKey: 'folder',
            semanticLabel: 'Dossier complet',
            topAccent: Semantics(label: 'accent du dossier', child: SizedBox()),
            footer: Semantics(label: 'auteur du dossier', child: Text('Ada')),
          ),
        ),
      );

      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Dossier complet'), findsOneWidget);
      expect(find.bySemanticsLabel('accent du dossier'), findsNothing);
      expect(find.bySemanticsLabel('auteur du dossier'), findsNothing);
      handle.dispose();
    });

    testWidgets('accent respecte les deux directions', (tester) async {
      for (final direction in <TextDirection>[
        TextDirection.ltr,
        TextDirection.rtl,
      ]) {
        await tester.pumpWidget(
          _host(
            const SizedBox(
              width: 240,
              height: 160,
              child: ZFolderCard(
                title: 'Dossier',
                colorKey: 'folder',
                topAccent: SizedBox(key: _topAccentKey, height: 4),
              ),
            ),
            direction: direction,
          ),
        );
        final card = tester.getRect(find.byType(Card));
        final accent = tester.getRect(find.byKey(_topAccentKey));
        expect(accent.left, card.left);
        expect(accent.right, card.right);
      }
    });

    testWidgets('ZFolderCardGradientAccent est utilisable comme topAccent', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            theme: const ZcrudTheme(
              accentBarHeight: 4,
              gradientBegin: AlignmentDirectional.centerStart,
              gradientEnd: AlignmentDirectional.centerEnd,
            ),
            gradientResolver: (_, _) => const ZGradientSpec(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF000000), Color(0xFFFFFFFF)],
              ),
              onGradient: Color(0xFFFFFFFF),
            ),
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: Scaffold(
                body: SizedBox(
                  width: 240,
                  height: 160,
                  child: ZFolderCard(
                    title: 'Dossier',
                    colorKey: 'folder',
                    topAccent: ZFolderCardGradientAccent(gradientKey: 'folder'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ZFolderCardGradientAccent), findsOneWidget);
      expect(tester.getSize(find.byType(ZFolderCardGradientAccent)).width, 240);
    });
  });

  group('CR-64 — décor de ZStudyToolsItemCard', () {
    testWidgets('accent null n’ajoute aucun décor résiduel', (tester) async {
      await tester.pumpWidget(_host(const ZStudyToolsItemCard(title: 'Outil')));
      expect(find.byKey(_itemAccentKey), findsNothing);
    });

    testWidgets('accent est décoratif et ne masque pas le tap de la carte', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 240,
            child: ZStudyToolsItemCard(
              title: 'Outil',
              onTap: () => taps++,
              accent: const SizedBox(key: _itemAccentKey, height: 4),
            ),
          ),
        ),
      );
      expect(find.byKey(_itemAccentKey), findsOneWidget);
      await tester.tap(find.byType(ZStudyToolsItemCard));
      expect(taps, 1);
    });
  });

  group('CR-67 — façades document et note', () {
    for (final card in <Widget>[
      const ZStudyDocumentCard(
        title: 'Cours.pdf',
        subtitle: 'Aujourd’hui',
        metadata: SizedBox(key: _metadataKey),
        actions: SizedBox(key: _actionsKey),
      ),
      const ZStudyNoteCard(
        title: 'Révision',
        subtitle: 'À compléter',
        metadata: SizedBox(key: _metadataKey),
        actions: SizedBox(key: _actionsKey),
      ),
    ]) {
      testWidgets('${card.runtimeType} délègue au chrome commun', (
        tester,
      ) async {
        await tester.pumpWidget(_host(card));
        expect(find.byType(ZStudyToolsItemCard), findsOneWidget);
        expect(find.byKey(_metadataKey), findsOneWidget);
        expect(find.byKey(_actionsKey), findsOneWidget);
        expect(
          tester.getSize(find.byType(ZStudyToolsItemCard)).height,
          greaterThanOrEqualTo(48),
        );
      });
    }

    test('les façades ne réimplémentent pas une Card', () {
      for (final path in <String>[
        'lib/src/presentation/z_study_document_card.dart',
        'lib/src/presentation/z_study_note_card.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('ZStudyToolsItemCard('), isTrue);
        final stripped = strippedOf(path);
        expect(RegExp(r'\bCard\s*\(').hasMatch(stripped), isFalse);
      }
    });
  });
}
