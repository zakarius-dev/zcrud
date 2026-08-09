# Handoff **v0.69.0** — le résumé de sous-liste affiche des libellés, et un port oublié depuis v0.66.0

> **Tag à épingler : `v0.69.0`** · additif — un hôte qui n'injecte rien ne voit **rien** changer.
> Aucune signature cassée, aucun paquet nouveau (38), aucune arête.

---

## 1. Gap 3bis — la clé brute au lieu du libellé

Votre constat est exact : la projection de résumé faisait `_stringOf(valeur)`, soit **la valeur
stockée mise en chaîne**. Un `select` affichait son identifiant, un `dateTime` son ISO.

🔵 **C'est la même famille que le défaut fermé en v0.65.0** — un identifiant technique à l'écran —
avec une différence qui compte : là-bas l'identité était **non résolvable** (valeur orpheline), ici
elle est **parfaitement résolvable**, les choix sont à deux champs de distance. On ne les regardait
simplement pas.

**Aucune quatrième copie n'a été écrite.** La projection d'affichage `zReadOnlyValueOf` existait et
résolvait **déjà** les libellés de choix **et** la règle d'orphelin de v0.65.0 — le résumé l'appelle.
Et pour ne pas créer une copie de plus, la résolution des choix a été **extraite** du dispatcher, qui
y délègue désormais.

> 🔴 Le compte vaut d'être dit : ce `_stringOf` était la **troisième copie locale** du même motif.
> Les deux premières — celles de la validation — ont été unifiées en v0.64.0 et v0.67.0. Une
> quatrième subsiste, hors périmètre : § 5.

### Ce qui est résolu, et ce qui ne peut pas l'être
Résolus **synchroniquement** : choix statiques, source de choix injectée (son port est synchrone par
contrat), choix dérivés d'un autre champ.
🔴 **Pas résolvable : un `relation`**, dont la source est un **flux**. Le résoudre depuis une cellule
de tableau exigerait de s'y abonner — donc d'élargir la tranche et de reconstruire la ligne à chaque
émission. **Nous ne l'avons pas improvisé** : ces valeurs retombent sur le libellé d'indisponibilité,
**jamais sur la clé**. Repli côté hôte : une source de choix miroir, ou le constructeur de titre.

## 2. Les dates — un port, et un repli qui ne déplace personne

`ZDateDisplayFormatter`, pur-Dart, injecté par `ZcrudScope`. Il sert **aussi** la fiche de lecture —
même appel, gratuit.

🔵 **Un repli « meilleur » a été écarté délibérément** : tronquer l'ISO était faisable en pur Dart et
plus lisible… mais aurait **déplacé tout hôte passif**. Le repli reste donc la chaîne brute
d'aujourd'hui, dans **tous** les chemins dégradés — port absent, valeur non parsable, mode heure,
retour nul, et port qui **lève**.

**L'implémentation `intl` n'est pas dans ce lot** (AD-1 : le cœur ne peut pas en dépendre). Elle est
spécifiée, avec les cinq pièges réels mesurés — dont l'initialisation sans laquelle un format
localisé **lève**, et la mise en cache, puisque le socle appelle le formateur **une fois par cellule
et par build**.

## 3. Les en-têtes de colonnes — opt-in, et pour une raison non évidente

`showSummaryHeaders`, défaut `false`.

