/// LE RANG 3 — la bande de propositions, dans le cadre.
///
/// Le socle recevait les propositions sans jamais les rendre. Ce fichier
/// mesure le chaînon manquant : un RANG, à sa place, alimenté par l'agrégat
/// du contrôleur — et rien du tout chez l'hôte qui ne l'a pas demandé.
///
/// * **SGB-I** — INERTIE : sans geste déclaré et sans store de brouillon, le
///   cadre est celui d'avant. Mesuré en ABSOLU (nombre et nature des enfants
///   du cadre), jamais par comparaison de deux arbres.
/// * **SGB-R** — RANG : la bande est le rang 3 — après les annonces (0-2),
///   AVANT l'ancre, et DANS le cadre. Mesuré par la position dans la `Column`
///   des rangs ET par des rectangles.
/// * **SGB-W** — CÂBLAGE : la bande montée par l'assemblé lit l'agrégat DU
///   contrôleur, pas une autre tranche.
/// * **SGB-V** — VIDE : une livraison vide ne prend AUCUNE hauteur (AD-4).
/// * **SGB-T** — TOUCHER : chaque proposition est un nœud de BOUTON distinct,
///   étiqueté par son contenu, cible ≥ 48 dp, et son tap rend LA proposition.
/// * **SGB-G** — GRANULARITÉ : une proposition qui arrive ne reconstruit pas
///   le champ, ne lui prend ni le focus, ni le texte, ni le curseur.
@TestOn('vm')
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

const Color _cursor = Color(0xFF123456);

/// LE CADRE — la marge que `ZChatComposer` pose autour de ses rangs.
Finder _frameFinder() => find
    .descendant(of: find.byType(ZChatComposer), matching: find.byType(Padding))
    .first;

Finder _columnFinder() =>
    find.descendant(of: _frameFinder(), matching: find.byType(Column)).first;

Column _column(WidgetTester tester) =>
    tester.widget<Column>(_columnFinder());

/// L'index du premier enfant du cadre satisfaisant [test], ou `-1`.
int _rankOf(WidgetTester tester, bool Function(Widget w) test) {
  final List<Widget> children = _column(tester).children;
  for (int i = 0; i < children.length; i++) {
    if (test(children[i])) return i;
  }
  return -1;
}

List<ZChatSuggestion> _three() => const <ZChatSuggestion>[
  ZChatSuggestion(id: 's1', content: 'Et ensuite ?'),
  ZChatSuggestion(id: 's2', content: 'Résume'),
  ZChatSuggestion(id: 's3', content: 'Donne un exemple'),
];

/// Le nœud sémantique de BOUTON portant [label], ou `null`.
SemanticsNode? _button(WidgetTester tester, String label) =>
    findSemantics(tester, (SemanticsNode n) =>
        n.label == label && n.flagsCollection.isButton);

