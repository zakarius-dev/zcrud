# Handoff **v0.52.0** — le composer partagé, les réglages et la portée de corpus **vérifiable**

> **Tag à épingler : `v0.52.0`** · **strictement additif**, aucune rupture d'API.
> Première livraison du chantier issu de l'étude **CR-IFFD-72** (`docs/etude-cr-iffd-72.md`).
> 🔴 **Rien ne change sans réglage** : les deux vues de chat rendent exactement l'arbre
> d'avant, et `send()` sans argument produit **le même objet de requête** (identité prouvée,
> pas égalité).

---

## 1. Ce que ce lot répond

L'étude a établi trois manques mesurés. Ils sont fermés :

| Manque mesuré (étude § 4) | Réponse |
|---|---|
| **La saisie n'est pas partagée** — aucun widget du socle ne rend `ZChatController.composer` | `ZChatComposer`, monté par les **deux** surfaces via une **fabrique unique** |
| **Aucune portée documentaire** sur la requête, et `corpus` n'est qu'un **libellé** ⇒ restriction invérifiable | `ZChatCorpusScope` + **`audit()`** : la confrontation des sources rendues à la portée demandée |
| **`ZChatRegenerateAction{messageId}`** rend `ZChatLengthBias` inatteignable sur son cas d'usage | l'action porte désormais `settings` et `corpusScope` — **sans nouveau variant** |

---

## 2. Le composer socle partagé

`ZChatComposer` rend `ZChatController.composer` — **le contrôleur socle existait déjà**, il
manquait son widget. Quatre créneaux nullables (`leading`, `trailing`, `tools`, `capture`) ;
`null` ⇒ **absent de l'arbre** (AD-4). Le créneau `capture` accueille le `ZChatCaptureBar`
**existant** : il n'a pas été réécrit.

* 🔴 **`ZChatController` n'a PAS été touché** pour le livrer — la garde d'ensemble **G-CH1**
  reste verte, et le paquet reste strictement additif.
* 🔴 **Anti-divergence prouvée** : la fabrique est déclarée **1×** et appelée **1×** dans tout
  `lib/`. Deux injections distinctes le démontrent, et elles ne sont pas redondantes —
  fabrique inerte ⇒ **les deux surfaces rougissent ensemble** ; relai notebook coupé ⇒ **une
  seule**. C'est la garantie que Chat et Notebook ne pourront pas dériver l'un de l'autre.
* **SM-1 mesuré** : 100 frappes ⇒ **0 tuile reconstruite**, controller `identical`, curseur à
  100 ; caret placé à l'offset 4 + rebuild réel du composer ⇒ **toujours 4**. Avec
  contre-preuve de non-vacuité (un vrai tour reconstruit bien les tuiles).
* **Cible tactile** : un créneau de **40 dp** — la taille exacte du bouton d'envoi legacy — est
  rendu **48×48**. 🔵 **Nous ne reproduisons pas ce défaut d'accessibilité**, même en visant le
  rendu de référence.

---

## 3. Réglages et portée : le contrat, et sa vérifiabilité

### `ZChatGenerationSettings`
Compose les types **déjà modélisés** (`ZChatResponseLength`, `ZChatLengthBias`,
`ZChatComputeEffort`, révélation du raisonnement). **Aucun enum n'a été réinventé** — c'était
le risque n°1 que votre CR-72 nommait, et une garde de source l'interdit désormais.
🔵 Au passage, votre tableau citait `ZChatQuotaMetadata` : **ce type n'existe pas** (les vrais
noms sont `ZChatQuotaKeys` + `zChatQuotaFromMetadata`). Le lecteur de quota n'a pas été
réécrit.

### 🔴 `ZChatCorpusScope` — et pourquoi `audit()` est le cœur du lot
Votre CR demandait de pouvoir **restreindre** une génération à des corpus choisis. Mesuré :
c'était impossible. Mais le vrai obstacle était ailleurs, et ni votre CR ni lex ne l'avaient
formulé :

> **`ZChatSource.corpus` est un LIBELLÉ, pas une clé.** Même en ajoutant un champ de
> restriction, aucune restriction n'aurait été **vérifiable**.

Livré : `ZChatSource.corpusKey` (clé stable, `corpus_key`) **à côté** de `corpus` (libellé,
jamais confronté), et surtout **`scope.audit(sources)`** qui rend un constat :
`{admitted, outOfScope, unattributed, isSatisfied, violations}`.

La distinction **hors portée** (clé connue, non demandée) / **invérifiable** (aucune clé) est
délibérée : les deux échouent, mais l'une accuse le fournisseur, l'autre son schéma.

**Prouvé, pas affirmé** : une source dont le **libellé** coïncide avec une clé demandée mais
dont la **clé** diffère est **détectée** ; et le bouclage est éprouvé **de bout en bout par le
vrai `ZChatStreamPort`** — un fournisseur malhonnête est démasqué.

### Ce qui vient de lex, et ce qui en est écarté
Repris : les deux niveaux, « filtre vide ⇒ toute la famille », le pilotage **par données**
(identifiant stable plutôt que libellé). **Écarté** : ses familles codées en dur
(`enableCodesDouanes`/`enableTec`/`enableValuation`) — elles imposeraient la douane à IFFD et
DODLP ; la famille passe par `sourceType`, déjà ouvert. **Ajouté** : la confrontation, que lex
n'a pas.
🔵 Et ce qu'il faut dire franchement à IFFD : **votre** mécanisme de corpus est **inerte** —
l'étude a mesuré que vos six drapeaux sont **jetés par `IffdAiRepositoryImpl`** (payload
`explain` = `message, model, enableWebSearch`). Nous ne nous en sommes donc pas inspirés.

