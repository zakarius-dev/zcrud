// CR DODLP — « Quatre formes de consultation sur cinq ne peuvent pas être
// encadrées » (2026-08-16, zcrud v1.4.1).
//
// Le constat de l'hôte : `readFillColor` / `readBorderColor` / `readBorderWidth`
// sont posés, valides, lus — et SANS EFFET dans quatre formes sur cinq. Il l'a
// établi en échantillonnant les pixels de l'écran, sur appareil, et non à l'œil,
// « précisément parce qu'un fond `grey.shade50` sur un fond d'écran `#ECEFF1`
// est une différence qu'un regard peut manquer » : (236,239,241) rendu là où
// (250,250,250) était déclaré.
//
// 🔴 Ces gardes mesurent donc la MÊME chose que lui : la couleur EFFECTIVEMENT
// PEINTE, lue dans l'image rendue (`RenderRepaintBoundary.toImage`). Lire
// `Card.color` reviendrait à relire le jeton d'entrée à travers un paramètre —
// cela prouverait le câblage, jamais la peinture.
//
// Les quatre premiers groupes reprennent LITTÉRALEMENT les quatre critères de
// recette du §7 du CR ; le cinquième garde ce que le CR demande de NE PAS
// changer (§5) et ce que l'architecture impose (AD-13).
//
// ⚠️ ÉCART DU CR LUI-MÊME. Le §2 affirme que « les quatre autres formes passent
// par `_dense(...)` ». C'est FAUX : `listTile` passe par `_listTile(...)`, qui
// monte un `ListTile` nu. Le remède proposé au §4 (« que `_dense` enveloppe son
// enfant ») aurait donc manqué le critère de recette n°3 du CR — « le filet
// suit `readBorderColor`/`readBorderWidth` dans les CINQ formes ». Le groupe (3)
// monte les cinq formes une par une, `listTile` comprise, pour que cet écart ne
// puisse pas se reformer.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Le fond d'écran mesuré par l'hôte : `#ECEFF1` = (236, 239, 241).
const _fondEcran = Color(0xFFECEFF1);

/// Le fond de fiche du legacy DODLP : `grey.shade50` = (250, 250, 250).
/// C'est l'écart que « le regard peut manquer », et que l'hôte a dû mesurer.
const _fondFiche = Color(0xFFFAFAFA);

/// Filet franchement distinct des deux fonds : un pixel de filet ne peut pas
/// être confondu avec un pixel de fond ni avec un pixel de fond d'écran.
const _filet = Color(0xFF3F51B5);

const _racine = ValueKey<String>('racine-repaint');

/// Hauteur de chaque forme, telle que la garde de référence
/// (`z_read_field_layout_test.dart`) l'asserte. Encadrer une fiche ne doit en
/// déplacer AUCUNE : c'est ce qui prouve que la hauteur minimale de `card`
/// (`readCardMinHeight`, 72) n'a pas été importée avec le conteneur.
const _hauteurs = <ZReadFieldLayout, double>{
  ZReadFieldLayout.card: 72,
  ZReadFieldLayout.listTile: 72,
  ZReadFieldLayout.definition: 54,
  ZReadFieldLayout.inlineRow: 36,
  ZReadFieldLayout.compact: 28,
};

Widget _champ(ZReadFieldLayout forme) => ZReadOnlyFieldCard(
      label: 'Nom',
      value: const Text('Ada'),
      copyText: 'Ada',
      layout: forme,
    );

/// Écran de mesure : un fond d'écran CONNU, une fiche posée dessus, et une
/// frontière de repeinture pour pouvoir en lire les pixels.
Widget _ecran(ZReadFieldLayout forme, {ZcrudTheme? theme}) => RepaintBoundary(
      key: _racine,
      child: MaterialApp(
        home: ZcrudScope(
          theme: theme,
          child: Scaffold(
            backgroundColor: _fondEcran,
            // `Column` et non `Align` : la fiche doit recevoir une contrainte
            // verticale NON BORNÉE, comme sous la liste de `DynamicEdition` —
            // c'est ce qui lui laisse prendre sa hauteur propre (celle que la
            // garde de référence asserte), au lieu de remplir l'écran.
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(width: 800, child: _champ(forme)),
              ],
            ),
          ),
        ),
      ),
    );

/// Les pixels réellement rendus, indexés en coordonnées logiques.
class _Pixels {
  const _Pixels(this._octets, this._largeur);

  final ByteData _octets;
  final int _largeur;

  Color enPoint(double x, double y) {
    final i = ((y.round() * _largeur) + x.round()) * 4;
    return Color.fromARGB(
      _octets.getUint8(i + 3),
      _octets.getUint8(i),
      _octets.getUint8(i + 1),
      _octets.getUint8(i + 2),
    );
  }
}

