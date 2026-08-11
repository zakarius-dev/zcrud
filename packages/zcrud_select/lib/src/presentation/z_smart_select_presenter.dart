/// Présentateur riche `ZSelectPresenter` adossé au fork vendorisé
/// `awesome_select` (`SmartSelect`), **apparence de référence** par défaut.
///
/// **Rôle** : implémentation CONCRÈTE du seam `ZSelectPresenter` (livré par le
/// cœur). Injectée via `ZcrudScope(selectPresenter: const
/// ZSmartSelectPresenter())`, elle **supplante** le rendu natif des familles
/// `select` / `radio` / `checkbox` / `multiselect` / `relation` par un
/// **modal S2 responsive + recherche**.
///
/// **« Par défaut » — ce que ça peut et ne peut pas vouloir dire.** L'invariant
/// AD-1 interdit à `zcrud_core` de dépendre de `zcrud_select` (CORE OUT = 0) :
/// le socle **ne peut pas** monter `awesome_select` de lui-même. « Par défaut »
/// ne signifie donc jamais « sans rien faire ». Ce qui est livré à la place :
///
/// 1. **l'enrôlement le plus court possible** — une seule expression `const`,
///    posée une fois pour toute l'application :
///    `ZcrudScope(selectPresenter: const ZSmartSelectPresenter(), …)` ;
/// 2. **une apparence de référence éprouvée comme défaut du présentateur** —
///    c'est *là* que « par défaut » a un sens réel : un hôte qui enrôle le
///    présentateur obtient ce rendu **sans rien configurer**. Toute la
///    personnalisation passe par [ZSelectTileSpec], qui est entièrement
///    optionnel.
///
/// **Zéro side-effect d'import** : aucun `register*()` top-level, aucune
/// mutation d'un registre global à l'import. Importer ce paquet ne change le
/// rendu de rien ; seule l'injection au scope le fait. C'est délibéré — un
/// enrôlement implicite rendrait le rendu dépendant de l'ordre des imports et
/// indébogable côté hôte.
///
/// **Isolation** : `SmartSelect` / `S2*` restent CONFINÉS sous
/// `lib/src/` — AUCUN type `awesome_select` ne fuit au barrel ni dans la
/// signature `present()` (neutre, `zcrud_core`). Les helpers de conversion
/// `ZFieldChoice → S2Choice` et `ZSelectChoiceStyle → S2ChoiceType` sont
/// **privés**.
///
/// **Invariant AD-2** : le présentateur ne touche JAMAIS le `ZFormController` ;
/// il lit la tranche via `presentation.selected` et **notifie** via
/// `presentation.onChanged` (valeur MÉTIER : scalaire en mono, `List` en
/// multi — jamais un type S2, jamais une concaténation littérale encodée
/// dans une chaîne). Il ne déclenche aucun `setState` de formulaire — un
/// rebuild global temporisé après chaque changement serait exactement le
/// défaut que l'objectif produit n°1 du dépôt corrige.
///
/// **Invariant AD-10 (défensif)** : options vides / `selected` hors options /
/// option `disabled` / spec absente → rendu **dégradé défini** (sélecteur vide
/// accessible / placeholder / option non cochable), jamais une exception.
///
/// **Invariant AD-13** : déclencheur avec une **seule** annonce accessible
/// (`Semantics(button:, label:, value:, enabled:)` + `excludeSemantics` sur
/// l'habillage), cible **≥ 48 dp**, couleurs dérivées du `ColorScheme` par
/// **rôles** (aucun littéral — table de correspondance dans
/// `z_select_tile_reference.dart`), insets et chevron **directionnels**.
/// Libellés d'options résolus via `label(context, ...)` (jamais la clé brute).
library;

import 'dart:math' as math;

import 'package:awesome_select/awesome_select.dart';
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_select_tile_metrics.dart';
import 'z_select_tile_reference.dart';

/// Présentateur riche `select`/`radio`/`checkbox`/`multiselect`/`relation`
/// au-dessus de `SmartSelect`, à l'**apparence de référence** par défaut.
///
/// `const`-constructible et **sans side-effect d'import** (aucun `register*()`
/// top-level) : l'enrôlement est **explicite** via `ZcrudScope.selectPresenter`.
/// Immuable ⇒ partageable en `const`.
class ZSmartSelectPresenter extends ZSelectPresenter {
  /// Constructeur `const` (présentateur immuable, injectable en `const`).
  ///
  /// [spec] surcharge **partiellement** l'apparence de référence. `null`
  /// (le défaut) ⇒ apparence de référence intégrale.
  const ZSmartSelectPresenter({this.spec});

  /// Surcharge par paramètre — maillon de plus haute priorité de la chaîne
  /// `paramètre > jeton (`ZcrudTheme.select*`) > référence`, désormais
  /// **complète** et résolue par `zSelectTileMetricsOf`.
  final ZSelectTileSpec? spec;

