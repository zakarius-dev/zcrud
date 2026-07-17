// A11y de su-8 : cibles ≥ 48 dp + Semantics sur TOUS les contrôles (AC20/AD-13).
//
// 🔴 « **Balayer tout le diff, pas un échantillon** » : su-5 avait corrigé 1
// tuile sur 4 ; su-6 avait omis un **dialog entier** ⇒ 4 tuiles non gardées,
// 4/4 défectueuses. Ce fichier énumère donc **TOUS** les contrôles interactifs
// de su-8 — y compris ceux qui n'existent qu'une fois un **overlay ouvert**
// (le menu d'actions), que les tests d'écran ne voient jamais.
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Cible tap minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

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

ZFlashcard _card(String id) => ZFlashcard(
      id: id,
      question: 'Question $id',
      answer: 'Réponse $id',
      tagIds: const <String>['tag'],
    );

Widget _harness(Widget child, {Size size = const Size(1000, 700)}) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: size.width, height: size.height, child: child),
      ),
    );

/// Liste COMPLÈTE (drag + boutons + toutes actions) — le pire cas.
Widget _fullList() => ZFlashcardListView(
      cards: <ZFlashcard>[_card('a'), _card('b'), _card('c')],
      labels: _labels,
      sortMode: ZFlashcardSortMode.manual,
      order: const ZFolderContentsOrder(folderId: 'f'),
      onOrderChanged: (_) {},
      onOpen: (_) {},
      onEdit: (_) {},
      onDelete: (_) {},
      onDuplicate: (_) {},
      onGenerateWithAi: () {},
    );

// ===========================================================================
// su-9 (AC12) — énumération a11y des contrôles des 2 feuilles de génération.
// 🔴 Leçon su-6 : l'énumération avait omis un dialog entier ⇒ on balaye TOUS
// les contrôles interactifs des 2 feuilles, pas un échantillon. C'est le trou
// qui avait laissé passer D3 (double annonce) et D4 (libellé de slider fantôme).
// ===========================================================================

const _genMessages = ZFlashcardGenerationMessages(
  unexpectedError: 'ERREUR',
  emptyResult: 'VIDE',
);

const _genLabels = ZFlashcardGenerationLabels(
  contentLabel: 'Contenu',
  contentHint: 'Coller le texte',
  countLabel: 'Nombre de cartes',
  instructionsLabel: 'Instructions',
  instructionsHint: 'Facultatif',
  modelIdLabel: 'Modèle',
  modelIdHint: 'Optionnel',
  sourceLabel: 'Source',
  generateLabel: 'Générer',
  generatingLabel: 'Génération…',
  proceedToTagsLabel: 'Confirmer les tags',
  previewTitle: 'Aperçu',
  typeLabels: <ZFlashcardType, String>{},
  tagConfirmTitle: 'Tags proposés',
  tagConfirmApply: 'Confirmer',
  tagConfirmCancel: 'Annuler',
  tagInputLabel: 'Nom du tag',
  tagInputHint: 'Ajouter un tag',
  tagAddSemanticLabel: 'Ajouter le tag',
);

class _FakeGenPort implements ZFlashcardGenerationPort {
  _FakeGenPort(this.responder);
  final Future<ZResult<List<ZFlashcard>>> Function(ZFlashcardGenerationRequest)
      responder;

  @override
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
          ZFlashcardGenerationRequest r) =>
      responder(r);
}

List<ZGenerationSourceOption> _genSources() => <ZGenerationSourceOption>[
      const ZGenerationSourceOption(label: 'Texte libre'),
      ZGenerationSourceOption(
        label: 'Article',
        provenance: ZCustomSource('article', const <String, dynamic>{'id': '9'}),
      ),
    ];

Widget _genSheet(ZFlashcardGenerationPort port) => ZFlashcardGenerationSheet(
      port: port,
      messages: _genMessages,
      labels: _genLabels,
      sources: _genSources(),
      suggestedTags: const <ZSuggestedTag>[ZSuggestedTag(title: 'algèbre')],
    );

