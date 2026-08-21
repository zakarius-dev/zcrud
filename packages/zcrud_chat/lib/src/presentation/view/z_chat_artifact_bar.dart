/// Le **rendu d'état** des artefacts déclarés d'un message : un glyphe par
/// artefact, teinté quand le contenu existe, avec sa pastille de compte et
/// son menu de verbes.
///
/// ## 🔴 « C'est un ÉTAT, pas un style »
///
/// C'est la phrase de CR-IFFD-84, et c'est la seule règle de ce fichier : la
/// teinte n'est peinte **que si l'artefact existe**. Un glyphe teinté en
/// permanence est une décoration ; un glyphe qui se teint quand le contenu
/// arrive est une information — c'est ce qui fait la valeur de l'écran.
///
/// Et parce qu'une information ne repose jamais sur la seule couleur
/// (invariant AD-13), l'état est **annoncé** : `Semantics.value` porte
/// « déjà généré » ou « aucun contenu », l'occupation et le compte. Un
/// utilisateur daltonien, un thème qui écrase la teinte, un lecteur d'écran :
/// aucun des trois ne perd le signal.
///
/// ## Ce que ce fichier CONSOMME de l'existant
///
/// `ZChatNotebookSkin.capabilityAccents`, le jeton
/// `ZcrudTheme.chatCapabilityAccents` et
/// `ZChatNotebookReference.capabilities` existaient — **sans aucun
/// consommateur** hors des fichiers qui les déclarent (motif « offert, non
/// passé », vérifié par grep). Ce rendu est leur premier lecteur : la chaîne
/// complète paramètre > jeton > référence décide de la teinte d'un artefact,
/// et la géométrie de la pastille vient elle aussi de la référence
/// (`perMessageActionIconSize`, `perMessageActionBadgeRadius`,
/// `perMessageActionBadgeFontSize`, et les deux décalages directionnels).
///
/// ## 🔴 La pastille ne vole PAS le tap (CR-IFFD-83, défaut ①)
///
/// `Badge.count` de Material rend son label **hit-testable** : un tap à
/// 8 px du coin du glyphe était absorbé par la pastille et ne déclenchait
/// rien. Ici la pastille entière — pas seulement son texte — est enveloppée
/// d'`IgnorePointer`, et le `GestureDetector` opaque est son **ancêtre** :
/// le rectangle de la pastille reste une zone active du bouton. La garde
/// tape sous la pastille pour le prouver.
///
/// ## Contraste (défaut ④)
///
/// La teinte déclarée par l'hôte est portée au plancher WCAG **avant** d'être
/// peinte (`zChatReadableTintOn`) : l'orange du legacy IFFD mesure 2,05:1 sur
/// blanc, et le livrer brut reproduirait le défaut que la CR a mesuré. La
/// couleur de l'hôte qui satisfait déjà le plancher est rendue **inchangée**.
///
/// ## Ce que ce fichier ne fait PAS
///
/// L'**animation** d'occupation (`ZChatNotebookReference.busyPalette`,
/// `busyCycleDuration`) n'est pas montée ici : elle relève d'un lot distinct,
/// avec « Réduire les animations » (invariant AD-13) qu'elle ne peut pas
/// ignorer. La lecture [ZChatArtifactSpec.busy] est néanmoins déjà
/// **consommée** — par l'annonce, pas par un pixel animé : un état lu et
/// jamais restitué serait exactement le motif « offert, non passé » que ce
/// lot corrige.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_chat_artifact_spec.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart'
    show ZChatMessageSlotBuilder, kZChatMinTapTarget;
import 'z_chat_notebook_reference.dart';
import 'z_chat_notebook_skin.dart';
import 'z_chat_readable_tint.dart';

