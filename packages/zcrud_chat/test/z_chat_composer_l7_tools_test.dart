// Lot L7 (chantier « composer avancé ») — gardes du VOCABULAIRE D'OUTILS.
//
// Ce que ce fichier MESURE, sur des pièces réellement montées et pilotées par
// les verbes publics du contrôleur d'outils — jamais par un objet interne que
// la production ne détiendrait pas.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

// ── Repères ABSOLUS de l'avant-lot ──────────────────────────────────────────
//
// 🔴 Ces valeurs sont écrites en DUR, jamais dérivées d'un second arbre monté
// dans le même test : une garde relative serait affectée par l'injection des
// deux côtés et ne rougirait pas.

/// Le repli français de `kZChatLabelRevealThinking`, tel que la table le
/// publie aujourd'hui.
const String _kThinkingLabel = 'Afficher le raisonnement';

/// Le repli français de `kZChatLabelCapabilityWebSearch`.
const String _kWebLabel = 'Recherche web';


// ── Catalogue de mesure ─────────────────────────────────────────────────────

const Key _kGlyph = Key('l7-glyph');

/// Un glyphe d'hôte, opaque et de taille connue.
Widget get _glyph => const SizedBox(key: _kGlyph, width: 16, height: 16);

/// Un contrôleur d'outils réel, monté sur un catalogue déclaré.
ZChatToolController _tools(List<ZChatToolEntry> entries) {
  final ZChatToolController c = ZChatToolController(
    catalog: ZChatToolCatalog(entries: entries),
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('🔴 G-L7-I — INERTIE : sans puce montée, l\'arbre est celui d\'avant', () {
    testWidgets(
      'les deux bascules existantes portent EXACTEMENT les mêmes nœuds '
      'sémantiques qu\'avant le vocabulaire d\'outils (repères absolus)',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final ZChatSettingsController settings = ZChatSettingsController();
        addTearDown(settings.dispose);
        await tester.pumpWidget(
          harness(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ZChatComposerThinkingToggle(
                  controller: settings,
                  glyph: const SizedBox(width: 16, height: 16),
                  showLabel: false,
                ),
                ZChatComposerWebSearchToggle(
                  controller: settings,
                  glyph: const SizedBox(width: 16, height: 16),
                  showLabel: false,
                ),
              ],
            ),
          ),
        );

        for (final String label in <String>[_kThinkingLabel, _kWebLabel]) {
          final SemanticsNode node = tester.getSemantics(
            find.bySemanticsLabel(label),
          );
          final SemanticsData data = node.getSemanticsData();
          expect(
            data.flagsCollection.isButton,
            isTrue,
            reason: '$label : la bascule reste un bouton.',
          );
          expect(
            data.flagsCollection.isToggled,
            isNot(Tristate.none),
            reason: '$label : l\'état reste porté par `toggled`.',
          );
          // 🔴 LE point de l'inertie : le canal `enabled` a été AJOUTÉ à la
          // primitive de bande pour les puces d'outil. Une bascule ne le
          // porte pas — sans quoi un lecteur d'écran annoncerait un état
          // d'activation là où il n'y en a jamais eu.
          expect(
            data.flagsCollection.isEnabled,
            Tristate.none,
            reason:
                '$label : AUCUN drapeau d\'activation — la bascule n\'en '
                'portait pas avant ce lot.',
          );
          // Idem pour la valeur sémantique : elle est restée VIDE.
          expect(
            data.value,
            '',
            reason: '$label : aucune valeur sémantique avant ce lot.',
          );
        }
        handle.dispose();
      },
    );

    testWidgets(
      'une option de modèle SANS description rend UN SEUL texte et AUCUNE '
      'valeur sémantique (repères absolus)',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await tester.pumpWidget(
          harness(
            ZChatComposerModelSelector(
              options: const <ZChatModelOption>[
                ZChatModelOption(id: 'a', label: 'Alpha'),
              ],
              activeId: 'a',
              onSelect: (String _) {},
            ),
          ),
        );
        // Le menu s'ouvre par le déclencheur — le geste réel d'un hôte.
        await tester.tap(find.text('Alpha').first);
        await tester.pumpAndSettle();

        // Un seul `Text` porte le libellé dans l'item : le canal description
        // n'a rien ajouté à l'arbre.
        expect(
          find.text('Alpha'),
          findsNWidgets(2),
          reason:
              'déclencheur + item : DEUX textes exactement, aucun troisième '
              'venu du canal description.',
        );
        final SemanticsNode node = tester.getSemantics(
          find.bySemanticsLabel('Alpha').last,
        );
        expect(
          node.getSemanticsData().value,
          '',
          reason: 'aucune valeur sémantique sans description déclarée.',
        );
        handle.dispose();
      },
    );
  });

  group('🔴 G-L7-E — les ÉTATS de la puce d\'outil', () {
    testWidgets(
      'au REPOS en compact : ICÔNE SEULE (aucun texte) ; ACTIVE : le libellé '
      'apparaît — sur la MÊME puce, pilotée par le verbe public',
      (WidgetTester tester) async {
        final ZChatToolController tools = _tools(<ZChatToolEntry>[
          ZChatToolEntry(
            key: 'web',
            label: 'Recherche',
            state: const ZChatToggleState(),
          ),
        ]);
        await tester.pumpWidget(
          harness(
            ZChatComposerToolChip(
              controller: tools,
              toolKey: 'web',
              glyph: _glyph,
              showLabel: false,
            ),
          ),
        );
        // REPOS : le glyphe est là, le libellé ne l'est pas.
        expect(find.byKey(_kGlyph), findsOneWidget);
        expect(
          find.text('Recherche'),
          findsNothing,
          reason: 'au repos en compact, la puce est réduite à son icône.',
        );

        // ACTIVE par le VERBE PUBLIC du contrôleur — pas par un remontage.
        tools.setEntryState('web', const ZChatToggleState(value: true));
        await tester.pump();
        expect(
          find.text('Recherche'),
          findsOneWidget,
          reason:
              'active, la puce retrouve son libellé : c\'est son seul canal '
              'visible inconditionnel.',
        );
      },
    );

    testWidgets(
      'le BADGE est rendu quand — et seulement quand — l\'état PORTE un '
      'compte : un catalogue à 2 retenues badge « 2 », une bascule ne badge '
      'rien (vert témoin)',
      (WidgetTester tester) async {
        final ZChatToolController tools = _tools(<ZChatToolEntry>[
          ZChatToolEntry(
            key: 'corpus',
            label: 'Corpus',
            state: ZChatCatalogState(
              itemKeys: const <String>['a', 'b', 'c'],
              selectedKeys: const <String>['a', 'b'],
            ),
          ),
          ZChatToolEntry(
            key: 'web',
            label: 'Recherche',
            state: const ZChatToggleState(value: true),
          ),
        ]);
        await tester.pumpWidget(
          harness(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ZChatComposerToolChip(
                  controller: tools,
                  toolKey: 'corpus',
                  // Un catalogue n'a pas de geste natif : l'hôte le fournit,
                  // sans quoi la puce serait absente (jamais inerte).
                  onTap: () {},
                ),
                ZChatComposerToolChip(controller: tools, toolKey: 'web'),
              ],
            ),
          ),
        );
        expect(
          find.text('2'),
          findsOneWidget,
          reason: 'le catalogue porte 2 retenues : le badge les rend.',
        );
        // 🟢 VERT TÉMOIN : la bascule est ACTIVE et pourtant SANS badge — le
        // badge suit le compte détenu, jamais l'activité.
        expect(
          find.byType(ZChatComposerCountBadge),
          findsOneWidget,
          reason:
              'UN seul badge dans la rangée : la bascule active n\'en porte '
              'aucun, elle n\'a pas de nombre à montrer.',
        );
      },
    );

    testWidgets(
      'INDISPONIBLE : la puce est rendue, INERTE, et annonce SON MOTIF',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        // 🔴 Un geste d'HÔTE : c'est le seul canal d'inertie ATTEIGNABLE
        // depuis le rendu. Mesurer l'inertie sur l'état du domaine ne prouve
        // rien — le catalogue refuse DÉJÀ d'écrire une entrée grisée, et
        // l'assertion resterait verte même si la puce laissait passer le tap
        // (mesuré : l'injection qui retire la garde `enabled ?` ne rougissait
        // pas cette assertion-là).
        int hostTaps = 0;
        final ZChatToolController tools = _tools(<ZChatToolEntry>[
          ZChatToolEntry(
            key: 'offline',
            label: 'Hors ligne',
            state: const ZChatToggleState(value: true),
          ),
          ZChatToolEntry(
            key: 'web',
            label: 'Recherche',
            state: const ZChatToggleState(),
            disabledWhen: <ZChatToolRule>[
              ZChatToolRule(
                condition: ZChatToolCondition(
                  activeKeys: const <String>['offline'],
                ),
                reasonToken: 'reason.offline',
              ),
            ],
          ),
        ]);
        await tester.pumpWidget(
          harness(
            ZChatComposerToolChip(
              controller: tools,
              toolKey: 'web',
              glyph: _glyph,
              showLabel: false,
              onTap: () => hostTaps++,
              reasonOf: (String token) =>
                  token == 'reason.offline' ? 'Mode hors ligne' : null,
            ),
          ),
        );

        // RENDUE — pas masquée : une affordance absente laisserait la
        // question « pourquoi la mienne n'est pas là ? » sans réponse.
        expect(find.byKey(_kGlyph), findsOneWidget);
        // Le libellé reste : indisponible, la puce a quelque chose à dire.
        expect(find.text('Recherche'), findsOneWidget);

        // ANNONCÉE avec son motif, sur le nœud TAPABLE (pas sur un `Text`).
        final SemanticsNode node = tester.getSemantics(
          find.bySemanticsLabel('Recherche'),
        );
        final SemanticsData data = node.getSemanticsData();
        expect(
          data.value,
          'Mode hors ligne',
          reason: 'le motif d\'indisponibilité est LU, pas seulement subi.',
        );
        expect(
          data.flagsCollection.isEnabled,
          Tristate.isFalse,
          reason: 'le nœud tapable annonce explicitement sa désactivation.',
        );

        // INERTE : le nœud ne porte AUCUNE action de tap...
        expect(
          data.hasAction(SemanticsAction.tap),
          isFalse,
          reason:
              'une puce indisponible n\'offre aucune action de tap au '
              'lecteur d\'écran.',
        );
        // ...et le geste d'hôte n'est JAMAIS atteint.
        await tester.tap(find.byKey(_kGlyph), warnIfMissed: false);
        await tester.pump();
        expect(
          hostTaps,
          0,
          reason: 'le tap n\'atteint pas le geste : la puce est inerte.',
        );
        expect(
          tools.catalog.entry('web')!.isActive,
          isFalse,
          reason: 'et l\'état du domaine reste intact (seconde ligne).',
        );
        handle.dispose();
      },
    );

    testWidgets(
      'la cible tapable rendue tient le plancher de 48 dp, glyphe seul '
      'compris (mesurée sur le nœud TAPABLE, jamais sur le texte)',
      (WidgetTester tester) async {
        final ZChatToolController tools = _tools(<ZChatToolEntry>[
          ZChatToolEntry(
            key: 'web',
            label: 'Recherche',
            state: const ZChatToggleState(),
          ),
        ]);
        await tester.pumpWidget(
          harness(
            ZChatComposerToolChip(
              controller: tools,
              toolKey: 'web',
              glyph: _glyph,
              showLabel: false,
            ),
          ),
        );
        // 🔴 Le nœud mesuré est le DÉTECTEUR DE GESTE de la puce — le seul
        // qui reçoive le tap —, pas le glyphe de 16 dp qu'il contient.
        final Size target = tester.getSize(
          find.descendant(
            of: find.byType(ZChatComposerToolChip),
            matching: find.byType(GestureDetector),
          ),
        );
        expect(target.width, greaterThanOrEqualTo(48.0));
        expect(target.height, greaterThanOrEqualTo(48.0));
      },
    );
  });

  group('🔴 G-L7-P — la puce à PALIERS suit le noyau, elle ne le rejoue pas', () {
    testWidgets(
      'le palier RENDU (badge + valeur sémantique) suit l\'état du noyau, y '
      'compris un saut IMPOSÉ DE L\'EXTÉRIEUR — la puce ne tient aucun '
      'compteur',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final ZChatToolController tools = _tools(<ZChatToolEntry>[
          ZChatToolEntry(
            key: 'effort',
            label: 'Effort',
            state: ZChatCycleState(step: 2, stepCount: 6),
            stateLabels: const <String, String>{
              'step.0': 'Aucun',
              'step.2': 'Modéré',
              'step.5': 'Maximal',
            },
          ),
        ]);
        await tester.pumpWidget(
          harness(
            ZChatComposerCycleChip(
              controller: tools,
              toolKey: 'effort',
              glyph: _glyph,
            ),
          ),
        );
        expect(find.text('2'), findsOneWidget, reason: 'le cran 2 est rendu.');
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Effort'))
              .getSemanticsData()
              .value,
          'Modéré',
          reason:
              'le palier est ANNONCÉ par le texte que l\'hôte a associé au '
              'jeton d\'état — le socle n\'en nomme aucun.',
        );

        // 🔴 Saut IMPOSÉ, sans passer par le tap : une puce qui tiendrait son
        // propre compteur afficherait encore 2.
        tools.setEntryState('effort', ZChatCycleState(step: 5, stepCount: 6));
        await tester.pump();
        expect(find.text('5'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Effort'))
              .getSemanticsData()
              .value,
          'Maximal',
        );
        handle.dispose();
      },
    );

    testWidgets(
      'le tap AVANCE par la mécanique du noyau — cran suivant, puis RETOUR À '
      'ZÉRO après le dernier',
      (WidgetTester tester) async {
        final ZChatToolController tools = _tools(<ZChatToolEntry>[
          ZChatToolEntry(
            key: 'effort',
            label: 'Effort',
            state: ZChatCycleState(stepCount: 3),
          ),
        ]);
        await tester.pumpWidget(
          harness(
            ZChatComposerCycleChip(controller: tools, toolKey: 'effort'),
          ),
        );
        int stepOf() =>
            (tools.catalog.entry('effort')!.state as ZChatCycleState).step;
        expect(stepOf(), 0, reason: '🔴 GARDE VACUELLE : rien à avancer.');
        for (final int expected in <int>[1, 2, 0]) {
          await tester.tap(find.text('Effort'));
          await tester.pump();
          expect(
            stepOf(),
            expected,
            reason:
                'le cran suivant — et le retour à zéro — appartiennent au '
                'domaine, jamais à la puce.',
          );
        }
      },
    );

    testWidgets(
      'montée sur une nature qui n\'est PAS un cycle, la puce à paliers ne '
      'rend RIEN (elle ne décide pas du sens des paliers)',
      (WidgetTester tester) async {
        final ZChatToolController tools = _tools(<ZChatToolEntry>[
          ZChatToolEntry(
            key: 'web',
            label: 'Recherche',
            state: const ZChatToggleState(value: true),
          ),
        ]);
        await tester.pumpWidget(
          harness(
            ZChatComposerCycleChip(controller: tools, toolKey: 'web'),
          ),
        );
        expect(find.text('Recherche'), findsNothing);
        expect(find.byType(GestureDetector), findsNothing);
      },
    );
  });

  group('🔴 G-L7-A2 — GRANULARITÉ : une puce qui change ne rejoue rien '
      'd\'autre', () {
    testWidgets(
      'basculer une puce ne reconstruit ni le champ de saisie, ni la puce '
      'voisine — et le champ garde son texte et son focus',
      (WidgetTester tester) async {
        final c = buildController();
        addTearDown(c.controller.dispose);
        final ZChatToolController tools = _tools(<ZChatToolEntry>[
          ZChatToolEntry(
            key: 'web',
            label: 'Recherche',
            state: const ZChatToggleState(),
          ),
          ZChatToolEntry(
            key: 'corpus',
            label: 'Corpus',
            state: const ZChatToggleState(),
          ),
        ]);

        // 🔴 Les sondes sont DANS les sous-arbres visés : le créneau du
        // composer (donc le champ, rejoué avec lui) et la puce VOISINE.
        int slotBuilds = 0;
        int neighbourBuilds = 0;
        await tester.pumpWidget(
          harness(
            ZChatComposer(
              controller: c.controller,
              cursorColor: const Color(0xFF123456),
              leading: (BuildContext context, ZChatComposerSlot slot) {
                slotBuilds++;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ZChatComposerToolChip(controller: tools, toolKey: 'web'),
                    ZChatComposerToolChip(
                      controller: tools,
                      toolKey: 'corpus',
                      badgeBuilder:
                          (BuildContext context, ZChatToolResolvedEntry _) {
                            neighbourBuilds++;
                            return null;
                          },
                      onTap: () {},
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.tap(find.byType(EditableText));
        await tester.pump();
        c.controller.composer.text = 'une phrase en cours';
        await tester.pump();
        final EditableTextState field = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(
          field.widget.focusNode.hasFocus,
          isTrue,
          reason: '🔴 GARDE VACUELLE : le champ n\'a jamais eu le focus.',
        );
        expect(
          slotBuilds,
          greaterThan(0),
          reason: '🔴 GARDE VACUELLE : la sonde du créneau n\'a jamais tourné.',
        );
        expect(
          neighbourBuilds,
          greaterThan(0),
          reason: '🔴 GARDE VACUELLE : la sonde voisine n\'a jamais tourné.',
        );
        final int slotBaseline = slotBuilds;
        final int neighbourBaseline = neighbourBuilds;
        final EditableTextState fieldBefore = field;

        // Le geste RÉEL sur la puce — trois fois.
        for (int i = 0; i < 3; i++) {
          await tester.tap(find.text('Recherche'));
          await tester.pump();
        }
        expect(
          tools.catalog.entry('web')!.isActive,
          isTrue,
          reason: '🔴 GARDE VACUELLE : l\'état n\'a pas bougé.',
        );
        expect(
          slotBuilds,
          slotBaseline,
          reason: 'le créneau — donc le champ — n\'est PAS rejoué.',
        );
        expect(
          neighbourBuilds,
          neighbourBaseline,
          reason: 'la puce VOISINE n\'écoute pas la tranche qui a changé.',
        );
        expect(
          identical(
            tester.state<EditableTextState>(find.byType(EditableText)),
            fieldBefore,
          ),
          isTrue,
          reason: 'le champ n\'a pas été recréé.',
        );
        expect(fieldBefore.widget.focusNode.hasFocus, isTrue);
        expect(find.text('une phrase en cours'), findsOneWidget);
      },
    );
  });
}