  @override
  Widget present(BuildContext context, ZSelectPresentation presentation) {
    // Titre du modal + déclencheur : label déjà résolu (l10n) sinon repli sur la
    // spéc du champ. TOUJOURS non-null (assert `SmartSelect`).
    final String title = presentation.label ??
        presentation.field.label ??
        presentation.field.name;

    // chaîne `paramètre > jeton > référence`, résolue UNE fois
    // pour tout le sous-arbre.
    final ZSelectTileMetrics metrics =
        zSelectTileMetricsOf(context, spec: spec);

    // AD-10 : projection défensive — options vides restent une `List` non-null
    // (assert `choiceItems != null`), aucune exception.
    //
    // Type-param `dynamic` (valeurs métier opaques) : `SmartSelect<dynamic>` a
    // pour `runtimeType` le littéral `SmartSelect` — indispensable pour la garde
    // de rendu `find.byType(SmartSelect)` (comparaison d'égalité de type).
    final List<S2Choice<dynamic>> choiceItems =
        _toS2Choices(context, presentation.options);

    final bool enabled = !presentation.readOnly;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    // `field.leading`, parité de référence (`ListTile.leading`).
    //
    // Cette capacité avait été rapportée « inatteignable, le DTO ne la porte
    // pas ». C'était FAUX : le DTO porte `field`, donc `field.leading`, et
    // `resolveAdornment` est exporté par le barrel de `zcrud_core`. Aucun
    // élargissement du seam n'était nécessaire — seulement de le lire.
    // Résolu ICI, pendant `build` (le résolveur consulte des `InheritedWidget`).
    // `null` ⇒ slot ABSENT de l'arbre (AD-4), rendu antérieur strictement
    // conservé pour tout champ sans ornement de tête.
    final Widget? leading = resolveAdornment(
      context,
      presentation.field.leading,
      field: presentation.field,
    );

    // règle d'inertie EXACTE de référence :
    // `choiceBuilder == null && (readOnly || isLoading) ? null : showModal`.
    // Autrement dit un `choiceBuilder` RÉ-ACTIVE le déclencheur, y compris en
    // lecture seule : c'est le seul rendu possible de la donnée, il faut
    // pouvoir l'atteindre.
    //
    // Hôte passif : avec les défauts du seam (`isLoading: false`,
    // `choiceBuilder: null`), cette expression vaut `!readOnly` — exactement
    // l'ancienne règle. Rien ne bouge.
    final bool tappable = presentation.choiceBuilder != null ||
        (!presentation.readOnly && !presentation.isLoading);

    // barre d'actions du modal : ACTIVE par défaut (parité
    // de référence). Un hôte peut la couper (`ZSelectTileSpec.showModalActions:
    // false`) pour retrouver les seules actions par défaut du fork.
    final bool showActions = spec?.showModalActions ?? true;

    // chargeur asynchrone d'options, ENVELOPPÉ (AD-10).
    final S2ChoiceLoader<dynamic>? choiceLoader =
        _wrapLoader(context, presentation);

    // FR-26 : placeholder de l'état vide LOCALISÉ via la l10n injectée (clé
    // `select`, résolue en/fr par `ZcrudLocalizations`) — JAMAIS le littéral
    // anglais `'Select one'` / `'Select one or more'` du fork. Passé à
    // `SmartSelect` (paramètre `placeholder:`) ET employé directement dans le
    // déclencheur, pour que le libellé anglais du fork ne surface nulle part.
    //
    // `field.hintText` **et** `isLoading` se déversent ICI, et
    // nulle part ailleurs, parce que c'est la place que leur donne le rendu
    // NATIF :
    //
    // * `hintText` est, dans `zFieldDecoration`, le texte de l'ÉTAT VIDE
    //   (`InputDecoration.hintText`) — exactement ce qu'est le placeholder du
    //   tile. Aucun autre slot de la tuile n'a ce sens.
    // * `isLoading` : le natif de `relation` écrit
    //   `hintText: label(loading ? 'loading' : 'select')` — le chargement
    //   l'emporte donc sur le hint, et « je n'ai pas encore les options » cesse
    //   de se confondre avec « il n'y a rien à choisir ».
    //
    // Hôte passif : sans `hintText` et sans chargement, l'expression vaut
    // `label(context, 'select')` — le littéral d'avant, au caractère près.
    final String? hintText = presentation.field.hintText == null
        ? null
        : label(context, presentation.field.hintText!,
            fallback: presentation.field.hintText!);
    final String placeholder = presentation.isLoading
        ? label(context, 'loading')
        : (hintText ?? label(context, 'select'));

    // `field.helperText` : ligne d'aide PERSISTANTE que le
    // natif rend SOUS le champ (`InputDecoration.helperText`), en plus du
    // contenu et jamais à sa place. Son équivalent en tuile est donc une ligne
    // de plus au BAS du sous-titre — surtout pas le sous-titre lui-même, qui
    // porte déjà la valeur ou les puces (l'y écraser aurait été une régression
    // déguisée en correctif). `null` ⇒ aucun nœud ajouté (AD-4).
    final String? helperText = presentation.field.helperText == null
        ? null
        : label(context, presentation.field.helperText!,
            fallback: presentation.field.helperText!);

    // ornements `prefix`/`suffix`. Le natif les pose DANS le
    // champ, de part et d'autre du CONTENU (`prefix`/`prefixIcon` et
    // `suffix`/`suffixIcon` de l'`InputDecoration`), pas dans ses marges : la
    // tête hors bordure est le slot `icon`, déjà occupé ici par `leading`, et la
    // fin de ligne du tile est occupée par le chevron. L'équivalent est donc la
    // ligne du sous-titre, qui porte la valeur.
    //
    // Comme `leading`, ces deux membres étaient **déjà atteignables** via
    // `presentation.field` : aucun élargissement du seam n'était nécessaire —
    // seulement de les lire. `null` ⇒ slot ABSENT de l'arbre (AD-4).
    final Widget? prefix = resolveAdornment(
      context,
      presentation.field.prefix,
      field: presentation.field,
    );
    final Widget? suffix = resolveAdornment(
      context,
      presentation.field.suffix,
      field: presentation.field,
    );

    // AD-13 — un ornement `.text` porte de l'INFORMATION (« € », « % », « kg »)
    // et le natif la fait lire : elle vit dans l'arbre sémantique de
    // l'`InputDecorator`. Le tile, lui, n'a qu'UNE annonce (`excludeSemantics:
    // true` écarte tous les descendants) : sans reprise explicite, ce texte
    // serait visible et JAMAIS annoncé — un canal purement visuel. Les
    // ornements `.icon`/`.widget` n'ont pas de texte à reprendre ; ils restent
    // décoratifs, exactement comme dans le natif.
    final String? prefixText =
        _adornmentText(context, presentation.field.prefix);
    final String? suffixText =
        _adornmentText(context, presentation.field.suffix);

    // **Modifier / Copier par option**. Le rendu NATIF de
    // `relation` les expose dès qu'un `crudHandler` est résolu
    // (`_CrudRowActions`) ; le présentateur n'en rendait que **Créer** —
    // enrôler le présentateur RETIRAIT donc deux actions. Le DTO porte déjà
    // `crudHandler` : rien à élargir, seulement à lire.
    //
    // Priorité : un `choiceSecondaryBuilder` fourni par l'hôte l'emporte
    // TOUJOURS (c'est le même slot, et c'est SA décision). Sans handler ⇒ slot
    // absent (AD-4), rendu antérieur strictement conservé.
    //
    // Écart ASSUMÉ avec le natif : celui-ci ne conditionne pas ces deux
    // actions à `readOnly`. Ici elles suivent `enabled`, comme **Créer** — les
    // trois écrivent la sélection (auto-sélection du résultat), et une écriture
    // sur un champ en lecture seule n'a pas de sens.
    final bool crudRowActions = presentation.choiceSecondaryBuilder == null &&
        presentation.crudHandler != null &&
        enabled;

    // FR-26 — infobulles RÉSOLUES ICI, dans le `context` du CHAMP, et
    // passées par valeur. Mesuré : le modal est poussé sur le `Navigator`, donc
    // **au-dessus** du `ZcrudScope` — un `label(modalContext, 'edit')` ne voit
    // PAS les libellés injectés au scope et retombe silencieusement sur la table
    // anglaise du cœur. C'est la même discipline de capture synchrone que
    // `_wrapLoader`.
    final String editTooltip = label(context, 'edit');
    final String copyTooltip = label(context, 'copy');

    // règle EXACTE de `ZFieldLabel` (cœur) :
    // `field.isRequired && !field.readOnly`. Lue sur `field`, pas sur
    // `presentation.readOnly` : c'est la spec du champ qui décide, comme dans le
    // rendu natif décoré (`zFieldDecoration` → `ZFieldLabel`).
    //
    // Hôte passif : un champ NON requis rend `false` ⇒ aucune des deux
    // branches ci-dessous n'est empruntée (ni libellé enrichi, ni
    // `modalHeaderBuilder`), le rendu antérieur est strictement conservé.
    final bool requiredIndicator =
        presentation.field.isRequired && !presentation.field.readOnly;

    // FR-26 : indice du champ de recherche du modal — l10n (clé `search`),
    // jamais le `'Search on $title'` anglais que le fork poserait sinon
    // (`s2_state.dart:289`).
    final String filterHint = label(context, 'search');

    // Parité de référence : `S2ChoiceStyle` d'option (sous-titre gris italique) et
    // d'option active (accent, gras) — exprimés en RÔLES.
    final S2ChoiceStyle choiceStyle = S2ChoiceStyle(
      subtitleStyle: TextStyle(
        fontStyle: FontStyle.italic,
        color: scheme.onSurfaceVariant,
      ),
    );
    final S2ChoiceStyle choiceActiveStyle = S2ChoiceStyle(
      opacity: 1,
      color: scheme.primary,
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
    );

    // Parité de référence : en-tête de modal translucide + élévation 3.
    final S2ModalHeaderStyle headerStyle = S2ModalHeaderStyle(
      backgroundColor: scheme.surface.withValues(
        alpha: ZSelectTileReference.modalHeaderOpacity,
      ),
      elevation: ZSelectTileReference.modalHeaderElevation,
    );

    // Parité de référence : `enableDrag`, `barrierDismissible`, `filterAuto` (la
    // recherche s'applique à la frappe, sans validation).
    const S2ModalConfig modalConfig = S2ModalConfig(
      enableDrag: true,
      barrierDismissible: true,
      filterAuto: true,
    );

    final S2ModalType modalType = _modalType(context, metrics);
    final int pageLimit = metrics.choicePageLimit;

    if (presentation.multiple) {
      return SmartSelect<dynamic>.multiple(
        title: title,
        placeholder: placeholder,
        // AD-10 : normalise scalaire/`null`/`List` → `List<Object?>` ; une
        // valeur hors options est simplement non représentée (placeholder).
        selectedValue: _asList(presentation.selected),
        choiceItems: choiceItems,
        // `null` ⇒ le fork reste SYNCHRONE sur `choiceItems`,
        // strictement comme avant (`S2Choices.isSync`).
        choiceLoader: choiceLoader,
        // builder d'option hôte. `null` ⇒ le fork rend
        // l'option lui-même (switches/radios/…), rendu antérieur inchangé.
        choiceBuilder: presentation.choiceBuilder == null
            ? null
            : (ctx, _, choice) =>
                _buildHostChoice(ctx, presentation, choice, enabled: enabled),
        // affordance de fin de ligne (Modifier/Copier chez
        // de référence). `null` ⇒ slot ABSENT (AD-4), rendu antérieur inchangé.
        choiceSecondaryBuilder: presentation.choiceSecondaryBuilder != null
            ? (ctx, _, choice) => _buildHostSecondary(
                  ctx,
                  presentation,
                  choice,
                  enabled: enabled,
                )
            : (crudRowActions
                ? (_, state, choice) => _crudRowActions(
                      state,
                      presentation,
                      choice,
                      multiple: true,
                      editTooltip: editTooltip,
                      copyTooltip: copyTooltip,
                    )
                : null),
        // Parité de référence EXACTE (`choiceDivider: field.choiceBuilder != null`) :
        // un rendu d'option sur mesure a besoin d'un séparateur, le rendu natif
        // du fork non. Hôte passif : `false` — c'est aussi le DÉFAUT du fork
        // (`S2ChoiceConfig.useDivider = false`), donc rien ne bouge.
        choiceDivider: presentation.choiceBuilder != null,
        // barre d'ACTIONS du modal (parité
        // `_modalActionsBuilder` de référence) : créer / confirmer / réinitialiser.
        // En MULTI searchable, la loupe est retirée : le champ de recherche
        // est rendu en PERMANENCE sous la barre (cf. `modalHeaderBuilder`).
        modalActionsBuilder: showActions
            ? (ctx, state) => _modalActions(
                  ctx,
                  state,
                  presentation,
                  multiple: true,
                  withFilterToggle: !presentation.searchable,
                )
            : null,
        modalHeaderBuilder: presentation.searchable
            ? (ctx, state) => _multiHeaderWithFilter(
                  ctx,
                  state,
                  presentation,
                  title: title,
                  showActions: showActions,
                  requiredIndicator: requiredIndicator,
                )
            // hors multi searchable, l'en-tête du fork
            // n'est REMPLACÉ que si l'astérisque est dû — sinon `null`, et
            // `defaultModalHeader` reste seul en charge (rendu inchangé).
            : (requiredIndicator
                ? (ctx, state) => _headerWithRequiredTitle(ctx, state, title)
                : null),
        choiceType: _s2ChoiceType(metrics.multiChoiceStyle),
        choicePageLimit: pageLimit,
        choiceStyle: choiceStyle,
        choiceActiveStyle: choiceActiveStyle,
        modalType: modalType,
        modalFilter: presentation.searchable,
        modalFilterHint: filterHint,
        // Parité de référence (`useConfirm: readOnly ? false : true`) : en multi, la
        // sélection se valide explicitement.
        modalConfirm: enabled,
        modalHeader: true,
        modalHeaderStyle: headerStyle,
        modalConfig: modalConfig,
        // Valeur MÉTIER : une vraie `List<Object?>` (jamais la concat "S2Choice").
        onChange: enabled
            ? (state) => presentation.onChanged(
                  List<Object?>.from(state.value),
                )
            : (_) {},
        tileBuilder: (context, state) => _ZSmartSelectTile(
          label: title,
          placeholder: placeholder,
          // Parité de référence : le multi affiche des PUCES, une par titre
          // sélectionné — jamais `state.selected.toString()` (qui retombe sur
          // `'Select one or more'` du fork quand la liste est vide, et rend un
          // `[a, b]` littéral sinon).
          chipLabels: state.selected.title ?? const <String>[],
          hasValue: state.selected.isNotEmpty,
          enabled: enabled,
          tappable: tappable,
          leading: leading,
          onTap: state.showModal,
          metrics: metrics,
          showChevron: spec?.showTrailingChevron ?? enabled,
          requiredIndicator: requiredIndicator,
          isLoading: presentation.isLoading,
          helperText: helperText,
          prefix: prefix,
          suffix: suffix,
          prefixText: prefixText,
          suffixText: suffixText,
        ),
      );
    }

    // Mono : `select` / `radio` (parité `radioAsModal` de référence) — choix unique en
    // modal S2, `choiceType: radios` par défaut.
    return SmartSelect<dynamic>.single(
      title: title,
      placeholder: placeholder,
      selectedValue: presentation.selected,
      choiceItems: choiceItems,
      choiceLoader: choiceLoader,
      choiceBuilder: presentation.choiceBuilder == null
          ? null
          : (ctx, _, choice) =>
              _buildHostChoice(ctx, presentation, choice, enabled: enabled),
      choiceSecondaryBuilder: presentation.choiceSecondaryBuilder != null
          ? (ctx, _, choice) => _buildHostSecondary(
                ctx,
                presentation,
                choice,
                enabled: enabled,
              )
          : (crudRowActions
              ? (_, state, choice) => _crudRowActions(
                    state,
                    presentation,
                    choice,
                    multiple: false,
                    editTooltip: editTooltip,
                    copyTooltip: copyTooltip,
                  )
              : null),
      choiceDivider: presentation.choiceBuilder != null,
      // même barre d'actions ; en MONO la recherche reste une
      // BASCULE (loupe), exactement comme de référence (`useFilter: true`).
      modalActionsBuilder: showActions
          ? (ctx, state) => _modalActions(
                ctx,
                state,
                presentation,
                multiple: false,
                withFilterToggle: true,
              )
          : null,
      // même règle qu'en multi : en-tête remplacé
      // UNIQUEMENT si l'astérisque est dû.
      modalHeaderBuilder: requiredIndicator
          ? (ctx, state) => _headerWithRequiredTitle(ctx, state, title)
          : null,
      choiceType: _s2ChoiceType(metrics.monoChoiceStyle),
      choicePageLimit: pageLimit,
      choiceStyle: choiceStyle,
      choiceActiveStyle: choiceActiveStyle,
      modalType: modalType,
      modalFilter: presentation.searchable,
      modalFilterHint: filterHint,
      modalHeader: true,
      modalHeaderStyle: headerStyle,
      modalConfig: modalConfig,
      // Valeur MÉTIER scalaire (jamais un type S2).
      onChange:
          enabled ? (state) => presentation.onChanged(state.value) : (_) {},
      tileBuilder: (context, state) => _ZSmartSelectTile(
        label: title,
        placeholder: placeholder,
        // État vide → placeholder LOCALISÉ (jamais `'Select one'` du fork).
        valueText: state.selected.isResolved ? state.selected.title : null,
        hasValue: state.selected.isResolved,
        enabled: enabled,
        tappable: tappable,
        leading: leading,
        onTap: state.showModal,
        metrics: metrics,
        showChevron: spec?.showTrailingChevron ?? enabled,
        requiredIndicator: requiredIndicator,
        isLoading: presentation.isLoading,
        helperText: helperText,
        prefix: prefix,
        suffix: suffix,
        prefixText: prefixText,
        suffixText: suffixText,
      ),
    );
  }

