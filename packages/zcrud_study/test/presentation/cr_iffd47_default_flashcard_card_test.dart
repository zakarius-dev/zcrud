/// **CR-IFFD-47** — une carte d'étude PAR DÉFAUT, et la voie TYPÉE qui porte
/// les données.
///
/// 🔴 **Ce que ces gardes mesurent, et l'angle mort qu'elles visent.**
///
/// 1. **La forme demandée par l'hôte était impossible.** « Rendre `itemBuilder`
///    facultatif » ne pouvait produire aucun rendu : `ZStudyToolsSectionSpec`
///    porte `itemCount` + `itemBuilder(context, index)` et **aucune donnée**.
///    La garde de non-régression ne se contente donc pas de vérifier qu'un hôte
///    existant marche : elle **verrouille dans la SOURCE** le fait
///    qu'`itemBuilder` reste `required` — un rendu de test resterait vert si
///    quelqu'un le rendait facultatif demain avec un repli, alors que c'est
///    exactement le changement à empêcher.
///
/// 2. **La hauteur, pas la présence.** Une garde « le widget est dans l'arbre »
///    aurait été verte pendant que la carte mesurait **854 dp** au lieu de
///    ~120 : deux `Align` sans `heightFactor` remplissaient toute la hauteur
///    disponible. Les gardes de layout assertent donc des **dp mesurés** dans
///    une colonne à hauteur NON BORNÉE — le seul régime où ce défaut se voit.
///
/// 3. **Le rail étroit n'est pas la grille large.** Mesuré, pas supposé : la
///    surface de test est élargie par `tester.view.physicalSize` (sinon un
///    `SizedBox` plus large que 800 dp y est écrasé et la mesure ment).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Énoncé LONG — le scénario qui déborde en colonne étroite.
const String kLongQuestion =
    'Expliquez en détail le mécanisme de la valeur transactionnelle en douane, '
    'ses ajustements obligatoires, ses exclusions, et les conditions de son '
    'rejet par le service, en citant les instruments applicables et la '
    'jurisprudence pertinente sur le sujet.';

/// Balises aux titres LONGS — sans elles, la puce ne déborde jamais et la
/// garde de rail serait VACUELLE (elle mesurerait un cas facile).
List<ZFlashcardTag> _longTags([int n = 5]) => <ZFlashcardTag>[
      for (int i = 0; i < n; i++)
        ZFlashcardTag(id: 't$i', title: 'Étiquette de révision numéro $i'),
    ];

ZFlashcard _card({
  String question = 'Qu\'est-ce que la valeur transactionnelle ?',
  ZFlashcardType type = ZFlashcardType.openQuestion,
  String? id = 'c1',
}) =>
    ZFlashcard(id: id, question: question, type: type);

Widget _host(Widget child, {double? width, double? height}) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

/// Élargit la surface de test — **obligatoire** : la vue par défaut fait 800 dp
/// de large, un `SizedBox` plus large y serait écrasé et la mesure mentirait.
void _wideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Color? _accentColor(WidgetTester tester) => tester
    .widget<ColoredBox>(
      find.descendant(
        of: find.byKey(ZDefaultFlashcardCard.accentKey),
        matching: find.byType(ColoredBox),
      ),
    )
    .color;

/// Couleur de fond RÉELLEMENT peinte sous [key] — la clé peut être portée par
/// la boîte elle-même ou par son enveloppe de taille : on descend jusqu'au
/// `DecoratedBox`, jamais une intention déclarée.
Color? _boxColor(WidgetTester tester, Key key) {
  final Finder box = find.byKey(key).evaluate().single.widget is DecoratedBox
      ? find.byKey(key)
      : find.descendant(of: find.byKey(key), matching: find.byType(DecoratedBox));
  return (tester.widget<DecoratedBox>(box).decoration as BoxDecoration).color;
}

Color? _textColor(WidgetTester tester, Key key) =>
    (tester.renderObject(find.byKey(key)) as RenderParagraph).text.style?.color;

/// Racine du dépôt, quel que soit le CWD (ancrage `melos.yaml`, jamais un `../`).
Directory _repoRoot() {
  Directory dir = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Racine du dépôt (melos.yaml) introuvable depuis ${Directory.current}');
}

