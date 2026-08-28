/// Port d'**autorisation** neutre du domaine `zcrud_core`.
///
/// Aucune règle métier ne vit dans le cœur : l'ACL est fournie par l'app
/// hôte (AD-16, `ZAcl` app-supplied).
library;

import '../contracts/z_entity.dart';

/// Action CRUD soumise à autorisation. Valeurs en **camelCase** (canonique §5).
///
/// Ce vocabulaire n'est **pas clos** : une application gouverne ses propres
/// gestes par des clés ouvertes ([ZActionKey] libre + [ZKeyedAcl]), décidées
/// fail-closed par [ZAclActionKey.canAction]. L'enum reste le chemin typé des
/// verbes canoniques.
///
/// **Ordre ADDITIF, jamais réordonné/renommé** : les actions étendues
/// (`copy`…`move`) sont ajoutées **après** les cinq actions historiques
/// (`view`/`create`/`update`/`delete`/`restore`) pour couvrir des besoins
/// applicatifs plus riches (dupliquer, archiver, publier, vider, valider,
/// consulter l'historique) tout en gardant une rétro-compatibilité stricte.
///
/// **Sérialisation (posture additive/défensive — AD-3/AD-10)** : cet enum n'est
/// sérialisé **nulle part** aujourd'hui (aucun `@JsonKey`, aucun `toJson/fromJson`)
/// ⇒ aucune migration de données. **S'il** devenait sérialisé, la (dé)sérialisation
/// DOIT être défensive (`@JsonKey(unknownEnumValue: …)` ou `fromJsonSafe → null`),
/// les valeurs restant en **camelCase** (canonique §5) et l'évolution **additive
/// seulement** (nouvelles valeurs en fin d'enum).
///
/// **Consommateurs non exhaustifs** : les call-sites (`ZAcl.can`, le champ
/// `ZCrudAction? requiredPermission`) ne font AUCUN `switch` exhaustif — l'ajout
/// n'invalide aucune exhaustivité. Tout futur `switch (action)` DOIT porter une
/// branche `default` défensive (AD-10).
enum ZCrudAction {
  /// Consulter / lister.
  view,

  /// Créer une entité.
  create,

  /// Modifier une entité.
  update,

  /// Supprimer (soft-delete) une entité.
  delete,

  /// Restaurer une entité soft-deleted (corbeille).
  restore,

  /// Dupliquer une entité.
  copy,

  /// Archiver une entité.
  archive,

  /// Publier une entité.
  publish,

  /// Vider / réinitialiser une entité.
  clear,

  /// Valider une entité.
  validate,

  /// Consulter l'historique d'une entité.
  history,

  /// Déplacer une entité d'un conteneur à un autre (dossier, classeur…).
  move,
}

/// Classification **lecture / écriture** d'une action CRUD.
///
/// Un formulaire en mode **lecture seule** doit couper toutes les actions
/// d'**écriture** sans couper les actions de lecture (une consultation reste
/// légitime) : filtrer uniquement sur l'ACL ne suffit pas, il faut aussi une
/// classification explicite de la nature de chaque action.
///
/// Pur-Dart (couche `domain`) : aucune dépendance Flutter.
extension ZCrudActionMutation on ZCrudAction {
  /// `true` si l'action **modifie** la donnée (donc interdite en lecture seule).
  ///
  /// Seules [ZCrudAction.view] et [ZCrudAction.history] sont des actions de
  /// **lecture**. Toutes les autres écrivent — y compris [ZCrudAction.copy]
  /// (crée une entité), [ZCrudAction.validate] et [ZCrudAction.publish] (font
  /// transiter un état persisté).
  bool get mutatesData => switch (this) {
        ZCrudAction.view || ZCrudAction.history => false,
        ZCrudAction.create ||
        ZCrudAction.update ||
        ZCrudAction.delete ||
        ZCrudAction.restore ||
        ZCrudAction.copy ||
        ZCrudAction.archive ||
        ZCrudAction.publish ||
        ZCrudAction.clear ||
        ZCrudAction.validate ||
        ZCrudAction.move =>
          true,
      };
}

