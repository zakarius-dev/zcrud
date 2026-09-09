# Changelog

Toutes les modifications notables de `zcrud_flashcard` sont documentées dans
ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.52.0 — 2026-09-09

### Ajouté

- **`ZFlashcardReviewCard.questionFaceChoices`
  (`ZFlashcardQuestionFaceChoices { shown, hidden }`, défaut `shown`).** Sur un
  QCM, la face **question** rendait toujours les choix sous l'énoncé, en radios
  non interactives, sans aucun moyen de ne rendre que l'énoncé
  (`grep questionFaceChoices` ⇒ 0 avant ce lot). Assemblée avec une surface de
  saisie qui rend les **mêmes** choix, interactifs, la carte les affichait donc
  **deux fois**. `hidden` réduit la face question à l'énoncé ; la face
  **réponse** est strictement inchangée dans les deux cas — ses choix marqués
  sont la correction. Réglage **inerte hors QCM** (prouvé, pas supposé : les
  autres types ne rendent aucun choix sur leur face question).

- **`ZFlashcardReviewCard.faceContent`
  (`ZFlashcardFaceContent { full, blank }`, défaut `full`).** `blank` rend le
  **chrome seul** — fond, rayon, ombre portée, liseré de tête — sans énoncé,
  choix, badge de type, consigne ni actions. La carte muette ne construit
  **aucun slot de l'hôte**, ne porte **aucune surface tapable** (pas d'`InkWell`,
  donc pas de bascule de révélation) et n'émet **aucun nœud `Semantics`** de
  révélation : elle n'est ni un contrôle ni une question pour un lecteur
  d'écran. Destiné aux cartes de rang > 0 d'une pile, dont seule une bande de
  débord est visible : `flutter_card_swiper` construit ses cartes arrière sans
  `IgnorePointer` ni `ExcludeSemantics` (`card_swiper_state.dart:175-199`),
  elles ne sont donc **pas** inertes par construction.

Les deux enums sont publiés par le barrel
(`src/presentation/z_flashcard_face_mode.dart`). Défauts = rendu d'hier, à
l'octet : quatre dumps d'arbre figés (QCM et question ouverte × face question et
face réponse) gardent l'inertie.

## 3.51.0 — 2026-09-09

### Ajouté

