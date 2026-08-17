/// `ZCrudScreen<T>` — écran CRUD **assemblé et déclaratif**.
///
/// La pièce qui prend une déclaration (`title` + `source`) et rend un écran
/// fonctionnel en câblant, une fois pour toutes, les briques publiques
/// existantes : `DynamicList`/`ZTabbedList` (rendu), `ZListController`
/// (recherche/tri/pagination), `ZRowAction` (actions de ligne gouvernées
/// `ZAcl`), `presentEdition`/`ZPresentationPolicy` (présentation du
/// formulaire), `DynamicEdition`/`ZFormController` (édition),
/// `ZRepository`/`ZDataRequest.deletedScope` (données et corbeille, plus le
/// mixin optionnel `ZPurgeable` pour la suppression définitive).
///
/// **Principe directeur** : tout ce qui est dérivable d'une déclaration
/// existante ne se redemande jamais — les champs et la projection en cellules
/// se dérivent du `ZcrudRegistry` (`kindOf<T>` → `fieldSpecsFor` /
/// `encode`), l'ACL du `ZcrudScope` ambiant, le mode de présentation du
/// breakpoint. Chaque dérivation reste **remplaçable** par un paramètre.
///
/// **Assemblage mince** : aucune logique qui n'existe pas déjà dans les
/// briques ; un consommateur qui a un cas particulier descend d'un cran
/// (utiliser `DynamicList` directement) sans rien perdre.
///
/// **La coquille de page vient de `zcrud_ui_kit`, elle n'est pas refaite
/// ici** : `ZPageScaffold` (donc `ZSearchableAppBar`) porte le `Scaffold`,
/// l'app-bar, les actions déclarées en données (`ZAppBarAction`, avec son
/// menu de débordement) et la recherche intégrée (`ZAppBarSearchConfig`,
/// titre qui morphe en champ, `Échap` ⇒ fermeture) ; `showZConfirmDialog`
/// porte la confirmation des gestes destructifs ; `ZToaster`/`ZToasterScope`
/// portent la notification d'échec des actions de ligne. Les états
/// vide/chargement/erreur du listing restent rendus par `DynamicList`
/// lui-même (aucun état n'est doublé ici).
///
/// **La navigation de l'application, elle, reste à l'application** : l'écran
/// ne fournit aucun menu, mais relaie `drawer`/`endDrawer` au `Scaffold` du
/// socle — y compris sur l'état « accès refusé » —, pour qu'un écran migré ne
/// devienne jamais un cul-de-sac dont on ne sort qu'en quittant l'app.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart'
    show ZFormWeight, ZPresentationPolicy, presentEdition;
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart'
    show
        ZAppBarAction,
        ZAppBarSearchConfig,
        ZConfirmTone,
        ZCountBadge,
        ZErrorState,
        ZPageScaffold,
        ZToastSeverity,
        ZToasterScope,
        showZConfirmDialog,
        zToast;

import 'z_app_bar_actions_builder.dart';
import 'z_crud_edition_scope.dart';
import 'z_crud_screen_actions.dart';
import 'z_crud_source.dart';
import 'z_export_policy.dart';
import 'z_history_sheet.dart';
import 'z_list_query_policy.dart';
import 'z_list_tabs_store.dart';
import 'z_row_action_menu.dart';
import 'z_row_actions_presentation.dart';
import 'z_row_tint.dart';
import 'z_screen_mode.dart';
import 'z_selection_policy.dart';

/// Mode d'ouverture de la surface d'édition — sélectionne le titre affiché
/// ([ZCrudTitles]), distingue la **duplication** de la création nue et la
/// **consultation** de l'édition.
enum _ZCrudEditionMode {
  /// Création (bouton « + ») — formulaire vide ou pré-semé.
  create,

  /// Duplication (geste « dupliquer ») — création pré-remplie d'une copie
  /// **sans identité** de l'entité source.
  duplicate,

  /// Édition d'une entité existante (action de ligne).
  update,

  /// **Consultation** d'une entité existante : la même surface, le même
  /// formulaire, rendu en lecture seule (fiche de détail).
  read,
}

/// Activation de la **corbeille** d'un [ZCrudScreen].
enum ZTrashMode {
  /// La corbeille est offerte dès que la source la supporte
  /// ([ZCrudSource.supportsTrash]) et que l'ACL l'autorise — défaut.
  auto,

  /// La corbeille n'existe pas : aucune bascule, aucune action de ligne
  /// soft-delete/restore — quel que soit le support de la source (journal
  /// immuable, référentiel en lecture seule).
  none,
}

/// Fabrique du **formulaire d'édition** d'une entité, voie d'échappement de
/// l'édition dérivée.
///
/// `initial == null` ⇒ création ; non-`null` ⇒ édition. [save] persiste via la
/// voie de sauvegarde de l'écran (`onSave` → `source.onSave` →
/// `repository.save`) puis rafraîchit la liste — le formulaire reste
/// responsable de **se fermer** (`Navigator.pop`) après un [save] réussi. En
/// cas d'échec de persistance, [save] lève un [StateError] portant le message
/// de la `ZFailure`.
typedef ZCrudEditionBuilder<T> =
    Widget Function(BuildContext context, T? initial, ZCrudSave<T> save);

/// Rendu d'une tuile de liste, voie d'échappement du rendu par défaut.
typedef ZCrudItemBuilder<T> =
    Widget Function(BuildContext context, T item, List<ZListColumn> columns);

/// Écran CRUD assemblé : liste + recherche + création + édition + sauvegarde
/// + corbeille, à partir d'une déclaration.
///
/// Déclaration **minimale** (le type `T` est enregistré au `ZcrudRegistry`,
/// champs et cellules sont dérivés du schéma généré) :
///
/// ```dart
/// ZCrudScreen<Consignee>(
///   title: 'Consignataires',
///   source: ZCrudSource.repository(repo),
///   registry: registry,
/// )
/// ```
///
/// Tout est ensuite surchargeable : [listFields]/[formFields] (schémas),
/// [cellsOf] (projection), [acl] (sinon `ZcrudScope.acl` ambiant), [policy]
/// (présentation), [layout]/[itemBuilder] (rendu), [tabs] (onglets),
/// [editionBuilder] (formulaire complet), [onSave] (persistance).
///
/// ## Cas exprimables par déclaration
///
/// * `canCreate: false` — aucun bouton de création ;
/// * `trash: ZTrashMode.none` — aucune corbeille ;
/// * `trashPolicy: ZTrashPolicy.withoutPurge` — corbeille dont rien ne
///   disparaît, même si le dépôt sait supprimer définitivement ;
/// * `detailsEnabled: true` — la **fiche de détail comme geste de ligne** :
///   l'écran reste complet (création, corbeille, restauration) et le tap sur
///   une ligne ouvre le formulaire entier en lecture seule ;
/// * `mode: ZScreenMode.details` — **écran de consultation** : la fiche, sans
///   création ni corbeille ;
/// * `mode: ZScreenMode.locked` — consultation verrouillée (ni création, ni
///   fiche, ni édition, ni corbeille) ;
/// * `rowColor: (context, entity) => …` — **coloration de ligne** décidée sur
///   l'entité typée (cf. [ZRowTint]) ;
/// * `ZCrudSource.items(rows)` **sans callbacks** — lecture seule effective ;
/// * `ZCrudSource.readOnlyRepository(repo)` — **ressource immuable servie par
///   un dépôt** : pagination, tri et recherche serveur restent entiers, mais
///   ni création, ni édition, ni corbeille n'existent, quelle que soit l'ACL
///   (cf. [ZCrudSource.readOnlyRepository]).
class ZCrudScreen<T extends ZEntity> extends StatefulWidget {
  /// Construit l'écran assemblé — seuls [title] et [source] sont requis.
  const ZCrudScreen({
    required this.title,
    required this.source,
    this.registry,
    this.kind,
    this.listFields,
    this.formFields,
    this.cellsOf,
    this.acl,
    this.policy = const ZPresentationPolicy(),
    this.formWeight = ZFormWeight.light,
    this.layout,
    this.itemBuilder,
    this.tabs,
    this.tabsScrollable = false,
    this.tabsStore,
    this.tabsScopeKey,
    this.query = const ZListQueryPolicy(),
    this.header,
    this.canCreate = true,
    this.canDuplicate = true,
    this.titles,
    this.trash = ZTrashMode.auto,
    this.trashPolicy = ZTrashPolicy.full,
    this.trashCount,
    this.mode = ZScreenMode.full,
    this.detailsEnabled = false,
    this.rowColor,
    @Deprecated(
      'Utiliser `mode` : `readOnly: true` devient `mode: ZScreenMode.locked`, '
      'et la fiche de détail (lecture seule AVEC retour vers l\'édition) '
      'devient `mode: ZScreenMode.details`. Sera retiré en 1.0.',
    )
    this.readOnly = false,
    this.searchEnabled = true,
    this.onSave,
    this.editionBuilder,
    this.defaultItemBuilder,
    this.history,
    this.rowActions,
    this.trashRowActions,
    this.columnPolicy,
    this.collectionId,
    this.actions = const <ZAppBarAction>[],
    this.actionsBuilder,
    this.appBarActions = const <Widget>[],
    this.leading,
    this.drawer,
    this.endDrawer,
    this.rowAcl,
    this.actionAclMode = ZActionAclMode.hide,
    this.rowActionsPresentation = ZRowActionsPresentation.inline,
    this.inlineActionLimit = 2,
    this.longPressOwner = ZRowLongPressOwner.contextMenu,
    this.confirmDestructive = true,
    this.selection,
    this.batchActions,
    this.export,
    super.key,
  });

  /// Titre de l'écran — clé l10n ou littéral (résolu via `label(context, …)`,
  /// repli sur le littéral lui-même).
  final String title;

  /// Source de données déclarative (repository ou items + callbacks).
  final ZCrudSource<T> source;

  /// Registre de modèles servant la **dérivation** : champs
  /// (`fieldSpecsFor`), cellules (`encode`) et reconstruction d'entité
  /// (`decode`). `null` ⇒ [listFields] + [cellsOf] deviennent requis, et
  /// l'édition exige [editionBuilder].
  final ZcrudRegistry? registry;

  /// `kind` explicite du modèle — requis seulement quand `T` est enregistré
  /// sous **plusieurs** kinds (sinon `registry.kindOf<T>()` le résout seul).
  final String? kind;

  /// Schéma des colonnes de liste. `null` ⇒ dérivé du registre.
  final List<ZFieldSpec>? listFields;

  /// Schéma des champs du formulaire dérivé. `null` ⇒ dérivé du registre
  /// (champs `isId` exclus). Ignoré si [editionBuilder] est fourni.
  final List<ZFieldSpec>? formFields;

  /// Projection `T → cellules` (indexées par `field.name`). `null` ⇒ dérivée
  /// du registre (`encode`, clés persistées = noms de specs générées).
  final Map<String, Object?> Function(T item)? cellsOf;

  /// ACL de l'écran. `null` ⇒ l'ACL du `ZcrudScope` ambiant s'applique telle
  /// quelle ; non-`null` ⇒ posée par `ZcrudScope.derive` autour de la liste.
  ///
  /// **Refus par défaut.** Sans ACL déclarée — ni ici, ni au scope — aucun
  /// geste n'est offert, et `ZCrudAction.view` étant refusé, l'écran rend un
  /// **état « accès refusé »** sans jamais interroger la source. Déclarez la
  /// vôtre (`acl: MonAcl()`), ou, en développement, déclarez l'ouverture
  /// totale : `acl: const ZAllowAllAcl()`.
  final ZAcl? acl;

  /// Politique de présentation du formulaire (breakpoint → page/sheet/dialog).
  final ZPresentationPolicy policy;

  /// Poids du formulaire, critère de la politique de présentation.
  final ZFormWeight formWeight;

  /// Variante de vue de la liste. `null` ⇒ liste verticale
  /// (`ZListBuilderLayout`) rendant [itemBuilder], ou la tuile générique du
  /// paquet à défaut.
  ///
  /// Le layout déclaré ici **reçoit** [itemBuilder] : une grille de cartes
  /// métier se déclare `layout: const ZListGridLayout(mainAxisExtent: 180)` +
  /// `itemBuilder: (context, entity, columns) => MaCarte(entity)`, sans que
  /// l'application n'ait à reconstruire l'index `ligne → entité`.
  final ZListLayout? layout;

  /// Rendu d'une tuile — il **reçoit l'entité `T`**, pas la ligne neutre.
  ///
  /// Il alimente le [layout] déclaré (liste, grille de cartes) aussi bien que
  /// le rendu par défaut. Un layout construit avec sa **propre** tuile
  /// (`ZListGridLayout(itemBuilder: …)`, qui reçoit une `ZListRow`) garde la
  /// sienne : l'explicite l'emporte sur l'injecté.
  final ZCrudItemBuilder<T>? itemBuilder;

  /// Onglets de catégorisation. Non-`null` ⇒ le corps est un `ZTabbedList` ;
  /// le bouton de création lit `canCreate` et `defaultItemBuilder` de
  /// l'**onglet actif**.
  ///
  /// Un onglet se déclare sous l'une de deux formes, et la présence de son
  /// `ZListTab.builder` suffit à trancher :
  ///
  /// * **onglet assemblé** (`builder` absent — la forme à préférer) : l'onglet
  ///   ne déclare que sa **catégorie** (`baseFilters`) et, s'il y a lieu, sa
  ///   restriction de droits (`acl`). L'écran construit alors sa liste
  ///   **exactement comme il construirait la sienne** — même schéma de
  ///   colonnes, mêmes tuiles, mêmes actions de ligne (consulter, modifier,
  ///   dupliquer, mettre à la corbeille), même filtrage par les droits, même
  ///   recherche. L'écran n'a rien à redéclarer : la catégorie de l'onglet
  ///   s'ajoute aux filtres permanents de [query], et ses droits se composent
  ///   en **conjonction** avec ceux de l'écran ;
  /// * **onglet à builder** : l'onglet rend ce qu'il veut (vue carte, carte
  ///   mentale, tableau de bord). L'écran ne connaît pas ce qu'il rend et n'y
  ///   accroche donc **ni actions de ligne, ni recherche** — c'est le prix de
  ///   la liberté totale, et il est assumé.
  ///
  /// Les deux formes cohabitent dans une même barre. Mais un seul onglet à
  /// builder suffit à retirer la **barre de recherche partagée** de l'écran
  /// (voir [searchEnabled]) et les **onglets de la corbeille** : l'écran ne
  /// propose pas ce qu'il ne pourrait honorer que sur une partie des onglets.
  ///
  /// ```dart
  /// tabs: <ZListTab>[
  ///   ZListTab(labelKey: 'enCours', baseFilters: <ZFilter>[
  ///     ZFilter('statut', ZFilterOp.eq, 'enCours'),
  ///   ]),
  ///   ZListTab(labelKey: 'clos', baseFilters: <ZFilter>[
  ///     ZFilter('statut', ZFilterOp.eq, 'clos'),
  ///   ], acl: const MesDroitsEnLecture()),
  /// ],
  /// ```
  final List<ZListTab>? tabs;

  /// Barre d'onglets **défilante** (défaut `false` = onglets répartis sur la
  /// largeur).
  ///
  /// À passer à `true` dès que le nombre d'onglets dépasse ce qu'une barre
  /// fixe peut afficher lisiblement : au-delà de quatre ou cinq libellés, une
  /// barre fixe les tronque, une barre défilante les laisse entiers. Sans
  /// [tabs], le réglage est sans effet.
  final bool tabsScrollable;

  /// **Persistance de l'onglet actif et du défilement de chaque onglet**, entre
  /// deux ouvertures de l'écran.
  ///
  /// `null` (défaut) ⇒ aucune persistance : **aucune lecture, aucune
  /// écriture**, l'écran rouvre sur le premier onglet en haut de liste, comme
  /// avant. Déclarer un [ZListTabsStore] suffit à ce que l'écran retrouve
  /// l'onglet quitté **et** la position de défilement **de chacun** de ses
  /// onglets — le paquet ne connaît pas le stockage, il ne connaît que le port.
  ///
  /// ```dart
  /// class OngletsPersistants extends ZListTabsStore {
  ///   const OngletsPersistants(this._box);
  ///   final GetStorage _box;
  ///
  ///   @override
  ///   int? loadTabIndex(String scopeKey) => _box.read<int>('$scopeKey/index');
  ///
  ///   @override
  ///   void saveTabIndex(String scopeKey, int index) =>
  ///       _box.write('$scopeKey/index', index);
  ///
  ///   @override
  ///   double? loadScrollOffset(String scopeKey, int tabIndex) =>
  ///       _box.read<double>('$scopeKey/offset/$tabIndex');
  ///
  ///   @override
  ///   void saveScrollOffset(String scopeKey, int tabIndex, double offset) =>
  ///       _box.write('$scopeKey/offset/$tabIndex', offset);
  /// }
  /// ```
  ///
  /// **Lecture tolérante** (AD-10) : index absent ⇒ premier onglet, offsets
  /// absents ⇒ zéros, index hors bornes ⇒ premier onglet (un jeu d'onglets a
  /// pu rétrécir depuis la dernière session), store qui lève ⇒ traité comme
  /// absent. Rien de ce que le store rend ne peut emporter l'écran.
  ///
  /// Sans [tabs], le réglage est sans effet.
  final ZListTabsStore? tabsStore;

  /// **Voie d'échappement** de la clé de portée passée à [tabsStore].
  ///
  /// `null` (défaut) ⇒ la clé est **dérivée** : type d'entité, identité de
  /// l'écran ([collectionId], à défaut [title]) et jeu d'onglets (clés de page
  /// dans l'ordre). C'est ce qui garantit que deux écrans à onglets ne se
  /// marchent jamais dessus, et qu'un **changement de jeu d'onglets invalide
  /// naturellement** l'ancienne préférence.
  ///
  /// À déclarer seulement quand deux écrans distincts partagent les trois — ou
  /// quand deux instances du même écran (deux dossiers, deux services) doivent
  /// mémoriser des onglets **différents**.
  final String? tabsScopeKey;

  /// **Tri par défaut, filtres permanents, taille de page et sémantique de
  /// recherche** du listing.
  ///
  /// Ces réglages existaient dans le socle sans qu'un écran assemblé les
  /// expose : les déclarer ici évite de construire un `ZListController` à la
  /// main — c'est-à-dire de quitter la déclaration — pour ouvrir une liste
  /// triée, ne jamais montrer les archives, changer la taille de page, ou
  /// élargir ce que la recherche interroge.
  ///
  /// ```dart
  /// query: const ZListQueryPolicy(
  ///   sort: <ZSort>[ZSort('updated_at', ZSortDirection.desc)],
  ///   baseFilters: <ZFilter>[ZFilter('archive', ZFilterOp.eq, false)],
  ///   pageSize: 50,
  /// ),
  /// ```
  ///
  /// **Rien de déclaré, rien de changé** (défaut) : les requêtes émises sont
  /// exactement celles d'avant — aucun filtre, aucun tri, aucune limite, et une
  /// recherche qui n'interroge que les champs `searchable` en tenant compte des
  /// blancs.
  ///
  /// Pour retrouver le domaine de recherche des moteurs de liste historiques
  /// (toutes les colonnes déclarées, blancs ignorés) :
  ///
  /// ```dart
  /// query: const ZListQueryPolicy.legacySearch(),
  /// ```
  ///
  /// Composition avec le reste de l'écran :
  ///
  /// * la **vue corbeille** garde sa portée de suppression ; le tri, les
  ///   filtres permanents et la sémantique de recherche s'y appliquent
  ///   **en plus** ;
  /// * la **recherche** ne les efface pas (un terme n'est pas un filtre), et
  ///   élargir son domaine ne lui fait pas franchir un filtre permanent ;
  /// * un tri demandé ensuite (`ZCrudScreenActions.sortBy`) **remplace** le
  ///   tri par défaut ; un filtre demandé ensuite
  ///   (`ZCrudScreenActions.filterBy`) **s'ajoute** aux filtres permanents ;
  /// * en mode [tabs], chaque onglet possède sa vue, donc sa requête : la
  ///   politique est **offerte** à ses pages (`ZListQueryPolicy.of(context)`,
  ///   composée par `filtersWith` avec les filtres de catégorie) et gouverne
  ///   directement le listing dont l'écran est propriétaire — la corbeille.
  final ZListQueryPolicy query;

  /// Widget partagé posé au-dessus du corps (au-dessus de la barre d'onglets
  /// en mode [tabs]).
  final Widget? header;

  /// Autorise la création (défaut `true`). `false` ⇒ aucun bouton « + »,
  /// quelle que soit l'ACL.
  final bool canCreate;

  /// Autorise le geste **« dupliquer »** (défaut `true`) : action de ligne
  /// ouvrant la surface d'édition en mode duplication — une **copie sans
  /// identité** de l'entité (produite par le canal du registre :
  /// `encode` → retrait des champs `isId` → `decode`), que la sauvegarde
  /// matérialise en **nouvelle** entité. Gouvernée par la même permission que
  /// la création (`ZCrudAction.create`) et par [canCreate] ; absente si
  /// [readOnly], si la source ne sait pas écrire, ou sans [registry] (le
  /// canal de copie est la dérivation).
  final bool canDuplicate;

  /// Titres à trois états de la surface d'édition (création / duplication /
  /// édition). `null` ⇒ replis l10n génériques (`create` / `copy` / `edit`),
  /// résolus via `label(context, …)`.
  final ZCrudTitles? titles;

  /// Activation de la corbeille (défaut [ZTrashMode.auto]).
  final ZTrashMode trash;

  /// **Quels gestes** la corbeille offre : mettre, restaurer, supprimer
  /// définitivement (défaut : les trois, `ZTrashPolicy.full`).
  ///
  /// À distinguer de [trash], qui décide seulement si la corbeille *existe*.
  /// Un geste apparaît quand il est **voulu** (ici), **possible** (la source
  /// sait le servir) et **autorisé** (`ZAcl` : `delete`, `restore`, `clear`).
  /// Déclarer un geste ici n'accorde jamais un droit refusé par l'ACL.
  ///
  /// ```dart
  /// // Corbeille consultable et restaurable, dont rien ne disparaît jamais :
  /// trashPolicy: ZTrashPolicy.withoutPurge,
  /// ```
  final ZTrashPolicy trashPolicy;

  /// **Nombre d'éléments en corbeille**, quand l'application le connaît
  /// (`null` par défaut).
  ///
  /// Sert à deux choses : afficher le compte sur l'accès à la corbeille
  /// (pastille `ZCountBadge`, si `ZTrashPolicy.showCount`) et **masquer** cet
  /// accès quand la corbeille est vide (si `ZTrashPolicy.visibleWhenEmpty`
  /// vaut `false`).
  ///
  /// ## Pourquoi une `ValueListenable`, et pourquoi l'écran ne compte pas
  ///
  /// Compter, c'est **lire la source**. Un `count(deletedOnly)` évalué au
  /// rendu coûterait une lecture du dépôt à chaque image — et une lecture
  /// asynchrone, donc un `FutureBuilder` par rendu : l'écran clignoterait
  /// pour afficher un nombre. L'écran ne le fait donc jamais.
  ///
  /// La valeur vient de l'application, qui sait d'où elle sort et quand elle
  /// change (un `ValueNotifier` alimenté après chaque mise à la corbeille,
  /// une projection d'un flux). Le fait qu'elle soit **écoutable** est ce qui
  /// permet à la pastille de se rafraîchir **sans reconstruire la liste** : le
  /// corps de l'écran est rendu une fois et **transmis tel quel** au travers
  /// des rafraîchissements de la coquille (AD-2).
  ///
  /// Le notifieur est **possédé par l'application** (create/dispose de son
  /// côté) : l'écran s'y abonne, il ne le dispose pas.
  ///
  /// Sur la voie `items` (liste en mémoire + prédicat `isDeleted`), le compte
  /// est **dérivé gratuitement** de la liste déjà parcourue : rien à déclarer,
  /// ce paramètre reste alors inutile.
  final ValueListenable<int>? trashCount;

