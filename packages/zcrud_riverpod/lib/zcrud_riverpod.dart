/// Barrel d'API publique de `zcrud_riverpod`.
///
/// Binding état/injection <-> Riverpod (invariant AD-15) — cible les hôtes
/// Riverpod (lex_douane, IFFD). Fournit `ZRiverpodResolver` (seam de
/// résolution via `ProviderContainer`), `ZcrudRiverpodScope` (scope de
/// binding + `ProviderScope`) et `zFormControllerProvider` (provider
/// auto-dispose du `ZFormController`). Réutilise la réactivité du cœur sans
/// la réimplémenter.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// `zStudyRepositoryProvider<T>` lève un `ZScopeError` quand le seam n'est pas
// surchargé, mais le type vit dans `zcrud_core`. Sans ce ré-export, un hôte
// devait importer `zcrud_core` UNIQUEMENT pour attraper l'erreur de son
// propre binding. Ré-export CIBLÉ (`show`) : le binding n'ouvre pas la
// surface entière du cœur, il n'expose que le type qu'il lève lui-même.
export 'package:zcrud_core/zcrud_core.dart' show ZScopeError;

export 'src/presentation/z_riverpod_api.dart';
export 'src/presentation/z_riverpod_resolver.dart';
export 'src/presentation/zcrud_riverpod_scope.dart';
// Providers study génériques + clé de family à égalité profonde possédée par
// le binding (invariant AD-24 : le contrat de caching vit au binding, jamais
// au kernel).
export 'src/study/z_session_config_key.dart';
// Le binding reste GÉNÉRIQUE : les providers TYPÉS par entité
// (`zStudyWatchAllProvider<ZStudyDocument>(...)`) sont des one-liners côté
// application (instanciés par l'hôte), jamais exportés ici. Seul l'adapter
// Firestore folder-scopé (générique, dans `zcrud_firestore`) est livré côté
// zcrud.
export 'src/study/z_study_providers.dart';
