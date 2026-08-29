# Changelog

Format « Keep a Changelog » (sections Ajouté / Modifié / Corrigé, versions
antéchronologiques). Toutes les modifications notables de `zcrud_ui_kit`
sont documentées ici.

## 3.29.0 — 2026-08-28

### Modifié

#### 🔴 L'app-bar de `ZPageShell` porte une teinte d'identité PAR DÉFAUT

Rupture volontaire. Jusqu'ici, une page sans `gradientKey` rendait une app-bar
sans teinte. Désormais, quand `gradientKey` n'est **pas** déclarée, le shell
dérive une identité — `signatureKey` s'il est fourni, sinon **le titre lorsque
c'est une chaîne** — et résout la clé `zcrud.signature.<identité>` de
`zcrud_core`. La teinte obtenue est posée en **lavis** sur l'app-bar
(quatre arrêts verticaux à 15 / 10 / 5 / 2 % de la teinte de base), et
l'élévation de la barre passe à 0.

Pourquoi un lavis et non le dégradé plein : sur les 67 app-bars du code de
référence, **une seule** porte un dégradé, et elle le pose exactement sous cette
forme — une teinte de base déclinée sur cette rampe d'opacité, titre laissé à
la couleur héritée. Peindre le dégradé à saturation pleine aurait été un choix
esthétique, pas une reprise du vécu. Le chemin `gradientKey` **explicite**, lui,
garde la saturation pleine et son `onGradient` : il est strictement inchangé.

Le premier plan de la barre n'est **pas** remplacé tant que celui en vigueur
tient 4.5:1 contre la bande la plus dense du lavis — ce qui est le cas courant.
Il n'est mesuré et posé que si ce plancher tombe.

**Trois échappatoires**, de la plus large à la plus locale :

1. `ZcrudScope(theme: ZcrudTheme(referenceProfile: ZReferenceProfile.neutral))`
   à la racine : rendu **strictement** identique à celui d'avant, partout —
   arbre, rectangles et décorations compris ;
2. `gradientKey: ''` sur une page : aucune teinte sur cette page ;
3. un titre `Widget` (et non `String`) sans `signatureKey` ne dérive aucune
   identité : la page reste sans teinte.

⚠️ Un hôte qui **posait déjà** un dégradé d'app-bar à la main au-dessus de
`ZPageScaffold` / `ZPageShellBody` / `ZSearchableAppBar` verra les deux se
superposer : sa compensation est à retirer, ou le profil neutre à poser.

### Ajouté

#### `signatureKey` sur les trois façades de page

`ZSearchableAppBar`, `ZPageScaffold` et `ZPageShellBody` acceptent une identité
explicite pour la teinte d'app-bar, indépendante du titre affiché. Priorité :
`gradientKey` > `signatureKey` > titre-chaîne.

#### `ZPageShellReference` — les métriques auditées du chrome

