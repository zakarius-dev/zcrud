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
/// * **A10** — la table de référence porte NEUF entrées, et ce sont les
///   valeurs d'**écran** : `summary` vaut `#607D8B`, PAS le `#2196F3` que
///   porte l'enum du modèle chez l'hôte. La garde asserte la valeur ET la
///   divergence, pour qu'un futur relevé reparti de la mauvaise source
///   rougisse. Une clé **inventée** par l'hôte reste servie par sa propre
///   déclaration — la table est un défaut, pas une liste fermée.
/// * **A11** — les quatre entrées neuves se surchargent exactement comme les
///   cinq anciennes : jeton de thème puis paramètre de skin, **clé par clé**.
/// * **A12** — DÉBORDEMENT : neuf artefacts sur 360 / 320 / 240 dp ⇒ toutes
///   les cibles ≥ 48 dp, dans le viewport, disjointes, et chacune répond à
///   SON tap. Assertions de GÉOMÉTRIE, jamais d'apparence — avec la
///   contre-preuve qu'un `Row` de neuf cibles, lui, sort bien de l'écran.
/// * **A13** — CONTRASTE : les neuf teintes tiennent le plancher §1.4.11 sur
///   surface claire ET sombre. `poem` (`#9C27B0`) est le témoin nommé du côté
///   sombre : 2,97:1 brut, donc réellement sous le plancher — la garde
///   mesurerait du vide s'il tenait déjà.
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

/// Deux teintes SOMBRES : elles tiennent déjà le plancher de contraste sur la
/// surface claire du harnais, donc `zReadableTintOn` les rend INCHANGÉES —
/// c'est ce qui autorise des assertions d'ÉGALITÉ EXACTE sur ce qui est peint,
/// sans jamais rappeler la fonction de correction (qui rendrait la garde
/// tautologique).
const Color _darkA = Color(0xFF004D40);
const Color _darkB = Color(0xFF311B92);

