/// Modèle de PREUVE (test-only — PAS un package produit) : le mixin émis à la
/// **signature de la base**.
///
/// [AuditEntry] étend une base ([AuditBase]) qui déclare déjà `toMap()` et
/// `copyWith()` avec des paramètres que le schéma ne connaît pas. Un mixin émis
/// à la seule vue du schéma serait refusé (`invalid_override`) : la présence de
/// ce fichier dans les imports du test est déjà une assertion de compilation.
///
/// Le `part 'audit_entry.g.dart'` est produit par **build_runner réel**
/// (`melos run generate`) — gitignoré, jamais édité à la main.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

import 'audit_base.dart';

part 'audit_entry.g.dart';

/// Entrée d'audit — adopte le codegen **par le mixin**, sur une base à canaux
/// hors schéma.
@ZcrudModel(kind: 'auditEntry')
class AuditEntry extends AuditBase with _$AuditEntryZcrud {
  /// Construit une entrée.
  const AuditEntry({
    super.label,
    super.extra,
    super.source,
    this.id,
    required this.action,
    this.count = 0,
  });

  /// Décodeur de DOMAINE exigé par le générateur.
  factory AuditEntry.fromMap(Map<String, dynamic> map) =>
      _$AuditEntryFromMap(map);

  /// Identité opaque.
  @ZcrudId()
  @override
  final String? id;

  /// Action journalisée.
  @ZcrudField(label: 'Action')
  @override
  final String action;

  /// Nombre d'occurrences.
  @ZcrudField()
  @override
  final int count;
}
