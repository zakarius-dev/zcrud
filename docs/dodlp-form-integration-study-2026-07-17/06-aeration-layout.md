# Étude d'intégration DODLP → zcrud — Lentille AÉRATION / ESPACEMENT / LAYOUT

Date : 2026-07-17. Périmètre : rythme visuel du formulaire d'édition DODLP
(`lib/modules/data_crud/`) confronté à ce que `zcrud_core`/`zcrud_responsive`
fournissent déjà. **Étude read-only** — aucune écriture hors ce fichier.

---

## 1. Résumé exécutif

**Constat majeur (change la nature du travail d'intégration pour cette lentille)** :
zcrud n'a **pas besoin** de "porter" un package DODLP pour l'aération/layout —
`packages/zcrud_core/lib/src/presentation/edition/z_responsive_grid.dart`,
`dynamic_edition.dart` (fonction `zFieldGapAfter`, `_SectionHeader`,
`_CollapsibleSectionHeader`) et `z_stepper_config.dart` sont déjà une
**réimplémentation pure-Flutter, theme-driven, quasi-1:1** de
`responsive_form_row.dart` + `dynamic_stepper.dart` + `MyStickyHeader` DODLP,
livrée par les stories E3-4/E3-5/DP-9 (commentaires de code citant
explicitement "parité DODLP" avec les chemins `dodlp-otr/...`). Confirmé par
grep négatif :

```
$ grep -rn "ResponsiveFormRow\|ResponsiveFormCol\|MyStickyHeader\|dynamic_stepper" packages/ | grep -v "\.g\.dart"
(aucune sortie, RC=1)
```

⇒ **aucun fichier DODLP n'est importé/enveloppé** dans zcrud pour cette
lentille. Le travail restant n'est donc pas "où brancher un
`ZFieldWidgetBuilder` adaptateur DODLP" (le seam `ZWidgetRegistry` ne
s'applique pas ici — il n'y a pas de widget DODLP à enregistrer), mais :
(a) **combler les 3 écarts numériques** identifiés en §4 pour une parité pixel
stricte si le produit l'exige, et (b) **documenter/exposer** les tokens déjà
présents pour que le binding `zcrud_get` (DODLP) les configure au bon endroit
plutôt que de recréer des constantes en dur côté app.

---

## 2. Inventaire DODLP (source, lecture seule)

### 2.1 `responsive_form_row.dart` (214 l.) — grille 12 colonnes

- `responsive_form_row.dart:24-47` — `ResponsiveFormRow` : liste de
  `ResponsiveFormCol`, **`horizontalSpacing = 16.0`** (défaut),
  **`verticalSpacing = 8.0`** (défaut) — deux valeurs **distinctes**.
- `responsive_form_row.dart:61-96` — algorithme de wrap : accumule les `colSpan`
  jusqu'à dépasser `ResponsiveColumns.maxColumns = 12` (`utils/responsive_utils.dart:152`),
  démarre une nouvelle rangée.
- `responsive_form_row.dart:106-109` — espacement **vertical** entre rangées :
  `Padding(top: rowIndex > 0 ? verticalSpacing : 0)` (jamais avant la 1ʳᵉ rangée).
- `responsive_form_row.dart:114-131` — espacement **horizontal** entre colonnes
  d'une même rangée : `Padding(right: isLast ? 0 : horizontalSpacing)` — implémenté
  en `EdgeInsets.only(right:)` **non-directionnel** (viole AD-13 si porté tel quel).
- `utils/responsive_utils.dart:24-46` — seuils Bootstrap :
  `xs=0, sm=576, md=768, lg=992, xl=1200`.
- `utils/responsive_utils.dart:76-134` — `BreakpointValue<T>` : cascade
  **mobile-first** (`xl ?? lg ?? md ?? sm ?? xs`).
- Usage réel dans `edition_screen.dart:531-535` :
  `ResponsiveFormRow(children: responsiveCols, verticalSpacing: 8.0, horizontalSpacing: 16.0)`
  — les défauts de la classe sont repris explicitement (pas de override produit).

### 2.2 Espacement inter-champ (hors grille) — `edition_screen.dart`

