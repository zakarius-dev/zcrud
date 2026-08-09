# Handoff **v0.60.1** — le catalogue des types de champ, et deux affirmations corrigées

> **Tag à épingler : `v0.60.1`** · **aucune ligne de `lib/` modifiée** — donc **aucun hôte, passif
> ou non, ne bouge d'un pixel**. Documentation + gardes uniquement.

---

## 1. La découvrabilité — votre § 7, livré sous une forme qui ne peut pas mentir

**Votre constat est exact, et pire que vous ne le disiez.** Mesuré :
`EditionFieldType.dateRange` + `ZDateRangeFieldWidget` existent depuis le commit `ae3a6ad` du
**2026-07-18**, tag **v0.10.0**. Vous consommez v0.59.0 — **49 mineures plus tard** — et votre propre
dartdoc affirme *« zcrud n'a pas de type `dateRange` dans son catalogue »*
(`z_date_range_field.dart:3`, doublé dans `anciennes_valeurs_filter_form.dart:19`).

🔵 **Nous avons cherché d'autres cas : il n'y en a qu'un.** Greps négatifs montrés — IFFD n'enregistre
que les extensions officielles (`registerZMarkdownFields`, `registerZFlashcardEditors`), lex n'utilise
pas le moteur d'édition, DLCFTI ne dépend pas de zcrud. Votre `ZDateRangeField` est **le seul**
doublon du parc. Le problème n'est donc pas systémique — mais il a coûté un widget, et il en aurait
coûté d'autres.

### Livré : `docs/zcrud-field-type-catalog.md`
Une seule question, une seule réponse : **« ce type existe-t-il déjà, et que dois-je ajouter pour
l'obtenir ? »** — type, famille, statut, classe de configuration, paquet satellite et sa fonction
d'enregistrement.

🔴 **Le document est DÉRIVÉ du code, pas écrit à la main** — parce qu'un tableau de quarante lignes
maintenu à la main devient faux au premier type ajouté, et que ce dépôt s'est déjà fait mordre par
des dartdoc périmés. Trois propriétés, chacune **prouvée** :

| Propriété | Preuve |
|---|---|
| **Exhaustivité forcée** | le catalogue est un `switch` **sans `default`**. Une valeur ajoutée à l'enum le casse **à la compilation**. Prouvé par injection isolante : la valeur classée dans `familyOf` laisse le socle vert et **seul le catalogue casse** |
| **Synchronisation prouvée** | la garde lit le fichier `readAsStringSync()` **tel qu'il est sur disque**, sans jamais régénérer avant de comparer. **Un caractère** ajouté au titre la fait rougir |
| **Statut mesuré, pas déclaré** | il n'existe **aucun champ où écrire un statut** : c'est un getter dérivé de `familyOf(type)`. Annoncer « supporté » un type que le dispatcher route en repli est **inexprimable** |

### 🔴 Trois pièges traités explicitement
* **`stepper` est `unsupported` — et pleinement disponible.** Une table qui s'arrêterait au verdict du
  dispatcher vous ferait fuir une fonctionnalité qui existe. Le catalogue le classe « cœur (autre
  chemin) » et nomme `zPartitionFieldsIntoSteps` + `ZStepperEdition`, avec la raison de l'écart. Une
  garde rougit si ce chemin alternatif disparaît de l'entrée.
* **Satellites** : paquet **et** fonction d'enregistrement, tous deux vérifiés sur disque (le paquet
  doit exister, mentionner le `kind`, **et** exposer le registrar annoncé).
  🔵 **Deux honnêtetés que recopier votre § 7 aurait ratées** : `zcrud_intl` (téléphone, pays) et
  `zcrud_geo` **n'ont pas** de registrar global. Le catalogue le dit, au lieu d'inventer un
  `registerZIntlFields` qui n'existe pas.
* **Non servis** : `icon` et `custom` — aucun paquet ne les enregistre (grep négatif montré),
  contournement `ZWidgetRegistry.register` documenté.