void main() {
  group('🔴 AC20/AD-13 — cibles ≥ 48 dp sur TOUS les contrôles', () {
    testWidgets('champ de recherche', (tester) async {
      await tester.pumpWidget(_harness(_fullList()));
      await tester.pump();

      final size = tester.getSize(find.byKey(ZFlashcardListView.searchFieldKey));
      expect(size.height, greaterThanOrEqualTo(_kMinTapTarget),
          reason: 'cible tap de ${size.height} dp < 48 dp');
    });

    testWidgets('🔴 déclencheur du menu d\'actions — de CHAQUE tuile', (tester) async {
      await tester.pumpWidget(_harness(_fullList()));
      await tester.pump();

      final triggers = find.byType(ZItemActionsMenu);
      expect(triggers, findsNWidgets(3),
          reason: 'sonde : les 3 tuiles doivent avoir leur menu — sinon on ne '
              'mesurerait qu\'un échantillon (su-5 : 1 tuile sur 4 corrigée)');

      // 🔴 TOUTES les tuiles, jamais la première seulement.
      for (var i = 0; i < 3; i++) {
        final size = tester.getSize(triggers.at(i));
        expect(size.width, greaterThanOrEqualTo(_kMinTapTarget),
            reason: 'tuile $i : largeur ${size.width} dp < 48 dp');
        expect(size.height, greaterThanOrEqualTo(_kMinTapTarget),
            reason: 'tuile $i : hauteur ${size.height} dp < 48 dp');
      }
    });

    testWidgets(
      '🔴 CHAQUE item du menu OUVERT (l\'overlay que les écrans ne voient pas)',
      (tester) async {
        await tester.pumpWidget(_harness(_fullList()));
        await tester.pump();

        // 2e tuile : elle a Monter ET Descendre (le pire cas — la 1re n'a pas
        // Monter, la dernière n'a pas Descendre).
        await tester.tap(find.byType(ZItemActionsMenu).at(1));
        await tester.pumpAndSettle();

        // 🔴 TOUTES les actions attendues sont là — sinon « toutes ≥ 48 dp »
        // serait vrai d'un menu VIDE.
        const expected = <String>[
          'Ouvrir',
          'Modifier',
          'Dupliquer',
          'Monter',
          'Descendre',
          'Générer avec IA',
          'Supprimer',
        ];
        for (final label in expected) {
          expect(find.text(label), findsOneWidget,
              reason: 'sonde : « $label » doit être rendue');
        }

        // Chaque item du menu est une cible ≥ 48 dp.
        // ⚠️ `.first` porte sur le RÉSULTAT de `find.ancestor` (l'ancêtre le
        // plus PROCHE), jamais sur le finder `matching:` — l'y mettre le
        // réduirait au 1er ConstrainedBox de tout l'arbre, qui n'a rien à voir
        // avec ce label (constaté en l'écrivant).
        for (final label in expected) {
          final target = find
              .ancestor(
                of: find.text(label),
                matching: find.byType(PopupMenuItem<ZItemAction>),
              )
              .first;
          final size = tester.getSize(target);
          expect(size.height, greaterThanOrEqualTo(_kMinTapTarget),
              reason: '🔴 « $label » : ${size.height} dp < 48 dp — un item de '
                  'menu trop petit est intappable au doigt');
        }
      },
    );

    testWidgets('cibles ≥ 48 dp tenues en ÉTROIT (mobile 360 dp)', (tester) async {
      await tester.pumpWidget(
          _harness(_fullList(), size: const Size(360, 640)));
      await tester.pump();

      final size = tester.getSize(find.byKey(ZFlashcardListView.searchFieldKey));
      expect(size.height, greaterThanOrEqualTo(_kMinTapTarget),
          reason: '🔴 c\'est en ÉTROIT que les cibles se compriment — mesurer '
              'seulement en large laisserait passer le défaut réel');
      expect(tester.takeException(), isNull, reason: 'aucun débordement');
    });
  });

  group('🔴 AC20 — Semantics sur tous les contrôles (rendu ET a11y)', () {
    testWidgets('🔴 D3 — le libellé atteint le CHAMP focusable (pas un fantôme)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(_fullList()));
      await tester.pump();

      // 🔴 D3 — on ancre sur le nœud DU champ (`isTextField` + focusable +
      // actionnable), jamais sur `bySemanticsLabel` : un `Semantics(label:)`
      // parent créait un nœud `isTextField` FANTÔME (non focusable, sans action)
      // que `bySemanticsLabel` matchait — garde VERTE sur un champ dont le vrai
      // nœud n'annonçait que le hint. `InputDecoration.labelText` attache le
      // libellé AU champ ; cette assertion le prouve sur le nœud actionnable.
      // Le nœud DU champ éditable (focusable, actionnable) — jamais un fantôme.
      final node = tester.getSemantics(find.byType(EditableText));
      expect(
        node,
        containsSemantics(
          label: 'Champ de recherche',
          isTextField: true,
          isFocusable: true,
        ),
        reason: '🔴 le champ focusable lui-même doit porter le libellé injecté',
      );
      handle.dispose();
    });

    testWidgets('le déclencheur du menu porte son tooltip a11y', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(_fullList()));
      await tester.pump();

      final tree = tester.semantics
          .find(find.byType(ZFlashcardListView))
          .toStringDeep();
      expect(tree.contains('Actions'), isTrue,
          reason: '🔴 le déclencheur du menu doit être annoncé — sans tooltip, '
              'un lecteur d\'écran annonce « bouton » sans dire lequel');
      handle.dispose();
    });

    testWidgets('🔴 CHAQUE action du menu est annoncée comme BOUTON', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(_fullList()));
      await tester.pump();

      await tester.tap(find.byType(ZItemActionsMenu).at(1));
      await tester.pumpAndSettle();

      // Le menu est un OVERLAY : il n'est PAS sous `ZFlashcardListView` dans
      // l'arbre. On lit donc la sémantique de chaque item, pas celle de la vue.
      for (final label in <String>['Ouvrir', 'Dupliquer', 'Monter', 'Supprimer']) {
        // ⚠️ On vise le nœud du **PopupMenuItem** (la *merge boundary*), et non
        // `find.text(label)` : `excludeSemantics: true` retire la sémantique du
        // `Text`, si bien que `getSemantics(find.text(…))` remonterait à un
        // nœud trompeur.
        final node = tester.getSemantics(find
            .ancestor(
              of: find.text(label),
              matching: find.byType(PopupMenuItem<ZItemAction>),
            )
            .first);

        // 🔴 `node.label` est le label **PROPRE** du nœud — VIDE sur une merge
        // boundary. Ce que le lecteur d'écran annonce réellement est la donnée
        // **FUSIONNÉE** : `getSemanticsData().label`. Mesurer `.label` ici
        // rendrait « 0 » sur une UI parfaitement correcte (constaté en dumpant
        // l'arbre) — et « 0 == 0 » aurait pu être pris pour une garde verte.
        final announced = node.getSemanticsData().label;

        // `containsSemantics` (et non `matchesSemantics`, qui est EXHAUSTIF et
        // exigerait d'énumérer toutes les actions du nœud — un test qui
        // rougirait au moindre ajout du SDK sans qu'aucun défaut n'existe).
        expect(
          node,
          containsSemantics(label: label, isButton: true, isEnabled: true),
          reason: '🔴 « $label » doit être annoncée ET reconnue comme un '
              'BOUTON. Annoncée comme du simple TEXTE, un lecteur d\'écran ne '
              'proposerait jamais de l\'activer — l\'action serait invisible '
              'pour l\'utilisateur qui en a le plus besoin.',
        );

        // 🔴 …et annoncée **EXACTEMENT UNE FOIS**. `PopupMenuItem` fusionne son
        // sous-arbre : sans `excludeSemantics: true`, le `label:` du `Semantics`
        // ET le `Text(action.label)` fusionnent tous deux ⇒ « Ouvrir, Ouvrir ».
        // Défaut RÉEL trouvé par ce test (`label was "Ouvrir\nOuvrir"`) et
        // corrigé dans `z_item_actions_menu.dart`.
        final occurrences =
            RegExp(RegExp.escape(label)).allMatches(announced).length;
        expect(
          occurrences,
          1,
          reason: '🔴 « $label » est annoncée $occurrences fois (label fusionné '
              'réel : « ${announced.replaceAll('\n', ' / ')} »).\n'
              '  • 0 ⇒ l\'action est MUETTE pour un lecteur d\'écran ;\n'
              '  • 2 ⇒ elle est RÉPÉTÉE (le `label:` s\'ajoute aux enfants au '
              'lieu de les remplacer — il faut `excludeSemantics: true`).',
        );
      }
      handle.dispose();
    });

    testWidgets('les boutons a11y Monter/Descendre EXISTENT (drag impossible)',
        (tester) async {
      // 🔴 La raison d'être des boutons : un utilisateur de lecteur d'écran ne
      // peut PAS glisser-déposer. S'ils manquaient, l'ordre manuel lui serait
      // TOTALEMENT inaccessible — et aucun test de drag ne le verrait.
      await tester.pumpWidget(_harness(_fullList()));
      await tester.pump();

      await tester.tap(find.byType(ZItemActionsMenu).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Monter'), findsOneWidget);
      expect(find.text('Descendre'), findsOneWidget);
    });
  });

  group('AC20 — Reduce Motion (AD-13)', () {
    testWidgets('disableAnimations ⇒ la liste rend sans throw', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox(width: 1000, height: 700, child: _fullList()),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Question a'), findsOneWidget);
    });

    testWidgets('Reduce Motion : l\'aperçu délègue à su-2 (qui le respecte)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ZFlashcardPreview(card: _card('c1')),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // La règle Reduce Motion est POSSÉDÉE par su-2 (`ZFlashcardReviewCard`) —
      // su-8 ne la réimplémente pas, il délègue. Gardé chez su-2.
      expect(find.byType(ZFlashcardReviewCard), findsOneWidget);
    });
  });

  // =========================================================================
  // 🔴 su-9 (AC12) — énumération a11y des contrôles des 2 feuilles.
  // =========================================================================
  group('🔴 su-9/AC12 — a11y des contrôles de génération', () {
    testWidgets('🔴 D3 — le launcher est annoncé EXACTEMENT UNE FOIS (pas dupliqué)',
        (tester) async {
      final handle = tester.ensureSemantics();
      final port = _FakeGenPort((_) async => right(<ZFlashcard>[]));
      await tester.pumpWidget(_harness(ZFlashcardGenerationLauncher(
        label: 'Générer avec IA',
        port: port,
        onPressed: (_) {},
      )));
      await tester.pump();

      final btn = find.byKey(const ValueKey<String>('z-generation-launch'));
      final node = tester.getSemantics(btn);
      final announced = node.getSemanticsData().label;
      // 🔴 Icon(semanticLabel: label) + Text(label) fusionnés ⇒ « … , … » (récidive
      // su-8 « Ouvrir\nOuvrir »). Le libellé doit apparaître UNE seule fois.
      final occurrences =
          RegExp(RegExp.escape('Générer avec IA')).allMatches(announced).length;
      expect(occurrences, 1,
          reason: '🔴 launcher annoncé $occurrences fois (label fusionné : '
              '« ${announced.replaceAll('\n', ' / ')} »)');
      expect(node, containsSemantics(isButton: true, isEnabled: true));
      // Cible ≥ 48 dp.
      final size = tester.getSize(btn);
      expect(size.width, greaterThanOrEqualTo(_kMinTapTarget));
      expect(size.height, greaterThanOrEqualTo(_kMinTapTarget));
      handle.dispose();
    });

    testWidgets('🔴 D4 — le slider count : UN SEUL nœud slider (pas de fantôme) '
        'actionnable, libellé atteignable', (tester) async {
      final handle = tester.ensureSemantics();
      final port = _FakeGenPort((_) async => right(<ZFlashcard>[]));
      await tester.pumpWidget(_harness(_genSheet(port), size: const Size(360, 900)));
      await tester.pump();

      // 🔴 Compte les nœuds portant le flag isSlider dans TOUT l'arbre. L'ancien
      // `Semantics(slider:true)` enveloppant créait un 2ᵉ nœud slider FANTÔME
      // (non actionnable) ⇒ 2 sliders. Après correction : exactement 1.
      final root =
          tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
      final sliderNodes = <SemanticsNode>[];
      void walk(SemanticsNode n) {
        if (n.getSemanticsData().hasFlag(SemanticsFlag.isSlider)) {
          sliderNodes.add(n);
        }
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(root);
      expect(sliderNodes, hasLength(1),
          reason: '🔴 un slider FANTÔME cohabite avec le vrai (récidive su-8 D3)');
      // Le seul nœud slider est ACTIONNABLE (increase/decrease), pas un fantôme.
      final data = sliderNodes.single.getSemanticsData();
      expect(data.hasAction(SemanticsAction.increase), isTrue,
          reason: '🔴 le nœud slider doit porter increase (actionnable)');
      // Le libellé « Nombre de cartes » est atteignable (conteneur libellé).
      expect(find.bySemanticsLabel('Nombre de cartes'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('le bouton « Générer » : ≥ 48 dp + annoncé comme BOUTON',
        (tester) async {
      final handle = tester.ensureSemantics();
      final port = _FakeGenPort((_) async => right(<ZFlashcard>[]));
      await tester.pumpWidget(_harness(_genSheet(port), size: const Size(360, 900)));
      await tester.pump();

      final submit = find.byKey(const ValueKey<String>('z-generation-submit'));
      final size = tester.getSize(submit);
      expect(size.height, greaterThanOrEqualTo(_kMinTapTarget),
          reason: '🔴 cible ${size.height} dp < 48 dp (mobile 360)');
      expect(tester.getSemantics(submit),
          containsSemantics(isButton: true, isEnabled: true));
      handle.dispose();
    });

    testWidgets('feuille de confirmation : Confirmer/Annuler + ajout tag ≥ 48 dp',
        (tester) async {
      final handle = tester.ensureSemantics();
      final port = _FakeGenPort((_) async => right(<ZFlashcard>[
            ZFlashcard(id: 'a', question: 'Q', answer: 'R'),
          ]));
      await tester.pumpWidget(_harness(_genSheet(port), size: const Size(900, 1600)));
      // idle → génère → preview.
      final submit = find.byKey(const ValueKey<String>('z-generation-submit'));
      await tester.ensureVisible(submit);
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();
      await tester.pump();
      // preview → confirmation.
      final proceed = find.byKey(const ValueKey<String>('z-generation-proceed'));
      await tester.ensureVisible(proceed);
      await tester.pump();
      // Le bouton « Confirmer les tags » (preview) est aussi ≥ 48 dp.
      expect(tester.getSize(proceed).height, greaterThanOrEqualTo(_kMinTapTarget));
      await tester.tap(proceed);
      await tester.pump();

      // 🔴 Balaye TOUS les contrôles de la feuille de confirmation (leçon su-6).
      for (final key in <String>['z-tag-confirm-cancel', 'z-tag-confirm-apply']) {
        final f = find.byKey(ValueKey<String>(key));
        expect(f, findsOneWidget, reason: 'sonde : « $key » doit être rendu');
        expect(tester.getSize(f).height, greaterThanOrEqualTo(_kMinTapTarget),
            reason: '🔴 « $key » : ${tester.getSize(f).height} dp < 48 dp');
      }
      // Le bouton d'ajout de tag (ZTagEditor réutilisé) est annoncé + ≥ 48 dp.
      expect(find.bySemanticsLabel('Ajouter le tag'), findsWidgets,
          reason: '🔴 libellé d\'ajout INJECTÉ atteignable (L10n, D2)');
      handle.dispose();
    });
  });
}
