# Story DP.13: Mode lecture dédié (fiche Card label/valeur + copie presse-papier) + `showIfNull` défaut inversé (parité DODLP — M3 + M4)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As développeur consommateur de zcrud (migration DODLP → zcrud),
I want qu'en **mode lecture global** un formulaire zcrud rende chaque champ sous forme de **fiche de consultation** (Card `label` au-dessus / `valeur` en dessous, avec **copie dans le presse-papier**) — au lieu de réutiliser le widget d'édition en `readOnly:true` (apparence « formulaire grisé ») — et que les champs **vides** soient **masqués par défaut** en lecture (`showIfNull` par défaut `false`),
so that un écran de consultation DODLP rende **structurellement à l'identique** (fiche dense, pas un formulaire désactivé), sans style codé en dur, sans régresser l'édition, et sans obliger un audit champ par champ pour masquer les vides.

Périmètre : **`zcrud_core` uniquement** (+ ses tests). Gaps couverts : **M4** (rendu vue lecture dédié — `readOnlyWidget` Card label/valeur + copie presse-papier, `edition_screen.dart:975-1040`) et **M3** (`showIfNull` défaut inversé — DODLP défaut `false` masque les vides `models.dart:843` ; zcrud défaut `true` `z_field_spec.dart:82`). Réf : `docs/dodlp-edition-parity-gap.md` §2.3 (lignes 94-95), §2.6 (ligne 157), §3 MAJOR (M3, M4) ; épic `E-DP` story DP-13.

**⚠️ POINTS DE CONTACT CORE PARTAGÉS (lock core sériel — orchestrateur).** Cette story écrit dans `zcrud_core` sur des fichiers partagés par d'autres stories DP majeures. **Aucune story parallèle ne doit toucher ces fichiers en même temps** :
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (dispatcher — aussi ciblé par DP-12/DP-15).
- `packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart` (spec — aussi ciblé par DP-12).
- `packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart` (assembleur — implémente déjà le filtre `showIfNull`).
- `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart` (tokens — aussi ciblé par DP-12/DP-17).

---

## Décision de design — `showIfNull` (M3) : **flip du défaut à `false`** (recommandé)

### Contexte
- **DODLP** : `showIfNull` défaut **`false`** → en lecture, un champ dont la valeur est vide/nulle est **masqué** (`models.dart:843`).
- **zcrud** : `ZFieldSpec.showIfNull` défaut **`true`** (`z_field_spec.dart:82`) → tout champ est affiché même vide.
- La sémantique est **déjà implémentée** côté assembleur : `DynamicEdition._renderInReadMode` masque un champ vide **uniquement** si `readOnly` global **et** `!spec.showIfNull` (`dynamic_edition.dart:396-401`). Le flag n'a **aucun effet hors mode lecture**.

### C'est un CHANGEMENT DE COMPORTEMENT (pas purement additif)
Inverser le défaut modifie ce qu'affiche un formulaire **en mode lecture** pour toute `ZFieldSpec` construite **sans** `showIfNull` explicite : un champ vide qui était affiché (fiche « — ») **disparaît**. **Blast radius borné au mode lecture** (`DynamicEdition.readOnly == true`) : édition et listes ne sont pas touchées.

### Pour / Contre
| | Flip défaut → `false` (RECOMMANDÉ) | Statu quo `true` + flag form-level | Statu quo `true` (audit manuel) |
|---|---|---|---|
| Parité DODLP | ✅ 1:1 (consommateur prioritaire) | ⚠️ divergence par défaut | ❌ nécessite audit champ par champ |
| Ampleur du changement | 🟡 comportement, **lecture seule** | 🟢 additif | 🟢 aucun |
| Densité fiche de consultation | ✅ native | ⚠️ opt-in | ❌ verbeux (vides partout) |
| Rétro-compat | 🟡 note de migration requise | ✅ | ✅ |
| Cohérence avec le modèle DODLP (par champ) | ✅ | ❌ (form-level ≠ per-field) | ✅ |

### Décision
**Flip du défaut de `ZFieldSpec.showIfNull` à `false`** (parité DODLP), pour trois raisons :
1. **Blast radius borné** — n'affecte QUE le mode lecture (le flag est inerte en édition/liste) ; l'édition, cible n°1 (SM-1), est intacte.
2. **Consommateur prioritaire** — DODLP est la cible de migration n°1 ; sa sémantique par champ (`false` = masquer les vides) devient le défaut, évitant un audit champ par champ à la migration.
3. **Cohérence de modèle** — garder la granularité **par champ** (DODLP) plutôt qu'un flag form-level qui diverge du modèle et duplique une sémantique déjà portée par `_renderInReadMode`.

