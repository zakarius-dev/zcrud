// Garde : un sous-stepper dont TOUTES les étapes sont filtrées ne lève pas.
//
// 🔴 MOTIF (2026-08-09) — défaut réel, trouvé en écrivant un gabarit de
// démonstration, pas en relisant le code. `_contribution()` indexait `_steps`
// sans garde de vacuité, alors que les **deux autres** sites qui l'indexent
// (`_initialUnion`, `build`) la portaient. Un sous-stepper intégralement filtré
// levait donc un `RangeError` — au montage (post-frame) **et** en vol.
//
// L'écrêtage d'index présent dans `_contribution` ne protégeait pas : sur une
// liste vide, la borne haute vaut -1, l'index retombe à 0, et l'accès lève.
//
// 🔴 Deux sens gardés, parce qu'ils empruntent des chemins DIFFÉRENTS :
//  * au MONTAGE, la fenêtre est publiée en post-frame ;
//  * EN VOL, elle l'est par le recalcul déclenché par le changement de valeur.
// Une garde posée sur un seul des deux laisserait l'autre ouvert — le dépôt
// s'est déjà fait prendre plusieurs fois cette semaine par des gardes
// unidirectionnelles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Champs du scénario : un pilote (`kind`) et deux champs de sous-étape.
const List<ZFieldSpec> _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'kind', type: EditionFieldType.text, label: 'Type'),
  ZFieldSpec(name: 'docA', type: EditionFieldType.text, label: 'Doc A'),
  ZFieldSpec(name: 'docB', type: EditionFieldType.text, label: 'Doc B'),
];

/// Sous-étapes conditionnées : AUCUNE n'est retenue tant que `kind != 'a'|'b'`.
List<ZEditionStep> _nested() => <ZEditionStep>[
      ZEditionStep(
        title: 'A',
        fields: const <String>['docA'],
        condition: const ZCondition.equals('kind', 'a'),
      ),
      ZEditionStep(
        title: 'B',
        fields: const <String>['docB'],
        condition: const ZCondition.equals('kind', 'b'),
      ),
    ];

Widget _host(ZFormController controller) => MaterialApp(
      home: Scaffold(
        body: ZStepperEdition(
          controller: controller,
          fields: _fields,
          // 🔴 Racine DÉPLIÉE : indispensable pour que la garde morde. En mode
          // paginé, seule l'étape courante est montée — l'étape portant le
          // sous-stepper ne l'est donc pas, l'enfant ne publie jamais sa
          // fenêtre, et le défaut reste inatteignable. Mesuré : la première
          // version de cette garde, écrite en racine paginée, restait VERTE
          // sous injection de la régression exacte.
          config: const ZStepperConfig(showAllSteps: true),
          steps: <ZEditionStep>[
            const ZEditionStep(title: 'Pilote', fields: <String>['kind']),
            ZEditionStep(
              title: 'Documents',
              fields: const <String>[],
              nestedSteps: _nested(),
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets(
      '🔴 sous-stepper INTÉGRALEMENT filtré : ne lève pas AU MONTAGE',
      (WidgetTester tester) async {
    // `kind` vide ⇒ aucune sous-étape ne satisfait sa condition.
    final controller = ZFormController(
      initialValues: const <String, Object?>{'kind': ''},
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();

    // Anti-vacuité : sans cette assertion, un montage qui aurait échoué en
    // silence passerait pour un succès.
    // Racine + sous-stepper = DEUX instances. Compter « exactement une »
    // rougissait pour une raison étrangère au défaut mesuré.
    expect(find.byType(ZStepperEdition), findsNWidgets(2),
        reason: 'racine et sous-stepper doivent être montés pour que la garde '
            'observe quelque chose');
    expect(tester.takeException(), isNull,
        reason: '🔴 un sous-stepper dont toutes les étapes sont filtrées ne '
            'doit pas lever au montage');
  });

  testWidgets(
      '🔴 sous-stepper INTÉGRALEMENT filtré : ne lève pas EN VOL',
      (WidgetTester tester) async {
    // Départ avec une sous-étape retenue, pour que le chemin exercé soit bien
    // le RECALCUL et non le montage — sinon cette garde doublonnerait la
    // précédente au lieu de couvrir l'autre chemin.
    final controller = ZFormController(
      initialValues: const <String, Object?>{'kind': 'a'},
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'état de départ sain');

    // Bascule vers une valeur qui ne retient AUCUNE sous-étape.
    controller.setValue('kind', 'zzz-aucune-sous-etape');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: '🔴 filtrer toutes les sous-étapes EN VOL ne doit pas lever');
    expect(find.byType(ZStepperEdition), findsNWidgets(2),
        reason: 'racine et sous-stepper doivent rester montés après le '
            'recalcul');
  });
}