---

## 4. 🔴 Jamais de repli muet — la règle qui vise votre défaut mesuré

Ajouter un paramètre à `ZChatActionExecutor`, **même optionnel**, invalide tout override
(4 implémenteurs mesurés) : c'est l'incident du 2026-08-01 à la lettre. D'où une **interface
sœur optionnelle**, `ZChatSettingsAwareActionExecutor`, routée depuis le site unique :

| Cas | Comportement |
|---|---|
| sans réglages | chemin historique, **identique** |
| réglages + hôte opté | action entière |
| réglages + hôte **non** opté | **`Left(ZUnsupportedOperationFailure)`** |

Et la garde ne se contente pas de vérifier la failure : elle asserte que l'exécuteur **n'a pas
été appelé du tout**. La dégradation silencieuse est *interdite*, pas seulement signalée.

C'est le pendant exact du défaut que l'étude a trouvé chez vous — des drapeaux transmis puis
jetés sans que rien ne le dise.

---

## 5. La feuille de réglages

`ZChatSettingsSheet` + `ZChatSettingsController` (tranches `ValueListenable`, **hors** de
`ZChatController` précisément pour ne pas élargir G-CH1). Cinq tuiles **remplaçables** :
builder absent ⇒ défaut du socle, fourni ⇒ remplace, rendant `null` ⇒ **tuile absente** (AD-4).
Priorité **paramètre > jeton > référence**, les trois niveaux atteints séparément par test.

🔴 **Le catalogue de corpus est une donnée d'HÔTE** (`ZChatCorpusOption`) : le socle ne porte
**aucune valeur métier** — ni code douanier, ni libellé de corpus.

**Composition réelle prouvée** : vue ▸ composer ▸ feuille, on règle « Niveau 4 » et le corpus
« Beta », on saisit, on valide au clavier ⇒ **un** appel au port portant
`computeEffort.level == 4` et `corpusScope.corpusKeys == ['corpus-beta']` — **la clé**, pas le
libellé.

---

## 6. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — les deux vues rendent l'arbre d'avant, `send()` rend le **même objet** de requête (identité, pas égalité), les 306 tests préexistants passent inchangés |
| **vous, IFFD** | montez `ZChatComposer` (créneau `capture` ⇒ votre `ZChatCaptureBar`), puis la feuille au créneau `tools` ; déclarez vos six corpus comme **`ZChatCorpusOption` d'hôte** — et **retirez vos drapeaux inertes**, ils ne servaient à rien |
| **hôte voulant les réglages sur une régénération** | implémentez `ZChatSettingsAwareActionExecutor` — sinon vous recevez une failure explicite, **jamais** un silence |
| ⚠️ **hôte montant le composer** | la vue exige alors une **hauteur bornée** (`Expanded`) ; sans composer, rien ne change |

🟢 **Tripwire recommandé** : un test qui appelle `scope.audit(...)` sur les sources d'une
réponse réelle et **affirme `isSatisfied`**. Il rougira le jour où un fournisseur sortira de
la portée — c'est le seul moyen de le savoir, et c'est précisément ce que le libellé seul ne
permettait pas.

---

## 7. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0 + corpus de
sérialisation, 36 paquets) · `dart pub get` résolu (91 contraintes).

`zcrud_chat` **377** (+71) · `zcrud_chat_kernel` **392** (+27) · jumelles inchangées :
`zcrud_chat_study` 67, `zcrud_chat_syncfusion` 57 · **0 erreur, 0 avertissement** partout.

**R3 — 40 injections mordantes** (14 + 7 + 19), **toutes ROUGE-ASSERTION**, aucune par
compilation. Restaurations par copie, `sha256` assertés, greps de résidu montrés.

🟢 **Trois gardes VACANTES démasquées pendant ces lots — deux par les agents sur leur propre
travail** : un `widthFactor` **inerte sous une `Row`** (dartdoc corrigé pour dire la mesure au
lieu de l'affirmation), un `ExcludeSemantics` dont le retrait **concatène** au lieu de
dupliquer (un `contains` y était aveugle ⇒ passé en **égalité**), et un créneau abonné au
mauvais sujet (injection **rejetée** plutôt que garde affaiblie).

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 8. Points d'arbitrage et limites

* 🔴 **`ZChatRequestBuilder` n'a PAS été élargi** — mesuré par sonde compilée : élargir un
  typedef de fonction, **même par un paramètre nommé optionnel**, est **cassant**
  (`invalid_assignment`). Les réglages sont donc appliqués **après** le builder, à un site
  unique hors d'atteinte de l'hôte : plus fort que demandé, puisque le défaut « drapeaux
  jetés » en devient **inexprimable**. Un builder-sœur reste possible, mais il faudrait
  assumer qu'un hôte puisse en jeter le contenu.
* Un porteur de réglages **vide** remplace (règle du kernel) : brancher la feuille lui cède la
  gouvernance des quatre axes.
* La feuille ne défile pas d'elle-même — c'est l'hôte qui la borne.
* `audit()` **constate**, il ne filtre pas : la décision (avertir, filtrer, rejeter) reste à
  l'hôte.
* Aucun exécuteur du dépôt n'implémente encore l'interface sœur (conséquence voulue, non
  silencieuse).
* **Non couvert, chantier suivant** : le rendu « pixel près » du Notebook
  (`ZChatNotebookReference` + skin via `ZSfAssistShellRenderer`) — v0.52.0 livre l'ossature,
  pas l'habillage.
* Dettes antérieures toujours ouvertes : champ de recherche sous dégradé (v0.49.0), deux
  gardes inertes de `ZMindmapView` (v0.49.0), estampillage par carte en multi-sources
  (v0.51.0).
