/// Config additive `const` des champs **sous-liste** (`subItems`) et **item
/// dynamique** (`dynamicItem`) — E3-3b-2 (mini-CRUD imbriqué, AD-2/AD-4).
///
/// origine: un champ `subItems` porte une **liste d'items** ; chaque item est un
/// `Map<String, dynamic>` édité par un **sous-formulaire imbriqué** (réutilise le
/// dispatcher `ZFieldWidget`). Le **sous-schéma** de l'item est décrit ici par un
/// `List<ZFieldSpec>` **pur-données `const`** ([itemFields]) — jamais une closure
/// ni un widget (couche `domain`, garde `domain_purity_test.dart`). Le champ
/// `dynamicItem` réutilise la même config (cardinalité ≤ 1).
///
/// **Point d'extension AD-4** : `const`, additif (sous-classe de [ZFieldConfig]),
/// jamais `sealed`. L'interprétation (schéma → widgets imbriqués) est E3-3b-2
/// (`ZSubListFieldWidget`/`ZDynamicItemFieldWidget`) ; ici on ne porte que la
/// **donnée** du sous-schéma.
///
/// Recoupement E4-5 (`ZSubListScreen`) : cette config décrit le **champ**
/// d'édition imbriqué (dans un formulaire) ; l'écran de sous-liste autonome
/// (mini-CRUD de niveau liste) est E4-5. Le sous-schéma `const` est la brique
/// commune réutilisable (à factoriser côté E4-5, pas dupliquée ici).
library;

import 'z_field_config.dart';
import 'z_field_spec.dart';

/// Mode de **rendu** d'une sous-liste (`subItems`) — DP-6 (parité DODLP, gap B8).
///
/// Extension **additive** `const` (AD-4, jamais `sealed`) : ajoute un mode sans
/// rien retirer. Valeurs en **camelCase** (canonique §5).
///
/// - [inline] (**défaut**, RÉTRO-COMPAT) : comportement E3-3b-2 — chaque item
///   déballe TOUS ses sous-champs en **sous-formulaire imbriqué** (mini-CRUD
///   inline). Aucun changement pour les configs existantes.
/// - [compact] : **liste résumé** (une ligne/valeurs de résumé par item) +
///   **dialog d'édition par item** (ajouter/consulter/modifier/supprimer),
///   chaque action **filtrée par `ZAcl`** — reproduit `DynamicSubListScreen`
///   (DODLP) sans imposer le déballage inline de tous les items.
enum ZSubListDisplayMode {
  /// Sous-formulaires imbriqués empilés (comportement historique E3-3b-2).
  inline,

  /// Liste résumé + dialog d'édition par item, actions gated `ZAcl` (DP-6).
  compact,
}

/// Config triviale pur-cœur des champs **sous-liste** (`subItems`) et **item
/// dynamique** (`dynamicItem`) — E3-3b-2.
///
/// [itemFields] est le **sous-schéma `const`** d'un item (chaque item est édité
/// par un sous-formulaire imbriqué). [reorderable] active le réordonnancement
/// (monter/descendre) de la sous-liste ; sans effet pour `dynamicItem`
/// (cardinalité ≤ 1).
///
/// DP-6 (additif, rétro-compat) : [displayMode] choisit inline (défaut) vs
/// compact ; [summaryFields] liste **ordonnée** de `name` de sous-champs
/// projetés en colonnes/valeurs de résumé en mode compact (pur-données ; un
/// titre/rendu personnalisé passe par un **seam de présentation**, jamais par
/// une closure dans le domaine — garde `domain_purity_test`). Le
/// réordonnancement reste une notion **inline** ([reorderable] est sans effet
/// en mode compact — parité DODLP : table sans reorder).
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
  });

  /// Sous-schéma `const` d'un item (projeté 1:1 en sous-formulaire imbriqué).
  final List<ZFieldSpec> itemFields;

  /// Autorise le réordonnancement (monter/descendre) des items (`subItems`).
  final bool reorderable;

  /// Mode de rendu (DP-6) : [ZSubListDisplayMode.inline] (défaut, rétro-compat)
  /// ou [ZSubListDisplayMode.compact] (liste résumé + dialog par item).
  final ZSubListDisplayMode displayMode;

  /// Liste **ordonnée** des `name` de sous-champs affichés comme colonnes/
  /// valeurs de résumé en mode compact (miroir des `fields` de
  /// `DynamicSubListScreen`). Vide (défaut) → repli titre dérivé côté widget.
  final List<String> summaryFields;

  /// DP-19 (M18) — **soft-delete/restore** : quand `true`, la suppression d'un
  /// item (mode compact) le **marque supprimé** (exclu de l'agrégation parent)
  /// **sans le retirer** de la session → une action **restaurer** le rétablit
  /// (parité `soft-delete/restore` DODLP, AD-9). `false` (défaut) ⇒ suppression
  /// **définitive** (comportement DP-6 strict, rétro-compat). Sans effet en mode
  /// inline (suppression toujours définitive).
  final bool softDelete;

  /// DP-19 (M18) — **gabarits de création** (parité `popUpMenuOptions` DODLP).
  /// Non vide ⇒ le bouton « ajouter » (mode compact) devient un **menu** offrant
  /// un item par gabarit, chacun **pré-remplissant** le dialog de création avec
  /// ses [ZSubListItemTemplate.defaults]. Vide (défaut) ⇒ un seul bouton
  /// « ajouter » (rétro-compat DP-6).
  final List<ZSubListItemTemplate> creationTemplates;

  /// DP-19 (M19) — **valeurs par défaut** d'un nouvel item (pur-données `const`,
  /// parité `defaultNewItem` DODLP). Amorce le `ZFormController` d'un item créé
  /// (mode compact **et** inline). Vide (défaut) ⇒ item vide (rétro-compat).
  final Map<String, Object?> defaultNewItem;

  /// DP-19 (M19) — **clé l10n** du libellé du bouton de création (parité
  /// `createNewText` DODLP). `null` (défaut) ⇒ libellé générique `addItem`.
  final String? createNewTextKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSubListConfig &&
          runtimeType == other.runtimeType &&
          reorderable == other.reorderable &&
          displayMode == other.displayMode &&
          softDelete == other.softDelete &&
          createNewTextKey == other.createNewTextKey &&
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
        Object.hashAll(itemFields),
        Object.hashAll(summaryFields),
        Object.hashAll(creationTemplates),
        Object.hashAllUnordered(
          defaultNewItem.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}

/// DP-19 (M18) — **Gabarit de création** d'un item de sous-liste (parité d'une
/// entrée de `popUpMenuOptions` DODLP). Pur-données `const` (AD-3/AD-14 : aucune
/// closure) : [labelKey] (clé l10n du libellé de menu) + [defaults] (valeurs
/// pré-remplies du nouvel item, fusionnées **par-dessus**
/// `ZSubListConfig.defaultNewItem`).
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
/// AD-1 out-degree 0).
bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Égalité **profonde** de deux listes (pur-Dart — évite `package:collection`,
/// AD-1 out-degree 0).
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
