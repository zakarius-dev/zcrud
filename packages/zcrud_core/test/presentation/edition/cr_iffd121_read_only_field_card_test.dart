// CR-IFFD-121 ② — un champ déclaré `readOnly` MANIFESTE sa lecture seule.
//
// Constat de l'hôte, mesuré au doigt : un champ `readOnly` isolé au milieu d'un
// formulaire éditable prenait le focus, sa bordure passait au bleu de focus, et
// aucun clavier ne s'ouvrait. La fiche de consultation existait déjà
// (`ZReadOnlyFieldCard`), mais son unique déclencheur était la SURFACE entière
// (`readMode`/`ZReadModeScope`) — jamais le champ lui-même.
//
// Ces gardes mesurent des propriétés OBSERVABLES du rendu (absence de champ de
// saisie, géométrie libellé-au-dessus-de-la-valeur, hauteur minimale de fiche),
// jamais un nom de classe : un rendu qui redeviendrait un `TextField` habillé
// en fiche les ferait rougir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const ZFieldSpec _editable =
    ZFieldSpec(name: 'nom', type: EditionFieldType.text, label: 'Nom');
const ZFieldSpec _locked = ZFieldSpec(
  name: 'ref',
  type: EditionFieldType.text,
  label: 'Référence',
  readOnly: true,
);

ZFormController _ctrl() => ZFormController(
      initialValues: const <String, Object?>{'nom': 'Ada', 'ref': 'REF-42'},
      visibleFields: const <String>['nom', 'ref'],
    );

/// Formulaire ÉDITABLE (`readOnly: false`) portant les deux champs.
Widget _form(
  ZFormController c, {
  List<ZFieldSpec> fields = const <ZFieldSpec>[_editable, _locked],
  bool? readOnlyFieldsAsCards,
}) {
  final Widget form = MaterialApp(
    home: Scaffold(
      body: DynamicEdition(controller: c, fields: fields),
    ),
  );
  return readOnlyFieldsAsCards == null
      ? form
      : ZcrudScope(readOnlyFieldsAsCards: readOnlyFieldsAsCards, child: form);
}

/// Signature GÉOMÉTRIQUE du rendu : chaque texte affiché avec son coin de
/// départ et sa taille, plus le nombre de champs de saisie. Deux rendus qui
/// partagent cette signature sont identiques là où l'œil les compare.
List<String> _signature(WidgetTester t) {
  final List<String> out = <String>[
    'inputs=${t.widgetList<EditableText>(find.byType(EditableText)).length}',
  ];
  for (final Element e in find.byType(Text).evaluate()) {
    final Text w = e.widget as Text;
    final Rect r = t.getRect(find.byWidget(w));
    final String text = w.data ?? w.textSpan?.toPlainText() ?? '';
    out.add('$text@${r.left.toStringAsFixed(1)},'
        '${r.top.toStringAsFixed(1)} ${r.width.toStringAsFixed(1)}x'
        '${r.height.toStringAsFixed(1)}');
  }
  return out;
}