- `edition_screen.dart:401-536` — `_buildFormField` : construit soit la grille
  responsive (si des enfants portent `xs/sm/md/lg/xl`), soit un `Column` simple
  (chemin de compat).
- `edition_screen.dart:519-521` — dans la grille : `if (e.withSpaceer == true && !readOnly) SizedBox(height: 12.0)` **après** le champ, à l'intérieur de la cellule (donc en plus du `verticalSpacing: 8.0` de la rangée suivante).
- `edition_screen.dart:550-552` — même règle dans le chemin `Column` de compat.
- `models.dart:722-732` — `withSpaceer` (getter) : vrai seulement pour
  `{text, float, number, timestamp, time, dateTime, phoneNumber}` **et**
  `name != null` — **les champs "blocs"** (multiline, subItems, file, image…)
  n'ont **pas** ce spacer (ils gèrent leur propre aération interne, cf. §2.4).
- `edition_screen.dart:4172-4174` / `4179-4182` — **padding d'écran** :
  `widget.padding ?? const EdgeInsets.all(12)` (hors dialog) — appliqué au
  `SingleChildScrollView`/`DynamicStepper` racine.
- `edition_screen.dart:4184-4188` — **largeur max en dialog** : `700` sur
  web/desktop (`AppPlatform.isWebOrDesktop`), sinon infinie.
- `edition_screen.dart:4194` — un `SizedBox(height: 8)` fixe en tête de colonne
  avant le premier champ (chemin `Column` non-grille).

### 2.3 En-tête de section — `forms_utils.dart:43-110` (`MyStickyHeader`)

- Hauteur **fixe** `50.0` dp, `padding: EdgeInsets.symmetric(horizontal: 10.0)`
  (`forms_utils.dart:70-72`) — **non-directionnel**.
- Fond **hardcodé** : `Colors.grey[800]` (dark) / `Colors.grey[240]` (light,
  valeur invalide >255 en pratique clampée) — **viole FR-26** (aucune dérivation
  `ColorScheme`).
- Bordure basse `2.0` `Colors.grey` hardcodée (`forms_utils.dart:76-82`).
- Style titre : `titleLarge` avec fallback `fontSize: 18`, couleur `Colors.grey`
  hardcodée si le thème ne fournit rien.
- Corps : `ExpandablePanel` (package tiers `expandable`) avec
  `padding: EdgeInsets.only(top: 8.0)` sur le contenu déplié
  (`forms_utils.dart:106`) — **non-directionnel** (`top` seul est neutre en RTL
  ceci dit, donc pas un vrai problème AD-13 ici).
- État d'expansion persisté via GetX (`Get.put(..., tag: title)`) + `_box.write`
  (Hive) — **couplage GetX explicite dans le layout de section**, pas seulement
  du style.

### 2.4 Champs "large" / Card — `edition_screen.dart` (motif répété ×4, ex.
`l.455-497`, `l.4013-4055`, `l.4128-4169`) et `app_file_edition_field.dart`

- Card `elevation: 0`, `color: isDark ? Colors.white.withValues(alpha:0.05) : Colors.grey.shade50`
  (hardcodé), `borderRadius: 12`, `side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)`
  (hardcodé), `margin: EdgeInsets.only(bottom: 12)` (non-directionnel),
  `Padding(all: 16.0)` interne, `SizedBox(height: 8)` entre label et valeur.
- `app_file_edition_field.dart:397-398` — constantes locales
  `spacing = 12.0`, `padding = 32.0` pour la zone de drop de fichier ;
  `:321` padding `symmetric(vertical: 24, horizontal: 16)` ; `:531` `all(24.0)`.