  /// **En-tête de modal portant l'astérisque « requis »**.
  ///
  /// Reproduit `S2State.defaultModalHeader` **à l'identique** (mêmes jetons de
  /// `modalHeaderStyle`, même `automaticallyImplyLeading`, même loupe de
  /// filtrage, même `modalError`, mêmes `modalActions` — donc la barre d'actions
  /// posée par `modalActionsBuilder` reste celle du présentateur), à une seule
  /// substitution près : le titre passe de `Text` à [_labelWithRequiredIndicator].
  ///
  /// Installé UNIQUEMENT quand l'astérisque est dû — sinon `modalHeaderBuilder`
  /// vaut `null` et le fork rend son en-tête par défaut, inchangé.
  Widget _headerWithRequiredTitle(
    BuildContext context,
    S2State<dynamic> state,
    String title,
  ) {
    final bool isFiltering = state.filter?.activated == true;
    final S2ModalHeaderStyle headerStyle = state.modalHeaderStyle;
    return AppBar(
      primary: true,
      shape: headerStyle.shape,
      elevation: headerStyle.elevation,
      backgroundColor: headerStyle.backgroundColor,
      actionsIconTheme: headerStyle.actionsIconTheme,
      iconTheme: headerStyle.iconTheme,
      centerTitle: headerStyle.centerTitle,
      automaticallyImplyLeading: state.modalConfig.isFullPage || isFiltering,
      leading: isFiltering ? const Icon(Icons.search) : null,
      title: isFiltering
          ? state.modalFilter
          : Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _labelWithRequiredIndicator(
                  context,
                  title,
                  required: true,
                  style: headerStyle.textStyle,
                ),
                state.modalError,
              ],
            ),
      actions: state.modalActions,
    );
  }

  /// **Barre d'actions du modal** — parité `_modalActionsBuilder` de référence
  /// (`edition_screen.dart` l. ~2633), rendue accessible.
  ///
  /// Ordre et conditions **mesurés en référence** :
  ///
  /// | Action | Condition de référence | Ici |
  /// |---|---|---|
  /// | **Créer** | `crudDataSelect && allowErpRessourceCrud` | `crudHandler != null` et champ éditable |
  /// | **Confirmer** | `state.confirmButton` (mono) / `IconButton(check_circle_outline)` (multi) | une seule affordance, mêmes icônes |
  /// | **Réinitialiser** | `state.selection?.choice != null` | une valeur est sélectionnée, et le champ est éditable |
  /// | **Rechercher** (loupe) | `filter != null && !filter.activated` | idem, **sauf** en multi searchable (le champ est permanent) |
  ///
  /// **Trois défauts de référence non reproduits ici :**
  ///
  /// 1. leurs `IconButton` n'ont **ni tooltip ni `Semantics`** — un lecteur
  ///    d'écran annonce « bouton » sans dire lequel. Ici chaque action porte un
  ///    `tooltip` **localisé** (clés `create`/`confirm`/`reset`/`search`), qui
  ///    alimente aussi l'annonce accessible ;
  /// 2. leur réinitialisation écrit la valeur **puis** appelle
  ///    `Future.delayed(500ms, () { Get.back(); Get.back(); setState(() {}); })`
  ///    — deux pops à l'aveugle et un rebuild global de formulaire. Ici la
  ///    remise à zéro **notifie la tranche** (`onChanged`) et ferme le modal une
  ///    fois : aucun `setState` de formulaire (AD-2/SM-1) ;
  /// 3. leur icône de réinitialisation est peinte en `kErrorColor` **littéral** ;
  ///    ici c'est le **rôle** `ColorScheme.error` (FR-26).
  ///
  /// AD-13 : `IconButton` porte nativement une cible de 48 dp ; l'état
  /// « inactif » n'est jamais porté par la seule couleur (`onPressed: null`
  /// désactive **et** retire l'action de l'arbre sémantique).
  List<Widget> _modalActions(
    BuildContext context,
    S2State<dynamic> state,
    ZSelectPresentation presentation, {
    required bool multiple,
    required bool withFilterToggle,
  }) {
    // invariant AD-10 : teste `state.mounted` en tête — un modal en cours de
    // fermeture ne doit pas reconstruire d'actions sur un état mort.
    if (!state.mounted) return const <Widget>[];

    final bool filtering = state.filter?.activated ?? false;
    final bool editable = !presentation.readOnly;
    final bool hasSelection = multiple
        ? _asList(presentation.selected).isNotEmpty
        : presentation.selected != null;

    final List<Widget> actions = <Widget>[];

    // Pendant la recherche, la barre masque TOUTES les actions sauf la bascule :
    // elle est alors occupée par le champ de saisie.
    if (!filtering) {
      if (presentation.crudHandler != null && editable) {
        actions.add(
          IconButton(
            tooltip: label(context, 'create'),
            icon: const Icon(Icons.add),
            onPressed: () => _crudThenSelect(
              state,
              presentation,
              () => presentation.crudHandler!.create(
                const <String, Object?>{},
              ),
              multiple: multiple,
            ),
          ),
        );
      }
      if (editable) {
        actions.add(
          IconButton(
            tooltip: label(context, 'confirm'),
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () => state.closeModal(confirmed: true),
          ),
        );
      }
      if (editable && hasSelection) {
        actions.add(
          IconButton(
            tooltip: label(context, 'reset'),
            // FR-26 : RÔLE `error`, jamais le `kErrorColor` littéral de référence.
            color: Theme.of(context).colorScheme.error,
            icon: const Icon(Icons.block),
            onPressed: () {
              // AD-2/SM-1 : on NOTIFIE la tranche ; c'est la réécriture de la
              // valeur qui rafraîchit le sélecteur, pas un `setState` global.
              presentation.onChanged(multiple ? const <Object?>[] : null);
              // INDISPENSABLE, et mesuré : en MONO le fork n'exige pas de
              // confirmation (`useConfirm == false`), si bien que `showModal()`
              // rappelle `onChange()` à la fermeture **avec l'ancienne
              // sélection** — la valeur qu'on vient d'effacer serait aussitôt
              // réécrite. Vider la sélection du fork rend `selection.choice`
              // nul et coupe ce rappel
              // (`state.selection!.choice = null; state.selected.choice = null;
              // state.selected.value = null;`), en une seule opération.
              state.selection?.clear();
              state.closeModal(confirmed: false);
            },
          ),
        );
      }
    }

    // Bascule de recherche : le widget du fork, qui gère lui-même l'entrée
    // d'historique de route (un retour arrière ferme la recherche, pas le
    // modal). Retirée en multi searchable, où le champ est permanent.
    if (withFilterToggle && state.filter != null && !filtering) {
      actions.add(state.defaultModalFilterToggle);
    }
    return actions;
  }

  /// **En-tête du modal MULTI avec champ de recherche PERMANENT** — pose la
  /// recherche dans une ligne **sous la barre de titre et au-dessus des
  /// options** (`ListTile(leading: Icon(search), title: state.modalFilter)`
  /// du fork), après avoir forcé son ouverture depuis `onModalOpen`.
  ///
  /// **Pourquoi ne PAS reprendre le mécanisme natif du fork.** Il obtient ce
  /// rendu en appelant `state.filter?.show(state.modalContext)` à l'ouverture, ce qui
  /// bascule le fork en mode « recherche » : la barre perd alors son **titre**
  /// (`defaultModalHeader` remplace `title` par le champ) et pousse une entrée
  /// d'historique de route, si bien qu'un premier retour arrière ferme la
  /// recherche au lieu du modal. Ils compensent des deux côtés (un
  /// `_modalBuilder` qui réaffiche le titre, un double `Get.back()` à la
  /// réinitialisation). Ici la recherche est simplement **rendue en plus**, le
  /// filtre du fork restant désactivé : le titre reste lisible, le retour
  /// arrière ferme le modal une fois, et aucun des deux contournements n'existe.
  ///
  /// AD-13 : le champ porte une icône **et** un libellé (`labelText` localisé) —
  /// l'affordance ne repose pas sur la seule icône ; ligne directionnelle.
  Widget _multiHeaderWithFilter(
    BuildContext context,
    S2State<dynamic> state,
    ZSelectPresentation presentation, {
    required String title,
    required bool showActions,
    required bool requiredIndicator,
  }) {
    final S2ModalHeaderStyle headerStyle = state.modalHeaderStyle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppBar(
          primary: true,
          shape: headerStyle.shape,
          elevation: headerStyle.elevation,
          backgroundColor: headerStyle.backgroundColor,
          actionsIconTheme: headerStyle.actionsIconTheme,
          iconTheme: headerStyle.iconTheme,
          centerTitle: headerStyle.centerTitle,
          automaticallyImplyLeading: state.modalConfig.isFullPage,
          // le titre n'est enrichi que si l'astérisque
          // est dû ; sinon on garde le widget du fork MOT POUR MOT
          // (`Container(child: Text(title, style: headerStyle.textStyle))`) —
          // aucun nœud de l'arbre ne bouge pour un champ non requis.
          title: requiredIndicator
              ? _labelWithRequiredIndicator(
                  context,
                  title,
                  required: true,
                  style: headerStyle.textStyle,
                )
              : state.modalTitle,
          actions: showActions
              ? _modalActions(
                  context,
                  state,
                  presentation,
                  multiple: true,
                  withFilterToggle: false,
                )
              : const <Widget>[],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
          child: TextField(
            controller: state.filter?.ctrl,
            textAlign: TextAlign.start,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              // FR-26 : libellé LOCALISÉ, jamais le `'Search on $title'` du
              // fork ni un littéral français comme en référence.
              labelText: label(context, 'search'),
              isDense: true,
            ),
            // Le filtre du fork applique la requête ; `filterAuto` étant actif,
            // de référence passerait par un debouncer — ici la liste est cliente et le
            // coût est nul, on applique directement.
            onChanged: (q) => state.filter?.apply(q),
          ),
        ),
      ],
    );
  }

  /// **Modifier / Copier** l'entité d'une option — parité avec
  /// `_CrudRowActions` du rendu NATIF de `relation`, que l'enrôlement du
  /// présentateur faisait jusqu'ici disparaître.
  ///
  /// Rendu dans le slot `secondary` de la tuile d'option du fork (le même que
  /// `choiceSecondaryBuilder`), donc **uniquement** quand l'hôte n'en fournit
  /// pas et qu'un `crudHandler` est résolu.
  ///
  /// AD-13 : `IconButton` porte nativement une cible de 48 dp ; chaque action a
  /// un `tooltip` **localisé** (clés `edit`/`copy`), qui alimente aussi son
  /// annonce accessible — l'icône n'est jamais le seul canal. FR-26 : aucune
  /// couleur posée, les icônes héritent de l'`IconTheme` ambiant.
  Widget _crudRowActions(
    S2State<dynamic> state,
    ZSelectPresentation presentation,
    S2Choice<dynamic> choice, {
    required bool multiple,
    required String editTooltip,
    required String copyTooltip,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: editTooltip,
          icon: const Icon(Icons.edit),
          onPressed: () => _crudThenSelect(
            state,
            presentation,
            () => presentation.crudHandler!.edit(choice.value),
            multiple: multiple,
            replaced: choice.value,
          ),
        ),
        IconButton(
          tooltip: copyTooltip,
          icon: const Icon(Icons.copy),
          onPressed: () => _crudThenSelect(
            state,
            presentation,
            () => presentation.crudHandler!.copy(choice.value),
            multiple: multiple,
          ),
        ),
      ],
    );
  }

  /// Exécute une opération CRUD via le port **neutre** `ZRelationCrudHandler`
  /// ([op] = `create` / `edit` / `copy`), puis **auto-sélectionne** l'option
  /// résultante (parité avec `_onCrud` et `_selectResult` du rendu natif).
  ///
  /// [replaced] (édition) : si l'entité change de valeur, l'ancienne est retirée
  /// de la sélection multi avant l'ajout de la nouvelle — sans quoi une édition
  /// qui ré-identifie l'entité laisserait un fantôme sélectionné.
  ///
  /// AD-10 : `Future` en erreur **ou** résultat `null` (annulation) ⇒ aucune
  /// écriture, aucun crash — équivalent exact de leur `try/catch (_) {}`.
  /// Invariant AD-2 : la sélection passe par `onChanged`, jamais par une
  /// mutation directe de l'état interne du fork (une approche naïve
  /// muterait cet état avec un `Future.delayed(500ms)` pour que ça « prenne »).
  Future<void> _crudThenSelect(
    S2State<dynamic> state,
    ZSelectPresentation presentation,
    Future<ZFieldChoice?> Function() op, {
    required bool multiple,
    Object? replaced,
  }) async {
    ZFieldChoice? result;
    try {
      result = await op();
    } catch (_) {
      return;
    }
    if (result == null) return;
    if (multiple) {
      final List<Object?> next = _asList(presentation.selected);
      if (replaced != null && replaced != result.value) next.remove(replaced);
      if (!next.contains(result.value)) next.add(result.value);
      presentation.onChanged(next);
    } else {
      presentation.onChanged(result.value);
    }
    if (state.mounted) state.closeModal(confirmed: false);
  }

  /// Enveloppe le [ZSelectOptionsLoader] hôte en `S2ChoiceLoader` — **le seul**
  /// point où la frontière asynchrone est franchie (`S2ChoiceLoaderInfo`
  /// ne remonte jamais au seam).
  ///
  /// **AD-10 — trois défaillances, un seul rendu dégradé.** Le fork ne
  /// rattrape QUE `on Error` (`s2/state/choices.dart`, `load()`) : une
  /// `Exception` — c'est-à-dire l'échec NORMAL d'une entrée/sortie en Dart —
  /// remonterait non capturée et laisserait le modal figé sur son indicateur
  /// d'attente. Une `Future` qui ne se termine jamais ferait pire encore :
  /// `task` ne redevient `null` qu'au `finally`, donc l'attente serait
  /// **définitive**. L'enveloppe traite les trois cas de la même façon :
  ///
  /// 1. `Exception` levée ⇒ liste **vide** (le modal affiche son état vide) ;
  /// 2. `Error` levée ⇒ idem ;
  /// 3. jamais terminée ⇒ [ZSelectTileReference.optionsLoadTimeout] puis idem.
  ///
  /// Le modal reste **sortable** dans tous les cas (`enableDrag`,
  /// `barrierDismissible`, en-tête à bouton de fermeture) : jamais d'écran
  /// bloqué sans issue.
  ///
  /// **Résolution l10n capturée SYNCHRONEMENT.** `label(context, …)` consulte
  /// des `InheritedWidget` (`dependOnInheritedWidgetOfExactType`) : l'appeler
  /// depuis une continuation asynchrone, sur un `context` peut-être démonté,
  /// serait un usage hors-`build`. Les deux résolveurs sont donc capturés ici,
  /// pendant `present()`, et la continuation n'appelle plus qu'une fonction
  /// **pure**.
  ///
  /// **AD-2/SM-1** : rien de tout cela ne touche le `ZFormController`, ne
  /// crée de contrôleur ni ne reconstruit le champ. L'attente vit dans le
  /// `S2Choices` (un `ChangeNotifier` interne au modal) ; le déclencheur, lui,
  /// n'est même pas dans l'arbre du modal.
  S2ChoiceLoader<dynamic>? _wrapLoader(
    BuildContext context,
    ZSelectPresentation presentation,
  ) {
    final ZSelectOptionsLoader? loader = presentation.optionsLoader;
    if (loader == null) return null;

    // Capture SYNCHRONE (on est dans `build`).
    final ZcrudLabels? scopeLabels = ZcrudScope.maybeOf(context)?.labels;
    final ZcrudLocalizations l10n = ZcrudLocalizations.of(context);
    String resolve(String key) =>
        scopeLabels?.maybeResolve(key) ?? l10n.maybeResolve(key) ?? key;

    return (info) async {
      List<ZFieldChoice> loaded;
      try {
        loaded = await loader(
          ZSelectOptionsQuery(
            search: info.query,
            page: info.page ?? 1,
            limit: info.limit,
          ),
        ).timeout(ZSelectTileReference.optionsLoadTimeout);
      } catch (_) {
        // `catch (_)` NU et délibéré : `on Exception` laisserait passer les
        // `Error` (dont `TimeoutException` n'est pas, mais `StateError` oui) et
        // reproduirait exactement le trou du fork.
        return const <S2Choice<dynamic>>[];
      }
      return <S2Choice<dynamic>>[
        for (final c in loaded)
          S2Choice<dynamic>(
            value: c.value,
            title: resolve(c.label),
            subtitle: c.subtitle == null ? null : resolve(c.subtitle!),
            disabled: c.disabled,
          ),
      ];
    };
  }

  /// Traduit une option du fork vers le [ZSelectChoiceBuilder] **neutre** de
  /// l'hôte (`S2Choice` ne franchit pas la frontière).
  ///
  /// L'option neutre est retrouvée par **valeur** dans `presentation.options` ;
  /// si elle n'y est pas (cas d'un chargement asynchrone), elle est reconstruite
  /// depuis le `S2Choice` — jamais une exception (AD-10).
  ///
  /// `ctx.select` est branché sur `choice.select` du fork, qui est l'unique
  /// voie d'écriture de la sélection depuis une option ; `null` (option hors
  /// modal) ⇒ rappel inerte plutôt qu'un `!` qui lèverait.
  Widget _buildHostChoice(
    BuildContext context,
    ZSelectPresentation presentation,
    S2Choice<dynamic> choice, {
    required bool enabled,
  }) =>
      presentation.choiceBuilder!(
        context,
        _neutralChoiceContext(presentation, choice, enabled: enabled),
      );

  /// Idem [_buildHostChoice] pour l'affordance de fin de ligne.
  ///
  /// **Écart assumé, et mesuré** : le seam laisse l'hôte rendre `null` pour
  /// « aucune affordance sur CETTE option » (AD-4), mais le slot du fork est
  /// **non-nullable** par option (`S2ComplexWidgetBuilder` rend un `Widget`).
  /// Un `null` de l'hôte est donc dégradé en `SizedBox.shrink()` : rien n'est
  /// peint, aucune place n'est prise, aucun nœud sémantique n'est ajouté — mais
  /// le slot existe formellement dans l'arbre. C'est la seule traduction
  /// possible sans forker le fork, et elle ne change rien à ce que l'utilisateur
  /// voit ou entend.
  Widget _buildHostSecondary(
    BuildContext context,
    ZSelectPresentation presentation,
    S2Choice<dynamic> choice, {
    required bool enabled,
  }) =>
      presentation.choiceSecondaryBuilder!(
        context,
        _neutralChoiceContext(presentation, choice, enabled: enabled),
      ) ??
      const SizedBox.shrink();

  /// Projette une option du fork vers le contexte **neutre** du seam.
  static ZSelectChoiceContext _neutralChoiceContext(
    ZSelectPresentation presentation,
    S2Choice<dynamic> choice, {
    required bool enabled,
  }) {
    // Retrouvée par VALEUR dans les options neutres — pour rendre à l'hôte SON
    // `ZFieldChoice` (clés l10n d'origine, `extra` éventuel) et non une
    // reprojection appauvrie. Absente (chargement asynchrone) ⇒ reconstruite
    // depuis le `S2Choice`, jamais une exception (AD-10).
    ZFieldChoice neutral = ZFieldChoice(
      value: choice.value,
      label: choice.title ?? '',
      subtitle: choice.subtitle,
      disabled: choice.disabled,
    );
    for (final o in presentation.options) {
      if (o.value == choice.value) {
        neutral = o;
        break;
      }
    }
    // `choice.select` est l'unique voie d'écriture depuis une option ; il est
    // `null` hors modal ⇒ rappel INERTE plutôt qu'un `!` qui lèverait (AD-10).
    final ValueSetter<bool?>? select = choice.select;
    return ZSelectChoiceContext(
      choice: neutral,
      selected: choice.selected,
      enabled: enabled && !choice.disabled,
      select: (v) => select?.call(v),
    );
  }

  /// Résout la forme du conteneur de modal — [ZSelectModalShape.adaptive]
  /// bascule sur la **largeur utile** (substitut mesurable au
  /// `AppPlatform.isWebOrDesktop` de référence, cf. [ZSelectModalShape.adaptive]).
  ///
  /// AD-10 : sans `MediaQuery` dans l'arbre, `maybeSizeOf` rend `null` et l'on
  /// retombe sur la feuille — jamais d'exception.
  S2ModalType _modalType(BuildContext context, ZSelectTileMetrics metrics) {
    final shape = metrics.modalShape;
    switch (shape) {
      case ZSelectModalShape.bottomSheet:
        return S2ModalType.bottomSheet;
      case ZSelectModalShape.popupDialog:
        return S2ModalType.popupDialog;
      case ZSelectModalShape.fullPage:
        return S2ModalType.fullPage;
      case ZSelectModalShape.adaptive:
        final width = MediaQuery.maybeSizeOf(context)?.width;
        final breakpoint = metrics.dialogBreakpoint;
        return (width != null && width >= breakpoint)
            ? S2ModalType.popupDialog
            : S2ModalType.bottomSheet;
    }
  }

  /// Traduit l'enum **local** [ZSelectChoiceStyle] en `S2ChoiceType` — **le
  /// seul** point de traduction du paquet (le type fork ne franchit jamais la
  /// frontière publique).
  static S2ChoiceType _s2ChoiceType(ZSelectChoiceStyle style) {
    switch (style) {
      case ZSelectChoiceStyle.radios:
        return S2ChoiceType.radios;
      case ZSelectChoiceStyle.checkboxes:
        return S2ChoiceType.checkboxes;
      case ZSelectChoiceStyle.switches:
        return S2ChoiceType.switches;
      case ZSelectChoiceStyle.chips:
        return S2ChoiceType.chips;
    }
  }

  /// Projette les options **neutres** `ZFieldChoice` en `S2Choice` **privés**
  /// (aucun S2 ne franchit la frontière publique). Résout les libellés d'options
  /// via `label(context, ...)` (clé l10n → texte, repli sur la clé). `disabled`
  /// est propagé (option visible mais non sélectionnable — AD-10/AD-13).
  static List<S2Choice<dynamic>> _toS2Choices(
    BuildContext context,
    List<ZFieldChoice> options,
  ) {
    return <S2Choice<dynamic>>[
      for (final c in options)
        S2Choice<dynamic>(
          value: c.value,
          title: label(context, c.label, fallback: c.label),
          subtitle: c.subtitle == null
              ? null
              : label(context, c.subtitle!, fallback: c.subtitle!),
          disabled: c.disabled,
        ),
    ];
  }

  /// Texte d'un ornement **`.text`**, résolu l10n — `null`
  /// pour toute autre nature (`.icon`, `.widget`) comme pour un ornement absent.
  ///
  /// Sert **uniquement** l'annonce accessible du tile : le rendu visuel, lui,
  /// passe par `resolveAdornment` (seule voie légitime, qui connaît les trois
  /// natures et le seam d'icônes de l'hôte).
  static String? _adornmentText(BuildContext context, ZFieldAdornment? a) =>
      (a == null || a.kind != ZAdornmentKind.text)
          ? null
          : label(context, a.value, fallback: a.value);

  /// Normalise la sélection multi (défensif AD-10) : scalaire/`null` → `List`.
  static List<Object?> _asList(Object? selected) {
    if (selected is List) return List<Object?>.from(selected);
    if (selected == null) return const <Object?>[];
    return <Object?>[selected];
  }
}

