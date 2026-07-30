/// **CR-IFFD-37** — `belowSubtitle` était **inutilisable à densité contrainte**.
///
/// CR-IFFD-28 / CR-LEX-75 ont livré le slot, correctement : il est au bon
/// endroit, il est annonçable, `null` ne change rien. Et IFFD **n'a pas pu s'en
/// servir** — leur grille alloue `childAspectRatio: itemWidth / 210`, et à
/// 210 dp chaque carte affichait `RenderFlex overflowed`. Le MÊME texte composé
/// dans le slot `counts` tenait, lui : parce que `counts` vit dans une zone
/// **déjà bornée** (`Expanded`) quand le bloc titre + sous-titre, sizé au
/// contenu et à enfants tous INFLEXIBLES, **s'ajoutait** à la hauteur au lieu
/// d'y **participer**.
///
/// 🔴 **Ce que les gardes précédentes ne voyaient pas** : présence, position,
/// ancrage, sémantique — jamais le **coût vertical**. Une carte peut satisfaire
/// les quatre et déborder de 30 px sur chaque cellule d'une grille dense. C'est
/// exactement ce qui s'est produit. La garde décisive de ce fichier monte donc
/// les trois cartes dans une cellule de **210 dp** — la mesure réelle d'IFFD —
/// et exige **l'absence d'exception de layout**.
///
/// ⚠️ **Contrôle négatif obligatoire** : la même carte SANS le slot doit tenir
/// dans une hauteur **encore plus faible**. Sans lui, la garde ne prouverait pas
/// que le coût venait du slot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Cellule mesurée par IFFD (`childAspectRatio: itemWidth / 210`).
const double _kCelluleIffd = 210;

/// Largeur de cellule d'une grille dense : c'est elle qui fait passer le titre
/// à 2 lignes et le sous-titre à 2 lignes — la densité du défaut.
const double _kLargeurCellule = 180;

/// Jetons d'espacement d'un hôte réel (IFFD/lex), plus généreux que les défauts
/// du socle : le défaut se mesure à la densité des hôtes, pas à la nôtre.
const ZcrudTheme _dense = ZcrudTheme(gapS: 8, gapM: 16, gapL: 24);

const Key _belowKey = Key('below-subtitle');
const Widget _sousTitre = Text(
  'Mathématiques · 3e année · Semestre 2',
  key: _belowKey,
);

const String _titreDossier = 'Valeur en douane et méthodes de détermination';
const String _titreItem = 'Cours de chimie organique.pdf';

void _noop() {}

Widget _folder({Widget? below}) => ZFolderCard(
  title: _titreDossier,
  colorKey: 'primary',
  belowSubtitle: below,
  counts: const Text('12 fiches'),
  menu: const Icon(Icons.more_vert),
  onTap: _noop,
);

Widget _item({Widget? below}) => ZStudyToolsItemCard(
  title: _titreItem,
  subtitle: 'Modifié hier',
  belowSubtitle: below,
  leading: const Icon(Icons.description_outlined),
  trailing: const Icon(Icons.more_vert),
);

Widget _note({Widget? below}) => ZStudyNoteCard(
  title: _titreItem,
  subtitle: 'Modifié hier',
  belowSubtitle: below,
  leading: const Icon(Icons.description_outlined),
  actions: const Icon(Icons.more_vert),
);

/// Monte [card] dans une cellule de hauteur **exactement** [height].
///
/// ⚠️ La surface de test fait 800 dp : un `SizedBox` PLUS PETIT que la surface
/// est nécessaire pour que la contrainte s'applique réellement — d'où
/// [_hauteurRendue], qui le VÉRIFIE au lieu de le supposer.
Future<Object?> _pump(
  WidgetTester tester,
  Widget card, {
  required double height,
  double width = _kLargeurCellule,
}) => _pumpRaw(
  tester,
  SizedBox(width: width, height: height, child: card),
);

/// Monte [card] en hauteur **NON BORNÉE** (usage autonome) : un
/// `SingleChildScrollView` donne une contrainte verticale INFINIE — la seule
/// façon d'éprouver le second régime, `Center` fournissant, lui, un maximum
/// fini de 600 dp (donc le régime BORNÉ).
Future<Object?> _pumpNonBorne(WidgetTester tester, Widget card) => _pumpRaw(
  tester,
  SingleChildScrollView(
    child: SizedBox(width: _kLargeurCellule, child: card),
  ),
);

