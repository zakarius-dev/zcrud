// AC7 (finding L3) — Garde `KeyedSubtree` : `DynamicEdition._buildField`
// enveloppe la sortie du `fieldBuilder` (custom OU dispatcher) dans
// `KeyedSubtree(key: ValueKey(field.name))`. Un `fieldBuilder` custom qui
// OMET la clé reste tout de même keyé sur `field.name` (place stable NON
// contournable → rebuild externe ⇒ Element/State réutilisés, préserve UJ-2).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Sonde stateful SANS clé explicite : compte ses `initState` par nom de champ.
class _ProbeField extends StatefulWidget {
  const _ProbeField({required this.name, required this.inits});
  final String name;
  final Map<String, int> inits;
  @override
  State<_ProbeField> createState() => _ProbeFieldState();
}

class _ProbeFieldState extends State<_ProbeField> {
  @override
  void initState() {
    super.initState();
    widget.inits[widget.name] = (widget.inits[widget.name] ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) => Text('probe-${widget.name}');
}

void main() {
  testWidgets(
      'fieldBuilder custom SANS clé → toujours keyé sur field.name (L3/AC7)',
      (tester) async {
    final inits = <String, int>{};
    final controller = ZFormController(
      initialValues: const <String, Object?>{'a': '', 'b': ''},
      visibleFields: const <String>['a', 'b'],
    );
    addTearDown(controller.dispose);

    // Rebuild d'ancêtre piloté par un signal externe.
    final tick = ValueNotifier<int>(0);
    addTearDown(tick.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: tick,
            builder: (context, _, __) => DynamicEdition(
              controller: controller,
              fields: const <ZFieldSpec>[
                ZFieldSpec(name: 'a', type: EditionFieldType.text),
                ZFieldSpec(name: 'b', type: EditionFieldType.text),
              ],
              // Builder custom qui OMET délibérément toute ValueKey.
              fieldBuilder: (context, ctrl, field) =>
                  _ProbeField(name: field.name, inits: inits),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // (1) La clé est appliquée par _buildField (KeyedSubtree), pas par le builder.
    expect(find.byKey(const ValueKey<String>('a')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('b')), findsOneWidget);
    expect(inits['a'], 1);
    expect(inits['b'], 1);

    // (2) Plusieurs rebuilds d'ancêtre → State réutilisé (place stable keyée).
    for (var i = 0; i < 5; i++) {
      tick.value = tick.value + 1;
      await tester.pump();
    }
    expect(inits['a'], 1, reason: 'State jamais recréé (keyé sur field.name)');
    expect(inits['b'], 1);
  });
}
