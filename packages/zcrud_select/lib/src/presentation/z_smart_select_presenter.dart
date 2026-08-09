/// Présentateur riche `ZSelectPresenter` adossé au fork vendorisé
/// `awesome_select` (`SmartSelect`) — fp-4-1 (AD-48), **apparence DODLP**
/// (CR-SELECT-FID, 2026-08-09).
///
/// **Rôle** : implémentation CONCRÈTE du seam `ZSelectPresenter` (livré par le
/// cœur, fp-1-1). Injectée via `ZcrudScope(selectPresenter: const
/// ZSmartSelectPresenter())`, elle **supplante** le rendu natif des familles
/// `select` / `radio` / `checkbox` / `multiselect` / `relation` par un
/// **modal S2 responsive + recherche** à parité DODLP.
///
/// 🔴 **« Par défaut » — ce que ça peut et ne peut pas vouloir dire.** AD-1
/// interdit à `zcrud_core` de dépendre de `zcrud_select` (CORE OUT = 0) : le
/// socle **ne peut pas** monter `awesome_select` de lui-même. « Par défaut » ne
/// signifie donc jamais « sans rien faire ». Ce qui est livré à la place :
///
/// 1. **l'enrôlement le plus court possible** — une seule expression `const`,
///    posée une fois pour toute l'application :
///    `ZcrudScope(selectPresenter: const ZSmartSelectPresenter(), …)` ;
/// 2. **l'apparence DODLP comme défaut du présentateur** — c'est *là* que
///    « par défaut » a un sens réel : un hôte qui enrôle le présentateur obtient
///    le rendu DODLP **sans rien configurer**. Toute la personnalisation passe
///    par [ZSelectTileSpec], qui est entièrement optionnel.
///
/// **Zéro side-effect d'import (AR-4)** : aucun `register*()` top-level,
/// aucune mutation d'un registre global à l'import. Importer ce paquet ne change
/// le rendu de rien ; seule l'injection au scope le fait. C'est délibéré — un
/// enrôlement implicite rendrait le rendu dépendant de l'ordre des imports et
/// indébogable côté hôte.
///
/// **Isolation (AD-40/AD-49)** : `SmartSelect` / `S2*` restent CONFINÉS sous
/// `lib/src/` — AUCUN type `awesome_select` ne fuit au barrel ni dans la
/// signature `present()` (neutre, `zcrud_core`). Les helpers de conversion
/// `ZFieldChoice → S2Choice` et `ZSelectChoiceStyle → S2ChoiceType` sont
/// **privés**.
///
/// **AD-2/SM-1** : le présentateur ne touche JAMAIS le `ZFormController` ; il
/// lit la tranche via `presentation.selected` et **notifie** via
/// `presentation.onChanged` (valeur MÉTIER : scalaire en mono, `List` en multi —
/// jamais un type S2, jamais la concaténation littérale `"S2Choice"` du DODLP).
/// Il ne déclenche aucun `setState` de formulaire (le `Future.delayed(300ms,
/// setState)` de DODLP est le bug produit n°1 du dépôt — non reproduit).
///
/// **AD-10 (défensif)** : options vides / `selected` hors options / option
/// `disabled` / spec absente → rendu **dégradé défini** (sélecteur vide
/// accessible / placeholder / option non cochable), jamais une exception.
///
/// **AD-13 / FR-26** : déclencheur avec une **seule** annonce accessible
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
/// (AD-48) au-dessus de `SmartSelect`, à l'**apparence DODLP** par défaut.
///
/// `const`-constructible et **sans side-effect d'import** (aucun `register*()`
/// top-level) : l'enrôlement est **explicite** via `ZcrudScope.selectPresenter`
/// (AR-4). Immuable ⇒ partageable en `const`.
class ZSmartSelectPresenter extends ZSelectPresenter {
  /// Constructeur `const` (présentateur immuable, injectable en `const`).
  ///
  /// [spec] surcharge **partiellement** l'apparence de référence DODLP. `null`
  /// (le défaut) ⇒ apparence DODLP intégrale.
  const ZSmartSelectPresenter({this.spec});

