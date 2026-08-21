/// CR-IFFD-84 (volet A) — les **artefacts déclarés** par message.
///
/// Ce que ce fichier prouve, et pourquoi chaque garde existe :
/// * **A1** — la teinte est un ÉTAT : deux artefacts déclarés, l'un présent,
///   l'autre absent ⇒ le premier est teinté, le second garde la couleur
///   ambiante. Et le tap ouvre un menu qui contient EXACTEMENT les verbes
///   dont la condition tient — le contenu est asserté, pas la présence d'un
///   widget.
/// * **A2** — la pastille : compte > 0 ⇒ pastille portant le nombre ; compte
///   nul ou `null` ⇒ AUCUNE pastille (comptes absolus). Et — défaut ① de
///   CR-IFFD-83 — un tap **sous le rectangle de la pastille** déclenche bien
///   le bouton : c'est le badge ASSEMBLÉ, pas seulement son label, qui volait
///   le geste.
/// * **A3** — contre-témoin : sans déclaration, l'arbre est celui d'avant, en
///   COMPTES ABSOLUS de widgets. Jamais une comparaison entre deux rendus
///   passifs, qui serait verte même si les deux avaient régressé ensemble.
/// * **A4** — l'ordre ET la teinte des verbes restent ceux de l'hôte : deux
///   artefacts qui déclarent des ordres différents les obtiennent. C'est la
///   garde qui prouve que la parité IFFD reste atteignable.
/// * **A5** — AD-10 : une lecture d'état qui lève rend l'artefact ABSENT
///   (repli fermant), sans qu'aucune exception ne remonte au rendu.
/// * **A6** — contraste : la teinte rendue respecte le plancher MÊME quand
///   l'hôte déclare une couleur qui ne le respecte pas. Le rapport est
///   recalculé ICI, par une implémentation INDÉPENDANTE de celle du socle —
///   une garde qui rappellerait la fonction mesurée serait tautologique.
/// * **A7** — a11y : l'état est ANNONCÉ (présence, occupation, compte), et la
///   cible tactile est une CONTRAINTE DÉCLARÉE, pas une taille que la mise en
///   page donnerait de toute façon.
/// * **A8** — la confirmation précède l'effet d'un verbe destructeur.
/// * **A9** — `capabilityAccents` est enfin CONSOMMÉ : la chaîne paramètre >
///   jeton > référence décide de la teinte.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

// ── Instruments ──────────────────────────────────────────────────────────

const IconData _iconA = IconData(0xE900);
const IconData _iconB = IconData(0xE901);

/// L'orange de la carte mentale du legacy IFFD — mesuré à 2,05:1 sur blanc.
const Color _legacyOrange = Color(0xFFFF9800);

String _fb(String key) => kZChatLabelFallbacks[key]!;

