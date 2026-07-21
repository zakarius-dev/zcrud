/// Fabrique d'adapter **folder-scopé concret** `buildFolderScopedStudyRepository`
/// (Story ES-10.2, AC3/AC4 — AD-5/AD-9/AD-10/AD-11) : la surface `zcrud_firestore`
/// que `lex_douane` enregistrera au seam Riverpod pour la topologie **imbriquée**
/// `users/{uid}/{parentCollection}/{folderId}/{collection}`.
///
/// ## Composition MINCE des briques ES-3 — rien de réimplémenté
///
/// La fabrique se contente d'**assembler** en un appel les briques offline-first
/// existantes (ES-3.2) :
/// - une **règle** [ZFirestorePathRule.nestedUnderParent] (collection sous
///   `{parentCollection}/{parentId}`, elle-même sous `users/{userId}` si
///   [userScoped]) ;
/// - un [ZFirestorePathResolver] mono-`kind` la portant ;
/// - un [ZOfflineFirstBoxRepository] câblé avec `parentId: folderId` et [userId].
///
/// Le merge LWW, le listener temps réel, le filtrage `hasPendingWrites`, la
/// matérialisation de l'éphémère et le hook `validate` restent **portés par**
/// [ZOfflineFirstBoxRepository]/`ZStudyRepository` — **non redéclarés ici**
/// (AD-4 : composer, pas dupliquer).
///
/// ## Générique-par-topologie — zéro couplage à un consommateur
///
/// [collection]/[parentCollection] sont des `String` **paramètres** : aucun nom
/// lex n'est codé en dur, aucune arête vers un package d'entité n'est introduite
/// dans `zcrud_firestore` (l'adapter reste générique). Le seul type
/// `cloud_firestore` de la signature est le paramètre d'injection [firestore] —
/// la SEULE couture backend voulue (AD-5) ; le **type de retour est le port
/// NEUTRE** `ZStudyRepository<T>`.
///
/// ## AD-10 — folderId manquant ⇒ `Left(ZDomainFailure)` explicite
///
/// La topologie `nestedUnderParent` **exige** un `parentId` non vide : la
/// fabrique passe [folderId] **tel quel** comme `parentId` (jamais un défaut
/// avalé, jamais un repli en chemin plat). Un [folderId] vide fait donc remonter,
/// à la résolution de chemin de toute opération, le `Left(ZDomainFailure)`
/// explicite du resolver (nommant le `kind` et l'exigence `parentId`) — jamais un
/// chemin silencieusement tronqué qui écrirait dans la mauvaise collection.
///
/// ## DW-ES102-1 — câblage lex-side déféré (dette tracée)
///
/// Exemple de câblage au `ProviderScope` lex (DÉFÉRÉ à la session `lex_douane`) :
/// ```dart
/// zStudyDocumentRepositoryProvider.overrideWith(
///   (ref) => buildFolderScopedStudyRepository<ZStudyDocument>(
///     firestore: ref.watch(firestoreProvider),
///     local: ref.watch(documentLocalStoreProvider),
///     kind: 'study_document',
///     collection: 'study_documents',
///     parentCollection: 'study_folders',
///     decode: (m) => ZcrudRegistry.decode('study_document', m),
///     encode: (d) => d.toMap(),
///     userId: ref.watch(uidProvider),
///     folderId: ref.watch(currentFolderIdProvider),
///   ),
/// )
/// ```
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import 'z_firestore_path_resolver.dart';
import 'z_offline_first_box_repository.dart';

/// Construit le [ZFirestorePathResolver] **mono-`kind`** de la topologie
/// folder-scopée : une unique règle [ZFirestorePathRule.nestedUnderParent]
/// ([collection] sous [parentCollection], user-scopée si [userScoped]).
///
/// Extrait pour être `@visibleForTesting` : c'est l'**apport propre** d'ES-10.2
/// (la composition `nestedUnderParent(collection, parentCollection)` que
/// [buildFolderScopedStudyRepository] utilise en interne). Prouve, sans réseau, le
/// chemin nested exact (AC3) et la propagation du `Left` folderId-manquant (AC4).
/// Type NEUTRE (aucun `cloud_firestore`).
@visibleForTesting
ZFirestorePathResolver buildFolderScopedResolver({
  required String kind,
  required String collection,
  required String parentCollection,
  bool userScoped = true,
}) =>
    ZFirestorePathResolver(<String, ZFirestorePathRule>{
      kind: ZFirestorePathRule.nestedUnderParent(
        collection: collection,
        parentCollection: parentCollection,
        userScoped: userScoped,
      ),
    });

/// Assemble un dépôt d'étude **folder-scopé concret** (offline-first) pour la
/// topologie imbriquée `users/{userId}/{parentCollection}/{folderId}/{collection}`.
///
/// **Injection** :
/// - [firestore] : instance `FirebaseFirestore` (SEULE couture backend, AD-5) ;
/// - [local] : store local **autoritaire** ([ZLocalStore], défaut
///   `HiveZLocalStore`) ;
/// - [kind] : discriminant de collection (clé de la règle de topologie) ;
/// - [collection]/[parentCollection] : segments **littéraux** de la topologie
///   nested (génériques-par-topologie, aucun nom consommateur en dur) ;
/// - [decode]/[encode] : (dé)sérialisation du corps métier (voie
///   `ZcrudRegistry.decode` recommandée pour [decode], ES-3.0) ;
/// - [folderId] : identité du dossier parent (`parentId` de la topologie nested)
///   — vide ⇒ `Left` explicite à la résolution (AD-10) ;
/// - [userId] : contexte user-scopé (requis si [userScoped]) ;
/// - [userScoped] : préfixe `users/{userId}` (défaut `true`, topologie lex) ;
/// - [isConnected]/[logger]/[autoListen] : coutures optionnelles propagées à
///   [ZOfflineFirstBoxRepository].
///
/// **Type de retour = port NEUTRE** `ZStudyRepository<T>` : aucun type
/// `cloud_firestore` en signature publique hors le paramètre d'injection
/// [firestore].
ZStudyRepository<T> buildFolderScopedStudyRepository<T extends ZEntity>({
  required FirebaseFirestore firestore,
  required ZLocalStore<T> local,
  required String kind,
  required String collection,
  required String parentCollection,
  required T Function(Map<String, dynamic> map) decode,
  required Map<String, dynamic> Function(T value) encode,
  required String folderId,
  String? userId,
  bool userScoped = true,
  Future<bool> Function()? isConnected,
  ZOfflineFirstBoxLog? logger,
  bool autoListen = true,
}) =>
    ZOfflineFirstBoxRepository<T>(
      local: local,
      firestore: firestore,
      resolver: buildFolderScopedResolver(
        kind: kind,
        collection: collection,
        parentCollection: parentCollection,
        userScoped: userScoped,
      ),
      kind: kind,
      decode: decode,
      encode: encode,
      userId: userId,
      // AD-10 : `folderId` passé TEL QUEL comme parentId — jamais avalé ni replié
      // en chemin plat. Vide ⇒ `Left(ZDomainFailure)` du resolver à toute opération.
      parentId: folderId,
      isConnected: isConnected,
      logger: logger,
      autoListen: autoListen,
    );
