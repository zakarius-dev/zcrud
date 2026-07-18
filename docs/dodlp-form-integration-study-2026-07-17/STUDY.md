# Étude d'intégration — réutilisation des packages de rendu de formulaire DODLP dans zcrud

> **Nature** : ÉTUDE / PROPOSITION. Aucun code de package modifié, aucun commit, aucun test/build exécuté.
> **Date** : 2026-07-17. **Périmètre** : `/home/zakarius/DEV/dodlp-otr` (référence, lecture seule) confronté à `/home/zakarius/DEV/zcrud`.
> **Synthèse de 6 lentilles** : `01-recon-seam-zcrud.md`, `02-flutter-form-builder.md`, `03-awesome-select.md`, `04-flutter-switch-country.md`, `05-intl-phone.md`, `06-aeration-layout.md` (mêmes conclusions, détails et `file:line` dans chaque rapport source).

---

## 1. Résumé exécutif

**Oui — on peut migrer l'UI de formulaire DODLP sans casser son rendu ni violer les invariants zcrud, et le gros du travail est déjà fait.** La découverte structurante des 6 lentilles est que **zcrud n'a quasiment aucun package DODLP à « porter »** : le cœur (`zcrud_core`) et les satellites (`zcrud_intl`, `zcrud_responsive`) ont **déjà réimplémenté nativement, theme-driven et conformes AD-2**, l'équivalent de ce que DODLP obtenait via `flutter_form_builder` (widgets), `flutter_switch`, `country_picker`, `intl_phone_number_input`, `responsive_form_row`/`dynamic_stepper`. Plusieurs de ces réimplémentations citent explicitement « parité DODLP » dans leurs commentaires. **Le vrai bug historique** (jank + perte de focus) ne venait **pas** de `flutter_form_builder` mais d'un `setState(() {})` à l'échelle de l'écran que DODLP appelait dans chaque callback de champ — précisément ce que `ZFormController`/`ZFieldListenableBuilder` corrige par conception. **Le seul package tiers réellement candidat à un adaptateur** est `awesome_select` (`SmartSelect`), pour les types `select`/`radio`/`relation` — et encore, `zcrud_core` a des widgets natifs et des configs (`ZSelectConfig.radioAsModal`, `ZRelationConfig.crudKey`) déjà taillées pour cette parité. Le travail restant est surtout : **du câblage** (`registry.register(...)` dans le binding), **du thème** (reproduire les mesures DODLP via tokens `ZcrudTheme`, jamais les couleurs hardcodées), et **quelques décisions produit** sur le niveau de parité pixel exigé.

---

## 2. Le seam d'intégration

### 2.1 Le contrat (recon lentille 01)

Le rendu d'un champ traverse : `DynamicEdition` (structurel) → `ZFieldWidget` (dispatcher `StatefulWidget`, un `State` par champ, scellé sur la frontière de rebuild AD-2) → `familyOf(EditionFieldType)` (switch exhaustif). Les familles de base ont un widget natif `zcrud_core` ; les types « widget ailleurs » tombent dans `EditionFamily.registryOrFallback` → **`ZWidgetRegistry`** (le seam) → repli accessible `ZUnsupportedFieldWidget` si absent (jamais un throw).

```dart
// packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart
@immutable
class ZFieldWidgetContext {
  final ZFieldSpec field;              // spec const (name/type/label/config)
  final Object? value;                 // valeur COURANTE de la tranche field.name
  final ValueChanged<Object?> onChanged; // écrit UNE nouvelle valeur dans la tranche
}
typedef ZFieldWidgetBuilder = Widget Function(BuildContext, ZFieldWidgetContext);

class ZWidgetRegistry {              // instanciable, PAS de singleton (AD-4)
  void register(String kind, ZFieldWidgetBuilder builder); // throw si collision de kind
  ZFieldWidgetBuilder? tryBuilderFor(String kind);         // null si absent
}
```

Points clés (garde-fous structurels AD-2) :
- Le builder **ne reçoit PAS** le `ZFormController` — seulement `ctx.value` (tranche découpée) et `ctx.onChanged` (callback branché sur `controller.setValue(field.name, v)`). Un adaptateur **ne peut pas** élargir sa souscription à d'autres champs par ce seam.
- `kind` = **le nom de l'enum `EditionFieldType`** (`field.type.name`), jamais un identifiant libre. Collision = `throw` fail-fast (AD-3).
- Le registre est **injecté** via `ZcrudScope(widgetRegistry: registry, child: …)`, jamais un singleton statique.

