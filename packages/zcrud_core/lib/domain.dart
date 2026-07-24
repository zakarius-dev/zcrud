/// Surface **domaine PUR-DART** de `zcrud_core` (Flutter-free).
///
/// Point d'entrée destiné aux **couches domaine des satellites** (`zcrud_flashcard`,
/// `zcrud_mindmap`, …) : il ré-exporte TOUTE la couche domaine/données du cœur
/// (contrats, extensibilité, registres, ports, sync, édition déclarative,
/// `ZResult`/`ZFailure`) **sans jamais tirer le SDK Flutter**. Ainsi un modèle de
/// satellite (`ZFlashcard`, `ZMindmapNode`, `ZRepetitionInfo`…) reste
/// **transitivement pur-Dart** (AD-14) — testable sous `dart test`, sans
/// dépendance à `package:flutter/*`.
///
/// La couche PRÉSENTATION (widgets, `ZcrudScope`, `ZcrudTheme`, `DynamicEdition`,
/// liste…) — qui, elle, tire Flutter — n'est **PAS** ré-exportée ici : elle vit
/// sur le barrel principal `package:zcrud_core/zcrud_core.dart` (qui ré-exporte
/// cette surface + la présentation, API publique inchangée).
///
/// **INVARIANT** : aucun `export`/`import` de `package:flutter/*` ne doit apparaître
/// dans l'arbre transitif de ce fichier (gardé par un test `dart test`).
library;

// Re-export CURATÉ de dartz (AD-11) — sous-ensemble minimal.
export 'package:dartz/dartz.dart' show Either, Left, Right, Unit, unit;

// Couche DONNÉES — adaptateurs de schéma existant (E2-6). Pur-Dart.
export 'src/data/adapters/json_serializable_adapter.dart';
export 'src/data/adapters/z_model_adapter.dart';

