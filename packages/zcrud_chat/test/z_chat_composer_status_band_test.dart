// Lot L4 (chantier « composer avancé ») — gardes de la BANDE D'ÉTAT (rang 0).
//
// Ce que ce fichier MESURE, sur un composer réellement monté :
//
// * **STB-A — ABSENTE** : sans annonce, la bande n'occupe RIEN. L'assertion est
//   ABSOLUE (taille rendue nulle, aucun texte, aucune marge), jamais la
//   comparaison de deux arbres.
// * **STB-R — RANG 0** : quand elle apparaît, elle se pose AU-DESSUS de toutes
//   les autres rangées, mesuré en dp sur les positions rendues.
// * **STB-M — le message** : clé résolue par le registre de l'hôte, ou texte
//   d'hôte rendu tel quel — jamais une concaténation.
// * **STB-S — la gravité** : glyphe et teinte par palier, et AUCUNE couleur
//   quand l'hôte n'en déclare pas (FR-26).
// * **STB-Ac — l'action** : rendue, cible ≥ 48 dp, geste de l'HÔTE appelé.
// * **STB-D — elle ne DÉCIDE rien** : grep NÉGATIF sur la source — aucune
//   politique de quota, aucune sonde réseau dans le socle.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

const Color _cursor = Color(0xFF123456);
const Color _accent = Color(0xFF884422);
const Key _glyphKey = Key('status-glyph');
const Key _counterKey = Key('rank-8');
const Key _suggestionsKey = Key('rank-3');

/// Le composer réel, avec la bande montée dans son créneau `status` — le
/// câblage exact qu'un hôte écrit.
Widget _mount(
  ZChatController controller,
  ValueListenable<ZChatComposerStatus?> status, {
  Map<String, String>? labels,
  Map<ZChatComposerStatusSeverity, Widget>? glyphs,
  Map<ZChatComposerStatusSeverity, Color>? accents,
  bool withOtherRanks = false,
}) => harness(
  labels: labels,
  ZChatComposer(
    controller: controller,
    cursorColor: _cursor,
    status: (BuildContext context, ZChatComposerSlot slot) =>
        ZChatComposerStatusBand(
          status: status,
          glyphs: glyphs,
          accents: accents,
        ),
    suggestions: withOtherRanks
        ? (BuildContext context, ZChatComposerSlot slot) =>
              const SizedBox(key: _suggestionsKey, height: 12)
        : null,
    counter: withOtherRanks
        ? (BuildContext context, ZChatComposerSlot slot) =>
              const SizedBox(key: _counterKey, height: 12)
        : null,
  ),
);

