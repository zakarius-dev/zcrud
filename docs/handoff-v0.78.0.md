# Handoff **v0.78.0** — un champ lit désormais ce qu'on lui donne, pas seulement ce qu'il écrit

> **Tag à épingler : `v0.78.0`** — répond à **CR-IFFD-79**.
> 🔴 **Changement d'arbre visible** sur les familles `date` / `time` / `dateTime` / `dateRange`
> **pour tout hôte qui sème ses valeurs depuis une persistance**. Un hôte qui sème des chaînes
> ISO est **strictement immobile** (prouvé).
> Aucun jeton nouveau, aucune arête, aucun paquet nouveau (38). Voie d'**écriture inchangée**.

---

## 1. Votre constat était juste — et il sous-estimait la portée

Vous aviez mesuré **un** cas. Une sonde sur le code d'origine, valeur **semée**, lecture du texte
**et** du nœud d'accessibilité, en dénombre **six** :

| Mode ← graine | Avant |
|---|---|
| `dateTime` ← `DateTime` | 🔴 vide — **votre cas** |
| `time` ← `DateTime` | 🔴 vide |
| `time` ← `TimeOfDay` | 🔴 vide |
| `dateRange` ← `Map` | 🔴 vide |
| valeur hors contrat (ex. un entier) | 🔴 vide |

Et votre § ③ visait plus juste encore que sa formulation. La symétrie est **exacte**, mesurée dans
le générateur (`_toMapExpr`) : un champ `DateTime` se persiste en **chaîne ISO**, un champ
`ZDateRange` se persiste en **Map**. Donc :

> **amorcer un formulaire depuis les champs du modèle cassait `date` ; l'amorcer depuis
> `model.toMap()` cassait `dateRange`.** Chaque convention d'hydratation cassait précisément **une**
> des deux familles — et aucune des deux n'était fautive.

C'est ce qui fait de `dateRange` une correction **mesurée**, pas une extension par analogie.

## 2. Ce qui change

* La graine est **normalisée** vers la convention que le sélecteur de son mode écrit lui-même
  (`HH:mm` en `time`, ISO ailleurs). **Aucun format nouveau n'entre dans le paquet**, et la valeur
  atteint enfin le port `ZDateDisplayFormatter` par le chemin déjà en place.
* `dateRange` accepte la **Map persistée**, décodée par le décodeur **défensif** déjà utilisé par la
  voie de persistance — `null` sur toute anomalie, jamais de `throw` (AD-10).
* **Le hors-contrat rend sa présence, jamais le vide** : une valeur non nulle non reconnue s'affiche
  par le repli déjà défini par le paquet, et la croix d'effacement est pilotée par la **présence** —
  sinon une graine hors contrat serait resoumise **sans recours**. C'est votre § ④, et c'est la règle
  déjà tranchée en CR-IFFD-77 puis `v0.65.0` : dissocier présence et identité plutôt qu'effacer.

🔵 **Un piège évité, qui vous concerne directement** : passer le `DateTime` nu au port aurait fait
replier sur `DateTime.toString()` — `2025-09-01 14:30:00.000`, avec une **espace**, pas l'ISO. Un
hôte passif aurait donc bougé. La normalisation existe pour ça.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte qui sème des chaînes ISO** | 🟢 **rien** — immobilité prouvée par garde dédiée |
| 🔴 **hôte qui sème `DateTime` / `TimeOfDay` / une Map de plage** | la valeur **apparaît** là où le champ était vide. C'est la correction demandée |
| 🔴 **hôte qui COMPENSAIT** en affichant la date **à côté** du champ | **retirez la compensation** — sinon la date s'affiche **deux fois** |
| 🔴 **DODLP** | mesuré chez vous : **7 champs** sèment un `DateTime`, et votre **soumission** relit `is DateTime` — donc la date choisie par l'utilisateur (une `String` ISO) était **jetée**. Le socle corrige l'affichage ; **votre garde de soumission doit accepter la chaîne ISO**, sinon le second défaut subsiste |

⚠️ **Notre CI reste à l'arrêt (facturation)** : ces vérifications sont locales, et c'est la seule
ligne de défense.

## 4. Vérification

`melos generate` **RC=0**, **0** `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1721** (+13) · `zcrud_study` 1521 · `example` 108. **0 erreur, 0 avertissement.**

**R3 — 6 injections, 6 rouges d'ASSERTION** (aucun rouge de compilation, de `StateError` ni d'erreur
de type), sha avant **et** après chacune, restauration par copie, résidus : greps négatifs montrés.
**Ligne de base mesurée dans les deux sens** : jouées sur le code d'origine, les gardes rendent
**10 rouges sur 13** — les 3 vertes sont précisément les non-régressions « hôte passif », vertes
avant **et** après.

🟢 **Une garde déclarée non discriminante par son propre auteur** : elle ne distingue pas une des
injections (le repli reste parsable) ; deux autres tiennent ce rôle, et c'est écrit plutôt que
masqué par un compte flatteur.

## 5. 🔴 Ce que votre CR a déclenché et que vous n'aviez pas demandé

Vous écriviez n'avoir **pas** vérifié les autres familles, et ne pas affirmer le motif ailleurs.
Nous l'avons arpenté : **33 sites**, recensement prouvé exhaustif.

* 🔴 **Une perte de données réelle, hors date** : le champ de **sous-liste** recompose chaque item à
  partir des seuls champs déclarés — **toute clé absente du schéma d'item disparaît à la première
  frappe**, `id` compris. Mesuré actif chez **deux** hôtes. **Lot suivant, immédiat.**
* 🟡 **Des champs qui ne se taisent pas mais MENTENT** : une graine `"3"` sur une notation affiche
  **`0 / 5`**, `"7"` sur un curseur affiche **0**, `"true"` sur un booléen affiche **faux**. Le vide
  est visible ; un zéro plausible ne l'est pas.
* Le cœur possède déjà des lecteurs tolérants (`zJsonIntOrNull`…) qu'**aucune famille n'utilise** —
  grep montré. La correction générique a donc déjà son outillage.

Ces lots suivent, à fichiers disjoints. Votre CR aura servi bien au-delà du champ date.

* Dettes antérieures : cf. `v0.77.0` et les handoffs précédents.
