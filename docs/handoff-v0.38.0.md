# Handoff **v0.38.0** — CR-IFFD-43 : la fratrie sort de l'onglet

> **Tag à épingler : `v0.38.0`** · additif, aucune rupture d'API.
> `withinTab` reste le **défaut** — un hôte passif ne bouge pas d'une ligne.

---

## 1. Ce qui est livré — deux pièces, dont une seule était vraiment neuve

**(b) Le chaînon manquant** — `ZStudyFolderDetail.aboveTabViews` est désormais relayé vers
`ZPageScaffold`, exactement comme ses deux voisins l'étaient déjà. **Rien de créé** : le créneau
existait des deux côtés, en mode fixe **et** en mode sliver. Seule la relève par la façade manquait.

**(a) Le jeton** — `ZSubfolderNavPlacement { withinTab, aboveTabs }`, paramètre optionnel.
Sous `aboveTabs`, la bande est construite **hors** de l'arbre d'onglets et l'onglet matériel ne rend
plus que son corps : la navigation n'est **pas dupliquée**, la sélection garde **une seule source**.

🟢 **Votre diagnostic était le bon, et votre correction de vous-mêmes aussi.** Vous alliez demander
« un créneau de navigation persistante » ; vous avez mesuré qu'il existait. Votre formule —
*« la demande la plus large aurait été la moins bonne : elle aurait fait réinventer ce qui existe »* —
est exactement ce qui a rendu ce lot court.

## 2. 🔴 L'arbitrage que vous nous laissiez : **mesuré, pas argumenté**

Vous écriviez ne pas avoir mesuré ce qu'`aboveTabs` implique pour la sidebar large. Voici la réponse,
et elle est plus nette qu'un avis :

> Le créneau est un enfant de `Column` dont le frère porte l'`Expanded` : il reçoit une **hauteur non
> bornée**. La sidebar déployée contient elle-même un `Expanded` (sa liste défilante) et lève —
> **mesuré** — `RenderFlex children have non-zero flex but incoming height constraints are unbounded`.

**Hisser la sidebar est structurellement impossible**, pas seulement discutable. Cette mesure est
**rejouée comme garde**, pour qu'elle ne reste pas une affirmation de rapport.

Le sens le confirme : une sidebar est *une colonne du corps*, donc du contenu d'onglet. Déclarer la
fratrie « contexte de page » **et** la vouloir en colonne de corps sont deux demandes contradictoires.

⇒ **Sous `aboveTabs`, aucune sidebar n'est rendue, à aucune largeur** — la bande est hissée à 400,
599, 600 et 1200 dp. **Si vous voulez sidebar en large et bande en étroit, c'est exactement le défaut
`withinTab`** : ne changez rien.

🟢 **L'indépendance des deux axes que vous demandiez est préservée et gardée** : le placement vient du
seul jeton, jamais du point de rupture ; `narrowMode` reste l'autre axe, toujours actif.

## 3. Le conflit que vous n'aviez pas soulevé — tranché et documenté

Si vous fournissez **vous-même** `aboveTabViews` **et** demandez `aboveTabs` : **composition**, la
navigation en premier, votre slot ensuite.

* **pas de priorité** — elle ferait disparaître silencieusement un slot que vous avez fourni
  explicitement : le pire mode d'échec ;
* **pas d'assertion** — elle transformerait une composition légitime en panne debug, avec divergence
  debug/release (contraire à AD-10) ;
* **ordre** : la navigation **désigne le sujet** dont tout ce qui suit parle.

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — `withinTab` est le défaut, et une garde « à l'envers » **affirme que le comportement historique est conservé** |
| **vous, IFFD** | passez `subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabs` |
| 🔴 **hôte ayant COMPENSÉ** la perte | **retirez votre compensation** — navigation reconstruite à la main dans vos autres onglets, ou bandeau de contexte maison rappelant le sous-dossier : elle **s'additionnerait** à la bande |

## 5. 🟢 Deux morceaux de code inertes, débusqués par R3 et **supprimés**

Nous les signalons parce qu'ils illustrent ce que la discipline attrape au-delà des régressions :

* une boîte de largeur infinie autour de la bande : injection **verte** — mesuré, les deux surfaces
  rendaient déjà pleine largeur sans elle. **C'était une boîte vide, pas une propriété.** Retirée, et
  la garde de largeur retendue : elle ne compare plus à une constante externe mais à **la largeur des
  vues d'onglets** — *« la bande borde la page comme le contenu »* ;
* un alignement transversal étiré : vert partout, **et pourtant nuisible** — il mettait en page
  **votre** slot différemment selon que vous demandiez ou non `aboveTabs`. Retiré, et la garde qui
  manquait ajoutée : *« le slot de l'hôte est mis en page à l'identique avec et sans `aboveTabs` »*.

## 6. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_study` **891** (+25) · **0 error, 0 warning** (les 55 `info` sont **strictement la baseline**,
vérifiée par mise de côté du lot).

**8 injections R3**, toutes qualifiées. La garde principale ne se contente pas de « la nav est
présente » — elle mesure qu'elle est rendue **une seule fois**, **géométriquement entre la barre
d'onglets et leurs vues**, **visible depuis le 2ᵉ et le 3ᵉ onglet**, et qu'**agir dessus depuis le
2ᵉ onglet filtre bien le corps**. La feuille modale est ouverte **depuis le 3ᵉ onglet**.

⚠️ Notre CI reste à l'arrêt (facturation) : ces chiffres sont des vérifications **locales**.

## 7. Ce que nous savons ne pas avoir couvert

* **`aboveTabs` avec une coquille d'hôte** (`ZSubfolderNavRendererScope`) n'est pas gardé au-dessus
  des onglets : le chemin est le même widget, mais une coquille qui se dimensionne sur son contenu y
  sera **centrée** — cohérent avec le placement `withinTab`, non gardé.
* **`aboveTabs` en mode sliver `floating`** n'est pas gardé — seul `pinned` l'est.
* **Aucun test de rebuilds** dédié au nouveau placement : la bande est construite hors de l'arbre
  d'onglets, mais le comptage n'est pas rejoué.
* Deux notificateurs de sidebar restent créés et libérés sous `aboveTabs` alors qu'aucune sidebar
  n'est montée : inoffensif, mais c'est du poids mort **assumé** plutôt qu'éliminé.

## 8. 🟢 Votre note de méthode, que nous reprenons à notre compte

> *« `zcrud_navigation` — dont le nom promettait exactement cela — ne répond pas à ce besoin. Nous
> l'avons vérifié avant d'écrire, et non après. **Un nom de paquet n'est pas une mesure.** »*

Vérifié de notre côté : ce paquet traite bien de la politique de présentation d'**édition**. Votre
règle vaut pour nous autant que pour vous.
