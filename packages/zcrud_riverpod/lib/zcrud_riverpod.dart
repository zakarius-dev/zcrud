/// Barrel d'API publique de `zcrud_riverpod`.
///
/// Binding état/injection <-> Riverpod (E2-9, AD-15) — cible lex_douane (E8).
/// Fournit `ZRiverpodResolver` (seam de résolution via `ProviderContainer`),
/// `ZcrudRiverpodScope` (scope de binding + `ProviderScope`) et
/// `zFormControllerProvider` (provider auto-dispose du `ZFormController`).
/// Réutilise la réactivité du cœur sans la réimplémenter.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/presentation/z_riverpod_api.dart';
export 'src/presentation/z_riverpod_resolver.dart';
export 'src/presentation/zcrud_riverpod_scope.dart';
