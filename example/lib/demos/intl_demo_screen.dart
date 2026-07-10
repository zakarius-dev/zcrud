import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../binding/binding_selector.dart';

/// Écran de démo INTL (EX-3, AC5, AC10). Monte une [DynamicEdition] sur un
/// `ZFormController` **stable** avec un schéma `phoneNumber` + `country` +
/// `address`. Ces champs sont résolus par le `demoWidgetRegistry` injecté au
/// scope RACINE (`ZPhoneFieldWidget.builder` / `ZCountryFieldWidget.builder` /
/// `ZAddressFieldWidget.builder`, `ZCountryCatalog` partagé). Valeurs de tranche
/// neutres (`ZPhoneNumber` E.164 / code ISO alpha-2 / `ZPostalAddress`).
///
/// Le champ téléphone **valide + normalise** en E.164 : un numéro valide produit
/// une valeur `ZPhoneNumber` neutre, un numéro invalide est signalé par le champ.
///
/// Parité multi-binding (AC10) comme `GeoDemoScreen`.
class IntlDemoScreen extends StatefulWidget {
  /// Construit l'écran de démo intl.
  const IntlDemoScreen({this.initialBinding = DemoBinding.scope, super.key});

  /// Binding initial (permet aux tests de cibler un wrap donné).
  final DemoBinding initialBinding;

  @override
  State<IntlDemoScreen> createState() => _IntlDemoScreenState();
}

class _IntlDemoScreenState extends State<IntlDemoScreen> {
  /// Schéma intl : téléphone + pays + adresse.
  static const List<ZFieldSpec> _fields = <ZFieldSpec>[
    ZFieldSpec(
      name: 'phone',
      type: EditionFieldType.phoneNumber,
      label: 'Téléphone',
    ),
    ZFieldSpec(
      name: 'country',
      type: EditionFieldType.country,
      label: 'Pays',
    ),
    ZFieldSpec(
      name: 'address',
      type: EditionFieldType.address,
      label: 'Adresse',
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
      appBar: AppBar(title: const Text('Démo Intl (E11a)')),
      body: KeyedSubtree(
        key: ValueKey<DemoBinding>(_binding),
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
