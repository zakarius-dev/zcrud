# Handoff v3.50.0 — le liseré de session peut enfin être teinté, et trois pièges de moins

Origine : une application hôte signalait que son résolveur de dégradé « répond, mais la
carte ne rend aucun liseré », sans avoir pu attribuer l'écart. **L'écart venait de nous**,
et la mesure a trouvé **quatre causes cumulées**, pas une.

## Clés de schéma ajoutées

**Aucune.** Aucune entité persistée n'est touchée ; aucune migration n'est requise.

## Pourquoi aucun liseré ne pouvait apparaître en session

| # | Cause | État |
|---|---|---|
| 1 | La carte de session demandait la clé **nue** (`openQuestion`), la carte de liste la clé **préfixée** (`flashcard.type.openQuestion`). Un hôte suivant le format documenté n'était jamais appelé | corrigé |
| 2 | Le jeton `ZcrudTheme.flashcardTypeGradients` — celui que pose notre propre thème « Classic » — **n'était pas lu** par la carte de session | corrigé |
| 3 | Le liseré n'est monté que si une hauteur est déclarée, et le jeton `accentBarHeight` vaut `null` par défaut : **aucune bande à peindre** | paramètre ajouté |
| 4 | Le dégradé était **annulé** dès que `gradientBegin` ou `gradientEnd` manquait — et le thème « Classic » ne les pose pas. Sans cette levée, les trois correctifs ci-dessus auraient été **inertes** chez un hôte réel | corrigé |

La quatrième n'avait été signalée par personne. Elle mérite d'être dite : les gardes des
trois premières auraient été **vertes** en posant ces deux jetons dans le harnais de test —
c'est-à-dire en mesurant un cas que personne ne vit.

## La chaîne, désormais explicite

```
typeGradientKey            (court-circuit total, échappatoire)
  → seam 'flashcard.type.<type.name>'
  → seam '<type.name>'      (format historique, conservé)
  → jeton flashcardTypeGradients[<type.name>]
```

Et l'interrupteur, séparé : **`accentHeight` > jeton `accentBarHeight`**. Sans l'un des
deux, aucune bande n'est peinte — que le dégradé soit résolu ou non.

⚠️ **`ZFlashcardReviewCard` — la priorité est désormais `seam > jeton`.** Si vous posez à la
fois un `ZcrudScope.gradientResolver` et le jeton `flashcardTypeGradients` (ce que fait
`ZClassicTheme`), **c'est votre résolveur qui peint**, qu'il réponde au format préfixé ou au
nom nu ; le jeton n'est plus qu'un repli quand le résolveur se tait sur les deux clés.

Venant de 3.49.0, où la carte de session ne lisait **pas du tout** ce jeton, le changement
est **additif** : vous gagnez le repli sans perdre votre résolveur. Si vous comptiez au
contraire sur le jeton pour l'emporter, l'unique échappatoire est `typeGradientKey`.

⚠️ **Effet de bord à connaître** : le **badge de type** peut apparaître teinté chez un hôte
qui fournit `questionTypeBadgeBuilder` et un résolveur, sans poser les jetons de géométrie.

## Ce qu'il fallait deviner, et qui est maintenant écrit

