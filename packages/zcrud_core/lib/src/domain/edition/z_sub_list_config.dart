/// Config additive `const` des champs **sous-liste** (`subItems`) et **item
/// dynamique** (`dynamicItem`) — mini-CRUD imbriqué (invariants AD-2/AD-4).
///
/// Un champ `subItems` porte une **liste d'items** ; chaque item est un
/// `Map<String, dynamic>` édité par un **sous-formulaire imbriqué** (réutilise
/// le dispatcher `ZFieldWidget`). Le **sous-schéma** de l'item est décrit ici
/// par un `List<ZFieldSpec>` **pur-données `const`** ([itemFields]) — jamais
/// une closure ni un widget (couche `domain`). Le champ `dynamicItem`
/// réutilise la même config (cardinalité ≤ 1).
///
/// **Point d'extension (invariant AD-4)** : `const`, additif (sous-classe de
/// [ZFieldConfig]), jamais `sealed`. L'interprétation (schéma → widgets
/// imbriqués) vit dans `ZSubListFieldWidget`/`ZDynamicItemFieldWidget` ; ici on
/// ne porte que la **donnée** du sous-schéma.
///
/// Recoupement avec `ZSubListScreen` : cette config décrit le **champ**
/// d'édition imbriqué (dans un formulaire) ; l'écran de sous-liste autonome
/// (mini-CRUD de niveau liste) est un moteur distinct. Le sous-schéma `const`
/// est la brique commune réutilisable entre les deux.
library;

import 'z_field_config.dart';
import 'z_field_spec.dart';

/// Mode de **rendu** d'une sous-liste (`subItems`).
///
/// Extension **additive** `const` (invariant AD-4, jamais `sealed`) : ajoute
/// un mode sans rien retirer. Valeurs en **camelCase**.
///
/// - [inline] (**défaut**, rétro-compat) : chaque item déballe TOUS ses
///   sous-champs en **sous-formulaire imbriqué** (mini-CRUD inline). Aucun
///   changement pour les configs existantes.
/// - [compact] : **liste résumé** (une ligne/valeurs de résumé par item) +
///   **dialog d'édition par item** (ajouter/consulter/modifier/supprimer),
///   chaque action **filtrée par `ZAcl`** — sans imposer le déballage inline
///   de tous les items.
/// - [tags] : **rangée de puces** (`Wrap`/`InputChip`) présentant le résumé de
///   chaque item + bouton d'ajout réutilisant la machinerie de création
///   (dialog par item). **Rendu natif minimal zéro-dépendance** — additif,
///   opt-in : jamais atteint sans `displayMode: ZSubListDisplayMode.tags`
///   (`inline` reste le défaut, rétro-compat stricte).
enum ZSubListDisplayMode {
  /// Sous-formulaires imbriqués empilés (comportement par défaut).
  inline,

  /// Liste résumé + dialog d'édition par item, actions filtrées par `ZAcl`.
  compact,

  /// Rangée de puces `InputChip` (résumé par item) + ajout par dialog — rendu
  /// natif minimal zéro-dépendance.
  tags,
}

