/// `DynamicEdition` — formulaire d'édition de **référence** assemblant N champs à
/// partir d'un `ZFormController` (AD-2, OBJECTIF PRODUIT N°1 / SM-1).
///
/// origine: E3-1 porte la preuve **plein-formulaire** de SM-1 (≥ 30 champs, ≥ 3
/// sections, 100 caractères). Le montage garantit par conception qu'une frappe
/// ne reconstruit QUE le champ courant :
/// - le `build` du formulaire n'observe QUE des canaux **structurels**
///   (`controller.visibleFields` + l'état de repli local `_collapsed`) via un
///   `ListenableBuilder` — il n'écoute JAMAIS une tranche de valeur ; une frappe
///   (qui ne touche aucun de ces canaux) ne le ré-exécute donc pas ;
/// - les champs sont montés via **`ListView.builder`** (jamais
///   `ListView(children: [...])`) — chaque champ porte `key: ValueKey(name)`
///   (place stable → réutilisation d'`Element`/`State` au rebuild, UJ-2) ;
/// - **aucun** `setState` de niveau formulaire dans la voie de frappe.
///
/// **E3-4** ajoute AUTOUR de ce cœur, sans jamais élargir la frontière de rebuild :
/// - **Champs conditionnels** (`ZFieldSpec.condition`) : un sélecteur de
///   visibilité **dérivé** ([_ConditionalVisibilityBinder]-like, fondu dans le
///   `State`) abonné UNIQUEMENT aux **champs de garde** (union des `field`
///   référencés par les conditions — [zGuardFieldsOf]) recalcule l'ensemble
///   visible en **ordre canonique** et pilote `setVisibleFields` (no-op si
///   inchangé). Une frappe sur un champ **non-garde** ne déclenche AUCUN recalcul.
/// - **Sections repliables** ([ZEditionSection.collapsible]) : en-tête accessible
///   (`Semantics(button, expanded, label)`, cible ≥ 48 dp, `EdgeInsetsDirectional`)
///   ; l'état d'expansion vit dans le `State` (canal `_collapsed`), survit à un
///   rebuild structurel, et n'affecte PAS `visibleFields` (orthogonal, AC9) ; le
///   repli masque VISUELLEMENT les membres sans détruire leurs tranches.
/// - **Mode lecture** (`readOnly` global) : chaque champ est rendu via une spec
///   effective `spec.copyWith(readOnly: true)` (réutilise le respect de
///   `field.readOnly` déjà présent dans toutes les familles). `showIfNull:false`
///   masque en lecture les champs vides (sans effet hors mode lecture).
/// - **Grille responsive 12 colonnes** ([layout]) : chaque champ reçoit un
///   [ZResponsiveSpan] ; disposition via [ZResponsiveGrid] (reflow par
///   breakpoint, gouttières directionnelles).
///
/// **Contrat de reflet de valeur EXTERNE (documenté, câblage reporté E3-6/E7)** :
/// l'état DÉRIVÉ d'E3-4 (visibilité/lecture/showIfNull) relit `valueOf`/la tranche
/// à CHAQUE calcul — il reflète donc nativement toute écriture externe d'un champ
/// de garde, sans buffer interne. Le write-back des widgets à buffer d'édition
/// (texte/signature/sous-liste) se fera par re-amorçage clé-de-révision
/// (`ValueKey(name + reseedRevision)`) appliqué **hors focus** — livré par E3-6/E7.
library;

import 'package:flutter/material.dart';

import '../../domain/edition/z_condition_evaluator.dart';
import '../../domain/edition/z_field_spec.dart';
import '../z_form_controller.dart';
import 'z_field_widget.dart';
import 'z_responsive_grid.dart';

/// Constructeur d'un widget de champ à partir de sa [ZFieldSpec] et du
/// [ZFormController]. Seam d'extension : à défaut, [DynamicEdition] rend le
/// dispatcher par type [ZFieldWidget] (E3-3a). La place stable
/// (`ValueKey(field.name)`) est garantie par [DynamicEdition] via `KeyedSubtree`
/// — un builder custom n'a donc PAS à la poser (garde L3/AC7).
typedef ZEditionFieldBuilder = Widget Function(
  BuildContext context,
  ZFormController controller,
  ZFieldSpec field,
);