void main() {
  group('🔴 STB-A — ABSENTE quand l\'hôte n\'annonce rien', () {
    testWidgets('taille RENDUE nulle, aucun texte, aucune marge', (
      WidgetTester tester,
    ) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<ZChatComposerStatus?> status =
          ValueNotifier<ZChatComposerStatus?>(null);
      addTearDown(status.dispose);
      await tester.pumpWidget(_mount(c.controller, status));

      expect(find.byType(ZChatComposerStatusBand), findsOneWidget,
          reason: '🔴 GARDE VACUELLE : la bande n\'est pas montée.');
      // La largeur suit l'étirement de la `Column` du composer ; c'est la
      // HAUTEUR qui dit si la bande vole de la place.
      expect(tester.getSize(find.byType(ZChatComposerStatusBand)).height, 0,
          reason: '🔴 une bande sans annonce VOLE de la hauteur au champ de '
              'saisie — c\'est exactement le créneau inerte que l\'invariant '
              'AD-4 interdit.');
      expect(
        find.descendant(
          of: find.byType(ZChatComposerStatusBand),
          matching: find.byType(Padding),
        ),
        findsNothing,
        reason: '🔴 la marge de la bande est posée alors qu\'il n\'y a rien à '
            'annoncer.',
      );
      expect(
        find.descendant(
          of: find.byType(ZChatComposerStatusBand),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });

    testWidgets('elle DISPARAÎT quand l\'annonce est retirée', (
      WidgetTester tester,
    ) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<ZChatComposerStatus?> status =
          ValueNotifier<ZChatComposerStatus?>(
            const ZChatComposerStatus(message: 'Hors ligne'),
          );
      addTearDown(status.dispose);
      await tester.pumpWidget(_mount(c.controller, status));
      expect(find.text('Hors ligne'), findsOneWidget);
      final double height = tester
          .getSize(find.byType(ZChatComposerStatusBand))
          .height;
      expect(height, greaterThan(0),
          reason: '🔴 GARDE VACUELLE : la bande n\'a jamais rien rendu.');

      status.value = null;
      await tester.pump();
      expect(find.text('Hors ligne'), findsNothing);
      expect(tester.getSize(find.byType(ZChatComposerStatusBand)).height, 0,
          reason: '🔴 la bande garde sa place après le retrait de l\'annonce.');
    });
  });

  group('🔴 STB-R — RANG 0 : au-dessus de tout le reste', () {
    testWidgets('la bande précède les propositions, l\'ancre et les '
        'accessoires', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<ZChatComposerStatus?> status =
          ValueNotifier<ZChatComposerStatus?>(
            const ZChatComposerStatus(message: 'Quota bientôt épuisé'),
          );
      addTearDown(status.dispose);
      await tester.pumpWidget(
        _mount(c.controller, status, withOtherRanks: true),
      );

      final double band = tester.getTopLeft(find.text('Quota bientôt épuisé')).dy;
      final double suggestions = tester.getTopLeft(
        find.byKey(_suggestionsKey),
      ).dy;
      final double field = tester.getTopLeft(find.byType(EditableText)).dy;
      final double counter = tester.getTopLeft(find.byKey(_counterKey)).dy;

      expect(band, lessThan(suggestions),
          reason: '🔴 une ANNONCE poussée sous une PROPOSITION : elle sortira '
              'du cadre dès que la proposition grandira.');
      expect(suggestions, lessThan(field),
          reason: '🔴 GARDE VACUELLE : l\'ordre mesuré n\'est pas celui des '
              'rangs.');
      expect(field, lessThan(counter));
    });
  });

  group('🔴 STB-M — le message, sans concaténation', () {
    testWidgets('par CLÉ : le registre de l\'hôte est consulté', (
      WidgetTester tester,
    ) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<ZChatComposerStatus?> status =
          ValueNotifier<ZChatComposerStatus?>(
            const ZChatComposerStatus.byKey(messageKey: 'app.quotaLow'),
          );
      addTearDown(status.dispose);
      await tester.pumpWidget(
        _mount(
          c.controller,
          status,
          labels: <String, String>{'app.quotaLow': 'Il vous reste 3 requêtes'},
        ),
      );
      expect(find.text('Il vous reste 3 requêtes'), findsOneWidget,
          reason: '🔴 la clé n\'est pas résolue : l\'utilisateur verrait le '
              'discriminant machine `app.quotaLow`.');
      expect(find.text('app.quotaLow'), findsNothing);
    });

    testWidgets('par TEXTE : le message d\'hôte est rendu tel quel', (
      WidgetTester tester,
    ) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<ZChatComposerStatus?> status =
          ValueNotifier<ZChatComposerStatus?>(
            const ZChatComposerStatus(message: 'Connexion perdue'),
          );
      addTearDown(status.dispose);
      await tester.pumpWidget(_mount(c.controller, status));
      expect(find.text('Connexion perdue'), findsOneWidget);
    });

    testWidgets('l\'annonce est une région LIVE — elle est dite, pas '
        'seulement affichée', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<ZChatComposerStatus?> status =
          ValueNotifier<ZChatComposerStatus?>(
            const ZChatComposerStatus(message: 'Connexion perdue'),
          );
      addTearDown(status.dispose);
      await tester.pumpWidget(_mount(c.controller, status));
      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsLabel('Connexion perdue'),
      );
      expect(
        node.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
        reason: '🔴 sans région live, un lecteur d\'écran ne dira JAMAIS la '
            'perte de connexion : la bande serait un canal purement visuel '
            '(invariant AD-13).',
      );
      // Le handle se libère DANS le corps du test : le harnais vérifie leur
      // disposition avant les `tearDown`.
      handle.dispose();
    });
  });

  group('🔴 STB-S — la gravité : glyphe et teinte, jamais inventés', () {
    testWidgets('le glyphe rendu est celui du PALIER courant', (
      WidgetTester tester,
    ) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<ZChatComposerStatus?> status =
          ValueNotifier<ZChatComposerStatus?>(
            const ZChatComposerStatus(
              message: 'Attention',
              severity: ZChatComposerStatusSeverity.warning,
            ),
          );
      addTearDown(status.dispose);
      await tester.pumpWidget(
        _mount(
          c.controller,
          status,
          glyphs: const <ZChatComposerStatusSeverity, Widget>{
            ZChatComposerStatusSeverity.warning: SizedBox(
              key: _glyphKey,
              width: 16,
              height: 16,
            ),
          },
        ),
      );
      expect(find.byKey(_glyphKey), findsOneWidget);

      // Le palier CHANGE : le glyphe de l'ancien palier ne survit pas.
      status.value = const ZChatComposerStatus(
        message: 'Info',
        severity: ZChatComposerStatusSeverity.info,
      );
      await tester.pump();
      expect(find.byKey(_glyphKey), findsNothing,
          reason: '🔴 le glyphe ne suit pas la gravité : un avertissement et '
              'une information seraient rendus à l\'identique.');
    });

    testWidgets('SANS accent déclaré, AUCUNE couleur n\'est imposée (FR-26)', (
      WidgetTester tester,
    ) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<ZChatComposerStatus?> status =
          ValueNotifier<ZChatComposerStatus?>(
            const ZChatComposerStatus(
              message: 'Échec',
              severity: ZChatComposerStatusSeverity.error,
            ),
          );
      addTearDown(status.dispose);
      await tester.pumpWidget(_mount(c.controller, status));
      expect(
        find.descendant(
          of: find.byType(ZChatComposerStatusBand),
          matching: find.byType(ZForegroundOverride),
        ),
        findsNothing,
        reason: '🔴 le socle a imposé une couleur que personne n\'a déclarée : '
            'un « rouge d\'erreur » inventé traverserait tous les thèmes.',
      );
    });

    testWidgets('AVEC accent déclaré, la teinte de l\'HÔTE est imposée au '
        'premier plan', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<ZChatComposerStatus?> status =
          ValueNotifier<ZChatComposerStatus?>(
            const ZChatComposerStatus(
              message: 'Échec',
              severity: ZChatComposerStatusSeverity.error,
            ),
          );
      addTearDown(status.dispose);
      await tester.pumpWidget(
        _mount(
          c.controller,
          status,
          accents: const <ZChatComposerStatusSeverity, Color>{
            ZChatComposerStatusSeverity.error: _accent,
          },
        ),
      );
      final ZForegroundOverride override = tester.widget<ZForegroundOverride>(
        find.descendant(
          of: find.byType(ZChatComposerStatusBand),
          matching: find.byType(ZForegroundOverride),
        ),
      );
      expect(override.color, _accent,
          reason: '🔴 la teinte peinte n\'est pas celle que l\'hôte a '
              'déclarée pour ce palier.');

      // Le palier sans accent déclaré retombe sur AUCUNE teinte — clé par
      // clé, jamais en bloc.
      status.value = const ZChatComposerStatus(
        message: 'Info',
        severity: ZChatComposerStatusSeverity.info,
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(ZChatComposerStatusBand),
          matching: find.byType(ZForegroundOverride),
        ),
        findsNothing,
        reason: '🔴 la teinte d\'un palier a débordé sur un autre.',
      );
    });
  });

  group('🔴 STB-Ac — l\'action : le geste appartient à l\'HÔTE', () {
    testWidgets('rendue, cible ≥ 48 dp, et le tap appelle le geste d\'hôte', (
      WidgetTester tester,
    ) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      int taps = 0;
      final ValueNotifier<ZChatComposerStatus?> status =
          ValueNotifier<ZChatComposerStatus?>(
            ZChatComposerStatus(
              message: 'Échec de la génération',
              severity: ZChatComposerStatusSeverity.error,
              action: ZChatComposerPickerAction(
                label: 'Réessayer',
                onTap: () => taps++,
              ),
            ),
          );
      addTearDown(status.dispose);
      await tester.pumpWidget(_mount(c.controller, status));

      final Finder action = find.bySemanticsLabel('Réessayer');
      expect(action, findsOneWidget);
      final Size size = tester.getSize(
        find.descendant(of: action, matching: find.byType(ConstrainedBox)).first,
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      await tester.tap(action);
      expect(taps, 1,
          reason: '🔴 le geste de l\'hôte n\'est pas appelé : la bande '
              'offrirait une affordance inerte.');
    });

    testWidgets('sans action, AUCUNE affordance n\'est posée', (
      WidgetTester tester,
    ) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<ZChatComposerStatus?> status =
          ValueNotifier<ZChatComposerStatus?>(
            const ZChatComposerStatus(message: 'Hors ligne'),
          );
      addTearDown(status.dispose);
      await tester.pumpWidget(_mount(c.controller, status));
      expect(
        find.descendant(
          of: find.byType(ZChatComposerStatusBand),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
        reason: '🔴 une cible tactile sans geste est une affordance qui ment '
            '(invariant AD-4).',
      );
    });
  });

  group('🔴 STB-D — la bande REND, elle ne DÉCIDE pas', () {
    test('grep NÉGATIF : aucune politique de quota ni sonde réseau dans la '
        'source de la bande', () {
      final File source = File(
        'lib/src/presentation/view/z_chat_composer_band.dart',
      );
      expect(source.existsSync(), isTrue,
          reason: '🔴 GARDE VACUELLE : le fichier lu n\'existe pas.');
      final String whole = source.readAsStringSync();
      // 🔴 Le corps de la BANDE, pas le fichier entier : d'autres pièces du
      // même fichier lisent légitimement leurs propres tranches. Une garde
      // qui lirait tout le fichier mesurerait le mauvais sujet.
      final int start = whole.indexOf('class ZChatComposerStatusBand');
      expect(start, greaterThanOrEqualTo(0),
          reason: '🔴 GARDE VACUELLE : ce n\'est pas le bon fichier.');
      final int end = whole.indexOf('\nclass ', start + 1);
      expect(end, greaterThan(start),
          reason: '🔴 GARDE VACUELLE : la fin de la classe est introuvable.');
      final String body = whole.substring(start, end);
      expect(body, contains('ValueListenableBuilder<ZChatComposerStatus?>'),
          reason: '🔴 GARDE VACUELLE : le corps découpé n\'est pas celui de '
              'la bande.');
      for (final String forbidden in <String>[
        'ZChatQuotaSnapshot',
        'remaining',
        'Connectivity',
        'lastFailure',
      ]) {
        expect(body.contains(forbidden), isFalse,
            reason: '🔴 le socle s\'est mis à LIRE la donnée d\'état lui-même '
                '($forbidden) : bloquer un envoi, proposer un achat ou '
                'dégrader un modèle sont des décisions de l\'hôte. La bande '
                'rend ce qu\'on lui donne.');
      }
    });
  });
}
