/// `ZSubfolderSelectorBar` — surface de navigation de sous-dossiers par DÉFAUT
/// sur petit écran (CR-IFFD-40, **forme fixée par CR-IFFD-41**).
///
/// ## Le défaut corrigé (CR-IFFD-40, inchangé)
///
/// La rangée de puces défilante (`ZSubfolderCompactSelector`) répondait à
/// « lesquels existent ? » avant « **lequel est actif ?** » : après un seul
/// balayage, la pastille sélectionnée sortait du champ visible et l'utilisateur
/// perdait le « où suis-je ». Rien n'était inaccessible — c'est la perte de
/// l'ÉTAT COURANT qui était le défaut.
///
/// Les trois propriétés qui comptent restent : surface **pleine largeur**, ligne
/// unique ≥ 48 dp ; **élément courant** toujours affiché avec repli explicite
/// sur [ZSubfolderNavSpec.allSubfoldersLabel] (AD-10) ; affordance d'ouverture
/// **visible**.
///
/// ## CR-IFFD-41 — la référence visuelle appartient à l'hôte IFFD
///
/// 🔴 **La feuille modale REMPLACE le déploiement en ligne de v0.34.0.** Ce
/// n'est pas un ajout et ce n'est pas la correction d'un défaut : le
/// propriétaire a tranché que la maquette d'IFFD est la référence du socle
/// partagé. Voir [ZSubfolderNarrowMode.selector] pour la note de migration.
///
/// ### STRUCTURE — codée dans le socle (identique pour tous les hôtes)
///
/// | # | Propriété |
/// |---|---|
/// | 3 | déploiement en **feuille modale**, bornée à 80 % de la hauteur d'écran |
/// | 5 | sous-dossiers **indentés de 24 dp** derrière un **filet vertical** |
/// | 7 | la **racine est un ITEM** de la liste (sélectionnable), pas un en-tête |
/// | 8 | **slot d'action par item** ([ZSubfolderNavSpec.itemActionBuilder]) |
/// | 9 | **pied** d'ajout, câblé sur `addAction`/`addLabel`/`addIcon` existants |
///
/// ### LOOK — tokens `ZcrudTheme` nullables, préréglage côté hôte
///
/// | # | Token | `null` ⇒ |
/// |---|---|---|
/// | 1 | `subfolderTriggerVariant` | `flat` (rendu historique) |
/// | 2 | `subfolderTriggerCollapsedIcon`/`…ExpandedIcon` | `expand_more`/`expand_less` |
/// | 4 | *(libellé)* `spec.sheetTitle` | slot absent |
/// | 6 | `subfolderSelectedEmphasis` | `highlight` (rendu historique) |
///
/// **Sans préréglage, le rendu de ces quatre points est strictement inchangé** :
/// aucune couleur, aucun glyphe, aucun libellé n'est figé ici (FR-26/NFR-S7).
///
/// **AD-2/AD-15** : la SÉLECTION reste détenue par le parent (tranche
/// `ValueListenable` injectée) ; le seul état local est l'ouverture de la
/// feuille (`ValueNotifier<bool>` créé une fois, disposé une fois), scopé par
/// `ValueListenableBuilder` — ouvrir/fermer ne reconstruit ni le corps de la
/// page ni les onglets. **AD-13** : `Semantics(selected:/button:/expanded:)`,
/// cibles ≥ 48 dp, insets et bordures **directionnels**.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZSubfolderSelectedEmphasis,
        ZSubfolderTriggerVariant,
        ZcrudScope,
        ZcrudTheme;

import 'z_subfolder_item_content.dart';
import 'z_subfolder_nav_spec.dart';
import 'z_subfolder_ref.dart';

/// Cible interactive minimale (AD-13).
const double _kMinTapTarget = 48.0;

/// Fraction MAXIMALE de la hauteur d'écran occupée par la feuille (point 3).
const double _kSheetMaxHeightFraction = 0.8;

/// Indentation de hiérarchie des sous-dossiers (point 5) — **dimension de
/// layout**, appliquée en `EdgeInsetsDirectional.only(start:)`.
const double _kHierarchyIndent = 24.0;

/// Glyphes conventionnels de REPLI du chevron (jamais des libellés) — utilisés
/// tant qu'aucun token de thème n'en propose d'autres.
const IconData _kOpenIconFallback = Icons.expand_more;
const IconData _kCloseIconFallback = Icons.expand_less;

