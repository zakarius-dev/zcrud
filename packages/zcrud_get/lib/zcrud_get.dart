/// Barrel d'API publique de `zcrud_get`.
///
/// Binding état/injection <-> GetX + get_it (E2-9, AD-15) — cible DODLP (E7).
/// Fournit `ZGetResolver` (seam de résolution via `get_it`/GetX) et
/// `ZcrudGetScope` (scope de binding : création/scoping/dispose du
/// `ZFormController` + enveloppe `ZcrudScope`). Réutilise la réactivité du cœur
/// (`ZFormController`/`ZFieldListenableBuilder`) sans la réimplémenter.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// Adaptateur de schéma existant DODLP (E2-6, FR-11, AD-3/AD-6) : `ReflectableCodec`
// (SEULE exception `reflectable` autorisée — chemin allowlisté du gate) + le port
// de réflexion injecté `ZReflectionCapability` / helper `ReflectableMirrorCapability`.
export 'src/data/codecs/reflectable_codec.dart';
export 'src/presentation/z_get_api.dart';
export 'src/presentation/z_get_resolver.dart';
export 'src/presentation/zcrud_get_scope.dart';
