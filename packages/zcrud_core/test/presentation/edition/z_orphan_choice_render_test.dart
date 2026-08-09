// CR-ORPHAN — rendu UNIFORME d'une valeur ORPHELINE (sélectionnée, puis absente
// des options) sur les HUIT voies de rendu des familles à choix, plus la voie de
// LECTURE SEULE et la voie `rowChips` trouvées au balayage.
//
// Règle gardée : une valeur orpheline est RENDUE, à sa place, sous un libellé
// l10n (`choiceUnresolved`), dans l'état `disabled` — jamais effacée (mensonge
// d'affichage : la donnée est là et sera soumise), jamais rendue par sa CLÉ
// technique (défaut déjà proscrit ailleurs, cf. `fileRefUnresolved`).
//
// 🔴 Anti-garde-vacante (deux pièges nommés, tous deux fermés par `groupe 0`) :
//   1. une garde d'orphelin est VACANTE si le jeu d'options d'après contient
//      encore la valeur ⇒ les deux populations sont assertées DISJOINTES ;
//   2. une garde « la clé n'est pas affichée » est VACANTE si la clé RESSEMBLE
//      à un libellé ⇒ les identifiants sont opaques (`ID-…`) et l'on asserte
//      qu'aucun libellé ne les contient, ni l'inverse.
//
// Sans delegate monté, `label()` retombe sur la table `en` intégrée : le libellé
// attendu est donc `'Option unavailable'` (cf. `_family_form.dart`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Libellé l10n `en` d'une valeur orpheline (table intégrée, sans delegate).
const String kOrphanLabel = 'Option unavailable';

/// Population **d'AVANT** la bascule de cascade. Identifiants OPAQUES : aucun
/// ne peut être confondu avec un libellé.
const String kOrphanId = 'ID-7F3A91-0001';
const String kOrphanId2 = 'ID-7F3A91-0002';
const List<ZFieldChoice> kBefore = <ZFieldChoice>[
  ZFieldChoice(value: kOrphanId, label: 'Alpha'),
  ZFieldChoice(value: kOrphanId2, label: 'Beta'),
];

/// Population **d'APRÈS** la bascule — DISJOINTE de [kBefore].
const String kLiveId = 'ID-B0C2D4-0011';
const List<ZFieldChoice> kAfter = <ZFieldChoice>[
  ZFieldChoice(value: kLiveId, label: 'Gamma'),
  ZFieldChoice(value: 'ID-B0C2D4-0012', label: 'Delta'),
];

Widget _app(Widget child) => MaterialApp(
      home: Scaffold(body: Material(child: child)),
    );

