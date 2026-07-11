// DP-13 (M4/M3) : fiche de lecture `ZReadOnlyFieldCard` (label/valeur + copie
// presse-papier), dispatch `readMode`, formatage défensif, tokens de thème, flip
// `showIfNull`. SM-1 : aucun `EditableText`/controller en fiche.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget _host(Widget child, {ZcrudTheme? theme}) => MaterialApp(
      home: Scaffold(
        body: theme == null ? child : ZcrudScope(theme: theme, child: child),
      ),
    );

Widget _fieldInReadMode(ZFieldSpec field, Object? value) {
  final controller = ZFormController(
    initialValues: <String, Object?>{field.name: value},
    visibleFields: <String>[field.name],
  );
  return _CtrlHost(controller: controller, field: field, readMode: true);
}

/// Petit hôte qui possède/dispose le controller (évite les fuites en test).
class _CtrlHost extends StatefulWidget {
  const _CtrlHost({
    required this.controller,
    required this.field,
    required this.readMode,
  });
  final ZFormController controller;
  final ZFieldSpec field;
  final bool readMode;
  @override
  State<_CtrlHost> createState() => _CtrlHostState();
}

class _CtrlHostState extends State<_CtrlHost> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ZFieldWidget(
        controller: widget.controller,
        field: widget.field,
        readMode: widget.readMode,
      );
}

