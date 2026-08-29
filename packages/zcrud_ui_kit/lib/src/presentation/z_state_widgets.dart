/// Widgets d'état de contenu génériques + aiguilleur (invariant AD-13).
///
/// `ZEmptyState` / `ZLoadingState` / `ZErrorState` factorisent les widgets
/// d'état de contenu en widgets **purs** : thème & couleurs dérivés du
/// `ColorScheme` (jamais de hex), textes fournis par l'appelant (l10n
/// injectée), `Semantics` explicites, cibles tactiles ≥ 48 dp, mise en page
/// **directionnelle** (RTL-safe). `ZContentStateView` aiguille vers le bon
/// widget selon [ZContentState] via un `switch` exhaustif.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_content_state.dart';
import '../domain/z_empty_state_spec.dart';

/// Cible tactile minimale (Material / AD-13) pour tout bouton/CTA.
const double _kMinTouchTarget = 48;

/// Mesure de référence du glyphe des états d'erreur, en dp.
///
/// Volontairement distincte du repli de `ZEmptyStateStyle` : les jetons
/// `emptyState*` ne pilotent **que** l'état vide, et un état d'erreur ne doit
/// pas changer de taille parce qu'un hôte a réglé son état vide.
const double _kStateIconSize = 48;

/// Rythme vertical de référence des états, en dp.
const double _kStateSpacing = 16;

/// Écart titre → message, en dp — décision interne, hors jeton.
const double _kStateTitleGap = 8;

/// Retrait extérieur de référence des états, en dp.
const double _kStatePadding = 24;

/// Style de bouton garantissant une cible tactile ≥ 48 dp (AD-13).
final ButtonStyle _kA11yButtonStyle = TextButton.styleFrom(
  minimumSize: const Size(_kMinTouchTarget, _kMinTouchTarget),
);

