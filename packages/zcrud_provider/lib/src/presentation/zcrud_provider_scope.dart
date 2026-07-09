/// `ZcrudProviderScope` — scope de binding `provider` (E2-9, AD-6/AD-15).
///
/// origine: équivalent de `ZcrudScope` pour l'idiome `provider`. Il (a) monte un
/// `ChangeNotifierProvider<ZFormController>` (dont `provider` gère le `dispose()`
/// automatiquement au démontage), (b) expose les seams applicatifs via des
/// providers additionnels, puis (c) enveloppe l'enfant dans un `ZcrudScope`
/// porteur d'un `ZProviderResolver` manager-backed (construit sous les
/// providers). Le binding NE réimplémente PAS la réactivité : il réutilise
/// `ZFormController` (AD-2) tel quel.
library;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_provider_resolver.dart';

/// Scope Flutter branchant l'injection/lifecycle sur `provider`.
///
/// **StatefulWidget** (et non `StatelessWidget`) afin de **mémoïser** le
/// [ZProviderResolver] : son identité reste stable à travers les rebuilds du
/// scope, si bien que `ZcrudScope.updateShouldNotify` (comparaison `identical`)
/// n'oblige jamais les consommateurs de `ZcrudScope.of` à se reconstruire sans
/// changement réel — à parité avec `zcrud_get`/`zcrud_riverpod` (MEDIUM-1,
/// AD-15/AD-2). Le `dispose()` du `ZFormController` reste, lui, entièrement géré
/// par `provider` (via `ChangeNotifierProvider`).
class ZcrudProviderScope extends StatefulWidget {
  /// Construit le scope.
  ///
  /// [createController] : fabrique du `ZFormController` exposé par le
  /// `ChangeNotifierProvider` (par défaut un `ZFormController()` vide) ; son
  /// `dispose()` est géré par `provider`. [providers] : providers additionnels
  /// (seams applicatifs) résolus par [ZProviderResolver]. [acl] : port
  /// d'autorisation exposé au cœur.
  const ZcrudProviderScope({
    required this.child,
    this.createController,
    this.providers = const [],
    this.acl = const ZAllowAllAcl(),
    super.key,
  });

  /// Sous-arbre applicatif placé sous le `ZcrudScope` manager-backed.
  final Widget child;

  /// Fabrique du `ZFormController` exposé (dispose géré par `provider`).
  final ZFormController Function()? createController;

  /// Providers additionnels (seams applicatifs) montés au-dessus du scope.
  final List<SingleChildWidget> providers;

  /// Port d'autorisation exposé au cœur (défaut : [ZAllowAllAcl]).
  final ZAcl acl;

  @override
  State<ZcrudProviderScope> createState() => _ZcrudProviderScopeState();
}

class _ZcrudProviderScopeState extends State<ZcrudProviderScope> {
  // Resolver MÉMOÏSÉ (identité stable) : créé une seule fois, son BuildContext
  // sous les providers lui est (ré)attaché à chaque build via `attach` — sans
  // changer son identité (parité AD-15 avec get/riverpod, MEDIUM-1).
  late final ZProviderResolver _resolver = ZProviderResolver();

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ZFormController>(
            // `lazy: false` : le controller est créé (et donc disposé par
            // `provider`) même s'il n'est jamais lu — un scope de formulaire
            // possède son controller dès le montage (pas de création paresseuse).
            lazy: false,
            create: (_) =>
                widget.createController?.call() ?? ZFormController(),
          ),
          ...widget.providers,
        ],
        // `Builder` : obtient un context SOUS les providers pour que
        // `ZProviderResolver` (context.read) les voie. Le context du `Builder`
        // est STABLE d'un build à l'autre ; on le (ré)attache au resolver
        // mémoïsé sans jamais recréer ce dernier (identité stable).
        child: Builder(
          builder: (inner) {
            _resolver.attach(inner);
            return ZcrudScope(
              resolver: _resolver,
              acl: widget.acl,
              child: widget.child,
            );
          },
        ),
      );
}
