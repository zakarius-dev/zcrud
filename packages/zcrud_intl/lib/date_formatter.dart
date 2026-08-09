/// Point d'entrée **séparé** : implémentation `intl` du port
/// [ZDateDisplayFormatter] de `zcrud_core` (CR-DODLP-GAP3BIS).
///
/// ## Pourquoi il n'est pas dans `package:zcrud_intl/zcrud_intl.dart`
///
/// Rendre une date localisée exige les **données de locale CLDR** d'`intl`
/// (`date_symbol_data_local` : ~700 locales, plusieurs centaines de Ko de
/// données Dart). Une fois la table atteignable, aucun tree-shaking ne la
/// retire. Un hôte qui ne veut que les champs **téléphone / pays / adresse** de
/// `zcrud_intl` n'a donc pas à payer ce poids : il n'importe pas ce fichier.
///
/// L'API publique historique (`zcrud_intl.dart`) est **inchangée** — l'hôte
/// passif ne bouge pas.
///
/// ```dart
/// import 'package:zcrud_intl/date_formatter.dart';
///
/// ZcrudScope(
///   dateDisplayFormatter: const ZIntlDateDisplayFormatter(),
///   child: …,
/// );
/// ```
library;

export 'src/presentation/z_intl_date_formatter.dart';
