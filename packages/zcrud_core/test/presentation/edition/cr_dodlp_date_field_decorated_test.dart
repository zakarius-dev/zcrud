// CR-DODLP-DATE-FIELD (« Détail 2 ») — les familles `date`/`time`/`dateTime` et
// `dateRange` rendaient un `OutlinedButton` « Libellé : valeur » : aspect
// bouton, aucun libellé flottant, aucun astérisque « requis », et surtout HORS
// de la chaîne `zFieldDecoration` — donc insensibles aux jetons
// `fieldFillColor`/`fieldBorderColor`/`fieldFocusedBorderColor` livrés en
// v0.60.0. Elles passent désormais par `InputDecorator` + `zFieldDecoration`,
// exactement comme `text`/`number`/`select`.
//
// Ces gardes sont écrites pour être MORDANTES : chacune distingue l'état que le
// défaut produirait de celui que le correctif produit (astérisque présent VS
// absent, libellé flottant VS au repos, jeton honoré VS ignoré).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZFormController _controller(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(),
    );

Widget _app(
  ZFormController controller,
  List<ZFieldSpec> fields, {
  ZcrudTheme? theme,
  TextDirection dir = TextDirection.ltr,
}) =>
    MaterialApp(
      theme: theme == null
          ? null
          : ThemeData(extensions: <ThemeExtension<dynamic>>[theme]),
      home: Directionality(
        textDirection: dir,
        child: Scaffold(
          body: DynamicEdition(controller: controller, fields: fields),
        ),
      ),
    );

/// Toutes les données sémantiques de l'arbre satisfaisant [match].
List<SemanticsData> _collect(
  WidgetTester tester,
  bool Function(SemanticsData) match,
) {
  final out = <SemanticsData>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (match(data)) out.add(data);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(DynamicEdition)));
  return out;
}

/// `dy` du haut du libellé enrichi du champ (discrimine repos vs flottant).
double _labelTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(ZFieldLabel).first).dy;

const ZFieldSpec _dtRequired = ZFieldSpec(
  name: 'dt',
  type: EditionFieldType.dateTime,
  label: 'Date',
  validators: <ZValidatorSpec>[ZValidatorSpec.required()],
);
const ZFieldSpec _dtOptional = ZFieldSpec(
  name: 'dt',
  type: EditionFieldType.dateTime,
  label: 'Date',
);