/// Libellé + **astérisque « requis » décoratif**.
///
/// **Pourquoi ce n'est PAS `ZFieldLabel`** — et ce n'est pas un choix de
/// confort : `ZFieldLabel` **impose un style de base au libellé** (`Text.rich`
/// dont le `TextSpan` racine porte `tokens.largeLabelTextStyle` en `large`, et
/// `tokens.labelTextStyle ?? textTheme.bodyMedium` sinon). C'est exactement ce
/// qu'il faut dans son habitat — `InputDecoration.label` / `ZLargeFieldCard`,
/// où aucun style ambiant ne préexiste. Ici les deux sites ont déjà LEUR
/// typographie, et la mesure (banc `zz_scratch`, rejouée) est sans appel :
///
/// | Site | style ambiant | `ZFieldLabel(large: true)` | `ZFieldLabel()` |
/// |---|---|---|---|
/// | `ListTile.title` | 16 / w400 | 16 / **w500** | **14** / w400 (+ couleur propre) |
/// | `AppBar.title` (titre du modal) | **22** / w400 | **16** / w500 | 14 / w400 |
///
/// Le titre du modal passerait donc de 22 à 16 points : l'en-tête cesserait
/// d'être un en-tête. Un second motif, indépendant, l'exclut aussi :
/// `ZFieldLabel` **re-dérive** le libellé de `field.label ?? field.name` et
/// ignore `ZSelectPresentation.label`, qui est pourtant le libellé **résolu**
/// que le seam transporte (et qu'un hôte peut surcharger).
///
/// Ce qui EST repris de `ZFieldLabel`, à la lettre (garde de non-divergence
/// `z_select_required_indicator_test.dart`) : le glyphe `' *'`, la couleur par
/// **rôle** (`ZcrudTheme.errorColor ?? ColorScheme.error` — FR-26, aucun
/// littéral), l'alignement `PlaceholderAlignment.middle`, et surtout le fait que
/// l'astérisque soit **décoratif** (`ExcludeSemantics`) : l'information
/// « requis » passe par `Semantics.isRequired` sur le déclencheur (AD-13), comme
/// le fait `ZDecoratedFieldTrigger` du cœur — jamais par un caractère lu.
///
/// [style] `null` ⇒ **aucun** style imposé : le libellé hérite intégralement du
/// `DefaultTextStyle` ambiant (c'est le cas du `ListTile.title`). L'astérisque,
/// lui, est un `WidgetSpan` : son enfant hérite du même `DefaultTextStyle` et
/// n'en surcharge que la **couleur** — la taille et la graisse du libellé ne
/// bougent donc pas d'un point.
///
/// [required] `false` ⇒ un `Text` nu, strictement identique au rendu antérieur
/// (aucun `WidgetSpan`, donc aucun caractère `U+FFFC` dans le texte brut : les
/// `find.text` des hôtes et des gardes continuent de mordre).
Widget _labelWithRequiredIndicator(
  BuildContext context,
  String text, {
  required bool required,
  TextStyle? style,
}) {
  if (!required) {
    return Text(text, textAlign: TextAlign.start, style: style);
  }
  // FR-26 : RÔLE `error` (jeton d'abord, `ColorScheme` en repli) — exactement la
  // résolution de `ZFieldLabel`, jamais un littéral.
  final Color errorColor = ZcrudTheme.of(context).errorColor ??
      Theme.of(context).colorScheme.error;
  return Text.rich(
    TextSpan(
      text: text,
      style: style,
      children: <InlineSpan>[
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: ExcludeSemantics(
            child: Text(' *', style: TextStyle(color: errorColor)),
          ),
        ),
      ],
    ),
    textAlign: TextAlign.start,
  );
}

