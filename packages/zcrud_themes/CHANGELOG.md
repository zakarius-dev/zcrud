# Changelog — zcrud_themes

## 3.50.0 — 2026-09-09

### Corrigé — la documentation disait le contraire de la chaîne réelle

Le socle a fait passer le **seam** `ZcrudScope.gradientResolver` **devant** le
jeton `ZcrudTheme.flashcardTypeGradients` sur les deux cartes de flashcard
(`z_flashcard_review_card.dart:912-928`,
`z_default_flashcard_card.dart:439-457`). La documentation de ce paquet
présentait encore le jeton comme le maillon que « seul un paramètre de widget
dépasse » : un hôte qui adoptait Classic **et** branchait son propre résolveur
pouvait en conclure que le thème gagnait, alors que c'est son résolveur qui
peint.

Corrigé dans la dartdoc de `ZClassicTheme`, dans celle de
`ZClassicCardGradientsReference` et dans le `README.md` : la chaîne des dégradés
par type est **`paramètre > seam > jeton > référence`**, et le jeton posé par le
thème est un **repli**, consulté quand le résolveur se tait. Aucune valeur ne
change ; c'est la description qui était fausse.

Une garde nouvelle monte la carte réelle et mesure le dégradé **peint** dans les
trois cas : thème seul (le jeton peint), thème + résolveur d'hôte étranger (le
résolveur peint, le jeton est écarté), thème + résolveur Classic (les deux
concordent). Aucune garde du paquet n'assertait l'ancien ordre — il n'y en avait
donc pas à retourner.

### Ajouté

- **`ZClassicSurfaceReference.cardAccentHeight`** (4 dp) — l'épaisseur mesurée du
  liseré de tête d'une carte de révision, à passer en **paramètre**
  (`cardAccentHeight` de l'écran de session, ou `accentHeight` de la carte).

### Délibérément non posé

| Jeton | Raison |
|---|---|
| `accentBarHeight` | Jeton **global** : il gouverne aussi le liseré des cartes de dossier (`z_folder_card_chrome.dart:32`) et celui des champs de formulaire (`z_field_widget.dart:613`), qui le lisent **nu** — aucun paramètre pour s'y soustraire. Mesuré au montage : posé, il fait apparaître le liseré de la carte (60 → 67 nœuds d'arbre) **et** celui de chaque champ dès que l'hôte branche un résolveur de dégradés large (61 → 64 nœuds). Le rendu dépendrait de ce que l'hôte a branché par ailleurs. La valeur est publiée à part, pour la voie paramètre. |
| Les **huit** jetons de chrome de page (`appBarWashAlphas`, `appBarWashElevation`, `fabShape`, `fabElevation`, `fabIconSize`, `fabLabelStyle`, `choiceChipShape`, `choiceChipShowCheckmark`) | Leur valeur mesurée est **déjà celle qui peint** : `ZPageShellReference` (`zcrud_ui_kit`) porte la rampe de lavis `[0.15, 0.10, 0.05, 0.02]`, l'élévation nulle sous lavis et les métriques de bouton et de puce, et chaque consommateur résout `jeton ?? référence` **sans condition**. Les poser écrirait la valeur déjà peinte — un second canal vers le même pixel. |

### Gardes

- **Précédence seam > jeton (`z_classic_gradient_seam_precedence_test.dart`)** —
  la carte de révision est montée pour de bon et le dégradé **peint** est lu sur
  la décoration du liseré, jamais sur le passage d'un jeton. Trois cas mesurés,
  et la non-vacuité asserte que le liseré existe (sans hauteur, la carte n'en
  monte aucun et la garde serait verte pour rien).
- **Jetons non posés (`z_classic_unposed_tokens_test.dart`)** — les neuf jetons
  restent `null` dans les deux luminosités, sous non-vacuité. La garde ne
  s'arrête pas là : elle lit sur disque les **trois** consommateurs de
  `accentBarHeight` et vérifie que deux d'entre eux le lisent **nu** (c'est ce
  qui rend le jeton global), et elle lit les **huit** chaînes
  `jeton ?? ZPageShellReference.<x>` de `zcrud_ui_kit` en comparant la rampe de
  référence à la valeur mesurée. Si la référence cesse d'être la valeur
  d'origine, la garde rougit — et c'est alors qu'il faudra poser le jeton.

