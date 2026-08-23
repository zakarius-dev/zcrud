/// Les pièces de la bande d'accessoires du composer, en widgets purs.
///
/// Le socle offre le composer en pièces assemblables (conteneur, `+`
/// pickers, bascule « réfléchir », bascule « internet », déclencheur
/// « outils », STOP, bandeau d'édition, déclencheur de dictée) ; l'assemblage
/// par défaut qui les réunit est `ZDefaultChatComposer` (fichier voisin).
/// Chaque pièce reste montable seule par un hôte qui compose sa propre
/// bande.
///
/// ## Un état, deux surfaces
///
/// Les bascules « réfléchir » et « internet » de la bande lisent et écrivent
/// le **même** [ZChatSettingsController] que les tuiles de
/// `ZChatSettingsSheet` — jamais un second état. Basculer dans la bande se
/// reflète dans la feuille, et inversement. La **présence** d'une pièce en
/// bande est un paramètre d'hôte ; le socle ne retire jamais la tuile
/// correspondante de la feuille.
///
/// ## Le bouton d'arrêt câble un verbe existant
///
/// `ZChatController` porte déjà l'annulation :
/// `runAction(ZChatCancelAction(requestId:))`. [ZChatComposerStopTarget]
/// appelle **ce** verbe — aucun membre nouveau, aucun raccourci `stop()` qui
/// ouvrirait un second site d'appel. Le bandeau d'édition rend, lui, les
/// verbes déjà exposés par le contrôleur (`editing` / `cancelEditing`).
///
/// ## Accessibilité et thème (invariants AD-13, AD-2)
///
/// Aucune couleur, aucun libellé en dur (tout passe par [zChatLabel]) ;
/// toutes les cibles ≥ 48 dp en géométrie rendue, tout est directionnel ;
/// chaque pièce n'écoute que **sa** tranche (`settings` pour les bascules,
/// `activeRequests` pour le STOP, `editing` pour le bandeau) — jamais les
/// messages, jamais la frappe.
///
/// ## Mode compact (« < mobileBreakpoint »)
///
/// Chaque pièce accepte `showLabel: false` — mais **refuse de perdre son
/// seul canal visible** : un état actif ou une valeur choisie doit rester
/// perceptible par au moins un canal visible, même avec le libellé masqué.
/// La règle est tenue par [_labelVisible] : le compact masque le libellé des
/// pièces qui n'ont **rien à dire**, et le garde sur toute pièce dont l'état
/// est actif ou dont une valeur est choisie — avec un glyphe seul, un état
/// actif serait sinon rendu à l'identique d'un état au repos.
///
/// ## Le filet du conteneur et le déclencheur de dictée
///
/// [ZChatComposerSurface] expose un canal de bordure (rôle `dividerColor`)
/// que l'hôte peut câbler sans envelopper la surface d'un second conteneur.
/// [ZChatComposerDictationTrigger] est le déclencheur de dictée compact : le
/// socle livre le bouton, l'hôte garde le geste et le moteur de
/// reconnaissance.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
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
        kZChatSettingsReferenceSelectedWeight,
        zChatSelectedEmphasisStyles;

/// La paire de styles d'emphase — même chaîne que la feuille de réglages
/// (jetons `chatSelectedEmphasis*`, puis références) **et la même
/// implémentation** ([zChatSelectedEmphasisStyles]) : la bande et la feuille
/// disent « choisi » de la MÊME façon, y compris l'anti-annulation
/// (invariant AD-10) sous un style ambiant déjà gras/souligné.
({TextStyle plain, TextStyle chosen}) _emphasisStyles(BuildContext context) {
  final ZcrudTheme? theme = ZcrudScope.maybeOf(context)?.theme;
  return zChatSelectedEmphasisStyles(
    DefaultTextStyle.of(context).style,
    weight:
        theme?.chatSelectedEmphasisWeight ??
        kZChatSettingsReferenceSelectedWeight,
    decoration:
        theme?.chatSelectedEmphasisDecoration ??
        kZChatSettingsReferenceSelectedDecoration,
  );
}

