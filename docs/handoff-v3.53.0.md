# Handoff v3.53.0 — un palier tapé dans l'assemblage note enfin le moteur

Origine : quatre demandes déposées par une application hôte après avoir porté sa session de
révision sur `ZStudySessionHost.wired` en visant la parité avec la référence. Toutes
mesurées, l'une **bloquante** — et elle désigne un trou dans une garantie que le handoff
v3.51.0 affirmait.

## Clés de schéma ajoutées

**Aucune.** Aucune entité persistée n'est touchée ; aucune migration n'est requise.

## Constats vérifiés sur disque avant tout travail

| # | Constat de l'hôte | Vérification | Verdict |
|---|---|---|---|
| 98 🔴 | Avec `gradingVisibility: always`, un palier tapé **notifie** l'hôte mais **ne note pas** le moteur ; la carte reste figée, saisie verrouillée | le host relaie `onQualitySelected` **nu** (`z_study_session_host.dart:616`) ; `_gradeAndAdvance` n'est atteint que par la soumission (`:1613`) | réel — **bloquant** |
| 98 bis | Une carte réinsérée au lapse **seule** garde la saisie précédente : la clé `zStudySessionAnswer_<id>` ne porte pas de numéro de présentation | à mesurer par le lot | à mesurer |
| 96 | `onSource` de la carte n'est relayé ni par le wiring ni par le slot | `grep onSource` host/view/slot ⇒ 0 | réel |
| 97 | `allowSkipEvaluation` et `revealStoredHint` ne sont pas relayés ; une saisie vide part au port d'évaluation | `grep` host ⇒ 0 ; validateur `answerRequired` présent dans la saisie (`:1339`) | réel, soumission vide à mesurer |
| 95 | `qualityPreviewLabelFor` ne reçoit pas la carte : un aperçu SM-2 par carte est inatteignable | `String Function(int quality)` sur host et saisie | réel |

Sur le point 98, la garde de v3.51.0 comptait les **notifications** de la surface de saisie,
pas les **écritures** du host. Elle était verte, mordante — et regardait à côté. L'hôte a
raison sur les mots : « le compteur mesuré est celui du rappel, pas celui de l'écriture ».

## Une réponse vide ne part plus au port d'évaluation

`_submitWritten` ne lisait jamais la vacuité de la réponse : il passait `userAnswer: ''` au
port d'évaluation, puis émettait une soumission au seuil de réussite. Le validateur
`answerRequired` existait — **aucun chemin de soumission ne le consultait**, et
`AutovalidateMode.onUserInteraction` n'affiche rien tant que rien n'a été tapé.

Désormais une saisie rédigée vide est **refusée avant tout appel** : message de validation
(clé l10n existante), saisie non verrouillée, aucune exception. Le chemin volontaire pour
« passer » une carte existe et est distinct — **« Je ne sais pas »** —, ce qui fait de ce
changement une correction, pas une rupture de contrat. Il se voit néanmoins :

