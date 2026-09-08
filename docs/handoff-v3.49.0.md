# Handoff v3.49.0 — un paquet de thèmes nommés, et une chaîne de résolution réparée

Cette version répond à une question posée par une application hôte : les jetons de
session étant **tous géométriques**, une identité visuelle typée est-elle condamnée à
passer par la réimplémentation ? La réponse tenait en une phrase dans le handoff
précédent ; elle tient désormais en un paquet.

## Clés de schéma ajoutées

**Aucune.** Aucune entité persistée n'est touchée ; aucune migration n'est requise.

## Le nouveau paquet `zcrud_themes`

Un paquet **opt-in** qui groupe des **thèmes nommés**. Le premier s'appelle « Classic ».

```dart
ZcrudScope(
  theme: ZClassicTheme.of(context),
  colorKeyResolver: ZClassicTheme.colorKeys,
  gradientResolver: ZClassicTheme.gradients,
  child: MonApp(),
)
```

Ce qu'il est, et ce qu'il n'est **pas** :

- il **ne rend aucun widget**. Il porte des valeurs de design et des fabriques de
  `ZcrudTheme` : il **habille** les widgets existants du socle, il ne les double pas.
  Une garde le prouve — aucun symbole exporté n'étend `Widget` ;
- il ne nomme **aucune application** : une palette porte un nom de thème, jamais un nom
  d'hôte. Garde de source ;
- il n'exporte que des **clés** de traduction, jamais un texte affichable. Garde de source ;
- il est un **puits** du graphe : rien ne dépend de lui, donc une application qui n'en veut
  pas n'en porte pas le poids — ni son code, ni ses dépendances.

### Ce que le thème ne porte pas, et pourquoi

Le thème **ne redéfinit pas** les dégradés par type de carte au-delà de ce que le socle
porte déjà : sa table est **strictement égale** à `ZFlashcardCardReference.typeGradients`,
et une garde lit la source du socle pour le prouver — elle rougit si l'un des deux côtés
change. Une seule table fait foi.

⚠️ Note pour qui voudrait « compléter » le thème plus tard : la référence visuelle
d'origine porte **deux** tables de dégradés, dans deux widgets différents, mutuellement
inversées sur deux types. Le socle en retient **une**. Ce n'est pas un oubli.

### Les contrastes ont été recalculés, pas recopiés

Quatre valeurs de la référence d'origine échouaient au contraste et ont été corrigées —
c'est une amélioration qui ne fait pas diverger le rendu :

| Élément | Avant | Après | Ratio |
|---|---|---|---|
| Palier « difficile » | `#FF9800` | `#E65100` | 2,06 → 3,62 |
| Palier « bien » | `#2196F3` | `#1E88E5` | 2,99 → 3,52 |
| Palier « parfait » | `#4CAF50` | `#388E3C` | 2,66 → 3,93 |
| Premier plan de la médaille | blanc | noir | **1,66** → 12,62 |

Le dernier cas n'était pas un ajustement de confort : le rendu d'origine était illisible.
Les confettis sont déclarés **décoratifs** au sens WCAG — aucun plancher ne leur est
inventé, et la documentation le dit.

## Une chaîne de résolution réparée

Le socle résout un dégradé de signature en consultant, dans l'ordre : le seam
`gradientResolver` d'un `ZcrudScope`, puis le jeton `ZcrudTheme.signaturePalette`, puis
la référence auditée sous le profil `legacy`.

Un site ne suivait pas cette voie : la bande de verdict du bilan de session appelait la
fonction **pure** de résolution, sans contexte — court-circuitant donc **à la fois** le
seam et le jeton. Une application ne pouvait ni la teinter par thème, ni par seam ; elle
ne pouvait que l'éteindre. C'est réparé.

⚠️ **Changement de comportement, pour qui posait déjà un résolveur ou une palette.**
Le profil `neutral` n'annule plus votre décision. Auparavant, un `zLegacyOr` appliqué
par-dessus la résolution effaçait sous `neutral` une palette que vous aviez délibérément
posée ; l'arbitrage du profil vit désormais là où il doit vivre — **dans** la résolution,
et il ne gouverne que le dernier maillon, la référence.

