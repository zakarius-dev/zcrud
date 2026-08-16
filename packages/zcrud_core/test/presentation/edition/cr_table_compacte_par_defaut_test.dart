/// Gardes — **le mode compact devient le défaut, et il rend une VRAIE table**.
///
/// Demande du owner : « rend le mode compact par défaut, avec de vrais tables
/// pour l'affichage par défaut ».
///
/// Pourquoi `compact` et pas `inline` : le moteur legacy dont ces sous-listes
/// sont l'extraction rendait chaque item par `itemBuilder?.call(item) ??
/// Container()` — **sans builder, un item legacy s'affiche vide** — et éditait
/// par une **fenêtre**. Le mode legacy est donc `compact` (résumé + fenêtre) ;
/// `inline` est un mode **natif zcrud**, sans contrepartie legacy.
///
/// Ce que ces gardes établissent :
/// * **(A)** le **défaut** est `compact` — sur une config qui ne déclare que son
///   sous-schéma, et jusque sur un champ **sans config du tout** (le cas du
///   générateur) ;
/// * **(B)** `displayMode: inline` rend **exactement** ce que rendait l'ancien
///   défaut — c'est la voie de retour arrière, et elle tient en une ligne ;
/// * **(C)** le rendu est **tabulaire** : largeurs suivant le contenu, en-têtes
///   solidaires de leurs cellules, valeurs **numériques cadrées en fin** ;
/// * **(D)** le **seuil de performance** bascule des deux côtés ;
/// * **(E)** une colonne **non éditable** s'affiche dans la table **et** ne
///   devient pas saisissable — les deux propriétés ;
/// * **(F)** a11y : en-têtes annoncés comme tels, cellules annoncées
///   « libellé : valeur », cibles ≥ 48 dp ;
/// * **(G)** contre-témoins : `showSummaryHeaders: false` conserve le résumé
///   défilant historique, et le repli étroit ne construit **aucune** table.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ── Lignes d'un document (le cas qui motive la table) ────────────────────────

const String kLibelleDesignation = 'Désignation';
const String kLibelleQuantite = 'Quantité';
const String kLibelleMontant = 'Montant HT';

const List<ZFieldSpec> _sousChamps = <ZFieldSpec>[
  ZFieldSpec(
    name: 'designation',
    type: EditionFieldType.text,
    label: kLibelleDesignation,
  ),
  ZFieldSpec(
    name: 'quantite',
    type: EditionFieldType.integer,
    label: kLibelleQuantite,
  ),
];

/// Colonnes déclarées : deux champs saisissables + **un montant calculé**, qui
/// n'appartient pas au sous-schéma (il est déposé dans l'item par le crochet
/// CRUD chez un hôte réel).
const List<ZSubListSummaryColumn> _colonnes = <ZSubListSummaryColumn>[
  ZSubListSummaryColumn(name: 'designation'),
  ZSubListSummaryColumn(name: 'quantite'),
  ZSubListSummaryColumn(
    name: 'montant',
    labelKey: 'montantHT',
    labelFallback: kLibelleMontant,
    decimals: 2,
  ),
];

const List<Map<String, dynamic>> _lignes = <Map<String, dynamic>>[
  <String, dynamic>{
    'designation': 'Ciment CPJ 35 — sacs de 50 kg',
    'quantite': 5,
    'montant': 1500,
  },
  <String, dynamic>{
    'designation': 'Fer',
    'quantite': 40,
    'montant': 725000.5,
  },
];

/// Champ **qui ne déclare RIEN** au-delà de son sous-schéma et de ses colonnes :
/// c'est lui qui porte l'assertion de défaut.
const ZFieldSpec _champDefaut = ZFieldSpec(
  name: 'lignes',
  type: EditionFieldType.subItems,
  label: 'Lignes',
  config: ZSubListConfig(
    itemFields: _sousChamps,
    summaryColumns: _colonnes,
  ),
);

Widget _hote(Widget enfant, {bool consultation = false}) => ZcrudScope(
      acl: const ZAllowAllAcl(),
      child: MaterialApp(
        home: Scaffold(
          body: ZReadModeScope(
            readMode: consultation,
            child: SingleChildScrollView(child: enfant),
          ),
        ),
      ),
    );

