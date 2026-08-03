# Handoff **v0.34.0** — CR-IFFD-40 : la navigation de fratrie ne perd plus le « où suis-je »

> **Tag à épingler : `v0.34.0`** · **aucune rupture d'API** — mais **changement de comportement
> par défaut** sur écran étroit. Lisez le § 3 : il vous concerne peut-être sans que vous l'ayez demandé.

---

## 1. Ce qui change

Sur écran étroit, la navigation entre sous-dossiers n'est plus une **rangée horizontale défilante**
mais une **barre de sélection** : une seule ligne pleine largeur qui montre **l'élément courant**,
avec un chevron visible ; la fratrie ne se déploie **qu'à la demande**.

**Votre diagnostic était juste, et votre méthode aussi.** Vous avez d'abord cru à un défaut de
troncature, vous avez **vérifié en balayant**, et vous avez corrigé votre propre constat avant
d'émettre : rien n'était inaccessible, c'est **la perte de l'état courant** qui était le défaut.
C'est ce que nous avons corrigé — pas la troncature.

## 2. 🔴 L'arbitrage que vous nous laissiez — et pourquoi aucune de vos trois voies n'a été prise telle quelle

Vous demandiez **(1) remplacer `compact`**, en acceptant **(2) ajouter et changer le défaut**.
Nous avons livré **l'effet de (2)** — le défaut disparaît partout, un retour arrière tient en une
ligne — mais **pas par une troisième valeur d'énumération**, et la raison vous concerne :

> Le dartdoc de `ZSubfolderLayoutMode` **recommande un `switch` exhaustif**, et l'un de vos propres
> tests en exerce un **à deux bras**. Une troisième valeur aurait fait **cesser de compiler** tout
> hôte suivant ce patron. C'eût été une rupture réelle, déguisée en ajout.

D'où **deux axes, deux types** : `ZSubfolderLayoutMode` décrit les **contraintes de layout de
l'item** ; le nouveau `ZSubfolderNarrowMode` décrit **quelle surface**. La nouvelle barre pose
elle aussi `ZSubfolderLayoutMode.compact`, donc **votre `itemBuilder` existant rend à l'identique**.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** (vous subissiez le défileur) | **rien** — vous obtenez la barre, et le défaut disparaît |
| 🔴 **hôte ayant COMPENSÉ** | **retirez votre compensation** : elle s'**ajoute** à la barre |
| vous préférez l'ancien rendu | `narrowMode: ZSubfolderNarrowMode.compact` — **une ligne**, comportement d'avant à l'identique (garde de non-régression dédiée) |

**Compensations connues à retirer, nommément** : un **défilement automatique** vers la puce active ;
un **en-tête maison** rappelant le sous-dossier courant au-dessus de la barre ; un `itemBuilder` qui
**grossissait** la puce sélectionnée pour la rendre repérable. Les trois deviennent redondants — et
le deuxième afficherait l'information **deux fois**.

⚠️ C'est la quatrième fois que nous insistons sur ce point dans un handoff, parce que nous l'avons
manqué trois fois : *« rien à faire » ne veut pas dire la même chose pour un hôte passif et pour un
hôte qui compensait.*

## 4. 🔵 Au-delà de votre demande — la lacune que vous avez nommée sans la demander

Vous écriviez : *« `itemBuilder` construit un ÉLÉMENT, pas le conteneur — il ne permet donc pas de
substituer la surface »*. **C'était la cause racine** : sans point de substitution de surface, chaque
nouveau besoin exige une nouvelle valeur d'énumération **de notre part**.

Nous avons donc ajouté **`ZSubfolderNavRenderer`**, sur le patron exact de nos seams éprouvés :
chaîne **totale** qui ne lève jamais, `null` = « garde la surface du socle », et **sans coquille
injectée, rendu strictement inchangé**.

Une propriété a été conçue pour vous : la requête neutre porte **la fabrique d'élément du socle**.
Une coquille tierce **ne peut pas perdre le seam d'élément** — elle ne peut que le rappeler.

C'est ce qui répond à votre observation générique : chapitres, étapes, onglets, filtres — *« la
question de l'utilisateur est "lequel est actif ?" avant "lesquels existent ?" »*.

## 5. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_study` **831 tests** (804 → +27), **0 error, 0 warning**.

**18 injections R3, 18 rouges d'assertion**, aucun rouge de compilation.

🟢 **Un angle mort trouvé et corrigé en cours de route**, que nous signalons parce qu'il illustre la
limite de l'exercice : vider le libellé **annoncé** n'a fait rougir que la garde d'accessibilité —
les gardes « repli affiché » et « jamais un vide » restaient **vertes**, le texte rendu venant d'un
autre chemin. Une seconde injection, visant le libellé **affiché**, a fait tomber les trois. *Sans ce
second passage, trois gardes se seraient contentées de bien mesurer à côté.*

⚠️ Notre CI reste à l'arrêt (facturation) : ces chiffres sont des vérifications **locales**.

## 6. 🟢 Tripwire recommandé

Si vous compensiez, gardez un test qui **affirme votre compensation** — par exemple que votre
en-tête maison affiche le sous-dossier courant. Il rougira à l'adoption de `v0.34.0` et vous
désignera le doublon, au lieu de vous laisser découvrir l'information affichée deux fois.

## 7. Ce que nous savons ne pas avoir couvert

* **Le seam de surface ne couvre pas la sidebar** (≥ 600 dp) : il est posé sur la seule surface
  étroite. L'étendre reste additif.
* **Le panneau déployé n'est pas virtualisé au sens strict** (liste paresseuse sous une hauteur
  bornée) : correct pour une fratrie de dossiers, à revoir si vous y branchez des centaines d'entrées.
* **Aucune mesure sur appareil réel** de notre côté — tout est mesuré en test widget à 500×800 et
  autour du seuil de 600 dp. Votre QA sur appareil reste la seule preuve d'usage.
* La garde « ouvrir la fratrie ne reconstruit pas le corps » est **structurellement vraie** mais peu
  mordante : elle attrapera une régression d'architecture, pas une régression locale.
