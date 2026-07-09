// E2-9 AC6 : GATE DE PARITÉ — config `ZcrudProviderScope`. Même harnais, mêmes
// assertions ; seul `wrap` change (provider confiné au wrap).
import 'package:binding_conformance/binding_conformance.dart';
import 'package:zcrud_provider/zcrud_provider.dart';

void main() {
  runZFormGranularRebuildParitySuite(
    label: 'ZcrudProviderScope',
    wrap: (child) => ZcrudProviderScope(child: child),
  );
}
