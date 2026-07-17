/// Barrel d'API publique de `zcrud_mindmap`.
///
/// `ZMindmap` + vue graphite.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// Domaine E10-1 (FR-19, AD-1/AD-4/AD-10/AD-16) : modèle canonique de carte
// mentale (forêt titrée `ZMindmap` + nœud récursif par nesting `ZMindmapNode`,
// slots d'extension AD-4, sync HORS-ENTITÉ) et moteur d'arbre PUR
// `ZMindmapTreeOps` (add/update/delete/find portés de lex + move/indent/outdent/
// reorder ajoutés avec recalcul de `level`, structural sharing `identical`).
export 'src/domain/z_mindmap.dart';
export 'src/domain/z_mindmap_api.dart';
export 'src/domain/z_mindmap_node.dart';
export 'src/domain/z_mindmap_tree_ops.dart';

// Présentation E10-2 (FR-19, AD-1/AD-2/AD-13/AD-15/FR-26) : vue de carte mentale
// = graphe auto-agencé `graphite` (surface visuelle `ExcludeSemantics`, zoom/pan
// bornés, aucun drag libre) + vue liste sémantique indentée (surface a11y de
// référence), partageant un `nodeContentBuilder` injectable (défaut sûr sans
// dépendance à `zcrud_markdown`). Lecture seule : interactions remontées par
// callback, état de vue local en `ValueNotifier` (aucun gestionnaire d'état).
export 'src/presentation/z_mindmap_list_view.dart';
// COMBLEMENT ES-7.2 (OQ-S5, AD-28/AD-4/AD-7) : seam rich-text OPT-IN
// `ZMindmapMarkdownContent` — adaptateur MINCE composant `ZMarkdownReader` +
// `ZDeltaCodec` identité de `zcrud_markdown` (aucun nouveau codec, aucune
// heuristique ; `content` de nœud reste texte brut, le rich vit dans le slot
// AD-4 opt-in). Défaut de la vue = texte brut (autres apps non forcées).
export 'src/presentation/z_mindmap_markdown_content.dart';
// SU-12 (FR-SU17, AD-40/AD-28/AD-7) : pendant ÉDITION du seam rich-text —
// adaptateur MINCE `ZMindmapMarkdownEditField` composant `ZMarkdownField` (voie
// `ctx`) + `ZDeltaCodec` identité, écrivant le payload rich dans le slot AD-4
// `extra[slotKey]` (le MÊME que lit `ZMindmapMarkdownContent`). Injecté via
// `ZMindmapOutlineEditor.editFieldBuilder` ; `label`/`content` restent plain.
export 'src/presentation/z_mindmap_markdown_edit_field.dart';
export 'src/presentation/z_mindmap_node_card.dart';
// Présentation E10-3 (FR-19, AD-1/AD-2/AD-13/AD-15/FR-26) : éditeur outline
// CORRIGÉ = liste indentée éditable dont la SAUVEGARDE applique réellement les
// modifications (correction par conception du bug lex, dette n°5). La forêt du
// `ZMindmapOutlineController` (ChangeNotifier pur) est la source de vérité
// unique, mutée en continu via `ZMindmapTreeOps` ; `onSave` émet exactement la
// forêt mutée. Rebuild granulaire (TextEditingController stable keyé par id,
// zéro perte de focus, SM-1), libellés a11y externalisés, thème injecté.
export 'src/presentation/z_mindmap_outline_controller.dart';
export 'src/presentation/z_mindmap_outline_editor.dart';
export 'src/presentation/z_mindmap_outline_labels.dart';
export 'src/presentation/z_mindmap_view.dart';
export 'src/presentation/z_mindmap_view_config.dart';
// COMBLEMENTS ES-7.2 (SM-S4, AD-2/AD-13/AD-15/FR-26) : contrôles user-facing de
// la vue (zoom piloté/clampé, compact, plein-écran, super-racine) via un
// `ZMindmapViewController` pur-Flutter + libellés a11y externalisés
// (`ZMindmapViewLabels`). Tout est OPT-IN (contrôleur optionnel) : défaut = E10.
export 'src/presentation/z_mindmap_view_controls.dart';
