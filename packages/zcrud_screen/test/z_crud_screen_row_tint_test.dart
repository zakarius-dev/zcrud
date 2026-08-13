// Gardes de la **coloration de ligne** (`ZCrudScreen.rowColor`).
//
// Ce que ces gardes mesurent :
//
// (a) le seam reçoit l'ENTITÉ TYPÉE, pas une cellule formatée — c'est ce qui
//     fait qu'un renommage devient une erreur de compilation, et non une
//     couleur qui disparaît ;
// (b) la couleur DÉCLARÉE est celle qui est peinte, derrière la tuile ;
// (c) sans `rowColor`, le rendu est STRICTEMENT inchangé (aucun widget de
//     plus) — et une ligne dont le seam rend `null` l'est aussi ;
// (d) la teinte descend dans les layouts à tuiles : liste, tuile de
//     l'application, et GRILLE de cartes ;
// (e) PIÈGE D'ÉGALITÉ : un builder de couleur est une FONCTION ; il ne doit
//     entrer ni dans la requête de rendu ni dans son `==`. Deux écrans qui ne
//     diffèrent que par leur `rowColor` produisent la MÊME requête ;
// (f) ACCESSIBILITÉ (AD-13) : le libellé qui double la couleur est annoncé.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

const Color _rouge = Color(0xFFB3261E);
const Color _vert = Color(0xFF2E7D32);

/// Deux lignes, deux états métier distincts : sans cet écart, une garde de
/// couleur serait verte même si le seam rendait toujours la même chose.
const List<Item> _deuxLignes = <Item>[
  Item(id: 'i1', name: 'Alpha', qty: 1),
  Item(id: 'i2', name: 'Beta', qty: 9),
];

/// La couleur peinte pour la ligne de [id], ou `null` si la ligne n'est pas
/// teintée. Lue sur la décoration RÉELLEMENT posée dans l'arbre.
Color? _tintOf(WidgetTester tester, String id) {
  final finder = find.byKey(ValueKey<String>('zRowTint_$id'));
  if (finder.evaluate().isEmpty) return null;
  final box = tester.widget<DecoratedBox>(finder);
  return (box.decoration as BoxDecoration).color;
}

