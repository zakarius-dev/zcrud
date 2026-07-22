# Handoff → sessions `lex_douane` **et** `IFFD` · zcrud **v0.4.3**

> **Tag à épingler : `v0.4.3`.**
> **Ce n'est pas une réponse à une CR** : c'est une passe de consolidation, et elle a
> découvert un défaut d'idempotence **que vos 9 CR sur ce package avaient toutes manqué**.
> Si vous migrez un corpus, lisez le § 1.

---

## 1. 🔴 Un défaut d'idempotence corrigé — il vous concerne tous les deux

### Le symptôme

```
status: 'embedded'  →  'ready'  (passe 1)  →  'uploading'  (passe 2)
```

Un document dont le `status` a été correctement migré est **rétrogradé** au passage suivant,
puis reste stable sur une valeur fausse.

### Le déclencheur — plus large que CR-IFFD-7

CR-IFFD-7 avait identifié ce piège via `opaqueKeys`. Le correctif d'alors ne traitait que
**la moitié** du problème : la détection enjambait les sous-arbres opaques, mais elle
continuait de **descendre dans toutes les autres structures imbriquées**, y compris quand
`recurseNested` est `false` — c'est-à-dire quand la conversion, elle, **ne descend pas**.

Conséquence : **il suffit d'un contenu imbriqué en camelCase**, sans aucun `opaqueKeys`,
pour que le document soit déclaré non canonique à jamais, re-migré à chaque passage, et ses
`valueMappers` réappliqués.

**Configurations touchées** : toute config déclarant des `valueMappers` (donc `status`) avec
`recurseNested: false` — soit le cas par défaut. **IFFD** : votre config déclare
`recurseNested: true`, vous étiez donc protégés sur ce chemin précis, mais pas sur les
sous-structures que la récursion n'atteint pas. **lex** : si vous migrez un corpus avec des
`valueMappers`, vérifiez.

### La règle, désormais complète

> **La détection doit refléter la conversion.** On n'exige la canonicité en profondeur que
> si la conversion y descend (`recurseNested`). Sinon, seul le premier niveau — le seul que
> le codec transforme — répond de sa casse.

### Ce que vous devez faire

Si vous avez **déjà exécuté une migration** avec une config à `valueMappers` : les documents
ayant subi ≥ 2 passages peuvent porter un `status` rétrogradé. **`_legacy_status` conserve la
valeur d'origine** (`preserveLegacyUnder`) — la réparation est donc possible sans perte, en
re-dérivant `status` depuis `_legacy_status`. Vérifiez avant d'écrire.

---

## 2. Comment il a été trouvé — et pourquoi ça change la suite

`ZStudyLegacyCodec` / `ZLegacyStudyMigrator` ont reçu **9 correctifs** issus de vos CR. Trois
d'entre eux corrigeaient des **régressions introduites par un correctif précédent** :
`keyAliases` avait cassé le census, `opaqueKeys` avait cassé l'idempotence, la garde
anti-collision dépendait de l'ordre des clés.

La cause n'était pas la qualité des correctifs mais **la forme de la couverture** : des
gardes **par CR**, chacune exerçant **une** option sur **le** document qui motivait la
demande. Les **croisements** n'étaient jamais couverts.

D'où un **banc d'invariants** (`z_migration_invariants_bench_test.dart`) : **7 configurations
× 12 formes de documents × 6 invariants universels** — les propriétés que chacune de vos CR
violait :

| | Invariant | CR correspondante |
|---|---|---|
| I1 | `migrate ∘ migrate == migrate` | CR-IFFD-1, CR-IFFD-7 |
| I2 | ne throw jamais (AD-10) | — |
| I3 | indépendant de l'ordre des clés | CR-IFFD-6 |
| I4 | toute valeur métier retrouvable | CR-IFFD-2, CR-IFFD-6 |
| I5 | un document supprimé ne renaît jamais | CR-IFFD-3 |
| I6 | le dry-run ne mute pas l'entrée | — |

**434 assertions.** L'oracle de I4 raisonne sur les **valeurs**, pas sur les clés —
délibérément **indépendant du census** : le vérifier avec la logique du census aurait été
tautologique.

### Le banc s'est lui-même fait prendre en défaut

Il est passé vert du premier coup. Suspect. Nous y avons **injecté la régression CR-IFFD-7** :
**il ne l'a pas vue** — aucune forme de document ne croisait *charge opaque* et *`status`*.
Après ajout de deux formes croisées, il a rougi — et pas seulement sur l'injection : sur des
configurations **sans** `opaqueKeys`. C'était le vrai bug du § 1.

**La leçon vaut pour vos propres bancs** : un banc combinatoire se valide comme un test — en
lui injectant la régression qu'il est censé attraper. S'il ne rougit pas, c'est votre matrice
qui a un trou, pas votre code qui est sain.

---

## 3. Second volet — audit des réimplémentations

Déclenché par une observation de l'owner : `zcrud_study` avait réimplémenté un calcul de
grille alors que `zcrud_responsive` — **déjà dépendu** — l'exposait en mieux (corrigé en
`v0.4.2`).

**Audit du monorepo : négatif.** Aucun autre cas. Un seul point mineur corrigé : deux
constantes M3 (`560` dp, `0.9`) dupliquées entre `zcrud_navigation` (privées) et `zcrud_get`,
avec un commentaire disant lui-même « répliquent ». Source promue en
**`ZAdaptivePresenterDefaults`**, copie supprimée — deux copies d'une même décision sont
deux occasions de diverger.

⚠️ **Le réflexe qui manquait, et qui vaut pour vous** : avant d'écrire une primitive,
vérifier ce que les packages **déjà dépendus** exposent. C'est la règle « ne réimplémente
rien » que nous vous imposons, et que nous avions nous-mêmes enfreinte.

---

## 4. Vérification

`zcrud_firestore` **682/682** (dont 434 du banc) · `zcrud_navigation` 33/33 ·
`zcrud_get` 74/74 · `melos run analyze` RC=0 · `melos run verify` RC=0.

Aucune rupture d'API. `ZAdaptivePresenterDefaults` est un **ajout** ; le correctif
d'idempotence **restreint** la détection (moins de faux « non canonique »), il ne peut donc
que réduire le nombre de re-migrations.

---

## 5. Registre — aucune CR ouverte

| Session | CR | État |
|---|---|---|
| lex_douane | CR-1 → CR-11 | ✅ toutes traitées (2 refusées avec raison) |
| IFFD | CR-IFFD-1 → CR-IFFD-10 | ✅ toutes traitées |

Continuez à émettre des CR, et continuez à **éprouver par exécution** ce que nous livrons :
deux de vos CR ont réfuté des affirmations écrites dans nos propres handoffs, et celle-ci
corrige un défaut qu'aucune revue de code n'avait vu.
