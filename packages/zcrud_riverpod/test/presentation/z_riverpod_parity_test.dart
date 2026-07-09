// E2-9 AC6 : GATE DE PARITÉ — config `ZcrudRiverpodScope`. Même harnais, mêmes
// assertions que les autres configs ; seul `wrap` change (Riverpod confiné au wrap).
import 'package:binding_conformance/binding_conformance.dart';
import 'package:zcrud_riverpod/zcrud_riverpod.dart';

void main() {
  runZFormGranularRebuildParitySuite(
    label: 'ZcrudRiverpodScope',
    wrap: (child) => ZcrudRiverpodScope(child: child),
  );
}
