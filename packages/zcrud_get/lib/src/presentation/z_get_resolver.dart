/// `ZGetResolver` — implémentation `get_it` du seam de résolution (AD-6).
///
/// origine: matérialise, pour le binding DODLP (E7), le contrat
/// `ZDependencyResolver` du cœur en déléguant la résolution des dépendances
/// applicatives au **service locator** `get_it` (idiome DODLP `getIt<T>()`). Le
/// cœur n'appelle QUE `ZcrudScope.of(context).resolver.resolve<T>()` : il ignore
/// totalement que GetX/get_it sont derrière (AD-15).
///
/// Note de conception (bound) : `ZDependencyResolver.resolve<T>()` a un `T`
/// **non borné** (nullable possible), alors que get_it exige `T extends Object`.
/// On franchit proprement l'écart via le paramètre `type:` de get_it (lookup par
/// `Type` à l'exécution), sans jamais passer un `T` non borné à l'API générique.
library;

import 'package:get_it/get_it.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Résolveur de dépendances adossé au locator `get_it`.
///
/// `resolve<T>()` interroge le [GetIt] fourni par le [ZcrudGetScope]. Si `T`
/// n'y est pas enregistré, lève [ZScopeError] avec un message actionnable —
/// jamais une résolution silencieuse (« seams throw par défaut », AD-6).
class ZGetResolver extends ZDependencyResolver {
  /// Construit le resolver autour d'un [locator] `get_it`.
  const ZGetResolver(this._locator);

  final GetIt _locator;

  @override
  T resolve<T>() {
    // Lookup par Type (escape hatch get_it) → compatible avec un `T` non borné.
    if (!_locator.isRegistered<Object>(type: T)) {
      throw ZScopeError(
        'Aucune dépendance de type «$T» enregistrée dans le locator get_it '
        'du ZcrudGetScope. Enregistrez-la (getIt.registerSingleton<$T>(...) ou '
        'Get.put<$T>(...)) avant de la résoudre.',
      );
    }
    return _locator.get<Object>(type: T) as T;
  }
}
