---
title: Cookbook — recettes courtes
description: Des recettes minimales et compilables pour les besoins CRUD les plus courants, chacune renvoyant à l'écran de démo correspondant.
sidebar_position: 2
---

# Cookbook

Chaque recette résout **un** problème avec le **minimum** de code réel — extrait ou adapté
de l'application de démonstration [`example/`](https://github.com/zakarius-dev/zcrud/blob/main/example/README.md). Le code est
compilable contre les barrels publics ; les parties omises (thème, navigation…) sont
signalées par un commentaire.

## Générer un formulaire depuis un modèle annoté {#formulaire-depuis-un-modele}

Vous avez un modèle métier et vous ne voulez pas écrire le schéma de champs à la main.

Annotez le modèle — le générateur produit `toMap`/`fromMap`, `$ArticleFieldSpecs`
(le `ZFieldSpec[]`) et l'enregistrement au registre (invariant
[AD-3](../concepts/invariants.md#ad-3)) :

```dart
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

part 'article.g.dart';

@ZcrudModel(kind: 'article')
class Article {
  const Article({this.id, required this.title, this.published = false});

  factory Article.fromMap(Map<String, dynamic> map) => _$ArticleFromMap(map);

  @ZcrudId()
  final String? id;

  @ZcrudField(
    label: 'Titre',
    validators: <ZValidatorSpec>[ZValidatorSpec.required(), ZValidatorSpec.minLength(3)],
  )
  final String title;

  @ZcrudField(searchable: true)
  final bool published;
}
```

Après `dart run build_runner build --delete-conflicting-outputs`, le formulaire se monte
sans redéclarer un seul champ :

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

class ArticleFormScreen extends StatefulWidget {
  const ArticleFormScreen({required this.article, super.key});

  final Article article;

  @override
  State<ArticleFormScreen> createState() => _ArticleFormScreenState();
}

class _ArticleFormScreenState extends State<ArticleFormScreen> {
  late final ZFormController _controller =
      ZFormController(initialValues: widget.article.toMap());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicEdition(controller: _controller, fields: $ArticleFieldSpecs);
  }
}
```

Voir l'écran de démo : `example/lib/demos/edition_demo_screen.dart` (schéma de référence
`example/lib/demos/reference_form.dart`, qui couvre toutes les familles de champs).

## Afficher un champ selon la valeur d'un autre {#champ-conditionnel}

Un champ (« Code premium ») ne doit apparaître que si un autre (« Compte actif ») est coché.

`ZCondition` est déclaratif — jamais une closure (AD-14) — et évalué par le moteur
d'édition, qui ne reconstruit que la place du champ concerné
([AD-2](../concepts/invariants.md#ad-2)) :

```dart
const ZFieldSpec(
  name: 'premiumCode',
  type: EditionFieldType.text,
  label: 'Code premium',
  condition: ZCondition.truthy('active'),
);
```

Voir l'écran de démo : `example/lib/demos/reference_form.dart` (champs `active` /
`premiumCode`).

## Afficher un champ selon une option cochée {#champ-selon-option}

Le champ observé porte une **sélection multiple** (multi-`select`, `tags`, cases groupées,
relation multiple…) et le champ dépendant ne concerne qu'une des options retenues :

```dart
const ZFieldSpec(
  name: 'quotaLome',
  type: EditionFieldType.number,
  label: 'Quota de Lomé',
  condition: ZCondition.contains('bureaux', 'lome'),
);
```

`ZCondition.contains` répond à « cette valeur est-elle retenue ? ». Seule une collection
(`List`, `Set`…) peut la contenir : un champ absent, `null`, un nombre, une `Map` ou **une
chaîne** rendent `false`, sans jamais lever. Pour un champ à valeur unique, la question est
« est-ce cette valeur ? » — c'est `ZCondition.equals`.

## Exiger au moins un critère parmi plusieurs {#requis-conditionnel}

Un écran de recherche porte trois critères, dont **au moins un** doit être renseigné. Chaque
champ est requis tant que les autres sont vides :

```dart
const ZValidatorSpec.requiredIf(
  ZCondition.and(<ZCondition>[
    ZCondition.isEmpty('cst'),
    ZCondition.isEmpty('marque'),
  ]),
  errorText: 'Renseignez au moins un critère',
);
```

Quand la condition ne tient pas, le champ vide est accepté comme un champ sans `required` —
la présence reste portée par la seule famille « requis », jamais par un validateur de forme.
Le champ dépendant s'abonne aux seuls champs que la condition observe : le message apparaît
et disparaît sans qu'il faille retoucher le champ lui-même
([AD-2](../concepts/invariants.md#ad-2)).

## Découper un formulaire en étapes {#stepper}

Un formulaire de 30 champs est plus lisible en assistant qu'en un seul écran.

`ZStepperEdition` partitionne les **mêmes** `ZFieldSpec` sur un **même**
`ZFormController` — l'état est conservé en va-et-vient entre étapes :

```dart
const List<ZFieldSpec> fields = <ZFieldSpec>[
  ZFieldSpec(name: 'fullName', type: EditionFieldType.text, label: 'Nom complet'),
  ZFieldSpec(name: 'email', type: EditionFieldType.text, label: 'Courriel'),
  ZFieldSpec(name: 'country', type: EditionFieldType.select, label: 'Pays', choices: <ZFieldChoice>[
    ZFieldChoice(value: 'ne', label: 'Niger'),
    ZFieldChoice(value: 'fr', label: 'France'),
  ]),
];

