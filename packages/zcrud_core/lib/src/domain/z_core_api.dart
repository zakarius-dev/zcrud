/// Marqueur d'API publique du cœur `zcrud_core`.
///
/// Point d'ancrage importable par les paquets satellites, qui rend
/// tangible l'invariant AD-1 (`satellite -> zcrud_core`, jamais l'inverse).
abstract final class ZCoreApi {
  const ZCoreApi._();

  /// Version de l'API publique du cœur au stade squelette.
  static const String version = '0.0.1';
}
