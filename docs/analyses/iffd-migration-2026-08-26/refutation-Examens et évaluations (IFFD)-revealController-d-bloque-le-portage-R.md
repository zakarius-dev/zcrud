# Réfutation — `revealController` débloque-t-il le portage `ReviewCardZcrudView` ?

**Domaine** : Examens et évaluations (IFFD) — 3 quartiers : examen-échéance (administration +
`ExamModel` + `ZBackedExamRepository`), **épreuve** (`features/flashcards`, runtime test/examen
blanc), correction (notation IA 1-5). 26 fichiers de production, 9 913 lignes ; 12 fichiers de
tests, 3 364 lignes.
**Besoin de l'hôte** : `revealController` — débloquer le portage `ReviewCardZcrudView`, GELÉ sur un
manque qui n'existe plus depuis v0.32.0 (CR-IFFD-38/39, commit `4231a2398`).
**Affirmation attaquée** : « le socle sait déjà le faire, par `ZFlashcardReviewCard.revealController`
(`ZToggleController?`) ».
**Date** : 2026-08-26. **Méthode** : réfutation — défaut sur le doute.

---

## VERDICT : l'affirmation **TIENT**

Les cinq axes d'attaque ont été joués. Aucun ne la dément. Le canal existe aux lignes citées, son
**corps** fait ce que sa dartdoc promet, il est atteignable depuis IFFD **au ref réellement
épinglé**, et il couvre le besoin réel des **deux** sites de commande.

Trois **conditions de portage** (réelles, non bloquantes) et **une annexe démentie** (le chiffre de
gain) sont consignées plus bas.

---

## 1. Le canal existe-t-il à l'endroit cité, avec cette signature ?

**Oui, aux cinq lignes citées, à l'unité près.**

`packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart` (1 044 lignes) :

| Ligne citée | Contenu mesuré | Statut |
|---|---|---|
| `:110` | `this.revealController,` (paramètre du constructeur `const`) | ✅ exact |
| `:175` | `final ZToggleController? revealController;` | ✅ exact |
| `:313-314` | `_reveal = ZDisplayStateBinding<bool>(consumer: this, initialValue: false)` `..bind(widget.revealController);` | ✅ exact |
| `:358` | `_reveal.bind(widget.revealController);` (dans `didUpdateWidget`) | ✅ exact |

`packages/zcrud_core/lib/src/presentation/state/z_display_state.dart:254` :
`class ZToggleController extends ZDisplayStateController<bool>` — ✅ exact. Il expose `toggle()`
(:264), `set()` (:267), `clear()` (:270).

La dartdoc `:150-158` nomme bien **littéralement** les deux sites IFFD :

> « un bouton « Voir la réponse » à côté de la carte, un bouton « Masquer la réponse » posé par le
> parent sur la face arrière »

Sites totaux de `revealController` dans le fichier : **5**.

---

## 2. Le corps fait-il ce que la dartdoc promet ? (attaque principale)

**Oui.** Ce n'est ni un drapeau inerte ni un jeton sans consommateur. Lecture du corps de
`ZDisplayStateBinding` (`z_display_state.dart:333-407`) :

- **Lecture** — `_source` devient **le contrôleur lui-même** au `bind` (`_source = controller;`
  :390). `T get value => _source.value;` (:364) : aucune copie, aucun miroir. La promesse « la carte
  ne garde aucun miroir » est **tenue par le code**, pas seulement écrite.
- **Écriture** — `set value(T next)` (:367-374) branche : si un contrôleur est lié,
  `controller.value = next; return;` ; sinon `_internal.value = next;`. Le tap sur la carte écrit
  donc **dans le contrôleur de l'hôte**. Canal **bidirectionnel**, vérifié aux deux sens.
- **Notification** — `_relay` est réabonné à chaque `bind` (`_source.addListener(_relay.forward)`,
  :396) et `if (_source.value != previous) _relay.forward();` (:397) rattrape le saut de valeur au
  branchement. `listenable` reste **stable** à travers un rebind (:361) : aucun abonné perdu.
- **Rebind vivant** — `didUpdateWidget` rappelle `bind` (:358) : l'hôte peut changer *ou retirer*
  son pilote. Au débranchement, `_internal` **reprend la dernière valeur rendue** (:393) : pas de
  saut d'affichage.
- **Voie unique** — `_setRevealed` (:398-402) n'écrit qu'à la source ; la notification et l'animation
  sont portées par le **seul** listener `_onRevealChanged` (:319, :412). Une commande venue de l'hôte
  (qui ne passe pas par la carte) est donc animée et notifiée comme un tap.
