/// Contrôleur d'édition outline `ZMindmapOutlineController` (Story E10-3).
///
/// **Correction par conception du bug lex (dette n°5)** : la forêt détenue par
/// ce contrôleur est la **source de vérité UNIQUE** de l'éditeur. Toute mutation
/// (label/content/add/delete/indent/outdent/reorder) est appliquée **en continu**
/// via `ZMindmapTreeOps` et **remplace** la forêt interne — de sorte que
/// `forest` reflète TOUJOURS l'état édité. La sauvegarde émet **exactement**
/// `controller.forest` : il n'existe AUCUN chemin où l'arbre d'origine serait
/// re-persisté par-dessus les edits (le bug lex historique).
///
/// **Réactivité Flutter-native (AD-2/AD-15)** : `ChangeNotifier` **pur-Flutter**
/// (aucun `flutter_riverpod`/`get`/`provider`, aucun `WidgetRef`/`Get.`/
/// `Provider.of`). Les notifications sont réservées aux mutations
/// **structurelles** (add/delete/indent/outdent/reorder) qui changent
/// l'aplatissement de l'outline ; l'édition de **texte** (`label`/`content`)
/// met à jour la forêt SANS notifier (le `TextField` porte déjà le texte via son
/// `TextEditingController` stable — rebuild ciblé, zéro perte de focus, SM-1).
///
/// **Aucune reconstruction manuelle d'arbre, aucun recalcul de `level`** : tout
/// passe par `ZMindmapTreeOps` (E10-1). `addSibling`/`addRoot` COMPOSENT les ops
/// existantes (`addChild` + `outdentNode`) — pas d'op « insérer racine » requise.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextEditingController;

import '../domain/z_mindmap_node.dart';
import '../domain/z_mindmap_tree_ops.dart';

/// Contrôleur `ChangeNotifier` détenant la forêt éditée (source de vérité).
///
/// Cycle de vie : créé avec une forêt initiale, muté via ses méthodes, puis
/// [dispose] libère TOUS les `TextEditingController` par nœud.
class ZMindmapOutlineController extends ChangeNotifier {
  /// Construit le contrôleur sur une [initialForest] (copiée en liste stable).
  ZMindmapOutlineController({
    List<ZMindmapNode> initialForest = const <ZMindmapNode>[],
  }) : _forest = List<ZMindmapNode>.unmodifiable(initialForest);

  List<ZMindmapNode> _forest;

  /// `TextEditingController` **stables** keyés par `ZMindmapNode.id` (label).
  final Map<String, TextEditingController> _labelControllers =
      <String, TextEditingController>{};

  /// `TextEditingController` **stables** keyés par `ZMindmapNode.id` (content).
  final Map<String, TextEditingController> _contentControllers =
      <String, TextEditingController>{};

  bool _disposed = false;

  /// Forêt éditée **courante** — c'est CE que `onSave` doit émettre (AC2).
  List<ZMindmapNode> get forest => _forest;

  // ---------------------------------------------------------------------------
  // TextEditingController stables par nœud (AC3 — zéro perte de focus)
  // ---------------------------------------------------------------------------

  /// `TextEditingController` **stable** du champ `label` de [node] : créé une
  /// seule fois par `id` (texte initial = `label`), réutilisé à l'identique aux
  /// rebuilds. **Jamais** réaffecté `.text` pendant la frappe (source du bug de
  /// focus historique). Le champ pilote la forêt (`onChanged → editLabel`), pas
  /// l'inverse.
  TextEditingController labelControllerFor(ZMindmapNode node) =>
      _labelControllers.putIfAbsent(
        node.id,
        () => TextEditingController(text: node.label),
      );

  /// `TextEditingController` **stable** du champ `content` de [node] (texte
  /// initial = `content ?? ''`). Mêmes garanties que [labelControllerFor].
  TextEditingController contentControllerFor(ZMindmapNode node) =>
      _contentControllers.putIfAbsent(
        node.id,
        () => TextEditingController(text: node.content ?? ''),
      );

