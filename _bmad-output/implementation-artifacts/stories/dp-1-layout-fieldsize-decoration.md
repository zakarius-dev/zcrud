# Story DP.1: Layout & décoration de formulaire (parité DODLP — B1 + B2 + M2)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As développeur consommateur de zcrud (migration DODLP → zcrud),
I want que le moteur d'édition zcrud reproduise fidèlement le **layout** et la **décoration** de formulaire DODLP (variante de taille `large` en Card, `minLines/maxLines` réellement honorés, décor `OutlineInputBorder` radius 12 / focus width 2 / padding 16 / filled / helper 2 lignes / label flottant gras, dérivé de tokens de thème injectables),
so that un formulaire authored pour DODLP rende **structurellement à l'identique** sous zcrud, sans style codé en dur ni divergence visuelle, tout en restant surchargable par l'app via `ThemeExtension`/`ZcrudScope`.

Périmètre : **`zcrud_core` uniquement** (+ ses tests). Gaps couverts : **B1** (`FieldSize.large`), **B2** (`minLines/maxLines` morts), **M2** (décor `ZcrudTheme` non câblé). Réf : `docs/dodlp-edition-parity-gap.md` §2.3, §3 (B1/B2/M2) ; épic `E-DP` story DP-1.

## Acceptance Criteria

### Bloc B1 — `ZFieldSize {normal, large}` + rendu variante Card

1. **Enum de domaine `ZFieldSize`.** Un enum public `ZFieldSize { normal, large }` existe dans la couche `domain` de `zcrud_core` (pur-Dart `const`, aucune dépendance Flutter — AD-1), documenté et exporté par le barrel du domaine (là où `ZFieldSpec`/`EditionFieldType` sont exportés). Valeurs en camelCase (canonique §5). Miroir 1:1 de `FieldSize {normal, large}` DODLP (`dodlp-otr/lib/modules/data_crud/models.dart:87-94`).

2. **`ZFieldSpec.fieldSize` additif & rétro-compatible.** `ZFieldSpec` porte un champ `final ZFieldSize fieldSize`, **défaut `ZFieldSize.normal`**, intégré au constructeur `const`, à `copyWith`, à `==` et à `hashCode`. Une `ZFieldSpec` construite sans `fieldSize` conserve exactement l'égalité de valeur, la sérialisation implicite et le rendu actuels (aucune régression sur les tests de projection E2-5 / égalité existants).

