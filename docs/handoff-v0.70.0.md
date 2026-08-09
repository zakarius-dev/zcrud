# Handoff **v0.70.0** — la quatrième copie est fermée, et les dates ont enfin un moteur

> **Tag à épingler : `v0.70.0`**
> 🔵 **Un seul mouvement d'affichage** : la valeur **orpheline** d'une liste cesse d'être un
> identifiant technique. Tout le reste est strictement inchangé sans injection.
> ⚠️ **`zcrud_intl` dépend désormais d'`intl`** (§ 3) — arbitrage du propriétaire, encadré.
> Aucune signature cassée, aucun paquet nouveau (38).

---

## 1. La quatrième copie — le défaut de v0.65.0 était encore ouvert dans les listes

`z_list_column.dart` portait la **quatrième copie locale** de la résolution de libellé, et elle
rendait la **valeur brute** sur une valeur orpheline. Autrement dit : le défaut fermé en v0.65.0 sur
dix voies de rendu restait ouvert **à l'endroit le plus vu de l'application**.

**Avant / après, par famille** — et le tableau est plus intéressant que le correctif :

| Famille | Avant | Hôte **passif** après | Via `DynamicList` |
|---|---|---|---|
| choix résolvable | libellé | **identique** | identique |
| **choix orphelin** | 🔴 identifiant brut | brut (voie sans arbre, § 4) | ✅ **libellé localisé** |
| date / heure | ISO brut | **identique** | ✅ **formaté**, avec locale |
| booléen, nombre, texte, vide | — | **strictement identiques** | identiques |
| visibilité, ordre, largeur, en-tête | — | **inchangés** | inchangés |

## 2. La closure sans contexte — la mesure a changé la conclusion

Le lot précédent avait renoncé à câbler les dates ici, au motif que le formateur est une **closure
sans `BuildContext`**. C'était exact, mais incomplet — et la distinction compte :

> la closure est **invoquée** sans contexte, et ça n'est **pas réparable** (`zcrud_list` l'appelle
> depuis sa source de données, `zcrud_export` l'appelle **sans aucun arbre**) ; mais elle est
> **construite** dans `DynamicList`, **avec** un contexte.

Elle n'a donc pas besoin d'un contexte : elle a besoin des **valeurs** qu'il fournit. Celles-ci sont
capturées à la dérivation. **La signature publique de `format` n'a pas bougé.**

🔴 **Un piège trouvé en chemin** : `zcrud_list` reconstruit ses cellules quand la requête change. Dès
que la closure capture des seams, deux colonnes de mêmes métadonnées rendent des textes différents —
donc ces seams **doivent** participer à l'égalité, sans quoi la grille garderait ses anciennes
chaînes **après un changement de locale**. Corrigé et gardé.

### Réutilisé, et ce qui a dû être écrit
**Réutilisé** : la clé de libellé de v0.65.0 — **aucune seconde clé pour la même idée**, et la garde
qui l'affirme lit la déclaration **dans la source**, commentaires retirés.
Le repli des dates a été **extrait** en fonction pur-Dart, partagée avec le reste du paquet. Preuve du
partage, élégante : **modifier du code de domaine fait rougir des gardes de liste**.

🔵 **Et une réutilisation a été REFUSÉE, avec quatre mesures** : la projection d'affichage
`zReadOnlyValueOf` **ne peut pas** servir de projection de liste — elle peut rendre un **widget** là
où le backend exige une chaîne ; elle rend `—` sur un vide ; elle transforme un booléen en « Oui » et
un nombre en « 42 % » ; et elle exige un contexte **au formatage**. La liste garde donc son routage,
mais **plus aucune règle métier propre** : le code net ajouté est un repli, une normalisation, et du
transport.

## 3. ⚠️ Les dates ont un moteur — et `zcrud_intl` dépend maintenant d'`intl`

`ZIntlDateDisplayFormatter` implémente le port livré en v0.69.0.

🔴 **Ce paquet s'interdisait `intl` par une garde nominative.** L'interdiction visait la **devise** et
les **subdivisions**, servies par des assets JSON — cette règle est **inchangée**. Le formatage de
dates est un besoin que ces assets ne couvrent pas : les noms de mois et de jours sont des **données
de locale**, et les écrire dans le paquet violerait FR-26.

**Arbitrage du propriétaire : autorisé**, avec trois garde-fous vérifiés — `zcrud_core` reste
interdit d'`intl`, la dépendance est **confinée à un seul fichier** sous sa propre garde, et le
formateur vit dans un **point d'entrée séparé** : un hôte qui ne veut que téléphone et pays ne paie
pas la table de locales.