/// Extrait la liste de paramètres du constructeur PRINCIPAL (`const <Type>({`)
/// — `null` si absent (la sonde échoue alors bruyamment, jamais « conforme »).
String? zPrimaryCtorOf(String source, String type) {
  final int start = source.indexOf('const $type({');
  if (start < 0) return null;
  final int end = source.indexOf('})', start);
  if (end < 0) return null;
  return source.substring(start, end);
}

/// Le paramètre [name] est-il déclaré `required` dans [ctor] ?
///
/// Tolère tout blanc (retours à la ligne compris) entre `required` et le
/// paramètre : la garde vise la RÈGLE, pas la mise en page.
bool zParamIsRequired(String ctor, String name) =>
    RegExp('required\\s+this\\.$name\\s*,').hasMatch(ctor);

String _sourceOf(String relative) {
  final File f = File('${_repoRoot().path}/packages/zcrud_study/$relative');
  expect(f.existsSync(), isTrue, reason: 'sonde cassée : ${f.path} introuvable');
  return f.readAsStringSync();
}

void main() {
  // -------------------------------------------------------------------------
  group('CR-IFFD-47 §1 — forme portée : les 5 éléments, dans l\'ordre de lecture',
      () {
    testWidgets('accent → pastille · balises → énoncé → puce de type',
        (WidgetTester tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(
          card: _card(question: kLongQuestion),
          typeLabels: const <String, String>{'openQuestion': 'Question ouverte'},
          tags: _longTags(3),
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();

      final double cardTop =
          tester.getTopLeft(find.byType(ZDefaultFlashcardCard)).dy;
      final Offset accent =
          tester.getTopLeft(find.byKey(ZDefaultFlashcardCard.accentKey));
      final Offset dot =
          tester.getTopLeft(find.byKey(ZDefaultFlashcardCard.typeDotKey));
      final Offset tags =
          tester.getTopLeft(find.byKey(ZDefaultFlashcardCard.tagsKey));
      final Offset question = tester.getTopLeft(find.text(kLongQuestion));
      final Offset chip =
          tester.getTopLeft(find.byKey(ZDefaultFlashcardCard.typeChipKey));

      // ① l'accent est bien EN TÊTE de la carte (pas un décor perdu au milieu).
      expect(accent.dy, cardTop,
          reason: '🔴 l\'accent doit coiffer la carte (élément ①).');
      // ② puis ③ — même ligne, dans le sens de lecture (directionnel).
      expect(dot.dx, lessThan(tags.dx),
          reason: '🔴 la pastille de type précède la zone de balises (② → ③).');
      // ② et ③ sont AU-DESSUS de l'énoncé…
      expect(dot.dy, lessThan(question.dy),
          reason: '🔴 la pastille (②) doit précéder l\'énoncé (④).');
      expect(tags.dy, lessThan(question.dy),
          reason: '🔴 les balises (③) doivent précéder l\'énoncé (④).');
      // …et ⑤ est bien EN PIED.
      expect(question.dy, lessThan(chip.dy),
          reason: '🔴 la puce de type (⑤) est en PIED, après l\'énoncé (④).');
    });

    testWidgets('④ l\'énoncé est tronqué sur 2-3 lignes (jamais déroulé)',
        (WidgetTester tester) async {
      _wideSurface(tester);
      for (final int maxLines in <int>[2, 3]) {
        await tester.pumpWidget(_host(
          ZDefaultFlashcardCard(
            card: _card(question: kLongQuestion),
            questionMaxLines: maxLines,
          ),
          width: 300,
        ));
        await tester.pumpAndSettle();
        final Text text = tester.widget<Text>(find.text(kLongQuestion));
        expect(text.maxLines, maxLines);
        expect(text.overflow, TextOverflow.ellipsis,
            reason: '🔴 « tronqué proprement » = ellipse, pas un texte coupé.');
      }
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-47 §2 — AD-13 : la couleur n\'est JAMAIS le seul canal', () {
    testWidgets('le type est redit EN TEXTE en pied, avec le premier plan APPARIÉ',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(
          card: _card(),
          typeLabels: const <String, String>{'openQuestion': 'Question ouverte'},
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();

      // Le libellé de type est RENDU, en toutes lettres.
      expect(find.text('Question ouverte'), findsOneWidget);

      // 🔴 NON-VACUITÉ : la couleur du texte de pied doit être le premier plan
      // APPARIÉ au fond réellement peint — pas la couleur ambiante. Sans ce
      // contrôle, l'assertion passerait par hasard si les deux coïncidaient.
      final Color? chipBg =
          _boxColor(tester, ZDefaultFlashcardCard.typeChipKey);
      final Color? labelFg =
          _textColor(tester, ZDefaultFlashcardCard.typeLabelKey);
      expect(chipBg, isNotNull);
      expect(labelFg, isNotNull);
      expect(labelFg, isNot(chipBg),
          reason: '🔴 un premier plan égal au fond serait ILLISIBLE.');

      final ColorScheme scheme =
          Theme.of(tester.element(find.byType(ZDefaultFlashcardCard)))
              .colorScheme;
      expect(labelFg, isNot(scheme.onSurface),
          reason: '🔴 garde VACUELLE : le premier plan mesuré vaut la couleur '
              'AMBIANTE — elle ne prouverait alors rien de l\'appariement.');
    });

    testWidgets('la pastille de tête est MUETTE (l\'info est déjà dite en pied)',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(
          card: _card(),
          typeLabels: const <String, String>{'openQuestion': 'Question ouverte'},
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();

      // La pastille EXISTE visuellement…
      expect(find.byKey(ZDefaultFlashcardCard.typeDotKey), findsOneWidget);

      // 🔴 **La bonne PROPRIÉTÉ, pas la commode.** La première rédaction de
      // cette garde cherchait un `Semantics` *descendant* de la pastille —
      // or une annonce se pose en ANCÊTRE. Sous l'injection exacte (pastille
      // rendue `Semantics(label:)`), elle restait VERTE : elle mesurait bien,
      // mais à côté. Ce qui compte n'est pas « où est le nœud » mais **combien
      // de fois le type est annoncé** : une seule, par la puce de pied.
      expect(find.bySemanticsLabel('Question ouverte'), findsOneWidget,
          reason: '🔴 le type doit être annoncé UNE SEULE fois. La pastille '
              'de tête est le doublon COLORÉ de la puce de pied : l\'annoncer '
              'la ferait entendre deux fois.');
      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-47 §3 — accent DÉRIVÉ d\'une clé stable (jamais un hex)', () {
    testWidgets('même type ⇒ même accent (déterministe, cartes différentes)',
        (WidgetTester tester) async {
      final List<Color?> seen = <Color?>[];
      for (final ZFlashcard card in <ZFlashcard>[
        _card(id: 'a', question: 'Première'),
        _card(id: 'b', question: 'Seconde'),
      ]) {
        await tester.pumpWidget(
            _host(ZDefaultFlashcardCard(card: card), width: 400));
        await tester.pumpAndSettle();
        seen.add(_accentColor(tester));
      }
      expect(seen.first, isNotNull);
      expect(seen[1], seen.first,
          reason: '🔴 l\'accent doit dériver d\'une clé STABLE (le type), pas '
              'de l\'identité ni de l\'ordre de rendu.');
    });

    testWidgets('une clé INJECTÉE prime et vient du ColorScheme (aucun hex)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(card: _card(), colorKey: 'tertiary'),
        width: 400,
      ));
      await tester.pumpAndSettle();
      final ColorScheme scheme =
          Theme.of(tester.element(find.byType(ZDefaultFlashcardCard)))
              .colorScheme;

      expect(_accentColor(tester), scheme.tertiaryContainer,
          reason: '🔴 la couleur doit être DÉRIVÉE du ColorScheme.');
      // 🔴 NON-VACUITÉ : `tertiaryContainer` doit se DISTINGUER de la surface,
      // sinon « l\'accent est peint » serait indiscernable de « rien n\'est peint ».
      expect(scheme.tertiaryContainer, isNot(scheme.surface));
      // …et se distinguer de l\'accent DÉRIVÉ du type, sinon l\'injection ne
      // prouverait pas qu\'elle a primé.
      await tester.pumpWidget(
          _host(ZDefaultFlashcardCard(card: _card()), width: 400));
      await tester.pumpAndSettle();
      expect(_accentColor(tester), isNot(scheme.tertiaryContainer),
          reason: '🔴 garde VACUELLE : l\'accent dérivé du type vaut déjà la '
              'clé injectée — l\'injection ne prouverait rien.');
    });

    testWidgets('la pastille de tête porte le MÊME accent que la barre',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          _host(ZDefaultFlashcardCard(card: _card()), width: 400));
      await tester.pumpAndSettle();
      expect(_boxColor(tester, ZDefaultFlashcardCard.typeDotKey),
          _accentColor(tester));
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-47 §4 — FR-26 : aucun libellé en dur', () {
    testWidgets('libellé de type INJECTÉ ; à défaut, la CLÉ OPAQUE',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(
          card: _card(type: ZFlashcardType.multipleChoice),
          typeLabels: const <String, String>{'multipleChoice': 'QCM'},
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();
      expect(find.text('QCM'), findsOneWidget);
      expect(find.text('multipleChoice'), findsNothing);

      // Sans injection : la clé OPAQUE, jamais une traduction en dur.
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(card: _card(type: ZFlashcardType.multipleChoice)),
        width: 400,
      ));
      await tester.pumpAndSettle();
      expect(find.text('multipleChoice'), findsOneWidget);
      expect(find.text('QCM'), findsNothing,
          reason: '🔴 le socle ne traduit JAMAIS en dur (FR-26/NFR-S7).');
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-47 §5 — zone de balises : affichée MÊME VIDE (AD-4)', () {
    testWidgets('aucune balise + aucun libellé ⇒ zone ABSENTE de l\'arbre',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          _host(ZDefaultFlashcardCard(card: _card()), width: 400));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultFlashcardCard.tagsKey), findsNothing);
      expect(find.byKey(ZDefaultFlashcardCard.emptyTagsKey), findsNothing);
      // AD-4 : ABSENT, jamais un `SizedBox.shrink()` inerte.
      expect(find.byType(ZTagChips), findsNothing);
    });

    testWidgets('aucune balise + libellé INJECTÉ ⇒ appel à l\'action',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(
          card: _card(),
          emptyTagsLabel: 'Ajouter des balises',
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Ajouter des balises'), findsOneWidget);
      // Sans action : AD-45 — une invite, pas un bouton inerte.
      expect(
        find.descendant(
          of: find.byKey(ZDefaultFlashcardCard.emptyTagsKey),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('appel à l\'action ACTIONNABLE : bouton ≥ 48 dp, libellé annoncé',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int taps = 0;
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(
          card: _card(),
          emptyTagsLabel: 'Ajouter des balises',
          onTagsTap: () => taps++,
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();

      final Finder inkwell = find.ancestor(
        of: find.byKey(ZDefaultFlashcardCard.emptyTagsKey),
        matching: find.byType(InkWell),
      );
      expect(inkwell, findsOneWidget);
      expect(tester.getSize(inkwell).height,
          greaterThanOrEqualTo(48.0),
          reason: '🔴 AD-13 — cible d\'activation ≥ 48 dp.');
      await tester.tap(inkwell);
      expect(taps, 1);
      expect(
        tester.getSemantics(find.ancestor(
          of: find.byKey(ZDefaultFlashcardCard.emptyTagsKey),
          matching: find.byType(Semantics).first,
        )),
        isNotNull,
      );
      handle.dispose();
    });

    testWidgets('balises présentes ⇒ ZTagChips RÉUTILISÉ (aucune rangée réécrite)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(card: _card(), tags: _longTags(2)),
        width: 500,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ZTagChips), findsOneWidget);
      // …et l'appel à l'action cède la place (il ne se cumule pas).
      expect(find.byKey(ZDefaultFlashcardCard.emptyTagsKey), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-47 §6 — les ACTIONS restent à l\'hôte, par créneaux', () {
    testWidgets('ni tap ni appui long ⇒ AUCUN InkWell (AD-45)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
          _host(ZDefaultFlashcardCard(card: _card()), width: 400));
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsNothing,
          reason: '🔴 AD-45 : l\'absence d\'activation est STRUCTURELLE — '
              'jamais un InkWell inerte.');
    });

    testWidgets('appui long SEUL ⇒ activable, et ANNONCÉ au lecteur d\'écran',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int longs = 0;
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(card: _card(), onLongPress: () => longs++),
        width: 400,
      ));
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(ZDefaultFlashcardCard));
      expect(longs, 1, reason: '🔴 l\'appui long doit RÉELLEMENT déclencher.');

      // 🔴 L'`InkWell` est exclu de la sémantique : sans déclaration sur le
      // nœud de la carte, le geste serait INATTEIGNABLE au lecteur d'écran.
      final SemanticsNode node =
          tester.getSemantics(find.byType(ZStudyToolsItemCard));
      expect(node.getSemanticsData().hasAction(SemanticsAction.longPress),
          isTrue,
          reason: '🔴 AD-13 — un appui long non déclaré est inatteignable.');
      handle.dispose();
    });

    testWidgets('le créneau d\'actions est rendu VERBATIM', (tester) async {
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(
          card: _card(),
          trailing: const Icon(Icons.more_vert, key: ValueKey<String>('menu')),
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('menu')), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-47 §7 — la voie TYPÉE porte les données', () {
    test('`.flashcards` dérive itemCount des cartes fournies', () {
      final spec = ZStudyToolsSectionSpec.flashcards(
        id: 'flashcards',
        title: 'Cartes',
        cards: <ZFlashcard>[_card(id: 'a'), _card(id: 'b'), _card(id: 'c')],
        emptyState: const SizedBox.shrink(),
      );
      expect(spec.itemCount, 3);
      // ⚠️ Le réordonnancement N'EST PAS proposé par cette voie (cf. dartdoc) :
      // une carte éphémère ferait diverger les espaces d'indices.
      expect(spec.onReorder, isNull);
      expect(spec.itemIds, isNull);
    });

    testWidgets('`.flashcards` rend la carte par défaut du socle, carte par carte',
        (WidgetTester tester) async {
      _wideSurface(tester);
      final spec = ZStudyToolsSectionSpec.flashcards(
        id: 'flashcards',
        title: 'Cartes',
        cards: <ZFlashcard>[
          _card(id: 'a', question: 'Énoncé A'),
          _card(id: 'b', question: 'Énoncé B'),
        ],
        emptyState: const SizedBox.shrink(),
        typeLabels: const <String, String>{'openQuestion': 'Question ouverte'},
      );

      await tester.pumpWidget(_host(
        Column(
          children: <Widget>[
            for (int i = 0; i < spec.itemCount; i++)
              Builder(builder: (BuildContext c) => spec.itemBuilder(c, i)),
          ],
        ),
        width: 600,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ZDefaultFlashcardCard), findsNWidgets(2));
      expect(find.text('Énoncé A'), findsOneWidget);
      expect(find.text('Énoncé B'), findsOneWidget);
      // Clé STABLE par carte (AD-2) : l'identité suit la carte, pas la position.
      expect(
        find.byKey(const ValueKey<String>('zDefaultFlashcardCard-a')),
        findsOneWidget,
      );
    });

    testWidgets('les créneaux d\'actions sont filés PAR CARTE',
        (WidgetTester tester) async {
      _wideSurface(tester);
      final List<String> opened = <String>[];
      final spec = ZStudyToolsSectionSpec.flashcards(
        id: 'flashcards',
        title: 'Cartes',
        cards: <ZFlashcard>[_card(id: 'a'), _card(id: 'b', question: 'B')],
        emptyState: const SizedBox.shrink(),
        onCardTap: (ZFlashcard c) => opened.add(c.id ?? ''),
      );
      await tester.pumpWidget(_host(
        Builder(builder: (BuildContext c) => spec.itemBuilder(c, 1)),
        width: 600,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ZDefaultFlashcardCard));
      expect(opened, <String>['b'],
          reason: '🔴 le créneau doit recevoir LA carte de l\'index rendu — '
              'un builder qui refermerait sur la mauvaise carte passerait '
              'inaperçu avec une seule carte.');
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-47 §8 — MESURE 1 : coût NUL pour un hôte qui fournit déjà '
      'son itemBuilder', () {
    test('🔴 `itemBuilder` reste REQUIS dans le constructeur principal', () {
      final String src = _sourceOf(
          'lib/src/presentation/z_study_tools_section_spec.dart');
      final String? ctor = zPrimaryCtorOf(src, 'ZStudyToolsSectionSpec');
      expect(ctor, isNotNull,
          reason: 'sonde cassée : constructeur principal introuvable');

      expect(zParamIsRequired(ctor!, 'itemBuilder'), isTrue,
          reason: '🔴 RÉGRESSION INTERDITE : rendre `itemBuilder` facultatif '
              'ouvrirait une branche de repli — or le descripteur ne PORTE '
              'aucune donnée et ne saurait rendre quoi que ce soit. La voie '
              'des données est `ZStudyToolsSectionSpec.flashcards(cards:)`.');
      expect(zParamIsRequired(ctor, 'itemCount'), isTrue);
    });

    // 🔴 CONTRE-PREUVES — le scanner RÉEL n'est ni aveugle ni fragile.
    //
    // Pourquoi elles remplacent une réinjection en source : la régression
    // exacte (« `itemBuilder` cesse d'être requis ») **ne compile pas** dans ce
    // dépôt — des dizaines de sites passent `itemBuilder:` en argument nommé,
    // et un rouge de COMPILATION ne prouve rien (il ne dit pas que la garde
    // mord, seulement que le code ne se construit plus). La mordance est donc
    // prouvée sur l'ENTRÉE du scanner, avec le motif exact de la régression.
    test('le scanner attrape un paramètre devenu FACULTATIF', () {
      const String regressed = '''
  const ZStudyToolsSectionSpec({
    required this.id,
    this.itemBuilder = _zNoItem,
    required this.emptyState,
  });''';
      final String? ctor = zPrimaryCtorOf(regressed, 'ZStudyToolsSectionSpec');
      expect(ctor, isNotNull);
      expect(zParamIsRequired(ctor!, 'itemBuilder'), isFalse,
          reason: '🔴 scanner AVEUGLE : la régression exacte passerait.');
      expect(zParamIsRequired(ctor, 'id'), isTrue);
    });

    test('le scanner n\'est pas FRAGILE au formatage (pas de faux positif)', () {
      const String reformatted = '''
  const ZStudyToolsSectionSpec({
    required
        this.itemBuilder,
  });''';
      final String? ctor = zPrimaryCtorOf(reformatted, 'ZStudyToolsSectionSpec');
      expect(zParamIsRequired(ctor!, 'itemBuilder'), isTrue,
          reason: '🔴 une garde qui rougit sur un simple retour à la ligne est '
              'une garde qu\'on finit par désactiver.');
    });

    test('le scanner ÉCHOUE BRUYAMMENT si le constructeur a disparu', () {
      expect(zPrimaryCtorOf('class X { const X(); }', 'ZStudyToolsSectionSpec'),
          isNull,
          reason: '🔴 une sonde qui rend « conforme » sur une source qu\'elle '
              'n\'a pas trouvée est pire qu\'aucune sonde.');
    });

    testWidgets('un hôte qui fournit son itemBuilder ne voit RIEN du socle',
        (WidgetTester tester) async {
      _wideSurface(tester);
      final spec = ZStudyToolsSectionSpec(
        id: 'docs',
        title: 'Documents',
        itemCount: 2,
        emptyState: const SizedBox.shrink(),
        itemBuilder: (BuildContext context, int index) =>
            Text('item-$index', key: ValueKey<String>('host-$index')),
      );
      await tester.pumpWidget(_host(
        Column(
          children: <Widget>[
            for (int i = 0; i < spec.itemCount; i++)
              Builder(builder: (BuildContext c) => spec.itemBuilder(c, i)),
          ],
        ),
        width: 600,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('host-0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('host-1')), findsOneWidget);
      // 🔴 AUCUNE injection du socle dans le rendu de l'hôte : ni carte par
      // défaut, ni puce de type, ni zone de balises.
      expect(find.byType(ZDefaultFlashcardCard), findsNothing);
      expect(find.byKey(ZDefaultFlashcardCard.typeChipKey), findsNothing);
      expect(find.byType(ZTagChips), findsNothing);
    });

    testWidgets('slot `aboveTitle` non fourni ⇒ arbre et espacement INCHANGÉS',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(title: 'Cours de chimie'),
        width: 400,
      ));
      await tester.pumpAndSettle();
      final Size withoutSlot = tester.getSize(find.byType(ZStudyToolsItemCard));

      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(
          title: 'Cours de chimie',
          aboveTitle: SizedBox(height: 20, key: ValueKey<String>('above')),
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();
      final Size withSlot = tester.getSize(find.byType(ZStudyToolsItemCard));

      expect(find.byKey(const ValueKey<String>('above')), findsOneWidget);
      expect(withSlot.height, greaterThan(withoutSlot.height),
          reason: '🔴 garde VACUELLE sinon : si le slot ne coûtait rien en '
              'hauteur NON BORNÉE, c\'est qu\'il ne serait pas rendu.');
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-47 §9 — MESURE 2 : rail ÉTROIT contraint vs grille LARGE', () {
    testWidgets('rail 300 dp : aucun débordement, hauteur BORNÉE',
        (WidgetTester tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(
          card: _card(question: kLongQuestion),
          tags: _longTags(),
          typeLabels: const <String, String>{'openQuestion': 'Question ouverte'},
        ),
        width: 300,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: '🔴 un énoncé long dans une carte étroite ne doit RIEN faire '
              'déborder (mesuré : la puce de balise débordait de 21 px).');

      // 🔴 Hauteur MESURÉE en colonne NON BORNÉE — le seul régime où un `Align`
      // sans `heightFactor` se voit (854 dp mesurés avant correction).
      final double h = tester.getSize(find.byType(ZDefaultFlashcardCard)).height;
      expect(h, lessThan(400.0),
          reason: '🔴 la carte doit se dimensionner à son CONTENU. Un `Align` '
              'sans `heightFactor` remplit toute la hauteur disponible : la '
              'carte mesurait alors 854 dp au lieu de ~264.');
      expect(h, greaterThan(100.0),
          reason: '🔴 garde VACUELLE sinon : une carte quasi vide passerait.');
    });

    testWidgets('grille à largeur LIBRE : plus large ⇒ plus BASSE (jamais l\'inverse)',
        (WidgetTester tester) async {
      _wideSurface(tester);
      final List<double> heights = <double>[];
      for (final double w in <double>[300, 800, 1200]) {
        await tester.pumpWidget(_host(
          ZDefaultFlashcardCard(
            card: _card(question: kLongQuestion),
            tags: _longTags(),
          ),
          width: w,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'largeur $w dp');
        heights.add(tester.getSize(find.byType(ZDefaultFlashcardCard)).height);
      }
      // MESURÉ (5 balises à titre long + énoncé long) : 300 dp ⇒ 264 dp de
      // haut, 800 dp ⇒ 264 dp (les puces tiennent déjà sur le même nombre de
      // lignes), 1200 dp ⇒ 232 dp. La propriété assérée est donc la MONOTONIE
      // — « jamais plus haut quand c'est plus large » — et non une décroissance
      // stricte, qui serait FAUSSE et rendrait la garde fragile.
      expect(heights[1], lessThanOrEqualTo(heights[0]),
          reason: '🔴 mesuré : 300 dp ⇒ ${heights[0]} dp de haut, '
              '800 dp ⇒ ${heights[1]} dp, 1200 dp ⇒ ${heights[2]} dp.');
      expect(heights[2], lessThanOrEqualTo(heights[1]));
      expect(heights[2], lessThan(heights[0]),
          reason: '🔴 garde VACUELLE sinon : si la largeur ne changeait RIEN à '
              'la hauteur, c\'est que l\'énoncé ne se remettrait pas en page.');
    });

    testWidgets('cellule de rail à HAUTEUR FIXE : les slots CÈDENT, la carte ne '
        'déborde pas', (WidgetTester tester) async {
      _wideSurface(tester);
      for (final double h in <double>[120, 150, 180, 210]) {
        await tester.pumpWidget(_host(
          ZDefaultFlashcardCard(
            card: _card(question: kLongQuestion),
            tags: _longTags(),
            typeLabels: const <String, String>{
              'openQuestion': 'Question ouverte',
            },
          ),
          width: 300,
          height: h,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '🔴 cellule 300 × $h dp : une hauteur imposée ne doit pas '
                'produire de `RenderFlex overflowed` (leçon CR-IFFD-37 — le '
                'slot PARTICIPE à la hauteur, il ne s\'y AJOUTE pas).');
        expect(tester.getSize(find.byType(ZDefaultFlashcardCard)).height, h);
      }
    });
  });
}