void main() {
  testWidgets(
      'garde (a) — le seam reçoit l\'ENTITÉ TYPÉE : la décision se prend sur '
      'le champ du modèle, pas sur une cellule', (tester) async {
    final repo = FakeItemRepo(_deuxLignes);
    final vues = <String>[];
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        rowColor: (context, item) {
          // `item` est un `Item` : le compilateur le sait, et `item.qty` est
          // un `int` — pas un `Object?` sorti d'une map de cellules.
          vues.add('${item.name}:${item.qty}');
          return item.qty > 5 ? const ZRowTint(_rouge) : null;
        },
      ),
    );
    expect(vues, containsAll(<String>['Alpha:1', 'Beta:9']));
    // La décision suit l'entité, ligne par ligne.
    expect(_tintOf(tester, 'i2'), _rouge);
    expect(_tintOf(tester, 'i1'), isNull);
    repo.dispose();
  });

  testWidgets(
      'garde (b) — la couleur DÉCLARÉE est celle qui est peinte, et la tuile '
      'reste rendue par-dessus', (tester) async {
    final repo = FakeItemRepo(_deuxLignes);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        rowColor: (context, item) =>
            ZRowTint(item.name == 'Alpha' ? _rouge : _vert),
      ),
    );
    expect(_tintOf(tester, 'i1'), _rouge);
    expect(_tintOf(tester, 'i2'), _vert);
    // La teinte n'a rien remplacé : le contenu de la ligne est toujours là.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'garde (c) — sans `rowColor`, le rendu est STRICTEMENT inchangé : aucune '
      'décoration de ligne dans l\'arbre', (tester) async {
    /// Compte les `DecoratedBox` de l'arbre — la mesure d'un « widget de plus ».
    Future<int> decorationCount(ZCrudScreen<Item> screen) async {
      await pumpScreen(tester, screen);
      final count = find.byType(DecoratedBox).evaluate().length;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      return count;
    }

    final sansRepo = FakeItemRepo(_deuxLignes);
    final sans = await decorationCount(
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(sansRepo),
        registry: buildItemRegistry(),
      ),
    );
    sansRepo.dispose();

    // Seam DÉCLARÉ mais rendant `null` partout : même rendu que sans seam —
    // une ligne sans teinte n'est pas une ligne teintée en transparent.
    final nulRepo = FakeItemRepo(_deuxLignes);
    final nul = await decorationCount(
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(nulRepo),
        registry: buildItemRegistry(),
        rowColor: (context, item) => null,
      ),
    );
    nulRepo.dispose();

    final avecRepo = FakeItemRepo(_deuxLignes);
    final avec = await decorationCount(
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(avecRepo),
        registry: buildItemRegistry(),
        rowColor: (context, item) => const ZRowTint(_rouge),
      ),
    );
    avecRepo.dispose();

    expect(nul, sans);
    // …et le relevé n'est pas vide de sens : déclarer une teinte AJOUTE bien
    // une décoration par ligne.
    expect(avec, sans + _deuxLignes.length);
  });

  testWidgets(
      'garde (d) — la teinte descend dans la tuile de l\'APPLICATION et dans '
      'la GRILLE de cartes', (tester) async {
    // Tuile de l'application, layout par défaut.
    final tuileRepo = FakeItemRepo(_deuxLignes);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(tuileRepo),
        registry: buildItemRegistry(),
        itemBuilder: (context, item, columns) =>
            Text(item.name, key: ValueKey<String>('carte_${item.id}')),
        rowColor: (context, item) =>
            item.name == 'Alpha' ? const ZRowTint(_rouge) : null,
      ),
    );
    expect(find.byKey(const ValueKey('carte_i1')), findsOneWidget);
    expect(_tintOf(tester, 'i1'), _rouge);
    expect(_tintOf(tester, 'i2'), isNull);
    tuileRepo.dispose();

    // Grille de cartes déclarée par l'application : la tuile typée y descend
    // (`withEntityTiles`), la teinte avec elle.
    final grilleRepo = FakeItemRepo(_deuxLignes);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(grilleRepo),
        registry: buildItemRegistry(),
        layout: const ZListGridLayout(mainAxisExtent: 120),
        itemBuilder: (context, item, columns) =>
            Text(item.name, key: ValueKey<String>('carte_${item.id}')),
        rowColor: (context, item) =>
            item.name == 'Beta' ? const ZRowTint(_vert) : null,
      ),
    );
    expect(find.byType(GridView), findsOneWidget);
    expect(_tintOf(tester, 'i2'), _vert);
    expect(_tintOf(tester, 'i1'), isNull);
    grilleRepo.dispose();
  });

  testWidgets(
      'garde (e) — PIÈGE D\'ÉGALITÉ : la couleur n\'entre pas dans la requête '
      'de rendu — deux builders différents, une seule et même requête',
      (tester) async {
    Future<ZListRenderRequest> requestWith(
      ZRowTintBuilder<Item>? rowColor,
    ) async {
      final repo = FakeItemRepo(_deuxLignes);
      late ZListRenderRequest captured;
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          // Le layout `custom` reçoit la requête COMPLÈTE : c'est le seul
          // point d'observation de ce qui descend réellement au rendu.
          layout: ZListCustomLayout(
            customView: (context, request) {
              captured = request;
              return const SizedBox.shrink();
            },
          ),
          rowColor: rowColor,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      repo.dispose();
      return captured;
    }

    final rouge = await requestWith((context, item) => const ZRowTint(_rouge));
    final vert = await requestWith((context, item) => const ZRowTint(_vert));
    final aucune = await requestWith(null);

    // Anti-vacuité : la requête observée porte bien des lignes et des colonnes.
    expect(rouge.rows, hasLength(_deuxLignes.length));
    expect(rouge.columns, isNotEmpty);

    // Le cœur de la garde : la couleur ne descend pas dans la requête, donc
    // deux couleurs différentes n'en font pas deux requêtes différentes — la
    // mémoïsation du rendu est préservée.
    expect(rouge, vert);
    expect(rouge.hashCode, vert.hashCode);
    expect(rouge, aucune);
    expect(rouge.hashCode, aucune.hashCode);
  });

  testWidgets(
      'garde (f) — ACCESSIBILITÉ : le libellé qui double la couleur est '
      'ANNONCÉ, et il reste optionnel', (tester) async {
    final repo = FakeItemRepo(_deuxLignes);
    final handle = tester.ensureSemantics();
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        rowColor: (context, item) => item.name == 'Alpha'
            ? const ZRowTint(_rouge, semanticLabel: 'Relancée')
            : const ZRowTint(_vert),
      ),
    );
    // La ligne teintée ET libellée porte l'annonce : ce que la couleur veut
    // dire est dit, pour qui ne la voit pas.
    expect(
      tester.getSemantics(find.byKey(const ValueKey('zRowTint_i1'))).label,
      contains('Relancée'),
    );
    // La ligne teintée SANS libellé n'en invente aucun — le doublage est un
    // choix de l'application, jamais un texte fabriqué par le socle.
    final beta =
        tester.getSemantics(find.byKey(const ValueKey('zRowTint_i2'))).label;
    expect(beta, isNot(contains('Relancée')));
    // …et ce relevé n'est pas vide de sens : la ligne EST bien dans l'arbre
    // sémantique, avec son propre contenu.
    expect(beta, contains('Beta'));
    expect(_tintOf(tester, 'i2'), _vert);
    handle.dispose();
    repo.dispose();
  });

  test(
      'garde (f bis) — `ZRowTint` est une valeur : deux teintes identiques le '
      'sont, deux libellés différents ne le sont pas', () {
    expect(
      const ZRowTint(_rouge, semanticLabel: 'Relancée'),
      const ZRowTint(_rouge, semanticLabel: 'Relancée'),
    );
    expect(
      const ZRowTint(_rouge, semanticLabel: 'Relancée').hashCode,
      const ZRowTint(_rouge, semanticLabel: 'Relancée').hashCode,
    );
    expect(
      const ZRowTint(_rouge, semanticLabel: 'Relancée'),
      isNot(const ZRowTint(_rouge, semanticLabel: 'Close')),
    );
    expect(const ZRowTint(_rouge), isNot(const ZRowTint(_vert)));
  });
}
