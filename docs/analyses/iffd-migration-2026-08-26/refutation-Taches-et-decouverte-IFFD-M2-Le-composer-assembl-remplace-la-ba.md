# Réfutation — M2 « Le composer assemblé remplace la barre de composition de la Découverte »

> ⚠️ **Nom de fichier** : le nom demandé par la tâche fait **380 octets** (limite ext4 : 255) et
> contient **3 `/`** (séparateurs de chemin) — il est littéralement incréable. Nom assaini ici ;
> le nom demandé était
> `refutation-Tâches et découverte (IFFD) — 59 fichiers / 22 778 lignes : tâches quotidiennes (lecture, agrégat révisions+examens), espace de travail lib/workflow (listes de tâches, tâches, agenda, événements, récurrence), et Découverte (recherche + fil IA en flux + TTS/podcast + réglages de génération + corpus documentaire)-M2-Le-composer-assembl-remplace-la-ba.md`.

Domaine : Tâches et découverte (IFFD) — 59 fichiers / 22 778 lignes.
Besoin hôte M2 : sélecteur de routeur, bascule raisonnement, bouton outils à pastille, bouton d'envoi.
Gain annoncé : ~293 lignes d'hôte supprimées.

**VERDICT : DÉMENTIE.** Les canaux existent, sont exportés et atteignables ; mais **deux des quatre
items de M2 (raisonnement, envoi) ne sont pas couverts**, deux des neuf canaux avancés couvrent
**zéro** item, et le gain réel est très inférieur à 293.

---

## 1. Ce qui RÉSISTE — les canaux existent, à la ligne près

Les onze ancres citées ont été relues. **Toutes exactes.**

| Symbole | Fichier:ligne vérifié |
|---|---|
| `ZChatComposer` | `packages/zcrud_chat/lib/src/presentation/view/z_chat_composer.dart:139` |
| `ZDefaultChatComposer` | `.../z_default_chat_composer.dart:63` |
| `ZChatComposerModelSelector` | `.../z_chat_composer_model_selector.dart:119` |
| `ZChatComposerThinkingToggle` | `.../z_chat_composer_band.dart:598` |
| `ZChatComposerWebSearchToggle` | `.../z_chat_composer_band.dart:705` |
| `ZChatComposerToolsTrigger` | `.../z_chat_composer_band.dart:793` |
| `ZChatComposerCountBadge` | `.../z_chat_composer_band.dart:892` |
| `ZChatComposerStopTarget` | `.../z_chat_composer_band.dart:1193` |
| `ZChatComposerSendTarget` | `.../z_chat_composer_chrome.dart:290` |
| `ZChatComposerSubmitPolicy` | `.../z_chat_composer_keys.dart:63` (`enterSubmits`, `desktopAndWebOnly = true` à :76-77) |
| `ZChatMaterialSettingsSheet` / `zChatMaterialSendFab` / `ZChatMaterialToolTile` | `packages/zcrud_chat_material/lib/src/presentation/z_chat_material_settings_sheet.dart:78` / `..._send_fab.dart:32` / `..._tool_tile.dart:52` |

**Atteignabilité prouvée.** 7 lignes d'`export` dans `packages/zcrud_chat/lib/zcrud_chat.dart`
(:163, :172, :173, :174, :175, :176, :225). IFFD déclare `zcrud_chat` **et** `zcrud_chat_material`
(`iffd/pubspec.yaml:455-459` et `:474-478`), épinglés `ref: v3.21.0` ; `pubspec.lock` résout
`cc276c15417919bb2f76b87feb8144724d7d37af`, qui est **exactement** `git rev-parse v3.21.0^{commit}`
et le HEAD du socle. Aucune version manquante.

Le corps du `ThinkingToggle` fait bien ce que la preuve avance : `ValueListenableBuilder<ZChatGenerationSettings>`
sur `controller.settings` (band:635-641), la même tranche que la feuille. Ce point tient.

---

## 2. Ce qui DÉMENT — item par item de M2

### 2.1 Bouton d'envoi (59 lignes annoncées) — NON MIGRABLE en l'état

`ZChatComposerSendTarget` exige `required this.slot` de type `ZChatComposerSlot`
(`z_chat_composer_chrome.dart:292`). Un `ZChatComposerSlot` n'est fabriqué **qu'à un seul endroit** :
`_ZChatComposerState._slot()` (`z_chat_composer.dart:285-292`). Idem pour `zChatMaterialSendFab()`,
qui rend un `ZChatComposerSlotBuilder` (`z_chat_material_send_fab.dart:32-34`) — même dépendance.