Patron déjà en production dans **5 satellites** (`zcrud_markdown`, `zcrud_geo`, `zcrud_intl`, `zcrud_flashcard`) : une fonction `registerZ<Pkg>Fields(ZWidgetRegistry registry, {options})` exportée, appelée explicitement au bootstrap par l'app hôte (jamais un side-effect d'import).

### 2.2 Squelette d'adaptateur type

```dart
// packages/zcrud_<satellite>/lib/src/presentation/z_<truc>_registration.dart
void registerZDodlpXxxField(ZWidgetRegistry registry, {/* deps runtime injectées */}) {
  registry.register('xxx', (context, ctx) => _XxxAdapter(
    key: ValueKey('z-xxx-${ctx.field.name}'),  // place stable PROPRE (AD-2) — posée par l'adaptateur
    ctx: ctx,
  ));
}

class _XxxAdapterState extends State<_XxxAdapter> {
  late final _controller;   // controller lourd créé 1× en initState, JAMAIS recréé au rebuild
  late final FocusNode _focus;

  @override void initState() {
    super.initState();
    final initial = _safeDecode(widget.ctx.value);      // décodage DÉFENSIF (AD-3/AD-10)
    _controller = /* … */(initial);
    _focus = FocusNode()..addListener(_onFocusChange);  // AUCUN abonnement hors ce champ
  }
  void _onFocusChange() {                               // sync guardée HORS focus uniquement
    if (_focus.hasFocus) return;
    final ext = _safeDecode(widget.ctx.value);
    if (ext != _controller.value) _controller.reset(ext);
  }
  void _onUserEdit(v) => widget.ctx.onChanged(_encode(v)); // valeur NEUTRE, pas de type lourd
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);                    // FR-26 : jamais de couleur en dur
    return Semantics(label: widget.ctx.field.label ?? widget.ctx.field.name, // AD-13
      child: Padding(padding: const EdgeInsetsDirectional.all(8), child: /* rendu DODLP-porté */));
  }
}
```

**Interdits dans un adaptateur** (sinon réintroduction du bug historique) : détenir un `FormBuilderState`/`GlobalKey<FormState>` de portée formulaire ; ré-écouter le controller au-delà de `field.name` ; recréer un controller lourd à chaque `build` ; appeler `onChanged` de façon synchrone pendant la frappe en écrasant le curseur.

**Limite importante** : le `ZWidgetRegistry` ne peut PAS *remplacer* un widget de famille de base — `familyOf` route text/number/date/select/relation/… vers leur widget natif `zcrud_core` **avant** d'atteindre `registryOrFallback`. Le registre ne sert que les types classés `registryOrFallback`/`freeWidget`/`custom`. Remplacer un rendu de famille de base exigerait `DynamicEdition.fieldBuilder` (seam niveau *formulaire*, non recommandé, peut violer AD-2) ou une story `zcrud_core` modifiant `familyOf`.

---

## 3. Matrice d'intégration

