/// `ZListTab` — descripteur d'un **onglet de catégorisation** de [ZTabbedList]
/// (E4-5, étend FR-6 · AD-8/AD-13/SM-5).
///
/// origine: capacité « **onglets** » du §4.2 du PRD (rattachée à FR-6). Un onglet
/// porte une **clé de libellé l10n** (`labelKey`, résolue au rendu via `label`),
/// une **icône** optionnelle et un [WidgetBuilder] `builder` qui construit la vue
/// de l'onglet (typiquement une [DynamicList]/`ZListController` ou un
/// `ZSubListScreen`, catégorisé via `baseFilters`).
///
/// **Pourquoi un `WidgetBuilder`, pas un `ZListController`** : un contrôleur est
/// un `ChangeNotifier` à cycle de vie (create/dispose) — le figer dans un modèle
/// `const` violerait AD-2. Le `builder` laisse **chaque page** créer/posséder son
/// contrôleur dans un `State` keep-alive (cf. [ZTabbedList]). La catégorisation se
/// fait via les `baseFilters` fournis au contrôleur construit dans le `builder`.
///
/// **Neutre** : imports limités à `package:flutter/widgets.dart` + le contrat
/// neutre `ZFilter`. AUCUN `package:syncfusion`, AUCUN backend.
library;

import 'package:flutter/widgets.dart';

import '../../domain/data/z_data_request.dart';

/// Descripteur **immuable** d'un onglet de catégorisation de [ZTabbedList].
@immutable
class ZListTab {
  /// Construit un onglet : [labelKey] (clé l10n résolue via `label`), [builder]
  /// (construit la vue de l'onglet), [icon] optionnelle.
  const ZListTab({
    required this.labelKey,
    required this.builder,
    this.icon,
  });

  /// Fabrique **catégorie** (cas courant) : les [filters] de catégorie sont
  /// passés à [buildList], qui les branche typiquement en `baseFilters` sur le
  /// `ZListController`/`ZSubListScreen` de l'onglet — la catégorie ne peut alors
  /// JAMAIS être écrasée par une recherche/un filtre utilisateur (E4-5).
  factory ZListTab.category({
    required String labelKey,
    required List<ZFilter> filters,
    required Widget Function(BuildContext context, List<ZFilter> categoryFilters)
        buildList,
    IconData? icon,
  }) {
    return ZListTab(
      labelKey: labelKey,
      icon: icon,
      builder: (context) => buildList(context, filters),
    );
  }

  /// Clé l10n du libellé (résolue au rendu via `label(context, labelKey)`).
  final String labelKey;

  /// Icône optionnelle de l'onglet.
  final IconData? icon;

  /// Construit la vue de l'onglet (une `DynamicList`/`ZSubListScreen`, etc.).
  final WidgetBuilder builder;
}
