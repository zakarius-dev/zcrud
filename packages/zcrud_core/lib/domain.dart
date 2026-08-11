/// Surface **domaine PUR-DART** de `zcrud_core` (Flutter-free).
///
/// Point d'entrée destiné aux **couches domaine des satellites** (`zcrud_flashcard`,
/// `zcrud_mindmap`, …) : il ré-exporte TOUTE la couche domaine/données du cœur
/// (contrats, extensibilité, registres, ports, sync, édition déclarative,
/// `ZResult`/`ZFailure`) **sans jamais tirer le SDK Flutter**. Ainsi un modèle de
/// satellite (`ZFlashcard`, `ZMindmapNode`, `ZRepetitionInfo`…) reste
/// **transitivement pur-Dart** (invariant AD-14) — testable sous `dart test`,
/// sans dépendance à `package:flutter/*`.
///
/// La couche PRÉSENTATION (widgets, `ZcrudScope`, `ZcrudTheme`, `DynamicEdition`,
/// liste…) — qui, elle, tire Flutter — n'est **PAS** ré-exportée ici : elle vit
/// sur le barrel principal `package:zcrud_core/zcrud_core.dart` (qui ré-exporte
/// cette surface + la présentation, API publique inchangée).
///
/// **INVARIANT** : aucun `export`/`import` de `package:flutter/*` ne doit apparaître
/// dans l'arbre transitif de ce fichier (gardé par un test `dart test`).
library;

// Re-export curaté de dartz (invariant AD-11) — sous-ensemble minimal.
export 'package:dartz/dartz.dart' show Either, Left, Right, Unit, unit;

// Couche DONNÉES — adaptateurs de schéma existant. Pur-Dart.
export 'src/data/adapters/json_serializable_adapter.dart';
export 'src/data/adapters/z_model_adapter.dart';