/// **La règle du canal visible en mode compact.**
///
/// Un état doit rester perceptible par au moins un canal **visible**. Avec
/// un glyphe d'hôte et `showLabel: false` (mode compact), masquer
/// systématiquement le libellé — **seul porteur de l'emphase** — rendrait un
/// état actif à l'identique d'un état au repos, puisque le glyphe, opaque,
/// ne change pas de lui-même.
///
/// ⇒ Le compact masque le libellé des pièces qui n'ont **rien à dire** ; une
/// pièce dont l'état est ACTIF (ou dont une valeur est CHOISIE) garde le
/// sien.
///
/// **Pourquoi ce canal-là**, et pas une pastille/un fond/un contour : le
/// socle n'invente aucune couleur. Une décoration exige une couleur d'hôte —
/// donc un canal **conditionné** au câblage, c'est-à-dire zéro canal chez
/// l'hôte qui n'a rien câblé. Le libellé emphasé est le seul canal que le
/// socle peut peindre **inconditionnellement**, et c'est déjà celui que la
/// feuille de réglages utilise (un état, deux surfaces, une seule grammaire).
///
/// ⇒ La teinte d'état actif (`activeAccent` / jeton
/// `chatComposerActiveAccent`, cf. [_activeAccent]) est un canal
/// **supplémentaire**, jamais un substitut : elle teinte glyphe et libellé
/// quand l'hôte l'a déclarée, et cette règle du canal visible reste tenue
/// telle quelle pour l'hôte qui n'a rien déclaré.
bool _labelVisible({
  required bool showLabel,
  required bool hasGlyph,
  required bool stateful,
}) => showLabel || !hasGlyph || stateful;

/// **La teinte d'état ACTIF, en garde-fou de lisibilité.**
///
/// Chaîne `paramètre > jeton (`ZcrudTheme.chatComposerActiveAccent`) >
/// **rien**` : sans déclaration, aucune teinte n'est peinte et l'arbre rendu
/// est exactement celui d'un socle sans ce canal (invariant AD-4).
///
/// La teinte déclarée est portée au **plancher de contraste** des composants
/// graphiques, mesuré contre la surface du composer : un accent que le thème
/// de l'hôte rendrait illisible est corrigé, jamais peint tel quel. Surface
/// non mesurable ⇒ aucune teinte (repli **fermant**, AD-10) : une couleur
/// dont on ne peut pas mesurer la lisibilité n'est pas un état lisible.
///
/// 🔴 Ce canal s'**AJOUTE**, il ne remplace rien : le libellé emphasé et
/// `Semantics(toggled:)` restent les canaux non chromatiques de l'état
/// (invariant AD-13).
TextStyle _tinted(TextStyle style, Color? tint) =>
    tint == null ? style : style.copyWith(color: tint);

Color? _activeAccent(BuildContext context, Color? accent) {
  final ZcrudTheme theme = ZcrudTheme.of(context);
  final Color? declared = accent ?? theme.chatComposerActiveAccent;
  final Color? surface = theme.surfaceColor;
  if (declared == null || surface == null) return null;
  return zReadableTintOn(declared, surface: surface);
}

double _gapOf(BuildContext context) =>
    ZcrudScope.maybeOf(context)?.theme?.gapS ?? kZChatSettingsReferenceGap;

/// Le CONTENEUR du composer — le fond arrondi que
/// `ZChatNotebookReference.composerRadius` et
/// `ZChatComposerReference.containerRadius` publient déjà (tous deux à 12).
///
/// * **rayon** : chaîne du chrome (paramètre > jeton `radiusM` > référence
///   12) ;
/// * **fond** : [backgroundColor] > jeton `surfaceColor` > **rien** — le
///   socle n'invente aucune couleur : sans fond résolu, l'enfant est rendu
///   tel quel, jamais une décoration inerte (invariant AD-4).
///
/// ## Le canal de BORDURE
///
/// Poser un filet sans point de câblage dédié obligerait l'hôte à envelopper
/// la surface d'un second conteneur et à faire coïncider deux rayons à la
/// main. Ce conteneur expose donc son propre canal :
///
/// * **couleur du filet** : [borderColor] > jeton `chatComposerBorderColor`
///   > **rien** (même doctrine que le fond) ;
/// * **épaisseur** : chaîne du chrome ([ZChatComposerChromeStyle.borderWidth],
///   référence 1) ;
/// * **rayon** : celui du conteneur, **par construction** — les deux rayons
///   ne peuvent pas diverger.
///
/// ## `clipBehavior` — porté, et par défaut INERTE
///
/// Sans fond ni filet, la surface ne pose **aucune** couche de rendu, et son
/// enfant par défaut (bandeau d'édition = un `Padding`, bande = une rangée)
/// ne peint jamais jusqu'au bord ⇒ un clip serait dans ce cas une couche de
/// composition pour rien. Il est donc **offert** ([clipBehavior]) et
/// **`Clip.none` par défaut** : l'hôte dont un enfant peint jusqu'au bord (un
/// bandeau à fond, une vignette pleine largeur) l'active, et le clip épouse
/// alors EXACTEMENT le rayon du conteneur — jamais un second rayon à
/// accorder.
class ZChatComposerSurface extends StatelessWidget {
  /// Construit le conteneur.
  const ZChatComposerSurface({
    required this.child,
    this.chrome,
    this.backgroundColor,
    this.borderColor,
    this.clipBehavior = Clip.none,
    super.key,
  });