La documentation ne mentionnait **aucun** des formats de clé réellement soumis aux seams,
hors ceux des champs de formulaire. Le guide et les fiches de paquet portent désormais
l'inventaire complet — dont la famille `zcrud.signature.<identité>`, qui a **dix émetteurs**
(l'app-bar, le bouton flottant, les en-têtes de section de tout formulaire groupé) et
n'était documentée nulle part.

Deux pièges y sont nommés explicitement : passer un `colorKey` **désactive** le seam pour
l'axe type, et le `gradientKey` du chrome Markdown vaut **le nom du champ** par défaut.

## Le chrome de page devient remplaçable par thème

Huit métriques de l'app-bar, du bouton flottant d'identité et de la puce de choix étaient
écrites **au site de rendu** (`elevation:`, `shape:`, `Icon(size:)`, `style:`,
`showCheckmark:`) — ce qui **prime** sur `AppBarTheme`, `FloatingActionButtonThemeData` et
`ChipThemeData`. Aucun canal du SDK ne pouvait les atteindre ; un hôte ne pouvait les
changer qu'en réimplémentant le widget.

Huit jetons nullables les exposent désormais dans `ZcrudTheme`, par ordre
`paramètre > jeton > référence` : `appBarWashAlphas`, `appBarWashElevation`, `fabShape`,
`fabElevation`, `fabIconSize`, `fabLabelStyle`, `choiceChipShape`, `choiceChipShowCheckmark`.

- une valeur hors contrat (rampe de moins de deux arrêts ou hors `[0, 1]`, élévation
  négative, taille de glyphe non positive) est **ignorée** au profit de la référence, jamais
  levée ;
- `fabShape` habille le bouton **et** son fond dégradé — les dissocier laisserait un bouton
  carré dans un halo rond ;
- `fabIconSize` ne touche pas la cible tactile, tenue au-dessus de 48 dp par le bouton ;
- aucun de ces jetons n'atteint le bouton **sans dégradé** ni l'app-bar **sans lavis** : ceux-là
  restent au SDK et au thème de l'hôte.

Un neuvième jeton envisagé — la couleur de sélection de la puce — n'a **pas** été ajouté : elle
est déjà résolue `paramètre > premier arrêt de la palette de signature > rôle`, et la palette de
signature est elle-même un jeton. Un jeton de plus aurait doublé un canal existant.

- **Application passive** : rien ne change, arbre et valeurs peintes identiques.
- **Application ayant compensé** par un `Theme`/`AppBarTheme` local qui ne prenait pas :
  le jeton est maintenant la voie ; retirez le thème local devenu inerte.

## Une pilule de progression, et pourquoi aucun paquet tiers n'est entré

`ZSessionProgressStyle.pill` s'ajoute à `dots`, `segmentedBar` et `linear` : un indicateur
compact « X/Y » de forme arrondie, couleurs par clé (`pillColorKey`, défaut `primary`),
**parité sémantique mesurée** contre les trois styles existants — le couple libellé/valeur du
nœud est identique pour les quatre. Le défaut de l'enum reste `dots`.

La référence visuelle d'origine utilise deux paquets tiers pour ses indicateurs. Ils ont été
mesurés contre leur source **avant** toute dépendance, et **aucun n'est entré** :

- le paquet de points rend exactement ce que rend le nôtre (un `Container` décoré) et impose
  huit `assert` qui lèveraient là où le socle borne. Ce qui diffère est de la **géométrie**
  (taille, ratio actif, espacement, alignement) — elle devient paramétrable, sans dépendance ;
- le paquet de barre segmentée code `TextDirection.ltr` **en dur** dans son painter — une
  violation non paramétrable de l'accessibilité directionnelle —, n'expose aucune sémantique,
  et son heuristique écrase le marqueur demandé dès qu'un segment est étroit (la référence
  subit ce défaut : elle omet sa dernière carte). Son rendu — segments séparés, marqueur
  triangulaire — est reproduit par un painter maison de quelques dizaines de lignes.

Aucune dépendance nouvelle n'est donc imposée aux applications consommatrices.

## Le thème « Classic » après le changement d'ordre

Sa documentation laissait croire que seul un paramètre de widget dépassait son jeton de
dégradés par type. La chaîne réelle, désormais écrite partout : **`paramètre > seam >
jeton > référence`**. Le jeton que pose le thème est un **repli** — un hôte qui branche un
résolveur le voit peindre, sous Classic comme sans.

**Deux choses que le thème ne pose délibérément pas, et pourquoi :**

- **`accentBarHeight`** — le jeton global de hauteur de liseré. Mesuré par comparaison
  d'arbres : son effet **dépend de ce que l'hôte a branché ailleurs**. Sous Classic seul, un
  champ de formulaire ne change pas ; sous Classic plus un résolveur large d'hôte, le même
  champ gagne un liseré que personne n'a demandé. Les deux autres surfaces lisent ce jeton
  **sans contrepoids**. Le poser globalement pour viser une seule surface serait le
  contraire d'un thème précis. La valeur de référence (4 dp) est publiée en
  `ZClassicSurfaceReference.cardAccentHeight` pour la **voie paramètre**, celle qui ne
  touche que la carte de session.
- **Les huit jetons de chrome de page** — `ZPageShellReference` porte **déjà** la rampe
  de lavis `[0.15, 0.10, 0.05, 0.02]` et l'élévation nulle, identiques à la source d'origine,
  et chaque consommateur résout `jeton ?? référence` sans condition. Les poser ouvrirait un
  second canal vers le même pixel.

**Un jeton non posé est une réponse mesurée ; un jeton posé « pour être complet » serait une
dette.**

- **Application passive** : rien ne change.
- **Application sous Classic qui posait aussi un résolveur** : c'est votre résolveur qui
  peint désormais le liseré par type — le jeton du thème ne l'écrase plus. Si vous vouliez
  au contraire le rendu du thème, retirez votre résolveur pour ces clés.

