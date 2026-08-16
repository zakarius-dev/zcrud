/// `ZSubListSeams` / `ZSubListSeamRegistry` — **canal déclaratif des seams de
/// présentation** des familles `subItems` et `dynamicItem`.
///
/// ## Le problème que ce canal résout
///
/// `ZSubListFieldWidget` acceptait déjà des seams (`itemTitleBuilder`, `acl`),
/// et `ZDynamicItemFieldWidget` un `fieldsResolver` — mais **aucun n'était
/// atteignable par le chemin nominal d'édition** : `ZFieldWidget` ne
/// transmettait que `field`/`initialValue`/`collectionId`/`onChanged`. Pour
/// toucher ces seams, un hôte devait **remplacer le champ entier** par un
/// `fieldBuilder`, c'est-à-dire renoncer à tout le reste du moteur (agrégation
/// vers la tranche parente, granularité AD-2, dialogues, ACL, soft-delete).
/// « Le socle sait faire, le présentateur ne relaie pas » : c'est la classe de
/// défaut qui a produit les derniers écarts remontés par les hôtes.
///
/// ## Pourquoi un canal, et pas un relais de plus
///
/// Ajouter un paramètre au dispatcher aurait reproduit le défaut au coup
/// suivant : un relais est une liste qu'il faut **penser à tenir à jour**, et
/// c'est précisément ce qui a été oublié. Le canal supprime le relais : ce sont
/// les widgets `subItems`/`dynamicItem` eux-mêmes qui **résolvent** leurs seams
/// dans le [ZcrudScope] ambiant, exactement comme ils y résolvent déjà l'ACL.
/// Conséquence : un seam déclaré est servi **par le chemin nominal**
/// (`DynamicEdition` sans `fieldBuilder`), **et aussi** par une construction
/// directe du widget — il n'y a pas de chemin de seconde classe.
///
/// ## Aucune closure dans le domaine (invariants AD-3/AD-14)
///
/// `ZSubListConfig` reste `const` et pur-données : **aucun** builder n'y entre.
/// Les seams vivent ici, en couche `presentation/`, portés par un registre
/// **instanciable** injecté (jamais un singleton statique mutable, invariant
/// AD-4).
///
/// ## Déclarer des seams
///
/// ```dart
/// final seams = ZSubListSeamRegistry()
///   ..register('lignes', ZSubListSeams(
///     itemTitleBuilder: (item) => '${item['designation']}',
///     itemActionsBuilder: (context, view) => <Widget>[
///       IconButton(icon: const Icon(Icons.print), onPressed: () {}),
///     ],
///   ));
///
/// ZcrudScope(
///   acl: const ZAllowAllAcl(),
///   subListSeamRegistry: seams,
///   child: DynamicEdition(fields: mesChamps, ...),
/// );
/// ```
///
/// ## Clé de résolution
///
/// Un champ est apparié par [ZSubListSeamRegistry.resolve], dans cet ordre —
/// **première entrée trouvée, jamais de fusion entre niveaux** :
///
/// 1. `field.widgetKind` — le **discriminant déclaré** déjà utilisé par
///    `ZWidgetRegistry` (deux sous-listes peuvent partager un jeu de seams) ;
/// 2. `field.name` — le nom du champ, clé la plus directe (c'est ainsi que le
///    moteur legacy portait ses builders : sur la déclaration du champ) ;
/// 3. `field.type.name` — `'subItems'` / `'dynamicItem'`, entrée **attrape-tout**
///    d'un formulaire : elle ne s'applique que si l'hôte l'a explicitement
///    enregistrée sous ce nom.
///
/// Même cascade défensive que `ZWidgetRegistry` : une clé inconnue rend `null`
/// (invariant AD-10), jamais une exception, et le rendu natif est conservé.
///
/// ## Chaînage et ombrage
///
/// `ZSubListSeamRegistry(parent: ambiant)` crée un registre **enfant** : le
/// lookup remonte la chaîne quand une clé manque localement, et une clé
/// redéclarée localement **ombre** le parent (enfant > parent). Une collision
/// **locale** lève [ZDuplicateRegistrationError] (jamais un « last-wins »
/// silencieux). La chaîne est **vivante** (un enregistrement ultérieur du
/// parent est visible de l'enfant) et **acyclique par construction** (`parent`
/// est `final`).
///
/// ## Menu d'item et arbitrage des mutations
///
/// Deux seams complètent le rendu par un **geste** : [ZSubItemMenuOption]
/// (entrées de menu déclaratives par item, gouvernées par l'ACL du socle) et
/// [ZSubItemCrudHook] (arbitrage **avant** chaque mutation : refuser,
/// transformer, laisser passer). Ils portent le vocabulaire `onCrud(item, crud,
/// {option})` du moteur legacy, sans reprendre ce que ce dernier faisait mal —
/// voir les dartdoc de ces deux types.
///
/// ## Le crochet CRUD comme NORMALISATEUR MÉTIER (lignes d'un document)
///
/// Le cas mesuré chez les hôtes n'est pas « une liste d'items isolée » : ce sont
/// les **lignes d'un document** (master-detail intra-formulaire), où le parent
/// **agrège** ce que les lignes produisent. Trois capacités le rendent
/// atteignable, toutes portées par la requête et l'issue — jamais par un
/// contexte ni un contrôleur exposés :
///
/// | Besoin réel | Canal |
/// |---|---|
/// | lire le taux de taxe / la devise du document | [ZSubItemCrudRequest.parent] ([ZValueOf]) |
/// | dire **pourquoi** on refuse (« X existe déjà ») | [ZSubItemCrudOutcome.veto] + `reasonKey` |
/// | mettre à jour les **totaux** du document | [ZSubItemCrudOutcome.parentPatch] |
/// | afficher un montant **calculé, jamais saisi** | `ZSubListConfig.summaryColumns` (domaine) |
///
/// La quatrième ligne ne relève **pas** de ce canal, et c'est délibéré : une
/// colonne de résumé est une **décision de données statique**, elle se déclare
/// `const` avec le reste de la config. Le canal ne porte que ce que le domaine
/// ne peut pas porter.
///
/// ## Ce que le canal ne fait pas
///
/// Il ne porte **aucune** décision de données **statique** : un mode
/// d'affichage, des colonnes de résumé, la **forme de présentation** du
/// formulaire d'item (`ZSubItemFormPresentation` — dialogue / feuille / page),
/// le sous-schéma `const` et les gabarits de création `const` restent déclarés
/// dans `ZSubListConfig` (`const`, pur-données).
///
/// ## Ce qui, en revanche, ne PEUT pas être `const` : le dérivé
///
/// Deux décisions de données ont besoin de l'**état du formulaire parent**, et
/// une déclaration `const` ne peut structurellement pas les exprimer :
/// [ZSubListSeams.subSchemaResolver] (les champs d'un item dépendent de ce qui
/// a été saisi ailleurs) et [ZSubListSeams.creationTemplatesResolver] (n'offrir
/// à l'ajout que les gabarits que l'état courant autorise — c'est l'usage réel
/// du moteur legacy, dont le menu d'ajout listait les **transitions permises**
/// depuis le dernier événement de la liste).
///
/// Elles vivent donc **ici**, en présentation, et non dans `ZSubListConfig` :
/// mettre une closure dans le domaine violerait AD-3/AD-14, et le canal existe
/// précisément pour accueillir ce que le domaine ne peut pas porter. Elles
/// n'échappent pas pour autant à l'invariant AD-2 — voir la mécanique de
/// **traçage et d'abonnement ciblé** décrite sur [ZSubListSchemaResolver].
///
/// C'est aussi ici, et non dans les options d'item, que vit l'équivalent du
/// `popUpMenuOptions` legacy : c'était un menu **d'ajout**, pas un menu par
/// item.
library;

