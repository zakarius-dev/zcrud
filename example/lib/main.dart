import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';

/// Point d'entrée de l'application exemple zcrud (EX-1 → EX-3).
///
/// `Hive.initFlutter()` est appelé AVANT `runApp` (EX-3, AC7) : la démo OFFLINE
/// (`HiveZLocalStore.openBox`) exige une init Hive préalable. C'est la SEULE
/// arête `hive_flutter` directe de l'app (le port `ZLocalStore` reste neutre) —
/// aucun secret, aucune config Firebase (le distant Firestore est documenté mais
/// NON initialisé, cf. `offline_demo_screen.dart`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ExampleApp());
}