## Un preset de session : les formes, pas seulement les valeurs

Après avoir posé jetons, clés, libellés et seams, une application constatait qu'il lui
manquait encore des **formes** — liseré, fond détaché, en-tête, pilule, pastilles — qu'elle
devait composer elle-même. *Tout ce qui traversait était une valeur ; tout ce qui manquait
était une forme.* Composer ces formes lui avait coûté deux erreurs retirées.

`ZStudySessionPreset` est un **objet de configuration immuable**, interprété par
`ZStudySessionHost`, `ZStudySessionView` et relayé par `ZStudySessionScaffold` :

```dart
ZStudySessionScaffold(
  title: l10n.sessionTitle, mode: ZReviewMode.spaced, queue: cards, reviewer: reviewer,
  preset: ZStudySessionPreset.classic(
    title: l10n.sessionTitle,
    counter: (ZStudySessionProgress p) => l10n.reviewedOf(p.reviewed, p.total),
    streak: streak, accentHeight: 4,
    cardTypeGradientKey: 'session.card', cardBackgroundColorKey: 'session.surface',
  ),
)
```

Ce que le preset **ne décide pas**, et c'est délibéré :
- le **libellé du compteur** est une valeur que vous composez : en répétition espacée,
  `remaining + reviewed ≠ total` **par conception** — le socle n'a pas de formule à imposer ;
- la **série** est un `ZStudyStreak`, pas un pourcentage ;
- les **couleurs** sont des clés résolues par votre thème, jamais des valeurs.

**Un slot explicite gagne toujours sur le preset** — `headerBuilder`, `progressStyle`,
chaque champ de chrome de carte. `preset: null` ⇒ arbre identique à l'octet.

