# Handoff **v0.39.0** — la classe « premier plan qui n'atteint pas les slots » est fermée

> **Tag à épingler : `v0.39.0`** · aucune rupture d'API.
> 🔴 **Changement de rendu réel** si l'un de vos slots se style **depuis le thème** — et c'est le
> correctif. Lisez le § 2 : il distingue votre cas.

---

## 1. Ce qui est livré

**`ZForegroundOverride`** — une primitive de `zcrud_core` qui **impose une couleur de premier plan**
(texte **et** icônes) **sans peindre de fond**. Elle ferme les **trois** chemins d'un coup :
`ThemeData.textTheme`, `ThemeData.iconTheme`, et les deux enveloppes d'héritage.

`ZInvertedSurface` (livré en `v0.37.0`) **la consomme** désormais : son corps ne contient plus aucune
enveloppe propre. **L'inversion est un cas particulier de la primitive** — plus deux mécanismes qui
divergeraient. Signature et comportement inchangés.

Les deux composants qui portaient encore l'ancien duo sont migrés : **`ZCountBadge`** (et
`ZCountBadgeRow`, qui l'instancie) et les tuiles de **`ZFlashcardListView`** (slot de contenu).

## 2. 🔴 Votre ligne — quatre cas, et un seul change quelque chose

| Vous êtes… | Ce qui se passe |
|---|---|
| **hôte passif** — slot nu (`Text('x')`, `Icon(...)`), ou aucun slot injecté | **rendu strictement inchangé**. Rien à faire. Couleur **et** taille de glyphe vérifiées identiques |
| 🔴 **votre slot lit le thème** — `Theme.of(context).textTheme.*` ou `…iconTheme.color` | **le rendu change, et c'est le correctif** : votre contenu était peint dans la couleur **ambiante** au lieu du premier plan du composant — contraste faux sur le badge, couleur incohérente sur la tuile |
| 🔴 **vous COMPENSIEZ** — couleur forcée en dur dans le builder, ou enveloppe posée par vos soins autour de l'icône injectée | **retirez la compensation** : elle s'additionne au correctif et peut désormais **surcharger** la couleur voulue |
| **votre slot est un widget déjà construit** avec une couleur figée dans ses arguments | ⚠️ **aucune enveloppe ne peut l'atteindre** — la couleur est gelée. Passez un `Builder`, ou une icône nue |

🟢 **Tripwire recommandé** : si vous compensiez, gardez un test qui **affirme la perte**. Il rougira à
l'adoption et vous désignera le doublon.

## 3. 🔴 Le correctif que personne n'avait anticipé — et que la garde a trouvé

Envelopper le **résultat** d'un slot ne corrigeait **rien**.

Le slot de contenu est un **builder**, invoqué avec le contexte de la tuile — donc **au-dessus** de
l'enveloppe. Sa résolution du thème restait **ambiante**. Il a fallu invoquer le builder **à
l'intérieur**.

⇒ **La primitive seule ne suffit pas** : il faut aussi que le builder soit invoqué **sous** elle. Une
injection dédiée le prouve — retirer ce seul détail suffit à ramener le défaut, enveloppe intacte.

## 4. 🔵 Le verrou structurel est enfin posé

Le lot `v0.37.0` avait écarté cette garde en le disant franchement : *« elle aurait rougi sur les deux
sites légitimes »*. **Ces deux sites étant migrés, l'obstacle est tombé.**

Une garde de source balaie désormais **tous** les paquets et interdit qu'un futur auteur repose une
enveloppe **colorée** hors de la primitive — rejouant le défaut une quatrième fois.

Elle distingue la **couleur** du reste : un ajustement de **taille**, de **graisse** ou de
**décoration** reste légitime. Vérifié — les **5** sites restants du dépôt sont tous verts, aucun ne
porte de couleur. Et elle porte trois volets de sûreté : discrimination sur témoins, **non-vacuité**
(un détecteur cassé rougit au lieu de passer vert à vide), et anti-régression de sa propre exemption.

## 5. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_core` **1151** (+6) · `zcrud_study` **896** (+5) · **0 error, 0 warning**.

**6 injections R3**, toutes qualifiées — dont un **contrôle de non-sur-détection** sur un fichier
réel (ajouter une propriété non colorée à un site légitime doit rester **vert**).

🟢 **Deux gardes de nous trouvées vertes-pour-rien** :
* l'une était **vacuelle par construction** — le repli de thème fixait la couleur attendue à
  **exactement la couleur ambiante** : elle aurait été verte quel que soit le code. Le harnais
  installe désormais une couleur **dérivée**, avec contrôle de non-vacuité avant chaque mesure ;
* l'autre mesurait un builder servant **deux** sites avec une clé fixe : elle n'en couvrait qu'un
  **tout en paraissant les couvrir**.

Et sous les injections principales, les gardes « slot **nu** » sont restées **vertes** : c'est la
preuve directe qu'un hôte passif ne bouge pas — pas un vert par accident.

⚠️ Notre CI reste à l'arrêt (facturation) : ces chiffres sont des vérifications **locales**.

## 6. Ce que nous savons ne pas avoir couvert

* 🔴 **Le `Builder` obligatoire n'est pas verrouillé.** Rien n'empêche un futur auteur d'invoquer un
  builder **au-dessus** de la primitive — le défaut exact du § 3. Une garde de source le détecterait
  mal (il faudrait typer l'expression). Seules les gardes de rendu, **site par site**, l'attrapent.
  **C'est la principale exposition restante de cette classe.**
* **Un slot pré-construit** avec une couleur figée dans ses arguments : non corrigeable par
  construction.
* **Composants Material résolvant depuis le `ColorScheme`** (boutons, `Chip`, champs) : hors
  couverture **par choix** — les recolorer détournerait vos cartes et vos états d'erreur. Limite
  **mesurée** par un test, pas supposée.
* **La garde de source est aveugle aux styles opaques** : une enveloppe dont le style est un
  identifiant portant une couleur n'est pas détectable statiquement.
* `zcrud_flashcard` et `zcrud_ui_kit` ont été **lus, pas modifiés** : la garde les balaie et les
  trouve propres, mais aucune garde de **rendu** n'y existe pour un futur site coloré.