- **`zResolveFlashcardTypeGradient(context, card, {typeGradientKey})` —
  foyer unique de la chaîne de résolution du dégradé de type**, publié par le
  barrel (`src/presentation/z_flashcard_type_gradient.dart`), qui porte
  désormais aussi `kZFlashcardReviewTypeGradientKeyPrefix`. La chaîne était
  jusqu'ici une méthode **privée** de `ZFlashcardReviewCard` : toute autre
  surface voulant peindre la même identité de type devait la **réécrire**
  (c'est ce qu'a fait la teinte d'ombre par type de `zcrud_study`, sous
  garde d'ordre inter-paquets). L'ordre publié — clé explicite, puis seam
  préfixé, puis seam nu, puis jeton `flashcardTypeGradients` — est inchangé,
  et `ZFlashcardReviewCard` l'**appelle** au lieu d'en garder une copie.
  Aucun changement de rendu : mêmes clés, même ordre, même `null`
  fonctionnel quand toute la chaîne se tait.

### Corrigé

- **`ZFlashcardReviewCard` ne lisait AUCUN des jetons `flashcardCard*`.** Ils
  ne gouvernaient que la carte de flashcard en **liste** : un hôte qui posait
  `flashcardCardBackgroundColor` croyait teinter ses cartes de session et ne
  teintait rien (grep : zéro occurrence de `flashcardCard` dans
  `zcrud_flashcard/lib`). La carte lit désormais :
  - `flashcardCardBackgroundColor` — chaîne totale `backgroundColor` >
    ce jeton > `surfaceColor` > rôle `ColorScheme.surface` ; le jeton dédié
    s'intercale AVANT le jeton générique, pour que teinter les cartes
    n'oblige pas à déplacer la surface de toutes les autres zones ;
  - `flashcardCardShadowColor` — chaîne totale, **identique à celle de la
    carte de liste** : les jetons `cardShadow{BlurRadius,Offset,Alpha}`
    priment dès qu'un SEUL d'entre eux est posé (teinte prise au rôle
    `CardThemeData.shadowColor`, sinon `ThemeData.shadowColor`), sinon la
    teinte seule — paramètre `shadowColor` puis ce jeton — porte l'ombre
    douce de référence (opacité par luminosité, flou et décalage fixes).
    Rien de posé ⇒ **aucune ombre**, comme avant.

- **Les coins de la carte lisaient `radiusM`**, le rayon des **champs de
  formulaire** : la carte n'avait aucun canal de forme propre, et l'arrondir
  obligeait à arrondir aussi toutes les zones de saisie. Ses deux sites de
  coin (la surface `Material` et l'onde de son `InkWell`) suivent désormais
  `radius` > `ZcrudTheme.flashcardCardRadius` > `radiusM`. Le pourtour de
  l'onde des **boutons d'action** reste sur `radiusM` — c'est un contrôle,
  pas un coin de carte — et une garde l'affirme.

### Ajouté

- **`ZFlashcardReviewCard.shadowColor`** (`Color?`) et
  **`ZFlashcardReviewCard.radius`** (`Radius?`) — échappatoires par instance
  de la teinte d'ombre et du rayon, premiers maillons de leurs chaînes.
- **`ZFlashcardReviewCard.shadowKey`** — clé de la boîte qui porte l'ombre,
  **absente de l'arbre** tant qu'aucun canal d'ombre n'est ouvert.

Rendu **strictement inchangé** pour un hôte qui ne pose rien : l'arbre nu
reste identique au dump figé (`test/support/z_review_card_tree_before_lotd1.txt`).

## 3.50.0 — 2026-09-09

### Corrigé

- **`ZFlashcardReviewCard` ne rendait jamais son liseré de type**, même avec un
  résolveur de dégradé branché et répondant. Quatre causes cumulées, toutes
  dans ce paquet, toutes levées :
  1. la carte soumettait au seam `ZcrudScope.gradientResolver` le nom de type
     **nu**, alors que la carte de flashcard de liste soumet
     `'flashcard.type.<type.name>'` — un résolveur écrit au format documenté
     n'était jamais appelé en session ;
  2. le jeton `ZcrudTheme.flashcardTypeGradients` n'était pas lu — un thème qui
     pose cette table ne pouvait pas teinter une carte de session ;
  3. le liseré exigeait `ZcrudTheme.accentBarHeight`, dont le défaut est `null`
     et qui gouverne aussi d'autres surfaces ;
  4. le dégradé était **supprimé** (et non rendu tel quel) quand le thème ne
     posait pas les deux jetons `gradientBegin`/`gradientEnd`, dont les défauts
     sont nuls — ce qui neutralisait aussi le badge de type.

  La chaîne de résolution suit l'ordre de priorité du socle — **seam > jeton**,
  le même qu'applique `zResolveGradient` partout ailleurs :

  1. `typeGradientKey`, s'il est posé : soumis **tel quel** au seam, et rien
     d'autre n'est consulté ;
  2. le seam `ZcrudScope.gradientResolver`, avec
     `'$kZFlashcardReviewTypeGradientKeyPrefix<type.name>'` ;
  3. le **même seam**, avec le nom de type **nu** (format historique) ;
  4. le jeton `ZcrudTheme.flashcardTypeGradients[type.name]`, en repli quand le
     seam s'est tu sur les **deux** clés.

  Autrement dit : **un résolveur d'hôte qui répond l'emporte toujours sur le
  jeton du thème**, quel que soit celui des deux formats de clé auquel il
  répond. Le seam n'est délibérément **pas coupé en deux** par le jeton : sinon
  la règle de priorité dépendrait du format de clé de l'hôte, et un hôte au
  format nu verrait son résolveur battu par une table qu'un thème du socle
  (`ZClassicTheme`) pose à sa place, sans aucun signal.

  ⚠️ **Bascule de valeur possible** pour un hôte dont le résolveur répond aux
  **deux** formats avec des dégradés **différents** : le format préfixé
  l'emporte désormais. Un résolveur qui ne répond qu'au format nu est servi
  comme avant, à l'identique.

  ⚠️ **Hôte qui pose un jeton ET un résolveur** : c'est le résolveur qui peint.
  Depuis la dernière version publiée (`3.47.0`), la carte de session ne lisait
  **pas du tout** le jeton — le changement est donc **additif** pour un hôte
  qui vient de `3.47.0` : il gagne un repli par jeton, sans perdre son
  résolveur. L'échappatoire pour reprendre la main dans l'autre sens reste
  `ZFlashcardReviewCard.typeGradientKey`, qui court-circuite toute la chaîne :
  la valeur rendue par le résolveur pour cette clé est **la** valeur retenue,
  sans repli.

  ⚠️ **Le badge de type peut apparaître teinté** là où il ne l'était pas, chez
  un hôte qui fournit `questionTypeBadgeBuilder` et un résolveur **sans** poser
  `gradientBegin`/`gradientEnd` : c'est la levée de la cause 4. Les hôtes qui
  posent ces deux jetons ne voient aucun changement.

### Ajouté

- `ZFlashcardReviewCard.accentHeight` — hauteur du liseré par instance,
  priorité **paramètre > jeton `accentBarHeight`**. Les deux nuls ⇒ aucun
  liseré, exactement comme avant. Le jeton, lui, garde son défaut `null` : le
  relever repeindrait les liserés d'autres surfaces.
- `ZFlashcardReviewCard.typeGradientKey` — clé de dégradé explicite, soumise
  telle quelle au seam ; elle court-circuite les deux clés dérivées du type
  **et** le jeton. Échappatoire pour un hôte dont les clés ne suivent aucun
  des deux formats, et seule voie pour sortir de la priorité `seam > jeton`.
- `ZFlashcardReviewCard.backgroundColor` — fond de carte par instance, priorité
  **paramètre > jeton `surfaceColor` > rôle `ColorScheme.surface`**.
- `kZFlashcardReviewTypeGradientKeyPrefix` — le préfixe de clé que la carte de
  session soumet au seam. Sa valeur est tenue égale à celle de la carte de
  liste par une garde de source.

## 3.47.0 — 2026-09-08

### Documenté

- `ZSrsConfig.minQuality` — la dartdoc dit désormais ce que cette borne
  **écrit**, et pas seulement ce qu'elle clampe. C'est la note réellement
  posée sur la répétition par le geste le plus bas d'une session (« je ne sais
  pas »), reportée en persistance dans `ZRepetitionInfo.lastQuality`. Une
  application dont l'échelle **persistée** ne comporte pas de `0` (énumération
  démarrant à `1`) doit déclarer `ZSrsConfig(minQuality: 1)` : le `0` par
  défaut lui est légal — c'est l'échelle qu'elle a elle-même fournie — mais
  non représentable chez elle, et sa propre conversion le ramène à « aucune
  note » sans exception ni test rouge. La configuration ne peut pas détecter
  la situation : elle ne connaît que l'échelle qu'on lui donne. **Aucun
  changement de contrat** : ni assertion nouvelle, ni valeur par défaut
  modifiée — un hôte au défaut n'a rien à faire.
  La dartdoc chiffre aussi le **coût** de la bascule `0 → 1` :
  `interval`/`repetitions` sont inchangés (deux lapses), mais le facteur de
  facilité diffère (`-0,80` contre `-0,54`, formule SM-2 en `(5 - q)`), et
  l'écart se reporte sur toutes les échéances ultérieures.
