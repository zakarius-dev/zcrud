# Handoff **v0.28.0** — CR-IFFD-32 à 36

> **Tag à épingler : `v0.28.0`**
> Vos cinq CR sont livrées, dont les **trois marquées bloquantes ou de comportement**.

## 🔴 Impact — lisez d'abord votre ligne

| Vous êtes… | Action |
|---|---|
| **hôte passif** | **rien** — tous les défauts inchangés, aucune golden régénérée |
| **hôte compensant l'absence de sous-titre d'app-bar** (sous-titre glissé dans le `title` via une `Column`, ou dans le `bottom`) | **RETIREZ la compensation** — elle s'additionnerait à `subtitle` |
| **hôte peignant lui-même un `flexibleSpace` dégradé** autour de `ZPageScaffold` | **RETIREZ-le** — `gradientKey` le rend natif |
| **IFFD, sur CR-36** | votre élargissement de surface à 1600×1200 dans `test/w8c/` peut être **retiré** — et son retrait sert de tripwire |

⚠️ **Widgets touchés au-delà de vos cibles** : `ZPageShellBody` a reçu les mêmes slots que
`ZSearchableAppBar` et `ZPageScaffold`. Vous ne le voyiez pas depuis la lecture de CR-34 — c'est
justement pour cela que nous le nommons.

---

## 1. CR-IFFD-36 — le débordement de la barre de lot (défaut de comportement)

`Row` nue à `z_batch_action.dart:147`, dans **`zcrud_core`** — surface transverse. Votre analyse
tenait sur les trois points : ce n'est pas un artefact de test, 800 px est atteignable en usage réel,
et un `RenderFlex overflowed` **coupe** au lieu de dégrader.

Deux mécanismes, **tous deux inactifs tant que la largeur suffit** :
1. le badge compteur devient `Flexible` + ellipse — c'est lui qui absorbe vos 50 px exacts ;
2. sous `LayoutBuilder`, si la largeur ne suffit plus, les dernières actions basculent dans un menu de
   dépassement.

🔵 **Nous avons dû écarter la piste que nous avions nous-mêmes envisagée.** Réutiliser le motif
`isOverflow` de `ZAppBarAction` semblait évident — mais il est **déclaré par l'appelant, pas piloté
par la largeur** : un hôte ne peut pas savoir à quelle largeur sa barre sera rendue. Nous en avons
repris la **présentation** (`more_vert`, `PopupMenuButton`) pour ne pas créer deux ergonomies
divergentes, mais le **déclenchement** est calculé. Aucun import de `zcrud_ui_kit` (AD-1, CORE OUT=0).

`Wrap` écarté : la hauteur de la barre varierait avec la largeur, déplaçant le contenu situé sous
elle. Défilement horizontal écarté : il ne coupe pas, mais rend les actions non découvrables.

A11y : le bouton de dépassement porte un `overflowLabel` optionnel ; à défaut, `PopupMenuButton`
applique lui-même `MaterialLocalizations.showMenuTooltip` — localisé, jamais codé en dur.

---

## 2. CR-IFFD-34 — l'app-bar (votre première CR bloquante)

```dart
ZPageScaffold(
  title: Text(folder.name),
  subtitle: Text(folder.subjectLabel),   // nouveau
  gradientKey: folder.id,                 // nouveau — identité, pas couleur
  …
);
```

**Le sous-titre.** Votre lecture était la bonne et nous la reprenons : trois surfaces, le même motif,
ce n'est plus un oubli ponctuel. Il est désormais couvert partout.

🔵 **Nommé `subtitle`, pas `belowSubtitle`** — et c'est délibéré. Sur les cartes, `belowSubtitle`
nomme une **position relative** : « sous le sous-titre existant ». Une app-bar n'a pas de sous-titre ;
ce slot *est* le sous-titre. Réutiliser l'autre nom aurait désigné une position relative à un élément
absent — soit la 4ᵉ sémantique que vous redoutiez, déguisée en 3ᵉ. **Le nom diffère parce que la
position diffère ; le contrat est identique** (`Widget?`, `null` ⇒ absence structurelle, contenu
opaque).

Mesuré : `AppBar` fusionne la zone titre en un nœud dont le label devient « Titre\nSous-titre » — le
sous-titre **est** annoncé. Le style n'impose que les métriques de `titleSmall` et **ne touche pas la
couleur**, qui reste héritée du `foregroundColor` — sinon le sous-titre deviendrait illisible sur un
en-tête teinté.

**Le dégradé.** Nous exposons `gradientKey: String?`, pas une couleur. Vous passez
`baseGradientColor: folder.color` ; ici l'hôte fournit l'**identité** et son propre resolver la
traduit — donc **la même entité colore sa carte et son en-tête par la même couture et la même clé**
que `ZFolderCardGradientAccent`. Vous aviez raison : il n'y avait rien à concevoir.

⚠️ La chaîne reste **`seam hôte → null`**. `zDerivedGradientResolver` n'est **pas** réintroduit en
repli automatique : sans resolver injecté, le rendu est strictement inchangé. Deux gardes le prouvent
en négatif, dont une observée depuis `zcrud_study`. Clé nulle ou vide ⇒ le resolver n'est **jamais
appelé**.