Un seul widget nouveau (la rangée d'en-tête, privée) ; tout le reste réutilise des briques
existantes. Les deux sites de montage de la carte sont fusionnés : un habillage ne peut plus
manquer sur l'un des deux.

⚠️ **Changement de type** : `progressStyle` devient nullable (`ZSessionProgressStyle?`) sur
le host, la vue et le scaffold — nécessaire pour qu'un style **posé** à `dots` se distingue
d'un style **non posé** et laisse la main au preset. Résolution `paramètre ?? preset ??
dots`.
- **Application qui passe le paramètre** : rien ne change.
- **Application qui LIT `host.progressStyle`** : le type porte maintenant un `?` — un `!`
  ou un `?? ZSessionProgressStyle.dots` restitue l'ancien comportement.
- **Application ayant compensé** en remontant elle-même `ZStreakBadge`, une rangée
  titre/compteur, ou en refabriquant la carte pour ses pastilles : ces compositions
  **s'additionnent** désormais au preset. Retirez-les et passez par `ZSessionHeaderSpec` /
  `ZCardChromeSpec`. Le test qui doit rougir chez vous : celui qui affirme que votre en-tête
  ou votre `cardBuilder` est rendu — s'il reste vert, la compensation est encore branchée.

### La fidélité, livrée par nos briques

- **`ZSessionDotsGeometry`** — cinq champs nullables (`inactiveSize`, `activeScale`, `gap`,
  `alignment`, `scrollable`), posés sur `ZSessionProgressIndicator.dotsGeometry` et relayés
  par `ZSessionCardSwiper.progressDotsGeometry`. **Défauts = le rendu d'aujourd'hui**, à
  l'octet. Une valeur hors bornes retombe sur le défaut, jamais sur une exception.
- **`ZSessionProgressStyle.segmentedMarker`** — segments détachés, tous arrondis, marqueur
  triangulaire sur le seul segment courant, épaisseur paramétrable
  (`segmentedMarkerThickness`). Peint par un painter maison : **RTL par `Directionality`**
  (aucun `TextDirection` codé), `shouldRepaint` honnête, sémantique **identique aux quatre
  autres styles** — les cinq annoncent le même couple libellé/valeur.
- **Épaisseurs** des styles `linear` et `segmentedMarker` désormais réglables depuis la pile
  — elle choisissait le style sans pouvoir en régler l'épaisseur.

Le défaut de l'enum reste `dots`. Les valeurs de la référence d'origine (points 14×10,
actif ×2,4, espacement 12, centré, défilant, épaisseur 8) **ne deviennent pas des défauts du
socle** : elles se posent par le preset ou par le thème.

- **Application passive** : rien ne change.
- **Application qui ré-implémentait un indicateur** pour obtenir ces formes : retirez-le et
  posez la géométrie ; le test qui doit rougir chez vous est celui qui affirme que votre
  indicateur maison est monté.

## Le montage énuméré : oublier un seam ne compile plus

Un hôte a retiré une composition de carte devenue inutile ; sa découpe a emporté **six
seams** — `contentBuilder`, `hintPort`, `evaluationPort`, `labels`, `onExit`,
`onSessionEnd`. Ses mots : *« `flutter analyze` est resté VERT — tous sont optionnels. La
suite aussi. »* Seul l'écran l'a montré.

C'était une propriété de notre conception : `ZStudySessionHost` porte **43 paramètres**,
dont 34 nullables à défaut silencieux. Un oubli ne produisait ni erreur, ni test rouge.

`ZStudySessionWiring` et `ZStudySessionHost.wired` changent cela **sans rien exiger de
personne** :

```dart
ZStudySessionHost.wired(
  mode: mode, queue: queue,
  wiring: ZStudySessionWiring(
    reviewer: monReviewer,
    labels: mesLibelles,
    hintPort: null,            // ← une décision ÉCRITE, pas un oubli
    evaluationPort: null,
    // … les 22 seams, tous nommés — en oublier un est une ERREUR DE COMPILATION
  ),
)
```

Le mécanisme tient en une règle : chaque champ du wiring est **`required` et nullable**.
Dart oblige à *écrire* `null` — l'omission ne compile plus, le renoncement devient une ligne
lisible et greppable. La **valeur** `null` signifie toujours « absent », comme partout dans
le socle ; seule sa **nomination** devient obligatoire.

Ce qui distingue un seam d'un réglage cosmétique n'est pas une liste sur parole : une garde
lit le host sur disque et **classe chaque paramètre par son type** — scalaires de mise en
page, couleurs et styles sont cosmétiques ; tout le reste est un seam, et un type inédit
tombe côté seam. Un 23ᵉ seam ajouté demain sans être câblé fait rougir cette garde.

- **Application passive** : rigoureusement rien. Le constructeur par défaut est intact ;
  `.wired` rend le même arbre, nœud pour nœud.
- **Application qui adopte `.wired`** : elle gagne la détection à la compilation — et
  accepte son prix, écrit noir sur blanc dans la documentation du wiring : **ajouter un seam
  au socle sera cassant pour elle**, puisqu'elle devra le nommer. C'est l'intérêt du
  mécanisme autant que son coût, et une garde refuse qu'on le contourne un jour par un
  défaut `= null`.
- `ZStudySessionWiring.none()` renonce à tout d'un coup — pour un banc d'essai, jamais pour
  un écran.

### Le scaffold suit, et la géométrie de progression traverse jusqu'au preset

`ZStudySessionScaffold.wired` remet le wiring **entier** au host — jamais champ par champ,
de sorte qu'un seam ajouté demain ne puisse pas manquer ici en silence. Le constructeur est
`const`, ce qui rend le démontage champ par champ **impossible à la compilation**.

La géométrie de progression livrée dans `zcrud_session` traverse désormais preset → host →
vue → pile : `progressDotsGeometry`, `progressLinearThickness`,
`progressSegmentedMarkerThickness`, résolus `paramètre ?? preset ?? défaut de l'indicateur`.
`ZStudySessionPreset.classic` pose la géométrie de la référence (points 14×10, actif ×2,4,
espacement 12, centré, défilant, épaisseur segmentée 8). `preset: null` ⇒ rendu inchangé.

Montage complet, tel qu'un hôte l'écrit :

```dart
ZStudySessionScaffold.wired(
  title: l10n.sessionTitle,
  mode: ZReviewMode.spaced,
  queue: cards,
  wiring: ZStudySessionWiring(/* les 22 seams, `null` compris — en oublier un ne compile pas */),
  preset: ZStudySessionPreset.classic(
    title: l10n.sessionTitle,
    counter: (p) => l10n.reviewedOf(p.reviewed, p.total),
    streak: streak,
    accentHeight: 4,
  ),
  // une forme propre bat celle du preset :
  // progressDotsGeometry: const ZSessionDotsGeometry(inactiveSize: Size(14, 10), activeScale: 2.4, gap: 12),
)
```

### Le filet pour les montages à plat : `auditSeams`

`.wired` protège qui l'adopte. Pour les montages restés **à plat**, un filet **opt-in**, en
deux formes — aucune ne coûte quoi que ce soit à qui ne la demande pas :

**Dans vos tests**, une fonction pure — ni `pump`, ni `BuildContext` :

```dart
test('mon écran de session pose tout ce qu\'il annonce', () {
  final report = maSessionWidget().auditSeams(
    waived: const {ZStudySeam.hintPort, ZStudySeam.celebrationBuilder},
  );
  expect(report.isComplete, isTrue, reason: report.toString());
});
```

**À la construction**, en debug seulement — un rapport par `FlutterError.reportError`,
jamais une exception, et **la session s'affiche quand même** :

```dart
ZStudySessionHost(
  mode: mode, queue: cards, reviewer: reviewer, onExit: Navigator.of(context).pop,
  seamAudit: const ZStudySeamAuditPolicy(waived: {ZStudySeam.hintPort}),
)
```

Trois régimes, tous **déclarés par vous**, jamais devinés :
- `.wired` → le `null` écrit est la décision ; `missing` est **vide par construction** ;
- à plat + `seamAudit` → les entrées de `waived` sont la décision, **le reste est un oubli** ;
- à plat sans rien → **silence total**, comme avant.

Deux détails qui comptent :
- le rapport nomme aussi les **renonciations inutiles** — un seam déclaré renoncé mais
  fourni — parce que c'est le même défaut de fond : la déclaration ne décrit plus le montage ;
- chaque `ZStudySeam` porte le **défaut** que le socle appliquera à sa place, pour que le
  rapport dise ce que vous perdez, pas seulement ce qui manque.

Le message est technique (noms de seams), jamais affiché à l'utilisateur final, et
`seamAudit` n'a **aucun** effet en release.


## Si vous n'adoptez rien

Une application **passive** — qui ne pose aucun réglage nouveau, ne monte pas `.wired` et
n'utilise pas de preset — ne voit **aucun** changement d'arbre ni de couleur peinte, à
deux exceptions près, toutes deux additives et documentées ci-dessus : le liseré de la carte
de session peut désormais apparaître **si** elle déclare une hauteur, et son résolveur de
dégradé prime désormais sur un jeton de thème.

Une application qui **compensait** l'un des défauts corrigés doit retirer sa compensation :
elle s'additionne au comportement natif. Chaque section dit quoi retirer, quoi garder, et
quel test doit rougir chez vous pour que vous le vérifiiez vous-même.

## Les tripwires à écrire chez vous

Sur chaque défaut amont que vous aviez contourné, gardez un test qui **affirme la perte**.
Quand l'amont corrige, il rougit et désigne le doublon — au lieu de croire un handoff sur
parole. Pour cette version :

| Vous compensiez… | Le test qui doit rougir |
|---|---|
| un liseré de type refabriqué dans `cardBuilder` | « mon `cardBuilder` est appelé » |
| une pastille ou un bandeau via `cardBuilder` | idem — et vérifiez que `revealController` est revenu |
| un en-tête titre/compteur/série composé à la main | « mon en-tête est rendu » |
| un indicateur de progression maison | « mon indicateur est monté » |
| un `Padding` bas ou un `SafeArea` autour de la saisie | la hauteur exacte de la surface |
| un résolveur ignoré sous un thème du socle | `BoxDecoration.gradient` du liseré avec jeton **et** résolveur posés |

## Vérification, rejouée au repos

- `melos run generate` → RC=0, **0 fichier généré modifié** ;
- `melos run analyze` **repo-wide** → RC=0 ;
- `melos run verify` (gates, dont `web`, `reserved-keys`, graphe acyclique et recette de
  consommation) → RC=0 ;
- balayage des **42 paquets**, `flutter test --no-pub` lancé **depuis le dossier de chaque
  paquet** → **41 verts**. `zcrud_generator` est rouge pour une raison d'environnement,
  qualifiée et non imputable au code : son `lib` et son `test` sont **identiques à l'octet** à
  la version précédente (`Unsupported operation: Isolate.packageConfig` via `build_test`) ;
- comptes par paquet, mesurés à la clôture de chaque lot : `zcrud_core` 2699, `zcrud_study`
  2304, `zcrud_session` 727, `zcrud_flashcard` 655, `zcrud_ui_kit` 340, `zcrud_themes` 107 ;
- aucun résidu d'injection R3 (`grep --no-ignore-files -a`), aucun `if (false` en
  production.

Les gardes de cette version ont été posées sous discipline R3 — rouge **par assertion**,
restauration par copie de fichier, sha256 publiés avant/après, résidus prouvés par grep
négatif. **Quatorze gardes étaient vertes au premier passage sous injection** ; aucune n'a été
déclarée solide — toutes reformulées sur la propriété réelle. Trois constats donnés pour
sûrs par l'orchestrateur se sont révélés faux, et les agents qui ont refusé d'exécuter
avaient raison : un plan se mesure avant de s'exécuter.