## 3.49.0 — 2026-09-08

### Ajouté

- **Le paquet.** Un porteur de valeurs de design : palettes auditées et
  fabriques de `ZcrudTheme`. Il ne rend aucun widget et ne nomme aucune
  application hôte — deux propriétés vérifiées par machine.
- **Thème « Classic »** (`ZClassicTheme`), adoptable en une ligne :
  `ZcrudScope(theme: ZClassicTheme.of(context), colorKeyResolver:
  ZClassicTheme.colorKeys, gradientResolver: ZClassicTheme.gradients, …)`.
  - `ZClassicSrsPaletteReference` — cinq paliers de notation SM-2 (teinte,
    premier plan mesuré, glyphe, clés de couleur / libellé / aperçu).
  - `ZClassicCardGradientsReference` — quatre dégradés par type de carte, dans
    la forme du jeton `ZcrudTheme.flashcardTypeGradients`.
  - `ZClassicSurfaceReference` — fonds de page et de carte par luminosité,
    rayons 20 / 14 / 12, bandeaux de tête, plancher tactile 48 dp.
  - `ZClassicCelebrationReference` — six confettis et la médaille de fin de
    session.
- **Fond de la carte de flashcard** — le thème pose
  `ZcrudTheme.flashcardCardBackgroundColor`, par luminosité (`#1A1F2E` en
  sombre, blanc en clair). Sans lui, la carte retombait sur le rôle
  `scaffoldBackgroundColor`, donc sur le fond de PAGE : elle se confondait avec
  son écran. Contraste vérifié contre `onSurface` et `onSurfaceVariant` de
  l'hôte, plancher texte 4,5:1.
- **Alimentation par défaut des quatre seams de notation** :
  `qualityColorKeyFor`, `qualityLabelKeyFor`, `qualityEmphasis`, et
  `previewLabelFor(label)` — un adaptateur qui compose la clé du thème avec le
  résolveur l10n de l'hôte, de sorte que le texte affiché reste produit par
  l'application.
- **`ZThemeCatalog` / `ZThemeSpec`** — registre de thèmes **ouvert** : un hôte
  ou un paquet tiers enregistre son thème sans modifier ce dépôt.

### Délibérément non posé

Deux jetons de couleur restent `null`, faute de valeur **mesurable** — et non
par oubli. Une garde vérifie qu'ils ne se remplissent pas en silence.

| Jeton | Raison |
|---|---|
| `flashcardCardShadowColor` | La teinte de l'ombre y est dérivée du dégradé du **type** de carte : quatre couleurs pour un jeton qui n'en porte qu'une. |
| `studySessionDividerColor` | Le rendu de référence ne trace aucun trait entre la pile et la zone de notation. |

Les rôles de l'hôte (`shadowColor`, `outlineVariant`) restent le repli : le
rendu est celui d'aujourd'hui.

### Corrigé par rapport aux valeurs relevées (améliorations non divergentes)

Quatre valeurs du rendu d'origine échouaient un plancher de contraste WCAG et
ont été corrigées au minimum nécessaire, chacune dans la même famille
chromatique. Aucun échec n'est masqué : une garde recalcule les ratios.

| Valeur | Origine | Retenue | Ratio |
|---|---|---|---|
| Palier `hard` | `#FF9800` | `#E65100` | 2.06:1 → 3.62:1 sur le fond clair |
| Palier `good` | `#2196F3` | `#1E88E5` | 2.99:1 → 3.52:1 sur le fond clair |
| Palier `perfect` | `#4CAF50` | `#388E3C` | 2.66:1 → 3.93:1 sur le fond clair |
| Premier plan de la médaille | blanc | noir | 1.66:1 → 12.62:1 |

Les paliers `fail` (3.52:1) et `easy` (3.51:1) tiennent le plancher et sont
repris à l'octet, comme les quatre dégradés par type (3.0:1 au pire cas sur la
bande médiane).

### Note pour les intégrateurs