  /// Le contenu (champ + bande).
  final Widget child;

  /// Réglage de chrome — `null` ⇒ jeton puis référence.
  final ZChatComposerChrome? chrome;

  /// Fond du conteneur. `null` ⇒ jeton `surfaceColor`, sinon aucun fond.
  final Color? backgroundColor;

  /// Couleur du FILET — un **rôle** de bordure que l'hôte fournit. `null` ⇒
  /// jeton `chatComposerBorderColor`, sinon **aucun filet** (invariant AD-4).
  final Color? borderColor;

  /// Rognage du contenu au rayon du conteneur. `Clip.none` par défaut —
  /// l'arbre d'un hôte passif est inchangé (cf. dartdoc de la classe).
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final ZChatComposerChromeStyle style = zChatComposerChromeOf(
      context,
      chrome: chrome,
    );
    final Color? fill =
        backgroundColor ?? ZcrudScope.maybeOf(context)?.theme?.surfaceColor;
    // Le jeton `chatComposerBorderColor` de `zcrud_core`, quand il existera,
    // s'insérera ici, entre le paramètre et le « rien ».
    final Color? line = borderColor;
    // Symétrique : un rayon uniforme n'a pas de côté (AD-13). UN seul rayon
    // pour le fond, le filet et le rognage — ils ne peuvent pas diverger.
    final BorderRadius radius = BorderRadius.all(style.containerRadius);
    // Une épaisseur nulle ne peint rien : sans couleur ET sans épaisseur
    // utile, on ne pose pas de côté (AD-4).
    final bool painted = line != null && style.borderWidth > 0;
    if (fill == null && !painted) {
      return clipBehavior == Clip.none
          ? child
          : ClipRRect(
              borderRadius: radius,
              clipBehavior: clipBehavior,
              child: child,
            );
    }
    final Widget inner = clipBehavior == Clip.none
        ? child
        : ClipRRect(
            borderRadius: radius,
            clipBehavior: clipBehavior,
            child: child,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        border: painted
            ? Border.all(color: line, width: style.borderWidth)
            : null,
        borderRadius: radius,
      ),
      child: inner,
    );
  }
}

