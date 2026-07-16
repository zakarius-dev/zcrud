/// Widgets d'état de contenu génériques + aiguilleur (AD-32, AD-13).
///
/// `ZEmptyState` / `ZLoadingState` / `ZErrorState` neutralisent les états
/// dupliqués des applications (dodlp `state_widgets.dart`, iffd `empty_*`) en
/// widgets **purs** : thème & couleurs dérivés du `ColorScheme` (jamais de hex),
/// textes fournis par l'appelant (l10n injectée), `Semantics` explicites, cibles
/// tactiles ≥ 48 dp, mise en page **directionnelle** (RTL-safe). `ZContentStateView`
/// aiguille vers le bon widget selon [ZContentState] via un `switch` exhaustif.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_content_state.dart';

/// Cible tactile minimale (Material / AD-13) pour tout bouton/CTA.
const double _kMinTouchTarget = 48;

/// Style de bouton garantissant une cible tactile ≥ 48 dp (AD-13).
final ButtonStyle _kA11yButtonStyle = TextButton.styleFrom(
  minimumSize: const Size(_kMinTouchTarget, _kMinTouchTarget),
);

/// État **vide** générique : contenu chargé mais aucune donnée à afficher.
///
/// Rend une icône **optionnelle** + un titre **optionnel** + un [message]
/// **toujours présent** (l'icône n'est jamais le seul canal d'information —
/// AD-13/NFR-U4) + un CTA **optionnel** ([actionLabel] + [onAction]). Les textes
/// sont fournis par l'appelant (aucune chaîne métier codée en dur) ; les couleurs
/// proviennent du `Theme.of(context)` courant.
class ZEmptyState extends StatelessWidget {
  /// Construit un état vide. [message] est requis (canal texte garanti).
  const ZEmptyState({
    required this.message,
    this.icon,
    this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Message principal (toujours affiché).
  final String message;

  /// Icône illustrative optionnelle (jamais le seul canal).
  final IconData? icon;

  /// Titre optionnel affiché au-dessus du [message].
  final String? title;

  /// Libellé du CTA optionnel (requis pour afficher le bouton avec [onAction]).
  final String? actionLabel;

  /// Callback du CTA optionnel.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _ZStateScaffold(
      icon: icon,
      iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      title: title,
      message: message,
      semanticLabel: title == null ? message : '$title. $message',
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// État **chargement** générique : indicateur de progression + message optionnel.
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
    // A11y (AD-13 / WCAG 4.1.3) : annoncer le chargement au lecteur d'écran
    // MÊME sans message visible (le repli par défaut de `ZContentStateView` est
    // `const ZLoadingState()` sans message). Libellé dérivé de la l10n injectée
    // par composition DÉFENSIVE (jamais `.of()` qui pourrait lever ; que des
    // `maybeOf`/`maybeResolve`), jamais un `Semantics.label` nul.
    final String a11yLabel = message ??
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
      // Rôle « en direct » : annonce le chargement en cours.
      liveRegion: true,
      label: a11yLabel,
      child: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// État **erreur** générique : icône + message + CTA « réessayer » optionnel.
///
/// La teinte d'erreur est **dérivée** du `ColorScheme` courant via `ZcrudTheme`
/// (`ZcrudScope.theme?.errorColor` → repli `ZcrudTheme.fallback(Theme.of).errorColor`
/// = `ColorScheme.error`) — jamais un littéral hex (AD-13/NFR-U5). Le [message]
/// (texte) reste toujours présent : la couleur n'est jamais le seul canal.
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
    final errorColor = ZcrudTheme.of(context).errorColor ??
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
/// `switch` **exhaustif sans `default`** sur les 5 valeurs (un nouveau palier
/// casserait la compilation → détection à froid, NFR-U7). Replis **sûrs**
/// (AD-10, jamais de throw) :
/// - `success` → [successBuilder] (obligatoire) ;
/// - `loading` → [loading] fourni, sinon `const ZLoadingState()` ;
/// - `idle` / `empty` / `error` → la tranche fournie, sinon `SizedBox.shrink()`.
class ZContentStateView extends StatelessWidget {
  /// Construit l'aiguilleur. [state] et [successBuilder] sont requis ; les
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

  /// Tranche `idle` optionnelle (repli : `SizedBox.shrink()`).
  final Widget? idle;

  /// Tranche `loading` optionnelle (repli : `const ZLoadingState()`).
  final Widget? loading;

  /// Tranche `empty` optionnelle (repli : `SizedBox.shrink()`).
  final Widget? empty;

  /// Tranche `error` optionnelle (repli : `SizedBox.shrink()`).
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    // Exhaustif sans `default` : un nouveau membre de ZContentState casserait la
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

/// Ossature commune (privée) des états vide/erreur : icône optionnelle + titre
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
  });

  final IconData? icon;
  final Color iconColor;
  final String? title;
  final Color? titleColor;
  final String message;
  final String semanticLabel;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showAction = actionLabel != null && onAction != null;
    // Bloc informationnel (icône + titre + message) : la sémantique est portée
    // UNE seule fois par le container (label explicite), les nœuds texte/icône
    // visuels sont exclus pour éviter la double annonce (a11y). Le CTA reste
    // HORS de cette exclusion → il garde sa propre sémantique cliquable.
    final visual = ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...[
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 16),
          ],
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: titleColor),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Semantics(
              container: true,
              label: semanticLabel,
              child: visual,
            ),
            if (showAction) ...[
              const SizedBox(height: 16),
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
