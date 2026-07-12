# MIN-2 — Gaps MINEURS de parité DODLP (zcrud_core)

**Mode** : dev-story ACCÉLÉRÉ, DEV DIRECT groupé (sans create-story). LOCK CORE détenu
(MIN-1 markdown en parallèle sur package disjoint — aucune collision).
**Statut** : `review` (vert).
**Périmètre** : `packages/zcrud_core` uniquement. Additif strict, sans régresser DP-1..DP-22.
**Source** : `docs/dodlp-edition-parity-gap.md` §2.2/§2.3/§2.4/§2.5/§2.6 (lignes « minor »).

---

## 1. Items LIVRÉS (implémentés + testés)

| # | Item (gap DODLP) | Implémentation | Fichiers |
|---|---|---|---|
| 1 | **slider défauts 0..100** (était 0..1) | Défaut `ZSliderConfig(max)` passé `1 → 100` (aligné DODLP), **paramétrable** champ par champ. Changement de défaut **documenté** (borné/paramétrable) — toute config déclarant `min`/`max` est inchangée. | `z_field_config.dart` |
| 2 | **file/image : allowedDocumentTypes par catégorie + fallback image** | `FileFieldConfig.allowedDocumentTypes: Map<String,List<String>>` (catégorie→extensions) + getter `effectiveExtensions` (union plate ∪ catégories, dédupliquée) ; `imageFallback: bool` consommé par `ZAppFileField._iconFor` (champ `image` ⇒ icône image même pour un non-image). | `z_field_config.dart`, `z_app_file_field_widget.dart` |
| 3 | **dates : croix « effacer » quand non requis → null** | `ZDateFieldWidget.onCleared` (croix a11y ≥48dp hors nœud `excludeSemantics`, rendue seulement si valeur présente) ; dispatcher fournit le callback **uniquement** pour champ non requis + éditable. | `z_date_field_widget.dart`, `z_field_widget.dart`, l10n `clear` |
| 4 | **select : reset (→null) + radio en modal (option) + rowChips sous-titre** ; **lecture multi** | `ZSelectFieldWidget.onCleared` (bouton reset mono) + `radioAsModal` (`ZSelectConfig.radioAsModal`) ; `ZRowChipsFieldWidget` rend `ZFieldChoice.subtitle` (label 2 lignes + Tooltip). *Lecture multi (libellés joints en readMode) déjà présente (`z_read_only_value._choiceLabels`) — vérifiée.* | `z_select_field_widget.dart`, `z_field_config.dart`, `z_row_chips_field_widget.dart`, `z_field_widget.dart` |
| 5 | **text → multiline : règle de mapping** | `text` + `ZTextConfig.minLines > 1` ⇒ le défaut de `maxLines` devient extensible (au lieu d'être figé à 1 et d'écraser le `minLines` authored). Documenté ; `maxLines` explicite toujours respecté ; `password` reste mono-ligne. | `z_text_field_widget.dart` |
| 6 | **time : conversion Map{hour,minute}↔ISO + helper** | Nouveau `ZTimeCodec` (pur-Dart, Flutter-free) : `mapToHhmm`/`hhmmToMap`/`hhmmToMinutesOfDay`, défensif (AD-10, hors-bornes/mal typé ⇒ `null`). | `z_time_codec.dart` (+ barrels domain/edition) |
| 7 | **layout : withSpaceer + cohérence clés `layout` + note pixel-fidelity** | `zFieldGapAfter(type, base)` (SizedBox **type-dépendant** après les types « blocs », `base 0` ⇒ rétro-compat pixel) + `DynamicEdition.interFieldGap` (défaut 0) appliqué en rendu colonne ; `zUnknownLayoutKeys(fieldNames, layout)` (détection des clés orphelines = colocalisation span). | `dynamic_edition.dart`, `z_responsive_grid.dart` |
| 8 | **persistance du repli des sections (seam neutre)** | Port `ZSectionCollapseStore` (+ `ZInMemorySectionCollapseStore`) ; `DynamicEdition.collapseStore`/`formId` (dé)chargent et persistent l'état de repli (autoritaire une fois persisté ; défensif). Impl GetStorage/app **déférée au binding** (AD-1). | `z_section_collapse_store.dart`, `dynamic_edition.dart` (+ barrel) |
| 9 | **password : complexité paramétrable** | **Déjà livré (DP-16)** : `ZValidatorSpec.password(minLength, maxLength, requireUppercase, requireLowercase, requireDigit, requireSpecial)` — vérifié complet, aucun cas manquant. | *(existant)* |

