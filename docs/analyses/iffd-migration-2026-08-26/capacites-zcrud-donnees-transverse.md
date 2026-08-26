# Capacités du socle zcrud — aire « Données, génération de code, bindings, TRANSVERSE »

**Relevé du 2026-08-26.** Socle mesuré à **v3.21.0** (41 paquets), arbre de travail
`/home/zakarius/DEV/zcrud`, HEAD `cc276c154`. Hôte de référence : IFFD, épinglé sur
`ref: v3.21.0` pour **tous** ses paquets zcrud (`iffd/pubspec.yaml:308,313,318,323,331,343,348,358,370`).

**Convention de chemin** : sauf mention contraire, tout `fichier:ligne` est relatif à
`/home/zakarius/DEV/zcrud/packages/`. Les chemins hôtes sont préfixés `iffd/`.

**Ce que ce document est** : le catalogue des **canaux publics** (type, paramètre, jeton de
thème, seam de scope, entrée de registre, port, fabrique) que le socle offre **aujourd'hui**
dans l'aire ci-dessus. Il sert de référence commune à onze agents de confrontation.

**Ce que ce document n'est pas** : un plan de migration, ni un jugement sur l'hôte. Les
mesures côté IFFD ne servent qu'à qualifier « probablement inconnu de l'hôte ».

---

## 0. Chiffres d'ensemble (mesurés)

| Paquet du périmètre | Version | Fichiers `lib/` | LOC `lib/` | Fichiers de test | Barrel |
|---|---|---|---|---|---|
| `zcrud_core` (porteur du TRANSVERSE) | 3.21.0 | — | — | **280** | `zcrud_core/lib/zcrud_core.dart` (271 l.) |
| `zcrud_firestore` | 3.21.0 | 14 | 5 537 | 28 | `zcrud_firestore/lib/zcrud_firestore.dart` (75 l.) |
| `zcrud_annotations` | 3.21.0 | 7 | 470 | 2 | `zcrud_annotations/lib/zcrud_annotations.dart` (22 l.) |
| `zcrud_generator` | 3.21.0 | 4 | 1 670 | 6 | `zcrud_generator/lib/zcrud_generator.dart` (12 l.) |
| `zcrud_get` | 3.21.0 | 11 | 1 278 | 18 | `zcrud_get/lib/zcrud_get.dart` (48 l.) |
| `zcrud_riverpod` | 3.21.0 | 6 | 370 | 8 | `zcrud_riverpod/lib/zcrud_riverpod.dart` (32 l.) |
| `zcrud_provider` | 3.21.0 | 4 | 190 | 3 | `zcrud_provider/lib/zcrud_provider.dart` (13 l.) |
| `zcrud_intl` | 3.21.0 | 27 | 5 183 | 20 | `zcrud_intl/lib/zcrud_intl.dart` (48 l.) |
| `zcrud_geo` | 3.21.0 | 24 | 7 195 | 23 | `zcrud_geo/lib/zcrud_geo.dart` (35 l.) |
| `zcrud_geo_location` | 3.21.0 | 5 | 272 | 2 | `zcrud_geo_location/lib/zcrud_geo_location.dart` (21 l.) |

Surfaces transverses de `zcrud_core` :

| Surface | Volume mesuré | Fichier |
|---|---|---|
| Seams de `ZcrudScope` | **25** | `zcrud_core/lib/src/presentation/zcrud_scope.dart:110-320` |
| Jetons de `ZcrudTheme` | **220** | `zcrud_core/lib/src/presentation/theme/z_theme.dart:594-2404` |
| Clés de localisation | **123** × **2** locales (`en`, `fr`) | `zcrud_core/lib/src/presentation/l10n/z_localizations.dart:24,209` |
| Types de champ (`EditionFieldType`) | **46** | `zcrud_core/lib/src/domain/edition/edition_field_type.dart:40-212` |
| Points d'entrée publics | 3 (`zcrud_core.dart`, `domain.dart`, `edition.dart`) | `zcrud_core/lib/` |

🔴 **Fait structurant du relevé** : entre `v3.12.0` et `HEAD`, **42 fichiers de `packages/*/lib/`**
ont changé — et **aucun** n'appartient aux neuf paquets de mon périmètre. Le mouvement récent
(3.13 → 3.21) est **entièrement TRANSVERSE** : `zcrud_core` (24 fichiers), `zcrud_markdown` (8),
`zcrud_responsive` (4), `zcrud_select` (4), `zcrud_reorder` (1), `zcrud_screen` (1).

```
$ git diff --name-only v3.12.0..HEAD -- 'packages/*/lib/*' | sed 's|/lib/.*||' | sort | uniq -c
     24 packages/zcrud_core       8 packages/zcrud_markdown       4 packages/zcrud_responsive
      4 packages/zcrud_select     1 packages/zcrud_reorder        1 packages/zcrud_screen
```

Corollaire : `zcrud_firestore`, `zcrud_annotations`, `zcrud_generator`, `zcrud_get`,
`zcrud_riverpod`, `zcrud_provider`, `zcrud_intl`, `zcrud_geo`, `zcrud_geo_location` sont
**gelés depuis v3.0.0** aux corrections documentaires près (mesuré : `zcrud_intl` 9 lignes,
`zcrud_geo` 1 ligne, `zcrud_annotations` 4 lignes, `zcrud_generator` 5 lignes sur
`v3.0.0..HEAD`). Leurs canaux ne sont donc **pas récents** — mais ils restent, pour partie,
**inutilisés par l'hôte** (§ 12).

---

## 1. TRANSVERSE — `ZcrudScope` : les 25 seams d'injection

`ZcrudScope` (`zcrud_core/lib/src/presentation/zcrud_scope.dart:75`) est un `InheritedWidget`
zéro-dépendance portant un **bundle immuable** de seams. Résolution : `ZcrudScope.of` (`:544`,
lève `ZScopeError`) / `ZcrudScope.maybeOf` (`:557`).

| Seam | `fichier:ligne` | Un hôte qui veut… écrit… | Défaut |
|---|---|---|---|
| `resolver` | `zcrud_scope.dart:110` | résoudre ses dépendances applicatives depuis le socle → `ZcrudScope(resolver: monResolver)` | `ZDependencyResolver.throwing` (`z_dependency_resolver.dart:24`) — **lève** `ZScopeError` |
| `acl` | `:117` | ouvrir/fermer les gestes CRUD → `ZcrudScope(acl: MonAcl())` | 🔴 **`ZDenyAllAcl`** (`ports/z_acl.dart:177`) — **fail-closed** : aucun geste offert |
| `labels` | `:120` | surcharger un libellé, ou en fournir un métier → `ZcrudScope(labels: ZcrudLabels({...}))` | `null` → repli sur `ZcrudLocalizations` |
| `theme` | `:123` | poser ses jetons de chrome → `ZcrudScope(theme: ZcrudTheme(...))` | `null` → `Theme.of` (voir § 2) |
| `widgetRegistry` | `:128` | servir un type de champ depuis un satellite/l'app → `ZWidgetRegistry()..register(kind, builder)` | `null` → tout type `registryOrFallback` rend `ZUnsupportedFieldWidget` |
| `subListSeamRegistry` | `:144` | décorer une sous-liste sans `fieldBuilder` de remplacement | `null` |
| `relationSourceRegistry` | `:152` | alimenter un champ `relation` par un flux | `null` |
| `choicesSourceRegistry` | `:160` | calculer les options d'un `select` | `null` |
| `selectChoiceBuilderRegistry` | `:164` | rendre une option riche par clé `const` | `null` → rendu natif |
| `relationCrudRegistry` | `:172` | créer/éditer une entité liée **en ligne** | `null` |
| `filePicker` | `:177` | brancher `image_picker`/`file_picker` | `null` |
| `cloudStorage` | `:183` | brancher un stockage distant de fichiers | `null` |
| `appFileResolver` | `:199` | résoudre une **référence opaque** de fichier vers `AppFile` | `null` |
| `listRenderer` | `:208` | rendre la liste via Syncfusion (`zcrud_list`) | `null` → `ZScopeError` sur la voie dataGrid |
| `reorderRenderer` | `:219` | fournir son châssis de réordonnancement | `null` → repli interne zéro-config |
| `dropRegionRenderer` | `:229` | accepter un dépôt de fichiers de l'OS | `ZNoDropRegionRenderer` |
| `selectPresenter` | `:239` | présenter les sélections en riche (`zcrud_select`) | `null` → rendu natif |
| `iconResolver` | `:246` | mapper une clé d'ornement `String` → `IconData` | `null` |
| `colorPicker` | `:253` | brancher une roue HSV | `null` |
| `colorKeyResolver` | `:272` | résoudre une clé métier → couple `(fond, premier plan)` | `null` |
| `gradientResolver` | `:276` | teinter par clé (dont **teinte par type de champ**) | `null` → aucune teinte |
| `richTextRenderer` | `:286` | rendre du rich-text en lecture | `null` |
| `dateDisplayFormatter` | `:296` | afficher les dates localisées | `null` → **chaîne brute** |
| `numberDisplayFormatter` | `:308` | afficher les nombres localisés | `null` → **chaîne brute** (`'$value'`) |
| `defaultTextConfig` | `:320` | poser un `ZTextConfig` par défaut pour tous les champs texte | `null` (précédence : champ > scope) |

### 1.1 `ZcrudScope.derive` — le canal d'héritage (`:478`)

`ZcrudScope.derive(context, {…})` lit le scope **ambiant** et ne remplace que les seams nommés ;
la sentinelle interne `_zScopeUndefined` (`:46`) distingue « omis » (hérite) de `null` explicite
(remet le seam à son repli). Un hôte qui veut poser une ACL par écran **sans reperdre thème,
registres et canaux de rendu** écrit `ZcrudScope.derive(context, acl: aclDeCetEcran, child: …)`.

> **Mesure hôte** : IFFD compte **28** sites `ZcrudScope(` et **0** site `ZcrudScope.derive`
> (`grep -rn "ZcrudScope.derive" iffd/lib --include="*.dart" | wc -l` → `0`). C'est le canal
> transverse le plus probablement inconnu de l'hôte, et le plus directement actionnable :
> un `ZcrudScope(` imbriqué **masque** son parent, un `derive` le complète.

---

## 2. TRANSVERSE — thème et jetons (`ZcrudTheme`, 220 jetons)

