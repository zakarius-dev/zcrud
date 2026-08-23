/// Gardes de la feuille d'outils Material (lot C).
///
/// Ce que chacune défend :
/// * MT-1 — une entrée désactivée est **rendue, grisée, avec sa raison**. Le
///   legacy la masquait ; masquer pose une question sans réponse.
/// * MT-2 — la bande et la feuille affichent **le même nombre**.
/// * MT-3 — AD-13 : toute cible tactile est ≥ 48 dp en géométrie RENDUE.
/// * MT-4/MT-5 — une nature inconnue et un tap refusé ne lèvent jamais.
/// * MT-6 — AD-2 : régler un outil ne reconstruit pas les autres tuiles.
/// * MT-7 — le cycle passe par `advance` : il BOUCLE.
/// * MT-8 — un séparateur ENTRE deux sections, sans index magique.
/// * MT-9/MT-10 — le catalogue filtrable et sa puce « tout ».
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_material/zcrud_chat_material.dart';

const String kReasonWeb = 'reason.web';
const String kReasonUnavailable = 'reason.unavailable';
const String kReasonWebText = 'Coupé par la recherche web';
const String kReasonUnavailableText = 'Non indexé';

ZChatToolCatalog _fixture() => ZChatToolCatalog(
      sections: <ZChatToolSection>[
        const ZChatToolSection(key: 'gen', label: 'Génération'),
        const ZChatToolSection(key: 'doc', label: 'Documents'),
        const ZChatToolSection(key: 'act', label: 'Actions'),
      ],
      entries: <ZChatToolEntry>[
        ZChatToolEntry(
          key: 'web',
          sectionKey: 'gen',
          label: 'Recherche web',
          state: const ZChatToggleState(),
          stateLabels: const <String, String>{
            'on': 'Activée',
            'off': 'Désactivée',
          },
        ),
        ZChatToolEntry(
          key: 'summary',
          sectionKey: 'gen',
          label: 'Résumé',
          state: const ZChatToggleState(),
          disabledWhen: <ZChatToolRule>[
            ZChatToolRule(
              condition: ZChatToolCondition(activeKeys: const <String>['web']),
              reasonToken: kReasonWeb,
            ),
          ],
        ),
        ZChatToolEntry(
          key: 'think',
          sectionKey: 'gen',
          label: 'Réflexion',
          state: ZChatCycleState(stepCount: 3),
          stateLabels: const <String, String>{
            'step.0': 'Aucune',
            'step.1': 'Courte',
            'step.2': 'Longue',
          },
        ),
        ZChatToolEntry(
          key: 'style',
          sectionKey: 'gen',
          label: 'Ton',
          state: ZChatChoiceState(optionKeys: const <String>['a', 'b']),
          stateLabels: const <String, String>{'a': 'Neutre', 'b': 'Direct'},
        ),
        ZChatToolEntry(
          key: 'depth',
          sectionKey: 'gen',
          label: 'Profondeur',
          state: ZChatScaleState(
            min: 0,
            max: 1,
            marks: const <double>[0, 0.5, 1],
          ),
          stateLabels: const <String, String>{
            'mark.0': 'Basse',
            'mark.1': 'Moyenne',
            'mark.2': 'Haute',
          },
        ),
        ZChatToolEntry(
          key: 'corpus',
          sectionKey: 'doc',
          label: 'Portée',
          state: ZChatCatalogState(
            itemKeys: const <String>['x', 'y'],
            unavailableKeys: const <String>['y'],
            unavailableReasonToken: kReasonUnavailable,
          ),
          stateLabels: const <String, String>{
            'x': 'Dossier X',
            'y': 'Dossier Y',
          },
        ),
        ZChatToolEntry(
          key: 'host',
          sectionKey: 'doc',
          label: 'Nature d\'hôte',
          state: const ZChatCustomToolState(kind: 'hostThing'),
        ),
        ZChatToolEntry(
          key: 'clear',
          sectionKey: 'act',
          label: 'Vider',
          state: const ZChatCommandState(),
        ),
      ],
    );

const ZChatMaterialToolLabels kLabels = ZChatMaterialToolLabels(
  title: 'Outils',
  reset: 'Réinitialiser',
  close: 'Fermer',
  search: 'Rechercher',
  all: 'Tous',
  active: 'Actifs',
  reasonOf: _reason,
  iconOf: _icon,
);

String? _reason(String token) => switch (token) {
      kReasonWeb => kReasonWebText,
      kReasonUnavailable => kReasonUnavailableText,
      _ => null,
    };

Widget? _icon(String key) => const Icon(Icons.tune);

