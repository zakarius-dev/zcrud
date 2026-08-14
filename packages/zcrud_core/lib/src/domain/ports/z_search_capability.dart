/// Capacité **déclarée** : ce dépôt sait-il servir `ZDataRequest.search` ?
///
/// Un dépôt reçoit un terme de recherche dans chaque requête. La plupart
/// savent le servir — un dépôt en mémoire, un backend SQL, un index
/// plein-texte. Certains non : Firestore n'a ni `LIKE`, ni recherche
/// plein-texte, ni pliage diacritique natif ; il **ignore** le terme et rend
/// le jeu entier. Vu de l'écran, la barre de recherche s'affiche, l'usager
/// tape, et rien n'est filtré : un terme sans correspondance rend **toute** la
/// liste, ce dont l'usager conclut que la liste ne contient pas ce qu'il
/// cherche. Une barre inerte est pire qu'une barre absente.
///
/// Rien, dans le port `ZRepository`, ne permettait de distinguer les deux cas :
/// l'assemblage **supposait** que la recherche était servie. Ce fichier
/// remplace la supposition par une **déclaration**, sur le modèle de
/// `ZPurgeable` : le dépôt dit ce qu'il ne sait pas faire, et le socle compose
/// avec au lieu de le nier.
library;

import '../contracts/z_entity.dart';

/// Déclare qu'un dépôt **ne sert pas** la recherche plein-texte et la
/// **délègue** au moteur du socle.
///
/// ## Pourquoi une capacité déclarée plutôt que devinée
///
/// Deviner reviendrait à reconnaître les adaptateurs par leur type ou leur nom
/// (« si c'est du Firestore, alors… ») : le cœur connaîtrait ses satellites,
/// ce qu'AD-1 interdit, et un dépôt d'application ayant la même limite ne
/// serait jamais reconnu. La déclaration inverse la charge — celui qui connaît
/// la limite est celui qui la porte.
///
/// ## Pourquoi un mixin plutôt qu'un membre du port
///
/// Ajouter `bool get servesSearch` à `ZRepository` casserait toute
/// implémentation hôte écrite avec `implements ZRepository<T>` : Dart exige
/// alors que **chaque** membre soit fourni, y compris ceux qui portent un
/// corps par défaut. Or c'est la forme la plus répandue (les décorateurs du
/// socle lui-même l'emploient). Un mixin **sans contrainte de superclasse**
/// s'applique à n'importe quel dépôt, et son **absence** est le comportement
/// historique : un dépôt qui ne l'applique pas est réputé servir la recherche,
/// exactement comme avant.
///
/// ## Comment le déclarer
///
/// ```dart
/// class MonDepotFirestore<T extends ZEntity> extends ZRepository<T>
///     with ZDelegatesSearch<T> {
///   // … le port, inchangé : aucun membre à ajouter.
/// }
/// ```
///
/// ## Ce que le socle en fait
///
/// `ZListController` interroge la capacité **au moment où une recherche est
/// active**. Si le dépôt la délègue, la requête part sans pagination et le
/// filtrage — recherche, portée de colonnes, pliage diacritique, tri — est
/// appliqué en mémoire par le moteur du socle, exactement comme sur le repli
/// d'un curseur non honoré. Sans recherche active, rien ne change : la
/// pagination curseur reste le chemin nominal.
///
/// ## Ce que ce chemin coûte
///
/// Servir la recherche en mémoire suppose de **lire le jeu entier** : une
/// lecture non paginée de la source à chaque terme saisi. C'est le prix d'une
/// recherche exacte sur un backend qui ne sait pas la faire, et il n'est
/// raisonnable que pour un listing dont les données tiennent en mémoire
/// (quelques milliers de lignes). Au-delà, la voie honnête est un **champ de
/// recherche normalisé pré-calculé** côté application, interrogeable par
/// égalité ou par préfixe — le dépôt sert alors la recherche et n'applique
/// pas ce mixin.
mixin ZDelegatesSearch<T extends ZEntity> {}

/// `true` si [repository] sert lui-même `ZDataRequest.search`.
///
/// C'est la lecture de la capacité [ZDelegatesSearch] : un dépôt qui ne la
/// déclare pas est réputé servir la recherche — le défaut historique, qui ne
/// change le comportement d'aucune implémentation existante. Le test porte sur
/// le mixin, jamais sur le type concret du dépôt : le cœur ne connaît aucun de
/// ses adaptateurs (AD-1).
///
/// ```dart
/// if (!zRepositoryServesSearch(repo)) {
///   // … filtrer en mémoire plutôt que d'offrir une recherche inerte.
/// }
/// ```
bool zRepositoryServesSearch(Object repository) =>
    repository is! ZDelegatesSearch;