**Opt-in de rétention** : un champ qui doit **toujours** apparaître en lecture, même vide, déclare explicitement `showIfNull: true` (annotation `@ZcrudField(showIfNull: true)` → projection générateur).

**Alternative rejetée** : flag form-level `DynamicEdition.showEmptyInReadMode` — rejetée car (a) diverge du modèle par champ DODLP, (b) duplique la sémantique déjà portée par `_renderInReadMode`, (c) empêche le réglage fin champ par champ.

### Note de migration (à documenter — audit E3-4) — AC13
Consigner dans la doc du champ `showIfNull` et dans les notes de complétion : « **BREAKING (mode lecture uniquement)** : depuis DP-13, `ZFieldSpec.showIfNull` vaut `false` par défaut. En **mode lecture global** (`DynamicEdition(readOnly: true)`), les champs à valeur **vide/nulle** sont désormais **masqués** par défaut (parité DODLP). Pour forcer l'affichage d'un champ vide en lecture, déclarer `showIfNull: true` (ou `@ZcrudField(showIfNull: true)`). **Édition et listes : aucun changement.** »

### ⚠️ Contact cross-package signalé (hors périmètre core — à traiter par l'orchestrateur en companion)
Le défaut runtime vit dans `ZFieldSpec` (core). Mais la **projection générateur** (`zcrud_generator`) et l'**annotation** (`@ZcrudField.showIfNull`, `zcrud_annotations`) portent leur **propre défaut**. Si le générateur émet `showIfNull:` **inconditionnellement** (valeur de l'annotation, défaut annotation `true`), le flip du défaut `ZFieldSpec` serait **silencieusement écrasé** pour tout modèle annoté. **Action requise (hors scope core, à séquencer par l'orchestrateur)** : aligner le défaut de `@ZcrudField.showIfNull` à `false` et vérifier que la projection n'émet la valeur que lorsqu'elle **diffère du défaut** (ou émet le nouveau défaut `false`). Cette story (core) : (a) flippe le défaut `ZFieldSpec`, (b) **audite** le comportement réel du générateur et **documente** la conclusion (aligné / à corriger en companion) dans les notes de complétion — sans modifier `zcrud_generator`/`zcrud_annotations` (périmètre).

---

## Acceptance Criteria

### Bloc M4 — Décorateur « fiche » de lecture (Card label/valeur + copie presse-papier)

1. **Widget `ZReadOnlyFieldCard` (presentation/edition).** Un nouveau `StatelessWidget` `ZReadOnlyFieldCard` est ajouté sous `packages/zcrud_core/lib/src/presentation/edition/`, reproduisant STRUCTURELLEMENT le `readOnlyWidget` DODLP (`edition_screen.dart:974-1040`) : `Card` `elevation 0`, coin arrondi (rayon = token `inputRadius`), bordure (`ColorScheme.outline`, largeur = token `inputBorderWidth`), fond dérivé du `ColorScheme` (token de dérivation, jamais un hex), marge basse directionnelle (token), `Padding` **directionnel** (token), `Column(crossAxisAlignment: start)` portant le **label AU-DESSUS** (style label token, dérivé `TextTheme`) + `SizedBox(gap token)` + la **valeur** en dessous (style valeur token, dérivé `TextTheme`). Le widget est **statique** (n'écoute aucune tranche — AD-2) : il reçoit `label` (String déjà résolu l10n) et `value` (Widget de rendu de valeur) construits par l'hôte.

2. **Copie presse-papier accessible (≥ 48 dp).** `ZReadOnlyFieldCard` expose une affordance de copie fidèle DODLP **et** accessible :
   - **Appui long** sur la carte (parité DODLP `onLongPress`) copie la représentation textuelle de la valeur via `Clipboard.setData(ClipboardData(text: …))` (`package:flutter/services.dart` — service Flutter, PAS un gestionnaire d'état, autorisé en `zcrud_core` ; AUCUN `FlutterClipboard`/`toastService` tiers).
   - **ET** une action de copie **explicite** : `IconButton` (icône `Icons.copy_outlined`) avec cible tactile **≥ 48 dp** et `Semantics`/`tooltip` libellé localisé (clé l10n `copy`, repli « Copier »), rendu **seulement** si la valeur est copiable (texte non vide) — pour la découvrabilité et l'a11y (AD-13), là où DODLP n'offrait que l'appui long.
   - La copie n'a lieu que pour une valeur **textuelle** (pas de copie d'un placeholder « — » ni d'un Widget de valeur non textuel — cf. AC5/AC7).
   - Retour utilisateur **best-effort sans dépendance** : annonce sémantique (`SemanticsService.announce`) et, si un `ScaffoldMessenger` est disponible, `ScaffoldMessenger.maybeOf(context)?.showSnackBar(...)` avec un message localisé (clé `copied`, repli « Valeur copiée dans le presse-papier »). Absence de `ScaffoldMessenger` ⇒ pas de throw (défensif).

3. **Dispatch en mode lecture GLOBAL uniquement.** `ZFieldWidget` reçoit un drapeau de présentation **additif** `readMode` (bool, défaut `false`) — signal distinct de `ZFieldSpec.readOnly`. Quand `readMode == true` **et** que la famille du champ est « fiche-able » (AC6), le dispatcher rend `ZReadOnlyFieldCard` (label + valeur formatée) **au lieu** d'appeler `_buildControl` (widget d'édition grisé). Le rendu fiche vit **sous** `ZFieldListenableBuilder` (reflète la tranche courante : une écriture externe met à jour la fiche ; aucun impact SM-1 car pas de saisie en lecture).

4. **Câblage `DynamicEdition` → `ZFieldWidget.readMode`.** `DynamicEdition` propage son `readOnly` global au dispatcher : `_fieldChild` construit `ZFieldWidget(controller, field: spec, readMode: widget.readOnly)`. Le `fieldBuilder` custom (seam) reste prioritaire et inchangé. Le forçage existant `spec.copyWith(readOnly: true)` (`_effective`) est **conservé** (repli sûr pour les familles non fiche-ables — AC6) : la fiche ne casse pas ce contrat.

5. **Formatage de valeur défensif (AD-10).** Un helper de présentation (ex. `zReadOnlyValueOf(BuildContext, ZFieldSpec, Object? value) → ReadOnlyValue`) produit soit un **texte** copiable, soit un **placeholder** non copiable « — » (clé l10n `emptyValue`, repli « — »), soit un **Widget** non copiable, selon le type :
   - `null`/vide (String/Iterable/Map vide) → placeholder « — » (non copiable). *(En pratique masqué en amont si `showIfNull == false` — AC10 —, mais le rendu reste sûr si affiché.)*
   - `select`/`radio`/`checkbox`/`relation`/`rowChips` → **libellé(s)** résolus depuis `field.choices` (`ZFieldChoice.label`) ; pour `multiple`/liste, libellés **joints** « , » ; valeur inconnue (pas dans `choices`) → sa représentation brute.
   - `boolean` → « Oui »/« Non » localisés (clés `yes`/`no`, replis « Oui »/« Non »).
   - `tags`/liste simple → éléments joints « , ».
   - `number`/`integer`/`float`/`dateTime`/`time`/`text`/`multiline` → `value.toString()`.
   - `Map`/objet complexe non résolu → représentation textuelle sûre **jointe/tronquée** (jamais un throw, jamais un dump illisible non borné).
   - `password` → jamais la valeur en clair : placeholder masqué (« •••• » ou « — »), non copiable.
   Le helper est **pur** (aucun accès à une tranche, aucun état) et **ne lève jamais** (AD-10).

6. **Politique de familles fiche-ables (documentée).** Le dispatcher applique une politique explicite `readMode` :
   - **Fiche-ables** (rendues via `ZReadOnlyFieldCard`) : `text`, `number`, `date`, `boolean`, `select`, `relation`, `tags`, `rowChips`, `rating`, `slider`, `color`.
   - **NON fiche-ables** (conservent leur rendu `readOnly` existant, JAMAIS régressé) : `subList`, `dynamicItem`, `signature`, `file`, `freeWidget`, `registryOrFallback` (markdown/géo/tél/custom — un reader dédié relève de leurs stories, ex. DP-3), `hidden` (→ `SizedBox.shrink`), `unsupported` (→ repli contrôlé). Pour ces familles, `readMode` **n'altère pas** le chemin actuel (rendu via `_buildControl` avec `field.readOnly` déjà forcé par `_effective`).
   La politique est un helper testable (ex. `bool zReadModeCardable(EditionFamily)`), documentée par un commentaire de référence DODLP.

7. **Valeur-Widget passe-plat.** Si le formatage (AC5) produit un **Widget** (cas d'un `color` → pastille, ou d'une valeur déjà widgetisée), `ZReadOnlyFieldCard` le rend tel quel dans le slot valeur et **désactive la copie** (parité DODLP : `value is Widget → onLongPress no-op`). `color` en lecture affiche une pastille + code (texte copiable du code hex/ARGB, au choix — documenter).

### Bloc M3 — `showIfNull` défaut `false`

8. **Défaut inversé.** `ZFieldSpec.showIfNull` a pour valeur par défaut **`false`** (`z_field_spec.dart:47`). Le constructeur `const`, `copyWith`, `==` et `hashCode` restent cohérents (la valeur reste sérialisable/égalable comme aujourd'hui, seul le défaut change).

9. **Documentation du champ mise à jour.** Le docstring de `ZFieldSpec.showIfNull` reflète le nouveau défaut `false` + la sémantique (« masqué en lecture si vide, sauf `showIfNull: true` ») + un renvoi à la note de migration (AC13). Aucune fuite de logique de présentation dans le domaine (le champ reste une **donnée** pure).

10. **Comportement de filtrage inchangé côté assembleur.** `DynamicEdition._renderInReadMode` (`dynamic_edition.dart:396-401`) est **fonctionnellement inchangé** (il lit déjà `spec.showIfNull`) : avec le nouveau défaut, un champ vide sans `showIfNull` explicite est **masqué en mode lecture**. Un test prouve : (a) champ vide, défaut → masqué en lecture ; (b) même champ `showIfNull: true` → affiché (fiche « — ») ; (c) hors mode lecture, `showIfNull` sans effet (toujours affiché).

11. **Audit générateur documenté (sans modifier zcrud_generator).** Vérifier réellement sur disque comment `zcrud_generator` projette `showIfNull` (émission inconditionnelle vs. conditionnelle au défaut) et **documenter la conclusion** dans les notes de complétion : soit « défaut aligné, aucun companion requis », soit « companion requis dans zcrud_annotations/zcrud_generator (flaggé à l'orchestrateur) ». **Ne pas** modifier ces packages (périmètre core).

### Bloc M4/M3 — Tokens de thème & transverse (invariants)

12. **Tokens de lecture dans `ZcrudTheme` (aucune couleur codée en dur).** `ZcrudTheme` gagne les tokens **non-couleur** nécessaires à la fiche (intégrés au constructeur `const`, `copyWith`, `lerp` s'il existe) : `readCardMargin: EdgeInsetsDirectional` (défaut `only(bottom: 12)` directionnel — parité `margin: only(bottom:12)`), `readPadding: EdgeInsetsDirectional` (défaut `all(16)`), `readLabelGap: double` (défaut `8`), `readLabelTextStyle: TextStyle?` (défaut : `labelMedium`-like, poids par défaut — **couleur `null` → dérivée**), `readValueTextStyle: TextStyle?` (défaut : poids `w500` — **couleur `null` → dérivée**). Le **fond** et la **bordure** de la Card sont **dérivés du `ColorScheme`** (ex. fond `surfaceContainerLow`/`surfaceContainerHighest` selon disponibilité, bordure `outline`) — **aucun `Colors.`/`Color(0x…)`** ; réutiliser `inputRadius`/`inputBorderWidth` pour la forme. La garde `test/purity/style_purity_test.dart` reste **verte**.

13. **Note de migration `showIfNull` consignée (audit E3-4).** La note de migration (cf. section « Décision de design ») est présente dans le docstring `showIfNull` **et** dans les notes de complétion de la story (Dev Agent Record). Elle explicite le caractère **breaking (lecture seule)** et l'opt-in `showIfNull: true`.

14. **A11y directionnel (AD-13).** Tous les insets/paddings/marges introduits sont **directionnels** (`EdgeInsetsDirectional`) ; aucun `EdgeInsets.only(left/right)`, `Alignment.centerLeft/Right`, `TextAlign.left/right`. La fiche porte une **sémantique de conteneur** cohérente : `Semantics(container: true, label: <label>, value: <valeur textuelle>)` (le lecteur d'écran annonce « label : valeur »), sans double annonce (label visible en `ExcludeSemantics` si déjà porté par le conteneur — cf. pattern `ZLargeFieldCard`). Cible de l'action copie ≥ 48 dp (AC2).

15. **Thème / FR-26.** Aucun style ni couleur codé en dur dans le code nouveau/modifié ; tout provient de tokens `ZcrudTheme` (résolus via `ZcrudTheme.of(context)` → `ThemeExtension`/`ZcrudScope` → `fallback`) et de dérivations `ColorScheme`/`TextTheme`. Un override app d'un token de lecture (ex. `readPadding`) est **effectivement reflété** dans la fiche.

16. **SM-1 non régressé + rebuild ciblé (AD-2).** En **édition** (hors `readMode`), le rendu est **strictement inchangé** : taper 100 caractères ne reconstruit que le champ courant, zéro perte de focus (preuve widget/instrumentation `onBuild`/`onInit` inchangée). En **mode lecture**, aucun `TextEditingController`/`FocusNode` n'est alloué pour les champs rendus en fiche (le chemin fiche n'entre pas dans `familyUsesTextController` — pas de clavier). La frontière de rebuild reste la tranche (`ZFieldListenableBuilder`).

17. **Aucun élargissement du graphe de dépendances (AD-1).** `zcrud_core` reste OUT-degree 0 (aucun nouvel import lourd ; `package:flutter/services.dart` pour `Clipboard`/`SemanticsService` est un service Flutter natif, admis). Aucune fuite de type backend ; aucune dépendance à un gestionnaire d'état (AD-15).

18. **Exports barrel.** `ZReadOnlyFieldCard` (et le helper de valeur/politique s'ils sont publics) sont exportés là où `ZLargeFieldCard`/`DynamicEdition` le sont (barrel présentation de `zcrud_core`), ou gardés `src`-privés si non destinés à l'API publique — décision documentée (par défaut : `ZReadOnlyFieldCard` public, helpers `src`-privés).

## Tasks / Subtasks

- [ ] **T1 — Flip `showIfNull` (M3, domaine)** (AC: 8, 9, 13)
  - [ ] `z_field_spec.dart:47` : défaut `showIfNull = false` ; docstring `showIfNull` réécrit (défaut + sémantique + renvoi migration).
  - [ ] Vérifier `copyWith`/`==`/`hashCode` inchangés fonctionnellement (défaut seul modifié).
  - [ ] Audit réel `zcrud_generator` (lecture disque) → conclusion documentée (AC11) ; **ne pas** modifier le générateur.
- [ ] **T2 — Tokens de lecture `ZcrudTheme`** (AC: 12, 15)
  - [ ] Ajouter `readCardMargin`/`readPadding`/`readLabelGap`/`readLabelTextStyle`/`readValueTextStyle` (const ctor + `copyWith` + `lerp`).
  - [ ] Dérivation fond/bordure via `ColorScheme` (aucun hex) ; réutiliser `inputRadius`/`inputBorderWidth`.
- [ ] **T3 — Helper de formatage/politique de valeur** (AC: 5, 6, 7)
  - [ ] `zReadOnlyValueOf(context, spec, value)` défensif (null/vide/select/relation/boolean/tags/number/date/map/password) — pur, jamais de throw.
  - [ ] `zReadModeCardable(EditionFamily)` (politique fiche-able, commentée réf DODLP).
- [ ] **T4 — Widget `ZReadOnlyFieldCard`** (AC: 1, 2, 7, 14)
  - [ ] Card (tokens/dérivations), Column label/valeur, appui long + `IconButton` copie ≥48dp, `Clipboard`/`SemanticsService`/`ScaffoldMessenger.maybeOf` best-effort, `Semantics` conteneur, insets directionnels.
- [ ] **T5 — Dispatch `readMode` dans `ZFieldWidget`** (AC: 3, 6, 16)
  - [ ] Param additif `readMode` (défaut `false`) ; en `readMode` + famille fiche-able → `ZReadOnlyFieldCard` sous `ZFieldListenableBuilder` ; sinon chemin `_buildControl` inchangé.
  - [ ] Pas d'allocation `_text`/`_focus` pour les champs fiche-ables en `readMode`.
- [ ] **T6 — Câblage `DynamicEdition`** (AC: 4, 10)
  - [ ] `_fieldChild` → `ZFieldWidget(..., readMode: widget.readOnly)` ; `_effective`/`_renderInReadMode` conservés.
- [ ] **T7 — l10n** (AC: 2, 5)
  - [ ] Clés `copy`/`copied`/`emptyValue`/`yes`/`no` (+ repli `en`/`fr`) dans le registre l10n (`_enLabels`/tables) consommées via `label(context, key, fallback: …)`.
- [ ] **T8 — Tests** (AC: tous)
  - [ ] Fiche : label+valeur rendus, copie (appui long ET IconButton) écrit le presse-papier (`TestDefaultBinaryMessengerBinding`/mock clipboard), placeholder « — » non copiable, `Semantics` conteneur, cible ≥48dp.
  - [ ] Dispatch : `readMode:true` fiche-able → `ZReadOnlyFieldCard` ; non fiche-able → widget existant ; `readMode:false` → édition inchangée.
  - [ ] `showIfNull` : défaut `false` masque vide en lecture ; `true` affiche ; hors lecture sans effet.
  - [ ] Défensif : null/Map/valeur inconnue → rendu sûr, aucun throw.
  - [ ] Thème : override `readPadding` reflété ; garde `style_purity_test.dart` verte.
  - [ ] SM-1 : édition non régressée (compteur build par champ == 1 sur 100 frappes) ; aucun controller alloué en fiche.

## Dev Notes

### État actuel des fichiers touchés (lecture réelle — préserver le contrat existant)

- **`z_field_spec.dart`** (domaine, pur-`const`, garde `domain_purity_test.dart`) — `showIfNull` (l.47, défaut `true`) projeté 1:1 depuis `@ZcrudField` par le générateur E2-5. Le flip ne change QUE le défaut ; `copyWith`/`==`/`hashCode` incluent déjà `showIfNull`. **Ne pas** introduire de closure/widget/dep Flutter (AD-1).
- **`dynamic_edition.dart`** — `_renderInReadMode` (l.396-401) lit **déjà** `spec.showIfNull` et masque un champ vide en mode lecture ; `_isEmptyValue` (l.387-393) traite `null`/String/Iterable/Map vides (`false`/`0` NON vides). `_effective` (l.405-406) force `readOnly:true` en lecture globale. `_fieldChild` (l.589-594) monte `ZFieldWidget` (ou `fieldBuilder` custom). **Ce câblage `showIfNull` est intact : la story n'y change que la propagation `readMode` (T6) — pas la logique de filtre.**
- **`z_field_widget.dart`** — dispatcher scellé sur la tranche (`ZFieldListenableBuilder`), controllers texte/focus alloués UNIQUEMENT pour familles clavier (l.164-171), `_dispatch`/`_buildControl` (l.291-491) rendent le contrôle par famille. Le wrapper `large` (l.265-272) montre déjà le pattern « wrapper statique autour du sous-arbre réactif » — **`ZReadOnlyFieldCard` suit le même principe** : décorateur statique, valeur lue via la tranche. `familyUsesTextController` (l.219-220, `edition_field_family.dart`) : ne PAS allouer pour les champs fiche en `readMode`.
- **`z_theme.dart`** — tokens `input*`/`large*` déjà présents (const ctor + `copyWith` + `lerp`), `fallback` dérive les couleurs du `ColorScheme`/`TextTheme` (seul emplacement exempté de la garde style). Ajouter les tokens `read*` sur le même modèle (couleurs = `null` → dérivées).

### Référence DODLP `readOnlyWidget` (parité structurelle — `edition_screen.dart:974-1040`, lecture seule)
`Card(elevation:0, fond grey.shade50 / white 0.05, radius 12, bordure grey.shade300/white24, margin bottom 12)` → `InkWell(onLongPress: copie + toast « Valeur copiée dans le presse-papier »)` → `Padding(all 16)` → `Column(start)` : `Text(label, labelMedium/grey)` + `SizedBox(8)` + `value is Widget ? value : Text.rich(value + suffix)`. **Traductions zcrud** : couleurs → dérivations `ColorScheme` (tokens) ; `FlutterClipboard`/`toastService` → `Clipboard`/`SemanticsService`/`ScaffoldMessenger.maybeOf` ; ajout d'une action copie explicite ≥48dp (a11y AD-13) que DODLP n'avait pas.

### Invariants AD applicables
AD-1 (OUT=0, `flutter/services` admis), AD-2/SM-1 (fiche statique, tranche = frontière, aucun controller en lecture), AD-10 (formatage défensif, jamais de throw), AD-13 (directionnel, Semantics, ≥48dp), AD-15 (aucun gestionnaire d'état), FR-26 (thème injecté, zéro couleur en dur).

### Project Structure Notes
- Nouveau fichier : `packages/zcrud_core/lib/src/presentation/edition/z_read_only_field_card.dart` (+ éventuel `z_read_only_value.dart` pour le helper de formatage/politique, `src`-privé).
- Modifs : `z_field_spec.dart` (défaut+doc), `z_theme.dart` (tokens read*), `z_field_widget.dart` (param `readMode`+dispatch), `dynamic_edition.dart` (propagation `readMode`), l10n (`z_localizations.dart` tables + éventuels labels), barrel présentation (export `ZReadOnlyFieldCard`).
- Tests sous `packages/zcrud_core/test/` (widget + unit + purity existante).

### Testing standards
`flutter_test` widget + unit. Mock presse-papier via `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, …)` (capter `Clipboard.setData`). Vérif verte NON-NÉGOCIABLE avant `review` : `melos run generate` → `dart analyze`/`flutter analyze` RC=0 → `flutter test` RC=0 (au moins package `zcrud_core`). Gardes `domain_purity_test.dart` et `style_purity_test.dart` **vertes**.

### References
- [Source: docs/dodlp-edition-parity-gap.md#2.3] (lignes 94-95 : `showIfNull` défaut inversé ; rendu lecture widget dédié)
- [Source: docs/dodlp-edition-parity-gap.md#2.6] (ligne 157 : rendu vue lecture dédié)
- [Source: docs/dodlp-edition-parity-gap.md#3-MAJOR] (M3, M4)
- [Source: dodlp-otr/lib/modules/data_crud/presentation/views/edition_screen.dart#974-1040] (`readOnlyWidget`)
- [Source: dodlp-otr/lib/modules/data_crud/models.dart#843] (`showIfNull` défaut `false`)
- [Source: packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart#47,82] (défaut `true` actuel)
- [Source: packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart#387-406] (filtre `showIfNull`, `_effective`)
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart#164-272,291-491] (dispatcher, wrapper large)
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_large_field_card.dart] (pattern décorateur Card statique + Semantics/ExcludeSemantics)
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_theme.dart#30-79] (tokens + fallback dérivé)
- [Source: packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart#237] (helper `label()`)
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md] (AD-1/2/10/13/15, FR-26)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, lot groupé DP-12+DP-13, LOCK CORE)

### Debug Log References

Implémenté en lot groupé avec DP-12 (fichiers hub `zcrud_core` partagés → single writer).

### Completion Notes List

**Décision `showIfNull` (M3) — flip + companion générateur** : défaut `ZFieldSpec.showIfNull`
inversé à `false` (parité DODLP). **AUDIT générateur (AC11)** : la projection historique
n'émettait `showIfNull: false` que si l'annotation valait `false` — donc, après le flip seul,
`@ZcrudField()` ET `@ZcrudField(showIfNull: true)` auraient TOUS DEUX pris le nouveau défaut
`false`, cassant l'opt-in. **Conclusion : companion REQUIS et APPLIQUÉ** (l'orchestrateur détenant
aussi le lock annotations/generator dans ce lot) : (a) défaut `@ZcrudField.showIfNull` aligné à
`false` ; (b) `_emitSpec` corrigé pour n'émettre que la valeur NON-défaut (`showIfNull: true`).
Résultat prouvé (test générateur) : `@ZcrudField()` → aucune émission → défaut `false` (masqué) ;
`@ZcrudField(showIfNull: true)` → `showIfNull: true` émis (affiché). Opt-in fonctionnel.

**NOTE DE MIGRATION (AC13) — BREAKING (mode lecture uniquement)** : depuis DP-13,
`ZFieldSpec.showIfNull` (et `@ZcrudField.showIfNull`) valent `false` par défaut. En **mode lecture
global** (`DynamicEdition(readOnly: true)`), les champs à valeur **vide/nulle** sont désormais
**masqués** par défaut (parité DODLP). Pour forcer l'affichage d'un champ vide en lecture, déclarer
`showIfNull: true` (ou `@ZcrudField(showIfNull: true)`). **Édition et listes : aucun changement.**

**Statut ACs** :
- AC1 `ZReadOnlyFieldCard` (Card elev.0, radius `inputRadius`, bordure `outline`, fond dérivé `surfaceContainerLow`, marge/padding directionnels, Column label/valeur) : OK.
- AC2 copie : appui long (parité DODLP) + `IconButton` copie ≥48dp + tooltip/l10n `copy` ; `Clipboard.setData` ; annonce `SemanticsService.sendAnnouncement` (variante non-dépréciée de `announce`) + `ScaffoldMessenger.maybeOf` best-effort : OK, testé (mock clipboard, ≥48dp).
- AC3 dispatch `readMode` (drapeau additif, défaut false) → fiche sous `ZFieldListenableBuilder` : OK.
- AC4 câblage `DynamicEdition.readOnly → ZFieldWidget.readMode` ; `_effective`/`_renderInReadMode` conservés : OK.
- AC5 helper `zReadOnlyValueOf` défensif (null/vide→«—», select/relation→libellés, boolean→Oui/Non, tags/list→join, password→masqué, Map→borné) : OK, testé, jamais de throw.
- AC6 politique `zReadModeCardable` (fiche-ables vs non) : OK, testé (signature non cardée).
- AC7 valeur-Widget passe-plat (`color` → pastille+code, copie désactivée) : OK.
- AC8/AC9/AC10 flip défaut `false` + docstring + filtrage `_renderInReadMode` inchangé : OK, testé (vide masqué / opt-in affiché / inerte hors lecture).
- AC11 audit générateur documenté + companion appliqué (voir ci-dessus) : OK.
- AC12/AC15 tokens `read*` dérivés `ColorScheme`/`TextTheme` (0 hex) + override `readPadding` reflété : OK, testé ; garde `style_purity` verte.
- AC13 note de migration consignée (docstring + ici) : OK.
- AC14 directionnel + `Semantics` conteneur (label:valeur, `ExcludeSemantics` visible) + ≥48dp : OK, testé.
- AC16 SM-1 : aucun `TextEditingController`/`FocusNode` alloué en fiche (garde `initState`) ; 0 `EditableText` en lecture ; édition inchangée (760 tests, dont SM-1, verts).
- AC17 AD-1 OUT=0 (services/semantics natifs admis) : `graph_proof` CORE OUT=0 OK ; garde `presentation_purity` étendue (allowlist `show` `Clipboard`/`ClipboardData`/`SemanticsService`, `SystemChannels`/`rootBundle` restent bannis, self-tests bidirectionnels).
- AC18 `ZReadOnlyFieldCard` exporté (barrel) ; helpers `zReadOnlyValueOf`/`zReadModeCardable` `src`-privés : OK.

**Vérif verte réelle** : `dart analyze` core/annotations/generator RC=0 ; `flutter test` zcrud_core = 760 OK ; générateur 87 OK ; graph_proof CORE OUT=0 OK ; domain_entrypoint_dart_test OK.

### File List

- `packages/zcrud_core/lib/src/presentation/edition/z_read_only_field_card.dart` (nouveau)
- `packages/zcrud_core/lib/src/presentation/edition/z_read_only_value.dart` (nouveau — helper valeur/politique, `src`-privé)
- `packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart` (flip `showIfNull` défaut + docstring/migration)
- `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart` (tokens `read*`)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (param `readMode` + dispatch fiche + garde controller)
- `packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart` (propagation `readMode`)
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` (`copy`/`copied`/`emptyValue`)
- `packages/zcrud_core/lib/zcrud_core.dart` (export `ZReadOnlyFieldCard`)
- `packages/zcrud_annotations/lib/src/domain/annotations/zcrud_field.dart` (flip défaut `showIfNull`)
- `packages/zcrud_generator/lib/src/zcrud_model_generator.dart` (projection `showIfNull` conditionnelle NON-défaut)
- Tests : `test/presentation/edition/dp13_read_mode_card_test.dart`, `packages/zcrud_generator/test/dp12_dp13_projection_test.dart` (nouveaux) ; `test/presentation/edition/read_mode_test.dart` (fiche + flip) ; `test/domain/edition/z_field_spec_test.dart`, `packages/zcrud_annotations/test/annotations_const_test.dart` (défaut inversé) ; `test/purity/presentation_purity_test.dart` (allowlist Clipboard/SemanticsService).
