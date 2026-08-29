# Changelog

Toutes les modifications notables de `zcrud_session` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.34.0 — 2026-08-29

### Modifié

- 🔴 **Le défaut du socle devient `ZReferenceProfile.neutral`** (décidé dans
  `zcrud_core`). Sans profil déclaré, la **bande de verdict** de
  `ZSessionSummaryView` peint désormais les rôles `primaryContainer` /
  `onPrimaryContainer` du `ColorScheme` de l'hôte, au lieu du dégradé de la
  palette signature auditée.
- Le dégradé de référence reste disponible par
  `ZcrudScope(theme: ZcrudTheme(referenceProfile: ZReferenceProfile.legacy))`.

### Tests

- Garde ajoutée « 🔴 K1b — DÉFAUT du socle : indiscernable du profil
  `neutral` » ; la garde K2 de l'habillage déclare `legacy` explicitement, ses
  assertions inchangées.

## 3.29.0 — 2026-08-28

### Corrigé

- 🔴 **`ZTestFiltersDialog` effaçait `sourceIds`.** Le dialog reconstruisait un
  `ZFlashcardTestFilters` sans ce critère : un `initial.sourceIds` non vide était
  **perdu** au simple aller-retour « ouvrir → Valider », sans aucun signal. Il est
  désormais repris à l'ouverture et restitué au `pop`, **même quand aucune section
  d'identifiants n'est rendue** — le dialog compose des filtres, il n'en efface
  aucun. Un hôte qui compensait en re-fusionnant lui-même `sourceIds` après le
  `pop` obtient maintenant le bon ensemble des deux côtés : **la compensation peut
  et doit être retirée** (une ré-union est idempotente, mais elle masquerait une
  future divergence).

### Ajouté

- **Seuil de réussite de l'examen blanc et verdict.**
  `ZWhiteExamSessionEngine` accepte un `successRatio` (`double?`, défaut `null`) :
  la part de réponses correctes exigée pour réussir. **Le seuil est une donnée de
  l'application** — aucune valeur n'est écrite dans le paquet, et une garde de
  source interdit qu'un `0.7`/`70` y réapparaisse. Le moteur expose
  `ZWhiteExamVerdict? verdict` (`{passed, ratio, correct, total}`), **dérivé** du
  résultat par la fonction pure `zWhiteExamVerdictFor(result, {successRatio})` et
  jamais stocké ; `ZWhiteExamSessionController` le relaie dans
  `ZWhiteExamSessionViewState.verdict`.
  Normalisation défensive : seuil borné à `[0, 1]` (un `1.4` ne rend pas l'examen
  ingagnable), `NaN` vaut « aucun seuil » (jamais un recalage silencieux), ratio
  borné (`total == 0` donne `0`, aucune division par zéro), comparaison **large**
  (atteindre exactement le seuil réussit — c'est un `>=`, et la garde tape sur
  cette frontière exacte).
  Sans `successRatio`, `verdict` reste `null` après soumission : **le défaut ne
  juge rien**.
- **`ZSessionSummaryView.verdict`** (défaut `null`) — un verdict réussi déclenche
  la célébration existante (`ZCelebrationSpec`), avec la durée
  `ZcrudTheme.celebrationDuration` et la courbe `celebrationCurve` (jetons déjà
  lus, désormais gardés). Un verdict qui réussit **promeut** la célébration par
  défaut à `confetti`, mais respecte une variante explicitement demandée par
  l'hôte (`subtle` reste `subtle`) ; un verdict manqué **éteint** toute
  célébration, même demandée — on ne fête pas un échec.
  Les couleurs de la bande de verdict passent par `zLegacyOrIn` : palette
  signature auditée sous le profil `legacy` (le défaut), rôles M3
  `primaryContainer`/`onPrimaryContainer` sous `neutral`. L'échec est dit par le
  **texte** (`label(context, 'zcrud.session.summary.verdict.failed', fallback:)`),
  sans couleur sémantique inventée : le style du thème est rendu tel quel.
  Sans verdict, **l'arbre monté est identique à l'octet près** au précédent — une
  garde le compare à un dump figé capturé sur le code d'avant.
- **`ZLapseRequeuePolicy`** — les offsets de réinsertion d'une carte ratée
  deviennent paramétrables : `offsetSevere` (défaut 2), `offsetLight` (défaut 4),
  `severeMaxQuality` (défaut 1). Injectable par le constructeur de
  `ZStudySessionEngine` et de `ZLinearSessionState` (`lapsePolicy:`) et par les
  reducers purs `reduceGrade` / `requeueCramming` (`policy:`). Le défaut **est**
  la table historique (les constantes `kLapseOffsetSoft`/`kLapseOffsetHard`/
  `kLapseSoftMaxQuality`, réutilisées et non recopiées) : sans injection, les
  positions de file sont identiques au dp près.
  Les dartdocs lèvent l'ambiguïté du mot « soft » : il qualifiait la **longueur de
  l'offset**, pas la sévérité de l'échec — l'offset court (+2) sert le lapse le
  plus **sévère**, parce qu'une carte totalement ratée doit revenir **plus tôt**.
  Les noms publics des constantes sont conservés (compatibilité).
