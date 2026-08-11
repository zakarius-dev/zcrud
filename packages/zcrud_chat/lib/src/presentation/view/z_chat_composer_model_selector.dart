/// Le sélecteur de modèle d'IA du composer.
///
/// ## Contrat opaque — zéro nom de modèle au socle
///
/// Les options ([ZChatModelOption]) sont injectées par l'hôte : id opaque,
/// libellé par clé de registre ou déjà localisé, icône optionnelle. Le socle
/// ne connaît aucun nom de modèle particulier. La sélection remonte par
/// callback ([ZChatComposerModelSelector.onSelect]) : le socle ne décide pas
/// où elle est persistée, c'est l'affaire de l'hôte. Aucun membre n'est
/// ajouté à `ZChatController`.
///
/// ## Le rendu par défaut
///
/// Un déclencheur dans la rangée d'accessoires du composer (l'hôte le monte
/// dans son créneau `tools` — ou `trailing` —, à droite, avant le bouton
/// d'envoi), qui ouvre un menu au-dessus de lui, coche sur l'actif. En
/// widgets purs : l'état actif est porté par `Semantics(selected:)` et par
/// l'emphase du thème (graisse + soulignement) ; la coche picturale est un
/// glyphe d'hôte ([ZChatComposerModelSelector.selectionMark]) — le socle
/// n'invente ni glyphe ni couleur. Le rendu pixel-perfect d'un design system
/// particulier est l'affaire du satellite qui le porte.
///
/// ## Invariant AD-4 — pas d'options, pas de menu
///
/// Le point de montage recommandé est [ZChatComposerModelSelector.slot] : un
/// `ZChatComposerSlotBuilder` qui rend `null` quand l'hôte n'a fourni aucune
/// option — le créneau est alors absent de l'arbre, jamais un bouton inerte.
///
/// ## Invariant AD-2 — ouvrir le menu ne reconstruit rien d'autre
///
/// L'état « ouvert » est un `OverlayPortalController` local : ni la liste des
/// messages, ni le champ, ni les autres créneaux ne sont abonnés.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_chat_composer.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;
import 'z_chat_settings_sheet.dart'
    show
        kZChatSettingsReferenceGap,
        kZChatSettingsReferenceMarkGap,
        kZChatSettingsReferenceSelectedDecoration,
        kZChatSettingsReferenceSelectedWeight;

/// Une option de modèle d'IA, entièrement fournie par l'hôte.
///
/// [id] est opaque — un identifiant de routage propre à l'hôte, le socle
/// n'en lit jamais le contenu ; le libellé vient d'une clé de registre
/// ([labelKey]) ou d'un texte déjà localisé ([label]) — exactement l'un des
/// deux.
@immutable
class ZChatModelOption {
  /// Option à libellé **déjà localisé par l'hôte**.
  const ZChatModelOption({
    required this.id,
    required String this.label,
    this.icon,
  }) : labelKey = null;

  /// Option à libellé par **clé** (registre + repli de l'hôte).
  const ZChatModelOption.byKey({
    required this.id,
    required String this.labelKey,
    this.icon,
  }) : label = null;

  /// Identifiant **opaque et stable** — c'est lui qui remonte par `onSelect`.
  final String id;

  /// Libellé d'hôte. Exclusif de [labelKey].
  final String? label;

  /// Clé de libellé. Exclusive de [label].
  final String? labelKey;

  /// Glyphe d'hôte, déjà stylé par lui. `null` signifie absent (invariant
  /// AD-4).
  final Widget? icon;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatModelOption &&
          id == other.id &&
          label == other.label &&
          labelKey == other.labelKey;

  @override
  int get hashCode => Object.hash(id, label, labelKey);
}

/// Construit — ou retire — le déclencheur du sélecteur. Rendre `null`
/// signifie affordance absente (invariant AD-4). [toggle] ouvre/ferme le
/// menu ; [open] est l'état courant.
typedef ZChatModelTriggerBuilder =
    Widget? Function(
      BuildContext context,
      ZChatModelOption? active,
      bool open,
      VoidCallback toggle,
    );

/// Construit le MENU entier à la place du défaut. [close] referme le portail.
typedef ZChatModelMenuBuilder =
    Widget Function(
      BuildContext context,
      List<ZChatModelOption> options,
      String? activeId,
      void Function(String id) select,
      VoidCallback close,
    );