  // ---------------------------------------------------------------------------
  // Édition de texte : met à jour la forêt SANS notifier (rebuild ciblé, SM-1)
  // ---------------------------------------------------------------------------

  /// Applique un nouveau [label] au nœud [id] via `ZMindmapTreeOps.updateNode`
  /// et **remplace** la forêt interne — **sans** `notifyListeners()` : le champ
  /// affiche déjà le texte via son controller stable ; notifier reconstruirait
  /// tout l'outline et ferait perdre le focus (interdit AD-2/SM-1).
  void editLabel(String id, String label) {
    final next = ZMindmapTreeOps.updateNode(_forest, id, label: label);
    if (!identical(next, _forest)) _forest = next;
  }

  /// Applique un nouveau [content] au nœud [id] (sémantique `updateNode` :
  /// `''` efface). Met à jour la forêt **sans** notifier (cf. [editLabel]).
  void editContent(String id, String content) {
    final next = ZMindmapTreeOps.updateNode(_forest, id, content: content);
    if (!identical(next, _forest)) _forest = next;
  }

  /// Écrit le payload rich (ops Delta neutres) dans le **slot AD-4** [slotKey] de
  /// `node.extra` du nœud [id], **sans** `notifyListeners()` (voie d'édition
  /// « live », comme [editLabel]/[editContent] — le champ rich porte déjà son
  /// état via son propre controller isolé ; notifier reconstruirait l'outline et
  /// ferait perdre le focus/curseur, AD-2/SM-1). `label`/`content` restent
  /// **inchangés** (OQ-S5/AD-28 : le rich vit dans `extra`, jamais dans
  /// `label`/`content`). Défensif (AD-10) : nœud introuvable → no-op.
  void editRichSlot(String id, String slotKey, List<Map<String, dynamic>> ops) {
    final node = ZMindmapTreeOps.findNode(_forest, id);
    if (node == null) return;
    final nextExtra = <String, dynamic>{...node.extra, slotKey: ops};
    final next = ZMindmapTreeOps.updateExtra(_forest, id, nextExtra);
    if (!identical(next, _forest)) _forest = next;
  }

  // ---------------------------------------------------------------------------
  // Mutations structurelles : remplacent la forêt et NOTIFIENT (rebuild liste)
  // ---------------------------------------------------------------------------

  /// Ajoute un nœud enfant vide au nœud [parentId] (niveau `parent.level + 1`).
  void addChild(String parentId) {
    final parent = ZMindmapTreeOps.findNode(_forest, parentId);
    if (parent == null) return;
    final child = ZMindmapTreeOps.newChildNode(parent.level);
    _set(ZMindmapTreeOps.addChild(_forest, parentId, child));
  }

  /// Ajoute un **frère** juste après [id], au même niveau — quel que soit le
  /// niveau de [id] (racine ou non). **Compose** les ops existantes sans
  /// `findParent` public ni op « insérer racine » : on ajoute d'abord un enfant
  /// SOUS [id] puis on le **désindente** (`outdentNode`), ce qui le repositionne
  /// comme frère de [id] (index `id + 1`) avec `level` recalculé. Pour une
  /// racine, `outdentNode` remonte l'enfant en racine, à la position `id + 1`.
  void addSibling(String id) {
    final node = ZMindmapTreeOps.findNode(_forest, id);
    if (node == null) return;
    final child = ZMindmapTreeOps.newChildNode(node.level);
    var next = ZMindmapTreeOps.addChild(_forest, id, child);
    next = ZMindmapTreeOps.outdentNode(next, child.id);
    _set(next);
  }

  /// Ajoute une **nouvelle racine** en fin de forêt. Forêt vide → création de la
  /// forêt initiale via `newRootNode()` (composition de liste d'une fabrique,
  /// aucune reconstruction de nœud). Sinon → [addSibling] de la dernière racine
  /// (100 % `ZMindmapTreeOps`).
  void addRoot() {
    if (_forest.isEmpty) {
      _set(<ZMindmapNode>[ZMindmapTreeOps.newRootNode()]);
      return;
    }
    addSibling(_forest.last.id);
  }