- **Application passive** : rien ne change, sous les deux profils. L'inertie est prouvée
  sur la couleur réellement peinte, en égalité stricte.
- **Application qui posait un résolveur ou une palette** : votre décision s'applique
  maintenant **aussi** sous `neutral`. Si vous comptiez sur `neutral` pour la neutraliser,
  c'est le profil qu'il faut cesser d'utiliser comme interrupteur — posez la valeur que
  vous voulez, ou n'en posez aucune.

Une garde interdit désormais la récidive dans les paquets concernés : aucun appel ne doit
court-circuiter la voie normale quand un contexte est disponible. Elle dit elle-même ce
qu'elle ne couvre pas — un alias local, un dégradé fabriqué à la main, la présence
effective d'un contexte — plutôt que de laisser croire à une couverture totale.

## Trois éléments de plus deviennent pilotables

Un relevé exhaustif des surfaces de session a établi deux choses. D'abord une bonne
nouvelle : **aucune couleur codée en dur** nulle part (grep négatif à l'appui). Ensuite,
que treize éléments lisent directement un rôle Material — l'application peut changer son
`ColorScheme` global, mais pas les teinter indépendamment.

Treize jetons auraient été de l'inflation : chaque jeton est une promesse à tenir, et
dix de ces sites relèvent du design voulu. **Trois** sont livrés, choisis par surface
occupée et fréquence de vue :

| Jeton | Ce qu'il peint |
|---|---|
| `flashcardCardBackgroundColor` | le fond de la carte — la surface la plus regardée d'une session |
| `flashcardCardShadowColor` | son ombre portée |
| `studySessionDividerColor` | le trait entre la pile et la zone de notation |

Tous **nullables** : `null` ⇒ le rendu d'aujourd'hui, à l'identique. Chaîne
`paramètre > jeton > rôle`.

⚠️ Deux nuances que la mesure impose et que nous préférons dire :
- l'ombre reste **dominée** par les jetons `cardShadow*` préexistants ;
- le thème « Classic » ne pose **que le premier** des trois. Pour l'ombre, la référence
  d'origine dérive quatre couleurs du dégradé par type : en figer une seule en
  repeindrait trois autres. Pour le trait, la référence n'en a aucun — la notation y vit
  dans la carte. **Un jeton non posé est une réponse ; un jeton inventé serait une dette.**

## Un champ mort retiré, et la classe fermée

`ZStudySessionChrome.accentColor` était calculé et **consommé par personne**. Sa garde
locale assertait qu'il suivait `colorScheme.primary` : elle vérifiait donc
consciencieusement qu'un champ inerte restait inerte — elle défendait le défaut.

Le champ est retiré (aucun appelant direct dans le dépôt), et une garde repo-wide ferme
désormais la classe entière : tout champ public d'un porteur de chrome doit être lu
quelque part. Elle dit ce qu'elle ne couvre pas — les constantes des fichiers de
référence, mesurées avant renoncement — plutôt que de laisser croire à l'exhaustivité.

## Vérification, rejouée au repos

`melos run generate` RC=0 (0 fichier généré modifié) ; `melos run analyze` repo-wide
RC=0 ; `melos run verify` RC=0 ; comptes par paquet, mesurés **depuis le dossier de
chaque paquet** : `zcrud_core` 2699, `zcrud_study` 2009, `zcrud_session` 685,
`zcrud_ui_kit` 340, `zcrud_themes` 84. Aucun résidu d'injection R3.

Les gardes de cette version ont été posées sous discipline R3 — rouge **par assertion**,
restauration par copie de fichier, sha256 publiés, résidus prouvés par grep négatif.
Trois d'entre elles étaient **vertes au premier passage** et ont été reformulées plutôt
que déclarées solides ; l'une l'a été après un balayage complet de l'espace des couleurs
qui a montré que son assertion était vraie pour **toute** valeur — donc qu'elle ne
mesurait rien.
