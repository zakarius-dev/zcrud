/// Marqueur d'API publique du cœur `zcrud_core` (placeholder E1-2).
///
/// Substance réelle (moteur d'édition, ports, `ZFieldSpec`, `ZcrudScope`)
/// posée en E2. Sert de point d'ancrage importable par les 13 satellites
/// pour rendre tangible l'arête AD-1 `satellite -> zcrud_core`.
abstract final class ZCoreApi {
  const ZCoreApi._();

  /// Version de l'API publique du cœur au stade squelette.
  static const String version = '0.0.1';
}
