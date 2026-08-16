/// Gardes — **une sous-liste reste lisible sur une surface étroite**.
///
/// Constat d'appareil (téléphone, fiche en consultation, quatre colonnes de
/// résumé) : la table à colonnes de largeur égale ne délivrait plus aucune
/// information — en-têtes tronqués (« Date … », « Poste … ») au-dessus de
/// cellules tronquées (« ven. … »).
///
/// Ce que ces gardes établissent :
/// * **(a)** en consultation, à largeur de téléphone et avec quatre colonnes,
///   chaque valeur est rendue **en entier** (aucune ligne de texte n'est
///   coupée) ;
/// * **(b)** dès que la place suffit, la table alignée est **inchangée**
///   (en-têtes présents, colonnes de largeur égale, cellules tombant
///   exactement sous leur en-tête) ;
/// * **(c)** les en-têtes restent cohérents : jamais d'en-tête orphelin
///   au-dessus d'un empilement — replié, le libellé descend dans chaque ligne ;
/// * **(d)** le résumé **sans** en-têtes (défilant) n'est pas dégradé ;
/// * **(e)** les trois modes de sous-liste restent ce qu'ils sont ;
/// * **(f)** un couple libellé/valeur est annoncé comme un couple, et les
///   actions de ligne gardent leur cible tactile ;
/// * **(g)** le seuil de repli est **dérivé de jetons déclarés**, jamais codé
///   en dur.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ── Données de la recette d'appareil ────────────────────────────────────────

const String kLibelleDebut = 'Date de début';
const String kLibelleFin = 'Date de fin';
const String kLibelleNom = 'Nom';
const String kLibellePoste = 'Poste occupé';

const List<ZFieldSpec> _champsItem = <ZFieldSpec>[
  ZFieldSpec(name: 'debut', type: EditionFieldType.text, label: kLibelleDebut),
  ZFieldSpec(name: 'fin', type: EditionFieldType.text, label: kLibelleFin),
  ZFieldSpec(name: 'nom', type: EditionFieldType.text, label: kLibelleNom),
  ZFieldSpec(name: 'poste', type: EditionFieldType.text, label: kLibellePoste),
];

const List<String> _colonnes = <String>['debut', 'fin', 'nom', 'poste'];

/// Un item : les quatre valeurs de la recette (longues, comme en production).
const Map<String, dynamic> _item1 = <String, dynamic>{
  'debut': 'vendredi 12 avril 2024',
  'fin': 'lundi 30 septembre 2024',
  'nom': 'Amivi Koffi',
  'poste': 'Chef de section des régimes suspensifs',
};

const Map<String, dynamic> _item2 = <String, dynamic>{
  'debut': 'mardi 1 octobre 2024',
  'fin': 'jeudi 20 février 2025',
  'nom': 'Kodjo Mensah',
  'poste': 'Adjoint au chef de bureau des douanes',
};

ZFieldSpec _champ({
  bool enTetes = true,
  bool consultation = true,
  ZSubListDisplayMode mode = ZSubListDisplayMode.compact,
  List<String> colonnes = _colonnes,
}) =>
    ZFieldSpec(
      name: 'changements',
      type: EditionFieldType.subItems,
      label: 'Changements subis',
      readOnly: consultation,
      config: ZSubListConfig(
        itemFields: _champsItem,
        displayMode: mode,
        summaryFields: colonnes,
        showSummaryHeaders: enTetes,
      ),
    );

Widget _hote(
  Widget enfant, {
  bool consultation = true,
  ZcrudTheme? jetons,
}) =>
    ZcrudScope(
      acl: const ZAllowAllAcl(),
      theme: jetons,
      child: MaterialApp(
        home: Scaffold(
          body: ZReadModeScope(
            readMode: consultation,
            child: SingleChildScrollView(child: enfant),
          ),
        ),
      ),
    );

Widget _sousListe(ZFieldSpec champ, List<Map<String, dynamic>> items) =>
    ZSubListFieldWidget(
      field: champ,
      initialValue: items,
      onChanged: (_) {},
    );

