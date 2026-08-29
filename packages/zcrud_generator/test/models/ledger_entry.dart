/// Modèle de PREUVE des deux capacités N0+N1 (test-only — PAS un package
/// produit) : **champs annotés HÉRITÉS** collectés, et champs **`Map<K, V>`**
/// (dé)sérialisés.
///
/// Couvre, en une seule fixture :
///   - une hiérarchie à **trois niveaux** (`LedgerRoot` → `LedgerBase` →
///     `LedgerEntry`), dont seule la feuille est annotée `@ZcrudModel` — les
///     champs annotés des deux bases doivent entrer dans `toMap()`, dans le
///     décodeur émis et dans `$LedgerEntryFieldSpecs`, **avant** les champs
///     locaux et dans l'ordre de linéarisation ;
///   - cinq formes de `Map` : valeurs scalaires, `dynamic`, `DateTime`, valeurs
///     nullables, et **clés enum** (encodées par `.name`).
///
/// Le `part 'ledger_entry.g.dart'` est produit par **build_runner réel**
/// (`melos run generate`) — gitignoré, jamais édité à la main.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

part 'ledger_entry.g.dart';

/// Zone d'imputation — sert de **clé** de map (encodée par `.name`).
enum LedgerZone { alpha, beta, gamma }

/// Racine de la hiérarchie : porte l'identité.
abstract class LedgerRoot {
  /// Construit la racine.
  const LedgerRoot({this.id});

  /// Identité opaque, annotée sur la RACINE (deux niveaux au-dessus du modèle).
  @ZcrudId()
  final String? id;
}

/// Niveau intermédiaire : porte deux champs métier annotés.
abstract class LedgerBase extends LedgerRoot {
  /// Construit le niveau intermédiaire.
  const LedgerBase({super.id, required this.label, this.archived = false});

  /// Libellé, annoté sur la base.
  @ZcrudField(label: 'Libellé')
  final String label;

  /// Drapeau d'archivage, annoté sur la base.
  @ZcrudField(label: 'Archivé')
  final bool archived;
}

/// Écriture de registre — le seul modèle annoté de la hiérarchie.
@ZcrudModel(kind: 'ledgerEntry')
class LedgerEntry extends LedgerBase {
  /// Construit une écriture. Les champs hérités transitent par `super.` : c'est
  /// ce que le décodeur et le `copyWith` émis exigent.
  const LedgerEntry({
    super.id,
    required super.label,
    super.archived,
    required this.amount,
    this.tally = const <String, int>{},
    this.meta = const <String, dynamic>{},
    this.zones = const <LedgerZone, String>{},
    this.stamps = const <String, DateTime>{},
    this.notes = const <String, String?>{},
  });

  /// Décodeur de DOMAINE exigé par le générateur. `LedgerEntry` n'est pas
  /// `ZExtensible` : la délégation nue est légitime.
  factory LedgerEntry.fromMap(Map<String, dynamic> map) =>
      _$LedgerEntryFromMap(map);

  /// Montant local.
  @ZcrudField()
  final double amount;

  /// Map à valeurs scalaires.
  @ZcrudField()
  final Map<String, int> tally;

  /// Map à valeurs `dynamic` — la forme la plus répandue, recopiée telle quelle.
  @ZcrudField()
  final Map<String, dynamic> meta;

  /// Map à **clés enum** : la map persistée reste à clés `String` (`.name`).
  @ZcrudField()
  final Map<LedgerZone, String> zones;

  /// Map à valeurs `DateTime` — ISO-8601 dans le document persisté.
  @ZcrudField()
  final Map<String, DateTime> stamps;

  /// Map à valeurs NULLABLES : un `null` déclaré est préservé au round-trip.
  @ZcrudField()
  final Map<String, String?> notes;
}
