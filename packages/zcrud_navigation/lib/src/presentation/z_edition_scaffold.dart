/// **Chrome d'édition rendu par mode** (CR chrome-presentation-aware) —
/// [ZEditionScaffold].
///
/// Le presenter reste responsable du **conteneur** (route / sheet / dialog) ;
/// ce widget est responsable du **chrome interne**, et il l'adapte au
/// [ZEditionPresentation] retenu :
///
/// | `mode`   | Chrome rendu                                                        |
/// |----------|---------------------------------------------------------------------|
/// | `page`   | `Scaffold` + `CustomScrollView` + `SliverAppBar` **repliable au scroll** |
/// | `dialog` | en-tête compacte + corps + **barre d'actions en pied**               |
/// | `sheet`  | **poignée** + en-tête + corps scrollable + actions ancrées, `SafeArea` |
///
/// ## Ce que ce fichier N'EST PAS
///
/// * Il n'importe **aucun** gestionnaire d'état ni routeur (AD-2/AD-15) — que
///   `package:flutter/material.dart` + `zcrud_core` (dépendance **déjà**
///   déclarée : aucune arête nouvelle ; en particulier **pas** de
///   `zcrud_ui_kit`, donc pas de `ZPageScaffold`).
/// * Il ne code **aucune couleur** ni **aucun libellé** en dur (FR-26/NFR-S7) :
///   couleurs = rôles du `ColorScheme`, libellés = `label(context, …)` de
///   `ZcrudLocalizations`, tous **surchargeables par paramètre**.
/// * Il n'est **jamais** monté par défaut : `presentEdition(chrome: null)` rend
///   l'arbre d'aujourd'hui, à l'identique (garde d'identité d'arbre).
///
/// ## AD-13 (a11y / RTL)
///
/// Toutes les insets/alignements sont **directionnels** ; chaque action porte
/// un `Semantics(button:, enabled:, label:)` **explicite** et une cible tactile
/// **assertée** par `ConstrainedBox` (jamais le plancher ambiant du SDK, qui
/// disparaît sous `MaterialTapTargetSize.shrinkWrap`) ; l'état activé/désactivé
/// est porté par la **sémantique** autant que par la couleur.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZDiscardGuard,
        ZSubmissionState,
        ZSubmissionStatus,
        label;

import '../domain/z_edition_presentation.dart';
import 'z_edition_chrome.dart';

/// Rend le [chrome] autour de [body], sous la forme dictée par [mode].
///
/// [metrics] permet de surcharger **par paramètre** les dimensions (priorité la
/// plus haute) ; à défaut elles sont résolues par [zEditionChromeMetricsOf]
/// (jeton `ZcrudTheme` puis [ZEditionChromeReference]).
class ZEditionScaffold extends StatelessWidget {
  /// Construit le chrome d'édition.
  const ZEditionScaffold({
    required this.body,
    required this.chrome,
    required this.mode,
    this.metrics,
    super.key,
  });

  /// Contenu du formulaire (opaque — jamais inspecté).
  final Widget body;

  /// Descripteur du chrome (titre, libellés, callbacks, actions).
  final ZEditionChrome chrome;

  /// Mode retenu par `ZPresentationPolicy` (jamais recalculé ici).
  final ZEditionPresentation mode;

  /// Surcharge **par paramètre** des métriques (priorité la plus haute).
  final ZEditionChromeMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final ZEditionChromeMetrics m = metrics ?? zEditionChromeMetricsOf(context);

    // AD-10 : chaîne de conditions avec REPLI TERMINAL — un mode ajouté plus
    // tard à l'enum rend la forme `dialog` (la plus neutre) au lieu de lever.
    final Widget rendered;
    if (mode == ZEditionPresentation.page) {
      rendered = _buildPage(context, m);
    } else if (mode == ZEditionPresentation.sheet) {
      rendered = _buildSheet(context, m);
    } else {
      rendered = _buildDialog(context, m);
    }

