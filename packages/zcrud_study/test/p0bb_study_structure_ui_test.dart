// P0b-B — la structure d'étude entre dans les écrans.
//
// Ce que ces gardes MESURENT, et pourquoi elles mordent :
//
// * l'arbre rendu par le sélecteur est celui des DONNÉES (ordre de pré-ordre,
//   indentation strictement ÉGALE à `depth × indentWidth`) — une garde en
//   `contains`/`<=` laisserait passer une indentation constante ;
// * la référence rendue par `onSelect` est la référence EXACTE (égalité
//   structurelle, instantané compris), jamais une reconstruite ;
// * un `kind` déclaré sans la capacité `hierarchical` est rendu FEUILLE : ni
//   affordance de dépliage, ni enfant peint ;
// * le fil d'Ariane rend EXACTEMENT `ZStudyContext.refs`, rend la référence
//   exacte au tap, et ses séparateurs BASCULENT en RTL ;
// * retirer une puce de portée produit le filtre RÉDUIT EXACT (égalité de
//   valeur sur le filtre ENTIER, pas seulement sur l'axe touché) ;
// * l'inertie est ABSOLUE : sans `scopeFilter`, `zFilterByScope` rend
//   l'INSTANCE reçue (`same`, pas `equals`) et la liste de flashcards rend le
//   MÊME ensemble de cartes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZReferenceProfile, ZcrudScope, ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

// ───────────────────────────────────────────────────────────── doubles ──

/// Porteur minimal du protocole de rattachement du noyau.
class _Artifact with ZStudyArtifact {
  _Artifact({this.primaryScopeRef});

  @override
  final ZStudyRef? ownerRef = null;

  @override
  final ZStudyRef? primaryScopeRef;

  @override
  final List<ZStudyBinding> bindings = const <ZStudyBinding>[];
}

ZStudyRef _unit(String id, {String? label, String? kind}) =>
    ZStudyRef(type: kZStudyRefTypeOrgUnit, id: id, label: label, kind: kind);

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
      ),
    );

double _rowTop(WidgetTester tester, String id) => tester
    .getTopLeft(find.byKey(ValueKey<String>('zStudyUnitPicker.row:$id')))
    .dy;

double _indentWidth(WidgetTester tester, String id) => tester
    .getSize(find.byKey(ValueKey<String>('zStudyUnitPicker.indent:$id')))
    .width;

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
  generateWithAiAction: 'Générer avec IA',
  readOnlyBadge: 'Lecture seule',
);

