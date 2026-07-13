/// Harnais du gate **AD-19.1** (volet A comportemental) — dev/test-only.
///
/// API publique : le câblage (registrars / sondes / allowlist) et les assertions
/// réutilisables. Exécuté par `scripts/ci/gate_reserved_keys.dart`
/// (`flutter test --tags reserved-keys`), **jamais** par `melos run test`
/// (le harnais est dans `melos.ignore` — cf. pubspec.yaml).
library;

export 'src/assertions.dart';
export 'src/manual_probes.dart';
export 'src/registrars.dart';