Future<Object?> _pumpRaw(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ZcrudScope(
        theme: _dense,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
  return tester.takeException();
}

double _hauteurRendue(WidgetTester tester) =>
    tester.getSize(find.byType(Card).first).height;

void main() {
  group('CR-IFFD-37 — coût vertical du slot `belowSubtitle`', () {
    testWidgets(
      '🔴 DÉCISIVE — ZFolderCard tient dans la cellule de 210 dp d\'IFFD',
      (WidgetTester tester) async {
        final Object? erreur = await _pump(
          tester,
          _folder(below: _sousTitre),
          height: _kCelluleIffd,
        );

        // 🔴 Régression à ré-injecter : replacer le bloc titre + sous-titre dans
        // une `Column(mainAxisSize: min)` à enfants INFLEXIBLES (l'état v0.27.0)
        // ⇒ `RenderFlex overflowed by 10 pixels on the bottom`.
        expect(
          erreur,
          isNull,
          reason:
              'le slot doit PARTICIPER à la contrainte de hauteur, pas s\'y ajouter',
        );
        // La contrainte s'applique VRAIMENT (piège de la surface de 800 dp).
        expect(_hauteurRendue(tester), _kCelluleIffd);
        expect(find.byKey(_belowKey), findsOneWidget);
      },
    );

    testWidgets(
      '🔴 DÉCISIVE — ZStudyToolsItemCard tient dans la cellule de 210 dp',
      (WidgetTester tester) async {
        final Object? erreur = await _pump(
          tester,
          _item(below: _sousTitre),
          height: _kCelluleIffd,
        );

        // 🔴 Régression : retirer le `Flexible` autour du slot (l'état
        // CR-LEX-75) ⇒ `RenderFlex overflowed by 66 pixels on the bottom`.
        expect(erreur, isNull);
        expect(_hauteurRendue(tester), _kCelluleIffd);
        expect(find.byKey(_belowKey), findsOneWidget);
      },
    );

    testWidgets(
      '🔴 DÉCISIVE — ZStudyNoteCard (façade) tient dans la cellule de 210 dp',
      (WidgetTester tester) async {
        // Couverture ÉGALE des trois cartes sœurs : c'est l'incohérence de
        // couverture que CR-IFFD-28 et CR-IFFD-34 reprochaient au socle.
        final Object? erreur = await _pump(
          tester,
          _note(below: _sousTitre),
          height: _kCelluleIffd,
        );

        expect(erreur, isNull);
        expect(_hauteurRendue(tester), _kCelluleIffd);
        expect(find.byKey(_belowKey), findsOneWidget);
      },
    );

    testWidgets(
      'CONTRÔLE NÉGATIF — sans le slot, la carte tenait DÉJÀ bien plus bas',
      (WidgetTester tester) async {
        // Sans ce contrôle, la garde décisive ne prouverait pas que le coût
        // venait du SLOT : une carte qui tient à 210 dp pourrait n'y tenir que
        // parce que 210 dp lui suffisent de toute façon.
        expect(await _pump(tester, _folder(), height: 100), isNull);
        expect(_hauteurRendue(tester), 100);
      },
    );

    testWidgets(
      'CONTRÔLE NÉGATIF — l\'item sans slot tenait déjà bien plus bas',
      (WidgetTester tester) async {
        expect(await _pump(tester, _item(), height: 80), isNull);
        expect(_hauteurRendue(tester), 80);
      },
    );

    testWidgets(
      '🔴 le slot ne coûte plus RIEN : mêmes hauteurs tenables avec et sans',
      (WidgetTester tester) async {
        // Le contrat de la CR, formulé en une mesure : à toute hauteur où la
        // carte SANS slot ne déborde pas, la carte AVEC slot ne déborde pas
        // non plus. Les débordements résiduels aux très petites hauteurs sont
        // ANTÉRIEURS au slot (ils se produisent aussi sans lui) et hors sujet.
        for (final double h in <double>[210, 160, 140, 120, 100]) {
          expect(
            await _pump(tester, _folder(below: _sousTitre), height: h),
            isNull,
            reason: 'ZFolderCard + slot à $h dp',
          );
        }
        for (final double h in <double>[210, 160, 140, 120, 100, 80]) {
          expect(
            await _pump(tester, _item(below: _sousTitre), height: h),
            isNull,
            reason: 'ZStudyToolsItemCard + slot à $h dp',
          );
        }
      },
    );
  });

  group('CR-IFFD-37 — garanties existantes NON régressées', () {
    testWidgets(
      'le titre reste ANCRÉ EN BAS et ellipsé en régime borné (patron lex)',
      (WidgetTester tester) async {
        await _pump(tester, _folder(), height: _kCelluleIffd);
        final Rect titreSansSlot = tester.getRect(find.text(_titreDossier));

        await _pump(tester, _folder(below: _sousTitre), height: _kCelluleIffd);
        final Rect titre = tester.getRect(find.text(_titreDossier));
        final Rect sous = tester.getRect(find.byKey(_belowKey));

        // 🔴 Régression : remplacer `AlignmentDirectional.bottomStart` par
        // `topStart` ⇒ le bloc cesse d'être ancré en bas.
        // Le bloc entier reste ancré en bas : le sous-titre occupe la ligne de
        // base que le titre occupait seul, et le titre remonte d'autant.
        expect(sous.bottom, closeTo(titreSansSlot.bottom, 0.01));
        expect(titre.bottom, lessThan(titreSansSlot.bottom));
        expect(sous.top, greaterThanOrEqualTo(titre.bottom - 0.01));
        // …et le titre reste ellipsé sur 2 lignes (jamais tronqué en dur).
        final Text texteTitre = tester.widget<Text>(find.text(_titreDossier));
        expect(texteTitre.maxLines, 2);
        expect(texteTitre.overflow, TextOverflow.ellipsis);
      },
    );

    testWidgets('régime NON BORNÉ : sizé au contenu, sans « unbounded height »', (
      WidgetTester tester,
    ) async {
      // 🔴 Régression : appliquer le chemin borné (LayoutBuilder + `Flexible`)
      // au régime non borné ⇒ « unbounded height » / colonne étirée.
      expect(await _pumpNonBorne(tester, _folder()), isNull);
      final double sansSlot = _hauteurRendue(tester);

      expect(await _pumpNonBorne(tester, _folder(below: _sousTitre)), isNull);
      final double avecSlot = _hauteurRendue(tester);
      final double hauteurSous = tester.getSize(find.byKey(_belowKey)).height;

      // Sizée AU CONTENU : la carte grandit exactement de l'espacement + la
      // hauteur du sous-titre — ni étirée à la surface, ni écrasée.
      expect(avecSlot, closeTo(sansSlot + _dense.gapS + hauteurSous, 0.01));
      expect(avecSlot, lessThan(600));
    });

    testWidgets('`null` ⇒ arbre STRICTEMENT inchangé (aucun nœud interposé)', (
      WidgetTester tester,
    ) async {
      // 🔴 Régression : rendre le nouveau chemin inconditionnel ⇒ des `Flexible`
      // apparaissent alors que le slot est absent (et les goldens rougissent).
      await _pump(tester, _folder(), height: _kCelluleIffd);
      expect(
        find.descendant(
          of: find.byType(ZFolderCard),
          matching: find.byType(Flexible),
        ),
        findsNothing,
      );

      await _pump(tester, _item(), height: _kCelluleIffd);
      final int flexiblesSansSlot = tester
          .widgetList(
            find.descendant(
              of: find.byType(ZStudyToolsItemCard),
              matching: find.byType(Flexible),
            ),
          )
          .length;
      await _pump(tester, _item(below: _sousTitre), height: _kCelluleIffd);
      expect(
        tester
            .widgetList(
              find.descendant(
                of: find.byType(ZStudyToolsItemCard),
                matching: find.byType(Flexible),
              ),
            )
            .length,
        flexiblesSansSlot + 1,
      );
    });

    testWidgets('♿ la sémantique du slot survit à la densité contrainte', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      // 🔴 Régression : envelopper le slot d'un `ExcludeSemantics` (ou le
      // laisser être écrasé à hauteur nulle) ⇒ le slot devient muet.
      await _pump(tester, _folder(below: _sousTitre), height: _kCelluleIffd);
      expect(
        find.bySemanticsLabel(RegExp('Mathématiques · 3e année · Semestre 2')),
        findsOneWidget,
      );

      await _pump(tester, _item(below: _sousTitre), height: _kCelluleIffd);
      expect(
        find.bySemanticsLabel(RegExp('Mathématiques · 3e année · Semestre 2')),
        findsOneWidget,
      );

      await _pump(tester, _note(below: _sousTitre), height: _kCelluleIffd);
      expect(
        find.bySemanticsLabel(RegExp('Mathématiques · 3e année · Semestre 2')),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