const List<ZEditionStep> steps = <ZEditionStep>[
  ZEditionStep(title: 'Identité', fields: <String>['fullName', 'email']),
  ZEditionStep(title: 'Préférences', fields: <String>['country']),
];

ZStepperEdition(
  controller: controller,
  fields: fields,
  steps: steps,
  previousLabel: 'Précédent',
  nextLabel: 'Suivant',
  finishLabel: 'Terminer',
  onComplete: () {},
);
```

Voir l'écran de démo : `example/lib/demos/edition_stepper_demo.dart` et sa variante
combinant choix dynamiques + ACL de ligne, `example/lib/demos/stepper_sub_list_demo_screen.dart`.

## Éditer une sous-liste imbriquée {#sous-listes}

Une commande porte des lignes (désignation/quantité/prix) éditées inline, sans écran
séparé.

Le type `subItems` rend un CRUD compact dont le schéma des lignes est lui-même un
`ZFieldSpec[]`, porté par `ZSubListConfig` :

```dart
const ZFieldSpec(
  name: 'orderLines',
  type: EditionFieldType.subItems,
  label: 'Lignes de commande',
  config: ZSubListConfig(
    itemFields: <ZFieldSpec>[
      ZFieldSpec(name: 'designation', type: EditionFieldType.text, label: 'Désignation'),
      ZFieldSpec(name: 'qty', type: EditionFieldType.integer, label: 'Qté'),
      ZFieldSpec(name: 'linePrice', type: EditionFieldType.number, label: 'Prix'),
    ],
  ),
);
```

`ZSubListConfig.displayMode` et `summaryFields` compactent l'affichage. Les gestes d'item
sont gouvernés par l'`ZAcl` du `ZcrudScope` ambiant — **avec ou sans** `aclCollectionId`,
qui ne sert qu'à désigner la collection interrogée. Sans ACL déclarée, le repli refuse
tout ([AD-16](../concepts/invariants.md#ad-16)) : posez
`ZcrudScope(acl: …)` à la racine, ou `const ZAllowAllAcl()` si l'ouverture totale est
voulue.

Voir l'écran de démo : `example/lib/demos/reference_form.dart` (champ `orderLines`) et
`example/lib/demos/stepper_sub_list_demo_screen.dart` (sous-liste compacte + ACL de ligne
dans une étape).

## Réordonner les lignes d'une sous-liste {#sous-listes-ordre}

Dans certaines sous-listes, **l'ordre est la donnée** (un modèle principal puis ses replis,
des étapes numérotées) : il faut pouvoir le changer sans supprimer puis recréer.

`ZSubListConfig.reorderable` est **tri-état** — c'est le troisième état qui compte :

| Déclaration | L'ordre s'édite |
|---|---|
| non déclaré (défaut) | en mode `inline` seulement ; `compact` ne rend aucun contrôle d'ordre |
| `reorderable: true` | en `inline` **et** en `compact` |
| `reorderable: false` | nulle part, même avec un renderer injecté au scope |

```dart
const ZFieldSpec(
  name: 'modeles',
  type: EditionFieldType.subItems,
  label: 'Modèles, par ordre de priorité',
  config: ZSubListConfig(
    reorderable: true,
    itemFields: <ZFieldSpec>[
      ZFieldSpec(name: 'nom', type: EditionFieldType.text, label: 'Modèle'),
    ],
  ),
);
```

Le contrôle est un **glisser-déposer à poignée** — une cible de 48 dp en tête de ligne —
doublé d'**actions sémantiques de déplacement** par ligne, qui sont la voie non gestuelle
du lecteur d'écran ([AD-13](../concepts/invariants.md#ad-13)). En `compact`, les lignes
réordonnables sont rendues **hors** de la table de résumé, dont les en-têtes de colonnes
sont conservés — une table fige ses rangées. Le mode `tags` ne sait pas honorer la
déclaration : elle y est signalée par une assertion de debug, jamais ignorée en silence.

La liste réordonnable est rendue par le port `ZReorderRenderer`. Sans rien déclarer, un
repli interne au cœur assure le geste ; injecter une implémentation le remplace pour tout
le sous-arbre :

```dart
ZcrudScope(
  reorderRenderer: const ZPackageReorderRenderer(), // paquet zcrud_reorder
  child: monFormulaire,
);
```

Voir les fiches [zcrud_reorder](../paquets/zcrud_reorder.md#sous-liste) et
[zcrud_responsive](../paquets/zcrud_responsive.md#reorder-renderer) pour l'arbitrage entre
les implémentations — le geste de glissement diffère (contact de la poignée pour le repli
interne, appui long pour les deux satellites), les actions sémantiques non.

## Rendre du Markdown riche avec l'habillage « carte » {#markdown-chrome}

Un champ de contenu doit ressembler à une carte (en-tête icône, bordure, pilule d'action)
plutôt qu'à une simple zone de texte encadrée.

`ZMarkdownField.chrome` est **opt-in** ([AD-7](../concepts/invariants.md#ad-7)) : sans lui,
le rendu reste la boîte historique.

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

const ZFieldSpec bodyField =
    ZFieldSpec(name: 'body', type: EditionFieldType.markdown, label: 'Contenu');

ZMarkdownField(
  controller: controller,
  field: bodyField,
  chrome: const ZMarkdownFieldChrome(
    icon: Icons.article_rounded,
    gradient: <Color>[Color(0xFF667EEA), Color(0xFF764BA2)],
    onGradient: Color(0xFFFFFFFF),
  ),
);
```

