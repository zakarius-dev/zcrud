# Handoff **v0.30.0** — epic CHAT : le socle de conversation IA

> **Tag à épingler : `v0.30.0`**
> **5 paquets nouveaux.** Lisez le § 1 avant tout : cette livraison n'est **pas** de même nature
> que les précédentes.

---

## 1. 🔴 Ce que vous recevez — et ce que vous ne recevez pas

**Ce socle est une spécification exécutable, pas une fonctionnalité clé en main.**

Nous l'écrivons en premier parce que notre propre revue de fin d'epic l'a établi, et parce que
l'inverse serait la quatrième occurrence d'une erreur que nous avons déjà commise trois fois :
affirmer une propriété sur *votre* code en n'ayant vérifié qu'une propriété sur *le nôtre*.

| Vous recevez | Vous ne recevez PAS |
|---|---|
| le modèle de conversation, les ports, le contrat d'action, le contrôleur, le rendu neutre | **un assistant qui fonctionne sans que vous écriviez d'adaptateur** |
| la couture Syncfusion et la normalisation du flux textuel d'IFFD | un transport (aucun client HTTP/SSE n'est fourni) |
| les contrats de pièces jointes et d'export | un sélecteur de fichier, un composeur PDF, une sortie de partage |

**Mesuré : 8 ports sur 10 n'ont aucun implémenteur dans le dépôt**, `example/` compris.
Sans adaptateur de votre côté, `runAction` rend un `Left` sur tous les verbes, et le PDF, le partage
et la sélection de fichier ne fonctionnent chez **aucun** hôte.

Ce n'est pas un défaut de livraison : c'est AD-57 (le tiers vit chez vous). Mais cela doit être dit
avant que vous ne planifiiez votre sprint d'adoption.

---

## 2. 🔴 Le portage n'est PAS additif pour IFFD

Deux migrations vous attendent, et elles ne sont pas triviales :

1. **Couplage par callbacks → ports.** Votre chat pilote ses actions par des callbacks passés au
   widget ; le socle impose un **contrat d'action unique** (`ZChatActionDispatcher`).
2. **Champs plats → blocs typés**, donc **migration Firestore** de vos messages existants.

Nous ne pouvons pas la faire pour vous, et nous ne prétendons pas qu'elle est indolore.

---

## 3. Votre ligne — hôte passif ou hôte ayant contourné

⚠️ **« Rien à faire » ne veut jamais dire la même chose pour les deux.** Une correction qui transforme
un défaut *contourné* en comportement natif fait **s'additionner** votre compensation au correctif.
Mesuré en v0.22.0 : une marge restituée par un `Padding` externe a donné **24 dp au lieu de 12** une
fois le socle corrigé.

### 3.1 Hôte **passif** (vous n'aviez rien contourné)

Un seul geste : ajouter les paquets neufs à votre `dependency_overrides` racine —
`zcrud_chat_kernel`, `zcrud_chat`, `zcrud_menu`, et selon vos besoins `zcrud_chat_syncfusion`.
⚠️ **`zcrud_study` tire désormais `zcrud_menu`** : même si vous n'utilisez pas le chat, l'ajout est
requis. C'est la récidive exacte du « Piège 1 » de `docs/private-git-consumption.md` (v0.16.0).

### 3.2 Hôte **ayant contourné** — ce que vous devez RETIRER, nommément

**IFFD** — `lib/src/presentation/features/folders/zcrud/folder_actions_menu_zcrud.dart` :
* **RETIRER `class IffdMenuAction`** et `iffdMenuActions()` (`permitted ? onSelected : null`).
  Vous aviez dû écrire cette classe parce que le socle **confondait le droit et l'effet** ;
  `ZItemAction(permitted: …)` le porte désormais nativement. Les garder n'est pas cassant, mais
  c'est une couche de traduction morte.
* **RETIRER** dans votre grille les `InkWell` sans plancher de taille **et** le `Semantics(label:)`
  qui **n'exclut pas** son sous-arbre — aujourd'hui, chez vous, **le libellé est annoncé deux fois**.
  Remplacez par `ZMenuEntryTile`.
  🔴 **Si vous gardez vos `InkWell` ET posez `ZMenuEntryTile`, vous aurez DEUX détecteurs de geste**,
  donc une **double invocation** de l'action.
* Vos **12 autres sites de menu** (étude, `data_crud`, workflow/agenda, IA) peuvent viser
  `ZActionMenu` directement.

**lex_douane** — `packages/lex_ui/lib/presentation/widgets/study/study_item_actions_menu.dart` :
* **RETIRER les 297 lignes** du `PopupMenuButton<StudyItemAction>`, la classe `_DeferredEntry`, et
  les `enabled: canMoveUp` / `canMoveDown` / `available`. Tout cela est natif :
  `ZItemAction(disabledReason: …)` rend l'entrée **présente, inerte et motivée**, le motif étant
  annoncé dans un slot dédié — jamais concaténé au libellé.

---

## 4. Ruptures déclarées