### Note pixel-fidelity span (item 7)
La grille responsive zcrud (`ZResponsiveGrid`) utilise `Wrap` + cellules `SizedBox`
largeur = `span/12 × (largeur − gouttières)`, breakpoints Bootstrap identiques à
DODLP (576/768/992/1200). Différence de mécanique : DODLP peut recourir à
`Expanded`/`Flexible` ; zcrud utilise des largeurs calculées (`Wrap`). La fidélité
au pixel près (arrondis de largeur, reflow en fin de rangée) **reste à confirmer par
un test visuel** (réserve déjà consignée §4 du doc de parité) — hors périmètre
pur-données MIN-2. `zUnknownLayoutKeys` couvre la **cohérence des clés** (dérive au
renommage), pas le rendu pixel.

## Critères d'acceptation (résumé)
- AC1 slider : sans config ⇒ 0..100 ; bornes explicites respectées.
- AC2 file : `effectiveExtensions` = acceptedExtensions sans catégorie ; union sinon ; `imageFallback` sur `image`.
- AC3 date : croix visible ⇔ (non requis ∧ éditable ∧ valeur présente) ; tap ⇒ `null`.
- AC4 select : reset mono ⇒ `null` (jamais en multi/requis) ; `radioAsModal` ⇒ pas de RadioListTile inline ; rowChips affiche le sous-titre.
- AC5 text : `text`+`minLines:2` ⇒ champ multi-ligne (min respecté, max non figé à 1) ; `text` nu ⇒ 1/1.
- AC6 time : round-trip Map↔'HH:mm' ; entrées corrompues ⇒ `null`.
- AC7 layout : `zUnknownLayoutKeys` détecte les orphelines ; `zFieldGapAfter` = 0 par défaut, `base` pour blocs.
- AC8 repli : persiste via store injecté ; ré-applique au montage ; no-op sans store (rétro-compat).

---

## 2. Lot DOCUMENTATION DE NON-PARITÉ (justifiée — NON sur-implémenté)

Points à **0 usage réel DODLP** ou **divergence AD assumée** — documentés comme
non-parité volontaire, pas d'implémentation (éviter la dette morte / violation AD) :

| Point | Décision & justification |
|---|---|
| **`stateValidators` (closures runtime)** | **Non porté (AD-3)**. Le catalogue `ZValidatorKind` est **fermé** (const pur-données, lisible `ConstantReader`) ; injecter des closures de validation arbitraires violerait AD-3/AD-14. 0 usage réel DODLP. Contournement : ajouter un `ZValidatorKind` fermé ou un `ZCrossFieldValidator` déclaratif. |
| **`enableFeadback`** | **Non porté**. 0 usage réel DODLP ; second niveau de lecture-seule sans bascule vue, sans valeur produit. `ZFieldSpec.readOnly` + mode lecture global (`ZReadOnlyFieldCard`) couvrent les besoins réels. |
| **Accès `TextEditingController` externe** (`field.controller`/`stateController`) | **Non porté (AD-2)**. Exposer le controller texte viole la réactivité granulaire (objectif n°1). Équivalent fourni : `ZFormController.valueOf(name)` (lecture) + `setValue` (écriture). Migration = réécrire les ~5 accès `auth_profile`. |
| **Thème mapping** (`kNavyColor`… → tokens) | **Divergence VOULUE (AD-6/FR-26)**. Constantes figées DODLP remplacées par `ZcrudTheme` (ThemeExtension) injecté. Aucune couleur en dur dans le cœur ; mapping explicite requis côté app (documenté). |
| **`widget` — indirection registry** | **Supporté via `ZWidgetRegistry`** (kind `widget`/`custom`). Migration mécanique **non 1:1** (closure inline DODLP → enregistrement au registre) — c'est une indirection assumée, pas un gap fonctionnel. |
| **`geoArea` polygone/cercle** | **Hors `zcrud_core`** (relève de `zcrud_geo`). Le cœur ne porte que l'abstraction ; support polygone/cercle/holes = gaps `zcrud_geo` (M13, réserve §4). À traiter dans le package géo, pas ici. |
| **`tags` — suggestions/autocomplete** | **Équivalent supporté** : `ZTagsFieldWidget` (add/remove/dédup + a11y). Les `suggestions` DODLP = enrichissement optionnel non bloquant ; pas de source de suggestions dans le cœur (seam app si besoin). |
| **`number` — `minValueKey`/`maxValueKey` (doublon)** | **Doublon assumé** : `ZNumberConfig.minValueKey/maxValueKey` (hint de bornes croisées) **et** `ZValidatorSpec.min.ref/max.ref` (`refKey`) coexistent. La **validation** effective passe par `ZValidatorSpec.refKey` (chemin unique) ; les clés de `ZNumberConfig` restent un hint d'authoring/outillage. Non fusionnés pour préserver la rétro-compat des deux surfaces (documenté pour éviter la confusion outillage). |

