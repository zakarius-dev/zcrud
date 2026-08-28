/// La **présentation** de la barre d'artefacts : le libellé de pastille, et le
/// menu de verbes.
///
/// Ce que ce fichier prouve, garde par garde :
/// * **B1** — le libellé de pastille est LISIBLE et n'est **pas** la couleur de
///   surface, en thème **sombre** comme en clair. La couleur assertée est celle
///   qui est *effectivement peinte* (`RenderParagraph`), et le rapport de
///   contraste est recalculé ici par une implémentation **indépendante** de
///   celle du socle — rappeler `zReadableTintOn` rendrait la garde tautologique.
/// * **B2** — le plancher tient MÊME quand l'hôte déclare un fond de pastille
///   inhabituel : un jaune très clair (où un premier plan clair serait
///   illisible) et un rouge saturé sombre (le cas mesuré chez l'hôte).
/// * **B3** — une présentation injectée est **réellement employée** : c'est son
///   rendu qui est asserté, jamais le fait qu'un paramètre ait été passé. Et
///   elle reçoit **exactement** les verbes visibles.
/// * **B4** — la présentation injectée ne peut pas diverger du socle : son
///   `select` passe par le MÊME chemin, donc un verbe destructeur **demande**
///   avant d'agir, et un verbe ordinaire ferme le menu.
/// * **B5** — sans injection, le défaut est une **grille** : trois verbes
///   tiennent sur UNE ligne (géométrie, pas apparence), et la colonne reste
///   atteignable par `menuCrossAxisCount: 1` — contre-preuve incluse.
/// * **B6** — AD-10 : une présentation qui LÈVE ⇒ le menu du socle prend le
///   relais, aucune exception ne remonte au rendu.
/// * **B7** — contre-témoin à comptes ABSOLUS sur ce qui ne doit PAS bouger :
///   la sélection des verbes reste au socle (un verbe dont la condition ne
///   tient pas n'est ni rendu ni transmis à la présentation injectée), et un
///   hôte sans artefact déclaré ne gagne aucun widget.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_fakes.dart';

// ── Instruments ──────────────────────────────────────────────────────────

const IconData _iconA = IconData(0xE900);

String _fb(String key) => kZChatLabelFallbacks[key]!;

/// Luminance relative WCAG 2.x — implémentation **indépendante** de celle du
/// socle (patron de la garde de contraste des glyphes).
double _luminance(Color c) {
  double lin(double channel) => channel <= 0.03928
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _ratio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = math.max(la, lb);
  final double lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Un hôte minimal, dont le THÈME est le sujet : `material` vit dans le test,
/// jamais dans `lib/`.
Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Directionality(
    textDirection: TextDirection.ltr,
    child: Scaffold(body: child),
  ),
);

ZChatMessage get _message => const ZChatMessage(
  id: 'm1',
  conversationId: 'c1',
  role: ZChatRole.assistant,
  contentBlocks: <ZContentBlock>[ZTextBlock(text: 'corps')],
);

/// La couleur RÉELLEMENT peinte du libellé de pastille — le style résolu du
/// paragraphe, pas le paramètre passé au widget.
Color _badgeLabelColor(WidgetTester tester, String count) =>
    tester.renderObject<RenderParagraph>(find.text(count)).text.style!.color!;

/// La couleur RÉELLEMENT peinte du fond de pastille.
Color _badgeBackgroundColor(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(ZChatArtifactBar),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color!;
}

/// La surface résolue par le socle sous ce thème.
Color _surfaceOf(WidgetTester tester) => ZcrudTheme.of(
  tester.element(find.byType(ZChatArtifactBar)),
).surfaceColor!;

ZChatArtifactSpec _counted({int count = 3}) => ZChatArtifactSpec(
  key: kZChatCapabilityMindmap,
  icon: _iconA,
  label: 'Carte mentale',
  presence: (ZChatMessage _) => true,
  count: (ZChatMessage _) => count,
);