  /// Mode de l'écran (défaut [ZScreenMode.full]) : écran complet, **fiche de
  /// détail** ([ZScreenMode.details]) ou consultation verrouillée
  /// ([ZScreenMode.locked]).
  ///
  /// En [ZScreenMode.details], chaque ligne porte une action « détails » qui
  /// ouvre **le formulaire entier** — ses [formFields], ou le formulaire de
  /// l'application ([editionBuilder]) — rendu en lecture seule. Ce n'est pas
  /// une fiche dérivée des colonnes de la liste : les colonnes affichent ce
  /// qu'un tableau peut montrer, la fiche montre **tous** les champs.
  ///
  /// L'action « modifier » reste offerte en [ZScreenMode.details] si et
  /// seulement si l'ACL autorise `ZCrudAction.update` — la consultation n'est
  /// pas un cul-de-sac pour qui a le droit de modifier. La création, la
  /// duplication et la corbeille, elles, sont absentes.
  ///
  /// 🔴 **Un écran complet peut lui aussi ouvrir des fiches** : ce n'est pas
  /// l'affaire du mode, c'est [detailsEnabled]. Choisir [ZScreenMode.details]
  /// pour obtenir la consultation **retirerait** la création et la corbeille de
  /// tout l'écran.
  final ZScreenMode mode;

  /// La **fiche de détail comme geste de ligne** (défaut `false`), sur un écran
  /// qui reste complet.
  ///
  /// Déclaré `true` en [ZScreenMode.full], chaque ligne gagne l'ouverture de sa
  /// fiche — le formulaire entier, tous ses champs, en lecture seule — **sans
  /// que l'écran perde quoi que ce soit** : le bouton de création, la mise à la
  /// corbeille et la restauration restent offerts, exactement comme avant.
  ///
  /// ```dart
  /// // On crée, on met à la corbeille, on restaure… et le tap consulte.
  /// ZCrudScreen<Convocation>(
  ///   title: 'Convocations',
  ///   source: ZCrudSource.repository(repo),
  ///   registry: registry,
  ///   detailsEnabled: true,
  /// )
  /// ```
  ///
  /// **Consulter et administrer ne sont pas exclusifs** — c'est même le cas le
  /// plus courant. [ZScreenMode.details] reste l'**écran de consultation** :
  /// une liste qui ne crée rien et n'a pas de corbeille. Ce drapeau est l'autre
  /// besoin : l'écran complet dont on ouvre les fiches.
  ///
  /// Trois conséquences, toutes gouvernées par l'ACL :
  ///
  /// * la ligne porte une action « détails » (`ZCrudAction.view`), **avant**
  ///   l'action « modifier » (`ZCrudAction.update`) ;
  /// * le geste **nominal** d'une carte métier devient la consultation :
  ///   `zCrudEditionOpener` ouvre la fiche, `zCrudDetailsOpener` la demande
  ///   explicitement, `ZCrudScreenActions.updateOpener` reste l'édition ;
  /// * depuis la fiche, `ZCrudEditionScope.onEditOf(context)` bascule la
  ///   surface vers l'édition sans la refermer, si `ZCrudAction.update` est
  ///   accordé.
  ///
  /// La fiche est offerte **en vue corbeille aussi**, aux mêmes conditions
  /// (`ZCrudAction.view`) : c'est là qu'on en a le plus besoin, la suppression
  /// définitive ne se rejouant pas. Les gestes d'**écriture**, eux, restent
  /// réservés aux vivants — la fiche ouverte depuis la corbeille n'offre donc
  /// aucun retour vers l'édition, quelle que soit l'ACL.
  ///
  /// Sans formulaire disponible ([editionBuilder], ou registre + schéma), il
  /// n'y a rien à consulter : le drapeau reste alors sans effet. En
  /// [ZScreenMode.locked], il est ignoré — l'écran verrouillé n'ouvre rien.
  final bool detailsEnabled;

  /// **Coloration de ligne** décidée sur l'**entité typée** — `null` (défaut)
  /// ⇒ rendu strictement inchangé.
  ///
  /// Sur un tableau de dépouillement, la couleur porte l'information : elle
  /// permet de balayer cent lignes d'un coup d'œil. Le seam reçoit l'objet
  /// métier, pas une cellule formatée — un renommage de champ devient une
  /// **erreur de compilation** au lieu d'une couleur qui disparaît en silence.
  ///
  /// ```dart
  /// rowColor: (context, convocation) => convocation.relancee
  ///     ? ZRowTint(
  ///         Theme.of(context).colorScheme.errorContainer,
  ///         semanticLabel: 'Relancée',
  ///       )
  ///     : null,
  /// ```
  ///
  /// La teinte est peinte **derrière** la tuile : celle du paquet comme celle
  /// de l'application ([itemBuilder]), dans la liste comme dans la grille de
  /// cartes. Elle ne s'applique **pas** à un [layout] qui porte déjà sa propre
  /// tuile (`ZListGridLayout(itemBuilder: …)`) — cette tuile appartient à
  /// l'application, qui la colore elle-même — ni à la grille de données
  /// (`ZListDataGridLayout`), dont le backend a sa propre coloration de
  /// cellules.
  ///
  /// 🔴 **Doublez la couleur.** Une information portée par la seule couleur est
  /// perdue pour un usager daltonien, en plein soleil, à l'impression et pour
  /// un lecteur d'écran (invariant AD-13). `ZRowTint.semanticLabel` la rend
  /// **audible** ; la rendre **visible** autrement — icône, pastille, mot
  /// d'état — est l'affaire de la tuile ([itemBuilder]).
  ///
  /// Aucune couleur n'est codée dans zcrud (invariant FR-26) : la teinte est
  /// entièrement dérivée du thème par l'application, d'où le `BuildContext`
  /// passé au seam.
  final ZRowTintBuilder<T>? rowColor;

  /// Consultation pure (défaut `false`) : ni création, ni édition, ni
  /// corbeille — les actions de ligne fournies via [rowActions] restent
  /// rendues (elles appartiennent à l'app).
  ///
  /// ⚠️ **Déprécié — préférer [mode]**. Correspondance exacte :
  ///
  /// | Ancien | Nouveau |
  /// |---|---|
  /// | `readOnly: false` (défaut) | `mode: ZScreenMode.full` (défaut) |
  /// | `readOnly: true` | `mode: ZScreenMode.locked` |
  /// | *(inexprimable)* | `mode: ZScreenMode.details` |
  ///
  /// `readOnly: true` reste **strictement** équivalent à
  /// [ZScreenMode.locked] : mêmes gestes retirés, même rendu. Le booléen ne
  /// savait pas dire la troisième chose — consulter la fiche complète, puis
  /// revenir à l'édition — d'où son remplacement par un mode à trois états.
  ///
  /// Quand les deux sont déclarés, [mode] l'emporte (le booléen n'est lu que
  /// s'il vaut `mode: ZScreenMode.full`, c'est-à-dire le défaut).
  @Deprecated(
    'Utiliser `mode` : `readOnly: true` devient `mode: ZScreenMode.locked`. '
    'Sera retiré en 1.0.',
  )
  final bool readOnly;

  /// Affiche la barre de recherche (défaut `true`). Sans effet en mode
  /// [tabs] (chaque onglet possède sa propre vue).
  final bool searchEnabled;

  /// Persistance de la sauvegarde, prioritaire sur `source.onSave` puis
  /// `repository.save`.
  final ZCrudSave<T>? onSave;

  /// Formulaire d'édition complet fourni par l'app — voie d'échappement de
  /// l'édition dérivée (`DynamicEdition` sur [formFields]).
  final ZCrudEditionBuilder<T>? editionBuilder;

  /// Fabrique de l'entité initiale d'une **création** (écran sans onglets, ou
  /// repli quand l'onglet actif n'en porte pas). `null` ⇒ le formulaire
  /// dérivé part de valeurs vides.
  final T Function()? defaultItemBuilder;

  /// Source optionnelle du journal de mutations. Sans elle, aucun geste,
  /// abonnement ou nœud de rendu d'historique n'est créé.
  final ZEntityHistorySource<T>? history;

  /// Actions de ligne **supplémentaires** de l'app pour la vue des éléments
  /// **vivants**, ajoutées après les actions assemblées (édition, duplication,
  /// mise à la corbeille) et filtrées par la même ACL.
  ///
  /// Elles ne sont **jamais** rendues en vue corbeille : les gestes qui s'y
  /// appliquent se déclarent par [trashRowActions]. Les deux canaux sont
  /// disjoints, précisément pour qu'une action destructive de corbeille ne
  /// puisse pas apparaître au milieu des éléments vivants.
  final List<ZRowAction<T>>? rowActions;

  /// Actions de ligne **supplémentaires** de l'app pour la vue **corbeille**,
  /// ajoutées après les actions assemblées (restauration, suppression
  /// définitive) et filtrées par la même ACL.
  ///
  /// Pendant symétrique de [rowActions] : ces actions ne sont jamais rendues
  /// sur les éléments vivants.
  final List<ZRowAction<T>>? trashRowActions;

  /// Politique de colonnes (force include/exclude par nom).
  final ZColumnPolicy? columnPolicy;

  /// Identifiant de collection soumis à l'**autorisation**, et à elle seule :
  /// c'est la valeur passée à `ZAcl.can(action, collectionId:)` pour toutes les
  /// décisions de l'écran (consultation, création, édition, corbeille, purge).
  ///
  /// Il n'est **jamais** transmis à `repository.save` : un dépôt porte déjà son
  /// propre emplacement d'écriture, c'est sa raison d'être. Déclarer ici la clé
  /// de gouvernance de l'écran est donc sans effet sur l'endroit où les données
  /// atterrissent — l'écriture suit toujours le dépôt déclaré dans [source].
  ///
  /// Pour rediriger réellement une écriture vers un autre conteneur, l'appel
  /// doit être explicite et direct : `repository.save(item, collectionId: …)`
  /// (voir `ZRepository.save`), jamais par le détour de cette déclaration.
  final String? collectionId;

  /// Actions additionnelles de l'app-bar, **déclarées en données**
  /// ([ZAppBarAction] de `zcrud_ui_kit`), rendues **avant** les actions
  /// assemblées (corbeille, création). Chaque action porte son
  /// `semanticLabel` (a11y AD-13, jamais nul) et peut demander le **menu de
  /// débordement** (`isOverflow: true`) — mécanisme du socle, pas une
  /// réinvention locale.
  final List<ZAppBarAction> actions;

  /// Actions additionnelles de l'app-bar **dépendantes de l'état**, toujours
  /// déclarées en **données** — le builder rend des [ZAppBarAction], jamais des
  /// widgets.
  ///
  /// **Exclusif avec [actions]** (assertion de construction) : le builder sait
  /// rendre les actions constantes en plus des conditionnelles, deux sources à
  /// la même place rendraient l'ordre de l'app-bar indécidable.
  ///
  /// Il reçoit un [ZAppBarActionsContext] portant l'**ACL résolue** (restriction
  /// de l'onglet actif déjà composée), l'**onglet actif**, le **nombre
  /// d'éléments de la vue courante**, la **vacuité** et l'**état corbeille** —
  /// et rien d'autre : l'état interne de l'écran n'est pas exposé.
  ///
  /// ```dart
  /// actionsBuilder: (state) => <ZAppBarAction>[
  ///   if (!state.isEmpty)
  ///     ZAppBarAction(
  ///       icon: Icons.filter_alt_off_outlined,
  ///       semanticLabel: label(context, 'filters'),
  ///       onPressed: _showFilterDialog,
  ///     ),
  /// ],
  /// ```
  ///
  /// **Granularité (AD-2)** : le builder est réévalué quand l'onglet, le
  /// comptage ou la portée changent, et **seule la coquille** est rebâtie — le
  /// corps de l'écran est construit une fois et transmis tel quel. Le comptage
  /// vient de la lecture notifiée du listing
  /// ([ZCrudScreenActions.entitiesInViewListenable], publication en fin de
  /// trame, comparaison par contenu) ; son notifieur n'est créé qu'au premier
  /// accès, donc **un écran sans builder ne paie rien**.
  final ZAppBarActionsBuilder? actionsBuilder;

  /// Boutons additionnels de l'`AppBar` sous forme de **widgets déjà
  /// construits** (avant les boutons assemblés).
  ///
  /// ⚠️ **Déprécié — préférer [actions]**. L'app-bar de l'écran est désormais
  /// celle de `zcrud_ui_kit` (`ZSearchableAppBar`), dont les actions sont des
  /// **données** ([ZAppBarAction]) : un widget déjà construit ne peut y être
  /// transmis qu'emballé (`ZAppBarAction.widget`), ce qui a deux effets
  /// **mesurés** :
  /// * le tap reste fonctionnel (le bouton de l'hôte reçoit bien le geste —
  ///   l'emballage est rendu `onPressed: null`, donc inerte) ;
  /// * la sémantique **propre** du widget de l'hôte (tooltip, libellé) est
  ///   masquée par l'`ExcludeSemantics` du socle et n'est **pas** remplacée
  ///   (aucun `semanticLabel` n'est dérivable d'un widget opaque) ;
  /// * la boîte du bouton passe de 48 dp à 64 dp de large (double rembourrage).
  ///
  /// Une action déclarée via [actions] n'a **aucun** de ces défauts.
  @Deprecated(
    'Utiliser `actions` (List<ZAppBarAction>) : une action déclarée en '
    'données porte son semanticLabel et son débordement. Sera retiré en 1.0.',
  )
  final List<Widget> appBarActions;

  /// Widget de tête de l'`AppBar` (remplacé par le bouton de sortie en vue
  /// corbeille).
  final Widget? leading;

  /// **Navigation de l'application** — tiroir latéral de tête, relayé tel quel
  /// au `Scaffold` du socle (`ZPageScaffold.drawer`).
  ///
  /// L'écran assemblé **construit** le `Scaffold` : sans ce relais, une
  /// application à modules n'avait aucun moyen d'attacher son menu à un écran
  /// migré — il fallait imbriquer un second `Scaffold` porteur du tiroir et un
  /// `GlobalKey<ScaffoldState>` pour l'ouvrir.
  ///
  /// **Le menu appartient à l'application** : le paquet n'en fournit aucun, ne
  /// décide d'aucun responsive (tiroir sur mobile, colonne fixe sur desktop :
  /// c'est l'hôte qui tranche) et n'y applique aucune règle de droits. Il
  /// transmet le widget, rien de plus.
  ///
  /// ```dart
  /// ZCrudScreen<Navire>(
  ///   title: 'ships',
  ///   source: ZCrudSource<Navire>.repository(repo),
  ///   drawer: MonMenuLateral(), // votre menu, votre ACL, votre responsive
  /// );
  /// ```
  ///
  /// **Le bouton d'ouverture est inséré par Material**, pas par zcrud : un
  /// `Scaffold` porteur d'un tiroir voit son `AppBar` se doter du bouton
  /// « hamburger » **si et seulement si** aucun `leading` n'occupe la place
  /// (`automaticallyImplyLeading`, comportement natif que le socle ne
  /// réimplémente pas). Trois conséquences **voulues** :
  ///
  /// * un [leading] déclaré par l'hôte **prime** sur le bouton de menu — le
  ///   tiroir reste alors atteignable par **glissement depuis le bord** ;
  /// * en **vue corbeille**, le socle impose son bouton de retour : le bouton
  ///   de menu y est donc masqué, même avec un tiroir déclaré. C'est le
  ///   comportement retenu — sortir de la corbeille prime sur changer de
  ///   module, et le glissement depuis le bord reste offert ;
  /// * pendant une **recherche ouverte**, le leading est le bouton de
  ///   fermeture de la recherche : même règle, même repli.
  ///
  /// `null` (défaut) ⇒ **aucun** tiroir, aucun bouton, rendu strictement
  /// identique à celui d'avant l'introduction du paramètre.
  final Widget? drawer;

  /// Tiroir latéral de **queue**, relayé tel quel au `Scaffold` du socle
  /// (`ZPageScaffold.endDrawer`).
  ///
  /// Mêmes règles que [drawer] — le paquet ne fournit aucun contenu et ne
  /// décide d'aucun responsive. Le bouton d'ouverture est inséré par Material
  /// en **fin** d'`AppBar` quand aucune action n'y figure ; les actions de
  /// l'écran (corbeille, création, export, actions déclarées) occupant cette
  /// place, un tiroir de queue s'ouvre en pratique par **glissement depuis le
  /// bord** ou par un geste que l'hôte déclare lui-même
  /// (`Scaffold.of(context).openEndDrawer()`).
  ///
  /// `null` (défaut) ⇒ **aucun** tiroir de queue, rendu inchangé.
  final Widget? endDrawer;

  /// **Gouvernance par ligne** : les droits propres à chaque entité, déclarés
  /// une seule fois pour tout l'écran.
  ///
  /// Un dossier clôturé, une pièce déjà validée, une cargaison d'un exercice
  /// fermé n'offrent pas les mêmes gestes que leurs voisines de liste, sans
  /// que les droits de l'utilisateur aient changé. Ce résolveur porte cette
  /// nuance — et lui seul : il gouverne les actions de la vue vivante comme
  /// celles de la corbeille, qu'elles soient rendues en boutons ou en menu.
  ///
  /// ```dart
  /// ZCrudScreen<Dossier>(
  ///   rowAcl: (dossier) => dossier.cloture
  ///       ? const ZRowPermissions.locked(reasonKey: 'dossierClosed')
  ///       : const ZRowPermissions.unrestricted(),
  ///   // …
  /// );
  /// ```
  ///
  /// 🔒 **Il restreint, il n'élargit jamais** : la composition avec l'ACL de
  /// l'écran (ou du scope) est une **intersection**. Un résolveur ne peut pas
  /// rouvrir un geste que l'ACL refuse — le vocabulaire de [ZRowPermissions]
  /// ne permet même pas de l'exprimer.
  ///
  /// `null` (défaut) = aucune restriction de ligne, comportement inchangé.
  final ZRowAclResolver<T>? rowAcl;

  /// Mode de filtrage ACL des actions de ligne (défaut : masquer).
  ///
  /// Il gouverne aussi la présentation en menu : une action masquée est
  /// **absente** du menu ; une action `ZActionAclMode.disable` y figure
  /// **inerte, avec son motif annoncé** (libellé `actionNotAllowed`), sans
  /// jamais devenir invocable.
  final ZActionAclMode actionAclMode;

  /// Comment les actions d'une ligne sont présentées (défaut
  /// [ZRowActionsPresentation.inline] — boutons visibles, comportement
  /// inchangé).
  ///
  /// ```dart
  /// // Un déclencheur de menu par ligne, plus le clic droit / l'appui long :
  /// rowActionsPresentation: ZRowActionsPresentation.contextMenu,
  /// ```
  ///
  /// La **présentation** du menu (colonne, grille) appartient au `ZMenuScope`
  /// ambiant : poser `ZMenuScope(renderer: const ZGridMenuRenderer())`
  /// au-dessus de l'écran suffit à le rendre en grille, et brancher son propre
  /// renderer suffit à le rendre autrement. L'écran n'en code aucun en dur.
  ///
  /// **Portée** : la présentation en menu s'applique aux tuiles dont l'écran
  /// est propriétaire — le rendu dérivé, ou celui d'[itemBuilder]. Un [layout]
  /// portant déjà sa **propre** tuile de ligne, ou le rendu délégué à un
  /// backend de grille de données, garde ses actions **en ligne** : l'écran ne
  /// s'insère jamais dans une tuile qu'il n'a pas construite.
  final ZRowActionsPresentation rowActionsPresentation;

  /// Seuil de la présentation adaptative ([ZRowActionsPresentation.auto], défaut
  /// `2`) : jusqu'à ce nombre d'actions assemblées, la ligne garde ses boutons
  /// visibles ; au-delà, elle passe au déclencheur de menu.
  final int inlineActionLimit;

  /// À qui appartient l'**appui long** sur une ligne (défaut
  /// [ZRowLongPressOwner.contextMenu]).
  ///
  /// À passer [ZRowLongPressOwner.list] dès que le rendu de liste occupe
  /// lui-même ce geste — la copie du contenu d'une cellule à l'appui long, par
  /// exemple : le menu contextuel ne s'ouvre alors plus qu'au **clic droit**,
  /// et le déclencheur visible reste offert (aucune action n'est perdue).
  /// L'écran ne dépend pas du rendu de liste et ne peut donc pas lire sa
  /// configuration : c'est l'application, qui possède les deux déclarations,
  /// qui arbitre.
  final ZRowLongPressOwner longPressOwner;

  /// Demande une **confirmation** avant tout geste destructif de ligne — mise
  /// à la corbeille **et** suppression définitive —, via `showZConfirmDialog`
  /// de `zcrud_ui_kit`, en tonalité [ZConfirmTone.destructive] (défaut `true`).
  ///
  /// Les deux gestes ne posent pas la **même** question : la mise à la
  /// corbeille se défait, la purge non. La confirmation de purge porte donc son
  /// propre libellé (« supprimer définitivement ») et annonce l'irréversibilité.
  ///
  /// Annuler (bouton, barrière ou `pop` sans valeur) ⇒ **aucune écriture** :
  /// ni `repository.softDelete`, ni `ZPurgeable.purge`, ni les rappels
  /// `source.onSoftDelete`/`source.onPurge`.
  ///
  /// `false` ⇒ aucun dialogue : l'hôte qui possède son propre flux de
  /// confirmation (feuille custom, annulation différée « Annuler » en toast)
  /// le garde sans double demande. La **restauration** n'est jamais
  /// confirmée : elle n'est pas destructive.
  final bool confirmDestructive;