void main() {
  group('Dispatch readMode (AC3/AC6)', () {
    testWidgets('famille fiche-able + readMode → ZReadOnlyFieldCard, 0 EditableText',
        (tester) async {
      await tester.pumpWidget(_host(_fieldInReadMode(
        const ZFieldSpec(name: 'x', type: EditionFieldType.text, label: 'Nom'),
        'Ada',
      )));
      await tester.pumpAndSettle();
      expect(find.byType(ZReadOnlyFieldCard), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);
      expect(find.text('Nom'), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
    });

    testWidgets('readMode:false → champ éditable (rendu inchangé)',
        (tester) async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{'x': 'Ada'},
        visibleFields: const <String>['x'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZFieldWidget(
        controller: controller,
        field: const ZFieldSpec(name: 'x', type: EditionFieldType.text),
      )));
      await tester.pumpAndSettle();
      expect(find.byType(ZReadOnlyFieldCard), findsNothing);
      expect(find.byType(EditableText), findsOneWidget);
    });

    testWidgets('famille NON fiche-able (signature) + readMode → PAS de fiche',
        (tester) async {
      await tester.pumpWidget(_host(_fieldInReadMode(
        const ZFieldSpec(name: 's', type: EditionFieldType.signature),
        null,
      )));
      await tester.pumpAndSettle();
      expect(find.byType(ZReadOnlyFieldCard), findsNothing);
      expect(find.byType(ZSignatureFieldWidget), findsOneWidget);
    });
  });

  group('Copie presse-papier (AC2)', () {
    List<String> mockClipboard(WidgetTester tester) {
      final captured = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            captured.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      return captured;
    }

    testWidgets('IconButton copie écrit la valeur textuelle (≥48dp)',
        (tester) async {
      final captured = mockClipboard(tester);
      await tester.pumpWidget(_host(_fieldInReadMode(
        const ZFieldSpec(name: 'x', type: EditionFieldType.text, label: 'Nom'),
        'Ada',
      )));
      await tester.pumpAndSettle();
      final copyBtn = find.byType(IconButton);
      expect(copyBtn, findsOneWidget);
      final size = tester.getSize(copyBtn);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(copyBtn);
      await tester.pumpAndSettle();
      expect(captured, <String>['Ada']);
    });

    testWidgets('appui long copie la valeur (parité DODLP)', (tester) async {
      final captured = mockClipboard(tester);
      await tester.pumpWidget(_host(_fieldInReadMode(
        const ZFieldSpec(name: 'x', type: EditionFieldType.text, label: 'Nom'),
        'Ada',
      )));
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(ZReadOnlyFieldCard));
      await tester.pumpAndSettle();
      expect(captured, contains('Ada'));
    });

    testWidgets('valeur VIDE → placeholder « — » NON copiable (pas de bouton)',
        (tester) async {
      await tester.pumpWidget(_host(_fieldInReadMode(
        // showIfNull:true pour AFFICHER le champ vide (sinon masqué en amont).
        const ZFieldSpec(
          name: 'x',
          type: EditionFieldType.text,
          label: 'Nom',
          showIfNull: true,
        ),
        '',
      )));
      await tester.pumpAndSettle();
      expect(find.text('—'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });
  });

  group('Formatage défensif de valeur (AC5, AD-10)', () {
    Future<void> pump(WidgetTester tester, ZFieldSpec f, Object? v) =>
        tester.pumpWidget(_host(_fieldInReadMode(f, v)))
            .then((_) => tester.pumpAndSettle());

    testWidgets('boolean → Oui/Non localisé', (tester) async {
      await pump(
        tester,
        const ZFieldSpec(name: 'b', type: EditionFieldType.boolean, label: 'B'),
        true,
      );
      expect(find.text('Yes'), findsOneWidget); // repli en (pas de delegate)
    });

    testWidgets('select → libellé du choix (pas la valeur brute)',
        (tester) async {
      await pump(
        tester,
        const ZFieldSpec(
          name: 's',
          type: EditionFieldType.select,
          label: 'S',
          choices: <ZFieldChoice>[
            ZFieldChoice(value: 'a', label: 'Alpha'),
            ZFieldChoice(value: 'b', label: 'Beta'),
          ],
        ),
        'b',
      );
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('password → jamais en clair (masqué), non copiable',
        (tester) async {
      await pump(
        tester,
        const ZFieldSpec(
          name: 'p',
          type: EditionFieldType.password,
          label: 'P',
        ),
        'secret',
      );
      expect(find.text('secret'), findsNothing);
      expect(find.text('••••'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('Map/objet complexe → texte sûr, aucun throw', (tester) async {
      await pump(
        tester,
        const ZFieldSpec(
          name: 'm',
          type: EditionFieldType.text,
          label: 'M',
          showIfNull: true,
        ),
        const <String, Object?>{'k': 'v', 'n': 2},
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ZReadOnlyFieldCard), findsOneWidget);
    });
  });

  group('showIfNull flip (M3, AC8/AC10)', () {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'plein', type: EditionFieldType.text, label: 'Plein'),
      // défaut showIfNull:false → masqué si vide en lecture.
      ZFieldSpec(name: 'vide', type: EditionFieldType.text, label: 'Vide'),
      // opt-in : affiché même vide.
      ZFieldSpec(
        name: 'gardevide',
        type: EditionFieldType.text,
        label: 'GardeVide',
        showIfNull: true,
      ),
    ];

    Widget app(ZFormController c, {required bool readOnly}) => MaterialApp(
          home: Scaffold(
            body: DynamicEdition(controller: c, fields: fields, readOnly: readOnly),
          ),
        );

    testWidgets('lecture : champ vide (défaut) masqué ; opt-in affiché',
        (tester) async {
      final c = ZFormController(
        initialValues: const <String, Object?>{
          'plein': 'x',
          'vide': '',
          'gardevide': '',
        },
        visibleFields: const <String>['plein', 'vide', 'gardevide'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c, readOnly: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('plein')), findsOneWidget);
      // Défaut false + vide → masqué.
      expect(find.byKey(const ValueKey<String>('vide')), findsNothing);
      // Opt-in showIfNull:true → affiché (fiche « — »).
      expect(find.byKey(const ValueKey<String>('gardevide')), findsOneWidget);
    });

    testWidgets('hors lecture : showIfNull SANS effet (tout affiché)',
        (tester) async {
      final c = ZFormController(
        initialValues: const <String, Object?>{
          'plein': 'x',
          'vide': '',
          'gardevide': '',
        },
        visibleFields: const <String>['plein', 'vide', 'gardevide'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(app(c, readOnly: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('vide')), findsOneWidget);
    });
  });

  group('Thème & a11y (AC12/AC14/AC15)', () {
    testWidgets('override readPadding effectivement reflété', (tester) async {
      const custom = EdgeInsetsDirectional.all(40);
      await tester.pumpWidget(_host(
        _fieldInReadMode(
          const ZFieldSpec(name: 'x', type: EditionFieldType.text, label: 'Nom'),
          'Ada',
        ),
        theme: const ZcrudTheme(readPadding: custom),
      ));
      await tester.pumpAndSettle();
      final found = find.byWidgetPredicate(
        (w) => w is Padding && w.padding == custom,
      );
      expect(found, findsOneWidget);
    });

    testWidgets('Semantics conteneur porte label + valeur', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(_fieldInReadMode(
        const ZFieldSpec(name: 'x', type: EditionFieldType.text, label: 'Nom'),
        'Ada',
      )));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Nom'), findsOneWidget);
      handle.dispose();
    });
  });
}
