# Handoff v3.40.0 — le remède prescrit compile enfin, et l'alignement des onglets se relaie

> **Date** : 2026-08-30. **Portée** : `zcrud_generator`, `zcrud_study`.
> **Traite** : CR-LEX-89 (MAJEUR) et CR-LEX-88 (MINEUR).

## Clés de schéma ajoutées

**Aucune.** `melos run generate` : 0 `.g.dart` modifié — les 65 modèles `@ZcrudModel` du dépôt
n'ont qu'une base, `ZEntity`, qui ne déclare ni `toMap` ni `copyWith` (grep RC=1).

## 1. CR-LEX-89 — le mixin s'aligne sur la signature du parent

La détection livrée en v3.36.0 était juste — elle a même attrapé chez l'hôte une entité qu'il
n'avait pas protégée. Mais **le remède qu'elle prescrivait ne compilait pas** : le mixin était émis
à partir des seuls champs du schéma, alors qu'il doit surcharger un membre du parent portant aussi
les canaux hors schéma. Deux `invalid_override` en résultaient (`toMap({ZSourceRegistry?})` contre
une signature nue ; 17 paramètres de `copyWith` contre 14).

Livré : quand la chaîne `extends` déclare `toMap`/`copyWith` avec des paramètres hors schéma, le
mixin s'aligne — clause `on <Base>`, paramètres de la base repris, canaux hors schéma typés par
l'accesseur correspondant. `toMap` **délègue** (`...super.toMap(...)` puis recouvrement par les
entrées du schéma : une clé libre d'`extra` ne peut pas usurper un champ persisté, gardé) ;
`copyWith` ne peut pas déléguer (le `copyWith` du parent construirait le type du parent) : il
**passe** les canaux au constructeur de la sous-classe. `super` n'est appelé que si la base est
concrète. Deux échecs de build explicites ajoutés : paramètres positionnels sur la base
(inaligneables) et paramètre de `copyWith` sans accesseur homonyme.

🔴 **La demande n°2 de la CR — exposer une sentinelle publique — est sans objet, prouvé au
runtime** : une valeur par défaut n'appartient pas à la signature d'une méthode, c'est
l'implémentation réellement appelée qui applique la sienne. Mesuré sur une fixture dont la
sentinelle est **privée à sa bibliothèque** : `base.copyWith()` préserve les canaux, et
`base.copyWith(label: null)` distingue toujours le reset explicite. Rien à porter dans un lot
suivant, et aucun paquet tiers touché.

## 2. CR-LEX-88 — `tabAlignment` relayé

`ZPageScaffold` expose `tabAlignment` ; `ZStudyFolderDetail` n'en portait aucune trace. Cause du
symptôme, mesurée : la barre étant **toujours défilante** (`isScrollable: true` en dur dans le
shell), Flutter y résout `TabAlignment.startOffset`, qui réserve **52 dp** — exactement ce que
l'hôte récupérait. Reproduction chiffrée : à 600 dp avec trois libellés longs, le centre du
troisième onglet tombe à **604,35 dp** (hors bornes) par défaut, **552,35 dp** sous
`TabAlignment.start` — le relevé de l'hôte disait `604.4`.

Relayé sur `ZStudyFolderDetail` **et** `ZStudySessionScaffold` (second conteneur du paquet avalant
le même paramètre). `isScrollable` n'existe pas sur `ZPageScaffold` : rien à relayer de ce côté,
aucun paramètre inventé.

## 3. Ce qui change pour un hôte

- **Passif : rien** dans les deux cas (mixin inchangé à l'octet sans base déclarante ;
  `tabAlignment` nul ⇒ arbre identique, prouvé par signature structurelle figée avant modification).
- **CR-89, hôte ayant compensé** : celui qui déclarait `toMap()`/`copyWith()` à la main pour
  contourner le défaut doit **retirer sa déclaration** — tant qu'elle est là, le codegen cesse
  d'écrire le membre et la compensation reste seule en charge. Celui qui avait renoncé au mixin
  n'a qu'à l'appliquer. À connaître : le constructeur de la sous-classe doit exposer les canaux de
  la base (`super.extension`, `super.extra`, `super.source`) — à défaut, erreur d'analyse claire,
  jamais une perte silencieuse.
- **CR-88, hôte ayant compensé** : celui qui avait remplacé la barre d'onglets par une barre maison
  (ou forcé un `TabBarTheme.tabAlignment`) peut retirer ce contournement. Précédence Flutter :
  paramètre > thème — un `TabBarTheme` d'hôte n'est pas écrasé tant que le paramètre reste nul.

**Report explicite** : le même motif `tabAlignment` manque encore dans `ZTabbedList`
(`zcrud_core`) et `ZCrudScreen` (`zcrud_screen`) — deux paquets, donc un lot séparé, pas un geste
trivial.

## 4. Vérification

`zcrud_generator` : **214 verts** (206 + 8), analyze propre, build_runner idempotent ·
`zcrud_study` : **1 867 verts** (1 855 + 12), analyze 72 infos préexistantes ·
`melos run generate` 0 `.g.dart` · `analyze` repo-wide RC=0 · `verify` RC=0 · R3 : 8 + 3
injections, toutes rouges **par assertion** — dont une garde trouvée **tautologique par sa propre
R3** (elle assertait l'absence d'un getter pour un champ non annoté, donc jamais dans le schéma) et
réécrite sur un champ réellement porté par la base · Balayage des 41 : **41/41 verts**.