  /// Surcharge par paramètre — maillon de plus haute priorité de la chaîne
  /// `paramètre > jeton (`ZcrudTheme.select*`) > référence`, désormais
  /// **complète** (CR-SELECT-SEAM) et résolue par `zSelectTileMetricsOf`.
  final ZSelectTileSpec? spec;

  @override
  Widget present(BuildContext context, ZSelectPresentation presentation) {
    // Titre du modal + déclencheur : label déjà résolu (l10n) sinon repli sur la
    // spéc du champ. TOUJOURS non-null (assert `SmartSelect`).
    final String title = presentation.label ??
        presentation.field.label ??
        presentation.field.name;

    // CR-SELECT-SEAM — chaîne `paramètre > jeton > référence`, résolue UNE fois
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

    // CR-SELECT-SEAM — `field.leading`, parité DODLP (`ListTile.leading`).
    //
    // 🔴 Cette capacité avait été rapportée « inatteignable, le DTO ne la porte
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

    // CR-SELECT-SEAM — règle d'inertie EXACTE de DODLP :
    // `choiceBuilder == null && (readOnly || isLoading) ? null : showModal`.
    // Autrement dit un `choiceBuilder` RÉ-ACTIVE le déclencheur, y compris en
    // lecture seule : c'est le seul rendu possible de la donnée, il faut
    // pouvoir l'atteindre.
    //
    // 🔴 Hôte passif : avec les défauts du seam (`isLoading: false`,
    // `choiceBuilder: null`), cette expression vaut `!readOnly` — exactement
    // l'ancienne règle. Rien ne bouge.
    final bool tappable = presentation.choiceBuilder != null ||
        (!presentation.readOnly && !presentation.isLoading);

    // CR-SELECT-SEAM — barre d'actions du modal : ACTIVE par défaut (parité
    // DODLP). Un hôte peut la couper (`ZSelectTileSpec.showModalActions:
    // false`) pour retrouver les seules actions par défaut du fork.
    final bool showActions = spec?.showModalActions ?? true;

    // CR-SELECT-SEAM — chargeur asynchrone d'options, ENVELOPPÉ (AD-10).
    final S2ChoiceLoader<dynamic>? choiceLoader =
        _wrapLoader(context, presentation);

    // FR-26 : placeholder de l'état vide LOCALISÉ via la l10n injectée (clé
    // `select`, résolue en/fr par `ZcrudLocalizations`) — JAMAIS le littéral
    // anglais `'Select one'` / `'Select one or more'` du fork. Passé à
    // `SmartSelect` (paramètre `placeholder:`) ET employé directement dans le
    // déclencheur, pour que le libellé anglais du fork ne surface nulle part.
    final String placeholder = label(context, 'select');

    // CR-REQUIRED-INDICATOR — règle EXACTE de `ZFieldLabel` (cœur) :
    // `field.isRequired && !field.readOnly`. Lue sur `field`, pas sur
    // `presentation.readOnly` : c'est la spec du champ qui décide, comme dans le
    // rendu natif décoré (`zFieldDecoration` → `ZFieldLabel`).
    //
    // 🔴 Hôte passif : un champ NON requis rend `false` ⇒ aucune des deux
    // branches ci-dessous n'est empruntée (ni libellé enrichi, ni
    // `modalHeaderBuilder`), le rendu antérieur est strictement conservé.
    final bool requiredIndicator =
        presentation.field.isRequired && !presentation.field.readOnly;

    // FR-26 : indice du champ de recherche du modal — l10n (clé `search`),
    // jamais le `'Search on $title'` anglais que le fork poserait sinon
    // (`s2_state.dart:289`).
    final String filterHint = label(context, 'search');

    // Parité DODLP : `S2ChoiceStyle` d'option (sous-titre gris italique) et
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

    // Parité DODLP : en-tête de modal translucide + élévation 3.
    final S2ModalHeaderStyle headerStyle = S2ModalHeaderStyle(
      backgroundColor: scheme.surface.withValues(
        alpha: ZSelectTileReference.modalHeaderOpacity,
      ),
      elevation: ZSelectTileReference.modalHeaderElevation,
    );

    // Parité DODLP : `enableDrag`, `barrierDismissible`, `filterAuto` (la
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
        // CR-SELECT-SEAM : `null` ⇒ le fork reste SYNCHRONE sur `choiceItems`,
        // strictement comme avant (`S2Choices.isSync`).
        choiceLoader: choiceLoader,
        // CR-SELECT-SEAM : builder d'option hôte. `null` ⇒ le fork rend
        // l'option lui-même (switches/radios/…), rendu antérieur inchangé.
        choiceBuilder: presentation.choiceBuilder == null
            ? null
            : (ctx, _, choice) =>
                _buildHostChoice(ctx, presentation, choice, enabled: enabled),
        // CR-SELECT-SEAM : affordance de fin de ligne (Modifier/Copier chez
        // DODLP). `null` ⇒ slot ABSENT (AD-4), rendu antérieur inchangé.
        choiceSecondaryBuilder: presentation.choiceSecondaryBuilder == null
            ? null
            : (ctx, _, choice) => _buildHostSecondary(
                  ctx,
                  presentation,
                  choice,
                  enabled: enabled,
                ),
        // Parité DODLP EXACTE (`choiceDivider: field.choiceBuilder != null`) :
        // un rendu d'option sur mesure a besoin d'un séparateur, le rendu natif
        // du fork non. 🔴 Hôte passif : `false` — c'est aussi le DÉFAUT du fork
        // (`S2ChoiceConfig.useDivider = false`), donc rien ne bouge.
        choiceDivider: presentation.choiceBuilder != null,
        // CR-SELECT-SEAM — barre d'ACTIONS du modal (parité
        // `_modalActionsBuilder` DODLP) : créer / confirmer / réinitialiser.
        // 🔴 En MULTI searchable, la loupe est retirée : le champ de recherche
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
            // CR-REQUIRED-INDICATOR : hors multi searchable, l'en-tête du fork
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
        // Parité DODLP (`useConfirm: readOnly ? false : true`) : en multi, la
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
          // Parité DODLP : le multi affiche des PUCES, une par titre
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
        ),
      );
    }

    // Mono : `select` / `radio` (parité `radioAsModal` DODLP) — choix unique en
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
      choiceSecondaryBuilder: presentation.choiceSecondaryBuilder == null
          ? null
          : (ctx, _, choice) => _buildHostSecondary(
                ctx,
                presentation,
                choice,
                enabled: enabled,
              ),
      choiceDivider: presentation.choiceBuilder != null,
      // CR-SELECT-SEAM — même barre d'actions ; en MONO la recherche reste une
      // BASCULE (loupe), exactement comme DODLP (`useFilter: true`).
      modalActionsBuilder: showActions
          ? (ctx, state) => _modalActions(
                ctx,
                state,
                presentation,
                multiple: false,
                withFilterToggle: true,
              )
          : null,
      // CR-REQUIRED-INDICATOR — même règle qu'en multi : en-tête remplacé
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
      ),
    );
  }

  /// **En-tête de modal portant l'astérisque « requis »** (CR-REQUIRED-INDICATOR).
  ///
  /// Reproduit `S2State.defaultModalHeader` **à l'identique** (mêmes jetons de
  /// `modalHeaderStyle`, même `automaticallyImplyLeading`, même loupe de
  /// filtrage, même `modalError`, mêmes `modalActions` — donc la barre d'actions
  /// posée par `modalActionsBuilder` reste celle du présentateur), à une seule
  /// substitution près : le titre passe de `Text` à [_labelWithRequiredIndicator].
  ///
  /// 🔴 Installé UNIQUEMENT quand l'astérisque est dû — sinon `modalHeaderBuilder`
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

  /// **Barre d'actions du modal** — parité `_modalActionsBuilder` DODLP
  /// (`edition_screen.dart` l. ~2633), rendue accessible.
  ///
  /// Ordre et conditions **mesurés chez DODLP** :
  ///
  /// | Action | Condition DODLP | Ici |
  /// |---|---|---|
  /// | **Créer** | `crudDataSelect && allowErpRessourceCrud` | `crudHandler != null` et champ éditable |
  /// | **Confirmer** | `state.confirmButton` (mono) / `IconButton(check_circle_outline)` (multi) | une seule affordance, mêmes icônes |
  /// | **Réinitialiser** | `state.selection?.choice != null` | une valeur est sélectionnée, et le champ est éditable |
  /// | **Rechercher** (loupe) | `filter != null && !filter.activated` | idem, **sauf** en multi searchable (le champ est permanent) |
  ///
  /// 🔴 **Trois défauts de DODLP non reproduits ici :**
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
    // AD-10 : DODLP teste `state.mounted` en tête — un modal en cours de
    // fermeture ne doit pas reconstruire d'actions sur un état mort.
    if (!state.mounted) return const <Widget>[];

    final bool filtering = state.filter?.activated ?? false;
    final bool editable = !presentation.readOnly;
    final bool hasSelection = multiple
        ? _asList(presentation.selected).isNotEmpty
        : presentation.selected != null;

    final List<Widget> actions = <Widget>[];

    // Pendant la recherche, DODLP masque TOUTES les actions sauf la bascule :
    // la barre est alors occupée par le champ de saisie.
    if (!filtering) {
      if (presentation.crudHandler != null && editable) {
        actions.add(
          IconButton(
            tooltip: label(context, 'create'),
            icon: const Icon(Icons.add),
            onPressed: () => _createThenSelect(
              state,
              presentation,
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
            // FR-26 : RÔLE `error`, jamais le `kErrorColor` littéral de DODLP.
            color: Theme.of(context).colorScheme.error,
            icon: const Icon(Icons.block),
            onPressed: () {
              // AD-2/SM-1 : on NOTIFIE la tranche ; c'est la réécriture de la
              // valeur qui rafraîchit le sélecteur, pas un `setState` global.
              presentation.onChanged(multiple ? const <Object?>[] : null);
              // 🔴 INDISPENSABLE, et mesuré : en MONO le fork n'exige pas de
              // confirmation (`useConfirm == false`), si bien que `showModal()`
              // rappelle `onChange()` à la fermeture **avec l'ancienne
              // sélection** (`s2_state.dart`, l. ~800) — la valeur qu'on vient
              // d'effacer serait aussitôt réécrite. Vider la sélection du fork
              // rend `selection.choice` nul et coupe ce rappel. C'est
              // exactement ce que DODLP fait à la main
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

  /// **En-tête du modal MULTI avec champ de recherche PERMANENT** — parité
  /// `_modalBuilder` DODLP, qui pose la recherche dans une ligne **sous la barre
  /// de titre et au-dessus des options** (leur `ListTile(leading: Icon(search),
  /// title: state.modalFilter)`), après avoir forcé son ouverture depuis
  /// `onModalOpen`.
  ///
  /// 🔴 **Pourquoi ne PAS reprendre leur mécanisme.** DODLP obtient ce rendu en
  /// appelant `state.filter?.show(state.modalContext)` à l'ouverture, ce qui
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
          // CR-REQUIRED-INDICATOR : le titre n'est enrichi que si l'astérisque
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
              // fork ni un littéral français comme chez DODLP.
              labelText: label(context, 'search'),
              isDense: true,
            ),
            // Le filtre du fork applique la requête ; `filterAuto` étant actif,
            // DODLP passerait par un debouncer — ici la liste est cliente et le
            // coût est nul, on applique directement.
            onChanged: (q) => state.filter?.apply(q),
          ),
        ),
      ],
    );
  }

  /// Crée une entité via le port **neutre** `ZRelationCrudHandler`, puis
  /// **auto-sélectionne** l'option résultante (parité DODLP `_onCrud`).
  ///
  /// AD-10 : `Future` en erreur **ou** résultat `null` (annulation) ⇒ aucune
  /// écriture, aucun crash — équivalent exact de leur `try/catch (_) {}`.
  /// AD-2 : la sélection passe par `onChanged`, jamais par une mutation directe
  /// de l'état interne du fork (ce que DODLP fait, avec un
  /// `Future.delayed(500ms)` pour que ça « prenne »).
  Future<void> _createThenSelect(
    S2State<dynamic> state,
    ZSelectPresentation presentation, {
    required bool multiple,
  }) async {
    ZFieldChoice? created;
    try {
      created = await presentation.crudHandler!.create(
        const <String, Object?>{},
      );
    } catch (_) {
      return;
    }
    if (created == null) return;
    if (multiple) {
      final List<Object?> next = _asList(presentation.selected);
      if (!next.contains(created.value)) next.add(created.value);
      presentation.onChanged(next);
    } else {
      presentation.onChanged(created.value);
    }
    if (state.mounted) state.closeModal(confirmed: false);
  }

  /// Enveloppe le [ZSelectOptionsLoader] hôte en `S2ChoiceLoader` — **le seul**
  /// point où la frontière asynchrone est franchie (AD-40 : `S2ChoiceLoaderInfo`
  /// ne remonte jamais au seam).
  ///
  /// 🔴 **AD-10 — trois défaillances, un seul rendu dégradé.** Le fork ne
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
  /// 🔴 **Résolution l10n capturée SYNCHRONEMENT.** `label(context, …)` consulte
  /// des `InheritedWidget` (`dependOnInheritedWidgetOfExactType`) : l'appeler
  /// depuis une continuation asynchrone, sur un `context` peut-être démonté,
  /// serait un usage hors-`build`. Les deux résolveurs sont donc capturés ici,
  /// pendant `present()`, et la continuation n'appelle plus qu'une fonction
  /// **pure**.
  ///
  /// 🔴 **AD-2/SM-1** : rien de tout cela ne touche le `ZFormController`, ne
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
        // 🔴 `catch (_)` NU et délibéré : `on Exception` laisserait passer les
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
  /// l'hôte (AD-40 : `S2Choice` ne franchit pas la frontière).
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
  /// 🔴 **Écart assumé, et mesuré** : le seam laisse l'hôte rendre `null` pour
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
  /// `AppPlatform.isWebOrDesktop` de DODLP, cf. [ZSelectModalShape.adaptive]).
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
  /// seul** point de traduction du paquet (AD-40 : le type fork ne franchit
  /// jamais la frontière publique).
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

  /// Normalise la sélection multi (défensif AD-10) : scalaire/`null` → `List`.
  static List<Object?> _asList(Object? selected) {
    if (selected is List) return List<Object?>.from(selected);
    if (selected == null) return const <Object?>[];
    return <Object?>[selected];
  }
}

