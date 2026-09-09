# Changelog

Toutes les modifications notables de `zcrud_study` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.54.0 — 2026-09-09

### Modifié

🔴 **Le formulaire de carte du multi-éditeur édite désormais la carte ENTIÈRE.**
Le sélecteur de type proposait `multipleChoice` et `trueOrFalse`, mais le
formulaire ne montait que l'énoncé, la réponse, l'explication et l'indice : une
carte QCM créée dans `ZMultiFlashcardEditor` sortait **sans choix** et une carte
vrai/faux **sans valeur** — invalides pour la révision. Les balises n'étaient
pas éditables du tout.

Le formulaire par défaut monte maintenant, **en réutilisant les widgets
d'édition du socle** (aucun second éditeur écrit) :

| Champ | Widget | Quand |
|---|---|---|
| choix du QCM | `ZChoicesFieldWidget` (`zcrud_flashcard`) | type `multipleChoice` |
| valeur vrai/faux | `ZTrueFalseFieldWidget` (`zcrud_flashcard`) | type `trueOrFalse` |
| balises | `ZTagsFieldWidget` (`zcrud_core`) | toujours |

Les deux premiers occupent une **place stable** dans le formulaire : le champ
apparaît et disparaît au même endroit, l'ordre ne bouge pas.

**Ce qui change pour une application déjà montée** : le volet détail du
multi-éditeur rend deux champs de plus (un seul si le type n'est ni QCM ni
vrai/faux). Une application qui avait posé `fieldBuilders` pour l'énoncé ou la
réponse continue de les voir honorés — ces créneaux sont inchangés. Une
application qui rendait **déjà** ces champs à côté du multi-éditeur les rendrait
désormais en double : elle passe à `cardFormBuilder` (ci-dessous), qui remplace
le formulaire du socle entièrement.

🔴 **Une carte invalide bloque le commit du lot.** Le commit ne validait rien :
le lot partait tel quel. Il applique désormais, à **toutes** les cartes, la
règle du socle (`ZFlashcardEditionValidator` — énoncé requis ; un QCM exige au
moins deux choix dont au moins un correct). La première carte fautive est
focalisée, la cause est affichée, et **aucune** salve n'est émise ; le brouillon
reste intact.

**Ce qui change pour une application déjà montée** : un lot qui contenait déjà
une carte sans énoncé, ou un QCM incomplet, n'est plus committé en silence.
Une application qui porte ses propres règles injecte `cardValidator` ;
`cardValidator: (card) => null` restitue exactement le comportement antérieur.

### Ajouté

- **`cardFormBuilder`** sur `ZMultiFlashcardEditor` : créneau de formulaire de
  carte **entier**. L'application monte son propre formulaire **dans**
  l'ossature de lot (liste, sélection, suppression groupée, aperçu, commit
  unique) sans rien en réécrire. Le créneau reçoit un
  **`ZFlashcardCardFormSlot`** : la carte vivante du brouillon, les controllers
  **stables** des quatre champs de texte (`controllerOf`, écoutés — le texte
  qu'on y écrit est publié), les tranches `type`/`choices`/`isTrue`/`tagIds`,
  un `onChanged` typé par champ écrivant **dans le même brouillon**, la fin de
  saisie, et `validate()` (la règle même qui garde le commit). Fourni, il
  remplace le formulaire du socle : aucun champ n'est rendu deux fois.
- **`cardValidator`** (`ZFlashcardCardValidator`) : règle de validité d'une
  carte, appliquée avant le commit du lot.
- **Libellés de la garde de sortie** dans `ZMultiFlashcardEditorLabels` :
  `discardTitle`, `discardMessage`, `discardConfirmLabel`, `discardCancelLabel`,
  relayés à `ZDiscardChangesGuard`. Le dialogue d'abandon de saisie affichait un
  repli non surchargeable. Absents, ce repli s'applique inchangé.
- **Libellés des champs neufs** dans `ZMultiFlashcardEditorLabels` :
  `choicesLabel`, `addChoiceLabel`, `trueFalseLabel`, `trueLabel`, `falseLabel`,
  `tagsLabel`, et `editionMessages` (messages d'invalidité rapportés au refus
  de commit). Tous **nullables** : un libellé omis laisse s'appliquer le défaut
  du widget d'édition correspondant, jamais un libellé écrit dans ce paquet.

Aucun champ `required` n'a été ajouté : les montages existants de
`ZMultiFlashcardEditorLabels` et de `ZMultiFlashcardEditor` compilent inchangés.

## 3.53.0 — 2026-09-09

### Modifié

🔴 **Cassant pour `ZStudySessionHost.wired` / `ZStudySessionScaffold.wired`.**
`ZStudySessionWiring` passe de 22 à **24 champs `required`** : tout montage
énuméré doit nommer les deux seams neufs (`qualityPreviewLabelForCard`,
`onSource`), `null` compris. C'est le prix annoncé du mécanisme — un champ
ajouté avec une valeur par défaut rouvrirait le trou que ce type ferme.
Correctif : ajouter les deux lignes au `ZStudySessionWiring(...)` existant.
Un montage **à plat** (`ZStudySessionHost(...)`) n'est pas concerné.

🔴 **Un palier de notation tapé AVANT la réponse NOTE désormais la carte.**
En `answerGradingVisibility: always` — le régime que pose
`ZStudySessionPreset.classic` — la rangée de paliers est montée et active avant
toute réponse. Taper un cran verrouillait la surface (saisie inerte, soumission
retirée) et se contentait de **notifier** `onQualitySelected` : rien n'était
écrit, la carte restait figée, et la session n'avait plus d'issue.

Le contrat est désormais écrit et garanti :

| Moment du geste | Qui note | Ce que fait `onQualitySelected` |
|---|---|---|
| **avant** la réponse | le palier tapé | il notifie, **et** la carte est notée puis part |
| **après** la réponse | la soumission | il ne fait que notifier |

Une présentation de carte produit **exactement une** écriture de révision
(invariant AD-33), par la voie unique de l'assemblage — retenue après notation
(`postSubmitPolicy`) comprise : en mode d'apprentissage, la carte notée à la
main reste affichée jusqu'à « Continuer », son écriture étant déjà partie. Le
rappel de l'hôte, lui, part **toujours**, avant toute décision d'écriture.

⚠️ **Hôte ayant COMPENSÉ** : un écran qui branchait `onQualitySelected` sur sa
propre écriture SRS pour rattraper ce défaut **doit retirer sa compensation** —
elle s'ajouterait à celle de l'assemblage et noterait la carte deux fois.
Un hôte qui n'utilise pas `always` (défaut `afterSubmit`) n'a rien à faire :
la rangée n'y apparaît qu'après la réponse, et le rappel y reste un rappel.

🔴 **Une carte réinsérée au lapse repart sur une saisie vierge.** La clé de la
surface de saisie porte désormais le **numéro de présentation** de la carte
(`zStudySessionAnswer_<id>#<n>`). Une carte réinsérée **seule** revenait sous
la même identité, donc sous la même clé : son `State` survivait, avec la
réponse déjà tapée, sa correction et son verrou de soumission. La tranche de
carte de devant est redite à chaque présentation neuve — sans quoi la clé
n'aurait jamais été relue. Dans le même geste, la **révélation se referme** :
la carte redemandée revient face question, plus face réponse.

Les tests qui cherchent cette clé par son littéral doivent ajouter le suffixe
de présentation (`#0` pour une première présentation).

### Ajouté

- `ZStudySessionHost.onSource` / `ZStudySessionScaffold.onSource` —
  `void Function(ZFlashcard card)?`, relayé à l'action « voir la source » de la
  carte de **devant** (jamais aux cartes empilées). `null` ⇒ action absente de
  l'arbre. Également 23ᵉ champ de `ZStudySessionWiring`.
- `ZStudySessionHost.qualityPreviewLabelForCard` /
  `ZStudySessionScaffold.qualityPreviewLabelForCard` —
  `String Function(ZFlashcard card, int quality)?`, aperçu d'intervalle
  prévisionnel recevant la carte affichée : un intervalle SM-2 se calcule sans
  tenir en parallèle un miroir de la file. Prioritaire sur
  `qualityPreviewLabelFor`, qui reste inchangé. 24ᵉ champ du wiring.
- `ZStudySessionHost.answerAllowSkipEvaluation` /
  `answerRevealStoredHint` (et leurs jumeaux sur `ZStudySessionScaffold`) —
  `bool?` relayés à la surface de saisie ; `null` (défaut) laisse le défaut de
  la surface. Ils restent **à plat** sur les deux constructeurs : la partition
  du montage les classe cosmétiques — ils ne câblent ni port, ni callback, ni
  constructeur de rendu, et leur effet est nul sans le seam qui les porte
  (`evaluationPort` pour l'un, l'indice de la carte pour l'autre).
- `ZStudySeam.onSource` et `ZStudySeam.qualityPreviewLabelForCard` — l'audit de
  montage couvre les 24 seams.

## 3.52.0 — 2026-09-09

### Modifié

🔴 **Deux ruptures VISIBLES pour un hôte qui monte l'écran de session assemblé
(`ZStudySessionHost` / `ZStudySessionScaffold`) sans avoir rien contourné.**
Elles ne touchent que la **carte par défaut** : un hôte qui pose son propre
`cardBuilder` ou `cardSlotBuilder` rend sa carte, et rien ne change pour lui.

- **Sur un QCM, les choix disparaissent de la CARTE.** L'écran monte une
  surface de saisie (`ZFlashcardAnswerInput`) qui rend les mêmes choix,
  interactifs ; la carte les rendait aussi, en radios inertes, sur sa face
  question. Le même QCM s'affichait donc **deux fois**, une fois tapable et une
  fois non. La règle appliquée désormais : *la carte ne rend pas ses choix
  quand la saisie du socle les rend*. La face **réponse** est inchangée — ses
  choix y portent le marquage de la bonne réponse, c'est-à-dire la correction.
  La décision se retire d'elle-même quand l'hôte pose un `gradingBuilder` :
  l'écran ne sait pas ce que rend une surface qui n'est pas la sienne, et la
  carte y garde ses choix.
- **Les cartes empilées derrière celle qu'on consulte perdent leur contenu.**
  La pile laisse dépasser une bande d'environ 18 dp de la carte suivante ; le
  texte qui s'y lisait était celui de la question d'après. Les cartes de rang
  > 0 sont désormais **muettes** : le chrome seul — fond, rayon, ombre portée,
  liseré de tête —, sans énoncé, choix, badge de type, consigne ni actions, et
  **sans nœud d'accessibilité** (elles ne sont plus annoncées comme des
  questions par un lecteur d'écran). La carte de **devant** est toujours pleine,
  et le redevient dès qu'elle passe devant.

  ⚠️ **Hôte ayant COMPENSÉ** : un écran qui masquait lui-même le débord de la
  pile (rognage, superposition opaque, `ExcludeSemantics` sur les cartes
  arrière) doit **retirer sa compensation** — elle s'additionne au correctif.

**Échappatoire, dans les deux sens.** `ZStudySessionHost` et
`ZStudySessionScaffold` portent deux réglages **nullables** ; `null` (défaut)
laisse l'assemblage décider, une valeur posée le bat :

- `questionFaceChoices` (`ZFlashcardQuestionFaceChoices?`) — `shown` ramène les
  choix sur la carte même quand la saisie les rend ; `hidden` les retire même
  sans saisie du socle ;
- `backCardsContent` (`ZFlashcardFaceContent?`) — `full` restitue le contenu
  des cartes empilées.

Les deux sont **cosmétiques** au sens de la partition seams/cosmétiques : ils
ne câblent ni port, ni callback, ni constructeur de rendu, ni contrôleur. Ils
restent donc **à plat** sur les deux constructeurs, y compris `.wired`, et ne
sont **pas** des champs de `ZStudySessionWiring` — un montage énuméré n'a pas à
réécrire une décision que l'assemblage prend pour lui. Ils ne sont pas non plus
portés par `ZStudySessionPreset` : un preset décrit une identité visuelle
partagée entre écrans, alors que ces deux décisions dépendent de ce que CET
écran monte à côté de la carte (une saisie de l'hôte, une pile) — le même
preset posé sur un écran à `gradingBuilder` y rétablirait le doublon qu'il
supprime ailleurs.

- **Le créneau de carte de la pile est désormais posé SANS condition.** L'écran
  ne passait `cardSlotBuilder` à la vue que lorsque l'affordance de révélation
  était portée (mode `learn`, ou `revealPolicy: always`) ; ailleurs, la pile
  empruntait `cardBuilder` et **aucune carte ne connaissait son rang**. Le rang
  n'est pas une affordance que l'hôte offre ou non : c'est une information que
  seule la pile détient. La voie `cardBuilder` reste servie **à l'identique**
  par le créneau — une carte d'hôte est rendue telle quelle, sans habillage ni
  décision de composition —, et l'arbre d'une session à **une seule carte** est
  inchangé nœud pour nœud (garde d'inertie à dump figé).

### Ajouté

- **`ZStudySessionHost.questionFaceChoices` et
  `ZStudySessionHost.backCardsContent`**, relayés par
  `ZStudySessionScaffold` (les deux constructeurs) — cf. « Modifié » ci-dessus
  pour leur contrat. Les deux enums (`ZFlashcardQuestionFaceChoices`,
  `ZFlashcardFaceContent`) viennent de `zcrud_flashcard`.

## 3.51.0 — 2026-09-09

### Modifié

- **`zFlashcardTypeShadowColor` n'écrit plus la chaîne de résolution : elle
  l'APPELLE.** Le relais recomposait les trois maillons (seam préfixé, seam
  nu, jeton `flashcardTypeGradients`) parce que la chaîne était privée en
  amont ; `zcrud_flashcard` la publie désormais
  (`zResolveFlashcardTypeGradient`), et le relais s'y branche. Un seul ordre à
  maintenir, dans le paquet qui le possède. **Aucun changement de rendu** :
  mêmes clés, même ordre, même `null` fonctionnel — les gardes de teinte
  d'ombre par type sont inchangées et vertes.

  La garde d'ordre inter-paquets, qui lisait la source de la carte amont pour
  y comparer les maillons recopiés, est **remplacée** (elle n'a plus d'objet)
  par une garde de source « aucune réécriture de la chaîne dans `preset/` » :
  les trois motifs de maillon doivent être absents de tout fichier du
  répertoire, et le détecteur porte sa contre-preuve (un fichier synthétique
  qui les porte est détecté ; l'appel au foyer unique, lui, ne l'est pas).

### Ajouté

- **Les quatre réglages de FORME de la surface de saisie traversent enfin
  l'assemblage.** `ZStudySessionHost` et `ZStudySessionScaffold` portent
  `answerChoiceLayout`, `answerActionsLayout`, `answerSubmitWidth` et
  `answerGradingVisibility` — tous **nullables**, relayés tels quels à la
  surface montée par l'écran. Avant ce lot, changer la forme de trois boutons
  imposait de réimplémenter la surface entière par `gradingBuilder`,
  c'est-à-dire de reperdre l'évaluation, les indices, la correction, la
  notation et le verrou one-shot pour gagner trois formes.

  Chaîne de résolution complète, maillon par maillon : **paramètre de l'écran >
  forme décrite par le preset > jeton `ZcrudTheme.answerInput*` > référence**.
  Les quatre restent nullables à chaque étage — sans cela, « posé au défaut » et
  « non posé » seraient indistinguables et la chaîne deviendrait inexprimable.

  Les quatre types (`ZAnswerChoiceLayout`, `ZAnswerActionsLayout`,
  `ZAnswerSubmitWidth`, `ZAnswerGradingVisibility`) sont **ré-exportés** par le
  barrel : un appelant de l'écran les nomme sans second import.

- **`ZStudySessionPreset` gagne les quatre formes**, et `ZStudySessionPreset
  .classic` les pose : `tile`, `sideBySide`, `full`, `always`. Un paramètre
  explicite de l'écran bat le preset, **forme par forme**.

- **L'ombre de la carte de session suit son TYPE.** `ZCardChromeSpec` porte
  désormais `shadowColor` (une teinte, en valeur) et `shadowColorResolver` (une
  teinte résolue **au site de montage**, donc dépendante du thème courant et de
  la carte rendue) ; l'écran les relaie au `shadowColor` de la carte, au site
  unique où il la monte. Priorité **valeur > résolveur > rien**.

  `ZStudySessionPreset.classic` pose la direction : la teinte est la **première
  couleur du dégradé qui identifie le type** de la carte, obtenue par la même
  chaîne que le liseré et la pastille — clé préfixée soumise au résolveur de
  l'hôte, puis nom de type nu, puis jeton `ZcrudTheme.flashcardTypeGradients`.
  C'est une forme qu'un thème ne peut **pas** décrire : il n'a qu'un jeton de
  teinte d'ombre, donc une valeur, quand un écran montre plusieurs types côte à
  côte. `classic(cardShadowColor:)` impose au contraire une teinte unique.

  La fonction de résolution, `zFlashcardTypeShadowColor`, est **publiée** : elle
  se pose telle quelle sur `shadowColorResolver`, ou s'enrobe pour n'agir que sur
  certains types.

  Chaîne **totale** : un type dont aucun dégradé n'est résoluble ne reçoit pas de
  teinte, et le jeton `flashcardCardShadowColor` garde la main — un chrome qui ne
  décrit aucune ombre transmet `null`, jamais une teinte fabriquée. Sans preset,
  aucune boîte d'ombre n'entre dans l'arbre.

### Modifié

- 🔴 **`ZStudySessionPreset.classic()` décrit désormais TOUJOURS un chrome de
  carte** (`cardChrome != null`), là où il ne le faisait qu'en présence d'une
  valeur de carte : la direction d'ombre par type en fait partie, au même titre
  que la pilule de progression. Le descripteur n'est donc jamais vide (AD-4
  tient), et il reste **strictement inerte** partout où la chaîne par type ne
  résout rien. Effet observable pour un hôte : sous `classic`, une carte dont le
  type porte un dégradé gagne une ombre teintée qu'elle n'avait pas. Un hôte qui
  **compensait** cette absence par sa propre ombre (un `Container` décoré autour
  de la carte, ou un jeton `flashcardCardShadowColor` posé pour tous les types)
  doit **retirer sa compensation** : les deux ombres s'additionneraient.

### ⚠️ Avertissement de COMPORTEMENT — `ZStudySessionPreset.classic`

`.classic` pose `answerGradingVisibility: ZAnswerGradingVisibility.always`, qui
**change l'ORDRE DES GESTES** : la rangée de paliers est montée et active
**avant** la réponse, et un palier tapé alors **est** une notation manuelle —
elle part par `onQualitySelected`, la voie de notation habituelle, aucune autre,
et elle **verrouille** la surface (saisie inerte, soumission et contrôles d'aide
retirés). Une carte notée à la main produit **exactement une** notation, jamais
deux (AD-33), et aucune `ZFlashcardSubmission` n'est fabriquée. Sans
`onQualitySelected`, aucune rangée n'est montée : le réglage n'a alors aucun
effet.

Un hôte qui adopte `.classic` et veut garder l'ordre habituel — répondre, puis
noter — pose `answerGradingVisibility: ZAnswerGradingVisibility.afterSubmit` sur
l'écran, ou `ZStudySessionPreset.classic(answerGradingVisibility: …)`. Les trois
autres formes de `.classic` sont purement visuelles.

Un hôte qui **ne pose pas** `.classic` ne voit **aucun** changement : sans preset
et sans aucun des quatre paramètres, l'arbre monté est identique à l'octet à
celui d'avant ce lot (quatre dumps figés avant écriture, égalité stricte —
porteur/rédigé, porteur/choix, porteur/voie de notation, page).

### Interne

- La partition seam/cosmétique du montage énuméré (`ZStudySessionWiring`) admet
  les quatre types **nominativement**, jamais par suffixe : ils ne câblent rien
  (ni port, ni callback, ni constructeur de rendu, ni contrôleur), les oublier
  coûte une forme et jamais une capacité. `ZAnswerGradingVisibility.always`
  déplace le moment d'une affordance **déjà branchée** : sans le seam
  `onQualitySelected`, il n'a aucun effet. Contre-preuve permanente : un
  `ZFutureLayout?`/`ZFutureWidth?`/`ZFutureVisibility?` inédit retombe du côté
  « seam » et fait rougir la comparaison tant qu'il n'est pas câblé.

- Les deux dumps d'inertie de la scène `socle` du montage énuméré
  (`z_session_tree_before_lotw1_socle.txt`,
  `z_page_tree_before_lotw2_socle.txt`) sont **re-gelés** : leur scène monte
  `ZStudySessionPreset.classic`, dont l'arbre change désormais par conception.
  Diff **audité avant re-gel** — que des ajouts imputables aux trois formes
  applicables (rangée de six paliers, ligne d'aide côte à côte, action de
  soumission étirée) et un unique déplacement de la paire
  `ValueListenableBuilder<String?>`/`SizedBox` du bloc d'indices ; **aucun
  retrait**, aucun nœud de carte touché.

## 3.50.0 — 2026-09-09

### Ajouté

- **Le socle monte ses propres démonstrations comme il recommande de les
  monter.** Recommander le montage énuméré tout en le montrant nulle part
  laissait la recommandation à l'état de prose : un lecteur copie ce qu'il
  voit. `test/support/z_session_mount_demos.dart` porte désormais la
  démonstration de référence — l'écran (`ZStudySessionHost.wired`) et la page
  (`ZStudySessionScaffold.wired`) montés seam par seam, les vingt-deux nommés,
  `null` compris, avec les cosmétiques restés à plat.

  Constat de départ, mesuré avant d'écrire : **aucune démonstration du paquet
  ne montait à plat** — il n'y avait rien à migrer. Les 99 sites du
  constructeur par défaut sont tous des harnais qui l'exercent délibérément
  (comparaison d'inertie entre les deux montages, audit d'un montage à plat,
  sondes de seam), et les migrer casserait ce qu'ils mesurent. Ce qui manquait
  n'était pas une migration mais la démonstration elle-même. À noter : la démo
  d'assemblage de bout en bout du paquet assemble encore sa session à la main
  depuis les briques de plus bas niveau, sans passer par l'écran de session —
  elle n'a pas été touchée (la réécrire changerait ce qu'elle démontre).

  Garde G8 (`lotw4_demo_mounts_test.dart`, 8 tests) : **nominative, jamais
  globale** — elle porte une liste nommée de fichiers de démonstration, et rien
  d'autre ; un balayage de tout `test/support/` condamnerait les harnais
  légitimes. Trois contre-preuves : une entrée qui n'existe pas rougit, une
  entrée qui ne monte aucune session rougit, et un harnais à plat **hors
  liste** reste vert. Inertie : la démonstration énumérée rend, nœud pour nœud,
  l'écran du montage à plat de mêmes valeurs — c'est ce qui atteste qu'un
  montage de vingt-deux seams écrit à la main n'en a perdu aucun.