/// Une action du menu `+` — **contrat opaque** : le socle ne connaît ni
/// galerie, ni photo, ni fichier. Libellé par clé de registre ou déjà
/// localisé par l'hôte, glyphe d'hôte, geste d'hôte.
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
  /// Créés UNE fois — jamais au rebuild (invariant AD-2) ; l'état « ouvert »
  /// est une tranche, jamais un `setState`.
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
            // (le `+` vit en tête de bande).
            targetAnchor: AlignmentDirectional.topStart.resolve(direction),
            followerAnchor: AlignmentDirectional.bottomStart.resolve(
              direction,
            ),
            // Le menu est posé au COIN ANCRÉ de la boîte suiveuse (elle
            // s'étend en amont de l'ancre) : il apparaît DIRECTEMENT
            // au-dessus du déclencheur — un `topStart` le poserait à l'autre
            // bout de la boîte, hors écran.
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
    this.liveRegion = false,
    this.foreground,
    this.minTarget = kZChatMinTapTarget,
  });

  final String semanticsLabel;
  final VoidCallback onTap;

  /// `true` ⇒ le changement d'étiquette est **annoncé** : une capture en
  /// cours ne doit pas être seulement visible.
  final bool liveRegion;

  /// `null` ⇒ simple bouton ; sinon l'état est porté par `Semantics(toggled:)`
  /// — le canal lecteur d'écran, qui s'ajoute au canal visible.
  final bool? toggled;

  final List<Widget> children;

  /// Teinte imposée au premier plan du contenu (glyphe d'hôte compris).
  /// `null` ⇒ couleur ambiante — l'arbre est alors celui d'avant ce canal.
  final Color? foreground;

  /// Côté demandé de la cible — ÉCRÊTÉ au plancher [kZChatMinTapTarget] : une
  /// demande plus basse est inexprimable, pas seulement déconseillée.
  final double minTarget;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: toggled,
      liveRegion: liveRegion,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // Écrêtage au plancher : une demande plus basse que
            // `kZChatMinTapTarget` est inexprimable (invariant AD-13).
            minWidth: math.max(minTarget, kZChatMinTapTarget),
            minHeight: math.max(minTarget, kZChatMinTapTarget),
          ),
          child: Align(
            // AD-13 : alignement DIRECTIONNEL.
            alignment: AlignmentDirectional.center,
            widthFactor: 1,
            heightFactor: 1,
            // Un glyphe d'hôte est opaque : seule une enveloppe de premier
            // plan peut le teinter — et c'est la primitive du socle qui le
            // fait, jamais un `IconTheme` coloré posé ici.
            child: foreground == null
                ? Row(mainAxisSize: MainAxisSize.min, children: children)
                : ZForegroundOverride(
                    color: foreground!,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Bascule « RÉFLÉCHIR » de la bande + badge d'effort optionnel.
///
/// **Deux surfaces, UN état** : elle lit et écrit
/// `ZChatSettingsController.settings.revealThinkingSteps` — la MÊME tranche
/// que la tuile de la feuille.
///
/// ## Une pièce n'affiche que la donnée qu'elle pilote
///
/// Le modèle du kernel exprime « réfléchir » en **booléen** (activé ou non),
/// avec un budget séparé. Un badge qui afficherait ce budget sur une bascule
/// qui ne pilote que le booléen créerait un décalage : le badge ne suivrait
/// jamais le geste de tap, et resterait un canal mort quand le budget est
/// absent. C'est pourquoi [badgeBuilder] reçoit l'**état booléen** — la
/// donnée que le tap change — et rien d'autre. Piloter aussi le budget
/// ferait de la bascule un déclencheur à menu, c'est-à-dire une autre pièce
/// ([ZChatComposerEffortSelector] en est déjà une).
///
/// **La règle est générale** : un widget ne rend que la donnée que son
/// propre geste écrit ; afficher un champ voisin fait de l'affichage un
/// commentaire — vrai par hasard, faux dès que le modèle bouge. Le budget se
/// règle et s'affiche là où il se pilote : la feuille de réglages
/// (`ZChatSettingsSheet`) et le sélecteur d'effort.
class ZChatComposerThinkingToggle extends StatelessWidget {
  /// Construit la bascule.
  const ZChatComposerThinkingToggle({
    required this.controller,
    this.glyph,
    this.showLabel = true,
    this.badgeBuilder,
    this.activeAccent,
    super.key,
  });

  /// Le contrôleur de réglages PARTAGÉ avec la feuille — jamais un second.
  final ZChatSettingsController controller;

  /// Glyphe d'HÔTE. `null` ⇒ libellé seul.
  final Widget? glyph;

  /// `false` ⇒ mode compact : le libellé est masqué **si un glyphe existe ET
  /// que la bascule est au repos**. Active, elle garde son libellé emphasé —
  /// son seul canal visible (cf. [_labelVisible]).
  final bool showLabel;

  /// Rend un badge à partir de l'**état que cette pièce pilote** — jamais
  /// d'un champ voisin. Non fourni ⇒ **aucun** badge : le socle n'a rien à
  /// badger sur un booléen déjà porté par l'emphase et par
  /// `Semantics(toggled:)`.
  final Widget? Function(BuildContext context, bool active)? badgeBuilder;

  /// Teinte de l'état **ACTIF** — un rôle d'hôte, jamais un style. `null` ⇒
  /// jeton `chatComposerActiveAccent`, sinon **aucune teinte**.
  ///
  /// Elle s'AJOUTE au libellé emphasé et à `Semantics(toggled:)` : c'est le
  /// canal que le mode compact rend nécessaire, pas un remplacement des
  /// canaux non chromatiques (invariant AD-13). Elle est portée au plancher
  /// de contraste avant d'être peinte.
  final Color? activeAccent;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZChatGenerationSettings>(
      // LA tranche des réglages, et elle seule — la même que la feuille :
      // un état, deux surfaces.
      valueListenable: controller.settings,
      builder:
          (
            BuildContext context,
            ZChatGenerationSettings settings,
            Widget? _,
          ) {
            final bool active = settings.revealThinkingSteps ?? false;
            final String resolved = zChatLabel(
              context,
              kZChatLabelRevealThinking,
            );
            final ({TextStyle plain, TextStyle chosen}) styles =
                _emphasisStyles(context);
            // Le badge reçoit `active` — CE que le tap change. Un booléen
            // n'a pas de nombre à montrer.
            final Widget? badge = badgeBuilder?.call(context, active);
            final Widget? face = glyph;
            final bool labelVisible = _labelVisible(
              showLabel: showLabel,
              hasGlyph: face != null,
              stateful: active,
            );
            // La teinte n'est résolue QUE sur l'état actif : au repos, la
            // pièce reste à la couleur ambiante.
            final Color? tint = active
                ? _activeAccent(context, activeAccent)
                : null;
            return _ZChatComposerBandTarget(
              semanticsLabel: resolved,
              toggled: active,
              foreground: tint,
              onTap: () => controller.setRevealThinkingSteps(!active),
              children: <Widget>[
                if (face != null) ExcludeSemantics(child: face),
                if (face != null && labelVisible)
                  const SizedBox(width: kZChatSettingsReferenceMarkGap),
                if (labelVisible)
                  Text(
                    resolved,
                    // Le canal VISIBLE de l'état : emphase quand actif —
                    // jamais la seule couleur, jamais la seule sémantique. La
                    // teinte s'y AJOUTE ; le style porte sa propre couleur, il
                    // n'hériterait pas de l'enveloppe de premier plan.
                    style: active
                        ? _tinted(styles.chosen, tint)
                        : styles.plain,
                    textAlign: TextAlign.start,
                  ),
                if (badge != null) ...<Widget>[
                  const SizedBox(width: kZChatSettingsReferenceMarkGap),
                  // Décoratif : l'état est déjà porté par l'emphase (vue) et
                  // par `Semantics(toggled:)` (lecteur d'écran).
                  ExcludeSemantics(child: badge),
                ],
              ],
            );
          },
    );
  }
}

/// Bascule « INTERNET » de la bande — l'état est la capacité TYPÉE du
/// kernel ([kZChatCapabilityWebSearch]), lue et écrite par le MÊME
/// contrôleur que la tuile de capacités de la feuille.
class ZChatComposerWebSearchToggle extends StatelessWidget {
  /// Construit la bascule.
  const ZChatComposerWebSearchToggle({
    required this.controller,
    this.glyph,
    this.showLabel = true,
    this.activeAccent,
    super.key,
  });

  /// Le contrôleur de réglages PARTAGÉ avec la feuille — jamais un second.
  final ZChatSettingsController controller;

  /// Glyphe d'HÔTE. `null` ⇒ libellé seul.
  final Widget? glyph;

  /// `false` ⇒ compact : libellé masqué **si un glyphe existe ET que la
  /// bascule est au repos**.
  final bool showLabel;

  /// Teinte de l'état **ACTIF** — un rôle d'hôte, jamais un style. `null` ⇒
  /// jeton `chatComposerActiveAccent`, sinon **aucune teinte**.
  ///
  /// Elle s'AJOUTE au libellé emphasé et à `Semantics(toggled:)` : c'est le
  /// canal que le mode compact rend nécessaire, pas un remplacement des
  /// canaux non chromatiques (invariant AD-13). Elle est portée au plancher
  /// de contraste avant d'être peinte.
  final Color? activeAccent;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZChatGenerationSettings>(
      // La même tranche que la feuille — un état, deux surfaces.
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
            final bool labelVisible = _labelVisible(
              showLabel: showLabel,
              hasGlyph: face != null,
              stateful: active,
            );
            final Color? tint = active
                ? _activeAccent(context, activeAccent)
                : null;
            return _ZChatComposerBandTarget(
              semanticsLabel: resolved,
              toggled: active,
              foreground: tint,
              // Le geste EXISTANT du contrôleur — demandé ⇔ non exprimé.
              onTap: () =>
                  controller.toggleCapability(kZChatCapabilityWebSearch),
              children: <Widget>[
                if (face != null) ExcludeSemantics(child: face),
                if (face != null && labelVisible)
                  const SizedBox(width: kZChatSettingsReferenceMarkGap),
                if (labelVisible)
                  Text(
                    resolved,
                    style: active
                        ? _tinted(styles.chosen, tint)
                        : styles.plain,
                    textAlign: TextAlign.start,
                  ),
              ],
            );
          },
    );
  }
}

