import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../binding/binding_selector.dart';

/// Écran de démo GEO (EX-3, AC4, AC10). Monte une [DynamicEdition] sur un
/// `ZFormController` **stable** avec un schéma portant un `location` ET un
/// `geoArea`. Ces champs sont résolus par le `demoWidgetRegistry` **injecté au
/// scope RACINE** (`app.dart`) — `ZGeoFieldWidget.builder(adapterFactory:
/// ZOsmMapAdapter.new)`, carte OSM SANS clé (AD-12). Valeurs de tranche NEUTRES
/// (`ZGeoPoint`/`ZGeoShape`).
///
/// Parité multi-binding (AC10) : `BindingSelector` + `wrapWithBinding(rootScope:
/// ZcrudScope.maybeOf(context))` + `KeyedSubtree(ValueKey(binding))` — un NOUVEAU
/// controller par wrap, dispose propre (MAJEUR-1 EX-1). La re-propagation de
/// `root.widgetRegistry` par `_BindingSeamForwarder` rend les champs géo sous les
/// 4 voies (jamais `ZUnsupportedFieldWidget`).
class GeoDemoScreen extends StatefulWidget {
  /// Construit l'écran de démo géo.
  const GeoDemoScreen({this.initialBinding = DemoBinding.scope, super.key});

  /// Binding initial (permet aux tests de cibler un wrap donné).
  final DemoBinding initialBinding;

  @override
  State<GeoDemoScreen> createState() => _GeoDemoScreenState();
}

class _GeoDemoScreenState extends State<GeoDemoScreen> {
  /// Schéma géo : un point (`location`) + une aire (`geoArea`).
  static const List<ZFieldSpec> _fields = <ZFieldSpec>[
    ZFieldSpec(
      name: 'position',
      type: EditionFieldType.location,
      label: 'Position (point)',
    ),
    ZFieldSpec(
      name: 'zone',
      type: EditionFieldType.geoArea,
      label: 'Zone (aire)',
    ),
  ];

  late DemoBinding _binding;
  late ZFormController _controller;

  @override
  void initState() {
    super.initState();
    _binding = widget.initialBinding;
    _controller = _newController();
  }

  /// Controller seedé : `visibleFields` = noms des champs (sinon `DynamicEdition`
  /// n'affiche rien — il ne rend que `controller.visibleFields`).
  ZFormController _newController() => ZFormController(
        initialValues: <String, Object?>{
          for (final f in _fields) f.name: null,
        },
      );

  void _changeBinding(DemoBinding next) {
    if (next == _binding) return;
    // AC10 : un NOUVEAU controller par wrap ; dispose propre de l'ancien.
    final old = _controller;
    setState(() {
      _binding = next;
      _controller = _newController();
    });
    old.dispose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Démo Geo (E11a)')),
      body: KeyedSubtree(
        key: ValueKey<DemoBinding>(_binding),
        // Capte le scope RACINE (dont `widgetRegistry`) pour le re-propager SOUS
        // le scope du binding (sinon masqué → champs géo inertes sous get/
        // riverpod/provider).
        child: wrapWithBinding(
          _binding,
          _buildBody(),
          rootScope: ZcrudScope.maybeOf(context),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BindingSelector(value: _binding, onChanged: _changeBinding),
        Expanded(
          child: DynamicEdition(
            controller: _controller,
            fields: _fields,
            padding: const EdgeInsetsDirectional.all(12),
          ),
        ),
      ],
    );
  }
}