- **README — « Trois façons de monter une session ».** Une page de doctrine qui
  dit **quand** choisir chacun des trois régimes, avec son code minimal :
  `.wired` pour ce qu'on livre, à plat avec `seamAudit` pour ce qu'on reprend,
  à plat sans rien pour ce qu'on jette. Et la ligne de partage entre les deux
  objets : les **formes** viennent du preset, les **seams** du wiring — aucun
  recouvrement.

- **Filet d'audit des seams de session — le montage à plat reçoit enfin un
  signal.** `ZStudySessionWiring`/`.wired` ferme la classe « un seam oublié en
  silence » pour les hôtes qui adoptent le montage énuméré. Ceux qui restent au
  montage à plat — la majorité, et le régime le moins cassant — n'avaient
  toujours rien : l'écran s'affiche, simplement ce n'est plus celui qu'on
  voulait.

  Quatre types publics : `ZStudySeam` (une valeur par champ du wiring, portant
  le **défaut** que le socle applique en son absence), `ZStudySeamReport`
  (`provided`/`waived`/`missing`/`invalidWaivers`, `isComplete`, rendu textuel
  qui nomme chaque trou et son défaut), `ZStudySeamAuditPolicy` (opt-in posé à
  la construction) et l'extension `auditSeams` sur `ZStudySessionHost`.

  `auditSeams` est **pure** — aucun `BuildContext`, aucun `pump` : elle
  s'appelle dans un test unitaire, sur le widget que l'hôte construit.
  `seamAudit`, lui, fait relever **une seule fois**, en debug et par
  `FlutterError.reportError`, les seams ni posés ni déclarés. Rien n'est levé
  (AD-10), rien n'est ajouté à l'arbre (garde de dump, nœud pour nœud), et le
  compilateur retire tout en release : le site d'appel vit sous `assert`.

  **Trois régimes, tous déclarés par l'hôte, jamais devinés** : sous `.wired`,
  un `null` est la décision écrite — le rapport n'y porte jamais de manquant ;
  à plat avec une politique, la décision est l'entrée nominative de `waived`, et
  l'oubli est tout le reste ; à plat sans politique, silence total. Une
  renonciation qui cite un seam **posé** est signalée à son tour
  (`invalidWaivers`) : la déclaration doit décrire le montage dans les deux
  sens.

  Le montage énuméré n'expose **aucune** politique : il n'a rien à auditer.

  Gardes : `lotw3_seam_audit_test.dart` (49 tests) — les 22 seams posés un par
  un et non par échantillon, `.none()` sans manquant, cohérence enum ↔ wiring
  lue sur la source, exactement un rapport et un arbre inchangé. Le `switch` de
  lecture des seams est **exhaustif** : une valeur d'enum ajoutée sans champ
  correspondant est une erreur de compilation, jamais un seam qui s'auditerait
  tout seul comme absent.

  Deux scanners existants amendés : `kCosmeticTypes` admet **nominativement**
  `ZStudySeamAuditPolicy` — un réglage de diagnostic ne câble rien, et sa
  contre-preuve (un `…Policy` voisin, un port inédit) reste conservée ; la
  borne du scanner de pass-through de la page passe de `\n  });` à `\n  })`,
  la même que celle du montage énuméré, sans quoi la capture non gourmande
  débordait sur le constructeur d'un widget privé.

- **`ZStudySessionScaffold.wired` — la page offre la garantie du montage
  énuméré.** Miroir exact de `ZStudySessionHost.wired`, d'un cran plus haut :
  `required ZStudySessionWiring wiring`, les cosmétiques et les défauts non nuls
  à plat, et **tous** les slots de page en pass-through. Un hôte qui monte la
  page — le cas courant — n'a plus à choisir entre la garantie et l'enveloppe.

  L'enveloppe **ne lit aucun champ du wiring** : elle le remet entier au
  porteur. Ce n'est pas une discipline, c'est structurel — le constructeur étant
  `const`, une liste d'initialisation ne *peut pas* lire `wiring.x`. Un seam
  ajouté demain au montage traverse donc la page sans qu'une ligne y soit
  écrite, et sans pouvoir y être oublié. Une garde de source l'assère par les
  trois écritures possibles du démontage (`wiring.x`, `_wiring?.x`,
  `wiring!.x`), une autre compare le relais des cosmétiques aux deux sources.

  **Coût d'un hôte passif : nul.** Le constructeur par défaut est inchangé, et
  rend le même arbre nœud pour nœud (dumps figés avant le lot).

