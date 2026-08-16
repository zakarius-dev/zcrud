# Handoff **v1.4.0** — la consultation redevient une consultation

> **Tag à épingler : `v1.4.0`** — corrige le CR « mode lecture perdu par les builders », enrichi
> en cours de traitement par deux constats d'appareil. Paquet porteur : **`zcrud_core`**.
>
> 🔴 **Rupture visuelle** : une application qui ne déclare rien verra ses fiches de consultation
> changer d'aspect. Retour à l'ancien rendu en une ligne — §4.

---

## 1. Le canal, et pourquoi le recâblage n'aurait pas suffi

Le mode de consultation ne circulait que par le constructeur de champ **par défaut**. Tout
appelant fournissant le sien le remplaçait — quatre sites sur six le perdaient, dont le plus
trompeur : l'assistant à étapes **propageait** bien son drapeau à la surface d'édition, mais
fournissait **aussi** son propre constructeur, qui écrasait le seul chemin capable de le
consommer. Tout paraissait câblé ; le mode retombait à `false` en silence.

Votre diagnostic a décidé de la solution : *« un drapeau qui dépend de ce que chaque builder
pense à recopier se reperdra au prochain builder ajouté — c'est déjà arrivé quatre fois »*. Le
mode descend désormais **par le contexte** (`ZReadModeScope`), et le paramètre explicite reste
prioritaire dans les deux sens.

Conséquence mesurable : les champs profonds — sous-listes dans leurs trois modes, items
dynamiques, étapes — sont atteints **par pur héritage**, sans qu'aucun relais ait été ajouté aux
quatre sites. C'est ce que « structurellement indépendant du builder » veut dire.

**Un piège trouvé en chemin** : la surface d'édition d'une étape **effaçait** la forme héritée en
posant un `null`. Corrigé, et gardé.

## 2. L'incohérence interne que vous avez relevée sur appareil

Vos captures montraient, sur **une seule fiche**, deux champs `text` habillés en saisie et un
`select` en bloc gris. Mesure faite : `select` est **fiche-able** au même titre que `text` — ce
que vous voyiez était donc le symptôme direct du canal manquant, chaque famille rendant son
propre habillage d'**édition**.

Une garde dédiée fige désormais la propriété : sur une même surface en lecture, `text`, `select`,
`dateTime` et `boolean` rendent **le même chrome** — même filet, même hauteur, même style de
libellé, zéro décoration de saisie — et cela **pour chacune des cinq formes** livrées.

## 3. Cinq formes de consultation, déclarables

Le owner a demandé des modes, pas un arbitrage. Hauteurs **mesurées et assertées** :

| Forme | Hauteur | Quand l'employer |
|---|---|---|
| `card` *(défaut)* | **72** | la fiche du socle, entièrement pilotée par les jetons — c'est l'échappatoire de réglage |
| `listTile` | **72** | se fond dans une liste Material existante ; retrouve un moteur legacy bâti sur `ListTile` |
| `definition` | **54** | hiérarchie inversée (libellé discret, valeur dominante) — lecture d'un dossier rempli. Motif *description list* (Tailwind UI, `Descriptions` d'Ant Design) |
| `inlineRow` | **36** | deux colonnes alignées, **la meilleure à l'impression**, repli automatique en empilé sous 360 dp. Motif `Descriptions` bordées / *structured list* d'IBM Carbon |
| `compact` | **28** | panneaux de propriétés — 2,5× plus de champs à l'écran qu'en `card` |

Priorité : **champ > surface > jeton de thème > `card`**. Un seul canal les porte, le même que le
mode de consultation.

**Le mode `card` par défaut reproduit le legacy, prouvé côte à côte** avec un vrai `ListTile`
dans le même test : hauteur 72 == 72, fond transparent, aucun filet, libellé 16/w400, valeur
14/w400 — égalité assertée champ par champ.

**Accessibilité** : la paire libellé/valeur est annoncée dans les cinq formes. Un trou a été
bouché au passage — la valeur n'était annoncée que si elle était **copiable**, donc un champ
affiché mais vide restait muet.

## 4. ⚠️ Ce qui change chez vous

**Rupture visuelle assumée** : sans déclaration, la consultation est désormais **posée à plat**
(92 dp → 72 dp, fond et filet disparus). Pour retrouver l'encadré précédent, une ligne suffit :

```dart
ZcrudTheme(readFillColor: scheme.surfaceContainerLow, readBorderWidth: 1)
```

- **Hôte passif** : vos fiches changent d'aspect — c'est le but pour DODLP, à vérifier pour les
  autres. La ligne ci-dessus restaure l'ancien rendu.
- **Hôte ayant compensé** : si vous recopiiez le drapeau de lecture dans votre propre
  constructeur de champ, ou si vous compensiez la **hauteur** des fiches, retirez ces
  compensations — elles s'ajoutent désormais au socle.
- **Rupture mineure de signature** : le drapeau de champ passe de `bool` à `bool?` (sans effet
  si vous le passiez ; à traiter si vous le *lisiez*).

## 5. Ce qui reste ouvert

Votre second constat d'appareil — la **sous-liste en consultation sur téléphone**, dont les
quatre en-têtes et la ligne sont tronqués au point de ne rien délivrer de lisible — n'est **pas**
traité ici. C'est un défaut de rendu en largeur contrainte, distinct du mode de lecture ; le
diluer dans ce lot aurait mal servi les deux. Il fera l'objet de son propre traitement.

Également ouvert, signalé et hors périmètre : l'écran assemblé ne relaie pas encore le choix de
forme — le jeton de thème couvre le besoin en attendant.

## 6. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets) · `melos run analyze` repo-wide RC=0.
Tests : `zcrud_core` **2152** (+36, aucune retirée), `zcrud_screen` **288**.

Treize injections R3, toutes rouges **par assertion**. Deux méritent d'être citées : l'une
**reproduit exactement votre défaut** (seul `text` rendu en fiche) et fait rougir les cinq gardes
de cohérence ; l'autre a **révélé une garde manquante** — elle est restée verte, ce qui a conduit
à écrire la garde absente avant de la voir rougir. Restaurations par copie vérifiées par
`sha256sum -c` sur six fichiers, résidus prouvés absents.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
constitue la ligne de défense de cette release.
