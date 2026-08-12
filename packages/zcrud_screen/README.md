# zcrud_screen

Écran CRUD **assemblé et déclaratif** : `ZCrudScreen<T>` est à `DynamicList` ce
que `DynamicEdition` est aux champs — la pièce qui prend une déclaration et rend
un écran fonctionnel (liste, recherche, création, édition, sauvegarde,
corbeille), sans que l'assemblage ne monte jamais dans le cœur (invariant AD-1).

## Aperçu {#apercu}

zcrud fournit d'excellentes briques — `DynamicList`/`ZTabbedList` (rendu),
`ZRowAction` (actions de ligne gouvernées `ZAcl`), `presentEdition` +
`ZPresentationPolicy` (présentation dérivée du breakpoint), `DynamicEdition`/
`ZFormController` (formulaire), `ZRepository`/`ZDataRequest.deletedScope`
(données et corbeille). Ce paquet fournit **la pièce qui les assemble**, pour
que chaque application n'ait plus à recoudre le cycle complet écran par écran.

Dépendances internes (arêtes sortantes uniquement, graphe acyclique) :

```
zcrud_screen ──> zcrud_core
             └─> zcrud_navigation ──> zcrud_responsive ──> zcrud_core
```

**Quand l'utiliser** : « une liste dont on crée, édite et met à la corbeille
les éléments » — le cas d'usage nominal d'un écran CRUD, y compris ses
variantes en lecture seule (déclarées, jamais contournées).

**Quand ne pas l'utiliser** : une vue qui n'est pas une liste (carte
géographique, organigramme) — descendez d'un cran et composez directement
`DynamicList`/`ZListController`/`presentEdition` : l'assemblage est mince,
rien n'est perdu.

## Installation {#installation}

Dépendance git (paquet non publié sur pub.dev) :

```yaml
dependencies:
  zcrud_screen:
    git:
      url: git@github.com:zakarius-dev/zcrud.git
      ref: <tag>
      path: packages/zcrud_screen
```

Les arêtes internes (`zcrud_core`, `zcrud_navigation`…) exigent des
`dependency_overrides` à la racine du consommateur : suivez la recette
complète de `docs/private-git-consumption.md` (dépôt zcrud).

## Démarrage rapide {#demarrage-rapide}

Déclaration **minimale** — le type est enregistré au `ZcrudRegistry`
(annotation `@ZcrudModel`, registrar généré appelé au bootstrap) : champs de
liste et de formulaire, projection en cellules et reconstruction d'entité sont
**dérivés** du schéma généré, l'ACL vient du `ZcrudScope` ambiant, le mode de
présentation du breakpoint.

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

/// Modèle d'exemple — en pratique un `@ZcrudModel` dont le registrar généré
/// enregistre schéma et codec au bootstrap.
class Consignee extends ZEntity {
  const Consignee({this.id, required this.name, this.code = ''});

  @override
  final String? id;
  final String name;
  final String code;
}

Widget buildConsigneesScreen(
  ZRepository<Consignee> repo,
  ZcrudRegistry registry,
) {
  return ZCrudScreen<Consignee>(
    title: 'Consignataires',
    source: ZCrudSource<Consignee>.repository(repo),
    registry: registry,
  );
}
```

Exemple **complet** (celui du CR d'origine) — chaque dérivation surchargée par
un paramètre :

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

// `Consignee` : voir le modèle d'exemple du bloc précédent.

Widget buildConsigneesScreenComplet({
  required ZRepository<Consignee> repo,
  required ZcrudRegistry registry,
  required ZAcl acl,
  required List<ZFieldSpec> listFields,
  required List<ZFieldSpec> formFields,
}) {
  return ZCrudScreen<Consignee>(
    title: 'Consignataires',
    source: ZCrudSource<Consignee>.repository(repo),
    registry: registry,
    listFields: listFields,          // ce qui s'affiche
    formFields: formFields,          // ce qui s'édite
    cellsOf: (c) => <String, Object?>{'name': c.name, 'code': c.code},
    acl: acl,
    policy: const ZPresentationPolicy(),
    layout: ZListGridLayout(
      maxCrossAxisExtent: 350,
      itemBuilder: (context, row, columns) => Card(
        child: Center(child: Text('${row.cells['name']}')),
      ),
    ),
  );
}
```

Cohabitation (les données arrivent des flux de l'hôte, écritures par
callbacks) :

```dart
Widget buildCohabitationScreen({
  required List<Consignee> consignees,
  required ZcrudRegistry registry,
  required Future<void> Function(Consignee c) upsert,
  required Future<void> Function(Consignee c) softDelete,
  required Future<void> Function(Consignee c) restore,
  required bool Function(Consignee c) isDeleted,
}) {
  return ZCrudScreen<Consignee>(
    title: 'Consignataires',
    source: ZCrudSource<Consignee>.items(
      consignees,
      onSave: upsert,
      onSoftDelete: softDelete,
      onRestore: restore,
      isDeleted: isDeleted,
    ),
    registry: registry,
  );
}
```

## Concepts clés {#concepts-cles}

### Dérivation depuis le registre