  /// **Sélection multiple et actions de masse** — `null` (défaut) = aucune
  /// sélection, écran strictement inchangé.
  ///
  /// Déclarer `selection: const ZSelectionPolicy()` suffit : chaque ligne
  /// reçoit sa case à cocher, et une **barre d'actions de masse** apparaît dès
  /// le premier élément coché, puis disparaît quand la sélection se vide.
  ///
  /// ```dart
  /// ZCrudScreen<Dossier>(
  ///   title: 'Dossiers',
  ///   source: ZCrudSource.repository(repo),
  ///   registry: registry,
  ///   selection: const ZSelectionPolicy(),
  /// )
  /// ```
  ///
  /// Les actions offertes sont celles de la **vue courante**, et personne
  /// d'autre ne les décide : mise à la corbeille sur les éléments vivants,
  /// restauration et suppression définitive en corbeille — chacune présente
  /// aux mêmes conditions que l'action de ligne homonyme (geste voulu par
  /// [trashPolicy], servi par la source, autorisé par l'ACL).
  ///
  /// ## Ce qui est gouverné, et comment
  ///
  /// * **Droit refusé pour la collection** : l'action de masse est **absente**
  ///   ([ZActionAclMode.hide], défaut) ou **inerte** ([ZActionAclMode.disable] :
  ///   elle reste offerte, l'invoquer annonce le refus et **n'écrit rien**).
  /// * **Ligne exclue** : une entité que [rowAcl] restreint, ou qu'un
  ///   `ZRowAction.enabledFor` déclare inapplicable, est **retirée du lot**
  ///   avant toute écriture — jamais traitée en silence. La résolution est
  ///   celle des actions de ligne (`zResolveRowActions`), pas une seconde
  ///   logique d'autorisation.
  /// * **Confirmation** : un geste de masse destructif passe par la même
  ///   confirmation que le geste unitaire ([confirmDestructive]), avec le
  ///   **nombre d'éléments** dans la question. Annuler n'écrit rien.
  ///
  /// ## Le lot rend des comptes
  ///
  /// Une suppression de masse dont une partie échoue **le dit** : la
  /// notification porte le nombre de succès, le nombre d'échecs, le nombre
  /// d'éléments écartés, et nomme les éléments en échec. Le
  /// `ZBatchReport` complet est offert à l'application par
  /// `ZSelectionPolicy.onReport`, pour qui veut sa propre surface (liste
  /// exhaustive, journal, réessai).
  ///
  /// ## Portée
  ///
  /// La sélection porte sur le listing **dont l'écran est propriétaire**. En
  /// mode [tabs], chaque onglet possède sa vue : la sélection s'y applique donc
  /// à la corbeille, et une page d'onglet qui veut la sienne déclare sa propre
  /// `DynamicList(selection:)`. La sélection est **vidée** après chaque action
  /// de masse, à la bascule vivants ⇄ corbeille et au changement d'onglet.
  final ZSelectionPolicy? selection;

  /// Actions de masse **supplémentaires** de l'application, ajoutées après les
  /// actions assemblées. Elles reçoivent les entités sélectionnées et
  /// appartiennent à l'application (l'écran ne les gouverne pas). Sans
  /// [selection] déclarée, elles ne sont jamais rendues.
  final ZCrudBatchActions<T>? batchActions;

  /// Politique d'**export** du listing — les formats offerts et la remise du
  /// fichier produit. `null` (défaut) : aucune entrée d'export, et aucune
  /// dépendance d'export tirée par l'écran.
  ///
  /// L'export part de ce qui est **affiché** : lignes réellement listées (tri,
  /// filtres, recherche et vue vivants/corbeille appliqués), colonnes dérivées
  /// du schéma, valeurs formatées. Une **sélection** en cours restreint
  /// l'export aux seuls éléments cochés. Les ornements d'écran — numéro
  /// d'ordre, cases à cocher, boutons d'action — n'y figurent pas.
  ///
  /// Voir [ZExportPolicy].
  final ZExportPolicy? export;

  @override
  State<ZCrudScreen<T>> createState() => _ZCrudScreenState<T>();
}

