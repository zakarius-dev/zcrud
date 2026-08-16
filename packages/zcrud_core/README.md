# zcrud_core

Domaine pur et moteur d'édition/liste Flutter-natif de l'écosystème zcrud —
un même schéma déclaratif `ZFieldSpec` pilote les formulaires et les tableaux,
avec une réactivité par tranche (invariant AD-2) : jamais de reconstruction
globale du formulaire à la frappe.

## Aperçu {#apercu}

`zcrud_core` est le **puits du graphe de dépendances** de l'écosystème
(invariant AD-1) : il n'importe aucun autre paquet `zcrud_*`, aucun
gestionnaire d'état (Riverpod/GetX/provider), aucun backend lourd (Firebase,
Syncfusion, Quill, cartes). Tous les autres paquets du dépôt en dépendent ;
lui ne dépend de rien d'entre eux.

Le paquet est structuré en deux couches :

- **`domain/`** — pur-Dart (aucune dépendance Flutter, testable sous `dart
  test`) : le schéma `ZFieldSpec`/`EditionFieldType`, les ports (`ZRepository`,
  `ZLocalStore`, `ZRemoteStore`, `ZAcl`…), la hiérarchie `ZFailure`/`ZResult`,
  les registres d'extensibilité, les contrats de synchronisation offline-first.
  Exposée seule par `package:zcrud_core/domain.dart`, pour les satellites dont
  seul le modèle a besoin de rester transitivement pur-Dart (invariant AD-14).
- **`presentation/`** — Flutter-native : `ZFormController`
  (`ChangeNotifier`/`ValueListenable`), `DynamicEdition`/`DynamicList`, les
  familles de champs, `ZcrudScope`, `ZcrudTheme`, la l10n injectable.

**Utilisez ce paquet** comme fondation de tout CRUD `zcrud` : décrire un
modèle avec `zcrud_annotations`/`zcrud_generator`, éditer avec
`DynamicEdition`, lister avec `DynamicList`. **N'utilisez pas** directement
`zcrud_core` pour du rendu riche (Markdown/LaTeX → `zcrud_markdown`), une
grille `SfDataGrid` (→ `zcrud_list`), des flashcards/mindmaps (→
`zcrud_flashcard`/`zcrud_mindmap`) ou la persistance Firestore (→
`zcrud_firestore`) : ce sont des paquets satellites qui dépendent, eux, de
`zcrud_core`.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour la recette d'épinglage par tag et de `dependency_overrides`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

// Un champ décrit une fois : la même spec pilote édition et liste.
const nameField = ZFieldSpec(
  name: 'name',
  type: EditionFieldType.text,
  label: 'name',
  validators: [ZValidatorSpec.required()],
);

// L'état du formulaire vit dans un ChangeNotifier pur Flutter — une tranche
// ValueListenable par champ, jamais un rebuild global (invariant AD-2).
final controller = ZFormController(initialValues: {nameField.name: ''});

// Un widget qui n'écoute QUE la tranche 'name' : taper dans un autre champ
// ne le reconstruit jamais.
Widget buildNameSlice() => ValueListenableBuilder<Object?>(
      valueListenable: controller.fieldListenable(nameField.name),
      builder: (context, value, _) => Text('$value'),
    );

// Le formulaire de référence, place stable pour les champs conditionnels.
Widget buildForm() => DynamicEdition(
      controller: controller,
      fields: const [nameField],
    );