- `constants.dart:23-64` — décoration de champ **globale** :
  `contentPadding: EdgeInsets.all(15)`, `borderRadius: 10`, couleurs
  hardcodées (`Colors.black12/black87/white70`, `kSuccessColor*`,
  `kErrorColor*` en `Color.fromARGB` littéraux) — **violation FR-26** de
  référence (c'est la source du "look" DODLP mais totalement non thémée).

### 2.5 `dynamic_stepper.dart` (868 l.) — formulaires par étapes

- `StepperConfig` (`models/stepper_config.dart:67-119`) : `indicatorSize = 40`
  (déclaré) mais le rendu réel recalcule
  `24.0 - (nestingLevel * 2).clamp(0, 8)` (`dynamic_stepper.dart:300,596,691`)
  — **le champ de config `indicatorSize` n'est pas branché sur le rendu**
  (dead config / bug de parité potentiel côté DODLP lui-même, à ne PAS
  reproduire tel quel).
- `stepSpacing = 8` (déclaré dans `StepperConfig`) — utilisé comme
  `margin: EdgeInsets.only(bottom: indicatorSize)` **entre étapes verticales**
  (`:489, :679`) — nom trompeur : c'est `indicatorSize` qui pilote l'espacement
  vertical réel, pas `stepSpacing` (autre incohérence source).
- Paddings d'étape : `symmetric(vertical: 8.0)` par item de step
  (`:393, :599, :771`), `only(top: 8.0, bottom: 24.0)` sous le contenu de step
  actif (`:416, :800`), `symmetric(vertical: 16.0)` autour de la bande
  d'indicateurs horizontale (`:441`), `SizedBox(height: 16)` avant les boutons
  Suivant/Précédent (`:541, :834`).
- `padding: widget.padding ?? EdgeInsets.all(nestingLevel == 0 ? 12 : 0)`
  (`:308-309, :561-562`) — le stepper racine reprend le même `12` que le
  padding d'écran ; un stepper imbriqué (nested) n'a **pas** de padding propre
  (0) pour ne pas cumuler.

---

## 3. Ce que zcrud fournit déjà (grep + lecture de code)

```
$ grep -rn "spacing\|Spacing\|gap\|ThemeExtension" packages/zcrud_core/lib packages/zcrud_responsive/lib | wc -l
83   (extrait pertinent ci-dessous ; commande complète exécutée, résultat non tronqué pour les lignes citées)
```

| Concept DODLP | Équivalent zcrud (fichier:ligne) | Écart |
|---|---|---|
| `ResponsiveFormRow`/`ResponsiveFormCol`, breakpoints Bootstrap | `z_responsive_grid.dart:44-86` (`ZBreakpoint`, `ZResponsiveBreakpoints` — **seuils identiques** 576/768/992/1200), `ZResponsiveSpan` (cascade mobile-first identique) | Seuils et cascade **bit-à-bit identiques** à DODLP |
| `horizontalSpacing`/`verticalSpacing` distincts | `ZResponsiveGrid.gutter` (`z_responsive_grid.dart:187,242-244`) — **un seul** `gutter` posé en `spacing`/`runSpacing` du `Wrap` | **Écart réel** : zcrud n'a pas de gouttière horizontale/verticale distincte (cf. §4.1) |
| Wrap avec `Padding(right:)` non-directionnel | `Wrap` natif Flutter (suit `Directionality`) + clé de place stable portée sur la cellule (`z_responsive_grid.dart:223-239`) | zcrud **corrige** le défaut AD-13 de DODLP (mieux, pas un gap) |
| `withSpaceer` (12dp après champs "texte") | `zFieldGapAfter()` (`dynamic_edition.dart:64-80`) — **liste de types inversée** : DODLP espace les champs *compacts* (text/number/date…), zcrud espace les champs *blocs* (multiline/subItems/file/signature/markdown) | **Écart sémantique** à documenter, cf. §4.2 |
| Padding d'écran `EdgeInsets.all(12)` par défaut | `DynamicEdition.padding` — **nullable, sans défaut** (`dynamic_edition.dart:177,654,736`) | **Écart** : le binding DODLP doit passer `EdgeInsets.all(12)` explicitement, cf. §4.3 |
| `MyStickyHeader` (boîte grise 50dp + bordure) | `_SectionHeader`/`_CollapsibleSectionHeader` (`dynamic_edition.dart:850-918`) — `Text(titleSmall)` + padding `16/16/16/8`, variante repliable `Semantics(button,expanded)` + `minHeight:48` | **Écart visuel volontaire** (FR-26 : zcrud refuse le gris hardcodé de DODLP) ; pas de hook pour un header custom, cf. §4.4 |
| `StepperConfig` (`indicatorSize`, `stepSpacing`) | `ZStepperConfig` (`z_stepper_config.dart:70-129`) — mêmes défauts `indicatorSize=40, stepSpacing=8`, **+ orientation `start` directionnelle** (AD-13, `left`→`start`) | Zcrud **répare** le bug DODLP (indicatorSize non branché) — à vérifier dans `z_stepper_edition.dart` si le même écueil existe |
| `FieldSize.large` (Card + label au-dessus) | `ZFieldSize.large` (`z_field_size.dart:1-23`, "Miroir 1:1... gap B1") + tokens `largeMinHeight=64, largePadding=16/12, largeLeadingGap=12, largeLabelGap=4` (`z_theme.dart:54-65`) | Parité **déclarée et documentée** dans le code source lui-même |
| `contentPadding: EdgeInsets.all(15)`, radius 10 (constants.dart) | `ZcrudTheme.inputContentPadding` (défaut `16/16`), `inputRadius` (défaut `12`) (`z_theme.dart:41-47`) | **Écart mineur de valeur** (15→16 padding, 10→12 radius) — cf. §4.5, non bloquant |
| Card lecture (`Colors.grey.shade50`, `margin: bottom:12`) | `ZcrudTheme.readCardMargin` (défaut `only(bottom:12)` — **identique**), `readPadding` (`all(16)` — identique), `readLabelGap=8` (identique) (`z_theme.dart:66-70,176-184`) | **Parité exacte** des mesures, couleurs dérivées du `ColorScheme` (conforme FR-26) au lieu de `Colors.grey.shade50` hardcodé |
| Espacement bloc de tags/chips (`Wrap spacing/runSpacing`) | `z_row_chips_field_widget.dart:101-102` (`spacing:8, runSpacing:4`), `z_tags_field_widget.dart:117-118` (idem), `z_select_field_widget.dart:317-318`, `z_relation_field_widget.dart:252-253`, `z_color_field_widget.dart:174-175,455-456` (`spacing:4,runSpacing:4`) | Cohérent en interne ; pas de comparaison DODLP directe faite ici (hors périmètre exact de la lentille — signalé pour information) |

`zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart:26-221` fournit en
outre une **grille adaptative alternative** (nombre de colonnes déduit de
`minItemWidth`, un seul `spacing`/`runSpacing?`) pour les usages hors formulaire
(listes de cartes) — non utilisée par `DynamicEdition` mais disponible pour
d'autres écrans (ex. galeries de fichiers).

---

## 4. Écarts identifiés (à trancher, du plus au moins impactant visuellement)

### 4.1 Gouttière grille : DODLP asymétrique (16 horiz / 8 vert) vs zcrud symétrique (`gutter` unique, défaut 8)
`ZResponsiveGrid` n'expose qu'un seul `gutter` posé à la fois en `spacing`
(horizontal du `Wrap`) et `runSpacing` (vertical). Pour une parité pixel
stricte avec `edition_screen.dart:533-534`
(`horizontalSpacing:16, verticalSpacing:8`), il faudrait soit (a) passer
`gutter: 16` en acceptant un espacement vertical 2× plus large que DODLP,
soit (b) étendre `ZResponsiveGrid` avec un `runGutter` distinct (changement
d'API non-cassant : nouveau paramètre optionnel `double? runGutter`, replié
sur `gutter` si absent — cohérent avec le style additif déjà pratiqué sur
`ZResponsiveGrid`/`ZcrudTheme`). **Recommandation** : ouvrir ce point côté
`zcrud_core` (hors périmètre de cette étude, qui est read-only) plutôt que
côté binding — c'est un token de layout, pas un souci GetX/Riverpod.

### 4.2 `withSpaceer` : listes de types inversées entre DODLP et `zFieldGapAfter`
DODLP espace après les champs **compacts** (`text, float, number, timestamp,
time, dateTime, phoneNumber`) et rien après les blocs. `zFieldGapAfter`
espace après les champs **blocs** (`multiline, subItems, dynamicItem,
signature, file, image, document, markdown`) et rien après les compacts.
Le commentaire de code (`dynamic_edition.dart:56-63`) présente ceci comme une
"projection" volontaire de la règle DODLP, pas un bug — mais le résultat
visuel n'est **pas pixel-identique** : dans une grille DODLP mixte (compacts +
blocs), un champ compact suivi d'un bloc a un espace *avant* le bloc côté
DODLP (porté par le compact) et *après* le bloc côté zcrud (porté par le
bloc) — l'ordre des espacements dans la séquence diffère selon l'alternance
des types. À vérifier au cas par cas si un formulaire DODLP réel alterne
souvent compact→bloc→compact (le rendu final peut légèrement diverger en
cumul). Par défaut `interFieldGap = 0` (aucun espace, rétro-compat stricte E3-1)
— le binding DODLP devra explicitement passer `interFieldGap: 12` **et**
vérifier visuellement sur 2-3 formulaires réels représentatifs plutôt que de
supposer la parité automatique.