void main() {
  group('🔴 SGB-I — INERTIE de l\'hôte passif', () {
    testWidgets(
      'sans geste de proposition ni store de brouillon : TROIS enfants dans '
      'le cadre, et aucun nœud de rang 0 ou 3',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: _cursor,
            ),
          ),
        );

        // ABSOLU : le bandeau d'édition (1), l'ancre (6), la bande
        // d'accessoires (7) — exactement l'arbre d'avant ce lot.
        expect(
          _column(tester).children,
          hasLength(3),
          reason: '🔴 un rang s\'est intercalé chez un hôte qui n\'a demandé '
              'ni proposition ni brouillon persistant (AD-4)',
        );
        expect(
          find.byType(ZChatComposerSuggestionsBand),
          findsNothing,
          reason: '🔴 le rang 3 est monté sans geste déclaré : la bande '
              'afficherait des propositions qui ne font rien',
        );
        expect(
          find.byType(ZChatComposerDraftNotice),
          findsNothing,
          reason: '🔴 le rang 0 est monté sans store : un indicateur qui ne '
              'peut RIEN annoncer occupe le cadre',
        );
      },
    );
  });

  group('SGB-R / SGB-W — RANG et CÂBLAGE', () {
    testWidgets(
      'la bande est APRÈS le bandeau d\'édition, AVANT l\'ancre, DANS le '
      'cadre — et lit l\'agrégat du contrôleur',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: _cursor,
              onSelectSuggestion: (ZChatSuggestion _) {},
            ),
          ),
        );

        final int banner = _rankOf(
          tester,
          (Widget w) => w is ZChatComposerEditingBanner,
        );
        final int band = _rankOf(
          tester,
          (Widget w) => w is ZChatComposerSuggestionsBand,
        );
        final int anchor = _rankOf(tester, (Widget w) => w is Row);

        expect(band, greaterThan(banner),
            reason: '🔴 la bande est passée DEVANT une annonce : le rang 3 '
                'n\'est plus après les rangs 0-2');
        expect(band, lessThan(anchor),
            reason: '🔴 la bande est passée SOUS l\'ancre : elle ne pousse '
                'plus le champ, elle le suit');

        // Le CÂBLAGE : la tranche lue est celle du contrôleur, pas une
        // autre — sans quoi le rang serait au bon endroit et muet.
        final ZChatComposerSuggestionsBand mounted = tester
            .widget<ZChatComposerSuggestionsBand>(
              find.byType(ZChatComposerSuggestionsBand),
            );
        expect(
          identical(mounted.suggestions, rig.controller.suggestions),
          isTrue,
          reason: '🔴 la bande n\'écoute pas l\'agrégat du contrôleur : elle '
              'ne verra jamais une proposition arriver',
        );

        // Et DANS le cadre, en géométrie rendue.
        final Rect frame = tester.getRect(_frameFinder());
        final Rect bandRect = tester.getRect(
          find.byType(ZChatComposerSuggestionsBand),
        );
        expect(bandRect.top, greaterThanOrEqualTo(frame.top - 0.5));
        expect(bandRect.bottom, lessThanOrEqualTo(frame.bottom + 0.5));
      },
    );
  });

  group('SGB-V — le VIDE ne prend aucune hauteur', () {
    testWidgets('liste vide ⇒ la bande mesure zéro', (
      WidgetTester tester,
    ) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);

      await tester.pumpWidget(
        harness(
          ZDefaultChatComposer(
            controller: rig.controller,
            settings: ZChatSettingsController(),
            cursorColor: _cursor,
            onSelectSuggestion: (ZChatSuggestion _) {},
          ),
        ),
      );

      // Le sujet est la HAUTEUR : c'est elle qu'un rang prend au champ. La
      // largeur d'un `SizedBox.shrink` dans une `Column` vaut celle du
      // cadre — la mesurer ferait une garde ancrée sur la mauvaise
      // propriété.
      expect(
        tester.getSize(find.byType(ZChatComposerSuggestionsBand)).height,
        0,
        reason: '🔴 une bande vide vole sa hauteur au champ de saisie (AD-4)',
      );
    });
  });

  group('SGB-T — TOUCHER : un bouton par proposition', () {
    testWidgets(
      'chaque proposition est un nœud de BOUTON étiqueté par son contenu, '
      '≥ 48 dp, et son tap rend LA proposition',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final ValueNotifier<List<ZChatSuggestion>> slice =
            ValueNotifier<List<ZChatSuggestion>>(_three());
        addTearDown(slice.dispose);
        final List<String> tapped = <String>[];

        await tester.pumpWidget(
          harness(
            ZChatComposerSuggestionsBand(
              suggestions: slice,
              onSelect: (ZChatSuggestion s) => tapped.add(s.id),
            ),
          ),
        );

        for (final ZChatSuggestion s in _three()) {
          expect(
            _button(tester, s.content),
            isNotNull,
            reason: '🔴 « ${s.content} » n\'est pas un nœud de BOUTON : '
                'l\'étiquette a fusionné dans son parent et la proposition '
                'est inatteignable au lecteur d\'écran (AD-13)',
          );
        }

        // La cible est le nœud qui REÇOIT le tap, pas le `Text` qu'il
        // contient : mesurer le libellé rendrait 20 dp et laisserait passer
        // n'importe quelle cible trop petite.
        final Size target = tester.getSize(
          find
              .ancestor(
                of: find.text('Résume'),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        expect(target.height, greaterThanOrEqualTo(48 - 0.5),
            reason: '🔴 cible sous le plancher tactile de 48 dp (AD-13)');
        expect(target.width, greaterThanOrEqualTo(48 - 0.5),
            reason: '🔴 cible sous le plancher tactile de 48 dp (AD-13)');

        await tester.tap(find.text('Résume'));
        await tester.pump();
        expect(
          tapped,
          <String>['s2'],
          reason: '🔴 le tap ne rend pas LA proposition touchée : le geste de '
              'l\'hôte est câblé sur la mauvaise donnée',
        );
        handle.dispose();
      },
    );
  });

  group('🔴 SGB-G — GRANULARITÉ', () {
    testWidgets(
      'une proposition qui arrive ne reconstruit pas le champ et ne lui prend '
      'ni focus, ni texte, ni curseur',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        final ValueNotifier<List<ZChatSuggestion>> slice =
            ValueNotifier<List<ZChatSuggestion>>(
              const <ZChatSuggestion>[],
            );
        addTearDown(slice.dispose);
        final FocusNode node = FocusNode();
        addTearDown(node.dispose);

        await tester.pumpWidget(
          harness(
            ZChatComposer(
              controller: rig.controller,
              cursorColor: _cursor,
              focusNode: node,
              suggestions:
                  (BuildContext context, ZChatComposerSlot slot) =>
                      ZChatComposerSuggestionsBand(
                        suggestions: slice,
                        onSelect: (ZChatSuggestion _) {},
                      ),
            ),
          ),
        );

        await tester.enterText(find.byType(EditableText), 'ma question');
        await tester.pump();
        node.requestFocus();
        await tester.pump();

        final Element before = tester.element(find.byType(EditableText));
        final TextSelection selection =
            rig.controller.composer.selection;
        expect(node.hasFocus, isTrue);

        slice.value = _three();
        await tester.pump();

        expect(
          identical(tester.element(find.byType(EditableText)), before),
          isTrue,
          reason: '🔴 le champ a été RECONSTRUIT par l\'arrivée d\'une '
              'proposition : le bug historique que zcrud existe pour '
              'corriger (AD-2)',
        );
        expect(node.hasFocus, isTrue,
            reason: '🔴 le focus a sauté quand une proposition est arrivée');
        expect(rig.controller.composer.text, 'ma question',
            reason: '🔴 le texte en cours a été perdu');
        expect(rig.controller.composer.selection, selection,
            reason: '🔴 le curseur a bougé');
        expect(find.byType(ZChatComposerSuggestionsBand), findsOneWidget);
        // 🟢 LE VERT TÉMOIN : sans lui, une bande INERTE rendrait la garde
        // ci-dessus verte pour rien — le champ ne serait pas reconstruit
        // parce que rien ne se serait passé.
        expect(find.text('Résume'), findsOneWidget,
            reason: '🔴 la bande n\'a PAS réagi : la garde de granularité '
                'serait verte pour rien');

        // 🔬 CONTRE-PREUVE : le matcher d'identité SAIT distinguer. Remonté
        // sous une autre clé, le champ change d'élément — si ce `isFalse`
        // rougissait, `identical(...)` serait vrai en toute circonstance et
        // la garde ne mesurerait rien.
        await tester.pumpWidget(
          harness(
            ZChatComposer(
              key: const ValueKey<String>('autre'),
              controller: rig.controller,
              cursorColor: _cursor,
            ),
          ),
        );
        expect(
          identical(tester.element(find.byType(EditableText)), before),
          isFalse,
          reason: '🔴 `identical` rend vrai même sur un élément neuf : la '
              'mesure de granularité ne discrimine rien',
        );
      },
    );
  });
}
