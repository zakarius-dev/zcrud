import 'package:zcrud_core/edition.dart';

/// Annotation de **classe** déclarant un modèle `zcrud` sérialisable et
/// enregistrable (source unique de vérité — AD-3).
///
/// Le générateur E2-5 (`build_runner`) lit cette annotation **statiquement**
/// (`TypeChecker`/`ConstantReader`, jamais d'exécution ni de réflexion — AD-3,
/// `reflectable` banni) pour émettre `toMap`/`fromMap`/`copyWith`, le
/// `ZFieldSpec[]` et l'enregistrement au `ZcrudRegistry`.
///
/// Classe `const` **pur-données** (tous champs `final`, zéro comportement — AC1).
///
/// ```dart
/// @ZcrudModel(kind: 'article')
/// class Article { ... }
/// ```
class ZcrudModel {
  /// Construit l'annotation `const` avec des défauts sûrs.
  const ZcrudModel({this.kind, this.fieldRename = ZFieldRename.snake});

  /// Discriminant du `ZcrudRegistry`. `null` ⇒ le générateur E2-5 le **dérive**
  /// du nom de la classe.
  final String? kind;

  /// Stratégie de renommage des clés persistées (défaut [ZFieldRename.snake] —
  /// AD-3, persistance snake_case). Un `@ZcrudField.name` explicite prime.
  final ZFieldRename fieldRename;
}