class _ZCrudScreenState<T extends ZEntity> extends State<ZCrudScreen<T>>
    implements ZCrudScreenActions {
  /// Vue corbeille active.
  bool _trashView = false;

  /// ACL résolue au dernier rendu.
  ///
  /// Les gestes exposés aux descendants ([ZCrudScreenScope]) sont interrogés
  /// depuis le `build` d'une carte, pas depuis celui de l'écran : ils lisent
  /// donc l'ACL **mémorisée** plutôt que d'en refaire la résolution par le
  /// contexte. Le défaut est le refus (fail-closed) — un geste interrogé avant
  /// tout rendu de l'écran n'est jamais offert.
  ZAcl _resolvedAcl = const ZDenyAllAcl();

  /// Recherche courante, **miroir** de la query détenue par l'app-bar de
  /// `zcrud_ui_kit` (le shell est propriétaire de son état de saisie, AD-2).
  ///
  /// Elle **filtre** directement la voie `items` ; sur la voie repository elle
  /// n'est qu'un miroir, l'application passant par `ZListController.setSearch`.
  /// Le miroir sert alors à **réaligner** le contrôleur devenu actif lors
  /// d'une bascule vivants ⇄ corbeille : sans lui, le texte resté visible dans
  /// l'app-bar ne correspondrait plus au filtre réellement appliqué.
  String _search = '';

  /// Index de l'onglet actif (mode [ZCrudScreen.tabs]) — possédé ici,
  /// synchronisé par `ZTabbedList.activeIndexNotifier`.
  final ValueNotifier<int> _activeTabIndex = ValueNotifier<int>(0);

  /// Index `row.id → entité` alimenté par la projection (source du filtrage
  /// ACL row-level et des handlers d'action).
  final Map<String, T> _entities = <String, T>{};

  /// Tri **demandé** (par l'application, via [sortBy]) — vide tant que
  /// personne n'en a demandé, auquel cas le tri par défaut de
  /// [ZCrudScreen.query] s'applique.
  List<ZSort> _userSort = const <ZSort>[];

  /// Filtres **demandés** (par l'application, via [filterBy]) — ils s'ajoutent
  /// aux filtres permanents de [ZCrudScreen.query], jamais à leur place.
  List<ZFilter> _userFilters = const <ZFilter>[];

  /// Contrôleur de **sélection multiple**, possédé par l'écran (create/dispose)
  /// et créé seulement quand une politique de sélection est déclarée. `null`
  /// (défaut) : aucune sélection n'existe, et rien de ce qui la sert n'est
  /// construit.
  ZListSelectionController? _selection;

  /// Identités des lignes **actuellement listées** — la portée exacte de
  /// « tout sélectionner ». Relevée au rendu du listing, jamais accumulée : le
  /// bouton ne sélectionne pas ce qui a quitté la vue (autre page, autre
  /// portée, résultat filtré).
  List<String> _visibleIds = const <String>[];

  /// Lignes **actuellement listées**, dans l'ordre où elles sont peintes — la
  /// matière exacte d'un export.
  ///
  /// Relevées au même endroit et au même moment que [_visibleIds], sur l'état
  /// réellement rendu : tri, filtres, recherche et portée (vivants ou
  /// corbeille) y sont donc déjà appliqués. C'est ce qui garantit qu'un fichier
  /// exporté dit ce que l'utilisateur a sous les yeux, et non ce que la source
  /// contient.
  List<ZListRow> _visibleRows = const <ZListRow>[];

  ZListController<T>? _liveController;
  ZListController<T>? _trashController;

  /// Contrôleurs des **onglets assemblés**, un par onglet et par portée
  /// (vivants / corbeille), créés au premier rendu de la page concernée.
  ///
  /// Chaque onglet assemblé possède le sien parce qu'il possède sa **requête** :
  /// sa catégorie est le socle persistant de son contrôleur, hors d'atteinte
  /// d'une recherche ou d'un filtre. Un contrôleur unique partagé forcerait à
  /// réécrire ce socle à chaque changement d'onglet — donc à re-interroger la
  /// source, et à perdre la position et la pagination de l'onglet quitté.
  ///
  /// Clé : `'<portée>:<clé de page de l'onglet>'` (voir [_tabControllerKey]).
  final Map<String, ZListController<T>> _tabControllers =
      <String, ZListController<T>>{};

  /// Lignes rendues par chaque onglet assemblé, relevées au même endroit et au
  /// même moment que [_visibleRows] — la matière d'un export fait depuis un
  /// onglet.
  ///
  /// Elles sont mémorisées **par onglet** parce que les pages d'onglets sont
  /// keep-alive : changer d'onglet ne reconstruit pas la page rejointe, et un
  /// relevé unique resterait donc celui de l'onglet construit en dernier —
  /// pas celui que l'usager regarde.
  final Map<String, List<ZListRow>> _tabVisibleRows =
      <String, List<ZListRow>>{};

  /// Clé du contrôleur d'onglet portant actuellement le terme de recherche,
  /// ou `null` si aucun ne le porte.
  ///
  /// La barre de recherche est **unique et partagée**, mais elle ne filtre que
  /// l'onglet **actif** : quitter un onglet lui rend donc sa liste entière.
  /// C'est cette clé qui dit lequel il faut relâcher.
  String? _searchedTabKey;

  // Le contrôleur des vivants est créé PARESSEUSEMENT, au premier rendu qui en
  // a besoin (voir `_ensureLiveController`) — jamais dans `initState`. Sa
  // construction déclenche une lecture de la source : la créer d'office
  // interrogerait le dépôt même quand `ZCrudAction.view` est refusé, c'est-à-dire
  // exactement ce que le refus doit empêcher.

  @override
  void initState() {
    super.initState();
    // Exclusivité `actions` / `actionsBuilder` — attrapée AU MONTAGE, avec un
    // message actionnable, plutôt que par une app-bar dont l'ordre serait
    // silencieusement indécidable. L'assertion vit ici et non dans le
    // constructeur : `List.length`/`isEmpty` n'est pas évaluable en contexte
    // constant, et `ZCrudScreen` doit rester constructible en `const` (même
    // patron que l'unicité des clés de page dans `ZTabbedList.initState`).
    assert(
      widget.actions.isEmpty || widget.actionsBuilder == null,
      'ZCrudScreen : `actions` et `actionsBuilder` sont EXCLUSIFS. Deux '
      'sources d\'actions additionnelles à la même place rendraient l\'ordre '
      'de l\'app-bar indécidable — déclarez la liste figée (`actions`) OU le '
      'builder (`actionsBuilder`), qui sait rendre les actions constantes en '
      'plus des conditionnelles.',
    );
    _syncSelectionController(null);
    // L'onglet mémorisé est SEMÉ ici, avant tout rendu : le notifieur porte
    // déjà la bonne valeur quand `ZTabbedList` se monte, donc rien n'est
    // notifié en trop et `_onActiveTabChanged` ne se déclenche pas à faux.
    _restoredTabIndex = _readStoredTabIndex();
    if (_restoredTabIndex != 0) _activeTabIndex.value = _restoredTabIndex;
    // Changer d'onglet change ce qui est listé : garder une sélection faite
    // sur l'onglet précédent laisserait un lot invisible s'exécuter sur des
    // éléments que l'utilisateur ne voit plus.
    _activeTabIndex.addListener(_onActiveTabChanged);
  }

  /// Changement d'onglet actif : la sélection est vidée, la recherche partagée
  /// **suit** l'onglet devenu actif, et l'onglet est **mémorisé**.
  void _onActiveTabChanged() {
    _clearSelection();
    _followSearchToActiveTab();
    // Les pages d'onglets sont keep-alive : rejoindre un onglet déjà construit
    // ne le reconstruit pas, donc ne repasse pas par le relevé des lignes. Sans
    // cette publication, la lecture notifiée resterait sur l'onglet quitté.
    _publishEntitiesInView();
    _writeStoredTabIndex(_activeTabIndex.value);
  }

  // ── Persistance des onglets (seam `ZListTabsStore`) ───────────────────────
  //
  // Tout passe par les quatre helpers ci-dessous, et par eux seuls : chacun
  // absorbe l'exception d'une implémentation fautive (invariant AD-10 — un
  // store qui lève est traité comme absent) et chacun est un NO-OP strict tant
  // qu'aucun store n'est déclaré. Aucun autre point du fichier n'appelle le
  // port.

  /// Index d'onglet **restauré** au montage (0 quand rien n'est mémorisé) —
  /// c'est l'`initialIndex` donné à `ZTabbedList`.
  int _restoredTabIndex = 0;

  /// Clé de portée du store : celle déclarée, sinon **dérivée** du type
  /// d'entité, de l'identité de l'écran et du jeu d'onglets.
  ///
  /// Le jeu d'onglets entre dans la clé pour deux raisons, pas une : deux
  /// écrans à onglets ne se marchent jamais dessus, **et** un changement de jeu
  /// d'onglets invalide naturellement l'ancienne préférence — un index
  /// mémorisé pour d'autres onglets ne peut pas être réappliqué aux nouveaux.
  String get _tabsScopeKey {
    final declared = widget.tabsScopeKey;
    if (declared != null) return declared;
    final tabs = widget.tabs ?? const <ZListTab>[];
    final identity = widget.collectionId ?? widget.title;
    final pageKeys = <String>[for (final tab in tabs) tab.resolvedPageKey];
    return '$T/$identity/${pageKeys.join(',')}';
  }

  /// Le store est-il **atteignable** ? (déclaré, et des onglets à mémoriser).
  ZListTabsStore? get _tabsStore {
    final store = widget.tabsStore;
    if (store == null) return null;
    final tabs = widget.tabs;
    if (tabs == null || tabs.isEmpty) return null;
    return store;
  }

  /// Onglet mémorisé, **borné au jeu d'onglets courant**.
  ///
  /// Trois replis, tous sur le premier onglet : rien de mémorisé, index hors
  /// bornes (le jeu d'onglets a pu rétrécir depuis la dernière session), ou
  /// store qui lève.
  int _readStoredTabIndex() {
    final store = _tabsStore;
    if (store == null) return 0;
    final int? stored;
    try {
      stored = store.loadTabIndex(_tabsScopeKey);
    } catch (_) {
      return 0;
    }
    if (stored == null) return 0;
    final count = widget.tabs!.length;
    if (stored < 0 || stored >= count) return 0;
    return stored;
  }

  void _writeStoredTabIndex(int index) {
    final store = _tabsStore;
    if (store == null) return;
    try {
      store.saveTabIndex(_tabsScopeKey, index);
    } catch (_) {
      // Un store fautif ne casse pas l'écran (AD-10) : la préférence est
      // simplement perdue.
    }
  }

  /// Défilement mémorisé de l'onglet [tabIndex] — `0` quand rien n'est
  /// mémorisé, quand la valeur n'est pas un réel exploitable (négatif, NaN,
  /// infini) ou quand le store lève.
  double _readStoredScrollOffset(int tabIndex) {
    final store = _tabsStore;
    if (store == null) return 0;
    final double? stored;
    try {
      stored = store.loadScrollOffset(_tabsScopeKey, tabIndex);
    } catch (_) {
      return 0;
    }
    if (stored == null || !stored.isFinite || stored < 0) return 0;
    return stored;
  }

  void _writeStoredScrollOffset(int tabIndex, double offset) {
    final store = _tabsStore;
    if (store == null) return;
    try {
      store.saveScrollOffset(_tabsScopeKey, tabIndex, offset);
    } catch (_) {
      // Idem : la position est perdue, l'écran reste debout.
    }
  }

  /// Aligne le contrôleur de sélection sur la politique déclarée : il n'existe
  /// que si une politique l'est, et il est **recréé** quand le mode change (le
  /// mode est fixe pour la durée de vie d'un contrôleur).
  void _syncSelectionController(ZSelectionPolicy? previous) {
    final policy = widget.selection;
    if (policy == null) {
      _selection?.dispose();
      _selection = null;
      return;
    }
    if (_selection != null && previous?.mode == policy.mode) return;
    _selection?.dispose();
    _selection = ZListSelectionController(mode: policy.mode);
  }

  /// Vide la sélection, s'il y en a une (no-op sinon).
  void _clearSelection() => _selection?.clearSelection();

  @override
  void didUpdateWidget(covariant ZCrudScreen<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelectionController(oldWidget.selection);
    final repo = widget.source.repository;
    // Une politique de requête change la construction même des contrôleurs
    // (taille de page, socle de filtres, tri par défaut) : la seule façon
    // honnête de l'honorer est de les reconstruire, comme au changement de
    // source.
    if (!identical(oldWidget.source.repository, repo) ||
        oldWidget.query != widget.query) {
      _liveController?.dispose();
      _trashController?.dispose();
      // Recréation PARESSEUSE : le prochain rendu autorisé reconstruit le
      // contrôleur ; un rendu refusé n'interroge pas la nouvelle source.
      _liveController = null;
      _trashController = null;
      // Les contrôleurs d'onglets naissent de la MÊME politique : ils suivent
      // le même sort, sans quoi un onglet continuerait d'interroger l'ancienne
      // source avec l'ancien socle.
      _disposeTabControllers();
      _entities.clear();
    }
  }

  /// Libère les contrôleurs d'onglets et oublie ce qu'ils portaient (recherche
  /// en cours, lignes relevées).
  void _disposeTabControllers() {
    for (final controller in _tabControllers.values) {
      controller.dispose();
    }
    _tabControllers.clear();
    _tabVisibleRows.clear();
    _searchedTabKey = null;
  }

  @override
  void dispose() {
    _liveController?.dispose();
    _trashController?.dispose();
    _disposeTabControllers();
    _selection?.dispose();
    _entitiesInViewNotifier?.dispose();
    _activeTabIndex.removeListener(_onActiveTabChanged);
    _activeTabIndex.dispose();
    super.dispose();
  }

  // ── Dérivation registre ───────────────────────────────────────────────────

  /// `kind` effectif : [ZCrudScreen.kind], sinon résolu du registre
  /// (`kindOf<T>` — `StateError` actionnable si l'association est ambiguë).
  String? get _registryKind {
    final registry = widget.registry;
    if (registry == null) return null;
    return widget.kind ?? registry.kindOf<T>();
  }

  /// Schéma dérivé du registre pour le `kind` effectif, ou `null`.
  List<ZFieldSpec>? get _derivedSpecs {
    final registry = widget.registry;
    final kind = _registryKind;
    if (registry == null || kind == null) return null;
    final specs = registry.tryFieldSpecsFor(kind);
    return (specs == null || specs.isEmpty) ? null : specs;
  }

  /// Colonnes effectives de la liste (paramètre > dérivation).
  List<ZFieldSpec> get _listFields {
    final fields = widget.listFields ?? _derivedSpecs;
    if (fields == null) {
      throw ZScopeError(
        'ZCrudScreen<$T> : aucun schéma de liste. Fournissez `listFields`, ou '
        'un `registry` où $T est enregistré avec ses `fieldSpecs` '
        '(annotation @ZcrudModel + registrar généré appelé au bootstrap).',
      );
    }
    return fields;
  }

  /// Champs effectifs du formulaire dérivé (paramètre > dérivation, `isId`
  /// exclus de la dérivation).
  List<ZFieldSpec>? get _formFields {
    final explicit = widget.formFields;
    if (explicit != null) return explicit;
    final derived = _derivedSpecs;
    if (derived == null) return null;
    final editable = <ZFieldSpec>[
      for (final spec in derived)
        if (!spec.isId) spec,
    ];
    return editable.isEmpty ? null : editable;
  }

  /// Projection effective `T → cellules` (paramètre > dérivation `encode`).
  Map<String, Object?> Function(T item) get _cellsOf {
    final explicit = widget.cellsOf;
    if (explicit != null) return explicit;
    final registry = widget.registry;
    final kind = _registryKind;
    if (registry == null || kind == null) {
      throw ZScopeError(
        'ZCrudScreen<$T> : aucune projection en cellules. Fournissez '
        '`cellsOf`, ou un `registry` où $T est enregistré (la projection est '
        'alors dérivée de `registry.encode`).',
      );
    }
    return (T item) => Map<String, Object?>.of(registry.encode(kind, item));
  }

  // ── Capacités dérivées de la déclaration ──────────────────────────────────

  /// Mode **effectif** de l'écran : [ZCrudScreen.mode] fait foi ; le booléen
  /// déprécié `readOnly` n'est lu que s'il est resté au défaut
  /// ([ZScreenMode.full]), auquel cas `true` vaut [ZScreenMode.locked].
  ///
  /// Cette table de correspondance est la seule lecture du booléen dans tout
  /// l'écran : le reste du code raisonne en modes.
  ZScreenMode get _mode {
    if (widget.mode != ZScreenMode.full) return widget.mode;
    // ignore: deprecated_member_use_from_same_package
    return widget.readOnly ? ZScreenMode.locked : ZScreenMode.full;
  }

  bool get _trashEnabled =>
      widget.trash == ZTrashMode.auto &&
      _mode == ZScreenMode.full &&
      widget.source.supportsTrash;

  /// `true` si un **formulaire** existe pour cet écran : fourni par l'app
  /// ([ZCrudScreen.editionBuilder]) ou dérivable du registre.
  ///
  /// Distinct de [_editionAvailable] : consulter une fiche ne demande aucune
  /// voie d'écriture — un référentiel distant en lecture seule a bien un
  /// formulaire à montrer, il n'a simplement rien à enregistrer.
  bool get _formPathAvailable {
    if (widget.editionBuilder != null) return true;
    return widget.registry != null &&
        _registryKind != null &&
        _formFields != null;
  }

  /// `true` si un chemin d'édition existe : formulaire fourni, ou dérivable
  /// (registre + schéma de formulaire) avec une voie de sauvegarde.
  bool get _editionAvailable =>
      _mode != ZScreenMode.locked &&
      widget.source.canWrite &&
      _formPathAvailable;

  /// `true` si la consultation est **déclarée** — indépendamment du fait qu'un
  /// formulaire existe pour la servir.
  ///
  /// Deux déclarations mènent à la fiche, et elles ne s'excluent pas : le mode
  /// [ZScreenMode.details] (écran de consultation) et le drapeau
  /// [ZCrudScreen.detailsEnabled] posé sur un écran **complet** (geste de
  /// ligne). Le mode verrouillé n'ouvre rien, quel que soit le drapeau.
  bool get _detailsDeclared => switch (_mode) {
    ZScreenMode.details => true,
    ZScreenMode.full => widget.detailsEnabled,
    ZScreenMode.locked => false,
  };

  /// `true` si la **fiche de détail** est offerte : consultation déclarée
  /// ([_detailsDeclared]) et formulaire disponible. L'ACL tranche ensuite
  /// (`ZCrudAction.view`, portée par l'action de ligne).
  bool get _detailsAvailable => _detailsDeclared && _formPathAvailable;

  /// ACL effective : paramètre de l'écran > scope ambiant > **refus**.
  ///
  /// Le repli est fail-closed : un oubli de câblage retire tous les gestes au
  /// lieu de tous les offrir.
  ZAcl _effectiveAcl(BuildContext context) =>
      widget.acl ?? ZcrudScope.maybeOf(context)?.acl ?? const ZDenyAllAcl();

  /// Onglet **actif**, ou `null` hors mode onglets (et en vue corbeille sans
  /// onglets, où le corps est le listing assemblé de l'écran).
  ZListTab? get _activeTab {
    final tabs = widget.tabs;
    if (tabs == null || tabs.isEmpty) return null;
    if (_trashView && !_trashTabsRendered) return null;
    final index = _activeTabIndex.value;
    if (index < 0 || index >= tabs.length) return null;
    return tabs[index];
  }

  /// `true` si **tous** les onglets déclarés sont assemblés (aucun ne porte de
  /// vue opaque).
  ///
  /// C'est la condition de tout ce que l'écran ne peut offrir que d'un bout à
  /// l'autre de la barre : la recherche partagée et la corbeille catégorisée.
  /// Un seul onglet opaque suffit à l'en priver — offrir une recherche qui ne
  /// filtrerait qu'une partie des onglets tromperait sur ce qu'elle fait.
  bool get _tabsFullyAssembled {
    final tabs = widget.tabs;
    if (tabs == null || tabs.isEmpty) return false;
    for (final tab in tabs) {
      if (tab.builder != null) return false;
    }
    return true;
  }

  /// `true` si la **vue corbeille garde les onglets** : ils sont tous
  /// assemblés, donc l'écran sait construire la partition supprimée de chaque
  /// catégorie, avec les mêmes filtres de catégorie qu'en vue vivante.
  ///
  /// Avec un onglet opaque, la corbeille reste le **listing unique** de
  /// l'écran — exactement comme avant.
  bool get _trashTabsRendered => _tabsFullyAssembled;

  /// `true` si le corps rendu est la barre d'onglets (vue vivante, ou vue
  /// corbeille catégorisée).
  bool get _tabsRendered =>
      widget.tabs != null && (!_trashView || _trashTabsRendered);

  /// Onglet actif **assemblé** (donc dont l'écran possède la liste), ou `null`.
  ZListTab? get _activeAssembledTab {
    final tab = _activeTab;
    if (tab == null || tab.builder != null) return null;
    return tab;
  }

  /// Clé du contrôleur d'un onglet dans une portée donnée : la portée d'abord
  /// (vivants / corbeille), puis la clé de page de l'onglet — que
  /// `ZTabbedList` garantit unique.
  String _tabControllerKey(ZListTab tab, {required bool trash}) =>
      '${trash ? 'trash' : 'live'}:${tab.resolvedPageKey}';

  /// ACL de l'onglet [index], **restreinte** par celle de l'écran.
  ///
  /// La cascade complète est `onglet ∩ écran ∩ scope` : `_effectiveAcl` porte
  /// déjà les deux niveaux hauts, `zRestrictAcl` y ajoute l'onglet en
  /// **conjonction**. Un onglet ne peut donc que retirer — quelle que soit la
  /// générosité de ce qu'il déclare, un geste refusé plus haut le reste.
  ZAcl _tabScopedAcl(ZAcl acl, int index) {
    final tabs = widget.tabs;
    if (tabs == null || index < 0 || index >= tabs.length) return acl;
    return zRestrictAcl(acl, tabs[index].acl);
  }

  /// `true` si la consultation de la collection est autorisée.
  ///
  /// `ZCrudAction.view` **gouverne l'écran entier** : refusé, aucune donnée
  /// n'est lue ni rendue (voir [_buildAccessDenied]).
  bool _viewAllowed(ZAcl acl) =>
      acl.can(ZCrudAction.view, collectionId: widget.collectionId);

  // ── Persistance ───────────────────────────────────────────────────────────

  /// Persiste [entity] par la voie déclarée (`onSave` → `source.onSave` →
  /// `repository.save`), rend la `ZFailure` en cas d'échec (`null` = succès),
  /// et rafraîchit la liste après un succès. Jamais d'exception (AD-10/AD-11) :
  /// un callback hôte qui lève est replié en `ZDomainFailure`.
  Future<ZFailure?> _persist(T entity) async {
    final custom = widget.onSave ?? widget.source.onSave;
    if (custom != null) {
      try {
        await custom(entity);
      } catch (error) {
        return ZDomainFailure('$error');
      }
      _refresh();
      return null;
    }
    // Dépôt d'ÉCRITURE, jamais `source.repository` : une source déclarée en
    // lecture seule sert le listing sans jamais offrir de voie d'enregistrement
    // — le refus tient à la déclaration, pas à ce qui manquerait par ailleurs.
    final repo = widget.source.writeRepository;
    if (repo == null) {
      return const ZDomainFailure(
        'ZCrudScreen : aucune voie de sauvegarde (ni onSave, ni repository).',
      );
    }
    // [collectionId] n'est PAS transmis ici : c'est une clé d'AUTORISATION, et
    // un dépôt sait déjà où il écrit. Le transmettre faisait interpréter la
    // clé d'ACL comme un chemin de collection par les adaptateurs qui
    // l'honorent — l'écriture réussissait alors dans une collection que
    // personne ne relit.
    final result = await repo.save(entity);
    return result.fold((failure) => failure, (_) {
      _refresh();
      return null;
    });
  }

  /// Relance les requêtes des contrôleurs (voie repository) et re-rend la
  /// partition (voie items).
  void _refresh() {
    unawaited(_liveController?.refresh());
    unawaited(_trashController?.refresh());
    // Les onglets assemblés listent la même collection : une écriture faite
    // depuis l'un d'eux les concerne tous (l'entité peut changer de catégorie).
    for (final controller in _tabControllers.values) {
      unawaited(controller.refresh());
    }
    if (mounted) setState(() {});
  }

  // ── Édition ───────────────────────────────────────────────────────────────

  /// Titre de la surface d'édition pour [mode] : titre déclaré
  /// ([ZCrudScreen.titles], clé l10n ou littéral), sinon repli l10n générique
  /// du mode — le mode duplication a son **propre** intitulé, distinct de la
  /// création nue.
  String _editionTitle(BuildContext context, _ZCrudEditionMode mode) {
    final titles = widget.titles;
    // Onglet actif d'abord : un écran segmenté par entité n'a pas un seul
    // intitulé de formulaire. Un mode non renseigné par l'onglet retombe sur
    // celui de l'écran, puis sur la clé l10n générique.
    final tabTitles = _activeTab?.titles;
    final declared = switch (mode) {
      _ZCrudEditionMode.create => tabTitles?.create ?? titles?.create,
      _ZCrudEditionMode.duplicate => tabTitles?.copy ?? titles?.copy,
      _ZCrudEditionMode.update => tabTitles?.update ?? titles?.update,
      _ZCrudEditionMode.read => tabTitles?.read ?? titles?.read,
    };
    if (declared != null) return label(context, declared);
    return switch (mode) {
      _ZCrudEditionMode.create => label(context, 'create'),
      _ZCrudEditionMode.duplicate => label(context, 'copy'),
      _ZCrudEditionMode.update => label(context, 'edit'),
      _ZCrudEditionMode.read => label(context, 'details'),
    };
  }

  /// Ouvre la **fiche de détail** d'[entity] : la même surface que l'édition,
  /// le même formulaire — celui de l'application s'il en fournit un, sinon
  /// celui dérivé des [ZCrudScreen.formFields] —, rendu en **lecture seule**.
  ///
  /// C'est le dernier maillon de la chaîne `liste → présentation →
  /// formulaire` : la fiche montre **tous** les champs du formulaire, pas les
  /// seules colonnes que la liste affiche.
  Future<void> _openDetails(T entity) =>
      _openEdition(initial: entity, mode: _ZCrudEditionMode.read);

  /// Ouvre le formulaire — création si [initial] est `null` ([seedValues]
  /// pré-remplit alors le formulaire dérivé : contexte d'onglet en `Map`).
  /// [mode] explicite pour la création semée d'une entité, la duplication et
  /// la consultation ; sinon dérivé de [initial] (`null` ⇒ création,
  /// non-`null` ⇒ édition).
  Future<void> _openEdition({
    T? initial,
    Map<String, Object?>? seedValues,
    _ZCrudEditionMode? mode,
  }) {
    final effectiveMode =
        mode ??
        (initial == null ? _ZCrudEditionMode.create : _ZCrudEditionMode.update);
    // Transport du drapeau de lecture : posé une fois ici, il gouverne le
    // formulaire DÉRIVÉ (via `DynamicEdition.readOnly`) comme le formulaire de
    // l'application (via `ZCrudEditionScope`, lu depuis son `BuildContext`).
    final readOnly = effectiveMode == _ZCrudEditionMode.read;
    // Retour vers l'édition DEPUIS la fiche : offert si et seulement si la
    // surface s'ouvre en consultation d'une entité que l'ACL laisse modifier.
    // Évalué ICI, à l'ouverture, avec l'entité pour cible — c'est le même
    // filtrage par ligne que l'action « modifier » de la liste.
    final canEdit = readOnly && initial != null && canOpenUpdate(initial);
    final builder = widget.editionBuilder;
    if (builder != null) {
      return presentEdition<void>(
        context,
        policy: widget.policy,
        formWeight: widget.formWeight,
        builder: (ctx) => _ZCrudEditionSurface(
          initialReadOnly: readOnly,
          canEdit: canEdit,
          // Le `Builder` interposé n'est pas décoratif : sans lui, le contexte
          // remis à l'application serait celui du dessus du scope, où
          // `ZCrudEditionScope.readOnlyOf` ne trouverait rien.
          builder: (surface, surfaceReadOnly, onEdit) => ZCrudEditionScope(
            readOnly: surfaceReadOnly,
            onEdit: onEdit,
            child: Builder(
              builder: (inner) => builder(inner, initial, (T entity) async {
                final failure = await _persist(entity);
                if (failure != null) throw StateError(failure.message);
              }),
            ),
          ),
        ),
      );
    }
    final registry = widget.registry;
    final kind = _registryKind;
    final fields = _formFields;
    if (registry == null || kind == null || fields == null) {
      throw ZScopeError(
        'ZCrudScreen<$T> : aucune voie d\'édition. Fournissez '
        '`editionBuilder`, ou un `registry` où $T est enregistré avec ses '
        '`fieldSpecs` (le formulaire est alors dérivé via DynamicEdition).',
      );
    }
    // Champs « chemin » : les specs à nom POINTÉ (dérivées ou fournies) lisent
    // et écrivent une valeur IMBRIQUÉE du modèle — l'ouverture aplatit
    // (`zFlattenPaths`), la reconstruction regroupe (`zRegroupPaths`). Aucun
    // nom pointé ⇒ chemin strictement inchangé.
    final pointedNames = <String>[
      for (final spec in fields)
        if (spec.name.contains('.')) spec.name,
    ];
    final encodedInitial = initial == null
        ? const <String, Object?>{}
        : registry.encode(kind, initial);
    final baseValues = <String, Object?>{
      ...encodedInitial,
      if (pointedNames.isNotEmpty)
        ...zFlattenPaths(
          Map<String, dynamic>.of(encodedInitial),
          paths: pointedNames,
        ),
      ...?seedValues,
    };
    return presentEdition<void>(
      context,
      policy: widget.policy,
      formWeight: widget.formWeight,
      builder: (ctx) => _ZCrudEditionSurface(
        initialReadOnly: readOnly,
        canEdit: canEdit,
        builder: (surface, surfaceReadOnly, onEdit) => ZCrudEditionScope(
          readOnly: surfaceReadOnly,
          onEdit: onEdit,
          child: _ZCrudEditionForm(
            // Le titre suit la bascule : une fiche devenue éditable n'annonce
            // plus « Détails ». Les autres modes (création, duplication) ne
            // basculent jamais — leur intitulé est donc inchangé.
            title: _editionTitle(
              surface,
              surfaceReadOnly || effectiveMode != _ZCrudEditionMode.read
                  ? effectiveMode
                  : _ZCrudEditionMode.update,
            ),
            fields: fields,
            readOnly: surfaceReadOnly,
            initialValues: baseValues,
            onSubmit: (values) async {
              final merged = <String, Object?>{...baseValues, ...values};
              final T entity;
              try {
                entity =
                    registry.decode(
                          kind,
                          pointedNames.isEmpty
                              ? Map<String, dynamic>.of(merged)
                              : zRegroupPaths(merged),
                        )
                        as T;
              } catch (error) {
                return ZDomainFailure('$error');
              }
              return _persist(entity);
            },
          ),
        ),
      ),
    );
  }

  /// Geste de création : hérite du contexte de l'onglet actif
  /// (`defaultItemBuilder` d'onglet : entité `T` ou `Map` de valeurs), sinon
  /// du [ZCrudScreen.defaultItemBuilder] de l'écran.
  Future<void> _create() {
    Object? seed;
    final tabs = widget.tabs;
    if (tabs != null && tabs.isNotEmpty) {
      final index = _activeTabIndex.value;
      if (index >= 0 && index < tabs.length) {
        seed = tabs[index].defaultItemBuilder?.call();
      }
    }
    seed ??= widget.defaultItemBuilder?.call();
    if (seed is T) {
      return _openEdition(initial: seed, mode: _ZCrudEditionMode.create);
    }
    if (seed is Map<String, Object?>) return _openEdition(seedValues: seed);
    return _openEdition();
  }

  // ── Gestes exposés aux descendants (ZCrudScreenScope) ─────────────────────
  //
  // Ces méthodes n'ouvrent RIEN par elles-mêmes : elles délèguent aux mêmes
  // `_openEdition` / `_openDetails` / `_create` que le bouton « + » et les
  // actions de ligne. C'est ce qui rend la surface obtenue par une carte
  // strictement identique à celle des gestes assemblés — même politique de
  // présentation, même poids de formulaire, même voie de sauvegarde, mêmes
  // titres — au lieu du court-circuit qu'un rappel capturé par fermeture
  // produirait.

  /// Permission gouvernant l'écriture d'[entity] : `create` pour une entité
  /// **éphémère** (l'enregistrer la crée), `update` sinon.
  ZCrudAction _writePermissionFor(ZEntity entity) =>
      entity.id == null ? ZCrudAction.create : ZCrudAction.update;

  /// Interroge l'ACL mémorisée avec [target] pour cible (filtrage par ligne).
  bool _allows(ZCrudAction action, ZEntity? target) => _resolvedAcl.can(
    action,
    target: target,
    collectionId: widget.collectionId,
  );

  /// L'édition est-elle **structurellement** ouvrable ? (hors vue corbeille,
  /// écran non verrouillé, source sachant écrire, formulaire disponible)
  bool get _editionOpenable => !_trashView && _editionAvailable;

  /// La fiche de détail est-elle **structurellement** ouvrable ?
  ///
  /// **Volontairement indifférente à la vue corbeille** — contrairement à
  /// [_editionOpenable]. L'asymétrie est le cœur du geste : *écrire* sur un
  /// élément supprimé n'a pas de sens, *le lire* en a — et c'est même là qu'on
  /// en a le plus besoin. La corbeille d'un écran métier contient des documents
  /// qui se ressemblent, dont la ligne ne montre qu'une poignée de colonnes ;
  /// consulter la fiche est la **vérification qui précède un geste
  /// irréversible** (la purge ne se rejoue pas).
  ///
  /// Ne pas y réintroduire `!_trashView` « par symétrie » : la symétrie porte
  /// sur l'écriture, pas sur la lecture. La gouvernance reste entière —
  /// [_detailsAvailable] (consultation déclarée + formulaire disponible) puis
  /// l'ACL (`ZCrudAction.view`, filtrée par ligne). Un usager sans `view`
  /// n'obtient pas la fiche, en corbeille comme sur les vivants.
  ///
  /// La fiche ainsi ouverte reste **strictement en lecture** : le retour vers
  /// l'édition (`ZCrudEditionScope.onEdit`) est décidé par `canOpenUpdate`,
  /// donc par [_editionOpenable] — qui, lui, exclut bien la corbeille. Aucune
  /// ACL ne peut y faire apparaître un bouton « Modifier ».
  bool get _detailsOpenable => _detailsAvailable;

  @override
  bool canOpenUpdate(ZEntity entity) =>
      entity is T &&
      _editionOpenable &&
      _allows(_writePermissionFor(entity), entity);

  @override
  Future<void> openUpdate(ZEntity entity) async {
    if (!canOpenUpdate(entity)) return;
    await _openEdition(initial: entity as T);
  }

  @override
  ZCrudOpener? updateOpener(ZEntity entity) =>
      canOpenUpdate(entity) ? () => openUpdate(entity) : null;

  @override
  bool canOpenDetails(ZEntity entity) =>
      entity is T && _detailsOpenable && _allows(ZCrudAction.view, entity);

  @override
  Future<void> openDetails(ZEntity entity) async {
    if (!canOpenDetails(entity)) return;
    await _openDetails(entity as T);
  }

  @override
  ZCrudOpener? detailsOpener(ZEntity entity) =>
      canOpenDetails(entity) ? () => openDetails(entity) : null;

  @override
  bool canOpenEdition(ZEntity entity) {
    if (entity is! T) return false;
    // Consultation offerte : le geste nominal est la CONSULTATION de la fiche —
    // c'est celui que la ligne offre en premier, et il relève de `view`. Vrai
    // de l'écran de consultation (`ZScreenMode.details`) comme de l'écran
    // COMPLET déclaré `detailsEnabled` : dans les deux cas, le tap consulte,
    // l'édition restant joignable par `updateOpener` et par l'action de ligne.
    if (_detailsOpenable) return _allows(ZCrudAction.view, entity);
    return canOpenUpdate(entity);
  }

  @override
  Future<void> openEdition(ZEntity entity) async {
    if (!canOpenEdition(entity)) return;
    if (_detailsOpenable) {
      await _openDetails(entity as T);
      return;
    }
    await _openEdition(initial: entity as T);
  }

  @override
  ZCrudOpener? editionOpener(ZEntity entity) =>
      canOpenEdition(entity) ? () => openEdition(entity) : null;

  @override
  bool get canOpenCreation =>
      _createOffered(_resolvedAcl, _activeTabIndex.value);

  @override
  Future<void> openCreation() async {
    if (!canOpenCreation) return;
    await _create();
  }

  @override
  ZCrudOpener? creationOpener() => canOpenCreation ? openCreation : null;

  @override
  void sortBy(List<ZSort> sort) {
    _userSort = List<ZSort>.unmodifiable(sort);
    final controller = _activeController;
    if (controller != null) {
      // Le contrôleur porte le tri demandé ; le décorateur de tri par défaut
      // ne comble QUE les requêtes qui n'en portent aucune — un tri demandé
      // remplace donc le défaut, il ne s'y superpose pas.
      controller.setSort(_userSort);
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  void filterBy(List<ZFilter> filters) {
    _userFilters = List<ZFilter>.unmodifiable(filters);
    final controller = _activeController;
    if (controller != null) {
      // `setFilters` ne remplace que les filtres DEMANDÉS : le socle
      // persistant (les filtres permanents de la politique) est ANDé en tête
      // par le contrôleur lui-même, hors d'atteinte de cet appel.
      controller.setFilters(_userFilters);
      return;
    }
    if (mounted) setState(() {});
  }

  /// Empreinte des capacités structurelles portée par [ZCrudScreenScope] —
  /// unique critère de reconstruction des descendants qui en dépendent.
  Object _actionsSignature(bool createOffered) =>
      (_mode, _trashView, _editionAvailable, _detailsAvailable, createOffered);

  // ── Duplication ───────────────────────────────────────────────────────────

  /// `true` si le geste « dupliquer » est offert : autorisé par déclaration,
  /// chemin d'édition disponible, et registre présent (la copie sans identité
  /// est produite par le canal `encode`/`decode` du registre).
  bool get _duplicateAvailable =>
      widget.canDuplicate &&
      _mode == ZScreenMode.full &&
      _editionAvailable &&
      widget.registry != null &&
      _registryKind != null;

  /// Copie **sans identité** d'[entity], produite par le même canal que la
  /// reconstruction d'entité de l'écran : `encode` → retrait des clés `isId`
  /// (noms réels lus dans les specs du registre) → `decode`. Un `initial`
  /// sans `id` se présente en création : la sauvegarde matérialise une
  /// **nouvelle** entité, l'originale reste intacte.
  Future<void> _duplicate(T entity) {
    final registry = widget.registry!;
    final kind = _registryKind!;
    final encoded = Map<String, dynamic>.of(registry.encode(kind, entity));
    final specs = registry.tryFieldSpecsFor(kind);
    var idRemoved = false;
    if (specs != null) {
      for (final spec in specs) {
        if (spec.isId) {
          encoded.remove(spec.name);
          idRemoved = true;
        }
      }
    }
    // Repli défensif : registre sans spec `isId` (specs absentes ou schéma
    // fourni par paramètre) — retirer la clé conventionnelle plutôt que de
    // risquer une duplication qui ÉDITERAIT l'originale.
    if (!idRemoved) encoded.remove('id');
    final copy = registry.decode(kind, encoded) as T;
    return _openEdition(initial: copy, mode: _ZCrudEditionMode.duplicate);
  }

  // ── Confirmation et notification (briques `zcrud_ui_kit`) ─────────────────

  /// Demande la confirmation d'un geste destructif.
  ///
  /// Rend `true` si le geste doit être exécuté : soit l'écran ne confirme pas
  /// ([ZCrudScreen.confirmDestructive] `false`), soit l'utilisateur a
  /// **explicitement** confirmé. Toute autre issue (bouton d'annulation,
  /// barrière, `pop` sans valeur) rend `false` — `showZConfirmDialog` replie
  /// déjà `null` en `false` (AD-10) : aucune écriture n'a alors lieu.
  ///
  /// [permanent] choisit le **ton** : mise à la corbeille (geste réversible,
  /// libellés `delete`/`confirmDeleteItem`) ou suppression définitive
  /// (libellés `deleteForever`/`confirmDeleteForeverItem`, dont le texte
  /// annonce l'irréversibilité). Dans les deux cas, la tonalité visuelle du
  /// dialogue est [ZConfirmTone.destructive] — c'est le texte, et lui seul, qui
  /// distingue « ça part à la corbeille » de « ça ne revient pas ».
  ///
  /// [count] accompagne un geste de **masse** : la question posée est la même,
  /// suivie du nombre d'éléments concernés — celui du lot réellement soumis
  /// (les éléments écartés en sont déjà retirés). `null` = geste unitaire,
  /// message inchangé.
  Future<bool> _confirmDestructive(
    BuildContext context, {
    bool permanent = false,
    int? count,
  }) {
    if (!widget.confirmDestructive) return Future<bool>.value(true);
    final title = permanent
        ? label(context, 'deleteForever', fallback: 'Delete permanently')
        : label(context, 'delete');
    final base = permanent
        ? label(
            context,
            'confirmDeleteForeverItem',
            fallback: 'Delete this item permanently? This cannot be undone.',
          )
        : label(context, 'confirmDeleteItem');
    final message = count == null ? base : '$base ($count)';
    return showZConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: title,
      tone: ZConfirmTone.destructive,
    );
  }

  /// Notifie l'échec d'une **action de ligne** (corbeille / restauration) —
  /// les seuls gestes de l'écran sans surface où s'afficher (l'échec d'une
  /// sauvegarde reste, lui, rendu **dans** la surface d'édition,
  /// `zCrudFormError`).
  ///
  /// Chaîne : `ZToasterScope` de l'hôte s'il est monté → repli pur-Flutter
  /// (`zToast` → `ZScaffoldMessengerToaster`) si un `ScaffoldMessenger` est
  /// atteignable → **silence** sinon. Jamais de `throw` (AD-10) : un écran
  /// monté hors `MaterialApp` ne casse pas sur un échec de suppression.
  void _notifyFailure(BuildContext context, ZFailure failure) =>
      _notify(context, failure.message, ZToastSeverity.error);

  /// Notifie [message] à la [severity] donnée, par la **même chaîne** que
  /// l'échec d'une action de ligne : `ZToasterScope` de l'hôte s'il est monté
  /// → repli pur-Flutter (`zToast`) si un `ScaffoldMessenger` est atteignable
  /// → silence sinon. Jamais de `throw` (AD-10).
  void _notify(BuildContext context, String message, ZToastSeverity severity) {
    if (!context.mounted) return;
    final toaster = ZToasterScope.maybeOf(context);
    if (toaster != null) {
      toaster.show(context, message: message, severity: severity);
      return;
    }
    if (ScaffoldMessenger.maybeOf(context) == null) return;
    zToast(context, message, severity: severity);
  }

  // ── Actions de ligne assemblées ───────────────────────────────────────────

  List<ZRowAction<T>>? _assembledRowActions() {
    final actions = <ZRowAction<T>>[];
    // Dépôt d'ÉCRITURE : les gestes de corbeille assemblés ici s'appuient sur
    // lui, jamais sur le dépôt de lecture.
    final repo = widget.source.writeRepository;
    if (widget.history != null) {
      actions.add(
        ZRowAction<T>(
          id: 'history',
          labelKey: 'history',
          icon: Icons.history_outlined,
          requiredPermission: ZCrudAction.history,
          onInvoke: (context, entity) => showZEntityHistory<T>(
            context,
            entity: entity,
            source: widget.history!,
            currentValue: _cellsOf(entity),
          ),
        ),
      );
    }
    // Fiche de détail : première action de la ligne, gouvernée par la
    // permission de CONSULTATION (`ZCrudAction.view`) — lire une fiche n'est
    // pas la modifier. L'action « modifier » qui suit porte, elle,
    // `ZCrudAction.update` : c'est ce filtrage-là, déjà appliqué par
    // `DynamicList`, qui rend le retour vers l'édition présent si et seulement
    // si le droit existe.
    //
    // Assemblée HORS de la partition vivants/corbeille, et c'est délibéré :
    // consulter est offert dans les DEUX vues, à la même place et avec la même
    // gouvernance, tandis que les gestes d'écriture restent réservés aux
    // vivants. Voir [_detailsOpenable] pour la raison de l'asymétrie.
    if (_detailsAvailable) {
      actions.add(
        ZRowAction<T>(
          id: 'details',
          labelKey: 'details',
          icon: Icons.visibility_outlined,
          requiredPermission: ZCrudAction.view,
          onInvoke: (context, entity) => _openDetails(entity),
        ),
      );
    }
    if (!_trashView) {
      if (_editionAvailable) {
        actions.add(
          ZRowAction<T>.edit(
            icon: Icons.edit_outlined,
            onInvoke: (context, entity) => _openEdition(initial: entity),
          ),
        );
      }
      if (_duplicateAvailable && widget.canCreate) {
        // Geste « dupliquer » : même permission que la création (une
        // duplication EST une création pré-remplie), filtrée par la même ACL
        // que les autres actions de ligne.
        actions.add(
          ZRowAction<T>(
            id: 'duplicate',
            labelKey: 'copy',
            icon: Icons.copy_outlined,
            requiredPermission: ZCrudAction.create,
            onInvoke: (context, entity) => _duplicate(entity),
          ),
        );
      }
      if (_trashEnabled && widget.trashPolicy.softDelete) {
        // `softDeleteWith` (et non `softDelete`) parce que la CONFIRMATION doit
        // précéder l'écriture : la fabrique `softDelete` appelle le dépôt
        // elle-même, il n'y a pas de point d'insertion avant. Identité, clé
        // l10n, permission (`ZCrudAction.delete`) et style destructif sont
        // ceux de la fabrique nominale — seule la confirmation s'ajoute.
        if (repo != null) {
          actions.add(
            ZRowAction<T>.softDeleteWith(icon: Icons.delete_outline, (
              context,
              entity,
            ) async {
              final entityId = entity.id;
              // Parité stricte avec `ZRowAction.softDelete` : une entité
              // éphémère n'a rien à supprimer (ignorée en silence).
              if (entityId == null) return;
              if (!await _confirmDestructive(context)) return;
              final result = await repo.softDelete(entityId);
              result.fold(
                (failure) => _notifyFailure(context, failure),
                (_) => _refresh(),
              );
            }),
          );
        } else {
          final onSoftDelete = widget.source.onSoftDelete;
          if (onSoftDelete != null) {
            actions.add(
              ZRowAction<T>.softDeleteWith(icon: Icons.delete_outline, (
                context,
                entity,
              ) async {
                if (!await _confirmDestructive(context)) return;
                try {
                  await onSoftDelete(context, entity);
                } catch (error) {
                  // AD-10 : un callback hôte qui lève est notifié, jamais
                  // relancé en erreur asynchrone non capturée.
                  _notifyFailure(context, ZDomainFailure('$error'));
                  return;
                }
                _refresh();
              }),
            );
          }
        }
      }
      // Actions supplémentaires de l'app pour les éléments VIVANTS : ajoutées
      // DANS la branche, jamais en dehors. Hors de ce `if`, une action de
      // corbeille passée par l'hôte apparaîtrait aussi sur les vivants.
      actions.addAll(widget.rowActions ?? const <Never>[]);
    } else {
      // Restauration : jamais confirmée (geste non destructif), mais son échec
      // est notifié comme celui de la mise à la corbeille.
      if (widget.trashPolicy.restore) {
        if (repo != null) {
          actions.add(
            ZRowAction<T>.restoreWith(icon: Icons.restore_from_trash, (
              context,
              entity,
            ) async {
              final entityId = entity.id;
              if (entityId == null) return;
              final result = await repo.restore(entityId);
              result.fold(
                (failure) => _notifyFailure(context, failure),
                (_) => _refresh(),
              );
            }),
          );
        } else {
          final onRestore = widget.source.onRestore;
          if (onRestore != null) {
            actions.add(
              ZRowAction<T>.restoreWith(icon: Icons.restore_from_trash, (
                context,
                entity,
              ) async {
                try {
                  await onRestore(context, entity);
                } catch (error) {
                  _notifyFailure(context, ZDomainFailure('$error'));
                  return;
                }
                _refresh();
              }),
            );
          }
        }
      }
      // Suppression définitive : troisième geste de la corbeille. Il n'existe
      // que si la source sait le servir (mixin `ZPurgeable` sur le dépôt, ou
      // rappel `onPurge` déclaré) ET que la politique le veut ; l'ACL
      // (`ZCrudAction.clear`, portée par la fabrique) tranche le reste.
      if (widget.trashPolicy.purge) {
        final purge = _purgeHandler();
        if (purge != null) {
          actions.add(
            ZRowAction<T>.purgeWith(icon: Icons.delete_forever, purge),
          );
        }
      }
      // Pendant symétrique : les actions supplémentaires DE LA CORBEILLE.
      actions.addAll(widget.trashRowActions ?? const <Never>[]);
    }
    return actions.isEmpty ? null : actions;
  }

  /// Handler de **suppression définitive** effectif, ou `null` si la source ne
  /// sait pas purger — auquel cas aucune action de purge n'est construite.
  ///
  /// Deux voies, dans cet ordre : dépôt appliquant le mixin `ZPurgeable`, puis
  /// rappel `ZCrudSource.onPurge`. Dans les deux cas la **confirmation
  /// irréversible précède l'écriture** : annuler ne touche pas la source.
  FutureOr<void> Function(BuildContext context, T entity)? _purgeHandler() {
    final repo = widget.source.writeRepository;
    if (repo is ZPurgeable<T>) {
      // Cast explicite : `ZPurgeable` ne pose AUCUNE contrainte de superclasse
      // (c'est ce qui lui permet de s'appliquer à un dépôt quelle que soit la
      // façon dont il satisfait le port), donc le test `is` ne promeut pas un
      // `ZRepository<T>?`.
      final purgeable = repo as ZPurgeable<T>;
      return (context, entity) async {
        final entityId = entity.id;
        // Parité avec les autres gestes de corbeille : une entité éphémère n'a
        // pas d'identité à purger (ignorée en silence).
        if (entityId == null) return;
        if (!await _confirmDestructive(context, permanent: true)) return;
        final result = await purgeable.purge(entityId);
        result.fold(
          (failure) => _notifyFailure(context, failure),
          (_) => _refresh(),
        );
      };
    }
    final onPurge = widget.source.onPurge;
    if (onPurge == null) return null;
    return (context, entity) async {
      if (!await _confirmDestructive(context, permanent: true)) return;
      try {
        await onPurge(context, entity);
      } catch (error) {
        // AD-10 : un rappel hôte qui lève est notifié, jamais relancé en
        // erreur asynchrone non capturée.
        _notifyFailure(context, ZDomainFailure('$error'));
        return;
      }
      _refresh();
    };
  }

  // ── Sélection multiple et actions de masse ────────────────────────────────

  /// La sélection est-elle servie par le listing courant ?
  ///
  /// Elle l'est pour le listing **dont l'écran est propriétaire**. En mode
  /// onglets, chaque onglet possède sa vue : hors corbeille, l'écran ne rend
  /// pas la liste et n'y branche donc aucune sélection.
  bool get _selectionOffered => _selection != null && !_tabsRendered;

  /// Résout la gouvernance d'une ligne **par la voie des actions de ligne**
  /// (`zResolveRowActions`) : mêmes actions assemblées, même ACL effective,
  /// même résolveur [ZCrudScreen.rowAcl], même mode de refus. Aucune seconde
  /// logique d'autorisation n'existe pour le lot.
  ///
  /// L'ACL lue est celle **mémorisée** par l'écran (paramètre > scope >
  /// refus) : la barre d'actions vit au-dessus de la liste, donc au-dessus de
  /// la dérivation de scope qui n'enveloppe qu'elle.
  List<ZResolvedRowAction> _resolveGovernanceFor(
    BuildContext context,
    T entity,
  ) {
    final actions = _assembledRowActions();
    if (actions == null) return const <ZResolvedRowAction>[];
    return zResolveRowActions<T>(
      context,
      actions: actions,
      entity: entity,
      acl: _resolvedAcl,
      mode: widget.actionAclMode,
      rowAcl: widget.rowAcl,
      collectionId: widget.collectionId,
    );
  }

  /// `true` si [entity] **admet** l'action [actionId] : la résolution la rend,
  /// et la rend active. Une action masquée pour cette ligne (droit refusé) ou
  /// rendue inerte (ligne restreinte, action inapplicable) vaut refus — donc
  /// **exclusion du lot**, jamais une écriture silencieuse.
  bool _admitsBatch(BuildContext context, T entity, String actionId) {
    for (final action in _resolveGovernanceFor(context, entity)) {
      if (action.id == actionId) return action.enabled;
    }
    return false;
  }

  /// Écriture par racine de la **mise à la corbeille** : dépôt s'il y en a un,
  /// sinon rappel déclaré par la source. Jamais de `throw` (AD-10) — un rappel
  /// hôte qui lève devient une racine échouée, avec sa cause.
  Future<ZResult<Unit>> _softDeleteRoot(
    BuildContext context,
    String rootId,
    T entity,
  ) async {
    final repo = widget.source.writeRepository;
    if (repo != null) return repo.softDelete(rootId);
    final callback = widget.source.onSoftDelete;
    if (callback == null) {
      return Left(const ZDomainFailure('no soft-delete path declared'));
    }
    try {
      await callback(context, entity);
    } catch (error) {
      return Left(ZDomainFailure('$error'));
    }
    return const Right(unit);
  }

  /// Écriture par racine de la **restauration** (mêmes voies, mêmes règles).
  Future<ZResult<Unit>> _restoreRoot(
    BuildContext context,
    String rootId,
    T entity,
  ) async {
    final repo = widget.source.writeRepository;
    if (repo != null) return repo.restore(rootId);
    final callback = widget.source.onRestore;
    if (callback == null) {
      return Left(const ZDomainFailure('no restore path declared'));
    }
    try {
      await callback(context, entity);
    } catch (error) {
      return Left(ZDomainFailure('$error'));
    }
    return const Right(unit);
  }

  /// Écriture par racine de la **suppression définitive** : mixin `ZPurgeable`
  /// du dépôt, sinon rappel `onPurge`. `null` si la source ne sait pas purger —
  /// auquel cas aucune action de masse de purge n'est construite.
  Future<ZResult<Unit>> Function(BuildContext, String, T)? _purgeRootWriter() {
    final repo = widget.source.writeRepository;
    if (repo is ZPurgeable<T>) {
      final purgeable = repo as ZPurgeable<T>;
      return (context, rootId, entity) => purgeable.purge(rootId);
    }
    final callback = widget.source.onPurge;
    if (callback == null) return null;
    return (context, rootId, entity) async {
      try {
        await callback(context, entity);
      } catch (error) {
        return Left(ZDomainFailure('$error'));
      }
      return const Right(unit);
    };
  }

  /// Entités actuellement sélectionnées, dans l'ordre de la sélection.
  List<T> _selectedEntities() {
    final controller = _selection;
    if (controller == null) return const <Never>[];
    return <T>[
      for (final id in controller.selectedIds.value)
        if (_entities[id] != null) _entities[id]!,
    ];
  }

  /// Construit une action de masse **gouvernée**, ou `null` si le droit est
  /// refusé et que le mode déclaré est le masquage.
  ///
  /// Droit refusé en mode [ZActionAclMode.disable] : l'action **garde sa
  /// place**, rendue inerte — grisée, non actionnable, motif du refus annoncé
  /// (`Semantics`). Même partage que pour une action de ligne : masquer relève
  /// du mode déclaré, l'inertie de l'état de l'action. Le callback de refus
  /// reste attaché en second rideau : rien ne s'écrit, quel que soit le chemin
  /// qui l'atteindrait.
  ZBatchAction? _batchEntry(
    BuildContext context,
    ZAcl acl, {
    required ZBatchActionKind kind,
    required String labelKey,
    required IconData icon,
    required ZCrudAction permission,
    required String actionId,
    required bool permanent,
    required bool confirm,
    required Future<ZResult<Unit>> Function(BuildContext, String, T) write,
  }) {
    final granted = acl.can(permission, collectionId: widget.collectionId);
    if (!granted && widget.actionAclMode == ZActionAclMode.hide) return null;
    return ZBatchAction(
      kind: kind,
      label: label(context, labelKey),
      icon: icon,
      enabled: granted,
      disabledReason: granted ? null : label(context, 'actionNotAllowed'),
      onSelected: granted
          ? () => unawaited(
              _runBatch(
                context,
                actionId: actionId,
                permanent: permanent,
                confirm: confirm,
                write: write,
              ),
            )
          : () => _notify(
              context,
              label(context, 'actionNotAllowed'),
              ZToastSeverity.warning,
            ),
    );
  }

  /// Actions de masse **assemblées** de la vue courante, puis celles de
  /// l'application. Mêmes conditions d'existence que les actions de ligne
  /// homonymes : geste voulu par la politique de corbeille, servi par la
  /// source, autorisé par l'ACL.
  List<ZBatchAction> _batchActions(BuildContext context, ZAcl acl) {
    final actions = <ZBatchAction>[];
    if (!_trashView) {
      final hasWriter =
          widget.source.writeRepository != null ||
          widget.source.onSoftDelete != null;
      if (_trashEnabled && widget.trashPolicy.softDelete && hasWriter) {
        final entry = _batchEntry(
          context,
          acl,
          kind: ZBatchActionKind.delete,
          labelKey: 'delete',
          icon: Icons.delete_outline,
          permission: ZCrudAction.delete,
          actionId: 'delete',
          permanent: false,
          confirm: true,
          write: _softDeleteRoot,
        );
        if (entry != null) actions.add(entry);
      }
    } else {
      final hasWriter =
          widget.source.writeRepository != null ||
          widget.source.onRestore != null;
      if (widget.trashPolicy.restore && hasWriter) {
        final entry = _batchEntry(
          context,
          acl,
          kind: ZBatchActionKind.restore,
          labelKey: 'restore',
          icon: Icons.restore_from_trash,
          permission: ZCrudAction.restore,
          actionId: 'restore',
          permanent: false,
          // La restauration n'est pas destructive : elle ne se confirme pas,
          // en lot comme à l'unité.
          confirm: false,
          write: _restoreRoot,
        );
        if (entry != null) actions.add(entry);
      }
      if (widget.trashPolicy.purge) {
        final writer = _purgeRootWriter();
        if (writer != null) {
          final entry = _batchEntry(
            context,
            acl,
            kind: ZBatchActionKind.delete,
            labelKey: 'deleteForever',
            icon: Icons.delete_forever,
            permission: ZCrudAction.clear,
            actionId: 'purge',
            permanent: true,
            confirm: true,
            write: writer,
          );
          if (entry != null) actions.add(entry);
        }
      }
    }
    final extra = widget.batchActions;
    if (extra != null) actions.addAll(extra(context, _selectedEntities()));
    return actions;
  }

  /// Exécute une action de masse : **écarte** les éléments que la gouvernance
  /// n'admet pas, confirme (avec le compte), applique par élément via le
  /// contrôleur de sélection, puis **rend compte**.
  ///
  /// L'ordre n'est pas indifférent : le lot est réduit aux éléments admis
  /// **avant** la confirmation, pour que le nombre annoncé soit celui qui sera
  /// réellement écrit. Annuler la confirmation n'écrit rien.
  Future<void> _runBatch(
    BuildContext context, {
    required String actionId,
    required bool permanent,
    required bool confirm,
    required Future<ZResult<Unit>> Function(BuildContext, String, T) write,
  }) async {
    final controller = _selection;
    if (controller == null) return;
    final selected = controller.selectedIds.value.toList(growable: false);
    final eligible = <String>[];
    var skipped = 0;
    for (final id in selected) {
      final entity = _entities[id];
      if (entity != null && _admitsBatch(context, entity, actionId)) {
        eligible.add(id);
      } else {
        skipped++;
      }
    }
    if (eligible.isEmpty) {
      // Aucun élément admis : rien n'est écrit, et le refus est annoncé plutôt
      // que laissé sans effet visible.
      _notify(
        context,
        label(context, 'actionNotApplicable'),
        ZToastSeverity.warning,
      );
      return;
    }
    // Le lot devient la sélection : ce que l'utilisateur voit compté est
    // exactement ce qui sera soumis.
    controller.setSelection(eligible);
    if (confirm &&
        !await _confirmDestructive(
          context,
          permanent: permanent,
          count: eligible.length,
        )) {
      return;
    }
    final report = await controller.batchApply(
      applyToRoot: (rootId) async {
        final entity = _entities[rootId];
        if (entity == null) {
          return Left(ZDomainFailure('unknown item "$rootId"'));
        }
        return write(context, rootId, entity);
      },
      clearSucceededFromSelection: false,
    );
    controller.clearSelection();
    _refresh();
    widget.selection?.onReport?.call(report);
    if (!mounted) return;
    // Le compte rendu est annoncé depuis le contexte de l'ÉCRAN, jamais depuis
    // celui de la barre : vider la sélection fait disparaître la barre, et une
    // notification adressée à un contexte démonté n'arriverait nulle part.
    _notifyBatchReport(this.context, report, skipped: skipped);
  }

  /// Annonce le résultat d'un lot — **jamais** un succès global masquant un
  /// échec par élément.
  ///
  /// Le message porte le nombre de succès, le nombre d'échecs, le nombre
  /// d'éléments écartés par la gouvernance, et **nomme** les éléments en échec
  /// (les trois premiers, le reste étant abrégé). Une application qui veut la
  /// liste exhaustive la reçoit par `ZSelectionPolicy.onReport`.
  void _notifyBatchReport(
    BuildContext context,
    ZBatchReport report, {
    required int skipped,
  }) {
    final parts = <String>[
      '${report.succeededCount} '
          '${label(context, 'batchSucceeded', fallback: 'succeeded')}',
      if (report.hasFailures)
        '${report.failedCount} '
            '${label(context, 'batchFailed', fallback: 'failed')}',
      if (skipped > 0)
        '$skipped ${label(context, 'batchSkipped', fallback: 'skipped')}',
    ];
    final names = _failedNames(report);
    final message = names.isEmpty
        ? parts.join(' · ')
        : '${parts.join(' · ')} : $names';
    final severity = !report.hasFailures
        ? ZToastSeverity.success
        : report.succeededCount == 0
        ? ZToastSeverity.error
        : ZToastSeverity.warning;
    _notify(context, message, severity);
  }

  /// Noms des éléments en échec (trois au plus, le reste abrégé), lus par la
  /// **première colonne non identifiante** du schéma de liste — celle qui sert
  /// déjà de titre à la tuile générique. Repli sur l'identité quand aucune
  /// valeur lisible n'est disponible.
  String _failedNames(ZBatchReport report) {
    final ids = report.failedRootIds.toList(growable: false);
    if (ids.isEmpty) return '';
    final shown = ids.take(3).map(_entityName).join(', ');
    return ids.length > 3 ? '$shown…' : shown;
  }

  /// Nom lisible de l'élément [id], ou l'identité elle-même à défaut.
  String _entityName(String id) {
    final entity = _entities[id];
    if (entity == null) return id;
    ZFieldSpec? titleField;
    for (final spec in _listFields) {
      if (!spec.isId) {
        titleField = spec;
        break;
      }
    }
    if (titleField == null) return id;
    final value = _cellsOf(entity)[titleField.name];
    final text = value?.toString();
    return (text == null || text.isEmpty) ? id : text;
  }

  /// Barre d'actions de masse, rendue **au-dessus** du listing et visible
  /// seulement quand la sélection n'est pas vide.
  ///
  /// Elle n'écoute que la tranche `selectedIds` du contrôleur (AD-2) : cocher
  /// une case redessine la barre, pas le reste de l'écran — le corps est
  /// construit une fois et transmis tel quel.
  // ── Export du listing ─────────────────────────────────────────────────────

  /// Formats d'export réellement offerts : ceux que la politique déclare,
  /// **dédoublonnés par `id`** et dans l'ordre de déclaration.
  ///
  /// Sans politique — le défaut — la liste est vide : rien n'est offert, et
  /// aucune des mécaniques d'export n'est construite.
  List<ZListExporter> get _exporters {
    final policy = widget.export;
    if (policy == null) return const <ZListExporter>[];
    final seen = <String>{};
    return <ZListExporter>[
      for (final exporter in policy.exporters)
        if (seen.add(exporter.id)) exporter,
    ];
  }

  /// Les lignes qui partiront dans le fichier.
  ///
  /// **La sélection l'emporte** quand elle porte : un utilisateur qui a coché
  /// des éléments puis demandé l'export veut ceux-là, pas la page entière.
  /// L'ordre reste celui de l'écran — la sélection restreint, elle ne réordonne
  /// pas. Sans sélection, c'est tout ce qui est listé.
  List<ZListRow> _exportRows() {
    final rows = _rowsInView;
    final selected = _selection?.selectedIds.value ?? const <String>{};
    if (selected.isEmpty) return rows;
    return <ZListRow>[
      for (final row in rows)
        if (selected.contains(row.id)) row,
    ];
  }

  /// Lignes réellement **sous les yeux** de l'usager : celles de l'onglet
  /// assemblé actif quand il y en a un, celles du listing de l'écran sinon.
  List<ZListRow> get _rowsInView {
    final tab = _activeAssembledTab;
    if (tab == null) return _visibleRows;
    return _tabVisibleRows[_tabControllerKey(tab, trash: _trashView)] ??
        const <ZListRow>[];
  }

  // ── Lecture publique du listing (ZCrudScreenActions) ──────────────────────
  //
  // L'écran relève déjà, pour son propre export, la matière exacte de ce qu'il
  // peint (`_visibleRows`, `_rowsInView`, `_exportRows`) et l'index typé qui la
  // résout (`_entities`). Ces trois membres n'ajoutent aucun mécanisme : ils
  // rendent PUBLIC celui-là, pour qu'un document métier construit par
  // l'application soit fait de la même matière, au même instant, que la liste
  // qu'il prétend imprimer.

  /// Résout [rows] en entités par l'index de projection, dans l'ordre reçu.
  ///
  /// L'index est alimenté par [_project], la voie unique par laquelle une ligne
  /// naît — les deux comptes sont donc égaux par construction : une ligne
  /// rendue a toujours son entité.
  List<ZEntity> _entitiesOf(List<ZListRow> rows) => <ZEntity>[
    for (final row in rows)
      if (_entities[row.id] case final T entity) entity,
  ];

  @override
  List<ZEntity> get entitiesInView => _entitiesOf(_rowsInView);

  @override
  List<ZEntity> get entitiesSelectedOrInView => _entitiesOf(_exportRows());

  /// Notifieur de [entitiesInViewListenable], créé au **premier accès** et
  /// jamais avant.
  ///
  /// Tant qu'il est `null`, [_publishEntitiesInView] est un test de nullité :
  /// un écran qui ne lit pas le listing ne relève rien, ne compare rien et ne
  /// pose aucun rappel de fin de trame — il se comporte exactement comme si
  /// cette lecture n'existait pas.
  ValueNotifier<List<ZEntity>>? _entitiesInViewNotifier;

  /// Une publication est déjà armée pour la fin de la trame courante : plusieurs
  /// relevés dans la même trame (listing d'écran, pages d'onglets) n'en
  /// produisent qu'une.
  bool _entitiesInViewPending = false;

  @override
  ValueListenable<List<ZEntity>> get entitiesInViewListenable {
    final existing = _entitiesInViewNotifier;
    if (existing != null) return existing;
    // Semé à la valeur COURANTE : un abonné qui arrive après le premier rendu
    // lit ce qui est à l'écran, pas une liste vide qu'aucune notification ne
    // viendrait corriger si rien ne changeait ensuite.
    final notifier = ValueNotifier<List<ZEntity>>(entitiesInView);
    _entitiesInViewNotifier = notifier;
    return notifier;
  }

  /// Publie la lecture notifiée, **en fin de trame** et **seulement si elle a
  /// changé**.
  ///
  /// Deux précautions, qui sont la raison d'être de cette méthode (invariant
  /// AD-2) :
  ///
  /// * **fin de trame** — le relevé se fait pendant la construction du listing ;
  ///   notifier là serait demander une reconstruction au milieu d'une
  ///   construction. Le rappel de fin de trame notifie une fois le rendu posé,
  ///   et n'atteint que ce qui écoute ;
  /// * **seulement si elle a changé** — la comparaison porte sur le **contenu**,
  ///   pas sur l'identité de la liste : reconstruire l'écran sans que le listing
  ///   bouge produit une nouvelle liste d'entités identiques, et n'émet rien.
  void _publishEntitiesInView() {
    final notifier = _entitiesInViewNotifier;
    if (notifier == null || _entitiesInViewPending) return;
    _entitiesInViewPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entitiesInViewPending = false;
      if (!mounted) return;
      final next = entitiesInView;
      if (_sameEntities(notifier.value, next)) return;
      notifier.value = next;
    });
  }

  /// Deux lectures portent-elles les **mêmes entités, dans le même ordre** ?
  static bool _sameEntities(List<ZEntity> a, List<ZEntity> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Produit le fichier du format [exporter] et le remet à l'application.
  ///
  /// Rien ici ne peut emporter l'écran (invariant AD-10) : une liste vide
  /// s'annonce, un exporteur en échec — ou qui lève — s'annonce aussi, et la
  /// remise du fichier reste le seul chemin de sortie.
  Future<void> _runExport(BuildContext context, ZListExporter exporter) async {
    final policy = widget.export;
    if (policy == null) return;
    final rows = _exportRows();
    if (rows.isEmpty) {
      _notify(context, label(context, 'exportEmpty'), ZToastSeverity.warning);
      return;
    }
    final title = label(context, widget.title);
    // Mêmes colonnes, même formatage que le rendu : la requête est construite
    // exactement comme `DynamicList` construit la sienne (`zListFormatOf`,
    // voie unique des seams d'affichage). Les ornements d'écran — numéro
    // d'ordre, cases à cocher, boutons d'action — ne sont pas des colonnes et
    // n'entrent donc jamais dans le fichier.
    final request = ZListRenderRequest.fromSchema(
      _listFields,
      rows,
      policy: widget.columnPolicy,
      formatting: zListFormatOf(context),
    );
    // En-têtes résolus AVANT l'appel : l'exporteur est asynchrone, et un
    // `BuildContext` ne se traverse pas au-delà d'un `await`.
    final headers = <String, String>{
      for (final column in request.columns)
        column.header: label(context, column.header),
    };
    final result = await exporter.exportSafely(
      request,
      title: title,
      resolveHeader: (key) => headers[key] ?? key,
    );
    if (!mounted || !context.mounted) return;
    final failure = result.fold<ZFailure?>((f) => f, (_) => null);
    if (failure != null) {
      _notify(
        context,
        '${label(context, 'exportFailed')} — ${failure.message}',
        ZToastSeverity.error,
      );
      return;
    }
    final bytes = result.getOrElse(() => Uint8List(0));
    await policy.onExported(
      context,
      ZExportedBytes(
        bytes: bytes,
        fileName: zExportFileName(
          policy.fileBaseName ?? title,
          exporter.fileExtension,
        ),
        mimeType: exporter.mimeType,
      ),
    );
  }

  /// Une entrée de menu par format offert — « Exporter (CSV) ».
  ///
  /// Les entrées vont au **menu de débordement** de l'app-bar : l'export est un
  /// geste occasionnel, il n'a pas à occuper une place permanente à côté des
  /// gestes du quotidien. Aucun format déclaré ⇒ aucune entrée, donc aucun
  /// menu supplémentaire.
  ///
  /// L'export est une **lecture** : il est offert là où le listing l'est, et
  /// nulle part ailleurs (`ZCrudAction.view`). Aucun droit propre n'est
  /// introduit.
  List<ZAppBarAction> _exportEntries(BuildContext context, ZAcl acl) {
    final exporters = _exporters;
    if (exporters.isEmpty || !_viewAllowed(acl)) {
      return const <ZAppBarAction>[];
    }
    final export = label(context, 'export');
    return <ZAppBarAction>[
      for (final exporter in exporters)
        ZAppBarAction(
          icon: Icons.file_download_outlined,
          semanticLabel: '$export (${label(context, exporter.labelKey)})',
          tooltip: '$export (${label(context, exporter.labelKey)})',
          isOverflow: true,
          onPressed: () => _runExport(context, exporter),
        ),
    ];
  }

  Widget _withBatchBar(BuildContext context, Widget body) {
    final controller = _selection;
    if (controller == null || !_selectionOffered) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ValueListenableBuilder<Set<String>>(
          valueListenable: controller.selectedIds,
          builder: (context, selected, _) => selected.isEmpty
              ? const SizedBox.shrink()
              : _buildBatchBar(context, controller),
        ),
        Expanded(child: body),
      ],
    );
  }

  /// Contenu de la barre : compteur, « tout sélectionner » (si déclaré), puis
  /// les actions de masse gouvernées. Aucune action offerte ⇒ aucune barre
  /// (jamais une barre vide).
  Widget _buildBatchBar(
    BuildContext context,
    ZListSelectionController controller,
  ) {
    final actions = _batchActions(context, _resolvedAcl);
    if (actions.isEmpty) return const SizedBox.shrink();
    final policy = widget.selection!;
    final selectAll = policy.showSelectAll && _visibleIds.isNotEmpty;
    return Padding(
      key: const ValueKey('zCrudBatchBar'),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      child: ZBatchActionBar(
        controller: controller,
        actions: actions,
        countLabelBuilder: (count) =>
            '$count ${label(context, 'selectedCount', fallback: 'selected')}',
        selectAllLabel: selectAll
            ? label(context, 'selectAll', fallback: 'Select all')
            : null,
        onSelectAll: selectAll ? () => controller.selectAll(_visibleIds) : null,
        overflowLabel: label(context, 'moreActions'),
      ),
    );
  }

  // ── Projection et contrôleurs ─────────────────────────────────────────────

  /// Projette une entité en ligne et **indexe** l'entité sous la même clé —
  /// celle de la convention publique `ZListRow.keyOf` (identité réelle, ou clé
  /// éphémère pour une entité non encore persistée). C'est cet index que
  /// `DynamicList.entityFor` consulte, pour les actions de ligne comme pour
  /// les tuiles typées.
  ZListRow _project(T item) {
    final id = ZListRow.keyOf(item);
    _entities[id] = item;
    return ZListRow(id: id, cells: _cellsOf(item));
  }

  /// Construit un contrôleur de listing pour [repo], **gouverné par la
  /// politique de requête déclarée** :
  ///
  /// * `pageSize` devient la taille de page curseur du contrôleur ;
  /// * `baseFilters` devient son socle **persistant** de filtres — le cœur
  ///   garantit qu'ils sont ANDés en tête de chaque requête et qu'aucun
  ///   `setFilters`/`setSearch` ne peut les écraser ;
  /// * `sort` devient le tri **de naissance** du contrôleur
  ///   (`initialSorts`) : la première requête — celle que la construction
  ///   émet — part déjà triée, au lieu d'en émettre une non triée puis de la
  ///   remplacer. Un tri demandé plus tard (`sortBy`) le remplace ;
  /// * `searchScope` et `searchFolding` deviennent la sémantique de recherche
  ///   portée par **chaque** requête du contrôleur — vue corbeille comprise ;
  /// * `paginationMode` choisit **où** la liste est paginée, filtrée et
  ///   cherchée : sur la source (défaut) ou en mémoire ;
  /// * `baseFilterGroups` devient son socle de **disjonctions** persistantes,
  ///   et `itemFilter` son **post-filtre** — le dernier mot sur ce qui est
  ///   listé, appliqué aux entités lues. Déclarer l'un ou l'autre fait
  ///   emprunter au contrôleur la voie mémoire : le cœur refuse qu'une
  ///   déclaration de périmètre soit ignorée par la pagination curseur.
  ///
  /// [policy] permet à un **onglet assemblé** de faire naître son contrôleur
  /// sur la politique composée de l'écran et de sa catégorie — sans quoi
  /// c'est celle de l'écran ([ZCrudScreen.query]) qui s'applique.
  ZListController<T> _createController(
    ZRepository<T> repo, {
    ZListQueryPolicy? policy,
  }) {
    policy ??= widget.query;
    final itemFilter = policy.itemFilter;
    return ZListController<T>(
      repository: repo,
      toRow: _project,
      schema: _listFields,
      pageSize: policy.pageSize,
      mode: policy.paginationMode,
      baseFilters: policy.baseFilters,
      baseFilterGroups: policy.baseFilterGroups,
      // Le post-filtre déclaré est un prédicat sur l'entité : il est remis au
      // contrôleur tel quel, typé sur `T`.
      itemFilter: itemFilter == null
          ? null
          : (T item) => itemFilter.keeps(item),
      initialSorts: policy.sort,
      searchScope: policy.searchScope,
      searchFolding: policy.searchFolding,
      watchMutations: true,
    );
  }

  /// Réapplique à un contrôleur **fraîchement créé** le tri et les filtres déjà
  /// demandés par l'application — le cas de la corbeille ouverte après un tri.
  /// Sans demande en cours (le cas courant), rien n'est émis.
  void _restoreRequestedQuery(ZListController<T> controller) {
    if (_userSort.isNotEmpty) controller.setSort(_userSort);
    if (_userFilters.isNotEmpty) controller.setFilters(_userFilters);
  }

  /// Contrôleur des **vivants**, créé au premier besoin (jamais avant qu'un
  /// rendu autorisé ne le réclame). `null` sur la voie `items`.
  ZListController<T> _ensureLiveController() {
    final existing = _liveController;
    if (existing != null) return existing;
    final controller = _createController(widget.source.repository!);
    _liveController = controller;
    _restoreRequestedQuery(controller);
    return controller;
  }

  ZListController<T> _ensureTrashController() {
    final existing = _trashController;
    if (existing != null) return existing;
    final repo = widget.source.repository!;
    final controller = _createController(_deletedScopeView<T>(repo));
    _trashController = controller;
    _restoreRequestedQuery(controller);
    return controller;
  }

  /// Contrôleur d'un **onglet assemblé** dans la portée courante, créé au
  /// premier rendu de sa page — jamais avant : un onglet jamais ouvert
  /// n'interroge jamais la source.
  ///
  /// Il naît sur la politique **composée** de l'écran et de la catégorie de
  /// l'onglet ([_tabPolicy]) : la catégorie est donc son socle persistant,
  /// ANDé en tête de chaque requête et hors d'atteinte de `setFilters` comme
  /// de `setSearch`. Chercher dans un onglet ne peut pas en faire sortir.
  ///
  /// Si l'onglet est **actif** et qu'une recherche est en cours, le terme lui
  /// est appliqué dès sa naissance : la barre partagée dit alors la vérité sur
  /// ce qui est listé, y compris pour un onglet ouvert pendant une recherche.
  ZListController<T> _ensureTabController(ZListTab tab, {required bool trash}) {
    final key = _tabControllerKey(tab, trash: trash);
    final existing = _tabControllers[key];
    if (existing != null) return existing;
    final repo = widget.source.repository!;
    final controller = _createController(
      trash ? _deletedScopeView<T>(repo) : repo,
      policy: _tabPolicy(tab),
    );
    _tabControllers[key] = controller;
    _restoreRequestedQuery(controller);
    if (_search.isNotEmpty && identical(tab, _activeAssembledTab)) {
      controller.setSearch(_search);
      _searchedTabKey = key;
    }
    return controller;
  }

  /// Politique de requête d'un onglet : celle de l'écran, **élargie du socle de
  /// l'onglet** — les filtres permanents de l'écran d'abord, la catégorie de
  /// l'onglet ensuite.
  ///
  /// Une seule composition sert les deux lecteurs : le contrôleur d'un onglet
  /// assemblé, et le `ZListQueryScope` posé sur la page d'un onglet à builder.
  /// Aucun des deux ne peut donc dériver de l'autre.
  ZListQueryPolicy _tabPolicy(ZListTab tab) {
    final policy = widget.query;
    if (tab.baseFilters.isEmpty &&
        tab.baseFilterGroups.isEmpty &&
        tab.itemFilter == null) {
      return policy;
    }
    return policy.copyWith(
      baseFilters: policy.filtersWith(tab.baseFilters),
      baseFilterGroups: policy.filterGroupsWith(tab.baseFilterGroups),
      // Les deux post-filtres doivent retenir l'entité : un onglet retire, il
      // ne rouvre pas ce que l'écran a écarté (même sens que la cascade d'ACL).
      itemFilter: policy.itemFilterWith(tab.itemFilter),
    );
  }

  // ── Rendu ─────────────────────────────────────────────────────────────────

  /// Résout la variante de vue effective.
  ///
  /// La tuile déclarée par l'application ([ZCrudScreen.itemBuilder], qui reçoit
  /// l'entité `T`) descend **dans le layout choisi par l'application**, quel
  /// qu'il soit — grille de cartes comprise (`ZListLayout.withEntityTiles`).
  /// Un layout qui porte déjà sa propre tuile la garde (l'explicite l'emporte
  /// sur l'injecté). Sans tuile déclarée, le rendu reste la tuile générique du
  /// paquet.
  ZListLayout _effectiveLayout() {
    final itemBuilder = widget.itemBuilder;
    final layout = widget.layout;
    // Présentation en menu : la tuile est enveloppée par `ZRowActionsMenu`
    // (déclencheur et/ou geste contextuel). L'enveloppe n'est posée que sur
    // les tuiles dont l'écran est PROPRIÉTAIRE — jamais sur celle qu'un layout
    // de l'application porte déjà.
    //
    // Elle l'est aussi quand les boutons RESTENT en ligne mais qu'un geste
    // contextuel est offert : le geste s'ajoute alors aux boutons, sans
    // déclencheur supplémentaire.
    final decorate = !_inlineActionsShown || _contextGestureOffered;
    if (layout != null) {
      if (itemBuilder == null) return layout;
      return layout.withEntityTiles<T>(
        _tinted(decorate ? _menuDecorated(itemBuilder) : itemBuilder),
      );
    }
    if (itemBuilder != null) {
      return ZListBuilderLayout.forEntity<T>(
        _tinted(decorate ? _menuDecorated(itemBuilder) : itemBuilder),
      );
    }
    return ZListBuilderLayout(
      itemBuilder: (context, row, columns) {
        final Widget tile = _ZCrudDefaultTile(row: row, columns: columns);
        final entity = _entities[row.id];
        // Ligne sans entité résolue : aucune action ne peut être liée, la
        // tuile est rendue nue (jamais un déclencheur qui n'ouvrirait rien) —
        // et aucune teinte, faute d'entité sur laquelle la décider.
        if (entity == null) return tile;
        return _paintTint(
          context,
          entity,
          decorate ? _rowActionsMenu(context, entity, tile) : tile,
        );
      },
    );
  }

  // ── Coloration de ligne ───────────────────────────────────────────────────

  /// Enveloppe une tuile typée de sa **teinte de ligne**.
  ///
  /// Sans `rowColor` déclaré, le builder est rendu **tel quel** — la même
  /// instance, pas une copie enveloppée : un écran qui ne colore rien n'a pas
  /// un widget de plus dans son arbre.
  ZCrudItemBuilder<T> _tinted(ZCrudItemBuilder<T> builder) =>
      widget.rowColor == null
      ? builder
      : (context, entity, columns) =>
            _paintTint(context, entity, builder(context, entity, columns));

  /// Peint la teinte déclarée **derrière** [tile], et l'annonce.
  ///
  /// La couleur vient entièrement de l'application (invariant FR-26 : aucune
  /// couleur n'est décidée ici) ; le libellé qui la double est résolu comme
  /// tout intitulé du paquet — clé l10n, repli sur le littéral. Sans teinte
  /// (seam absent, ou `null` rendu pour cette ligne), [tile] ressort
  /// **inchangée**.
  ///
  /// La teinte ne porte volontairement **aucune** décoration au-delà de la
  /// couleur : bordure, rayon et élévation appartiennent à la tuile, qui
  /// continue d'être rendue par-dessus telle qu'elle l'était.
  Widget _paintTint(BuildContext context, T entity, Widget tile) {
    final resolve = widget.rowColor;
    if (resolve == null) return tile;
    final tint = resolve(context, entity);
    if (tint == null) return tile;
    final Widget painted = DecoratedBox(
      key: ValueKey<String>('zRowTint_${ZListRow.keyOf(entity)}'),
      decoration: BoxDecoration(color: tint.color),
      child: tile,
    );
    final semantic = tint.semanticLabel;
    if (semantic == null) return painted;
    // Doublage de la couleur (invariant AD-13) : ce que la teinte veut dire,
    // annoncé à qui ne la voit pas. `container` pour que l'annonce accompagne
    // la ligne au lieu de se fondre dans la précédente.
    return Semantics(
      container: true,
      label: label(context, semantic),
      child: painted,
    );
  }

  // ── Présentation des actions de ligne ─────────────────────────────────────

  /// Nombre d'actions **assemblées** de la vue courante — critère de la
  /// présentation adaptative (le filtrage ACL, lui, est par ligne).
  int get _assembledActionCount => _assembledRowActions()?.length ?? 0;

  /// Les actions restent-elles des **boutons visibles dans la ligne** ?
  ///
  /// Vrai pour le défaut ([ZRowActionsPresentation.inline]) et pour la
  /// présentation adaptative tant que la ligne ne porte pas plus d'actions que
  /// le seuil déclaré.
  bool get _inlineActionsShown => switch (widget.rowActionsPresentation) {
    ZRowActionsPresentation.inline => true,
    ZRowActionsPresentation.menu => false,
    ZRowActionsPresentation.contextMenu => false,
    ZRowActionsPresentation.auto =>
      _assembledActionCount <= widget.inlineActionLimit,
  };

  /// Le **geste contextuel** (clic droit / appui long) est-il offert ?
  bool get _contextGestureOffered =>
      widget.rowActionsPresentation == ZRowActionsPresentation.contextMenu ||
      widget.rowActionsPresentation == ZRowActionsPresentation.auto;

  /// Résout les actions d'une ligne **exactement comme `DynamicList`** : les
  /// deux présentations empruntent la **même** voie du socle
  /// (`zResolveRowActions`), pour qu'aucune ne puisse dériver de l'autre sur
  /// une question de droits — refus par défaut sans ACL déclarée
  /// (fail-closed), intersection avec la gouvernance de ligne, filtrage ou
  /// désactivation selon le mode d'ACL déclaré, entité liée à l'effet.
  List<ZResolvedRowAction> _resolveRowActionsFor(
    BuildContext context,
    T entity,
  ) {
    final actions = _assembledRowActions();
    if (actions == null) return const <ZResolvedRowAction>[];
    final ZAcl acl = ZcrudScope.maybeOf(context)?.acl ?? const ZDenyAllAcl();
    return zResolveRowActions<T>(
      context,
      actions: actions,
      entity: entity,
      acl: acl,
      mode: widget.actionAclMode,
      rowAcl: widget.rowAcl,
      collectionId: widget.collectionId,
    );
  }

  /// Enveloppe une tuile typée de l'application du menu d'actions.
  ZCrudItemBuilder<T> _menuDecorated(ZCrudItemBuilder<T> builder) =>
      (context, entity, columns) =>
          _rowActionsMenu(context, entity, builder(context, entity, columns));

  /// Tuile portant le menu d'actions de la ligne.
  ///
  /// Le déclencheur visible est rendu dès que les boutons en ligne ne le sont
  /// pas : l'action reste ainsi atteignable **sans** geste contextuel
  /// (invariant AD-13).
  Widget _rowActionsMenu(BuildContext context, T entity, Widget tile) =>
      ZRowActionsMenu(
        actions: _resolveRowActionsFor(context, entity),
        showTrigger: !_inlineActionsShown,
        secondaryTap: _contextGestureOffered,
        longPress:
            _contextGestureOffered &&
            widget.longPressOwner == ZRowLongPressOwner.contextMenu,
        child: tile,
      );

  /// Rend le listing pour [state].
  ///
  /// [tabKey] non-`null` = ce listing est celui d'un **onglet assemblé** :
  /// ses lignes sont relevées sous cette clé (chaque onglet garde les
  /// siennes), et l'ACL de l'écran n'est **pas** re-dérivée ici — elle est
  /// déjà posée au-dessus de la barre d'onglets, et la restriction de l'onglet
  /// par-dessus. La re-poser écraserait la seconde.
  Widget _buildList(
    BuildContext context,
    ZListViewState state, {
    String? tabKey,
  }) {
    // Portée de « tout sélectionner » : les lignes RÉELLEMENT listées, relevées
    // au moment où elles le sont. Une simple lecture d'état — rien n'est
    // notifié ni reconstruit ici.
    final rows = state is ZListReady ? state.rows : const <ZListRow>[];
    if (tabKey != null) {
      // Vide, sans résultat, en erreur, en chargement : il n'y a rien à
      // l'écran, donc rien à exporter (même règle que le listing d'écran).
      _tabVisibleRows[tabKey] = rows;
    } else if (state is ZListReady) {
      _visibleIds = <String>[for (final row in rows) row.id];
      _visibleRows = rows;
    } else {
      // Vide, sans résultat, en erreur, en chargement : il n'y a rien à
      // l'écran, donc rien à exporter. Conserver les lignes du rendu précédent
      // ferait exporter ce que l'utilisateur ne voit plus.
      _visibleRows = const <ZListRow>[];
    }
    // Lecture notifiée : armée seulement si quelqu'un l'a demandée, honorée en
    // fin de trame et seulement si le contenu a changé (AD-2).
    _publishEntitiesInView();
    final list = DynamicList<T>(
      fields: _listFields,
      state: state,
      // Sélection : le contrôleur possédé par l'écran descend dans la liste,
      // qui rend les cases à cocher. `null` (aucune politique déclarée) ⇒ liste
      // strictement inchangée.
      selection: _selectionOffered ? _selection : null,
      // Ouverture de la sélection : à l'appui long si c'est à elle que ce
      // geste a été déclaré, en permanence sinon (défaut inchangé).
      selectionActivation: widget.longPressOwner == ZRowLongPressOwner.selection
          ? ZListSelectionActivation.longPress
          : ZListSelectionActivation.always,
      layout: _effectiveLayout(),
      columnPolicy: widget.columnPolicy,
      // Les actions ne descendent dans `DynamicList` que si elles doivent y
      // être rendues EN BOUTONS : en présentation menu, la tuile porte le
      // déclencheur, et laisser les boutons doublerait chaque action.
      rowActions: _inlineActionsShown ? _assembledRowActions() : null,
      entityFor: (row) => _entities[row.id],
      rowAcl: widget.rowAcl,
      actionAclMode: widget.actionAclMode,
      collectionId: widget.collectionId,
    );
    final acl = widget.acl;
    if (acl == null || tabKey != null) return list;
    // ACL d'écran : posée par dérivation du scope ambiant (les autres seams
    // sont hérités, jamais recopiés).
    return ZcrudScope.derive(context, acl: acl, child: list);
  }

  /// Corps « voie repository » : contrôleur (vivants ou corbeille) écouté sur
  /// sa seule tranche `state` (rebuild ciblé, AD-2). La recherche n'est plus
  /// dans le corps : elle vit dans l'app-bar du shell (`ZAppBarSearchConfig`).
  ///
  /// [tab] non-`null` = corps d'un **onglet assemblé** : le contrôleur est
  /// celui de l'onglet (sa catégorie en socle), et non celui de l'écran.
  Widget _buildRepositoryBody(BuildContext context, {ZListTab? tab}) {
    final controller = tab == null
        ? (_trashView ? _ensureTrashController() : _ensureLiveController())
        : _ensureTabController(tab, trash: _trashView);
    final tabKey = tab == null
        ? null
        : _tabControllerKey(tab, trash: _trashView);
    return ValueListenableBuilder<ZListViewState>(
      valueListenable: controller.state,
      builder: (context, state, _) =>
          _buildList(context, state, tabKey: tabKey),
    );
  }

  /// Corps « voie items » : partition vivants/corbeille par le prédicat
  /// déclaré, puis recherche in-memory par le moteur du cœur.
  ///
  /// [tab] non-`null` = corps d'un **onglet assemblé** : la catégorie de
  /// l'onglet s'ajoute aux filtres permanents de l'écran (même composition que
  /// la voie dépôt, par la même [_tabPolicy]), et le terme de recherche n'est
  /// appliqué que si cet onglet est l'**actif** — une barre partagée filtre
  /// l'onglet regardé, pas les autres.
  Widget _buildItemsBody(BuildContext context, {ZListTab? tab}) {
    final items = widget.source.items ?? const <Never>[];
    final predicate = widget.source.isDeleted;
    final policy = tab == null ? widget.query : _tabPolicy(tab);
    // Post-filtre déclaré : appliqué ICI aussi, sur les entités et avant leur
    // projection. Une déclaration de périmètre vaut pour l'écran, pas pour une
    // voie de données — la voie `items` n'a pas le droit de l'ignorer.
    final itemFilter = policy.itemFilter;
    final visible = <T>[
      for (final item in items)
        if ((predicate == null || predicate(item) == _trashView) &&
            (itemFilter == null || itemFilter.keeps(item)))
          item,
    ];
    final rows = <ZListRow>[for (final item in visible) _project(item)];
    final searched = tab == null || identical(tab, _activeAssembledTab);
    // Mêmes règles de composition que la voie dépôt, servies par les mêmes
    // fonctions : filtres permanents en tête des filtres demandés, tri demandé
    // sinon tri par défaut. La **taille de page** n'est pas appliquée ici :
    // cette voie rend une liste déjà en mémoire, d'un bloc, sans geste « page
    // suivante » — la tronquer masquerait des éléments sans recours.
    final page = zApplyListRequest(
      rows,
      ZDataRequest(
        filters: policy.filtersWith(_userFilters),
        filterGroups: policy.baseFilterGroups,
        sorts: policy.sortFor(_userSort),
        search: (!searched || _search.isEmpty) ? null : _search,
        searchScope: policy.searchScope,
        searchFolding: policy.searchFolding,
      ),
      schema: _listFields,
    );
    final ZListViewState state;
    if (rows.isEmpty) {
      state = const ZListEmpty();
    } else if (page.rows.isEmpty) {
      state = const ZListNoResults();
    } else {
      state = ZListReady(page.rows);
    }
    return _buildList(
      context,
      state,
      tabKey: tab == null ? null : _tabControllerKey(tab, trash: _trashView),
    );
  }

  Widget _buildBody(BuildContext context) {
    // Mode onglets : le corps est le `ZTabbedList` déclaré. Un onglet à builder
    // possède sa vue ; un onglet assemblé reçoit ici celle que l'écran
    // construit. La corbeille garde les onglets quand ils sont TOUS assemblés
    // (même catégorisation qu'en vue vivante), et retombe sur le listing
    // unique de l'écran sinon.
    if (_tabsRendered) {
      final Widget tabbed = ZTabbedList(
        tabs: _composedTabs(widget.tabs!),
        // L'en-tête partagé de l'application appartient à la vue vivante : la
        // corbeille ne l'a jamais porté (même règle que le listing unique).
        header: _trashView ? null : widget.header,
        isScrollable: widget.tabsScrollable,
        activeIndexNotifier: _activeTabIndex,
        // Onglet mémorisé (0 sans store, ou hors bornes) — le notifieur porte
        // déjà cette valeur depuis `initState`, donc rien n'est renotifié.
        initialIndex: _restoredTabIndex,
      );
      final acl = widget.acl;
      if (acl == null) return tabbed;
      // L'ACL de l'écran est posée AU-DESSUS des onglets : c'est elle que la
      // restriction d'un onglet vient intersecter, et que lisent les listes
      // construites par les onglets (même dérivation que la voie sans
      // onglets, où elle enveloppe la liste assemblée).
      return ZcrudScope.derive(context, acl: acl, child: tabbed);
    }
    final body = _withBatchBar(
      context,
      widget.source.repository != null
          ? _buildRepositoryBody(context)
          : _buildItemsBody(context),
    );
    final header = widget.header;
    if (header == null || _trashView) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        header,
        Expanded(child: body),
      ],
    );
  }

  bool _createOffered(ZAcl acl, int activeTabIndex) {
    if (!widget.canCreate ||
        _mode != ZScreenMode.full ||
        _trashView ||
        !_editionAvailable) {
      return false;
    }
    final tabs = widget.tabs;
    if (tabs != null &&
        tabs.isNotEmpty &&
        activeTabIndex >= 0 &&
        activeTabIndex < tabs.length &&
        !tabs[activeTabIndex].canCreate) {
      return false;
    }
    // Droits de l'onglet actif : ils RESTREIGNENT ceux de l'écran, jamais
    // l'inverse (voir `_tabScopedAcl`).
    return _tabScopedAcl(
      acl,
      activeTabIndex,
    ).can(ZCrudAction.create, collectionId: widget.collectionId);
  }

  /// Nombre d'éléments en corbeille, ou `null` s'il est **inconnu**.
  ///
  /// Deux sources, dans cet ordre : le compte déclaré par l'application
  /// ([ZCrudScreen.trashCount]), puis la dérivation gratuite de la voie
  /// `items` (la liste est déjà en mémoire, le prédicat de suppression déjà
  /// déclaré). Sur la voie dépôt sans déclaration, le compte reste inconnu :
  /// l'écran n'interroge jamais la source pour afficher un nombre.
  int? _resolveTrashCount() {
    final declared = widget.trashCount;
    if (declared != null) return declared.value;
    final items = widget.source.items;
    final predicate = widget.source.isDeleted;
    if (items == null || predicate == null) return null;
    // Le post-filtre de l'écran vaut aussi pour ce compte : la pastille
    // annonce ce que la vue corbeille montrera, jamais davantage.
    final itemFilter = widget.query.itemFilter;
    var count = 0;
    for (final item in items) {
      if (predicate(item) && (itemFilter == null || itemFilter.keeps(item))) {
        count++;
      }
    }
    return count;
  }

  /// L'accès à la corbeille est-il offert ?
  ///
  /// Trois conditions, toutes nécessaires :
  ///
  /// * la corbeille **existe** pour cet écran, et on n'y est pas déjà ;
  /// * l'usager a de quoi y **faire quelque chose** : restaurer ou purger.
  ///   Le droit de *supprimer* n'en fait pas partie — il ouvre la mise à la
  ///   corbeille, pas la corbeille elle-même. Qui peut supprimer sans pouvoir
  ///   ni restaurer ni purger n'a rien à y faire ;
  /// * la corbeille n'est pas **vide**, si la déclaration l'exige
  ///   (`ZTrashPolicy.visibleWhenEmpty: false`). Compte inconnu ⇒ l'accès
  ///   reste offert : une corbeille non comptée n'est pas une corbeille vide.
  bool _trashToggleOffered(ZAcl acl, int? count) {
    if (!_trashEnabled || _trashView) return false;
    final allowed =
        acl.can(ZCrudAction.restore, collectionId: widget.collectionId) ||
        acl.can(ZCrudAction.clear, collectionId: widget.collectionId);
    if (!allowed) return false;
    if (!widget.trashPolicy.visibleWhenEmpty && count != null && count <= 0) {
      return false;
    }
    return true;
  }

  // ── Recherche (détenue par l'app-bar du shell) ────────────────────────────

  /// Contrôleur de listing **actif** (voie repository), ou `null` sur la voie
  /// `items` (filtrage in-memory).
  ZListController<T>? get _activeController {
    if (widget.source.repository == null) return null;
    final tab = _activeAssembledTab;
    if (tab != null) {
      // Lecture SEULE de la table : un onglet dont la page n'a pas encore été
      // montée n'a pas de contrôleur, et en fabriquer un ici interrogerait la
      // source pour une vue que personne ne regarde. Sa naissance appliquera
      // la recherche en cours (voir `_ensureTabController`).
      return _tabControllers[_tabControllerKey(tab, trash: _trashView)];
    }
    return _trashView ? _ensureTrashController() : _ensureLiveController();
  }

  /// La recherche est-elle offerte ?
  ///
  /// Déclarée par [ZCrudScreen.searchEnabled], et retirée dès qu'un onglet est
  /// **opaque** (il porte son propre `ZListTab.builder`) : l'écran ne connaît
  /// pas ce qu'un tel onglet rend, il ne peut donc pas y appliquer un terme de
  /// recherche — et une barre qui ne filtrerait qu'une partie des onglets
  /// mentirait sur ce qu'elle fait.
  ///
  /// Des onglets **tous assemblés** l'offrent : la barre est unique, partagée
  /// par la barre d'onglets, et filtre l'onglet **actif** (voir
  /// [_onSearchChanged]).
  bool get _searchOffered {
    if (!widget.searchEnabled) return false;
    final tabs = widget.tabs;
    if (tabs == null) return true;
    // Corbeille non catégorisée : le corps est le listing unique de l'écran,
    // que la recherche filtre comme n'importe quel listing.
    if (_trashView && !_trashTabsRendered) return true;
    return _tabsFullyAssembled;
  }

  /// Émission de la query par le shell : la valeur est propagée **telle
  /// quelle** (aucune normalisation ici) au contrôleur actif, ou re-partitionne
  /// la voie `items`.
  ///
  /// En mode onglets, « le contrôleur actif » est celui de l'onglet **actif** :
  /// une barre unique, un onglet filtré. L'onglet qui portait la recherche
  /// précédemment est relâché — il retrouve sa liste entière.
  void _onSearchChanged(String query) {
    _search = query;
    final controller = _activeController;
    if (controller != null) {
      _releaseSearchedTab(except: _activeSearchKey);
      controller.setSearch(query);
      _searchedTabKey = _activeSearchKey;
      return;
    }
    if (mounted) setState(() {});
  }

  /// Clé du contrôleur qui doit porter la recherche, ou `null` hors onglets
  /// assemblés.
  String? get _activeSearchKey {
    final tab = _activeAssembledTab;
    if (tab == null) return null;
    return _tabControllerKey(tab, trash: _trashView);
  }

  /// Rend sa liste entière à l'onglet qui portait la recherche, sauf s'il est
  /// celui d'[except]. No-op quand aucun onglet ne la porte.
  void _releaseSearchedTab({String? except}) {
    final key = _searchedTabKey;
    if (key == null || key == except) return;
    _tabControllers[key]?.setSearch('');
    _searchedTabKey = null;
  }

  /// Fait **suivre** la recherche partagée à l'onglet devenu actif : l'onglet
  /// quitté retrouve sa liste entière, le nouvel onglet reçoit le terme
  /// toujours visible dans la barre.
  ///
  /// Rien n'est émis sans onglets, ni quand la barre est vide. Sur la voie
  /// `items`, un simple rendu suffit : la partition est recalculée par
  /// [_buildItemsBody], qui n'applique le terme qu'à l'onglet actif.
  void _followSearchToActiveTab() {
    if (widget.tabs == null) return;
    final target = _activeSearchKey;
    if (target == _searchedTabKey) return;
    _releaseSearchedTab(except: target);
    if (_search.isEmpty) return;
    if (widget.source.repository == null) {
      if (mounted) setState(() {});
      return;
    }
    final controller = target == null ? null : _tabControllers[target];
    // Onglet jamais ouvert : son contrôleur naîtra avec le terme appliqué.
    if (controller == null) return;
    controller.setSearch(_search);
    _searchedTabKey = target;
  }

  /// Bascule vivants ⇄ corbeille : réaligne le filtre du contrôleur devenu
  /// actif sur la query **visible** dans l'app-bar (le shell conserve sa
  /// saisie d'une vue à l'autre).
  void _setTrashView(bool value) {
    // La sélection ne franchit pas la bascule : les éléments cochés d'une vue
    // n'existent pas dans l'autre, et un lot exécuté sur eux serait invisible.
    _clearSelection();
    // La recherche ne franchit pas la bascule sur le contrôleur QUITTÉ : la
    // portée change, et l'onglet laissé derrière doit retrouver sa liste
    // entière. Le terme, lui, reste visible dans la barre et est réappliqué
    // ci-dessous à la vue devenue active.
    _releaseSearchedTab();
    setState(() => _trashView = value);
    if (_search.isEmpty) return;
    final controller = _activeController;
    if (controller == null) return;
    controller.setSearch(_search);
    _searchedTabKey = _activeSearchKey;
  }

  // ── Actions d'app-bar assemblées ──────────────────────────────────────────

  /// Les actions assemblées passent par `ZAppBarAction.widget` (et non par le
  /// constructeur à icône) uniquement pour **porter une `ValueKey`** sur le
  /// glyphe : ces clés sont la surface de ciblage des gardes de l'écran et de
  /// celles des hôtes. Le rendu est **identique** au chemin à icône : le shell
  /// emballe les deux formes de la même façon
  /// (`Semantics(label:) > ExcludeSemantics > enfant`).
  List<ZAppBarAction> _appBarActions(
    BuildContext context,
    ZAcl acl,
    int? trashCount,
    int activeTabIndex,
    int itemCount,
  ) {
    final trashLabel = label(context, 'trash', fallback: 'Trash');
    return <ZAppBarAction>[
      // Voie DÉCLARÉE (liste figée) et voie CONDITIONNELLE (builder) occupent
      // la même place, et sont exclusives par assertion : l'une des deux est
      // toujours vide.
      ...widget.actions,
      ..._builtActions(acl, activeTabIndex, itemCount),
      // Chemin DÉPRÉCIÉ : widget déjà construit, emballé inerte
      // (`onPressed: null`) — c'est le bouton de l'hôte qui reçoit le tap.
      // ignore: deprecated_member_use_from_same_package
      for (final action in widget.appBarActions)
        ZAppBarAction.widget(semanticLabel: '', child: action),
      if (_trashToggleOffered(acl, trashCount))
        ZAppBarAction.widget(
          semanticLabel: _trashActionLabel(context, trashLabel, trashCount),
          tooltip: trashLabel,
          onPressed: () => _setTrashView(true),
          child: _trashToggleGlyph(trashCount),
        ),
      // Export : une entrée par format déclaré, dans le menu de débordement.
      // Aucun format déclaré ⇒ liste vide ⇒ app-bar strictement inchangée.
      ..._exportEntries(context, acl),
      if (_createOffered(acl, activeTabIndex))
        ZAppBarAction.widget(
          semanticLabel: label(context, 'create'),
          tooltip: label(context, 'create'),
          onPressed: _create,
          child: const Icon(Icons.add, key: ValueKey('zCrudCreate')),
        ),
    ];
  }

  /// Actions rendues par [ZCrudScreen.actionsBuilder], ou rien.
  ///
  /// L'ACL transmise est celle que l'écran interroge pour ses propres gestes,
  /// **restreinte par l'onglet actif** (cascade `onglet ∩ écran ∩ scope`) : une
  /// action gouvernée par elle suit le segment courant sans que l'appelant ne
  /// recompose quoi que ce soit.
  ///
  /// Un builder qui lève ne peut pas emporter l'app-bar (invariant AD-10) : il
  /// est traité comme n'ayant rien produit.
  List<ZAppBarAction> _builtActions(ZAcl acl, int activeTabIndex, int count) {
    final builder = widget.actionsBuilder;
    if (builder == null) return const <ZAppBarAction>[];
    try {
      return builder(
        ZAppBarActionsContext(
          acl: _tabScopedAcl(acl, activeTabIndex),
          tabIndex: activeTabIndex,
          itemCount: count,
          isTrashView: _trashView,
        ),
      );
    } catch (_) {
      return const <ZAppBarAction>[];
    }
  }

  /// `true` si la **pastille de comptage** doit accompagner l'accès à la
  /// corbeille : la déclaration la veut (`ZTrashPolicy.showCount`), le compte
  /// est connu, et il n'est pas nul (une pastille à zéro n'apprend rien).
  bool _trashBadgeShown(int? count) =>
      widget.trashPolicy.showCount && count != null && count > 0;

  /// Glyphe de l'accès à la corbeille, **pastillé** du nombre d'éléments
  /// quand il est connu.
  ///
  /// La clé du glyphe (`zCrudTrashToggle`) est conservée dans les deux cas :
  /// elle est la surface de ciblage des gardes de l'écran et de celles des
  /// applications, et ne doit pas dépendre de la présence d'une pastille.
  Widget _trashToggleGlyph(int? count) {
    const glyph = Icon(Icons.delete, key: ValueKey('zCrudTrashToggle'));
    if (!_trashBadgeShown(count)) return glyph;
    return ZCountBadge(
      key: const ValueKey('zCrudTrashCount'),
      count: count!,
      child: glyph,
    );
  }

  /// Annonce de l'accès à la corbeille : son libellé, suivi du nombre
  /// d'éléments quand il est affiché (« Corbeille, 3 éléments dans la
  /// corbeille »). Sans pastille, l'annonce est inchangée.
  String _trashActionLabel(
    BuildContext context,
    String trashLabel,
    int? count,
  ) {
    if (!_trashBadgeShown(count)) return trashLabel;
    final unit = label(context, 'trashCount', fallback: 'items in trash');
    return '$trashLabel, $count $unit';
  }

  /// État **accès refusé** : rendu à la place du listing quand
  /// `ZCrudAction.view` n'est pas autorisé pour la collection.
  ///
  /// Composé des briques d'état de `zcrud_ui_kit` (`ZErrorState`) : icône,
  /// titre et message issus de la l10n générique, couleurs dérivées du thème
  /// (jamais de littéral). Aucune action d'app-bar, aucune recherche : l'écran
  /// ne propose rien de ce qu'il refuse. **Aucune lecture de la source n'est
  /// déclenchée** — le contrôleur de listing n'est pas construit.
  ///
  /// 🔴 La **navigation de l'application y est conservée**
  /// ([ZCrudScreen.drawer] / [ZCrudScreen.endDrawer]) : c'est l'écran où elle
  /// manque le plus. Un refus d'ACL sans menu enfermerait l'usager sur une
  /// page qui ne lui offre ni contenu ni sortie — il devrait quitter
  /// l'application pour changer de module.
  Widget _buildAccessDenied(BuildContext context) => ZPageScaffold(
    title: label(context, widget.title),
    leading: widget.leading,
    drawer: widget.drawer,
    endDrawer: widget.endDrawer,
    body: ZErrorState(
      key: const ValueKey('zCrudAccessDenied'),
      icon: Icons.lock_outline,
      title: label(context, 'accessDenied', fallback: 'Access denied'),
      message: label(
        context,
        'accessDeniedMessage',
        fallback: 'You are not allowed to view this content.',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final acl = _effectiveAcl(context);
    // Mémorisation pour les gestes exposés aux descendants, qui sont
    // interrogés hors du `build` de l'écran (cf. `_resolvedAcl`).
    _resolvedAcl = acl;
    // `view` gouverne l'écran entier : refusé, rien n'est lu ni rendu du
    // listing. Le test précède toute construction de corps (donc de
    // contrôleur), pour qu'un refus n'interroge jamais la source.
    if (!_viewAllowed(acl)) return _buildAccessDenied(context);
    // Le corps est construit UNE fois et passé en `child:` du
    // `ValueListenableBuilder` : au changement d'onglet actif, seule la
    // coquille (donc la liste d'actions) est rebâtie — le sous-arbre du corps
    // est l'instance IDENTIQUE, que Flutter ne reconstruit pas (AD-2).
    final body = _buildBody(context);
    final counter = widget.trashCount;
    if (counter == null) {
      return _buildShell(context, acl, body, _resolveTrashCount());
    }
    // Compte DÉCLARÉ : seule la coquille s'abonne. Le corps est construit une
    // fois, au-dessus de l'abonnement, et transmis **tel quel** — changer le
    // compte redessine la pastille, jamais la liste (AD-2).
    return ValueListenableBuilder<int>(
      valueListenable: counter,
      child: body,
      builder: (context, count, child) =>
          _buildShell(context, acl, child!, count),
    );
  }

  /// Coquille de l'écran (barre, actions, corbeille) au-dessus d'un [body]
  /// **déjà construit**, qu'elle transmet sans le reconstruire.
  Widget _buildShell(
    BuildContext context,
    ZAcl acl,
    Widget body,
    int? trashCount,
  ) {
    return ValueListenableBuilder<int>(
      valueListenable: _activeTabIndex,
      child: body,
      // Le scope des gestes est posé ICI, au-dessus de la coquille : le corps
      // (donc chaque carte) en est descendant, et le changement d'onglet actif
      // rafraîchit l'empreinte des capacités (la création dépend de l'onglet).
      builder: (context, activeTabIndex, child) =>
          _buildScope(context, acl, child!, trashCount, activeTabIndex),
    );
  }

  /// Le scope des gestes et, dessous, la coquille — sous l'abonnement au
  /// **comptage** quand (et seulement quand) un `actionsBuilder` est déclaré.
  ///
  /// 🔴 **Granularité (AD-2)** : l'abonnement est posé ICI, au-dessus de la
  /// seule coquille, avec le corps **déjà construit** passé en `child:`. Un
  /// changement de comptage rebâtit donc la barre d'actions et rien d'autre —
  /// le sous-arbre du corps est l'instance IDENTIQUE, que Flutter ne
  /// reconstruit pas. Poser l'abonnement plus haut (dans `build`) rendrait
  /// chaque changement de comptage responsable d'une reconstruction du listing,
  /// c'est-à-dire exactement le rafraîchissement global que ce paquet existe
  /// pour supprimer — et, le relevé des lignes republiant en fin de trame, la
  /// boucle serait sans fin.
  ///
  /// 🔴 **Un écran sans builder ne paie rien** : `entitiesInViewListenable`
  /// n'est **pas** touché, donc son notifieur n'est pas créé, donc
  /// `_publishEntitiesInView` reste un test de nullité — aucun relevé, aucune
  /// comparaison, aucun rappel de fin de trame.
  Widget _buildScope(
    BuildContext context,
    ZAcl acl,
    Widget body,
    int? trashCount,
    int activeTabIndex,
  ) {
    if (widget.actionsBuilder == null) {
      return _buildScopeAndScaffold(
        context,
        acl,
        body,
        trashCount,
        activeTabIndex,
        0,
      );
    }
    return ValueListenableBuilder<List<ZEntity>>(
      valueListenable: entitiesInViewListenable,
      child: body,
      builder: (context, entities, child) => _buildScopeAndScaffold(
        context,
        acl,
        child!,
        trashCount,
        activeTabIndex,
        entities.length,
      ),
    );
  }

  Widget _buildScopeAndScaffold(
    BuildContext context,
    ZAcl acl,
    Widget body,
    int? trashCount,
    int activeTabIndex,
    int itemCount,
  ) {
    final child = body;
    return ZCrudScreenScope(
      actions: this,
      signature: _actionsSignature(_createOffered(acl, activeTabIndex)),
      // La politique de requête est OFFERTE aux vues que l'application
      // construit sous l'écran — au premier chef la page d'un onglet, qui
      // possède sa propre requête et veut hériter des filtres permanents
      // sans les recopier. Le contexte n'est posé que si une politique est
      // déclarée : sans déclaration, l'arbre reste celui d'avant.
      child: _wrapQueryScope(
        ZPageScaffold(
          title: _trashView
              ? label(context, 'trash', fallback: 'Trash')
              : label(context, widget.title),
          leading: _trashView
              ? IconButton(
                  key: const ValueKey('zCrudTrashBack'),
                  tooltip: label(context, 'back', fallback: 'Back'),
                  onPressed: () => _setTrashView(false),
                  icon: const BackButtonIcon(),
                )
              : widget.leading,
          // Navigation de l'application : relayée TELLE QUELLE au socle,
          // dans les deux vues. En vue corbeille, le bouton de retour occupe
          // le `leading` — Material n'y insère donc pas le bouton de menu
          // (cf. doc de `drawer`) : le tiroir reste ouvrable par glissement
          // depuis le bord.
          drawer: widget.drawer,
          endDrawer: widget.endDrawer,
          actions: _appBarActions(
            context,
            acl,
            trashCount,
            activeTabIndex,
            itemCount,
          ),
          search: _searchOffered
              ? ZAppBarSearchConfig(onQueryChanged: _onSearchChanged)
              : null,
          body: child,
        ),
      ),
    );
  }

  /// Donne à **chaque onglet** la vue qu'il rendra, et la politique de requête
  /// qu'elle lira.
  ///
  /// Deux cas, et un seul critère : la présence du `ZListTab.builder`.
  ///
  /// * **Onglet assemblé** (`builder` absent) : l'écran construit sa liste par
  ///   les **mêmes** fonctions que le mode sans onglets
  ///   (`_buildRepositoryBody`/`_buildItemsBody`, donc `_buildList` et
  ///   `_assembledRowActions`). Il n'existe pas de seconde voie d'assemblage :
  ///   ce que l'onglet rend est ce que l'écran rendrait, catégorisé.
  /// * **Onglet à builder** : sa page est rendue **telle quelle**, simplement
  ///   posée sous la politique composée pour qu'elle puisse la lire
  ///   (`ZListQueryPolicy.of(context)`). Rien d'autre ne change — c'est le
  ///   comportement d'avant, à l'identique.
  ///
  /// La politique composée est celle de [_tabPolicy] : les filtres permanents
  /// de l'écran **puis** le socle de l'onglet. Les deux socles sont ANDés en
  /// tête de chaque requête et restent hors d'atteinte d'une recherche ou d'un
  /// filtre utilisateur : chercher dans un onglet ne peut pas en faire sortir.
  ///
  /// Un onglet à builder sans socle, sous un écran sans politique, est rendu
  /// **tel quel** — aucun `InheritedWidget` de plus dans son arbre.
  List<ZListTab> _composedTabs(List<ZListTab> tabs) => <ZListTab>[
    for (var i = 0; i < tabs.length; i++) _composedTab(tabs[i], i),
  ];

  ZListTab _composedTab(ZListTab tab, int index) {
    final declared = tab.builder;
    if (declared == null) {
      return tab.copyWith(
        builder: (context) => _wrapTabScrollMemory(
          index,
          _wrapTabQueryScope(
            tab,
            widget.source.repository != null
                ? _buildRepositoryBody(context, tab: tab)
                : _buildItemsBody(context, tab: tab),
          ),
        ),
      );
    }
    // Rien à offrir à la page : ni l'écran ni l'onglet ne déclarent quoi que
    // ce soit (la politique composée est la mesure des deux à la fois) — et
    // aucun store d'onglets n'est déclaré.
    if (_tabPolicy(tab).declaresNothing && _tabsStore == null) return tab;
    return tab.copyWith(
      // La page doit être construite SOUS la portée, sinon elle lirait
      // l'ancienne (ou aucune).
      builder: (context) => _wrapTabScrollMemory(
        index,
        _wrapTabQueryScope(tab, Builder(builder: declared)),
      ),
    );
  }

  /// Enveloppe la page de l'onglet [index] de sa **mémoire de défilement** —
  /// **uniquement** quand un store est déclaré.
  ///
  /// Sans store, [child] est rendu tel quel : pas un widget de plus dans
  /// l'arbre, pas un écouteur de plus sur les notifications de défilement.
  ///
  /// La mémoire est posée **par onglet**, à l'intérieur de la page keep-alive :
  /// chaque onglet a donc sa propre position, et rejoindre un onglet déjà
  /// monté ne rejoue rien. C'est la moitié du geste qu'un index d'onglet seul
  /// ne restitue pas.
  Widget _wrapTabScrollMemory(int index, Widget child) {
    if (_tabsStore == null) return child;
    return _ZTabScrollMemory(
      key: ValueKey<String>('zCrudTabScroll_${_tabsScopeKey}_$index'),
      initialOffset: _readStoredScrollOffset(index),
      onOffsetChanged: (offset) => _writeStoredScrollOffset(index, offset),
      child: child,
    );
  }

  /// Enveloppe [child] de la politique composée de [tab] — **uniquement**
  /// quand il y a quelque chose à déclarer.
  Widget _wrapTabQueryScope(ZListTab tab, Widget child) {
    final policy = _tabPolicy(tab);
    if (policy.declaresNothing) return child;
    return ZListQueryScope(policy: policy, child: child);
  }

  /// Enveloppe [child] du contexte de politique de requête — **uniquement**
  /// quand une politique est déclarée. Sans déclaration, [child] est rendu tel
  /// quel : l'arbre est celui d'avant, à l'identique.
  Widget _wrapQueryScope(Widget child) {
    final policy = widget.query;
    if (policy.declaresNothing) return child;
    return ZListQueryScope(policy: policy, child: child);
  }
}

/// **Mémoire de défilement d'une page d'onglet** — restaure la position au
/// montage, relève chaque déplacement, et n'existe que si un `ZListTabsStore`
/// est déclaré.
///
/// ## Pourquoi une observation, et pas un `ScrollController` injecté
///
/// Les listes du cœur (`ListView.builder` de `DynamicList`) ne prennent **pas**
/// de `ScrollController` : il n'existe aucun seam pour leur en donner un, et en
/// ouvrir un dans `zcrud_core` dépasserait de loin ce qu'un écran assemblé doit
/// se permettre. Un `PrimaryScrollController` posé au-dessus s'y attacherait
/// bien, mais **exploserait** dès qu'une page rendrait deux zones défilantes
/// verticales (assertion « attached to multiple scroll views ») — un
/// `itemBuilder` d'application suffit à provoquer le cas.
///
/// L'observation par notification n'a aucun de ces deux défauts : elle ne
/// s'attache à rien, elle **écoute** ce que la page dispatche déjà.
/// `ScrollNotification` porte le déplacement, `ScrollMetricsNotification` porte
/// le moment où la liste connaît enfin ses dimensions — c'est-à-dire le moment
/// où une position mémorisée redevient atteignable (avant, la liste charge
/// encore : sauter alors ne ferait rien).
///
/// ## Ce qui est filtré, et pourquoi
///
/// * `depth == 0` — seule la zone défilante **la plus proche** compte : un
///   défilement imbriqué (carrousel dans une tuile) n'est pas la position de la
///   liste ;
/// * `axis == Axis.vertical` — une barre horizontale n'est pas une position de
///   lecture ;
/// * la restauration n'a lieu **qu'une fois**, et seulement si un offset non
///   nul est mémorisé : un écran qui rouvre en haut ne provoque aucun saut.
class _ZTabScrollMemory extends StatefulWidget {
  const _ZTabScrollMemory({
    required this.initialOffset,
    required this.onOffsetChanged,
    required this.child,
    super.key,
  });

  /// Position mémorisée à rejoindre (`0` ⇒ rien à restaurer).
  final double initialOffset;

  /// Notifié à chaque déplacement relevé — c'est la voie d'écriture unique.
  final ValueChanged<double> onOffsetChanged;

  /// La page de l'onglet, rendue telle quelle.
  final Widget child;

  @override
  State<_ZTabScrollMemory> createState() => _ZTabScrollMemoryState();
}

class _ZTabScrollMemoryState extends State<_ZTabScrollMemory> {
  /// La position mémorisée a-t-elle déjà été rejointe ? Une seule fois, sans
  /// quoi le premier défilement de l'usager serait aussitôt défait.
  bool _restored = false;

  /// Un saut est déjà programmé pour la fin de la trame courante.
  bool _pendingJump = false;

  /// Dernière position ÉCRITE — la comparaison évite d'écrire à chaque pixel
  /// une valeur que le store a déjà.
  double? _lastWritten;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    // Un `ScrollStartNotification` sur une position mémorisée non encore
    // rejointe signifie que l'usager a pris la main : la restauration n'a plus
    // lieu d'être, elle lui reprendrait son geste.
    if (notification is ScrollStartNotification) _restored = true;
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _record(notification.metrics.pixels);
    }
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    _maybeRestore(notification.context, notification.metrics);
    return false;
  }

  void _record(double pixels) {
    if (!pixels.isFinite) return;
    final normalized = pixels < 0 ? 0.0 : pixels;
    if (_lastWritten == normalized) return;
    _lastWritten = normalized;
    widget.onOffsetChanged(normalized);
  }

  /// Rejoint la position mémorisée dès que la liste a des dimensions qui la
  /// rendent atteignable — et jamais pendant la construction en cours.
  void _maybeRestore(BuildContext scrollContext, ScrollMetrics metrics) {
    if (_restored || _pendingJump) return;
    final target = widget.initialOffset;
    if (target <= 0) {
      _restored = true;
      return;
    }
    if (metrics.maxScrollExtent <= 0) return;
    _pendingJump = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingJump = false;
      if (!mounted || _restored) return;
      final position = Scrollable.maybeOf(scrollContext)?.position;
      if (position == null || !position.hasContentDimensions) return;
      _restored = true;
      final clamped = target.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      position.jumpTo(clamped);
      // La valeur rejointe est celle que le store porte déjà : la noter évite
      // une réécriture immédiate par le `ScrollEndNotification` du saut.
      _lastWritten = clamped;
    });
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: _onMetrics,
          child: widget.child,
        ),
      );
}

