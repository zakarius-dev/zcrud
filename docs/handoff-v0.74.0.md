# Handoff **v0.74.0** — le texte d'état du booléen, et une annonce qu'on a évité de doubler

> **Tag à épingler : `v0.74.0`** · strictement **additif** — aucune signature cassée, aucun paquet
> nouveau (38). Un hôte qui ne déclare rien ne voit **rien** changer.
> ⚠️ **Une extension au-delà de votre CR** au § 4 — elle est invisible à sa lecture, donc nous la
> signalons.

---

## 1. Le texte d'état, livré — mais activé, pas imposé

Votre constat est exact : le `SwitchListTile` porte le libellé du champ en titre, et **aucun texte
d'état**. Aucune configuration booléenne n'existait.

🔵 **Nous avons inversé votre condition, et c'est important.** Vous demandiez des défauts localisés
« quand l'hôte ne fournit rien » — pris à la lettre, un texte serait apparu chez **tous les hôtes**,
y compris ceux qui n'ont rien demandé. À la place : **l'affichage s'active**, et *une fois activé*
les libellés retombent sur les clés localisées. Vous obtenez vos défauts « Oui / Non », personne
d'autre ne bouge.

🟢 **Aucune clé n'a été créée** : `yes` et `no` existaient déjà, traduites en français et en anglais.

🔵 **L'activation accepte les deux voies** : demander explicitement le texte, **ou** simplement
fournir un libellé. Sans cela, déclarer un libellé personnalisé aurait été **silencieusement
ignoré** — un réglage inerte, ce que la règle de CR-IFFD-78 interdit.

## 2. L'emplacement : une quatrième forme, meilleure que les trois de votre CR

Vos deux suggestions et la variante manuelle ont été **mesurées et écartées** :
* le slot « secondaire » d'un `SwitchListTile` est le côté **début** — mauvais côté ;
* le sous-titre **éloigne** le texte du switch, ce qui affaiblit l'affordance recherchée ;
* une rangée faite main **remplace** le `SwitchListTile`, donc obligerait à réimplémenter la fusion
  sémantique, le tap sur toute la ligne et la hauteur minimale.

Retenu : le texte est injecté **à la fin du titre**, donc immédiatement avant le switch — la position
de votre legacy — **sans changer de widget**. Ordre correct prouvé par coordonnées **en RTL et en
LTR**.

## 3. 🔴 Le vrai risque n'était pas visuel, il était sonore

Un `SwitchListTile` annonce **déjà** son état. Ajouter « Oui / Non » risquait de **doubler
l'annonce**. Mesuré, et le résultat est net :

> sans exclusion : *« …a-t-il été visité ?, **Non**, interrupteur, **désactivé** »* — l'état **deux
> fois**.

Le texte est donc **décoratif**, comme l'astérisque du requis. Et la garde n'est pas complaisante :
le canal natif d'état est mesuré **présent et discriminant** — forcer la valeur contraire la fait
rougir.

## 4. ⚠️ Une extension au-delà de votre CR — signalée parce qu'invisible à sa lecture

🔵 **Le socle rendait DÉJÀ « Oui / Non » dans la fiche de lecture**, via les mêmes clés. L'alignement
imposait donc de garder le texte en lecture seule, et non de l'y supprimer.

Conséquence, qui dépasse ce que votre CR demande : **un hôte qui fournit ses propres libellés les
verra aussi dans la fiche de lecture**, pas seulement sur le switch. C'est cohérent — sans cela, le
switch dirait « ACTIVÉ » et la fiche « Oui » pour la même donnée — mais cela **n'apparaît nulle part
dans votre CR**, donc vous ne l'auriez pas anticipé.

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — sans configuration, le titre reste un texte nu, aucune rangée n'apparaît, la sémantique est intacte. Gardé par deux assertions **structurelles**, pas seulement visuelles |
| **DODLP** | déclarez la configuration booléenne sur vos champs concernés ; les libellés retombent sur « Oui / Non » localisés sans que vous ayez à les écrire |
| **hôte fournissant ses propres libellés** | ⚠️ ils apparaîtront **aussi** dans la fiche de lecture (§ 4) |

## 6. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1655** (+25) · `zcrud_study` 1521 · `zcrud_firestore` 770 · `zcrud_flashcard` 586 ·
`zcrud_markdown` 516 · `zcrud_intl` 202 · `zcrud_select` 135 · `example` 108.
**0 erreur, 0 avertissement.** **Aucune garde existante retouchée.**

**R3 — 11 injections, toutes rouges d'ASSERTION**, sha avant, après et restauré vérifiés,
restauration par copie, résidus : grep négatif montré.

🔴 **Une trouvaille qui dépasse ce lot.** L'agent a voulu moderniser une API de test dépréciée en
suivant le remplaçant que la dépréciation elle-même annonce — et le remplaçant rend le propriétaire
sémantique **nul**. Les trois gardes d'accessibilité échouaient alors par **erreur de type**, pas par
assertion — **y compris celle de l'hôte passif, qui ne dépend d'aucune injection**. Repéré
**uniquement parce que le rouge a été qualifié**. Retour à l'API que trois autres fichiers du dépôt
utilisent déjà, avec le motif écrit sur place.

> C'est la démonstration la plus nette de la semaine que **qualifier un rouge n'est pas une
> formalité** : un rouge de type ressemble à un rouge d'assertion dans un journal, et aurait fait
> passer trois gardes pour mordantes alors qu'elles ne mesuraient plus rien.

🟢 Et une injection a été mordue par une garde de source **préexistante** : la règle directionnelle
d'AD-13 était déjà couverte par le socle, sans qu'il faille l'ajouter.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 7. Non couvert

* Aucun style ni couleur propre au texte d'état — il hérite du titre.
* Aucune propagation à la liste (`zcrud_list`).
* Dettes antérieures : cf. v0.73.0 et les handoffs précédents.
