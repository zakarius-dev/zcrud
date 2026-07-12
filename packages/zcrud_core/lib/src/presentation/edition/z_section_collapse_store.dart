/// `ZSectionCollapseStore` — **seam de persistance NEUTRE** de l'état de repli des
/// sections de `DynamicEdition` (MIN-2, parité DODLP « repli persistant par titre
/// via GetStorage »).
///
/// origine: DODLP persiste l'état plié/déplié de chaque section (par titre) dans
/// `GetStorage`, de sorte qu'il **survive au redémarrage**. Côté zcrud, l'état de
/// repli vit par défaut **en mémoire** (`_collapsed`, `ValueNotifier`), donc
/// éphémère. Ce port fournit une **frontière d'injection** (AD-1 : cœur OUT=0)
/// permettant à l'app/binding (DODLP → GetStorage, autres → shared_preferences…)
/// de brancher une persistance réelle — SANS tirer aucune dépendance de stockage
/// dans `zcrud_core`.
///
/// **Contrat** :
/// - synchrone et **pur** (jamais de throw — l'appelant `DynamicEdition` est
///   défensif : une impl fautive ne casse pas le formulaire) ;
/// - clé de portée = `formId` (opaque, fourni par l'hôte ; `null` ⇒ portée
///   « globale »). Les titres de section repliées sont l'unité persistée.
///
/// Défaut : aucune persistance (comportement historique **strictement inchangé**)
/// quand `DynamicEdition.collapseStore == null`.
library;

/// Port de (dé)chargement de l'ensemble des **titres de sections repliées**.
///
/// Implémentation concrète **déférée au binding/app** (GetStorage pour DODLP,
/// etc.) — le cœur n'en fournit qu'une variante mémoire ([ZInMemorySectionCollapseStore]).
abstract class ZSectionCollapseStore {
  /// Contrat `const` (impls immuables).
  const ZSectionCollapseStore();

  /// Charge les titres de sections **repliées** persistés pour [formId]
  /// (`null` ⇒ portée globale). Retourne un ensemble vide si rien n'est persisté.
  /// Ne lève **jamais** (AD-10).
  Set<String> loadCollapsed(String? formId);

  /// Persiste l'ensemble des titres de sections **repliées** [collapsed] pour
  /// [formId]. Ne lève **jamais** (AD-10).
  void saveCollapsed(String? formId, Set<String> collapsed);
}

/// Store mémoire (défaut testable) : conserve l'état de repli **par [formId]**
/// pour la durée de vie de l'instance. Utile aux tests et comme repli explicite ;
/// ne survit **pas** au redémarrage (la persistance disque relève du binding).
class ZInMemorySectionCollapseStore extends ZSectionCollapseStore {
  /// Construit un store mémoire vide.
  ZInMemorySectionCollapseStore();

  final Map<String, Set<String>> _byForm = <String, Set<String>>{};

  String _key(String? formId) => formId ?? '__global__';

  @override
  Set<String> loadCollapsed(String? formId) {
    final stored = _byForm[_key(formId)];
    return stored == null ? <String>{} : <String>{...stored};
  }

  @override
  void saveCollapsed(String? formId, Set<String> collapsed) {
    _byForm[_key(formId)] = <String>{...collapsed};
  }
}