/// Décorateur **corbeille** d'un `ZRepository` : force
/// `ZDeletedScope.deletedOnly` sur toutes les lectures porteuses d'un
/// `ZDataRequest` — c'est lui qui fait du `ZListController` (qui ne connaît
/// pas les portées de suppression) un listing de corbeille, avec recherche et
/// pagination inchangées.
///
/// `watchAll` délègue tel quel (il ne sert que de **signal de mutation** à
/// `watchMutations`). Les écritures délèguent. [dispose] est un no-op : le
/// décorateur ne possède pas le dépôt décoré.
///
/// **Capacité de recherche préservée** : un décorateur ne sait pas chercher
/// mieux que le dépôt qu'il décore. Quand celui-ci déclare déléguer la
/// recherche (`ZDelegatesSearch`), la vue corbeille doit le déclarer aussi —
/// sans quoi la corbeille rendrait la barre inerte que le listing vivant, lui,
/// vient de rendre exacte. C'est le rôle de [_deletedScopeView], qui choisit
/// la variante portant la capacité.
class _ZDeletedScopeRepository<T extends ZEntity> implements ZRepository<T> {
  _ZDeletedScopeRepository(this._inner);

  final ZRepository<T> _inner;

  ZDataRequest _scoped(ZDataRequest? request) =>
      (request ?? const ZDataRequest()).copyWith(
        deletedScope: ZDeletedScope.deletedOnly,
      );