Future<_Pixels> _pixels(WidgetTester tester) async {
  final frontiere =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_racine));
  final image = await tester.runAsync(() => frontiere.toImage());
  final octets = await tester
      .runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
  final largeur = image!.width;
  image.dispose();
  return _Pixels(octets!, largeur);
}

Rect _rect(WidgetTester tester) =>
    tester.getRect(find.byType(ZReadOnlyFieldCard));

/// Un point INTÉRIEUR à la fiche et à l'écart de tout glyphe : la gouttière du
/// début de ligne (le retrait horizontal vaut 16 dans les cinq formes), en
/// retrait d'un filet même épais. C'est le pendant du « dans la carte »
/// échantillonné par l'hôte — et il évite le bouton de copie de `card`, qui
/// occupe la fin de la ligne.
Offset _dansLaFiche(Rect r) => Offset(r.left + 8, r.center.dy);

Finder _carteDe(Finder fiche) =>
    find.descendant(of: fiche, matching: find.byType(Card));

Finder get _carte => _carteDe(find.byType(ZReadOnlyFieldCard));

BorderSide _filetRendu(WidgetTester tester) =>
    ((tester.widget<Card>(_carte).shape! as RoundedRectangleBorder)).side;

List<String> _presseParier(WidgetTester tester) {
  final captures = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        captures.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return captures;
}