/// Source dynamique de relation émettant [emissions] à la demande.
class _StreamSource implements ZRelationSource {
  _StreamSource(this._controller);
  final StreamController<List<ZFieldChoice>> _controller;
  @override
  Stream<List<ZFieldChoice>> options(Map<String, Object?> filterContext) =>
      _controller.stream;
}

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  group('0. Pré-conditions — sans elles, TOUTE garde ci-dessous serait vacante',
      () {
    test('les deux populations sont DISJOINTES (aucune valeur commune)', () {
      final before = kBefore.map((c) => c.value).toSet();
      final after = kAfter.map((c) => c.value).toSet();
      expect(before.intersection(after), isEmpty,
          reason: 'si une valeur survivait à la bascule, elle ne serait pas '
              'orpheline et la garde ne mesurerait rien');
      expect(after.contains(kOrphanId), isFalse);
      expect(after.contains(kOrphanId2), isFalse);
    });

    test('la CLÉ ne peut pas être confondue avec un LIBELLÉ', () {
      final labels = <String>[
        for (final c in <ZFieldChoice>[...kBefore, ...kAfter]) c.label,
        kOrphanLabel,
      ];
      for (final l in labels) {
        expect(l.contains(kOrphanId), isFalse,
            reason: 'un libellé contenant la clé rendrait vacante toute '
                'assertion « la clé n\'est pas affichée »');
        expect(kOrphanId.contains(l), isFalse);
      }
      // Le libellé d'orphelin est bien un LIBELLÉ, pas la clé l10n brute.
      expect(kOrphanLabel, isNot('choiceUnresolved'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('Voies 1-5 — famille select (z_select_field_widget)', () {
    testWidgets('voie 1 — dropdown mono : orphelin VISIBLE, clé JAMAIS',
        (tester) async {
      Object? written;
      await tester.pumpWidget(_app(ZSelectFieldWidget(
        field: const ZFieldSpec(
            name: 'f', type: EditionFieldType.select, label: 'Choix'),
        value: kOrphanId,
        choices: kAfter,
        onChanged: (v) => written = v,
      )));
      await tester.pumpAndSettle();

      expect(find.text(kOrphanLabel), findsWidgets,
          reason: 'la valeur EXISTE et sera soumise : l\'effacer de l\'écran '
              'est un mensonge d\'affichage');
      expect(find.text(kOrphanId), findsNothing,
          reason: 'une identité non résolue ne se montre jamais par sa clé');
      expect(tester.takeException(), isNull);
      // Rendu ⇒ AUCUNE écriture (ce lot touche au rendu, jamais à la donnée).
      expect(written, isNull);
    });

    testWidgets('voie 2 — modal mono (searchable) : déclencheur non menteur',
        (tester) async {
      await tester.pumpWidget(_app(ZSelectFieldWidget(
        field: const ZFieldSpec(
            name: 'f', type: EditionFieldType.select, label: 'Choix'),
        value: kOrphanId,
        choices: kAfter,
        searchable: true,
        onChanged: (_) {},
      )));
      await tester.pumpAndSettle();

      expect(find.text(kOrphanLabel), findsOneWidget);
      expect(find.text(kOrphanId), findsNothing);
      // Le placeholder « Select » signifierait « rien de choisi » — c'est
      // précisément le mensonge à ne plus commettre.
      expect(find.text('Select'), findsNothing);
      // a11y : le déclencheur porte la VALEUR sémantique, pas seulement un nom.
      final sem = tester.getSemantics(find.byType(InputDecorator).first);
      expect(sem.value, kOrphanLabel);
    });

    testWidgets(
        'voie 2 bis — DANS la feuille modale : orpheline cochée, non cochable, '
        'et « Confirmer » la restitue À L\'IDENTIQUE', (tester) async {
      final written = <Object?>[];
      await tester.pumpWidget(_app(ZSelectFieldWidget(
        field: const ZFieldSpec(
            name: 'f', type: EditionFieldType.select, label: 'Choix'),
        value: const <Object?>[kOrphanId, kLiveId],
        choices: kAfter,
        multiple: true,
        onChanged: written.add,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Pré-contrôle : la feuille est bien ouverte (sinon garde vacante).
      expect(find.text('Confirm'), findsOneWidget);
      // Pré-contrôle (même leçon que la voie 5) : sans lui, la perte de la
      // tuile rougirait par `StateError` de recherche, pas par assertion.
      // 🔴 On CIBLE la tuile de la feuille : le champ reste monté DERRIÈRE le
      // modal, donc `find.text(kOrphanLabel)` en trouve deux (la puce + la
      // tuile). Filtrer par `CheckboxListTile` isole celle de la feuille.
      final orphanTileFinder = find.ancestor(
          of: find.text(kOrphanLabel), matching: find.byType(CheckboxListTile));
      expect(orphanTileFinder, findsOneWidget);
      final orphanTile = tester.widget<CheckboxListTile>(orphanTileFinder);
      expect(orphanTile.value, isTrue);
      expect(orphanTile.onChanged, isNull,
          reason: 'l\'orpheline est lue et vue, mais non manipulable');
      expect(find.text(kOrphanId), findsNothing);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(written, hasLength(1));
      expect((written.single! as List<Object?>).toSet(),
          <Object?>{kOrphanId, kLiveId},
          reason: 'confirmer sans rien toucher ne doit RIEN retirer');
    });

    testWidgets('voie 3 — chips multi : plus jamais l\'identifiant brut',
        (tester) async {
      await tester.pumpWidget(_app(ZSelectFieldWidget(
        field: const ZFieldSpec(
            name: 'f', type: EditionFieldType.select, label: 'Choix'),
        value: const <Object?>[kOrphanId, kLiveId],
        choices: kAfter,
        multiple: true,
        onChanged: (_) {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Gamma'), findsOneWidget, reason: 'la valeur résolue');
      expect(find.text(kOrphanLabel), findsOneWidget, reason: 'l\'orpheline');
      expect(find.text(kOrphanId), findsNothing);
      // Le canal a11y ne doit pas non plus porter la clé.
      final chips = tester.widgetList<InputChip>(find.byType(InputChip));
      expect(chips.length, 2);
      for (final s in tester
          .widgetList<Semantics>(find.ancestor(
              of: find.byType(InputChip), matching: find.byType(Semantics)))
          .where((s) => s.properties.label != null)) {
        expect(s.properties.label, isNot(contains(kOrphanId)));
      }
    });

    testWidgets('voie 4 — radios : la sélection orpheline est COCHÉE, désactivée',
        (tester) async {
      await tester.pumpWidget(_app(ZSelectFieldWidget(
        field: const ZFieldSpec(
            name: 'f', type: EditionFieldType.radio, label: 'Radio'),
        value: kOrphanId,
        choices: kAfter,
        onChanged: (_) {},
      )));
      await tester.pumpAndSettle();

      final tiles = tester
          .widgetList<RadioListTile<Object?>>(
              find.byType(RadioListTile<Object?>))
          .toList();
      expect(tiles.length, kAfter.length + 1,
          reason: 'une tuile synthétique s\'ajoute aux options réelles');
      final orphan = tiles.singleWhere((t) => t.value == kOrphanId);
      expect(orphan.enabled, isFalse,
          reason: 'canal a11y : l\'état est porté par `disabled`, pas par une '
              'couleur');
      expect(find.text(kOrphanLabel), findsOneWidget);
      expect(find.text(kOrphanId), findsNothing);
    });

    testWidgets('voie 5 — cases : la case orpheline est COCHÉE, non décochable',
        (tester) async {
      await tester.pumpWidget(_app(ZSelectFieldWidget(
        field: const ZFieldSpec(
            name: 'f', type: EditionFieldType.checkbox, label: 'Cases'),
        value: const <Object?>[kOrphanId],
        choices: kAfter,
        onChanged: (_) {},
      )));
      await tester.pumpAndSettle();

      final tiles = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(tiles.length, kAfter.length + 1);
      // Pré-contrôle : sans lui, une régression ferait rougir cette garde par
      // un `StateError` de RECHERCHE (« Bad state: No element ») au lieu d'une
      // ASSERTION — un rouge illisible qui ne nomme pas la propriété perdue.
      // Mesuré lors de l'injection R3 n°2.
      expect(find.text(kOrphanLabel), findsOneWidget);
      final orphanTile = tester.widget<CheckboxListTile>(find.ancestor(
          of: find.text(kOrphanLabel), matching: find.byType(CheckboxListTile)));
      expect(orphanTile.value, isTrue, reason: 'l\'état réel : elle EST portée');
      expect(orphanTile.onChanged, isNull,
          reason: 'ce widget ne rend que la donnée que son propre geste écrit');
      expect(find.text(kOrphanId), findsNothing);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('Voies 6-8 — famille relation (z_relation_field_widget)', () {
    testWidgets('voie 6 — dropdown : orphelin VISIBLE, clé JAMAIS',
        (tester) async {
      final ctrl = StreamController<List<ZFieldChoice>>.broadcast();
      addTearDown(ctrl.close);
      await tester.pumpWidget(_app(ZRelationFieldWidget(
        field: const ZFieldSpec(
            name: 'r', type: EditionFieldType.relation, label: 'Relation'),
        value: kOrphanId,
        source: _StreamSource(ctrl),
        onChanged: (_) {},
      )));
      ctrl.add(kAfter);
      await tester.pumpAndSettle();

      expect(find.text(kOrphanLabel), findsWidgets);
      expect(find.text(kOrphanId), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'voie 6 bis — PENDANT le chargement, rien n\'est déclaré orphelin',
        (tester) async {
      final ctrl = StreamController<List<ZFieldChoice>>.broadcast();
      addTearDown(ctrl.close);
      await tester.pumpWidget(_app(ZRelationFieldWidget(
        field: const ZFieldSpec(
            name: 'r', type: EditionFieldType.relation, label: 'Relation'),
        value: kOrphanId,
        source: _StreamSource(ctrl),
        onChanged: (_) {},
      )));
      await tester.pump(); // aucune émission encore.

      expect(find.text(kOrphanLabel), findsNothing,
          reason: '« pas encore chargé » n\'est PAS « plus proposé » — '
              'l\'annoncer indisponible serait une donnée inventée');
      expect(find.text(kOrphanId), findsNothing,
          reason: 'et surtout, jamais la clé pendant le chargement');
    });

    testWidgets('voie 7 — mono searchable : déclencheur non menteur',
        (tester) async {
      final ctrl = StreamController<List<ZFieldChoice>>.broadcast();
      addTearDown(ctrl.close);
      await tester.pumpWidget(_app(ZRelationFieldWidget(
        field: const ZFieldSpec(
            name: 'r', type: EditionFieldType.relation, label: 'Relation'),
        value: kOrphanId,
        source: _StreamSource(ctrl),
        searchable: true,
        onChanged: (_) {},
      )));
      ctrl.add(kAfter);
      await tester.pumpAndSettle();

      expect(find.text(kOrphanLabel), findsOneWidget);
      expect(find.text(kOrphanId), findsNothing);
      expect(find.text('Select'), findsNothing);
      final sem = tester.getSemantics(find.byType(InputDecorator).first);
      expect(sem.value, kOrphanLabel);
    });

    testWidgets('voie 8 — chips multi : plus jamais l\'identifiant brut',
        (tester) async {
      final ctrl = StreamController<List<ZFieldChoice>>.broadcast();
      addTearDown(ctrl.close);
      await tester.pumpWidget(_app(ZRelationFieldWidget(
        field: const ZFieldSpec(
            name: 'r', type: EditionFieldType.relation, label: 'Relation'),
        value: const <Object?>[kOrphanId, kLiveId],
        source: _StreamSource(ctrl),
        multiple: true,
        onChanged: (_) {},
      )));
      ctrl.add(kAfter);
      await tester.pumpAndSettle();

      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text(kOrphanLabel), findsOneWidget);
      expect(find.text(kOrphanId), findsNothing);
    });

    testWidgets(
        'voie 8 bis — pendant le chargement, les chips ne montrent PAS la clé',
        (tester) async {
      final ctrl = StreamController<List<ZFieldChoice>>.broadcast();
      addTearDown(ctrl.close);
      await tester.pumpWidget(_app(ZRelationFieldWidget(
        field: const ZFieldSpec(
            name: 'r', type: EditionFieldType.relation, label: 'Relation'),
        value: const <Object?>[kOrphanId],
        source: _StreamSource(ctrl),
        multiple: true,
        onChanged: (_) {},
      )));
      await tester.pump();

      expect(find.text(kOrphanId), findsNothing,
          reason: 'défaut jumeau : la liste live vide faisait déjà tomber les '
              'chips sur `\'\$v\'` — la clé s\'affichait pendant le chargement');
      expect(find.text('Loading…'), findsWidgets);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('Voies hors des deux fichiers, trouvées au balayage', () {
    testWidgets('rowChips — puce synthétique, jamais la clé', (tester) async {
      await tester.pumpWidget(_app(const ZRowChipsFieldWidget(
        field: ZFieldSpec(
            name: 'rc',
            type: EditionFieldType.rowChips,
            label: 'Puces',
            choices: kAfter),
        value: kOrphanId,
        onChanged: _noop,
      )));
      await tester.pumpAndSettle();

      final chips =
          tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips.length, kAfter.length + 1);
      expect(chips.where((c) => c.selected).length, 1,
          reason: 'sans puce synthétique, AUCUNE puce n\'était sélectionnée '
              'alors qu\'une valeur était portée');
      expect(chips.singleWhere((c) => c.selected).onSelected, isNull,
          reason: 'non re-sélectionnable : elle n\'est plus proposée');
      expect(find.text(kOrphanLabel), findsOneWidget);
      expect(find.text(kOrphanId), findsNothing);
    });

    testWidgets('LECTURE SEULE — la fiche ne montre plus l\'identifiant brut',
        (tester) async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{'sel': kOrphanId},
        visibleFields: const <String>['sel'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            readOnly: true,
            fields: const <ZFieldSpec>[
              ZFieldSpec(
                  name: 'sel',
                  type: EditionFieldType.select,
                  label: 'Choix',
                  choices: kAfter),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(kOrphanId), findsNothing,
          reason: 'le mode lecture rendait `\'\$v\'` — la clé, à l\'écran');
      expect(find.text(kOrphanLabel), findsOneWidget);
      // La lecture n'écrit rien : la valeur reste EXACTEMENT celle d'entrée.
      expect(controller.valueOf('sel'), kOrphanId);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('🔴 La DONNÉE est intacte — ce lot touche au rendu, jamais à la valeur',
      () {
    testWidgets('mono : la valeur soumise est identique après le correctif',
        (tester) async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{'sel': kOrphanId},
        visibleFields: const <String>['sel'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: const <ZFieldSpec>[
              ZFieldSpec(
                  name: 'sel',
                  type: EditionFieldType.select,
                  label: 'Choix',
                  choices: kAfter),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // 🔴 La DONNÉE est assertée EN PREMIER : placée après les assertions de
      // rendu, elle n'aurait jamais été atteinte sous une injection de purge
      // (le rendu rougit d'abord) — la garde aurait paru mordante sans l'être.
      // Mesuré lors de l'injection R3 n°5.
      expect(controller.values['sel'], kOrphanId);
      // Le rendu, lui, montre l'indisponibilité — sans substituer le libellé à
      // la valeur.
      expect(find.text(kOrphanLabel), findsWidgets);
      expect(controller.values['sel'], isNot(kOrphanLabel));
      expect(controller.isDirty.value, isFalse,
          reason: 'aucune écriture : le formulaire n\'est pas devenu sale du '
              'seul fait de l\'affichage');
    });

    testWidgets('multi : la liste soumise est identique, ordre compris',
        (tester) async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{
          'chk': <Object?>[kOrphanId, kLiveId, kOrphanId2],
        },
        visibleFields: const <String>['chk'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: const <ZFieldSpec>[
              ZFieldSpec(
                  name: 'chk',
                  type: EditionFieldType.checkbox,
                  label: 'Cases',
                  choices: kAfter,
                  multiple: true),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Idem : la donnée d'abord (cf. injection R3 n°6).
      expect(controller.values['chk'],
          const <Object?>[kOrphanId, kLiveId, kOrphanId2]);
      expect(controller.isDirty.value, isFalse);
      // Les DEUX orphelines sont rendues, aucune n'est effacée ni montrée en clé.
      expect(find.text(kOrphanLabel), findsNWidgets(2));
      expect(find.text(kOrphanId), findsNothing);
      expect(find.text(kOrphanId2), findsNothing);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('Hôte passif — sans orphelin, rien ne change', () {
    // Note : l'identité d'instance renvoyée par `zWithOrphanChoices` quand il
    // n'y a aucun orphelin (pas de liste réallouée à chaque build, SM-1) n'est
    // PAS gardée ici — le helper est `src`-privé et aucun test de ce paquet
    // n'importe `package:zcrud_core/src/…`. Elle est assurée par lecture, pas
    // par mesure : je le déclare plutôt que de maquiller une garde.
    testWidgets('un select dont la valeur est OFFERTE rend exactement comme avant',
        (tester) async {
      await tester.pumpWidget(_app(ZSelectFieldWidget(
        field: const ZFieldSpec(
            name: 'f', type: EditionFieldType.select, label: 'Choix'),
        value: kLiveId,
        choices: kAfter,
        onChanged: (_) {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text(kOrphanLabel), findsNothing,
          reason: 'aucun marqueur ne doit apparaître là où rien n\'est orphelin');

      // 🔴 Compter les `DropdownMenuItem` sur un dropdown FERMÉ ne mesure rien
      // (Flutter n'en monte qu'un : l'item sélectionné). Le menu est donc
      // OUVERT avant de compter — sinon la garde serait vacante.
      await tester.tap(find.byType(DropdownButtonFormField<Object?>));
      await tester.pumpAndSettle();
      expect(find.text('Delta'), findsWidgets,
          reason: 'pré-contrôle : le menu est bien ouvert');
      expect(find.text(kOrphanLabel), findsNothing,
          reason: 'aucune option synthétique ajoutée au menu déroulant');
    });
  });
}

void _noop(Object? _) {}
