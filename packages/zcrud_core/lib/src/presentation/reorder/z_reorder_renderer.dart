/// Port de **rendu réordonnable** du cœur `zcrud_core` (abstraction pure —
/// AD-57, patron strict de `ZListRenderer`/AD-8).
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
/// **Pourquoi ce port existe** — une grille réordonnable avait d'abord été
/// écrite **à la main** au motif qu'un paquet tiers serait « refusé par AD-1 ».
/// C'était une sur-lecture : AD-1 ne contraint que `zcrud_core`, et quinze
/// satellites dépendaient déjà de paquets pub.dev. AD-57 fixe la règle — tiers
/// admis dans un satellite, **derrière une abstraction** et avec un **défaut
/// zéro-dépendance** — et ce port en est l'application.
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
abstract class ZReorderRenderer {
  /// Constructeur `const` pour permettre des renderers immuables/`const`.
  const ZReorderRenderer();

  /// Construit le widget réordonnable pour la [request] neutre fournie.
  Widget build(BuildContext context, ZReorderRenderRequest request);
}
