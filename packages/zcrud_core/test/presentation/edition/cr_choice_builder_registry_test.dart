/// Gardes du canal déclaratif `ZSelectConfig.choiceBuilderKey`.
///
/// Elles exercent le chemin nominal `DynamicEdition → ZFieldWidget →
/// ZSelectFieldWidget` avec une hauteur suffisante : un `ListView.builder`
/// ne peut donc pas laisser le champ hors arbre et rendre le test vert à vide.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _RenderingPresenter extends ZSelectPresenter {
  @override
  Widget present(BuildContext context, ZSelectPresentation presentation) {
    return Column(
      children: presentation.options
          .map((choice) {
            final choiceContext = ZSelectChoiceContext(
              choice: choice,
              selected: false,
              enabled: !presentation.readOnly,
              select: (_) {},
            );
            final primary =
                presentation.choiceBuilder?.call(context, choiceContext) ??
                Text('default:${choice.label}');
            final secondary = presentation.choiceSecondaryBuilder?.call(
              context,
              choiceContext,
            );
            return secondary == null
                ? primary
                : Column(children: <Widget>[primary, secondary]);
          })
          .toList(growable: false),
    );
  }
}

class _ReadOnlyChoice extends StatelessWidget {
  const _ReadOnlyChoice({required this.choice});

  final ZSelectChoiceContext choice;

  @override
  Widget build(BuildContext context) => FilledButton(
    key: const ValueKey<String>('rich-read-only-choice'),
    onPressed: choice.enabled ? () => choice.select(true) : null,
    child: Text('rich:${ZReadModeScope.of(context)}'),
  );
}

class _ReadOnlyRecordingPresenter extends ZSelectPresenter {
  bool? receivedReadOnly;

  @override
  Widget present(BuildContext context, ZSelectPresentation presentation) {
    receivedReadOnly = presentation.readOnly;
    final choice = presentation.options.single;
    final choiceContext = ZSelectChoiceContext(
      choice: choice,
      selected: presentation.selected == choice.value,
      enabled: !presentation.readOnly && !choice.disabled,
      select: (selected) =>
          presentation.onChanged(selected ? choice.value : null),
    );
    return presentation.choiceBuilder!(context, choiceContext);
  }
}

const ZFieldSpec _plain = ZFieldSpec(
  name: 'permission',
  type: EditionFieldType.select,
  label: 'Permission',
  choices: <ZFieldChoice>[ZFieldChoice(value: 'read', label: 'Lire')],
);

const ZFieldSpec _declared = ZFieldSpec(
  name: 'permission',
  type: EditionFieldType.select,
  label: 'Permission',
  config: ZSelectConfig(choiceBuilderKey: 'acl-matrix'),
  choices: <ZFieldChoice>[ZFieldChoice(value: 'read', label: 'Lire')],
);

ZFormController _readController() => ZFormController(
  initialValues: const <String, Object?>{'permission': 'read'},
);

Widget _form({
  required ZFieldSpec field,
  ZSelectChoiceBuilderRegistry? registry,
  ZSelectPresenter? presenter,
  ZFormController? controller,
  bool readOnly = false,
}) => MaterialApp(
  home: ZcrudScope(
    selectPresenter: presenter ?? _RenderingPresenter(),
    selectChoiceBuilderRegistry: registry,
    child: Scaffold(
      body: SizedBox(
        height: 600,
        child: DynamicEdition(
          controller:
              controller ??
              ZFormController(initialValues: const <String, Object?>{}),
          fields: <ZFieldSpec>[field],
          readOnly: readOnly,
        ),
      ),
    ),
  ),
);

ZSelectChoiceBuilders _aclBuilders() => ZSelectChoiceBuilders(
  choiceBuilder: (context, choice) => Semantics(
    label: 'permission ${choice.choice.label}',
    button: true,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Text('personnalise:${choice.choice.label}'),
    ),
  ),
  choiceSecondaryBuilder: (context, choice) => const Text('secondaire'),
);