import 'package:flutter/widgets.dart';

import '../../domain/edition/z_condition_evaluator.dart' show ZValueOf;
import '../../domain/edition/z_field_spec.dart';
import '../../domain/edition/z_sub_list_config.dart';
import '../../domain/ports/z_acl.dart';
import '../../domain/registry/z_registry_error.dart';

/// Seam de **présentation** : dérive un **titre/résumé** lisible d'un item
/// (`Map`) — titre du dialogue d'édition, repli de résumé de ligne (mode
/// compact) et libellé de puce (mode tags). Vit en couche widget (JAMAIS dans
/// la config domaine — garde `domain_purity_test`).
///
/// **Reçoit toujours la donnée BRUTE** de l'item : ni
/// [ZSubListSeams.itemTransformer] ni aucune projection d'affichage ne
/// s'appliquent à son entrée. C'est un contrat volontairement stable — un titre
/// se dérive de la donnée, pas de son habillage.
///
/// La donnée fournie est l'item tel qu'il serait **agrégé vers le parent** :
/// les tranches des `itemFields` **plus** les clés hors sous-schéma conservées
/// depuis la graine (`id` en premier). Un builder peut donc lire un
/// identifiant technique sans que celui-ci soit déclaré au sous-schéma.
typedef ZSubItemTitleBuilder = String Function(Map<String, dynamic> item);

/// Vue **immuable** d'un item telle qu'un seam de présentation la reçoit.
///
/// Ajouter un membre ici est **additif** : les seams des hôtes ne se cassent
/// pas quand la vue s'enrichit (c'est la raison d'être de l'objet, plutôt
/// qu'une liste de paramètres positionnels).
@immutable
class ZSubListItemView {
  /// Construit la vue `const` d'un item.
  const ZSubListItemView({
    required this.field,
    required this.data,
    required this.index,
    required this.itemId,
    this.deleted = false,
    this.readOnly = false,
  });

  /// Spécification du champ **conteneur** (`subItems`/`dynamicItem`).
  final ZFieldSpec field;

  /// Données de l'item **telles qu'elles doivent être affichées** :
  /// [ZSubListSeams.itemTransformer] y est déjà appliqué s'il est déclaré.
  /// Contient les tranches des `itemFields` **et** les clés hors sous-schéma
  /// conservées depuis la graine.
  final Map<String, dynamic> data;

  /// Position de l'item dans la liste rendue (0 pour `dynamicItem`).
  final int index;

  /// Identité **stable** de l'item (clé de place ; jamais réutilisée).
  final String itemId;

  /// `true` ssi l'item est **soft-deleted** (mode compact avec
  /// `ZSubListConfig.softDelete`) : affiché barré, restaurable, exclu de
  /// l'agrégation parent.
  final bool deleted;

  /// `true` ssi le champ conteneur est en lecture seule.
  final bool readOnly;
}

/// Vue **immuable** passée à [ZSubListSeams.listViewBuilder].
@immutable
class ZSubListViewData {
  /// Construit la vue `const` d'une sous-liste.
  const ZSubListViewData({
    required this.field,
    required this.items,
    required this.children,
    required this.itemBuilder,
  });

  /// Spécification du champ conteneur (`subItems`).
  final ZFieldSpec field;

  /// Données d'affichage de chaque item, **dans l'ordre rendu**
  /// ([ZSubListSeams.itemTransformer] appliqué). Même longueur et même ordre
  /// que [children]. Les items soft-deleted y figurent (ils restent visibles et
  /// restaurables).
  final List<Map<String, dynamic>> items;

  /// Lignes déjà construites, une par item — **construction impatiente**
  /// (toutes les lignes sont bâties avant l'appel). Sur une liste longue,
  /// préférez [itemBuilder] dans un `ListView.builder` : la construction y
  /// redevient paresseuse.
  final List<Widget> children;

  /// Construit la ligne de l'item d'indice donné (borne dépassée ⇒
  /// `SizedBox.shrink()`, invariant AD-10 — un conteneur hôte ne fait jamais
  /// échouer le rendu en demandant un indice qui n'existe plus).
  final Widget Function(BuildContext context, int index) itemBuilder;
}

/// Rendu **libre** d'un item (remplace le contenu résumé de sa ligne).
typedef ZSubItemWidgetBuilder = Widget Function(
  BuildContext context,
  ZSubListItemView item,
);

/// Actions **supplémentaires** d'un item — rendues **en plus** des actions
/// natives, jamais à leur place (une action native reste gouvernée par l'ACL et
/// par `readOnly`).
typedef ZSubItemActionsBuilder = List<Widget> Function(
  BuildContext context,
  ZSubListItemView item,
);

/// Conteneur **libre** de la liste d'items (remplace le conteneur natif).
typedef ZSubListViewBuilder = Widget Function(
  BuildContext context,
  ZSubListViewData view,
);

/// Habillage **libre** de l'en-tête de la sous-liste. Reçoit le **contrôle
/// d'ajout natif** (bouton `+` ou menu de gabarits) déjà filtré par l'ACL :
/// quand la création n'est pas autorisée, c'est un `SizedBox.shrink()` qui est
/// passé — l'ACL n'est **jamais** contournée par ce seam.
typedef ZSubListCaptionBuilder = Widget Function(
  BuildContext context,
  Widget addControl,
);