/// Le sélecteur de modèle du composer — déclencheur + menu par défaut au
/// rendu des vidéos, tout surchargeable (règle des trois cas sur le
/// déclencheur, builder de menu).
class ZChatComposerModelSelector extends StatefulWidget {
  /// Construit le sélecteur. [options] ne doit pas être vide — un hôte sans
  /// option ne monte pas le widget (passer par [slot], qui rend `null`).
  const ZChatComposerModelSelector({
    required this.options,
    required this.onSelect,
    this.activeId,
    this.selectionMark,
    this.triggerBuilder,
    this.menuBuilder,
    this.spacing,
    super.key,
       // Sans option, pas de sélecteur : passer par [slot], qui rend `null`
       // (invariant AD-4) — l'assert tient la promesse côté montage direct.
  }) : assert(options.length > 0);

  /// Le point de montage recommandé : un builder de créneau qui rend `null`
  /// quand [options] est vide — le sélecteur est alors absent de l'arbre
  /// (invariant AD-4), jamais un bouton inerte.
  static ZChatComposerSlotBuilder slot({
    required List<ZChatModelOption> options,
    required ValueChanged<String> onSelect,
    String? activeId,
    Widget? selectionMark,
    ZChatModelTriggerBuilder? triggerBuilder,
    ZChatModelMenuBuilder? menuBuilder,
    double? spacing,
  }) => (BuildContext context, ZChatComposerSlot slot) => options.isEmpty
      ? null
      : ZChatComposerModelSelector(
          options: options,
          onSelect: onSelect,
          activeId: activeId,
          selectionMark: selectionMark,
          triggerBuilder: triggerBuilder,
          menuBuilder: menuBuilder,
          spacing: spacing,
        );

  /// Le catalogue d'hôte — jamais une donnée du socle.
  final List<ZChatModelOption> options;

  /// Id de l'option active, ou `null` (aucune coche — l'état vit chez
  /// l'hôte, le socle ne présume rien, invariant AD-10).
  final String? activeId;

  /// La sélection remonte ici — l'hôte la range où il veut. Le socle ne la
  /// stocke pas.
  final ValueChanged<String> onSelect;

  /// Glyphe d'hôte posé devant l'option active du menu. `null` signifie
  /// l'emphase du thème seule — le socle n'invente aucun glyphe.
  final Widget? selectionMark;

  /// Remplace le déclencheur (règle des trois cas : absent, défaut du
  /// socle ; rend un widget, le remplace ; rend `null`, affordance absente).
  final ZChatModelTriggerBuilder? triggerBuilder;

  /// Remplace le menu entier. `null` signifie le menu par défaut du socle.
  final ZChatModelMenuBuilder? menuBuilder;

  /// Interligne du menu. `null` signifie jeton `gapS`, puis référence.
  final double? spacing;

  @override
  State<ZChatComposerModelSelector> createState() =>
      _ZChatComposerModelSelectorState();
}

