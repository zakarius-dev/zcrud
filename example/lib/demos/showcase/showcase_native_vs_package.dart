import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_select/zcrud_select.dart';

/// **Décisions natif-vs-package côte à côte** (fp-3-2, AC3 — D1/D2/D4 du
/// `FIELD-PACKAGE-MATRIX`). Les DEUX rendus coexistent visiblement, chacun par
/// son **adaptateur réel** (jamais un faux-rendu) ; la bascule est purement le
/// **seam `ZcrudScope` injecté** (présentateur / picker), pas un widget différent :
///
///  - **`select` NATIF** (aucun `selectPresenter`) — `ZSelectFieldWidget` rend le
///    dropdown natif — **vs** **modal riche** (`ZSmartSelectPresenter` injecté) —
///    le MÊME `ZSelectFieldWidget` délègue au présentateur (modal S2) ;
///  - **`color` built-in** (aucun `colorPicker`) — `ZColorFieldWidget` ouvre le
///    picker sliders neutre du cœur — **vs** **roue** (`ZcrudScope.colorPicker`
///    injecté) — le MÊME `ZColorFieldWidget` délègue au seam host-fourni.
///
/// Deux `ZcrudScope` imbriqués (l'un sans seam, l'autre avec) matérialisent les
/// deux voies sur un sous-arbre chacun (AD-4 : seams app-owned, jamais statiques).
class NativeVsPackageSection extends StatefulWidget {
  /// Construit la section comparative.
  const NativeVsPackageSection({super.key});

  @override
  State<NativeVsPackageSection> createState() => _NativeVsPackageSectionState();
}

class _NativeVsPackageSectionState extends State<NativeVsPackageSection> {
  // Contrôleurs STABLES (AD-2) — un par voie (créés 1×, jamais recréés).
  final ZFormController _selNative =
      ZFormController(initialValues: <String, Object?>{'choice': 'a'});
  final ZFormController _selModal =
      ZFormController(initialValues: <String, Object?>{'choice': 'a'});
  final ZFormController _colBuiltin =
      ZFormController(initialValues: <String, Object?>{'tone': null});
  final ZFormController _colWheel =
      ZFormController(initialValues: <String, Object?>{'tone': null});

  static const ZFieldSpec _selectField = ZFieldSpec(
    name: 'choice',
    type: EditionFieldType.select,
    label: 'Choix',
    choices: <ZFieldChoice>[
      ZFieldChoice(value: 'a', label: 'Option A'),
      ZFieldChoice(value: 'b', label: 'Option B'),
      ZFieldChoice(value: 'c', label: 'Option C'),
    ],
  );

  static const ZFieldSpec _colorField = ZFieldSpec(
    name: 'tone',
    type: EditionFieldType.color,
    label: 'Teinte',
  );

  /// Seam « roue » de démonstration (données seules, aucun secret) : renvoie une
  /// teinte dérivée sans plugin lourd. Suffit à prouver la voie seam (AC3).
  Future<int?> _demoWheelPicker(
    BuildContext context, {
    required int? initialArgb,
    required bool enableAlpha,
    required List<int> recentColors,
  }) async {
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Roue (seam de démo)'),
          content: Wrap(
            spacing: 8,
            children: <Widget>[
              for (final c in <Color>[
                scheme.primary,
                scheme.secondary,
                scheme.tertiary,
              ])
                IconButton(
                  icon: Icon(Icons.circle, color: c),
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(c.toARGB32()),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _selNative.dispose();
    _selModal.dispose();
    _colBuiltin.dispose();
    _colWheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey<String>('showcase-native-vs-package'),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Décisions natif vs package (côte à côte)',
                textAlign: TextAlign.start,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _Pair(
              leftLabel: 'select — NATIF',
              rightLabel: 'select — MODAL (ZSmartSelectPresenter)',
              left: _Slot(
                keyName: 'nvp-select-native',
                // Aucun presenter : rendu natif.
                child: ZcrudScope(
                  child: ZFieldWidget(
                      controller: _selNative, field: _selectField),
                ),
              ),
              right: _Slot(
                keyName: 'nvp-select-modal',
                child: ZcrudScope(
                  selectPresenter: const ZSmartSelectPresenter(),
                  child: ZFieldWidget(
                      controller: _selModal, field: _selectField),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Pair(
              leftLabel: 'color — sliders (built-in)',
              rightLabel: 'color — roue (seam colorPicker)',
              left: _Slot(
                keyName: 'nvp-color-builtin',
                // Aucun colorPicker : picker sliders neutre du cœur.
                child: ZcrudScope(
                  child: ZFieldWidget(
                      controller: _colBuiltin, field: _colorField),
                ),
              ),
              right: _Slot(
                keyName: 'nvp-color-wheel',
                child: ZcrudScope(
                  colorPicker: _demoWheelPicker,
                  child: ZFieldWidget(
                      controller: _colWheel, field: _colorField),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({
    required this.leftLabel,
    required this.rightLabel,
    required this.left,
    required this.right,
  });

  final String leftLabel;
  final String rightLabel;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(leftLabel, textAlign: TextAlign.start, style: style)),
            Expanded(child: Text(rightLabel, textAlign: TextAlign.start, style: style)),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            Expanded(child: right),
          ],
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.keyName, required this.child});

  final String keyName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<String>(keyName),
      child: child,
    );
  }
}
