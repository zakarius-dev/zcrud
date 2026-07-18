# Recon — le seam de rendu de champ zcrud (contrat d'intégration pour un package tiers)

**Lentille** : comment un package tiers (adaptateur porté de DODLP) vient rendre un `EditionFieldType` dans zcrud, sans violer AD-1/AD-2/AD-13/FR-26.
**Portée** : uniquement `/home/zakarius/DEV/zcrud` (lecture seule sur DODLP — non consulté ici, cf. autres lentilles de l'étude).
**Statut** : étude — aucune écriture de code, aucun test/build exécuté.

---

## 1. Vue d'ensemble du seam

Le rendu d'un champ dans `DynamicEdition` traverse 4 couches :

```
DynamicEdition (montage global, structurel uniquement)
  └─ ZFieldWidget (dispatcher StatefulWidget, State par champ, scellé sur AD-2)
       └─ familyOf(EditionFieldType) → EditionFamily  (switch exhaustif, 0 default)
            ├─ familles de BASE (text/number/date/boolean/select/relation/tags/…)
            │     → widget dédié zcrud_core (dans packages/zcrud_core/lib/src/presentation/edition/families/)
            └─ EditionFamily.registryOrFallback  ← LE SEAM D'INTÉGRATION
                  └─ ZWidgetRegistry.tryBuilderFor(field.type.name)
                       ├─ trouvé  → builder(context, ZFieldWidgetContext) rendu DANS la tranche
                       └─ absent  → ZUnsupportedFieldWidget (repli accessible, jamais un throw)
```

Fichiers sources (`packages/zcrud_core/lib/src/presentation/edition/`) :
- `z_widget_registry.dart` — le registre + le contrat `ZFieldWidgetBuilder`/`ZFieldWidgetContext`.
- `z_field_widget.dart` — le dispatcher (`_dispatchRegistry`, lignes 671-697).
- `edition_field_family.dart` — la classification `EditionFieldType → EditionFamily` (switch exhaustif, AC2).
- `dynamic_edition.dart` — l'assembleur (place stable, canal structurel).
- `../z_field_listenable_builder.dart` + `../z_form_controller.dart` — la primitive de tranche réactive.
- `zcrud_scope.dart` — le point d'injection du registre (`ZcrudScope.widgetRegistry`).

---

## 2. Le contrat exact : `ZFieldWidgetBuilder` / `ZFieldWidgetContext`

Source : `packages/zcrud_core/lib/src/presentation/edition/z_widget_registry.dart:34-61`.

```dart
@immutable
class ZFieldWidgetContext {
  const ZFieldWidgetContext({
    required this.field,      // ZFieldSpec — spec const du champ (name/type/label/config/…)
    required this.value,      // Object? — valeur COURANTE de la tranche field.name
    required this.onChanged,  // ValueChanged<Object?> — écrit une nouvelle valeur dans la tranche
  });
  final ZFieldSpec field;
  final Object? value;
  final ValueChanged<Object?> onChanged;
}

typedef ZFieldWidgetBuilder = Widget Function(
  BuildContext context,
  ZFieldWidgetContext ctx,
);
```

Points clés :
- Le builder **ne reçoit PAS** le `ZFormController` — seulement la tranche déjà découpée (`value`) et le callback d'écriture (`onChanged`). C'est **volontaire** (cf. commentaire `z_markdown_field.dart:17` : « le builder ne reçoit PAS le `ZFormController` ») : un adaptateur ne peut pas élargir sa souscription à d'autres champs via ce seam — il n'a que le nécessaire pour sa propre tranche. (Un besoin cross-champ — ex. DODLP `filterKeys`/`crudKey` sur `relation` — est déjà géré nativement par `ZFieldWidget._buildControl` pour les familles de base, via des seams dédiés du `ZcrudScope` : `relationSourceRegistry`/`choicesSourceRegistry`. Le registre de widgets n'est PAS le point pour ce genre de besoin.)
- `onChanged` est déjà branché : `_dispatchRegistry` (z_field_widget.dart:679-697) construit `ZFieldWidgetContext(..., onChanged: (v) => widget.controller.setValue(field.name, v))`. L'adaptateur n'a jamais accès directement à `setValue` — il **doit** passer par `onChanged`.

## 3. Le registre : `ZWidgetRegistry`

Source : `z_widget_registry.dart:71-108`.

```dart
class ZWidgetRegistry {
  ZWidgetRegistry();  // instanciable, PAS de singleton (AD-4)
  void register(String kind, ZFieldWidgetBuilder builder);      // throw ZDuplicateRegistrationError si collision
  bool isRegistered(String kind);
  Iterable<String> get kinds;
  ZFieldWidgetBuilder builderFor(String kind);      // throw ZUnregisteredTypeError si absent
  ZFieldWidgetBuilder? tryBuilderFor(String kind);  // null si absent — c'est CETTE voie qu'utilise le dispatcher
}
```

- `kind` = **le nom de l'enum `EditionFieldType`** (`field.type.name`), jamais un identifiant libre. Convention documentée `z_field_widget.dart:676` : « alignée sur `ZTypeRegistry` ».
- Collision de `kind` → `throw` (jamais un last-wins silencieux, AD-3). Un adaptateur DODLP portant plusieurs sous-types (ex. `markdown`/`inlineMarkdown`/`richText`) doit soit enregistrer chaque `kind` séparément avec un builder distinct (paramétré), soit laisser l'app hôte composer plusieurs `registerZXxxFields(registry)` sans collision.
- Le registre est **injecté**, jamais un singleton statique mutable : `ZcrudScope(widgetRegistry: registry, child: ...)` (`zcrud_scope.dart:58,86`). Résolu côté dispatcher via `ZcrudScope.maybeOf(context)?.widgetRegistry` (défensif — un registre absent ⇒ repli `ZUnsupportedFieldWidget`, jamais un crash).

## 4. Où un adaptateur satellite s'enregistre : le patron déjà en production

`grep -rn "\.register(" packages/*/lib` (RC=0) montre **5 satellites** qui utilisent DÉJÀ ce seam pour des `EditionFieldType` marqués « widget ailleurs » dans l'enum :

| Package | Fichier | `kind` enregistrés |
|---|---|---|
| `zcrud_markdown` | `lib/src/presentation/z_markdown_registration.dart:44-58` | `inlineMarkdown`, `markdown`, `richText` |
| `zcrud_markdown` | `lib/src/presentation/z_html_registration.dart:49-56` | `html`, `inlineHtml` (probable, non lu en détail) |
| `zcrud_geo` | `lib/adapters/{google,osm}.dart` | `location`, `geoArea` |
| `zcrud_intl` | `lib/src/presentation/z_phone_field_widget.dart` (doc), `z_country_field_widget.dart` (doc), `z_address_field_widget.dart:66-67` | `phoneNumber`, `country`, `address`/`addressSearch` |
| `zcrud_flashcard` | `lib/src/presentation/z_flashcard_editors.dart:50` | (registre analogue, hors scope édition champ générique) |

**Patron canonique retenu** (`zcrud_markdown/lib/src/presentation/z_markdown_registration.dart`, lu intégralement) :

```dart
void registerZMarkdownFields(ZWidgetRegistry registry, {ZCodec? codec, int? minLines, ...}) {
  registry.register('inlineMarkdown', (context, ctx) => _build(ctx, ZMarkdownFieldMode.inline, ...));
  registry.register('markdown',       (context, ctx) => _build(ctx, ZMarkdownFieldMode.block, ...));
  registry.register('richText',       (context, ctx) => _build(ctx, ZMarkdownFieldMode.block, ...));
}

Widget _build(ZFieldWidgetContext ctx, ZMarkdownFieldMode mode, ...) => ZMarkdownField.fromContext(
  key: ValueKey<String>('z-markdown-${ctx.field.name}'),   // place stable (AD-2) — POSÉE PAR L'ADAPTATEUR
  ctx: ctx,
  mode: mode,
  ...
);
```

Trois invariants que ce patron rend visibles et qu'un adaptateur DODLP doit reproduire :
1. **Fonction d'enregistrement nommée, exportée, paramétrable** (`registerZ<Pkg>Fields(registry, {options})`) — appelée explicitement par l'app hôte au bootstrap, PAS auto-enregistrée par un side-effect d'import.
2. **`key: ValueKey('z-<pkg>-${ctx.field.name}')` posée par l'adaptateur lui-même** dans le widget racine retourné — la place stable de `DynamicEdition`/`KeyedSubtree` protège le `ZFieldWidget` parent, mais le sous-arbre interne de l'adaptateur (ex. `QuillController`) a besoin de SA propre clé stable pour que son `State` (et donc son controller lourd) survive aux rebuilds de la tranche.
3. **Un constructeur `.fromContext(ctx: ZFieldWidgetContext, ...)` dédié**, distinct du constructeur « legacy » `controller`-native (`ZMarkdownField` a aussi un constructeur historique pour du code appelant qui détient un `ZFormController`). Le constructeur `fromContext` **ne prend PAS** de `ZFormController` — uniquement `ctx` (voir §2).

## 5. Comment un adaptateur pousse une valeur SANS rebuild global (SM-1)

Chaîne de tranche, de la frappe utilisateur à la notification :

1. `DynamicEdition.build` (dynamic_edition.dart:590-623) écoute **uniquement** `_structural` = `Listenable.merge([controller.visibleFields, _collapsed])` — **jamais** une tranche de valeur. Une frappe dans un champ adaptateur ne touche ni `visibleFields` ni `_collapsed` ⇒ **zéro rebuild du formulaire**.
2. `ZFieldWidget` (StatefulWidget, un par champ, State créé une fois en `initState`) route vers `EditionFamily.registryOrFallback` → `_dispatchRegistry` → construit `ZFieldWidgetContext` et appelle le builder **à l'intérieur** de `ZFieldListenableBuilder` (`z_field_widget.dart:299-313`, `ListenableBuilder(listenable: _revealAndRefs, ...)` puis `ZFieldListenableBuilder(controller, name: field.name, builder: ...)`). Le builder de l'adaptateur est donc déjà **sous** la frontière de rebuild du champ — il n'a rien à faire de spécial pour ça.
3. L'adaptateur lit `ctx.value` (valeur actuelle) et, sur interaction utilisateur, appelle `ctx.onChanged(newValue)`. `onChanged` = `(v) => widget.controller.setValue(field.name, v)` (z_field_widget.dart:694). `ZFormController.setValue` (z_form_controller.dart:127) écrit dans la `ValueNotifier` de LA tranche `name` uniquement — pas de `notifyListeners()` global sur le `ChangeNotifier` racine.
4. `ZFieldListenableBuilder` (z_field_listenable_builder.dart) est un fin wrapper de `ValueListenableBuilder<Object?>(valueListenable: controller.fieldListenable(name), ...)` — seul CE `ValueNotifier` déclenche un rebuild, et seul le sous-arbre sous ce builder (donc le widget de l'adaptateur) est reconstruit.

**Ce qu'un adaptateur NE DOIT PAS faire** (sinon il réintroduit le bug historique que zcrud corrige) :
- Créer/détenir un `FormBuilderState`, un `GlobalKey<FormState>` de portée formulaire, ou tout état qui agrège plusieurs champs — l'adaptateur reçoit UNE tranche, pas le formulaire.
- Ré-écouter `controller` au-delà de `field.name` (le `ctx` ne donne PAS accès au `ZFormController` — cf. §2 — c'est une garde structurelle, pas juste une convention).
- Recréer son propre controller lourd (`QuillController`/équivalent) à chaque `build` — il doit vivre dans un `State` dont l'identité est protégée par la `key` posée par l'adaptateur (§4.2) et par `KeyedSubtree(ValueKey(field.name))` posé en amont par `DynamicEdition`/`ZFieldWidget`.
- Appeler `ctx.onChanged` de façon synchrone dans un chemin qui écraserait la sélection/le curseur pendant la frappe (cf. la « sync guardée hors focus » de `ZFieldWidget._syncText`, qui est le patron de référence pour ce genre de piège — chaque adaptateur à buffer interne doit implémenter son équivalent).

## 6. Mapping `EditionFieldType` ↔ « widget natif zcrud_core » vs « widget ailleurs (registre) »

Source : `edition_field_type.dart` (39 valeurs) + `edition_field_family.dart::familyOf` (switch exhaustif, AC2 — 0 `default`).

| `EditionFieldType` | `EditionFamily` | Widget natif zcrud_core ? |
|---|---|---|
| text, multiline, password | text | oui — `ZTextFieldWidget` |
| number, integer, float | number | oui — `ZNumberFieldWidget` |
| dateTime, time | date | oui — `ZDateFieldWidget` |
| boolean | boolean | oui — `ZBooleanFieldWidget` |
| select, radio, checkbox | select | oui — `ZSelectFieldWidget` |
| relation | relation | oui — `ZRelationFieldWidget` (source injectée via `ZcrudScope.relationSourceRegistry`) |
| tags | tags | oui — `ZTagsFieldWidget` |
| rowChips | rowChips | oui — `ZRowChipsFieldWidget` |
| rating | rating | oui — `ZRatingFieldWidget` |
| slider | slider | oui — `ZSliderFieldWidget` |
| color | color | oui — `ZColorFieldWidget` |
| subItems | subList | oui — `ZSubListFieldWidget` (mini-CRUD, canal structurel dédié) |
| dynamicItem | dynamicItem | oui — `ZDynamicItemFieldWidget` |
| signature | signature | oui — `ZSignatureFieldWidget` |
| widget | freeWidget | **via `ZWidgetRegistry` kind `'widget'`** (même seam, `ZFreeWidgetFieldWidget` comme repli/pont) |
| file, image, document | file | oui — `ZAppFileField` (picker/storage injectés via `ZcrudScope`, PAS le widget registry) |
| hidden | hidden | oui — `SizedBox.shrink()` |
| stepper | unsupported | **repli seulement** — pas encore de widget (E3-5 à venir), pas non plus servi par le registre aujourd'hui |
| **markdown, inlineMarkdown, richText** | **registryOrFallback** | **NON — via `ZWidgetRegistry`, déjà servi par `zcrud_markdown`** |
| **html, inlineHtml** | **registryOrFallback** | **NON — via `ZWidgetRegistry`, déjà servi par `zcrud_markdown` (probable, `z_html_registration.dart`)** |
| **location, geoArea** | **registryOrFallback** | **NON — via `ZWidgetRegistry`, déjà servi par `zcrud_geo` (adapters google/osm)** |
| **phoneNumber, country, address** | **registryOrFallback** | **NON — via `ZWidgetRegistry`, déjà servi par `zcrud_intl`** |
| **icon** | **registryOrFallback** | **NON — hors parité MVP, pas de satellite connu — resterait en repli `ZUnsupportedFieldWidget`** |
| **custom** | **registryOrFallback** | **NON — point d'extension app hôte (AD-4)** |

**Conséquence pour la mission « intégrer les packages de rendu DODLP »** : tout type DODLP qui correspond à un `EditionFieldType` déjà « famille de base » (text/number/date/select/relation/tags/rowChips/rating/slider/color/subItems/dynamicItem/signature/file) a **déjà** un widget natif dans `zcrud_core` — la question de parité pour ces types est « le rendu natif zcrud reproduit-il fidèlement le rendu DODLP historique ? » (hors scope de cette lentille recon, cf. autres lentilles de l'étude). Le **vrai point d'atterrissage pour un package DODLP réutilisé tel quel** (ex. un widget de champ complexe DODLP qui n'a pas d'équivalent natif encore construit, ou dont on veut réutiliser le comportement pixel-identique plutôt que le widget zcrud_core natif) est le `ZWidgetRegistry`, sous un `kind` = nom d'`EditionFieldType`, dans un package satellite dédié (`zcrud_dodlp_compat` ou similaire) — **jamais dans `zcrud_core`**.

Un cas notable : si l'objectif est de réutiliser le rendu DODLP **à la place** d'un widget déjà natif (ex. remplacer `ZSelectFieldWidget` par le sélecteur DODLP), le registre `ZWidgetRegistry` **ne le permet pas** — `familyOf` route les familles de base vers leur widget dédié `zcrud_core` AVANT même d'atteindre `registryOrFallback` (cf. `edition_field_family.dart:117-213`, le switch est résolu au niveau `EditionFamily`, pas au niveau du registre). Le seam registre ne peut suppléer QUE les types déjà classés `registryOrFallback`/`freeWidget` par le switch exhaustif. **Remplacer un widget de famille de base nécessiterait soit `fieldBuilder` (voir §7), soit une story zcrud modifiant `familyOf` — hors périmètre d'un package satellite pur.**

## 7. Seam alternatif (mentionné pour complétude) : `fieldBuilder` de `DynamicEdition`

`DynamicEdition.fieldBuilder` (`dynamic_edition.dart:132-136, 217`) :

```dart
typedef ZEditionFieldBuilder = Widget Function(
  BuildContext context, ZFormController controller, ZFieldSpec field,
);
```

Ce seam **court-circuite ENTIÈREMENT** `ZFieldWidget` (donc `familyOf`/`ZWidgetRegistry`) pour TOUS les champs du formulaire (pas un seul type) — c'est un point d'extension de niveau **formulaire**, pas de niveau **champ**. Il donne accès au `ZFormController` complet (donc peut violer AD-2 si mal utilisé — rien ne l'empêche techniquement d'observer plusieurs tranches). La place stable (`KeyedSubtree(ValueKey(name))`) reste garantie par `DynamicEdition._buildField` même si `fieldBuilder` omet la clé (garde L3, `dynamic_edition.dart:814-822`) — mais RIEN ne protège contre un `fieldBuilder` qui appelle `controller.addListener` global. **Ce n'est PAS le seam recommandé pour un adaptateur de type de champ** : il est prévu pour une app qui veut remplacer le dispatcher entier (rare), pas pour ajouter un type. Le `ZWidgetRegistry` (§2-§6) reste le seam correct pour la mission de cette étude.

## 8. Contraintes AD/FR qu'un adaptateur doit respecter — checklist

- **AD-1 (acyclique, CORE OUT=0)** : l'adaptateur vit dans un package satellite (`zcrud_<domaine>` existant ou nouveau) qui dépend de `zcrud_core` — **jamais l'inverse**. Aucune dépendance DODLP-specific (packages tiers lourds portés depuis `dodlp-otr/pubspec.yaml`) n'entre dans `zcrud_core`. `grep -rn "package:zcrud_core" packages/zcrud_core/lib` doit rester vide (le cœur ne s'auto-référence pas comme dépendance externe — trivialement vrai) ; le vrai gate est `grep -n "^  zcrud_" packages/zcrud_core/pubspec.yaml` → RC de grep attendu 1 (aucune ligne), à vérifier au moment de l'implémentation (non exécuté ici, étude read-only).
- **AD-2 (réactivité Flutter-native, objectif produit n°1)** : cf. §5 — le builder reste **strictement** dans la frontière `field.name` ; contrôleur lourd créé 1× dans un `State` propre, jamais recréé au rebuild ; sync externe uniquement hors focus.
- **AD-13 (RTL/a11y)** : `Semantics` explicite sur le widget racine de l'adaptateur (label du champ au minimum) ; cibles tactiles ≥ 48 dp ; **jamais** `EdgeInsets.only(left:/right:)`/`Alignment.centerLeft/Right`/`Positioned(left:/right:)`/`TextAlign.left/right` — variantes directionnelles uniquement (`EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start/end`), exactement comme `ZUnsupportedFieldWidget` (`EdgeInsetsDirectional.symmetric`, lu en exemple) et `ZMarkdownField` (Semantics explicites documentées ligne 36).
- **FR-26 (thème, pas de couleur/style codé en dur)** : lire via `Theme.of(context)` / `ZcrudTheme.of(context)` (cf. `ZUnsupportedFieldWidget` : `final theme = ZcrudTheme.of(context);`), jamais une `Color(0xFF...)` littérale portée depuis le style DODLP historique.
- **AD-4 (registre instanciable, pas de singleton)** : la fonction d'enregistrement (`registerZ<Pkg>Fields(ZWidgetRegistry registry, {options})`) est appelée explicitement par l'app hôte, qui construit ET détient le `ZWidgetRegistry` puis l'injecte via `ZcrudScope(widgetRegistry: registry, ...)`. L'adaptateur ne doit **jamais** créer/posséder son propre registre statique global.
- **AD-3 (désérialisation défensive, si l'adaptateur touche à la valeur persistée)** : toute valeur de tranche `value` reçue par le builder doit être traitée défensivement (`null`/type inattendu ⇒ état vide utilisable, jamais un throw dans `build`) — patron déjà appliqué par `ZMarkdownField` (« décodage défensif — Delta corrompu → document vide », ligne 34-35) et par `ZFieldWidget._resolveSelectChoices`/`_resolveDateBound` (try/catch + repli, jamais un throw dans `build`).

## 9. Squelette d'adaptateur (pseudo-code)

```dart
// packages/zcrud_<satellite>/lib/src/presentation/z_<truc>_registration.dart
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';  // ZWidgetRegistry, ZFieldWidgetContext

/// Enregistre le(s) kind(s) DODLP-portés dans [registry]. Appelée explicitement
/// par l'app hôte au bootstrap (JAMAIS un side-effect d'import — AD-4).
void registerZDodlpXxxField(ZWidgetRegistry registry, {/* options de config */}) {
  registry.register('xxx', (context, ctx) => _XxxAdapter(ctx: ctx));
  // Si plusieurs EditionFieldType partagent le même rendu paramétré :
  // registry.register('yyy', (context, ctx) => _XxxAdapter(ctx: ctx, mode: yyy));
}

/// Widget adaptateur — StatefulWidget SEULEMENT si un controller lourd doit
/// survivre aux rebuilds de tranche (sinon Stateless suffit).
class _XxxAdapter extends StatefulWidget {
  const _XxxAdapter({required this.ctx})
      : super(key: /* place stable propre — ValueKey('z-xxx-${ctx.field.name}') */ null);
  // ^ en pratique : passer une vraie clé au constructeur, pas dans l'initializer list.
  final ZFieldWidgetContext ctx;

  @override
  State<_XxxAdapter> createState() => _XxxAdapterState();
}

class _XxxAdapterState extends State<_XxxAdapter> {
  // Controller lourd DODLP-porté — créé UNE FOIS, jamais recréé (AD-2).
  late final /* DodlpXxxController */ _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    // Décodage DÉFENSIF de la valeur initiale (AD-3/AD-10) : jamais de throw.
    final initial = _safeDecode(widget.ctx.value);
    _controller = /* DodlpXxxController */ (initial);
    _focus = FocusNode()..addListener(_onFocusChange);
    // AUCUN abonnement à autre chose que ce controller local — le ctx ne
    // donne d'ailleurs pas accès au ZFormController (garde structurelle).
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Sync guardée HORS focus uniquement (jamais pendant la frappe — FR-1/AD-2).
    if (_focus.hasFocus) return;
    final external = _safeDecode(widget.ctx.value);
    if (external != _controller.currentValue) _controller.reset(external);
  }

  void _onUserEdit(/* nouvelle valeur interne */ v) {
    // Encodage NEUTRE (pas de type lourd DODLP dans la tranche — AD-1/AD-7 si rich-text).
    widget.ctx.onChanged(_encode(v));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // FR-26 : jamais de couleur codée en dur.
    return Semantics(
      label: widget.ctx.field.label ?? widget.ctx.field.name, // AD-13
      child: Padding(
        padding: const EdgeInsetsDirectional.all(8), // AD-13 : directionnel
        child: /* rendu DODLP-porté branché sur _controller, onChanged: _onUserEdit */
            const SizedBox.shrink(),
      ),
    );
  }

  /* Décodage/encodage défensifs — jamais de throw dans build/initState (AD-3/AD-10). */
  static Object? _safeDecode(Object? raw) { try { /* ... */ return raw; } catch (_) { return null; } }
  static Object? _encode(Object? v) => v;
}
```

## 10. Risques identifiés

1. **`ZFieldWidgetContext` n'expose pas le `ZFormController`** — tout adaptateur DODLP qui, dans son code source original, lisait/écrivait plusieurs champs directement (ex. un widget composite qui touchait 2-3 clés de state en même temps) ne peut PAS être porté tel quel derrière ce seam : il doit être **redécoupé** en un champ = une tranche, avec toute logique cross-champ déplacée vers les seams dédiés déjà existants (`ZcrudScope.relationSourceRegistry`/`choicesSourceRegistry`, ou des `ZFieldSpec.validators` inter-champs) — PAS bricolée dans le builder du registre.
2. **Le registre ne peut PAS remplacer un widget de famille de base** (§6 dernier paragraphe) — si un besoin de parité DODLP porte sur un type déjà natif zcrud_core (ex. reproduire pixel-exact le `select` DODLP), le seam `ZWidgetRegistry` est **inapplicable**; il faudrait soit accepter le widget natif zcrud_core (déjà écrit, à valider en parité visuelle par une autre lentille), soit une story zcrud modifiant `familyOf`/ajoutant un mécanisme d'override par famille — décision d'architecture hors périmètre satellite.
3. **Collision de `kind`** : si deux satellites tentent d'enregistrer le même `EditionFieldType.name` (ex. un satellite DODLP-compat et `zcrud_markdown` enregistrent tous deux `'richText'`), `ZWidgetRegistry.register` **throw** au bootstrap — c'est un fail-fast voulu (AD-3), mais impose à l'app hôte (DODLP migré) de composer l'enregistrement une seule fois par `kind`, jamais deux registrations concurrentes du même type.
4. **`icon` et `stepper`** n'ont aujourd'hui **aucun** widget (ni natif, ni satellite connu dans ce monorepo) — un besoin de parité DODLP sur ces deux types resterait au repli `ZUnsupportedFieldWidget` tant qu'aucun satellite ne les enregistre (`icon`) ou que `E3-5` ne livre le widget stepper natif.
5. **Poids du contrôleur lourd DODLP porté** : le patron `zcrud_markdown` montre qu'un controller lourd (Quill) est acceptable dans un satellite tant qu'il est isolé (AD-7) — mais un package DODLP entier réutilisé « tel quel » pourrait tirer des dépendances non alignées avec les packages déjà choisis par zcrud pour le même domaine (ex. DODLP pourrait avoir un package de markdown/carte différent de celui déjà intégré dans `zcrud_markdown`/`zcrud_geo`) — risque de **doublon de dépendance lourde** à trancher lentille par lentille (hors portée recon).

## 11. Questions ouvertes

- Le mapping §6 suppose que `z_html_registration.dart` enregistre bien `html`/`inlineHtml` — confirmé par le nom du fichier et le grep (2 appels `.register(` lignes 49 et 53) mais le contenu détaillé n'a pas été lu ligne à ligne dans cette lentille (hors budget de cette recon, non bloquant pour le contrat documenté ici qui est indépendant du contenu de ce fichier précis).
- Reste à trancher (autres lentilles) : pour chaque type DODLP à porter, la décision « widget natif zcrud_core déjà suffisant » vs « nécessite un builder `ZWidgetRegistry` dédié » — cette recon fournit le contrat, pas l'inventaire de parité champ-par-champ.

---

## Commandes de vérification exécutées (traçabilité)

```
$ grep -rn "\.register(" /home/zakarius/DEV/zcrud/packages/*/lib
RC=0  (17 occurrences, cf. tableau §4)
```

Tous les autres fichiers cités ont été lus intégralement ou par extraits ciblés via l'outil `Read` (chemins absolus donnés en tête de chaque section) — pas de `grep | head` utilisé pour une preuve d'absence dans ce rapport.
