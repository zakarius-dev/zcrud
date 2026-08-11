/// `ZProviderResolver` — implémentation `provider` du seam de résolution
/// (invariant AD-6).
///
/// Matérialise le contrat `ZDependencyResolver` du cœur en déléguant à
/// `context.read<T>()` (lecture non écoutante du package `provider`). Le cœur
/// ignore totalement `provider` (invariant AD-15) : il n'appelle que
/// `ZcrudScope.of(context).resolver.resolve<T>()`.
library;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Résolveur de dépendances adossé à l'arbre `provider` sous un [BuildContext].
///
/// `resolve<T>()` interroge le [BuildContext] fourni (situé SOUS les providers du
/// [ZcrudProviderScope]) via `Provider.of<T>(..., listen: false)` — l'équivalent
/// de `context.read<T>()`. Si aucun provider ne fournit `T`, la
/// `ProviderNotFoundException` interne est convertie en [ZScopeError] actionnable
/// (« seams throw par défaut », invariant AD-6).
///
/// **Identité stable (parité invariant AD-15)** : l'instance est **mémoïsée** par
/// le [ZcrudProviderScope] (créée une fois) ; son [BuildContext] sous les
/// providers est (ré)injecté par [attach] à chaque rebuild du scope SANS changer
/// l'identité du resolver. `ZcrudScope.updateShouldNotify` compare le resolver
/// par `identical(...)` : une identité stable évite le sur-rebuild de tous les
/// consommateurs de `ZcrudScope.of`, à parité avec les autres bindings.
class ZProviderResolver extends ZDependencyResolver {
  /// Construit le resolver. Le [BuildContext] situé sous les providers peut être
  /// fourni au montage ou (ré)attaché ensuite via [attach].
  ZProviderResolver([this._context]);

  BuildContext? _context;

  /// (Ré)attache le [context] situé SOUS les providers, en **conservant
  /// l'identité** du resolver (appelé par [ZcrudProviderScope] à chaque build).
  void attach(BuildContext context) => _context = context;

  @override
  T resolve<T>() {
    final context = _context;
    if (context == null) {
      throw ZScopeError(
        'ZProviderResolver non attaché à un BuildContext sous les providers du '
        'ZcrudProviderScope (bug interne : attach() non appelé avant resolve).',
      );
    }
    try {
      return Provider.of<T>(context, listen: false);
    } on ProviderNotFoundException catch (e) {
      throw ZScopeError(
        'Aucun provider ne fournit le type «${e.valueType}» sous le '
        'ZcrudProviderScope. Ajoutez-le via '
        'ZcrudProviderScope(providers: [Provider<$T>.value(value: ...)]).',
      );
    }
  }
}
