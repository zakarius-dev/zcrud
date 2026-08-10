/// `ZOptionPickerField<T>` — **sélecteur inline générique réutilisable**
/// (interne, E11b-2, AD-2/AD-13).
///
/// origine: `ZCurrencyField` (devise) et `ZStateField` (état/province), ainsi que
/// le sous-champ `region` de `ZAddressField`, ont tous besoin du **même**
/// comportement de sélection que le picker pays d'E11a-2 : une **cible tactile
/// ≥48 dp** (Semantics **opérable** MEDIUM-2) qui déplie un **panneau recherche +
/// liste** (`ListView.builder`). Pour **ne pas dupliquer** la logique a11y/RTL
/// (retro E10 AI-E10-1) entre les nouveaux champs, ce widget la factorise **une
/// seule fois**, paramétré par des accesseurs (`itemKey`/`itemTitle`/…).
///
/// **AD-2** : `TextEditingController`/`FocusNode` de recherche créés **1×**
/// (`initState`), disposés, jamais recréés. Aucune reconstruction globale : la
/// recherche déclenche un `setState` **local**.
///
/// **AD-13** : trigger + items Semantics **opérables** (action `tap` sur le nœud
/// englobant), cibles **≥ 48 dp**, thème injecté (`ZcrudTheme.of`), directionnel.
///
/// **ZDisplayState (CR-IFFD-38)** : l'état « déplié » accepte un
/// [ZOptionPickerField.openController] **optionnel**. Sans lui, comportement
/// **strictement inchangé** (état interne). Avec lui, le contrôleur est **LA
/// source de vérité** — aucun miroir n'est conservé (cf. [ZDisplayStateBinding]).
/// Toute fermeture décidée par le composant (sélection, `readOnly`) est écrite
/// **à travers** le contrôleur : l'hôte ne peut donc jamais croire le panneau
/// ouvert alors qu'il est fermé.
///
/// **Interne** : jamais exporté par le barrel ; n'expose aucun type de lib tierce.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Sélecteur inline générique déployant recherche + liste sur des options [T].
class ZOptionPickerField<T> extends StatefulWidget {
  /// Construit le sélecteur.
  ///
  /// - [keyPrefix] : préfixe des `Key` de test (`<prefix>-trigger`/`-search`/
  ///   `-item-<key>`), ex. `"z-currency"` / `"z-state"` ;
  /// - [search] : filtre les options selon la requête courante ;
  /// - [itemKey]/[itemTitle] : clé stable + libellé d'une option ;
  /// - [itemLeading]/[itemTrailing] : décor optionnel (symbole/code) ;
  /// - [selectedTitle]/[selectedLeading] : affichage de l'option sélectionnée ;
  /// - [onSelected] : émet l'option choisie ;
  /// - [searchable] : masque la boîte de recherche si `false` (option neutre) ;
  /// - [readOnly] : déploiement désactivé ;
  /// - [openController] : commande **optionnelle** du déploiement par l'hôte.
  const ZOptionPickerField({
    required this.keyPrefix,
    required this.search,
    required this.itemKey,
    required this.itemTitle,
    required this.onSelected,
    this.itemLeading,
    this.itemTrailing,
    this.selectedTitle,
    this.selectedLeading,
    this.readOnly = false,
    this.searchable = true,
    this.semanticLabel,
    this.placeholder,
    this.listMaxHeight = 240,
    this.openController,
    this.decoration,
    super.key,
  });

  /// Décoration **thémée** du déclencheur (CR-DODLP-INTL-DECORATION).
  ///
  /// `null` ⇒ rendu **strictement inchangé** (chemin des champs devise/état, qui
  /// ne sont pas dans le périmètre de la CR). Fournie ⇒ le déclencheur est rendu
  /// par un `InputDecorator`, comme `ZDecoratedFieldTrigger` du cœur : libellé
  /// au repos quand vide / flottant quand rempli, chevron en `suffixIcon` sauf
  /// si un ornement de fin est déjà déclaré.
  ///
  /// Une décoration **sans libellé** signale le mode `bare` : le nœud sémantique
  /// n'en pose alors aucun (l'ancêtre `ZLargeFieldCard` le porte).
  final InputDecoration? decoration;

  /// Préfixe des clés de test (`<prefix>-trigger`, `<prefix>-item-<key>`…).
  final String keyPrefix;

  /// Filtre les options selon la requête (chaîne vide → toutes les options).
  final List<T> Function(String query) search;

  /// Clé stable d'une option (utilisée pour `ValueKey` d'item).
  final String Function(T item) itemKey;

  /// Libellé principal d'une option.
  final String Function(T item) itemTitle;

