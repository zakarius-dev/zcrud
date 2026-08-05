# Handoff **v0.51.0** — CR-IFFD-69 + 70 + 71 : le LaTeX sûr sans pont, la source sur place, le notebook distingué

> **Tag à épingler : `v0.51.0`** · aucune rupture d'API, tout est additif.
> 🔴 **À lire d'abord** : § 1 — le chemin sans pont est désormais **sûr** ; votre tripwire de
> présence du pont **ne rougira pas** (comportement avec pont prouvé inchangé). § 3 — le
> notebook existe : `ZChatNotebookView`, et vos 5 capacités (dont une que votre CR n'avait
> pas listée) se composent sans nouvelle API kernel.

---

## 1. CR-IFFD-69 — la corruption LaTeX : votre localisation était juste, et la cause est DOUBLE

Reproduit au caractère près : sans pont, `$$\int_0^1 x\,dx$$` → `$$\\int\_0^1 x,dx$$` ; avec
pont, intact. Votre mesure « dans les deux sens » a tenu à la reproduction — merci pour elle,
elle a économisé la moitié de l'enquête.

**La cause est double**, plus étendue que le signalement d'origine : au **décodage**, `\,` est
résolu en `,` (perte CommonMark irréversible) ; à l'**encodage**, `\` doublé et `_` échappé.
Mesuré en plus : `\(a+b\)` perdait ses délimiteurs.

### La forme retenue — et les chiffres qui ont éliminé les deux autres

