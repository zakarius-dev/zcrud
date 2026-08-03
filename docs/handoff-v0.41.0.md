# Handoff **v0.41.0** — CR-IFFD-45 : le contexte de page passe AVANT les onglets

> **Tag à épingler : `v0.41.0`** · additif, aucune rupture d'API.
> `withinTab` reste le défaut — un hôte passif ne bouge pas d'une ligne.
> 🔴 **Lisez le § 2 avant d'intégrer** : la voie que votre CR proposait livrait un défaut
> silencieux. Nous l'avons mesurée, et nous ne l'avons pas prise.

---

## 1. Votre constat est exact — vérifié ligne à ligne

| Votre affirmation | Vérifiée |
|---|---|
| `subtitle` occupe la position visée et est déjà relayé par `ZStudyFolderDetail` | ✅ |
| `_selected` est un `ValueNotifier` **privé**, amorcé par `initialSelectedSubfolderId` | ✅ |
| aucun contrôleur externe, aucune notification de changement | ✅ — grep sur `z_subfolder_nav_spec.dart` : **0 ligne** |
| ⇒ un hôte devrait tenir une **seconde source de vérité** | ✅ et c'est traité au § 4 |

Vous aviez donc raison de refuser le contournement local. Il n'y en avait pas de correct.

## 2. 🔴 « Une valeur de plus, pas un mécanisme de plus » — **faux, et mesuré**

Vous proposiez de router vers `subtitle`. Or `subtitle` est posé dans le **`title:` de l'`AppBar`**
(`_zBuildTitleBlock`), donc dans une toolbar de 56 dp **qui ne s'agrandit jamais**.

Écran 500 × 800, mode fixe, 3 onglets — `TabBar` occupant 56 → 104 :

| contenu de `subtitle` | rect obtenu | AppBar totale | verdict |
|---|---|---|---|
| `Text` court | — | 104 dp | ok |
| bande **48 dp** | (16, **18** → **66**) | **104 dp, inchangée** | **10 dp de recouvrement du `TabBar`** |
| bande **96 dp** | (16, **−6** → 90) | **104 dp, inchangée** | **sort de l'écran par le haut**, 34 dp de recouvrement |

**Zéro exception de layout dans les trois cas**, et le `TabBar` reste tapable sous la bande qui le
recouvre. Le défaut aurait été **entièrement silencieux** — donc invisible à toute garde qui se
contente de vérifier que la surface est « présente dans l'arbre ».

⇒ **C'est aussi la réponse aux deux points que vous déclariez non mesurés** : l'app-bar **ne grandit
pas du tout** quand la fratrie s'allonge ; le contenu sort de l'écran au lieu de pousser quoi que ce soit.

## 3. Ce qui est livré à la place — un vrai créneau, dans le `bottom:` de l'app-bar

**`ZPageScaffold.aboveTabBar`** (`Widget?`) **+ `aboveTabBarHeight`** (`double?`), également sur
`ZPageShellBody` (mode sliver), posés par un **site de composition unique** :
`bottom:` devient `PreferredSize(Column [aboveTabBar, TabBar])`.

**`ZSubfolderNavPlacement.aboveTabBar`** — troisième valeur : la **même** surface, avec la **même**
source de sélection, routée vers ce créneau. L'onglet Matériel ne rend alors que son corps filtré :
la navigation est rendue **une seule fois**, la sélection garde **une seule source**. Composition
avec un `aboveTabBar` d'hôte : navigation d'abord, slot ensuite — même règle qu'en `v0.38.0`.

**Pourquoi la hauteur est DÉCLARÉE et non mesurée** : `AppBar.preferredSize` est consulté **avant**
la mise en page. Une mesure a posteriori arriverait après que le `Scaffold` a réservé sa hauteur —
c'est exactement le mécanisme qui produit le défaut du § 2. Contrepartie assumée : un contenu plus
haut que déclaré déborde **bruyamment** (`RenderFlex overflowed`), jamais en silence.
Repli si vous ne déclarez rien : `preferredSize` du créneau s'il en a un, sinon 56 dp. Pour la bande
de fratrie, le socle calcule la hauteur lui-même — **et il y ajoute votre `subfolderBarPadding`**
de `v0.40.0`, pour ne pas tronquer ce que vous venez de poser.

**Mesures sliver, verrouillées par gardes** (créneau 48 dp, drag −400) :

| mode | comportement |
|---|---|
| `pinned` | créneau **visible et inchangé** après défilement (dy 56 → 104) |
| `floating` | se replie avec l'app-bar (sort de l'arbre) |
| `floatingPinned` | toolbar repliée, **créneau épinglé en tête** (dy 0 → 48) |

Mode fixe avec un créneau de 96 dp : app-bar **200 dp = 56 + 96 + 48**, zéro recouvrement, rien hors
écran. C'est la contre-épreuve directe du tableau du § 2.

## 4. 🔵 Au-delà de votre demande — la sélection de fratrie devient ADRESSABLE

