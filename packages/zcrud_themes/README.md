# zcrud_themes

Thèmes visuels **nommés** pour zcrud : des palettes auditées et des fabriques de
`ZcrudTheme` prêtes à poser, qui habillent les widgets **existants** de la boîte
à outils.

## Ce que ce paquet est

Un **lieu**, pas un mécanisme. Le socle savait déjà habiller ses widgets —
`ZcrudTheme` et ses jetons, `ZReferenceProfile`, la chaîne
`paramètre > jeton > référence`, les seams `colorKeyResolver` /
`gradientResolver`. Ce qui manquait, c'était un endroit où loger des palettes
nommées, complètes et cohérentes, sans les imposer à personne.

Un thème d'ici ne fait que **remplir des jetons** et **alimenter des seams** que
le socle interroge déjà.

## Ce que ce paquet n'est PAS

**Il ne rend aucun widget.** Il n'exporte que des valeurs de design et des
fabriques. Un widget ici créerait un second rendu, concurrent de celui des
paquets d'écrans — le doublon exact qu'une boîte à outils partagée existe pour
supprimer. Une garde le vérifie sur toute la surface publique
(`test/z_no_widget_export_test.dart`).

Il ne rend pas non plus de **texte affiché** : il produit des **clés** l10n, que
l'application traduit dans sa langue.

Enfin, il n'est le défaut de personne. Aucun écran ne change tant qu'un hôte n'a
pas posé le thème explicitement — une garde d'inertie mesure les couleurs
réellement peintes avec et sans les résolveurs branchés, et exige l'égalité
stricte.

## Adoption — une ligne, à la racine

```dart
ZcrudScope(
  theme: ZClassicTheme.of(context),
  colorKeyResolver: ZClassicTheme.colorKeys,
  gradientResolver: ZClassicTheme.gradients,
  child: MonApp(),
)
```

Pour que les crans de notation prennent l'identité du thème, les quatre seams de
la surface de session :

```dart
ZFlashcardAnswerInput(
  qualityColorKeyFor: ZClassicTheme.qualityColorKeyFor,
  qualityLabelKeyFor: ZClassicTheme.qualityLabelKeyFor,
  qualityPreviewLabelFor: ZClassicTheme.previewLabelFor(monResolveurL10n),
  qualityEmphasis: ZClassicTheme.qualityEmphasis,
  // …
)
```

`previewLabelFor` prend le résolveur l10n de l'application, parce que l'aperçu
d'intervalle est une phrase : le paquet fournit la clé, l'hôte fournit le texte.

## Le thème « Classic »

Cinq paliers de notation (teinte, premier plan, glyphe), quatre dégradés par type
de carte, deux fonds de page et deux fonds de carte, quatre rayons, trois formes
de la surface de saisie, deux bandeaux de tête, six confettis et une médaille de
fin de session.

Toutes les valeurs sont **mesurées** sur un rendu réel et recopiées avec leur
`fichier:ligne` d'origine ; une table figée dans les tests les compare une à une.
Les couleurs vivent exclusivement dans les quatre fichiers de référence audités
de `lib/src/themes/classic/` — jamais éparpillées dans le code.

### Le fond de la carte de flashcard

Le thème pose `ZcrudTheme.flashcardCardBackgroundColor`, **par luminosité** : la
carte reçoit son propre fond au lieu de retomber sur le rôle
`scaffoldBackgroundColor`, c'est-à-dire sur le fond de page qui la confondait
avec son écran. C'est la plus grande surface de l'écran de révision.

Le contraste est vérifié contre le texte que l'hôte y peint réellement
(`onSurface` et `onSurfaceVariant` du `ColorScheme` de la luminosité), au
plancher texte 4,5:1 — jamais contre un candidat théorique.

### Le rayon de la carte de flashcard

Le thème pose `ZcrudTheme.flashcardCardRadius` à **20**, là où les cartes et les
champs valent 14. Sans ce jeton, la carte de révision suivait `radiusM`,
c'est-à-dire le rayon des **champs de saisie** : la relever aurait obligé à
arrondir aussi toutes les zones de texte de l'application.

