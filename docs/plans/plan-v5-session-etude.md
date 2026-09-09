# Plan V — Intégrer une session d'étude sans la recomposer

> **Fichier de persistance.** Ce plan vit dans le dépôt pour survivre au redémarrage
> d'une session et permettre la reprise par un autre exécutant. Il est la source de
> vérité de l'avancement : **cocher chaque lot ici au fur et à mesure**, jamais dans un
> scratchpad (qui est purgé).
>
> Base : **v3.49.0** (`ce865bca8`). Dépôts hôtes en LECTURE SEULE ABSOLUE.

## Suivi d'avancement

> ✅ **LIVRÉ — v3.50.0, 2026-09-09.** Les 18 lots sont clos et vérifiés par l'orchestrateur ; generate/analyze/verify verts au repos, 41/42 paquets verts au balayage (`zcrud_generator` rouge environnemental, identique à l'octet à v3.49.0). Ce plan est conservé comme trace : **ne relancer aucun lot sans le remesurer**.

| Lot | Paquet | État |
|---|---|---|
| D1 chaîne de résolution du liseré | `zcrud_flashcard` | ✅ fait |
| D2 `accentHeight` | `zcrud_flashcard` | ✅ fait |
| D3 `backgroundColor` par instance | `zcrud_flashcard` | ✅ fait |
| **D1b** ordre **seam > jeton** (défaut trouvé en chemin) | `zcrud_flashcard` | ✅ fait |
| D4 relais des slots orphelins | `zcrud_study` | ✅ fait |
| D5 les 10 seams perdus du scaffold | `zcrud_study` | ✅ fait (42/42 relayés + garde d'exhaustivité) |
| **D5b** ordre **seam > jeton** sur la carte de liste | `zcrud_study` | ✅ fait |
| D6 documentation des formats de clé | `docs/` | ✅ fait |
| P1 `ZSessionProgressStyle.pill` | `zcrud_session` | ✅ fait |
| P2 mesure de fidélité | `zcrud_session` | ✅ mesuré — **décision : fidélité par nos briques, aucun tiers** (les deux paquets du legacy sont inutiles ou rédhibitoires, cf. §P2) |
| **P2b** géométrie de `dots` paramétrable + style à marqueur triangulaire maison | `zcrud_session` | ✅ fait — `ZSessionDotsGeometry` (5 champs, défauts = rendu actuel), `ZSessionProgressStyle.segmentedMarker` (painter privé, RTL par `Directionality`, parité `Semantics` des 5 styles), relais jusqu'au swiper ; référence mesurée : `Size(14,10)`, ×2,4, gap 12, `center`, `scrollable`, épaisseur 8 ; 727 tests |
| P3 `preset/` + champ `preset` + en-tête | `zcrud_study` | ✅ fait — `ZStudySessionPreset`(+`.classic`), `ZSessionHeaderSpec`, `ZCardChromeSpec` ; seul widget neuf `_ZSessionHeaderRow` ; `progressStyle` devenu **nullable** (host/view/scaffold) pour que « posé » se distingue de « non posé » ; 2094 tests, 57 s |
| P4 Classic après D1b + `accentBarHeight` (à mesurer) | `zcrud_themes` | ✅ fait — doc alignée `paramètre > seam > jeton > référence` ; `accentBarHeight` **non posé** (mesuré : effet dépendant des branchements de l'hôte) ; 8 jetons de chrome laissés `null` (`ZPageShellReference` porte déjà les mêmes valeurs) ; 107 tests |
| **P2c** relais de `progressDotsGeometry` + épaisseurs sur preset/host/scaffold/view ; `.classic` pose la géométrie de référence | `zcrud_study` | ✅ fait — G1 étendue par admission **nominative** du type de géométrie (règle : cosmétique = ne câble rien), contre-preuve `ZFutureGeometry?` ⇒ seam ; 2244 tests, 1 min 01 |
| W1 `ZStudySessionWiring` + `.wired` | `zcrud_study` | ✅ fait — 43 paramètres mesurés : **22 seams / 12 cosmétiques**, règle de type fail-safe écrite dans la garde G1 (source, sur disque) ; `.wired` = constructeur de transfert, arbre identique nœud pour nœud ; 2162 tests, 1 min 09 |
| W2 `ZStudySessionScaffold.wired` | `zcrud_study` | ✅ fait — `const .wired`, wiring remis **entier** au host (le `const` rend le démontage champ par champ impossible à la compilation) ; G5 réutilise les 22 sondes de W1 |
| W3 `ZStudySeam` + audit | `zcrud_study` | ✅ fait — `ZStudySeam` (22, chacune porte son `fallback`), `ZStudySeamReport` (+`invalidWaivers`), `ZStudySeamAuditPolicy`, `auditSeams()` pur ; `.none()` ⇒ 22 `waived`, 0 `missing` ; renonciation inutile = erreur du rapport (AD-10) ; 2296 tests, 1 min 01 |
| W4 démos migrées + README | `zcrud_study` | ✅ fait — **prémisse fausse** : 0 démo à migrer (99 sites à plat, tous des harnais ; `suf4_assembly_demo.dart` n'assemble ni host ni scaffold) ⇒ démonstration de référence **construite** (`z_session_mount_demos.dart`, écran + page en `.wired`), G8 nominative à 3 contre-preuves, README « Trois façons de monter une session » ; 2304 tests, 1 min 10 |
| **X1** jetons `fab*`/`chip*`/`appBarWash*` (reste du plan précédent) | `zcrud_core` + `zcrud_ui_kit` | ✅ fait — 8 jetons ; `chipSelectedColor` écarté par la mesure (déjà résolu `paramètre > palette signature`) |

### Audit des plans antérieurs (2026-09-08, mesuré sur disque)

Les plans « Réactivation des chaînes d'étude » (2026-08-28) et « `zcrud_themes` » sont
**intégralement livrés** à v3.49.0 — chaque lot prouvé présent, `fichier:ligne` à l'appui.
Deux points qui figuraient comme « restes » dans leur texte ne le sont pas : le port de
partage v2 est livré depuis **v3.33.0**, et l'« Apparence F » a été **annulée par décision**
le 29/08, pas laissée en attente. L'exemption `flip_card` est pré-approuvée mais
volontairement non déclenchée — aucun composant ne l'exige.

**Un seul reste mesuré**, inscrit ci-dessus comme lot **X1** : les jetons
`fab{Shape,Elevation,IconSize,LabelStyle}`, `chip{Shape,ShowCheckmark,SelectedColor}` et
`appBarWash{Alphas,Elevation}` sont absents de `ZcrudTheme` (grep négatif), alors que
`ZChoiceChipStyle` et `ZGradientFab` (`zcrud_ui_kit`) sont leurs consommateurs cibles déjà
en place. Sans eux, ces métriques ne sont pas remplaçables par thème.

⚠️ **Ne relancer aucun autre lot de ces deux plans sans le remesurer** : ce dépôt a déjà
relancé douze lots livrés depuis dix jours, et lancé un agent sur un défaut qui n'existait
plus.

### Défauts trouvés en cours d'exécution (non prévus par le plan)

1. **Le dégradé était annulé sans géométrie déclarée.** `_resolvedGradient` rendait `null`
   dès que `gradientBegin` **ou** `gradientEnd` manquait — et le thème « Classic » ne les
   pose pas. Sans cette levée, D1 et D2 auraient été **inertes chez un hôte réel**, et leurs
   gardes n'auraient été vertes qu'en posant ces jetons dans le harnais. Corrigé dans D1.
   ⚠️ Effet de bord à porter au handoff : le **badge de type** peut apparaître teinté chez un
   hôte qui fournit `questionTypeBadgeBuilder` et un résolveur sans poser ces deux jetons.
2. 🔴 **Le jeton passait AVANT le seam** sur les deux cartes, à rebours de l'ordre que
   `zResolveGradient` applique partout ailleurs (`seam > jeton > référence`). Comme
   `ZClassicTheme` pose `flashcardTypeGradients`, un hôte adoptant notre thème voyait son
   résolveur **ignoré sans aucun signal**. Décision du propriétaire : **aligner sur l'ordre
   du socle**. Lots D1b (carte de session) et D5b (carte de liste). **Rupture** pour un hôte
   qui comptait sur le jeton pour gagner ; échappatoire : `typeGradientKey`.
3. **La lacune documentaire était bien plus large que la flashcard** : la famille
   `zcrud.signature.<identité>` — **dix émetteurs**, dont l'app-bar, le bouton flottant et
   les en-têtes de section de tout formulaire groupé — n'était documentée **nulle part** dans
   `docs/site/`. Couverte par D6.

⚠️ **Pièges d'outillage, à rappeler dans chaque brief** :
- `flutter analyze` **sans `--no-pub`** déclenche un `pub get` qui **réécrit le `.dart_tool/package_config` partagé** du workspace — un agent qui l'exécute peut faire rougir au chargement un autre paquet en cours de mesure. Toujours `flutter analyze --no-pub` et `flutter test --no-pub`.
- `packages/zcrud_themes/` est **suivi par git** depuis v3.49.0 (`ce865bca8`) ; seul `docs/plans/` est encore non suivi. L'interdiction de `git checkout`/`stash`/`clean` vaut pour **tout** travail non commité, suivi ou non.
- **Le balayage des 42 paquets a été tué par manque de mémoire** (14 Gi, 6 paquets passés) : `flutter test` sans `-j` ouvre autant d'isolates que de cœurs (≈ 660 % CPU mesurés) et les gros paquets cumulent. Balayer avec **`flutter test --no-pub -j 4`**, mesurer `free -g` avant, tuer les `flutter_tester`/`frontend_server` orphelins qu'un run tué laisse derrière lui, et reprendre en sautant les paquets déjà verts plutôt que tout rejouer.
- `find … -newermt '-90 seconds'` est
**rejeté** par le `find` installé (`bfs`) — erreur sur stderr, stdout vide, **RC=0**. Tout
contrôle de concurrence fondé dessus est faussement rassurant. Forme correcte :
`find <chemins> -type f -printf '%T@\n' | sort -n | tail -1`, comparée à `date +%s`.

⚠️ **Second piège d'outillage** : le `grep` installé est **ugrep**, qui **honore
`.gitignore` par défaut** — vérifié par expérience. Tout grep de résidus doit porter
`--no-ignore-files`, sinon il est faussement rassurant.

### Dépendances tierces — mesure faite, aucune retenue (2026-09-08)

Le propriétaire les avait autorisées et **privilégiait la fidélité**. La mesure a montré que
les deux paquets de la référence la **desservent** :
- `dots_indicator` n'apporte **aucune capacité** (même `Container(width,height,margin,
  ShapeDecoration)` que notre `_Dot`) et impose huit `assert` qui **lèveraient** là où nous
  bornons (AD-10) ;
- `segmented_progress_bar` porte `TextDirection.ltr` **en dur**, non paramétrable —
  violation directe d'AD-13 —, n'expose aucun `Semantics`, et son heuristique **écrase** le
  marqueur demandé dès qu'un segment est étroit.

| Style | Écart visible vs le tiers du legacy | Verdict sur le tiers |
|---|---|---|
| `dots` vs `dots_indicator` | point inactif circulaire 8×8 au lieu d'une pilule 14×10 ; actif ×1,5 au lieu de ×2,4 ; espacement 4 dp au lieu de 12 ; alignement `start` au lieu de `center` ; file longue qui passe à la ligne | **n'apporte aucune capacité** : sa source rend un `Container(ShapeDecoration)` identique à notre `_Dot` ; ses `lerp` s'écrasent ; il impose 8 `assert` qui **lèveraient** là où notre `position` borne (AD-10). La fidélité s'obtient en **paramétrant notre géométrie** |
| `segmentedBar` vs `segmented_progress_bar` | segments séparés et tous arrondis (vs bandes jointives), **marqueur triangulaire** sur le courant, 8 dp vs 4 dp | **rédhibitoire** : `TextDirection.ltr` **codé en dur** dans un `CustomPainter` (violation AD-13 non paramétrable), `shouldRepaint => true`, aucun `Semantics`, et une heuristique qui **écrase le `isAbove` demandé** dès qu'un segment fait < ~50 dp — défaut que la référence subit elle-même (elle omet sa dernière carte). Reproduction fidèle par un `CustomPainter` privé (~40 l), RTL par `Directionality`, zéro dépendance |

⇒ **Décision du propriétaire (2026-09-09) : fidélité par PARAMÉTRAGE de nos briques** (lot P2b). Le rendu visé est
atteint, sans dette ni violation, avec l'accessibilité en plus. Les valeurs de la référence
ne deviennent **pas** des défauts du socle : elles seront posées par le thème.


**Règles d'exécution communes** : un seul rédacteur par paquet ; scratchpads distincts ;
discipline R3 sur chaque garde (rouge **par assertion**, restauration **par copie de
fichier** — jamais `git checkout`, sha256 avant/après, grep négatif montré) ; `flutter
test --no-pub` **depuis le dossier du paquet** ; vérif verte rejouée par l'orchestrateur au
repos ; `melos run verify` repo-wide et balayage des 42 paquets avant tout tag.

---

# Partie V — Intégrer une session d'étude sans la recomposer

> Rédigé le 2026-09-08 sur trois explorations en lecture seule (la chaîne du liseré ;
> l'anatomie des cinq formes manquantes ; le coût réel mesuré chez l'hôte) et deux
> conceptions parallèles (preset / montage énuméré). Base : **v3.49.0**, 42 paquets.
> Dépôts hôtes en LECTURE SEULE ABSOLUE.

## 1. Contexte — pourquoi ce plan

CR-IFFD-143 constate, après le portage d'une session sur `ZStudySessionHost` : **tout ce
qui a traversé jusqu'ici est une VALEUR** (couleurs, libellés, clés, seams de notation) ;
**tout ce qui manque est une FORME** (liseré, fond, en-tête, pilule, pastilles). Un thème
transporte des valeurs — il ne peut pas, par construction, livrer une disposition. La CR
propose des **assemblages de référence paramétrés**, livrés par le paquet qui rend déjà
l'écran, et refuse explicitement de casser la garde anti-widget de `zcrud_themes`.

La mesure a confirmé le besoin **et trouvé plus grave** :

- 🔴 **le liseré ne peut pas fonctionner** : la carte de liste demande la clé
  `'flashcard.type.<name>'` (`z_default_flashcard_card.dart:434`, constante publique `:107`),
  la carte de **session** demande `card.type.name` **nu** (`z_flashcard_review_card.dart:939`).
  Deux conventions incompatibles pour la même notion ; l'hôte qui suit le format documenté
  n'est jamais appelé en session ;
- 🔴 **le jeton que nous venons de livrer est ignoré** : `ZcrudTheme.flashcardTypeGradients`
  (`z_theme.dart:1515`), posé par `ZClassicTheme` (`z_classic_theme.dart:121`), est lu par la
  carte de liste (`:431`) et **jamais** par celle de session. Le thème « Classic » de v3.49.0
  ne peut donc pas teindre le liseré d'une session ;
- 🔴 **le liseré n'est même pas monté** : il exige `ZcrudTheme.accentBarHeight` non nul,
  **défaut `null`** (`z_theme.dart:410,1131`) ;
- 🔴 **deux slots existants sont orphelins** : `ZFlashcardReviewCard.questionTypeBadgeBuilder`
  (`:133,862-899`) et `.instructionBanner` (`:139,902-911`) — exactement les deux pastilles
  réclamées — ne sont **jamais** passés par le host (`z_study_session_host.dart:919-923,938-943`) ;
- 🔴 **le scaffold perd 10 des 19 seams** (`z_study_session_scaffold.dart:290-317`) ;
- 🔴 **tout oubli de seam est SILENCIEUX** : `ZStudySessionHost` porte 37 paramètres nommés,
  dont 2 requis et 27 nullables. L'hôte a perdu six seams d'un coup — `contentBuilder`,
  `hintPort`, `evaluationPort`, `labels`, `onExit`, `onSessionEnd` — et *« `flutter analyze`
  est resté VERT — tous sont optionnels. La suite aussi »* (commits `5da020c` → `c48adf4`).
  Seul l'écran l'a montré. **Chaque hôte suivant paiera la même erreur séparément.**

Ordre de grandeur mesuré : l'écran porté fait **456 lignes** contre **1202** en legacy — le
socle apporte déjà 62 % de réduction. Ce plan vise le reste.

## 2. Décisions du propriétaire (2026-09-08)

| Sujet | Décision |
|---|---|
| Anti-oubli | **Montage énuméré `.wired` + audit** — `required` sur champ nullable : oublier ne compile plus, renoncer s'écrit `null` |
| Périmètre | **Les trois vagues, dans l'ordre** : défauts → preset → anti-oubli |
| Dépendances tierces | **Autorisées dans les paquets d'étude**, et **adoptées ici pour la fidélité** au legacy |

⚠️ **Réserve inscrite sur la troisième décision, à appliquer telle quelle.** La mesure montre
que le socle possède déjà `ZSessionProgressIndicator.dots`/`.segmentedBar`, `ZSkeleton`,
`ZStreakBadge` et un retournement de carte maison (`Matrix4.rotateY`). Les tiers entrent donc
**derrière l'API existante**, comme implémentation d'un style, **jamais comme un second
widget** — sinon on crée l'indicateur concurrent que ce chantier combat. Et la bascule
maison → tiers se décide sur un **écart visuel constaté à l'écran**, jamais supposé : la
vague 2 porte cette mesure avant d'ajouter la moindre ligne à un `pubspec`.

## 3. Vague 1 — les défauts livrés (aucun ne demande de décision produit)

| Lot | Paquet | Contenu |
|---|---|---|
| **D1** | `zcrud_flashcard` | Chaîne de résolution du liseré de session, **additive** : jeton `flashcardTypeGradients[name]` → `zResolveGradient('flashcard.type.$name')` → `zResolveGradient(name)` (**échappatoire : le comportement d'aujourd'hui, conservé en dernier**). Constante de préfixe **jumelle** (`zcrud_flashcard` ne peut pas importer celle de `zcrud_study` — sens des arêtes), gardée par **parité de source** sur le patron déjà accepté de `z_classic_theme.dart:59-66` |
| **D2** | `zcrud_flashcard` (avec D1) | `ZFlashcardReviewCard.accentHeight` (`param > jeton accentBarHeight`). 🚫 **Ne pas changer le défaut du jeton** : il gouverne aussi `ZFolderCardGradientAccent` (`z_folder_card_chrome.dart:32`) et `z_field_widget.dart:613` — le changer repeindrait deux surfaces que personne n'a demandées |
| **D3** | `zcrud_flashcard` (avec D1) | `backgroundColor` par instance sur la carte (`Material` de `:986-988`, aujourd'hui figé sur `theme.surfaceColor ?? scheme.surface`) |
| **D4** | `zcrud_study` (après D1-D3) | Relais des slots orphelins aux **deux** sites (`_buildCard:919-923`, `_buildCardSlot:938-943`) : `questionTypeBadgeBuilder`, `instructionBanner`, `typeGradientKey`, `accentHeight`, `backgroundColor`. ⚠️ Le relais alimente la carte que le host monte **déjà** — il ne passe jamais par `cardBuilder`, ce qui préserverait le câblage `revealController: slot.isFront ? … : null` (`:942`) |
| **D5** | `zcrud_study` (après D4) | `ZStudySessionScaffold` : les **10 seams perdus** (`cardSlotBuilder`, `onQualitySelected`, `qualityColorKeyFor`, `qualityPreviewLabelFor`, `qualityLabelKeyFor`, `qualityEmphasis`, `revealPolicy`, `postSubmitPolicy`, `questionRecall`, `bottomInset`) |
| **D6** | racine (`docs/`) | `docs/site/guides/cookbook.md:592-608` documente `zcrud.fieldType.*` et `zcrud.fieldAccent.*` mais **jamais** `flashcard.type.*` — un hôte qui suit le guide produit la mauvaise clé. Documenter aussi le piège `colorKey`, qui **désactive silencieusement** le seam (`z_default_flashcard_card.dart:430`) |

**Rupture** : nulle pour un hôte répondant au format nu (sa branche est conservée, en
dernier). Le **seul** cas de bascule est un hôte répondant aux **deux** formats avec des
valeurs différentes — le préfixé l'emporterait. À annoncer, avec l'échappatoire
`typeGradientKey` qui court-circuite toute la chaîne.

D1-D2-D3 ∥ rien (même paquet, même rédacteur, séquentiels). D4 → D5. D6 indépendant.

## 4. Vague 2 — le preset et les cinq formes

**Forme retenue : objet de configuration immuable interprété par le host**, dans
`packages/zcrud_study/lib/src/presentation/preset/` (3 fichiers). Rejetée : une fabrique
remplissant des slots — rien n'empêcherait l'hôte de n'en poser que la moitié, c'est-à-dire
l'erreur même qu'on supprime. Rejeté aussi : un `copyWith` sur le host (40 champs, seconde
API de construction, opt-in non prouvable).

```dart
class ZStudySessionPreset {
  const ZStudySessionPreset({this.header, this.cardChrome, this.progressStyle,
                             this.cardBackgroundColorKey});
  const ZStudySessionPreset.classic({...});
  final ZSessionHeaderSpec Function(ZStudySessionProgress)? header;
  final ZCardChromeSpec Function(ZFlashcard)? cardChrome;
  final ZSessionProgressStyle? progressStyle;
  final String? cardBackgroundColorKey;   // CLÉ, jamais une Color (FR-26)
}
```

Résolution : `widget.headerBuilder ?? _presetHeaderBuilder` — un slot explicite gagne
toujours ; `preset: null` ⇒ aucune branche prise, **arbre identique à l'octet**.

| Lot | Paquet | Contenu |
|---|---|---|
| **P1** | `zcrud_session` | `ZSessionProgressStyle.pill` + sa branche. Couleurs par `zResolveColorKeyOrSlot`, **jamais** `scheme.error`. 🚫 Ne pas réutiliser `ZCountBadge` (`z_count_badge.dart:173` code `scheme.error` en dur, compte des notifications, pas une position) |
| **P2** | `zcrud_session` (avec P1) | **Mesure de fidélité** des styles `dots`/`segmentedBar`/`pill` contre le rendu du legacy. Si l'écart est visible à l'écran, adopter `dots_indicator` / `segmented_progress_bar` **derrière l'API existante** ; sinon garder la brique maison et l'écrire. Aucune ligne de `pubspec` avant ce constat |
| **P3** | `zcrud_study` (après P1) | `preset/` : `ZStudySessionPreset`, `ZSessionHeaderSpec`, `ZCardChromeSpec` ; champ `preset` sur host **et** view ; `_ZSessionHeaderRow` (**seul widget neuf**, ~60 l — `grep -rln "SessionHeader"` ne rend que des typedefs) |
| **P4** | `zcrud_themes` (après D2) | Évaluer si `ZClassicTheme` pose `accentBarHeight`. ⚠️ **Mesurer d'abord** : le poser repeindrait `ZFolderCardGradientAccent` et `z_field_widget.dart:613` chez tout hôte du thème |

⚠️ **Deux corrections à l'esquisse de la CR, mesurées** : `ZStudySessionProgress` porte
`total`/`reviewed`/`remaining`/`lapses`/`index`, et **`remaining + reviewed ≠ total` en SRS
par conception** (`z_study_session_slices.dart:96-103`) — le libellé « 0/30 » est donc une
**valeur de l'hôte**, le preset ne choisit jamais la formule à sa place. Et `ZStreakBadge`
exige un `ZStudyStreak` (`z_streak_badge.dart:31,45`), pas un pourcentage.

## 5. Vague 3 — le montage énuméré

Mécanisme : **`required` sur un champ de type nullable**. Dart oblige à écrire
`hintPort: null` — l'omission devient une **erreur de compilation**, la décision une ligne
greppable. **AD-4 intact** : la valeur `null` signifie toujours ABSENT ; seule sa
*nomination* devient obligatoire. Coût d'un hôte passif : **rigoureusement nul** (aucun
paramètre requis ajouté, aucun défaut changé, `assert` élidé en release).

| Lot | Paquet | Contenu |
|---|---|---|
| **W1** | `zcrud_study` | `ZStudySessionWiring` (19 seams, tous `required` et nullables) + `ZStudySessionHost.wired` — **constructeur de transfert** : il alimente les champs `final` existants, donc **zéro** modification des 31 sites de lecture |
| **W2** | `zcrud_study` (après W1) | `ZStudySessionScaffold.wired` — referme au passage les 10 seams de D5 |
| **W3** | `zcrud_study` (après W1) | `ZStudySeam`, `ZStudySeamReport`, `auditSeams()` (pure, sans `BuildContext`), `ZStudySeamAuditPolicy(waived:)`, diagnostic debug via `FlutterError.reportError` — **jamais de `throw`** (AD-10), patron `z_chat_seam_failure.dart:49` |
| **W4** | `zcrud_study` (après W2) | Démos migrées en `.wired` + section README « montage complet » |

**Oubli vs décision** — trois régimes, tous **déclarés**, jamais devinés : `.wired` ⇒ la
décision est le `null` écrit ; montage à plat + `waived: {…}` ⇒ la décision est l'entrée
nominative ; montage à plat sans rien ⇒ **silence total**, comme aujourd'hui. C'est la
culture d'exemption nominative du dépôt, transposée du côté auteur de gardes vers le côté
auteur d'hôtes.

⚠️ **Prix à écrire noir sur blanc** : ajouter un 20ᵉ seam à `ZStudySessionWiring` sera
**cassant** pour ses utilisateurs. C'est l'intérêt du mécanisme autant que son coût ; sans
cette mention, la première évolution le contournera par un défaut `= null`, ce qu'une garde
doit refuser.

## 6. Gardes (R3 sur chacune : rouge par assertion, restauration par copie, sha, grep négatif)

- **Inertie absolue** partout : `preset: null` / montage à plat ⇒ arbre **et couleur peinte**
  identiques, égalité STRICTE, jamais `<=` ni `contains`.
- **D1, deux sens** : résolveur répondant **uniquement** au format préfixé ⇒ liseré peint ;
  puis **uniquement** au format nu ⇒ liseré peint (l'échappatoire tient) ; puis jeton seul,
  sans résolveur ⇒ liseré peint.
- **D2** : `accentHeight: null` + jeton `null` ⇒ `findsNothing` ; jeton seul ⇒ peint ;
  paramètre + jeton ⇒ le **paramètre** gagne.
- **P3** : `streak: null` ⇒ badge absent ; fourni ⇒ présent, `Semantics.value` correct,
  hauteur ≥ 48 dp (AD-13). Compteur de builds : faire varier `progress` ne reconstruit que
  l'en-tête, la pile reste à `buildCount` constant (AD-2).
- **W1** : garde de source lisant le host sur disque, partitionnant les paramètres nullables
  **par leur TYPE** (allowlist cosmétique : `double? int? EdgeInsetsGeometry? TextStyle?
  Color?`) et exigeant que le reste soit **exactement** l'ensemble des champs du wiring. Un
  20ᵉ seam ajouté demain sans être câblé ⇒ **ROUGE**. Contre-preuve de non-vacuité
  obligatoire (un `ZSomePort?` synthétique doit être signalé ; un `double?` ne doit pas).
- **W3** : `waived` citant un seam **fourni** ⇒ rouge (patron « exemption inutile »).
  `seamAudit` non fourni ⇒ **zéro** appel à `reportError` ; fourni et incomplet ⇒ exactement
  un rapport, **et la session s'affiche quand même** (AD-10).
- **FR-26 / anti-peau** : garde de source sur `preset/` — aucun `Colors.`, aucun libellé
  affichable, aucun nom d'application hôte.

## 7. Vérification

`flutter test --no-pub` **depuis le dossier** de chaque paquet touché ; `melos run generate`
(0 `.g.dart`) → `analyze` repo-wide → `verify` → balayage des **42** (`zcrud_generator` rouge
environnemental attendu) ; handoff par vague, distinguant hôte passif et hôte ayant compensé,
chaque conseil de retrait accompagné du test qui doit rougir chez l'hôte.

## 8. Risques

| Risque | Parade |
|---|---|
| La bascule de clé casse un hôte répondant aux deux formats | Format nu conservé **en dernier** ; échappatoire `typeGradientKey` ; annoncé au handoff |
| `accentBarHeight` posé par le thème repeint deux surfaces non demandées | P4 **différé**, mesure pump-and-compare obligatoire avant |
| Le preset devient la peau d'un hôte nommé | « classic » = direction de design ; garde de source anti-nom d'hôte |
| Une dépendance tierce double une brique maison | P2 : écart visuel **constaté** avant tout ajout ; le tiers entre derrière l'API, jamais à côté |
| `.wired` alourdit un petit hôte (19 lignes pour 3 seams utiles) | Pas de `copyWith` en W1 (il rouvrirait le trou du silence) ; mesurer la plainte réelle avant d'en ajouter un |
| `zcrud_study` déjà goulot | Tout confiné dans `preset/` et `z_study_session_wiring.dart` ; aucune ligne ajoutée aux gros fichiers hors relais |

---

