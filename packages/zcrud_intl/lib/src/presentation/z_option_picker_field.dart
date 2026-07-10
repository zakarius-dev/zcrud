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
  /// - [readOnly] : déploiement désactivé.
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
    super.key,
  });

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

  @override
  State<ZOptionPickerField<T>> createState() => _ZOptionPickerFieldState<T>();
}

class _ZOptionPickerFieldState<T> extends State<ZOptionPickerField<T>> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocus = FocusNode();
  }

  @override
  void dispose() {
    // Anti-fuite (learning E5) : libérer contrôleur + focus de recherche.
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.readOnly) return;
    setState(() => _open = !_open);
  }

  void _select(T item) {
    widget.onSelected(item);
    setState(() {
      _open = false;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _trigger(theme),
        if (_open) ...<Widget>[
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
    final semLabel = widget.semanticLabel ??
        label(context, 'intl.option', fallback: 'Sélection');
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: theme.gapM,
                vertical: theme.gapS,
              ),
              child: Row(
                children: <Widget>[
                  if (widget.selectedLeading != null) ...<Widget>[
                    Text(widget.selectedLeading!),
                    SizedBox(width: theme.gapS),
                  ],
                  Expanded(
                    child: Text(
                      display,
                      textAlign: TextAlign.start,
                      style: TextStyle(color: theme.labelColor),
                    ),
                  ),
                  Icon(
                    _open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: theme.labelColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchBox(ZcrudTheme theme) => TextField(
        key: Key('${widget.keyPrefix}-search'),
        controller: _searchController,
        focusNode: _searchFocus,
        textAlign: TextAlign.start,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search),
          labelText: label(context, 'intl.option.search', fallback: 'Rechercher'),
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
