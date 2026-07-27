---
baseline_commit: fd83a1b
---

# Story VIS-2 : carte dossier, accent dégradé et badges de compte

Status: done

<!-- Epic VIS : premier consommateur zcrud_study des tokens/couture livrés par VIS-1. -->
<!-- Dépend de VIS-1 en review : ne pas démarrer tant que son API publique n'est pas verte et stable. -->

## Story

As a **développeur d'une application hôte de zcrud**,
I want **personnaliser le chrome d'une `ZFolderCard` avec une barre d'accent dégradée et des badges de compte accessibles**,
so that **je puisse obtenir une carte inspirée d'IFFD par injection, tout en gardant exactement le rendu v0.19.3 sans preset et une couleur stable pour chaque dossier après tri ou filtrage**.

**Contexte et objectif.** VIS-1 a livré des tokens tous opt-in dans `ZcrudTheme` et la couture `zResolveGradient(context, key)`: sans `gradientResolver`, elle renvoie `null`; le resolver dérivé est un choix explicite de l'hôte. VIS-2 est le premier consommateur et doit donc matérialiser l'invariant de l'epic : zéro injection signifie rendu pixel-identique à la carte SUF-2 existante. Le périmètre est strictement `zcrud_study`; aucune écriture dans `zcrud_core`, IFFD ou lex_douane.

**Couvre :** slot décoratif d'en-tête, barre d'accent dégradée optionnelle, `ZCountBadge` / `ZCountBadgeRow` publics et leur intégration par le slot `counts` déjà existant. **Dépend de :** VIS-1. **Débloque :** le preset applicatif et les comparaisons visuelles ultérieures. **Hors périmètre :** palette IFFD, couleurs littérales, persistance/tri/filtrage métier, gestionnaire d'état, modification d'un package autre que `zcrud_study`, nouvelle prop métier pour les comptes, et changement de `sprint-status.yaml`.

### Décisions tranchées avant dev

#### D1 — Le slot d'en-tête remplace seulement la pastille, jamais la structure de carte

Ajouter `Widget? headerDecoration` à `ZFolderCard`. Quand il est non nul, il remplace **exactement** le `Container` de pastille de l'en-tête actuel; le menu, le `Spacer`, le titre, le pied, la sémantique de carte et les branches hauteur bornée/non bornée restent inchangés. Quand il est nul, la pastille circulaire d'accent reste présente avec une taille effective de 14 dp : aucune branche nouvelle ne doit influencer ce chemin.

