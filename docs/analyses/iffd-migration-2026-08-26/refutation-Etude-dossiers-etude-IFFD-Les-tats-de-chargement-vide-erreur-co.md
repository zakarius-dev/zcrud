# Réfutation — Étude / dossiers d'étude (IFFD)

> Domaine attaqué : **Étude — dossiers d'étude (IFFD)** : `lib/src/presentation/features/folders/**`
> (36 f. / 18 333 l), `features/documents/**` (12 f. / 6 420 l), 6 modèles de dossier (1 310 l),
> sécurité/ACL (8 f. / 1 582 l), 6 adaptateurs `z_backed_*` (4 648 l).
> Hôte à `65d1af9` (`feat/migration-zcrud`), socle à `cc276c154` (v3.21.0).
>
> *(nom de fichier tronqué : le nom demandé dépassait la limite de 255 octets du système de
> fichiers — les accents sont multi-octets — et contenait des `/`.)*

**Besoin attaqué** : les états de chargement / vide / erreur —
`core/widgets/loading_indicators.dart` (100 l : `WrapInProgressIndication`:4,
`FlashcardGenerationIndicator`:44) + `folders/widgets/empty_folder_content.dart` (183 l) ;
15 `CircularProgressIndicator` dans le domaine.

**Affirmation** : « le socle sait déjà le faire, par `ZContentStateView({state, successBuilder, idle,
loading, empty, error})` + `ZEmptyState` + `ZLoadingState` + `ZErrorState` + `ZContentState` ».
**Gain annoncé : ~283 lignes d'hôte supprimées.**

Hôte `/home/zakarius/DEV/iffd` @ `65d1af9` — vérifié. Socle `/home/zakarius/DEV/zcrud` @ `cc276c154` — vérifié.

---

## VERDICT : **DÉMENTIE**

Le canal existe, il est décrit avec exactitude, il est atteignable. **Mais il ne couvre pas le besoin
réel de l'hôte**, et le gain annoncé est faux d'un facteur ≈ 8. Les deux fichiers dont la suppression
compose les 283 lignes (100 + 183 = 283) sont **tous les deux non supprimables**, pour des raisons
indépendantes l'une de l'autre.

---

## 1. Ce qui RÉSISTE (à porter au crédit de l'affirmation)

Tout le volet « socle » est exact **à la ligne près**. Rien à redire.

| Affirmé | Mesuré | |
|---|---|---|
| `z_state_widgets.dart:180` `ZContentStateView` | `class ZContentStateView extends StatelessWidget` **l.180** | ✅ |
| `:31 ZEmptyState` | **l.31** | ✅ |
| `:75 ZLoadingState` | **l.75** | ✅ |
| `:127 ZErrorState` | **l.127** | ✅ |
| `domain/z_content_state.dart:13` | `enum ZContentState` **l.13**, 5 membres | ✅ |
| `switch(state)` exhaustif **sans `default`** | l.215-226, 5 `case`, **aucun `default`** | ✅ |
| `loading ⇒ const ZLoadingState()` | l.219 `return loading ?? const ZLoadingState();` | ✅ |
| `idle/empty/error ⇒ SizedBox.shrink()` | l.217, 221, 223 | ✅ |
| jamais de `throw` (AD-10) | corps lu intégralement (311 l), 0 `throw` | ✅ |
| couleurs dérivées du `ColorScheme` | l.61 `onSurfaceVariant`, l.156-157 `ZcrudTheme…errorColor ?? colorScheme.error` | ✅ |
| `Semantics`, ≥ 48 dp | l.104 `Semantics(liveRegion:)`, l.20-22 `minimumSize: Size(48,48)` | ✅ |
| exporté par le barrel | `zcrud_ui_kit.dart:145` (domain) + **`:157`** (presentation) | ✅ |
| `zcrud_ui_kit` déclaré `pubspec.yaml:440` | `ref: v3.21.0`, `path: packages/zcrud_ui_kit` | ✅ |
| grep négatif hôte = 0 | `grep -rn -w -e ZContentStateView -e ZEmptyState -e ZLoadingState -e ZErrorState -e ZContentState lib/ \| wc -l` → **0** | ✅ |

**Une objection que j'ai testée et qui NE tient PAS** — je la consigne pour qu'on ne la ressorte pas :
`ZLoadingState` l.89-92 replie son libellé a11y sur la chaîne **anglaise** `'Loading…'`. Ce repli
n'est jamais atteint chez IFFD : `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart:230`
porte `'loading': 'Chargement…'` et `iffd/lib/main.dart:312` monte `ZcrudLocalizationsDelegate()`.
Le libellé sort **en français**. Pas de défaut ici.

