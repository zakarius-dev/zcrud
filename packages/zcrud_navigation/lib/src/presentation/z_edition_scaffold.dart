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
import 'package:flutter/rendering.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZDiscardGuard,
        ZSubmissionState,
        ZSubmissionStatus,
        label;

import '../domain/z_edition_presentation.dart';
import 'z_edition_body_fit.dart';
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
    this.bodyFit = ZEditionBodyFit.intrinsic,
    super.key,
  });

  /// Contenu du formulaire (opaque — jamais inspecté).
  ///
  /// 🔴 « Opaque » est une **contrainte**, pas une description : ce widget ne
  /// teste **jamais** le type de [body] pour deviner comment le placer. C'est
  /// [bodyFit] que l'appelant **déclare** — cf. `z_edition_body_fit.dart`.
  final Widget body;

  /// Descripteur du chrome (titre, libellés, callbacks, actions).
  final ZEditionChrome chrome;

  /// Mode retenu par `ZPresentationPolicy` (jamais recalculé ici).
  final ZEditionPresentation mode;

  /// Surcharge **par paramètre** des métriques (priorité la plus haute).
  final ZEditionChromeMetrics? metrics;

  /// **Déclaration** de l'appelant : comment [body] veut être placé.
  ///
  /// Défaut [ZEditionBodyFit.intrinsic] — le comportement de v0.60.0, à
  /// l'identique. Passez [ZEditionBodyFit.scrollable] quand le corps défile
  /// lui-même : c'est alors le **contenant** qui le borne, et le corps garde son
  /// propre défilement (aucun `shrinkWrap` à poser côté appelant).
  final ZEditionBodyFit bodyFit;

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
  //
  // 🔴 Corps SCROLLABLE (`bodyFit: scrollable`) : `NestedScrollView`, et NON
  // `SliverFillRemaining(hasScrollBody: true)`. Les deux ont été mesurés
  // (probe du 2026-08-09, corps `ListView` de 60 lignes, glissement de 400 px) :
  //
  //   * `SliverFillRemaining(hasScrollBody: true)` — le corps défile bien
  //     (`L0` sort de l'arbre, `L10` y entre), **mais l'en-tête ne se replie
  //     plus JAMAIS** : le titre reste à `Rect.fromLTRB(16, 14, 126, 42)` après
  //     le glissement. Le corps consomme tout le geste, le viewport externe
  //     n'a plus rien à défiler. Les deux exigences se CONTREDISENT sur cette
  //     forme.
  //   * `NestedScrollView` — le corps défile **et** l'en-tête se replie (le
  //     titre disparaît de l'arbre après le même glissement). C'est la seule
  //     forme mesurée qui satisfait les deux ; c'est celle retenue.
  Widget _buildPage(BuildContext context, ZEditionChromeMetrics m) {
    final Widget bar = _pageAppBar(context, m);
    if (bodyFit == ZEditionBodyFit.scrollable) {
      return Scaffold(
        body: NestedScrollView(
          // 🔴 `floatHeaderSlivers: true` n'est PAS décoratif : sans lui,
          // l'en-tête `floating` se replie bien, mais ne REPARAÎT qu'une fois
          // le corps ramené tout en haut. Mesuré (glissement inverse de
          // 200 px) : sans le drapeau, titre toujours absent ; avec, titre
          // revenu. C'est le drapeau qui rend au corps scrollable le
          // comportement EXACT du `SliverAppBar(floating: true)` livré en
          // v0.60.0.
          floatHeaderSlivers: true,
          headerSliverBuilder: (BuildContext _, bool _) => <Widget>[bar],
          body: body,
        ),
      );
    }
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          bar,
          SliverToBoxAdapter(child: _ZUnboundedBodyGuard(child: body)),
        ],
      ),
    );
  }

  /// L'en-tête de page — **une seule** définition, partagée par les deux
  /// régimes de [bodyFit] : `floating: true, pinned: false` (repli au scroll)
  /// n'est donc pas re-décidé deux fois.
  Widget _pageAppBar(BuildContext context, ZEditionChromeMetrics m) {
    final List<Widget> actions = _actions(context, m);
    final String? title = chrome.title;
    return SliverAppBar(
      floating: true,
      pinned: false,
      // `title` ABSENT de l'arbre quand aucun titre n'est fourni (AD-4) —
      // jamais un `SizedBox.shrink` de remplissage.
      title:
          title == null ? null : Semantics(header: true, child: Text(title)),
      leading: _ZChromeAction(
        label: chrome.discardLabel ?? label(context, 'close'),
        metrics: m,
        onTap: () => _discard(context),
        emphasis: _ZActionEmphasis.neutral,
      ),
      leadingWidth: m.minTouchTarget * 2,
      actions: actions.isEmpty ? null : actions,
    );
  }

  // ── dialog ──────────────────────────────────────────────────────────────
  //
  // 🔴 [bodyFit] n'a **aucun effet** ici, et ce n'est pas un oubli : `Flexible`
  // donne déjà au corps une hauteur BORNÉE. Mesuré (probe du 2026-08-09) : un
  // corps `ListView` en mode `dialog` monte avec **zéro** exception, là où
  // `page` en lève 14 et `sheet` 23. Aucune symétrie n'a été supposée entre les
  // trois modes — chacun a été mesuré séparément. Aucune garde de corps non
  // borné n'est posée ici non plus : le cas ne peut pas se produire.
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
        // 🔴 Un corps qui défile DÉJÀ ne s'imbrique pas dans un
        // `SingleChildScrollView` : celui-ci lui donne une hauteur INFINIE,
        // c'est le même piège qu'en `page`. Mesuré : `ListView` en feuille
        // `intrinsic` ⇒ 23 exceptions ; sous `Flexible` nu ⇒ 0, et le corps
        // défile tandis que la barre d'actions reste ancrée.
        if (bodyFit == ZEditionBodyFit.scrollable)
          Flexible(child: body)
        else
          Flexible(
            child: SingleChildScrollView(
              child: _ZUnboundedBodyGuard(child: body),
            ),
          ),
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