- **`ZSessionCardSwiper.preserveIndexOnMutation`** (défaut `false`) — conserve la
  carte courante quand la file change d'identité, au lieu de ramener la pile à sa
  première carte. La position est ramenée dans les bornes de la nouvelle file (une
  file qui rétrécit sous l'index le ramène sur la dernière carte). Ni la remise à
  zéro ni la conservation n'émettent `onIndexChanged` : une mutation de file n'est
  pas une avancée. Le paramètre conserve la **position**, jamais l'identité de la
  carte — un hôte qui veut suivre une carte précise pilote l'index par
  `indexController`.
- **5ᵉ seau « carte passée »** — `ZFlashcardSubmission.skipped` (défaut `false`) et
  `ZFeedbackTier.skipped`, alimenté par `zFeedbackTierFor(skipped:)`. Une carte
  passée (« Je ne sais pas ») et une carte ratée portaient la même note et étaient
  donc indistinguables : le retour pédagogique reprochait une erreur à qui n'avait
  rien tenté. Le seau **ne se déduit d'aucune note** — il n'est atteint que sur
  déclaration explicite. Les quatre seaux historiques et tous les agrégats par
  qualité sont inchangés. La banque FR/EN par défaut couvre le nouveau seau.
  ⚠️ `ZFeedbackTier` gagne une valeur : un `switch` **exhaustif sans `default`**
  sur cet enum, chez un hôte, cessera de compiler. Vérifié : aucun des quatre
  dépôts hôtes ne référence `ZFeedbackTier` (`grep` sur `iffd`, `lex_douane`,
  `dodlp-otr`, `dlcfti-otr` — aucune occurrence).
- **`ZFlashcardAnswerInput.markSkippedSubmissions`** (défaut `false`) — marque
  `skipped` sur la soumission émise par « Je ne sais pas », et sur elle seule
  (« Évaluer sans IA » reste une réponse ordinaire). Note, verdict, verrou de
  soumission et auto-passage sont inchangés.
- **`ZTestFiltersDialog.availableSourceIds`** — section de filtre par identifiant
  de provenance (`noteId`, `documentId`, `messageId`…), rendue **uniquement** si
  l'hôte propose des candidats. Libellés par `label(context,
  'zcrud.study.sourceId.<id>')`, repli sur l'identifiant lui-même. Clé de bascule :
  `ZTestFiltersDialog.sourceIdKey(id)`.
  Dossier, tags et types de question restent **hors** de ce dialog : ils
  appartiennent à `ZStudySessionConfig` / `ZStudySessionSelector`, et les porter
  ici créerait deux sources du même filtre.
- **`ZSessionCardSwiper.onSwipeDirection`** + **`enum ZSwipeDirection { start,
  end }`** — seam de **direction du geste**, jamais de notation. Le socle dit
  *un swipe a eu lieu, vers `start` ou vers `end`, sur telle carte* ; ce qu'on
  en fait appartient à l'hôte. L'invariant AD-33 (« le swipe navigue, il ne
  note jamais ») est **tenu et non amendé** : aucun symbole de notation
  n'entre dans le fichier du swiper, et la garde de source qui le vérifie
  (`z_swipe_never_grades_test.dart`) est **inchangée à l'octet**.
  Contrat : appelé **une fois par geste**, avec l'index de la carte
  **chassée**, et **avant** `onIndexChanged(index + 1)` — l'ordre est gardé
  par un journal unique. La direction est **logique** (`start`/`end`, résolues
  contre la `TextDirection` — jamais `left`/`right`, invariant AD-13) : sous
  `rtl`, le même geste physique donne la direction opposée.
  N'émet **que sur un geste** : ni une commande `ZIndexController`, ni le
  bouton accessible « carte suivante » n'appellent le callback. Ces avances
  n'expriment aucune direction, et en relayer une par défaut attribuerait à
  l'utilisateur de lecteur d'écran — le seul à passer par ce bouton — une
  intention qu'il n'a pas formulée. Conséquence pour un hôte qui dérive une
  décision de la direction : cette décision doit rester atteignable sans
  geste (une rangée `ZSrsQualityButtons` en frère y suffit).
  Sans le paramètre, inertie absolue : arbre rendu et suite des index émis
  strictement identiques à l'état antérieur (empreinte de 89 widgets figée
  sur la source d'avant le lot, comparée en égalité stricte).

### Renforcé

- La garde de source anti-« navigation à gauche » du swiper
  (`z_session_card_swiper_a11y_test.dart`) portait sur la **mention** du jeton
  `CardSwiperDirection.left`. Elle porte désormais sur l'**argument de chaque
  appel `swipe(`**, qui doit être `CardSwiperDirection.right` littéral. Plus
  strict (elle attrape maintenant `final d = …; swipe(d);`, que l'ancien
  ancrage laissait passer) et correctement ancré (comparer une direction
  reçue en entrée d'`onSwipe` ne commande aucune navigation).

### Note pour les hôtes

Hôte **passif** : rien à faire, tous les nouveaux paramètres sont opt-in et leur
défaut reproduit le comportement antérieur (arbres et files gelés, mesurés).
Hôte ayant **compensé** :
- celui qui re-fusionnait `sourceIds` après le `pop` de `ZTestFiltersDialog` peut
  retirer sa compensation ;
- celui qui notait lui-même sur `onIndexChanged` de `ZSessionCardSwiper` doit
  savoir que ce rappel n'a **pas** changé (aucune note n'est émise par la pile) ;
- celui qui remontait `ZSessionCardSwiper` par une `key` pour compenser la remise
  à zéro sur mutation peut passer à `preserveIndexOnMutation: true` et retirer la
  clé — les deux ensemble laisseraient la pile repartir de zéro malgré le
  paramètre.

## 3.28.0 — 2026-08-28

### Ajouté

- `ZFlashcardAnswerInput` devient **contrôlable et pluggable**, par cinq
  contrats strictement optionnels :
  - `choiceContentBuilder` — remplace le `Text` brut d'un choix de QCM, sans
    toucher à la sélection, aux sémantiques ni à la cible tactile. Un hôte qui
    rendait ses choix en markdown avait dû **cloner le widget entier** pour y
    parvenir ; il peut revenir au socle.
  - `writtenAnswerFieldBuilder` — remplace le `TextFormField` de la réponse
    rédigée. Le builder reçoit le `controller` et le `focusNode` **détenus par
    la surface** : le texte saisi dans le champ injecté part au barème sans
    câblage supplémentaire.
  - `initialAnswer` — préremplit la réponse rédigée, **une seule fois, au
    montage**. Jamais réinjectée : une valeur repoussée à chaque build
    écraserait la sélection et le curseur en pleine frappe (invariant AD-2).
  - `onAnswerChanged` — observe la réponse courante
    (`ZFlashcardAnswerDraft` : texte, positions cochées, réponse Vrai/Faux).
    Passe par un écouteur, jamais par un `setState` : observer la saisie ne
    reconstruit aucun frère.
  - `isSubmitted` — impose le verrou de soumission (`null` : la correction
    locale décide seule). `true` rend inertes les choix, les boutons
    Vrai/Faux, le champ rédigé, « Indice » et « Je ne sais pas », **sans
    peindre de correction** : la surface n'en fabrique pas. `false` ne rouvre
    pas une soumission déjà consommée.
- `ZFlashcardAnswerDraft` et les typedefs `ZFlashcardChoiceContentBuilder` /
  `ZFlashcardWrittenAnswerFieldBuilder`.

### Corrigé

- L'observation de la réponse rédigée ne suit plus les notifications de
  **sélection** du `TextEditingController` : poser le focus dans le champ
  (l'offset passe de `-1` à `0`) émettait une « saisie » vide avant la
  première frappe. Défaut trouvé par la garde de granularité pendant sa
  propre mise au point, avant toute publication.

### Inertie

- Sans aucun de ces paramètres, l'arbre de widgets des trois variantes (QCM,
  Vrai/Faux, rédaction) est **strictement identique** à celui de la 3.27.0 —
  garde d'égalité stricte sur la séquence complète des types descendants,
  jamais un `contains`.

## [Non publié] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu,
  installation, démarrage rapide, concepts clés, API principale, cas
  limites et invariants.
- Fiche `docs/site/paquets/zcrud_session.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel (trois moteurs de runtime, surface de saisie, boutons de notation,
  pile swipeable, sélecteur de session, écran de fin, dialog de filtres) :
  première phrase autonome, exemples compilables sur les entités
  principales, invariants d'architecture cités par leur nom stable
  (`docs/site/concepts/invariants.md`). Purge des références de story et
  d'epic, des emoji de journal et des historiques de correctifs — conservation
  des invariants, cas limites et avertissements de contrat (notamment la
  voie d'écriture SRS unique, l'arène des gestes de la surface de saisie et
  la correspondance carte ↔ réponse de l'examen blanc en liste). Aucun
  changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_session/`.