/// Déclencheur du modal S2, à l'**apparence de référence** (AD-13 / FR-26).
///
/// Structure reproduite de `edition_screen.dart` (cf.
/// `z_select_tile_reference.dart` pour le relevé complet et la table de
/// correspondance gris → rôles) :
/// `Card(elevation: 0, RoundedRectangleBorder(radius 12, side 1))` →
/// `ListTile(title: libellé, trailing: chevron, subtitle: placeholder | puces)`.
///
/// **Une SEULE annonce accessible** : le nœud `Semantics` porte lui-même le rôle
/// `button`, le `label`, la `value` ET l'action `tap` (`onTap:`), avec
/// `excludeSemantics: true` qui **écarte tous les nœuds descendants** (Card /
/// ListTile / Chip / Text) — pas de double annonce (un `Wrap` de dix puces
/// produirait sinon dix nœuds), mais l'activation par lecteur d'écran reste
/// possible (l'action `tap` vit sur ce même nœud).
///
/// **AD-13** : cible **≥ 48 dp** (`ConstrainedBox`, plancher jamais abaissable —
/// défaut de référence non reproduit n°2) ; `contentPadding` **directionnel** ; chevron
/// **retourné en RTL** ; l'état ne repose jamais sur la seule couleur (le
/// placeholder est un **texte** distinct, `Semantics.value` n'est renseignée que
/// s'il y a une valeur, `Semantics.enabled` porte la lecture seule).
class _ZSmartSelectTile extends StatelessWidget {
  const _ZSmartSelectTile({
    required this.label,
    required this.placeholder,
    required this.hasValue,
    required this.enabled,
    required this.tappable,
    required this.showChevron,
    required this.onTap,
    required this.metrics,
    required this.requiredIndicator,
    required this.isLoading,
    this.leading,
    this.valueText,
    this.chipLabels,
    this.helperText,
    this.prefix,
    this.suffix,
    this.prefixText,
    this.suffixText,
  });

