// CR-IFFD-97 — lecteur riche : ① copie multi-format DÉCLARÉE PAR L'HÔTE ;
// ② relais de l'état vide (placeholder/emptyIcon/emptySubtitle/emptyBuilder)
// jusqu'au lecteur via le champ ET le registre.
//
// Étalon (NON-NÉGOCIABLE) : sans déclaration, comportement STRICTEMENT
// inchangé — copie directe au long-press (aucun menu), état vide historique
// (placeholder seul).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

/// Capture les appels `Clipboard.setData` (canal platform mocké).
List<String> _mockClipboard(WidgetTester tester) {
  final captured = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        captured.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  return captured;
}

/// Nettoyage : démonte l'arbre (annule le Timer de clignotement du curseur).
Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

const List<Map<String, dynamic>> _delta = <Map<String, dynamic>>[
  <String, dynamic>{'insert': 'Bonjour\n'},
];

final Finder _gesture =
    find.byKey(const Key('z-markdown-reader-copy-gesture'));

ZFormController _controller(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(),
    );

Widget _registryApp(ZFormController controller, List<ZFieldSpec> fields,
        ZWidgetRegistry registry) =>
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudScope(
          widgetRegistry: registry,
          child: Scaffold(
            body: DynamicEdition(controller: controller, fields: fields),
          ),
        ),
      ),
    );