🔵 **Mesure non triviale trouvée en chemin** : **`dateRange` n'a aucune classe de configuration** — le
dispatcher n'en lit pas, donc pas de bornes `firstDate`/`lastDate` comme `date`. Si votre widget
maison posait des bornes, c'est une **perte réelle** au moment de le retirer. Gardé.

### Coût
**Zéro octet au runtime.** Le catalogue et son renderer vivent sous `test/support/`, pas dans `lib/` —
grep négatif montré. Ce choix règle trois contraintes d'un coup : coût nul, **FR-26 par
construction** (la prose destinée aux développeurs est *inatteignable* depuis une application, pas
seulement déconseillée), et **AD-1 sans arête** (le nom du satellite est une `String` inerte, jamais
un `import` — `git diff --stat -- packages/zcrud_core/lib` est **vide**).

## 2. 🔴 Deux affirmations de notre handoff v0.60.0, corrigées

Le § 8 de `handoff-v0.60.0.md` annonçait deux points « non traités ». **Les deux étaient faux**, et
la correction est écrite dans ce document-là aussi :

* **Le stepper *data-driven inline* était DÉJÀ livré.** `z_step_partition.dart` — 344 lignes,
  exporté — fait exactement ce que votre G1 demandait : liste **plate** de `ZFieldSpec` annotés
  `ZStepFieldConfig` → `List<ZEditionStep>`, par une fonction **pure et totale**, consommée telle
  quelle par `ZStepperEdition`. Le blocage de votre écran agent est levé depuis plus longtemps que
  nous ne le pensions. **Rien à attendre de nous** — et c'est notre erreur de vous avoir dit le
  contraire, y compris quelques heures plus tôt.
* **La table type → statut** est le § 1 ci-dessus.

⇒ **vos cinq CR sont couvertes.**

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **tous** | **rien** — aucune ligne de `lib/` n'a changé, aucune signature, aucun rendu |
| **DODLP** | ⚠️ vous pouvez retirer votre `ZDateRangeField` maison — **mais qualifiez d'abord** : il imite votre ancien `selectDateRange`, donc **l'apparence de vos écrans de recherche changera**, et le type du socle **n'expose pas de bornes**. Ce n'est pas « rien à faire », c'est « à mesurer avant » |
| **tous** | branchez le catalogue dans votre réflexe : avant d'écrire un champ maison, une recherche dans `docs/zcrud-field-type-catalog.md` |

## 4. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués après le bump. `zcrud_core` **1380** (+10), `dart analyze` RC=0 avec un `diff` de
logs **identique** avant/après (mêmes 10 infos). Aucune signature publique modifiée.

**R3 — 10 injections, toutes rouges d'ASSERTION.** L'exhaustivité, elle, est garantie **à la
compilation** : sa preuve est un rouge de compilation, assumé et **non compté** comme garde
d'assertion.

🟢 **Un incident de campagne qui mérite d'être connu** : **trois injections n'avaient pas pris** au
premier passage (échappement de heredoc). Le `sha256` du fichier était **inchangé** — donc le vert
observé n'était pas le vert d'une garde faible, c'était le vert d'un fichier **jamais modifié**.
Détecté par les sha, les trois ont été rejouées individuellement avec une assertion sur la présence
du motif dans la source, et rougissent bien. **Sans la discipline des empreintes, trois gardes
auraient été déclarées mordantes sans l'avoir jamais été.**

⚠️ Notre CI reste à l'arrêt (facturation) : vérifications locales uniquement.

## 5. Non couvert

* Pas d'API runtime interrogeable (`ZFieldTypeCatalog` public) — incompatible avec le coût nul et
  avec FR-26. Si vous en voulez une, dites-le : c'est un choix, pas une limite.
* Les *seams* listés ne sont pas exhaustifs : seulement ceux **dérivables et vérifiables** contre
  `ZcrudScope`. Recopier votre liste aurait recréé le tableau manuel que ce livrable remplace.
* Dettes antérieures : cf. v0.60.0 — dont les **quatre axes visibles** de ce lot-là, qui restent la
  vraie chose à lire avant de bumper.
