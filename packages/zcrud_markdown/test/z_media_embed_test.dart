// DP-22 (M20) — Embeds **image / vidéo** neutres de `zcrud_markdown` :
//   - rendu via le SEAM `ZMediaResolver`/`ZMediaEmbedScope` (l'hôte fournit le
//     rendu réel) ;
//   - rendu DÉFENSIF (AD-10) : source absente/non-String/vide → placeholder ;
//     resolver ABSENT → placeholder thémé ; resolver qui THROW → placeholder,
//     JAMAIS de throw ;
//   - insertion/édition via la toolbar (boutons image/vidéo) → op Delta
//     `{insert:{image|video:<source>}}`, tranche NEUTRE + JSON-safe (AD-7) ;
//   - a11y / thème (AD-13/FR-26) : label a11y, cibles ≥ 48 dp, couleur du thème.
//
// SEAM NEUTRE (AD-1) : le package ne câble AUCUN accès réseau. Le resolver est
// fourni par l'HÔTE. On le simule ici par un widget keyé — jamais un
// `Image.network`.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
// Import CIBLÉ de l'impl (même package) : le barrel n'exporte pas les embeds
// Quill-étendus (`ZMediaEmbedBuilder`/`ZImageEmbed`) — isolation AD-1. Un test
// INTERNE au package câble l'`EmbedBuilder` réel pour prouver le rendu readOnly.
import 'package:zcrud_markdown/src/presentation/z_media_embed.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(
  Widget child, {
  TextDirection dir = TextDirection.ltr,
  ThemeData? theme,
}) =>
    MaterialApp(
      theme: theme,
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: child),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

