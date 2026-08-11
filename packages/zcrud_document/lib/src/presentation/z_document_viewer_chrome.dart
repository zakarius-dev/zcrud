/// Coquille de viewer de document indépendante de tout moteur de rendu.
///
/// L'hôte fournit le contenu, les barres, les vues d'état et les libellés
/// localisés. Cette surface ne connaît donc ni PDF, ni contrôleur de rendu,
/// ni dépendance tierce.
library;

import 'package:flutter/material.dart';

/// État de lecture affiché par [ZDocumentViewerChrome].
enum ZDocumentViewerLoadState {
  /// Le slot [ZDocumentViewerChrome.document] peut être affiché.
  content,

  /// L'hôte charge le document.
  loading,

  /// L'hôte a rencontré une erreur de lecture.
  error,

  /// L'hôte n'a aucun document à afficher.
  empty,
}

/// Navigation de pages fournie et localisée par l'hôte.
///
/// Les callbacks restent au niveau de l'application : la coquille ne possède
/// aucun état de page et ne communique avec aucun moteur de rendu.
class ZDocumentPageNavigation {
  /// Crée une navigation sans libellé implicite.
  const ZDocumentPageNavigation({
    required this.previousPageLabel,
    required this.nextPageLabel,
    this.onPreviousPage,
    this.onNextPage,
  });

  /// Libellé localisé de l'action vers la page précédente.
  final String previousPageLabel;

  /// Libellé localisé de l'action vers la page suivante.
  final String nextPageLabel;

  /// Demande à l'hôte d'afficher la page précédente ; `null` désactive l'action.
  final VoidCallback? onPreviousPage;

  /// Demande à l'hôte d'afficher la page suivante ; `null` désactive l'action.
  final VoidCallback? onNextPage;
}

/// Chrome composable d'un viewer de document, sans moteur de rendu.
///
/// Chaque slot est optionnel et n'est jamais remplacé par une vue ou un texte
/// implicite. En particulier, [document] absent ne crée aucun sous-arbre de
/// contenu. Les états [loading], [error] et [empty] sont des widgets injectés
/// par l'hôte ; leurs libellés restent donc dans la couche l10n de l'application.
class ZDocumentViewerChrome extends StatelessWidget {
  /// Crée une coquille de viewer optionnelle.
  const ZDocumentViewerChrome({
    this.document,
    this.topBar,
    this.bottomBar,
    this.loadState = ZDocumentViewerLoadState.content,
    this.loading,
    this.error,
    this.empty,
    this.pageNavigation,
    super.key,
  });

  /// Contenu rendu par le moteur choisi par l'hôte.
  final Widget? document;

  /// Slot de barre supérieure fourni par l'hôte.
  final Widget? topBar;

  /// Slot de barre inférieure fourni par l'hôte.
  final Widget? bottomBar;

  /// État de lecture piloté par l'hôte.
  final ZDocumentViewerLoadState loadState;

  /// Vue de chargement injectée par l'hôte.
  final Widget? loading;

  /// Vue d'erreur injectée par l'hôte.
  final Widget? error;

  /// Vue vide injectée par l'hôte.
  final Widget? empty;

  /// Navigation sans connaissance du moteur, ou `null` si absente.
  final ZDocumentPageNavigation? pageNavigation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = _bodyForState();
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (topBar case final topBar?) topBar,
          if (topBar case final _?)
            Divider(height: 1, color: scheme.outlineVariant),
          if (body != null) Expanded(child: body),
          if (pageNavigation != null)
            _PageNavigationBar(navigation: pageNavigation!),
          if (bottomBar case final _?)
            Divider(height: 1, color: scheme.outlineVariant),
          if (bottomBar case final bottomBar?) bottomBar,
        ],
      ),
    );
  }

  Widget? _bodyForState() {
    switch (loadState) {
      case ZDocumentViewerLoadState.content:
        return document;
      case ZDocumentViewerLoadState.loading:
        return loading;
      case ZDocumentViewerLoadState.error:
        return error;
      case ZDocumentViewerLoadState.empty:
        return empty;
    }
  }
}

class _PageNavigationBar extends StatelessWidget {
  const _PageNavigationBar({required this.navigation});

  final ZDocumentPageNavigation navigation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainerLow),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _PageAction(
              icon: Icons.chevron_left,
              label: navigation.previousPageLabel,
              onPressed: navigation.onPreviousPage,
            ),
            _PageAction(
              icon: Icons.chevron_right,
              label: navigation.nextPageLabel,
              onPressed: navigation.onNextPage,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageAction extends StatelessWidget {
  const _PageAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, textAlign: TextAlign.start),
      ),
    ),
  );
}