  /// Libellé du champ (titre du `ListTile`).
  final String label;

  /// Texte de l'état vide, déjà localisé.
  final String placeholder;

  /// Valeur affichée en **mono** (`null` ⇒ état vide).
  final String? valueText;

  /// Titres sélectionnés en **multi** (`null` ⇒ le tile est mono).
  final List<String>? chipLabels;

  /// `true` si la tranche porte une valeur.
  final bool hasValue;

  /// `false` en lecture seule — porte l'état **d'édition** : disparition du
  /// tile vide, `Semantics.enabled`, `ListTile.enabled`.
  final bool enabled;

  /// `false` si le déclencheur ne doit PAS ouvrir le modal.
  ///
  /// **Distinct de [enabled]** : ce drapeau neutralise le
  /// tap sur `readOnly || isLoading`, **sauf** si un `choiceBuilder` est fourni.
  /// Sans les deux drapeaux du seam, ces deux notions se confondaient.
  final bool tappable;

  /// Affiche le chevron de fin de ligne (résolu par l'appelant : paramètre,
  /// sinon la règle de référence « oui sauf en lecture seule »).
  final bool showChevron;

  /// ornement de **tête** déjà résolu en widget par
  /// `resolveAdornment` (parité `field.leading` de référence). `null` ⇒ slot ABSENT de
  /// l'arbre (AD-4), rendu antérieur strictement conservé.
  final Widget? leading;