  /// Décor de tête optionnel (symbole/emoji) d'une option.
  final String? Function(T item)? itemLeading;

  /// Décor de queue optionnel (code) d'une option.
  final String? Function(T item)? itemTrailing;

  /// Émet l'option choisie.
  final ValueChanged<T> onSelected;

  /// Libellé de l'option sélectionnée (affiché sur le trigger).
  final String? selectedTitle;

  /// Décor de tête de l'option sélectionnée.
  final String? selectedLeading;

  /// Champ en lecture seule (déploiement désactivé).
  final bool readOnly;

  /// Affiche la boîte de recherche (option neutre).
  final bool searchable;

  /// Libellé sémantique explicite (a11y, AD-13).
  final String? semanticLabel;

  /// Texte de substitution quand aucune option n'est sélectionnée.
  final String? placeholder;

  /// Hauteur max de la liste déployée.
  final double listMaxHeight;

  /// Commande **optionnelle** du déploiement depuis l'hôte (AD-4).
  ///
  /// `null` ⇒ le champ se gouverne seul, comportement **strictement inchangé**.
  /// Fourni ⇒ il devient la **source de vérité** de l'ouverture : l'hôte peut
  /// déplier (retour de validation pointant le champ fautif, bouton « choisir »
  /// placé ailleurs, restauration d'état) **et** replier (navigation).
  ///
  /// Doit être possédé **hors `build`** (`ZDisplayStateOwnerMixin`).
  final ZToggleController? openController;

  @override
  State<ZOptionPickerField<T>> createState() => _ZOptionPickerFieldState<T>();
}