/// Clé d'action **ouverte** soumise à autorisation.
///
/// Le vocabulaire des actions n'est pas clos par [ZCrudAction] : une
/// application peut gouverner des gestes qui lui sont propres (générations
/// assistées, workflows métier…) avec la même matrice de droits que les verbes
/// canoniques. Une [ZActionKey] transporte ce droit sous forme de **clé
/// opaque** : le socle la véhicule de la déclaration au point de décision
/// **sans l'interpréter** — il ne sait pas ce que la clé signifie, et n'a pas
/// à le savoir.
///
/// Deux familles de clés :
/// * les **clés canoniques** — une par valeur de [ZCrudAction], de même nom
///   camelCase ([view]…[move]). Elles sont décidées par le chemin typé
///   existant ([ZAcl.can]) : une ACL déjà écrite les gouverne à l'identique,
///   qu'elles arrivent par l'enum ou par la clé.
/// * les **clés libres** — n'importe quelle autre chaîne, déclarée par
///   l'application (`const ZActionKey('monGeste')`). Elles ne sont décidées
///   que par une ACL qui a **choisi** de les comprendre ([ZKeyedAcl]) ;
///   partout ailleurs, elles sont **refusées** (fail-closed).
///
/// **Sérialisation défensive** : une clé est une chaîne — si elle voyage en
/// persistance, une valeur inconnue à la relecture reste une [ZActionKey]
/// valide (opaque) et sera simplement refusée par une ACL qui ne la connaît
/// pas ; [asCrudAction] retourne `null` plutôt que d'échouer.
class ZActionKey {
  /// Construit une clé d'action à partir de sa chaîne opaque (`const`).
  const ZActionKey(this.key);

  /// Clé canonique équivalente à [action] (même nom camelCase).
  ZActionKey.of(ZCrudAction action) : key = action.name;

  /// Chaîne opaque de l'action. Convention : **camelCase**, comme les valeurs
  /// canoniques.
  final String key;

  /// Clé canonique « consulter / lister » ([ZCrudAction.view]).
  static const ZActionKey view = ZActionKey('view');

  /// Clé canonique « créer » ([ZCrudAction.create]).
  static const ZActionKey create = ZActionKey('create');

  /// Clé canonique « modifier » ([ZCrudAction.update]).
  static const ZActionKey update = ZActionKey('update');

  /// Clé canonique « supprimer » ([ZCrudAction.delete]).
  static const ZActionKey delete = ZActionKey('delete');

  /// Clé canonique « restaurer » ([ZCrudAction.restore]).
  static const ZActionKey restore = ZActionKey('restore');

  /// Clé canonique « dupliquer » ([ZCrudAction.copy]).
  static const ZActionKey copy = ZActionKey('copy');

  /// Clé canonique « archiver » ([ZCrudAction.archive]).
  static const ZActionKey archive = ZActionKey('archive');

  /// Clé canonique « publier » ([ZCrudAction.publish]).
  static const ZActionKey publish = ZActionKey('publish');

  /// Clé canonique « vider / réinitialiser » ([ZCrudAction.clear]).
  static const ZActionKey clear = ZActionKey('clear');

  /// Clé canonique « valider » ([ZCrudAction.validate]).
  static const ZActionKey validate = ZActionKey('validate');

  /// Clé canonique « consulter l'historique » ([ZCrudAction.history]).
  static const ZActionKey history = ZActionKey('history');

  /// Clé canonique « déplacer » ([ZCrudAction.move]).
  static const ZActionKey move = ZActionKey('move');

  // Index nom → valeur, construit une seule fois depuis l'enum lui-même :
  // aucune table parallèle à maintenir quand une valeur canonique s'ajoute.
  static final Map<String, ZCrudAction> _canonical =
      ZCrudAction.values.asNameMap();

  /// Valeur canonique équivalente, ou `null` si la clé est **libre** (ou
  /// inconnue — posture défensive AD-10 : jamais d'exception).
  ZCrudAction? get asCrudAction => _canonical[key];

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ZActionKey && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'ZActionKey($key)';
}

/// Port d'autorisation **synchrone** fourni par l'application hôte.
///
/// **Aucune règle métier** ne vit dans le cœur (AD-16) : l'implémentation
/// concrète (rôles, ACL par collection…) est fournie par l'app. Consommé
/// notamment pour filtrer les actions de ligne d'une liste.
///
/// Une ACL **asynchrone** (décision distante) est **différée** : le contrat
/// synchrone couvre le besoin immédiat (filtrage d'actions ligne).
abstract class ZAcl {
  /// Retourne `true` si [action] est autorisée sur la [target] optionnelle
  /// (ou la collection [collectionId]), `false` sinon. Décision **synchrone**.
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId});
}