Le manque structurel derrière votre CR n'est pas le placement : c'est que **la sélection est
prisonnière**. Nous l'ouvrons, en optionnel pur :

* **`ZSubfolderSelectionController`** — contrôleur externe optionnel (`nav.selectionController`), sur
  le patron `ZDisplayState` de `zcrud_core` **déjà en production dans ce package**. Le contrôleur est
  la **source de vérité**, jamais un miroir ; le socle **ne le dispose jamais** (il ne lui appartient pas) ;
* **`nav.onSelectionChanged`** — pour l'hôte qui veut seulement **observer** ;
* **précédence tranchée et documentée** : un contrôleur fourni **prime** sur
  `initialSelectedSubfolderId` (sinon deux amorces se contrediraient en silence) ;
* `null` (défaut) ⇒ la page détient son état exactement comme avant ;
* le contrôleur pilote **aussi la sidebar** (≥ 600 dp, `withinTab`) — ce n'est pas réservé au nouveau placement.

Cela débloque ce que vous n'aviez pas encore demandé : **deep-link** vers un sous-dossier,
**persistance** de la sélection entre deux visites, **synchronisation** avec un autre écran — sans
jamais la seconde source de vérité que vous redoutiez à juste titre.

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — `withinTab` est le défaut, et les deux placements existants sont gardés inchangés |
| **vous, IFFD** | `subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar` |
| 🔴 **hôte ayant COMPENSÉ** | **retirez votre compensation** : si vous aviez posé **votre propre** barre de contexte dans `subtitle` (ou reconstruit la navigation à la main au-dessus des onglets) pour obtenir cette position, elle **s'additionnera** à la bande du socle — deux navigations, deux sources de sélection |
| vous vouliez piloter la sélection | `nav.selectionController` / `nav.onSelectionChanged` (§ 4) |

🟢 **Tripwire recommandé** : si vous compensiez, gardez un test qui **affirme votre compensation**
(p. ex. que votre barre maison est dans l'arbre, ou que le sous-dossier courant n'est pas observable
depuis l'hôte). Il rougira à l'adoption et vous désignera le doublon.

## 6. 🔵 Un tripwire de NOTRE côté, sur l'argument que nous venons de vous servir

Le § 2 est un argument fondé sur un comportement de Flutter. Nous ne vous demandons pas de nous
croire sur parole : une garde **affirme le défaut** de la voie `subtitle` — app-bar non agrandie,
recouvrement mesuré, **et `takeException() == null`**. Si Flutter change, elle rougit et nous signale
que l'argumentaire doit être re-mesuré avant d'être resservi.

## 7. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_ui_kit` **193** (+11) · `zcrud_study` **951** (+31) · **0 error, 0 warning** ·
consommateurs rejoués verts : `zcrud_session` 565, `zcrud_get` 74, `zcrud_menu` 72, `zcrud_chat_study` 67.

**R3 — 8 + 7 = 15 injections, toutes ROUGES D'ASSERTION**, aucune de compilation, aucune inerte.
🔴 **Les 8 injections du lot `zcrud_study` ont été rejouées par l'orchestrateur lui-même**, l'agent
rédacteur étant mort **avant** d'avoir prouvé la moindre garde : 31 tests verts au premier jet ne
prouvent rien tant qu'aucun n'a été vu rouge. Une neuvième injection a **échoué bruyamment** (motif
introuvable) plutôt que de passer pour une preuve — puis a été rejouée sur le motif réel.

Aucune garde ne teste la **présence** : toutes mesurent la **géométrie** (`getRect`) — bord bas du
créneau ≤ bord haut du `TabBar`, app-bar effectivement agrandie, aucun recouvrement. Les injections
« créneau présent mais mal placé » le prouvent : la surface est bien dans l'arbre, les gardes
rougissent quand même.

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**, pas un
run d'intégration continue.

## 8. Ce que nous savons ne pas avoir couvert

* **Le débordement bruyant n'est pas verrouillé par test** : nous n'avons pas voulu figer le message
  du framework. Un contenu plus haut que déclaré déborde — c'est documenté, non gardé.
* **Aucune garde sur une hauteur déclarée ≤ 0.**
* **Pas de mesure RTL** sur le nouveau créneau : aucune géométrie directionnelle n'y est introduite
  (`CrossAxisAlignment.stretch`), une garde RTL y serait tautologique. Nous le disons plutôt que de
  compter une garde de plus.
* **`aboveTabBar` n'est pas exposé sur `ZSearchableAppBar` seule** — son `bottom` y suffit.
* **`aboveTabBar` avec une coquille d'hôte** (`ZSubfolderNavRendererScope`) n'est pas gardé dans ce
  placement, comme déjà signalé en `v0.38.0` pour `aboveTabs`.
* **Aucun golden** : tout est mesuré en géométrie et en présence d'arbre, jamais en pixels.
* Le **débordement de libellé** signalé en `v0.40.0` § 4 reste **non corrigé** — toujours un candidat CR.