class _ZOptionPickerFieldState<T> extends State<ZOptionPickerField<T>> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;

  /// État « déplié » : interne par défaut, **traversant** vers
  /// [ZOptionPickerField.openController] dès qu'il est fourni. Aucun miroir
  /// `bool` n'est conservé ⇒ les deux états ne peuvent pas diverger.
  late final ZDisplayStateBinding<bool> _open;

  /// Vrai pendant `didUpdateWidget` : le rebuild vient de toute façon, un
  /// `setState` y serait illégal (on est dans la phase de build).
  bool _inDidUpdate = false;

  bool _readOnlyCloseScheduled = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocus = FocusNode();
    _open = ZDisplayStateBinding<bool>(consumer: this, initialValue: false)
      ..bind(widget.openController);
    _open.listenable.addListener(_onOpenChanged);
  }

  @override
  void didUpdateWidget(covariant ZOptionPickerField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'hôte a le droit de changer (ou de retirer) son contrôleur.
    _inDidUpdate = true;
    _open.bind(widget.openController);
    _inDidUpdate = false;
    if (widget.readOnly && _open.value) _scheduleReadOnlyClose();
  }

  @override
  void dispose() {
    // Anti-fuite (learning E5) : libérer contrôleur + focus de recherche.
    _searchController.dispose();
    _searchFocus.dispose();
    // ⚠️ La liaison ne dispose JAMAIS le contrôleur de l'hôte : il ne nous
    // appartient pas (son propriétaire est un `State` de l'hôte).
    _open.listenable.removeListener(_onOpenChanged);
    _open.dispose();
    super.dispose();
  }

  void _onOpenChanged() {
    if (widget.readOnly && _open.value) _scheduleReadOnlyClose();
    if (!mounted || _inDidUpdate) return;
    setState(() {});
  }

  /// `readOnly` **prime** : le panneau ne se déplie jamais. On REND alors la
  /// vérité au contrôleur (post-frame, pour ne jamais écrire pendant un build)
  /// — sans quoi l'hôte croirait le sélecteur ouvert alors qu'il est fermé.
  void _scheduleReadOnlyClose() {
    if (_readOnlyCloseScheduled) return;
    _readOnlyCloseScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readOnlyCloseScheduled = false;
      if (!mounted || !widget.readOnly) return;
      _open.value = false;
    });
  }

  /// Vrai si le panneau est effectivement déplié dans l'arbre rendu.
  bool get _isOpen => _open.value && !widget.readOnly;

  void _toggle() {
    if (widget.readOnly) return;
    _open.value = !_open.value;
  }

  void _select(T item) {
    widget.onSelected(item);
    _searchController.clear();
    // Fermeture décidée par le composant : elle passe **par** le contrôleur.
    _open.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _trigger(theme),
        if (_isOpen) ...<Widget>[
          SizedBox(height: theme.gapS),
          if (widget.searchable) ...<Widget>[
            _searchBox(theme),
            SizedBox(height: theme.gapS),
          ],
          _resultsList(theme),
        ],
      ],
    );
  }

  Widget _trigger(ZcrudTheme theme) {
    final deco = widget.decoration;
    final bare = deco != null && deco.label == null && deco.labelText == null;
    final semLabel = bare
        ? null
        : (widget.semanticLabel ??
            label(context, 'intl.option', fallback: 'Sélection'));
    final hasValue = widget.selectedTitle != null;
    final display = widget.selectedTitle ??
        widget.placeholder ??
        label(context, 'intl.option.select', fallback: 'Sélectionner…');
    return Semantics(
      container: true,
      button: !widget.readOnly,
      label: semLabel,
      value: display,
      // MEDIUM-2 (AD-13) : action de tap SUR le nœud englobant → opérable au
      // lecteur d'écran malgré `ExcludeSemantics`.
      onTap: widget.readOnly ? null : _toggle,
      child: ExcludeSemantics(
        child: InkWell(
          key: Key('${widget.keyPrefix}-trigger'),
          onTap: widget.readOnly ? null : _toggle,
          // AD-13 : cible tactile portée par la CONTRAINTE LIANTE, jamais par
          // la hauteur intrinsèque de l'`InputDecorator`.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: deco == null
                ? Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      horizontal: theme.gapM,
                      vertical: theme.gapS,
                    ),
                    child: _triggerRow(theme, display, withChevron: true),
                  )
                : InputDecorator(
                    decoration: _decorate(deco),
                    isEmpty: !hasValue,
                    child: _triggerRow(
                      theme,
                      hasValue || bare ? display : '',
                      withChevron: false,
                      hint: !hasValue,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Chevron d'affordance + état `enabled` — un ornement de fin déclaré par
  /// l'appelant n'est jamais écrasé (parité `ZDecoratedFieldTrigger`).
  InputDecoration _decorate(InputDecoration deco) {
    var d = deco;
    if (d.suffixIcon == null && d.suffix == null && d.suffixText == null) {
      d = d.copyWith(
        suffixIcon: Icon(_isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
      );
    }
    return d.copyWith(enabled: !widget.readOnly);
  }

  Widget _triggerRow(
    ZcrudTheme theme,
    String text, {
    required bool withChevron,
    bool hint = false,
  }) {
    final materialTheme = Theme.of(context);
    // FR-26 : aucune couleur en dur.
    final style = withChevron
        ? TextStyle(color: theme.labelColor)
        : hint
            ? materialTheme.textTheme.bodyLarge
                ?.copyWith(color: materialTheme.hintColor)
            : materialTheme.textTheme.bodyLarge;
    return Row(
      children: <Widget>[
        if (widget.selectedLeading != null) ...<Widget>[
          Text(widget.selectedLeading!),
          SizedBox(width: theme.gapS),
        ],
        Expanded(
          child: Text(text, textAlign: TextAlign.start, style: style),
        ),
        if (withChevron)
          Icon(
            _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: theme.labelColor,
          ),
      ],
    );
  }

  Widget _searchBox(ZcrudTheme theme) => TextField(
        key: Key('${widget.keyPrefix}-search'),
        controller: _searchController,
        focusNode: _searchFocus,
        textAlign: TextAlign.start,
        // Fabrique THÉMÉE du cœur : le panneau déplié ne peut pas rester en
        // trait souligné sous un déclencheur encarté.
        decoration: theme.inputDecoration(
          context,
          label: label(context, 'intl.option.search', fallback: 'Rechercher'),
          prefixIcon: const Icon(Icons.search),
        ),
        onChanged: (_) => setState(() {}),
      );

  Widget _resultsList(ZcrudTheme theme) {
    final results = widget.search(_searchController.text);
    if (results.isEmpty) {
      return Padding(
        padding: EdgeInsetsDirectional.symmetric(vertical: theme.gapS),
        child: Text(
          label(context, 'intl.option.empty', fallback: 'Aucun résultat'),
          textAlign: TextAlign.start,
          style: TextStyle(color: theme.labelColor),
        ),
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.listMaxHeight),
      child: Scrollbar(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: results.length,
          itemBuilder: (context, i) {
            final item = results[i];
            final title = widget.itemTitle(item);
            final leading = widget.itemLeading?.call(item);
            final trailing = widget.itemTrailing?.call(item);
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Semantics(
                container: true,
                button: true,
                label: title,
                // MEDIUM-2 : action de sélection portée par le nœud englobant.
                onTap: () => _select(item),
                child: ExcludeSemantics(
                  child: ListTile(
                    key: Key('${widget.keyPrefix}-item-${widget.itemKey(item)}'),
                    dense: false,
                    leading: leading == null ? null : Text(leading),
                    title: Text(title, textAlign: TextAlign.start),
                    trailing: trailing == null ? null : Text(trailing),
                    onTap: () => _select(item),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