/// Port d'autorisation à **vocabulaire ouvert** — opt-in de l'application.
///
/// Une ACL qui n'implémente que [ZAcl] gouverne les verbes canoniques
/// ([ZCrudAction]) ; toute clé **libre** lui est refusée d'office par
/// [ZAclActionKey.canAction] (fail-closed). Implémenter ce contrat est le
/// geste par lequel une application déclare : « je sais décider des clés qui
/// ne sont pas dans l'enum ».
///
/// [canKey] ne reçoit **que des clés libres** : les clés canoniques sont
/// toujours décidées par [ZAcl.can], que l'ACL soit ouverte ou non — une
/// même action ne peut pas avoir deux points de décision.
abstract class ZKeyedAcl implements ZAcl {
  /// Retourne `true` si l'action **libre** [actionKey] (clé opaque, jamais
  /// interprétée par le socle) est autorisée sur la [target] optionnelle (ou
  /// la collection [collectionId]), `false` sinon. Décision **synchrone**.
  ///
  /// Posture attendue des implémentations : **fail-closed** — une clé
  /// inconnue de la matrice de l'application doit être refusée, jamais
  /// accordée par défaut.
  bool canKey(String actionKey, {ZEntity? target, String? collectionId});
}

/// Décision d'autorisation sur une [ZActionKey], pour **toute** [ZAcl] —
/// y compris celles écrites avant l'ouverture du vocabulaire.
extension ZAclActionKey on ZAcl {
  /// Retourne `true` si [action] est autorisée sur la [target] optionnelle
  /// (ou la collection [collectionId]), `false` sinon.
  ///
  /// Routage, sans interprétation :
  /// 1. clé **canonique** → délégué à [ZAcl.can] avec la valeur
  ///    [ZCrudAction] équivalente — une ACL existante décide à l'identique ;
  /// 2. clé **libre** et ACL ouverte ([ZKeyedAcl]) → délégué à
  ///    [ZKeyedAcl.canKey] ;
  /// 3. clé **libre** et ACL fermée → **refusé** (`false`, fail-closed) :
  ///    une action qu'une ACL ne connaît pas n'est jamais accordée au motif
  ///    qu'elle n'était pas dans l'enum.
  bool canAction(ZActionKey action, {ZEntity? target, String? collectionId}) {
    final ZCrudAction? canonical = action.asCrudAction;
    if (canonical != null) {
      return can(canonical, target: target, collectionId: collectionId);
    }
    final ZAcl self = this;
    if (self is ZKeyedAcl) {
      return self.canKey(action.key,
          target: target, collectionId: collectionId);
    }
    return false;
  }
}

/// Implémentation **permissive** : autorise tout, sans condition.
///
/// ⚠️ Ce n'est **plus** le repli par défaut du socle (voir [ZDenyAllAcl]) :
/// c'est un **choix explicite** de développement, de prototype ou de test.
/// L'oubli d'une ACL ne doit jamais ouvrir tous les gestes ; la déclarer
/// permissive, si.
///
/// À déclarer nommément, au scope ou à l'écran :
///
/// ```dart
/// ZcrudScope(acl: const ZAllowAllAcl(), child: monEcran);
/// ZCrudScreen<Dossier>(acl: const ZAllowAllAcl(), /* … */);
/// ```
///
/// En production, remplacez-la par votre propre implémentation de [ZAcl]
/// (rôles, droits par collection…) : aucune règle métier ne vit dans le socle.
class ZAllowAllAcl implements ZKeyedAcl {
  /// Construit l'ACL permissive (`const`).
  const ZAllowAllAcl();

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) => true;

  /// Permissive aussi sur les clés **libres** : « autorise tout » couvre le
  /// vocabulaire ouvert, sinon un prototype déclaré permissif verrait ses
  /// gestes applicatifs refusés sans signal.
  @override
  bool canKey(String actionKey, {ZEntity? target, String? collectionId}) =>
      true;
}

