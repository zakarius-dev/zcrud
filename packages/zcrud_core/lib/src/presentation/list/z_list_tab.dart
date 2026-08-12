/// `ZListTab` — descripteur d'un **onglet de catégorisation** de [ZTabbedList]
/// (AD-8/AD-13).
///
/// Un onglet porte une **clé de libellé l10n** (`labelKey`, résolue au rendu
/// via `label`), une **icône** optionnelle et un [WidgetBuilder] `builder` qui
/// construit la vue de l'onglet (typiquement une [DynamicList]/`ZListController`
/// ou un `ZSubListScreen`, catégorisé via `baseFilters`).
///
/// **Pourquoi un `WidgetBuilder`, pas un `ZListController`** : un contrôleur est
/// un `ChangeNotifier` à cycle de vie (create/dispose) — le figer dans un modèle
/// `const` violerait AD-2. Le `builder` laisse **chaque page** créer/posséder son
/// contrôleur dans un `State` keep-alive (cf. [ZTabbedList]). La catégorisation se
/// fait via les `baseFilters` fournis au contrôleur construit dans le `builder`.
///
/// **Contexte de création par onglet** : un onglet segmenté porte souvent, en
/// plus de son filtre, la **valeur pré-remplie** de toute entité créée depuis
/// cet onglet (« liste segmentée par statut, la création hérite du segment
/// courant »). Le seam [ZListTab.defaultItemBuilder] transporte ce contexte
/// dans le modèle : le geste de création de l'app (FAB, bouton de barre…)
/// lit l'onglet actif (via `ZTabbedList.onTabChanged` → `tabs[index]`) et
/// appelle `defaultItemBuilder?.call()` pour obtenir la valeur initiale.
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
  /// (construit la vue de l'onglet), [icon] optionnelle,
  /// [defaultItemBuilder] optionnel (contexte de création de l'onglet),
  /// [pageKey] optionnelle (identité technique découplée du libellé),
  /// [canCreate] (autorisation de création de l'onglet, défaut `true`).
  const ZListTab({
    required this.labelKey,
    required this.builder,
    this.icon,
    this.defaultItemBuilder,
    this.pageKey,
    this.canCreate = true,
  });

  /// Fabrique **catégorie** (cas courant) : les [filters] de catégorie sont
  /// passés à [buildList], qui les branche typiquement en `baseFilters` sur le
  /// `ZListController`/`ZSubListScreen` de l'onglet — la catégorie ne peut alors
  /// JAMAIS être écrasée par une recherche/un filtre utilisateur.
  ///
  /// [defaultItemBuilder] optionnel : contexte de création de la catégorie
  /// (l'entité pré-remplie quand l'usager crée depuis cet onglet) — voir
  /// [ZListTab.defaultItemBuilder]. [pageKey] et [canCreate] : voir
  /// [ZListTab.pageKey] et [ZListTab.canCreate].
  factory ZListTab.category({
    required String labelKey,
    required List<ZFilter> filters,
    required Widget Function(BuildContext context, List<ZFilter> categoryFilters)
        buildList,
    IconData? icon,
    Object? Function()? defaultItemBuilder,
    String? pageKey,
    bool canCreate = true,
  }) {
    return ZListTab(
      labelKey: labelKey,
      icon: icon,
      defaultItemBuilder: defaultItemBuilder,
      pageKey: pageKey,
      canCreate: canCreate,
      builder: (context) => buildList(context, filters),
    );
  }

  /// Clé l10n du libellé (résolue au rendu via `label(context, labelKey)`).
  final String labelKey;

  /// **Identité technique** optionnelle de l'onglet, découplée du libellé.
  ///
  /// `ZTabbedList` dérive la clé de page keep-alive (et son assert d'unicité)
  /// de [resolvedPageKey] = `pageKey ?? labelKey`. Fournir une [pageKey]
  /// permet : (1) **deux onglets homonymes** (même libellé métier, clés
  /// distinctes) ; (2) de **renommer un libellé** sans changer l'identité de
  /// la page (l'état keep-alive de l'onglet survit au renommage).
  ///
  /// `null` (défaut) = repli sur [labelKey] — strictement le comportement
  /// antérieur, rien ne change pour les consommateurs existants.
  final String? pageKey;

  /// Clé de page **effective** de l'onglet : [pageKey] si fournie, sinon
  /// [labelKey]. C'est cette valeur que `ZTabbedList` utilise comme clé de
  /// page keep-alive et qui doit être **unique** parmi les onglets.
  String get resolvedPageKey => pageKey ?? labelKey;

  /// **Autorisation de création** de l'onglet (défaut `true`) — le pendant de
  /// [defaultItemBuilder] : si l'onglet porte le **contexte** de création, il
  /// porte aussi son **autorisation**. `false` = onglet en lecture seule pour
  /// la création (le geste de création de l'app — FAB, bouton de barre… — se
  /// masque ou se désactive quand l'onglet actif ne l'autorise pas).
  ///
  /// Comme [defaultItemBuilder], le cœur **transporte** cette autorisation
  /// sans la consommer : c'est le geste de création de l'app qui la lit
  /// (`tabs[index].canCreate`), typiquement via l'index actif exposé par
  /// `ZTabbedList.activeIndexNotifier`.
  final bool canCreate;

  /// Icône optionnelle de l'onglet.
  final IconData? icon;

  /// Construit la vue de l'onglet (une `DynamicList`/`ZSubListScreen`, etc.).
  final WidgetBuilder builder;

  /// **Contexte de création** optionnel de l'onglet : fabrique la **valeur
  /// initiale** (typiquement l'entité pré-remplie, ou un `Map` de valeurs)
  /// de toute création déclenchée **depuis cet onglet** — motif « la création
  /// hérite du segment courant » (un onglet par statut/type, chaque création
  /// naît dans le statut/type de l'onglet actif).
  ///
  /// `null` (défaut) = l'onglet ne porte aucun contexte de création (onglet de
  /// consultation pure, ou création uniforme quelle que soit la catégorie).
  ///
  /// Le retour est **opaque** (`Object?`) : le cœur transporte le contexte
  /// sans l'interpréter — c'est le geste de création de l'app qui le
  /// consomme. Câblage typique avec `ZTabbedList` :
  ///
  /// ```dart
  /// var activeTab = tabs[0];
  /// ZTabbedList(
  ///   tabs: tabs,
  ///   onTabChanged: (index) => activeTab = tabs[index],
  /// );
  /// // FAB / bouton « créer » de l'app :
  /// final seed = activeTab.defaultItemBuilder?.call();
  /// ```
  ///
  /// C'est une **fabrique** (et non une valeur figée) : chaque création
  /// obtient une instance fraîche (aucun partage accidentel d'un objet
  /// mutable entre deux créations).
  final Object? Function()? defaultItemBuilder;
}