void main() {
  group('CR choiceBuilder déclaratif', () {
    testWidgets(
      'G1 — DynamicEdition nominal monte le champ et applique le builder enregistré',
      (tester) async {
        final registry = ZSelectChoiceBuilderRegistry()
          ..register('acl-matrix', _aclBuilders());

        await tester.pumpWidget(_form(field: _declared, registry: registry));

        expect(
          find.byType(ZSelectFieldWidget),
          findsOneWidget,
          reason:
              '🔴 le champ ciblé doit être réellement monté par le ListView.',
        );
        expect(
          find.text('personnalise:Lire'),
          findsOneWidget,
          reason:
              '🔴 la clé déclarée doit atteindre le choiceBuilder sans champ de remplacement.',
        );
        expect(
          find.text('secondaire'),
          findsOneWidget,
          reason: '🔴 la même clé doit aussi atteindre choiceSecondaryBuilder.',
        );
      },
    );

    testWidgets('G2 — sans clé, le compte ABSOLU de nœuds reste identique', (
      tester,
    ) async {
      await tester.pumpWidget(_form(field: _plain));
      final before = tester.allElements.length;
      expect(
        before,
        220,
        reason: '🔴 contre-témoin absolu : ce témoin fige l’arbre historique.',
      );
      await tester.pumpWidget(
        _form(
          field: const ZFieldSpec(
            name: 'permission',
            type: EditionFieldType.select,
            label: 'Permission',
            config: ZSelectConfig(),
            choices: <ZFieldChoice>[ZFieldChoice(value: 'read', label: 'Lire')],
          ),
        ),
      );
      expect(
        tester.allElements.length,
        220,
        reason:
            '🔴 une config sans clé ne doit ajouter aucun nœud à tous les hôtes.',
      );
    });

    testWidgets('G3 — clé inconnue : repli par défaut et aucune exception', (
      tester,
    ) async {
      await tester.pumpWidget(
        _form(field: _declared, registry: ZSelectChoiceBuilderRegistry()),
      );
      expect(
        find.text('default:Lire'),
        findsOneWidget,
        reason: '🔴 une clé absente doit conserver le rendu par défaut.',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '🔴 une clé absente ne doit jamais remonter une exception.',
      );
    });

    test('G4 — parent/enfant : ombrage réel, collision locale explicite', () {
      final parent = ZSelectChoiceBuilderRegistry()
        ..register('acl-matrix', _aclBuilders());
      final child = ZSelectChoiceBuilderRegistry(parent: parent)
        ..register(
          'acl-matrix',
          const ZSelectChoiceBuilders(choiceSecondaryBuilder: _secondary),
        );
      expect(
        child.buildersFor('acl-matrix').choiceBuilder,
        isNull,
        reason:
            '🔴 le builder enfant doit ombrer le parent, pas fusionner silencieusement.',
      );
      expect(
        () => child.register('acl-matrix', _aclBuilders()),
        throwsA(isA<ZDuplicateRegistrationError>()),
        reason: '🔴 une seconde inscription locale doit lever explicitement.',
      );
    });

    testWidgets('G5 — le builder impose lui-même Semantics et la cible 48 dp', (
      tester,
    ) async {
      final registry = ZSelectChoiceBuilderRegistry()
        ..register('acl-matrix', _aclBuilders());
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_form(field: _declared, registry: registry));

      final node = tester.getSemantics(find.text('personnalise:Lire'));
      expect(
        node.label,
        contains('permission Lire'),
        reason:
            '🔴 le builder doit annoncer explicitement son choix personnalisé.',
      );
      final constrained = tester.widget<ConstrainedBox>(
        find.ancestor(
          of: find.text('personnalise:Lire'),
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(
        constrained.constraints.minHeight,
        48,
        reason:
            '🔴 la garde vérifie la contrainte DÉCLARÉE par le builder, pas un minimum implicite Flutter.',
      );
      expect(constrained.constraints.minWidth, 48);
      semantics.dispose();
    });

    testWidgets(
      'G6 — lecture : le rendu riche résolu remplace la fiche générique',
      (tester) async {
        final registry = ZSelectChoiceBuilderRegistry()
          ..register('acl-matrix', _aclBuilders());
        final controller = _readController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _form(
            field: _declared,
            registry: registry,
            controller: controller,
            readOnly: true,
          ),
        );

        expect(find.byType(ZSelectFieldWidget), findsOneWidget);
        expect(find.text('personnalise:Lire'), findsOneWidget);
        expect(find.byType(ZReadOnlyFieldCard), findsNothing);
      },
    );

    testWidgets(
      'G7 — lecture : le builder reçoit le mode et ne peut pas écrire',
      (tester) async {
        final registry = ZSelectChoiceBuilderRegistry()
          ..register(
            'acl-matrix',
            ZSelectChoiceBuilders(
              choiceBuilder: (context, choice) =>
                  _ReadOnlyChoice(choice: choice),
            ),
          );
        final presenter = _ReadOnlyRecordingPresenter();
        final controller = ZFormController(
          initialValues: const <String, Object?>{'permission': 'read'},
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _form(
            field: _declared,
            registry: registry,
            presenter: presenter,
            controller: controller,
            readOnly: true,
          ),
        );

        expect(find.byType(ZSelectFieldWidget), findsOneWidget);
        expect(find.byType(_ReadOnlyChoice), findsOneWidget);
        expect(presenter.receivedReadOnly, isTrue);
        expect(find.text('rich:true'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey<String>('rich-read-only-choice')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('rich-read-only-choice')),
        );
        await tester.pump();
        expect(controller.valueOf('permission'), 'read');
      },
    );

    testWidgets(
      'G8 — lecture : clé non résolue retombe sur la fiche sans exception',
      (tester) async {
        final controller = _readController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _form(
            field: _declared,
            registry: ZSelectChoiceBuilderRegistry(),
            controller: controller,
            readOnly: true,
          ),
        );

        expect(find.byType(ZReadOnlyFieldCard), findsOneWidget);
        expect(find.byType(ZSelectFieldWidget), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('G9 — lecture sans clé : compte ABSOLU de fiches historique', (
      tester,
    ) async {
      final controller = _readController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _form(field: _plain, controller: controller, readOnly: true),
      );

      expect(find.byType(ZReadOnlyFieldCard), findsNWidgets(1));
      expect(find.byType(ZSelectFieldWidget), findsNothing);
    });
  });
}

Widget? _secondary(BuildContext context, ZSelectChoiceContext choice) => null;