/// **Forme de présentation** du formulaire d'édition d'un item de sous-liste
/// (modes `compact` et `tags` — les seuls qui ouvrent un formulaire par item).
///
/// Extension **additive** `const` (invariant AD-4, jamais `sealed`), valeurs en
/// camelCase. C'est une **déclaration de données**, pas un builder : la forme
/// choisie est une propriété de la sous-liste, au même titre que son mode
/// d'affichage — un hôte qui veut fabriquer lui-même la surface a déjà, pour
/// cela, le crochet CRUD et les seams de présentation.
///
/// - [dialog] (**défaut**, rétro-compat stricte) : `AlertDialog` centré. Le
///   rendu, les libellés et la géométrie sont **inchangés** — un hôte qui ne
///   déclare rien ne voit strictement rien bouger.
/// - [sheet] : **feuille modale** ancrée en bas (`showModalBottomSheet`,
///   `isScrollControlled`), utile quand le sous-formulaire est long sur une
///   surface étroite : elle occupe la hauteur disponible au lieu d'être bornée
///   par la boîte de dialogue.
/// - [page] : **page entière** poussée sur le `Navigator` (`MaterialPageRoute`),
///   avec barre de titre et bouton de retour système — la seule forme qui
///   laisse un sous-formulaire riche respirer, et la seule qui survive
///   proprement à l'ouverture du clavier sur mobile.
///
/// **Les trois formes rendent la MÊME donnée.** Le corps du formulaire, la
/// liste des sous-champs et la construction de la `Map` rendue à la validation
/// sont **partagés** : seule l'enveloppe (chrome) diffère. Ce n'est pas une
/// promesse de documentation, c'est une propriété de structure — il n'existe
/// qu'un seul chemin de sortie de données.
///
/// **Défensivité (invariant AD-10)** : une forme qui ne peut pas être montée
/// (aucun `Navigator` au-dessus du champ) n'ouvre rien et **ne lève pas** ;
/// l'incident est signalé à `FlutterError.reportError`, jamais avalé et jamais
/// fatal au rendu du formulaire parent.
enum ZSubItemFormPresentation {
  /// Boîte de dialogue centrée (`AlertDialog`) — **défaut**, rendu inchangé.
  dialog,

  /// Feuille modale ancrée en bas (`showModalBottomSheet`).
  sheet,

  /// Page entière poussée sur le `Navigator` (`MaterialPageRoute`).
  page,
}

/// Config triviale pur-cœur des champs **sous-liste** (`subItems`) et **item
/// dynamique** (`dynamicItem`).
///
/// [itemFields] est le **sous-schéma `const`** d'un item (chaque item est édité
/// par un sous-formulaire imbriqué). [reorderable] active le réordonnancement
/// (monter/descendre) de la sous-liste ; sans effet pour `dynamicItem`
/// (cardinalité ≤ 1).
///
/// Additif, rétro-compat : [displayMode] choisit inline (défaut) vs compact ;
/// [summaryFields] liste **ordonnée** de `name` de sous-champs projetés en
/// colonnes/valeurs de résumé en mode compact (pur-données ; un titre/rendu
/// personnalisé passe par un **seam de présentation**, jamais par une closure
/// dans le domaine). Le réordonnancement reste une notion **inline**
/// ([reorderable] est sans effet en mode compact).
class ZSubListConfig extends ZFieldConfig {
  /// Construit une config de sous-liste `const`.
  const ZSubListConfig({
    this.itemFields = const <ZFieldSpec>[],
    this.reorderable = true,
    this.displayMode = ZSubListDisplayMode.inline,
    this.summaryFields = const <String>[],
    this.summaryColumns = const <ZSubListSummaryColumn>[],
    this.softDelete = false,
    this.creationTemplates = const <ZSubListItemTemplate>[],
    this.defaultNewItem = const <String, Object?>{},
    this.createNewTextKey,
    this.aclCollectionId,
    this.showSummaryHeaders = false,
    this.itemFormPresentation = ZSubItemFormPresentation.dialog,
  });

  /// Sous-schéma `const` d'un item (projeté 1:1 en sous-formulaire imbriqué).
  final List<ZFieldSpec> itemFields;

  /// Autorise le réordonnancement (monter/descendre) des items (`subItems`).
  final bool reorderable;

  /// Mode de rendu : [ZSubListDisplayMode.inline] (défaut, rétro-compat) ou
  /// [ZSubListDisplayMode.compact] (liste résumé + dialog par item).
  final ZSubListDisplayMode displayMode;

