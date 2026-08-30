/// Modèles de PREUVE de l'atteignabilité du codegen face à un `toMap()`
/// d'INSTANCE hérité (test-only — PAS un package produit).
///
/// Deux formes, toutes deux reproduites du terrain :
///
///   - [ArchiveRecord] étend une base qui déclare un `toMap()` **CONCRET**
///     d'instance. Sans le mixin, l'extension générée serait syntaxiquement
///     présente et sémantiquement MORTE — c'est la base qui répondrait, et les
///     champs propres ne seraient jamais écrits. La classe applique donc
///     `_$ArchiveRecordZcrud`, et la garde vérifie que `toMap()` répond
///     À TRAVERS le type de base **avec** les champs propres ;
///   - [ArchiveDigest] déclare un **accesseur** qui rétrécit un champ hérité
///     annoté (`stamp`, jamais nul à la lecture). Un accesseur n'est pas un
///     champ : traité comme un masquage, il ferait disparaître la spec du champ
///     hérité en silence. La garde vérifie que la spec est **conservée** et que
///     la clé est bien écrite, avec la valeur de repli de l'accesseur.
///
/// Le `part 'archive_record.g.dart'` est produit par **build_runner réel**
/// (`melos run generate`) — gitignoré, jamais édité à la main.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

part 'archive_record.g.dart';

/// Base à `toMap()` **CONCRET** d'instance — la forme qui tue une extension.
abstract class ArchiveBase {
  /// Construit la base.
  const ArchiveBase({this.id, required this.label});

  /// Identité opaque, portée par la base.
  @ZcrudId()
  final String? id;

  /// Libellé, porté et annoté par la base.
  @ZcrudField()
  final String label;

  /// Sérialisation de la base, déclarée en membre d'INSTANCE **concret**.
  ///
  /// Elle ne connaît que les champs de la base : si une sous-classe adoptait le
  /// codegen sans le mixin, c'est CE corps-ci qui répondrait à `toMap()`.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'label': label,
      };
}

/// Fiche d'archive — adopte le codegen **par le mixin**, au-dessus d'un
/// `toMap()` concret hérité.
@ZcrudModel(kind: 'archiveRecord')
class ArchiveRecord extends ArchiveBase with _$ArchiveRecordZcrud {
  /// Construit une fiche.
  const ArchiveRecord({
    super.id,
    required super.label,
    required this.volume,
    this.sealedAt,
  });

  /// Décodeur de DOMAINE exigé par le générateur.
  factory ArchiveRecord.fromMap(Map<String, dynamic> map) =>
      _$ArchiveRecordFromMap(map);

  /// Volume d'archivage — champ PROPRE, absent du `toMap()` de la base.
  @ZcrudField()
  @override
  final int volume;

  /// Date de scellement — champ PROPRE nullable.
  @ZcrudField()
  @override
  final DateTime? sealedAt;
}

/// Base sans sérialisation — seul l'accesseur masquant est en jeu ici.
abstract class DigestBase {
  /// Construit la base.
  const DigestBase({this.id, this.stamp});

  /// Identité opaque.
  @ZcrudId()
  final String? id;

  /// Horodatage hérité, annoté et NULLABLE au stockage.
  @ZcrudField()
  final DateTime? stamp;
}

/// Condensé d'archive — **rétrécit** le champ hérité `stamp` par un accesseur.
@ZcrudModel(kind: 'archiveDigest')
class ArchiveDigest extends DigestBase {
  /// Construit un condensé.
  const ArchiveDigest({super.id, super.stamp, required this.title});

  /// Décodeur de DOMAINE exigé par le générateur.
  factory ArchiveDigest.fromMap(Map<String, dynamic> map) =>
      _$ArchiveDigestFromMap(map);

  /// Valeur de repli d'un horodatage absent, en un SEUL endroit.
  static final DateTime epoch = DateTime.utc(1970);

  /// Titre du condensé.
  @ZcrudField()
  final String title;

  /// Horodatage **jamais nul à la lecture** : l'accesseur rétrécit le champ
  /// hérité, sans rien retirer à sa persistance.
  @override
  DateTime get stamp => super.stamp ?? epoch;
}