---

## 3. Invariants respectés

- **AD-1 (CORE OUT=0)** : `graph_proof.py` ⇒ `out-degree(zcrud_core)=0`, ACYCLIQUE OK. Aucune dépendance état/backend ajoutée. Seams neutres (`ZSectionCollapseStore` abstrait ; impl GetStorage déférée binding).
- **AD-2 / SM-1** : controllers stables inchangés ; croix/reset/gap montés **hors voie de frappe** (widgets statiques / canal structurel) ; formatage lecture hors chemin chaud. Aucune nouvelle frontière de rebuild.
- **AD-3 / AD-14** : configs **`const` pur-données** (nouveaux champs `FileFieldConfig`/`ZSelectConfig`/`ZSliderConfig` sans closure) ; catalogue `ZValidatorKind` fermé préservé ; `ZTimeCodec` **Flutter-free** (domaine pur — purity test vert) ; aucun import état/backend.
- **AD-10** : `ZTimeCodec`, store, `_initialCollapsed`, `imageFallback` tous **défensifs** (jamais de throw ; entrée corrompue ⇒ repli sûr).
- **AD-13** : croix/reset ≥48dp, `Semantics`/`Tooltip`, insets directionnels.
- **FR-26** : zéro couleur en dur (icônes/thème hérités).

## 4. Additivité / changements de défaut

- **Additif strict** : tous les nouveaux paramètres sont **optionnels** avec défauts rétro-compat (`onCleared=null`, `radioAsModal=false`, `imageFallback=false`, `allowedDocumentTypes={}`, `interFieldGap=0`, `collapseStore=null`). Aucun symbole public supprimé/renommé. Barrels **additifs** (`z_time_codec`, `z_section_collapse_store`). Enums camelCase préservés.
- **Changement de défaut documenté (1 seul)** : `ZSliderConfig` défaut `max` **`1 → 100`** (parité DODLP). **Borné et paramétrable** : toute spec déclarant `min`/`max` est inchangée ; seul un `slider` **sans** config voit sa plage passer à 0..100. Note de migration : un usage s'appuyant sur `0..1` implicite doit déclarer `ZSliderConfig(max: 1)`. (Confirmé : aucun test/consommateur core ne dépend du défaut `0..1`.)

## 5. Vérif verte (RC réels rejoués sur disque)

| Commande | RC | Résultat |
|---|---|---|
| `dart analyze packages/zcrud_core` | 0 | No issues found! |
| `flutter test packages/zcrud_core` | 0 | **884 tests passés** (858 antérieurs + **26 MIN-2**) |
| `python3 scripts/dev/graph_proof.py` | 0 | ACYCLIQUE OK · CORE OUT=0 OK |
| `dart test test/purity/domain_entrypoint_dart_test.dart` | 0 | domaine pur-Dart OK (AD-14) |

`build_runner` : **non requis** (aucune annotation `@ZcrudModel`/`@ZcrudField` touchée).

## 6. Fichiers

**Créés**
- `packages/zcrud_core/lib/src/domain/edition/z_time_codec.dart`
- `packages/zcrud_core/lib/src/presentation/edition/z_section_collapse_store.dart`
- `packages/zcrud_core/test/domain/edition/min2_config_time_test.dart`
- `packages/zcrud_core/test/presentation/edition/min2_widgets_test.dart`

**Modifiés**
- `packages/zcrud_core/lib/src/domain/edition/z_field_config.dart` (slider défaut, FileFieldConfig catégories/imageFallback/effectiveExtensions, ZSelectConfig.radioAsModal)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_date_field_widget.dart` (onCleared/croix)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_select_field_widget.dart` (onCleared/reset, radioAsModal, _withReset)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_row_chips_field_widget.dart` (sous-titre)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_text_field_widget.dart` (mapping text→multiline)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_app_file_field_widget.dart` (imageFallback)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (câblage date onCleared, select radioAsModal/onCleared)
- `packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart` (zFieldGapAfter, interFieldGap, collapseStore/formId, persistance repli)
- `packages/zcrud_core/lib/src/presentation/edition/z_responsive_grid.dart` (zUnknownLayoutKeys)
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` (clé `clear`)
- `packages/zcrud_core/lib/{domain,edition}.dart`, `lib/zcrud_core.dart` (barrels additifs)
