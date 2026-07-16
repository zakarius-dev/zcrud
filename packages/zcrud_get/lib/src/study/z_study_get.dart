/// Branchement study **GÉNÉRIQUE** GetX (Story ES-11.1, AC1/AC3/AC4/AC5 —
/// FR-S34, AD-1/AD-2/AD-5/AD-6/AD-10/AD-15/AD-24) — MIROIR GetX des providers
/// Riverpod d'ES-10.1.
///
/// Branche le port générique `ZStudyRepository<T>` (kernel) et la primitive PURE
/// `ZStudySessionSelector` (kernel) sur l'idiome GetX/get_it, **sans que le
/// kernel ni le cœur ne connaissent GetX** (garanti STRUCTURELLEMENT par le
/// graphe — ils ne dépendent pas de `zcrud_get`, AD-15).
///
/// ## R28 — binding GÉNÉRIQUE, spécialisation typée APP-SIDE (DW-ES111-1)
///
/// Tout ici est paramétré par `T extends ZEntity` (port `ZStudyRepository<T>`) —
/// **aucune entité concrète** n'est nommée ni tirée (leçon centrale ES-10.2 : un
/// fan-in typé forcerait `example/` à tirer une entité déférée v1.x, EX-3). La
/// spécialisation typée par entité (`ZStudyWatchController<ZStudyDocument>`,
/// seam `ZStudyRepository<ZStudyDocument>`) est un **one-liner APP-SIDE**
/// (composition-root DODLP), tracée en dette **DW-ES111-1** — jamais ici.
///
/// ## Résolution PAR SEAM (AD-6/AD-10)
///
/// Le repo concret n'est **jamais** importé ici : il est résolu via le
/// `ZDependencyResolver` (le `ZGetResolver`/get_it du `ZcrudGetScope`), qui
/// *throw* `ZScopeError` actionnable si absent (« seams throw », jamais de
/// résolution silencieuse).
library;

import 'dart:async';

import 'package:get/get.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import 'z_session_config_key.dart';

/// `GetxController` GÉNÉRIQUE branchant le flux **nu** `watchAll()` d'un
/// `ZStudyRepository<T>` (kernel) sur un observable GetX (AC1/AC5).
///
/// - `onInit()` s'abonne au flux `watchAll()` (`Stream<List<T>>` **NU**, AD-5) et
///   publie chaque émission **telle quelle** dans [items] — ordre et contenu
///   **préservés, sans transformation ni réordonnancement**.
/// - `onClose()` **annule** la souscription (`StreamSubscription.cancel()`) puis
///   délègue à `super.onClose()` — aucune souscription pendante, aucune fuite
///   (miroir de l'auto-dispose Riverpod, AC5).
/// - Les écritures (`save`/`softDelete`/…) restent celles du port : des
///   `Future<ZResult<T>>` **non enveloppés** — le controller n'altère pas le
///   contrat du port (AD-5/AD-11).
class ZStudyWatchController<T extends ZEntity> extends GetxController {
  /// Construit le controller autour d'un [repo] déjà résolu (via le seam — cf.
  /// [buildStudyWatchController]).
  ZStudyWatchController(this._repo);

  final ZStudyRepository<T> _repo;

  /// Observable GetX des éléments courants — ré-émission **exacte** du flux nu.
  final RxList<T> items = <T>[].obs;

  StreamSubscription<List<T>>? _sub;

  /// Le repo sous-jacent (accès aux écritures brutes du port — `Future<ZResult>`
  /// non enveloppé, AC1).
  ZStudyRepository<T> get repository => _repo;

  @override
  void onInit() {
    super.onInit();
    // Ré-émission EXACTE : aucune transformation/filtrage/réordonnancement.
    _sub = _repo.watchAll().listen(items.assignAll);
  }

  @override
  void onClose() {
    // AC5 — annulation explicite AVANT super.onClose() : aucune fuite (le
    // `onCancel` de la StreamController source est déclenché). Retirer ce
    // `cancel()` laisserait le flux vivant (R3-I5).
    _sub?.cancel();
    _sub = null;
    super.onClose();
  }
}

/// Fabrique de résolution **PAR SEAM** d'un [ZStudyWatchController] (AC4).
///
/// Résout `ZStudyRepository<T>` via le [resolver] (typiquement le `ZGetResolver`/
/// get_it du `ZcrudGetScope`). Si aucun repo n'est enregistré pour ce type, la
/// résolution *throw* un `ZScopeError` **actionnable** contenant le `Type`
/// manquant (contrat de `ZGetResolver`, AD-6/AD-10) — **jamais** `null` silencieux
/// ni repli sur un repo par défaut (avaler le throw rougit AC4, R3-I4).
///
/// **DW-ES111-1** : la spécialisation typée (`buildStudyWatchController<
/// ZStudyDocument>(resolver)`) est un one-liner APP-SIDE — le binding reste
/// générique sur `T`.
ZStudyWatchController<T> buildStudyWatchController<T extends ZEntity>(
  ZDependencyResolver resolver,
) =>
    ZStudyWatchController<T>(resolver.resolve<ZStudyRepository<T>>());

/// Fabrique de **sélection de session dédupliquée** (SM-1, AD-24) — miroir GetX
/// de la `family` Riverpod (AC3).
///
/// Dédup par le `tag` DÉTERMINISTE de [key] (`ZSessionConfigKey`) dans le
/// gestionnaire d'instances GetX (`Get.isRegistered`/`Get.put`/`Get.find` indexés
/// par `Type` + `tag`) : deux `ZStudySessionConfig` **structurellement égales
/// mais distinctes en mémoire** ⇒ **même** `tag` ⇒ la MÊME instance de
/// `ZStudySessionSelector` est réutilisée (`identical` vrai) — **zéro recréation
/// superflue** (objectif produit n°1). Une config différant d'un champ ⇒ nouveau
/// `tag` ⇒ nouvelle instance.
///
/// Le corps **délègue** à la primitive PURE `ZStudySessionSelector(key.config)`
/// du kernel — la sélection n'est **jamais** réimplémentée ici (AD-14).
///
/// [create] (défaut `ZStudySessionSelector.new`) est le point d'injection qui
/// permet aux tests de **compter** les constructions (R27.4 : le verrou vise ce
/// symbole PUBLIC exporté, pas seulement `ZSessionConfigKey.tag` isolé).
///
/// > Dériver le `tag` d'une composante d'IDENTITÉ (`identityHashCode`) ou d'une
/// > clé shallow (ignorant `extra`/`tagIds`/`types`) ferait passer le compteur de
/// > constructions de 1 → 2 sur « égales mais distinctes » (R3-I3, rouge).
ZStudySessionSelector zPutStudySessionSelector(
  ZSessionConfigKey key, {
  ZStudySessionSelector Function(ZStudySessionConfig config)? create,
}) {
  final tag = key.tag;
  if (!Get.isRegistered<ZStudySessionSelector>(tag: tag)) {
    Get.put<ZStudySessionSelector>(
      (create ?? ZStudySessionSelector.new)(key.config),
      tag: tag,
    );
  }
  return Get.find<ZStudySessionSelector>(tag: tag);
}
