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

import 'package:flutter/foundation.dart';

import '../../domain/contracts/z_entity.dart';
import '../../domain/failures/z_failure.dart';
import '../../domain/ports/z_repository.dart';

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

  /// Supprime en **lot** (best-effort) les éléments sélectionnés via
  /// `repository.softDelete` (AD-9/AD-11). Chaque `Left(ZFailure)` est remonté à
  /// [onFailure] **sans throw** ; les id supprimés avec succès sont **retirés**
  /// de la sélection (les échecs y restent). [onSuccess] est appelé si **tous**
  /// les soft-delete ont réussi.
  ///
  /// **Atomicité** : best-effort — une transaction atomique multi-document est
  /// backend-spécifique (E5), non garantie ici (ambiguïté story #4).
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