/// La rangée d'artefacts d'**un** message.
///
/// Montée automatiquement par `ZChatNotebookView.artifacts` ; un hôte qui
/// reste sur `ZChatConversationView` la monte lui-même par [slot] — c'est
/// l'échappatoire d'un cran vers les briques, sans rien perdre.
class ZChatArtifactBar extends StatelessWidget {
  /// Construit la rangée.
  const ZChatArtifactBar({
    required this.message,
    required this.artifacts,
    this.skin,
    this.confirm,
    this.spacing,
    super.key,
  });

  /// Point de montage dans un créneau d'actions par message : rend `null`
  /// quand rien n'est déclaré — le créneau est alors absent de l'arbre
  /// (invariant AD-4), et l'hôte passif retrouve son rendu au widget près.
  ///
  /// [host] est le créneau d'actions que l'hôte avait déjà : les deux
  /// **cohabitent** — son contenu est rendu au-dessus de la rangée, jamais
  /// remplacé par elle. La composition vit ICI, et non dans
  /// `ZChatNotebookView` : la surface notebook doit rester une composition
  /// mince — elle relaie, elle ne dispose pas (garde CMP-F2).
  static ZChatMessageSlotBuilder slot({
    required List<ZChatArtifactSpec> artifacts,
    ZChatMessageSlotBuilder? host,
    ZChatNotebookSkin? skin,
    ZChatArtifactConfirm? confirm,
    double? spacing,
  }) => (BuildContext context, ZChatMessage message) {
    final Widget? own = host?.call(context, message);
    if (artifacts.isEmpty) return own;
    final Widget bar = ZChatArtifactBar(
      message: message,
      artifacts: artifacts,
      skin: skin,
      confirm: confirm,
      spacing: spacing,
    );
    if (own == null) return bar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[own, bar],
    );
  };

  /// Le message dont on rend les artefacts.
  final ZChatMessage message;

  /// Les artefacts déclarés, **dans l'ordre de l'hôte**.
  final List<ZChatArtifactSpec> artifacts;

  /// Réglage de rendu — c'est lui qui porte `capabilityAccents`. `null`
  /// signifie « le jeton, puis la référence ».
  final ZChatNotebookSkin? skin;

  /// Couture de confirmation d'un verbe destructeur. `null` signifie la
  /// confirmation **en place** du socle.
  final ZChatArtifactConfirm? confirm;

  /// Espacement entre glyphes. `null` signifie le jeton `gapS`.
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ZChatNotebookStyle style = (skin ?? const ZChatNotebookSkin())
        .resolve(context);
    final List<Widget> entries = <Widget>[
      for (final ZChatArtifactSpec spec in artifacts)
        if (_isRendered(spec))
          _ZChatArtifactButton(
            key: ValueKey<String>(spec.key),
            message: message,
            spec: spec,
            style: style,
            confirm: confirm,
          ),
    ];
    // Aucun artefact à montrer sur ce message : rien dans l'arbre, pas même
    // un conteneur vide (invariant AD-4).
    if (entries.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: zChatLabel(context, kZChatLabelArtifacts),
      child: Wrap(
        spacing: spacing ?? theme.gapS,
        runSpacing: spacing ?? theme.gapS,
        children: entries,
      ),
    );
  }

  /// Un artefact ni présent ni actionnable n'est **pas** rendu : une
  /// affordance inerte est pire qu'une absence (invariant AD-4). C'est aussi
  /// ce qui permet à un hôte de déclarer ses artefacts une fois pour tout le
  /// fil : sur un message d'utilisateur, aucune condition ne tient, donc
  /// aucun glyphe n'apparaît.
  bool _isRendered(ZChatArtifactSpec spec) {
    final bool present = spec.isPresent(message);
    return present || spec.visibleActions(message, present: present).isNotEmpty;
  }
}

/// Un glyphe d'artefact : état peint, état annoncé, menu de verbes.
class _ZChatArtifactButton extends StatefulWidget {
  const _ZChatArtifactButton({
    required this.message,
    required this.spec,
    required this.style,
    required this.confirm,
    super.key,
  });

