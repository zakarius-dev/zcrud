/// `ZRelationCrudHandler` — **port neutre** du **CRUD inline** d'une entité liée
/// pour le champ `relation` + son registre instanciable `ZRelationCrudRegistry`
/// (AD-4).
///
/// Depuis un sélecteur de relation, un utilisateur peut vouloir **créer /
/// modifier / copier** l'entité liée sans quitter le formulaire ; à la
/// résolution, l'option créée/éditée est **auto-sélectionnée**. Ce mécanisme
/// est **généralisé en port pur** : le cœur ne connaît NI le formulaire
/// d'édition, NI un repository, NI aucun backend — il **n'affiche que les
/// boutons** (Créer dans le modal ; Modifier/Copier par option) et **appelle
/// le handler**, puis auto-sélectionne l'option résultante.
///
/// **NEUTRALITÉ (NON-NÉGOCIABLE, AD-1/AD-5)** : ce fichier est **pur-Dart**
/// (`dart:async` autorisé, AUCUN import Flutter/`cloud_firestore`/Hive/gestionnaire
/// d'état). **Aucune implémentation concrète ne vit dans le cœur** : l'app ou
/// le binding hôte implémente `ZRelationCrudHandler` — le **formulaire
/// d'édition** (dialog) **+ le repository** create/update/copy vivent
/// entièrement là-bas — et l'enregistre au runtime via
/// `ZcrudScope(relationCrudRegistry: registry)`.
///
/// **Contrat de retour (AD-5/AD-10)** : chaque opération retourne un
/// `Future<ZFieldChoice?>` = l'**option résultante** à auto-sélectionner, ou
/// `null` si annulé/échec. Le `Future` peut aussi être **en erreur** : le widget
/// le capture défensivement (aucune écriture, aucun crash).
///
/// ## Gestes offerts — trois droits, pas un seul (frontière ACL)
///
/// Les trois gestes se gouvernent **séparément** : [ZRelationCrudHandler.canCreate],
/// [ZRelationCrudHandler.canEdit], [ZRelationCrudHandler.canCopy]. Enregistrer un
/// handler n'ouvre plus forcément les trois boutons — un agent peut avoir le
/// droit de *modifier* un navire sans avoir celui d'en *créer* un, cas courant
/// d'une autorité calculée par rôle ∪ poste ∪ utilisateur. Les trois valent
/// `true` par défaut : **tout handler écrit avant cette capacité se comporte
/// exactement comme avant**.
///
/// **Frontière (NON-NÉGOCIABLE, AD-16)** : le socle **ne connaît pas** l'ACL de
/// l'hôte et ne veut pas la connaître. Les trois booléens sont **calculés par
/// l'implémentation du port**, qui a seule accès aux permissions de
/// l'application ; le paquet ne fait que les **lire**. C'est exactement la
/// frontière déjà tenue par `ZAcl` (app-supplied, injectée) et par
/// `ZCrudScreen.acl` : aucune règle métier ne descend ici, aucun type
/// applicatif ne remonte.
///
/// **Absent, pas inerte.** Un geste refusé n'est **pas rendu** : ni bouton, ni
/// icône, ni action sémantique — rien à atteindre. Un bouton laissé en place
/// qui ne fait rien (par exemple un `create()` qui rendrait `null`) est *plus
/// mauvais* qu'un bouton absent : l'usager clique, rien ne se passe, et rien ne
/// lui dit pourquoi.
///
/// **Pourquoi pas `ZActionAclMode` ici** — le vocabulaire existe déjà pour les
/// actions de **ligne de liste** (`hide` / `disable`), et il n'est pas
/// dupliqué : la relation en applique la seule sémantique `hide`, sans en faire
/// un paramètre. La raison est mesurable dans le type lui-même : le mode
/// `disable` de `ZResolvedRowAction` n'est défendable que parce que l'action
/// résolue porte, à côté de `enabled`, un `disabledReasonKey` **annoncé aux
/// lecteurs d'écran** — montrer un geste fermé n'a de valeur que si la surface
/// peut dire *pourquoi*. Les affordances Créer/Modifier/Copier d'un sélecteur
/// de relation n'ont aucun canal de motif. Offrir `disable` sans motif
/// produirait précisément le bouton inerte et muet que ce port refuse. Si un
/// jour un mode inerte est voulu pour la relation, il devra arriver **avec** sa
/// clé de motif (extension additive de `ZRelationConfig`), jamais par un simple
/// basculement de booléen.
///
/// **Lecture défensive (AD-10)** : le socle ne lit jamais `canCreate`/`canEdit`/
/// `canCopy` en direct — il passe par [ZRelationCrudOffer] (`offersCreate`/
/// `offersEdit`/`offersCopy`), qui capture un getter d'hôte **qui lève** et
/// retombe **en fermant** le geste. Un repli ouvrant transformerait un bug de
/// l'ACL hôte en autorisation silencieuse ; c'est la même posture que le repli
/// `ZDenyAllAcl` du socle.
library;

