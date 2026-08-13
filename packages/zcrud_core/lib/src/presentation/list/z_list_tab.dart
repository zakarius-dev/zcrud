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
/// **Onglet gouverné** : au-delà du contexte de création, un onglet peut
/// porter ses **droits** ([ZListTab.acl], composés en cascade — voir plus
/// bas), ses **intitulés de formulaire** ([ZListTab.titles]) et son
/// **compteur** ([ZListTab.countOf]). Trois déclarations, toutes optionnelles :
/// un onglet qui n'en porte aucune se comporte exactement comme avant.
///
/// **La cascade RESTREINT, elle n'élargit jamais** : l'ACL d'un onglet est
/// composée en **conjonction** avec celle qui l'englobe (écran, puis scope) —
/// un onglet peut retirer un geste, jamais en rendre un que l'application a
/// refusé plus haut. Voir `zRestrictAcl`/`ZRestrictedAcl`.
///
/// **Neutre** : imports limités à `package:flutter/widgets.dart` + les
/// contrats neutres `ZFilter`/`ZAcl`. AUCUN `package:syncfusion`, AUCUN
/// backend.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../../domain/data/z_data_request.dart';
import '../../domain/ports/z_acl.dart';
import '../z_crud_titles.dart';

/// Descripteur **immuable** d'un onglet de catégorisation de [ZTabbedList].
@immutable
class ZListTab {
  /// Construit un onglet : [labelKey] (clé l10n résolue via `label`), [builder]
  /// (construit la vue de l'onglet), [icon] optionnelle,
  /// [defaultItemBuilder] optionnel (contexte de création de l'onglet),
  /// [pageKey] optionnelle (identité technique découplée du libellé),
  /// [canCreate] (autorisation de création de l'onglet, défaut `true`),
  /// [acl] (restriction de droits propre à l'onglet), [titles] (intitulés de
  /// formulaire de l'onglet), [countOf] (compteur affiché en pastille).
  const ZListTab({
    required this.labelKey,
    required this.builder,
    this.icon,
    this.baseFilters = const <ZFilter>[],
    this.defaultItemBuilder,
    this.pageKey,
    this.canCreate = true,
    this.acl,
    this.titles,
    this.countOf,
  });

