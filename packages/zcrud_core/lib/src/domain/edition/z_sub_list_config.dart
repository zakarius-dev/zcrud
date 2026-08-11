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
    this.softDelete = false,
    this.creationTemplates = const <ZSubListItemTemplate>[],
    this.defaultNewItem = const <String, Object?>{},
    this.createNewTextKey,
    this.aclCollectionId,
    this.showSummaryHeaders = false,
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
  final List<String> summaryFields;

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
  /// ⇒ à réserver à un petit nombre de colonnes. Une vraie grille (colonnes
  /// dimensionnées, tri, défilement synchronisé) relève de `zcrud_list`.
  final bool showSummaryHeaders;

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
          _listEquals(itemFields, other.itemFields) &&
          _listEquals(summaryFields, other.summaryFields) &&
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
        Object.hashAll(itemFields),
        Object.hashAll(summaryFields),
        Object.hashAll(creationTemplates),
        Object.hashAllUnordered(
          defaultNewItem.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}

/// **Gabarit de création** d'un item de sous-liste. Pur-données `const`
/// (invariants AD-3/AD-14 : aucune closure) : [labelKey] (clé l10n du libellé
/// de menu) + [defaults] (valeurs pré-remplies du nouvel item, fusionnées
/// **par-dessus** `ZSubListConfig.defaultNewItem`).
class ZSubListItemTemplate {
  /// Construit un gabarit `const`.
  const ZSubListItemTemplate({
    required this.labelKey,
    this.defaults = const <String, Object?>{},
  });

  /// Clé l10n (ou libellé brut en repli) de l'entrée de menu de création.
  final String labelKey;

  /// Valeurs pré-remplies du nouvel item (pur-données `const`).
  final Map<String, Object?> defaults;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSubListItemTemplate &&
          runtimeType == other.runtimeType &&
          labelKey == other.labelKey &&
          _mapEquals(defaults, other.defaults);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        labelKey,
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