- **La forme de la progression se règle et se décrit** :
  `progressDotsGeometry`, `progressLinearThickness` et
  `progressSegmentedMarkerThickness` sur `ZStudySessionHost`,
  `ZStudySessionScaffold`, `ZStudySessionView` **et** `ZStudySessionPreset`.
  L'écran choisissait le style de sa progression sans pouvoir en régler la
  forme : ni la taille d'un point, ni l'élongation du point courant, ni l'écart
  entre deux points, ni l'épaisseur d'une barre. Un hôte qui voulait la forme de
  sa référence visuelle n'avait qu'une issue — remplacer la pile entière, et
  perdre tout ce que le socle y monte.

  Résolution identique à celle du style : **paramètre explicite ⇒ preset ⇒
  défaut de l'indicateur**. Aucune dimension n'est substituée en chemin : `null`
  reste `null` jusqu'à l'indicateur, qui tient ses propres défauts.

  `ZStudySessionPreset.classic` pose la géométrie de sa direction de design —
  `inactiveSize: Size(14, 10)`, `activeScale: 2.4`, `gap: 12`, file **centrée**
  et **défilante sur une seule rangée** — et l'épaisseur `8` de la barre
  segmentée à marqueur. Elle ne décrit **aucune** épaisseur de barre continue :
  rien n'est fabriqué pour rien. Constantes publiques
  `ZStudySessionPreset.classicDotsGeometry` et
  `.classicSegmentedMarkerThickness`. Chaque réglage est sans effet hors de son
  style — décrire une forme ne la montre pas, elle attend le style qui la peint.

  Les trois champs entrent dans `==`, `hashCode` et `toString` du preset.
  `ZSessionDotsGeometry` est ré-exporté par le barrel : aucun hôte n'a à
  dépendre de `zcrud_session` pour décrire sa forme.

  **`preset: null` et aucun paramètre ⇒ rendu strictement inchangé** — arbre
  identique au dump figé avant le lot, et géométrie peinte identique (point
  carré de `gapM`, point courant à `1,5 ×`, écart `gapS`, file alignée au bord
  de lecture qui passe à la ligne).

- **Montage énuméré de la session — `ZStudySessionWiring` et
  `ZStudySessionHost.wired`.** Le porteur de session déclare 43 paramètres
  nommés, dont 34 nullables : 22 sont des **seams** (builders, ports,
  callbacks, libellés, contrôleur, preset) et 12 des cosmétiques de mise en
  page. Tous étaient optionnels, tous à défaut silencieux — en retirer un lors
  d'un remaniement ne produisait ni erreur de compilation, ni test rouge.
  Mesuré chez une application hôte : le retrait d'une composition de carte
  devenue inutile a emporté **six seams** (`contentBuilder`, `hintPort`,
  `evaluationPort`, `labels`, `onExit`, `onSessionEnd`) ; `analyze` est resté
  vert, la suite aussi, et seul l'écran l'a montré (libellés du socle
  affichés).

  `ZStudySessionWiring` énumère les 22 seams en champs **`required` de type
  nullable** : Dart oblige à *écrire* `hintPort: null` au lieu de l'omettre.
  L'oubli devient une erreur de compilation, la renonciation une ligne
  greppable. `ZStudySessionWiring.none()` renonce à tout d'un coup — banc
  d'essai, jamais un écran.

  `ZStudySessionHost.wired({required wiring, …})` est un constructeur de
  **transfert** : il alimente les mêmes champs `final` que le constructeur par
  défaut, n'accepte aucun seam à plat (donc aucune règle de fusion), et laisse
  les cosmétiques et les défauts non nuls là où ils étaient. À valeurs égales,
  l'arbre rendu est celui du constructeur par défaut, nœud pour nœud
  (dumps figés). **Coût d'un hôte passif : nul** — rien n'est requis sur
  `ZStudySessionHost` lui-même, l'opt-in passe par le constructeur nommé.

  ⚠️ Ajouter un seam à `ZStudySessionWiring` est **cassant** pour ses
  utilisateurs (le champ neuf est `required`) : c'est l'intérêt du mécanisme
  autant que son prix. La garde de complétude lit la source du porteur, partage
  ses paramètres nullables par une **règle de type** écrite dans la garde
  (`Function`/`Port`/`Builder`/`Controller`/`Labels`/`Preset`/`Widget` ⇒ seam ;
  liste fermée de scalaires, `Color`, `EdgeInsets*` et suffixe `Style` ⇒
  cosmétique, tout type inédit tombant du côté seam), et exige l'égalité
  stricte avec les champs du wiring : un seam ajouté demain sans être câblé
  rougit.