Ce jeton n'est **pas** global, et c'est mesuré : une garde balaie les `lib/` de
tous les paquets et vérifie que la carte de révision en est le **seul** lecteur.
Le poser n'atteint donc aucune autre surface — ni les cartes de liste, ni les
cartes de dossier, ni les champs. Le jour où une seconde surface se met à le
lire, la garde rougit et l'arbitrage est à refaire.

### Les formes de la surface de saisie notée

Trois réglages de **forme** sont posés, tous mesurés sur le rendu de référence en
largeur mobile :

| Jeton | Valeur | Rendu |
|---|---|---|
| `answerInputChoiceLayout` | `tile` | la ligne de choix devient une tuile : fond, liseré, coins ; le liseré s'épaissit sur la ligne sélectionnée |
| `answerInputActionsLayout` | `sideBySide` | « indice » et « je ne sais pas » partagent une ligne, à parts égales, pourtour tracé |
| `answerInputSubmitWidth` | `full` | le contrôle de soumission occupe la largeur entière |

**Aucune couleur n'est posée avec elles.** Le fond de la tuile est le
`surfaceColor` que le thème pose déjà ; le liseré et les pourtours restent des
rôles du `ColorScheme` de l'hôte et des clés du seam de couleur. Le contraste des
combinaisons réelles est recalculé par une garde, aux deux luminosités : le texte
d'une tuile tient 4,5:1 (9,3:1 au pire mesuré) et le liseré **sélectionné** —
celui qui porte l'information — tient 3,0:1 (6,4:1 au pire).

Les traits qui ne font que **grouper** (pourtour d'une tuile non sélectionnée,
pourtours des deux contrôles d'aide) restent sous 3,0:1 : ils retombent sur
`outlineVariant` et sur des rôles conteneur, qu'aucun jeton de ce thème
n'atteint. Ce n'est pas un défaut d'accessibilité — ce qui identifie ces éléments
est leur libellé, et la sélection est portée par l'**épaisseur** du trait, jamais
par sa seule teinte. L'arbitrage est figé par une garde qui rougira si ces rôles
changent.

### Trois jetons délibérément laissés vides

| Jeton | Pourquoi il reste `null` |
|---|---|
| `flashcardCardShadowColor` | Le rendu de référence dérive la teinte de l'ombre du dégradé du **type** de carte : elle vaut quatre couleurs, là où le jeton n'en porte qu'une. En figer une repeindrait les trois autres. |
| `studySessionDividerColor` | L'écran de référence ne trace **aucun** trait entre la pile et la zone de notation : la notation y vit dans la carte. Il n'y a rien à relever. |
| `answerInputGradingVisibility` | Ce n'est pas une forme : `always` rend la rangée de paliers active **avant** toute réponse, et un palier tapé y vaut notation manuelle — la saisie devient inerte et la soumission disparaît. Un thème ne change pas l'ordre des gestes d'une session. |

Dans les trois cas, le repli (`shadowColor`, `outlineVariant`, la référence de la
surface) reste en place, et une garde vérifie que ces jetons ne se remplissent
pas en silence. Un jeton vide est une valeur non mesurée, ou une décision qui
n'appartient pas à un thème ; ce n'est pas un oubli.

La géométrie d'ombre (`cardShadowBlurRadius`, `cardShadowOffset`,
`cardShadowAlpha`) reste vide elle aussi, et pour une raison plus forte que sa
portée globale : la carte de révision teste ce trio **avant** la teinte et rend
immédiatement, en prenant sa couleur du rôle `CardThemeData.shadowColor`. Le
poser rendrait donc le paramètre `shadowColor` de la carte **inerte** — c'est la
seule voie par laquelle un écran peut donner à chaque carte l'ombre teintée de
son type.

L'ordre des gestes se règle là où il se décide, jamais dans la peinture :

```dart
ZFlashcardAnswerInput(
  gradingVisibility: ZAnswerGradingVisibility.always,
  // …
)
```

### Le liseré de carte : une valeur mesurée, passée en paramètre

