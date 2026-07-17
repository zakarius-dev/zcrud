// Tests de `ZFlashcardListView` (SU-8/AC1, AC3, AC8, AC14-AC17, AC19-AC21).
//
// 🔴 Discipline « présence ≠ association » : chaque contrôle est **ACTIONNÉ**,
// jamais seulement trouvé (su-4 : un bouton « précédent » qui AVANÇAIT, vert car
// jamais tapé).
//
// 🔴 Discipline « un test ne doit pas observer qu'UN canal » : le rendu ET la
// sémantique sont assérés (su-6 : un nombre visible NULLE PART mais annoncé au
// lecteur d'écran, test vert).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
// `ZAdaptiveGrid` n'est PAS ré-exporté par `zcrud_study` (le consommateur importe
// `zcrud_responsive` directement) — le test l'importe donc, comme le ferait une
// app. Un ré-export de confort serait une 2e surface à maintenir.
import 'package:zcrud_responsive/zcrud_responsive.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

const _labels = ZFlashcardListLabels(
  searchHint: 'Rechercher',
  searchFieldLabel: 'Champ de recherche',
  emptyState: 'Aucune carte',
  noResults: 'Aucun résultat',
  actionsMenuTooltip: 'Actions',
  openAction: 'Ouvrir',
  editAction: 'Modifier',
  deleteAction: 'Supprimer',
  duplicateAction: 'Dupliquer',
  moveUpAction: 'Monter',
  moveDownAction: 'Descendre',
  generateWithAiAction: 'Générer avec IA',  readOnlyBadge: 'Lecture seule',
);

ZFlashcard _card(
  String id, {
  String? question,
  String? answer,
  bool isReadOnly = false,
  List<String> tagIds = const <String>[],
  ZFlashcardSource? source,
  List<ZChoice>? choices,
  DateTime? createdAt,
}) =>
    ZFlashcard(
      id: id,
      question: question ?? 'Question $id',
      answer: answer,
      isReadOnly: isReadOnly,
      tagIds: tagIds,
      source: source,
      choices: choices,
      createdAt: createdAt,
    );

Widget _harness(
  Widget child, {
  TextDirection textDirection = TextDirection.ltr,
  Brightness brightness = Brightness.light,
  Size size = const Size(1200, 800),
}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Directionality(
        textDirection: textDirection,
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    );

/// Ouvre le menu d'actions de la première tuile et rend les libellés VISIBLES.
Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(ZItemActionsMenu).first);
  await tester.pumpAndSettle();
}

/// Label sémantique **FUSIONNÉ** de toute la liste (ce que le lecteur d'écran
/// annonce réellement).
///
/// ⚠️ `container: true` **fusionne** les labels des descendants en UN nœud :
/// `find.bySemanticsLabel('X')` (match EXACT) ne le trouve donc jamais. On lit
/// l'arbre réel — vérifié en le dumpant, pas supposé.
String _mergedSemantics(WidgetTester tester) =>
    tester.semantics.find(find.byType(ZFlashcardListView)).toStringDeep();

/// Nombre d'occurrences de [needle] dans les labels sémantiques réels.
int _semanticsCount(WidgetTester tester, String needle) =>
    RegExp(RegExp.escape(needle)).allMatches(_mergedSemantics(tester)).length;