### 4.3 Pas de padding d'écran par défaut
DODLP applique `EdgeInsets.all(12)` par défaut au conteneur de formulaire
(`edition_screen.dart:4174,4182`) ; `DynamicEdition.padding` est `null` par
défaut (aucun padding visuel si l'hôte n'en fournit pas). Ce n'est **pas** un
bug zcrud — c'est cohérent avec FR-26 (pas de valeur imposée non thémée) —
mais c'est un point de configuration que le binding `zcrud_get`/l'app DODLP
**doit** fixer explicitement pour ne pas perdre l'aération d'écran DODLP.
Aucun token `ZcrudTheme` dédié à un "padding d'écran de formulaire" n'existe
actuellement (seuls `fieldPadding`, `readPadding`, `largePadding` existent,
tous à l'échelle du champ/de la carte, pas de l'écran) :
```
$ grep -n "screenPadding\|formPadding\|pagePadding" packages/zcrud_core/lib packages/zcrud_responsive/lib
(aucune sortie, RC=1)
```
**Question ouverte** : faut-il un token `ZcrudTheme.formPadding` (défaut
`EdgeInsetsDirectional.all(12)`, parité DODLP) consommé par défaut dans
`DynamicEdition` quand `widget.padding == null` ? Aujourd'hui l'app doit le
recopier en dur dans son binding — acceptable pour DODLP seul, mais recrée
exactement le pattern "constante éparpillée" que zcrud cherche à éliminer.

