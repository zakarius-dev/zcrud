# Handoff **v0.75.0** — la pilule booléenne, le téléphone natif, et un pays qui n'était pas un choix

> **Tag à épingler : `v0.75.0`**
> 🔴 **UNE RUPTURE DE CONTRAT** : la valeur du champ téléphone passe d'un objet typé à une **chaîne**
> (§ 3). Arbitrage du propriétaire — et **mesuré sans coût** : aucun de vos quatre dépôts ne lisait
> l'objet.
> 🔴 **Une dépendance nouvelle**, confinée à `zcrud_intl` (§ 3). Aucune dans le cœur.
> Le booléen reste **entièrement additif** : sans configuration, rien ne change.

---

## 1. Le booléen en pilule — sans faire entrer `flutter_switch`

Votre demande se heurtait à un invariant : `boolean` est rendu **en dur dans le dispatcher du cœur**,
et `zcrud_core` ne peut prendre **aucune** dépendance lourde. Décision du propriétaire : **les deux
voies que votre CR proposait**.

**Voie A — la pilule est peinte nativement.** `pubspec` du cœur **intouché**, `CORE OUT = 0` intact,
aucun littéral de couleur (greps montrés). Activation par `ZBooleanConfig.style`, dans la continuité
du canal de v0.74.0 ; défaut ⇒ rendu de v0.74.0 **strictement inchangé**, prouvé par trois gardes
**structurelles**.

**Voie B — le registre s'ouvre pour `boolean`.** Un hôte peut désormais injecter son propre widget,
au patron **exact** des familles déjà routées. Priorité gardée dans les deux sens : registre fourni ⇒
il gagne ; absent ⇒ natif.

### 🔵 Nous sommes allés à la source, et nous y avons trouvé trois écarts avec votre CR
1. 🔴 **Votre « vert » est ambigu chez vous** : deux constantes **homonymes** portent des valeurs
   différentes, et votre CR n'en donne aucune. Recopier son tableau aurait figé une valeur
   peut-être fausse.
2. Un comportement en lecture seule est **à votre source mais absent du tableau** de la CR — reproduit.
3. Trois défauts du paquet ne figuraient nulle part ; deux sont reproduits, l'animation non (dit).

### ⚠️ Ce que vous devrez faire, et pourquoi
🔴 **Sans réglage, la pilule active prend la couleur d'accent de votre thème — pas le vert.** Nous
avons **refusé** l'exception FR-26 encadrée, parce qu'elle imposait de **retoucher une garde de
source** pour y exempter un fichier. **Une ligne chez vous** rend la pilule verte, via la chaîne
`paramètre > jeton > rôle`. C'est le prix — modeste — de ne faire entrer aucun hex dans le socle.

🔵 **Contraste traité, sans invention** : le précédent existait (le premier plan des badges du
stepper, v0.73.0) et a été réutilisé — la couleur du texte et du pouce est **dérivée** de la piste.
Gardé sur piste sombre **et** claire : un blanc en dur passe l'une et rougit l'autre.

🔴 **Le texte interne reste décoratif** — v0.74.0 avait mesuré qu'un texte non exclu fait entendre
l'état **deux fois**. Le piège s'est présenté à nouveau : la première forme faisait annoncer le
**titre** deux fois. Mesuré, corrigé.

## 2. Le téléphone — le paquet est adopté, et confiné

`intl_phone_number_input` entre dans `zcrud_intl` et rend le champ. **Confinement prouvé par greps** :
le paquet n'apparaît que dans **un seul fichier de production** (un pont), **un seul pubspec** le
déclare, le barrel ne le mentionne pas, et **aucun de ses types ne sort du pont**. C'est la condition
qui rend cette dépendance acceptable — le même patron que Quill dans `zcrud_markdown`.

🔵 **`phone_numbers_parser` est conservé, et il sert** — mais la façon dont ça a été établi vaut mieux
que la conclusion : la campagne a d'abord montré que **le débrancher laissait tout vert**. Plutôt que
d'en conclure qu'il était inutile, le cas où il change le résultat a été **cherché, trouvé, et
gardé**. Le paquet rend l'interface ; lui décide de la valeur.

**Quatre chemins crashants du tiers** ont été mesurés et repliés, dont un découvert **par** la
campagne. Le rattrapage porte sur `Object` — donc aussi les `Error`, la leçon des deux moteurs tiers
de cette semaine.

## 3. 🔴 La valeur devient une chaîne — et ce n'est pas `value.phoneNumber`

Votre CR proposait de persister `value.phoneNumber`. **Mesuré : cela produit `+228+++++` pour une
saisie `+++++`** — une donnée qu'on ne peut plus interpréter en base.

