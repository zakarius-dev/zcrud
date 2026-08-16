# Handoff **v1.3.0** — l'écran assemblé dit enfin ce qu'il liste

> **Tag à épingler : `v1.3.0`** — débloque le **dernier écran du parc**, refusé deux fois.
> Paquet porteur : **`zcrud_screen`** uniquement (`zcrud_core` : diff vide).
> Release **strictement additive** : un écran qui ne lit rien est inchangé.

---

## 1. Le manque

Sur la voie `items`, vous déteniez la liste : ce que vous imprimez et ce que le socle rend sont
**la même variable, au même instant**. Sur la voie `repository`, ce lien se coupait — le
contrôleur lisait, filtrait, cherchait, triait, paginait, et **rien ne revenait**. Le seul
recours était de relire en parallèle : deux lectures, deux instants, deux règles à tenir
d'accord.

Votre argument sur la gravité a emporté la décision : la sortie de cet écran est un **PDF signé,
imprimé et diffusé**. Un export qui contredit la liste qu'il prétend imprimer **quitte l'écran et
circule** — il devient une pièce que plus personne ne rapprochera de sa source. Refuser la
bascule deux fois plutôt que de l'accepter « en attendant » était le bon choix.

Et votre analyse de l'alternative applicative était juste : adosser exports et statistiques à une
lecture partagée ne tient pas, parce que la recherche, le tri demandé et la page courante sont
des **états vivants du contrôleur** qu'aucune déclaration ne rejoue.

## 2. Ce qui est livré — la publication de ce qui existait

Vous écriviez : *« nous ne demandons pas un mécanisme, nous demandons de rendre public celui qui
existe »*. C'est exactement ce qui a été fait — aucun mécanisme neuf, la publication de
`_rowsInView` / `_exportRows()` résolus par l'index d'entités déjà tenu par l'écran.

Sur `ZCrudScreenActions`, accessible par `ZCrudScreenScope.maybeOf(context)` :

| Membre | Sens |
|---|---|
| `List<ZEntity> get entitiesInView` | ce qui est listé, à l'instant de la lecture |
| `ValueListenable<List<ZEntity>> get entitiesInViewListenable` | la même chose, notifiée |
| `List<ZEntity> get entitiesSelectedOrInView` | la règle de l'export intégré : la sélection l'emporte quand elle porte |

Type `ZEntity`, **aucun générique introduit** — comme vous le demandiez, et comme le fait déjà
`canOpenEdition(ZEntity)`.

**Garanties** : ordre **peint** (tri appliqué), portée respectée (vivants ou corbeille), onglet
**actif** en mode onglets, **pages chargées comprises** — la définition même qu'emploie l'export
intégré. Écran vidé ⇒ lecture **vide**, jamais le rendu précédent.

**Non-garanties, dites explicitement** : ce n'est ni un flux de données, ni une prise sur le
contrôleur. `ZListController` reste privé — vous demandiez « une lecture, jamais une prise ».

## 3. La lecture notifiée ne coûte rien à l'affichage

Trois propriétés, chacune mesurée plutôt que supposée : le notifieur n'est **créé qu'au premier
accès** (personne ne lit ⇒ rien n'est publié) ; la publication a lieu **en fin de trame**, car
le relevé se fait pendant la construction du listing et notifier là déclencherait une demande de
reconstruction en pleine construction ; et la comparaison porte sur le **contenu**, si bien qu'un
rendu qui refabrique la même liste n'émet rien.

Preuve : deux écrans identiques, même scénario, seul écart l'abonnement — **4 constructions dans
les deux cas**, au repos comme après une recherche.

## 4. Impact sur votre code

- **Hôte passif** : rien à faire.
- **Hôte ayant compensé** — c'est votre cas : votre **relecture parallèle devient inutile**. Et
  attention, **vos chiffres peuvent changer** en migrant : cette relecture ignorait la recherche
  plein texte et la page courante. C'est précisément le défaut que vous décriviez ; l'écart que
  vous constaterez est la mesure de ce qu'il coûtait.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets).
`zcrud_screen` : analyze RC=0 strict, **288** tests (baseline 267, +21). `zcrud_core` non touché
(diff vide), donc non rejoué.

Votre critère principal est gardé littéralement : dans le **même test**, le nombre d'entités lues
est comparé au nombre de lignes **réellement peintes**, puis les deux suites d'identités — sur un
listing nu, avec filtre permanent, avec post-filtre, avec pagination. Sous injection, la garde
rend `entités lues (3) ≠ lignes rendues (2)`.

Huit injections R3, toutes rouges par assertion. L'une mérite d'être signalée : conserver un
relevé **périmé** quand l'écran n'est plus en état de rendu n'était vu par **aucune** garde
d'export préexistante — le trou est désormais couvert.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
constitue la ligne de défense de cette release.
