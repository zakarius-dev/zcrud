/// Widget de la **famille sous-liste** (`subItems`) : **mini-CRUD
/// imbriqué** (POINT DE VIGILANCE invariant AD-2).
///
/// Édite une `List<Map<String, dynamic>>` d'items : **ajouter**, **supprimer**,
/// **réordonner**. Chaque item est édité par un **sous-formulaire imbriqué** —
/// un `ZFormController` PROPRE à l'item (slice imbriqué) réutilisant le
/// dispatcher `ZFieldWidget`.
///
/// **RÉACTIVITÉ IMBRIQUÉE (invariant AD-2)** — invariants NON-NÉGOCIABLES :
/// - **Le conteneur écoute un canal STRUCTUREL** (add/remove/reorder — géré par
///   `setState` local), **jamais la valeur des sous-champs**. Taper dans un champ
///   d'un item ne reconstruit QUE ce champ (via le `ZFieldListenableBuilder` du
///   `ZFieldWidget` imbriqué) — **PAS** le conteneur, **PAS** les autres items,
///   **PAS** le formulaire racine.
/// - **La tranche parente est agrégée hors de la voie de rebuild** : ce widget
///   est monté par `ZFieldWidget` **AVANT** la souscription à la tranche parente
///   (comme `hidden`/`unsupported`) → écrire la `List` agrégée via `onChanged`
///   (→ `setValue` parent) **ne reconstruit pas** ce conteneur. L'agrégation est
///   déclenchée par un listener sur chaque slice imbriqué (canal de valeur), qui
///   écrit la `List` sans jamais reconstruire le conteneur.
/// - **Place stable par item** : chaque item est enveloppé dans
///   `KeyedSubtree(ValueKey(itemId))` (identité stable) → un réordonnancement ou
///   un retrait **ne vole/ne perd pas** l'état/focus des voisins. Le
///   `ZFormController` d'un item retiré est **`dispose`** (aucune fuite).
/// - **Aucun `setState` de niveau formulaire, aucun `Form`/`FormBuilder`
///   global** : la granularité imbriquée réutilise INTÉGRALEMENT la machinerie
///   du dispatcher + tranches.
///
/// Ce widget est le **champ d'édition imbriqué** (dans un formulaire) ; un
/// **écran de sous-liste autonome** (mini-CRUD plein écran) resterait un
/// composant distinct, non dupliqué ici. Le sous-schéma `const`
/// ([ZSubListConfig.itemFields]) est la brique commune réutilisable.
///
/// a11y/RTL (invariant AD-13) : boutons add/remove/monter/descendre =
/// `IconButton` (cibles ≥ 48 dp) + `Semantics`/tooltips ; insets
/// **directionnels** ; aucune couleur codée en dur (bordure dérivée du
/// `ZcrudTheme` — invariant FR-26).
///
/// **Mode compact — le DÉFAUT** (`ZSubListConfig.displayMode`) : le widget rend
/// une **table de résumé** (une ligne par item, une colonne par valeur de
/// résumé, jamais les sous-champs éditables inline) + un **formulaire d'édition
/// PAR ITEM** (ajouter/consulter/modifier/supprimer), chaque action **filtrée
/// par `ZAcl`**. Dans le formulaire : `ZFormController` PROPRE, `ZFieldWidget`
/// réutilisé, aucun `Form` global.
///
/// Le mode `inline` (sous-formulaires imbriqués empilés) est **strictement
/// préservé** et reste à une ligne de déclaration : il ne partage aucun chemin
/// de code avec le compact (`_buildInline`), il n'y a donc rien à faire diverger.
///
/// **Trois rendus, un seul mode compact** — décidés par mesure, jamais par
/// déclaration :
/// 1. **table** (`Table` à colonnes suivant le contenu, en-têtes solidaires,
///    numériques cadrés en fin) — le cas nominal ; voir `_buildSummaryTable` ;
/// 2. **colonnes de largeur égale** sous une ligne d'en-têtes de même géométrie
///    (`ListView.builder`, lignes construites à la demande) — au-delà du budget
///    de lignes, quand un conteneur ou un rendu de ligne de l'hôte reprend la
///    main ; voir `ZSubListFieldWidget.summaryTableRowBudget` ;
/// 3. **empilement libellé/valeur** — quand la place manque : la table n'est
///    tenue que tant que chaque colonne garde la largeur minimale lisible du
///    thème (marges et actions déduites). En deçà, chaque ligne s'empile et la
///    ligne d'en-têtes disparaît — les deux décisions sortent du même calcul,
///    de sorte qu'un en-tête ne surplombe jamais un empilement. Voir
///    `_summaryIsStacked`.
///
/// `showSummaryHeaders: false` sort de ces trois rendus : c'est le **résumé
/// défilant** historique (cellules de largeur intrinsèque, sans en-tête, sans
/// alignement inter-lignes, sans repli), conservé pour l'hôte qui le déclare.
///
/// ## Seams de présentation — résolus par le CHEMIN NOMINAL
///
/// Titre d'item, rendu libre de ligne, actions supplémentaires, conteneur de
/// liste, habillage d'en-tête, transformation d'affichage et ACL du champ sont
/// déclarés par le **canal** `ZSubListSeamRegistry`, injecté au
/// `ZcrudScope.subListSeamRegistry` et résolu **ici**, dans le widget — pas
/// relayé par le dispatcher.
///
/// C'est une décision, pas une commodité. Ces seams existaient déjà en
/// paramètres (`acl`, `itemTitleBuilder`) mais `ZFieldWidget` ne les
/// transmettait pas : ils n'étaient atteignables qu'en **remplaçant le champ**
/// par un `fieldBuilder`, donc en renonçant à l'agrégation vers la tranche
/// parente, à la granularité (invariant AD-2), aux dialogues, à l'ACL et au
/// soft-delete. Ajouter un paramètre de plus au dispatcher aurait reproduit le
/// défaut au seam suivant — un relais est une liste qu'il faut penser à tenir à
/// jour. Résoudre **au point d'usage** supprime le relais : le chemin nominal
/// (`DynamicEdition`) et la construction directe du widget servent exactement
/// les mêmes seams, et le widget lisait déjà le scope pour son ACL.
///
/// **Priorité** : paramètre du constructeur > seam du registre > défaut natif.
/// Un hôte qui construit le widget à la main garde donc le dernier mot.
///
/// **Rétro-compatibilité stricte** : aucun seam déclaré ⇒ **aucun** widget
/// supplémentaire, aucune structure modifiée, aucun appel supplémentaire. Voir
/// `ZSubListSeams` pour l'applicabilité mode par mode.
///
/// ## Options d'item et arbitrage des mutations
///
/// Deux seams du même canal donnent un **geste** à l'hôte, et se répartissent
/// les rôles sans se recouvrir :
///
/// - `itemMenuOptions` ([ZSubItemMenuOption]) — entrées **déclaratives** par
///   item, rendues dans un menu de débordement en fin de ligne (`compact`),
///   **après** les actions natives et **après** `itemActionsBuilder`. Trois
///   canaux d'affordance coexistent donc, et c'est délibéré : les actions
///   natives sont gouvernées par l'ACL du socle ; `itemActionsBuilder` livre des
///   widgets **opaques** que le socle ne peut ni lire ni filtrer ; les options,
///   elles, sont des **déclarations** que le socle filtre lui-même — ACL
///   d'abord, prédicat de l'hôte ensuite. Une option ne peut donc jamais élargir
///   un droit refusé, ce qu'un `itemActionsBuilder` pourrait faire (et ce
///   pourquoi il reste, lui, sous la responsabilité de l'hôte).
/// - `onCrud` ([ZSubItemCrudHook]) — arbitre **avant** toute écriture
///   (`create`/`update`/`delete` natifs **et** option choisie) : refuser,
///   transformer, laisser passer. Un crochet qui lève **refuse** et son erreur
///   est signalée à `FlutterError.reportError` (jamais avalée, jamais fatale au
///   rendu — invariant AD-10).
///
/// ## Lignes d'un document : ce que le socle rend, et ce qu'il applique
///
/// Trois mécaniques servent le cas master-detail réel — un document dont les
/// lignes alimentent des champs calculés du parent :
///
/// - **colonnes de résumé déclarées** (`ZSubListConfig.summaryColumns`) : une
///   colonne peut désigner une valeur **hors sous-schéma** (un montant calculé,
///   déposé dans l'item par le crochet). Elle s'affiche **sans** rendre le champ
///   saisissable — le formulaire d'item ne monte que les `itemFields`. Elle
///   porte sa mise en forme (décimales, suffixe l10n) et son libellé d'en-tête ;
/// - **motif de véto** ([ZSubItemCrudOutcome.reasonKey]) : le socle le résout
///   par le canal l10n et le rend lui-même (annonce a11y + `SnackBar`) — le
///   crochet ne reçoit **jamais** de `BuildContext`, qu'il emploierait après un
///   `await` ;
/// - **correctif de parent** ([ZSubItemCrudOutcome.parentPatch]) : le crochet
///   **décrit** les tranches parentes à écrire, le socle les applique **une
///   fois**, après l'agrégation, par le canal granulaire (invariant AD-2). La
///   tranche du champ lui-même est ignorée : elle appartient à l'agrégation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;

import '../../../domain/edition/edition_field_type.dart';
import '../../../domain/edition/z_condition_evaluator.dart' show ZValueOf;
import '../../../domain/edition/z_field_config.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../../domain/edition/z_sub_list_config.dart';
import '../../../domain/ports/z_acl.dart';
import '../../l10n/z_localizations.dart';
import '../../theme/z_theme.dart';
import '../../z_form_controller.dart';
import '../../zcrud_scope.dart';
import '../z_field_widget.dart';
import '../z_read_mode_scope.dart';
import '../z_read_only_value.dart';
import '../z_select_choices_resolver.dart';
import '../z_sub_list_seams.dart';
import '../z_value_emptiness.dart';

/// Seam (usage de test) : construit le widget d'édition d'un **sous-champ**
/// d'item, avec le contexte de l'item (`itemId`) pour instrumenter les compteurs
/// de rebuild imbriqués (preuve de granularité, invariant AD-2). À défaut :
/// dispatcher `ZFieldWidget`. Le type est public ; le **paramètre** qui le
/// porte est `@visibleForTesting` (production : toujours `null`).
typedef ZSubItemFieldBuilder = Widget Function(
  BuildContext context,
  ZFormController itemController,
  ZFieldSpec field,
  String itemId,
);

/// Champ d'édition d'une **sous-liste** d'items (`List<Map>` en tranche parente).
class ZSubListFieldWidget extends StatefulWidget {
  /// Construit le champ sous-liste pour [field], valeur initiale [initialValue]
  /// (`List<Map>` ou `null`), agrégeant vers la tranche parente via [onChanged].
  ///
  /// [acl] filtre les actions du mode compact. `null` (défaut) ⇒ le seam `acl`
  /// du registre (`ZcrudScope.subListSeamRegistry`) est consulté, puis l'ACL du
  /// `ZcrudScope` ambiant ; sans scope, le repli est **refusant**
  /// (`ZDenyAllAcl`) : aucune action d'item n'est offerte. [collectionId] est
  /// transmis à `ZAcl.can(..., collectionId:)` ;
  /// [itemTitleBuilder] dérive le titre du dialog / résumé de ligne — `null`
  /// (défaut) ⇒ le seam `itemTitleBuilder` du registre est consulté. Ces deux
  /// paramètres sont **ignorés** en mode `inline` (comportement inchangé) ;
  /// `itemTitleBuilder` vaut en revanche aussi en mode `tags`.
  ///
  /// Priorité, pour l'un comme pour l'autre : **paramètre > registre > défaut**.
  /// Les autres seams (rendu libre, actions supplémentaires, conteneur,
  /// en-tête, transformation d'affichage) n'ont **pas** de paramètre : ils se
  /// déclarent uniquement par le registre — un canal, pas vingt paramètres.
  const ZSubListFieldWidget({
    required this.field,
    required this.initialValue,
    required this.onChanged,
    this.itemFieldBuilder,
    this.acl,
    this.collectionId,
    this.itemTitleBuilder,
    this.parentController,
    super.key,
  });

  /// Spécification `const` du champ rendu (`config` = [ZSubListConfig]).
  final ZFieldSpec field;

  /// Valeur INITIALE de la tranche parente (`List<Map>` ou `null`) — lue **une
  /// fois** pour amorcer les sous-contrôleurs. La suite est gouvernée par l'état
  /// imbriqué (le conteneur ne re-souscrit PAS à la tranche parente).
  final Object? initialValue;

  /// Notifié avec la `List<Map<String, dynamic>>` agrégée à chaque mutation
  /// (structurelle OU valeur d'un sous-champ) — branché sur `setValue` parent.
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  /// Seam de test (voir [ZSubItemFieldBuilder]) ; `null` en production.
  @visibleForTesting
  final ZSubItemFieldBuilder? itemFieldBuilder;

  /// Port d'autorisation consommé **uniquement** en mode compact pour
  /// filtrer add/view/edit/delete.
  ///
  /// `null` (défaut) ⇒ ACL du `ZcrudScope` ambiant, puis repli **refusant**
  /// (`ZDenyAllAcl`). En développement, l'ouverture totale se déclare :
  /// `ZcrudScope(acl: const ZAllowAllAcl())`.
  final ZAcl? acl;

  /// Discriminant de collection transmis à [ZAcl.can]. `null` par défaut.
  final String? collectionId;

  /// Seam de titre d'item, mode compact. `null` → titre dérivé des
  /// `summaryFields`/champs + libellé du champ.
  final ZSubItemTitleBuilder? itemTitleBuilder;

  /// Contrôleur du formulaire **PARENT**, transmis par `ZFieldWidget` sur le
  /// chemin nominal — **en LECTURE seule**.
  ///
  /// Il ne sert qu'aux deux résolveurs dérivés du canal de seams
  /// ([ZSubListSeams.subSchemaResolver],
  /// [ZSubListSeams.creationTemplatesResolver]) : lire la valeur d'une tranche
  /// parente et **s'abonner** aux seules tranches que le résolveur a réellement
  /// lues (invariant AD-2). Ce widget n'y **écrit jamais** — l'agrégation vers
  /// la tranche parente passe, comme avant, par [onChanged] et par lui seul.
  ///
  /// Ce n'est pas un seam relayé (la classe de défaut que le canal a supprimée)
  /// mais une **capacité structurelle**, au même titre que [collectionId] : un
  /// résolveur ne peut pas aller chercher le formulaire parent tout seul, et
  /// aucun `InheritedWidget` ne publie le contrôleur d'édition.
  ///
  /// `null` (construction directe du widget, hors formulaire) ⇒ les deux
  /// résolveurs sont **inertes** et le socle retombe sur la config déclarée
  /// (invariant AD-10).
  final ZFormController? parentController;

  /// **Budget de lignes** de la table de résumé (mode `compact` tabulaire) :
  /// au-delà, le socle retombe sur un rendu **construit à la demande**.
  ///
  /// ## Pourquoi un budget, et pourquoi il est explicite
  ///
  /// Une table ne se **virtualise pas** : dimensionner une colonne sur son
  /// contenu oblige à mesurer la largeur intrinsèque de **toutes** ses cellules,
  /// donc à construire et à mesurer chaque ligne à chaque mise en page. C'est le
  /// prix de l'alignement, et il est linéaire en nombre de lignes.
  ///
  /// Ce prix est parfaitement tenable sur ce à quoi une sous-liste **sert** :
  /// les lignes d'un document, d'un bordereau, d'un procès-verbal — des
  /// dizaines de lignes. Il ne l'est pas sur des milliers. Plutôt que de laisser
  /// ce point implicite (et de le découvrir sur l'appareil d'un utilisateur), le
  /// socle **choisit** : au-delà de ce nombre de lignes, il rend la sous-liste
  /// par un `ListView.builder` (lignes construites à la demande, colonnes de
  /// largeur **égale** sous une ligne d'en-têtes de même géométrie).
  ///
  /// **La bascule est observable**, et c'est délibéré : `find.byType(Table)`
  /// répond `findsOneWidget` à [summaryTableRowBudget] lignes et `findsNothing`
  /// à [summaryTableRowBudget] + 1. Un seuil qu'on ne peut pas mesurer des deux
  /// côtés n'est pas un seuil, c'est une intention.
  ///
  /// **Au-delà du budget, une sous-liste n'est plus une sous-liste** : une liste
  /// de cette taille demande un tri, une pagination, une virtualisation — le
  /// moteur de `zcrud_list` (invariant AD-8), pas une mise en page de
  /// formulaire. Le repli est un **filet de sécurité**, pas une invitation.
  static const int summaryTableRowBudget = 60;

