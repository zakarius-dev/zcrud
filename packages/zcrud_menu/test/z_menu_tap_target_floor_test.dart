/// 🔴 Garde du **plancher de 48 dp** — mesuré HORS `PopupMenuItem` et EN
/// COMPOSITION CONTRAINTE.
///
/// ## Pourquoi cette garde existe
///
/// Le plancher de [ZMenuEntryTile] était **déclaré et non tenu** : un
/// `ConstrainedBox` applique `enforce(contraintes du parent)`, donc il est
/// écrasé sous contrainte serrée. Mesure du défaut, dans la grille à deux
/// colonnes que la dartdoc du fichier cite elle-même comme cas cible (IFFD,
/// `childAspectRatio: 3.5`) : **`Size(100.0, 28.6)`**, soit 60 % de la cible.
///
/// Les gardes existantes ne pouvaient pas le voir : elles mesuraient toutes un
/// ancêtre `PopupMenuItem`, qui impose déjà `kMinInteractiveDimension` par
/// Material. Elles mesuraient **le plancher de Flutter, jamais le nôtre** —
/// et restaient vertes quand on mettait le nôtre à zéro.
///
/// Cette garde tient les trois moitiés de la promesse, chacune avec sa propre
/// injection mordante :
/// 1. contrainte LÂCHE ⇒ la cellule se rend à 48 dp (`ConstrainedBox`) ;
/// 2. contrainte SERRÉE de l'hôte ⇒ le défaut est **DÉNONCÉ** (erreur de
///    disposition en debug), jamais silencieux ;
/// 3. disposition du SOCLE (`ZMenuEntryTile.gridDelegate`) ⇒ la cellule tient
///    réellement 48 dp **en grille**, sans aucune erreur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_menu/zcrud_menu.dart';

ZMenuEntry _entree(String id, VoidCallback? onSelected) =>
    ZMenuEntry(id: id, label: id, onSelected: onSelected);

Widget _hote(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 220, child: child)),
  ),
);

/// Grille de l'HÔTE — reproduit `folder_actions_menu_zcrud.dart:_grid` (IFFD,
/// LECTURE SEULE) : deux colonnes, hauteur DÉRIVÉE de la largeur.
Widget _grilleHote(List<String> ids, void Function(String) onTap) => _hote(
  GridView.count(
    shrinkWrap: true,
    crossAxisCount: 2,
    childAspectRatio: 3.5,
    children: [
      for (final id in ids)
        ZMenuEntryTile(
          key: ValueKey(id),
          entry: _entree(id, () {}),
          onSelected: () => onTap(id),
          direction: Axis.vertical,
        ),
    ],
  ),
);

/// Grille du SOCLE — même densité de colonnes, plancher porté par la
/// DISPOSITION.
Widget _grilleSocle(
  List<String> ids,
  void Function(String) onTap, {
  double mainAxisExtent = kZMenuMinTapTarget,
}) => _hote(
  GridView(
    shrinkWrap: true,
    gridDelegate: ZMenuEntryTile.gridDelegate(
      crossAxisCount: 2,
      mainAxisExtent: mainAxisExtent,
    ),
    children: [
      for (final id in ids)
        ZMenuEntryTile(
          key: ValueKey(id),
          entry: _entree(id, () {}),
          onSelected: () => onTap(id),
          direction: Axis.vertical,
        ),
    ],
  ),
);