/// Force `disableAnimations` SOUS le `MediaQuery` du harnais — le chemin exact
/// qu'emprunte un vrai réglage d'accessibilité (patron
/// `z_chat_composer_chrome_test.dart`).
Widget _reduceMotion(Widget child) => Builder(
  builder: (BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

/// L'orange de la carte mentale du legacy IFFD. 🔴 Deux chiffres circulent
/// pour cette couleur, et TOUS DEUX sont exacts — sur des surfaces
/// différentes : **2,155:1 sur blanc pur** et **2,049:1 sur le `surface`
/// d'un thème clair Material 3** (`#FEF7FF`). Les deux sont sous le plancher
/// §1.4.11 (3,0:1). La mesure faite ci-dessous n'est ni l'une ni l'autre :
/// elle porte sur la surface RÉELLEMENT résolue par le rendu.
const Color _legacyOrange = Color(0xFFFF9800);

/// Une clé d'artefact que la référence ne connaît PAS — le témoin qui prouve
/// que la table de référence est un **défaut**, pas une liste fermée.
///
/// 🔴 Ce témoin valait `poem` avant CR-IFFD-84 ; la CR a fait entrer `poem`
/// dans la référence. La garde d'anti-vacuité qui accompagnait le témoin a
/// donc rougi, comme elle le devait. Un nom de forme poétique **rare**, qu'un
/// écran d'étude n'aura aucune raison de porter, est le bon choix de témoin.
const String _kCleInventee = 'limerick';

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

/// Le n-ième glyphe témoin d'une rangée de neuf — hors de la plage de
/// [_iconA]/[_iconB], pour qu'aucune garde ne se croise.
IconData _nthIcon(int i) => _nineIcons[i];

const List<IconData> _nineIcons = <IconData>[
  IconData(0xE910),
  IconData(0xE911),
  IconData(0xE912),
  IconData(0xE913),
  IconData(0xE914),
  IconData(0xE915),
  IconData(0xE916),
  IconData(0xE917),
  IconData(0xE918),
];

/// La **cible tactile** qui porte [icon] : la contrainte déclarée de 48 dp,
/// jamais le glyphe de 24 dp qu'elle contient.
Finder _targetOf(IconData icon) => find.ancestor(
  of: find.byWidgetPredicate((Widget w) => w is Icon && w.icon == icon),
  matching: find.byWidgetPredicate(
    (Widget w) =>
        w is ConstrainedBox &&
        w.constraints.minWidth == kZChatMinTapTarget &&
        w.constraints.minHeight == kZChatMinTapTarget,
  ),
);

/// Monte **les neuf clés de la référence**, un artefact présent par clé, et
/// rend la teinte réellement peinte pour chacune.
///
/// La table est parcourue depuis la RÉFÉRENCE elle-même : ajouter une dixième
/// entrée sans l'assertion qui va avec ne peut pas passer inaperçu.
Future<Map<String, Color?>> _mountReferenceKeys(
  WidgetTester tester, {
  ZcrudTheme? theme,
  ZChatNotebookSkin? skin,
  void Function(Color? surface)? onSurface,
}) async {
  final List<String> keys = ZChatNotebookReference.capabilities.keys.toList();
  final rig = buildController(
    initialMessages: <ZChatMessage>[
      assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
    ],
  );
  addTearDown(rig.controller.dispose);
  Widget tree = Builder(
    builder: (BuildContext context) {
      onSurface?.call(ZcrudTheme.of(context).surfaceColor);
      return ZChatNotebookView(
        controller: rig.controller,
        skin: skin,
        artifacts: <ZChatArtifactSpec>[
          for (int i = 0; i < keys.length; i++)
            ZChatArtifactSpec(
              key: keys[i],
              icon: _nthIcon(i),
              label: keys[i],
              presence: (ZChatMessage _) => true,
            ),
        ],
      );
    },
  );
  if (theme != null) tree = ZcrudScope(theme: theme, child: tree);
  await tester.pumpWidget(harness(tree));
  return <String, Color?>{
    for (int i = 0; i < keys.length; i++)
      keys[i]: _glyphColor(tester, _nthIcon(i)),
  };
}

/// Monte **neuf** artefacts présents sur un écran de [largeur] dp et rend les
/// rectangles de leurs cibles tactiles, dans l'ordre déclaré.
Future<List<Rect>> _mountNineTargets(
  WidgetTester tester,
  double largeur,
) async {
  tester.view.physicalSize = Size(largeur, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
          for (int i = 0; i < 9; i++)
            ZChatArtifactSpec(
              key: 'a$i',
              icon: _nthIcon(i),
              label: 'A$i',
              presence: (ZChatMessage _) => true,
              // Une pastille sur chacune : c'est le pire cas de largeur
              // occupée, et c'est aussi elle qui volait le geste (défaut ①).
              count: (ZChatMessage _) => 12,
            ),
        ],
      ),
    ),
  );
  return <Rect>[
    for (int i = 0; i < 9; i++) tester.getRect(_targetOf(_nthIcon(i))),
  ];
}

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
                  ZChatArtifactAction.create(onSelected: (ZChatMessage _) {}),
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
                  ZChatArtifactAction.create(onSelected: (ZChatMessage _) {}),
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
        reason:
            '🔴 l\'artefact PRÉSENT n\'est pas teinté : la teinte est '
            'redevenue un style, elle ne dit plus l\'état',
      );
      expect(
        absent,
        isNull,
        reason:
            '🔴 l\'artefact ABSENT est teint : le legacy n\'applique la '
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
        reason:
            '🔴 le menu d\'un artefact PRÉSENT doit porter « ouvrir » et '
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
                  ZChatArtifactAction.create(onSelected: (ZChatMessage _) {}),
                  ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                  ZChatArtifactAction.delete(onSelected: (ZChatMessage _) {}),
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
      expect(_verbTexts(tester, _standardVerbs), <String>[
        _fb(kZChatLabelArtifactCreate),
      ]);
    });
  });

  group('🔴 CR84-A2 — la pastille : présente si > 0, et elle ne VOLE PAS le '
      'tap (CR-IFFD-83, défaut ①)', () {
    Future<void> mount(
      WidgetTester tester,
      int? count,
      VoidCallback? tapped,
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
        reason:
            '🔴 une pastille « 0 » est du bruit : elle occupe la place '
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
        reason:
            '🔴 le tap sous la pastille n\'a pas atteint le bouton : la '
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
        reason:
            '🔴 le socle a imposé SON ordre : l\'hôte est alors forcé de '
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
        reason:
            '🔴 les deux artefacts rendent le MÊME ordre : les écarts par '
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
        reason:
            '🔴 « Régénérer » rend la même couleur pour les deux '
            'artefacts : la teinte par verbe a été figée par le socle',
      );
    });
  });

  group(
    '🔴 CR84-A5 — AD-10 : une lecture qui LÈVE ferme, elle ne casse pas',
    () {
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
          reason:
              '🔴 repli OUVRANT : l\'artefact est peint comme présent alors '
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
          reason:
              '🔴 les verbes d\'un artefact PRÉSENT sont offerts sur un état '
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
        expect(_verbTexts(tester, _standardVerbs), <String>[
          _fb(kZChatLabelArtifactOpen),
        ]);
      });
    },
  );

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
        reason:
            '🔴 GARDE VACUELLE : la teinte témoin passe déjà le plancher, '
            'la correction n\'est donc pas mesurée',
      );
      final Color? peint = _glyphColor(tester, _iconA);
      expect(peint, isNotNull);
      expect(
        peint,
        isNot(_legacyOrange),
        reason:
            '🔴 la teinte brute de l\'hôte est peinte telle quelle : le '
            'défaut ④ de la CR (2,049:1 sur le `surface` M3 clair) est '
            'reproduit par le socle',
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
                  ZChatArtifactAction.create(onSelected: (ZChatMessage _) {}),
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
        reason:
            '🔴 l\'ABSENCE doit s\'annoncer aussi : une absence qui ne se '
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
          (BoxConstraints c) => c.minWidth >= 48.0 && c.minHeight >= 48.0,
        ),
        isTrue,
        reason:
            '🔴 aucune contrainte de 48 dp DÉCLARÉE : la cible ne tient '
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
        ZChatNotebookReference.capabilities[kZChatCapabilityMindmap]!.accent,
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
          capabilityAccents: <String, Color>{kZChatCapabilityMindmap: parSkin},
        ),
      );
      final Color? specifie = await mount(
        tester,
        skin: const ZChatNotebookSkin(
          capabilityAccents: <String, Color>{kZChatCapabilityMindmap: parSkin},
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
      // 🔴 La clé témoin était `poem` — et CR-IFFD-84 l'a fait ENTRER dans la
      // référence. C'est exactement le cas que ce garde-fou annonçait : la
      // garde serait devenue vacuelle sans qu'elle rougisse au bon endroit.
      // Le témoin est donc une clé que la référence ne portera pas.
      expect(
        ZChatNotebookReference.capabilities.containsKey(_kCleInventee),
        isFalse,
        reason:
            '🔴 GARDE VACUELLE : la clé témoin est entrée dans la '
            'référence, elle ne prouve plus rien sur les clés INVENTÉES',
      );
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            skin: const ZChatNotebookSkin(
              capabilityAccents: <String, Color>{_kCleInventee: invente},
            ),
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: _kCleInventee,
                icon: _iconA,
                label: 'Limerick',
                presence: (ZChatMessage _) => true,
              ),
            ],
          ),
        ),
      );
      expect(_glyphColor(tester, _iconA), invente);
    });
  });

  // ── Tranche 3 — LA TABLE DE NEUF, ET LE DÉBORDEMENT ─────────────────────

  group('🔴 CR84-A10 — la table de référence rend NEUF accents, et ce sont '
      'ceux de l\'ÉCRAN', () {
    testWidgets('les neuf clés — et EXACTEMENT elles — portent un accent de '
        'référence', (WidgetTester tester) async {
      expect(
        ZChatNotebookReference.capabilities.keys.toSet(),
        <String>{
          kZChatCapabilityMindmap,
          kZChatCapabilityFlashcards,
          kZChatCapabilityStory,
          kZChatCapabilityHumour,
          kZChatCapabilityClassroom,
          kZChatCapabilitySummary,
          kZChatCapabilityElaboration,
          kZChatCapabilityExamples,
          kZChatCapabilityPoem,
        },
        reason:
            '🔴 CR-IFFD-84 : « IFFD legacy en rend NEUF, pas cinq ». Une clé '
            'de moins est une capacité que l\'hôte devra reteinter chez lui.',
      );
    });

    testWidgets('chacune des neuf clés rend une teinte DISTINCTE — c\'est le '
        'code-couleur que l\'utilisateur a appris', (WidgetTester tester) async {
      final Map<String, Color?> peint = await _mountReferenceKeys(tester);
      expect(peint.values.whereType<Color>(), hasLength(9),
          reason: '🔴 une clé de référence ne peint plus rien');
      expect(
        peint.values.toSet(),
        hasLength(9),
        reason:
            '🔴 deux clés de référence peignent la MÊME teinte : le '
            'code-couleur du legacy est perdu. Le cas le plus probable est '
            'une valeur relevée sur la mauvaise source — cf. le piège de la '
            'double source. Vu : $peint',
      );
    });

    testWidgets('🔴 LA DOUBLE SOURCE — `summary` porte la valeur d\'ÉCRAN '
        '(#607D8B), PAS celle de l\'enum du modèle (#2196F3)', (
      WidgetTester tester,
    ) async {
      // 🔴 Le piège que CR-IFFD-84 signale nommément : deux sources existent
      // chez l'hôte et elles divergent. « C'est l'écran qui décide de ce que
      // l'utilisateur voit. » Un futur relevé reparti de l'enum du modèle
      // rendrait un résumé de la couleur des flashcards — une régression
      // silencieuse, qui ne casse rien et change ce que l'utilisateur
      // reconnaît.
      const Color ecran = Color(0xFF607D8B);
      final Color declare =
          ZChatNotebookReference.capabilities[kZChatCapabilitySummary]!.accent;
      final Color flashcards = ZChatNotebookReference
          .capabilities[kZChatCapabilityFlashcards]!
          .accent;
      expect(declare, ecran,
          reason: '🔴 `summary` a été « corrigé » vers la valeur du modèle : '
              'relevé d\'écran `chatbot_conversation_screen.dart:1297`.');
      expect(declare, isNot(flashcards),
          reason: '🔴 `summary` a pris la teinte des flashcards — c\'est '
              'EXACTEMENT la valeur que porte l\'enum du modèle (#2196F3).');

      // …et la propriété tient jusqu'au PIXEL, pas seulement dans la table.
      final Map<String, Color?> peint = await _mountReferenceKeys(tester);
      expect(
        peint[kZChatCapabilitySummary],
        isNot(peint[kZChatCapabilityFlashcards]),
        reason: '🔴 à l\'écran, le résumé et les flashcards sont désormais '
            'de la même couleur.',
      );
    });

    testWidgets('les trois autres relevés d\'écran sont ceux de la CR', (
      WidgetTester tester,
    ) async {
      const Map<String, Color> ecran = <String, Color>{
        // `:1306`, `:1315`, `:1324` du relevé d'écran IFFD.
        kZChatCapabilityElaboration: Color(0xFF4CAF50),
        kZChatCapabilityExamples: Color(0xFFE91E63),
        kZChatCapabilityPoem: Color(0xFF9C27B0),
      };
      for (final MapEntry<String, Color> e in ecran.entries) {
        expect(
          ZChatNotebookReference.capabilities[e.key]!.accent,
          e.value,
          reason: '🔴 l\'accent de `${e.key}` a bougé : re-mesurez sur la '
              'table d\'ÉCRAN, jamais sur l\'enum du modèle.',
        );
      }
    });

    testWidgets('une clé INVENTÉE par l\'hôte reste servie par SA propre '
        'déclaration — la table est un DÉFAUT, pas une liste fermée', (
      WidgetTester tester,
    ) async {
      const Color invente = Color(0xFF1A237E);
      expect(
        ZChatNotebookReference.capabilities.containsKey(_kCleInventee),
        isFalse,
        reason: '🔴 GARDE VACUELLE : la clé témoin est entrée dans la '
            'référence.',
      );
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
                key: _kCleInventee,
                icon: _iconA,
                label: 'Limerick',
                presence: (ZChatMessage _) => true,
                // Aucun skin, aucun jeton : la SEULE source d'accent est la
                // déclaration de l'hôte.
                accent: invente,
              ),
            ],
          ),
        ),
      );
      expect(_glyphColor(tester, _iconA), invente,
          reason: '🔴 la table de référence est devenue une liste FERMÉE : un '
              'artefact inventé par l\'hôte a perdu sa teinte.');
    });
  });

  group('🔴 CR84-A11 — les QUATRE nouvelles entrées sont surchargeables comme '
      'les cinq anciennes', () {
    const Map<String, Color> parJeton = <String, Color>{
      kZChatCapabilitySummary: Color(0xFF0A0B0C),
      kZChatCapabilityElaboration: Color(0xFF0D0E0F),
      kZChatCapabilityExamples: Color(0xFF101112),
      kZChatCapabilityPoem: Color(0xFF131415),
    };
    const Map<String, Color> parSkin = <String, Color>{
      kZChatCapabilitySummary: Color(0xFF161718),
      kZChatCapabilityElaboration: Color(0xFF191A1B),
      kZChatCapabilityExamples: Color(0xFF1C1D1E),
      kZChatCapabilityPoem: Color(0xFF1F2021),
    };

    testWidgets('le JETON de thème bat la référence, clé par clé', (
      WidgetTester tester,
    ) async {
      final Map<String, Color?> peint = await _mountReferenceKeys(
        tester,
        // 🔴 `surfaceColor` est fourni DÉLIBÉRÉMENT : `ZcrudScope` REMPLACE le
        // thème, il ne le fusionne pas — sans surface, la chaîne de contraste
        // se replie en FERMANT (aucune teinte peinte), et la garde
        // mesurerait `null` contre `null`.
        theme: const ZcrudTheme(
          surfaceColor: Color(0xFFFFFFFF),
          chatCapabilityAccents: parJeton,
        ),
      );
      for (final MapEntry<String, Color> e in parJeton.entries) {
        expect(peint[e.key], e.value,
            reason: '🔴 le jeton n\'est pas consulté pour `${e.key}` : la '
                'nouvelle entrée n\'est pas un DÉFAUT, c\'est une valeur '
                'figée.');
      }
      // Les cinq anciennes, non citées par le jeton, gardent la référence :
      // la chaîne est résolue clé par clé, pas table par table.
      expect(peint[kZChatCapabilityStory],
          ZChatNotebookReference.capabilities[kZChatCapabilityStory]!.accent,
          reason: '🔴 renseigner quatre clés a effacé les cinq autres.');
    });

    testWidgets('le PARAMÈTRE du skin bat le jeton, clé par clé', (
      WidgetTester tester,
    ) async {
      final Map<String, Color?> peint = await _mountReferenceKeys(
        tester,
        theme: const ZcrudTheme(
          surfaceColor: Color(0xFFFFFFFF),
          chatCapabilityAccents: parJeton,
        ),
        skin: const ZChatNotebookSkin(capabilityAccents: parSkin),
      );
      for (final MapEntry<String, Color> e in parSkin.entries) {
        expect(peint[e.key], e.value,
            reason: '🔴 le skin ne bat pas le jeton pour `${e.key}`.');
      }
    });

    testWidgets('…et les cinq ANCIENNES entrées se surchargent toujours de la '
        'même façon (non-régression)', (WidgetTester tester) async {
      const Map<String, Color> anciennes = <String, Color>{
        kZChatCapabilityMindmap: Color(0xFF222324),
        kZChatCapabilityFlashcards: Color(0xFF252627),
        kZChatCapabilityStory: Color(0xFF28292A),
        kZChatCapabilityHumour: Color(0xFF2B2C2D),
        kZChatCapabilityClassroom: Color(0xFF2E2F30),
      };
      final Map<String, Color?> peint = await _mountReferenceKeys(
        tester,
        skin: const ZChatNotebookSkin(capabilityAccents: anciennes),
      );
      for (final MapEntry<String, Color> e in anciennes.entries) {
        expect(peint[e.key], e.value, reason: '🔴 `${e.key}`');
      }
    });
  });

  group('🔴 CR84-A12 — DÉBORDEMENT : neuf cibles sur un téléphone', () {
    // 🔴 CR-IFFD-84 : « neuf cibles de 48 dp font 432 dp — au-delà d'un
    // téléphone courant ». MESURE faite sur le rendu réel : la rangée est un
    // `Wrap`, qui répartit déjà les neuf cibles sur plusieurs lignes —
    // 6 + 3 sur 360 dp, 5 + 4 sur 320 dp, 4 + 4 + 1 sur 240 dp. Aucune cible
    // ne sort du viewport, aucune ne descend sous 48 dp, aucune n'en recouvre
    // une autre. Aucun mécanisme de débordement supplémentaire n'est donc
    // ajouté : ce qui suit est la garde qui interdit à cette propriété de se
    // perdre — par exemple si le `Wrap` redevenait un `Row`.
    for (final double largeur in <double>[360, 320, 240]) {
      testWidgets('$largeur dp : les neuf cibles restent ATTEIGNABLES, '
          '≥ 48 dp, et DISJOINTES', (WidgetTester tester) async {
        final List<Rect> cibles = await _mountNineTargets(tester, largeur);
        expect(cibles, hasLength(9));
        final Rect ecran = Offset.zero & tester.view.physicalSize;
        for (int i = 0; i < cibles.length; i++) {
          expect(cibles[i].width, greaterThanOrEqualTo(kZChatMinTapTarget),
              reason: '🔴 la cible $i a été rétrécie pour tenir en largeur.');
          expect(cibles[i].height, greaterThanOrEqualTo(kZChatMinTapTarget),
              reason: '🔴 la cible $i a été rétrécie pour tenir en hauteur.');
          expect(ecran.contains(cibles[i].topLeft), isTrue,
              reason: '🔴 la cible $i commence HORS de l\'écran '
                  '(${cibles[i]} vs $ecran) : elle est inatteignable.');
          expect(ecran.contains(cibles[i].bottomRight - const Offset(1, 1)),
              isTrue,
              reason: '🔴 la cible $i déborde de l\'écran (${cibles[i]} vs '
                  '$ecran) : une partie en est inatteignable.');
          for (int j = i + 1; j < cibles.length; j++) {
            expect(cibles[i].overlaps(cibles[j]), isFalse,
                reason: '🔴 les cibles $i et $j se recouvrent : l\'une vole '
                    'le geste de l\'autre.');
          }
        }
      });
    }

    testWidgets('🔬 le détecteur SAIT voir un débordement — un `Row` de neuf '
        'cibles de 48 dp SORT bien de 360 dp', (WidgetTester tester) async {
      // Contre-preuve : sans cette mesure, la garde ci-dessus resterait verte
      // sur un instrument incapable de constater quoi que ce soit.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: OverflowBox(
            alignment: AlignmentDirectional.topStart,
            maxWidth: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < 9; i++)
                  SizedBox(
                    key: ValueKey<int>(i),
                    width: kZChatMinTapTarget,
                    height: kZChatMinTapTarget,
                  ),
              ],
            ),
          ),
        ),
      );
      final Rect derniere = tester.getRect(find.byKey(const ValueKey<int>(8)));
      expect(derniere.right, 9 * kZChatMinTapTarget,
          reason: '🔴 le calcul de la CR (9 × 48 = 432) ne se retrouve pas.');
      expect(derniere.right, greaterThan(360.0),
          reason: '🔴 l\'instrument ne voit pas sortir de l\'écran une '
              'rangée qui en sort : la garde ci-dessus ne prouve rien.');
    });

    testWidgets('les neuf cibles répondent RÉELLEMENT au tap, chacune la '
        'sienne', (WidgetTester tester) async {
      // La géométrie ne suffit pas : une cible peut être dans l'écran ET
      // masquée par un ancêtre. On tape les neuf, et on vérifie que chaque
      // tap atteint SON artefact — jamais celui d'à côté.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final List<String> touches = <String>[];
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
              for (int i = 0; i < 9; i++)
                ZChatArtifactSpec(
                  key: 'a$i',
                  icon: _nthIcon(i),
                  label: 'A$i',
                  presence: (ZChatMessage _) => true,
                  actions: <ZChatArtifactAction>[
                    ZChatArtifactAction.open(
                      onSelected: (ZChatMessage _) => touches.add('a$i'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
      for (int i = 0; i < 9; i++) {
        await tester.tap(_targetOf(_nthIcon(i)));
        await tester.pump();
        await tester.tap(find.text(_fb(kZChatLabelArtifactOpen)));
        await tester.pump();
      }
      expect(touches, <String>[for (int i = 0; i < 9; i++) 'a$i'],
          reason: '🔴 une cible n\'a pas répondu, ou a répondu pour une '
              'autre : $touches');
    });
  });

  group('🔴 CR84-A13 — CONTRASTE : aucune des neuf teintes ne descend sous le '
      'plancher', () {
    testWidgets('sur surface CLAIRE, les neuf teintes peintes tiennent le '
        'plancher §1.4.11', (WidgetTester tester) async {
      Color? surface;
      final Map<String, Color?> peint = await _mountReferenceKeys(
        tester,
        onSurface: (Color? s) => surface = s,
      );
      expect(surface, isNotNull);
      // TÉMOIN : au moins une teinte de la table échoue RÉELLEMENT au
      // plancher sur cette surface — sans quoi la garde ne mesurerait rien.
      final List<String> sousPlancher = <String>[
        for (final MapEntry<String, ZChatNotebookCapabilityStyle> e
            in ZChatNotebookReference.capabilities.entries)
          if (_ratio(e.value.accent, surface!) < 3.0) e.key,
      ];
      expect(sousPlancher, isNotEmpty,
          reason: '🔴 GARDE VACUELLE : aucune teinte de référence n\'échoue '
              'sur cette surface, la correction n\'est pas mesurée.');
      for (final MapEntry<String, Color?> e in peint.entries) {
        expect(_ratio(e.value!, surface!), greaterThanOrEqualTo(3.0),
            reason: '🔴 `${e.key}` est peint sous le plancher WCAG 1.4.11.');
      }
    });

    testWidgets('🔴 sur surface SOMBRE aussi — et c\'est là que le violet du '
        'poème a besoin d\'être ÉCLAIRCI', (WidgetTester tester) async {
      const Color sombre = Color(0xFF121212);
      Color? surface;
      final Map<String, Color?> peint = await _mountReferenceKeys(
        tester,
        theme: const ZcrudTheme(surfaceColor: sombre),
        onSurface: (Color? s) => surface = s,
      );
      expect(surface, sombre, reason: '🔴 la surface sombre n\'a pas pris.');
      // TÉMOIN nommé : `poem` échoue vraiment sur fond sombre (2,97:1). Le
      // relevé de la CR ne le dit pas — il ne porte que la valeur. C'est la
      // mesure faite ici qui l'établit.
      final Color violet =
          ZChatNotebookReference.capabilities[kZChatCapabilityPoem]!.accent;
      expect(_ratio(violet, sombre), lessThan(3.0),
          reason: '🔴 GARDE VACUELLE : `poem` tient désormais le plancher sur '
              'fond sombre, le témoin ne prouve plus rien.');
      expect(peint[kZChatCapabilityPoem], isNot(violet),
          reason: '🔴 la teinte du poème est peinte BRUTE sur fond sombre : '
              'le défaut ④ de la CR est reproduit, du côté sombre.');
      for (final MapEntry<String, Color?> e in peint.entries) {
        expect(_ratio(e.value!, sombre), greaterThanOrEqualTo(3.0),
            reason: '🔴 `${e.key}` est peint sous le plancher sur fond '
                'sombre.');
      }
    });
  });

  // ── Tranche 2 — L'ANIMATION D'OCCUPATION ────────────────────────────────

  group('🔴 CR84-B1 — l\'occupation s\'anime PAR ARTEFACT (défaut ③)', () {
    testWidgets('deux artefacts, UN SEUL occupé ⇒ seul le sien s\'anime — et '
        'le voisin garde EXACTEMENT sa teinte d\'état', (
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
                key: 'occupe',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                accent: _darkA,
                busy: (ZChatMessage _) => true,
              ),
              ZChatArtifactSpec(
                key: 'calme',
                icon: _iconB,
                label: 'Flashcards',
                presence: (ZChatMessage _) => true,
                accent: _darkB,
                // 🔴 La MÊME lecture est déclarée ici : ce qui distingue les
                // deux glyphes n'est pas la présence d'un canal d'occupation,
                // c'est SA VALEUR. C'est exactement la forme du défaut ③.
                busy: (ZChatMessage _) => false,
              ),
            ],
          ),
        ),
      );
      final Color? occupeT0 = _glyphColor(tester, _iconA);
      final Color? calmeT0 = _glyphColor(tester, _iconB);
      expect(
        calmeT0,
        _darkB,
        reason: '🔴 le voisin ne porte plus SA teinte d\'état au repos',
      );
      expect(
        occupeT0,
        isNot(calmeT0),
        reason: '🔴 l\'occupation ne se distingue pas du repos',
      );
      await tester.pump(const Duration(milliseconds: 700));
      final Color? occupeT1 = _glyphColor(tester, _iconA);
      final Color? calmeT1 = _glyphColor(tester, _iconB);
      expect(
        occupeT1,
        isNot(occupeT0),
        reason:
            '🔴 le glyphe OCCUPÉ ne s\'anime pas : l\'occupation est lue, '
            'annoncée, et jamais rendue',
      );
      expect(
        calmeT1,
        calmeT0,
        reason:
            '🔴 L\'OCCUPATION A DÉBORDÉ SUR LE VOISIN — c\'est le défaut '
            '③ de CR-IFFD-84, mesuré chez l\'hôte : « l\'occupation animait '
            'les sept glyphes faute d\'être indexée par artefact »',
      );
      expect(
        calmeT1,
        _darkB,
        reason:
            '🔴 le voisin a perdu sa teinte d\'état pendant que l\'autre '
            's\'animait',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('l\'occupation PRIME sur la teinte d\'état, et la rend dès '
        'qu\'elle retombe', (WidgetTester tester) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      Widget build({required bool busy}) => harness(
        ZChatNotebookView(
          controller: rig.controller,
          artifacts: <ZChatArtifactSpec>[
            ZChatArtifactSpec(
              key: 'occupe',
              icon: _iconA,
              label: 'Carte mentale',
              presence: (ZChatMessage _) => true,
              accent: _darkA,
              busy: (ZChatMessage _) => busy,
            ),
          ],
        ),
      );
      await tester.pumpWidget(build(busy: true));
      expect(
        _glyphColor(tester, _iconA),
        isNot(_darkA),
        reason:
            '🔴 la teinte d\'état a gagné sur l\'occupation : le legacy '
            'fait l\'inverse (`animationColor ?? présence`)',
      );
      await tester.pumpWidget(build(busy: false));
      expect(
        _glyphColor(tester, _iconA),
        _darkA,
        reason:
            '🔴 la teinte d\'état n\'est pas revenue quand la génération '
            's\'est terminée',
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('un artefact ABSENT et SANS verbe est quand même rendu s\'il '
        'est occupé', (WidgetTester tester) async {
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
                key: 'occupe',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => false,
                busy: (ZChatMessage _) => true,
              ),
            ],
          ),
        ),
      );
      expect(
        find.byType(Icon),
        findsOneWidget,
        reason:
            '🔴 une génération EN COURS est annoncée sur un glyphe que '
            'personne ne voit',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('🔴 CR84-B2 — « Réduire les animations » : rien ne bouge, l\'état '
      'RESTE', () {
    testWidgets('préférence active ⇒ AUCUNE animation, ET l\'occupation reste '
        'annoncée ET peinte', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          _reduceMotion(
            ZChatNotebookView(
              controller: rig.controller,
              artifacts: <ZChatArtifactSpec>[
                ZChatArtifactSpec(
                  key: 'occupe',
                  icon: _iconA,
                  label: 'Carte mentale',
                  presence: (ZChatMessage _) => true,
                  accent: _darkA,
                  busy: (ZChatMessage _) => true,
                  actions: <ZChatArtifactAction>[
                    ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason:
            '🔴 « Réduire les animations » est actif et le cycle tourne '
            'quand même (AD-13)',
      );
      final Color? fige = _glyphColor(tester, _iconA);
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        _glyphColor(tester, _iconA),
        fige,
        reason:
            '🔴 la teinte bouge encore : ce n\'est pas une animation '
            'supprimée, c\'est une animation de durée nulle qui bat toujours',
      );
      // 🔴 ET l'état RESTE : un état qui disparaît quand on réduit les
      // animations est un défaut d'accessibilité, pas une simplification.
      expect(
        fige,
        isNot(_darkA),
        reason:
            '🔴 l\'occupation est devenue INVISIBLE sous « Réduire les '
            'animations » : le glyphe est indiscernable d\'un artefact au '
            'repos',
      );
      final SemanticsNode? node = findSemantics(
        tester,
        (SemanticsNode n) => n.label == 'Carte mentale',
      );
      expect(node, isNotNull);
      expect(
        node!.value,
        contains(_fb(kZChatLabelArtifactBusy)),
        reason:
            '🔴 l\'occupation n\'est plus ANNONCÉE : le seul canal qui '
            'survivait à la réduction des animations a disparu',
      );
      handle.dispose();
    });
  });

  group('🔴 CR84-B3 — AD-2 : l\'animation ne reconstruit NI la vue NI les '
      'voisins', () {
    testWidgets('20 frames d\'animation : COMPTES ABSOLUS de constructions '
        'inchangés', (WidgetTester tester) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      int slotBuilds = 0;
      int lecturesVoisin = 0;
      int lecturesOccupe = 0;
      Widget build() => harness(
        ZChatNotebookView(
          controller: rig.controller,
          // Le créneau de l'hôte : la sonde « la VUE a-t-elle été
          // reconstruite ? ».
          actionsBuilder: (BuildContext context, ZChatMessage m) {
            slotBuilds++;
            return const SizedBox(height: 8);
          },
          artifacts: <ZChatArtifactSpec>[
            ZChatArtifactSpec(
              key: 'occupe',
              icon: _iconA,
              label: 'Carte mentale',
              // Chaque lecture d'état est appelée DANS `build` : les compter
              // mesure exactement le nombre de reconstructions du bouton.
              presence: (ZChatMessage _) {
                lecturesOccupe++;
                return true;
              },
              busy: (ZChatMessage _) => true,
            ),
            ZChatArtifactSpec(
              key: 'voisin',
              icon: _iconB,
              label: 'Flashcards',
              presence: (ZChatMessage _) {
                lecturesVoisin++;
                return true;
              },
              accent: _darkB,
            ),
          ],
        ),
      );
      await tester.pumpWidget(build());
      final int slot0 = slotBuilds;
      final int voisin0 = lecturesVoisin;
      final int occupe0 = lecturesOccupe;
      expect(slot0, greaterThan(0), reason: 'non-vacuité de la sonde');
      expect(voisin0, greaterThan(0), reason: 'non-vacuité de la sonde');
      final Color? avant = _glyphColor(tester, _iconA);
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(
        _glyphColor(tester, _iconA),
        isNot(avant),
        reason:
            '🔴 GARDE VACUELLE : rien ne s\'est animé, les comptes ne '
            'prouvent donc rien',
      );
      expect(
        slotBuilds,
        slot0,
        reason:
            '🔴 COMPTE ABSOLU : l\'animation reconstruit la VUE — 20 '
            'frames ont suffi à rejouer le créneau de l\'hôte',
      );
      expect(
        lecturesVoisin,
        voisin0,
        reason: '🔴 COMPTE ABSOLU : l\'animation reconstruit le glyphe VOISIN',
      );
      expect(
        lecturesOccupe,
        occupe0,
        reason:
            '🔴 COMPTE ABSOLU : l\'animation reconstruit son PROPRE '
            'bouton — le cycle n\'est pas scellé sur le glyphe',
      );
      // 🔴 NON-VACUITÉ DES SONDES : trois compteurs qui ne bougent JAMAIS
      // prouveraient la granularité aussi bien qu'une sonde débranchée. Un
      // vrai rebuild de la vue doit les faire monter, tous les trois.
      await tester.pumpWidget(build());
      expect(
        slotBuilds,
        greaterThan(slot0),
        reason:
            '🔴 SONDE INERTE : le créneau de l\'hôte ne bouge même pas '
            'quand la vue est réellement reconstruite',
      );
      expect(lecturesVoisin, greaterThan(voisin0));
      expect(lecturesOccupe, greaterThan(occupe0));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('🔴 CR84-B4 — cycle de vie : rien ne tourne au repos', () {
    testWidgets('aucun artefact occupé ⇒ AUCUN contrôleur ; l\'occupation '
        'l\'arme, sa fin le libère, le démontage aussi', (
      WidgetTester tester,
    ) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      Widget build({required bool busy}) => harness(
        ZChatNotebookView(
          controller: rig.controller,
          artifacts: <ZChatArtifactSpec>[
            ZChatArtifactSpec(
              key: 'a',
              icon: _iconA,
              label: 'Carte mentale',
              presence: (ZChatMessage _) => true,
              busy: (ZChatMessage _) => busy,
            ),
            ZChatArtifactSpec(
              key: 'b',
              icon: _iconB,
              label: 'Flashcards',
              presence: (ZChatMessage _) => true,
              busy: (ZChatMessage _) => false,
            ),
          ],
        ),
      );
      await tester.pumpWidget(build(busy: false));
      expect(
        find.byType(ZColorCycle),
        findsNWidgets(2),
        reason: 'les deux artefacts DÉCLARENT une lecture d\'occupation',
      );
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason:
            '🔴 une animation tourne alors que RIEN n\'est occupé : un '
            'écran au repos qui vide la batterie, et rien ne le signalerait',
      );
      await tester.pumpWidget(build(busy: true));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(build(busy: false));
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: '🔴 le contrôleur tourne encore après la fin de la génération',
      );
      await tester.pumpWidget(build(busy: true));
      // 🔴 Démontage sous animation : sans `dispose`, `flutter_test` échoue
      // ici sur « A Ticker was started and never stopped ».
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('🔴 CR84-B5 — contre-témoin : SANS lecture d\'occupation, RIEN ne '
      'change', () {
    testWidgets('aucune lecture déclarée ⇒ comptes ABSOLUS : aucun cycle, '
        'aucune animation, la teinte d\'état inchangée', (
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
                key: 'sans',
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                accent: _darkA,
              ),
            ],
          ),
        ),
      );
      expect(
        find.byType(ZColorCycle),
        findsNothing,
        reason:
            '🔴 un cycle a été monté chez un hôte qui n\'a déclaré AUCUNE '
            'occupation : la livraison n\'est plus additive',
      );
      expect(find.byType(Icon), findsOneWidget);
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason:
            '🔴 une animation tourne sans qu\'aucune occupation ait été '
            'déclarée',
      );
      expect(
        _glyphColor(tester, _iconA),
        _darkA,
        reason: '🔴 la teinte d\'état d\'un hôte passif a changé',
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(_glyphColor(tester, _iconA), _darkA);
    });
  });

  group('🔴 CR84-B6 — la teinte d\'occupation vient de `busyPalette`', () {
    testWidgets('sans réglage, la palette de RÉFÉRENCE est consommée — la '
        'table que personne ne lisait', (WidgetTester tester) async {
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
                busy: (ZChatMessage _) => true,
              ),
            ],
          ),
        ),
      );
      // La référence ouvre sur le BLEU du legacy et passe au ROUGE au premier
      // segment. La garde ne recalcule pas la correction de contraste (ce
      // serait tautologique) : elle mesure la DOMINANTE, que l'assombrissement
      // préserve.
      expect(ZChatNotebookReference.busyPalette.first, const Color(0xFF2196F3));
      expect(ZChatNotebookReference.busyPalette[1], const Color(0xFFF44336));
      final Color? debut = _glyphColor(tester, _iconA);
      expect(debut, isNotNull);
      expect(
        debut!.b > debut.r && debut.b > debut.g,
        isTrue,
        reason:
            '🔴 le cycle ne démarre pas sur le BLEU de `busyPalette` — '
            'mesuré : $debut',
      );
      // Un septième de cycle (2 s / 7 teintes) : la deuxième teinte, le rouge.
      await tester.pump(const Duration(microseconds: 2000000 ~/ 7));
      final Color? segment = _glyphColor(tester, _iconA);
      expect(segment, isNotNull);
      expect(
        segment!.r > segment.b && segment.r > segment.g,
        isTrue,
        reason:
            '🔴 le deuxième segment n\'est pas le ROUGE de `busyPalette` : '
            'la séquence lue n\'est pas celle de la référence — mesuré : '
            '$segment',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('le PARAMÈTRE du skin bat la référence', (
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
            skin: const ZChatNotebookSkin(busyPalette: <Color>[_darkA, _darkB]),
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: kZChatCapabilityMindmap,
                icon: _iconA,
                label: 'Carte mentale',
                presence: (ZChatMessage _) => true,
                busy: (ZChatMessage _) => true,
              ),
            ],
          ),
        ),
      );
      expect(
        _glyphColor(tester, _iconA),
        _darkA,
        reason:
            '🔴 la palette du SKIN n\'est pas consultée : la surcharge '
            'annoncée par `ZChatNotebookSkin.busyPalette` est décorative',
      );
      // Mi-cycle d'une palette de deux teintes : exactement la seconde.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(
        _glyphColor(tester, _iconA),
        _darkB,
        reason: '🔴 la palette du skin n\'est parcourue qu\'à moitié',
      );
      await tester.pumpWidget(const SizedBox.shrink());
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