### 4.4 En-tête de section : pas de hook de style/rendu custom
`_SectionHeader`/`_CollapsibleSectionHeader` sont des classes **privées**
(préfixe `_`) internes à `dynamic_edition.dart` — aucun paramètre
`sectionHeaderBuilder` sur `DynamicEdition` :
```
$ grep -n "sectionHeaderBuilder\|headerBuilder\|sectionBuilder" packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart
(aucune sortie)
```
Le rendu de zcrud (texte `titleSmall` sobre, sans boîte grise ni bordure) est
**délibérément plus neutre** que le `MyStickyHeader` DODLP (boîte 50dp,
fond gris, bordure basse 2px). C'est un choix FR-26 défendable (DODLP hardcode
`Colors.grey[800]/[240]`, ce que zcrud refuse par construction) mais c'est un
**écart visuel notable pour un utilisateur DODLP habitué** à la séparation
"boîte grise" entre sections. Si le produit exige la parité visuelle stricte
des sections (pas seulement fonctionnelle), il faudra soit (a) enrichir
`ZcrudTheme` de tokens de section (hauteur, couleur de fond dérivée,
épaisseur de bordure) consommés par `_SectionHeader`, soit (b) exposer un
`sectionHeaderBuilder` — les deux sont des changements `zcrud_core`
(hors écriture pour cette étude), pas un sujet de binding satellite.