/// État **vide** générique : contenu chargé mais aucune donnée à afficher.
///
/// Rend une illustration **optionnelle** (un glyphe [icon], ou le widget
/// [illustration] qui le remplace) + un titre **optionnel** + un [message]
/// **toujours présent** (l'image n'est jamais le seul canal d'information,
/// invariant AD-13) + un CTA **optionnel** ([actionLabel] + [onAction]). Les
/// textes sont fournis par l'appelant (aucune chaîne métier codée en dur).
///
/// ## Ce qui décide du pixel
///
/// Taille et couleur du glyphe, styles du titre et du message, rythme
/// vertical : tout vient de `ZEmptyStateStyle.resolve(context)`, donc des
/// jetons `emptyState*` de `ZcrudTheme`. **Aucun jeton posé ⇒ rendu
/// strictement identique** à celui d'un socle qui ne les lirait pas : les
/// replis du style sont exactement les valeurs de référence du composant
/// (48 dp, `onSurfaceVariant`, `titleMedium`, `bodyMedium`, `gapL`).
///
/// La taille du glyphe suit la priorité **paramètre > jeton > défaut** :
/// [iconSize] l'emporte sur `emptyStateIconSize`, qui l'emporte sur 48 dp. Un
/// écran qui a besoin d'une seule dérogation n'a donc pas à réécrire le thème.
///
/// ## Illustration
///
/// [illustration] **remplace** le glyphe : quand elle est fournie, [icon]
/// n'est pas rendu, même s'il est non nul. C'est le point d'entrée d'une image
/// de marque, d'un `SvgPicture` ou d'une animation — le socle ne connaît
/// aucun asset et n'en fabrique aucun.
///
/// ## Table par nature de contenu
///
/// [ZEmptyState.fromSpec] construit l'état à partir d'un [ZEmptyStateSpec] et
/// d'un registre de libellés. La **table** qui associe une nature de contenu
/// (dossiers, cartes, notes…) à sa spec appartient à l'hôte ou au module
/// d'étude qui connaît ces natures : ce paquet est transverse et n'en nomme
/// aucune.
class ZEmptyState extends StatelessWidget {
  /// Construit un état vide. [message] est requis (canal texte garanti).
  const ZEmptyState({
    required this.message,
    this.icon,
    this.illustration,
    this.iconSize,
    this.title,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  /// Construit un état vide à partir d'une [spec] et d'un registre [labels].
  ///
  /// Les clés de la spec sont résolues par `ZcrudLabels.resolve`, qui rend la
  /// clé elle-même quand le registre ne la porte pas : un libellé manquant
  /// dégrade l'écran, il ne le fait jamais échouer (invariant AD-10). Le CTA
  /// n'apparaît que si la spec porte une clé d'action **et** que [onAction]
  /// est fourni — une action déclarée sans callback reste structurellement
  /// absente.
  factory ZEmptyState.fromSpec(
    ZEmptyStateSpec spec,
    ZcrudLabels labels, {
    VoidCallback? onAction,
    double? iconSize,
    bool compact = false,
    Key? key,
  }) {
    final ZEmptyStateIllustrationBuilder? builder = spec.illustrationBuilder;
    return ZEmptyState(
      key: key,
      icon: spec.iconData,
      illustration: builder == null ? null : Builder(builder: builder),
      iconSize: iconSize,
      title: labels.resolve(spec.titleKey),
      message: labels.resolve(spec.messageKey),
      actionLabel: spec.actionLabelKey == null
          ? null
          : labels.resolve(spec.actionLabelKey!),
      onAction: onAction,
      compact: compact,
    );
  }

  /// Message principal (toujours affiché).
  final String message;

  /// Icône illustrative optionnelle (jamais le seul canal). Ignorée quand
  /// [illustration] est fournie.
  final IconData? icon;

  /// Illustration **remplaçant** le glyphe [icon] quand elle est fournie.
  final Widget? illustration;

  /// Taille du glyphe, en dp. Prioritaire sur le jeton `emptyStateIconSize`
  /// et sur le défaut de 48 dp. Sans effet quand [illustration] est fournie —
  /// une illustration se dimensionne elle-même.
  final double? iconSize;

  /// Titre optionnel affiché au-dessus du [message].
  final String? title;

  /// Libellé du CTA optionnel (requis pour afficher le bouton avec [onAction]).
  final String? actionLabel;

  /// Callback du CTA optionnel.
  final VoidCallback? onAction;

  /// Variante **dense** : le retrait extérieur passe de 24 à 12 dp et le
  /// rythme vertical est divisé par deux. La taille du glyphe n'est **pas**
  /// touchée — la chaîne paramètre > jeton > défaut en reste seule maîtresse,
  /// pour qu'une densité ne réécrive pas silencieusement une décision de
  /// thème.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ZEmptyStateStyle style = ZEmptyStateStyle.resolve(context);
    return _ZStateScaffold(
      icon: icon,
      illustration: illustration,
      iconSize: iconSize ?? style.iconSize,
      iconColor: style.iconColor,
      title: title,
      titleStyle: style.titleStyle,
      messageStyle: style.messageStyle,
      spacing: compact ? style.spacing / 2 : style.spacing,
      titleGap: compact ? _kStateTitleGap / 2 : _kStateTitleGap,
      padding: compact ? _kStatePadding / 2 : _kStatePadding,
      message: message,
      semanticLabel: title == null ? message : '$title. $message',
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// État **chargement** générique: indicateur de progression + message optionnel.
///
/// Porte un `Semantics(label:)` explicite pour les lecteurs d'écran. Le [message]
/// (optionnel) est fourni par l'appelant (l10n injectée).
class ZLoadingState extends StatelessWidget {
  /// Construit un état de chargement. [message] optionnel (l10n injectée).
  const ZLoadingState({this.message, super.key});

  /// Message optionnel affiché sous l'indicateur.
  final String? message;

  @override
  Widget build(BuildContext context) {
    // A11y (AD-13 / WCAG 4.1.3): annoncer le chargement au lecteur d'écran
    // MÊME sans message visible (le repli par défaut de `ZContentStateView` est
    // `const ZLoadingState()` sans message). Libellé dérivé de la l10n injectée
    // par composition DÉFENSIVE (jamais `.of()` qui pourrait lever; que des
    // `maybeOf`/`maybeResolve`), jamais un `Semantics.label` nul.
    final String a11yLabel =
        message ??
        ZcrudScope.maybeOf(context)?.labels?.maybeResolve('loading') ??
        ZcrudLocalizations.maybeOf(context)?.maybeResolve('loading') ??
        'Loading…';
    final children = <Widget>[
      const CircularProgressIndicator(),
      if (message != null) ...[
        const SizedBox(height: 16),
        Text(
          message!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ];
    return Semantics(
      // Rôle « en direct »: annonce le chargement en cours.
      liveRegion: true,
      label: a11yLabel,
      child: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

/// État **erreur** générique: icône + message + CTA « réessayer » optionnel.
///
/// La teinte d'erreur est **dérivée** du `ColorScheme` courant via `ZcrudTheme`
/// (`ZcrudScope.theme?.errorColor` → repli `ZcrudTheme.fallback(Theme.of).errorColor`
/// = `ColorScheme.error`) — jamais un littéral hex (invariant AD-13). Le [message]
/// (texte) reste toujours présent: la couleur n'est jamais le seul canal.
class ZErrorState extends StatelessWidget {
  /// Construit un état d'erreur. [message] requis (canal texte garanti).
  const ZErrorState({
    required this.message,
    this.icon,
    this.title,
    this.retryLabel,
    this.onRetry,
    super.key,
  });

  /// Message d'erreur (toujours affiché).
  final String message;

  /// Icône optionnelle (défaut visuel `Icons.error_outline` si absente).
  final IconData? icon;

  /// Titre optionnel affiché au-dessus du [message].
  final String? title;

  /// Libellé du CTA « réessayer » (requis pour afficher le bouton avec [onRetry]).
  final String? retryLabel;

  /// Callback du CTA « réessayer » optionnel.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Couleur d'erreur dérivée du thème injecté (ZcrudScope) ou du ColorScheme.
    final errorColor =
        ZcrudTheme.of(context).errorColor ??
        Theme.of(context).colorScheme.error;
    return _ZStateScaffold(
      icon: icon ?? Icons.error_outline,
      iconColor: errorColor,
      title: title,
      titleColor: errorColor,
      message: message,
      semanticLabel: title == null ? message : '$title. $message',
      actionLabel: retryLabel,
      onAction: onRetry,
    );
  }
}

/// Aiguilleur : rend le widget d'état correspondant à un [ZContentState].
///
/// `switch` **exhaustif sans `default`** sur les 5 valeurs (un nouveau
/// palier casserait la compilation → détection à froid). Replis **sûrs**
/// (invariant AD-10, jamais de throw) :
/// - `success` → [successBuilder] (obligatoire) ;
/// - `loading` → [loading] fourni, sinon `const ZLoadingState()` ;
/// - `idle` / `empty` / `error` → la tranche fournie, sinon
///   `SizedBox.shrink()`.
class ZContentStateView extends StatelessWidget {
  /// Construit l'aiguilleur. [state] et [successBuilder] sont requis; les
  /// tranches [idle]/[loading]/[empty]/[error] sont optionnelles (replis sûrs).
  const ZContentStateView({
    required this.state,
    required this.successBuilder,
    this.idle,
    this.loading,
    this.empty,
    this.error,
    super.key,
  });

  /// État courant à rendre.
  final ZContentState state;

  /// Constructeur du contenu prêt (rendu pour `ZContentState.success`).
  final WidgetBuilder successBuilder;

  /// Tranche `idle` optionnelle (repli: `SizedBox.shrink()`).
  final Widget? idle;

  /// Tranche `loading` optionnelle (repli: `const ZLoadingState()`).
  final Widget? loading;

  /// Tranche `empty` optionnelle (repli: `SizedBox.shrink()`).
  final Widget? empty;

  /// Tranche `error` optionnelle (repli: `SizedBox.shrink()`).
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    // Exhaustif sans `default`: un nouveau membre de ZContentState casserait la
    // compilation (garde à froid — enums > booléens).
    switch (state) {
      case ZContentState.idle:
        return idle ?? const SizedBox.shrink();
      case ZContentState.loading:
        return loading ?? const ZLoadingState();
      case ZContentState.empty:
        return empty ?? const SizedBox.shrink();
      case ZContentState.error:
        return error ?? const SizedBox.shrink();
      case ZContentState.success:
        return successBuilder(context);
    }
  }
}

/// Ossature commune (privée) des états vide/erreur: icône optionnelle + titre
/// optionnel + message + CTA optionnel, centrés, directionnels, avec `Semantics`.
class _ZStateScaffold extends StatelessWidget {
  const _ZStateScaffold({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.semanticLabel,
    required this.actionLabel,
    required this.onAction,
    this.titleColor,
    this.illustration,
    this.iconSize = _kStateIconSize,
    this.titleStyle,
    this.messageStyle,
    this.spacing = _kStateSpacing,
    this.titleGap = _kStateTitleGap,
    this.padding = _kStatePadding,
  });

  final IconData? icon;
  final Widget? illustration;
  final double iconSize;
  final Color iconColor;
  final String? title;
  final Color? titleColor;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final double spacing;
  final double titleGap;
  final double padding;
  final String message;
  final String semanticLabel;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showAction = actionLabel != null && onAction != null;
    // Glyphe et illustration occupent la MÊME place, et l'arbitrage a lieu ICI
    // et nulle part ailleurs : une illustration fournie l'emporte, y compris
    // quand l'appelant a aussi passé une icône. Dupliquer ce choix chez
    // l'appelant donnerait deux sites à maintenir et un seul mesurable — donc
    // une garde qui ne rougirait pas quand l'autre se casse.
    final Widget? leading =
        illustration ??
        (icon == null ? null : Icon(icon, size: iconSize, color: iconColor));
    // Bloc informationnel (icône + titre + message): la sémantique est portée
    // UNE seule fois par le container (label explicite), les nœuds texte/icône
    // visuels sont exclus pour éviter la double annonce (a11y). Le CTA reste
    // HORS de cette exclusion → il garde sa propre sémantique cliquable.
    final visual = ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (leading != null) ...[leading, SizedBox(height: spacing)],
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: (titleStyle ?? theme.textTheme.titleMedium)?.copyWith(
                color: titleColor,
              ),
            ),
            SizedBox(height: titleGap),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: messageStyle ?? theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
    return Center(
      child: Padding(
        padding: EdgeInsetsDirectional.all(padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Semantics(container: true, label: semanticLabel, child: visual),
            if (showAction) ...[
              SizedBox(height: spacing),
              TextButton(
                style: _kA11yButtonStyle,
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
