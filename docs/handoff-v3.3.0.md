# Handoff **v3.3.0** — CR-IFFD-84 complète, et une dette de documentation soldée

> **Tag à épingler : `v3.3.0`** — **additif** : aucun hôte passif ne change de rendu.
> Paquets porteurs : **`zcrud_chat`**, **`zcrud_core`**, **`zcrud_study`**, **`zcrud_generator`**.

---

## 1. CR-IFFD-84 — les quatre tranches sont livrées

Votre constat d'ouverture était exact, et il commandait tout le reste : `busyPalette` et
`capabilityAccents` existaient **sans aucun consommateur**. Le mécanisme d'artefacts déclarés en
est désormais le lecteur.

**L'animation d'occupation** — que vous appeliez « le cœur de la demande » — anime le glyphe **par
artefact**, jamais globalement : votre défaut ③ est structurellement inexprimable. Sous « Réduire
les animations », aucun contrôleur n'est créé et le glyphe se fige sur la première teinte, de sorte
que l'occupation reste perceptible par **deux** canaux.

⚠️ **Le mécanisme ne vit pas dans le chat.** Sur arbitrage du owner, il est livré comme primitive
publique du **cœur** (`ZColorCycle`) : elle ne connaît ni le chat, ni les artefacts, ni le notebook,
et sert donc **tous les modules**. Vos autres écrans qui signalent une génération en cours peuvent
s'en servir sans passer par le notebook.

**La table passe de 5 à 9 entrées**, aux valeurs d'**écran** que vous aviez relevées — et le piège
de la double source est **gardé** : une garde rougit si un futur relevé repart de l'enum du modèle.

**La coquille de tuile** livre vos quatre points : carte et filet, coiffe par le sujet du tour,
style du bouton de dépli, format d'horodatage.

## 2. Trois points où nous vous corrigeons, mesures à l'appui

**Le débordement n'existe pas.** Votre calcul — neuf cibles de 48 dp font 432 dp — est juste, mais
décrit une **rangée**. La barre est un `Wrap` : mesuré à 360, 320 et 240 dp, en LTR comme en RTL,
les neuf cibles restent à 48 × 48, dans l'écran, disjointes, et chacune répond au tap. **Nous
n'avons rien ajouté** — un mécanisme de débordement déplacerait des cibles déjà atteignables
derrière une affordance de plus.

**Le contraste de `#9C27B0`.** Votre CR ne porte que les hex. Mesuré : c'est la première teinte du
catalogue à échouer côté **sombre** (2,97:1) tout en tenant en clair. Elle est donc **éclaircie**,
pas assombrie — une correction à sens unique aurait aggravé son cas.

**« Par jeton » n'était pas réalisable** pour le bouton de dépli : aucun jeton ne vise ces axes, et
le porteur de jetons vit dans un autre paquet. La chaîne livrée est *paramètre > référence*, et le
point d'insertion d'un futur jeton est documenté. Pour l'horodatage, vous autorisiez « par jeton
**ou** par résolveur » : c'est le résolveur.

## 3. Ce que la coiffe s'appelle, et pourquoi

`topic` — le **sujet du tour**, pas l'identité de l'interlocuteur. Vous insistiez sur la
distinction ; elle était déjà **outillée** chez nous : une garde interdit nominativement le mot
« identité » dans la vue du notebook. Le contresens que vous redoutiez n'était pas seulement
compris, il était empêché.

## 4. ⚠️ Le sens de « défaut »

Vous demandiez « le rendu IFFD legacy en défaut ». Nous l'avons livré comme défaut **de la
référence** — servi dès que la coquille est déclarée — et **non** comme défaut du paquet : plusieurs
applications consomment `zcrud_chat` et aucune n'a demandé votre rendu. Sans déclaration, l'arbre
est **strictement inchangé**.

## 5. Une dette de documentation soldée

La documentation du projet est générée à partir des commentaires Dart. Les nôtres racontaient le
traitement des CR — numéros, versions, récits de lots — au lieu de documenter les API. **~150 sites
ont été repris** dans 16 paquets, jusque dans les commentaires **émis par le générateur**. Le dépôt
n'en contient plus aucun.

Ce qui compte pour vous : la **règle** reste écrite partout où un appelant doit la connaître ; seul
son historique a changé de support. Une dizaine de dartdoc cassées par un nettoyage antérieur ont
été recousues au passage.

## 6. Deux dettes que nous vous signalons

- Un **troisième** calculateur de contraste subsiste dans un autre paquet ; il échappe à la garde de
  déduplication parce qu'il délègue au SDK au lieu d'écrire les coefficients. Prochain candidat.
- Une garde sœur de notre noyau porte le même angle mort qu'une autre, **en sens inverse** (faux
  vert). Non atteignable aujourd'hui, consigné.

## 7. État des vérifications

`melos run generate` RC=0 · `melos run analyze` **repo-wide** RC=0 · `melos run verify` RC=0.
**Balayage complet des 40 paquets** : `zcrud_core` **2370** · `zcrud_study` **1555** ·
`zcrud_firestore` 812 · `zcrud_chat` **633** · `zcrud_flashcard` 586 · `zcrud_markdown` 584 ·
`zcrud_session` 581 · `zcrud_chat_kernel` 411 · `zcrud_study_kernel` 398 · `zcrud_geo` 370 ·
`zcrud_screen` 350 · `zcrud_intl` 286 · `zcrud_document` 235 · `zcrud_ui_kit` 232 · … tous verts.
⚠️ `zcrud_generator` échoue de façon **environnementale** (`Isolate.packageConfig` via `build_test`)
— rouge qualifié, code sain.

Injections R3 sur les cinq lots, rouges **par assertion**, restaurations par copie avec sha256
cités. Le nettoyage documentaire a été prouvé sans effet par diff mécanique contre 80 sauvegardes :
**aucune ligne de code touchée**, comptes de tests identiques partout.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue la
ligne de défense de cette release.
