/// Adaptateurs Firestore du catalogue de routeurs IA du chat.
///
/// ## La règle
///
/// Le repository Firestore générique de `zcrud_firestore`
/// (`FirebaseZRepositoryImpl`) sert l'entité `ZChatRouter` **sans adaptateur
/// spécifique** : le codec est celui du noyau, la forme sur le fil est la
/// forme canonique. Ce paquet est le **point d'accroche** — et rien de plus :
/// une fabrique qui branche le dépôt sur une collection, un codec legacy
/// optionnel pour une collection qui préexiste au dépôt, et la sémantique de
/// suppression choisie par l'hôte.
///
/// ## Dépendances
///
/// Puits du graphe : ce paquet dépend de `zcrud_core`, `zcrud_chat_kernel` et
/// `zcrud_firestore` ; rien n'en dépend. `zcrud_firestore` ne connaît pas le
/// chat — un consommateur Firestore sans chat n'en porte jamais le poids.
///
/// ## Démarrage
///
/// ```dart
/// final ZRepository<ZChatRouter> routers = buildChatRouterFirestoreRepository(
///   firestore: FirebaseFirestore.instance,
///   collectionPath: myRoutersCollection,
///   // Collection écrite avant ce dépôt, sans `is_deleted` :
///   deletionSemantics: ZDeletionSemantics.absentMeansAlive,
///   toCanonical: myLegacyCodec.toCanonical,
///   toLegacy: myLegacyCodec.toLegacy,
/// );
/// ```
library;

export 'src/data/z_chat_router_firestore_repository.dart';