- `ZFlashcardHintPort` — la dartdoc dit ce qu'un hôte **sans port** conserve :
  l'indice **stocké** (`ZFlashcard.hint`) reste servi à la première demande,
  exactement comme avec un port ; seule la **génération** des indices suivants
  est perdue. Ne pas implémenter ce port est un choix tenable, pas une
  dégradation de la carte.

### Tests

- `z_min_quality_written_note_test.dart` — fige, par la mesure, que le socle
  **reporte** la note dans `ZRepetitionInfo.lastQuality` sur les deux échelles
  admises (la perte éventuelle n'est donc jamais la sienne), que
  `ZSrsConfig(minQuality: 1)` reste constructible et clampe `0` vers `1`, et
  que la bascule `0 → 1` laisse `interval`/`repetitions` identiques tout en
  déplaçant le facteur de facilité de `1,70` à `1,96`.
- `z_optional_port_and_low_bound_doc_guard_test.dart` — garde de source : les
  deux règles ci-dessus doivent rester **écrites** dans le bloc de dartdoc de
  leur déclaration. Le comportement « sans port, l'indice stocké est servi »
  est réalisé par la surface de saisie, dans un autre paquet, hors d'atteinte
  d'un test d'ici (invariant AD-1) ; et la disparition d'un avertissement au
  consommateur n'est attrapée par aucun test de comportement.

## 3.29.0 — 2026-08-28

### Ajouté

- `ZEaseFactorAdjustment` — **stratégie d'ajustement du facteur de facilité**,
  déclarée sur `ZSrsConfig.easeFactorAdjustment` et consommée par
  `ZSm2Scheduler`. Deux implémentations livrées :
  - `ZEaseFactorAdjustment.canonical()` (le **défaut**) : la formule
    SuperMemo-2 historique `EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))`,
    déplacée telle quelle depuis le corps du planificateur — mêmes opérations,
    même ordre, **mêmes doubles au bit près** ;
  - `ZEaseFactorAdjustment.table(deltaByQuality:, penalizeLapse:)` : delta
    **additif par qualité** déclaré par l'application. Une qualité absente de
    la table laisse le facteur de facilité inchangé ; `penalizeLapse: false`
    neutralise toute variation sous `passThreshold`. **Aucune valeur de delta
    n'est fournie par le paquet** — la table est une donnée de l'application.
  La stratégie rend une valeur **brute** : le bornage à
  `[minEaseFactor, maxEaseFactor]` reste au planificateur, jamais dupliqué.
  `toMap`/`fromMap` tolérants (clés de table en chaînes, contrainte JSON) :
  toute forme non reconnue — map nulle, discriminant absent/inconnu, table
  absente ou illisible — se replie sur la stratégie canonique, jamais une
  levée (AD-10).
- `ZSrsConfig.neutralQuality` (`int?`, défaut `null`) : qualité posée quand
  aucune évaluation n'est disponible (type non évalué localement **et** port
  d'évaluation absent/indisponible/muet). `null` ⇒ `passThreshold`, résolu par
  l'accesseur dérivé `ZSrsConfig.effectiveNeutralQuality` — **source unique**
  de la règle, pour qu'aucun consommateur n'écrive `?? passThreshold` chez
  lui. La valeur est **bornée** à `[minQuality, maxQuality]` à la construction
  (clamp, jamais une levée). Ce paquet ne consomme pas ce réglage : il décrit
  la politique du flux de session, et il est déclaré ici parce que l'échelle
  de qualité est possédée ici.

### Inchangé (vérifié)

- `z_sm2_contract_test.dart` — le golden numérique SM-2 — **n'a pas été
  touché** et reste vert : le passage par la stratégie est strictement
  iso-comportemental pour la configuration par défaut. Une garde
  supplémentaire (`z_ease_factor_adjustment_test.dart`) le prouve sur une
  grille de 20 facteurs de facilité de départ × 6 qualités, en **égalité
  exacte** contre la formule littérale réécrite dans le test.
- `ZMasteryLevel` couvrait **déjà** les bandes de qualité demandées
  (`bad` = `[minQuality .. passThreshold-1]`, `good` =
  `[passThreshold .. masteredThreshold-1]`, `mastered` =
  `[masteredThreshold .. maxQuality]`, soit q0-2 / q3 / q4-5 en configuration
  canonique) : aucun type de bande supplémentaire n'a été introduit — un
  second classement aurait été une seconde source de vérité.

### Modifié

- Surface publique : les **169 symboles du modèle de structure** de
  `zcrud_study_kernel` (entités study et leurs analyseurs d'extension, ports
  neutres de structure et leurs implémentations inertes, ontologie et ses
  validateurs, primitives de graphe/visibilité, primitives de (dé)sérialisation
  partagées, clés canoniques `kZStudy…`) sont **masqués** au réexport du barrel
  du noyau : ils sont study-niveau et n'ont jamais appartenu à la surface
  flashcard. Un consommateur qui en a besoin importe `zcrud_study_kernel`
  directement (foyer unique). La surface flashcard historique est intégralement
  préservée — aucun symbole retiré, aucune allowlist étendue.
- `z_kernel_surface_guard_test.dart` : le scan de la surface du noyau lisait le
  barrel **ligne à ligne** et rendait donc invisibles les directives `export`
  écrites sur plusieurs lignes (`export '…'` puis `hide …;`). Onze sources du
  noyau — 24 symboles, dont `ZStudyOrganization`, `ZStudyCompetency` et
  `ZStudyShareGrant` — échappaient ainsi à toute classification et pouvaient
  fuiter en silence. Le scan porte désormais sur le texte joint, et deux
  assertions de méta-garde interdisent le retour de l'angle mort.

## 3.28.0 — 2026-08-28

### Ajouté

- `ZFlashcardTestFilters.sourceIds` et `ZFlashcardBrowseFilters.sourceIds` :
  filtre par **identifiant** de provenance, en complément du filtre par `kind`
  déjà présent. Défaut `const <String>{}` ⇒ aucun filtre, et inertie absolue
  des deux appliqueurs (`zApplyTestFilters`, `zApplyBrowseFilters`) tant que
  l'ensemble est vide.
- `zMatchesSourceId(card, sourceIds)` : prédicat public **unique** de
  comparaison d'identifiant de provenance, partagé par le tirage de session et
  la consultation — pendant exact de `zMatchesSourceKind`. Extraction
  canonique de `noteId` / `messageId` / `documentId` par `switch` exhaustif sur
  les variants scellés de `ZFlashcardSource` ; une `ZCustomSource` (registre
  ouvert, sans identifiant canonique) ne correspond jamais à un filtre non
  vide. Pur et total : aucun cas ne lève (AD-10).
- `sourceIds` participe à `==` et `hashCode` des deux value objects de filtres.

### Modifié

- `zApplyTestFilters` et `zApplyBrowseFilters` composent `sourceIds` **en ET**
  avec `sources` (`kind`). L'ordre d'application ne change rien au résultat :
  les deux critères sont des conjonctions.
- Barrel : `ZStudySubjectRef` (symbole study-niveau du noyau d'étude) rejoint
  le `hide` de la ré-export `zcrud_study_kernel` — il n'appartient pas à la
  surface publique flashcard.

### Tests

- `z_flashcard_source_id_filters_test.dart` : 2 gardes d'inertie absolue
  (60 cartes, identité d'instance index par index sur les deux appliqueurs) et
  5 gardes d'effet, de composition en ET et de participation à l'égalité.
- `z_flashcard_source_id_predicate_guard_test.dart` : garde de source
  interdisant toute comparaison applicative d'identifiant de provenance en
  dehors de `zMatchesSourceId`, corps du prédicat canonique neutralisé avant le
  scan (une disparition du prédicat fait échouer la garde au lieu de produire
  un faux vert). Les égalités structurelles des value objects de
  `z_flashcard_source.dart` restent autorisées.
- Les trois gardes sont qualifiées par injection R3 : rouge par assertion,
  restauration par copie, empreinte identique avant/après.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet réécrit en français au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_flashcard.md` (rôle, quand l'utiliser, types
  clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, exemples compilables, invariants
  d'architecture cités par leur nom stable (`docs/site/concepts/invariants.md`).
  Purge des références de story et d'epic, des emoji de journal et des
  comparatifs applicatifs nominatifs — conservation des invariants, cas
  limites et avertissements de contrat. Aucun changement de code — la revue
  ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_flashcard/`.