/// Glyphe conventionnel « ajouter » de REPLI (jamais un libellé).
const IconData _kAddFallbackIcon = Icons.add;

/// Barre de sélection de sous-dossiers (petit écran, surface par DÉFAUT).
class ZSubfolderSelectorBar extends StatefulWidget {
  /// Construit la barre de sélection.
  const ZSubfolderSelectorBar({
    required this.spec,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  /// Clé stable de la barre (exposée pour les tests).
  static const Key barKey = ValueKey<String>('suf3:selector');

  /// Clé stable de la ligne cliquable montrant l'élément courant.
  static const Key triggerKey = ValueKey<String>('suf3:selector:trigger');

  /// Clé stable du chevron d'ouverture.
  static const Key chevronKey = ValueKey<String>('suf3:selector:chevron');

  /// Clé stable de l'habillage du déclencheur (point 1) — **ABSENT de l'arbre**
  /// tant que `ZcrudTheme.subfolderTriggerVariant` vaut `null`/`flat`.
  static const Key triggerChromeKey = ValueKey<String>(
    'suf3:selector:trigger:chrome',
  );

  /// Clé stable de la **feuille modale** (ABSENTE de l'arbre tant qu'elle n'est
  /// pas ouverte). Portée par la liste des items — conservée depuis CR-IFFD-40.
  static const Key panelKey = ValueKey<String>('suf3:selector:panel');

  /// Clé stable de la racine de la feuille (colonne titre + liste + pied).
  static const Key sheetKey = ValueKey<String>('suf3:selector:sheet');

  /// Clé stable du titre de la feuille (absent si `spec.sheetTitle == null`).
  static const Key sheetTitleKey = ValueKey<String>('suf3:selector:sheet:title');

  /// Clé stable du bouton « Ajouter » de la BARRE (absent si `addAction` nul).
  static const Key addKey = ValueKey<String>('suf3:selector:add');

  /// Clé stable du **pied** « Ajouter » de la feuille (point 9) — absent si
  /// `addAction` nul.
  static const Key footerAddKey = ValueKey<String>('suf3:selector:sheet:add');

  /// Clé stable d'un item de la feuille ([id] vide = item racine « tous »).
  static Key itemKey(String id) => ValueKey<String>('suf3:selector:item:$id');

  /// Clé stable du **filet d'indentation** d'un item non-racine (point 5).
  static Key indentKey(String id) =>
      ValueKey<String>('suf3:selector:indent:$id');

  /// Clé stable du slot d'action d'un item (point 8) — absent si
  /// `spec.itemActionBuilder` nul ou s'il rend `null` pour cet item.
  static Key itemActionKey(String id) =>
      ValueKey<String>('suf3:selector:action:$id');

  /// Descripteur de navigation (données + libellés, tout injecté).
  final ZSubfolderNavSpec spec;

  /// Tranche réactive de sélection (`null` = item racine).
  final ValueListenable<String?> selected;

  /// Émis quand un item est choisi (`null` pour la racine).
  final ValueChanged<String?> onSelect;

  @override
  State<ZSubfolderSelectorBar> createState() => _ZSubfolderSelectorBarState();
}

class _ZSubfolderSelectorBarState extends State<ZSubfolderSelectorBar> {
  /// Feuille ouverte — SEUL état local (AD-2 : la sélection reste au parent).
  final ValueNotifier<bool> _open = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  /// Item courant, ou `null` pour la racine.
  ///
  /// **AD-10** : un id qui ne correspond à AUCUN sous-dossier (liste rafraîchie,
  /// dossier supprimé) retombe sur la racine — la barre affiche alors le repli
  /// [ZSubfolderNavSpec.allSubfoldersLabel], jamais un vide.
  ZSubfolderRef? _currentRef(String? id) {
    if (id == null) return null;
    for (final ZSubfolderRef ref in widget.spec.subfolders) {
      if (ref.id == id) return ref;
    }
    return null;
  }

  Widget _itemContent(
    BuildContext context,
    ZSubfolderRef? refOrNull,
    bool selected,
  ) => zBuildSubfolderItemContent(
    context,
    spec: widget.spec,
    refOrNull: refOrNull,
    label: refOrNull?.label ?? widget.spec.allSubfoldersLabel,
    selected: selected,
  );

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    // Scope de mode posé AU-DESSUS de tout le sous-arbre d'items : un
    // `itemBuilder` injecté observe `compact` ici comme dans la rangée de puces
    // — un builder existant rend donc à l'identique (CR-IFFD-31/CR-IFFD-40).
    return ZSubfolderLayoutScope(
      mode: ZSubfolderLayoutMode.compact,
      child: Column(
        key: ZSubfolderSelectorBar.barKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[_bar(context, theme)],
      ),
    );
  }

  // --- Ligne unique : élément courant + chevron (+ « Ajouter ») -------------

  Widget _bar(BuildContext context, ZcrudTheme theme) {
    return Row(
      children: <Widget>[
        Expanded(child: _trigger(context, theme)),
        // Slot d'ajout — MÊME capacité que la rangée de puces et que la sidebar
        // (AD-4 : `addAction` null ⇒ bouton ABSENT de l'arbre).
        if (widget.spec.addAction != null) _addButton(context, theme),
      ],
    );
  }

  Widget _trigger(BuildContext context, ZcrudTheme theme) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.selected,
      builder: (context, currentId, _) {
        final ZSubfolderRef? ref = _currentRef(currentId);
        final String label = ref?.label ?? widget.spec.allSubfoldersLabel;
        return ValueListenableBuilder<bool>(
          valueListenable: _open,
          builder: (context, open, _) {
            return Semantics(
              container: true,
              button: true,
              expanded: open,
              // Annonce de l'ÉLÉMENT COURANT — c'est la réponse à « où
              // suis-je ». `excludeSemantics` garantit UNE seule annonce, même
              // quand le contenu vient d'un `itemBuilder` injecté.
              label: label,
              excludeSemantics: true,
              onTap: _openSheet,
              child: _triggerChrome(
                context,
                theme,
                InkWell(
                  key: ZSubfolderSelectorBar.triggerKey,
                  onTap: _openSheet,
                  excludeFromSemantics: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: _kMinTapTarget,
                      minWidth: _kMinTapTarget,
                    ),
                    child: Padding(
                      padding: EdgeInsetsDirectional.symmetric(
                        horizontal: theme.gapM,
                        vertical: theme.gapS,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: _itemContent(context, ref, true),
                            ),
                          ),
                          SizedBox(width: theme.gapS),
                          // Affordance VISIBLE d'ouverture (jamais déduite du
                          // défilement), ancrée côté END (RTL-safe : c'est la
                          // `Row` directionnelle qui la place, aucun `left`/
                          // `right`).
                          Icon(
                            open
                                ? (theme.subfolderTriggerExpandedIcon ??
                                      _kCloseIconFallback)
                                : (theme.subfolderTriggerCollapsedIcon ??
                                      _kOpenIconFallback),
                            key: ZSubfolderSelectorBar.chevronKey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Point 1 — habillage du déclencheur, piloté par un token NULLABLE.
  ///
  /// `null` / [ZSubfolderTriggerVariant.flat] ⇒ [child] rendu **tel quel**,
  /// aucun élément supplémentaire dans l'arbre : c'est la neutralité littérale
  /// (pas seulement « même apparence », mais même arbre).
  Widget _triggerChrome(BuildContext context, ZcrudTheme theme, Widget child) {
    final ZSubfolderTriggerVariant variant =
        theme.subfolderTriggerVariant ?? ZSubfolderTriggerVariant.flat;
    if (variant == ZSubfolderTriggerVariant.flat) return child;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: ZSubfolderSelectorBar.triggerChromeKey,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(theme.radiusM),
        // Aucune couleur littérale : deux RÔLES du `ColorScheme` courant.
        color: variant == ZSubfolderTriggerVariant.filled
            ? scheme.surfaceContainerHighest
            : null,
        border: variant == ZSubfolderTriggerVariant.outlined
            ? Border.fromBorderSide(
                BorderSide(color: scheme.outlineVariant),
              )
            : null,
      ),
      child: child,
    );
  }

  Widget _addButton(BuildContext context, ZcrudTheme theme) {
    final String label = widget.spec.addLabel ?? widget.spec.allSubfoldersLabel;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _kMinTapTarget,
        minHeight: _kMinTapTarget,
      ),
      child: IconButton(
        key: ZSubfolderSelectorBar.addKey,
        onPressed: widget.spec.addAction,
        tooltip: label,
        icon: Icon(
          widget.spec.addIcon ?? _kAddFallbackIcon,
          semanticLabel: label,
        ),
      ),
    );
  }

  // --- Feuille modale (point 3) ---------------------------------------------

  /// Ouvre la fratrie en **feuille modale**.
  ///
  /// **AD-10** : sans `Navigator` dans l'arbre, aucune exception n'est levée —
  /// l'échec est signalé à `FlutterError.reportError` (console + rapports de
  /// crash de l'hôte) et la barre reste inerte plutôt que d'emporter la page.
  Future<void> _openSheet() async {
    final NavigatorState? navigator = Navigator.maybeOf(context);
    if (navigator == null) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError(
            'ZSubfolderSelectorBar : aucun Navigator au-dessus de la barre — '
            'la fratrie ne peut pas se déployer en feuille modale.',
          ),
          library: 'zcrud_study',
          context: ErrorDescription(
            'lors de l\'ouverture de la feuille de sous-dossiers',
          ),
        ),
      );
      return;
    }
    // 🔴 La feuille est rendue dans l'`Overlay` : elle SORT du sous-arbre de la
    // barre. Deux héritages doivent donc être re-posés explicitement, sans quoi
    // le préréglage de l'hôte disparaîtrait précisément là où il doit se voir :
    // * la `Directionality` (un `Directionality` local n'est pas un
    //   `InheritedTheme`, donc pas capturé par `showModalBottomSheet`) ;
    // * le `ZcrudScope`, qui porte les tokens `ZcrudTheme` ET le résolveur de
    //   `colorKey` des pastilles d'accent.
    final TextDirection direction = Directionality.of(context);
    final ZcrudScope? scope = ZcrudScope.maybeOf(context);
    final double maxHeight =
        MediaQuery.sizeOf(context).height * _kSheetMaxHeightFraction;

    _open.value = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (BuildContext sheetContext) => Directionality(
        textDirection: direction,
        child: _rePoseScope(scope, _sheet(sheetContext)),
      ),
    );
    if (mounted) _open.value = false;
  }

  /// Re-pose le [ZcrudScope] ambiant sous l'`Overlay`.
  ///
  /// ⚠️ Recopie **champ par champ** : `ZcrudScope` est un `InheritedWidget` nu
  /// (pas un `InheritedTheme`), il n'est donc pas capturé par
  /// `showModalBottomSheet`, et il n'expose pas de `copyWith`. Un champ ajouté à
  /// `ZcrudScope` et oublié ici serait perdu dans la feuille : c'est
  /// exactement ce que garde `cr_iffd41_subfolder_sheet_test.dart`
  /// (« tout paramètre de ZcrudScope est propagé »), qui lit la liste réelle
  /// des paramètres dans la source de `zcrud_core`.
  Widget _rePoseScope(ZcrudScope? scope, Widget child) {
    if (scope == null) return child;
    return ZcrudScope(
      resolver: scope.resolver,
      acl: scope.acl,
      labels: scope.labels,
      theme: scope.theme,
      widgetRegistry: scope.widgetRegistry,
      relationSourceRegistry: scope.relationSourceRegistry,
      choicesSourceRegistry: scope.choicesSourceRegistry,
      relationCrudRegistry: scope.relationCrudRegistry,
      filePicker: scope.filePicker,
      cloudStorage: scope.cloudStorage,
      listRenderer: scope.listRenderer,
      reorderRenderer: scope.reorderRenderer,
      dropRegionRenderer: scope.dropRegionRenderer,
      selectPresenter: scope.selectPresenter,
      iconResolver: scope.iconResolver,
      colorPicker: scope.colorPicker,
      colorKeyResolver: scope.colorKeyResolver,
      gradientResolver: scope.gradientResolver,
      child: child,
    );
  }

  /// Contenu de la feuille : titre (point 4) + racine en ITEM (point 7) + la
  /// fratrie indentée (point 5) + pied d'ajout (point 9).
  Widget _sheet(BuildContext sheetContext) {
    // Le scope de mode est re-posé DANS la feuille : hors du sous-arbre de la
    // barre, il ne serait pas hérité — un `itemBuilder` injecté y lirait
    // `null` au lieu de `compact` et pourrait rendre différemment.
    return ZSubfolderLayoutScope(
      mode: ZSubfolderLayoutMode.compact,
      child: Builder(
        builder: (BuildContext context) {
          final ZcrudTheme theme = ZcrudTheme.of(context);
          final List<ZSubfolderRef> subfolders = widget.spec.subfolders;
          final String? title = widget.spec.sheetTitle;
          return SafeArea(
            child: Padding(
              padding: EdgeInsetsDirectional.all(theme.gapM),
              child: Column(
                key: ZSubfolderSelectorBar.sheetKey,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Point 4 — titre INJECTÉ ; `null` ⇒ absent de l'arbre (AD-4).
                  if (title != null)
                    Padding(
                      padding: EdgeInsetsDirectional.all(theme.gapM),
                      child: Text(
                        title,
                        key: ZSubfolderSelectorBar.sheetTitleKey,
                        textAlign: TextAlign.start,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  // Point 7 — la RACINE est un ITEM (sélectionnable), rendue
                  // hors de la liste défilante pour rester visible, mais avec
                  // EXACTEMENT le même chrome et la même voie de sélection ;
                  // seule l'indentation lui est retirée (elle est le parent).
                  _item(context, theme, null),
                  Flexible(
                    child: ListView.builder(
                      key: ZSubfolderSelectorBar.panelKey,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: subfolders.length,
                      itemBuilder: (context, index) =>
                          _item(context, theme, subfolders[index]),
                    ),
                  ),
                  // Point 9 — pied d'ajout CÂBLÉ sur les slots existants
                  // (`addAction`/`addLabel`/`addIcon`) : aucun nouveau champ.
                  if (widget.spec.addAction != null) _footerAdd(context, theme),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Un item de la feuille. [refOrNull] `null` ⇒ item racine (non indenté).
  Widget _item(BuildContext context, ZcrudTheme theme, ZSubfolderRef? ref) {
    final String? id = ref?.id;
    final String label = ref?.label ?? widget.spec.allSubfoldersLabel;
    final Widget row = ValueListenableBuilder<String?>(
      valueListenable: widget.selected,
      builder: (context, current, _) {
        final bool isSelected = current == id;
        // Point 8 — slot d'action ; `null` (builder absent OU décision de
        // l'hôte pour cet item) ⇒ AUCUN élément dans l'arbre (AD-4).
        final Widget? action = widget.spec.itemActionBuilder?.call(
          context,
          ref,
          isSelected,
        );
        // 🔴 L'ACTION est posée HORS du conteneur sémantique de l'item, et
        // c'est mesuré. Le premier jet gardait la structure de la barre (un
        // `Semantics` englobant tout, `excludeSemantics` levé pour laisser
        // passer l'action) : le lecteur d'écran annonçait alors
        // « Sous-dossier 0 / Sous-dossier 0 / 0 » — le libellé du conteneur
        // FUSIONNÉ avec le contenu qu'il était censé remplacer. Séparer les
        // deux sujets donne UNE annonce pour l'item et UNE pour l'action.
        return Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                container: true,
                button: true,
                selected: isSelected,
                label: label,
                excludeSemantics: true,
                onTap: () => _select(context, id),
                child: InkWell(
                  key: ZSubfolderSelectorBar.itemKey(id ?? ''),
                  onTap: () => _select(context, id),
                  excludeFromSemantics: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: _kMinTapTarget,
                    ),
                    child: _emphasis(
                      context,
                      theme,
                      selected: isSelected,
                      // 🔴 `WidgetBuilder` et non `Widget` : le contenu doit
                      // être CONSTRUIT SOUS les enveloppes d'inversion, sinon
                      // un `itemBuilder` d'hôte qui lit `IconTheme.of(context)`
                      // ou `DefaultTextStyle.of(context)` pour se colorer
                      // lui-même y trouverait la couleur AMBIANTE — donc
                      // illisible sur le fond opaque. Le rendu des `Icon`/`Text`
                      // nus serait pourtant correct : le défaut ne se verrait
                      // que chez l'hôte qui fait bien son travail.
                      builder: (BuildContext inner) => Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _itemContent(inner, ref, isSelected),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (action != null)
              ConstrainedBox(
                key: ZSubfolderSelectorBar.itemActionKey(id ?? ''),
                constraints: const BoxConstraints(
                  minWidth: _kMinTapTarget,
                  minHeight: _kMinTapTarget,
                ),
                child: Center(child: action),
              ),
          ],
        );
      },
    );
    if (ref == null) return row;
    // Point 5 — indentation de hiérarchie + filet vertical, DIRECTIONNELS :
    // `EdgeInsetsDirectional.only(start:)` et `BorderDirectional(start:)`
    // basculent tous deux en RTL. La couleur du filet est DÉRIVÉE
    // (`ThemeData.dividerColor`), jamais littérale.
    return Container(
      key: ZSubfolderSelectorBar.indentKey(ref.id),
      margin: const EdgeInsetsDirectional.only(start: _kHierarchyIndent),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: row,
    );
  }

  /// Point 6 — mise en évidence de l'élément courant.
  ///
  /// 🔴 [ZSubfolderSelectedEmphasis.inverted] **retourne le couple** : fond
  /// `inverseSurface` ET premier plan forcé à `onInverseSurface` via
  /// `IconTheme` + `DefaultTextStyle`, de sorte qu'un `itemBuilder` injecté
  /// s'inverse lui aussi. Un simple fond opaque laisserait le texte de l'hôte
  /// illisible — c'est le contraste RÉEL qui est la capacité, pas la décoration.
  ///
  /// `null`/`highlight` ⇒ chemin d'origine, **sans** enveloppes de premier plan.
  Widget _emphasis(
    BuildContext context,
    ZcrudTheme theme, {
    required bool selected,
    required WidgetBuilder builder,
  }) {
    final EdgeInsetsDirectional padding = EdgeInsetsDirectional.symmetric(
      horizontal: theme.gapM,
      vertical: theme.gapS,
    );
    if (!selected) {
      return Padding(padding: padding, child: Builder(builder: builder));
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ZSubfolderSelectedEmphasis emphasis =
        theme.subfolderSelectedEmphasis ?? ZSubfolderSelectedEmphasis.highlight;
    if (emphasis == ZSubfolderSelectedEmphasis.highlight) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.all(theme.radiusM),
        ),
        child: Builder(builder: builder),
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.all(theme.radiusM),
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: scheme.onInverseSurface),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.onInverseSurface),
          child: Builder(builder: builder),
        ),
      ),
    );
  }

  /// Point 9 — pied « Ajouter un sous-dossier ».
  ///
  /// Le libellé est **AFFICHÉ** (et non plus seulement annoncé) quand
  /// [ZSubfolderNavSpec.addLabel] est fourni ; sans libellé, le pied reste un
  /// bouton à glyphe annoncé — jamais un contrôle muet, jamais une chaîne en
  /// dur.
  Widget _footerAdd(BuildContext context, ZcrudTheme theme) {
    final String? label = widget.spec.addLabel;
    final Icon icon = Icon(widget.spec.addIcon ?? _kAddFallbackIcon);
    return Padding(
      padding: EdgeInsetsDirectional.all(theme.gapM),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinTapTarget),
        child: label == null
            ? OutlinedButton(
                key: ZSubfolderSelectorBar.footerAddKey,
                onPressed: () => _runAdd(context),
                child: Semantics(
                  label: widget.spec.allSubfoldersLabel,
                  child: icon,
                ),
              )
            : OutlinedButton.icon(
                key: ZSubfolderSelectorBar.footerAddKey,
                onPressed: () => _runAdd(context),
                icon: icon,
                label: Text(label, textAlign: TextAlign.start),
              ),
      ),
    );
  }

  /// Déclenche l'ajout puis REFERME la feuille : l'hôte ouvre typiquement sa
  /// propre surface d'édition, qui ne doit pas s'empiler derrière celle-ci.
  void _runAdd(BuildContext sheetContext) {
    Navigator.of(sheetContext).maybePop();
    widget.spec.addAction?.call();
  }

  /// Choisit [id] et REFERME la feuille : la barre revient à sa ligne unique
  /// montrant le nouvel élément courant.
  void _select(BuildContext sheetContext, String? id) {
    Navigator.of(sheetContext).maybePop();
    widget.onSelect(id);
  }
}
