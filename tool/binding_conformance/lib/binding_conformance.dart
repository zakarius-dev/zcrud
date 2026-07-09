/// Barrel du harnais de parité dev/test-only (E2-9, AD-15).
///
/// Expose l'ORACLE COMMUN [runZFormGranularRebuildParitySuite] : une suite de
/// tests `flutter_test` paramétrée par un `wrap`, exécutée À L'IDENTIQUE sous
/// `ZcrudScope` seul et sous les 3 bindings — preuve exécutable que la
/// granularité de rebuild (SM-1) est indépendante du gestionnaire d'état.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/z_form_parity_suite.dart';