  /// Liste **ordonnée** des `name` de sous-champs affichés comme colonnes/
  /// valeurs de résumé en mode compact. Vide (défaut) → repli titre dérivé
  /// côté widget.
  ///
  /// Un `name` qui ne correspond à **aucun** `itemField` rend une cellule
  /// **vide** — comportement historique, délibérément **conservé**. La colonne
  /// qui doit afficher une valeur non saisie se déclare en [summaryColumns].
  final List<String> summaryFields;

  /// **Colonnes de résumé déclarées** (modes `compact` et `tags`).
  ///
  /// Vide (**défaut**) ⇒ ce sont les [summaryFields] qui gouvernent le résumé,
  /// **à l'identique** : aucune colonne déclarée, aucune allocation, aucun
  /// changement de rendu.
  ///
  /// Non vide ⇒ cette liste **remplace** [summaryFields] (elle ne s'y ajoute
  /// pas) : deux sources de colonnes qui fusionneraient rendraient impossible
  /// de **retirer** une colonne, et feraient d'un même résumé deux
  /// déclarations à tenir d'accord.
  ///
  /// ## Ce qu'elle apporte, et pourquoi ce n'est PAS un second sous-schéma
  ///
  /// Une colonne n'est pas un champ : elle **désigne une valeur de l'item** et
  /// dit comment l'afficher. C'est la différence avec le moteur legacy, qui
  /// tenait deux listes parallèles (`subItemsFieldsBuilder` pour les colonnes,
  /// `subItemsFormFieldsBuilder` pour les champs) et pouvait donc les laisser
  /// diverger.
  ///
  /// Deux cas, un seul mécanisme :
  /// - [ZSubListSummaryColumn.name] **est** un `itemField` ⇒ la valeur vient de
  ///   sa tranche, projetée exactement comme aujourd'hui (libellé de choix,
  ///   port de date) ;
  /// - [ZSubListSummaryColumn.name] n'est **pas** un `itemField` ⇒ la valeur
  ///   est lue dans la **donnée de l'item** (le résidu hors sous-schéma, celui
  ///   que la graine du parent ou une issue `replace` du crochet CRUD y ont
  ///   déposé). La colonne s'affiche donc **sans** que le champ devienne
  ///   saisissable : le formulaire d'item ne rend que les `itemFields`, et
  ///   aucune tranche n'est allouée pour elle.
  ///
  /// C'est le cas mesuré des **lignes d'un document** : « Montant HT » et
  /// « Montant TTC » sont calculés par le crochet CRUD, déposés dans l'item, et
  /// **affichés sans jamais être saisis**.
  final List<ZSubListSummaryColumn> summaryColumns;

  /// **Soft-delete/restore** : quand `true`, la suppression d'un item (mode
  /// compact) le **marque supprimé** (exclu de l'agrégation parent) **sans le
  /// retirer** de la session → une action **restaurer** le rétablit (invariant
  /// AD-9). `false` (défaut) ⇒ suppression **définitive** (rétro-compat). Sans
  /// effet en mode inline (suppression toujours définitive).
  final bool softDelete;

  /// **Gabarits de création**. Non vide ⇒ le bouton « ajouter » (mode compact)
  /// devient un **menu** offrant un item par gabarit, chacun **pré-remplissant**
  /// le dialog de création avec ses [ZSubListItemTemplate.defaults]. Vide
  /// (défaut) ⇒ un seul bouton « ajouter » (rétro-compat).
  final List<ZSubListItemTemplate> creationTemplates;

