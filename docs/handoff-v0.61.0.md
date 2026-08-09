# Handoff **v0.61.0** — le `select` à parité DODLP, et la régression du chrome refermée le jour même

> **Tag à épingler : `v0.61.0`**
> 🔴 **DODLP : deux gestes à faire ENSEMBLE** (§ 2) — la correction du chrome n'est utile que si vous
> retirez votre contournement **en même temps** que vous déclarez le nouveau paramètre.
> Hôte passif : **rien ne bouge**. Aucun paquet nouveau (38).

---

## 1. Le champ de sélection à parité DODLP legacy

Décision du propriétaire : **tout champ de sélection doit être produit par `awesome_select` via
`zcrud_select`, et reproduire l'apparence par défaut de DODLP legacy.**

### Ce que nous avons trouvé en lisant votre code, et que vous ne saviez peut-être pas
🔵 **En multi, vous rendez des interrupteurs, pas des cases à cocher.** Votre `edition_screen.dart`
calcule un `_choiceType`… puis **ne s'en sert pas** dans la branche multiple, qui retombe sur
`switches`. Notre satellite rendait des cases : il était en écart de fidélité **depuis toujours**,
et personne ne l'avait vu. Corrigé sur votre comportement **réel**, pas sur l'intention lisible.

Trois autres écarts relevés à la source : le `Wrap` de puces est **multi seulement** (le mono est un
texte), un `choiceBuilder` **ré-active** le tap même en lecture seule, et un padding qui n'existe que
sur une branche.

### 🔴 Le trou qui comptait le plus : enrôler le présentateur riche FAISAIT PERDRE une capacité
Le rendu **natif** exposait déjà Créer / Modifier / Copier via un gestionnaire CRUD. Le seam
`ZSelectPresentation` ne le transportait pas — donc **passer au présentateur riche retirait ces
actions**. C'était une régression fonctionnelle silencieuse, offerte à qui suivait notre
recommandation. Le seam les porte désormais.

Ajouté au seam, **tout nullable et inerte par défaut** : `isLoading` (que `relation` possédait sans
l'envoyer), `choiceBuilder`, `choiceSecondaryBuilder`, `optionsLoader`, `crudHandler`.

🔵 **Une mesure du premier lot corrigée par le second** : `field.leading` était **déjà atteignable**
(le DTO porte le `ZFieldSpec`) — il suffisait de le lire. Aucun élargissement n'était nécessaire là.

**Refusé comme non exprimable neutrement** : `modalActionsBuilder`, `onModalWillOpen/onModalOpen`,
`modalBuilder` — leurs usages réels pilotent l'**état interne du fork**, qui n'a pas sa place dans
`zcrud_core` (AD-1). Leur **fonction produit** est en revanche implémentée dans `zcrud_select`, où le
type du fork est légitime : vous obtenez le comportement sans que le cœur connaisse `awesome_select`.

### L'apparence : structure DODLP, couleurs par rôles
🔴 Le propriétaire a tranché ailleurs : **« on n'impose aucune couleur ; chaque app injecte ses
jetons, hérités du `Theme` de l'app »**. Donc **les métriques sont les vôtres à l'identique** (carte
élévation 0 / rayon 12 / filet 1, `ListTile` à chevron, `Wrap(6, 4)` de puces, tailles de texte,
paddings — relevés chez vous, centralisés dans une référence auditée), et **les couleurs sont des
rôles** :

`grey.300` → `outlineVariant` · `grey.400` → `onSurfaceVariant` · `black87`/`white` → `onSurface` ·
`blueAccent` → `primary` · fond de la barre → `surface` à 70 %.

🔵 Élégance involontaire de votre code : votre ternaire `isDark ? kNavyColor : grey.shade200` est
**absorbé par un seul rôle**, `surfaceContainerHighest`, qui fait le travail des deux branches. Le
mode sombre n'a plus de branche du tout.

**Chaîne complète** : `ZSelectTileSpec` (paramètre) > `ZcrudTheme.select*` (jeton) > référence.
**8 jetons retenus, 7 écartés** — écartés parce qu'ils **dupliqueraient un canal que le SDK possède
déjà** (`ChipTheme`, `TextTheme`, `hintColor`, `CardThemeData.elevation`) ou sont des micro-métriques
d'un seul widget, atteignables par paramètre. Les 3 métriques de carte sont **retenues malgré**
`CardThemeData`, parce que la référence prime sur elle (`shape:` explicite) : le jeton est alors le
seul canal à l'échelle de l'application.

### 🔴 Six défauts du legacy NON reproduits
* votre `Stack` portant un `FormBuilderCheckboxGroup` **à options vides**, monté uniquement pour
  transporter un validateur — un détournement, pas un patron ;
* votre liste encodée par une **sentinelle textuelle** (`join("S2Choice")`) ;
* votre `Future.delayed(300 ms)` suivi d'un `setState` — c'est-à-dire **le rafraîchissement global
  qui est l'objectif produit n°1 de ce dépôt** ;
* un `Future.delayed(500 ms)` + double `Get.back()` ;
* `kErrorColor` en littéral ;
* l'absence de tooltip sur les actions.

### Chargement asynchrone : le fork ne protégeait pas ce qu'il fallait
Mesuré : `awesome_select` ne rattrape que `on Error`. Une **`Exception`** — l'échec **normal** d'une
E/S — **remonte** et casse le champ ; et une `Future` qui ne se termine jamais bloque
**définitivement**. Enveloppé, plus un délai de garde de 30 s : dans les **trois** cas, liste vide et
champ utilisable (AD-10), prouvé par injection.
**SM-1 mesuré, pas supposé** : pendant tout le chargement, `onChanged` n'est jamais appelé et
l'`Element` du déclencheur est **identique** avant et après.

### ⚠️ Un ajout au-delà de la demande, à connaître
Une **barre d'actions de modal** (créer / confirmer / réinitialiser) et un **champ de recherche
permanent** en multi ont été livrés — c'est dans le périmètre de la parité (votre `modalConfig`
active `useHeader`/`useConfirm`/`filterAuto`), mais **au-delà de la lettre de la demande**. Elle est
**active par défaut** ; coupez-la par `ZSelectTileSpec(showModalActions: false)`.
🔵 Bénéfice de forme : la recherche est rendue **en plus** plutôt qu'en activant le filtre du fork —
ce qui fait disparaître **vos deux contournements** sur ce point.