Donc l'envoi exige un `ZChatComposer`, qui exige `required this.controller` de type **`ZChatController`**
(`z_chat_composer.dart:161`). Or :

1. **La Découverte n'a pas de `ZChatController`.** `grep -rn "ZChatController" /home/zakarius/DEV/iffd/lib --include='*.dart'`
   rend **13 lignes sur 7 fichiers**, tous dans `ai_assistant/zcrud/**` (Notebook) et
   `features/folders/zcrud/` (Assistant) ; la **seule** occurrence côté Découverte est un
   **commentaire** (`discovry_page_controller.dart:630`). La barre attaquée est pilotée par
   `DiscovryPageController extends Controller` (`discovry_page_controller.dart:194`), 2 412 lignes.
2. **`ZChatController` exige 5 ports obligatoires** — `streamPort`, `actionExecutor`, `confirm`,
   `newRequestId`, `buildRequest` (`z_chat_controller.dart:253-258`). La Découverte n'en implémente aucun.
3. **`ZChatController` POSSÈDE son champ de saisie** : `final TextEditingController composer = TextEditingController();`
   (`z_chat_controller.dart:336`) — non injectable. L'hôte, lui, passe `controller.searchController`
   (`discovry_search_composer.dart:164`), lu sur **17 sites / 3 fichiers** de la Découverte
   (`discovry_search_bar.dart`, `discovry_search_composer.dart`, `discovry_page_controller.dart`).
4. **Le chemin d'envoi ne rentre pas dans `send()`.** `ZChatController.send({settings, corpusScope})`
   (`z_chat_controller.dart:687-690`) n'accepte que deux arguments. L'hôte appelle
   `explainSubject(text, aiRouter:, documentsIds:, userData:, userPresentation:, onFolderExplanation:)`
   (`discovry_search_composer.dart:449-468`), méthode de 11 paramètres
   (`discovry_page_controller.dart:1278-1291`) qui relaie **19 champs de réglage** à
   `aiRepository.generateSubjectExplanation(...)` (`:1293-1319` : `enableWebSearch`, `scrapeWebResults`,
   `enableThinking`, `thinkingEffort`, `maxWebSearchResults`, `maxWebThinkingTokens`, `enableCDNTogo`,
   `enableCDNNiger`, `enableCDCCedeao`, `enableCGITogo`, `enableTecCedeao`, `enableCodeGATT`,
   `niveauIFFD`, `conversationSummary`, `aiExpertId`, `aiExpertRagModel`, `folder`, `parentFolder`,
   `documentsIds`).

⇒ « le composer assemblé remplace la barre » présuppose une migration de **tout le pipeline de
génération de la Découverte** vers les ports du kernel. Ce n'est pas M2, c'est un domaine entier.

### 2.2 Bascule raisonnement (78 lignes annoncées) — COUVERTURE PARTIELLE présentée comme totale

L'hôte n'a **pas** une bascule booléenne. `toggleThinking()` est un **cycle à 6 états**
(`discovry_page_controller.dart:939-947`) :

```dart
void toggleThinking() {
  if (thinkingEffort < 5) { thinkingEffort++; } else { thinkingEffort = 0; }
  enableThinking = thinkingEffort > 0;
  notifyListeners();
}
```

et la puce rouge affiche le **cran** (`discovry_search_composer.dart:295-315` : `controller.thinkingEffort.toString()`).

Le canal du socle fait autre chose, **et le refuse explicitement** :

* il écrit `controller.setRevealThinkingSteps(!active)` — un **flip booléen** (band:668) ;
* son `badgeBuilder` a la signature `Widget? Function(BuildContext, bool active)` (band:624), et son
  dartdoc tranche : « Le badge reçoit `active` — CE que le tap change. Un booléen n'a pas de nombre à
  montrer » (band:659-660) et « jamais d'un champ voisin » (band:621) ;
* l'axe des crans est un **autre** type, `ZChatComputeEffort`, **borné 1..5 sans zéro**
  (`zcrud_chat_kernel/lib/src/domain/ai/z_chat_compute_effort.dart:44-52` : `level < min ? min : …`) —
  et le fichier pose en tête « Les deux axes ne sont jamais fusionnés » (:14). Il est rendu par une
  **pièce séparée**, `ZChatComposerEffortSelector` (band:920).