  /// **Valeurs par défaut** d'un nouvel item (pur-données `const`). Amorce le
  /// `ZFormController` d'un item créé (mode compact **et** inline). Vide
  /// (défaut) ⇒ item vide (rétro-compat).
  ///
  /// ## 🔴 Les clés HORS sous-schéma sont désormais CONSERVÉES
  ///
  /// **C'est une rupture de comportement, et elle est assumée.** Auparavant,
  /// une clé de cette carte (ou des [creationTemplates]) que les [itemFields]
  /// **ne déclarent pas** était **perdue** à la création : le formulaire d'item
  /// n'alloue une tranche que pour les champs déclarés, et l'item créé était
  /// recomposé à partir de ces seules tranches. Une charge utile de gabarit —
  /// `{'type': 'depotageDebut'}` sur une timeline dont le type n'est pas un
  /// champ saisissable — n'atteignait donc **jamais** la donnée.
  ///
  /// Ce n'était pas un détail : c'est précisément la charge que le moteur
  /// legacy faisait voyager (`option.data`), et sans elle un item créé depuis
  /// un gabarit était indiscernable d'un item créé à vide.
  ///
  /// Désormais, ces clés rejoignent le **résidu hors sous-schéma** du nouvel
  /// item — le même mécanisme qui préserve déjà l'`id` d'un item venu du parent
  /// — et sont réémises vers la tranche parente, **avant** les tranches (une
  /// clé déclarée l'emporte donc toujours sur son homonyme du gabarit).
  ///
  /// **Périmètre exact de la rupture** : uniquement un hôte qui (1) déclare
  /// [defaultNewItem] ou [creationTemplates], (2) avec au moins une clé absente
  /// des [itemFields], (3) en mode `compact` ou `tags`, (4) à la **création**.
  /// Hors de cette intersection, la donnée produite est identique au **byte
  /// près** : `_unmappedOf` d'une graine sans clé étrangère rend la constante
  /// vide, et rien de plus n'est écrit.
  final Map<String, Object?> defaultNewItem;

  /// **Clé l10n** du libellé du bouton de création. `null` (défaut) ⇒ libellé
  /// générique `addItem`.
  final String? createNewTextKey;

  /// **Discriminant de collection ACL des lignes** de cette sous-liste,
  /// transmis à `ZAcl.can(action, collectionId:)`.
  ///
  /// C'est **aussi l'interrupteur** de la garde ACL, et c'est délibéré : câbler
  /// le scope inconditionnellement déplacerait un hôte passif — une app qui
  /// pose déjà une ACL restrictive au scope verrait ses boutons de sous-liste
  /// disparaître sans avoir rien demandé.
  ///
  /// Donc : `null` (**défaut**) ⇒ l'ACL du scope **n'est pas consultée**,
  /// comportement strictement inchangé. Non `null` ⇒ le dispatcher passe
  /// `ZcrudScope.acl` **et** ce discriminant à la sous-liste, qui filtre alors
  /// réellement ses actions de ligne. Pur-données `const` (aucune closure —
  /// invariants AD-3/AD-14) ; sans effet en mode `inline` (qui n'a pas
  /// d'actions gatées).
  final String? aclCollectionId;

  /// **En-têtes de colonnes** du résumé (mode compact).
  ///
  /// **Opt-in**, et c'est délibéré : activer les en-têtes change la **hauteur**
  /// de la table ET la **mise en page des cellules** chez tout hôte en mode
  /// compact. `false` (**défaut**) ⇒ rendu strictement inchangé.
  ///
  /// `true` ⇒ (1) une ligne d'en-tête reprenant le `label` (résolu l10n) de
  /// chaque `ZFieldSpec` de [summaryFields] est rendue au-dessus des lignes ;
  /// (2) les cellules passent d'un défilement horizontal **par ligne** à des
  /// **colonnes de largeur égale** (`Expanded` + ellipse). Ce second point n'est
  /// pas cosmétique : des cellules de largeur intrinsèque défilant chacune
  /// indépendamment ne s'alignent JAMAIS sous un en-tête — l'en-tête mentirait.
  /// Le texte tronqué reste atteignable par le dialog consulter/modifier.
  ///
  /// ## Sur une surface étroite, la table se replie
  ///
  /// Des colonnes de largeur égale ne tiennent que si la largeur suffit. En
  /// deçà, la sous-liste **empile** chaque ligne en couples libellé/valeur : la
  /// valeur est alors rendue en entier (elle revient à la ligne au lieu d'être
  /// coupée) et le libellé qui coiffait la colonne **descend dans la ligne**,
  /// la ligne d'en-têtes s'effaçant avec elle — il n'y a donc jamais d'en-tête
  /// au-dessus d'un empilement.
  ///
  /// Le basculement est **mesuré**, pas déclaré : la table est conservée tant
  /// que la largeur restante — actions de ligne et marges déduites — laisse à
  /// chaque colonne au moins la largeur minimale lisible du thème
  /// (`ZcrudTheme.subListColumnMinWidth`, dérivée de `readRowLabelWidth`, 160
  /// par défaut). Le repli vaut en consultation **comme** en saisie : il ne se
  /// déclenche que là où la table ne délivrait plus rien.
  ///
  /// ⇒ à réserver à un petit nombre de colonnes : au-delà, la table se repliera
  /// sur la plupart des téléphones. Une vraie grille (colonnes dimensionnées,
  /// tri, défilement synchronisé) relève de `zcrud_list`.
  final bool showSummaryHeaders;

