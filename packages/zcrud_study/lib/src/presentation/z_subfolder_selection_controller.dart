/// `ZSubfolderSelectionController` — pilotage EXTERNE et optionnel de la
/// sélection de fratrie de `ZStudyFolderDetail`.
///
/// ## Le manque comblé
///
/// Sans ce contrôleur, un hôte qui veut *connaître* la sélection (pour titrer
/// une barre, filtrer un compteur, journaliser) ou la *commander* (depuis un
/// fil d'Ariane, une recherche, un lien profond) n'aurait qu'une option :
/// tenir une **seconde source de vérité** et la resynchroniser à la main —
/// donc accepter une divergence silencieuse entre ce que la barre montre et
/// ce que l'hôte croit sélectionné.
///
/// ## La forme retenue : le patron `ZDisplayState` de `zcrud_core`
///
/// Ce contrôleur n'invente rien : c'est le patron **déjà en production dans ce
/// package même** (`ZStudyToolsSectionSpec.expandController`), décliné sur
/// `String?` au lieu de `bool`. Ses cinq clauses s'appliquent telles
/// quelles — en particulier :
///
/// * **état interne par défaut** : `null` ⇒ `ZStudyFolderDetail` détient la
///   sélection exactement comme avant, rendu et cycle de vie **strictement
///   inchangés** (AD-4 : extension par point d'entrée, jamais par obligation) ;
/// * **le contrôleur EST la source de vérité**, jamais un miroir : lecture et
///   écriture le traversent, la page n'en garde aucune copie — deux états ne
///   peuvent donc pas diverger, parce qu'il n'y en a qu'un ;
/// * **possession hors `build` imposée** : le constructeur exige un
///   `ZDisplayStateOwner`, que l'hôte obtient en appliquant
///   `ZDisplayStateOwnerMixin` à son `State`. Un contrôleur créé dans `build`
///   lève une `FlutterError` nommant le contrôleur, au lieu de devenir
///   silencieusement inerte au premier rebuild ;
/// * **un contrôleur jamais consommé est détectable**
///   (`wasEverConsumed` — assert au `dispose` du mixin) : un fil d'Ariane câblé
///   sur un contrôleur orphelin ne peut pas passer pour branché.
///
/// ## Pourquoi `String?` et pas un index
///
/// La sélection de fratrie est **identitaire**, pas positionnelle : `null`
/// désigne l'item racine (« tous les sous-dossiers »), une chaîne désigne un
/// `ZSubfolderRef.id`. Un `ZIndexController` aurait fait dépendre la sélection
/// de l'**ordre** de la liste — or cet ordre est réordonnable
/// (`ZSubfolderNavSpec.onReorder`) : un réordonnancement aurait déplacé la
/// sélection sans que personne ne la change. C'est pourquoi ce type existe
/// plutôt qu'une réutilisation de `ZIndexController`.
library;

import 'package:zcrud_core/zcrud_core.dart' show ZDisplayStateController;

/// Contrôleur de la **sélection de sous-dossier** (`null` = item racine).
///
/// Se passe à `ZSubfolderNavSpec.selectionController`. Voir la doc de
/// bibliothèque pour le contrat complet et la précédence vis-à-vis de
/// `ZStudyFolderDetail.initialSelectedSubfolderId` (**le contrôleur prime**).
class ZSubfolderSelectionController extends ZDisplayStateController<String?> {
  /// Crée un contrôleur de sélection possédé par [owner].
  ///
  /// [initialValue] `null` (défaut) ⇒ item racine sélectionné.
  ZSubfolderSelectionController({
    required super.owner,
    super.initialValue,
    super.debugLabel,
  });

  /// Sélectionne le sous-dossier [id].
  void select(String id) => value = id;

  /// Revient à l'item RACINE (« tous les sous-dossiers »).
  ///
  /// Nommé plutôt que `value = null` pour que l'intention soit lisible sur le
  /// site d'appel : `null` est une **valeur métier** ici (la racine), pas une
  /// absence de valeur.
  void selectRoot() => value = null;
}
