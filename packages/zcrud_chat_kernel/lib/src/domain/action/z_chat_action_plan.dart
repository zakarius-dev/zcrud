/// Plan d'action, impact chiffré et **jeton de confirmation infalsifiable**.
///
/// CHAT-0b, décisions **D2** et **D6**.
///
/// ## 🔴 Pourquoi les trois types vivent dans CE fichier
///
/// Le constructeur de [ZChatConfirmedAction] est **privé** (`._`). En Dart, le
/// privé est à portée de **bibliothèque** : séparer ces types casserait la
/// garantie — [ZChatActionPlan] ne pourrait plus fabriquer le jeton, ou bien il
/// faudrait un constructeur public, ce qui rendrait le jeton **forgeable par
/// n'importe quel package hôte**. Le voisinage est donc **structurel**, pas
/// esthétique (garde **G-C2**).
///
/// ## Le protocole en deux temps
///
/// `isDestructive` **seul** est un drapeau consultatif : IFFD *savait* que
/// supprimer était destructeur, sa surface B (`:3886-3908`) ne le consultait
/// simplement pas. Le contrat n'expose donc pas un drapeau, il impose un
/// **protocole** :
///
/// 1. `dispatcher.prepare(action)` chiffre l'impact **AVANT** toute destruction
///    (patron `deleteMessagesAfter` de lex, qui **retourne le compte**) et rend
///    un [ZChatActionPlan] ;
/// 2. le **seul** moyen d'obtenir un [ZChatConfirmedAction] est une méthode du
///    plan : [ZChatActionPlan.proceedWithoutConfirmation] rend **`null`** quand
///    la confirmation est requise, [ZChatActionPlan.confirmedByUser] ne doit
///    être appelée **qu'après** l'accord réel de l'utilisateur ;
/// 3. `dispatcher.execute(jeton)` **refuse** un plan exigeant confirmation dont
///    le jeton n'est pas confirmé, **sans jamais toucher l'executor**.
///
/// ⚠️ **Limite assumée** : un hôte qui appelle [ZChatActionPlan.confirmedByUser]
/// **sans** avoir montré de dialogue **ment au contrat** — le socle ne peut pas
/// l'en empêcher. Ce qu'il garantit : (1) le raccourci sûr
/// ([ZChatActionPlan.proceedWithoutConfirmation]) est **refusé** sur une action
/// destructrice ; (2) le mensonge est **localisé et greppable** en un seul appel
/// nommé.
///
/// Ce qui reste **app-side** (AD-2/AD-13/FR-26) : le rendu du dialogue, ses
/// libellés, ses icônes, ses couleurs, et la **décision** de l'afficher. Le
/// domaine ne connaît aucun widget, aucun `BuildContext`.
/// ## 🔴 Le répartiteur est un `part` de CETTE bibliothèque, et c'est structurel
///
/// **Correction de fin d'epic (MAJEUR).** [ZChatActionPlan] avait un
/// constructeur **PUBLIC** : un hôte fabriquait `ZChatActionPlan(action: …,
/// impact: ZChatActionImpact())` de toutes pièces, obtenait un jeton par
/// [ZChatActionPlan.proceedWithoutConfirmation] et **exécutait sans qu'aucun
/// `estimateImpact` n'ait jamais été appelé** — un contournement complet du
/// protocole en deux temps, sur une action déclarée non destructrice par un
/// impact que personne n'avait chiffré. La dartdoc de [ZChatActionImpact]
/// (« aucun chemin d'exécution ne contourne un impact chiffré ») était donc
/// **fausse**.
///
/// Le constructeur est maintenant **privé** (`._`). En Dart le privé est à
/// portée de **bibliothèque** : pour que `ZChatActionDispatcher.prepare` — le
/// seul producteur légitime, celui qui `await` `estimateImpact` — puisse encore
/// le nommer, `z_chat_action_dispatcher.dart` est déclaré `part` d'ici. C'est
/// exactement l'argument qui colocalise déjà [ZChatConfirmedAction] avec sa
/// fabrique, étendu à la fabrique du plan lui-même. Le fichier du répartiteur
/// reste distinct sur disque, donc la garde **G-U1** (« les membres d'effet ne
/// sont invoqués que depuis `z_chat_action_dispatcher.dart` ») continue de
/// mordre à l'identique.
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_action.dart';
import 'z_chat_action_executor.dart';
import 'z_chat_action_failure.dart';
import 'z_chat_action_outcome.dart';

part 'z_chat_action_dispatcher.dart';

/// Impact **chiffré avant destruction** d'une action (D6).
///
/// Défaut IFFD n°1 : le pied de requête supprime question **et** réponse en
/// cascade ; la surface A confirme, la surface B non, et **aucune** ne dit
/// combien. Ici, aucun chemin d'exécution ne contourne un impact chiffré.
class ZChatActionImpact {
  /// Construit un impact.
  const ZChatActionImpact({
    this.affectedMessageCount = 0,
    this.posteriorMessageCount = 0,
    this.cascadesToRequestAndResponse = false,
  });