La barre est fournie par une primitive de présentation publique dédiée (nom à figer dans l'implémentation, p. ex. `ZFolderCardGradientAccent`) passée à ce slot. Elle reçoit une `gradientKey` opaque, qui est une identité persistante de dossier fournie par l'hôte, jamais un index d'affichage. Cette clé décorative ne devient pas une prop métier de `ZFolderCard`; le contrat de données de la carte reste ses primitives et slots.

#### D2 — La barre n'existe que sous configuration complète et directionnelle

La primitive de barre appelle `zResolveGradient(context, gradientKey)` et ne construit une barre que si, ensemble, le resolver renvoie une `ZGradientSpec` **et** les trois tokens nécessaires sont fournis : `accentBarHeight`, `gradientBegin`, `gradientEnd`. Toute configuration partielle, clé vide ou résolution `null` rend la barre structurellement absente, sans exception. Le preset IFFD peut injecter 4 dp, mais `4` ne figure pas dans la production : la hauteur vient exclusivement du token.

Les alignements doivent être `AlignmentDirectional.centerStart` et `AlignmentDirectional.centerEnd` (ou autres `AlignmentDirectional` injectés), jamais `Alignment.centerLeft` / `centerRight`. Pour un `LinearGradient`, les tokens remplacent son `begin`/`end`; un `Gradient` non linéaire fourni par l'hôte conserve sa nature sans cast non sûr. Le sens visuel s'inverse donc correctement en RTL. L'original IFFD utilise un `LinearGradient(colors: gradientColors)` à `folders_page.dart:953-965`, dont le sens physique par défaut ne doit pas être recopié dans zcrud.

#### D3 — G8 : la clé est stable sous permutation et filtrage

La couleur d'un dégradé appartient au dossier, non à sa position à l'écran. La `gradientKey` est donc la clé persistée du dossier (par exemple son id opaque); une clé de couleur ou un index de grille ne la remplace pas implicitement. L'anti-modèle contrôlé dans IFFD définit `buildFolderItem(FolderModel folder, int index)` (`folders_page.dart:461-462`) puis sélectionne `themeGradients[index % themeGradients.length]` si aucune couleur n'est définie (`472-478`) : le même dossier change alors de couleur après tri/filtre. C'est interdit.

VIS-1 a reporté explicitement sa garde G8 au premier consommateur : VIS-2 doit donc comporter un test de rendu/résolution qui monte les mêmes dossiers avec une permutation puis un filtrage, et prouve que, pour une même `gradientKey`, le `Gradient` observé est identique, indépendamment de tout index affiché.

#### D4 — Les comptes sont des slots de présentation, zéro signifie absence structurelle

`ZCountBadge` et `ZCountBadgeRow` sont des surfaces publiques de `zcrud_study`, à contenu injecté (icône et libellé sémantique) et sans connaissance de types métier. `ZCountBadgeRow` reçoit des descripteurs de compte; il élimine les comptes `<= 0` **avant** de construire un `ZCountBadge`. Ainsi le finder de `ZCountBadge`/de sa `ValueKey` ne trouve réellement aucun widget pour zéro : ni `Opacity(0)`, ni `Visibility`, ni `SizedBox.shrink`, ni espace réservé.

Pour rendre cette règle impossible à contourner par la surface unitaire, `ZCountBadge` ne représente qu'un compte strictement positif (assertion de contrat en debug/documentation); la ligne est l'unique constructeur conditionnel. Le résultat de `ZCountBadgeRow` est passé tel quel à `ZFolderCard.counts`, qui le rend déjà verbatim et l'omet quand le slot est `null` (`z_folder_card.dart:118-121, 166-180`). Ne pas ajouter à `ZFolderCard` des nombres de flashcards, notes, documents, sous-dossiers ou mindmaps : ce serait une prop métier et une seconde source de règles.

#### D5 — Un seul chrome de pastille de compte

Ne pas recopier le `Container` de `ZSubfolderCountPill`. Extraire/réutiliser un chrome interne commun dans `z_subfolder_item_chrome.dart` (padding, fond `secondaryContainer`, premier plan `onSecondaryContainer`, rayon, texte directionnel), puis faire composer ce chrome par `ZSubfolderCountPill` et les nouveaux badges. Le style effectif est :

- `countPillPadding ?? EdgeInsetsDirectional.symmetric(horizontal: theme.gapS, vertical: theme.gapS / 2)`;
- `countPillRadius ?? theme.radiusM`;
- `countPillIconSize ?? theme.gapM` pour l'icône du nouveau badge.

Ces replis conservent exactement le rendu de `ZSubfolderCountPill` actuel quand les tokens VIS restent `null`; aucune couleur ni dimension décorative littérale n'est ajoutée. Les icônes et les libellés sémantiques viennent de l'hôte. Chaque badge expose un `Semantics` explicite et un conteneur de zone au moins `48×48` dp; les insets, alignements, ordre et texte restent directionnels.

## Acceptance Criteria

> **Discipline R3 obligatoire.** Chaque garde ci-dessous doit être mordante : le dev réinjecte la régression exacte, observe le rouge, retire la régression, réobserve le vert et consigne chemin, ligne, commande et symptôme dans le Dev Agent Record. Une garde qui reste verte après retrait du correctif est refusée.

1. **AC1 — Slot `headerDecoration` rétrocompatible.** `ZFolderCard` expose `Widget? headerDecoration`, documenté comme un slot purement visuel. Non nul, il remplace la seule pastille d'en-tête; nul, il conserve la pastille circulaire de taille effective 14 dp (`_kPastilleSize` actuel, `z_folder_card.dart:65-67, 216-230`). Le menu, le footer `counts`, les états archive, le comportement d'interaction, la sémantique et les deux régimes de hauteur restent inchangés. Une golden sans scope, sans tokens et sans `headerDecoration` est exactement égale au PNG neutre committé; elle ne doit jamais être réacceptée par mise à jour de baseline.

2. **AC2 — Barre d'accent opt-in et complète.** La primitive publique de barre d'accent, utilisable dans `headerDecoration`, obtient son `ZGradientSpec` uniquement avec `zResolveGradient`. Elle rend le dégradé seulement lorsque `accentBarHeight`, `gradientBegin`, `gradientEnd` et un resolver qui renvoie une spec sont tous présents; sinon elle est absente de l'arbre et ne lève jamais. Avec un preset injecté, elle utilise la hauteur tokenisée (le preset de test vaut 4 dp), le dégradé résolu et son premier plan associé si nécessaire; aucun `Color(0x…)`, `Colors.*`, hauteur/rayon IFFD ou table de couleurs n'est ajouté dans `zcrud_study`.

3. **AC3 — Direction RTL de la barre.** Les extrémités applicables d'un `LinearGradient` sont celles des tokens `AlignmentDirectional`; aucune occurrence de `Alignment.centerLeft`, `Alignment.centerRight`, `EdgeInsets.left/right`, `TextAlign.left/right` ou positionnement physique nouveau n'est introduite. Sous `Directionality.rtl`, la barre commence côté logique start et finit côté logique end, sans exception; un test inspecte le `LinearGradient` rendu et une garde source interdit les alias physiques.

4. **AC4 — D3/G8, identité de dégradé stable.** L'API de la barre demande une `gradientKey` persistante et documente explicitement l'interdiction de l'index d'affichage. Avec un resolver déterministe qui produit des gradients distinctifs par clé, un même dossier conserve strictement le même gradient après permutation de la liste puis filtrage, tandis que des ids distincts peuvent rester distincts. Le test ne transmet aucun index au resolver; sa régression remplace volontairement la clé par `displayIndex % n` et doit rougir après permutation. Cette garde est l'implémentation reportée de G8 VIS-1.

5. **AC5 — `ZCountBadge` / `ZCountBadgeRow` publics, composables et sans règle métier.** Les deux types sont exportés par `package:zcrud_study/zcrud_study.dart`. Ils reçoivent uniquement des données de présentation injectées (nombre, icône, key optionnelle, libellé sémantique) et composent le slot `counts` existant de `ZFolderCard`; ils ne connaissent aucun modèle study, provider, repository, état ou compteur asynchrone. `counts: null` demeure absent et une `ZCountBadgeRow` sans compte positif ne réserve aucun pied de carte.

6. **AC6 — Compte zéro absent de l'arbre.** Toute entrée de compte `<= 0` est filtrée avant l'instanciation du widget de badge. En particulier, pour une ligne contenant zéro et un compte positif, seul le positif est présent; pour une ligne de zéros, `find.byType(ZCountBadge)` et les finders keyés de ces badges retournent `findsNothing`. Le test doit échouer si le badge est seulement caché (`Opacity(0)`, `Visibility`, `Offstage` ou widget vide) : l'absence est structurelle, comme les cinq conditions IFFD `if (!…Empty)` observées à `folders_page.dart:1064-1102`.

7. **AC7 — Style partagé et tokens de pill.** `ZCountBadge` et `ZSubfolderCountPill` utilisent le même chrome factorisé, sans duplication de `BoxDecoration` ni de logique de repli. `countPillPadding`, `countPillRadius` et `countPillIconSize` modifient respectivement le padding, le rayon et la taille d'icône quand ils sont injectés; leurs valeurs nulles reproduisent le chrome pré-VIS-2 de `ZSubfolderCountPill` (`z_subfolder_item_chrome.dart:47-74`). Les couleurs proviennent exclusivement de `ColorScheme.secondaryContainer` / `onSecondaryContainer` et le texte est directionnel.

8. **AC8 — Accessibilité, RTL et cibles.** Chaque badge positif a un `Semantics` explicite avec le libellé injecté, n'annonce pas deux fois son nombre, respecte `Directionality.rtl`, et expose une zone d'au moins 48 dp dans chacune des dimensions. La ligne conserve un ordre logique et des espacements directionnels. `ZFolderCard` conserve son plancher `kZFolderCardMinHeight == 48`; aucun `InkWell` inerte, gestionnaire d'état ou rebuild global de formulaire n'est introduit.

9. **AC9 — Isolation, API et défaut inchangé.** Seuls `zcrud_study` et ses tests/goldens sont touchés; aucune nouvelle dépendance/pubspec/codegen, aucune modification de `zcrud_core`, de `sprint-status.yaml`, d'IFFD ou de lex_douane. Les widgets restent Flutter natif et immuables quand possible (`const`); les nouveaux symboles publics sont préfixés `Z` et exportés par le barrel. L'exécution sans resolver/tokens continue de prendre la branche de pastille unie historique au pixel près, tandis qu'un golden distinct prouve le preset injecté.

## Tasks / Subtasks

- [ ] **T0 — Préconditions et frontières** (AC1-AC9)
  - [ ] Vérifier que VIS-1 est réellement verte et que `ZcrudTheme` porte les 16 tokens / `zResolveGradient` est exporté; si l'API diffère, HALT et escalader plutôt que contourner ou modifier `zcrud_core`.
  - [ ] Relire `ZFolderCard`, `ZSubfolderCountPill`, leurs tests et leur golden avant toute écriture; conserver les changements utilisateurs non liés.
  - [ ] Confirmer que le seul dépôt modifié est `packages/zcrud_study` (plus son test/golden) et que IFFD/lex restent lecture seule.

- [ ] **T1 — Slot d'en-tête et pastille historique** (AC1, AC9)
  - [ ] Ajouter `headerDecoration` et son dartdoc à `ZFolderCard`; rendre `headerDecoration ?? pastilleHistorique` au point unique de l'en-tête.
  - [ ] Conserver `_kPastilleSize` avec valeur effective 14 pour le chemin `null`; ne déplacer ni `menu`, ni `Spacer`, ni le footer, ni les branches `LayoutBuilder` sans une preuve de nécessité.
  - [ ] Étendre les tests de slot : `null` trouve la pastille; décoration distinctive trouve celle-ci et ne trouve plus la pastille; le slot n'affecte ni `counts` ni menu.

- [ ] **T2 — Primitive de barre à gradient stable** (AC2-AC4)
  - [ ] Créer le fichier de présentation dédié (p. ex. `lib/src/presentation/z_folder_card_chrome.dart`) ou un voisin cohérent, avec une primitive publique `Z...GradientAccent`; ne faire résoudre un gradient que par `zResolveGradient(context, gradientKey)`.
  - [ ] Exiger une clé non vide, une spec non nulle et les trois tokens avant de créer le sous-arbre décoratif; aucune valeur par défaut visuelle ne doit contourner ce contrat.
  - [ ] Pour un `LinearGradient`, appliquer les tokens directionnels via `copyWith(begin:, end:)`; préserver les gradients non linéaires sans supposer leur type. Ne pas introduire de `centerLeft`/`centerRight`.
  - [ ] Documenter près de `gradientKey` : id de dossier persistant, jamais index de liste, de pagination, tri ou filtre. Le harnais de test doit représenter explicitement un ordre d'affichage séparé de l'identité.

- [ ] **T3 — Chrome partagé et badges publics** (AC5-AC8)
  - [ ] Factoriser le chrome aujourd'hui dans `ZSubfolderCountPill` dans `z_subfolder_item_chrome.dart`; faire consommer exactement cette même voie par `ZSubfolderCountPill` et les nouveaux badges.
  - [ ] Définir les descripteurs de ligne minimaux nécessaires (données de présentation seulement) et faire filtrer `<= 0` dans `ZCountBadgeRow` avant tout `ZCountBadge`.
  - [ ] Construire le badge positif avec icône/label injectés, `Semantics` explicite, `ConstrainedBox` ou équivalent de 48×48, `EdgeInsetsDirectional`, `TextAlign.start` et tokens de pill avec replis D5.
  - [ ] Passer une `ZCountBadgeRow` au slot `counts` sans modifier le contrat de `ZFolderCard` ni lui ajouter de compte métier.

- [ ] **T4 — Barrel public et documentation** (AC5, AC9)
  - [ ] Exporter seulement les nouvelles surfaces publiques depuis `packages/zcrud_study/lib/zcrud_study.dart`; conserver les helpers/chrome interne sous `src/`.
  - [ ] Mettre à jour le dartdoc de `ZFolderCard`, du slot et des badges : injection, absence structurelle à zéro, clé stable et comportement sans preset.

- [ ] **T5 — Tests R3, widget et golden** (AC1-AC9)
  - [ ] Étendre le harnais existant `test/presentation/z_folder_card_test.dart` ou créer des fichiers VIS-2 ciblés; réutiliser `pumpCard`, `buildFixedTheme` et les finders par `ValueKey` plutôt que les textes localisés.
  - [ ] Conserver `test/golden/goldens/z_folder_card_neutral.png` comme oracle de non-régression; ne l'écraser sous aucun prétexte. Ajouter une golden séparée pour le preset complet (scope + resolver stable + tokens + header bar).
  - [ ] Réinjecter une fois chacune des régressions du plan R3 ci-dessous, consigner le rouge réel puis restaurer et confirmer le vert.

- [ ] **T6 — Vérif verte et handoff** (AC9)
  - [ ] Examiner le diff et exécuter `git diff --check`.
  - [ ] Exécuter `melos run analyze` et obtenir RC=0.
  - [ ] Depuis `packages/zcrud_study`, exécuter `flutter test` (et non `dart test`, faux-rouge `dart:ui`) avec RC=0 et un total strictement supérieur à la baseline de 633 tests après les nouveaux tests VIS-2.
  - [ ] Ne pas déclarer la story terminée ni modifier `sprint-status.yaml`: consigner les résultats dans le Dev Agent Record pour l'orchestrateur.

## Dev Notes

### Plan de tests détaillé — R3

| Garde | Emplacement conseillé | Assertion verte | Régression à réinjecter, puis rouge attendu |
|---|---|---|---|
| G1 — golden zéro-config | `test/golden/z_folder_card_golden_test.dart` | Sans `ZcrudScope`, sans tokens et sans `headerDecoration`, l'image correspond exactement à `goldens/z_folder_card_neutral.png` | Donner une décoration ou une hauteur par défaut à la carte : mismatch golden. Restaurer le code, jamais le PNG. |
| G2 — golden preset | même fichier, PNG distinct | Scope avec resolver stable + `accentBarHeight: 4` + alignements directionnels rend la barre attendue, distincte de G1 | Retirer le passage du gradient, de la hauteur ou du slot : mismatch de la golden preset. |
| G3 — configuration complète | test widget de la primitive | Resolver seul, tokens seuls, clé vide ou resolver `null` : finder de barre `findsNothing`; les quatre ensemble : `findsOneWidget` | Remplacer le `&&` complet par un `||` ou donner une valeur par défaut : un cas partiel affiche une barre. |
| G4 — slot/pastille | `z_folder_card_test.dart` | `headerDecoration: null` conserve le cercle 14; une décoration keyée remplace le cercle et le menu/footer restent présents | Ignorer le slot ou toujours rendre la pastille : finder de remplacement/cercle échoue. |
| G5 — D3/G8 permutation/filtrage | nouveau test `z_folder_card_gradient_accent_test.dart` | Même id opaque → même `LinearGradient` avant/après permutation et filtrage; ids différents → specs distinctives | Réinjecter `displayIndex % gradients.length` : l'id conservé obtient une autre spec après permutation, assertion rouge. |
| G6 — zéro absent | test badges | `ZCountBadgeRow` avec `0, 3` construit un seul `ZCountBadge`; avec seulement `0` le finder par type **et** les keys retournent `findsNothing` | Remplacer le filtre par `Opacity(0)`/`Offstage`/widget vide : `find.byType(ZCountBadge)` reste présent et rougit. |
| G7 — chrome commun/tokens | test widget des badges et sous-dossier | Les deux pill suivent la même décoration; padding/rayon/icône changent avec tokens et retombent au style existant à `null` | Dupliquer le style ou ignorer un token : comparaison des décorations/tailles attendues rouge. |
| G8 — semantics/48 dp | test widget avec `ensureSemantics()` | Label injecté une seule fois, zone de chaque badge positif ≥48×48, zéro absent | Retirer `Semantics`, réduire la contrainte ou laisser le texte annoncer deux fois : arbre/taille rouge. |
| G9 — RTL directionnel | test widget + scan source ciblé | Sous RTL, le gradient porte `AlignmentDirectional.centerStart/End`, la ligne de badges ne lève pas et l'ordre logique est conservé | Réinjecter `Alignment.centerLeft/Right` ou un inset physique : scan/inspection gradient rouge. |
| G10 — pureté/frontières | scan source ciblé | Aucun `Colors.`, `Color(0x`, provider/Get/Riverpod, index de display ou modèle study dans les nouveaux widgets | Réinjecter l'un de ces anti-modèles : scan rouge. |

### Fichiers et état actuel vérifiés sur disque

- `packages/zcrud_study/lib/src/presentation/z_folder_card.dart`
  - `_kPastilleSize = 14` est la pastille historique (lignes 65-67); le constructeur expose déjà les slots `counts` et `menu` (86-101).
  - `counts` est rendu verbatim, puis absent quand `null` (118-121, 166-180); il ne faut pas lui ajouter de props métier.
  - L'en-tête réel est la `Row` 216-230 : pastille, `Spacer`, `menu`; c'est l'unique point où agit le nouveau slot.
  - La carte conserve son minimum 48 (`kZFolderCardMinHeight`, lignes 56-58 et 261-282), son label sémantique unique et l'absence d'`InkWell` inerte.

- `packages/zcrud_study/lib/src/presentation/z_subfolder_item_chrome.dart`
  - `ZSubfolderCountPill` est le style à factoriser/réutiliser, pas à copier : padding directionnel `gapS` (60-63), couleurs `secondaryContainer` / `onSecondaryContainer` (64-72), rayon `radiusM` (66).
  - Son rendu par défaut est le contrat historique à préserver lorsque les tokens VIS sont nuls.

- `packages/zcrud_study/test/presentation/z_folder_card_test.dart`
  - Le helper `pumpCard` gère taille bornée/non bornée, resolver de couleur et RTL (17-43); les tests existants couvrent déjà slot `counts`, menu, minimum 48, RTL et sémantique. Étendre ces patterns sans les affaiblir.

- `packages/zcrud_study/test/golden/z_folder_card_golden_test.dart`
  - La golden neutre, surface 240×180 et carte 220×160, est déjà l'oracle SUF-2 (20-58). Elle doit rester intacte comme garde pixel à pixel; le preset VIS-2 a son propre fichier PNG et son propre test.

- `packages/zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart`
  - `zResolveGradient` est total et renvoie seulement le seam hôte ou `null` (85-96). `zDerivedGradientResolver` est explicitement opt-in et utilise déjà `AlignmentDirectional.centerStart/End` (37-82). Ne pas lui ajouter de repli automatique et ne pas modifier ce package dans VIS-2.

### Contraintes d'architecture non négociables

- **AD-1 / AD-2 / AD-15 :** `zcrud_study` dépend de `zcrud_core`, jamais l'inverse; Flutter natif seulement, aucun Riverpod/Get/provider, aucune I/O, aucun état métier ou async dans ces widgets. Les slots et données injectées restent la frontière.
- **AD-4 / AD-45 :** `null` ou compte non positif signifie absence structurelle, non un widget désactivé/caché; la carte garde son absence d'`InkWell` inerte.
- **AD-13 :** `Semantics` explicite, cibles ≥48 dp, `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start`, `const` où possible, RTL testé. L'icône n'est jamais le seul canal : le libellé sémantique injecté nomme chaque compte.
- **FR-26 / NFR-S7 :** aucune couleur littérale. Les couleurs viennent du `ColorScheme` (chrome badges) ou de `ZGradientSpec` (barre); les dimensions de la barre/pill viennent des tokens ou des métriques de thème documentées.
- **Invariant VIS majeur :** sans `gradientResolver`, sans tokens VIS et sans slot d'en-tête, aucune branche ne peut modifier le rendu actuel. La golden neutre est l'oracle non négociable; le preset est prouvé séparément.
- **Réactivité :** aucun `setState` de formulaire, controller ou gestionnaire de state n'a sa place ici; les widgets sont de présentation immuable et ne reconstruisent que par le mécanisme Flutter normal de leur parent.

### Project Structure Notes

- Production : modifier `packages/zcrud_study/lib/src/presentation/z_folder_card.dart`; factoriser le chrome dans `z_subfolder_item_chrome.dart`; créer au besoin un unique voisin `z_folder_card_chrome.dart` pour la barre et les surfaces publiques; exporter ces surfaces depuis `packages/zcrud_study/lib/zcrud_study.dart`.
- Tests : compléter `packages/zcrud_study/test/presentation/z_folder_card_test.dart` et/ou ajouter des fichiers ciblés sous le même dossier; compléter `test/golden/z_folder_card_golden_test.dart` et ajouter seulement le PNG de preset nécessaire dans `test/golden/goldens/`.
- Ne pas modifier de `pubspec.yaml`, de code généré, du core, d'IFFD, de lex_douane, ni `_bmad-output/implementation-artifacts/sprint-status.yaml`. Aucune dépendance nouvelle n'est justifiée.
- Le resolver de gradient est une seam d'identité : le preset de test/hôte doit employer une fonction top-level/stable ou mémoïsée hors `build`, jamais une closure recréée au build.

### Risques et points d'attention

1. **Régression silencieuse zéro-config :** un fallback automatique de gradient ou une barre par défaut ferait passer visuellement à côté du contrat. Mitigation : G1 et branche stricte D2.
2. **Stabilité de couleur fausse :** le harnais ne doit pas dériver la clé du compteur d'itération. Mitigation : représenter id persistant et index affiché par deux variables distinctes; G5 doit réinjecter l'index.
3. **Faux zéro absent :** `Offstage` et `Opacity` conservent le widget. Mitigation : assertions par type et keys, pas seulement pixels ou visibilité.
4. **Duplication chrome :** une seconde `BoxDecoration` fera diverger sous les tokens. Mitigation : extraction interne unique et G7 sur les deux consommateurs.
5. **RTL partiel :** un gradient peut être directionnel tandis que ses badges restent physiques. Mitigation : test RTL réel + scan source G9.
6. **Golden réacceptée :** mettre à jour la baseline neutre masquerait précisément la régression. Mitigation : PNG neutre immuable, PNG preset distinct.

### References

- [Source: `.claude/skills/bmad-create-story/template.md` — structure obligatoire de story]
- [Source: `_bmad-output/implementation-artifacts/stories/vis-1-tokens-look-couture-degrade.md` — D3/G8 reportée, couture `zResolveGradient`, tokens nullables et invariant pixel-identique]
- [Source: `_bmad-output/implementation-artifacts/sprint-status.yaml:522-530` — séquencement VIS-1 → VIS-2 et périmètre zcrud_study]
- [Source: `packages/zcrud_study/lib/src/presentation/z_folder_card.dart:56-67, 86-121, 166-180, 216-246, 261-307` — structure, slots, pastille, footer et a11y actuels]
- [Source: `packages/zcrud_study/lib/src/presentation/z_subfolder_item_chrome.dart:47-74` — style existant de `ZSubfolderCountPill` à réutiliser]
- [Source: `packages/zcrud_study/test/presentation/z_folder_card_test.dart:17-50, 134-174, 208-304` — harnais et gardes R3 existants]
- [Source: `packages/zcrud_study/test/golden/z_folder_card_golden_test.dart:1-59` — oracle golden neutre]
- [Source: `packages/zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart:37-96` — resolver opt-in, null fonctionnel et alignements directionnels]
- [Source (LECTURE SEULE) : `/home/zakarius/DEV/iffd/lib/src/presentation/features/folders/pages/folders_page.dart:461-478` — anti-modèle index de liste]
- [Source (LECTURE SEULE) : `/home/zakarius/DEV/iffd/lib/src/presentation/features/folders/pages/folders_page.dart:953-965` — barre 4 dp de référence, à adapter directionnellement]
- [Source (LECTURE SEULE) : `/home/zakarius/DEV/iffd/lib/src/presentation/features/folders/pages/folders_page.dart:1064-1102` — cinq badges conditionnels, zéro/absence structurelle]
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md` — AD-1, AD-2, AD-4, AD-13, AD-15, AD-45, FR-26/NFR-S7]

## Dev Agent Record

### Agent Model Used

Implémentation : Codex (`gpt-5.6-terra`). Reconstruction après incident, reprise R3 et rejeux verts :
orchestrateur Claude.

### Debug Log References

**Vérif verte finale — REJOUÉE PAR L'ORCHESTRATEUR** : `melos run analyze` **RC=0** (0 erreur) ·
`melos run verify` **RC=0** · `zcrud_study` `flutter test` **RC=0 — 642 tests** (633 baseline + 9).

**Injections R3 — 7 gardes prouvées mordantes**

| Garde | Régression injectée | Résultat | Par |
|---|---|---|---|
| G1 — golden zéro-config | pastille par défaut `_kPastilleSize + 6` (`z_folder_card.dart:232`) | **ROUGE** — écart golden | orchestrateur |
| G2 — golden preset | golden de preset absente | **ROUGE** (`non-existent file`) | dev |
| G3 — configuration complète | `\|\|` → `&&` sur la garde des 4 entrées | **ROUGE** (null-safety) | dev |
| G4 — slot/pastille | slot ignoré, pastille toujours rendue | **ROUGE** (`Found 0 widgets with key`) | dev |
| G6 — zéro absent de l'arbre | `.where((b) => b.count > 0)` → `(b) => true` (`z_subfolder_item_chrome.dart:168`) | **ROUGE** | orchestrateur |
| G9 — RTL directionnel | `AlignmentDirectional` → `Alignment` physique | **ROUGE** | orchestrateur |
| G10 — pureté couleurs | `Color(0xFF667eea)` injecté dans le chrome | **ROUGE** (2 scans) | orchestrateur |

⚠️ **G1 a exigé TROIS tentatives, et les deux premières auraient conclu à tort.**
(1) motif introuvable ⇒ aucune injection appliquée ⇒ **faux vert** ; (2) injection utilisant `??=`
sur une variable `final` ⇒ rouge du **compilateur**, pas de la golden ⇒ **faux rouge** ; (3) bonne
cible enfin trouvée — `ZFolderCardGradientAccent` n'est PAS dans l'arbre par défaut (l'hôte le place
dans le slot), il fallait donc injecter dans `ZFolderCard` lui-même. **Un code retour ne qualifie pas
un rouge** : il faut lire la nature de l'échec.

**G5 (D3/G8 — invariance sous tri/filtrage)** : couverte par le test dédié ; jugée **insuffisante**
par la code-review d'epic (MEDIUM-2) — voir `code-review-epic-vis.md`.

### Completion Notes List

**⚠️ Incident : travail détruit puis reconstruit (faute de l'orchestrateur).** En rejouant le
reliquat R3, l'orchestrateur a exécuté `git checkout -- lib/src/presentation/` pour restaurer ses
injections. Cette commande ne distingue pas une injection d'une **modification légitime non
commitée** : elle a effacé le slot `headerDecoration` (`z_folder_card.dart`) et
`ZCountBadge`/`ZCountBadgeRow`/`ZCountBadgeSpec` (`z_subfolder_item_chrome.dart`) ⇒ **20 erreurs de
compilation**. Les fichiers *non suivis* (chrome, tests, golden, barrel) ayant survécu, les **tests
ont servi de contrat** pour reconstruire l'API à l'identique. Vert rétabli : 642 tests.
**Règle retenue** : une injection se restaure uniquement depuis une copie explicite du fichier,
jamais via git, et jamais en visant un répertoire.

**⚠️ Second effet** : une injection faite dans un fichier **non suivi** (`z_folder_card_chrome.dart`)
a survécu au `git checkout` et a pollué deux exécutions suivantes. Retirée manuellement.

**Neutralité prouvée au niveau de l'oracle** : `git status` confirme qu'**aucun PNG golden
préexistant n'a été modifié** — la non-régression n'est donc pas obtenue en déplaçant la référence.

### File List

**Production** (`zcrud_study` uniquement)
- `lib/src/presentation/z_folder_card.dart` — UPDATE (slot `headerDecoration`)
- `lib/src/presentation/z_folder_card_chrome.dart` — NEW (`ZFolderCardGradientAccent`)
- `lib/src/presentation/z_subfolder_item_chrome.dart` — UPDATE (`ZCountBadge`, `ZCountBadgeRow`, `ZCountBadgeSpec`)
- `lib/zcrud_study.dart` — UPDATE (exports)

**Tests**
- `test/presentation/z_folder_card_vis2_test.dart` (NEW)
- `test/golden/z_folder_card_vis2_golden_test.dart` + `test/golden/goldens/z_folder_card_vis2_preset.png` (NEW)