/// Transformation d'un item **avant affichage seulement**.
///
/// Le résultat alimente les cellules de résumé, [ZSubListSeams.itemBuilder],
/// [ZSubListSeams.itemActionsBuilder] et [ZSubListSeams.listViewBuilder]. Il
/// n'entre **jamais** dans les données : ni dans l'agrégation vers la tranche
/// parente, ni dans la graine du dialogue de consultation/édition, ni dans
/// l'entrée de [ZSubItemTitleBuilder]. Éditer un item transformé rendrait la
/// donnée à sa forme brute — le transformateur est un habillage, pas une
/// migration.
typedef ZSubItemTransformer = Map<String, dynamic> Function(
  BuildContext context,
  Map<String, dynamic> item,
);

/// Calcule la **liste des sous-champs à rendre** d'un `dynamicItem` à partir de
/// son état courant. Défensif : le résultat est **intersecté** avec les
/// `itemFields` de la config (aucune tranche orpheline, invariants AD-10/AD-2).
typedef ZSubItemFieldsResolver = List<ZFieldSpec> Function(
  Map<String, dynamic> state,
);

/// Calcule le **sous-schéma d'un item** (`subItems`) depuis l'état du
/// **formulaire PARENT** — l'équivalent du `subItemsFieldsBuilder(editionState)`
/// du moteur legacy.
///
/// ## Pourquoi une lecture par NOM, et pas la `Map` de l'état parent
///
/// Le legacy recevait `editionState` en entier. Ici le résolveur reçoit un
/// [ZValueOf] : une lecture **par nom**, et c'est ce qui rend le seam compatible
/// avec l'invariant AD-2.
///
/// Le socle exécute le résolveur **une première fois en le TRAÇANT** : il note
/// les noms réellement lus et ne s'abonne qu'à **ces tranches-là**. Taper dans
/// un champ parent que le résolveur ne lit pas ne déclenche donc rien du tout.
/// Une `Map` complète aurait rendu ce ciblage impossible : le socle aurait dû
/// re-résoudre à **chaque frappe** du formulaire parent, sur toutes ses
/// tranches. Le précédent est déjà dans le socle — c'est exactement la mécanique
/// de `ZFieldSpec.choicesResolver`.
///
/// Conséquences, à connaître avant d'écrire un résolveur :
/// - **le jeu d'abonnements est FIGÉ au montage** (première branche exécutée) :
///   les dépendances d'un résolveur doivent être **stables**, comme les
///   `sources` d'une `ZDerivation` ;
/// - **la tranche du champ lui-même n'est jamais abonnée**, même si le
///   résolveur la lit (il le peut : la lecture rend la liste d'items agrégée).
///   S'abonner à sa propre tranche ferait re-résoudre le schéma à **chaque
///   agrégation d'item** — donc à chaque frappe dans un sous-champ, ce que ce
///   canal existe précisément pour éviter.
///
/// ## Ce que le socle garantit quand le schéma CHANGE
///
/// Les `ZFormController` des items **ne sont jamais recréés** (invariant AD-2) :
/// le socle **réconcilie** les tranches — il en ouvre pour les champs apparus,
/// et **déplace dans le résidu hors sous-schéma** la valeur des champs disparus
/// (elle n'est donc pas détruite, et revient si le champ revient). L'état, le
/// focus et les `TextEditingController` des champs inchangés survivent.
///
/// Résolveur qui **lève** ⇒ repli sur `ZSubListConfig.itemFields` (invariant
/// AD-10) : jamais un écran vide, jamais une exception.
typedef ZSubListSchemaResolver = List<ZFieldSpec> Function(ZValueOf parent);

/// Calcule les **gabarits de création** d'une sous-liste depuis l'état du
/// **formulaire PARENT** — l'équivalent du `popUpMenuOptions(crud)` legacy,
/// dont les entrées étaient calculées dans une closure fermant sur
/// `editionState`.
///
/// C'est le dynamisme qui manquait à `ZSubListConfig.creationTemplates` :
/// `const` et pur-données, celui-ci ne peut pas exprimer « les seules actions
/// autorisées **après l'événement courant** ». Mêmes règles de traçage,
/// d'abonnement ciblé et de repli défensif que [ZSubListSchemaResolver] — le
/// jeu de noms tracés est l'**union** de ce que lisent les deux résolveurs.
///
/// Résolveur qui **lève** ⇒ repli sur `ZSubListConfig.creationTemplates`
/// (invariant AD-10). Résultat **vide** ⇒ le contrôle d'ajout redevient le
/// simple bouton `+` (aucun menu à ouvrir) : un menu vide ne s'affiche jamais.
typedef ZSubListTemplatesResolver = List<ZSubListItemTemplate> Function(
  ZValueOf parent,
);

/// Prédicat de **visibilité par item** d'une option de menu
/// ([ZSubItemMenuOption.isVisible]).
///
/// Il reçoit la **vue** de l'item, pas sa `Map` brute : un prédicat qui ne
/// verrait que les données ne saurait pas si la ligne est soft-deleted ou en
/// lecture seule, et proposerait « restaurer » sur un item vivant.
///
/// **Il ne peut que RESTREINDRE.** L'ACL est consultée **avant** lui : un
/// prédicat qui rend `true` sur une action refusée n'ouvre rien (voir
/// [ZSubItemMenuOption.permission]). Un prédicat qui **lève** masque l'option
/// (invariant AD-10 — le repli d'un doute de visibilité est de ne pas offrir le
/// geste, jamais de l'offrir).
typedef ZSubItemMenuVisibility = bool Function(ZSubListItemView item);

