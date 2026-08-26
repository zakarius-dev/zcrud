# Handoff v3.22.0 — la fusion qui évite la perte, et trois CR de l'hôte

> **Date** : 2026-08-26. **Portée** : `zcrud_screen`, `zcrud_firestore`, `zcrud_markdown`,
> `zcrud_document`, `zcrud_core`, `zcrud_select`.
> **Traite** : CR-IFFD-114, 115, 116, 121 · CR-IFFD-120 **rouverte de notre initiative** · deux
> manques établis par l'état des lieux de migration (fusion sur les valeurs initiales, natures
> d'annotation).

## 1. Le défaut principal : un chemin de perte de données

Trois briques, chacune correcte isolément, formaient ensemble un chemin de destruction :

1. La projection des valeurs d'un formulaire part d'une carte **vide** et n'itère que sur les champs
   **déclarés**, en sautant ceux en lecture seule et ceux qu'une condition masque.
2. `presentFormEdition` rendait cette projection, et n'offrait **aucun** canal fusionnant.
3. L'écriture Firestore est un **écrasement total** — sa propre documentation le dit : `batch.set`,
   jamais un merge.

Enchaînées, elles font qu'un écran porté qui enregistre réécrit son document **amputé de toutes ses
clés non déclarées**. Mesuré côté hôte : un document d'étude perd son identifiant et ses deux clés
de rattachement ; un examen perd **cinq clés sur neuf, dont son identifiant** — une mise à jour
devient une création. **Douze fichiers** de l'hôte empruntent ce chemin.

Le défaut n'est dans aucune des trois briques : il est à leur jointure. C'est pourquoi aucune garde
ne le voyait.

## 2. Ce que le socle livre

**Deux canaux opt-in, jamais un défaut changé** — `preserveInitialValues` sur la présentation d'un
formulaire, `saveMerging()` sur le dépôt. Un hôte passif obtient le comportement d'aujourd'hui à
l'octet : sans l'option, c'est **la même instance** qui est rendue, sans copie ni réordonnancement
de clés ; côté Firestore, la voie historique passe `null` et non un `SetOptions(merge: false)`.

**Un champ en lecture seule est conservé** par le mode fusionnant. La carte étant destinée à être
réécrite en entier, un `readOnly` disparu serait effacé du document alors que personne ne l'a
touché — le défaut visé, simplement déplacé d'un cran.

**Les trois CR ouvertes de l'hôte**, toutes additives et à rendu inchangé par défaut : retour à la
ligne souple déclarable, largeur de tableau déclarable, sous-titre du dialogue plein écran.

**La teinte dynamique du déclencheur de sélection**, active par défaut, conformément à la demande :
bordure teintée et épaissie, ornement plus dense dès que le champ porte une valeur.

**Trois natures d'annotation** — souligné, barré, ondulé — en queue d'énumération, avec une apparence
canonique par nature.

## 3. Ce qui change pour un hôte

- **Fusion** — hôte passif : **rien ne change**, prouvé par des gardes d'inertie qui rejouent
  l'appel d'avant-lot sans le paramètre. Hôte ayant **compensé** par une fusion maison : sa
  compensation reste correcte mais devient du **code mort qui masque le témoin** — il ne verra plus
  si l'option est réellement posée. La retirer, et garder un tripwire assertant la présence de
  l'identifiant dans la carte rendue.
- 🔴 **Teinte de sélection** — hôte **sans** résolveur de teinte : rien ne change, et pas par
  convention : le dernier maillon de l'état renseigné **est le duo de repos lui-même**, si bien que
  l'épaisseur ne peut pas bouger seule. Hôte **avec** résolveur : le rendu change, c'est voulu, et
  poser les jetons d'état aux valeurs de repos rétablit le rendu statique. Hôte ayant **compensé**
  en figeant son état au repos : sa compensation **s'additionne**.
- 🔴 **Annotations** — un hôte qui montait la barre d'annotation voit ses outils passer de **deux à
  cinq** sans avoir touché son code. Le paramètre `kinds:` fige le jeu ; à défaut, fournir les
  libellés de localisation, faute de quoi les boutons affichent les noms bruts. Un hôte qui
  persistait sa nature **à côté** du champ de nature a désormais un doublon qui peut diverger.
- ⚠️ **Largeur de tableau** — poser le mode a **deux effets au-delà du débordement** : les petits
  tableaux cessent de s'étirer, et le texte ne se replie plus en cellule. La première documentation
  du canal le niait ; elle a été corrigée après mesure.
- 🔴 **Extension de notre initiative, invisible depuis la lecture des CR** : le **forçage de la
  présentation plein cadre** répond à une CR que l'hôte avait **retirée avant émission**, en
  écrivant « nous ne le demandons pas ». Son retrait était fondé sur la partie qu'il avait
  vérifiée — le champ est bien public et exporté — mais le point d'entrée ergonomique ne permettait
  pas de **forcer** la présentation, seulement de la subir. C'est désormais possible, et `null`
  conserve la décision automatique par la largeur.

## 4. Vérification

Rejouée par l'orchestrateur, tous les lots au repos.

| Paquet | Tests |
|---|---|
| `zcrud_core` | **2 554** |
| `zcrud_firestore` | **821** |
| `zcrud_markdown` | **655** |
| `zcrud_screen` | **370** |
| `zcrud_document` | **267** |
| `zcrud_select` | **184** |

`melos run generate` : 0 `.g.dart` modifié · `melos run analyze` repo-wide : RC=0 ·
`melos run verify` (12 gates) : RC=0 · balayage des **41 paquets** : **40 verts** (`zcrud_generator` rouge **environnemental** de signature inchangée) · résidus
d'injection R3 : **0**.

**Discipline R3** : 3 + 2 + 11 + 11 + 15 injections selon les lots, toutes rouges **par assertion**,
restauration par copie, sha256 identiques, grep négatif montré.

## 5. Ce que la mesure a corrigé en cours de route

- **Une garde avait tort, et c'est elle qui a été corrigée.** Elle assertait qu'aucune couleur de
  décoration n'existait pour les natures d'annotation sans trait — or le thème en porte une, qu'une
  copie ne peut effacer. Elle mesurait donc **le thème et non le rendu**, et serait restée verte si
  le socle avait teinté toutes les natures indistinctement.
- **Une injection R3 a échoué la discipline** : elle rougissait par erreur de recherche de widget et
  non par assertion. Les gardes concernées ont été durcies, puis l'injection rejouée.
- **Un réglage avait un angle mort d'une espace de large** : le retour à la ligne souple a deux
  chemins, et ne traiter que le premier laissait passer le reliquat.
- **Une affirmation d'absence de l'orchestrateur était fausse** : conclue d'une fenêtre de lecture
  tronquée d'une ligne, sans le grep négatif que ce dépôt exige. La conclusion tenait — le forçage
  manquait — mais le raisonnement était faux, et l'agent l'a démontré.