  @override
  State<ZSubListFieldWidget> createState() => _ZSubListFieldWidgetState();
}

/// Item imbriqué : identité **stable** ([id]) + sous-contrôleur imbriqué.
class _SubItem {
  _SubItem(this.id, this.controller, {this.unmapped = const <String, dynamic>{}});

  final String id;
  final ZFormController controller;

  /// **Clés de la GRAINE que le sous-schéma ne gère pas.**
  ///
  /// Le sous-formulaire d'un item n'alloue une tranche que pour les `itemFields`
  /// déclarés. Sans ce résidu, l'item réémis serait RECOMPOSÉ à partir de ces
  /// seuls champs et toute autre clé portée par la graine — `id` en premier —
  /// **disparaîtrait dès la première frappe** dans n'importe quel sous-champ.
  /// Ce ne serait pas un affichage faux : la donnée serait détruite (un
  /// identifiant technique ou une clé annexe non déclarée au sous-schéma).
  ///
  /// **Pourquoi ce point de conservation, et pas un autre :**
  /// - il est porté par l'**item lui-même**, donc l'appariement graine ↔ item est
  ///   fait par **IDENTITÉ**, jamais par index. Un `_move`/`_removeAt`/
  ///   soft-delete transporte le résidu avec son item : il est structurellement
  ///   impossible de recoller la graine d'un item sur un autre — ce qui serait
  ///   **pire** que la perte d'origine ;
  /// - il ne contient **JAMAIS** une clé déclarée (filtrée à la construction),
  ///   et il est fusionné **AVANT** les tranches dans `_syncToParent` : un champ
  ///   que l'utilisateur **efface** reste effacé, il ne ressuscite pas depuis la
  ///   graine ;
  /// - il n'est peuplé que depuis la graine du parent (`initState`) **ou** par
  ///   une donnée de remplacement rendue par le crochet CRUD de l'hôte
  ///   (`ZSubItemCrudOutcome.replace`) — qui est, elle aussi, une graine venue
  ///   de l'extérieur, et le seul moyen pour un hôte d'attribuer un `id` que le
  ///   sous-schéma ne déclare pas. Un item **ajouté** sans crochet n'a pas de
  ///   graine : son résidu reste vide et son comportement est inchangé.
  ///
  /// **Non `final`** pour cette seule raison : un remplacement issu du crochet
  /// **fusionne** dans le résidu (`{...ancien, ...nouveau}`), il ne l'écrase
  /// pas — sans quoi un crochet qui ne renvoie qu'un sous-ensemble détruirait
  /// l'identifiant qu'il vient de poser.
  Map<String, dynamic> unmapped;

  /// Soft-delete : `true` ⇒ item **marqué supprimé** (exclu de l'agrégation
  /// parent) mais conservé pour **restauration** en session.
  bool deleted = false;
}

class _ZSubListFieldWidgetState extends State<ZSubListFieldWidget> {
  /// Items imbriqués (source de vérité en édition ; agrégés vers le parent).
  final List<_SubItem> _items = <_SubItem>[];

  /// Compteur monotone d'identités d'items (clés stables, jamais réutilisées).
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    for (final data in _readList(widget.initialValue)) {
      // SEUL point d'entrée d'une GRAINE (données du parent) → seul point où
      // un résidu hors schéma est capturé (cf. `_SubItem.unmapped`).
      _items.add(_makeItem(data, preserveUnmapped: true));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Les seams vivent dans un `InheritedWidget` : ils ne sont PAS lisibles en
    // `initState`. C'est ici — et seulement ici — que les résolveurs dérivés
    // sont installés, et ré-installés si le registre injecté change.
    _installParentSubscription();
    final resolved = _resolveSchema();
    if (resolved != null && !_sameFields(resolved, _itemFields)) {
      _applySchema(resolved);
    }
  }

  @override
  void dispose() {
    _dropParentSubscription();
    for (final item in _items) {
      _detach(item);
      item.controller.dispose();
    }
    super.dispose();
  }

  // ── Sous-schéma et gabarits DÉRIVÉS de l'état du formulaire parent ─────────

  /// Sous-schéma **résolu** par [ZSubListSeams.subSchemaResolver], ou `null`
  /// quand aucun résolveur n'est déclaré (⇒ `config.itemFields`, à l'identique).
  List<ZFieldSpec>? _derivedItemFields;

  /// Tranches parentes auxquelles ce champ est abonné — l'**union** des noms
  /// que les deux résolveurs ont lus lors de l'appel traçant. Jamais toutes les
  /// tranches du parent : c'est là que se joue l'invariant AD-2.
  final Map<String, VoidCallback> _parentSubs = <String, VoidCallback>{};

  /// Exécute [run] en **traçant** les noms de tranches parentes lues.
  ///
  /// Le lecteur passé au résolveur est un [ZValueOf] pur : il **lit**, il
  /// n'écrit pas. Le contrôleur parent lui-même n'est jamais exposé à l'hôte —
  /// un seam de présentation ne prend pas la main sur le formulaire qui le
  /// contient.
  T? _traced<T>(T Function(ZValueOf parent) run, Set<String>? trace) {
    final parent = widget.parentController;
    if (parent == null) return null;
    Object? read(String name) {
      trace?.add(name);
      return parent.valueOf(name);
    }

    // Invariant AD-10 : un résolveur qui lève est traité comme absent, et les
    // noms déjà lus AVANT l'erreur restent abonnés (même règle que
    // `choicesResolver` dans `ZFieldWidget`) — sinon une branche qui échoue une
    // fois figerait le champ sur un schéma mort.
    return _safe(() => run(read));
  }

  /// Sous-schéma dérivé, ou `null` (aucun résolveur / pas de parent / résolveur
  /// en erreur).
  List<ZFieldSpec>? _resolveSchema({Set<String>? trace}) {
    final resolver = _seams?.subSchemaResolver;
    if (resolver == null) return null;
    return _traced<List<ZFieldSpec>>(resolver, trace);
  }

  /// Gabarits dérivés, ou `null` (aucun résolveur / pas de parent / résolveur
  /// en erreur ⇒ `config.creationTemplates`).
  List<ZSubListItemTemplate>? _resolveTemplates({Set<String>? trace}) {
    final resolver = _seams?.creationTemplatesResolver;
    if (resolver == null) return null;
    return _traced<List<ZSubListItemTemplate>>(resolver, trace);
  }

  /// Installe l'abonnement **ciblé** aux tranches parentes lues par les
  /// résolveurs — appel traçant, puis une souscription par nom lu.
  ///
  /// 🔴 **La tranche du champ lui-même est EXCLUE**, même si un résolveur la
  /// lit (et il en a le droit : elle porte la liste d'items agrégée). S'y
  /// abonner ferait re-résoudre le schéma à chaque `_syncToParent`, donc à
  /// chaque frappe dans un sous-champ — exactement le rafraîchissement global
  /// que ce canal existe pour éviter.
  void _installParentSubscription() {
    final parent = widget.parentController;
    final wanted = <String>{};
    if (parent != null &&
        (_seams?.subSchemaResolver != null ||
            _seams?.creationTemplatesResolver != null)) {
      _resolveSchema(trace: wanted);
      _resolveTemplates(trace: wanted);
      wanted.remove(widget.field.name);
    }
    if (wanted.length == _parentSubs.length &&
        wanted.every(_parentSubs.containsKey)) {
      return; // Jeu d'abonnements inchangé — rien à défaire ni à refaire.
    }
    _dropParentSubscription();
    if (parent == null) return;
    for (final name in wanted) {
      void listener() => _onParentChanged();
      parent.fieldListenable(name).addListener(listener);
      _parentSubs[name] = listener;
    }
  }

  void _dropParentSubscription() {
    final parent = widget.parentController;
    if (parent != null) {
      _parentSubs.forEach((name, listener) {
        parent.fieldListenable(name).removeListener(listener);
      });
    }
    _parentSubs.clear();
  }

  /// Une tranche parente **suivie** a changé : re-résoudre, et ne reconstruire
  /// que si quelque chose a réellement bougé.
  ///
  /// Un `setState` inconditionnel serait tentant et faux : le résolveur peut
  /// lire une tranche dont seule une partie l'intéresse, et rendre le même
  /// schéma. Comparer d'abord garde le compte de reconstructions au plancher
  /// (invariant AD-2) — c'est ce que la garde de granularité assère.
  void _onParentChanged() {
    if (!mounted) return;
    final nextFields = _resolveSchema();
    final schemaChanged =
        nextFields != null && !_sameFields(nextFields, _itemFields);
    final nextTemplates = _resolveTemplates();
    final templatesChanged = nextTemplates != null &&
        !_sameTemplates(nextTemplates, _creationTemplates);
    if (!schemaChanged && !templatesChanged) return;
    if (schemaChanged) _applySchema(nextFields);
    setState(() {});
  }

  /// Applique un nouveau sous-schéma **sans jamais recréer un
  /// `ZFormController`** (invariant AD-2).
  ///
  /// Pour chaque item, la donnée complète est relue **avec l'ancien schéma**,
  /// puis :
  /// - un champ **apparu** reçoit une tranche amorcée de la valeur que l'item
  ///   portait déjà (dans son résidu hors schéma, typiquement) ;
  /// - un champ **disparu** voit sa valeur **descendre dans le résidu** — elle
  ///   n'est pas détruite, elle reste agrégée vers le parent, et elle remonte
  ///   dans une tranche si le champ revient ;
  /// - un champ **inchangé** n'est pas touché du tout : ni `setValue`, ni
  ///   réabonnement, ni réamorçage. Son `TextEditingController`, son focus et
  ///   sa position de curseur survivent — c'est ce que la garde mesure.
  void _applySchema(List<ZFieldSpec> next) {
    final oldFields = _itemFields;
    final oldNames = <String>{for (final f in oldFields) f.name};
    final newNames = <String>{for (final f in next) f.name};
    for (final item in _items) {
      final full = _rawItemData(item);
      _detachFields(item, oldFields);
      item.unmapped = <String, dynamic>{
        for (final entry in full.entries)
          if (!newNames.contains(entry.key)) entry.key: entry.value,
      };
      for (final f in next) {
        if (!oldNames.contains(f.name)) {
          // `setValue` pose la même valeur qu'une tranche déjà à `null` sans
          // notifier (no-op natif de `ValueNotifier`) : aucun réveil parasite.
          item.controller.setValue(f.name, full[f.name]);
        }
      }
    }
    _derivedItemFields = next;
    for (final item in _items) {
      _attachFields(item, next);
    }
    // La donnée agrégée peut avoir changé de FORME (une clé passée de tranche à
    // résidu garde sa valeur, mais l'ordre d'émission suit le nouveau schéma) :
    // republier est la seule façon de ne pas laisser le parent sur une vue
    // périmée. Hors voie de rebuild, comme toute agrégation.
    _syncToParent();
  }