/// **Option de menu d'un item** de sous-liste (mode `compact`) — une entrée
/// déclarative, gouvernée par l'ACL du socle, qui déclenche
/// [ZSubListSeams.onCrud].
///
/// ## Ce que le moteur legacy faisait, et ce qui n'est PAS porté
///
/// Le legacy (`DynamicSubItemMenuOption`) portait `label`, `value`, `type`,
/// `data` et un prédicat `filter(item)` — **et** trois méthodes
/// `toMap()`/`fromMap()`/`toJson()` qui prétendaient sérialiser une **closure**
/// et un **`Type`** (`fromMap` relisait `map['filter']` comme une fonction
/// depuis du JSON). C'est cassé par construction : **aucune** de ces trois
/// méthodes n'est portée, et ce type n'est **pas** sérialisable. Un seam de
/// présentation ne traverse jamais la persistance.
///
/// Deux autres écarts mesurés dans les dépôts hôtes, volontairement corrigés
/// ici plutôt que reproduits :
/// - `filter` n'était **jamais invoqué** (grep négatif sur `dodlp-otr` et
///   `iffd` : les seuls appels de `filter(item)` appartiennent à `DynamicTab`,
///   une autre classe). Les hôtes filtraient donc leur **liste** d'options à la
///   main, à la construction. Ici le prédicat est **vivant** et évalué par item ;
/// - le `label` était un **libellé brut codé en dur**. Ici, [labelKey] est une
///   **clé l10n** résolue par le canal habituel (`ZcrudScope.labels` → locale →
///   table `en` → [labelFallback]), invariant FR-26.
///
/// ## Où l'option est rendue
///
/// Dans un **menu de débordement** en fin de ligne (`Icons.more_vert`, tooltip
/// `moreActions`), **après** les actions natives (consulter / modifier /
/// supprimer) et **après** les actions ajoutées par
/// [ZSubListSeams.itemActionsBuilder]. Aucune affordance native n'est
/// remplacée, aucune n'est doublée : les trois canaux sont distincts et
/// cumulatifs.
///
/// Le déclencheur n'est rendu que si **au moins une** option survit au filtrage
/// pour CETTE ligne — jamais un menu vide, et rien du tout quand aucune option
/// n'est déclarée (rétro-compatibilité stricte).
///
/// **Aucun appui long** n'est ajouté : l'affordance est visible, focalisable au
/// clavier et annoncée (invariant AD-13). Un chemin exclusivement gestuel serait
/// inaccessible ; un chemin gestuel **redondant** n'apporterait rien ici.
@immutable
class ZSubItemMenuOption {
  /// Construit une option `const`.
  const ZSubItemMenuOption({
    required this.id,
    required this.labelKey,
    this.labelFallback,
    this.icon,
    this.isVisible,
    this.payload = const <String, Object?>{},
    this.destructive = false,
    this.permission,
  });

  /// Identité **stable** de l'option, transmise au crochet
  /// ([ZSubItemCrudRequest.option]) et utilisée comme clé de rendu.
  ///
  /// L'option elle-même est portée comme `value` du `PopupMenuItem` :
  /// la résolution du choix se fait par **identité d'objet**, jamais par
  /// position (un rebuild survenu menu ouvert ne peut pas déclencher l'option
  /// du voisin, ni lever un `RangeError` dans un gestionnaire de tap).
  final String id;

  /// Clé l10n du libellé (repli [labelFallback], puis la clé elle-même).
  /// **Jamais un libellé codé en dur** (invariant FR-26).
  final String labelKey;

  /// Repli affiché quand [labelKey] n'est résolue nulle part.
  final String? labelFallback;

  /// Icône optionnelle affichée devant le libellé (`null` ⇒ libellé seul).
  final IconData? icon;

  /// Prédicat de visibilité **par item** (voir [ZSubItemMenuVisibility]).
  /// `null` ⇒ visible pour tout item que l'ACL autorise.
  final ZSubItemMenuVisibility? isVisible;

  /// **Charge utile opaque** de l'option (le `value`/`data` du legacy, fondus
  /// en un seul porteur). Le socle ne l'interprète **jamais** : elle est
  /// recopiée telle quelle dans [ZSubItemCrudRequest.option].
  final Map<String, Object?> payload;

  /// `true` ⇒ option **destructive** : rendue avec la couleur d'erreur du
  /// thème (`ColorScheme.error`, jamais une couleur codée en dur) et, à défaut
  /// de [permission] explicite, gouvernée par [ZCrudAction.delete].
  final bool destructive;

  /// Droit exigé pour **offrir** l'option. `null` ⇒ [ZCrudAction.delete] si
  /// [destructive], sinon [ZCrudAction.update].
  ///
  /// Ce défaut est **restrictif par conception** : une option agit sur un item,
  /// donc au minimum elle l'écrit. Un défaut `null`-permissif aurait fait de ce
  /// canal une porte dérobée capable d'offrir un geste sur un formulaire où
  /// l'ACL refuse tout.
  final ZCrudAction? permission;

  /// Droit effectivement exigé (voir [permission]).
  ZCrudAction get effectivePermission =>
      permission ?? (destructive ? ZCrudAction.delete : ZCrudAction.update);
}

/// Ce qui a déclenché un appel de [ZSubListSeams.onCrud].
///
/// Objet **additif** (comme [ZSubListItemView]) : l'enrichir ne casse pas les
/// crochets déjà écrits par les hôtes.
@immutable
class ZSubItemCrudRequest {
  /// Construit la requête `const` d'un crochet CRUD.
  const ZSubItemCrudRequest({
    required this.field,
    required this.action,
    required this.data,
    this.item,
    this.option,
    this.template,
    this.parent,
  });

  /// Spécification du champ **conteneur** (`subItems`).
  final ZFieldSpec field;

  /// Action à l'origine de l'appel : [ZCrudAction.create], [ZCrudAction.update],
  /// [ZCrudAction.delete] pour les actions **natives** ; pour une option de
  /// menu, c'est [ZSubItemMenuOption.effectivePermission] — le droit même qui a
  /// autorisé son affichage, jamais un autre.
  final ZCrudAction action;

  /// Donnée **proposée** par le geste, avant application :
  /// - `create` — la graine validée dans le dialogue d'ajout ;
  /// - `update` — l'item tel qu'il sortirait du dialogue d'édition (résidu hors
  ///   sous-schéma compris, `id` en premier) ;
  /// - `delete` — l'item **actuel**, tel qu'il serait retiré ;
  /// - option de menu — l'item **actuel**, inchangé (l'option ne propose rien
  ///   d'elle-même : sa charge utile vit dans [option]).
  final Map<String, dynamic> data;

  /// Item visé — `null` pour une **création** (l'item n'existe pas encore).
  final ZSubListItemView? item;

  /// Option de menu à l'origine de l'appel, ou `null` pour une action native.
  /// C'est le **seul** discriminant fiable entre « l'utilisateur a validé le
  /// dialogue » et « l'utilisateur a choisi l'entrée X ».
  final ZSubItemMenuOption? option;

