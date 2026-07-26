/// Page-shell déclaratif : `ZSearchableAppBar` (app-bar recherchable) +
/// `ZPageScaffold` (assemblage titre/actions/recherche/onglets/modes) — SUF-1.
///
/// Ce fichier est le **cœur de bibliothèque** partagé par les deux parties
/// ([ZSearchableAppBar] et [ZPageScaffold]). Il porte les briques privées
/// factorisées (contrôleur d'état de recherche `_ZSearchController`, résolution
/// de labels, constructeurs de tranches leading/titre/actions) — ainsi le motif
/// `SliverAppBar`/app-bar-recherchable qu'on élimine des applications hôtes
/// n'est **pas re-dupliqué** entre le mode fixe et le mode sliver (SUF-1, T3).
///
/// **AD-2/AD-15** : l'état de recherche (`isSearching`/`query`) est détenu par
/// un `ValueNotifier` **interne** au widget — aucun gestionnaire d'état importé
/// (`get`/`flutter_riverpod`/`provider`), aucun contrôleur externe requis. La
/// frappe reconstruit **seulement** la tranche app-bar (via
/// `ValueListenableBuilder`), jamais le corps des onglets (SM-1).
///
/// **AD-13** : insets/positions **directionnels** (RTL-safe), `Semantics`
/// explicites, cibles ≥ 48 dp, `const` là où l'immuabilité le permet.
///
/// **AD-29** : dépend UNIQUEMENT de `zcrud_core` (+ flutter) et **consomme** ses
/// seams (`ZcrudScope`/`ZcrudLocalizations`) en lecture, avec repli sur
/// `MaterialLocalizations` — aucun symbole de `zcrud_core` redéclaré/ré-exporté.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_app_bar_action.dart';
import '../domain/z_app_bar_search_config.dart';
import '../domain/z_page_app_bar_mode.dart';
import '../domain/z_page_tab.dart';

part 'z_page_scaffold.dart';
part 'z_searchable_app_bar.dart';

/// Contrôleur d'état de recherche **détenu par le widget** (AD-2/AD-15).
///
/// Propriétaire unique de `isSearching`/`query` + du `TextEditingController` et
/// du `FocusNode` (créés une fois, `dispose`és une fois — jamais recréés au
/// rebuild). Aucun état global, aucun singleton : chaque app-bar a le sien.
///
/// **La config n'est jamais copiée** : elle est lue **au moment de l'émission**
/// via [_configOf] (`() => widget.search`). `ZAppBarSearchConfig` est une valeur
/// `@immutable` que l'hôte remplace à chaque `build` (son `onQueryChanged` est
/// typiquement une closure recréée capturant l'onglet/dossier courant) —
/// capturer la première instance figerait le point d'émission et perdrait la
/// frappe **en silence**. Le rendu (hint/icône) et l'émission lisent donc
/// **la même** config fraîche.
class _ZSearchController {
  _ZSearchController(this._configOf)
      : _isSearching = ValueNotifier<bool>(false),
        query = ValueNotifier<String>(_configOf()?.initialQuery ?? ''),
        textController =
            TextEditingController(text: _configOf()?.initialQuery ?? ''),
        focusNode = FocusNode();

  /// Accès **paresseux** à la config courante du widget propriétaire (jamais
  /// une copie : relu à chaque émission).
  final ZAppBarSearchConfig? Function() _configOf;
  final ValueNotifier<bool> _isSearching;

  /// Query détenue par le widget (source de vérité de la saisie).
  final ValueNotifier<String> query;

  /// Contrôleur de saisie (état d'entrée détenu par le widget).
  final TextEditingController textController;

  /// Focus du champ de recherche (autofocus à l'ouverture).
  final FocusNode focusNode;

  /// Tranche réactive de bascule recherche (lecture seule).
  ValueListenable<bool> get isSearching => _isSearching;

  /// Ouvre la recherche (morphe l'app-bar en champ, autofocus).
  void open() => _isSearching.value = true;

  /// Émet la query **exacte** : met à jour l'état détenu ET notifie l'app.
  /// La config est relue **maintenant** (jamais la copie d'un `initState`).
  void onChanged(String text) {
    query.value = text;
    _configOf()?.onQueryChanged(text);
  }

  /// Ferme la recherche : **vide** le champ, remet `query = ''`, émet `''` et
  /// restaure le titre (AC7).
  void close() {
    textController.clear();
    query.value = '';
    _isSearching.value = false;
    _configOf()?.onQueryChanged('');
  }

  /// Bascule ouvrir/fermer (fermeture ⇒ reset complet via [close]).
  void toggle() => _isSearching.value ? close() : open();

  /// Resynchronise l'état détenu quand la **prop** `search` change d'un build à
  /// l'autre (appelé depuis `didUpdateWidget` des deux propriétaires).
  ///
  /// Ne recrée **jamais** le `TextEditingController`/`FocusNode` (invariant
  /// AD-2 : pas de controller recréé au rebuild) — seul l'état déclaré change :
  /// * `search` retirée (non-null → null) ⇒ la recherche se referme et le champ
  ///   est vidé, **sans** émettre vers le callback disparu ;
  /// * `initialQuery` déclaré différemment (y compris à l'apparition d'une
  ///   config, null → non-null) ⇒ la nouvelle valeur initiale est adoptée ;
  /// * simple remplacement de la closure `onQueryChanged` ⇒ **aucun** effet sur
  ///   la saisie en cours (elle est déjà relue à l'émission).
  void didUpdateConfig(
    ZAppBarSearchConfig? previous,
    ZAppBarSearchConfig? current,
  ) {
    if (current == null) {
      if (previous == null) return;
      _isSearching.value = false;
      if (query.value.isNotEmpty) {
        textController.clear();
        query.value = '';
      }
      return;
    }
    if (previous?.initialQuery == current.initialQuery) return;
    // Nouvelle valeur initiale DÉCLARÉE : elle prime sur la saisie précédente.
    textController.value = TextEditingValue(
      text: current.initialQuery,
      selection:
          TextSelection.collapsed(offset: current.initialQuery.length),
    );
    query.value = current.initialQuery;
  }