import 'dart:async';

import '../edition/z_field_choice.dart';
import '../registry/z_registry_error.dart';

/// Port **abstrait** (neutre) du CRUD inline d'une entité liée (`relation`).
/// Aucune impl concrète dans `zcrud_core` (form + repository → binding/app E7).
///
/// Chaque opération retourne l'**option résultante** (`ZFieldChoice`) à
/// sélectionner, ou `null` si l'utilisateur annule / l'opération échoue.
abstract class ZRelationCrudHandler {
  /// Constructeur `const` (impl concrètes immuables si possible).
  const ZRelationCrudHandler();

  /// `true` (défaut) si le geste **Créer** est offert à l'usager courant.
  ///
  /// Déclaré par l'implémentation hôte à partir de **son** ACL (le socle n'en
  /// connaît rien, AD-16). `false` ⇒ le bouton Créer n'est **pas rendu** — pas
  /// grisé, pas inerte : **absent**, donc inatteignable.
  ///
  /// **Getter, pas méthode à paramètre — et pourquoi.** `create` reçoit bien un
  /// `Map<String, Object?> context` (snapshot du filtre cross-champ), mais le
  /// droit, lui, se décide au grain du **couple usager × ressource liée** : un
  /// handler est résolu par `crudKey`, c'est-à-dire *par ressource*. Une
  /// signature `canCreate(context)` obligerait ses jumelles à prendre la valeur
  /// de l'option (`canEdit(value)`, `canCopy(value)`) pour rester symétriques
  /// des opérations — donc à faire **exécuter du code d'ACL hôte dans
  /// l'`itemBuilder` de la liste d'options, à chaque frame de défilement**
  /// (contraire à AD-2/SM-1), pour un besoin par-instance que le port ne
  /// constate nulle part. Le getter est stable le temps d'une feuille, lu une
  /// fois par construction, trivial à implémenter et à garder. Le choix reste
  /// **réversible dans le sens sûr** : une variante contextuelle pourra
  /// s'ajouter en additif, alors que retirer un paramètre serait cassant.
  ///
  /// **Non réactif, par construction** : les droits d'un usager ne changent pas
  /// pendant qu'un sélecteur est ouvert. La valeur est lue à la construction du
  /// rendu ; aucun abonnement, aucune invalidation.
  bool get canCreate => true;

  /// `true` (défaut) si le geste **Modifier** est offert à l'usager courant.
  /// Voir [canCreate] pour la doctrine (frontière ACL, absent ≠ inerte, getter).
  bool get canEdit => true;

  /// `true` (défaut) si le geste **Copier** est offert à l'usager courant.
  /// Voir [canCreate] pour la doctrine (frontière ACL, absent ≠ inerte, getter).
  ///
  /// ⚠️ Copier **crée** une entité : un hôte dont l'ACL refuse la création
  /// refuse en général aussi la copie. Les deux restent néanmoins **distincts**
  /// — le socle n'en déduit rien, il lit ce que l'hôte déclare.
  bool get canCopy => true;

  /// **Créer** une nouvelle entité liée. [context] = snapshot du filtre
  /// cross-champ (mêmes clés que `ZRelationConfig.filterKeys`) pour pré-remplir
  /// le form côté binding. Retourne l'option créée (auto-sélectionnée) ou `null`.
  Future<ZFieldChoice?> create(Map<String, Object?> context);

  /// **Modifier** l'entité identifiée par [value] (valeur opaque de l'option).
  /// Retourne l'option mise à jour (auto-sélectionnée) ou `null`.
  Future<ZFieldChoice?> edit(Object? value);

  /// **Copier** (dupliquer) l'entité identifiée par [value]. Retourne l'option
  /// copiée (auto-sélectionnée) ou `null`.
  Future<ZFieldChoice?> copy(Object? value);
}