| Rupture | Qui est touché | Geste |
|---|---|---|
| `PopupMenuItem<ZItemAction>` → `PopupMenuItem<ZMenuEntry>` | un hôte qui asserte **ce type dans ses tests** | ajuster l'assertion ; pouvoir discriminant inchangé, **aucun impact production** |
| `ZSfAssistConversationView`, `ZSfAssistRenderer`, les clés `zchat.sf.*` **disparaissent** | consommateur de `zcrud_chat_syncfusion` | passer à `ZChatConversationView` + `ZChatShellRendererScope(ZSfAssistShellRenderer())`, retirer vos deux libellés jumeaux |
| un menu sans aucune action visible et sans slot de contenu rend un déclencheur **inerte** | aucun appelant connu | — |
| une action de menu est résolue par **identité**, plus par rang | hôte dont la liste se réordonne | c'est un **correctif** : vous obteniez auparavant une action arbitraire ou un `RangeError` |

**Changement de comportement à connaître** : c'est le callback capturé **à l'ouverture** du menu qui
s'exécute, pas une relecture fraîche au moment du tap. C'est le seul comportement qui honore ce que
l'utilisateur a **vu**.

---

## 5. Ce que la revue a corrigé, et qui vous concerne directement

* **Les 12 clés de libellé du chat portent désormais un repli lisible.** Avant correction, un hôte non
  configuré affichait `zchat.showMore` à l'écran et **annonçait `zchat.liveRegion`** à son lecteur
  d'écran. Deux de nos gardes défendaient ce comportement : elles ont été **renversées**.
* **Le résumé accessible est réellement annoncé.** Il partait dans un champ de Syncfusion que le
  paquet tiers **n'exploite pas** sur notre chemin de rendu. Il est désormais posé par un `Semantics`
  que **nous** contrôlons, commun aux deux branches.
* **La région live annonce les réponses faites uniquement de blocs** (tableau, sources) — elle était
  muette sur ce cas.
* **Le plancher de 48 dp est structurellement tenu.** Il était un `ConstrainedBox` **écrasé sous
  contrainte serrée** : mesuré à **28,6 dp** dans une grille `childAspectRatio`. Le plancher passe de
  la cellule à la **disposition** (`ZMenuEntryTile.gridDelegate`) — un enfant ne peut pas être plus
  grand que la place imposée, c'est le protocole de Flutter.
  ⚠️ **Si vous composez `ZMenuEntryTile` dans votre propre grille serrée**, une erreur de disposition
  en debug nommera le remède. Vérifié : aucune occurrence chez vous aujourd'hui.

---

## 6. 🟢 Tripwires recommandés

Votre règle « ne jamais retirer un contournement sur la foi d'un handoff » vous a déjà évité trois
régressions. Gardez-la, et instrumentez-la :

* **IFFD** : un test affirmant que le libellé de votre grille est annoncé **deux fois**.
* **lex** : un test affirmant qu'une entrée `disabledReason` est **absente**.
* **Les deux** : un test affirmant qu'un menu résolu positionnellement exécute la **mauvaise** action
  après réordonnancement.

Ils rougiront à l'adoption de `v0.30.0` et **désigneront** le contournement à retirer — au lieu de
nous croire sur parole.

---

## 7. Vérification

`melos analyze` **RC=0, 0 erreur** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, **35 paquets**,
tous gates) · `zcrud_core` **1114** · `zcrud_study` **797** · `zcrud_chat_kernel` **283**
(`-p node` 236) · `zcrud_ui_kit` **176** · `zcrud_chat` **169** · `zcrud_menu` **72** ·
`zcrud_chat_syncfusion` **57**.

Revue de fin d'epic à **4 lentilles** (conformité AD, tests porteurs, a11y/l10n, adversariale).
Tous les findings HIGH et MAJEUR sont corrigés, chaque correction portant une garde **prouvée
mordante** par injection de sa régression exacte.

⚠️ **La CI GitHub de zcrud est à l'arrêt** (compte verrouillé pour facturation, **75 runs sur 75**
sans démarrage). Les chiffres ci-dessus sont des vérifications **locales rejouées à la main**.
Nous vous le signalons parce que cela change la confiance à accorder à ce handoff : notre filet
habituel n'a pas joué.

---

## 8. Ce que nous savons ne pas avoir couvert

* Aucun rendu riche **réel** : markdown, LaTeX et diagrammes sont **atteignables** par la couture,
  pas rendus. Un diagramme affiche son code source.
* La **reprise de flux** est modélisée, mais l'adaptateur IFFD ne fabrique **délibérément aucun
  numéro de séquence** — son serveur n'a aucun point de reprise. Une reconnexion **rejouerait le
  tour**, quota consommé deux fois. N'annoncez pas la reprise à vos utilisateurs sous ce backend.
* Le dépôt porte encore un `PopupMenuButton` en dur dans `ZBatchActionBar` (impossible à migrer tant
  que la couture n'est pas dans le cœur — `CORE OUT = 0`).
* Aucun hôte n'a été migré : le § 3 décrit ce que vous devez retirer, il **ne prouve pas** que votre
  build passe après retrait. C'est l'objet des tripwires du § 6.
