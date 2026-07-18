/// Sélection multiple **neutre** de liste du cœur `zcrud_core` (E4-4).
///
/// origine: bug historique de sélection des 3 apps (IFFD `_dataGridController`
/// **commenté** — `dynamic_list_screen.dart:1094,1100`, statut « buggy » — la
/// sélection Syncfusion n'était pas branchée à un état applicatif ; DODLP/DLCFTI
/// idem). **Correctif E4-4** : l'état de sélection vit ICI, dans un contrôleur
/// **Flutter-natif** (`ChangeNotifier` + `ValueNotifier` mémoïsé), **hors** du
/// renderer, keyé par l'**`id` STABLE** de `ZListRow` (jamais par index/position)
/// — immunisé contre rebuild/scroll/pagination (la grille devient stateful et se
/// lie à cet état, cf. `zcrud_list`). Calque `ZFormController`/`ZListController`
/// (AD-2/AD-15) : **aucun** gestionnaire d'état ; imports limités à
/// `package:flutter/foundation.dart` + types `zcrud_core`.
library;

import 'package:dartz/dartz.dart' show Left, Unit;
import 'package:flutter/foundation.dart';

import '../../domain/contracts/z_entity.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/failures/z_failure.dart';
import '../../domain/ports/z_repository.dart';
import '../edition/z_validator_compiler.dart';
import 'z_batch_deletion_report.dart';

/// Mode de sélection d'une liste (AC3).
enum ZListSelectionMode {
  /// Sélection désactivée : toute mutation est un **no-op**.
  none,

  /// Sélection **unique** : `toggle`/`setSelection` ne conservent qu'un seul id.
  single,

  /// Sélection **multiple** (cases à cocher, actions en lot).
  multiple,
}

/// Contrôleur de **sélection multiple** neutre, exposant une tranche
/// `ValueListenable<Set<String>>` d'`id` de ligne stables (AC3/AC4).
///
/// Réactivité **Flutter-native** (AD-2/AD-15) : un widget écoute la SEULE tranche
/// [selectedIds] via `ValueListenableBuilder` (rebuild ciblé). Les `Set` émis
/// sont **non modifiables** (immuabilité de la tranche). `dispose()` libère le
/// `ValueNotifier` interne ; toute mutation post-`dispose` est un no-op.
class ZListSelectionController extends ChangeNotifier {
  /// Construit le contrôleur pour le [mode] donné (défaut `multiple`), avec une
  /// sélection initiale optionnelle [initialSelection].
  ZListSelectionController({
    this.mode = ZListSelectionMode.multiple,
    Iterable<String> initialSelection = const <String>[],
  }) : _selected = ValueNotifier<Set<String>>(
          Set<String>.unmodifiable(_normalize(mode, initialSelection)),
        );

  /// Mode de sélection (fixe pour la durée de vie du contrôleur).
  final ZListSelectionMode mode;

  final ValueNotifier<Set<String>> _selected;
  bool _disposed = false;

  /// Tranche réactive des `id` sélectionnés (unique surface observée par l'UI).
  /// Émet toujours un `Set` **non modifiable**.
  ValueListenable<Set<String>> get selectedIds => _selected;

  /// Nombre d'éléments sélectionnés.
  int get selectedCount => _selected.value.length;

  /// `true` si [id] est actuellement sélectionné.
  bool isSelected(String id) => _selected.value.contains(id);

  /// Bascule la sélection de [id]. En mode `single`, sélectionner un nouvel id
  /// **remplace** la sélection (re-toggle du même id ⇒ désélection) ; en mode
  /// `none`, no-op.
  void toggle(String id) {
    if (_disposed || mode == ZListSelectionMode.none) return;
    final current = _selected.value;
    final Set<String> next;
    if (current.contains(id)) {
      next = <String>{...current}..remove(id);
    } else if (mode == ZListSelectionMode.single) {
      next = <String>{id};
    } else {
      next = <String>{...current, id};
    }
    _commit(next);
  }

  /// Sélectionne tous les [ids] fournis (union). En mode `single`, ne conserve
  /// qu'un id ; en mode `none`, no-op.
  void selectAll(Iterable<String> ids) {
    if (_disposed || mode == ZListSelectionMode.none) return;
    _commit(<String>{..._selected.value, ...ids});
  }

  /// **Remplace** intégralement la sélection par [ids] (normalisée selon le
  /// mode). Utilisé pour refléter la sélection remontée par la grille.
  void setSelection(Iterable<String> ids) {
    if (_disposed || mode == ZListSelectionMode.none) return;
    _commit(ids.toSet());
  }

  /// Vide la sélection.
  void clearSelection() {
    if (_disposed) return;
    _commit(const <String>{});
  }

