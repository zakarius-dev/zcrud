/// Barrel d'API publique de `zcrud_core`.
///
/// Cœur : domaine pur + moteur d'édition + ports + `ZFieldSpec` + `ZcrudScope`.
/// Invariant AD-1 : puits du graphe de dépendances (aucune arête `zcrud_*` sortante).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// Couche DOMAINE/DONNÉES **pur-Dart** (Flutter-free) : ré-exportée depuis le
// point d'entrée dédié `package:zcrud_core/domain.dart`. Le barrel principal la
// ré-expose (API publique inchangée) ET y ajoute la couche présentation
// ci-dessous. Les satellites qui n'ont besoin QUE du domaine (leurs modèles)
// importent `domain.dart` pour rester transitivement pur-Dart (invariant AD-14).
export 'domain.dart';

// Couche présentation (invariants AD-2/AD-6/AD-13/AD-14/AD-15) : réactivité
// Flutter-native (aucun gestionnaire d'état). `ZFormController` (tranches
// `ValueListenable`), seams d'injection (`ZDependencyResolver` défaut throw,
// `ZScopeError`), `ZcrudScope` (InheritedWidget, défaut zéro-config), helper de
// slice. Seams l10n/thème injectables (invariant AD-13) : delegate générique
// `ZcrudLocalizations`/`ZcrudLocalizationsDelegate` + registre `ZcrudLabels` +
// helper `label(context, key)` ; `ZcrudTheme` (ThemeExtension, repli
// `Theme.of`, aucun style codé en dur).
// Moteur d'édition granulaire (invariant AD-2) : `DynamicEdition` (formulaire
// de référence, `ListView.builder` + sections visuelles, écoute STRUCTURELLE
// only) + `ZEditionField` (champ hôte scellé sur sa tranche via
// `ZFieldListenableBuilder`, `TextEditingController` stable, saisie sens unique).
// Dispatcher de champ par type + familles de base (invariants AD-2/AD-13) :
// classification exhaustive `EditionFieldType → EditionFamily` (`familyOf`),
// hôte-dispatcher `ZFieldWidget` (réutilise la tranche du champ), widgets par
// famille (texte/nombre/date/booléen/select/relation) + repli contrôlé
// `ZUnsupportedFieldWidget` (types servis ailleurs, par registre). Place stable
// garantie par `DynamicEdition` (KeyedSubtree).
// Port de zone de dépôt native (fichiers de l'OS, échange inter-apps) :
// abstraction pure au cœur + défaut zéro-dépendance `ZNoDropRegionRenderer`.
// L'implémentation native vit dans le satellite opt-in `zcrud_dnd` : son
// backend impose une chaîne de build native, que le cœur n'inflige à personne.
export 'src/presentation/dnd/z_drop_region_renderer.dart';
export 'src/presentation/dnd/z_drop_region_request.dart';
export 'src/presentation/edition/dynamic_edition.dart';
export 'src/presentation/edition/edition_field_family.dart';
export 'src/presentation/edition/families/z_app_file_field_widget.dart';
export 'src/presentation/edition/families/z_boolean_field_widget.dart';
export 'src/presentation/edition/families/z_color_field_widget.dart';
export 'src/presentation/edition/families/z_color_multi_field_widget.dart';
export 'src/presentation/edition/families/z_date_field_widget.dart';
export 'src/presentation/edition/families/z_date_range_field_widget.dart';
export 'src/presentation/edition/families/z_dynamic_item_field_widget.dart';
export 'src/presentation/edition/families/z_free_widget_field_widget.dart';
export 'src/presentation/edition/families/z_number_field_widget.dart';
export 'src/presentation/edition/families/z_rating_field_widget.dart';
export 'src/presentation/edition/families/z_relation_field_widget.dart';
export 'src/presentation/edition/families/z_row_chips_field_widget.dart';
export 'src/presentation/edition/families/z_select_field_widget.dart';
export 'src/presentation/edition/families/z_signature_codec.dart';
export 'src/presentation/edition/families/z_signature_field_widget.dart';
export 'src/presentation/edition/families/z_slider_field_widget.dart';
export 'src/presentation/edition/families/z_sub_list_field_widget.dart';
export 'src/presentation/edition/families/z_tags_field_widget.dart';
export 'src/presentation/edition/families/z_text_field_widget.dart';
export 'src/presentation/edition/families/z_unsupported_field_widget.dart';
// Soumission agrégée + états UI + confirmation d'abandon (invariants
// AD-2/AD-11/AD-15) : `ZEditionSubmitController` (validation agrégée
// toutes-étapes + seam `onSubmit` renvoyant `Either<ZFailure,T>`, états
// `ZSubmissionState` idle/inProgress/success/failure — le pont vers
// `AsyncValue.error` se fait au binding, jamais dans le cœur), `ZSubmitButton`
// (chrome accessible scellé sur l'état), `ZDiscardGuard` (garde de sortie type
// PopScope, seam `onConfirmDiscard`, aucune dépendance de routing),
// `ZCrossFieldValidator` (validation inter-champs `match`/`minKey`/`maxKey` en
// closures capturant le controller).
export 'src/presentation/edition/z_cross_field_validator.dart';
export 'src/presentation/edition/z_derivation_engine.dart';
export 'src/presentation/edition/z_discard_guard.dart';
export 'src/presentation/edition/z_edition_field.dart';
// Décoration de champ enrichie : résolveur d'ornement neutre
// `resolveAdornment`/`zFieldDecoration` (+ seam `ZAdornmentIconResolver`) et
// libellé enrichi partagé `ZFieldLabel` (style thémé + astérisque requis).
export 'src/presentation/edition/z_field_adornment_view.dart';
export 'src/presentation/edition/z_field_label.dart';
export 'src/presentation/edition/z_field_widget.dart';
// Seam d'acquisition de fichier injecté : interface `ZFilePicker` (impl
// concrète image_picker/file_picker fournie par l'application ou un binding —
// jamais par le cœur).
export 'src/presentation/edition/z_file_picker.dart';
// Voie UNIQUE de validation agrégée et de normalisation des saisies :
// `zValidateFormFields` / `zNormalizeFormValues` / `zNormalizeFieldValue`.
// Partagée par la soumission (`ZEditionSubmitController`) et par les
// formulaires intégrés hors de cette voie.
export 'src/presentation/edition/z_form_values.dart';
// Décorateur Card de la variante `ZFieldSize.large` : label au-dessus, champ
// interne bare, mesures pilotées par les tokens `large*` de `ZcrudTheme`.
export 'src/presentation/edition/z_large_field_card.dart';
// Fiche de consultation du mode lecture : `ZReadOnlyFieldCard` (label/valeur +
// copie presse-papier accessible). Les helpers de formatage/politique
// (`zReadOnlyValueOf`/`zReadModeCardable`) restent privés au paquet.
export 'src/presentation/edition/z_read_only_field_card.dart';
// Grille responsive 12 colonnes du moteur d'édition (invariant AD-13) :
// descripteur de span par breakpoint `ZResponsiveSpan`, seuils `ZBreakpoint`/
// `ZResponsiveBreakpoints`, widget de disposition directionnel `ZResponsiveGrid`.
export 'src/presentation/edition/z_responsive_grid.dart';
export 'src/presentation/edition/z_section_collapse_store.dart';
// Seam de présentation riche des familles de sélection : abstraction
// Material-free `ZSelectPresenter` + DTO neutre `ZSelectPresentation` (injecté
// via `ZcrudScope.selectPresenter`, défaut `null` → rendu natif). L'impl
// concrète (awesome_select) vit dans `zcrud_select`, jamais dans le cœur
// (invariant AD-1).
export 'src/presentation/edition/z_select_presenter.dart';
// Assistant multi-étapes (invariants AD-2/AD-13) : `ZStepperEdition`
// partitionne le MÊME `ZFormController` en étapes séquencées (réutilise
// `DynamicEdition` par étape) ; validation PAR ÉTAPE (gate « suivant » sur les
// validateurs de l'étape), état préservé en va-et-vient (controller unique),
// chrome scellé sur des canaux structurels. `ZEditionStep` = descripteur de
// présentation (titre + noms de champs).
// `ZStepperConfig` (+ enums `ZStepOrientation`/`ZStepStyle`/
// `ZStepIndicatorPosition`, directionnel) configure style/orientation/position
// d'indicateur, icône + sous-titre par étape, gate `validateOnNext`
// configurable, navigation par tap, et steppers imbriqués (single-writer
// racine de `visibleFields`).
// `z_step_partition.dart` livre l'adaptateur *data-driven inline* : une liste
// PLATE de `ZFieldSpec` annotés (`ZStepFieldConfig`) est regroupée en
// `List<ZEditionStep>` par une fonction pure et totale, consommée telle quelle
// par `ZStepperEdition`. Helper de construction — `EditionFieldType.stepper`
// reste délibérément `unsupported` (un stepper est un regroupement
// single-writer, pas un widget-feuille).
export 'src/presentation/edition/z_step_partition.dart';
export 'src/presentation/edition/z_stepper_config.dart';
export 'src/presentation/edition/z_stepper_edition.dart';
export 'src/presentation/edition/z_submission.dart';
export 'src/presentation/edition/z_submit_button.dart';
// Compilateur mémoïsable `ZValidatorSpec[] → FormFieldValidator` (invariant
// AD-2) : projette la donnée déclarative en validateur exécutable champ-local
// via `form_builder_validators` (jamais `flutter_form_builder`). Réutilisé par
// l'assistant multi-étapes.
export 'src/presentation/edition/z_validator_compiler.dart';
// Règle UNIQUE de vacuité du dépôt (`zIsEmptyValue`) et sa projection vers le
// texte soumis aux validateurs (`zValidationText`). Exportée pour qu'un champ
// custom à valeur structurée (map/liste) qualifie « vide » exactement comme le
// cœur — au lieu de ré-inventer une seconde règle qui divergerait de
// `required`.
export 'src/presentation/edition/z_value_emptiness.dart';
// Registre de widgets d'édition injecté (invariant AD-4) : `ZWidgetRegistry`
// (instanciable, jamais un singleton statique) + `ZFieldWidgetContext`/
// `ZFieldWidgetBuilder`. Sert les types dont le widget vit ailleurs (rich-text,
// géo/téléphone, `custom`→app) sans que le cœur importe ces paquets.
export 'src/presentation/edition/z_widget_registry.dart';
export 'src/presentation/l10n/z_labels.dart';
export 'src/presentation/l10n/z_localizations.dart';
// Moteur de liste — hôte + port neutre + dérivation/vues/états (invariants
// AD-8/AD-11/AD-13) : `DynamicList` (piloté par `ZListViewState`, dispatch sur
// `ZListLayout` ; délègue au `ZListRenderer` injecté sur le chemin dataGrid,
// `ZScopeError` actionnable si absent), port abstrait `ZListRenderer` (rendu
// concret `SfDataGrid` dans `zcrud_list`, jamais dans le cœur), colonnes
// **dérivées** `ZListColumn` + helper pur `deriveColumns`/`ZColumnPolicy`,
// variantes `ZListLayout` (dataGrid/builder/custom — builder/custom rendus
// dans le cœur sans Syncfusion), états `ZListViewState` (loading/empty/
// noResults/error/ready, accessibles), modèles neutres
// `ZListRenderRequest`/`ZListRow`.
// Actions de LOT génériques (invariant AD-10) : modèle déclaré en
// données `ZBatchAction`/`ZBatchActionKind` (delete/restore/move/custom ;
// `onSelected == null` ⇒ action absente ; `enabled: false` ⇒ action présente
// mais INERTE, motif annoncé), barre neutre `ZBatchActionBar` (tranche
// `selectedIds`, badge compteur, cible ≥ 48 dp, thème injecté) ; rapport au
// grain de la racine `ZBatchReport`/`ZBatchDeletionReport` (racines réussies +
// `Map<rootId, ZFailure>`). Voies `batchDelete`/`batchMove`/`applyCommonField`
// sur le contrôleur (seams injectés, `await`és par racine — cascade bornée
// hors du cœur). Puits du graphe de dépendances préservé (invariant AD-1).
export 'src/presentation/list/dynamic_list.dart';
export 'src/presentation/list/z_batch_action.dart';
export 'src/presentation/list/z_batch_deletion_report.dart';
// Post-filtre d'écran (AD-2/AD-10) : `ZItemFilter`, prédicat écrit sur
// l'entité typée et appliqué aux entités lues avant qu'elles ne deviennent des
// lignes — la voie des périmètres que la source ne sait pas exprimer.
export 'src/presentation/list/z_item_filter.dart';
export 'src/presentation/list/z_list_column.dart';
// Interrogation de liste (invariants AD-2/AD-8/AD-10/AD-15/AD-16) : contrôleur
// réactif Flutter-native `ZListController` (tranche
// `ValueListenable<ZListViewState>`, pagination curseur + repli in-memory,
// mapping empty/noResults) + `ZListPaginationMode` ; moteur in-memory neutre
// `zApplyListRequest` (+ `ZListPage`, `zMatchesSearch`, `zDeriveCursor`)
// productionisant le repli sans Syncfusion, backend ni gestionnaire d'état.
export 'src/presentation/list/z_list_controller.dart';
// Liste actionnable (invariants AD-2/AD-9/AD-11/AD-13/AD-16) : actions de
// ligne neutres `ZRowAction<T>` (+ fabriques corbeille softDelete/restore/edit)
// filtrées par `ZAcl`, résolues par ligne en `ZResolvedRowAction` (sans `T`) ;
// mode de filtrage `ZActionAclMode` ; sélection multiple neutre
// `ZListSelectionController` (+ `ZListSelectionMode`) keyée par `id` stable ;
// pont neutre `ZListInteraction` (hors `ZListRenderRequest` pour préserver
// l'égalité de valeur). Aucun Syncfusion, backend ni gestionnaire d'état.
export 'src/presentation/list/z_list_exporter.dart';
export 'src/presentation/list/z_list_interaction.dart';
export 'src/presentation/list/z_list_layout.dart';
export 'src/presentation/list/z_list_query.dart';
export 'src/presentation/list/z_list_render_request.dart';
export 'src/presentation/list/z_list_renderer.dart';
export 'src/presentation/list/z_list_selection.dart';
export 'src/presentation/list/z_list_tab.dart';
export 'src/presentation/list/z_list_view_state.dart';
export 'src/presentation/list/z_row_action.dart';
// Gouvernance PAR LIGNE (invariants AD-13/AD-16) : `ZRowPermissions`
// (vocabulaire de RESTRICTION — aucune autorisation n'y est exprimable),
// résolveur unique `ZRowAclResolver<T>` et voie de résolution partagée
// `zResolveRowActions`. La composition avec l'ACL de l'application est une
// INTERSECTION : une ligne retire un droit, jamais elle n'en ouvre un.
export 'src/presentation/list/z_row_governance.dart';