**Imprécision mineure, non disqualifiante** : le chemin cité `core/widgets/loading_indicators.dart`
est en réalité `lib/src/presentation/core/widgets/loading_indicators.dart` (et non `lib/src/core/`).
Les ancres `:4` et `:44` sont exactes.

---

## 2. RÉFUTATION 1 — `loading_indicators.dart` (100 l) est **INSUPPRIMABLE** : aucune de ses deux classes n'a d'équivalent au socle

Les 100 lignes ne sont pas « des états de chargement ». Ce sont **deux widgets de tout autre nature**.

### 2.a `FlashcardGenerationIndicator` (l.44-100, 57 l) — ce n'est PAS un état de chargement

Corps lu (l.57-99) : il construit un `MovieTween` de **7 segments** de `ColorTween`
(bleu→rouge→jaune→orange→brun→teal→vert→bleu, 300 ms chacun) et le joue **en boucle** via
`LoopAnimationBuilder` (`package:simple_animations`). Puis, selon `colorAnimation` :

* `true` → il **passe la couleur animée** au `builder(Color?)` de l'appelant ;
* `false` → il enveloppe l'enfant d'un `Container` à `BoxShadow` **pulsante** (`blurRadius: 5`,
  `borderRadius: 12`).

C'est un **halo animé paramétré par un `builder(Color?)`**. Le socle n'a **rien** de cette forme :

```
grep -rn "class ZBusy\|class ZOverlay\|class ZProgressOverlay\|class ZLoadingOverlay" packages/*/lib/
→ RC=1, AUCUNE sortie
```

`ZLoadingState` (l.75-119) rend `Center(Padding(24, Column([CircularProgressIndicator(), texte?])))`.
Aucune animation de couleur, aucun `builder(Color?)`, aucune ombre portée, aucune boucle. Le
recouvrement fonctionnel est **nul**.

**Et il est utilisé partout** : **35 sites d'appel vivants** dans `lib/` (hors commentaires), sur
**16 fichiers** — dont 9 dans `ai_assistant/screens/chatbot_conversation_screen.dart`, 4 dans
`explain_ai_page.dart`, 4 dans `ai_experts_dialogs.dart`, 3 dans `folder_study_tools_page.dart`,
2 dans `folders_page.dart`. Il déborde très largement le domaine Étude.

### 2.b `WrapInProgressIndication` (l.4-42, 39 l) — sémantique **overlay**, absente du socle

Corps lu (l.19-30) :
`Stack([ Opacity(opacity: isLoading ? 0.5 : 1, child: child), if (isLoading) Center(CircularProgressIndicator()) ])`.
Le contenu **reste monté et visible**, atténué à 50 %, avec un spinner **par-dessus**.

`ZContentStateView` fait l'exact contraire : à `loading` il **retourne** la tranche de chargement
**à la place** de `successBuilder` (l.219) — le contenu est **démonté**. `ZLoadingState` est un
`Center`, pas un `Stack` de recouvrement. Aucun paramètre d'opacité, aucun mode overlay.

**5 sites d'appel vivants** : `first_folder_widget.dart:40`, `ai_flashcards_generator_dialog_widget.dart:162`,
`folder_content_add_dialog_widget.dart:113`, `folder_tags_selection_dialog_widget.dart:78`,
`content_hub_zcrud.dart:442`.

### 2.c Un filet de caractérisation FIGE le comportement actuel

`test/characterization/screens/loading_indicators_widget_test.dart` porte **15 `testWidgets`**
(compté) qui assertent la géométrie exacte : `expect(find.byType(Container), findsNothing)` au repos,
`decoration.boxShadow` de longueur 1, `blurRadius == 5`, `borderRadius == 12`, `received == Colors.purple`.
`test/characterization/screens/README_BLOCAGES.md:106-107` documente en outre deux anomalies connues
et **délibérément figées** (D : `overlay`/`color` ignorés, enfant resté cliquable ⇒ double-soumission
possible ; E : `MovieTween` réalloué à chaque build). Migrer vers `ZLoadingState` ferait **rougir ces
15 tests** sans qu'aucun ne soit remplacé par un équivalent socle.

> **Conclusion 2** : les **100 lignes** de `loading_indicators.dart` ne sont pas supprimables.
> Zéro ligne migrable vers les 5 symboles cités. **−100 sur le gain annoncé.**

---

## 3. RÉFUTATION 2 — `empty_folder_content.dart` (183 l) : `ZEmptyState` n'en absorbe qu'un squelette, au prix de régressions visuelles

`ZEmptyState` a **exactement 5 paramètres** (l.33-40) : `message` (requis), `icon`, `title`,
`actionLabel`, `onAction`. **Aucun slot `child`**, **aucune liste d'actions**, **une seule** CTA,
rendue en `TextButton` (l.300).

