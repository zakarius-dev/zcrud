# Handoff → session `IFFD` · zcrud **v0.5.1** — AD-57, CR-IFFD-15/16 revisitées, CR-IFFD-17

> **Tag à épingler : `v0.5.1`**
> Deux tags intermédiaires existent (`v0.4.6`, `v0.5.0`) : épinglez **`v0.5.1`**, qui les contient.

| CR | État |
|---|---|
| CR-IFFD-12 · 13 · 14 | ✅ livrées (`v0.4.6`) |
| CR-IFFD-15 | ✅ livrée (`v0.4.6`), puis **refondue** en `v0.5.0` — voir §1 |
| CR-IFFD-16 | ✅ livrée (`v0.4.6`) |
| CR-IFFD-17 | ✅ **livrée (`v0.5.1`)** |

---

## 1. 🔴 LISEZ CECI EN PREMIER — nous avons refusé CR-IFFD-11 §1 pour une raison FAUSSE

Dans le handoff `v0.4.5`, nous avons refusé la grille réordonnable en écrivant que
`reorderable_grid_view` était **« explicitement refusé par AD-1 »**. Puis, en livrant CR-IFFD-15,
nous avons écrit un **drag-and-drop bidimensionnel à la main** pour contourner cet interdit.

**Cet interdit n'existe pas.** AD-1 dit :

> « `zcrud_core` ne déclare **aucune** dépendance vers un autre package zcrud ni vers
> Firebase/Syncfusion/Quill/Maps. »

Il contraint **le cœur**, pas les satellites. L'affirmation venait d'un **commentaire de code**,
reprise dans deux handoffs, **jamais confrontée au texte de l'AD**. Et elle était contredite par
**quinze satellites** qui dépendaient déjà de paquets pub.dev — `graphite`, `pinput`,
`html_editor_enhanced`, `image_cropper`, `confetti`. Si `confetti` passait, un moteur de
drag-and-drop passait *a fortiori*.

Vous nous aviez demandé de trancher entre « ouvrir AD-1 à un paquet tiers » et « implémenter
maison ». Nous avons tranché **sur une lecture erronée de notre propre architecture**, puis
facturé le coût de ce choix à la livraison.

### Ce qui a été fait en conséquence — AD-57

Une décision d'architecture écrit désormais la règle, pour qu'elle ne se reforme pas :

> **AD-57** — un satellite PEUT dépendre d'un paquet tiers, sous **trois conditions
> cumulatives** : (1) jamais dans `zcrud_core` ; (2) **derrière une abstraction** portée par le
> paquet léger (patron `ZCodec`/AD-7, `ZListRenderer`/AD-8), aucun type tiers dans une signature
> publique du socle ; (3) **défaut zéro-dépendance obligatoire** — un consommateur qui n'installe
> pas le satellite garde une capacité **dégradée, jamais absente**.

Elle énonce aussi le **coût de build à peser** : un tiers embarquant du natif s'impose au build
de *toutes* les applications, la distribution étant en dépendance git.

### Ce que ça change pour vous, concrètement

Le drag-and-drop maison **n'est pas jeté** : il devient le **repli garanti**.

```dart
// Rien à faire : sans injection, le repli zéro-dépendance s'applique.
ZStudyToolsSectionSpec(onReorder: …, crossAxisMinItemWidth: 300)

// Pour l'ergonomie d'un paquet de l'écosystème :
//   pubspec : zcrud_reorder (git, tag v0.5.1)
ZcrudScope(
  reorderRenderer: const ZPackageReorderRenderer(),
  child: …,
)
```

Le port `ZReorderRenderer` accepte aussi **votre propre implémentation** — c'était la seconde
moitié de votre proposition, et elle est ouverte.

⚠️ **Le port impose ce que le paquet tiers ne donnait pas.** `reorderable_grid_view` n'offre que
l'appui long, **zéro action sémantique** : inatteignable au lecteur d'écran. La voie accessible
est donc exigée par le **contrat du port** et ajoutée par le satellite. Sans cela, chaque backend
l'aurait oubliée à sa façon — c'est exactement le risque que vous souligniez sur AD-13.

---

## 2. `zcrud_dnd` — le dépôt de fichiers de l'OS, **et pourquoi il est à part**

Nouveau satellite opt-in, adossé à `super_drag_and_drop` : déposer un fichier de l'explorateur
sur une carte de dossier, recevoir un contenu d'une autre application.

```dart
ZcrudScope(
  dropRegionRenderer: const ZNativeDropRegionRenderer(),
  child: …,
)
```

⚠️ **Il est isolé délibérément, et vous devez connaître le coût avant de l'ajouter** :
`super_drag_and_drop` embarque du **code natif (Rust)** et télécharge des **binaires
précompilés** au build. Comme zcrud est distribué en dépendance git — sans étape de publication
qui absorberait ce coût — cette contrainte s'imposerait à toute app qui en hérite. Un hôte qui
veut seulement **réordonner** ne doit pas la payer. D'où deux paquets, pas un.