/// Monte la sous-liste sur une surface de [largeur] logique.
Future<void> _monter(
  WidgetTester tester, {
  required double largeur,
  ZFieldSpec? champ,
  List<Map<String, dynamic>> items = const <Map<String, dynamic>>[_item1],
  bool consultation = true,
  ZcrudTheme? jetons,
}) async {
  await tester.binding.setSurfaceSize(Size(largeur, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_hote(
    _sousListe(champ ?? _champ(consultation: consultation), items),
    consultation: consultation,
    jetons: jetons,
  ));
  await tester.pumpAndSettle();
}

/// Cellules d'**en-tête** effectivement montées (nœud `header`).
Finder _enTetes() => find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.header == true,
      description: 'cellule d’en-tête de colonne',
    );

/// Le paragraphe qui rend [texte] — la mesure porte sur le texte **rendu**,
/// pas sur la présence du widget.
RenderParagraph _paragraphe(WidgetTester tester, String texte) =>
    tester.renderObject<RenderParagraph>(find.text(texte));

/// Toutes les valeurs de résumé attendues pour [items].
List<String> _valeurs(List<Map<String, dynamic>> items) => <String>[
      for (final Map<String, dynamic> item in items)
        for (final String colonne in _colonnes) item[colonne] as String,
    ];

