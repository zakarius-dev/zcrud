# Handoff **v0.95.0** — l'onglet s'assemble, et le formulaire se détache

> **Tag à épingler : `v0.95.0`** — lève le **dernier bloquant d'adoption** (les 6 écrans à
> onglets), et livre le formulaire seul réclamé par deux moteurs legacy. Paquets porteurs :
> **`zcrud_core`**, **`zcrud_screen`**. Release additive, avec **une correction de
> comportement à connaître** (§3).

---

## 1. L'onglet s'assemble — `ZListTab.builder` devient optionnel

`ZCrudScreen` sans onglets assemblait ; **avec onglets, il n'assemblait pas** : il posait le
chrome et déléguait le corps à un `WidgetBuilder` opaque. Une liste d'onglet n'avait donc ni
« modifier », ni « détails », ni « mettre à la corbeille », et la recherche était désactivée.

Un onglet peut désormais se déclarer **sans vue** : il ne porte que sa catégorie
(`baseFilters`) et, s'il y a lieu, ses droits (`acl`) — l'assembleur lui construit sa vue, par
**les mêmes fonctions** que le mode sans onglets. Les quatre points sont livrés :

- **P1 — onglet assemblé** : actions de ligne, filtrage ACL, tout ce que l'écran sait faire ;
- **P2 — recherche partagée** : la restriction devient « pas de recherche **si un onglet est
  opaque** », au lieu de « pas de recherche **si onglets** ». Une barre unique filtre l'onglet
  **actif** ;
- **P3 — corbeille catégorisée** : livrée, pas différée. Vous vous disiez prêts à l'absorber ;
  le coût mesuré était faible (la table de contrôleurs est déjà indexée par portée) et le
  risque nul, puisqu'aucun écran de la v0.94 ne *pouvait* avoir d'onglet assemblé ;
- **P4 — `tabsScrollable`** : pour les six onglets de votre chef de division.

**Un onglet qui fournit son `builder` garde le comportement actuel à l'octet près** (contre-témoin
dédié). C'est un défaut, pas un remplacement : vos onglets qui rendent une carte, une carte
mentale ou un tableau de bord restent possibles.

**Découverte que votre CR ne mentionnait pas** : `ZTabbedList` composait **déjà** l'ACL
d'onglet en conjonction. La cascade n'avait donc rien à corriger — il suffisait que le corps
d'onglet **cesse de re-dériver** l'ACL d'écran, qui l'écrasait. Le défaut était un écrasement,
pas une absence.

**Corrigé au passage** (révélé par la garde adversariale) : `ZTabbedList` notifiait
`activeIndexNotifier` **pendant** son `initState`, donc pendant le build du parent — d'où un
`setState() called during build` au remontage. Le timing du cas courant est préservé.

### ⚠️ Hôte ayant compensé

Retirez, écran par écran : la liste re-déclarée, `entityFor`, les actions, le filtre de
catégorie — et surtout **la barre de recherche posée en `header`**, qui doublerait désormais
celle de l'app-bar. `vido/rapports_depotage` (+170 lignes pour basculer) est le premier
concerné.

Code qui **lisait** `tab.builder` : le type devient `WidgetBuilder?`, traitez le `null`.

## 2. Le formulaire seul, et la fenêtre qui rend une carte de valeurs

Vos deux moteurs legacy avaient `formOnly` — et la lecture du code montre qu'il recouvrait en
réalité **deux besoins** : `formOnly` monte le formulaire nu et `pop` **sans résultat** (l'hôte
pilote validation et soumission) ; `bodyOnly` rend la donnée. Les deux sont livrés séparément :

- **`ZFormOnly`** — le formulaire **sans coquille** (aucun `Scaffold`, aucune barre, aucun
  bouton imposé), intégrable dans une page. Le pilotage vient de l'extérieur via
  `ZFormOnlyController` : `validate`, `isValid`, `revealErrors`, `values`, `submit`. Le
  contrôleur que vous fournissez n'est **pas** libéré par le widget ; celui qu'il crée l'est.
- **`presentFormEdition(...)`** → **`Map<String, dynamic>?`** — page, feuille ou dialogue selon
  la `ZPresentationPolicy`, `null` si annulé, la carte des valeurs si soumis. Le chrome, le
  bouton de soumission et la garde d'abandon sont ceux du socle : rien de dupliqué.

**Ce qui est rendu est validé et normalisé** : types coercés, dates en ISO-8601, heures en
`HH:mm`, plages en `{start, end}`, énumérations en camelCase. Les champs **en lecture seule** et
ceux qu'une **condition masque** en sont **absents**. Un formulaire **invalide ne rend rien**.
Une valeur qui ne se laisse pas convertir est rendue **inchangée** — c'est au validateur de
refuser une saisie, jamais à la normalisation de la perdre.

Pas de `ZMapEntity` : le formulaire n'en a jamais eu besoin (`ZFormController` est nativement
une `Map`, `presentEdition<T>` est générique sans borne). Un tel type ne se justifiera que pour
**lister et persister** des données sans modèle typé — c'est un autre sujet, et il portera ses
propres questions d'identité et de sérialisation.

## 3. ⚠️ Correction de comportement — la sauvegarde passe par la même normalisation

En câblant le formulaire seul, une mesure a montré que **la soumission de `ZCrudScreen` ne
validait ni ne normalisait** : elle écrivait les valeurs **brutes** des contrôleurs. Aucune
normalisation n'existait dans le socle.

Les trois fonctions sont désormais publiques (`zValidateFormFields`, `zNormalizeFormValues`,
`zNormalizeFieldValue`) et **la sauvegarde de l'écran assemblé passe par elles** — une seule
règle pour toutes les surfaces.

**Ce qui change pour vous** : un champ **en lecture seule** ou **masqué par une condition** ne
peut plus contribuer à l'écrit, et les types sont projetés vers leur forme de persistance avant
d'atteindre votre `onSave` ou votre dépôt. Si vous compensiez cette absence par une
normalisation maison, **retirez-la** : elle s'appliquerait deux fois.

## 4. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` RC=0 ·
`melos run verify` RC=0 (14 gates, 40 paquets, graphe acyclique, `CORE OUT=0`).
`zcrud_core` **1950** tests · `zcrud_screen` **208** — **aucun test existant modifié** sur les
deux lots, ce qui est le vrai contre-témoin.

Vingt injections R3 au total, toutes rouges **par assertion** ; deux d'entre elles, obtenues
d'abord en *compilation*, ont été refaites en versions compilables plutôt que comptées.
L'unicité de la normalisation est prouvée structurellement : les injections portent sur la
**définition unique**, et il n'existe pas de seconde implémentation à injecter.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
ci-dessus constitue la ligne de défense de cette release.

## 5. Ce que cela débloque

Les 6 écrans à onglets peuvent basculer sans re-déclarer leur liste. Vos **deux coquilles
(1411 lignes)** n'ont plus de raison d'exister — c'était, selon vos propres termes, « la
dernière dette d'adoption du parc, et elle ne tient qu'à ce point ».