  @override
  Future<ZResult<List<T>>> getAll({ZDataRequest? request}) =>
      _inner.getAll(request: _scoped(request));

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) =>
      _inner.count(request: _scoped(request));

  @override
  Stream<List<T>> watch(ZDataRequest request) => _inner.watch(_scoped(request));

  @override
  Stream<List<T>> watchAll() => _inner.watchAll();

  @override
  Future<ZResult<T>> getById(String id) => _inner.getById(id);

  /// Délègue **tel quel**, `collectionId` compris : un décorateur ne réinterprète
  /// pas le contrat qu'il décore. Ce qui arrive ici vient d'un appelant qui a
  /// choisi sa redirection en connaissance de cause — l'écran, lui, n'en passe
  /// aucune (voir `ZCrudScreen.collectionId`, clé d'autorisation).
  @override
  Future<ZResult<T>> save(T item, {String? collectionId}) =>
      _inner.save(item, collectionId: collectionId);

  @override
  Future<ZResult<Unit>> softDelete(String id) => _inner.softDelete(id);

  @override
  Future<ZResult<Unit>> restore(String id) => _inner.restore(id);

  @override
  void dispose() {
    // No-op : le dépôt décoré appartient à l'appelant.
  }
}

/// Vue corbeille d'un dépôt qui **délègue la recherche** : le même décorateur,
/// plus la capacité `ZDelegatesSearch` du dépôt décoré.
class _ZDeletedScopeDelegatingSearchRepository<T extends ZEntity>
    extends _ZDeletedScopeRepository<T>
    with ZDelegatesSearch<T> {
  _ZDeletedScopeDelegatingSearchRepository(super.inner);
}

