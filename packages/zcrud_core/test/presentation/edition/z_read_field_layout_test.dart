// Les CINQ formes de consultation (`ZReadFieldLayout`).
//
// Une forme se prouve par une MESURE, jamais par son nom : chaque garde de ce
// fichier affirme une hauteur, un rectangle, une taille de police ou la
// présence/absence d'un widget structurant. Les cinq hauteurs mesurées ici
// (72 / 72 / 54 / 36 / 28) sont celles annoncées par la documentation des
// valeurs de l'énumération : si l'une bouge, la documentation ment.
//
// 🔴 Garde centrale : la forme PAR DÉFAUT reproduit le rendu du moteur legacy
// DODLP (`ListTile(title: label, subtitle: valeur)`) — ni fond, ni filet, même
// hauteur, même typographie. Elle est mesurée CÔTE À CÔTE avec un vrai
// `ListTile`, dans le même test, pour qu'aucune des deux mesures ne puisse
// dériver seule.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _texte = ZFieldSpec(
  name: 'nom',
  type: EditionFieldType.text,
  label: 'Nom',
);

const _second = ZFieldSpec(
  name: 'ville',
  type: EditionFieldType.text,
  label: 'Ville',
);

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
  ZFieldSpec(name: 'f2', type: EditionFieldType.number, label: 'F2'),
];

const _itemValues = <String, dynamic>{'f1': 'Alpha', 'f2': 42};

/// Hauteur attendue de chaque forme, pour un couple libellé/valeur d'une ligne
/// sur une surface de 800 (thème Material 3 par défaut, LTR).
const _hauteurs = <ZReadFieldLayout, double>{
  ZReadFieldLayout.card: 72,
  ZReadFieldLayout.listTile: 72,
  ZReadFieldLayout.definition: 54,
  ZReadFieldLayout.inlineRow: 36,
  ZReadFieldLayout.compact: 28,
};

class _Host extends StatefulWidget {
  const _Host({required this.controller, required this.builder});

  final ZFormController controller;
  final Widget Function(ZFormController controller) builder;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(widget.controller);
}

Widget _hosted(
  Map<String, Object?> values,
  Widget Function(ZFormController controller) builder,
) =>
    _Host(
      controller: ZFormController(
        initialValues: values,
        visibleFields: values.keys.toList(),
      ),
      builder: builder,
    );

/// Enveloppe d'hôte. La [cle] distingue deux montages successifs dans un même
/// test : le mode d'un champ est arrêté à son MONTAGE.
Widget _app(Widget child, {String cle = 'unique', ZcrudTheme? theme}) =>
    MaterialApp(
      home: ZcrudScope(
        key: ValueKey<String>(cle),
        acl: const ZAllowAllAcl(),
        theme: theme,
        child: Scaffold(body: child),
      ),
    );

/// Formulaire d'un champ `text` en consultation, dans la forme demandée.
Widget _fiche(
  ZReadFieldLayout? forme, {
  String cle = 'unique',
  ZcrudTheme? theme,
  bool readOnly = true,
  List<ZFieldSpec> champs = const <ZFieldSpec>[_texte],
  Map<String, Object?> valeurs = const <String, Object?>{'nom': 'Ada'},
}) =>
    _app(
      _hosted(
        valeurs,
        (c) => DynamicEdition(
          controller: c,
          fields: champs,
          shrinkWrap: true,
          readOnly: readOnly,
          readLayout: forme,
        ),
      ),
      cle: cle,
      theme: theme,
    );

double _hauteurDe(WidgetTester tester) =>
    tester.getRect(find.byType(ZReadOnlyFieldCard)).height;

TextStyle? _styleLibelle(WidgetTester tester) =>
    tester.widget<Text>(find.text('Nom')).style;

TextStyle _styleValeur(WidgetTester tester) =>
    DefaultTextStyle.of(tester.element(find.text('Ada'))).style;

