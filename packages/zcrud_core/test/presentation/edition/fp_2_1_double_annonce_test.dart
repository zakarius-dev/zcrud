// FP-2.1 — Dette a11y « double annonce » corrigée sur les 5 familles natives
// portant le motif `Semantics(container: true, label: X)` + `Text(X)` visible.
//
// Patron de correction (fp-4-4/fp-5-1) : retirer `label:` du conteneur — le
// `Text(resolvedLabel)` visible fournit déjà le nom accessible. Le libellé du
// champ ne doit donc apparaître qu'UNE seule fois dans l'arbre sémantique.
//
// Tests PORTEURS (canal Semantics, NON tautologiques) : chaque test parcourt
// l'arbre sémantique réel et compte le nombre d'OCCURRENCES du libellé dans les
// `label` des nœuds (les conteneurs `container: true` fusionnent leurs
// descendants en un seul nœud → il faut compter les occurrences de la
// sous-chaîne, pas les nœuds). Assert == 1. Falsifiable : réintroduire
// `label: resolvedLabel` sur le `Semantics(container:true)` ferait apparaître le
// libellé DEUX fois (== 2) → le test rougit. Aucun changement visuel/fonctionnel.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../../support/fake_file_picker.dart';

ZFormController _controller(Map<String, Object?> values, List<String> visible) =>
    ZFormController(initialValues: values, visibleFields: visible);

Widget _app(
  ZFormController controller,
  List<ZFieldSpec> fields, {
  ZFilePicker? picker,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: ZcrudScope(
          filePicker: picker,
          child: Scaffold(
            body: DynamicEdition(controller: controller, fields: fields),
          ),
        ),
      ),
    );

/// Compte le nombre total d'occurrences de [needle] (sensible à la casse) dans
/// les `label` de TOUS les nœuds sémantiques rendus. C'est le canal réellement
/// lu par un lecteur d'écran : une double annonce se traduit par 2 occurrences.
int _labelOccurrences(WidgetTester tester, String needle) {
  final owner = tester.binding.pipelineOwner.semanticsOwner!;
  var count = 0;
  void walk(SemanticsNode n) {
    count += needle.allMatches(n.getSemanticsData().label).length;
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(owner.rootSemanticsNode!);
  return count;
}

/// Vrai si un nœud sémantique porte [needle] dans son attribut `value` (canal
/// distinct du `label`, NON dupliqué par le `Text` visible → doit être préservé).
bool _hasSemanticsValue(WidgetTester tester, String needle) {
  final owner = tester.binding.pipelineOwner.semanticsOwner!;
  var found = false;
  void walk(SemanticsNode n) {
    if (n.getSemanticsData().value.contains(needle)) found = true;
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(owner.rootSemanticsNode!);
  return found;
}

void main() {
  // AC1 — color simple.
  testWidgets('color simple : libellé annoncé UNE seule fois (a11y)',
      (tester) async {
    final handle = tester.ensureSemantics();
    final controller = _controller(<String, Object?>{'c': null}, <String>['c']);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[
      ZFieldSpec(name: 'c', type: EditionFieldType.color, label: 'Couleur'),
    ]));
    await tester.pumpAndSettle();

    // Falsifiable : réintroduire `label: resolvedLabel` sur le conteneur ⇒ 2.
    expect(_labelOccurrences(tester, 'Couleur'), 1);
    handle.dispose();
  });

  // AC2 — rating : libellé une fois ET `value: '$current / $max'` conservé.
  testWidgets('rating : libellé UNE fois + value conteneur conservée',
      (tester) async {
    final handle = tester.ensureSemantics();
    final controller = _controller(<String, Object?>{'r': 3}, <String>['r']);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[
      ZFieldSpec(name: 'r', type: EditionFieldType.rating, label: 'Note'),
    ]));
    await tester.pumpAndSettle();

    expect(_labelOccurrences(tester, 'Note'), 1);
    // Le `value:` du conteneur n'est PAS dupliqué par le Text → doit rester
    // (prouve qu'on n'a pas retiré `value:` par erreur en retirant `label:`).
    expect(_hasSemanticsValue(tester, '3 / 5'), isTrue);
    handle.dispose();
  });

  // AC3 — tags.
  testWidgets('tags : libellé annoncé UNE seule fois (a11y)', (tester) async {
    final handle = tester.ensureSemantics();
    final controller =
        _controller(<String, Object?>{'t': <String>['x']}, <String>['t']);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[
      ZFieldSpec(name: 't', type: EditionFieldType.tags, label: 'Étiquettes'),
    ]));
    await tester.pumpAndSettle();

    expect(_labelOccurrences(tester, 'Étiquettes'), 1);
    handle.dispose();
  });

  // AC4 — rowChips.
  testWidgets('rowChips : libellé annoncé UNE seule fois (a11y)',
      (tester) async {
    final handle = tester.ensureSemantics();
    final controller = _controller(<String, Object?>{'rc': 'a'}, <String>['rc']);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const <ZFieldSpec>[
      ZFieldSpec(
        name: 'rc',
        type: EditionFieldType.rowChips,
        label: 'Choix',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'a', label: 'A'),
          ZFieldChoice(value: 'b', label: 'B'),
        ],
      ),
    ]));
    await tester.pumpAndSettle();

    expect(_labelOccurrences(tester, 'Choix'), 1);
    handle.dispose();
  });

  // AC5 — app_file wrapper natif : libellé une fois ; 2ᵉ Semantics intact.
  testWidgets('app_file : libellé UNE fois + 2ᵉ Semantics (état upload) intact',
      (tester) async {
    final handle = tester.ensureSemantics();
    final controller = _controller(
        <String, Object?>{'f': <AppFile>[fakePendingFile()]}, <String>['f']);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(
      controller,
      const <ZFieldSpec>[
        ZFieldSpec(
          name: 'f',
          type: EditionFieldType.image,
          label: 'Photo',
          config: FileFieldConfig(
            allowedSources: <ZFileSource>[ZFileSource.gallery],
          ),
        ),
      ],
      picker: FakeFilePicker(<AppFile>[fakePendingFile()]),
    ));
    await tester.pumpAndSettle();

    // 1er conteneur : le libellé du champ n'apparaît qu'une fois ('Photo' est
    // sensible à la casse et n'est PAS une sous-chaîne de 'photo.png').
    expect(_labelOccurrences(tester, 'Photo'), 1);
    // 2ᵉ Semantics (état upload) laissé strictement intact : il porte
    // value = stateLabel = nom du fichier ('photo.png') pour un fichier pending.
    expect(_hasSemanticsValue(tester, 'photo.png'), isTrue);
    handle.dispose();
  });
}
