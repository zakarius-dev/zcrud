/// `ZStepIndexStore` — **seam de persistance NEUTRE** de l'étape courante d'un
/// [ZStepperEdition] (« reprise »).
///
/// ## Le besoin, nommé
///
/// Un formulaire long en 5 étapes abandonné à l'étape 4 rouvre à l'étape 1 :
/// l'utilisateur re-traverse tout ce qu'il avait déjà rempli. Les états
/// **de saisie** survivent déjà (le `ZFormController` est possédé par l'hôte) —
/// c'est la **position dans le parcours** qui était perdue, et elle seule.
///
/// ## Pourquoi ce patron et pas un autre
///
/// 🔴 Ce fichier **réutilise le patron `ZSectionCollapseStore`** (repli persisté
/// des sections) plutôt que d'ouvrir un second canal de persistance : même
/// forme (`abstract` + `const`, `load`/`save`, clé de portée `formId` opaque),
/// même contrat, même variante mémoire pour les tests. Un hôte qui a déjà
/// branché GetStorage/shared_preferences pour les sections branche celui-ci
/// **de la même façon**, et `zcrud_core` ne tire toujours **aucune** dépendance
/// de stockage (AD-1, CORE OUT = 0).
///
/// ## Contrat
///
/// * **synchrone** et **défensif** : une implémentation qui lève ne casse pas
///   le stepper — l'appelant absorbe (AD-10) et retombe sur `initialStep` ;
/// * un index **hors bornes** est ignoré de la même façon (le nombre d'étapes
///   a pu changer entre deux sessions, notamment avec des étapes
///   conditionnelles) ;
/// * `null` ⇒ « rien de persisté », pas « étape 0 ».
///
/// Défaut : `ZStepperEdition.stepStore == null` ⇒ **aucune persistance**, donc
/// comportement historique **strictement inchangé**.
library;

/// Port de (dé)chargement de l'**index d'étape courant** d'un formulaire.
abstract class ZStepIndexStore {
  /// Contrat `const` (impls immuables).
  const ZStepIndexStore();

  /// Charge l'index d'étape persisté pour [formId] (`null` ⇒ portée globale).
  /// Rend `null` si rien n'est persisté. Ne lève **jamais** (AD-10).
  int? loadStepIndex(String? formId);

  /// Persiste l'[index] d'étape courant pour [formId]. Ne lève **jamais**.
  void saveStepIndex(String? formId, int index);
}

/// Store mémoire (défaut testable) : conserve l'étape courante **par `formId`**
/// pour la durée de vie de l'instance. Ne survit pas au redémarrage — la
/// persistance disque relève du binding/app, jamais du cœur.
class ZInMemoryStepIndexStore extends ZStepIndexStore {
  /// Construit un store mémoire vide.
  ZInMemoryStepIndexStore();

  final Map<String, int> _byForm = <String, int>{};

  String _key(String? formId) => formId ?? '__global__';

  @override
  int? loadStepIndex(String? formId) => _byForm[_key(formId)];

  @override
  void saveStepIndex(String? formId, int index) {
    _byForm[_key(formId)] = index;
  }
}
