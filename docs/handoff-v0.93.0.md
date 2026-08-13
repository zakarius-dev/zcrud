# Handoff **v0.93.0** — parité de l'écran CRUD avec le moteur remplacé

> **Tag à épingler : `v0.93.0`** — la plus grosse release du projet : **douze lots**, issus de
> l'analyse intégrale du moteur legacy remplacé (2021 lignes, 47 paramètres, 85 capacités
> inventoriées) et du retour de pilote sur un écran réel. Paquets porteurs : `zcrud_core`,
> `zcrud_screen`, `zcrud_menu`, `zcrud_ui_kit`, `zcrud_list`, `zcrud_navigation`,
> `zcrud_export`, `zcrud_export_pdf`.
>
> ⚠️ **Cette release contient une rupture de sécurité voulue** (§1) et plusieurs ruptures de
> signature. Lisez §1 et §8 avant de monter de version.

---

## 1. 🔴 Rupture — les autorisations sont désormais **fail-closed**

Jusqu'ici, tant qu'aucune ACL n'était déclarée, le socle repliait sur `ZAllowAllAcl` : une
application qui **oubliait** de brancher la sienne voyait **tous** les gestes au lieu
d'**aucun**. Rien ne levait, rien ne signalait l'oubli. **Le repli est désormais refusant**
(`ZDenyAllAcl`), sur les dix points qui consultaient une ACL — `ZcrudScope`, `DynamicList`,
`DynamicEdition`, `ZSubListFieldWidget`, `ZCrudScreen` et les trois scopes de binding.

- **Hôte déclarant déjà une ACL réelle** : rien ne change — mais vérifiez que vous accordez
  `view`, seule action dont la portée s'élargit (elle gouverne désormais l'accès à l'écran).
- **Hôte passif** : vos écrans passeront en « accès refusé ». Remède, **déclaré** :
  `ZcrudScope(acl: MonAcl())` — ou `ZcrudScope(acl: const ZAllowAllAcl())` pour retrouver
  l'ouverture totale, désormais lisible dans votre code.
- **Hôte ayant compensé** par un masquage maison de boutons : votre compensation
  **s'additionne** au correctif. Retirez-la. Widgets concernés au-delà de la cible :
  `ZCrudScreen`, `DynamicList`, `DynamicEdition.formActions`, `ZSubListFieldWidget`.

Second point indépendant : les libellés de l'assistant multi-étapes étaient codés en français
comme repli de dernier recours alors que la table par défaut du socle est l'anglais. Ils
suivent maintenant la table. Montez `ZcrudLocalizationsDelegate` avec la locale `fr` (ou
surchargez via `ZcrudScope(labels:)`) pour retrouver les libellés d'avant.

## 2. Les trois bloquants du retour de pilote

- **Une carte reçoit l'entité, dans n'importe quel layout.** `itemBuilder` était ignoré dès
  qu'un `layout` était fourni : une grille de cartes métier — la moitié d'un parc typique —
  ne recevait qu'une `ZListRow` anonyme. Les layouts à tuiles acceptent désormais un builder
  **typé** (`layout.withEntityTiles<T>(...)`, `ZListGridLayout.forEntity<T>(...)`).
  Et la convention de clé cesse d'être privée : `ZListRow.keyOf(entity)` /
  `ZListRow.ofEntity(...)` — **retirez votre réplication de `identityHashCode`**, c'était le
  seul endroit de votre code qui aurait cassé en silence.
- **La corbeille a ses trois gestes.** Purge via le mixin optionnel **`ZPurgeable`** (hors du
  port `ZRepository`, pour ne casser aucune implémentation existante) et
  `ZRowAction.purgeWith`. **Correction d'un défaut** : `rowActions` était ajouté aux **deux**
  vues — une action « purger » posée en contournement apparaissait dans la liste des éléments
  vivants. Les canaux sont séparés (`rowActions` / `trashRowActions`). Si vous filtriez
  vous-même, retirez ce filtrage.