### 4.5 Valeurs de détail non-identiques (mineur)
`contentPadding` DODLP `all(15)` vs `ZcrudTheme.inputContentPadding` défaut
`16/16` ; `borderRadius` DODLP `10` vs `ZcrudTheme.inputRadius` défaut `12`.
Différence de 1-2dp, probablement imperceptible, mais si une parité pixel
stricte est requise pour un audit visuel côte-à-côte, ces deux tokens sont
déjà **surchargeables** (`ZcrudTheme(inputContentPadding: EdgeInsetsDirectional.all(15), inputRadius: Radius.circular(10))`)
sans toucher au cœur — c'est le chemin normal FR-26, pas un gap structurel.

---

## 5. Mapping `EditionFieldType` / aération (résumé)

Cette lentille ne crée pas de nouveau mapping de type de champ (elle porte sur
le *conteneur*, pas les widgets de champ individuels) — le mapping pertinent
est le **layout wrapper** :

| Concept DODLP | Paramètre zcrud | Type |
|---|---|---|
| `field.xs/sm/md/lg/xl` | `DynamicEdition.layout: Map<String, ZResponsiveSpan>` | authoring présentation (pas de schéma domaine — conforme AD-1/AD-3) |
| `ResponsiveFormRow(horizontalSpacing, verticalSpacing)` | `DynamicEdition.gridGutter` (via `ZResponsiveGrid.gutter`) | présentation |
| `withSpaceer` | `DynamicEdition.interFieldGap` + `zFieldGapAfter()` | présentation |
| `StepperConfig` | `ZStepperConfig` (passé à `ZStepperEdition`, DP-9) | présentation |
| `FieldSize.large` | `ZFieldSize.large` (`ZFieldSpec.size` probable — non vérifié dans cette lentille, cf. `z_field_size.dart`) | domaine pur (enum `const`) |

---

## 6. Proposition d'intégration (placement, conformité AD-1/AD-2/AD-13/FR-26)

1. **Aucun wrapper `ZWidgetRegistry` requis pour l'aération** — ce n'est pas
   un type de champ mais un paramétrage de `DynamicEdition` lui-même. Le
   binding `zcrud_get` (DODLP) doit se contenter de :
   - construire `layout: {...}` depuis les anciennes valeurs `xs/sm/md/lg/xl`
     de chaque `DynamicFormField` DODLP (mapping direct, mêmes seuils) ;
   - passer `interFieldGap: 12` et `padding: const EdgeInsets.all(12)`
     explicitement à `DynamicEdition` (ou attendre l'ajout d'un token
     `formPadding` en cœur, cf. §4.3) ;
   - construire un `ZStepperConfig` par défaut (`ZStepperConfig.defaultHorizontal`)
     pour les formulaires DODLP à steppers.
   - **AD-1/isolation** : ce mapping vit dans le package de binding
     `zcrud_get` (ou une couche app), jamais dans `zcrud_core` — c'est un
     câblage de **valeurs**, pas de nouveau widget, donc pas de dépendance
     lourde à isoler.
2. **Si parité pixel stricte requise** : les 3 tokens/hooks manquants
   (`runGutter` sur `ZResponsiveGrid`, `ZcrudTheme.formPadding`,
   `sectionHeaderBuilder`/tokens de section) sont des **extensions additives**
   de `zcrud_core` — hors périmètre d'écriture de cette étude, à faire
   trancher par le owner puis implémenter en story dédiée (pas par ce
   binding).
3. **A11y/RTL** : zcrud est déjà **strictement meilleur** que DODLP ici — la
   grille est directionnelle (`Wrap` suit `Directionality`) là où DODLP utilise
   `Padding(right:)` non-directionnel, et l'en-tête repliable a `Semantics`
   explicite + cible ≥ 48dp, ce que `MyStickyHeader`/`ExpandablePanel` DODLP
   n'expose pas explicitement (pas de `Semantics(button:)` trouvé dans
   `forms_utils.dart:43-110`) :
   ```
   $ grep -n "Semantics" lib/modules/data_crud/forms_utils.dart
   (aucune sortie côté MyStickyHeader — grep exécuté, RC=1 sur ce fichier)
   ```
   ⇒ ne **pas** régresser ces deux points en cherchant une parité pixel
   aveugle avec DODLP.