- **Assemblages de référence de l'écran de session — `ZStudySessionPreset`.**
  Tout ce dont une session complète avait besoin traversait déjà l'écran, mais
  **en valeurs** : une clé de dégradé ici, un seam de pastille là, une hauteur
  de liseré ailleurs. Les **formes** qui les assemblent — rangée d'en-tête,
  chrome de carte, style de progression — restaient à recomposer par chaque
  hôte, et chaque recomposition se paie (un créneau de carte posé sans l'état
  de révélation branché, un retrait qui emporte des seams sans qu'aucune
  assertion ne bouge).

  Trois types, sous `lib/src/presentation/preset/` :
  - `ZStudySessionPreset` — `header`, `cardChrome`, `progressStyle`,
    `cardBackgroundColorKey`, plus la fabrique `ZStudySessionPreset.classic`
    qui décrit les quatre formes depuis des valeurs simples ;
  - `ZSessionHeaderSpec` — titre, compteur (composé par l'hôte : en régime SRS
    `remaining + reviewed != total`), série d'assiduité, contenu de fin ; sa
    méthode `buildRow` rend la rangée de référence (cible ≥ 48 dp, `Semantics`
    d'en-tête, variantes directionnelles) ;
  - `ZCardChromeSpec` — `typeGradientKey`, `instructionBanner`,
    `questionTypeBadgeBuilder`, `accentHeight`.

  Le preset est **interprété par l'écran lui-même** (`ZStudySessionHost`,
  `ZStudySessionView`, `ZStudySessionScaffold`) : il n'y a aucun câblage
  intermédiaire à oublier. **Un paramètre explicite gagne toujours** sur la
  forme correspondante, maillon par maillon ; `preset: null` ⇒ aucune branche
  prise, arbre rendu **et couleurs peintes** strictement identiques.
  `cardBackgroundColorKey` est une **clé**, résolue par `zResolveColorKeyOrSlot`
  — jamais une couleur (FR-26). Aucune dépendance tierce nouvelle.

  `ZSessionProgressStyle` est désormais ré-exporté par le barrel : poser un
  style ne demande plus un second import.

  Gardes : `test/presentation/lotp3_session_preset_test.dart` (inertie en
  égalité stricte contre trois dumps figés avant le lot, priorité sur chacun
  des six maillons, effet **rendu** de chaque forme, granularité AD-2 mesurée
  sur la surface de notation — la pile mémoïse ses cartes par index et
  resterait muette sous n'importe quelle injection) et
  `test/presentation/lotp3_preset_source_guard_test.dart` (zéro couleur
  littérale, zéro libellé affichable, zéro nom d'application hôte).

- **`ZStudySessionHost` relaie les cinq créneaux de la carte de révision**
  jusqu'à la carte qu'il monte **déjà** — `questionTypeBadgeBuilder`,
  `instructionBanner`, `cardTypeGradientKey`, `cardAccentHeight`,
  `cardBackgroundColor`. Ces créneaux existaient sur `ZFlashcardReviewCard` mais
  n'étaient atteignables qu'en remplaçant la carte entière par `cardBuilder` —
  ce qui faisait perdre au passage le câblage `revealController`, donc la
  révélation elle-même. Le relais alimente la carte du socle aux **deux** sites
  symétriques (avec et sans affordance de révélation) ; tous nuls ⇒ arbre rendu
  **strictement identique** (AD-4). Les trois derniers portent le préfixe `card`
  pour ne pas se confondre avec `gradientKey` / `backgroundColor` de la page,
  qui teintent l'app-bar et le `Scaffold`.

  Gardes : `test/presentation/lotd4_session_card_slots_test.dart` — elles lisent
  le nœud réellement monté, la hauteur réellement mise en page et la couleur
  réellement peinte (`RenderDecoratedBox`, `RenderPhysicalShape`), jamais une
  valeur passée à un constructeur ; l'inertie est mesurée en **égalité stricte**
  contre deux dumps d'arbre capturés avant le relais.

### Modifié

- ⚠️ **`progressStyle` devient nullable** sur `ZStudySessionHost`,
  `ZStudySessionView` et `ZStudySessionScaffold` (`ZSessionProgressStyle?`,
  défaut `null` au lieu de `ZSessionProgressStyle.dots`). Un champ non nullable
  porteur d'un défaut ne peut pas distinguer « posé explicitement à `dots` » de
  « non posé » : la règle « le paramètre explicite gagne sur le preset » y était
  **inexprimable**. La résolution est désormais `paramètre ?? preset ?? dots`,
  au site de rendu.

  Un appelant qui passe une valeur n'est pas concerné ; un appelant qui n'en
  passait pas obtient le même rendu qu'avant. Seul un code qui **lit** le champ
  d'un de ces widgets en attendant un non-nul doit s'adapter.


### Corrigé

- **`ZStudySessionScaffold` ne relayait que 27 des 37 paramètres de
  `ZStudySessionHost`** (`MAJEUR`). Un hôte qui montait la page plutôt que le
  porteur perdait **en silence** : `cardSlotBuilder`, `onQualitySelected`,
  `qualityLabelKeyFor`, `qualityColorKeyFor`, `qualityPreviewLabelFor`,
  `qualityEmphasis`, `revealPolicy`, `postSubmitPolicy`, `questionRecall`,
  `bottomInset`. Les dix sont désormais transmis, plus les cinq créneaux de
  carte ci-dessus. Aucun défaut ne change : chaque paramètre garde exactement
  la valeur par défaut du porteur.

  Gardes : `test/presentation/lotd5_session_scaffold_seams_test.dart` — une
  valeur distinctive posée sur la page est **observable dans le rendu ou le
  comportement** pour chacun des quinze, plus une garde d'exhaustivité qui
  compare les deux sources sur disque : un paramètre ajouté demain au porteur et
  oublié dans l'enveloppe fait rougir.

- ⚠️ **CHANGEMENT DE COMPORTEMENT — `ZDefaultFlashcardCard` résout désormais son
  dégradé de type dans l'ordre `seam > jeton`** (`MAJEUR`). La carte consultait
  le jeton `ZcrudTheme.flashcardTypeGradients` **avant** le seam
  `ZcrudScope.gradientResolver`, à rebours de l'ordre que `zResolveGradient`
  applique dans tout le socle. Conséquence mesurée : une application qui adopte
  un thème du socle posant ce jeton — c'est le cas de `ZClassicTheme` — voyait
  son résolveur **ignoré sans aucun signal** (le seam était interrogé, sa
  réponse reçue, et jetée).

  Chaîne finale, du plus fort au plus faible : `typeColors[type]` → `colorKey`
  posé (coupe l'axe type entier) → **seam** `flashcard.type.<type.name>` →
  **jeton** `flashcardTypeGradients[type]` → `ZFlashcardCardReference`. Les deux
  maillons amont ne bougent pas.

  🔴 **Ce qui change pour un hôte** : une application qui posait un résolveur de
  dégradé **et** un thème du socle voit désormais son résolveur peindre. Si elle
  s'appuyait sur le jeton pour cette carte, elle doit soit retirer son résolveur
  pour ces clés, soit passer l'entrée par le paramètre `typeColors` (qui prime
  toujours). Une application qui ne posait qu'un des deux ne voit **aucun
  changement**.

  Gardes : `test/presentation/lotd5b_list_card_gradient_order_test.dart`. La
  garde `cr_iffd57_58_flashcard_reference_test.dart` qui affirmait l'ordre
  inverse — elle **défendait le défaut** — a été retournée.

## 3.49.0 — 2026-09-08

### Ajouté

- **Les trois surfaces les plus regardées de la session d'étude deviennent
  teintables indépendamment du reste** — chaîne `paramètre > jeton > rôle`,
  `null` partout ⇒ rendu peint strictement inchangé :
  - fond de `ZDefaultFlashcardCard` : paramètre `backgroundColor` >
    `ZcrudTheme.flashcardCardBackgroundColor` > rôle `scaffoldBackgroundColor` ;
  - ombre de `ZDefaultFlashcardCard` : **nouveau** paramètre `shadowColor` >
    `ZcrudTheme.flashcardCardShadowColor` > rôle `shadowColor` (teinte seule —
    opacité, flou et décalage restent la référence) ;
    Relayé par la voie typée sous le nom `ZStudyToolsSectionSpec.flashcards(
    cardShadowColor:)`, comme l'exige la garde de parité carte ↔ voie typée ;
  - séparateur de `ZStudySessionView` : **nouveau** paramètre `dividerColor`
    (relayé à `zStudySessionChromeOf`) > `ZcrudTheme.studySessionDividerColor` >
    rôle `outlineVariant`.

  Gardes associées : `test/presentation/z_study_chromatic_tokens_test.dart` —
  elles lisent la couleur RÉELLEMENT PEINTE (le `Material` construit par `Card`,
  la `BoxDecoration` de l'ombre, la bordure construite par `Divider`), jamais
  une valeur passée à un constructeur.

### Corrigé

- **La pastille de palette signature de `ZStudyUnitPicker` passe enfin par la
  chaîne de résolution complète** (`MAJEUR`) : elle appelait la fonction PURE
  `zSignatureGradientFor`, court-circuitant le seam hôte
  `ZcrudScope.gradientResolver`, le jeton `ZcrudTheme.signaturePalette` et la
  stratégie `ZcrudTheme.signaturePaletteIndexStrategy`. Une application n'avait
  donc **aucune prise** sur cette pastille. Elle passe désormais par
  `zResolveGradient(context, zSignatureKey(...))`.

  L'arbitrage de profil externe (`zLegacyOr`) a été **retiré** : il vit dans le
  dernier maillon de `zResolveGradient` et ne gouverne que la référence. Le
  rejouer par-dessus annulait, sous le profil `neutral`, une palette que l'hôte
  avait délibérément posée par jeton ou par seam.

  **Inertie prouvée sous les deux profils** : sans seam ni jeton, la couleur
  peinte est identique à avant — dégradé de référence indexé par `titleHash`
  sous `legacy`, pastille **absente** sous `neutral` (le défaut).
  Garde : `test/presentation/z_study_unit_picker_gradient_chain_test.dart`,
  qui lit la décoration du `RenderDecoratedBox` MONTÉ.

### Supprimé

- `ZStudySessionChrome.accentColor` — champ **inerte** : résolu à chaque build
  de l'écran de session (rôle `primary`) et lu par aucun site de rendu. Retiré
  plutôt que doté d'un consommateur inventé. Sa garde locale assertait qu'il
  suivait bien le rôle du schéma, c'est-à-dire qu'elle défendait le défaut.

  ⚠️ **Rupture pour un appelant qui construisait `ZStudySessionChrome`
  directement** : le paramètre nommé `accentColor` disparaît du constructeur.
  Aucun appelant de ce type n'existe dans le dépôt (grep négatif sur
  `packages/*/lib` et `packages/*/test`). L'écran de session lui-même passe par
  `zStudySessionChromeOf`, dont la signature est inchangée.

## 3.48.0 — 2026-09-08

### Ajouté

- **Seams de présentation de la rangée de notation, relayés de bout en bout**
  (`MAJEUR`) : `ZStudySessionHost` expose `qualityLabelKeyFor`,
  `qualityColorKeyFor`, `qualityPreviewLabelFor` et `qualityEmphasis`, relayés
  tels quels à la surface de saisie par défaut, puis à `ZSrsQualityButtons`.
  Une application qui veut cinq paliers colorés avec aperçu d'intervalle n'a
  donc plus à fournir un `gradingBuilder` complet — c'est-à-dire à
  réimplémenter toute la saisie — pour changer une couleur.
  * **Précondition de montage** : `ZStudySessionHost.onQualitySelected`, neuf
    lui aussi. Mesuré avant ce lot : `grep -rn "onQualitySelected"
    packages/zcrud_study/lib` rendait **zéro** occurrence — l'assemblage
    montait une surface de saisie sans voie de notation manuelle, et la rangée
    de crans (le seul objet que les quatre seams peignent) n'entrait jamais
    dans l'arbre. Relayer les quatre seams sans cette précondition aurait
    livré quatre commandes mortes.
  * Cette voie **n'écrit rien** dans le SRS : l'écriture de révision reste la
    soumission de la carte, et elle seule (AD-33). La garde le vérifie par le
    compteur du faux `ZSessionReviewer`, avant et après le tap d'un cran.
  * `gradingBuilder` **prime** : quand l'hôte fournit son propre constructeur
    de notation, la surface par défaut n'est pas montée et les cinq paramètres
    n'ont aucun point d'application. Figé par une garde.
  * Strictement **additif**, défauts neutres : un hôte qui ne pose aucun des
    cinq paramètres obtient le sous-arbre de saisie **strictement identique**
    au montage nu de `ZFlashcardAnswerInput` (égalité de séquence, jamais
    `contains`), et la rangée de crans reste **absente** de l'arbre (AD-4).
  * Aucune valeur chromatique introduite (FR-26) : le seam relaie une **clé**
    de couleur résolue par le thème.
  * `zcrud_study` ré-exporte `ZQualityLabelKeyResolver`,
    `ZQualityColorKeyResolver`, `ZSrsQualityEmphasis` et
    `zDefaultQualityLabelKey` — un appelant de `ZStudySessionHost` les nomme
    sans second import.

## 3.47.0 — 2026-09-08

### Ajouté

- **Créneau de carte relayé jusqu'à l'hôte** (`MAJEUR`) :
  `ZStudySessionHost.cardSlotBuilder` reçoit un `ZStudySessionCardSlot` — la
  carte résolue par identité, le rang, `isFront`, l'état de révélation et la
  commande qui le bascule. Un hôte qui compose sa propre carte n'a donc plus à
  posséder ni contrôleur d'index, ni contrôleur de révélation.
  * Strictement **additif** : `cardBuilder` reste inchangé et pleinement
    supporté ; un hôte qui ne fournit pas le créneau ne voit aucun changement
    d'arbre. Le créneau **prime** sur `cardBuilder` quand les deux sont donnés.
  * `ZStudySessionCardSlot` **compose** le `ZSessionCardSlot` de `zcrud_session`
    (champ `slot`, plus les accès `item` / `index` / `isFront`) : le rang et la
    position restent définis à un seul endroit.
  * `toggleReveal` est `null` — jamais une commande inerte — sur les cartes
    empilées derrière le front, et sous une politique de révélation qui ne
    l'offre pas dans ce mode.
  * L'affordance de révélation **du socle** n'est pas rendue quand le créneau
    est fourni : l'hôte a reçu la commande et la place où il veut ; deux
    contrôles sur le même état se contrediraient à l'écran.
- **Retenue de la carte notée** (`MAJEUR`) :
  `ZStudySessionHost.postSubmitPolicy` (`ZStudySessionPostSubmitPolicy.auto` par
  défaut). En mode d'apprentissage, la carte notée ne part plus au moment de la
  notation : la réponse est dévoilée, et une action « Continuer »
  (`ZStudySessionHost.continueActionKey`, libellé
  `ZStudySessionLabels.continueAction` ou clé l10n `zcrud.session.continue`,
  cible ≥ 48 dp, `Semantics` de bouton) passe à la suivante.
  * 🔒 La voie d'écriture SRS reste **unique** (AD-9/AD-33) : la note part au
    même moment, avec la même valeur, à la soumission. Seul l'instant du
    **passage** change. La continuation n'écrit rien.
  * **Inertie totale des modes notés** : `spaced`, `list`, `test`, `whiteExam`
    et `cramming` sont inchangés — arbre identique au widget près et même
    séquence d'avance.
  * Échappatoire : `ZStudySessionPostSubmitPolicy.advance` restaure le passage
    immédiat dans tous les modes ; `hold` retient dans tous les modes.
  * Un seam SRS en échec (`Left`) ne retient rien : rien n'a été noté.
  * La **dernière** carte est retenue comme les autres — la fin de session est
    poussée à la continuation, toujours exactement une fois.

- **Révélation de la réponse portée par l'écran de session assemblé**
  (`MAJEUR`) : `ZStudySessionHost` possède désormais l'état de révélation et
  rend une action « afficher / masquer la réponse » en frère de la pile.
  * Gouvernée par `revealPolicy` (`ZStudySessionRevealPolicy.auto` par défaut) :
    l'action n'est offerte qu'en mode d'apprentissage, où voir la réponse est
    l'objet de la session. `never` la retire partout, `always` l'offre partout.
  * Libellés injectables : `ZStudySessionLabels.revealAction` / `.hideAction`
    (à défaut, clés l10n `zcrud.flashcard.reveal` / `.hide` — celles que porte
    déjà la carte de révision). Placement par
    `ZStudySessionReference.revealActionPadding`, cible ≥ 48 dp rendus.
  * L'action est **absente** dès qu'un `cardBuilder` d'hôte est fourni : la
    carte de l'hôte ne se branche pas sur la révélation de l'assemblage, et une
    commande morte coûte plus cher qu'une commande absente.
  * La révélation **n'écrit rien** : ni SRS, ni avance de pile.
  * 🔒 Invariant gardé : la révélation se **referme** au changement de carte de
    devant, et n'est branchée que sur la carte **de devant** (la pile en rend
    plusieurs).
- **Régime du rappel de question** (`MAJEUR`) : `ZStudySessionHost.questionRecall`
  (`ZStudySessionQuestionRecall.auto` par défaut). La question était rendue deux
  fois — sur la carte et au-dessus de la saisie ; sur une fenêtre étroite, les
  deux occupent la hauteur et poussent la saisie hors de l'écran.
  ⚠️ **Changement de rendu par défaut sous
  `ZStudySessionReference.narrowWidth` (600 dp)** : le rappel y devient
  **abrégé** (hauteur bornée à 96 dp, fin en dégradé). Au-dessus du seuil, rien
  ne change. Échappatoire : `questionRecall: ZStudySessionQuestionRecall.full`
  restaure exactement le rendu antérieur ; `hidden` retire le rappel.
- **Transport de l'inset bas** (`MINEUR`) : `ZStudySessionHost.bottomInset`
  (`null` ⇒ inset système, `0` ⇒ aucune réserve, l'hôte gouverne) est passé à la
  surface de saisie par défaut. Gardé : une **seule** réserve est rendue —
  l'inset est consommé pour le sous-arbre, donc aucune gouttière double.
- **`ZStudySessionView.cardSlotBuilder`** et **`.revealBuilder`** (`MINEUR`) :
  slots additifs. `cardSlotBuilder` reçoit le créneau de pile (item, rang,
  `isFront`) et **remplace** `cardBuilder` quand il est fourni ; `revealBuilder`
  est rendu entre la pile et le séparateur. `null` ⇒ comportement antérieur
  strictement inchangé.

## 3.46.0 - 2026-09-04

### Ajouté

- **Ouverture IMPÉRATIVE ancrée du menu d'actions d'item** (CR-IFFD-135,
  `MINEUR`) : `showZItemActionsMenu(context, actions:, anchorKey:, menuBuilder:,
  crossAxisCount:, renderer:, semanticLabel:)`. `ZItemActionsMenu` portait son
  propre déclencheur ; un hôte qui a DÉJÀ son bouton monté (et l'ouvrait
  impérativement par sa `GlobalKey`) devait le retirer de ses écrans pour
  router vers le socle — une réécriture non réversible qui casse un
  *strangler fig*. Il garde désormais son bouton et branche cette fonction sur
  son `onPressed`.
  ⚠️ La CR situait le widget dans `zcrud_ui_kit` : il vit dans `zcrud_study`.

  * **Composition à site UNIQUE** — la traduction actions → entrées, les cartes
    d'identité, la règle d'absence et le contenu par défaut sont factorisés
    (`_composeItemActions`) et partagés par le widget et la fonction. Aucune
    seconde composition ne peut réapparaître : garde de source dédiée
    (`cr_iffd135_composition_site_guard_test.dart`), rougie par injection R3.
  * **Rendu prouvé IDENTIQUE** — la signature de l'arbre rendu (déclencheur et
    surface) est figée sur le code antérieur à la factorisation et comparée en
    égalité stricte ; la surface ouverte par la voie impérative rend la MÊME
    liste de widgets que celle du déclencheur porté.
  * **Géométrie** — le point d'ancrage est un COIN du bord haut de l'ancre,
    celui du côté vers lequel la surface grandit (bord de départ, bord de fin
    quand l'ancre est plus proche du bord de fin de l'écran, la directionnalité
    départageant l'ancre centrée). Mesuré par `getRect` sur les six
    configurations *placement × directionnalité* : le rectangle rendu est
    **égal** à celui du déclencheur porté. Un simple coin haut-gauche divergeait
    de 40 à 232 dp (mesuré).
  * **AD-10** — ancre non montée / détachée / non mesurée, contexte démonté,
    rien à montrer : aucune surface, aucune levée. Aucun `assert` sur l'ancre
    (une ancre démontée est une course, pas une erreur de programmation) ; le
    nom accessible manquant, lui, reste asserté en debug.

## 3.45.0 - 2026-09-04

### Ajouté

- **Créneau de rendu des champs texte du formulaire de carte de
  `ZMultiFlashcardEditor`** (CR-IFFD-134, `MINEUR`). L'écran legacy IFFD que ce
  multi-éditeur remplace déclarait question et réponse en `inlineMarkdown`
  (éditeur riche : formules, tableaux) ; le multi-éditeur ne rendait que des
  champs de texte simples, via une méthode PRIVÉE (`_field`) sans aucun point
  d'injection — l'hôte gardait donc son écran legacy allumé.
  Nouvelle surface publique : `ZFlashcardEditorField` (discriminant),
  `ZFlashcardFieldSlot` (contexte remis au slot), `ZFlashcardFieldBuilder`
  (fabrique) et le paramètre `ZMultiFlashcardEditor.fieldBuilders`. **Aucune
  dépendance d'édition riche n'entre dans `zcrud_study`** : le paquet ne fournit
  qu'un créneau, l'hôte y branche son propre éditeur.
  **Écart assumé par rapport au texte de la CR** : la CR proposait la signature
  `(BuildContext, TextEditingController, String label)`. Elle a été refusée
  telle quelle — sans discriminant, une application qui partage une fabrique
  entre plusieurs champs devrait comparer des **libellés LOCALISÉS** pour savoir
  quel champ elle rend. Le slot porte donc `field`, stable et indépendant de la
  langue, et il porte aussi `onEditingComplete` (la voie de fin de saisie que le
  champ par défaut possédait et que l'hôte aurait sinon perdue).

### Corrigé

- **La saisie faite dans un widget injecté n'aurait rien publié** — défaut que
  la CR ne voyait pas. `_notify()` n'était appelé que par `onChanged` /
  `onEditingComplete` du `TextField` ; un éditeur riche injecté aurait écrit
  dans le controller sans que la carte n'en sache rien, et la saisie de
  l'utilisateur aurait été perdue **silencieusement** au commit groupé.
  L'état écoute désormais le controller de chaque champ **rendu par un slot**,
  et lui seul : le chemin par défaut reste non écouté (l'écouter doublerait la
  notification à chaque frappe). L'écoute est réalignée quand la table de slots
  change et retirée au `dispose`.

### Inchangé (garde d'inertie)

- Sans aucun slot, le formulaire de carte est rendu **à l'identique** : liste
  figée des enfants de sa colonne, quatre `TextField` aux mêmes clés, libellés
  et alignements, et **aucune écoute** posée sur leurs controllers.

## 3.44.0 — 2026-08-30

### Ajouté

- **`ZFolderGridReference` — les quatre nombres de la grille de dossiers, au
  socle** (CR-LEX-93, `MINEUR`). Les deux hôtes réécrivaient à l'identique
  `minItemWidth` **300** / **350** au-delà du palier, `cellHeight` **250**,
  `spacing` **8** ; IFFD réécrivait en plus le seuil **840** que
  `zcrud_responsive` porte déjà (`ZWindowSizeThresholds.expandedMinWidth`).
  Valeurs relevées sur `main` d'IFFD, `folders_page.dart:450` (largeurs et
  palier), `:648-649` (espacements), `:652` (hauteur de cellule) — le même
  triplet 300/350/840 se relit sur six autres pages du même hôte, c'est une
  convention, pas un réglage d'écran.
  **Aucun widget de grille n'a été ajouté** : `ZAdaptiveGrid` couvre déjà le
  besoin, la référence n'expose que des jetons et `minItemWidthFor(width)`,
  qui applique le palier du socle. La dartdoc du fichier montre l'expression
  d'usage exacte. Fichier de référence **sans aucune couleur** : comme
  `ZFolderCardReference`, il n'est **pas** inscrit dans l'exemption nominative
  de la garde anti-couleurs, et une garde vérifie qu'il ne l'est pas.
- **`ZFolderCard.bodyPlacement` / `ZDefaultFolderCard.bodyPlacement`** —
  répartition verticale du contenu en cellule haute (CR-LEX-94, `MINEUR`).
  `ZFolderCardBodyPlacement.top` rend pastille, titre et sous-titre solidaires
  en haut et déplace le vide sous ce bloc ; `bottom` reste le **défaut**.

### Note d'impact

- **CR-LEX-94 est OPT-IN, et c'est une décision mesurée.** Le vide entre la
  pastille et le titre ne venait pas du `const Spacer()` de
  `z_folder_card.dart:403` (celui-ci est **horizontal**, dans la `Row` du pied,
  et n'est rendu que sans `counts` ni `footer`) mais du patron anti-overflow
  `Expanded(Align(bottomStart))` du régime borné. Basculer cet ancrage
  changerait le rendu de **toute** cellule de grille chez **tout** hôte :
  mesuré en cellule de 250 dp, l'écart pastille→titre passe de **144 dp** à
  **0**, et les 148 dp de vide descendent sous le sous-titre. Le paramètre
  laisse donc le défaut intact — un hôte passif rend le pixel d'avant, en
  cellule bornée comme à hauteur libre — et l'hôte qui veut la répartition de
  référence la demande. À hauteur non bornée, les deux valeurs rendent le même
  pixel : sans hauteur résiduelle, il n'y a rien à répartir.
- **Hôtes ayant contourné** : IFFD et lex peuvent retirer leurs quatre nombres
  de grille et, pour IFFD, son `840` littéral, au profit de
  `ZFolderGridReference`. Retirer un contournement de répartition verticale
  (pied recomposé à la main pour remonter le titre) suppose en revanche de
  passer `bodyPlacement: top` — sinon le vide revient.

### Interne

- La garde `z_subfolder_nav_source_guard_test` bannissait `ZWindowSizeThresholds`
  **en entier** hors de `z_subfolder_nav.dart`, alors qu'elle ne défend que le
  seuil de bascule des sous-dossiers (`mediumMinWidth`, 600). Le motif vise
  désormais `ZWindowSizeThresholds.mediumMinWidth` : la famille grille de
  dossiers peut consommer `expandedMinWidth` sans réécrire son seuil en
  littéral — ce que la garde elle-même combat. Contre-preuve rejouée : un
  second site de `mediumMinWidth` la fait toujours rougir.

## 3.43.0 — 2026-08-30

### Corrigé

- **La bande en dégradé retrouve sa géométrie directionnelle** (CR-LEX-92,
  `MINEUR`, invariant AD-13). `ZDefaultFolderCard` rendait le `ZGradientSpec`
  **verbatim** (`BoxDecoration(gradient: signature.gradient)`) pendant que
  `ZFolderCardGradientAccent` appliquait, lui, `ZcrudTheme.gradientBegin` /
  `gradientEnd` : deux chemins divergents dans le même paquet. Un
  `LinearGradient` construit sans `begin`/`end` porte les défauts **non
  directionnels** de Flutter (`Alignment.centerLeft` / `centerRight`) : le
  dégradé cessait de se miroiter en RTL et les deux jetons de thème étaient
  morts sur ce chemin, sans un avertissement. Symptôme mesuré par l'hôte à
  l'adoption : `Expected AlignmentDirectional.centerStart, Actual
  Alignment.centerLeft`.

  La composition vit désormais à **un seul endroit**
  (`z_gradient_geometry.dart`, garde de source) et sert les **cinq** surfaces
  qui rendaient un `ZGradientSpec` : la bande de `ZDefaultFolderCard`,
  `ZFolderCardGradientAccent`, le segment « appris » de `ZFolderProgressBar`,
  la pastille de `ZStudyUnitPicker` et la bande + la puce de type de
  `ZDefaultFlashcardCard`.

  **Borne de détection assumée** : `ZGradientSpec` ne porte pas de `begin`/`end`
  propres — « non déclaré » n'est donc distinguable que par égalité aux défauts
  du constructeur Flutter. Les jetons sont appliqués à cette seule condition ;
  toute autre géométrie est celle de l'appelant et n'est jamais écrasée
  (précédence paramètre > jeton). Un appelant qui veut réellement un dégradé
  figé gauche→droite dans les deux sens de lecture ne pose pas les jetons.

  **Inertie** : sans `gradientBegin`/`gradientEnd`, la décoration rendue est
  **strictement identique** à la 3.42.0 (garde d'égalité stricte sur le
  `BoxDecoration`). Seul changement de comportement pour un hôte déjà équipé :
  `ZFolderCardGradientAccent` écrasait jusqu'ici **toute** géométrie déclarée
  par le résolveur, y compris explicite ; elle est maintenant respectée.

## 3.42.0 — 2026-08-30

### Corrigé

- **Une navigation de fratrie SANS DESTINATION n'occupe plus la place**
  (CR-LEX-90, `MAJEUR`). `ZSubfolderNavSpec.subfolders` vide ⇒ **aucune surface
  n'est montée**, sous aucun `ZSubfolderNavPlacement` et à aucune largeur : ni
  barre latérale, ni surface étroite, ni bande hissée, ni hauteur réservée dans
  l'app-bar.

  Mesuré sur disque **avant** correction, écran 600 × 800, spec
  `subfolders: []` :

  | placement | avant | après |
  |---|---|---|
  | `withinTab` @600 | corps `LTRB(300, 104, 600, 800)` — 300 dp mangés par une barre latérale à zéro item | `LTRB(0, 104, 600, 800)` |
  | `withinTab` @400 | corps `LTRB(0, 152, 400, 800)` — 48 dp de bande vide | `LTRB(0, 104, 400, 800)` |
  | `aboveTabs` @600 | bande `LTRB(0, 104, 600, 152)` | absente |
  | `aboveTabBar` @600 | app-bar 152 dp | 104 dp |

  Symptôme de l'hôte rejoué en garde : une grille à `maxCrossAxisExtent: 320`
  tenait **une** colonne sur les 300 dp restants, elle en tient de nouveau
  **deux** sur 600 dp.

  La borne est publiée : `zSubfolderNavHasDestinations(spec)` — elle mesure
  `subfolders`, et **rien d'autre**. Un `allSubfoldersLabel` seul ne fait pas une
  destination : mesuré, l'item racine n'y désigne que ce qui est déjà affiché et
  le choisir est un no-op. Conséquence assumée et gardée : sans destination,
  l'affordance d'ajout portée par la navigation (`ZSubfolderNavSpec.addAction`,
  quel que soit son `addPlacement`) est absente elle aussi — la création du
  *premier* sous-dossier relève de l'app-bar, du hub de contenu ou de l'état vide
  du corps.

  Inertie stricte avec des sous-dossiers : géométrie des trois placements figée
  sur un relevé pris **avant** la correction (400 et 600 dp).

### Ajouté

- **`ZStudyFolderDetail.notebookTabBuilder` / `.progressionTabBuilder`** et le
  typedef **`ZStudyTabBuilder`** — le contrat de `materialSectionsBuilder`
  (`(BuildContext, String? selectedSubfolderId)`) porté aux deux autres onglets
  (CR-LEX-91, `MAJEUR`). Le conteneur détient la sélection et la fait évoluer par
  sa propre navigation ; jusqu'ici seul l'onglet Matériel la recevait, et un
  écran dont le Bloc-notes filtre par sous-dossier restait figé sur le périmètre
  du montage — deux onglets désynchronisés, sans qu'aucun test ne rougisse.

  **Forme retenue : paramètres distincts, pas de changement de signature.** Dart
  n'admet pas deux signatures sur un même nom ; retoucher `notebookBuilder` /
  `progressionBuilder` aurait cassé tous les hôtes. Les nouveaux paramètres
  **priment** quand les deux sont fournis, et les anciens restent supportés — ils
  rendent à l'identique (goldens de rect relevés avant correction) et **ne
  reçoivent toujours rien** de la navigation, contrat historique conservé.
  `notebookBuilder` devient optionnel : un `assert` exige l'une des deux formes,
  et le chemin release retombe sur un onglet vide plutôt que sur une exception
  (AD-10).

  Les builders portés sont invoqués **dans la même tranche réactive** que le
  corps Matériel (`ValueListenableBuilder<String?>` sur l'état unique de
  sélection) : les trois voient donc toujours la même valeur, et un changement de
  fratrie ne reconstruit que le corps de l'onglet visible (AD-2/SM-1).

## 3.40.0 — 2026-08-30

### Ajouté

- **`ZStudyFolderDetail.tabAlignment`** et **`ZStudySessionScaffold.tabAlignment`**
  — relais du paramètre homonyme de `ZPageScaffold` (donc de
  `TabBar.tabAlignment`), jusqu'ici **avalé** par les deux conteneurs
  (CR-LEX-88, `MINEUR`). `null` (défaut) ⇒ **rien n'est déclaré** : le rendu est
  strictement inchangé — garde d'inertie par comparaison de la signature
  structurelle d'app-bar au relevé pris **avant** l'ajout du relais.

  Ce que le relais débloque, mesuré : la barre d'onglets du socle est toujours
  défilante, donc Flutter y résout `TabAlignment.startOffset`, qui réserve
  **52 dp** de décrochage avant le premier onglet. Sur un viewport de 600 dp
  avec trois libellés (« Matériel » / « Carnet de notes » / « Progression
  détaillée »), le centre du troisième onglet tombe à **604,35 dp** — hors des
  bornes : un geste qui le vise n'atteint pas sa cible. `TabAlignment.start`
  ramène ce centre à **552,35 dp** et l'onglet redevient atteignable. Les deux
  bornes sont figées dans les gardes.

  `isScrollable` n'est **pas** relayé : `ZPageScaffold` ne l'expose pas — le
  socle de page le fixe à `true` pour toutes ses barres. Un conteneur ne peut
  pas relayer un paramètre que le shell n'a pas.

## 3.39.0 — 2026-08-30

### Ajouté

- **`ZSubfolderNav`** — la **bascule responsive** de navigation de sous-dossiers
  devient un widget autonome, utilisable **hors** de `ZStudyFolderDetail`
  (CR-LEX-87, `MAJEUR`). Les deux surfaces existaient déjà
  (`ZSubfolderNarrowNav` sous le seuil, `ZSubfolderSidebar` au-dessus) ; ce qui
  manquait était **la règle qui choisit entre elles**, jusqu'ici enfermée dans
  l'ossature. Mesuré chez deux hôtes : chacun l'avait réécrite, au même seuil,
  le second ayant dû ouvrir le dépôt du premier pour retrouver la valeur.
  - `LayoutBuilder` sur la largeur **locale** (jamais `MediaQuery`/écran) — bonne
    disposition en split-view, master-detail ou colonne de `Row`.
  - Seuil par défaut = `ZWindowSizeThresholds.mediumMinWidth`, exposé en
    `kZSubfolderSidebarBreakpoint` et surchargeable par `sidebarBreakpoint`.
  - **Exclusivité structurelle** : les builders sont paresseux, la variante
    écartée n'est pas construite — jamais deux filtres concurrents sur la même
    sélection.
  - `bodyBuilder` fourni ⇒ assemblage `Column`/`Row` rendu par le socle ;
    `bodyBuilder` absent ⇒ la variante est rendue **seule**, pour un appelant qui
    tient déjà sa coquille.
- **`zSubfolderNavPrefersSidebar(width, {breakpoint})`** — la règle sous forme de
  **fonction pure**, source unique de la comparaison au seuil.

### Modifié

- `ZStudyFolderDetail` **consomme** désormais `ZSubfolderNav` au lieu de porter
  sa propre bascule (`ZResponsiveLayout` + assemblage). La règle n'existe donc
  plus qu'à **un** endroit. **Rendu strictement inchangé** : les signatures
  d'arbre des deux assemblages ont été relevées AVANT l'extraction, figées en
  dur, et sont vertes après — bornes 599/600/601 comprises.

### Gardes

- Inertie d'arbre de `ZStudyFolderDetail` : signature structurelle figée aux deux
  côtés du seuil + borne exacte 599/600/601.
- `ZSubfolderNav` seul : exclusivité aux deux largeurs (une variante montée,
  l'autre **ni montée ni construite**), seuil personnalisé honoré avec
  contre-preuve au seuil par défaut, rendu sans corps, neutralité LTR/RTL.
- Gardes de source (`@TestOn('vm')`) : le seuil n'est **nommé** qu'au site de la
  règle, la comparaison de largeur n'existe qu'à **un** endroit de la famille
  nav, aucun littéral `600` dans cette famille (FR-26), plus une contre-preuve
  que la garde de littéral mord.

## 3.38.0 — 2026-08-30

### Ajouté

- **`ZDefaultFolderCard.accentGradient` et `ZDefaultFolderCard.gradientKey`** —
  le dégradé de bande devient une décision **indépendante** de la couleur du
  dossier (CR-LEX-86, `MAJEUR`). Jusqu'ici, déclarer une couleur (`colorKey`,
  ou un `ZcrudScope.colorKeyResolver` qui répond pour cette identité) mettait
  le dégradé de signature à `null` : la carte était colorée mais **plate**, et
  ne rien déclarer donnait le dégradé mais perdait la couleur de l'utilisateur.
  Les deux ne coexistaient pas — cause pour laquelle **deux hôtes indépendants**
  avaient abandonné la carte par défaut et recomposé sa bande à la main.
  - Précédence de la bande : `accent` (widget rendu verbatim) >
    `accentGradient` > `gradientKey` (résolue au seam de l'hôte) > repli de
    signature (**uniquement** sans couleur déclarée) > bande unie dérivée de la
    couleur.
  - Partage des rôles quand les deux coexistent : la **couleur déclarée** pilote
    la matière (tuile d'icône, badges, sous-titre, liseré), le **dégradé** pilote
    la bande. Sans couleur déclarée, la matière suit la **tête** du dégradé —
    le rendu du repli de signature, inchangé.
  - Le plancher de contraste reste **mesuré** sur la surface réellement peinte
    (`zReadableTintOn`) pour la matière ; le dégradé, lui, est peint tel quel
    avec le `onGradient` choisi par l'appelant.

### Gardes

- Nouveau fichier `test/presentation/cr_lex86_folder_card_gradient_test.dart`
  (11 gardes, chacune rougie par assertion sous injection R3) : inertie absolue
  sans les nouveaux paramètres (arbre complet, rects et couleurs peintes figés à
  l'octet depuis un relevé pris **avant** la modification) ; coexistence
  dégradé + couleur ; comportement défini d'un dégradé sans couleur ; les quatre
  niveaux de précédence ; clé vide ou seam muet inertes (AD-10) ; planchers WCAG
  recalculés (4.5 badges/sous-titre, 3.0 liseré).
- `test/appearance_c_test.dart` : les deux gardes de préséance de la couleur
  choisie sont **ré-ancrées** — elles figeaient « couleur déclarée ⇒ jamais de
  dégradé », propriété devenue fausse dès qu'un dégradé est explicitement
  demandé. Elles affirment désormais l'absence du **repli de signature**, et
  seulement sans demande explicite. Aucune n'a été affaiblie.

### Migration

- **Hôte passif** : rien à faire, rien ne bouge — l'inertie est gardée à l'octet.
- **Hôte qui avait contourné** (bande recomposée à la main par-dessus la
  primitive, ou app-side) : la composition externe peut être **retirée** et
  remplacée par `accentGradient`/`gradientKey` sur `ZDefaultFolderCard`. La
  laisser en place **s'additionnerait** désormais à la bande native.

## 3.34.0 — 2026-08-29

### Modifié

- 🔴 **Le défaut du socle devient `ZReferenceProfile.neutral`** (décidé dans
  `zcrud_core`). Sans profil déclaré, ce paquet rend ce qu'il rendait avant le
  lot d'apparence des cartes :
  - `ZDefaultFolderCard` d'un dossier **sans couleur choisie** : bande **unie**,
    plus de repli sur le dégradé de signature ;
  - en-têtes de `ZSectionedStudyLayout` : ni bande d'accent de 3 dp ni tuile
    d'icône 36/rayon 10 — le glyphe reste nu ;
  - `ZSubfolderAccentPastille` : `signatureIdentity` est ignorée ;
  - `ZStudyUnitPicker` : la pastille d'identité n'est pas montée.
- Une couleur **choisie** (`colorKey`), un résolveur d'hôte
  (`ZcrudScope.colorKeyResolver` / `gradientResolver`) et les jetons de thème
  s'appliquent inchangés dans les deux profils : seul le dernier maillon —
  la référence auditée — est arbitré.
- L'habillage complet reste disponible par
  `ZcrudScope(theme: ZcrudTheme(referenceProfile: ZReferenceProfile.legacy))`.

### Tests

- Nouveau groupe « 🔴 le DÉFAUT du socle est le rendu d'avant le lot
  d'apparence » (`test/appearance_c_test.dart`) : en-tête, carte de dossier et
  pastille mesurés **sans aucun profil déclaré**, chacun avec sa contre-preuve
  sous `legacy` explicite — aucune garde ne peut devenir vacante si les deux
  profils convergeaient.
- Les gardes de l'habillage de référence déclarent `legacy` explicitement ;
  leurs assertions (rects, rayons, ombres teintées, dégradés exacts) sont
  conservées à l'identique.
- Tripwire visuel `test/golden/goldens/study_tools_sectioned.png` **re-figé sur
  le rendu neutre** : le harnais golden est zéro-config (aucun `ZcrudScope`),
  il fige donc le défaut du socle. Le rendu `legacy` reste gardé par des
  assertions de rects, jamais par comparaison de pixels.

## 3.33.0 — 2026-08-29

### Ajouté
- `ZStudySharingReadPort` — port **compagnon** de lecture de la galerie
  publique : `watchPublicFolders({ZDataRequest? request})` (flux **nu**,
  pagination par le `ZDataRequest` neutre du socle),
  `publicFolderById(String)` rendant `ZResult<ZPublicStudyFolder?>`
  (`Right(null)` = non publié, distinct d'un `Left`), et `isAvailable` pour
  couper la lecture à chaud. Inerte fourni : `ZInertStudySharingReadPort`
  (`const`).
- `ZStudySharingAdminPort` — port **compagnon** d'administration :
  `revokeMembership(String membershipId)`,
  `setJoinableByLink(String folderId, bool value)`,
  `setMembersCanInvite(String folderId, bool value)` (tous
  `Future<ZResult<Unit>>`), plus `isAvailable`. Inerte fourni :
  `ZInertStudySharingAdminPort` (`const`).
- `ZPublicGalleryView.readPort` / `.readRequest` : la galerie sait
  s'alimenter seule. Le flux `folders` devient **optionnel** et reste
  **prioritaire** quand les deux voies sont fournies ; le flux du port est
  abonné **une seule fois** (un rebuild ne réabonne pas).
- `ZFolderSharingSheet.adminPort` : la révocation d'adhésion et les deux
  interrupteurs de partage existent désormais **par port OU par callback**.
  Le callback historique (`onRevokeMembership`, `onSetJoinableWithLink`,
  `onSetMembersCanInvite`) **prime** quand les deux sont présents.

### Modifié
- Les interrupteurs de partage portent un **verrou d'occupation par
  interrupteur** : une seconde bascule pendant l'appel en vol n'émet plus un
  second appel.

### Notes de compatibilité
- **Aucune méthode n'a été ajoutée à `ZStudySharingPort`** : un implémenteur
  de ce contrat n'a **rien** à changer. Les capacités neuves vivent dans des
  ports compagnons **additifs**, consommés seulement s'ils sont fournis et
  `isAvailable`.
- Un hôte qui **compensait** un de ces manques (flux de galerie câblé à la
  main, callbacks de révocation ou de drapeaux) garde son comportement à
  l'octet : sa voie prime. Il peut migrer vers un compagnon à son rythme —
  mais **fournir les deux ne double aucun appel**, le callback l'emporte.
- Portail fail-closed inchangé : une ACL refusante refuse les deux surfaces,
  compagnons fournis ou non.

## 3.31.0 — 2026-08-29

### Ajouté
- `ZStudyUnitPicker` : sélecteur **arborescent** des conteneurs de structure
  d'étude (organisations, unités, groupes, programmes…). Il reçoit une **valeur
  immuable** — une forêt de `ZStudyUnitNode` (`ZStudyRef` + enfants) — et rend la
  `ZStudyRef` **exacte** par `onSelect` : aucun port, aucun dépôt, aucun flux, et
  donc rien à câbler côté hôte au-delà de la donnée qu'il possède déjà. Rangées
  **virtualisées** (`ListView.builder`), indentation strictement égale à
  `depth × indentWidth`, recherche locale sur libellé et code, pastille de la
  palette signature sous le profil `legacy` (rien sous `neutral`), icône dérivée
  de `ZStudyKindSpec.iconKey` via le seam d'icônes du socle. Une ontologie
  fournie décide de **deux** choses seulement : l'icône, et le fait qu'un `kind`
  déclaré **sans** la capacité `hierarchical` soit rendu **feuille** (ni
  affordance de dépliage, ni enfant peint).
- `ZStudyPathBar` : fil d'Ariane d'un `ZStudyContext`, **snapshot-first** — les
  libellés viennent des instantanés portés par les `ZStudyRef`, sans aucune
  résolution ni lecture au rendu. Les segments sont exactement
  `ZStudyContext.refs` (l'ordre déclaré par le noyau, racine d'abord) ; chaque
  segment est tapable et rend sa référence exacte. Séparateurs **directionnels**
  (ils basculent en RTL) et débordement en menu par `maxVisibleSegments` — les
  derniers segments restent peints, les premiers passent dans le menu et y
  rendent la même référence.
- `ZStudyScopeBar` : la portée courante en **puces retirables**, une par valeur
  de chaque axe du `ZStudyScopeFilter` (portées, périodes, offres, matières,
  cours, thèmes). Retirer une puce appelle `onScopeChanged` avec le filtre
  **réduit exact** — les autres axes et `includeDescendants` restent inchangés.
  Un filtre vide ne monte rien du tout.
- `zFilterByScope` : application d'un `ZStudyScopeFilter` à une liste d'écran,
  par délégation à `zMatchesScopeFilter` du noyau. Rend **l'instance reçue**
  (`identical`) quand le filtre est `null`, vide, ou quand aucune projection
  n'est fournie.
- `ZFlashcardListView` gagne quatre paramètres **additifs** — `scopeFilter`,
  `scopeArtifactOf`, `scopeSnapshot`, `scopeAt` — appliqués **après** les filtres
  de recherche et **avant** le tri, là où les cartes sont déjà filtrées ; aucun
  dépôt n'est touché.

### Contrat
- 🔴 **La structure académique n'est pas l'arborescence des dossiers.** Le
  sélecteur sert au **rattachement** et à la **portée** — jamais à ranger des
  dossiers. Il ne **modifie** rien : créer, renommer ou déplacer une unité
  n'est pas de son ressort.
- Une flashcard ne porte **aucun** rattachement à la structure : `scopeFilter`
  n'est applicable que si `scopeArtifactOf` dit où le lire. Sans cette
  projection, le paramètre est **inerte** et la liste est rendue à l'identique —
  le socle n'invente pas un rattachement que la donnée ne porte pas. Sous un
  filtre non vide **et** avec projection, une carte dont la projection rend
  `null` est écartée : elle n'est dans aucune portée.
- Sans instantané de structure, seule la portée **exacte** est reconnue :
  `includeDescendants` n'étend une portée que là où l'instantané connaît
  l'arbre.
- Un nœud sans libellé ni code affiche son **identifiant** : le socle n'invente
  aucun libellé et n'en traduit aucun (`labelBuilder` permet de décider
  autrement).

## 3.30.0 — 2026-08-29

### Ajouté
- `ZAiExplanationStreamPort` : pendant **progressif** du seam d'explication,
  contrat SÉPARÉ et optionnel (`Stream<ZResult<ZGenerationProgress>>
  explainStream(request)` — flux NU, jamais enveloppé dans un `Future`) plus un
  `isAvailable` qui permet de couper le progressif à chaud sans retirer le port
  de l'arbre. `ZAiExplanationPort` (one-shot) reste **inchangé** : un hôte qui
  n'implémente pas le progressif garde exactement le comportement qu'il avait.
- `ZGenerationProgress {text, isDone}` : avancement immuable dont le `text` est
  **cumulatif** (jamais un delta) — deux consommateurs ne peuvent pas diverger
  sur l'accumulation, et un événement rejoué ne décale pas le rendu.
- `ZInertAiExplanationStreamPort` : port progressif inerte `const`
  (indisponible, flux vide qui se termine — jamais une exception ni une attente
  infinie).
- `ZAiExplanationRequest.style` / `.operation` / `.routeId` (+ `withOperation`,
  `withRouteId`) : trois champs additifs, tous `null` par défaut. Ce sont des
  **clés opaques du vocabulaire de l'hôte**, transportées verbatim ; le socle
  n'en déclare, n'en compare et n'en interprète aucune. `routeId` porte
  l'intention de route au même rang que l'endpoint unique.
- `ZExplanationController` : `ChangeNotifier` pur, statut en enum
  `idle → generating → ready | empty | failed`, **historique de versions en
  mémoire** (`versions` non modifiable, `currentIndex`, `select`/`undo`/`redo`),
  jeton de fraîcheur monotone, anti-double-soumission. Choisit le port de FLUX
  quand il est fourni et disponible, sinon la voie one-shot — le choix est fait
  à chaque génération, jamais figé à la construction.
- `ZExplanationController.streamingText` : tranche `ValueListenable<String>` du
  texte cumulé. Les fragments **ne passent pas** par `notifyListeners` : seule
  la tranche est notifiée (rendu progressif sans reconstruire la surface,
  AD-2).
- `ZExplanationOperationKeys` / `ZExplanationMessages` /
  `ZExplanationVersion` : clés d'opération et messages **injectés**. Une clé
  absente rend le traitement indisponible — méthode sans effet, commande
  absente de l'arbre.
- `ZExplanationView` : rendu de la version courante par le slot injecté
  `contentBuilder` (aucun moteur de rich-text tiré ici), barre de traitements,
  sélecteur de versions sobre, handoff `onPersist` remettant une
  `ZStudyExplanation` **construite mais jamais enregistrée**. Le choix de style
  passe par `ZActionMenu` — la couture de menu partagée, jamais un menu
  reconstruit sur place.
- `ZExplanationStyleOption` / `ZExplanationLabels` : options de style et
  libellés injectés, tous requis (FR-26).
- `ZExplanationStreamScope` : injection Flutter-native d'un port progressif
  optionnel.
- `ZStudyToolsSectionSpec.icon` : glyphe de TÊTE d'un en-tête de section
  (jamais celui d'une action). `null` ⇒ aucun glyphe, aucune tuile.
- `ZSubfolderAccentPastille.signatureIdentity` : identité de repli alignant la
  pastille sur la tête du dégradé de signature du dossier correspondant.
  `null` ⇒ rendu strictement inchangé.
- `ZStudyEmptyStateReference` / `ZStudyContentNature` /
  `zStudyEmptyStateSpecFor` : table de référence des états vides d'étude par
  nature de contenu (six natures, glyphes et tailles de référence, clés de
  libellé **opaques** résolues par l'hôte). `null` pour une nature inconnue —
  l'appelant garde alors le rendu qu'il avait. Fichier **sans aucune couleur**,
  donc hors de l'exemption nominative de la garde anti-couleurs.
- `ZStudyCardReference.sectionAccentHeight` (3), `.sectionIconTileSize` (36),
  `.sectionIconTileRadius` (10), `.tintedShadowAlpha` (0.4),
  `.tintedShadowBlurRadius` (20), `.tintedShadowOffset` (0, 8) — scalaires
  seuls ; la teinte de l'ombre vient du dégradé courant, jamais d'un littéral.
- `ZFolderSharingSheet` : feuille de partage d'un dossier montée sur le port
  `ZStudySharingPort` — qui n'avait, jusqu'ici, **aucun consommateur en
  présentation**. Elle assemble le lien révocable (création, révocation
  monotone, remise du jeton à l'hôte pour la copie), les adhésions (flux NU
  rendu par une liste virtualisée, octroi, révocation remise à l'hôte) et la
  publication/dépublication en galerie. Chaque geste porte son verrou
  d'occupation (une seconde pression n'émet pas un second appel) et consomme
  son `Either` : un `Left` alimente l'aire annoncée (`liveRegion`) et le canal
  `onFailure`, en laissant l'état INTACT — jamais une exception, jamais un
  interrupteur qui ment (un mutateur de drapeau en échec revient à son état
  antérieur).
- `ZPrincipalResolver` : la saisie d'invitation (identifiant, adresse, alias)
  n'est **jamais interprétée par le socle** — elle est remise verbatim au
  résolveur de l'hôte, et `grantMembership` reçoit exactement la valeur
  RENDUE, jamais ce qui a été tapé. Sans résolveur, la surface d'invitation
  est absente de l'arbre.
- `ZPublicGalleryView` : galerie des dossiers publiés, rendue par
  `ListView.builder` sur les cartes d'item du paquet, avec « rejoindre »,
  « copier » et — seulement si un `ZStudyModerationPort` est fourni —
  « signaler ».
- `zSharingAccessGranted`, `ZStudySharingActions`, `zFeatureKeyFolderSharing`,
  `zFeatureKeyPublicGallery` : portail **fail-closed** des deux surfaces —
  disponibilité (`ZFeatureAvailability`) ET autorisation (`ZAcl` lue sur le
  `ZcrudScope`, **absence de scope ⇒ refus**), sur des clés d'action LIBRES
  qu'une ACL fermée refuse d'office. Un refus rend un état « accès refusé »
  ANNONCÉ, jamais une surface vide ni un masquage silencieux.
- `zFolderSharingItemAction` / `zPublicGalleryItemAction` : entrées de menu
  rendues `null` — donc rien dans l'arbre — tant qu'il manque un glyphe, un
  libellé, un geste ou l'accord du portail.

- `ZFolderProgressSummary` + `zSummarizeFolderProgress(cards, infos, now:)` :
  agrégat **pur** des trois seaux SRS d'un dossier (`learned` / `toReview` /
  `toLearn` / `total` / `ratio`), immuable et porteur de `==`. Le calcul
  **délègue** la partition à `zCategorize` (`zcrud_flashcard`) et n'écrit
  aucune condition SRS de son côté : `toLearn` est `neverLearned.length`,
  `toReview` est `due.length`, `learned` est le reste. Il n'y a volontairement
  pas de paramètre de configuration SRS — en ajouter un obligerait à
  recalculer les seaux autrement, c'est-à-dire à créer la seconde formule que
  ce contrat exclut. Gardé par une garde de source (grep négatif sur
  `repetitions` / `nextReviewDate` / `isAfter` dans le corps) et par un
  vecteur figé de 20 cartes (8 / 5 / 7).
- `ZFolderProgressBar` : barre segmentée qui consomme la **valeur** agrégée —
  jamais les cartes, jamais les états SRS, jamais un flux. Le legacy
  recalculait ces comptes à chaque `build` depuis les flux ; une garde compte
  désormais les appels du calculateur pendant 25 reconstructions et exige
  **exactement 1**. Un seau à zéro est **absent** de l'arbre ; sans libellé,
  aucune légende n'est rendue ; avec libellés, les comptes sont dits en texte
  (la couleur n'est jamais seul canal). Segment « apprises » en dégradé de
  signature quand une `gradientIdentity` est fournie — l'arbitrage
  référence/neutre reste celui du résolveur du cœur.
- `ZSubjectChip(ref:, resolver:)` : puce de **matière** — premier consommateur
  de `ZStudySubjectRef`. Le libellé embarqué (snapshot) s'affiche **sans
  aucune résolution** ; le résolveur est optionnel et, quand il répond `Right`,
  met le libellé à jour. Un `Left`, une levée du résolveur, une réponse
  tardive après démontage ou un identifiant vide sont sans effet : la puce
  reste au snapshot, ou reste absente si le snapshot n'a pas de libellé. La
  puce n'affiche **jamais** l'identifiant opaque à défaut de libellé.
- `ZDefaultFolderCard.subjectRef` / `.subjectLabelResolver` : deux paramètres
  additifs. Sans matière déclarée, l'arbre rendu est **strictement égal** à
  celui d'avant (garde d'égalité de signature d'arbre, avec contre-preuve).
- `ZDefaultExamCard.now` / `.pastLabel` + `kZDefaultExamPastOpacity` : variante
  « passé » de la tuile d'examen. La règle de date est celle de `ZExam.isPast`
  (aucune seconde règle écrite ici) et l'horloge est un **paramètre** — sans
  `now`, la variante est hors service et la carte rend l'arbre d'avant, même
  sur un examen échu. L'atténuation est une **opacité**, jamais une couleur
  sémantique inventée, et l'état est dit **en texte** par une puce au libellé
  injecté, reprise dans l'annonce sémantique.

### Modifié — apparence de référence (rupture VOULUE sous profil par défaut)
- **Carte de dossier par défaut** : quand AUCUNE couleur n'est déclarée (ni
  `colorKey`, ni réponse du résolveur de couleurs de l'hôte pour cette
  identité), la bande d'accent peint le **dégradé de signature** de l'identité
  du dossier au lieu d'une teinte unie, et la matière de la carte (tuile,
  badges, sous-titre) suit la tête de ce dégradé. Une couleur **déclarée**
  prime toujours et rend exactement comme avant.
- **En-têtes de section d'étude** (`ZSectionedStudyLayout`,
  `ZSectionedStudySliver`) : bande d'accent de 3 dp au-dessus de la ligne
  d'en-tête, colorée par la palette signature indexée sur le titre ; une
  section à glyphe gagne une tuile 36 × 36 au rayon 10, lavée du dégradé et
  portant une ombre teintée. Mêmes défauts que les en-têtes de section de
  `DynamicEdition`.
- Échappatoire unique, prouvée par gardes d'inertie à deux largeurs :
  `ZcrudScope(theme: ZcrudTheme(referenceProfile: ZReferenceProfile.neutral))`
  — ni bande, ni tuile, ni dégradé ; glyphe rendu nu.
- Rayon de référence des cartes d'outils **remesuré et conservé à 16** ; celui
  de la carte de dossier reste 12. Les deux familles ne se confondent pas.

### Garanties
- **Hôte passif strictement inchangé** : les trois champs neufs de la requête
  valent `null` par défaut, l'égalité d'une requête construite comme avant est
  identique, et la voie one-shot est prise à l'identique sans port de flux
  (garde d'inertie dédiée).
- **Rien n'est écrit** : aucun dépôt n'est importé. Une explication ne sort que
  par `onPersist`, sans identité — c'est l'application qui écrit.
- **`Left` en cours de flux** ⇒ `failed` avec le `ZFailure` typé exposé,
  historique **intact** et version courante non écrasée ; erreur de flux ou
  exception ⇒ `failed` **sans** `ZFailure` fabriqué ; texte vide ⇒ `empty`, qui
  n'est pas un échec.
- **Annulation** : un flux abandonné (jeton de fraîcheur périmé) n'écrase
  jamais la version courante, même si ses événements arrivent après coup.



### Ajouté
- `ZMindmapGenerationController` : orchestration du flux de génération de carte
  mentale par IA au-dessus de `ZMindmapGenerationPort`, jusque-là sans aucun
  consommateur de présentation (le port existait, rien ne l'appelait).
  `ChangeNotifier` pur, statut en enum `idle → generating → reviewing | empty |
  failed`, jeton de fraîcheur monotone, anti-double-soumission.
- `ZMindmapGenerationSheet` : feuille de saisie (sources, contenu, instructions
  libres, option « résumer »), revue des nœuds générés dans
  `ZMindmapOutlineEditor` — la surface d'édition d'outline existante, pas un
  éditeur parallèle — puis validation.
- `ZMindmapGenerationScope` : injection Flutter-native d'un port optionnel.
- `ZMindmapGenerationLabels` / `ZMindmapGenerationMessages` /
  `ZMindmapGenerationSourceOption` : libellés et sources INJECTÉS, tous requis.
- `ZStudyMindmapSection.generationPort` / `.onGenerate` /
  `.generateSemanticLabel` / `.generateIcon` (et les mêmes sur `sectionSpec`) :
  action « générer par IA » dans le chrome de la section.
- `ZMindmapGenerationRequest.summarize` (défaut `false`) : demande de
  condensation plutôt que de développement.
- `ZMindmapGenerationRequest.routeId` + `withRouteId` : identifiant de ROUTE
  opaque, transporté verbatim. Le mode « une route par intention de
  génération » est désormais porté par la requête au même rang que
  l'endpoint unique ; sa résolution en transport reste côté application.

### Garanties
- **Hôte passif strictement inchangé** : sans port, `ZStudyMindmapSection` rend
  un arbre IDENTIQUE au widget près (recensement ordonné de 69 entrées capturé
  AVANT le lot et figé en garde), et le même nombre d'actions. L'action de
  génération est ABSENTE de l'arbre, jamais grisée ni inerte : port, rappel et
  libellé sont indissociables.
- **Rien n'est écrit avant validation** : le seul canal de sortie est le
  handoff `onGenerated`, et c'est l'application qui écrit. `Left` ⇒ `failed`
  avec le `ZFailure` typé exposé (`lastFailure`) ; exception du port ⇒ `failed`
  sans `ZFailure` fabriqué ; forêt vide ⇒ `empty`, qui n'est pas un échec.
  Dans les trois cas, zéro écriture (mesuré par un dépôt en mémoire à
  compteur). Aucune exception ne remonte de `generate`.
- **Les nœuds ÉDITÉS sont ceux qui partent à l'écriture** : la validation émet
  la forêt mutée dans la revue, jamais la forêt d'origine. La carte remise
  porte un `id` vide — aucune identité n'est fabriquée par ce paquet.
- **SM-1** : les `TextEditingController` sont créés une seule fois ; la saisie
  et le focus survivent aux changements d'état, et un changement d'état ne
  reconstruit pas la surface hôte.
- `generateMindmap(` n'est appelé que depuis le contrôleur (garde de source :
  toute seconde voie d'appel dans `lib/` fait rougir).
- Aucun libellé ni couleur en dur dans les fichiers du lot ; le libellé de
  l'action de génération n'a délibérément aucun défaut de constructeur.

### Impact hôte
- Hôte **passif** : rien à faire, rien ne change.
- Hôte ayant **assemblé lui-même** la génération autour de
  `ZMindmapGenerationPort` (contrôleur maison, feuille maison, bouton posé à
  côté de la section) : sa surface s'ADDITIONNE désormais à celle du socle dès
  qu'il câble `generationPort`. Deux actions « générer » apparaîtraient dans le
  chrome de `ZStudyMindmapSection` — retirer la sienne, ou ne pas câbler le
  paramètre et conserver la sienne.
- Hôte ayant **assemblé lui-même** le résumé de note autour de
  `ZNoteSummaryPort` : même règle, à propos de `ZDefaultNoteCard.summaryPort`
  et de son action « résumer ».

### Ajouté — résumé de note par IA (consommateur de `ZNoteSummaryPort`)
- `ZNoteSummaryController` : orchestration du flux de résumé au-dessus de
  `ZNoteSummaryPort`, jusque-là sans aucun consommateur de présentation (le
  port existait, rien ne l'appelait). `ChangeNotifier` pur, statut en enum
  `idle → summarizing → reviewing | empty | failed`, jeton de fraîcheur
  monotone, anti-double-soumission.
- `ZNoteSummarySheet` : saisie du contenu à résumer, revue du texte produit,
  puis **deux issues** remises à l'application — `onInsertAtTop` (insérer le
  résumé en tête de la note) et `onCreateNote` (nouvelle note).
- `ZNoteSummarySheet.summaryBuilder` : slot de rendu injecté du résumé
  (`null` ⇒ texte brut thématisé). C'est par là qu'une lecture Markdown entre,
  **fournie par l'application** : `zcrud_study` ne dépend d'aucun moteur de
  rich-text, et une garde de source interdit d'en importer un ici (AD-1).
- `ZNoteSummaryScope` : injection Flutter-native d'un port optionnel.
- `ZNoteSummaryLabels` / `ZNoteSummaryMessages` : libellés et messages
  INJECTÉS, tous requis.
- `ZDefaultNoteCard.summaryPort` / `.onSummarize` / `.summarizeSemanticLabel` /
  `.summarizeIcon` : action « résumer » dans le créneau d'actions de la carte,
  qui **s'ajoute** au `trailing` de l'hôte sans le remplacer.

### Garanties — résumé de note
- **Hôte passif strictement inchangé** : sans port, `ZDefaultNoteCard` rend un
  arbre IDENTIQUE au widget près (recensement ordonné de 45 entrées capturé
  AVANT le lot et figé en garde), le même nombre d'actions (aucune), et le
  `trailing` de l'hôte traverse **tel quel**, sans rangée interposée. L'action
  est ABSENTE de l'arbre, jamais grisée ni inerte : port, rappel et libellé
  sont indissociables.
- **Le socle ne persiste rien** : aucun dépôt n'est importé en présentation.
  Le résumé sort par les deux handoffs, et c'est l'application qui écrit.
  `Left` ⇒ `failed` avec le `ZFailure` typé exposé (`lastFailure`) ; exception
  du port ⇒ `failed` sans `ZFailure` fabriqué ; texte vide ⇒ `empty`, qui n'est
  pas un échec. Dans les trois cas, zéro handoff (mesuré par un dépôt en
  mémoire à compteur). Aucune exception ne remonte de `generate`.
- **Le texte remis est celui du port, à l'octet près** : la revue est en
  LECTURE, blancs de bord compris. Une issue sans handoff est absente de
  l'arbre ; un geste appelle au plus un handoff, et le retour à `idle` rend un
  second appel inopérant.
- **`summarize` n'est appelé qu'une fois par geste** : anti-double-soumission
  du contrôleur, doublée du désarmement du bouton pendant la requête.
- La requête voyage verbatim (contenu, longueur cible, langue, échappatoire).
  `ZNoteSummaryRequest` **ne porte aucun identifiant de route** : rien n'en est
  donc transporté de ce côté, et rien n'en est fabriqué.
- **SM-1** : le `TextEditingController` est créé une seule fois ; la saisie et
  le focus survivent aux changements d'état, et un changement d'état ne
  reconstruit pas la surface hôte.
- `summarize(` n'est appelé que depuis le contrôleur (garde de source : toute
  seconde voie d'appel dans `lib/` fait rougir).
- Aucun libellé ni couleur en dur dans les fichiers du lot ; le libellé de
  l'action « résumer » n'a délibérément aucun défaut de constructeur.

### Limite connue — résumé de note
- La revue **n'édite pas** le résumé. Une application qui veut le laisser
  retoucher avant écriture le fait dans sa propre surface, à partir du texte
  reçu par le handoff.
- Le slot d'échappatoire de la feuille s'appelle `requestExtra`, pas `extra` :
  une surface de présentation n'est pas un porteur d'`extra` persisté et n'a
  donc ni stockage ni filtre propre (AD-19.1) — elle relaie vers
  `ZNoteSummaryRequest`, qui écarte les clés de synchronisation réservées.

### Ajouté — podcast : la présentation qui manquait
- `ZPodcastCard` : carte de podcast du socle, au chrome commun de
  `ZStudyCardReference`. Statut (`ZPodcastStatus`) et fraîcheur
  (`ZPodcastFreshness`) sont rendus par **libellés injectés** — sans fabrique
  de libellé, la puce est absente et aucune clé d'enum n'est jamais affichée
  nue. Action « régénérer » montée seulement si un callback est fourni
  (`regenerating` la laisse présente mais inerte). Fraîcheur **dérivée**
  (`podcastFreshness` du kernel), jamais stockée, aucun hachage ni horloge.
- `ZPodcastAudioPlayer` : mini-lecteur branché sur le `ZAudioPlaybackPort` du
  cœur. Monté **ssi** un port est fourni, se déclare disponible, et le podcast
  porte un audio — les quatre combinaisons sont gardées. `load` appelé une
  seule fois (jamais depuis `build`), `Left` traduit en état d'échec visible
  sans levée, port **jamais** disposé (il appartient à l'hôte), rebuild
  granulaire : un événement de position ne reconstruit ni le bouton ni l'arbre
  autour. `sourceOf` applique une règle unique et totale sur le `resultRef`
  opaque : vide ⇒ aucune source, schéma `http`/`https` ⇒ URL, sinon chemin.
- `ZPodcastGenerationController` : `ChangeNotifier` pur, statut en enum
  `idle → generating → ready | failed`, jeton de fraîcheur monotone,
  anti-double-soumission, `freshnessFor(currentSourceHash)`. Le podcast produit
  sort par le handoff `onGenerated` — le contrôleur **n'écrit rien**. Un port
  qui lève est capté et converti en `failed` (message injecté), aucune
  exception ne remonte.
- `zPodcastHubEntry(...)` : construit l'entrée « podcast » du hub de contenu,
  ou `null` tant que glyphe, libellé et geste ne sont pas tous les trois
  fournis — une entrée non câblée est **absente** de l'arbre, jamais un bouton
  mort. Teinte portée par la clé stable `ZContentHubReference.colorKeyPodcast`
  déjà existante ; aucune apparence propre.

### Ajouté — `routeId` sur les trois requêtes qui ne l'avaient pas
- `ZNoteSummaryRequest.routeId`, `ZPodcastGenerationRequest.routeId` et
  `ZFlashcardGenerationRequest.routeId` (+ `withRouteId` sur chacune) : champ
  `String?` additif, `null` par défaut, transporté **verbatim** — jamais une
  URL, jamais interprété ici (AD-12). Les adaptateurs routés peuvent désormais
  estamper ces trois intentions comme ils le faisaient déjà pour la carte
  mentale et l'explication. `ZFlashcardGenerationRequest.withResolvedSources`
  reconduit la route au lieu de la perdre.

### Garanties — podcast et routes
- **Inertie absolue** : une requête construite sans `routeId` reste
  strictement égale (égalité, `hashCode`, `extra`) à ce qu'elle était ; poser
  une route la rend non égale (égalité stricte, pas un `contains`). Un hub sans
  entrée podcast câblée rend exactement le même arbre qu'avant.
- Round-trip `withRouteId` **verbatim** sur les trois requêtes : route posée,
  tous les autres champs et l'`extra` inchangés ; `withRouteId(null)` rend la
  requête d'origine.
- Gardes de source (`@TestOn('vm')`) : aucune couleur littérale, aucun
  `Text(<littéral>)`, aucune variante non directionnelle dans les quatre
  fichiers du lot ; chaque scanner porte sa contre-preuve.
- Cibles tactiles ≥ 48 dp sur l'action « régénérer » et sur la bascule du
  lecteur (AD-13).

### Impact hôte — podcast
- Hôte **passif** : rien à faire. Aucune surface existante ne change ; toute la
  livraison est additive et opt-in.
- Hôte ayant **compensé** l'absence de présentation podcast (carte de podcast
  écrite chez lui) : câbler `zPodcastHubEntry` ou `ZPodcastCard` **sans**
  retirer sa propre carte donnerait **deux** cartes de podcast. Retirer la
  compensation avant de câbler.

### Limite connue — podcast
- La carte ne porte pas de titre propre : `title` est requis et injecté, parce
  que `ZStudyPodcast` n'en a aucun (il est nommé par sa source, que seul l'hôte
  connaît).
- Aucune feuille de génération de podcast n'est fournie : le contrôleur et la
  carte sont les briques, l'assemblage de saisie reste chez l'hôte.

## 3.28.0 — 2026-08-28

### Ajouté
- `ZExamEditor.showWeeklyReminders` (défaut `false`) : section de **rappel
  hebdomadaire éditable**. Activée, elle rend les sept jours de la semaine
  (ordre de la locale) puis la ligne d'heure existante, et compose
  `ZExam.reminderRecurrence.weekdays` en convention ISO-8601.
- `ZExamWeekdayLabeler` + `ZExamEditor.weekdayLabeler` : libellé de jour
  INJECTÉ. Repli `MaterialLocalizations.narrowWeekdays` — aucun nom de jour
  n'est écrit dans le paquet.
- `ZExamEditor.weeklyRemindersLabel` : intitulé injecté de la section.

### Garanties
- **Hôte passif inchangé** : sans `showWeeklyReminders`, l'arbre rendu et le
  `ZExam` émis sont strictement identiques à la version précédente, et
  `reminderRecurrence` n'entre pas dans le `copyWith` de soumission — une
  récurrence portée par l'examen édité est donc préservée à l'octet, sans être
  affichée ni effacée.
- La section n'édite que la famille **hebdomadaire** : `daysBefore` de la
  récurrence initiale est reporté tel quel, et `ZExam.reminderDaysBefore`
  (champ distinct, édité par la liste de seuils) n'est jamais touché. Aucun
  jour coché et aucun `daysBefore` à reporter ⇒ `reminderRecurrence == null`,
  emplacement absent plutôt que récurrence vide.
- Chaque puce de jour : cible ≥ 48 dp sur les deux axes, nœud `Semantics` avec
  label et état `selected`, couleurs par jetons de thème
  (`selectTileSelectedBorderColor` / `selectTileBorderColor`, replis
  `ColorScheme`).

### Limite connue
- Le repli `MaterialLocalizations.narrowWeekdays` est **ambigu au lecteur
  d'écran** : en `en_US` il rend `S M T W T F S`, soit cinq libellés pour sept
  jours (mardi/jeudi et samedi/dimanche homographes). Flutter n'expose aucun
  nom de jour complet sans une date réelle. Un hôte soucieux d'accessibilité
  injecte `weekdayLabeler` avec ses noms complets ; c'est cette chaîne qui
  devient le `Semantics.label`.

## 3.6.0 — 2026-08-23

### Corrigé
- Octet NUL brut dans un littéral de test remplacé par `\u0000`.

## 3.3.0 — 2026-08-21

### Modifié — le calculateur de teinte lisible est remonté au cœur

L'implémentation vit désormais dans `zcrud_core`. **Aucune rupture** : le barrel
de ce paquet ré-exporte les mêmes symboles sous les mêmes noms, et un test
existant qui les importe ainsi passe sans modification.

## 3.2.0 — 2026-08-21

### 🔴 Corrigé — la pastille de compte volait le tap qu'elle surmonte

Le badge livré en 3.0.0 pose son label **par-dessus** la tuile, et ce label est
**sensible aux gestes** : il absorbait les taps de son rectangle. Mesuré : tap au
centre **1**, tap à 8 px du coin **0**. Le tap perdu **n'émettait rien** — ni
erreur, ni retour visuel — et c'est l'action portant un artefact existant, donc
celle sur laquelle on appuie le plus.

La pastille est sortie du hit-test. Cinq montages ont été mesurés : neutraliser le
seul label **ne suffit pas** — l'absorbeur est la boîte décorée du stade, pas le
texte. **Rendu iso-pixel prouvé** : tuile, pastille, nombre et glyphe aux mêmes
rectangles.

### 🔴 Corrigé — la pastille rétrécissait la tuile, tuant la moitié de la cellule

Défaut **plus large que le précédent**, trouvé en marge et gardé : le `Stack`
portant la pastille donnait des contraintes lâches, si bien qu'une tuile **avec**
compte mesurait `93,3 × 48` là où sa voisine **sans** compte mesurait
`93,3 × 96`. La moitié basse de la cellule était **morte** — et avec un libellé
court, les **trois quarts**.

Conséquence visible : dans la même grille, le glyphe d'une action avec compte
était **24 dp plus haut** que celui d'une action sans compte. Le correctif les
**aligne** ; la pastille, elle, ne bouge pas d'un pixel (asserté en absolu et en
relatif).

La garde de preuve a été écrite **avant** le correctif et rougissait en cinq
assertions chiffrées.

## 3.1.0 — 2026-08-18

### 🔴 Corrigé — la teinte d'état n'atteignait pas un slot d'hôte

La teinte d'état livrée en 3.0.0 passait par `IconTheme.merge`, qui n'atteint
**que le contenu qui hérite**. Un slot d'hôte stylé depuis
`Theme.of(context).textTheme.*` (rôles `inherit: false`) gardait donc la couleur
ambiante et **restait illisible** — le défaut même que la teinte prétend
corriger.

Remplacé par `ZForegroundOverride`, la primitive prévue, qui réécrit **aussi**
`ThemeData.textTheme`/`iconTheme`. Trouvé par une garde **inter-paquets** de
`zcrud_core` qui scanne les sources de tous les paquets.

### Modifié — la re-pose du scope devient infaillible par construction

Les deux sites qui recopiaient le `ZcrudScope` **seam par seam** sous un
`Overlay` emploient désormais `copyWith`, qui **hérite de tout paramètre omis**.
Le défaut ne peut plus se produire, au lieu d'être rattrapé après coup.

Les commentaires du fichier recensaient **cinq** ports oubliés puis rattrapés un
par un ; les deux derniers dataient de la veille, et le **site jumeau** portait
les mêmes manquants sans qu'aucune garde ne le surveille.

La garde de structure a été **repensée, pas supprimée** : elle vérifie désormais
le **comportement** — huit seams survivent par **identité** dans la feuille et
dans la carte — et couvre **les deux** sites. Elle échouerait aussi si quelqu'un
revenait à une énumération manuelle.

## 3.0.0 — 2026-08-18

### 🔴 Corrigé — deux canaux de seams disparaissaient sous la feuille

`subListSeamRegistry` (ajouté en 1.8.0) et `selectChoiceBuilderRegistry`
(ajouté en 2.1.0) n'étaient **pas re-posés** lors de la recopie du `ZcrudScope`.
Sous l'`Overlay`, un hôte perdait donc **en silence** le rendu déclaré qu'il
venait d'obtenir.

Trouvé par la garde de structure de `cr_iffd41_subfolder_sheet_test`, qui lit la
liste **réelle** des paramètres dans la source de `zcrud_core` et exige que
chacun soit re-posé. C'est la **quatrième et cinquième** fois qu'elle mord.

**Un site jumeau, non couvert par cette garde, portait le même défaut** :
`z_default_flashcard_card` recopie le scope de la même façon. Corrigé aussi —
trouvé en cherchant le jumeau, pas en attendant qu'il se manifeste.

### ⚠️ Modifié — RUPTURE : le menu d'actions rend une grille par défaut

`ZItemActionsMenu` rendait une **colonne unique** quand aucune présentation
n'était injectée. Mesuré chez l'hôte : **aucun** de ses cinq menus n'est en
colonne, et son portage a dû réinjecter la grille à la main.

Le défaut est désormais une **grille de 3 colonnes**, via le
`ZMenuEntryTile.gridDelegate` qui existait déjà et porte le plancher de cible
tactile par construction. `crossAxisCount` est déclarable au point d'appel.

**Retour arrière en une ligne : `crossAxisCount: 1`** — prouvé par garde, pas
promis.

Trois colonnes et non deux est un **arbitrage assumé de l'hôte**, contre son
propre legacy qui en rend deux : il demande le meilleur défaut pour l'ensemble
des applications d'étude, quitte à déclarer `2` chez lui.

### Ajouté — une action porte son état

`ZItemActionState { absent, inProgress, present }` et un **compte** optionnel :
la couleur d'une action signale l'existence de ce qu'elle produit, le badge dit
combien. *« Retirer la couleur ne retire pas un ornement : cela retire
l'information. »*

**Aucune couleur codée en dur** (FR-26) : teinte dérivée du `ColorScheme` par le
patron déjà employé par `ZDefaultFolderCard` (`zReadableTintOn`, plancher de
contraste). L'état est **annoncé**, pas seulement peint — une information portée
par la seule couleur est invisible à un lecteur d'écran, et ce serait reproduire
le défaut à l'envers. Un état invalide **échoue fermé** : aucune teinte sans
annonce.

Sans état ni compte déclarés : aucun enrobage, aucun badge, aucune teinte —
rendu identique (contre-témoin à comptes absolus).

## [Non publié] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu, patron
  des sections composables, installation, démarrage rapide, concepts clés,
  API principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_study.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc du domaine, de la couche données et d'une
  partie de la couche présentation : première phrase autonome, invariants
  d'architecture cités par leur nom stable
  (`docs/site/concepts/invariants.md`). Purge des références de story et
  d'epic, des emoji de journal, des comparatifs legacy nominatifs et des
  historiques de correctifs — conservation des invariants, cas limites et
  avertissements de contrat. Aucun changement de code — la revue ne porte
  que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_study/`.