Le liseré de tête d'une carte de révision vaut **4 dp** dans le rendu de
référence, et cette valeur est publiée —
`ZClassicSurfaceReference.cardAccentHeight`. Elle n'est **pas** posée sur le
jeton `ZcrudTheme.accentBarHeight`, qui est global : il gouverne aussi le liseré
des cartes de dossier et celui des champs de formulaire, deux surfaces qui le
lisent **nu**, sans paramètre pour s'y soustraire. Mesuré au montage : posé, il
fait apparaître le liseré de la carte, **et** celui de chaque champ dès que
l'hôte branche un résolveur de dégradés large. Le rendu dépendrait donc de ce
que l'hôte a branché par ailleurs.

La valeur se passe donc là où elle a été mesurée :

```dart
ZStudySessionScaffold(
  cardAccentHeight: ZClassicSurfaceReference.cardAccentHeight,
  // …
)
```

Un hôte qui veut bel et bien les trois liserés pose lui-même
`accentBarHeight` — c'est son arbitrage, et il reste possible.

### Le chrome de page : rien à poser

Les huit jetons de chrome de page (`appBarWashAlphas`, `appBarWashElevation`,
`fabShape`, `fabElevation`, `fabIconSize`, `fabLabelStyle`, `choiceChipShape`,
`choiceChipShowCheckmark`) restent `null`, et c'est **mesuré** : leur valeur
d'origine est déjà celle que le dernier maillon peint. `ZPageShellReference`
(`zcrud_ui_kit`) porte la rampe de lavis `[0.15, 0.10, 0.05, 0.02]`, l'élévation
nulle sous lavis et les métriques de bouton et de puce, et chaque consommateur
résout `jeton ?? référence` **sans condition**. Les poser ici écrirait la valeur
déjà peinte : un second canal vers le même pixel. Une garde compare la rampe de
référence à la valeur mesurée et rougit si l'une des deux bouge — c'est alors
qu'il faudra poser le jeton, pas avant.

### Les dégradés par type sont ceux du socle

Le thème pose explicitement le jeton `ZcrudTheme.flashcardTypeGradients` avec
une table **strictement égale** à `ZFlashcardCardReference.typeGradients` : mêmes
clés, mêmes arrêts, même sens, mêmes premiers plans. Adopter Classic ne change
donc aucun dégradé de carte par rapport au rendu par défaut — le thème rend
seulement explicite, au maillon jeton, ce que le socle applique déjà au dernier
maillon.

**Ce jeton est un repli, pas une décision.** Les deux cartes qui le lisent
consultent d'abord le seam `ZcrudScope.gradientResolver` : la chaîne réelle est
`paramètre > seam > jeton > référence`. Un hôte qui branche son propre résolveur
de dégradés par type voit **son** résolveur peindre, thème posé ou non ; le
jeton ne sert que là où le résolveur se tait. Un hôte qui veut au contraire que
sa table l'emporte ne pose pas de résolveur pour ces clés. Une garde monte la
carte réelle et vérifie les deux sens.

Ce n'est pas une promesse : une garde lit la **source réelle** du socle sur
disque et compare entrée par entrée, sans ouvrir la moindre arête de dépendance
vers `zcrud_study`. Elle rougit si l'un **ou l'autre** des deux côtés bouge — et
neuf contre-preuves vérifient qu'elle mord dans les deux sens.

**Améliorations non divergentes.** Quatre valeurs d'origine échouaient les
planchers de contraste WCAG et ont été corrigées au minimum nécessaire : trois
teintes de palier (invisibles sur le fond clair du thème) et le premier plan de
la médaille (illisible, 1.66:1). Le détail est dans le `CHANGELOG.md` et dans les
commentaires des fichiers de référence. Une garde recalcule les ratios : rien
n'est affirmé sur parole.

## Ajouter un thème

Le registre est **ouvert** : ni `enum`, ni hiérarchie `sealed`.

```dart
ZThemeCatalog.register(const ZThemeSpec(id: 'nuit', labelKey: 'app.theme.nuit'));
```

## Dépendances

`zcrud_core` (la cible produite et les seams alimentés), `zcrud_session` (les
seams de notation), `zcrud_flashcard` (les types de carte). Aucune dépendance
tierce.
