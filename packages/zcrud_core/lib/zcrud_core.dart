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
// Normalisation de texte NEUTRE pour la recherche SANS ACCENTS (E4-3, AD-10) :
// helper pur-Dart `zFoldDiacritics` (table Latin documentée), réutilisable par
// l'adaptateur Firestore (E5) et le moteur in-memory `zApplyListRequest`.
export 'src/domain/data/z_search_text.dart';
// Surface d'autorité du moteur déclaratif (E2-4, AD-1/AD-3/AD-4) : catalogue de
// champs `EditionFieldType` (enum ouvert, `custom`) + types-valeur `const`
// partagés authoring (`@ZcrudField`) ↔ runtime (`ZFieldSpec`, émis en E2-5) :
// `ZValidatorSpec` (déclaratif, aucune closure), `ZFieldChoice`, `ZCondition`
// (displayCondition déclarative, AD-2), base d'extension `ZFieldConfig` (+
// configs triviales pur-cœur texte/nombre/date), stratégie `ZFieldRename`.
export 'src/domain/edition/app_file.dart';
export 'src/domain/edition/edition_field_type.dart';
export 'src/domain/edition/z_condition.dart';
// Évaluateur PUR de `ZCondition` contre l'état de formulaire (E3-4, AD-2) :
// `evaluateZCondition` + helper `zIsTruthy` + extraction des champs de garde
// `zGuardFieldsOf` (souscription CIBLÉE du sélecteur de visibilité — SM-1).
export 'src/domain/edition/z_condition_evaluator.dart';
export 'src/domain/edition/z_field_choice.dart';
export 'src/domain/edition/z_field_config.dart';
export 'src/domain/edition/z_field_rename.dart';
export 'src/domain/edition/z_field_spec.dart';
export 'src/domain/edition/z_sub_list_config.dart';
export 'src/domain/edition/z_validator_spec.dart';
// Slots d'extensibilité (E2-3, AD-4/AD-10) : slot type additif VERSIONNÉ
// `ZExtension` (parsing défensif `guard`), mixin `ZExtensible` (`extension` +
// `extra`) porté par les entités E9/E10, helper `zExtraRead`.
export 'src/domain/extension/z_extensible.dart';
export 'src/domain/extension/z_extension.dart';
export 'src/domain/failures/z_failure.dart';
export 'src/domain/ports/cloud_storage_repository.dart';
export 'src/domain/ports/z_acl.dart';
// Ports bas-niveau offline-first (E5-2, AD-5/AD-9/AD-11) : store LOCAL source de
// vérité `ZLocalStore<T>` + store DISTANT fire-and-forget `ZRemoteStore<T>`,
// neutres (aucun type hive/cloud_firestore). Adaptateurs (Hive/Firestore) en
// `zcrud_firestore`. Le merge LWW/orchestrateur (E5-3/E5-4) n'est PAS ici.
export 'src/domain/ports/z_local_store.dart';
export 'src/domain/ports/z_remote_store.dart';
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
// Moteur d'édition granulaire (E3-1, AD-2/SM-1) : `DynamicEdition` (formulaire
// de référence, `ListView.builder` + sections visuelles, écoute STRUCTURELLE
// only) + `ZEditionField` (champ hôte scellé sur sa tranche via
// `ZFieldListenableBuilder`, `TextEditingController` stable, saisie sens unique).
// Dispatcher de champ par type + familles de base (E3-3a, AD-2/AD-13/FR-23) :
// classification exhaustive `EditionFieldType → EditionFamily` (`familyOf`, 0
// default), hôte-dispatcher `ZFieldWidget` (réutilise slice + stabilité E3-2),
// widgets par famille (texte/nombre/date/booléen/select/relation) + repli
// contrôlé `ZUnsupportedFieldWidget` (types servis ailleurs — E3-3b/E3-3c/
// registre). Place stable garantie par `DynamicEdition` (KeyedSubtree, L3/AC7).
export 'src/presentation/edition/dynamic_edition.dart';
export 'src/presentation/edition/edition_field_family.dart';
export 'src/presentation/edition/families/z_app_file_field_widget.dart';
export 'src/presentation/edition/families/z_boolean_field_widget.dart';
export 'src/presentation/edition/families/z_color_field_widget.dart';
export 'src/presentation/edition/families/z_date_field_widget.dart';
export 'src/presentation/edition/families/z_dynamic_item_field_widget.dart';
export 'src/presentation/edition/families/z_free_widget_field_widget.dart';
export 'src/presentation/edition/families/z_number_field_widget.dart';
export 'src/presentation/edition/families/z_rating_field_widget.dart';
export 'src/presentation/edition/families/z_relation_field_widget.dart';
export 'src/presentation/edition/families/z_row_chips_field_widget.dart';
export 'src/presentation/edition/families/z_select_field_widget.dart';
export 'src/presentation/edition/families/z_signature_field_widget.dart';
export 'src/presentation/edition/families/z_slider_field_widget.dart';
export 'src/presentation/edition/families/z_sub_list_field_widget.dart';
export 'src/presentation/edition/families/z_tags_field_widget.dart';
export 'src/presentation/edition/families/z_text_field_widget.dart';
export 'src/presentation/edition/families/z_unsupported_field_widget.dart';
// Soumission agrégée + états UI + confirmation d'abandon (E3-6, AD-11/AD-2/AD-15) :
// `ZEditionSubmitController` (validation agrégée toutes-étapes + seam `onSubmit`
// `Either<ZFailure,T>`, états `ZSubmissionState` idle/inProgress/success/failure —
// pont `AsyncValue.error` au binding, jamais dans le cœur), `ZSubmitButton`
// (chrome accessible scellé sur l'état), `ZDiscardGuard` (PopScope-like, seam
// `onConfirmDiscard`, aucune dép routing), `ZCrossFieldValidator` (inter-champs
// `match`/`minKey`/`maxKey` en closures capturant le controller — report b).
export 'src/presentation/edition/z_cross_field_validator.dart';
export 'src/presentation/edition/z_discard_guard.dart';
export 'src/presentation/edition/z_edition_field.dart';
export 'src/presentation/edition/z_field_widget.dart';
// Seam d'acquisition de fichier injecté (E3-3c, AD-1/AD-6) : interface `ZFilePicker`
// (impl concrète image_picker/file_picker = app/binding E7, jamais le cœur).
export 'src/presentation/edition/z_file_picker.dart';
// Grille responsive 12 colonnes du moteur d'édition (E3-4, FR-3/AD-13) :
// descripteur de span par breakpoint `ZResponsiveSpan`, seuils `ZBreakpoint`/
// `ZResponsiveBreakpoints`, widget de disposition directionnel `ZResponsiveGrid`.
export 'src/presentation/edition/z_responsive_grid.dart';
// Assistant multi-étapes (E3-5, AD-2/AD-13/SM-1) : `ZStepperEdition` partitionne
// le MÊME `ZFormController` en étapes séquencées (réutilise `DynamicEdition` par
// étape) ; validation PAR ÉTAPE (gate « suivant » sur validateurs E3-2), état
// préservé en va-et-vient (controller unique), chrome scellé sur des canaux
// STRUCTURELS (SM-1). `ZEditionStep` = descripteur présentation (titre + noms).
export 'src/presentation/edition/z_stepper_edition.dart';
export 'src/presentation/edition/z_submission.dart';
export 'src/presentation/edition/z_submit_button.dart';
// Compilateur mémoïsable `ZValidatorSpec[] → FormFieldValidator` (E3-2, AD-2) :
// projette la donnée déclarative en validateur EXÉCUTABLE champ-local via
// `form_builder_validators` (jamais `flutter_form_builder`). Réutilisé par E3-5.
export 'src/presentation/edition/z_validator_compiler.dart';
// Registre de widgets d'édition injecté (E3-3b-1, AD-4) : `ZWidgetRegistry`
// (instanciable, jamais un singleton statique) + `ZFieldWidgetContext`/
// `ZFieldWidgetBuilder`. Sert les types dont le widget vit AILLEURS (markdown→E6,
// géo/tél→E11a, `custom`→app) sans que le cœur importe ces packages (OUT=0).
export 'src/presentation/edition/z_widget_registry.dart';
export 'src/presentation/l10n/z_labels.dart';
export 'src/presentation/l10n/z_localizations.dart';
// Moteur de liste — hôte + port neutre + dérivation/vues/états (E4-1→E4-2,
// AD-8/AD-11/AD-13/SM-5) : `DynamicList` (piloté par `ZListViewState`, dispatch
// sur `ZListLayout` ; délègue au `ZListRenderer` injecté sur le chemin dataGrid,
// `ZScopeError` actionnable si absent), port abstrait `ZListRenderer` (rendu
// concret `SfDataGrid` dans `zcrud_list`, jamais dans le cœur), colonnes
// **dérivées** `ZListColumn` + helper PUR `deriveColumns`/`ZColumnPolicy` (AC1),
// variantes `ZListLayout` (dataGrid/builder/custom — builder/custom rendus dans
// le cœur SANS Syncfusion), états `ZListViewState` (loading/empty/noResults/
// error/ready, accessibles), modèles neutres `ZListRenderRequest`/`ZListRow`.
export 'src/presentation/list/dynamic_list.dart';
export 'src/presentation/list/z_list_column.dart';
// Interrogation de liste (E4-3, AD-8/AD-10/AD-16/AD-2/AD-15) : contrôleur
// réactif Flutter-native `ZListController` (tranche `ValueListenable<
// ZListViewState>`, pagination curseur + repli in-memory, mapping empty/
// noResults) + `ZListPaginationMode` ; moteur in-memory NEUTRE `zApplyListRequest`
// (+ `ZListPage`, `zMatchesSearch`, `zDeriveCursor`) productionisant le repli
// prouvé E2-2. Aucun Syncfusion/backend/gestionnaire d'état (SM-5).
export 'src/presentation/list/z_list_controller.dart';
// Liste ACTIONNABLE (E4-4, AD-16/AD-9/AD-11/AD-2/AD-13/SM-5) : actions de ligne
// NEUTRES `ZRowAction<T>` (+ fabriques corbeille softDelete/restore/edit) filtrées
// par `ZAcl`, résolues par ligne en `ZResolvedRowAction` (sans `T`) ; mode de
// filtrage `ZActionAclMode` ; sélection multiple neutre `ZListSelectionController`
// (+ `ZListSelectionMode`) keyée par `id` STABLE (bug historique corrigé) ; pont
// neutre `ZListInteraction` (hors `ZListRenderRequest` pour préserver l'égalité de
// valeur). Aucun Syncfusion/backend/gestionnaire d'état (SM-5).
export 'src/presentation/list/z_list_interaction.dart';
export 'src/presentation/list/z_list_layout.dart';
export 'src/presentation/list/z_list_query.dart';
export 'src/presentation/list/z_list_render_request.dart';
export 'src/presentation/list/z_list_renderer.dart';
export 'src/presentation/list/z_list_selection.dart';
export 'src/presentation/list/z_list_tab.dart';
export 'src/presentation/list/z_list_view_state.dart';
export 'src/presentation/list/z_row_action.dart';
// Composition de listes (E4-5, étend FR-6 · AD-8/AD-16/AD-2/AD-15/SM-5) :
// `ZSubListScreen<T>` (sous-liste d'entités RELIÉES filtrée par la relation
// neutre `ZFilter(parentField, eq, parentId)` en `baseFilters` PERSISTANTS ;
// mini-CRUD réutilisant `ZListController`+`DynamicList`+actions/`ZAcl`/sélection/
// corbeille E4-1..E4-4 sans duplication ; reset de sélection sur changement de
// parent) ; onglets de catégorisation `ZTabbedList`+`ZListTab` (chrome pur-Flutter
// Material, chaque onglet = une liste indépendante, état/sélection PRÉSERVÉS et
// INDÉPENDANTS par onglet via keep-alive). Distinct du CHAMP d'édition inline
// E3-3b-2 (`z_sub_list_field_widget.dart`). Aucun Syncfusion/backend (SM-5).
export 'src/presentation/list/z_sub_list_screen.dart';
export 'src/presentation/list/z_tabbed_list.dart';
export 'src/presentation/theme/z_theme.dart';
export 'src/presentation/z_dependency_resolver.dart';
export 'src/presentation/z_field_listenable_builder.dart';
export 'src/presentation/z_form_controller.dart';
export 'src/presentation/z_scope_error.dart';
export 'src/presentation/zcrud_scope.dart';