void main() {
  // ── G1 : le déclencheur est un CHAMP DÉCORÉ, plus un bouton ───────────────
  group('G1 · le déclencheur passe par la chaîne de décoration', () {
    testWidgets('dateTime : InputDecorator + ZFieldLabel, aucun OutlinedButton',
        (tester) async {
      final c = _controller(<String, Object?>{'dt': null});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[_dtOptional]));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ZDateFieldWidget),
          matching: find.byType(InputDecorator),
        ),
        findsOneWidget,
        reason: 'le champ date doit traverser `InputDecorator`',
      );
      expect(
        find.descendant(
          of: find.byType(ZDateFieldWidget),
          matching: find.byType(ZFieldLabel),
        ),
        findsOneWidget,
        reason: 'le libellé enrichi partagé (astérisque) doit être monté',
      );
      // 🔴 Anti-régression frontale : le retour au rendu bouton doit rougir.
      expect(find.byType(OutlinedButton), findsNothing);
      // 🔴 Et le libellé n'est PLUS concaténé à la valeur (« Date : … »).
      expect(find.textContaining('Date :'), findsNothing);
    });

    testWidgets('dateRange : même traitement que la famille date sœur',
        (tester) async {
      final c = _controller(<String, Object?>{'p': null});
      addTearDown(c.dispose);
      const f = ZFieldSpec(
          name: 'p', type: EditionFieldType.dateRange, label: 'Période');
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[f]));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ZDateRangeFieldWidget),
          matching: find.byType(InputDecorator),
        ),
        findsOneWidget,
      );
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('`time` (mode heure) est décoré AUSSI — pas 1 kind sur 3',
        (tester) async {
      final c = _controller(<String, Object?>{'t': null});
      addTearDown(c.dispose);
      const f =
          ZFieldSpec(name: 't', type: EditionFieldType.time, label: 'Heure');
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[f]));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ZDateFieldWidget),
          matching: find.byType(InputDecorator),
        ),
        findsOneWidget,
      );
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });

  // ── G2 : astérisque « requis » — les DEUX états ───────────────────────────
  group('G2 · astérisque requis (garde non vacante : requis ET non requis)', () {
    testWidgets('requis ⇒ astérisque rendu, à la couleur d\'ERREUR thémée',
        (tester) async {
      final c = _controller(<String, Object?>{'dt': null});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[_dtRequired]));
      await tester.pumpAndSettle();

      final star = find.descendant(
        of: find.byType(ZDateFieldWidget),
        matching: find.text(' *'),
      );
      expect(star, findsOneWidget, reason: 'astérisque requis attendu');
      final ctx = tester.element(find.byType(ZDateFieldWidget));
      final expected = ZcrudTheme.of(ctx).errorColor ??
          Theme.of(ctx).colorScheme.error;
      expect(tester.widget<Text>(star).style?.color, expected,
          reason: 'couleur d\'erreur THÉMÉE, jamais un littéral (FR-26)');
    });

    testWidgets(
        '🔴 NON requis ⇒ AUCUN astérisque (sans quoi la garde ci-dessus '
        'passerait aussi avec isRequired: false)', (tester) async {
      final c = _controller(<String, Object?>{'dt': null});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[_dtOptional]));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ZDateFieldWidget),
          matching: find.text(' *'),
        ),
        findsNothing,
      );
    });

    testWidgets('l\'astérisque reste DÉCORATIF (jamais lu à voix haute)',
        (tester) async {
      final handle = tester.ensureSemantics();
      final c = _controller(<String, Object?>{'dt': null});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[_dtRequired]));
      await tester.pumpAndSettle();

      final withStar =
          _collect(tester, (d) => d.label.contains('*') || d.value.contains('*'));
      expect(withStar, isEmpty,
          reason: 'aucun nœud sémantique ne porte l\'astérisque');
      handle.dispose();
    });
  });

  // ── G3 : libellé FLOTTANT vs AU REPOS — les deux états distingués ─────────
  group('G3 · libellé flottant (garde non vacante : repos ≠ flottant)', () {
    testWidgets('vide ⇒ libellé AU REPOS ; rempli ⇒ libellé FLOTTANT (plus haut)',
        (tester) async {
      final c = _controller(<String, Object?>{'dt': null});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[_dtOptional]));
      await tester.pumpAndSettle();

      final restingTop = _labelTop(tester);
      final decoratorTop = tester.getTopLeft(find.byType(InputDecorator)).dy;

      c.setValue('dt', '2024-01-02T03:04:00.000');
      await tester.pumpAndSettle();
      final floatingTop = _labelTop(tester);

      // 🔴 Cœur de la garde : le libellé MONTE quand la valeur apparaît. Un
      // libellé figé (toujours flottant OU toujours au repos) rend l'égalité
      // vraie et fait ROUGIR ce test.
      expect(floatingTop, lessThan(restingTop),
          reason: 'le libellé doit passer du repos au flottant');
      // Et l'état « au repos » est bien DANS la boîte (pas collé au bord haut).
      expect(restingTop, greaterThan(decoratorTop),
          reason: 'au repos, le libellé est dans le corps du champ');
      // La valeur, elle, est rendue une fois flottant.
      expect(find.textContaining('2024-01-02'), findsOneWidget);
    });
  });

  // ── G4 : les jetons de champ s'appliquent SANS code nouveau ───────────────
  group('G4 · jetons fieldFillColor / fieldBorderColor honorés', () {
    testWidgets('le champ date consomme les jetons v0.60.0 (chaîne partagée)',
        (tester) async {
      const fill = Color(0xFF102030);
      const border = Color(0xFF405060);
      final c = _controller(<String, Object?>{'dt': null});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        c,
        const <ZFieldSpec>[_dtOptional],
        theme: const ZcrudTheme(fieldFillColor: fill, fieldBorderColor: border),
      ));
      await tester.pumpAndSettle();

      final dec = tester
          .widget<InputDecorator>(find.descendant(
            of: find.byType(ZDateFieldWidget),
            matching: find.byType(InputDecorator),
          ))
          .decoration;
      expect(dec.fillColor, fill,
          reason: 'fieldFillColor doit atteindre le champ date');
      expect(
        (dec.enabledBorder! as OutlineInputBorder).borderSide.color,
        border,
        reason: 'fieldBorderColor doit atteindre le champ date',
      );
    });
  });

  // ── G5 : échappatoire (paramètre > jeton > référence) ─────────────────────
  group('G5 · échappatoire vers le rendu historique', () {
    testWidgets('jeton `dateFieldDecorated: false` ⇒ OutlinedButton restitué',
        (tester) async {
      final c = _controller(<String, Object?>{'dt': null});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        c,
        const <ZFieldSpec>[_dtOptional],
        theme: const ZcrudTheme(dateFieldDecorated: false),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(InputDecorator), findsNothing);
      // Rendu historique EXACT (libellé concaténé à la valeur).
      expect(find.textContaining('Date :'), findsOneWidget);
    });

    testWidgets('🔴 le PARAMÈTRE l\'emporte sur le jeton (ordre de la chaîne)',
        (tester) async {
      // Jeton à `false` (legacy) MAIS paramètre à `true` ⇒ décoré.
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: const <ThemeExtension<dynamic>>[
          ZcrudTheme(dateFieldDecorated: false),
        ]),
        home: Scaffold(
          body: ZDateFieldWidget(
            field: _dtOptional,
            value: null,
            decorated: true,
            onChanged: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(InputDecorator), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);

      // Et l'inverse : jeton absent (référence = décoré) + paramètre `false`.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ZDateFieldWidget(
            field: _dtOptional,
            value: null,
            decorated: false,
            onChanged: _swallow,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(InputDecorator), findsNothing);
    });

    testWidgets('défaut du paquet (aucun jeton, aucun paramètre) = DÉCORÉ',
        (tester) async {
      final c = _controller(<String, Object?>{'dt': null});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[_dtOptional]));
      await tester.pumpAndSettle();
      expect(find.byType(InputDecorator), findsOneWidget);
    });
  });

  // ── G6 : a11y — un seul nœud, rien de perdu, `isRequired` sur le canal ────
  group('G6 · arbre sémantique : ni perte ni doublon', () {
    testWidgets('UN seul nœud bouton (libellé + valeur), + canal isRequired',
        (tester) async {
      final handle = tester.ensureSemantics();
      final c = _controller(<String, Object?>{'dt': null});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[_dtRequired]));
      await tester.pumpAndSettle();

      final nodes = _collect(tester, (d) => d.label.contains('Date'));
      expect(nodes.length, 1,
          reason: '🔴 aucun DOUBLON : le libellé de l\'InputDecorator ne doit '
              'pas produire un second nœud à côté du wrapper');
      expect(nodes.single.flagsCollection.isButton, isTrue);
      expect(nodes.single.label, 'Date');
      // 🔴 Aucune PERTE : la valeur (placeholder l10n) reste annoncée alors
      // qu'elle n'est plus peinte (le libellé au repos la remplace à l'écran).
      expect(nodes.single.value, isNotEmpty);
      // Canal sémantique « requis » (et non l'astérisque).
      expect(nodes.single.flagsCollection.isRequired, ui.Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('🔴 non requis ⇒ isRequired NON positionné (garde non vacante)',
        (tester) async {
      final handle = tester.ensureSemantics();
      final c = _controller(<String, Object?>{'dt': null});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[_dtOptional]));
      await tester.pumpAndSettle();
      final nodes = _collect(tester, (d) => d.label.contains('Date'));
      expect(nodes.single.flagsCollection.isRequired, isNot(ui.Tristate.isTrue));
      handle.dispose();
    });
  });

  // ── G7 : comportement conservé (tap, effacement, repli AD-10) ─────────────
  group('G7 · comportement inchangé (tap, effacement, replis AD-10)', () {
    testWidgets('le tap OUVRE le sélecteur (comme avant)', (tester) async {
      final c = _controller(<String, Object?>{'dt': null});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[_dtOptional]));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ZDateFieldWidget));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('la croix d\'effacement survit au changement de rendu',
        (tester) async {
      final c =
          _controller(<String, Object?>{'dt': '2024-01-02T00:00:00.000'});
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[_dtOptional]));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.clear), findsOneWidget);
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(c.valueOf('dt'), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AD-10 : valeur nulle / date invalide / bornes incohérentes '
        '⇒ aucun throw', (tester) async {
      // (a) valeur nulle
      final a = _controller(<String, Object?>{'dt': null});
      addTearDown(a.dispose);
      await tester.pumpWidget(_app(a, const <ZFieldSpec>[_dtOptional]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // (b) chaîne non parsable : rendue telle quelle, aucun throw
      final b = _controller(<String, Object?>{'dt': 'pas-une-date'});
      addTearDown(b.dispose);
      await tester.pumpWidget(_app(b, const <ZFieldSpec>[_dtOptional]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('pas-une-date'), findsOneWidget);

      // (c) bornes incohérentes (min > max) : le picker s'ouvre quand même
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZDateFieldWidget(
            field: _dtOptional,
            value: null,
            firstDate: () => DateTime(2030),
            lastDate: () => DateTime(2000),
            onChanged: _swallow,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ZDateFieldWidget));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  // ── G8 : SM-1 — le changement de rendu n'élargit pas la frontière ─────────
  group('G8 · SM-1 : seule la tranche du champ se reconstruit', () {
    testWidgets('choisir/effacer une date ne reconstruit PAS le champ voisin',
        (tester) async {
      final builds = <String, int>{};
      final c = _controller(
        <String, Object?>{'dt': '2024-01-02T00:00:00.000', 'txt': ''},
      );
      addTearDown(c.dispose);
      const fields = <ZFieldSpec>[
        _dtOptional,
        ZFieldSpec(name: 'txt', type: EditionFieldType.text, label: 'T'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: c,
            fields: fields,
            fieldBuilder: (context, ctrl, field) => ZFieldWidget(
              controller: ctrl,
              field: field,
              onBuild: () =>
                  builds[field.name] = (builds[field.name] ?? 0) + 1,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final dtBefore = builds['dt']!;
      final txtBefore = builds['txt']!;

      // Effacement (voie `onCleared` → setValue) puis écriture d'une valeur.
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      c.setValue('dt', '2025-06-07T08:09:00.000');
      await tester.pumpAndSettle();

      // 🔴 Clause PORTEUSE en premier : élargir la frontière de rebuild doit
      // rougir ICI (et pas sur une clause annexe).
      expect(builds['txt'], txtBefore,
          reason: '🔴 le champ voisin ne DOIT PAS se reconstruire (AD-2/SM-1)');
      expect(builds['dt']!, greaterThan(dtBefore),
          reason: 'la tranche du champ date se reconstruit bien');
    });
  });

  _g9();
}

void _swallow(String _) {}

// ── G9 : mode `large` (Card) — le libellé ne doit pas être DOUBLÉ ──────────
void _g9() {
  group('G9 · fieldSize.large : décor porté par la Card (mode bare)', () {
    testWidgets('un SEUL libellé (celui de la Card), aucun libellé de champ',
        (tester) async {
      final c = _controller(<String, Object?>{'dt': null});
      addTearDown(c.dispose);
      const f = ZFieldSpec(
        name: 'dt',
        type: EditionFieldType.dateTime,
        label: 'Date',
        fieldSize: ZFieldSize.large,
      );
      await tester.pumpWidget(_app(c, const <ZFieldSpec>[f]));
      await tester.pumpAndSettle();
      // 🔴 Le décor en `bare` ne pose AUCUN label : sans quoi la Card et le
      // champ afficheraient tous deux « Date ».
      expect(find.byType(ZFieldLabel), findsOneWidget,
          reason: 'un seul libellé enrichi (celui de la Card)');
      // Le texte de substitution reste VISIBLE en `bare` (le libellé au repos
      // ne peut plus tenir ce rôle).
      expect(find.textContaining('Select'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
