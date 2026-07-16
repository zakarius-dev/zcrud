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
// ES-10.1 (AD-24) — providers study génériques + clé de family à égalité
// profonde possédée par le binding.
export 'src/study/z_session_config_key.dart';
// ES-10.2 — le binding reste GÉNÉRIQUE : les providers TYPÉS par entité
// (`zStudyWatchAllProvider<ZStudyDocument>(...)`) sont des one-liners CÔTÉ APP
// (instanciés par lex/IFFD), jamais exportés ici (DW-ES102-1). Seul l'adapter
// firestore folder-scopé (générique, dans `zcrud_firestore`) est livré côté zcrud.
export 'src/study/z_study_providers.dart';
