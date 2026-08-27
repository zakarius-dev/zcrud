// Lot L4 (chantier « composer avancé ») — gardes du CADRE du composer.
//
// Ce que ce fichier MESURE, sur un sujet réellement monté, et TOUJOURS sur les
// nœuds qui PEIGNENT (le `DecoratedBox` et le `ClipRRect` descendants de
// `ZChatComposerSurface`), jamais sur une valeur lue au vol :
//
// * **FRM-I — INERTIE** : aucun jeton posé, aucun paramètre ⇒ le cadre
//   n'introduit AUCUN nœud. L'assertion est ABSOLUE (`findsNothing` +
//   géométrie de l'enfant mesurée en dp), jamais la comparaison de deux arbres
//   qu'une même injection déplacerait ensemble.
// * **FRM-P — PRÉCÉDENCE** : paramètre > jeton > rien, les trois niveaux
//   atteints SÉPARÉMENT, sur la couleur et l'épaisseur RÉELLEMENT peintes.
// * **FRM-R — RAYON UNIQUE** : fond, filet et rognage partagent le rayon —
//   la garde lit les DEUX nœuds et exige l'égalité, de sorte qu'un second
//   rayon introduit quelque part rougisse.
//
// Ancrage : le sujet est piloté par `ZcrudScope(theme:)` et par les paramètres
// publics du widget — exactement ce qu'un hôte détient. Aucun objet interne
// n'est fabriqué pour l'occasion.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_render_harness.dart';

const Color _tokenFill = Color(0xFF0A0B0C);
const Color _paramFill = Color(0xFF102030);
const Color _tokenLine = Color(0xFF445566);
const Color _paramLine = Color(0xFF778899);
const Color _surfaceToken = Color(0xFF010203);

/// L'enfant du cadre — une boîte de taille connue, pour que la géométrie soit
/// mesurable en dp et non par comparaison d'arbres.
const Key _childKey = Key('frame-child');
const Widget _child = SizedBox(key: _childKey, width: 120, height: 40);

Widget _surface({
  ZcrudTheme? theme,
  Color? backgroundColor,
  Color? borderColor,
  ZChatComposerChrome? chrome,
  Clip clipBehavior = Clip.none,
}) {
  final Widget subject = ZChatComposerSurface(
    backgroundColor: backgroundColor,
    borderColor: borderColor,
    chrome: chrome,
    clipBehavior: clipBehavior,
    child: _child,
  );
  return harness(
    theme == null
        ? subject
        : ZcrudScope(theme: theme, child: subject),
  );
}

/// La décoration RÉELLEMENT peinte par le cadre, ou `null` si le cadre n'a
/// posé aucun nœud décoré.
BoxDecoration? _painted(WidgetTester tester) {
  final Finder f = find.descendant(
    of: find.byType(ZChatComposerSurface),
    matching: find.byType(DecoratedBox),
  );
  if (f.evaluate().isEmpty) return null;
  expect(f, findsOneWidget,
      reason: '🔴 le cadre peint DEUX fois : une seconde décoration rendrait '
          'la précédence invérifiable (quelle couleur gagne à l\'écran ?)');
  return tester.widget<DecoratedBox>(f).decoration as BoxDecoration;
}