  final ZChatMessage message;
  final ZChatArtifactSpec spec;
  final ZChatNotebookStyle style;
  final ZChatArtifactConfirm? confirm;

  @override
  State<_ZChatArtifactButton> createState() => _ZChatArtifactButtonState();
}

class _ZChatArtifactButtonState extends State<_ZChatArtifactButton> {
  /// Créés une fois, jamais au rebuild (invariant AD-2).
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  /// Tranche locale « menu ouvert » — jamais un `setState` d'échelle tuile.
  final ValueNotifier<bool> _open = ValueNotifier<bool>(false);

  /// Le verbe destructeur en attente de confirmation, `null` sinon. Une
  /// tranche, pas un `setState` : ouvrir la confirmation ne reconstruit que
  /// le contenu du portail.
  final ValueNotifier<ZChatArtifactAction?> _pending =
      ValueNotifier<ZChatArtifactAction?>(null);

  @override
  void dispose() {
    _open.dispose();
    _pending.dispose();
    super.dispose();
  }

  void _toggle() {
    _portal.toggle();
    _open.value = !_open.value;
  }

  void _close() {
    _pending.value = null;
    if (_open.value) {
      _portal.hide();
      _open.value = false;
    }
  }

  /// Un verbe a été choisi. Destructeur ⇒ confirmation AVANT tout effet.
  Future<void> _select(ZChatArtifactAction action) async {
    if (!action.destructive) {
      _close();
      action.onSelected(widget.message);
      return;
    }
    final ZChatArtifactConfirm? ask = widget.confirm;
    if (ask == null) {
      // Confirmation EN PLACE : le socle ne dépend d'aucune surface stylée,
      // il ne peut pas pousser un dialogue — il transforme donc son menu.
      _pending.value = action;
      return;
    }
    _close();
    final bool ok = await ask(
      context,
      ZChatArtifactConfirmRequest(
        message: widget.message,
        artifact: widget.spec,
        action: action,
      ),
    );
    if (!mounted || !ok) return;
    action.onSelected(widget.message);
  }

  void _confirmPending() {
    final ZChatArtifactAction? action = _pending.value;
    _close();
    if (action == null) return;
    action.onSelected(widget.message);
  }

  /// La surface contre laquelle tout contraste est mesuré. `null` ⇒ aucune
  /// teinte n'est peinte : une couleur dont on ne peut pas mesurer la
  /// lisibilité n'est pas un état lisible (repli **fermant**, AD-10).
  Color? _surface(BuildContext context) => ZcrudTheme.of(context).surfaceColor;

  /// La couleur ambiante du glyphe — celle d'un artefact absent.
  Color? _ambient(BuildContext context) =>
      IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color;

  /// Chaîne d'accent d'un artefact : paramètre de la spec > paramètre du
  /// skin > jeton de thème > référence.
  ///
  /// Les deux tables du milieu sont lues **par clé** : un accent déclaré pour
  /// une clé que la référence ne connaît pas est honoré malgré tout — c'est
  /// la seule façon qu'un hôte ait de teinter un artefact qu'il invente.
  Color? _accent() {
    final ZChatArtifactSpec spec = widget.spec;
    return spec.accent ??
        widget.style.capabilityAccents?[spec.key] ??
        widget.style.themeCapabilityAccents?[spec.key] ??
        widget.style.capability(spec.key)?.accent;
  }

  /// La teinte réellement peinte : la teinte déclarée, portée au plancher de
  /// contraste des composants graphiques. `null` ⇒ couleur ambiante.
  Color? _tint(BuildContext context, {required bool present}) {
    if (!present) return null;
    final Color? accent = _accent();
    final Color? surface = _surface(context);
    if (accent == null || surface == null) return null;
    return zChatReadableTintOn(accent, surface: surface);
  }