Voir l'écran de démo : `example/lib/demos/markdown_demo_screen.dart` (sélecteur de
`ZCodec` Delta/Markdown + zone de valeur persistée).

## Offrir plusieurs formats de copie sur un contenu riche {#copie-multi-format}

Le même contenu doit partir tantôt en Markdown (vers un dépôt), tantôt en texte brut (vers
une messagerie). Un seul geste de copie ne peut pas deviner lequel.

Le paquet ne connaît que le **Delta neutre** : chaque format est une paire
**clé + transformation** déclarée par l'application, et le menu rend exactement cette
liste, dans cet ordre.

```dart
import 'dart:convert';

import 'package:zcrud_markdown/zcrud_markdown.dart';

String enMarkdown(List<Map<String, dynamic>> delta) =>
    '${const ZMarkdownCodec().encode(delta) ?? ''}';

String enDeltaJson(List<Map<String, dynamic>> delta) =>
    jsonEncode(const ZDeltaCodec().encode(delta));

ZMarkdownField(
  controller: controller,
  field: bodyField,
  copyOnLongPress: true,
  copyFormats: <ZMarkdownCopyFormat>[
    ZMarkdownCopyFormat(key: 'copyAsMarkdown', transform: enMarkdown),
    ZMarkdownCopyFormat(key: 'copyAsDelta', transform: enDeltaJson),
  ],
  copiedFeedbackText: 'Copié',
);
```