void main() {
  testWidgets('1. contrainte LÂCHE : la cellule porte elle-même ses 48 dp', (
    tester,
  ) async {
    await tester.pumpWidget(
      _hote(
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ZMenuEntryTile(
            key: const ValueKey('A'),
            entry: _entree('A', () {}),
            onSelected: () {},
          ),
        ),
      ),
    );
    final cible = find.byKey(const ValueKey('A'));
    expect(cible, findsOneWidget, reason: 'contrôle positif : cellule montée');
    final taille = tester.getSize(cible);
    // 🔴 Mesure sur la CELLULE, pas sur un `PopupMenuItem` : sans le
    // `ConstrainedBox` de ZMenuEntryTile, la hauteur retombe à celle du texte.
    expect(
      taille.height,
      greaterThanOrEqualTo(kZMenuMinTapTarget),
      reason: '🔴 cellule à ${taille.height} dp — le plancher propre a disparu',
    );
    expect(taille.width, greaterThanOrEqualTo(kZMenuMinTapTarget));
  });

  testWidgets(
    '2. grille de l\'HÔTE (childAspectRatio) : l\'écrasement est DÉNONCÉ',
    (tester) async {
      // Une SEULE cellule : chaque cellule écrasée émet son erreur, et
      // `takeException` n'en rend qu'une.
      await tester.pumpWidget(_grilleHote(<String>['A'], (_) {}));
      final cible = find.byKey(const ValueKey('A'));
      expect(
        cible,
        findsOneWidget,
        reason: 'contrôle positif : cellule montée',
      );

      // Le fait mesuré, écrit noir sur blanc : la cellule EST écrasée. Aucun
      // dispositif interne ne peut l'empêcher — un enfant ne se rend jamais
      // plus grand que la place imposée.
      final taille = tester.getSize(cible);
      expect(
        taille.height,
        lessThan(kZMenuMinTapTarget),
        reason:
            'sonde : si cette grille ne produit PLUS une cellule écrasée, '
            'le reste du test ne prouve rien — mettre à jour la sonde.',
      );

      final erreur = tester.takeException();
      expect(
        erreur,
        isA<FlutterError>(),
        reason:
            '🔴 cellule rendue à ${taille.height} dp SANS aucune erreur : '
            'le plancher est de nouveau écrasable EN SILENCE — exactement le '
            'défaut CR-CHAT M-3.',
      );
      expect(
        erreur.toString(),
        contains('gridDelegate'),
        reason:
            'le message doit NOMMER le remède, sinon l\'hôte ne peut que '
            'constater le rouge sans savoir quoi en faire',
      );
    },
  );

  testWidgets(
    '3. grille du SOCLE : 48 dp RÉELLEMENT tenus en composition contrainte',
    (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _grilleSocle(<String>['A', 'B', 'C', 'D'], taps.add),
      );

      final cellules = find.byType(ZMenuEntryTile);
      expect(
        cellules,
        findsWidgets,
        reason:
            'contrôle positif : sans cellule montée, la boucle ci-dessous '
            'serait verte à vide',
      );
      expect(tester.widgetList(cellules), hasLength(4));

      for (final id in <String>['A', 'B', 'C', 'D']) {
        final taille = tester.getSize(find.byKey(ValueKey(id)));
        expect(
          taille.height,
          greaterThanOrEqualTo(kZMenuMinTapTarget),
          reason:
              '🔴 « $id » : ${taille.height} dp en GRILLE — le plancher '
              'porté par la disposition a été perdu',
        );
        expect(taille.width, greaterThanOrEqualTo(kZMenuMinTapTarget));
      }
      expect(
        tester.takeException(),
        isNull,
        reason: 'la disposition du socle ne doit produire AUCUNE dénonciation',
      );

      // La cible est réellement ATTEIGNABLE sur toute sa hauteur, pas seulement
      // grande : tap à 1 dp du bord haut de la cellule.
      final haut = tester.getTopLeft(find.byKey(const ValueKey('A')));
      final taille = tester.getSize(find.byKey(const ValueKey('A')));
      await tester.tapAt(Offset(haut.dx + taille.width / 2, haut.dy + 1));
      await tester.pump();
      expect(taps, <String>['A']);
    },
  );

  testWidgets(
    '4. `gridDelegate` REFUSE une demande sous le plancher (24 dp ⇒ 48 dp)',
    (tester) async {
      await tester.pumpWidget(
        _grilleSocle(<String>['A', 'B'], (_) {}, mainAxisExtent: 24),
      );
      final taille = tester.getSize(find.byKey(const ValueKey('A')));
      expect(
        taille.height,
        greaterThanOrEqualTo(kZMenuMinTapTarget),
        reason:
            '🔴 ${taille.height} dp : `mainAxisExtent` n\'est plus borné '
            'par le bas — un appelant peut de nouveau demander une cible '
            'sous-dimensionnée et l\'obtenir',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('5. cellule NON tappable écrasée : aucune dénonciation', (
    tester,
  ) async {
    // La cellule sans `onSelected` ne porte AUCUN geste propre : c'est
    // `PopupMenuItem` qui porte la cible. Dénoncer ici ferait rougir un cas
    // conforme — et rendrait la garde n° 2 ininterprétable.
    await tester.pumpWidget(
      _hote(
        SizedBox(
          height: 20,
          child: ZMenuEntryTile(
            key: const ValueKey('A'),
            entry: _entree('A', () {}),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('A')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