  /// L'état, en TEXTE : présence, occupation, compte. C'est le canal non
  /// chromatique — il existe même quand aucune teinte n'est peinte.
  String _stateValue(
    BuildContext context, {
    required bool present,
    required bool busy,
    required int? count,
  }) {
    final List<String> parts = <String>[
      zChatLabel(
        context,
        present ? kZChatLabelGenerated : kZChatLabelArtifactEmpty,
      ),
      if (busy) zChatLabel(context, kZChatLabelArtifactBusy),
      if (count != null)
        zChatCountLabel(context, kZChatLabelArtifactCount, count),
    ];
    return parts.join(', ');
  }

  String _actionLabel(BuildContext context, ZChatArtifactAction action) =>
      action.label ?? zChatLabel(context, action.labelKey!);

  @override
  Widget build(BuildContext context) {
    final ZChatArtifactSpec spec = widget.spec;
    final bool present = spec.isPresent(widget.message);
    final int? count = spec.countOf(widget.message);
    final bool busy = spec.isBusy(widget.message);
    final List<ZChatArtifactAction> actions = spec.visibleActions(
      widget.message,
      present: present,
    );
    final String value = _stateValue(
      context,
      present: present,
      busy: busy,
      count: count,
    );
    final Widget glyph = _glyph(context, present: present, count: count);

    // Aucun verbe visible : l'entrée reste un INDICATEUR d'état, jamais un
    // bouton qui n'ouvrirait rien (invariant AD-4).
    if (actions.isEmpty) {
      return Semantics(
        label: spec.label,
        value: value,
        excludeSemantics: true,
        child: glyph,
      );
    }

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (BuildContext context) => _overlay(context, actions),
      child: CompositedTransformTarget(
        link: _link,
        child: ValueListenableBuilder<bool>(
          valueListenable: _open,
          builder: (BuildContext context, bool open, Widget? child) =>
              Semantics(
                button: true,
                expanded: open,
                label: spec.label,
                value: value,
                excludeSemantics: true,
                onTap: _toggle,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: child,
                ),
              ),
          // Le glyphe est passé en `child` : ouvrir le menu ne le reconstruit
          // pas (invariant AD-2).
          child: glyph,
        ),
      ),
    );
  }

  /// Le glyphe et sa pastille — la cible tactile, jamais la seule icône.
  Widget _glyph(
    BuildContext context, {
    required bool present,
    required int? count,
  }) {
    final Color? tint = _tint(context, present: present);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: kZChatMinTapTarget,
        minHeight: kZChatMinTapTarget,
      ),
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: <Widget>[
          Icon(
            widget.spec.icon,
            size: ZChatNotebookReference.perMessageActionIconSize,
            // 🔴 L'ÉTAT, et rien d'autre : teinte si le contenu existe,
            // couleur ambiante sinon.
            color: tint,
          ),
          if (count != null)
            PositionedDirectional(
              top: ZChatNotebookReference.perMessageActionBadgeTopInset,
              end: ZChatNotebookReference.perMessageActionBadgeEndInset,
              // 🔴 Le badge ENTIER est transparent au geste — pas seulement
              // son texte : c'est le badge assemblé qui absorbait le tap.
              child: IgnorePointer(
                child: ExcludeSemantics(child: _badge(context, count)),
              ),
            ),
        ],
      ),
    );
  }

  /// La pastille de compte. Sa couleur est un **rôle** (`errorColor`), jamais
  /// une valeur de référence : la référence a explicitement REFUSÉ de porter
  /// cette couleur, dérivable d'un `ColorScheme`.
  Widget _badge(BuildContext context, int count) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final Color? surface = _surface(context);
    // Un rôle, jamais un littéral. Aucune couleur résolvable ⇒ aucune
    // décoration : le compte reste lisible, il ne devient pas invisible sur
    // un fond inventé (repli fermant, AD-10).
    final Color? background = theme.errorColor ?? _ambient(context) ?? surface;
    final TextStyle base = DefaultTextStyle.of(context).style;
    // Le libellé d'une pastille est du TEXTE : plancher 4.5, mesuré contre le
    // fond de la pastille, jamais contre la page.
    final Color? foreground = background == null
        ? null
        : zChatReadableTintOn(
            surface ?? background,
            surface: background,
            minContrast: kZChatTextMinContrast,
          );
    final double diameter =
        ZChatNotebookReference.perMessageActionBadgeRadius * 2;
    final Widget body = ConstrainedBox(
      constraints: BoxConstraints(minWidth: diameter, minHeight: diameter),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          style: base.copyWith(
            fontSize: ZChatNotebookReference.perMessageActionBadgeFontSize,
            color: foreground,
          ),
        ),
      ),
    );
    if (background == null) return body;
    return DecoratedBox(
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: body,
    );
  }

  /// Le portail : toile de fermeture + menu ancré sur le bouton.
  Widget _overlay(BuildContext context, List<ZChatArtifactAction> actions) {
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
            targetAnchor: AlignmentDirectional.bottomStart.resolve(direction),
            followerAnchor: AlignmentDirectional.topStart.resolve(direction),
            child: Align(
              alignment: AlignmentDirectional.topStart.resolve(direction),
              child: ValueListenableBuilder<ZChatArtifactAction?>(
                valueListenable: _pending,
                builder:
                    (
                      BuildContext context,
                      ZChatArtifactAction? pending,
                      Widget? _,
                    ) => pending == null
                    ? _menu(context, actions)
                    : _confirmation(context, pending),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Le menu : **exactement** les verbes dont la condition tient, dans
  /// l'ordre déclaré par l'hôte.
  Widget _menu(BuildContext context, List<ZChatArtifactAction> actions) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.spec.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final ZChatArtifactAction action in actions)
            _menuItem(context, action),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, ZChatArtifactAction action) {
    final String resolved = _actionLabel(context, action);
    return _tappableRow(
      context,
      label: resolved,
      icon: action.icon,
      accent: action.accent,
      onTap: () => unawaited(_select(action)),
    );
  }

  /// La confirmation **en place** d'un verbe destructeur : la question de
  /// l'hôte (ou celle du socle), puis deux verbes. Le rappel de l'hôte n'est
  /// appelé que par « confirmer » — le défaut ⑤ de la CR (une suppression qui
  /// part sans question) n'est pas exprimable ici.
  Widget _confirmation(BuildContext context, ZChatArtifactAction action) {
    final String question =
        action.confirmMessage ??
        zChatLabel(context, kZChatLabelArtifactConfirmPrompt);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _actionLabel(context, action),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(question, textAlign: TextAlign.start),
          _tappableRow(
            context,
            label: zChatLabel(context, kZChatLabelArtifactConfirm),
            icon: null,
            accent: action.accent,
            onTap: _confirmPending,
          ),
          _tappableRow(
            context,
            label: zChatLabel(context, kZChatLabelArtifactCancel),
            icon: null,
            accent: null,
            onTap: _close,
          ),
        ],
      ),
    );
  }

  /// Une ligne tapable du portail — cible ≥ 48 dp, teinte portée au plancher
  /// de contraste du TEXTE, et jamais un mot codé en dur.
  Widget _tappableRow(
    BuildContext context, {
    required String label,
    required IconData? icon,
    required Color? accent,
    required VoidCallback onTap,
  }) {
    final Color? surface = _surface(context);
    final Color? tint = (accent == null || surface == null)
        ? null
        : zChatReadableTintOn(
            accent,
            surface: surface,
            minContrast: kZChatTextMinContrast,
          );
    final TextStyle base = DefaultTextStyle.of(context).style;
    return Semantics(
      button: true,
      label: label,
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
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  ExcludeSemantics(
                    child: Icon(
                      icon,
                      size: ZChatNotebookReference.perMessageActionIconSize,
                      color: tint,
                    ),
                  ),
                  SizedBox(width: ZcrudTheme.of(context).gapS),
                ],
                Text(
                  label,
                  textAlign: TextAlign.start,
                  style: tint == null ? base : base.copyWith(color: tint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