  /// Deux jeux de specs décrivent-ils le **même** sous-schéma ? (`ZFieldSpec`
  /// porte une égalité de valeur : un `label` ou un `readOnly` qui change
  /// compte comme un changement, car il change le rendu.)
  static bool _sameFields(List<ZFieldSpec> a, List<ZFieldSpec> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameTemplates(
    List<ZSubListItemTemplate> a,
    List<ZSubListItemTemplate> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// **Seams de présentation** résolus dans le `ZcrudScope` ambiant pour CE
  /// champ (cascade `widgetKind` → `name` → `type.name`).
  ///
  /// Lu à chaque usage plutôt que mémorisé dans l'état : un registre injecté à
  /// chaud (ou un scope dérivé qui l'ombre) doit être vu immédiatement, et la
  /// lecture d'un `InheritedWidget` déjà consulté pour l'ACL n'ajoute ni
  /// souscription ni allocation. `null` ⇒ rendu natif, inchangé (AD-10).
  ZSubListSeams? get _seams =>
      ZcrudScope.maybeOf(context)?.subListSeamRegistry?.resolve(widget.field);

  /// Sous-schéma **effectif** de l'item : le schéma dérivé du formulaire parent
  /// s'il est résolu ([ZSubListSeams.subSchemaResolver]), sinon le sous-schéma
  /// `const` de la config (vide si config absente/non conforme).
  List<ZFieldSpec> get _itemFields {
    final derived = _derivedItemFields;
    if (derived != null) return derived;
    final config = widget.field.config;
    return config is ZSubListConfig ? config.itemFields : const <ZFieldSpec>[];
  }

  bool get _reorderable {
    final config = widget.field.config;
    return config is ZSubListConfig ? config.reorderable : true;
  }

  /// Mode de rendu — `compact` (défaut) si config absente/non conforme.
  ///
  /// Ce repli suit le défaut de `ZSubListConfig.displayMode` **délibérément**,
  /// et pas par symétrie décorative : le générateur (`@ZcrudModel`) émet un
  /// champ `subItems` **sans aucune config** pour un sous-modèle. Laisser ce
  /// repli sur `inline` ferait donc coexister deux « défauts » contradictoires
  /// — `compact` pour qui écrit une config à la main, `inline` pour qui laisse
  /// le générateur écrire la sienne — et le second est justement le cas où
  /// l'hôte n'a rien choisi.
  ZSubListDisplayMode get _displayMode {
    final config = widget.field.config;
    return config is ZSubListConfig
        ? config.displayMode
        : ZSubListDisplayMode.compact;
  }

  /// **Colonnes de résumé effectives** du mode compact (et du libellé de puce
  /// en mode `tags`) — vide si config absente/non conforme.
  ///
  /// `ZSubListConfig.summaryColumns` **remplace** `summaryFields` quand elle est
  /// déclarée ; sinon chaque `summaryFields` est promu en colonne **nue** (aucun
  /// libellé propre, aucune mise en forme) — donc le rendu d'avant, à
  /// l'identique.
  List<ZSubListSummaryColumn> get _summaryColumns {
    final config = widget.field.config;
    if (config is! ZSubListConfig) return const <ZSubListSummaryColumn>[];
    if (config.summaryColumns.isNotEmpty) return config.summaryColumns;
    return <ZSubListSummaryColumn>[
      for (final name in config.summaryFields) ZSubListSummaryColumn(name: name),
    ];
  }

  /// L'hôte a-t-il **déclaré** ses colonnes (`summaryColumns`) ?
  ///
  /// C'est l'interrupteur de la lecture **hors sous-schéma**, et c'est délibéré.
  /// Un `summaryFields` nommant une clé absente des `itemFields` rend une
  /// cellule vide **depuis toujours** ; se mettre à y afficher le résidu
  /// déplacerait un hôte qui n'a rien demandé. La valeur non éditable ne
  /// s'affiche donc que là où une colonne la **désigne**.
  bool get _hasDeclaredColumns {
    final config = widget.field.config;
    return config is ZSubListConfig && config.summaryColumns.isNotEmpty;
  }

  /// **Rendu tabulaire** du résumé (colonnes alignées + en-têtes) ?
  ///
  /// Défaut `true` (voir `ZSubListConfig.showSummaryHeaders`). `false` ⇒ résumé
  /// **défilant** historique : cellules de largeur intrinsèque, sans en-tête,
  /// sans alignement inter-lignes et sans repli mesuré.
  ///
  /// Une config absente/non conforme suit le défaut : `true`.
  bool get _showSummaryHeaders {
    final config = widget.field.config;
    return config is! ZSubListConfig || config.showSummaryHeaders;
  }

  /// Soft-delete actif ? (défaut `false`, config absente/non conf.)
  bool get _softDelete {
    final config = widget.field.config;
    return config is ZSubListConfig && config.softDelete;
  }

  /// Gabarits de création **effectifs** : ceux dérivés de l'état du formulaire
  /// parent quand [ZSubListSeams.creationTemplatesResolver] est déclaré et
  /// résout, sinon ceux de la config (vide si config absente/non conforme).
  ///
  /// Résolu **à chaque lecture** plutôt que mémorisé : ce n'est qu'une liste de
  /// données `const`, aucune tranche n'en dépend, et un cache aurait une
  /// seconde source de vérité à invalider. Le résolveur n'est appelé que là où
  /// un menu d'ajout est réellement construit (modes `compact`/`tags`).
  List<ZSubListItemTemplate> get _creationTemplates {
    final derived = _resolveTemplates();
    if (derived != null) return derived;
    final config = widget.field.config;
    return config is ZSubListConfig
        ? config.creationTemplates
        : const <ZSubListItemTemplate>[];
  }

  /// Forme de présentation du formulaire d'item (défaut : dialogue).
  ZSubItemFormPresentation get _itemFormPresentation {
    final config = widget.field.config;
    return config is ZSubListConfig
        ? config.itemFormPresentation
        : ZSubItemFormPresentation.dialog;
  }

  /// Valeurs par défaut d'un nouvel item (vide si config absente).
  Map<String, Object?> get _defaultNewItem {
    final config = widget.field.config;
    return config is ZSubListConfig
        ? config.defaultNewItem
        : const <String, Object?>{};
  }

  /// Libellé du bouton de création (repli `addItem`).
  String _addLabel(BuildContext context) {
    final config = widget.field.config;
    final key = config is ZSubListConfig ? config.createNewTextKey : null;
    return label(context, key ?? 'addItem', fallback: label(context, 'addItem'));
  }

  /// Lecture **défensive** de la liste courante (`null`/type inattendu → `[]`).
  List<Map<String, dynamic>> _readList(Object? value) {
    if (value is List) {
      return <Map<String, dynamic>>[
        for (final e in value)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    }
    return const <Map<String, dynamic>>[];
  }

  /// Construit un item. [preserveUnmapped] n'est `true` que pour une **graine**
  /// venue du parent (`initState`) : un item **ajouté** (bouton `+` ou dialog
  /// d'ajout) n'a pas de graine, son résidu reste vide et son comportement est
  /// strictement inchangé.
  _SubItem _makeItem(Map<String, dynamic> data, {bool preserveUnmapped = false}) {
    final id = 'item_${_seq++}';
    final controller = ZFormController(
      initialValues: <String, Object?>{
        for (final f in _itemFields) f.name: data[f.name],
      },
      visibleFields: <String>[for (final f in _itemFields) f.name],
    );
    final item = _SubItem(
      id,
      controller,
      unmapped: preserveUnmapped ? _unmappedOf(data) : const <String, dynamic>{},
    );
    _attach(item);
    return item;
  }

  /// Résidu de [data] : les clés que le sous-schéma **ne déclare pas**. Une clé
  /// déclarée n'y entre JAMAIS — c'est ce qui garantit qu'un champ effacé par
  /// l'utilisateur ne ressuscite pas depuis la graine.
  Map<String, dynamic> _unmappedOf(Map<String, dynamic> data) {
    final known = <String>{for (final f in _itemFields) f.name};
    final rest = <String, dynamic>{
      for (final entry in data.entries)
        if (!known.contains(entry.key)) entry.key: entry.value,
    };
    return rest.isEmpty ? const <String, dynamic>{} : rest;
  }

  /// Attache le listener d'agrégation sur CHAQUE slice imbriqué. Un changement
  /// de valeur d'un sous-champ ne reconstruit PAS le conteneur (non souscrit à
  /// la tranche parente) — il se contente d'agréger vers le parent (invariant
  /// AD-2 préservé).
  void _attach(_SubItem item) => _attachFields(item, _itemFields);

  void _detach(_SubItem item) => _detachFields(item, _itemFields);

  /// Abonnement/désabonnement sur un jeu de champs **explicite** — nécessaire
  /// dès lors que le sous-schéma peut changer : se désabonner du schéma
  /// *courant* après l'avoir remplacé laisserait des listeners orphelins sur
  /// les tranches de l'ancien.
  void _attachFields(_SubItem item, List<ZFieldSpec> fields) {
    for (final f in fields) {
      item.controller.fieldListenable(f.name).addListener(_syncToParent);
    }
  }

  void _detachFields(_SubItem item, List<ZFieldSpec> fields) {
    for (final f in fields) {
      item.controller.fieldListenable(f.name).removeListener(_syncToParent);
    }
  }

  /// Agrège l'état imbriqué en `List<Map>` et écrit la tranche parente. Appelé
  /// depuis un handler d'évènement (listener/bouton), JAMAIS pendant un `build`.
  void _syncToParent() {
    widget.onChanged(<Map<String, dynamic>>[
      // Un item soft-deleted est EXCLU de l'agrégation parent (retiré des
      // données) mais conservé localement pour restauration.
      for (final item in _items)
        if (!item.deleted)
          <String, dynamic>{
            // Le résidu hors schéma de la GRAINE DE CET ITEM (apparié par
            // identité — il voyage avec l'item à travers réordonnancement,
            // retrait et soft-delete) est réémis EN PREMIER : les tranches
            // écrites ensuite priment TOUJOURS, donc un champ déclaré effacé
            // reste effacé (`null`) et ne ressuscite pas.
            ...item.unmapped,
            for (final f in _itemFields) f.name: item.controller.valueOf(f.name),
          },
    ]);
  }

  void _addItem() {
    setState(() {
      // Amorce le nouvel item avec `defaultNewItem` (défensif).
      _items.add(_makeItem(Map<String, dynamic>.from(_defaultNewItem)));
    });
    _syncToParent();
  }

  void _removeAt(int index) {
    final removed = _items[index];
    setState(() {
      _items.removeAt(index);
    });
    _detach(removed);
    removed.controller.dispose();
    _syncToParent();
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
    });
    _syncToParent();
  }

  /// **La lecture seule DESCEND dans les sous-champs.**
  ///
  /// `DynamicEdition._effective` ne force `readOnly: true` que sur les specs de
  /// PREMIER NIVEAU : les `itemFields` ne sont pas parcourus par ce mécanisme.
  /// En mode `inline`, sans ce relais, seuls les boutons du conteneur
  /// seraient gatés — les champs internes resteraient **éditables et
  /// focalisables**. La règle est la MÊME pour les trois modes (le mode
  /// `compact` la couvre dans son dialogue,
  /// `_ZSubItemForm._buildField`).
  ///
  /// Le **mode de présentation**, lui, n'a pas à être relayé : il descend par
  /// le contexte (`ZReadModeScope`). En consultation, les champs internes d'un
  /// item — du texte, un nombre, une date — sont donc rendus en **fiches**,
  /// jamais en cadres de saisie imbriqués dans des cadres.
  Widget _buildItemField(_SubItem item, ZFieldSpec field) {
    final spec = widget.field.readOnly && !field.readOnly
        ? field.copyWith(readOnly: true)
        : field;
    final custom = widget.itemFieldBuilder;
    if (custom != null) return custom(context, item.controller, spec, item.id);
    return ZFieldWidget(controller: item.controller, field: spec);
  }

  @override
  Widget build(BuildContext context) {
    // Dispatch EXPLICITE par mode de rendu, décidé UNE FOIS au build du
    // conteneur (l'édition vit dans le dialog → pas de rebuild par frappe).
    // `switch` exhaustif SANS `default:` : un futur mode casse la
    // compilation → JAMAIS un repli silencieux vers `inline`.
    switch (_displayMode) {
      case ZSubListDisplayMode.compact:
        return _buildCompact(context);
      case ZSubListDisplayMode.tags:
        return _buildTags(context);
      case ZSubListDisplayMode.inline:
        return _buildInline(context);
    }
  }

  /// Rendu **inline** — STRICTEMENT préservé.
  Widget _buildInline(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final removeLabel = label(context, 'removeItem');
    final upLabel = label(context, 'moveItemUp');
    final downLabel = label(context, 'moveItemDown');
    final readOnly = widget.field.readOnly;

    // a11y : le conteneur ne porte PAS `label:` — le `Text` visible
    // ci-dessous fournit déjà le nom accessible de la section. Un `label:`
    // sur le `Semantics(container:)` DOUBLERAIT l'annonce du lecteur d'écran
    // (deux nœuds « Items »). Le `container: true` conserve la frontière
    // sémantique (groupement) sans redoublement.
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Text(
              resolvedLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (var i = 0; i < _items.length; i++)
            KeyedSubtree(
              key: ValueKey<String>(_items[i].id),
              child: _SubItemCard(
                borderColor: theme.fieldBorderColor,
                radius: theme.radiusM,
                index: i,
                count: _items.length,
                reorderable: _reorderable && !readOnly,
                removable: !readOnly,
                removeLabel: removeLabel,
                upLabel: upLabel,
                downLabel: downLabel,
                onRemove: () => _removeAt(i),
                onMoveUp: () => _move(i, -1),
                onMoveDown: () => _move(i, 1),
                // Seul seam servi en `inline` : des actions **en plus** des
                // contrôles de la carte. Les autres seams remplaceraient ou
                // désynchroniseraient des sous-champs vivants (état, focus —
                // invariant AD-2) ; ceux-là s'ajoutent sans y toucher. Le
                // transformateur d'affichage ne vaut pas ici : ce mode affiche
                // la donnée éditée, pas son habillage.
                extraActions:
                    _extraActions(context, _items[i], i, readOnly: readOnly),
                fields: <Widget>[
                  for (final f in _itemFields)
                    KeyedSubtree(
                      key: ValueKey<String>('${_items[i].id}/${f.name}'),
                      child: _buildItemField(_items[i], f),
                    ),
                ],
              ),
            ),
          if (!readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: Text(_addLabel(context)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Mode compact (liste résumé + dialog par item) ──────────────────────────

  /// Représentation textuelle stable d'une valeur (`null`/vide → `''`,
  /// invariant AD-10).
  static String _stringOf(Object? value) => value == null ? '' : '$value';

  /// Sous-spec de [name] dans le sous-schéma `const`, ou `null` si le `name`
  /// déclaré en `summaryFields` ne correspond à aucun `itemField` (invariant
  /// AD-10 : une config incohérente ne fait pas échouer le rendu).
  ZFieldSpec? _specOf(String name) {
    for (final f in _itemFields) {
      if (f.name == name) return f;
    }
    return null;
  }

  /// **Projection d'AFFICHAGE** d'une valeur de résumé.
  ///
  /// Ce n'est **pas** une copie du motif `'$value'` : elle **réutilise**
  /// `zReadOnlyValueOf`, la projection d'affichage déjà en place pour le mode
  /// lecture — donc les MÊMES règles, dans le même canal :
  /// - un `select`/`radio`/`checkbox`/`relation`/`rowChips` rend le **libellé**
  ///   du choix, jamais sa clé technique ;
  /// - une valeur **orpheline** (sélectionnée puis retirée des choix) rend le
  ///   libellé l10n `choiceUnresolved` de `z_orphan_choice.dart` — le même
  ///   libellé et le même canal que les autres voies de rendu, ni
  ///   disparition ni clé brute ;
  /// - une date rend le port `ZDateDisplayFormatter` (chaîne brute sans port).
  ///
  /// Les **choix effectifs** sont résolus par `zResolveSelectChoices` sur le
  /// contrôleur DE L'ITEM : une source `ZChoicesSource` (synchrone), un
  /// `choicesFromKey` ou des options dérivées de l'item sont donc honorés — une
  /// valeur légitime issue d'une source dynamique n'est PAS vue comme orpheline.
  /// La famille `relation` (source = `Stream`) reste hors de portée synchrone :
  /// elle retombe sur `choices` statiques, donc sur le libellé d'orphelin.
  ///
  /// **Valeur vide ⇒ `''` STRICTEMENT** (jamais le placeholder « — » de la fiche
  /// de lecture) : le mettre déplacerait tout hôte passif.
  ///
  /// **Périmètre volontairement BORNÉ** : choix et dates. Les autres familles
  /// gardent `_stringOf` **inchangé** — router tout le résumé dans
  /// `zReadOnlyValueOf` transformerait aussi, sans qu'un hôte l'ait demandé,
  /// `true` en « Oui », `42` en « 42 % », une valeur `password` en « •••• ».
  /// Un hôte passif ne bouge donc QUE là où c'est exigé (libellés de choix)
  /// ou là où il a injecté un port (dates).
  ///
  /// **Transformation d'affichage** ([ZSubListSeams.itemTransformer]) : quand
  /// un [display] est fourni, la valeur brute est lue **dans lui** au lieu de
  /// la tranche. Le reste de la chaîne (choix, orphelin, port de date) est
  /// strictement le même — le transformateur change la valeur, jamais les
  /// règles de sa mise en forme. `display == null` (aucun seam) ⇒ chemin
  /// d'origine, à l'identique.
  ///
  /// Invariant AD-2 : lecture de la seule tranche du sous-champ, aucun objet
  /// coûteux alloué, aucune souscription — la cellule ne reconstruit rien
  /// au-delà d'elle.
  String _displayText(
    BuildContext context,
    _SubItem item,
    String name, [
    Map<String, dynamic>? display,
  ]) {
    final raw =
        display == null ? item.controller.valueOf(name) : display[name];
    if (zIsEmptyValue(raw)) return '';
    final spec = _specOf(name);
    if (spec == null || !_projectedTypes.contains(spec.type)) {
      return _stringOf(raw);
    }
    final cfg = spec.config;
    final rov = zReadOnlyValueOf(
      context,
      spec,
      raw,
      choices: zResolveSelectChoices(
        context,
        item.controller,
        spec,
        cfg is ZSelectConfig ? cfg : null,
      ),
    );
    // `rov.widget` n'a pas de texte : repli brut (aucune famille projetée ici
    // n'en produit — garde-fou AD-10).
    return rov.text ?? _stringOf(raw);
  }

  /// Carte de lecture des **colonnes** d'une ligne, ou `null` ⇒ lecture des
  /// tranches (chemin d'origine, à l'identique).
  ///
  /// Non `null` dans deux cas seulement : un transformateur d'affichage est
  /// déclaré (la carte est son résultat) ou l'hôte a **déclaré ses colonnes**
  /// (la carte est la donnée BRUTE de l'item). Cette seconde carte est la seule
  /// qui porte les valeurs **non éditables** : le résidu hors sous-schéma, où
  /// vivent les montants qu'un crochet CRUD a calculés.
  ///
  /// Les valeurs des champs **déclarés** y sont identiques à celles des
  /// tranches ([_rawItemData] les lit précisément dans les tranches) : router
  /// toutes les cellules par cette carte ne change donc rien pour elles.
  Map<String, dynamic>? _columnData(
    _SubItem item,
    Map<String, dynamic>? display,
  ) =>
      display ?? (_hasDeclaredColumns ? _rawItemData(item) : null);

  /// Texte d'une **colonne de résumé** : la valeur projetée ([_displayText]),
  /// puis la mise en forme **déclarée** par la colonne.
  ///
  /// Une cellule vide reste vide — ni décimales, ni suffixe : un « 0,00 F » ou
  /// un « % » solitaire inventerait une donnée que l'item n'a pas.
  String _columnText(
    BuildContext context,
    _SubItem item,
    ZSubListSummaryColumn column,
    Map<String, dynamic>? data,
  ) {
    final text = _displayText(context, item, column.name, data);
    if (text.isEmpty) return '';
    final Object? raw =
        data == null ? item.controller.valueOf(column.name) : data[column.name];
    return _formatColumn(context, column, raw, text);
  }

  /// Mise en forme **bornée** d'une cellule : décimales fixes (sur un `num`
  /// seulement) puis suffixe l10n, séparé par une espace **insécable** (une
  /// valeur et son unité ne se coupent pas en fin de ligne).
  ///
  /// Une valeur qui n'est pas un `num` traverse `decimals` **inchangée**
  /// (invariant AD-10 : une donnée d'une autre forme s'affiche, elle ne fait
  /// pas échouer la cellule).
  String _formatColumn(
    BuildContext context,
    ZSubListSummaryColumn column,
    Object? raw,
    String text,
  ) {
    var out = text;
    final decimals = column.decimals;
    if (decimals != null && decimals >= 0 && raw is num) {
      out = raw.toStringAsFixed(decimals);
    }
    final suffixKey = column.suffixKey;
    if (suffixKey != null) {
      final suffix = label(
        context,
        suffixKey,
        fallback: column.suffixFallback ?? suffixKey,
      );
      if (suffix.isNotEmpty) out = '$out $suffix';
    }
    return out;
  }

  /// Libellé d'en-tête d'une colonne : sa **clé l10n** déclarée si elle en a
  /// une, sinon le `label` de l'`itemField` de même nom, sinon le nom.
  ///
  /// L'ordre importe : une colonne **calculée** n'a pas de `ZFieldSpec` d'où
  /// tirer un libellé — sans sa clé, l'en-tête afficherait un nom technique.
  String _columnLabel(BuildContext context, ZSubListSummaryColumn column) {
    final key = column.labelKey;
    if (key != null) {
      return label(context, key, fallback: column.labelFallback ?? key);
    }
    final spec = _specOf(column.name);
    return label(
      context,
      spec?.label ?? column.name,
      fallback: spec?.label ?? column.name,
    );
  }

  /// Une colonne de résumé porte-t-elle une valeur **numérique** ?
  ///
  /// C'est la seule question qui gouverne le **cadrage de fin** d'une cellule,
  /// et elle se répond sur des **déclarations**, jamais sur la donnée : lire la
  /// valeur d'une ligne pour décider de l'alignement d'une **colonne** ferait
  /// dépendre la géométrie du contenu, et une colonne dont la première ligne
  /// est vide s'alignerait autrement que la même colonne remplie.
  ///
  /// Deux sources, dans cet ordre :
  /// 1. `ZSubListSummaryColumn.decimals` — une colonne qui fixe ses décimales
  ///    se déclare numérique. C'est le **seul** signal disponible pour une
  ///    colonne **calculée** (hors sous-schéma) : elle n'a pas de `ZFieldSpec`.
  /// 2. le **type déclaré** de l'`itemField` de même nom (`number`, `integer`,
  ///    `float`).
  ///
  /// Pourquoi ces trois types et pas davantage : `rating`, `slider` ou `stepper`
  /// portent bien un nombre, mais leur résumé se lit comme une **appréciation**,
  /// pas comme une grandeur à comparer en colonne. Cadrer un montant en fin sert
  /// à aligner les unités entre lignes ; cadrer une note de 1 à 5 n'aligne rien.
  bool _isNumericColumn(ZSubListSummaryColumn column) {
    if (column.decimals != null) return true;
    final spec = _specOf(column.name);
    if (spec == null) return false;
    return spec.type == EditionFieldType.number ||
        spec.type == EditionFieldType.integer ||
        spec.type == EditionFieldType.float;
  }

  /// Cadrage **directionnel** d'une colonne (invariant AD-13) : fin pour une
  /// colonne numérique, début sinon. Jamais `left`/`right`.
  TextAlign _columnAlign(ZSubListSummaryColumn column) =>
      _isNumericColumn(column) ? TextAlign.end : TextAlign.start;

  /// Familles dont le résumé est **projeté** : les familles à choix (libellé
  /// au lieu de la clé) et les familles de date (port d'affichage). Toute
  /// autre famille conserve son rendu brut d'origine.
  static const Set<EditionFieldType> _projectedTypes = <EditionFieldType>{
    EditionFieldType.select,
    EditionFieldType.radio,
    EditionFieldType.checkbox,
    EditionFieldType.relation,
    EditionFieldType.rowChips,
    EditionFieldType.dateTime,
    EditionFieldType.time,
  };

  /// Snapshot `Map` des valeurs courantes d'un item (lecture des tranches).
  Map<String, dynamic> _itemData(_SubItem item) => <String, dynamic>{
        for (final f in _itemFields) f.name: item.controller.valueOf(f.name),
      };

  /// Snapshot **complet** d'un item, tel qu'il serait agrégé vers le parent :
  /// le résidu hors sous-schéma de la graine **d'abord** (donc `id` et toute
  /// clé annexe non déclarée), les tranches ensuite — dans le MÊME ordre que
  /// `_syncToParent`, de sorte qu'un champ déclaré effacé reste effacé.
  ///
  /// C'est la donnée **BRUTE** servie aux seams de présentation : un titre ou
  /// une transformation d'affichage ont besoin de l'identifiant technique, que
  /// le sous-schéma ne déclare presque jamais.
  Map<String, dynamic> _rawItemData(_SubItem item) => <String, dynamic>{
        ...item.unmapped,
        for (final f in _itemFields) f.name: item.controller.valueOf(f.name),
      };

  /// Invoque un seam hôte **défensivement** (invariant AD-10) : un seam qui
  /// lève est traité comme un seam **absent** — `null`, donc repli sur le rendu
  /// natif. Jamais d'exception remontée au rendu du formulaire.
  static T? _safe<T>(T Function() run) {
    try {
      return run();
    } catch (_) {
      return null;
    }
  }

  /// Applique **défensivement** le seam de titre : paramètre du constructeur
  /// d'abord, seam du registre ensuite (priorité paramètre > registre), puis
  /// `null` ⇒ repli dérivé.
  String? _safeTitle(Map<String, dynamic> data) {
    final builder = widget.itemTitleBuilder ?? _seams?.itemTitleBuilder;
    if (builder == null) return null;
    return _safe(() => builder(data));
  }

  /// Données d'**AFFICHAGE** d'un item : `null` quand aucun transformateur
  /// n'est déclaré — et ce `null` n'est pas une commodité, c'est la garantie de
  /// rétro-compatibilité : sans seam, aucune `Map` n'est allouée et la lecture
  /// reste celle des tranches, à l'identique.
  ///
  /// Le transformateur reçoit la donnée **brute** ([_rawItemData]) et son
  /// résultat ne sert **qu'à l'affichage** : ni l'agrégation parente, ni la
  /// graine des dialogues, ni l'entrée du builder de titre n'en dépendent.
  Map<String, dynamic>? _displayDataOf(_SubItem item) {
    final transformer = _seams?.itemTransformer;
    if (transformer == null) return null;
    return _safe(() => transformer(context, _rawItemData(item)));
  }

  /// Titre de résumé d'une ligne quand aucun `summaryFields` :
  /// `itemTitleBuilder` s'il est fourni, sinon **concaténation lisible** des
  /// valeurs non nulles des `itemFields` (jamais un déballage éditable).
  String _defaultTitle(
    BuildContext context,
    _SubItem item, [
    Map<String, dynamic>? display,
  ]) {
    // Le builder de titre reçoit toujours la donnée BRUTE — jamais la donnée
    // transformée. Un titre se dérive de ce qui EST, pas de son habillage : si
    // les deux venaient de la même source, un transformateur qui masque une
    // valeur masquerait aussi le titre qui sert à retrouver l'item.
    final t = _safeTitle(_rawItemData(item));
    if (t != null && t.isNotEmpty) return t;
    // Seul le repli dérivé est projeté (mêmes règles que `_displayText`) — et
    // c'est LUI, non le builder, qui honore la transformation d'affichage.
    final data = display ?? _itemData(item);
    return <String>[
      for (final f in _itemFields)
        if (data[f.name] != null &&
            _displayText(context, item, f.name, display).isNotEmpty)
          _displayText(context, item, f.name, display),
    ].join(' — ');
  }

  /// Titre du dialog d'édition : `itemTitleBuilder(data)` s'il est fourni
  /// et non vide, sinon le libellé du champ.
  String _dialogTitle(BuildContext context, Map<String, dynamic> data) {
    final t = _safeTitle(data);
    if (t != null && t.isNotEmpty) return t;
    return label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
  }

  /// Contenu résumé d'une ligne (mode compact) : les `summaryFields` en lecture
  /// (défilement horizontal encapsulé) ou le titre dérivé.
  ///
  /// [replie] ne concerne que le mode **en-têtes** : `true` ⇒ la ligne
  /// abandonne ses colonnes pour un **empilement de couples libellé/valeur**
  /// (voir [_stackedSummary]), parce que la place manque pour que des colonnes
  /// disent encore quelque chose. Le calcul de ce basculement appartient à
  /// [_summaryIsStacked] ; la cellule, elle, ne mesure rien.
  Widget _summaryCells(
    BuildContext context,
    _SubItem item, {
    required bool replie,
    Map<String, dynamic>? display,
  }) {
    final summaryColumns = _summaryColumns;
    if (summaryColumns.isNotEmpty) {
      // Carte de lecture des cellules — `null` (aucune colonne déclarée, aucun
      // transformateur) ⇒ lecture des tranches, chemin d'origine.
      final data = _columnData(item, display);
      // Mode EN-TÊTES (opt-in) : colonnes de largeur égale, ellipse, aucun
      // défilement horizontal — sans quoi des cellules de largeur intrinsèque
      // défilant chacune pour son compte ne s'aligneraient jamais sous
      // l'en-tête. Le texte tronqué reste atteignable par consulter/modifier…
      // …tant que les colonnes ont la place d'exister : en deçà, la ligne
      // s'empile (le seul régime où l'ellipse ne cachait plus un détail mais
      // la totalité de l'information).
      if (_showSummaryHeaders && replie) {
        return _stackedSummary(context, item, summaryColumns, data);
      }
      if (_showSummaryHeaders) {
        return Row(
          children: <Widget>[
            for (final column in summaryColumns)
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 16, 0),
                  child: Text(
                    _columnText(context, item, column, data),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: _columnAlign(column),
                  ),
                ),
              ),
          ],
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final column in summaryColumns)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 16, 0),
                child: Text(
                  _columnText(context, item, column, data),
                  textAlign: TextAlign.start,
                ),
              ),
          ],
        ),
      );
    }
    return Text(
      _defaultTitle(context, item, display),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
    );
  }

  /// Résumé **empilé** d'une ligne : un couple libellé/valeur par colonne, le
  /// libellé au-dessus de sa valeur.
  ///
  /// C'est la forme que prend le résumé quand les colonnes n'ont plus la place
  /// d'être lisibles. Le libellé est celui-là même qui coiffait la colonne : il
  /// **descend dans la ligne** au lieu de rester en en-tête, de sorte qu'aucun
  /// en-tête ne surplombe un empilement auquel il ne correspondrait plus. La
  /// valeur, elle, n'est ni limitée en nombre de lignes ni tronquée : elle
  /// revient à la ligne autant qu'il le faut.
  ///
  /// Un couple dont la **valeur est vide** n'est pas rendu : un libellé seul
  /// n'apprend rien et coûterait deux lignes de hauteur là où la place est
  /// justement comptée. Une ligne dont toutes les valeurs sont vides ne rend
  /// donc rien — comme la table alignée, dont les cellules seraient toutes
  /// blanches.
  ///
  /// a11y (invariant AD-13) : chaque couple forme **un** nœud annoncé
  /// « libellé : valeur ». Les deux textes en sont exclus, faute de quoi la
  /// valeur serait annoncée deux fois et le libellé, isolé, passerait pour un
  /// contenu.
  Widget _stackedSummary(
    BuildContext context,
    _SubItem item,
    List<ZSubListSummaryColumn> summaryColumns, [
    Map<String, dynamic>? data,
  ]) {
    final labelStyle = Theme.of(context).textTheme.labelMedium;
    final couples = <Widget>[];
    for (final column in summaryColumns) {
      final value = _columnText(context, item, column, data);
      if (value.isEmpty) continue;
      final resolved = _columnLabel(context, column);
      couples.add(
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            0,
            couples.isEmpty ? 0 : _stackedPairGap,
            0,
            0,
          ),
          child: Semantics(
            container: true,
            label: resolved,
            value: value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ExcludeSemantics(
                  child: Text(
                    resolved,
                    style: labelStyle,
                    textAlign: TextAlign.start,
                  ),
                ),
                ExcludeSemantics(
                  child: Text(value, textAlign: TextAlign.start),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (couples.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        0,
        _stackedPairGap,
        0,
        _stackedPairGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: couples,
      ),
    );
  }

  /// Écart vertical entre deux couples empilés (et marge haute/basse du bloc).
  static const double _stackedPairGap = 8;

  /// Emprise horizontale d'une ligne de résumé **hors colonnes**, actions
  /// exclues : les marges externes de `_CompactRow` (16 de chaque côté) et ses
  /// marges internes (12 au début, 4 à la fin). La ligne d'en-têtes reproduit
  /// exactement la même emprise — c'est ce qui fait tomber les colonnes en face.
  static const double _rowChromeExtent = 16 + 16 + 12 + 4;

  /// Largeur minimale qu'une colonne de résumé doit conserver pour rester
  /// lisible, **gouttière comprise**.
  ///
  /// Elle n'est pas choisie : elle est **déclarée** par le thème
  /// (`subListColumnMinWidth`) ou, à défaut, **dérivée** de `readRowLabelWidth`
  /// (160 par défaut). La dérivation a une raison : une colonne est coiffée par
  /// le libellé de son champ, elle doit donc être au moins aussi large que la
  /// colonne de libellés qu'un champ consulté en ligne se réserve déjà. En deçà,
  /// c'est l'en-tête lui-même qui se tronque.
  double _minColumnWidth(ZcrudTheme tokens) =>
      tokens.subListColumnMinWidth ?? tokens.readRowLabelWidth ?? 160;

  /// Le résumé doit-il s'**empiler** sur une surface de [width] logique ?
  ///
  /// Le seuil n'est pas un nombre : il se calcule à chaque mise en page, à
  /// partir de ce que la ligne doit réellement loger.
  ///
  /// ```text
  /// disponible = largeur − marges de ligne (48) − actions × 48
  /// empilé     ⇔ disponible < nombre de colonnes × largeur minimale de colonne
  /// ```
  ///
  /// Les actions entrent dans le calcul parce qu'elles prennent la largeur aux
  /// colonnes : la même surface peut donc porter une table en consultation
  /// (une seule action) et l'empiler en édition (trois). C'est voulu — dans les
  /// deux cas, ce qui est mesuré est la place qui reste au texte.
  ///
  /// Deux cas ne s'empilent jamais : le résumé **sans** en-têtes (qui défile
  /// horizontalement et ne tronque donc rien) et une largeur non bornée (une
  /// surface qui ne se prononce pas ne peut pas déclencher un repli).
  bool _summaryIsStacked(ZcrudTheme tokens, double width, int actionCount) {
    if (!_showSummaryHeaders || !width.isFinite) return false;
    final columns = _summaryColumns.length;
    if (columns == 0) return false;
    final available = width - _rowChromeExtent - actionCount * _actionExtent;
    return available < columns * _minColumnWidth(tokens);
  }

  /// Ligne d'**en-têtes de colonnes** (opt-in). Reprend le
  /// `label` l10n de chaque `ZFieldSpec` de `summaryFields` (repli : le `name`)
  /// — aucun libellé codé en dur (invariant FR-26). Même géométrie de colonnes
  /// que les cellules (`Expanded` + même padding de fin) : l'alignement est réel.
  ///
  /// a11y (invariant AD-13) : `header: true` sur chaque cellule — l'en-tête
  /// est annoncé comme tel, et la distinction ne repose pas sur le seul
  /// style visuel.
  ///
  /// [actionCount] = nombre d'`IconButton` de fin de ligne (gated ACL) : la
  /// réserve de fin reproduit leur emprise pour que les colonnes tombent
  /// réellement en face. Une ligne **soft-deleted** n'expose qu'une action
  /// (restaurer) + un badge : ses colonnes sont donc décalées de la différence.
  Widget _summaryHeaderRow(BuildContext context, int actionCount) {
    final summaryColumns = _summaryColumns;
    return Padding(
      // Reproduit la géométrie de `_CompactRow` : marge externe 16, marge
      // interne de début 12, réserve de fin = actions + marge interne 4.
      padding: const EdgeInsetsDirectional.fromSTEB(28, 8, 16, 0),
      child: Row(
        children: <Widget>[
          for (final column in summaryColumns)
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 16, 0),
                child: Semantics(
                  // `container: true` est NÉCESSAIRE, pas décoratif : le mode
                  // compact est enveloppé d'un `Semantics(container: true)` qui
                  // FUSIONNE ses descendants — sans nœud propre, le drapeau
                  // `header` remonterait sur le bloc entier, qui serait alors
                  // annoncé comme un titre (mesuré).
                  container: true,
                  header: true,
                  child: Text(
                    _columnLabel(context, column),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: _columnAlign(column),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ),
          SizedBox(width: actionCount * _actionExtent + 4),
        ],
      ),
    );
  }

  /// Emprise horizontale d'une action de fin de ligne (`IconButton` Material,
  /// cible tactile ≥ 48 dp — invariant AD-13). Sert à réserver, sous
  /// l'en-tête, la même largeur que la zone d'actions.
  static const double _actionExtent = 48;

  // ── Table de résumé (mode compact tabulaire) ────────────────────────────────

  /// **Table de résumé** : une `Table` unique portant la ligne d'en-têtes ET
  /// toutes les lignes d'items.
  ///
  /// ## Ce que « vraie table » veut dire ici, et ce que ça exclut
  ///
  /// Trois propriétés, qu'une pile de lignes indépendantes ne peut pas tenir :
  ///
  /// 1. **Largeurs suivant le contenu** — `IntrinsicColumnWidth` : chaque
  ///    colonne se dimensionne sur la plus large de ses cellules, en-tête
  ///    compris. La **première** colonne porte en plus un `flex` : elle absorbe
  ///    la place restante quand la table est plus étroite que la surface, et
  ///    elle cède la première quand elle est plus large. C'est la colonne de
  ///    désignation d'une ligne de document — la seule dont l'élasticité ne
  ///    dérange personne, et celle qu'on veut voir en entier.
  /// 2. **En-têtes solidaires** — l'en-tête n'est pas une ligne qui *reproduit*
  ///    la géométrie des cellules (ce que fait le rendu à colonnes égales, en
  ///    recopiant marges et réserve d'actions) : c'est **la même colonne**, dans
  ///    la même `Table`. Il ne peut donc pas se désaligner : il n'y a rien à
  ///    tenir d'accord.
  /// 3. **Cadrage de fin des valeurs numériques** ([_columnAlign]) — sans lui,
  ///    une colonne de montants ne se lit pas en colonne, et c'est tout l'objet
  ///    d'une table de lignes de document.
  ///
  /// ## Où passe la frontière avec `zcrud_list` (invariant AD-8)
  ///
  /// Ceci est une **mise en page**, pas un moteur de liste. La distinction n'est
  /// pas rhétorique, elle est vérifiable : cette table n'a **ni tri, ni
  /// pagination, ni virtualisation, ni renderer interchangeable, ni source de
  /// données** — elle reçoit les items déjà en mémoire du formulaire qui la
  /// contient, et les dispose. Tout ce qui suppose que la liste est *grande*
  /// (donc tout ce qui la rend paresseuse ou navigable) appartient à
  /// `zcrud_list` et n'entrera jamais ici ; c'est aussi ce qui justifie le
  /// budget de lignes ([ZSubListFieldWidget.summaryTableRowBudget]) plutôt
  /// qu'une virtualisation maison. `zcrud_core` ne dépend d'aucun paquet zcrud
  /// (invariant AD-1) : la table est bâtie sur les seules primitives Flutter.
  ///
  /// a11y (invariant AD-13) : chaque en-tête est un nœud `header` ; chaque
  /// cellule est annoncée « libellé : valeur » (le libellé vit dans l'en-tête,
  /// hors de portée d'un lecteur d'écran qui parcourt les lignes). Les actions
  /// gardent leur cible de 48 dp, et aucun `left`/`right` n'apparaît : les
  /// bordures verticales de la table sont **symétriques**, donc invariantes par
  /// renversement.
  Widget _buildSummaryTable(
    BuildContext context, {
    required ZcrudTheme theme,
    required int actionCount,
    required bool canView,
    required bool canUpdate,
    required bool canDelete,
    required List<List<Widget>>? extras,
    required List<List<ZSubItemMenuOption>>? optionsPerItem,
  }) {
    final columns = _summaryColumns;
    final borderColor = theme.fieldBorderColor;
    final labelStyle = Theme.of(context).textTheme.labelMedium;
    // Une ligne soft-deleted porte TOUJOURS son action « restaurer » (elle
    // n'est pas gatée : sans elle, la ligne serait un cul-de-sac). La colonne
    // d'actions doit donc exister même quand l'ACL n'accorde rien.
    final anyDeleted = _items.any((item) => item.deleted);
    final hasActions = actionCount > 0 || anyDeleted;
    final actionsIndex = columns.length;

    Widget cell(Widget child, {required bool last}) => Padding(
          padding: EdgeInsetsDirectional.fromSTEB(12, 8, last ? 12 : 16, 8),
          child: child,
        );

    final headerRow = TableRow(
      decoration: borderColor == null
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
      children: <Widget>[
        for (var c = 0; c < columns.length; c++)
          cell(
            Semantics(
              // Même raison qu'en v1.4.1 : le bloc compact est enveloppé d'un
              // `Semantics(container: true)` ; sans nœud propre, le drapeau
              // `header` remonterait sur le bloc entier.
              container: true,
              header: true,
              child: Text(
                _columnLabel(context, columns[c]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: _columnAlign(columns[c]),
                style: labelStyle,
              ),
            ),
            last: !hasActions && c == columns.length - 1,
          ),
        if (hasActions) const SizedBox.shrink(),
      ],
    );

    final rows = <TableRow>[headerRow];
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final display = _displayDataOf(item);
      final data = _columnData(item, display);
      final last = i == _items.length - 1;
      rows.add(
        TableRow(
          // Identité **stable** par item (invariant AD-2) : un retrait ou un
          // réordonnancement ne vole pas l'état de ses voisines.
          key: ValueKey<String>('subListRow_${item.id}'),
          decoration: borderColor == null || last
              ? null
              : BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
          children: <Widget>[
            for (var c = 0; c < columns.length; c++)
              cell(
                _tableCell(context, item, columns[c], data),
                last: !hasActions && c == columns.length - 1,
              ),
            if (hasActions)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (item.deleted)
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                      child: Text(
                        label(context, 'deletedItemBadge'),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.start,
                      ),
                    ),
                  _RowActions(
                    deleted: item.deleted,
                    canView: canView,
                    canUpdate: canUpdate,
                    canDelete: canDelete,
                    viewLabel: label(context, 'viewItem'),
                    editLabel: label(context, 'editItem'),
                    deleteLabel: label(context, 'deleteItem'),
                    restoreLabel: label(context, 'restoreItem'),
                    onView: () => _openViewDialog(item),
                    onEdit: () => _openEditDialog(item),
                    onDelete: () => _confirmDelete(item),
                    onRestore: () => _restore(item),
                    extraActions: extras == null || i >= extras.length
                        ? const <Widget>[]
                        : extras[i],
                    menu: optionsPerItem == null ||
                            i >= optionsPerItem.length ||
                            optionsPerItem[i].isEmpty
                        ? null
                        : _buildItemMenu(context, item, optionsPerItem[i]),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      child: Table(
        // La première colonne absorbe le jeu (surplus ET déficit) ; les autres
        // sont dimensionnées par leur contenu.
        columnWidths: <int, TableColumnWidth>{
          0: const IntrinsicColumnWidth(flex: 1),
          if (hasActions) actionsIndex: const IntrinsicColumnWidth(),
        },
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: borderColor == null
            ? null
            : TableBorder(
                top: BorderSide(color: borderColor),
                bottom: BorderSide(color: borderColor),
                // Bordures verticales **symétriques** : invariantes par
                // renversement, donc sans variante directionnelle à tenir.
                left: BorderSide(color: borderColor),
                right: BorderSide(color: borderColor),
                borderRadius: BorderRadius.all(theme.radiusM),
              ),
        children: rows,
      ),
    );
  }

  /// Cellule de valeur d'une ligne de table : le texte projeté de la colonne,
  /// cadré selon la nature de la colonne, barré si l'item est soft-deleted.
  ///
  /// a11y : le couple est annoncé « libellé : valeur ». Le `Text` en est exclu,
  /// faute de quoi la valeur serait annoncée deux fois — même règle que le
  /// résumé empilé, pour la même raison.
  Widget _tableCell(
    BuildContext context,
    _SubItem item,
    ZSubListSummaryColumn column,
    Map<String, dynamic>? data,
  ) {
    final value = _columnText(context, item, column, data);
    Widget text = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: _columnAlign(column),
    );
    if (item.deleted) {
      text = DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.lineThrough),
        child: text,
      );
    }
    return Semantics(
      container: true,
      label: _columnLabel(context, column),
      value: value,
      child: ExcludeSemantics(child: text),
    );
  }

  /// Ouvre le **formulaire d'édition** d'un item, sous la forme déclarée
  /// (`ZSubListConfig.itemFormPresentation` : dialogue, feuille ou page).
  /// `initial` amorce le `ZFormController` propre du formulaire ; retourne le
  /// `Map` agrégé à la validation, `null` à l'annulation/consultation.
  ///
  /// ## Les trois formes rendent la MÊME donnée
  ///
  /// Ce n'est pas une convention à tenir mais une propriété de structure : les
  /// trois formes montent **le même** `_ZSubItemForm`, avec les **mêmes**
  /// `itemFields` et la **même** graine ; seule l'enveloppe diffère, et la
  /// `Map` rendue est construite par un unique `_save`. Il n'existe pas de
  /// second chemin de sortie de données à faire diverger.
  ///
  /// ## Défensivité (invariant AD-10)
  ///
  /// Les trois formes ont besoin d'un `Navigator`. Sans lui, aucune n'est
  /// montable : le socle **n'ouvre rien**, **ne lève pas**, et signale
  /// l'incident à `FlutterError.reportError` — le formulaire parent reste
  /// utilisable, et l'erreur n'est pas avalée pour autant. Une forme qui
  /// échoue à s'ouvrir pour une autre raison **retombe sur le dialogue**, la
  /// seule forme dont ce socle garantit le montage depuis toujours.
  Future<Map<String, dynamic>?> _showItemForm(
    Map<String, dynamic> initial, {
    required bool readOnly,
  }) async {
    // Forme héritée de la surface, relevée ICI (sous le scope) : la route du
    // formulaire naîtra hors de cet arbre et ne l'hériterait pas.
    final formeHeritee = ZReadModeScope.maybeOf(context)?.layout;
    final presentation = _itemFormPresentation;

    // La route naît dans une AUTRE branche de l'arbre : le mode de présentation
    // de la surface ne l'atteint pas par héritage. Il est donc REPOSÉ ici, avec
    // le mode du formulaire lui-même — consultation d'un item ⇒ fiches, édition
    // ⇒ champs de saisie, même à l'intérieur d'un formulaire ouvert en lecture
    // — ET avec la forme de la surface, faute de quoi les fiches retomberaient
    // sur la forme par défaut.
    Widget body(BuildContext routeContext) => ZReadModeScope(
          readMode: readOnly,
          layout: formeHeritee,
          child: _ZSubItemForm(
            title: _dialogTitle(routeContext, initial),
            itemFields: _itemFields,
            initial: initial,
            readOnly: readOnly,
            presentation: presentation,
            itemFieldBuilder: widget.itemFieldBuilder,
          ),
        );

    final navigator = Navigator.maybeOf(context);
    if (navigator == null) {
      _reportUnmountableForm(presentation, 'aucun Navigator au-dessus du champ');
      return null;
    }
    try {
      switch (presentation) {
        case ZSubItemFormPresentation.dialog:
          return await showDialog<Map<String, dynamic>>(
            context: context,
            builder: body,
          );
        case ZSubItemFormPresentation.sheet:
          return await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            // Un sous-formulaire n'est pas une liste d'options : il doit
            // pouvoir occuper la hauteur disponible et remonter au-dessus du
            // clavier, sinon la feuille est la PIRE des trois formes.
            isScrollControlled: true,
            useSafeArea: true,
            builder: body,
          );
        case ZSubItemFormPresentation.page:
          return await navigator.push<Map<String, dynamic>>(
            MaterialPageRoute<Map<String, dynamic>>(builder: body),
          );
      }
    } catch (error, stack) {
      // La forme demandée n'a pas pu être montée. Replier sur le dialogue est
      // préférable à ne rien ouvrir : l'utilisateur a demandé à éditer un item,
      // et la forme n'est qu'un habillage. L'incident reste signalé.
      _reportUnmountableForm(presentation, '$error', stack: stack);
      if (presentation == ZSubItemFormPresentation.dialog || !mounted) {
        return null;
      }
      return _safeAsync(
        () => showDialog<Map<String, dynamic>>(context: context, builder: body),
      );
    }
  }

  /// Signale une forme non montable — jamais avalée (rapporteur de crash,
  /// `FlutterError.onError`, `tester.takeException()`), jamais fatale au rendu.
  void _reportUnmountableForm(
    ZSubItemFormPresentation presentation,
    String reason, {
    StackTrace? stack,
  }) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError(
          'La forme « ${presentation.name} » du formulaire d\'item du champ '
          '« ${widget.field.name} » n\'a pas pu être montée : $reason.',
        ),
        stack: stack,
        library: 'zcrud_core',
        context: ErrorDescription(
          'lors de l\'ouverture du formulaire d\'item '
          '(ZSubListConfig.itemFormPresentation). Le formulaire parent reste '
          'intact : le socle ne casse pas un écran pour un habillage.',
        ),
      ),
    );
  }

  /// Pendant asynchrone de [_safe] — un repli qui échoue à son tour ne remonte
  /// pas (invariant AD-10).
  static Future<T?> _safeAsync<T>(Future<T?> Function() run) async {
    try {
      return await run();
    } catch (_) {
      return null;
    }
  }

  /// Crochet CRUD de l'hôte (`ZSubListSeams.onCrud`) — `null` ⇒ chemins natifs
  /// strictement inchangés (aucun `await` supplémentaire, aucune bifurcation).
  ZSubItemCrudHook? get _crudHook => _seams?.onCrud;

  /// Soumet une mutation au crochet CRUD **avant** de l'appliquer.
  ///
  /// **Défensivité asymétrique, et c'est délibéré** : contrairement aux seams de
  /// rendu (`_safe` → repli natif silencieux), un crochet qui **lève** ne peut
  /// pas être « traité comme absent ». Absent, il laisserait passer la
  /// mutation ; or l'hôte vient d'échouer à l'arbitrer, et personne ne sait si
  /// elle est légitime. Le socle prend donc la seule décision sûre — **véto** —
  /// et **signale** l'erreur à `FlutterError.reportError` : elle remonte à
  /// `FlutterError.onError`, donc au rapporteur de crash de l'application (et,
  /// en test, à `tester.takeException()`). Elle n'est jamais avalée, et le
  /// rendu n'est jamais cassé (invariant AD-10).
  Future<ZSubItemCrudOutcome> _arbitrate(
    ZSubItemCrudHook hook,
    ZSubItemCrudRequest request,
  ) async {
    try {
      final outcome = await hook(request);
      // Un véto MOTIVÉ parle à l'utilisateur — ici, et une seule fois, pour les
      // quatre déclencheurs (création, édition, suppression, option de menu).
      if (outcome.vetoed) _announceVeto(outcome);
      return outcome;
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'zcrud_core',
          context: ErrorDescription(
            'lors de l\'appel du crochet CRUD (ZSubListSeams.onCrud) pour '
            'l\'action « ${request.action.name} » du champ '
            '« ${widget.field.name} ». La mutation a été REFUSÉE : le socle ne '
            'la laisse pas passer sur un arbitrage en échec.',
          ),
        ),
      );
      return const ZSubItemCrudOutcome.veto();
    }
  }

  /// **Rend le motif d'un véto** à l'utilisateur — annonce au lecteur d'écran
  /// (invariant AD-13) **et** `SnackBar` si un `ScaffoldMessenger` est
  /// disponible, sinon rien de plus (aucun `throw` — invariant AD-10). Même
  /// mécanique best-effort que le retour de copie d'une fiche de lecture.
  ///
  /// Le libellé passe par le canal l10n habituel (`ZcrudScope.labels` → locale
  /// → table `en` → repli → la clé) : **jamais** un libellé codé en dur
  /// (invariant FR-26), y compris quand il vient d'une règle métier de l'hôte.
  ///
  /// Appelé **après** un `await` : `mounted` est vérifié — le geste a pu
  /// démonter le champ pendant que le crochet arbitrait. C'est aussi la raison
  /// pour laquelle le socle rend le motif lui-même au lieu de confier un
  /// `BuildContext` au crochet : un contexte capturé dans une requête et employé
  /// après un `await` est le piège classique du widget démonté.
  void _announceVeto(ZSubItemCrudOutcome outcome) {
    final key = outcome.reasonKey;
    if (key == null || !mounted) return;
    final message = label(context, key, fallback: outcome.reasonFallback ?? key);
    if (message.isEmpty) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// **Lecture** de l'état du formulaire parent offerte au crochet CRUD
  /// ([ZSubItemCrudRequest.parent]) — `null` hors formulaire (construction
  /// directe du widget), auquel cas le crochet le voit et s'en passe.
  ///
  /// Lecture **non tracée**, et c'est une différence assumée avec les résolveurs
  /// dérivés : elle a lieu au moment d'un geste, une fois, et n'ouvre **aucun**
  /// abonnement. Un crochet ne suit pas une tranche parente, il en prend une
  /// photo.
  ZValueOf? get _parentReader => widget.parentController?.valueOf;

  /// Applique le **correctif de parent** décrit par une issue de crochet
  /// ([ZSubItemCrudOutcome.parentPatch]) — **une seule fois**, après
  /// l'agrégation de la sous-liste.
  ///
  /// L'écriture passe par le canal **granulaire** du contrôleur parent : chaque
  /// tranche nommée notifie ses seuls abonnés, jamais le `ChangeNotifier`
  /// global (invariant AD-2). Un champ parent que le correctif ne nomme pas ne
  /// se reconstruit donc pas.
  ///
  /// 🔴 **La tranche de la sous-liste elle-même est IGNORÉE.** Elle vient d'être
  /// publiée par `_syncToParent` ; l'écraser depuis un correctif détruirait
  /// l'agrégation que le socle garantit. Un hôte qui veut changer l'item rend
  /// une issue `replace`.
  ///
  /// **Aucune boucle possible** : ce champ n'est abonné qu'aux tranches lues par
  /// ses résolveurs, jamais à la sienne ; et un résolveur relancé ne rappelle
  /// pas le crochet — seul un geste de l'utilisateur le fait.
  void _applyParentPatch(Map<String, Object?>? patch) {
    if (patch == null || patch.isEmpty) return;
    final parent = widget.parentController;
    if (parent == null) return;
    for (final entry in patch.entries) {
      if (entry.key == widget.field.name) continue;
      parent.setValue(entry.key, entry.value);
    }
  }

  /// Vue d'un item pour le crochet — l'indice est **relu** au moment de
  /// l'appel (un `await` a pu passer entre-temps) et retombe sur `0` si l'item
  /// n'est plus dans la liste, plutôt que sur un `-1` que l'hôte lirait comme
  /// une position (invariant AD-10).
  ZSubListItemView _hookView(_SubItem item) {
    final index = _items.indexOf(item);
    return _viewOf(
      item,
      index < 0 ? 0 : index,
      _displayDataOf(item),
      readOnly: widget.field.readOnly,
    );
  }

  /// Ajout via le formulaire d'item. L'item est amorcé de `defaultNewItem`
  /// **fusionné** avec les `defaults` du [template] de création choisi — les
  /// valeurs du gabarit priment. Item vide par défaut.
  ///
  /// Le crochet CRUD, s'il est déclaré, arbitre **avant** l'insertion : il peut
  /// refuser (rien n'est ajouté) ou remplacer la donnée validée. Un
  /// remplacement est traité comme une **graine** (résidu hors sous-schéma
  /// conservé) — c'est ainsi qu'un hôte attribue un `id` à la création.
  ///
  /// ## 🔴 Le résidu de la GRAINE survit désormais à la création
  ///
  /// Le formulaire d'item ne rend, et ne renvoie, que les `itemFields`. Les
  /// clés de la graine que le sous-schéma **ne déclare pas** étaient donc
  /// **perdues** — y compris la charge utile d'un gabarit, qui est justement
  /// la donnée qui distingue « ajouter un événement de type X » de « ajouter un
  /// événement ». Elles sont maintenant conservées dans le résidu du nouvel
  /// item, exactement comme celui d'un item venu du parent, et **transmises au
  /// crochet** dans `data` — sans quoi l'hôte arbitrerait une donnée amputée de
  /// ce qu'il vient lui-même de déclarer.
  ///
  /// Voir la note de rupture sur `ZSubListConfig.defaultNewItem` pour le
  /// périmètre exact. Sans clé étrangère dans la graine, `_unmappedOf` rend la
  /// constante vide : le chemin est identique à l'octet près.
  Future<void> _openAddDialog({ZSubListItemTemplate? template}) async {
    final seed = <String, dynamic>{
      ..._defaultNewItem,
      ...?template?.defaults,
    };
    // Gabarit **sans saisie** (`opensForm: false`) : la graine EST la donnée
    // proposée. C'est le geste du menu d'ajout legacy, qui appelait le crochet
    // sans ouvrir quoi que ce soit.
    final Map<String, dynamic>? result = template != null && !template.opensForm
        ? <String, dynamic>{
            for (final f in _itemFields) f.name: seed[f.name],
          }
        : await _showItemForm(seed, readOnly: false);
    if (!mounted || result == null) return;
    // Résidu de la GRAINE : les clés hors sous-schéma que l'hôte a déclarées et
    // que le formulaire ne pouvait pas rendre. Écrit AVANT le résultat saisi :
    // une clé déclarée l'emporte toujours sur son homonyme du gabarit.
    var data = <String, dynamic>{..._unmappedOf(seed), ...result};
    Map<String, Object?>? patch;
    final hook = _crudHook;
    if (hook != null) {
      final outcome = await _arbitrate(
        hook,
        ZSubItemCrudRequest(
          field: widget.field,
          action: ZCrudAction.create,
          data: data,
          // Le gabarit CHOISI — l'équivalent du `{option}` legacy sur `create`.
          // `null` pour un ajout par simple bouton `+` : rien n'a été choisi.
          template: template,
          parent: _parentReader,
        ),
      );
      if (!mounted || outcome.vetoed) return;
      final replacement = outcome.data;
      if (replacement != null) data = replacement;
      patch = outcome.parentPatch;
    }
    setState(() => _items.add(_makeItem(data, preserveUnmapped: true)));
    _syncToParent();
    // APRÈS l'agrégation : le parent voit la liste à jour ET son correctif dans
    // le même état cohérent (un total qui précéderait sa ligne serait faux).
    _applyParentPatch(patch);
  }

  /// Édition via dialog (remplace **à sa place** — identité stable
  /// conservée en réécrivant les tranches du contrôleur de l'item).
  Future<void> _openEditDialog(_SubItem item) async {
    // Graine BRUTE (résidu hors schéma compris) : le dialogue n'en lit que les
    // `itemFields`, mais le titre, lui, peut avoir besoin de l'identifiant.
    // La donnée **transformée** n'entre jamais ici : on édite ce qui est
    // stocké, pas son habillage.
    final result = await _showItemForm(_rawItemData(item), readOnly: false);
    if (!mounted || result == null) return;
    var data = result;
    Map<String, Object?>? patch;
    final hook = _crudHook;
    if (hook != null) {
      final outcome = await _arbitrate(
        hook,
        ZSubItemCrudRequest(
          field: widget.field,
          action: ZCrudAction.update,
          parent: _parentReader,
          // Donnée PROPOSÉE : le résidu hors sous-schéma d'abord (donc `id`),
          // les tranches saisies ensuite — MÊME ordre que `_syncToParent`, de
          // sorte que le crochet voie exactement ce qui serait agrégé.
          data: <String, dynamic>{...item.unmapped, ...result},
          item: _hookView(item),
        ),
      );
      if (!mounted || outcome.vetoed) return;
      final replacement = outcome.data;
      if (replacement != null) {
        data = replacement;
        item.unmapped = <String, dynamic>{
          ...item.unmapped,
          ..._unmappedOf(replacement),
        };
      }
      patch = outcome.parentPatch;
    }
    for (final f in _itemFields) {
      item.controller.setValue(f.name, data[f.name]);
    }
    setState(() {});
    _syncToParent();
    _applyParentPatch(patch);
  }

  /// Consultation (dialog `readOnly`, sans Enregistrer).
  Future<void> _openViewDialog(_SubItem item) async {
    await _showItemForm(_rawItemData(item), readOnly: true);
  }

  /// Suppression avec **dialog de confirmation** puis retrait. En mode
  /// `softDelete`, l'item est **marqué supprimé** (restaurable) au lieu
  /// d'être retiré définitivement.
  Future<void> _confirmDelete(_SubItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(label(dialogContext, 'confirmDeleteItem')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(label(dialogContext, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(label(dialogContext, 'delete')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    Map<String, Object?>? patch;
    final hook = _crudHook;
    if (hook != null) {
      final outcome = await _arbitrate(
        hook,
        ZSubItemCrudRequest(
          field: widget.field,
          action: ZCrudAction.delete,
          data: _rawItemData(item),
          item: _hookView(item),
          parent: _parentReader,
        ),
      );
      // Un remplacement n'a pas de destinataire ici : l'item s'en va. Seul le
      // véto a un effet — et c'est le seul moyen de le retenir. Le correctif de
      // parent, lui, en a un : un retrait de ligne change les totaux.
      if (!mounted || outcome.vetoed) return;
      patch = outcome.parentPatch;
    }
    if (_softDelete) {
      setState(() => item.deleted = true);
      _syncToParent();
      _applyParentPatch(patch);
      return;
    }
    final index = _items.indexOf(item);
    if (index >= 0) _removeAt(index);
    _applyParentPatch(patch);
  }

  /// Restaure un item soft-deleted (réintègre l'agrégation parent).
  void _restore(_SubItem item) {
    setState(() => item.deleted = false);
    _syncToParent();
  }

  /// Contrôle d'ajout — **menu** de gabarits de création si
  /// `creationTemplates` non vide, sinon simple bouton `+`. Chaque gabarit
  /// pré-remplit le dialog.
  Widget _buildAddControl(BuildContext context) {
    final templates = _creationTemplates;
    if (templates.isEmpty) {
      return IconButton(
        icon: const Icon(Icons.add),
        tooltip: _addLabel(context),
        onPressed: () => _openAddDialog(),
      );
    }
    // Résolution par IDENTITÉ, JAMAIS par position : la valeur portée est le
    // GABARIT lui-même, jamais son index. Avec `value: i` + `templates[i]`,
    // un rebuild survenu entre l'ouverture du menu et la sélection (la
    // sous-liste rebâtit à chaque `setState` d'item) et qui RÉORDONNE les
    // gabarits ouvrirait un dialog pré-rempli avec les valeurs d'un AUTRE
    // gabarit ; un rebuild qui les RACCOURCIT lèverait un `RangeError` dans
    // un gestionnaire de tap. Même sémantique que `ZDefaultMenuRenderer`
    // (`zcrud_menu`) — non importable ici (invariant AD-1, out-degree zcrud
    // de 0).
    return PopupMenuButton<ZSubListItemTemplate>(
      icon: const Icon(Icons.add),
      tooltip: _addLabel(context),
      onSelected: (template) => _openAddDialog(template: template),
      itemBuilder: (context) => <PopupMenuEntry<ZSubListItemTemplate>>[
        for (final template in templates)
          PopupMenuItem<ZSubListItemTemplate>(
            value: template,
            child: Text(label(
              context,
              template.labelKey,
              fallback: template.labelFallback ?? template.labelKey,
            )),
          ),
      ],
    );
  }

  /// Vue immuable d'un item telle qu'un seam de présentation la reçoit.
  ///
  /// [display] est le résultat du transformateur d'affichage quand il est
  /// déclaré ; sinon la donnée **brute**. Un seam voit donc toujours ce que
  /// l'utilisateur voit — c'est ce qui rend cohérents un rendu libre et les
  /// cellules de résumé qu'il remplace.
  ZSubListItemView _viewOf(
    _SubItem item,
    int index,
    Map<String, dynamic>? display, {
    required bool readOnly,
  }) =>
      ZSubListItemView(
        field: widget.field,
        data: display ?? _rawItemData(item),
        index: index,
        itemId: item.id,
        deleted: item.deleted,
        readOnly: readOnly,
      );

  /// **Actions supplémentaires** d'un item ([ZSubListSeams.itemActionsBuilder])
  /// — rendues **en plus** des actions natives, jamais à leur place.
  ///
  /// Chaque action est contrainte à **≥ 48 dp** (invariant AD-13) : le socle ne
  /// peut pas garantir la cible tactile d'un widget qu'il ne construit pas, il
  /// peut en revanche garantir la **place** qu'il lui réserve. Un seam absent
  /// ou qui lève rend une liste vide (invariant AD-10) — donc, structurellement,
  /// le rendu d'avant.
  ///
  /// [display] est la donnée d'affichage **quand le mode courant honore le
  /// transformateur** (compact). En `inline`, l'appelant passe `null` : ce mode
  /// n'applique pas le transformateur, et une action ne doit pas voir une
  /// donnée que la ligne d'à côté n'affiche pas.
  List<Widget> _extraActions(
    BuildContext context,
    _SubItem item,
    int index, {
    required bool readOnly,
    Map<String, dynamic>? display,
  }) {
    final builder = _seams?.itemActionsBuilder;
    if (builder == null) return const <Widget>[];
    final built = _safe(() => builder(
          context,
          _viewOf(item, index, display, readOnly: readOnly),
        ));
    if (built == null || built.isEmpty) return const <Widget>[];
    return <Widget>[
      for (final action in built)
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: action,
        ),
    ];
  }

  /// **Options de menu VISIBLES** pour cet item — `const []` si aucune ne
  /// survit au filtrage.
  ///
  /// 🔴 **ACL D'ABORD, PRÉDICAT ENSUITE.** L'ordre n'est pas une préférence de
  /// style : une option est une **déclaration de l'hôte de présentation**, pas
  /// une source de droit. Le prédicat n'est même pas consulté quand l'ACL a dit
  /// non — il ne peut donc, structurellement, que **restreindre**. Si le
  /// filtrage était inversé (ou fusionné en un `||`), une option permissive
  /// offrirait un geste sur un formulaire où l'ACL refuse tout.
  ///
  /// La lecture seule est appliquée **avec** l'ACL, et par la même règle que les
  /// actions natives : une action qui écrit ([ZCrudActionMutation.mutatesData])
  /// n'est pas offerte sur un champ en lecture seule, quoi qu'en dise l'ACL.
  ///
  /// Un prédicat qui **lève** masque l'option (`_safe` → `null` ≠ `true`) : le
  /// repli d'un doute de visibilité est de ne pas offrir le geste, jamais de
  /// l'offrir (invariant AD-10).
  List<ZSubItemMenuOption> _visibleOptions(
    List<ZSubItemMenuOption> declared,
    _SubItem item,
    int index, {
    required ZAcl acl,
    required String? cid,
    required bool readOnly,
    Map<String, dynamic>? display,
  }) {
    if (declared.isEmpty) return const <ZSubItemMenuOption>[];
    final view = _viewOf(item, index, display, readOnly: readOnly);
    final kept = <ZSubItemMenuOption>[];
    for (final option in declared) {
      final action = option.effectivePermission;
      // 1. ACL (et lecture seule) — jamais contournables.
      if (readOnly && action.mutatesData) continue;
      if (!acl.can(action, collectionId: cid)) continue;
      // 2. Prédicat de l'hôte — il ne peut que retirer.
      final predicate = option.isVisible;
      if (predicate != null && _safe(() => predicate(view)) != true) continue;
      kept.add(option);
    }
    return kept.isEmpty ? const <ZSubItemMenuOption>[] : kept;
  }

  /// Menu de **débordement** d'une ligne : rendu **après** les actions natives
  /// et après les actions ajoutées par `itemActionsBuilder` — il n'en remplace
  /// aucune et n'en double aucune.
  ///
  /// Rendu **uniquement** si [options] n'est pas vide : jamais un déclencheur
  /// qui ouvrirait un menu vide, jamais un widget de plus quand rien n'est
  /// déclaré. Contraint à ≥ 48 dp (invariant AD-13), nom accessible `moreActions`
  /// (clé l10n déjà servie par le socle). L'option est portée comme **valeur**
  /// du `PopupMenuItem` : résolution par identité, jamais par position.
  Widget _buildItemMenu(
    BuildContext context,
    _SubItem item,
    List<ZSubItemMenuOption> options,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: PopupMenuButton<ZSubItemMenuOption>(
        key: ValueKey<String>('itemMenu_${item.id}'),
        icon: const Icon(Icons.more_vert),
        tooltip: label(context, 'moreActions'),
        onSelected: (option) => _onOptionSelected(item, option),
        itemBuilder: (menuContext) => <PopupMenuEntry<ZSubItemMenuOption>>[
          for (final option in options)
            PopupMenuItem<ZSubItemMenuOption>(
              value: option,
              child: _optionEntry(menuContext, option),
            ),
        ],
      ),
    );
  }

  /// Contenu d'une entrée de menu : icône optionnelle + libellé **localisé**
  /// (`labelKey` → repli `labelFallback` → la clé). Une option destructive
  /// emprunte la couleur d'erreur du **thème** — jamais une couleur codée en
  /// dur (invariant FR-26). Directionnel (`TextAlign.start`, `Row` qui suit la
  /// `Directionality`).
  Widget _optionEntry(BuildContext context, ZSubItemMenuOption option) {
    final Color? tint =
        option.destructive ? Theme.of(context).colorScheme.error : null;
    final text = Text(
      label(context, option.labelKey,
          fallback: option.labelFallback ?? option.labelKey),
      style: tint == null ? null : TextStyle(color: tint),
      textAlign: TextAlign.start,
    );
    final icon = option.icon;
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: tint),
        const SizedBox(width: 12),
        Flexible(child: text),
      ],
    );
  }

  /// Une option a été choisie : elle est **arbitrée par le crochet CRUD**, comme
  /// une action native — même ordre (avant toute écriture), même véto, même
  /// signalement d'erreur.
  ///
  /// `proceed` applique « la donnée de la requête telle quelle » : pour une
  /// option, cette donnée **est** l'item courant — c'est donc, par construction,
  /// un non-événement. Seul `replace` écrit. Cette symétrie est voulue : le
  /// socle n'invente aucune sémantique particulière selon le déclencheur.
  Future<void> _onOptionSelected(
    _SubItem item,
    ZSubItemMenuOption option,
  ) async {
    final hook = _crudHook;
    if (hook == null) return;
    final outcome = await _arbitrate(
      hook,
      ZSubItemCrudRequest(
        field: widget.field,
        action: option.effectivePermission,
        data: _rawItemData(item),
        item: _hookView(item),
        option: option,
        parent: _parentReader,
      ),
    );
    if (!mounted || outcome.vetoed) return;
    final replacement = outcome.data;
    if (replacement == null) {
      // Aucune donnée d'item à écrire — le correctif de parent, lui, reste dû :
      // une option peut n'agir QUE sur le formulaire parent.
      _applyParentPatch(outcome.parentPatch);
      return;
    }
    item.unmapped = <String, dynamic>{
      ...item.unmapped,
      ..._unmappedOf(replacement),
    };
    for (final f in _itemFields) {
      item.controller.setValue(f.name, replacement[f.name]);
    }
    setState(() {});
    _syncToParent();
    _applyParentPatch(outcome.parentPatch);
  }

  /// Contenu résumé d'une ligne compacte : le **rendu libre**
  /// ([ZSubListSeams.itemBuilder]) s'il est déclaré et n'a pas levé, sinon les
  /// cellules natives. Le seam ne remplace QUE ce contenu : les actions de fin
  /// de ligne, le badge de soft-delete et l'ACL restent au socle.
  Widget _rowSummary(
    BuildContext context,
    _SubItem item,
    int index,
    Map<String, dynamic>? display, {
    required bool stacked,
    required bool readOnly,
  }) {
    final builder = _seams?.itemBuilder;
    if (builder != null) {
      final built = _safe(
        () => builder(context, _viewOf(item, index, display, readOnly: readOnly)),
      );
      if (built != null) return built;
    }
    return _summaryCells(context, item, replie: stacked, display: display);
  }

  /// Rendu **compact** : en-tête + liste résumé keyée + actions gated ACL.
  ///
  /// La table de résumé à en-têtes est mesurée à chaque mise en page
  /// ([_summaryIsStacked]) : au-dessus du seuil elle reste une table alignée,
  /// en dessous elle devient un empilement de couples libellé/valeur et la
  /// ligne d'en-têtes s'efface avec elle. Les deux décisions sortent du **même**
  /// calcul : il ne peut donc pas y avoir d'en-tête sans colonnes en face.
  ///
  /// **Seams** (tous optionnels ; aucun déclaré ⇒ structure d'avant, à
  /// l'identique) : `captionBuilder` remplace la ligne d'en-tête, `itemBuilder`
  /// le contenu résumé d'une ligne, `itemActionsBuilder` ajoute des actions de
  /// fin de ligne, `listViewBuilder` remplace le conteneur de lignes,
  /// `itemTransformer` habille les valeurs affichées.
  Widget _buildCompact(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final readOnly = widget.field.readOnly;
    final cid = widget.collectionId;
    final seams = _seams;
    // Priorité : paramètre du champ > seam du registre > ACL du scope ambiant
    // > refus. Le seam s'intercale AVANT le scope : une ACL déclarée pour CE
    // champ est plus spécifique que celle de l'écran, et un hôte qui n'en
    // déclare pas retrouve exactement la chaîne d'avant.
    final ZAcl acl = widget.acl ??
        seams?.acl ??
        ZcrudScope.maybeOf(context)?.acl ??
        const ZDenyAllAcl();
    final canCreate =
        !readOnly && acl.can(ZCrudAction.create, collectionId: cid);
    final canView = acl.can(ZCrudAction.view, collectionId: cid);
    final canUpdate =
        !readOnly && acl.can(ZCrudAction.update, collectionId: cid);
    final canDelete =
        !readOnly && acl.can(ZCrudAction.delete, collectionId: cid);

    // Actions supplémentaires : précalculées **UNIQUEMENT** si le seam est
    // déclaré. La réserve de fin sous l'en-tête doit connaître leur NOMBRE
    // avant que les lignes ne soient bâties, et ce nombre peut différer d'un
    // item à l'autre — c'est le maximum qui gouverne l'alignement des colonnes.
    // Sans seam : `null`, aucune allocation, aucune perte de paresse, aucun
    // appel — le rendu est celui d'avant, à la structure près comme au compte
    // de widgets près.
    final List<List<Widget>>? extras = _seams?.itemActionsBuilder == null
        ? null
        : <List<Widget>>[
            for (var i = 0; i < _items.length; i++)
              _extraActions(
                context,
                _items[i],
                i,
                readOnly: readOnly,
                display: _displayDataOf(_items[i]),
              ),
          ];
    var extraCount = 0;
    if (extras != null) {
      for (final e in extras) {
        if (e.length > extraCount) extraCount = e.length;
      }
    }

    // Options de menu par item — mêmes règles de gratuité que les actions
    // supplémentaires : rien de déclaré (ou aucun crochet pour les recevoir)
    // ⇒ `null`, aucune allocation, aucun appel de prédicat, aucun widget.
    final declaredOptions =
        seams?.itemMenuOptions ?? const <ZSubItemMenuOption>[];
    final hook = seams?.onCrud;
    // Une option n'a **aucun destinataire** sans crochet : le socle ne rend pas
    // une affordance inerte. C'est une erreur de configuration — signalée en
    // debug/test, jamais un plantage en production (invariant AD-10).
    assert(
      declaredOptions.isEmpty || hook != null,
      'ZSubListSeams.itemMenuOptions déclaré sans ZSubListSeams.onCrud : '
      'les options seraient inertes (aucun destinataire). Déclarez `onCrud`, '
      'ou retirez les options.',
    );
    final List<List<ZSubItemMenuOption>>? optionsPerItem =
        declaredOptions.isEmpty || hook == null
            ? null
            : <List<ZSubItemMenuOption>>[
                for (var i = 0; i < _items.length; i++)
                  _visibleOptions(
                    declaredOptions,
                    _items[i],
                    i,
                    acl: acl,
                    cid: cid,
                    readOnly: readOnly,
                    display: _displayDataOf(_items[i]),
                  ),
              ];
    // Le déclencheur est UN widget, quel que soit le nombre d'options ; il
    // n'occupe une place de colonne que si au moins une ligne en porte un.
    var menuCount = 0;
    if (optionsPerItem != null) {
      for (final options in optionsPerItem) {
        if (options.isNotEmpty) {
          menuCount = 1;
          break;
        }
      }
    }

    final actionCount = (canView ? 1 : 0) +
        (canUpdate ? 1 : 0) +
        (canDelete ? 1 : 0) +
        extraCount +
        menuCount;

    final listSeam = _seams?.listViewBuilder;
    final captionSeam = _seams?.captionBuilder;

    // a11y : pas de `label:` sur le conteneur — le `Text` visible
    // (en-tête) porte déjà le nom de section ; un `label:` doublerait l'annonce.
    return Semantics(
      container: true,
      // La largeur réellement offerte à la table est connue ICI, et nulle part
      // ailleurs : ni la config ni le thème ne savent sur quelle surface la
      // sous-liste est posée. Ce `LayoutBuilder` ne reconstruit qu'à un
      // changement de contraintes — jamais à une frappe (invariant AD-2).
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              _summaryIsStacked(theme, constraints.maxWidth, actionCount);

          // Rendu **tabulaire** : une `Table` unique (en-têtes + lignes). Cinq
          // conditions, toutes nécessaires, aucune cosmétique :
          // - le rendu tabulaire est demandé (`showSummaryHeaders`) et il y a
          //   des colonnes ET des lignes à disposer ;
          // - la place suffit (sinon c'est l'empilement mesuré qui parle) ;
          // - aucun conteneur hôte (`listViewBuilder`) : il dispose les lignes
          //   comme il l'entend, aucune colonne ne peut plus être promise ;
          // - aucun rendu libre de ligne (`itemBuilder`) : le socle reçoit un
          //   widget OPAQUE qu'il ne peut pas découper en cellules ;
          // - le budget de lignes est tenu (une table ne se virtualise pas —
          //   voir `ZSubListFieldWidget.summaryTableRowBudget`).
          final tabular = _showSummaryHeaders &&
              !stacked &&
              listSeam == null &&
              _seams?.itemBuilder == null &&
              _summaryColumns.isNotEmpty &&
              _items.isNotEmpty &&
              _items.length <= ZSubListFieldWidget.summaryTableRowBudget;

          // Une ligne, à l'indice demandé. Indice hors bornes ⇒
          // `SizedBox.shrink()` : un conteneur hôte qui redemande un item
          // disparu ne fait pas échouer le rendu (invariant AD-10).
          Widget buildRow(BuildContext rowContext, int i) {
            if (i < 0 || i >= _items.length) return const SizedBox.shrink();
            final item = _items[i];
            final display = _displayDataOf(item);
            return KeyedSubtree(
              key: ValueKey<String>(item.id),
              child: _CompactRow(
                borderColor: theme.fieldBorderColor,
                radius: theme.radiusM,
                summary: _rowSummary(
                  rowContext,
                  item,
                  i,
                  display,
                  stacked: stacked,
                  readOnly: readOnly,
                ),
                extraActions: extras == null || i >= extras.length
                    ? const <Widget>[]
                    : extras[i],
                menu: optionsPerItem == null ||
                        i >= optionsPerItem.length ||
                        optionsPerItem[i].isEmpty
                    ? null
                    : _buildItemMenu(rowContext, item, optionsPerItem[i]),
                deleted: item.deleted,
                canView: canView,
                canUpdate: canUpdate,
                canDelete: canDelete,
                viewLabel: label(rowContext, 'viewItem'),
                editLabel: label(rowContext, 'editItem'),
                deleteLabel: label(rowContext, 'deleteItem'),
                restoreLabel: label(rowContext, 'restoreItem'),
                deletedBadge: label(rowContext, 'deletedItemBadge'),
                onView: () => _openViewDialog(item),
                onEdit: () => _openEditDialog(item),
                onDelete: () => _confirmDelete(item),
                onRestore: () => _restore(item),
              ),
            );
          }

          // Corps de liste — évalué **seulement** s'il y a des lignes : sur une
          // sous-liste vide, c'est l'état vide natif qui parle, et le seam
          // n'est pas appelé pour rien (le moteur legacy faisait le même
          // choix).
          Widget buildListBody() {
            final Widget nativeList = ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              itemBuilder: buildRow,
            );
            if (listSeam == null) return nativeList;
            // Conteneur libre : il reçoit les données d'affichage, les lignes
            // déjà bâties ET le builder de ligne (mêmes trois entrées que le
            // moteur legacy). S'il lève, la liste native reprend la main.
            final custom = _safe(
              () => listSeam(
                context,
                ZSubListViewData(
                  field: widget.field,
                  items: <Map<String, dynamic>>[
                    for (final item in _items)
                      _displayDataOf(item) ?? _rawItemData(item),
                  ],
                  children: <Widget>[
                    for (var i = 0; i < _items.length; i++)
                      buildRow(context, i),
                  ],
                  itemBuilder: buildRow,
                ),
              ),
            );
            return custom ?? nativeList;
          }

          // En-tête : soit l'habillage hôte (qui reçoit le contrôle d'ajout
          // **déjà filtré par l'ACL** — un `SizedBox.shrink()` quand la
          // création est refusée : ce seam n'ouvre aucun geste), soit la ligne
          // native, inchangée.
          Widget caption = Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    resolvedLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.start,
                  ),
                ),
                if (canCreate) _buildAddControl(context),
              ],
            ),
          );
          if (captionSeam != null) {
            final custom = _safe(
              () => captionSeam(
                context,
                canCreate ? _buildAddControl(context) : const SizedBox.shrink(),
              ),
            );
            if (custom != null) caption = custom;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              caption,
              if (tabular)
                _buildSummaryTable(
                  context,
                  theme: theme,
                  actionCount: actionCount,
                  canView: canView,
                  canUpdate: canUpdate,
                  canDelete: canDelete,
                  extras: extras,
                  optionsPerItem: optionsPerItem,
                )
              else ...<Widget>[
                // Hors table : la ligne d'en-têtes **reproduit** la géométrie
                // des cellules (colonnes de largeur égale, même réserve
                // d'actions). Rendue seulement s'il y a des colonnes ET des
                // lignes à coiffer — et seulement tant que les lignes SONT des
                // colonnes : empilées, elles portent leur propre libellé et
                // l'en-tête n'aurait plus rien à coiffer. Un conteneur hôte les
                // efface aussi : il dispose ses lignes comme il l'entend, un
                // en-tête ne pourrait plus promettre de tomber en face de quoi
                // que ce soit.
                if (_showSummaryHeaders &&
                    listSeam == null &&
                    !stacked &&
                    _summaryColumns.isNotEmpty &&
                    _items.isNotEmpty)
                  _summaryHeaderRow(context, actionCount),
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                    child: Text(
                      label(context, 'noItems'),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.start,
                    ),
                  )
                else
                  buildListBody(),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Mode tags (rangée de puces `InputChip`, minimal) ────────────────────────

  /// Rendu **tags** : rendu natif **MINIMAL** zéro-dépendance — une
  /// rangée `Wrap` de `InputChip` présentant le **résumé** de chaque item
  /// (`summaryFields`/repli titre), plus un bouton d'ajout (≥ 48 dp) réutilisant
  /// la machinerie de dialog existante (`_buildAddControl` → `_openAddDialog`).
  /// Tapoter une puce ouvre le dialog d'édition (consultation si `readOnly`) ;
  /// la puce est supprimable (`onDeleted` → `_confirmDelete`, gère softDelete).
  /// Directionnel (`Wrap` suit `Directionality`, `EdgeInsetsDirectional`),
  /// `Semantics` explicites, aucune couleur codée en dur (thème hérité,
  /// invariant FR-26). Les tags **riches** (toggle/icône par tag,
  /// réordonnancement drag) relèvent d'un rendu séparé, hors de ce mode
  /// minimal.
  Widget _buildTags(BuildContext context) {
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final readOnly = widget.field.readOnly;
    final removeLabel = label(context, 'removeItem');
    // Items visibles : les items soft-deleted sont EXCLUS (cohérent avec
    // l'agrégation parent) ; le rendu minimal ne porte pas la restauration
    // (offerte par le mode compact / un rendu tags riche futur).
    final visible = <_SubItem>[
      for (final item in _items)
        if (!item.deleted) item,
    ];

    // En-tête : habillage hôte s'il est déclaré (il reçoit le contrôle d'ajout
    // natif, ou un `SizedBox.shrink()` en lecture seule), sinon la ligne
    // native — inchangée.
    Widget caption = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              resolvedLabel,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.start,
            ),
          ),
          if (!readOnly) _buildAddControl(context),
        ],
      ),
    );
    final captionSeam = _seams?.captionBuilder;
    if (captionSeam != null) {
      final custom = _safe(() => captionSeam(
            context,
            readOnly ? const SizedBox.shrink() : _buildAddControl(context),
          ));
      if (custom != null) caption = custom;
    }

    // a11y : pas de `label:` sur le conteneur — le `Text` visible
    // (en-tête) porte déjà le nom de section ; un `label:` doublerait l'annonce.
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          caption,
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final item in visible)
                  InputChip(
                    key: ValueKey<String>('tag_${item.id}'),
                    label: Text(_chipLabel(item)),
                    // Invariant AD-13 : épingle la cible tactile à `padded`
                    // (≥ 48 dp) INDÉPENDAMMENT du thème ambiant — sinon un thème
                    // `materialTapTargetSize: shrinkWrap` ferait tomber la puce
                    // (et son `onDeleted`) sous 48 dp.
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onPressed: readOnly
                        ? () => _openViewDialog(item)
                        : () => _openEditDialog(item),
                    onDeleted: readOnly ? null : () => _confirmDelete(item),
                    deleteButtonTooltipMessage: readOnly ? null : removeLabel,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Libellé lisible d'une puce : résumé dérivé (`summaryFields`/titre)
  /// ou, à défaut, le libellé du champ (jamais une puce vide/illisible).
  ///
  /// Le transformateur d'affichage vaut ici comme dans le résumé compact : une
  /// puce est un résumé, elle en suit les règles.
  String _chipLabel(_SubItem item) {
    final display = _displayDataOf(item);
    final summaryColumns = _summaryColumns;
    if (summaryColumns.isNotEmpty) {
      final data = _columnData(item, display);
      final parts = <String>[
        for (final column in summaryColumns)
          if (_columnText(context, item, column, data).isNotEmpty)
            _columnText(context, item, column, data),
      ];
      if (parts.isNotEmpty) return parts.join(' — ');
    }
    final title = _defaultTitle(context, item, display);
    if (title.isNotEmpty) return title;
    return label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
  }
}