Le widget hôte (l.44-183) est d'une tout autre densité :

| Ce que fait l'hôte | Ligne(s) | `ZEmptyState` le fait ? |
|---|---|---|
| **13 champs** de constructeur (`userId`, `subject`, `folder`, `parentFolder`, `contentType`, `onAdd`, `onFileSelected`, `onFilesScanned`, `loadingCallback`, `readOnly`, `subjectToolPage`, `permissions`, `aiRouter`) | 45-73 | ❌ hors périmètre |
| `enum FolderContentType` — 4 membres × (icône, titre, description, libellé de bouton) | 16-42 (27 l) | ❌ aucun registre équivalent |
| **Deux branches** de rendu selon `contentType == null` | 78 / 138 | ❌ un seul rendu |
| `FaIcon(FontAwesomeIcons.folderOpen, size: **200**)` | 86-89 | ❌ `_ZStateScaffold:267` code **`size: 48` EN DUR** — aucun paramètre de taille |
| `ElevatedButton.icon(label, icon: Icon(Icons.add))` | 109-130 | ❌ `TextButton` sans icône |
| `ResponsiveBuilder` → calcule `bottomSheet`/`dialog` par point de rupture | 106-108 | ❌ |
| `showFolderContentAddDialog(...)` à **11 arguments** | 113-126 | ❌ |
| `DottedBorder(RoundedRectDottedBorderOptions(dashPattern:[20,10,20,10], strokeWidth:6, radius:20))` | 138-145 | ❌ aucun cadre |
| `ListTile(leading/title/subtitle)` — mise en page **start-alignée** | 148-152 | ❌ `_ZStateScaffold` est un `Center`+`Column` **centré** |
| **Deux** `FolderDocumentSelector` (import + scan), chacun lisant `ProviderScope.containerOf(context).read(foldersRepositoryProvider)` | 154-172 | ❌ pas de slot enfant |
| Garde de permission `permissions?.can(Crud.create, "FolderDocument")` | 155 | ❌ |
| `OutlinedButton.icon` conditionnel | 173-178 | ❌ (3ᵉ variante de bouton) |

Au mieux, `ZEmptyState` absorberait le squelette icône + titre + message + 1 CTA de la **branche 1**
— de l'ordre de **15 à 25 lignes** — et encore, en **régressant** l'icône de 200 dp à 48 dp et le
bouton d'`ElevatedButton.icon` à `TextButton`. La **branche 2 (44 l) est intégralement
non-migrable**.

Le widget est par ailleurs consommé à **12 sites** (`folder_study_tools_page.dart` ×9,
`study_tools_zcrud_adapter.dart` ×2, `study_tools_zcrud_view.dart` ×1) avec sa signature à
13 champs : le fichier reste, quoi qu'il arrive.

> **Conclusion 3** : ~20 lignes migrables sur 183, avec régression visuelle. **−160 environ.**

---

## 4. RÉFUTATION 3 — les « 15 `CircularProgressIndicator` » : le compte est juste, la conclusion ne l'est pas

Le chiffre **15** est exact (mesuré sur `features/folders/` + `features/documents/`, aucun en
commentaire). Mais le contexte des 15 a été lu : **7 d'entre eux ne sont pas des états de contenu**.
Ce sont des **spinners de chrome**, dimensionnés et colorés, incrustés dans un bouton ou un `suffixIcon`.

| Fichier:ligne | Forme réelle | `ZLoadingState` convient ? |
|---|---|---|
| `folder_content_creating_buttons.dart:105` | `SizedBox(24×24, strokeWidth: 2.5, color: primary)` en `icon:` de bouton | ❌ |
| `folder_content_creating_buttons.dart:151` | idem | ❌ |
| `folder_tags_management_dialog.dart:180` | `SizedBox(20×20, strokeWidth: 2)` remplaçant un `IconButton` | ❌ |
| `folder_tags_management_dialog.dart:241` | `SizedBox(20×20, strokeWidth: 2)` en `suffixIcon:` | ❌ |
| `document_selector_dropdown.dart:268` | `SizedBox(18×18)` **`value: progress`** — progression **DÉTERMINÉE** | ❌❌ |
| `document_selector_dropdown.dart:273` | `SizedBox(18×18, strokeWidth: 2, color: primary)` | ❌ |
| `document_viewer/search_toolbar.dart:161` | `SizedBox(24×24, color: primaryColor)` sous `Visibility` | ❌ |

`ZLoadingState` (l.93-117) construit `Center(Padding(EdgeInsetsDirectional.all(24), Column(...)))`
autour d'un `const CircularProgressIndicator()` **sans aucun paramètre** : ni `size`, ni
`strokeWidth`, ni `color`, ni **`value`**. Le poser en `icon:` d'un bouton rendrait un spinner centré
avec 24 dp de marge — géométrie sans rapport. Et le cas **déterminé**
(`document_selector_dropdown.dart:268`, `value: progress`) est **structurellement inexprimable** :
le socle code l'indicateur en dur, indéterminé.