```

## Concepts clés {#concepts-cles}

- **Réactivité granulaire (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))**
  — `ZFormController` expose une `ValueListenable` par champ ; `DynamicEdition`
  n'écoute que les canaux structurels (liste des champs visibles, étape
  courante) et laisse chaque champ écouter sa propre tranche. C'est l'objectif
  produit qui corrige, par conception, le rafraîchissement global à la frappe.
- **Un schéma, deux moteurs** — `ZFieldSpec[]` pilote à la fois
  `DynamicEdition` (édition) et `DynamicList` (tableau) : décrire un champ une
  fois évite la dérive entre le formulaire et la colonne qui l'affiche.
- **Extensibilité par composition (invariant [AD-4](../../docs/site/concepts/invariants.md#ad-4))**
  — types servis ailleurs (`markdown`, `geoArea`, `phoneNumber`, `custom`…) se
  branchent via `ZTypeRegistry`/`ZWidgetRegistry` sans que le cœur importe le
  paquet qui les implémente ; configs spécialisées par extension de
  `ZFieldConfig`, jamais par `sealed` inter-paquet.
- **Domaine backend-agnostique (invariant [AD-5](../../docs/site/concepts/invariants.md#ad-5))**
  — `ZRepository<T>`/`ZLocalStore`/`ZRemoteStore` ne connaissent aucun type
  Firestore ; les contrats renvoient `Either<ZFailure, T>` (invariant
  [AD-11](../../docs/site/concepts/invariants.md#ad-11)) et des `Stream<List<T>>`
  nus. Les adaptateurs concrets vivent dans `zcrud_firestore`.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| **Schéma déclaratif** | |
| `ZFieldSpec` | Spécification `const` d'un champ — projection runtime de `@ZcrudField`. |
| `EditionFieldType` | Catalogue canonique des types de champ (pilote édition **et** liste). |
| `ZFieldConfig` (+ sous-classes) | Configuration spécialisée par type (`ZTextConfig`, `ZNumberConfig`, `ZSelectConfig`, `ZDateConfig`…). |
| `ZCondition` / `ZValidatorSpec` / `ZDerivation` | Visibilité conditionnelle, validation, dérivation cross-champ — toutes pur-données `const`. |
| `ZFieldChoice` / `ZFieldAdornment` / `ZFieldRename` | Option de sélection, ornement (leading/prefix/suffix), stratégie de renommage de clé. |
| **État réactif** | |
| `ZFormController` | Contrôleur `ChangeNotifier` du formulaire — une `ValueListenable` par champ. |
| `ZDependencyResolver` / `ZcrudScope` | Seam d'injection et son `InheritedWidget` par défaut (resolver, l10n, thème, registres). |
| **Édition** | |
| `DynamicEdition` | Formulaire de référence, dispatché par `EditionFieldType`, place stable pour les champs conditionnels. |
| `ZEditionField` / `ZFieldWidget` | Champ hôte scellé sur sa tranche ; dispatcher de widget par famille. |
| `ZStepperEdition` | Assistant multi-étapes sur le même `ZFormController`, validation par étape. `stepStore` reprend l'étape courante ; `collapseStore` conserve le repli des sections d'étape (chaque étape sous **sa** portée, dérivée de `formId` et du titre de l'étape). `null` (défaut) ⇒ aucune lecture, aucune écriture. |
| `ZEditionSubmitController` / `ZSubmitButton` | Soumission agrégée (`Either<ZFailure,T>`) et chrome accessible scellé sur l'état. |
| **Liste** | |
| `DynamicList` | Hôte de liste dispatché par `ZListLayout`, délègue le rendu grille à `ZListRenderer`. |
| `ZListController` | Contrôleur réactif — pagination curseur, recherche/tri in-memory de repli. `initialSorts` le fait **naître trié** : la toute première requête part déjà ordonnée, au lieu d'en émettre une non triée puis de la remplacer. |
| `ZListSelectionActivation` | Comment la sélection **s'ouvre** : en permanence (défaut) ou à l'**appui long**, les cases n'apparaissant qu'une fois la sélection non vide. « Ouverte » n'est pas un état à part — c'est « non vide ». |
| `ZListOrdinal` | Colonne de numéro d'ordre. `continuousAcrossPages` rend la numérotation continue quand c'est le **rendu** qui pagine : la règle reste au cœur, seule la position vient du rendu. |
| `ZRowAction<T>` / `ZBatchAction` | Actions de ligne et de lot (corbeille, restauration, déplacement…), filtrées par `ZAcl`. Absente et inerte sont distinctes : `onSelected == null` **retire** l'action, `enabled: false` la garde en place, grisée, motif annoncé. |
| `ZListTab` | Onglet de catégorisation. `baseFilters` déclare son socle (ANDé en tête, hors d'atteinte d'une recherche), `filtersWith` compose sans remplacer, `copyWith` permet à un assembleur d'envelopper sa vue sans recopier ses déclarations. |
| `ZSubListScreen<T>` / `ZTabbedList` | Sous-liste filtrée par relation ; liste à onglets indépendants. |
| `ZListExporter` / `ZExportedBytes` | Port d'export d'une liste (format, extension, type MIME, production d'octets) et fichier produit. Les implémentations vivent dans `zcrud_export`/`zcrud_export_pdf` : un hôte qui n'exporte rien ne tire rien. `exportSafely` convertit tout jet en `ZFailure` (invariant AD-10). |
| `zListFormatOf(context)` | Voie **unique** des seams d'affichage (libellé d'option orpheline, port de dates, locale) : liste et export la partagent, donc le fichier dit ce que l'écran montre. |
| **Domaine & données** | |
| `ZRepository<T>` / `ZReadOnlyRepository<T>` | Contrats repository backend-agnostiques (`Either<ZFailure,T>`, flux nus). |
| `ZFailure` (+ sous-classes) | Hiérarchie d'erreurs maison (`DomainFailure`, `NotFoundFailure`, `CacheFailure`…). |
| `ZExtension` / `ZExtensible` / `extra` | Slots d'extensibilité additifs versionnés (invariant AD-4). |
| `ZSyncMeta` / `ZLwwResolver` / `ZSyncOrchestrator` | Méta de synchronisation hors-entité, résolution Last-Write-Wins, orchestrateur offline-first. |
| `ZTypeRegistry` / `ZWidgetRegistry` / `ZcrudRegistry` | Registres ouverts d'extensibilité (types, widgets, modèles). |
| **Thème & l10n** | |
| `ZcrudTheme` | `ThemeExtension` de jetons visuels — jamais de couleur/style codé en dur. |
| `ZcrudLocalizations` / `ZcrudLabels` / `label()` | Delegate l10n générique + registre de libellés injectable. |

## Cas limites et invariants {#cas-limites}

- **Désérialisation défensive (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))**
  — un champ absent, inconnu ou corrompu ne fait jamais échouer le parent :
  repli sûr (`unknownEnumValue`, `fromJsonSafe → null`), jamais un `throw`. Un
  document écrit il y a longtemps se relit aujourd'hui.
- **Extension inter-paquet sans héritage** — toute extension métier (types de
  configs, sources de choix, widgets custom) se branche par composition
  (registre, `ZExtension`, `extra`) ; le cœur n'expose jamais de classe
  `sealed` à étendre depuis un satellite.
- **`ZDerivation` est le seul membre de `ZFieldSpec` à porter des closures** —
  elle n'est donc jamais émise par le générateur : c'est une surcharge runtime
  posée par l'hôte (`spec.copyWith(derivedFrom: ...)`), volontairement exclue
  de `==`/`hashCode`.
- **Le rendu riche est toujours en repli explicite** — un type dont le widget
  vit ailleurs (`markdown`, `geoArea`, `phoneNumber`, `custom`…) dégrade en
  `ZUnsupportedFieldWidget` tant que son `kind` n'est pas enregistré, jamais un
  crash.
- **Accessibilité et RTL (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13))**
  — variantes directionnelles partout (`EdgeInsetsDirectional`,
  `TextAlign.start`/`end`), cibles tactiles ≥ 48 dp, `Semantics` explicites.
- **Offline-first (invariant [AD-9](../../docs/site/concepts/invariants.md#ad-9))**
  — le store local est la source de vérité, le distant est fire-and-forget, la
  suppression est un soft-delete hors-entité (`ZSyncMeta.is_deleted`), le merge
  est Last-Write-Wins sur `updatedAt`.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_core.md`](../../docs/site/paquets/zcrud_core.md)
- [`ZFieldSpec`, le schéma canonique](../../docs/site/concepts/zfieldspec.md) — le concept central du paquet.
- [Réactivité granulaire](../../docs/site/concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Architecture hexagonale](../../docs/site/concepts/architecture-hexagonale.md) — couches et ports.
- [Offline-first](../../docs/site/concepts/offline-first.md) — AD-9 en pratique.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_list` — rendu de liste `SfDataGrid` qui implémente `ZListRenderer`.
- `zcrud_markdown` / `zcrud_geo` / `zcrud_intl` — widgets riches branchés via `ZWidgetRegistry`.
- `zcrud_firestore` — adaptateurs `ZRepository`/`ZLocalStore`/`ZRemoteStore` sur Firebase et Hive.

## Licence {#licence}

MIT — voir la racine du dépôt.