Fichier de référence **sans aucune couleur** (garde de source à l'appui) :
rampe d'opacité du lavis, élévation sous lavis, rayon et ombre du bouton
d'action flottant, taille de glyphe, graisse et interlettrage du libellé, rayon
et coche des puces. Les teintes, elles, viennent toutes de la palette signature
de `zcrud_core` ou des rôles du `ColorScheme` de l'hôte.

#### `ZGradientFab` — bouton d'action flottant d'identité

Fond dégradé à coins arrondis (rayon 20) et ombre reprenant la teinte de base
(opacité 0.4, flou 20, décalage (0, 8)), bouton lui-même transparent et sans
élévation, glyphe à 22, libellé en `w600` / interlettrage 0.3. Le premier plan
est `ZGradientSpec.onGradient` — **mesuré**, là où le code de référence décrète
un blanc qui tombe sous le plancher de contraste sur quatre des cinq teintes de
la palette.

Sans dégradé résolu — profil neutre, `gradientKey: ''`, ou palette vide — le
widget rend un `FloatingActionButton` Material **nu** : aucun conteneur, aucune
ombre, aucune couleur posée.

#### `ZChoiceChipStyle` / `zChipThemeFor` — style transversal des puces

Forme à rayon 12, coche masquée, teinte de sélection issue de la palette
signature sous `legacy` et de `ColorScheme.primary` sous `neutral`, couleur du
libellé sélectionné **mesurée** contre cette teinte. Le `ChipThemeData` produit
ne renseigne que ces quatre créneaux : il fusionne sur le thème de l'hôte au
lieu de l'écraser.

Aucun widget de ce paquet ne rend de puce : ce style est un utilitaire offert
aux hôtes, à poser dans un `ChipTheme`.

#### `ZEmptyState` consomme les jetons `emptyState*`

Taille et couleur du glyphe, styles du titre et du message, rythme vertical :
tout vient désormais de `ZEmptyStateStyle.resolve(context)`, donc des jetons
`emptyState*` de `ZcrudTheme`. Ces styles existaient depuis la 3.28.0 mais
**aucun widget ne les lisait** : la boucle « jeton → pixel » n'était pas fermée,
et un hôte qui posait `emptyStateIconSize` ne voyait rien changer.

Les replis du style de `zcrud_core` coïncident exactement avec les valeurs qui
étaient codées ici (48 dp, `onSurfaceVariant`, `titleMedium`, `bodyMedium`,
`gapL` = 16) : **aucun jeton posé ⇒ rendu strictement identique**, arbre, rects
et couleur d'icône figés avant modification et vérifiés après.

Trois créneaux nouveaux :

* `illustration: Widget?` — **remplace** le glyphe quand il est fourni (image de
  marque, `SvgPicture`, animation). L'arbitrage a lieu à un seul endroit ;
* `iconSize: double?` — priorité stricte **paramètre > jeton > défaut** ;
* `compact: bool` — variante dense : retrait 24 → 12 dp, rythme divisé par deux.
  La taille du glyphe n'est délibérément pas touchée, pour qu'une densité ne
  réécrive pas une décision de thème.

Les jetons `emptyState*` ne pilotent **que** l'état vide : `ZErrorState` garde
ses mesures, et une garde le vérifie.

#### `ZEmptyStateSpec` + `ZEmptyState.fromSpec` — l'état vide en données

Un état vide décrit par clés (`titleKey`, `messageKey`, `actionLabelKey?`,
`iconData?`, `illustrationBuilder?`), résolu au rendu contre un `ZcrudLabels`.
Une clé absente rend la clé elle-même — un libellé manquant dégrade l'écran, il
ne le fait jamais échouer.

**La table par nature de contenu appartient à l'appelant.** Ce paquet est
transverse : il ne nomme aucune nature (dossiers, cartes, notes…), sous peine
d'y cacher une dépendance métier.

#### `showZConfirmDialog` consomme les jetons `confirmDialog*` et gagne trois créneaux

Forme, styles du titre et du message, retrait des actions et couleur de l'action
destructive viennent de `ZConfirmDialogStyle.resolve(context)`. Le régime de
nullité du dialogue est **différent** de celui de l'état vide : les jetons sont
transportés `null` jusqu'à `AlertDialog`, qui suit alors le `DialogTheme` puis
son défaut Material. Sans jeton, le dialogue est au pixel près celui d'avant.

Créneaux : `icon: Widget?` (au-dessus du titre), `content: Widget?` (remplace le
rendu du message — qui reste requis et reste le libellé sémantique du dialogue
sans titre), `barrierDismissible: bool`.

La tonalité destructive reste portée par `ZConfirmTone.destructive`, pas par un
`bool isDestructive` : le paquet a fait le choix de l'enum contre le booléen, et
deux sources de vérité pour la même décision auraient dû être réconciliées à
chaque appel.

#### `ZSkeleton` / `ZSkeletonList` — l'attente en forme du contenu à venir

Trois formes (`line`, `box`, `tile`) et une liste virtualisée. Les deux teintes
du battement sont des **rôles Material 3** (`surfaceContainerHighest`,
`surfaceContainerHigh`) : aucun littéral de couleur, aucune opacité magique,
aucune dépendance tierce (`skeletonizer`/`shimmer`), et une garde de source le
vérifie fichier en main.

L'animation passe par `ZColorCycle` : un seul contrôleur, créé uniquement quand
le squelette est actif, libéré au démontage. Sous « Réduire les animations »
aucun contrôleur n'est créé et la forme **reste peinte**. L'ensemble est muet
pour les lecteurs d'écran — sans quoi une liste de squelettes annoncerait une
zone défilable vide.

### Corrigé

#### Un dialogue n'héritait pas des jetons posés par `ZcrudScope`

Une route de dialogue est poussée sur le `Navigator` : elle hérite du `Theme`
(capturé par `showDialog`) mais **pas** d'un `InheritedWidget` ordinaire. Des
jetons `confirmDialog*` posés par `ZcrudScope(theme:)` étaient donc invisibles
depuis le dialogue — seuls ceux passés par `ThemeData.extensions` arrivaient.

`showZConfirmDialog` résout désormais le style **au point d'appel**, dans le
contexte de l'écran, et le transporte par le nouveau paramètre
`ZConfirmDialog.style`. Utilisé directement dans un arbre, `ZConfirmDialog`
continue de résoudre depuis son propre contexte.

## 2.4.0 — 2026-08-17

### Modifié

#### Le titre d'une confirmation devient optionnel

`showZConfirmDialog` et `ZConfirmDialog` imposaient un `title`. La confirmation
du moteur legacy n'en affichait **aucun** — son titre était explicitement
**commenté** dans le source. Un hôte portant ses gestes destructifs devait donc
**inventer** des libellés que rien ne permet de vérifier contre une référence, le
message portant déjà la question en entier.

Le coût réel n'était pas le bruit visuel mais la **localisation** : dans un module
traduit en dix langues sans clé de titre générique, les seules issues étaient une
chaîne en dur, dix fichiers à modifier pour un mot jamais affiché, ou le
détournement d'une clé voisine.

`title: null` ⇒ **aucun `AlertDialog.title` dans l'arbre** — pas un titre vide,
pas un `SizedBox`, et **surtout aucun défaut inventé par le socle** : un socle qui
invente un titre recrée le même problème un étage plus bas, et l'hôte ne saurait
pas le retirer. Sans titre, le dialogue reste correctement annoncé (route nommée
et cadrée).

**Rétrocompatibilité totale** : tout appelant passant un titre garde exactement le
rendu actuel.

## 0.93.0 — 2026-08-13

### Ajouté

- **`ZCountBadge`** — pastille de comptage réutilisable : seule, ou posée sur un
  contenu (icône de barre, avatar). Le nombre est **annoncé**
  (`semanticsLabel` nomme ce qui est compté), la cible tactile passe à **48 dp**
  dès que la pastille est cliquable, le placement est **directionnel**
  (bascule en RTL) et toutes les couleurs sont dérivées du `ColorScheme` —
  aucune valeur littérale. Zéro n'affiche rien (`showZero` pour l'imposer), et
  les grands nombres sont écrêtés à l'affichage (`99+`) sans altérer l'annonce.

### Modifié

- Chantier documentation : README réécrit au gabarit du monorepo, dartdoc de
  l'API publique normalisée (orientée consommateur), fiche `docs/site/paquets/`
  ajoutée, `public_member_api_docs` activé.

Historique antérieur : voir `git log` sur `packages/zcrud_ui_kit/`.