La valeur exposée respecte donc un invariant strict : **forme internationale close** `^\+[0-9]+$`,
canonique quand le numéro est valide, `null` quand aucun indicatif n'est déterminable.
🔵 **Un bug trouvé en relecture** : un numéro international d'un **autre pays** que le sélecteur
produisait `+228336…`. Corrigé, gardé.

**Rayon de la rupture, mesuré des deux côtés** : `ZPhoneNumber` n'était lu par **aucun** de vos quatre
dépôts — **zéro fichier**. Dans le socle, seule la vitrine était concernée ; elle est adaptée.

## 4. 🔵 Le pays par défaut n'était pas un choix — c'était un artefact

En adoptant le paquet, un défaut est apparu : sans configuration, le champ affichait **`+93`**
(Afghanistan), **y compris sous une locale `fr_TG`**, purement ignorée. Deux mesures ont changé la
nature du problème :

* c'était un **mensonge d'affichage**, pas une valeur : la tranche n'était **jamais** écrite au
  montage ;
* et ce n'est même pas un défaut choisi par le paquet — c'est le **premier pays de son catalogue trié
  alphabétiquement**. Un artefact de tri.

**Corrigé en dérivant d'une information réelle**, jamais en inventant. Chaîne écrite au dartdoc :
> valeur saisie **>** configuration du champ **>** défaut du builder **>** locale ambiante **>**
> locales de l'appareil **>** repli défini.

🔵 **Un piège mesuré a rendu la cinquième source nécessaire** : `Localizations` rend la locale
**résolue**, donc une application configurée en `fr_TG` mais ne déclarant que `en_US` en locales
supportées ferait apparaître **les États-Unis**. Les locales de l'appareil rattrapent ce cas.

🔴 **Et l'étape finale est une règle assumée** : s'il ne reste **aucune** source honnête, le socle
**ne choisit aucun pays**. Déduire le pays de la **langue** (`fr` → France) a été **refusé** — c'est
aussi mensonger —, et un pays de repli en dur aussi. **FR-26 reste total : zéro code pays en dur.**

**Aucune valeur saisie n'est réécrite** — cinq valeurs stockées montées sous une autre locale, toutes
inchangées, invariant re-vérifié. C'était le risque principal du lot, et il est gardé par trois
mécanismes distincts.

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif du booléen** | **rien** — sans configuration, rendu de v0.74.0 identique |
| **DODLP (booléen)** | déclarez le style pilule **et** réglez la couleur active : sans cela elle prend l'accent de votre thème, pas le vert (§ 1) |
| 🔴 **tout hôte du champ téléphone** | la valeur est désormais une **chaîne** en forme internationale. Mesuré : **aucun de vos dépôts** ne lisait l'objet, donc rien à faire — mais si vous aviez du code non commité, il casse à la compilation, pas en silence |
| **hôte de `zcrud_intl`** | ⚠️ le paquet tire désormais `intl_phone_number_input`. Il reste **confiné** : vous ne le déclarez jamais |
| **hôte sans pays configuré** | le champ suit désormais votre **locale**, au lieu d'afficher l'Afghanistan |

## 6. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1685** (+30) · `zcrud_intl` **250** (+48) · `zcrud_study` 1521 · `zcrud_markdown` 516 ·
`zcrud_get` 150 · `zcrud_select` 135 · `example` 108. **0 erreur, 0 avertissement.**

**R3 — 35 injections sur les trois lots**, sha avant **et** après chacune, restauration par copie,
résidus : greps négatifs montrés.

🟢 **Trois gestes de rigueur que nous relayons tels quels** :
* une injection rendait dix **`StateError`** — des rouges d'**infrastructure**. Plutôt que de les
  compter, les aides de test ont été **durcies** ; l'injection rend désormais quinze rouges
  d'assertion sur quinze ;
* une injection est restée **verte** et a révélé que **deux gardes étaient protégées par une étape
  antérieure** et ne prouvaient donc pas ce qu'elles annonçaient. Une garde **isolante** a été
  ajoutée ;
* une injection a été **qualifiée `LateError`, pas assertion**, et rejouée sous une forme légale.

🟡 **Une garde préexistante VACANTE repérée et signalée, non touchée** : son cas « locale inconnue »
passe une locale qui, faute de locales supportées déclarées, se **résout** en une autre — elle
n'atteint donc jamais le champ. Elle sera reprise dans un lot dédié.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 7. Non couvert

* L'animation de bascule de la pilule (rendu statique) — dit, pas fait.
* Le repli de lecture plateforme n'est **pas gardé** : le déclencher exigerait une garde tautologique.
  Déclaré plutôt que maquillé.
* Aucune propagation du rendu pilule à la liste.
* Dettes antérieures : cf. v0.74.0 et les handoffs précédents.