3. **Rendu variante `large` piloté par tokens.** Dans le host de champ (`z_field_widget.dart`, dispatcher actif), quand `field.fieldSize == ZFieldSize.large`, le contrôle est enveloppé dans un décorateur Card (nouveau widget `presentation` `ZLargeFieldCard`) qui reproduit `_buildLargeCard` DODLP (`edition_screen.dart:893-971`) : `Card` (bordure radius = token, elevation 0), `ConstrainedBox(minHeight = token 64)`, `Padding(token 16/12 directionnel)`, `Row` avec **label rendu AU-DESSUS** du champ (Column, `crossAxisAlignment.start`), gaps par tokens, slots **leading/suffix optionnels**, et **champ interne sans bordure** (décor « bare »). Toutes les mesures (radius, minHeight, paddings, gaps, taille de police label, taille d'icône leading) proviennent de tokens `ZcrudTheme` (AC10) — **aucune valeur numérique de layout ni couleur codée en dur** dans le widget.

4. **Champ interne « bare » en mode large.** En variante `large`, les familles décor-portantes concernées (au minimum `text`/`number`/`select`) rendent leur `InputDecoration` en mode **bare** (`InputBorder.none`, `isDense: true`, `contentPadding` zéro, **sans** `labelText` — le label est porté par la Card) via la fabrique M2 (AC11). Le host signale ce mode aux familles (paramètre additif `bare`/équivalent, défaut `false`), sans élargir la frontière de rebuild (AD-2, SM-1 préservé).

5. **`normal` = comportement par défaut inchangé.** Quand `field.fieldSize == ZFieldSize.normal` (défaut), aucun wrapper Card n'est monté ; le champ est rendu inline avec le décor standard (AC10/AC11). Les invariants AD-2 (rebuild ciblé à la tranche, `TextEditingController`/`FocusNode` stables, aucun `Form` global) restent vérifiés à l'identique.

### Bloc B2 — `ZTextConfig.minLines/maxLines` réellement lus

6. **Fin du hardcode.** `ZTextFieldWidget` (`families/z_text_field_widget.dart:71-72`) lit `field.config` : si c'est un `ZTextConfig` non nul, les `minLines`/`maxLines` **effectifs** dérivent de `config.minLines`/`config.maxLines`. Les littéraux `1`/`3`/`null` codés en dur ne pilotent plus seuls le rendu.

7. **Défauts préservés si config absente/partielle.** Sans `ZTextConfig` (ou champ nul), la résolution reproduit le comportement actuel : `text`/`password` → `minLines: 1, maxLines: 1` ; `multiline` → `minLines: 3, maxLines: null`. Résolution partielle : `minLines effectif = config.minLines ?? (isMultiline ? 3 : 1)` ; `maxLines effectif = config.maxLines ?? (isMultiline ? null : 1)`.

8. **Cohérence clavier & masquage.** `keyboardType` passe à `TextInputType.multiline` dès que `maxLines effectif != 1` (sinon `TextInputType.text`). Garde-fou `obscureText` : pour `password`, `minLines`/`maxLines` sont **forcés à 1** (une saisie masquée multi-ligne est invalide côté Flutter) — la config multi-ligne est ignorée sans throw et documentée.

### Bloc M2 — Tokens de décoration `ZcrudTheme` + fabrique centrale

9. **Tokens de décoration NON-COULEUR.** `ZcrudTheme` gagne des tokens de décoration **sans aucune couleur** (couleurs toujours dérivées du `ColorScheme` de l'app — AC12), valeurs par défaut = parité DODLP (`themes.dart:17-46`) :
   - `inputRadius: Radius` = `Radius.circular(12)` ;
   - `inputBorderWidth: double` = `1` (bordure enabled/normale) ;
   - `inputFocusedBorderWidth: double` = `2` ;
   - `inputContentPadding: EdgeInsetsDirectional` = `symmetric(horizontal: 16, vertical: 16)` ;
   - `inputFilled: bool` = `true` ;
   - `helperMaxLines: int` = `2` ;
   - `floatingLabelWeight: FontWeight` = `FontWeight.bold` ;
   - styles texte **non-couleur** (poids/taille uniquement, `color` laissé `null` → dérivé) : `labelTextStyle: TextStyle?`, `inputTextStyle: TextStyle?`, `hintTextStyle: TextStyle?` (défaut `hintTextStyle` : `TextStyle(overflow: TextOverflow.clip)` conforme DODLP) ;
   - lot **large** : `largeMinHeight: double` = `64`, `largePadding: EdgeInsetsDirectional` = `symmetric(horizontal: 16, vertical: 12)`, `largeLabelTextStyle: TextStyle?` (défaut : poids `w500`, taille `16` — parité `_buildLabelWidget`/`bodyLarge`), `largeLeadingIconSize: double` = `22`, `largeLeadingGap: double` = `12`, `largeLabelGap: double` = `4`.
   Chaque token est intégré au constructeur `const`, à `copyWith`, à `lerp`. `ZcrudTheme.fallback` reste inchangé pour les couleurs (dérivation `ColorScheme`/`TextTheme` seule).

10. **Fabrique centrale `inputDecoration`.** `ZcrudTheme` expose une méthode d'instance `InputDecoration inputDecoration(BuildContext context, {String? label, String? hintText, String? helperText, String? errorText, bool bare = false, Widget? prefixIcon, Widget? suffixIcon})` qui **assemble** l'`InputDecoration` à partir des tokens (AC9) + des **couleurs dérivées** de `Theme.of(context).colorScheme` (border = `outline`, focusedBorder = `primary` × `inputFocusedBorderWidth`, errorBorder = `error`, fill dérivé de la surface du thème). Quand `bare == true` : `border/enabled/focused = InputBorder.none`, `isDense: true`, `contentPadding: EdgeInsets.zero`, `filled: false`, **sans** `labelText`/`floatingLabel` (usage interne à la Card `large`). Résolution honorant l'override app : le point d'entrée est `ZcrudTheme.of(context).inputDecoration(context, …)` (donc `ZcrudScope.theme` → `ThemeExtension<ZcrudTheme>` → `fallback`).

11. **Câblage des familles.** Au minimum `z_text_field_widget.dart`, `z_number_field_widget.dart` et `z_select_field_widget.dart` dérivent désormais leur `InputDecoration` de `ZcrudTheme.of(context).inputDecoration(context, …)` (mode standard, ou `bare: true` en variante `large` — AC4), **au lieu** du `InputDecoration(labelText: …)` en dur actuel (`z_text_field_widget.dart:79`, `z_number_field_widget.dart:91`, `z_select_field_widget.dart:73`). Le libellé sémantique et l'a11y (rôle champ natif, RTL/directionnel — AD-13) sont préservés.

12. **Surcharge par l'app réellement consommée.** Un `ThemeExtension<ZcrudTheme>` (ou `ZcrudScope(theme:)`) fourni par l'app surchargeant un token de décoration (ex. `inputRadius`/`inputContentPadding`) est **effectivement reflété** dans l'`InputDecoration` produite pour un champ standard (border radius / contentPadding résolus = valeur de l'override, pas le défaut). Les couleurs restent dérivées du `ColorScheme` de l'app.

### Transverse — invariants & non-régression

13. **Zéro couleur codée en dur.** Aucun littéral de couleur ni constante de style interdite dans le code nouveau/modifié (`ZLargeFieldCard`, tokens/fabrique `ZcrudTheme`, familles câblées) — la garde `test/purity/style_purity_test.dart` reste **verte** ; la fabrique `inputDecoration` n'utilise que des dérivations `ColorScheme`/`TextTheme` (aucun `Colors.`/`Color(0x…)` ; l'exemption de garde reste bornée à `ZcrudTheme.fallback`).
14. **Directionnel only (AD-13).** Tous les insets/paddings introduits sont directionnels (`EdgeInsetsDirectional`), aucun `EdgeInsets.only(left/right)`/`Alignment.centerLeft/Right`/`TextAlign.left/right`.
15. **SM-1 / AD-2 non régressés.** La variante `large` et le câblage décor ne changent PAS la frontière de rebuild : taper 100 caractères dans un champ (normal ou large) ne reconstruit que ce champ, sans perte de focus ni saut de curseur (test widget de rebuild ciblé toujours vert).