  void dispose() {
    _isSearching.dispose();
    query.dispose();
    textController.dispose();
    focusNode.dispose();
  }
}

/// Résout un libellé par composition défensive (AD-13/AD-10) :
/// `ZcrudScope.labels` → `ZcrudLocalizations` → `MaterialLocalizations`.
/// Jamais de throw, jamais de chaîne codée en dur.
String _resolveSearchLabel(BuildContext context) =>
    ZcrudScope.maybeOf(context)?.labels?.maybeResolve('search') ??
    ZcrudLocalizations.maybeOf(context)?.maybeResolve('search') ??
    MaterialLocalizations.of(context).searchFieldLabel;

/// Idem pour le libellé de fermeture (`'close'`).
String _resolveCloseLabel(BuildContext context) =>
    ZcrudScope.maybeOf(context)?.labels?.maybeResolve('close') ??
    ZcrudLocalizations.maybeOf(context)?.maybeResolve('close') ??
    MaterialLocalizations.of(context).closeButtonTooltip;

/// Emballe un titre déclaratif (`Widget` tel quel, ou `String` → `Text`).
Widget _resolveTitleWidget(Object title) =>
    title is Widget ? title : Text(title as String);

/// Tranche **leading** partagée (fixe + sliver). En mode recherche, un bouton
/// retour (`close`) ; sinon le [leading] fourni (nul ⇒ **absent**, AC1).
Widget? _zBuildLeading(
  BuildContext context,
  _ZSearchController controller,
  Widget? leading,
  ZAppBarSearchConfig? search,
  bool searching,
) {
  if (search != null && searching) {
    return IconButton(
      icon: Icon(Icons.arrow_back, semanticLabel: _resolveCloseLabel(context)),
      tooltip: _resolveCloseLabel(context),
      onPressed: controller.close,
    );
  }
  return leading;
}

/// Tranche **titre** partagée : le champ de recherche (autofocus, `Échap` ⇒
/// fermeture) en mode recherche, sinon le titre déclaratif (AC4).
Widget _zBuildTitle(
  BuildContext context,
  _ZSearchController controller,
  Object title,
  ZAppBarSearchConfig? search,
  bool searching,
) {
  if (search != null && searching) {
    final String hint = search.hintLabel ?? _resolveSearchLabel(context);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): controller.close,
      },
      child: TextField(
        controller: controller.textController,
        focusNode: controller.focusNode,
        autofocus: true,
        textInputAction: TextInputAction.search,
        textAlign: TextAlign.start,
        onChanged: controller.onChanged,
        style: Theme.of(context).textTheme.titleLarge,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
        ),
      ),
    );
  }
  return _resolveTitleWidget(title);
}

/// Tranche **actions** partagée : chaque [ZAppBarAction] non-débordement rend
/// **un** `IconButton` (cible ≥ 48 dp par défaut, `Semantics` via
/// `Icon.semanticLabel`) ; les actions `isOverflow` alimentent un
/// `PopupMenuButton` ; la loupe/close de recherche est ajoutée si [search]
/// est configurée (AC2/AC3/AC4/AC8).
List<Widget> _zBuildActions(
  BuildContext context,
  _ZSearchController controller,
  List<ZAppBarAction> actions,
  ZAppBarSearchConfig? search,
  bool searching,
) {
  final inline = <ZAppBarAction>[];
  final overflow = <ZAppBarAction>[];
  for (final action in actions) {
    (action.isOverflow ? overflow : inline).add(action);
  }
  return <Widget>[
    for (final action in inline)
      IconButton(
        icon: Icon(action.icon, semanticLabel: action.semanticLabel),
        tooltip: action.tooltip,
        onPressed: action.onPressed,
      ),
    if (overflow.isNotEmpty)
      PopupMenuButton<int>(
        icon: const Icon(Icons.more_vert),
        itemBuilder: (context) => <PopupMenuEntry<int>>[
          for (var i = 0; i < overflow.length; i++)
            PopupMenuItem<int>(
              value: i,
              enabled: overflow[i].onPressed != null,
              child: Row(
                children: <Widget>[
                  Icon(overflow[i].icon),
                  const SizedBox(width: 12),
                  Text(overflow[i].semanticLabel),
                ],
              ),
            ),
        ],
        onSelected: (i) => overflow[i].onPressed?.call(),
      ),
    if (search != null)
      IconButton(
        icon: Icon(
          searching ? Icons.close : Icons.search,
          semanticLabel: searching
              ? _resolveCloseLabel(context)
              : _resolveSearchLabel(context),
        ),
        tooltip: searching
            ? _resolveCloseLabel(context)
            : _resolveSearchLabel(context),
        onPressed: controller.toggle,
      ),
  ];
}