/// Libellé + **astérisque « requis » décoratif** (CR-REQUIRED-INDICATOR).
///
/// 🔴 **Pourquoi ce n'est PAS `ZFieldLabel`** — et ce n'est pas un choix de
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

/// Déclencheur du modal S2, à l'**apparence DODLP** (AD-13 / FR-26).
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
/// défaut DODLP non reproduit n°2) ; `contentPadding` **directionnel** ; chevron
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
    this.leading,
    this.valueText,
    this.chipLabels,
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
  /// 🔴 **Distinct de [enabled]** depuis CR-SELECT-SEAM : DODLP neutralise le
  /// tap sur `readOnly || isLoading`, **sauf** si un `choiceBuilder` est fourni.
  /// Sans les deux drapeaux du seam, ces deux notions se confondaient.
  final bool tappable;

  /// Affiche le chevron de fin de ligne (résolu par l'appelant : paramètre,
  /// sinon la règle DODLP « oui sauf en lecture seule »).
  final bool showChevron;

  /// CR-SELECT-SEAM — ornement de **tête** déjà résolu en widget par
  /// `resolveAdornment` (parité `field.leading` DODLP). `null` ⇒ slot ABSENT de
  /// l'arbre (AD-4), rendu antérieur strictement conservé.
  final Widget? leading;

  /// Ouvre le modal S2.
  final VoidCallback onTap;

  /// Métriques déjà résolues (paramètre > jeton > référence).
  final ZSelectTileMetrics metrics;

  /// CR-REQUIRED-INDICATOR — `field.isRequired && !field.readOnly`, déjà résolu
  /// par `present()`. Pilote **deux** canaux, jamais un seul (AD-13) :
  /// l'astérisque **visuel** (décoratif) et `Semantics.isRequired` (annoncé).
  /// `false` ⇒ tile strictement identique au rendu antérieur.
  final bool requiredIndicator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // Parité DODLP : `readOnly && rien de sélectionné` → le tile DISPARAÎT
    // (leur `const EmptyContainer()`, l. ~2905 et ~3072).
    if (!enabled && !hasValue) return const SizedBox.shrink();

    // 🔴 AD-13 : le plancher de 48 dp ne peut être que REHAUSSÉ — la garantie
    // est déjà tenue par `zSelectTileMetricsOf` (paramètre ET jeton), ce
    // `math.max` la rend **locale** : quelle que soit l'origine des métriques,
    // ce widget ne pose jamais une contrainte inférieure au plancher.
    final double minHeight = math.max(
      ZSelectTileReference.minTileHeight,
      metrics.minHeight,
    );

    final Widget subtitle = chipLabels == null
        ? _monoSubtitle(theme)
        : _multiSubtitle(context);

    // Valeur annoncée : le texte mono, ou les puces jointes. `null` si vide —
    // l'état vide N'EST donc PAS annoncé comme une valeur (AD-13 : l'état ne
    // repose pas sur la seule couleur du placeholder).
    final String? semanticValue = !hasValue
        ? null
        : (chipLabels != null ? chipLabels!.join(', ') : valueText);

    return Semantics(
      button: true,
      // 🔴 `tappable`, PAS `enabled` : on annonce ce qu'on peut faire, et un
      // `choiceBuilder` rend le déclencheur actionnable même en lecture seule.
      // Hôte passif : sans builder ni chargement, `tappable == !readOnly`,
      // c'est-à-dire exactement l'ancienne valeur — rien ne bouge.
      enabled: tappable,
      label: label,
      value: semanticValue,
      // 🔴 AD-13 — l'astérisque n'est PAS le seul canal, et surtout pas un canal
      // audible : il est `ExcludeSemantics`, et de toute façon `excludeSemantics:
      // true` ci-dessous écarte tous les descendants. C'est CE drapeau qui porte
      // « requis » jusqu'au lecteur d'écran, exactement comme le fait
      // `ZDecoratedFieldTrigger` du cœur.
      isRequired: requiredIndicator,
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
            // CR-REQUIRED-INDICATOR : aucun style imposé (`style: null`) — le
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
            // 🔴 MESURÉ : un `ListTile` à `enabled: false` IGNORE son `onTap`.
            // Poser `enabled` ici aurait rendu la règle DODLP « un
            // `choiceBuilder` ré-active le tap » inopérante — le tile aurait eu
            // un `onTap` que rien ne pouvait déclencher. DODLP ne touche
            // d'ailleurs jamais ce paramètre : il annule seulement `onTap`.
            enabled: tappable,
          ),
        ),
      ),
    );
  }

  /// Sous-titre **mono** — parité DODLP : le titre sélectionné, sinon le
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

  /// Sous-titre **multi** — parité DODLP : `Wrap(spacing: 6, runSpacing: 4)` de
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
