# Changelog

Toutes les modifications notables de `zcrud_study` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

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
