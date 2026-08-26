# Réfutation — M8 « Le carrousel de session » (IFFD, Révision/flashcards)

**Affirmation attaquée** : « le socle sait déjà le faire, par `ZSessionCardSwiper`
(+ `ZSessionProgressIndicator`, `ZIndexController`) ». Gain annoncé : **~260 lignes d'hôte
supprimées**.

**Verdict : RÉFUTÉE.** Le canal existe, il est réel, exporté et atteignable — mais il **interdit
structurellement** le comportement central du carrousel IFFD (le swipe **note**), et il n'expose
aucun des réglages que l'hôte utilise. Ce n'est pas un remplacement : c'est un **changement de
produit** plus une réécriture de l'hôte, pour un gain net très inférieur à 260 lignes.

Tout est mesuré sur disque le 2026-08-26. Dépôts hôtes lus en **lecture seule**. Aucun test lancé.

---

## 1. Ce qui RÉSISTE dans la preuve avancée

Ces points de l'affirmation sont vrais, vérifiés :

| Affirmation | Mesure |
|---|---|
| Le type existe | `packages/zcrud_session/lib/src/presentation/z_session_card_swiper.dart`, **648 lignes** ; `class ZSessionCardSwiper extends StatefulWidget` à la **ligne 134** ; constructeur à la **ligne 153**, **10 paramètres** (`queue`, `cardBuilder`, `passThreshold`, `onIndexChanged`, `onStackEnd`, `emptyBuilder`, `progressStyle`, `qualityOf`, `swipeDuration`, `indexController`) |
| `indexController` réel, pas un passe-plat | `:213` déclaration ; `_onCurrentChanged` `:404-422` appelle **réellement** `_controller.moveTo(clamped)` `:417` quand l'origine est l'hôte. Vérifié côté paquet tiers : `flutter_card_swiper-7.2.0/lib/src/widget/card_swiper_state.dart:329 _moveTo(int index)` accepte **un index inférieur** (`if (index < 0 \|\| index >= widget.cardsCount) return;` — pas de contrainte de sens) ⇒ le recul programmatique fonctionne |
| Bouton a11y = même voie que le geste | `_advance()` **`:483`** = `_controller.swipe(CardSwiperDirection.right)`, et non `moveTo` — donc `onSwipe` → `_handleSwipe` `:455` → `_emitIndexChanged` → `onIndexChanged`. (La citation « :142-146 » vise en réalité une puce de dartdoc du constructeur, pas le mécanisme ; le mécanisme est à `:470-483`.) |
| `zReduceMotionOf` importé et **consommé** | import `:120` ; usage réel `:500` `final reduceMotion = zReduceMotionOf(context);` → `duration: reduceMotion ? Duration.zero : widget.swipeDuration` `:527` |
| Exporté par le barrel | `packages/zcrud_session/lib/zcrud_session.dart:85` `export 'src/presentation/z_session_card_swiper.dart';` (+ `:101` pour l'indicateur, `:32` pour `ZSessionItem`) |
| `ZIndexController` existe | `packages/zcrud_core/lib/src/presentation/state/z_display_state.dart:276` |
| IFFD dépend déjà de `zcrud_session` | `iffd/pubspec.yaml:412`, dans la section **`dependencies:`** (bornes mesurées : `dependencies:` ligne 10, `dev_dependencies:` ligne 533) ; déjà importé à **3 fichiers** (`review_session_zcrud.dart:36`, `interactive_flashcard_repetition_card.dart:21`, `srs_quality_zcrud.dart:30`) |
| Pas de conflit de version tierce | `zcrud_session/pubspec.yaml:98` `^7.2.0` ; `iffd/pubspec.yaml:177` `^7.0.2` ; **`iffd/pubspec.lock:913` → `version: "7.2.0"`**. L'intersection est déjà résolue, réellement, dans le lock de l'hôte |
| Sites hôtes cités | `folder_flashcards_repetitions_page.dart:198` `CardSwiperController()`, `:503` `CardSwiper(`, `:743` `CardSwiperButtons(`, `:922` `class CardSwiperButtons` — les quatre existent |

Un point réel **en faveur** de la migration, non revendiqué par l'affirmation : l'hôte construit son
`CardSwiperController()` **dans `build`** (`:198`, à l'intérieur du `builder:` du `StreamBuilder`),
donc une instance neuve à chaque frame — et il compense en injectant `swiperController.hashCode` dans
la `key` du `CardSwiper` (`:506`). Le socle, lui, possède son contrôleur (`late final` en champ,
`dispose()` `:390`). C'est un vrai défaut de l'hôte que le socle ferme.

---

## 2. Ce qui la DÉMENT

### 2.1 (décisif) Le swipe d'IFFD **NOTE** ; le socle l'interdit par construction

Hôte, `folder_flashcards_repetitions_page.dart:614-729` (`onSwipe`, 116 lignes) :

```dart
final isCorrect = direction == CardSwiperDirection.right;   // :626
...
final quality = isCorrect ? 5 : 1;                          // :651
final (_, updatedRepetition) = repetition.updateWithQuality(quality);
ref.read(flashcardRepetitionRepositoryProvider).update(updatedRepetition);  // :654
```

Le geste horizontal écrit une note SRS (5 ou 1) au dépôt de répétitions. C'est **exactement** ce que
`ZSessionCardSwiper` existe pour rendre impossible :

- `_handleSwipe(int previousIndex, int? currentIndex, Object? direction)` `:455` — le paramètre
  `direction` est **typé `Object?` et jamais lu** ;
- la seule sortie est `onIndexChanged` : `final ValueChanged<int>? onIndexChanged;` `:184` — **un
  entier, aucune direction, aucun `previousIndex`** ;
- **grep négatif montré** sur la surface publique du fichier :

  ```
  $ grep -n "quality|Quality|reviewer|Reviewer|grade|Grade" z_session_card_swiper.dart
  5,7,66,69   → dartdoc (« Ce type n'a aucun paramètre de qualité… »)
  147,161,189,582 → `qualityOf` : seam de LECTURE pour colorer l'indicateur
  313  → commentaire mentionnant ZStudySessionEngine.reduceGrade
  ```
  Aucun paramètre de notation, aucun reviewer. Le seul `quality*` est `ZSessionQualityAtIndex?
  qualityOf` — « quelle note **a déjà été** obtenue à l'index i », en entrée, pour l'indicateur.

- ce n'est pas qu'une dartdoc : une **garde** l'asserte, sur deux axes, avec témoin positif
  anti-tautologie — `packages/zcrud_session/test/presentation/z_swipe_never_grades_test.dart`
  (« 🎯 AC1 + AC2 (SU-4) — le swipe NAVIGUE ; il ne note JAMAIS », axe COMPORTEMENT + axe SOURCE).

Conséquence : **la direction du swipe n'est observable par aucun canal public**. Un hôte migré ne
peut pas reconstituer `isCorrect`. Le carrousel IFFD ne peut donc pas être porté « tel quel » : il
faudrait décider que **le swipe cesse de noter** chez IFFD et que la note ne vienne plus que des
boutons. C'est une décision produit, pas une migration.

Aggravant : la **dernière carte**. Chez l'hôte, le dernier swipe note (via `previousIndex`). Chez le
socle, `_handleSwipe` `:456` fait `if (currentIndex == null) return true;` — **aucune émission** ;
seul `onStackEnd` part, sans index. La dernière note serait perdue même si l'on trouvait un moyen de
noter sur `onIndexChanged`.

### 2.2 (décisif) Le socle remet l'index à **0** à chaque mutation de file ; IFFD mute la file à presque chaque note

Socle, `didUpdateWidget` `:365-388` :

```dart
if (!listEquals(oldWidget.queue, widget.queue)) {
  _cardCache.clear(); _lastEmittedIndex = null; _stackEnded = false;
  _swiperIndex = 0;                    // :371
  _resettingQueue = true; _current.value = 0; _resettingQueue = false;  // :378
  _queueGeneration++;                  // :383  → remonte tout le CardSwiper (key)
}
```

Le modèle assumé est une file **consommée par le haut** (la carte courante est toujours l'index 0 —
c'est le contrat de `ZStudySessionEngine.reduceGrade`, cité `:313`). IFFD ne fonctionne pas ainsi :
c'est un **curseur qui se déplace dans une liste mutée en place** —

- succès en cycle d'apprentissage : `controller.removeFlashcard(flashcard)` `:672`, puis
  `setCurrentFlashcardIndex(adjustedIndex)` où `adjustedIndex = previousIndex` (`:674-686`) ;
- échec : `putFlashcardAfterXNext(flashcard: …, after: 3, previousIndex: newIndex)` `:691-695` —
  la carte est **retirée puis réinsérée 3 rangs plus loin**, index conservé ;
- mode `test` : retrait systématique `:700`, index conservé.

Chacun de ces cas change `actualizedFlashcardsList` ⇒ chez le socle, `listEquals` faux ⇒ **retour
forcé à la carte 0**. Une session IFFD arrivée à la carte 12 repartirait à la carte 1 à chaque note.
Il n'existe **aucun paramètre pour désarmer ce reset** — grep négatif : voir §2.4.

### 2.3 Le `cardBuilder` du socle ne donne ni le modèle, ni les offsets de drag, ni de poignée de swipe

- Signature socle : `typedef ZSessionCardBuilder = Widget Function(BuildContext, ZSessionItem)`
  `:128-131`. `ZSessionItem` (`zcrud_session/lib/src/domain/z_session_item.dart:17-33`) ne porte que
  `{flashcardId, folderId, typeKey?}`. L'hôte a besoin du `FlashcardModel` complet
  (`FlashcardRepetitionCard(folder:, flashcard:, userId:, readOnly:, tags:, tagsStream:,
  permissions:, …)` `:552-568`) ⇒ table de correspondance à écrire chez l'hôte.
- Signature paquet tiers utilisée par l'hôte : `cardBuilder: (context, index, percentThresholdX,
  percentThresholdY)` `:527-530`. Les deux offsets **ne sont pas relayés** : le socle les consomme
  lui-même pour son `ZSwipeEmotionIndicator` (`:545-548`). L'hôte perd donc ses **87 lignes** de
  `cardBuilder` (`:527-613`), dont les overlays maison :
  - `Icons.sentiment_very_satisfied_outlined` / `sentiment_dissatisfied_outlined` en
    `Colors.green` / `Colors.red` (`:569-589`),
  - une seconde paire verticale bleu/jaune (`:590-610`).

  Ce que le socle rend à la place est **délibérément neutre** :
  `z_session_progress_indicator.dart:485-490` → `Icons.arrow_forward` / `Icons.arrow_back`, couleurs
  `'secondary'` / `'tertiary'`, avec un commentaire explicite « Glyphe neutre et directionnel —
  jamais un visage. Un visage souriant ou mécontent serait une évaluation ». **Régression visuelle
  assumée par le socle**, pas un détail d'implémentation.
- `onAutoNext` (`:563-568`) appelle `swiperController.swipe(right)` **depuis l'intérieur de la
  carte**. Le socle n'expose aucune poignée de swipe : `_advance()` `:483` est **privé**. Le
  contournement est `indexController.value = i + 1`, qui passe par `moveTo` — donc sans animation
  (`_moveTo` = un simple `setState`, `card_swiper_state.dart:333-335`) et sans passer par `onSwipe`.
  Comportement différent, pas équivalent.

### 2.4 Réglages du carrousel non exposés — grep négatif montré

```
$ cd packages/zcrud_session/lib/src/presentation
$ grep -n "backCardOffset"                       z_session_card_swiper.dart   → (0 hit)
$ grep -n "this.padding|final EdgeInsets"        z_session_card_swiper.dart   → (0 hit)
$ grep -n "this.numberOfCardsDisplayed|final int numberOfCards" z_session_card_swiper.dart → (0 hit)
$ grep -n "showNav|hideNav|this.showProgress|navigationRow:"    z_session_card_swiper.dart → (0 hit)
```

| Réglage | Hôte | Socle |
|---|---|---|
| `backCardOffset` | `const Offset(0, 35)` `:504` | **absent** (défaut du paquet) |
| `padding` | `EdgeInsets.zero` `:505` | **codé en dur** `EdgeInsets.all(theme.gapM)` `:537` |
| `numberOfCardsDisplayed` | `math.min(3, n)` `:525` | **codé en dur** `math.min(2, n)` `:522` |
| indicateur + bouton « suivant » | rendus **au-dessus**, dans un conteneur décoré, **conditionnels** (`!= listOnly && !readOnly && segmentsColors.isNotEmpty`, `:358-360`) | `_navigationRow` **toujours** rendu, **sous** la pile, dans la même `Column` `:552-554` — **non désactivable** |
| indicateur | `DotsIndicator` (dots_indicator ^4.0.1, `pubspec.yaml:191`) **ou** `SegmentedProgressBar` (`^1.2.0`, `:192`) selon le mode `:430-484` | `ZSessionProgressIndicator`, styles `dots` / `segmentedBar` / `linear` (`z_session_progress_indicator.dart:46-69`) |

En mode `listOnly` / `readOnly`, IFFD n'affiche **ni** progression **ni** chevron ; le socle en
imposerait deux.

### 2.5 L'arithmétique des « ~260 lignes » ne tient pas

Bloc `CardSwiper(` mesuré : **lignes 503 → 731 = 229 lignes**, plus `:198` (contrôleur) et `:9`
(import) = **231**. Décomposition :

| Portion | Lignes | Devenir en cas de migration |
|---|---|---|
| `onSwipe` (`:614-729`) | **116** | **ne disparaît pas** — logique métier (notation, retrait, réinsertion). Aucun canal socle ne l'accueille (§2.1, §2.2) : elle doit être **re-hébergée**, et sa moitié « notation par direction » **n'a aucune destination** |
| `cardBuilder` (`:527-613`) | **87** | l'appel à `FlashcardRepetitionCard` reste (adapté `ZSessionItem` → `FlashcardModel`) ; ~50 lignes d'overlays disparaissent **au prix d'un rendu différent** (§2.3) |
| configuration pure (`key`, `padding`, `controller`, `initialIndex`, `cardsCount`, `allowedSwipeDirection`, `numberOfCardsDisplayed`, `backCardOffset`) | **26** | seule portion réellement **supprimable** — et 3 de ces 8 réglages sont perdus (§2.4) |

Le gain net honnête est de l'ordre de **quelques dizaines de lignes**, pas 260 — et il s'achète par
une réécriture de la boucle de session de l'hôte.

Les 260 lignes annoncées semblent inclure `class CardSwiperButtons` (`:922-1202`, **281 lignes**).
Or ce widget est la **rangée de notation**, qui relève d'un **autre canal** (`ZSrsQualityButtons`,
barrel `:113`) — et l'hôte l'importe **déjà** (`srs_quality_zcrud.dart:30`). Le compter en M8 est un
double comptage.

### 2.6 La dépendance tierce ne quitterait pas l'hôte

`flutter_card_swiper` est importé dans **2 fichiers** de `iffd/lib` — la page **et**
`controllers/flashcards_learing_controller.dart` (`:2` import, `:172` `CardSwiperController?
swipeController`, `:174` `void Function(CardSwiperDirection, VoidCallback)? swipe`, `:195`
`CardSwiperDirection.left/right`). Migrer la seule page laisse le type tiers **dans la signature
publique du contrôleur** : `iffd/pubspec.yaml:177` reste nécessaire.

### 2.7 Le recul de l'hôte a une sémantique que le socle ne reproduit pas

`onPrevious` (`:794-805`) → `controller.toNextFlashcard(quality: -1, …)`
(`flashcards_learing_controller.dart:170-197`) :

```dart
if (quality == -1) {
  if (currentFlashcardIndex == 0) currentFlashcardIndex = totalFlashcards - 1;  // BOUCLE
  else currentFlashcardIndex--;
}
```

Recul **circulaire**, borné sur `totalFlashcards` (le total **initial**), puis `swiperController.moveTo(index)`.
Le socle **clampe** (`_clampIndex` `:355-359`) et **réécrit la valeur clampée dans le contrôleur de
l'hôte** (`_onCurrentChanged:409-414`). Comme `totalFlashcards` ≥ `actualizedFlashcardsList.length`
dès le premier retrait, une commande « reculer depuis 0 » serait silencieusement ramenée à la
dernière carte **de la file courante**, et la valeur de l'hôte réécrite sous lui. Le comportement
change ; la boucle disparaît.

---

## 3. Conclusion

Le canal est réel, exporté, atteignable, sans conflit de version, et il ferme même un vrai défaut de
l'hôte (contrôleur créé dans `build`). Mais **il n'implémente pas le besoin de M8** : il implémente
délibérément le besoin **inverse** sur le point central (« le swipe navigue, il ne note jamais »,
gardé par test), il réinitialise l'index sur chaque mutation de file — que la session IFFD provoque à
presque chaque note —, il ne relaie ni le modèle ni les offsets de drag au `cardBuilder`, il n'expose
aucune poignée de swipe pour `onAutoNext`, et il n'expose ni `backCardOffset`, ni `padding`, ni
`numberOfCardsDisplayed`, ni le moyen de masquer sa propre rangée de navigation.

**M8 n'est pas une migration : c'est un changement de modèle de session.** Il peut se décider — il ne
peut pas se présenter comme « le socle sait déjà le faire ».

### Ce qui serait vrai à la place

> Le socle offre une pile de session **de navigation pure** (`ZSessionCardSwiper`, réelle, exportée,
> `zcrud_session` déjà déclaré chez IFFD à `pubspec.yaml:412` et `flutter_card_swiper` déjà résolu en
> 7.2.0 dans `iffd/pubspec.lock:913`). L'adopter suppose **trois décisions produit** chez IFFD :
> (1) le swipe cesse de noter — la note ne vient plus que des boutons de qualité ; (2) la file
> devient **consommée par le haut** (carte courante = index 0), sinon le reset à 0 du socle casse la
> session ; (3) les overlays « visage content / mécontent » cèdent la place aux flèches neutres du
> socle. Ces décisions prises, le gain réel est de l'ordre de **quelques dizaines de lignes** de
> configuration, pas 260 ; les 116 lignes d'`onSwipe` (notation + retrait + réinsertion) devront être
> re-hébergées côté hôte, et la dépendance tierce restera nécessaire tant que
> `flashcards_learing_controller.dart` exposera `CardSwiperController` / `CardSwiperDirection` dans
> sa signature. Prérequis socle pour une migration **non destructive** : relayer la direction (ou
> `previousIndex`) en sortie, permettre de désarmer le reset d'index sur changement de file, exposer
> les offsets de drag au `cardBuilder`, et rendre la rangée de navigation optionnelle.

---

### Méthode et limites

- Fichiers lus : socle `z_session_card_swiper.dart` (648 l., intégral), `z_session_progress_indicator.dart`
  (502 l., partiel), `z_session_item.dart`, `zcrud_session.dart` (barrel), `z_display_state.dart`
  (partiel), `z_swipe_never_grades_test.dart` (partiel) ; hôte
  `folder_flashcards_repetitions_page.dart` (1202 l., intégral sur 1-960 + repères au-delà),
  `flashcards_learing_controller.dart` (partiel), `pubspec.yaml`, `pubspec.lock` ; paquet tiers
  `flutter_card_swiper-7.2.0/lib/src/widget/card_swiper_state.dart` (partiel).
- **Aucun test lancé**, dans aucun dépôt. Aucune écriture hors de ce répertoire. Aucune clé ni secret
  cité.
- Non vérifié, et donc non affirmé : le comportement de `ZSessionProgressIndicator` style
  `segmentedBar` à l'écran (lu en dartdoc/enum seulement) ; l'existence éventuelle d'un assemblage de
  plus haut niveau ailleurs dans `zcrud_study` qui recomposerait pile + notation (non recherché
  exhaustivement — le grep de confinement montre seulement que **`z_session_card_swiper.dart` est le
  seul fichier du monorepo important `flutter_card_swiper`**).