  /// Ouvre le modal S2.
  final VoidCallback onTap;

  /// Métriques déjà résolues (paramètre > jeton > référence).
  final ZSelectTileMetrics metrics;

  /// `field.isRequired && !field.readOnly`, déjà résolu
  /// par `present()`. Pilote **deux** canaux, jamais un seul (AD-13) :
  /// l'astérisque **visuel** (décoratif) et `Semantics.isRequired` (annoncé).
  /// `false` ⇒ tile strictement identique au rendu antérieur.
  final bool requiredIndicator;

  /// `ZSelectPresentation.isLoading`. Le DTO le portait déjà et
  /// le tile ne l'AFFICHAIT pas : « pas encore chargé » se lisait comme « rien à
  /// choisir ». Pilote deux choses, jamais une seule (AD-13) : le [placeholder]
  /// (déjà résolu sur la clé l10n `loading` par l'appelant — un **texte**, pas
  /// un tourniquet) et l'annonce accessible (cf. [_semanticValue]).
  final bool isLoading;

  /// `field.helperText`, déjà résolu l10n. Rendu en ligne
  /// SUPPLÉMENTAIRE au bas du sous-titre (jamais à la place de la valeur ou des
  /// puces) et annoncé via `Semantics.hint`. `null` ⇒ aucun nœud (AD-4).
  final String? helperText;

  /// ornement `field.prefix` déjà résolu en widget. `null` ⇒
  /// aucun nœud (AD-4).
  final Widget? prefix;