void main() {
  group('(1) §7.1 — une fiche en `definition` déclarant `readFillColor` peint '
      'ce fond, vérifié AU PIXEL', () {
    testWidgets('le pixel rendu dans la fiche est le fond DÉCLARÉ, et le pixel '
        "hors de la fiche reste celui de l'écran", (tester) async {
      await tester.pumpWidget(_ecran(
        ZReadFieldLayout.definition,
        theme: const ZcrudTheme(readFillColor: _fondFiche),
      ));
      await tester.pumpAndSettle();

      final r = _rect(tester);
      final px = await _pixels(tester);
      // « dans la carte » — la ligne que l'hôte attendait à (250,250,250).
      expect(px.enPoint(_dansLaFiche(r).dx, _dansLaFiche(r).dy), _fondFiche);
      // « entre deux cartes » — le fond d'écran, inchangé : la fiche peint SA
      // surface et rien de plus.
      expect(px.enPoint(r.center.dx, r.bottom + 20), _fondEcran);
    });

    testWidgets('🔴 le défaut mesuré par l\'hôte : SANS le jeton, le même pixel '
        "rend le fond de l'écran", (tester) async {
      // C'est la ligne du milieu de son tableau — et elle doit le rester : sans
      // déclaration, la fiche est posée à plat (cf. groupe 2).
      await tester.pumpWidget(_ecran(ZReadFieldLayout.definition));
      await tester.pumpAndSettle();

      final r = _rect(tester);
      final px = await _pixels(tester);
      expect(px.enPoint(_dansLaFiche(r).dx, _dansLaFiche(r).dy), _fondEcran);
    });

    testWidgets('les QUATRE formes non-`card` peignent le fond déclaré',
        (tester) async {
      for (final forme in ZReadFieldLayout.values
          .where((f) => f != ZReadFieldLayout.card)) {
        await tester.pumpWidget(_ecran(
          forme,
          theme: const ZcrudTheme(readFillColor: _fondFiche),
        ));
        await tester.pumpAndSettle();

        final r = _rect(tester);
        final px = await _pixels(tester);
        expect(px.enPoint(_dansLaFiche(r).dx, _dansLaFiche(r).dy), _fondFiche,
            reason: '$forme : le fond déclaré n\'est pas peint');
      }
    });
  });

  group('(2) §7.2 — la même fiche SANS jeton déclaré reste posée à plat, à '
      "l'identique d'aujourd'hui", () {
    for (final forme in ZReadFieldLayout.values) {
      testWidgets('${forme.name} — aucun conteneur en trop, hauteur '
          '${_hauteurs[forme]}, pixel = fond d\'écran', (tester) async {
        await tester.pumpWidget(_ecran(forme));
        await tester.pumpAndSettle();

        // `card` monte SA carte (elle l'a toujours fait) ; les quatre autres
        // n'en montent aucune tant que rien n'est déclaré.
        expect(_carte.evaluate().length,
            forme == ZReadFieldLayout.card ? 1 : 0,
            reason: '$forme : le défaut a changé de structure');
        expect(_rect(tester).height, _hauteurs[forme], reason: '$forme');

        final r = _rect(tester);
        final px = await _pixels(tester);
        expect(px.enPoint(_dansLaFiche(r).dx, _dansLaFiche(r).dy), _fondEcran,
            reason: '$forme : le défaut peint quelque chose');
      });
    }

    testWidgets('🔴 le PIÈGE : `readBorderColor` SEUL ne déclenche rien — sans '
        'largeur, il n\'y a rien à peindre', (tester) async {
      // Poser un conteneur ici serait un enrobage strictement invisible : la
      // largeur retombe à 0, donc `BorderSide.none`, donc aucun trait ; et
      // aucun fond n'est déclaré. La règle retenue est donc : fond déclaré OU
      // largeur strictement positive.
      for (final forme in ZReadFieldLayout.values
          .where((f) => f != ZReadFieldLayout.card)) {
        await tester.pumpWidget(_ecran(
          forme,
          theme: const ZcrudTheme(readBorderColor: _filet),
        ));
        await tester.pumpAndSettle();

        expect(_carte, findsNothing, reason: '$forme : enrobage invisible monté');
        final r = _rect(tester);
        final px = await _pixels(tester);
        expect(px.enPoint(r.left + 2, r.center.dy), _fondEcran, reason: '$forme');
      }
    });

    testWidgets('une largeur NULLE explicite ne déclenche rien non plus',
        (tester) async {
      await tester.pumpWidget(_ecran(
        ZReadFieldLayout.definition,
        theme: const ZcrudTheme(readBorderColor: _filet, readBorderWidth: 0),
      ));
      await tester.pumpAndSettle();
      expect(_carte, findsNothing);
    });
  });

  group('(3) §7.3 — le filet suit `readBorderColor`/`readBorderWidth` dans les '
      'CINQ formes', () {
    // ⚠️ `listTile` est le piège du CR : elle ne passe PAS par `_dense`. Cette
    // boucle est écrite sur `ZReadFieldLayout.values` — elle ne peut pas
    // oublier une forme sans le dire.
    for (final forme in ZReadFieldLayout.values) {
      testWidgets('${forme.name} — le filet est DÉCLARÉ et PEINT',
          (tester) async {
        await tester.pumpWidget(_ecran(
          forme,
          theme: const ZcrudTheme(readBorderColor: _filet, readBorderWidth: 4),
        ));
        await tester.pumpAndSettle();

        // Un seul conteneur : aucune forme n'en empile deux.
        expect(_carte.evaluate().length, 1, reason: '$forme');
        final side = _filetRendu(tester);
        expect(side.style, BorderStyle.solid, reason: '$forme');
        expect(side.width, 4, reason: '$forme');
        expect(side.color, _filet, reason: '$forme');

        // Et il est réellement PEINT : le pixel du bord porte la couleur du
        // filet (bande [left, left+4], échantillonnée en son milieu).
        final r = _rect(tester);
        final px = await _pixels(tester);
        expect(px.enPoint(r.left + 2, r.center.dy), _filet,
            reason: '$forme : filet déclaré mais non peint');
      });
    }

    testWidgets('le rayon est celui de la fiche (`inputRadius`), identique '
        'dans les cinq formes', (tester) async {
      final rayons = <BorderRadius>{};
      for (final forme in ZReadFieldLayout.values) {
        await tester.pumpWidget(_ecran(
          forme,
          theme: const ZcrudTheme(readBorderColor: _filet, readBorderWidth: 4),
        ));
        await tester.pumpAndSettle();
        rayons.add(
          (tester.widget<Card>(_carte).shape! as RoundedRectangleBorder)
              .borderRadius as BorderRadius,
        );
      }
      expect(rayons.length, 1, reason: 'encadré hétérogène : $rayons');
      expect(rayons.single,
          BorderRadius.all(const ZcrudTheme().inputRadius));
    });
  });

  group('(4) §7.4 — `card` ne change EN RIEN', () {
    testWidgets('sans jeton : une seule carte, 72 de haut, fond translucide, '
        'filet absent, bouton de copie présent', (tester) async {
      await tester.pumpWidget(_ecran(ZReadFieldLayout.card));
      await tester.pumpAndSettle();

      expect(_carte.evaluate().length, 1);
      expect(_rect(tester).height, 72);
      expect(tester.widget<Card>(_carte).color!.a, 0);
      expect(_filetRendu(tester).style, BorderStyle.none);
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);

      final r = _rect(tester);
      final px = await _pixels(tester);
      expect(px.enPoint(r.left + 2, r.center.dy), _fondEcran);
    });

    testWidgets('avec les TROIS jetons : toujours UNE seule carte, même '
        'géométrie, même bouton', (tester) async {
      await tester.pumpWidget(_ecran(ZReadFieldLayout.card));
      await tester.pumpAndSettle();
      final reference = _rect(tester);

      await tester.pumpWidget(_ecran(
        ZReadFieldLayout.card,
        theme: const ZcrudTheme(
          readFillColor: _fondFiche,
          readBorderColor: _filet,
          readBorderWidth: 4,
        ),
      ));
      await tester.pumpAndSettle();

      // 🔴 Le risque du correctif : enrober `card` une seconde fois.
      expect(_carte.evaluate().length, 1);
      expect(_rect(tester), reference);
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      final side = _filetRendu(tester);
      expect(side.color, _filet);
      expect(side.width, 4);
      expect(tester.widget<Card>(_carte).color, _fondFiche);
    });
  });

  group('(5) Ce que le CR demande de NE PAS changer (§5) et ce que AD-13 '
      'impose', () {
    testWidgets('🔴 encadrer NE DÉPLACE AUCUNE hauteur : `readCardMinHeight` '
        'reste propre à `card`', (tester) async {
      for (final forme in ZReadFieldLayout.values) {
        await tester.pumpWidget(_ecran(
          forme,
          theme: const ZcrudTheme(
            readFillColor: _fondFiche,
            readBorderColor: _filet,
            readBorderWidth: 4,
          ),
        ));
        await tester.pumpAndSettle();
        expect(_rect(tester).height, _hauteurs[forme],
            reason: '$forme : la hauteur a bougé en s\'encadrant');
      }
    });

    testWidgets('`readCardMinHeight` déclaré ne gouverne QUE `card`, même une '
        'fois les autres formes encadrées', (tester) async {
      for (final forme in ZReadFieldLayout.values) {
        await tester.pumpWidget(_ecran(
          forme,
          theme: const ZcrudTheme(
            readFillColor: _fondFiche,
            readBorderWidth: 4,
            readCardMinHeight: 200,
          ),
        ));
        await tester.pumpAndSettle();
        expect(
          _rect(tester).height,
          forme == ZReadFieldLayout.card ? 200 : _hauteurs[forme],
          reason: '$forme',
        );
      }
    });

    testWidgets('aucun bouton de copie n\'apparaît dans les formes denses '
        'encadrées (§5 du CR)', (tester) async {
      for (final forme in <ZReadFieldLayout>[
        ZReadFieldLayout.definition,
        ZReadFieldLayout.inlineRow,
        ZReadFieldLayout.compact,
      ]) {
        await tester.pumpWidget(_ecran(
          forme,
          theme: const ZcrudTheme(readFillColor: _fondFiche, readBorderWidth: 4),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(IconButton), findsNothing, reason: '$forme');
        expect(find.byIcon(Icons.copy_outlined), findsNothing, reason: '$forme');
      }
    });

    testWidgets('🔴 AD-13 — un fond peint ne fait pas d\'un texte un contrôle : '
        'aucune encre, aucun `InkWell` dans les formes denses', (tester) async {
      for (final forme in <ZReadFieldLayout>[
        ZReadFieldLayout.definition,
        ZReadFieldLayout.inlineRow,
        ZReadFieldLayout.compact,
      ]) {
        await tester.pumpWidget(_ecran(
          forme,
          theme: const ZcrudTheme(readFillColor: _fondFiche, readBorderWidth: 4),
        ));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(ZReadOnlyFieldCard),
            matching: find.byType(InkWell),
          ),
          findsNothing,
          reason: '$forme : une cible de 48 se serait imposée',
        );
        expect(
          find.descendant(
            of: find.byType(ZReadOnlyFieldCard),
            matching: find.byType(GestureDetector),
          ),
          findsWidgets,
          reason: '$forme : la copie par appui long a disparu',
        );
      }
    });

    testWidgets('🔴 la SURFACE PEINTE répond au geste : appui long au bord de '
        "l'encadré, à l'écart du texte, et la valeur est copiée",
        (tester) async {
      for (final forme in <ZReadFieldLayout>[
        ZReadFieldLayout.definition,
        ZReadFieldLayout.inlineRow,
        ZReadFieldLayout.compact,
      ]) {
        final captures = _presseParier(tester);
        await tester.pumpWidget(_ecran(
          forme,
          theme: const ZcrudTheme(readFillColor: _fondFiche, readBorderWidth: 4),
        ));
        await tester.pumpAndSettle();

        final r = _rect(tester);
        // Le point échantillonné au groupe (1) : il porte le fond peint, il
        // doit donc porter le geste.
        await tester.longPressAt(_dansLaFiche(r));
        await tester.pumpAndSettle();
        expect(captures, <String>['Ada'], reason: '$forme');
      }
    });

    testWidgets('la sémantique survit à l\'encadrement : la paire libellé / '
        'valeur reste annoncée dans les cinq formes', (tester) async {
      for (final forme in ZReadFieldLayout.values) {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_ecran(
          forme,
          theme: const ZcrudTheme(readFillColor: _fondFiche, readBorderWidth: 4),
        ));
        await tester.pumpAndSettle();
        final noeud = tester.getSemantics(find.byType(ZReadOnlyFieldCard));
        expect(noeud.label, 'Nom', reason: '$forme');
        expect(noeud.value, 'Ada', reason: '$forme');
        handle.dispose();
      }
    });
  });
}