/// Ligne résumé d'un item en mode **compact** : résumé + actions de fin
/// de ligne accessibles (`IconButton` ≥ 48 dp, tooltips l10n), gated ACL en
/// amont (rendues conditionnellement). Bordure dérivée du thème (invariant
/// FR-26).
class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.borderColor,
    required this.radius,
    required this.summary,
    required this.deleted,
    required this.canView,
    required this.canUpdate,
    required this.canDelete,
    required this.viewLabel,
    required this.editLabel,
    required this.deleteLabel,
    required this.restoreLabel,
    required this.deletedBadge,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
    this.extraActions = const <Widget>[],
    this.menu,
  });

  final Color? borderColor;
  final Radius radius;
  final Widget summary;

  /// Actions **supplémentaires** de l'hôte (seam `itemActionsBuilder`), déjà
  /// contraintes à ≥ 48 dp. Rendues **après** les actions natives — jamais à
  /// leur place, y compris sur une ligne soft-deleted (l'hôte sait qu'elle
  /// l'est : `ZSubListItemView.deleted`).
  final List<Widget> extraActions;

  /// Menu de **débordement** des options d'item (`itemMenuOptions`), ou `null`
  /// quand aucune option n'est visible pour cette ligne.
  ///
  /// Rendu **en dernier**, après les actions natives ET après [extraActions] :
  /// les trois canaux coexistent, aucun n'est masqué ni doublé. Il est offert
  /// aussi sur une ligne soft-deleted — la vue passée au prédicat porte
  /// `deleted`, l'hôte décide donc lui-même ce qui a du sens dans cet état.
  final Widget? menu;

  /// Item soft-deleted → résumé barré + badge + action restaurer.
  final bool deleted;
  final bool canView;
  final bool canUpdate;
  final bool canDelete;
  final String viewLabel;
  final String editLabel;
  final String deleteLabel;
  final String restoreLabel;
  final String deletedBadge;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    // Résumé barré en état soft-deleted (a11y : badge textuel explicite).
    final summaryContent = deleted
        ? Row(
            children: <Widget>[
              Flexible(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                      decoration: TextDecoration.lineThrough),
                  child: summary,
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                child: Text(deletedBadge,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.start),
              ),
            ],
          )
        : summary;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: borderColor == null ? null : Border.all(color: borderColor!),
          borderRadius: BorderRadius.all(radius),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 0),
          child: Row(
            children: <Widget>[
              Expanded(child: summaryContent),
              _RowActions(
                deleted: deleted,
                canView: canView,
                canUpdate: canUpdate,
                canDelete: canDelete,
                viewLabel: viewLabel,
                editLabel: editLabel,
                deleteLabel: deleteLabel,
                restoreLabel: restoreLabel,
                onView: onView,
                onEdit: onEdit,
                onDelete: onDelete,
                onRestore: onRestore,
                extraActions: extraActions,
                menu: menu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// **Actions de fin de ligne** d'un item (`IconButton` ≥ 48 dp, tooltips l10n),
/// partagées par les DEUX rendus du mode compact : la ligne empilée/défilante
/// (`_CompactRow`) et la cellule d'actions de la table.
///
/// Le partage n'est pas une économie de lignes : il rend **impossible** que les
/// deux rendus n'offrent pas les mêmes gestes, dans le même ordre, sous la même
/// ACL. Un budget de lignes franchi change la mise en page ; il ne doit pas
/// changer ce qu'on peut faire d'une ligne.
///
/// Ordre **invariant** : actions natives (gatées ACL en amont), puis
/// [extraActions] de l'hôte, puis le [menu] de débordement — aucun canal n'en
/// masque un autre. Une ligne soft-deleted n'offre que « restaurer », qui n'est
/// **pas** gatée : sans elle, la ligne serait un cul-de-sac.
class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.deleted,
    required this.canView,
    required this.canUpdate,
    required this.canDelete,
    required this.viewLabel,
    required this.editLabel,
    required this.deleteLabel,
    required this.restoreLabel,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
    this.extraActions = const <Widget>[],
    this.menu,
  });

  final bool deleted;
  final bool canView;
  final bool canUpdate;
  final bool canDelete;
  final String viewLabel;
  final String editLabel;
  final String deleteLabel;
  final String restoreLabel;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;
  final List<Widget> extraActions;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Item soft-deleted : seule l'action **restaurer** est offerte.
        if (deleted)
          IconButton(
            icon: const Icon(Icons.restore_from_trash),
            tooltip: restoreLabel,
            onPressed: onRestore,
          )
        else ...<Widget>[
          if (canView)
            IconButton(
              icon: const Icon(Icons.visibility),
              tooltip: viewLabel,
              onPressed: onView,
            ),
          if (canUpdate)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: editLabel,
              onPressed: onEdit,
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: deleteLabel,
              onPressed: onDelete,
            ),
        ],
        ...extraActions,
        ?menu,
      ],
    );
  }
}