  /// **Forme de présentation** du formulaire d'édition d'un item (voir
  /// [ZSubItemFormPresentation]). Défaut [ZSubItemFormPresentation.dialog] ⇒
  /// rendu strictement inchangé.
  ///
  /// Sans effet en mode `inline` (qui n'ouvre aucun formulaire par item : ses
  /// sous-champs sont déballés dans la carte).
  final ZSubItemFormPresentation itemFormPresentation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSubListConfig &&
          runtimeType == other.runtimeType &&
          reorderable == other.reorderable &&
          displayMode == other.displayMode &&
          softDelete == other.softDelete &&
          createNewTextKey == other.createNewTextKey &&
          aclCollectionId == other.aclCollectionId &&
          showSummaryHeaders == other.showSummaryHeaders &&
          itemFormPresentation == other.itemFormPresentation &&
          _listEquals(itemFields, other.itemFields) &&
          _listEquals(summaryFields, other.summaryFields) &&
          _listEquals(summaryColumns, other.summaryColumns) &&
          _listEquals(creationTemplates, other.creationTemplates) &&
          _mapEquals(defaultNewItem, other.defaultNewItem);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        reorderable,
        displayMode,
        softDelete,
        createNewTextKey,
        aclCollectionId,
        showSummaryHeaders,
        itemFormPresentation,
        Object.hashAll(itemFields),
        Object.hashAll(summaryFields),
        Object.hashAll(summaryColumns),
        Object.hashAll(creationTemplates),
        Object.hashAllUnordered(
          defaultNewItem.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}

/// **Colonne de résumé** d'une sous-liste — pur-données `const` (invariants
/// AD-3/AD-14 : aucune closure), déclarée dans `ZSubListConfig.summaryColumns`.
///
/// Elle **désigne une valeur** de l'item ([name]) et dit comment l'afficher.
/// Elle ne déclare **pas un champ** : rien n'est saisissable de son fait, aucune
/// tranche n'est allouée, le formulaire d'item reste celui des `itemFields`.
///
/// ## Périmètre de mise en forme — BORNÉ, et volontairement
///
/// Une colonne calculée sans mise en forme est à moitié utile : un montant rendu
/// « 1500.0 » à côté d'une quantité rendue « 3 » n'apprend pas grand-chose. Deux
/// réglages, pas trois :
/// - [decimals] — nombre de décimales **fixe** (`toStringAsFixed`), appliqué au
///   seul cas où la valeur est un `num` ;
/// - [suffixKey] — **clé l10n** d'un suffixe accolé à la valeur (« % », un
///   symbole monétaire, une unité). Jamais un libellé codé en dur (FR-26).
///
/// **Ce qui n'est PAS livré, et qu'il ne faut pas croire livré** :
/// - aucun **formatage monétaire localisé** (séparateur de milliers, position du
///   symbole, cadrage comptable) : cela demande un port de formatage, que ce
///   socle n'a pas — le `isCurrency` du moteur legacy n'est donc **pas** porté,
///   seulement son effet visible le plus simple (décimales + suffixe) ;
/// - aucun **suffixe dérivé de l'item** (le `suffixBuilder(item)` legacy, qui
///   lisait l'unité de stock d'une ligne) : c'est une closure, elle ne peut pas
///   vivre dans le domaine. Une colonne dont le suffixe varie par item se rend
///   par le canal de seams (`itemTransformer` ou `itemBuilder`) ;
/// - aucun **alignement de colonne** ni largeur : la géométrie du résumé reste
///   celle du socle (colonnes égales ou empilement mesuré).
class ZSubListSummaryColumn {
  /// Construit une colonne de résumé `const`.
  const ZSubListSummaryColumn({
    required this.name,
    this.labelKey,
    this.labelFallback,
    this.decimals,
    this.suffixKey,
    this.suffixFallback,
  });