/// Le bouton « OUTILS » + compteur — le DÉCLENCHEUR qui **ouvre** la feuille
/// de réglages ([onOpen] : le conteneur appartient à l'hôte). Le badge
/// (`ZChatMaterialToolsBadge`, ou tout widget d'hôte) vit **dans la cible** :
/// le tap sur le badge atteint le bouton, il ne peut pas être volé par un
/// `Stack` posé par-dessus.
class ZChatComposerToolsTrigger extends StatelessWidget {
  /// Construit le déclencheur.
  const ZChatComposerToolsTrigger({
    required this.onOpen,
    this.badge,
    this.badgeCount,
    this.glyph,
    this.showLabel = true,
    super.key,
  });

  /// OUVRE la feuille — modale, page, panneau : l'hôte décide. Le créneau
  /// `tools` du composer est une **bande** ; la feuille n'y est jamais
  /// montée inline (sous peine de débordement visuel).
  final VoidCallback onOpen;

  /// Badge compteur d'HÔTE. Rendu DANS la cible — décoratif pour le lecteur
  /// d'écran (le compte vit dans la feuille). Il prime sur [badgeCount].
  final Widget? badge;

  /// Le nombre de réglages actifs, en tranche.
  ///
  /// Renseigné (et sans [badge] d'hôte), le déclencheur rend lui-même le
  /// compte : rien tant qu'il vaut zéro, un badge dès qu'il est non nul.
  /// C'est aussi ce qui rend la règle du mode compact exprimable — sous le
  /// seuil, le badge **remplace** le libellé au lieu de s'y ajouter — sans
  /// jamais laisser le déclencheur sans aucun canal visible : à zéro, le
  /// libellé reste.
  ///
  /// Seule cette tranche est écoutée : une frappe dans le champ ne
  /// reconstruit pas ce bouton (invariant AD-2).
  final ValueListenable<int>? badgeCount;