  /// Sélectionne la **plage inclusive** de [orderedIds] entre [anchorId] et
  /// [targetId] (dans l'ordre visuel fourni), en **union** avec la sélection
  /// courante (sélection par Shift+clic). Sans effet si l'un des bornes est
  /// absent de [orderedIds], en mode `none`, ou après `dispose`.
  void selectRange(
    List<String> orderedIds,
    String anchorId,
    String targetId,
  ) {
    if (_disposed || mode == ZListSelectionMode.none) return;
    final a = orderedIds.indexOf(anchorId);
    final b = orderedIds.indexOf(targetId);
    if (a < 0 || b < 0) return;
    final lo = a <= b ? a : b;
    final hi = a <= b ? b : a;
    final range = orderedIds.sublist(lo, hi + 1);
    if (mode == ZListSelectionMode.single) {
      _commit(<String>{targetId});
      return;
    }
    _commit(<String>{..._selected.value, ...range});
  }

  /// Applique une opération de lot GÉNÉRIQUE à chaque `id` sélectionné, via le
  /// **seam INJECTÉ** [applyToRoot] (`Future<ZResult<Unit>> Function(String)`),
  /// **`await`é par racine** (jamais fire-and-forget — AD-39). Agrège un
  /// [ZBatchReport] au grain de la racine : chaque racine est **soit** réussie
  /// (`Right`) **soit** échouée (`Left` **ou** `throw` capté en [ZFailure] —
  /// AD-10 : **aucune exception ne franchit la surface**). Les racines réussies
  /// sont **retirées** de la sélection quand [clearSucceededFromSelection] est
  /// `true` ; les échouées y restent.
  ///
  /// **CORE OUT=0 (AD-1)** : la **cascade** (AD-21, borne ≤ 450) et le chemin
  /// d'écriture physique sont des propriétés de [applyToRoot] (injecté par
  /// `zcrud_study_kernel`/`zcrud_firestore`), jamais du cœur. Post-`dispose` ⇒
  /// rapport vide (no-op).
  ///
  /// L'itération se fait sur un **instantané** des `id` sélectionnés capturé à
  /// l'entrée : une mutation concurrente de la sélection ne change pas le lot en
  /// cours. Le seam est appelé par `id` STABLE — jamais par index/position
  /// (leçon E-STUDY-UI, RISQUE N°1).
  Future<ZBatchReport> batchApply({
    required Future<ZResult<Unit>> Function(String rootId) applyToRoot,
    bool clearSucceededFromSelection = true,
  }) async {
    if (_disposed) return ZBatchReport.empty();
    final ids = _selected.value.toList(growable: false);
    final succeeded = <String>{};
    final failures = <String, ZFailure>{};
    for (final id in ids) {
      ZResult<Unit> result;
      try {
        result = await applyToRoot(id);
      } catch (error, stack) {
        // AD-10 — un `throw` du seam injecté est CAPTÉ et converti en racine
        // échouée (jamais propagé). Le stack est joint au message (diagnostic).
        failures[id] = ServerFailure('batch operation threw for "$id": '
            '$error\n$stack');
        continue;
      }
      result.fold(
        (failure) => failures[id] = failure,
        (_) => succeeded.add(id),
      );
    }
    if (!_disposed &&
        clearSucceededFromSelection &&
        succeeded.isNotEmpty) {
      _commit(<String>{..._selected.value}..removeAll(succeeded));
    }
    return ZBatchReport(succeededRootIds: succeeded, failures: failures);
  }

  /// Suppression par **lot** conforme AD-39 : le supprimeur [deleteRoot] est un
  /// **seam INJECTÉ** (la cascade AD-21 et la borne ≤ 450 sont sa propriété, pas
  /// celle du cœur), **`await`é par racine**. Retourne un [ZBatchDeletionReport]
  /// (= [ZBatchReport]) : l'appelant reçoit TOUJOURS les racines échouées avec
  /// leur cause — jamais un lot silencieusement partiel. Les racines supprimées
  /// avec succès sont retirées de la sélection ; les échouées y restent. Tout
  /// `throw` est capté (AD-10).
  ///
  /// Remplace la voie best-effort [softDeleteSelected] (sans rapport racine).
  Future<ZBatchDeletionReport> batchDelete({
    required Future<ZResult<Unit>> Function(String rootId) deleteRoot,
  }) =>
      batchApply(applyToRoot: deleteRoot);

  /// **Déplace** en lot les éléments sélectionnés en réaffectant le **champ de
  /// rattachement DÉCLARÉ par le modèle** [attachmentField] (nom PARAMÉTRIQUE —
  /// ex. `folder_id`/`parent_id` ; JAMAIS codé en dur) à la [destination]
  /// fournie par un **sélecteur INJECTÉ** de l'app. L'écriture par racine passe
  /// par le seam INJECTÉ [moveRoot] ; application **par élément** + rapport
  /// (même contrat que [batchDelete]).
  ///
  /// **Modèle sans champ de rattachement** ([attachmentField] `null`/vide) ⇒
  /// résultat DÉFINI (AD-10) : chaque racine est rapportée en échec
  /// ([DomainFailure]) et **aucune écriture** n'est tentée — jamais de `throw`.
  Future<ZBatchReport> batchMove({
    required String? attachmentField,
    required Object? destination,
    required Future<ZResult<Unit>> Function(
      String rootId,
      String attachmentField,
      Object? destination,
    ) moveRoot,
  }) {
    if (attachmentField == null || attachmentField.isEmpty) {
      // Aucune écriture : chaque racine échoue avec une cause définie (AD-10).
      return batchApply(
        applyToRoot: (_) async => Left<ZFailure, Unit>(
          const DomainFailure(
            'move rejected: model declares no attachment field',
          ),
        ),
        clearSucceededFromSelection: false,
      );
    }
    return batchApply(
      applyToRoot: (id) => moveRoot(id, attachmentField, destination),
    );
  }