void main() {
  group('🔴 FRM-I — INERTIE : sans jeton NI paramètre, le cadre ne pose rien',
      () {
    testWidgets('aucun nœud décoré, aucun rognage — et l\'enfant garde sa '
        'géométrie EXACTE', (WidgetTester tester) async {
      await tester.pumpWidget(_surface());

      expect(
        find.descendant(
          of: find.byType(ZChatComposerSurface),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
        reason: '🔴 le cadre a posé une décoration alors qu\'AUCUN fond n\'est '
            'résolu — le socle inventerait une couleur (FR-26) et un hôte '
            'passif verrait son composer changer d\'aspect à la mise à jour.',
      );
      expect(
        find.descendant(
          of: find.byType(ZChatComposerSurface),
          matching: find.byType(ClipRRect),
        ),
        findsNothing,
        reason: '🔴 `Clip.none` par défaut : un rognage posé d\'office est une '
            'couche de composition pour rien.',
      );
      // Géométrie ABSOLUE : la boîte de 120 × 40 est rendue telle quelle, sans
      // le moindre dp de bordure ou de marge ajouté par le cadre.
      expect(tester.getSize(find.byKey(_childKey)), const Size(120, 40));
    });

    testWidgets('un thème SANS les quatre jetons de cadre est aussi inerte '
        'qu\'une absence de thème', (WidgetTester tester) async {
      // Le contre-sujet exact du défaut : l'hôte a un `ZcrudScope`, un thème,
      // et n'a rien réglé sur le cadre. Rien ne doit apparaître.
      await tester.pumpWidget(
        _surface(theme: const ZcrudTheme(radiusM: Radius.circular(7))),
      );
      expect(_painted(tester), isNull,
          reason: '🔴 un thème sans jeton de cadre a fait apparaître un fond '
              'ou un filet : le rendu d\'un hôte passif a changé.');
      expect(tester.getSize(find.byKey(_childKey)), const Size(120, 40));
    });
  });

  group('🔴 FRM-P — PRÉCÉDENCE, mesurée sur ce qui est PEINT', () {
    testWidgets('FOND — niveau 3 « rien » : sans paramètre ni jeton, aucun '
        'fond', (WidgetTester tester) async {
      await tester.pumpWidget(_surface(theme: const ZcrudTheme()));
      expect(_painted(tester), isNull);
    });

    testWidgets('FOND — niveau 2 : le jeton `chatComposerFill` PEINT, et il '
        'passe DEVANT `surfaceColor`', (WidgetTester tester) async {
      await tester.pumpWidget(
        _surface(
          theme: const ZcrudTheme(
            chatComposerFill: _tokenFill,
            surfaceColor: _surfaceToken,
          ),
        ),
      );
      expect(_painted(tester)!.color, _tokenFill,
          reason: '🔴 le rôle PRÉCIS (fond du cadre) doit primer sur le rôle '
              'LARGE (surface de l\'app) : sinon le jeton neuf est inerte '
              'chez tout hôte qui a déjà réglé `surfaceColor`.');
    });

    testWidgets('FOND — le rôle large reste atteignable : `surfaceColor` seul '
        'peint encore (non-régression)', (WidgetTester tester) async {
      await tester.pumpWidget(
        _surface(theme: const ZcrudTheme(surfaceColor: _surfaceToken)),
      );
      expect(_painted(tester)!.color, _surfaceToken,
          reason: '🔴 insérer le jeton précis a coupé le rôle large : un hôte '
              'qui n\'a réglé que `surfaceColor` a perdu son fond.');
    });

    testWidgets('FOND — niveau 1 : le PARAMÈTRE prime sur le jeton', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _surface(
          theme: const ZcrudTheme(chatComposerFill: _tokenFill),
          backgroundColor: _paramFill,
        ),
      );
      expect(_painted(tester)!.color, _paramFill,
          reason: '🔴 le jeton a écrasé le paramètre : l\'ordre de la chaîne '
              'est inversé.');
    });

    testWidgets('FILET — niveau 3 « rien » : un fond SANS teinte de filet ne '
        'dessine aucun côté', (WidgetTester tester) async {
      await tester.pumpWidget(
        _surface(theme: const ZcrudTheme(chatComposerFill: _tokenFill)),
      );
      expect(_painted(tester)!.border, isNull,
          reason: '🔴 le socle a inventé un contour que personne n\'a '
              'déclaré.');
    });

    testWidgets('FILET — niveau 2 : le jeton `chatComposerBorderColor` PEINT, '
        'à l\'épaisseur de référence', (WidgetTester tester) async {
      await tester.pumpWidget(
        _surface(theme: const ZcrudTheme(chatComposerBorderColor: _tokenLine)),
      );
      final Border border = _painted(tester)!.border! as Border;
      expect(border.top.color, _tokenLine,
          reason: '🔴 le jeton de filet est INERTE — c\'est exactement le '
              'défaut que la garde d\'inertie de `zcrud_core` signale.');
      expect(border.top.width, 1,
          reason: '🔴 l\'épaisseur de référence (1) n\'est plus le dernier '
              'ressort.');
    });

    testWidgets('FILET — niveau 1 : le PARAMÈTRE prime sur le jeton', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _surface(
          theme: const ZcrudTheme(chatComposerBorderColor: _tokenLine),
          borderColor: _paramLine,
        ),
      );
      expect((_painted(tester)!.border! as Border).top.color, _paramLine);
    });

    testWidgets('ÉPAISSEUR — les trois niveaux, sur la largeur PEINTE', (
      WidgetTester tester,
    ) async {
      // Niveau 3 — référence (1) : déjà mesuré ci-dessus.
      // Niveau 2 — le jeton `chatComposerBorderWidth`.
      await tester.pumpWidget(
        _surface(
          theme: const ZcrudTheme(
            chatComposerBorderColor: _tokenLine,
            chatComposerBorderWidth: 3,
          ),
        ),
      );
      expect((_painted(tester)!.border! as Border).top.width, 3,
          reason: '🔴 le jeton d\'épaisseur est INERTE.');

      // Niveau 1 — le paramètre de chrome.
      await tester.pumpWidget(
        _surface(
          theme: const ZcrudTheme(
            chatComposerBorderColor: _tokenLine,
            chatComposerBorderWidth: 3,
          ),
          chrome: const ZChatComposerChrome(borderWidth: 5),
        ),
      );
      expect((_painted(tester)!.border! as Border).top.width, 5,
          reason: '🔴 le jeton a écrasé le paramètre d\'épaisseur.');
    });

    testWidgets('ÉPAISSEUR — un jeton nul ou négatif ne peint AUCUN côté '
        '(AD-10)', (WidgetTester tester) async {
      await tester.pumpWidget(
        _surface(
          theme: const ZcrudTheme(
            chatComposerFill: _tokenFill,
            chatComposerBorderColor: _tokenLine,
            chatComposerBorderWidth: -4,
          ),
        ),
      );
      expect(_painted(tester)!.border, isNull,
          reason: '🔴 une épaisseur négative a produit un côté : la dartdoc du '
              'jeton promet « pas de filet », pas un trait aberrant.');
      expect(_painted(tester)!.color, _tokenFill,
          reason: '🔴 le fond, lui, reste peint — l\'écrêtage de l\'épaisseur '
              'n\'annule pas le cadre.');
    });
  });

  group('🔴 FRM-R — RAYON UNIQUE : fond, filet et rognage ne divergent pas',
      () {
    testWidgets('le jeton `chatComposerRadius` gouverne LES DEUX nœuds à la '
        'fois', (WidgetTester tester) async {
      const Radius radius = Radius.circular(19);
      await tester.pumpWidget(
        _surface(
          theme: const ZcrudTheme(
            chatComposerRadius: radius,
            chatComposerFill: _tokenFill,
            chatComposerBorderColor: _tokenLine,
            // Le rôle large est présent ET différent : s'il gagnait, les deux
            // nœuds seraient encore ÉGAUX entre eux — l'égalité seule ne
            // suffirait donc pas à prouver la précédence.
            radiusM: Radius.circular(4),
          ),
          clipBehavior: Clip.antiAlias,
        ),
      );
      final BoxDecoration decoration = _painted(tester)!;
      final ClipRRect clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(ZChatComposerSurface),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(decoration.borderRadius, const BorderRadius.all(radius),
          reason: '🔴 le jeton `chatComposerRadius` est INERTE sur le fond, ou '
              'ne passe pas devant `radiusM`.');
      expect(clip.borderRadius, const BorderRadius.all(radius),
          reason: '🔴 le rognage a pris un AUTRE rayon que le fond : deux '
              'rayons à accorder, c\'est exactement ce que le contrat '
              'interdit.');
      expect(clip.borderRadius, decoration.borderRadius,
          reason: '🔴 fond et rognage ont DIVERGÉ.');
    });

    testWidgets('le paramètre de chrome gouverne LES DEUX nœuds à la fois', (
      WidgetTester tester,
    ) async {
      const Radius radius = Radius.circular(23);
      await tester.pumpWidget(
        _surface(
          theme: const ZcrudTheme(
            chatComposerRadius: Radius.circular(19),
            chatComposerFill: _tokenFill,
          ),
          chrome: const ZChatComposerChrome(containerRadius: radius),
          clipBehavior: Clip.antiAlias,
        ),
      );
      final BoxDecoration decoration = _painted(tester)!;
      final ClipRRect clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(ZChatComposerSurface),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(decoration.borderRadius, const BorderRadius.all(radius));
      expect(clip.borderRadius, const BorderRadius.all(radius));
    });

    testWidgets('le rôle large `radiusM` reste atteignable (non-régression)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _surface(
          theme: const ZcrudTheme(
            radiusM: Radius.circular(4),
            chatComposerFill: _tokenFill,
          ),
        ),
      );
      expect(
        _painted(tester)!.borderRadius,
        const BorderRadius.all(Radius.circular(4)),
        reason: '🔴 insérer `chatComposerRadius` a coupé `radiusM` : un hôte '
            'qui n\'a réglé que le rayon générique a perdu son rayon.',
      );
    });

    testWidgets('le rognage SEUL (sans fond ni filet) porte déjà le rayon '
        'unique', (WidgetTester tester) async {
      const Radius radius = Radius.circular(19);
      await tester.pumpWidget(
        _surface(
          theme: const ZcrudTheme(chatComposerRadius: radius),
          clipBehavior: Clip.antiAlias,
        ),
      );
      expect(_painted(tester), isNull,
          reason: '🔴 un rognage demandé ne doit pas faire apparaître un fond.');
      final ClipRRect clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(ZChatComposerSurface),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, const BorderRadius.all(radius));
    });
  });
}
