/// **CR-IFFD-76 — les PIÈCES de la bande d'accessoires du composer**, en
/// widgets purs (lot « composer assemblé »).
///
/// ## Ce que la CR a mesuré
///
/// Le socle offrait le composer en **pièces** ; l'assemblage restait à la
/// charge de l'hôte — et IFFD, en l'écrivant (64 lignes), a introduit QUATRE
/// défauts, tous trouvés par la QA à l'écran. Les six pièces absentes de
/// l'inventaire §③ sont livrées ici (conteneur, `+` pickers, bascule
/// « réfléchir », bascule « internet », déclencheur « outils », STOP +
/// bandeau d'édition) ; l'assemblage par défaut est `ZDefaultChatComposer`
/// (fichier voisin).
///
/// ## 🔴 UN état, DEUX surfaces (arbitrage owner n°3)
///
/// Les bascules « réfléchir » et « internet » de la bande lisent et écrivent
/// le **même** [ZChatSettingsController] que les tuiles de
/// `ZChatSettingsSheet` — jamais un second état. Basculer dans la bande se
/// reflète dans la feuille, et inversement (garde mesurée). La **présence** en
/// bande est un paramètre d'hôte ; le socle ne retire pas la tuile.
///
/// ## 🔴 G-CH1 — le STOP câble un verbe EXISTANT
///
/// `ZChatController` porte déjà l'annulation :
/// `runAction(ZChatCancelAction(requestId:))` (grep `cancel` positif —
/// `z_chat_controller.dart`, arrêt local du jeton + protocole du répartiteur).
/// [ZChatComposerStopTarget] appelle **ce** verbe — aucun membre nouveau,
/// aucun raccourci `stop()` (le raccourci serait un second site d'appel, le
/// défaut IFFD que `runAction` ferme). Le bandeau d'édition rend, lui, les
/// verbes K2 existants (`editing` / `cancelEditing`).
///
/// ## FR-26 / AD-13 / SM-1
///
/// Aucune couleur, aucun libellé en dur (tout passe par [zChatLabel]) ; toutes
/// les cibles ≥ 48 dp en géométrie rendue, tout est directionnel ; chaque
/// pièce n'écoute que **sa** tranche (`settings` pour les bascules,
/// `activeRequests` pour le STOP, `editing` pour le bandeau) — jamais les
/// messages, jamais la frappe.
///
/// ## Mode compact (« < mobileBreakpoint »)
///
/// lex masque les libellés sous 400 dp et garde les badges (lex/f011). Chaque
/// pièce accepte `showLabel: false` — mais **refuse de perdre son seul canal
/// visible** : sans glyphe d'hôte, le libellé reste rendu (CR-74 : un état —
/// et une affordance — doivent rester perceptibles par un canal visible).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../settings/z_chat_settings_controller.dart';
import '../z_chat_controller.dart';
import 'z_chat_composer_chrome.dart';
import 'z_chat_composer_reference.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;
import 'z_chat_settings_sheet.dart'
    show
        kZChatSettingsReferenceGap,
        kZChatSettingsReferenceMarkGap,
        kZChatSettingsReferenceSelectedDecoration,
        kZChatSettingsReferenceSelectedWeight;

/// La paire de styles emphase CR-74 — même chaîne que la feuille de réglages
/// (jetons `chatSelectedEmphasis*`, puis références) : la bande et la feuille
/// disent « choisi » de la MÊME façon.
({TextStyle plain, TextStyle chosen}) _emphasisStyles(BuildContext context) {
  final ZcrudTheme? theme = ZcrudScope.maybeOf(context)?.theme;
  final TextStyle base = DefaultTextStyle.of(context).style;
  return (
    plain: base,
    chosen: base.copyWith(
      fontWeight:
          theme?.chatSelectedEmphasisWeight ??
          kZChatSettingsReferenceSelectedWeight,
      decoration:
          theme?.chatSelectedEmphasisDecoration ??
          kZChatSettingsReferenceSelectedDecoration,
    ),
  );
}

