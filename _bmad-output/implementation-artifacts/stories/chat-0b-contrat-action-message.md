---
baseline_commit: 3f41d95
---

# Story CHAT-0b : contrat d'action de message (`zcrud_core`)

Status: ready-for-dev

<!-- Epic CHAT. Story [M], SÉQUENTIELLE — TÊTE après CHAT-0, seule écriture dans zcrud_core tant qu'elle n'est pas verte. -->
<!-- Sources de plan : sprint-status.yaml:584 ; ~/.claude/plans/tingly-brewing-cake.md § « PLAN — Epic CHAT » (l.477-487, 544-556) ; /tmp/zcrud-lexplus/DELTA-LEX.md §3 et §7 ; /tmp/zcrud-lexplus/lex-cycle-vie.md ; /tmp/zcrud-notebook/cycle-vie-message.md ; /tmp/zcrud-existant/CARTE-ANTI-DUPLICATION.md. -->
<!-- Les dépôts /home/zakarius/DEV/iffd et /home/zakarius/DEV/lex_douane sont STRICTEMENT en LECTURE SEULE : grep/read uniquement, jamais d'écriture. -->

## Story

As a **développeur d'une application hôte de zcrud (IFFD, lex_douane, DODLP)**,
I want **un contrat d'action de message dans `zcrud_core` où chaque verbe (éditer · régénérer · supprimer · annuler · copier) n'a QU'UN SEUL chemin d'exécution, où toute action destructrice ne peut pas s'exécuter sans confirmation, et où l'annulation ne peut pas détruire la saisie**,
so that **les neuf défauts d'IFFD deviennent structurellement IMPOSSIBLES à reproduire — pas seulement déconseillés — avant que C2 (controller) et C7 (RAG/config) ne construisent dessus.**

**Couvre :** la **discipline structurelle** posée en préalable des lots C2 et C7 (plan, l.477-487).
**Dépend de :** CHAT-0 (livrée — 12 classes sous `packages/zcrud_core/lib/src/domain/chat/`, 1244 tests).
**Débloque :** CHAT-2 (`ZChatController` — il *consomme* ce contrat, il ne le redéfinit pas), CHAT-7 (RAG/config), CHAT-4 (menus).
**Hors périmètre (par conception, justifié en Dev Notes) :** tout controller (CHAT-2), tout port IA / streaming / `ZChatStreamEvent` / `CancelToken` réel (CHAT-1), tout repository ou adapter de persistance (C5/C6), tout widget, dialogue, libellé, icône ou couleur (CHAT-3/CHAT-4 + app-side), l'historique de versions de contenu (**n'existe ni chez lex ni chez IFFD** — ce serait une invention, cf. Dev Notes).

---

## 🔴 Pourquoi cette story existe — UNE cause racine, neuf symptômes

Le delta lex (`/tmp/zcrud-lexplus/DELTA-LEX.md` §3) a établi que les **9 corrections** apportées par lex
aux défauts d'IFFD partagent **une seule** cause racine :

> **UN VERBE = UN SEUL SITE D'APPEL DANS LE CONTRÔLEUR.**

IFFD porte **deux implémentations parallèles du même concept de barre d'actions** dans un seul fichier de
5153 lignes (`chatbot_conversation_screen.dart`) : (A) barre de bulle ≈ l.1650-2170, (B) en-tête compact
≈ l.3600-4120. Elles **ne se comportent pas pareil** :

| Verbe | Surface A | Surface B | Divergence mesurée |
|---|---|---|---|
| Supprimer | `buildConfirmDialog` puis delete cascade Q+R (l.2134-2165) | delete cascade Q+R **SANS confirmation** (l.3886-3908) | même icône rouge `delete_forever_outlined`, deux garanties opposées |
| Régénérer | chat-session : **delete Q+R puis resend** (l.1979-1990) | chat-session : `refresh:true` **en place** (l.3909-3941) | **trois** comportements au total avec le cas `transformer` (l.2026-2121, `create` additif) |
| Annuler | — | pendant génération, la **seule** icône est la poubelle : `stopSubjectExplaningOnError()` **+ `delete(requestedMessage.id)`** (l.3618-3672) | « annuler » **supprime la question tapée**, sans confirmation ni toast |
| Copier | absent (code commenté l.1513, l.4208) | absent | 3 sites morts recensés (`onTap: () {}`, callback jamais invoqué) |

⇒ Une checklist « pensez à confirmer » ne corrige pas cela : **la structure** doit rendre le second chemin
inexprimable. C'est l'objet unique de cette story.

⚠️ **lex n'applique pas non plus sa propre discipline partout** (DELTA §7 : son pipeline chat ne type pas
le mapping status-code → `Failure`, exactement comme IFFD). Reprendre lex veut donc dire **systématiser**,
pas recopier.

---

## Décisions tranchées avant dev

### D1 — 🔴 FORME DU CONTRAT : intentions **scellées** + **répartiteur unique**. Ni interface à 5 méthodes, ni `typedef` par verbe.

**Trois formes ont été pesées. Le critère décisif est celui de l'owner : quelle forme rend l'unicité du
site d'appel VÉRIFIABLE PAR UNE MACHINE ?**

| Forme | Ce qu'elle donne | Pourquoi REJETÉE / RETENUE |
|---|---|---|
| **(a) `abstract interface class` à un membre par verbe** (`editMessage`, `regenerate`, `deleteMessages`, `cancel`, `copy`) | contrat typé, `Either` par membre | 🔴 **REJETÉE** : 5 membres publics = **5 points d'entrée**. Rien n'empêche la surface A d'appeler `deleteMessages` après un dialogue et la surface B de l'appeler nue — **c'est exactement la forme d'IFFD**. Une garde ne peut alors mesurer que « ce membre est appelé de 2 endroits », sans pouvoir dire lequel est légitime. Le contrat serait contournable sans qu'aucune garde ne rougisse. |
| **(b) un `typedef` par verbe** (`ZOnRegenerate = void Function(String)`) | souplesse maximale | 🔴 **REJETÉE, la pire** : un callback est libre en nombre de sites, invisible au typage, et **peut être vide** — c'est littéralement le défaut « Copier » d'IFFD (`onTap: () {}`, callback jamais invoqué, 3 sites morts). Aucune garde structurelle possible. |
| **(c) `sealed class ZChatAction` (intentions) + répartiteur UNIQUE `ZChatActionDispatcher`** | le verbe devient une **donnée**, pas une méthode | ✅ **RETENUE**. (1) **Unicité mécaniquement vérifiable** : le répartiteur n'expose que **deux** membres publics (`prepare`/`execute`) — une garde source assertant l'**égalité exacte de cet ensemble** rougit dès qu'un verbe acquiert une méthode dédiée. (2) L'effet réel vit dans `ZChatActionExecutor`, dont les membres sont invocables **depuis un seul fichier** — garde par grep positif borné (G-U1). (3) `sealed` ⇒ chaque nouveau verbe **doit** déclarer sa destructivité (membre abstrait) : l'oubli **ne compile pas**. (4) Les deux surfaces d'IFFD, portées, construisent la **même valeur** `ZChatAction` et la remettent au **même** répartiteur : la divergence n'a plus d'endroit où exister. |

**Conforme au précédent maison** : c'est exactement le patron déjà arbitré et livré en CHAT-0 pour
`ZContentBlock` — **`sealed` INTERNE** (exhaustivité pour le socle) **+ un variant ouvert**
(`ZChatCustomAction`) pour l'extension inter-package, AD-4 étant respecté puisque l'extension ne passe
**pas** par l'héritage externe.

### D2 — 🔴 OÙ VIT LA CONFIRMATION : le domaine **exige et refuse**, l'UI **rend**. Les deux, pas l'un ou l'autre.

La question de l'owner (« le domaine décide qu'il faut confirmer, ou expose seulement `isDestructive` ? »)
est un faux dilemme : `isDestructive` **seul** est un drapeau consultatif — IFFD *savait* que supprimer
était destructeur, sa surface B ne le consultait simplement pas.

**Tranché — protocole en deux temps, avec un jeton que seul le domaine peut fabriquer :**

1. `dispatcher.prepare(action)` → `ZResult<ZChatActionPlan>`. Le plan porte l'**impact CHIFFRÉ AVANT
   toute destruction** (`ZChatActionImpact.affectedMessageCount`, patron `deleteMessagesAfter` de lex qui
   **retourne le compte**, DELTA §3.1) et `requiresConfirmation`.
