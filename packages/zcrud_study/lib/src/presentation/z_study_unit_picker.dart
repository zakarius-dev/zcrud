/// `ZStudyUnitPicker` — sélecteur arborescent des **conteneurs** de la
/// structure d'étude (organisations, unités, groupes, programmes…).
///
/// ## Ce que ce sélecteur désigne — et ce qu'il ne désigne pas
///
/// 🔴 **La structure académique n'est pas l'arborescence des dossiers.** Une
/// unité d'organisation, un groupe ou un programme disent **à quoi un contenu
/// se rattache** et **dans quelle portée on travaille**. Un dossier dit **où un
/// contenu est rangé**. Les deux arbres coexistent, ne se recouvrent pas et
/// n'ont pas la même durée de vie : on range un dossier dans un autre dossier,
/// jamais dans une unité d'organisation.
///
/// Ce sélecteur sert donc au **rattachement** et à la **portée**. Il ne sert
/// jamais à ranger des dossiers, et il ne **modifie rien** : administrer la
/// structure (créer, renommer, déplacer une unité) n'est pas de son ressort.
///
/// ## Données, pas port
///
/// Le sélecteur reçoit une **valeur immuable** — une forêt de
/// [ZStudyUnitNode] — et rend une [ZStudyRef] par [ZStudyUnitPicker.onSelect].
/// Il n'ouvre aucun flux, n'appelle aucun dépôt et n'attend rien : l'hôte
/// construit la forêt à partir de son instantané, le sélecteur l'affiche. Un
/// arbre vide est un état valide, jamais un chargement.
///
/// ## Ce que l'ontologie change
///
/// Fournie, [ZStudyUnitPicker.ontology] décide de deux choses et de rien
/// d'autre : l'**icône** d'un nœud (`ZStudyKindSpec.iconKey`, résolue par le
/// seam d'icônes du socle) et le fait qu'un nœud soit rendu **feuille** — un
/// `kind` déclaré sans la capacité `hierarchical` n'admet pas de parent, donc
/// n'ouvre pas de sous-arbre. Absente, ou muette sur un `kind`, elle ne
/// restreint rien : l'arbre est celui des données.
///
/// ## Apparence
///
/// Sous le profil de référence `legacy`, chaque nœud porte une **pastille** de
/// la palette signature, dérivée de l'identité de la référence. Sous le profil
/// `neutral`, la pastille n'est pas montée du tout — aucune couleur de
/// référence n'est peinte. Aucun libellé, aucune couleur et aucune icône ne
/// sont codés en dur (FR-26) ; toutes les API de placement sont
/// directionnelles (AD-13).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZGradientSpec, zLegacyOr, zResolveAdornmentIcon, zSignatureGradientFor;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show
        ZStudyKindSpec,
        ZStudyOntology,
        ZStudyRef,
        kZStudyCapabilityHierarchical,
        zHasCapability;

/// Largeur d'indentation appliquée **par niveau** de profondeur.
///
/// 20 dp : assez pour lire une hiérarchie sur une largeur de téléphone sans
/// que le quatrième niveau ne laisse plus de place au libellé. Remplaçable par
/// [ZStudyUnitPicker.indentWidth].
const double zStudyUnitPickerIndentWidth = 20;

/// Hauteur minimale d'une rangée — cible tactile (AD-13).
const double zStudyUnitPickerRowHeight = 48;

/// Nœud immuable de la forêt affichée par [ZStudyUnitPicker].
///
/// Un nœud est **une référence et ses enfants** : rien d'autre. Le libellé,
/// le code et le `kind` viennent de l'instantané porté par [ref] — le
/// sélecteur n'en résout aucun.
@immutable
class ZStudyUnitNode {
  /// Construit un nœud. [children] vide = feuille.
  const ZStudyUnitNode({
    required this.ref,
    this.children = const <ZStudyUnitNode>[],
  });

  /// Référence désignée par ce nœud — celle que [ZStudyUnitPicker.onSelect]
  /// rend **à l'identique** lorsqu'il est choisi.
  final ZStudyRef ref;

  /// Enfants du nœud, dans l'ordre d'affichage voulu par l'hôte.
  final List<ZStudyUnitNode> children;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyUnitNode &&
          ref == other.ref &&
          _nodesEqual(children, other.children);

  @override
  int get hashCode => Object.hash(ref, Object.hashAll(children));