class _ZChatComposerModelSelectorState
    extends State<ZChatComposerModelSelector> {
  /// Créés une fois — jamais au rebuild (invariant AD-2).
  final OverlayPortalController _portal = OverlayPortalController();

  /// Tranche locale « menu ouvert » — pilote uniquement le drapeau
  /// `expanded` du déclencheur, jamais un `setState`.
  final ValueNotifier<bool> _open = ValueNotifier<bool>(false);

  final LayerLink _link = LayerLink();

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _toggle() {
    _portal.toggle();
    _open.value = !_open.value;
  }

  void _close() {
    if (_open.value) {
      _portal.hide();
      _open.value = false;
    }
  }

  void _select(String id) {
    // La sélection remonte, puis le menu se ferme — jamais l'inverse : un
    // hôte qui reconstruit sur `onSelect` ne doit pas retrouver un portail
    // ouvert sur un arbre disparu.
    widget.onSelect(id);
    _close();
  }

  ZChatModelOption? get _active {
    final String? id = widget.activeId;
    if (id == null) return null;
    for (final ZChatModelOption o in widget.options) {
      if (o.id == id) return o;
    }
    // Id actif inconnu du catalogue : aucune présomption (invariant AD-10)
    // — le déclencheur retombe sur son libellé générique.
    return null;
  }

  String _optionLabel(BuildContext context, ZChatModelOption o) =>
      o.label ?? zChatLabel(context, o.labelKey!);

  double _gap(BuildContext context) =>
      widget.spacing ??
      ZcrudScope.maybeOf(context)?.theme?.gapS ??
      kZChatSettingsReferenceGap;

  ({TextStyle plain, TextStyle chosen}) _styles(BuildContext context) {
    final ZcrudTheme? theme = ZcrudScope.maybeOf(context)?.theme;
    final TextStyle base = DefaultTextStyle.of(context).style;
    final FontWeight weight =
        theme?.chatSelectedEmphasisWeight ??
        kZChatSettingsReferenceSelectedWeight;
    final TextDecoration decoration =
        theme?.chatSelectedEmphasisDecoration ??
        kZChatSettingsReferenceSelectedDecoration;
    return (
      plain: base,
      chosen: base.copyWith(fontWeight: weight, decoration: decoration),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _overlay,
      child: CompositedTransformTarget(
        link: _link,
        child: ValueListenableBuilder<bool>(
          valueListenable: _open,
          builder: (BuildContext context, bool open, Widget? _) =>
              _trigger(context, open),
        ),
      ),
    );
  }

  Widget _trigger(BuildContext context, bool open) {
    final ZChatModelOption? active = _active;
    final ZChatModelTriggerBuilder? override = widget.triggerBuilder;
    if (override != null) {
      // Règle des trois cas : rendre `null` ⇒ affordance absente (AD-4) —
      // un `SizedBox.shrink` serait une cible fantôme.
      return override(context, active, open, _toggle) ??
          const SizedBox.shrink();
    }
    final String resolved = active == null
        ? zChatLabel(context, kZChatLabelModelSelector)
        : _optionLabel(context, active);
    final Widget? icon = active?.icon;
    return Semantics(
      button: true,
      expanded: open,
      label: zChatLabel(context, kZChatLabelModelSelector),
      value: active == null ? null : _optionLabel(context, active),
      excludeSemantics: true,
      onTap: _toggle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kZChatMinTapTarget,
            minHeight: kZChatMinTapTarget,
          ),
          child: Align(
            // Invariant AD-13 : alignement directionnel.
            alignment: AlignmentDirectional.center,
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  ExcludeSemantics(child: icon),
                  const SizedBox(width: kZChatSettingsReferenceMarkGap),
                ],
                Text(resolved, textAlign: TextAlign.start),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final ZChatModelMenuBuilder? override = widget.menuBuilder;
    final Widget menu = override != null
        ? override(context, widget.options, widget.activeId, _select, _close)
        : _defaultMenu(context);
    // Invariant AD-13 : ancres résolues contre la direction du texte — le
    // menu s'ouvre au-dessus du déclencheur, aligné sur son bord de fin.
    final TextDirection direction = Directionality.of(context);
    return Stack(
      children: <Widget>[
        // La toile de fermeture : un tap hors menu referme, sans consommer le
        // geste d'un autre widget au-delà de cette frame.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            // Sémantiquement muette : la fermeture est déjà offerte par le
            // déclencheur (`expanded`), la toile n'est pas une affordance.
            child: const ExcludeSemantics(child: SizedBox.expand()),
          ),
        ),
        Positioned.fill(
          child: CompositedTransformFollower(
            link: _link,
            targetAnchor: AlignmentDirectional.topEnd.resolve(direction),
            followerAnchor: AlignmentDirectional.bottomEnd.resolve(direction),
            child: Align(
              alignment: AlignmentDirectional.topStart.resolve(direction),
              child: menu,
            ),
          ),
        ),
      ],
    );
  }

  /// Le menu par défaut : une option par ligne, coche sur l'actif —
  /// `Semantics(selected:)` + emphase du thème + glyphe d'hôte éventuel.
  /// Cibles ≥ 48 dp en géométrie rendue.
  Widget _defaultMenu(BuildContext context) {
    final double gap = _gap(context);
    final ({TextStyle plain, TextStyle chosen}) styles = _styles(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: zChatLabel(context, kZChatLabelModelSelector),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final ZChatModelOption option in widget.options)
            _menuItem(context, option, gap, styles),
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context,
    ZChatModelOption option,
    double gap,
    ({TextStyle plain, TextStyle chosen}) styles,
  ) {
    // La coche suit l'actif — elle n'est jamais figée : c'est l'id, et lui
    // seul, qui décide.
    final bool selected = option.id == widget.activeId;
    final String resolved = _optionLabel(context, option);
    final Widget? icon = option.icon;
    final Widget? mark = widget.selectionMark;
    return Semantics(
      button: true,
      selected: selected,
      label: resolved,
      excludeSemantics: true,
      onTap: () => _select(option.id),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(option.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kZChatMinTapTarget,
            minHeight: kZChatMinTapTarget,
          ),
          child: Align(
            // Invariant AD-13 : alignement directionnel.
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  ExcludeSemantics(child: icon),
                  SizedBox(width: gap),
                ],
                Text(
                  resolved,
                  // L'état passe par le style, mesurable sur le
                  // RenderParagraph — jamais par la seule couleur (invariant
                  // AD-13).
                  style: selected ? styles.chosen : styles.plain,
                  textAlign: TextAlign.start,
                ),
                if (selected && mark != null) ...<Widget>[
                  SizedBox(width: gap),
                  // Décorative : l'état est déjà annoncé par `selected`.
                  ExcludeSemantics(child: mark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