4. **Thème (FR-26)** : ne **jamais** recopier les couleurs hardcodées DODLP
   (`Colors.grey[800]/[240]`, `Colors.black12`, `kSuccessColorDark` etc.) dans
   le binding — utiliser `ZcrudTheme.of(context)` / `Theme.of(context)`
   uniquement. Les *mesures* (12/16/8dp) peuvent être répliquées comme
   valeurs de tokens ; les *couleurs* jamais.

---

## 7. Risques

- **Risque produit** : les utilisateurs DODLP habitués à la boîte grise de
  section (`MyStickyHeader`) pourraient percevoir le nouveau look zcrud
  (texte sobre) comme "moins fini" — décision produit à trancher explicitement
  (§4.4), pas un défaut technique.
- **Risque de dérive silencieuse** : sans token `formPadding` central, chaque
  écran DODLP migré doit se souvenir de passer `padding: EdgeInsets.all(12)`
  à la main — oubli probable sur un écran isolé (dialog vs page pleine, cf.
  §2.2 le cas `dialog` qui n'a **pas** de repli `all(12)` côté DODLP non plus,
  seul le mode non-dialog en a un — donc DODLP lui-même a cette même
  fragilité, ce n'est pas une régression zcrud).
- **Risque de double-espacement en grille** : `withSpaceer`/`interFieldGap`
  s'ajoute **par-dessus** `gridGutter`/`ZResponsiveGrid.gutter` (comme dans
  DODLP où le `SizedBox(12)` de cellule s'ajoute au `verticalSpacing:8` de la
  rangée suivante, cf. §2.2) — comportement voulu et déjà présent côté DODLP,
  mais à vérifier visuellement une fois les deux valeurs branchées ensemble
  côté binding (12 + 8 = 20dp cumulés entre certains champs empilés).

## 8. Questions ouvertes (pour le owner, pas tranchées ici)

1. Faut-il un `ZResponsiveGrid.runGutter` (gouttière verticale distincte) pour
   parité stricte avec `horizontalSpacing:16/verticalSpacing:8` DODLP, ou
   `gutter` symétrique unique est-il acceptable en v1 (écart 8dp)  ?
2. Faut-il un token `ZcrudTheme.formPadding` par défaut `all(12)` consommé
   automatiquement par `DynamicEdition` quand `padding == null`, pour éviter
   que chaque binding le recopie en dur ?
3. Le look "boîte grise" de section DODLP doit-il être reproduit (nouveaux
   tokens `ZcrudTheme` de section) ou le nouveau look sobre zcrud est-il
   acté comme évolution produit assumée ?
4. `interFieldGap`/`zFieldGapAfter` — la liste de types "blocs" actuelle
   suffit-elle, ou faut-il aligner strictement sur la liste DODLP "champs
   compacts" pour un cumul d'espacement identique en séquence mixte (§4.2) ?

---

## Annexe — commandes de vérification exécutées (traçabilité)

```
grep -rn "SizedBox(\|EdgeInsets\|padding:\|spacing:\|gap:\|const.*= [0-9]" lib/modules/data_crud/   # DODLP, RC=0, ~150 lignes
grep -n "ResponsiveFormRow\|ResponsiveFormCol\|\.responsive(" lib/modules/data_crud/presentation/views/edition_screen.dart   # RC=0
grep -rln "ResponsiveFormRow\|ResponsiveFormCol\|\.responsive(" lib/modules/data_crud/   # 3 fichiers
grep -n "enum FieldSize" -A 15 lib/modules/data_crud/*.dart   # models.dart:88
grep -rn "spacing\|Spacing\|gap\|ThemeExtension" packages/zcrud_core/lib packages/zcrud_responsive/lib   # zcrud, RC=0
grep -rn "ResponsiveFormRow|ResponsiveFormCol|MyStickyHeader|dynamic_stepper" packages/   # RC=1, aucune sortie
grep -n "screenPadding|formPadding|pagePadding" packages/zcrud_core/lib packages/zcrud_responsive/lib   # RC=1
grep -n "sectionHeaderBuilder|headerBuilder|sectionBuilder" packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart   # RC=1
grep -n "Semantics" lib/modules/data_crud/forms_utils.dart   # pas de match dans MyStickyHeader
```