`ZcrudTheme` (`zcrud_core/lib/src/presentation/theme/z_theme.dart:323`) est un
`ThemeExtension<ZcrudTheme>`. Constructeur `const` à `:327`, `copyWith` à `:2561`, `lerp` à `:3113`.

### 2.1 Chaîne de résolution — et sa précédence

`ZcrudTheme.of(context)` (`z_theme.dart:2553`) :

```
ZcrudScope.theme  →  Theme.of(context).extension<ZcrudTheme>()  →  ZcrudTheme.fallback(theme)
```

Deux conséquences qu'un hôte doit connaître :
1. Un `ZcrudTheme` **posé en `ThemeExtension`** dans `ThemeData` agit **sans aucun `ZcrudScope`**.
2. Un `ZcrudScope(theme: …)` posé n'importe où dans l'arbre **prime** sur l'extension de thème et
   la neutralise pour tout ce sous-arbre.

`ZcrudTheme.fallback(ThemeData)` (`:564`) **dérive** tout du `ColorScheme`/`TextTheme` sans aucun
littéral — c'est le seul corps exempté de la garde anti-couleurs (§ 4).

> **Mesure hôte** : IFFD installe `ZcrudTheme.fallback(base)` en extension
> (`iffd/lib/src/config/themes/app_theme.dart:171,259`) **et** pose un `ZcrudScope(theme:)`
> à un site (`iffd/lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart:354`).
> Son fichier de jetons (`iffd/lib/src/presentation/shared/zcrud/z_iffd_form_theme.dart`,
> 281 lignes) pose **~30 jetons distincts** — sur les 220 disponibles.

### 2.2 Familles de jetons (comptées sur `z_theme.dart`)

| Famille | Plage de lignes | Exemples de jetons |
|---|---|---|
| Décoration de champ | `:594-782` | `fieldBorderColor`, `fieldFillColor`, `fieldFocusedBorderColor`, `errorColor`, `onErrorColor`, `labelColor`, `inputRadius`, `inputBorderWidth`, `inputContentPadding`, `inputFilled`, `helperMaxLines`, `floatingLabelWeight`, `labelTextStyle`, `inputTextStyle`, `hintTextStyle` |
| Variante `large` | `:787-803` | `largeMinHeight`, `largePadding`, `largeLabelTextStyle`, `largeLeadingIconSize`, `largeLeadingGap`, `largeLabelGap` |
| Fiche de **lecture** | `:817-900` | `readLayout`, `readCardMargin`, `readPadding`, `readLabelGap`, `readLabelTextStyle`, `readValueTextStyle`, `readFillColor`, `readBorderColor`, `readBorderWidth`, `readCardMinHeight`, `readRowLabelWidth`, `readRowMinWidth` |
| **Sous-listes** (🆕 3.13→3.18) | `:916-1066` | 20 jetons — voir § 11 |
| Ornement / pastille (🆕 3.15) | `:1078-1102` | `adornmentIconBackgroundAlpha`, `adornmentIconBackgroundRadius`, `adornmentIconSize`, `accentBarHeight` |
| Dégradés & cartes | `:1105-1147` | `gradientBegin`, `gradientEnd`, `cardShadowBlurRadius`, `cardShadowOffset`, `cardShadowAlpha`, `cardTintAlpha`, `iconContainerSize`, `iconContainerRadius`, `countPillPadding`, `countPillRadius`, `countPillIconSize`, `celebrationDuration`, `celebrationCurve`, `flipDuration`, `flipCurve` |
| Sous-dossiers / rail | `:1157-1378` | `subfolderTriggerVariant`, `subfolderTriggerFill`, `subfolderTriggerBorder`, `subfolderSelectedEmphasis`, `railItemWidth`, `railPadding`, `studySection*` |
| Cartes d'étude / dossier | `:1391-1573` | `studyCard*` (13), `folderCard*` (11), `flashcardTypeGradients` |
| Séance d'étude / tâches | `:1600-1695` | `studySession*` (6), `dailyTasks*` (7) |
| Hub de contenu | `:1715-1773` | `contentHub*` (12) |
| En-tête de page | `:1809-1835` | `pageHeaderTitleStyle`, `pageHeaderSubtitleStyle`, `pageHeaderTab*` |
| Chat | `:1852-1976` | `chatBubble*`, `chatToolAccentColor`, `chatCapabilityAccents`, `chatBusyPalette`, `chatComposer*` (8), `chatComposerActiveAccent`, `chatResponseLengthAccents`, `chatSelectedEmphasis*` |
| Chrome d'édition | `:2005-2089` | `editionSheetFrameMode`, `editionSheetWidthRatio`, `editionSheetMaxWidth`, `editionSheetBorderColor`, `editionSheetBorderWidth`, `editionChromeMinTouchTarget`, `editionChromeHeaderPadding`, `editionChromeActionBarPadding`, `editionChromePageHeaderExpandedHeight` |
| Tuiles de sélection (🆕 3.20) | `:2157-2275` | `selectTile*` (4), `selectDialogBreakpoint`, `selectMonoChoiceStyle`, `selectMultiChoiceStyle`, `selectModalShape`, `selectSummaryMaxChips`, `selectSummaryChipRadius`, `selectSummaryChipPadding`, `selectSummaryChipFontSize` |
| Stepper | `:2291-2330` | `stepperRailColor`, `stepperRailThickness`, `stepperBadgeForegroundColor`, `stepperAllStepsGap`, `stepperSideBandMaxWidth` |
| Pastille booléenne | `:2352-2404` | `booleanPill*` (9) |

### 2.3 Résolveurs de couleur — les quatre canaux publics

