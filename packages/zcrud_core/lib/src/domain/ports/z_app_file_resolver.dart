/// `ZAppFileResolver` — **port neutre** de résolution de **références opaques**
/// de fichiers (`String`) vers des [AppFile].
///
/// Une application peut ne pas stocker d'objet fichier dans ses documents,
/// mais seulement des **identifiants** opaques (par exemple des `id` de
/// document distant). Sans ce port, la famille fichier du cœur ne retiendrait
/// que les valeurs déjà typées `AppFile` — toute valeur qui n'en est pas
/// **déjà** un serait **silencieusement ignorée**, donc un champ fichier migré
/// s'afficherait **VIDE** sur une donnée existante, **sans erreur**. Ce port
/// ouvre la voie de résolution ; il ne la remplit pas.
///
/// **NEUTRALITÉ (NON-NÉGOCIABLE, AD-1)** : ce fichier est **pur-Dart** (AUCUN
/// import Flutter / `cloud_firestore` / Hive / gestionnaire d'état). Les
/// références sont des **`String` opaques** : le cœur n'en connaît NI la forme
/// (chemin, id de document, URL…), NI la collection, NI le backend. **Aucune
/// implémentation concrète ne vit dans le cœur** : l'app / `zcrud_firestore`
/// implémente [ZAppFileResolver] et l'injecte via
/// `ZcrudScope(appFileResolver: …)`.
///
/// **CONTRAT D'APPARIEMENT (explicite, sans ambiguïté)** : l'implémentation
/// retourne des [AppFile] dont l'[AppFile.id] est **exactement** la référence
/// demandée. Une référence sans [AppFile] correspondant dans le retour est
/// considérée **INTROUVABLE** — et c'est un état **VISIBLE**, jamais un silence.
///
/// **AD-10 (dégradation définie)** : le consommateur (`ZAppFileField`) traite
/// TOUS les cas d'échec sans jamais lever ni bloquer le champ :
/// - port **absent** ⇒ comportement historique **strictement conservé** (les
///   références restent ignorées, aucun état ajouté — hôte passif immobile) ;
/// - `Future` en **erreur** — `Error` **comme** `Exception` (l'échec NORMAL
///   d'une E/S est une `Exception`) ⇒ état `échec` réessayable ;
/// - `Future` qui **ne se termine jamais** ⇒ [ZAppFileResolver.timeout] tranche
///   et bascule sur l'état `échec` ;
/// - référence **introuvable** ⇒ état `introuvable` visible.
library;

import '../edition/app_file.dart';

/// Port **abstrait** (neutre) de résolution de références de fichiers.
///
/// Contrat (AD-5) : [resolve] retourne une `List<AppFile>` **nue** (jamais un
/// `Either`) — le cœur ne veut pas connaître la taxonomie d'échec du backend, il
/// veut un rendu dégradé DÉFINI. Un échec s'exprime par un `Future` en erreur ou
/// par une référence absente du retour.
abstract class ZAppFileResolver {
  /// Constructeur `const` (impls concrètes immuables si possible).
  const ZAppFileResolver();

  /// Résout les [refs] (références **opaques**) en [AppFile].
  ///
  /// L'ordre du retour est **indifférent** : l'appariement se fait par
  /// [AppFile.id] == référence. Une référence non résolue est simplement absente
  /// du retour (⇒ état `introuvable` côté rendu, jamais un silence).
  Future<List<AppFile>> resolve(List<String> refs);

  /// **Délai de garde** appliqué par le consommateur à [resolve] (AD-10) : un
  /// `Future` qui ne se termine jamais ne doit pas laisser le champ bloqué.
  ///
  /// Surchargeable par l'implémentation (et par les tests). Défaut : 15 s.
  Duration get timeout => const Duration(seconds: 15);
}
