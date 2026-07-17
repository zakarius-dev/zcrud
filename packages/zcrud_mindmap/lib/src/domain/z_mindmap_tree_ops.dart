/// Moteur d'opérations d'arbre **pur** `ZMindmapTreeOps` (Story E10-1, FR-19).
///
/// origine: lex_core (module « Étude ») — `MindmapTreeOps`
/// (`mindmap_tree_ops.dart:16-178`). **Pur, immuable, structural sharing via
/// `identical()`** : tout sous-arbre non modifié est renvoyé PAR RÉFÉRENCE ;
/// toute opération no-op renvoie la forêt d'entrée par référence.
///
/// **Extension zcrud au-delà de lex** (dette n°5, OQ-5/OQ-10/OQ-11) :
/// `moveNode`/`indentNode`/`outdentNode`/`reorderChild` — annoncés au docstring
/// de lex mais **jamais codés** — sont ajoutés ici avec **recalcul systématique
/// de `level`** du sous-arbre reparenté (le `level` est un cache fragile).
///
/// Toutes les opérations opèrent sur une **forêt** `List<ZMindmapNode>` (racines)
/// et renvoient une **nouvelle forêt** (ou l'entrée `identical` si no-op).
library;

import 'dart:math';

import 'z_mindmap_node.dart';

/// Opérations d'arbre pures et immuables sur une forêt de `ZMindmapNode`.
///
/// Classe utilitaire sans état : uniquement des fonctions statiques.
abstract final class ZMindmapTreeOps {
  const ZMindmapTreeOps._();

  static final Random _random = Random.secure();

  // ---------------------------------------------------------------------------
  // Fabriques
  // ---------------------------------------------------------------------------

  /// Nouveau nœud racine vide (`level = 0`).
  static ZMindmapNode newRootNode() => ZMindmapNode(id: _uuidV4(), level: 0);

  /// Nouveau nœud enfant vide au niveau `parentLevel + 1`.
  static ZMindmapNode newChildNode(int parentLevel) =>
      ZMindmapNode(id: _uuidV4(), level: parentLevel + 1);

  // ---------------------------------------------------------------------------
  // Lecture
  // ---------------------------------------------------------------------------