## Tasks / Subtasks

- [x] **T1 — Domaine : `ZFieldSize` + `ZFieldSpec.fieldSize` (AC1, AC2)**
  - [x] Créer `packages/zcrud_core/lib/src/domain/edition/z_field_size.dart` : `enum ZFieldSize { normal, large }` documenté (pur-Dart const).
  - [x] Ajouter l'export dans le barrel du domaine (`domain.dart`).
  - [x] `z_field_spec.dart` : ajouter `final ZFieldSize fieldSize` (défaut `ZFieldSize.normal`) au constructeur, `copyWith`, `==`, `hashCode`, `toString` inchangé.
  - [x] Garde `domain_purity_test.dart` verte (aucune dépendance Flutter introduite).

- [x] **T2 — Tokens de décoration `ZcrudTheme` (AC9)**
  - [x] `z_theme.dart` : ajouter les 16 tokens `input*`/`large*` (défauts = parité DODLP, aucune couleur).
  - [x] Intégrer au constructeur `const`, `copyWith`, `lerp`. `fallback` (couleurs) inchangé.
  - [x] Rétro-compat : `radiusM` (=8) / `fieldPadding` (=12/8) NON mutés — tokens `input*`/`large*` dédiés.

- [x] **T3 — Fabrique `ZcrudTheme.inputDecoration(context, {...})` (AC10, AC12, AC13)**
  - [x] Méthode d'instance assemblant `OutlineInputBorder`/paddings/filled/helperMaxLines/floatingLabelStyle depuis les tokens + couleurs dérivées de `colorScheme` (outline/primary/error/surfaceContainerHighest).
  - [x] Chemin `bare: true` (borderless, isDense, padding zéro, sans label).
  - [x] Garde couleurs : dérivations scheme/textTheme uniquement.

- [x] **T4 — B2 : `minLines/maxLines` dans `ZTextFieldWidget` (AC6, AC7, AC8)**
  - [x] Lire `field.config as ZTextConfig?` ; `minLines`/`maxLines` effectifs avec repli type-dépendant.
  - [x] `keyboardType` multiline dès `maxLines != 1`.
  - [x] Garde `password` : forcé 1/1.