  /// Nombre total de messages touchés (cible comprise).
  final int affectedMessageCount;

  /// Nombre de messages **postérieurs** repris ou invalidés.
  final int posteriorMessageCount;

  /// `true` si la paire question/réponse est entraînée.
  final bool cascadesToRequestAndResponse;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatActionImpact &&
          affectedMessageCount == other.affectedMessageCount &&
          posteriorMessageCount == other.posteriorMessageCount &&
          cascadesToRequestAndResponse == other.cascadesToRequestAndResponse;

  @override
  int get hashCode => Object.hash(
        affectedMessageCount,
        posteriorMessageCount,
        cascadesToRequestAndResponse,
      );

  @override
  String toString() => 'ZChatActionImpact(affected: $affectedMessageCount, '
      'posterior: $posteriorMessageCount, '
      'cascade: $cascadesToRequestAndResponse)';
}

/// Plan d'une action : l'intention, son impact chiffré, son exigence de
/// confirmation **DÉRIVÉE**.
///
/// 🔴 `final class` : le plan n'est **pas** sous-classable. Un héritier pourrait
/// surcharger [requiresConfirmation] pour rendre `false` sur une suppression en
/// cascade et obtenir un jeton non confirmé — exactement le contournement que
/// D2 existe pour fermer.
final class ZChatActionPlan {
  /// 🔴 Constructeur **PRIVÉ** — la **seule** fabrique est
  /// `ZChatActionDispatcher.prepare`, qui `await` `estimateImpact` avant de
  /// l'appeler. Un plan ne peut donc pas exister sans un impact **réellement
  /// chiffré par l'executor de l'hôte** (D6). Le rendre public rouvrirait le
  /// contournement décrit dans l'en-tête de bibliothèque.
  ///
  /// [requiresConfirmation] n'est **jamais** un paramètre : il est dérivé, pour
  /// qu'aucun appelant ne puisse l'affaiblir.
  const ZChatActionPlan._({required this.action, required this.impact});

  /// Intention planifiée.
  final ZChatAction action;

  /// Impact chiffré **avant** exécution.
  final ZChatActionImpact impact;

  /// Exigence de confirmation — **dérivée**, jamais renseignée (D6).
  ///
  /// Vraie dès que l'action est destructrice, **ou** qu'elle cascade, **ou**
  /// qu'elle touche plus d'un message. Les trois branches sont nécessaires :
  /// ne garder que `isDestructive` laisserait passer une cascade Q+R non
  /// annoncée (garde **G-D1**).
  bool get requiresConfirmation =>
      action.isDestructive ||
      action.cascades ||
      impact.affectedMessageCount > 1;

  /// Raccourci **sûr** : rend un jeton **uniquement** si aucune confirmation
  /// n'est requise, **`null`** sinon.
  ///
  /// C'est la première ligne de défense : on ne peut pas court-circuiter une
  /// action destructrice — c'est une **contrainte de compilation**
  /// (`ZChatConfirmedAction?`), pas une discipline.
  ZChatConfirmedAction? proceedWithoutConfirmation() =>
      requiresConfirmation ? null : ZChatConfirmedAction._(this, false);

  /// Jeton confirmé — à n'appeler qu'**après** l'accord réel de l'utilisateur.
  ZChatConfirmedAction confirmedByUser() =>
      ZChatConfirmedAction._(this, true);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatActionPlan &&
          action == other.action &&
          impact == other.impact;

  @override
  int get hashCode => Object.hash(action, impact);

  @override
  String toString() => 'ZChatActionPlan(${action.verb}, $impact, '
      'requiresConfirmation: $requiresConfirmation)';
}

/// Jeton **infalsifiable** autorisant l'exécution d'une action.
///
/// 🔴 Constructeur **PRIVÉ** : aucun package hôte ne peut en fabriquer un. La
/// seule fabrique est [ZChatActionPlan] — donc on ne peut pas exécuter une
/// action destructrice sans être passé par `prepare` et par un impact chiffré.
final class ZChatConfirmedAction {
  const ZChatConfirmedAction._(this.plan, this.userConfirmed);

  /// Plan dont ce jeton est issu (porte l'action et l'impact).
  final ZChatActionPlan plan;

  /// `true` si l'hôte déclare avoir obtenu l'accord **réel** de l'utilisateur.
  final bool userConfirmed;

  /// Intention à exécuter.
  ZChatAction get action => plan.action;

  @override
  String toString() =>
      'ZChatConfirmedAction(${plan.action.verb}, confirmed: $userConfirmed)';
}
