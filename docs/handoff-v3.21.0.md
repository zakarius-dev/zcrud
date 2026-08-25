# Handoff v3.21.0 — le champ compact ressemble enfin à ce qu'il doit être

> **Date** : 2026-08-25. **Portée** : `zcrud_markdown`, `zcrud_core`.
> **Origine** : décision du propriétaire — *« le socle doit offrir un chrome et une configuration de
> barre par défaut, de sorte à ressembler à ce dont dispose le legacy, tel que la migration l'a
> répliqué »*.

## 1. Les défauts

**① Le socle avait les canaux, et aucun défaut.** Le chrome du champ rich-text compact existait,
son fichier de référence aussi — mais la dartdoc promettait « aucun chrome déclaré ⇒ rendu
strictement inchangé », donc une boîte bordée nue. Chaque hôte devait écrire son propre habillage.

**② Deux hôtes écrivaient spontanément le même bloc.** Mesuré : la configuration de barre est
**identique à l'octet** entre les deux applications, l'une l'ayant posée après avoir vu l'autre le
faire. Deux hôtes qui écrivent la même ligne, c'est la définition d'un défaut manquant.

**③ Le drapeau qu'ils posaient tous les deux était mort.** `themedBarBackground` ne changeait
**0 pixel sur 1 823 500** en affichage sur une seule ligne — le mode dans lequel la barre de
formulaire est **toujours** rendue. Quill peint son propre conteneur aux bornes exactes de la
décoration du socle, et **après** elle : fond et liseré bas recouverts. Les sept tests qui citaient
ce drapeau montaient un carré de 10 dp à la place de la vraie barre : ils seraient restés verts si
le défaut avait persisté.

**④ Aucun préréglage ne reproduisait la barre du legacy** : le socle avait traduit le *préréglage
déclaré* du legacy, pas son *rendu*. Et sa géométrie n'était pas exprimable — hauteur figée à
67,2 dp contre 42 dp, sur des formulaires portant jusqu'à quatre éditeurs.

**⑤ Le chrome posait quatre libellés français en dur**, alors que le paquet n'utilisait pas la
localisation du socle. Activer le défaut sans les localiser aurait exposé ces littéraux à tous les
consommateurs : la localisation était un préalable, pas un raffinement.

## 2. Ce que le socle livre

Le champ compact a désormais **un chrome et une barre par défaut** — carte, en-tête, barre habillée
à fleur — sans qu'un hôte n'écrive quoi que ce soit, tout restant remplaçable par paramètre et par
jeton. Le préréglage `inline` porte les seize boutons du legacy, dans leur ordre, groupés comme lui,
sans ceux qu'il n'a pas ; un préréglage est une **donnée**, jamais un comportement. La géométrie de
barre s'exprime enfin (séparateurs, taille et couleur d'icône, facteur de bouton, hauteur). Les
quatre libellés vivent dans les deux tables de localisation, et la garde de couverture des clés
balaie désormais ce paquet, qui lui échappait.

**Le drapeau est vivant, et une garde l'asserte au pixel** : défaut posé ⇒ la bande de fond et le
liseré portent les couleurs attendues ; drapeau éteint ⇒ la couleur du châssis. C'est la première
garde de ce paquet à mesurer une couleur peinte.

**Le paquet a enfin une garde de source** — il n'en avait aucune. Elle encadre le fichier de
référence et **déclare** ce qu'elle ne couvre pas encore, au lieu de le prétendre couvert.

## 3. Ce qui change pour un hôte

- 🔴 **Hôte passif : son rendu CHANGE.** C'est l'objet de la version, et c'est voulu.
- 🔴 **Hôte francophone qui ne monte pas le delegate de localisation : il verra l'ANGLAIS** là où le
  paquet écrivait le français en dur. C'est le point le plus susceptible d'être découvert en
  production. Remède : monter le delegate, ou passer ses propres libellés.
- **Ce que les deux hôtes peuvent supprimer** : le bloc de configuration de barre (cinq lignes,
  identiques à l'octet entre eux) et la ligne d'icône. Restent trois lignes — leurs couleurs de
  signature, que le socle ne code pas. ⚠️ **La suppression n'est pas inerte** : la barre perd
  citation, bloc de code, lien, image et vidéo, gagne les retraits, et le plein écran retrouve le
  préréglage complet. À regarder avant de supprimer.
- **Hôte ayant compensé** par son propre habillage de carte ou d'en-tête : sa compensation
  **s'additionne** au défaut. La retirer d'abord.

## 4. Ce qui n'est PAS fait, dit sans maquillage

- **La hauteur de 42 dp du legacy n'est pas adoptée en défaut** : les boutons portent le plancher
  interactif de 48 dp, que la forcer rognerait. Le jeton `barHeight` est exposé, avec cet
  avertissement.
- **L'alignement d'icône n'est volontairement pas exposé** : il est inerte en une rangée. L'exposer
  aurait rejoué exactement le défaut que cette version corrige.
- Non traités : opacités distinctes clair/sombre, pilule à icône seule et son état désactivé,
  pastille de plein écran dans l'en-tête, teinte de l'icône d'en-tête, ombre de pilule, marge de
  carte, formules de hauteur. Les autres libellés en dur du paquet (menus de tableau, dialogue de
  formule) sont hors lot — et la garde de source le **déclare**.

## 5. Vérification

Rejouée par l'orchestrateur, lot au repos.

| Contrôle | Résultat |
|---|---|
| `zcrud_markdown` | **623 tests verts** (597 + 26) |
| `zcrud_core` | **2 544 tests verts** |
| Paquets dépendants | verts |
| `melos run generate` | SUCCESS — 0 `.g.dart` modifié |
| `melos run analyze` repo-wide | RC=0 |
| `melos run verify` (12 gates) | RC=0, avant **et** après le bump |
| Balayage des **41 paquets** | **40 verts** ; `zcrud_generator` rouge **environnemental** de signature inchangée |

**Discipline R3** : 16 injections rouges **par assertion**, sha256 identiques, 0 résidu — et **deux
tentatives invalides consignées telles quelles**, qui rendaient vert parce que l'injection ratait sa
cible et non parce que la garde était faible. Les distinguer est le cœur du procédé.

## 6. Ce que le lot a introduit puis corrigé — et qui l'a vu

Deux défauts ont été **introduits par ce lot** et **attrapés par des gardes existantes** :

1. **Le codec entrait dans le chemin chaud de frappe** — cent appels pour cent caractères. C'est
   exactement ce que l'objectif produit n°1 interdit, et c'est la garde de rebuild granulaire qui
   l'a arrêté. Corrigé **sans toucher au test**.
2. **`showLabel: false` devenait inopérant** : le libellé n'était rendu que si aucun chrome n'était
   présent — condition rendue injoignable par l'activation du défaut. Le drapeau gouverne désormais
   aussi l'en-tête du chrome.

Quatre tests assertaient le contrat que cette version change délibérément. Ils ont été **relevés**,
avec leur justification écrite dans le code — jamais affaiblis : le plus sensible continue
d'asserter « un seul cadre », contre la nouvelle valeur attendue, et sa ligne de base « sans
chrome » reste couverte par les cas où le chrome demeure un paramètre.