/// Garde de **développement** (AD-10) : transforme l'écran blanc de la CR
/// scaffold-scrollable-body en **un** message actionnable qui nomme le
/// paramètre à passer.
///
/// ## Ce qui n'était PAS atteignable, et pourquoi
///
/// Intercepter l'exception du corps est **impossible** : `RenderObject.layout`
/// enveloppe lui-même `performResize`/`performLayout` dans un `try/catch` qui
/// **rapporte puis avale** (`_reportException`), et remet `_needsLayout` à
/// `false`. Mesuré : un `try/catch` autour de `child.layout(...)` n'attrape
/// **rien** (probe 3, 0 occurrence du message), et `child.debugNeedsLayout` est
/// `false` après l'échec — deux signaux inutilisables.
///
/// Le signal **fiable** est `child.hasSize` : un `RenderBox` dont le
/// `performResize` a levé n'a jamais reçu de taille. La condition est donc
/// « contrainte de hauteur **infinie** ET l'enfant n'a pas de taille après
/// `layout` ». Elle ne peut pas produire de faux positif : un `layout` réussi
/// pose toujours une taille (mesuré : corps `Text` court ⇒ aucune détection).
///
/// ## FR-26 — ce message ne peut PAS s'afficher
///
/// Il n'est **jamais** un widget : aucun `Text`, aucun `ErrorWidget`, aucune
/// couleur. C'est un `FlutterErrorDetails` **construit et rapporté à
/// l'intérieur d'un `assert`** — donc élidé du binaire en profil et en release
/// (la garde de source `z_edition_chrome_source_guard_test.dart` continue par
/// ailleurs d'interdire tout littéral de couleur ou de libellé d'UI).
class _ZUnboundedBodyGuard extends SingleChildRenderObjectWidget {
  const _ZUnboundedBodyGuard({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ZRenderUnboundedBodyGuard();
}

class _ZRenderUnboundedBodyGuard extends RenderProxyBox {
  bool _degraded = false;

  @override
  void performLayout() {
    final RenderBox? c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(constraints, parentUsesSize: true);
    _degraded = false;
    assert(() {
      if (constraints.maxHeight != double.infinity || c.hasSize) return true;
      _degraded = true;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
              'ZEditionScaffold : le corps DÉFILE lui-même, mais il a été '
              'placé en `ZEditionBodyFit.intrinsic` (le défaut).',
            ),
            ErrorDescription(
              'Dans ce régime le corps reçoit une hauteur INFINIE, ce qui fait '
              'lever « Vertical viewport was given unbounded height » puis une '
              'cascade de « RenderBox was not laid out » — écran blanc.',
            ),
            ErrorHint(
              'Déclarez-le : ZEditionScaffold(bodyFit: '
              'ZEditionBodyFit.scrollable) — ou presentEdition(bodyFit: '
              'ZEditionBodyFit.scrollable). Ne modifiez PAS votre corps : ni '
              '`shrinkWrap: true`, ni `NeverScrollableScrollPhysics()`.',
            ),
          ]),
          library: 'zcrud_navigation',
          context: ErrorDescription('pendant la mise en page du chrome '
              'd\'édition'),
        ),
      );
      return true;
    }());
    // En release `_degraded` reste `false` (l'`assert` est élidé) : la taille
    // de l'enfant est lue comme avant — aucun changement de comportement.
    size = _degraded ? constraints.constrain(Size.zero) : c.size;
  }

  // Un enfant sans taille ne peut être ni peint ni testé au toucher : le faire
  // rejouerait la cascade qu'on vient de remplacer par UN message.
  @override
  void paint(PaintingContext context, Offset offset) {
    if (_degraded) return;
    super.paint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_degraded) return false;
    return super.hitTestChildren(result, position: position);
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
