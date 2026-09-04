# Handoff v3.46.0 — le menu d'actions s'ouvre sur le bouton que vous avez déjà

> **Date** : 2026-09-04. **Portée** : `zcrud_study`. **Traite** : CR-IFFD-135 (`MINEUR`).

## Clés de schéma ajoutées

**Aucune.** `melos run generate` : **0 `.g.dart` modifié**. Livraison entièrement
présentationnelle, purement additive.

## 1. Le défaut, tel que l'hôte l'a mesuré

`ZItemActionsMenu` est un **widget qui porte son propre déclencheur**. Un hôte dont l'arbre a
**déjà** un bouton monté — et qui ouvrait son menu dessus, par la clé de ce bouton — ne pouvait
pas router vers le socle sans **retirer ce bouton de ses écrans**. Ce n'est plus un aiguillage
sous drapeau mais une réécriture, et surtout : elle n'est **pas réversible** en repassant le
drapeau à `false`. Le principe même d'une migration progressive s'y oppose, et l'hôte gardait donc
son menu d'origine.

Deux précisions de mesure, faites de notre côté :

- la CR situe le widget dans `zcrud_ui_kit` : **il vit dans `zcrud_study`**. Le constat est juste,
  la localisation non ;
- le socle était **plus près de la solution que la CR ne le supposait** : `ZMenuRenderer.openAt`
  existait déjà, avec son implémentation par défaut, et le menu contextuel (`ZContextMenuRegion`)
  en empruntait déjà tout le chemin. Il ne manquait ni la surface ni l'ouverture : il manquait la
  **composition** et le calcul de position depuis une ancre.

## 2. Ce que le socle livre

```dart
Future<void> showZItemActionsMenu(
  BuildContext context, {
  required List<ZItemAction> actions,
  required GlobalKey anchorKey,
  ZItemActionsMenuBuilder? menuBuilder,
  int crossAxisCount = 3,
  ZMenuRenderer? renderer,
  String? semanticLabel,
});
```

**Une seule composition, deux voies d'ouverture.** C'était le risque principal du lot, et l'hôte
l'avait nommé : recopier la traduction des actions produirait deux rendus du même menu, qui
divergeraient au premier changement. La composition — traduction des actions, correspondance par
identité, règle d'absence, choix entre slot hôte et grille par défaut — vit désormais dans un
**site unique** appelé par le widget **et** par la fonction impérative. Une garde de source compte
les occurrences et balaie tout `lib/` : une seconde composition fait rougir le paquet.

**Géométrie.** La surface s'ouvre au coin du bord haut de l'ancre situé du côté vers lequel elle
grandit (le bord de fin quand l'ancre est proche du bord de fin de l'écran, la directionnalité
départageant une ancre centrée). Prouvé par rectangle mesuré sur **six** configurations
placement × directionnalité : le rectangle obtenu est **égal** à celui du déclencheur porté.

**Repli, jamais de levée (AD-10).** Contexte démonté, ancre sans contexte courant, boîte de rendu
absente, détachée ou sans taille, rien à montrer : **aucune surface**, aucune exception. L'ancre
n'est délibérément **pas** assertée — une ancre démontée est une course, pas une faute de
programmation, et l'asserter serait précisément la levée qu'AD-10 proscrit. La résolution des
localisations Material passe par la forme qui rend `null` plutôt que celle qui lève.

## 3. Ce qui change pour un hôte

- **Passif : rien.** Le widget existant rend un arbre identique — signature d'arbre capturée
  **avant** modification et comparée en égalité stricte (61 widgets pour le déclencheur, 157 pour
  la surface), et la voie impérative rend **les mêmes 157**.
- 🔴 **Hôte qui compensait** — deux cas distincts, ne les confondez pas :
  1. celui qui **gardait son menu d'origine** faute d'ouverture ancrée : il peut router
     maintenant, **en gardant son bouton**. Le geste vérifiable de son côté : son menu d'origine
     devient le doublon, et le test qui affirmait la perte doit rougir. C'est ce rouge qui désigne
     le code à retirer — pas cette phrase.
  2. celui qui avait **redupliqué la composition** chez lui (grille maison, filtrage refait,
     fermeture à la main) : cette compensation est maintenant redondante. `menuBuilder` reçoit
     déjà la liste **filtrée**, et la fonction de sélection ferme la surface — cumuler les deux
     voies produirait une double fermeture.

```dart
final GlobalKey _boutonKey = GlobalKey();

IconButton(
  key: _boutonKey,
  icon: Icon(monGlyphe),
  tooltip: l10n.moreOptions,
  onPressed: () => showZItemActionsMenu(
    context,
    actions: mesActions,
    anchorKey: _boutonKey,
  ),
)
```

## 4. Vérification

| Paquet | Avant | Après |
|---|---|---|
| `zcrud_study` | 1 912 | **1 939** |
| `zcrud_menu` | 80 | **80** (intouché — `git diff` vide) |

`melos run generate` : SUCCESS, **0 `.g.dart` modifié** · `analyze` repo-wide RC=0 · `verify`
RC=0 (12 gates) · balayage des 41 paquets · R3 : 6 injections, **toutes rouges par assertion**,
restauration par copie, sha256 identique avant et après chaque cycle, grep négatif du marqueur
montré.

🟢 **Deux gardes ont été refaites après avoir échoué à leur propre R3**, et c'est dit ici parce que
c'est la partie utile : l'une était **verte sous injection** — elle mesurait le refus du renderer
Material, pas notre code, donc elle regardait à côté ; l'autre **pendait dix minutes au lieu de
rougir**, une attente de complétion là où il fallait mesurer une valeur. Une garde qui pend n'est
pas une garde lente : c'est une garde qui ne mesure rien. Toutes deux ont été re-ciblées avant
d'être acceptées.

⚠️ Piège de mesure consigné pour qui écrit des gardes de directionnalité : une `Directionality`
posée dans `home` laisse la couche de superposition en LTR, ce qui rend **tautologique** toute
garde RTL portant sur une surface flottante. Le harnais la pose au niveau du constructeur
d'application.