  /// Glyphe d'HÔTE. `null` ⇒ libellé seul.
  final Widget? glyph;

  /// `false` ⇒ compact : libellé masqué **si un glyphe existe** — le badge,
  /// lui, reste.
  ///
  /// La règle du canal visible en compact ne s'applique pas ici : ce
  /// déclencheur n'a **pas d'état** (il ouvre une feuille). Ce qu'il a à
  /// dire — le nombre de réglages actifs — est porté par son [badge], que le
  /// compact garde justement.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ValueListenable<int>? count = badgeCount;
    if (badge != null || count == null) {
      return _body(context, badge, hasBadge: badge != null);
    }
    return ValueListenableBuilder<int>(
      // LA tranche du compte, et elle seule.
      valueListenable: count,
      builder: (BuildContext context, int value, Widget? _) => _body(
        context,
        value <= 0 ? null : ZChatComposerCountBadge(count: value),
        hasBadge: value > 0,
      ),
    );
  }

  /// [hasBadge] compte comme un canal VISIBLE : c'est lui qui autorise le
  /// mode compact à masquer le libellé même sans glyphe — et qui le garde
  /// quand le compte est nul, où le badge ne rend rien.
  Widget _body(BuildContext context, Widget? counter, {required bool hasBadge}) {
    final String resolved = zChatLabel(context, kZChatLabelTools);
    final Widget? face = glyph;
    final bool labelVisible = _labelVisible(
      showLabel: showLabel,
      hasGlyph: face != null || hasBadge,
      stateful: false,
    );
    return _ZChatComposerBandTarget(
      semanticsLabel: resolved,
      onTap: onOpen,
      children: <Widget>[
        if (face != null) ExcludeSemantics(child: face),
        if (face != null && labelVisible)
          const SizedBox(width: kZChatSettingsReferenceMarkGap),
        if (labelVisible) Text(resolved, textAlign: TextAlign.start),
        if (counter != null) ...<Widget>[
          if (face != null || labelVisible)
            SizedBox(width: ZChatComposerReference.badgeStartGap),
          // DANS la cible, donc DANS le hit-test du bouton — et hors de
          // l'arbre sémantique (le nombre est un rappel visuel).
          ExcludeSemantics(child: counter),
        ],
      ],
    );
  }
}

/// Le badge compteur par défaut du socle — un nombre, sans couleur inventée.
///
/// Un chiffre n'est pas un libellé : il ne passe par aucune table de
/// localisation. La forme (rayon, marge interne) vient de la référence du
/// composer ; la teinte reste l'affaire du satellite de design qui la porte —
/// ce paquet n'invente aucune couleur (FR-26).
class ZChatComposerCountBadge extends StatelessWidget {
  /// Construit le badge.
  const ZChatComposerCountBadge({required this.count, super.key});

  /// Le nombre rendu. Zéro ou négatif ⇒ rien (invariant AD-4).
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    // Un NOMBRE, pas un libellé : il ne traverse aucune table de
    // localisation, et la garde des chaînes en dur (ancrée sur `Text('`) n'a
    // rien à dire ici. Il est formaté avant le rendu pour que sa nature soit
    // lisible au lieu d'être noyée dans l'appel.
    final String rendered = count.toString();
    return Padding(
      // Invariant AD-13 : marge directionnelle.
      padding: ZChatComposerReference.badgePadding,
      child: Text(rendered, textAlign: TextAlign.start),
    );
  }
}

