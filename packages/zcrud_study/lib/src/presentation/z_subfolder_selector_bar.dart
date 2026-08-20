/// `ZSubfolderSelectorBar` — surface de navigation de sous-dossiers par DÉFAUT
/// sur petit écran.
///
/// ## Le défaut évité
///
/// Une rangée de puces défilante (`ZSubfolderCompactSelector`) répond à
/// « lesquels existent ? » avant « **lequel est actif ?** » : après un seul
/// balayage, la pastille sélectionnée sortirait du champ visible et
/// l'utilisateur perdrait le « où suis-je ». Rien ne serait inaccessible —
/// c'est la perte de l'ÉTAT COURANT qui serait le défaut.
///
/// Les trois propriétés qui comptent restent : surface **pleine largeur**, ligne
/// unique ≥ 48 dp ; **élément courant** toujours affiché avec repli explicite
/// sur [ZSubfolderNavSpec.allSubfoldersLabel] (invariant AD-10) ; affordance
/// d'ouverture **visible**.
///
/// ## La référence visuelle du socle
///
/// **La feuille modale REMPLACE un déploiement en ligne.** Ce n'est pas un
/// ajout et ce n'est pas la correction d'un défaut : c'est un choix de design
/// tranché par le propriétaire du produit, retenu comme référence du socle
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
/// aucune couleur, aucun glyphe, aucun libellé n'est figé ici (invariant FR-26).
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
import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZInvertedSurface,
        ZSubfolderSelectedEmphasis,
        ZSubfolderTriggerBorder,
        ZSubfolderTriggerFill,
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
  /// pas ouverte). Portée par la liste des items.
  static const Key panelKey = ValueKey<String>('suf3:selector:panel');

  /// Clé stable de la racine de la feuille (colonne titre + liste + pied).
  static const Key sheetKey = ValueKey<String>('suf3:selector:sheet');

  /// Clé stable du titre de la feuille (absent si `spec.sheetTitle == null`).
  static const Key sheetTitleKey = ValueKey<String>('suf3:selector:sheet:title');

  /// Clé stable du bouton « Ajouter » de la BARRE (absent si `addAction` nul).
  static const Key addKey = ValueKey<String>('suf3:selector:add');

  /// Clé stable du **pied** « Ajouter » de la feuille (point 9) — absent si
  /// `addAction` nul **ou** sous [ZSubfolderAddPlacement.barOnly].
  static const Key footerAddKey = ValueKey<String>('suf3:selector:sheet:add');

  /// Clé stable de l'enveloppe de **marge extérieure** — **ABSENTE de
  /// l'arbre** tant que `ZcrudTheme.subfolderBarPadding` est `null`.
  static const Key barPaddingKey = ValueKey<String>('suf3:selector:padding');

  /// Clé stable de l'enveloppe de **marge extérieure de la FEUILLE**
  /// (point 4) — **ABSENTE de l'arbre** tant que
  /// `ZcrudTheme.subfolderSheetPadding` est `null`.
  static const Key sheetPaddingKey = ValueKey<String>(
    'suf3:selector:sheet:padding',
  );

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

  /// Contenu du DÉCLENCHEUR — il annonce le **filtre actif**.
  ///
  /// Repli sur [ZSubfolderNavSpec.allSubfoldersLabel], **jamais** sur
  /// `rootItemLabel` : « aucun filtre » se dit « tous les sous-dossiers », alors
  /// que la ligne racine de la feuille désigne le CONTENEUR (point 1). Aucun
  /// `rootIcon` non plus, pour la même raison.
  Widget _triggerContent(
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

  /// Contenu d'un ITEM de la feuille — la ligne racine y désigne le conteneur.
  Widget _sheetItemContent(
    BuildContext context,
    ZSubfolderRef? refOrNull,
    bool selected,
  ) => zBuildSubfolderItemContent(
    context,
    spec: widget.spec,
    refOrNull: refOrNull,
    label: refOrNull?.label ?? zSubfolderRootItemLabel(widget.spec),
    selected: selected,
    rootIcon: widget.spec.rootItemIcon,
  );

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    // Scope de mode posé AU-DESSUS de tout le sous-arbre d'items : un
    // `itemBuilder` injecté observe `compact` ici comme dans la rangée de puces
    // — un builder existant rend donc à l'identique.
    return ZSubfolderLayoutScope(
      mode: ZSubfolderLayoutMode.compact,
      // Point 1 — second axe : la surface CONCRÈTE. Le déclencheur
      // et la feuille posent le même `mode` (leurs contraintes de layout sont
      // les mêmes) mais des `surface` DIFFÉRENTES : c'est ce qui rend les deux
      // surfaces enfin discernables pour un `itemBuilder` injecté.
      surface: ZSubfolderSurface.selectorTrigger,
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
    final EdgeInsetsGeometry? padding = theme.subfolderBarPadding;
    // Le sujet de la garde est le DÉCLENCHEUR, pas la barre. Mesuré : sous
    // une marge horizontale, la `Row` garde la largeur qu'on lui donne et le
    // bouton `+` garde ses 48 dp intrinsèques — c'est l'`Expanded` du
    // déclencheur qui absorbe TOUT le retrait. Garder la barre aurait produit
    // une garde verte pendant que la cible réelle s'écrase.
    final Widget trigger = padding == null
        ? _trigger(context, theme)
        : _ZTapTargetGuard(
            minSize: _kMinTapTarget,
            subject: 'déclencheur',
            token: 'ZcrudTheme.subfolderBarPadding',
            cause:
                'La marge extérieure `ZcrudTheme.subfolderBarPadding` retire '
                'de la largeur au déclencheur, qui est le seul élément '
                'élastique de la barre : au-delà d\'un certain retrait, il '
                'passe sous le plancher de cible tactile.',
            remedy:
                'Mesuré : à 320 dp de large, la rupture n\'apparaît qu\'au-delà '
                'de 112 dp de marge PAR CÔTÉ.',
            child: _trigger(context, theme),
          );
    final Row row = Row(
      children: <Widget>[
        Expanded(child: trigger),
        // Slot d'ajout — MÊME capacité que la rangée de puces et que la sidebar
        // (invariant AD-4 : `addAction` null ⇒ bouton ABSENT de l'arbre).
        // Son EMPLACEMENT est adressable : sous `sheetOnly`, l'action reste
        // offerte (pied de la feuille) mais le `+` quitte l'arbre.
        if (widget.spec.addAction != null && widget.spec.addPlacement.inBar)
          _addButton(context, theme),
      ],
    );
    // Marge EXTÉRIEURE adressable. `null` ⇒ AUCUNE enveloppe dans l'arbre :
    // la neutralité est littérale (même arbre, pas seulement « même
    // apparence »), comme pour `_triggerChrome`.
    if (padding == null) return row;
    return Padding(
      key: ZSubfolderSelectorBar.barPaddingKey,
      // `EdgeInsetsGeometry` : un `EdgeInsetsDirectional` est résolu par la
      // `Directionality` ambiante et bascule donc en RTL (AD-13).
      padding: padding,
      child: row,
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
                              child: _triggerContent(context, ref, true),
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

  /// Point 1 — habillage du déclencheur, piloté par un token NULLABLE ;
  /// trois attributs COMPOSABLES (fond, bordure, élévation).
  ///
  /// ## Précédence (contrat gardé par test)
  ///
  /// `subfolderTriggerVariant` reste l'API publiée et décide par défaut ;
  /// les jetons `subfolderTriggerFill` / `subfolderTriggerBorder` /
  /// `subfolderTriggerElevation` la **raffinent attribut par attribut** :
  /// fourni, un jeton PRIME sur ce que la variante décide pour SON attribut —
  /// et seulement pour lui ; `null`, la variante décide. Les trois attributs
  /// effectifs se COMPOSENT (fond + bordure + relief ensemble, sans
  /// exclusivité entre eux).
  ///
  /// `flat` + aucun jeton effectif ⇒ [child] rendu **tel quel**, aucun élément
  /// supplémentaire dans l'arbre : neutralité littérale (même arbre, pas
  /// seulement même apparence). Même chose quand tous les attributs effectifs
  /// sont retirés explicitement (`fill: none` sur une variante `filled`,
  /// etc.) : rien à peindre ⇒ rien dans l'arbre.
  ///
  /// ## Élévation : TONALE M3, jamais d'ombre portée (MESURÉ)
  ///
  /// Le déclencheur vit dans le `bottom:` de l'app-bar (`aboveTabBar`),
  /// **bord à bord** au-dessus du `TabBar` (écart mesuré : 0 dp) et la zone
  /// n'est PAS rognée : une `BoxShadow` descendante (blur 8, offset (0, 4))
  /// repeint réellement la bande du `TabBar` (mesuré au pixel : 796 pixels
  /// modifiés sur 3 lignes échantillonnées, delta max 254/255 — mesuré par
  /// garde dédiée). L'élévation est donc rendue en
  /// **voile tonal** ([ElevationOverlay.applySurfaceTint] —
  /// `ColorScheme.surfaceTint` gradué par l'élévation), calculé ICI et passé en
  /// fond : `Material.elevation` reste à 0 **par construction**, aucune ombre
  /// portée n'existe, quel que soit `useMaterial3` de l'hôte. Les jetons
  /// `cardShadow*` (epic VIS) ne sont pas réutilisés : aucune ombre n'est
  /// retenue nulle part sur cette surface.
  ///
  /// ## Ordre Material/Décoration : l'encre reste VISIBLE (piège B-53)
  ///
  /// Le chrome est un [Material] (plus un `DecoratedBox`) : l'`InkWell` du
  /// déclencheur y trouve son ancêtre `Material` LE PLUS PROCHE, et l'encre se
  /// dessine AU-DESSUS du fond — un fond opaque posé en `DecoratedBox`
  /// au-dessus du `Material` ambiant l'aurait avalée (piège M3 payé en B-53
  /// chez IFFD). Gardé par test : le `Material` du chrome est bien l'ancêtre
  /// d'encre de l'`InkWell`, et le splash y est réellement peint.
  Widget _triggerChrome(BuildContext context, ZcrudTheme theme, Widget child) {
    final ZSubfolderTriggerVariant variant =
        theme.subfolderTriggerVariant ?? ZSubfolderTriggerVariant.flat;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // Attribut par attribut : jeton fourni ⇒ il prime ; absent ⇒ la variante
    // décide. Aucune couleur littérale : uniquement des RÔLES du `ColorScheme`.
    final Color? fill = switch (theme.subfolderTriggerFill) {
      null => variant == ZSubfolderTriggerVariant.filled
          ? scheme.surfaceContainerHighest
          : null,
      ZSubfolderTriggerFill.none => null,
      ZSubfolderTriggerFill.surface => scheme.surface,
      ZSubfolderTriggerFill.surfaceContainerLowest =>
        scheme.surfaceContainerLowest,
      ZSubfolderTriggerFill.surfaceContainerLow => scheme.surfaceContainerLow,
      ZSubfolderTriggerFill.surfaceContainer => scheme.surfaceContainer,
      ZSubfolderTriggerFill.surfaceContainerHigh =>
        scheme.surfaceContainerHigh,
      ZSubfolderTriggerFill.surfaceContainerHighest =>
        scheme.surfaceContainerHighest,
    };
    final BorderSide? side = switch (theme.subfolderTriggerBorder) {
      null => variant == ZSubfolderTriggerVariant.outlined
          ? BorderSide(color: scheme.outlineVariant)
          : null,
      ZSubfolderTriggerBorder.none => null,
      ZSubfolderTriggerBorder.outlineVariant =>
        BorderSide(color: scheme.outlineVariant),
      ZSubfolderTriggerBorder.outline => BorderSide(color: scheme.outline),
    };
    // Aucune variante n'a d'élévation : `null` ⇒ 0 (rendu inchangé).
    final double elevation = theme.subfolderTriggerElevation ?? 0;
    // Rien à peindre ⇒ RIEN dans l'arbre (neutralité littérale, AD-4).
    if (fill == null && side == null && elevation <= 0) return child;
    // Voile TONAL calculé ici (jamais d'ombre portée — cf. dartdoc). Sans
    // fond, le voile se pose sur un fond DÉRIVÉ rendu invisible (alpha 0) :
    // la garde couleur interdit tout littéral, et `MaterialType.transparency`
    // ne peindrait pas la bordure.
    final Color base = fill ?? scheme.surface.withAlpha(0);
    final Color painted = elevation > 0
        ? ElevationOverlay.applySurfaceTint(base, scheme.surfaceTint, elevation)
        : base;
    return Material(
      key: ZSubfolderSelectorBar.triggerChromeKey,
      color: painted,
      // 0 par CONSTRUCTION : le relief est déjà dans `painted` (tonal).
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(theme.radiusM),
        side: side ?? BorderSide.none,
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
    // La feuille est rendue dans l'`Overlay` : elle SORT du sous-arbre de la
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
  /// Recopie **champ par champ** : `ZcrudScope` est un `InheritedWidget` nu
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
      // v0.64.0 : le port de RÉSOLUTION des références de fichiers. Sans cette
      // re-pose, un champ fichier monté dans la feuille afficherait ses valeurs
      // persistées comme VIDES — le défaut même que ce port ferme. Ajouté sur
      // signalement de la garde de structure de `cr_iffd41_subfolder_sheet_test`,
      // qui lit la liste RÉELLE des paramètres dans la source de `zcrud_core`.
      appFileResolver: scope.appFileResolver,
      // v0.66.0 : port de rendu riche (sous-titres d'étape en Markdown). Même
      // motif que `appFileResolver` ci-dessus — signalé par la MÊME garde de
      // structure, qui a donc mordu deux fois de suite sur deux ports
      // différents. Elle lit la liste réelle des paramètres dans la source de
      // `zcrud_core` : tout port ajouté sans être re-posé ici la fait rougir.
      richTextRenderer: scope.richTextRenderer,
      // v0.69.0 : port de formatage des dates. TROISIÈME port signalé par cette
      // même garde en trois jours (`appFileResolver`, `richTextRenderer`, puis
      // celui-ci). Le motif est clair : tout port ajouté à `ZcrudScope` doit
      // être re-posé ici, et c'est la garde — pas la vigilance — qui le tient.
      dateDisplayFormatter: scope.dateDisplayFormatter,
      // v1.8.0 puis v2.1.0 : les deux canaux de seams déclaratifs — celui des
      // SOUS-LISTES, puis celui du RENDU DE CHOIX. QUATRIÈME et CINQUIÈME ports
      // signalés par cette même garde. Le motif ne varie pas : un canal ajouté
      // au scope et non re-posé ici disparaîtrait sous l'Overlay, et l'hôte
      // verrait son rendu déclaré s'évanouir dans la feuille — sans rien qui
      // l'annonce. C'est la garde, jamais la vigilance, qui tient cette liste.
      subListSeamRegistry: scope.subListSeamRegistry,
      selectChoiceBuilderRegistry: scope.selectChoiceBuilderRegistry,
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
      surface: ZSubfolderSurface.selectorSheet,
      child: Builder(
        builder: (BuildContext context) {
          final ZcrudTheme theme = ZcrudTheme.of(context);
          final List<ZSubfolderRef> subfolders = widget.spec.subfolders;
          final String? title = widget.spec.sheetTitle;
          return SafeArea(
            // Point 4 — marge EXTÉRIEURE adressable, pendant exact de
            // `subfolderBarPadding` : `null` ⇒ AUCUNE enveloppe dans l'arbre
            // (neutralité littérale, pas seulement « même apparence »).
            // Posée SOUS la `SafeArea` et AU-DESSUS de la gouttière interne :
            // elle s'AJOUTE à `gapM` au lieu de la remplacer — cf. le dartdoc
            // du token. Elle est aussi sous le `constraints` de
            // `showModalBottomSheet` : le plafond de 80 % de hauteur d'écran
            // reste posé sur la feuille elle-même, cette marge ne peut donc
            // pas le déborder — elle réduit la hauteur du CONTENU, que la
            // liste `Flexible` absorbe.
            child: _sheetPadding(
              theme,
              Padding(
                // La gouttière de la feuille est adressable, séparément de
                // `gapM` que l'hôte règle déjà pour le padding de ses cartes
                // (12) alors que sa feuille en demande 8 : aucune valeur de
                // `gapM` ne pouvait satisfaire les deux. `null` ⇒ `gapM`, le
                // rendu strictement historique.
                padding: _sheetGutter(theme),
                child: Column(
                key: ZSubfolderSelectorBar.sheetKey,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Point 4 — titre INJECTÉ ; `null` ⇒ absent de l'arbre (AD-4).
                  if (title != null)
                    Padding(
                      // Même jeton que la gouttière : le titre fait partie
                      // de la STRUCTURE de la feuille.
                      padding: _sheetGutter(theme),
                      child: Text(
                        title,
                        key: ZSubfolderSelectorBar.sheetTitleKey,
                        // Point 2 — alignement ADRESSABLE.
                        // `null` ⇒ `start`, rendu strictement inchangé.
                        // La `Column` est en `crossAxisAlignment: stretch` : le
                        // `Text` reçoit donc TOUTE la largeur, et l'alignement
                        // est réellement observable (sur une boîte ajustée au
                        // texte, il n'aurait rien fait — c'est ce que la garde
                        // vérifie par une mesure de position, pas de propriété).
                        textAlign:
                            theme.subfolderSheetTitleAlign ?? TextAlign.start,
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
                  // Son emplacement est adressable : sous `barOnly`, le pied
                  // quitte l'arbre et le `+` de la barre reste la seule
                  // affordance.
                  if (widget.spec.addAction != null &&
                      widget.spec.addPlacement.inSheet)
                    _footerAdd(context, theme),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Point 4 — enveloppe de marge extérieure de la FEUILLE.
  ///
  /// `null` ⇒ [child] rendu tel quel : aucun élément supplémentaire dans
  /// l'arbre (invariant AD-4), exactement comme `_triggerChrome` et
  /// l'enveloppe de la barre.
  Widget _sheetPadding(ZcrudTheme theme, Widget child) {
    final EdgeInsetsGeometry? padding = theme.subfolderSheetPadding;
    if (padding == null) return child;
    return Padding(
      key: ZSubfolderSelectorBar.sheetPaddingKey,
      // `EdgeInsetsGeometry` : un `EdgeInsetsDirectional` est résolu par la
      // `Directionality` re-posée dans la feuille et bascule en RTL (AD-13).
      padding: padding,
      child: child,
    );
  }

  /// Padding STRUCTUREL interne de la feuille : gouttière, titre, pied
  /// « ajouter ».
  ///
  /// `null` ⇒ `EdgeInsetsDirectional.all(gapM)` — **rendu strictement
  /// inchangé**. Motif identique à `contentPadding` de la carte et à
  /// `leadingGap` : un jeton générique porterait plusieurs valeurs de
  /// référence incompatibles, ce slot lui en retire une.
  ///
  /// NE couvre PAS le padding des ITEMS de la feuille (`_emphasis`), qui
  /// reste `gapM`/`gapS` : c'est un rôle d'ITEM, pas de structure de feuille.
  EdgeInsetsGeometry _sheetGutter(ZcrudTheme theme) =>
      theme.subfolderSheetContentPadding ??
      EdgeInsetsDirectional.all(theme.gapM);

  /// Dénonciation de cible tactile pour les ITEMS de la feuille — posée
  /// UNIQUEMENT sous `subfolderSheetPadding`, comme son pendant de la barre.
  Widget _sheetTapGuard(ZcrudTheme theme, Widget child) {
    if (theme.subfolderSheetPadding == null) return child;
    return _ZTapTargetGuard(
      minSize: _kMinTapTarget,
      subject: 'item de la feuille',
      token: 'ZcrudTheme.subfolderSheetPadding',
      cause:
          'La marge extérieure `ZcrudTheme.subfolderSheetPadding` retire de la '
          'largeur aux items, seuls éléments élastiques de la feuille : au-delà '
          'd\'un certain retrait, ils passent sous le plancher de cible '
          'tactile. Le plafond de 80 % de hauteur d\'écran de la feuille, lui, '
          'n\'est PAS en cause — il est posé au-dessus de cette marge et reste '
          'tenu.',
      remedy:
          'Mesuré : à 320 dp de large, la rupture n\'apparaît qu\'au-delà de '
          '128 dp de marge PAR CÔTÉ.',
      child: child,
    );
  }

  /// Un item de la feuille. [refOrNull] `null` ⇒ item racine (non indenté).
  Widget _item(BuildContext context, ZcrudTheme theme, ZSubfolderRef? ref) {
    final String? id = ref?.id;
    // Point 1 — l'ANNONCE a11y de l'item suit le libellé RENDU : les
    // laisser diverger ferait dire au lecteur d'écran autre chose que ce
    // que l'œil lit, ce qui est pire que l'absence du réglage (invariant AD-13).
    final String label = ref?.label ?? zSubfolderRootItemLabel(widget.spec);
    final Widget row = ValueListenableBuilder<String?>(
      valueListenable: widget.selected,
      builder: (context, current, _) {
        final bool isSelected = current == id;
        // Point 8 — slot d'action ; `null` (builder absent OU décision de
        // l'hôte pour cet item) ⇒ AUCUN élément dans l'arbre (invariant AD-4).
        final Widget? action = widget.spec.itemActionBuilder?.call(
          context,
          ref,
          isSelected,
        );
        // L'ACTION est posée HORS du conteneur sémantique de l'item, et
        // c'est mesuré. Le premier jet gardait la structure de la barre (un
        // `Semantics` englobant tout, `excludeSemantics` levé pour laisser
        // passer l'action) : le lecteur d'écran annonçait alors
        // « Sous-dossier 0 / Sous-dossier 0 / 0 » — le libellé du conteneur
        // FUSIONNÉ avec le contenu qu'il était censé remplacer. Séparer les
        // deux sujets donne UNE annonce pour l'item et UNE pour l'action.
        return Row(
          children: <Widget>[
            Expanded(
              // Point 4 — même garde que sur la marge de la barre : sous
              // marge de feuille, l'item est le seul élément élastique, et
              // c'est sa LARGEUR qui rompt (mesuré jusqu'à 0 dp). Sans marge,
              // la garde n'est PAS dans l'arbre : rendu strictement inchangé.
              child: _sheetTapGuard(
                theme,
                Semantics(
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
                      // `WidgetBuilder` et non `Widget` : le contenu doit
                      // être CONSTRUIT SOUS les enveloppes d'inversion, sinon
                      // un `itemBuilder` d'hôte qui lit `IconTheme.of(context)`
                      // ou `DefaultTextStyle.of(context)` pour se colorer
                      // lui-même y trouverait la couleur AMBIANTE — donc
                      // illisible sur le fond opaque. Le rendu des `Icon`/`Text`
                      // nus serait pourtant correct : le défaut ne se verrait
                      // que chez l'hôte qui fait bien son travail.
                      builder: (BuildContext inner) => Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _sheetItemContent(inner, ref, isSelected),
                      ),
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
  /// [ZSubfolderSelectedEmphasis.inverted] **retourne le couple** : fond
  /// `inverseSurface` ET premier plan forcé à `onInverseSurface` via
  /// [ZInvertedSurface] (`zcrud_core`), de sorte qu'un `itemBuilder` injecté
  /// s'inverse lui aussi — **y compris** quand il se style depuis
  /// `Theme.of(context).textTheme.*`. Un simple fond opaque
  /// laisserait le texte de l'hôte illisible — c'est le contraste RÉEL qui est
  /// la capacité, pas la décoration.
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
    // L'inversion est déléguée à l'enveloppe PARTAGÉE de
    // `zcrud_core` : elle seule atteint le contenu stylé depuis
    // `Theme.of(context).textTheme.*` (chaque rôle porte sa propre couleur, qui
    // écrasait le `DefaultTextStyle` posé ici). Toute surface d'inversion à
    // venir en hérite au lieu de rejouer le défaut.
    return ZInvertedSurface(
      padding: padding,
      borderRadius: BorderRadius.all(theme.radiusM),
      child: Builder(builder: builder),
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
      // Même jeton que la gouttière et le titre.
      padding: _sheetGutter(theme),
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

/// Dénonciation en DEBUG d'une cible tactile écrasée par la marge extérieure
/// — jamais une correction silencieuse.
///
/// ## L'arbitrage, et ce qui l'a décidé (MESURÉ, pas supposé)
///
/// Une marge extérieure non bornée peut, à largeur contrainte, écraser la
/// cible du déclencheur sans qu'aucun signal ne le révèle. Mesures rejouées
/// ici (écran 320 dp et 400 dp, `addAction` fourni donc `+` présent) :
///
/// | largeur | marge/côté | déclencheur rendu |
/// |---|---|---|
/// | 320 | 0 | 272 × 48 |
/// | 320 | 24 | 224 × 48 |
/// | 320 | 48 | 176 × 48 |
/// | 320 | 96 | 80 × 48 |
/// | 320 | **112** | **48 × 48** ← plancher atteint |
/// | 320 | 130 | **12 × 48** ← plancher ROMPU |
/// | 400 | 48 | 256 × 48 |
/// | 400 | 130 | 92 × 48 |
///
/// Trois enseignements :
/// 1. **La HAUTEUR ne bouge jamais** (48 dp) : le `ConstrainedBox` du
///    déclencheur la tient, et la marge n'intervient pas sur un axe libre.
/// 2. **Le bouton `+` ne rétrécit pas** : il garde ses 48 dp intrinsèques ;
///    c'est l'`Expanded` du déclencheur qui absorbe **tout** le retrait.
/// 3. La rupture n'arrive qu'au-delà de **112 dp par côté à 320 dp** (soit 70 %
///    de la largeur écran en marge) — **152 dp à 400 dp**. Aucune marge
///    plausible n'y touche.
///
/// ## Pourquoi DÉNONCER plutôt que BORNER, ou que ne rien faire
///
/// * **Borner** la marge ferait rendre au socle autre chose que ce que l'hôte a
///   demandé, **en silence** — un socle qui déciderait à la place de l'hôte :
///   le remède ne peut pas rejouer ce défaut.
/// * **Ne rien faire** serait tenable si le cas était inatteignable — il ne
///   l'est pas : mesuré à 12 dp. Un plancher a11y rompu sans le moindre signal
///   est le pire des trois.
/// * **Dénoncer** en debug ne coûte rien en production, rougit dans les tests
///   de l'hôte, s'affiche dans sa console, et **nomme le remède** (réduire la
///   marge). Même idiome que `ZMenuEntryTile` / `RenderFlex overflowed`.
///
/// La garde n'est posée QUE lorsque la marge est fournie : sans marge, l'arbre
/// est strictement celui d'avant l'existence de cette marge.
/// ## Point 4 — la MÊME garde sert la marge de la FEUILLE
///
/// Mesures rejouées (écran 320 × 800, 12 sous-dossiers, titre fourni) :
///
/// | marge/côté | feuille rendue | colonne de contenu | item racine |
/// |---|---|---|---|
/// | *(aucune)* | 320 × 640 | 304 × 624 | 304 × 48 |
/// | 24 | **320 × 640** | 256 × 576 | 256 × 48 |
/// | 120 | **320 × 640** | 64 × 384 | **64 × 48** |
/// | 300 | **320 × 640** | 0 × 24 | **0 × 48** ← plancher ROMPU |
///
/// Trois enseignements, symétriques de ceux de la barre :
/// 1. **Le plafond de 80 % de hauteur d'écran ne bouge JAMAIS** (640 dp =
///    0,8 × 800 dans les quatre cas) : il est posé en `constraints` sur la
///    feuille elle-même, donc AU-DESSUS de cette marge. Une marge verticale
///    généreuse réduit la hauteur du CONTENU, que la liste `Flexible` absorbe.
/// 2. C'est la **LARGEUR** de l'item qui rompt, pas sa hauteur (miroir exact de
///    la barre, où c'était aussi l'axe libre qui cédait) — et elle tombe
///    jusqu'à **0 dp**.
/// 3. La rupture n'arrive qu'au-delà de **128 dp par côté à 320 dp** (soit 80 %
///    de la largeur écran en marge). Aucune marge plausible n'y touche.
///
/// Le sujet gardé est **chaque ITEM**, pas la colonne : les items de la liste
/// sont **plus étroits que la racine** de l'indentation de hiérarchie (mesuré :
/// 279 contre 304 dp). Garder la seule racine aurait laissé une fenêtre de
/// 25 dp où les items réels rompent pendant que la garde reste verte.
class _ZTapTargetGuard extends SingleChildRenderObjectWidget {
  const _ZTapTargetGuard({
    required this.minSize,
    required this.subject,
    required this.token,
    required this.cause,
    required this.remedy,
    required Widget super.child,
  });

  /// Cible minimale exigée sur les DEUX axes (dp).
  final double minSize;

  /// Élément mesuré, nommé dans le message (« déclencheur », « item »…).
  final String subject;

  /// Jeton de thème RESPONSABLE — le message doit NOMMER le remède.
  final String token;

  /// Pourquoi ce jeton écrase cette cible-là.
  final String cause;

  /// Ce que l'hôte doit faire, avec le seuil MESURÉ.
  final String remedy;

  @override
  _RenderZTapTargetGuard createRenderObject(BuildContext context) =>
      _RenderZTapTargetGuard(
        minSize: minSize,
        subject: subject,
        token: token,
        cause: cause,
        remedy: remedy,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderZTapTargetGuard renderObject,
  ) {
    renderObject
      ..minSize = minSize
      ..subject = subject
      ..token = token
      ..cause = cause
      ..remedy = remedy;
  }
}

class _RenderZTapTargetGuard extends RenderProxyBox {
  // Champ privé à SETTER (chaque écriture doit `markNeedsLayout`) : un formal
  // d'initialisation ne conviendrait pas.
  // ignore: prefer_initializing_formals
  _RenderZTapTargetGuard({
    required double minSize,
    required this.subject,
    required this.token,
    required this.cause,
    required this.remedy,
  }) : _minSize = minSize;

  /// Textes du message — purement diagnostiques (console de debug), jamais
  /// rendus à l'écran : ils ne relèvent donc pas de la l10n (FR-26).
  String subject;
  String token;
  String cause;
  String remedy;

  double get minSize => _minSize;
  double _minSize;
  set minSize(double value) {
    if (value == _minSize) return;
    _minSize = value;
    markNeedsLayout();
  }

  /// Tolérance d'arrondi : 47,7 dp n'est pas le défaut visé (le cas mesuré
  /// était 12 dp).
  static const double _tolerance = 0.5;

  @override
  void performLayout() {
    super.performLayout();
    assert(() {
      if (size.width >= _minSize - _tolerance &&
          size.height >= _minSize - _tolerance) {
        return true;
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
              'ZSubfolderSelectorBar : cible tactile ÉCRASÉE ($subject) — '
              '${size.width.toStringAsFixed(1)} × '
              '${size.height.toStringAsFixed(1)} dp au lieu de '
              '${_minSize.toStringAsFixed(0)} dp minimum (AD-13/NFR-S6).',
            ),
            ErrorDescription(cause),
            ErrorHint(
              'Remède : RÉDUIRE `$token`. Le socle ne la borne pas de '
              'lui-même — il rendrait alors autre chose que la marge '
              'demandée, en silence. $remedy',
            ),
          ]),
          library: 'zcrud_study',
          context: ErrorDescription(
            'pendant la disposition de la barre de sélection de fratrie',
          ),
        ),
      );
      return true;
    }());
  }
}