QuillController _quillOf(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;

Iterable<EmbedBuilder>? _embedBuildersOf(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).config.embedBuilders;

void _pressMediaButton(WidgetTester tester, String tooltip) {
  final btn = tester
      .widgetList<QuillToolbarCustomButton>(
          find.byType(QuillToolbarCustomButton))
      .firstWhere((b) => b.options.tooltip == tooltip);
  btn.options.onPressed!.call();
}

const _field = ZFieldSpec(name: 'notes', type: EditionFieldType.text);

List<Map<String, dynamic>> _mediaSeed(String type, Object? source) =>
    <Map<String, dynamic>>[
      <String, dynamic>{
        'insert': <String, dynamic>{type: source},
      },
      <String, dynamic>{'insert': '\n'},
    ];

void main() {
  group('embedBuilders image/vidéo câblés (édition ET lecture)', () {
    testWidgets('les EmbedBuilders latex+table+image+video sont présents',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final keys = _embedBuildersOf(tester)!.map((b) => b.key).toSet();
      expect(keys.containsAll(<String>{'latex', 'table', 'image', 'video'}),
          isTrue,
          reason: 'image/video doivent s\'ajouter SANS retirer latex/table');
      await _settle(tester);
    });
  });

  group('SEAM ZMediaResolver / ZMediaEmbedScope', () {
    testWidgets('resolver fourni → son widget est rendu (image)',
        (tester) async {
      ZMediaRef? seen;
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'notes': _mediaSeed('image', 'https://host/x.png'),
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMediaEmbedScope(
        resolver: (context, ref) {
          seen = ref;
          return Container(key: const Key('resolved-image'));
        },
        child: ZMarkdownField(
          key: const ValueKey('notes'),
          controller: controller,
          field: _field,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('resolved-image')), findsOneWidget,
          reason: 'le widget du resolver hôte doit être rendu');
      expect(seen, isNotNull);
      expect(seen!.kind, ZMediaKind.image);
      expect(seen!.source, 'https://host/x.png',
          reason: 'la source OPAQUE est passée telle quelle (aucune interprétation)');
      await _settle(tester);
    });

    testWidgets('resolver fourni → son widget est rendu (vidéo)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'notes': _mediaSeed('video', 'https://host/clip.mp4'),
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMediaEmbedScope(
        resolver: (context, ref) => ref.kind == ZMediaKind.video
            ? Container(key: const Key('resolved-video'))
            : null,
        child: ZMarkdownField(
          key: const ValueKey('notes'),
          controller: controller,
          field: _field,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('resolved-video')), findsOneWidget);
      await _settle(tester);
    });

    testWidgets('resolver ABSENT → placeholder thémé (image), aucun réseau',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'notes': _mediaSeed('image', 'https://host/x.png'),
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.image_outlined), findsWidgets,
          reason: 'placeholder image attendu en l\'absence de resolver');
      await _settle(tester);
    });

    testWidgets('resolver qui retourne null → placeholder (défaut sûr)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'notes': _mediaSeed('video', 'rtsp://host/live'),
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMediaEmbedScope(
        resolver: (context, ref) => null,
        child: ZMarkdownField(
          key: const ValueKey('notes'),
          controller: controller,
          field: _field,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.videocam_outlined), findsWidgets);
      await _settle(tester);
    });

    testWidgets('resolver qui THROW → placeholder, JAMAIS de throw (AD-10)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'notes': _mediaSeed('image', 'https://host/x.png'),
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMediaEmbedScope(
        resolver: (context, ref) => throw StateError('boom hôte'),
        child: ZMarkdownField(
          key: const ValueKey('notes'),
          controller: controller,
          field: _field,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull,
          reason: 'un resolver hôte qui throw ne casse JAMAIS l\'éditeur');
      expect(find.byIcon(Icons.image_outlined), findsWidgets);
      await _settle(tester);
    });
  });

  group('rendu DÉFENSIF (AD-10) : source invalide → placeholder, aucun throw', () {
    final seeds = <String, Object?>{
      'image source null': _mediaSeed('image', null),
      'image source non-String (nombre)': _mediaSeed('image', 42),
      'image source vide': _mediaSeed('image', '   '),
      'video source null': _mediaSeed('video', null),
      'video source vide': _mediaSeed('video', ''),
    };
    seeds.forEach((label, seed) {
      testWidgets('$label → placeholder, aucun throw', (tester) async {
        final controller = ZFormController(
          initialValues: <String, Object?>{'notes': seed},
        );
        addTearDown(controller.dispose);
        // Même avec un resolver présent, une source invalide ne l'atteint PAS.
        await tester.pumpWidget(_host(ZMediaEmbedScope(
          resolver: (context, ref) => const Text('SHOULD-NOT-RESOLVE'),
          child: ZMarkdownField(
            key: const ValueKey('notes'),
            controller: controller,
            field: _field,
          ),
        )));
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull);
        expect(find.text('SHOULD-NOT-RESOLVE'), findsNothing,
            reason: 'source invalide ne doit JAMAIS être résolue');
        expect(find.byType(ZMarkdownField), findsOneWidget);
        await _settle(tester);
      });
    });
  });

  group('rendu réel en LECTURE (readOnly) via l\'EmbedBuilder image', () {
    testWidgets('placeholder image rendu en lecture seule', (tester) async {
      final quill = QuillController(
        document: Document.fromJson(_mediaSeed('image', 'assets/pic.png')),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      addTearDown(quill.dispose);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          FlutterQuillLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: QuillEditor(
              controller: quill,
              focusNode: focus,
              scrollController: scroll,
              config: const QuillEditorConfig(
                scrollable: false,
                embedBuilders: <EmbedBuilder>[ZMediaEmbedBuilder(ZMediaKind.image)],
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(quill.readOnly, isTrue);
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      await _settle(tester);
    });
  });

  group('insertion / édition via toolbar (boutons image & vidéo)', () {
    testWidgets('bouton image → dialogue → op {insert:{image:...}} + neutre',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.image_outlined), findsWidgets);
      _pressMediaButton(tester, 'Insérer une image');
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'https://host/pic.png');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final value = controller.valueOf('notes')! as List<Map<String, dynamic>>;
      final op = value.firstWhere(
        (op) => op['insert'] is Map && (op['insert'] as Map)['image'] is String,
        orElse: () => <String, dynamic>{},
      );
      expect(op.isNotEmpty, isTrue, reason: 'op {insert:{image:...}} absente');
      expect((op['insert'] as Map)['image'], 'https://host/pic.png');
      // AC7 : tranche NEUTRE + JSON-safe après insertion d'un embed.
      expect(value, isA<List<Map<String, dynamic>>>());
      expect(jsonDecode(jsonEncode(value)), equals(value));
      await _settle(tester);
    });

    testWidgets('bouton vidéo → dialogue → op {insert:{video:...}}',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      _pressMediaButton(tester, 'Insérer une vidéo');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'https://host/clip.mp4');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final value = controller.valueOf('notes')! as List<Map<String, dynamic>>;
      final op = value.firstWhere(
        (op) => op['insert'] is Map && (op['insert'] as Map)['video'] is String,
        orElse: () => <String, dynamic>{},
      );
      expect(op.isNotEmpty, isTrue);
      expect((op['insert'] as Map)['video'], 'https://host/clip.mp4');
      await _settle(tester);
    });

    testWidgets('source VIDE au dialogue → AUCUNE op insérée (traitée comme annuler)',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      final before = controller.valueOf('notes');

      _pressMediaButton(tester, 'Insérer une image');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(controller.valueOf('notes'), before,
          reason: 'une source blanche ne doit PAS insérer d\'embed');
      await _settle(tester);
    });
  });

  group('a11y / thème (AD-13 / FR-26)', () {
    testWidgets('placeholder : label a11y (image) + couleur du thème injecté',
        (tester) async {
      const border = Color(0xFF00A0B0);
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'notes': _mediaSeed('image', 'https://host/x.png'),
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZcrudScope(
        theme: const ZcrudTheme(fieldBorderColor: border),
        child: ZMarkdownField(
          key: const ValueKey('notes'),
          controller: controller,
          field: _field,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final labelled = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => (s.properties.label ?? '').contains(kImagePlaceholderLabel));
      expect(labelled, isNotEmpty,
          reason: 'placeholder sans label a11y image');
      // Bordure du placeholder = couleur du thème (aucune couleur en dur).
      final decorated = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border is Border && (d.border! as Border).top.color == border);
      expect(decorated, isNotEmpty,
          reason: 'la bordure du placeholder doit provenir de ZcrudTheme (FR-26)');
      await _settle(tester);
    });

    testWidgets('dialogue source média : boutons OK/Annuler ≥ 48 dp',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      _pressMediaButton(tester, 'Insérer une image');
      await tester.pumpAndSettle();
      for (final label in <String>['OK', 'Cancel']) {
        final box = tester.getSize(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(box.height, greaterThanOrEqualTo(48));
        expect(box.width, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await _settle(tester);
    });

    testWidgets('placeholder rendu sous RTL + thème sombre sans exception',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'notes': _mediaSeed('video', 'https://host/clip.mp4'),
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: const ValueKey('notes'),
          controller: controller,
          field: _field,
        ),
        dir: TextDirection.rtl,
        theme: ThemeData.dark(),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.videocam_outlined), findsWidgets);
      await _settle(tester);
    });
  });

  group('SM-1 / AD-2 : embedBuilders STABLES (image/video ajoutés)', () {
    testWidgets('taper 60 caractères ne réalloue PAS la liste embedBuilders',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final quill = _quillOf(tester);
      final before = _embedBuildersOf(tester);
      quill.replaceText(0, 0, 'x', const TextSelection.collapsed(offset: 1));
      await tester.pump();
      for (var i = 0; i < 60; i++) {
        final at = quill.selection.baseOffset;
        quill.replaceText(at, 0, 'y', TextSelection.collapsed(offset: at + 1));
        await tester.pump();
      }
      final after = _embedBuildersOf(tester);
      expect(identical(after, before), isTrue,
          reason: 'embedBuilders const canonicalisés → aucune réallocation');
      await _settle(tester);
    });
  });
}
