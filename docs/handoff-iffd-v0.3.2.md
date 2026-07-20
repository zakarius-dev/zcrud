# Handoff → session de migration `IFFD` · zcrud **v0.3.2**

> Réponse officielle aux demandes `CR-IFFD-1` → `CR-IFFD-3`.
> **Tag à épingler : `v0.3.2`.**

**Vos trois CR ont été reproduites sur disque avant toute correction** — jamais acceptées
sur parole. Les deux qui bloquaient sont **corrigées**.

| CR | Sévérité | État |
|---|---|---|
| CR-IFFD-1 | mineur | ✅ **caduque** — le contournement obligatoire reste la bonne réponse |
| CR-IFFD-2 | majeur | ✅ **LIVRÉ** (v0.3.2) |
| CR-IFFD-3 | 🔴 bloquant | ✅ **LIVRÉ** (v0.3.2) |

**W4 et W5 sont débloquées.**

---

## 1. Reproduction — ce que nous avons mesuré

Sonde exécutée contre `v0.3.1`, avant correctif :

```
CR-IFFD-3 : {name, deleted:true} → {name, deleted:true, is_deleted:false}
            VISIBLE POUR ZCRUD ? true          ← le document supprimé ressuscitait

CR-IFFD-2 : alreadyCanonical = true
            nodes = [{edgeColor:4278190080, outputs:[{edgeColor:1}]}]
                                               ← contenu legacy déclaré canonique
```

Votre analyse était exacte de bout en bout, y compris sur le point le plus grave : **le
census R26 était satisfait**, le migrateur ne levait rien, le rapport sortait vert. Aucun
garde-fou existant ne voyait passer ces deux pertes.

*(Au passage, notre sonde a elle-même buté sur `CR-1` — source `path` vs `hosted`.
Confirmation involontaire que la correction de recette de `v0.3.1` était juste.)*

---

## 2. CR-IFFD-3 — `syncMetaKeyAliases`

`ZStudyLegacyCodec` accepte désormais une table d'alias : une clé legacy déclare la clé
**réservée** qu'elle désigne réellement.

```dart
const codec = ZStudyLegacyCodec(
  // ⚠️ NE PAS OUBLIER — cf. § 4, piège d'usage
  valueMappers: {'status': ZStudyLegacyCodec.mapDocumentStatus},
  preserveLegacyUnder: {'status'},

  // CR-IFFD-3 : votre soft-delete générique s'appelle `deleted`
  syncMetaKeyAliases: {'deleted': ZSyncMeta.kIsDeleted},
);
```

Comportement : la clé legacy est **consommée** (renommée, jamais dupliquée dans le corps),
et sa valeur brute est préservée sous `_legacy_deleted` (AD-4, zéro perte).

### Deux décisions de conception à connaître

**Fail-closed sur valeur ininterprétable.** Une valeur ni `bool` ni `null` (ex. `'oui'`)
est traitée comme **supprimée**. Le choix est délibérément asymétrique : masquer à tort est
réparable — la donnée est intacte et la valeur brute survit sous `_legacy_` — tandis que
**ressusciter** expose un contenu que l'utilisateur avait explicitement retiré,
potentiellement aux autres membres d'un dossier `sharedWith`. `null` → `false` (absent
signifie non supprimé, cohérent avec votre `map["deleted"] ??= false`).

**L'alias PRIME sur une clé réservée déjà présente.** Ce point vient d'un échec de notre
propre test de garde. Sur un corpus **partiellement migré**, un document porte à la fois
`deleted:true` (votre vérité legacy) et un `is_deleted:false` ajouté à tort par un passage
antérieur. Notre première version laissait le passthrough de la clé réservée écraser
l'alias : **la corruption l'emportait sur l'intention réelle**. Les alias sont désormais
appliqués après la boucle et gagnent toujours.

Conséquence pour vous : **une reprise de migration sur un corpus déjà partiellement traité
par une version défectueuse répare les documents au lieu de les figer.**

---

## 3. CR-IFFD-2 — profondeur