/// Implémentation **refusante** : interdit tout, sans condition. C'est le
/// **repli par défaut** du socle quand aucune ACL n'a été déclarée.
///
/// ## Pourquoi un refus par défaut
///
/// Une application qui **oublie** de brancher son ACL doit voir *aucun* geste,
/// jamais *tous* les gestes. Un repli permissif transforme un oubli de câblage
/// en ouverture silencieuse de la création, de la modification, de la mise à la
/// corbeille et de la restauration — sans aucune erreur, sans aucun signal. Le
/// repli refusant transforme le même oubli en absence visible de boutons : le
/// défaut se voit à l'écran, immédiatement, et se corrige en une ligne.
///
/// ## Comment brancher une ACL réelle
///
/// Implémentez [ZAcl] avec vos règles, puis déclarez-la une fois pour tout un
/// sous-arbre :
///
/// ```dart
/// class MonAcl implements ZAcl {
///   const MonAcl(this.role);
///   final String role;
///
///   @override
///   bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) {
///     if (action == ZCrudAction.view) return true;
///     return role == 'admin';
///   }
/// }
///
/// ZcrudScope(acl: MonAcl(session.role), child: monEcran);
/// ```
///
/// Un écran peut aussi porter la sienne : `ZCrudScreen(acl: MonAcl(...))`
/// l'emporte alors sur celle du scope ambiant, pour ce seul écran.
///
/// ## Comment retrouver l'ancien comportement (développement / prototype)
///
/// Déclarez explicitement l'ACL permissive — c'est le geste que doit faire une
/// application qui s'appuyait, sciemment ou non, sur l'ancien repli :
///
/// ```dart
/// ZcrudScope(acl: const ZAllowAllAcl(), child: monEcran);
/// ```
///
/// Ce geste est **volontaire et lisible** dans le code de l'application : c'est
/// toute la différence avec un repli implicite.
class ZDenyAllAcl implements ZKeyedAcl {
  /// Construit l'ACL refusante (`const`).
  const ZDenyAllAcl();

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      false;

  @override
  bool canKey(String actionKey, {ZEntity? target, String? collectionId}) =>
      false;
}

/// Composition **restrictive** de deux autorisations : un geste n'est offert
/// que si [base] **et** [restriction] l'accordent tous les deux.
///
/// ## À quoi ça sert
///
/// Une autorisation se déclare souvent à plusieurs endroits : au scope de
/// l'application, à l'écran, puis à un onglet d'un écran segmenté. La question
/// est alors : que fait la déclaration la plus proche de l'usager ? Deux
/// réponses sont possibles, et une seule est sûre.
///
/// * *Remplacer* — l'onglet dit le dernier mot. Une déclaration d'onglet
///   trop généreuse **rouvre** alors un geste que l'application avait refusé,
///   sans qu'aucune erreur ne le signale.
/// * *Restreindre* — c'est **ce type**. Une déclaration plus proche ne peut
///   que **retirer** : elle affine un droit déjà accordé, jamais l'inverse.
///
/// L'intersection est la seule composition qui rende un élargissement
/// **inexprimable** : quoi que déclare la restriction, aucun geste refusé par
/// [base] ne peut réapparaître.
///
/// ```dart
/// // L'onglet « Archives » ne rend AUCUN geste : au mieux, il en retire.
/// final aclDeLOnglet = zRestrictAcl(aclDeLEcran, aclDeclareeSurLOnglet);
/// ```
class ZRestrictedAcl implements ZKeyedAcl {
  /// Compose [base] (l'autorisation héritée) et [restriction] (la déclaration
  /// la plus proche de l'usager) en **conjonction**.
  const ZRestrictedAcl(this.base, this.restriction);

  /// Autorisation **héritée** — celle du niveau supérieur (scope, écran).
  final ZAcl base;

  /// Autorisation **restreignante** — celle du niveau le plus proche
  /// (onglet, section). Elle ne peut que retirer.
  final ZAcl restriction;

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      base.can(action, target: target, collectionId: collectionId) &&
      restriction.can(action, target: target, collectionId: collectionId);

  /// Conjonction sur une clé **libre** : chaque côté décide par
  /// [ZAclActionKey.canAction] — un côté fermé au vocabulaire ouvert refuse
  /// donc la clé (fail-closed), et l'intersection reste inélargissable.
  @override
  bool canKey(String actionKey, {ZEntity? target, String? collectionId}) {
    final ZActionKey key = ZActionKey(actionKey);
    return base.canAction(key, target: target, collectionId: collectionId) &&
        restriction.canAction(key,
            target: target, collectionId: collectionId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZRestrictedAcl &&
          other.base == base &&
          other.restriction == restriction;

  @override
  int get hashCode => Object.hash(base, restriction);

  @override
  String toString() => 'ZRestrictedAcl($base ∩ $restriction)';
}

/// Restreint [base] par [restriction], en évitant d'emballer pour rien.
///
/// Retourne [base] tel quel quand aucune restriction n'est déclarée
/// (`restriction == null`) : une déclaration absente ne change rien, ni dans
/// un sens ni dans l'autre. Sinon, retourne la composition **conjonctive**
/// ([ZRestrictedAcl]) — le résultat n'accorde jamais plus que [base].
ZAcl zRestrictAcl(ZAcl base, ZAcl? restriction) =>
    restriction == null ? base : ZRestrictedAcl(base, restriction);