Sans le satellite, `ZNoDropRegionRenderer` rend le contenu **inchangé** : pas de bordure
« déposez ici » qui mentirait sur une capacité absente (AD-45).

⚠️ **Limite assumée, et nous préférons vous la dire** : les chemins de dépôt natif ne sont **pas
testables** sous `flutter test` — aucune session de glissement système n'est fabricable sans
engine natif. Sont couvertes les **règles** (traduction des formats, filtrage, robustesse AD-10,
paresse de lecture) ; ne le sont pas l'adaptateur natif lui-même ni le survol réel. **Éprouvez-le
sur appareil avant de vous y fier.**

`ZDroppedItem.readBytes` est une **fonction**, pas des octets : sur plusieurs plateformes le
fichier n'existe pas au moment du dépôt (fichier « virtuel »), et le matérialiser d'office
chargerait en mémoire des données que vous ne voulez peut-être pas.

---

## 3. CR-IFFD-17 — récurrence de rappel généralisée

Votre analyse était juste, y compris sur le point qui décide de tout : **les deux modèles ne sont
pas inter-convertibles**.

```dart
ZExam(
  reminderEnabled: true,
  reminderRecurrence: ZReminderRecurrence.weekly({DateTime.monday, DateTime.friday}),
)
// ou les deux :
ZReminderRecurrence(daysBefore: [1, 7], weekdays: {DateTime.monday})
```

`ZReminderRecurrence` couvre les deux familles ; `isApproaching` passe **par elle**, jamais plus
par les champs bruts. Votre modèle hebdomadaire devient donc **visible à la logique temporelle du
socle** — c'était l'objet de la demande. **Vous pouvez retirer** le contournement
`extra['<prefixe>_reminder_days']`.

**Rétro-compatibilité stricte** : `reminderDaysBefore` est **inchangé** et reste seul en vigueur
tant que `reminderRecurrence` est `null`. Une app qui n'utilise que les seuils relatifs n'a rien
à faire.

**Trois décisions que nous avons prises et qu'il vaut mieux connaître :**

1. **La récurrence explicite REMPLACE les seuils bruts** (elle ne s'y ajoute pas) — sinon migrer
   déclencherait des rappels que vous n'avez pas demandés. Elle peut porter ses propres
   `daysBefore`.
2. **Une échéance passée n'arme aucune des deux familles.** Rappeler chaque lundi un examen déjà
   passé n'a pas de sens. Si vous voulez des rappels post-échéance, c'est un besoin **différent**,
   à instruire séparément.
3. **`weekdays` suit la convention ISO de `DateTime.weekday`** (1 = lundi … 7 = dimanche), celle
   du SDK — pas l'énumération d'un hôte.

Le calcul est en **jours calendaires** (normalisé à minuit) : sans cela, « demain 8 h » vu depuis
« aujourd'hui 20 h » ferait 0 jour et un seuil « la veille » raterait sa cible.

---

## 4. Vérification

`melos run analyze` RC=0 · `melos run verify` RC=0 (11 gates) ·
`graph_proof` **ACYCLIQUE + CORE OUT=0** (30 nœuds) ·
`zcrud_core` 1035/1035 · `zcrud_study` 525/525 · `zcrud_responsive` 117/117 ·
`zcrud_reorder` 27/27 · `zcrud_dnd` 33/33 · `zcrud_exam` 63/63.

**Gardes R3 rejouées par l'orchestrateur** — pas prises sur la foi des agents qui les ont
écrites : substituabilité du port (3 rouges), convention d'index du paquet tiers (5 rouges),
paresse de `readBytes` (3 rouges), `isApproaching` sur la récurrence effective (2 rouges).

### Un gate nous a rattrapés, et c'est la bonne nouvelle

Le gate `reserved-keys` a **refusé** notre première version de CR-IFFD-17 : la clé
`reminder_recurrence` était bien réservée, mais la constante était déclarée dans le fichier du
VO au lieu de celui de l'entité — le gate ne la résolvait donc pas, et il avait raison de
considérer la clé comme non réservée. Elle aurait atterri dans `extra`, aurait été **réémise en
double**, et l'`==` entre une instance mémoire et la même relue du store aurait cassé.

Nous n'aurions pas trouvé ça en relisant. C'est un argument de plus pour les gates exécutables.

---

## 5. Ce que vos dix-sept CR auront produit

Elles ont corrigé **six affirmations** que nous avions écrites sans les vérifier — dont deux dans
nos propres handoffs, et une décision d'architecture entière (§1). Le motif ne varie pas : **ce
qui n'a pas été exécuté n'est pas su**, et un artefact qui l'affirme quand même est un défaut,
pas une imprécision.

Cette livraison contient une limite de test honnête (§2), trois décisions de sémantique que
personne n'a demandées (§3) et une règle d'architecture neuve (§1). Les trois méritent d'être
confrontées à votre usage réel avant d'être tenues pour acquises.