/// Formulaire d'édition PAR ITEM — héberge un `ZFormController`
/// **PROPRE** amorcé du `Map` de l'item et rend les sous-champs via le
/// dispatcher `ZFieldWidget` (réutilisation intégrale de la machinerie
/// d'édition). **Aucun `Form` global** (invariant AD-2). Le contrôleur est
/// `dispose` à la fermeture (aucune fuite). Invariant AD-2 : taper dans un
/// sous-champ ne reconstruit QUE ce champ (`ZFieldWidget`/
/// `ZFieldListenableBuilder`), jamais le formulaire ni la liste résumé. En
/// lecture (`readOnly`) : chaque spec `copyWith(readOnly: true)`, pas de bouton
/// Enregistrer (seul **Fermer**).
///
/// ## Une seule donnée, trois enveloppes
///
/// [presentation] ne choisit **que le chrome** : la boîte de dialogue, la
/// feuille modale ou la page. Le **corps** ([_fields]) et la **sortie**
/// ([_save]) sont partagés, si bien que la même saisie rend structurellement la
/// même `Map` dans les trois formes. Faire diverger les trois demanderait
/// d'écrire trois `_save` — c'est précisément ce que cette classe interdit.
///
/// ## a11y (invariant AD-13)
///
/// Les trois formes portent le titre comme **en-tête annoncé**
/// (`Semantics(header: true)`), une cible tactile ≥ 48 dp sur chaque bouton
/// (épinglée à `padded` — un thème en `shrinkWrap` ne peut pas la faire tomber)
/// et un chemin de **retour clavier/système** : la boîte et la feuille se
/// referment par `Échap`/retour arrière (route modale barrée), la page par le
/// bouton de retour de sa barre de titre. Aucune de ces sorties n'enregistre :
/// annuler rend `null`, comme le fait déjà la boîte de dialogue.
class _ZSubItemForm extends StatefulWidget {
  const _ZSubItemForm({
    required this.title,
    required this.itemFields,
    required this.initial,
    required this.readOnly,
    required this.presentation,
    this.itemFieldBuilder,
  });