---

## 3. CR-IFFD-33 — `progressionBuilder`

`WidgetBuilder?` branché comme `notebookBuilder`. Le builder **possède l'onglet** : il prime sur
l'anneau *et* sur `progressEmptyState`, qui garde son sens strict — rendu uniquement si
`progressData == null` **et** aucun builder.

🔵 **Votre rejet du contournement était juste, et il est désormais gardé.** Une injection R3 branche
délibérément le builder dans le chemin « aucune donnée » — celui que vous refusiez d'emprunter — et
**fait rougir** la garde de priorité. Le mauvais design n'est pas seulement déconseillé : il est
exclu par un test.

---

## 4. CR-IFFD-32 — un slot, pas une option de grille

```dart
ZItemActionsMenu(
  menuBuilder: (context, actions, select) => MaGrilleDActions(actions, select),
  …
);
```

🔵 **Nous avons retenu le slot**, que vous disiez suffisant, plutôt que l'option de disposition.
Raison : figer un `crossAxisMaxColumns` dans le socle y figerait **une** ergonomie de menu flottant —
largeur de panneau, ordre de lecture, parcours clavier, place du séparateur destructif. C'est
exactement le défaut que vos CR-LEX-61/73 et votre propre CR-35 reprochent au socle. Une option de
disposition reste ajoutable par-dessus, sans rupture.

⚠️ **Ce que le socle garde malgré le slot** : le filtrage `onSelected == null` est fait **en amont,
partagé**. Vous ne recevez que les actions actives — la règle d'absence vous est donc **inopposable**,
vous ne *pouvez pas* rendre une entrée grisée. `select` passe par le même chemin que le défaut : pas
de double appel, pas d'oubli de fermeture. C'est ce que vous jugiez « exactement ce qu'il faut », et
nous l'avons protégé plutôt qu'exposé.

Nous avons respecté votre cadrage : l'argument retenu est le **plafond de lisibilité**, pas votre
implémentation.

---

## 5. CR-IFFD-35 — la grille de flashcards

`crossAxisMaxColumns` (`int?`) et `crossAxisItemHeight` (`double?`) sur `ZFlashcardListView` —
**mêmes noms, mêmes types, même défaut `null`, même repli AD-10** que `ZStudyToolsSectionSpec`. Pas
une variante : c'est précisément ce que votre CR reprochait.

Votre argument d'incohérence interne était le bon : la vue utilisait **déjà** `ZAdaptiveGrid.builder`,
seuls les deux paramètres n'étaient pas câblés (constantes privées 300/180). Aucune seconde mécanique
n'a été écrite.

Deux écarts assumés : `crossAxisItemHeight == null` conserve la hauteur historique de 180 dp (la
non-régression prime) ; le plafond ne s'applique pas au chemin **réordonnable**, qui est un
`ReorderableListView` mono-colonne du SDK.

---

## 6. Vérification

`melos analyze` **RC=0** (0 erreur) · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0) ·
`zcrud_core` **1093** (+7) · `zcrud_ui_kit` **174** (+12) · `zcrud_study` **770** (+23).

Garde reproduisant votre symptôme exact : 24 actions à 800 dp ⇒ **aucune exception de layout**.
Neutraliser le repli rend `A RenderFlex overflowed by 400 pixels on the right`.

### ⚠️ Trois défauts de garde trouvés et corrigés — nous les listons

Vos CR nous ont appris à nous en méfier ; en voici trois, tous détectés en injectant.

1. **Garde de libellé du menu de dépassement** : restée verte parce que le code qu'elle protégeait
   était **mort** — `PopupMenuButton` applique déjà ce repli. Doublon supprimé, injection reformulée
   pour viser la vraie muetteté.
2. **Garde de virtualisation de la grille** : comptait les tuiles montées — or sous une régression
   *eager*, ce compte reste **identique** (le viewport culle dans les deux cas). Ce qui change est la
   construction en amont, invisible dans l'arbre. Déplacée sur le mécanisme (`shrinkWrap == false`).
3. **Garde de largeur de sidebar** (lot précédent) : le parent du test posait des contraintes serrées
   qui écrasaient l'injection. Refaite en contraintes lâches.

Le point commun : dans les trois cas, la garde mesurait **autre chose que ce qu'elle croyait**.

---

## 7. État de votre file

Vos CR-IFFD-27 à 36 sont **toutes livrées** (v0.27.0 et v0.28.0). Aucune n'est en attente.

🔵 **Votre runbook indique toujours `v0.18.0` comme tag consommé.** Dix versions vous séparent du
tag courant, dont l'epic VIS complet et l'ensemble des lots d'alignement visuel. Si la montée est
volontairement différée, ignorez cette remarque ; sinon, sachez que les handoffs `v0.19.0` à
`v0.26.0` sont estampillés `lex` mais que plusieurs touchent des surfaces que vous consommez — votre
propre runbook met d'ailleurs en garde contre le fait d'écarter un handoff sur le seul nom du fichier.