🔵 **Un en-tête posé au-dessus des cellules actuelles aurait MENTI** : les largeurs sont intrinsèques
et chaque ligne a son **propre** défilement horizontal — rien ne serait tombé en face. L'option
change donc aussi la mise en page (colonnes réparties, texte à l'ellipse). C'est pourquoi elle est
opt-in, et non « presque gratuite » comme nous l'avions d'abord estimé.
⚠️ Contrepartie : un texte tronqué reste atteignable par le dialogue de la ligne — **sauf** si votre
ACL refuse à la fois la consultation et la modification.

## 4. 🔴 Un port oublié depuis v0.66.0 — et la garde qui manquait

En traitant ce qui précède, un autre défaut est apparu : **`richTextRenderer` était absent
d'`updateShouldNotify`**. Mesuré : **21 paramètres déclarés, 20 comparés**. Le port était déclaré,
propagé et consommé — mais un hôte qui en changeait **à chaud** ne voyait **aucun dépendant se
reconstruire**. Rien ne levait ; le rendu restait simplement périmé.

**La garde qui l'aurait vu n'existait pas.** Le dépôt en avait une pour la **re-pose** du scope dans
une feuille — elle a mordu trois fois cette semaine — mais **personne ne surveillait la
comparaison**. Le même angle mort, décalé d'un cran. Elle est posée, et elle lit la liste **réelle
dans la source**.

> 🟢 **Elle a mordu sur son auteur, immédiatement.** Sa première version bornait la zone analysée au
> premier `;` — et un point-virgule écrit dans un **commentaire de prose** l'a fait s'arrêter avant
> les deux dernières comparaisons : elle a accusé du code correct. C'est le pendant exact d'un
> incident inverse de la même semaine (une garde qui rougissait sur sa **propre** prose). Elle retire
> désormais les commentaires **avant** d'analyser. Une garde qui lit du code ne doit jamais pouvoir
> être déviée par ce qu'on écrit autour.

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — sans port injecté ni option activée, l'affichage est **strictement** celui d'aujourd'hui : un booléen reste `true`, un pourcentage n'est pas suffixé, un vide reste vide, une date reste ISO |
| **DODLP** | vos colonnes de résumé affichent enfin les **libellés** ; pour les dates, injectez un formateur (l'implémentation `intl` arrive) |
| **hôte changeant un port à chaud** | 🔵 le rendu riche se met enfin à jour — il ne le faisait pas depuis v0.66.0 |

## 6. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1568** (+12) · `zcrud_study` 1521 · `zcrud_firestore` 770 · `zcrud_flashcard` 586 ·
`zcrud_markdown` 516 · `zcrud_select` 135 · `example` 102. **0 erreur, 0 avertissement.**

### 🔴 La garde jumelle a mordu une TROISIÈME fois
`dateDisplayFormatter` n'était pas re-posé dans la feuille de `zcrud_study` — après `appFileResolver`
et `richTextRenderer`. **Trois ports, trois jours, trois morsures.** Le motif est établi : tout port
ajouté au scope doit être re-posé, et c'est **la garde, pas la vigilance**, qui le tient.

**R3 — 13 injections**, sha avant **et** après chacune, restauration par copie, résidus : greps
négatifs montrés. Le défaut du § 4 a été **réinjecté** et la garde l'a nommé par son nom.

🟢 **Une injection restée verte a révélé une garde vacante** — troisième jour consécutif où un lot
mesure avant de forcer. La garde du mode heure passait pour une bonne raison apparente et une
mauvaise raison réelle ; une seconde garde, sur un cas réellement atteignable, a été ajoutée.
🟢 Un essai rougissant par **compilation** a été **rejeté et rejoué**, pas compté.
🟢 Et les identifiants de test ont été choisis **volontairement non confondables** : `arrivee` ↔
« Arrivée » aurait laissé passer la projection brute.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 7. Trois défauts signalés, non corrigés

* 🔴 **`z_list_column.dart` est la QUATRIÈME copie** de la résolution de libellé — et elle rend la
  **valeur brute** sur un orphelin. Le défaut fermé en v0.65.0 est donc **encore ouvert dans
  `DynamicList`**.
* Le **déclencheur du champ date en édition** affiche encore l'ISO.
* `DynamicEdition` n'observe pas son drapeau de gestion de visibilité (cf. v0.68.0).

Chacun est mesuré, écrit, et laissé à un lot dédié plutôt que glissé ici.

## 8. Non couvert

* L'implémentation `intl` du formateur de dates — spécifiée, pas écrite.
* La résolution d'un `relation` dans une cellule de résumé (§ 1) — non atteignable sans élargir la
  tranche.
* Dettes antérieures : cf. v0.68.0 et les handoffs précédents.