  /// Fabrique **catégorie** (cas courant) : les [filters] de catégorie sont
  /// passés à [buildList], qui les branche typiquement en `baseFilters` sur le
  /// `ZListController`/`ZSubListScreen` de l'onglet — la catégorie ne peut alors
  /// JAMAIS être écrasée par une recherche/un filtre utilisateur.
  ///
  /// [defaultItemBuilder] optionnel : contexte de création de la catégorie
  /// (l'entité pré-remplie quand l'usager crée depuis cet onglet) — voir
  /// [ZListTab.defaultItemBuilder]. [pageKey] et [canCreate] : voir
  /// [ZListTab.pageKey] et [ZListTab.canCreate]. [acl], [titles] et [countOf] :
  /// voir [ZListTab.acl], [ZListTab.titles] et [ZListTab.countOf].
  factory ZListTab.category({
    required String labelKey,
    required List<ZFilter> filters,
    required Widget Function(BuildContext context, List<ZFilter> categoryFilters)
        buildList,
    IconData? icon,
    Object? Function()? defaultItemBuilder,
    String? pageKey,
    bool canCreate = true,
    ZAcl? acl,
    ZCrudTitles? titles,
    ValueListenable<int>? countOf,
  }) {
    return ZListTab(
      labelKey: labelKey,
      icon: icon,
      // La catégorie est AUSSI déclarée dans le modèle : la même liste de
      // filtres part au `buildList` (le chemin historique) et devient le socle
      // lisible par l'assembleur (voir [ZListTab.baseFilters]). Une seule
      // source, deux lecteurs — jamais deux déclarations à tenir d'accord.
      baseFilters: filters,
      defaultItemBuilder: defaultItemBuilder,
      pageKey: pageKey,
      canCreate: canCreate,
      acl: acl,
      titles: titles,
      countOf: countOf,
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

  /// **Restriction de droits** propre à l'onglet (`null` = aucune, défaut).
  ///
  /// Les droits d'un onglet se composent en **cascade** avec ceux qui
  /// l'englobent — l'écran, puis le scope de l'application — et la composition
  /// est une **conjonction** : un geste n'est offert dans l'onglet que si
  /// l'onglet **et** le niveau supérieur l'accordent.
  ///
  /// | Niveau | Rôle |
  /// |---|---|
  /// | Scope de l'application | droits de l'usager, valables partout |
  /// | Écran | droits de la ressource affichée |
  /// | **Onglet** | affinage du segment courant — **retire seulement** |
  ///
  /// Déclarer ici une autorisation généreuse ne rouvre donc **rien** : un
  /// geste refusé plus haut reste refusé. C'est ce qui rend l'oubli sans
  /// danger — au pire l'onglet ne restreint pas, jamais il n'ouvre.
  ///
  /// ```dart
  /// // Onglet « Clôturés » : plus aucune écriture, même pour un rédacteur.
  /// ZListTab(labelKey: 'closed', acl: const MesDroitsEnLecture(), builder: …)
  /// ```
  ///
  /// L'onglet applique cette restriction à **sa vue** (les listes construites
  /// par son `builder` la lisent via le scope) ; l'assemblage qui héberge les
  /// onglets l'applique en plus à ses propres gestes (le bouton de création
  /// d'un `ZCrudScreen`, par exemple).
  final ZAcl? acl;

  /// **Intitulés de formulaire** propres à l'onglet (`null` = ceux de
  /// l'écran, défaut).
  ///
  /// Un écran segmenté par **type d'entité** ouvre le même formulaire depuis
  /// des onglets différents : « Nouveau dossier » ici, « Nouvelle pièce »
  /// juste à côté. Sans cette déclaration, tous les onglets partagent le titre
  /// de l'écran — le défaut historique, et la cause du « Nouvel élément »
  /// générique de tous les écrans à onglets.
  ///
  /// Les titres se résolvent **par mode** (création / duplication / édition /
  /// consultation) : un `ZCrudTitles` d'onglet dont un mode est `null`
  /// retombe sur celui de l'écran, puis sur la clé l10n générique.
  final ZCrudTitles? titles;

  /// **Compteur** de l'onglet, affiché en pastille à côté du libellé
  /// (`null` = aucune pastille, défaut).
  ///
  /// C'est une `ValueListenable`, jamais un `int`, et c'est délibéré (AD-2) :
  /// la pastille s'abonne à cette valeur et se redessine **seule** quand elle
  /// change. Le contenu de l'onglet — sa liste, son défilement, sa sélection —
  /// n'est pas reconstruit pour autant.
  ///
  /// Le cœur ne compte **jamais** lui-même : compter, c'est interroger une
  /// source, et le faire à chaque rendu coûterait une lecture par image. La
  /// valeur vient donc de l'hôte, qui sait déjà d'où elle sort (un
  /// `ValueNotifier` alimenté par son dépôt, la longueur d'une liste en
  /// mémoire, un flux converti).
  ///
  /// Le notifieur est **possédé par l'hôte** (create/dispose de son côté) :
  /// l'onglet s'y abonne, il ne le dispose pas.
  final ValueListenable<int>? countOf;

  /// Icône optionnelle de l'onglet.
  final IconData? icon;

  /// **Socle de filtres de l'onglet**, déclaré dans le modèle (défaut
  /// `const []` ⇒ onglet non catégorisé, comportement inchangé).
  ///
  /// C'est la catégorie de l'onglet **rendue lisible** : jusqu'ici elle ne
  /// vivait que dans la fermeture de [ZListTab.category] (passée au
  /// `buildList`), donc invisible à qui héberge les onglets. Un assembleur —
  /// `ZCrudScreen` et ses semblables — ne pouvait pas composer la requête d'un
  /// onglet qu'il ne pouvait pas lire ; c'est chaque page qui devait aller
  /// chercher la politique de l'écran pour la mêler à sa catégorie.
  ///
  /// **Un socle, jamais un filtre utilisateur** : ces filtres sont destinés au
  /// `baseFilters` du `ZListController` de l'onglet, c'est-à-dire ANDés en tête
  /// de chaque requête et **hors d'atteinte** de `setFilters`/`setSearch` —
  /// chercher ou filtrer dans un onglet ne peut pas en faire sortir. C'est
  /// exactement la garantie que [ZListTab.category] offrait déjà ; elle est
  /// désormais déclarée plutôt que confiée à l'usage.
  ///
  /// Composer avec des filtres venus d'ailleurs se fait par [filtersWith], qui
  /// tient l'ordre (socle d'abord).
  final List<ZFilter> baseFilters;

  /// Compose le socle de l'onglet avec des filtres [extra] : le socle **en
  /// tête**, les autres ensuite.
  ///
  /// L'ordre porte l'intention : un socle qui vient en premier est un socle
  /// qu'aucun ajout ne peut annuler. La méthode **ajoute**, elle ne remplace
  /// jamais — un onglet reste dans sa catégorie quoi que l'on empile dessus.
  List<ZFilter> filtersWith(List<ZFilter> extra) {
    if (extra.isEmpty) return baseFilters;
    if (baseFilters.isEmpty) return extra;
    return <ZFilter>[...baseFilters, ...extra];
  }

  /// Copie de l'onglet avec les champs fournis remplacés (les autres
  /// inchangés).
  ///
  /// Sert aux **assembleurs** : envelopper la vue d'un onglet (pour y déposer
  /// une portée, une ACL, une politique de requête) sans avoir à recopier à la
  /// main les huit autres déclarations — recopie où l'on oublie tôt ou tard
  /// celle qui vient d'être ajoutée.
  ZListTab copyWith({
    String? labelKey,
    WidgetBuilder? builder,
    IconData? icon,
    List<ZFilter>? baseFilters,
    Object? Function()? defaultItemBuilder,
    String? pageKey,
    bool? canCreate,
    ZAcl? acl,
    ZCrudTitles? titles,
    ValueListenable<int>? countOf,
  }) {
    return ZListTab(
      labelKey: labelKey ?? this.labelKey,
      builder: builder ?? this.builder,
      icon: icon ?? this.icon,
      baseFilters: baseFilters ?? this.baseFilters,
      defaultItemBuilder: defaultItemBuilder ?? this.defaultItemBuilder,
      pageKey: pageKey ?? this.pageKey,
      canCreate: canCreate ?? this.canCreate,
      acl: acl ?? this.acl,
      titles: titles ?? this.titles,
      countOf: countOf ?? this.countOf,
    );
  }

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