- **État initial respecté** — `initState` lit `_reveal.value` **après** `bind` et initialise
  `_showBack` / `AnimationController.value` dessus (:324-333). Un contrôleur fourni **déjà à `true`**
  ouvre la carte face réponse : pas de divergence à la première frame.
- **Reset carte suivante** — `_setRevealed(false, deferNotification: true)` quand
  `widget.card != oldWidget.card` (:365) : écrit `false` **dans le contrôleur**, conformément au
  contrat annoncé. `deferNotification` évite le « called during build » chez l'hôte.
- **Non-propriété** — `dispose()` de la liaison ne dispose **jamais** le contrôleur de l'hôte
  (:400-407) ; code et commentaire concordent.

**Aucun écart dartdoc/corps détecté.**

---

## 3. Atteignable depuis l'hôte ?

**Oui, aux quatre conditions vérifiées.**

- **Barrels, sans `show`/`hide`** :
  `packages/zcrud_flashcard/lib/zcrud_flashcard.dart:214` → `export 'src/presentation/z_flashcard_review_card.dart';`
  `packages/zcrud_core/lib/zcrud_core.dart:250` → `export 'src/presentation/state/z_display_state.dart';`
  Ce second export tire **tout** le fichier, donc `ZDisplayStateOwner` (:63),
  `ZDisplayStateOwnerMixin` (:97), `ZDisplayStateController` (:182), `ZToggleController` (:254),
  `ZDisplayStateBinding` (:333).
- **Dépendances déclarées** chez IFFD (`/home/zakarius/DEV/iffd/pubspec.yaml`, lecture seule) :
  `zcrud_core` (:305), `zcrud_flashcard` (:328), plus overrides (:572, :638).
- **Ref réellement épinglé** : `ref: v3.21.0` sur **48** entrées zcrud (`ref: master` ×1 et
  `ref: v6.1.0` ×1 concernent des paquets **non-zcrud**). Le canal a donc été vérifié **au tag**, pas
  seulement sur l'arbre de travail :
  - `git show v3.21.0:…/z_flashcard_review_card.dart | grep -c 'revealController'` → **5**
  - `git show v3.21.0:…/z_display_state.dart | grep -c 'class ZToggleController'` → **1**
- **Généalogie confirmée** : `4231a2398eeb161a986886faa34c88a43e2044c7`, 2026-08-02 —
  *« feat(core,chat,flashcard): CR-IFFD-38 & 39 — commande externe d'etat + liste de conversations
  (v0.32.0) »*. v3.21.0 ≫ v0.32.0 : le manque invoqué par le gel a disparu **avant** le ref épinglé.

---

## 4. Couvre-t-il le besoin RÉEL de l'hôte ? — l'objection du tripwire

### L'objection écrite

`/home/zakarius/DEV/iffd/test/w8m/review_card_reveal_command_test.dart:79` :

> « Un `revealController` interne à la carte ne l'aurait pas servi. »

### Le besoin réel, mesuré chez l'hôte

Le tripwire mesure lui-même **2** sites de commande (`expect(commandes.length, 2)`), en excluant le
portage qui cite `toggleCard` dans sa propre documentation :

1. `interactive_flashcard_repetition_card.dart` (**1 205** lignes) — bouton « Voir la réponse » →
   `flipCardController?.toggleCard`, **à côté** de la carte ;
2. `flashcard_repetition_widgets.dart` (**717** lignes) — bouton « Masquer la réponse » posé par
   **le parent**, en `Positioned(bottom: 16.0, right: 16.0)` dans le `Stack` de la **face arrière**
   (lignes 293-302), gardé par `if (flipCardController != null)`.

### Pourquoi l'objection ne porte pas

Elle vise un contrôleur **interne à la carte**. Le canal du socle est l'exact contraire :

- `ZToggleController({required super.owner, …})` — le paramètre `owner` est **obligatoire**, de type
  `ZDisplayStateOwner`. Le contrôleur est donc **structurellement possédé par l'hôte**, jamais par la
  carte.
- La carte ne fait que s'y **brancher** (`consumer: this`) ; `dispose()` de la liaison ne le détruit
  pas.
- Le contrôleur étant possédé **au-dessus** de la carte, les deux sites — celui d'à côté et celui du
  parent — lisent et écrivent **la même** instance. C'est exactement le cas d'usage nommé dans la
  dartdoc `:150-158`.

L'objection était **juste à la date où elle a été écrite** et **caduque au ref épinglé aujourd'hui** :
elle décrit une conception que le socle n'a pas retenue.

### GREP NÉGATIF chez IFFD (confirmé)

```
cd /home/zakarius/DEV/iffd
grep -rn 'revealController\|ZToggleController' lib                            → RC=1  (0 occurrence)
grep -rn "ReviewCardZcrudView" lib | grep -v "zcrud/review_card_zcrud.dart"   → RC=1  (0 occurrence)
```

