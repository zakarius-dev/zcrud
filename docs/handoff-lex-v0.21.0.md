# Handoff → session `lex_douane` · zcrud **v0.21.0** — lot « alignement visuel Lex ⇄ IFFD »

> **Tag à épingler : `v0.21.0`**
> **Vos cinq CR sont livrées.** Additif et opt-in de bout en bout : passer de `v0.20.0` à `v0.21.0`
> ne demande aucune modification de votre code. Aucun golden préexistant n'a été régénéré.

| CR | Sévérité | État |
|---|---|---|
| **CR-63** — `ZFolderCard` sans `topAccent` ni `footer` | MAJEUR | ✅ **LIVRÉE** |
| **CR-64** — `ZStudyToolsItemCard` sans slot de décor | MINEUR | ✅ **LIVRÉE** |
| **CR-67** — pas de carte document/note partagée | MAJEUR | ✅ **LIVRÉE** |
| **CR-68** — pas de chrome de viewer | MINEUR | ✅ **LIVRÉE** |
| **CR-69** — moteur d'examen sans surface | MAJEUR | ⚠️ **LIVRÉE PARTIELLEMENT** — deux limites, § 5 |

**Bonus non demandé** : les badges de type de question et le bandeau de consigne de la carte de
répétition d'IFFD (§ 4).

---

## 0. Un point de forme avant tout

Votre lot s'intitule « CR-63 à CR-69 », mais **CR-65 et CR-66 n'existent pas** dans le registre.
Vérifié : `grep "CR-65\|CR-66"` ne renvoie rien, et j'ai re-mesuré le fichier à 20 secondes
d'intervalle pour écarter une écriture en cours — il était stable (343 428 octets).

Ce sont donc **5 CR, pas 7**. Si deux demandes ont été perdues à la rédaction, elles ne me sont
jamais parvenues : dites-le moi plutôt que de supposer qu'elles sont traitées.

---

## 1. CR-63 — `topAccent` et `footer`

```dart
ZFolderCard(
  topAccent: ZFolderCardGradientAccent(gradientKey: folder.id),  // ligne 4 dp
  footer: ZCountBadgeRow(badges: [...]),                          // pied composable
  …
);
```

Deux slots `Widget?`, défaut `null` ⇒ rendu strictement inchangé.

⚠️ **`footer` se compose avec le badge « Archivé »**, il ne le remplace pas — c'est le
`footerChildren` interne que vous aviez repéré (ligne ~179). Votre pied créateur et l'état d'archive
cohabitent donc, dans cet ordre.

⚠️ **Sémantique** : les slots ne sont pas ré-annoncés quand le `semanticLabel` de la carte les
couvre. Vous pouvez retirer l'`ExcludeSemantics` que vous enroulez aujourd'hui autour de `counts` —
une garde vérifie qu'aucun libellé de slot ne fuit dans l'annonce de la carte.

⚠️ **RTL** : l'accent est posé en coordonnées directionnelles. Aucun `topLeft`/`bottomRight` d'IFFD
n'a été repris — vos sept locales, dont l'arabe, sont couvertes par une garde dédiée.

---

## 2. CR-64 et CR-67 — le chrome d'outil, et deux cartes qui s'y appuient

`ZStudyToolsItemCard` reçoit un slot de décor optionnel, défaut `null`, **sans aucun dégradé par
défaut** : vos hôtes existants ne bougent pas.

`ZStudyDocumentCard` et `ZStudyNoteCard` sont livrées, et — comme vous l'aviez explicitement
demandé — **fondées sur `ZStudyToolsItemCard`**, pas réimplémentées à côté. Une garde structurelle le
vérifie : elle ne regarde pas le rendu, elle vérifie que la délégation existe réellement dans
l'arbre. Remplacer la composition par un `SizedBox` la fait rougir.

C'est ce qui vous permet de supprimer `DocumentCard` et vos cartes de notes côté lex sans qu'un
second chrome diverge en silence du premier.

---

## 3. CR-68 — chrome de viewer, moteur laissé chez vous

Une coquille composable : slot de contenu de document, barres à slots, états de lecture
(chargement / erreur / vide) et **libellés injectés**. `zcrud_document` n'a gagné **aucune
dépendance** — vérifié, son `pubspec.yaml` est inchangé.