double _gapOf(BuildContext context) =>
    ZcrudScope.maybeOf(context)?.theme?.gapS ?? kZChatSettingsReferenceGap;

/// Le CONTENEUR du composer (CR-IFFD-76, pièce 1) — le fond arrondi que les
/// deux relevés (`ZChatNotebookReference.composerRadius` = 12,
/// `ZChatComposerReference.containerRadius` = 12) publient déjà et que
/// personne ne dessinait.
///
/// * **rayon** : chaîne du chrome K2 (paramètre > jeton `radiusM` > référence
///   12) ;
/// * **fond** : [backgroundColor] > jeton `surfaceColor` > **rien** — le socle
///   n'invente aucune couleur (FR-26) : sans fond résolu, l'enfant est rendu
///   tel quel, jamais une décoration inerte (AD-4).
class ZChatComposerSurface extends StatelessWidget {
  /// Construit le conteneur.
  const ZChatComposerSurface({
    required this.child,
    this.chrome,
    this.backgroundColor,
    super.key,
  });

  /// Le contenu (champ + bande).
  final Widget child;

  /// Réglage de chrome — `null` ⇒ jetons puis référence lex (chaîne K2).
  final ZChatComposerChrome? chrome;

  /// Fond du conteneur. `null` ⇒ jeton `surfaceColor`, sinon aucun fond.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ZChatComposerChromeStyle style = zChatComposerChromeOf(
      context,
      chrome: chrome,
    );
    final Color? fill =
        backgroundColor ?? ZcrudScope.maybeOf(context)?.theme?.surfaceColor;
    if (fill == null) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        // Symétrique : un rayon uniforme n'a pas de côté (AD-13).
        borderRadius: BorderRadius.all(style.containerRadius),
      ),
      child: child,
    );
  }
}

/// Une action du menu `+` (CR-IFFD-76, pièce 2) — **contrat opaque** : le
/// socle ne connaît ni galerie, ni photo, ni fichier. Libellé par clé de
/// registre ou déjà localisé par l'hôte, glyphe d'hôte, geste d'hôte.
@immutable
class ZChatComposerPickerAction {
  /// Action à libellé **déjà localisé par l'hôte**.
  const ZChatComposerPickerAction({
    required String this.label,
    required this.onTap,
    this.icon,
  }) : labelKey = null;

  /// Action à libellé par **clé** (registre + repli de l'hôte).
  const ZChatComposerPickerAction.byKey({
    required String this.labelKey,
    required this.onTap,
    this.icon,
  }) : label = null;

  /// Libellé d'hôte. Exclusif de [labelKey].
  final String? label;

  /// Clé de libellé. Exclusive de [label].
  final String? labelKey;

  /// Glyphe d'HÔTE. `null` ⇒ absent (AD-4).
  final Widget? icon;

  /// Le geste — il appartient à l'hôte (ouvrir sa galerie, son scanner…).
  final VoidCallback onTap;
}

/// Le déclencheur `+` des pickers (pièce 2) : un créneau structurel + un menu
/// au-dessus de lui, chaque entrée entièrement fournie par l'hôte.
///
/// AD-4 : passer par [slot] — il rend `null` quand l'hôte n'a fourni aucune
/// action, le créneau est alors absent de l'arbre, jamais un `+` inerte.
class ZChatComposerPickerTrigger extends StatefulWidget {
  /// Construit le déclencheur. [actions] ne doit pas être vide.
  const ZChatComposerPickerTrigger({
    required this.actions,
    this.glyph,
    this.spacing,
    super.key,
  }) : assert(actions.length > 0);

  /// Le point de montage RECOMMANDÉ : rend `null` sans action (AD-4).
  static Widget? Function(BuildContext) maybe({
    required List<ZChatComposerPickerAction> actions,
    Widget? glyph,
    double? spacing,
  }) => (BuildContext context) => actions.isEmpty
      ? null
      : ZChatComposerPickerTrigger(
          actions: actions,
          glyph: glyph,
          spacing: spacing,
        );