  /// **Gabarit de création choisi**, ou `null` — pendant exact de [option] pour
  /// l'ajout : le seul discriminant entre « l'utilisateur a cliqué sur `+` » et
  /// « l'utilisateur a choisi le gabarit X ».
  ///
  /// Renseigné **uniquement** sur [ZCrudAction.create], et seulement quand le
  /// contrôle d'ajout est un **menu de gabarits** (déclarés en config ou
  /// dérivés par [ZSubListSeams.creationTemplatesResolver]). `null` partout
  /// ailleurs — un simple bouton `+` ne choisit rien.
  ///
  /// C'est ce champ qui porte le `{option}` du moteur legacy sur la création :
  /// sans lui, seules les **valeurs par défaut** du gabarit atteignaient le
  /// crochet, fondues dans [data] et donc indiscernables d'une saisie de
  /// l'utilisateur.
  ///
  /// ```dart
  /// onCrud: (r) async {
  ///   if (r.action == ZCrudAction.create && r.template != null) {
  ///     return ZSubItemCrudOutcome.replace(<String, dynamic>{
  ///       ...r.data,
  ///       'type': r.template!.defaults['type'],
  ///       'horodatage': DateTime.now().toIso8601String(),
  ///     });
  ///   }
  ///   return const ZSubItemCrudOutcome.proceed();
  /// }
  /// ```
  final ZSubListItemTemplate? template;

  /// **Lecture de l'état du formulaire PARENT**, par nom de champ — `null`
  /// quand la sous-liste est construite hors formulaire (aucun parent).
  ///
  /// ## Pourquoi une lecture, et pas le `ZFormController` parent
  ///
  /// C'est le même vocabulaire que les deux résolveurs dérivés du canal
  /// ([ZSubListSeams.subSchemaResolver],
  /// [ZSubListSeams.creationTemplatesResolver]) : un [ZValueOf] **lit**, il
  /// n'écrit pas. Exposer le contrôleur ouvrirait la réentrance — un crochet
  /// appelé en pleine mutation pourrait écrire dans le formulaire qui l'a
  /// appelé, et rien n'empêcherait plus de casser l'invariant AD-2 depuis un
  /// seam de présentation. Pour **écrire**, il y a
  /// [ZSubItemCrudOutcome.parentPatch] : le crochet **décrit**, le socle
  /// applique.
  ///
  /// C'est le besoin mesuré du cas réel : les lignes d'une commande lisent le
  /// taux de taxe global, la devise et les options du document parent pour
  /// normaliser la ligne saisie.
  ///
  /// ## Aucun abonnement n'en découle
  ///
  /// Contrairement aux résolveurs, cette lecture n'est **pas tracée** : elle a
  /// lieu au moment d'un geste utilisateur, une fois, et ne crée aucune
  /// souscription. Un crochet ne « suit » donc pas une tranche parente — il en
  /// prend une photo à l'instant où il arbitre.
  final ZValueOf? parent;
}

/// Issue d'un appel de [ZSubListSeams.onCrud].
///
/// ## Pourquoi un résultat TYPÉ et pas le `Future<Map?>` du legacy
///
/// Le legacy interprétait `null` comme « n'applique rien » — c'était sa **seule**
/// voie de véto, et elle était **ambiguë** : `null` disait aussi bien « je
/// refuse » que « je m'en suis chargé moi-même » que « rien à changer ». Mesuré :
/// l'implémentation de référence (`edition_screen.dart`) retourne `null` sur
/// **toutes** ses branches, y compris celles qui viennent d'appliquer la
/// mutation — le socle ne pouvait donc rien déduire du retour.
///
/// Trois issues explicites lèvent l'ambiguïté :
/// - [ZSubItemCrudOutcome.proceed] — applique la donnée de la requête telle
///   quelle (défaut, comportement natif) ;
/// - [ZSubItemCrudOutcome.replace] — applique une donnée **transformée** ;
/// - [ZSubItemCrudOutcome.veto] — **n'applique rien** (la voie de véto
///   explicite, celle que le legacy exprimait par `null`).
///
/// ## Pourquoi pas `Either<ZFailure, T>` (AD-5/AD-11)
///
/// `Either<ZFailure, T>` gouverne les **ports de dépôt** du domaine : un échec
/// y est une valeur que l'appelant transporte, journalise, réessaie. Ici, il n'y
/// a ni dépôt, ni appelant métier — c'est un seam de **présentation**, et le
/// seul destinataire possible d'un échec est l'infrastructure d'erreurs de
/// l'application. Un `ZFailure` n'aurait aucun consommateur ; il ferait entrer
/// `dartz` dans la couche widget pour rien.
///
/// **Ce qui n'est pas négociable l'est autrement** : un crochet qui **lève** est
/// traité comme un **véto** (aucune mutation) **et** son erreur est signalée à
/// `FlutterError.reportError` — donc à `FlutterError.onError`, à la zone, au
/// rapporteur de crash de l'application. Elle n'est **jamais** avalée, et elle
/// ne casse **jamais** le rendu (invariant AD-10).
///
/// ## Deux pouvoirs de plus, portés par l'ISSUE
///
/// - **Dire pourquoi** ([ZSubItemCrudOutcome.veto] + `reasonKey`) : un véto muet
///   laisse l'utilisateur devant un geste qui « n'a rien fait ». L'usage réel
///   affiche « X existe déjà dans la liste » **avant** de refuser.
/// - **Corriger le formulaire parent** ([parentPatch]) : le crochet **décrit**
///   les tranches parentes à écrire, le socle les applique **en une fois**.
///
/// Les deux sont portés par l'issue plutôt que par la requête, et c'est la même
/// raison dans les deux cas : le crochet **décrit** ce qu'il veut, il ne le fait
/// pas lui-même. Un `BuildContext` capturé dans la requête serait employé
/// **après un `await`** (le crochet est asynchrone) — le piège classique du
/// widget démonté ; et un `ZFormController` parent exposé ouvrirait la
/// réentrance en pleine mutation.
@immutable
class ZSubItemCrudOutcome {
  /// Applique la donnée de la requête **telle quelle** (comportement natif).
  ///
  /// [parentPatch] (`null` par défaut ⇒ comportement d'avant, à l'identique)
  /// décrit les tranches du **formulaire parent** à écrire une fois la mutation
  /// appliquée — voir [parentPatch].
  const ZSubItemCrudOutcome.proceed({this.parentPatch})
      : vetoed = false,
        data = null,
        reasonKey = null,
        reasonFallback = null;

  /// Applique [replacement] **à la place** de la donnée proposée.
  ///
  /// Seules les clés du **sous-schéma** (`itemFields`) sont écrites dans les
  /// tranches ; les clés **hors sous-schéma** rejoignent le résidu de l'item
  /// (`id` et clés annexes), exactement comme une graine venue du parent. C'est
  /// ce qui rend le crochet utile à la création : un hôte peut y **attribuer un
  /// identifiant** que le sous-schéma ne déclare pas.
  ///
  /// **Ignoré pour [ZCrudAction.delete]** : il n'y a rien à écrire sur un item
  /// qui disparaît. Un hôte qui veut le conserver **véto**.
  const ZSubItemCrudOutcome.replace(
    Map<String, dynamic> replacement, {
    this.parentPatch,
  })  : vetoed = false,
        data = replacement,
        reasonKey = null,
        reasonFallback = null;