⇒ migrer donne **deux** affordances (bascule + sélecteur d'effort) là où l'hôte en a **une**, et l'état
« 0 = éteint » de l'hôte n'a pas d'image dans `ZChatComputeEffort`.

**La preuve avancée se contredit elle-même** : le « cycle à badge de cran » cité
(`z_chat_material_tool_tile.dart:52`) n'est **pas** une pièce de la barre. C'est le cas
`ZChatCycleState` d'un `ListTile` de la **feuille d'outils** (`:134-144`), piloté par un
`ZChatToolController`, pas par le composer. Le socle sait faire le cycle — ailleurs que là où M2 le
demande.

### 2.3 Condition cachée — la bascule migrée serait INERTE

`ZChatComposerThinkingToggle` exige `required this.controller` de type **`ZChatSettingsController`**
(band:609). L'hôte peut en instancier un (il le fait déjà :
`assistant_chat_zcrud_mount.dart:111`). Mais rien du chemin d'envoi de la Découverte ne lit un
`ZChatGenerationSettings` : `explainSubject` lit les **champs nus** de `DiscovryPageController`
(`:1305-1319`). Une bascule branchée sur un `ZChatSettingsController` s'allumerait à l'écran et
**n'atteindrait jamais la requête** — sauf miroir écrit à la main vers `DiscovryPageController`,
c'est-à-dire deux détenteurs du même réglage. C'est précisément le défaut que le dartdoc du socle
nomme : « des réglages affichés, réglés, puis jetés avant l'appel » (`z_chat_composer.dart:122-123`).

### 2.4 Deux canaux sur neuf couvrent ZÉRO item de M2

**Grep négatif montré**, sur le fichier hôte entier :

```
$ grep -n "WebSearch\|webSearch\|Internet\|internet\|stop\|Stop\|annul\|cancel" \
    iffd/lib/src/presentation/features/discovery/widgets/discovry_search_composer.dart
$ echo $?
1
```

Aucune occurrence : la barre de la Découverte n'a **ni** bascule internet **ni** bouton d'arrêt.
`ZChatComposerWebSearchToggle` (band:705) et `ZChatComposerStopTarget` (band:1193) — ce dernier
exigeant en plus un `ZChatController` (band:1203) — ne remplacent **aucune ligne** d'hôte.

### 2.5 Sélecteur de routeur (57 lignes) — le seul item réellement couvert, et pas à l'identique

`ZChatComposerModelSelector` est la seule pièce citée qui soit **autonome** : `options`, `onSelect`,
`activeId` (model_selector:123-126), plus `ZcrudScope.maybeOf` (nullable, sûr) et `zChatLabel`, qui
porte un repli (`z_chat_labels.dart:706-707`). `ZChatModelOption` est bien opaque (`:55-81`).

