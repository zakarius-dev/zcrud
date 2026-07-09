/// Seam de **résolution de dépendances** (AD-6) — défaut « throw ».
///
/// origine: point d'extension unique par lequel un binding (E2-9 :
/// `zcrud_riverpod`/`zcrud_get`/`zcrud_provider`) ou un `ZcrudScope` configuré
/// fournit au cœur les dépendances applicatives, SANS que le cœur ne référence
/// jamais un gestionnaire d'état (AD-15).
library;

import 'z_scope_error.dart';

/// Résolveur de dépendances abstrait fourni par l'app/binding.
///
/// L'implémentation **par défaut** ([throwing]) lève [ZScopeError] sur tout
/// [resolve] : rien n'est résolu magiquement tant qu'un binding/scope n'a pas
/// explicitement fourni la dépendance. Le **seam de cycle de vie** du
/// `ZFormController` (création/scoping/dispose) est, lui aussi, résolu par ce
/// canal côté binding (E2-9) ; le défaut zéro-config est le « cycle local
/// possédé par l'hôte » (l'hôte crée et `dispose()` son contrôleur).
abstract class ZDependencyResolver {
  /// Constructeur `const` pour les implémentations immuables.
  const ZDependencyResolver();

  /// Résolveur **par défaut** : lève [ZScopeError] sur tout [resolve].
  static const ZDependencyResolver throwing = _ThrowingResolver();

  /// Résout la dépendance de type [T] fournie par le binding.
  ///
  /// Lève [ZScopeError] (message actionnable) si [T] n'a pas été fournie.
  T resolve<T>();
}

/// Implémentation par défaut : `throw` systématique (« seams throw par défaut »).
class _ThrowingResolver extends ZDependencyResolver {
  const _ThrowingResolver();

  @override
  T resolve<T>() => throw ZScopeError(
        'Aucune dépendance de type «$T» fournie par un ZcrudScope/binding. '
        'Fournissez-la via ZcrudScope(resolver: ...) ou un binding E2-9 '
        '(zcrud_riverpod/zcrud_get/zcrud_provider).',
      );
}