    final ZDiscardGuardHost host = ZDiscardGuardHost(chrome: chrome);
    return host.wrap(rendered);
  }

  // ── page ────────────────────────────────────────────────────────────────
  //
  // `SliverAppBar(floating: true, pinned: false)` : l'en-tête se REPLIE au
  // défilement et reparaît au défilement inverse — le comportement du
  // `listenToScrool` de `scaffoldDialog` (DODLP legacy), obtenu nativement.
  Widget _buildPage(BuildContext context, ZEditionChromeMetrics m) {
    final List<Widget> actions = _actions(context, m);
    final String? title = chrome.title;
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            floating: true,
            pinned: false,
            // `title` ABSENT de l'arbre quand aucun titre n'est fourni (AD-4) —
            // jamais un `SizedBox.shrink` de remplissage.
            title: title == null
                ? null
                : Semantics(header: true, child: Text(title)),
            leading: _ZChromeAction(
              label: chrome.discardLabel ?? label(context, 'close'),
              metrics: m,
              onTap: () => _discard(context),
              emphasis: _ZActionEmphasis.neutral,
            ),
            leadingWidth: m.minTouchTarget * 2,
            actions: actions.isEmpty ? null : actions,
          ),
          SliverToBoxAdapter(child: body),
        ],
      ),
    );
  }

  // ── dialog ──────────────────────────────────────────────────────────────
  Widget _buildDialog(BuildContext context, ZEditionChromeMetrics m) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _header(context, m),
        Flexible(child: body),
        _actionBar(context, m),
      ],
    );
  }

  // ── sheet ───────────────────────────────────────────────────────────────
  Widget _buildSheet(BuildContext context, ZEditionChromeMetrics m) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Poignée ABSENTE de l'arbre si désactivée (AD-4).
        if (chrome.showDragHandle)
          Semantics(
            excludeSemantics: true,
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(vertical: m.gap),
              child: Align(
                alignment: AlignmentDirectional.center,
                child: SizedBox(
                  width: ZEditionChromeReference.dragHandleWidth,
                  height: ZEditionChromeReference.dragHandleHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(
                        alpha: ZEditionChromeReference.dragHandleOpacity,
                      ),
                      borderRadius: BorderRadius.all(
                        Radius.circular(
                          ZEditionChromeReference.dragHandleHeight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        _header(context, m),
        Flexible(child: SingleChildScrollView(child: body)),
        // Actions ancrées en bas, SAFE-AREA honorée (encoche/gesture bar).
        SafeArea(top: false, child: _actionBar(context, m)),
      ],
    );
  }

  // ── briques communes ────────────────────────────────────────────────────

  /// En-tête compacte : titre (si fourni) + actions supplémentaires.
  ///
  /// Si ni titre ni action supplémentaire n'existent, l'en-tête reste un
  /// `Padding`+`Row` **vides** — jamais un `throw` (AD-10).
  Widget _header(BuildContext context, ZEditionChromeMetrics m) {
    final String? title = chrome.title;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: m.headerPadding,
      child: Row(
        children: <Widget>[
          if (title != null)
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.start,
                  style: text.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            const Spacer(),
          ...chrome.extraActions,
        ],
      ),
    );
  }

  /// Barre d'actions en pied : abandon (toujours) puis enregistrement (si une
  /// action de soumission existe).
  Widget _actionBar(BuildContext context, ZEditionChromeMetrics m) {
    return Padding(
      padding: m.actionBarPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          _ZChromeAction(
            label: chrome.discardLabel ?? label(context, 'cancel'),
            metrics: m,
            onTap: () => _discard(context),
            emphasis: _ZActionEmphasis.neutral,
          ),
          SizedBox(width: m.gap),
          ..._actions(context, m),
        ],
      ),
    );
  }

  /// Les actions **positives** : `extraActions` puis l'enregistrement.
  /// Liste **vide** (donc rien dans l'arbre) si aucune n'existe (AD-4).
  List<Widget> _actions(BuildContext context, ZEditionChromeMetrics m) {
    final List<Widget> out = <Widget>[...chrome.extraActions];
    if (!chrome.hasSubmitAction) return out;
    final String text = chrome.submitLabel ?? label(context, 'save');
    final submitController = chrome.submitController;
    if (submitController == null) {
      out.add(
        _ZChromeAction(
          label: text,
          metrics: m,
          onTap: chrome.onSubmit,
          emphasis: _ZActionEmphasis.primary,
        ),
      );
      return out;
    }
    out.add(
      // SM-1 : n'écoute QUE le canal `state` du contrôleur de soumission —
      // une frappe dans le formulaire ne reconstruit pas ce bouton.
      ValueListenableBuilder<ZSubmissionState>(
        valueListenable: submitController.state,
        builder: (BuildContext context, ZSubmissionState state, Widget? _) {
          final bool busy = state.status == ZSubmissionStatus.inProgress;
          return _ZChromeAction(
            label: text,
            metrics: m,
            emphasis: _ZActionEmphasis.primary,
            onTap: busy
                ? null
                : (chrome.onSubmit ?? () => submitController.submit()),
          );
        },
      ),
    );
    return out;
  }

  /// Voie d'abandon **explicite**. Repli : `Navigator.maybePop` — la SEULE voie
  /// native qui consulte `PopScope`, donc `ZDiscardGuard`.
  void _discard(BuildContext context) {
    final VoidCallback? explicit = chrome.onDiscard;
    if (explicit != null) {
      explicit();
      return;
    }
    Navigator.maybePop(context);
  }
}