- **La fiche de détail est le formulaire.** `ZScreenMode { full, details, locked }` remplace
  `readOnly` (déprécié, `readOnly: true ≡ locked` à l'octet près). En `details`, la surface
  ouverte rend **tous les `formFields`** en lecture seule — pas une fiche dérivée des 4-6
  colonnes de la liste — avec retour vers l'édition si `acl.update` l'autorise. Le drapeau
  descend jusqu'à votre formulaire par `ZCrudEditionScope.readOnlyOf(context)`.
  ⚠️ Un **champ widget libre** dessine ses propres contrôles : lisez le drapeau, sinon votre
  fiche « lecture seule » reste cliquable.

## 3. Ouvrir l'édition depuis une carte, et les actions en menu

`ZCrudScreenActions` (via `ZCrudScreenScope`) expose les gestes de l'écran à n'importe quel
descendant : `canOpenX(entity)` pour **interroger la capacité avant de rendre**, `openX(entity)`
pour ouvrir, `xOpener(entity)` pour obtenir le rappel — ou `null` quand le geste est impossible,
pour ne pas dessiner un bouton mort. La surface obtenue est **exactement** celle du bouton « + » :
même policy, même `formWeight`, même `onSave`. Plus de court-circuit par fermeture capturée.

Les actions de ligne peuvent se présenter **en menu** (débordement ou contextuel : clic droit
sur pointeur, appui long sur tactile), rendu par le renderer ambiant de `zcrud_menu` — donc
remplaçable par le vôtre. Une action refusée peut rester **visible et inerte avec sa raison**
plutôt que de disparaître sans explication.

## 4. Gouvernance par ligne — un seul concept

`ZRowAclResolver` rend les droits effectifs d'**une** entité ; `ZRowAction.enabledFor` porte
l'éligibilité métier. Les quatre seams du moteur legacy (ACL par item, `readOnly` par item,
`canBeDeleted`, `toBeValidated`) s'écrivent tous avec ce concept unique.

🔒 **Un résolveur de ligne RESTREINT, il n'élargit jamais.** La composition avec l'ACL d'écran
est une intersection — et `ZRowPermissions` n'expose aucun vocabulaire d'autorisation, ce qui
rend l'élargissement *inexprimable*, pas seulement interdit.

Distinction à connaître : un refus de **droit** obéit à votre `ZActionAclMode` (`hide` masque) ;
une **inéligibilité métier** est toujours rendue inerte avec sa raison, y compris en `hide` —
« restaurer » sur un élément vivant ne disparaît pas mystérieusement.

## 5. Onglets, corbeille, colonnes, requête, recherche

- **Onglets** : `acl`, `titles`, `countOf`, `baseFilters` sur `ZListTab`. La cascade
  onglet > écran > scope **restreint** (même règle qu'en §4).
- **Corbeille** : compteur (`ZCountBadge` dans `zcrud_ui_kit`), et **correction du critère de
  visibilité** — l'accès suit `restore || clear`, plus jamais `delete`. Un rôle « suppression
  seule » perd donc le bouton : c'est voulu. *Extension de notre initiative, invisible depuis
  votre CR* : en mode onglets, l'ACL d'écran est désormais posée au-dessus des pages, donc une
  ACL d'écran plus restrictive que le scope restreindra les listes d'onglets.
- **Colonnes** : numéro d'ordre (1-based sur l'affichage, **stable au tri**), **devise par
  ligne** (une ligne sans code retombe sur le repli **déclaré**, jamais sur la devise d'une
  autre), `formatWithRow`, largeurs bornées.
- **Requête** : `ZListQueryPolicy(sort:, baseFilters:, pageSize:)` déclarée une fois. Se
  compose avec la portée corbeille, les filtres d'onglet et la recherche — sans les écraser.
  `pageSize` ne s'applique pas à la voie `items` (tronquer une liste déjà rendue masquerait
  sans recours).
- **Recherche** : `searchScope` et `searchFolding`. **Le défaut ne change pas** (`searchable`
  seul). `ZListQueryPolicy.legacySearch()` retrouve le domaine du moteur remplacé — toutes les
  colonnes, espaces internes ignorés. ⚠️ Si vous compensiez par un filtrage maison sans
  espaces, **retirez-le avant** : sinon les deux se conjuguent et la liste rétrécit.

## 6. Sélection, actions de masse, export

Sélection multiple et actions de masse **assemblées** (`ZSelectionPolicy`, `batchActions`), avec
les mêmes autorisations que les actions de ligne : une entité inéligible est **exclue du lot**
avant écriture, jamais traitée en silence.