  /// Clé de la valeur affichée, dans l'item.
  ///
  /// Si elle nomme un `itemField`, la valeur vient de sa **tranche** (et garde
  /// toutes les projections d'affichage : libellé de choix, port de date). Sinon
  /// elle est lue dans la **donnée de l'item** — une valeur **non éditable**,
  /// typiquement calculée par le crochet CRUD.
  final String name;

  /// Clé l10n du **libellé d'en-tête** de la colonne (repli [labelFallback],
  /// puis le `label` de l'`itemField` de même nom, puis [name]).
  ///
  /// Indispensable pour une colonne **calculée** : n'ayant pas de `ZFieldSpec`,
  /// elle n'a pas de libellé à emprunter — sans cette clé, l'en-tête afficherait
  /// le nom technique.
  final String? labelKey;

  /// Repli affiché quand [labelKey] n'est résolue nulle part.
  final String? labelFallback;

  /// Nombre **fixe** de décimales (`toStringAsFixed`). `null` (défaut) ⇒ la
  /// valeur est rendue telle quelle, exactement comme aujourd'hui. Sans effet
  /// sur une valeur qui n'est pas un `num` (invariant AD-10 : une donnée d'une
  /// autre forme s'affiche, elle ne fait pas échouer la cellule).
  final int? decimals;

  /// Clé l10n du **suffixe** accolé à la valeur, séparé par une espace
  /// insécable (« 1 500,00 F », « 12 % »). `null` (défaut) ⇒ aucun suffixe.
  /// Non appliqué à une cellule **vide** : un suffixe seul n'apprend rien.
  final String? suffixKey;

  /// Repli affiché quand [suffixKey] n'est résolue nulle part.
  final String? suffixFallback;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSubListSummaryColumn &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          labelKey == other.labelKey &&
          labelFallback == other.labelFallback &&
          decimals == other.decimals &&
          suffixKey == other.suffixKey &&
          suffixFallback == other.suffixFallback;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        name,
        labelKey,
        labelFallback,
        decimals,
        suffixKey,
        suffixFallback,
      );
}

/// **Gabarit de création** d'un item de sous-liste. Pur-données `const`
/// (invariants AD-3/AD-14 : aucune closure) : [labelKey] (clé l10n du libellé
/// de menu) + [defaults] (valeurs pré-remplies du nouvel item, fusionnées
/// **par-dessus** `ZSubListConfig.defaultNewItem`).
///
/// ## Le gabarit choisi ATTEINT le crochet CRUD
///
/// Le gabarit sélectionné est transmis tel quel à `ZSubItemCrudRequest.template`
/// (`null` pour un ajout sans gabarit). C'est l'équivalent exact du `{option}`
/// que le moteur legacy passait à `onCrudSubItem(item, Crud.create, state,
/// {option})`, et sans lui la charge utile d'un gabarit — le `{"type": …}` d'une
/// timeline, par exemple — n'atteignait le crochet que **fondue dans la graine**,
/// donc indiscernable d'une saisie de l'utilisateur.
///
/// [defaults] sert **deux** rôles, et c'est délibéré : les clés qui appartiennent
/// au sous-schéma **pré-remplissent** le formulaire ; les autres sont une
/// **charge utile** qui voyage avec l'item (voir la note de rupture de
/// `ZSubListConfig.defaultNewItem`). Le legacy séparait `value`/`data` du
/// libellé ; les fondre en un seul porteur évite d'avoir à choisir lequel des
/// deux le socle doit écrire.
class ZSubListItemTemplate {
  /// Construit un gabarit `const`.
  const ZSubListItemTemplate({
    required this.labelKey,
    this.id,
    this.labelFallback,
    this.defaults = const <String, Object?>{},
    this.opensForm = true,
  });