  final String title;
  final List<ZFieldSpec> itemFields;
  final Map<String, dynamic> initial;
  final bool readOnly;
  final ZSubItemFormPresentation presentation;
  final ZSubItemFieldBuilder? itemFieldBuilder;

  @override
  State<_ZSubItemForm> createState() => _ZSubItemFormState();
}

class _ZSubItemFormState extends State<_ZSubItemForm> {
  /// Contrôleur PROPRE au formulaire (create/dispose) — jamais partagé avec le
  /// conteneur : taper ici n'affecte le parent qu'à **Enregistrer**.
  late final ZFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ZFormController(
      initialValues: <String, Object?>{
        for (final f in widget.itemFields) f.name: widget.initial[f.name],
      },
      visibleFields: <String>[for (final f in widget.itemFields) f.name],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildField(ZFieldSpec field) {
    final spec = widget.readOnly ? field.copyWith(readOnly: true) : field;
    final custom = widget.itemFieldBuilder;
    if (custom != null) {
      return custom(context, _controller, spec, 'dialog');
    }
    return ZFieldWidget(controller: _controller, field: spec);
  }

  /// **VOIE UNIQUE de sortie des données**, quelle que soit la forme. Les clés
  /// et leur ordre sont ceux du sous-schéma — ni le chrome, ni la route, ni la
  /// hauteur de la surface n'entrent dans cette carte.
  void _save() {
    Navigator.of(context).pop(<String, dynamic>{
      for (final f in widget.itemFields) f.name: _controller.valueOf(f.name),
    });
  }

  void _cancel() => Navigator.of(context).pop();

  /// **Corps commun** aux trois formes : un sous-champ par `itemField`, à place
  /// stable (`KeyedSubtree`). La clé de place reste `dialog/<name>` dans les
  /// trois formes — la changer aurait rebattu l'identité des sous-champs chez
  /// tout hôte existant, pour un gain nul.
  List<Widget> get _fields => <Widget>[
        for (final f in widget.itemFields)
          KeyedSubtree(
            key: ValueKey<String>('dialog/${f.name}'),
            child: _buildField(f),
          ),
      ];

  /// Cible tactile ≥ 48 dp **indépendamment du thème ambiant** (invariant
  /// AD-13) — même précaution que la puce du mode `tags`.
  static final ButtonStyle _touchTarget = TextButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.padded,
    minimumSize: const Size(64, 48),
  );

