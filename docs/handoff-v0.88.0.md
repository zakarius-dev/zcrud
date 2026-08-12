# Handoff **v0.88.0** — le codegen devient adoptable sur un parc existant

> **Tag à épingler : `v0.88.0`** — répond intégralement au CR DODLP
> `cr-generator-fieldrename-and-unannotated-fields-2026-08-12.md` (ADR-004 Étape 2,
> pilote `Berth`). Paquets porteurs du changement : **`zcrud_generator`**,
> **`zcrud_annotations`**. Les 37 autres paquets sont bumpés sans changement de code.

---

## 1. Constat 1 du CR — `fieldRename` ignoré : **corrigé**

`@ZcrudModel(fieldRename: ZFieldRename.none)` (et `kebab`, `pascal`) est désormais
**honoré** dans la sortie générée. La cause était bien celle que vous supposiez : la
lecture de l'énumération comparait un accesseur *qualifié* (`ZFieldRename.none`) à un nom
nu et retombait toujours sur `snake`.

Deux précisions issues de nos mesures :

- **La lecture que le CR proposait (`objectValue.variable?.name`) est défectueuse** :
  derrière un alias `const` (`const alias = ZFieldRename.kebab;`) elle rend `alias`, pas
  `kebab`. La lecture retenue (dernier segment de l'accesseur qualifié) est prouvée sur
  les quatre stratégies, écrites littéralement **et** derrière alias — le tout par des
  gardes qui assertent la **sortie émise**, pas la fonction interne.
- **Une valeur illisible est un échec de build explicite**, plus jamais un repli muet sur
  `snake` : si la résolution d'annotation se dégrade un jour, le build crie au lieu de
  reproduire la corruption que vous avez décrite.

**Le défaut reste `snake`, bit-à-bit identique** : zéro `*.g.dart` du monorepo n'a changé.
Un hôte qui s'appuyait sur le défaut n'a rien à faire.

### Votre contournement `@ZcrudField(name:)` : neutre, à retirer à votre rythme

Mesuré chez nous : un `name:` explicite **court-circuite la stratégie** — la sortie est
bit-à-bit identique sous les cinq régimes (absent/none/snake/kebab/pascal). Votre
contournement ne s'**additionne** donc pas au correctif : garder les `name:` posés est
inoffensif, les retirer au profit d'un seul `fieldRename: none` est simplement plus sûr
contre la faute de frappe. Votre fixture d'équivalence
(`berth_codegen_equivalence_test.dart`) est l'arbitre idéal pour ce retrait.

## 2. Constat 2 du CR — champs non annotés perdus : **échec de build** (option 1)

Un champ d'instance **public, non annoté, de type non sérialisable** (ni scalaire
supporté, ni `enum`, ni classe `@ZcrudModel`) est désormais un **échec de build** qui
nomme **tous** les champs fautifs du modèle en une passe et cite les remèdes réels :

1. donner au champ un type sérialisable et l'annoter `@ZcrudField` ;
2. annoter le type `@ZcrudModel` **et** le champ `@ZcrudField` (les deux gestes sont
   nécessaires — le premier seul laisserait le champ non écrit) ;
3. déclarer l'exclusion avec **`@ZcrudIgnore`** (nouvelle annotation, exportée par le
   barrel de `zcrud_annotations`).

Sur `Berth`, `lastCrudOperation` et `location` rougiront donc le build au lieu d'être
effacés du document à la première sauvegarde.

### ⚠️ Durcissement cassant — qui est concerné

- **Hôte passif** (aucun modèle `@ZcrudModel`, ou modèles dont tous les champs publics
  sont annotés ou de type sérialisable) : **rien à faire**.
- **Hôte concerné** : tout modèle portant un champ public non annoté de type non
  sérialisable verra son build **rougir à la prochaine génération** — c'est le but, le
  message donne les remèdes champ par champ.
- **Exemptés d'office** (ne rougissent PAS) : les champs **privés** (`_xxx`), les slots
  d'extensibilité d'une classe `ZExtensible` (`extension`, `extra` — déjà couverts par
  leurs propres gardes), les champs statiques, et les champs non annotés de type
  **sérialisable** (contrat inchangé : ignorés en silence — seuls les champs annotés sont
  sérialisés, c'est désormais écrit dans la dartdoc de `@ZcrudModel`).
- La garde couvre aussi les champs concrets **hérités** d'une super-classe ou d'un mixin
  hors SDK (`Berth extends BaseBerth` est protégé ; `ZEntity`, qui n'expose que des
  getters, ne déclenche rien).

Mesure d'étalonnage sur notre propre parc (21 modèles) : **4 champs** ont réclamé
`@ZcrudIgnore`, tous des canaux sérialisés à la main et documentés comme tels.

### `@ZcrudIgnore` dit ce qu'il fait — et refuse la contradiction

`@ZcrudIgnore` signifie « cette donnée n'est **pas** écrite par le codegen » : si elle
doit vivre dans le document, le canal manuel (`toMap` de domaine, slot `extra`) reste à
votre charge. Combiné à `@ZcrudField` ou `@ZcrudId` sur le même champ, c'est un **échec de
build** — aucune résolution silencieuse.

## 3. Constat 3 du CR — `created_at` émis, `updated_at` omis : **délibéré, désormais documenté**

L'asymétrie ne tient pas au type (`DateTime?`) mais au **statut de la clé** :
`updated_at` / `is_deleted` sont des **clés réservées de la couche de synchronisation**
(hors-entité, `ZSyncMeta`). Leur miroir dans l'entité n'est émis que s'il porte réellement
une valeur — l'émettre à `null` déclencherait l'avertissement de collision de sync sur
100 % des écritures. `created_at` est une clé métier ordinaire : toujours émise. La règle
est maintenant écrite au point d'usage (dartdoc de `@ZcrudModel` et du générateur). Aucun
changement de comportement.

## 4. Constat 4 du CR — dates ISO dans `toMap()` : **avertissement ajouté au point d'usage**

La dartdoc de `@ZcrudModel` et de `@ZcrudField.persistAs` dit désormais explicitement : le
`toMap()` généré émet **toute** date en `String` ISO-8601 ; le format natif du backend
(`Timestamp`) est appliqué par le **repository** via `$XxxTimestampFields`. Pendant une
cohabitation, un moteur legacy qui appelle `toMap()` directement écrira des `String` là où
le parc attend des `Timestamp` — passez par le repository, ou convertissez à l'écriture.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `*.g.dart` modifié — la sortie existante est préservée),
`melos run analyze` RC=0, `melos run verify` RC=0 (14 gates), tests rejoués paquet par
paquet depuis leur dossier : generator 149, annotations 10, document 235, exam 79,
flashcard 586 — tous verts, workstreams au repos. Chaque garde neuve a été prouvée
mordante par injection de la régression exacte (rouge **par assertion**), restauration par
copie vérifiée par sha256.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification ci-dessus
a été rejouée localement et constitue la ligne de défense de cette release.

## 6. Recommandation tripwire (pratique lex, à propager)

Si vous aviez contourné un des défauts corrigés ici (le `name:` par champ, un guard local
sur la perte de champs), gardez un test qui **affirme l'ancien comportement** : à la
montée en v0.88.0 il rougit et vous désigne le contournement à retirer — au lieu de croire
ce handoff sur parole.
