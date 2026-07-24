/// Éditeur outline `ZMindmapOutlineEditor` (Story E10-3, FR-19).
///
/// **Liste indentée éditable** d'une forêt `ZMindmap` dont la **sauvegarde
/// applique RÉELLEMENT les modifications** (correction du bug lex — dette n°5) :
/// la forêt vit dans un [ZMindmapOutlineController] (source de vérité unique),
/// mutée en continu via `ZMindmapTreeOps`, et `onSave` émet **exactement**
/// `controller.forest`. Aucun chemin ne re-persiste l'arbre d'origine.
///
/// **Réactivité Flutter-native (AD-2/AD-15)** : aucun gestionnaire d'état ; le
/// contrôleur est un `ChangeNotifier` pur. Rebuild **granulaire** (SM-1) : une
/// frappe de `label`/`content` ne notifie pas → seul le champ concerné se met à
/// jour (controller `TextEditingController` stable keyé par `id`, jamais recréé,
/// zéro perte de focus) ; seules les mutations **structurelles** (add/delete/
/// indent/outdent/reorder) reconstruisent l'outline via `ListView.builder`.
///
/// **AD-13** : indentation `EdgeInsetsDirectional`, `TextAlign.start`, `Semantics`
/// externalisés ([ZMindmapOutlineLabels]), cibles ≥ 48 dp. **FR-26** : toutes les
/// couleurs/espacements viennent de `ZcrudTheme.of(context)` (aucun littéral).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_mindmap_node.dart';
import 'z_mindmap_outline_controller.dart';
import 'z_mindmap_outline_labels.dart';
import 'z_mindmap_view_config.dart';

/// Callback recevant une forêt `ZMindmapNode` (sauvegarde / changement).
typedef ZMindmapForestCallback = void Function(List<ZMindmapNode> forest);

/// Éditeur outline indenté et éditable d'une forêt de cartes mentales.
///
/// Par défaut, crée et possède un [ZMindmapOutlineController] interne (initialisé
/// depuis [roots]) qu'il `dispose`. Un contrôleur peut être injecté via
/// [controller] (l'appelant en garde alors la propriété et le cycle de vie).
class ZMindmapOutlineEditor extends StatefulWidget {
  /// Construit l'éditeur sur une forêt initiale [roots] (contrôleur interne).
  const ZMindmapOutlineEditor({
    this.roots = const <ZMindmapNode>[],
    this.controller,
    this.onSave,
    this.onChanged,
    this.labels = const ZMindmapOutlineLabels(),
    this.config = const ZMindmapViewConfig(),
    this.editContentField = true,
    this.editFieldBuilder,
    this.padding,
    super.key,
  });

  /// Forêt initiale (ignorée si [controller] est fourni).
  final List<ZMindmapNode> roots;

  /// Contrôleur injecté optionnel (sinon interne, créé/disposé par le widget).
  final ZMindmapOutlineController? controller;

  /// Émis (avec la forêt mutée) au tap sur « enregistrer ». `null` → pas de
  /// bouton d'enregistrement (mode piloté par [onChanged] ou contrôleur externe).
  final ZMindmapForestCallback? onSave;

  /// Émis à **chaque** modification (édition de texte ET mutation structurelle),
  /// pour un mode auto-save. Toujours appelé avec la forêt courante mutée.
  final ZMindmapForestCallback? onChanged;

  /// Libellés a11y externalisés (repli neutre non-nul).
  final ZMindmapOutlineLabels labels;

  /// Configuration de layout (indentStep, minTapTarget ≥ 48 dp).
  final ZMindmapViewConfig config;

  /// Affiche un second champ pour éditer `content` (texte brut multiligne).
  final bool editContentField;

  /// **Slot d'édition de champ injectable** (SU-12, AD-40). `null` (défaut) ⇒
  /// repli `TextField` texte brut ACTUEL (aucune régression). Fourni ⇒ **label
  /// ET content** sont rendus par ce builder (ex.
  /// `ZMindmapMarkdownEditField.builder(slotKey: …)` pour l'édition rich-text).
  /// Les `TextEditingController` stables et la voie d'écriture texte brut restent
  /// inchangés (SM-1) ; l'adaptateur riche écrit un slot AD-4 séparé (`extra`).
  final ZMindmapEditFieldBuilder? editFieldBuilder;

