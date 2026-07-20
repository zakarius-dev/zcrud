/// `ZRiverpodResolver` — implémentation Riverpod du seam de résolution (AD-6).
///
/// origine: matérialise, pour le binding lex_douane (E8), le contrat
/// `ZDependencyResolver` du cœur en déléguant la résolution à un
/// `ProviderContainer`. Riverpod résout par PROVIDER (pas par `Type`) ; on
/// adapte l'API `resolve<T>()` du cœur via un registre `Type → provider` fourni
/// par le `ZcrudRiverpodScope`. Le cœur ignore totalement Riverpod (AD-15).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 a resserré sa surface publique : `ProviderListenable` (le type de
// « ce qui se watch/read ») n'est plus exporté par l'entrypoint principal et vit
// désormais dans `misc.dart`. Import délibéré, pas un accès à du privé.
import 'package:flutter_riverpod/misc.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Résolveur de dépendances adossé à un [ProviderContainer].
///
/// `resolve<T>()` lit le provider associé au type `T` dans le registre `seams`.
/// Si aucun provider n'est enregistré pour `T`, lève [ZScopeError] (message
/// actionnable) — jamais de résolution silencieuse (« seams throw », AD-6).
class ZRiverpodResolver extends ZDependencyResolver {
  /// Construit le resolver autour d'un [container] et d'un registre [seams]
  /// associant un `Type` au `ProviderListenable` qui le fournit.
  ZRiverpodResolver(
    this._container,
    Map<Type, ProviderListenable<Object?>> seams,
  ) : _seams = seams;

  final ProviderContainer _container;
  final Map<Type, ProviderListenable<Object?>> _seams;

  @override
  T resolve<T>() {
    final provider = _seams[T];
    if (provider == null) {
      throw ZScopeError(
        'Aucun provider Riverpod enregistré pour le type «$T» dans le '
        'ZcrudRiverpodScope. Fournissez-le via '
        'ZcrudRiverpodScope(seams: {$T: monProvider}).',
      );
    }
    return _container.read(provider) as T;
  }
}
