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
de carte, deux fonds de page et deux fonds de carte, trois rayons, deux bandeaux
de tête, six confettis et une médaille de fin de session.

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

### Deux jetons délibérément laissés vides

| Jeton | Pourquoi il reste `null` |
|---|---|
| `flashcardCardShadowColor` | Le rendu de référence dérive la teinte de l'ombre du dégradé du **type** de carte : elle vaut quatre couleurs, là où le jeton n'en porte qu'une. En figer une repeindrait les trois autres. |
| `studySessionDividerColor` | L'écran de référence ne trace **aucun** trait entre la pile et la zone de notation : la notation y vit dans la carte. Il n'y a rien à relever. |

Dans les deux cas, le rôle de l'hôte (`shadowColor`, `outlineVariant`) reste le
repli, et une garde vérifie que ces jetons ne se remplissent pas en silence. Un
jeton vide est une valeur non mesurée ; ce n'est pas un oubli.

### Les dégradés par type sont ceux du socle

Le thème pose explicitement le jeton `ZcrudTheme.flashcardTypeGradients` avec
une table **strictement égale** à `ZFlashcardCardReference.typeGradients` : mêmes
clés, mêmes arrêts, même sens, mêmes premiers plans. Adopter Classic ne change
donc aucun dégradé de carte par rapport au rendu par défaut — le thème rend
seulement explicite, au maillon jeton, ce que le socle applique déjà au dernier
maillon.

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
