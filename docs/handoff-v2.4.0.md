# Handoff **v2.4.0** — le titre d'une confirmation devient optionnel

> **Tag à épingler : `v2.4.0`** — paquet porteur : **`zcrud_ui_kit`**.
> **Rétrocompatibilité totale** : tout appelant passant un titre garde exactement le rendu actuel.

---

## 1. Le défaut

`showZConfirmDialog` et `ZConfirmDialog` imposaient un `title`. Votre confirmation legacy n'en
affichait **aucun** — son titre était explicitement **commenté** dans le source. Sur 14 sites
portés, vous avez donc dû inventer 14 libellés que rien ne permet de vérifier contre une référence,
alors que le message porte déjà la question en entier.

Le coût que vous décrivez est le bon, et ce n'est pas le bruit visuel : c'est la **localisation**.
Dans un module traduit en dix langues sans clé de titre générique, vos trois issues étaient toutes
mauvaises — une chaîne française dans un module multilingue, dix fichiers à modifier pour un mot
jamais affiché, ou le détournement d'une clé voisine. Votre quatrième voie, l'infobulle du bouton
« Supprimer » de Flutter, était la moins mauvaise, et votre formule est juste : *« elle documente le
problème plutôt qu'elle ne le résout »*.

## 2. Ce qui change

```dart
title: title == null ? null : Text(title!),
```

`title: null` ⇒ **aucun `AlertDialog.title` dans l'arbre**. Pas un titre vide, pas un `SizedBox`.

**Et surtout : aucun défaut inventé par le socle**, exactement comme vous le demandiez. Votre
argument a emporté la décision — un socle qui invente un titre recrée le même problème un étage
plus bas, et vous ne sauriez pas le retirer. Vous pouvez donc retirer votre détournement de
`deleteButtonTooltip`.

Sans titre, le dialogue reste correctement annoncé : la route est nommée et cadrée, et c'est gardé.

## 3. Impact sur votre code

- **Hôte passif** : rien à faire. Contre-témoin à comptes absolus : avec titre, la structure est
  celle d'aujourd'hui.
- **Vous** : supprimez les titres inventés là où ils n'apportent rien, et le détournement de
  l'infobulle Material dans le module `workflow`.

## 4. L'écart que vous consignez sans le demander

Vous relevez que le legacy mettait une icône dans chaque bouton et deux boutons de même poids, là
où `ZConfirmDialog` distingue annuler et confirmer par la **forme** du bouton et une tonalité issue
du `ColorScheme`. Vous le qualifiez d'amélioration et ne le demandez pas : **nous ne l'avons donc
pas touché**. C'est noté ici pour qu'un relevé de parité futur ne le prenne pas pour une régression
non vue — ce qui était précisément votre intention en le consignant.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0 (14 gates, 40 paquets).
`zcrud_ui_kit` **232** tests (base 227, +5), analyse **propre** · `zcrud_screen` **345**, inchangé.

Deux injections R3, rouges **par assertion**. La première fait inventer un titre au socle quand
aucun n'est fourni : `Expected: null / Actual: Text:<Text("…")>` — c'est la garde qui protège
précisément ce que vous demandiez de ne pas faire. Restaurations par copie, sha256 identiques,
résidus prouvés absents.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue
la ligne de défense de cette release.