| Package DODLP | Rôle DODLP réel | `EditionFieldType` / kind cible | Placement (JAMAIS `zcrud_core`) | Stratégie AD-2 | Parité visuelle DODLP | Effort | Risque |
|---|---|---|---|---|---|---|---|
| **`flutter_form_builder`** ^10.2 | Orchestrateur de cycle de vie (`validate/save/reset/isDirty`) — **jamais** source de vérité des valeurs ; le vrai moteur de sélection est `awesome_select` | Aucun widget cible — remplacé par les familles natives `zcrud_core` (`ZTextFieldWidget`, `ZDateFieldWidget`…) | **Rien** (widgets NON portés) ; les *validateurs* seuls déjà dans `zcrud_core` | Le `FormBuilderState` global est en **tension directe** AD-2 → **écarté**. Familles natives = `ValueNotifier`/tranche | N/A (rendu natif à valider) | **Nul** (déjà tranché) | Faible |
| **`form_builder_validators`** ^11.2 | Validateurs purs `String? Function(String?)` (required/minLength/email/…) | Pipeline `ZValidatorCompiler`/`ZCrossFieldValidator` | **DÉJÀ dépendance de `zcrud_core`** (fonctions pures, aucun widget/état) | Conforme : fonctions pures, aucun état ; inter-champs via `ZCrossFieldValidator` (abonnement ciblé `fieldListenable`) | N/A | **Nul** (déjà fait) | Faible |
| **`awesome_select`** (`SmartSelect`, fork git) | `select` + `radio` + `crudDataSelect` (relation) : modal S2 responsive, recherche, CRUD inline | `select`, `radio`, `relation` (+ `checkbox`) via `ZWidgetRegistry` | **Nouveau satellite** (`zcrud_select` ou `zcrud_dodlp_compat`) — jamais le cœur | Adaptateur lit `ctx.value`, écrit via `ctx.onChanged` ; **jamais** le `setState(300ms)` DODLP. Configs const-safe déjà là (`ZSelectConfig`, `ZRelationConfig`) | **Point dur** : `radio` DODLP = modal (pas inline) ; CRUD inline ; bascule responsive du modal | **Moyen-élevé** | **Élevé** (fork non pub.dev, `ref: master` flottant, mainteneur unique) |
| **`flutter_switch`** ^0.3.2 | Champ `boolean` — pill switch avec texte "Oui/Non" incrusté | `boolean` | **Rien** — `SwitchListTile` natif **déjà livré** (`z_boolean_field_widget.dart`) | Conforme (Stateless, `onChanged` direct) | Delta cosmétique (texte incrusté, forme pill) — absorbable par `SwitchThemeData` | **Nul** | Faible |
| **`intl_phone_number_input`** ^0.7.4 | Champ `phoneNumber` : sélecteur pays dialog + validateur Togo | kind `phoneNumber` via `ZWidgetRegistry` | **`zcrud_intl` (existe déjà)** — widget maison sur `phone_numbers_parser` (pont unique) | Conforme et vérifié (`_numberController` 1×, sync guardée hors focus, `_emit()`) | Delta UX : sélecteur **inline** (zcrud) vs **dialog modal** (DODLP) | **Faible** (câblage seul) | Moyen (parité UX perçue + migration de données) |
| **`country_picker`** ^2.0.23 | Champ `country` — **CODE MORT** (`onSelect` no-op, enum retiré). Vrai champ pays DODLP = `select` sur `WORLD_COUNTRIES` | kind `country` via `ZWidgetRegistry` | **`zcrud_intl` (existe déjà)** — `ZCountryFieldWidget`/`ZCountryCatalog`, zéro dépendance tierce | Conforme et audité | Aucune référence (code mort) — zcrud est **plus riche** | **Nul** | Faible (couverture l10n du catalogue JSON à vérifier) |
| **`responsive_form_row` / `dynamic_stepper` / `MyStickyHeader`** (interne DODLP, pas un package) | Grille 12-col, steppers, en-têtes de section | Paramètres de `DynamicEdition` (`layout`, `interFieldGap`, `ZStepperConfig`) — pas un type de champ | **Rien à porter** — réimplémenté 1:1 dans `zcrud_core`/`zcrud_responsive` (E3-4/E3-5/DP-9) | N/A (conteneur) | Parité mesures OK ; **3 écarts** (gouttière H/V, padding d'écran, look boîte grise des sections) | **Faible** (câblage de valeurs) | Faible-moyen (décisions produit sur parité pixel) |

---

## 4. La décision `flutter_form_builder` (le point dur)

**Recommandation : option (a) — `form_builder_validators` seul, jamais les widgets `flutter_form_builder`. C'est déjà implémenté et documenté dans `zcrud_core` ; ne rien changer.**

### Justification (lentille 02, preuves sur disque)

1. **DODLP n'utilise `flutter_form_builder` que comme orchestrateur de cycle de vie**, jamais comme source de vérité des valeurs. Grep négatif décisif : `_form.currentState?.value` / `.fields[` → **0 résultat** dans tout `edition_screen.dart`. Les valeurs vivent dans un `Map item` mutable de l'écran, pas dans `FormBuilderState`.

2. **Le bug historique n'est PAS causé par `flutter_form_builder`.** Chaque callback de champ DODLP fait `setState(() {})` sur `DynamicEditionScreenState` — l'écran entier. Comme `_buildFormField` est appelé dans le `build()`, une frappe reconstruit **tous** les champs. Le `Future.delayed(300ms)` avant un `setState` (au `SmartSelect.multiple.onChange`) est un contournement de jank explicite déjà constaté par l'équipe DODLP. `ZFormController` (`ValueNotifier`/tranche) corrige exactement ce point, **indépendamment** du sort de `flutter_form_builder`.

3. **L'option (a) est déjà en place** : `form_builder_validators: ^11.0.0` est dépendance de `zcrud_core` (`pubspec.yaml:48`), utilisée en fonctions pures dans `ZValidatorCompiler`/`ZCrossFieldValidator`, avec un commentaire qui **interdit explicitement `flutter_form_builder`** (« son `FormBuilder`/`FormBuilderState` serait un ÉTAT de formulaire global, interdit »). `flutter_form_builder` n'est dépendance d'**aucun** package zcrud (grep → 1 seule occurrence, dans un commentaire). CORE OUT=0 respecté.

4. **Les options (b)/(c) sont faisables mais superflues.** `FormBuilderField extends FormField` fonctionne **sans** ancêtre `FormBuilder` (`FormBuilder.of(context)` est nullable, tous les accès gardés par `?.`) — donc un widget FormBuilder *pourrait* être monté en tranche. Mais `zcrud_core` a **déjà** toutes les familles natives équivalentes (text/number/date/boolean/select/…), rendues de façon plus conforme à AD-2 (contrôleur stable + `ValueNotifier` dès la conception) qu'un wrapper autour de `FormBuilderField`. Les introduire ajouterait une dépendance lourde à `zcrud_core` (violation AD-1) pour un gain de couverture **nul** et un gain de parité visuelle **incertain** (DODLP habille lui-même ses `FormBuilderTextField` avec sa propre `InputDecoration`, reproductible directement dans `ZTextFieldWidget`).

**Note pour la doc d'intégration** : si une app hôte migrée voulait malgré tout réutiliser un widget `FormBuilder*` précis pour un `EditionFieldType.custom`, elle reste libre de le faire **dans son code applicatif** (via `ZWidgetRegistry.register('custom', …)`), en s'appuyant sur la nullabilité de `FormBuilder.of(context)` — **jamais dans un package zcrud**.

---

## 5. Spécification d'aération / espacement (« spacing spec »)

Principe FR-26/AD-13 : **les *mesures* (dp) peuvent être répliquées comme valeurs de tokens ; les *couleurs* jamais** (les couleurs DODLP `Colors.grey[800]/[240]`, `Colors.black12`, `kSuccessColor*` sont hardcodées et doivent dériver du `ColorScheme`).

### 5.1 Valeurs DODLP de référence → tokens zcrud

| Concept DODLP | Valeur DODLP | Token/param zcrud | Défaut zcrud | Parité |
|---|---|---|---|---|
| Breakpoints grille | xs0/sm576/md768/lg992/xl1200 (Bootstrap) | `ZResponsiveBreakpoints` | **identiques** | ✅ bit-à-bit |
| Cascade responsive | mobile-first `xl ?? lg ?? md ?? sm ?? xs` | `ZResponsiveSpan` | **identique** | ✅ |
| Gouttière horizontale | `16.0` | `ZResponsiveGrid.gutter` (spacing) | `8` (symétrique) | ⚠️ écart §5.2-a |
| Gouttière verticale | `8.0` | `ZResponsiveGrid.gutter` (runSpacing) | `8` | ⚠️ symétrique unique |
| Spacer inter-champ | `SizedBox(height: 12)` après champs *compacts* | `DynamicEdition.interFieldGap` + `zFieldGapAfter()` | `0` (rétro-compat) | ⚠️ liste inversée §5.2-b |
| Padding d'écran | `EdgeInsets.all(12)` | `DynamicEdition.padding` | `null` (aucun) | ⚠️ à passer explicitement §5.2-c |
| Largeur max dialog | `700` (web/desktop) | `DynamicEdition` (à câbler côté binding) | — | à câbler |
| `contentPadding` champ | `all(15)` | `ZcrudTheme.inputContentPadding` | `16/16` | ~ (surchargeable) |
| Radius champ | `10` | `ZcrudTheme.inputRadius` | `12` | ~ (surchargeable) |
| Card `FieldSize.large` | minHeight 64, padding 16/12, leadingGap 12, labelGap 4 | `ZcrudTheme.large*` | **identiques** | ✅ déclaré 1:1 |
| Card lecture | margin `bottom:12`, padding `all(16)`, labelGap 8 | `ZcrudTheme.readCardMargin`/`readPadding`/`readLabelGap` | **identiques** | ✅ (couleurs dérivées) |
| Stepper | indicatorSize 40, stepSpacing 8 | `ZStepperConfig` | **mêmes défauts** + orientation `start` directionnelle | ✅ (zcrud **répare** le bug DODLP `indicatorSize` non branché) |

### 5.2 Les 3 écarts à trancher (parité pixel stricte uniquement)

- **(a) Gouttière asymétrique** : DODLP 16 H / 8 V, zcrud un seul `gutter`. Parité stricte → ajouter un `double? runGutter` optionnel sur `ZResponsiveGrid` (additif, non cassant, replié sur `gutter`). **C'est un token de layout `zcrud_core`, pas un sujet de binding.**
- **(b) `withSpaceer` liste inversée** : DODLP espace après les champs *compacts* (text/number/date…), `zFieldGapAfter` espace après les *blocs* (multiline/subItems/file/signature/markdown). En séquence mixte compact→bloc→compact, l'ordre des espaces diverge. → passer `interFieldGap: 12` **et vérifier visuellement** sur 2-3 formulaires réels (ne pas supposer la parité automatique).
- **(c) Pas de padding d'écran par défaut** : `DynamicEdition.padding` est `null`. Le binding DODLP doit passer `padding: const EdgeInsets.all(12)` explicitement. Question ouverte : ajouter `ZcrudTheme.formPadding` (défaut `EdgeInsetsDirectional.all(12)`) consommé quand `padding == null`, pour éviter la « constante éparpillée » que zcrud veut éliminer.

**Tokens injectés** : tout passe par `ZcrudScope`/`ThemeExtension` (`ZcrudTheme.of(context)`) ou les paramètres de `DynamicEdition` — jamais de constante en dur dans un package. zcrud est déjà **strictement meilleur** que DODLP en RTL/a11y ici (grille directionnelle via `Wrap` vs `Padding(right:)` DODLP ; en-tête repliable avec `Semantics(button/expanded)` + ≥48dp vs `MyStickyHeader` sans `Semantics`) — **ne pas régresser** ces points en cherchant une parité pixel aveugle.

---

## 6. Plan d'intégration par phases

**Phase 0 — Acquis (aucun travail)** : `form_builder_validators` (validateurs, déjà dans `zcrud_core`) ; `boolean` (`SwitchListTile` natif) ; `country` (`zcrud_intl`, code mort côté DODLP) ; aération/grille/stepper (réimplémentés E3-4/E3-5/DP-9).

**Phase 1 — Câblage `zcrud_intl` (effort faible, gate : tests widget RTL/a11y verts)** :
- Enregistrer `registry.register('phoneNumber', ZPhoneFieldWidget.builder(catalog: …, defaultIsoCode: 'TG'))` — le widget existe et est testé, seul le **câblage applicatif** manque (aucun binding ne l'enregistre aujourd'hui). Décider : dans `zcrud_get` (défaut) ou dans l'app DODLP (E7) ?
- Mapper le flag legacy `tgPhoneNumber` → `ZIntlFieldConfig(nationalPhone: …)` (recommandé : variante « chiffres nus », avec test de non-régression sur le seuil d'erreur).
- Vérifier la couverture l10n du catalogue pays JSON (`ZCountryCatalog`) vs `WORLD_COUNTRIES` (FR/AR/EN) ; attention au piège legacy `translations["fa"]` pour l'arabe (à ne pas reproduire).

**Phase 2 — Adaptateur `select`/`radio`/`relation` (effort moyen-élevé, le vrai chantier)** :
- **Décision préalable du owner** : nom/emplacement du satellite (`zcrud_select` neuf ? `zcrud_dodlp_compat` ? module dans `zcrud_get` ?) ; adopter `awesome_select` (fork risqué) vs le vendoriser vs s'appuyer sur les widgets natifs `zcrud_core`.
- Vérifier l'existence des registres runtime référencés par les commentaires (`ZRelationSourceRegistry`, `ZChoicesSourceRegistry`, `ZRelationCrudRegistry`) — configs const-safe (`ZSelectConfig`, `ZRelationConfig`, `ZFieldChoice`) déjà présentes.
- Adaptateur : lire `ctx.value` / écrire `ctx.onChanged` uniquement ; **ne pas porter** les bugs DODLP (`rowChips.multiple` vide, séparateur littéral `"S2Choice"`, `setState(300ms)`, `FormBuilderChoiceChips` fantômes, règle magique par nom de champ) ; `radioAsModal: true` pour la parité modal ; couleurs → `Theme.of(context)` ; `Semantics(button:)` sur le trigger.

**Phase 3 — Parité pixel optionnelle (stories `zcrud_core` dédiées, si le owner l'exige)** : `runGutter` sur `ZResponsiveGrid` ; `ZcrudTheme.formPadding` ; tokens/`sectionHeaderBuilder` pour le look « boîte grise » des sections.

**Gates transverses** (chaque story) : les 16 AD ; CORE OUT=0 (grep : aucune dép lourde ni `zcrud_*` dans `zcrud_core/pubspec.yaml`) ; SM-1 (100 caractères ne reconstruisent que le champ) ; tests widget RTL/a11y ; vérif verte `generate`+`analyze`+`test` rejouée.

---

## 7. Questions ouvertes pour le owner (8)

1. **`awesome_select`** : l'adopter via le fork git `akbarpulatov` (`ref: master` flottant, non pub.dev, mainteneur unique), le **vendoriser** (fork interne zcrud), ou **s'en passer** en s'appuyant sur les widgets `select`/`radio`/`relation` natifs de `zcrud_core` (au prix d'un delta visuel avec le modal S2 actuel) ?
2. **Emplacement de l'adaptateur select** : nouveau package `zcrud_select` / `zcrud_dodlp_compat`, ou module dans le binding `zcrud_get` (DODLP cible GetX) ?
3. **Niveau de parité pixel exigé** : parité *fonctionnelle* suffisante, ou parité *visuelle stricte* (déclenche les 3 stories `zcrud_core` de la Phase 3) ?
4. **Look « boîte grise » des sections** (`MyStickyHeader`) : le reproduire (nouveaux tokens `ZcrudTheme`) ou acter le look sobre `titleSmall` de zcrud comme évolution produit assumée ?
5. **Token `ZcrudTheme.formPadding`** (défaut `all(12)`, consommé auto par `DynamicEdition`) : le créer pour éviter que chaque binding recopie `EdgeInsets.all(12)` en dur ?
6. **Sélecteur pays téléphone** : le panneau **inline** de `ZCountryPickerField` est-il acceptable, ou faut-il une variante `showDialog`/`showModalBottomSheet` pour coller au **dialog modal** de `intl_phone_number_input` ?
7. **Validateur national Togo** : variante « chiffres nus » (`length:8`, plus propre) vs « formatée avec espaces » (`length:11`, parité stricte DODLP) — seuils d'erreur observables différents.
8. **Câblage `phoneNumber`** : enregistrement par défaut dans `zcrud_get`, ou à la charge exclusive de l'app DODLP (E7) ?

---

## 8. Les 2-3 risques majeurs de la migration DODLP

1. **`awesome_select` (fork git non pub.dev, `ref: master` flottant)** — le point le plus fragile : aucune garantie semver, mainteneur personnel unique, le `pubspec.lock` DODLP pin un commit mais tout `pub upgrade` peut faire dériver l'API sans avertissement. Porter cette dépendance dans un satellite zcrud propage ce risque à **tous** les consommateurs. C'est aussi le seul type où la parité visuelle DODLP est réellement riche (modal responsive + recherche + CRUD inline) et donc coûteuse à reproduire nativement.
2. **Parité visuelle perçue sur `select`/`radio` et le sélecteur pays** — `radio` DODLP est en réalité un **modal S2** (pas un `RadioListTile` inline) ; le sélecteur pays téléphone est un **dialog** (pas un panneau inline). Un utilisateur DODLP habitué percevra le changement. Mitigé par `ZSelectConfig.radioAsModal: true` (déjà prévu) mais nécessite validation produit explicite.
3. **Migration de données `phoneNumber`** — la valeur DODLP persistée est une `String` peu normalisée (pas E.164 strict) ; zcrud émet un `ZPhoneNumber` structuré (format meilleur). Nécessite un **script de backfill** (`ZPhoneCodec.parse(raw, iso:'TG')`), pas seulement un mapping de widget — sinon les données historiques restent au format legacy dégradé.

**À noter** : la migration **améliore** plusieurs invariants (RTL/a11y directionnels, rebuild granulaire, thème dérivé au lieu de couleurs hardcodées, format téléphone canonique) — le risque n'est pas une régression technique mais une **divergence visuelle assumée** à faire valider par le owner.