- [x] **T5 — M2 : câbler le décor dans les familles (AC11, AC4)**
  - [x] `z_text_field_widget.dart`, `z_number_field_widget.dart`, `z_select_field_widget.dart` : `decoration = ZcrudTheme.of(context).inputDecoration(...)`.
  - [x] Paramètre additif `bool bare` (défaut `false`) ajouté aux 3 familles.

- [x] **T6 — B1 : `ZLargeFieldCard` + dispatch host (AC3, AC4, AC5, AC14, AC15)**
  - [x] Créer `z_large_field_card.dart` (Card + minHeight + label au-dessus + slots leading/suffix optionnels + child), 100 % tokens, insets directionnels.
  - [x] `z_field_widget.dart` : en sortie de `build`, si `fieldSize == large`, envelopper le sous-arbre réactif dans `ZLargeFieldCard` (wrapper STATIQUE) + `bare: true` aux familles text/number/select.
  - [x] Exporter `z_large_field_card.dart` dans le barrel principal.
  - [x] Label au-dessus résolu via `label(context, …)` (l10n/RTL).

- [x] **T7 — Tests (AC1..AC15)**
  - [x] Domaine : défaut `fieldSize == normal`, `copyWith(fieldSize: large)`, égalité/hashCode (rétro-compat).
  - [x] Widget : `large` monte une `Card` + `ConstrainedBox minHeight >= 64` + label au-dessus ; champ interne bare.
  - [x] Widget : `ZTextConfig(minLines: 2, maxLines: 4)` honoré ; défauts préservés (text 1/1, multiline 3/null) ; `password` → 1/1.
  - [x] Décor : `inputDecoration` défaut → radius 12, focus width 2, padding 16/16, filled, helperMaxLines 2, floatingLabel gras ; couleurs dérivées du scheme ; bare borderless.
  - [x] Override : `Theme(extensions: [ZcrudTheme(inputRadius: 4, inputContentPadding: …)])` reflété dans l'`InputDecoration`.
  - [x] Garde : `style_purity_test.dart` reste vert.
  - [x] SM-1 : frappe char-par-char en `large` → focus conservé, rebuild ciblé.

- [x] **T8 — Vérif verte** : `dart analyze` (zcrud_core) RC=0 → `flutter test packages/zcrud_core` RC=0 (623) → `graph_proof` CORE OUT=0 → purity entrypoint OK.

## Dev Notes

### État actuel des fichiers touchés (lus intégralement)

- **`domain/edition/z_field_spec.dart`** — `ZFieldSpec` `const` pur-données (constructeur + `copyWith` + `==` + `hashCode`). **Aucun** champ de taille. Ajout de `fieldSize` doit être répercuté dans les 4 endroits (ctor/copyWith/==/hashCode) sinon l'égalité de valeur diverge silencieusement (tests E2-5).
- **`domain/edition/z_field_config.dart`** — `ZTextConfig({minLines, maxLines, keyboardType})` **existe déjà** (l.27-51) avec `==`/`hashCode`. B2 = pure consommation runtime, **aucune** modif de cette classe.
- **`presentation/theme/z_theme.dart`** — `ZcrudTheme extends ThemeExtension` : couleurs nullable dérivées par `fallback` ; tokens existants `gapS/M/L`, `radiusS(=4)/radiusM(=8)`, `fieldPadding(=12/8 directionnel)`. `of(context)` résout `ZcrudScope.theme` → `extension<ZcrudTheme>()` → `fallback`. **Aucune** fabrique `inputDecoration` aujourd'hui. ⚠️ NE PAS repurposer `radiusM`/`fieldPadding` (consommés ailleurs / rétro-compat) : ajouter des tokens `input*`/`large*` dédiés.
- **`presentation/edition/z_field_widget.dart`** — dispatcher actif (`ZFieldWidget`), hôte scellé sur la tranche (AD-2). `_dispatch` rend le contrôle de la famille ; text/number retournent le contrôle nu, les autres passent par `_wrapError`. C'est **ici** que doit se brancher le wrapper `large` (après construction du child) + le passage de `bare` aux familles text/number/select. NE PAS déplacer la frontière `ListenableBuilder`/`ZFieldListenableBuilder`.
- **`presentation/edition/z_edition_field.dart`** — hôte **générique legacy** (E3-1), rend un `TextFormField` uniforme avec `InputDecoration(labelText:)` en dur (l.154). Il n'est PAS le chemin de rendu par-type (c'est `ZFieldWidget`). DP-1 cible `ZFieldWidget` ; toucher `z_edition_field.dart` est optionnel (le laisser tel quel est acceptable — il ne sert que de preuve SM-1 générique). **Ne pas** y introduire de régression.
- **`families/z_text_field_widget.dart`** — `minLines: isMultiline ? 3 : 1`, `maxLines: isMultiline ? null : 1` **codés en dur** (l.71-72), `decoration: InputDecoration(labelText:)` (l.79). Cibles directes B2 + M2.
- **`families/z_number_field_widget.dart`** — `decoration: InputDecoration(labelText:)` (l.91). Cible M2 (mêmes `inputFormatters`/parsing typé conservés).
- **`families/z_select_field_widget.dart`** — `decoration: InputDecoration(labelText:)` (l.73). Cible M2.