// Composition de listes (invariants AD-2/AD-8/AD-15/AD-16) : `ZSubListScreen<T>`
// (sous-liste d'entités RELIÉES filtrée par la relation neutre
// `ZFilter(parentField, eq, parentId)` en `baseFilters` PERSISTANTS ;
// mini-CRUD réutilisant `ZListController`+`DynamicList`+actions/`ZAcl`/
// sélection/corbeille sans duplication ; reset de sélection sur changement de
// parent) ; onglets de catégorisation `ZTabbedList`+`ZListTab` (chrome
// pur-Flutter Material, chaque onglet = une liste indépendante, état/
// sélection préservés et indépendants par onglet via keep-alive). Distinct du
// champ d'édition inline `z_sub_list_field_widget.dart`. Aucun Syncfusion ni
// backend en dépendance directe.
export 'src/presentation/list/z_sub_list_screen.dart';
export 'src/presentation/list/z_tabbed_list.dart';
// Politique de corbeille : quels gestes (mettre / restaurer / purger) une
// liste offre, en conjonction avec l'ACL et les capacités de la source.
export 'src/presentation/list/z_trash_policy.dart';
// Port de rendu réordonnable : abstraction pure au cœur, implémentations hors
// cœur (repli zéro-dépendance dans `zcrud_responsive`, ou impl fournie par un
// satellite ou par l'hôte). Aucun type tiers en surface.
export 'src/presentation/reorder/z_reorder_render_request.dart';
export 'src/presentation/reorder/z_reorder_renderer.dart';
// Patron général « état d'affichage détenu par un composant, mais pilotable
// par l'hôte » : contrôleur optionnel qui devient la source de vérité,
// possession hors `build` imposée, contrôleur jamais consommé sans être
// détecté comme tel.
export 'src/presentation/state/z_display_state.dart';
export 'src/presentation/theme/z_color_key_resolver.dart';
export 'src/presentation/theme/z_foreground_override.dart';
export 'src/presentation/theme/z_gradient_resolver.dart';
export 'src/presentation/theme/z_inverted_surface.dart';
export 'src/presentation/theme/z_theme.dart';
export 'src/presentation/z_crud_titles.dart';
export 'src/presentation/z_dependency_resolver.dart';
export 'src/presentation/z_field_listenable_builder.dart';
export 'src/presentation/z_form_controller.dart';
export 'src/presentation/z_rich_text_renderer.dart';
export 'src/presentation/z_scope_error.dart';
export 'src/presentation/zcrud_scope.dart';