  /// ornement `field.suffix` déjà résolu en widget. `null` ⇒
  /// aucun nœud (AD-4).
  final Widget? suffix;

  /// Texte de [prefix] quand l'ornement est de nature `.text` — repris dans
  /// l'annonce accessible (AD-13). `null` sinon (ornement décoratif).
  final String? prefixText;

  /// Texte de [suffix] quand l'ornement est de nature `.text`. Cf. [prefixText].
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // Parité de référence : `readOnly && rien de sélectionné` → le tile DISPARAÎT
    // (leur `const EmptyContainer()`, l. ~2905 et ~3072).
    if (!enabled && !hasValue) return const SizedBox.shrink();

    // AD-13 : le plancher de 48 dp ne peut être que REHAUSSÉ — la garantie
    // est déjà tenue par `zSelectTileMetricsOf` (paramètre ET jeton), ce
    // `math.max` la rend **locale** : quelle que soit l'origine des métriques,
    // ce widget ne pose jamais une contrainte inférieure au plancher.
    final double minHeight = math.max(
      ZSelectTileReference.minTileHeight,
      metrics.minHeight,
    );

    final Widget subtitle = _subtitle(context, theme);
    final String? semanticValue = _semanticValue();

    return Semantics(
      button: true,
      // `tappable`, PAS `enabled` : on annonce ce qu'on peut faire, et un
      // `choiceBuilder` rend le déclencheur actionnable même en lecture seule.
      // Hôte passif : sans builder ni chargement, `tappable == !readOnly`,
      // c'est-à-dire exactement l'ancienne valeur — rien ne bouge.
      enabled: tappable,
      label: label,
      value: semanticValue,
      // AD-13 — l'astérisque n'est PAS le seul canal, et surtout pas un canal
      // audible : il est `ExcludeSemantics`, et de toute façon `excludeSemantics:
      // true` ci-dessous écarte tous les descendants. C'est CE drapeau qui porte
      // « requis » jusqu'au lecteur d'écran, exactement comme le fait
      // `ZDecoratedFieldTrigger` du cœur.
      isRequired: requiredIndicator,
      // invariant AD-13 — le `helperText` est une information, pas une
      // décoration : sous `excludeSemantics: true` il serait VU et jamais
      // ENTENDU. `hint` est le slot que Flutter réserve à la description
      // complémentaire d'un nœud actionnable. `null` ⇒ propriété absente.
      hint: helperText,
      // L'action `tap` est portée par CE nœud → activable par lecteur d'écran
      // malgré `excludeSemantics` (qui n'écarte que les descendants).
      onTap: tappable ? onTap : null,
      excludeSemantics: true,
      child: Card(
        elevation: metrics.elevation,
        color: metrics.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(metrics.radius),
          side: BorderSide(
            color: metrics.borderColor,
            width: metrics.borderWidth,
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: ListTile(
            contentPadding: metrics.contentPadding,
            // AD-4 : `null` ⇒ le slot n'existe pas dans l'arbre.
            leading: leading,
            // aucun style imposé (`style: null`) — le
            // titre garde la typographie de `ListTileThemeData.titleTextStyle`.
            title: _labelWithRequiredIndicator(
              context,
              label,
              required: requiredIndicator,
            ),
            subtitle: subtitle,
            trailing: showChevron
                ? Icon(isRtl ? Icons.chevron_left : Icons.chevron_right)
                : null,
            onTap: tappable ? onTap : null,
            // MESURÉ : un `ListTile` à `enabled: false` IGNORE son `onTap`.
            // Poser `enabled` ici aurait rendu la règle « un
            // `choiceBuilder` ré-active le tap » inopérante — le tile aurait eu
            // un `onTap` que rien ne pouvait déclencher. Le rendu natif ne
            // touche d'ailleurs jamais ce paramètre : il annule seulement `onTap`.
            enabled: tappable,
          ),
        ),
      ),
    );
  }

  /// Sous-titre complet du tile : le contenu antérieur
  /// (valeur mono ou puces multi), **encadré** des ornements `prefix`/`suffix`
  /// et **suivi** de la ligne d'aide `helperText`.
  ///
  /// **Hôte passif immobile** : sans ornement et sans aide, la méthode rend
  /// EXACTEMENT le widget d'avant — aucune `Row`, aucune `Column`, aucun
  /// `Padding` intercalé (AD-4 : ce qui est `null` est absent de l'arbre, pas
  /// rendu en boîte vide).
  Widget _subtitle(BuildContext context, ThemeData theme) {
    Widget content =
        chipLabels == null ? _monoSubtitle(theme) : _multiSubtitle(context);

    if (prefix != null || suffix != null) {
      // AD-13 : insets DIRECTIONNELS — en RTL le préfixe reste du côté d'où
      // commence la lecture. `Flexible` : c'est le contenu qui cède, pas les
      // ornements (le natif place les siens hors de la zone élastique du texte).
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (prefix != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: ZSelectTileReference.ornamentGap,
              ),
              child: prefix,
            ),
          Flexible(child: content),
          if (suffix != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ZSelectTileReference.ornamentGap,
              ),
              child: suffix,
            ),
        ],
      );
    }

    if (helperText == null) return content;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        content,
        // FR-26 : aucune couleur posée — la ligne hérite de la teinte de
        // sous-titre du `ListTile` et de la typographie `bodySmall`, exactement
        // le registre que Material donne au `helperText` d'un champ.
        Text(
          helperText!,
          textAlign: TextAlign.start,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Valeur annoncée par l'unique nœud sémantique du tile.
  ///
  /// * Rien de sélectionné et **pas** de chargement ⇒ `null` : l'état vide n'est
  ///   pas une valeur (invariant antérieur, conservé).
  /// * Rien de sélectionné **en chargement** ⇒ le texte d'attente. C'est un
  ///   canal NON VISUEL du chargement, et il va plus loin que le natif : son
  ///   `_SelectionTrigger` affiche « Chargement… » mais met `value: null`, donc
  ///   n'annonce rien du tout.
  /// * Une valeur ⇒ le texte mono (ou les puces jointes), **encadré** des
  ///   ornements `.text` — sans quoi un « € » serait visible et jamais lu.
  String? _semanticValue() {
    if (!hasValue) return isLoading ? placeholder : null;
    final String? base =
        chipLabels != null ? chipLabels!.join(', ') : valueText;
    if (base == null) return null;
    if (prefixText == null && suffixText == null) return base;
    return <String>[?prefixText, base, ?suffixText].join(' ');
  }

  /// Sous-titre **mono** — parité de référence : le titre sélectionné, sinon le
  /// placeholder ; taille 15 ; teintes par rôles.
  Widget _monoSubtitle(ThemeData theme) {
    final text = hasValue ? (valueText ?? placeholder) : placeholder;
    return Text(
      text,
      textAlign: TextAlign.start,
      overflow: TextOverflow.clip,
      style: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontSize: ZSelectTileReference.monoValueFontSize,
        color: hasValue ? metrics.valueColor : metrics.placeholderColor,
      ),
    );
  }

  /// Sous-titre **multi** — parité de référence : `Wrap(spacing: 6, runSpacing: 4)` de
  /// `Chip`s (texte 12), sinon le placeholder. Teintes par rôles.
  Widget _multiSubtitle(BuildContext context) {
    final labels = chipLabels ?? const <String>[];
    if (labels.isEmpty) {
      return Text(
        placeholder,
        textAlign: TextAlign.start,
        style: TextStyle(color: metrics.placeholderColor),
      );
    }
    return Wrap(
      spacing: metrics.chipSpacing,
      runSpacing: metrics.chipRunSpacing,
      children: <Widget>[
        for (final t in labels)
          Chip(
            label: Text(
              t,
              style: TextStyle(fontSize: metrics.chipFontSize),
            ),
            backgroundColor: metrics.chipBackgroundColor,
            labelStyle: TextStyle(color: metrics.chipForegroundColor),
          ),
      ],
    );
  }
}
