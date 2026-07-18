/// Enrôlement des champs spécialisés `zcrud_field_extras` (fp-5-2, AD-53) dans
/// un `ZWidgetRegistry` — patron `registerZMediaFieldWidgets`/`registerZHtmlFields`.
///
/// Enregistre les trois builders riches sous des `kind` **alignés sur les noms
/// d'`EditionFieldType`** ([pinFieldKind]/[autocompleteFieldKind]/
/// [editableTableFieldKind]) — les seuls que le dispatcher cœur résout
/// (`registry.tryBuilderFor(field.type.name)`). Un `kind` non aligné serait du
/// code mort en intégration (leçon fp-4-2).
///
/// **Point d'enrôlement EXPLICITE** : à appeler au **bootstrap** du binding/app,
/// jamais un side-effect d'import. Le cœur reste agnostique (aucune modif de
/// `zcrud_core`, aucune dépendance lourde tirée — AD-1, CORE OUT=0).
///
/// Chaque `kind` est enrôlé **une seule fois** : un double appel sur le même
/// registre lève `ZDuplicateRegistrationError` (jamais un last-wins silencieux —
/// contrat `ZWidgetRegistry.register`).
///
/// ⚠️ **« tags riches » NON enrôlé (SIGNAL cœur, AC-D)** : `EditionFieldType.tags`
/// route vers la famille NATIVE `tags` (pas `registryOrFallback`) — un `kind ==
/// 'tags'` serait du code mort. Le besoin est déjà couvert zéro-dép par
/// `ZSubListDisplayMode.tags` (fp-5-1). Un chemin dispatcher-atteignable
/// exigerait un NOUVEAU type d'enum cœur (`richTags`) — décision owner requise.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_autocomplete_field_widget.dart';
import 'z_editable_table_field_widget.dart';
import 'z_pin_field_widget.dart';

/// Enregistre les builders `pin`/`autocomplete`/`editableTable` dans [registry]
/// sous leurs `kind` alignés sur `EditionFieldType.<type>.name`.
///
/// [onBuild] est un hook de test partagé (SM-1) propagé aux trois widgets.
void registerZFieldExtrasFields(
  ZWidgetRegistry registry, {
  VoidCallback? onBuild,
}) {
  registry.register(pinFieldKind, ZPinFieldWidget.builder(onBuild: onBuild));
  registry.register(
    autocompleteFieldKind,
    ZAutocompleteFieldWidget.builder(onBuild: onBuild),
  );
  registry.register(
    editableTableFieldKind,
    ZEditableTableFieldWidget.builder(onBuild: onBuild),
  );
}