/// Vue **corbeille** de [inner], portant la même capacité de recherche que lui.
///
/// Un décorateur est transparent pour la portée de suppression, il doit l'être
/// aussi pour ce que le dépôt sait faire : décorer un dépôt qui ne sert pas la
/// recherche ne lui apprend pas à chercher.
ZRepository<T> _deletedScopeView<T extends ZEntity>(ZRepository<T> inner) =>
    zRepositoryServesSearch(inner)
    ? _ZDeletedScopeRepository<T>(inner)
    : _ZDeletedScopeDelegatingSearchRepository<T>(inner);

/// Construit le contenu d'une surface d'édition pour l'état courant : le
/// drapeau de lecture, et le rappel de bascule vers l'édition (`null` s'il
/// n'est pas offert).
typedef _ZCrudSurfaceBuilder =
    Widget Function(BuildContext context, bool readOnly, ZCrudOpener? onEdit);

/// Enveloppe **à état** de la surface présentée : c'est elle qui rend le retour
/// vers l'édition possible **sans refermer la fiche**.
///
/// Le drapeau de lecture était jusqu'ici figé au moment de l'ouverture. En le
/// portant dans un `State` posé au sommet de la surface, la bascule devient un
/// simple `setState` : le formulaire est reconstruit **à la même place**, donc
/// son `State` — et le `ZFormController` qu'il possède — survit. Les valeurs
/// déjà chargées, la position de défilement et les modifications en cours sont
/// conservées ; aucune route n'est fermée ni rouverte.
class _ZCrudEditionSurface extends StatefulWidget {
  const _ZCrudEditionSurface({
    required this.initialReadOnly,
    required this.canEdit,
    required this.builder,
  });