  /// **N'applique rien** — la voie de véto explicite.
  ///
  /// [reasonKey] (`null` par défaut ⇒ véto **muet**, comportement d'avant à
  /// l'identique) est la **clé l10n** du motif rendu à l'utilisateur — voir
  /// [reasonKey].
  const ZSubItemCrudOutcome.veto({this.reasonKey, this.reasonFallback})
      : vetoed = true,
        data = null,
        parentPatch = null;

  /// `true` ⇒ aucune mutation n'est appliquée.
  final bool vetoed;

  /// Donnée de remplacement, ou `null` (proceed/veto).
  final Map<String, dynamic>? data;

  /// **Clé l10n du motif** d'un véto — `null` ⇒ véto muet (défaut).
  ///
  /// Résolue par le canal habituel (`ZcrudScope.labels` → locale → table `en` →
  /// [reasonFallback] → la clé), invariant FR-26 : **jamais un libellé codé en
  /// dur**, y compris ici, où le texte vient pourtant d'une règle métier de
  /// l'hôte.
  ///
  /// Le socle le rend **lui-même**, une fois, au retour du crochet : annonce au
  /// lecteur d'écran (invariant AD-13) **et** `SnackBar` si un
  /// `ScaffoldMessenger` est disponible — la même mécanique best-effort que le
  /// retour de copie d'une fiche de lecture. Sans `ScaffoldMessenger`, l'annonce
  /// a tout de même lieu et **rien n'est levé** (invariant AD-10).
  ///
  /// Il n'est pas rendu pour `proceed`/`replace` : un motif explique un refus.
  /// Un crochet qui veut informer sans refuser dispose de ses propres moyens —
  /// il est, lui, dans le code de l'application.
  final String? reasonKey;

  /// Repli affiché quand [reasonKey] n'est résolue nulle part.
  final String? reasonFallback;

  /// **Correctif du formulaire PARENT** : les tranches à écrire (`nom → valeur`)
  /// une fois la mutation appliquée. `null` (défaut) ⇒ rien n'est écrit,
  /// comportement d'avant à l'identique.
  ///
  /// ## Pourquoi un correctif décrit, et pas le contrôleur parent
  ///
  /// C'est le besoin mesuré des **lignes d'un document** : le crochet recalcule
  /// les totaux (« total HT », « total TVA », « total TTC ») et les dépose dans
  /// des tranches **voisines** du formulaire parent, que des champs calculés
  /// affichent. Sans ce canal, l'hôte n'a aucun moyen de le faire depuis un
  /// crochet — il devrait remplacer le champ entier.
  ///
  /// Exposer le `ZFormController` parent l'aurait permis aussi, et bien plus :
  /// écrire pendant une mutation en cours, déclencher une re-résolution qui
  /// rappelle le crochet, casser l'invariant AD-2 depuis un seam de
  /// présentation. Le correctif **décrit** ; c'est le socle qui écrit, **une
  /// seule fois**, après l'agrégation de la sous-liste — de sorte que le parent
  /// voit la liste à jour **et** ses totaux dans le même état cohérent.
  ///
  /// **Trois bornes, à connaître avant d'écrire un crochet :**
  /// 1. **un véto n'applique rien**, correctif compris — c'est le sens même du
  ///    véto (le constructeur de véto ne l'accepte donc pas) ;
  /// 2. **la tranche de la sous-liste elle-même est ignorée** : une entrée
  ///    nommée comme le champ conteneur écraserait l'agrégation que le socle
  ///    vient de publier. Pour changer les items, il y a
  ///    [ZSubItemCrudOutcome.replace] ;
  /// 3. l'écriture passe par le canal **granulaire** du contrôleur parent (une
  ///    tranche à la fois) : seuls les champs nommés se reconstruisent, jamais
  ///    le formulaire entier (invariant AD-2).
  final Map<String, Object?>? parentPatch;
}

/// **Crochet CRUD** d'une sous-liste — l'équivalent de `onCrud(item, crud,
/// {option})` du moteur legacy.
///
/// ## Ordre d'appel : AVANT la mutation, toujours
///
/// Le crochet est appelé **après** que l'utilisateur a confirmé (dialogue
/// validé, suppression confirmée, option choisie) et **avant** que quoi que ce
/// soit ne soit écrit dans l'état imbriqué ou agrégé vers la tranche parente.
/// C'est ce qui lui donne ses deux pouvoirs — **refuser** et **transformer** —
/// et c'est déjà l'ordre du legacy (qui appelait puis appliquait le retour).
///
/// Un crochet appelé **après** ne pourrait qu'observer : refuser exigerait de
/// défaire une agrégation déjà publiée, donc d'émettre `onChanged` **deux
/// fois** et de laisser fuiter, entre les deux, une donnée que l'hôte venait
/// justement de refuser.
///
/// ## Ce qu'il ne remplace pas
///
/// Il ne remplace **ni** les dialogues natifs **ni** l'ACL : quand il est
/// appelé, le geste a déjà été autorisé par [ZAcl] et la donnée proposée a déjà
/// été saisie. Le crochet arbitre, il n'ouvre pas de porte.
typedef ZSubItemCrudHook = Future<ZSubItemCrudOutcome> Function(
  ZSubItemCrudRequest request,
);

