# Handoff v3.36.0 — l'extension morte devient un échec de build

> **Date** : 2026-08-30. **Portée** : `zcrud_generator`. **Traite** : CR-LEX-84 (MAJEUR).

## Clés de schéma ajoutées

**Aucune.** Aucun `toMap()` ne change ; `melos run generate` ne produit **pas un octet** de diff
sur les 45 modèles du dépôt (mesuré, pas supposé).

## 1. Le défaut, tel que l'hôte l'a mesuré

Une sous-classe d'entité adopte le codegen ; sa base déclare un `toMap()` en **membre
d'instance**. Le générateur émet le `toMap()` de la sous-classe dans une **`extension`** — et un
membre d'extension ne surcharge **jamais** un membre d'instance hérité. L'extension est
syntaxiquement présente et **sémantiquement morte** : les champs propres sont décodés, jamais
écrits au document. Build vert, `analyze` vert, test de fixture vert (l'objet en mémoire est
correct) ; le premier symptôme aurait été une donnée utilisateur disparue.

Le remède existait depuis v3.33.0 — le mixin `_$XxxZcrud`, qui apporte des membres d'instance
réels. Ce qui manquait : **rien ne l'exigeait**.

## 2. Ce que le socle livre

**Le build refuse l'extension morte.** Si un super-type hors SDK (super-classe à quelque niveau,
mixin ou interface) déclare `toMap()`/`copyWith()` en membre d'instance — abstrait ou concret —
et que la classe annotée n'applique pas le mixin, le build échoue avec un message qui nomme la
classe, le membre hérité, le `fichier:ligne` de sa déclaration, et le geste :
`class Xxx extends … with _$XxxZcrud`. Trois sorties restent acceptées et sont gardées par
contre-preuve : mixin appliqué, membre déclaré par la classe elle-même, membre venant d'une
extension. La clause `with` est cherchée dans l'AST **en plus** de `element.mixins` — sans quoi
le tout premier build d'un modèle conforme échouerait, le mixin vivant dans le `part` pas encore
généré.

**Un accesseur qui rétrécit un champ hérité ne fait plus disparaître sa spec.** Seule une vraie
redéclaration de champ masque désormais. Le rétrécissement est légitime (une valeur de repli en
un seul endroit) : l'interdire aurait été le mauvais remède ; le `toMap()` émis lit
`this.<champ>`, donc l'accesseur répond et le champ reste `required`. Si le constructeur n'expose
pas le champ conservé, l'échec `_requireInheritedInConstructor` le **nomme** — aucun chemin muet
ne subsiste.

**Non traité, dit franchement** : `fromJson` confondu avec `fromMap` (troisième point de la CR)
est une erreur d'hôte, pas un défaut du socle — les contrats sont opposés (`fromMap` ne lève
jamais, AD-10 ; `fromJson` de l'hôte compte les entrées corrompues pour les écarter). Vérifié que
notre dartdoc n'induit pas la confusion (grep négatif montré : les seules occurrences de
`fromJson` dans `lib/` sont `ZDateRange.fromJsonSafe`).

## 3. Ce qui change pour un hôte

- **Passif : rien.** Aucun modèle du dépôt n'est concerné (les 45 classes `@ZcrudModel` n'ont pour
  super-types que `ZEntity`, `ZExtensible`, `ZStudyArtifact`, `ZSessionCandidate`, dont aucun ne
  déclare `toMap`/`copyWith` — greps négatifs à l'appui) et aucune n'étend une autre classe
  annotée.
- **Hôte qui compensait** — c'est la classe d'impact à lire deux fois : celui qui écrivait son
  `toMap()` à la main pour composer `super.toMap()` avec ses clés propres, ou qui faisait
  transiter ses champs par `extra`, garde un build vert (sa classe déclare son propre membre)
  mais sa compensation devient **redondante** : la retirer au profit du mixin, et vérifier qu'on
  ne cumule pas les deux voies. Celui qui avait **relâché un `required`** pour contourner le trou
  de la spec (des dates retombant sur l'epoch en silence) peut le rétablir.

**Note de suivi** : CR-IFFD-83 (la pastille de compte qui vole le tap) est **déjà livrée** et
encore marquée « OUVERTE » dans le registre de l'hôte. Vérifié le 2026-08-30 par R3 :
`z_item_actions_menu.dart:529-579` monte la pastille **entière** sous `IgnorePointer` (pas
seulement son label), `z_chat_artifact_bar.dart:817` de même ; injection de `ignoring: false` ⇒
rouge par assertion (`Expected: <1> / Actual: <0>`), restauration par copie, sha identique.

## 4. Vérification

`zcrud_generator` : **198 verts** (185 + 13), `dart analyze` propre, `build_runner` idempotent ·
`melos run generate` SUCCESS, **0 `.g.dart` modifié** · `analyze` repo-wide RC=0 · `verify` RC=0
(12 gates) · R3 : 4 injections, toutes rouges **par assertion** (dont la reproduction de bout en
bout du scénario de la CR : mixin retiré ⇒ build rouge avec le message attendu), restaurations par
copie, sha `9b9276c2…` identique avant et après chaque cycle, grep négatif final ·
Balayage des 41 : **41/41 verts**.