/// Le titre d'une TUILE — jamais la puce du même nom dans l'en-tête des
/// actifs : les deux surfaces portent le même libellé, et les confondre
/// rendrait la garde ambiguë.
Finder _tile(String text) =>
    find.descendant(of: find.byType(ListView), matching: find.text(text));

Future<void> _pump(
  WidgetTester tester,
  ZChatToolController controller, {
  ZChatMaterialToolLabels labels = kLabels,
  VoidCallback? onClose,
  void Function(String key)? onCommand,
  Map<String, ZChatMaterialToolTileBuilder> kindBuilders =
      const <String, ZChatMaterialToolTileBuilder>{},
}) async {
  // Une feuille haute : `ListView.builder` est PARESSEUX, et une garde qui
  // compte des séparateurs sur une fenêtre trop courte compterait le
  // découpage de l'écran, pas celui des sections.
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZChatMaterialToolsSheet(
          controller: controller,
          labels: labels,
          onClose: onClose,
          onCommand: onCommand,
          kindBuilders: kindBuilders,
          draggable: false,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('🔴 MT-1 — une entrée désactivée est RENDUE, grisée, avec sa raison',
      () {
    testWidgets('elle reste à l\'écran et porte son motif', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      await _pump(tester, c);

      expect(_tile('Résumé'), findsOneWidget,
          reason: '🔴 masquée : c\'est exactement le défaut legacy');
      expect(find.text(kReasonWebText), findsOneWidget);

      final SwitchListTile tile = tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text('Résumé'),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(tile.onChanged, isNull,
          reason: '🔴 grisée signifie non actionnable');
    });

    testWidgets('…et un tap dessus n\'explose pas et n\'écrit rien', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      await _pump(tester, c);
      final ZChatToolCatalog before = c.catalog;

      await tester.tap(_tile('Résumé'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(identical(c.catalog, before), isTrue);
    });

    testWidgets('le sous-titre décrit l\'ÉTAT, jamais la fonction', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.text('Désactivée'), findsOneWidget);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('Activée'), findsOneWidget);
    });
  });

  group('🔴 MT-2 — la feuille et la bande affichent LE MÊME nombre', () {
    testWidgets('le badge de l\'en-tête est le comptage du domaine', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      c.advance('think');
      await _pump(tester, c);

      final int band =
          c.catalog.resolve(surface: ZChatToolSurface.band).activeCount;
      final int sheet =
          c.catalog.resolve(surface: ZChatToolSurface.sheet).activeCount;
      expect(band, sheet);
      expect(band, greaterThan(0), reason: '🔴 GARDE VACUELLE : 0 partout');

      final ZChatMaterialBadge badge = tester.widget<ZChatMaterialBadge>(
        find.byType(ZChatMaterialBadge).first,
      );
      expect(badge.count, band);
    });
  });

  group('🔴 MT-3 — AD-13 : toute cible est ≥ 48 dp en géométrie RENDUE', () {
    testWidgets('tuiles, puces et boutons de l\'en-tête', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      await _pump(tester, c, onClose: () {}, onCommand: (String _) {});

      int measured = 0;
      for (final Type type in <Type>[
        SwitchListTile,
        ListTile,
        FilterChip,
        InputChip,
        IconButton,
        TextButton,
        FilledButton,
      ]) {
        for (final Element e in find.byType(type).evaluate()) {
          final Size size = tester.getSize(find.byElementPredicate(
            (Element candidate) => identical(candidate, e),
          ));
          measured++;
          expect(size.height, greaterThanOrEqualTo(kZChatMinTapTarget),
              reason: '🔴 cible de $type haute de ${size.height} dp');
        }
      }
      expect(measured, greaterThan(5),
          reason: '🔴 GARDE VACUELLE : $measured cible(s) mesurée(s)');
    });
  });

  group('🔴 MT-4/MT-5 — rien ne lève (AD-4/AD-10)', () {
    testWidgets('une nature inconnue n\'a pas de rendu par défaut, et ne '
        'lève pas', (WidgetTester tester) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(tester.takeException(), isNull);
      expect(_tile('Nature d\'hôte'), findsNothing);
    });

    testWidgets('…et le builder de l\'hôte la reprend (non-vacuité)', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZChatMaterialToolsSheet(
              controller: c,
              labels: kLabels,
              draggable: false,
              unknownBuilder: (
                BuildContext context,
                ZChatToolController controller,
                ZChatToolResolvedEntry resolved,
              ) => Text(resolved.entry.label!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_tile('Nature d\'hôte'), findsOneWidget);
    });
  });

  group('🔴 MT-6 — AD-2 : régler un outil ne reconstruit pas les autres', () {
    testWidgets('la tuile voisine n\'est pas reconstruite', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      final Map<String, int> builds = <String, int>{};
      await _pump(
        tester,
        c,
        kindBuilders: <String, ZChatMaterialToolTileBuilder>{
          kZChatToolKindToggle: (
            BuildContext context,
            ZChatToolController controller,
            ZChatToolResolvedEntry resolved,
          ) {
            builds[resolved.entry.key] =
                (builds[resolved.entry.key] ?? 0) + 1;
            return SwitchListTile(
              value: resolved.entry.isActive,
              onChanged: (bool next) => controller.setEntryState(
                resolved.entry.key,
                ZChatToggleState(value: next),
              ),
              title: Text(resolved.entry.label!),
            );
          },
        },
      );
      expect(builds['web'], 1);
      expect(builds['summary'], 1);

      await tester.tap(_tile('Recherche web'));
      await tester.pumpAndSettle();

      expect(builds['web'], 2, reason: '🔴 la tuile réglée doit se refaire');
      expect(builds['summary'], 2,
          reason: '🔴 `summary` DEVIENT grisée : sa tuile doit se refaire');

      final int before = builds['summary']!;
      await tester.tap(_tile('Recherche web'));
      await tester.pumpAndSettle();
      // `summary` redevient actionnable : elle bouge encore. On mesure donc
      // sur une tuile qui, elle, n'a AUCUN lien avec la bascule.
      expect(builds['summary'], greaterThan(before));
    });

    testWidgets('une tuile SANS aucun lien n\'est jamais reconstruite', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(
        catalog: ZChatToolCatalog(
          sections: <ZChatToolSection>[
            const ZChatToolSection(key: 'gen', label: 'G'),
          ],
          entries: <ZChatToolEntry>[
            ZChatToolEntry(
              key: 'a',
              sectionKey: 'gen',
              label: 'A',
              state: const ZChatToggleState(),
            ),
            ZChatToolEntry(
              key: 'b',
              sectionKey: 'gen',
              label: 'B',
              state: const ZChatToggleState(),
            ),
          ],
        ),
      );
      addTearDown(c.dispose);
      final Map<String, int> builds = <String, int>{};
      await _pump(
        tester,
        c,
        kindBuilders: <String, ZChatMaterialToolTileBuilder>{
          kZChatToolKindToggle: (
            BuildContext context,
            ZChatToolController controller,
            ZChatToolResolvedEntry resolved,
          ) {
            builds[resolved.entry.key] =
                (builds[resolved.entry.key] ?? 0) + 1;
            return SwitchListTile(
              value: resolved.entry.isActive,
              onChanged: (bool next) => controller.setEntryState(
                resolved.entry.key,
                ZChatToggleState(value: next),
              ),
              title: Text(resolved.entry.label!),
            );
          },
        },
      );
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      expect(builds['a'], 2);
      expect(builds['b'], 1,
          reason: '🔴 AD-2 : régler A a reconstruit la tuile B — c\'est le '
              'rafraîchissement global que ce socle existe pour éviter');
    });
  });

  group('🔴 MT-7 — le cycle BOUCLE : il passe par `advance`', () {
    testWidgets('quatre taps sur un cycle à trois crans donnent 1, 2, 0, 1', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c);
      final List<int> steps = <int>[];
      for (int i = 0; i < 4; i++) {
        await tester.tap(_tile('Réflexion'));
        await tester.pumpAndSettle();
        steps.add(
          (c.catalog.entry('think')!.state as ZChatCycleState).step,
        );
      }
      expect(steps, <int>[1, 2, 0, 1],
          reason: '🔴 une saturation au dernier cran signalerait un incrément '
              'réimplémenté dans le rendu');
      expect(find.text('Longue'), findsNothing);
    });
  });

  group('🔴 MT-8 — un séparateur ENTRE deux sections, sans index magique', () {
    testWidgets('trois sections rendues ⇒ deux séparateurs', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c, onCommand: (String _) {});
      expect(c.sheetStructure.value.sections, hasLength(3));
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('une section qui perd toutes ses entrées perd aussi son '
        'en-tête ET son séparateur', (WidgetTester tester) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c);
      c.setQuery('portée');
      await tester.pumpAndSettle();
      expect(_tile('Génération'), findsNothing);
      expect(_tile('Documents'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });
  });

  group('🔴 MT-9/MT-10 — le catalogue filtrable', () {
    testWidgets('une entrée indisponible est GRISÉE avec sa raison, jamais '
        'masquée', (WidgetTester tester) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c);

      expect(find.text('Dossier Y'), findsOneWidget);
      final FilterChip chip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Dossier Y'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(chip.onSelected, isNull);
      expect(
        find.ancestor(
          of: find.text('Dossier Y'),
          matching: find.byType(Tooltip),
        ),
        findsWidgets,
      );
    });

    testWidgets('la puce « tout » n\'existe QUE si l\'hôte l\'a nommée '
        '(FR-26)', (WidgetTester tester) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.text('Tous'), findsOneWidget);

      await _pump(
        tester,
        c,
        labels: const ZChatMaterialToolLabels(reasonOf: _reason),
      );
      expect(find.text('Tous'), findsNothing,
          reason: '🔴 le socle a inventé un libellé que l\'hôte n\'a pas '
              'fourni');
    });

    testWidgets('cocher un item écrit par le domaine', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c);
      await tester.tap(_tile('Dossier X'));
      await tester.pumpAndSettle();
      expect(
        (c.catalog.entry('corpus')!.state as ZChatCatalogState).selectedKeys,
        <String>['x'],
      );
    });
  });

  group('🔴 MT-11 — en-tête, actifs, recherche', () {
    testWidgets('l\'en-tête des actifs liste ce qui est activé et le retire',
        (WidgetTester tester) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.text('Actifs'), findsNothing);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('Actifs'), findsOneWidget);
      expect(find.byType(InputChip), findsOneWidget);

      final InputChip chip = tester.widget<InputChip>(find.byType(InputChip));
      expect(chip.onDeleted, isNotNull,
          reason: '🔴 une puce d\'actif se retire, sinon elle n\'informe que '
              'd\'un état qu\'on ne peut pas défaire');
      chip.onDeleted!();
      await tester.pumpAndSettle();
      expect(c.activeKeys.value, isEmpty);
      expect(find.text('Actifs'), findsNothing);
    });

    testWidgets('« réinitialiser » vide réellement le comptage', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      await _pump(tester, c);
      await tester.tap(find.text('Réinitialiser'));
      await tester.pumpAndSettle();
      expect(c.activeKeys.value, isEmpty);
    });

    testWidgets('la fermeture n\'existe que si l\'hôte en fournit une', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.byIcon(Icons.close), findsNothing);
      await _pump(tester, c, onClose: () {});
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('la recherche n\'est proposée que si le catalogue est large '
        'ET nommée par l\'hôte', (WidgetTester tester) async {
      final ZChatToolController large =
          ZChatToolController(catalog: _fixture());
      addTearDown(large.dispose);
      await _pump(tester, large);
      expect(find.byType(TextField), findsOneWidget);

      await _pump(
        tester,
        large,
        labels: const ZChatMaterialToolLabels(reasonOf: _reason),
      );
      expect(find.byType(TextField), findsNothing);

      final ZChatToolController small = ZChatToolController(
        catalog: ZChatToolCatalog(
          sections: <ZChatToolSection>[
            const ZChatToolSection(key: 'gen', label: 'G'),
          ],
          entries: <ZChatToolEntry>[
            ZChatToolEntry(
              key: 'a',
              sectionKey: 'gen',
              label: 'A',
              state: const ZChatToggleState(),
            ),
          ],
        ),
      );
      addTearDown(small.dispose);
      await _pump(tester, small);
      expect(find.byType(TextField), findsNothing,
          reason: '🔴 une barre de recherche sur deux outils est du bruit');
    });

    testWidgets('taper dans la recherche filtre le rendu, jamais le comptage',
        (WidgetTester tester) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      await _pump(tester, c);
      final int before = c.activeCount.value;

      await tester.enterText(find.byType(TextField), 'portée');
      await tester.pumpAndSettle();

      expect(_tile('Recherche web'), findsNothing);
      expect(_tile('Portée'), findsOneWidget);
      expect(c.activeCount.value, before);
    });
  });

  group('🔴 MT-12 — les autres natures', () {
    testWidgets('un choix est rendu en segments, et écrit par le domaine', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      await tester.tap(_tile('Direct'));
      await tester.pumpAndSettle();
      expect(
        (c.catalog.entry('style')!.state as ZChatChoiceState).selectedKey,
        'b',
      );
    });

    testWidgets('une échelle est rendue en curseur à repères', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.byType(ZChatMaterialLabelledSlider), findsOneWidget);
      expect(find.text('Basse'), findsOneWidget);
      expect(find.text('Haute'), findsOneWidget);
    });

    testWidgets('une action n\'est rendue que si l\'hôte fournit le geste', (
      WidgetTester tester,
    ) async {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      await _pump(tester, c);
      expect(find.widgetWithText(FilledButton, 'Vider'), findsNothing);

      final List<String> fired = <String>[];
      await _pump(tester, c, onCommand: fired.add);
      expect(find.widgetWithText(FilledButton, 'Vider'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Vider'));
      await tester.pumpAndSettle();
      expect(fired, <String>['clear'],
          reason: '🔴 une action ne peuple jamais le comptage : elle se '
              'déclenche');
      expect(c.activeKeys.value, isNot(contains('clear')));
    });
  });
}