Future<void> _monter(
  WidgetTester tester, {
  required ZFieldSpec champ,
  List<Map<String, dynamic>> items = _lignes,
  double largeur = 1000,
  double hauteur = 3000,
  bool consultation = false,
}) async {
  await tester.binding.setSurfaceSize(Size(largeur, hauteur));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_hote(
    ZSubListFieldWidget(
      field: champ,
      initialValue: items,
      onChanged: (_) {},
    ),
    consultation: consultation,
  ));
  await tester.pumpAndSettle();
}

/// La table de résumé native, **sous le champ** (jamais une `Table` d'ailleurs).
Finder _table() => find.descendant(
      of: find.byType(ZSubListFieldWidget),
      matching: find.byType(Table),
    );

/// Rectangle **GLOBAL des glyphes réellement peints** de [texte].
///
/// 🔴 Mesure indispensable, et pas une coquetterie : dans une `Table`, chaque
/// cellule est posée sous une contrainte de largeur **serrée** (celle de sa
/// colonne). `tester.getTopLeft`/`getTopRight` d'un `Text` de cellule rendent
/// donc les bords de la COLONNE, identiques pour toutes les cellules — une
/// assertion de cadrage écrite avec eux serait **vide** (elle passerait aussi
/// bien avec `TextAlign.start`). Ce qui se déplace quand le cadrage change,
/// c'est le texte À L'INTÉRIEUR de la cellule : c'est donc lui qu'on mesure.
Rect _glyphes(WidgetTester tester, String texte) {
  final RenderParagraph paragraphe =
      tester.renderObject<RenderParagraph>(find.text(texte));
  final List<TextBox> boites = paragraphe.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: texte.length),
  );
  expect(boites, isNotEmpty, reason: 'aucun glyphe peint pour « $texte »');
  var gauche = boites.first.left;
  var droite = boites.first.right;
  for (final TextBox b in boites) {
    if (b.left < gauche) gauche = b.left;
    if (b.right > droite) droite = b.right;
  }
  final Offset origine = paragraphe.localToGlobal(Offset.zero);
  return Rect.fromLTRB(
    origine.dx + gauche,
    origine.dy,
    origine.dx + droite,
    origine.dy + paragraphe.size.height,
  );
}

/// Cellules d'**en-tête** montées (nœud `header`).
Finder _enTetes() => find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.header == true,
      description: 'cellule d’en-tête de colonne',
    );

