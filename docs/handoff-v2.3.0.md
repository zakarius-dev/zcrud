# Handoff **v2.3.0** — le rendu riche survit à la consultation

> **Tag à épingler : `v2.3.0`** — suite directe de la v2.1.0. Paquet porteur : **`zcrud_core`**.
> **Rétrocompatible** : un champ sans clé de rendu déclarée est **inchangé**, fiche comprise.

---

## 1. Le défaut, et votre lucidité sur son origine

La v2.1.0 vous a ouvert le canal déclaratif de rendu de choix. Il fonctionnait **en édition** et
disparaissait **en lecture** : la décision de poser une fiche de consultation était une fonction
**pure sur la famille**, sans échappatoire.

Vous l'avez qualifié vous-même — *« c'est notre angle mort, pas une livraison incomplète »*. Le
constat n'en était pas moins juste : votre matrice d'autorisations redevenait, en consultation, une
ligne de texte énumérant des clés, sur le seul écran par lequel l'autorité de l'application se lit.

Et votre refus d'« adapter » vos deux gardes était le bon : *« réécrire une garde pour qu'elle
décrive l'absence de ce qu'elle protégeait, c'est la transformer en témoin de la régression »*.
Elles doivent repasser telles quelles — c'est le critère de cette livraison.

## 2. Ce qui change

Option **A**, la plus petite, celle que vous préfériez :

```dart
_readModeCard =
    readMode && zReadModeCardable(_family) && !hasResolvedChoiceBuilder;
```

La règle reste **inchangée pour tous les champs ordinaires** ; elle cède uniquement là où l'hôte a
explicitement pris la main sur le rendu.

**Aucun canal n'a été ajouté** : votre constructeur de choix recevait déjà le drapeau de lecture
seule, et il est déjà monté sous `ZReadModeScope`. C'est le canal de contexte livré en 1.4.0 — celui
qui répondait à votre CR « mode lecture perdu par les builders » — qui rend ce correctif si petit.
Votre matrice n'a donc rien à changer : elle porte déjà son propre `readOnly`.

## 3. 🔴 Le point que votre CR ne mesurait pas

Votre demande posait une question que vous ne traitiez pas : **ne plus poser de fiche rend-il le
champ modifiable ?** Une matrice d'autorisations **éditable en consultation** serait bien pire que
le défaut signalé.

Vérifié : **non**. La lecture seule est appliquée en amont (`spec.copyWith(readOnly: true)`) et
respectée par la famille en quatre points. Mais nous ne nous en sommes pas tenus au constat — une
propriété de sûreté vérifiée une fois et non gardée est une propriété qui se perdra. Elle est
**gardée**, et l'injection qui la neutralise fait rougir la garde : `Expected: true / Actual:
<false>`.

## 4. Impact sur votre code

- **Hôte passif** : rien à faire. Sans clé déclarée, le rendu de consultation est identique —
  contre-témoin à **compte absolu**, pas une comparaison entre deux rendus passifs.
- **Vous** : rien à changer non plus. Déclarez votre clé comme en édition ; la matrice reparaît en
  consultation, verrouillée. **Vos deux gardes doivent repasser sans retouche** — si l'une d'elles
  résiste, dites-le nous, ce serait notre défaut, pas le vôtre.
- **Défensif** : une clé déclarée mais **absente** du registre replie sur la fiche générique — jamais
  d'écran vide, jamais d'exception.

## 5. Ce que nous n'avons pas fait, et pourquoi

Ni opt-out déclaratif (votre option B), ni famille non fiche-able (votre option C). L'inférence
suffit et n'ajoute **aucun concept** : un champ dont le rendu est déclaré *et résolu* a, par
construction, pris la main. Ajouter un drapeau aurait créé deux façons de dire la même chose, dont
l'une aurait pu contredire l'autre.

## 6. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0 (14 gates, 40 paquets).
`zcrud_core` **2341** tests (base 2337, +4), 11 `info` inchangés.

Quatre injections R3, **toutes rouges par assertion**, restaurées par copie avec sha256 identiques —
vérifié en outre par le périmètre git : le fichier muté par l'injection de sûreté **n'apparaît pas**
comme modifié, donc rien n'y subsiste.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue
la ligne de défense de cette release.