| Canal | `fichier:ligne` | Un hôte qui veut… |
|---|---|---|
| `ZGradientResolver` (typedef) | `theme/z_gradient_resolver.dart:63` | teinter par **clé** → `ZcrudScope(gradientResolver: (scheme, key) => ZGradientSpec(...))` |
| `zFieldTypeTintKey(EditionFieldType)` | `z_gradient_resolver.dart:20` (préfixe `zcrud.fieldType.`, `:10`) | teinter **par type de champ** (bordure de focus, pastille, libellé flottant, barre d'accent) |
| `zFieldAccentKey(String fieldName)` | `z_gradient_resolver.dart:35` (préfixe `zcrud.fieldAccent.`, `:24`) | teinter **un champ nommé**, avec repli sur la teinte de type |
| `ZColorKeyResolver` (typedef) | `theme/z_color_key_resolver.dart:148`, `ZColorPair` `:56` | résoudre une clé métier → couple `(fond, premier plan)` |

Trois points d'entrée pour les **présentateurs riches** (🆕 3.16), qui évitent de redupliquer la
normalisation de contraste :

| Fonction | `fichier:ligne` |
|---|---|
| `zResolveFieldTint(context, field)` | `edition/z_field_adornment_view.dart:206` |
| `zResolveFieldAccent(context, field)` | `:218` |
| `zResolveTintedAdornment(...)` → `ZTintedAdornment` | `:270` (type `:227`) |

Normalisation de contraste — **domicile unique du dépôt** :
`theme/z_readable_tint.dart` — `zReadableTintOn` (`:219`), `zContrastRatio` (`:153`),
`zRelativeLuminance` (`:140`), `zCompositeOver` (`:165`), seuils WCAG 2.2
`kZNonTextMinContrast = 3.0` (`:111`) et `kZTextMinContrast = 4.5` (`:114`).

Trois primitives de chrome, souvent ignorées :
`ZColorCycle` (`theme/z_color_cycle.dart:107`, palette + période **requises**, aucun contrôleur
sous « Réduire les animations »), `ZForegroundOverride` (`theme/z_foreground_override.dart:76`),
`ZInvertedSurface` (`theme/z_inverted_surface.dart:77`).

### 2.4 `ZFieldTintPresets` — des données, jamais un défaut

`domain/edition/z_field_tint_presets.dart:66` — `ZFieldTintPresets.classic` (`:73`), 15 entrées,
couleurs en `int` ARGB (domaine pur). **Le socle ne les lit jamais** :

```
$ grep -rn "ZFieldTintPresets" --include="*.dart" packages/*/lib
packages/zcrud_core/lib/src/domain/edition/z_field_tint_presets.dart:26:  ///     final preset = ZFieldTintPresets.classic[   ← exemple de dartdoc
packages/zcrud_core/lib/src/domain/edition/z_field_tint_presets.dart:66:abstract final class ZFieldTintPresets {
```

Les deux seules occurrences sont **le fichier de déclaration lui-même** (dont une dartdoc).
Aucun site consommateur : un hôte qui veut la palette la **recopie** dans son propre résolveur.

---

## 3. TRANSVERSE — localisation

| Canal | `fichier:ligne` | Un hôte qui veut… | Défaut |
|---|---|---|---|
| `ZcrudLocalizationsDelegate` | `l10n/z_localizations.dart:407` | des libellés CRUD localisés → l'ajouter à `MaterialApp.localizationsDelegates` | tables `en`/`fr` intégrées |
| `ZcrudLocalizationsDelegate.supportedLocales` | `:413` | connaître la couverture | **`en`, `fr` uniquement** |
| `ZcrudLocalizations.of` / `.maybeOf` | `:402` / `:397` | lire une clé | repli table `en` |
| `ZcrudLabels(Map<String,String>)` | `l10n/z_labels.dart:20` | **surcharger** un libellé du socle, ou fournir un libellé **métier par clé** → `ZcrudScope(labels: ZcrudLabels({...}))` | `ZcrudLabels.empty` (`:28`) |
| `label(context, key, {fallback})` | `l10n/z_localizations.dart:449` | résoudre une clé depuis son propre widget | jamais de `throw` |

**Chaîne de résolution** (`:449-457`) :
`ZcrudScope.labels?.maybeResolve` → `ZcrudLocalizations.of` (locale) → **table `en` de repli** →
`fallback` → **clé brute**. `ZcrudLabels` étant une valeur portée par le scope, il n'y a **aucun
singleton mutable** : deux instances résolvent indépendamment (égalité par contenu, `:43-50`).

**Les 123 clés** (`z_localizations.dart:24-208` pour `en`, `:209-366` pour `fr`) :

`save cancel delete restore edit create history date operation author update view add confirm
search required invalidValue invalidPassword loading empty retry list.loading list.empty
list.noResults list.error yes no showPassword hidePassword select selectDate selectTime
selectDateTime selectDateRange selectSummaryOverflow dateRangeTooLong dateRangeTooShort
daysInclusive close back reset clear remove next previous unsupportedField addTag removeTag
selectColor customColor colorHue colorSaturation colorBrightness colorOpacity colorHex
colorRecent colorAddColor removeColor apply percentSuffix currencySuffix rate addItem
removeItem moveItemUp moveItemDown reorderItem clearItem viewItem editItem deleteItem
confirmDeleteItem noItems restoreItem deletedItemBadge signatureArea signatureSigned
signatureEmpty clearSignature undoSignature fileActionScan fileActionCamera fileActionGallery
fileActionPick fileRemove fileRetry fileUploading fileUploadFailed filePreviewAlt
fileMaxReached fileResolving fileRefUnresolved fileResolveFailed fileResolveRetry copy copied
emptyValue z.stepper.previous z.stepper.next z.stepper.finish trash trashCount details
deleteForever confirmDeleteForeverItem accessDenied accessDeniedMessage choiceUnresolved
moreActions actionNotAllowed actionNotApplicable export exportEmpty exportFailed selectedCount
selectAll batchSucceeded batchFailed batchSkipped z.markdown.write z.markdown.edit
z.markdown.commit z.markdown.expand`

> **Mesure hôte** : IFFD monte bien le delegate (`iffd/lib/main.dart:45,312`) mais n'utilise
> **jamais** `ZcrudLabels` :
> ```
> $ grep -rn "ZcrudLabels" iffd/lib --include="*.dart" ; echo "RC=$?"
> RC=1
> ```
> Le canal de surcharge de libellé — le seul moyen de renommer un libellé du socle sans
> patcher le socle — est donc entièrement inexploité.

---

## 4. TRANSVERSE — accessibilité et RTL

Ce ne sont pas des canaux paramétrables mais des **garanties du socle**, à connaître pour ne pas
les compenser deux fois.

| Garantie | Preuve sur disque | Portée |
|---|---|---|
| Aucune couleur codée en dur, variantes **directionnelles** obligatoires | `zcrud_core/test/purity/style_purity_test.dart` — motifs `:25-32` (couleurs) et `:41-49` (`EdgeInsets.only(left/right`, `EdgeInsets.fromLTRB`, `Alignment.centerLeft/…`, `TextAlign.left/right`, `Positioned(left/right`, `BorderRadius.only`, `BorderRadius.horizontal`) | balaie `zcrud_core/lib/src/presentation/**` ; **seule exemption** : le corps de `ZcrudTheme.fallback`, borné par comptage d'accolades |
| Rendu RTL de référence | `zcrud_core/test/presentation/rtl_reference_test.dart` | — |
| RTL par champ / fichier / stepper | `zcrud_core/test/presentation/edition/field_rtl_test.dart`, `file_field_a11y_rtl_test.dart`, `stepper_a11y_rtl_test.dart` | — |
| A11y du catalogue de champs | `zcrud_core/test/presentation/edition/catalogue_a11y_test.dart`, `field_a11y_test.dart` | — |
| Planchers tactiles **non réglables** | `zcrud_core/CHANGELOG.md:45` (marge du glyphe de poignée ≥ 12 dp, 14 dp si `subListDragHandleSize: 20`), `:65` (jeu de 14 dp sous une ligne réordonnable) | sous-listes |
| Cible tactile paramétrable | jeton `editionChromeMinTouchTarget` (`z_theme.dart:2066`) | chrome d'édition |
| Octets de contrôle bruts interdits dans toute source Dart | `zcrud_core/test/z_source_control_bytes_guard_test.dart` (livré en 3.6.0) | dépôt entier |

⚠️ **Piège d'accessibilité connu** : `subListRowHorizontalPadding` (§ 11) gouverne aussi
l'en-tête de colonnes **et** le seuil d'empilement du résumé compact — le réduire peut faire
redevenir tabulaire un résumé jusqu'ici empilé (`zcrud_core/CHANGELOG.md:44`).

---

## 5. TRANSVERSE — hors-ligne et synchronisation (contrats du cœur)

Toute cette surface est **pur-Dart**, atteignable par `package:zcrud_core/domain.dart`
(`zcrud_core/lib/domain.dart:141-152`) sans tirer Flutter.

| Canal | `fichier:ligne` (sous `zcrud_core/lib/src/domain/`) | Un hôte qui veut… |
|---|---|---|
| `ZSyncMeta` | `sync/z_sync_meta.dart:20` | lire/écrire les métadonnées **hors-entité** |
| `ZSyncMeta.kUpdatedAt` / `kIsDeleted` | `:27` / `:31` | ne pas coder `'updated_at'` / `'is_deleted'` en dur |
| `ZSyncMeta.reservedKeys` | `:44` | **consommer** l'ensemble réservé dans son propre `_reservedKeys` (gate AD-19.1) |
| `ZSyncMeta.stripReserved(map)` | `:52` | retirer les clés réservées d'une map |
| `ZSyncMeta.collidingReservedKeys(map)` | `:90` | **détecter** une collision au lieu de la subir |
| `ZLwwResolver` / `ZLwwDecision` / `ZLwwAction` | `sync/z_lww_resolver.dart:87` / `:29` / `:16` | arbitrer local ⇄ distant en Last-Write-Wins |
| `ZSyncEntry<T>` | `sync/z_sync_entry.dart:26` | apparier entité + méta |
| `ZSyncOrchestrator` | `sync/z_sync_orchestrator.dart:117` | orchestrer la poussée (débounce, `isConnected`, `syncNow` `:258`, `flushPending` `:273`) |
| `ZSyncRunReport` | `sync/z_sync_run_report.dart:25` | lire `attempted`/`succeeded`/`failed`/`failures` |
| `ZClock` (typedef) | `sync/z_clock.dart:31` | **injecter la source de temps** de la clé LWW → atténuer le décalage d'horloge entre appareils |
| `ZSystemClock.utc` / `.fixed` / `.offset` | `:36` / `:40` / `:48` | horloge système, figée (tests), ou décalée |
| `ZSyncableRepository<T>` | `ports/z_syncable_repository.dart` | déclarer un dépôt synchronisable |
| `ZLocalStore<T>` / `ZRemoteStore<T>` | `ports/z_local_store.dart` / `ports/z_remote_store.dart` | fournir ses propres stores |

> **Mesure hôte** : `ZSyncMeta` est massivement utilisé (**84** sites dans `iffd/lib`), mais
> `ZSyncOrchestrator` et `ZClock` comptent **0** site chacun.

---

## 6. TRANSVERSE — granularité des reconstructions (objectif produit n°1)

| Canal | `fichier:ligne` (sous `zcrud_core/lib/src/presentation/`) | Ce qu'il garantit |
|---|---|---|
| `ZFormController` | `z_form_controller.dart:33` | `ChangeNotifier` pur-Flutter ; **une `ValueNotifier` par champ** (`:78`) |
| `.fieldListenable(name)` | `:123` | la tranche d'**un seul** champ — c'est la primitive de granularité |
| `.valueOf(name)` / `.setValue(name, v, {derived})` | `:129` / `:243` | lire/écrire une tranche sans toucher les autres |
| `.seedDefaultValue(name, v)` | `:150` | amorcer une tranche absente d'`initialValues` |
| `.baselineValueOf(name)` / `.isTouched(name)` | `:169` / `:183` | comparer au point de départ, savoir si l'utilisateur a touché |
| `.isDirty` (`ValueListenable<bool>`) | `:278` | armer une garde de sortie sur **une** tranche booléenne |
| `.reveal` / `.revealErrors()` | `:282` / `:290` | révéler les erreurs sans reconstruire le formulaire |
| `.reseedRevision` / `.reseed(values)` | `:286` / `:332` | recharger des valeurs et le signaler **structurellement** |
| `.markPristine()` / `.reset()` | `:296` / `:314` | rebaser / revenir au départ |
| `.visibleFields` / `.setVisibleFields(names)` | `:348` / `:355` | piloter la visibilité conditionnelle (single-writer) |
| `.recordRemovedFile(name, entry)` / `.removedFiles` | `:207` / `:225` | collecter les fichiers retirés pour un nettoyage post-soumission |
| `ZFieldListenableBuilder` | `z_field_listenable_builder.dart:21` | **sceller un widget sur une seule tranche** — 49 lignes, c'est tout le patron |
| `DynamicEdition` | `edition/dynamic_edition.dart:296` | formulaire de référence : `ListView.builder`, `KeyedSubtree` par champ, écoute **structurelle** seule |
| `DynamicEdition.onStructuralBuild` | `:497` | **observer** les reconstructions structurelles (canal de mesure pour un hôte qui veut prouver SM-1 chez lui) |
| `ZDisplayState` | `state/z_display_state.dart` | patron « état détenu par le composant, pilotable par l'hôte » |

`DynamicEdition` expose 21 paramètres publics (`:324-497`), dont `sections` (`:344`),
`fieldBuilder` (`:360`), `readOnly` (`:374`), `readLayout` (`:386`), `layout`
(`Map<String, ZResponsiveSpan>`, `:390`), `gridGutter`/`gridRunGutter` (`:394`/`:401`),
`conditionContext` (`:413`), `manageVisibility` (`:424`), `acl` (`:438`), `formActions` (`:446`),
`collectionId` (`:451`), `collapseStore` (`:458`), `formId` (`:462`), `interFieldGap` (`:491`), `onStructuralBuild` (`:497`).

---

## 7. Données — ports neutres du cœur

| Canal | `fichier:ligne` (sous `zcrud_core/lib/src/domain/`) | Un hôte qui veut… |
|---|---|---|
| `ZReadOnlyRepository<T>` | `ports/z_repository.dart:58` | un port de **lecture seule** |
| `ZRepository<T>` | `:114` | le port complet : `watchAll` `:125`, `watch` `:134`, `getAll` `:142`, `getById` `:151`, `save` `:179`, `softDelete` `:185`, `restore` `:189`, `count` `:197`, `dispose` `:200` |
| `ZPurgeable<T>` (mixin) | `ports/z_purgeable.dart` | déclarer la suppression **définitive** — capacité **hors** du port |
| `ZDelegatesSearch<T>` (mixin) | `ports/z_search_capability.dart` | **déclarer** qu'un dépôt ne sert pas `ZDataRequest.search` → le listing du socle filtre lui-même |
| `zRepositoryServesSearch(repo)` | `ports/z_search_capability.dart` | interroger cette capacité |
| `ZDataRequest` | `data/z_data_request.dart:286` | requête neutre : `filters` `:308`, `filterGroups` `:321`, `sorts` `:324`, `search` `:327`, `limit` `:330`, `startAfter` (**curseur**) `:333`, `deletedScope` `:338`, `searchScope` `:348`, `searchFolding` `:353` |
| `ZFilter` / `ZFilterOp` / `ZFilterGroup` / `ZSort` | `:104` / `:13` / `:221` / `:251` | composer la requête ; `ZFilter.sourceOnly` (`:153`) marque un filtre que la source seule applique |
| `ZDeletedScope` / `ZSearchScope` / `ZSortDirection` | `:51` / `:69` / `:86` | corbeille, portée de recherche, tri |
| `ZAcl.can(action, {target, collectionId})` | `ports/z_acl.dart:101` | gouverner les gestes ; `ZCrudAction` `:28` |
| `ZAllowAllAcl` / `ZDenyAllAcl` / `ZRestrictedAcl` | `:123` / `:177` / `:210` | ouverture assumée / refus par défaut / **intersection** |
| `ZFailure` et sa hiérarchie | `failures/z_failure.dart:23` | `ZDomainFailure` `:45`, `ZCacheFailure` `:51`, `ZNotFoundFailure` `:57`, `ZServerFailure` `:89`, `ZQuotaExceededFailure` `:109`, `ZUnsupportedOperationFailure` `:169` |
| `ZExtensible` / `ZExtension` / `zSanitizeExtra` | `extension/z_extensible.dart`, `z_extension.dart` | slot d'extension **versionné** + `extra` (AD-4) |
| `zJsonEquals` / `zJsonHash` | `extension/z_json_equality.dart` | égalité/hash **profonds** — implémentation unique du dépôt |
| `zDecodeExtension` | `extension/z_opaque_extension.dart` | préserver **verbatim** un slot `extension` que l'hôte ne sait pas typer |
| `z_json_read.dart` | `json/z_json_read.dart` | primitives de **lecture défensive** partagées (AD-10) |
| `ZcrudRegistry` / `ZTypeRegistry` / `ZSourceRegistry` / `ZCodecRegistry` | `registry/` | registres ouverts d'extensibilité |
| `ZDateDisplayFormatter` | `ports/z_date_display_formatter.dart` | formater les dates → impl `zcrud_intl` (§ 9) |
| `ZNumberDisplayFormatter` | `ports/z_number_display_formatter.dart:43` | formater les nombres → **aucune impl livrée** (§ 13) |
| `ZAppFileResolver` | `ports/z_app_file_resolver.dart` | résoudre une référence de fichier → impl `zcrud_firestore` (§ 8) |
| `ZEntityHistorySource` | `ports/z_entity_history_source.dart` | servir l'historique d'une entité |

---

## 8. `zcrud_firestore` — adaptateurs Firestore + Hive, offline-first

Barrel : `zcrud_firestore/lib/zcrud_firestore.dart` (13 `export`, 14 fichiers, 5 537 LOC).
**Aucun type `cloud_firestore`/`hive` n'est exporté** — l'injection d'une instance
`FirebaseFirestore` ou d'une `Box` est la seule couture (dartdoc `:7-12`).

| Canal | `fichier:ligne` (sous `zcrud_firestore/lib/src/data/`) | Un hôte qui veut… | Défaut |
|---|---|---|---|
| `FirebaseZRepositoryImpl<T>` | `firebase_z_repository_impl.dart:156` (ctor `:159`) | un `ZRepository<T>` Firestore direct | — |
| `.fromRegistry(...)` | `:261` | le câbler sur `ZcrudRegistry` au lieu d'écrire `fromMap`/`toMap` | — |
| ↳ `fromMapSafe` | `:165` | une **voie de décodage défensive** : un document corrompu est écarté + loggé, jamais propagé | `null` → enveloppe locale de `fromMap` |
| ↳ `timestampFields` | `:167` | écrire certaines dates en `Timestamp` natif (alimenté par `$XxxTimestampFields`) | `{}` — **les clés réservées en sont soustraites en release** (`:203-206`) |
| ↳ `omitNullFields` | `:168` | l'équivalent du `compact(true)` legacy : retrait **récursif** des clés nulles avant écriture | `false` |
| ↳ `deletionSemantics` | `:169` | 🔴 lire un **parc legacy** où « absent = vivant » → `ZDeletionSemantics.absentMeansAlive` | **`strict`** : un document **sans** `is_deleted` est **exclu de toutes les lectures** |
| ↳ `legacyDeletedKey` | `:170` | honorer une clé de soft-delete héritée (`'deleted'`…) | `null` ; **n'est honorée qu'en `absentMeansAlive`** (assert `:180-187`) |
| `ZDeletionSemantics` | `:57` (`strict` `:63`, `absentMeansAlive` `:81`) | choisir la sémantique | `strict` |
| `ZFirestoreLog` (typedef) | `:42` | tracer les rejets défensifs | `_noopLog` (`:48`) |
| `HiveZLocalStore<T>` | `hive_z_local_store.dart:68` | un `ZLocalStore<T>` sur une `Box` injectée | — |
| `FirestoreZRemoteStore<T>` | `firestore_z_remote_store.dart:42` | un `ZRemoteStore<T>` fire-and-forget | — |
| `ZOfflineFirstRepository<T>` | `z_offline_first_repository.dart:57` | composer local + distant, merge LWW, `Right(unit)` hors-ligne | — |
| `ZOfflineFirstBoxRepository<T>` | `z_offline_first_box_repository.dart:103` (ctor `:107`) | la base offline-first du gabarit `ZStudyRepository<T>` : merge LWW hors-entité, `hasPendingWrites`, listener temps réel, rattrapage local-only | `autoListen: true`, `clock: ZSystemClock.utc` |
| `ZFirestorePathResolver` | `z_firestore_path_resolver.dart:134` | résoudre `kind → chemin String` depuis une **table littérale** ; entrée neutre, sortie `String` ou `Left(ZDomainFailure)` | — |
| `ZFirestorePathRule.flatTopLevel` | `:75` | collection racine, optionnellement `users/{uid}/…` | `userScoped: false` |
| `ZFirestorePathRule.nestedUnderParent` | `:90` | collection imbriquée sous un parent | `userScoped: true` |
| `ZFirestorePathRule.globalTopLevel` | `:104` | collection globale **hors** de tout scope utilisateur | — |
| `ZFirestoreTopology` | `:44` | l'énumération des trois topologies | — |
| `buildFolderScopedStudyRepository<T>` | `z_folder_scoped_study_repository.dart:114` | un dépôt **folder-scopé** clé en main | `userScoped: true`, `autoListen: true` |
| `buildUserScopedStudyRepository<T>` | `:187` | un dépôt **racine user-scopé** clé en main | `autoListen: true` |
| `ZFirestoreCascadeBatcher` | `z_firestore_cascade_batcher.dart:107` | un soft-delete **en cascade borné** (lots ≤ 450) → `ZResult<ZCascadeReport>` | — |
| `ZCascadeReport` | `:77` | lire le rapport observable de la cascade | — |
| `ZFirestoreAppFileResolver` | `z_firestore_app_file_resolver.dart:280` | résoudre des **références opaques** de fichiers en lot | — |
| `ZAppFileFieldAliases` | `:138` | déclarer les alias de champs de sa collection de fichiers | — |
| `ZAppFileRefLocation` | `:104` | déclarer où vit la référence | — |
| `ZAppFileDocumentMapper` (typedef) | `:227` | mapper soi-même le document → `AppFile?` | — |
| `zChunkAppFileRefs(refs, size)` | `:247` | découper une liste de références (contrainte `whereIn`) | — |
| `ZStudyLegacyCodec` | `z_study_codec.dart:62` | normaliser camelCase ⇄ snake_case, statuts legacy, `ZSyncMeta` additif, dates `int` millis — **normaliseur PUR, jamais `throw`** | — |
| `ZLegacyValueMapper` (typedef) | `:56` | mapper une valeur legacy vers une valeur canonique | — |
| `ZLegacyStudyMigrator` | `z_study_migrator.dart:167` | migrer un corpus flat → canonique : idempotence, recensement de préservation, rapport auditable, **mode simulation** | — |
| `ZDocumentMigrationOutcome` / `ZLegacyMigrationReport` | `:74` / `:120` | lire le résultat par document / le rapport global | — |
| `assembleZStudySyncOrchestrator(...)` | `z_study_sync_orchestrator.dart:54` | câbler un `ZSyncOrchestrator` sur une **liste de dépôts injectée** | — |

> **Mesure hôte** — sites dans `iffd/lib` :
> `ZStudyLegacyCodec` **15**, `ZLegacyStudyMigrator` **8**, `ZSyncMeta` **84** ;
> `FirebaseZRepositoryImpl` **0**, `HiveZLocalStore` **0**, `FirestoreZRemoteStore` **0**,
> `ZOfflineFirstRepository` **0**, `ZFirestoreCascadeBatcher` **0**, `ZFirestorePathRule` **0**,
> `buildFolderScopedStudyRepository` **0**, `buildUserScopedStudyRepository` **0**,
> `assembleZStudySyncOrchestrator` **0**, `ZFirestoreAppFileResolver` **0**,
> `ZDeletionSemantics` **0**, `omitNullFields` **0**, `ZDelegatesSearch` **0**,
> `ZSyncOrchestrator` **0**, `ZClock` **0**.
> Les deux seules mentions de `ZOfflineFirstBoxRepository` et `ZFirestorePathResolver` sont des
> **commentaires** (`iffd/lib/src/data/repositories/z_backed_folder_document_repository.dart:308,309`).

---

## 9. `zcrud_annotations` + `zcrud_generator` — la voie codegen

### 9.1 Les quatre annotations (+ un enum)

| Annotation | `fichier:ligne` (sous `zcrud_annotations/lib/src/domain/annotations/`) | Paramètres |
|---|---|---|
| `@ZcrudModel` | `zcrud_model.dart:151` (ctor `:153`) | `kind` (`:157`), `fieldRename` (`:161`, défaut `ZFieldRename.snake`) |
| `@ZcrudField` | `zcrud_field.dart:52` (ctor `:54`) | **18 paramètres** : `label` `:76`, `type` `:81`, `validators` `:84`, `config` `:87`, `choices` `:90`, `condition` `:94`, `searchable` `:97`, `defaultValue` `:100`, `readOnly` `:103`, `showIfNull` `:110`, `name` `:114`, `multiple` `:117`, `persistAs` `:140`, `leading` `:145`, `prefix` `:148`, `suffix` `:152`, `hintText` `:155`, `helperText` `:158` |
| `@ZcrudId` | `zcrud_id.dart:16` | — |
| `@ZcrudIgnore` | `zcrud_ignore.dart:62` | — (assume l'exclusion d'un champ non sérialisable) |
| `ZPersistAs` | `z_persist_as.dart:16` | `iso8601` / `timestamp` |

### 9.2 Ce que le générateur émet

Point d'entrée `build.yaml` : `package:zcrud_generator/builder.dart` → `zcrudModelBuilder`
(`zcrud_generator/lib/builder.dart:19`), `SharedPartBuilder` `zcrud`,
`auto_apply: dependents` (`zcrud_generator/build.yaml:21`).
Générateur : `zcrud_generator/lib/src/zcrud_model_generator.dart` (1 619 LOC).

| Symbole émis | Ce qu'un hôte y gagne | Documenté à |
|---|---|---|
| `_$XxxFromMap` | reconstruction **défensive** : champ absent → `defaultValue`, enum inconnu → repli (jamais `byName` nu), sous-objet corrompu → n'échoue **jamais** le parent | `zcrud_model_generator.dart:7-10` |
| `extension XxxZcrud on Xxx` → `toMap()` + `copyWith()` | snake_case, enum `.name`, dates ISO-8601, récursion ; `copyWith` **à sentinelle** (reset-`null` distinct de « non fourni ») | `:11-13` (émission `:978`) |
| `$XxxFieldSpecs` (`List<ZFieldSpec>`) | **le formulaire ET la liste dérivés du modèle**, avec inférence de type si `type == null` | `:14-15` |
| `registerXxx(ZcrudRegistry)` | câblage `kind → (fromMap, toMap, fieldSpecs)` | `:16-17` (émission `:1184`, `:1208`) |
| `$XxxTimestampFields` (`const Set<String>`) | la métadonnée que le **repository** applique pour écrire le format natif | `:55-59` (émission `:1237`) |

**Échecs de build explicites** (`InvalidGenerationSourceError`, jamais un cast `null` silencieux) —
`:18-26` : type non (dé)sérialisable, cible non-classe, collision de clé persistée, valeur
d'énumération d'annotation non reconnue, `@ZcrudIgnore` combiné à `@ZcrudField`/`@ZcrudId`,
**champ non annoté de type non sérialisable**, **enum redéclarant `name` comme membre d'instance**.

**Contrat cassant en vigueur** : toute classe `@ZcrudModel` doit déclarer un décodeur **de
domaine** `Xxx.fromMap(Map<String,dynamic>)` (factory *ou* méthode statique) ; une classe
`ZExtensible` doit y **peupler `extra`** et le **ré-émettre** depuis un `toMap()` d'instance.
Trois filets machine, dont un **garde d'exécution** dans `registerXxx` qui exige la survie d'une
clé hors-schéma à l'aller-retour et lève un `StateError` **hors `assert`** (donc en release) —
`zcrud_generator/CHANGELOG.md:154-166`.

> **Mesure hôte** : IFFD n'utilise **pas du tout** la voie codegen.
> ```
> $ grep -rn "@ZcrudModel" iffd/lib --include="*.dart" ; echo "RC=$?"
> RC=1
> $ grep -rn "ZcrudRegistry" iffd/lib --include="*.dart" ; echo "RC=$?"
> RC=1
> $ grep -n "zcrud_generator" iffd/pubspec.yaml ; echo "RC=$?"
> RC=1
> ```
> Les 10 occurrences de `@ZcrudField` dans `iffd/lib` sont **toutes des commentaires**, dans
> cinq dépôts qui **recopient à la main** les clés de schéma des modèles zcrud
> (`z_backed_folder_document_repository.dart:17,106`, `z_backed_exam_repository.dart:20,151`,
> `z_backed_flashcard_repository.dart:20,134`, `z_backed_folder_repository.dart:21,156`,
> `z_backed_smart_note_repository.dart:18,109`).

---

## 10. Bindings — `zcrud_get`, `zcrud_riverpod`, `zcrud_provider`

### 10.1 Le contrat commun (identique aux trois, livré en 3.1.0)

Les trois bindings **dérivent** du `ZcrudScope` ambiant au lieu de le masquer : ce qu'ils
déclarent (résolveur, ACL) prime, **tout le reste est hérité**. Preuve de code :
`zcrud_riverpod/lib/src/presentation/zcrud_riverpod_scope.dart:98` (`ZcrudScope.derive(context, …)`).
Avant 3.1.0, un hôte posant son `ZcrudScope` **au-dessus** du binding perdait ses seams en silence
(`zcrud_riverpod/CHANGELOG.md:5-24`).

### 10.2 `zcrud_riverpod` (cible IFFD)

| Canal | `fichier:ligne` | Un hôte qui veut… | Défaut |
|---|---|---|---|
| `ZcrudRiverpodScope` | `zcrud_riverpod/lib/src/presentation/zcrud_riverpod_scope.dart:40` (ctor `:46`) | monter le binding : `overrides` (`:58`), `seams` (`:61`), `acl` (`:69`) | `acl: ZDenyAllAcl()` |
| `zFormControllerProvider` | `:31` | un `ZFormController` auto-dispose | — |
| `ZRiverpodResolver` | `z_riverpod_resolver.dart:24` | résoudre `Type → provider` | — |
| `ZScopeError` (ré-export ciblé) | `zcrud_riverpod/lib/zcrud_riverpod.dart:18` | attraper l'erreur de son propre binding **sans importer `zcrud_core`** | — |
| `zStudyRepositoryProvider<T>()` | `src/study/z_study_providers.dart:51` | un **seam** qui lève `ZScopeError` tant qu'il n'est pas surchargé | throwing |
| `zStudyWatchAllProvider<T>({repo})` | `:76` | le flux **nu** `watchAll()`, sans transformation, auto-dispose | — |
| `zStudySessionSelectorProvider` | `:94` | une `family` clée par `ZSessionConfigKey` — **égalité profonde ⇒ dédup ⇒ zéro rebuild superflu** | — |
| `ZSessionConfigKey` | `src/study/z_session_config_key.dart:40` | la clé à égalité profonde | — |

### 10.3 `zcrud_provider`

| Canal | `fichier:ligne` | Rôle |
|---|---|---|
| `ZcrudProviderScope` | `zcrud_provider/lib/src/presentation/zcrud_provider_scope.dart:33` | `ChangeNotifierProvider<ZFormController>` + dérivation du scope |
| `ZProviderResolver` | `z_provider_resolver.dart:28` | résolution via `context.read` |

### 10.4 `zcrud_get` (cible DODLP) — et son canal **générique** mal domicilié

| Canal | `fichier:ligne` | Un hôte qui veut… | Défaut |
|---|---|---|---|
| `ZcrudGetScope` | `zcrud_get/lib/src/presentation/zcrud_get_scope.dart:30` (ctor `:52`) | monter le binding : `locator` (`:54`), `createController` (`:55`), `acl` (`:56`), `registerController` (`:57`), `registerInGetX` (`:58`) | `acl: ZDenyAllAcl()`, `registerController: true`, `registerInGetX: false` |
| `ZGetResolver` | `z_get_resolver.dart:25` | résoudre via `get_it`/GetX | — |
| `ZcrudGetUiScope` | `zcrud_get_ui_scope.dart:30` | monter **les deux seams UI** en une ligne | `ZGetFormPresenter()`, `ZGetToaster()` |
| `ZGetFormPresenter` | `z_get_form_presenter.dart:124` | `page → Get.to(fullscreenDialog:)`, `sheet → Get.bottomSheet`, `dialog → Get.dialog` | `sheetBackgroundColor: null` |
| `ZGetToaster` | `z_get_toaster.dart:36` | `Get.snackbar` mappé sur `ZToastSeverity`, couleur dérivée du `ColorScheme` | — |
| `ReflectableCodec<T>` | `src/data/codecs/reflectable_codec.dart:52` | adapter un schéma DODLP existant (**seule exception `reflectable`** du dépôt) | — |
| `ZReflectionCapability<T>` | `:35` | injecter sa propre capacité de réflexion | — |
| `ZStudyWatchController<T>` | `src/study/z_study_get.dart:46` | un contrôleur de flux GetX | — |
| `zPutStudySessionSelector(...)` | `:118` | une factory de dédoublonnage | — |
| 🔴 **`registerZcrudFormFields(registry, {...})`** | `z_form_fields_composer.dart:76` | **enrôler en un point** markdown + intl + geo dans un `ZWidgetRegistry` injecté | voir ci-dessous |

`registerZcrudFormFields` câble par défaut : la voie markdown (`markdown`/`inlineMarkdown`/
`richText`, `:88`), `phoneNumber` (`:93`), `country` (`:97`), `address` + `addressSearchField`
(`:101`, via `registerZAddressFieldWidgets`), `location` (`:109`) ; `geoArea` en opt-in
(`wireGeoArea`, `:113`). Le seam `additionalRegistrars` (`:84`) est exécuté **en dernier** pour
que toute collision de `kind` lève un `ZDuplicateRegistrationError` de façon déterministe.

🔴 **Ce composeur est le seul du dépôt, et il vit dans le binding GetX.**
```
$ grep -rn "registerZcrudFormFields" --include="*.dart" packages/*/lib
packages/zcrud_get/lib/zcrud_get.dart:30            (commentaire du barrel)
packages/zcrud_get/lib/src/presentation/z_form_fields_composer.dart:5,76
$ grep -rn "registerZ.*Fields\|FormFieldsComposer" --include="*.dart" packages/zcrud_riverpod/lib packages/zcrud_provider/lib ; echo "RC=$?"
RC=1
```
Or son corps n'utilise **que** `ZWidgetRegistry` + markdown/intl/geo — rien de GetX. Un hôte
Riverpod qui voudrait ce point de composition unique devrait dépendre de `zcrud_get`, donc de
`get ^4.7.2`, `get_it ^9.0.0` et `reflectable ^5.2.3` (`zcrud_get/pubspec.yaml`, bloc
`dependencies`). C'est un **assemblage manquant côté Riverpod**, pas un défaut de code.

> **Mesure hôte** : IFFD écrit son propre registre —
> `iffd/lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart` (461 lignes, **2** appels
> `.register(`, dont un `register('phoneNumber'`).

---

## 11. `zcrud_intl`, `zcrud_geo`, `zcrud_geo_location`

### 11.1 `zcrud_intl` (20 `export`, 5 183 LOC)

| Canal | `fichier:ligne` (sous `zcrud_intl/lib/`) | Un hôte qui veut… |
|---|---|---|
| `ZPhoneFieldWidget.builder({catalog})` | `src/presentation/z_phone_field_widget.dart:152` | servir le `kind` `phoneNumber` |
| `ZCountryFieldWidget.builder({catalog})` | `src/presentation/z_country_field_widget.dart:85` | servir `country` |
| `registerZAddressFieldWidgets(registry, {...})` | `src/presentation/z_address_field_widget.dart:75` | servir `address` **et** `addressSearchField` (`:61`, `:65`) |
| `ZAddressFieldWidget.builder({...})` | `:140` | le même builder, à la main |
| ⚠️ `ZCurrencyField.builder({...})` | `src/presentation/z_currency_field_widget.dart:104` | un champ devise — **aucun composeur du socle ne l'enrôle** (§ 13) |
| ⚠️ `ZStateField.builder({...})` | `src/presentation/z_state_field_widget.dart:100` | un champ état/province — **idem** |
| `ZIntlFieldConfig` | `src/domain/z_intl_field_config.dart:36` (ctor `:62`) | régler `defaultCountryIso`, `preferredCountryIsos`, `allowedCountryIsos`, `showDialCode` (défaut `true`), `searchable` (défaut `true`), `defaultCurrencyCode`, `nationalPhone`, `selectorLeadingPadding` |
| `ZCountryCatalog` / `sharedDefaultCountryCatalog()` | `src/data/z_country_catalog.dart:46` / `:42` | un catalogue pays servi depuis un **asset JSON paresseux**, partagé entre phone/country/address |
| `ZCurrencyCatalog` | `src/data/z_currency_catalog.dart:39` | catalogue ISO 4217 |
| `ZSubdivisionCatalog` | `src/data/z_subdivision_catalog.dart:45` | catalogue ISO 3166-2 |
| `ZPhoneNumber` / `ZCountryInfo` / `ZCurrencyInfo` / `ZMoney` / `ZPostalAddress` / `ZSubdivision` | `src/domain/z_phone_number.dart:21`, `z_country_info.dart:21`, `z_currency_info.dart:19`, `z_money.dart:23`, `z_postal_address.dart:17`, `z_subdivision.dart:19` | des **valeurs de tranche neutres** (E.164 `String`, ISO alpha-2, ISO 4217, ISO 3166-2, adresse structurée) |
| `ZNationalPhoneValidator` / `ZNationalPhoneError` | `src/domain/z_national_phone_validator.dart:78` / `:61` | valider un numéro **national** avec des causes distinctes |
| `ZAddressCodec` | `src/domain/z_address_codec.dart:36` | (dé)sérialiser une adresse structurée |
| `ZPlaceSearchProvider` / `ZPlacePrediction` | `src/domain/z_place_search_provider.dart:56` / `:27` | brancher une autocomplétion d'adresse |
| 🔑 `ZIntlDateDisplayFormatter` | `src/presentation/z_intl_date_formatter.dart:125`, **entrée séparée** `zcrud_intl/lib/date_formatter.dart:25` | des dates localisées → `ZcrudScope(dateDisplayFormatter: const ZIntlDateDisplayFormatter())`. Entrée séparée **exprès** : les données CLDR (~700 locales) ne sont pas payées par un hôte qui ne veut que les champs téléphone/pays |

Isolation : aucun symbole `phone_numbers_parser`/`intl_phone_number_input` n'est exporté ; le pont
E.164 est confiné à `src/presentation/z_phone_codec.dart` (jamais exporté) — dartdoc
`zcrud_intl/lib/zcrud_intl.dart:13-18`.

### 11.2 `zcrud_geo` (18 `export`, 7 195 LOC)

| Canal | `fichier:ligne` (sous `zcrud_geo/lib/`) | Un hôte qui veut… | Défaut |
|---|---|---|---|
| `ZGeoFieldWidget.builder({adapterFactory, geometry})` | `src/presentation/z_geo_field_widget.dart:50` | servir `location` / `geoArea` | `adapterFactory: null` → repli **coordonnées seules**, aucun SDK carte, aucun secret |
| `ZGeoFieldConfig` | `src/domain/z_geo_field_config.dart:65` (ctor `:92`) | régler **19 paramètres** : `geometry`, `defaultCenter`, `defaultZoom`, `mapHeight`, `tileUrlTemplate`, `mapStyleJson`, `interactive` (⇒ `true`), `toolbarConfig`, `allowedGeometries`, `adapterKey`, `tileUrlTemplates`, `allowFullscreen` (⇒ `true`), `showStylePicker` (⇒ `false`), `showMetrics` (⇒ `false`), `showChrome` (⇒ `false`), `minZoom`, `maxZoom`, `zoomStep`, `presentation` (⇒ `ZGeoPresentation.inlineEditor`) | — |
| `ZGeoEditorToolbarConfig` | `src/domain/z_geo_editor_toolbar_config.dart:21` | régler **21 bascules** de barre d'outils (`showModeSelector` `:65`, `showMyLocationButton` `:68`, `showUndoButton` `:71`, `showClearButton` `:74`, `showOptimizeButton` `:78`, `showMapTypeToggle` `:83`, `showExtendedMapTypes` `:86`, `showTrafficToggle` `:91`, `showBuildingsToggle` `:94`, `showIndoorViewToggle` `:97`, `showRotationToggle` `:102`, `showTiltToggle` `:105`, `showZoomControlsToggle` `:110`, `showCompassToggle` `:113`, `showMapToolbarToggle` `:116`, `useMapOptionsDropdown` `:121`, `mapOptionsLabel` `:124`, `showButtonLabels` `:127`, `compactMode` `:130`, `compactBreakpointDp` `:137`, `disabled` `:56`) | — |
| `ZMapAdapter` (port) | `src/presentation/z_map_adapter.dart:161` | fournir **son propre** backend carte | — |
| `ZMapCameraCapable` / `ZMapGesturesCapable` | `:94` / `:121` | déclarer des capacités optionnelles | — |
| `ZGeoLocationResolver` (typedef) | `:64` | brancher « ma position » | — |
| `ZGeoMapView` | `src/presentation/z_geo_map_view.dart:65` | une **vue** carte multi-entrées (`ZGeoMapViewEntry` `:39`, `ZGeoMapViewLabelBuilder` `:62`) |
| `ZGeoShapeStylePicker` | `src/presentation/z_geo_shape_style_picker.dart:47` | un sélecteur de style de forme |
| `ZGeoPoint` / `ZGeoShape` / `ZGeoCircle` / `ZGeoShapeStyle` / `ZGeoBounds` | `src/domain/z_geo_point.dart:34`, `z_geo_shape.dart:39`, `z_geo_circle.dart:30`, `z_geo_shape_style.dart:32`, `z_geo_metrics.dart:56` | des valeurs **neutres** |
| `ZGeoJson` | `src/domain/z_geo_geojson.dart:136` | (dé)sérialiser en GeoJSON |
| `ZGeoChromeReference` / `ZGeoStyleReference` / `ZGeoTileReference` | `src/domain/z_geo_chrome_reference.dart:26`, `z_geo_style_reference.dart:18`, `z_geo_tile_reference.dart:33` | des références de chrome/style/tuiles surchargeables |
| Adaptateur OSM | **entrée dédiée** `zcrud_geo/lib/adapters/osm.dart:21` → `ZOsmMapAdapter` | `flutter_map`, hors de la voie d'import par défaut |
| Adaptateur Google | **entrée dédiée** `zcrud_geo/lib/adapters/google.dart:29` → `ZGoogleMapAdapter` | `google_maps_flutter` ; **la clé API vit dans la config plateforme de l'hôte** (`AndroidManifest.xml` → `com.google.android.geo.API_KEY` ; `AppDelegate` → `GMSServices.provideAPIKey`), jamais dans le paquet — `adapters/google.dart:11-15` |

### 11.3 `zcrud_geo_location` (3 `export`, 272 LOC)

| Canal | `fichier:ligne` (sous `zcrud_geo_location/lib/`) | Un hôte qui veut… |
|---|---|---|
| `zcrudGeolocatorResolver({onFailure, gateway})` | `src/zcrud_geolocator_resolver.dart:42` | « ma position » **clé en main** : vérification du service, une seule re-demande de permission, `LocationAccuracy.high`, `distanceFilter: 10`, limite 10 s |
| `ZGeoLocationFailureCause` | `src/z_geo_location_cause.dart:15` | distinguer `serviceDisabled` / `permissionDenied` / `permissionDeniedForever` / `error` |
| `ZGeoLocationFailureListener` (typedef) | `:39` | recevoir la cause ; **le résolveur ne lève jamais** et complète `null` |
| `ZGeoLocationGateway` / `ZGeoLocationPermission` | `src/z_geo_location_gateway.dart:32` / `:16` | **falsifier la plateforme** en test |

Isolation : aucun symbole `geolocator` exporté ; le plugin est confiné à
`src/geolocator_gateway_impl.dart` (jamais exporté) — dartdoc `zcrud_geo_location.dart:8-11`.
Les permissions plateforme restent à la charge de l'hôte (`:13-14`).

---

## 12. Pièges — canaux qui n'agissent que sous condition, défauts qui ont changé

| # | Piège | Preuve | Statut |
|---|---|---|---|
| P1 | 🔴 `ZDeletionSemantics.strict` (**défaut**) exclut de **toutes** les lectures tout document **sans** `is_deleted`. Sur un parc legacy non backfillé, un dépôt zcrud rend une collection **vide** sans lever. | `zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:57-63,169` | **fait** |
| P2 | `legacyDeletedKey` est **ignorée en `strict`** — l'assert le refuse en debug (`:180-187`), mais l'assert ne vit qu'en debug. | même fichier `:180-187` | **fait** |
| P3 | `save(collectionId:)` **redirige l'écriture** hors du `collectionPath` sur `FirebaseZRepositoryImpl`, et est **ignoré** sur `ZOfflineFirstRepository`. Deux sémantiques opposées, même nom. | `zcrud_firestore/CHANGELOG.md:14-31` | **fait** |
| P4 | `buildFolderScopedStudyRepository` **n'accepte pas** `clock`, alors que `buildUserScopedStudyRepository` l'accepte. Un hôte qui veut une horloge injectée sur la voie folder-scopée doit composer `ZOfflineFirstBoxRepository` à la main. | `grep -n clock zcrud_firestore/lib/src/data/z_folder_scoped_study_repository.dart` → `198`, `216` **seulement** (les deux dans `buildUserScopedStudyRepository`, `:187-218`) ; ctor `:114-152` sans `clock` | **fait** |
| P5 | 🔴 Le port `ZNumberDisplayFormatter` existe (3.14) mais **aucune implémentation n'est livrée** par le socle. `zcrud_intl` fournit `ZIntlDateDisplayFormatter`, pas son pendant numérique. | `grep -rn "implements ZNumberDisplayFormatter\|extends ZNumberDisplayFormatter" --include="*.dart" packages/*/lib` → **RC=1** | **fait** |
| P6 | `ZCurrencyField.builder` et `ZStateField.builder` existent, mais **aucun composeur du socle** n'enrôle un `kind` `currency`/`state` — et `EditionFieldType` (46 membres) n'en contient aucun. | `grep -rn "register('currency'\|register('state'\|register('money'" --include="*.dart" packages/*/lib` → **RC=1** ; `zcrud_core/lib/src/domain/edition/edition_field_type.dart:40-212` | **fait** |
| P7 | `registerZcrudFormFields` — le seul point de composition des champs — vit dans le binding **GetX**, alors que son corps est générique. Un hôte Riverpod paierait `get` + `get_it` + `reflectable` pour l'utiliser. | § 10.4 (greps montrés) | **fait** |
| P8 | 🔴 `accentBarHeight` est un jeton **partagé** (cartes d'étude/flashcard le consommaient déjà). Un hôte qui le posait pour ses cartes **et** dispose d'un résolveur de teinte de type verra désormais **ses champs porter la barre**. Aucun moyen de le neutraliser côté champs par jeton unique. | `zcrud_core/CHANGELOG.md:78` ; jeton `z_theme.dart:1102` | **fait, livré en 3.16.0** |
| P9 | 🔴 **Changement de défaut en 3.20.0** : le résumé d'un `select` multiple est désormais **coupé au-delà de 3 valeurs** (« +N … »). Échappatoire : `selectSummaryMaxChips` ≤ 0 rétablit l'affichage intégral. | `zcrud_core/CHANGELOG.md:21` ; jeton `z_theme.dart:2255` | **fait** |
| P10 | 🔴 **Remplacement en 3.17.0** : les flèches monter/descendre des sous-listes sont **supprimées** des deux modes au profit de la poignée. L'équivalent non gestuel devient **sémantique**, par ligne. Le résumé **tabulaire** ne s'applique plus quand l'ordre est réordonnable. | `zcrud_core/CHANGELOG.md:56-57` | **fait** |
| P11 | `subListRowHorizontalPadding` gouverne **aussi** l'en-tête de colonnes et le **seuil d'empilement** du résumé compact ; le libellé du bloc garde sa propre marge de 16 dp (posé à 0, le jeton ne l'aligne pas sur le cadre). | `zcrud_core/CHANGELOG.md:44` ; jeton `z_theme.dart:1026` | **fait** |
| P12 | `ZcrudScope(theme:)` **prime** sur `ThemeData.extension<ZcrudTheme>()`. Un scope posé pour une autre raison neutralise silencieusement l'extension de thème sur tout son sous-arbre. | `z_theme.dart:2549-2558` | **fait** |
| P13 | `ZDenyAllAcl` est le défaut de `ZcrudScope`, `ZcrudGetScope` et `ZcrudRiverpodScope`. Un hôte qui oublie `acl:` voit **zéro geste** offert — pas d'erreur, juste une UI muette. | `zcrud_scope.dart:82` (ctor) / `:117` (champ) ; `zcrud_get_scope.dart:56` ; `zcrud_riverpod_scope.dart:50` | **fait** |
| P14 | `ZcrudLocalizationsDelegate.supportedLocales` ne contient que `en` et `fr`. Une troisième locale retombe sur la table `en`. | `z_localizations.dart:413-416`, `load` `:421` | **fait** |
| P15 | `ZReorderRenderer.buildDragHandle` a une **implémentation par défaut identité** : un renderer injecté qui ne l'implémente pas rend la poignée telle quelle — donc, sous un châssis non-`SliverReorderableList`, **inerte**. C'était précisément le défaut corrigé en 3.19.0. | `presentation/reorder/z_reorder_renderer.dart:91` ; `zcrud_core/CHANGELOG.md:26,30` | **fait** |
| P16 | **Soupçon, non vérifié à l'exécution** : la dartdoc des bindings 3.1.0 parle de « 21 seams sur 23 » ; `ZcrudScope` en porte **25** aujourd'hui (`zcrud_scope.dart:110-320`). Le comportement de `derive` est générique et couvre les 25 (parité gardée par `zcrud_core/test/presentation/z_scope_copywith_parity_test.dart` et `z_scope_notify_parity_test.dart`), mais **le chiffre de la dartdoc est périmé**. À traiter comme une imprécision documentaire, pas comme un défaut. | `zcrud_riverpod/CHANGELOG.md:14` vs `zcrud_scope.dart:110-320` | **soupçon documentaire** |
| P17 | **Soupçon** : `ZFieldTintPresets` est présenté comme « offert aux applications » mais n'est **jamais** lu par le socle — un hôte qui l'importe et attend un effet n'en aura aucun tant qu'il n'écrit pas son `gradientResolver`. La dartdoc le dit (`z_field_tint_presets.dart:12-15`) ; le nom, lui, suggère un préréglage actif. | grep montré § 2.4 | **soupçon d'ergonomie** |

---

## 13. Greps négatifs montrés (récapitulatif)

Toute affirmation d'absence de ce document repose sur l'un de ces relevés, exécutés le 2026-08-26
depuis `/home/zakarius/DEV/zcrud` (ou `/home/zakarius/DEV/iffd` pour les mesures hôtes).

| Affirmation | Commande | Résultat |
|---|---|---|
| Aucun paquet de mon périmètre n'a changé depuis v3.12.0 | `git diff --name-only v3.12.0..HEAD -- 'packages/*/lib/*'` | 42 fichiers, **0** dans les 9 paquets du périmètre |
| Aucune implémentation de `ZNumberDisplayFormatter` livrée | `grep -rn "implements ZNumberDisplayFormatter\|extends ZNumberDisplayFormatter" --include="*.dart" packages/*/lib` | **RC=1** |
| Aucun `kind` `currency`/`state`/`money` enrôlé par le socle | `grep -rn "register('currency'\|register('state'\|register('money'\|register('address" --include="*.dart" packages/*/lib` | **RC=1** |
| Aucun composeur de champs côté Riverpod/Provider | `grep -rn "registerZ.*Fields\|FormFieldsComposer" --include="*.dart" packages/zcrud_riverpod/lib packages/zcrud_provider/lib` | **RC=1** |
| `ZFieldTintPresets` n'est lu par aucun site du socle | `grep -rn "ZFieldTintPresets" --include="*.dart" packages/*/lib` | 2 hits, **tous deux dans son fichier de déclaration** |
| `buildFolderScopedStudyRepository` n'accepte pas `clock` | `grep -n "clock" packages/zcrud_firestore/lib/src/data/z_folder_scoped_study_repository.dart` | `198`, `216` — **hors** du corps `:114-152` |
| IFFD n'utilise pas `ZcrudLabels` | `grep -rn "ZcrudLabels" iffd/lib --include="*.dart"` | **RC=1** |
| IFFD n'utilise pas `ZcrudScope.derive` | `grep -rn "ZcrudScope.derive" iffd/lib --include="*.dart" \| wc -l` | **0** (contre 28 `ZcrudScope(`) |
| IFFD n'utilise pas la voie codegen | `grep -rn "@ZcrudModel" iffd/lib --include="*.dart"` ; `grep -rn "ZcrudRegistry" iffd/lib --include="*.dart"` ; `grep -n "zcrud_generator" iffd/pubspec.yaml` | **RC=1** pour les trois |

---

## 14. 🔴 Livré récemment (3.13 → 3.21), probablement inconnu de l'hôte

**Fenêtre** : `v3.12.0` (2026-08-23) → `v3.21.0` (2026-08-25) — neuf versions en trois jours.
IFFD est épinglé sur `v3.21.0` : ces canaux sont **dans son arbre**, disponibles, et n'ont
jamais fait l'objet d'un handoff qu'il aurait exercé.

Deltas mesurés sur `v3.12.0..HEAD` :
* **+27 jetons** de `ZcrudTheme` (`git diff v3.12.0..HEAD -- .../z_theme.dart | grep -cE '^\+  final …'` → 27)
* **+8 clés** de localisation (`showPassword`, `hidePassword`, `reorderItem`, `selectSummaryOverflow`, `z.markdown.write`, `z.markdown.edit`, `z.markdown.commit`, `z.markdown.expand`)
* **+2 seams** de `ZcrudScope` (`numberDisplayFormatter`, `defaultTextConfig`)
* **+2 fichiers** dans `zcrud_core/lib/` (`z_field_tint_presets.dart`, `ports/z_number_display_formatter.dart`)

### 14.1 Nouveaux canaux, par version

| Version | Canal | `fichier:ligne` | Ce qu'un hôte y gagne |
|---|---|---|---|
| **3.14.0** | seam `ZcrudScope.defaultTextConfig` | `zcrud_scope.dart:320` | un `ZTextConfig` **par défaut** pour tous les champs texte (précédence champ > scope) |
| **3.14.0** | port `ZNumberDisplayFormatter` | `domain/ports/z_number_display_formatter.dart:43` + seam `zcrud_scope.dart:308` | des nombres localisés en lecture **et** dans le résumé de sous-liste (⚠️ P5 : impl à écrire) |
| **3.14.0** | `ZTextConfig.keyboardType` (table fermée) | `domain/edition/z_field_config.dart:101` | choisir le clavier par champ ; chaîne inconnue ⇒ repli par `maxLines` |
| **3.14.0** | `ZTextCapitalization.lowercase` | `z_field_config.dart:55` (enum `:35`) | forçage déterministe, **collage compris** |
| **3.14.0** | teinte par **type de champ** (bordure de focus + pastille) | `theme/z_gradient_resolver.dart:20` (`zFieldTypeTintKey`), `:10` (préfixe) | teinter tout un formulaire par famille de champ ; **étalon pixel-identique tant qu'aucun résolveur n'est injecté** |
| **3.14.0** | `ZFieldTintPresets.classic` | `domain/edition/z_field_tint_presets.dart:73` | une palette de départ **copiable** (15 entrées, `int` ARGB) |
| **3.14.0** | cinquième cible `readOnly` de `ZDerivation` | `domain/edition/z_derivation.dart:241` (clé de canal `:105`) | lecture seule **conditionnelle**, toutes familles (le statique prime) |
| **3.14.0** | `ZFieldSpec.defaultValue` amorcé pour toute tranche absente | `z_form_controller.dart:150` (`seedDefaultValue`) | une clé présente dans `initialValues` reste **autoritaire, même nulle** |
| **3.15.0** | teinte jusqu'au **libellé flottant** | `zcrud_core/CHANGELOG.md:82` | cohérence visuelle du champ teinté |
| **3.15.0** | **pastille de fond** de l'icône d'ornement | jetons `adornmentIconBackgroundAlpha` `z_theme.dart:1078`, `adornmentIconBackgroundRadius` `:1083`, `adornmentIconSize` `:1089` | aucun jeton ⇒ **aucun conteneur ajouté** |
| **3.16.0** | **accent supérieur de champ** | jeton `accentBarHeight` `z_theme.dart:1102` ; clé `zFieldAccentKey` `z_gradient_resolver.dart:35` | une fine barre colorée au sommet du champ, par champ nommé ou par type (⚠️ P8) |
| **3.16.0** | teinte + pastille sur le slot `leading` | `zcrud_core/CHANGELOG.md:71` | même gouvernance que `prefixIcon` |
| **3.16.0** | `zResolveTintedAdornment` / `zResolveFieldTint` / `zResolveFieldAccent` | `edition/z_field_adornment_view.dart:270` / `:206` / `:218` | un **présentateur riche** pose une tuile teintée sans redupliquer la normalisation de contraste |
| **3.16.0** | garde d'**inertie des jetons de thème** | `zcrud_core/test/purity/z_theme_token_inertia_guard_test.dart` | tout jeton public a un consommateur, ou une exemption nominative — **un jeton « futur » ne peut plus naître muet** |
| **3.17.0** | **glisser-déposer dans la sous-liste** via le port `ZcrudScope.reorderRenderer` | seam `zcrud_scope.dart:219` | poignée ≥ 48 dp + actions sémantiques de déplacement, dans les deux modes ; repli interne zéro-config |
| **3.17.0** | **six jetons d'espacement vertical** de sous-liste | `z_theme.dart:993,1001,1012,1049,1057,1066` | jusqu'à **52 dp** récupérés par sous-liste en résumé tabulaire ; tous nullables, rendu inchangé au pixel tant qu'aucun n'est posé |
| **3.17.0** | ordre déclaré de `fields` respecté par la voie **groupée** | `zcrud_core/CHANGELOG.md:52` | un champ indépendant peut suivre une section décorée sans groupe factice |
| **3.18.0** | poignée de sous-liste **personnalisable** | `subListDragHandleIcon` `z_theme.dart:969`, `subListDragHandleSize` `:979`, `subListDragHandleColor` `:983` | jetons absents ⇒ `Icons.drag_indicator_rounded` à taille et couleur **ambiantes** |
| **3.18.0** | marges horizontales de ligne réglables | `subListRowHorizontalPadding` `:1026` (⇒ 16), `subListRowInnerPadding` `:1041` (⇒ 12) | deux scalaires qui se composent (début = externe + interne, fin = externe seul) — ⚠️ P11 |
| **3.18.0** | bordure de ligne **dépendante de l'item** | `ZSubListSeams.itemBorderColorKey` (`edition/z_sub_list_seams.dart:1020`, typedef `ZSubItemColorKey` `:442`) | chaîne de résolution seam → `ZcrudScope.colorKeyResolver` → rôles Material 3 → `fieldBorderColor` ; **sans seam, aucune résolution n'est tentée** |
| **3.19.0** | `ZReorderRenderer.buildDragHandle(context, index, handle)` | `reorder/z_reorder_renderer.dart:91` | un renderer qui sait ancrer un geste l'y ancre ; implémentation par défaut **identité** (⚠️ P15) |
| **3.19.0** | `ZReorderRenderRequest.dragPreviewWrapper` | `reorder/z_reorder_render_request.dart:127` (typedef `:34`) | habiller l'aperçu flotté, qui vit dans l'`Overlay` hors de l'arbre — non rempli ⇒ identité |
| **3.20.0** | jetons de **résumé de `select` multiple** | `selectSummaryMaxChips` `z_theme.dart:2255`, `selectSummaryChipRadius` `:2262`, `selectSummaryChipPadding` `:2268`, `selectSummaryChipFontSize` `:2275` | couper un résumé de 15 valeurs ; **valeur ≤ 0 ⇒ aucune coupure** (⚠️ P9) |
| **3.20.0** | clé `selectSummaryOverflow` | `l10n/z_localizations.dart` (tables `:24`/`:209`) | le fragment « +N … », composé comme les clés à quantité déjà en place |
| **3.21.0** | quatre clés de chrome du champ rich-text compact | `z.markdown.write`, `z.markdown.edit`, `z.markdown.commit`, `z.markdown.expand` | `write` et `edit` sont distinctes **à dessein** : rédiger un champ vide n'est pas modifier un champ rempli |
| **3.21.0** | garde de couverture des libellés étendue à `zcrud_markdown/lib` | `zcrud_core/CHANGELOG.md:12` | une clé non servie dans les deux tables rougit |

### 14.2 Canaux **anciens** mais mesurément inutilisés par IFFD

Ils ne sont pas récents ; ils sont **inconnus dans les faits**, ce qui, pour une confrontation,
revient au même. Chiffres du § 8, § 9 et § 12.

| Canal | Où | Pourquoi il compte pour IFFD |
|---|---|---|
| `ZDeletionSemantics.absentMeansAlive` + `legacyDeletedKey` | `firebase_z_repository_impl.dart:81`, `:170` | 0 site hôte. C'est **le** canal prévu pour un parc legacy — celui d'IFFD |
| `omitNullFields` | `:168` | 0 site hôte. L'équivalent du `compact(true)` legacy, indispensable en écriture fusionnée |
| `ZDelegatesSearch` | `zcrud_core/lib/src/domain/ports/z_search_capability.dart` | 0 site hôte. Sans lui, une barre de recherche de listing est **inerte** au-dessus d'un dépôt qui ne sert pas `search` |
| `buildFolderScopedStudyRepository` / `buildUserScopedStudyRepository` | `z_folder_scoped_study_repository.dart:114` / `:187` | 0 site hôte. Deux fabriques offline-first clé en main |
| `ZFirestoreCascadeBatcher` | `z_firestore_cascade_batcher.dart:107` | 0 site hôte. Soft-delete en cascade borné à 450 écritures/lot, avec rapport |
| `ZFirestoreAppFileResolver` | `z_firestore_app_file_resolver.dart:280` | 0 site hôte. Résolution en lot de références opaques de fichiers |
| `ZSyncOrchestrator` + `assembleZStudySyncOrchestrator` | `sync/z_sync_orchestrator.dart:117`, `z_study_sync_orchestrator.dart:54` | 0 site hôte |
| `ZClock` / `ZSystemClock` | `sync/z_clock.dart:31`, `:34` | 0 site hôte. Le seul levier contre le décalage d'horloge sur la clé LWW |
| `ZcrudLabels` + `label()` | `l10n/z_labels.dart:20`, `z_localizations.dart:449` | 0 site hôte. Le seul canal de **surcharge de libellé** |
| `ZcrudScope.derive` | `zcrud_scope.dart:478` | 0 site hôte contre 28 `ZcrudScope(` |
| Toute la voie codegen (`@ZcrudModel` → `$XxxFieldSpecs` → `registerXxx`) | `zcrud_generator/lib/src/zcrud_model_generator.dart` | 0 site hôte, `zcrud_generator` absent du `pubspec.yaml`. Cinq dépôts hôtes recopient à la main les clés de schéma |
| ~190 jetons de `ZcrudTheme` sur 220 | `z_theme.dart:594-2404` | l'hôte en pose ~30 (`iffd/.../z_iffd_form_theme.dart`) |

---

## 15. Limites de ce relevé

1. **Aucun test n'a été lancé**, dans aucun dépôt (consigne). Les garanties citées au § 4 le sont
   d'après le **contenu** des fichiers de garde, pas d'après un run.
2. Les comptes de « types publics déclarés » (§ 0) sont des **approximations par grep** sur
   `^(class|abstract class|enum|mixin|typedef|extension) [A-Z]…` dans `lib/` : ils incluent des
   types déclarés mais non ré-exportés par le barrel. Les chiffres de seams (25), de jetons (220),
   de clés (123) et de types de champ (46), eux, sont comptés sur la déclaration exacte.
3. Les mesures côté IFFD portent sur `iffd/lib` uniquement (pas `test/`, pas `example/`) et sur
   l'arbre de travail au 2026-08-26 ; elles qualifient un **usage**, jamais une intention.
4. `docs/analyses/iffd-migration-2026-08-25/` n'a **pas** été utilisé comme source : tout constat
   de ce document a été remesuré sur disque.
5. Les aires **formulaires**, **listes**, **chat/IA**, **étude/SRS**, **examens** ne sont pas
   couvertes ici ; les canaux de sous-liste et de `select` n'y figurent que par leur **facette
   transverse** (jetons de thème, clés de localisation, port de réordonnancement).