  /// Recherche profonde du nœud [nodeId] dans la forêt ; `null` si introuvable.
  static ZMindmapNode? findNode(List<ZMindmapNode> roots, String nodeId) {
    for (final node in roots) {
      if (node.id == nodeId) return node;
      final found = findNode(node.children, nodeId);
      if (found != null) return found;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Opérations portées de lex (AC4)
  // ---------------------------------------------------------------------------

  /// Met à jour [label] et/ou [content] du nœud [nodeId].
  ///
  /// Sémantique `content` (canonique §2.2) : `null` = **non touché**, `''` =
  /// **efface**, toute autre valeur = remplace. `label` : `null` = non touché.
  /// No-op `identical` si [nodeId] introuvable.
  static List<ZMindmapNode> updateNode(
    List<ZMindmapNode> roots,
    String nodeId, {
    String? label,
    String? content,
  }) {
    if (label == null && content == null) return roots;
    return _replaceNode(
      roots,
      nodeId,
      (n) => ZMindmapNode(
        id: n.id,
        label: label ?? n.label,
        content: content ?? n.content,
        level: n.level,
        children: n.children,
        extension: n.extension,
        extra: n.extra,
      ),
    );
  }

  /// Remplace l'échappatoire [extra] (slot AD-4) du nœud [nodeId] par [extra]
  /// (l'appelant compose la map complète : c'est une **voie d'écriture de slot**,
  /// pas un merge). `label`/`content`/`level`/`children`/`extension` **inchangés**.
  /// No-op `identical` si [nodeId] introuvable. Le constructeur `ZMindmapNode`
  /// **dépouille** [extra] des clés réservées de sync (AD-19.1) — jamais un
  /// `assert`. Voie de l'édition riche SU-12 (`extra[slotKey]` = ops Delta).
  static List<ZMindmapNode> updateExtra(
    List<ZMindmapNode> roots,
    String nodeId,
    Map<String, dynamic> extra,
  ) {
    return _replaceNode(
      roots,
      nodeId,
      (n) => ZMindmapNode(
        id: n.id,
        label: n.label,
        content: n.content,
        level: n.level,
        children: n.children,
        extension: n.extension,
        extra: extra,
      ),
    );
  }

  /// Ajoute [child] (et son sous-arbre) comme dernier enfant de [parentId], avec
  /// **recalcul de `level`** (nouvelle base = `parent.level + 1`, cascade).
  /// No-op `identical` si [parentId] introuvable.
  static List<ZMindmapNode> addChild(
    List<ZMindmapNode> roots,
    String parentId,
    ZMindmapNode child,
  ) {
    return _replaceNode(roots, parentId, (parent) {
      final leveled = _recomputeLevels(child, parent.level + 1);
      return _withChildren(
        parent,
        <ZMindmapNode>[...parent.children, leveled],
      );
    });
  }

  /// Supprime le nœud [nodeId] **et tout son sous-arbre**, où qu'il soit.
  /// No-op `identical` si [nodeId] introuvable.
  static List<ZMindmapNode> deleteNode(
    List<ZMindmapNode> roots,
    String nodeId,
  ) {
    return _removeNode(roots, nodeId);
  }

  // ---------------------------------------------------------------------------
  // Opérations ajoutées zcrud + recalcul de level (AC5)
  // ---------------------------------------------------------------------------

  /// Reparente [nodeId] (et son sous-arbre) sous [newParentId] (ou en **racine**
  /// si `null`) à la position [index] (append si `null`, **clampé** aux bornes).
  /// **Recalcule `level`** de tout le sous-arbre déplacé (nouvelle base =
  /// `newParent.level + 1`, ou `0` en racine ; cascade `enfant = parent + 1`).
  ///
  /// **Anti-cycle** : déplacement vers soi-même ou vers un **descendant** de
  /// [nodeId] → rejet **no-op** (`identical`), jamais de boucle. Déplacement sans
  /// effet (même parent, même position) → no-op `identical`.
  static List<ZMindmapNode> moveNode(
    List<ZMindmapNode> roots,
    String nodeId,
    String? newParentId, {
    int? index,
  }) {
    final node = findNode(roots, nodeId);
    if (node == null) return roots;

    // Anti-cycle : cible == soi-même ou descendant du sous-arbre déplacé.
    if (newParentId != null && _containsId(node, newParentId)) return roots;

    // Contexte courant (parent + index) pour détecter un déplacement sans effet.
    final currentParent = _findParent(roots, nodeId);
    final currentParentId = currentParent?.id;
    final currentSiblings = currentParent?.children ?? roots;
    final currentIndex =
        currentSiblings.indexWhere((n) => n.id == nodeId);

    // Base de niveau de la destination.
    final int newBase;
    if (newParentId == null) {
      newBase = 0;
    } else {
      final newParent = findNode(roots, newParentId);
      if (newParent == null) return roots;
      newBase = newParent.level + 1;
    }

    // Détection de no-op « même emplacement ».
    final destLenBefore = newParentId == null
        ? roots.length
        : (findNode(roots, newParentId)?.children.length ?? 0);
    if (newParentId == currentParentId) {
      final clamped = index == null
          ? destLenBefore - 1 // append == rester en dernière position
          : index.clamp(0, destLenBefore - 1);
      if (clamped == currentIndex) return roots;
    }

    // Retrait puis ré-insertion avec niveaux recalculés.
    final without = _removeNode(roots, nodeId);
    final leveled = _recomputeLevels(node, newBase);

    if (newParentId == null) {
      return _insertAt(without, leveled, index);
    }
    return _replaceNode(
      without,
      newParentId,
      (parent) => _withChildren(
        parent,
        _insertAt(parent.children, leveled, index),
      ),
    );
  }

  /// Rattache [nodeId] comme **dernier enfant de son frère précédent** ;
  /// recalcule `level` (+1 cascade). **No-op** `identical` si le nœud est
  /// premier de sa fratrie (pas de frère précédent) ou introuvable.
  static List<ZMindmapNode> indentNode(
    List<ZMindmapNode> roots,
    String nodeId,
  ) {
    if (findNode(roots, nodeId) == null) return roots;
    final parent = _findParent(roots, nodeId);
    final siblings = parent?.children ?? roots;
    final idx = siblings.indexWhere((n) => n.id == nodeId);
    if (idx <= 0) return roots; // premier de la fratrie → no-op
    final previous = siblings[idx - 1];
    return moveNode(roots, nodeId, previous.id);
  }

  /// Rattache [nodeId] comme **frère suivant de son parent** ; recalcule `level`
  /// (−1 cascade). **No-op** `identical` si le nœud est une racine (pas de
  /// parent) ou introuvable.
  static List<ZMindmapNode> outdentNode(
    List<ZMindmapNode> roots,
    String nodeId,
  ) {
    if (findNode(roots, nodeId) == null) return roots;
    final parent = _findParent(roots, nodeId);
    if (parent == null) return roots; // racine → no-op
    final grandParent = _findParent(roots, parent.id);
    final gpSiblings = grandParent?.children ?? roots;
    final parentIdx = gpSiblings.indexWhere((n) => n.id == parent.id);
    return moveNode(roots, nodeId, grandParent?.id, index: parentIdx + 1);
  }

  /// Réordonne une fratrie sous [parentId] (ou les **racines** si `null`) en
  /// déplaçant l'élément de [oldIndex] vers [newIndex] ; `level` **inchangé**.
  /// No-op `identical` si parent introuvable, indices hors bornes ou identiques.
  static List<ZMindmapNode> reorderChild(
    List<ZMindmapNode> roots,
    String? parentId,
    int oldIndex,
    int newIndex,
  ) {
    if (parentId == null) {
      return _reorderList(roots, oldIndex, newIndex);
    }
    final parent = findNode(roots, parentId);
    if (parent == null) return roots;
    final reordered = _reorderList(parent.children, oldIndex, newIndex);
    if (identical(reordered, parent.children)) return roots;
    return _replaceNode(
      roots,
      parentId,
      (p) => _withChildren(p, reordered),
    );
  }

  // ---------------------------------------------------------------------------
  // Niveaux
  // ---------------------------------------------------------------------------

  /// Renormalise les `level` d'une forêt : chaque racine → `0`, cascade
  /// `enfant = parent + 1`. Structural sharing : les sous-arbres déjà cohérents
  /// sont renvoyés `identical`.
  static List<ZMindmapNode> normalizeLevels(List<ZMindmapNode> roots) {
    var changed = false;
    final result = <ZMindmapNode>[];
    for (final node in roots) {
      final leveled = _recomputeLevels(node, 0);
      if (!identical(leveled, node)) changed = true;
      result.add(leveled);
    }
    return changed ? List<ZMindmapNode>.unmodifiable(result) : roots;
  }

  // ---------------------------------------------------------------------------
  // Internes — structural sharing
  // ---------------------------------------------------------------------------

  /// Reconstruit récursivement un nœud avec [level] = [baseLevel] et cascade sur
  /// les enfants. Renvoie le nœud **`identical`** si rien ne change.
  static ZMindmapNode _recomputeLevels(ZMindmapNode node, int baseLevel) {
    var childrenChanged = false;
    final newChildren = <ZMindmapNode>[];
    for (final child in node.children) {
      final leveled = _recomputeLevels(child, baseLevel + 1);
      if (!identical(leveled, child)) childrenChanged = true;
      newChildren.add(leveled);
    }
    if (node.level == baseLevel && !childrenChanged) return node;
    return ZMindmapNode(
      id: node.id,
      label: node.label,
      content: node.content,
      level: baseLevel,
      children: childrenChanged ? newChildren : node.children,
      extension: node.extension,
      extra: node.extra,
    );
  }

  /// Remplace le nœud [id] par `fn(node)` où qu'il soit. Structural sharing :
  /// les branches intactes sont renvoyées `identical` ; forêt d'entrée renvoyée
  /// `identical` si [id] introuvable.
  static List<ZMindmapNode> _replaceNode(
    List<ZMindmapNode> forest,
    String id,
    ZMindmapNode Function(ZMindmapNode node) fn,
  ) {
    var changed = false;
    final result = <ZMindmapNode>[];
    for (final node in forest) {
      if (node.id == id) {
        result.add(fn(node));
        changed = true;
      } else {
        final newChildren = _replaceNode(node.children, id, fn);
        if (identical(newChildren, node.children)) {
          result.add(node);
        } else {
          result.add(_withChildren(node, newChildren));
          changed = true;
        }
      }
    }
    return changed ? List<ZMindmapNode>.unmodifiable(result) : forest;
  }

  /// Supprime le nœud [id] (et son sous-arbre) où qu'il soit. Structural sharing
  /// comme [_replaceNode].
  static List<ZMindmapNode> _removeNode(
    List<ZMindmapNode> forest,
    String id,
  ) {
    var changed = false;
    final result = <ZMindmapNode>[];
    for (final node in forest) {
      if (node.id == id) {
        changed = true;
        continue;
      }
      final newChildren = _removeNode(node.children, id);
      if (identical(newChildren, node.children)) {
        result.add(node);
      } else {
        result.add(_withChildren(node, newChildren));
        changed = true;
      }
    }
    return changed ? List<ZMindmapNode>.unmodifiable(result) : forest;
  }

  /// Parent DIRECT du nœud [id], ou `null` si [id] est une racine OU introuvable.
  static ZMindmapNode? _findParent(List<ZMindmapNode> forest, String id) {
    for (final node in forest) {
      for (final child in node.children) {
        if (child.id == id) return node;
      }
      final found = _findParent(node.children, id);
      if (found != null) return found;
    }
    return null;
  }

  /// `true` si [node] est [id] ou contient [id] dans son sous-arbre.
  static bool _containsId(ZMindmapNode node, String id) {
    if (node.id == id) return true;
    for (final child in node.children) {
      if (_containsId(child, id)) return true;
    }
    return false;
  }

  /// Nouveau nœud identique à [node] mais avec [children] (niveau propre
  /// inchangé). La liste est copiée défensivement par le constructeur.
  static ZMindmapNode _withChildren(
    ZMindmapNode node,
    List<ZMindmapNode> children,
  ) =>
      ZMindmapNode(
        id: node.id,
        label: node.label,
        content: node.content,
        level: node.level,
        children: children,
        extension: node.extension,
        extra: node.extra,
      );

  /// Insère [item] dans [list] à [index] (append si `null`, **clampé** à
  /// `[0, length]`). Renvoie toujours une nouvelle liste.
  static List<ZMindmapNode> _insertAt(
    List<ZMindmapNode> list,
    ZMindmapNode item,
    int? index,
  ) {
    final copy = <ZMindmapNode>[...list];
    final at = index == null ? copy.length : index.clamp(0, copy.length);
    copy.insert(at, item);
    return copy;
  }

  /// Réordonne [list] en déplaçant [oldIndex] → [newIndex] ([newIndex] clampé).
  /// Renvoie la liste d'entrée `identical` si no-op (hors bornes ou identiques).
  static List<ZMindmapNode> _reorderList(
    List<ZMindmapNode> list,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex < 0 || oldIndex >= list.length) return list;
    final target = newIndex.clamp(0, list.length - 1);
    if (target == oldIndex) return list;
    final copy = <ZMindmapNode>[...list];
    final item = copy.removeAt(oldIndex);
    copy.insert(target, item);
    return List<ZMindmapNode>.unmodifiable(copy);
  }

  // ---------------------------------------------------------------------------
  // UUID v4 (sans dépendance externe)
  // ---------------------------------------------------------------------------

  /// Génère un identifiant **UUID v4** (variante RFC 4122) via `Random.secure`,
  /// sans introduire de dépendance de package (id opaque `String`).
  static String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