/// Section **visuelle** d'un formulaire : un titre et l'ensemble des noms de
/// champs qu'elle regroupe. Peut être **repliable** ([collapsible], E3-4).
@immutable
class ZEditionSection {
  /// Construit une section de titre [title] regroupant les champs [fields].
  ///
  /// [collapsible] (défaut `false`) rend l'en-tête actionnable (accordéon) ;
  /// [initiallyExpanded] (défaut `true`) fixe l'état de repli initial. Une
  /// section non repliable ignore [initiallyExpanded].
  const ZEditionSection({
    required this.title,
    required this.fields,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  /// Titre affiché de la section (clé l10n ou littéral — résolu côté hôte).
  final String title;

  /// Noms de champs appartenant à la section (ordre indicatif ; l'ordre effectif
  /// suit `visibleFields`).
  final List<String> fields;

  /// La section est-elle repliable (en-tête accordéon accessible — E3-4) ?
  final bool collapsible;

  /// État de repli initial d'une section repliable (`true` = dépliée).
  final bool initiallyExpanded;
}

/// Assemble un formulaire d'édition réactif **par tranche** depuis un
/// [controller] et la liste des [fields] connus, regroupés en [sections]
/// visuelles.
class DynamicEdition extends StatefulWidget {
  /// Construit le formulaire de référence.
  const DynamicEdition({
    required this.controller,
    required this.fields,
    this.sections = const <ZEditionSection>[],
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.fieldBuilder,
    this.readOnly = false,
    this.layout = const <String, ZResponsiveSpan>{},
    this.gridGutter = 8,
    this.onStructuralBuild,
    super.key,
  });

  /// Contrôleur détenant l'état (créé/possédé par l'hôte ; jamais recréé ici).
  final ZFormController controller;

  /// Catalogue des champs connus (source des [ZFieldSpec] par nom).
  final List<ZFieldSpec> fields;

  /// Sections visuelles (en-têtes ; repliables si `collapsible`). Vide = liste
  /// plate.
  final List<ZEditionSection> sections;

  /// Marge du `ListView` (héritée par l'hôte ; défaut : aucune).
  final EdgeInsetsGeometry? padding;

  /// `ListView.shrinkWrap` — pour imbrication dans un scroll parent.
  final bool shrinkWrap;

  /// `ListView.physics` — pour imbrication dans un scroll parent.
  final ScrollPhysics? physics;

  /// Seam de rendu de champ. À défaut : le dispatcher par type [ZFieldWidget]
  /// (E3-3a). La place stable est garantie par [DynamicEdition] (KeyedSubtree).
  final ZEditionFieldBuilder? fieldBuilder;

  /// **Mode lecture global** (E3-4) : quand `true`, chaque champ est rendu non
  /// éditable via une spec effective `readOnly: true` (le per-champ reste
  /// respecté hors mode global). Active aussi le filtre `showIfNull`.
  final bool readOnly;

  /// **Grille 12 colonnes** (E3-4) : span responsif par nom de champ. Vide = pas
  /// de grille (disposition en colonne pleine largeur — compat ascendante).
  final Map<String, ZResponsiveSpan> layout;

  /// Gouttière (dp) de la grille responsive (quand [layout] est non vide).
  final double gridGutter;

  /// Hook d'instrumentation : appelé à chaque (re)build **structurel** — compteur
  /// de build de niveau formulaire pour SM-1 (reste inchangé pendant la saisie).
  @visibleForTesting
  final VoidCallback? onStructuralBuild;

  @override
  State<DynamicEdition> createState() => _DynamicEditionState();
}

class _DynamicEditionState extends State<DynamicEdition> {
  /// Index `name → spec` (identité de valeur, recalculé si [widget.fields] change).
  late Map<String, ZFieldSpec> _specByName;

  /// Index `name → titre de section` (pour l'interleave des en-têtes).
  late Map<String, String> _sectionByField;

  /// Champs de **garde** : union des `field` référencés par les conditions. Le
  /// sélecteur de visibilité s'abonne UNIQUEMENT à ceux-ci (AC3, SM-1).
  late Set<String> _guardFields;

  /// Tranches réactives des champs de garde auxquelles [_onGuardChanged] est
  /// abonné (référence stable pour le retrait en `dispose`/`didUpdateWidget`).
  final List<Listenable> _guardListenables = <Listenable>[];

  /// Canal STRUCTUREL local : titres des sections **repliées**. Piloté par les
  /// en-têtes ; orthogonal à `controller.visibleFields` (AC9). Vit dans le
  /// `State` ⇒ survit aux rebuilds structurels ET au recyclage `ListView.builder`.
  late final ValueNotifier<Set<String>> _collapsed;

  /// Listenable fusionné observé par le `build` structurel : `visibleFields`
  /// (conditionnel) + `_collapsed` (repli). Aucune tranche de valeur.
  late Listenable _structural;

  @override
  void initState() {
    super.initState();
    _collapsed = ValueNotifier<Set<String>>(_initialCollapsed());
    _rebuildIndexes();
    _bindGuards();
    _structural = Listenable.merge(<Listenable?>[
      widget.controller.visibleFields,
      _collapsed,
    ]);
    // Amorçage : calcule la visibilité initiale depuis les valeurs du controller
    // (uniquement s'il existe des conditions — sinon on respecte l'ensemble
    // visible fourni par l'hôte, compat ascendante).
    if (_guardFields.isNotEmpty) {
      _recomputeVisibility();
    }
  }

  @override
  void didUpdateWidget(DynamicEdition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    final fieldsChanged = !identical(oldWidget.fields, widget.fields);
    if (controllerChanged || fieldsChanged) {
      _rebuildIndexes();
      _bindGuards();
      if (controllerChanged) {
        _structural = Listenable.merge(<Listenable?>[
          widget.controller.visibleFields,
          _collapsed,
        ]);
      }
      if (_guardFields.isNotEmpty) {
        _recomputeVisibility();
      }
    }
  }

  Set<String> _initialCollapsed() => <String>{
        for (final s in widget.sections)
          if (s.collapsible && !s.initiallyExpanded) s.title,
      };

  void _rebuildIndexes() {
    _specByName = <String, ZFieldSpec>{
      for (final f in widget.fields) f.name: f,
    };
    _sectionByField = <String, String>{
      for (final s in widget.sections)
        for (final n in s.fields) n: s.title,
    };
    _guardFields = zGuardFieldsOf(widget.fields.map((f) => f.condition));
  }

  /// (Ré)abonne [_onGuardChanged] aux tranches des champs de garde UNIQUEMENT.
  void _bindGuards() {
    for (final l in _guardListenables) {
      l.removeListener(_onGuardChanged);
    }
    _guardListenables.clear();
    for (final g in _guardFields) {
      final l = widget.controller.fieldListenable(g);
      l.addListener(_onGuardChanged);
      _guardListenables.add(l);
    }
  }

  void _onGuardChanged() => _recomputeVisibility();

  /// Recalcule l'ensemble visible = **ordre canonique** de [widget.fields] filtré
  /// par [evaluateZCondition], puis pilote `setVisibleFields` (no-op si inchangé
  /// — AC4). Préserve la PLACE ordinale (réinsertion à l'index canonique — AC5)
  /// et ne détruit JAMAIS de tranche (le controller conserve ses slices).
  void _recomputeVisibility() {
    final next = <String>[
      for (final f in widget.fields)
        if (f.condition == null ||
            evaluateZCondition(f.condition!, widget.controller.valueOf))
          f.name,
    ];
    widget.controller.setVisibleFields(next);
  }

  @override
  void dispose() {
    for (final l in _guardListenables) {
      l.removeListener(_onGuardChanged);
    }
    _guardListenables.clear();
    _collapsed.dispose();
    super.dispose();
  }

  // ── Filtres de présentation (mode lecture) ────────────────────────────────

  /// `true` si une valeur compte comme **vide** pour `showIfNull` : `null` ou
  /// collection/chaîne vide. `false`/`0` NE sont PAS vides (valeurs affichables).
  static bool _isEmptyValue(Object? v) {
    if (v == null) return true;
    if (v is String) return v.isEmpty;
    if (v is Iterable) return v.isEmpty;
    if (v is Map) return v.isEmpty;
    return false;
  }

  /// En mode lecture, masque les champs vides dont `showIfNull == false`. Hors
  /// mode lecture : toujours affiché (AC11).
  bool _renderInReadMode(ZFieldSpec spec) {
    if (!widget.readOnly) return true;
    if (spec.showIfNull) return true;
    return !_isEmptyValue(widget.controller.valueOf(spec.name));
  }

  /// Spec **effective** : force `readOnly` en mode lecture global (réutilise le
  /// respect de `field.readOnly` par les familles — aucune réécriture).
  ZFieldSpec _effective(ZFieldSpec spec) =>
      widget.readOnly && !spec.readOnly ? spec.copyWith(readOnly: true) : spec;

  bool get _grouped =>
      widget.layout.isNotEmpty ||
      widget.sections.any((s) => s.collapsible);

  @override
  Widget build(BuildContext context) {
    // Canaux STRUCTURELS uniquement : ce builder ne se ré-exécute que lorsque
    // l'ensemble visible OU l'état de repli change (jamais sur une frappe).
    return ListenableBuilder(
      listenable: _structural,
      builder: (context, _) {
        widget.onStructuralBuild?.call();
        final visible = widget.controller.visibleFields.value;
        return _grouped ? _buildGrouped(visible) : _buildFlat(visible);
      },
    );
  }

  // ── Rendu PLAT (compat E3-1 : pas de grille, pas de section repliable) ─────

  Widget _buildFlat(List<String> visible) {
    final rows = <_EditionRow>[];
    String? currentSection;
    for (final name in visible) {
      final spec = _specByName[name];
      if (spec == null) continue;
      if (!_renderInReadMode(spec)) continue;
      final section = _sectionByField[name];
      if (section != null && section != currentSection) {
        rows.add(_EditionRow.header(section));
      }
      currentSection = section;
      rows.add(_EditionRow.field(_effective(spec)));
    }

    // Index inverse `Key → position` : permet au `ListView.builder` (sliver
    // paresseux) de RETROUVER l'`Element` d'un champ keyé qui a CHANGÉ d'index
    // (insertion/retrait d'un champ conditionnel voisin) et de PRÉSERVER son
    // `State`/focus (AC6). Sans lui, un champ décalé serait remonté à neuf
    // (focus perdu) — le simple `ValueKey` ne suffit pas dans un sliver lazy.
    final keyIndex = <Key, int>{};
    for (var i = 0; i < rows.length; i++) {
      final k = rows[i].key;
      if (k != null) keyIndex[k] = i;
    }

    return ListView.builder(
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: rows.length,
      findChildIndexCallback: (key) => keyIndex[key],
      itemBuilder: (context, i) => rows[i].build(context, this),
    );
  }

  // ── Rendu GROUPÉ (sections repliables et/ou grille responsive) ────────────

  Widget _buildGrouped(List<String> visible) {
    final visibleSet = visible.toSet();
    final blocks = <Widget>[];

    // Index inverse `Key → position` des BLOCS : comme le chemin plat, il permet
    // au `ListView.builder` (sliver paresseux) de RETROUVER l'`Element` d'un bloc
    // keyé qui a CHANGÉ d'index — bloc « loose » de tête qui bascule (l.369) ou
    // section qui se vide et est sautée (`if (members.isEmpty) continue`) — et de
    // PRÉSERVER le `State`/focus des champs des blocs aval (AC5/AC6/AD-2). Chaque
    // bloc est keyé sur une identité STABLE (`__loose__` / titre de section).
    final blockKeyIndex = <Key, int>{};
    void addBlock(Key key, Widget child) {
      blockKeyIndex[key] = blocks.length;
      blocks.add(KeyedSubtree(key: key, child: child));
    }

    // (1) Champs sans section, dans l'ordre visible (bloc de tête sans en-tête).
    final loose = <ZFieldSpec>[
      for (final name in visible)
        if (_specByName[name] != null &&
            !_sectionByField.containsKey(name) &&
            _renderInReadMode(_specByName[name]!))
          _effective(_specByName[name]!),
    ];
    if (loose.isNotEmpty) {
      addBlock(const ValueKey<String>('block:__loose__'), _membersLayout(loose));
    }

    // (2) Sections dans leur ordre déclaré ; membres filtrés par visibilité +
    //     mode lecture. Une section repliée cache ses membres (slices intacts).
    for (final section in widget.sections) {
      final members = <ZFieldSpec>[
        for (final name in section.fields)
          if (visibleSet.contains(name) &&
              _specByName[name] != null &&
              _renderInReadMode(_specByName[name]!))
            _effective(_specByName[name]!),
      ];
      if (members.isEmpty) continue;

      final expanded =
          !(section.collapsible && _collapsed.value.contains(section.title));

      final header = section.collapsible
          ? _CollapsibleSectionHeader(
              key: ValueKey<String>('section:${section.title}'),
              title: section.title,
              expanded: expanded,
              onToggle: () => _toggleSection(section.title),
            )
          : _SectionHeader(
              key: ValueKey<String>('section:${section.title}'),
              title: section.title,
            );

      addBlock(
        ValueKey<String>('block:section:${section.title}'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            header,
            // Repli = masquage VISUEL sans destruction de slice (les membres ne
            // sont simplement pas montés ; le controller conserve leurs tranches).
            if (expanded) _membersLayout(members),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: blocks.length,
      findChildIndexCallback: (key) => blockKeyIndex[key],
      itemBuilder: (context, i) => blocks[i],
    );
  }

  /// Dispose une liste de champs : en **grille 12 colonnes** si [widget.layout]
  /// est fourni, sinon en colonne pleine largeur. Chaque cellule est keyée
  /// `ValueKey(name)` (place stable NON contournable).
  Widget _membersLayout(List<ZFieldSpec> members) {
    if (widget.layout.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final spec in members) _buildField(context, spec),
        ],
      );
    }
    // Grille : la place stable est portée par les CELLULES (enfants directs du
    // `Wrap`) via `keys`, PAS par un `KeyedSubtree` descendant — sinon `Wrap`
    // réconcilierait par position et un conditionnel inséré avant un champ
    // focalisé détruirait son `State` (focus/curseur perdus — AD-2/FR-1). On
    // fournit donc les enfants NON keyés à la racine (`_fieldChild`) + les clés à
    // part (la garde L3 « place stable non contournable » reste tenue par `keys`).
    return ZResponsiveGrid(
      gutter: widget.gridGutter,
      spans: <ZResponsiveSpan>[
        for (final spec in members)
          widget.layout[spec.name] ?? const ZResponsiveSpan(),
      ],
      keys: <Key?>[
        for (final spec in members) ValueKey<String>(spec.name),
      ],
      children: <Widget>[
        for (final spec in members) _fieldChild(context, spec),
      ],
    );
  }

  void _toggleSection(String title) {
    final next = Set<String>.of(_collapsed.value);
    if (!next.remove(title)) next.add(title);
    _collapsed.value = next; // notifie → rebuild STRUCTUREL (jamais une frappe).
  }

  /// Sous-arbre RENDU d'un champ (dispatcher par type ou `fieldBuilder` custom),
  /// **sans** la place stable — celle-ci est posée par l'appelant (`KeyedSubtree`
  /// en colonne/plat, ou la clé de cellule `keys` en grille).
  Widget _fieldChild(BuildContext context, ZFieldSpec spec) {
    final builder = widget.fieldBuilder;
    return builder != null
        ? builder(context, widget.controller, spec)
        : ZFieldWidget(controller: widget.controller, field: spec);
  }

  Widget _buildField(BuildContext context, ZFieldSpec spec) {
    // Garde L3 (AC7) : place stable NON contournable — même si un `fieldBuilder`
    // custom omet la clé, le champ reste keyé sur `spec.name` (préserve SM-1/
    // UJ-2 : rebuild externe ⇒ Element/State réutilisés).
    return KeyedSubtree(
      key: ValueKey<String>(spec.name),
      child: _fieldChild(context, spec),
    );
  }
}

/// Ligne du `ListView` PLAT : soit un **en-tête** de section, soit un **champ**.
@immutable
class _EditionRow {
  const _EditionRow.header(this.title) : spec = null;
  const _EditionRow.field(this.spec) : title = null;

