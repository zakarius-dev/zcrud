# Changelog

Toutes les modifications notables de `zcrud_core` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.16.0 — 2026-08-24

### Ajouté
- **Accent supérieur de champ** : une fine barre au sommet du champ, colorée par un accent déclaré par champ (repli : la teinte du type) et **dimensionnée par `accentBarHeight`** — le jeton cesse d'être « futur ». Sans teinte ni déclaration : rendu inchangé au pixel.
- **La teinte et la pastille suivent le slot `leading`**, sous les mêmes jetons et la même gouvernance que `prefixIcon`.
- **Point d'entrée public pour les présentateurs riches** : `zResolveTintedAdornment(...)` (+ `zResolveFieldTint`/`zResolveFieldAccent`) — teinte normalisée et icône en pastille prêtes à poser sur une tuile, sans dupliquer la normalisation ni la résolution de clé.

### Garde
- **Inertie des jetons de thème** : tout jeton public de `ZcrudTheme` a un consommateur hors du fichier de thème, ou une exemption nominative vérifiée mécaniquement — un jeton « futur » ne peut plus naître muet.

### Attention
- `accentBarHeight` est un jeton **partagé** (cartes d'étude et de flashcard le consommaient déjà) : un hôte qui le posait pour ses cartes **et** dispose d'un résolveur de teinte de type verra désormais ses champs porter la barre — déclarer `accentBarHeight` nul côté champs n'est pas possible par jeton unique ; l'accent de champ reste inerte tant qu'aucune teinte ne se résout.
## 3.15.0 — 2026-08-24

### Ajouté
- **La teinte par type de champ atteint le libellé flottant** : quand une teinte est résolue, la couleur du `floatingLabelStyle` la porte (normalisée pour le contraste) ; sans résolveur, rendu inchangé au pixel.
- **Pastille de fond de l'icône d'ornement** : jetons de fond (alpha clair/sombre, rayon, taille) peints sous l'icône dans la vue d'ornement, sous la normalisation de contraste et la gouvernance des modes existantes ; aucun jeton ⇒ aucun conteneur ajouté.
## 3.14.0 — 2026-08-24

### Ajouté
- **Formulaires** : `ZTextConfig.keyboardType` honoré (table fermée, chaîne inconnue ⇒ repli par `maxLines`) ; port `ZNumberDisplayFormatter` (lecture et résumé de sous-liste — sans port, rendu inchangé) ; `ZTextCapitalization.lowercase` (déterministe, collage compris) et `ZcrudScope(defaultTextConfig:)` (précédence champ > scope) ; teinte par type de champ atteignant bordure de focus et pastille d'icône — **étalon pixel-identique sans déclaration**, présets = données, couleurs normalisées pour le contraste ; `minValueKey`/`maxValueKey` honorés (revalidation ciblée au changement du champ référencé) ; cinquième cible **`readOnly`** de `ZDerivation` (lecture seule conditionnelle, toutes familles, le statique prime) ; œil natif sur le mot de passe (48 dp, `Semantics`, masqué par défaut) et `ZFieldAdornment.onTap` ; `ZFieldSpec.defaultValue` amorcé pour toute tranche absente d'`initialValues` (clé présente = autoritaire, même nulle).

### Garde
- **Garde d'inertie** : toute propriété publique d'une `Z*Config` est lue par la présentation, ou figure dans une courte liste « domaine pur » justifiée au point de déclaration — l'ajout d'une option morte rougit.
## 3.13.0 — 2026-08-24

### Ajouté
- **Sous-listes** : `reorderable: true` explicite rend les contrôles d'ordre **aussi en `compact`** (ordre réellement persisté) ; en `tags`, l'option devient bruyante (assertion de debug) — plus jamais silencieusement inerte ; `ZSubListViewData.onReorder` exposé aux seams. Préférences d'affichage des actions de ligne (`showViewAction`/`showEditAction`/`showDeleteAction`) — **montré = permis (ACL) et préféré**, une préférence ne rouvre jamais un droit refusé ; couleurs et taille par jetons `ZcrudTheme`. Contrôle d'ajout décorable par cinq jetons (fond, dégradé, rayon, taille, couleur d'icône) — aucun jeton ⇒ rendu inchangé. `ZSubListSeams.headerBuilder` (`ZSubListHeaderView` : champ, compte, `addControl`, `onAdd`) — `captionBuilder` reste honoré.
- **Sections** : `ZEditionSection.icon` et `ZEditionSection.style` (`ZEditionSectionStyle` : fond, filet supérieur, rayon, typographie, chevrons remplaçables, **filet vertical côté début** — directionnel, RTL testé). Sans style : arbre inchangé.

### Changé
- `ZSubListConfig.reorderable` passe de `bool` à `bool?` (`null` = comportement historique) — un lecteur externe du champ écrit `?? true`.

## 3.9.0 — 2026-08-23

### Corrigé
- **Sous-listes imbriquées** : un `subItems` déclaré dans les `itemFields` d'un `subItems` est désormais réellement éditable — le dialogue d'item pose une largeur finie quand le sous-schéma emboîte une liste, le formulaire d'item re-pose `ZcrudScope` (un scope sous `home` était perdu en traversant la route : niveau 2 sans ACL, libellés ni thème), et un `summaryFields` nommant une sous-liste rend son **compte**. Sans limite de profondeur ; lecture seule propagée ; éditer au niveau 2 ne reconstruit pas le niveau 1.

## 3.8.0 — 2026-08-23

### Ajouté
- `ZListCustomLayout.entityView` / `ZListCustomLayout.forEntity<T>` (`ZEntityResolver<T>`, `ZEntityListViewBuilder<T>`) : une vue entière reçoit `entityFor` comme tous les autres layouts — le résolveur ne lève jamais. `entityFor` est passé à la vue **hors** `ZListRenderRequest` : la mémoïsation de la requête de rendu reste intacte. Nuance : `ZListCustomLayout.customView` devient nullable.

## 3.6.0 — 2026-08-23

### Garde
- **Octets de contrôle bruts interdits dans toute source Dart du dépôt** (`z_source_control_bytes_guard_test`) : lecture en octets, tolère `\t`/`\n`/`\r`, nomme `fichier:ligne:octet`. Sept occurrences (six NUL, un VT) corrigées à cette version.

## 3.5.0 — 2026-08-22

### Ajouté — deux jetons de premier plan

**`onErrorColor`** — le premier plan d'erreur, **apparié** à `errorColor` : le
repli l'alimente depuis le rôle correspondant du `ColorScheme`, exactement comme
le fond depuis le sien. Un consommateur qui peint un fond d'alerte y prend son
texte, jamais dans la couleur de surface — laquelle n'a aucune raison d'être
lisible sur une pastille.

**`chatComposerActiveAccent`** — teinte d'état **actif** des bascules d'outils
du composer. **Absente du repli** : sans déclaration, aucune teinte n'est peinte.

## 3.3.1 — 2026-08-21

### Gardes — l'unicité du calculateur de contraste couvre une seconde forme

La garde attrapait une réimplémentation portant les **coefficients WCAG
littéraux**. Elle attrape désormais aussi un calculateur qui **délègue la
luminance au SDK** — forme qui n'écrit aucun coefficient et lui échappait donc
entièrement. Les deux motifs sont **dérivés de la source**, jamais figés dans le
test.

La conjonction est délibérée : mesurer une brillance reste légitime ; c'est
l'association avec le décalage du rapport de contraste qui trahit une
réimplémentation.

## 3.3.0 — 2026-08-21

### Ajouté — `ZColorCycle`, une animation de progression réutilisable

Primitive publique qui anime une **palette fournie** sur une période fournie.
Elle ne connaît ni son appelant ni son usage : tout module peut s'en servir pour
signaler une génération en cours.

Palette et période sont **requises** — le cœur n'invente ni couleur ni tempo
(FR-26). Sous « Réduire les animations », aucun contrôleur n'est créé.

### Modifié — un seul calculateur de teinte lisible, dans le cœur

Le calculateur vivait dans un satellite, et une copie avait dû être faite dans un
autre : une arête entre satellites violerait l'invariant de dépendances. Il est
remonté au cœur, **sans rupture** — le satellite d'origine le ré-exporte sous le
même nom.

Sa dartdoc dit désormais **sur quelle surface la mesure porte**. Deux chiffres
circulaient pour la même couleur, tous deux exacts : l'un sur blanc pur, l'autre
sur la surface réelle d'un thème clair.

## 3.1.0 — 2026-08-18

### Renforcé — la parité `copyWith` / `derive` exige le relais exact

La garde de parité dérivait déjà les trois listes de paramètres de la **source**.
Elle exige désormais que `derive` **relaie** effectivement chaque seam, et pas
seulement qu'il l'accepte en signature : un paramètre accepté puis ignoré aurait
rouvert, un étage plus haut, toute la classe de défauts de perte de seam.

## 2.5.0 — 2026-08-18

### Ajouté

#### L'accès à la vue corbeille devient déclarable

`ZTrashPolicy` porte désormais une **condition d'accès** qui remplace le critère
par défaut. `null` (défaut) ⇒ comportement **strictement inchangé**.

Le défaut `restore || clear` reste juste pour la plupart des écrans, et son
raisonnement est conservé : qui peut *supprimer* sans pouvoir ni restaurer ni
purger n'a rien à faire dans la corbeille. La déclaration n'existe que pour les
règles d'autorité que ce critère ne sait pas exprimer.

🔴 **La condition gouverne l'ACCÈS À LA VUE, jamais les actions dedans.**
Restaurer et purger restent gouvernés par l'ACL, individuellement : une condition
permissive **n'élargit aucun droit**. La propriété est **gardée
adversairement**, et l'injection qui l'ouvre fait rougir la garde.

**Défensif (AD-10)** : une condition qui **lève** ⇒ accès **refusé**, jamais
accordé. `visibleWhenEmpty` s'applique **après** la condition — une corbeille
vide masquée le reste, quelle que soit la règle déclarée.

## 2.3.0 — 2026-08-17

### Modifié

#### Un champ qui a déclaré son propre rendu le conserve en consultation

Le canal déclaratif de rendu de choix ouvert en 2.1.0 fonctionnait **en édition**
et disparaissait **en lecture** : la décision de poser une fiche de consultation
était une fonction **pure sur la famille**, sans échappatoire. Une matrice
d'autorisations, portée sur `select` + rendu déclaré, redevenait donc en
consultation une ligne de texte énumérant des clés — sur l'écran même par lequel
l'autorité d'une application se lit.

La règle cède désormais **uniquement** là où l'hôte a explicitement pris la main :

```dart
_readModeCard =
    readMode && zReadModeCardable(_family) && !hasResolvedChoiceBuilder;
```

Elle reste inchangée pour tous les champs ordinaires.

**Aucun canal n'a été ajouté** : le présentateur recevait déjà son drapeau de
lecture seule et le constructeur de choix est déjà monté sous `ZReadModeScope`.
C'est le canal de contexte livré en 1.4.0 qui rend ce correctif si petit.

🔴 **Ne plus poser de fiche ne rend PAS le champ modifiable** — et ce n'est pas
une supposition : la lecture seule est appliquée en amont
(`spec.copyWith(readOnly: true)`) et respectée par la famille. La propriété est
**gardée**, et l'injection qui la neutralise fait rougir la garde
(`Expected: true / Actual: <false>`). Sans elle, rien ne garantirait qu'une
matrice d'autorisations ne devienne éditable en consultation.

**Défensif (AD-10)** : une clé déclarée mais **absente** du registre replie sur
la fiche générique — jamais d'écran vide, jamais d'exception.

**Rétrocompatibilité stricte** : un champ **sans** clé déclarée garde exactement
le comportement actuel, fiche comprise (contre-témoin à compte absolu).

## 2.2.0 — 2026-08-17

### Ajouté

#### Le journal d'une entité devient consultable

Port `ZEntityHistorySource` : un **flux nu** (AD-5) d'entrées de journal, fourni
par l'hôte. **zcrud ne lit jamais le backend** — la forme du journal, la
résolution de l'auteur et l'écriture restent métier, et aucun type
`cloud_firestore` n'approche le domaine (AD-16).

`ZCrudAction.history` **existait déjà** dans l'énum ACL, et y était déjà classé
comme action de **lecture** : la gouvernance était en place, seule la capacité
manquait. L'énum n'a pas été touchée.

L'opération est portée par une **action typée**, donc localisable par le socle,
avec un libellé libre en échappatoire pour les opérations métier que l'énum ne
couvre pas. Un libellé fabriqué par l'hôte ne pourrait pas être traduit (FR-26).

Nouvelles entrées de catalogue l10n : `history`, `date`, `operation`, `author`,
`update`, `view`.

## 2.1.0 — 2026-08-17

### Ajouté

#### Le CRUD inline d'une relation se gouverne geste par geste

`ZRelationCrudHandler` porte `canCreate` / `canEdit` / `canCopy` (getters, défaut
`true`) et une extension `ZRelationCrudOffer` (`offersCreate`/`offersEdit`/
`offersCopy`/`offersAnyGesture`) qui centralise le repli **AD-10 fermant** : un
getter qui lève masque le geste, il ne l'offre jamais.

Auparavant, enregistrer un gestionnaire affichait les trois boutons et ne pas
l'enregistrer n'en affichait aucun — impossible d'exprimer « peut modifier, ne
peut pas créer », qui est le cas le plus courant d'un modèle d'autorité par rôle
et par poste.

**Un geste refusé est ABSENT, jamais inerte.** Rendre `null` depuis l'opération
laissait un bouton qui ne fait rien : l'usager clique et ne comprend pas. Les
icônes refusées ne sont pas construites (jamais un `onPressed: null`), et un
gestionnaire qui n'offre plus rien ne force plus l'ouverture de la feuille.

**`ZActionAclMode.disable` a été délibérément écarté** ici : ce mode n'est
défendable que là où l'action porte un motif annoncé aux lecteurs d'écran. La
feuille de relation n'a aucun canal de motif — `disable` y produirait le bouton
inerte et muet que ce lot supprime. La condition de levée est écrite en dartdoc.

La frontière ne bouge pas : **zcrud ne connaît pas l'ACL de l'hôte**. Les
booléens sont calculés par l'implémentation du port ; le paquet ne fait que les
lire.

#### Un rendu de choix personnalisé devient déclarable

Nouveau `ZSelectChoiceBuilderRegistry` (chaînable, ombrage enfant > parent,
collision locale ⇒ `throw`) injecté par `ZcrudScope`, et une **clé** portée par
`ZSelectConfig`. `choiceBuilder` **et** `choiceSecondaryBuilder` étaient acceptés
par le widget et transmis au présentateur, mais absents de toute la couche
domaine et jamais renseignés par le dispatcher : un hôte instanciant le widget à
la main obtenait tout, un hôte **déclarant** ses champs — le mode d'emploi normal
du paquet — n'obtenait jamais rien.

Le canal **résout** plutôt qu'il ne **relaie**, comme le canal de seams des
sous-listes : un relais est une liste qu'on oublie de tenir à jour, et c'est ce
qui a produit quatre signalements successifs. La spec reste `const` — aucune
closure n'entre dans le domaine.

Clé déclarée mais absente du registre ⇒ repli sur le rendu par défaut, jamais
d'exception (AD-10).

## 2.0.0 — 2026-08-16

### ⚠️ Modifié — RUPTURE

#### Le mode `compact` devient le défaut, avec un vrai rendu tabulaire

Mesuré sur le moteur legacy : un item y est rendu par
`itemBuilder?.call(item) ?? Container()` — **sans builder, un item legacy
s'affiche vide** — et l'édition passe par une fenêtre. Le mode qui correspond au
legacy est donc **`compact`** (résumé + fenêtre), jamais `inline`
(sous-formulaires imbriqués à champs vivants, mode natif zcrud sans contrepartie
legacy). **Le défaut était le mauvais** pour tout hôte qui migre.

Trois défauts inversés, et le troisième compte autant que les deux autres :
`displayMode` → `compact` ; `showSummaryHeaders` → `true` ; **et le repli du
widget quand la config est absente** → `compact`. Ce dernier couvre le cas du
générateur `@ZcrudModel`, qui émet un `ZFieldSpec(type: subItems)` **sans
config** pour un sous-modèle : le laisser sur `inline` aurait fait coexister deux
défauts contradictoires, le second visant justement l'hôte qui n'a rien choisi.

**Retour arrière en une ligne : `displayMode: ZSubListDisplayMode.inline`.** Il
est *prouvé*, pas promis — le rendu `inline` est **octet pour octet** celui de la
v1.9.0 (sha identique).

#### Le rendu tabulaire

Une **seule** `Table` porte l'en-tête et les lignes. Conséquence structurelle :
l'en-tête ne *reproduit* plus la géométrie des cellules — **c'est la même
colonne**, il ne peut donc plus se désaligner. Les largeurs **suivent le
contenu** (la colonne de désignation absorbe le surplus et cède la première),
là où le rendu précédent imposait des colonnes **égales** puis tronquait.

Les valeurs numériques sont cadrées en **fin** (`TextAlign.end`, jamais `right` —
AD-13) : une colonne de montants qui ne s'aligne pas ne se lit pas. Sont
numériques les colonnes portant `decimals` ou dont le type déclaré est
`number`/`integer`/`float` ; `rating`/`slider`/`stepper` sont exclus — un nombre
qui se lit comme une appréciation n'aligne rien.

Aucune dépendance nouvelle : primitives Material seules, aucun `pubspec` touché.
La frontière **AD-8** est écrite en dartdoc — tri, pagination et virtualisation
restent au moteur de liste ; rendre quelques lignes embarquées dans un formulaire
est une mise en page.

#### Ce qui NE change pas

- **Le repli responsive de la v1.4.1 est intact** (même formule, même seuil
  dérivé) : sous le seuil, aucune table n'est construite et la ligne s'empile en
  couples libellé/valeur.
- `showSummaryHeaders: false` rend le résumé défilant historique **au byte
  près** : aucune déclaration existante ne change de sens, seul le défaut est
  inversé.
- Les seams des v1.8.0/v1.9.0 gardent leur applicabilité. **La table cède, jamais
  le seam** : `listViewBuilder`, `itemBuilder` et le repli responsive sortent du
  rendu tabulaire plutôt que de le contraindre.

### Ajouté

`ZSubListFieldWidget.summaryTableRowBudget` (**60**, public) : au-delà, le rendu
retombe sur une liste construite à la demande — une table ne virtualise pas. Le
seuil est **asserté des deux côtés**, et volontairement **non réglable** : un
seuil négociable ne s'asserte plus.

## 1.9.0 — 2026-08-16

### Ajouté

#### Les sous-listes deviennent des lignes de document

Relecture d'un cinquième dépôt hôte portant le même moteur legacy : l'intention
de `subItems`, ce sont **les lignes d'un document** (master-detail
intra-formulaire). Trois manques en découlaient.

- **`ZSubListSummaryColumn` / `ZSubListConfig.summaryColumns`** — une colonne de
  résumé peut désigner une valeur **non éditable**. Une colonne dont le `name`
  n'est pas un `itemField` lit la donnée de l'item : elle **s'affiche sans
  devenir saisissable**. C'est le cas réel — « Montant HT », « Montant TTC » sont
  calculés par le crochet, jamais tapés. Porte `decimals` et un suffixe
  localisable. Non vide, `summaryColumns` **remplace** `summaryFields`.
- **`ZSubItemCrudOutcome.veto(reasonKey:, reasonFallback:)`** — le véto peut
  enfin dire pourquoi. Le motif est **localisable** et rendu par le socle
  (annonce aux lecteurs d'écran comprise). Auparavant, un crochet refusait en
  silence.
- **`parentPatch`** sur `proceed`/`replace`, et **`ZSubItemCrudRequest.parent`**
  (lecture non tracée de l'état parent) — le crochet peut maintenir une tranche
  voisine du formulaire, ce que fait l'usage réel à chaque ligne ajoutée.

**Trois arbitrages, et leurs raisons.** Le motif et le correctif sont portés par
l'**issue**, non par un `BuildContext` ni par le `ZFormController` parent : le
crochet est `async`, donc un contexte capturé serait employé après un `await`,
et un contrôleur exposé ouvrirait la réentrance depuis un crochet appelé en
pleine mutation. **Une seule** liste de colonnes, jamais deux à tenir d'accord —
c'est la dérive du legacy, qui déclare un schéma de colonnes *et* un schéma de
formulaire. Enfin **un véto n'applique aucun correctif** : dans l'usage réel,
refuser et mettre à jour l'état voisin sont deux branches distinctes.

Tout est **additif** : les crochets écrits pour la v1.8.0 compilent et se
comportent à l'identique. La lecture d'une valeur hors sous-schéma reste
gouvernée par l'opt-in — un `summaryFields` nommant une clé absente rend vide
depuis toujours, l'afficher d'office déplacerait un hôte passif.

### Non livré, délibérément

Le formatage **monétaire localisé** du legacy (`isCurrency`) : il exige un port
de formatage que le cœur n'a pas, et l'inventer ici serait le mauvais endroit —
`decimals` et un suffixe localisable sont livrés à la place. Le
`suffixBuilder(item)` : une closure n'entre pas dans le domaine `const`, le
chemin passe par `itemTransformer` (documenté). L'alignement et la largeur de
colonne : ils relèvent du rendu tabulaire, traité séparément.

## 1.8.0 — 2026-08-16

### Ajouté

#### Les sous-listes deviennent personnalisables — canal de seams, menu par item, cycle CRUD

Portage de l'ensemble des capacités du moteur de sous-listes legacy (DODLP), en
trois passes. Rien de déclaré ⇒ rendu et données **identiques**, à une rupture
près, isolée et documentée plus bas.

**Le canal.** `ZSubListSeams` + `ZSubListSeamRegistry`, injectés par
`ZcrudScope.subListSeamRegistry`, résolus **par les widgets eux-mêmes** (clé
`widgetKind` → `name` → `type.name`, chaînage `parent:`, ombrage enfant > parent).

Ce choix règle un défaut de fond : `itemTitleBuilder` et `acl` existaient déjà
sur le widget, mais **n'étaient jamais transmis** par le constructeur de champ —
donc inatteignables sans `fieldBuilder` de remplacement. Un relais est une liste
qu'il faut penser à tenir à jour ; c'est précisément ce qui a été oublié quatre
fois. En faisant **résoudre** plutôt que **relayer**, le chemin nominal et la
construction directe servent les mêmes seams par construction. Un troisième seam
inatteignable a été trouvé au passage : `ZDynamicItemFieldWidget.fieldsResolver`.

Seams : `acl`, `itemTitleBuilder`, `itemBuilder`, `itemActionsBuilder`,
`listViewBuilder`, `captionBuilder`, `itemTransformer`, `itemFieldsResolver`.
`itemActionsBuilder` **ajoute** des actions, ne les remplace jamais, et ses
actions entrent dans le calcul de repli du résumé — sinon l'en-tête mentirait.
`itemTitleBuilder` garde son contrat « donnée brute » : un titre sert à retrouver
un item, l'habiller le rendrait introuvable.

**Le menu par item.** `ZSubItemMenuOption` (`const`) : clé l10n + repli, icône,
prédicat de visibilité par item, charge utile opaque, marquage destructif,
permission. Le défaut de permission est **restrictif** (`delete` si destructive,
sinon `update`) — un défaut permissif aurait fait du canal une porte dérobée.
**L'ACL décide d'abord, le prédicat ensuite**, jamais fusionnés : le prédicat
n'est pas même appelé quand l'ACL refuse.

**Le crochet CRUD.** `Future<ZSubItemCrudOutcome> Function(ZSubItemCrudRequest)`,
issues `proceed` / `replace(data)` / `veto`, appelé **avant** la mutation. Il
n'imite pas le `Future<Map?>` du legacy : mesuré, ce `null` servait à la fois de
véto et de retour normal — le legacy retourne `null` sur toutes ses branches, y
compris après avoir appliqué la mutation. Un crochet qui **lève** est traité
comme un **véto**, et son erreur est signalée : ici « traité comme absent »
voudrait dire « la mutation passe ».

**Le cycle porté par le champ.** Sous-schéma et gabarits de création **dérivés de
l'état du formulaire parent** (résolveurs recevant une lecture par nom, pas la
`Map` de l'état — ce qui permet l'abonnement **ciblé** aux seules tranches lues,
invariant AD-2) ; identité du gabarit choisi transmise au crochet
(`ZSubItemCrudRequest.template`) ; `ZSubItemFormPresentation { dialog, sheet,
page }` pour la forme du formulaire d'item, défaut inchangé, avec assertion
croisée que les trois formes rendent la **même** donnée.

Le sous-schéma dérivé **ne recrée pas** les `ZFormController` des champs
inchangés (AD-2, comptes assertés), et la tranche du champ lui-même n'est jamais
abonnée : s'y abonner relancerait la résolution à chaque agrégation d'item —
exactement le rafraîchissement global que zcrud existe pour supprimer.

**Ni `ZMapEntity`, ni adossement à un `ZRepository`** (décision d'owner) : un
sac de clés n'a pas de schéma déclaré, or la chaîne défensive (AD-3, AD-10)
présuppose un modèle typé ; et les sous-items vivent dans le document parent, pas
dans une collection. Le champ porte le cycle sur des `Map`, l'hôte branche sa
persistance derrière le crochet.

### Modifié

#### Les clés hors sous-schéma survivent désormais à la création

⚠️ **Rupture au périmètre étroit.** Un hôte qui déclare `defaultNewItem` ou
`creationTemplates` **avec au moins une clé absente des `itemFields`**, en mode
`compact` ou `tags`, à la **création** : cette clé était perdue, elle est
maintenant conservée. Hors de cette intersection, la donnée est identique.

Ce n'était pas académique : l'usage réel porte une charge `{"type": …}` qui n'a
aucune raison d'être un champ éditable du sous-schéma.

### Non porté, délibérément

Le `DataTable` du legacy (c'est un moteur de liste — AD-8, `zcrud_list` ; le
dupliquer dans un champ recréerait la divergence combattue), son surlignage en
couleur codée en dur lisant un `Timestamp` Firestore dans un widget (FR-26 **et**
AD-5), `flutter_tags` (AD-1), et quatre blocs de code mort ou commenté.

Trois **gestes morts** du legacy ont été mesurés et non portés : la sérialisation
d'une closure et d'un `Type` en JSON ; un prédicat d'option qui n'a **aucun**
appelant dans les dépôts hôtes ; et le menu d'ajout d'une timeline qui n'est
jamais rendu, le bouton étant sous `readOnly == false` alors que le champ déclare
`readOnly: true`.

## 1.7.0 — 2026-08-16

### Ajouté

#### `ZStepperEdition.collapseStore` — le pli des sections survit aux étapes

L'assistant à étapes montait `DynamicEdition` sans lui passer le seam de pli
persisté des sections. Une section repliée dans une étape se rouvrait à chaque
ouverture de l'écran.

**Portée dérivée par étape**, et c'est mesuré, pas décoré : `saveCollapsed`
remplace la portée **entière**. Deux étapes partageant un `formId` s'effaçaient
donc mutuellement — un relais naïf aurait été un défaut par construction.
Chaque étape reçoit `"<formId>/étape:<titre>"` ; un sous-assistant dérive
par-dessus.

Défaut `null` ⇒ comportement strictement inchangé.

## 1.5.0 — 2026-08-16

### Modifié

#### Le fond et le filet de la fiche appartiennent à la fiche, plus à la forme

Les jetons `readFillColor` / `readBorderColor` / `readBorderWidth` étaient
**inertes** dans quatre des cinq formes de `ZReadFieldLayout` : seule `card`
construisait un conteneur où les peindre. Déclarés sur `definition`,
`inlineRow`, `compact` ou `listTile`, ils étaient posés, valides, lus — et sans
effet. Mesuré au pixel par l'hôte : la fiche peignait **exactement le fond de
l'écran**.

L'encadré est désormais appliqué **au niveau de l'aiguillage**, donc aux cinq
formes, et partage littéralement son fond et son contour avec `card` (helpers
`_fond` / `_contour`) : déclarer les jetons donne le **même** encadré partout.

`readCardMinHeight` et le bouton de copie **restent propres à `card`** : les
hauteurs des formes denses (54 / 36 / 28) ne bougent pas en s'encadrant.

⚠️ **Rupture pour un hôte qui déclarait déjà ces jetons.** Une application ayant
posé `readFillColor` ou `readBorderWidth` au thème **et** employant une forme
dense verra apparaître un encadré qu'elle n'avait pas. C'est la correction
demandée ; elle est visible.

### Ajouté

- Deux déclencheurs, et deux seulement, font naître le conteneur :
  `readFillColor` **déclaré** (quelle que soit sa transparence — c'est une
  déclaration d'intention) **ou** `readBorderWidth` **strictement positif**.
  `readBorderColor` seul ne déclenche rien : sans largeur le filet retombe à
  `BorderSide.none`, et poser une surface invisible n'ajouterait qu'un nœud à
  l'arbre. **Le défaut des cinq formes est strictement inchangé**, posé à plat.
- Aucun `InkWell` n'est ajouté par l'encadré : peindre un fond ne fait pas d'un
  texte un contrôle, et rien n'y impose donc de cible de 48 dp (AD-13). Les
  formes denses gardent leur copie par appui long, sans bouton.

### Documentation

- La dartdoc de `readFillColor` **perd sa restriction** à `ZReadFieldLayout.card`,
  qui était la cause directe de la méprise ; `readBorderColor` porte désormais
  l'avertissement « seul, ne peint rien » ; `readCardMinHeight` est signalé comme
  le **seul** jeton de fiche encore propre à `card`.

## 1.4.1 — 2026-08-16

### Corrigé

#### Sur un téléphone, une sous-liste ne délivrait aucune information lisible

Une sous-liste à en-têtes de colonnes présentait ses items en table alignée :
autant de colonnes de largeur égale que de champs de résumé, chacune coupée à
une ligne. Sur la largeur d'un téléphone, quatre colonnes laissent moins de
soixante-dix points à chacune — marges déduites, il ne reste rien. En
consultation, l'agent lisait donc une table dont **les en-têtes eux-mêmes**
étaient tronqués (« Date … », « Poste … ») au-dessus de lignes qui l'étaient
tout autant (« ven. … ») : ni la période, ni le poste, ni rien d'autre. Et sur
une fiche qu'on consulte et qu'on imprime, « ouvrir l'item pour lire »
n'est pas une réponse.

La table alignée est conservée — c'est un bon rendu, et il ne changera pas d'un
pixel là où la place suffit. Mais **en deçà de la largeur qu'elle exige**, la
sous-liste empile désormais chaque ligne en couples libellé/valeur : la valeur
est rendue en entier, sur autant de lignes qu'il le faut, et le libellé qui
coiffait la colonne descend dans la ligne. La ligne d'en-têtes s'efface avec
elle : il n'y a jamais un en-tête au-dessus d'un empilement auquel il ne
correspondrait plus. Chaque couple est annoncé comme un couple aux lecteurs
d'écran.

Le seuil n'est pas un nombre choisi : il se calcule à chaque mise en page. La
table est gardée tant que la largeur restante — marges de ligne et boutons
d'action déduits — laisse à **chaque** colonne au moins la largeur minimale
lisible du thème. Les boutons entrent dans le calcul parce qu'ils prennent
réellement la largeur au texte : la même surface peut donc porter une table en
consultation, où une seule action est offerte, et l'empiler en saisie, où il y
en a trois. Le repli vaut dans les deux cas — il ne se déclenche que là où la
table ne délivrait plus rien.

### Ajouté

* `ZcrudTheme.subListColumnMinWidth` — largeur minimale qu'une colonne de
  résumé de sous-liste doit garder pour rester lisible, et donc seuil de repli
  de la table. `null` (défaut) ⇒ **dérivée** de `readRowLabelWidth` (160 par
  défaut) : une colonne est coiffée par le libellé de son champ, elle doit être
  au moins aussi large que la colonne de libellés qu'un champ consulté en ligne
  se réserve déjà. Le déclarer permet de régler le repli des sous-listes sans
  toucher à la présentation des champs consultés en ligne.

## 1.4.0 — 2026-08-16

### Corrigé

#### La consultation ne ressemblait pas à une consultation

Un formulaire ouvert en lecture rend ses champs en **fiches** : le libellé
au-dessus de la valeur, sans bordure de saisie, sans libellé flottant, sans
icône de préfixe. C'était vrai d'un formulaire à plat. Ce ne l'était pas d'une
**fenêtre à étapes**, ni des champs **à l'intérieur d'une sous-liste** ou d'un
**item dynamique** : là, la consultation donnait à lire un formulaire de saisie
désactivé — un champ encadré et étiqueté en flottant, ce qui annonce une saisie
possible sur un document qu'on ne fait que consulter et imprimer.

La cause n'était pas le rendu, qui existait déjà, mais le chemin qu'empruntait
le mode de lecture : un paramètre de constructeur, que seul le rendu de champ
**par défaut** transmettait. Toute surface fournissant son propre rendu de
champ — ce que fait la fenêtre à étapes — remplaçait le seul endroit qui le
portait, et le mode retombait à « édition », en silence.

Le mode de présentation descend désormais **par le contexte**
(`ZReadModeScope`) : `DynamicEdition` et `ZStepperEdition` le posent d'après
leur `readOnly`, chaque champ le lit. Plus rien à recopier — ni pour un
`fieldBuilder` fourni, ni pour un champ au fond d'une sous-liste, ni pour le
dialogue de consultation d'un item, qui vit pourtant dans une autre branche de
l'arbre.

`ZFieldWidget.readMode` **prime toujours** quand il est donné : une surface en
lecture peut forcer un champ en saisie, et réciproquement. Il reste distinct de
`ZFieldSpec.readOnly`, qui dit « ce champ-ci n'est pas modifiable » et n'a
jamais dit comment le présenter.

Effet de bord attendu : les ornements déclarés (`leading`/`suffix`) ne sont plus
rendus en consultation dans ces surfaces — une fiche n'en porte pas.

### Ajouté

#### Une fiche de consultation encadrée, ou posée à plat

Le fond et le filet de la fiche de lecture étaient figés : fond
`surfaceContainerLow`, filet d'un point emprunté à la largeur de bordure des
**champs de saisie**. Une application qui voulait une consultation posée à plat,
à la manière d'une liste de lignes, ne pouvait pas retirer ce filet sans retirer
aussi celui de tous ses champs de saisie.

Trois jetons de thème le rendent réglable :

```dart
ZcrudTheme(
  readFillColor: ...,
  readBorderWidth: 0, // 0 ⇒ aucun filet
  readBorderColor: ...,
)
```

Ces trois jetons **ont désormais pour défaut la fiche posée à plat** (aucun
fond, aucun filet) — voir la rupture visuelle décrite plus bas.

#### Cinq formes de consultation, déclarables

Une consultation ne se présente pas de la même façon selon qu'on lit un dossier
de cinq champs sur un grand écran, qu'on parcourt une fiche de trente champs sur
un téléphone, ou qu'on imprime un document. Le socle n'offrait qu'une seule
présentation.

`ZReadFieldLayout` en offre cinq, et l'application choisit :

| Forme | Hauteur d'un champ court | Ce qu'elle apporte | Ce qu'elle coûte |
|---|---|---|---|
| `card` (défaut) | 72 | la présentation de référence, entièrement pilotée par les jetons `read*` | la plus haute des cinq |
| `listTile` | 72 | la ligne Material native — densités, retraits et RTL compris | structure figée par Material |
| `definition` | 54 | la valeur domine le libellé : la lecture d'un dossier rempli | libellés discrets, moins repérables |
| `inlineRow` | 36 | deux colonnes alignées, excellentes à l'impression | une largeur fixe prise par les libellés |
| `compact` | 28 | la densité maximale pour une fiche longue | pas de bouton de copie visible |

Elle se déclare là où elle a du sens, et se surcharge du plus lointain au plus
proche : jeton de thème `ZcrudTheme(readLayout: …)` pour toute l'application,
`DynamicEdition(readLayout: …)` / `ZStepperEdition(readLayout: …)` pour une
surface, `ZFieldSpec(readLayout: …)` pour un champ isolé.

```dart
// Toute l'application en lignes à deux colonnes, sauf le commentaire.
ZcrudTheme(readLayout: ZReadFieldLayout.inlineRow)

const ZFieldSpec(
  name: 'commentaire',
  type: EditionFieldType.text,
  readLayout: ZReadFieldLayout.definition,
)
```

La forme emprunte **le canal du mode de consultation lui-même** : rien à
recopier pour un rendu de champ fourni, une fenêtre à étapes, une sous-liste,
ni même le dialogue de consultation d'un item, qui vit pourtant dans une autre
branche de l'arbre.

Trois précisions qui se paient à l'usage :

* `inlineRow` **se replie** en présentation empilée sous 360 de large (jeton
  `readRowMinWidth`) : sur téléphone, deux colonnes n'ont plus la place de le
  rester ;
* `definition`, `inlineRow` et `compact` **n'affichent pas** le bouton de copie.
  Le garder aurait imposé une cible tactile de 48 à chaque rang, c'est-à-dire
  annulé leur densité. La copie reste offerte par appui long et par une action
  annoncée aux lecteurs d'écran ;
* dans toutes les formes, le libellé et la valeur sont annoncés **ensemble**,
  y compris quand la valeur n'est pas copiable — un champ vide affiché se dit
  désormais « vide » au lieu de rester muet.

### Changé

#### 🔴 Rupture visuelle : la consultation est posée à plat par défaut

**Ce qui change sans que vous fassiez rien.** La fiche de consultation était
une carte **remplie** (`surfaceContainerLow`) **cernée d'un filet d'un point**,
occupant 92 de hauteur, libellé de 12 en demi-gras au-dessus d'une valeur de 14
en demi-gras. Elle est désormais **posée à plat** : aucun fond, aucun filet,
rang de 72, libellé de 16 en corps de texte et valeur de 14 en gris —
c'est-à-dire, hauteur et typographie mesurées côte à côte, la présentation d'un
`ListTile(title: libellé, subtitle: valeur)`.

Disons-le sans détour : **une application qui ne déclare rien verra ses fiches
de consultation changer d'aspect.** Le fond et le filet disparaissent, la
hauteur d'un rang passe de 92 à 72, la typographie change. Ce n'est pas un
effet de bord, c'est la décision : la consultation doit ressembler à un document
qu'on lit et qu'on imprime, pas à un formulaire désactivé.

**Le retour se déclare en une ligne**, sans changer de forme :

```dart
ZcrudTheme(
  readFillColor: scheme.surfaceContainerLow,
  readBorderWidth: 1,
)
```

Et si c'est la **hauteur** ou la **typographie** d'avant qui vous manquent, les
jetons `readCardMinHeight`, `readPadding`, `readLabelGap`,
`readLabelTextStyle` et `readValueTextStyle` les reprennent un à un.

**Trois jetons changent de type** — `readCardMargin`, `readPadding` et
`readLabelGap` passent de valeur obligatoire à valeur **facultative** (`null` =
« la valeur propre à la forme rendue »). Les déclarer continue de compiler et de
primer ; seul un code qui **lisait** l'un de ces trois jetons en attendant une
valeur non nulle est concerné.

## 1.2.0 — 2026-08-16

### Ajouté

#### Un champ qui suit une case cochée

Une condition d'affichage savait comparer une valeur, tester une vacuité,
mesurer une longueur — mais pas répondre à « cette sélection multiple
contient-elle telle option ? ». Un formulaire qui s'adapte à une sélection
multiple devait donc fabriquer ses champs au rendu, un jeu variable là où le
catalogue est figé.

`ZCondition.contains` répond à cette question :

```dart
const ZFieldSpec(
  name: 'quotaLome',
  type: EditionFieldType.number,
  condition: ZCondition.contains('bureaux', 'lome'),
)
```

Le champ apparaît dès que `'lome'` figure parmi les valeurs retenues par
`bureaux`, et disparaît dès qu'il en sort. L'opérateur se compose comme tous
les autres : `ZCondition.not(...)` pour l'inverse, `and`/`or` pour le combiner,
`source:` pour lire la valeur d'origine plutôt que la saisie en cours.

**Ce qui compte comme collection** : un `Iterable` (`List`, `Set`…), et lui
seul. Un champ absent, `null`, un nombre, une `Map` — et **une chaîne** —
rendent `false`, sans jamais lever. Le cas de la chaîne est un choix délibéré :
`'lome-port'.contains('lome')` est vrai en Dart, si bien qu'une condition
pointée par erreur sur un champ à valeur unique aurait semblé fonctionner puis
surpris. Cet opérateur répond à « cette valeur est-elle retenue ? » ; pour
« est-ce cette valeur ? », c'est `ZCondition.equals`.

#### Un champ requis seulement quand une condition tient

`ZValidatorSpec.required` exige une valeur en toutes circonstances. Une règle
comme « au moins un de ces trois critères » n'avait donc pas de traduction :
trois `required` interdisent la recherche par un seul critère, aucun laisse
soumettre un formulaire vide.

`ZValidatorSpec.requiredIf` porte la même exigence, sous condition :

```dart
const ZFieldSpec(
  name: 'nts',
  type: EditionFieldType.text,
  validators: <ZValidatorSpec>[
    ZValidatorSpec.requiredIf(
      ZCondition.and(<ZCondition>[
        ZCondition.isEmpty('cst'),
        ZCondition.isEmpty('marque'),
      ]),
      errorText: 'Renseignez au moins un critère',
    ),
  ],
)
```

Déclarée ainsi sur chacun des trois champs, la règle refuse la soumission tant
que les trois sont vides et l'accepte dès qu'un seul est renseigné.

La frontière **forme / présence** est inchangée : quand la condition ne tient
pas, le champ vide est accepté exactement comme un champ sans `required`, et
ses validateurs de forme gardent leur verrou dès qu'il est rempli. Déclarer
`required` **et** `requiredIf` sur un même champ revient à `required`.

La condition est évaluée là où le champ est validé — à la frappe comme à la
soumission — contre l'état courant du formulaire et sa valeur d'origine
(`ZValueSource.persisted`). Le champ dépendant s'abonne aux seuls champs que sa
condition observe : le message apparaît et disparaît sans qu'il faille
retoucher le champ lui-même, et une frappe ailleurs ne reconstruit rien.

Deux points à connaître : une feuille de source `ZValueSource.context` n'est
pas honorée par `requiredIf` (le contexte d'édition n'est pas lisible sous le
champ) — exposez le drapeau comme un champ du formulaire ; et
`ZFieldSpec.isRequired` reste `false` pour un champ qui ne déclare que
`requiredIf`, l'astérisque du label restant réservé à une exigence qui ne
dépend pas de l'état.

## 1.1.0 — 2026-08-16

### Ajouté

#### Un champ fichier retient ce que l'usager a retiré

La tranche d'un champ `file`/`image`/`document` ne porte que ce qui **reste**
attaché. Ce que l'usager détachait — une photo supprimée, un document remplacé
— disparaissait au moment même où il le produisait : plus rien ne désignait le
fichier à effacer pour de bon, et rien ne le signalait. Un formulaire pouvait
donc paraître enregistré alors que les pièces retirées restaient en base
indéfiniment.

Les valeurs normalisées d'une soumission portent désormais, à côté de chaque
champ de la famille fichier, une entrée **compagne** nommée par
`zRemovedFilesKey('nom du champ')` :

```dart
final valeurs = formulaire.submit();
final restants = valeurs?['photos'] as List<Object>?;
final retires  = valeurs?[zRemovedFilesKey('photos')] as List<Object>?;
// `retires` : ce qu'il faut effacer réellement.
```

Les entrées retirées sont rendues **sous la forme que le champ tenait** :
l'objet `AppFile` quand il le connaît — y compris pour une référence opaque que
le résolveur de fichiers avait résolue —, la référence opaque sinon. C'est bien
un objet résolu qui ressort, pas un identifiant à relire.

La clé est **toujours présente** pour un champ fichier soumis : liste **vide**
quand rien n'a été retiré, jamais `null`. Elle suit exactement les règles de la
soumission — un champ en lecture seule ou masqué par une condition n'en produit
aucune —, et elle ne recouvre jamais un champ que vous auriez réellement
déclaré sous ce nom. Un formulaire sans champ fichier rend exactement les mêmes
clés qu'avant.

Un remplacement compte comme un retrait : sur un champ à valeur unique, choisir
un nouveau fichier détache l'ancien. Une simple transition d'état d'envoi
(`en attente → en cours → envoyé`), elle, n'est jamais un retrait.

Deux points d'accès plus fins restent disponibles pour qui compose ses propres
briques : `ZFormController.removedFilesOf('nom du champ')` (et le snapshot
`removedFiles`), remis à zéro par `reset` / `reseed` / `markPristine` ; et
`ZAppFileField.onRemoved`, notifié à chaque retrait.

### Corrigé

#### Un motif ne rend plus le champ obligatoire

Poser `ZValidatorSpec.pattern` sur un champ le rendait **obligatoire** : la
valeur vide était refusée par le motif lui-même. Un champ de contact facultatif
mais valide quand il est rempli — un numéro de téléphone qu'on ne saisit pas
toujours — était donc inexprimable : poser le motif imposait la saisie, ne pas
le poser perdait le verrou de format.

**Forme et présence sont désormais deux exigences distinctes.** Un validateur
de forme décrit ce à quoi une valeur doit ressembler *quand il y en a une* ; la
présence est exigée par `ZValidatorSpec.required`, et par lui seul :

```dart
// Facultatif, mais valide s'il est rempli :
validators: [ZValidatorSpec.pattern(r'^\+228[0-9]{8}$')],

// Obligatoire ET bien formé :
validators: [ZValidatorSpec.required(), ZValidatorSpec.email()],
```

La même incohérence affectait **tous** les autres validateurs de forme, qui
refusaient eux aussi le vide : `email` (que nous avons instruit et confirmé),
`url`, `ip`, `creditCard`, `phone`, `numeric`, `integer`, `dateString`,
`minLength`, `maxLength`, `min`, `max`, `equal`, `notEqual`, ainsi que
`address(enforceFormat: true)` et `percentage(enforceRange: true)`. Tous
acceptent désormais une valeur absente. `password` se comportait déjà ainsi ;
`required` est inchangé.

**Rupture douce à vérifier.** Si vous vous appuyiez sur l'effet de bord « poser
un motif (ou un format) rend le champ obligatoire », ce champ est maintenant
soumissible à vide : **ajoutez-lui `ZValidatorSpec.required()`**. Le verrou de
format, lui, est intact — une valeur non conforme reste refusée. Les champs qui
déclaraient déjà `required` ne changent pas de comportement.

## 1.0.1 — 2026-08-15

### Corrigé

#### Un ornement `.widget` était rendu aveugle à la valeur du champ qu'il orne

Un ornement `leading`/`prefix`/`suffix` de type `.widget` recevait `null` en
guise de valeur, alors même que le socle tenait déjà celle du champ décoré. Le
cas le plus naturel — un suffixe qui dépend de la saisie en cours, par exemple
une action « Réauthentifier » qui n'a de sens qu'une fois l'ancien mot de passe
renseigné — était donc hors d'atteinte, sauf à détenir l'état hors du
formulaire.

L'ornement reçoit désormais la **valeur courante** de la tranche qu'il orne
(`ZFieldWidgetContext.value`) et la voit **changer** avec elle, y compris quand
il est hissé dans la fiche d'un champ `large`. Il reste un **affichage** : son
`onChanged` demeure inerte — lire n'est pas écrire.

### Ajouté

#### Lire un autre champ du même formulaire depuis un widget hôte

`ZFieldWidgetContext` expose `valueOf` : une lecture **par nom** des autres
champs du formulaire qui rend le champ. Elle sert aussi bien un champ
`EditionFieldType.widget` (ou `custom`) qu'un ornement `.widget`, et couvre le
besoin d'un widget monté **dans** la liste de champs, qui doit réagir à la
saisie d'un voisin sans que l'application ait à détenir l'état elle-même.

La lecture est **réactive et ciblée** : le socle observe les noms que le
builder consulte réellement et ne reconstruit que ce champ quand l'une de ces
valeurs change. Modifier un champ que le widget ne lit pas ne le reconstruit
pas ; un widget qui ne lit rien n'est abonné à rien de plus qu'avant.

La surface reste volontairement étroite : `valueOf` **ne fait que lire** — pas
d'écriture, pas d'accès à l'état complet du formulaire, pas de contrôleur
publié. Un nom inconnu rend `null` sans jamais lever. Hors formulaire
(composition manuelle, prévisualisation), `valueOf` vaut `null` : appelez-le
avec `?.call(...)` et prévoyez le repli.

```dart
registre.register('reauth', (context, ctx) {
  final ancien = ctx.valueOf?.call('ancienMotDePasse');
  final actif = ancien != null && '$ancien'.isNotEmpty;
  return TextButton(
    onPressed: actif ? _reauthentifier : null,
    child: const Text('Réauthentifier'),
  );
});
```

## 1.0.0 — 2026-08-14

### Corrigé

#### Un listing trié sur une date facultative perdait, en silence, les éléments non datés

Quand un listing est servi **en mémoire** — parce qu'il déclare un post-filtre,
une disjonction, le mode mémoire, ou simplement parce qu'une recherche est en
cours — le jeu est lu **en entier** puis ordonné par le moteur du socle. Le tri
partait pourtant **aussi** à la source, où il ne servait plus à rien : l'ordre
final était de toute façon recalculé.

Il n'était pas sans effet pour autant. Sur un backend documentaire, un ordre
serveur **exclut** les documents dépourvus du champ trié. Trier un listing sur
une date facultative en retranchait donc tous les éléments non datés — sans
message, sans erreur, sans rien qui distingue « il n'y en a pas » de « ils ont
été écartés ». Restait une alternative sans issue : déclarer le tri et amputer
la liste, ou renoncer à l'ordre.

La requête d'une lecture servie en mémoire ne porte plus de tri. L'ordre demandé
est rendu par le moteur du socle, qui **classe** les valeurs absentes au lieu de
les retrancher — dernières en ordre croissant, premières en décroissant. Un
listing affiche donc tout ce qu'il a lu, et aucun index composite n'est exigé
pour un tri qui ne s'applique qu'en mémoire.

**Ce qui ne change pas** : un listing à périmètre requêtable garde son tri
**et** sa pagination **serveur**, à l'identique. La correction ne touche que la
lecture non paginée de la voie mémoire.

⚠️ **Si vous compensiez** — en renonçant au tri déclaré, en le ré-appliquant
après coup, ou en réintroduisant à la main les éléments perdus — cette
compensation **s'ajoute** désormais à la correction : elle est à retirer.

### Ajouté

#### Une clause que seule la base sait trancher

Dès qu'un listing est servi en mémoire, les filtres de la requête sont
**ré-appliqués** aux lignes projetées : c'est ce qui les rend exacts devant une
source qui ne les traduit pas. Mais une clause qui vise un champ **absent de la
ligne** — une valeur calculée, jamais persistée, ou une colonne que l'écran
n'affiche pas — n'y trouve rien, et **vide le listing dès le premier rendu**. Le
seul contournement était d'ajouter une colonne « pont » au seul bénéfice du
filtre, et certaines clauses restaient impossibles à porter.

`ZFilter.servedBySource` déclare l'exception :

```dart
// `etat_depotage` est calculé côté source : aucune colonne ne le porte.
baseFilters: <ZFilter>[
  ZFilter.servedBySource('etat_depotage', ZFilterOp.isIn, <String>['termine']),
],
```

La clause part dans la requête comme n'importe quelle autre — un adaptateur la
traduit sans avoir à la distinguer — et le socle ne la rejoue **jamais** sur les
lignes, ni en conjonction ni dans une disjonction. Le listing filtre à la
lecture, sans colonne-pont et sans se vider.

⚠️ **C'est une promesse faite à la source, pas une garantie du socle.** Devant
un dépôt qui ne sert pas la clause, elle ne filtre **rien** et l'écran montre
plus que ce qui a été déclaré, sans erreur ni avertissement. À réserver aux
clauses dont votre dépôt est connu capable ; partout ailleurs, une clause
ordinaire — ré-appliquée, donc exacte — ou un post-filtre écrit sur l'entité
restent les bonnes voies.

**Rien ne change sans déclaration** : `ZFilter` conserve son comportement, ses
requêtes et ses tests.

## 0.99.0 — 2026-08-14

### Ajouté

#### Une plage de dates peut enfin déclarer son amplitude

`ZDateConfig` savait dire **où** une période se situe (`minDateIso`,
`maxDateIso`, `firstDateKey`, `lastDateKey`) mais pas **quelle largeur** elle
peut avoir. Cette contrainte n'est pas une préférence d'ergonomie : sur les
écrans qui alimentent une lecture ou un export à partir d'une période, c'est
elle qui protège la requête. Et son absence est **silencieuse** — un champ sans
amplitude fonctionne parfaitement, l'utilisateur choisit trois ans, et le
premier symptôme est une lenteur ou un export inexploitable, jamais un message
qui pointe la cause.

Deux nouvelles clés, pour le type `dateRange` :

```dart
ZFieldSpec(
  name: 'periode',
  type: EditionFieldType.dateRange,
  config: ZDateConfig(maxDays: 45, minDateIso: '2023-01-01'),
)
```

**Le comptage porte sur les jours, bornes incluses.** `maxDays: 7` autorise
« du 1er au 7 janvier » (7 jours) et refuse « du 1er au 8 » (8 jours) ; une
période d'une seule journée compte pour 1. Le nombre déclaré et le nombre
annoncé à l'utilisateur sont **le même** — le message le dit d'ailleurs mot
pour mot : « La période ne doit pas dépasser 45 jours (bornes incluses) ».

**Le refus a lieu à la sélection**, pas à la validation du formulaire : quand
le sélecteur rend une période hors amplitude, elle n'est pas écrite, le champ
**conserve sa valeur précédente**, et le motif est présenté sur le champ
concerné — et annoncé aux lecteurs d'écran. L'utilisateur n'a jamais à deviner
quel champ corriger.

`minDays` est le symétrique. Une déclaration hors de sens (valeur inférieure à
1, ou `minDays` supérieur à `maxDays`) est **ignorée** plutôt que de bloquer le
champ. Un champ qui ne déclare aucune amplitude se comporte exactement comme
avant.

Nouveaux membres publics : `ZDateConfig.maxDays`/`minDays`,
`ZDateConfig.effectiveMaxDays`/`effectiveMinDays`/`checkSpanDays`,
`ZDateSpanVerdict`, `ZDateRange.spanDays`, `zDateSpanRefusalMessage`,
`zShowDateSpanRefusal`. Libellés `dateRangeTooLong`, `dateRangeTooShort`,
`daysInclusive` (tables `en` et `fr`).

### Corrigé

#### Les bornes d'une plage de dates étaient déclarées mais jamais appliquées

Un champ `dateRange` portant `minDateIso`/`maxDateIso`/`firstDateKey`/
`lastDateKey` déclarait des bornes que le sélecteur **n'a jamais reçues** : il
s'ouvrait sur l'intervalle de repli 1900–2100, et l'utilisateur pouvait choisir
n'importe quelle date. Seule la famille date sœur les honorait. Les bornes sont
désormais résolues et transmises au sélecteur, selon la même règle qu'ailleurs
(littéral prioritaire sur la clé d'un autre champ, résolution **au moment du
geste**), et elles se **cumulent** avec l'amplitude : une période peut être
conforme au calendrier proposé et refusée pour sa largeur.

⚠️ **À vérifier chez vous** : si un écran compensait ce défaut — bornes
restituées par un validateur, par une correction après coup, ou par des dates
volontairement laissées hors config — cette compensation **s'ajoute** désormais
au comportement natif. Les écrans qui déclaraient simplement leurs bornes en
attendant qu'elles s'appliquent n'ont rien à faire.

## 0.99.0 — 2026-08-14

### Ajouté

#### Une disjonction dans les filtres : « cette valeur **ou** ce champ absent »

Les `ZFilter` d'une requête se composaient uniquement en **conjonction**. C'est
la bonne règle pour un listing, mais elle ne sait pas dire le cas le plus
courant d'un workflow : *l'état initial est l'absence d'état*. Un onglet
« En attente » exprimé par la seule égalité `etat == enAttente` se vidait des
dossiers fraîchement déposés, dont le champ n'a jamais été écrit — sans
message, sans erreur.

`ZFilterGroup.any([...])` exprime cette règle, et `ZDataRequest.filterGroups`
la transporte : chaque groupe est ANDé aux filtres et aux autres groupes, mais
ses clauses sont résolues en **OU**.

```dart
ZFilterGroup.any(<ZFilter>[
  ZFilter('etat', ZFilterOp.eq, 'enAttente'),
  ZFilter('etat', ZFilterOp.isNull),
])
```

Un groupe élargit **à l'intérieur de lui-même**, jamais au-delà : il ne peut
pas faire ressortir une ligne qu'un filtre permanent, une catégorie d'onglet ou
la portée de corbeille ont exclue. Un groupe **sans clause** est inerte — il
n'impose rien, plutôt que de vider un listing sur une liste de clauses calculée
qui se trouve vide.

Le moteur de liste du socle (`zApplyListRequest`) sert les groupes. Un
adaptateur qui exécute la requête côté serveur reste libre de ne pas les
traduire, comme il l'est déjà pour la recherche : c'est pourquoi en déclarer un
**impose la voie mémoire** au listing (voir ci-dessous). Champ additif,
défaut vide : aucune requête existante n'est affectée.

#### Un post-filtre écrit sur l'entité, pour les périmètres non requêtables

Sur la voie dépôt, le périmètre d'un listing était **entièrement** dérivé de sa
requête : il n'existait aucun point d'accroche entre la lecture de la source et
le rendu. Un écran dont le périmètre appartient au métier — croisement de
droits, fenêtre de dates calculée, catégorie qui n'existe pas en base — n'avait
donc pas de voie honnête : basculer sur le dépôt aurait élargi ou amputé ce que
voit l'usager.

`ZListController.itemFilter` est ce point d'accroche : un prédicat **écrit sur
l'entité** `T`, appliqué aux entités lues, après la lecture de la source et
**avant** leur projection en lignes — donc avant la recherche, le tri et la
pagination. Une page pleine reste pleine. `ZItemFilter.of<T>(…)` porte le même
prédicat dans les déclarations (`ZListTab.itemFilter`, et la politique de
requête de `zcrud_screen`), en le gardant typé sur l'entité : renommer un champ
devient une erreur de compilation, jamais un listing qui se met à tout montrer.

Il ne peut que **restreindre** — aucune entité que la requête n'a pas ramenée
ne peut réapparaître — et il se compose en conjonction avec celui d'un onglet :
chaque niveau retire, aucun ne rouvre.

#### Une déclaration de périmètre n'est jamais ignorée en silence

Un post-filtre et une disjonction ont ceci de commun qu'aucune source n'est
réputée savoir les servir. Le contrôleur de liste **bascule donc sur le chemin
mémoire** dès que l'un des deux est déclaré — le même chemin qu'emprunte déjà
une recherche que le dépôt délègue — au lieu de laisser la pagination curseur
les ignorer.

**Ce que cela coûte** : le jeu est lu **en entier** à chaque requête, et pour
toute la vie du listing (là où la bascule d'une recherche ne dure que le temps
du terme saisi). C'est le prix de l'exactitude, raisonnable sur un listing
borné, à proscrire sur une collection sans borne. Une disjonction **sans
clause** ne déclenche rien : elle n'exprime aucune intention.

**Rien de déclaré, rien de changé** : un listing sans post-filtre ni
disjonction émet exactement les mêmes requêtes qu'avant, pagination serveur
comprise.

## 0.98.0 — 2026-08-14

### Corrigé

#### `ZRepository.save` documente enfin ce que `collectionId` fait vraiment

La documentation du port se contentait de « localise le conteneur si
nécessaire », formule assez neutre pour être lue comme une clé d'autorisation.
Elle en désigne en réalité l'inverse : quand un adaptateur l'honore,
`collectionId` **remplace** l'emplacement d'écriture du dépôt. Y passer la clé
de gouvernance d'un écran envoyait donc les données ailleurs, sans erreur, dans
un conteneur que les lectures du même dépôt n'interrogent jamais.

La dartdoc nomme désormais cette redirection, avertit de l'homonymie avec le
`collectionId` de `ZAcl.can`, et pose la règle : `null` — le cas normal — écrit
là où le dépôt écrit ; une valeur ne se renseigne que pour une redirection
voulue, vers un conteneur dont l'appelant connaît le nom réel.

Aucun changement de signature ni de comportement : le paramètre reste au
contrat, et les appelants qui l'utilisent délibérément ne sont pas affectés.

## 0.97.0 — 2026-08-14

### Ajouté

#### Une source peut désormais **déclarer** qu'elle ne sait pas chercher

Un dépôt reçoit un terme de recherche dans chaque requête, et rien ne
permettait de savoir s'il le servait. Les listings le **supposaient** — au
détriment des sources qui ne le peuvent pas : Firestore n'a ni `LIKE`, ni
recherche plein-texte, ni pliage diacritique, et rendait donc la liste entière
quel que soit le terme saisi.

Le mixin `ZDelegatesSearch<T>` remplace la supposition par une déclaration :
un dépôt qui l'applique dit au socle qu'il délègue la recherche. Il ne coûte
rien à écrire (aucun membre à implémenter) et **ne casse aucune implémentation
existante** : ne pas l'appliquer signifie « je sers la recherche », le
comportement historique. `zRepositoryServesSearch(depot)` lit la capacité.

C'est la même forme que `ZPurgeable` — une capacité déclarée, jamais devinée
d'après le type du dépôt.

### Corrigé

#### Sur une source qui ne sait pas chercher, la recherche filtre enfin

`ZListController` interroge la capacité au moment où un terme est saisi. Si la
source la délègue, le listing emprunte le **chemin mémoire** — celui-là même
qu'il empruntait déjà quand un curseur n'était pas honoré — et le filtrage
devient exact : portée des champs `searchable` inchangée, pliage diacritique
tenu (« elephant » trouve « Éléphant »), et un terme sans correspondance rend
la liste **vide** au lieu de la totalité.

**Ce que cela coûte, et quand** : le chemin mémoire lit le jeu **non paginé**.
La bascule ne s'applique donc que **tant qu'une recherche est active** — sans
terme, la pagination curseur reste le chemin nominal, et aucune lecture
supplémentaire n'a lieu. Le terme effacé ramène immédiatement la voie paginée.
Ce chemin convient à un listing dont le jeu tient en mémoire ; au-delà, la voie
tenable reste un champ de recherche normalisé pré-calculé côté application —
le dépôt sert alors la recherche et n'applique pas le mixin.

## 0.95.0 — 2026-08-14

### Ajouté

#### Validation agrégée et normalisation des saisies, en fonctions publiques

Trois fonctions pures rendent explicite ce que la soumission faisait déjà, et
le rendent réutilisable par toute surface d'édition :

- `zValidateFormFields(fields:, controller:)` — la table `champ → message` des
  champs **visibles** en erreur (vide ⇒ formulaire valide), sans rien afficher ;
- `zNormalizeFormValues(fields:, controller:)` — les valeurs projetées vers
  leur forme de persistance : types coercés, dates en ISO-8601, heures en
  `HH:mm`, plages en `{start, end}`, valeurs d'énumération en camelCase. Les
  champs **en lecture seule** et ceux qu'une **condition d'affichage masque**
  en sont absents ;
- `zNormalizeFieldValue(spec, value)` — la même projection, pour une valeur.

Une valeur qui ne se laisse pas convertir est rendue **inchangée** : c'est au
validateur de refuser une saisie, jamais à la normalisation de la perdre
(AD-10). `ZEditionSubmitController` valide désormais **par** ces fonctions —
une seule règle, partagée par toutes les voies de soumission.

#### `ZListTab.builder` devient **optionnel** — l'onglet assemblé

Un `ZListTab` peut désormais se déclarer **sans vue** : il ne porte alors que
sa catégorie (`baseFilters`) et, s'il y a lieu, ses droits (`acl`), et c'est
l'**assembleur** qui l'héberge (`ZCrudScreen`) qui lui construit sa vue. C'est
un **défaut, pas un remplacement** : un onglet qui fournit son `builder` reste
libre de rendre ce qu'il veut — vue carte, carte mentale, tableau de bord.

Monté nu dans un `ZTabbedList`, un onglet sans vue rend une **page vide** :
jamais d'exception (AD-10).

### Corrigé

- `ZTabbedList` ne notifie plus `activeIndexNotifier` **pendant une
  construction**. Quand l'index publié au montage diffère de la valeur déjà
  portée par le notifieur — remontage au-dessus d'un notifieur déjà avancé, ou
  `initialIndex` non nul — la mise à jour est reportée à la fin de la frame
  courante au lieu de réveiller des abonnés en cours de construction (ce qui
  levait un « setState() called during build »). Quand la valeur est déjà la
  bonne — le cas de très loin le plus courant — rien n'est notifié et le
  timing est celui d'avant.

### Impact sur votre code

- **Hôte passif** : **rien à faire**. `builder` reste accepté et se comporte à
  l'identique ; seule son obligation disparaît.
- **Code qui LISAIT `tab.builder`** : le type devient `WidgetBuilder?` — un
  appel direct `tab.builder(context)` doit désormais traiter le cas `null`
  (l'onglet est assemblé, sa vue vient de l'assembleur).

## 0.93.0 — 2026-08-13

### Modifié — rupture

#### Autorisations : refus par défaut (fail-closed) partout

Jusqu'ici, tant qu'aucune ACL n'était déclarée, le socle repliait sur
`ZAllowAllAcl` : une application qui **oubliait** de brancher la sienne voyait
**tous** les gestes (créer, modifier, mettre à la corbeille, restaurer, actions
de ligne, actions de formulaire) au lieu d'**aucun**. Rien ne levait, rien ne
signalait l'oubli. Le repli est désormais **refusant**.

- Nouveau `ZDenyAllAcl` : implémentation de `ZAcl` qui refuse tout. C'est le
  repli de tous les points qui consultent une ACL sans en avoir reçu une.
- `ZcrudScope.acl` : défaut `ZAllowAllAcl()` → `ZDenyAllAcl()`.
- `DynamicList` : sans `ZcrudScope` ambiant, les actions de ligne portant une
  `requiredPermission` ne sont plus offertes. Les actions **sans** permission
  (custom) restent offertes, comme avant.
- `DynamicEdition.acl` devient **nullable** (`ZAcl?`, défaut `null`) : la
  résolution suit désormais **paramètre > ACL du `ZcrudScope` ambiant >
  refus**. Passer une ACL explicite reste possible et prioritaire.
- `ZSubListFieldWidget.acl` devient **nullable**, avec la même résolution. Le
  câblage du mode compact ne dépend plus de `ZSubListConfig.aclCollectionId` :
  l'ACL du scope gouverne les gestes d'item **avec ou sans** discriminant,
  celui-ci ne servant qu'à désigner la collection interrogée.

**Échappatoire explicite.** `ZAllowAllAcl` reste public et documenté : il
redevient l'ouverture totale, mais **déclarée** —
`ZcrudScope(acl: const ZAllowAllAcl())`. Le geste est volontaire et lisible
dans le code de l'application ; c'est toute la différence avec un repli
implicite.

#### Libellés : les clés manquantes rejoignent les deux tables

Six clés étaient **consommées** par `label(context, …)` sans exister dans
`_enLabels`/`_frLabels` : `trash`, `back`, `selectDateRange`, et les trois clés
de navigation de l'assistant (`z.stepper.previous`/`next`/`finish`). Le repli
silencieux de `label()` masquait le trou — une traduction française n'atteignait
jamais ces libellés.

- Ajout de `trash`, `back`, `selectDateRange`, `z.stepper.previous`,
  `z.stepper.next`, `z.stepper.finish`, `accessDenied`,
  `accessDeniedMessage` et `details` dans **les deux** tables. `details`
  (« Details » / « Détails ») intitule la **fiche de consultation** ouverte
  par un écran assemblé en mode « Détails » — distincte de `edit`, qui annonce
  une modification, et de `viewItem`, qui désigne un élément de sous-liste.
- ⚠️ **Rupture visible sur l'assistant multi-étapes** : les libellés
  « Précédent / Suivant / Terminer » étaient codés en **français** comme repli
  de dernier recours, alors que la table par défaut du socle est l'anglais. Une
  application qui **monte** `ZcrudLocalizationsDelegate` avec la locale `fr`
  voit exactement les mêmes libellés qu'avant ; une application qui ne le monte
  pas voit désormais « Previous / Next / Finish », cohérents avec tous les
  autres libellés du socle. Si le français est attendu, montez le delegate (ou
  surchargez ces clés via `ZcrudScope(labels:)`).
- Une garde de source vérifie désormais que **toute** clé littérale passée à
  `label(context, …)` dans `zcrud_core/lib` et `zcrud_screen/lib` existe dans
  les deux tables.

### Ajouté

#### Un contrôleur de liste qui naît trié (`ZListController.initialSorts`)

Le tri d'une liste ne s'obtenait que par `setSort`, appelé après construction :
la première requête partait non triée, une seconde la remplaçait aussitôt — une
lecture de la source pour rien, et un premier rendu dans le mauvais ordre. Un
assembleur devait contourner par un décorateur de dépôt. `initialSorts` fait
porter le tri à la **toute première** requête. Défaut vide ⇒ requêtes
strictement identiques. Un `setSort` ultérieur remplace ce tri, comme avant.

#### Le socle de filtres d'un onglet est déclaré (`ZListTab.baseFilters`)

La catégorie d'un onglet ne vivait que dans la fermeture de `ZListTab.category`,
donc invisible à qui héberge les onglets : chaque page devait aller chercher la
politique de l'écran pour y mêler sa catégorie. Elle est désormais **lisible**,
ce qui permet à un assembleur de composer la requête d'un onglet à la place de
sa page. `ZListTab.category` la renseigne (le `buildList` la reçoit toujours),
`filtersWith` compose sans jamais remplacer, `copyWith` permet d'envelopper la
vue d'un onglet sans recopier ses déclarations.

#### Numérotation continue d'une page à l'autre (`ZListOrdinal.continuousAcrossPages`)

`pageOffset` suppose que l'application sache dans quelle page elle se trouve —
faux dès que c'est le rendu qui pagine, l'index de page lui étant privé : la
numérotation continue y était **inatteignable**. La règle reste au cœur, seule
la position vient du rendu (`textAt(displayIndex, pageIndex:, pageSize:)`).
Défaut `false` ⇒ chaque page repart de `1`, comme avant.

#### Actions de lot : l'inertie se déclare (`ZBatchAction.enabled`)

Une action de lot était présente ou absente, jamais grisée — un mode d'ACL
« désactiver » ne pouvait donc s'exprimer que par l'effet, pas par l'apparence.
`enabled: false` garde l'action en place, non actionnable, et annonce son motif
(`disabledReason`, `Semantics(enabled: false)`) : la parité exacte des actions
de **ligne**. `onSelected == null` continue de la retirer.

#### `ZBatchActionKind.restore`

La restauration en lot devait se déclarer `custom`, c'est-à-dire « hors
nomenclature », alors qu'elle est le pendant exact de `delete`.

#### La sélection peut s'ouvrir à l'appui long (`ZListSelectionActivation`)

`DynamicList(selectionActivation: ZListSelectionActivation.longPress)` n'affiche
les cases qu'une fois la sélection non vide, et fait de l'appui long sur une
ligne le geste qui l'ouvre — le motif tactile usuel, jusqu'ici inexprimable.
Aucun état supplémentaire : « ouverte » **est** « non vide », si bien qu'un
vidage venu d'ailleurs referme la sélection de lui-même. Vues `builder` et
`grid` ; sur le chemin `dataGrid`, les gestes de ligne appartiennent au backend.
L'appui long étant réclamé par plusieurs fonctions, l'arbitrage se **déclare**
chez l'assembleur (`ZRowLongPressOwner` de `zcrud_screen`).

#### Export d'une liste : le port `ZListExporter`

Produire un `.csv`, un `.xlsx` ou un `.pdf` demande une bibliothèque lourde.
Le cœur ne déclare donc que le **contrat**, et les implémentations vivent dans
les paquets d'export : un hôte qui n'exporte rien ne tire rien.

- **`ZListExporter`** — un identifiant de format, sa clé de libellé, son
  extension, son type MIME, et une production d'octets à partir de la
  `ZListRenderRequest` déjà construite par la liste (colonnes dérivées +
  lignes). Aucune entité, aucun dépôt, aucun widget : l'exporteur reçoit
  exactement ce que l'écran montre.
- **`ZListExporter.exportSafely`** — appel blindé : un exporteur qui **lève**
  rend un `Left(ZDomainFailure)` portant le jet d'origine, jamais une exception
  qui emporterait l'écran.
- **`ZExportedBytes`** — le fichier produit : octets, nom suggéré, type MIME.
  Sa **destination** (enregistrer, partager, imprimer) n'est pas une décision
  d'écran : elle reste à l'application.
- **`zExportFileName(titre, extension)`** — compose un nom de fichier sûr à
  partir d'un titre libre (accents, ponctuation, barres obliques écartés), avec
  repli `export.<ext>` plutôt qu'un fichier nommé `.csv`.

Les **colonnes techniques** ne sont pas exportables par construction : la
colonne de numéro d'ordre vit hors des colonnes (`ZListRenderRequest.ordinal`),
les champs d'identité sont écartés à la dérivation, et les cases à cocher comme
les boutons d'action sont des ornements de rendu.

#### `zListFormatOf(context)` — la voie unique des seams d'affichage

Le libellé d'option orpheline, le port de formatage des dates et l'étiquette de
locale se lisaient dans `DynamicList` et nulle part ailleurs. Ils sont désormais
exposés par une fonction publique, que la liste **et** un export lancé depuis un
écran partagent : ce que l'utilisateur lit à l'écran est ce que son fichier
contient. Reconstruire cet objet à la main rouvrirait l'écart, sans erreur ni
signe visible.

#### Libellés génériques

Nouvelles clés dans les **deux** tables (`en`/`fr`) : `export`, `exportEmpty`,
`exportFailed`, ainsi que `selectedCount`, `selectAll`, `batchSucceeded`,
`batchFailed`, `batchSkipped` — ces cinq dernières étaient consommées par
l'écran assemblé mais absentes des tables, et retombaient donc sur un repli
codé en dur, jamais traduit.

#### Recherche : le domaine des colonnes et la normalisation se déclarent

La recherche de liste interrogeait les seuls champs `searchable` et comparait
en ignorant la casse et les accents. Deux réglages **additifs** portés par
`ZDataRequest` la rendent déclarative, sans changer son défaut :

- `ZSearchScope` — `searchableFields` (défaut, comportement historique) ou
  `allColumns` : **toutes** les colonnes du schéma, le domaine des moteurs de
  liste déclaratifs antérieurs. Un champ visible à l'écran redevient trouvable
  sans avoir à annoter le schéma champ par champ.
- `ZSearchFolding` — `diacritics` (défaut, comportement historique) ou
  `diacriticsAndSpaces` : ignore en plus **tous** les blancs (espace, espace
  insécable, tabulation, saut de ligne), de sorte que « SOCIETE X SARL U » se
  laisse trouver par « sarlu ». La ponctuation reste significative dans les
  deux modes.

Surface : `ZDataRequest.searchScope` / `.searchFolding` (défauts
rétro-compatibles, transportés par `copyWith`), `zFoldDiacritics(input,
folding:)`, `zMatchesSearch(row, term, schema:, scope:, folding:)` et
`ZListController(searchScope:, searchFolding:)` — le contrôleur les porte dans
**chaque** requête émise, première page et pages suivantes comprises.
`zApplyListRequest` les sert.

**Non cassant** : sans rien déclarer, une requête par défaut est **égale en
valeur** à celle d'avant et le moteur rend exactement les mêmes lignes (garde
de contre-témoin dédiée). Un adaptateur qui exécute la recherche côté serveur
reçoit les deux réglages mais reste libre de ne pas les servir — l'adaptateur
Firestore, qui ne sert pas `search`, est inchangé.

#### Onglets gouvernés : droits, intitulés et compteur par onglet

Un onglet ne portait que son libellé et son contexte de création. Un écran
segmenté par entité affichait donc le **même** intitulé de formulaire partout,
sans moyen de fermer une écriture sur un segment précis ni d'annoncer son
volume.

- `ZListTab.acl` : restriction de droits **propre à l'onglet**. Elle se compose
  en **cascade** avec celle de l'écran, puis du scope.
- 🔒 **La cascade restreint, elle n'élargit jamais.** L'onglet est intersecté
  avec le niveau supérieur : quelle que soit la générosité de ce qu'il déclare,
  un geste refusé plus haut le reste. Sans aucun niveau supérieur monté, la
  composition retombe sur le refus — déclarer des droits sur un onglet n'en
  crée jamais à partir de rien.
- Nouveaux `ZRestrictedAcl` et `zRestrictAcl(base, restriction)` : la
  composition conjonctive de deux `ZAcl`, réutilisable partout où deux niveaux
  d'autorisation se rencontrent. L'élargissement y est **inexprimable**.
- `ZListTab.titles` (`ZCrudTitles`) : intitulés de formulaire de l'onglet
  (« Nouveau dossier » ici, « Nouvelle pièce » à côté). Un mode non renseigné
  retombe sur l'écran, puis sur la clé l10n générique.
- `ZListTab.countOf` (`ValueListenable<int>`) : compteur affiché en pastille à
  côté du libellé. C'est une valeur **écoutable**, et c'est délibéré — la
  pastille se redessine seule, la page de l'onglet n'est pas reconstruite. Le
  cœur ne compte jamais lui-même : compter, c'est lire la source.
- `ZCrudTitles` **vit désormais dans `zcrud_core`** (et reste exporté par
  `zcrud_screen` à l'identique) : c'est ce qui permet à un onglet de porter ses
  intitulés sans que le cœur connaisse l'écran assemblé.
- `ZTrashPolicy` gagne `showCount` (afficher le volume de la corbeille sur son
  accès) et `visibleWhenEmpty` (`false` retire l'accès tant que la corbeille est
  vide). Défauts inchangés : `showCount: true`, `visibleWhenEmpty: true`.
- Clé l10n `trashCount` (`en` + `fr`), qui **nomme** ce que compte la pastille
  dans l'annonce lue par les technologies d'assistance.


#### Gouvernance par ligne : les droits d'UNE entité

Les autorisations du socle s'arrêtaient à la collection : « peut-on supprimer
ici ? », jamais « peut-on supprimer **cette** ligne-là ? ». Un dossier clôturé,
une pièce déjà validée, un élément protégé réclamaient donc du filtrage maison
en amont des actions — hors de toute garantie du socle.

- Nouveau `ZRowPermissions` : ce qu'une ligne **retire**, jamais ce qu'elle
  accorde — `.unrestricted()` (neutre, `const`), `.locked()` (toutes les
  écritures tombent, consultation et historique restent), `.denying({…})`, avec
  un `reasonKey` facultatif annonçant le motif.
- Nouveau `ZRowAclResolver<T>` (`ZRowPermissions Function(T entity)`), déclaré
  sur `DynamicList.rowAcl` : **un seul** point d'extension pour toute la
  gouvernance de ligne. Ajouter un besoin n'ajoute jamais un paramètre.
- 🔒 **Il restreint, il n'élargit jamais.** La composition avec l'ACL de
  l'application est une **intersection** : un résolveur, même écrit permissif,
  ne peut pas rouvrir un geste que l'ACL refuse — le vocabulaire de
  `ZRowPermissions` ne permet même pas de l'exprimer. Une garde adversariale
  dédiée fige la règle.
- Nouveau `ZRowAction.enabledFor` (+ `ineligibleReasonKey`, et
  `withEligibility(...)` pour en poser un sur une action de fabrique) :
  l'**éligibilité métier** d'une action, distincte du droit. « Restaurer » sur
  un élément vivant n'est pas un refus d'autorisation : l'action existe, elle
  ne s'applique pas ici. Une action inéligible est **toujours rendue, inerte et
  motivée**, jamais masquée — la présentation des refus de **droit**, elle,
  reste gouvernée par le `ZActionAclMode` déclaré.
- `ZResolvedRowAction.disabledReasonKey` (additif) porte ce motif jusqu'au
  rendu : le bouton de ligne l'annonce en indice sémantique, à côté du
  `Semantics(enabled: false)` qu'il posait déjà.
- Nouvelle voie de résolution partagée `zResolveRowActions` : la liste et
  l'écran assemblé y passent tous deux, pour qu'aucune présentation ne puisse
  dériver de l'autre sur une question de droits.
- Nouvelle clé de libellé générique `actionNotApplicable` (`en`/`fr`).

Sans `rowAcl` déclaré ni `enabledFor` posé, le comportement est **strictement
inchangé** (contre-témoin sous garde).

#### Corbeille : le troisième geste, la suppression définitive

La corbeille du socle savait y mettre et en sortir. Elle sait désormais aussi
détruire — sans que cela devienne une obligation pour les dépôts qui ne le
peuvent pas.

- Nouveau mixin `ZPurgeable<T extends ZEntity>` (`Future<ZResult<Unit>>
  purge(String id)`) : la suppression définitive est une capacité **déclarée**
  par le dépôt, **pas** un membre du port `ZRepository`. Aucune implémentation
  existante n'a à changer ; un dépôt qui ne l'applique pas reste complet et
  valide, et les assemblages n'offrent alors simplement aucun geste de purge.
  Le mixin ne pose aucune contrainte de superclasse : il s'applique à un dépôt
  quelle que soit la façon dont celui-ci satisfait le port (`with` ou
  `implements`). Contrepartie documentée : le test `is ZPurgeable<T>` ne
  **promeut** pas une variable déclarée `ZRepository<T>`, un cast explicite
  reste nécessaire.
- Nouvelle fabrique `ZRowAction.purgeWith(handler)`, symétrique de
  `softDeleteWith`/`restoreWith` : permission requise `ZCrudAction.clear`,
  style destructif, identité `purge`, libellé `deleteForever`. Elle n'a pas de
  jumelle à dépôt, précisément parce que la purge n'appartient pas au port.
- Nouveau `ZTrashPolicy` — quels gestes une corbeille offre (`softDelete`,
  `restore`, `purge`), avec les raccourcis `full` (défaut), `withoutPurge` et
  `readOnly`. Trois questions distinctes se composent en conjonction : le geste
  est-il **voulu** (ce type), **possible** (la source sait-elle le servir),
  **autorisé** (`ZAcl`). Déclarer un geste ici n'accorde jamais un droit refusé
  en amont.
- Libellés génériques `deleteForever` et `confirmDeleteForeverItem` (tables
  `en` et `fr`). Leur texte est **distinct** de `delete`/`confirmDeleteItem` :
  la mise à la corbeille se défait, la suppression définitive annonce son
  irréversibilité.

#### Tuiles **typées** : une carte reçoit l'entité, plus seulement la ligne

Une grille de cartes métier n'a que faire d'un sac de cellules : elle veut
l'objet. Les layouts qui rendent des tuiles savent désormais le lui donner.

- Nouveau `ZEntityTileBuilder<T extends ZEntity>` —
  `Widget Function(BuildContext, T entity, List<ZListColumn> columns)` — et
  `ZRowTileBuilder`, qui nomme la forme historique (`ZListRow`).
- `ZListGridLayout.forEntity<T>(…)` et `ZListBuilderLayout.forEntity<T>(…)`
  déclarent une tuile typée ; le paramètre `entityBuilder` des constructeurs
  principaux fait de même sous forme non générique.
- `ZListLayout.withEntityTiles<T>(builder)` : un **assembleur** (`ZCrudScreen`)
  fait descendre la tuile typée déclarée par l'application dans le layout que
  cette même application a choisi. Une variante sans tuiles (`dataGrid`,
  `custom`) ou portant **déjà** sa tuile retourne `this` — l'explicite l'emporte
  sur l'injecté, aucun rendu déclaré ne change.
- L'entité est résolue par le seam **déjà déclaré** `DynamicList.entityFor`
  (`ZListRow → T?`) : une seule déclaration sert l'ACL par entité, les actions
  de ligne **et** le rendu des cartes. Ligne dont l'entité reste introuvable :
  repli sur la tuile de ligne du layout, jamais d'exception (AD-10).
- `ZListRow.keyOf(entity)` et `ZListRow.ofEntity(entity, cells)` publient la
  **convention de clé** de l'assemblage (identité réelle, ou clé éphémère
  stable si l'entité n'est pas persistée) : un hôte qui construit l'index
  `ligne → entité` n'a plus à la deviner.
- Les builders restent **hors** de `ZListRenderRequest` (value object à
  égalité de valeur) : ce sont des closures, dont l'identité change à chaque
  build. Les y faire entrer casserait la mémoïsation du rendu — même raison
  que l'exclusion de `ZFieldSpec.derivedFrom`/`choicesResolver` de
  `==`/`hashCode`. Une garde vérifie que deux rendus aux `entityFor`
  différents produisent des requêtes **égales**.

Compatibilité : `ZListGridLayout.itemBuilder` et `ZListBuilderLayout.itemBuilder`
deviennent **optionnels et nullables** (un layout peut désormais n'être que de
la géométrie, la tuile venant de l'assembleur). Les déclarations existantes
`ZListGridLayout(itemBuilder: …)` restent valides et rendent à l'identique ;
seul un code qui **lisait** `layout.itemBuilder` comme non-nullable doit
s'adapter.

#### Colonnes de liste : numéro d'ordre, devise par ligne, format sur la ligne, largeurs bornées

Quatre réglages de colonne rejoignent le cœur — donc **tous** les rendus
(tableau, cartes, grille, export), et non plus un seul backend.

- **Numéro d'ordre** — `ZListOrdinal`, déclaré par
  `ZColumnPolicy(ordinal: ZListOrdinal(enabled: true))` et porté par
  `ZListRenderRequest.ordinal`. La numérotation est **1-based sur la séquence
  rendue** : `request.ordinalTextAt(position)` et
  `request.ordinalTextsForDisplay(lignesAffichées)` la produisent au moment du
  rendu. Le numéro n'est **jamais** rangé dans les cellules de la ligne : un
  tri renumérote donc l'écran au lieu de promener d'anciens numéros.
  `pageOffset` permet une numérotation continue à travers les pages.
- **Devise par ligne** — `ZCurrencyFormat(codeField: 'currency',
  fallbackCode: 'XOF')` sur une colonne : chaque ligne s'affiche avec **sa**
  devise, lue dans le champ désigné. Une ligne dont ce champ est absent, nul ou
  vide retombe sur le **repli déclaré**, jamais sur la devise d'une autre
  ligne : la résolution est purement locale à la ligne, sans mémoire d'un rendu
  à l'autre. Un montant nul rend une cellule vide, jamais un code devise
  esseulé. `decimalDigits`, `placement` et `separator` complètent le rendu, qui
  reste locale-neutre.
- **`ZListColumn.formatWithRow`** — un format qui reçoit, en plus de la valeur
  de la cellule, **toute la ligne** : pour un suffixe d'unité rangé dans une
  colonne voisine, un libellé composé, un montant et sa devise. Nouveau point
  d'entrée `ZListColumn.formatRow(valeur, ligne)`, dont la précédence est
  `formatWithRow` > `currency` > `format`. Comme `format`, cette fonction est
  **exclue de l'égalité de valeur** : deux colonnes identiques aux formats
  différents restent égales, sans quoi la mémoïsation du rendu serait perdue à
  chaque build.
- **`ZListColumn.minWidth` / `maxWidth`** — bornes d'**encombrement à l'écran**
  (pixels logiques), à ne pas confondre avec une borne sur la valeur affichée
  ou un filtre. Un backend qui ne sait pas contraindre ses colonnes les ignore.

Ces trois derniers réglages se déclarent colonne par colonne via
`ZColumnPolicy(overrides: {'amount': ZColumnOverride(…)})`, sans toucher aux
annotations du modèle.

Compatibilité : entièrement additif. Sans `ordinal` ni `overrides`, la
dérivation des colonnes et le texte de chaque cellule sont **strictement**
inchangés, et `formatRow` rend exactement ce que rend `format`.

## 0.92.0 — 2026-08-12

### Ajouté

#### `ZTabbedList` / `ZListTab` / `ZListGridLayout` — ergonomie des écrans à onglets

- `ZTabbedList.header` : emplacement optionnel pour un widget partagé
  (barre de recherche…) rendu au-dessus de la barre d'onglets, dans le même
  arbre. `null` (défaut) = rendu inchangé.
- `ZListTab.pageKey` : identité technique de l'onglet découplée du libellé
  (repli sur `labelKey` si omise). Deux onglets homonymes deviennent valides
  avec des `pageKey` distinctes ; renommer un libellé ne casse plus l'identité
  keep-alive de la page. L'assert d'unicité porte désormais sur la clé
  effective (`pageKey ?? labelKey`).
- `ZTabbedList.activeIndexNotifier` : `ValueNotifier<int>` fourni (et possédé)
  par l'hôte, tenu synchronisé avec l'onglet actif — positionné dès le montage
  à l'index initial effectif, puis à chaque changement (tap ou swipe), avant
  `onTabChanged`. Flux à sens unique (widget → hôte). Supprime le `_activeIndex`
  dupliqué côté hôte (bouton « + » : `tabs[notifier.value].defaultItemBuilder`).
- `ZListTab.canCreate` : autorisation de création par onglet (défaut `true`),
  transportée comme `defaultItemBuilder` — le geste de création de l'app la lit
  sur l'onglet actif ; `false` = onglet en lecture seule pour la création.
- `ZListGridLayout.maxColumns` : plafond optionnel du nombre de colonnes dérivé
  de `maxCrossAxisExtent` (équivalent du motif legacy
  `(largeur / extent).clamp(1, N)`). Plafonnée, la grille cesse d'ajouter des
  colonnes et les tuiles s'élargissent au-delà de `maxCrossAxisExtent` ;
  `null` (défaut) = comportement responsive antérieur strictement inchangé.

### Corrigé

- **Cocher une case ne reconstruit plus les tuiles de la liste** (AD-2). Sur les
  vues rendues dans le cœur (`builder`, `grid`), l'abonnement à la sélection
  était posé au niveau de la liste : chaque changement reconstruisait **toutes**
  les tuiles visibles — mesuré à 5 reconstructions pour 5 lignes affichées, et
  proportionnel au nombre de lignes à l'écran. Il descend désormais jusqu'à la
  **case** de chaque ligne, le seul sous-arbre qui dépende réellement de
  l'ensemble sélectionné. Le chemin `dataGrid` est inchangé : le backend y
  reçoit la sélection comme donnée de son modèle de rendu.

### Documentation

- La dartdoc du port `ZRepository` dit désormais, chemin par chemin, comment la
  **portée de suppression** se choisit : `watch(request)`/`getAll`/`count`
  honorent `ZDataRequest.deletedScope` (défaut `aliveOnly` — comportement
  historique) ; `watchAll`/`getById` sont figés `aliveOnly` et renvoient vers la
  voie à `request`. L'onglet Corbeille s'écrit
  `watch(request.copyWith(deletedScope: ZDeletedScope.deletedOnly))` — la
  capacité existait depuis la 0.86.0, la doc du port la cachait.

## 0.91.0 — 2026-08-12

### Ajouté

#### `ZcrudRegistry` — résolution depuis les génériques non bornés

- Nouvelles résolutions `kindOfType(Type)` et `kindOfInstance(Object)` pour les
  moteurs génériques non bornés (`toMap<T>(T? item)`) que la borne de
  `kindOf<T>()` excluait — contrat identique (`null` si absent, `StateError`
  actionnable si ambigu) ; `kindOf<T>()` délègue à `kindOfType(T)` (source de
  vérité unique).
- Dartdoc `encode`/`encodeOf` : les clés nulles sont émises ; en écriture
  fusionnée Firestore (`merge: true`), une clé nulle **efface** la valeur
  distante — voir `omitNullFields` de `FirebaseZRepositoryImpl`.

#### `DynamicList` — parité écrans segmentés

- **Onglets** : `ZListTab` (et sa fabrique `.category`) porte un **contexte de
  création par onglet** optionnel — `Object? Function()? defaultItemBuilder` —
  pour le motif « liste segmentée par statut, la création hérite du segment
  courant ». Rappel : le filtre par onglet et le chrome à état préservé
  existaient déjà (`ZTabbedList`/`ZListTab.category`).
- **Corbeille sans repository** : fabriques `ZRowAction.softDeleteWith(handler)`
  / `ZRowAction.restoreWith(handler)` — l'écriture est déléguée à l'app
  (migration progressive, listes alimentées par des flux legacy), l'ACL reste
  appliquée exactement comme pour `softDelete(repository)`/`restore(repository)`,
  qui restent le raccourci nominal. L'entité éphémère (`id == null`) est
  transmise au handler.
- **Clé éphémère standard** : `ZListRow.ephemeralKey(index)`
  (`'__ephemeral_<index>'`) et `ZListRow.isEphemeralKey(id)` — la clé
  positionnelle des entités non persistées est fabriquée par le cœur, plus par
  chaque consommateur.
- **Grille neutre** : `ZListGridLayout` — grille de cartes **responsive** rendue
  `GridView.builder` **dans le cœur** (virtualisée, directionnelle RTL, sans
  Syncfusion ni renderer) ; sélection et actions de ligne supportées (pied de
  tuile accessible, ≥ 48 dp).
- **Doc** : `deriveColumns` documente l'escamotage silencieux des champs hors
  liste blanche tabulaire et son contournement (`ZColumnPolicy.forceInclude`).

## 0.90.0 — 2026-08-12

### Ajouté

- `ZcrudRegistry.kindOf<T>()` : le registre **retient** l'association
  `Type → kind` au moment de `register<T>(kind, …)` (elle était jetée avec
  l'effacement de `T`) et l'expose. Contrat : `kind` si l'association est
  univoque ; `null` si le type n'est pas enregistré ; `StateError` actionnable
  (nommant le type et les `kind` en jeu) si le même type est enregistré sous
  plusieurs `kind` — cet usage reste **permis** à l'enregistrement (modèle
  partagé par plusieurs collections), l'ambiguïté est signalée à la lecture.
  Un moteur générique sur `T` n'a plus à maintenir sa propre table
  `Map<Type, String>` (demande du pilote DODLP, 48 entrées manuelles).
- `ZcrudRegistry.encodeOf<T>(value)` / `ZcrudRegistry.decodeOf<T>(map)` :
  variantes typées d'`encode`/`decode` qui résolvent le `kind` depuis `T`
  via cette table. `decodeOf<T>` retourne directement un `T`. Type non
  enregistré ou ambigu → `StateError` explicite, jamais un silence ; le
  contexte de décodage est threadé comme par la voie par-`kind`.
  Aucun changement du générateur : les registrars émis appellent déjà
  `register<T>` typé.

## 0.89.0 — 2026-08-12

### Ajouté

- `ZcrudScope.copyWith(...)` : dérivation sûre d'un scope — tout seam omis
  hérite de la valeur du scope courant (les 21 seams couverts) ; pour un seam
  nullable, un `null` explicite le remet à son repli par défaut (sentinelle,
  même patron que le `copyWith` généré par `zcrud_generator`).
- `ZcrudScope.derive(context, ...)` : dérive le scope **ambiant** en ne
  remplaçant que les seams nommés — la forme recommandée pour une surcharge
  par écran (par exemple une ACL propre à la ressource affichée). Sans scope
  ambiant, la dérivation part du scope zéro-config.
- Garde de non-oubli (`z_scope_copywith_parity_test.dart`) : tout seam déclaré
  sur `ZcrudScope` doit être couvert par `copyWith` **et** `derive` — un
  nouveau seam absent de la dérivation rougit par assertion au lieu d'être
  perdu silencieusement par les scopes dérivés.

### Modifié

- `ZListRow.id` : la dartdoc explicite le contrat face à `ZEntity.id` nullable —
  une entité éphémère (`id == null`) n'a pas de clé de ligne naturelle ; le
  projecteur `T → ZListRow` fabrique une clé stable (clé positionnelle stable
  ou identité locale) jusqu'à la persistance. Aucun changement de code.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu des
  couches domaine/présentation, installation, démarrage rapide, concepts clés,
  API principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_core.md` (rôle, quand l'utiliser, types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc du barrel (`zcrud_core.dart`, `domain.dart`,
  `edition.dart`) et du schéma déclaratif (`lib/src/domain/edition/`) :
  première phrase autonome, invariants d'architecture cités par leur nom
  stable (`docs/site/concepts/invariants.md`). Purge des références de story
  et d'epic, des comparatifs legacy nominatifs et des emoji de journal —
  conservation des invariants, cas limites et avertissements de contrat. Aucun
  changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_core/`.