Le second grep prouve le **gel** : `ReviewCardZcrudView`
(`lib/src/presentation/features/flashcards/zcrud/review_card_zcrud.dart`, **180 lignes**) n'est
référencé **nulle part** dans `lib` hors de son propre fichier. Il n'existe qu'en test
(`test/w8e/review_card_zcrud_test.dart`). Portage écrit, non raccordé — conforme à l'affirmation.

---

## 5. Conditions cachées (réelles, non bloquantes)

Aucune ne dément l'affirmation ; toutes doivent figurer dans le brief de portage.

**C1 — La possession hors `build` est IMPOSÉE, pas conseillée.**
`ZDisplayStateOwnerMixin` (`z_display_state.dart:97-176`) pose une **borne temporelle** :
`addPostFrameCallback((_) => _zInstalled = true)` en `initState`. Tout enregistrement postérieur lève
une `FlutterError` nommant le contrôleur. Le parent `flashcard_repetition_widgets.dart` devra donc
porter le mixin et créer le `ZToggleController` **en champ ou en `initState`** — jamais dans `build`.
Dérogation possible mais explicite (`zAllowsLateDisplayState`, défaut `false`).

**C2 — Un contrôleur jamais consommé fait échouer un `assert` au `dispose`.**
`dispose()` du mixin (:166-175) asserte `controller.wasEverConsumed`. Créer le contrôleur sans le
passer à la carte casse en debug. Garde utile — elle interdit exactement le « bouton mort » — mais
elle mord si le portage est câblé à moitié.

**C3 — Pas de slot de sur-impression de face arrière dans la carte du socle.**
GREP NÉGATIF montré :
```
cd /home/zakarius/DEV/zcrud
grep -n 'Stack\|Positioned' packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart   → RC=1
grep -n 'backOverlay\|backBuilder\|overlay' …/z_flashcard_review_card.dart                               → (vide)
```
Et `ZFlashcardContentBuilder` (`z_flashcard_content_slot.dart:41-44`) est
`Widget Function(BuildContext, String)` : **aucun paramètre de face**, donc il ne permet pas de
distinguer recto/verso pour y loger le bouton.

⇒ Le bouton « Masquer la réponse » **ne peut pas être injecté dans** la face arrière de la carte. Il
doit être **re-logé par l'hôte** dans son propre `Stack` autour de `ZFlashcardReviewCard`, sa
visibilité étant pilotée par la valeur du contrôleur (que l'hôte possède et peut écouter).

**C3 est un déplacement de mise en page, pas une perte de fonction** : la *commande* — l'objet de
l'affirmation — est intégralement servie. Consignée parce qu'un brief qui l'omettrait ferait
découvrir la contrainte en cours de portage.

---

## 6. Annexe DÉMENTIE — le gain de « ~180 lignes d'hôte supprimées »

Ce chiffre **ne résiste pas** ; il n'engage pas le cœur de l'affirmation.

**180 est la taille du portage lui-même** (`review_card_zcrud.dart` = 180 lignes) — or ce fichier
serait **activé et conservé**, pas supprimé. Le chiffre confond la taille du remplaçant avec le
volume du remplacé.

Volumes réels côté legacy :

| Fichier | Lignes |
|---|---|
| `interactive_flashcard_repetition_card.dart` | 1 205 |
| `flashcard_repetition_widgets.dart` | 717 |
| **Total legacy des deux porteurs de commande** | **1 922** |

Je **ne substitue aucun chiffre de gain** : ces deux fichiers portent bien plus que la révélation
(rendu, audio, navigation, notation), et je n'ai pas mesuré la part imputable. Affirmer « X lignes
gagnées » sans cette mesure reproduirait le défaut que je viens de relever. **Le gain réel est non
établi par cette analyse** ; il est à mesurer avant d'être annoncé.

---

## Synthèse

| Axe d'attaque | Résultat |
|---|---|
| 1. Canal existe aux lignes citées | ✅ 5/5 exact |
| 2. Le corps tient la promesse de la dartdoc | ✅ bidirectionnel, source unique, non inerte |
| 3. Atteignable (barrel + dep + **ref v3.21.0**) | ✅ vérifié au tag, pas seulement en local |
| 4. Couvre le besoin réel des 2 sites | ✅ objection du tripwire caduque (contrôleur **externe**) |
| 5. Conditions cachées | ⚠️ C1 mixin, C2 assert, C3 pas de slot face arrière — aucune bloquante |
| 6. Gain « ~180 lignes » | ❌ **démenti** (180 = taille du portage conservé ; legacy = 1 922) |

**L'affirmation principale tient. Le chiffre de gain qui l'accompagne est retiré.**