Tout ce qui est dérivable d'une déclaration existante ne se redemande jamais :
`registry.kindOf<T>()` résout le `kind`, `fieldSpecsFor` fournit le schéma
(colonnes de liste, champs de formulaire — champs `isId` exclus du
formulaire), `encode` projette l'entité en cellules **et** en valeurs
initiales du formulaire, `decode` reconstruit l'entité depuis les valeurs
fusionnées (l'identité et les champs non édités sont conservés). Chaque
dérivation est remplaçable : `listFields`, `formFields`, `cellsOf`,
`editionBuilder`. Un type enregistré sous **plusieurs** kinds exige le
paramètre `kind` explicite (le registre refuse le choix silencieux).

### Source déclarative

`ZCrudSource.repository(repo)` est la voie nominale (lecture, recherche,
sauvegarde et corbeille par les ports neutres) ; `ZCrudSource.items(rows, …)`
la voie de cohabitation (callbacks optionnels). Les capacités de l'écran se
**dérivent** de la source : sans voie d'écriture, ni création ni édition ; sans
support de corbeille, ni bascule ni actions.

### Corbeille

Voie repository : le listing corbeille interroge le backend en portée
`ZDeletedScope.deletedOnly` (recherche et pagination inchangées) ; les actions
sont `ZRowAction.softDelete`/`.restore`. Voie items : partition par le
prédicat `isDeleted` déclaré, actions `softDeleteWith`/`restoreWith` — mêmes
permissions (`ZCrudAction.delete`/`.restore`), même filtrage `ZAcl`.

### Présentation de l'édition

Le formulaire est présenté via `presentEdition` : le mode (`page`/`sheet`/
`dialog`) se dérive du breakpoint par la `ZPresentationPolicy` déclarée
(`policy`, `formWeight`). `editionBuilder` remplace le formulaire dérivé par
un formulaire applicatif complet — la présentation et la voie de sauvegarde
restent assemblées.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZCrudScreen<T>` | Écran CRUD assemblé : liste + recherche + création + édition + sauvegarde + corbeille, depuis une déclaration. |
| `ZCrudSource<T>` | Source déclarative : `.repository(ZRepository<T>)` ou `.items(List<T>, callbacks…)`. |
| `ZTrashMode` | Activation de la corbeille : `auto` (dès que la source la supporte) / `none`. |
| `ZCrudSave<T>` | Persistance (upsert) d'une entité — `onSave` de l'écran et de la source. |
| `ZCrudTrashWrite<T>` | Écriture de corbeille déléguée (voie items). |
| `ZCrudEditionBuilder<T>` | Fabrique du formulaire applicatif — voie d'échappement de l'édition dérivée. |
| `ZCrudItemBuilder<T>` | Rendu d'une tuile (reçoit l'entité `T`) — voie d'échappement de la tuile générique. |

## Cas limites et invariants {#cas-limites}

- **Lecture seule par déclaration** : `readOnly: true`, `canCreate: false`,
  `trash: ZTrashMode.none`, ou `ZCrudSource.items(rows)` sans callbacks — un
  journal immuable ou un référentiel distant en lecture seule s'écrivent sans
  contournement.
- **ACL partout** (invariant AD-16) : bouton de création (`ZCrudAction.create`),
  actions de ligne (`update`/`delete`/`restore` — masquées par défaut,
  grisables via `actionAclMode`), bascule corbeille. `acl` non fourni ⇒ l'ACL
  du `ZcrudScope` ambiant s'applique.
- **Jamais d'exception de persistance** (invariants AD-10/AD-11) : un échec de
  `repository.save` (ou un callback hôte qui lève) est replié en `ZFailure`
  et **affiché dans la surface d'édition** (zone annoncée, `liveRegion`), qui
  reste ouverte. Exception : la voie `editionBuilder` reçoit un `save` qui
  lève un `StateError` sur échec — le formulaire applicatif reste maître de
  son affichage.
- **Déclaration incomplète = erreur actionnable** : sans registre ni
  `listFields`/`cellsOf`, l'écran lève une `ZScopeError` nommant le paramètre
  manquant — jamais un écran vide silencieux.
- **Réactivité granulaire** (invariant AD-2) : contrôleurs possédés par des
  `State` (create/dispose), liste écoutée sur sa seule tranche
  `ValueListenable<ZListViewState>`, formulaire réactif par tranche
  (`ZFormController`), bouton de création re-évalué par `ValueListenable`
  (onglets).
- **Onglets** : `tabs` non-`null` ⇒ le corps est un `ZTabbedList` (chaque
  onglet possède sa vue) ; la création lit `canCreate` et `defaultItemBuilder`
  de l'onglet **actif** (`Map` de valeurs ou entité `T`). La recherche et la
  corbeille de l'écran ne s'appliquent pas au contenu des onglets.
- **Purge définitive absente** : `ZRepository` n'expose pas de suppression
  dure ; l'action « vider » se branche via `rowActions` (action custom) le cas
  échéant.
- **RTL / a11y** (invariant AD-13) : primitives directionnelles, `Semantics`
  explicites, cibles ≥ 48 dp. Aucune couleur codée en dur (rôles du thème).

## Voir aussi {#voir-aussi}

- Fiche du paquet : `docs/site/paquets/zcrud_screen.md` (dépôt zcrud).
- `zcrud_core` — `DynamicList`, `ZListController`, `ZRowAction`,
  `DynamicEdition`, `ZcrudRegistry` : les briques assemblées ici.
- `zcrud_navigation` — `presentEdition`, `ZPresentationPolicy`, `ZFormWeight`.
- `zcrud_list` — backend de **rendu** Syncfusion du port `ZListRenderer`
  (à injecter si vous utilisez le layout `dataGrid`).

## Licence {#licence}

MIT — voir la racine du dépôt.