### Référence DODLP (LECTURE SEULE — valeurs exactes répliquées, HORS couleurs)

- **`dodlp-otr/lib/themes.dart:17-46` (`kFormInputDecorationThemeLight`)** : `filled: true` ; `helperMaxLines: 2` ; `floatingLabelStyle: FontWeight.bold` ; `contentPadding: symmetric(horizontal: 16, vertical: 16)` ; `OutlineInputBorder radius 12` ; `focusedBorder width 2` ; `hintStyle overflow: clip`. (Couleurs `kNavyColor`/`Colors.white`/`grey.shade300`… **NON** répliquées — dérivées du `ColorScheme`.)
- **`dodlp-otr/lib/modules/data_crud/models.dart:87-94`** : `enum FieldSize { normal, large }` → `ZFieldSize`.
- **`dodlp-otr/lib/modules/data_crud/presentation/views/edition_screen.dart:893-971` (`_buildLargeCard`)** : `Card` `elevation 0`, `RoundedRectangleBorder radius 12` ; `ConstrainedBox minHeight 64` ; `Padding symmetric(horizontal: 16, vertical: 12)` ; leading `IconTheme/Icon size 22` ; `SizedBox width 12` (leading↔colonne et colonne↔suffix) ; label puis `SizedBox height 4` puis child ; label rendu au-dessus (bodyLarge/w500 ~16, astérisque requis rouge géré ailleurs — hors DP-1). Child = champ **borderless** (décor bare).

**Tokens DODLP retenus (hors couleurs) :** inputRadius **12** · inputBorderWidth **1** · inputFocusedBorderWidth **2** · inputContentPadding **16/16** · inputFilled **true** · helperMaxLines **2** · floatingLabelWeight **bold** · hintStyle overflow **clip** · largeMinHeight **64** · largePadding **16/12** · largeLabelTextStyle **w500 / 16** · largeLeadingIconSize **22** · largeLeadingGap **12** · largeLabelGap **4**.

### Contraintes d'architecture (AD — NON-NÉGOCIABLES)

- **AD-2 / OBJECTIF N°1 / SM-1** : la variante `large` et le câblage décor ne doivent JAMAIS élargir la frontière de rebuild. Le wrapper Card enveloppe le **résultat** du `ZFieldListenableBuilder`, il ne s'insère pas entre la frontière et la frappe. Aucun `setState` de formulaire, aucun `Form` global, `TextEditingController`/`FocusNode` restent stables et détenus par l'hôte.
- **FR-26 / AD-6** : ZÉRO style/couleur en dur dans le cœur ; tout dérive de `ZcrudTheme` (tokens) + `ColorScheme`/`TextTheme` (couleurs) ; surchargable par `ZcrudScope.theme`/`ThemeExtension`. Repli `Theme.of(context)`.
- **AD-13 (RTL/a11y)** : insets **directionnels** (`EdgeInsetsDirectional`), `TextAlign.start`, cibles ≥ 48 dp, `Semantics`/label sémantique préservés. La garde `style_purity_test.dart` échoue sur toute variante non-directionnelle ou couleur littérale.
- **AD-1** : `ZFieldSize` reste pur-Dart (domaine, out-degree 0). Aucune dépendance Flutter dans le domaine.
- **AD-3 / AD-4** : `fieldSize` est un ajout **additif** rétro-compatible (défaut `normal`) ; désérialisation défensive préservée (un schéma sans `fieldSize` reste valide).

### Décisions & points de vigilance

