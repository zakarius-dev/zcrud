/// Port de **rendu réordonnable** du cœur `zcrud_core` (abstraction pure,
/// même patron que `ZListRenderer`/AD-8).
///
/// `zcrud_core` n'expose QUE cette abstraction. Les implémentations vivent
/// ailleurs :
///
/// | Implémentation | Paquet | Dépendance tirée |
/// |---|---|---|
/// | repli SDK maison | `zcrud_responsive` | aucune (Flutter seul) |
/// | paquet de l'écosystème | satellite dédié, opt-in | le paquet tiers |
/// | propre à l'hôte | l'application | ce qu'elle veut |
///
/// **Pourquoi ce port existe** : AD-1 ne contraint que `zcrud_core` — un
/// satellite peut dépendre d'un paquet tiers, à condition de le placer
/// **derrière une abstraction** et de garder un **défaut zéro-dépendance**.
/// Ce port en est l'application pour la réorganisation de collections.
///
/// Le défaut zéro-dépendance n'est pas une politesse : un consommateur qui ne
/// prend pas le satellite doit garder une capacité **fonctionnelle**, dégradée
/// au pire, jamais absente.
///
/// Imports limités à `package:flutter/widgets.dart` + types `zcrud_core` :
/// AUCUNE dépendance lourde, AUCUN gestionnaire d'état (garde
/// `presentation_purity_test.dart`).
library;

import 'package:flutter/widgets.dart';

import 'z_reorder_render_request.dart';

/// Abstraction de rendu d'une collection réordonnable à partir d'une
/// [ZReorderRenderRequest] **neutre**.
///
/// Injecté via `ZcrudScope.reorderRenderer`. Le cœur ne connaît QUE ce contrat :
/// aucun type du backend (paquet tiers ou non) n'apparaît dans sa signature.
///
/// **Contrat que toute implémentation doit tenir** — c'est ce qui les rend
/// interchangeables :
/// 1. **index linéaires** : `onReorder` reçoit des positions `0..n-1`, la grille
///    n'étant qu'une projection de cet ordre (cf. [ZReorderRenderRequest]) ;
/// 2. **voie non-gestuelle** : une alternative accessible à l'appui long/glisser
///    (AD-13) — sans quoi la capacité n'existe pas au lecteur d'écran ;
/// 3. **l'appelant est la source de vérité** : le renderer peut tenir un ordre
///    optimiste local, mais se resynchronise sur la liste reçue ;
/// 4. **AD-10** : un `onReorder` qui échoue restaure l'ordre affiché plutôt que
///    de laisser un état incohérent.
///
/// S'y ajoute une **capacité facultative** : ancrer le geste sur une poignée
/// (cf. [buildDragHandle]). Ne pas la tenir est un choix légitime — le contrat
/// ci-dessus, lui, ne se négocie pas.
abstract class ZReorderRenderer {
  /// Constructeur `const` pour permettre des renderers immuables/`const`.
  const ZReorderRenderer();

  /// Construit le widget réordonnable pour la [request] neutre fournie.
  Widget build(BuildContext context, ZReorderRenderRequest request);

  /// Enveloppe la **poignée de glissement** de l'item d'index [index] pour que
  /// le geste de réorganisation s'y ancre.
  ///
  /// L'appelant rend une poignée visible en tête de chaque item (glyphe, cible
  /// tactile, libellé sémantique) et la soumet ici : c'est le renderer — seul à
  /// connaître son chassis de geste — qui décide si un glissement amorcé sur
  /// cette poignée démarre la réorganisation.
  ///
  /// [context] appartient au sous-arbre du renderer : la poignée est construite
  /// par `ZReorderRenderRequest.itemBuilder`, que le renderer appelle
  /// lui-même. Une implémentation peut donc y retrouver sa propre machinerie
  /// (un `InheritedWidget` privé, un `State` ancêtre…) **sans qu'aucun de ses
  /// types n'apparaisse dans ce port**.
  ///
  /// **Ce qu'une implémentation qui l'honore doit garantir** :
  /// 1. **ancrer, et rien d'autre** : un glissement démarré sur le sous-arbre
  ///    retourné réorganise l'item [index] ;
  /// 2. **rendre [handle] inchangé** : ni taille, ni marge, ni décoration, ni
  ///    sémantique ajoutée ou retirée — la poignée reste celle de l'appelant,
  ///    qui porte déjà sa cible tactile et son libellé ;
  /// 3. **ne pas confisquer le reste** : le geste propre à l'item (appui long
  ///    ou autre) et la voie non gestuelle restent tels quels.
  ///
  /// **Ne pas l'honorer est légitime.** Un chassis dont l'API n'expose aucun
  /// déclencheur par poignée ne peut pas la tenir : il laisse alors ce défaut
  /// en place, la poignée reste une affordance visible et le glissement
  /// s'amorce par le geste de l'item. Rien ne lève, rien n'est masqué — et la
  /// voie non gestuelle (point 2 du contrat, AD-13) reste dans tous les cas le
  /// chemin qui rend la capacité atteignable au lecteur d'écran.
  ///
  /// **Défaut : l'identité.** [handle] est retourné tel quel, sans geste
  /// ajouté. C'est le comportement de toute implémentation qui ne redéfinit
  /// pas ce membre.
  Widget buildDragHandle(BuildContext context, int index, Widget handle) =>
      handle;
}
