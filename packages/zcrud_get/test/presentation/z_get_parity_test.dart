// E2-9 AC6 : GATE DE PARITÉ — configs (a) bare `ZcrudScope` (référence) et
// (b) `ZcrudGetScope`. Même harnais, mêmes assertions ; seul `wrap` change. La
// config de référence bare est jouée ici (auto-test de l'oracle) en plus du
// binding get, prouvant que la granularité est identique avec/sans manager.
import 'package:binding_conformance/binding_conformance.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_get/zcrud_get.dart';

void main() {
  // (a) Référence : aucun manager, `ZcrudScope` seul (auto-test de l'oracle).
  runZFormGranularRebuildParitySuite(
    label: 'bare ZcrudScope',
    wrap: (child) => ZcrudScope(child: child),
  );

  // (b) Binding get : le manager (get_it/GetX) n'est présent que dans le wrap.
  runZFormGranularRebuildParitySuite(
    label: 'ZcrudGetScope',
    wrap: (child) => ZcrudGetScope(child: child),
  );
}