void main() {
  group('① copie multi-format (lecteur)', () {
    testWidgets(
        'ÉTALON : sans format déclaré, le long-press copie DIRECTEMENT '
        '(aucun menu)', (t) async {
      final captured = _mockClipboard(t);
      await t.pumpWidget(_host(const ZMarkdownReader(
        value: _delta,
        copyOnLongPress: true,
      )));
      await t.pump(const Duration(milliseconds: 50));
      await t.longPress(_gesture);
      await t.pumpAndSettle();
      expect(find.byType(PopupMenuItem<ZMarkdownCopyFormat>), findsNothing,
          reason: '🔴 sans copyFormats, AUCUN menu — copie directe (étalon)');
      expect(captured, hasLength(1));
      expect(jsonDecode(captured.single), _delta,
          reason: 'payload = valeur encodée par le codec, inchangé');
      await _settle(t);
    });

    testWidgets(
        'formats déclarés : le menu liste EXACTEMENT les formats de '
        "l'hôte (libellé l10n par clé, repli = clé), rien n'est copié "
        "à l'ouverture", (t) async {
      final captured = _mockClipboard(t);
      final formats = <ZMarkdownCopyFormat>[
        ZMarkdownCopyFormat(key: 'copy.markdown', transform: (_) => 'md'),
        ZMarkdownCopyFormat(key: 'copy.whatsapp', transform: (_) => 'wa'),
        ZMarkdownCopyFormat(key: 'copy.html', transform: (_) => 'html'),
      ];
      await t.pumpWidget(_host(ZMarkdownReader(
        value: _delta,
        copyOnLongPress: true,
        copyFormats: formats,
      )));
      await t.pump(const Duration(milliseconds: 50));
      await t.longPress(_gesture);
      await t.pumpAndSettle();
      expect(find.byType(PopupMenuItem<ZMarkdownCopyFormat>), findsNWidgets(3),
          reason: '🔴 le menu porte EXACTEMENT les formats déclarés — '
              'ni plus (le socle n\'invente pas de format) ni moins');
      for (final f in formats) {
        expect(find.text(f.key), findsOneWidget,
            reason: 'libellé résolu l10n par clé, repli = la clé (FR-26 : '
                'aucun libellé du paquet)');
      }
      expect(captured, isEmpty,
          reason: "l'ouverture du menu ne copie rien — seul un CHOIX copie");
      // cible tactile : hauteur d'item ≥ 48 dp (AD-13).
      final Size item = t.getSize(
          find.byKey(const Key('z-markdown-copy-format-copy.markdown')));
      expect(item.height, greaterThanOrEqualTo(48),
          reason: '🔴 AD-13 : cible ≥ 48 dp');
      // fermer sans choisir : rien copié.
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();
      expect(captured, isEmpty);
      await _settle(t);
    });

    testWidgets(
        'choisir un format : sa transformation reçoit le Delta NEUTRE du '
        'document et sa chaîne est copiée (+ SnackBar au libellé injecté)',
        (t) async {
      final captured = _mockClipboard(t);
      List<Map<String, dynamic>>? received;
      await t.pumpWidget(_host(ZMarkdownReader(
        value: _delta,
        copyOnLongPress: true,
        copiedFeedbackText: 'Copié',
        copyFormats: <ZMarkdownCopyFormat>[
          ZMarkdownCopyFormat(
            key: 'copy.whatsapp',
            transform: (delta) {
              received = delta;
              return '*Bonjour*';
            },
          ),
        ],
      )));
      await t.pump(const Duration(milliseconds: 50));
      await t.longPress(_gesture);
      await t.pumpAndSettle();
      await t.tap(find.text('copy.whatsapp'));
      await t.pumpAndSettle();
      expect(received, _delta,
          reason: '🔴 la transformation reçoit le Delta neutre du document');
      expect(captured, hasLength(1));
      expect(captured.single, '*Bonjour*',
          reason: '🔴 la charge copiée est la chaîne produite par le format '
              'CHOISI — pas la valeur encodée par défaut');
      expect(find.text('Copié'), findsOneWidget,
          reason: 'même canal de retour que la copie directe');
      await _settle(t);
    });

    testWidgets(
        'transformation qui lève : rien n\'est copié, aucun crash (défensif)',
        (t) async {
      final captured = _mockClipboard(t);
      await t.pumpWidget(_host(ZMarkdownReader(
        value: _delta,
        copyOnLongPress: true,
        copyFormats: <ZMarkdownCopyFormat>[
          ZMarkdownCopyFormat(
            key: 'copy.broken',
            transform: (_) => throw StateError('hôte défaillant'),
          ),
        ],
      )));
      await t.pump(const Duration(milliseconds: 50));
      await t.longPress(_gesture);
      await t.pumpAndSettle();
      await t.tap(find.text('copy.broken'));
      await t.pumpAndSettle();
      expect(captured, isEmpty);
      expect(t.takeException(), isNull);
      await _settle(t);
    });
  });

  group('② relais de l\'état vide jusqu\'au lecteur', () {
    ZFieldSpec readOnlyField(String name) => ZFieldSpec(
          name: name,
          type: EditionFieldType.markdown,
          label: 'Note',
          readOnly: true,
        );

    testWidgets(
        'ZMarkdownField (voie controller, readOnly) relaie '
        'placeholder/emptyIcon/emptySubtitle au lecteur', (t) async {
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('note'),
        controller: c,
        field: readOnlyField('note'),
        placeholder: 'Rien à lire',
        emptyIcon: Icons.notes_rounded,
        emptySubtitle: 'Ajoutez une note',
      )));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget,
          reason: '🔴 emptyIcon déclaré DOIT atteindre le lecteur');
      expect(find.text('Rien à lire'), findsOneWidget,
          reason: '🔴 placeholder explicite relayé au lecteur');
      expect(find.text('Ajoutez une note'), findsOneWidget,
          reason: '🔴 emptySubtitle relayé au lecteur');
      await _settle(t);
    });

    testWidgets(
        'ÉTALON : sans déclaration, zone identique (placeholder par défaut '
        'seul, aucune icône)', (t) async {
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('note'),
        controller: c,
        field: readOnlyField('note'),
      )));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text(ZMarkdownReader.defaultPlaceholder), findsOneWidget,
          reason: 'état vide historique STRICTEMENT inchangé');
      expect(find.byType(Icon), findsNothing,
          reason: 'aucune icône sans déclaration');
      await _settle(t);
    });

    testWidgets('emptyBuilder (prioritaire) relayé au lecteur', (t) async {
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('note'),
        controller: c,
        field: readOnlyField('note'),
        emptyIcon: Icons.notes_rounded,
        emptyBuilder: (_) => const Text('custom vide'),
      )));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('custom vide'), findsOneWidget);
      expect(find.byIcon(Icons.notes_rounded), findsNothing,
          reason: 'le builder custom est PRIORITAIRE (contrat lecteur)');
      await _settle(t);
    });

    testWidgets(
        'registerZMarkdownFields relaie l\'état vide ET le geste de copie '
        'multi-format au champ construit par le REGISTRE', (t) async {
      final captured = _mockClipboard(t);
      final r = ZWidgetRegistry();
      registerZMarkdownFields(
        r,
        emptyIcon: Icons.article_outlined,
        emptySubtitle: 'Vide pour l\'instant',
        copyOnLongPress: true,
        copyFormats: <ZMarkdownCopyFormat>[
          ZMarkdownCopyFormat(key: 'copy.plain', transform: (_) => 'plat'),
        ],
      );
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(
          _registryApp(c, <ZFieldSpec>[readOnlyField('note')], r));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.article_outlined), findsOneWidget,
          reason: '🔴 emptyIcon posé au registre atteint le lecteur — '
              'le registre est la SEULE voie de construction d\'un hôte');
      expect(find.text('Vide pour l\'instant'), findsOneWidget);
      // le geste de copie relayé : sur un contenu non vide.
      c.setValue('note', _delta);
      await t.pump(const Duration(milliseconds: 50));
      await t.longPress(_gesture);
      await t.pumpAndSettle();
      expect(find.text('copy.plain'), findsOneWidget,
          reason: '🔴 copyFormats posés au registre alimentent le menu');
      await t.tap(find.text('copy.plain'));
      await t.pumpAndSettle();
      expect(captured, <String>['plat']);
      await _settle(t);
    });
  });
}