  /// Le catalogue d'HÔTE — jamais une donnée du socle.
  final List<ZChatComposerPickerAction> actions;

  /// Glyphe du déclencheur (le `+` dessiné par l'hôte ou le satellite).
  /// `null` ⇒ le libellé résolu ([kZChatLabelAttachmentPickers]).
  final Widget? glyph;

  /// Interligne du menu. `null` ⇒ jeton `gapS`, puis référence.
  final double? spacing;

  @override
  State<ZChatComposerPickerTrigger> createState() =>
      _ZChatComposerPickerTriggerState();
}

class _ZChatComposerPickerTriggerState
    extends State<ZChatComposerPickerTrigger> {
  /// Créés UNE fois — jamais au rebuild (AD-2) ; l'état « ouvert » est une
  /// tranche, jamais un `setState` (G-CH5).
  final OverlayPortalController _portal = OverlayPortalController();
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

  void _run(ZChatComposerPickerAction action) {
    // Le geste d'hôte part, PUIS le menu se ferme — jamais l'inverse.
    action.onTap();
    _close();
  }

  String _labelOf(BuildContext context, ZChatComposerPickerAction a) =>
      a.label ?? zChatLabel(context, a.labelKey!);

  @override
  Widget build(BuildContext context) {
    final String resolved = zChatLabel(context, kZChatLabelAttachmentPickers);
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _overlay,
      child: CompositedTransformTarget(
        link: _link,
        child: ValueListenableBuilder<bool>(
          valueListenable: _open,
          builder: (BuildContext context, bool open, Widget? _) => Semantics(
            button: true,
            expanded: open,
            label: resolved,
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
                  // AD-13 : alignement DIRECTIONNEL.
                  alignment: AlignmentDirectional.center,
                  widthFactor: 1,
                  heightFactor: 1,
                  child:
                      widget.glyph ??
                      Text(resolved, textAlign: TextAlign.start),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final double gap = widget.spacing ?? _gapOf(context);
    final TextDirection direction = Directionality.of(context);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: const ExcludeSemantics(child: SizedBox.expand()),
          ),
        ),
        Positioned.fill(
          child: CompositedTransformFollower(
            link: _link,
            // Le menu s'ouvre AU-DESSUS du déclencheur, ancré côté DÉBUT
            // (le `+` vit en tête de bande — lex/f003).
            targetAnchor: AlignmentDirectional.topStart.resolve(direction),
            followerAnchor: AlignmentDirectional.bottomStart.resolve(
              direction,
            ),
            // 🔴 Le menu est posé au COIN ANCRÉ de la boîte suiveuse (elle
            // s'étend en amont de l'ancre) : il apparaît DIRECTEMENT
            // au-dessus du déclencheur — un `topStart` le poserait à l'autre
            // bout de la boîte, hors écran (mesuré, DC-I1).
            child: Align(
              alignment: AlignmentDirectional.bottomStart.resolve(direction),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                label: zChatLabel(context, kZChatLabelAttachmentPickers),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final ZChatComposerPickerAction a in widget.actions)
                      _item(context, a, gap),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(
    BuildContext context,
    ZChatComposerPickerAction action,
    double gap,
  ) {
    final String resolved = _labelOf(context, action);
    final Widget? icon = action.icon;
    return Semantics(
      button: true,
      label: resolved,
      excludeSemantics: true,
      onTap: () => _run(action),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _run(action),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kZChatMinTapTarget,
            minHeight: kZChatMinTapTarget,
          ),
          child: Align(
            // AD-13 : alignement DIRECTIONNEL.
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
                Text(resolved, textAlign: TextAlign.start),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La primitive commune des pièces de bande : cible ≥ 48 dp en géométrie
/// rendue, `Semantics` explicite, contenu en rangée directionnelle.
class _ZChatComposerBandTarget extends StatelessWidget {
  const _ZChatComposerBandTarget({
    required this.semanticsLabel,
    required this.onTap,
    required this.children,
    this.toggled,
  });

  final String semanticsLabel;
  final VoidCallback onTap;

  /// `null` ⇒ simple bouton ; sinon l'état est porté par `Semantics(toggled:)`
  /// — le canal lecteur d'écran, qui s'AJOUTE au canal visible (CR-74).
  final bool? toggled;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: toggled,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kZChatMinTapTarget,
            minHeight: kZChatMinTapTarget,
          ),
          child: Align(
            // AD-13 : alignement DIRECTIONNEL.
            alignment: AlignmentDirectional.center,
            widthFactor: 1,
            heightFactor: 1,
            child: Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

/// Bascule « RÉFLÉCHIR » de la bande (CR-IFFD-76, pièce 3) + badge d'effort.
///
/// 🔴 **Deux surfaces, UN état** : elle lit et écrit
/// `ZChatSettingsController.settings.revealThinkingSteps` — la MÊME tranche
/// que la tuile de la feuille. Le badge rend le palier de budget
/// (`computeEffort.level`), la donnée que lex badge sur sa puce « réfléchir ».
class ZChatComposerThinkingToggle extends StatelessWidget {
  /// Construit la bascule.
  const ZChatComposerThinkingToggle({
    required this.controller,
    this.glyph,
    this.showLabel = true,
    this.badgeBuilder,
    super.key,
  });

  /// Le contrôleur de réglages PARTAGÉ avec la feuille — jamais un second.
  final ZChatSettingsController controller;

  /// Glyphe d'HÔTE (le cerveau de lex). `null` ⇒ libellé seul.
  final Widget? glyph;

  /// `false` ⇒ mode compact (lex < 400 dp) : le libellé est masqué **si un
  /// glyphe existe** — sans glyphe, il reste rendu (jamais zéro canal
  /// visible).
  final bool showLabel;

  /// Rend le badge d'effort à partir du palier courant (`null` ⇒ pas de
  /// budget réglé). Non fourni ⇒ le nombre nu, en texte (le pixel-perfect est
  /// l'affaire du satellite Material).
  final Widget? Function(BuildContext context, int? level)? badgeBuilder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZChatGenerationSettings>(
      // 🔴 LA tranche des réglages, et elle seule (SM-1) — la même que la
      // feuille : un état, deux surfaces.
      valueListenable: controller.settings,
      builder:
          (
            BuildContext context,
            ZChatGenerationSettings settings,
            Widget? _,
          ) {
            final bool active = settings.revealThinkingSteps ?? false;
            final int? level = settings.computeEffort?.level;
            final String resolved = zChatLabel(
              context,
              kZChatLabelRevealThinking,
            );
            final ({TextStyle plain, TextStyle chosen}) styles =
                _emphasisStyles(context);
            final Widget? badge = badgeBuilder != null
                ? badgeBuilder!(context, level)
                // Un NOMBRE, pas un libellé (comme `ZChatMaterialBadge`) —
                // et sans littéral de chaîne : la garde G-R10 balaie tout
                // `Text('…')` d'un fichier de rendu.
                : (level == null
                      ? null
                      : Text(level.toString(), textAlign: TextAlign.start));
            final Widget? face = glyph;
            final bool labelVisible = showLabel || face == null;
            return _ZChatComposerBandTarget(
              semanticsLabel: resolved,
              toggled: active,
              onTap: () => controller.setRevealThinkingSteps(!active),
              children: <Widget>[
                if (face != null) ExcludeSemantics(child: face),
                if (face != null && labelVisible)
                  const SizedBox(width: kZChatSettingsReferenceMarkGap),
                if (labelVisible)
                  Text(
                    resolved,
                    // 🔴 Le canal VISIBLE de l'état (CR-74) : emphase quand
                    // actif — jamais la seule couleur, jamais la seule
                    // sémantique.
                    style: active ? styles.chosen : styles.plain,
                    textAlign: TextAlign.start,
                  ),
                if (badge != null) ...<Widget>[
                  const SizedBox(width: kZChatSettingsReferenceMarkGap),
                  // Décoratif : le palier est déjà réglé/annoncé par la
                  // feuille ; le badge est un rappel visuel.
                  ExcludeSemantics(child: badge),
                ],
              ],
            );
          },
    );
  }
}

/// Bascule « INTERNET » de la bande (CR-IFFD-76, pièce 4) — l'état est la
/// capacité TYPÉE du kernel ([kZChatCapabilityWebSearch], lot K1), lue et
/// écrite par le MÊME contrôleur que la tuile de capacités de la feuille.
class ZChatComposerWebSearchToggle extends StatelessWidget {
  /// Construit la bascule.
  const ZChatComposerWebSearchToggle({
    required this.controller,
    this.glyph,
    this.showLabel = true,
    super.key,
  });

  /// Le contrôleur de réglages PARTAGÉ avec la feuille — jamais un second.
  final ZChatSettingsController controller;

  /// Glyphe d'HÔTE. `null` ⇒ libellé seul.
  final Widget? glyph;

  /// `false` ⇒ compact : libellé masqué **si un glyphe existe**.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZChatGenerationSettings>(
      // 🔴 La même tranche que la feuille — un état, deux surfaces.
      valueListenable: controller.settings,
      builder:
          (
            BuildContext context,
            ZChatGenerationSettings settings,
            Widget? _,
          ) {
            final bool active =
                settings.capability(kZChatCapabilityWebSearch) ?? false;
            final String resolved = zChatLabel(
              context,
              kZChatLabelCapabilityWebSearch,
            );
            final ({TextStyle plain, TextStyle chosen}) styles =
                _emphasisStyles(context);
            final Widget? face = glyph;
            final bool labelVisible = showLabel || face == null;
            return _ZChatComposerBandTarget(
              semanticsLabel: resolved,
              toggled: active,
              // 🔴 Le geste EXISTANT du contrôleur — demandé ⇔ non exprimé,
              // le couple de la chip lex.
              onTap: () =>
                  controller.toggleCapability(kZChatCapabilityWebSearch),
              children: <Widget>[
                if (face != null) ExcludeSemantics(child: face),
                if (face != null && labelVisible)
                  const SizedBox(width: kZChatSettingsReferenceMarkGap),
                if (labelVisible)
                  Text(
                    resolved,
                    style: active ? styles.chosen : styles.plain,
                    textAlign: TextAlign.start,
                  ),
              ],
            );
          },
    );
  }
}

/// Le bouton « OUTILS » + compteur (CR-IFFD-76, pièce 5) — le DÉCLENCHEUR qui
/// **ouvre** la feuille de réglages ([onOpen] : le conteneur appartient à
/// l'hôte, F11). Le badge (`ZChatMaterialToolsBadge`, ou tout widget d'hôte)
/// vit **dans la cible** : le tap sur le badge atteint le bouton — le défaut ③
/// d'IFFD (badge posé sur un `Stack`, volant le tap) est inexprimable ici.
class ZChatComposerToolsTrigger extends StatelessWidget {
  /// Construit le déclencheur.
  const ZChatComposerToolsTrigger({
    required this.onOpen,
    this.badge,
    this.glyph,
    this.showLabel = true,
    super.key,
  });

  /// OUVRE la feuille — modale, page, panneau : l'hôte décide. Le créneau
  /// `tools` du composer est une **bande** ; la feuille n'y est jamais montée
  /// inline (défaut ① d'IFFD : débordement de 149 px).
  final VoidCallback onOpen;

  /// Badge compteur (réglages actifs). Rendu DANS la cible — décoratif pour
  /// le lecteur d'écran (le compte vit dans la feuille).
  final Widget? badge;

  /// Glyphe d'HÔTE. `null` ⇒ libellé seul.
  final Widget? glyph;

  /// `false` ⇒ compact : libellé masqué **si un glyphe existe** — le badge,
  /// lui, reste (lex/f011 : libellés masqués, badges gardés).
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final String resolved = zChatLabel(context, kZChatLabelTools);
    final Widget? face = glyph;
    final bool labelVisible = showLabel || face == null;
    final Widget? counter = badge;
    return _ZChatComposerBandTarget(
      semanticsLabel: resolved,
      onTap: onOpen,
      children: <Widget>[
        if (face != null) ExcludeSemantics(child: face),
        if (face != null && labelVisible)
          const SizedBox(width: kZChatSettingsReferenceMarkGap),
        if (labelVisible) Text(resolved, textAlign: TextAlign.start),
        if (counter != null) ...<Widget>[
          SizedBox(width: ZChatComposerReference.badgeStartGap),
          // 🔴 DANS la cible, donc DANS le hit-test du bouton — et hors de
          // l'arbre sémantique (le nombre est un rappel visuel).
          ExcludeSemantics(child: counter),
        ],
      ],
    );
  }
}

/// Le déclencheur d'EFFORT à menu (CR-IFFD-76, défaut ④) — la forme lex
/// (« ✦ Plus » ouvrant Mini/Plus/Pro, lex/f011) : **un déclencheur unique à
/// menu**, jamais trois chips. L'axe est celui du kernel
/// ([ZChatResponseLength]) ; l'état vit dans le MÊME [ZChatSettingsController]
/// que la tuile de verbosité de la feuille (un état, deux surfaces).
class ZChatComposerEffortSelector extends StatefulWidget {
  /// Construit le déclencheur.
  const ZChatComposerEffortSelector({
    required this.controller,
    this.glyph,
    this.selectionMark,
    this.showLabel = true,
    this.spacing,
    super.key,
  });

  /// Le contrôleur de réglages PARTAGÉ avec la feuille.
  final ZChatSettingsController controller;

  /// Glyphe du déclencheur (le « ✦ » de lex, stylé par l'hôte).
  final Widget? glyph;

  /// Glyphe posé devant le palier ACTIF du menu (la coche lex/f011).
  /// `null` ⇒ l'emphase CR-74 seule.
  final Widget? selectionMark;

  /// `false` ⇒ compact : le libellé du déclencheur est masqué **si un glyphe
  /// existe**.
  final bool showLabel;

  /// Interligne du menu. `null` ⇒ jeton `gapS`, puis référence.
  final double? spacing;

  @override
  State<ZChatComposerEffortSelector> createState() =>
      _ZChatComposerEffortSelectorState();
}

class _ZChatComposerEffortSelectorState
    extends State<ZChatComposerEffortSelector> {
  final OverlayPortalController _portal = OverlayPortalController();
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

  void _select(ZChatResponseLength? length) {
    // 🔴 Le verbe EXISTANT du contrôleur partagé — la feuille reflète le choix
    // (un état, deux surfaces).
    widget.controller.setResponseLength(length);
    _close();
  }

  static const Map<ZChatResponseLength, String> _labels =
      <ZChatResponseLength, String>{
        ZChatResponseLength.concise: kZChatLabelLengthConcise,
        ZChatResponseLength.standard: kZChatLabelLengthStandard,
        ZChatResponseLength.detailed: kZChatLabelLengthDetailed,
      };

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _overlay,
      child: CompositedTransformTarget(
        link: _link,
        child: ValueListenableBuilder<ZChatGenerationSettings>(
          // 🔴 La tranche des réglages, et elle seule (SM-1).
          valueListenable: widget.controller.settings,
          builder:
              (
                BuildContext context,
                ZChatGenerationSettings settings,
                Widget? _,
              ) => ValueListenableBuilder<bool>(
                valueListenable: _open,
                builder: (BuildContext context, bool open, Widget? _) =>
                    _trigger(context, settings.responseLength, open),
              ),
        ),
      ),
    );
  }

  Widget _trigger(
    BuildContext context,
    ZChatResponseLength? active,
    bool open,
  ) {
    final String group = zChatLabel(context, kZChatLabelResponseLength);
    final String resolved = active == null
        ? group
        : zChatLabel(context, _labels[active]!);
    final Widget? face = widget.glyph;
    final bool labelVisible = widget.showLabel || face == null;
    return Semantics(
      button: true,
      expanded: open,
      label: group,
      value: active == null ? null : resolved,
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
            // AD-13 : alignement DIRECTIONNEL.
            alignment: AlignmentDirectional.center,
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (face != null) ExcludeSemantics(child: face),
                if (face != null && labelVisible)
                  const SizedBox(width: kZChatSettingsReferenceMarkGap),
                if (labelVisible)
                  Text(resolved, textAlign: TextAlign.start),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final double gap = widget.spacing ?? _gapOf(context);
    final TextDirection direction = Directionality.of(context);
    final ZChatGenerationSettings settings =
        widget.controller.settings.value;
    final ({TextStyle plain, TextStyle chosen}) styles = _emphasisStyles(
      context,
    );
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: const ExcludeSemantics(child: SizedBox.expand()),
          ),
        ),
        Positioned.fill(
          child: CompositedTransformFollower(
            link: _link,
            // Au-dessus du déclencheur, ancré côté FIN (lex/f011).
            targetAnchor: AlignmentDirectional.topEnd.resolve(direction),
            followerAnchor: AlignmentDirectional.bottomEnd.resolve(direction),
            // 🔴 Même règle que le menu du `+` : le menu vit au COIN ANCRÉ de
            // la boîte suiveuse (au-dessus du déclencheur), jamais à son
            // `topStart` — qui est hors écran (mesuré, DC-E1).
            child: Align(
              alignment: AlignmentDirectional.bottomEnd.resolve(direction),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                label: zChatLabel(context, kZChatLabelResponseLength),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _item(
                      context,
                      zChatLabel(context, kZChatLabelSettingAuto),
                      selected: settings.responseLength == null,
                      onTap: () => _select(null),
                      gap: gap,
                      styles: styles,
                    ),
                    for (final ZChatResponseLength length
                        in ZChatResponseLength.values)
                      _item(
                        context,
                        zChatLabel(context, _labels[length]!),
                        selected: settings.responseLength == length,
                        onTap: () => _select(length),
                        gap: gap,
                        styles: styles,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(
    BuildContext context,
    String resolved, {
    required bool selected,
    required VoidCallback onTap,
    required double gap,
    required ({TextStyle plain, TextStyle chosen}) styles,
  }) {
    final Widget? mark = widget.selectionMark;
    return Semantics(
      button: true,
      selected: selected,
      label: resolved,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kZChatMinTapTarget,
            minHeight: kZChatMinTapTarget,
          ),
          child: Align(
            // AD-13 : alignement DIRECTIONNEL.
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  resolved,
                  // L'état par le STYLE (CR-74) — jamais la seule couleur.
                  style: selected ? styles.chosen : styles.plain,
                  textAlign: TextAlign.start,
                ),
                if (selected && mark != null) ...<Widget>[
                  SizedBox(width: gap),
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

/// Le bouton STOP pendant le flux (CR-IFFD-76, pièce 6) — visible SEULEMENT
/// quand une génération est en vol, câblé sur le verbe **EXISTANT**
/// `runAction(ZChatCancelAction(requestId:))` (G-CH1 : aucun membre ajouté,
/// aucun raccourci `stop()` — le raccourci serait un second site d'appel).
///
/// 🔴 SM-1 : c'est la SEULE pièce de la bande abonnée à une tranche de flux
/// (`activeRequests` — qui ne signale qu'aux départs/arrivées de requêtes,
/// jamais aux tokens). La saisie est restituée intacte par le protocole
/// d'annulation (G-A1/G-A2 du kernel : annuler ≠ supprimer la question).
class ZChatComposerStopTarget extends StatelessWidget {
  /// Construit le bouton.
  const ZChatComposerStopTarget({
    required this.controller,
    this.glyph,
    this.showLabel = true,
    super.key,
  });

  /// Le contrôleur de conversation — le verbe est le sien.
  final ZChatController controller;

  /// Glyphe d'HÔTE (le carré stop). `null` ⇒ libellé seul.
  final Widget? glyph;

  /// `false` ⇒ compact : libellé masqué **si un glyphe existe**.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      // 🔴 LA tranche des requêtes EN VOL, et elle seule.
      valueListenable: controller.activeRequests,
      builder: (BuildContext context, List<String> ids, Widget? _) {
        if (ids.isEmpty) return const SizedBox.shrink();
        final String resolved = zChatLabel(
          context,
          kZChatLabelStopGeneration,
        );
        final Widget? face = glyph;
        final bool labelVisible = showLabel || face == null;
        return _ZChatComposerBandTarget(
          semanticsLabel: resolved,
          onTap: () => unawaited(
            // 🔴 L'UNIQUE point d'entrée des verbes : l'annulation est
            // adressée par identité de requête (la plus récente), et le
            // brouillon est restitué INTACT par le protocole.
            controller.runAction(
              ZChatCancelAction(
                requestId: ids.last,
                draft: controller.currentDraft,
              ),
            ),
          ),
          children: <Widget>[
            if (face != null) ExcludeSemantics(child: face),
            if (face != null && labelVisible)
              const SizedBox(width: kZChatSettingsReferenceMarkGap),
            if (labelVisible) Text(resolved, textAlign: TextAlign.start),
          ],
        );
      },
    );
  }
}

/// Le bandeau de MODE ÉDITION (CR-IFFD-76, pièce 6 bis) — il REND les verbes
/// K2 existants : visible quand [ZChatController.editing] porte une session,
/// sortie par `cancelEditing` (la saisie d'avant l'édition est restituée par
/// le contrôleur — jamais détruite).
///
/// ⚠️ Le bouton « fermer » de 28 dp du bandeau lex (`chat_input.dart:516-519`)
/// n'est PAS reproduit : la cible de sortie fait ≥ 48 dp en géométrie rendue.
class ZChatComposerEditingBanner extends StatelessWidget {
  /// Construit le bandeau.
  const ZChatComposerEditingBanner({
    required this.controller,
    this.glyph,
    this.cancelGlyph,
    super.key,
  });

  /// Le contrôleur de conversation — la tranche `editing` est la sienne.
  final ZChatController controller;

  /// Glyphe d'HÔTE du bandeau (le crayon). `null` ⇒ absent (AD-4).
  final Widget? glyph;

  /// Glyphe d'HÔTE de la sortie. `null` ⇒ le libellé résolu.
  final Widget? cancelGlyph;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZChatEditingSession?>(
      // 🔴 LA tranche du mode édition, et elle seule (SM-1).
      valueListenable: controller.editing,
      builder:
          (BuildContext context, ZChatEditingSession? session, Widget? _) {
            if (session == null) return const SizedBox.shrink();
            final String title = zChatLabel(context, kZChatLabelEditing);
            final String cancel = zChatLabel(
              context,
              kZChatLabelEditingCancel,
            );
            final Widget? face = glyph;
            return Padding(
              padding: ZChatComposerReference.editingBannerPadding,
              child: Row(
                children: <Widget>[
                  if (face != null) ...<Widget>[
                    ExcludeSemantics(child: face),
                    const SizedBox(
                      width: kZChatSettingsReferenceMarkGap,
                    ),
                  ],
                  Expanded(
                    child: Semantics(
                      label: title,
                      excludeSemantics: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.start,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  _ZChatComposerBandTarget(
                    semanticsLabel: cancel,
                    // 🔴 Le verbe K2 EXISTANT — la saisie d'avant l'édition
                    // est restituée par le contrôleur.
                    onTap: controller.cancelEditing,
                    children: <Widget>[
                      cancelGlyph == null
                          ? Text(cancel, textAlign: TextAlign.start)
                          : ExcludeSemantics(child: cancelGlyph!),
                    ],
                  ),
                ],
              ),
            );
          },
    );
  }
}