void main() {
  testWidgets(
      '🔴 EFFET : un champ `readOnly` SEUL dans un formulaire éditable est '
      'rendu en fiche — aucun champ de saisie pour lui, libellé au-dessus de '
      'la valeur', (tester) async {
    final c = _ctrl();
    addTearDown(c.dispose);
    await tester.pumpWidget(_form(c));
    await tester.pumpAndSettle();

    // Le formulaire reste ÉDITABLE : le champ voisin garde sa saisie. Sans
    // cette moitié, la garde passerait aussi pour un formulaire entièrement
    // basculé en consultation — le défaut inverse.
    expect(find.byType(EditableText), findsOneWidget,
        reason: 'exactement UN champ de saisie : le champ éditable voisin');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Ada',
      reason: 'le champ de saisie survivant est bien le champ ÉDITABLE',
    );

    // Le champ verrouillé : libellé ET valeur rendus, le libellé AU-DESSUS de
    // la valeur et aligné au même bord — la géométrie d'une fiche, jamais
    // celle d'un `InputDecorator` (libellé flottant DANS la bordure).
    final Offset label = tester.getTopLeft(find.text('Référence'));
    final Offset value = tester.getTopLeft(find.text('REF-42'));
    expect(value.dy, greaterThan(label.dy),
        reason: 'la valeur est SOUS son libellé');
    expect(value.dx, closeTo(label.dx, 0.5),
        reason: 'libellé et valeur partagent le même bord de départ');
  });

  testWidgets(
      '🔴 ÉCHAPPATOIRE : `ZcrudScope.readOnlyFieldsAsCards: false` rétablit '
      'le champ de saisie NU — verrouillé, mais un champ de saisie',
      (tester) async {
    final c = _ctrl();
    addTearDown(c.dispose);
    await tester.pumpWidget(_form(c, readOnlyFieldsAsCards: false));
    await tester.pumpAndSettle();

    final Iterable<EditableText> inputs =
        tester.widgetList<EditableText>(find.byType(EditableText));
    expect(inputs.length, 2,
        reason: 'les DEUX champs sont de nouveau des champs de saisie');
    final EditableText locked =
        inputs.firstWhere((e) => e.controller.text == 'REF-42');
    expect(locked.readOnly, isTrue,
        reason: "l'échappatoire rend la FORME, jamais le droit d'écrire");
  });

  testWidgets(
      "🔴 INERTIE : un formulaire SANS champ `readOnly` rend exactement "
      "comme avant — l'échappatoire ne change rien à sa géométrie",
      (tester) async {
    const List<ZFieldSpec> plain = <ZFieldSpec>[
      _editable,
      ZFieldSpec(name: 'ref', type: EditionFieldType.text, label: 'Référence'),
    ];

    // Rendu de RÉFÉRENCE : l'échappatoire posée reproduit, par construction,
    // le rendu antérieur au déclencheur par champ.
    final c1 = _ctrl();
    addTearDown(c1.dispose);
    await tester.pumpWidget(
      _form(c1, fields: plain, readOnlyFieldsAsCards: false),
    );
    await tester.pumpAndSettle();
    final List<String> before = _signature(tester);
    expect(before.length, greaterThan(2),
        reason: 'anti-vacuité : la signature observe réellement quelque chose');

    // Rendu COURANT, déclencheur actif : aucun champ n'est `readOnly`, rien ne
    // doit bouger — ni un pixel, ni un champ de saisie.
    final c2 = _ctrl();
    addTearDown(c2.dispose);
    await tester.pumpWidget(_form(c2, fields: plain));
    await tester.pumpAndSettle();
    expect(_signature(tester), before);
  });

  testWidgets(
      "🔴 INERTIE : une surface ENTIÈRE en consultation garde ses fiches, "
      "même échappatoire posée — la voie globale est intacte", (tester) async {
    final c = _ctrl();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      ZcrudScope(
        readOnlyFieldsAsCards: false,
        child: MaterialApp(
          home: Scaffold(
            body: DynamicEdition(
              controller: c,
              fields: const <ZFieldSpec>[_editable, _locked],
              readOnly: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsNothing,
        reason: "l'échappatoire ne désarme QUE le déclencheur par champ");
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('REF-42'), findsOneWidget);
  });

  testWidgets(
      "🔴 FAMILLE NON FICHE-ABLE : un champ `readOnly` d'une famille sans "
      "rendu de fiche garde EXACTEMENT son rendu antérieur", (tester) async {
    // `dateRange` n'a pas de rendu de fiche (`zReadModeCardable` → false) : le
    // déclencheur par champ ne doit rien changer pour elle. La preuve est
    // comparative — même signature géométrique avec et sans l'échappatoire,
    // cette dernière reproduisant par construction le rendu antérieur.
    const List<ZFieldSpec> fields = <ZFieldSpec>[
      ZFieldSpec(
        name: 'periode',
        type: EditionFieldType.dateRange,
        label: 'Période',
        readOnly: true,
      ),
    ];

    ZFormController rangeCtrl() => ZFormController(
          initialValues: <String, Object?>{
            'periode': ZDateRange(
              start: DateTime(2026, 1, 10),
              end: DateTime(2026, 1, 12),
            ),
          },
          visibleFields: const <String>['periode'],
        );

    final c1 = rangeCtrl();
    addTearDown(c1.dispose);
    await tester.pumpWidget(
      _form(c1, fields: fields, readOnlyFieldsAsCards: false),
    );
    await tester.pumpAndSettle();
    final List<String> before = _signature(tester);
    expect(before.length, greaterThan(1),
        reason: 'anti-vacuité : la signature observe réellement quelque chose');
    expect(before.any((e) => e.contains('→')), isTrue,
        reason: 'la plage rendue est bien observée par la signature');

    final c2 = rangeCtrl();
    addTearDown(c2.dispose);
    await tester.pumpWidget(_form(c2, fields: fields));
    await tester.pumpAndSettle();
    expect(_signature(tester), before,
        reason: 'aucune famille non fiche-able ne bascule sur ce déclencheur');
  });

  testWidgets(
      "🔴 BASCULE DYNAMIQUE : un champ qui DEVIENT `readOnly` pendant la "
      "saisie garde sa valeur et son focus", (tester) async {
    // La lecture seule dérivée arrive PENDANT la vie du champ. Le mode de
    // présentation, lui, est arrêté au montage : le champ se verrouille sans
    // changer de forme. C'est délibéré — remonter le champ en fiche à cet
    // instant lui ferait perdre contrôleur, valeur en cours et focus
    // (invariant AD-2).
    final ZFormController c = ZFormController();
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: c,
          fields: <ZFieldSpec>[
            const ZFieldSpec(name: 'mode', type: EditionFieldType.text),
            ZFieldSpec(
              name: 'nom',
              type: EditionFieldType.text,
              derivedFrom: ZDerivation(
                sources: const <String>['mode'],
                overwrite: ZDerivationOverwrite.always,
                readOnly: (Map<String, Object?> v) => v['mode'] == 'locked',
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    final Finder nom = find.byType(EditableText).last;
    await tester.tap(nom);
    await tester.pump();
    await tester.enterText(nom, 'Ada');
    await tester.pump();
    expect(tester.widget<EditableText>(nom).focusNode.hasFocus, isTrue);

    c.setValue('mode', 'locked');
    await tester.pump();

    expect(find.byType(EditableText), findsNWidgets(2),
        reason: 'le champ ne bascule PAS en fiche en cours de saisie');
    final EditableText after = tester.widget<EditableText>(
      find.byType(EditableText).last,
    );
    expect(after.controller.text, 'Ada',
        reason: 'la valeur en cours de saisie survit au verrouillage');
    expect(c.valueOf('nom'), 'Ada', reason: 'la tranche aussi');
    expect(after.focusNode.hasFocus, isTrue,
        reason: 'le focus n\'est pas perdu (le champ n\'a pas été remonté)');
    expect(after.readOnly, isTrue,
        reason: 'le verrou, lui, prend effet immédiatement');
  });
}