⚠️ **Tout code qui soumettait une réponse rédigée vide ne soumet plus rien.**
- **Application qui désactivait le bouton** sur saisie vide : retirez cette compensation, le
  socle refuse maintenant lui-même. Le test qui doit rougir chez vous : « le bouton est
  désactivé quand la saisie est vide » (il ne l'est plus — il refuse au tap).
- **Application qui « passait » une carte par soumission vide** : basculez sur
  « Je ne sais pas ». Le test qui doit rougir : « une soumission vide fait avancer la file ».

## L'aperçu d'intervalle reçoit la carte

`qualityPreviewLabelFor` (`String Function(int quality)`) ne recevait pas la carte : un
aperçu SM-2 (« ↺ 15 j ») dépend de l'état de répétition de **la carte de devant**, et un
hôte devait tenir un miroir de file pour l'obtenir. Un second seam, **additif**, sur la
surface de saisie : `qualityPreviewLabelForCard: String Function(ZFlashcard card, int
quality)?`. Priorité : **carte > ancien seam > aucun aperçu**. L'ancien type ne change pas.

- **Application passive** : rien ne change.
- **Application qui tenait un miroir de file** pour l'aperçu : retirez-le et posez le seam
  avec carte. Le test qui doit rougir : celui qui affirme que le miroir est consulté.

## Note d'adoption : `gradingBuilder` et le doublon de choix

Depuis v3.52.0, l'assemblage pose `hidden` sur la carte d'un QCM **sauf** quand
`gradingBuilder` est fourni — le socle ne sait pas ce que rend votre créneau. Cas mesuré
chez un hôte : un créneau qui rend **lui-même** les choix retrouve le doublon (deux fois le
même choix à l'écran). Posez alors `questionFaceChoices:
ZFlashcardQuestionFaceChoices.hidden` explicitement, et gardez-le chez vous par un test
« les choix ne sont rendus qu'une fois ». Ce n'est pas un défaut du socle : c'est la
frontière d'une décision qu'il ne peut pas prendre à votre place.

## Un palier tapé note enfin le moteur

Avec `gradingVisibility: always` — ce que pose le preset `.classic` —, un palier tapé avant
la réponse verrouillait la saisie et appelait `onQualitySelected` **et rien d'autre**. Le
host relayait le rappel nu, sans jamais atteindre la voie d'écriture. Mesuré avant
correction : **zéro** écriture. La garde de v3.51.0 qui affirmait « une notation manuelle,
prouvé par compteur » comptait les **notifications de la surface de saisie**, pas les
écritures du host — et pire, une autre garde **assertait ce zéro**. Elle est retournée.

Le contrat, désormais écrit et gardé par le **compteur d'écritures du `reviewer`** :
- palier actif **avant** la réponse ⇒ le taper **note la carte** et la fait partir, en
  respectant `postSubmitPolicy` (retenue en `learn`) exactement comme une soumission ;
- **après** la réponse ⇒ c'est la soumission qui a noté ; le palier n'est qu'un rappel ;
- le rappel `onQualitySelected` part **toujours**, avant toute décision d'écriture ;
- **une seule écriture par présentation de carte**, par la voie unique — tenter de soumettre
  après un palier ne réécrit pas.

Le bilan de session compte les cartes **notées**, sans fabriquer de soumission fictive.

**Une carte réinsérée seule repart vierge.** La clé de la saisie porte un numéro de
présentation. Mais la clé seule était **inerte** : la carte de devant est publiée par un
notifieur à égalité de valeur, qu'une réinsertion du même identifiant ne fait pas bouger.
La tranche est donc **republiée** explicitement — ce qui referme aussi la révélation
(mesuré : sans cela, une carte redemandée revenait face réponse).

## `onSource` et l'aperçu par carte entrent dans le wiring — c'est cassant, comme annoncé

`ZStudySessionWiring` passe de 22 à **24 champs `required`** : `onSource` (« voir la
source » de la carte de devant, relayé à `ZFlashcardReviewCard.onSource`) et
`qualityPreviewLabelForCard` (l'aperçu d'intervalle avec la carte). C'est le prix du
mécanisme, écrit dans sa documentation depuis sa naissance : **ajouter un seam casse les
montages `.wired`** — c'est ce qui garantit qu'aucun montage ne les oubliera en silence.

⚠️ **Deux applications cassent à la compilation en montant cette version** — mesuré dans
leurs sources : celle qui monte `ZStudySessionWiring` dans sa page de session, et celle
qui le monte dans son pont de session. Le correctif tient en **deux lignes** dans le
constructeur du wiring :

```dart
onSource: null,                    // ou votre rappel « voir la source »
qualityPreviewLabelForCard: null,  // ou (card, q) => votre projection SM-2
```

Un `null` est une **décision écrite** — c'est tout ce que le mécanisme demande. Les
montages à plat ne sont pas touchés ; leur audit (`auditSeams`) signale simplement deux
seams de plus.

## Les deux drapeaux traversent

`allowSkipEvaluation` et `revealStoredHint`, livrés autrefois pour un hôte, n'étaient pas
relayés par l'assemblage : sous `ZStudySessionHost`, « Évaluer sans IA » était absent et
l'indice stocké n'était servi qu'après un tap. Relayés, nullables (`null` ⇒ défaut de la
saisie), classés **cosmétiques** par la règle écrite — ils ne câblent rien, leur effet est
nul sans le seam qui les porte. Ils restent hors du wiring.

## Si vous n'adoptez rien

Une application **passive** au montage à plat, sans `always`, voit **un** changement :
une saisie rédigée vide ne part plus au port d'évaluation (cf. plus haut). Tout le reste
est identique à l'octet.

Une application **sur `.classic`** (donc `always`) voit un palier tapé **noter et faire
partir** la carte — ce qu'il aurait toujours dû faire.

Une application en **`.wired`** doit ajouter deux lignes, ou ne compile pas.

## Les tripwires à écrire chez vous

| Vous compensiez… | Le test qui doit rougir |
|---|---|
| un `gradingBuilder` qui refaisait le fil « palier → soumission » pour que la carte parte | « mon `gradingBuilder` est appelé » — et gardez « une écriture par présentation », qui doit rester vert |
| un miroir de file pour projeter l'intervalle SM-2 | « le miroir est consulté » |
| un `cardSlotBuilder` posé pour câbler « voir la source » | « mon `cardSlotBuilder` est appelé » |
| la désactivation du bouton sur saisie vide | « le bouton est désactivé quand la saisie est vide » |
| une composition qui passait `allowSkipEvaluation`/`revealStoredHint` à la main | « ma composition est montée » |

## Vérification, rejouée au repos

- `melos run generate` → RC=0, **0 fichier généré modifié** ;
- `melos run analyze` **repo-wide** → RC=0 ;
- `melos run verify` (gates, dont `web`, `reserved-keys`, graphe acyclique et recette de
  consommation) → RC=0 ;
- balayage des **42 paquets**, `flutter test --no-pub -j 4` lancé **depuis le dossier de
  chaque paquet** → **41 verts**. `zcrud_generator` est rouge pour une raison
  d'environnement, qualifiée et non imputable au code : son `lib` et son `test` sont
  **identiques à l'octet** à la version précédente ;
- comptes mesurés à la clôture des lots : `zcrud_session` 775, `zcrud_study` 2394 ;
- aucun résidu d'injection R3, aucun `if (false` en production.

Vingt-trois injections R3, toutes rouges par assertion. **Trois gardes étaient vertes sous
injection** : l'une parce que sa valeur injectée n'était jamais lue (injection inerte,
refaite), l'autre parce que le verrou qu'elle visait était couvert par un second (garde
neuve sur une surface d'hôte qui soumet deux fois), la troisième parce que les cartes
empilées sont muettes par défaut (rejouée sous `backCardsContent: full`). Aucune n'a été
déclarée solide. Et une garde de la version précédente **assertait le défaut** — c'est
elle que cette version retourne.