Card _carte(WidgetTester tester) => tester.widget<Card>(
      find.descendant(
        of: find.byType(ZReadOnlyFieldCard),
        matching: find.byType(Card),
      ),
    );

void main() {
  group('(a) Chaque forme rend le libellé ET la valeur, et se distingue par '
      'une mesure', () {
    for (final forme in ZReadFieldLayout.values) {
      testWidgets('${forme.name} — libellé, valeur, hauteur ${_hauteurs[forme]}',
          (tester) async {
        await tester.pumpWidget(_fiche(forme, cle: forme.name));
        await tester.pumpAndSettle();

        // Une fiche vide n'est pas une fiche : les deux sont rendus.
        expect(find.text('Nom'), findsOneWidget);
        expect(find.text('Ada'), findsOneWidget);
        expect(find.byType(InputDecorator), findsNothing);
        expect(_hauteurDe(tester), _hauteurs[forme]);
      });
    }

    testWidgets('les cinq hauteurs sont bien DISTINCTES là où elles doivent '
        "l'être", (tester) async {
      final mesurees = <ZReadFieldLayout, double>{};
      for (final forme in ZReadFieldLayout.values) {
        await tester.pumpWidget(_fiche(forme, cle: 'h-${forme.name}'));
        await tester.pumpAndSettle();
        mesurees[forme] = _hauteurDe(tester);
      }
      // La fiche et la ligne Material partagent le rang de 72 (c'est le but) ;
      // les trois formes denses descendent STRICTEMENT à chaque cran.
      expect(mesurees[ZReadFieldLayout.card],
          mesurees[ZReadFieldLayout.listTile]);
      expect(mesurees[ZReadFieldLayout.definition]!,
          lessThan(mesurees[ZReadFieldLayout.card]!));
      expect(mesurees[ZReadFieldLayout.inlineRow]!,
          lessThan(mesurees[ZReadFieldLayout.definition]!));
      expect(mesurees[ZReadFieldLayout.compact]!,
          lessThan(mesurees[ZReadFieldLayout.inlineRow]!));
    });

    testWidgets('definition — la valeur DOMINE le libellé (hiérarchie '
        'inversée), sans aucun chrome', (tester) async {
      await tester.pumpWidget(_fiche(ZReadFieldLayout.definition));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      final libelle = _styleLibelle(tester)!.fontSize!;
      final valeur = _styleValeur(tester).fontSize!;
      expect(libelle, 12);
      expect(valeur, 16);
      expect(valeur, greaterThan(libelle));
      // Empilée : la valeur commence SOUS le libellé.
      expect(tester.getRect(find.text('Ada')).top,
          greaterThanOrEqualTo(tester.getRect(find.text('Nom')).bottom));
    });

    testWidgets('inlineRow — deux colonnes : libellé de largeur FIXE au début, '
        'valeur alignée à la fin, sur la MÊME ligne', (tester) async {
      await tester.pumpWidget(_fiche(ZReadFieldLayout.inlineRow));
      await tester.pumpAndSettle();

      final libelle = tester.getRect(find.text('Nom'));
      final valeur = tester.getRect(find.text('Ada'));
      expect(libelle.top, valeur.top);
      // Colonne de libellé : la largeur du jeton (160), pas celle du texte.
      expect(libelle.width, 160);
      // Valeur alignée à la FIN : elle finit au bord interne du padding
      // (788 − 16), et non au début comme dans les formes empilées.
      expect(valeur.right, closeTo(772, 0.5));
      expect(valeur.left, greaterThan(400));
    });

    testWidgets('compact — une ligne, colonne de libellé INTRINSÈQUE, aucun '
        'bouton', (tester) async {
      await tester.pumpWidget(_fiche(ZReadFieldLayout.compact));
      await tester.pumpAndSettle();

      final libelle = tester.getRect(find.text('Nom'));
      final valeur = tester.getRect(find.text('Ada'));
      expect(libelle.top, valeur.top);
      // Rien n'est aligné d'un champ à l'autre : le libellé prend SA largeur.
      expect(libelle.width, lessThan(160));
      // La densité tient parce qu'aucune cible de 48 n'est montée.
      expect(find.byIcon(Icons.copy_outlined), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('inlineRow se REPLIE en empilé sous la largeur minimale',
        (tester) async {
      Widget etroit(double largeur, String cle) => _app(
            Center(
              child: SizedBox(
                width: largeur,
                child: _hosted(
                  const <String, Object?>{'nom': 'Ada'},
                  (c) => DynamicEdition(
                    controller: c,
                    fields: const <ZFieldSpec>[_texte],
                    shrinkWrap: true,
                    readOnly: true,
                    readLayout: ZReadFieldLayout.inlineRow,
                  ),
                ),
              ),
            ),
            cle: cle,
          );

      // Au-dessus du seuil (360) : deux colonnes, même ligne.
      await tester.pumpWidget(etroit(500, 'large'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Nom')).top,
          tester.getRect(find.text('Ada')).top);

      // En dessous : la valeur passe SOUS le libellé.
      await tester.pumpWidget(etroit(300, 'etroit'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Ada')).top,
          greaterThan(tester.getRect(find.text('Nom')).top));
    });
  });

  group('(b) 🔴 La forme par DÉFAUT reproduit le legacy DODLP', () {
    testWidgets('aucun filet, aucun fond', (tester) async {
      await tester.pumpWidget(_fiche(null));
      await tester.pumpAndSettle();

      final carte = _carte(tester);
      // Fond : dérivé du ColorScheme mais totalement translucide.
      expect(carte.color!.a, 0);
      // Filet : ABSENT (et non un trait de largeur nulle, qui se verrait
      // encore à l'écran).
      final side = (carte.shape! as RoundedRectangleBorder).side;
      expect(side.style, BorderStyle.none);
    });

    testWidgets('même hauteur et même typographie qu\'un ListTile legacy, '
        'mesurées CÔTE À CÔTE', (tester) async {
      // 1. La forme par défaut.
      await tester.pumpWidget(_fiche(null, cle: 'socle'));
      await tester.pumpAndSettle();
      final hauteurSocle = _hauteurDe(tester);
      final libelleSocle = _styleLibelle(tester)!;
      final valeurSocle = _styleValeur(tester);

      // 2. Le moteur legacy, à l'identique :
      //    `ListTile(title: Text(label), subtitle: Text(valeur))`.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ListTile(title: Text('Nom'), subtitle: Text('Ada')),
        ),
      ));
      await tester.pumpAndSettle();
      final hauteurLegacy = tester.getRect(find.byType(ListTile)).height;
      final libelleLegacy =
          DefaultTextStyle.of(tester.element(find.text('Nom'))).style;
      final valeurLegacy =
          DefaultTextStyle.of(tester.element(find.text('Ada'))).style;

      expect(hauteurSocle, hauteurLegacy);
      expect(hauteurSocle, 72);
      expect(libelleSocle.fontSize, libelleLegacy.fontSize);
      expect(libelleSocle.fontWeight, libelleLegacy.fontWeight);
      expect(libelleSocle.color, libelleLegacy.color);
      expect(valeurSocle.fontSize, valeurLegacy.fontSize);
      expect(valeurSocle.fontWeight, valeurLegacy.fontWeight);
      expect(valeurSocle.color, valeurLegacy.color);
      // Et, en clair : 16/w400 pour le libellé, 14/w400 grisé pour la valeur.
      expect(libelleSocle.fontSize, 16);
      expect(libelleSocle.fontWeight, FontWeight.w400);
      expect(valeurSocle.fontSize, 14);
      expect(valeurSocle.fontWeight, FontWeight.w400);
    });
  });

  group('(c) La forme listTile rend un vrai ListTile', () {
    testWidgets('libellé en title, valeur en subtitle', (tester) async {
      await tester.pumpWidget(_fiche(ZReadFieldLayout.listTile));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsOneWidget);
      final tuile = tester.widget<ListTile>(find.byType(ListTile));
      expect(
        find.descendant(
          of: find.byWidget(tuile.title!),
          matching: find.text('Nom'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byWidget(tuile.subtitle!),
          matching: find.text('Ada'),
        ),
        findsOneWidget,
      );
      // Aucune autre forme n'en rend : la sonde est spécifique.
      await tester.pumpWidget(_fiche(ZReadFieldLayout.card, cle: 'carte'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('(d) La forme descend par le canal EXISTANT et atteint les champs '
      'profonds', () {
    testWidgets("fenêtre à étapes — la forme traverse le fieldBuilder de l'étape",
        (tester) async {
      await tester.pumpWidget(_app(
        _hosted(
          const <String, Object?>{'nom': 'Ada'},
          (c) => ZStepperEdition(
            controller: c,
            fields: const <ZFieldSpec>[_texte],
            steps: <ZEditionStep>[
              ZEditionStep(title: 'Étape', fields: const <String>['nom']),
            ],
            readOnly: true,
            readLayout: ZReadFieldLayout.listTile,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byType(InputDecorator), findsNothing);
    });

    testWidgets('sous-liste inline — les champs internes prennent la forme',
        (tester) async {
      await tester.pumpWidget(_app(_hosted(
        <String, Object?>{
          'items': const <Map<String, dynamic>>[_itemValues],
        },
        (c) => DynamicEdition(
          controller: c,
          fields: const <ZFieldSpec>[
            ZFieldSpec(
              name: 'items',
              type: EditionFieldType.subItems,
              label: 'Items',
              config: ZSubListConfig(
                itemFields: _itemFields,
                displayMode: ZSubListDisplayMode.inline,
                summaryFields: <String>['f1'],
              ),
            ),
          ],
          shrinkWrap: true,
          readOnly: true,
          readLayout: ZReadFieldLayout.compact,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(ZReadOnlyFieldCard), findsNWidgets(2));
      // Forme compacte au fond de la sous-liste : le libellé et la valeur du
      // premier champ interne sont sur la MÊME ligne.
      expect(tester.getRect(find.text('F1')).top,
          tester.getRect(find.text('Alpha')).top);
      for (final carte in find.byType(ZReadOnlyFieldCard).evaluate()) {
        expect(tester.getRect(find.byElementPredicate((e) => e == carte)).height,
            28);
      }
    });

    testWidgets("dialogue d'item — la forme traverse la ROUTE", (tester) async {
      await tester.pumpWidget(_app(_hosted(
        <String, Object?>{
          'items': const <Map<String, dynamic>>[_itemValues],
        },
        (c) => DynamicEdition(
          controller: c,
          fields: const <ZFieldSpec>[
            ZFieldSpec(
              name: 'items',
              type: EditionFieldType.subItems,
              label: 'Items',
              config: ZSubListConfig(
                itemFields: _itemFields,
                displayMode: ZSubListDisplayMode.compact,
                summaryFields: <String>['f1'],
              ),
            ),
          ],
          shrinkWrap: true,
          readOnly: true,
          readLayout: ZReadFieldLayout.listTile,
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(find.byType(ZReadOnlyFieldCard), findsNWidgets(2));
      // Le dialogue naît hors de l'arbre de la surface : sans le relais de la
      // forme, ces deux fiches retomberaient sur la forme par défaut.
      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('un fieldBuilder FOURNI ne perd pas la forme', (tester) async {
      await tester.pumpWidget(_app(_hosted(
        const <String, Object?>{'nom': 'Ada'},
        (c) => DynamicEdition(
          controller: c,
          fields: const <ZFieldSpec>[_texte],
          shrinkWrap: true,
          readOnly: true,
          readLayout: ZReadFieldLayout.listTile,
          fieldBuilder: (context, controller, field) =>
              ZFieldWidget(controller: controller, field: field),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('priorité : surface > jeton de thème', (tester) async {
      // Jeton seul : c'est lui qui décide.
      await tester.pumpWidget(_fiche(
        null,
        cle: 'jeton',
        theme: const ZcrudTheme(readLayout: ZReadFieldLayout.listTile),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);

      // Surface déclarée : elle prime sur le jeton.
      await tester.pumpWidget(_fiche(
        ZReadFieldLayout.compact,
        cle: 'surface',
        theme: const ZcrudTheme(readLayout: ZReadFieldLayout.listTile),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(_hauteurDe(tester), 28);
    });
  });

  group('(e) La surcharge par CHAMP prime sur la surface', () {
    testWidgets('un seul champ change de forme, les autres non', (tester) async {
      await tester.pumpWidget(_fiche(
        ZReadFieldLayout.compact,
        champs: const <ZFieldSpec>[
          ZFieldSpec(
            name: 'nom',
            type: EditionFieldType.text,
            label: 'Nom',
            readLayout: ZReadFieldLayout.listTile,
          ),
          _second,
        ],
        valeurs: const <String, Object?>{'nom': 'Ada', 'ville': 'Lomé'},
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ZReadOnlyFieldCard), findsNWidgets(2));
      // Le champ surchargé : une ligne Material.
      expect(find.byType(ListTile), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Nom'),
        ),
        findsOneWidget,
      );
      // L'autre : la forme de la surface, à 28.
      expect(tester.getRect(find.text('Ville')).top,
          tester.getRect(find.text('Lomé')).top);
    });
  });

  group('(f) Semantics — le libellé et la valeur forment une PAIRE dans '
      'chaque forme', () {
    for (final forme in ZReadFieldLayout.values) {
      testWidgets('${forme.name} — « Nom » : « Ada » annoncés ensemble',
          (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_fiche(forme, cle: 's-${forme.name}'));
        await tester.pumpAndSettle();

        final noeud = tester.getSemantics(find.byType(ZReadOnlyFieldCard));
        expect(noeud.label, 'Nom');
        expect(noeud.value, 'Ada');
        handle.dispose();
      });
    }

    testWidgets('les formes DENSES publient la copie en action annoncée, '
        'faute de bouton', (tester) async {
      // Référence : le libellé EXACT que porte le bouton de copie de la fiche,
      // résolu par la même l10n. La garde compare donc deux affordances du même
      // socle, jamais une chaîne écrite en dur.
      await tester.pumpWidget(_fiche(ZReadFieldLayout.card, cle: 'ca-ref'));
      await tester.pumpAndSettle();
      final attendu = tester.widget<IconButton>(find.byType(IconButton)).tooltip;
      expect(attendu, isNotNull);

      for (final forme in <ZReadFieldLayout>[
        ZReadFieldLayout.definition,
        ZReadFieldLayout.inlineRow,
        ZReadFieldLayout.compact,
      ]) {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_fiche(forme, cle: 'ca-${forme.name}'));
        await tester.pumpAndSettle();

        expect(find.byType(IconButton), findsNothing,
            reason: '$forme ne doit monter aucune cible tactile');
        final data = tester
            .getSemantics(find.byType(ZReadOnlyFieldCard))
            .getSemanticsData();
        final libelles = data.customSemanticsActionIds!
            .map((id) => CustomSemanticsAction.getAction(id)?.label)
            .toList();
        expect(libelles, contains(attendu), reason: '$forme');
        handle.dispose();
      }
    });

    testWidgets('une valeur NON copiable est annoncée quand même', (tester) async {
      // Un champ vide déclaré visible en consultation rend un placeholder :
      // affiché, mais **non copiable**. Sans annonce dédiée, un lecteur
      // d'écran entendrait « Nom » et rien d'autre — impossible de distinguer
      // un champ vide d'un champ non lu.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_fiche(
        null,
        cle: 'vide',
        champs: const <ZFieldSpec>[
          ZFieldSpec(
            name: 'nom',
            type: EditionFieldType.text,
            label: 'Nom',
            showIfNull: true,
          ),
        ],
        valeurs: const <String, Object?>{'nom': ''},
      ));
      await tester.pumpAndSettle();

      // Aucune affordance de copie : la valeur n'est pas copiable.
      expect(find.byType(IconButton), findsNothing);
      final noeud = tester.getSemantics(find.byType(ZReadOnlyFieldCard));
      expect(noeud.label, 'Nom');
      // Le placeholder EFFECTIVEMENT affiché est celui qui est annoncé — la
      // garde ne réécrit pas le libellé du vide, elle le relit.
      final affiche = tester.widget<Text>(
        find.descendant(
          of: find.byType(ZReadOnlyFieldCard),
          matching: find.byType(Text),
        ).last,
      );
      expect(noeud.value, affiche.data);
      expect(noeud.value, isNotNull);
      expect(noeud.value, isNotEmpty);
      handle.dispose();
    });

    testWidgets('les formes à bouton gardent une cible ≥ 48', (tester) async {
      for (final forme in <ZReadFieldLayout>[
        ZReadFieldLayout.card,
        ZReadFieldLayout.listTile,
      ]) {
        await tester.pumpWidget(_fiche(forme, cle: 'b-${forme.name}'));
        await tester.pumpAndSettle();
        final taille = tester.getSize(find.byType(IconButton));
        expect(taille.width, greaterThanOrEqualTo(48), reason: '$forme');
        expect(taille.height, greaterThanOrEqualTo(48), reason: '$forme');
      }
    });
  });

  group('(i) 🔴 COHÉRENCE INTER-FAMILLES — deux champs voisins de familles '
      'différentes sont habillés PAREIL, dans chaque forme', () {
    // Le défaut relevé sur appareil : sur une même fiche en consultation, un
    // champ `text` rendait une carte bordée à libellé flottant et un champ
    // `select` un bloc plein à libellé interne. Deux voisins, deux habillages,
    // aucun réglage d'hôte n'ayant prise dessus. Une forme n'en est une que si
    // elle vaut pour TOUTES les familles fiche-ables.
    const champs = <ZFieldSpec>[
      ZFieldSpec(name: 'nom', type: EditionFieldType.text, label: 'Nom'),
      ZFieldSpec(
        name: 'poste',
        type: EditionFieldType.select,
        label: 'Poste',
        choices: <ZFieldChoice>[ZFieldChoice(value: 'chef', label: 'Chef')],
      ),
      ZFieldSpec(name: 'jour', type: EditionFieldType.dateTime, label: 'Jour'),
      ZFieldSpec(name: 'actif', type: EditionFieldType.boolean, label: 'Actif'),
    ];
    const valeurs = <String, Object?>{
      'nom': 'Ada',
      'poste': 'chef',
      'jour': '2026-08-16',
      'actif': true,
    };

    for (final forme in ZReadFieldLayout.values) {
      testWidgets('${forme.name} — quatre familles, un seul habillage',
          (tester) async {
        await tester.pumpWidget(_fiche(
          forme,
          cle: 'coh-${forme.name}',
          champs: champs,
          valeurs: valeurs,
        ));
        await tester.pumpAndSettle();

        // Aucune surface de saisie ne subsiste, quelle que soit la famille.
        expect(find.byType(InputDecorator), findsNothing);
        expect(find.byType(EditableText), findsNothing);
        expect(find.byType(ZReadOnlyFieldCard), findsNWidgets(champs.length));

        // Même structure : la forme monte le même nombre de cartes (4 en
        // fiche, 0 ailleurs) et de lignes Material — jamais un mélange.
        final cartes = find.byType(Card).evaluate().length;
        final tuiles = find.byType(ListTile).evaluate().length;
        expect(cartes, forme == ZReadFieldLayout.card ? champs.length : 0,
            reason: '$forme : chrome de carte inégal entre familles');
        expect(tuiles, forme == ZReadFieldLayout.listTile ? champs.length : 0,
            reason: '$forme : chrome de ligne inégal entre familles');

        // Même filet : toutes les cartes de la forme fiche partagent le même
        // style de bordure (c'est le point exact du constat d'appareil).
        if (forme == ZReadFieldLayout.card) {
          final styles = find
              .byType(Card)
              .evaluate()
              .map((e) => ((e.widget as Card).shape! as RoundedRectangleBorder)
                  .side
                  .style)
              .toSet();
          expect(styles.length, 1, reason: '$forme : filets inégaux');
          expect(styles.single, BorderStyle.none);
        }

        // Même rythme vertical : les quatre rangs ont la même hauteur.
        final hauteurs = find
            .byType(ZReadOnlyFieldCard)
            .evaluate()
            .map((e) => tester.getRect(find.byElementPredicate((x) => x == e))
                .height)
            .toSet();
        expect(hauteurs.length, 1,
            reason: '$forme : hauteurs inégales entre familles → $hauteurs');
        expect(hauteurs.single, _hauteurs[forme]);

        // Même typographie de libellé pour les quatre.
        final stylesLibelle = <String>['Nom', 'Poste', 'Jour', 'Actif']
            .map((l) => tester.widget<Text>(find.text(l)).style)
            .toSet();
        expect(stylesLibelle.length, 1,
            reason: '$forme : libellés stylés différemment selon la famille');
      });
    }
  });

  group('(g) Contre-témoin — un formulaire en ÉDITION ne change dans AUCUNE '
      'forme', () {
    testWidgets('même rectangle de champ de saisie, forme déclarée ou non',
        (tester) async {
      await tester.pumpWidget(_fiche(null, cle: 'ed-nul', readOnly: false));
      await tester.pumpAndSettle();
      final reference = tester.getRect(find.byType(InputDecorator));
      expect(find.byType(EditableText), findsOneWidget);

      for (final forme in ZReadFieldLayout.values) {
        await tester.pumpWidget(
          _fiche(forme, cle: 'ed-${forme.name}', readOnly: false),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ZReadOnlyFieldCard), findsNothing, reason: '$forme');
        expect(find.byType(InputDecorator), findsOneWidget, reason: '$forme');
        expect(find.byType(EditableText), findsOneWidget, reason: '$forme');
        expect(tester.getRect(find.byType(InputDecorator)), reference,
            reason: '$forme');
      }
    });
  });

  group("(h) Réversibilité — l'encadré revient par DÉCLARATION", () {
    testWidgets('deux jetons suffisent à retrouver la fiche cernée',
        (tester) async {
      // Départ : à plat (c'est la rupture assumée du socle).
      await tester.pumpWidget(_fiche(null, cle: 'plat'));
      await tester.pumpAndSettle();
      expect(_carte(tester).color!.a, 0);
      expect(
        (_carte(tester).shape! as RoundedRectangleBorder).side.style,
        BorderStyle.none,
      );

      // Le geste de retour, tel qu'il est documenté au consommateur.
      final scheme = ThemeData().colorScheme;
      await tester.pumpWidget(_fiche(
        null,
        cle: 'encadre',
        theme: ZcrudTheme(
          readFillColor: scheme.surfaceContainerLow,
          readBorderWidth: 1,
        ),
      ));
      await tester.pumpAndSettle();

      expect(_carte(tester).color, scheme.surfaceContainerLow);
      final side = (_carte(tester).shape! as RoundedRectangleBorder).side;
      expect(side.style, BorderStyle.solid);
      expect(side.width, 1);
      expect(side.color, scheme.outline);
    });

    testWidgets('les jetons de mesure gouvernent TOUTES les formes',
        (tester) async {
      // Un padding déclaré s'applique à la forme dense comme à la fiche.
      await tester.pumpWidget(_fiche(
        ZReadFieldLayout.compact,
        cle: 'pad',
        theme: const ZcrudTheme(
          readPadding: EdgeInsetsDirectional.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // 20 + 20 + la ligne de 20 : la forme dense n'ignore pas le jeton.
      expect(_hauteurDe(tester), 60);
    });
  });
}