Mais son **déclencheur par défaut** ne rend qu'un `Semantics > GestureDetector > ConstrainedBox >
Align > Row[icon?, Text]` (`:288-321`) : **aucun fond, aucun filet, aucun chevron** —
`grep -n "chevron\|arrow\|Chevron\|Arrow" z_chat_composer_model_selector.dart` → **RC=1, zéro ligne**.
L'hôte, lui, rend une pastille `surfaceContainerHighest` à `BorderRadius.circular(20)` avec
`Icons.auto_awesome` (14 px, teinte `primary`) et `Icons.keyboard_arrow_down`
(`discovry_search_composer.dart:208-242`). Conserver l'aspect impose de fournir `triggerBuilder`,
qui **réécrit** l'essentiel des 35 lignes de décor.

De plus les 57 lignes contiennent la **construction du catalogue** que le socle ne fait pas : filtre
de permission `userPermissions?.aiHasAccessToAiRouter(el.id)`, tri par `workflowEffort.index`
(`:64-69`), repli `defaultIffdModels.first` (`:79-81`), et **double écriture** à la sélection
(`controller.setAiRouterId(...)` **et** `aiRouterConfigProvider.notifier.setRouterId(...)`, `:202-205`).

⚠️ Note d'axe : le libellé affiché par l'hôte est `aiRouter.workflowEffort.displayName` (`:226`) —
or le socle bannit nommément ce symbole (`z_chat_compute_effort.dart:16-18` : « Tout symbole
`*Effort*` ambigu (notamment un `WorkflowEffort` qui mélangerait les deux axes) est donc évité »).
`ZChatModelOption.label` étant du texte d'hôte opaque, ce n'est pas bloquant — mais c'est le signe
que le sélecteur de l'hôte affiche un **axe** et non un **nom de modèle**.

### 2.6 Bouton outils (99 lignes) — le déclencheur ne remplace que son décor

`ZChatComposerToolsTrigger` est autonome (`onOpen`, `badge`, `badgeCount`, `glyph`, `showLabel`,
band:800-836) et `ZChatComposerCountBadge` aussi (band:894-897). Mais sur les 99 lignes de l'hôte
(`:326-424`), la grande majorité est un `StreamBuilder` sur
`aiExpertRepositoryProvider.streamAll(DataRequest(where: {"isActive": true}))` avec filtrage par
`isAdmin`/`filieresEtCycles` et tri par titre (`:327-346`), plus l'ouverture de `ToolsSheet`
(feuille d'hôte, `:353-361`). Le socle ne remplace **rien** de cela. Et `badgeCount` attend un
`ValueListenable<int>` (band:825) là où l'hôte expose un **getter** `int get toolsCount` agrégeant
10 booléens (`discovry_page_controller.dart:926-937`) sur un `ChangeNotifier` : adaptation à écrire.

---

## 3. Le chiffre de 293

L'arithmétique des spans est exacte (57 + 78 + 99 + 59 = 293) et les bornes sont justes
(fichier hôte : **483 lignes**). Mais :

* `:474-483` (**10 lignes**) sont les **fermetures structurelles** du `Row`/`Column`/`Container`/
  `ListenableBuilder`/`build`/`class` — elles ne disparaissent pas, elles se re-nichent. Le bloc
  « envoi » réel est `:425-473`, soit **49** lignes.
* **~127 lignes** (envoi 49 + raisonnement 78) dépendent d'un `ZChatController` ou d'un cycle que
  le socle refuse de porter dans la barre.
* Sur les 57 du routeur, ~22 sont du catalogue/permissions qui reste chez l'hôte ; sur les 99 des
  outils, ~70 sont le `StreamBuilder` + `ToolsSheet` qui restent chez l'hôte.

**Ordre de grandeur défendable si l'on garde `DiscovryPageController` : ~60-70 lignes, pas 293.**
Le reste exige la migration du pipeline de génération de la Découverte — un lot distinct, non couvert
par M2.

---

## 4. Le « PIÈGE » avancé — il tient, et il est plus large que dit

`ZChatComposerSubmitPolicy` par défaut : `submitKey = enterSubmits`, `desktopAndWebOnly = true`
(`z_chat_composer_keys.dart:64-65, :72-77`). L'hôte tient aujourd'hui **la même convention et il l'a
écrite à la main** : `Ctrl+Enter` insère un saut de ligne, `Enter` seul envoie, le tout **sous garde de
plateforme** `!(android || iOS)` (`discovry_search_composer.dart:116-162`, 47 lignes). Le piège n'est
donc pas la politique — c'est que ce `CallbackShortcuts` pilote `searchController` et `explainSubject`,
deux choses que le socle remplacerait par `ZChatComposerSlot.submit` → `ZChatController.send()`. Le
raccourci n'est migrable qu'avec le pipeline (cf. §2.1). Ces 47 lignes ne sont d'ailleurs **pas**
comptées dans les 293.

---

## 5. Correction à porter au dossier

M2 doit être **redécoupé** :

* **M2a — sélecteur de routeur** : `ZChatComposerModelSelector` + `triggerBuilder` d'hôte. Faisable
  aujourd'hui, sans `ZChatController`. Gain ~25-35 lignes.
* **M2b — bouton outils** : `ZChatComposerToolsTrigger` + `ZChatComposerCountBadge`, avec adaptation
  `int getter → ValueListenable<int>`. Gain ~25-30 lignes.
* **M2c — bascule raisonnement** : **bloqué par conception**. Soit l'hôte accepte deux affordances
  (`ThinkingToggle` + `EffortSelector`) et un axe borné 1..5 sans zéro, soit une CR demande au socle
  une pièce de bande à **cycle et badge de cran** (le socle sait déjà la rendre — dans la feuille,
  `ZChatMaterialToolTile` / `ZChatCycleState`).
* **M2d — bouton d'envoi** : **bloqué** tant que la Découverte n'est pas portée sur `ZChatController`
  (5 ports, `TextEditingController` possédé, `send()` à 2 arguments contre 19 réglages hôte).

Annoncer « le socle sait déjà le faire » sur les quatre items, pour ~293 lignes, n'est pas soutenable.