/// **Bundle immuable** des seams de présentation d'un champ `subItems` /
/// `dynamicItem`. Chaque seam est **optionnel** : `null` ⇒ rendu natif
/// **strictement** inchangé (rétro-compatibilité stricte).
///
/// ## Applicabilité par mode d'affichage
///
/// | Seam | `inline` | `compact` | `tags` | `dynamicItem` |
/// |---|---|---|---|---|
/// | [acl] | — | ✅ actions de ligne | — | — |
/// | [itemTitleBuilder] | — | ✅ titre de ligne (sans `summaryFields`) + titre de dialogue | ✅ libellé de puce + titre de dialogue | — |
/// | [itemBuilder] | — | ✅ remplace le contenu résumé | — | — |
/// | [itemActionsBuilder] | ✅ après retrait/réordonnancement | ✅ après les actions natives | — | ✅ après « effacer » |
/// | [listViewBuilder] | — | ✅ remplace le conteneur de lignes | — | — |
/// | [captionBuilder] | — | ✅ remplace l'en-tête | ✅ remplace l'en-tête | — |
/// | [itemTransformer] | — | ✅ résumé + seams de rendu | ✅ libellé de puce | — |
/// | [itemFieldsResolver] | — | — | — | ✅ sous-champs rendus |
/// | [subSchemaResolver] | ✅ sous-schéma rendu | ✅ sous-schéma du formulaire d'item | ✅ sous-schéma du formulaire d'item | — |
/// | [creationTemplatesResolver] | — | ✅ menu d'ajout | ✅ menu d'ajout | — |
/// | [itemMenuOptions] | — | ✅ menu de débordement de ligne | — | — |
/// | [onCrud] | — | ✅ create/update/delete + option + gabarit | ✅ create/update/delete + gabarit | — |
///
/// **« — » signifie : le seam est ignoré, silencieusement et sans effet de
/// bord.** Un seam déclaré pour un mode qui ne le sert pas ne dégrade rien et
/// ne lève rien (invariant AD-10) ; il ne fait simplement rien. Les raisons,
/// mode par mode :
///
/// - **`inline`** déballe les sous-champs **éditables** de chaque item. Un
///   rendu libre, un conteneur libre ou une transformation d'affichage y
///   remplaceraient ou désynchroniseraient des champs vivants — donc de l'état
///   et du focus (invariant AD-2). Deux seams y ont malgré tout un sens : les
///   **actions supplémentaires**, qui s'ajoutent à côté des contrôles de la
///   carte sans toucher aux champs ; et le **sous-schéma dérivé**, qui décide
///   *quels* champs sont déballés — le socle réconcilie alors les tranches
///   plutôt que de recréer les contrôleurs, si bien que les champs inchangés
///   gardent leur état et leur focus. Les **gabarits de création**, eux, ne
///   valent pas ici : le mode `inline` ajoute un item **vide** par un bouton,
///   il n'ouvre aucun formulaire à pré-remplir et n'a donc pas de menu d'ajout.
/// - **`tags`** rend une puce, dont le libellé est **du texte** : un rendu
///   libre d'item n'y a pas de place, et le conteneur (`Wrap`) est le rendu
///   même du mode. Le moteur legacy faisait le même choix (son mode tags
///   ignorait `listViewBuilder`). Ce mode ne consulte **pas** l'ACL — il n'en
///   consultait pas avant, et la mettre ici retirerait des gestes à un hôte qui
///   n'a rien demandé.
/// - **`dynamicItem`** n'a ni liste, ni résumé, ni en-tête à habiller
///   (cardinalité ≤ 1, item toujours déballé) : seuls [itemFieldsResolver] et
///   [itemActionsBuilder] y ont un sens. Il n'y a **pas d'item à supprimer ni à
///   créer** (seulement « effacer », qui vide des tranches) : ni les options ni
///   le crochet n'y auraient de geste à arbitrer.
///
/// Deux précisions sur les deux derniers seams, dont l'applicabilité **diffère**
/// l'une de l'autre :
///
/// - **[itemMenuOptions] : `compact` uniquement.** Le mode `tags` rend une puce
///   dont les seules affordances sont « ouvrir » et « retirer » ; y greffer un
///   menu par puce entasserait trois gestes sur une cible de la taille d'un
///   mot. Le mode `inline` déballe des champs vivants : une ligne y est un
///   sous-formulaire, pas un enregistrement résumé sur lequel agir.
/// - **[onCrud] : `compact` ET `tags`.** Ce sont les deux modes qui possèdent un
///   cycle de vie **par item** passant par les dialogues (ajouter, consulter,
///   modifier, supprimer). Le mode `inline` est délibérément **exclu** : il n'a
///   ni création ni édition d'item au sens CRUD — un item y naît vide et se
///   modifie **champ par champ** par le canal granulaire (invariant AD-2), si
///   bien qu'appeler un crochet « update » y reviendrait à l'appeler à chaque
///   frappe ; et son retrait de ligne est une rétractation **structurelle**,
///   non gouvernée par l'ACL (ce mode n'en consulte pas). Câbler le crochet sur
///   ce seul point aurait donné à l'hôte le pouvoir de refuser un retrait sans
///   jamais pouvoir arbitrer une création ni une édition : une asymétrie plus
///   trompeuse qu'un silence assumé.
///
/// ## Défensivité (invariant AD-10)
///
/// Un seam qui **lève** est traité comme un seam **absent** : le rendu natif
/// reprend la main, aucune exception ne remonte, le formulaire reste utilisable.
@immutable
class ZSubListSeams {
  /// Construit un bundle `const` de seams — tous optionnels.
  const ZSubListSeams({
    this.acl,
    this.itemTitleBuilder,
    this.itemBuilder,
    this.itemActionsBuilder,
    this.listViewBuilder,
    this.captionBuilder,
    this.itemTransformer,
    this.itemFieldsResolver,
    this.subSchemaResolver,
    this.creationTemplatesResolver,
    this.itemMenuOptions = const <ZSubItemMenuOption>[],
    this.onCrud,
  });

  /// Surcharge d'**ACL propre à ce champ**, prioritaire sur `ZcrudScope.acl`.
  ///
  /// Priorité effective : paramètre du widget > ce seam > ACL du scope > refus
  /// (`ZDenyAllAcl`). `null` ⇒ chaîne inchangée.
  final ZAcl? acl;

  /// Titre/résumé lisible d'un item (voir [ZSubItemTitleBuilder]).
  final ZSubItemTitleBuilder? itemTitleBuilder;

  /// Rendu libre d'un item (voir [ZSubItemWidgetBuilder]).
  final ZSubItemWidgetBuilder? itemBuilder;

  /// Actions supplémentaires d'un item (voir [ZSubItemActionsBuilder]).
  final ZSubItemActionsBuilder? itemActionsBuilder;

  /// Conteneur libre de la liste (voir [ZSubListViewBuilder]).
  final ZSubListViewBuilder? listViewBuilder;

  /// Habillage libre de l'en-tête (voir [ZSubListCaptionBuilder]).
  final ZSubListCaptionBuilder? captionBuilder;

  /// Transformation d'affichage d'un item (voir [ZSubItemTransformer]).
  final ZSubItemTransformer? itemTransformer;

  /// Sous-champs rendus d'un `dynamicItem` (voir [ZSubItemFieldsResolver]).
  final ZSubItemFieldsResolver? itemFieldsResolver;