// Contrats de domaine (E2-1) + hiérarchie d'erreurs/`ZResult` (AD-11) + méta de
// sync hors-entité (AD-16) + marqueur d'API. Ports & value objects (E2-2).
export 'src/domain/collection/z_immutable_view.dart';
export 'src/domain/contracts/z_entity.dart';
export 'src/domain/contracts/z_node.dart';
export 'src/domain/contracts/z_syncable.dart';
export 'src/domain/data/z_cursor.dart';
export 'src/domain/data/z_data_request.dart';
export 'src/domain/data/z_data_state.dart';
export 'src/domain/data/z_search_text.dart';
// Surface d'autorité du moteur déclaratif (E2-4) — types-valeur `const` partagés.
export 'src/domain/edition/app_file.dart';
export 'src/domain/edition/edition_field_type.dart';
export 'src/domain/edition/z_condition.dart';
export 'src/domain/edition/z_condition_evaluator.dart';
export 'src/domain/edition/z_date_range.dart';
export 'src/domain/edition/z_derivation.dart';
export 'src/domain/edition/z_field_adornment.dart';
export 'src/domain/edition/z_field_choice.dart';
export 'src/domain/edition/z_field_config.dart';
export 'src/domain/edition/z_field_rename.dart';
export 'src/domain/edition/z_field_size.dart';
export 'src/domain/edition/z_field_spec.dart';
export 'src/domain/edition/z_sub_list_config.dart';
export 'src/domain/edition/z_time_codec.dart';
export 'src/domain/edition/z_validator_spec.dart';
// Slots d'extensibilité (E2-3, AD-4/AD-10) : `ZExtension`/`ZExtensible`, la
// garde partagée `zSanitizeExtra` et l'égalité/hash PROFONDS `zJsonEquals`/
// `zJsonHash` (ES-2.2b — DW-ES22-3/DW-ES22-4 : implémentation UNIQUE du repo ;
// les recopier dans un satellite, ou les importer depuis `zcrud_note`, VIOLERAIT
// AD-1 — cf. `z_json_equality.dart`).
// CR-IFFD-18 — preservation de l'ABSENCE sur le chemin ENTITE (le chemin des
// hotes qui consomment les entites directement, sans passer par un codec de
// migration). Meme cle de survie que le codec, pour que les deux chemins
// s'accordent sur un corpus deja migre.
export 'src/domain/extension/z_absence.dart';
export 'src/domain/extension/z_extensible.dart';
export 'src/domain/extension/z_extension.dart';
export 'src/domain/extension/z_json_equality.dart';
// CR-LEX-33 : `extension` était une clé CONNUE (donc exclue d'`extra`) dont le
// décodage dépendait d'un paramètre OPTIONNEL — un hôte sans parser DÉTRUISAIT
// le slot d'un autre, au décodage. `zDecodeExtension` préserve verbatim ce que
// personne n'a su typer.
export 'src/domain/extension/z_opaque_extension.dart';
export 'src/domain/failures/z_failure.dart';
export 'src/domain/ports/cloud_storage_repository.dart';
export 'src/domain/ports/z_acl.dart';
// Port neutre + registre de source d'options CALCULÉES du champ `select` (DP-15,
// M22, AD-1/AD-4/AD-5) : `ZChoicesSource` (liste `List<ZFieldChoice>` SYNCHRONE,
// impl hors cœur) + `ZChoicesSourceRegistry` (instanciable, injecté via `ZcrudScope`).
export 'src/domain/ports/z_choices_source.dart';
// Ports bas-niveau offline-first (E5-2) : `ZLocalStore`/`ZRemoteStore` neutres.
export 'src/domain/ports/z_local_store.dart';
// Port neutre + registre du CRUD inline du champ `relation` (DP-15, M8,
// AD-1/AD-4/AD-5) : `ZRelationCrudHandler` (create/edit/copy → `Future<ZFieldChoice?>`,
// impl hors cœur) + `ZRelationCrudRegistry` (instanciable, injecté via `ZcrudScope`).
export 'src/domain/ports/z_relation_crud.dart';
// Port neutre + registre de source dynamique du champ `relation` (DP-5, gap B7,
// AD-1/AD-4/AD-5) : `ZRelationSource` (flux `List<ZFieldChoice>` nu, impl hors
// cœur) + `ZRelationSourceRegistry` (instanciable, injecté via `ZcrudScope`).
export 'src/domain/ports/z_relation_source.dart';
export 'src/domain/ports/z_remote_store.dart';
export 'src/domain/ports/z_repository.dart';
// Sur-port synchronisable (E5-3) : `ZSyncableRepository<T>`.
export 'src/domain/ports/z_syncable_repository.dart';
// Registres ouverts d'extensibilité (E2-3, E3-3b, E9-1) : `ZTypeRegistry`,
// `ZSourceRegistry`, `ZcrudRegistry`, `ZCodecRegistry`, erreurs de config.
export 'src/domain/registry/z_codec_registry.dart';
export 'src/domain/registry/z_decode_context.dart';
export 'src/domain/registry/z_open_registry.dart';
export 'src/domain/registry/z_registry_error.dart';
export 'src/domain/registry/z_source_registry.dart';
export 'src/domain/registry/z_type_registry.dart';
export 'src/domain/registry/zcrud_registry.dart';
// Contrats de synchronisation offline-first (E5-3) : `ZLwwResolver`, `ZSyncEntry`,
// `ZSyncMeta`.
// CR-LEX-36 : source de temps injectable pour la clé LWW `updated_at` — le
// levier app-side qui manquait pour atténuer le skew d'horloge multi-appareils.
export 'src/domain/sync/z_clock.dart';
export 'src/domain/sync/z_lww_resolver.dart';
export 'src/domain/sync/z_sync_entry.dart';
export 'src/domain/sync/z_sync_meta.dart';
// Orchestrateur de synchronisation (E5-4) : `ZSyncOrchestrator` (Dart PUR).
export 'src/domain/sync/z_sync_orchestrator.dart';
export 'src/domain/sync/z_sync_run_report.dart';
export 'src/domain/z_core_api.dart';