/// Le déclencheur d'EFFORT à menu — **un déclencheur unique à menu**,
/// jamais trois chips côte à côte. L'axe est celui du kernel
/// ([ZChatResponseLength]) ; l'état vit dans le MÊME
/// [ZChatSettingsController] que la tuile de verbosité de la feuille (un
/// état, deux surfaces).
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

  /// Glyphe du déclencheur, stylé par l'hôte.
  final Widget? glyph;

  /// Glyphe posé devant le palier ACTIF du menu (une coche, typiquement).
  /// `null` ⇒ l'emphase de style seule.
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
    // Le verbe EXISTANT du contrôleur partagé — la feuille reflète le choix
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
          // La tranche des réglages, et elle seule.
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
    // Le déclencheur d'effort porte une VALEUR ; un palier explicitement
    // choisi reste lisible en compact — « Automatique » (le défaut,
    // `active == null`) n'a rien à dire et cède la place.
    final bool labelVisible = _labelVisible(
      showLabel: widget.showLabel,
      hasGlyph: face != null,
      stateful: active != null,
    );
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
            // Au-dessus du déclencheur, ancré côté FIN.
            targetAnchor: AlignmentDirectional.topEnd.resolve(direction),
            followerAnchor: AlignmentDirectional.bottomEnd.resolve(direction),
            // Même règle que le menu du `+` : le menu vit au COIN ANCRÉ de
            // la boîte suiveuse (au-dessus du déclencheur), jamais à son
            // `topStart` — qui serait hors écran.
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
                  // L'état par le STYLE — jamais la seule couleur.
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

