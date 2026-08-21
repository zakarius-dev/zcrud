# Handoff **v3.3.1** — dettes soldées, documentation auditée

> **Tag à épingler : `v3.3.1`** — **aucun changement de comportement**. Correctifs internes,
> gardes durcies, documentation corrigée.

---

## 1. Un seul calculateur de contraste dans tout le dépôt

Un troisième calculateur WCAG privé subsistait, bâti sur la luminance du SDK. Il consomme
désormais celui du cœur.

**Rendu strictement inchangé, et mesuré plutôt que supposé** : les deux implémentations rendent le
même nombre à **0.0 près** sur 1 257 couleurs et 5 028 couples teinte/surface, et classent tous ces
couples du même côté des planchers 3:1 et 4,5:1. Aucune divergence, pas même en flottant.

**L'angle mort de la garde est refermé** : elle cherchait les coefficients WCAG littéraux, que ce
calculateur ne portait pas. Elle couvre désormais aussi la délégation au SDK — les deux motifs
étant dérivés de la source, jamais figés.

## 2. 🔴 Un faux VERT refermé dans une garde de contrat

Le test « aucun verbe mort » du noyau pouvait être **dupé** : un constructeur nommé homonyme d'un
verbe suffisait à le faire passer pour routé alors qu'il aurait été mort.

Ce scénario avait été jugé **inatteignable**. **Mesure faite : c'était faux** — la garde censée
l'interdire exige un blanc devant le nom du membre, or un constructeur nommé y porte un point. Les
trois formes lui échappaient.

C'est le même angle mort qu'un test jumeau corrigé la veille, mais **en sens inverse** : là un faux
rouge, bruyant donc corrigé dans l'heure ; ici un faux vert, silencieux. Aucun changement de code de
production.

## 3. Deux dartdocs qui mentaient

- 🔴 Un binding annonçait un défaut d'autorisation **permissif** là où le code pose un **refus par
  défaut** — le fichier se contredisait quelques lignes plus bas. Le comportement n'a jamais changé ;
  seul le texte était faux. **Une documentation qui inverse un défaut de sécurité est pire qu'une
  absence de documentation.**
- Deux libellés de repli annoncés « localisés » sont des constantes **en français**. La dartdoc le
  dit désormais, et avertit qu'une application multilingue doit fournir les siens.

## 4. Le site de documentation, audité avant republication

Il était figé 29 versions en arrière. **16 pages corrigées, chaque correction portant sa preuve.**
Ce qui mentait, et qui vous concerne directement :

| Ce qui était écrit | Réalité |
|---|---|
| dépendance épinglée sur une version d'il y a un mois | **3.3.1** |
| ports et échecs cités **sans le préfixe du paquet** | les noms réels le portent |
| sous-schémas : « chaque item est édité par un sous-formulaire imbriqué » | c'est l'ancien défaut — le défaut est **compact** depuis la 2.0.0 |
| « un scope de binding ne re-propage que le résolveur et l'ACL » | ils **dérivent** l'ambiant depuis la 3.1.0 |
| recherche Firestore « **non honorée** » | elle l'est ; le socle filtre en mémoire |
| un type public qui **n'existe pas** | absent du barrel |
| « quatre formats d'export », « deux onglets », « un modal en bas d'écran » | cinq, trois, et une forme **adaptative** |

**Le contrepoids compte autant** : le point le plus grave de l'audit précédent — le repli
d'autorisation **refusant** — était correctement documenté et l'est resté. Les 393 symboles cités
par le site ont été confrontés au code : **un seul** était fantôme.

## 5. Ce qui reste à documenter, et qui demande un arbitrage

Cinq capacités livrées récemment ne sont **pas encore** sur le site : les artefacts de message
déclarés, le journal d'entité, la primitive d'animation du cœur, la navigation de sous-dossiers, et
la gouvernance geste par geste du CRUD de relation. Aucune n'est *fausse* — elles sont **absentes**.

Chacune demande une décision de forme (section de fiche ou page de concept), pas une rédaction
mécanique : le mécanisme d'artefacts, par exemple, ne tient pas dans un tableau.

## 6. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0.
**Balayage complet des 40 paquets** : `zcrud_core` **2371** · `zcrud_study` 1555 ·
`zcrud_firestore` 812 · `zcrud_chat` 633 · `zcrud_flashcard` 586 · `zcrud_markdown` 584 ·
`zcrud_session` 581 · `zcrud_chat_kernel` 411 · `zcrud_document` **237** · … tous verts.
⚠️ `zcrud_generator` échoue de façon **environnementale** (`Isolate.packageConfig` via `build_test`)
— rouge qualifié, code sain.

Injections R3 sur les trois lots, rouges **par assertion**. La plus instructive démontre le faux
vert dans les deux sens, **sur exactement le même code injecté** : vert avec l'ancien motif alors
qu'un verbe est mort, rouge avec le nouveau.

⚠️ **Un piège de méthode, à connaître** : `grep` sans `-a` traite certaines sources Dart comme
binaires et rend **une sortie vide sans erreur**. Il a failli produire un faux « symbole disparu »
pendant l'audit. Toutes nos preuves d'absence ont été refaites avec `-a`.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue la
ligne de défense de cette release.