// Le modèle de conversation IA vit hors du cœur, dans
// `package:zcrud_chat_kernel/zcrud_chat_kernel.dart` : la quasi-totalité des
// consommateurs de `zcrud_core` n'a aucun usage du chat, et le patron du dépôt
// est sans exception — aucun domaine MÉTIER ne vit dans le cœur
// (`ZFlashcard`→`zcrud_flashcard`, `ZStudyFolder`→`zcrud_study_kernel`,
// `ZSmartNote`→`zcrud_note`, `ZExam`→`zcrud_exam`) ; `domain/` du cœur ne porte
// que des mécanismes TRANSVERSES (collection, contracts, data, edition,
// extension, failures, json, ports, registry, sync).
// Restent ici, car transverses et non spécifiques au chat : les primitives de
// lecture défensive `src/domain/json/z_json_read.dart` et la hiérarchie
// `ZFailure` (dont `ZQuotaExceededFailure`).
// Contrats de domaine + hiérarchie d'erreurs/`ZResult` (invariant AD-11) + méta
// de sync hors-entité (invariant AD-16) + marqueur d'API. Ports & value objects.
export 'src/domain/collection/z_immutable_view.dart';
export 'src/domain/contracts/z_entity.dart';
export 'src/domain/contracts/z_node.dart';
export 'src/domain/contracts/z_syncable.dart';
export 'src/domain/data/z_cursor.dart';
export 'src/domain/data/z_data_request.dart';
export 'src/domain/data/z_data_state.dart';
export 'src/domain/data/z_search_text.dart';
// Surface d'autorité du moteur déclaratif — types-valeur `const` partagés.
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
// Slots d'extensibilité (invariants AD-4/AD-10) : `ZExtension`/`ZExtensible`,
// la garde partagée `zSanitizeExtra` et l'égalité/hash PROFONDS `zJsonEquals`/
// `zJsonHash` — implémentation UNIQUE du dépôt ; les recopier dans un
// satellite, ou les importer depuis un autre paquet zcrud, violerait
// l'invariant AD-1 (cf. `z_json_equality.dart`).
// Préservation de l'ABSENCE sur le chemin ENTITÉ (le chemin des hôtes qui
// consomment les entités directement, sans passer par un codec de migration).
// Même clé de survie que le codec, pour que les deux chemins s'accordent sur
// un corpus déjà migré.
export 'src/domain/extension/z_absence.dart';
export 'src/domain/extension/z_extensible.dart';
export 'src/domain/extension/z_extension.dart';
export 'src/domain/extension/z_json_equality.dart';
// `extension` est une clé CONNUE (donc exclue d'`extra`) dont le décodage
// dépend d'un paramètre optionnel — un hôte sans parser détruirait le slot
// d'un autre, au décodage. `zDecodeExtension` préserve verbatim ce que
// personne n'a su typer.
export 'src/domain/extension/z_opaque_extension.dart';
export 'src/domain/failures/z_failure.dart';
// Lecture JSON défensive partagée (invariant AD-10) — pendant, pour la
// LECTURE, de ce que `zJsonEquals`/`zJsonHash` sont pour l'ÉGALITÉ : une
// implémentation UNIQUE des primitives qu'une entité écrite à la main
// reconstruirait sinon en privé (coercition de map, de chaîne, garde de
// décodage…). Destinée à tous les modules.
export 'src/domain/json/z_json_read.dart';
export 'src/domain/ports/cloud_storage_repository.dart';
export 'src/domain/ports/z_acl.dart';
// Port neutre de résolution des RÉFÉRENCES opaques de fichiers (`String`) vers
// `AppFile` (invariants AD-1/AD-10). Impl hors cœur (`zcrud_firestore`/app),
// injecté via `ZcrudScope`.
export 'src/domain/ports/z_app_file_resolver.dart';
// Port neutre + registre de source d'options CALCULÉES du champ `select`
// (invariants AD-1/AD-4/AD-5) : `ZChoicesSource` (liste `List<ZFieldChoice>`
// SYNCHRONE, impl hors cœur) + `ZChoicesSourceRegistry` (instanciable, injecté
// via `ZcrudScope`).
export 'src/domain/ports/z_choices_source.dart';
// Port neutre de FORMATAGE D'AFFICHAGE des dates (invariants AD-1/AD-10) :
// `ZDateDisplayFormatter` (impl `intl` hors cœur, injectée via `ZcrudScope`) +
// `zDateModeOf`. Sans port injecté, toute voie de lecture rend la chaîne
// brute — l'affichage par défaut, en l'absence d'hôte actif.
export 'src/domain/ports/z_date_display_formatter.dart';
// Ports bas-niveau offline-first : `ZLocalStore`/`ZRemoteStore` neutres.
export 'src/domain/ports/z_local_store.dart';
// Port neutre + registre du CRUD inline du champ `relation` (invariants
// AD-1/AD-4/AD-5) : `ZRelationCrudHandler` (create/edit/copy →
// `Future<ZFieldChoice?>`, impl hors cœur) + `ZRelationCrudRegistry`
// (instanciable, injecté via `ZcrudScope`).
export 'src/domain/ports/z_relation_crud.dart';
// Port neutre + registre de source dynamique du champ `relation` (invariants
// AD-1/AD-4/AD-5) : `ZRelationSource` (flux `List<ZFieldChoice>` nu, impl hors
// cœur) + `ZRelationSourceRegistry` (instanciable, injecté via `ZcrudScope`).
export 'src/domain/ports/z_relation_source.dart';
export 'src/domain/ports/z_remote_store.dart';
export 'src/domain/ports/z_repository.dart';
// Sur-port synchronisable : `ZSyncableRepository<T>`.
export 'src/domain/ports/z_syncable_repository.dart';
// Registres ouverts d'extensibilité : `ZTypeRegistry`, `ZSourceRegistry`,
// `ZcrudRegistry`, `ZCodecRegistry`, erreurs de configuration.
export 'src/domain/registry/z_codec_registry.dart';
export 'src/domain/registry/z_decode_context.dart';
export 'src/domain/registry/z_open_registry.dart';
export 'src/domain/registry/z_registry_error.dart';
export 'src/domain/registry/z_source_registry.dart';
export 'src/domain/registry/z_type_registry.dart';
export 'src/domain/registry/zcrud_registry.dart';
// Contrats de synchronisation offline-first : `ZLwwResolver`, `ZSyncEntry`,
// `ZSyncMeta`.
// Source de temps injectable pour la clé LWW `updated_at` — le levier
// côté application qui permet d'atténuer le décalage d'horloge entre
// appareils.
export 'src/domain/sync/z_clock.dart';
export 'src/domain/sync/z_lww_resolver.dart';
export 'src/domain/sync/z_sync_entry.dart';
export 'src/domain/sync/z_sync_meta.dart';
// Orchestrateur de synchronisation : `ZSyncOrchestrator` (Dart pur).
export 'src/domain/sync/z_sync_orchestrator.dart';
export 'src/domain/sync/z_sync_run_report.dart';
export 'src/domain/z_core_api.dart';