Trois points à ne pas manquer :

- **la clé libelle aussi l'entrée de menu** : elle est résolue par le système de libellés
  injecté (`ZcrudScope.labels`), avec repli sur la clé elle-même. Aucun libellé n'est codé
  dans le paquet — ni pour le menu, ni pour le retour de copie ;
- **le geste est opt-in** : sans `copyOnLongPress`, ni copie ni menu. Activé sans
  `copyFormats`, l'appui long copie directement la valeur encodée par le codec du champ ;
- **l'appui long de copie désactive la sélection interactive** du lecteur — les deux gestes
  se disputent la même arène, et c'est la copie qui gagne.

Les mêmes paramètres se posent une fois pour tout un sous-arbre sur
`registerZMarkdownFields`, plutôt que champ par champ.

## Aperçu inerte + édition plein écran pour un champ géo {#champ-geo-apercu}

Une carte pleine taille dans le flux d'un formulaire est encombrante ; un aperçu suffit,
avec une porte d'entrée vers l'édition complète.

`ZGeoPresentation.previewWithFullscreen` rend une carte lecture seule en flux (pan/zoom
conservés, tap d'ajout désarmé) et ouvre l'éditeur complet en plein écran :

```dart
import 'package:zcrud_core/zcrud_core.dart';
// Entrée dédiée : seul chemin qui tire le SDK flutter_map (AD-1).
import 'package:zcrud_geo/adapters/osm.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

final ZWidgetRegistry registry = ZWidgetRegistry()
  ..register('location', ZGeoFieldWidget.builder(adapterFactory: ZOsmMapAdapter.new));

const ZFieldSpec positionField = ZFieldSpec(
  name: 'position',
  type: EditionFieldType.location,
  label: 'Position',
  config: ZGeoFieldConfig(
    presentation: ZGeoPresentation.previewWithFullscreen,
    mapHeight: 180,
  ),
);
```

L'adaptateur OSM ne nécessite **aucune clé** ([AD-12](../concepts/invariants.md#ad-12)). Le
`ZWidgetRegistry` s'injecte via `ZcrudScope(widgetRegistry: registry, child: ...)`.

Voir l'écran de démo : `example/lib/demos/geo_demo_screen.dart` (champs `location` **et**
`geoArea`, parité multi-binding) et le registre partagé `example/lib/demos/demo_registry.dart`.

## Afficher une liste avec recherche, tri et pagination {#liste-recherche-tri}

Une collection doit se parcourir avec filtre, tri de colonne et « charger plus », sans
recharger tout l'écran à chaque frappe.

