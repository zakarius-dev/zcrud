# Handoff **v0.64.0** — le bloquant de migration, la rigueur du requis, et la lecture seule qui verrouille

> **Tag à épingler : `v0.64.0`**
> 🔴 **Trois changements de COMPORTEMENT** (pas d'API) : un formulaire aujourd'hui soumissible peut
> ne plus l'être, et un formulaire en lecture seule perd des boutons. C'est voulu — § 4.
> Aucune signature cassée, aucun paquet nouveau (38).

---

## 0. D'où vient ce lot

Un workflow de **8 lentilles en lecture seule + une synthèse** a lu le constructeur de formulaire
DODLP legacy dans son entier — 37 types de champ, ~11 000 lignes — et l'a confronté au socle.
Verdict d'ouverture, qui mérite d'être dit avant la liste des correctifs :

> **Le socle couvre déjà l'essentiel.** Sur ~118 capacités distinctes : **71 couvertes** (souvent
> mieux que le legacy), 28 partielles, **11 réellement absentes**, 8 refusées.

Et une mesure que personne n'avait demandée a re-priorisé tout le reste : **l'usage réel des types**.
`select` **147 usages**, `timestamp` 54, la trappe `widget` 54, `boolean` 53, `text` 49 — et **zéro**
pour `dateTime`, `image`, `document`, `color`, `signature`, `rating`, `slider`, `password`, `radio`,
`checkbox`, `icon`, `hidden`. Deux lentilles entières avaient produit 35 capacités « haute valeur »
pour 5 usages de `file` et 2 de `geoArea` : la synthèse a rabattu leur priorité d'elle-même.

## 1. 🔴 Le bloquant de migration : vos fichiers étaient invisibles, sans erreur

**Le défaut** : vous stockez des **identifiants** de fichiers (`shipDocumentsIds`). Notre champ ne
retenait que les valeurs **déjà** typées fichier — donc un champ migré affichait **VIDE** sur une
donnée existante, **sans le moindre message**. Et tout le reste du champ fichier (bornes, reprise,
réseau — que le socle fait déjà mieux que votre legacy) était **inatteignable** tant que ce trou
existait.

Livré : le **port** `ZAppFileResolver`, injecté par `ZcrudScope`. Références = `String` opaques,
appariement par identifiant, contrat écrit et gardé. **Aucune implémentation dans le cœur** (AD-1) —
l'adaptateur Firestore suit.

🔴 **Le silence était le vrai défaut, et il ne revient pas sous une autre forme.** Une référence non
résolue devient une tuile **visible** — `en cours`, `introuvable`, `échec` — annoncée en région
vivante, avec réessai. Nous n'avons pas remplacé un vide muet par un autre.
`on Object` est **délibéré** : un `on Error` laisserait remonter l'`Exception`, c'est-à-dire l'échec
**normal** d'une entrée-sortie. Délai de garde pour la requête qui ne répond jamais.

🔵 **Deux corrections nécessaires trouvées en chemin** : les références sont **préservées à
l'écriture** (sans quoi ajouter un fichier **effaçait** les identifiants persistés), et le type de la
tranche reste inchangé tant qu'aucune référence ne subsiste.

**SM-1 prouvé, pas promis** : à l'arrivée de la réponse, l'`Element` du voisin **et** celui de
`DynamicEdition` sont **identiques**, la voie structurelle n'est pas rejouée, les compteurs de build
ne bougent pas — y compris celui du champ fichier — et la tranche ne notifie **zéro** fois.
**Sans port injecté, rien ne bouge** (deux gardes le prouvent).

## 2. 🔴 Le requis mord enfin sur une collection vide

**Le défaut** : `_stringOf([])` rendait la chaîne `"[]"`, qui n'est pas vide — donc `required`
**acceptait** une multi-sélection vide. Un champ obligatoire non rempli passait la validation.

Corrigé **sans échappatoire** : une échappatoire serait garder le bug. Et surtout, corrigé à la
**source unique** — les deux copies existantes de la règle y délèguent désormais, au lieu de dériver
chacune de son côté. `false`, `0`, `0.0`, `'0'` restent des valeurs **présentes** (gardés un par un).
**10 types** couverts et gardés nommément.

## 3. 🔴 La lecture seule verrouille — et la cause était plus profonde que vos deux symptômes

Vos deux constats sont corrigés : les actions d'**écriture** disparaissent (nouvelle classification —
`view` et `history` restent, ce sont des lectures), et la barre d'acquisition du champ fichier n'est
plus **émise** au lieu d'être seulement grisée.

🔴 **Mais le balayage a trouvé la cause structurelle** : `_effective` ne descendait **pas** dans les
sous-champs. Les enfants d'un `subItems` en ligne et d'un `dynamicItem` étaient **pleinement
éditables** dans un formulaire déclaré en lecture seule. Ce n'était pas un bouton de trop : c'était
une saisie ouverte. Corrigé.

### Signalé, non corrigé — parce que ce sont des décisions, pas des oublis
* un `TextFormField(readOnly: true)` reste **focalisable** : arbitrage accessibilité contre
  copier-coller, à trancher ;
* `ZFreeWidgetFieldWidget` n'honore pas `readOnly` — par nature, c'est votre widget ;
* 🔵 **~18 familles rendent leur libellé par un `Text` brut** et **n'affichent donc jamais
  l'astérisque, même en ÉDITION**. C'est un défaut d'édition découvert en cherchant un défaut de
  lecture. Cadré, non fait.