  /// Clé l10n de l'entrée de menu de création (repli [labelFallback], puis la
  /// clé elle-même). **Jamais un libellé codé en dur** (invariant FR-26).
  final String labelKey;

  /// Repli affiché quand [labelKey] n'est résolue nulle part — même contrat que
  /// `ZSubItemMenuOption.labelFallback`. `null` (défaut) ⇒ la clé elle-même
  /// s'affiche, comme avant.
  final String? labelFallback;

  /// Identité **stable** et optionnelle du gabarit, à l'usage du crochet
  /// (`ZSubItemCrudRequest.template?.id`).
  ///
  /// Elle existe parce qu'un gabarit **dérivé de l'état du formulaire parent**
  /// est reconstruit à chaque résolution : comparer par identité d'objet y
  /// serait faux, et comparer par [labelKey] ferait dépendre une décision
  /// métier d'un libellé traduisible. `null` (défaut) ⇒ le crochet lit
  /// [defaults], comme le faisait le legacy avec `option.data`.
  final String? id;

  /// Valeurs pré-remplies du nouvel item (pur-données `const`).
  final Map<String, Object?> defaults;

  /// Ce gabarit ouvre-t-il le **formulaire d'item** avant de créer ?
  ///
  /// `true` (**défaut**, rétro-compat stricte) : le formulaire s'ouvre
  /// pré-rempli, et le crochet arbitre ce que l'utilisateur a validé.
  ///
  /// `false` : l'item est créé **directement** depuis [defaults], sans aucune
  /// saisie — le crochet est appelé avec la graine du gabarit et c'est lui qui
  /// fabrique l'item (issue `replace`), ou la graine passe telle quelle
  /// (`proceed`), ou rien n'est créé (`veto`).
  ///
  /// **Pourquoi ce commutateur existe** : c'est le comportement du geste
  /// legacy, et il n'était pas atteignable autrement. Le menu d'ajout du moteur
  /// legacy appelait `onCrud(..., Crud.create, option: choisi)` **sans ouvrir
  /// de formulaire** — un « ajouter l'événement *Début du dépotage* » n'a rien
  /// à faire saisir : son type vient du gabarit, son horodatage et son auteur
  /// du moment du clic. Sans ce commutateur, un hôte devrait déclarer un
  /// sous-schéma vide pour n'obtenir qu'une boîte de dialogue à deux boutons.
  ///
  /// Sans effet sur le bouton `+` simple (aucun gabarit n'est choisi) : lui
  /// ouvre toujours le formulaire.
  final bool opensForm;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSubListItemTemplate &&
          runtimeType == other.runtimeType &&
          labelKey == other.labelKey &&
          id == other.id &&
          labelFallback == other.labelFallback &&
          opensForm == other.opensForm &&
          _mapEquals(defaults, other.defaults);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        labelKey,
        id,
        labelFallback,
        opensForm,
        Object.hashAllUnordered(
          defaults.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}

/// Égalité **profonde** de deux maps (pur-Dart — évite `package:collection`,
/// invariant AD-1).
bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Égalité **profonde** de deux listes (pur-Dart — évite `package:collection`,
/// invariant AD-1).
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