**Bouclier littéral LaTeX sur le chemin sans pont** : les mêmes motifs de reconnaissance que
`ZMarkdownBridges.latex`, rejoués en mode **texte littéral** (jamais d'embed) des deux côtés,
actifs **uniquement quand `bridges.isEmpty`**.

* **Pont par défaut — REJETÉ par mesure** : sur 9 textes à `$` non mathématiques, **8 voyaient
  leurs octets changer** (`$` → `\$`), et « total $x$ affiché » devenait un **embed** — rendu
  cassé chez tout hôte sans `EmbedBuilder`.
* **Refus/throw — REJETÉ** : `ZCodec.decode` n'a pas de canal d'échec (rupture d'API),
  contraire à AD-10, inerte en release.

### Ce qui est garanti
* **Avec pont : rien ne bouge** — prouvé structurellement (bouclier court-circuité par
  construction), suites pinnantes et goldens verts. **Votre
  `latex_corruption_tripwire_test.dart` ne rougira pas.**
* **AD-10 sur le legacy corrompu** : un document déjà altéré se décode sans throw et devient
  un **point fixe** — le dés-échapper aurait recorrompu les `\\` de matrices légitimes.
* Vos « non mesuré », mesurés : le pont est **rigoureusement neutre hors LaTeX** (7/7
  constructions cassées du banc v0.49.0, octets identiques avec ou sans pont — il ne répare
  ni n'aggrave) ; `$$` dans un bloc de code reste **opaque** dans les deux régimes (garde).

### ⚠️ Limite délibérée, à connaître
Le bouclier se désactive **dès qu'un pont quelconque est déclaré** — un hôte à ponts partiels
non-LaTeX reste exposé sur le LaTeX. Choix argumenté (ne pas deviner l'intention d'un hôte qui
gère déjà ses ponts) ; si ce cas vous concerne un jour, déclarez aussi le pont LaTeX.

Non couvert : formule fragmentée sur ops stylées, `$$` multi-paragraphe.

---

## 2. CR-IFFD-70 — la feuille de génération prend sa source

Le créneau est livré, jamais l'implémentation — l'extraction reste chez vous, comme la
génération l'est déjà.

### Le contrat
* `ZResolvedGenerationSource` — **trois formes** : texte composé · **paginée PARTIELLE**
  (pages choisies — la forme exacte de votre legacy, testée sur `{3,7}`) · **par RÉFÉRENCE**
  (la provenance seule porte le `documentId`).
* `ZGenerationSourceResolver` — résolution **à la demande**, `Either` sur tout échec : la
  feuille ne charge rien pour s'ouvrir.
* **Choisir** : `contextSources` (multi-sélection, résolution à la soumission).
* **Acquérir** : `acquisitionGestures` — libellés **injectés**, `Right(null)` = annulation
  propre, la source produite est **pré-sélectionnée dans la même session** : le flux n'est
  jamais rompu.

### Les preuves qui comptent
* **Hôte passif : identique au pixel** (pas seulement « rien ne casse »), gardé.
* **Le paramétrage survit à l'acquisition** : la garde saisit 3 champs, désélectionne un
  type, acquiert, puis vérifie la requête finale complète.
* **Votre `…FromWholeDocument` commenté est couvert** par la forme par référence — le jour où
  vous le décommentez, le créneau existe (testé).
* **Conserver ou éphémère** : le contrat est **silencieux à dessein** — c'est une question de
  produit ; une garde de pureté verrouille que le socle n'écrit rien.

⚠️ **Point d'arbitrage produit, remonté sans être tranché** : l'estampillage des cartes reste
`request.provenance` (mono-source historique). En multi-sources, un estampillage **par
carte** serait une décision produit — les provenances par source voyagent déjà dans
`resolvedSources`, l'implémentation du port peut donc le faire le jour où vous tranchez.

---

## 3. CR-IFFD-71 — le notebook est distinct, sur racine commune

Votre directive (« des widgets différents, peut-être héritant d'une racine commune ») est
suivie à la lettre, avec le mécanisme qui neutralise le risque de divergence :

* **Deux créneaux additifs** sur `ZChatMessageTile` **et** `ZChatConversationView` :
  `identityBuilder` (l'axe identité — que le socle ne portait **pas** : votre hypothèse
  « `showAuthorAvatar`/`showAuthorName` existent peut-être déjà » est **INFIRMÉE**, grep
  négatif montré ; ces réglages étaient un type Syncfusion laissé à l'hôte) et
  `actionsBuilder` (l'axe « que fait-on du résultat », sous les blocs, hors zone repliable).
  **Builders, jamais des booléens** — l'erreur `AssistMessageSettings` n'est pas refaite.
* **`ZChatNotebookView`** : composition mince sur la **même racine** — son `build()` retourne
  `ZChatConversationView` ; l'identité y est **structurellement masquée** (le paramètre
  n'existe pas), le slot d'actions exposé.
* 🔴 **Anti-divergence prouvée par injection** : une régression dans la fabrique unique de
  tuile fait rougir **les deux surfaces ensemble**. C'est la garantie que le motif
  « deux vues qui divergent » (déjà payé une fois dans ce dépôt) ne se reproduira pas.

### La preuve centrale : vos capacités se composent SANS nouvelle API
Un test de composition monte **les 5 capacités** — mindmap, flashcards, variantes, export,
**et « enregistrer en note »**, la cinquième que notre dépouillement a trouvée dans votre
monolithe et que votre CR ne listait pas — via `actionsBuilder` + `runAction(ZChatCustomAction)`
uniquement. Chaque verbe atteint `executeCustom` avec le `message_id` ; cibles ≥ 48 dp en
**géométrie rendue** (le précédent `widthFactor` de ce même paquet a servi de leçon).
**Aucun ajout kernel, aucun jeton de thème** : le contrat CHAT-0b suffisait.

### Vos « 29 branches », dépouillées : ce sont 21 décisions vivantes
3 IDENTITÉ · 9 CAPACITÉ · 9 COSMÉTIQUE (+ 8 occurrences mortes). Classement intégral :
**8** couvertes par les créneaux livrés · **4** par l'existant (`collapsedMaxHeight`,
`ZChatRegenerateAction`, `zchat.streaming`, `ZChatExportService`) · **9** relèvent de l'hôte
(cosmétique, composeur, permissions). Le détail branche par branche est dans le rapport de
lot — utile pour planifier votre migration du monolithe.

**Culling mesuré** : 13/100 tuiles construites avec le créneau monté.

---

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **vous, IFFD** | § 1 : rien — votre pont vous protégeait déjà, et il continue ; § 2 : branchez `contextSources` + vos deux gestes (FilePicker, scanner) dans `acquisitionGestures` ; § 3 : le portage du monolithe peut commencer — le classement des 21 branches est votre plan de route |
| **hôte passif** | rien, nulle part — les trois lots sont additifs, défauts inchangés, gardés (feuille de génération identique **au pixel**) |
| **hôte SANS pont qui persiste des formules** | 🟢 vos données **cessent d'être altérées** — c'était le défaut ; aucune action requise |
| **hôte à ponts partiels non-LaTeX** | ⚠️ § 1 : le bouclier se désactive dès qu'un pont existe — déclarez aussi le pont LaTeX |

🟢 **Tripwire recommandé** (IFFD) : vous portez déjà le bon — le test de présence du pont.
Ajoutez son symétrique : un test qui affirme qu'un `$$…$$` passé par `ZMarkdownCodec()` **sans
pont** revient intact — il documente la garantie amont, et rougira si un refactor du socle la
perdait.

---

## 5. Vérification

`melos generate` **RC=0** (0 `.g.dart` modifié) · `melos analyze` **RC=0** · `melos verify`
**RC=0** (ACYCLIQUE + CORE OUT=0 + corpus de sérialisation, 36 paquets) · `dart pub get`
résolu (91 contraintes).

`zcrud_markdown` **494** (+28) · `zcrud_study` **1392** (+24) · `zcrud_chat` **306** (+20) ·
voisins rejoués : chat_kernel 365, chat_study 67, chat_syncfusion 57, note 173, flashcard 586,
core 1244 · **0 error, 0 warning** partout.

**R3 — 27 injections mordantes** : 10 (CR-69) + 8 (CR-70) + 9 (CR-71), toutes
**ROUGE-ASSERTION**, restaurations par copie, zéro résidu (greps montrés). S'y ajoute la
sonde d'anti-divergence (les deux surfaces rougissent ensemble).

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 6. Ce que nous savons ne pas avoir couvert

* **CR-69** : formule fragmentée sur ops stylées ; `$$` multi-paragraphe ; hôte à ponts
  partiels (limite délibérée, § 1).
* **CR-70** : l'estampillage par carte en multi-sources (arbitrage produit, § 2) ; aucun
  jeton de thème créé (structurel — espacements sur jetons existants).
* **CR-71** : les ponts métier mindmap/variantes/export par message (satellites futurs — le
  créneau les accueille, ils n'existent pas encore) ; tranches de progression par message ;
  mesure RTL isolée des créneaux.
* Dettes antérieures toujours ouvertes : champ de recherche sous dégradé (v0.49.0), deux
  gardes inertes de `ZMindmapView` (v0.49.0).