2. Le seul moyen d'obtenir un `ZChatConfirmedAction` est une méthode **du plan** :
   - `ZChatConfirmedAction? proceedWithoutConfirmation()` → **`null`** si `requiresConfirmation` (le
     raccourci ne peut pas contourner une action destructrice) ;
   - `ZChatConfirmedAction confirmedByUser()` → à n'appeler **qu'après** l'accord réel de l'utilisateur.
3. `dispatcher.execute(confirmed)` **refuse** (`Left(ZChatActionNotConfirmedFailure)`, **sans jamais
   toucher l'executor**) un plan destructeur non confirmé.

🔴 **Le constructeur de `ZChatConfirmedAction` est PRIVÉ** (`ZChatConfirmedAction._`) et vit **dans le même
fichier** que `ZChatActionPlan` : aucun package hôte ne peut en fabriquer un. On ne peut donc pas exécuter
une action destructrice sans être passé par `prepare` — **contrainte de compilation, pas de discipline**.

**Ce qui reste app-side** (jamais dans le domaine — AD-2/AD-13/FR-26) : le rendu du dialogue, les libellés
(`ZcrudLabels` / `label(context, 'chat.…')` — **existant, 121 sites**, à réutiliser), les icônes, les
couleurs, la persistance, et la **décision** d'afficher le dialogue. Le domaine ne connaît **aucun** widget,
**aucun** `BuildContext`.

⚠️ Limite assumée, à écrire dans la dartdoc : un hôte qui appelle `confirmedByUser()` **sans** avoir montré
de dialogue ment au contrat — le socle ne peut pas l'en empêcher. Ce que le socle garantit : (1) le
raccourci sûr est refusé, (2) le mensonge est **localisé et greppable** en un seul appel nommé.

### D3 — 🔴 L'ANNULATION est un verbe NON DESTRUCTIF qui PORTE la saisie — elle ne peut pas la perdre

Défaut IFFD (`cycle-vie-message.md` §3c) : la poubelle pendant « Réflexion en cours » appelle
`stopSubjectExplaningOnError()` **puis** `delete(requestedMessage.id)` — la question tapée **disparaît**.
Correction lex : `stopStreaming()` n'a **aucune** référence à `delete` (`lex-cycle-vie.md` §Annuler).

**Tranché, plus fort que lex** : ne pas se contenter d'une séparation *par convention*.
`ZChatCancelAction` **transporte** la saisie (`ZChatDraft {text, attachmentIds}`) et le contrat impose que
`ZChatActionOutcome.preservedDraft` de l'annulation soit **égal** au brouillon soumis. Un `execute` qui
perdrait ou viderait le brouillon est **détectable par assertion**, pas par relecture (G-A1).
`ZChatCancelAction.isDestructive == false` et `preservesDraft == true`, **membres abstraits** de la classe
scellée : un futur verbe ne peut pas « oublier » de se prononcer.

### D4 — Annulation **par requête**, et le répartiteur ne détient **AUCUN** état

Défaut IFFD : `CancelToken` d'**instance** partagé ⇒ annuler un flux annule le mauvais.
`ZChatCancelAction` porte un **`requestId` requis** ; l'executor expose `cancelRequest(String requestId)`.
🔴 **`ZChatActionDispatcher` n'a qu'un seul champ, `final ZChatActionExecutor executor`** — aucun champ
mutable, aucun `late`, aucun `static` mutable, aucun jeton d'instance. Garde source **et** garde
comportementale (deux requêtes concurrentes, annuler A ne touche pas B) — G-T1.
⚠️ Le `CancelToken`/`StreamSubscription` **réel** appartient à CHAT-1 : ici on fixe **l'adressage** (par
requête), pas le transport.

### D5 — 🔴 `Either<ZFailure, T>` sur CHAQUE verbe, et rien ne lève — l'exception ne peut plus devenir une réponse

Défaut IFFD n°4 : le **texte d'exception brut affiché comme contenu de réponse**.
Forme de référence **vérifiée chez lex** : `chat_repository.dart` porte **16** `Either<Failure, T>`, dont
`Stream<Either<Failure, ChatStreamEvent>>` (plan l.530-533).

**Tranché** : (1) **tout** membre de `ZChatActionExecutor` et **tout** membre public du répartiteur
retournent `Future<ZResult<…>>` — jamais un type nu, jamais `void`, jamais `Unit` nu là où un **compte**
est disponible (leçon lex `deleteMessagesAfter`) ; (2) le répartiteur **enveloppe chaque appel à
l'executor** : une implémentation hôte qui **lève** produit un `Left`, jamais une propagation, **jamais un
message** (AD-10) ; (3) `ZChatActionOutcome` **ne porte aucun champ de texte libre** susceptible de servir
de contenu de bulle — le seul texte qu'il transporte est le **rendu de copie** demandé explicitement par
`ZChatCopyAction`. Garde G-E1 + G-E2.

### D6 — 🔴 Aucune CASCADE silencieuse : la cascade est une donnée du plan, chiffrée avant destruction

Défaut IFFD n°1 : le pied de requête supprime **question ET réponse** en cascade — la surface A le confirme,
la surface B non, et **aucune** ne dit combien.
**Tranché** : `ZChatActionImpact {affectedMessageCount, cascadesToRequestAndResponse, posteriorMessageCount}`
est calculé par `executor.estimateImpact(action)` **avant** exécution ; `requiresConfirmation` est **dérivé**
et vaut `true` dès que `isDestructive || cascades || affectedMessageCount > 1`. Une cascade **non annoncée**
est donc impossible : il n'existe pas de chemin d'exécution qui ne passe pas par un plan chiffré.

### D7 — 🔴 SOFT-DELETE : ici **zcrud prime sur lex**

