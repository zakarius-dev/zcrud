/// Barrel d'API publique de `zcrud_core`.
///
/// Cœur : domaine pur + moteur d'édition + ports + `ZFieldSpec` + `ZcrudScope`.
/// AD-1 : puits du graphe de dépendances (aucune arête `zcrud_*` sortante).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// Re-export CURATÉ de dartz (AD-11) — sous-ensemble minimal pour ne pas polluer
// l'API publique. Pas d'export global de `package:dartz/dartz.dart`.
export 'package:dartz/dartz.dart' show Either, Left, Right, Unit, unit;

// Couche DONNÉES — adaptateurs de schéma existant (E2-6, FR-11, AD-3/AD-4/AD-10) :
// contrat `ZModelAdapter<T>` (adapte un modèle HÉRITÉ vers `ZcrudRegistry` sans
// le repasser par le builder zcrud) + `JsonSerializableAdapter<T>` (cible
// lex_douane `@JsonSerializable`, mode défensif `fromMapSafe`). Pur-Dart. Le
// pendant DODLP `ReflectableCodec` (reflectable) vit dans `zcrud_get` (chemin
// allowlisté du gate AD-3), jamais dans le cœur.
export 'src/data/adapters/json_serializable_adapter.dart';
export 'src/data/adapters/z_model_adapter.dart';

// Contrats de domaine (E2-1) ; hiérarchie d'erreurs + `ZResult<T>` (AD-11) ;
// métadonnées de sync hors-entité (AD-16) ; marqueur d'API (placeholder E1-2,
// conservé pour les satellites). Ordre alphabétique (directives_ordering).
// Ports & value objects de la couche données (E2-2, AD-5/AD-11/AD-16) :
// `ZRepository<T>` (flux nus + CRUD `Either`), `ZDataRequest`/`ZFilter`/`ZSort`,
// curseur neutre `ZCursor`, états `ZDataState` (sealed), port `ZAcl`.
export 'src/domain/contracts/z_entity.dart';
export 'src/domain/contracts/z_node.dart';
export 'src/domain/contracts/z_syncable.dart';
export 'src/domain/data/z_cursor.dart';
export 'src/domain/data/z_data_request.dart';
export 'src/domain/data/z_data_state.dart';
// Surface d'autorité du moteur déclaratif (E2-4, AD-1/AD-3/AD-4) : catalogue de
// champs `EditionFieldType` (enum ouvert, `custom`) + types-valeur `const`
// partagés authoring (`@ZcrudField`) ↔ runtime (`ZFieldSpec`, émis en E2-5) :
// `ZValidatorSpec` (déclaratif, aucune closure), `ZFieldChoice`, `ZCondition`
// (displayCondition déclarative, AD-2), base d'extension `ZFieldConfig` (+
// configs triviales pur-cœur texte/nombre/date), stratégie `ZFieldRename`.
export 'src/domain/edition/edition_field_type.dart';
export 'src/domain/edition/z_condition.dart';
export 'src/domain/edition/z_field_choice.dart';
export 'src/domain/edition/z_field_config.dart';
export 'src/domain/edition/z_field_rename.dart';
export 'src/domain/edition/z_field_spec.dart';
export 'src/domain/edition/z_validator_spec.dart';
// Slots d'extensibilité (E2-3, AD-4/AD-10) : slot type additif VERSIONNÉ
// `ZExtension` (parsing défensif `guard`), mixin `ZExtensible` (`extension` +
// `extra`) porté par les entités E9/E10, helper `zExtraRead`.
export 'src/domain/extension/z_extensible.dart';
export 'src/domain/extension/z_extension.dart';
export 'src/domain/failures/z_failure.dart';
export 'src/domain/ports/z_acl.dart';
export 'src/domain/ports/z_repository.dart';
// Registres ouverts d'extensibilité (E2-3, AD-3/AD-4) : container générique
// `ZCodecRegistry<T>`, registre de modèles `ZcrudRegistry`/`ZModelCodec`
// (consommé par E2-5), registres ouverts `ZTypeRegistry` (E3-3b) /
// `ZSourceRegistry` (E9-1) sur base `ZOpenRegistry`/`ZValueCodec`, erreurs de
// config `ZUnregisteredTypeError`/`ZDuplicateRegistrationError` (Error, PAS
// `ZFailure`).
export 'src/domain/registry/z_codec_registry.dart';
export 'src/domain/registry/z_open_registry.dart';
export 'src/domain/registry/z_registry_error.dart';
export 'src/domain/registry/z_source_registry.dart';
export 'src/domain/registry/z_type_registry.dart';
export 'src/domain/registry/zcrud_registry.dart';
export 'src/domain/sync/z_sync_meta.dart';
export 'src/domain/z_core_api.dart';
// Couche présentation (E2-7/E2-8, AD-2/AD-6/AD-13/AD-14/AD-15) : réactivité
// Flutter-native (aucun gestionnaire d'état). `ZFormController` (tranches
// `ValueListenable`), seams d'injection (`ZDependencyResolver` défaut throw,
// `ZScopeError`), `ZcrudScope` (InheritedWidget, défaut zéro-config), helper de
// slice. Seams l10n/thème injectables (E2-8, FR-23/FR-26/AD-13) : delegate
// générique `ZcrudLocalizations`/`ZcrudLocalizationsDelegate` + registre
// `ZcrudLabels` + helper `label(context, key)` ; `ZcrudTheme` (ThemeExtension,
// repli `Theme.of`, aucun style codé en dur). Ordre alpha (directives_ordering).
export 'src/presentation/l10n/z_labels.dart';
export 'src/presentation/l10n/z_localizations.dart';
export 'src/presentation/theme/z_theme.dart';
export 'src/presentation/z_dependency_resolver.dart';
export 'src/presentation/z_field_listenable_builder.dart';
export 'src/presentation/z_form_controller.dart';
export 'src/presentation/z_scope_error.dart';
export 'src/presentation/zcrud_scope.dart';