/// Enveloppe conditionnelle par `ZDiscardGuard` — **exposée** pour que
/// `presentEdition` et les gardes puissent raisonner sur la même décision.
@immutable
class ZDiscardGuardHost {
  /// Construit l'hôte pour [chrome].
  const ZDiscardGuardHost({required this.chrome});

  /// Le chrome dont on lit [ZEditionChrome.guardsDiscard].
  final ZEditionChrome chrome;

  /// Retourne [child] tel quel si aucun garde n'est armé (AD-4 : `null` ⇒
  /// **absent de l'arbre**, jamais un nœud neutre de remplissage), sinon
  /// [child] enveloppé dans un `ZDiscardGuard`.
  Widget wrap(Widget child) {
    final controller = chrome.formController;
    if (controller == null) return child;
    return ZDiscardGuard(
      controller: controller,
      onConfirmDiscard: chrome.onConfirmDiscard,
      child: child,
    );
  }
}

/// Emphase visuelle d'une action de chrome — **jamais** le seul canal : la
/// sémantique porte `button`/`enabled`/`label` en parallèle (AD-13).
enum _ZActionEmphasis { neutral, primary }

/// Action textuelle du chrome, à cible tactile **assertée** (≥ `minTouchTarget`
/// par `ConstrainedBox` — indépendante du `MaterialTapTargetSize` ambiant).
class _ZChromeAction extends StatelessWidget {
  const _ZChromeAction({
    required this.label,
    required this.metrics,
    required this.onTap,
    required this.emphasis,
  });

  final String label;
  final ZEditionChromeMetrics metrics;
  final VoidCallback? onTap;
  final _ZActionEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool enabled = onTap != null;
    final Color color = !enabled
        ? scheme.onSurface
            .withValues(alpha: ZEditionChromeReference.disabledOpacity)
        : emphasis == _ZActionEmphasis.primary
            ? scheme.primary
            : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: metrics.minTouchTarget,
              minHeight: metrics.minTouchTarget,
            ),
            child: Align(
              alignment: AlignmentDirectional.center,
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: metrics.actionPadding,
                child: Text(
                  label,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.labelLarge?.copyWith(color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