Restent **8 sites** plein-cadre. Parmi eux, `folder_document_pages_selection_dialog.dart:204` et
`:217` sont des **placeholders de vignette** dans une grille de pages PDF, pas un état de page. Seul
`folder_document_pages_selection_dialog.dart:276` est réellement `ZContentStateView`-shaped
(ternaire `isLoading` / `hasError` / contenu) — et encore, l'hôte devrait d'abord **dériver** un
`ZContentState` depuis ses booléens.

Substituer les 8 sites plein-cadre économise l'ordre de **8 à 20 lignes**, pas 283.

---

## 5. Arithmétique du gain

| Poste | Annoncé | Mesuré |
|---|---|---|
| `loading_indicators.dart` supprimé | 100 l | **0 l** — 35 + 5 sites vivants, 0 équivalent socle, 15 tests de caractérisation |
| `empty_folder_content.dart` supprimé | 183 l | **~20 l**, avec régression icône 200→48 dp et `ElevatedButton`→`TextButton` |
| 15 `CircularProgressIndicator` | (inclus) | **~8-20 l** sur 8 sites ; 7 sites structurellement non-migrables |
| **Total** | **~283 l** | **~30 à 40 l** |

**Le gain annoncé est surestimé d'un facteur ≈ 8.**

---

## 6. Ce qui resterait défendable (affirmation réduite)

Une affirmation **tenable** serait : *« `ZContentStateView` + `ZErrorState` peuvent normaliser les
~8 états de contenu plein-cadre du domaine Étude (~30 lignes), et apportent en prime `Semantics`, la
teinte d'erreur dérivée du `ColorScheme` et l'exhaustivité à froid du `switch`. »* Cela a une vraie
valeur qualitative (a11y, AD-13) — elle ne se chiffre simplement pas en 283 lignes.

Deux manques du socle sont, eux, des **CR candidates**, pas des migrations :

1. **un mode overlay** (contenu atténué + spinner par-dessus) — 5 sites hôte, 0 équivalent socle
   (grep négatif §2.a montré) ;
2. **un spinner paramétrable** (`size`, `strokeWidth`, `color`, **`value`** déterminé) — 7 sites hôte.

`FlashcardGenerationIndicator`, lui, est du **produit IFFD** (halo animé de génération IA) et n'a
aucune vocation à monter au socle.

---

## Méthode — mesures rejouées

Aucun test lancé, aucune écriture hors de ce dossier. Dépôts hôtes ouverts en lecture seule.

```
# socle
git -C /home/zakarius/DEV/zcrud log --oneline -1                        → cc276c154 (v3.21.0)
cat -n packages/zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart  → 311 l, lu intégralement
cat -n packages/zcrud_ui_kit/lib/src/domain/z_content_state.dart        → 28 l, lu intégralement
cat -n packages/zcrud_ui_kit/lib/zcrud_ui_kit.dart                      → exports l.145 et l.157
grep -rn "class ZBusy\|class ZOverlay\|class ZProgressOverlay\|class ZLoadingOverlay" packages/*/lib/
                                                                        → RC=1, 0 ligne
grep -rn "'loading'" packages/zcrud_core/lib/                           → z_localizations.dart:46 (EN), :230 (FR)

# hôte (LECTURE SEULE)
git -C /home/zakarius/DEV/iffd log --oneline -1                         → 65d1af9 (feat/migration-zcrud)
grep -n "zcrud_ui_kit" -A6 pubspec.yaml                                 → l.440, ref v3.21.0
grep -rn -w -e ZContentStateView -e ZEmptyState -e ZLoadingState -e ZErrorState -e ZContentState lib/ | wc -l
                                                                        → 0
grep -rn "['\"]loading['\"]" lib/                                       → RC=1, 0 ligne
wc -l lib/src/presentation/core/widgets/loading_indicators.dart          → 100
wc -l lib/src/presentation/features/folders/widgets/empty_folder_content.dart → 183
grep -rn "FlashcardGenerationIndicator(" lib/ | grep -v "//" | wc -l     → 35
grep -rn "WrapInProgressIndication(" lib/ | grep -v "//"                 → 5 sites (hors définition)
grep -rn "CircularProgressIndicator" features/folders/ features/documents/ | wc -l → 15
grep -c "testWidgets(" test/characterization/screens/loading_indicators_widget_test.dart → 15
grep -rn "EmtyFolderContent" lib/ | awk -F: '{print $1}' | sort | uniq -c → 12 sites / 3 fichiers
```