  /// État d'ouverture : `true` pour une fiche de détail.
  final bool initialReadOnly;

  /// La bascule vers l'édition est-elle **permise** ? Décidé à l'ouverture par
  /// l'écran (mode, source, ACL avec l'entité pour cible).
  final bool canEdit;

  final _ZCrudSurfaceBuilder builder;

  @override
  State<_ZCrudEditionSurface> createState() => _ZCrudEditionSurfaceState();
}

class _ZCrudEditionSurfaceState extends State<_ZCrudEditionSurface> {
  late bool _readOnly = widget.initialReadOnly;

  /// Bascule la surface vers l'édition. Sans effet si elle y est déjà, ou si
  /// le geste n'est pas permis (AD-10 : un second appel ne lève pas).
  Future<void> _switchToEdition() async {
    if (!_readOnly || !widget.canEdit || !mounted) return;
    setState(() => _readOnly = false);
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _readOnly,
    // `null` tant que le geste n'a pas de sens (surface déjà éditable) ou
    // n'est pas permis : l'appelant ne dessine alors pas de bouton mort.
    _readOnly && widget.canEdit ? _switchToEdition : null,
  );
}

/// Tuile générique par défaut : première colonne en titre, colonnes suivantes
/// en sous-titre `en-tête : valeur formatée` (formats du cœur —
/// `ZListColumn.format`).
class _ZCrudDefaultTile extends StatelessWidget {
  const _ZCrudDefaultTile({required this.row, required this.columns});

  final ZListRow row;
  final List<ZListColumn> columns;

  @override
  Widget build(BuildContext context) {
    if (columns.isEmpty) return const SizedBox.shrink();
    final first = columns.first;
    final rest = columns.skip(1).toList(growable: false);
    return ListTile(
      key: ValueKey<String>('zCrudTile_${row.id}'),
      title: Text(first.format(row.cells[first.name])),
      subtitle: rest.isEmpty
          ? null
          : Text(
              <String>[
                for (final column in rest)
                  '${column.header} : ${column.format(row.cells[column.name])}',
              ].join(' · '),
            ),
    );
  }
}

/// Formulaire d'édition **dérivé** : possède son `ZFormController` (cycle
/// create/dispose — AD-2), rend un `DynamicEdition` sur les specs dérivées et
/// un pied enregistrer/annuler. L'échec de persistance est affiché **dans**
/// la surface (`Semantics` liveRegion), jamais levé (AD-10).
///
/// En mode lecture ([readOnly]), c'est **le même formulaire, les mêmes
/// champs** : seul le rendu change (`DynamicEdition.readOnly`, qui force
/// `spec.copyWith(readOnly: true)` sur chaque champ), et le pied se réduit à
/// une fermeture — il n'y a rien à enregistrer.
class _ZCrudEditionForm extends StatefulWidget {
  const _ZCrudEditionForm({
    required this.title,
    required this.fields,
    required this.initialValues,
    required this.onSubmit,
    this.readOnly = false,
  });

  /// Titre du mode courant (création / duplication / édition / consultation),
  /// déjà résolu.
  final String title;

  final List<ZFieldSpec> fields;
  final Map<String, Object?> initialValues;
  final Future<ZFailure?> Function(Map<String, Object?> values) onSubmit;

  /// Rendu en **consultation** : tous les champs en lecture seule, aucun
  /// bouton d'enregistrement.
  final bool readOnly;

  @override
  State<_ZCrudEditionForm> createState() => _ZCrudEditionFormState();
}

class _ZCrudEditionFormState extends State<_ZCrudEditionForm> {
  late final ZFormController _controller = ZFormController(
    initialValues: widget.initialValues,
    visibleFields: <String>[for (final f in widget.fields) f.name],
  );

  final ValueNotifier<String?> _error = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _controller.dispose();
    _error.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy.value) return;
    _busy.value = true;
    _error.value = null;
    // Voie de normalisation UNIQUE du socle (`zNormalizeFormValues`) : la même
    // que celle du formulaire seul. Les champs en lecture seule et ceux qu'une
    // condition masque n'en sortent pas — leur valeur d'origine, elle, reste
    // portée par `initialValues`.
    final values = <String, Object?>{
      ...widget.initialValues,
      ...zNormalizeFormValues(
        fields: widget.fields,
        controller: _controller,
        persistedValueOf: _controller.baselineValueOf,
      ),
    };
    final failure = await widget.onSubmit(values);
    if (!mounted) return;
    _busy.value = false;
    if (failure == null) {
      Navigator.of(context).pop();
    } else {
      _error.value = failure.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 12),
              child: Text(
                widget.title,
                key: const ValueKey('zCrudFormTitle'),
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          Flexible(
            child: DynamicEdition(
              // Le mode de rendu d'un champ est arrêté à son MONTAGE (une
              // fiche de lecture n'alloue ni contrôleur de texte ni clavier —
              // invariant AD-2). Le retour vers l'édition doit donc remonter
              // les champs : la place est keyée par le mode. Ce qui survit à
              // la bascule est ce qui compte — le `ZFormController` du
              // formulaire, donc les valeurs déjà chargées, et la surface
              // elle-même, qui n'est ni fermée ni rouverte.
              key: ValueKey<bool>(widget.readOnly),
              controller: _controller,
              fields: widget.fields,
              shrinkWrap: true,
              // PAS de `collapseStore` ici, et c'est mesuré, pas oublié : ce
              // formulaire ne déclare AUCUNE section (`sections` n'est pas
              // passé, et `ZCrudScreen` n'expose nulle part de quoi en
              // déclarer). Sans section, rien n'est repliable ; un store
              // branché ici ne serait jamais ni lu ni écrit. Le jour où
              // l'écran assemblé acceptera des sections, le relais devra
              // suivre dans le même geste — c'est la seule surface d'édition
              // du socle qui ne le porte pas.

              // Dernier maillon de la chaîne : le drapeau atteint enfin le
              // rendu des champs, où toutes les familles le respectent déjà.
              readOnly: widget.readOnly,
            ),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: _error,
            builder: (context, message, _) => message == null
                ? const SizedBox.shrink()
                : Semantics(
                    liveRegion: true,
                    container: true,
                    label: message,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: 8,
                        bottom: 8,
                      ),
                      child: Text(
                        message,
                        key: const ValueKey('zCrudFormError'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                // En consultation, le pied n'offre qu'une **fermeture** :
                // « Annuler » n'a pas de sens là où rien n'a été saisi, et le
                // bouton d'enregistrement n'existe pas.
                child: TextButton(
                  key: widget.readOnly
                      ? const ValueKey('zCrudFormClose')
                      : const ValueKey('zCrudFormCancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    label(context, widget.readOnly ? 'close' : 'cancel'),
                  ),
                ),
              ),
              if (!widget.readOnly)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _busy,
                    builder: (context, busy, _) => FilledButton(
                      key: const ValueKey('zCrudFormSave'),
                      onPressed: busy ? null : _submit,
                      child: Text(label(context, 'save')),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