  final String? title;
  final ZFieldSpec? spec;

  /// Clé du widget d'item (celle posée par `_buildField` : `ValueKey(name)`) —
  /// `null` pour un en-tête (non keyé). Alimente `findChildIndexCallback`.
  Key? get key {
    final s = spec;
    return s == null ? null : ValueKey<String>(s.name);
  }

  Widget build(BuildContext context, _DynamicEditionState parent) {
    final header = title;
    if (header != null) return _SectionHeader(title: header);
    return parent._buildField(context, spec!);
  }
}

/// En-tête de section **visuel** (non repliable). Style dérivé du thème (aucune
/// couleur codée en dur — FR-26) ; insets **directionnels** (AD-13).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      );
}

/// En-tête de section **repliable** (accordéon accessible — E3-4, AD-13).
///
/// - `Semantics(button, expanded, label)` explicite (AC7) ;
/// - **cible tactile ≥ 48 dp** (`minHeight`) ;
/// - insets **directionnels** (`EdgeInsetsDirectional`) et icône reflétant l'état
///   (aucune couleur codée en dur — thème).
///
/// L'état d'expansion est **détenu par le parent** ([_DynamicEditionState._collapsed])
/// : ce widget est sans état (rend [expanded], remonte [onToggle]). Justification
/// (résout l'ambiguïté story) : un état d'expansion porté par le `State` du parent
/// **survit** non seulement au rebuild structurel mais AUSSI au recyclage
/// `ListView.builder` (un `State` local d'en-tête serait perdu au défilement),
/// tout en restant orthogonal à `visibleFields` (AC9).
class _CollapsibleSectionHeader extends StatelessWidget {
  const _CollapsibleSectionHeader({
    required this.title,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      label: title,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