  /// Édite un **champ commun** [field] sur tous les éléments sélectionnés, en
  /// dérivant les validateurs du `ZFieldSpec` via [ZValidatorCompiler.compile]
  /// — **exactement les mêmes** que le formulaire unitaire (AD-44 : une seule
  /// source de validation, jamais une 2e implémentation). La valeur candidate
  /// [value] est validée **AVANT toute écriture** : si elle est invalide,
  /// **aucune racine n'est touchée** (le seam [writeRoot] n'est PAS appelé) et
  /// chaque racine sélectionnée est rapportée en échec ([DomainFailure] portant
  /// le message du validateur). Sinon, application **par élément** via le seam
  /// INJECTÉ [writeRoot] + rapport (même contrat que [batchDelete]).
  ///
  /// [clearSucceededFromSelection] : défaut **`false`** — l'édition d'un champ
  /// commun est une écriture **in-place**, les éléments RESTENT visibles ⇒ la
  /// sélection est **conservée** (l'utilisateur peut enchaîner un 2ᵉ champ sur
  /// le même lot, ex. multi-éditeur me-2, sans tout re-sélectionner). Contraste
  /// avec [batchDelete]/[batchMove] où les éléments quittent la vue (défaut
  /// `true`). L'appelant peut forcer le vidage en passant `true`.
  Future<ZBatchReport> applyCommonField({
    required ZFieldSpec field,
    required String? value,
    required Future<ZResult<Unit>> Function(
      String rootId,
      String fieldName,
      String? value,
    ) writeRoot,
    bool clearSucceededFromSelection = false,
  }) async {
    if (_disposed) return ZBatchReport.empty();
    // Mêmes validateurs que l'édition unitaire (AD-44) — validation AVANT écriture.
    final validator = ZValidatorCompiler.compile(field.validators);
    final error = validator?.call(value);
    if (error != null) {
      // Valeur invalide ⇒ AUCUNE racine touchée (writeRoot jamais appelé).
      final ids = _selected.value.toList(growable: false);
      final failures = <String, ZFailure>{
        for (final id in ids) id: DomainFailure(error),
      };
      return ZBatchReport(
        succeededRootIds: const <String>{},
        failures: failures,
      );
    }
    return batchApply(
      applyToRoot: (id) => writeRoot(id, field.name, value),
      clearSucceededFromSelection: clearSucceededFromSelection,
    );
  }

  /// Supprime en **lot** (best-effort) les éléments sélectionnés via
  /// `repository.softDelete` (AD-9/AD-11). Chaque `Left(ZFailure)` est remonté à
  /// [onFailure] **sans throw** ; les id supprimés avec succès sont **retirés**
  /// de la sélection (les échecs y restent). [onSuccess] est appelé si **tous**
  /// les soft-delete ont réussi.
  ///
  /// **Atomicité** : best-effort — une transaction atomique multi-document est
  /// backend-spécifique (E5), non garantie ici (ambiguïté story #4).
  @Deprecated(
    'Voie best-effort SANS rapport au grain de la racine (AD-39). Utiliser '
    'batchDelete({deleteRoot}) qui await par racine et retourne un '
    'ZBatchDeletionReport (racines réussies + Map<rootId, ZFailure>). '
    'Conservée pour rétro-compat E4-4.',
  )
  Future<void> softDeleteSelected<T extends ZEntity>(
    ZRepository<T> repository, {
    void Function(ZFailure failure)? onFailure,
    void Function()? onSuccess,
  }) async {
    if (_disposed) return;
    final ids = _selected.value.toList(growable: false);
    final succeeded = <String>{};
    var allOk = true;
    for (final id in ids) {
      final result = await repository.softDelete(id);
      result.fold(
        (failure) {
          allOk = false;
          onFailure?.call(failure);
        },
        (_) => succeeded.add(id),
      );
    }
    if (_disposed) return;
    if (succeeded.isNotEmpty) {
      _commit(<String>{..._selected.value}..removeAll(succeeded));
    }
    if (allOk) onSuccess?.call();
  }

  void _commit(Set<String> next) {
    _selected.value = Set<String>.unmodifiable(_normalize(mode, next));
  }

  /// Normalise une sélection initiale/entrante selon le [mode] (single ⇒ ≤ 1 ;
  /// none ⇒ vide).
  static Set<String> _normalize(ZListSelectionMode mode, Iterable<String> ids) {
    switch (mode) {
      case ZListSelectionMode.none:
        return const <String>{};
      case ZListSelectionMode.single:
        final it = ids.toList(growable: false);
        return it.isEmpty ? <String>{} : <String>{it.last};
      case ZListSelectionMode.multiple:
        return ids.toSet();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _selected.dispose();
    super.dispose();
  }
}
