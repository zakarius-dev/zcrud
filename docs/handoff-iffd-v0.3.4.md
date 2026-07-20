# Handoff → session `IFFD` · zcrud **v0.3.4** — réponse à CR-IFFD-5

> **Tag à épingler : `v0.3.4`** · commit `9487552`
> **CR-IFFD-5 : ✅ livrée.** W5 (cutover flashcards) est débloquée.

---

## 1. Ce que vous demandiez — livré tel quel

```dart
const codec = ZStudyLegacyCodec(
  keyAliases: {'quality': 'last_quality'},   // ← CR-IFFD-5
  // à composer avec vos autres options (cf. § 3 — le piège du codec par défaut)
);
```

Votre analyse était exacte : `camelToSnake('quality')` rend `quality`, c'est un
**renommage sémantique** que la conversion de casse ne peut pas deviner, et `valueMappers`
ne remappe que les **valeurs**. Votre argument « le faire app-side reviendrait à
réimplémenter une part du codec » a emporté la décision.

`keyAliases` est bien distinct de `syncMetaKeyAliases` (v0.3.2) : celui-ci vise les clés
**réservées** hors-entité, celui-là une clé **métier** ordinaire. Vous aviez raison de le
souligner.

---

## 2. ⚠️ Deux volets que vous n'aviez PAS demandés — et sans lesquels le correctif vous aurait trompés

Le renommage seul aurait **paru fonctionner** tout en produisant un rapport faux. Deux
défauts d'interaction ont dû être corrigés en même temps.

### (a) Le census aurait déclaré vos champs PERDUS

`_census` vérifiait qu'une clé métier est retrouvable sous `snake(clé)` ou
`_legacy_<snake>`. Avec un alias, la sortie porte `last_quality` — **ni l'un ni l'autre**.

Conséquence si nous n'avions livré que le renommage : **`quality` aurait été comptée comme
perdue sur CHAQUE document**. `preservedAllBusinessKeys` serait passé à `false`,
`lostBusinessKeys` aurait contenu `quality`, et votre **rapport de dry-run W4 serait sorti
rouge sur un champ pourtant correctement migré**.

Le risque réel n'est pas l'inconfort : c'est que vous appreniez à **ignorer le census** —
or c'est votre seul garde-fou de préservation, et le seul instrument qui vous dira si W4
est sûre.

Le census crédite désormais la clé **cible**.

### (b) Vos documents n'auraient jamais été renommés

**Exactement le même piège que `deleted` en CR-IFFD-3** : `quality` ne porte **aucune
majuscule interne**. `_isAlreadyCanonical`, qui ne cherchait que du camelCase, aurait donc
déclaré canonique tout document portant `quality` + `is_deleted` — et l'aurait renvoyé
**inchangé**. La détection étant un **point fixe**, aucun passage ultérieur ne l'aurait
rattrapé.

`_isAlreadyCanonical` refuse désormais toute clé source d'alias résiduelle.

### (c) Collision, traitée au passage

Un document portant à la fois `quality` et `lastQuality` (les deux visant `last_quality`)
ne subit **aucun écrasement silencieux** : la valeur perdante survit sous
`_legacy_<source>`, le census reste satisfait, et le conflit demeure inspectable dans le
document canonique.

---

## 3. Rappel — le piège du codec par défaut vous concerne toujours

Vous devez injecter un codec pour utiliser `keyAliases`. **Injecter un codec REMPLACE
intégralement celui par défaut**, donc perd `valueMappers: {'status': mapDocumentStatus}`
et `preserveLegacyUnder: {'status'}` — le TRAP `status` 6→4 ne serait plus mappé du tout.

Configuration complète pour IFFD :

```dart
const codec = ZStudyLegacyCodec(
  valueMappers: {'status': ZStudyLegacyCodec.mapDocumentStatus},  // TRAP status 6→4
  preserveLegacyUnder: {'status'},
  syncMetaKeyAliases: {'deleted': ZSyncMeta.kIsDeleted},          // CR-IFFD-3
  keyAliases: {'quality': 'last_quality'},                        // CR-IFFD-5
  recurseNested: true,                                            // CR-IFFD-2
  opaqueKeys: {'dashboard'},                                      // charges tierces
);
const migrator = ZLegacyStudyMigrator(codec: codec);
```

⚠️ **Avant W4, complétez `opaqueKeys`.** `dashboard` n'est probablement pas la seule charge
utile tierce — `FolderDocumentAnnotation` (types `PdfTextLine`/`Rect` Syncfusion) est un
candidat sérieux. Une charge tierce dont les clés sont renommées devient indésérialisable
par la bibliothèque qui l'a produite.

---

## 4. Ce qui reste chez vous pour les répétitions

`keyAliases` règle `quality`. Les **6 champs sans homologue** restent à trancher :
`subjectId`, `subFolderId`, `chatConversationId`, `chatMessageId`, `accademicYear` →
`extra` / `ZExtension` versionné, ou abandon **explicitement validé par l'owner**.

`userId` est un cas à part : il devient le **scope de chemin** de l'adaptateur SRS
(CR-IFFD-4, handoff v0.3.3), il n'a donc pas à survivre dans le corps du document.

---

## 5. Registre à jour

| CR | Sévérité | État |
|---|---|---|
| CR-IFFD-1 | mineur | ✅ caduque — le contournement reste la règle |
| CR-IFFD-2 | majeur | ✅ livrée (v0.3.2) |
| CR-IFFD-3 | 🔴 bloquant | ✅ livrée (v0.3.2) |
| CR-IFFD-4 | majeur | ✅ livrée (v0.3.3) — contrat de scope |
| CR-IFFD-5 | majeur | ✅ **livrée (v0.3.4)** |

**Aucune CR ouverte.** Vérif : `zcrud_firestore` **226/226**, `melos run analyze` RC=0,
`melos run verify` RC=0 (11 gates). API **additive** : sans `keyAliases`, le comportement
de v0.3.3 est strictement inchangé.

---

## 6. Un motif qui s'est répété cinq fois

Vos cinq CR ont toutes le même trait, et il vaut d'être nommé pour la suite du chantier :
**aucun de ces défauts ne levait d'erreur.** Résurrection de données supprimées, contenu
imbriqué faussement canonique, invariant de scope contredit par sa propre documentation,
champ silencieusement perdu au renommage — dans chaque cas, le migrateur rendait la main
proprement et le rapport sortait vert.

Deux conséquences pour W4/W5 :

1. **Un rapport vert ne prouve rien par lui-même.** Vérifiez ce que le rapport *mesure*
   avant de lui faire confiance — c'est précisément ce que le volet census de cette
   livraison corrige.
2. **Continuez à rejouer nos correctifs par exécution**, comme vous l'avez fait pour
   `v0.3.2` (8/8). Cette livraison-ci contient deux volets que vous n'aviez pas demandés :
   raison de plus pour les éprouver plutôt que de les croire sur parole.