- **Tokens dédiés vs repurposing** : le rapport de parité M2 suggérait « aligner `radiusM→12`, `fieldPadding→16/16` ». **Décision DP-1** : introduire des tokens **dédiés** `inputRadius`/`inputContentPadding`/`large*` et NE PAS muter `radiusM`/`fieldPadding` (évite une régression silencieuse sur tout autre consommateur de ces tokens + garde la rétro-compat AC2/AC13). À consigner en Completion Notes.
- **`bare` en variante large** : threading d'un `bool bare` (paramètre nommé optionnel, défaut `false`) aux familles text/number/select. Ne pas introduire d'`InheritedWidget` supplémentaire (surcharge inutile ; le host connaît déjà `field.fieldSize`).
- **Garde couleurs de la fabrique** : `inputDecoration` NE DOIT PAS utiliser `Colors.*`/`Color(0x…)` (la garde ne l'exempte pas — seule `fallback` l'est). Dériver fill/borders de `colorScheme` uniquement.
- **Label du large card** : réutiliser le helper `label(context, …)` de `z_localizations.dart` (déjà utilisé par les familles) pour la résolution l10n.

### Besoins détectés HORS `zcrud_core` (à signaler — NON traités par DP-1)

1. **Authoring `fieldSize`** : pour qu'un `fieldSize` déclaré sur un modèle atteigne `ZFieldSpec`, il faut `@ZcrudField(fieldSize:)` dans **`zcrud_annotations`** + projection dans **`zcrud_generator`**. DP-1 ajoute seulement le champ **runtime** `ZFieldSpec.fieldSize` (settable via `copyWith`/construction directe). → **story de suivi** (bloc annotations/generator).
2. **Slots leading/suffix authored (M1)** : `ZLargeFieldCard` **accepte** des slots leading/suffix optionnels, mais `ZFieldSpec` n'a pas encore de champs `leading/prefix/suffix` (gap **M1**, DP-12+). En DP-1 la Card est structurellement prête mais rendue **sans** leading/suffix par défaut (aucune source de données). → couvert par M1 ultérieurement.
3. **Autres familles décor-portantes** (`date`/`relation`/`color`…) : DP-1 câble text/number/select (les 3 qui construisent une `InputDecoration` aujourd'hui). L'harmonisation du décor des autres familles est un suivi M2-résiduel (non bloquant pour la parité layout).

### Project Structure Notes

- Fichiers **NEW** : `lib/src/domain/edition/z_field_size.dart`, `lib/src/presentation/edition/z_large_field_card.dart` (+ tests associés).
- Fichiers **UPDATE** : `z_field_spec.dart`, `z_theme.dart`, `z_field_widget.dart`, `families/z_text_field_widget.dart`, `families/z_number_field_widget.dart`, `families/z_select_field_widget.dart`, barrel(s) d'export.
- Aucune nouvelle dépendance de package (AD-1). Aucun `*.g.dart` impacté (pas d'annotation modifiée dans `zcrud_core`).

### References

- [Source: docs/dodlp-edition-parity-gap.md#2.3 Affichage / taille / layout] (B1 `FieldSize.large`, `minLines/maxLines` morts, décor `kFormInputDecorationTheme`)
- [Source: docs/dodlp-edition-parity-gap.md#3 Liste priorisée — 🔴 BLOCKING B1/B2 + 🟠 MAJOR M2]
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md#E-DP DP-1]
- [Source: dodlp-otr/lib/themes.dart:17-46] (kFormInputDecorationTheme — valeurs non-couleur)
- [Source: dodlp-otr/lib/modules/data_crud/models.dart:87-94] (enum FieldSize)
- [Source: dodlp-otr/lib/modules/data_crud/presentation/views/edition_screen.dart:893-971] (_buildLargeCard)
- [Source: packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart] (UPDATE)
- [Source: packages/zcrud_core/lib/src/domain/edition/z_field_config.dart:27-51] (ZTextConfig — déjà présent)
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_theme.dart] (UPDATE — tokens + fabrique)
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart] (UPDATE — dispatch large + bare)
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_text_field_widget.dart:71-79] (UPDATE — B2 + M2)
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_number_field_widget.dart:91] (UPDATE — M2)
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_select_field_widget.dart:73] (UPDATE — M2)
- [Source: packages/zcrud_core/test/purity/style_purity_test.dart] (garde zéro-couleur / directionnel — doit rester verte)
- [Source: CLAUDE.md#Critical Patterns] (AD-1, AD-2, AD-6/FR-26, AD-13)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, skill `bmad-dev-story`).

### Debug Log References

- `dart analyze packages/zcrud_core` → **RC=0**, `No issues found!` (après correction du lint `directives_ordering` sur l'export de `z_large_field_card.dart`).
- `flutter test packages/zcrud_core` → **RC=0**, **623 tests OK** (baseline 608 + 15 nouveaux, aucune régression).
- `python3 scripts/dev/graph_proof.py` → **CORE OUT=0 OK**, ACYCLIQUE OK.
- `dart test test/purity/domain_entrypoint_dart_test.dart` → **RC=0** (surface pure Flutter-free préservée).

### Completion Notes List

- **B1** : `ZFieldSize {normal, large}` (domaine pur-Dart, exporté par `domain.dart`) ; `ZFieldSpec.fieldSize` additif (défaut `normal`) intégré ctor/`copyWith`/`==`/`hashCode`. `ZLargeFieldCard` (Card elevation 0 + bordure rayon-token, `ConstrainedBox minHeight`, `Padding` directionnel, `Row` leading/suffix optionnels, `Column` label au-dessus + gap), 100 % tokens `large*`/`input*`. Dispatch : le wrapper `large` enveloppe le **résultat** du `ListenableBuilder` réactif **en sortie de `build()`** (wrapper STATIQUE, hors voie de frappe) — la frontière de rebuild AD-2 n'est pas déplacée (SM-1 préservé, prouvé par le test char-par-char : focus jamais perdu).
- **B2** : `ZTextFieldWidget` lit `field.config as ZTextConfig?` ; `minLines/maxLines` effectifs = `config ?? repli type-dépendant` (text 1/1, multiline 3/null) ; `keyboardType` multiline dès `maxLines != 1` ; garde `password` → 1/1 (config multi-ligne ignorée sans throw, évite l'assert Flutter `!obscureText || maxLines == 1`).
- **M2** : 16 tokens de décoration NON-couleur ajoutés à `ZcrudTheme` (ctor/`copyWith`/`lerp`) ; fabrique `inputDecoration(context, {label, hintText, helperText, errorText, bare, prefixIcon, suffixIcon})` assemblant bordures/paddings/filled/floatingLabel depuis les tokens + couleurs dérivées du `ColorScheme` (border `outline`, focus `primary`, error `error`, fill `surfaceContainerHighest`). `z_text/number/select_field_widget` câblés dessus (+ param additif `bool bare`, défaut `false`).
- **Décision rétro-compat (Dev Notes)** : `radiusM`/`fieldPadding` NON mutés ; tokens `input*`/`large*` **dédiés** → aucun autre consommateur de `radiusM`/`fieldPadding` impacté.
- **Additivité / rétro-compat** : tous les ajouts sont additifs (nouvel enum, nouveau champ défaut `normal`, nouveaux tokens à défauts, nouvelle méthode, params nommés optionnels) — aucun symbole existant retiré/renommé ; `zcrud_core` reste compilant à tout instant (périmètre disjoint des workstreams satellites parallèles).
- **Périmètre** : `packages/zcrud_core` uniquement. Aucun autre package touché. `graph_proof` CORE OUT=0 conservé. Gaps hors-cœur signalés dans la story (authoring `@ZcrudField(fieldSize:)` → annotations/generator ; slots leading/suffix authored M1 ; autres familles décor M2-résiduel) NON traités ici.

### File List

**NEW**
- `packages/zcrud_core/lib/src/domain/edition/z_field_size.dart`
- `packages/zcrud_core/lib/src/presentation/edition/z_large_field_card.dart`
- `packages/zcrud_core/test/presentation/edition/dp1_layout_decoration_test.dart`

**UPDATE**
- `packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart`
- `packages/zcrud_core/lib/domain.dart`
- `packages/zcrud_core/lib/zcrud_core.dart`
- `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart`
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart`
- `packages/zcrud_core/lib/src/presentation/edition/families/z_text_field_widget.dart`
- `packages/zcrud_core/lib/src/presentation/edition/families/z_number_field_widget.dart`
- `packages/zcrud_core/lib/src/presentation/edition/families/z_select_field_widget.dart`
- `packages/zcrud_core/test/domain/edition/z_field_spec_test.dart`