  static bool _nodesEqual(List<ZStudyUnitNode> a, List<ZStudyUnitNode> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Rangée aplatie rendue par le sélecteur : une référence et sa profondeur.
@immutable
class ZStudyUnitRow {
  /// Construit une rangée.
  const ZStudyUnitRow({
    required this.node,
    required this.depth,
    required this.isLeaf,
  });

  /// Nœud d'origine.
  final ZStudyUnitNode node;

  /// Profondeur dans la forêt, `0` pour une racine.
  final int depth;

  /// `true` si la rangée n'ouvre aucun sous-arbre — soit qu'elle n'ait pas
  /// d'enfant, soit que l'ontologie déclare son `kind` non hiérarchique.
  final bool isLeaf;
}

/// Sélecteur arborescent de conteneurs de structure d'étude.
class ZStudyUnitPicker extends StatefulWidget {
  /// Construit un sélecteur. Seuls [roots] et [onSelect] sont requis.
  const ZStudyUnitPicker({
    required this.roots,
    required this.onSelect,
    this.ontology,
    this.selectedRef,
    this.searchEnabled = true,
    this.searchHintText,
    this.searchSemanticLabel,
    this.labelBuilder,
    this.indentWidth = zStudyUnitPickerIndentWidth,
    this.shrinkWrap = false,
    super.key,
  });

  /// Racines de la forêt affichée. Vide ⇒ aucune rangée, aucun état de
  /// chargement.
  final List<ZStudyUnitNode> roots;

  /// Appelée avec la **référence exacte** du nœud choisi.
  final ValueChanged<ZStudyRef> onSelect;

  /// Ontologie consultée pour l'icône et la nature feuille d'un `kind`.
  /// `null` ⇒ aucune contrainte, aucune icône dérivée.
  final ZStudyOntology? ontology;

  /// Référence actuellement retenue, comparée par identité (`type` + `id`) ;
  /// `null` ⇒ aucune rangée n'est marquée.
  final ZStudyRef? selectedRef;

  /// Monte le champ de recherche locale (défaut `true`).
  final bool searchEnabled;

  /// Texte d'aide du champ de recherche — `null` ⇒ aucun (le socle ne fournit
  /// aucun libellé, FR-26).
  final String? searchHintText;

  /// Libellé d'accessibilité du champ de recherche, `null` ⇒ aucun.
  final String? searchSemanticLabel;

  /// Libellé d'un nœud. `null` ⇒ `ZStudyRef.label`, puis `ZStudyRef.code`,
  /// puis l'identifiant — le socle n'invente aucun libellé et n'en traduit
  /// aucun.
  final String Function(ZStudyRef ref)? labelBuilder;

  /// Indentation appliquée par niveau de profondeur.
  final double indentWidth;

  /// Passé tel quel à la liste virtualisée, pour un montage dans un parent
  /// non borné.
  final bool shrinkWrap;

  @override
  State<ZStudyUnitPicker> createState() => _ZStudyUnitPickerState();
}

class _ZStudyUnitPickerState extends State<ZStudyUnitPicker> {
  /// Requête de recherche : `ValueListenable` ciblée — le champ de saisie
  /// n'est jamais reconstruit par la frappe (AD-2, focus conservé).
  final ValueNotifier<String> _query = ValueNotifier<String>('');
  late final TextEditingController _searchController;

  /// Nœuds explicitement REPLIÉS. Le défaut est déplié : l'arbre rendu est
  /// alors exactement l'arbre des données.
  final Set<String> _collapsed = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _query.dispose();
    super.dispose();
  }

  static String _identity(ZStudyRef ref) =>
      '${ref.type.length}:${ref.type}:${ref.id}';

  String _label(ZStudyRef ref) =>
      widget.labelBuilder?.call(ref) ?? ref.label ?? ref.code ?? ref.id;

  bool _isLeaf(ZStudyUnitNode node) {
    if (node.children.isEmpty) return true;
    final String? kind = node.ref.kind;
    if (kind == null) return false;
    return !zHasCapability(
      widget.ontology,
      kind,
      kZStudyCapabilityHierarchical,
    );
  }

  /// Aplatit la forêt en pré-ordre. Sous une requête non vide, l'arbre entier
  /// est parcouru (le repli ne masque rien) et seules les rangées dont le
  /// libellé ou le code contient la requête sont rendues.
  List<ZStudyUnitRow> _rows(String query) {
    final String needle = query.trim().toLowerCase();
    final bool searching = needle.isNotEmpty;
    final out = <ZStudyUnitRow>[];

    void walk(ZStudyUnitNode node, int depth) {
      final bool leaf = _isLeaf(node);
      if (!searching || _matches(node.ref, needle)) {
        out.add(ZStudyUnitRow(node: node, depth: depth, isLeaf: leaf));
      }
      if (leaf) return;
      if (!searching && _collapsed.contains(_identity(node.ref))) return;
      for (final ZStudyUnitNode child in node.children) {
        walk(child, depth + 1);
      }
    }

    for (final ZStudyUnitNode root in widget.roots) {
      walk(root, 0);
    }
    return out;
  }

  bool _matches(ZStudyRef ref, String needle) {
    if (_label(ref).toLowerCase().contains(needle)) return true;
    final String? code = ref.code;
    return code != null && code.toLowerCase().contains(needle);
  }

  void _toggle(ZStudyUnitNode node) {
    final String key = _identity(node.ref);
    setState(() {
      if (!_collapsed.remove(key)) _collapsed.add(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.searchEnabled) _buildSearchField(context),
        Flexible(
          child: ValueListenableBuilder<String>(
            valueListenable: _query,
            builder: (BuildContext context, String query, Widget? _) {
              final List<ZStudyUnitRow> rows = _rows(query);
              return ListView.builder(
                key: const ValueKey<String>('zStudyUnitPicker.list'),
                shrinkWrap: widget.shrinkWrap,
                itemCount: rows.length,
                itemBuilder: (BuildContext context, int index) =>
                    _buildRow(context, rows[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context) {
    final IconData? icon = zResolveAdornmentIcon(context, 'search');
    final String? semanticLabel = widget.searchSemanticLabel;
    final Widget field = TextField(
      key: const ValueKey<String>('zStudyUnitPicker.search'),
      controller: _searchController,
      decoration: InputDecoration(
        hintText: widget.searchHintText,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      onChanged: (String value) => _query.value = value,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
      child: semanticLabel == null
          ? field
          : Semantics(label: semanticLabel, textField: true, child: field),
    );
  }

  Widget _buildRow(BuildContext context, ZStudyUnitRow row) {
    final ZStudyRef ref = row.node.ref;
    final String label = _label(ref);
    final ThemeData theme = Theme.of(context);
    final bool selected = widget.selectedRef?.sameTarget(ref) ?? false;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      container: true,
      child: InkWell(
        key: ValueKey<String>('zStudyUnitPicker.row:${ref.id}'),
        onTap: () => widget.onSelect(ref),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: zStudyUnitPickerRowHeight,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                key: ValueKey<String>('zStudyUnitPicker.indent:${ref.id}'),
                width: row.depth * widget.indentWidth,
              ),
              _buildExpander(context, row),
              ..._buildBadge(context, ref),
              ..._buildKindIcon(context, ref),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 12, 8),
                  child: Text(
                    label,
                    textAlign: TextAlign.start,
                    overflow: TextOverflow.ellipsis,
                    style: selected
                        ? theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          )
                        : theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpander(BuildContext context, ZStudyUnitRow row) {
    if (row.isLeaf) {
      return const SizedBox(
        width: zStudyUnitPickerRowHeight,
        height: zStudyUnitPickerRowHeight,
      );
    }
    final bool collapsed = _collapsed.contains(_identity(row.node.ref));
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final IconData icon = collapsed
        ? (rtl ? Icons.chevron_left : Icons.chevron_right)
        : Icons.expand_more;
    return SizedBox(
      width: zStudyUnitPickerRowHeight,
      height: zStudyUnitPickerRowHeight,
      child: IconButton(
        key: ValueKey<String>('zStudyUnitPicker.expander:${row.node.ref.id}'),
        icon: Icon(icon),
        onPressed: () => _toggle(row.node),
      ),
    );
  }

  /// Pastille de la palette signature — montée sous le profil `legacy`, pas
  /// montée du tout sous `neutral`.
  List<Widget> _buildBadge(BuildContext context, ZStudyRef ref) {
    final ZGradientSpec? spec = zLegacyOr<ZGradientSpec?>(
      context,
      zSignatureGradientFor(_identity(ref)),
    );
    if (spec == null) return const <Widget>[];
    return <Widget>[
      Container(
        key: ValueKey<String>('zStudyUnitPicker.badge:${ref.id}'),
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          gradient: spec.gradient,
          shape: BoxShape.circle,
        ),
      ),
    ];
  }

  List<Widget> _buildKindIcon(BuildContext context, ZStudyRef ref) {
    final String? kind = ref.kind;
    if (kind == null) return const <Widget>[];
    final ZStudyKindSpec? spec = widget.ontology?.kindSpec(kind);
    final String? iconKey = spec?.iconKey;
    if (iconKey == null) return const <Widget>[];
    final IconData? icon = zResolveAdornmentIcon(context, iconKey);
    if (icon == null) return const <Widget>[];
    return <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 8),
        child: Icon(
          icon,
          key: ValueKey<String>('zStudyUnitPicker.icon:${ref.id}'),
          size: 18,
        ),
      ),
    ];
  }
}