  Widget _cancelButton(BuildContext context, {bool styled = false}) =>
      TextButton(
        style: styled ? _touchTarget : null,
        onPressed: _cancel,
        child: Text(label(context, widget.readOnly ? 'close' : 'cancel')),
      );

  Widget _saveButton(BuildContext context, {bool styled = false}) => TextButton(
        style: styled ? _touchTarget : null,
        onPressed: _save,
        child: Text(label(context, 'save')),
      );

  @override
  Widget build(BuildContext context) {
    switch (widget.presentation) {
      case ZSubItemFormPresentation.dialog:
        return _buildDialog(context);
      case ZSubItemFormPresentation.sheet:
        return _buildSheet(context);
      case ZSubItemFormPresentation.page:
        return _buildPage(context);
    }
  }

  /// Forme **par défaut** — rendue à l'identique de ce qu'elle a toujours été
  /// (aucun `Semantics` ajouté, aucun style de bouton posé) : c'est ce que
  /// voit un hôte qui ne déclare rien, et il ne doit rien voir bouger. Le titre
  /// d'un `AlertDialog` est **déjà** annoncé comme en-tête par Material.
  Widget _buildDialog(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: _fields,
        ),
      ),
      actions: <Widget>[
        _cancelButton(context),
        if (!widget.readOnly) _saveButton(context),
      ],
    );
  }

  /// Feuille modale — hauteur bornée à 90 % de la surface pour que le geste de
  /// fermeture reste atteignable, et **remontée au-dessus du clavier**
  /// (`viewInsets`) : une feuille qui laisse le clavier recouvrir ses champs
  /// est inutilisable là où elle sert précisément.
  Widget _buildSheet(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: _fields,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    _cancelButton(context, styled: true),
                    if (!widget.readOnly) _saveButton(context, styled: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Page entière — barre de titre (avec le bouton de retour natif, qui **ne
  /// sauvegarde pas**) et actions en fin de barre. `Scaffold` propre : la page
  /// vit sur sa propre route, elle ne partage rien avec l'écran parent.
  Widget _buildPage(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(widget.title, textAlign: TextAlign.start),
        ),
        actions: <Widget>[
          if (!widget.readOnly) _saveButton(context, styled: true),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: _fields,
          ),
        ),
      ),
    );
  }
}