/// Le bouton STOP pendant le flux — visible SEULEMENT quand une génération
/// est en vol, câblé sur le verbe **EXISTANT**
/// `runAction(ZChatCancelAction(requestId:))` : aucun membre ajouté, aucun
/// raccourci `stop()` qui ouvrirait un second site d'appel.
///
/// C'est la SEULE pièce de la bande abonnée à une tranche de flux
/// (`activeRequests` — qui ne signale qu'aux départs/arrivées de requêtes,
/// jamais aux tokens). La saisie est restituée intacte par le protocole
/// d'annulation du kernel : annuler ne supprime jamais la question.
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
  ///
  /// La règle du canal visible en compact ne s'applique pas ici : le STOP
  /// n'a pas d'état à montrer — sa **présence** EST son état (il n'existe
  /// que pendant le flux).
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      // LA tranche des requêtes EN VOL, et elle seule.
      valueListenable: controller.activeRequests,
      builder: (BuildContext context, List<String> ids, Widget? _) {
        if (ids.isEmpty) return const SizedBox.shrink();
        final String resolved = zChatLabel(
          context,
          kZChatLabelStopGeneration,
        );
        final Widget? face = glyph;
        final bool labelVisible = _labelVisible(
          showLabel: showLabel,
          hasGlyph: face != null,
          stateful: false,
        );
        return _ZChatComposerBandTarget(
          semanticsLabel: resolved,
          onTap: () => unawaited(
            // L'UNIQUE point d'entrée des verbes : l'annulation est
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

/// Le bandeau de MODE ÉDITION — il REND les verbes existants du contrôleur :
/// visible quand [ZChatController.editing] porte une session, sortie par
/// `cancelEditing` (la saisie d'avant l'édition est restituée par le
/// contrôleur — jamais détruite).
///
/// La cible de sortie fait ≥ 48 dp en géométrie rendue (invariant AD-13) —
/// jamais une cible tactile réduite pour des raisons de compacité visuelle.
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
      // LA tranche du mode édition, et elle seule.
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
                    // La cible de sortie est déclarée par la référence, et la
                    // primitive l'écrête au plancher : compacte visuellement,
                    // jamais compacte au toucher.
                    minTarget:
                        ZChatComposerReference.editingCancelTargetSize,
                    semanticsLabel: cancel,
                    // Le verbe EXISTANT du contrôleur — la saisie d'avant
                    // l'édition est restituée par lui.
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

/// « Jamais à l'écoute » — l'état de repli quand l'hôte ne fournit AUCUNE
/// tranche d'écoute.
///
/// Constante de fait : jamais notifiée, jamais disposée, partagée par toutes
/// les instances. Elle existe pour qu'il n'y ait qu'**UN SEUL chemin de
/// rendu** dans [ZChatComposerDictationTrigger] — une seconde branche
/// « statique » séparée du chemin réactif laisserait une régression du
/// mécanisme d'écoute passer inaperçue.
final ValueNotifier<bool> _kZChatNeverListening = ValueNotifier<bool>(false);

/// Le DÉCLENCHEUR DE DICTÉE compact — un bouton dans la rangée, qui change
/// de glyphe et d'étiquette pendant l'écoute.
///
/// ## Le socle livre la pièce, l'hôte garde le geste — et le moteur
///
/// Exactement le patron du `+` des pickers. Ce widget **n'écoute rien** : il
/// n'ouvre aucun micro, ne connaît aucun `ZChatDictationPort` et ne détient
/// aucun état. L'état d'écoute est **injecté** ([listening]) et le geste
/// ([onTap]) appartient à l'hôte — qui branchera, s'il le veut,
/// `ZChatCaptureController.listening` / `startDictation()`, ou son propre
/// moteur.
///
/// ## Canaux de l'état d'écoute — trois, dont deux non chromatiques
///
/// 1. l'**étiquette** change (`Dicter` ⇄ `Arrêter la dictée`) ;
/// 2. `Semantics(toggled:)` **et** une région **live** — l'écoute est
///    *annoncée*, pas seulement affichée, pas laissée au seul canal visuel ;
/// 3. le **glyphe** bascule sur [listeningGlyph] si l'hôte en fournit un —
///    et, en mode compact, le libellé reste rendu pendant l'écoute (cf.
///    [_labelVisible]) : jamais zéro canal visible.
class ZChatComposerDictationTrigger extends StatelessWidget {
  /// Construit le déclencheur.
  const ZChatComposerDictationTrigger({
    required this.onTap,
    this.listening,
    this.glyph,
    this.listeningGlyph,
    this.showLabel = true,
    this.activeAccent,
    super.key,
  });

  /// Le geste d'HÔTE — démarrer si au repos, arrêter si à l'écoute. Le socle
  /// ne décide pas lequel des deux : il n'a pas le moteur.
  final VoidCallback onTap;

  /// La tranche d'écoute, **injectée** par l'hôte (typiquement
  /// `ZChatCaptureController.listening`). `null` ⇒ toujours au repos.
  ///
  /// Une `ValueListenable`, donc l'écoute ne reconstruit QUE ce bouton —
  /// jamais la bande, jamais le champ.
  final ValueListenable<bool>? listening;

  /// Glyphe d'HÔTE au repos (le micro). `null` ⇒ libellé seul.
  final Widget? glyph;

  /// Glyphe d'HÔTE **pendant l'écoute**. `null` ⇒ [glyph] est conservé (l'état
  /// reste porté par l'étiquette, la sémantique et le libellé compact).
  final Widget? listeningGlyph;

  /// `false` ⇒ compact : libellé masqué **si un glyphe existe ET que le
  /// micro est au repos**.
  final bool showLabel;

  /// Teinte de l'état **ACTIF** — un rôle d'hôte, jamais un style. `null` ⇒
  /// jeton `chatComposerActiveAccent`, sinon **aucune teinte**.
  ///
  /// Elle s'AJOUTE au libellé emphasé et à `Semantics(toggled:)` : c'est le
  /// canal que le mode compact rend nécessaire, pas un remplacement des
  /// canaux non chromatiques (invariant AD-13). Elle est portée au plancher
  /// de contraste avant d'être peinte.
  final Color? activeAccent;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      // UN SEUL chemin de rendu — le repli est une tranche inerte, pas une
      // seconde branche.
      valueListenable: listening ?? _kZChatNeverListening,
      builder: (BuildContext context, bool active, Widget? _) {
        final String resolved = zChatLabel(
          context,
          active ? kZChatLabelStopDictation : kZChatLabelDictate,
        );
        final ({TextStyle plain, TextStyle chosen}) styles = _emphasisStyles(
          context,
        );
        final Widget? face = active ? (listeningGlyph ?? glyph) : glyph;
        final bool labelVisible = _labelVisible(
          showLabel: showLabel,
          hasGlyph: face != null,
          stateful: active,
        );
        final Color? tint = active
            ? _activeAccent(context, activeAccent)
            : null;
        return _ZChatComposerBandTarget(
          semanticsLabel: resolved,
          toggled: active,
          foreground: tint,
          // L'écoute est ANNONCÉE : ce que dit l'utilisateur part dans un
          // moteur — il doit le savoir sans regarder l'écran.
          liveRegion: active,
          onTap: onTap,
          children: <Widget>[
            if (face != null) ExcludeSemantics(child: face),
            if (face != null && labelVisible)
              const SizedBox(width: kZChatSettingsReferenceMarkGap),
            if (labelVisible)
              Text(
                resolved,
                style: active ? _tinted(styles.chosen, tint) : styles.plain,
                textAlign: TextAlign.start,
              ),
          ],
        );
      },
    );
  }
}