**Les dégradés par type sont ceux du socle, à l'octet.** Le thème pose
explicitement `ZcrudTheme.flashcardTypeGradients` avec une table
**strictement égale** à `ZFlashcardCardReference.typeGradients`
(`zcrud_study`) : mêmes clés, mêmes arrêts, même sens, mêmes premiers plans.
Adopter Classic ne change donc **aucun** dégradé de carte par rapport au rendu
par défaut du socle — le thème rend seulement explicite, au maillon JETON, ce
que le socle applique déjà au dernier maillon. Le thème reste autoportant (il
n'importe rien de `zcrud_study`) **et** prioritaire (le jeton passe devant la
référence), mais aucune divergence ne peut s'installer sans être détectée.

Le code de référence historique porte **deux** tables de dégradés par type,
dans deux widgets différents, inversées l'une par rapport à l'autre sur
`openQuestion` et `exercise`. Le socle retient celle de la carte de
grille/liste (`openQuestion` bleu → cyan, `exercise` rose → corail) ; le thème
retient désormais la même. Un hôte qui aurait câblé Classic sur la table
inversée verra ces deux types échanger leur dégradé.

L'**ordre** de la palette signature du thème est resté celui de
`ZSignaturePaletteReference.gradients` : il décide quelle couleur reçoit une
identité de section, et n'a pas suivi le renommage des types. Aucune identité
de section ne change de couleur.

### Gardes

**Pureté FR-26 (`z_color_purity_test.dart`)** — aucun littéral de couleur nulle
part dans `lib/`, sauf dans les quatre fichiers de référence audités, exemptés
**nominativement par chemin exact**. La garde couvre `Color(0x…)`,
`Color.fromARGB(`, `Color.fromRGBO(`, `Colors.<nom>`, l'hexadécimal de couleur
écrit hors `Color(`, `Color(<décimal>)` y compris multi-ligne, `Color.from(`
à composante littérale, et l'entier décimal dans la plage ARGB opaque. Trois
contre-preuves tiennent l'exemption : un chemin exempté absent du disque
rougit, un fichier exempté sans couleur rougit, et le même contenu placé sous
un chemin voisin rougit.

**Pureté des libellés (`z_label_purity_test.dart`)** — tout littéral de chaîne
du code de `lib/` doit avoir une forme de **clé** l10n, interpolations
retirées. Un texte affichable (accentué, multi-mots, capitalisé, ponctué) fait
rougir. Deux corps de `toString()` sont exemptés nominativement par chemin
**et** par contenu, sous les mêmes trois contre-preuves.

**Égalité stricte avec le socle (`z_socle_gradient_parity_test.dart`)** — la
table de dégradés par type posée par le thème est comparée, entrée par entrée,
à celle du socle. La garde **lit la source réelle** de
`z_flashcard_card_reference.dart` sur disque (ancrage par remontée jusqu'au
dossier portant `melos.yaml`) plutôt qu'une copie figée : une table recopiée
dans le test resterait verte le jour où le socle change. Aucune arête de
dépendance n'est ouverte vers `zcrud_study`, pas même en `dev_dependencies`.
L'extraction **lève** plutôt que de rendre une table vide, pour qu'un
reformatage du socle fasse rougir au lieu de rendre la garde creuse, et le
nombre de clés lues est asserté. Neuf contre-preuves prouvent la morsure des
**deux côtés** : arrêt changé, premier plan changé, sens inversé, clé en trop,
clé en moins, et les deux entrées ré-inversées — tantôt en mutant le texte du
socle, tantôt la table du thème. La palette signature est comparée de la même
façon aux quatre premières entrées de `ZSignaturePaletteReference.gradients`,
avec l'assertion de longueur qui empêche un `take(4)` de comparer moins.

La même garde couvre le **préfixe de clé de dégradé** que le thème recopie au
lieu de l'importer (pour ne pas ouvrir d'arête vers le paquet d'étude) : elle
lit la déclaration du socle sur disque et vérifie que le résolveur du thème
répond aux clés que le socle **compose réellement**, avec la contre-preuve
qu'un préfixe étranger reste sans réponse. Ce préfixe était jusqu'ici annoncé
comme gardé sans l'être.

Aucun widget exporté ; aucun nom d'application dans `lib/` ; inertie absolue
(arbre et couleurs peintes strictement identiques sans le thème) ; priorité
`paramètre > jeton > référence` prouvée à trois niveaux distincts ; contrastes
WCAG recalculés ; table de valeurs figée dans le test, recopiée de la source
avec ses `fichier:ligne` ; registre prouvé ouvert.