/// Carte d'un item imbriqué : sous-formulaire + contrôles (retrait/réordo)
/// accessibles (`IconButton` ≥ 48 dp), bordure dérivée du thème (FR-26).
class _SubItemCard extends StatelessWidget {
  const _SubItemCard({
    required this.borderColor,
    required this.radius,
    required this.index,
    required this.count,
    required this.reorderable,
    required this.removable,
    required this.removeLabel,
    required this.upLabel,
    required this.downLabel,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.fields,
    this.extraActions = const <Widget>[],
  });

  /// Actions **supplémentaires** de l'hôte (seam `itemActionsBuilder`), déjà
  /// contraintes à ≥ 48 dp, rendues **après** retrait/réordonnancement.
  final List<Widget> extraActions;

  final Color? borderColor;
  final Radius radius;
  final int index;
  final int count;
  final bool reorderable;
  final bool removable;
  final String removeLabel;
  final String upLabel;
  final String downLabel;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: borderColor == null ? null : Border.all(color: borderColor!),
          borderRadius: BorderRadius.all(radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Column(children: fields)),
                if (reorderable)
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    tooltip: upLabel,
                    onPressed: index > 0 ? onMoveUp : null,
                  ),
                if (reorderable)
                  IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    tooltip: downLabel,
                    onPressed: index < count - 1 ? onMoveDown : null,
                  ),
                if (removable)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: removeLabel,
                    onPressed: onRemove,
                  ),
                ...extraActions,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