void main() {
  // ── (A) LE DÉFAUT EST `compact` ────────────────────────────────────────────
  group('(A) le défaut est compact', () {
    testWidgets(
      'une config qui ne déclare PAS displayMode rend une table + une fenêtre '
      'par item — jamais des sous-formulaires empilés',
      (WidgetTester tester) async {
        await _monter(tester, champ: _champDefaut);

        // La table est là…
        expect(_table(), findsOneWidget);
        // …avec ses en-têtes.
        expect(_enTetes(), findsNWidgets(3));
        // Les actions par item du mode compact sont offertes.
        expect(find.byIcon(Icons.visibility), findsNWidgets(2));
        expect(find.byIcon(Icons.edit), findsNWidgets(2));
        expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
        // 🔴 Et AUCUN sous-champ n'est déballé : c'est ce qui distingue le
        // compact de l'inline, et c'est l'assertion qui rougit si le défaut
        // repasse à `inline`.
        expect(find.byType(TextFormField), findsNothing);
      },
    );

    testWidgets(
      'un champ subItems SANS config (cas du générateur) suit le même défaut',
      (WidgetTester tester) async {
        // `@ZcrudModel` émet `ZFieldSpec(name:…, type: subItems)` **sans
        // config** pour un sous-modèle : c'est le cas où l'hôte n'a rien choisi
        // du tout, donc celui où le défaut compte le plus.
        const champSansConfig = ZFieldSpec(
          name: 'lignes',
          type: EditionFieldType.subItems,
          label: 'Lignes',
        );
        await _monter(tester, champ: champSansConfig);

        // Sans sous-schéma il n'y a pas de colonne, donc pas de table : ce qui
        // se mesure ici est le MODE, par ses actions de ligne (le compact en a,
        // l'inline n'en a pas).
        expect(find.byIcon(Icons.visibility), findsNWidgets(2));
        expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
        expect(find.byType(TextFormField), findsNothing);
      },
    );
  });

  // ── (B) LA VOIE DE RETOUR ─────────────────────────────────────────────────
  group('(B) displayMode: inline rend l\'ancien défaut', () {
    testWidgets(
      'sous-formulaires imbriqués empilés : 2 items × 2 champs = 4 champs '
      'vivants, réordonnancement, aucune table, aucune action de fenêtre',
      (WidgetTester tester) async {
        const champInline = ZFieldSpec(
          name: 'lignes',
          type: EditionFieldType.subItems,
          label: 'Lignes',
          config: ZSubListConfig(
            itemFields: _sousChamps,
            summaryColumns: _colonnes,
            displayMode: ZSubListDisplayMode.inline,
          ),
        );
        await _monter(tester, champ: champInline);

        // Structure de l'ancien défaut, telle qu'elle était rendue en v1.9.0 :
        // chaque item déballe TOUS ses sous-champs.
        expect(find.byType(TextFormField), findsNWidgets(4));
        // Les valeurs sont dans des champs VIVANTS, pas dans des cellules.
        expect(
          find.widgetWithText(TextFormField, 'Fer'),
          findsOneWidget,
        );
        // Réordonnancement inline (monter/descendre) + retrait.
        expect(find.byIcon(Icons.arrow_upward), findsNWidgets(2));
        expect(find.byIcon(Icons.arrow_downward), findsNWidgets(2));
        // 🔴 Aucune des trois marques du compact.
        expect(_table(), findsNothing);
        expect(_enTetes(), findsNothing);
        expect(find.byIcon(Icons.visibility), findsNothing);
      },
    );

    testWidgets(
      'le retour arrière ne coûte QU\'une ligne : deux configs identiques à '
      'displayMode près',
      (WidgetTester tester) async {
        const defaut = ZSubListConfig(itemFields: _sousChamps);
        const inline = ZSubListConfig(
          itemFields: _sousChamps,
          displayMode: ZSubListDisplayMode.inline,
        );
        // Elles diffèrent (sinon le défaut n'aurait pas changé)…
        expect(defaut == inline, isFalse);
        // …et le défaut est bien `compact`, lu sur la donnée elle-même.
        expect(defaut.displayMode, ZSubListDisplayMode.compact);
        // …et par RIEN d'autre : reconstruire l'une depuis l'autre en ne
        // changeant que `displayMode` les rend égales.
        const retour = ZSubListConfig(
          itemFields: _sousChamps,
          displayMode: ZSubListDisplayMode.inline,
        );
        expect(retour, inline);
        expect(retour.hashCode, inline.hashCode);
      },
    );
  });

  // ── (C) UN VRAI RENDU TABULAIRE ───────────────────────────────────────────
  group('(C) le rendu est tabulaire', () {
    testWidgets(
      'largeurs SUIVANT LE CONTENU : deux contenus différents, deux largeurs '
      'différentes (géométrie, pas apparence)',
      (WidgetTester tester) async {
        await _monter(tester, champ: _champDefaut, largeur: 1200);

        final double xDesignation =
            tester.getTopLeft(find.text(kLibelleDesignation)).dx;
        final double xQuantite =
            tester.getTopLeft(find.text(kLibelleQuantite)).dx;
        final double xMontant =
            tester.getTopLeft(find.text(kLibelleMontant)).dx;

        final double largeurDesignation = xQuantite - xDesignation;
        final double largeurQuantite = xMontant - xQuantite;

        expect(largeurDesignation, greaterThan(0));
        expect(largeurQuantite, greaterThan(0));
        // La colonne « Désignation » porte « Ciment CPJ 35 — sacs de 50 kg » ;
        // la colonne « Quantité » porte « 5 » et « 40 ». Des colonnes de
        // largeur égale rendraient ces deux mesures identiques.
        expect(
          largeurQuantite,
          lessThan(largeurDesignation - 50),
          reason: 'les colonnes ne suivent pas leur contenu',
        );
      },
    );

    testWidgets(
      'en-têtes SOLIDAIRES : chaque cellule tombe exactement sous son en-tête',
      (WidgetTester tester) async {
        await _monter(tester, champ: _champDefaut, largeur: 1200);

        // Colonne textuelle : les DÉBUTS de glyphes coïncident.
        expect(
          _glyphes(tester, 'Fer').left,
          closeTo(_glyphes(tester, kLibelleDesignation).left, 0.5),
          reason: 'la cellule ne tombe pas sous son en-tête',
        );
        // Colonne numérique : ce sont les FINS qui coïncident (cadrage de fin) —
        // l'en-tête est cadré COMME sa colonne, sinon il désignerait de côté.
        expect(
          _glyphes(tester, '40').right,
          closeTo(_glyphes(tester, kLibelleQuantite).right, 0.5),
          reason: 'l’en-tête numérique n’est pas cadré comme sa colonne',
        );
      },
    );

    testWidgets(
      '🔴 les valeurs NUMÉRIQUES sont cadrées en FIN : deux nombres de '
      'longueurs différentes partagent leur bord de fin, pas leur bord de début',
      (WidgetTester tester) async {
        await _monter(tester, champ: _champDefaut, largeur: 1200);

        // Colonne « Quantité » (type déclaré `integer`) : « 5 » et « 40 ».
        expect(
          _glyphes(tester, '5').right,
          closeTo(_glyphes(tester, '40').right, 0.5),
          reason: 'la colonne numérique n’est pas cadrée en fin',
        );
        expect(
          _glyphes(tester, '5').left,
          greaterThan(_glyphes(tester, '40').left + 1),
          reason: 'la colonne numérique est cadrée au DÉBUT (donc illisible en '
              'colonne)',
        );

        // Colonne « Montant HT » (colonne CALCULÉE, numérique par ses
        // décimales) : même règle, et la mise en forme est appliquée.
        expect(find.text('1500.00'), findsOneWidget);
        expect(find.text('725000.50'), findsOneWidget);
        expect(
          _glyphes(tester, '1500.00').right,
          closeTo(_glyphes(tester, '725000.50').right, 0.5),
        );
        expect(
          _glyphes(tester, '1500.00').left,
          greaterThan(_glyphes(tester, '725000.50').left + 1),
        );

        // CONTRE-TÉMOIN : une colonne TEXTUELLE reste cadrée au DÉBUT — deux
        // valeurs de longueurs très différentes y partagent leur bord de début,
        // pas leur bord de fin.
        final Rect court = _glyphes(tester, 'Fer');
        final Rect long = _glyphes(tester, 'Ciment CPJ 35 — sacs de 50 kg');
        expect(
          court.left,
          closeTo(long.left, 0.5),
          reason: 'une colonne textuelle ne doit PAS être cadrée en fin',
        );
        expect(court.right, lessThan(long.right - 1));
      },
    );
  });

  // ── (D) LE SEUIL DE PERFORMANCE ───────────────────────────────────────────
  group('(D) budget de lignes : la bascule est mesurable des DEUX côtés', () {
    List<Map<String, dynamic>> lignes(int n) => <Map<String, dynamic>>[
          for (int i = 0; i < n; i++)
            <String, dynamic>{'designation': 'L$i', 'quantite': i},
        ];

    const ZFieldSpec champDeuxColonnes = ZFieldSpec(
      name: 'lignes',
      type: EditionFieldType.subItems,
      label: 'Lignes',
      config: ZSubListConfig(
        itemFields: _sousChamps,
        summaryFields: <String>['designation', 'quantite'],
      ),
    );

    testWidgets('AU budget : une vraie table', (WidgetTester tester) async {
      await _monter(
        tester,
        champ: champDeuxColonnes,
        items: lignes(ZSubListFieldWidget.summaryTableRowBudget),
        largeur: 1200,
        hauteur: 8000,
      );
      expect(_table(), findsOneWidget);
      expect(_enTetes(), findsNWidgets(2));
      expect(find.text('L59'), findsOneWidget);
    });

    testWidgets('budget + 1 : plus de table, un rendu construit à la demande',
        (WidgetTester tester) async {
      await _monter(
        tester,
        champ: champDeuxColonnes,
        items: lignes(ZSubListFieldWidget.summaryTableRowBudget + 1),
        largeur: 1200,
        hauteur: 8000,
      );
      expect(_table(), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ZSubListFieldWidget),
          matching: find.byType(ListView),
        ),
        findsOneWidget,
      );
      // Le repli n'AMPUTE rien : en-têtes et lignes restent rendus.
      expect(_enTetes(), findsNWidgets(2));
      expect(find.text('L60'), findsOneWidget);
    });
  });

  // ── (E) UNE COLONNE NON ÉDITABLE ──────────────────────────────────────────
  testWidgets(
    '(E) une colonne hors sous-schéma S\'AFFICHE dans la table et NE DEVIENT '
    'PAS saisissable',
    (WidgetTester tester) async {
      await _monter(tester, champ: _champDefaut, largeur: 1200);

      // (1) Elle s'affiche — en-tête et valeurs mises en forme.
      expect(find.text(kLibelleMontant), findsOneWidget);
      expect(find.text('1500.00'), findsOneWidget);

      // (2) Elle n'est pas saisissable : le formulaire d'item ne monte que les
      // `itemFields`. Ouvrir la ligne le prouve.
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.widgetWithText(TextFormField, '1500'), findsNothing);
      expect(find.widgetWithText(TextFormField, '1500.00'), findsNothing);
      // Les deux champs déclarés, eux, sont bien là.
      expect(
        find.widgetWithText(TextFormField, 'Ciment CPJ 35 — sacs de 50 kg'),
        findsOneWidget,
      );
    },
  );

  // ── (F) a11y ──────────────────────────────────────────────────────────────
  group('(F) a11y', () {
    testWidgets('chaque en-tête est annoncé comme un en-tête',
        (WidgetTester tester) async {
      final SemanticsHandle poignee = tester.ensureSemantics();
      await _monter(tester, champ: _champDefaut, largeur: 1200);
      expect(_enTetes(), findsNWidgets(3));
      poignee.dispose();
    });

    testWidgets(
        'une cellule est annoncée « libellé : valeur » — le libellé vit dans '
        'l\'en-tête, hors de portée d\'un parcours par ligne',
        (WidgetTester tester) async {
      final SemanticsHandle poignee = tester.ensureSemantics();
      await _monter(tester, champ: _champDefaut, largeur: 1200);
      expect(
        tester.getSemantics(find.text('725000.50')),
        matchesSemantics(label: kLibelleMontant, value: '725000.50'),
      );
      poignee.dispose();
    });

    testWidgets('les actions de ligne gardent leur cible de 48 dp',
        (WidgetTester tester) async {
      await _monter(tester, champ: _champDefaut, largeur: 1200);
      final Size taille = tester.getSize(find.byIcon(Icons.edit).first);
      final Size cible =
          tester.getSize(find.ancestor(
        of: find.byIcon(Icons.edit).first,
        matching: find.byType(IconButton),
      ).first);
      expect(taille.width, greaterThan(0));
      expect(cible.width, greaterThanOrEqualTo(48));
      expect(cible.height, greaterThanOrEqualTo(48));
    });
  });

  // ── (G) CONTRE-TÉMOINS ────────────────────────────────────────────────────
  group('(G) contre-témoins', () {
    testWidgets(
      'showSummaryHeaders: false conserve le résumé DÉFILANT historique — '
      'aucune table, aucun en-tête',
      (WidgetTester tester) async {
        const champDefilant = ZFieldSpec(
          name: 'lignes',
          type: EditionFieldType.subItems,
          label: 'Lignes',
          config: ZSubListConfig(
            itemFields: _sousChamps,
            summaryColumns: _colonnes,
            showSummaryHeaders: false,
          ),
        );
        await _monter(tester, champ: champDefilant, largeur: 1200);

        expect(_table(), findsNothing);
        expect(_enTetes(), findsNothing);
        expect(find.text(kLibelleMontant), findsNothing);
        // Une bande défilante par ligne, comme avant.
        expect(
          find.byWidgetPredicate(
            (Widget w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
            description: 'résumé défilant horizontalement',
          ),
          findsNWidgets(2),
        );
      },
    );

    testWidgets(
      'sous le seuil de largeur, AUCUNE table n\'est construite (le repli '
      'responsive de la v1.4.1 garde la main)',
      (WidgetTester tester) async {
        await _monter(tester, champ: _champDefaut, largeur: 360);
        expect(_table(), findsNothing);
        expect(_enTetes(), findsNothing);
        // Le libellé descend dans CHAQUE ligne, et la valeur n'est pas tronquée.
        expect(find.text(kLibelleMontant), findsNWidgets(2));
        expect(
          tester
              .renderObject<RenderBox>(
                  find.text('Ciment CPJ 35 — sacs de 50 kg'))
              .size
              .height,
          greaterThan(20),
          reason: 'la valeur ne revient pas à la ligne (elle est tronquée)',
        );
      },
    );
  });
}