  /// Marge externe optionnelle de la liste (directionnelle recommandée).
  final EdgeInsetsGeometry? padding;

  @override
  State<ZMindmapOutlineEditor> createState() => _ZMindmapOutlineEditorState();
}

class _ZMindmapOutlineEditorState extends State<ZMindmapOutlineEditor> {
  // CR-LEX-20 : NON `late final`. Un `State` survit au remplacement de son
  // widget ; figer le contrôleur à la construction rendait tout contrôleur
  // injecté ensuite **inerte** — l'éditeur continuait d'écouter et de muter
  // l'ancien, sans erreur ni signal. C'est le défaut AD-2 que ce socle existe
  // pour éliminer, dans l'un de ses propres widgets.
  late ZMindmapOutlineController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _adopt(widget.controller);
  }

  /// Adopte [injected] (propriété à l'appelant) ou en crée un possédé.
  void _adopt(ZMindmapOutlineController? injected) {
    if (injected != null) {
      _controller = injected;
      _ownsController = false;
    } else {
      _controller = ZMindmapOutlineController(initialForest: widget.roots);
      _ownsController = true;
    }
  }

  /// CR-LEX-20 — prend en compte un contrôleur **remplacé** par l'appelant.
  ///
  /// Règle de propriété, et c'est elle qui rend le correctif sûr :
  /// - on ne `dispose` **QUE** ce qu'on possède. Un contrôleur injecté
  ///   appartient à l'appelant : le libérer parce qu'il en fournit un autre
  ///   détruirait un objet dont on n'a pas la charge ;
  /// - passer d'un contrôleur injecté à `null` recrée un contrôleur **possédé**
  ///   (l'éditeur redevient autonome), sans toucher à l'ancien.
  @override
  void didUpdateWidget(ZMindmapOutlineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.controller, oldWidget.controller)) return;
    final previous = _controller;
    final ownedPrevious = _ownsController;
    _adopt(widget.controller);
    // L'ancien n'est libéré que s'il était POSSÉDÉ et n'est pas réutilisé.
    if (ownedPrevious && !identical(previous, _controller)) previous.dispose();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  /// Aplatit la forêt en profondeur-d'abord (une ligne par nœud, ordre stable).
  static List<ZMindmapNode> _flatten(List<ZMindmapNode> roots) {
    final out = <ZMindmapNode>[];
    void visit(ZMindmapNode node) {
      out.add(node);
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final root in roots) {
      visit(root);
    }
    return out;
  }

  void _notifyChanged() => widget.onChanged?.call(_controller.forest);

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _OutlineToolbar(
          labels: widget.labels,
          config: widget.config,
          theme: theme,
          onAddRoot: () {
            _controller.addRoot();
            _notifyChanged();
          },
          onSave: widget.onSave == null
              ? null
              : () => widget.onSave!(_controller.forest),
        ),
        Expanded(
          // Point d'écoute STRUCTUREL unique : ne se reconstruit qu'aux mutations
          // structurelles (add/delete/indent/outdent/reorder). Une frappe de
          // texte ne notifie pas → l'outline n'est PAS reconstruit (SM-1).
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final flat = _flatten(_controller.forest);
              return ListView.builder(
                padding: widget.padding,
                itemCount: flat.length,
                itemBuilder: (context, index) {
                  final node = flat[index];
                  return _OutlineRow(
                    // ValueKey stable par id : Flutter préserve l'état (focus,
                    // sélection) du champ même quand l'ordre aplati change.
                    key: ValueKey<String>('zmindmap-outline-${node.id}'),
                    node: node,
                    controller: _controller,
                    labels: widget.labels,
                    config: widget.config,
                    theme: theme,
                    editContentField: widget.editContentField,
                    editFieldBuilder: widget.editFieldBuilder,
                    onStructuralChange: _notifyChanged,
                    onTextChange: _notifyChanged,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Barre d'outils supérieure : « ajouter une racine » (toujours) + « enregistrer »
/// (si `onSave`). Affordance d'ajout accessible même sur forêt vide (AC1).
class _OutlineToolbar extends StatelessWidget {
  const _OutlineToolbar({
    required this.labels,
    required this.config,
    required this.theme,
    required this.onAddRoot,
    required this.onSave,
  });

  final ZMindmapOutlineLabels labels;
  final ZMindmapViewConfig config;
  final ZcrudTheme theme;
  final VoidCallback onAddRoot;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.gapM,
        vertical: theme.gapS,
      ),
      child: Row(
        children: <Widget>[
          _OutlineActionButton(
            label: labels.addRoot,
            icon: Icons.add_box_outlined,
            config: config,
            theme: theme,
            onTap: onAddRoot,
          ),
          const Spacer(),
          if (onSave != null)
            _OutlineActionButton(
              label: labels.save,
              icon: Icons.save_outlined,
              config: config,
              theme: theme,
              onTap: onSave!,
            ),
        ],
      ),
    );
  }
}

/// Une ligne éditable de l'outline (un nœud).
///
/// Indentation directionnelle dérivée de `level` ; champ `label` (+ `content`
/// optionnel) sur `TextEditingController` STABLE du contrôleur ; barre d'actions.
class _OutlineRow extends StatelessWidget {
  const _OutlineRow({
    required this.node,
    required this.controller,
    required this.labels,
    required this.config,
    required this.theme,
    required this.editContentField,
    required this.editFieldBuilder,
    required this.onStructuralChange,
    required this.onTextChange,
    super.key,
  });

  final ZMindmapNode node;
  final ZMindmapOutlineController controller;
  final ZMindmapOutlineLabels labels;
  final ZMindmapViewConfig config;
  final ZcrudTheme theme;
  final bool editContentField;
  final ZMindmapEditFieldBuilder? editFieldBuilder;
  final VoidCallback onStructuralChange;
  final VoidCallback onTextChange;

  @override
  Widget build(BuildContext context) {
    final indent = node.level * config.indentStep;

    // Chaque mutation structurelle passe par le contrôleur puis notifie l'hôte.
    void structural(void Function() op) {
      op();
      onStructuralChange();
    }

    // Slot d'édition injectable (SU-12, AD-40) : `label` ET `content` passent par
    // `editFieldBuilder ?? _defaultEditField`. Le défaut reproduit À L'IDENTIQUE
    // le `TextField` historique (mêmes controllers stables, hints, bordures,
    // ≥ 48 dp, TextAlign.start) — aucune régression sans injection.
    final builder = editFieldBuilder ?? _defaultEditField;

    Widget field(ZMindmapEditFieldKind kind) {
      final isLabel = kind == ZMindmapEditFieldKind.label;
      final ctx = ZMindmapEditFieldContext(
        node: node,
        kind: kind,
        // Controller STABLE keyé par `node.id` (SM-1/AD-2 — jamais recréé).
        controller: isLabel
            ? controller.labelControllerFor(node)
            : controller.contentControllerFor(node),
        value: isLabel ? node.label : (node.content ?? ''),
        onChanged: (value) {
          // Voie texte brut « live » : met à jour la forêt SANS reconstruire
          // l'outline (le controller stable porte déjà le texte) — zéro focus.
          if (isLabel) {
            controller.editLabel(node.id, value);
          } else {
            controller.editContent(node.id, value);
          }
          onTextChange();
        },
        // Voie slot AD-4 (`extra`) : édition riche — écrit un slot séparé, laisse
        // `label`/`content` en texte brut (OQ-S5/AD-28). SANS notifier (SM-1).
        writeRichSlot: (slotKey, ops) {
          controller.editRichSlot(node.id, slotKey, ops);
          onTextChange();
        },
        hint: isLabel ? labels.labelHint : labels.contentHint,
        config: config,
        theme: theme,
      );
      return builder(context, ctx);
    }

    final labelField = field(ZMindmapEditFieldKind.label);

    final contentField = !editContentField
        ? null
        : Padding(
            padding: EdgeInsetsDirectional.only(top: theme.gapS),
            child: field(ZMindmapEditFieldKind.content),
          );

    final actions = Wrap(
      spacing: theme.gapS,
      runSpacing: theme.gapS,
      children: <Widget>[
        _OutlineActionButton(
          label: labels.addChild,
          icon: Icons.subdirectory_arrow_right,
          config: config,
          theme: theme,
          onTap: () => structural(() => controller.addChild(node.id)),
        ),
        _OutlineActionButton(
          label: labels.addSibling,
          icon: Icons.add,
          config: config,
          theme: theme,
          onTap: () => structural(() => controller.addSibling(node.id)),
        ),
        _OutlineActionButton(
          label: labels.indent,
          icon: Icons.format_indent_increase,
          config: config,
          theme: theme,
          onTap: () => structural(() => controller.indent(node.id)),
        ),
        _OutlineActionButton(
          label: labels.outdent,
          icon: Icons.format_indent_decrease,
          config: config,
          theme: theme,
          onTap: () => structural(() => controller.outdent(node.id)),
        ),
        _OutlineActionButton(
          label: labels.moveUp,
          icon: Icons.arrow_upward,
          config: config,
          theme: theme,
          onTap: () => structural(() => controller.moveUp(node.id)),
        ),
        _OutlineActionButton(
          label: labels.moveDown,
          icon: Icons.arrow_downward,
          config: config,
          theme: theme,
          onTap: () => structural(() => controller.moveDown(node.id)),
        ),
        _OutlineActionButton(
          label: labels.delete,
          icon: Icons.delete_outline,
          config: config,
          theme: theme,
          onTap: () => structural(() => controller.deleteNode(node.id)),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: indent,
        top: theme.gapS,
        bottom: theme.gapS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          labelField,
          if (contentField != null) contentField,
          Padding(
            padding: EdgeInsetsDirectional.only(top: theme.gapS),
            child: actions,
          ),
        ],
      ),
    );
  }
}

/// Slot d'édition **par défaut** (SU-12, AD-40) : le `TextField` texte brut
/// HISTORIQUE, extrait tel quel. `label` = mono-ligne ; `content` = multiligne
/// (`minLines:1`, `maxLines:4`). Mêmes controllers stables (SM-1), mêmes hints/
/// bordures/couleurs thématisées (FR-26), cible ≥ 48 dp, `TextAlign.start` (AD-13).
/// Repli utilisé quand aucun `editFieldBuilder` n'est injecté — AUCUNE régression.
Widget _defaultEditField(BuildContext context, ZMindmapEditFieldContext ctx) {
  final theme = ctx.theme;
  final labelColor =
      theme.labelColor ?? Theme.of(context).colorScheme.onSurface;
  final borderColor =
      theme.fieldBorderColor ?? Theme.of(context).colorScheme.outline;
  final isContent = ctx.kind == ZMindmapEditFieldKind.content;
  return Semantics(
    // Le TextField expose déjà le rôle `textField` (LOW-2 : pas de flag
    // redondant) ; on ne conserve que le label a11y.
    label: ctx.hint,
    child: TextField(
      controller: ctx.controller,
      textAlign: TextAlign.start,
      minLines: isContent ? 1 : null,
      maxLines: isContent ? 4 : 1,
      decoration: InputDecoration(
        hintText: ctx.hint,
        isDense: true,
        // MEDIUM-1 (AD-13) : cible éditable garantie ≥ 48 dp.
        constraints: BoxConstraints(minHeight: ctx.config.minTapTarget),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor),
          borderRadius: BorderRadius.all(theme.radiusS),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(theme.radiusS),
        ),
      ),
      style: TextStyle(color: labelColor),
      onChanged: ctx.onChanged,
    ),
  );
}

/// Bouton d'action a11y (≥ 48 dp, `Semantics` externalisé, icône thématisée).
///
/// La sémantique (label + action `onTap`) est portée par le `Semantics` parent ;
/// l'icône est `ExcludeSemantics` pour éviter tout doublon (patron E10-2).
class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({
    required this.label,
    required this.icon,
    required this.config,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final ZMindmapViewConfig config;
  final ZcrudTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        theme.labelColor ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: config.minTapTarget,
            minHeight: config.minTapTarget,
          ),
          child: Center(
            child: ExcludeSemantics(
              child: Icon(icon, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