void main() {
  // ─────────────────────────────────────────────── ZStudyUnitPicker ──

  group('ZStudyUnitPicker — l\'arbre rendu EST celui des données', () {
    List<ZStudyUnitNode> forest() => <ZStudyUnitNode>[
      ZStudyUnitNode(
        ref: _unit('racine', label: 'Racine'),
        children: <ZStudyUnitNode>[
          ZStudyUnitNode(
            ref: _unit('enfant', label: 'Enfant'),
            children: <ZStudyUnitNode>[
              ZStudyUnitNode(ref: _unit('petit', label: 'Petit-enfant')),
            ],
          ),
          ZStudyUnitNode(ref: _unit('second', label: 'Second')),
        ],
      ),
    ];

    testWidgets('ordre de PRÉ-ORDRE, indentation ÉGALE à depth × indentWidth', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZStudyUnitPicker(
            roots: forest(),
            onSelect: (_) {},
            searchEnabled: false,
            indentWidth: 10,
          ),
        ),
      );

      // Ordre RÉEL, lu sur les ordonnées peintes — jamais sur l'ordre des
      // Finders, qui ne dit rien de ce que l'utilisateur voit.
      expect(_rowTop(tester, 'racine'), lessThan(_rowTop(tester, 'enfant')));
      expect(_rowTop(tester, 'enfant'), lessThan(_rowTop(tester, 'petit')));
      expect(_rowTop(tester, 'petit'), lessThan(_rowTop(tester, 'second')));

      // Égalité STRICTE : une indentation constante (le défaut à craindre)
      // rougirait ici, alors qu'un `lessThan` l'accepterait.
      expect(_indentWidth(tester, 'racine'), 0);
      expect(_indentWidth(tester, 'enfant'), 10);
      expect(_indentWidth(tester, 'petit'), 20);
      expect(_indentWidth(tester, 'second'), 10);
    });

    testWidgets('`onSelect` rend la référence EXACTE (instantané compris)', (
      WidgetTester tester,
    ) async {
      final ZStudyRef cible = _unit('enfant', label: 'Enfant', kind: 'faculty');
      final List<ZStudyRef> recues = <ZStudyRef>[];
      await tester.pumpWidget(
        _host(
          ZStudyUnitPicker(
            roots: <ZStudyUnitNode>[
              ZStudyUnitNode(
                ref: _unit('racine', label: 'Racine'),
                children: <ZStudyUnitNode>[ZStudyUnitNode(ref: cible)],
              ),
            ],
            onSelect: recues.add,
            searchEnabled: false,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('zStudyUnitPicker.row:enfant')),
      );
      await tester.pump();

      expect(recues, hasLength(1));
      // Égalité STRUCTURELLE : `sameTarget` passerait sur une référence
      // reconstruite sans son libellé — pas ici.
      expect(recues.single, cible);
      expect(recues.single.label, 'Enfant');
      expect(recues.single.kind, 'faculty');
    });

    testWidgets('un `kind` SANS `hierarchical` est rendu FEUILLE', (
      WidgetTester tester,
    ) async {
      const ZStudyOntology ontologie = ZStudyOntology(
        orgUnitKinds: <ZStudyKindSpec>[
          ZStudyKindSpec(
            key: 'terminal',
            family: kZStudyFamilyOrgUnit,
            // Aucune capacité : le type n'admet PAS de parent.
          ),
          ZStudyKindSpec(
            key: 'branche',
            family: kZStudyFamilyOrgUnit,
            capabilities: <String>{kZStudyCapabilityHierarchical},
          ),
        ],
      );

      final List<ZStudyUnitNode> roots = <ZStudyUnitNode>[
        ZStudyUnitNode(
          ref: _unit('branche', label: 'Branche', kind: 'branche'),
          children: <ZStudyUnitNode>[
            ZStudyUnitNode(ref: _unit('sousBranche', label: 'Sous-branche')),
          ],
        ),
        ZStudyUnitNode(
          ref: _unit('terminal', label: 'Terminal', kind: 'terminal'),
          children: <ZStudyUnitNode>[
            ZStudyUnitNode(ref: _unit('cache', label: 'Jamais peint')),
          ],
        ),
      ];

      await tester.pumpWidget(
        _host(
          ZStudyUnitPicker(
            roots: roots,
            onSelect: (_) {},
            ontology: ontologie,
            searchEnabled: false,
          ),
        ),
      );

      // Le nœud hiérarchique déplie et porte son affordance…
      expect(
        find.byKey(const ValueKey<String>('zStudyUnitPicker.expander:branche')),
        findsOneWidget,
      );
      expect(find.text('Sous-branche'), findsOneWidget);

      // …le nœud terminal n'en a AUCUNE et son enfant n'est PAS peint.
      expect(
        find.byKey(
          const ValueKey<String>('zStudyUnitPicker.expander:terminal'),
        ),
        findsNothing,
      );
      expect(find.text('Jamais peint'), findsNothing);
      expect(find.text('Terminal'), findsOneWidget);
    });

    testWidgets('recherche locale : seules les rangées qui matchent restent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(ZStudyUnitPicker(roots: forest(), onSelect: (_) {})),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('zStudyUnitPicker.search')),
        'second',
      );
      await tester.pump();

      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Racine'), findsNothing);
      expect(find.text('Petit-enfant'), findsNothing);
    });

    testWidgets('pastille : PRÉSENTE sous `legacy`, ABSENTE sous `neutral` '
        'ET par défaut', (
      WidgetTester tester,
    ) async {
      final Finder pastille = find.byKey(
        const ValueKey<String>('zStudyUnitPicker.badge:racine'),
      );
      final List<ZStudyUnitNode> roots = <ZStudyUnitNode>[
        ZStudyUnitNode(ref: _unit('racine', label: 'Racine')),
      ];

      await tester.pumpWidget(
        _host(
          ZcrudScope(
            theme: const ZcrudTheme(
              referenceProfile: ZReferenceProfile.legacy,
            ),
            child: ZStudyUnitPicker(
              roots: roots,
              onSelect: (_) {},
              searchEnabled: false,
            ),
          ),
        ),
      );
      expect(pastille, findsOneWidget);

      await tester.pumpWidget(
        _host(
          ZcrudScope(
            theme: const ZcrudTheme(
              referenceProfile: ZReferenceProfile.neutral,
            ),
            child: ZStudyUnitPicker(
              roots: roots,
              onSelect: (_) {},
              searchEnabled: false,
            ),
          ),
        ),
      );
      expect(pastille, findsNothing);

      // 🔴 Et le DÉFAUT du socle — aucun profil déclaré, pas même de
      // `ZcrudScope` — doit être indiscernable du profil neutre.
      await tester.pumpWidget(
        _host(
          ZStudyUnitPicker(
            roots: roots,
            onSelect: (_) {},
            searchEnabled: false,
          ),
        ),
      );
      expect(
        pastille,
        findsNothing,
        reason: '🔴 la pastille d\'identité est montée sans profil déclaré : '
            'le défaut du socle a dérivé vers `legacy`',
      );
    });
  });

  // ───────────────────────────────────────────────── ZStudyPathBar ──

  group('ZStudyPathBar — les segments SONT le chemin du contexte', () {
    final ZStudyRef org = ZStudyRef(
      type: kZStudyRefTypeOrganization,
      id: 'org',
      label: 'Université',
    );
    final ZStudyRef unite = _unit('unite', label: 'Faculté');
    final ZStudyRef groupe = ZStudyRef(
      type: kZStudyRefTypeGroup,
      id: 'grp',
      label: 'Groupe A',
    );
    final ZStudyRef offre = ZStudyRef(
      type: kZStudyRefTypeOffering,
      id: 'off',
      label: 'Session 2026',
    );
    final ZStudyContext contexte = ZStudyContext(
      organizationPath: <ZStudyRef>[org],
      orgUnitPath: <ZStudyRef>[unite],
      groupRefs: <ZStudyRef>[groupe],
      offeringRef: offre,
    );

    testWidgets('segments == `ZStudyContext.refs`, un segment tapable chacun', (
      WidgetTester tester,
    ) async {
      final List<ZStudyRef> recues = <ZStudyRef>[];
      final ZStudyPathBar barre = ZStudyPathBar(
        studyContext: contexte,
        onSelect: recues.add,
      );
      await tester.pumpWidget(_host(barre));

      // La liste rendue est celle du noyau, à l'ordre près de RIEN.
      expect(barre.segments, contexte.refs);
      expect(barre.segments, <ZStudyRef>[org, unite, groupe, offre]);

      for (final ZStudyRef ref in barre.segments) {
        expect(
          find.byKey(ValueKey<String>('zStudyPathBar.segment:${ref.id}')),
          findsOneWidget,
          reason: 'segment manquant : ${ref.id}',
        );
      }

      await tester.tap(
        find.byKey(const ValueKey<String>('zStudyPathBar.segment:grp')),
      );
      await tester.pump();
      expect(recues, hasLength(1));
      expect(recues.single, groupe);
      expect(recues.single.label, 'Groupe A');
    });

    testWidgets('🔴 RTL : le séparateur BASCULE (contre-preuve LTR incluse)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(ZStudyPathBar(studyContext: contexte, onSelect: (_) {})),
      );
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(3));
      expect(find.byIcon(Icons.chevron_left), findsNothing);

      await tester.pumpWidget(
        _host(
          ZStudyPathBar(studyContext: contexte, onSelect: (_) {}),
          direction: TextDirection.rtl,
        ),
      );
      expect(find.byIcon(Icons.chevron_left), findsNWidgets(3));
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('débordement : les premiers segments passent dans le menu', (
      WidgetTester tester,
    ) async {
      final List<ZStudyRef> recues = <ZStudyRef>[];
      await tester.pumpWidget(
        _host(
          ZStudyPathBar(
            studyContext: contexte,
            onSelect: recues.add,
            maxVisibleSegments: 2,
          ),
        ),
      );

      // Les DEUX derniers restent peints, les deux premiers non.
      expect(
        find.byKey(const ValueKey<String>('zStudyPathBar.segment:grp')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('zStudyPathBar.segment:off')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('zStudyPathBar.segment:org')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('zStudyPathBar.overflow')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('zStudyPathBar.overflowItem:org')),
      );
      await tester.pumpAndSettle();

      // Un segment choisi dans le menu rend la MÊME référence qu'en ligne.
      expect(recues, hasLength(1));
      expect(recues.single, org);
    });

    testWidgets('contexte vide ⇒ RIEN n\'est monté', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const ZStudyPathBar(studyContext: ZStudyContext())),
      );
      expect(
        find.byKey(const ValueKey<String>('zStudyPathBar.scroll')),
        findsNothing,
      );
    });
  });

  // ──────────────────────────────────────────────── ZStudyScopeBar ──

  group('ZStudyScopeBar — retirer une puce rend le filtre RÉDUIT EXACT', () {
    final ZStudyRef portee = _unit('unite', label: 'Faculté');
    final ZStudyRef autre = ZStudyRef(
      type: kZStudyRefTypeGroup,
      id: 'grp',
      label: 'Groupe A',
    );
    final ZStudyScopeFilter filtre = ZStudyScopeFilter(
      scopes: <ZStudyRef>[portee, autre],
      periodIds: const <String>['p1', 'p2'],
      subjectIds: const <String>['s1'],
      includeDescendants: false,
    );

    testWidgets('retirer une PORTÉE ne touche QUE l\'axe des portées', (
      WidgetTester tester,
    ) async {
      final List<ZStudyScopeFilter> recus = <ZStudyScopeFilter>[];
      await tester.pumpWidget(
        _host(ZStudyScopeBar(filter: filtre, onScopeChanged: recus.add)),
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('zStudyScopeBar.chip:orgUnit:unite'),
          ),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();

      expect(recus, hasLength(1));
      // Égalité de VALEUR sur le filtre ENTIER : un axe collatéral modifié
      // (ou `includeDescendants` réinitialisé à son défaut `true`) rougirait.
      expect(
        recus.single,
        ZStudyScopeFilter(
          scopes: <ZStudyRef>[autre],
          periodIds: const <String>['p1', 'p2'],
          subjectIds: const <String>['s1'],
          includeDescendants: false,
        ),
      );
    });

    testWidgets('retirer une PÉRIODE ne retire QUE cet identifiant', (
      WidgetTester tester,
    ) async {
      final List<ZStudyScopeFilter> recus = <ZStudyScopeFilter>[];
      await tester.pumpWidget(
        _host(ZStudyScopeBar(filter: filtre, onScopeChanged: recus.add)),
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('zStudyScopeBar.chip:period:p1'),
          ),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();

      expect(recus, hasLength(1));
      expect(
        recus.single,
        ZStudyScopeFilter(
          scopes: <ZStudyRef>[portee, autre],
          periodIds: const <String>['p2'],
          subjectIds: const <String>['s1'],
          includeDescendants: false,
        ),
      );
    });

    testWidgets('filtre VIDE ⇒ aucune puce, aucune hauteur réservée', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZStudyScopeBar(
            filter: const ZStudyScopeFilter(),
            onScopeChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('cible tactile ≥ 48 dp sur chaque puce (AD-13)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(ZStudyScopeBar(filter: filtre, onScopeChanged: (_) {})),
      );
      for (final String key in <String>[
        'zStudyScopeBar.chip:orgUnit:unite',
        'zStudyScopeBar.chip:group:grp',
        'zStudyScopeBar.chip:period:p1',
      ]) {
        expect(
          tester.getSize(find.byKey(ValueKey<String>(key))).height,
          greaterThanOrEqualTo(48),
          reason: 'cible trop petite : $key',
        );
      }
    });
  });

  // ────────────────────────────────────────────── zFilterByScope ──

  group('zFilterByScope — portée appliquée, inertie ABSOLUE sans portée', () {
    final ZStudyRef parent = _unit('parent');
    final ZStudyRef enfant = _unit('enfant');
    final _Artifact sousUnite = _Artifact(primaryScopeRef: enfant);
    final _Artifact ailleurs = _Artifact(primaryScopeRef: _unit('ailleurs'));

    // Vecteur FIGÉ : l'instantané déclare que `enfant` descend de `parent`.
    const ZStudyStructureSnapshot snapshot = ZStudyStructureSnapshot(
      orgUnits: <String, ZStudyOrgUnit>{
        'parent': ZStudyOrgUnit(id: 'parent', label: 'Parent'),
        'enfant': ZStudyOrgUnit(
          id: 'enfant',
          label: 'Enfant',
          parentId: 'parent',
          ancestorIds: <String>['parent'],
        ),
      },
    );

    test('`descendants` INCLUT la sous-unité ; sans lui, elle est EXCLUE', () {
      final List<_Artifact> items = <_Artifact>[sousUnite, ailleurs];
      final ZStudyScopeFilter surParent = ZStudyScopeFilter(
        scopes: <ZStudyRef>[parent],
      );

      expect(
        zFilterByScope<_Artifact>(
          items,
          surParent,
          artifactOf: (_Artifact a) => a,
          snapshot: snapshot,
        ),
        <_Artifact>[sousUnite],
      );

      // CONTRE-PREUVE : la même donnée, `includeDescendants: false`, n'inclut
      // plus rien — la garde mesure bien l'extension, pas un hasard.
      expect(
        zFilterByScope<_Artifact>(
          items,
          surParent.copyWith(includeDescendants: false),
          artifactOf: (_Artifact a) => a,
          snapshot: snapshot,
        ),
        isEmpty,
      );

      // CONTRE-PREUVE 2 : sans instantané, l'arbre est inconnu ⇒ rien.
      expect(
        zFilterByScope<_Artifact>(
          items,
          surParent,
          artifactOf: (_Artifact a) => a,
        ),
        isEmpty,
      );
    });

    test('INERTIE ABSOLUE : l\'INSTANCE reçue est rendue, pas une copie', () {
      final List<_Artifact> items = <_Artifact>[sousUnite, ailleurs];

      expect(
        zFilterByScope<_Artifact>(items, null, artifactOf: (_Artifact a) => a),
        same(items),
      );
      expect(
        zFilterByScope<_Artifact>(
          items,
          const ZStudyScopeFilter(),
          artifactOf: (_Artifact a) => a,
        ),
        same(items),
      );
      // Filtre NON vide mais AUCUNE projection : le socle n'invente pas un
      // rattachement — la liste est rendue telle quelle.
      expect(
        zFilterByScope<_Artifact>(
          items,
          ZStudyScopeFilter(scopes: <ZStudyRef>[parent]),
        ),
        same(items),
      );
    });

    test('un item sans rattachement est ÉCARTÉ sous un filtre non vide', () {
      final List<_Artifact?> items = <_Artifact?>[sousUnite, null];
      expect(
        zFilterByScope<_Artifact?>(
          items,
          ZStudyScopeFilter(scopes: <ZStudyRef>[enfant]),
          artifactOf: (_Artifact? a) => a,
        ),
        <_Artifact?>[sousUnite],
      );
    });
  });

  // ─────────────────────────────── ZFlashcardListView : inertie ──

  group('ZFlashcardListView — `scopeFilter` ABSENT ⇒ liste INCHANGÉE', () {
    List<ZFlashcard> cartes() => <ZFlashcard>[
      ZFlashcard(id: 'a', question: 'Alpha'),
      ZFlashcard(id: 'b', question: 'Beta'),
      ZFlashcard(id: 'c', question: 'Gamma'),
    ];

    Future<List<String>> rendu(
      WidgetTester tester, {
      ZStudyScopeFilter? scopeFilter,
      ZStudyArtifactOf<ZFlashcard>? artifactOf,
    }) async {
      final List<String> vus = <String>[];
      await tester.pumpWidget(
        _host(
          ZFlashcardListView(
            cards: cartes(),
            labels: _labels,
            scopeFilter: scopeFilter,
            scopeArtifactOf: artifactOf,
            contentBuilder: (BuildContext context, String text) {
              vus.add(text);
              return Text(text);
            },
          ),
        ),
      );
      await tester.pump();
      return vus;
    }

    testWidgets('sans portée, et avec une portée SANS projection : IDENTIQUE', (
      WidgetTester tester,
    ) async {
      final List<String> reference = await rendu(tester);
      expect(reference, isNotEmpty, reason: 'sonde VACUELLE : rien rendu');

      final List<String> avecPortee = await rendu(
        tester,
        scopeFilter: ZStudyScopeFilter(scopes: <ZStudyRef>[_unit('inconnue')]),
      );
      // Égalité STRICTE de la liste rendue — pas un `contains`.
      expect(avecPortee, reference);
    });

    testWidgets('avec projection, la portée FILTRE réellement', (
      WidgetTester tester,
    ) async {
      final ZStudyRef portee = _unit('unite');
      final List<String> vus = await rendu(
        tester,
        scopeFilter: ZStudyScopeFilter(scopes: <ZStudyRef>[portee]),
        artifactOf: (ZFlashcard card) =>
            card.id == 'b' ? _Artifact(primaryScopeRef: portee) : null,
      );
      expect(vus, <String>['Beta']);
    });
  });
}