### Deux des cinq pièges annoncés étaient faux
🔵 La **normalisation** de l'étiquette de locale — décrite comme « le seul piège fonctionnel réel » —
était **inutile** : la bibliothèque canonicalise elle-même, et cinq écritures différentes de la même
locale rendent le même résultat. L'écrire aurait été du **code mort livré avec sa garde**.
🔴 En revanche l'**initialisation** est pire qu'annoncé : elle ne concerne pas que les locales
étrangères — l'anglais lève aussi.

🔴 **Le vrai piège était ailleurs, et c'est un précédent de la semaine** : une locale inconnue lève
une `Error`, mais des **données absentes** lèvent une **`Exception`**. Un `on Error catch` aurait donc
laissé fuir l'échec le plus **normal**. Exactement le défaut mesuré le matin même dans le moteur
Markdown.

Le cache est prouvé **par instance**, pas par résultat — 26× de coût mesuré entre créer et réutiliser.
**Décliné, jamais inventé** : sur une locale inconnue, le formateur rend `null` plutôt que de basculer
sur une locale par défaut, ce qui serait un **mensonge de locale**.

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — sans port injecté, chaque famille rend exactement comme avant |
| **DODLP** | injectez `ZIntlDateDisplayFormatter` (point d'entrée `package:zcrud_intl/date_formatter.dart`) et vos colonnes de date deviennent lisibles ; vos valeurs orphelines cessent d'afficher un identifiant |
| **hôte de `zcrud_intl`** | ⚠️ le paquet tire désormais `intl`. Si vous n'utilisez que téléphone/pays, **n'importez pas** le point d'entrée du formateur |
| ⚠️ **export sans interface** | la valeur orpheline y reste brute : **aucun arbre, donc aucune localisation atteignable**, et coder le texte en dur violerait FR-26. Vous pouvez fournir le libellé vous-même |

## 5. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1583** (+15) · `zcrud_intl` **202** (+19) · `zcrud_firestore` 770 · `zcrud_markdown`
516 · `zcrud_study` 1521 · `zcrud_select` 135 · `zcrud_export` 33 · `zcrud_list` 21 · `example` 102.
**0 erreur, 0 avertissement.**

### 🔴 Cinq gardes ont bougé — et voici pourquoi ce n'est pas un affaiblissement
L'égalité d'une colonne inclut désormais les seams capturés, qu'une dérivation nue n'a pas. Les
gardes de **dérivation** comparent donc une projection de métadonnées — **exactement ce qu'elles
comparaient avant que les seams existent**. Vérifié par nous, champ par champ : la projection couvre
nom, en-tête, type, ordre et largeur, soit **tout ce que l'égalité comparait**, moins le champ qui
n'existait pas. La propriété nouvelle est gardée **à part**. Aucune garde supprimée.
🟢 Et la garde qui **défendait** le défaut (« la valeur brute ressort telle quelle ») n'a **pas** eu à
bouger : elle exerce la voie sans arbre, et une injection la prouve mordante.

**R3 — 26 injections** sur les deux lots, sha avant **et** après, restauration par copie, résidus :
greps négatifs montrés.

🟢 **Une injection restée verte, mesurée puis rejouée** — quatrième jour consécutif.
🟢 **Une injection non tentée et déclarée telle** : son motif avait zéro occurrence, la branche visée
ayant été fusionnée ; la propriété est mordue par deux autres.
🟢 **Un incident de campagne rattrapé par les empreintes** : un premier passage tué par dépassement de
délai avait laissé une injection **en place**. Détecté par `sha256`, restauré par copie, campagne
rejouée.
🔴 **Et une trouvaille qui dépasse ce lot** : des séparateurs de clé écrits en **octets NUL bruts**
rendaient un fichier **binaire aux yeux de `grep`** — une recherche de source ne rendait **rien**,
sans erreur. Toute garde de source l'aurait silencieusement sauté. Corrigé ; plus aucun fichier
binaire dans le paquet.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 6. Deux affirmations d'agent corrigées par la mesure

* Un rapport affirmait que `updateShouldNotify` **oubliait toujours** un port : **faux**, corrigé en
  v0.69.0 — vérifié sur disque, et la garde de parité passe. Le rapport reprenait un constat lu, non
  re-mesuré.
* Un autre affirmait que `zcrud_markdown` possédait un registrar : **faux** aussi. Il n'en a pas, pas
  plus que `zcrud_intl`.

## 7. Non couvert

* Le déclencheur du champ date **en édition** affiche encore l'ISO.
* `rowChips` et `relation` ne résolvent pas leurs libellés en liste.
* `DynamicEdition` n'observe pas son drapeau de gestion de visibilité (cf. v0.68.0).
* Dettes antérieures : cf. v0.69.0 et les handoffs précédents.