`ZListController` détient la requête courante et expose une **unique** tranche
`ValueListenable<ZListViewState>` ([AD-2](../concepts/invariants.md#ad-2)) ; `DynamicList`
la rend via le backend Syncfusion de `zcrud_list` ([AD-8](../concepts/invariants.md#ad-8)) :

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_list/zcrud_list.dart';

class Contact extends ZEntity {
  const Contact({required this.id, required this.name});

  @override
  final String? id;
  final String name;

  Map<String, Object?> toMap() => <String, Object?>{'name': name};
}

const List<ZFieldSpec> contactFields = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Nom', searchable: true),
];

class ContactListScreen extends StatefulWidget {
  // `repository` : port ZRepository<Contact> de votre couche data
  // (adaptateur zcrud_firestore, ou toute autre implémentation).
  const ContactListScreen({required this.repository, super.key});

  final ZRepository<Contact> repository;

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  late final ZListController<Contact> _controller = ZListController<Contact>(
    repository: widget.repository,
    toRow: (c) => ZListRow(id: c.id!, cells: c.toMap()),
    schema: contactFields,
    pageSize: 20,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZListViewState>(
      valueListenable: _controller.state,
      builder: (context, state, _) => DynamicList(
        fields: contactFields,
        state: state,
        renderer: const ZSfDataGridRenderer(),
      ),
    );
  }
}
```

`_controller.setSearch(...)`, `setSort(...)`, `setFilters(...)` et `loadMore()` pilotent la
requête ; chacun ne notifie que la tranche `state`.

Voir l'écran de démo : `example/lib/demos/list_demo_screen.dart` (recherche + filtre +
tri + pagination + actions de ligne + onglets + corbeille).

## Monter un écran CRUD complet sans recoudre le cycle {#ecran-crud-assemble}

La recette précédente monte la liste ; il reste à lui recoudre la recherche, le bouton de
création, la présentation du formulaire, la sauvegarde et la corbeille — écran par écran.

`ZCrudScreen` est la pièce qui **assemble** ces briques. Quand le modèle est enregistré au
`ZcrudRegistry` et que la source est un `ZRepository`, champs de liste et de formulaire,
projection en cellules et reconstruction d'entité sont **dérivés** du schéma généré :

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_list/zcrud_list.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

Widget buildContactsScreen(
  ZRepository<Contact> repository,
  ZcrudRegistry registry,
) {
  // Le rendu de la grille et l'ACL sont injectés une fois pour l'application.
  return ZcrudScope(
    listRenderer: const ZSfDataGridRenderer(),
    acl: const ZAllowAllAcl(),
    child: ZCrudScreen<Contact>(
      title: 'Contacts',
      source: ZCrudSource<Contact>.repository(repository),
      registry: registry,
      detailsEnabled: true,
      query: const ZListQueryPolicy(
        sort: <ZSort>[ZSort('name', ZSortDirection.asc)],
        pageSize: 50,
      ),
    ),
  );
}
```

Trois points à ne pas manquer :

- **l'ACL est refusante par défaut** ([AD-16](../concepts/invariants.md#ad-16)) : sans
  `acl` déclarée, l'écran n'offre aucun geste et affiche « accès refusé ». `ZAllowAllAcl`
  ci-dessus est l'ouverture totale **déclarée** — remplacez-la par la vôtre ;
- **le layout par défaut délègue à un backend de rendu** que le cœur n'embarque pas :
  sans `listRenderer` injecté, l'écran lève une `ZScopeError` explicite
  ([AD-8](../concepts/invariants.md#ad-8)) ;
- **`detailsEnabled: true`** ajoute la fiche de chaque ligne **sans** retirer la création
  ni la corbeille — contrairement à `mode: ZScreenMode.details`, qui fait de l'écran
  entier un écran de consultation.

Tout le reste se déclare de la même façon sur le même widget : corbeille (`trash`,
`trashPolicy`), droits par ligne (`rowAcl`), sélection multiple (`selection`), export
(`export`), onglets (`tabs`), coloration (`rowColor`).

Voir la [fiche `zcrud_screen`](../paquets/zcrud_screen.md) pour la carte complète des
déclarations, et le README du paquet pour l'API exhaustive.

## Compléter les valeurs juste avant l'enregistrement {#before-submit}

L'entité à enregistrer porte une donnée qu'aucun champ ne saisit : un identifiant de
pièces jointes publiées à part, un tampon métier, un état calculé. Fournir un formulaire
applicatif complet pour cela seul reviendrait à perdre tout ce que l'écran dérive.

`beforeSubmit` s'intercale **entre la validation du formulaire et la reconstruction de
l'entité**, et couvre d'un seul site la création, l'édition **et** la duplication :

```dart
ZCrudScreen<Dossier>(
  title: 'Dossiers',
  source: ZCrudSource<Dossier>.repository(repository),
  registry: registry,
  beforeSubmit: (Map<String, Object?> values, Dossier? original) async {
    return <String, Object?>{
      ...values,
      // `original` est nul en création, la copie éphémère en duplication.
      'revision': (original?.revision ?? 0) + 1,
      'piecesJointes': await depotDeFichiers.publierLesEnAttente(),
    };
  },
);
```

- la map rendue **remplace** les valeurs telles quelles sur le chemin d'enregistrement ;
- une exception levée dans le crochet **échoue proprement** — message affiché dans le
  formulaire, aucune écriture — et ne remonte jamais à l'appelant ;
- sans crochet déclaré, le chemin est strictement inchangé ;
- sous un `editionBuilder`, le crochet est sans effet : un formulaire applicatif maîtrise
  déjà ses valeurs avant d'appeler `save`.

## Exporter une liste en PDF ou Excel {#export-liste}

Le jeu de lignes affiché doit pouvoir se retrouver en pièce jointe.

`ZExporter` part du même schéma que la liste — aucune redéfinition de colonnes :

```dart
import 'dart:typed_data';

import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export/zcrud_export.dart';

Uint8List exportContactsToPdf(List<ZFieldSpec> fields, List<ZListRow> rows) {
  final request = ZListRenderRequest.fromSchema(fields, rows, policy: const ZColumnPolicy());
  return const ZExporter().toPdfBytes(request);
}

Uint8List exportContactsToExcel(List<ZFieldSpec> fields, List<ZListRow> rows) {
  final request = ZListRenderRequest.fromSchema(fields, rows, policy: const ZColumnPolicy());
  return const ZExporter().toExcelBytes(request);
}
```

Syncfusion `xlsio`/`pdf` reste confiné à `zcrud_export` : un hôte qui n'importe pas ce
paquet ne le tire jamais dans son build.

Voir l'écran de démo : `example/lib/demos/export_demo_screen.dart`.

## Injecter un thème et des dégradés de préréglage visuel {#preset-visuel}

Une app veut ses propres dégradés de dossier/carte sans qu'aucune couleur ne vive dans un
paquet zcrud.

`ZcrudTheme` porte les tokens neutres (espacements, hauteurs, alignements
**directionnels** — [AD-13](../concepts/invariants.md#ad-13)) ; `gradientResolver` reste
un pur mappage `clé → ZGradientSpec` posé par l'app :

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

const ZcrudTheme presetTheme = ZcrudTheme(
  accentBarHeight: 4,
  gradientBegin: AlignmentDirectional.centerStart,
  gradientEnd: AlignmentDirectional.centerEnd,
);

ZGradientSpec? presetGradientResolver(ColorScheme scheme, String key) {
  if (key != 'folder-primary') return null;
  return const ZGradientSpec(
    gradient: LinearGradient(colors: <Color>[Color(0xFF667EEA), Color(0xFF764BA2)]),
    onGradient: Color(0xFFFFFFFF),
  );
}

// À la racine de l'app :
ZcrudScope(
  theme: presetTheme,
  gradientResolver: presetGradientResolver,
  child: child,
);
```

Les widgets qui consomment un dégradé n'assemblent leur accent que si le token de hauteur
**et** le dégradé résolu sont tous deux non nuls — un préréglage partiel reste
inobservable par construction.

**`accentBarHeight` ne dimensionne pas que des cartes.** Le même token dimensionne aussi
la **barre d'accent supérieure d'un champ de formulaire**, dès qu'une couleur d'accent se
résout pour ce champ. Le résolveur ci-dessus ne répond qu'à `'folder-primary'` : aucun
champ ne porte donc de barre. Mais servir une clé de champ — `zcrud.fieldAccent.<nom du
champ>` pour un champ nommé, à défaut `zcrud.fieldType.<type>` pour tous les champs d'un
type — suffit à la faire apparaître sur les champs concernés, par l'**effet conjoint** de
deux déclarations qui existaient déjà séparément. Si vous posiez
`accentBarHeight` pour vos seules cartes, sachez-le avant d'ajouter la première clé de
champ ; l'inverse est vrai aussi — sans le token, aucune barre de champ.

La chaîne complète (teinte par type, normalisation de contraste, pastille d'ornement) est
décrite sur la fiche [zcrud_core](../paquets/zcrud_core.md).

Voir l'écran de démo : `example/lib/demos/iffd_visual_preset.dart` (dix dégradés clair/sombre
et le résolveur complet utilisé par toute l'application de démonstration).

## Basculer d'un mécanisme d'injection à l'autre {#binding-getx-riverpod}

La même page doit fonctionner sous `ZcrudScope` seul, GetX ou Riverpod sans dupliquer le
schéma ni l'écran ([AD-15](../concepts/invariants.md#ad-15)).

Le code spécifique au manager tient dans **un seul** wrapper, à la racine du sous-arbre —
jamais dans les champs ni dans l'écran :

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_riverpod/zcrud_riverpod.dart';

// GetX + get_it (cible DODLP) :
Widget wrapWithGetX(Widget child) => ZcrudGetScope(child: child);

// Riverpod (cible lex_douane/IFFD) :
Widget wrapWithRiverpod(Widget child) => ZcrudRiverpodScope(child: child);
```

`ZcrudGetScope`/`ZcrudRiverpodScope`/`ZcrudProviderScope` (paquet `zcrud_provider`)
enveloppent le **même** sous-arbre `DynamicEdition`/`DynamicList` : seul le `resolver`
d'injection change, jamais la construction des champs. Un scope de binding **dérive**
le `ZcrudScope` ambiant (`ZcrudScope.derive`) au lieu de le remplacer : il surcharge
`resolver` et `acl`, et **hérite tous les autres seams** (`theme`, `filePicker`,
`widgetRegistry`, `listRenderer`, registres de choix/relations, `gradientResolver`…)
posés plus haut — rien à redéclarer sous le binding.

Voir l'écran de démo : `example/lib/binding/binding_selector.dart` (sélecteur réutilisé
par les démos édition/liste/géo/intl) et `example/lib/demos/edition_demo_screen.dart`.

## Assembler un parcours de session d'étude {#session-etude}

Une file de flashcards doit s'enchaîner (question → réponse → note) en écrivant la
répétition espacée par une seule voie, jamais deux compteurs qui divergent.

`ZStudySessionEngine` est le **seul** type à détenir un `ZSessionReviewer` — la note d'une
carte passe exclusivement par lui ([AD-9](../concepts/invariants.md#ad-9)). Le swiper suit
la file **dynamique** du moteur (`engine.state.queue`), jamais un index indépendant :

```dart
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

// `reviewer` = le seam `reviewCard` de votre repository en production.
Future<ZResult<ZRepetitionInfo>> reviewCard({
  required String flashcardId,
  required String folderId,
  required int quality,
  DateTime? now,
}) async =>
    Right<ZFailure, ZRepetitionInfo>(
      ZRepetitionInfo(flashcardId: flashcardId, folderId: folderId),
    );

final List<ZFlashcard> cards = <ZFlashcard>[
  ZFlashcard(id: 'c1', folderId: 'f1', question: 'Capitale du Niger ?', answer: 'Niamey'),
];

final engine = ZStudySessionEngine(
  queue: <ZSessionItem>[
    for (final c in cards)
      if (c.id != null) ZSessionItem(flashcardId: c.id!, folderId: c.folderId ?? 'f1'),
  ],
  reviewer: reviewCard,
  mode: ZReviewMode.learn,
);

ZSessionCardSwiper(
  queue: engine.state.queue,
  cardBuilder: (context, item) => ZFlashcardReviewCard(
    card: cards.firstWhere((c) => c.id == item.flashcardId),
  ),
  passThreshold: const ZSrsConfig().passThreshold,
  onIndexChanged: (_) {},
  onStackEnd: () {},
);
```

L'entrée du parcours (choix du mode : apprentissage/révision/test/bachotage) passe par
`ZSessionModeSelector`, qui dérive elle-même la file initiale depuis les cartes dues.

Voir l'écran de démo : `example/lib/demos/study_session_demo_screen.dart` — l'assemblage
complet (sélecteur → swiper → carte interactive → résumé), avec la resynchronisation de
file et le verrou anti-double-célébration qu'un hôte réel doit reproduire.

## Voir aussi

- [Concept : ZFieldSpec](../concepts/zfieldspec.md) — le schéma qui alimente chacune de
  ces recettes.
- [Invariants d'architecture](../concepts/invariants.md) — les règles citées ci-dessus.
- [Catalogue des paquets](../paquets/index.md) — la fiche de chaque paquet mobilisé.
