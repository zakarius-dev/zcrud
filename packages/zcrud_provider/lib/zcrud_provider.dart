/// Barrel d'API publique de `zcrud_provider`.
///
/// Binding état/injection <-> provider (E2-9, AD-15) — matrice AD-15.
/// Fournit `ZProviderResolver` (seam de résolution via `context.read`) et
/// `ZcrudProviderScope` (scope de binding : `ChangeNotifierProvider<ZFormController>`
/// + enveloppe `ZcrudScope`). Réutilise la réactivité du cœur sans la réimplémenter.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/presentation/z_provider_api.dart';
export 'src/presentation/z_provider_resolver.dart';
export 'src/presentation/zcrud_provider_scope.dart';