/// Luminance relative WCAG 2.x — implémentation **indépendante** de celle du
/// socle : c'est ce qui empêche la garde A6 d'être tautologique.
double _luminance(Color c) {
  double lin(double channel) => channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _ratio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Capture les erreurs relayées à `FlutterError` pendant [body] (patron
/// `z_chat_cr71_slots_test.dart`).
Future<List<FlutterErrorDetails>> captureFlutterErrors(
  Future<void> Function() body,
) async {
  final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = caught.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return caught;
}

/// La couleur réellement peinte sur le glyphe de [icon].
Color? _glyphColor(WidgetTester tester, IconData icon) => tester
    .widget<Icon>(
      find.byWidgetPredicate(
        (Widget w) => w is Icon && w.icon == icon,
        description: 'Icon($icon)',
      ),
    )
    .color;

/// Les pastilles réellement rendues — un disque décoré, quel que soit son
/// contenu.
int _badgeCount(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(ZChatArtifactBar),
        matching: find.byType(DecoratedBox),
      ),
    )
    .where(
      (DecoratedBox d) =>
          d.decoration is BoxDecoration &&
          (d.decoration as BoxDecoration).shape == BoxShape.circle,
    )
    .length;

/// Tous les libellés de verbe rendus, **dans l'ordre de l'arbre**.
List<String> _verbTexts(WidgetTester tester, Set<String> vocabulary) =>
    <String>[
      for (final String t in renderedTexts(tester))
        if (vocabulary.contains(t)) t,
    ];

Set<String> get _standardVerbs => <String>{
  _fb(kZChatLabelArtifactCreate),
  _fb(kZChatLabelArtifactOpen),
  _fb(kZChatLabelArtifactRegenerate),
  _fb(kZChatLabelArtifactEdit),
  _fb(kZChatLabelArtifactDelete),
};

void main() {
  group('🔴 CR84-A1 — la teinte est un ÉTAT, et le tap ouvre un MENU', () {
    testWidgets('présent ⇒ teinté ; absent ⇒ couleur ambiante ; le menu porte '
        'EXACTEMENT les verbes dont la condition tient', (
      WidgetTester tester,
    ) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: kZChatCapabilityMindmap,
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                actions: <ZChatArtifactAction>[
                  ZChatArtifactAction.create(
                    onSelected: (ZChatMessage _) {},
                  ),
                  ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                  ZChatArtifactAction.regenerate(
                    onSelected: (ZChatMessage _) {},
                  ),
                ],
              ),
              ZChatArtifactSpec(
                key: kZChatCapabilityFlashcards,
                icon: _iconB,
                label: 'Flashcards',
                presence: (ZChatMessage _) => false,
                actions: <ZChatArtifactAction>[
                  ZChatArtifactAction.create(
                    onSelected: (ZChatMessage _) {},
                  ),
                  ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                ],
              ),
            ],
          ),
        ),
      );

      final Color? present = _glyphColor(tester, _iconA);
      final Color? absent = _glyphColor(tester, _iconB);
      expect(
        present,
        isNotNull,
        reason: '🔴 l\'artefact PRÉSENT n\'est pas teinté : la teinte est '
            'redevenue un style, elle ne dit plus l\'état',
      );
      expect(
        absent,
        isNull,
        reason: '🔴 l\'artefact ABSENT est teint : le legacy n\'applique la '
            'couleur QUE si le contenu est là — sinon le glyphe teinté ne '
            'signifie plus rien',
      );

      // Le MENU : contenu asserté, pas la présence d'un widget.
      await tester.tap(
        find.byWidgetPredicate((Widget w) => w is Icon && w.icon == _iconA),
      );
      await tester.pump();
      expect(
        _verbTexts(tester, _standardVerbs),
        <String>[
          _fb(kZChatLabelArtifactOpen),
          _fb(kZChatLabelArtifactRegenerate),
        ],
        reason: '🔴 le menu d\'un artefact PRÉSENT doit porter « ouvrir » et '
            '« régénérer », et surtout PAS « créer » — un verbe dont la '
            'condition ne tient pas est une invitation à écraser le contenu',
      );
    });

    testWidgets('l\'artefact ABSENT n\'offre que « créer »', (
      WidgetTester tester,
    ) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconB,
                label: 'Flashcards',
                presence: (ZChatMessage _) => false,
                actions: <ZChatArtifactAction>[
                  ZChatArtifactAction.create(
                    onSelected: (ZChatMessage _) {},
                  ),
                  ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                  ZChatArtifactAction.delete(
                    onSelected: (ZChatMessage _) {},
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.tap(
        find.byWidgetPredicate((Widget w) => w is Icon && w.icon == _iconB),
      );
      await tester.pump();
      expect(
        _verbTexts(tester, _standardVerbs),
        <String>[_fb(kZChatLabelArtifactCreate)],
      );
    });
  });

  group('🔴 CR84-A2 — la pastille : présente si > 0, et elle ne VOLE PAS le '
      'tap (CR-IFFD-83, défaut ①)', () {
    Future<void> mount(WidgetTester tester, int? count, VoidCallback? tapped)
    async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                count: (ZChatMessage _) => count,
                actions: <ZChatArtifactAction>[
                  ZChatArtifactAction.open(
                    onSelected: (ZChatMessage _) => tapped?.call(),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('compte > 0 ⇒ UNE pastille portant le nombre', (
      WidgetTester tester,
    ) async {
      await mount(tester, 7, null);
      expect(_badgeCount(tester), 1);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('compte NUL ⇒ AUCUNE pastille (compte absolu)', (
      WidgetTester tester,
    ) async {
      await mount(tester, 0, null);
      expect(
        _badgeCount(tester),
        0,
        reason: '🔴 une pastille « 0 » est du bruit : elle occupe la place '
            'd\'une information sans en porter',
      );
    });

    testWidgets('compte `null` ⇒ AUCUNE pastille (compte absolu)', (
      WidgetTester tester,
    ) async {
      await mount(tester, null, null);
      expect(_badgeCount(tester), 0);
    });

    testWidgets('🔴 le tap SOUS LE RECTANGLE de la pastille déclenche le '
        'bouton — le badge assemblé n\'absorbe rien', (
      WidgetTester tester,
    ) async {
      int opened = 0;
      await mount(tester, 7, () => opened++);
      // 🔴 La pastille est localisée par SON CONTENU, jamais par le widget
      // qui la rend inerte : une garde qui viserait `IgnorePointer` mesurerait
      // sa propre implémentation et rougirait pour la mauvaise raison dès
      // qu'on change de barrière.
      final Finder badge = find.descendant(
        of: find.byType(ZChatArtifactBar),
        matching: find.text('7'),
      );
      expect(badge, findsOneWidget);
      // Le CENTRE de la pastille — le point exact où `Badge.count` absorbait
      // le geste chez IFFD (tap au centre du glyphe : 1 ; à 8 px du coin : 0).
      await tester.tapAt(tester.getCenter(badge));
      await tester.pump();
      expect(
        find.text(_fb(kZChatLabelArtifactOpen)),
        findsOneWidget,
        reason: '🔴 le tap sous la pastille n\'a pas atteint le bouton : la '
            'pastille est redevenue hit-testable (défaut ① de la CR)',
      );
      await tester.tap(find.text(_fb(kZChatLabelArtifactOpen)));
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('🔴 CR84-A3 — contre-témoin : SANS déclaration, rien ne bouge', () {
    testWidgets('aucun artefact déclaré ⇒ comptes ABSOLUS de widgets '
        'inchangés', (WidgetTester tester) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(ZChatNotebookView(controller: rig.controller)),
      );
      expect(find.byType(ZChatArtifactBar), findsNothing);
      expect(
        find.byType(Icon),
        findsNothing,
        reason: '🔴 un glyphe est apparu chez un hôte qui n\'a rien déclaré',
      );
      expect(find.text(_fb(kZChatLabelArtifacts)), findsNothing);
      expect(renderedTexts(tester), <String>['corps']);
      // La tuile garde son CŒUR NU : EXACTEMENT une `Column`, la sienne —
      // le compte absolu qu'assertait déjà CR71-S1 avant ce lot.
      expect(
        find.descendant(
          of: find.byType(ZChatMessageTile),
          matching: find.byType(Column),
        ),
        findsOneWidget,
        reason: '🔴 un conteneur de composition a été ajouté à un hôte passif',
      );
    });

    testWidgets('non-vacuité : le MÊME montage AVEC déclaration monte bien la '
        'rangée', (WidgetTester tester) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
              ),
            ],
          ),
        ),
      );
      expect(find.byType(ZChatArtifactBar), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('le créneau d\'actions de l\'hôte COHABITE avec la rangée', (
      WidgetTester tester,
    ) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            actionsBuilder: (BuildContext context, ZChatMessage m) =>
                const SizedBox(key: ValueKey<String>('propre'), height: 48),
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
              ),
            ],
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('propre')), findsOneWidget);
      expect(find.byType(ZChatArtifactBar), findsOneWidget);
    });
  });

  group('🔴 CR84-A4 — l\'ORDRE et la TEINTE des verbes restent ceux de '
      'l\'hôte', () {
    testWidgets('deux artefacts qui déclarent des ordres différents les '
        'obtiennent, et chaque verbe garde SA teinte', (
      WidgetTester tester,
    ) async {
      const Color vert = Color(0xFF2E7D32);
      const Color grisBleu = Color(0xFF37474F);
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      ZChatArtifactSpec spec(
        String key,
        IconData icon,
        List<ZChatArtifactAction> actions,
      ) => ZChatArtifactSpec(
        key: key,
        icon: icon,
        label: key,
        presence: (ZChatMessage _) => true,
        actions: actions,
      );
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            artifacts: <ZChatArtifactSpec>[
              spec('a', _iconA, <ZChatArtifactAction>[
                ZChatArtifactAction.regenerate(
                  onSelected: (ZChatMessage _) {},
                  accent: vert,
                ),
                ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                ZChatArtifactAction.edit(onSelected: (ZChatMessage _) {}),
              ]),
              spec('b', _iconB, <ZChatArtifactAction>[
                ZChatArtifactAction.edit(onSelected: (ZChatMessage _) {}),
                ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                ZChatArtifactAction.regenerate(
                  onSelected: (ZChatMessage _) {},
                  accent: grisBleu,
                ),
              ]),
            ],
          ),
        ),
      );

      await tester.tap(
        find.byWidgetPredicate((Widget w) => w is Icon && w.icon == _iconA),
      );
      await tester.pump();
      expect(
        _verbTexts(tester, _standardVerbs),
        <String>[
          _fb(kZChatLabelArtifactRegenerate),
          _fb(kZChatLabelArtifactOpen),
          _fb(kZChatLabelArtifactEdit),
        ],
        reason: '🔴 le socle a imposé SON ordre : l\'hôte est alors forcé de '
            'choisir entre le socle et la parité de ses repères appris',
      );
      final Color? teinteA = _paintedColor(
        tester,
        _fb(kZChatLabelArtifactRegenerate),
      );
      // On referme, puis on ouvre le SECOND artefact.
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.tap(
        find.byWidgetPredicate((Widget w) => w is Icon && w.icon == _iconB),
      );
      await tester.pump();
      expect(
        _verbTexts(tester, _standardVerbs),
        <String>[
          _fb(kZChatLabelArtifactEdit),
          _fb(kZChatLabelArtifactOpen),
          _fb(kZChatLabelArtifactRegenerate),
        ],
        reason: '🔴 les deux artefacts rendent le MÊME ordre : les écarts par '
            'artefact ne sont plus exprimables',
      );
      final Color? teinteB = _paintedColor(
        tester,
        _fb(kZChatLabelArtifactRegenerate),
      );
      expect(teinteA, isNotNull);
      expect(teinteB, isNotNull);
      expect(
        teinteA,
        isNot(teinteB),
        reason: '🔴 « Régénérer » rend la même couleur pour les deux '
            'artefacts : la teinte par verbe a été figée par le socle',
      );
    });
  });

  group('🔴 CR84-A5 — AD-10 : une lecture qui LÈVE ferme, elle ne casse pas', () {
    testWidgets('`presence` qui lève ⇒ artefact rendu ABSENT, aucune '
        'exception au rendu', (WidgetTester tester) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      final List<FlutterErrorDetails> caught = await captureFlutterErrors(
        () async {
          await tester.pumpWidget(
            harness(
              ZChatNotebookView(
                controller: rig.controller,
                artifacts: <ZChatArtifactSpec>[
                  ZChatArtifactSpec(
                    key: kZChatCapabilityMindmap,
                    icon: _iconA,
                    label: 'Carte mentale',
                    presence: (ZChatMessage _) =>
                        throw StateError('lecture cassée'),
                    count: (ZChatMessage _) =>
                        throw StateError('compte cassé'),
                    accent: _legacyOrange,
                    actions: <ZChatArtifactAction>[
                      ZChatArtifactAction.create(
                        onSelected: (ZChatMessage _) {},
                      ),
                      ZChatArtifactAction.open(
                        onSelected: (ZChatMessage _) {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '🔴 une lecture d\'hôte qui lève a fait tomber le rendu',
      );
      expect(
        _glyphColor(tester, _iconA),
        isNull,
        reason: '🔴 repli OUVRANT : l\'artefact est peint comme présent alors '
            'que sa présence n\'a PAS pu être lue',
      );
      expect(
        _badgeCount(tester),
        0,
        reason: '🔴 une pastille est apparue sur un compte illisible',
      );
      await tester.tap(
        find.byWidgetPredicate((Widget w) => w is Icon && w.icon == _iconA),
      );
      await tester.pump();
      expect(
        _verbTexts(tester, _standardVerbs),
        <String>[_fb(kZChatLabelArtifactCreate)],
        reason: '🔴 les verbes d\'un artefact PRÉSENT sont offerts sur un état '
            'qu\'on n\'a pas pu lire',
      );
      // L'échec reste OBSERVABLE : il est relayé, jamais avalé en silence.
      expect(
        caught.map((FlutterErrorDetails d) => d.library).toSet(),
        contains('zcrud_chat'),
      );
    });

    testWidgets('une CONDITION de verbe qui lève masque CE verbe, pas les '
        'autres', (WidgetTester tester) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await captureFlutterErrors(() async {
        await tester.pumpWidget(
          harness(
            ZChatNotebookView(
              controller: rig.controller,
              artifacts: <ZChatArtifactSpec>[
                ZChatArtifactSpec(
                  key: 'k',
                  icon: _iconA,
                  label: 'Carte mentale',
                  presence: (ZChatMessage _) => true,
                  actions: <ZChatArtifactAction>[
                    ZChatArtifactAction(
                      labelKey: kZChatLabelArtifactEdit,
                      visible: (ZChatMessage _, bool _) =>
                          throw StateError('condition cassée'),
                      onSelected: (ZChatMessage _) {},
                    ),
                    ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                  ],
                ),
              ],
            ),
          ),
        );
        await tester.tap(
          find.byWidgetPredicate((Widget w) => w is Icon && w.icon == _iconA),
        );
        await tester.pump();
      });
      expect(tester.takeException(), isNull);
      expect(
        _verbTexts(tester, _standardVerbs),
        <String>[_fb(kZChatLabelArtifactOpen)],
      );
    });
  });

  group('🔴 CR84-A6 — le plancher de CONTRASTE tient même contre l\'hôte', () {
    testWidgets('une teinte déclarée sous le plancher est CORRIGÉE avant '
        'd\'être peinte', (WidgetTester tester) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      Color? surface;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (BuildContext context) {
              surface = ZcrudTheme.of(context).surfaceColor;
              return ZChatNotebookView(
                controller: rig.controller,
                artifacts: <ZChatArtifactSpec>[
                  ZChatArtifactSpec(
                    key: kZChatCapabilityMindmap,
                    icon: _iconA,
                    label: 'Carte mentale',
                    presence: (ZChatMessage _) => true,
                    accent: _legacyOrange,
                  ),
                ],
              );
            },
          ),
        ),
      );
      expect(surface, isNotNull);
      // Le TÉMOIN : la teinte brute de l'hôte échoue réellement au plancher.
      expect(
        _ratio(_legacyOrange, surface!),
        lessThan(3.0),
        reason: '🔴 GARDE VACUELLE : la teinte témoin passe déjà le plancher, '
            'la correction n\'est donc pas mesurée',
      );
      final Color? peint = _glyphColor(tester, _iconA);
      expect(peint, isNotNull);
      expect(
        peint,
        isNot(_legacyOrange),
        reason: '🔴 la teinte brute de l\'hôte est peinte telle quelle : le '
            'défaut ④ de la CR (2,05:1) est reproduit par le socle',
      );
      expect(
        _ratio(peint!, surface!),
        greaterThanOrEqualTo(3.0),
        reason: '🔴 la teinte rendue reste sous le plancher WCAG 1.4.11',
      );
    });

    testWidgets('une teinte qui SATISFAIT déjà le plancher est rendue '
        'INCHANGÉE — le choix de l\'hôte n\'est pas réécrit sans nécessité', (
      WidgetTester tester,
    ) async {
      const Color sombre = Color(0xFF1A237E);
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                accent: sombre,
              ),
            ],
          ),
        ),
      );
      expect(_glyphColor(tester, _iconA), sombre);
    });
  });

  group('🔴 CR84-A7 — a11y : l\'état est ANNONCÉ, la cible est DÉCLARÉE', () {
    testWidgets('la sémantique porte présence, occupation et compte', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                count: (ZChatMessage _) => 3,
                busy: (ZChatMessage _) => true,
                actions: <ZChatArtifactAction>[
                  ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                ],
              ),
              ZChatArtifactSpec(
                key: 'k2',
                icon: _iconB,
                label: 'Flashcards',
                presence: (ZChatMessage _) => false,
                actions: <ZChatArtifactAction>[
                  ZChatArtifactAction.create(
                    onSelected: (ZChatMessage _) {},
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      final SemanticsNode? present = findSemantics(
        tester,
        (SemanticsNode n) => n.label == 'Carte mentale',
      );
      expect(present, isNotNull);
      expect(
        present!.value,
        contains(_fb(kZChatLabelGenerated)),
        reason: '🔴 l\'état « déjà généré » n\'est porté que par la couleur',
      );
      expect(present.value, contains(_fb(kZChatLabelArtifactBusy)));
      expect(present.value, contains('3'));
      final SemanticsNode? absent = findSemantics(
        tester,
        (SemanticsNode n) => n.label == 'Flashcards',
      );
      expect(absent, isNotNull);
      expect(
        absent!.value,
        contains(_fb(kZChatLabelArtifactEmpty)),
        reason: '🔴 l\'ABSENCE doit s\'annoncer aussi : une absence qui ne se '
            'signale que par l\'absence d\'annonce est indiscernable d\'un '
            'rendu muet',
      );
      handle.dispose();
    });

    testWidgets('la cible tactile est une CONTRAINTE déclarée ≥ 48 dp — pas '
        'une taille que la mise en page donnerait de toute façon', (
      WidgetTester tester,
    ) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                actions: <ZChatArtifactAction>[
                  ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                ],
              ),
            ],
          ),
        ),
      );
      final Iterable<BoxConstraints> declarees = tester
          .widgetList<ConstrainedBox>(
            find.descendant(
              of: find.byType(ZChatArtifactBar),
              matching: find.byType(ConstrainedBox),
            ),
          )
          .map((ConstrainedBox b) => b.constraints);
      expect(
        declarees.any(
          (BoxConstraints c) =>
              c.minWidth >= 48.0 && c.minHeight >= 48.0,
        ),
        isTrue,
        reason: '🔴 aucune contrainte de 48 dp DÉCLARÉE : la cible ne tient '
            'que par le hasard de la mise en page courante',
      );
    });
  });

  group('🔴 CR84-A8 — la CONFIRMATION précède l\'effet d\'un verbe '
      'destructeur (défaut ⑤)', () {
    /// Monte un artefact PRÉSENT portant un unique verbe destructeur, et
    /// rend le compteur d'exécutions — un compteur, parce que « la
    /// confirmation précède l'effet » se prouve par un ZÉRO, pas par
    /// l'absence d'un widget.
    Future<List<int>> mountDelete(
      WidgetTester tester, {
      ZChatArtifactConfirm? confirm,
    }) async {
      final List<int> fired = <int>[0];
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            confirmArtifactAction: confirm,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                actions: <ZChatArtifactAction>[
                  ZChatArtifactAction.delete(
                    onSelected: (ZChatMessage _) => fired[0]++,
                    confirmMessage: 'Supprimer la carte mentale ?',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      return fired;
    }

    testWidgets('choisir « supprimer » n\'exécute RIEN : le socle demande '
        'd\'abord', (WidgetTester tester) async {
      final List<int> fired = await mountDelete(tester);
      await tester.tap(
        find.byWidgetPredicate((Widget w) => w is Icon && w.icon == _iconA),
      );
      await tester.pump();
      await tester.tap(find.text(_fb(kZChatLabelArtifactDelete)));
      await tester.pump();
      expect(fired.single, 0);
      expect(find.text('Supprimer la carte mentale ?'), findsOneWidget);
      // Le refus n'exécute rien non plus.
      await tester.tap(find.text(_fb(kZChatLabelArtifactCancel)));
      await tester.pump();
      expect(fired.single, 0);
    });

    testWidgets('confirmer exécute — une fois', (WidgetTester tester) async {
      final List<int> fired = await mountDelete(tester);
      await tester.tap(
        find.byWidgetPredicate((Widget w) => w is Icon && w.icon == _iconA),
      );
      await tester.pump();
      await tester.tap(find.text(_fb(kZChatLabelArtifactDelete)));
      await tester.pump();
      await tester.tap(find.text(_fb(kZChatLabelArtifactConfirm)));
      await tester.pump();
      expect(fired.single, 1);
    });

    testWidgets('la couture de l\'hôte, quand elle est fournie, DÉCIDE', (
      WidgetTester tester,
    ) async {
      final List<ZChatArtifactConfirmRequest> asked =
          <ZChatArtifactConfirmRequest>[];
      final List<int> fired = await mountDelete(
        tester,
        confirm:
            (BuildContext context, ZChatArtifactConfirmRequest request) async {
              asked.add(request);
              return false;
            },
      );
      await tester.tap(
        find.byWidgetPredicate((Widget w) => w is Icon && w.icon == _iconA),
      );
      await tester.pump();
      await tester.tap(find.text(_fb(kZChatLabelArtifactDelete)));
      await tester.pumpAndSettle();
      expect(asked, hasLength(1));
      expect(asked.single.artifact.key, 'k');
      expect(fired.single, 0);
    });
  });

  group('🔴 CR84-A9 — `capabilityAccents` est enfin CONSOMMÉ', () {
    Future<Color?> mount(
      WidgetTester tester, {
      ZChatNotebookSkin? skin,
      Color? specAccent,
    }) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            skin: skin,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: kZChatCapabilityMindmap,
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                accent: specAccent,
              ),
            ],
          ),
        ),
      );
      return _glyphColor(tester, _iconA);
    }

    testWidgets('sans réglage, la teinte VIENT de la référence — la table '
        'que personne ne lisait', (WidgetTester tester) async {
      final Color? peint = await mount(tester);
      expect(peint, isNotNull);
      // La référence porte l'orange du legacy ; ce qui est peint en dérive
      // (plancher de contraste), donc la teinte n'est ni nulle ni ambiante.
      expect(
        ZChatNotebookReference
            .capabilities[kZChatCapabilityMindmap]!
            .accent,
        _legacyOrange,
      );
    });

    testWidgets('le PARAMÈTRE du skin bat la référence, et le paramètre de la '
        'spec bat le skin', (WidgetTester tester) async {
      const Color parSkin = Color(0xFF004D40);
      const Color parSpec = Color(0xFF311B92);
      final Color? reference = await mount(tester);
      final Color? skinne = await mount(
        tester,
        skin: const ZChatNotebookSkin(
          capabilityAccents: <String, Color>{
            kZChatCapabilityMindmap: parSkin,
          },
        ),
      );
      final Color? specifie = await mount(
        tester,
        skin: const ZChatNotebookSkin(
          capabilityAccents: <String, Color>{
            kZChatCapabilityMindmap: parSkin,
          },
        ),
        specAccent: parSpec,
      );
      expect(skinne, parSkin, reason: '🔴 le skin n\'est pas consulté');
      expect(specifie, parSpec, reason: '🔴 la spec ne bat pas le skin');
      expect(reference, isNot(skinne));
    });

    testWidgets('une clé que la RÉFÉRENCE ne connaît pas obtient quand même '
        'l\'accent déclaré par le skin', (WidgetTester tester) async {
      const Color invente = Color(0xFF4A148C);
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      expect(
        ZChatNotebookReference.capabilities.containsKey('poem'),
        isFalse,
        reason: '🔴 GARDE VACUELLE : la clé témoin est entrée dans la '
            'référence, elle ne prouve plus rien sur les clés INVENTÉES',
      );
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            skin: const ZChatNotebookSkin(
              capabilityAccents: <String, Color>{'poem': invente},
            ),
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'poem',
                icon: _iconA,
                label: 'Poème',
                presence: (ZChatMessage _) => true,
              ),
            ],
          ),
        ),
      );
      expect(_glyphColor(tester, _iconA), invente);
    });
  });
}

/// La couleur réellement PEINTE sur le texte [data] — mesurée sur le
/// `RenderParagraph`, jamais sur le `TextStyle` demandé.
Color? _paintedColor(WidgetTester tester, String data) {
  final RenderParagraph p = tester.renderObject<RenderParagraph>(
    find.text(data).last,
  );
  return p.text.style?.color;
}
