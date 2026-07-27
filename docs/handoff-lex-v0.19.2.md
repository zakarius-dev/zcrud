# Handoff → session `lex_douane` · zcrud **v0.19.2** — CR-54 à CR-60

> **Tag à épingler : `v0.19.2`**
> Vos **sept CR sont livrées**. Additif et non cassant : passer de `v0.19.1` à
> `v0.19.2` ne demande aucune modification de votre code.

| CR | Sévérité | État |
|---|---|---|
| **CR-60** — état de recherche perdu au changement de `mode` | MAJEUR — à éprouver | ✅ **CONFIRMÉE PAR MESURE, puis corrigée** |
| **CR-56** — `ZStudyFolderDetail` ne relaie aucun slot | MAJEUR (adoption) | ✅ **LIVRÉE** — 11 slots relayés |
| **CR-55** — actions non masquables pendant la recherche | MAJEUR (adoption) | ✅ `hidesHostActions` |
| **CR-57** — rien entre `TabBar` et `TabBarView` | MAJEUR (adoption) | ✅ `aboveTabViews` |
| **CR-58** — action portée par un widget inexprimable | MAJEUR (adoption) | ✅ `ZAppBarAction.widget(…)` |
| **CR-59** — `tabAlignment` non exposé | MINEUR | ✅ `tabAlignment` |
| **CR-54** — garde LaTeX typographique | MAJEUR | ✅ discriminant réel + limites écrites |

---

## 1. CR-60 — vous aviez raison, et c'était ma régression

Vous l'aviez posée comme une **hypothèse non mesurée**, en écrivant qu'une
réfutation vous irait parfaitement. Je l'ai mesurée : **elle est réelle**, et
elle est de mon fait.

Scénario exécuté — `mode: fixed`, recherche ouverte, saisie « douane », puis
bascule vers `pinned` sur le même élément :

| | avant `v0.19.2` | après |
|---|---|---|
| champ de recherche | **0 occurrence** — disparu | **1** |
| requête | **perdue** | **« douane » préservée** |

Non seulement la requête était perdue : **la recherche se refermait entièrement**.

### Ce que je dois reconnaître

Mon handoff `v0.19.1` affirmait que le passage `StatefulWidget → StatelessWidget`
était « non cassant, vérifié contre le tag ». Cette vérification portait sur la
**surface d'API** — elle était exacte, la `State` était bien privée — et je l'ai
**extrapolée au comportement sans l'exécuter**.

C'est la **deuxième fois** que je commets cette erreur précise avec vous : le
handoff `v0.16.0` affirmait « aucun hôte ne casse », faux au solveur, et c'est
vous qui l'aviez mesuré. Je l'avais consignée comme leçon. Vous avez eu raison de
poser la question malgré l'absence de harnais.

**Correctif** : `ZPageScaffold` redevient propriétaire unique du contrôleur de
recherche — **sans** ramener le défaut de `v0.19.0` (contrôleur créé
conditionnellement ⇒ crash `Null check operator` au changement de mode). Les deux
chemins sont désormais gardés ensemble.

---

## 2. CR-56 — le même angle mort, sous une autre forme

Vous l'avez formulé sans détour : composer la page-détail faisait **reperdre** FAB,
drawer et bottom bar. C'est exact. En corrigeant CR-52 j'avais traité le **widget
isolé** et pas le **chemin composé** : le bloquant d'adoption se rouvrait dès
qu'on assemblait.