**Détection corrigée (sans opt-in, s'applique toujours).** `_isAlreadyCanonical` est
désormais **récursive** et refuse tout document portant encore une clé d'alias. Vos deux
faux positifs sont fermés :

- premier niveau propre + contenu imbriqué legacy ⇒ **n'est plus déclaré canonique** ;
- clé `deleted` encore présente (aucune majuscule interne) ⇒ **n'est plus sautée**.

Votre argument a emporté la décision : *un faux négatif coûte un retraitement — le
migrateur est idempotent — un faux positif perd la donnée*. La détection est maintenant
volontairement stricte.

**Conversion récursive (opt-in).** `recurseNested: true` fait descendre le renommage de
clés et la normalisation des dates `int` millis → ISO à **toute profondeur**.
`false` par défaut : rétro-compatibilité stricte.

```dart
const codec = ZStudyLegacyCodec(
  valueMappers: {'status': ZStudyLegacyCodec.mapDocumentStatus},
  preserveLegacyUnder: {'status'},
  syncMetaKeyAliases: {'deleted': ZSyncMeta.kIsDeleted},
  recurseNested: true,
  opaqueKeys: {'dashboard'},   // ← lisez le paragraphe suivant
);
```

### ⚠️ `opaqueKeys` — nous avons refusé de faire ce que vous demandiez, et voici pourquoi

Votre CR cite `dashboard` (sérialisation `flutter_flow_chart`) comme *« structure tierce
entière, dont aucune clé ne sera convertie »*, présenté comme un défaut à corriger.

**C'en est un — mais la convertir serait pire.** Renommer `elementId` → `element_id` à
l'intérieur d'une charge utile produite par `flutter_flow_chart` la rendrait
**indésérialisable par la bibliothèque elle-même**. La récursion aveugle aurait détruit vos
mindmaps au lieu de les migrer.

D'où `opaqueKeys` : vous déclarez les clés de premier niveau dont la valeur est une charge
utile tierce, et la récursion les enjambe. Pour `MindmapModel`, `dashboard` en fait partie ;
`nodes` **non** (c'est votre structure, elle doit être convertie).

⚠️ **À vous d'inventorier** les autres charges utiles tierces avant W4 —
`FolderDocumentAnnotation` (types `PdfTextLine`/`Rect` Syncfusion) est un candidat probable.

**Portées non couvertes, à traiter côté IFFD** : `valueMappers` et `preserveLegacyUnder`
restent **de premier niveau uniquement** (ils désignent des champs de document, pas des
feuilles arbitraires). Et la récursion ne convertit **ni les `Timestamp` Firestore bruts,
ni vos deux formats de couleur** — vos « quatre conventions incompatibles » (§ 3.2 de votre
inventaire) restent entièrement à votre charge, entité par entité.

---

## 4. ⚠️ Le piège d'usage qui vous attend au premier câblage

Découvert en écrivant nos gardes — notre test a rougi dessus.

**Injecter un `codec` REMPLACE intégralement celui par défaut du migrateur**, et perd donc
sa configuration IFFD implicite : `valueMappers: {'status': mapDocumentStatus}` et
`preserveLegacyUnder: {'status'}`. Sans les redéclarer, **le TRAP `status` 6→4 n'est plus
mappé du tout** : `embedded` sort tel quel au lieu de `ready`.

Or vous **devez** injecter un codec pour utiliser les alias. **Redéclarez donc toujours les
quatre options ensemble**, comme dans l'exemple du § 3.

---

## 5. CR-IFFD-1 — caduque, mais la règle reste

`ZStudyLegacyCodec.toCanonical` n'est toujours pas idempotent sur `status` — c'est
volontaire : le mapper 6→4 est une fonction de conversion, pas un point fixe.
`ZLegacyStudyMigrator` porte la garde, et elle est désormais **plus robuste** (détection
récursive + alias).

🚫 **La règle ne change pas : n'appelez JAMAIS `ZStudyLegacyCodec` nu sur un corpus.
Toujours `ZLegacyStudyMigrator`.**

---

## 6. Gardes livrées

`packages/zcrud_firestore/test/z_study_migrator_sync_alias_test.dart` — **11 tests** :
résurrection, document vivant, absent, fail-closed, corpus partiellement migré, imbriqué
non-canonique, dates profondes, `opaqueKeys`, récursion désactivée par défaut, idempotence
avec suppression conservée, AD-10 sur entrées hostiles.

Non-régression : `zcrud_firestore` **220/220**, `melos run verify` **RC=0** (11 gates).

---

## 7. Ce que nous n'avons PAS corrigé, et qui reste chez vous

Votre inventaire relève des points **hors périmètre zcrud** — ils sont justes et méritent
d'être suivis, mais aucun tag ne les résoudra :

- **Quatre conventions de sérialisation incompatibles** (couleur `String` vs `int`, date
  `Timestamp` vs millis) — conversion entité par entité, à votre charge.
- **`fromMap` qui fabriquent des valeurs** (`DateTime.now()`, `randomColor()`,
  `randomString()`) — ils **fausseront votre census** en surestimant la complétude. Votre
  recommandation de migrer ces comportements **à l'identique**, et de corriger dans des
  stories **séparées et postérieures**, est la bonne : corriger pendant la migration rendrait
  toute régression post-cutover indémêlable.
- **Collection parasite `Map<String, dynamic>`** (38 écrans mal typés) — à vérifier en base
  avant W4 ; ces documents ne doivent pas entrer dans le corpus.
- **`firestore.rules` totalement ouvert** — argument de plus pour le dry-run W4.
- **Baseline non verte** (8 des 11 tests ne compilent pas, `font_awesome_flutter` vs
  `IconData` `final class`) — votre story W0-0 est le bon préalable.

Votre remarque sur le statut « hors périmètre » de `zcrud_html`/`zcrud_media` est
**acceptée** : c'était une décision prise **pour lex_douane**, motivée par son
`file_picker 12.0.0-beta.5`. IFFD étant en `^10.3.8`, elle **ne s'applique pas** — ces deux
packages vous sont ouverts.

---

## 8. Un mot sur votre reconnaissance

Elle a trouvé, en amont de toute ligne de code, deux pertes de données silencieuses qu'aucun
test existant ne détectait — dont une avec une dimension de confidentialité. La démarche qui
l'a permis mérite d'être conservée pour la suite du chantier : **exécuter plutôt que
supposer**, et se méfier d'un rapport vert.

Vous en avez d'ailleurs fait vous-mêmes la démonstration sur votre propre repo :
`flutter analyze` vert sur 8 fichiers de test qui ne compilent pas. Le corollaire vaut pour
les deux sessions — **seuls `flutter test` et un build réel font foi**.