/// Lecture **défensive** (AD-10) des gestes déclarés par un
/// [ZRelationCrudHandler] : ce que le handler *déclare* (`canCreate`…) vs ce que
/// la surface *offre* réellement (`offersCreate`…).
///
/// C'est la **seule voie** par laquelle le socle — et tout présentateur riche
/// enrôlé via `ZcrudScope.selectPresenter` — doit consulter les droits. Un
/// getter d'hôte qui **lève** (ACL pas encore chargée, session nulle, bug de
/// calcul) ne casse alors ni le rendu ni le formulaire : le geste est
/// simplement **fermé**.
///
/// **Le repli ferme, il n'ouvre jamais.** Retomber sur `true` transformerait un
/// incident de l'ACL hôte en autorisation silencieuse — exactement ce que le
/// repli `ZDenyAllAcl` du socle refuse par ailleurs.
extension ZRelationCrudOffer on ZRelationCrudHandler {
  /// `true` si le geste **Créer** doit être rendu (déclaration lue
  /// défensivement ; un getter qui lève ⇒ `false`).
  bool get offersCreate => _readDeclaration(() => canCreate);

  /// `true` si le geste **Modifier** doit être rendu (idem [offersCreate]).
  bool get offersEdit => _readDeclaration(() => canEdit);

  /// `true` si le geste **Copier** doit être rendu (idem [offersCreate]).
  bool get offersCopy => _readDeclaration(() => canCopy);

  /// `true` si **au moins un** des trois gestes est offert.
  ///
  /// Sert à décider si la présence d'un handler justifie encore d'imposer la
  /// surface qui portait ses boutons : un handler qui n'offre plus rien ne doit
  /// pas changer le rendu d'un champ (il n'a plus rien à y montrer).
  bool get offersAnyGesture => offersCreate || offersEdit || offersCopy;
}

/// Évalue une déclaration de droit hôte en **fermant** sur toute exception
/// (AD-10). Isolée ici pour qu'il n'existe **qu'un seul** endroit où le repli
/// est décidé.
bool _readDeclaration(bool Function() declaration) {
  try {
    return declaration();
  } catch (_) {
    return false;
  }
}

/// Registre **instanciable** de handlers CRUD de relation, discriminés par une
/// clé `String` (portée par `ZRelationConfig.crudKey`). Injecté via
/// `ZcrudScope.relationCrudRegistry` (AD-4 — **jamais** un singleton statique
/// mutable).
///
/// API alignée sur `ZRelationSourceRegistry`/`ZChoicesSourceRegistry`
/// (register/isRegistered/keys + lookup strict/défensif) : `sourceFor` **throw**
/// [ZUnregisteredTypeError] si absent (bug de configuration, AD-3) ;
/// `trySourceFor` retourne `null` (chemin défensif : aucun bouton CRUD, AD-10).
class ZRelationCrudRegistry {
  /// Construit un registre de handlers vide.
  ZRelationCrudRegistry();

  /// Nom logique du registre (messages d'erreur actionnables).
  static const String _name = 'ZRelationCrudRegistry';

  final Map<String, ZRelationCrudHandler> _handlers =
      <String, ZRelationCrudHandler>{};

  /// Enregistre le [handler] sous [key]. Collision → **`throw`**
  /// [ZDuplicateRegistrationError] (jamais un « last-wins » silencieux, AD-3).
  void register(String key, ZRelationCrudHandler handler) {
    if (_handlers.containsKey(key)) {
      throw ZDuplicateRegistrationError(kind: key, registryName: _name);
    }
    _handlers[key] = handler;
  }

  /// `true` si un handler est enregistré pour [key].
  bool isRegistered(String key) => _handlers.containsKey(key);

  /// Les clés actuellement enregistrées.
  Iterable<String> get keys => _handlers.keys;

  /// Lookup **strict** : le handler de [key], ou **`throw`**
  /// [ZUnregisteredTypeError] si absent (AD-3).
  ZRelationCrudHandler sourceFor(String key) {
    final handler = _handlers[key];
    if (handler == null) {
      throw ZUnregisteredTypeError(kind: key, registryName: _name);
    }
    return handler;
  }

  /// Lookup **défensif** : le handler de [key], ou `null` si absent (AD-10) —
  /// utilisé par le dispatcher pour n'afficher AUCUN bouton CRUD (rétro-compat).
  ZRelationCrudHandler? trySourceFor(String key) => _handlers[key];
}