void main() {
  group('🔴 AC1/NFR-SU9 — grille responsive VIRTUALISÉE via ZAdaptiveGrid', () {
    testWidgets('la grille est un ZAdaptiveGrid (jamais une grille réécrite)',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1'), _card('c2')],
        labels: _labels,
      )));
      await tester.pump();

      expect(find.byType(ZAdaptiveGrid), findsOneWidget,
          reason: '🔴 l\'AC exige « responsive via ZAdaptiveGrid, jamais une '
              'grille réécrite »');
    });

    testWidgets('🔴 des MILLIERS de cartes : seul le viewport est construit',
        (tester) async {
      final cards = List<ZFlashcard>.generate(2000, (i) => _card('c$i'));

      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: cards,
        labels: _labels,
      )));
      await tester.pump();

      // Compte les tuiles RÉELLEMENT construites (sonde de virtualisation).
      final built = find.byType(ZItemActionsMenu).evaluate().length;
      expect(built, greaterThan(0),
          reason: 'sonde cassée : aucune tuile construite ⇒ rien n\'est mesuré');
      expect(built, lessThan(200),
          reason: '🔴 NFR-SU9 : $built/2000 tuiles construites — la grille '
              'n\'est PAS virtualisée. Avec `children:`, les 2 000 seraient '
              'matérialisées À CHAQUE FRAPPE de recherche');
    });

    testWidgets('AC19 — 2 000 cartes : aucun throw, la liste rend', (tester) async {
      final cards = List<ZFlashcard>.generate(2000, (i) => _card('c$i'));
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: cards,
        labels: _labels,
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(ZAdaptiveGrid), findsOneWidget);
    });
  });

  group('AC3 — tuile compacte : question, type, tags, source, aperçu réponse', () {
    testWidgets('tous les éléments de la tuile sont RENDUS', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[
          _card('c1',
              question: 'Le noyau atomique',
              answer: 'Protons et neutrons',
              tagIds: const <String>['physique'],
              source: ZCustomSource('pdf', const <String, dynamic>{})),
        ],
        labels: _labels,
      )));
      await tester.pump();

      expect(find.text('Le noyau atomique'), findsOneWidget,
          reason: 'la question');
      expect(find.text('openQuestion'), findsOneWidget, reason: 'le badge type');
      expect(find.text('physique'), findsOneWidget, reason: 'les tags');
      expect(find.text('pdf'), findsOneWidget, reason: 'la source');
      expect(find.text('Protons et neutrons'), findsOneWidget,
          reason: '🔴 l\'aperçu de la réponse — EN GRILLE (AC3)');
    });

    testWidgets('🔴 aperçu QCM : le choix CORRECT (une carte QCM n\'a pas d\'answer)',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[
          _card('c1', choices: const <ZChoice>[
            ZChoice(content: 'Mauvaise réponse'),
            ZChoice(content: 'La bonne réponse', isCorrect: true),
          ]),
        ],
        labels: _labels,
      )));
      await tester.pump();

      expect(find.text('La bonne réponse'), findsOneWidget,
          reason: '🔴 n\'afficher que `answer` laisserait les QCM SANS aperçu — '
              'le défaut « affiché nulle part »');
      expect(find.text('Mauvaise réponse'), findsNothing);
    });

    testWidgets('tagLabels résout les ids en libellés', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1', tagIds: const <String>['t-42'])],
        labels: _labels,
        tagLabels: const <String, String>{'t-42': 'Physique'},
      )));
      await tester.pump();

      expect(find.text('Physique'), findsOneWidget);
      expect(find.text('t-42'), findsNothing,
          reason: 'l\'id brut ne doit pas fuir dans l\'UI quand un libellé existe');
    });

    testWidgets('AC3/AD-40 — le slot de contenu est CONSOMMÉ quand injecté',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1', question: 'Brut')],
        labels: _labels,
        contentBuilder: (context, text) {
          calls++;
          return Text('RICHE:$text');
        },
      )));
      await tester.pump();

      expect(calls, greaterThan(0),
          reason: '🔴 un slot jamais appelé serait une fonctionnalité MORTE sur '
              'son chemin documenté');
      expect(find.text('RICHE:Brut'), findsOneWidget);
      expect(find.text('Brut'), findsNothing,
          reason: 'le slot REMPLACE le défaut, il ne s\'y ajoute pas');
    });

    testWidgets('AD-40 — défaut = texte BRUT thématisé (aucun rendu riche en dur)',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1', question: '**gras**')],
        labels: _labels,
      )));
      await tester.pump();

      expect(find.text('**gras**'), findsOneWidget,
          reason: 'le défaut ne rend RIEN de riche : les astérisques restent');
    });
  });

  group('🔴 AC14/AD-45 — lecture seule : actions ABSENTES, jamais grisées', () {
    testWidgets('carte isReadOnly : Modifier et Supprimer ABSENTS du menu',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1', isReadOnly: true)],
        labels: _labels,
        onEdit: (_) {},
        onDelete: (_) {},
        onOpen: (_) {},
      )));
      await tester.pump();
      await _openMenu(tester);

      expect(find.text('Modifier'), findsNothing,
          reason: '🔴 AD-45 : ABSENTE, jamais grisée (une action grisée est un '
              'no-op silencieux qui laisse croire à une permission)');
      expect(find.text('Supprimer'), findsNothing);
      expect(find.text('Ouvrir'), findsOneWidget,
          reason: 'consulter une carte partagée reste légitime');
    });

    testWidgets('🔴 carte isReadOnly : DUPLIQUER reste disponible (FR-SU21)',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1', isReadOnly: true)],
        labels: _labels,
        onDuplicate: (_) {},
      )));
      await tester.pump();
      await _openMenu(tester);

      expect(find.text('Dupliquer'), findsOneWidget,
          reason: '🔴 c\'est LA raison d\'être de FR-SU21 : une carte qu\'on ne '
              'peut pas modifier est justement celle qu\'on veut dupliquer');
    });

    testWidgets('carte éditable : Modifier et Supprimer PRÉSENTS', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        onEdit: (_) {},
        onDelete: (_) {},
      )));
      await tester.pump();
      await _openMenu(tester);

      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
    });

    testWidgets('badge de lecture seule : rendu ET annoncé (deux canaux)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1', isReadOnly: true)],
        labels: _labels,
      )));
      await tester.pump();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget,
          reason: 'canal VISUEL');
      expect(_semanticsCount(tester, 'Lecture seule'), 1,
          reason: '🔴 canal A11Y — su-6 : un test qui n\'observe qu\'un canal '
              'laisse passer un état annoncé mais invisible (ou l\'inverse). '
              'Une icône SANS Semantics est muette pour un lecteur d\'écran : '
              'l\'utilisateur ne saurait JAMAIS que la carte est verrouillée');
      handle.dispose();
    });
  });

  group('🔴 AC15/AD-44 — actions déclarées : onSelected null ⇒ ABSENTE', () {
    testWidgets('aucun callback ⇒ toutes les actions métier absentes',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
      )));
      await tester.pump();
      await _openMenu(tester);

      for (final label in <String>['Ouvrir', 'Modifier', 'Supprimer', 'Dupliquer']) {
        expect(find.text(label), findsNothing,
            reason: '« $label » sans callback doit être ABSENTE');
      }
    });

    testWidgets('🔴 Ouvrir est ACTIONNÉ et reçoit LA BONNE carte', (tester) async {
      ZFlashcard? opened;
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1', question: 'La cible')],
        labels: _labels,
        onOpen: (c) => opened = c,
      )));
      await tester.pump();
      await _openMenu(tester);
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      expect(opened, isNotNull,
          reason: '🔴 présence ≠ association : le contrôle doit être ACTIONNÉ');
      expect(opened!.id, 'c1');
      expect(opened!.question, 'La cible');
    });

    testWidgets('🔴 Supprimer est ACTIONNÉ (et ne fait pas autre chose)',
        (tester) async {
      ZFlashcard? deleted;
      ZFlashcard? edited;
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        onDelete: (c) => deleted = c,
        onEdit: (c) => edited = c,
      )));
      await tester.pump();
      await _openMenu(tester);
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(deleted?.id, 'c1');
      expect(edited, isNull,
          reason: '🔴 su-4 : un bouton câblé sur la MAUVAISE action est vert '
              'tant qu\'on n\'assère pas que l\'AUTRE n\'a pas été appelée');
    });
  });

  group('🔴 AC13/FR-SU21 — duplication depuis le menu', () {
    testWidgets('🔴 Dupliquer est ACTIONNÉ et livre une copie ÉPHÉMÈRE',
        (tester) async {
      ZFlashcard? duplicated;
      final original = _card('c1', question: 'À copier', isReadOnly: true);

      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[original],
        labels: _labels,
        onDuplicate: (c) => duplicated = c,
      )));
      await tester.pump();
      await _openMenu(tester);
      await tester.tap(find.text('Dupliquer'));
      await tester.pumpAndSettle();

      expect(duplicated, isNotNull, reason: 'le contrôle doit être ACTIONNÉ');
      expect(duplicated!.id, isNull,
          reason: '🔴 la vue livre bien la COPIE (id null), pas l\'original — '
              'un id copié ferait ÉCRASER la carte partagée au commit');
      expect(duplicated!.isReadOnly, isFalse, reason: '🔴 copie ÉDITABLE');
      expect(duplicated!.question, 'À copier', reason: 'le contenu est copié');
      expect(original.isReadOnly, isTrue,
          reason: '🔴 l\'original n\'est JAMAIS muté');
      expect(original.id, 'c1');
    });
  });

  group('🔴 AC16 — « Générer avec l\'IA » ABSENTE sans port (par COMPOSITION)', () {
    testWidgets('🔴 aucun port ⇒ option ABSENTE, saisie manuelle intacte',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        onOpen: (_) {},
        // onGenerateWithAi ABSENT — su-8 ne livre AUCUN flux (su-9).
      )));
      await tester.pump();
      await _openMenu(tester);

      expect(find.text('Générer avec IA'), findsNothing,
          reason: '🔴 ABSENTE, jamais grisée');
      expect(find.text('Ouvrir'), findsOneWidget,
          reason: '🔴 la saisie manuelle RESTE disponible — l\'absence de l\'IA '
              'ne doit rien amputer d\'autre');
    });

    testWidgets('port fourni + feature disponible ⇒ option PRÉSENTE et ACTIONNÉE',
        (tester) async {
      var called = 0;
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        onGenerateWithAi: () => called++,
      )));
      await tester.pump();
      await _openMenu(tester);

      expect(find.text('Générer avec IA'), findsOneWidget);
      await tester.tap(find.text('Générer avec IA'));
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets(
      '🔴 port fourni MAIS feature indisponible ⇒ ABSENTE (ZFeatureAvailability)',
      (tester) async {
        await tester.pumpWidget(_harness(ZFlashcardListView(
          cards: <ZFlashcard>[_card('c1')],
          labels: _labels,
          onGenerateWithAi: () {},
          aiAvailability: const ZMapFeatureAvailability(
            <String, bool>{kFlashcardAiGenerationFeature: false},
          ),
        )));
        await tester.pump();
        await _openMenu(tester);

        expect(find.text('Générer avec IA'), findsNothing,
            reason: '🔴 `gate` fabrique le `null` que `onSelected` consomme '
                'DÉJÀ — jamais un `if (kEnableAi)` ni un booléen local');
      },
    );

    testWidgets('la disponibilité se lit sur le SCOPE ambiant si non passée',
        (tester) async {
      await tester.pumpWidget(_harness(
        ZFeatureAvailabilityScope(
          availability: const ZMapFeatureAvailability(
            <String, bool>{kFlashcardAiGenerationFeature: false},
          ),
          child: ZFlashcardListView(
            cards: <ZFlashcard>[_card('c1')],
            labels: _labels,
            onGenerateWithAi: () {},
          ),
        ),
      ));
      await tester.pump();
      await _openMenu(tester);

      expect(find.text('Générer avec IA'), findsNothing,
          reason: 'injection Flutter-native par InheritedWidget (AD-2/AD-15)');
    });
  });

  group('🔴 AC11 — boutons a11y : MÊME voie que le drag, réellement ACTIONNÉS', () {
    final cards = <ZFlashcard>[_card('a'), _card('b'), _card('c')];

    testWidgets('🔴 Monter REMONTE réellement (et persiste le bon ordre)',
        (tester) async {
      ZFolderContentsOrder? persisted;
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: cards,
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: const ZFolderContentsOrder(folderId: 'f'),
        onOrderChanged: (o) => persisted = o,
      )));
      await tester.pump();

      // Menu de la 2e tuile (« b »).
      await tester.tap(find.byType(ZItemActionsMenu).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monter'));
      await tester.pumpAndSettle();

      expect(persisted, isNotNull, reason: 'le bouton doit être ACTIONNÉ');
      expect(persisted!.orderFor(zFlashcardsSectionKey()), <String>['b', 'a', 'c'],
          reason: '🔴 « b » passe AVANT « a ». Un bouton câblé à l\'envers '
              'serait VERT si l\'on n\'assérait que « l\'ordre a changé »');
    });

    testWidgets('🔴 Descendre DESCEND réellement', (tester) async {
      ZFolderContentsOrder? persisted;
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: cards,
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: const ZFolderContentsOrder(folderId: 'f'),
        onOrderChanged: (o) => persisted = o,
      )));
      await tester.pump();

      await tester.tap(find.byType(ZItemActionsMenu).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descendre'));
      await tester.pumpAndSettle();

      expect(persisted!.orderFor(zFlashcardsSectionKey()), <String>['a', 'c', 'b']);
    });

    testWidgets('🔴 le PREMIER n\'a PAS de bouton Monter', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: cards,
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: const ZFolderContentsOrder(folderId: 'f'),
        onOrderChanged: (_) {},
      )));
      await tester.pump();

      await tester.tap(find.byType(ZItemActionsMenu).first);
      await tester.pumpAndSettle();

      expect(find.text('Monter'), findsNothing,
          reason: '🔴 ABSENT (null), jamais un no-op silencieux');
      expect(find.text('Descendre'), findsOneWidget,
          reason: 'sonde : le 1er PEUT descendre — sinon « rien n\'est rendu » '
              'passerait pour « le bouton est bien absent »');
    });

    testWidgets('🔴 le DERNIER n\'a PAS de bouton Descendre', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: cards,
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: const ZFolderContentsOrder(folderId: 'f'),
        onOrderChanged: (_) {},
      )));
      await tester.pump();

      await tester.tap(find.byType(ZItemActionsMenu).at(2));
      await tester.pumpAndSettle();

      expect(find.text('Descendre'), findsNothing);
      expect(find.text('Monter'), findsOneWidget, reason: 'sonde');
    });

    testWidgets('sans onOrderChanged ⇒ AUCUN bouton de réordonnancement',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: cards,
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: const ZFolderContentsOrder(folderId: 'f'),
      )));
      await tester.pump();
      await _openMenu(tester);

      expect(find.text('Monter'), findsNothing);
      expect(find.text('Descendre'), findsNothing,
          reason: 'réordonner sans persister = fonctionnalité MORTE (l\'ordre '
              'sauterait au prochain rebuild) ⇒ mieux vaut ABSENTE');
    });

    testWidgets('mode NON manuel ⇒ aucun bouton de réordonnancement', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: cards,
        labels: _labels,
        sortMode: ZFlashcardSortMode.dateDesc,
        order: const ZFolderContentsOrder(folderId: 'f'),
        onOrderChanged: (_) {},
      )));
      await tester.pump();
      await _openMenu(tester);

      expect(find.text('Monter'), findsNothing,
          reason: 'réordonner à la main sous un tri par date serait aussitôt '
              'écrasé par le tri');
    });
  });

  group('🔴 AC8/AD-38 — tri et ordre manuel appliqués au RENDU', () {
    testWidgets('mode manuel : l\'ordre PERSISTÉ pilote l\'affichage', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('a'), _card('b'), _card('c')],
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: ZFolderContentsOrder(
          folderId: 'f',
          sectionOrders: <String, List<String>>{
            'flashcards': <String>['c', 'a', 'b'],
          },
        ),
        onOrderChanged: (_) {},
      )));
      await tester.pump();

      // Assère l'ordre RENDU (pas seulement la clé) : `applyOrder` étant TOTAL,
      // une clé fautive rendrait l'ordre d'entrée SANS lever.
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((t) => t != null && t.startsWith('Question '))
          .toList();
      expect(texts, <String>['Question c', 'Question a', 'Question b'],
          reason: '🔴 l\'ordre personnel doit piloter le RENDU RÉEL');
    });

    testWidgets('mode manuel : une carte NEUVE est appendée en fin (AC12)',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('neuve'), _card('a'), _card('b')],
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: ZFolderContentsOrder(
          folderId: 'f',
          sectionOrders: <String, List<String>>{
            'flashcards': <String>['b', 'a'],
          },
        ),
        onOrderChanged: (_) {},
      )));
      await tester.pump();

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((t) => t != null && t.startsWith('Question '))
          .toList();
      expect(texts, <String>['Question b', 'Question a', 'Question neuve'],
          reason: '🔴 la carte neuve est APPENDÉE, jamais perdue');
    });

    testWidgets('tri par date décroissante appliqué au rendu', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[
          _card('vieux', createdAt: DateTime.utc(2020)),
          _card('recent', createdAt: DateTime.utc(2023)),
        ],
        labels: _labels,
        sortMode: ZFlashcardSortMode.dateDesc,
      )));
      await tester.pump();

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((t) => t != null && t.startsWith('Question '))
          .toList();
      expect(texts.first, 'Question recent');
    });
  });

  group('🔴 AC19/AD-10 — robustesse : le CONTENU rendu, pas juste « aucun throw »', () {
    testWidgets('dossier VIDE ⇒ message « aucune carte » RENDU', (tester) async {
      await tester.pumpWidget(_harness(const ZFlashcardListView(
        cards: <ZFlashcard>[],
        labels: _labels,
      )));
      await tester.pump();

      expect(find.text('Aucune carte'), findsOneWidget,
          reason: '🔴 su-7 : `takeException() isNull` ne vérifie PAS la '
              'justesse — on assère le CONTENU');
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 recherche sans résultat ⇒ « aucun RÉSULTAT » (≠ « aucune carte »)',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1', question: 'Physique')],
        labels: _labels,
        filters: const ZFlashcardBrowseFilters(query: 'introuvable-zzz'),
      )));
      await tester.pump();

      expect(find.text('Aucun résultat'), findsOneWidget,
          reason: '🔴 « aucune carte » et « aucun résultat » appellent deux '
              'gestes différents (créer / élargir) — les confondre égare');
      expect(find.text('Aucune carte'), findsNothing);
    });

    testWidgets('UNE SEULE carte', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('seule', question: 'Unique')],
        labels: _labels,
      )));
      await tester.pump();
      expect(find.text('Unique'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('carte SANS id (éphémère) ⇒ rendue, aucun throw', (tester) async {
      await tester.pumpWidget(_harness(const ZFlashcardListView(
        cards: <ZFlashcard>[ZFlashcard(question: 'Éphémère')],
        labels: _labels,
      )));
      await tester.pump();
      expect(find.text('Éphémère'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clé de section INCONNUE ⇒ ordre d\'entrée, aucun throw',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('a'), _card('b')],
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        subfolderId: 'sous-dossier-jamais-vu',
        order: const ZFolderContentsOrder(folderId: 'f'),
        onOrderChanged: (_) {},
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Question a'), findsOneWidget);
    });

    testWidgets('ordre PÉRIMÉ (orphelins) ⇒ cohérent, aucune carte perdue',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('a'), _card('b')],
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: ZFolderContentsOrder(
          folderId: 'f',
          sectionOrders: <String, List<String>>{
            'flashcards': <String>['supprimee', 'b', 'fantome', 'a'],
          },
        ),
        onOrderChanged: (_) {},
      )));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((t) => t != null && t.startsWith('Question '))
          .toList();
      expect(texts, <String>['Question b', 'Question a'],
          reason: 'orphelins ignorés, aucune carte réelle perdue');
    });

    testWidgets('tags VIDES / DUPLIQUÉS ⇒ aucun throw', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[
          _card('a', tagIds: const <String>[]),
          _card('b', tagIds: const <String>['t', 't', 't']),
        ],
        labels: _labels,
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('🔴 AC17 — fonctionne SANS sélection multiple (aucun précâblage)', () {
    testWidgets('consultation, recherche, actions : tout marche sans FR-SU19',
        (tester) async {
      ZFlashcard? opened;
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1'), _card('c2')],
        labels: _labels,
        onOpen: (c) => opened = c,
      )));
      await tester.pump();

      expect(find.byType(ZAdaptiveGrid), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing,
          reason: '🔴 aucun précâblage de sélection (FR-SU19 = me-3)');

      await _openMenu(tester);
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(opened, isNotNull, reason: 'la liste est UTILE sans sélection');
    });
  });

  group('AC20/AD-13 — a11y, RTL, cibles ≥ 48 dp', () {
    testWidgets('🔴 D3 — le champ est annoncé sur son nœud focusable (pas fantôme)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
      )));
      await tester.pump();

      // Le nœud DU champ éditable (focusable, actionnable) — jamais un fantôme.
      final node = tester.getSemantics(find.byType(EditableText));
      expect(
        node,
        containsSemantics(
          label: 'Champ de recherche',
          isTextField: true,
          isFocusable: true,
        ),
        reason: '🔴 D3 : le libellé injecté est porté par le CHAMP (labelText), '
            'jamais par un nœud fantôme parent',
      );
      handle.dispose();
    });

    testWidgets(
      '🔴 la tuile est annoncée par sa question — EXACTEMENT UNE FOIS',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_harness(ZFlashcardListView(
          cards: <ZFlashcard>[_card('c1', question: 'Annoncée')],
          labels: _labels,
        )));
        await tester.pump();

        // Canal A11Y : la question EST annoncée…
        expect(_semanticsCount(tester, 'Annoncée'), 1,
            reason: '🔴 DEUX défauts opposés, une seule assertion :\n'
                '  • 0 ⇒ la carte est MUETTE pour un lecteur d\'écran ;\n'
                '  • 2 ⇒ elle est annoncée DEUX FOIS (le piège réel : un '
                '`label:` explicite sur un `Semantics(container: true)` '
                'S\'AJOUTE aux labels fusionnés des enfants au lieu de les '
                'remplacer — constaté en dumpant l\'arbre réel).');

        // …et le canal VISUEL la rend, une seule fois aussi.
        expect(find.text('Annoncée'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('le badge de type est annoncé (et non muet)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
      )));
      await tester.pump();

      expect(_semanticsCount(tester, 'openQuestion'), 1);
      handle.dispose();
    });

    testWidgets('champ de recherche : cible ≥ 48 dp', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
      )));
      await tester.pump();

      final size = tester.getSize(find.byKey(ZFlashcardListView.searchFieldKey));
      expect(size.height, greaterThanOrEqualTo(48.0),
          reason: 'AD-13/NFR-S6 : cible tap minimale');
    });

    testWidgets('RTL : rend sans throw et sans débordement', (tester) async {
      await tester.pumpWidget(_harness(
        ZFlashcardListView(
          cards: <ZFlashcard>[
            _card('c1', question: 'سؤال', tagIds: const <String>['وسم']),
          ],
          labels: _labels,
        ),
        textDirection: TextDirection.rtl,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'aucun RenderFlex overflow en RTL');
      expect(find.text('سؤال'), findsOneWidget);
    });

    testWidgets('étroit (mobile) : rend sans débordement', (tester) async {
      await tester.pumpWidget(_harness(
        ZFlashcardListView(
          cards: <ZFlashcard>[
            _card('c1',
                question: 'Une question très longue qui doit être tronquée '
                    'proprement sans jamais déborder de sa tuile',
                answer: 'Une réponse également très longue à tronquer',
                tagIds: const <String>['tag-un', 'tag-deux', 'tag-trois']),
          ],
          labels: _labels,
        ),
        size: const Size(360, 640),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: '🔴 su-2 : un débordement RenderFlex avait été MASQUÉ en '
              'modifiant le test — ici on assère le rendu réel en 360 dp');
    });
  });

  group('🔴 D2/AC20 — type & source : libellés INJECTÉS (jamais la clé brute)', () {
    testWidgets('typeLabels/sourceLabels traduisent ⇒ la clé Dart DISPARAÎT',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[
          _card('c1', source: ZCustomSource('pdf', const <String, dynamic>{})),
        ],
        labels: _labels,
        typeLabels: const <String, String>{'openQuestion': 'Question ouverte'},
        sourceLabels: const <String, String>{'pdf': 'Document PDF'},
      )));
      await tester.pump();

      expect(find.text('Question ouverte'), findsOneWidget,
          reason: 'le badge de type est LOCALISÉ via le slot injecté');
      expect(find.text('Document PDF'), findsOneWidget,
          reason: 'la source est LOCALISÉE via le slot injecté');
      expect(find.text('openQuestion'), findsNothing,
          reason: '🔴 D2 : « openQuestion » est un identifiant Dart écrit pour un '
              'dev — il ne doit JAMAIS atteindre l\'utilisateur quand un libellé '
              'est injecté (c\'était le 1er mot annoncé sur chaque carte)');
      expect(find.text('pdf'), findsNothing,
          reason: '🔴 D2 : la clé de source brute ne fuit plus');
    });

    testWidgets('sans injection ⇒ repli sur la clé opaque (patron tagLabels)',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[
          _card('c1', source: ZCustomSource('pdf', const <String, dynamic>{})),
        ],
        labels: _labels,
      )));
      await tester.pump();

      expect(find.text('openQuestion'), findsOneWidget,
          reason: 'repli sur la clé (identique au repli `tagLabels?[id] ?? id`)');
      expect(find.text('pdf'), findsOneWidget);
    });
  });

  group('🔴 D1 (HIGH) — réordonner sous filtre NE DÉTRUIT PAS l\'ordre masqué', () {
    final cards = <ZFlashcard>[
      _card('a', question: 'Alpha'),
      _card('b', question: 'Beta'),
      _card('c', question: 'Alpha gamma'),
    ];

    testWidgets(
        '🔴 recherche active ⇒ drag ET boutons ABSENTS (aucune écriture possible)',
        (tester) async {
      ZFolderContentsOrder? persisted;
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: cards,
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: const ZFolderContentsOrder(folderId: 'f'),
        onOrderChanged: (o) => persisted = o,
        // « alpha » masque « Beta » : réordonner écraserait l'ordre de « b ».
        filters: const ZFlashcardBrowseFilters(query: 'alpha'),
      )));
      await tester.pump();

      expect(find.byType(ReorderableListView), findsNothing,
          reason: '🔴 D1 : drag DÉSACTIVÉ sous filtre de contenu — sinon '
              'zReorderFlashcards remplacerait la section par les 2 seules '
              'cartes visibles, effaçant l\'ordre de « b » (masquée)');

      await tester.tap(find.byType(ZItemActionsMenu).first);
      await tester.pumpAndSettle();
      expect(find.text('Monter'), findsNothing);
      expect(find.text('Descendre'), findsNothing,
          reason: '🔴 D1 : boutons a11y ABSENTS aussi (les deux voies)');

      expect(persisted, isNull,
          reason: '🔴 D1 : aucune écriture possible ⇒ l\'ordre des cartes non '
              'visibles est PRÉSERVÉ (perte de données évitée)');
    });

    testWidgets('🔴 filtre de TAGS actif ⇒ réordonnancement ABSENT', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[
          _card('a', tagIds: const <String>['keep']),
          _card('b', tagIds: const <String>['other']),
        ],
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: const ZFolderContentsOrder(folderId: 'f'),
        onOrderChanged: (_) {},
        // Le sélecteur masque « b » (tag « other ») — filtre de CONTENU.
        selector: const ZStudySessionSelector(
          ZStudySessionConfig(tagIds: <String>['keep']),
        ),
      )));
      await tester.pump();

      expect(find.byType(ReorderableListView), findsNothing);
      await tester.tap(find.byType(ZItemActionsMenu).first);
      await tester.pumpAndSettle();
      expect(find.text('Monter'), findsNothing);
      expect(find.text('Descendre'), findsNothing,
          reason: '🔴 D1 : un filtre de TAGS masque aussi des cartes ⇒ pas de '
              'réordonnancement destructeur, même sans que l\'utilisateur tape');
    });

    testWidgets(
        '🔴 sous-dossier : réordonnancement AUTORISÉ, autres sections PRÉSERVÉES',
        (tester) async {
      ZFolderContentsOrder? persisted;
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('s1'), _card('s2')],
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        subfolderId: 'sub1',
        order: ZFolderContentsOrder(
          folderId: 'f',
          sectionOrders: <String, List<String>>{
            // Ordre de la RACINE (autre section) — DOIT survivre.
            'flashcards': <String>['r1', 'r2'],
          },
        ),
        onOrderChanged: (o) => persisted = o,
      )));
      await tester.pump();

      // Le sous-dossier scope la CLÉ (`flashcards/sub1`) ⇒ ce n'est PAS un
      // filtre de contenu : réordonner reste possible ET sûr.
      await tester.tap(find.byType(ZItemActionsMenu).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monter'));
      await tester.pumpAndSettle();

      expect(persisted, isNotNull,
          reason: '🔴 D1 : réordonner un sous-dossier reste AUTORISÉ');
      expect(persisted!.sectionOrders['flashcards/sub1'], <String>['s2', 's1'],
          reason: 'l\'ordre du sous-dossier est écrit sous SA clé');
      expect(persisted!.sectionOrders['flashcards'], <String>['r1', 'r2'],
          reason: '🔴 D1 : l\'ordre de la RACINE (non visible ici) est PRÉSERVÉ '
              '— la clé scopée l\'isole, aucune perte');
    });
  });

  group('🔴 R3 — carte ÉPHÉMÈRE (id==null) ⇒ réordonnancement DÉSACTIVÉ', () {
    // Une duplication non persistée (`id == null`) fait DIVERGER l'espace
    // d'indices de la liste affichée de celui des ids persistables : un drag
    // déplacerait SILENCIEUSEMENT la mauvaise carte (mesuré). Le garde le rend
    // ABSENT (patron D1/AD-44), filet défensif AD-10/AD-2.
    const ephemeral = ZFlashcard(question: 'Éphémère'); // id == null

    testWidgets(
        '🔴 une carte sans id visible ⇒ drag ET boutons ABSENTS, aucune écriture',
        (tester) async {
      ZFolderContentsOrder? persisted;
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('a'), ephemeral, _card('b')],
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: const ZFolderContentsOrder(folderId: 'f'),
        onOrderChanged: (o) => persisted = o,
      )));
      await tester.pump();

      expect(find.byType(ReorderableListView), findsNothing,
          reason: '🔴 R3 : drag DÉSACTIVÉ tant qu\'une carte sans id est '
              'visible — sinon un glisser déplacerait la MAUVAISE carte '
              '(indices de `visible` ≠ indices des `visibleIds` persistables)');

      await tester.tap(find.byType(ZItemActionsMenu).first);
      await tester.pumpAndSettle();
      expect(find.text('Monter'), findsNothing);
      expect(find.text('Descendre'), findsNothing,
          reason: '🔴 R3 : boutons a11y ABSENTS aussi (les deux voies)');

      expect(persisted, isNull,
          reason: '🔴 R3 : aucune voie d\'écriture ⇒ pas de réordonnancement '
              'incohérent sur un espace d\'indices divergent');
    });

    testWidgets(
        '🔴 contrôle : SANS carte éphémère, le réordonnancement est PRÉSENT',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('a'), _card('b')],
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: const ZFolderContentsOrder(folderId: 'f'),
        onOrderChanged: (_) {},
      )));
      await tester.pump();

      // Prouve que R3 désactive à cause de l'ÉPHÉMÈRE, PAS d'autre chose : le
      // même montage sans carte sans id garde le drag. (Neutraliser le garde
      // `!visible.any((c) => c.id == null)` ⇒ le 1er test passe RED, celui-ci
      // reste vert : falsifiabilité.)
      expect(find.byType(ReorderableListView), findsOneWidget,
          reason: '🔴 R3 : le garde ne vise QUE la carte éphémère — sinon il '
              'casserait le réordonnancement nominal');
    });
  });

  group('🔴 F2/AC11 — le DRAG est réellement ACTIONNÉ (indices, référentiel)', () {
    testWidgets('🔴 glisser (onReorderItem) persiste le bon ordre (littéral)',
        (tester) async {
      ZFolderContentsOrder? persisted;
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('a'), _card('b'), _card('c')],
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: const ZFolderContentsOrder(folderId: 'f'),
        onOrderChanged: (o) => persisted = o,
      )));
      await tester.pump();

      // 🔴 On ACTIONNE le callback du SDK (patron z_study_tools_reorder_test) :
      // c'est le SEUL test qui prouve « la voie du drag est correctement câblée »
      // (la garde de voie unique prouve « pas de 2e voie », pas « la voie est
      // juste »). Sans lui, des indices inversés restaient 334/334 verts (F2).
      final rlv =
          tester.widget<ReorderableListView>(find.byType(ReorderableListView));
      rlv.onReorderItem!(0, 2); // glisse « a » (index 0) vers l'index 2.
      await tester.pumpAndSettle();

      expect(persisted, isNotNull, reason: '🔴 le drag doit être ACTIONNÉ');
      // Littéral (jamais comparé à zReorderFlashcards ⇒ pas de tautologie).
      expect(persisted!.orderFor(zFlashcardsSectionKey()), <String>['b', 'c', 'a'],
          reason: '🔴 F2 : « a » glissé en position 2 ⇒ [b, c, a]. Des indices '
              'INVERSÉS donneraient [c, a, b] : le drag ferait l\'INVERSE du '
              'geste, en silence, `applyOrder` étant TOTAL');
    });
  });

  group('🔴 D5 — filters.query est une prop VIVANTE (didUpdateWidget)', () {
    Widget build(String q) => _harness(ZFlashcardListView(
          cards: <ZFlashcard>[
            _card('a', question: 'Physique'),
            _card('b', question: 'Histoire'),
          ],
          labels: _labels,
          filters: ZFlashcardBrowseFilters(query: q),
        ));

    testWidgets('🔴 le parent pousse une nouvelle query ⇒ elle est APPLIQUÉE',
        (tester) async {
      await tester.pumpWidget(build(''));
      await tester.pump();
      expect(find.text('Physique'), findsOneWidget);
      expect(find.text('Histoire'), findsOneWidget,
          reason: 'au montage, rien n\'est filtré');

      // Le parent pousse query='physique' (deep-link, filtre restauré, puce).
      await tester.pumpWidget(build('physique'));
      await tester.pump();

      expect(find.text('Physique'), findsOneWidget);
      expect(find.text('Histoire'), findsNothing,
          reason: '🔴 D5 : la query poussée est VIVANTE. Avant, elle était GELÉE '
              'au montage et ignorée en silence, alors que `searchFields`/'
              '`sources` étaient vivants — un filtre à moitié appliqué');

      final field = tester
          .widget<TextField>(find.byKey(ZFlashcardListView.searchFieldKey));
      expect(field.controller?.text, 'physique',
          reason: '🔴 le champ REFLÈTE la query poussée (pas un champ vide)');

      // Draine le débounce armé par la resynchronisation (aucun Timer pendant).
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('resynchronisation UNIQUEMENT sur changement réel (pas chaque build)',
        (tester) async {
      await tester.pumpWidget(build('physique'));
      await tester.pump(const Duration(milliseconds: 400));

      // L'utilisateur affine la saisie DANS le champ (le parent ne repousse rien).
      await tester.enterText(
          find.byKey(ZFlashcardListView.searchFieldKey), 'physique quantique');
      await tester.pump(const Duration(milliseconds: 400));

      // Un rebuild du parent AVEC LA MÊME query prop ne doit PAS écraser la
      // saisie en cours (sinon AD-2 : ré-injection qui casse focus/sélection).
      await tester.pumpWidget(build('physique'));
      await tester.pump();
      final field = tester
          .widget<TextField>(find.byKey(ZFlashcardListView.searchFieldKey));
      expect(field.controller?.text, 'physique quantique',
          reason: '🔴 D5/AD-2 : la prop inchangée ne réécrase pas la saisie '
              'utilisateur (resync seulement sur changement RÉEL de la prop)');
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  });
}