### « Par défaut » : ce que ça peut vouloir dire, et ce que ça ne peut pas
🔴 **AD-1 interdit à `zcrud_core` de dépendre de `zcrud_select`** (`CORE OUT = 0`) : le socle ne peut
pas monter `awesome_select` de lui-même. « Par défaut » ne peut donc pas signifier « sans rien
faire ». Ce que ça signifie ici : **une ligne** —
`ZcrudScope(selectPresenter: const ZSmartSelectPresenter())` — et **tout le reste est le défaut**.
Un hôte qui enrôle le présentateur obtient l'apparence DODLP sans rien configurer.
Les cinq familles `select` / `radio` / `checkbox` / `multiselect` / `relation` passent par le même
seam (vérifié : elles mappent toutes sur `EditionFamily.select`, `multiselect` en étant le drapeau).

## 2. 🔴 `ZEditionScaffold` : votre CR du jour, et ce qu'elle ne disait pas

Votre diagnostic est **exact** — `SliverToBoxAdapter` donne une hauteur infinie, écran blanc.
Trois choses en plus, mesurées :

| | corps `ListView` non borné |
|---|---|
| `page` | 14 exceptions |
| **`sheet`** | **23 exceptions** — 🔴 **le même piège par une autre voie** (`Flexible(SingleChildScrollView(…))`), que votre CR ne mentionne pas |
| `dialog` | **0** — son `Flexible` borne déjà |

🔴 **`ZStepperEdition` échoue AUTREMENT** : ce n'est pas une `ListView` mais une `Column`+`Expanded`.
Son rouge est `RenderFlex children have non-zero flex`, pas `Vertical viewport`. ⇒ **votre
contournement `shrinkWrap` ne l'aurait pas sauvé.** La déclaration côté contenant, si.

### Le remède que vous proposiez casse l'en-tête
`SliverFillRemaining(hasScrollBody: true)` fait bien défiler le corps — mais l'en-tête **ne se replie
plus jamais** (titre mesuré figé après 400 px). La forme qui satisfait les deux est un
`NestedScrollView`, et `floatHeaderSlivers: true` **n'est pas décoratif** : sans lui l'en-tête ne
reparaît qu'au retour en haut de liste. Une injection ne fait rougir que cette garde-là — elle
mesure bien la **réapparition**, pas l'existence.

### Livré : `ZEditionBodyFit { intrinsic, scrollable }`
Sur `ZEditionScaffold(bodyFit:)` **et** `presentEdition(bodyFit:)`.
🔴 **Votre option 1 (reconnaître le type du corps) est refusée** : c'est l'heuristique
`runtimeType.toString()` d'IFFD que ce dépôt a refusé de reproduire **le matin même**, dans ce même
paquet. Le socle ne devine jamais la nature du contenu ; l'hôte déclare.

