# Handoff **v3.0.0** — trois CR IFFD, et une régression que nous avions livrée

> **Tag à épingler : `v3.0.0`** — majeure à cause d'**un** changement de défaut (§4).
> Tout le reste est additif ou correctif.
>
> 🔴 **Si vous consommez `zcrud_study`, lisez le §1 en priorité** : il corrige un défaut que nous
> avons introduit en 1.8.0 et qui vous touchait en silence depuis.

---

## 1. 🔴 Une régression que nous avons livrée, et que VOTRE garde a trouvée

`subListSeamRegistry` (1.8.0) et `selectChoiceBuilderRegistry` (2.1.0) n'étaient **pas re-posés**
lors de la recopie du `ZcrudScope` sous la feuille modale. Un hôte y perdait **en silence** le rendu
déclaré qu'il venait d'obtenir.

C'est **votre** garde de structure — `cr_iffd41_subfolder_sheet_test` — qui l'a trouvée. Elle lit la
liste **réelle** des paramètres dans la source de `zcrud_core` et exige que chacun soit re-posé.
C'est la **quatrième et cinquième** fois qu'elle mord. Son commentaire le dit mieux que nous :
*« c'est la garde — pas la vigilance — qui le tient »*.

**Nous avons cherché le jumeau plutôt que d'attendre qu'il se manifeste** : `z_default_flashcard_card`
recopie le scope de la même façon et portait **exactement les deux mêmes manquants**, sans qu'aucune
garde ne le surveille. Corrigé aussi.

⚠️ **Et nous vous devons la vérité sur pourquoi c'est arrivé** : nos gates repo-wide (`analyze`,
`verify`) étaient verts, et nous ne rejouons les suites que des paquets touchés. Cette garde vit
dans un paquet que nous ne touchions pas. Un gate cross-package existait précisément pour ça, et
nous ne l'avions pas exécuté.

## 2. CR-IFFD-80 — le message de requête n'était jamais peint *(bloquante)*

**Mécanisme établi.** Vos trois hypothèses étaient toutes fausses, et vous aviez raison de les
éliminer par mesure : la cause était **au paint**.

La référence de skin fournissait à la **requête seule** une bordure portant un rayon
**directionnel**. Le rendu de Syncfusion appelle `getOuterPath(bounds)` **sans transmettre de
`TextDirection`** ; Flutter ne peut donc pas résoudre le rayon et **lève** ; le paint s'interrompt
**avant** de peindre l'enfant. La trace le confirme : géométrie valide, `RenderParagraph …
NEEDS-PAINT`.

Cela explique le dernier fait qui vous restait inexpliqué — pourquoi votre sonde, un `Container`
jaune vif, restait invisible : **rien de cet enfant n'était peint**, quelle que soit sa couleur.

La bordure est désormais **résolue** avec la direction du contexte avant d'être transmise. Le rendu
RTL est conservé, votre contrat `null → rendu neutre` n'est pas touché, et **aucune dépendance
Syncfusion** n'entre dans `zcrud_chat`.

⚠️ **La voie que vous proposiez en premier — alimenter le champ `data` — était déjà en place** et
n'aurait rien corrigé. Nous le signalons parce que vous auriez pu la tenter de votre côté.

## 3. CR-IFFD-81 — un créneau d'action par groupe

`groupActionsBuilder` reçoit le **groupe exact** et rend vos actions. **Le socle ne fabrique pas le
« + »** : vous demandiez le créneau, pas l'action — la création reste métier.

Défaut : aucune action, rendu identique au pixel. Un constructeur qui lève laisse la liste intacte,
**sans action de repli**. Cible ≥ 48 dp, sémantique de bouton, activation au clavier.

**Non livré, comme vous le demandiez** : accordéon, icône de groupe, troncature du titre — vous les
qualifiez de cosmétiques et annoncez qu'un profil de référence les couvrira.

## 4. ⚠️ CR-IFFD-82 — RUPTURE : le menu rend une grille par défaut

`ZItemActionsMenu` rendait une **colonne unique**. Le défaut est désormais une **grille de
3 colonnes**, via le `gridDelegate` qui existait déjà et porte le plancher de cible tactile par
construction.

**Retour arrière en une ligne : `crossAxisCount: 1`** — prouvé par garde, pas promis. Et
`crossAxisCount: 2` est respecté, si vous préférez votre géométrie legacy.

Trois colonnes et non deux est **votre arbitrage**, contre votre propre legacy : nous l'avons tenu
tel quel, sans le « corriger ».

**L'action porte son état** : `absent / inProgress / present`, plus un compte. Aucune couleur codée
en dur — teinte dérivée du `ColorScheme` par le patron déjà employé pour les cartes de dossier, avec
plancher de contraste. Et l'état est **annoncé**, pas seulement peint : une information portée par
la seule couleur est invisible à un lecteur d'écran, ce qui reproduirait votre défaut à l'envers. Un
état invalide **échoue fermé** — aucune teinte sans annonce.

Sans état ni compte : rendu identique, contre-témoin à comptes absolus.

## 5. Deux points que nous vous signalons sans les traiter

- **Les trois bindings** (GetX, Riverpod, provider) construisent un scope minimal, or un scope
  imbriqué **masque** l'ambiant au lieu d'en hériter. Un hôte plaçant son propre `ZcrudScope`
  *au-dessus* d'un binding perdrait 21 seams en silence. Personne ne l'a signalé, et le rôle déclaré
  du binding n'est pas de relayer — mais le piège existe.
- **La recopie seam par seam invite l'erreur** : `copyWith` existe et hérite des paramètres omis, ce
  qui rendrait le défaut du §1 **impossible** au lieu d'être rattrapé. Cinq déclenchements de la même
  garde en trois jours plaident pour ce changement. Il implique de réécrire une garde qui fonctionne,
  donc il mérite son propre lot.

## 6. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0 (14 gates, 40 paquets).
`zcrud_study` **1536** (+8), 70 signalements inchangés · `zcrud_chat` **556** (+5), analyse propre ·
`zcrud_chat_syncfusion` **69** (+4), analyse propre.

Injections R3 sur les trois lots, **toutes rouges par assertion**, restaurations par copie avec
sha256 avant/après cités. Deux méritent d'être signalées : celle qui remplace une teinte dérivée par
une couleur en dur (`Expected: not contains RegExp(\bColors\.)`), et celle qui prive un état de son
annonce accessible.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue la
ligne de défense de cette release.
