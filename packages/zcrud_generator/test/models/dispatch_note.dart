/// Modèle de PREUVE de GEN-1 (test-only — PAS un package produit) : le codegen
/// émis en **membres d'instance**, pas seulement en membres d'extension.
///
/// La hiérarchie reproduit la forme qui rendait le codegen inadoptable : une
/// racine `DispatchModel` déclare `toMap()` et `copyWith()` **abstraits**. Un
/// membre d'extension ne satisfait jamais un membre abstrait hérité — la classe
/// ne compilerait donc pas sans une implémentation d'instance.
///
///   - [DispatchNote] **applique** le mixin `_$DispatchNoteZcrud` : elle
///     compile, et `toMap()` répond à travers le type de base ;
///   - [DispatchEcho] ne l'applique pas et implémente à la main : elle sert de
///     témoin d'identité — même schéma, la map de l'une doit être égale à la
///     map de l'autre.
///
/// Le `part 'dispatch_note.g.dart'` est produit par **build_runner réel**
/// (`melos run generate`) — gitignoré, jamais édité à la main.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

part 'dispatch_note.g.dart';

/// Statut d'acheminement.
enum DispatchStatus { queued, sent, failed }

/// Racine à membres ABSTRAITS — la forme que l'extension ne peut pas satisfaire.
abstract class DispatchModel {
  /// Construit la racine.
  const DispatchModel({this.id});

  /// Identité opaque, portée par la racine.
  @ZcrudId()
  final String? id;

  /// Sérialisation, déclarée ABSTRAITE : toute sous-classe doit en fournir une
  /// implémentation d'INSTANCE.
  Map<String, dynamic> toMap();

  /// Copie, déclarée ABSTRAITE.
  DispatchModel copyWith();
}

/// Bordereau d'acheminement — adopte le codegen **par le mixin**.
@ZcrudModel(kind: 'dispatchNote')
class DispatchNote extends DispatchModel with _$DispatchNoteZcrud {
  /// Construit un bordereau.
  const DispatchNote({
    super.id,
    required this.subject,
    this.status = DispatchStatus.queued,
    this.attempts = 0,
    this.sentAt,
    this.tags = const <String>[],
  });

  /// Décodeur de DOMAINE exigé par le générateur.
  factory DispatchNote.fromMap(Map<String, dynamic> map) =>
      _$DispatchNoteFromMap(map);

  /// Objet du bordereau.
  @ZcrudField(label: 'Objet')
  @override
  final String subject;

  /// Statut courant.
  @ZcrudField()
  @override
  final DispatchStatus status;

  /// Nombre de tentatives.
  @ZcrudField()
  @override
  final int attempts;

  /// Date d'envoi, nullable.
  @ZcrudField()
  @override
  final DateTime? sentAt;

  /// Étiquettes libres.
  @ZcrudField()
  @override
  final List<String> tags;
}

/// Témoin d'identité : MÊME schéma, sérialisation écrite à la main.
///
/// Sa map est la référence à l'octet contre laquelle celle de [DispatchNote]
/// est comparée — une divergence du codegen ne peut pas passer inaperçue.
class DispatchEcho {
  /// Construit le témoin.
  const DispatchEcho({
    this.id,
    required this.subject,
    this.status = DispatchStatus.queued,
    this.attempts = 0,
    this.sentAt,
    this.tags = const <String>[],
  });

  /// Identité opaque.
  final String? id;

  /// Objet du bordereau.
  final String subject;

  /// Statut courant.
  final DispatchStatus status;

  /// Nombre de tentatives.
  final int attempts;

  /// Date d'envoi, nullable.
  final DateTime? sentAt;

  /// Étiquettes libres.
  final List<String> tags;

  /// Map écrite à la main, dans l'ordre et le format attendus.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'subject': subject,
        'status': status.name,
        'attempts': attempts,
        'sent_at': sentAt?.toIso8601String(),
        'tags': tags,
      };
}