**Défaut inchangé (`intrinsic`)** — parce que la condition que nous avions posée est mesurée
**fausse** : sur un corps **non** scrollable, les deux régimes donnent des arbres **différents**
(`SliverFillRemaining` étire un texte court sur tout le viewport). Le régime robuste n'est pas
gratuit, donc il se déclare.
🔵 Honnêteté de mesure : l'étalon d'arbre livré le matin est **structurellement aveugle** à cette
question (il épingle la voie `chrome: null`, qui ne monte jamais le scaffold). Il n'a donc **pas**
été invoqué comme preuve ; la mesure a été refaite avec son sérialiseur sur la voie `chrome != null`.

### L'échec devient actionnable — et sa limite est dite
Intercepter l'exception est **impossible** : `RenderObject.layout` l'avale lui-même. Le signal fiable
est l'absence de taille de l'enfant sous contrainte infinie. Le message nomme le paramètre **et**
précise de **ne pas** transformer votre corps. Il vit dans un `assert` (élidé en release) et ne
construit aucun widget d'erreur.
⚠️ **La détection reste post-mortem** : vous verrez toujours `Vertical viewport…` en premier, notre
message ensuite.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — rendu inchangé, `bodyFit` par défaut inchangé, présentateur toujours opt-in |
| 🔴 **DODLP (a contourné)** | **les deux gestes ENSEMBLE** : ajoutez `bodyFit: ZEditionBodyFit.scrollable` **et retirez** `shrinkWrap: true` + `NeverScrollableScrollPhysics()`. **Garder les deux casserait le défilement en feuille.** Ne rien faire reste valide |
| **hôte enrôlant `ZSmartSelectPresenter`** | vous gagnez la parité DODLP **et** les actions CRUD que le seam ne transportait pas. En multi le rendu passe en **interrupteurs** (le vrai comportement DODLP). Barre d'actions de modal active par défaut : `showModalActions: false` pour la couper |
| **IFFD / lex_douane** | même piège de corps scrollable si vous adoptez le chrome — en `page` **et** en `sheet` |

🟢 **Tripwire recommandé** (DODLP) : gardez un test qui **affirme** votre `shrinkWrap` actuel — il
rougira le jour où vous adopterez `bodyFit`, et vous désignera les lignes à retirer.

## 4. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump des 38 versions et des contraintes.

`zcrud_core` **1394** (+14) · `zcrud_select` **83** (+54) · `zcrud_navigation` **144** (+31) ·
`zcrud_get` 119 · `zcrud_study` 1521 · `example` 97. **0 erreur, 0 avertissement.**
CORE OUT = 0 intact, `SmartSelect`/`S2*` toujours confinés sous `lib/src/` (greps montrés).

**R3 — 55 injections sur trois lots, toutes rouges d'ASSERTION** ; sha256 avant **et** après chaque
pas, restauration par copie, résidus : greps négatifs montrés.

🟢 **Sept gardes trouvées inertes et corrigées par les agents sur leur PROPRE travail** :
* quatre **tautologiques** — elles comparaient le rendu à la constante **qui le produit**, donc
  changer la référence changeait les deux côtés de l'égalité ;
* une **vacante par contrainte non liante** — le plancher de 48 dp était mesuré sur un `ListTile`
  dont la hauteur intrinsèque dépasse déjà 48, donc le plancher n'était jamais liant ;
* une où **deux clamps se masquaient l'un l'autre** — et comme le résolveur est public, un hôte
  aurait lu **12 dp** au lieu du plancher ;
* une gardée sur **une seule des deux branches** (`.single`/`.multiple` sont deux sites distincts).

🟢 Et **un script R3 arrêté de lui-même** (`exit 2`) sur un motif d'injection ambigu — consigne
respectée plutôt que contournée.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 5. Non couvert

* Les trois seams refusés (`modalActionsBuilder`, `onModalWillOpen/Open`, `modalBuilder`) : leur
  **effet** est livré, leur **forme injectable** ne l'est pas. Dites-nous si vous en avez besoin
  comme points d'extension.
* La détection du corps non borné est **post-mortem** et vit sous `assert` : rien en release.
* Un nœud transparent s'ajoute à l'arbre du chrome en régime `intrinsic` — aucun étalon ne
  l'épinglait, mais c'est un changement réel.
* Le mode `page` est le seul couvert **de bout en bout** par la garde de défilement.
* Dettes antérieures : cf. v0.60.0 (dont ses **quatre axes visibles**) et v0.60.1.
