/// `ZCountryPickerField` — **sélecteur pays inline réutilisable** (interne,
/// E11a-2, AD-2/AD-13).
///
/// origine: le champ pays, le champ téléphone (indicatif) et le sous-formulaire
/// adresse ont tous besoin de choisir un pays depuis le [ZCountryCatalog]. Ce
/// widget factorise ce comportement : une **cible tactile ≥48 dp** (drapeau + nom
/// ou indicatif) qui déplie un **panneau de recherche + liste** (`ListView.builder`)
/// alimenté paresseusement par le catalogue.
///
/// **AD-2** : `TextEditingController`/`FocusNode` de recherche créés **1×**
/// (`initState`), disposés en `dispose`, jamais recréés (learning anti-fuite E5).
/// Le chargement paresseux du catalogue déclenche un `setState` **local** (rebuild
/// ciblé de ce champ uniquement, jamais du formulaire).
///
/// **Interne** : jamais exporté par le barrel. N'expose aucun type de lib tierce.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/z_country_catalog.dart';
import '../domain/z_country_info.dart';

/// Sélecteur pays inline (drapeau + nom/indicatif) déployant recherche + liste.
class ZCountryPickerField extends StatefulWidget {
  /// Construit le sélecteur. [selectedIso] est le code ISO courant (valeur de
  /// tranche pour le champ pays), [onSelected] émet le pays choisi.
  const ZCountryPickerField({
    required this.catalog,
    required this.selectedIso,
    required this.onSelected,
    this.readOnly = false,
    this.compact = false,
    this.semanticLabel,
    this.placeholder,
    this.listMaxHeight = 240,
    super.key,
  });

  /// Catalogue pays (paresseux + caché), injecté par closure de factory.
  final ZCountryCatalog catalog;

  /// Code ISO alpha-2 actuellement sélectionné (`null` si aucun).
  final String? selectedIso;

  /// Émet le pays choisi (l'appelant en extrait `isoCode`/`dialCode`).
  final ValueChanged<ZCountryInfo> onSelected;

  /// Champ en lecture seule (déploiement désactivé).
  final bool readOnly;

  /// Rendu **compact** (drapeau + indicatif) pour le champ téléphone ; sinon
  /// drapeau + nom.
  final bool compact;

  /// Libellé sémantique explicite (a11y, AD-13).
  final String? semanticLabel;

  /// Texte de substitution quand aucun pays n'est sélectionné.
  final String? placeholder;

  /// Hauteur max de la liste déployée (dimension injectable).
  final double listMaxHeight;

  @override
  State<ZCountryPickerField> createState() => _ZCountryPickerFieldState();
}

class _ZCountryPickerFieldState extends State<ZCountryPickerField> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocus = FocusNode();
    // Chargement paresseux : au premier montage, si le catalogue n'est pas encore
    // résolu, on le charge puis on rebuild CE champ (setState local, SM-1 intact).
    if (!widget.catalog.isLoaded) {
      widget.catalog.load().then((_) {
        if (mounted) setState(() {});
      });
    }
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

  void _select(ZCountryInfo country) {
    widget.onSelected(country);
    setState(() {
      _open = false;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final selected =
        widget.selectedIso == null ? null : widget.catalog.byIso(widget.selectedIso!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _trigger(theme, selected),
        if (_open) ...<Widget>[
          SizedBox(height: theme.gapS),
          _searchBox(theme),
          SizedBox(height: theme.gapS),
          _resultsList(theme),
        ],
      ],
    );
  }

  Widget _trigger(ZcrudTheme theme, ZCountryInfo? selected) {
    final semLabel = widget.semanticLabel ??
        label(context, 'intl.country', fallback: 'Pays');
    final display = _triggerText(selected);
    return Semantics(
      container: true,
      button: !widget.readOnly,
      label: semLabel,
      value: display,
      // MEDIUM-2 (AD-13 opérabilité) : câbler l'action de tap SUR le nœud
      // sémantique englobant — sinon `ExcludeSemantics` retire l'action native
      // de l'`InkWell` et le lecteur d'écran ne peut PAS déclencher l'ouverture.
      onTap: widget.readOnly ? null : _toggle,
      child: ExcludeSemantics(
        child: InkWell(
          key: const Key('z-country-picker-trigger'),
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
                  if (selected?.flagEmoji != null) ...<Widget>[
                    Text(selected!.flagEmoji!),
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

  String _triggerText(ZCountryInfo? selected) {
    if (selected == null) {
      return widget.placeholder ??
          label(context, 'intl.country.select', fallback: 'Sélectionner…');
    }
    if (widget.compact) {
      return selected.dialCode ?? selected.isoCode;
    }
    return selected.name ?? selected.isoCode;
  }

  Widget _searchBox(ZcrudTheme theme) => TextField(
        key: const Key('z-country-picker-search'),
        controller: _searchController,
        focusNode: _searchFocus,
        textAlign: TextAlign.start,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search),
          labelText: label(context, 'intl.country.search', fallback: 'Rechercher'),
        ),
        onChanged: (_) => setState(() {}),
      );

  Widget _resultsList(ZcrudTheme theme) {
    final results = widget.catalog.search(_searchController.text);
    if (results.isEmpty) {
      return Padding(
        padding: EdgeInsetsDirectional.symmetric(vertical: theme.gapS),
        child: Text(
          label(context, 'intl.country.empty', fallback: 'Aucun résultat'),
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
            final c = results[i];
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Semantics(
                container: true,
                button: true,
                label: c.name ?? c.isoCode,
                // MEDIUM-2 : action de sélection portée par le nœud sémantique
                // englobant (opérable au lecteur d'écran malgré ExcludeSemantics).
                onTap: () => _select(c),
                child: ExcludeSemantics(
                  child: ListTile(
                    key: Key('z-country-item-${c.isoCode}'),
                    dense: false,
                    leading: c.flagEmoji == null ? null : Text(c.flagEmoji!),
                    title: Text(c.name ?? c.isoCode, textAlign: TextAlign.start),
                    trailing: c.dialCode == null ? null : Text(c.dialCode!),
                    onTap: () => _select(c),
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
