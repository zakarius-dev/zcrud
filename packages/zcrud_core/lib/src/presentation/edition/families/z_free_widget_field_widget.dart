/// Widget de la **famille freeWidget** (`widget` libre) — E3-3b-3.
///
/// Le type `widget` rend un **widget d'édition host-fourni** résolu via le
/// [ZWidgetRegistry] injecté (`ZcrudScope.widgetRegistry`) — **exactement le même
/// seam** que les types [EditionFamily.registryOrFallback] (markdown/géo/tél/
/// `custom`, E3-3b-1). Le `kind` résolu est le **nom de l'enum** (`'widget'`,
/// aligné sur `ZTypeRegistry`). Si aucun builder n'est enregistré pour ce `kind`,
/// on **retombe** sur le repli contrôlé [ZUnsupportedFieldWidget] (jamais une
/// exception, AD-10).
///
/// **CONSOMME** le registre d'E3-3b-1 (ne le réimplémente pas, AD-4) : le cœur
/// reste agnostique du widget métier (aucun import satellite ; graphe OUT=0
/// inchangé). Le builder hôte lit `value` et écrit via `onChanged` **dans** la
/// frontière de rebuild du dispatcher (value-in-slice, AD-2) — s'il a besoin d'un
/// contrôleur isolé, c'est **sa** responsabilité (AD-7).
///
/// a11y/RTL (AD-13) : délégués au widget hôte (démo/satellite) ou au repli
/// accessible `ZUnsupportedFieldWidget`.
library;

import 'package:flutter/widgets.dart';

import '../../../domain/edition/z_field_spec.dart';
import '../../zcrud_scope.dart';
import '../z_widget_registry.dart';
import 'z_unsupported_field_widget.dart';

/// Champ d'édition **widget libre** : rend le widget host-fourni (registre) ou
/// le repli contrôlé si le `kind` n'est pas enregistré.
class ZFreeWidgetFieldWidget extends StatelessWidget {
  /// Construit le champ pour [field], valeur courante [value] (lue par le widget
  /// hôte), notifiant [onChanged] (branché sur `setValue` par le dispatcher).
  const ZFreeWidgetFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Spécification `const` du champ rendu (`type == EditionFieldType.widget`).
  final ZFieldSpec field;

  /// Valeur COURANTE de la tranche `field.name` (lue par le builder hôte).
  final Object? value;

  /// Écrit une nouvelle valeur dans la tranche (branché sur `setValue`).
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    final registry = ZcrudScope.maybeOf(context)?.widgetRegistry;
    // Convention `kind` alignée sur `ZTypeRegistry` : le nom de l'enum
    // (`'widget'`). L'app enregistre codec + widget sous le même `kind`.
    final builder = registry?.tryBuilderFor(field.type.name);
    if (builder == null) {
      return ZUnsupportedFieldWidget(field: field);
    }
    return builder(
      context,
      ZFieldWidgetContext(field: field, value: value, onChanged: onChanged),
    );
  }
}