lex fait un **hard delete** (`chat_repository_impl.dart:408-424, 247-254` — aucun flag posé) ; IFFD aussi
(`FirebaseCrudRepositoryImpl.delete()` → `documentReference.delete()`, alors qu'un `softDelete()` existe
ligne 365 et n'est **jamais appelé**). **Les deux divergent d'AD-9.**

**Tranché** : le seul membre de retrait du contrat s'appelle **`softDeleteMessages`** ; `ZChatActionOutcome`
d'une suppression porte `softDeleted == true`. Le contrat **n'expose aucun** membre de suppression dure
(grep négatif prouvé sur `hardDelete`/`purge`/`deleteForever` dans le dossier — G-S1).
⚠️ **Le drapeau `is_deleted` lui-même appartient à `ZSyncMeta`, HORS entité** (AD-16/AD-19, décision D3 de
CHAT-0) : le contrat **nomme** la sémantique, il ne persiste rien et n'écrit **jamais** `is_deleted`.

### D8 — 🔴 ANTI-DUPLICATION : ce contrat est un **contrat de DOMAINE**, pas un menu — `ZItemAction` reste la couche de rendu

Piège n°2 de la carte (`CARTE-ANTI-DUPLICATION.md` §2) : *« `ZItemActionsMenu`/`ZItemAction`/`ZBatchAction`
vs un nouveau `ZMessageActionMenu` maison plus pauvre — **motif CR-LEX-78 explicite** »*.

**Vérifié sur disque** :
- `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart:61-81` — `ZItemAction {kind, label,
  icon, onSelected}` : **présentation** (porte `IconData`, `String label` injecté), règle AD-4
  « `onSelected == null` ⇒ action **ABSENTE** » appliquée **en amont** (l.168-169).
- `packages/zcrud_core/lib/src/presentation/list/z_batch_action.dart:63-83` — `ZBatchAction`, même patron,
  couche **présentation** du cœur (importe `package:flutter/material.dart`).
- `packages/zcrud_ui_kit/lib/src/domain/z_app_bar_action.dart:15` — `ZAppBarAction` (+ `isOverflow`).

⇒ **Aucun recouvrement** : ces trois types déclarent **comment afficher** un geste (glyphe, libellé, repli
de dépassement) ; `ZChatAction` déclare **ce que le geste fait** et **à quelles conditions** (domaine pur,
zéro Flutter). **La règle de projection est NORMATIVE et doit figurer en dartdoc** :

> un hôte construit **son** `ZItemAction`/`ZBatchAction` (libellé i18n + icône **de l'hôte**) dont
> `onSelected` appelle `prepare` → confirmation → `execute`. Le socle ne fournit **aucun** menu de message,
> **aucun** libellé, **aucune** icône. La règle « callback nul ⇒ action absente » reste celle de
> `ZItemAction` — elle est **réutilisée**, pas réimplémentée.

🔴 **Interdit explicite, gardé par grep négatif** (G-D2) : aucun symbole `ZMessageAction*`,
`ZChatActionMenu`, `ZChatItemAction`, ni aucun champ `label`/`icon` sur un type d'action de chat.

#### D8.1 — « Et si `ZMessageAction` **étendait** `ZItemAction` ? » — 🔴 NON, et pour quatre raisons dont une fatale

La question est légitime (réutiliser plutôt que dupliquer, c'est la consigne). Elle est tranchée **NON** :

1. **Impossible mécaniquement.** `ZItemAction` vit dans `packages/zcrud_study/lib/src/presentation/` —
   un package **satellite** qui dépend de `zcrud_core`. Hériter depuis le cœur créerait l'arête
   `zcrud_core → zcrud_study` : **cycle AD-1**, `graph_proof` **CORE OUT ≠ 0**, `melos run verify` ROUGE.
   Le dépôt a **déjà tranché ce point précis** : `z_batch_action.dart:1-8` documente que `ZBatchAction`
   est une **duplication VOULUE** du patron de `ZItemActionsMenu` *« une arête core→study serait un cycle
   AD-1 — la variance est assumée (les deux modèles partagent le patron sans partager de type) »*.
2. **Cela importerait la présentation dans le domaine.** `ZItemAction` porte `IconData icon` et
   `String label` ⇒ tout héritier tire `package:flutter/material.dart` et un libellé dans
   `zcrud_core/domain` : **AD-2 + AD-13 + FR-26** violés d'un coup, et la garde de pureté existante
   (`domain_purity_test.dart`) rougit.
3. **AD-4 rejette l'héritage** comme mécanisme d'extension inter-package (« Rejetés : héritage de classes
   sérialisées, `sealed` pour l'extension inter-package »). Le socle étend par **variant ouvert + registre**,
   jamais par sous-classement d'un type d'un autre package.
4. 🔴 **La raison fatale — l'héritage réintroduirait EXACTEMENT le défaut que la story corrige.**
   `ZItemAction` porte `VoidCallback? onSelected`. Un `ZMessageAction extends ZItemAction` hériterait donc
   d'un **second chemin d'exécution** — le callback — **à côté** du répartiteur. Deux surfaces pourraient
   de nouveau porter deux `onSelected` divergents pour le même verbe : c'est la forme **(b)** rejetée en
   D1, et littéralement la structure d'IFFD (dont le défaut « Copier » est un `onTap: () {}` vide). La
   garde **G-U1** deviendrait incapable de mordre : l'effet ne passerait plus par un identifiant unique.

**Ce qui est réutilisé à la place** : la **relation de projection**, pas la relation d'héritage.
L'hôte instancie `ZItemAction(kind: …, label: <i18n hôte>, icon: <icône hôte>, onSelected: () =>
prepare → confirmer → execute)`. Le geste est déclaré une fois côté rendu (avec sa règle « callback nul ⇒
action absente », inchangée), l'effet reste **unique** côté domaine. Aucun type n'est dupliqué : les deux
couches modélisent deux choses différentes.

### D9 — Ce qui est RÉUTILISÉ, et ce qui est créé (une seule failure neuve, justifiée)

| Besoin | Brique **EXISTANTE** réutilisée | Chemin vérifié |
|---|---|---|
| Type de résultat | `ZResult<T> = Either<ZFailure, T>` | `z_failure.dart:194` |
| Hiérarchie d'erreurs | `ZFailure` (`abstract`, extensible — **jamais `sealed`**, AD-4) | `z_failure.dart:22-41` |
| Quota IA dépassé | **`ZQuotaExceededFailure`** (+`retryAfter`) — **ne PAS inventer** de `ZChatQuotaFailure` (piège n°3) | `z_failure.dart:109-129` |
| Verbe non supporté par l'hôte ⇒ action à masquer | **`ZUnsupportedOperationFailure(operation:)`** — c'est **littéralement** son cas d'usage documenté (repli déterministe sans parser de chaîne) | `z_failure.dart:167-187` |
| Identités de message/conversation, brouillon d'attachements | `ZChatMessage.id`, `ZChatMessage.conversationId`, `ZChatAttachment` (CHAT-0) | `domain/chat/z_chat_message.dart:152-155` |
| Égalité/hachage de payload JSON | `zJsonEquals` / `zJsonHash` — **implémentation UNIQUE du repo** | `extension/z_json_equality.dart` |
| Lecture défensive (si un payload est lu) | `z_json_read.dart` (surface **PARTAGÉE**, CHAT-0 ⓪) | `domain/json/z_json_read.dart` |
| Rendu du menu / libellés / icônes | `ZItemAction`(+`Menu`), `ZBatchAction`, `ZAppBarAction`, `ZcrudLabels`/`label(context,key)` | cf. D8 |

**Créé — UN SEUL nouveau `ZFailure`** : `ZChatActionNotConfirmedFailure extends ZFailure {final String verb;}`.
Justification (et pourquoi pas un `ZDomainFailure` nu) : le dartdoc de `ZQuotaExceededFailure`/
`ZUnsupportedOperationFailure` documente le défaut exact que la story ne doit pas rejouer — *aplatir la
distinction dans le `message` force l'hôte à **parser du texte** pour décider*. Refuser faute de
confirmation et échouer pour une panne appellent **deux réactions opposées** (rouvrir le dialogue vs
remonter l'erreur) : le type est structurant, il porte le `verb` pour un diagnostic sans parsing.
🚫 **Aucune autre failure n'est créée dans cette story** — les familles d'erreurs IA (modération, contexte
trop long, réponse vide) appartiennent à **CHAT-1**.

### D10 — Aucune persistance, donc aucun câblage du gate `reserved-keys`

Les actions sont des **commandes éphémères**, pas des entités : **pas** de `ZEntity`, **pas** de mixin
`ZExtensible`, **pas** de `toMap`/`fromMap`, **pas** de slot `extra`. Conséquence machine **vérifiée** :
`scripts/ci/gate_reserved_keys.dart` dérive sa population des entités **`ZExtensible`** (registrars générés
+ `kManualProbes`) ⇒ **aucune sonde à ajouter**, contrairement à CHAT-0/AC12.
🔴 Corollaire à respecter : si le dev éprouve le besoin d'ajouter `extra` ou `toMap` à une action, **il sort
du périmètre** — l'extension passe par `ZChatCustomAction(verb, payload)`.

### D11 — Pas d'historique de versions : ne PAS inventer ce que ni lex ni IFFD ne font

Grep négatif **vérifié dans les deux dépôts** : aucun champ `history`/`previousContent`/`versions`/
`supersedes`/`parentVersionId` (`chat_message.dart` de lex, `chatbot_message.dart` d'IFFD, 390 l.).
Le `versionKey` de lex est un **tag de version de prompt/dataset**, sans rapport (déjà porté tel quel en
CHAT-0). ⇒ Le contrat **ne modélise aucun undo de contenu**. Ce qui est porté, c'est le correctif **réel**
de lex : à l'annulation d'une édition, **le texte tapé est restauré** — ce que garantit ici `ZChatDraft`
(D3), sans inventer d'historique persistant.

---

## Acceptance Criteria

> **Discipline R3 obligatoire.** Chaque garde doit être prouvée **mordante** : injecter précisément la
> régression décrite, constater le **rouge**, restaurer, constater le **vert**, consigner chemin/ligne/
> symptôme dans le Dev Agent Record. **Une garde qui reste verte après retrait du correctif est rejetée.**
> Une garde sans sa régression nommée n'est pas une garde.

1. **AC1 — Emplacement, pureté, barrel.** Tous les types naissent sous
   `packages/zcrud_core/lib/src/domain/chat/action/`, en **pur Dart** : zéro `import 'package:flutter/…'`,
   zéro `dart:ui`, zéro `package:zcrud_*`, zéro type backend, zéro widget/`BuildContext`, zéro couleur,
   icône ou libellé d'affichage. Exports ajoutés à `packages/zcrud_core/lib/domain.dart` dans la section
   « chat », **ordre alphabétique** respecté (lint `directives_ordering`).
   `packages/zcrud_core/test/purity/domain_purity_test.dart` reste vert **et couvre le nouveau
   sous-dossier** (à vérifier explicitement, pas à supposer).

2. **AC2 — Aucune arête, aucune dépendance, aucun codegen.** `packages/zcrud_core/pubspec.yaml`
   **inchangé**. `python3 scripts/dev/graph_proof.py` vert (**ACYCLIQUE**, **CORE OUT = 0**). Aucun `part`,
   aucun `*.g.dart`, aucune annotation `@ZcrudModel`/`@JsonSerializable`. `melos run generate` **non
   exécuté**.

3. **AC3 — 🔴 Intentions scellées : le verbe est une DONNÉE (D1).** `sealed class ZChatAction` porte les
   **membres abstraits** `String get verb`, `bool get isDestructive`, `bool get cascades`,
   `bool get preservesDraft` — un nouveau variant qui ne se prononce pas **ne compile pas**. Variants
   livrés, tous `const`, `==`/`hashCode` structurels :
   `ZChatEditAction {messageId, newText, draft}` (destructif : entraîne la reprise des messages postérieurs) ·
   `ZChatRegenerateAction {messageId}` (non destructif côté persistance) ·
   `ZChatDeleteAction {messageId, cascadeToPair}` (destructif, cascade) ·
   `ZChatCancelAction {requestId, draft}` (non destructif, `preservesDraft == true`) ·
   `ZChatCopyAction {messageId, format}` (lecture seule) ·
   `ZChatCustomAction {verb, payload, required isDestructive, required cascades}` — **variant ouvert**
   (AD-4 : `sealed` INTERNE + variant ouvert, patron `ZCustomContentBlock` de CHAT-0 ; `isDestructive`
   **requis**, jamais de défaut permissif).
   🚫 Aucun champ `label`, `icon`, `tooltip`, `color` sur AUCUN de ces types (D8).

4. **AC4 — 🔴 Répartiteur UNIQUE : exactement deux membres publics.** `ZChatActionDispatcher` est une classe
   **concrète, pure, sans état** dont la **surface publique est exactement**
   `{prepare(ZChatAction) → Future<ZResult<ZChatActionPlan>>,
     execute(ZChatConfirmedAction) → Future<ZResult<ZChatActionOutcome>>}`
   — **aucune** méthode publique par verbe, **aucun** raccourci de confort (`deleteMessage()`,
   `regenerate()`…). Son **seul champ** est `final ZChatActionExecutor executor` : aucun champ mutable,
   aucun `late`, aucun `static` mutable, **aucun jeton d'annulation d'instance** (D4).

5. **AC5 — 🔴 L'effet vit dans UN SEUL fichier appelant.** `abstract interface class ZChatActionExecutor`
   (l'app hôte l'*implements*) déclare les membres d'effet :
   `estimateImpact` · `editAndResend` · `regenerate` · `softDeleteMessages` · `cancelRequest` ·
   `renderForCopy` · `executeCustom`. **Chacun retourne `Future<ZResult<…>>`** (D5).
   🔴 **Invariant central de la story** : ces identifiants ne sont **invoqués** que depuis
   `z_chat_action_dispatcher.dart`. Toute autre occurrence en position d'appel dans `packages/*/lib`
   est une **violation** (G-U1). Un verbe non implémenté renvoie `Left(ZUnsupportedOperationFailure(
   operation: '<membre>'))` — **type EXISTANT réutilisé**, jamais une failure neuve (D9).

6. **AC6 — 🔴 Confirmation : protocole en deux temps à jeton infalsifiable (D2).**
   `ZChatActionImpact {affectedMessageCount, posteriorMessageCount, cascadesToRequestAndResponse}` ·
   `ZChatActionPlan {action, impact, requiresConfirmation}` ·
   `ZChatConfirmedAction` à **constructeur PRIVÉ**, déclaré **dans le même fichier** que le plan, obtenu
   **uniquement** par `plan.confirmedByUser()` ou `plan.proceedWithoutConfirmation()`.
   `requiresConfirmation` est **DÉRIVÉ** : `action.isDestructive || action.cascades ||
   impact.affectedMessageCount > 1` (D6). `proceedWithoutConfirmation()` retourne **`null`** —
   jamais un jeton — quand `requiresConfirmation` est vrai.

7. **AC7 — 🔴 Refus vérifiable, executor jamais touché.** `execute` d'un `ZChatConfirmedAction` dont le plan
   exigeait une confirmation et qui n'a **pas** été confirmé par l'utilisateur retourne
   `Left(ZChatActionNotConfirmedFailure(verb: …))` **et n'appelle AUCUN membre de l'executor**
   (prouvé par un executor-espion à compteur d'appels == 0). `ZChatActionNotConfirmedFailure extends
   ZFailure` avec `==`/`hashCode`/`toString` incluant `verb` (patron `ZUnsupportedOperationFailure`).

8. **AC8 — 🔴 L'annulation PRÉSERVE la saisie (D3).** `execute(ZChatCancelAction)` : (a) n'appelle **que**
   `executor.cancelRequest(requestId)` ; (b) n'appelle **jamais** `softDeleteMessages` ni
   `editAndResend` (espion == 0) ; (c) retourne un `ZChatActionOutcome` dont `preservedDraft` est
   **égal** (égalité structurelle) au `draft` de l'action. La dartdoc nomme la régression IFFD
   (`chatbot_conversation_screen.dart:3618-3672`) qu'elle interdit.

9. **AC9 — 🔴 Annulation par requête, zéro état partagé (D4).** `ZChatCancelAction.requestId` est
   **requis** ; deux requêtes concurrentes `r1`/`r2` : annuler `r1` transmet `r1` — et **seulement** `r1` —
   à l'executor. Aucun champ d'instance ne mémorise de requête « courante ».

10. **AC10 — 🔴 `Either` partout, rien ne lève, aucune exception ne devient un message (D5).**
    (a) Garde source : **tout** membre public de l'executor et du répartiteur a un type de retour
    `Future<ZResult<` — aucune exception à la règle ; (b) un executor hôte qui **lève** ⇒ `execute`
    retourne `Left`, **ne propage pas**, et **ne produit aucun `ZChatMessage`** ; (c) `ZChatActionOutcome`
    ne porte **aucun** champ de texte libre autre que `copyPayload`, alimenté **uniquement** par
    `ZChatCopyAction` ; (d) `throw` **absent** du dossier `action/` (grep négatif prouvé).

11. **AC11 — 🔴 Soft-delete, jamais de hard-delete (D7, AD-9).** Le seul membre de retrait est
    `softDeleteMessages` ; l'`outcome` d'une suppression porte `softDeleted == true` et la liste des ids
    affectés. Grep négatif prouvé : `hardDelete`/`deleteForever`/`purge`/`is_deleted` **absents** du
    dossier `action/`. La dartdoc dit explicitement que **lex et IFFD divergent d'AD-9 sur ce point et que
    zcrud prime**.

12. **AC12 — 🔴 Pas de doublon de menu, et aucun héritage de la couche de rendu (D8, D8.1).** Grep négatif
    prouvé dans `packages/*/lib` : aucun symbole `ZMessageAction`, `ZMessageActionMenu`,
    `ZChatActionMenu`, `ZChatItemAction` ; **aucun `extends ZItemAction`/`ZBatchAction`/`ZAppBarAction`** ;
    **aucun `VoidCallback`** sous `action/` (un callback serait un **second chemin d'exécution**, D8.1 §4).
    La dartdoc de `ZChatAction` énonce la **règle de projection** vers `ZItemAction`/`ZBatchAction`/
    `ZAppBarAction` (existants) et rappelle la règle AD-4 « callback nul ⇒ action **absente** », qui n'est
    **pas** réimplémentée.

13. **AC13 — Aucune persistance, aucun câblage de gate (D10).** Aucun type d'action n'est `ZEntity`, ne
    mixe `ZExtensible`, ne porte `extra`, `toMap` ni `fromMap`.
    `tool/reserved_keys_gate/lib/src/manual_probes.dart` est **inchangé** ;
    `dart run scripts/ci/gate_reserved_keys.dart` **RC=0**.

14. **AC14 — Neutralité totale.** Aucun fichier de production existant n'est modifié **hors**
    `packages/zcrud_core/lib/domain.dart` (ajout d'exports). Aucun comportement existant ne change ; aucun
    test existant n'est réécrit pour « passer ». Le total de `zcrud_core` est **1244 + N**, N = nombre exact
    de tests CHAT-0b ajoutés (**aucune disparition** — baseline mesurée par l'orchestrateur).

15. **AC15 — Vérif verte.** `dart run melos run analyze` **RC=0** ; depuis `packages/zcrud_core`,
    `flutter test` **RC=0** (jamais `dart test` : faux rouge `dart:ui`) ; `dart run melos run verify`
    **RC=0** repo-wide.

---

## Tasks / Subtasks

- [ ] **T0 — Lire avant d'écrire** (toutes AC)
  - [ ] `packages/zcrud_core/lib/src/domain/chat/z_content_block.dart:80-100, 211-230` — **le patron
        exact** de `sealed` interne + variant ouvert + membre abstrait discriminant. **Décalquer**.
  - [ ] `packages/zcrud_core/lib/src/domain/failures/z_failure.dart` **intégralement** — surtout les
        dartdoc de `ZQuotaExceededFailure:94-108` et `ZUnsupportedOperationFailure:131-166` : ils
        **nomment le défaut** (« parser du texte pour décider ») que D9 interdit de rejouer.
  - [ ] `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:153-164` — forme canonique
        d'un port `abstract interface class` + `Future<ZResult<…>>` + dartdoc « la mécanique de transport
        ne fuit pas dans le domaine ».
  - [ ] `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart:61-104` et
        `packages/zcrud_core/lib/src/presentation/list/z_batch_action.dart:38-83` — pour **constater** que
        ce sont des types de **présentation** (D8) et ne pas les dupliquer.
  - [ ] `packages/zcrud_core/test/domain/chat/z_chat_naming_guard_test.dart` — **le patron exact** d'une
        garde par scan de source (helpers `_repoRoot`, `_packageLibDartFiles`, `_stripComment`). Les
        gardes structurelles de cette story les **réutilisent**, ne les recopient pas à l'identique sans
        raison.
  - [ ] LECTURE SEULE : `/tmp/zcrud-lexplus/lex-cycle-vie.md` (les 5 verbes chez lex) et
        `/tmp/zcrud-notebook/cycle-vie-message.md` (les 4 points de suppression d'IFFD).

- [ ] **T1 — Intentions** (AC3)
  - [ ] `action/z_chat_action.dart` : `ZChatDraft {text, attachmentIds}` (`const`, `==`/`hashCode`,
        `zListEquals`) + `sealed class ZChatAction` (4 membres abstraits) + les 6 variants.
  - [ ] Dartdoc de la classe : la règle **« un verbe = un seul site d'appel »**, la **table des 3 formes
        pesées** (D1) en une ligne chacune, la **règle de projection** vers `ZItemAction` (D8).

- [ ] **T2 — Plan, impact, jeton** (AC6)
  - [ ] `action/z_chat_action_plan.dart` : `ZChatActionImpact`, `ZChatActionPlan`, **et**
        `ZChatConfirmedAction` à constructeur **privé** — 🔴 **les trois dans CE fichier** (le privé est
        à portée de *bibliothèque* : les séparer casserait la garantie).
  - [ ] `requiresConfirmation` **dérivé** (jamais un champ que l'appelant renseigne).

- [ ] **T3 — Résultat & failure** (AC7, AC10, AC11)
  - [ ] `action/z_chat_action_outcome.dart` : `ZChatActionOutcome {verb, affectedMessageIds, softDeleted,
        preservedDraft, copyPayload}` — aucun autre texte libre.
  - [ ] `action/z_chat_action_failure.dart` : `ZChatActionNotConfirmedFailure extends ZFailure` (+`verb`).
        🚫 **Aucune autre failure.** Réutiliser `ZQuotaExceededFailure`/`ZUnsupportedOperationFailure`.

- [ ] **T4 — Port d'effet** (AC5)
  - [ ] `action/z_chat_action_executor.dart` : `abstract interface class` à 7 membres, tous
        `Future<ZResult<…>>`. Dartdoc : « **ces membres ne sont appelés que par
        `ZChatActionDispatcher`** — toute autre invocation est une violation, gardée par G-U1 ».

- [ ] **T5 — Répartiteur** (AC4, AC7, AC8, AC9, AC10)
  - [ ] `action/z_chat_action_dispatcher.dart` : `prepare` + `execute`, **rien d'autre en public**.
        `switch` **exhaustif** sur `ZChatAction` (le compilateur refusera un variant non traité).
  - [ ] Chaque appel à l'executor **enveloppé** : une exception hôte devient `Left`, jamais une
        propagation, jamais un message (D5).
  - [ ] Vérifier ligne à ligne : **aucun** champ mutable, **aucun** `late`, **aucun** `static` mutable.

- [ ] **T6 — Barrel** (AC1)
  - [ ] Ajouter les 6 exports à `packages/zcrud_core/lib/domain.dart`, section « chat », **ordre
        alphabétique** (`chat/action/…` se place avant `chat/z_chat_attachment.dart`).

- [ ] **T7 — Tests R3** (toutes AC)
  - [ ] `packages/zcrud_core/test/domain/chat/action/` : `z_chat_action_test.dart`,
        `z_chat_action_plan_test.dart`, `z_chat_action_dispatcher_test.dart`,
        `z_chat_action_contract_guard_test.dart` (gardes **structurelles** par scan de source).
  - [ ] Écrire un **executor-espion** (fake à compteurs + journal d'appels) — c'est lui qui rend
        démontrables « executor jamais touché » (AC7) et « annuler n'appelle pas delete » (AC8).
  - [ ] Exécuter **chaque** injection du plan ci-dessous, consigner rouge→vert.

- [ ] **T8 — Gates de sortie** (AC15)
  - [ ] `dart run melos run analyze` → RC=0.
  - [ ] `packages/zcrud_core` → `flutter test` → RC=0, total **1244 + N**.
  - [ ] `dart run melos run verify` → RC=0 (repo-wide, au repos).
  - [ ] **Ne pas** exécuter `melos run generate` ; **ne pas** committer (commit unique en fin d'epic) ;
        **ne pas** toucher `sprint-status.yaml`, `pubspec.yaml`, `manual_probes.dart`.

---

## Plan de tests détaillé — R3

> Chaque ligne nomme **la régression exacte** qui doit faire rougir la garde. Une garde dont l'injection
> laisse le vert est **rejetée** (précédent VIS-1 : première injection non mordante — le défaut était dans
> la garde, pas dans le code).

| Garde | Fichier | Assertion verte | Régression à ré-injecter → rouge attendu |
|---|---|---|---|
| **G-U1 — 🔴 UNICITÉ DU SITE D'APPEL (garde décisive, STRUCTURELLE)** | `z_chat_action_contract_guard_test.dart` | Scan de `packages/*/lib/**.dart` (commentaires retirés) : pour **chacun** des 7 identifiants d'effet (`estimateImpact`, `editAndResend`, `regenerate`, `softDeleteMessages`, `cancelRequest`, `renderForCopy`, `executeCustom`), les fichiers contenant une **invocation** (`identifiant(`) sont **exactement** `{z_chat_action_executor.dart (déclaration), z_chat_action_dispatcher.dart}` | Ajouter `executor.softDeleteMessages(...)` dans **un second fichier** de `packages/zcrud_core/lib` (simuler la « surface B » d'IFFD) ⇒ la garde nomme le fichier fautif et rougit. **C'est LA garde qui empêche la récidive** : elle rougira aussi en C2/C7 si un controller court-circuite le répartiteur. |
| **G-U2 — surface publique du répartiteur figée** | idem | Le scan des déclarations de méthodes publiques de `z_chat_action_dispatcher.dart` rend **exactement** `{prepare, execute}` (égalité d'ensemble, pas « contient ») | Ajouter une méthode de confort `Future<ZResult<ZChatActionOutcome>> deleteMessage(String id)` ⇒ rouge. **Une garde « contient prepare et execute » ne mordrait PAS** : l'égalité d'ensemble est obligatoire. |
| **G-U3 — exhaustivité scellée** | `z_chat_action_test.dart` | Un test énumère les **6** variants et vérifie que chacun expose `verb`/`isDestructive`/`cascades`/`preservesDraft` ; les `verb` sont **deux à deux distincts** | Ajouter un 7ᵉ variant sans le traiter dans le `switch` du répartiteur ⇒ **rouge de COMPILATION** (à qualifier comme tel : c'est la garantie `sealed`, pas une assertion) ; **et** rouge d'assertion sur l'énumération si le variant ne se prononce pas. |
| **G-C1 — 🔴 action destructrice sans confirmation ⇒ REFUS, executor INTACT** | `z_chat_action_dispatcher_test.dart` | Pour **chaque** variant destructeur : `plan.proceedWithoutConfirmation()` ⇒ `null` ; un jeton non confirmé ⇒ `Left(ZChatActionNotConfirmedFailure)` **et espion : 0 appel** | (a) Faire retourner un jeton par `proceedWithoutConfirmation()` même quand `requiresConfirmation` ⇒ rouge ; (b) retirer le contrôle de `execute` (reproduire IFFD `chatbot_conversation_screen.dart:3886-3908`, suppression silencieuse) ⇒ **rouge sur le compteur de l'espion** — c'est cette seconde injection qui prouve que le refus précède l'effet, pas seulement qu'il retourne un `Left`. |
| **G-C2 — le jeton est infalsifiable** | `z_chat_action_contract_guard_test.dart` | Scan : `ZChatConfirmedAction` est déclarée dans `z_chat_action_plan.dart` avec un constructeur **privé** (`ZChatConfirmedAction._`) et **aucun** constructeur public/factory | Rendre le constructeur public ⇒ rouge. *(Le contournement réel serait alors possible sans qu'aucun test de comportement ne bouge — d'où une garde de source.)* |
| **G-D1 — 🔴 aucune cascade silencieuse** | `z_chat_action_dispatcher_test.dart` | `prepare` d'une suppression en cascade **appelle `estimateImpact` AVANT** tout effet (ordre du journal de l'espion) et produit `requiresConfirmation == true` avec `affectedMessageCount == 2` | (a) Dériver `requiresConfirmation` du seul `isDestructive` (ignorer `cascades`/`affectedMessageCount > 1`) ⇒ une cascade Q+R passe sans confirmation ⇒ rouge ; (b) déplacer `estimateImpact` **après** l'effet ⇒ rouge sur l'ordre du journal (l'impact ne serait plus annonçable **avant** destruction — le défaut IFFD exact). |
| **G-A1 — 🔴 annuler PRÉSERVE la saisie** | `z_chat_action_dispatcher_test.dart` | `execute(ZChatCancelAction(requestId:'r1', draft: d))` ⇒ `outcome.preservedDraft == d` ; espion : `cancelRequest` **1**, `softDeleteMessages` **0**, `editAndResend` **0** | Réintroduire le comportement IFFD (`:3618-3672`) : faire suivre `cancelRequest` d'un `softDeleteMessages` ⇒ **deux** rouges (compteur ≠ 0 **et** brouillon perdu). Second cas : renvoyer un `outcome` sans brouillon ⇒ rouge. |
| **G-A2 — le brouillon survit à l'ÉCHEC de l'annulation** | idem | Executor qui renvoie `Left` sur `cancelRequest` ⇒ `Left` propagé **et** aucune destruction ; le brouillon reste intact côté appelant (il n'a jamais été remis à l'executor) | Faire « nettoyer » le brouillon dans le chemin d'échec ⇒ rouge. *(Perte de travail utilisateur : jamais acceptable, y compris sur un chemin d'erreur.)* |
| **G-T1 — 🔴 annulation PAR REQUÊTE, aucun jeton partagé** | `z_chat_action_dispatcher_test.dart` + garde source | Comportement : deux annulations `r1` puis `r2` ⇒ l'espion reçoit exactement `['r1','r2']`. Source : `z_chat_action_dispatcher.dart` ne déclare **aucun** champ non-`final`, aucun `late`, aucun `static` mutable | Introduire `String? _currentRequestId;` mémorisé par le répartiteur et utilisé à la place de `action.requestId` ⇒ **rouge de source** (champ mutable) **et** rouge de comportement (l'espion reçoit deux fois le même id). **Les deux injections sont obligatoires** : la garde de source seule ne prouve pas l'usage, la garde de comportement seule laisserait passer un champ dormant. |
| **G-E1 — `Either` sur CHAQUE verbe (garde de source)** | `z_chat_action_contract_guard_test.dart` | Dans `z_chat_action_executor.dart` et `z_chat_action_dispatcher.dart`, **toute** déclaration de membre public a un type de retour commençant par `Future<ZResult<` ; **0** membre `void`/`Future<void>`/type nu | Changer `Future<ZResult<Unit>> cancelRequest(...)` en `Future<void> cancelRequest(...)` (le style IFFD) ⇒ rouge, en nommant le membre fautif. |
| **G-E2 — 🔴 une exception hôte ne devient JAMAIS une réponse** | `z_chat_action_dispatcher_test.dart` | Executor dont un membre **lève** ⇒ `execute` retourne `Left` (`ZFailure`), `returnsNormally`, aucun `ZChatMessage` produit, et le **message d'exception brut n'apparaît dans aucun champ de l'`outcome`** | Retirer l'enveloppe de garde autour de l'appel executor ⇒ l'exception remonte ⇒ rouge. Second cas (défaut IFFD n°4) : recopier le texte de l'exception dans `outcome.copyPayload` ⇒ rouge sur l'assertion « le texte d'exception n'apparaît nulle part ». |
| **G-E3 — `throw` absent du dossier (grep négatif prouvé)** | garde source | **0** occurrence de `throw ` (hors commentaires) sous `lib/src/domain/chat/action/` | Ajouter un `throw ArgumentError(...)` dans une validation ⇒ rouge. *(AD-10 : tout échec est une valeur.)* |
| **G-S1 — 🔴 soft-delete, jamais de hard-delete (zcrud prime sur lex)** | garde source + comportement | Source : **0** occurrence de `hardDelete`/`deleteForever`/`purge`/`is_deleted` sous `action/` ; le contrat n'expose **qu'un** membre de retrait, nommé `softDeleteMessages`. Comportement : l'`outcome` d'une suppression porte `softDeleted == true` | Renommer le membre en `deleteMessages` **et** poser `softDeleted: false` (le choix de lex, `chat_repository_impl.dart:408-424`) ⇒ **rouge sur les deux** (l'absence de nom sûr **et** le drapeau). |
| **G-D2 — 🔴 pas de doublon de menu (motif CR-LEX-78)** | `z_chat_action_contract_guard_test.dart` | Scan `packages/*/lib` : **0** occurrence de `ZMessageAction`, `ZMessageActionMenu`, `ZChatActionMenu`, `ZChatItemAction` ; **0** champ `label`/`icon`/`tooltip`/`color` **et 0 `VoidCallback`** déclarés sous `action/` ; **0** `extends ZItemAction`/`extends ZBatchAction`/`extends ZAppBarAction` dans `packages/zcrud_core/lib` ; la dartdoc de `ZChatAction` **cite `ZItemAction`** (règle de projection, D8.1) | (a) Déclarer `class ZMessageAction { final String label; final IconData icon; }` ⇒ rouge ; (b) déclarer `class ZMessageAction extends ZItemAction` ⇒ rouge **de la garde** (le `extends` interdit) **et** rouge de compilation/`graph_proof` (arête `core → study`, D8.1) — les deux à qualifier séparément ; (c) ajouter un `VoidCallback? onSelected` à un variant d'action ⇒ rouge (c'est le **second chemin d'exécution** que G-U1 ne pourrait plus voir). **Une « absence » non prouvée par un grep négatif n'est pas une preuve** (lentille « réalité du code »). |
| **G-P1 — pureté & neutralité du dossier `action/`** | garde source (+ `test/purity/domain_purity_test.dart` existant) | `lib/src/domain/chat/action/**` : 0 import Flutter/`dart:ui`/`package:zcrud_*`/backend, 0 `Color(0x`, 0 `Colors.`, 0 `Icons.`, 0 `part '`, 0 annotation de codegen ; `pubspec.yaml` inchangé | Ajouter `import 'package:flutter/material.dart';` dans `z_chat_action.dart` ⇒ **le test de pureté EXISTANT** doit rougir — vérifier qu'il **couvre bien** le nouveau sous-dossier ; s'il reste vert, c'est **la garde** qu'il faut corriger, jamais contourner. |
| **G-R1 — réutilisation prouvée des failures existantes** | `z_chat_action_dispatcher_test.dart` | Un executor qui renvoie `Left(ZQuotaExceededFailure(…, retryAfter: …))` traverse `execute` **sans perte de type ni de `retryAfter`** ; un verbe non supporté ⇒ `Left(ZUnsupportedOperationFailure)` avec `operation` renseigné | Envelopper/aplatir la failure de l'executor dans un `ZDomainFailure('…')` générique ⇒ rouge (l'hôte devrait « parser du texte » pour décider — le défaut nommé en `z_failure.dart:99-104`). |
| **G-R2 — aucune failure inventée** | garde source | Sous `action/`, la **seule** déclaration `extends ZFailure` est `ZChatActionNotConfirmedFailure` | Ajouter un `ZChatQuotaFailure` (piège n°3 de la carte) ⇒ rouge. |
| **G-N1 — aucune persistance, gate intact** | garde source + `gate_reserved_keys` | Sous `action/` : 0 `ZExtensible`, 0 `extends ZEntity`, 0 `toMap`, 0 `fromMap`, 0 `extra` ; `manual_probes.dart` **inchangé** ; `dart run scripts/ci/gate_reserved_keys.dart` RC=0 | Faire mixer `ZExtensible` à une action ⇒ rouge de la garde de source **et** (règle (3) du gate) `verify` rouge tant qu'aucune sonde n'est câblée — ce qui **prouve** que D10 est un choix, pas un oubli. |

**Qualifier chaque rouge** : compilation · infrastructure · **vraie assertion**. Un rouge de compilation ne
prouve rien sur une garde d'assertion (il prouve la garantie `sealed` en G-U3, et rien d'autre). Une
injection non réellement appliquée sur disque ⇒ **aucune preuve**.

---

## Dev Notes

### Fichiers et état actuel VÉRIFIÉS sur disque (zcrud — modifiable)

- `packages/zcrud_core/lib/src/domain/chat/` — **12 classes CHAT-0 livrées** (`z_chat_message.dart`,
  `z_chat_conversation.dart`, `z_content_block.dart`, `z_chat_source.dart`, `z_chat_enums.dart`,
  `z_chat_attachment.dart`, `z_chat_suggestion.dart`, `z_chat_thinking_step.dart`,
  `z_chat_response_confidence.dart`, `z_chat_source_freshness.dart`, `z_chat_quota_snapshot.dart`,
  `z_chat_extension_parser.dart`). **0 port / 0 repository / 0 widget consommateur** aujourd'hui
  (motif CR-IFFD-27 à l'échelle d'un module) — cette story est le **premier consommateur**.
- `packages/zcrud_core/lib/src/domain/chat/z_content_block.dart:80-86, 211-219` — `sealed class` +
  `String get kind` abstrait + variants `const`. **Patron à décalquer** pour `ZChatAction`.
- `packages/zcrud_core/lib/src/domain/chat/z_chat_message.dart:51, 152-155` — `ZChatMessage extends ZEntity
  with ZExtensible`, `id` **nullable** (éphémère = message en cours de streaming), `conversationId`.
- `packages/zcrud_core/lib/src/domain/failures/z_failure.dart` — `ZFailure:22` (abstract, **jamais
  `sealed`** — AD-4 explicite en dartdoc), `ZQuotaExceededFailure:109`, `ZUnsupportedOperationFailure:167`,
  `ZResult<T>:194`.
- `packages/zcrud_core/lib/src/domain/json/z_json_read.dart` — 14 primitives défensives **partagées**
  (CHAT-0 ⓪) : si un payload d'action custom doit être lu, **les utiliser**, ne rien recopier.
- `packages/zcrud_core/lib/src/domain/extension/z_json_equality.dart` — `zJsonEquals`/`zJsonHash`,
  **implémentation UNIQUE du repo** pour l'égalité de payload JSON (les recopier = finding DW-ES22-4).
- `packages/zcrud_core/lib/domain.dart:33-44` — bloc d'exports « chat » existant, ordre alphabétique.
- `packages/zcrud_core/test/domain/chat/z_chat_naming_guard_test.dart` — **patron exact** d'une garde par
  scan de source : `_repoRoot()` (remonte jusqu'à `melos.yaml`), `_packageLibDartFiles()`,
  `_stripComment()`, et surtout le motif **anti-garde-vacuelle** (`expect(files, isNotEmpty)`).
  🔴 **Reprendre ce motif** : une garde qui scanne 0 fichier est verte pour rien.
- `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart:61-104` — `ZItemAction` +
  `menuBuilder` (CR-IFFD-32) + filtrage AD-4 **en amont** (l.168-169) : la **couche de rendu** des gestes.
- `packages/zcrud_core/lib/src/presentation/list/z_batch_action.dart:38-114` — `ZBatchAction` + barre à
  repli de dépassement mesuré (CR-IFFD-36). Lire le dartdoc l.100-114 : il documente pourquoi la
  convention de dépassement est **inspirée, jamais importée** (AD-1) — même discipline ici.
- `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:153-164` — forme canonique du port
  `abstract interface class` + `Future<ZResult<…>>` (AD-5/AD-11), avec la règle « aucune mécanique de
  transport ne fuit dans le domaine ».
- `scripts/ci/gate_reserved_keys.dart` + `tool/reserved_keys_gate/lib/src/manual_probes.dart` — population
  dérivée des entités **`ZExtensible`**. **Rien à câbler ici** (D10) — et c'est vérifiable (G-N1).
- `melos.yaml:104-119` — contenu réel de `verify` (`graph_proof`, gates, `gate_reserved_keys`,
  `verify_serialization`).

### Sources externes (LECTURE SEULE — jamais d'écriture)

| Source | Ce qu'on en prend | Ce qu'on n'en prend PAS |
|---|---|---|
| `lex_ui/.../chat_controller.dart` (via `/tmp/zcrud-lexplus/lex-cycle-vie.md`) | 1 méthode par verbe, 1 call-site ; `deleteMessagesAfter` **retournant le compte** ; `stopStreaming()` sans aucun `delete` ; `StreamSubscription` **par appel** ; restauration du texte à l'annulation d'édition | le **hard delete** (D7) ; l'absence de confirmation sur `regenerate` **laissée telle quelle** (ici la règle est uniforme : c'est le **plan** qui décide, pas le verbe) ; le mapping status-code non typé (angle mort résiduel de lex, DELTA §7) |
| `lex_core/.../chat_repository.dart` | la **forme de référence** : 16 `Either<Failure,T>`, dont `Stream<Either<Failure, ChatStreamEvent>>` | le `Stream` lui-même ⇒ **CHAT-1** |
| IFFD `chatbot_conversation_screen.dart` (via `/tmp/zcrud-notebook/cycle-vie-message.md`) | **rien à porter** — c'est le **catalogue des régressions à ré-injecter** : `:2134` (confirmé) vs `:3886` (silencieux), `:1979`/`:2000`/`:2026` (3 régénérations divergentes), `:3618-3672` (annuler = supprimer la question), `:1513`/`:4208` (copier mort) | tout |

### Ce qui est ÉCARTÉ, et pourquoi (à ne pas « rattraper » en cours de dev)

- **Historique de versions de contenu** — absent des DEUX dépôts (grep négatif vérifié, D11). L'introduire
  serait une **invention**, pas un portage. `versionKey` (déjà porté en CHAT-0) est un tag de prompt, sans
  rapport.
- **`CancelToken`/`StreamSubscription` réels, `ZChatStreamEvent`** — **CHAT-1**. Ici : l'**adressage** par
  `requestId`, rien de plus.
- **Le controller, l'état de composer, les `ValueListenable`** — **CHAT-2**. Ce contrat ne connaît aucun
  `ChangeNotifier`.
- **Le dialogue de confirmation, ses libellés, son icône, sa couleur** — app-side (AD-2/AD-13/FR-26), rendus
  avec `ZItemAction`/`ZcrudLabels` **existants**.
- **Les familles de `ZFailure` IA** (modération, contexte trop long, réponse vide, modèle indisponible) —
  **CHAT-1**. Une seule failure neuve ici (D9).
- **Le mapping status-code HTTP → `ZFailure`** — **CHAT-1** (c'est l'angle mort résiduel de lex, DELTA §7 ;
  le nommer ici évite de croire qu'il est couvert).
- **Les variantes de transformation** (résumer/expliquer/reformuler) — **CHAT-1** (`ZChatTransformPort`
  paramétré par style). Ce ne sont pas des verbes du cycle de vie d'un message.

### Contraintes d'architecture non négociables (rappel opérationnel)

- **AD-1** : `zcrud_core` = puits du graphe. Aucun `zcrud_*`, aucune dépendance lourde, aucun gestionnaire
  d'état. `pubspec.yaml` **intouché** (`graph_proof` : ACYCLIQUE + **CORE OUT = 0**).
- **AD-2/AD-15** : aucun widget, aucun `BuildContext`, aucun `ChangeNotifier`, aucun gestionnaire d'état
  dans le domaine.
- **AD-4** : extension par **variant ouvert + registre**, jamais par héritage externe d'un type scellé.
  `sealed` reste **interne** au socle (précédent `ZContentBlock`, validé en CHAT-0).
- **AD-5/AD-11** : `Either<ZFailure, T>` partout ; `Unit` pour void — mais **jamais `Unit` là où un compte
  est disponible** (leçon `deleteMessagesAfter`) ; flux `Stream` **nus** (hors périmètre ici).
- **AD-9** : soft-delete `is_deleted` **hors entité** (`ZSyncMeta`) — **zcrud prime sur lex** (D7).
- **AD-10** : rien ne lève ; tout échec est une **valeur**.
- **AD-13/FR-26** : aucun libellé, aucune couleur, aucune icône dans le domaine.
- **AD-16/AD-19** : `updated_at`/`is_deleted` appartiennent à `ZSyncMeta` — le contrat n'en écrit **jamais**.

### Structure de projet

**Production — NEW** (`packages/zcrud_core/lib/src/domain/chat/action/`) :
`z_chat_action.dart` · `z_chat_action_plan.dart` · `z_chat_action_outcome.dart` ·
`z_chat_action_failure.dart` · `z_chat_action_executor.dart` · `z_chat_action_dispatcher.dart`

**Production — UPDATE :** `packages/zcrud_core/lib/domain.dart` (6 exports)

**Tests — NEW :** `packages/zcrud_core/test/domain/chat/action/z_chat_action_test.dart` ·
`z_chat_action_plan_test.dart` · `z_chat_action_dispatcher_test.dart` ·
`z_chat_action_contract_guard_test.dart`

🚫 **Aucun autre fichier.** Ni `pubspec.yaml`, ni `manual_probes.dart`, ni `melos.yaml`, ni
`sprint-status.yaml`, ni `dart_test.yaml`, ni un fichier d'IFFD/lex (lecture seule), ni un `*.g.dart`.

### Pièges déjà payés par ce dépôt — à ne pas repayer

1. **Un test peut certifier une erreur** (VIS-1) : écrire l'assertion à partir de l'**invariant**, jamais à
   partir de ce que le code fait.
2. **Une injection non appliquée ⇒ aucune preuve** (VIS-1 : 10 gardes sur 11 non injectées par l'agent).
3. **Une garde qui « contient » au lieu d'« égaler » ne mord pas** : G-U2 exige l'**égalité d'ensemble** de
   la surface publique — c'est la différence entre une garde et une décoration.
4. **Une garde qui scanne 0 fichier est verte pour rien** : reprendre les `expect(files, isNotEmpty)` du
   patron `z_chat_naming_guard_test.dart`.
5. **`melos analyze` par package ne voit pas une régression cross-package** — la vérif finale est
   **repo-wide** (précédent : `ZExportApi` supprimé en E11a-3, `melos analyze` resté ROUGE plusieurs commits).
6. **`dart test` dans `zcrud_core` donne un faux rouge `dart:ui`** — toujours `flutter test`.
7. **Déclarer plus qu'on ne câble** (CR-IFFD-27, 9 occurrences recensées dans le seul périmètre CHAT) : ce
   contrat n'est utile que s'il est **le seul chemin** — G-U1 est ce qui l'empêche de rejoindre la liste
   des capacités orphelines.

### 🔴 Handoff — à consigner en Completion Notes (obligation `CLAUDE.md § Handoffs`)

Ce contrat **n'est PAS additif pour IFFD**, et il ne l'est pas de la même façon pour tout le monde :

- **IFFD** doit **SUPPRIMER** une de ses deux implémentations par verbe (barre de bulle **ou** en-tête
  compact) et faire construire aux deux surfaces la **même** `ZChatAction`. Les compensations locales
  (dialogue de confirmation ajouté à un seul endroit, garde ad hoc contre la perte de saisie) **doivent
  être RETIRÉES** : additionnées au contrat, elles produiraient une **double confirmation** ou un
  brouillon **doublement restauré**. Widgets concernés au-delà de la cible : les quatre points de
  suppression (`:2134`, `:3886`, `:3647`, popups mindmap/flashcards `:573`/`:859`).
- **lex** est **plus proche** du contrat (1 call-site par verbe déjà) mais **diverge sur la suppression** :
  son hard delete devra devenir un soft-delete (D7). Un hôte **passif** n'a rien à faire ; un hôte qui
  **compensait** doit retirer sa compensation.
- 🟢 **Tripwire recommandé** (pratique de lex, à propager) : garder chez l'hôte un test qui **affirme la
  perte** (« annuler supprime la question », « la surface B supprime sans confirmer »). Il rougira au
  portage et **désignera** le doublon, au lieu de croire ce handoff sur parole.

### Références

- [Source: _bmad-output/implementation-artifacts/sprint-status.yaml:584] — définition de la story, cadence (code-review **unique en fin d'epic**).
- [Source: ~/.claude/plans/tingly-brewing-cake.md:477-487, 488-493, 544-556] — discipline structurelle à poser avant C2/C7, 9 pièges de duplication, défauts IFFD à ne pas reproduire.
- [Source: /tmp/zcrud-lexplus/DELTA-LEX.md:52-78, 127-138] — les 9 corrections de lex, leur cause racine unique, le risque n°1 (« porter la richesse sans porter la discipline »).
- [Source: /tmp/zcrud-lexplus/lex-cycle-vie.md:13-128] — verdict par défaut IFFD, détail des 5 verbes chez lex, hard-delete divergent d'AD-9.
- [Source: /tmp/zcrud-notebook/cycle-vie-message.md:36-160, 215-231] — les 3 régénérations divergentes, les 4 points de suppression, l'annulation destructrice, la table des incohérences UX (catalogue des régressions à ré-injecter).
- [Source: /tmp/zcrud-existant/CARTE-ANTI-DUPLICATION.md:35-46, 59-66, 81-83] — les 9 pièges de duplication, ce que les gates interdisent, le risque n°1.
- [Source: packages/zcrud_core/lib/src/domain/failures/z_failure.dart:22-41, 94-129, 131-187, 194] — hiérarchie extensible, `ZQuotaExceededFailure`, `ZUnsupportedOperationFailure`, `ZResult`.
- [Source: packages/zcrud_core/lib/src/domain/chat/z_content_block.dart:80-86, 211-219] — patron `sealed` interne + variant ouvert.
- [Source: packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart:61-104, 168-169] — couche de rendu des gestes, règle « callback nul ⇒ action absente ».
- [Source: packages/zcrud_core/lib/src/presentation/list/z_batch_action.dart:38-114] — pendant cœur, et pourquoi une convention est « inspirée, jamais importée » (AD-1).
- [Source: packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:153-164] — forme canonique d'un port `abstract interface class` + `Future<ZResult<…>>`.
- [Source: packages/zcrud_core/test/domain/chat/z_chat_naming_guard_test.dart:8-64] — patron d'une garde par scan de source (anti-vacuité incluse).
- [Source: _bmad-output/implementation-artifacts/stories/chat-0-modele-conversation-neutre.md] — story sœur : décisions D1-D9, discipline R3, 25 injections mordantes, baseline 1244 tests.
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md] — AD-1, AD-2, AD-4, AD-5, AD-9, AD-10, AD-11, AD-13, AD-15, AD-16.

## Dev Agent Record

### Agent Model Used

### Debug Log References

#### Vérif verte — RC RÉELLEMENT observés sur disque

| Commande | RC | Détail |
|---|---|---|
| `dart run melos run analyze` (repo-wide) | | |
| `packages/zcrud_core` → `flutter test` | | total attendu **1244 + N** |
| `dart run melos run verify` (repo-wide) | | `graph_proof` (ACYCLIQUE, CORE OUT=0), `gate:reserved-keys`, `verify:serialization` |

#### Injections R3 — chaque garde, appliquée SUR DISQUE, qualifiée

| Garde | Régression réellement appliquée (fichier:ligne) | Rouge observé | Nature (compilation / infrastructure / **assertion**) |
|---|---|---|---|
| G-U1 | | | |
| G-U2 | | | |
| G-U3 | | | |
| G-C1 (a) et (b) | | | |
| G-C2 | | | |
| G-D1 (a) et (b) | | | |
| G-A1 | | | |
| G-A2 | | | |
| G-T1 (source **et** comportement) | | | |
| G-E1 | | | |
| G-E2 (a) et (b) | | | |
| G-E3 | | | |
| G-S1 | | | |
| G-D2 | | | |
| G-P1 | | | |
| G-R1 | | | |
| G-R2 | | | |
| G-N1 | | | |

### Completion Notes List

### File List

### Change Log

| Date | Changement |
|---|---|
| 2026-08-01 | CHAT-0b créée (`bmad-create-story`) : contrat d'action de message — intentions scellées + répartiteur unique, confirmation à jeton infalsifiable, annulation préservant la saisie, `Either` sur chaque verbe, soft-delete. Statut → `ready-for-dev`. |
