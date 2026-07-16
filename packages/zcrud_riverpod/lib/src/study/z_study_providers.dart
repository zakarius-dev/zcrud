/// Providers Riverpod GÉNÉRIQUES branchant le port `ZStudyRepository<T>` et la
/// primitive PURE `ZStudySessionSelector` du kernel sur Riverpod (Story ES-10.1,
/// AC1/AC3/AC4/AC5 — FR-S33, AD-1/AD-2/AD-5/AD-6/AD-10/AD-15/AD-24).
///
/// ## Forme d'API : fonction fabrique (Riverpod n'a pas de provider générique)
///
/// Riverpod ne permet PAS `Provider.family<T, …>` générique sur `T`. On expose
/// donc des **fonctions fabriques** paramétrées par le type d'entité :
/// - [zStudyRepositoryProvider] — le **seam** du repo (un `Provider` qui *throw*
///   [ZScopeError] tant qu'il n'est pas surchargé — patron seam AD-6, réutilise
///   le contrat de `ZRiverpodResolver`) ; l'app le crée **une fois** et le
///   surcharge (`overrideWith`) avec son repo concret (ES-10.2) ;
/// - [zStudyWatchAllProvider] — un `StreamProvider.autoDispose` émettant la
///   `Stream<List<T>>` **NUE** du repo (`watchAll()`, AD-5), sans transformation.
///
/// Les providers **typés concrets** (adossés à `ZStudyDocument`/`ZSmartNote`/
/// `ZExam`…) et leurs adapters `zcrud_firestore` nested sont **ES-10.2** — cette
/// story reste générique et sans dépendance aux packages d'entités (fan-in
/// minimal = kernel seul, AC6).
///
/// ## Sélection de session : family clée par `ZSessionConfigKey` (SM-1, AD-24)
///
/// [zStudySessionSelectorProvider] est une `family` clée par [ZSessionConfigKey]
/// (égalité PROFONDE au binding). Deux `ZStudySessionConfig` structurellement
/// égales mais distinctes en mémoire ⇒ **même** clé ⇒ Riverpod **dédup** ⇒ le
/// provider ne build **qu'une fois** (aucun rebuild superflu — objectif produit
/// n°1). Le body délègue à la primitive PURE `ZStudySessionSelector` du kernel,
/// il ne **réimplémente PAS** la sélection.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import 'z_session_config_key.dart';

/// Fabrique le **seam** d'un `ZStudyRepository<T>` : un `Provider` qui *throw*
/// [ZScopeError] tant qu'il n'a pas été surchargé (`overrideWith`) avec un repo
/// concret — jamais de résolution silencieuse (AD-6 « seams throw », AD-10).
///
/// L'app (ES-10.2) crée le seam **une fois**
/// (`final docsRepo = zStudyRepositoryProvider<ZStudyDocument>();`) et le
/// surcharge dans son `ProviderScope`/`ZcrudRiverpodScope`. Le message d'erreur
/// nomme le `Type` manquant (cohérent avec `ZRiverpodResolver`), le rendant
/// actionnable.
Provider<ZStudyRepository<T>> zStudyRepositoryProvider<T extends ZEntity>() =>
    Provider<ZStudyRepository<T>>(
      (ref) => throw ZScopeError(
        'Aucun ZStudyRepository<$T> fourni pour le seam Riverpod. Surchargez le '
        'provider retourné par zStudyRepositoryProvider<$T>() via '
        'overrideWith((ref) => monRepoConcret) dans le ProviderScope / '
        'ZcrudRiverpodScope de l\'app.',
      ),
    );

/// Fabrique un `StreamProvider.autoDispose` exposant le flux **nu**
/// `watchAll()` (`Stream<List<T>>`, AD-5) du repo résolu par [repo].
///
/// - [repo] : le seam du repo (typiquement le `Provider` de
///   [zStudyRepositoryProvider], surchargé par l'app). S'il n'est pas fourni,
///   sa lecture *throw* [ZScopeError] (AC4).
/// - **`.autoDispose`** : dès que plus personne n'écoute (ou que le
///   `ProviderContainer` est disposé), Riverpod annule la souscription au flux
///   du repo — aucune fuite (AC5, même patron que `zFormControllerProvider`).
/// - Aucune transformation : la liste émise est **exactement** celle du repo
///   (ordre et contenu préservés, AD-5).
AutoDisposeStreamProvider<List<T>> zStudyWatchAllProvider<T extends ZEntity>({
  required ProviderListenable<ZStudyRepository<T>> repo,
}) =>
    StreamProvider.autoDispose<List<T>>(
      (ref) => ref.watch(repo).watchAll(),
    );

/// Family de **sélection de session** clée par [ZSessionConfigKey] (égalité
/// PROFONDE au binding, AD-24) — délègue à la primitive PURE
/// [ZStudySessionSelector] du kernel (jamais réimplémentée ici).
///
/// **SM-1 (objectif produit n°1)** : deux configs structurellement égales mais
/// distinctes en mémoire ⇒ **même** [ZSessionConfigKey] (par `==`/`hashCode`)
/// ⇒ Riverpod réutilise le **même** provider (dedup) ⇒ **zéro rebuild** superflu.
/// Une config différant d'un champ ⇒ nouvelle clé ⇒ nouveau provider (rebuild).
///
/// `.autoDispose` : la sélection étant dérivée (pure, sans souscription), le
/// provider se libère dès qu'il n'est plus écouté.
final zStudySessionSelectorProvider = Provider.autoDispose
    .family<ZStudySessionSelector, ZSessionConfigKey>(
  (ref, key) => ZStudySessionSelector(key.config),
);