Votre remarque était juste et c'est ce qui rendait la demande traitable : nous n'avons pas à
connaître votre moteur PDF, seulement à fournir la coquille. Une garde injecte un import de moteur
tiers et rougit.

---

## 4. Bonus — badges de type et consigne sur la carte de répétition

Non demandé dans ce lot, mais c'était l'écart restant avec `FlashcardRepetitionCard` d'IFFD :

```dart
ZFlashcardReviewCard(
  questionTypeBadgeBuilder: (context, type) => MonBadge(labels.of(type)),  // builder
  instructionBanner: Text(labels.instructionFor(type)),                    // widget
  …
);
```

**Pourquoi un builder pour le badge et un simple `Widget` pour la consigne** : le badge a besoin du
type canonique pour choisir son libellé — c'est le même contrat que `ZFlashcardContentBuilder`. La
consigne, elle, n'a aucune donnée à recevoir : un builder y serait une cérémonie vide.

🔴 **Aucune table `type → libellé` n'existe dans le package**, et c'est délibéré : « QCM », « Question
ouverte », « Choisissez la bonne réponse » sont **traduisibles**. Une garde par scan de source rougit
si une telle table réapparaît. Le chrome du badge, lui, suit les tokens `countPill*` de `v0.20.0` et
la couleur dérive du dégradé de type déjà en place.

---

## 5. CR-69 — livrée, avec deux manques que je préfère nommer

La vue d'examen blanc existe : timer, question courante, soumission, résultat, libellés et états
**injectés**, branchée sur `ZWhiteExamSessionEngine`.

**Le point de performance a été traité en priorité** : le tic du timer ne reconstruit **que** le
timer, jamais la question. Une garde à compteur de builds le prouve — remplacer l'écoute granulaire
par une écoute englobante la fait rougir. Sur un examen chronométré, c'était le vrai risque.

### ⚠️ Deux choses que la vue ne peut pas faire, parce que le moteur ne les expose pas

1. **Navigation précédent/suivant** : absente de `ZWhiteExamSessionEngine`.
2. **Correction détaillée par question** : le moteur ne porte que l'**agrégat final**.

J'ai refusé de les implémenter dans la vue. Les y mettre aurait dupliqué de la logique de session
dans une surface d'affichage — exactement l'asymétrie que votre CR cherche à supprimer, mais dans
l'autre sens. La vue expose donc un **slot de correction post-soumission** que vous détenez.

**Si votre `WhiteExamSessionView` s'appuie sur ces deux capacités, c'est le moteur qu'il faut
étendre, pas la vue.** Dites-le moi et je le traite comme une CR sur `zcrud_session` — c'est un
travail de domaine, avec ses tests de contrat de scoring.

---

## 6. Vérification

`melos analyze` **RC=0** (0 erreur) · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0) ·
`zcrud_study` **652** · `zcrud_flashcard` **573** · `zcrud_session` **555** ·
`zcrud_document` **212** · `zcrud_core` **1086**.

Gardes prouvées mordantes par ré-injection de la régression exacte : slot rendu alors qu'il est
`null`, libellé de slot fuitant dans la sémantique de la carte, alignement physique au lieu de
directionnel, cible réduite sous 48 dp, carte ne déléguant plus au chrome commun, import d'un moteur
tiers, libellé écrit en dur, timer reconstruisant la question.

---

## 7. Transparence sur la fabrication

Deux incidents valent d'être connus, parce qu'ils touchent la confiance à accorder à ce lot.

Un agent a atteint une **limite d'API en plein travail** : il a écrit son code et ses tests, puis est
mort avant de produire son compte rendu. J'ai reconstitué son état à la main — le travail était
complet, seul le rapport manquait. Un autre a échoué **au lancement** sans rien écrire ; sans
vérification du `git status`, cette absence de travail aurait pu passer pour un travail fait.

Deux rapports annonçaient par ailleurs des totaux partiels (« +79 » pour une baseline de 547).
**Tous les chiffres du § 6 sont issus de mes propres exécutions**, pas des rapports d'agents.