  /// **Sous-schéma dérivé de l'état du formulaire parent** — `subItems`
  /// uniquement (voir [ZSubListSchemaResolver]).
  ///
  /// `null` (défaut) ⇒ `ZSubListConfig.itemFields`, à l'identique : aucun
  /// abonnement, aucun appel, aucune allocation.
  ///
  /// **Pourquoi `subItems` et pas `dynamicItem`** : un `dynamicItem` dérive
  /// déjà ses sous-champs de **son propre** état ([itemFieldsResolver]), ce qui
  /// est le besoin qu'il exprime (cardinalité ≤ 1, l'item EST l'état). Aucun
  /// usage hôte mesuré ne dérive le schéma d'un `dynamicItem` du formulaire qui
  /// l'entoure, et le moteur legacy ne le proposait pas non plus
  /// (`subItemsFieldsBuilder` n'existait que sur `subItems`). Déclarer ce seam
  /// sur un `dynamicItem` est donc **sans effet**, silencieusement et sans
  /// dégradation (invariant AD-10).
  final ZSubListSchemaResolver? subSchemaResolver;

  /// **Gabarits de création dérivés de l'état du formulaire parent** —
  /// `subItems`, modes `compact` et `tags` (voir [ZSubListTemplatesResolver]).
  ///
  /// `null` (défaut) ⇒ `ZSubListConfig.creationTemplates`, à l'identique.
  /// Non `null` ⇒ le résultat **remplace** la liste déclarée en config (il ne
  /// s'y ajoute pas) : deux sources de gabarits qui fusionneraient rendraient
  /// impossible de **retirer** un gabarit, or c'est le besoin même (n'offrir
  /// que les transitions autorisées depuis l'état courant).
  final ZSubListTemplatesResolver? creationTemplatesResolver;

  /// **Options de menu par item** (voir [ZSubItemMenuOption]) — mode `compact`.
  ///
  /// Liste **vide** par défaut ⇒ aucun déclencheur de menu n'est rendu, aucune
  /// allocation, aucun appel : la ligne est celle d'avant, au widget près.
  ///
  /// Filtrage, dans cet ordre et jamais dans l'autre :
  /// 1. **ACL** — [ZSubItemMenuOption.effectivePermission] doit être autorisée
  ///    (et l'action ne doit pas écrire si le champ est en lecture seule) ;
  /// 2. **prédicat** — [ZSubItemMenuOption.isVisible] pour CET item.
  ///
  /// Une option ne peut donc **jamais élargir** un droit refusé : le prédicat
  /// n'est même pas consulté quand l'ACL a dit non.
  final List<ZSubItemMenuOption> itemMenuOptions;

  /// **Crochet CRUD** (voir [ZSubItemCrudHook]) — modes `compact` et `tags`.
  ///
  /// `null` ⇒ les chemins natifs (ajouter / modifier / supprimer) sont
  /// **strictement** ceux d'avant : aucun `await` supplémentaire, aucun appel,
  /// aucune bifurcation.
  final ZSubItemCrudHook? onCrud;
}

/// Registre **instanciable** de [ZSubListSeams], discriminés par clé
/// (`String`). Injecté via `ZcrudScope.subListSeamRegistry` (invariant AD-4 —
/// jamais un singleton statique mutable).
///
/// API alignée sur `ZWidgetRegistry` : `register`/`isRegistered`/`keys` +
/// lookup strict ([seamsFor], **throw** si absent — bug de configuration) et
/// défensif ([trySeamsFor], `null` si absent). [resolve] applique la cascade de
/// clés décrite en tête de bibliothèque.
class ZSubListSeamRegistry {
  /// Construit un registre, vide localement, chaîné sur un éventuel [parent]
  /// (lookup en cascade enfant → parent).
  ZSubListSeamRegistry({this.parent});

  /// Registre **parent** consulté quand une clé manque localement (`null` ⇒
  /// racine). La chaîne reflète les enregistrements **ultérieurs** du parent.
  final ZSubListSeamRegistry? parent;

  /// Nom logique du registre (messages d'erreur actionnables).
  static const String _name = 'ZSubListSeamRegistry';

  final Map<String, ZSubListSeams> _seams = <String, ZSubListSeams>{};

  /// Enregistre [seams] sous [key]. Collision **locale** ⇒ **`throw`**
  /// [ZDuplicateRegistrationError] (jamais un « last-wins » silencieux,
  /// invariant AD-3). Redéclarer une clé servie par le [parent] est en revanche
  /// **permis** : c'est l'**ombrage** (enfant > parent), la raison d'être du
  /// chaînage.
  void register(String key, ZSubListSeams seams) {
    if (_seams.containsKey(key)) {
      throw ZDuplicateRegistrationError(kind: key, registryName: _name);
    }
    _seams[key] = seams;
  }

  /// `true` si une entrée est enregistrée pour [key] — localement **ou** dans
  /// la chaîne parent.
  bool isRegistered(String key) =>
      _seams.containsKey(key) || (parent?.isRegistered(key) ?? false);

  /// Les clés actuellement servies : **union** des clés locales et de la chaîne
  /// parent (dédupliquée — une clé ombrée n'apparaît qu'une fois, et c'est
  /// l'entrée **enfant** que le lookup rend).
  Iterable<String> get keys => <String>{..._seams.keys, ...?parent?.keys};

  /// Lookup **strict** : l'entrée de [key] (enfant d'abord, puis chaîne
  /// parent), ou **`throw`** [ZUnregisteredTypeError] si absente partout
  /// (invariant AD-3).
  ZSubListSeams seamsFor(String key) {
    final found = trySeamsFor(key);
    if (found == null) {
      throw ZUnregisteredTypeError(kind: key, registryName: _name);
    }
    return found;
  }

  /// Lookup **défensif** : l'entrée de [key] (**ombrage** enfant > parent), ou
  /// `null` si absente partout (invariant AD-10).
  ZSubListSeams? trySeamsFor(String key) =>
      _seams[key] ?? parent?.trySeamsFor(key);

  /// Résout les seams d'un champ : `field.widgetKind`, puis `field.name`, puis
  /// `field.type.name` — **première entrée trouvée**, aucune fusion entre
  /// niveaux. `null` si aucune (rendu natif inchangé, invariant AD-10).
  ZSubListSeams? resolve(ZFieldSpec field) {
    final kind = field.widgetKind;
    if (kind != null) {
      final byKind = trySeamsFor(kind);
      if (byKind != null) return byKind;
    }
    return trySeamsFor(field.name) ?? trySeamsFor(field.type.name);
  }
}