  /// Supprime le nœud [id] et tout son sous-arbre (`deleteNode`). Purge aussi les
  /// `TextEditingController` du sous-arbre retiré (LOW-1 : anti-fuite mémoire).
  void deleteNode(String id) {
    final next = ZMindmapTreeOps.deleteNode(_forest, id);
    if (identical(next, _forest)) return; // introuvable → aucun changement
    final removed = ZMindmapTreeOps.findNode(_forest, id);
    if (removed != null) _disposeSubtreeControllers(removed);
    _set(next);
  }

  /// Dispose récursivement les controllers du sous-arbre enraciné en [node].
  void _disposeSubtreeControllers(ZMindmapNode node) {
    _labelControllers.remove(node.id)?.dispose();
    _contentControllers.remove(node.id)?.dispose();
    for (final child in node.children) {
      _disposeSubtreeControllers(child);
    }
  }

  /// Indente [id] (rattache comme dernier enfant du frère précédent).
  void indent(String id) => _set(ZMindmapTreeOps.indentNode(_forest, id));

  /// Désindente [id] (rattache comme frère suivant de son parent).
  void outdent(String id) => _set(ZMindmapTreeOps.outdentNode(_forest, id));

  /// Déplace [id] d'une position vers le **début** dans sa fratrie
  /// (`reorderChild`). No-op si déjà premier ou introuvable.
  void moveUp(String id) {
    final loc = _locate(_forest, null, id);
    if (loc == null || loc.index <= 0) return;
    _set(ZMindmapTreeOps.reorderChild(
      _forest,
      loc.parentId,
      loc.index,
      loc.index - 1,
    ));
  }

  /// Déplace [id] d'une position vers la **fin** dans sa fratrie
  /// (`reorderChild`). No-op si déjà dernier ou introuvable.
  void moveDown(String id) {
    final loc = _locate(_forest, null, id);
    if (loc == null || loc.index >= loc.siblingCount - 1) return;
    _set(ZMindmapTreeOps.reorderChild(
      _forest,
      loc.parentId,
      loc.index,
      loc.index + 1,
    ));
  }

  // ---------------------------------------------------------------------------
  // Internes
  // ---------------------------------------------------------------------------

  /// Remplace la forêt et notifie **seulement si elle a réellement changé**
  /// (respect du no-op `identical` de `ZMindmapTreeOps` — pas de rebuild inutile).
  void _set(List<ZMindmapNode> next) {
    if (identical(next, _forest)) return;
    _forest = next;
    notifyListeners();
  }

  /// Localise [id] : `parentId` (`null` en racine), `index` dans sa fratrie et
  /// taille de la fratrie. **Lecture seule** (aucune mutation) — l'équivalent
  /// position de `findNode` ; n'utilise PAS le `_findParent` privé de TreeOps.
  static _NodeLocation? _locate(
    List<ZMindmapNode> forest,
    String? parentId,
    String id,
  ) {
    for (var i = 0; i < forest.length; i++) {
      if (forest[i].id == id) {
        return _NodeLocation(parentId, i, forest.length);
      }
      final found = _locate(forest[i].children, forest[i].id, id);
      if (found != null) return found;
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final c in _labelControllers.values) {
      c.dispose();
    }
    for (final c in _contentControllers.values) {
      c.dispose();
    }
    _labelControllers.clear();
    _contentControllers.clear();
    super.dispose();
  }

  /// `true` si [dispose] a déjà été appelé (garde de test/diagnostic).
  bool get isDisposed => _disposed;
}

/// Position d'un nœud dans sa fratrie (résultat de localisation lecture-seule).
@immutable
class _NodeLocation {
  const _NodeLocation(this.parentId, this.index, this.siblingCount);

  /// Id du parent direct, ou `null` si le nœud est une racine.
  final String? parentId;

  /// Index du nœud dans sa fratrie.
  final int index;

  /// Nombre de nœuds dans la fratrie.
  final int siblingCount;
}