🟢 **Gain sur le moteur remplacé** : celui-ci **avalait** les échecs partiels d'une suppression
de masse. Vous obtenez désormais `succès · échecs · ignorés` avec les **noms** des entités en
échec, et le rapport complet via `onReport`.

**Export** : port `ZListExporter` dans le cœur, implémentations CSV/XLSX/PDF dans les paquets
d'export. **Aucun exporteur par défaut** : sans déclaration, aucune entrée, aucune dépendance
nouvelle. L'export reflète **ce que vous voyez** (tri, filtres, recherche, portée corbeille) et
se restreint à la sélection si elle est active. **Correction d'une perte silencieuse** : l'export
lisait les valeurs brutes et perdait les formats de colonne — un hôte consommant `ZExporter`
directement verra le **contenu** de ses fichiers changer sur les colonnes à devise ou
`formatWithRow`. C'est la correction, pas une régression.

## 7. Et ce que nous n'avons pas fait

- **Pas de renommage de `zcrud_list`** : votre remarque est fondée (le nom laisse croire à
  « l'écran de liste »), mais le renommage serait cassant pour un gain cosmétique. Le README du
  paquet dit désormais explicitement qu'il s'agit du **backend de rendu Syncfusion** du port
  `ZListRenderer`, et renvoie vers `zcrud_screen`.
- **Aucun moteur de menu tiers intégré par défaut** : le renderer est **injecté** par le scope.
  Intégrer un paquet tiers dans l'assemblage l'imposerait à tous les consommateurs — et
  réimporterait les défauts d'accessibilité qu'une application venait justement de corriger.
- **Pas de droit d'export inventé** : `ZCrudAction` n'a aucun membre pertinent ; l'export suit
  `view`.
- **Le mode `grid` du moteur legacy n'a pas été porté « fidèlement »** : il n'a aucune branche
  propre dans le code d'origine. L'implémenter fidèlement aurait été implémenter un
  comportement inexistant.

## 8. Ruptures de signature (détectées à la compilation)

| Symbole | Avant | Après |
|---|---|---|
| `ZCrudTrashWrite<T>` | `(T)` | `(BuildContext, T)` |
| `ZCrudScreen.readOnly` | `bool` | **déprécié** → `mode: ZScreenMode` |
| `ZCrudScreen.appBarActions` | `List<Widget>` | **déprécié** → `actions: List<ZAppBarAction>` |
| `ZSfDataGridRenderer.columnWidthMode` | `ColumnWidthMode` | nullable (largeur dérivée) — échappatoire : `columnWidthMode: ColumnWidthMode.fill`, désormais **ré-exporté par le barrel** |
| `ZCrudTitles` | dans `zcrud_screen` | déplacé dans `zcrud_core`, **ré-exporté** — imports inchangés |

## 9. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` RC=0 ·
`melos run verify` RC=0 (14 gates, 40 paquets, graphe **acyclique**, `CORE OUT=0`).
Tests rejoués depuis le dossier de chaque paquet, workstreams au repos : core **1949**,
screen **173**, ui_kit **227**, menu **80**, list **69**, navigation **188**, export **51**,
export_pdf **80**, export_ui **30**.

Discipline : chaque garde a été prouvée **mordante** par injection de la régression exacte
(rouge par assertion), restauration par copie vérifiée par sha256, résidus prouvés absents par
grep négatif. Un **contrôle R3 indépendant** a rejoué 34 gardes de deux lots dont les rapports
manquaient : 30 mordaient, **4 étaient défaillantes** — dont cinq assertions de refus qui, sous
régression, faisaient *pendre* le test au lieu de rougir. Toutes corrigées et reprouvées.
Aucun défaut de production derrière.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
ci-dessus constitue la ligne de défense de cette release.

## 10. Recommandation

Montez de version **écran par écran**, pas en bloc — la §1 est une rupture de posture, et vos
compensations (masquage de boutons, filtrage de recherche, réplication de clé, coquilles
d'assemblage) doivent être retirées au fur et à mesure. Gardez sur chaque défaut contourné un
test qui **affirme la perte** : il rougira à la montée et vous désignera le doublon, au lieu de
vous laisser croire ce handoff sur parole.
