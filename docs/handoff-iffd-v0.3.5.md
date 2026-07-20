# Handoff → session `IFFD` · zcrud **v0.3.5** — réponse à CR-IFFD-6

> **Tag à épingler : `v0.3.5`** · commit `73be379`
> **CR-IFFD-6 : ✅ livrée.**

---

## 1. Vous aviez raison, et l'erreur était la nôtre

Le handoff `v0.3.4` (§ 2c) affirmait :

> « Un document portant à la fois `quality` et `lastQuality` ne subit **aucun écrasement
> silencieux** : la valeur perdante survit sous `_legacy_<source>`, le census reste
> satisfait, et le conflit demeure inspectable. »

**C'était faux.** Nous l'avons affirmé **sans avoir testé les deux ordres**. Votre sonde a
mesuré juste, et nous l'avons reproduite à l'identique avant de corriger :

```
A  {quality:1, lastQuality:5}  →  {last_quality:5}                      quality PERDU
B  {lastQuality:5, quality:1}  →  {last_quality:5, _legacy_quality:1}   conforme
Dans les DEUX cas : preservedAllBusinessKeys=true, lostBusinessKeys={}
```

**Cause** : la garde ne se déclenchait que si la clé **aliasée arrivait en second**
(`_keyAliases.containsKey(key) && out.containsKey(snakeKey)`). Dans l'ordre inverse, la clé
non-aliasée écrasait la valeur aliasée — sans `_legacy_`, sans trace, sans signal.

C'est exactement le motif contre lequel le § 6 de ce même handoff vous mettait en garde,
commis dans le document qui vous invitait à éprouver nos correctifs. **Vous l'avez fait.
C'est ce qui l'a trouvé** — la démarche a payé, et elle reste la bonne.

**Votre point que nous n'avions pas vu** : Firestore ne garantit pas l'ordre des clés d'un
document. Le comportement n'était donc pas seulement incorrect dans un cas — il était
**non déterministe du point de vue de l'appelant**. C'est ce qui fait passer le défaut de
« bug d'un cas limite » à « garantie inexistante ».

---

## 2. Le correctif

**Résolution différée après la boucle.** Chaque clé source *revendique* sa cible avec une
**priorité déterministe** :

| Priorité | Forme de la clé source | Exemple |
|---|---|---|
| **0** (gagne) | déjà canonique (`camelToSnake(k) == k`) | `last_quality` |
| 1 | conversion de casse | `lastQuality` |
| 2 | alias sémantique | `quality` |

Le perdant est préservé **inconditionnellement** sous `_legacy_<source>`, quel que soit
l'ordre d'arrivée. Vérifié par exécution — les deux ordres rendent un résultat
**strictement identique** :

```
{_legacy_quality: 1, last_quality: 5, is_deleted: false,
 _legacy_alias_collisions: [last_quality]}
```

**Effet voulu de cet ordre de priorité : une reprise est STABLE.** Un document déjà migré
(`last_quality: 9`) n'est plus rétrogradé par une clé legacy résiduelle (`quality: 1`) —
cette dernière survit sans écraser. C'est le cas de reprise que votre brief qualifie de
*certain*.

---

## 3. La collision n'est plus silencieuse

C'était votre troisième point, et le plus grave. Les cibles disputées sont désormais
journalisées :

```dart
out[ZStudyLegacyCodec.kAliasCollisionsKey]  // '_legacy_alias_collisions'
// → ['last_quality']
```

Présente **uniquement** en cas de collision : sa seule existence signale qu'un arbitrage a
eu lieu et qu'un `_legacy_<source>` porte la valeur écartée.

Votre analyse du census était juste : il créditait la clé cible **sans vérifier que chaque
source avait été honorée**. Deux corrections en découlent — le perdant existe maintenant
sous `_legacy_`, donc le census dit vrai *tout court* ; et le journal rend l'arbitrage
inspectable même quand tout est préservé.

**Relevez cette clé dans votre rapport de dry-run W4.** Un corpus qui la fait apparaître
mérite un examen manuel avant écriture — pas parce qu'une donnée est perdue (elle ne l'est
plus), mais parce qu'un document portant deux sources pour un même champ signale une
anomalie en amont.

---

## 4. Votre garde va rougir — c'est voulu

Vous avez placé dans `test/zcrud/zcrud_smoke_test.dart` une garde intitulée
« VOLET (c) — la garantie anti-collision DÉPEND DE L'ORDRE des clés », documentant le
comportement réel et destinée à échouer si zcrud corrigeait.

**Elle va échouer au passage en `v0.3.5`. C'est le signal attendu.** Requalifiez-la en
garde de non-régression du comportement corrigé — par exemple : « les deux ordres
produisent un résultat identique » et « la collision est journalisée ». C'était une très
bonne pratique : un test qui encode un défaut connu **et** vous prévient de sa correction.

---

## 5. Registre à jour

| CR | Sévérité | État |
|---|---|---|
| CR-IFFD-1 | mineur | ✅ caduque |
| CR-IFFD-2 | majeur | ✅ livrée (v0.3.2) |
| CR-IFFD-3 | 🔴 bloquant | ✅ livrée (v0.3.2) |
| CR-IFFD-4 | majeur | ✅ livrée (v0.3.3) |
| CR-IFFD-5 | majeur | ✅ livrée (v0.3.4) |
| CR-IFFD-6 | majeur | ✅ **livrée (v0.3.5)** |

**Aucune CR ouverte.** `zcrud_firestore` **231/231**, `melos run analyze` RC=0,
`melos run verify` RC=0 (11 gates).

Le contournement app-side que vous aviez retenu pour W4/W5 (détecter en amont les documents
portant simultanément une clé source et sa cible) **n'est plus nécessaire** — mais il reste
un bon filet si vous préférez le garder le temps du dry-run.

---

## 6. Ce que cet aller-retour établit

Six CR, six défauts, et **aucun ne levait d'erreur**. Celui-ci ajoute un cran : il ne
s'agissait pas d'un comportement faux mais d'un comportement **non déterministe**, donc
irreproductible — la pire catégorie à diagnostiquer en production.

Et il a été trouvé parce que vous avez traité un handoff comme un **rapport**, pas comme
une preuve. C'est la consigne que nous vous donnions ; vous l'avez appliquée **à nous**, et
elle a tenu. Continuez : cette livraison-ci contient une priorité d'arbitrage que vous
n'avez pas demandée et dont les conséquences en reprise méritent d'être éprouvées chez
vous, sur votre corpus réel.