## 4. 🔴 Votre ligne — lisez-la avant de bumper

| Vous êtes… | Geste |
|---|---|
| 🔴 **tous** | **un champ obligatoire vide bloque désormais la soumission.** Des formulaires qui passaient ne passeront plus — c'est le correctif, pas une régression |
| 🔴 **tous** | **un formulaire en lecture seule perd ses actions d'écriture**, et ses **sous-champs** deviennent réellement figés |
| **hôte qui compensait** | si vous passiez `formActions: []` pour masquer des actions en lecture, **retirez la compensation** — sinon vous retirez deux fois |
| **DODLP** | injectez `ZcrudScope.appFileResolver` et vos champs fichier **cessent d'être vides**. Sans lui, comportement d'aujourd'hui strictement conservé |
| **hôte du champ fichier** | la tranche peut contenir une référence non résolue **uniquement** si un résolveur est injecté et qu'une référence échoue |

🟢 **Tripwire recommandé** : un test qui affirme qu'un de vos formulaires en lecture seule montre
aujourd'hui un bouton d'écriture — il rougira à l'adoption et vous désignera ce qui disparaît.

## 5. Le reste du lot — le champ de sélection, classe fermée

Trois régressions de la **même famille** avaient été trouvées sur ce seam en 24 h : le `crudHandler`,
puis l'astérisque requis, puis quatre écarts mesurés. Motif constant : **le DTO porte la donnée, le
présentateur ne la lit pas** — donc enrôler `ZSmartSelectPresenter` **retirait** une capacité que le
rendu natif offrait.

**Inventaire exhaustif livré** : les **8 voies de rendu natives** confrontées à la voie enrôlée,
**26 capacités**. Six corrigées — dont `crudHandler.edit`/`.copy`, que l'inventaire a trouvé
lui-même. **Il en reste deux, et aucun n'appartient à cette famille : la classe est fermée**, et
c'est prouvé, pas ressenti.

🔵 **Un refus argumenté** : la suppression d'une puce en ligne n'a pas d'équivalent sensé dans la
forme tuile — la tuile n'a **qu'une seule** annonce d'accessibilité, donc un bouton à l'intérieur
serait cliquable et **invisible au lecteur d'écran**. Décision de conception, pas omission.

🔴 **Défaut découvert en chemin, plus large que le lot** : les libellés de `ZcrudScope.labels`
**n'atteignent pas le modal** (la route se monte au-dessus du scope) — mesuré à zéro. Les nouvelles
infobulles capturent donc leurs textes en amont, mais **les infobulles préexistantes** (créer,
confirmer, réinitialiser, rechercher) **ne sont pas localisées aujourd'hui**. Signalé, non touché.

## 6. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.

`zcrud_core` **1459** (+47) · `zcrud_select` **135** (+33) · `zcrud_study` 1521 · `zcrud_flashcard`
586 · `zcrud_markdown` 504 · `zcrud_intl` 183 · `zcrud_geo` 174 · `zcrud_media` 31 ·
`zcrud_field_extras` 26 · `example` 97. **0 erreur, 0 avertissement.**

### 🔴 Une garde JUMELLE a mordu, et c'est la bonne nouvelle du lot
Ajouter un paramètre à `ZcrudScope` a fait **rougir `zcrud_study`** : sa garde de structure affirme
que **chaque** paramètre du scope est re-posé dans sa feuille — et elle lit la liste **réelle dans la
source de `zcrud_core`**, jamais une copie qui dériverait. Elle a nommé le manquant. Sans elle, un
champ fichier monté dans cette feuille aurait affiché ses valeurs persistées comme **vides** —
exactement le défaut que ce lot ferme. Corrigé sur les **deux** sites de re-pose.

**R3 — 35 injections sur les deux lots**, sha **avant et après** chacune, restauration par copie,
résidus : greps négatifs montrés.

🟢 **Trois gardes trouvées inertes par les campagnes elles-mêmes**, et réparées :
* une **vacante** — l'astérisque mesuré en lecture globale restait vert **parce que le composant
  mesuré n'y est pas monté** ;
* une **vacante** — elle ouvrait un modal en tapant sur une tuile inerte, donc son `findsNothing`
  passait **pour la mauvaise raison** ;
* une posée sur **une seule** des deux branches d'un couple mono/multi.

🟢 Et **quatre rouges qualifiés puis corrigés** parce qu'ils n'étaient pas des assertions : deux
délais d'animation, un rouge de **compilation**, et un `StateError`. Un rouge d'infrastructure n'est
pas une preuve de morsure.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 7. Non couvert

* L'**implémentation Firestore** du résolveur de fichiers — le port existe, l'adaptateur suit.
* Les ~18 familles dont le libellé est un `Text` brut, donc **sans astérisque même en édition**.
* La focalisation d'un champ en lecture seule (arbitrage a11y ↔ copie) et `ZFreeWidgetFieldWidget`.
* Les libellés non localisés dans le modal du sélecteur (§ 5).
* Ce que la synthèse a mesuré et **écarté faute d'usage réel** : médias, géo, échelles — 0 à 2 usages
  en production. Nous ne les traiterons pas sans demande explicite.
* Dettes antérieures : cf. v0.63.0, v0.62.0, v0.61.0, v0.60.0.
