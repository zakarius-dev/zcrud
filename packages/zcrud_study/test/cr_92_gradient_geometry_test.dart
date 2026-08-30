@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/src/presentation/z_default_folder_card.dart';

import 'support/z_sources.dart';

/// Dégradé de témoin **sans géométrie déclarée** : `LinearGradient` construit
/// sans `begin`/`end`, donc porteur des défauts Flutter NON directionnels
/// (`Alignment.centerLeft` / `Alignment.centerRight`). C'est exactement la
/// forme que produit un hôte qui ne s'est pas soucié du RTL.
const LinearGradient _sansGeometrie = LinearGradient(
  colors: <Color>[Color(0xFF102030), Color(0xFF405060)],
  stops: <double>[0, 1],
);

/// Dégradé de témoin **avec géométrie explicite** de l'hôte : la précédence
/// paramètre > jeton doit le laisser intact.
const LinearGradient _avecGeometrie = LinearGradient(
  colors: <Color>[Color(0xFF102030), Color(0xFF405060)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const ZGradientSpec _specSansGeometrie = ZGradientSpec(
  gradient: _sansGeometrie,
  onGradient: Color(0xFFFFFFFF),
);

const ZGradientSpec _specAvecGeometrie = ZGradientSpec(
  gradient: _avecGeometrie,
  onGradient: Color(0xFFFFFFFF),
);

const ZcrudTheme _jetonsDirectionnels = ZcrudTheme(
  gradientBegin: AlignmentDirectional.centerStart,
  gradientEnd: AlignmentDirectional.centerEnd,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ZcrudTheme? theme,
  TextDirection direction = TextDirection.ltr,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: ZcrudScope(
        theme: theme,
        child: Directionality(
          textDirection: direction,
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    ),
  );
}

/// Décoration RÉELLEMENT peinte par la bande de tête — lue sur le
/// `DecoratedBox` monté, jamais déduite d'une clé.
BoxDecoration _decorationBande(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byKey(ZDefaultFolderCard.accentKey),
      matching: find.byType(DecoratedBox),
    ),
  );
  return box.decoration as BoxDecoration;
}

void main() {
  group('CR-92 — géométrie directionnelle de la bande en dégradé', () {
    testWidgets(
      'G1 — INERTIE : sans jetons de thème, la bande porte le dégradé de '
      'l’hôte à l’identique (égalité stricte)',
      (WidgetTester tester) async {
        await _pump(
          tester,
          const ZDefaultFolderCard(
            title: 'Dossier',
            accentGradient: _specSansGeometrie,
          ),
        );

        final BoxDecoration decoration = _decorationBande(tester);
        // Égalité STRICTE avec la décoration figée avant modification : c'est
        // la condition pour qu'aucun hôte n'ait à toucher son code.
        expect(
          decoration,
          const BoxDecoration(gradient: _sansGeometrie),
          reason: 'sans jetons, le rendu doit rester celui de la version '
              'précédente, au champ près',
        );
        expect(decoration.gradient, same(_sansGeometrie));
      },
    );

    testWidgets(
      'G2 — jetons posés : la bande porte la géométrie DIRECTIONNELLE, '
      'couleurs et stops préservés',
      (WidgetTester tester) async {
        await _pump(
          tester,
          const ZDefaultFolderCard(
            title: 'Dossier',
            accentGradient: _specSansGeometrie,
          ),
          theme: _jetonsDirectionnels,
        );

        final LinearGradient rendu =
            _decorationBande(tester).gradient! as LinearGradient;
        expect(rendu.begin, AlignmentDirectional.centerStart);
        expect(rendu.end, AlignmentDirectional.centerEnd);
        expect(rendu.colors, _sansGeometrie.colors);
        expect(rendu.stops, _sansGeometrie.stops);
      },
    );

    testWidgets(
      'G3 — RTL : la géométrie appliquée se MIROITE, là où les défauts '
      'Flutter restaient figés',
      (WidgetTester tester) async {
        // Sens LTR.
        await _pump(
          tester,
          const ZDefaultFolderCard(
            title: 'Dossier',
            accentGradient: _specSansGeometrie,
          ),
          theme: _jetonsDirectionnels,
        );
        final LinearGradient ltr =
            _decorationBande(tester).gradient! as LinearGradient;
        expect(ltr.begin.resolve(TextDirection.ltr), Alignment.centerLeft);
        expect(ltr.end.resolve(TextDirection.ltr), Alignment.centerRight);

        // Sens RTL : le MÊME jeton résout à l'opposé — c'est le miroir que le
        // rendu verbatim ne produisait pas.
        await _pump(
          tester,
          const ZDefaultFolderCard(
            title: 'Dossier',
            accentGradient: _specSansGeometrie,
          ),
          theme: _jetonsDirectionnels,
          direction: TextDirection.rtl,
        );
        final LinearGradient rtl =
            _decorationBande(tester).gradient! as LinearGradient;
        expect(rtl.begin.resolve(TextDirection.rtl), Alignment.centerRight);
        expect(rtl.end.resolve(TextDirection.rtl), Alignment.centerLeft);

        // Le symptôme mesuré par l'hôte : un dégradé rendu verbatim gardait
        // `Alignment.centerLeft` dans les DEUX sens.
        expect(
          _sansGeometrie.begin.resolve(TextDirection.rtl),
          Alignment.centerLeft,
        );
      },
    );

    testWidgets(
      'G4 — précédence : une géométrie EXPLICITE de l’hôte n’est pas '
      'écrasée par les jetons',
      (WidgetTester tester) async {
        await _pump(
          tester,
          const ZDefaultFolderCard(
            title: 'Dossier',
            accentGradient: _specAvecGeometrie,
          ),
          theme: _jetonsDirectionnels,
        );

        expect(_decorationBande(tester).gradient, same(_avecGeometrie));
      },
    );
  });

  group('CR-92 — source', () {
    test(
      'G5 — la composition des jetons de géométrie n’existe qu’à UN endroit',
      () {
        final List<String> porteurs = <String>[];
        for (final FileSystemEntity entity
            in Directory('lib').listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          // Commentaires DÉPOUILLÉS : la dartdoc a le droit de NOMMER les
          // jetons (elle documente la règle pour l'appelant) ; c'est le CODE
          // qui ne doit les composer qu'à un seul endroit.
          final String source = strippedText(entity);
          if (source.contains('gradientBegin') ||
              source.contains('gradientEnd')) {
            porteurs.add(entity.path);
          }
        }
        expect(
          porteurs,
          <String>['lib/src/presentation/z_gradient_geometry.dart'],
          reason: 'une seconde composition divergerait de la première — c’est '
              'exactement le défaut corrigé ici',
        );
      },
    );
  });
}