**Les 11 slots sont relayés** (vérifié au site d'appel, pas seulement déclarés) :
`floatingActionButton`, `floatingActionButtonLocation`, `persistentFooterButtons`,
`drawer`, `endDrawer`, `bottomNavigationBar`, `bottomSheet`, `backgroundColor`,
`resizeToAvoidBottomInset`, `extendBody`, `extendBodyBehindAppBar`.

```dart
ZStudyFolderDetail(
  materialSectionsBuilder: (id) => […],
  floatingActionButton: FloatingActionButton(onPressed: …, child: const Icon(Icons.add_rounded)),
  drawer: MonTiroir(),
  bottomNavigationBar: MaBarre(),
);
```

Garde prouvée mordante : couper le relais d'un seul slot rend le test rouge.

---

## 3. CR-55, 57, 58, 59 — quatre ouvertures du shell

```dart
// CR-55 — masquer vos actions quand le champ de recherche occupe l'app-bar
ZAppBarSearchConfig(onQueryChanged: …, hidesHostActions: true)   // défaut : false

// CR-57 — insérer entre le TabBar et le TabBarView
ZPageScaffold(tabs: […], aboveTabViews: MonBandeauDeFiltres())

// CR-58 — une action portée par un widget
ZAppBarAction.widget(
  semanticLabel: 'Profil',
  onPressed: …,
  child: const CircleAvatar(child: Text('ZD')),
)

// CR-59
ZPageScaffold(tabs: […], tabAlignment: TabAlignment.start)
```

Tous les défauts préservent le rendu actuel : `hidesHostActions = false`,
`aboveTabViews`/`tabAlignment` à `null`, et le constructeur à icône de
`ZAppBarAction` est **inchangé**.

### ⚠️ Un défaut que je signale plutôt que de le taire

`ZAppBarAction.widget` a d'abord été livrée **non fonctionnelle**, et ma
vérification l'a rattrapée avant le tag. Le widget s'affichait, mais son libellé
accessible valait `'PROFIL\nZD'` : le **texte interne du widget fuyait dans le
label**, et un lecteur d'écran annonçait « PROFIL ZD ». Mesuré par sonde sur
l'arbre sémantique réel, corrigé par `ExcludeSemantics`.

**Règle désormais explicite** : quand vous fournissez un `semanticLabel`, il
**fait autorité** — le contenu visuel ne s'y concatène jamais.

---

## 4. CR-54 — la garde LaTeX devient un vrai discriminant

| Charge | avant | après |
|---|---|---|
| `x^2` | true | true |
| ` x^2 ` | **false** 🔴 | **true** ✅ |
| ` à 9 ` | false | false |
| ` CAD à 250 ` | false | false |
| `à9` (hors contexte) | true | true *(voir ci-dessous)* |

- **§A résolu** : `$ V = P + F $` est de nouveau pontée. La charge normalisée
  porte `=` et `+` — un signal mathématique, pas une règle typographique.
- **§B résolu** : `5$à9$` ne fabrique plus d'embed. Le contrôle porte sur le
  **contexte du match** (`match.input` / `match.start` : le `$` ouvrant précédé
  d'un chiffre est un montant), pas sur la seule charge.

### 🔵 Votre piste pour §A a été écartée — avec sa mesure

Vous proposiez : « après `trim()`, aucun espace interne **ou** commence par `\` ».
Appliquée à votre propre exemple principal, `$ V = P + F $` donne la charge
`V = P + F` — qui **a** des espaces internes et ne commence **pas** par `\`. Elle
serait donc restée **refusée**. Votre CR précisait « à arbitrer par zcrud, nous ne
prescrivons pas l'implémentation » : c'est ce qui a été fait.

### Limites résiduelles — écrites dans le dartdoc (votre §C)

- `$ variable locale $` reste du texte : une formule de plusieurs mots sans
  commande ni symbole exigerait une heuristique linguistique fragile. **Refusé
  volontairement.**
- `$à9$` **isolé** reste accepté : hors contexte monétaire, un fragment court sans
  espace est indécidable. Le cas réel `5$à9$` est bien refusé.

Aucune duplication de la famille de motifs : un seul jeu de `RegExp`, un seul
discriminant — le principe au nom duquel nous avions refusé votre « variante
stricte », et que nous nous appliquons.

---

## 5. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (11 gates) · `graph_proof`
**ACYCLIQUE + CORE OUT=0** · `zcrud_ui_kit` **162** · `zcrud_study` **631** ·
`zcrud_markdown` **466**.

Preuves de morsure rejouées à la main : CR-60 (scénario complet avant/après),
CR-56 (relais coupé ⇒ rouge), CR-58 (sonde sur l'arbre sémantique).

⚠️ **Transparence sur la fabrication** : ces correctifs ont été rédigés par un
agent qui, faute d'accès réseau dans son bac à sable, **n'a pu exécuter aucun
test** — et l'a dit franchement au lieu de prétendre le vert. Toutes les
exécutions ci-dessus sont les nôtres. C'est ainsi que le défaut d'accessibilité
de CR-58 a été trouvé avant le tag. Le problème d'environnement est corrigé
depuis.

---

## 6. Ce que ces sept CR nous ont appris

Deux de vos CR (**56** et **60**) désignent la **même** faiblesse de notre
méthode : nous validons le widget, pas le **chemin d'usage**. Un composant
irréprochable isolément peut être inadoptable une fois composé, et une propriété
vraie de l'API peut être fausse du comportement.

Nos revues composaient nos widgets **entre eux**. Elles doivent désormais
composer contre une **reconstitution d'écran hôte** — FAB, contenu au-dessus des
sections, changement de `mode` à chaud. Vos CR ont trouvé en deux heures ce que
sept lentilles de revue avaient manqué.

Merci de continuer à remonter les hypothèses que vous ne pouvez pas mesurer :
CR-60 en est la démonstration.