void main() {
  // ── (a) ──────────────────────────────────────────────────────────────────
  testWidgets(
    '(a) consultation, 360 dp, 4 colonnes : chaque valeur est rendue en entier',
    (WidgetTester tester) async {
      await _monter(tester, largeur: 360);

      for (final String valeur in _valeurs(const <Map<String, dynamic>>[
        _item1,
      ])) {
        expect(
          find.text(valeur),
          findsOneWidget,
          reason: 'valeur absente du rendu : $valeur',
        );
        expect(
          _paragraphe(tester, valeur).didExceedMaxLines,
          isFalse,
          reason: 'valeur TRONQUÉE sur un téléphone : $valeur',
        );
        // 🔴 …et elle tient dans l'écran. Cette seconde assertion a été AJOUTÉE
        // avec le rendu tabulaire, et elle n'est pas décorative : mesurée, la
        // seule assertion de troncature ne mord PLUS contre la perte du repli.
        // Une `Table` privée de son repli ne tronque pas — elle DÉBORDE (ses
        // colonnes se déploient au-delà de la surface), et le texte, lui, reste
        // entier. La garde d'origine restait donc verte en laissant l'écran
        // illisible : c'est le mode de défaillance qui a changé, pas le défaut.
        expect(
          tester.getRect(find.text(valeur)).right,
          lessThanOrEqualTo(360.5),
          reason: 'valeur rejetée HORS DE L’ÉCRAN sur un téléphone : $valeur',
        );
      }

      // Le libellé qui la coiffe est lui aussi rendu en entier.
      for (final String libelle in const <String>[
        kLibelleDebut,
        kLibelleFin,
        kLibelleNom,
        kLibellePoste,
      ]) {
        expect(
          _paragraphe(tester, libelle).didExceedMaxLines,
          isFalse,
          reason: 'libellé TRONQUÉ sur un téléphone : $libelle',
        );
      }
    },
  );

  // ── (b) ──────────────────────────────────────────────────────────────────
  //
  // 🔴 Cette garde a CHANGÉ d'assertion, et il faut dire laquelle : elle
  // exigeait des **colonnes de largeur ÉGALE**. C'était le rendu de v1.4.1 —
  // et c'était précisément le défaut que la table corrige (une colonne de
  // dates et une colonne d'intitulés n'ont aucune raison d'avoir la même
  // largeur). Ce qu'elle établit désormais : la table tient (elle ne se replie
  // pas), chaque cellule tombe EXACTEMENT sous son en-tête — ce qui reste la
  // propriété qui compte, et qui est maintenant structurelle : en-tête et
  // cellules sont les MÊMES colonnes d'une même `Table` — et les largeurs
  // **suivent le contenu**.
  testWidgets(
    '(b) contre-témoin : à largeur suffisante, la table tient et ses colonnes '
    'suivent le contenu',
    (WidgetTester tester) async {
      await _monter(tester, largeur: 1400);

      // Les quatre en-têtes sont là…
      expect(_enTetes(), findsNWidgets(4));

      // …et chaque cellule tombe EXACTEMENT sous son en-tête.
      const List<String> libelles = <String>[
        kLibelleDebut,
        kLibelleFin,
        kLibelleNom,
        kLibellePoste,
      ];
      final List<double> debutsEnTete = <double>[
        for (final String l in libelles) tester.getTopLeft(find.text(l)).dx,
      ];
      final List<double> debutsCellule = <double>[
        for (final String c in _colonnes)
          tester.getTopLeft(find.text(_item1[c] as String)).dx,
      ];
      for (int i = 0; i < 4; i++) {
        expect(
          debutsCellule[i],
          closeTo(debutsEnTete[i], 0.5),
          reason: 'colonne $i désalignée de son en-tête',
        );
      }

      // Largeurs SUIVANT LE CONTENU : le pas entre deux en-têtes est la
      // largeur de la colonne de gauche. La colonne « Nom » (« Amivi Koffi »)
      // est plus étroite que la colonne « Date de fin » (« lundi 30 septembre
      // 2024 ») — mesure de GÉOMÉTRIE, pas d'apparence.
      final List<double> largeurs = <double>[
        for (int i = 1; i < 4; i++) debutsEnTete[i] - debutsEnTete[i - 1],
      ];
      for (final double l in largeurs) {
        expect(l, greaterThan(0));
      }
      expect(
        largeurs[2], // colonne « Nom »
        lessThan(largeurs[1] - 20), // colonne « Date de fin »
        reason: 'les colonnes ne suivent pas leur contenu (largeurs uniformes)',
      );
      // …et ce n'est pas un hasard de deux colonnes : au moins deux pas
      // DIFFÈRENT franchement, ce qu'une table à colonnes égales ne peut pas
      // produire.
      expect(
        largeurs.reduce((double a, double b) => a > b ? a : b) -
            largeurs.reduce((double a, double b) => a < b ? a : b),
        greaterThan(20),
        reason: 'toutes les colonnes ont la même largeur',
      );
    },
  );

  // ── (c) ──────────────────────────────────────────────────────────────────
  testWidgets(
    '(c) replié : aucun en-tête orphelin — le libellé descend dans la ligne',
    (WidgetTester tester) async {
      await _monter(
        tester,
        largeur: 360,
        items: const <Map<String, dynamic>>[_item1, _item2],
      );

      // Aucune ligne d'en-tête : elle ne coifferait plus rien.
      expect(_enTetes(), findsNothing);

      // Le libellé apparaît une fois PAR LIGNE, collé à sa valeur.
      for (final String libelle in const <String>[
        kLibelleDebut,
        kLibelleFin,
        kLibelleNom,
        kLibellePoste,
      ]) {
        expect(
          find.text(libelle),
          findsNWidgets(2),
          reason: 'le libellé $libelle ne suit pas ses deux valeurs',
        );
      }
    },
  );

  testWidgets(
    '(c) aligné : le libellé n\'apparaît QUE dans l\'en-tête',
    (WidgetTester tester) async {
      await _monter(
        tester,
        largeur: 1400,
        items: const <Map<String, dynamic>>[_item1, _item2],
      );
      for (final String libelle in const <String>[
        kLibelleDebut,
        kLibelleFin,
        kLibelleNom,
        kLibellePoste,
      ]) {
        expect(find.text(libelle), findsOneWidget);
      }
    },
  );

  // ── (d) ──────────────────────────────────────────────────────────────────
  testWidgets(
    '(d) sans en-têtes : le résumé défilant n\'est pas dégradé à 360 dp',
    (WidgetTester tester) async {
      await _monter(
        tester,
        largeur: 360,
        champ: _champ(enTetes: false),
        items: const <Map<String, dynamic>>[_item1, _item2],
      );

      // Une bande défilante par ligne, comme avant.
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
          description: 'résumé défilant horizontalement',
        ),
        findsNWidgets(2),
      );
      // Aucun libellé ne s'invite dans la ligne.
      expect(find.text(kLibelleDebut), findsNothing);
      // Et rien n'est coupé (largeur intrinsèque).
      for (final String valeur in _valeurs(const <Map<String, dynamic>>[
        _item1,
        _item2,
      ])) {
        expect(_paragraphe(tester, valeur).didExceedMaxLines, isFalse);
      }
    },
  );

  // ── (e) ──────────────────────────────────────────────────────────────────
  testWidgets(
    '(e) mode inline : inchangé à 360 dp (sous-champs, aucune ligne résumé)',
    (WidgetTester tester) async {
      await _monter(
        tester,
        largeur: 360,
        champ: _champ(mode: ZSubListDisplayMode.inline),
      );
      expect(_enTetes(), findsNothing);
      // Le mode inline n'a pas d'action de ligne.
      expect(find.byIcon(Icons.visibility), findsNothing);
      // Les sous-champs sont bien déballés (le libellé de chacun est rendu).
      expect(find.text(kLibellePoste), findsWidgets);
    },
  );

  testWidgets(
    '(e) mode tags : inchangé à 360 dp (une puce par item)',
    (WidgetTester tester) async {
      await _monter(
        tester,
        largeur: 360,
        champ: _champ(mode: ZSubListDisplayMode.tags),
        items: const <Map<String, dynamic>>[_item1, _item2],
      );
      expect(find.byType(InputChip), findsNWidgets(2));
      expect(_enTetes(), findsNothing);
    },
  );

  // ── (f) ──────────────────────────────────────────────────────────────────
  testWidgets(
    '(f) a11y : le couple libellé/valeur est annoncé comme un couple',
    (WidgetTester tester) async {
      final SemanticsHandle poignee = tester.ensureSemantics();
      await _monter(tester, largeur: 360);

      expect(
        tester.getSemantics(find.text(_item1['nom'] as String)),
        matchesSemantics(label: kLibelleNom, value: _item1['nom'] as String),
      );
      poignee.dispose();
    },
  );

  testWidgets(
    '(f) a11y : l\'action de ligne garde sa cible tactile de 48 dp',
    (WidgetTester tester) async {
      await _monter(tester, largeur: 360);
      final Size taille = tester.getSize(find.byType(IconButton).first);
      expect(taille.width, greaterThanOrEqualTo(48));
      expect(taille.height, greaterThanOrEqualTo(48));
    },
  );

  // ── (g) ──────────────────────────────────────────────────────────────────
  group('(g) le seuil est dérivé de jetons déclarés', () {
    const List<String> troisColonnes = <String>['debut', 'fin', 'nom'];

    testWidgets('sans jeton : 3 colonnes tiennent à 800 dp',
        (WidgetTester tester) async {
      await _monter(
        tester,
        largeur: 800,
        champ: _champ(colonnes: troisColonnes),
      );
      expect(_enTetes(), findsNWidgets(3));
    });

    testWidgets('élargir `readRowLabelWidth` déplace le seuil : la même '
        'surface se replie', (WidgetTester tester) async {
      await _monter(
        tester,
        largeur: 800,
        champ: _champ(colonnes: troisColonnes),
        jetons: const ZcrudTheme(readRowLabelWidth: 240),
      );
      expect(_enTetes(), findsNothing);
    });

    testWidgets('`subListColumnMinWidth` prime sur la dérivation',
        (WidgetTester tester) async {
      await _monter(
        tester,
        largeur: 800,
        champ: _champ(colonnes: troisColonnes),
        jetons: const ZcrudTheme(
          readRowLabelWidth: 240,
          subListColumnMinWidth: 160,
        ),
      );
      expect(_enTetes(), findsNWidgets(3));
    });
  });

  // ── (h) ──────────────────────────────────────────────────────────────────
  group('(h) les actions de ligne entrent dans le calcul', () {
    testWidgets('consultation à 800 dp (une action) : la table tient',
        (WidgetTester tester) async {
      await _monter(tester, largeur: 800);
      expect(_enTetes(), findsNWidgets(4));
    });

    testWidgets(
      'édition à la MÊME largeur (trois actions) : la table s\'empile — '
      'et les valeurs restent entières',
      (WidgetTester tester) async {
        await _monter(tester, largeur: 800, consultation: false);
        expect(_enTetes(), findsNothing);
        for (final String valeur in _valeurs(const <Map<String, dynamic>>[
          _item1,
        ])) {
          expect(_paragraphe(tester, valeur).didExceedMaxLines, isFalse);
        }
      },
    );
  });
}