Future<void> _pumpBadge(
  WidgetTester tester, {
  required ThemeData theme,
}) async {
  await tester.pumpWidget(
    _app(
      ZChatArtifactBar(
        message: _message,
        artifacts: <ZChatArtifactSpec>[_counted()],
      ),
      theme: theme,
    ),
  );
}

/// Un thème dont SEULE la couleur d'erreur est imposée — le reste du schéma
/// reste celui du SDK, pour que la garde mesure notre chaîne et non la sienne.
ThemeData _withError(Brightness brightness, Color error) {
  final ThemeData base = ThemeData(brightness: brightness);
  return base.copyWith(colorScheme: base.colorScheme.copyWith(error: error));
}

/// Les libellés de verbe rendus, dans l'ordre de l'arbre.
List<String> _verbTexts(WidgetTester tester) => <String>[
  for (final Text t in tester.widgetList<Text>(find.byType(Text)))
    if (t.data != null && _vocabulary.contains(t.data)) t.data!,
];

Set<String> get _vocabulary => <String>{
  _fb(kZChatLabelArtifactCreate),
  _fb(kZChatLabelArtifactOpen),
  _fb(kZChatLabelArtifactRegenerate),
  _fb(kZChatLabelArtifactDelete),
};

void main() {
  group('🔴 CR86-B1 — le libellé de pastille n\'est PAS la surface', () {
    for (final (String nom, Brightness brightness) in <(String, Brightness)>[
      ('sombre', Brightness.dark),
      ('clair', Brightness.light),
    ]) {
      testWidgets('thème $nom : libellé lisible, et ≠ couleur de surface', (
        WidgetTester tester,
      ) async {
        await _pumpBadge(tester, theme: ThemeData(brightness: brightness));

        final Color painted = _badgeLabelColor(tester, '3');
        final Color background = _badgeBackgroundColor(tester);
        final Color surface = _surfaceOf(tester);

        expect(
          painted,
          isNot(surface),
          reason:
              '🔴 le libellé de pastille vaut la couleur de SURFACE '
              '($painted) : la surface n\'a aucune raison d\'être lisible sur '
              'une pastille d\'alerte — en thème sombre, c\'est du noir sur '
              'du rouge, correct à la mesure et faux à l\'usage',
        );
        expect(
          _ratio(painted, background),
          greaterThanOrEqualTo(4.5),
          reason:
              '🔴 le libellé de pastille ($painted) est sous le plancher de '
              'contraste du TEXTE contre son fond ($background)',
        );
      });
    }

    testWidgets('thème sombre + rouge saturé (le cas mesuré chez l\'hôte) : le '
        'libellé est CLAIR, jamais la surface sombre', (
      WidgetTester tester,
    ) async {
      const Color rouge = Color(0xFFD32F2F);
      await _pumpBadge(
        tester,
        theme: _withError(Brightness.dark, rouge),
      );

      final Color painted = _badgeLabelColor(tester, '3');
      final Color surface = _surfaceOf(tester);

      expect(_badgeBackgroundColor(tester), rouge);
      expect(
        painted,
        isNot(surface),
        reason: '🔴 la surface sombre est repeinte telle quelle sur le rouge',
      );
      expect(
        _luminance(painted),
        greaterThan(_luminance(rouge)),
        reason:
            '🔴 le libellé est plus SOMBRE que la pastille rouge : personne '
            'n\'écrit du noir sur une pastille d\'alerte',
      );
      expect(_ratio(painted, rouge), greaterThanOrEqualTo(4.5));
    });

    testWidgets('thème sombre, schéma COHÉRENT (rouge saturé + son premier '
        'plan) : le libellé est EXACTEMENT le rôle déclaré', (
      WidgetTester tester,
    ) async {
      const Color rouge = Color(0xFFD32F2F);
      const Color dessus = Color(0xFFFFFFFF);
      final ThemeData base = ThemeData(brightness: Brightness.dark);
      await _pumpBadge(
        tester,
        theme: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
            error: rouge,
            onError: dessus,
          ),
        ),
      );
      // ÉGALITÉ EXACTE : le rôle « ce qui se pose sur la couleur d'erreur »
      // tient déjà le plancher sur ce rouge, donc il est peint INCHANGÉ —
      // c'est la preuve que le libellé vient bien du rôle apparié au fond, et
      // non d'une correction de contraste appliquée à autre chose.
      expect(
        _badgeLabelColor(tester, '3'),
        dessus,
        reason:
            '🔴 le libellé ne vient pas du premier plan APPARIÉ au fond de la '
            'pastille : il a été dérivé d\'une autre couleur',
      );
    });
  });

  group('🔴 CR86-B2 — le plancher tient sur un fond de pastille INHABITUEL', () {
    for (final (String nom, Color fond) in <(String, Color)>[
      ('jaune très clair', Color(0xFFFFF59D)),
      ('bleu de luminance médiane', Color(0xFF3F51B5)),
      ('presque blanc', Color(0xFFFAFAFA)),
    ]) {
      testWidgets('fond déclaré $nom ⇒ libellé au plancher', (
        WidgetTester tester,
      ) async {
        await _pumpBadge(tester, theme: _withError(Brightness.light, fond));
        final Color painted = _badgeLabelColor(tester, '3');
        expect(_badgeBackgroundColor(tester), fond);
        expect(
          _ratio(painted, fond),
          greaterThanOrEqualTo(4.5),
          reason:
              '🔴 sur un fond de pastille $nom, le libellé peint ($painted) '
              'tombe sous 4,5:1 — le plancher n\'est plus un garde-fou',
        );
      });
    }
  });

  group('🔴 CR86-B3/B4 — la présentation du menu est INJECTABLE', () {
    testWidgets('la présentation injectée est RENDUE, et reçoit exactement les '
        'verbes visibles', (WidgetTester tester) async {
      List<String>? recus;
      await tester.pumpWidget(
        _app(
          ZChatArtifactBar(
            message: _message,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                actions: <ZChatArtifactAction>[
                  // Sa condition NE TIENT PAS sur un artefact présent.
                  ZChatArtifactAction.create(onSelected: (ZChatMessage _) {}),
                  ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                  ZChatArtifactAction.regenerate(
                    onSelected: (ZChatMessage _) {},
                  ),
                ],
              ),
            ],
            menuBuilder:
                (
                  BuildContext context,
                  List<ZChatArtifactAction> actions,
                  void Function(ZChatArtifactAction) select,
                ) {
                  recus = <String>[
                    for (final ZChatArtifactAction a in actions)
                      a.label ?? _fb(a.labelKey!),
                  ];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('MENU-HÔTE'),
                      for (final ZChatArtifactAction a in actions)
                        GestureDetector(
                          onTap: () => select(a),
                          child: Text(a.label ?? _fb(a.labelKey!)),
                        ),
                    ],
                  );
                },
          ),
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();

      expect(
        find.text('MENU-HÔTE'),
        findsOneWidget,
        reason:
            '🔴 le rendu de la présentation injectée est ABSENT : le socle a '
            'peint son menu à lui malgré la couture',
      );
      expect(
        recus,
        <String>[
          _fb(kZChatLabelArtifactOpen),
          _fb(kZChatLabelArtifactRegenerate),
        ],
        reason:
            '🔴 la SÉLECTION des verbes a changé de main : la barre doit '
            'continuer de décider quels verbes sont visibles',
      );
    });

    testWidgets('le `select` de la présentation injectée passe par le MÊME '
        'chemin : un verbe destructeur DEMANDE avant d\'agir', (
      WidgetTester tester,
    ) async {
      int supprime = 0;
      await tester.pumpWidget(
        _app(
          ZChatArtifactBar(
            message: _message,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                actions: <ZChatArtifactAction>[
                  // DEUX verbes visibles : un verbe unique ne passe plus par
                  // un menu (il s'exécute au clic) — c'est la couture de MENU
                  // qui est mesurée ici.
                  ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                  ZChatArtifactAction.delete(
                    onSelected: (ZChatMessage _) => supprime++,
                  ),
                ],
              ),
            ],
            menuBuilder:
                (
                  BuildContext context,
                  List<ZChatArtifactAction> actions,
                  void Function(ZChatArtifactAction) select,
                ) => GestureDetector(
                  onTap: () => select(actions.last),
                  child: const Text('MENU-HÔTE'),
                ),
          ),
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      await tester.tap(find.text('MENU-HÔTE'));
      await tester.pump();

      expect(
        supprime,
        0,
        reason:
            '🔴 une présentation injectée a contourné la confirmation : le '
            'verbe destructeur a agi sans question',
      );
      expect(
        find.text(_fb(kZChatLabelArtifactConfirmPrompt)),
        findsOneWidget,
        reason: '🔴 la question du socle n\'a pas été posée',
      );

      await tester.tap(find.text(_fb(kZChatLabelArtifactConfirm)));
      await tester.pump();
      expect(supprime, 1);
      expect(find.text('MENU-HÔTE'), findsNothing);
    });
  });

  group('🔴 CR86-B5 — sans injection, le défaut est une GRILLE', () {
    Future<List<Rect>> rects(
      WidgetTester tester, {
      required int columns,
    }) async {
      await tester.pumpWidget(
        _app(
          ZChatArtifactBar(
            message: _message,
            menuCrossAxisCount: columns,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => false,
                // Trois verbes DONT LA CONDITION TIENT tous les trois : la
                // garde mesure la DISPOSITION, elle ne doit pas dépendre du
                // filtrage.
                actions: <ZChatArtifactAction>[
                  ZChatArtifactAction(
                    onSelected: (ZChatMessage _) {},
                    labelKey: kZChatLabelArtifactCreate,
                  ),
                  ZChatArtifactAction(
                    onSelected: (ZChatMessage _) {},
                    labelKey: kZChatLabelArtifactOpen,
                  ),
                  ZChatArtifactAction(
                    onSelected: (ZChatMessage _) {},
                    labelKey: kZChatLabelArtifactDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      return <Rect>[
        for (final String v in _verbTexts(tester)) tester.getRect(find.text(v)),
      ];
    }

    testWidgets('trois verbes, trois colonnes ⇒ UNE seule ligne', (
      WidgetTester tester,
    ) async {
      final List<Rect> r = await rects(tester, columns: 3);
      expect(r, hasLength(3));
      expect(
        <double>{for (final Rect x in r) x.top},
        hasLength(1),
        reason:
            '🔴 les trois verbes ne sont pas sur la même ligne : le menu est '
            'reparti en colonne',
      );
      expect(
        r[0].left < r[1].left && r[1].left < r[2].left,
        isTrue,
        reason: '🔴 l\'ordre déclaré par l\'hôte n\'est plus l\'ordre rendu',
      );
      for (final Rect x in r) {
        expect(x.left, greaterThanOrEqualTo(0));
        expect(x.right, lessThanOrEqualTo(800));
      }
    });

    testWidgets('🔬 contre-preuve — `menuCrossAxisCount: 1` retrouve bien une '
        'COLONNE (trois lignes distinctes)', (WidgetTester tester) async {
      final List<Rect> r = await rects(tester, columns: 1);
      expect(r, hasLength(3));
      expect(
        <double>{for (final Rect x in r) x.top},
        hasLength(3),
        reason:
            '🔴 la colonne n\'est plus atteignable : la garde de grille '
            'ci-dessus mesurerait alors une propriété que RIEN ne peut '
            'contredire',
      );
    });
  });

  group('🔴 CR86-B6 — AD-10 : une présentation qui LÈVE ne casse pas l\'écran',
      () {
    testWidgets('le menu du socle prend le relais, l\'exception est relayée', (
      WidgetTester tester,
    ) async {
      final List<FlutterErrorDetails> captures = <FlutterErrorDetails>[];
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = captures.add;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(
        _app(
          ZChatArtifactBar(
            message: _message,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                actions: <ZChatArtifactAction>[
                  // Deux verbes visibles : c'est le MENU qui est mesuré.
                  ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                  ZChatArtifactAction.regenerate(
                    onSelected: (ZChatMessage _) {},
                  ),
                ],
              ),
            ],
            menuBuilder:
                (
                  BuildContext context,
                  List<ZChatArtifactAction> actions,
                  void Function(ZChatArtifactAction) select,
                ) => throw StateError('présentation fautive'),
          ),
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();

      expect(
        find.text(_fb(kZChatLabelArtifactOpen)),
        findsOneWidget,
        reason:
            '🔴 une présentation d\'hôte qui lève a emporté le menu : le '
            'socle doit reprendre la main (AD-10)',
      );
      expect(tester.takeException(), isNull);
      expect(
        captures.any((FlutterErrorDetails d) => d.exception is StateError),
        isTrue,
        reason:
            '🔴 l\'échec du seam est AVALÉ : l\'hôte ne peut plus déboguer sa '
            'présentation',
      );
    });
  });

  group('🔴 CR86-B8 — la surface notebook RELAIE la couture', () {
    testWidgets('`ZChatNotebookView.artifactMenuBuilder` atteint bien le menu '
        '— sinon la couture serait inatteignable depuis la surface que les '
        'hôtes montent', (WidgetTester tester) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[_message],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        _app(
          ZChatNotebookView(
            controller: rig.controller,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                actions: <ZChatArtifactAction>[
                  // Deux verbes visibles : c'est le MENU qui est mesuré.
                  ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                  ZChatArtifactAction.regenerate(
                    onSelected: (ZChatMessage _) {},
                  ),
                ],
              ),
            ],
            artifactMenuBuilder:
                (
                  BuildContext context,
                  List<ZChatArtifactAction> actions,
                  void Function(ZChatArtifactAction) select,
                ) => const Text('MENU-HÔTE'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      expect(
        find.text('MENU-HÔTE'),
        findsOneWidget,
        reason:
            '🔴 la surface notebook n\'a pas relayé la présentation injectée : '
            'l\'hôte qui la monte ne peut pas atteindre la couture',
      );
    });
  });

  group('🔴 CR86-B7 — contre-témoin à comptes ABSOLUS', () {
    testWidgets('la sélection reste au socle : EXACTEMENT deux verbes rendus, '
        'et EXACTEMENT deux boutons', (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          ZChatArtifactBar(
            message: _message,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                actions: <ZChatArtifactAction>[
                  ZChatArtifactAction.create(onSelected: (ZChatMessage _) {}),
                  ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                  ZChatArtifactAction.regenerate(
                    onSelected: (ZChatMessage _) {},
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      expect(_verbTexts(tester), <String>[
        _fb(kZChatLabelArtifactOpen),
        _fb(kZChatLabelArtifactRegenerate),
      ]);
      expect(
        find.descendant(
          of: find.byType(GridView),
          matching: find.byType(GestureDetector),
        ),
        findsNWidgets(2),
        reason:
            '🔴 le menu par défaut ne porte pas EXACTEMENT une cible par verbe '
            'visible',
      );
    });

    testWidgets('la cible d\'un verbe du menu par défaut reste ≥ 48 dp', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ZChatArtifactBar(
            message: _message,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'k',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                actions: <ZChatArtifactAction>[
                  // Deux verbes visibles : c'est la grille de MENU par défaut
                  // qui est mesurée.
                  ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                  ZChatArtifactAction.regenerate(
                    onSelected: (ZChatMessage _) {},
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      final Rect cible = tester.getRect(
        find
            .descendant(
              of: find.byType(GridView),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(cible.width, greaterThanOrEqualTo(kZChatMinTapTarget));
      expect(cible.height, greaterThanOrEqualTo(kZChatMinTapTarget));
    });

    testWidgets('un hôte SANS artefact déclaré ne gagne aucun widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ZChatArtifactBar(
            message: ZChatMessage(
              id: 'm1',
              conversationId: 'c1',
              role: ZChatRole.assistant,
              contentBlocks: <ZContentBlock>[ZTextBlock(text: 'corps')],
            ),
            artifacts: <ZChatArtifactSpec>[],
          ),
        ),
      );
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(DecoratedBox), findsNothing);
    });
  });
}
